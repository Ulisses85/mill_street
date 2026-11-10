---
name: level-art
description: Generate AI level backgrounds (sky, skyline, rooftops, building fronts) with Retro Diffusion or PixelLab in one consistent style and save them where the level kit imports them. Use when a level should get AI-made art instead of (or mixed with) the code-drawn look.
---

# Level art (AI)

The level kit (`tools/levels/level_kit.py`) builds every level from `art/levels/<id>/level.json`. Any layer that has images under `art/levels/<id>/raw/` is taken from those images; the rest is drawn by code. The **floor (pavement, kerb, road) is always drawn by code**, because the walk area (y 164–246) must stay flat and readable; in `free` palette mode it is recoloured from the art so it matches.

Read `tools/levels/ai_layers.py` (the `ai` block format) and `CLAUDE.md` first. Always quote the cost and get the user's OK before generating.

## 1. Style bible (first, and only once per level)
Agree with the user on: setting, time of day, mood, 3–5 main colours, how detailed. Write it as one **style line** that goes at the end of every prompt, e.g.
`16-bit pixel art, northern English mill town at dusk, warm brick, purple sky, soft light, flat front view, no people, clean pixel edges`.
Generate **one reference image** first (a building front), show it to the user, and iterate on it before anything else. Then pass it as `--input-image` with `--strength 0.4–0.6` to every later image so the whole level shares one style.

## 2. What to generate (sizes are the game's pixels, so no rescaling)

| Layer | Folder | Size | Notes |
|---|---|---|---|
| sky | `raw/sky/` | 384×270 | `--tile-x`. Sky only: clouds, sunset, stars. No buildings |
| far skyline | `raw/far/` | 384×140 | `--tile-x --remove-bg`. Distant silhouettes, low contrast, chimneys, cranes, spires |
| near rooftops | `raw/near/` | 384×140 | `--tile-x --remove-bg`. Closer roofs and chimney stacks, darker than far |
| building fronts | `raw/facade/` | 128–384 × 140 | `--remove-bg`. **One building per image**, flat front elevation, no perspective, ground floor touching the bottom edge, nothing in front of it |

Building fronts: 4–6 ordinary ones (they fill the street) plus the landmarks. AI lettering is unreliable, so leave sign boards blank in the prompt ("blank sign board above the door") and let the kit paint the text (`"sign": {"text": ..., "y": ...}` on the landmark).

## 3. Retro Diffusion (pay per image)
```
export RD_API_KEY=rdpk-...
python3 tools/art/retrodiffusion.py --prompt "<subject>, <style line>" --style rd_plus__environment --size 384 270 --tile-x --check-cost
python3 tools/art/retrodiffusion.py --prompt "<subject>, <style line>" --style rd_plus__environment --size 384 270 --tile-x --out art/levels/<id>/raw/sky
python3 tools/art/retrodiffusion.py --prompt "pub front, blank sign board, <style line>" --style rd_plus__environment --size 192 140 --remove-bg --input-image art/levels/<id>/raw/facade/00.png --strength 0.5 --out art/levels/<id>/raw/facade
```
- `rd_plus__environment` goes up to 384 px and costs about `(w*h + 50000) / 2,000,000` dollars per image (≈ $0.08 at 384×270). A full level (sky, far, near, ~8 fronts) is roughly **$0.50–1.00**. `--check-cost` is free and authoritative.
- Other styles worth a try: `rd_plus__default`, `rd_plus__retro`, `rd_pro__platformer` (≤256 px, $0.18), `rd_plus__textured`.
- `--palette <png>` locks colours to a palette image if the layers drift apart.
- Rename the files to something meaningful (`pub.png`, `mill.png`) before using them as landmarks.

## 4. PixelLab (MCP, generations from a subscription)
Check `get_balance` first and quote generations before generating. `search_help(tool="<name>")` gives any tool's full parameters and prices for free. Keep the same sizes and rules as above.

| Tool | Canvas | Transparent background | Cost | Style control |
|---|---|---|---|---|
| **`create_image_pixen`** (default) | 16–768 per side, **multiples of 4**, area ≤ 262,144 px | up to 65,536 px (384×140 is fine); larger is refused with `no_background` | 1 | none: description, view, outline, detail, seed |
| `create_image_pixflux` | 16–400 per side, area ≤ 160,000; multiples of 4 at large sizes | up to 40,000 px; above that a **flat colour** (cut it away before import) | 1 | **`color_image_url`** = forced palette, `init_image_url` = image-to-image |
| `create_image_pro` | about 0.25 MP by aspect ratio (3:2 632×424, 21:9 792×336) | yes | 10 / 15 / 25 per call | `style_image_url`, `reference_images`, `palette` (hex) |
| `create_image_pro_flash` | 16–256, multiples of 4 | yes | 5–9 | `style_image`, `palette` |

- **Default: `pixen`** for building fronts and skylines: 1 generation, transparent at full size.
- **To lock the palette across layers:** `pixflux` with `color_image_url` set to the reference front, uploaded with `get_upload_url`. Pixen has no palette input. Its fronts are unified by the kit's shared palette (`palette_mode: free`), or snap them to the reference's colours before import.
- **Sky:** no PixelLab tool tiles. Generate 384×268 or 384×272 (270 isn't a multiple of 4; the kit scales the sky to 270) and leave `tiles` off, so the kit blends the edges.
- **Not useful here:** `create_building_kit`, `create_room`, the tilesets and `create_map` make tiles, top-down rooms or maps, not front-view pictures. `inpaint_image` above 256 px per side needs Tier 2.
- Every prompt: the style line, plus "flat front elevation, no perspective, ground floor touching the bottom edge, nothing in front of it, no plants, no fence". The models still add trees, fences, planters and shrubs, so check each front and crop or clean it before import. Keep the downloads in `raw/originals/`, which the kit doesn't read.

## 5. Wire it into the spec
Add to `art/levels/<id>/level.json`:
```json
"ai": {
  "palette_mode": "free",
  "max_colors": 32,
  "layers": {
    "sky":  {"source": "raw/sky", "tiles": true},
    "far":  {"source": "raw/far", "tiles": true, "bottom": 150},
    "near": {"source": "raw/near", "tiles": true, "bottom": 150},
    "facade": {"source": "raw/facade",
               "landmarks": [{"image": "pub.png", "x": 640, "sign": {"text": "SPINNERS ARMS", "y": 92}}]}
  }
}
```
- `palette_mode`: `free` keeps the art's colours (shared across layers, `max_colors`); `level` snaps them to the spec's 7-colour palette for the pale template look.
- `tiles: true` when the image was generated with `--tile-x`; otherwise the kit blends the edges to make it repeat.
- `bottom`: the y where a skyline's bottom sits (hidden behind the fronts at 140).
- Leave out a layer to keep it code-drawn.

Then build and look:
```
python3 tools/levels/level_kit.py <id> && python3 tools/make_levels.py
```
Check in game (screenshots, see `new-level`): characters must stand out from the background. If they don't, lower `max_colors`, use `palette_mode: level`, or ask for "muted colours, low contrast" in the style line.

Test without a key: `python3 tools/levels/examples/fake_level_provider.py <folder>` writes stand-in art in this layout.
