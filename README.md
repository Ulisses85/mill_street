# Beat 'Em Up Template (Godot 4.3)

A 2D side-scrolling beat 'em up template in GDScript. It's a reusable base: combat, AI, waves and camera are systems you tune in the Inspector, and all art comes from swappable sprite sheets.

**Milestone 2: full template.** Three levels with bosses, weapons, breakables, menus, touch controls and an audio controller.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / Arrows | Left stick / D-pad |
| Run | Double-tap left or right | Double-tap the stick or D-pad |
| Attack (combo) | J / Z | X (Xbox) / Square |
| Special (costs power) | K / X | Y / Triangle |
| Super (full power) | K + L together | Y + A |
| Dodge | I / C / Shift | RB / R1 |
| Grab | U / V | B / Circle |
| Jump | L / Space | A / Cross |
| Taunt (fills power) | T | Back / Select |
| Pause | P / Esc | Start |

**Moves** (Shredder's Revenge style "brawler" controls, the default):
- **Attack** x4: a 4-hit combo; the last hit knocks the enemy flying into others. Hold **away** on the last hit to slam it over your shoulder instead.
- **Run** + Attack: dash attack. **Run** + Jump + Attack: flying kick. In the air, **Down** + Attack: dive kick (bounces off heads).
- Hit enemies while they're in the air to **juggle** them; bodies knocked flying hit other enemies and bounce off the screen edges.
- **Power** fills as you hit, get hit or taunt. Special: a spinning attack all round you, invulnerable. Super: hits everyone on screen.
- **Dodge**: a quick invulnerable dash. Dodge just as an attack lands for a **perfect dodge**: enemies slow down and you gain power.
- Presses made during the freeze on impact are buffered, so combos don't drop inputs.

Classic controls (punch combo, kick combo, hold to block) are one setting away: `"controls": "classic"` in the hero spec, or clear Special Attack and set Defence Mode to Block in the Inspector.

`scripts/core/game.gd` registers these as defaults. Define the same actions in **Project Settings → Input Map** to override them.

On phones and tablets an on-screen stick and buttons (A S J D G) appear on the first touch. They hide again when a keyboard or gamepad is used.

## Run it

Open the folder in Godot 4.3 or newer and press **F5**. On the very first open, Godot imports all the assets. While it does, it may print a burst of `Could not preload resource` errors. They go away once the import finishes; if any remain, use **Project → Reload Current Project**. The game starts on the main menu (`scenes/ui/main_menu.tscn`). To play one level straight away, open it in `scenes/levels/` and press **F6**.

## What's in it

| System | Where | Inspector settings |
|---|---|---|
| Unit (base fighter) | `scripts/core/unit.gd` | Name & portrait, random name file, movement (speed, air speed, acceleration, vertical 80%), jump (height, gravity), hit stun, knockdown (height, distance, floor time, bounce), throw (height, distance), defence (rear defence, stops knockdown attacks), hurtbox |
| Player | `scripts/characters/player.gd` | Attack `ComboData` with back finisher, dash / flying / dive attacks, special and super on a power meter (cost, gain per damage, taunt), dodge with perfect-dodge slow-mo or block, run, jump punch/kick, grab (range, position, duration, knee, finisher, throw damage, thrown-body damage), lives |
| Enemy AI | `scripts/characters/enemy.gd` | Attack, windup telegraph, cooldowns, max simultaneous attackers, wait distance, defend chance (0–100) & duration, can be grabbed, **field of view** (distance, angle, eye offset, look-around, alert delay, debug cone) |
| Attacks & combos | `scripts/combat/attack_data.gd`, `combo_data.gd`, `resources/` | Damage, knockdown, animation, timing (duration / hit window), reach, depth & height range, knockback, forward step, hit-stop, shake. Special properties: invulnerable, launch height (juggles), throw behind, bowls (body hits others), hits whole screen, power gain. Combos: reset time, *continue combo on hit*, ordered list |
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
Each level is one spec, `art/levels/<id>/level.json`: its look (palette, sky, skyline, building fronts with sign text, street furniture) and its gameplay (waves, enemies, props, pickups). Two scripts build it:

```
python3 tools/levels/level_kit.py    # draws the art: assets/levels/<art>/background.png, sky/far/near.png, layout.json
python3 tools/make_levels.py         # writes scenes/levels/<id>.tscn: waves, props, pickups and the parallax layers
```

**The level kit draws everything by code** (Python + Pillow, no AI, no browser), so it's free, unlimited and the same every run. It has a library of building fronts (`terrace`, `mill`, `shop`, `pub`, `warehouse`, `shed`, `billboard`, `alley`, `grand`, `market_hall`) and street furniture. In the spec, `landmarks` pin named buildings to an x position (e.g. a mill called "MILL ST. WORKS" at x 1080) and `fill` sets how often each piece fills the gaps. Behind the street are three repeating parallax layers: `sky` (clouds, smog or stars), `far` (skyline theme: `mills`, `docks` or `town`) and `near` rooftops. `layout.json` lists every layer with its scroll factor and repeat flag (the same shape as FX Games' `parallax-background-v2`), and `make_levels.py` turns each into a Godot `Parallax2D` node.

