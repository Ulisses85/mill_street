# Mill Street: beat 'em up template (Godot 4.3, GDScript)

A 2D side-scrolling beat 'em up template plus a demo game: three levels with bosses. The aim is to ship on Steam, mobile and itch.io. The owner generates their own characters and levels with AI tools through the art pipeline in `tools/art/`.

## Layout
- `scripts/core/`: `unit.gd` is the base fighter (2.5D floor: node position = feet, `z` = height). Also `game.gd` (autoload: input, hit-stop, levels, save, `god_mode`, `fx_rng`), `level.gd`, and `sprite_animator.gd` (reads `sheet.json`).
- `scripts/characters/`: `player.gd`, `enemy.gd` (AI, field of view, bosses, weapons).
- `scripts/combat/`: `AttackData`, `ComboData`, `WeaponData` resources.
- `scripts/systems/`: waves, camera, health, pickups, breakables, projectiles, effects, `sfx.gd` (audio controller).
- `scripts/ui/`: HUD, menus, touch controls. `scripts/debug/`: F1–F9 debug tools (debug builds only).
- `scenes/`: characters, props, levels (generated), ui. `resources/`: attacks, combos, weapons, audio library, level list.
- `assets/`: sprite sheets, items, level art, sfx, fonts. **Generated, do not hand-edit:** `assets/characters/*/sheet.*`, `assets/levels/*` and `scenes/levels/*`.
- `art/`: source art and specs: `art/characters/<id>/character.json` (+ `raw/`, `preview/`) and `art/levels/<id>/level.json` (look + waves).
- `tools/`: `art/` (AI art importer and enemy builder), `levels/level_kit.py` (level art drawn by code), `sprite_pipeline/` (procedural mannequin rig), `make_levels.py`, `check_generated.py`, `sfx/`.

## Commands
```
godot --headless --path . --import            # run twice on a fresh clone (first pass builds the cache)
GODOT=godot tests/run_bot.sh god              # gate: every level finishable, no script errors
GODOT=godot tests/run_bot.sh                  # balance report (3 seeds, normal damage)
godot --headless --path . --fixed-fps 60 --disable-vsync res://tests/sim.tscn -- level_02 seed=3   # one bot run
pip install -r tools/art/requirements.txt    # before importing art (pins Pillow so local output matches CI)
python3 tools/art/import_character.py art/characters/<id>/character.json
python3 tools/art/make_enemy.py art/characters/<id>/character.json
python3 tools/art/make_player.py art/characters/<id>/character.json   # hero spec ("role": "player") -> scenes/characters/player.tscn
python3 tools/levels/level_kit.py             # level art from art/levels/*/level.json (backgrounds + parallax layers)
python3 tools/make_levels.py                  # scenes/levels/<id>.tscn from the same specs
python3 tools/check_generated.py assets scenes resources   # after regenerating: committed output must match (PNGs by pixels)
python3 tools/sprite_pipeline/render.py       # regenerates the built-in mannequin art
```
Screenshots for visual checks: `xvfb-run godot --path . --rendering-driver opengl3 --resolution 480x270 --fixed-fps 60 res://tests/sim.tscn -- level_01 shots=600,1200 quiet`. Files land in Godot's user data folder (`sim_<level>_<frame>.png`). Look at them before calling visual work done.

## Conventions
- GDScript is typed. Godot treats "variable inferred from Variant" as an error, so use `minf/maxf/mini/maxi` instead of `min/max`, and give explicit types when a value comes from a Dictionary or Array.
- Gameplay is tick-based at 60 Hz (`t` counts ticks in the current state). Times in resources are in seconds and converted with `* 60`.
- Gameplay randomness uses the global RNG, seeded by the bot for reproducible runs. Cosmetic randomness (sound, debris, shake) uses `Game.fx_rng`, so it doesn't change gameplay.
- Levels come from `art/levels/<id>/level.json`. Edit the spec and re-run the level kit and `make_levels.py`, not the `.tscn` files, unless you stop using the generator.
- Every animation in `sheet.json` has `hand` + `weapon_angle` per frame (the weapon bone) and `active_frames` for attacks.

## Before committing
1. Import twice. There must be no `SCRIPT ERROR`.
2. `tests/run_bot.sh god` passes.
3. For visual changes, take a screenshot and look at it.
4. Work on a feature branch. CI (`.github/workflows/bot-playthrough.yml`) runs the same checks.

## AI art
Use the skills in `.claude/skills/`:
- `ideate`: brainstorm a character or level.
- `new-enemy`: idea → art → playable enemy in a level.
- `new-level`: idea → level spec → art drawn by code → waves → bot test and screenshots.
- `new-hero`: idea (any fighting style) → art in a stance → combo slots picked from generated attacks → `make_player.py` → balance against Max.
- `character-art`: provider specifics for PixelLab (MCP) and Retro Diffusion (`tools/art/retrodiffusion.py`).

API keys come from the environment (`PIXELLAB_API_KEY`, `RD_API_KEY`). Never commit them.
