"""Characters from MPFB (the MakeHuman add-on for Blender): a rigged human body made from sliders,
dressed by colouring regions of the body (runs inside Blender, with MPFB installed as an extension).

MPFB is GPL-3 code; its bundled body, targets and rigs are CC0, so the characters it makes can ship
in a commercial game. Only the bundled data is used here (no clothes packs): clothes are painted
onto body regions and puffed out a little, which reads well with cel shading at sprite size.

Spec ("source" block of character.json):

    "model": "mpfb",
    "mpfb": {
      "macros": {"gender": 0.0, "age": 0.6, "muscle": 0.85, "weight": 0.85, "height": 0.6, "proportions": 0.5},
      "targets": {"nose/nose-scale-horiz-incr": 0.6},          optional MPFB targets (path under data/targets, weight)
      "colours": {"skin": [214, 160, 122], "jacket": [64, 112, 62], "shirt": [236, 232, 222],
                  "jeans": [58, 82, 128], "boots": [62, 44, 36], "beard": [58, 42, 34], "eyes": [20, 16, 18]},
      "beard": true, "open_jacket": true, "sleeves": "long"
    }

Install MPFB once: Blender > Preferences > Get Extensions > MPFB, or headless:
    bpy.ops.extensions.package_install_files(repo="user_default", filepath="mpfb.zip", enable_on_install=True)
"""
from __future__ import annotations

import importlib
import math
import os

import bpy

PKG = "bl_ext.user_default.mpfb"

# canonical bone -> the MPFB "default" rig bones it drives (each is pointed the same way)
BONE_MAP = {
    "hips": ["root"],
    "spine": ["spine05", "spine04"],
    "chest": ["spine03", "spine02", "spine01"],
    "neck": ["neck01", "neck02", "neck03"],
    "head": ["head"],
    "upper_arm.R": ["upperarm01.R", "upperarm02.R"], "forearm.R": ["lowerarm01.R", "lowerarm02.R"], "hand.R": ["wrist.R"],
    "upper_arm.L": ["upperarm01.L", "upperarm02.L"], "forearm.L": ["lowerarm01.L", "lowerarm02.L"], "hand.L": ["wrist.L"],
    "thigh.R": ["upperleg01.R", "upperleg02.R"], "shin.R": ["lowerleg01.R", "lowerleg02.R"], "foot.R": ["foot.R"],
    "thigh.L": ["upperleg01.L", "upperleg02.L"], "shin.L": ["lowerleg01.L", "lowerleg02.L"], "foot.L": ["foot.L"],
}
FINGERS = [f"finger{i}-{j}.{s}" for s in "LR" for i in range(2, 6) for j in range(1, 4)]
THUMBS = [f"finger1-{j}.{s}" for s in "LR" for j in range(2, 4)]

SKIN = ("head", "jaw", "neck", "wrist", "finger", "metacarpal", "eye", "oris", "levator", "tongue", "special",
        "orbicularis", "oculi", "temporalis", "risorius")
JACKET = ("spine01", "spine02", "spine03", "spine04", "clavicle", "shoulder", "upperarm", "lowerarm", "breast")
JEANS = ("root", "spine05", "pelvis", "upperleg", "lowerleg")
BOOTS = ("foot", "toe")


def _svc(mod, name):
    return getattr(importlib.import_module(f"{PKG}.{mod}"), name)


def _ensure_mpfb():
    import addon_utils
    bpy.ops.wm.read_userpref()
    if PKG not in {m.__name__ for m in addon_utils.modules(refresh=True)}:
        raise SystemExit("MPFB is not installed in this Blender (see tools/blender/mpfb_character.py)")
    addon_utils.enable(PKG, default_set=True)


def _region(name: str, v, mid_y: float, cfg: dict) -> str:
    n = name
    if n.startswith(BOOTS):
        return "boots"
    if n.startswith(JEANS):
        return "jeans"
    if n.startswith(JACKET):
        lower_arm = n.startswith("lowerarm")
        if cfg.get("sleeves", "long") == "short" and lower_arm:
            return "skin"
        # open jacket: a strip down the front of the chest shows the shirt
        if cfg.get("open_jacket", True) and n.startswith(("spine0", "breast")) and v.co.y < -0.085 and abs(v.co.x) < 0.07 \
                and 0.95 < v.co.z < 1.38:
            return "shirt"
        return "jacket"
    if n.startswith("eye"):
        return "eyes"
    if n.startswith(SKIN):
        # beard: the lower front of the face
        if cfg.get("beard", False) and 1.43 < v.co.z < 1.515 and v.co.y < -0.07:
            return "beard"
        # brows: a band above the eyes
        if 1.565 < v.co.z < 1.585 and v.co.y < -0.1 and 0.012 < abs(v.co.x) < 0.06:
            return "beard"
        return "skin"
    return "jacket"


