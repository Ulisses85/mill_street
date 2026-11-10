"""AI-made (or hand-drawn) level art for the level kit.

level_kit.py uses this when a level spec has an "ai" block whose layer folders hold images. Any layer
without images is still drawn by code, so a level can mix both (e.g. AI skyline, code-drawn street).

    "ai": {
      "palette_mode": "free",          free: keep the art's colours, reduced to max_colors shared by all layers;
                                       the floor and any code-drawn parts use a 7-colour ramp taken from the art.
                                       level: snap the art to the spec's 7-colour palette (the pale template world).
      "max_colors": 32,
      "layers": {
        "sky":    {"source": "raw/sky"},                       one image, scaled to fill 270 px tall, repeats
        "far":    {"source": "raw/far", "bottom": 150},        skyline on a transparent or plain background
        "near":   {"source": "raw/near", "bottom": 150},
        "facade": {"source": "raw/facade",                     building fronts, one per image, feet on the ground line
                   "landmarks": [{"image": "pub.png", "x": 640, "sign": {"text": "SPINNERS ARMS", "y": 92}},
                                 {"piece": "billboard", "x": 20, "width": 220, "text": ["MILL ST."]}]}
                                       a landmark with "piece" (billboard, alley, ... any level_kit piece) is drawn
                                       by code at its x and width, among the AI fronts
      }
    }

Images can be any size: they're cleaned (background removed), scaled (layer "height", or "scale"),
made to repeat where needed and reduced to the palette. Generate at the target size to keep pixels 1:1:
sky 384x270, far/near 384x140, facades up to 384 wide x 140 tall (see the level-art skill).
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "art"))
from import_character import clean  # noqa: E402  (background removal shared with the character importer)

IMAGE_EXT = (".png", ".gif", ".webp", ".jpg", ".jpeg")


def images_in(folder: Path) -> list[Path]:
    if folder.is_file():
        return [folder]
    if not folder.is_dir():
        return []
    return sorted(p for p in folder.iterdir() if p.suffix.lower() in IMAGE_EXT)


def _resize(im: Image.Image, w: int, h: int) -> Image.Image:
    if (w, h) == im.size:
        return im
    if w % im.width == 0 and h % im.height == 0:
        return im.resize((w, h), Image.NEAREST)          # whole-number upscale stays crisp
    return im.resize((w, h), Image.LANCZOS)              # requantized afterwards


def seamless(im: Image.Image, band: int = 32) -> Image.Image:
    """Make an image repeat horizontally: blend its last `band` columns into its first ones.
    The result is `band` px narrower and its right edge continues into its left edge."""
    w, h = im.size
    if w <= band * 3:
        return im
    out = im.crop((0, 0, w - band, h))
    end = im.crop((w - band, 0, w, h))
    start = im.crop((0, 0, band, h))
    for x in range(band):
        t = (x + 0.5) / band
        col = Image.blend(end.crop((x, 0, x + 1, h)), start.crop((x, 0, x + 1, h)), t)
        out.paste(col, (x, 0))
    return out


def edges_clear(im: Image.Image) -> bool:
    a = im.getchannel("A")
    return a.crop((0, 0, 1, im.height)).getbbox() is None and a.crop((im.width - 1, 0, im.width, im.height)).getbbox() is None


def load_layer(base: Path, key: str, cfg: dict, H: int, base_y: int) -> Image.Image | None:
    files = images_in(base / cfg.get("source", f"raw/{key}"))
    if not files:
        return None
    im = Image.open(files[0]).convert("RGBA")
    if key == "sky":
        k = H / im.height
        im = _resize(im, max(1, round(im.width * k)), H)
        im.putalpha(255)
        return im if cfg.get("tiles", False) else seamless(im)
    im = clean(im, cfg.get("background", "auto"))
    b = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
    if not b:
        return None
    im = im.crop((0, b[1], im.width, b[3]))                # keep full width (it may be drawn to tile)
    if "height" in cfg or "scale" in cfg:
        k = cfg["height"] / im.height if "height" in cfg else float(cfg["scale"])
        im = _resize(im, max(1, round(im.width * k)), max(1, round(im.height * k)))
    if not cfg.get("tiles", False) and not edges_clear(im):
        im = seamless(im)
    out = Image.new("RGBA", (im.width, H), (0, 0, 0, 0))
    out.alpha_composite(im, (0, max(0, cfg.get("bottom", base_y + 10) - im.height)))
    return out


def load_facades(base: Path, cfg: dict) -> dict[str, Image.Image]:
    """Building fronts, cropped to their content, keyed by file name."""
    out = {}
    for f in images_in(base / cfg.get("source", "raw/facade")):
        im = clean(Image.open(f).convert("RGBA"), cfg.get("background", "auto"))
        b = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()
        if not b:
            continue
        im = im.crop(b)
        if "height" in cfg or "scale" in cfg:
            k = cfg["height"] / im.height if "height" in cfg else float(cfg["scale"])
            im = _resize(im, max(1, round(im.width * k)), max(1, round(im.height * k)))
        out[f.name] = im
    return out


def plan_facades(fronts: dict[str, Image.Image], cfg: dict, world: int, seed: int) -> tuple[list, list, list]:
    """Lay the fronts along the street.

    A landmark is either an AI front ({"image": "pub.png", "x": ...}) or a code-drawn piece
    ({"piece": "billboard", "x": ..., "width": ..., "text": [...]}, any key of level_kit.PIECES), which
    keeps its x and width among the AI fronts.
    Returns (placed [(name, x)], gaps [(x, width)] for code-drawn filler, pieces [(piece, x, width, landmark)])."""
    rng = random.Random(seed)
    marks = sorted(cfg.get("landmarks", []), key=lambda m: m["x"])
    fill = [n for n in fronts if n not in {m["image"] for m in marks if "image" in m}] or list(fronts)
    placed, gaps, pieces, x, prev = [], [], [], 0, None

    def fill_to(end):
        nonlocal x, prev
        while end - x > 0:
            fits = [n for n in fill if fronts[n].width <= end - x and n != prev] or \
                   [n for n in fill if fronts[n].width <= end - x]
            if not fits:
                gaps.append((x, end - x))
                x = end
                return
            n = rng.choice(fits)
            placed.append((n, x))
            x += fronts[n].width
            prev = n

    for m in marks:
        if "piece" in m:                                    # code-drawn landmark at its own x
            fill_to(max(x, m["x"]))
            w = int(m.get("width", 200))
            pieces.append((m["piece"], x, w, m))
            x += w
            prev = None
            continue
        if m["image"] not in fronts:
            raise SystemExit(f"landmark image {m['image']} not found in the facade folder")
        fill_to(max(x, m["x"]))
        placed.append((m["image"], x))
        x += fronts[m["image"]].width
        prev = m["image"]
    fill_to(world)
    return placed, gaps, pieces


# ---------------------------------------------------------------- palette
def _visible(im: Image.Image) -> list[tuple]:
    px = im.getdata()
    return [p[:3] for p in px if p[3] >= 128]


def shared_palette(images: list[Image.Image], n: int) -> Image.Image:
    """One palette for all the level's AI art, so the layers belong together."""
    sample = []
    for im in images:
        small = im if im.width * im.height <= 200_000 else im.resize((im.width // 2, im.height // 2), Image.NEAREST)
        sample += _visible(small)
    strip = Image.new("RGB", (len(sample), 1))
    strip.putdata(sample)
    return strip.quantize(colors=n, method=Image.MEDIANCUT, dither=Image.NONE)


def apply_palette(im: Image.Image, pal_img: Image.Image) -> Image.Image:
    a = im.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    q = im.convert("RGB").quantize(palette=pal_img, dither=Image.NONE).convert("RGBA")
    q.putalpha(a)
    return q


def snap_to_ramp(im: Image.Image, ramp: list[tuple]) -> Image.Image:
    """Map every pixel to the ramp colour of nearest brightness (keeps the template's mono look)."""
    lum = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for c in ramp]
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            l = 0.299 * r + 0.587 * g + 0.114 * b
            i = min(range(len(lum)), key=lambda k: abs(lum[k] - l))
            px[x, y] = ramp[i][:3] + (255,)
    return out


def ramp_from(images: list[Image.Image], steps: int = 7) -> list[tuple]:
    """A dark-to-light ramp taken from the art's own colours (for the floor and code-drawn parts).
    Picks colours at evenly spaced brightness percentiles, slightly desaturated so the floor stays calm."""
    cols = []
    for im in images:
        small = im.resize((max(1, im.width // 4), max(1, im.height // 4)), Image.NEAREST)
        cols += _visible(small)
    cols.sort(key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    out = []
    for i in range(steps):
        r, g, b = cols[min(len(cols) - 1, int((i + 0.5) / steps * len(cols)))]
        m = (r + g + b) / 3
        out.append((int(r * 0.7 + m * 0.3), int(g * 0.7 + m * 0.3), int(b * 0.7 + m * 0.3), 255))
    return out
