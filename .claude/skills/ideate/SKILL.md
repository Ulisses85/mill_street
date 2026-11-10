---
name: ideate
description: Brainstorm a new enemy, boss, hero or level for the beat 'em up with the user and write it up as a concept and a character spec. Use when the user has a rough idea ("a nightclub bouncer enemy", "a docks level") or asks for ideas.
---

# Ideate

Turn a rough idea into something the art pipeline can build. Keep it a conversation: the user owns the ideas, you sharpen them.

1. **Get the seed.** Ask what they have in mind. If they want suggestions, offer 3 short, different concepts that fit the game: a UK city streets setting, Mill Street / Canal Wharf / Market Row, a mono grey world with red enemies and a white hero.
2. **Pin down gameplay first, looks second.** For an enemy or boss:
   - **Role:** pick a preset (`thug`: fast and weak, can grab weapons; `brute`: slow, tanky, knockdown hits; `boss`: big bar, super armour).
   - **One thing that makes it different:** blocks a lot, long reach, fast windup, grabs weapons, and so on.
   - **Where it appears:** which level and wave.
3. **Looks.** Silhouette, outfit, one accent colour, accessory. It must read at ~60–90 px tall, side view facing right. Keep the template's style unless the user wants a new one: chunky pixel art, dark outline, enemies in reds.
4. **Write it down:**
   - `art/characters/<id>/concept.md`: the idea, gameplay role, look, and any open questions.
   - `art/characters/<id>/character.json`: follow `tools/art/README.md`. Set `role`, `preset`, `target_height`, `attack_animation`, `stats` overrides, and `generator.prompt` plus `generator.animations_requested`. Leave `animations` with the expected `raw/` paths, to be filled after generation.
5. **For a level idea:** write `art/levels/<id>/concept.md` (setting, landmarks with their sign text, skyline theme, palette mood, wave plan, boss), then build it with `/new-level`.
6. **Confirm with the user,** then suggest `/new-enemy`, `/new-hero` or `/new-level` to build it.

Good prompts are concrete: "heavy-set nightclub bouncer, purple bomber jacket, dark shades, bald, side view facing right, pixel art, clean dark outline, transparent background".
