"""Render a rigged 3D character into 2D sprite frames (colour + normal map + weapon bone), Dead Cells style.

    blender -b -P tools/blender/render_sprites.py -- art/characters/<id>/character.json [--only punch,idle]
    python3 tools/blender/render_sprites.py art/characters/<id>/character.json      (with the bpy module)

then pack the frames into the game's sheet:

    python3 tools/blender/pack_sheet.py art/characters/<id>/character.json

The spec's "source" block says what to render and how it looks:

    "source": {
      "kind": "blender",
      "model": "sample:bruiser",           shapes built by sample_character.py
                                           "mpfb": a MakeHuman body from the "mpfb" block (mpfb_character.py)
                                           or a .blend (relative to the spec) holding an armature named "rig"
      "look": "comic",                     comic: cel bands + ink outline, smooth edges (HD)
                                           pixel: flat bands + 1 px outline, no anti-aliasing (Dead Cells)
      "scale": 4,                          texture pixels per game unit (HD: 4 for a 1920x1080 window)
      "outline_px": 4,                     outline thickness in texture pixels
      "yaw_deg": 28, "tilt_deg": 8,        turn the body towards the camera; look down a little
      "light": [-0.5, 0.7, 0.6],           light direction in camera space (x right, y up, z towards camera)
      "engine": "CYCLES"                   or BLENDER_EEVEE (faster with a GPU)
    },
    "animations": {"punch": {"move": "punch", "frames": 6, "fps": 20, "active": [2, 3]}, ...}

Frames land in art/characters/<id>/raw/render/<anim>/NN.png and NN_n.png (normal map), with the hand
position, weapon angle and timings in raw/render/meta.json. A paint-over pass may write repainted
colour frames to raw/paint/<anim>/NN.png; pack_sheet.py prefers those.
"""
from __future__ import annotations

import json
import math
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import bpy  # noqa: E402
from bpy_extras.object_utils import world_to_camera_view  # noqa: E402
from mathutils import Vector  # noqa: E402

import moves  # noqa: E402
import sample_character  # noqa: E402
from rig import WEAPON_FOREARM, WEAPON_HAND, bone_world, fist_world, identity_map, set_pose  # noqa: E402

CELL = (160, 128)        # game units, same cell and anchor as the 2D importer
ANCHOR = (80, 116)


# ------------------------------------------------------------------ shaders
def _nodes(name):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes") and not m.use_nodes:
        m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    return m, nt, out


def cel_material(name, rgba, light_world, look):
    m, nt, out = _nodes(name)
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    dot.inputs[1].default_value = light_world
    nt.links.new(geo.outputs["Normal"], dot.inputs[0])
    half = nt.nodes.new("ShaderNodeMath")          # -1..1 -> 0..1
    half.operation = "MULTIPLY_ADD"
    half.inputs[1].default_value = 0.5
    half.inputs[2].default_value = 0.5
    nt.links.new(dot.outputs["Value"], half.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    r, g, b, _ = rgba
    shadow = (r * 0.42, g * 0.44, b * 0.62, 1.0) if look == "comic" else (r * 0.5, g * 0.5, b * 0.62, 1.0)
    light = (min(1.0, r * 1.35 + 0.02), min(1.0, g * 1.3 + 0.02), min(1.0, b * 1.22 + 0.02), 1.0)
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, shadow
    els[1].position, els[1].color = 0.52, rgba
    hi = els.new(0.86)
    hi.color = light
    nt.links.new(half.outputs["Value"], ramp.inputs["Fac"])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


def _hull_only(nt, out, shader_out):
    """Inverted-hull outline: the shell's normals point inwards, so the side of it facing the camera is
    seen from behind. Hide that side (it would cover the body) and keep the far side, which shows as
    a rim around the silhouette."""
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(geo.outputs["Backfacing"], mix.inputs["Fac"])
    nt.links.new(shader_out, mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])


def outline_material(rgba):
    m, nt, out = _nodes("outline")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = rgba
    _hull_only(nt, out, em.outputs["Emission"])
    return m


def normal_material(outline: bool):
    """Camera-space normal as colour (x right, y up, z towards camera), the usual 2D normal-map layout."""
    m, nt, out = _nodes("normal_outline" if outline else "normal")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    vt = nt.nodes.new("ShaderNodeVectorTransform")
    vt.vector_type, vt.convert_from, vt.convert_to = "NORMAL", "WORLD", "CAMERA"
    nt.links.new(geo.outputs["Normal"], vt.inputs["Vector"])
    # Blender's camera space looks down -Z, so a normal facing the camera is +Z: map -1..1 -> 0..1
    ma = nt.nodes.new("ShaderNodeVectorMath")
    ma.operation = "MULTIPLY_ADD"
    ma.inputs[1].default_value = (0.5, 0.5, 0.5)
    ma.inputs[2].default_value = (0.5, 0.5, 0.5)
    nt.links.new(vt.outputs["Vector"], ma.inputs[0])
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(ma.outputs["Vector"], em.inputs["Color"])
    if outline:
        _hull_only(nt, out, em.outputs["Emission"])
    else:
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
    return m


