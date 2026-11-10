---
name: character-art
description: Generate beat 'em up character art with PixelLab (MCP) or Retro Diffusion (tools/art/retrodiffusion.py) and save it in the layout the importer expects. Use when generating or regenerating sprites for a character spec.
---

# Character art

The goal is side-view frames facing right for each animation in the spec, saved under `art/characters/<id>/raw/`. The importer handles the background, scale, alignment and palette. Your job is consistent, usable frames.

## Art direction
- **Composition:** side view, facing right, full body, the same character in every animation, feet visible.
- **Background:** plain or transparent, with no ground shadow (the game draws shadows).
- **Template style:** chunky pixel art, dark 1 px outline, limited palette. Enemies are red or another strong accent colour on the grey world. The hero is white or pale.
- **Size:** generate at 64–128 px tall. The importer scales to `target_height`.

## PixelLab (MCP, subscription)
Setup (user, once): `claude mcp add pixellab https://api.pixellab.ai/mcp -t http -H "Authorization: Bearer $PIXELLAB_API_KEY"`. See `.mcp.json.example`.

1. `get_balance` to check credits. Tell the user before large jobs.
2. `create_character` with the spec's `generator.prompt`. Use a side view, and 4 directions is enough. Jobs return an ID; poll the matching `get_*` tool until the job is done (30 s – 5 min).
3. `animate_character` with the character ID, once per animation: idle, walk, the attack (e.g. a punch, or an overhead smash for brutes) and hurt. For a boss or hero, also block and knockdown if available.
4. Download the results. Keep only the **east (right-facing)** direction. Save each animation as `raw/<anim>/` frames, or as the sheet or GIF PixelLab exports.
5. If a frame set is off, regenerate that one animation rather than the whole character.
6. Tool names and parameters may change. List the server's tools if a call fails.

## Retro Diffusion (pay per image)
Setup: `export RD_API_KEY=rdpk-...`. Always `--check-cost` first and tell the user the price.
```
# base frame / reference
python3 tools/art/retrodiffusion.py --prompt "<prompt>" --style rd_pro__spritesheet --size 128 128 --remove-bg --out art/characters/<id>/raw/base
# walk from the base frame
python3 tools/art/retrodiffusion.py --prompt "<prompt>, walking" --style rd_advanced_animation__walking --size 128 128 --input-image art/characters/<id>/raw/base/00.png --remove-bg --out art/characters/<id>/raw/walk
```
- Use `--palette` with a palette PNG to match the game's colours.
- Use `rd_tile__scene_object` for props.
- Retro Diffusion may return a sprite sheet. Set `frames`/`grid` in the spec, or let the importer split it on empty columns.

## After generating
- Update `animations` in `character.json`: `source`, `fps` (idle ~8, walk ~12, attacks ~16–30), `loop`, and `active` (hit frames) for attacks.
- Run `python3 tools/art/import_character.py ...` and look at `preview/contact.png`.
