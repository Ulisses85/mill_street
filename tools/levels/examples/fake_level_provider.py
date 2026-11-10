#!/usr/bin/env python3
"""Writes stand-in "AI output" for a level, to test the AI path of the level kit without an API key.

    python3 tools/levels/examples/fake_level_provider.py art/levels/<id>

Writes raw/sky/00.png (384x270), raw/far/00.png and raw/near/00.png (384x140 on a magenta background)
and four building fronts in raw/facade/ (on a green background), in full colour, the way a provider
returns them. Then add an "ai" block to the spec (see tools/levels/ai_layers.py) and run the level kit.
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import level_kit as K  # noqa: E402

WARM = [(40, 26, 46, 255), (78, 42, 64, 255), (128, 62, 70, 255), (176, 96, 80, 255),
        (214, 146, 100, 255), (238, 196, 138, 255), (250, 232, 190, 255)]


def main(folder: Path) -> None:
    rng = random.Random(4)
    raw = folder / "raw"
    sky = Image.new("RGBA", (384, 270))
    d = ImageDraw.Draw(sky)
    for y in range(270):                                       # dusk gradient, smooth (as AI art often is)
        t = y / 269
        d.line([(0, y), (383, y)], fill=(int(70 + 170 * t), int(40 + 120 * t), int(90 + 40 * t), 255))
    for _ in range(9):
        x, y, w = rng.randrange(384), rng.randrange(10, 120), rng.randrange(40, 120)
        d.ellipse([x, y, x + w, y + 10], fill=(250, 200, 170, 255))
    (raw / "sky").mkdir(parents=True, exist_ok=True)
    sky.save(raw / "sky/00.png")
    for key, fn, col in (("far", K.layer_far, (150, 90, 110, 255)), ("near", K.layer_near, (90, 50, 75, 255))):
        layer = fn(WARM, random.Random(len(key)), {"theme": "mills"}).crop((0, 0, 384, 270))
        band = layer.crop((0, 130 - 120, 384, 130 + 10))         # the skyline part
        out = Image.new("RGBA", band.size, (255, 0, 255, 255))
        tint = Image.new("RGBA", band.size, col)
        out.paste(tint, (0, 0), band.getchannel("A"))
        (raw / key).mkdir(parents=True, exist_ok=True)
        out.save(raw / key / "00.png")
    (raw / "facade").mkdir(parents=True, exist_ok=True)
    for i, (piece, w) in enumerate([("terrace", 150), ("shop", 130), ("pub", 160), ("mill", 260)]):
        cv = K.Canvas(w + 20, K.H, WARM)
        K.PIECES[piece](cv, random.Random(i), 10, w, {"name": "THE OLD BELL" if piece == "pub" else "WORKS"})
        im = cv.im.crop((0, 0, w + 20, K.BASE))
        bg = Image.new("RGBA", im.size, (0, 200, 60, 255))
        bg.alpha_composite(im)
        bg.save(raw / "facade" / f"{i:02d}_{piece}.png")
    print("wrote stand-in AI art to", raw)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
