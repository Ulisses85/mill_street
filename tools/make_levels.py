"""Writes scenes/levels/<id>.tscn from art/levels/<id>/level.json.

Each spec holds the level's art folder, music, length, waves (bound x + enemies), props and floor pickups.
Enemy: [scene, x, y, fov]  fov=false means it runs in when its wave starts.
The parallax layers come from assets/levels/<art>/layout.json, written by tools/levels/level_kit.py
from the same spec. Run the kit first when the look changes, then this:
    python3 tools/levels/level_kit.py && python3 tools/make_levels.py
You can also edit the generated scenes in the Godot editor; just don't re-run this script afterwards.
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

def load_levels() -> list[dict]:
    """One spec per level: art/levels/<id>/level.json (background, waves, pickups, props)."""
    out = []
    for spec in sorted((ROOT / "art/levels").glob("*/level.json")):
        d = json.loads(spec.read_text())
        out.append(dict(file=d["id"], name="Level" + d["id"].split("_")[-1], art=d["art"], music=d["music"],
                        world=d["world"], waves=[(w["bound"], [tuple(e) for e in w["enemies"]]) for w in d["waves"]],
                        pickups=[tuple(p) for p in d["pickups"]], props=[tuple(p) for p in d["props"]]))
    return out


HEAL = {"can": 15, "chips": 35}


def build(lv: dict) -> str:
    ext = []
    ids = {}

    def ref(kind: str, path: str) -> str:
        if path not in ids:
            ids[path] = str(len(ext) + 1)
            ext.append(f'[ext_resource type="{kind}" path="{path}" id="{ids[path]}"]')
        return f'ExtResource("{ids[path]}")'

    art = f"res://assets/levels/{lv['art']}"
    nodes = []
    nodes.append(f'''[node name="{lv['name']}" type="Node2D"]
script = {ref("Script", "res://scripts/core/level.gd")}
walk_area = Rect2(0, 164, {lv['world']}, 82)
layout_json = "{art}/layout.json"
signpost_texture = {ref("Texture2D", art + "/signpost.png")}
music = &"{lv['music']}"
''')
    layout = ROOT / "assets/levels" / lv["art"] / "layout.json"
    layers = json.loads(layout.read_text()).get("layers", []) if layout.exists() else []
    for L in sorted(layers, key=lambda l: l["order"]):
        if L["parallax"] == 1.0:
            continue                          # the street itself is the Background sprite below
        node = L["layer_id"].title()
        nodes.append(f'''[node name="{node}" type="Parallax2D" parent="."]
scroll_scale = Vector2({L["parallax"]}, 1)
scroll_offset = Vector2({L["offset_x"]}, {L["offset_y"]})
repeat_size = Vector2({L["width"] if L["repeat_x"] else 0}, 0)
repeat_times = 2
''')
        nodes.append(f'''[node name="Sprite" type="Sprite2D" parent="{node}"]
texture = {ref("Texture2D", L["asset_ref"])}
centered = false
''')
    nodes.append(f'''[node name="Background" type="Sprite2D" parent="."]
texture = {ref("Texture2D", art + "/background.png")}
centered = false
''')
    nodes.append('[node name="World" type="Node2D" parent="."]\ny_sort_enabled = true\n')
    nodes.append(f'[node name="Player" parent="World" instance={ref("PackedScene", "res://scenes/characters/player.tscn")}]\nposition = Vector2(80, 205)\n')
    for i, (kind, x, y, drop) in enumerate(lv["props"], 1):
        s = f'[node name="{kind.title()}{i}" parent="World" instance={ref("PackedScene", f"res://scenes/props/{kind}.tscn")}]\nposition = Vector2({x}, {y})\n'
        s += f'texture = {ref("Texture2D", f"{art}/{kind}.png")}\ndamaged_texture = {ref("Texture2D", f"{art}/{kind}_damaged.png")}\n'
        if drop in HEAL:
            s += f'spawn_health_texture = {ref("Texture2D", f"res://assets/items/{drop}.png")}\nspawn_health_amount = {HEAL[drop]}\n'
        else:
            s += f'spawn_weapon = {ref("Resource", f"res://resources/weapons/{drop}.tres")}\n'
        nodes.append(s)
    for i, (w, x, y) in enumerate(lv["pickups"], 1):
        nodes.append(f'''[node name="Pickup{i}" type="Node2D" parent="World"]
position = Vector2({x}, {y})
script = {ref("Script", "res://scripts/systems/pickup.gd")}
kind = 1
weapon = {ref("Resource", f"res://resources/weapons/{w}.tres")}
''')
    nodes.append(f'[node name="WaveManager" type="Node2D" parent="World"]\ny_sort_enabled = true\nscript = {ref("Script", "res://scripts/systems/wave_manager.gd")}\n')
    n = 0
    for wi, (bound, enemies) in enumerate(lv["waves"], 1):
        nodes.append(f'[node name="Wave{wi}" type="Node2D" parent="World/WaveManager"]\ny_sort_enabled = true\nscript = {ref("Script", "res://scripts/systems/wave.gd")}\n')
        for (scene, x, y, fov) in enemies:
            n += 1
            s = f'[node name="{scene.split("_")[-1].title()}{n}" parent="World/WaveManager/Wave{wi}" instance={ref("PackedScene", f"res://scenes/characters/{scene}.tscn")}]\nposition = Vector2({x}, {y})\n'
            s += "enable_fov = false\n" if not fov else f"start_direction = {1 if n % 2 else -1}\n"
            nodes.append(s)
        nodes.append(f'[node name="LevelBound" type="Marker2D" parent="World/WaveManager/Wave{wi}"]\nposition = Vector2({bound}, 0)\nscript = {ref("Script", "res://scripts/systems/level_bound.gd")}\n')
    nodes.append('[node name="Foreground" type="Node2D" parent="."]\nz_index = 50\n')
    nodes.append(f'[node name="BeatCamera" type="Camera2D" parent="."]\nscript = {ref("Script", "res://scripts/systems/beat_camera.gd")}\nview_area = Rect2(0, 0, {lv["world"]}, 270)\n')
    nodes.append('[node name="HUD" type="CanvasLayer" parent="."]\n')
    nodes.append(f'''[node name="HUDRoot" type="Control" parent="HUD"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
script = {ref("Script", "res://scripts/ui/hud.gd")}
''')
    nodes.append(f'[node name="TouchControls" type="CanvasLayer" parent="."]\nscript = {ref("Script", "res://scripts/ui/touch_controls.gd")}\n')
    nodes.append(f'[node name="LevelMenus" parent="." instance={ref("PackedScene", "res://scenes/ui/level_menus.tscn")}]\n')
    return f'[gd_scene load_steps={len(ext) + 1} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(nodes)


for lv in load_levels():
    (ROOT / "scenes/levels" / f"{lv['file']}.tscn").write_text(build(lv))
    print("wrote", lv["file"])
