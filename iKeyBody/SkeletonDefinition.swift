import Vision

/// Which joints are connected by a bone, for each kind of skeleton.
nonisolated enum SkeletonDefinition {
    typealias Body = VNHumanBodyPoseObservation.JointName
    typealias Hand = VNHumanHandPoseObservation.JointName
    typealias Body3D = VNHumanBodyPose3DObservation.JointName

    static let bodyBones: [(Body, Body)] = [
        (.nose, .leftEye), (.leftEye, .leftEar),
        (.nose, .rightEye), (.rightEye, .rightEar),
        (.nose, .neck),
        (.neck, .leftShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.neck, .rightShoulder), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.root, .rightHip), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    static let handBones: [(Hand, Hand)] = [
        // Thumb
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        // Index
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        // Middle
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        // Ring
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        // Little
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip),
        // Palm
        (.indexMCP, .middleMCP), (.middleMCP, .ringMCP), (.ringMCP, .littleMCP),
    ]

    static let body3DJoints: [Body3D] = [
        .topHead, .centerHead, .centerShoulder,
        .leftShoulder, .leftElbow, .leftWrist,
        .rightShoulder, .rightElbow, .rightWrist,
        .spine, .root,
        .leftHip, .leftKnee, .leftAnkle,
        .rightHip, .rightKnee, .rightAnkle,
    ]

    static let body3DBones: [(Body3D, Body3D)] = [
        (.topHead, .centerHead), (.centerHead, .centerShoulder),
        (.centerShoulder, .leftShoulder), (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.centerShoulder, .rightShoulder), (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.centerShoulder, .spine), (.spine, .root),
        (.root, .leftHip), (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.root, .rightHip), (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]
}