def build(cfg: dict):
    """Returns (rig, parts, colours, bone_map); parts carry 'part_materials' (one per material slot)."""
    _ensure_mpfb()
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    HumanService = _svc("services.humanservice", "HumanService")
    HOP = _svc("entities.objectproperties", "HumanObjectProperties")
    TargetService = _svc("services.targetservice", "TargetService")
    LocationService = _svc("services.locationservice", "LocationService")

    body = HumanService.create_human()
    for k, v in cfg.get("macros", {}).items():
        HOP.set_value(k, float(v), entity_reference=body)
    TargetService.reapply_macro_details(body)
    troot = LocationService.get_mpfb_data("targets")
    for path, w in cfg.get("targets", {}).items():
        TargetService.load_target(body, os.path.join(troot, path + ".target.gz"), weight=float(w))
    rig = HumanService.add_builtin_rig(body, "default")

    # show the body and the eyeballs, hide the other helper geometry (MPFB's own mask hides all helpers)
    vis = body.vertex_groups.new(name="visible")
    gi = {g.name: g.index for g in body.vertex_groups}
    keep = {gi["body"], gi["helper-l-eye"], gi["helper-r-eye"]}
    vis.add([v.index for v in body.data.vertices if any(g.group in keep and g.weight > 0.5 for g in v.groups)], 1.0, "REPLACE")
    for m in body.modifiers:
        if m.type == "MASK":
            m.vertex_group = "visible"

    # paint regions: each vertex goes to the region of the bone that moves it most
    bone_groups = {g.index: g.name for g in body.vertex_groups if g.name in rig.data.bones}
    eyes = {gi["helper-l-eye"], gi["helper-r-eye"]}
    ys = [v.co.y for v in body.data.vertices]
    mid_y = (min(ys) + max(ys)) / 2
    region = {}
    for v in body.data.vertices:
        if any(g.group in eyes and g.weight > 0.5 for g in v.groups):
            region[v.index] = "eyes"
            continue
        best = max((g for g in v.groups if g.group in bone_groups), key=lambda g: g.weight, default=None)
        region[v.index] = _region(bone_groups[best.group], v, mid_y, cfg) if best else "skin"
    names = ["skin", "jacket", "shirt", "jeans", "boots", "beard", "eyes"]
    body.data.materials.clear()
    for n in names:
        body.data.materials.append(bpy.data.materials.new(n))
    for p in body.data.polygons:
        votes = {}
        for vi in p.vertices:
            votes[region[vi]] = votes.get(region[vi], 0) + 1
        p.material_index = names.index(max(votes, key=votes.get))
        p.use_smooth = True
    body["part_materials"] = names

    # clothes stand off the body a little: puff the jacket and jeans out along the normals
    for reg, amount in (("jacket", 0.014), ("jeans", 0.008), ("boots", 0.012)):
        g = body.vertex_groups.new(name=f"puff_{reg}")
        g.add([i for i, r in region.items() if r == reg], 1.0, "REPLACE")
        d = body.modifiers.new(f"puff_{reg}", "DISPLACE")
        d.vertex_group, d.strength, d.mid_level = g.name, amount, 0.0

    # face +X like the canonical skeleton (MakeHuman faces -Y)
    rig.rotation_euler.z = math.radians(90)
    rig["base_yaw"] = 90.0
    c = cfg.get("colours", {})
    defaults = {"skin": (214, 160, 122), "jacket": (64, 112, 62), "shirt": (236, 232, 222), "jeans": (58, 82, 128),
                "boots": (62, 44, 36), "beard": (58, 42, 34), "eyes": (20, 16, 18)}
    colours = {n: _srgb(tuple(c.get(n, defaults[n]))) for n in names}
    rig["fist"] = True
    return rig, [body], colours, BONE_MAP


def curl_fists(rig, side_axis_arm):
    """Close the hands: fingers fold towards the palm (around the character's side axis)."""
    from mathutils import Matrix
    for names, ang in ((FINGERS, 75.0), (THUMBS, 30.0)):
        for n in names:
            pb = rig.pose.bones.get(n)
            if pb is None:
                continue
            h = pb.head.copy()
            r = Matrix.Rotation(math.radians(ang), 4, side_axis_arm)
            pb.matrix = Matrix.Translation(h) @ r @ Matrix.Translation(-h) @ pb.matrix
            bpy.context.view_layer.update()


def _srgb(c):
    def lin(v):
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (lin(c[0]), lin(c[1]), lin(c[2]), 1.0)