# ------------------------------------------------------------------ scene
def setup_scene(src: dict):
    sc = bpy.context.scene
    scale = float(src.get("scale", 4))
    W, H = round(CELL[0] * scale), round(CELL[1] * scale)
    sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = W, H, 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.engine = src.get("engine", "CYCLES")
    pixel = src.get("look", "comic") == "pixel"
    if sc.render.engine == "CYCLES":
        cy = sc.cycles
        cy.device = "CPU"
        cy.samples = 1 if pixel else 8
        cy.use_adaptive_sampling = False
        cy.use_denoising = False
        cy.max_bounces = cy.diffuse_bounces = cy.glossy_bounces = 0
        cy.transparent_max_bounces = 8
        cy.pixel_filter_type = "BOX" if pixel else "BLACKMAN_HARRIS"
        cy.filter_width = 0.01 if pixel else 1.2
    sc.view_settings.look = "None"
    return scale, W, H


def setup_camera(src, scale, W, H, ppm):
    tilt = math.radians(float(src.get("tilt_deg", 8)))
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = max(W, H) / ppm
    cam.clip_start, cam.clip_end = 0.1, 100.0
    ob = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(ob)
    ob.rotation_euler = (math.pi / 2 - tilt, 0.0, 0.0)
    ob.location = (0.0, -20.0, 1.0 + 20.0 * math.tan(tilt))
    sc = bpy.context.scene
    sc.camera = ob
    bpy.context.view_layer.update()
    # shift the view so the floor point under the character lands on the cell's anchor
    big = max(W, H)
    for _ in range(3):
        p = world_to_camera_view(sc, ob, Vector((0, 0, 0)))
        cam.shift_x += (p.x - ANCHOR[0] * scale / W) * W / big
        cam.shift_y += (p.y - (1 - ANCHOR[1] * scale / H)) * H / big
        bpy.context.view_layer.update()
    return ob


def to_pixels(sc, cam, co: Vector, W, H):
    p = world_to_camera_view(sc, cam, co)
    return Vector((p.x * W, (1 - p.y) * H))


def lowest_point(parts) -> float:
    dg = bpy.context.evaluated_depsgraph_get()
    z = 1e9
    for ob in parts:
        ev = ob.evaluated_get(dg)
        mw = ev.matrix_world
        for v in ev.data.vertices if ev.type == "MESH" else []:
            z = min(z, (mw @ v.co).z)
    return z


def pose_on_floor(rig, parts, pose: dict, grounded: bool, bone_map: dict):
    set_pose(rig, pose, bone_map)
    if grounded:
        dz = -lowest_point(parts)
        if abs(dz) > 1e-4:
            h = pose.get("hips", 0)
            h = [h, 0, 0] if isinstance(h, (int, float)) else list(h) + [0] * (3 - len(h))
            h[2] += dz
            p = dict(pose)
            p["hips"] = h
            set_pose(rig, p, bone_map)
    if rig.get("fist"):
        import mpfb_character
        from mathutils import Matrix
        base = Matrix.Rotation(-math.radians(float(rig.get("base_yaw", 0.0))), 3, "Z")
        mpfb_character.curl_fists(rig, base @ Vector((0, 1, 0)))


