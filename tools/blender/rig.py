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


# Rest direction of each canonical bone in character space (x forward, y = far side, z up).
REST_DIR = {"hips": (0, 0, 1), "spine": (0, 0, 1), "chest": (0, 0, 1), "neck": (0, 0, 1), "head": (0, 0, 1),
            "upper_arm": (0, 0, -1), "forearm": (0, 0, -1), "hand": (0, 0, -1),
            "thigh": (0, 0, -1), "shin": (0, 0, -1), "foot": (1, 0, -0.3)}


def _rest_dir(bname: str) -> Vector:
    return Vector(REST_DIR[bname.split(".")[0]]).normalized()


def identity_map() -> dict:
    return {b: [b] for b in SKELETON}


def _vals(v):
    if isinstance(v, (int, float)):
        return float(v), 0.0, 0.0
    v = list(v) + [0.0, 0.0]
    return float(v[0]), float(v[1]), float(v[2])


def set_pose(rig: bpy.types.Object, pose: dict, bone_map: dict | None = None) -> None:
    """Pose any humanoid rig from a canonical pose.

    Works by direction, so it fits rigs with other bone names, rest poses (T-pose, A-pose) and bone
    counts: each canonical bone gets an absolute direction in the side plane (its angle plus its
    parents'), and every rig bone mapped to it (bone_map: canonical -> [rig bones]) is turned to point
    that way. The hips are turned and moved instead, which carries the whole body.
    rig["base_yaw"] (degrees) says how the rig's own space is turned from character space
    (90 for a rig that faces -Y, like MakeHuman's)."""
    bone_map = bone_map or identity_map()
    base = Matrix.Rotation(-math.radians(float(rig.get("base_yaw", 0.0))), 3, "Z")     # character -> armature space
    for pb in rig.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()

    side = base @ Vector((0, 1, 0))
    absang = {}
    for c, (_h, _t, parent) in SKELETON.items():
        absang[c] = _vals(pose.get(c, 0))[0] + (absang[parent] if parent else 0.0)

    # hips: turn the root around the side axis at its head, then move it
    ang, x, z = _vals(pose.get("hips", 0))
    for rb in bone_map.get("hips", []):
        pb = rig.pose.bones.get(rb)
        if pb is None:
            continue
        h = pb.head.copy()
        m = Matrix.Translation(base @ Vector((x, 0, z))) @ Matrix.Translation(h) @ \
            Matrix.Rotation(-math.radians(ang), 4, side) @ Matrix.Translation(-h)
        pb.matrix = m @ pb.matrix
        bpy.context.view_layer.update()

    for c in SKELETON:
        if c == "hips":
            continue
        a = math.radians(absang[c])
        d = _rest_dir(c)
        want = base @ Vector((d.x * math.cos(a) - d.z * math.sin(a), 0.0, d.x * math.sin(a) + d.z * math.cos(a)))
        for rb in bone_map.get(c, []):
            pb = rig.pose.bones.get(rb)
            if pb is None:
                continue
            cur = pb.tail - pb.head
            if cur.length < 1e-6:
                continue
            q = cur.normalized().rotation_difference(want.normalized()).to_matrix().to_4x4()
            h = pb.head.copy()
            pb.matrix = Matrix.Translation(h) @ q @ Matrix.Translation(-h) @ pb.matrix
            bpy.context.view_layer.update()


def bone_world(rig: bpy.types.Object, bname: str, end: str = "tail") -> Vector:
    pb = rig.pose.bones[bname]
    return rig.matrix_world @ (pb.tail if end == "tail" else pb.head)


def fist_world(rig: bpy.types.Object, hand_bone: str, reach: float = 0.06) -> Vector:
    """Middle of the fist: a little past the wrist along the hand bone (rigs differ in hand bone length)."""
    pb = rig.pose.bones[hand_bone]
    d = (pb.tail - pb.head).normalized()
    return rig.matrix_world @ (pb.head + d * reach)
