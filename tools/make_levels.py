"""Writes scenes/levels/level_0N.tscn from the layouts below.

Each level: art folder, music, length, waves (bound x + enemies), props and floor pickups.
Enemy tuple: (scene, x, y, fov)  fov=False means it runs in when its wave starts.
Re-run after editing:  python3 tools/make_levels.py
You can also edit the generated scenes in the Godot editor; just don't re-run this script afterwards.
"""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

LEVELS = [
    dict(file="level_01", name="Level01", art="street", music="music_street", world=2600,
         waves=[(700, [("thug", 500, 190, True), ("thug", 560, 228, True), ("thug", 760, 200, False)]),
                (1300, [("thug", 1040, 186, True), ("thug", 1130, 230, True), ("thug", 1360, 200, False), ("thug", 1400, 222, False)]),
                (1900, [("brute", 1640, 200, True), ("thug", 1700, 180, True), ("thug", 1960, 226, False), ("thug", 2000, 196, False)]),
                (2600, [("boss_foreman", 2420, 206, True), ("thug", 2300, 184, True), ("thug", 2590, 236, False)])],
         pickups=[("pipe", 990, 214), ("bat", 1560, 196)],
         props=[("crate", 620, 176, "can"), ("barrel", 1460, 236, "chips"), ("crate", 2180, 200, "knife")]),
    dict(file="level_02", name="Level02", art="wharf", music="music_wharf", world=2900,
         waves=[(720, [("thug", 520, 196, True), ("thug", 600, 230, True), ("thug", 780, 186, False)]),
                (1220, [("brute", 1060, 206, True), ("thug", 1120, 178, True), ("thug", 1280, 230, False)]),
                (1720, [("thug", 1540, 190, True), ("thug", 1600, 226, True), ("thug", 1780, 200, False), ("thug", 1800, 176, False)]),
                (2220, [("brute", 2020, 196, True), ("thug", 2080, 230, True), ("brute", 2290, 210, False)]),
                (2900, [("boss_bookie", 2700, 206, True), ("thug", 2600, 182, True), ("thug", 2880, 230, False), ("thug", 2890, 190, False)])],
         pickups=[("knife", 760, 220), ("pipe", 1500, 190), ("bat", 2300, 226)],
         props=[("crate", 620, 236, "can"), ("crate", 1200, 176, "knife"), ("barrel", 1820, 210, "chips"), ("crate", 2420, 190, "can")]),
    dict(file="level_03", name="Level03", art="market", music="music_market", world=3200,
         waves=[(700, [("thug", 500, 186, True), ("thug", 560, 226, True), ("brute", 760, 206, False)]),
                (1200, [("thug", 1020, 190, True), ("thug", 1080, 230, True), ("thug", 1260, 178, False), ("thug", 1280, 214, False)]),
                (1700, [("brute", 1520, 196, True), ("brute", 1580, 230, True), ("thug", 1760, 186, False)]),
                (2200, [("thug", 2000, 186, True), ("thug", 2060, 226, True), ("thug", 2080, 200, True), ("brute", 2270, 210, False)]),
                (2700, [("brute", 2500, 190, True), ("brute", 2560, 230, True), ("thug", 2760, 200, False), ("thug", 2780, 180, False)]),
                (3200, [("boss_landlord", 3000, 206, True), ("brute", 2900, 186, True), ("thug", 3180, 230, False)])],
         pickups=[("bat", 700, 230), ("knife", 1300, 180), ("pipe", 2000, 214), ("bat", 2600, 196)],
         props=[("barrel", 560, 186, "can"), ("crate", 1100, 228, "chips"), ("crate", 1700, 180, "knife"), ("barrel", 2200, 232, "chips"), ("crate", 2760, 200, "can")]),
]

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


for lv in LEVELS:
    (ROOT / "scenes/levels" / f"{lv['file']}.tscn").write_text(build(lv))
    print("wrote", lv["file"])
