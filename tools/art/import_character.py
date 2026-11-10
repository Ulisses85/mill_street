#!/usr/bin/env python3
"""Turn AI-generated (or hand-drawn) character art into the template's sprite-sheet format.

    python3 tools/art/import_character.py art/characters/<id>/character.json

Reads whatever a generator gave you, from art/characters/<id>/raw/:
  * a folder of frame PNGs            "source": "raw/idle"
  * a sprite strip or grid PNG        "source": "raw/walk.png", "frames": 8   (or "grid": [4, 2])
  * an animated GIF                   "source": "raw/attack.gif"
and writes:
  assets/characters/<id>/sheet.png + sheet.json + portrait.png     (what the game loads)
  art/characters/<id>/preview/contact.png + <anim>.gif              (for review)

Per frame it removes a solid background, scales the character to `target_height`, puts the feet
on the template's anchor, reduces colours to one shared palette and optionally adds an outline.
Animations the template needs but you didn't provide are synthesized (knockdown, getup, aliases)
so a new character works with as few as 3-4 generated animations. See tools/art/README.md.
"""
from __future__ import annotations

import json
import math
import sys
from collections import Counter
from pathlib import Path

from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[2]
CELL = (160, 128)
ANCHOR = (80, 116)

# The hero's move slots. punch_N / kick_N are the hits of the punch and kick combos (the last one is the finisher);
# their names are slot IDs, the art in them can be any move (a jab, a slash, a headbutt...).
COMBO_SLOTS = ["punch_1", "punch_2", "punch_3", "kick_1", "kick_2"]
# Names used before the slots were renamed; specs that still use them keep working.
LEGACY_NAMES = {"jab": "punch_1", "cross": "punch_2", "hook": "punch_3", "lowkick": "kick_1", "jpunch": "jump_punch", "jkick": "jump_kick"}
PLAYER_ANIMS = ["idle", "run", *COMBO_SLOTS, "jump", "jump_punch", "jump_kick", "defend", "hurt",
                "knockdown", "down", "getup", "grab", "grab_knee", "throw", "swing", "toss", "carry", "carry_idle", "pickup"]
ENEMY_BASE = ["idle", "walk", "run", "windup", "hurt", "defend", "grabbed", "knockdown", "down", "getup", "lurk"]
ARMED = ["swing", "pickup", "windup_armed"]

SWING_ANIMS = {"swing", "smash", "slam"}
WINDUP_POSE_DIFF = 0.1   # an attack frame counts as "wound up" once >10% of it differs from every idle frame


def required_anims(spec: dict) -> list[str]:
    role = spec.get("role", "enemy")
    if role == "player":
        return PLAYER_ANIMS
    req = ENEMY_BASE + [spec.get("attack_animation", "punch")]
    if spec.get("can_use_weapons", role == "enemy" and spec.get("preset", "thug") == "thug"):
        req += ARMED
    return req


# ---------------------------------------------------------------- loading
def load_frames(base: Path, a: dict) -> list[Image.Image]:
    src = base / a["source"]
    if src.is_dir():
        files = sorted(p for p in src.iterdir() if p.suffix.lower() in (".png", ".gif", ".webp"))
        if not files:
            raise SystemExit(f"no frames in {src}")
        return [Image.open(p).convert("RGBA") for p in files]
    if not src.exists():
        raise SystemExit(f"missing source {src}")
    im = Image.open(src)
    if getattr(im, "is_animated", False):
        return [f.convert("RGBA") for f in ImageSequence.Iterator(im)]
    im = im.convert("RGBA")
    if "grid" in a:
        cols, rows = a["grid"]
        return _split(im, cols, rows, a.get("frames", cols * rows))
    n = a.get("frames")
    if n:
        if im.width >= im.height:
            return _split(im, n, 1, n)
        return _split(im, 1, n, n)
    return _auto_split(im)


