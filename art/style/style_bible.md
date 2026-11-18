# Mill Street style bible

The rules every art agent and every prompt starts from. Version 0: written after the first
Qwen-Image tests (issue #33); the look, numbers and prompt templates get tuned as tests come in.
Change this file, not individual prompts, when the house style changes.

## The look

- **HD comic book, hybrid pipeline:** characters are 3D (MPFB or AI-made models) rendered in
  Blender with cel shading and ink outlines, then painted over so they read as hand-drawn.
  The game stays 2D. Target feel: Streets of Rage 4 with heavier ink and grit.
- **Setting:** Manchester-like northern English city, early-to-mid 1990s: terraced streets,
  mills, pubs, rave flyers, rain, sodium street lights.
- **Characters:** slightly exaggerated proportions: heads about 1/7 of the height, big hands
  and forearms, broad shoulders on heavies. Readable silhouettes at about 250 px tall.
- **Shading:** 2 to 3 flat cel bands (shadow, base, small highlight); cool shadows, warm lights.
- **Lines:** solid near-black ink outline, thicker on the silhouette than inside.
- **Palette:** muted street colours (brick, slate, denim, olive, grey) with one saturated accent
  per character (orange lining, red tracksuit, yellow cap) so enemies are told apart at a glance.
- **Light:** key light from the upper left of the camera; the renderer's `light` setting matches.

## Look images (stage 1: Qwen-Image-2512)

A look image is the reference everything else matches. It is a design sheet, not a scene.

**Image size:** tall, **928 x 1664** (Qwen-Image's native 9:16 portrait). Never square for a
character: square crops the legs. Wide 1664 x 928 is for side-by-side front + side views.

**Always in the prompt:**
- `full body from head to toe, feet and shoes fully visible, standing, whole figure in frame`
- the view: `side view, facing right` (game view) or `front view` (for the 3D model)
- `plain flat light grey background, no floor, no shadow, no scenery, no text`
- the style line (below)
- every distinctive feature spelled out, never implied: `completely bald shiny head` (not
  "bald" alone: it drifts to a buzz cut), `full thick beard`, the exact clothing and colours

**Style line** (paste as is):
`comic book illustration, bold black ink outlines, flat cel shading with two tones, 1990s
British street brawler video game character design, clean readable silhouette`

**Avoid in the prompt / negative:** `cropped, cut off, close-up, portrait, half body, multiple
people, background scenery, text, logo, watermark, blurry`

**Prompt template:**
```
{style line}. {view}. {who}: {build}, {head and face}, {clothing with colours}, {accent},
{props if any}. {always-in-the-prompt line}. {pose: neutral standing / guard stance}.
```

Example (the test character):
```
comic book illustration, bold black ink outlines, flat cel shading with two tones, 1990s British
street brawler video game character design, clean readable silhouette. Side view, facing right.
A heavy-set street brawler: broad shoulders, big fists, completely bald shiny head, full thick
dark beard, green bomber jacket with orange lining, white T-shirt, blue jeans, brown boots.
Full body from head to toe, feet and shoes fully visible, standing, whole figure in frame,
plain flat light grey background, no floor, no shadow, no scenery, no text. Fists up in a guard.
```

## Generation settings

| Use | Settings | Time on the RX 7900 XTX |
|---|---|---|
| Exploring looks (many variations) | Lightning LoRA, 4 steps, CFG 1 | to be measured (#54 test) |
| Final approved look | Template default, 50 steps | about 6 min (measured, #33) |
| Edits (colour change, fix a detail) | Qwen-Image-Edit-2511, Lightning 4 steps; 40 steps for finals | about 4.5 min at 40 steps (#33) |

Fix the seed when comparing settings, so only the setting changes.

## Batches (for the generator agent)

ComfyUI runs with `--cache-none` on this machine (keeps system RAM safe, see #33), so models
reload on every separate run (about a minute). The generator agent therefore:
- **queues a batch** (all variations of a look, all edits for a character) as one submission,
  so models load once per batch, not once per image
- unloads Ollama models before a batch and leaves ComfyUI idle afterwards (both need ~20 GB)
- names outputs `art/characters/<id>/looks/<view>_<seed>.png` and keeps the prompt and seed in
  a sidecar `.json`, so any image can be reproduced

## Review checklist (art director agent)

Reject a look image if: any part of the body is cropped; the background isn't plain; a
spelled-out feature is wrong (hair, beard, colours); there is more than one figure; there is
text or a logo; the silhouette doesn't read at 250 px tall (shrink it and look).
