"""Sprite pipeline v0: renders sprite sheets, portraits and level art from the procedural rig.

Usage (from the project root):
    python3 tools/sprite_pipeline/render.py

Reads characters.json and the level palettes in art/levels/*/level.json, writes into assets/:
    assets/characters/<name>/sheet.png + sheet.json + portrait.png
    assets/levels/<name>/signpost.png + crate/barrel sprites (backgrounds: tools/levels/level_kit.py)
Swap any of these PNGs for hand-made or AI-made art with the same cell size and anchor
and the game picks them up unchanged.
"""
import asyncio, base64, json, pathlib
from playwright.async_api import async_playwright

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
FONT = (ROOT / "assets/fonts/Silkscreen-Regular.ttf").as_uri()
FONT_B = (ROOT / "assets/fonts/Silkscreen-Bold.ttf").as_uri()

PAGE = f"""<!doctype html><html><head><style>
@font-face {{ font-family: Silkscreen; src: url('{FONT}'); font-weight: 400; }}
@font-face {{ font-family: Silkscreen; src: url('{FONT_B}'); font-weight: 700; }}
</style></head><body><span style="font-family:Silkscreen">a</span><b style="font-family:Silkscreen">b</b></body></html>"""


def save_png(data_url: str, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(base64.b64decode(data_url.split(",", 1)[1]))


async def main() -> None:
    chars = json.loads((HERE / "characters.json").read_text())
    # Level palettes come from the level specs; the kit (tools/levels/level_kit.py) draws the backgrounds.
    levels = {}
    for spec in sorted((ROOT / "art/levels").glob("*/level.json")):
        d = json.loads(spec.read_text())
        levels[d["art"]] = {"mono": d["palette"], "world": d["world"]}
    async with async_playwright() as p:
        browser = await p.chromium.launch(args=["--allow-file-access-from-files"])
        page = await browser.new_page()
        tmp = HERE / ".page.html"
        tmp.write_text(PAGE)
        await page.goto(tmp.as_uri())
        await page.evaluate("document.fonts.ready")
        await page.evaluate("Promise.all([document.fonts.load('8px Silkscreen'), document.fonts.load('bold 8px Silkscreen'), document.fonts.load('bold 16px Silkscreen')])")
        for f in ("rig.js", "render.js"):
            await page.add_script_tag(path=str(HERE / f))
        for name, d in chars["characters"].items():
            if (ROOT / "art/characters" / name / "character.json").exists():
                print("character", name, "skipped: built from art/characters by tools/art/import_character.py")
                continue
            out = ROOT / "assets/characters" / name
            res = await page.evaluate("([d, c, a]) => Pipeline.buildSheet(d, c, a)", [d, chars["cell"], chars["anchor"]])
            save_png(res["png"], out / "sheet.png")
            (out / "sheet.json").write_text(json.dumps(res["meta"], indent=1))
            if d.get("portrait"):
                save_png(await page.evaluate("(d) => Pipeline.buildPortrait(d)", d), out / "portrait.png")
            print("character", name, len(res["meta"]["anims"]), "anims")
        items = ROOT / "assets/items"
        for w in ("bat", "pipe", "knife"):
            save_png(await page.evaluate("(k) => Pipeline.buildWeapon(k)", w), items / f"{w}.png")
        for it in ("chips", "can"):
            save_png(await page.evaluate("(k) => Pipeline.buildItem(k)", it), items / f"{it}.png")
        print("items")
        for name, lv in levels.items():
            out = ROOT / "assets/levels" / name
            # The background, parallax layers and layout.json come from tools/levels/level_kit.py.
            save_png(await page.evaluate("(m) => Pipeline.buildSignpost(m)", lv["mono"]), out / "signpost.png")
            for prop in ("crate", "barrel"):
                for dmg in (False, True):
                    save_png(await page.evaluate("([k, d, m]) => Pipeline.buildProp(k, d, m)", [prop, dmg, lv["mono"]]), out / f"{prop}{'_damaged' if dmg else ''}.png")
            print("level", name)
        tmp.unlink()
        await browser.close()

asyncio.run(main())
