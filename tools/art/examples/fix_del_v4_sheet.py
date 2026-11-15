"""Corrects the Del v4 preview sheet: drops ghosted frames, rescales oversized floor poses,
re-cuts the heavy punch whose glove crossed the cell edge, removes the background and stray bits.
Writes one transparent strip per animation (160x128 cells, feet on y=116) plus a preview sheet."""
import sys, zipfile
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np
from scipy import ndimage

# usage: python3 tools/art/examples/fix_del_v4_sheet.py art/characters/del/raw/v4_original_sheet.png <out folder>
SRC, OUT = Path(sys.argv[1]), Path(sys.argv[2])
CW, CH, PITCH, TOP, FEET = 160, 128, 148, 20, 116
ROWS = ["idle", "walk", "run", "punch_1", "punch_2", "punch_3", "heavy_punch", "jump", "hurt", "knockdown", "getup", "down"]
src = np.array(Image.open(SRC).convert("RGB")).astype(int)
BG = np.array([29, 31, 40])

def cut(row, col, extra_right=0, mask_left=0):
    """One frame as RGBA with the flat background made transparent."""
    r = ROWS.index(row)
    y0, x0 = TOP + PITCH * r, col * CW
    a = src[y0:y0 + CH, x0:x0 + CW + extra_right]
    alpha = (np.abs(a - BG).sum(axis=2) > 3)
    if mask_left:
        alpha[:, :mask_left] = False
    # keep the figure, drop specks (stray glove bits, shadow blobs)
    lab, n = ndimage.label(alpha, structure=np.ones((3, 3)))
    if n:
        sizes = ndimage.sum(alpha, lab, range(1, n + 1))
        keep = [i + 1 for i, s in enumerate(sizes) if s >= max(80, 0.04 * sizes.max())]
        alpha = np.isin(lab, keep)
    rgba = np.dstack([a, np.where(alpha, 255, 0)]).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")

def scaled(img, factor):
    """Shrink an oversized frame so the body matches the standing frames."""
    b = img.getbbox()
    fig = img.crop(b)
    w, h = max(1, round(fig.width / factor)), max(1, round(fig.height / factor))
    pm = np.array(fig).astype(float)
    pm[..., :3] *= pm[..., 3:4] / 255.0                       # premultiply so edges don't pick up background
    small = np.array(Image.fromarray(pm.astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)).astype(float)
    al = small[..., 3:4]
    rgb = np.where(al > 0, small[..., :3] * 255.0 / np.maximum(al, 1), 0)
    out = np.dstack([np.clip(rgb, 0, 255), np.where(al >= 128, 255, 0)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")

def place(fig, cx=None, lift=0):
    """Put a figure in a cell: feet on the ground line (or lifted), centred or at its original x."""
    b = fig.getbbox()
    f = fig.crop(b)
    cell = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    x = (CW - f.width) // 2 if cx is None else cx
    x = max(0, min(CW - f.width, x))
    cell.alpha_composite(f, (x, FEET - lift - f.height))
    return cell

def std(row, col, **kw):
    """A frame that is already the right size: keep its x position, put its feet on the line."""
    img = cut(row, col, **kw)
    b = img.getbbox()
    lift = max(0, (CH - b[3]) - 12) if row == "jump" else 0     # keep the height of airborne frames
    if img.width > CW:                                          # re-cut frame wider than a cell: centre it
        return place(img)
    return place(img, cx=b[0], lift=lift)

def floor(row, col, factor):
    return place(scaled(cut(row, col), factor))

heavy = [std("heavy_punch", 2), std("heavy_punch", 3), std("heavy_punch", 4, extra_right=14), std("heavy_punch", 5, mask_left=14)]
ANIMS = {
    "idle": [std("idle", c) for c in range(5)],
    "walk": [std("walk", c) for c in range(5)],
    "run": [std("run", c) for c in range(5)],
    "punch_1": [std("punch_1", c) for c in range(5)],
    "punch_2": [std("punch_2", c) for c in range(5)],
    "punch_3": heavy,                                            # the finisher: the heavy punch (the old punch_3 barely moved)
    "punch_3_light": [std("punch_3", c) for c in range(5)],     # the old punch_3, kept in case it's wanted
    "jump": [std("jump", 0), std("jump", 3), std("jump", 4), std("jump", 5)],
    "hurt": [std("hurt", 3), std("hurt", 4), std("hurt", 5)],
    "knockdown": [std("hurt", 3), floor("knockdown", 2, 1.68), floor("knockdown", 3, 1.23), floor("knockdown", 4, 1.9), floor("knockdown", 5, 1.78)],
    "getup": [floor("getup", 0, 1.79), floor("getup", 1, 1.99), floor("getup", 2, 1.72), floor("getup", 3, 1.51), floor("getup", 4, 1.29), floor("getup", 5, 1.16)],
    "down": [floor("down", 0, 1.78)],
}
OUT.mkdir(parents=True, exist_ok=True)
for name, frames in ANIMS.items():
    strip = Image.new("RGBA", (CW * len(frames), CH), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.alpha_composite(f, (i * CW, 0))
    strip.save(OUT / f"{name}.png")
# preview sheet in the original layout
cols = max(len(f) for f in ANIMS.values())
prev = Image.new("RGBA", (CW * cols, PITCH * len(ANIMS)), tuple(BG) + (255,))
d = ImageDraw.Draw(prev)
for r, (name, frames) in enumerate(ANIMS.items()):
    d.text((5, PITCH * r + 4), name.upper(), fill=(220, 220, 230, 255))
    d.line([(0, PITCH * r + TOP + FEET), (CW * cols, PITCH * r + TOP + FEET)], fill=(45, 48, 62, 255))
    for i, f in enumerate(frames):
        prev.alpha_composite(f, (i * CW, PITCH * r + TOP))
prev.convert("RGB").save(OUT / "_preview.png")
with zipfile.ZipFile(OUT.parent / "del_v4_corrected.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for p in sorted(OUT.glob("*.png")):
        z.write(p, p.name)
for name, frames in ANIMS.items():
    print(name, len(frames), [f.getbbox()[2] - f.getbbox()[0] for f in frames], [f.getbbox()[3] - f.getbbox()[1] for f in frames])
