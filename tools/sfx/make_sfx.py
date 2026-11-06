"""Generates the template's placeholder sound effects (16-bit mono WAV) with a tiny synth.
Replace any file in assets/sfx/ with your own sound of the same name."""
import math, random, struct, wave, pathlib
SR = 22050
OUT = pathlib.Path(__file__).resolve().parents[2] / "assets/sfx"

def env(n, attack=0.004, decay=None):
    a = int(SR * attack)
    return [min(1.0, i / max(1, a)) * (1 - i / n) ** 2 for i in range(n)]

def tone(f0, f1, dur, wav="square", vol=0.3):
    n = int(SR * dur); e = env(n); ph = 0.0; out = []
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / n); ph += f / SR
        s = (1 if (ph % 1) < 0.5 else -1) if wav == "square" else (2 * abs(2 * (ph % 1) - 1) - 1 if wav == "tri" else 2 * (ph % 1) - 1)
        out.append(s * vol * e[i])
    return out

def noise(dur, vol=0.4, lp=0.3):
    n = int(SR * dur); e = env(n); y = 0.0; out = []
    for i in range(n):
        y += lp * (random.uniform(-1, 1) - y); out.append(y * vol * e[i] * 3)
    return out

def mix(*parts):
    n = max(len(p) for p in parts); return [sum(p[i] for p in parts if i < len(p)) for i in range(n)]

def save(name, data):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32000)) for s in data))

random.seed(7)
save("swish", noise(0.08, 0.25, 0.6))
save("hit", mix(noise(0.08, 0.45, 0.35), tone(190, 70, 0.08, "square", 0.18)))
save("heavy", mix(noise(0.16, 0.6, 0.2), tone(130, 40, 0.18, "saw", 0.25)))
save("hurt", mix(tone(320, 110, 0.14, "square", 0.18), noise(0.08, 0.3, 0.4)))
save("thud", noise(0.14, 0.55, 0.08))
save("jump", tone(260, 520, 0.1, "tri", 0.25))
save("block", mix(tone(1300, 900, 0.06, "square", 0.12), noise(0.05, 0.25, 0.8)))
save("alert", tone(330, 220, 0.18, "square", 0.14))
save("ko", tone(300, 60, 0.4, "square", 0.18))
save("go", tone(660, 880, 0.2, "square", 0.12))
print("sfx written to", OUT)
