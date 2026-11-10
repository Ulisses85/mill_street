---
name: new-hero
description: Build a new player hero end to end - any fighting style (boxer, brawler, kicker, armed) - spec, AI art in a stance, combos picked from generated attacks, make_player.py, bot balance against the built-in hero. Use when the user wants a new or replacement player character.
---

# New hero

Read `CLAUDE.md` and `tools/art/README.md` first. Work on a branch off `main` (`git checkout -b hero/<id>`).
Worked example: `art/characters/del/character.json` (Del, a boxer). Copy the method, not the moves.

## The hero's move slots
The game has fixed slots. Their names are IDs, not moves: the art in them can be anything that fits the character's style. Name the actual move with `attack_name` in the spec's `attacks` (Del: `"punch_3": {"attack_name": "Hook"}`).

| Slot (animation name) | Role | Del (boxer) | Other ideas |
|---|---|---|---|
| `punch_1` | punch combo hit 1: light, fast | jab | elbow, backhand, quick slash |
| `punch_2` | punch combo hit 2: light | cross | headbutt, second slash |
| `punch_3` | punch combo finisher: heavy, knocks down | hook | uppercut, overhead smash, spin slash |
| `kick_1` | kick combo hit 1 | low kick | knee, shin kick, shoulder barge |
| `kick_2` | kick combo finisher, knocks down | roundhouse | flying kick, dropkick, shield bash |
| `punch`, `kick` | the generated attacks the slots are cut from (`kick` becomes `kick_2` if you don't fill it) | straight punch, roundhouse | haymaker, stomp, slash |
| `idle`, `walk`, `hurt`, `block` | basics | | |
| `jump`, `jump_punch`, `jump_kick`, grab, throw, carry | optional; synthesized if missing | | |

**Brawler moves** (Shredder's Revenge style, the default `"controls": "brawler"`): the Attack button runs `punch_1` > `punch_2` > `kick_1` > `punch_3`, and these optional animations give the other moves their own art. Until they exist, `make_player.py` uses punch/kick animations instead and the code adds afterimages, so generate them in this order of payoff:

| Animation | Move | Falls back to |
|---|---|---|
| `special` | spinning attack hitting all round (costs power, invulnerable) | `kick_2` |
| `dodge` | quick dash or roll | `defend` + afterimages |
| `dash_attack` | running attack (shoulder charge, sliding kick) | `kick_2` |
| `slam` | over-the-shoulder throw finisher | `punch_3` |
| `flying_kick`, `dive` | running jump attack; downward dive kick | `jump_kick` |
| `super` | big showy move for the full-power super | `punch_3` |
| `taunt` | short taunt (fills power) | `idle` |
| `run` | a real run, different from `walk` | `walk` played faster |

Each is about 2 PixelLab generations from the stance start frame. Name the folder after the animation (`raw/special/`) and add it to `animations` in the spec, then re-run the importer and `make_player.py`.

Pick the slot moves from the concept in step 1 and write them into the spec (`concept` and `generator.animations_requested`).

## 1. Spec
If there's no `art/characters/<id>/character.json`, run the `ideate` skill or write one with the user.
- `role: "player"`, `target_height` about 58–62 (enemies: thug 58, Biker 62).
- Give the hero an identity against the built-in hero (Max: 100 HP, speed 126, punch_1/2/3 5/6/9, kick_1/2 7/12). Override in `stats` and per attack in `attacks` (`damage`, `reach_to`, ...).
- Readability: the hero must be easy to find in a crowd of red/black enemies. Distinct colours, not necessarily white.

## 2. Generate the art (quote the cost first, ask before every retry)
Follow the `character-art` skill. For a hero:
- **Base character in the fighting stance** (guard), side view, facing right. PixelLab animations start from the base pose; an arms-down base makes idle and walk drop out of the stance.
- If the base isn't in stance: take the stance frame from idle and pass it as the **start frame** (`get_upload_url` → `custom_start_frame_url`) for walk and any other looping animation.
- Animations: **idle, walk, hurt, block**, plus **one main attack for each combo** in the character's style (Del: a straight punch and a roundhouse; a brawler might be a wild haymaker and a stomp). Optional: jump (otherwise the jump attacks reuse an attack frame). A long or varied attack gives more frames to pick combo hits from.
- Name the direction of every strike in the prompt ("forward, in the direction he is facing").
- Show the user the base character before animating it.
- Typical cost (PixelLab, right-facing only): base 2 + 2 per 8-frame animation ≈ 14 generations.

## 3. Fill the combo slots from frame picks (free)
One generated attack can fill a whole combo: start each hit at a different point of the same animation, so later hits have more wind-up. Copy frame ranges into `raw/<slot>/` and add each slot to `animations` with `fps` and `active`. Generate a separate attack only when a slot needs a visibly different move.

Hit timing targets (time from the start of the slot to the first active frame), whatever the move is:
- hit 1: ~0.07 s (start near the end of the attack)
- hit 2: ~0.10 s
- finisher (`punch_3`, `kick_2`): ~0.15 s, extension held a little longer. Later than ~0.2 s and enemies interrupt the combo.
- kick slots: the same pattern.
- idle: loop only the frames that are fully in the stance (Del: 6,7,8,7).
Record the source frames in each animation's `note`. An armed hero keeps the weapon in every frame; the template's pickup weapons still attach to the `hand` the importer estimates.

## 4. Import and review
```
pip install -r tools/art/requirements.txt
python3 tools/art/import_character.py art/characters/<id>/character.json
```
Look at `preview/contact.png` and the GIFs: feet on one line, nothing touching the cell edge, stance held through idle and walk. The importer prints each attack's timing; check the hit times above.

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
- Screenshots (`xvfb-run ... res://tests/sim.tscn -- level_01 shots=600,1200 quiet`): HUD name and portrait, stance held while walking, hit sparks, combo counter. Look at them.

## 7. Hand over
Commit (spec, raw art, previews, sheet, scene, combos) and open a PR into `main`. Tell the user:
- generations used and left
- what was generated, frame-picked and synthesized
- the balance numbers against Max
- what to playtest by hand: finisher weight, block, grab knee and throws (they reuse attack frames), jump attacks