def _split(im: Image.Image, cols: int, rows: int, n: int) -> list[Image.Image]:
    w, h = im.width // cols, im.height // rows
    out = []
    for i in range(n):
        c, r = i % cols, i // cols
        out.append(im.crop((c * w, r * h, c * w + w, r * h + h)))
    return out


def _auto_split(im: Image.Image) -> list[Image.Image]:
    """Split a strip on empty (background) columns."""
    mask = _foreground(im)
    cols = [any(mask.getpixel((x, y)) for y in range(0, im.height, 2)) for x in range(im.width)]
    segs, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start > 3:
                segs.append((start, x))
            start = None
    if len(segs) <= 1:
        return [im]
    return [im.crop((max(0, a - 2), 0, min(im.width, b + 2), im.height)) for a, b in segs]


# ---------------------------------------------------------------- background
def _has_alpha(im: Image.Image) -> bool:
    a = im.getchannel("A")
    lo, _ = a.getextrema()
    return lo < 250


def _bg_color(im: Image.Image) -> tuple:
    w, h = im.size
    pts = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (0, h // 2), (w - 1, h // 2)]
    return Counter(im.getpixel(p)[:3] for p in pts).most_common(1)[0][0]


def _foreground(im: Image.Image, bg: tuple | None = None, tol: int = 28) -> Image.Image:
    """1-bit mask of the character."""
    if _has_alpha(im):
        return im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).convert("1")
    bg = bg or _bg_color(im)
    w, h = im.size
    px = im.load()
    seen = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]

    def near(c):
        return abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) <= tol * 3

    while stack:  # flood fill background from the borders
        x, y = stack.pop()
        i = y * w + x
        if seen[i] or not near(px[x, y]):
            continue
        seen[i] = 1
        if x > 0: stack.append((x - 1, y))
        if x < w - 1: stack.append((x + 1, y))
        if y > 0: stack.append((x, y - 1))
        if y < h - 1: stack.append((x, y + 1))
    mask = Image.new("1", (w, h), 1)
    mp = mask.load()
    for i, s in enumerate(seen):
        if s:
            mp[i % w, i // w] = 0
    return mask


def clean(im: Image.Image, bg_setting) -> Image.Image:
    if bg_setting == "none":
        return im
    bg = None
    if isinstance(bg_setting, str) and bg_setting.startswith("#"):
        bg = tuple(int(bg_setting[i:i + 2], 16) for i in (1, 3, 5))
    m = _foreground(im, bg)
    out = im.copy()
    out.putalpha(m.convert("L"))
    return out


# ---------------------------------------------------------------- geometry
def bbox(im: Image.Image):
    return im.getchannel("A").point(lambda v: 255 if v >= 128 else 0).getbbox()


def pose_diff(a: Image.Image, b: Image.Image) -> float:
    """Share of pixels (over the union of both silhouettes) that differ in coverage or colour."""
    pa, pb = a.convert("RGBA").load(), b.convert("RGBA").load()
    n = d = 0
    for y in range(min(a.height, b.height)):
        for x in range(min(a.width, b.width)):
            A, B = pa[x, y], pb[x, y]
            if A[3] < 128 and B[3] < 128:
                continue
            n += 1
            if (A[3] >= 128) != (B[3] >= 128) or abs(A[0] - B[0]) + abs(A[1] - B[1]) + abs(A[2] - B[2]) > 60:
                d += 1
    return d / n if n else 0.0


def feet(im: Image.Image) -> tuple[float, int]:
    """(x, y) of the feet: centre of the bottom 12% of the body, lowest opaque row."""
    b = bbox(im)
    if not b:
        return im.width / 2, im.height - 1
    a = im.getchannel("A").load()
    band = max(2, int((b[3] - b[1]) * 0.12))
    xs = [x for y in range(b[3] - band, b[3]) for x in range(b[0], b[2]) if a[x, y] >= 128]
    return (sum(xs) / len(xs) if xs else (b[0] + b[2]) / 2), b[3] - 1


def scale_frame(im: Image.Image, k: float) -> Image.Image:
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    if abs(k - round(k)) < 0.01 and k >= 1:
        return im.resize((w, h), Image.NEAREST)
    if k < 1:
        # area-average colours, then snap alpha back to hard pixel edges
        rgb = im.resize((w, h), Image.BOX)
        alpha = im.getchannel("A").resize((w, h), Image.BOX).point(lambda v: 255 if v >= 110 else 0)
        rgb.putalpha(alpha)
        return rgb
    return im.resize((w, h), Image.NEAREST)


def place(im: Image.Image, at: tuple[float, int] | None = None) -> Image.Image:
    """Put the character in a template cell with its feet on ANCHOR.
    `at` overrides the feet position (used by "align": "canvas" to keep every frame's offset in its source canvas)."""
    fx, fy = at if at is not None else feet(im)
    cell = Image.new("RGBA", CELL, (0, 0, 0, 0))
    cell.alpha_composite(im, (round(ANCHOR[0] - fx), ANCHOR[1] - fy)) if _fits(im, fx, fy) else _paste_clipped(cell, im, fx, fy)
    return cell


def _fits(im, fx, fy):
    x, y = round(ANCHOR[0] - fx), ANCHOR[1] - fy
    return x >= 0 and y >= 0 and x + im.width <= CELL[0] and y + im.height <= CELL[1]


def _paste_clipped(cell, im, fx, fy):
    cell.paste(im, (round(ANCHOR[0] - fx), ANCHOR[1] - fy), im)


def rotate_about_anchor(cell: Image.Image, deg: float, shift: tuple[float, float]) -> Image.Image:
    out = cell.rotate(deg, resample=Image.NEAREST, center=ANCHOR, translate=shift)
    return out


# ---------------------------------------------------------------- palette
def to_palette(frames: list[Image.Image], max_colors: int, lock: list[str]) -> list[Image.Image]:
    opaque = [f for f in frames]
    w = sum(f.width for f in opaque)
    strip = Image.new("RGB", (w, CELL[1]), (0, 0, 0))
    x = 0
    for f in opaque:
        strip.paste(f.convert("RGB"), (x, 0), f.getchannel("A"))
        x += f.width
    # sample only opaque pixels for the palette
    pixels = []
    for f in frames:
        rgb, a = f.convert("RGB").load(), f.getchannel("A").load()
        for yy in range(0, f.height):
            for xx in range(0, f.width):
                if a[xx, yy] >= 128:
                    pixels.append(rgb[xx, yy])
    if not pixels:
        return frames
    sample = Image.new("RGB", (len(pixels), 1))
    sample.putdata(pixels)
    pal = sample.quantize(colors=max(2, max_colors - len(lock)), method=Image.Quantize.MEDIANCUT)
    colors = pal.getpalette()[: 3 * max(2, max_colors - len(lock))]
    for h in lock:
        colors += [int(h[i:i + 2], 16) for i in (1, 3, 5)]
    pal_img = Image.new("P", (1, 1))
    pal_img.putpalette(colors + [0] * (768 - len(colors)))
    out = []
    for f in frames:
        q = f.convert("RGB").quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(f.getchannel("A").point(lambda v: 255 if v >= 128 else 0))
        out.append(q)
    return out


def add_outline(f: Image.Image, color: tuple) -> Image.Image:
    a = f.getchannel("A").load()
    w, h = f.size
    out = f.copy()
    px = out.load()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if a[x, y] < 128 and (a[x - 1, y] >= 128 or a[x + 1, y] >= 128 or a[x, y - 1] >= 128 or a[x, y + 1] >= 128):
                px[x, y] = (*color, 255)
    return out


# ---------------------------------------------------------------- weapon bone
def hand(cell: Image.Image, height: int) -> list[int]:
    """Front-most opaque pixel in the arm band, relative to the anchor (facing right)."""
    a = cell.getchannel("A").load()
    y0, y1 = ANCHOR[1] - int(height * 0.78), ANCHOR[1] - int(height * 0.42)
    best = None
    for x in range(CELL[0] - 1, ANCHOR[0] - 2, -1):
        ys = [y for y in range(max(0, y0), min(CELL[1], y1)) if a[x, y] >= 128]
        if ys:
            best = (x, sum(ys) / len(ys))
            break
    if best is None:
        return [9, -int(height * 0.62)]
    return [int(best[0] - ANCHOR[0] - 2), int(round(best[1] - ANCHOR[1]))]


def weapon_angles(name: str, n: int, active: list[int] | None) -> list[float]:
    if name in SWING_ANIMS and active:
        return [(-2.5 if i < active[0] else 0.05 if i <= active[1] else 0.6) for i in range(n)]
    if name.startswith("windup"):
        return [-2.5] * n
    if name == "toss":
        a0 = active[0] if active else n // 3
        return [(-2.2 if i < a0 else -0.3) for i in range(n)]
    if name in (*COMBO_SLOTS, "kick", "jump", "jump_punch", "jump_kick", "punch"):
        return [-0.3] * n
    return [-1.1] * n


# ---------------------------------------------------------------- synthesis
def synth(name: str, have: dict, spec: dict) -> dict | None:
    """Build a missing animation from the ones we have. Returns {frames, tpf, loop, active?, note}."""
    atk = spec.get("attack_animation", "punch")

    def pick(*names):
        for n in names:
            if n in have:
                return n
        return None

    def hold(src, which="first", note=""):
        s = have[src]
        if which == "active" and s.get("active"):
            f = s["frames"][s["active"][0]]
        elif which == "last":
            f = s["frames"][-1]
        else:
            f = s["frames"][0]
        return {"frames": [f], "tpf": 1, "loop": True, "note": note or f"held {which} frame of {src}"}

    def copy(src, tpf_scale=1.0, note=""):
        s = have[src]
        d = {"frames": list(s["frames"]), "tpf": max(1, round(s["tpf"] * tpf_scale)), "loop": s["loop"], "note": note or f"copy of {src}"}
        if s.get("active"):
            d["active"] = list(s["active"])
        return d

    if name == "windup":
        src = pick(atk, "punch")
        if src:
            s = have[src]
            idle = have["idle"]["frames"] if "idle" in have else []
            # wind-up = the attack's lead-in: from the first frame that no longer matches an idle pose
            # up to the frame before the hit; played once, holding the last (most wound-up) frame
            start = next((i for i, f in enumerate(s["frames"]) if not idle or min(pose_diff(f, g) for g in idle) > WINDUP_POSE_DIFF), 0)
            end = s["active"][0] if s.get("active") else 1
            if start < end:
                # trim=(src, end): the caller drops frames 0..end-1 from the attack so it doesn't replay
                # the lead-in (arm drops back, then raises again) right after the windup
                return {"frames": s["frames"][start:end], "tpf": s["tpf"], "loop": False, "trim": (src, end),
                        "note": f"{src} frames {start}-{end - 1} (lead-in before the hit; trimmed from {src})"}
            return hold(src, "first")

    hurt_src = pick("hurt", "idle")
    if name == "knockdown" and hurt_src:
        f0 = have[hurt_src]["frames"][0]
        frames = [rotate_about_anchor(f0, 90 * q, (6 * q, -3 * q)) for q in [i / 5 for i in range(6)]]
        return {"frames": frames, "tpf": 2, "loop": False, "note": f"rotated {hurt_src} falling"}
    if name == "down" and hurt_src:
        f0 = have[hurt_src]["frames"][0]
        return {"frames": [rotate_about_anchor(f0, 90, (6, -3))], "tpf": 1, "loop": True, "note": f"{hurt_src} lying flat"}
    if name == "getup" and hurt_src:
        f0 = have[hurt_src]["frames"][0]
        idle0 = have[pick("idle", hurt_src)]["frames"][0]
        frames = [rotate_about_anchor(f0, 90 * (1 - i / 6), (6 * (1 - i / 6), -3 * (1 - i / 6))) for i in range(7)] + [idle0] * 3
        return {"frames": frames, "tpf": 2, "loop": False, "note": f"{hurt_src} rotating back up"}
    if name == "pickup" and "idle" in have:
        f = have["idle"]["frames"][0]
        b = bbox(f)
        squat = f.resize((f.width, f.height), Image.NEAREST)
        if b:
            body = f.crop(b)
            body = body.resize((body.width, max(1, int(body.height * 0.78))), Image.NEAREST)
            squat = Image.new("RGBA", CELL, (0, 0, 0, 0))
            squat.alpha_composite(body, (b[0], ANCHOR[1] - body.height + 1))
        return {"frames": [squat], "tpf": 1, "loop": True, "note": "idle squashed into a crouch"}
    rules = {
        "run": [("walk", "copy", 0.75)], "walk": [("run", "copy", 1.33)], "lurk": [("idle", "copy", 1.8)],
        "windup_armed": [("windup", "copy"), (atk, "first")],
        "defend": [("block", "copy"), ("idle", "first")], "grabbed": [("hurt", "copy"), ("idle", "first")],
        "hurt": [("idle", "first")], "swing": [(atk, "copy"), ("punch", "copy")],
        "punch_1": [("punch", "copy")], "punch_2": [("punch", "copy", 1.1)], "punch_3": [("punch_2", "copy", 1.4), ("punch", "copy", 1.5)],
        "kick_1": [("kick_2", "copy", 0.8), ("punch", "copy")], "kick_2": [("kick_1", "copy", 1.4), ("punch", "copy", 1.6)],
        "jump": [("idle", "first")], "jump_punch": [("punch", "active"), ("punch_1", "active")], "jump_kick": [("kick_2", "active"), ("kick_1", "active")],
        "grab": [("punch", "first"), ("punch_1", "first")], "grab_knee": [("kick_2", "active"), ("kick_1", "active")],
        "throw": [("punch", "last"), ("punch_1", "last")], "toss": [("punch", "copy"), ("punch_1", "copy")],
        "carry": [("walk", "copy"), ("run", "copy", 1.4)], "carry_idle": [("idle", "first")],
    }
    for rule in rules.get(name, []):
        src = rule[0]
        if src not in have:
            continue
        kind = rule[1]
        if kind == "copy":
            return copy(src, rule[2] if len(rule) > 2 else 1.0)
        return hold(src, kind)
    return None


# ---------------------------------------------------------------- main
def main(spec_path: Path) -> int:
    spec = json.loads(spec_path.read_text())
    base = spec_path.parent
    cid = spec["id"]
    target_h = int(spec.get("target_height", 58))
    pal_cfg = spec.get("palette", {})
    bg_setting = spec.get("background", "auto")
    flip = spec.get("source_facing", "right") == "left"
    warnings: list[str] = []

    if spec.get("role") == "player":
        for old, new in LEGACY_NAMES.items():
            if old in spec["animations"] and new not in spec["animations"]:
                spec["animations"][new] = spec["animations"].pop(old)
                warnings.append(f"animation '{old}' is now called '{new}' - rename it in the spec")
        # A hero's generated "kick" is the kick combo's finisher; the other kick slots are cut from it.
        if "kick" in spec["animations"] and "kick_2" not in spec["animations"]:
            spec["animations"]["kick_2"] = spec["animations"].pop("kick")
    raw: dict[str, list[Image.Image]] = {}
    for name, a in spec["animations"].items():
        frames = [clean(f, bg_setting) for f in load_frames(base, a)]
        if flip:
            frames = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in frames]
        raw[name] = frames

    ref_name = "idle" if "idle" in raw else next(iter(raw))
    b = bbox(raw[ref_name][0])
    if not b:
        raise SystemExit(f"{ref_name}: first frame is empty after background removal")
    k = target_h / (b[3] - b[1])
    print(f"[{cid}] reference '{ref_name}' is {b[3] - b[1]}px tall -> scale x{k:.3f} to {target_h}px")

    have: dict[str, dict] = {}
    for name, frames in raw.items():
        a = spec["animations"][name]
        if a.get("align") == "canvas":
            # keep the motion inside the generator's canvas (falls, get-ups): every frame gets the offset
            # of the reference idle frame, which shares the canvas size and ground line
            ref0 = raw[ref_name][0]
            if any(f.size != ref0.size for f in frames):
                warnings.append(f"{name}: align canvas needs frames the size of {ref_name}'s ({ref0.size}); "
                                f"got {sorted({f.size for f in frames})} - placed per frame instead")
                cells = [place(scale_frame(f, k)) for f in frames]
            else:
                at = feet(scale_frame(ref0, k))
                cells = [place(scale_frame(f, k), at) for f in frames]
        else:
            cells = [place(scale_frame(f, k)) for f in frames]
        hs = [(bbox(c)[3] - bbox(c)[1]) if bbox(c) else 0 for c in cells]
        if hs and name in ("idle", "walk", "run") and max(hs) > target_h * 1.25:
            warnings.append(f"{name}: frames up to {max(hs)}px tall (target {target_h}) - check the source scale")
        for i, c in enumerate(cells):
            bb = bbox(c)
            if bb and (bb[0] == 0 or bb[2] >= CELL[0] or bb[1] == 0):
                warnings.append(f"{name} frame {i}: touches the cell edge ({CELL[0]}x{CELL[1]}) and may be clipped")
                break
        fps = float(a.get("fps", 10))
        entry = {"frames": cells, "tpf": max(1, round(60 / fps)), "loop": bool(a.get("loop", name in ("idle", "walk", "run", "lurk", "carry")))}
        if "active" in a:
            entry["active"] = a["active"]
        elif name in (spec.get("attack_animation", "punch"), "punch", "kick", *COMBO_SLOTS, "swing", "smash", "slam", "toss"):
            n = len(cells)
            entry["active"] = [n // 3, max(n // 3, (2 * n) // 3 - 1)]
        have[name] = entry

    required = required_anims(spec)
    synthesized = []
    for _ in range(3):  # aliases may depend on other synthesized anims
        for name in required:
            if name in have:
                continue
            s = synth(name, have, spec)
            if s:
                trim = s.pop("trim", None)
                if trim:   # the windup took the attack's lead-in: start the attack at its first hit frame
                    src, cut = trim
                    a = have[src]
                    a["frames"] = a["frames"][cut:]
                    a["active"] = [a["active"][0] - cut, a["active"][1] - cut]
                have[name] = s
                synthesized.append(f"{name}: {s.pop('note')}")
    missing = [n for n in required if n not in have]

    order = [n for n in required if n in have] + [n for n in have if n not in required]
    all_frames = [f for n in order for f in have[n]["frames"]]
    all_frames = to_palette(all_frames, int(pal_cfg.get("max_colors", 24)), pal_cfg.get("lock", []))
    if pal_cfg.get("outline"):
        oc = tuple(int(pal_cfg["outline"][i:i + 2], 16) for i in (1, 3, 5))
        all_frames = [add_outline(f, oc) for f in all_frames]
    it = iter(all_frames)
    for n in order:
        have[n]["frames"] = [next(it) for _ in have[n]["frames"]]

    cols = max(len(have[n]["frames"]) for n in order)
    sheet = Image.new("RGBA", (CELL[0] * cols, CELL[1] * len(order)), (0, 0, 0, 0))
    meta = {"cell": list(CELL), "anchor": list(ANCHOR), "columns": cols, "anims": {}, "source": "tools/art/import_character.py"}
    for row, n in enumerate(order):
        e = have[n]
        for col, f in enumerate(e["frames"]):
            sheet.alpha_composite(f, (col * CELL[0], row * CELL[1]))
        m = {"row": row, "frames": len(e["frames"]), "ticks_per_frame": e["tpf"], "loop": e["loop"],
             "hand": [hand(f, target_h) for f in e["frames"]],
             "weapon_angle": weapon_angles(n, len(e["frames"]), e.get("active"))}
        if e.get("active"):
            m["active_frames"] = e["active"]
        meta["anims"][n] = m

    out = ROOT / "assets/characters" / cid
    out.mkdir(parents=True, exist_ok=True)
    sheet.save(out / "sheet.png")
    (out / "sheet.json").write_text(json.dumps(meta, indent=1))
    _portrait(have["idle" if "idle" in have else order[0]]["frames"][0], target_h).save(out / "portrait.png")
    _previews(base / "preview", order, have)

    used = len({px for f in all_frames for px in f.convert("RGBA").get_flattened_data() if px[3]})
    print(f"[{cid}] wrote {out.relative_to(ROOT)}/sheet.png: {len(order)} animations, {cols} columns, {used} colours")
    for s in synthesized:
        print(f"  synthesized  {s}")
    for w in warnings:
        print(f"  WARNING      {w}")
    for m_ in missing:
        print(f"  MISSING      {m_} (no source and no fallback)")
    timing = {n: round(len(have[n]['frames']) * have[n]['tpf'] / 60, 2) for n in order if have[n].get("active")}
    if timing:
        print("  attack timing (s) for AttackData.duration / active window:")
        for n, d in timing.items():
            a0, a1 = have[n]["active"]
            print(f"    {n:10s} duration={d}  active_from={round(a0 * have[n]['tpf'] / 60, 2)}  active_to={round((a1 + 1) * have[n]['tpf'] / 60, 2)}")
    report = {"id": cid, "animations": order, "synthesized": synthesized, "warnings": warnings, "missing": missing, "colors": used, "timing": timing}
    (base / "import_report.json").write_text(json.dumps(report, indent=1))
    return 1 if missing else 0


def _portrait(cell: Image.Image, h: int) -> Image.Image:
    b = bbox(cell)
    p = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
    if not b:
        return p
    head_h = max(8, int(h * 0.28))
    cx = (b[0] + b[2]) // 2
    row = [x for x in range(b[0], b[2]) if cell.getpixel((x, b[1] + 2))[3] >= 128]
    if row:
        cx = (min(row) + max(row)) // 2
    crop = cell.crop((cx - head_h // 2 - 2, b[1], cx + head_h // 2 + 2, b[1] + head_h))
    s = 18 / max(crop.width, crop.height)
    crop = crop.resize((max(1, round(crop.width * s)), max(1, round(crop.height * s))), Image.NEAREST)
    p.alpha_composite(crop, ((20 - crop.width) // 2, 1))
    return p


def _previews(folder: Path, order: list[str], have: dict) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    bgc = (200, 200, 214, 255)
    cols = max(len(have[n]["frames"]) for n in order)
    contact = Image.new("RGBA", (CELL[0] * cols, CELL[1] * len(order)), bgc)
    for r, n in enumerate(order):
        for c, f in enumerate(have[n]["frames"]):
            contact.alpha_composite(f, (c * CELL[0], r * CELL[1]))
    contact.convert("RGB").save(folder / "contact.png")
    for n in order:
        frames = []
        for f in have[n]["frames"]:
            bgim = Image.new("RGBA", CELL, bgc)
            bgim.alpha_composite(f)
            frames.append(bgim.resize((CELL[0] * 2, CELL[1] * 2), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
        dur = max(20, int(1000 * have[n]["tpf"] / 60))
        frames[0].save(folder / f"{n}.gif", save_all=True, append_images=frames[1:], duration=dur, loop=0, disposal=2)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(Path(sys.argv[1]).resolve()))
