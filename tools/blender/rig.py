"""The template's canonical humanoid skeleton and side-view posing helpers (runs inside Blender).

Bone names follow Rigify's metarig, so a Rigify-generated rig (DEF- bones) or a rig renamed to these
names can be posed by the move library. The character faces +X, up is +Z, and every pose angle is a
rotation in the side (X-Z) plane:

    angle in degrees, counter-clockwise as seen by the camera when the character faces right
    (an arm hanging down at +90 points straight forward; a negative hips angle tips the body backwards)

Child angles are relative to the parent, like FK. The hips bone is the root and also takes a
location [x, z] in metres (x forward, z up) for crouches, jumps and falls.
"""
from __future__ import annotations

import math

import bpy
from mathutils import Matrix, Vector

# name: (head, tail, parent).  Metres, character facing +X, feet on z = 0.
# The near side (towards the camera at -Y) is .R, the far side .L.
SKELETON = {
    "hips":        ((0.0, 0.0, 0.98), (0.0, 0.0, 1.10), None),
    "spine":       ((0.0, 0.0, 1.10), (0.0, 0.0, 1.30), "hips"),
    "chest":       ((0.0, 0.0, 1.30), (0.0, 0.0, 1.52), "spine"),
    "neck":        ((0.0, 0.0, 1.52), (0.0, 0.0, 1.60), "chest"),
    "head":        ((0.0, 0.0, 1.60), (0.0, 0.0, 1.86), "neck"),
    "upper_arm.R": ((0.0, -0.22, 1.47), (0.0, -0.22, 1.17), "chest"),
    "forearm.R":   ((0.0, -0.22, 1.17), (0.0, -0.22, 0.91), "upper_arm.R"),
    "hand.R":      ((0.0, -0.22, 0.91), (0.0, -0.22, 0.81), "forearm.R"),
    "upper_arm.L": ((0.0, 0.22, 1.47), (0.0, 0.22, 1.17), "chest"),
    "forearm.L":   ((0.0, 0.22, 1.17), (0.0, 0.22, 0.91), "upper_arm.L"),
    "hand.L":      ((0.0, 0.22, 0.91), (0.0, 0.22, 0.81), "forearm.L"),
    "thigh.R":     ((0.0, -0.11, 0.98), (0.0, -0.11, 0.53), "hips"),
    "shin.R":      ((0.0, -0.11, 0.53), (0.0, -0.11, 0.09), "thigh.R"),
    "foot.R":      ((0.0, -0.11, 0.09), (0.17, -0.11, 0.04), "shin.R"),
    "thigh.L":     ((0.0, 0.11, 0.98), (0.0, 0.11, 0.53), "hips"),
    "shin.L":      ((0.0, 0.11, 0.53), (0.0, 0.11, 0.09), "thigh.L"),
    "foot.L":      ((0.0, 0.11, 0.09), (0.17, 0.11, 0.04), "shin.L"),
}

WEAPON_HAND = "hand.R"           # the near hand holds weapons
WEAPON_FOREARM = "forearm.R"


def build_armature(name: str = "rig") -> bpy.types.Object:
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, (head, tail, parent) in SKELETON.items():
        b = arm.edit_bones.new(bname)
        b.head, b.tail = Vector(head), Vector(tail)
        b.align_roll(Vector((0, -1, 0)))      # same roll everywhere: local axes are predictable
        if parent:
            b.parent = arm.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


def set_pose(rig: bpy.types.Object, pose: dict) -> None:
    """Apply a pose: {bone: angle} or {bone: [angle, x, z]} (location only on the hips)."""
    yaxis = Vector((0, 1, 0))
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    for bname, v in pose.items():
        pb = rig.pose.bones.get(bname)
        if pb is None:
            continue
        ang, x, z = (v, 0.0, 0.0) if isinstance(v, (int, float)) else (v[0], v[1] if len(v) > 1 else 0.0, v[2] if len(v) > 2 else 0.0)
        rest3 = pb.bone.matrix_local.to_3x3()
        inv = rest3.inverted()
        axis = (inv @ yaxis).normalized()
        basis = Matrix.Rotation(-math.radians(ang), 4, axis)
        if x or z:
            basis = Matrix.Translation(inv @ Vector((x, 0, z))) @ basis
        pb.matrix_basis = basis
    bpy.context.view_layer.update()


def bone_world(rig: bpy.types.Object, bname: str, end: str = "tail") -> Vector:
    pb = rig.pose.bones[bname]
    return rig.matrix_world @ (pb.tail if end == "tail" else pb.head)
