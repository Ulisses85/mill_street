#!/usr/bin/env python3
"""Create a playable enemy (or boss) scene from a character spec and its imported sprite sheet.

    python3 tools/art/make_enemy.py art/characters/<id>/character.json

Run tools/art/import_character.py first. Writes:
  scenes/characters/<id>.tscn              the enemy, ready to drop into a Wave
  resources/attacks/<id>_attack.tres       its attack, timed to the imported animation

Stats start from a preset (thug / brute / boss) and can be overridden in the spec's "stats" block:
  max_hp, move_speed, defend_chance, attack_damage, attack_reach, attack_knockdown, windup_time,
  attack_cooldown_min, attack_cooldown_max, score_value, can_pick_up_weapons, drop_health_chance,
  attack_knockback, attack_hitstop
To place it in a level, add ("<id>", x, y, fov) to a wave in tools/make_levels.py and re-run that.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

PRESETS = {
    "thug": dict(max_hp=30, move_speed=63.0, hit_stun_time=0.27, knockdown_floor_time=0.67, body_half_width=9.0, body_height=58.0,
                 windup_time=0.27, attack_cooldown_min=0.85, attack_cooldown_max=1.5, defend_chance=18, wait_distance=70.0,
                 score_value=200, can_pick_up_weapons=True, drop_health_chance=0.25, drop_health_amount=15, drop="can",
                 attack_damage=7, attack_reach=28.0, attack_knockdown=False, shadow=(14, 3.5)),
    "brute": dict(max_hp=70, move_speed=39.0, hit_stun_time=0.27, knockdown_floor_time=0.75, knockdown_height=14.0, knockdown_distance=40.0,
                  body_half_width=11.0, body_height=72.0, windup_time=0.43, attack_cooldown_min=1.17, attack_cooldown_max=1.83,
                  defend_chance=30, wait_distance=80.0, score_value=500, can_pick_up_weapons=False, drop_health_chance=1.0,
                  drop_health_amount=35, drop="chips", attack_damage=14, attack_reach=40.0, attack_knockdown=True, shadow=(17, 4)),
    "boss": dict(max_hp=200, move_speed=50.0, hit_stun_time=0.22, knockdown_floor_time=0.9, knockdown_height=12.0, knockdown_distance=34.0,
                 body_half_width=13.0, body_height=84.0, windup_time=0.4, attack_cooldown_min=0.7, attack_cooldown_max=1.2,
                 defend_chance=35, wait_distance=90.0, score_value=4000, can_pick_up_weapons=False, drop_health_chance=0.0,
                 drop_health_amount=0, drop=None, attack_damage=18, attack_reach=48.0, attack_knockdown=True, is_boss=True,
                 super_armor=True, alert_delay=0.3, shadow=(20, 5)),
}

# Unit/Enemy properties copied from the stats into the scene when present
SCENE_PROPS = ["move_speed", "hit_stun_time", "knockdown_floor_time", "knockdown_height", "knockdown_distance", "body_half_width",
               "body_height", "windup_time", "attack_cooldown_min", "attack_cooldown_max", "defend_chance", "wait_distance",
               "score_value", "can_pick_up_weapons", "drop_health_chance", "drop_health_amount", "is_boss", "super_armor", "alert_delay"]


def gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        return f'"{v}"'
    return str(v)


def main(spec_path: Path) -> int:
    spec = json.loads(spec_path.read_text())
    cid = spec["id"]
    role = spec.get("role", "enemy")
    if role == "player":
        raise SystemExit("make_enemy.py builds enemies and bosses; use the player tools for heroes")
    preset = spec.get("preset", "boss" if role == "boss" else "thug")
    stats = dict(PRESETS[preset])
    stats.update(spec.get("stats", {}))
    sheet_json = ROOT / "assets/characters" / cid / "sheet.json"
    if not sheet_json.exists():
        raise SystemExit(f"{sheet_json.relative_to(ROOT)} not found - run tools/art/import_character.py first")
    meta = json.loads(sheet_json.read_text())
    anim = spec.get("attack_animation", "punch")
    if anim not in meta["anims"]:
        raise SystemExit(f"attack animation '{anim}' is not in the sheet ({', '.join(meta['anims'])})")
    a = meta["anims"][anim]
    tpf = a["ticks_per_frame"]
    a0, a1 = a.get("active_frames", [a["frames"] // 3, (2 * a["frames"]) // 3])
    duration = round(a["frames"] * tpf / 60, 2)
    act_from, act_to = round(a0 * tpf / 60, 2), round((a1 + 1) * tpf / 60, 2)

    atk_path = ROOT / "resources/attacks" / f"{cid}_attack.tres"
    atk_path.write_text("\n".join([
        '[gd_resource type="Resource" script_class="AttackData" load_steps=2 format=3]', "",
        '[ext_resource type="Script" path="res://scripts/combat/attack_data.gd" id="1"]', "",
        "[resource]", 'script = ExtResource("1")',
        f'attack_name = "{spec.get("display_name", cid)} Attack"',
        f"damage = {int(stats['attack_damage'])}",
        f"knockdown = {gd(bool(stats['attack_knockdown']))}",
        f'animation = &"{anim}"',
        f"duration = {duration}", f"active_from = {act_from}", f"active_to = {act_to}",
        f"reach_to = {float(stats['attack_reach'])}",
        f"screen_shake = {5.0 if stats['attack_knockdown'] else 2.0}",
        f"hitstop_frames = {int(stats.get('attack_hitstop', 4 if role == 'boss' else 3))}"]
        + ([f"knockback = {float(stats['attack_knockback'])}"] if "attack_knockback" in stats else []) + [""]))

    ext = [("Script", "res://scripts/characters/enemy.gd"), ("Script", "res://scripts/core/sprite_animator.gd"),
           ("Script", "res://scripts/core/unit_shadow.gd"), ("Script", "res://scripts/systems/health_system.gd"),
           ("Resource", f"res://resources/attacks/{cid}_attack.tres"), ("Texture2D", f"res://assets/characters/{cid}/portrait.png"),
           ("Texture2D", f"res://assets/characters/{cid}/sheet.png")]
    if stats.get("drop") and stats.get("drop_health_chance", 0) > 0:
        ext.append(("Texture2D", f"res://assets/items/{stats['drop']}.png"))
    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""]
    lines += [f'[ext_resource type="{t}" path="{p}" id="{i}"]' for i, (t, p) in enumerate(ext, 1)]
    node = "".join(w.title() for w in cid.split("_"))
    lines += ["", f'[node name="{node}" type="Node2D"]', 'script = ExtResource("1")',
              f'unit_name = "{spec.get("display_name", cid)}"', 'portrait = ExtResource("6")', "start_direction = -1",
              'attack = ExtResource("5")']
    if role != "boss" and preset != "boss" and spec.get("random_names", True):
        lines.append('random_name_file = "res://resources/enemy_names.txt"')
    for k in SCENE_PROPS:
        if k in stats and k not in ("drop_health_amount",) or (k == "drop_health_amount" and len(ext) == 8):
            lines.append(f"{k} = {gd(stats[k])}")
    if len(ext) == 8:
        lines.append('drop_health_texture = ExtResource("8")')
    sx, sy = stats["shadow"]
    hp = int(stats["max_hp"])
    lines += ["", '[node name="Shadow" type="Node2D" parent="."]', 'script = ExtResource("3")', f"radius = Vector2({sx}, {sy})",
              "", '[node name="Body" type="Sprite2D" parent="."]', 'texture = ExtResource("7")', "centered = false",
              f"offset = Vector2(-{meta['anchor'][0]}, -{meta['anchor'][1]})", "region_enabled = true",
              f"region_rect = Rect2(0, 0, {meta['cell'][0]}, {meta['cell'][1]})", 'script = ExtResource("2")',
              f'sheet_json = "res://assets/characters/{cid}/sheet.json"',
              "", '[node name="HealthSystem" type="Node" parent="."]', 'script = ExtResource("4")', f"max_hp = {hp}", f"current_hp = {hp}", ""]
    scene = ROOT / "scenes/characters" / f"{cid}.tscn"
    scene.write_text("\n".join(lines))
    print(f"[{cid}] wrote {scene.relative_to(ROOT)} ({preset} preset, {hp} HP) and {atk_path.relative_to(ROOT)}")
    print(f"  attack '{anim}': duration {duration}s, hits {act_from}-{act_to}s, reach {stats['attack_reach']}px, damage {stats['attack_damage']}")
    print(f'  place it: add ("{cid}", x, y, True) to a wave in tools/make_levels.py, then python3 tools/make_levels.py')
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(Path(sys.argv[1]).resolve()))
