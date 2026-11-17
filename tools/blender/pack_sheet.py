#!/usr/bin/env python3
"""Pack rendered frames (tools/blender/render_sprites.py) into the game's sprite sheet.

    python3 tools/blender/pack_sheet.py art/characters/<id>/character.json

Reads art/characters/<id>/raw/render/ (colour from raw/paint/<anim>/NN.png when a paint-over exists)
and writes assets/characters/<id>/sheet.png, sheet_n.png (normal map) and sheet.json, plus one
preview strip per animation in art/characters/<id>/preview/.

HD frames are big, so every frame is trimmed to its pixels and packed tightly. sheet.json then has a
"rects" list per animation: [x, y, w, h, ox, oy] = the frame's place in the sheet and where the
character's feet (the anchor) sit inside it. "scale" turns texture pixels into game units
(0.25 for 4x art) and "filter": "linear" asks the game to draw it smoothly.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PAD = 2
MAX_W = 4096


def trim(im: Image.Image, ax: float) -> tuple[int, int, int, int]:
    """The frame's pixels, widened to be symmetric around the anchor so a flipped sprite still stands
    on its feet (the game mirrors frames around their centre)."""
    b = im.getchannel("A").point(lambda v: 255 if v > 4 else 0).getbbox() or (0, 0, 1, 1)
    half = max(ax - b[0], b[2] - ax) + PAD
    x0, x1 = max(0, int(ax - half)), min(im.width, int(ax + half + 0.999))
    return x0, max(0, b[1] - PAD), x1, min(im.height, b[3] + PAD)


def main(spec_path: Path) -> int:
    spec = json.loads(spec_path.read_text())
    cid = spec["id"]
    base = spec_path.parent
    rdir = base / "raw" / "render"
    meta = json.loads((rdir / "meta.json").read_text())
    scale = float(meta["scale"])
    ax, ay = meta["anchor"]

    frames = []          # (anim, index, colour, normal, box)
    for name in spec["animations"]:
        if name not in meta["anims"]:
            continue
        for i in range(meta["anims"][name]["frames"]):
            paint = base / "raw" / "paint" / name / f"{i:02d}.png"
            col = Image.open(paint if paint.exists() else rdir / name / f"{i:02d}.png").convert("RGBA")
            nrm = Image.open(rdir / name / f"{i:02d}_n.png").convert("RGBA")
            frames.append((name, i, col, nrm, trim(col, ax)))

    # shelf packing in animation order (rows of frames, a new shelf when the row is full)
    x = y = shelf = 0
    place = []
    for f in frames:
        b = f[4]
        w, h = b[2] - b[0], b[3] - b[1]
        if x + w > MAX_W:
            x, y, shelf = 0, y + shelf, 0
        place.append((x, y))
        x += w
        shelf = max(shelf, h)
    W = max(px + (f[4][2] - f[4][0]) for f, (px, _) in zip(frames, place))
    H = y + shelf
    sheet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    nsheet = Image.new("RGBA", (W, H), (128, 128, 255, 0))
    anims = {}
    for (name, i, col, nrm, b), (px, py) in zip(frames, place):
        sheet.paste(col.crop(b), (px, py))
        nsheet.paste(nrm.crop(b), (px, py))
        m = meta["anims"][name]
        a = anims.setdefault(name, {
            "row": 0, "frames": m["frames"], "ticks_per_frame": max(1, round(60 / float(m["fps"]))),
            "loop": m["loop"], "hand": m["hand"], "weapon_angle": m["weapon_angle"],
            "active_frames": m["active"], "rects": []})
        a["rects"].append([px, py, b[2] - b[0], b[3] - b[1], round(ax - b[0]), round(ay - b[1])])

    out = ROOT / "assets" / "characters" / cid
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / "sheet.png", optimize=True)
    nsheet.save(out / "sheet_n.png", optimize=True)
    data = {"cell": meta["cell"], "anchor": meta["anchor"], "scale": round(1 / scale, 6),
            "filter": "nearest" if meta.get("look") == "pixel" else "linear", "normal_map": "sheet_n.png",
            "source": "tools/blender/pack_sheet.py", "anims": anims}
    (out / "sheet.json").write_text(json.dumps(data, separators=(",", ":")) + "\n")

    # portrait (head crop of the first idle frame) for the HUD, at game resolution
    first = frames[0]
    col, b = first[2], first[4]
    head = col.crop((b[0], b[1], b[2], b[1] + int(28 * scale))).resize(
        (max(1, round((b[2] - b[0]) / scale)), 28), Image.LANCZOS)
    pw = 24
    portrait = Image.new("RGBA", (pw, 24), (0, 0, 0, 0))
    hb = head.getbbox() or (0, 0, head.width, head.height)
    hc = head.crop(hb)
    hc.thumbnail((pw, 24), Image.LANCZOS)
    portrait.alpha_composite(hc, ((pw - hc.width) // 2, 24 - hc.height))
    portrait.save(out / "portrait.png")

    prev = base / "preview"
    prev.mkdir(exist_ok=True)
    for name in anims:
        fr = [f for f in frames if f[0] == name]
        w, h = fr[0][2].size
        strip = Image.new("RGBA", (w * len(fr) // 2, h // 2), (196, 196, 200, 255))
        for k, f in enumerate(fr):
            strip.alpha_composite(f[2].resize((w // 2, h // 2), Image.LANCZOS), (k * w // 2, 0))
        strip.save(prev / f"{name}.png")
    print(f"assets/characters/{cid}/sheet.png  {W}x{H}, {len(frames)} frames in {len(anims)} animations")
    return 0


if __name__ == "__main__":
    sys.exit(main(Path(sys.argv[1])))
