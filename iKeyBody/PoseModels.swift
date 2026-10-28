import Foundation
import CoreGraphics
import simd
import Vision

/// Body joints from the 2D body request, in Vision's normalized image space
/// (0...1, lower-left origin, not mirrored).
nonisolated struct BodyPose2D: Sendable, Equatable {
    var joints: [VNHumanBodyPoseObservation.JointName: CGPoint]
}

/// The 21 joints of one hand, in Vision's normalized image space.
nonisolated struct HandPose2D: Sendable, Equatable {
    enum Side: Sendable { case left, right, unknown }

    var joints: [VNHumanHandPoseObservation.JointName: CGPoint]
    var side: Side
}

/// One face landmark region (eye, lips, contour…) as a polyline.
nonisolated struct FaceRegion: Sendable, Equatable {
    var points: [CGPoint]
    var isClosed: Bool
}

/// All landmark regions of one face, in Vision's normalized image space.
nonisolated struct FacePose2D: Sendable, Equatable {
    var regions: [FaceRegion]

    var pointCount: Int { regions.reduce(0) { $0 + $1.points.count } }
}

/// Everything the 2D requests found in a single camera frame.
nonisolated struct PoseFrame2D: Sendable, Equatable {
    var bodies: [BodyPose2D] = []
    var hands: [HandPose2D] = []
    var faces: [FacePose2D] = []

    static let empty = PoseFrame2D()

    var pointCount: Int {
        bodies.reduce(0) { $0 + $1.joints.count }
            + hands.reduce(0) { $0 + $1.joints.count }
            + faces.reduce(0) { $0 + $1.pointCount }
    }
}

/// The 17 joints of the 3D body request, in meters, relative to the root (hip center).
nonisolated struct BodyPose3D: Sendable, Equatable {
    var joints: [VNHumanBodyPose3DObservation.JointName: SIMD3<Float>]
    var bodyHeight: Float
}
