"""Move library: side-view poses for the canonical skeleton (pure data, no Blender needed).

A move is a function of t (0..1 through the animation) that returns a pose for rig.set_pose():
    {bone: angle}  or  {"hips": [angle, x, z]}
Angles are degrees, counter-clockwise as seen with the character facing right (see rig.py).
  - an arm hanging down at +90 points straight forward; the forearm angle is relative to the upper arm
  - a positive spine/chest angle leans back, a negative one leans forward
  - a negative shin angle bends the knee
The renderer keeps the lowest point of the body on the floor, so poses don't need to place the feet.

One-shot moves are written as key poses and eased between; loops are written as functions.
Add a move: write a function or a KEYS entry, then use its name as "move" in the character spec.
"""
from __future__ import annotations

import math

GUARD = {
    "hips": [0, 0, -0.03], "spine": -5, "chest": -6, "neck": 4, "head": 5,
    "thigh.L": 20, "shin.L": -16, "foot.L": 4, "thigh.R": -14, "shin.R": -12, "foot.R": 14,
    "upper_arm.L": 58, "forearm.L": 82, "hand.L": -10,
    "upper_arm.R": 38, "forearm.R": 108, "hand.R": -10,
}


def _mix(a: dict, b: dict, k: float) -> dict:
    out = {}
    for bone in set(a) | set(b):
        va, vb = a.get(bone, 0), b.get(bone, 0)
        la = list(va) + [0, 0] if isinstance(va, list) else [va, 0, 0]
        lb = list(vb) + [0, 0] if isinstance(vb, list) else [vb, 0, 0]
        out[bone] = [la[i] + (lb[i] - la[i]) * k for i in range(3)]
    return out


def _over(base: dict, **changes) -> dict:
    """base pose with some bones changed (bone names use __ for '.': upper_arm__R)."""
    p = dict(base)
    for k, v in changes.items():
        p[k.replace("__", ".")] = v
    return p


def _keys(keys: list[tuple[float, dict]], t: float) -> dict:
    """Eased interpolation through (time, pose) keys."""
    if t <= keys[0][0]:
        return _mix(keys[0][1], keys[0][1], 0)
    for (t0, p0), (t1, p1) in zip(keys, keys[1:]):
        if t <= t1:
            k = (t - t0) / max(1e-6, t1 - t0)
            return _mix(p0, p1, k * k * (3 - 2 * k))
    return _mix(keys[-1][1], keys[-1][1], 0)


# ------------------------------------------------------------------ loops
def idle(t):
    s = math.sin(t * 2 * math.pi)
    return _over(GUARD, hips=[0, 0, -0.03 - 0.012 * (s + 1)], chest=-6 - 2 * s, head=5 + s,
                 upper_arm__L=58 + 2 * s, upper_arm__R=38 + 2 * s, forearm__R=108 - 3 * s)


def walk(t):
    s, c = math.sin(t * 2 * math.pi), math.cos(t * 2 * math.pi)
    return _over(GUARD, hips=[0, 0, -0.02 + 0.02 * abs(c)], spine=-6, chest=-7 + 2 * s,
                 thigh__L=24 * s, shin__L=-10 - 30 * max(0.0, -c) - 6, foot__L=6 * c,
                 thigh__R=-24 * s, shin__R=-10 - 30 * max(0.0, c) - 6, foot__R=-6 * c,
                 upper_arm__L=56 - 8 * s, upper_arm__R=36 + 8 * s)


def run(t):
    s, c = math.sin(t * 2 * math.pi), math.cos(t * 2 * math.pi)
    return {"hips": [0, 0, 0.03 * abs(s)], "spine": -14, "chest": -8, "neck": 10, "head": 8,
            "thigh.L": 42 * s + 8, "shin.L": -25 - 55 * max(0.0, -c), "foot.L": 10,
            "thigh.R": -42 * s + 8, "shin.R": -25 - 55 * max(0.0, c), "foot.R": 10,
            "upper_arm.L": -35 * s + 20, "forearm.L": 95, "upper_arm.R": 35 * s + 20, "forearm.R": 95}


def lurk(t):
    s = math.sin(t * 2 * math.pi)
    return {"hips": [0, 0, -0.01 * (s + 1)], "spine": -8, "chest": -10 - 2 * s, "neck": 14, "head": 6 + 2 * s,
            "thigh.L": 10, "shin.L": -8, "thigh.R": -8, "shin.R": -6, "foot.R": 8,
            "upper_arm.L": 14 + 3 * s, "forearm.L": 30, "upper_arm.R": 8 - 3 * s, "forearm.R": 26}


def grabbed(t):
    s = math.sin(t * 2 * math.pi)
    return {"hips": [0, 0, -0.02], "spine": 10 + 4 * s, "chest": 8 - 4 * s, "head": 16 + 6 * s,
            "thigh.L": 12 + 8 * s, "shin.L": -14, "thigh.R": -10 - 8 * s, "shin.R": -10,
            "upper_arm.L": 120 + 20 * s, "forearm.L": 40, "upper_arm.R": 100 - 20 * s, "forearm.R": 50}


