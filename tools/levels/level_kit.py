#!/usr/bin/env python3
"""Level kit: draws a level's background art from its spec, by code. No AI, no browser.

    python3 tools/levels/level_kit.py                 # every art/levels/*/level.json
    python3 tools/levels/level_kit.py street wharf    # just these

Reads art/levels/<id>/level.json and writes assets/levels/<art>/:
  background.png   the street itself (parallax 1.0): building fronts, pavement, road. World length.
                   Transparent above the rooftops, so the layers behind show through.
  sky.png          parallax layer, repeats horizontally (default scroll 0.05)
  far.png          distant skyline silhouettes, repeats (default 0.25)
  near.png         nearer rooftops and chimneys, repeats (default 0.5)
  layout.json      the parallax manifest (see LAYERS below) plus foreground signposts

Every layer is drawn to repeat exactly: shapes that cross the right edge are drawn again at the left.
The same spec and seed always give the same pixels.

The look comes from a 7-colour palette ramp (dark -> light). The template's art direction is a pale,
low-contrast world so the red enemies and the hero stand out.
"""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
H = 270
BASE = 140          # where building fronts meet the back pavement
TILE = 960          # width of the repeating parallax layers
FONT = ROOT / "assets/fonts/Silkscreen-Regular.ttf"
FONT_B = ROOT / "assets/fonts/Silkscreen-Bold.ttf"

# Default scroll factor per parallax layer (1.0 = moves with the street).
LAYERS = {"sky": 0.05, "far": 0.25, "near": 0.5}


def hexrgb(h: str) -> tuple[int, int, int, int]:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Canvas:
    """An RGBA image with pixel-art rectangle helpers. Colours are palette indices 0 (dark) .. 6 (light)."""

    def __init__(self, w: int, h: int, pal: list, wrap: bool = False):
        self.w, self.h, self.pal, self.wrap = w, h, pal, wrap
        self.im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def col(self, c):
        return self.pal[c] if isinstance(c, int) else c

    def rect(self, x: int, y: int, w: int, h: int, c) -> None:
        if w <= 0 or h <= 0:
            return
        xs = [x]
        if self.wrap:
            if x < 0:
                xs.append(x + self.w)
            if x + w > self.w:
                xs.append(x - self.w)
        for xx in xs:
            self.d.rectangle([xx, y, xx + w - 1, y + h - 1], fill=self.col(c))

    def px(self, x: int, y: int, c) -> None:
        self.rect(x, y, 1, 1, c)

    def clear(self, x: int, y: int, w: int, h: int) -> None:
        self.d.rectangle([x, y, x + w - 1, y + h - 1], fill=(0, 0, 0, 0))

    def text(self, x: int, y: int, s: str, c, bold: bool = False, size: int = 8, center: bool = False) -> int:
        """Crisp pixel text (Silkscreen, thresholded). Returns the text width."""
        font = ImageFont.truetype(str(FONT_B if bold else FONT), size)
        l, t, r, b = font.getbbox(s)
        tw, th = r - l, b - t
        if center:
            x -= tw // 2
        mask = Image.new("L", (tw + 2, th + 2), 0)
        ImageDraw.Draw(mask).text((1 - l, 1 - t), s, font=font, fill=255)
        mask = mask.point(lambda v: 255 if v >= 128 else 0)
        self.im.paste(Image.new("RGBA", mask.size, self.col(c)), (x - 1, y - 1), mask)
        return tw