**AI-made backgrounds** plug into the same kit: put images in `art/levels/<id>/raw/` (`sky/`, `far/`, `near/`, `facade/`) and add an `ai` block to the spec. Those layers come from the images (background removed, made to repeat, reduced to one shared palette); the rest, and always the floor, is drawn by code in colours taken from the art. Landmark signs are painted by the kit so the text is crisp. In Claude Code, `/level-art` covers style, prompts, sizes and costs (Retro Diffusion `rd_plus__environment`: about $0.50–1.00 a level).

You can still edit the scenes in the Godot editor, but don't re-run `make_levels.py` afterwards or it will overwrite your edits. To add a level, copy a spec folder, change it, run both scripts and append a `LevelInfo` to `resources/level_list.tres`. In Claude Code, `/new-level` walks through it.

### Adding an enemy to a wave
Instance `scenes/characters/thug.tscn` under a `Wave` node:
- Leave **Field of View** on, and it waits until it sees you.
- Turn it off and place it past the `LevelBound`, and it runs in when the wave starts.

## AI art pipeline
To turn AI-generated (or hand-drawn) art into playable characters, see **[tools/art/README.md](tools/art/README.md)**. In Claude Code, run `/new-enemy`. Put your keys in the environment (`PIXELLAB_API_KEY`, `RD_API_KEY`) and copy `.mcp.json.example` to `.mcp.json` to enable the PixelLab MCP server.

## Procedural art pipeline (v0)

```
python3 tools/sprite_pipeline/render.py   # needs: pip install playwright (+ Chromium)
python3 tools/sfx/make_sfx.py             # regenerates the placeholder sounds and music loops
python3 tools/levels/level_kit.py         # regenerates the level backgrounds and parallax layers
python3 tools/make_levels.py              # regenerates the three level scenes
```

`tools/sprite_pipeline/` holds a procedural mannequin rig (`rig.js`), which headless Chrome renders to:
- `assets/characters/<name>/sheet.png` + `sheet.json` (128×112 cells, feet anchor at 64,100, frame timing in 60 Hz ticks) + `portrait.png`
- `assets/levels/<name>/signpost.png` + crate/barrel sprites, in each level's palette (the backgrounds come from the level kit)
- `assets/items/` weapons (grip at 6,6) and health items

Each animation in `sheet.json` also stores per-frame `hand` positions and a `weapon_angle` for the weapon bone. Custom art needs these as well (or leave them out, and weapons sit at a default hand position).

To use other art, put a sheet with the same cell size, anchor and `sheet.json` animation names in place of these files. The game picks it up with no code changes. This is where the AI art workflow plugs in (milestone 3).

## Testing

### Play it
- **Editor:** press **F5** to run from the main menu, or **F6** on a level scene to start straight in that level.
- **Builds:** export with the presets in **Project → Export** (Web, Windows, Linux).
- **Phone:** upload the web export to itch.io as a draft HTML5 project and open the page on your phone.

### Debug tools
These work in the editor and in debug exports. Release exports turn them off automatically.

| Key | Action |
|---|---|
| F1 | Show / hide the debug panel (FPS, wave, enemies left, player state) |
| F2 | God mode |
| F3 | Defeat the current wave |
| F4 | Unlock all levels |
| F6 | Slow motion (25%) |
| F7 | Show hurtboxes (blue), active attack hitboxes (red), enemy view cones, walk area and camera bound |
| F8 | Full health and a bat |
| F9 | Skip to the next level |

### Bot playthrough
```
godot --headless --path . --fixed-fps 60 --disable-vsync res://tests/sim.tscn -- level_02 [god] [seed=7] [timeout=300] [boxes] [shots=900,1500] [quiet]
tests/run_bot.sh god     # every level must be finishable
tests/run_bot.sh         # balance report: 3 seeds per level, normal damage
```
A bot plays the level with real inputs and walks around anything that blocks it. It prints a `RESULT` line and exits with `0` if the level was finished, `1` on timeout, `2` if the player died, or `3` on a setup error. A run takes about 3 seconds per level. Runs are deterministic for a given seed: cosmetic randomness (sound pitch, debris, camera shake) uses its own generator, `Game.fx_rng`. That means a failing seed replays exactly.

### CI
`.github/workflows/bot-playthrough.yml` runs on every push and pull request:
1. Imports the project and fails on any script or parse error.
2. Runs the god-mode bot on every level. The build fails if any level can't be finished or a script error is printed.
3. Runs the normal-mode balance report. This step is informational: deaths don't fail the build, but timeouts do. Its table shows in the run summary.

Logs are uploaded as the `bot-logs` artifact.

## Roadmap
- ~~Milestone 2: full Osarion parity~~ ✔
- **Milestone 3: AI art pipeline.**
  - Part 1 ✔ New enemies from AI art: `tools/art/` (importer, enemy builder, Retro Diffusion client) and Claude Code skills `/ideate`, `/new-enemy` and `/character-art` with PixelLab MCP. Example: the Bouncer (Mill Street wave 3, Canal Wharf wave 4).
  - Part 2 ✔ AI-made hero: Del, the retired boxer, built with `tools/art/make_player.py` and `/new-hero`.
  - Part 3 ✔ Level backgrounds drawn by code: `tools/levels/level_kit.py`, one spec per level with parallax layers, and `/new-level`.
- **Exports:** Windows/Mac/Linux (Steam), Android/iOS, Web (itch.io).

Fonts: Silkscreen (SIL Open Font License, `assets/fonts/OFL.txt`).
