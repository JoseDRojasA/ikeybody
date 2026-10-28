import RealityKit
import SwiftUI
import Vision

/// A rotatable 3D view of the 17-joint body skeleton from Vision's 3D request.
/// Drag to orbit, scroll or pinch to zoom.
struct Skeleton3DView: View {
    let pose: BodyPose3D?

    @State private var rig = SkeletonRig()

    var body: some View {
        RealityView { content in
            content.add(rig.root)

            // Camera in front of the skeleton, roughly at chest height.
            let camera = Entity()
            camera.components.set(PerspectiveCameraComponent())
            camera.look(at: [0, 0.2, 0], from: [0, 0.4, 3], relativeTo: nil)
            content.add(camera)

            let light = DirectionalLight()
            light.light.intensity = 3000
            light.look(at: .zero, from: [1, 2, 2], relativeTo: nil)
            content.add(light)
        } update: { _ in
            rig.apply(pose)
        }
        .realityViewCameraControls(.orbit)
        .background(Color(white: 0.08))
    }
}

/// Holds one sphere per joint and one cylinder per bone, and moves them each frame.
@MainActor
private final class SkeletonRig {
    typealias JointName = VNHumanBodyPose3DObservation.JointName

    let root = Entity()
    private var joints: [JointName: ModelEntity] = [:]
    private var bones: [ModelEntity] = []

    init() {
        let jointMesh = MeshResource.generateSphere(radius: 0.035)
        let jointMaterial = SimpleMaterial(color: .systemYellow, isMetallic: false)
        for name in SkeletonDefinition.body3DJoints {
            let entity = ModelEntity(mesh: jointMesh, materials: [jointMaterial])
            entity.isEnabled = false
            root.addChild(entity)
            joints[name] = entity
        }

        // Unit-height cylinder along +Y; each frame it's scaled to the bone length.
        let boneMesh = MeshResource.generateCylinder(height: 1, radius: 0.015)
        let boneMaterial = SimpleMaterial(color: .systemGreen, isMetallic: false)
        for _ in SkeletonDefinition.body3DBones {
            let entity = ModelEntity(mesh: boneMesh, materials: [boneMaterial])
            entity.isEnabled = false
            root.addChild(entity)
            bones.append(entity)
        }

        // Simple floor grid reference so depth and rotation are easier to read.
        let floor = ModelEntity(
            mesh: .generatePlane(width: 2, depth: 2),
            materials: [SimpleMaterial(color: .init(white: 0.25, alpha: 1), isMetallic: false)]
        )
        floor.position.y = -1.0
        root.addChild(floor)
    }

    func apply(_ pose: BodyPose3D?) {
        guard let pose else {
            joints.values.forEach { $0.isEnabled = false }
            bones.forEach { $0.isEnabled = false }
            return
        }

        // Flip X so the 3D skeleton moves like a mirror, matching the camera preview.
        func position(_ name: JointName) -> SIMD3<Float>? {
            pose.joints[name].map { SIMD3(-$0.x, $0.y, $0.z) }
        }

        for (name, entity) in joints {
            if let p = position(name) {
                entity.position = p
                entity.isEnabled = true
            } else {
                entity.isEnabled = false
            }
        }

        for (index, (from, to)) in SkeletonDefinition.body3DBones.enumerated() {
            let bone = bones[index]
            guard let a = position(from), let b = position(to) else {
                bone.isEnabled = false
                continue
            }
            let delta = b - a
            let length = simd_length(delta)
            guard length > 0.0001 else {
                bone.isEnabled = false
                continue
            }
            bone.position = (a + b) / 2
            bone.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
            bone.scale = [1, length, 1]
            bone.isEnabled = true
        }
    }
}
