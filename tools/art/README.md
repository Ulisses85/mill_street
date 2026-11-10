# Art pipeline (AI or hand-made art → game)

```
idea ──► character.json ──► generate (PixelLab MCP / Retro Diffusion) ──► raw/  ──► import_character.py ──► assets/characters/<id>/
                                                                                       │
                                                       make_enemy.py ◄─────────────────┘──► scenes/characters/<id>.tscn ──► make_levels.py ──► bot test
```

In Claude Code, the skills in `.claude/skills/` run this whole flow: `/ideate`, `/new-enemy`, `/new-hero` and `/character-art`.

## 1. A character spec: `art/characters/<id>/character.json`

```json
{
  "id": "bouncer",                       // file and scene name (snake_case)
  "display_name": "Bouncer",
  "role": "enemy",                       // enemy | boss | player
  "preset": "brute",                     // starting stats: thug | brute | boss
  "concept": "Nightclub doorman ...",    // the idea, in words
  "target_height": 70,                   // standing height in game pixels (thug 58, brute 72, boss 84-92)
  "source_facing": "right",              // which way the raw art faces (left gets mirrored)
  "attack_animation": "smash",           // the enemy's attack animation name
  "background": "auto",                  // auto (detect solid colour) | none (art already transparent) | "#00ff00"
  "palette": { "max_colors": 20, "outline": "#300408", "lock": ["#ff3a2a"] },   // outline/lock optional
  "stats": { "max_hp": 90, "defend_chance": 45, "attack_damage": 15 },           // overrides the preset
  "generator": { "provider": "pixellab", "prompt": "...", "animations_requested": ["idle", "walk", "attack", "hurt"] },
  "animations": {
    "idle":  { "source": "raw/idle", "fps": 8, "loop": true },                    // folder of frames
    "walk":  { "source": "raw/walk_strip.png", "frames": 8, "fps": 12, "loop": true },   // strip (or "grid": [4, 2])
    "smash": { "source": "raw/attack.gif", "fps": 20, "active": [4, 6] },         // GIF; active = hit frames
    "hurt":  { "source": "raw/hurt.png", "fps": 8 },                              // single image
    "down":  { "source": "raw/down", "fps": 10, "align": "canvas" }               // align canvas: see below
  }
}
```

Each frame is normally placed with its own feet on the anchor. `"align": "canvas"` keeps the offset from the source canvas instead (the reference idle frame's), so a fall, a lying pose and a get-up generated on the same canvas line up with each other. Use it for knockdown, down and getup.

The source formats are a folder of PNGs, a strip or grid PNG (with `frames`, or split automatically on empty columns) or a GIF.

## 2. Import: `python3 tools/art/import_character.py art/characters/<id>/character.json`

`pip install -r tools/art/requirements.txt` before importing art. It pins Pillow: CI rebuilds every character and fails if the committed sheets differ byte for byte, and a different Pillow version can change the palette.

For each frame, the importer:
- removes the background
- scales to `target_height`, using the first `idle` frame as the reference
- places the feet on the template anchor (cell 160×128, feet at 80,116)
- reduces every frame to one shared palette and adds an optional outline
- estimates the weapon-bone hand position

It writes the following, and exits 1 if a required animation is missing with no fallback:
- `assets/characters/<id>/sheet.png`, `sheet.json` and `portrait.png`
- `art/characters/<id>/preview/contact.png` and one `<anim>.gif` per animation
- `import_report.json`

**Synthesized animations.** The template needs 12–15 animations for an enemy and 23 for the player. Anything you don't supply is built from what you did:

| Needed | Built from |
|---|---|
| knockdown, down, getup | `hurt` rotated to the floor and back (same motion as the built-in fighters) |
| run / walk | each other, re-timed |
| lurk | `idle`, slowed |
| windup | the attack's lead-in: from the first frame that differs from every idle pose up to the frame before `active`, played once. Those frames are then trimmed from the start of the attack (and `active` shifted) so the attack opens on the hit. Falls back to the attack's first frame |
| defend | `block` if given, else first `idle` frame |
| grabbed | `hurt` |
| pickup | `idle` squashed into a crouch |
| swing (armed thugs) | the attack |
| player: combo slots `punch_1`–`punch_3`, `kick_1`, `kick_2`; `jump_punch`, `jump_kick`, grab, grab_knee, throw, toss, carry | `punch` and `kick` (copies, held active frames), `walk`/`idle`. A hero's `kick` becomes `kick_2`, the kick finisher |

The minimum useful set is **idle, walk, attack and hurt**. For a hero, add **punch and kick**: one main attack per combo, in any style. The combo slots are IDs, not moves; see the `new-hero` skill. Give a separate `block`, `knockdown` or `jump` and it's used instead of the fallback.

The importer also prints each attack's timing (duration and hit window). `make_enemy.py` uses those numbers so damage lines up with the animation.

## 3. Make it playable: `python3 tools/art/make_enemy.py art/characters/<id>/character.json`

This writes `scenes/characters/<id>.tscn` and `resources/attacks/<id>_attack.tres`. Stats come from the preset plus the spec's `stats` overrides.

To place the enemy, add `("<id>", x, y, fov)` to a wave in `tools/make_levels.py`, then run `python3 tools/make_levels.py`.

**A hero** (`"role": "player"`) uses `python3 tools/art/make_player.py art/characters/<id>/character.json` instead. It writes:
- `scenes/characters/player.tscn`, the hero every level spawns. Use `--out` to write somewhere else.
- `resources/combos/<id>_punch_combo.tres`: `punch_1` > `punch_2` > `punch_3` (the finisher, knocks down).
- `resources/combos/<id>_kick_combo.tres`: `kick_1` > `kick_2` (the finisher).

Each combo attack's duration and hit window come from the sheet. Damage, reach, knockdown and step start from the built-in hero's values. You can override them per attack in the spec, for example `"attacks": {"punch_3": {"attack_name": "Uppercut", "damage": 10}}`. Specs that still use the old names (`jab`, `cross`, `hook`, `lowkick`, `jpunch`, `jkick`) keep working; the tools print a rename hint. You can override hero stats in `stats`, for example `max_hp` or `move_speed`. The jump, grab, throw and carry attacks are shared. The built-in Max scene is in git history if you want him back.

## 4. Check it

```
godot --headless --path . --import && godot --headless --path . --import
GODOT=godot tests/run_bot.sh god     # every level still finishable
GODOT=godot tests/run_bot.sh         # balance report
```

## Providers

**PixelLab** (subscription): use its MCP server in Claude Code. Characters with 4 or 8 directions; animate idle, walk, run, attack and more.

```
claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H "Authorization: Bearer $PIXELLAB_API_KEY"
```

Use the side view. Keep only the east-facing (right) direction, then save the frames or the sheet into `raw/<anim>`. Jobs return an ID; poll until they're done.

**Retro Diffusion** (pay per image, about $0.02–0.25): use `tools/art/retrodiffusion.py`, with `RD_API_KEY` set.
- `--check-cost` gives a free price quote.
- Useful styles: `rd_pro__spritesheet`, `rd_advanced_animation__walking` (needs `--input-image`, a first frame) and `rd_tile__scene_object`.
- `--palette` locks output to a palette PNG. `--remove-bg` gives transparent output.

**By hand:** draw in Aseprite or similar and export frames or a strip. The importer doesn't care where the art came from.

## Test without an API key

`python3 tools/art/examples/fake_provider.py` writes stand-in "AI output" for the Bouncer:
- 3× scale on a green background
- a different file format per animation

Then run the import and make_enemy steps on `art/characters/bouncer/character.json`.
