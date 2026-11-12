---
name: new-enemy
description: Build a new enemy or boss end to end - spec, AI-generated art, import into sprite sheets, Godot scene, placement in a level, bot test and screenshots. Use when the user wants to add an enemy or boss to the game.
---

# New enemy

Read `CLAUDE.md` and `tools/art/README.md` first. Work on a branch (`git checkout -b enemy/<id>`).

## 1. Spec
If there's no `art/characters/<id>/character.json`, run the `ideate` skill or write one with the user.

## 2. Generate the art
Follow the `character-art` skill for the provider (PixelLab MCP or Retro Diffusion).
- Generate one base character, side view, facing right.
- Animations: **idle, walk, attack, hurt** at minimum. Optionally block and knockdown.
- Save everything the provider returns into `art/characters/<id>/raw/`: frames in a folder, a strip, or a GIF. Fill in `animations` in the spec with each `source`, `fps` and (for the attack) `active` hit frames.
- Before spending credits, tell the user what you'll generate and roughly what it costs.

## 3. Import and review
```
python3 tools/art/import_character.py art/characters/<id>/character.json
```
- Read the output: synthesized animations, warnings and missing animations.
- **Look at** `art/characters/<id>/preview/contact.png`. Check:
  - the size matches other enemies
  - the feet are on the same line in every frame
  - the background is fully gone
  - nothing touches the cell edge
- Fix by adjusting `target_height`, `background`, `fps`, `active`, `frames`/`grid`, or by regenerating one animation. Then re-import.

## 4. Make it playable
```
python3 tools/art/make_enemy.py art/characters/<id>/character.json
```
Then add `("<id>", x, y, True)` to a wave in `tools/make_levels.py`. Use `False` for an enemy that runs in from off screen. Run `python3 tools/make_levels.py`.

## 5. Test
```
godot --headless --path . --import && godot --headless --path . --import    # no SCRIPT ERROR
GODOT=godot tests/run_bot.sh god                                            # must pass
GODOT=godot tests/run_bot.sh                                                # balance: note deaths / hits taken
```
- Take screenshots of the fight: `xvfb-run godot --path . --rendering-driver opengl3 --resolution 480x270 --fixed-fps 60 res://tests/sim.tscn -- <level> shots=<frames> quiet`. Look at them.
- Tune `stats` in the spec, then re-run `make_enemy.py`, if the enemy is too easy or too hard.

## 6. Hand over
Commit (scene, attack, sheet, spec, raw art, previews). Tell the user:
- what was generated and what was synthesized
- where the enemy appears
- the balance numbers
- anything to playtest by hand (F7 shows hitboxes; F3 skips a wave)

## Special moves (optional)
Any enemy can get these through its spec's `stats` (copied into the scene by `make_enemy.py`): `dodge_chance` (0–100, backsteps out of the player's attacks), `grab_chance` (grabs and slams; the player mashes to escape; `grab_hold_time`), `special_cooldown`, `rage_at` (share of health where it speeds up). Charges (`charge_attack`) and throws (`throw_weapon`) need a resource, so set them on the scene in the Inspector (see the three bosses). Generate `charge`, `throw` or `grab` animations to give them their own art; until then they borrow `walk`, the attack and `windup`. Run the balance report after adding any of these.

## Planned specs and bosses
A spec with `"status": "planned"` has its look, prompts and stats written but no art yet: the importer, `make_enemy.py` and CI skip it. The three bosses (`art/characters/boss_*`) start like this. To make one real:
1. Generate on PixelLab's 96px canvas (bosses are 76-90 px tall) from the spec's `generator.prompt`, base first in the fighting stance, then every animation in `animations_requested` from the stance start frame (`animation_notes` says what each move is). About 20 generations a boss.
2. Fill `animations` like `art/characters/brute/character.json`, set `target_height` to the base's real height, delete `status`.
3. `import_character.py` then `make_enemy.py`: the scene keeps its special moves through the spec's `moves` block (charge, knife throw, grab slam) and its stats.
4. Bot tests (`tests/run_bot.sh` too, bosses decide the balance) and screenshots.

