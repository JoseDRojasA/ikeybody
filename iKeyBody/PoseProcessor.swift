import AVFoundation
import Vision

/// Receives camera frames on the capture queue and runs the Vision requests.
///
/// 2D requests (body, hands, face) run on every frame. The 3D body request is
/// slower, so it runs on its own queue and frames that arrive while it's busy
/// are skipped for 3D only.
nonisolated final class PoseProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    /// Called on the capture queue with the 2D results of each frame.
    var on2DResult: (@Sendable (PoseFrame2D) -> Void)?
    /// Called on the 3D queue with the latest 3D body, or nil when nobody is found.
    var on3DResult: (@Sendable (BodyPose3D?) -> Void)?

    /// Joints below this confidence are dropped to avoid flickering points.
    private let minimumConfidence: Float = 0.3

    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 4
        return request
    }()
    private let faceRequest = VNDetectFaceLandmarksRequest()
    private let body3DRequest = VNDetectHumanBodyPose3DRequest()

    private let body3DQueue = DispatchQueue(label: "iKeyBody.pose3D", qos: .userInitiated)
    private let lock = NSLock()
    private var isBody3DBusy = false

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([bodyRequest, handRequest, faceRequest])
        } catch {
            return
        }

        on2DResult?(PoseFrame2D(bodies: makeBodies(), hands: makeHands(), faces: makeFaces()))
        schedule3D(sampleBuffer)
    }

    // MARK: - 2D results

    private func makeBodies() -> [BodyPose2D] {
        (bodyRequest.results ?? []).map { observation in
            let points = (try? observation.recognizedPoints(.all)) ?? [:]
            var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            for (name, point) in points where point.confidence > minimumConfidence {
                joints[name] = point.location
            }
            return BodyPose2D(joints: joints)
        }
    }

    private func makeHands() -> [HandPose2D] {
        (handRequest.results ?? []).map { observation in
            let points = (try? observation.recognizedPoints(.all)) ?? [:]
            var joints: [VNHumanHandPoseObservation.JointName: CGPoint] = [:]
            for (name, point) in points where point.confidence > minimumConfidence {
                joints[name] = point.location
            }
            let side: HandPose2D.Side = switch observation.chirality {
            case .left: .left
            case .right: .right
            default: .unknown
            }
            return HandPose2D(joints: joints, side: side)
        }
    }

    private func makeFaces() -> [FacePose2D] {
        (faceRequest.results ?? []).compactMap { face in
            guard let landmarks = face.landmarks else { return nil }
            let box = face.boundingBox

            // Landmark points are normalized to the face bounding box; convert them to image space.
            func region(_ region: VNFaceLandmarkRegion2D?, closed: Bool) -> FaceRegion? {
                guard let region, region.pointCount > 0 else { return nil }
                let points = region.normalizedPoints.map {
                    CGPoint(x: box.minX + CGFloat($0.x) * box.width,
                            y: box.minY + CGFloat($0.y) * box.height)
                }
                return FaceRegion(points: points, isClosed: closed)
            }

            let regions = [
                region(landmarks.faceContour, closed: false),
                region(landmarks.leftEyebrow, closed: false),
                region(landmarks.rightEyebrow, closed: false),
                region(landmarks.leftEye, closed: true),
                region(landmarks.rightEye, closed: true),
                region(landmarks.leftPupil, closed: false),
                region(landmarks.rightPupil, closed: false),
                region(landmarks.nose, closed: true),
                region(landmarks.noseCrest, closed: false),
                region(landmarks.medianLine, closed: false),
                region(landmarks.outerLips, closed: true),
                region(landmarks.innerLips, closed: true),
            ].compactMap { $0 }

            return FacePose2D(regions: regions)
        }
    }

    // MARK: - 3D results

    private func schedule3D(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        if isBody3DBusy {
            lock.unlock()
            return
        }
        isBody3DBusy = true
        lock.unlock()

        nonisolated(unsafe) let buffer = sampleBuffer
        body3DQueue.async { [self] in
            let pose = process3D(buffer)
            lock.lock()
            isBody3DBusy = false
            lock.unlock()
            on3DResult?(pose)
        }
    }

    private func process3D(_ sampleBuffer: CMSampleBuffer) -> BodyPose3D? {
        // Using the sample buffer lets Vision read the camera intrinsics attached to it.
        let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer, orientation: .up)
        guard (try? handler.perform([body3DRequest])) != nil,
              let observation = body3DRequest.results?.first,
              let points = try? observation.recognizedPoints(.all)
        else { return nil }

        var joints: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>] = [:]
        for (name, point) in points {
            let translation = point.position.columns.3
            joints[name] = SIMD3(translation.x, translation.y, translation.z)
        }
        return BodyPose3D(joints: joints, bodyHeight: observation.bodyHeight)
    }
}