def main(argv: list[str]) -> int:
    args = [a for a in argv if not a.startswith("--")]
    only = None
    for a in argv:
        if a.startswith("--only="):
            only = set(a.split("=", 1)[1].split(","))
    spec_path = Path(args[0]).resolve()
    spec = json.loads(spec_path.read_text())
    src = spec["source"]
    base = spec_path.parent

    bpy.ops.wm.read_factory_settings(use_empty=True)
    model = src.get("model", "sample:bruiser")
    bone_map = identity_map()
    if model.startswith("sample:"):
        rig, parts, colours = sample_character.build(model.split(":", 1)[1])
    elif model == "mpfb":
        import mpfb_character
        rig, parts, colours, bone_map = mpfb_character.build(src.get("mpfb", {}))
    else:
        rig, parts, colours = sample_character.load_blend(str(base / model))
        bone_map = src.get("bone_map", bone_map)
    rig.rotation_euler.z = math.radians(float(rig.get("base_yaw", 0.0)) - float(src.get("yaw_deg", 28)))
    bpy.context.view_layer.update()

    scale, W, H = setup_scene(src)
    set_pose(rig, moves.pose("idle", 0.0), bone_map)
    height = max((ob.matrix_world @ Vector(c)).z for ob in parts for c in ob.bound_box) - lowest_point(parts)
    ppm = float(spec.get("target_height", 62)) * scale / height       # texture pixels per metre
    cam = setup_camera(src, scale, W, H, ppm)
    sc = bpy.context.scene

    # light direction: given in camera space, the shader needs it in world space
    lc = Vector(src.get("light", [-0.5, 0.7, 0.6])).normalized()
    light_world = (cam.matrix_world.to_3x3() @ lc).normalized()
    look = src.get("look", "comic")
    cel = {k: cel_material(k, c, light_world, look) for k, c in colours.items()}
    ink = outline_material((0.02, 0.018, 0.025, 1.0))
    n_mat, n_ink = normal_material(False), normal_material(True)
    thick = float(src.get("outline_px", 4)) / ppm
    for ob in parts:
        names = list(ob["part_materials"]) if "part_materials" in ob else [ob["part_material"]]
        mats = ob.data.materials                # replace in place: clearing would reset the faces' slots
        for i, n in enumerate(names):
            if i < len(mats):
                mats[i] = cel[n]
            else:
                mats.append(cel[n])
        for _ in names:                       # the shell's faces use slot index + len(names): all ink
            mats.append(ink)
        m = ob.modifiers.new("outline", "SOLIDIFY")
        m.thickness, m.offset, m.use_flip_normals, m.use_rim, m.material_offset = thick, 1.0, True, False, len(names)

    out_dir = base / "raw" / "render"
    out_dir.mkdir(parents=True, exist_ok=True)
    meta_path = out_dir / "meta.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() and only else {}
    meta.update({"scale": scale, "cell": [W, H], "anchor": [ANCHOR[0] * scale, ANCHOR[1] * scale],
                 "look": look, "ppm": ppm})
    meta.setdefault("anims", {})
    anims = {k: v for k, v in spec["animations"].items() if v.get("status") != "planned" and (only is None or k in only)}

    def frames_of(a):
        n = int(a.get("frames", 6))
        loop = bool(a.get("loop", a.get("move", "") in moves.LOOPS))
        return n, loop, [(i / n if loop else i / max(1, n - 1)) for i in range(n)]

    for name, a in anims.items():
        d = out_dir / name
        shutil.rmtree(d, ignore_errors=True)
        d.mkdir(parents=True)
        n, loop, ts = frames_of(a)
        hands, angles = [], []
        for i, t in enumerate(ts):
            pose_on_floor(rig, parts, moves.pose(a.get("move", name), t), a.get("grounded", True), bone_map)
            sc.view_settings.view_transform = "Standard"
            sc.render.filepath = str(d / f"{i:02d}.png")
            bpy.ops.render.render(write_still=True)
            fist = fist_world(rig, bone_map[WEAPON_HAND][0])
            elbow = bone_world(rig, bone_map[WEAPON_FOREARM][0], "head")
            pf, pe = to_pixels(sc, cam, fist, W, H), to_pixels(sc, cam, elbow, W, H)
            hands.append([round((pf.x - ANCHOR[0] * scale) / scale), round((pf.y - ANCHOR[1] * scale) / scale)])
            angles.append(round(math.atan2(pf.y - pe.y, pf.x - pe.x), 2))
        meta["anims"][name] = {"frames": n, "fps": a.get("fps", 12), "loop": loop, "hand": hands,
                               "weapon_angle": angles, "active": a.get("active", []),
                               "align": a.get("align", "canvas")}
        print(f"{name}: {n} frames")

    # normal maps: same poses, materials swapped, raw values (no display transform)
    for ob in parts:
        half = len(ob.material_slots) // 2
        for i, slot in enumerate(ob.material_slots):
            slot.material = n_mat if i < half else n_ink
    sc.view_settings.view_transform = "Raw"
    for name, a in anims.items():
        n, loop, ts = frames_of(a)
        for i, t in enumerate(ts):
            pose_on_floor(rig, parts, moves.pose(a.get("move", name), t), a.get("grounded", True), bone_map)
            sc.render.filepath = str(out_dir / name / f"{i:02d}_n.png")
            bpy.ops.render.render(write_still=True)
    meta_path.write_text(json.dumps(meta, indent=1) + "\n")
    print(f"rendered {len(anims)} animations to {out_dir}")
    return 0


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    sys.exit(main(argv))
