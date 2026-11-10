#!/usr/bin/env python3
"""Create the playable hero scene from a player spec and its imported sprite sheet.

    python3 tools/art/make_player.py art/characters/<id>/character.json [--out scenes/characters/player.tscn]

Run tools/art/import_character.py first. Writes:
  scenes/characters/player.tscn                  the hero every level spawns (or --out)
  resources/combos/<id>_punch_combo.tres         jab > cross > hook, timed to the hero's animations
  resources/combos/<id>_kick_combo.tres          low kick > roundhouse, timed the same way

Combo attack timing (duration and hit window) comes from sheet.json, so damage lines up with the art.
Everything else about an attack (damage, reach, knockdown, step) starts from the built-in hero's values
and can be overridden per attack in the spec, e.g. "attacks": {"hook": {"damage": 10, "reach_to": 36}}.
Hero stats (Unit/Player properties) can be overridden in "stats", e.g. {"max_hp": 110, "move_speed": 120}.
Jump, grab, throw and carry attacks are shared (resources/attacks/) because they don't depend on frame timing.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# The built-in hero's attacks, minus timing (which comes from the sheet).
COMBOS = {
    "punch": [("jab", "Jab", dict(damage=5, reach_to=30.0, knockback=1.2)),
              ("cross", "Cross", dict(damage=6, reach_to=32.0, knockback=1.6)),
              ("hook", "Hook", dict(damage=9, knockdown=True, reach_to=32.0, forward_step=48.0, hitstop_frames=3, screen_shake=4.0))],
    "kick": [("lowkick", "Low Kick", dict(damage=7, reach_to=34.0, knockback=1.6)),
             ("kick", "Roundhouse", dict(damage=12, knockdown=True, reach_to=38.0, forward_step=48.0, hitstop_frames=3, screen_shake=5.0))],
}
COMBO_SETTINGS = dict(combo_reset_time=0.37, continue_combo_on_hit=True)

# The built-in hero's scene settings; any of these (or other Unit/Player exports) can be set in "stats".
STATS = dict(move_speed=126.0, knockdown_floor_time=0.83, defence_stops_knockdown_attacks=True, max_hp=100)
NOT_SCENE_PROPS = {"max_hp", "shadow"}

SHARED = [("jump_punch", "jump_punch"), ("jump_kick", "jump_kick"), ("grab_knee", "grab_knee"),
          ("grab_knee_finisher", "grab_knee_finisher"), ("throw_attack", "throw"), ("thrown_body_hit", "thrown_body"),
          ("carry_throw_attack", "prop_hit")]


def gd(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, str):
        return f'"{v}"'
    return str(v)


def timing(meta: dict, anim: str) -> dict:
    if anim not in meta["anims"]:
        raise SystemExit(f"animation '{anim}' is not in the sheet ({', '.join(meta['anims'])}) - re-run import_character.py")
    a = meta["anims"][anim]
    tpf, n = a["ticks_per_frame"], a["frames"]
    a0, a1 = a.get("active_frames", [n // 3, max(n // 3, (2 * n) // 3 - 1)])
    return dict(duration=round(n * tpf / 60, 2), active_from=round(a0 * tpf / 60, 2), active_to=round((a1 + 1) * tpf / 60, 2))


def write_combo(cid: str, which: str, meta: dict, overrides: dict) -> tuple[Path, list[str]]:
    lines = [f'[gd_resource type="Resource" script_class="ComboData" load_steps={len(COMBOS[which]) + 3} format=3]', "",
             '[ext_resource type="Script" path="res://scripts/combat/attack_data.gd" id="1"]',
             '[ext_resource type="Script" path="res://scripts/combat/combo_data.gd" id="2"]', ""]
    report = []
    for anim, name, props in COMBOS[which]:
        p = dict(props)
        p.update(timing(meta, anim))
        p.update(overrides.get(anim, {}))
        lines += [f'[sub_resource type="Resource" id="{anim}"]', 'script = ExtResource("1")',
                  f'attack_name = "{p.pop("attack_name", name)}"', f'animation = &"{anim}"']
        lines += [f"{k} = {gd(v)}" for k, v in p.items()]
        lines.append("")
        report.append(f"{anim} {p['duration']}s hits {p['active_from']}-{p['active_to']}s dmg {p['damage']}")
    ids = ", ".join(f'SubResource("{anim}")' for anim, _, _ in COMBOS[which])
    lines += ["[resource]", 'script = ExtResource("2")'] + [f"{k} = {gd(v)}" for k, v in COMBO_SETTINGS.items()]
    lines += [f'attacks = Array[ExtResource("1")]([{ids}])', ""]
    path = ROOT / "resources/combos" / f"{cid}_{which}_combo.tres"
    path.write_text("\n".join(lines))
    return path, report


def main(spec_path: Path, out: Path) -> int:
    spec = json.loads(spec_path.read_text())
    cid = spec["id"]
    if spec.get("role") != "player":
        raise SystemExit("make_player.py builds the hero from a spec with \"role\": \"player\"; use make_enemy.py for enemies")
    sheet_json = ROOT / "assets/characters" / cid / "sheet.json"
    if not sheet_json.exists():
        raise SystemExit(f"{sheet_json.relative_to(ROOT)} not found - run tools/art/import_character.py first")
    meta = json.loads(sheet_json.read_text())
    stats = dict(STATS)
    stats.update(spec.get("stats", {}))
    overrides = spec.get("attacks", {})

    combos = {w: write_combo(cid, w, meta, overrides) for w in COMBOS}

    ext = [("Script", "res://scripts/characters/player.gd"), ("Script", "res://scripts/core/sprite_animator.gd"),
           ("Script", "res://scripts/core/unit_shadow.gd"), ("Script", "res://scripts/systems/health_system.gd"),
           ("Resource", f"res://resources/combos/{cid}_punch_combo.tres"), ("Resource", f"res://resources/combos/{cid}_kick_combo.tres")]
    ext += [("Resource", f"res://resources/attacks/{f}.tres") for _, f in SHARED]
    ext += [("Texture2D", f"res://assets/characters/{cid}/portrait.png"), ("Texture2D", f"res://assets/characters/{cid}/sheet.png")]
    rid = {p: str(i) for i, (_, p) in enumerate(ext, 1)}
    R = lambda p: f'ExtResource("{rid[p]}")'

    lines = [f"[gd_scene load_steps={len(ext) + 1} format=3]", ""]
    lines += [f'[ext_resource type="{t}" path="{p}" id="{rid[p]}"]' for t, p in ext]
    lines += ["", '[node name="Player" type="Node2D"]', f'script = {R("res://scripts/characters/player.gd")}', "team = 0",
              f'unit_name = "{spec.get("display_name", cid)}"', f'portrait = {R(f"res://assets/characters/{cid}/portrait.png")}']
    lines += [f"{k} = {gd(v)}" for k, v in stats.items() if k not in NOT_SCENE_PROPS]
    lines += [f'punch_combo = {R(f"res://resources/combos/{cid}_punch_combo.tres")}',
              f'kick_combo = {R(f"res://resources/combos/{cid}_kick_combo.tres")}']
    lines += [f'{prop} = {R(f"res://resources/attacks/{f}.tres")}' for prop, f in SHARED]
    lines += ["", '[node name="Shadow" type="Node2D" parent="."]', f'script = {R("res://scripts/core/unit_shadow.gd")}']
    if "shadow" in stats:
        lines.append(f"radius = Vector2({stats['shadow'][0]}, {stats['shadow'][1]})")
    lines += ["", '[node name="Body" type="Sprite2D" parent="."]', f'texture = {R(f"res://assets/characters/{cid}/sheet.png")}',
              "centered = false", f"offset = Vector2(-{meta['anchor'][0]}, -{meta['anchor'][1]})", "region_enabled = true",
              f"region_rect = Rect2(0, 0, {meta['cell'][0]}, {meta['cell'][1]})", f'script = {R("res://scripts/core/sprite_animator.gd")}',
              f'sheet_json = "res://assets/characters/{cid}/sheet.json"',
              "", '[node name="HealthSystem" type="Node" parent="."]', f'script = {R("res://scripts/systems/health_system.gd")}']
    if stats["max_hp"] != 100:
        lines += [f"max_hp = {int(stats['max_hp'])}", f"current_hp = {int(stats['max_hp'])}"]
    lines.append("")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines))
    print(f"[{cid}] wrote {out.relative_to(ROOT)} ({spec.get('display_name', cid)}, {int(stats['max_hp'])} HP, speed {stats['move_speed']})")
    for which, (path, report) in combos.items():
        print(f"  {path.relative_to(ROOT)}: " + "; ".join(report))
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    out = ROOT / "scenes/characters/player.tscn"
    if "--out" in args:
        i = args.index("--out")
        out = (Path.cwd() / args[i + 1]).resolve()
        del args[i:i + 2]
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(Path(args[0]).resolve(), out))
