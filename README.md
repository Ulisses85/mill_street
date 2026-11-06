# Beat 'Em Up Template (Godot 4.3)

A 2D side-scrolling beat 'em up template in GDScript. It's a reusable base: combat, AI, waves and camera are systems you tune in the Inspector, and all art comes from swappable sprite sheets.

**Milestone 2: full template.** Three levels with bosses, weapons, breakables, menus, touch controls and an audio controller.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / Arrows | Left stick / D-pad |
| Punch | J / Z | X (Xbox) / Square |
| Kick | K / X | Y / Triangle |
| Defend (hold) | I / C / Shift | RB / R1 |
| Grab | U / V | B / Circle |
| Jump | L / Space | A / Cross |
| Pause | P / Esc | Start |

`scripts/core/game.gd` registers these as defaults. Define the same actions in **Project Settings → Input Map** to override them.

On phones and tablets an on-screen stick and buttons (P K J D G) appear on the first touch. They hide again when a keyboard or gamepad is used.

## Run it

Open the folder in Godot 4.3 or newer and press **F5**. The game starts on the main menu (`scenes/ui/main_menu.tscn`). To play one level straight away, open it in `scenes/levels/` and press **F6**.

## What's in it

| System | Where | Inspector settings |
|---|---|---|
| Unit (base fighter) | `scripts/core/unit.gd` | Name & portrait, random name file, movement (speed, air speed, acceleration, vertical 80%), jump (height, gravity), hit stun, knockdown (height, distance, floor time, bounce), throw (height, distance), defence (rear defence, stops knockdown attacks), hurtbox |
| Player | `scripts/characters/player.gd` | Punch & kick `ComboData`, jump punch/kick, change direction while defending, grab (range, position, duration, knee, finisher, throw damage, thrown-body damage), lives |
| Enemy AI | `scripts/characters/enemy.gd` | Attack, windup telegraph, cooldowns, max simultaneous attackers, wait distance, defend chance (0–100) & duration, can be grabbed, **field of view** (distance, angle, eye offset, look-around, alert delay, debug cone) |
| Attacks & combos | `scripts/combat/attack_data.gd`, `combo_data.gd`, `resources/` | Damage, knockdown, animation, timing (duration / hit window), reach, depth & height range, knockback, forward step, hit-stop, shake. Combos: reset time, *continue combo on hit*, ordered list |
| Health | `scripts/systems/health_system.gd` | Max/current HP, invulnerable, small bar, hit flash, shake, SFX |
| Waves | `scripts/systems/wave_manager.gd`, `wave.gd`, `level_bound.gd` | `WaveManager/Wave1..N`, each holding enemies and a `LevelBound` (yellow line in the editor). The camera stops at the bound until the wave is cleared. Option to end the level some other way |
| Camera | `scripts/systems/beat_camera.gd` | Targets (default: player group), damping, Y offset, view area, backtracking + margin, keep targets on screen + border margin |
| Level | `scripts/core/level.gd` | Walkable floor rectangle (shown in the editor), foreground parallax |
| HUD | `scripts/ui/hud.gd` | Portrait, name, health bars, score, lives, combo counter, GO arrow, messages |
| Weapons | `scripts/combat/weapon_data.gd`, `resources/weapons/` | Bat, pipe (melee) and throwing knife (projectile). Uses/durability for player and enemy, attack per user, grip point. Held on a **weapon bone** that follows the hand position stored per frame in `sheet.json`. Units: *lose weapon when hit* / *when knocked down*. Enemies with *can pick up weapons* walk over and grab them |
| Pickups | `scripts/systems/pickup.gd` | Health (walk over it) or weapon (press Punch while standing on it) |
| Breakables | `scripts/systems/breakable.gd`, `scenes/props/` | Crates and barrels with a HealthSystem, damaged sprite, debris and a spawned item. The player can't walk through them; Grab lifts one and any attack button throws it |
| Projectiles | `scripts/systems/projectile.gd` | Knives fly flat; thrown crates arc, spin and smash on impact |
| Bosses | `enemy.gd` → Boss group | *Is boss* (big HUD bar, name banner, can't be grabbed), *super armor* (light hits don't interrupt its attacks). `scenes/characters/boss_*.tscn` |
| Enemy drops | `enemy.gd` → Drops group | Chance, heal amount and sprite of a health item dropped on defeat |
| Menus & flow | `scripts/ui/`, `resources/level_list.tres` | Main menu, level select (levels unlock in order, best scores), pause, level complete, all levels complete, game over. Progress is saved to `user://save.cfg` |
| Touch controls | `scripts/ui/touch_controls.gd` | Virtual stick + five buttons; they press the same input actions, so gameplay code doesn't change |
| Audio controller | `scripts/systems/sfx.gd`, `audio_item.gd`, `resources/audio/audio_library.tres` | `AudioItem`: name, clip list (picks one at random), volume, random volume, min time between calls, random pitch, loop. `Sfx.play(&"hit")`, `Sfx.music(&"music_street")` |
| Effects | `scripts/systems/effects.gd` | Hit bursts, block shields, dust, debris chunks, floating text |

