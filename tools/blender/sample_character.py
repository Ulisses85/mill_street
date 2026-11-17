"""A sample brawler built from simple shapes, rigged to the canonical skeleton (runs inside Blender).

It exists so the render pipeline can be built and tested without an AI-made model. Each body part is a
rigid shape parented to one bone, the classic "segmented puppet" rig: no skin weights to go wrong.
Real characters (Qwen-Image -> TRELLIS.2 -> Rigify) replace it through the spec's "model" setting.

    "model": "sample:bruiser"    or    "model": "source/bruiser.blend"   (an armature named "rig")
"""
from __future__ import annotations

import math

import bpy
from mathutils import Matrix, Vector

from rig import build_armature

# Colours are sRGB 0-255; the shaders turn them into cel-shaded bands.
LOOKS = {
    "bruiser": {
        "skin": (214, 160, 122), "beard": (58, 42, 34), "jacket": (64, 112, 62), "lining": (232, 128, 40),
        "shirt": (236, 232, 222), "jeans": (58, 82, 128), "boots": (62, 44, 36), "belt": (34, 30, 30),
    },
}


def _srgb(c):
    def lin(v):
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1.0)


def _shape(kind: str, name: str, loc, size, mat: str, rot_y: float = 0.0, bevel: float = 0.0) -> bpy.types.Object:
    if kind == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=14, radius=1.0)
    else:
        bpy.ops.mesh.primitive_cube_add(size=2.0)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    ob.rotation_euler = (0.0, math.radians(rot_y), 0.0)
    ob.location = loc
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        m = ob.modifiers.new("bevel", "BEVEL")
        m.width, m.segments, m.limit_method = bevel, 3, "NONE"
    for p in ob.data.polygons:
        p.use_smooth = True
    ob["part_material"] = mat
    return ob


def _limb(name, a, b, r, mat, squash=1.0):
    """An ellipsoid from point a to point b (both in the side plane)."""
    a, b = Vector(a), Vector(b)
    mid, d = (a + b) / 2, b - a
    ang = math.degrees(math.atan2(d.x, d.z))     # tilt from vertical, in the X-Z plane
    return _shape("ball", name, mid, (r * squash, r, d.length / 2 + r * 0.6), mat, rot_y=ang)


def build(look: str = "bruiser") -> tuple[bpy.types.Object, list[bpy.types.Object], dict]:
    """Returns (rig, parts, colours). Parts carry a 'part_material' key that the renderer turns into shaders."""
    rig = build_armature()
    P = []
    # Each entry: (bone, object). Far side (.L) parts sit at +Y, near side (.R) at -Y.
    for side, y in (("L", 0.22), ("R", -0.22)):
        P += [("upper_arm." + side, _limb(f"upper_arm.{side}", (0, y, 1.45), (0, y, 1.18), 0.085, "jacket")),
              ("forearm." + side, _limb(f"forearm.{side}", (0, y, 1.16), (0, y, 0.93), 0.072, "jacket")),
              ("forearm." + side, _shape("ball", f"cuff.{side}", (0, y, 0.93), (0.066, 0.066, 0.03), "lining")),
              ("hand." + side, _shape("ball", f"fist.{side}", (0.01, y, 0.86), (0.065, 0.06, 0.07), "skin"))]
    for side, y in (("L", 0.11), ("R", -0.11)):
        P += [("thigh." + side, _limb(f"thigh.{side}", (0, y, 0.96), (0, y, 0.55), 0.105, "jeans")),
              ("shin." + side, _limb(f"shin.{side}", (0, y, 0.53), (0, y, 0.14), 0.085, "jeans")),
              ("foot." + side, _shape("cube", f"boot.{side}", (0.06, y, 0.06), (0.13, 0.065, 0.06), "boots", bevel=0.035))]
    P += [("hips", _shape("cube", "pelvis", (0, 0, 1.0), (0.13, 0.19, 0.11), "jeans", bevel=0.06)),
          ("hips", _shape("cube", "belt", (0, 0, 1.09), (0.135, 0.195, 0.025), "belt", bevel=0.01)),
          ("spine", _shape("cube", "belly", (0.0, 0, 1.2), (0.15, 0.2, 0.12), "shirt", bevel=0.08)),
          ("chest", _shape("cube", "torso", (-0.01, 0, 1.38), (0.17, 0.25, 0.14), "jacket", bevel=0.09)),
          ("chest", _shape("cube", "shirt_v", (0.13, 0, 1.36), (0.05, 0.08, 0.11), "shirt", bevel=0.03)),
          ("chest", _shape("cube", "collar", (-0.02, 0, 1.5), (0.13, 0.2, 0.035), "lining", bevel=0.03)),
          ("neck", _shape("ball", "neck", (0.01, 0, 1.56), (0.07, 0.075, 0.07), "skin")),
          ("head", _shape("ball", "skull", (0.01, 0, 1.72), (0.105, 0.1, 0.125), "skin")),
          ("head", _shape("ball", "nose", (0.115, 0, 1.71), (0.03, 0.025, 0.035), "skin")),
          ("head", _shape("ball", "ear", (-0.005, -0.1, 1.72), (0.03, 0.02, 0.04), "skin")),
          ("head", _shape("ball", "beard", (0.05, 0, 1.64), (0.08, 0.098, 0.07), "beard")),
          ("head", _shape("cube", "brow", (0.09, 0, 1.765), (0.03, 0.08, 0.012), "beard", bevel=0.01))]
    bpy.context.view_layer.update()
    parts = []
    for bone, ob in P:
        mw = ob.matrix_world.copy()
        ob.parent, ob.parent_type, ob.parent_bone = rig, "BONE", bone
        bpy.context.view_layer.update()
        ob.matrix_world = mw
        parts.append(ob)
    colours = {k: _srgb(v) for k, v in LOOKS[look].items()}
    return rig, parts, colours


def load_blend(path: str) -> tuple[bpy.types.Object, list[bpy.types.Object], dict]:
    """A character from a .blend: an armature named 'rig' and its meshes. Their own materials are kept
    as base colours ('part_material' = material name)."""
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = list(src.objects)
    rig, parts, colours = None, [], {}
    for ob in dst.objects:
        bpy.context.scene.collection.objects.link(ob)
        if ob.type == "ARMATURE" and ob.name == "rig":
            rig = ob
        elif ob.type == "MESH":
            parts.append(ob)
            if ob.active_material:
                name = ob.active_material.name
                ob["part_material"] = name
                c = ob.active_material.diffuse_color
                colours[name] = (c[0], c[1], c[2], 1.0)
    if rig is None:
        raise SystemExit(f"{path}: no armature named 'rig'")
    return rig, parts, colours
