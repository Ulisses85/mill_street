// AUTO-EXTRACTED from the browser prototype (mill-street-brawl.html) by tools/sprite_pipeline/extract.py.

// The rig: pose() gives joint positions per state/time; renderSprite() draws a mannequin; postProcess() adds the outline.

const W = 480, H = 270;

const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

const SW = 200, SH = 170, AX = 100, AY = 150;

const SB = document.createElement('canvas'); SB.width = SW; SB.height = SH;

const sctx = SB.getContext('2d', { willReadFrequently: true });

const MASK = new Uint8Array(SW * SH);

const WEAPONS = {};

const ATK = {
  hook:  { dur: 22, a0: 6, a1: 9,  reach: 32, dmg: 9,  kb: 3.5, kd: true },
  lowkick: { dur: 16, a0: 4, a1: 8, reach: 34, dmg: 7, kb: 1.6, kd: false },
  jab:   { dur: 13, a0: 3, a1: 6,  reach: 30, dmg: 5,  kb: 1.2, kd: false },
  cross: { dur: 15, a0: 4, a1: 7,  reach: 32, dmg: 6,  kb: 1.6, kd: false },
  kick:  { dur: 24, a0: 7, a1: 12, reach: 38, dmg: 12, kb: 4,   kd: true },
  jkick: { dur: 1e9, a0: 0, a1: 1e9, reach: 34, dmg: 10, kb: 3.5, kd: true, zr: 34 },
  spin:  { dur: 30, a0: 5, a1: 22, reach: 36, dmg: 10, kb: 4.5, kd: true, both: true },
  pipe:  { dur: 22, a0: 7, a1: 11, reach: 46, dmg: 14, kb: 4, kd: true, weapon: true, swing: true },
  ePipe: { dur: 24, a0: 7, a1: 11, reach: 44, dmg: 11, kb: 4, kd: true, weapon: true, swing: true },
  bat:   { dur: 20, a0: 6, a1: 10, reach: 48, dmg: 13, kb: 4.5, kd: true, weapon: true, swing: true },
  eBat:  { dur: 24, a0: 7, a1: 11, reach: 46, dmg: 11, kb: 4.5, kd: true, weapon: true, swing: true },
  toss:  { dur: 16, a0: 5, a1: 5, reach: 0, dmg: 0, kb: 0, kd: false },
  knifeHit: { dmg: 14, kb: 3, kd: true },
  propHit: { dmg: 16, kb: 4.5, kd: true },
  jpunch: { dur: 1e9, a0: 0, a1: 1e9, reach: 30, dmg: 8, kb: 2.5, kd: true, zr: 34 },
  bookieKick: { dur: 26, a0: 8, a1: 12, reach: 44, dmg: 14, kb: 4.5, kd: true },
  knee:  { dmg: 5, kb: 0, kd: false },
  knee3: { dmg: 8, kb: 3, kd: true },
  throw: { dmg: 14, kb: 4, kd: true },
  body:  { dmg: 10, kb: 3.5, kd: true },
  thugJab:    { dur: 20, a0: 6,  a1: 9,  reach: 28, dmg: 7,  kb: 2, kd: false },
  bruteSwing: { dur: 28, a0: 8,  a1: 12, reach: 40, dmg: 14, kb: 4, kd: true },
  bossSlam:   { dur: 34, a0: 10, a1: 15, reach: 48, dmg: 18, kb: 5, kd: true },
};

const BOARD_SUBS = ['TO LET', 'NO BALL GAMES', 'EST. 1868', 'DEMOLITION SOON', 'NO PARKING', 'BILL STICKERS WILL BE PROSECUTED'];

let LV = null, lvIdx = 0, WORLD = 2620, MONO = null, HYD = [], FG = [];

const hex2rgb = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];

const _dk = new Map();

function dk(h, f = 0.66) { const key = h + f; let v = _dk.get(key); if (!v) { const [r, g, b] = hex2rgb(h); v = `rgb(${r * f | 0},${g * f | 0},${b * f | 0})`; _dk.set(key, v); } return v; }

