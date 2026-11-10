#!/usr/bin/env python3
"""Fails if generated files differ from what is committed (run after regenerating them).

    python3 tools/check_generated.py assets/characters scenes/characters resources/attacks resources/combos assets/levels scenes/levels

PNGs are compared by their decoded pixels, not their bytes: the same pixels can compress to different
bytes on different machines (zlib builds and CPU features differ), which is not a real change.
Every other file is compared byte for byte. New files that git doesn't track yet also count as drift.
"""
import io
import subprocess
import sys

from PIL import Image


def git(*args: str) -> bytes:
    return subprocess.run(["git", *args], check=True, capture_output=True).stdout


def pixels(data: bytes) -> tuple:
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    return im.size, im.tobytes()


def main(paths: list[str]) -> int:
    changed = [p for p in git("diff", "--name-only", "HEAD", "--", *paths).decode().splitlines() if p]
    untracked = [p for p in git("ls-files", "--others", "--exclude-standard", "--", *paths).decode().splitlines()
                 if p and not p.endswith(".import")]
    drift = []
    for path in changed:
        try:
            now = open(path, "rb").read()
        except FileNotFoundError:
            drift.append(f"deleted  {path}")
            continue
        before = git("show", f"HEAD:{path}")
        if path.endswith(".png") and pixels(now) == pixels(before):
            subprocess.run(["git", "checkout", "--", path], check=True)   # same picture: keep the committed bytes
            continue
        drift.append(f"changed  {path}")
    drift += [f"new      {p}" for p in untracked]
    if drift:
        print("Generated files differ from the commit. Regenerate them locally and commit the result:")
        print("\n".join("  " + d for d in drift))
        return 1
    print(f"generated files match the commit ({', '.join(paths)})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["."]))
