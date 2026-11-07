#!/usr/bin/env python3
"""Minimal Retro Diffusion API client for the art pipeline (pay per image).

    export RD_API_KEY=rdpk-...
    python3 tools/art/retrodiffusion.py --prompt "..." --style rd_pro__spritesheet --size 128 128 --out art/characters/<id>/raw/idle
    python3 tools/art/retrodiffusion.py ... --check-cost          # free price check, nothing generated
    python3 tools/art/retrodiffusion.py ... --input-image raw/idle/frame_00.png --style rd_advanced_animation__walking
    python3 tools/art/retrodiffusion.py ... --palette art/palettes/mono_red.png --remove-bg

API: POST https://api.retrodiffusion.ai/v2/inferences (header X-RD-Token), then poll
GET /v2/inferences/tasks/<id>. Field names follow Retro Diffusion's public docs and examples
(github.com/Retro-Diffusion/api-examples). If they change, adjust BODY/RESULT handling below.
Every image the API returns is saved into --out as NN.png, ready for import_character.py.
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.request
from pathlib import Path

API = "https://api.retrodiffusion.ai/v2"


def b64(path: str) -> str:
    return base64.b64encode(Path(path).read_bytes()).decode()


def call(method: str, url: str, key: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"X-RD-Token": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def find_images(obj) -> list[str]:
    """Collect base64 PNGs from whatever shape the response has."""
    found = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            if "base64" in k.lower() or k in ("images", "image", "output"):
                if isinstance(v, str) and len(v) > 200:
                    found.append(v)
                elif isinstance(v, list):
                    found += [x for x in v if isinstance(x, str) and len(x) > 200]
            found += find_images(v) if isinstance(v, (dict, list)) else []
    elif isinstance(obj, list):
        for v in obj:
            found += find_images(v)
    return list(dict.fromkeys(found))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prompt", required=True)
    ap.add_argument("--style", default="rd_pro__spritesheet", help="prompt_style, e.g. rd_pro__spritesheet, rd_advanced_animation__walking, rd_tile__scene_object")
    ap.add_argument("--size", nargs=2, type=int, default=[128, 128], metavar=("W", "H"))
    ap.add_argument("--num", type=int, default=1)
    ap.add_argument("--input-image", help="first frame for advanced animations / image-to-image")
    ap.add_argument("--palette", help="PNG whose colours constrain the output")
    ap.add_argument("--remove-bg", action="store_true")
    ap.add_argument("--seed", type=int)
    ap.add_argument("--check-cost", action="store_true", help="ask for the price only (free)")
    ap.add_argument("--out", required=False, help="folder to save NN.png images into")
    a = ap.parse_args()
    key = os.environ.get("RD_API_KEY")
    if not key:
        print("set RD_API_KEY (create one on the Retro Diffusion devtools page)", file=sys.stderr)
        return 2
    body = {"prompt": a.prompt, "width": a.size[0], "height": a.size[1], "num_images": a.num, "prompt_style": a.style}
    if a.input_image:
        body["input_image"] = b64(a.input_image)
    if a.palette:
        body["input_palette"] = b64(a.palette)
    if a.remove_bg:
        body["remove_bg"] = True
    if a.seed is not None:
        body["seed"] = a.seed
    if a.check_cost:
        body["check_cost"] = True
        print(json.dumps(call("POST", f"{API}/inferences", key, body), indent=1))
        return 0
    if not a.out:
        print("--out is required unless --check-cost", file=sys.stderr)
        return 2
    res = call("POST", f"{API}/inferences", key, body)
    task = res.get("task_id") or res.get("id")
    images = find_images(res)
    t0 = time.time()
    while task and not images:
        time.sleep(3)
        res = call("GET", f"{API}/inferences/tasks/{task}", key)
        status = str(res.get("status", "")).lower()
        images = find_images(res)
        if status in ("failed", "error"):
            print(json.dumps(res, indent=1), file=sys.stderr)
            return 1
        if time.time() - t0 > 600:
            print("timed out waiting for task", task, file=sys.stderr)
            return 1
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    start = len(list(out.glob("*.png")))
    for i, img in enumerate(images):
        data = img.split(",", 1)[1] if img.startswith("data:") else img
        (out / f"{start + i:02d}.png").write_bytes(base64.b64decode(data))
    print(f"saved {len(images)} image(s) to {out}  (cost/balance info: {res.get('remaining_balance', res.get('balance_cost', 'n/a'))})")
    return 0 if images else 1


if __name__ == "__main__":
    sys.exit(main())
