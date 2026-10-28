import SwiftUI

struct ContentView: View {
    @State private var camera = CameraController()

    var body: some View {
        HSplitView {
            cameraPane
                .frame(minWidth: 480, minHeight: 360)
            skeletonPane
                .frame(minWidth: 320, minHeight: 360)
        }
        .frame(minWidth: 900, minHeight: 500)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    private var cameraPane: some View {
        ZStack {
            Color.black
            CameraPreviewView(session: camera.session, isRunning: camera.status == .running)
            PoseOverlayView(frame: camera.frame2D, imageSize: camera.imageSize)
            statusMessage
        }
        .overlay(alignment: .topLeading) {
            Label {
                Text("\(camera.frame2D.bodies.count) bodies · \(camera.frame2D.hands.count) hands · \(camera.frame2D.faces.count) faces · \(camera.frame2D.pointCount) points")
            } icon: {
                Image(systemName: "figure.stand")
            }
            .font(.callout.monospacedDigit())
            .padding(8)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
            .padding(10)
        }
    }

    private var skeletonPane: some View {
        Skeleton3DView(pose: camera.body3D)
            .overlay(alignment: .topLeading) {
                Text(camera.body3D == nil ? "3D: no body detected" : "3D: \(camera.body3D?.joints.count ?? 0) joints")
                    .font(.callout.monospacedDigit())
                    .padding(8)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
                    .padding(10)
            }
            .overlay(alignment: .bottom) {
                Text("Drag to rotate · Scroll to zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch camera.status {
        case .denied:
            ContentUnavailableView(
                "Camera Access Needed",
                systemImage: "video.slash",
                description: Text("Allow camera access in System Settings › Privacy & Security › Camera.")
            )
        case .noCamera:
            ContentUnavailableView("No Camera Found", systemImage: "video.slash")
        case .failed(let message):
            ContentUnavailableView("Camera Error", systemImage: "exclamationmark.triangle", description: Text(message))
        case .idle, .running:
            EmptyView()
        }
    }
}

#Preview {
    ContentView()
}