# ---------------------------------------------------------------- building parts
def wall(cv: Canvas, rng, x0, w, top, material, c=(4, 5, 6)):
    lo, mid, hi = c
    cv.rect(x0, top, w, BASE - top, mid)
    if material == "brick":
        for r, y in enumerate(range(top, BASE, 4)):
            off = (r % 2) * 4
            for px in range(x0 - off, x0 + w, 8):
                cv.rect(max(px, x0), y, 1, 4, lo) if px >= x0 else None
                if rng.random() < 0.06:
                    cv.rect(max(px + 1, x0), y + 1, 6, 2, lo if rng.random() < 0.5 else hi)
            cv.rect(x0, y + 3, w, 1, lo)
    elif material == "stone":
        for r, y in enumerate(range(top, BASE, 10)):
            off = (r % 2) * 12
            for px in range(x0 - off, x0 + w, 24):
                a = max(px + 1, x0)
                cv.rect(a, y + 1, min(px + 23, x0 + w) - a, 8, lo if rng.random() < 0.1 else mid)
                cv.rect(a, y + 1, min(px + 23, x0 + w) - a, 1, hi)
    elif material == "plaster":
        for _ in range(w // 12):
            cv.rect(x0 + rng.randrange(w), rng.randrange(top, BASE - 4), 2 + rng.randrange(6), 1, lo)
    elif material == "panel":
        for px in range(x0, x0 + w, 20):
            cv.rect(px, top, 1, BASE - top, lo)
            cv.rect(px + 1, top, 1, BASE - top, hi)
    elif material == "corrugated":
        for px in range(x0, x0 + w, 4):
            cv.rect(px, top, 1, BASE - top, lo)
            cv.rect(px + 2, top, 1, BASE - top, hi)


def slate_roof(cv: Canvas, rng, x0, w, top, chimneys=2):
    """A pitched slate roof seen from the street: a dark band above the wall, with chimney stacks."""
    cv.rect(x0, top - 10, w, 10, 2)
    for y in range(top - 9, top, 3):
        cv.rect(x0, y, w, 1, 1)
    cv.rect(x0, top - 11, w, 1, 3)
    cv.rect(x0 - 1, top, w + 2, 2, 3)
    for i in range(chimneys):
        cx = x0 + (w * (i + 1)) // (chimneys + 1) - 6 + rng.randrange(-8, 9)
        ch = 12 + rng.randrange(8)
        cv.rect(cx, top - 10 - ch, 12, ch, 3)
        cv.rect(cx, top - 10 - ch, 12, 2, 4)
        cv.rect(cx + 11, top - 10 - ch, 1, ch, 2)
        for p in range(1 + rng.randrange(3)):
            cv.rect(cx + 2 + p * 3, top - 14 - ch, 2, 4, 1)


def parapet(cv: Canvas, x0, w, top):
    cv.rect(x0 - 1, top - 4, w + 2, 4, 5)
    cv.rect(x0 - 1, top - 4, w + 2, 1, 6)
    cv.rect(x0 - 1, top - 1, w + 2, 1, 3)


def cornice(cv: Canvas, x0, w, y):
    cv.rect(x0 - 2, y, w + 4, 3, 6)
    cv.rect(x0 - 2, y + 3, w + 4, 2, 4)
    cv.rect(x0 - 2, y + 5, w + 4, 1, 3)
    for px in range(x0, x0 + w, 6):
        cv.rect(px, y + 3, 2, 2, 5)


def sash(cv: Canvas, rng, x, y, w=16, h=22, lit=None):
    cv.rect(x - 2, y - 2, w + 4, h + 4, 3)          # reveal
    cv.rect(x, y, w, h, 1)                          # glass
    cv.rect(x, y + h // 2, w, 1, 4)                 # meeting rail
    cv.rect(x + w // 2, y, 1, h, 4)
    if lit if lit is not None else rng.random() < 0.25:
        cv.rect(x + 1, y + 1, w // 2 - 1, h // 2 - 1, 3)
    cv.rect(x - 3, y + h + 2, w + 6, 2, 6)          # sill
    cv.rect(x - 3, y + h + 4, w + 6, 1, 3)


def arched(cv: Canvas, rng, x, y, w=10, h=16):
    cv.rect(x - 1, y + 2, w + 2, h - 1, 3)
    cv.rect(x + 1, y, w - 2, 2, 3)
    cv.rect(x, y + 2, w, h - 2, 1)
    cv.rect(x + 1, y + 1, w - 2, 1, 1)
    cv.rect(x, y + h // 2, w, 1, 3)
    if rng.random() < 0.15:
        cv.rect(x + 1, y + 3, 3, h // 2 - 3, 2)
    cv.rect(x - 2, y + h, w + 4, 1, 6)


def door(cv: Canvas, x, w=14, h=30, fan=True):
    y = BASE - h
    cv.rect(x - 2, y - (6 if fan else 2), w + 4, h + (6 if fan else 2), 3)
    if fan:
        cv.rect(x, y - 4, w, 3, 1)
        for k in range(2, w, 3):
            cv.px(x + k, y - 3, 3)
    cv.rect(x, y, w, h, 2)
    cv.rect(x + 2, y + 3, w - 4, 10, 1)
    cv.rect(x + 2, y + 16, w - 4, h - 19, 1)
    cv.px(x + w - 3, y + h // 2, 5)
    cv.rect(x - 3, BASE - 2, w + 6, 2, 5)            # step


def shutter(cv: Canvas, x, w, h):
    y = BASE - h
    cv.rect(x - 2, y - 4, w + 4, h + 4, 2)
    cv.rect(x, y - 2, w, 2, 1)
    for yy in range(y, BASE, 3):
        cv.rect(x, yy, w, 2, 4)
        cv.rect(x, yy + 2, w, 1, 3)


def sign(cv: Canvas, x, y, w, h, lines: list[str], dark=False, bold=True):
    """A painted board with one or more lines of text, centred."""
    bg, fg, rim = (1, 6, 0) if dark else (6, 1, 2)
    cv.rect(x - 1, y - 1, w + 2, h + 2, rim)
    cv.rect(x, y, w, h, bg)
    n = len(lines)
    lh = 9
    y0 = y + (h - n * lh) // 2 + 2
    for i, s in enumerate(lines):
        cv.text(x + w // 2, y0 + i * lh, s, fg, bold=bold and i == 0, center=True)


def ghost_text(cv: Canvas, x, y, s, c=5):
    """Faded lettering painted on a wall."""
    cv.text(x, y, s, c, bold=True)


# ---------------------------------------------------------------- pieces
# Each piece draws one building front in [x0, x0 + w) and returns nothing. "top" is its roof line.
def p_terrace(cv, rng, x0, w, o):
    top = o.get("top", 44 + rng.randrange(14))
    wall(cv, rng, x0, w, top, o.get("material", "brick"))
    slate_roof(cv, rng, x0, w, top, chimneys=max(1, w // 70))
    bays = max(1, (w - 16) // 44)
    step = (w - 8) // bays
    for b in range(bays):
        bx = x0 + 4 + b * step
        sash(cv, rng, bx + step // 2 - 8, top + 12)
        if b % 2 == 0:
            door(cv, bx + step // 2 - 7)
        else:
            sash(cv, rng, bx + step // 2 - 9, 100, 18, 24)
    cv.rect(x0, top + 44, w, 2, 6)                   # string course
    cv.rect(x0, top, 1, BASE - top, 3)
    cv.rect(x0 + w - 1, top, 1, BASE - top, 3)


def p_mill(cv, rng, x0, w, o):
    top = o.get("top", 4 + rng.randrange(8))
    wall(cv, rng, x0, w, top, o.get("material", "brick"))
    parapet(cv, x0, w, top)
    cols = max(2, (w - 20) // 18)
    gap = (w - 20) // cols
    rows = list(range(top + 30, 112, 24))
    for y in rows:
        for k in range(cols):
            arched(cv, rng, x0 + 14 + k * gap, y)
        cv.rect(x0, y + 18, w, 1, 6)
    if o.get("name"):
        band_y = top + 10
        cv.rect(x0 + 8, band_y - 2, w - 16, 13, 4)
        tw = ImageFont.truetype(str(FONT_B), 8).getbbox(o["name"])[2]
        ghost_text(cv, x0 + (w - tw) // 2, band_y + 1, o["name"], 6)
    # cart entrance
    ax = x0 + w // 2 - 16
    cv.rect(ax - 3, 98, 38, 42, 3)
    cv.rect(ax, 104, 32, 36, 1)
    cv.rect(ax + 2, 101, 28, 3, 1)
    for k in range(ax + 4, ax + 32, 6):
        cv.rect(k, 106, 1, 34, 2)
    for px in (x0, x0 + w - 6):                        # corner piers
        cv.rect(px, top, 6, BASE - top, 5)
        cv.rect(px, top, 1, BASE - top, 6)


def p_shop(cv, rng, x0, w, o):
    top = o.get("top", 50 + rng.randrange(12))
    wall(cv, rng, x0, w, top, o.get("material", "plaster"))
    slate_roof(cv, rng, x0, w, top, chimneys=1)
    for k in range(max(1, (w - 20) // 40)):
        sash(cv, rng, x0 + 18 + k * 40, top + 10)
    # shopfront
    cv.rect(x0 + 2, 92, w - 4, BASE - 92, 2)
    sign(cv, x0 + 6, 94, w - 12, 11, [o.get("name") or rng.choice(SHOP_NAMES)], dark=True)
    # awning stripes
    for k in range(0, w - 8, 8):
        cv.rect(x0 + 4 + k, 107, 4, 6, 5)
        cv.rect(x0 + 8 + k, 107, 4, 6, 3)
    cv.rect(x0 + 4, 113, w - 8, 1, 2)
    for k in range(0, w - 8, 4):
        cv.px(x0 + 5 + k, 114, 3)
    # window display and door
    cv.rect(x0 + 6, 116, w - 30, 22, 1)
    for k in range(x0 + 8, x0 + w - 28, 7):
        cv.rect(k, 130 - rng.randrange(8), 4, 8 + rng.randrange(4), 3)
    cv.rect(x0 + 6, 134, w - 30, 4, 4)
    door(cv, x0 + w - 20, 12, 26, fan=False)


def p_pub(cv, rng, x0, w, o):
    top = o.get("top", 38 + rng.randrange(10))
    wall(cv, rng, x0, w, top, o.get("material", "brick"))
    slate_roof(cv, rng, x0, w, top, chimneys=2)
    for k in range(max(1, (w - 20) // 36)):
        sash(cv, rng, x0 + 16 + k * 36, top + 12)
    cv.rect(x0, 88, w, BASE - 88, 1)                   # dark glazed tiles
    for y in range(90, BASE, 6):
        cv.rect(x0, y, w, 1, 2)
    sign(cv, x0 + 4, 90, w - 8, 12, [o.get("name", "THE MILL TAVERN")], dark=True)
    for k in range(x0 + 8, x0 + w - 30, 26):            # frosted windows
        cv.rect(k, 108, 20, 24, 3)
        cv.rect(k + 1, 109, 18, 2, 5)
        cv.rect(k + 9, 108, 1, 24, 2)
    door(cv, x0 + w - 22, 14, 30, fan=False)
    bx = x0 + w - 6                                     # hanging sign
    cv.rect(bx, 72, 14, 2, 1)
    cv.rect(bx + 2, 74, 10, 14, 1)
    cv.rect(bx + 3, 75, 8, 12, 4)
    cv.rect(bx + 5, 78, 4, 6, 2)


def p_warehouse(cv, rng, x0, w, o):
    top = o.get("top", 26 + rng.randrange(18))
    wall(cv, rng, x0, w, top, o.get("material", "stone"))
    parapet(cv, x0, w, top)
    cx = x0 + w // 2 - 11
    cv.rect(cx + 9, top - 10, 4, 12, 2)                 # hoist beam
    cv.rect(cx + 4, top - 10, 22, 3, 1)
    cv.rect(cx + 24, top - 7, 1, 20, 1)
    for y in range(top + 10, 96, 26):                   # loading doors
        cv.rect(cx - 2, y - 2, 26, 22, 3)
        cv.rect(cx, y, 22, 20, 2)
        cv.rect(cx + 10, y, 2, 20, 1)
        for yy in range(y + 3, y + 20, 5):
            cv.rect(cx, yy, 22, 1, 1)
    for k in range(x0 + 12, x0 + w - 12, 30):
        if abs(k - cx) > 28:
            for y in range(top + 12, 90, 26):
                sash(cv, rng, k, y, 12, 16, lit=False)
    shutter(cv, x0 + 14, min(56, w // 3), 40)
    if o.get("name"):
        sign(cv, x0 + w - 12 - min(110, w // 2), 100, min(110, w // 2), 12, [o["name"]])


def p_shed(cv, rng, x0, w, o):
    top = o.get("top", 50 + rng.randrange(10))
    wall(cv, rng, x0, w, top, "corrugated")
    cv.rect(x0 - 2, top - 6, w + 4, 6, 2)               # low pitched roof edge
    cv.rect(x0 - 2, top - 6, w + 4, 1, 4)
    sx = x0 + 10
    sw = w - 20
    cv.rect(sx, 84, sw, BASE - 84, 2)                   # sliding door, half open
    cv.rect(sx, 84, sw // 2, BASE - 84, 1)
    for k in range(sx + sw // 2, sx + sw, 6):
        cv.rect(k, 84, 1, BASE - 84, 3)
    cv.rect(sx - 2, 82, sw + 4, 2, 1)
    if o.get("name"):
        sign(cv, x0 + 10, top + 8, w - 20, 12, [o["name"]])


def p_billboard(cv, rng, x0, w, o):
    wall_top = 96
    wall(cv, rng, x0, w, wall_top, "brick")
    cv.rect(x0, wall_top - 3, w, 3, 6)
    cv.rect(x0, wall_top, w, 1, 3)
    lines = o.get("text", ["MILL ST."])
    bw, bh = min(w - 20, 120), 12 + 9 * len(lines)
    bx, by = x0 + (w - bw) // 2, wall_top - bh - 12
    for px in (bx + 8, bx + bw - 10):
        cv.rect(px, by + bh, 2, BASE - by - bh, 2)
    sign(cv, bx, by, bw, bh, lines)
    for k in range(x0 + 6, x0 + w - 10, 34):            # posters and graffiti on the wall
        if rng.random() < 0.5:
            cv.rect(k, 104 + rng.randrange(10), 10, 13, 6)
            cv.rect(k + 2, 107 + rng.randrange(8), 6, 1, 3)
        elif rng.random() < 0.5:
            y = 112 + rng.randrange(14)
            for s in range(8 + rng.randrange(10)):
                cv.px(k + s, y + int(2 * ((s // 3) % 2)), 2)


def p_alley(cv, rng, x0, w, o):
    top = o.get("top", 72)
    cv.rect(x0, top, w, BASE - top, 2)                  # back wall in shadow
    for y in range(top + 4, BASE, 8):
        cv.rect(x0, y, w, 1, 1)
    cv.rect(x0, top, w, 2, 3)
    cv.rect(x0, BASE - 14, w, 14, 1)
    bx = x0 + w // 2 - 7                                 # bin
    cv.rect(bx, BASE - 16, 14, 16, 3)
    cv.rect(bx - 1, BASE - 18, 16, 3, 4)
    cv.rect(bx + 3, BASE - 12, 1, 10, 2)
    cv.rect(bx + 9, BASE - 12, 1, 10, 2)


def p_grand(cv, rng, x0, w, o):
    top = o.get("top", 2 + rng.randrange(8))
    wall(cv, rng, x0, w, top, "stone")
    cornice(cv, x0, w, top)
    cv.rect(x0 + w // 2 - 20, top - 10, 40, 10, 5)       # pediment block
    cv.rect(x0 + w // 2 - 20, top - 10, 40, 1, 6)
    if o.get("name"):
        cv.rect(x0 + 10, top + 10, w - 20, 13, 3)
        cv.text(x0 + w // 2, top + 13, o["name"], 6, bold=True, center=True)
    cols = max(3, w // 34)
    gap = w // cols
    for k in range(cols):
        cxp = x0 + k * gap + gap // 2
        arched(cv, rng, cxp - 6, top + 32, 12, 22)
        arched(cv, rng, cxp - 6, top + 66, 12, 18)
    for k in range(cols + 1):                            # columns
        px = x0 + k * gap - 3
        if x0 <= px < x0 + w - 5:
            cv.rect(px, top + 28, 6, BASE - top - 28, 5)
            cv.rect(px, top + 28, 1, BASE - top - 28, 6)
            cv.rect(px - 1, top + 28, 8, 2, 6)
    cornice(cv, x0, w, 94)
    door(cv, x0 + w // 2 - 12, 24, 34)


def p_market_hall(cv, rng, x0, w, o):
    top = o.get("top", 16)
    spring = 70                                          # where the glazed arch meets the brick front
    wall(cv, rng, x0, w, spring, "brick")
    cx, r, hgt = x0 + w // 2, w // 2 - 4, spring - top
    for y in range(top, spring):
        k = (spring - y) / hgt
        half = int(r * max(0.0, 1 - k * k) ** 0.5)
        if half <= 0:
            continue
        cv.rect(cx - half, y, half * 2, 1, 5)            # glass
        cv.rect(cx - half, y, 2, 1, 2)                   # iron rim
        cv.rect(cx + half - 2, y, 2, 1, 2)
        if (y - top) % 10 == 0:
            cv.rect(cx - half, y, half * 2, 1, 3)        # glazing bars
        for g in range(-r + 12, r, 12):
            if abs(g) < half - 2:
                cv.px(cx + g, y, 3)
    cv.rect(x0, spring - 2, w, 3, 2)
    if o.get("name"):
        sign(cv, cx - 50, 74, 100, 12, [o["name"]])
    for k in range(x0 + 10, x0 + w - 30, 34):            # open stall arches
        cv.rect(k, 96, 26, BASE - 96, 1)
        cv.rect(k + 2, 93, 22, 3, 1)
        cv.rect(k + 2, 120, 22, 6, 4)
        for g in range(k + 3, k + 24, 5):
            cv.rect(g, 116 + rng.randrange(3), 3, 4, 3)


SHOP_NAMES = ["GROCER", "BUTCHER", "PAWNBROKER", "CHIPPY", "BOOKMAKER", "NEWSAGENT", "HARDWARE", "BARBER",
              "CAFE", "TAILOR", "BAKER", "LAUNDERETTE"]

PIECES = {"terrace": p_terrace, "mill": p_mill, "shop": p_shop, "pub": p_pub, "warehouse": p_warehouse,
          "shed": p_shed, "billboard": p_billboard, "alley": p_alley, "grand": p_grand, "market_hall": p_market_hall}
WIDTHS = {"terrace": (120, 180), "mill": (220, 300), "shop": (110, 160), "pub": (140, 180), "warehouse": (180, 260),
          "shed": (150, 220), "billboard": (180, 240), "alley": (40, 64), "grand": (230, 290), "market_hall": (260, 320)}


# ---------------------------------------------------------------- street (pavement, kerbs, road, furniture)
def street(cv: Canvas, rng, world):
    c = cv
    c.rect(0, BASE, world, 36, 5)                       # back pavement
    c.rect(0, BASE, world, 1, 3)
    c.rect(0, BASE + 1, world, 2, 4)
    for px in range(0, world, 32):
        c.rect(px, BASE + 3, 1, 33, 4)
    c.rect(0, 158, world, 1, 4)
    c.rect(0, 159, world, 1, 6)
    c.rect(0, 176, world, 2, 6)                         # kerb
    c.rect(0, 178, world, 3, 4)
    c.rect(0, 181, world, 1, 2)
    px = 90 + rng.randrange(60)
    while px < world:                                   # drains
        c.rect(px, 177, 28, 5, 1)
        for k in range(2, 28, 4):
            c.rect(px + k, 178, 2, 3, 3)
        px += 260 + rng.randrange(220)
    c.rect(0, 182, world, 68, 4)                        # front slabs
    rows = [182, 204, 228, 250]
    for r in range(3):
        y0, y1, off = rows[r], rows[r + 1], (r * 23) % 48
        for px in range(-off, world, 48):
            if rng.random() < 0.35:
                c.rect(px + 1, y0 + 2, 46, y1 - y0 - 2, 5 if rng.random() < 0.5 else 3)
            c.rect(px, y0, 1, y1 - y0, 3)
            c.rect(px + 1, y0 + 1, 1, y1 - y0 - 1, 5)
        c.rect(0, y0, world, 1, 3)
        c.rect(0, y0 + 1, world, 1, 5)
    c.rect(0, 250, world, 2, 6)                         # front kerb + road
    c.rect(0, 252, world, 4, 3)
    c.rect(0, 256, world, H - 256, 2)
    for px in range(0, world, 60):
        c.rect(px, 264, 28, 2, 4)


def lamp(cv, x):
    cv.rect(x, 64, 2, 98, 1)
    cv.rect(x - 1, 156, 4, 6, 1)
    cv.rect(x - 1, 66, 4, 2, 1)
    cv.rect(x - 4, 56, 10, 9, 1)
    cv.rect(x - 3, 58, 8, 5, 6)
    cv.rect(x - 2, 54, 6, 2, 1)


def bollard(cv, x):
    cv.rect(x, 150, 5, 12, 1)
    cv.rect(x, 150, 5, 2, 3)


def postbox(cv, x):
    cv.rect(x, 136, 10, 26, 1)
    cv.rect(x - 1, 134, 12, 3, 2)
    cv.rect(x + 2, 141, 6, 1, 4)


def drum(cv, x):
    cv.rect(x, 144, 14, 18, 3)
    cv.rect(x, 144, 14, 2, 4)
    cv.rect(x, 150, 14, 1, 2)
    cv.rect(x, 156, 14, 1, 2)
    cv.rect(x + 2, 146, 1, 16, 4)


def bags(cv, x):
    for k, (bx, by) in enumerate([(0, 6), (9, 7), (4, 0)]):
        cv.rect(x + bx, 148 + by, 10, 9, 1)
        cv.rect(x + bx + 1, 148 + by, 8, 2, 2)
        cv.rect(x + bx + 4, 147 + by, 2, 2, 1)


FURNITURE = {"lamp": lamp, "bollard": bollard, "postbox": postbox, "drum": drum, "bags": bags}


# ---------------------------------------------------------------- parallax layers
def layer_sky(pal, rng, spec) -> Image.Image:
    cv = Canvas(TILE, H, pal, wrap=True)
    cv.rect(0, 0, TILE, H, 5)
    for y in range(40, 120):                            # dithered fade to the light horizon
        p = (y - 40) / 80
        for x in range(TILE):
            if ((x + y) % 4 == 0 and p > 0.25) or ((x * 3 + y) % 7 == 0 and p > 0.55) or (p > 0.85 and (x + y) % 2 == 0):
                cv.d.point((x, y), fill=pal[6])
    cv.rect(0, 120, TILE, H - 120, 6)
    kind = spec.get("detail", "clouds")
    if kind in ("clouds", "smog"):
        for _ in range(spec.get("count", 7 if kind == "clouds" else 4)):
            cx, cy = rng.randrange(TILE), rng.randrange(14, 90)
            cw = rng.randrange(50, 130) if kind == "clouds" else rng.randrange(200, 380)
            ch = rng.randrange(6, 12) if kind == "clouds" else 3
            for k in range(3 if kind == "clouds" else 1):
                ox, ow = rng.randrange(cw // 3), cw - rng.randrange(cw // 2)
                cv.rect(cx + ox, cy - k * 4, ow, ch, 6)
            cv.rect(cx, cy + ch - 1, cw, 2, 4 if kind == "clouds" else 5)
    if kind == "stars":
        for _ in range(60):
            cv.px(rng.randrange(TILE), rng.randrange(4, 80), 6)
    return cv.im


def chimney(cv, rng, x, top, smoke=True):
    cv.rect(x, top, 8, BASE - top, 3)
    cv.rect(x - 1, top, 10, 3, 2)
    for k in range(top + 8, BASE, 12):
        cv.rect(x, k, 8, 1, 2)
    if smoke:
        sx, sy = x, top - 6
        for k in range(5):
            cv.rect(sx - k * 3, sy - k * 5, 10 + k * 3, 4, 4)
            sx += 2


def layer_far(pal, rng, spec) -> Image.Image:
    """Distant skyline: low contrast against the sky."""
    cv = Canvas(TILE, H, pal, wrap=True)
    theme = spec.get("theme", "mills")
    x = 0
    while x < TILE:
        w = rng.randrange(60, 150)
        top = rng.randrange(70, 104)
        cv.rect(x, top, w, BASE - top, 4)
        if theme == "mills":
            for t in range(x, x + w - 12, 14):          # sawtooth roofs
                for k in range(8):
                    cv.rect(t + k, top - 8 + k, 14 - k, 1, 4)
            if rng.random() < 0.6:
                chimney(cv, rng, x + rng.randrange(max(1, w - 10)), top - 50 - rng.randrange(20))
        elif theme == "docks":
            if rng.random() < 0.5:                       # crane
                cx = x + rng.randrange(max(1, w - 20))
                cv.rect(cx, top - 60, 4, 60, 3)
                cv.rect(cx - 30, top - 62, 70, 3, 3)
                cv.rect(cx + 36, top - 59, 1, 30, 3)
                cv.rect(cx + 33, top - 30, 7, 5, 3)
            for k in range(x + 4, x + w - 4, 10):
                cv.rect(k, top + 6, 5, 4, 3)
        else:                                            # town: roofs, a spire or clock tower
            for k in range(0, w, 10):
                cv.rect(x + k, top - 6 + (k // 10 % 2) * 3, 8, 6, 4)
            if rng.random() < 0.35:
                sx = x + w // 2
                for k in range(30):
                    cv.rect(sx - k // 4, top - 64 + k, (k // 4) * 2 + 2, 1, 3)
                cv.rect(sx - 8, top - 34, 18, 34, 3)
        for k in range(x + 6, x + w - 6, 9):            # window specks
            if rng.random() < 0.4:
                cv.rect(k, top + 14 + rng.randrange(20), 3, 2, 3)
        x += w + rng.randrange(0, 30)
    return cv.im


def layer_near(pal, rng, spec) -> Image.Image:
    """Nearer rooftops and chimney stacks, darker than the far skyline."""
    cv = Canvas(TILE, H, pal, wrap=True)
    x = 0
    while x < TILE:
        w = rng.randrange(80, 170)
        top = rng.randrange(36, 66)
        cv.rect(x, top, w, BASE - top, 3)
        for y in range(top + 2, top + 10, 3):
            cv.rect(x, y, w, 1, 2)
        cv.rect(x, top, w, 1, 4)
        for i in range(rng.randrange(1, 4)):
            cx = x + rng.randrange(max(1, w - 12))
            ch = rng.randrange(8, 18)
            cv.rect(cx, top - ch, 10, ch, 2)
            cv.rect(cx, top - ch, 10, 2, 3)
            for p in range(rng.randrange(1, 4)):
                cv.rect(cx + 1 + p * 3, top - ch - 3, 2, 3, 1)
        if spec.get("theme") == "docks" and rng.random() < 0.4:   # ship masts
            mx = x + rng.randrange(w)
            cv.rect(mx, top - 50, 2, 50, 2)
            cv.rect(mx - 12, top - 40, 26, 1, 2)
        x += w + rng.randrange(10, 60)
    return cv.im


# ---------------------------------------------------------------- level
def plan_facade(spec, rng, world) -> list[tuple[str, int, int, dict]]:
    """Landmarks stay where the spec puts them; the gaps are filled with pieces from "fill"."""
    marks = sorted(spec.get("landmarks", []), key=lambda m: m["x"])
    fill = spec.get("fill", {"terrace": 3, "shop": 1, "alley": 1})
    names, weights = list(fill), list(fill.values())
    out, x = [], 0

    def fill_to(end):
        nonlocal x
        while end - x >= 40:
            prev = out[-1][0] if out else None
            for _ in range(12):
                name = rng.choices(names, weights)[0]
                lo, hi = WIDTHS[name]
                if lo <= end - x and (name != prev or len(names) == 1):
                    break
            else:
                name, lo, hi = "alley", 40, 64
            w = rng.randrange(lo, hi + 1)
            if end - x - w < 40:                          # stretch to close the gap
                w = end - x
            out.append((name, x, w, {}))
            x += w
        if end > x and out:                               # a sliver: widen the previous piece
            n, px, pw, o = out[-1]
            out[-1] = (n, px, pw + end - x, o)
            x = end

    for m in marks:
        lo, hi = WIDTHS[m["piece"]]
        w = m.get("width", (lo + hi) // 2)
        start = max(x, m["x"])
        fill_to(start)
        out.append((m["piece"], x, w, m))
        x += w
    fill_to(world)
    return out


def build(spec_path: Path) -> dict:
    spec = json.loads(spec_path.read_text())
    lid = spec["id"]
    art = spec.get("art", lid)
    world = int(spec["world"])
    pal = [hexrgb(h) for h in spec["palette"]]
    seed = int(spec.get("seed", 1))
    out_dir = ROOT / "assets/levels" / art
    out_dir.mkdir(parents=True, exist_ok=True)

    main = Canvas(world, H, pal)
    rng = random.Random(seed)
    plan = plan_facade(spec.get("facade", {}), rng, world)
    for name, x0, w, o in plan:
        PIECES[name](main, random.Random(seed * 7919 + x0), x0, w, o)
    street(main, random.Random(seed + 1), world)
    frng = random.Random(seed + 2)
    furn = spec.get("furniture", {"lamp": 2, "bollard": 2, "postbox": 1, "drum": 1, "bags": 1})
    signs = [(x0, x0 + w) for n, x0, w, _ in plan if n == "billboard"]   # keep lamp posts off the signs
    px = 60 + frng.randrange(60)
    while px < world - 30:
        kind = frng.choices(list(furn), list(furn.values()))[0]
        if kind == "lamp" and any(a - 8 < px < b + 8 for a, b in signs):
            kind = "bollard"
        FURNITURE[kind](main, px)
        px += 110 + frng.randrange(150)
    main.im.save(out_dir / "background.png")

    layers = []
    sky_spec, far_spec = spec.get("sky", {}), spec.get("skyline", {})
    makers = {"sky": (layer_sky, sky_spec), "far": (layer_far, far_spec), "near": (layer_near, far_spec)}
    for order, (key, (fn, sub)) in enumerate(makers.items()):
        im = fn(pal, random.Random(seed * 31 + order), sub)
        im.save(out_dir / f"{key}.png")
        layers.append({"layer_id": key, "asset_ref": f"res://assets/levels/{art}/{key}.png", "order": order,
                       "width": TILE, "height": H, "parallax": float(spec.get("parallax", {}).get(key, LAYERS[key])),
                       "offset_x": 0, "offset_y": 0, "repeat_x": True, "repeat_y": False})
    layers.append({"layer_id": "street", "asset_ref": f"res://assets/levels/{art}/background.png", "order": len(layers),
                   "width": world, "height": H, "parallax": 1.0, "offset_x": 0, "offset_y": 0,
                   "repeat_x": False, "repeat_y": False})

    srng = random.Random(seed + 3)
    signposts, fx = [], 340
    while fx < world * 1.25 + 480:
        signposts.append(fx)
        fx += 480 + srng.randrange(260)
    layout = {"format": "parallax-background-v2", "world": world, "canvas": {"width": 480, "height": H},
              "layers": layers, "facade": [{"piece": n, "x": x0, "width": w} for n, x0, w, _ in plan],
              "signposts": signposts}
    (out_dir / "layout.json").write_text(json.dumps(layout, indent=1) + "\n")
    print(f"[{lid}] {world}px street, {len(plan)} building fronts: " + " ".join(n for n, *_ in plan))
    return layout


def main(argv: list[str]) -> int:
    specs = sorted((ROOT / "art/levels").glob("*/level.json"))
    if argv:
        specs = [s for s in specs if s.parent.name in argv]
    if not specs:
        print("no level specs found (art/levels/<id>/level.json)", file=sys.stderr)
        return 1
    for s in specs:
        build(s)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