function mulberry(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

function mk(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; const x = c.getContext('2d'); x.imageSmoothingEnabled = false; return [c, x]; }

function buildFacade() {
  MONO = LV.mono; const c = MONO;
  const [cv2, x] = mk(WORLD, H), R = mulberry(LV.seed);
  HYD = []; FG = [];
  x.fillStyle = c[6]; x.fillRect(0, 0, WORLD, 140);
  let bx = 0, n = 0;
  while (bx < WORLD) { const w = [168, 192, 216, 240][R() * 4 | 0]; drawBlock(x, R, bx, w, n, c); bx += w; n++; }
  // back pavement
  x.fillStyle = c[5]; x.fillRect(0, 140, WORLD, 36);
  x.fillStyle = c[3]; x.fillRect(0, 140, WORLD, 1); x.fillStyle = c[4]; x.fillRect(0, 141, WORLD, 2);
  for (let px = 0; px < WORLD; px += 32) { x.fillStyle = c[4]; x.fillRect(px, 143, 1, 33); }
  x.fillStyle = c[4]; x.fillRect(0, 158, WORLD, 1); x.fillStyle = c[6]; x.fillRect(0, 159, WORLD, 1);
  // kerb
  x.fillStyle = c[6]; x.fillRect(0, 176, WORLD, 2); x.fillStyle = c[4]; x.fillRect(0, 178, WORLD, 3); x.fillStyle = c[2]; x.fillRect(0, 181, WORLD, 1);
  for (let px = 90 + (R() * 60 | 0); px < WORLD; px += 260 + (R() * 220 | 0)) {
    x.fillStyle = c[1]; x.fillRect(px, 177, 28, 5);
    x.fillStyle = c[3]; for (let k = 2; k < 28; k += 4) x.fillRect(px + k, 178, 2, 3);
  }
  // front pavement slabs
  x.fillStyle = c[4]; x.fillRect(0, 182, WORLD, 68);
  const rows = [182, 204, 228, 250];
  for (let r = 0; r < rows.length - 1; r++) {
    const y0 = rows[r], y1 = rows[r + 1], off = (r * 23) % 48;
    for (let px = -off; px < WORLD; px += 48) {
      if (R() < 0.35) { x.fillStyle = R() < 0.5 ? c[5] : c[3]; x.globalAlpha = 0.35; x.fillRect(px + 1, y0 + 2, 46, y1 - y0 - 2); x.globalAlpha = 1; }
      x.fillStyle = c[3]; x.fillRect(px, y0, 1, y1 - y0);
      x.fillStyle = c[5]; x.fillRect(px + 1, y0 + 1, 1, y1 - y0 - 1);
      if (R() < 0.07) { x.fillStyle = c[3]; let cx = px + 8 + R() * 28 | 0, cy = y0 + 4; for (let k = 0; k < 8; k++) { x.fillRect(cx, cy, 1, 1); cx += R() < 0.5 ? 1 : -1; cy++; } }
    }
    x.fillStyle = c[3]; x.fillRect(0, y0, WORLD, 1); x.fillStyle = c[5]; x.fillRect(0, y0 + 1, WORLD, 1);
  }
  // front kerb + road
  x.fillStyle = c[6]; x.fillRect(0, 250, WORLD, 2); x.fillStyle = c[3]; x.fillRect(0, 252, WORLD, 4);
  x.fillStyle = c[2]; x.fillRect(0, 256, WORLD, H - 256);
  for (let px = 0; px < WORLD; px += 60) { x.fillStyle = c[4]; x.fillRect(px, 264, 28, 2); }
  // street furniture against the wall
  for (let px = 120 + (R() * 80 | 0); px < WORLD - 40; px += 150 + (R() * 160 | 0)) {
    const k = R();
    if (k < 0.3) drum(x, px, 160, c);
    else if (k < 0.55) bags(x, px, 158, c);
    else if (k < 0.8) { hydrant(x, px, 162, c); HYD.push({ x: px, y: 148, spray: R() < 0.6 }); }
    else postbox(x, px, 160, c);
  }
  for (let fx = 340; fx < WORLD * 1.25 + W; fx += 480 + (R() * 260 | 0)) FG.push(fx);
  return cv2;
}

function drawBlock(x, R, x0, w, n, c) {
  const kind = ['stone', 'plaster', 'stone', 'panel'][(n + LV.seed) % 4];
  x.save(); x.beginPath(); x.rect(x0, 0, w, 140); x.clip();
  x.fillStyle = c[4]; x.fillRect(x0, 0, w, 140);
  if (kind === 'stone') {
    for (let y = 0, r = 0; y < 140; y += 10, r++)
      for (let px = x0 - (r % 2) * 12; px < x0 + w; px += 24) {
        x.fillStyle = R() < 0.12 ? c[4] : c[5]; x.fillRect(px + 1, y + 1, 22, 8);
        x.fillStyle = c[6]; x.fillRect(px + 1, y + 1, 22, 1);
      }
  } else if (kind === 'plaster') {
    x.fillStyle = c[5]; x.fillRect(x0, 0, w, 140);
    for (let k = 0; k < 10; k++) { x.fillStyle = c[4]; x.fillRect(x0 + R() * w | 0, R() * 130 | 0, 2 + R() * 6 | 0, 1); }
  } else {
    x.fillStyle = c[5]; x.fillRect(x0, 0, w, 140);
    for (let px = x0; px < x0 + w; px += 20) { x.fillStyle = c[4]; x.fillRect(px, 0, 1, 140); x.fillStyle = c[6]; x.fillRect(px + 1, 0, 1, 140); }
  }
  // upper floor: barred windows
  for (let wx = x0 + 18; wx + 24 < x0 + w - 10; wx += 40) window_(x, wx, 14, c, R);
  // ledge
  x.fillStyle = c[6]; x.fillRect(x0, 60, w, 2); x.fillStyle = c[5]; x.fillRect(x0, 62, w, 3); x.fillStyle = c[3]; x.fillRect(x0, 65, w, 1);
  // ground floor feature
  const f = n === 0 ? 2 : [0, 1, 3, 2][(n * 3 + LV.seed) % 4], cx = x0 + 16 + (R() * Math.max(1, w - 130) | 0);
  if (f === 0) garage(x, cx, c, R);
  else if (f === 1) doorway(x, cx + 10, c);
  else if (f === 2) billboard(x, cx, c, n);
  else crumble(x, cx, c, R);
  // extra barred window on ground floor if room
  if (w > 200) window_(x, x0 + w - 44, 84, c, R);
  // pilaster
  x.fillStyle = c[5]; x.fillRect(x0, 0, 8, 140); x.fillStyle = c[6]; x.fillRect(x0, 0, 2, 140); x.fillStyle = c[3]; x.fillRect(x0 + 7, 0, 1, 140);
  x.fillStyle = c[3]; x.fillRect(x0 - 1, 132, 10, 8); x.fillStyle = c[5]; x.fillRect(x0 - 1, 132, 10, 1);
  // downpipe + wall box
  const dp = x0 + w - 14; x.fillStyle = c[3]; x.fillRect(dp, 0, 3, 140); x.fillStyle = c[5]; x.fillRect(dp, 0, 1, 140);
  for (let y = 20; y < 140; y += 30) { x.fillStyle = c[2]; x.fillRect(dp - 1, y, 5, 2); }
  if (f === 3 && R() < 0.6) { const bx = x0 + w - 28; x.fillStyle = c[2]; x.fillRect(bx, 76, 1, 8); x.fillStyle = c[1]; x.fillRect(bx - 5, 84, 11, 14); x.fillStyle = c[3]; x.fillRect(bx - 4, 85, 9, 12); x.fillStyle = c[5]; x.fillRect(bx - 4, 85, 9, 1); x.fillStyle = c[1]; x.fillRect(bx - 1, 89, 3, 3); }
  x.restore();
}

function window_(x, wx, wy, c, R) {
  x.fillStyle = c[2]; x.fillRect(wx - 2, wy - 2, 28, 38);
  x.fillStyle = c[1]; x.fillRect(wx, wy, 24, 34);
  x.fillStyle = c[2]; x.fillRect(wx, wy, 24, 6);
  if (R() < 0.4) { x.fillStyle = c[3]; x.fillRect(wx + 2, wy + 2, 8, 30); }
  x.fillStyle = c[4]; for (let k = 2; k < 24; k += 5) x.fillRect(wx + k, wy, 2, 34);
  x.fillStyle = c[6]; for (let k = 2; k < 24; k += 5) x.fillRect(wx + k, wy, 1, 34);
  x.fillStyle = c[4]; x.fillRect(wx, wy + 16, 24, 2);
  x.fillStyle = c[6]; x.fillRect(wx - 4, wy + 36, 32, 2); x.fillStyle = c[3]; x.fillRect(wx - 4, wy + 38, 32, 2);
}

function garage(x, gx, c, R) {
  const w = 78, y0 = 76, h = 64;
  x.fillStyle = c[3]; x.fillRect(gx - 4, y0 - 6, w + 8, h + 6); x.fillStyle = c[5]; x.fillRect(gx - 4, y0 - 6, w + 8, 2);
  x.fillStyle = c[0]; x.fillRect(gx, y0, w, h);
  const open = 26 + (R() * 10 | 0);
  for (let y = y0; y < y0 + open; y += 4) { x.fillStyle = c[4]; x.fillRect(gx, y, w, 3); x.fillStyle = c[5]; x.fillRect(gx, y, w, 1); }
  x.fillStyle = c[2]; x.fillRect(gx, y0 + open, w, 2);
  // car
  const cy = y0 + h; x.fillStyle = c[3];
  x.fillRect(gx + 6, cy - 16, w - 12, 10); x.fillRect(gx + 16, cy - 24, w - 34, 8);
  x.fillStyle = c[1]; x.fillRect(gx + 19, cy - 22, 14, 6); x.fillRect(gx + 36, cy - 22, 14, 6);
  x.fillStyle = c[5]; x.fillRect(gx + 6, cy - 16, w - 12, 1); x.fillRect(gx + 8, cy - 12, 6, 2); x.fillRect(gx + w - 14, cy - 12, 6, 2);
  x.fillStyle = c[4]; x.fillRect(gx + 26, cy - 10, 20, 3);
  x.fillStyle = c[0]; x.fillRect(gx + 12, cy - 6, 10, 6); x.fillRect(gx + w - 22, cy - 6, 10, 6);
}

function doorway(x, dx, c) {
  const y0 = 84;
  x.fillStyle = c[3]; x.fillRect(dx - 6, y0 - 8, 42, 56); x.fillStyle = c[6]; x.fillRect(dx - 6, y0 - 8, 42, 2);
  x.fillStyle = c[1]; x.fillRect(dx, y0, 30, 48);
  x.fillStyle = c[2]; x.fillRect(dx + 2, y0 + 2, 12, 20); x.fillRect(dx + 16, y0 + 2, 12, 20); x.fillRect(dx + 2, y0 + 25, 12, 20); x.fillRect(dx + 16, y0 + 25, 12, 20);
  x.fillStyle = c[3]; x.fillRect(dx + 3, y0 + 3, 4, 18); x.fillRect(dx + 17, y0 + 3, 4, 18);
  x.fillStyle = c[5]; x.fillRect(dx + 24, y0 + 26, 2, 2);
  for (let s = 0; s < 3; s++) { x.fillStyle = c[5 - (s % 2)]; x.fillRect(dx - 6 - s * 4, 132 + s * 3, 42 + s * 8, 3); x.fillStyle = c[3]; x.fillRect(dx - 6 - s * 4, 134 + s * 3, 42 + s * 8, 1); }
}

function billboard(x, bx, c, n) {
  const w = 104, h = 58, y0 = 72;
  x.fillStyle = c[1]; x.fillRect(bx - 3, y0 - 3, w + 6, h + 6);
  x.fillStyle = c[6]; x.fillRect(bx, y0, w, h);
  x.fillStyle = c[5]; x.fillRect(bx, y0 + h - 6, w, 6);
  x.fillStyle = c[2]; x.fillRect(bx + 10, y0 + h + 3, 3, 8); x.fillRect(bx + w - 13, y0 + h + 3, 3, 8);
  x.textAlign = 'center'; x.textBaseline = 'top'; x.fillStyle = c[1];
  if (lvIdx === 0 && n === 0) {
    x.font = 'bold 16px Silkscreen, monospace'; x.fillText('MILL ST.', bx + w / 2, y0 + 5);
    x.font = '8px Silkscreen, monospace';
    x.fillText('J PUNCH  K KICK', bx + w / 2, y0 + 25); x.fillText('L JUMP  U GRAB', bx + w / 2, y0 + 36);
    x.fillText('I DEFEND', bx + w / 2, y0 + 46);
  } else {
    const g = LV.ghost[n % LV.ghost.length][0];
    x.font = 'bold 8px Silkscreen, monospace'; x.fillText(g, bx + w / 2, y0 + 12);
    x.font = '8px Silkscreen, monospace';
    const sub = BOARD_SUBS[(n + LV.seed) % BOARD_SUBS.length];
    if (sub.length > 16) { const i = sub.lastIndexOf(' ', 16); x.fillText(sub.slice(0, i), bx + w / 2, y0 + 28); x.fillText(sub.slice(i + 1), bx + w / 2, y0 + 38); }
    else x.fillText(sub, bx + w / 2, y0 + 30);
  }
}

function crumble(x, cx, c, R) {
  const pts = [], w = 90, h = 50, y0 = 74;
  for (let k = 0; k < 14; k++) { const a = k / 14 * 6.283, r = 0.75 + R() * 0.3; pts.push([cx + w / 2 + Math.cos(a) * w / 2 * r, y0 + h / 2 + Math.sin(a) * h / 2 * r]); }
  x.save(); x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.closePath();
  x.fillStyle = c[3]; x.fill(); x.clip();
  for (let y = y0, r = 0; y < y0 + h; y += 5, r++) for (let px = cx - (r % 2) * 5; px < cx + w; px += 10) { x.fillStyle = R() < 0.3 ? c[2] : c[4]; x.fillRect(px + 1, y + 1, 8, 3); }
  x.restore();
  x.strokeStyle = c[2]; x.lineWidth = 1; x.beginPath(); x.moveTo(pts[0][0], pts[0][1]); for (const p of pts) x.lineTo(p[0], p[1]); x.closePath(); x.stroke();
  for (let k = 0; k < 5; k++) {
    const px = cx + 6 + R() * (w - 20) | 0, py = y0 + 2 + R() * (h - 16) | 0;
    x.save(); x.translate(px + 6, py + 7); x.rotate((R() - 0.5) * 0.4);
    x.fillStyle = c[2]; x.fillRect(-6, -7, 13, 15); x.fillStyle = c[6]; x.fillRect(-6, -8, 12, 15);
    x.fillStyle = c[4]; x.fillRect(-4, -5, 8, 1); x.fillRect(-4, -3, 6, 1); x.fillRect(-4, 0, 8, 1);
    x.restore();
  }
}

function drum(x, px, y, c) {
  x.fillStyle = c[1]; x.fillRect(px - 9, y - 26, 18, 26);
  x.fillStyle = c[4]; x.fillRect(px - 8, y - 24, 16, 23);
  x.fillStyle = c[6]; x.fillRect(px - 6, y - 24, 3, 23); x.fillStyle = c[3]; x.fillRect(px + 4, y - 24, 4, 23);
  x.fillStyle = c[2]; x.fillRect(px - 8, y - 17, 16, 2); x.fillRect(px - 8, y - 8, 16, 2);
  x.fillStyle = c[5]; x.fillRect(px - 8, y - 26, 16, 3); x.fillStyle = c[3]; x.fillRect(px - 5, y - 25, 10, 1);
}

function bags(x, px, y, c) {
  const blob = (bx, by, r) => { x.fillStyle = c[0]; x.beginPath(); x.arc(bx, by, r + 1, 0, 6.283); x.fill(); x.fillStyle = c[2]; x.beginPath(); x.arc(bx, by, r, 0, 6.283); x.fill(); x.fillStyle = c[3]; x.fillRect(bx - r / 2, by - r / 2, r / 2, 2); };
  blob(px - 5, y - 6, 7); blob(px + 6, y - 5, 6); blob(px, y - 13, 6);
  x.fillStyle = c[1]; x.fillRect(px - 1, y - 21, 3, 3);
}

function hydrant(x, px, y, c) {
  x.fillStyle = c[1]; x.fillRect(px - 6, y - 18, 12, 18); x.fillRect(px - 9, y - 12, 18, 5); x.fillRect(px - 8, y - 2, 16, 3);
  x.fillStyle = c[3]; x.fillRect(px - 5, y - 17, 10, 16); x.fillRect(px - 8, y - 11, 16, 3);
  x.fillStyle = c[5]; x.fillRect(px - 4, y - 17, 2, 16);
  x.fillStyle = c[2]; x.fillRect(px - 4, y - 21, 8, 4);
}

function postbox(x, px, y, c) {
  x.fillStyle = c[1]; x.fillRect(px - 8, y - 32, 16, 32); x.beginPath(); x.arc(px, y - 32, 8, Math.PI, 0); x.fill();
  x.fillStyle = c[3]; x.fillRect(px - 7, y - 31, 14, 30); x.fillStyle = c[5]; x.fillRect(px - 6, y - 31, 2, 30);
  x.fillStyle = c[0]; x.fillRect(px - 5, y - 26, 10, 2); x.fillStyle = c[2]; x.fillRect(px - 8, y - 4, 16, 4);
}

function pose(e) {
  const P = { lean: 0, hip: -18, ff: [5, 0], bf: [-5, 0], fh: [9, -31], bh: [4, -33] };
  const t = e.t;
  switch (e.state) {
    case 'walk': case 'approach': case 'enter': case 'carry': {
      const run = e.kind === 'player' || e.state === 'enter', amp = run ? 1 : 0.62, a = e.walkT * (run ? 0.34 : 0.26);
      const ph = Math.sin(a), up = Math.cos(a);
      P.lean = run ? 3.5 : 1.5; P.hip = -17.5 - Math.abs(ph) * 1.6 * amp;
      P.ff = [9 * ph * amp, -Math.max(0, up) * 5 * amp]; P.bf = [-9 * ph * amp, -Math.max(0, -up) * 5 * amp];
      P.fh = [P.lean + 6 - 9 * ph * amp, -28 - Math.max(0, -ph) * 6 * amp]; P.bh = [P.lean + 1 + 9 * ph * amp, -29 - Math.max(0, ph) * 6 * amp];
      if (e.state === 'carry') { P.lean = 0; P.fh = [4, -52]; P.bh = [-2, -52]; }
      break; }
    case 'idle': {
      const b = Math.sin(t * 0.12);
      P.hip = -16 + b * 0.7; P.lean = 1; P.ff = [8, 0]; P.bf = [-7, 0];
      P.fh = [10, -35 + b * 0.8]; P.bh = [6, -37 + b * 0.8];
      if (e.carry) { P.fh = [4, -52]; P.bh = [-2, -52]; }
      break; }
    case 'attack': {
      const a = ATK[e.atk], act = t >= a.a0 && t <= a.a1, pre = t < a.a0;
      switch (e.atk) {
        case 'hook': P.fh = act ? [19, -40] : pre ? [5, -27] : [14, -37]; P.bh = [2, -34]; P.lean = act ? 5 : 1; P.ff = [8, 0]; break;
        case 'lowkick': P.ff = act ? [26, -9] : pre ? [9, -5] : [12, -3]; P.lean = act ? -2 : 0; P.fh = [9, -35]; P.bh = [5, -37]; P.bf = [-5, 0]; break;
        case 'jab': case 'thugJab': P.fh = act ? [24, -32] : pre ? [11, -31] : [15, -31]; P.lean = act ? 2 : 0; break;
        case 'cross': P.bh = act ? [25, -31] : [9, -31]; P.fh = [6, -33]; P.lean = act ? 4 : 1; P.bf = [-8, 0]; break;
        case 'kick': case 'bookieKick': P.ff = act ? [28, -22] : pre ? [10, -12] : [12, -6]; P.lean = act ? -4 : -1; P.bf = [-2, 0]; P.fh = [4, -34]; P.bh = [-8, -30]; break;
        case 'spin': { const s = Math.floor(t / 3) % 2 ? 1 : -1; P.fh = [22 * s, -31]; P.bh = [-22 * s, -31]; P.ff = [4, -4]; break; }
        case 'toss': P.fh = t < a.a0 ? [-6, -40] : [24, -33]; P.bh = [-4, -30]; P.lean = t < a.a0 ? -3 : 3; break;
        case 'bruteSwing': case 'bossSlam': case 'pipe': case 'ePipe': case 'bat': case 'eBat':
          P.fh = act ? [26, -20] : pre ? [-6, -46] : [18, -12]; P.bh = act ? [22, -24] : [2, -44]; P.lean = act ? 6 : -3; P.ff = [9, 0]; break;
      }
      break; }
    case 'windup':
      P.lean = -3; P.fh = e.type === 'thug' && !e.weapon ? [-9, -34] : [-6, -46]; P.bh = e.type === 'thug' ? [2, -30] : [0, -44]; break;
    case 'jump':
      if (e.jk && e.atk === 'jpunch') { P.fh = [23, -31]; P.bh = [-4, -34]; P.ff = [6, -8]; P.bf = [-6, -4]; P.lean = 3; }
      else if (e.jk) { P.ff = [20, -14]; P.bf = [-4, -7]; P.fh = [2, -34]; P.bh = [-8, -30]; P.lean = -2; }
      else { P.ff = [5, -7]; P.bf = [-5, -5]; P.fh = [8, -34]; P.bh = [-6, -36]; }
      break;
    case 'lurk': { const b = Math.sin(t * 0.06); P.hip = -18 + b * 0.4; P.fh = [5, -20 + b * 0.4]; P.bh = [1, -21 + b * 0.4]; P.ff = [4, 0]; P.bf = [-4, 0]; break; }
    case 'block': P.lean = -2; P.fh = [11, -40]; P.bh = [9, -35]; P.ff = [6, 0]; P.bf = [-7, 0]; P.hip = -17; break;
    case 'hurt': P.lean = -5; P.fh = [-8, -24]; P.bh = [-2, -38]; P.ff = [7, 0]; P.bf = [-6, 0]; break;
    case 'grab':
      P.fh = [13, -30]; P.bh = [11, -33]; P.lean = 2;
      if (e.kneeT > 6) { P.ff = [12, -17]; P.lean = 4; P.bf = [-3, 0]; }
      break;
    case 'grabbed': P.lean = 5; P.fh = [-2, -22]; P.bh = [3, -24]; P.ff = [6, 0]; P.bf = [-7, 0]; break;
    case 'pickup': P.hip = -10; P.lean = 4; P.ff = [8, 0]; P.bf = [-6, 0]; P.fh = [10, -14]; P.bh = [4, -16]; break;
    case 'getup':
      if (t < 10) { P.hip = -7; P.lean = 7; P.ff = [9, 0]; P.bf = [-9, -1]; P.fh = [14, -2]; P.bh = [8, -2]; }
      else { const q = (t - 10) / 10; P.hip = -10 - q * 6; P.lean = 5 - q * 4; P.ff = [8, 0]; P.bf = [-6, 0]; P.fh = [10, -14 - q * 18]; P.bh = [4, -16 - q * 16]; }
      break;
    case 'throw': if (e.kind === 'player' && e.lastCarry && t < 10) { P.fh = [18, -46]; P.bh = [14, -46]; P.lean = 5; P.ff = [9, 0]; P.bf = [-8, 0]; break; }
      P.lean = -5; P.fh = [-6, -45]; P.bh = [-3, -43]; P.ff = [7, 0]; P.bf = [-7, 0]; break;
  }
  return P;
}

function L(x1, y1, x2, y2, w, c) { sctx.strokeStyle = c; sctx.lineWidth = w; sctx.beginPath(); sctx.moveTo(x1, y1); sctx.lineTo(x2, y2); sctx.stroke(); }

function dot(x, y, r, c) { sctx.fillStyle = c; sctx.beginPath(); sctx.arc(x, y, r, 0, 6.283); sctx.fill(); }

function poly(pts, c) { sctx.fillStyle = c; sctx.beginPath(); sctx.moveTo(pts[0][0], pts[0][1]); for (let i = 1; i < pts.length; i++) sctx.lineTo(pts[i][0], pts[i][1]); sctx.closePath(); sctx.fill(); }

function R2(x, y, w, h, c) { sctx.fillStyle = c; sctx.fillRect(x, y, w, h); }

function renderSprite(e) {
  const pal = e.pal, P = pose(e), k = 1.2 * e.scale, m = pal.main, sh = pal.shade;
  sctx.setTransform(1, 0, 0, 1, 0, 0); sctx.clearRect(0, 0, SW, SH);
  const sq = e.sq > 0 ? e.sq * 0.035 : 0;
  sctx.translate(AX + (e.state === 'hurt' && e.t < 5 ? -e.face * 2 : 0), AY); sctx.scale(e.face * k * (1 + sq), k * (1 - sq));
  if (e.state === 'down' || e.state === 'dead') {
    const q = e.landed || e.bounced ? 1 : Math.min(1, e.t / 10), wob = e.bounced && !e.landed ? Math.sin(e.t * 0.6) * 0.15 : 0;
    sctx.translate(6 * q, -3 * q); sctx.rotate(-Math.PI / 2 * q + wob);
  }
  sctx.lineCap = 'round'; sctx.lineJoin = 'round';
  const hip = P.hip, shY = hip - 15, sx = P.lean, hd = [P.lean + 1, hip - 23];
  // far limbs
  L(sx - 1, shY + 1, P.bh[0], P.bh[1], 4.6, sh); dot(P.bh[0], P.bh[1], 2.7, sh);
  L(-1, hip, P.bf[0], P.bf[1], 5.8, sh); R2(P.bf[0] - 2.5, P.bf[1] - 2.8, 7, 3, sh);
  // torso
  poly([[-4.8, hip + 1], [4.8, hip + 1], [sx + 6.2, shY - 0.6], [sx - 5.4, shY - 0.6]], m);
  L(-3.8, hip, sx - 4.4, shY + 1, 2.2, sh);
  dot(0, hip, 4.8, m); dot(-2.4, hip + 1, 2.2, sh);
  dot(sx + 0.5, shY + 1, 3.4, m);
  if (pal.acc === 'chain') { L(sx - 3, shY + 1, sx + 0.5, shY + 6, 1.2, '#ffd23a'); L(sx + 0.5, shY + 6, sx + 4, shY + 1, 1.2, '#ffd23a'); }
  // near leg
  L(1, hip, P.ff[0], P.ff[1], 5.8, m); R2(P.ff[0] - 2.5, P.ff[1] - 2.8, 7.2, 3, m); R2(P.ff[0] - 2.5, P.ff[1] - 0.6, 7.2, 0.9, sh);
  // head
  R2(sx - 0.5, shY - 3.5, 3, 4, sh);
  dot(hd[0] - 0.8, hd[1] + 0.8, 6.4, sh); dot(hd[0] + 0.4, hd[1] - 0.4, 5.8, m);
  if (pal.visor) { R2(hd[0] + 0.5, hd[1] - 2.2, 6.2, 3.2, pal.visor); R2(hd[0] + 2, hd[1] - 2.2, 4, 1, '#8a8aa0'); }
  dot(hd[0] + 2.2, hd[1] - 2.6, 1.7, pal.hi);
  if (pal.acc === 'hat') { sctx.fillStyle = '#ffcc1a'; sctx.beginPath(); sctx.arc(hd[0], hd[1] - 1.8, 6.8, Math.PI, Math.PI * 2); sctx.fill(); R2(hd[0] - 6, hd[1] - 2.4, 15, 2.2, '#c89a00'); }
  if (pal.acc === 'shades') { R2(hd[0] + 1, hd[1] - 1.8, 6, 2.2, '#16121a'); R2(hd[0] + 4.4, hd[1] - 1.6, 1.2, 0.8, '#ffffff'); }
  // weapon + near arm
  if (e.weapon && !e.noDraw && !(e.state === 'attack' && e.atk === 'toss' && e.t >= ATK.toss.a0)) {
    const wt = e.weapon.type, thrown = WEAPONS[wt].thrown;
    let ang = thrown ? -0.25 : -1.1;
    if (e.state === 'attack' && ATK[e.atk].swing) { const a = ATK[e.atk]; ang = e.t < a.a0 ? -2.5 : e.t <= a.a1 ? 0.05 : 0.6; }
    else if (e.state === 'windup') ang = -2.5;
    else if (e.state === 'attack' && e.atk === 'toss') ang = -2.2;
    else if (e.state === 'attack' || e.state === 'jump') ang = -0.3;
    const len = thrown ? 9 : wt === 'bat' ? 21 : 19, cs = Math.cos(ang), sn = Math.sin(ang);
    const x2 = P.fh[0] + cs * len, y2 = P.fh[1] + sn * len;
    if (thrown) { L(P.fh[0], P.fh[1], x2, y2, 2.4, '#3a404a'); L(P.fh[0] + cs * 3, P.fh[1] + sn * 3 - 0.4, x2, y2 - 0.4, 1.1, '#eef3f8'); }
    else if (wt === 'bat') {
      const xm = P.fh[0] + cs * 8, ym = P.fh[1] + sn * 8;
      L(P.fh[0], P.fh[1], xm, ym, 2.6, '#5a3616'); L(xm, ym, x2, y2, 4.6, '#7a4f22'); L(xm, ym - 0.6, x2, y2 - 0.6, 2.4, '#d9a464');
    } else { L(P.fh[0], P.fh[1], x2, y2, 3.4, '#4f5763'); L(P.fh[0], P.fh[1] - 0.6, x2, y2 - 0.6, 1.4, '#c9d1da'); dot(x2, y2, 2, '#4f5763'); }
  }
  L(sx + 1, shY + 1, P.fh[0], P.fh[1], 4.6, m);
  dot(P.fh[0], P.fh[1], 3, m);
}

function postProcess(ol, flash) {
  const img = sctx.getImageData(0, 0, SW, SH), d = img.data, A = MASK, n = SW * SH;
  for (let i = 0, o = 3; i < n; i++, o += 4) A[i] = d[o] > 100 ? 1 : 0;
  for (let y = 1; y < SH - 1; y++) {
    let i = y * SW + 1;
    for (let x = 1; x < SW - 1; x++, i++) {
      const o = i * 4;
      if (A[i]) {
        d[o + 3] = 255;
        if (flash) { d[o] = d[o + 1] = d[o + 2] = 255; }
        else if (!A[i - SW]) { d[o] = Math.min(255, d[o] * 1.1 + 18); d[o + 1] = Math.min(255, d[o + 1] * 1.1 + 18); d[o + 2] = Math.min(255, d[o + 2] * 1.1 + 18); }
      } else if (A[i - 1] || A[i + 1] || A[i - SW] || A[i + SW]) { d[o] = ol[0]; d[o + 1] = ol[1]; d[o + 2] = ol[2]; d[o + 3] = 255; }
      else d[o + 3] = 0;
    }
  }
  sctx.putImageData(img, 0, 0);
}
