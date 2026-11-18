# Mill Street style bible

The rules every art agent and every prompt starts from. Version 1: written after the first
Qwen-Image tests (#33) and tuned with the style-bible test (#54); the look, numbers and prompt
templates keep being tuned as tests come in.
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
- the view: `strict side profile view, facing right, body and head in profile` (game view) or
  `front view` (for the 3D model). "Side view" alone comes out three-quarter.
- `plain flat light grey background, no floor, no shadow, no scenery, no text`
- the style line (below)
- every distinctive feature spelled out, never implied: `completely bald shiny head` (not
  "bald" alone: it drifts to a buzz cut), `full thick beard`, the exact clothing and colours
- the accent **and where it shows**: `bright orange inner lining clearly visible at the collar and
  the open front` (a bare "with orange lining" mostly disappears)
- the build in body terms: `barrel chest, broad shoulders, thick muscular arms` ("heavy-set"
  comes out as a big belly)
- a pose that reads in silhouette: `fists up in a boxing guard, lead fist held out in front of
  the face, clear gap between arms and body` (fists in front of the chest vanish inside the
  outline at 250 px)

**Style line** (paste as is):
`comic book illustration, bold black ink outlines, flat cel shading with two tones, hard-edged shadows, no gradients, 1990s British street brawler video game character design, clean readable silhouette`

Qwen still leans towards soft, painterly shading. That's acceptable for look images: the real
cel look comes from the Blender render and the paint-over.

**Negative prompt** (one line, paste as is; 50-step runs only, see Lightning below):
`cropped, cut off, close-up, portrait, half body, multiple people, background scenery, text, logo, watermark, blurry, three-quarter view, front view, soft shading, airbrush, gradient, painterly, realistic`

**Prompt template:**
```
{style line}. {view}. {who}: {build}, {head and face}, {clothing with colours}, {accent},
{props if any}. {always-in-the-prompt line}. {pose: neutral standing / guard stance}.
```

Example (the test character):
```
comic book illustration, bold black ink outlines, flat cel shading with two tones, hard-edged shadows, no gradients, 1990s British street brawler video game character design, clean readable silhouette. Strict side profile view, facing right, body and head in profile. A street brawler with a barrel chest, broad shoulders and thick muscular arms, big fists, completely bald shiny head, full thick dark beard, open green bomber jacket with bright orange inner lining clearly visible at the collar and the open front, white T-shirt, blue jeans, brown boots. Full body from head to toe, feet and shoes fully visible, standing, whole figure in frame, plain flat light grey background, no floor, no shadow, no scenery, no text. Fists up in a boxing guard, lead fist held out in front of the face, clear gap between arms and body.
```

## Generation settings

| Use | Settings | Time on the RX 7900 XTX |
|---|---|---|
| Exploring looks | Lightning LoRA, 4 steps, CFG 1 | about 75 s model load per batch, then about 12.5 s per image at 928x1664 (#54) |
| Final approved look | Template default, 50 steps, CFG 4 | about 5 min at 928x1664 (301 s, #54) |
| Edits (colour change, fix a detail) | Qwen-Image-Edit-2511, Lightning 4 steps; 40 steps for finals | about 4.5 min at 40 steps (#33) |

Fix the seed when comparing settings, so only the setting changes.

**Lightning, what it's good for (#54):** build, clothing layout, pose and framing: it got every
structural rule right. It is **not** good for colour accents or small details (the orange lining
failed 4 of 4), it **ignores the negative prompt** at CFG 1 (anything that must hold goes in the
positive prompt), and different seeds give nearly identical images.

**Workflow:** explore with Lightning by changing the **prompt**, not the seed; then rerun the
chosen prompt with the same seed at 50 steps, and run the review checklist on the 50-step image only.

## Batches (for the generator agent)

ComfyUI runs with `--cache-none` on this machine (keeps system RAM safe, see #33), so models
reload on every separate run (about a minute). The generator agent therefore:
- **queues a batch** (all variations of a look, all edits for a character) as one submission,
  so models load once per batch, not once per image. Build it as one graph with shared loaders
  and one sampler, decode and save chain per seed, not `batch_size` in the latent, so each
  image keeps its own seed and can be remade alone (#54)
- unloads Ollama models before a batch and leaves ComfyUI idle afterwards (both need ~20 GB)
- names outputs `art/characters/<id>/looks/<view>_<seed>.png` and keeps the prompt and seed in
  a sidecar `.json`, so any image can be reproduced

## Review checklist (art director agent)

Run it on the 50-step image. Reject a look image if: any part of the body is cropped; the
background isn't plain; a spelled-out feature is wrong (hair, beard, colours, the accent); the
view isn't a side profile (game view); there is more than one figure; there is text or a logo;
the silhouette doesn't read at 250 px tall (shrink it and look: the guard and the build must show).
