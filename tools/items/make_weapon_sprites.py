#!/usr/bin/env python3
"""Draws the extra weapon sprites by code: 40x12, pointing right, grip at (6, 6).

    python3 tools/items/make_weapon_sprites.py      # writes assets/items/<name>.png

(The bat, pipe and knife come from tools/sprite_pipeline.) To add a weapon: draw it here, add a
WeaponData in resources/weapons/, and place it in a level spec's "pickups" or as a crate drop.
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "assets/items"
INK = (30, 28, 40, 255)


def canvas():
    return Image.new("RGBA", (40, 12), (0, 0, 0, 0))


def rect(im, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= xx < im.width and 0 <= yy < im.height:
                im.putpixel((xx, yy), c)


def outline(im):
    """One-pixel dark outline around everything drawn."""
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if im.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and im.getpixel((nx, ny))[3]:
                    out.putpixel((x, y), INK)
                    break
    return out


def machete():
    im = canvas()
    rect(im, 3, 5, 8, 3, (74, 46, 26, 255))          # wooden handle
    rect(im, 4, 5, 6, 1, (120, 78, 44, 255))
    rect(im, 11, 4, 1, 5, (58, 64, 74, 255))         # guard
    rect(im, 12, 3, 20, 4, (174, 184, 196, 255))     # blade
    rect(im, 12, 3, 20, 1, (236, 242, 248, 255))     # edge highlight
    rect(im, 12, 6, 18, 1, (110, 120, 134, 255))
    rect(im, 32, 4, 2, 3, (174, 184, 196, 255))      # tip
    rect(im, 34, 5, 1, 2, (174, 184, 196, 255))
    return outline(im)


def nailbat():
    im = canvas()
    rect(im, 3, 5, 9, 2, (90, 54, 22, 255))           # handle
    rect(im, 12, 4, 21, 4, (122, 79, 34, 255))        # barrel
    rect(im, 12, 4, 21, 1, (217, 164, 100, 255))
    for x in (17, 22, 27, 31):                        # nails, up and down
        rect(im, x, 2, 1, 2, (214, 220, 228, 255))
        rect(im, x + 2, 8, 1, 2, (214, 220, 228, 255))
    return outline(im)


def bottle():
    im = canvas()
    rect(im, 3, 5, 9, 2, (52, 110, 70, 255))          # neck (held by it)
    rect(im, 3, 5, 2, 2, (200, 180, 90, 255))         # cap
    rect(im, 12, 4, 2, 4, (52, 110, 70, 255))         # shoulder
    rect(im, 14, 3, 14, 6, (40, 96, 58, 255))         # body
    rect(im, 14, 3, 14, 1, (130, 200, 150, 255))
    rect(im, 18, 5, 7, 3, (226, 220, 196, 255))       # label
    return outline(im)


def broken_bottle():
    im = canvas()
    rect(im, 3, 5, 9, 2, (52, 110, 70, 255))
    rect(im, 3, 5, 2, 2, (200, 180, 90, 255))
    rect(im, 12, 4, 2, 4, (52, 110, 70, 255))
    rect(im, 14, 3, 5, 6, (40, 96, 58, 255))
    rect(im, 14, 3, 5, 1, (130, 200, 150, 255))
    for x, y, h in ((19, 3, 2), (20, 3, 1), (19, 6, 3), (20, 7, 2), (21, 8, 1), (19, 5, 1), (21, 3, 1), (22, 3, 1)):   # jagged edge
        rect(im, x, y, 1, h, (130, 200, 150, 255))
    return outline(im)


def brick():
    im = canvas()
    rect(im, 3, 3, 14, 7, (158, 62, 44, 255))
    rect(im, 3, 3, 14, 1, (206, 100, 76, 255))
    rect(im, 3, 9, 14, 1, (112, 40, 30, 255))
    for x, y in ((6, 5), (11, 7), (14, 5), (8, 8)):
        rect(im, x, y, 1, 1, (112, 40, 30, 255))
    return outline(im)


if __name__ == "__main__":
    for name, fn in (("machete", machete), ("nailbat", nailbat), ("bottle", bottle), ("broken_bottle", broken_bottle), ("brick", brick)):
        fn().save(OUT / f"{name}.png")
        print("wrote", f"assets/items/{name}.png")
