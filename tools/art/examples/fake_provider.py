"""Makes stand-in "AI output" for testing the importer without an API key.

Renders a character with the procedural rig, then deliberately makes it look like typical generator
output: 3x upscaled, solid green background, jittered position, and a different file format per
animation (frame folder, horizontal strip, GIF, single PNG).

    python3 tools/art/examples/fake_provider.py   ->  art/characters/bouncer/raw/
"""
import asyncio, base64, io, json, random, pathlib
from PIL import Image
from playwright.async_api import async_playwright

ROOT = pathlib.Path(__file__).resolve().parents[3]
PIPE = ROOT / "tools/sprite_pipeline"
OUT = ROOT / "art/characters/bouncer/raw"
DEF = {"kind": "enemy", "type": "brute", "scale": 1.2,
       "palette": {"main": "#7b3fb8", "shade": "#4a1f78", "hi": "#c79cf0", "outline": [30, 8, 46], "acc": "shades"},
       "anims": ["idle", "walk", "smash", "hurt"]}

async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch()
        pg = await b.new_page()
        await pg.set_content("<html><body></body></html>")
        for f in ("rig.js", "render.js"):
            await pg.add_script_tag(path=str(PIPE / f))
        res = await pg.evaluate("([d]) => Pipeline.buildSheet(d, [160, 128], [80, 116])", [DEF])
        await b.close()
    sheet = Image.open(io.BytesIO(base64.b64decode(res["png"].split(",", 1)[1]))).convert("RGBA")
    meta = res["meta"]
    random.seed(3)
    def frames(name):
        a = meta["anims"][name]
        out = []
        for i in range(a["frames"]):
            c = sheet.crop((i * 160, a["row"] * 128, i * 160 + 160, a["row"] * 128 + 128)).resize((480, 384), Image.NEAREST)
            bg = Image.new("RGBA", (520, 420), (0, 255, 0, 255))
            bg.alpha_composite(c, (20 + random.randint(-6, 6), 18 + random.randint(-3, 3)))
            out.append(bg.convert("RGB"))
        return out
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "idle").mkdir(exist_ok=True)
    for i, f in enumerate(frames("idle")):               # 1) folder of frames
        f.save(OUT / "idle" / f"frame_{i:02d}.png")
    w = frames("walk")                                    # 2) horizontal strip
    strip = Image.new("RGB", (520 * len(w), 420)); [strip.paste(f, (i * 520, 0)) for i, f in enumerate(w)]
    strip.save(OUT / "walk_strip.png")
    s = frames("smash")                                   # 3) animated GIF
    s[0].save(OUT / "attack.gif", save_all=True, append_images=s[1:], duration=33, loop=0)
    frames("hurt")[0].save(OUT / "hurt.png")              # 4) single image
    print("fake provider output in", OUT.relative_to(ROOT))

asyncio.run(main())
