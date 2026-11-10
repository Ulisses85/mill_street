---
name: new-level
description: Build a new level or restyle an existing one end to end - concept, level spec (look + waves), background and parallax layers drawn by code with the level kit, scene, bot test and screenshots. Use when the user wants a new level, a new setting or a different look for a level.
---

# New level

Read `CLAUDE.md` first. Work on a branch off `main` (`git checkout -b level/<id>`).
The art is drawn by code (`tools/levels/level_kit.py`), so it costs nothing and you can iterate freely.
Worked examples: `art/levels/level_01` (Mill Street), `level_02` (Canal Wharf), `level_03` (Market Row).

## 1. Concept
If there's no `art/levels/<id>/concept.md`, run the `ideate` skill or agree with the user on:
- setting and mood (mill town, docks, market, estate, station...)
- 3–6 **landmarks** with their sign text (a pub name, a mill name, a shop)
- skyline theme and sky
- wave plan: how many waves, which enemies, the boss

## 2. Spec: `art/levels/<id>/level.json`
Copy a worked example and change it. The keys:

| Key | What |
|---|---|
| `id`, `display_name`, `art`, `music`, `world` | scene id (`level_04`), name, art folder under `assets/levels/`, music `AudioItem`, street length in px |
| `seed` | changes the random fill; same seed = same pixels |
| `palette` | 7 colours, dark to light. Keep it pale and low in saturation so red enemies and the hero stand out |
| `sky` | `{"detail": "clouds" \| "smog" \| "stars", "count": n}` |
| `skyline` | `{"theme": "mills" \| "docks" \| "town"}` (used by the `far` and `near` layers) |
| `parallax` | scroll factor per layer: `sky` 0.05, `far` 0.25, `near` 0.5 |
| `facade.landmarks` | `{"piece", "x", "width"?, "name"? / "text"?: [lines]}` pinned at x |
| `facade.fill` | weights of pieces that fill the gaps, e.g. `{"terrace": 4, "shop": 2, "alley": 1}` |
| `furniture` | weights of `lamp`, `bollard`, `postbox`, `drum`, `bags` along the pavement |
| `waves` | `{"bound": x, "enemies": [[scene, x, y, fov], ...]}`; `fov` false = runs in from off screen |
| `pickups`, `props` | `[weapon, x, y]`, `[crate \| barrel, x, y, drop]` (drop: `can`, `chips` or a weapon) |

Pieces: `terrace`, `mill`, `shop` (random trade if no name), `pub`, `warehouse`, `shed`, `billboard` (lines of `text`), `alley`, `grand`, `market_hall`. Put the controls billboard near the start of the first level. Keep landmarks away from the wave bounds where the camera stops, so the player sees them.

To add a new piece: write a `p_<name>(cv, rng, x0, w, o)` function in `level_kit.py` (draw with palette indices 0–6 and `BASE` = 140 as the ground line), add it to `PIECES` and `WIDTHS`, and use it in a spec.

## 3. Build
```
pip install -r tools/art/requirements.txt
python3 tools/levels/level_kit.py <id>        # art: assets/levels/<art>/background.png, sky/far/near.png, layout.json
python3 tools/make_levels.py                  # scenes/levels/<id>.tscn
```
For a new level: also run `python3 tools/sprite_pipeline/render.py` (crate, barrel and signpost in its palette) and append a `LevelInfo` to `resources/level_list.tres` (name, scene, boss name, palette).

## 4. Look at it
Composite a few camera positions without Godot to iterate quickly, then check in game:
```
xvfb-run godot --path . --rendering-driver opengl3 --resolution 480x270 --fixed-fps 60 res://tests/sim.tscn -- <id> god shots=300,1500 quiet
```
Check: sign text readable, no lamp post across a sign, no two identical fronts side by side, the sky shows over the rooftops, the floor is unchanged (walk area y 164–246).

## 5. Test
```
godot --headless --path . --import && godot --headless --path . --import    # no SCRIPT ERROR
GODOT=godot tests/run_bot.sh god                                            # every level finishable
GODOT=godot tests/run_bot.sh                                                # balance
python3 tools/check_generated.py assets/levels scenes/levels               # committed = generated
```
A restyle that keeps the waves must give the same god-mode frame counts as before.

## 6. Hand over
Commit the spec, the generated art and scene, and open a PR into `main`. Tell the user what the level looks like (send the screenshots), the landmarks, the wave plan and the balance numbers.