def down(t):
    s = math.sin(t * 2 * math.pi)
    return {"hips": [92, -0.15, 0], "spine": -2, "chest": -4 + 2 * s, "neck": -6, "head": -8,
            "thigh.L": 30, "shin.L": -40, "thigh.R": 12, "shin.R": -20,
            "upper_arm.L": 150, "forearm.L": 20, "upper_arm.R": 125, "forearm.R": 30}


LOOPS = {"idle": idle, "walk": walk, "run": run, "lurk": lurk, "grabbed": grabbed, "down": down}

# ------------------------------------------------------------------ one-shots (key poses)
PUNCH_WIND = _over(GUARD, chest=6, spine=0, upper_arm__R=12, forearm__R=125, upper_arm__L=70, forearm__L=70)
PUNCH_HIT = _over(GUARD, hips=[0, 0.1, -0.05], spine=-12, chest=-18, neck=12, head=6,
                  upper_arm__R=118, forearm__R=-4, hand__R=-4, upper_arm__L=25, forearm__L=110,
                  thigh__L=28, shin__L=-24, thigh__R=-22, shin__R=-6)
SWING_WIND = _over(GUARD, chest=12, spine=6, head=0, upper_arm__R=175, forearm__R=40, hand__R=10,
                   upper_arm__L=40, forearm__L=60)
SWING_HIT = _over(GUARD, hips=[0, 0.06, -0.05], spine=-14, chest=-20, neck=12,
                  upper_arm__R=55, forearm__R=-5, hand__R=-30, upper_arm__L=20, forearm__L=70,
                  thigh__L=30, shin__L=-28, thigh__R=-24, shin__R=-6)
HURT = {"hips": [-4, -0.05, -0.02], "spine": 12, "chest": 14, "neck": 10, "head": 22,
        "thigh.L": 16, "shin.L": -12, "thigh.R": -16, "shin.R": -8,
        "upper_arm.L": 30, "forearm.L": 50, "upper_arm.R": 18, "forearm.R": 40}
DEFEND = _over(GUARD, hips=[0, -0.02, -0.06], chest=-10, head=-4, upper_arm__L=78, forearm__L=100,
               upper_arm__R=70, forearm__R=112, thigh__L=24, shin__L=-24, thigh__R=-16, shin__R=-18)
FALLING = {"hips": [50, -0.12, 0.1], "spine": 6, "chest": 8, "head": 20, "thigh.L": 30, "shin.L": -30,
           "thigh.R": 10, "shin.R": -20, "upper_arm.L": 150, "forearm.L": 30, "upper_arm.R": 120, "forearm.R": 40}
LYING = down(0.0)
SIT = {"hips": [80, -0.1, 0], "spine": -40, "chest": -20, "head": -10, "thigh.L": 70, "shin.L": -110,
       "thigh.R": 20, "shin.R": -40, "upper_arm.L": -20, "forearm.L": 10, "upper_arm.R": -30, "forearm.R": 20}
KNEEL = {"hips": [0, 0, -0.3], "spine": -20, "chest": -10, "thigh.L": 85, "shin.L": -90,
         "thigh.R": -30, "shin.R": -100, "upper_arm.L": 30, "forearm.L": 40, "upper_arm.R": 10, "forearm.R": 30}
CROUCH = {"hips": [0, 0, -0.3], "spine": -45, "chest": -20, "neck": 20, "thigh.L": 80, "shin.L": -110,
          "thigh.R": 50, "shin.R": -110, "upper_arm.R": 40, "forearm.R": 10, "upper_arm.L": 20, "forearm.L": 30}

KEYS = {
    "punch": [(0.0, GUARD), (0.2, PUNCH_WIND), (0.4, PUNCH_HIT), (0.6, PUNCH_HIT), (1.0, GUARD)],
    "windup": [(0.0, GUARD), (1.0, PUNCH_WIND)],
    "swing": [(0.0, SWING_WIND), (0.35, SWING_HIT), (0.6, SWING_HIT), (1.0, GUARD)],
    "windup_armed": [(0.0, GUARD), (1.0, SWING_WIND)],
    "hurt": [(0.0, GUARD), (0.3, HURT), (1.0, _mix(HURT, GUARD, 0.5))],
    "defend": [(0.0, DEFEND), (1.0, DEFEND)],
    "knockdown": [(0.0, HURT), (0.35, FALLING), (0.75, LYING), (1.0, LYING)],
    "getup": [(0.0, LYING), (0.35, SIT), (0.7, KNEEL), (1.0, GUARD)],
    "pickup": [(0.0, GUARD), (0.5, CROUCH), (1.0, CROUCH)],
}


def pose(move: str, t: float) -> dict:
    if move in LOOPS:
        return LOOPS[move](t)
    if move in KEYS:
        return _keys(KEYS[move], t)
    raise SystemExit(f"unknown move '{move}' (have: {', '.join(sorted(LOOPS) + sorted(KEYS))})")