### How the 2.5D floor works
A unit's node position is the point on the floor under its feet: `x` runs along the street and `y` is depth. Its height off the floor is `z`. The `World` node y-sorts its children, so whoever stands nearer is drawn in front. Hits only connect when the attacker and target are within the attack's `depth_range` and `height_range`.

### Levels
`tools/make_levels.py` writes `scenes/levels/level_0N.tscn` from a short layout for each level: waves, enemies, props and pickups. Edit the layout and re-run it. You can also edit the scenes in the Godot editor, but don't re-run the script afterwards or it will overwrite your edits. To add a level, append a `LevelInfo` to `resources/level_list.tres`.

### Adding an enemy to a wave
Instance `scenes/characters/thug.tscn` under a `Wave` node:
- Leave **Field of View** on, and it waits until it sees you.
- Turn it off and place it past the `LevelBound`, and it runs in when the wave starts.

## Art pipeline (v0)

```
python3 tools/sprite_pipeline/render.py   # needs: pip install playwright (+ Chromium)
python3 tools/sfx/make_sfx.py             # regenerates the placeholder sounds and music loops
python3 tools/make_levels.py              # regenerates the three level scenes
```

`tools/sprite_pipeline/` holds a procedural mannequin rig (`rig.js`), which headless Chrome renders to:
- `assets/characters/<name>/sheet.png` + `sheet.json` (128×112 cells, feet anchor at 64,100, frame timing in 60 Hz ticks) + `portrait.png`
- `assets/levels/<name>/background.png` + `signpost.png` + `layout.json` + crate/barrel sprites
- `assets/items/` weapons (grip at 6,6) and health items

Each animation in `sheet.json` also stores per-frame `hand` positions and a `weapon_angle` for the weapon bone. Custom art needs these as well (or leave them out, and weapons sit at a default hand position).

To use other art, put a sheet with the same cell size, anchor and `sheet.json` animation names in place of these files. The game picks it up with no code changes. This is where the AI art workflow plugs in (milestone 3).

## Tests

```
godot --headless --path . res://tests/sim.tscn -- level_02     # a bot plays a level and logs waves / damage
xvfb-run godot --path . --rendering-driver opengl3 res://tests/shots.tscn   # renders screenshots
```

## Roadmap
- ~~Milestone 2: full Osarion parity~~ ✔
- **Milestone 3: AI art pipeline.** Generate character and level art from your own ideas, then slice it into the sheet format above.
- **Exports:** Windows/Mac/Linux (Steam), Android/iOS, Web (itch.io).

Fonts: Silkscreen (SIL Open Font License, `assets/fonts/OFL.txt`).
