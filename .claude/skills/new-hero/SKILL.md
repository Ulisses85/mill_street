---
name: new-hero
description: Build a new player hero end to end - spec, AI-generated art in a fighting stance, frame-picked combos, import, make_player.py, bot balance against the built-in hero, screenshots. Use when the user wants a new or replacement player character.
---

# New hero

Read `CLAUDE.md` and `tools/art/README.md` first. Work on a branch off `main` (`git checkout -b hero/<id>`).
Reference hero: `art/characters/del/character.json` (Del, the retired boxer).

## 1. Spec
If there's no `art/characters/<id>/character.json`, run the `ideate` skill or write one with the user.
- `role: "player"`, `target_height` about 58–62 (enemies: thug 58, Biker 62).
- Give the hero an identity against the built-in hero (Max: 100 HP, speed 126, jab/cross/hook 5/6/9, low kick/roundhouse 7/12). Override in `stats` and per attack in `attacks` (`damage`, `reach_to`, ...).
- Readability: the hero must be easy to find in a crowd of red/black enemies. Distinct colours, not necessarily white.

## 2. Generate the art (quote the cost first, ask before every retry)
Follow the `character-art` skill. For a hero:
- **Base character in the fighting stance** (guard), side view, facing right. PixelLab animations start from the base pose; an arms-down base makes idle and walk drop out of the stance.
- If the base isn't in stance: take the stance frame from idle and pass it as the **start frame** (`get_upload_url` → `custom_start_frame_url`) for walk and any other looping animation.
- Animations: **idle, walk, punch, kick, hurt, block**. Optional: jump (otherwise the jump attacks reuse a punch/kick frame).
- Name the direction of every strike in the prompt ("forward, in the direction he is facing").
- Show the user the base character before animating it.
- Typical cost (PixelLab, right-facing only): base 2 + 2 per 8-frame animation ≈ 14 generations.

## 3. Build the combo from frame picks (free)
One generated punch gives the whole jab > cross > hook combo; one kick gives low kick > roundhouse. Copy frame ranges into `raw/jab`, `raw/cross`, `raw/hook`, `raw/lowkick` and add them to `animations` with `fps` and `active`:
- jab: the last few frames of the punch (fast, hits ~0.07 s)
- cross: from mid-punch (hits ~0.10 s)
- hook: from mid-punch with full extension held (hits ~0.15 s; later than ~0.2 s and enemies interrupt the combo)
- idle: loop only the frames that are fully in guard (e.g. 6,7,8,7)
Record the source frames in each animation's `note`.

## 4. Import and review
```
pip install -r tools/art/requirements.txt
python3 tools/art/import_character.py art/characters/<id>/character.json
```
Look at `preview/contact.png` and the GIFs: feet on one line, nothing touching the cell edge, guard held through idle and walk. The importer prints each attack's timing; check the hit times above.

## 5. Make it the hero
```
python3 tools/art/make_player.py art/characters/<id>/character.json
```
This overwrites `scenes/characters/player.tscn` (the hero every level spawns) and writes `resources/combos/<id>_punch_combo.tres` and `<id>_kick_combo.tres`. The previous hero stays in git; `--out` writes somewhere else for a side-by-side test.

## 6. Test
```
godot --headless --path . --import && godot --headless --path . --import    # no SCRIPT ERROR
GODOT=godot tests/run_bot.sh god                                            # must pass
GODOT=godot tests/run_bot.sh                                                # balance
```
- **Balance target:** total hits taken across the 9 runs within ~15% of Max's (48). More than that usually means late hit frames; retime by frame picks before touching stats.
- Run the CI art loop locally; there must be no drift (`git diff --exit-code` on assets/characters, scenes/characters, resources/attacks, resources/combos).
- Screenshots (`xvfb-run ... res://tests/sim.tscn -- level_01 shots=600,1200 quiet`): HUD name and portrait, guard while walking, hit sparks, combo counter. Look at them.

## 7. Hand over
Commit (spec, raw art, previews, sheet, scene, combos) and open a PR into `main`. Tell the user:
- generations used and left
- what was generated, frame-picked and synthesized
- the balance numbers against Max
- what to playtest by hand: hook weight, block, throws and knees (they reuse punch/kick frames), jump attacks
