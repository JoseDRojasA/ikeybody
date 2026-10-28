@preconcurrency import AVFoundation
import Observation

/// Owns the webcam capture session and publishes the latest pose results to SwiftUI.
@Observable
final class CameraController {
    enum Status: Equatable {
        case idle
        case running
        case denied
        case noCamera
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var frame2D: PoseFrame2D = .empty
    private(set) var body3D: BodyPose3D?
    /// Size of the camera image in pixels, used to keep the overlay's aspect ratio.
    private(set) var imageSize = CGSize(width: 1280, height: 720)

    let session = AVCaptureSession()

    @ObservationIgnored private let processor = PoseProcessor()
    @ObservationIgnored private let captureQueue = DispatchQueue(label: "iKeyBody.capture", qos: .userInitiated)
    @ObservationIgnored private var isConfigured = false

    init() {
        processor.on2DResult = { [weak self] frame in
            Task { @MainActor [weak self] in self?.frame2D = frame }
        }
        processor.on3DResult = { [weak self] pose in
            Task { @MainActor [weak self] in self?.body3D = pose }
        }
    }

    func start() async {
        guard status != .running else { return }

        guard await AVCaptureDevice.requestAccess(for: .video) else {
            status = .denied
            return
        }

        if !isConfigured {
            do {
                try configureSession()
                isConfigured = true
            } catch let error as SetupError {
                status = error == .noCamera ? .noCamera : .failed(error.message)
                return
            } catch {
                status = .failed(error.localizedDescription)
                return
            }
        }

        let session = session
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            captureQueue.async {
                session.startRunning()
                continuation.resume()
            }
        }
        status = .running
    }

    func stop() {
        let session = session
        captureQueue.async { session.stopRunning() }
        status = .idle
    }

    // MARK: - Setup

    private enum SetupError: Error, Equatable {
        case noCamera
        case cannotAdd(String)

        var message: String {
            switch self {
            case .noCamera: "No camera found."
            case .cannotAdd(let what): "Couldn't add \(what) to the capture session."
            }
        }
    }

    private func configureSession() throws {
        guard let device = AVCaptureDevice.default(for: .video) else { throw SetupError.noCamera }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw SetupError.cannotAdd("the camera input") }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(processor, queue: captureQueue)
        guard session.canAddOutput(output) else { throw SetupError.cannotAdd("the video output") }
        session.addOutput(output)

        // Vision must see the raw, unmirrored image. The overlay and 3D view do the mirroring
        // themselves, so the frames given to Vision must never be pre-mirrored.
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }

        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        imageSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
    }
}
