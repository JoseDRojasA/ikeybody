import SwiftUI
import Vision

/// Draws the 2D body, hand, and face points on top of the camera preview.
///
/// Vision points are normalized with a lower-left origin. The preview is mirrored
/// and letterboxed (`resizeAspect`), so points are flipped and fitted the same way.
struct PoseOverlayView: View {
    let frame: PoseFrame2D
    let imageSize: CGSize

    var body: some View {
        Canvas { context, size in
            let mapper = PointMapper(imageSize: imageSize, viewSize: size)

            for face in frame.faces {
                drawFace(face, in: &context, mapper: mapper)
            }
            for body in frame.bodies {
                drawBody(body, in: &context, mapper: mapper)
            }
            for hand in frame.hands {
                drawHand(hand, in: &context, mapper: mapper)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawBody(_ body: BodyPose2D, in context: inout GraphicsContext, mapper: PointMapper) {
        var bones = Path()
        for (from, to) in SkeletonDefinition.bodyBones {
            guard let a = body.joints[from], let b = body.joints[to] else { continue }
            bones.move(to: mapper.map(a))
            bones.addLine(to: mapper.map(b))
        }
        context.stroke(bones, with: .color(.green), style: StrokeStyle(lineWidth: 4, lineCap: .round))

        for point in body.joints.values {
            context.fill(dot(at: mapper.map(point), radius: 6), with: .color(.yellow))
        }
    }

    private func drawHand(_ hand: HandPose2D, in context: inout GraphicsContext, mapper: PointMapper) {
        let color: Color = switch hand.side {
        case .left: .cyan
        case .right: .orange
        case .unknown: .white
        }

        var bones = Path()
        for (from, to) in SkeletonDefinition.handBones {
            guard let a = hand.joints[from], let b = hand.joints[to] else { continue }
            bones.move(to: mapper.map(a))
            bones.addLine(to: mapper.map(b))
        }
        context.stroke(bones, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        for point in hand.joints.values {
            context.fill(dot(at: mapper.map(point), radius: 3.5), with: .color(.white))
        }
    }

    private func drawFace(_ face: FacePose2D, in context: inout GraphicsContext, mapper: PointMapper) {
        for region in face.regions {
            let points = region.points.map(mapper.map)
            guard let first = points.first else { continue }

            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            if region.isClosed { path.closeSubpath() }
            context.stroke(path, with: .color(.pink.opacity(0.8)), lineWidth: 1.2)

            for point in points {
                context.fill(dot(at: point, radius: 1.5), with: .color(.pink))
            }
        }
    }

    private func dot(at point: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Converts Vision's normalized points into view coordinates that match the preview layer.
private struct PointMapper {
    let videoRect: CGRect

    init(imageSize: CGSize, viewSize: CGSize) {
        // Same math as AVLayerVideoGravity.resizeAspect: fit and center.
        let scale = min(viewSize.width / max(imageSize.width, 1), viewSize.height / max(imageSize.height, 1))
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        videoRect = CGRect(x: (viewSize.width - width) / 2, y: (viewSize.height - height) / 2, width: width, height: height)
    }

    func map(_ point: CGPoint) -> CGPoint {
        // Mirror horizontally (preview is mirrored) and flip vertically (Vision uses lower-left origin).
        CGPoint(x: videoRect.minX + (1 - point.x) * videoRect.width,
                y: videoRect.minY + (1 - point.y) * videoRect.height)
    }
}
