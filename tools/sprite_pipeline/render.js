// Turns the rig into sprite sheets. Loaded after rig.js in headless Chrome by render.py.
// Each animation maps to rig state(s); frames are sampled at fixed game ticks so Godot
// can play them in lock-step with gameplay timers (60 ticks per second).

const A = (name) => ATK[name];
const loopRun = (n, rate) => (i) => ({ walkT: i * (Math.PI * 2 / n) / rate });

// name -> { state, frames, tpf (ticks per frame), loop, fields(i) }
const ANIMS = {
  idle:      { state: 'idle', frames: 8, tpf: 7, loop: true, fields: (i) => ({ t: i * 52 / 8 }) },
  lurk:      { state: 'lurk', frames: 8, tpf: 13, loop: true, fields: (i) => ({ t: i * 105 / 8 }) },
  run:       { state: 'walk', frames: 8, tpf: 2, loop: true, kind: 'player', fields: loopRun(8, 0.34) },
  walk:      { state: 'approach', frames: 8, tpf: 3, loop: true, fields: loopRun(8, 0.26) },
  // hero combo slots (punch_N / kick_N); atk is the rig's pose for the built-in hero
  punch_1:   { state: 'attack', atk: 'jab' },
  punch_2:   { state: 'attack', atk: 'cross' },
  punch_3:   { state: 'attack', atk: 'hook' },
  kick_1:    { state: 'attack', atk: 'lowkick' },
  kick_2:    { state: 'attack', atk: 'kick' },
  kick:      { state: 'attack', atk: 'kick' },     // the Bookie's attack
  punch:     { state: 'attack', atk: 'thugJab' },
  windup:    { state: 'windup', frames: 1, tpf: 1, loop: true, fields: () => ({ t: 0 }) },
  windup_armed: { state: 'windup', frames: 1, tpf: 1, loop: true, fields: () => ({ t: 0, weapon: { type: 'pipe' }, noDraw: true }) },
  swing:     { state: 'attack', atk: 'pipe' },
  smash:     { state: 'attack', atk: 'bruteSwing' },
  slam:      { state: 'attack', atk: 'bossSlam' },
  toss:      { state: 'attack', atk: 'toss' },
  carry:     { state: 'carry', frames: 8, tpf: 3, loop: true, kind: 'player', fields: (i) => ({ walkT: i * (Math.PI * 2 / 8) / 0.34 }) },
  carry_idle:{ state: 'idle', frames: 1, tpf: 1, loop: true, fields: () => ({ t: 0, carry: {} }) },
  pickup:    { state: 'pickup', frames: 1, tpf: 1, loop: true, fields: () => ({}) },
  jump:      { state: 'jump', frames: 1, tpf: 1, loop: true, fields: () => ({ jk: false }) },
  jump_punch:{ state: 'jump', frames: 1, tpf: 1, loop: true, fields: () => ({ jk: true, atk: 'jpunch' }) },
  jump_kick: { state: 'jump', frames: 1, tpf: 1, loop: true, fields: () => ({ jk: true, atk: 'jkick' }) },
  defend:    { state: 'block', frames: 1, tpf: 1, loop: true, fields: () => ({}) },
  hurt:      { state: 'hurt', frames: 1, tpf: 1, loop: true, fields: () => ({}) },
  knockdown: { state: 'down', frames: 6, tpf: 2, loop: false, fields: (i) => ({ t: i * 2, landed: false, bounced: false }) },
  down:      { state: 'down', frames: 1, tpf: 1, loop: true, fields: () => ({ t: 30, landed: true, bounced: true }) },
  getup:     { state: 'getup', frames: 10, tpf: 2, loop: false, fields: (i) => ({ t: i * 2 }) },
  grab:      { state: 'grab', frames: 1, tpf: 1, loop: true, fields: () => ({ kneeT: 0 }) },
  grab_knee: { state: 'grab', frames: 1, tpf: 1, loop: true, fields: () => ({ kneeT: 10 }) },
  grabbed:   { state: 'grabbed', frames: 1, tpf: 1, loop: true, fields: () => ({}) },
  throw:     { state: 'throw', frames: 1, tpf: 1, loop: true, fields: () => ({ lastCarry: false }) },
};

function fakeUnit(def, extra) {
  return Object.assign({
    kind: def.kind, type: def.type || 'player', face: 1, scale: def.scale, pal: def.palette,
    state: 'idle', t: 0, walkT: 0, atk: null, jk: false, kneeT: 0, landed: true, bounced: true,
    sq: 0, flash: 0, carry: null, lastCarry: false, weapon: null, z: 0,
  }, extra);
}

function framesFor(name) {
  const a = ANIMS[name];
  if (!a) throw new Error('unknown anim ' + name);
  if (a.state === 'attack') {
    const d = A(a.atk), tpf = 2, frames = Math.ceil(d.dur / tpf);
    return { a, tpf, loop: false, list: Array.from({ length: frames }, (_, i) => ({ state: 'attack', atk: a.atk, t: i * tpf })),
             active: [Math.floor(d.a0 / tpf), Math.floor(d.a1 / tpf)] };
  }
  return { a, tpf: a.tpf, loop: a.loop, list: Array.from({ length: a.frames }, (_, i) => Object.assign({ state: a.state }, a.fields(i), a.kind ? { kind: a.kind } : {})) };
}

function buildSheet(def, cell, anchor) {
  const [cw, ch] = cell, [ax, ay] = anchor;
  const rows = def.anims.map(framesFor);
  const cols = Math.max(...rows.map(r => r.list.length));
  const [sheet, sx] = mk(cw * cols, ch * rows.length);
  const meta = { cell, anchor, columns: cols, anims: {} };
  rows.forEach((r, row) => {
    const hands = [], angles = [];
    r.list.forEach((f, col) => {
      const e = fakeUnit(def, f);
      const P = pose(e), k = 1.2 * e.scale;
      hands.push([Math.round(P.fh[0] * k), Math.round(P.fh[1] * k)]);
      angles.push(+weaponAngle(e).toFixed(2));
      renderSprite(e);
      postProcess(def.palette.outline, false);
      sx.drawImage(SB, AX - ax, AY - ay, cw, ch, col * cw, row * ch, cw, ch);
    });
    const m = { row, frames: r.list.length, ticks_per_frame: r.tpf, loop: r.loop, hand: hands, weapon_angle: angles };
    if (r.active) m.active_frames = r.active;
    meta.anims[def.anims[row]] = m;
  });
  return { png: sheet.toDataURL('image/png'), meta };
}

function weaponAngle(e) {
  if (e.state === 'attack' && ATK[e.atk] && ['pipe', 'bat', 'ePipe', 'eBat', 'bruteSwing', 'bossSlam'].includes(e.atk)) {
    const a = ATK[e.atk]; return e.t < a.a0 ? -2.5 : e.t <= a.a1 ? 0.05 : 0.6;
  }
  if (e.state === 'windup') return -2.5;
  if (e.state === 'attack' && e.atk === 'toss') return -2.2;
  if (e.state === 'attack' || e.state === 'jump') return -0.3;
  return -1.1;
}

// ---------- weapon, item and prop sprites ----------
function outline(c, rgb) {
  const x = c.getContext('2d'), img = x.getImageData(0, 0, c.width, c.height), d = img.data, w = c.width, h = c.height;
  const A = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) A[i] = d[i * 4 + 3] > 100 ? 1 : 0;
  for (let y = 1; y < h - 1; y++) for (let xx = 1; xx < w - 1; xx++) {
    const i = y * w + xx, o = i * 4;
    if (A[i]) d[o + 3] = 255;
    else if (A[i - 1] || A[i + 1] || A[i - w] || A[i + w]) { d[o] = rgb[0]; d[o + 1] = rgb[1]; d[o + 2] = rgb[2]; d[o + 3] = 255; }
    else d[o + 3] = 0;
  }
  x.putImageData(img, 0, 0); return c;
}
// Weapons point right with the grip at (6, 6) of a 40x12 image.
function buildWeapon(kind) {
  const [c, x] = mk(40, 12); x.lineCap = 'round'; x.translate(6, 6); x.scale(1.2, 1.2);
  const Lx = (x1, y1, x2, y2, w, col) => { x.strokeStyle = col; x.lineWidth = w; x.beginPath(); x.moveTo(x1, y1); x.lineTo(x2, y2); x.stroke(); };
  if (kind === 'bat') { Lx(0, 0, 8, 0, 2.6, '#5a3616'); Lx(8, 0, 21, 0, 4.6, '#7a4f22'); Lx(8, -0.6, 21, -0.6, 2.4, '#d9a464'); }
  else if (kind === 'pipe') { Lx(0, 0, 19, 0, 3.4, '#4f5763'); Lx(0, -0.6, 19, -0.6, 1.4, '#c9d1da'); x.fillStyle = '#4f5763'; x.beginPath(); x.arc(19, 0, 2, 0, 6.283); x.fill(); }
  else { Lx(0, 0, 9, 0, 2.4, '#3a404a'); Lx(3, -0.4, 9, -0.4, 1.1, '#eef3f8'); Lx(-1, 0, 3, 0, 2.6, '#3a2418'); }
  return outline(c, [30, 28, 40]).toDataURL('image/png');
}
function buildItem(kind) {
  const [c, x] = mk(20, 18), X = 10, Y = 16, O = '#09070f';
  if (kind === 'chips') {
    x.fillStyle = O; x.fillRect(X - 8, Y - 14, 16, 13);
    x.fillStyle = '#ffd34d'; for (let i = 0; i < 6; i++) x.fillRect(X - 6 + i * 2, Y - 13 + (i % 2), 1, 6);
    x.fillStyle = '#ffeaa0'; x.fillRect(X - 4, Y - 13, 1, 2);
    x.fillStyle = '#f1ece2'; x.fillRect(X - 7, Y - 8, 14, 6); x.fillStyle = '#c4382f'; x.fillRect(X - 7, Y - 6, 14, 2);
  } else {
    x.fillStyle = O; x.fillRect(X - 4, Y - 12, 8, 11);
    x.fillStyle = '#c4382f'; x.fillRect(X - 3, Y - 11, 6, 9); x.fillStyle = '#ff7466'; x.fillRect(X - 3, Y - 11, 1, 9);
    x.fillStyle = '#e8e4dc'; x.fillRect(X - 3, Y - 11, 6, 1); x.fillRect(X - 3, Y - 7, 6, 2);
  }
  return c.toDataURL('image/png');
}
// Props: 28x32 images, feet (floor contact) at (14, 30).
function buildProp(kind, damaged, mono) {
  const [cv, x] = mk(28, 32), X = 14, Y = 30, O = '#1e1c28', c = mono;
  if (kind === 'crate') {
    x.fillStyle = O; x.fillRect(X - 12, Y - 21, 24, 21);
    x.fillStyle = '#8a5a2e'; x.fillRect(X - 11, Y - 20, 22, 19);
    x.fillStyle = '#a8743e'; x.fillRect(X - 11, Y - 20, 22, 2);
    x.fillStyle = '#5e3b1c'; x.fillRect(X - 11, Y - 14, 22, 1); x.fillRect(X - 11, Y - 8, 22, 1); x.fillRect(X - 11, Y - 20, 2, 19); x.fillRect(X + 9, Y - 20, 2, 19);
    for (let k = 0; k < 16; k++) x.fillRect(X - 8 + k, Y - 3 - k, 2, 1);
    x.fillStyle = '#c99858'; x.fillRect(X - 9, Y - 19, 1, 1); x.fillRect(X + 7, Y - 19, 1, 1);
    if (damaged) { x.fillStyle = O; x.fillRect(X - 2, Y - 18, 1, 5); x.fillRect(X - 1, Y - 13, 1, 3); x.fillRect(X, Y - 10, 1, 4); x.fillRect(X + 4, Y - 20, 2, 3); }
  } else {
    x.fillStyle = c[1]; x.fillRect(X - 9, Y - 26, 18, 26);
    x.fillStyle = c[4]; x.fillRect(X - 8, Y - 24, 16, 23);
    x.fillStyle = c[6]; x.fillRect(X - 6, Y - 24, 3, 23); x.fillStyle = c[3]; x.fillRect(X + 4, Y - 24, 4, 23);
    x.fillStyle = c[2]; x.fillRect(X - 8, Y - 17, 16, 2); x.fillRect(X - 8, Y - 8, 16, 2);
    x.fillStyle = c[5]; x.fillRect(X - 8, Y - 26, 16, 3); x.fillStyle = c[3]; x.fillRect(X - 5, Y - 25, 10, 1);
    if (damaged) { x.fillStyle = c[2]; x.fillRect(X - 4, Y - 20, 5, 3); x.fillRect(X + 1, Y - 6, 4, 2); x.fillRect(X - 7, Y - 13, 2, 3); }
  }
  return cv.toDataURL('image/png');
}

function buildPortrait(def) {
  const [c, x] = mk(20, 20), p = def.palette;
  x.fillStyle = '#1e1c28'; x.beginPath(); x.arc(10, 10, 8, 0, 6.283); x.fill();
  x.fillStyle = p.shade; x.beginPath(); x.arc(10, 10, 7, 0, 6.283); x.fill();
  x.fillStyle = p.main; x.beginPath(); x.arc(11, 9, 6, 0, 6.283); x.fill();
  if (p.visor) { x.fillStyle = p.visor; x.fillRect(11, 7, 7, 4); }
  if (p.acc === 'hat') { x.fillStyle = '#ffcc1a'; x.beginPath(); x.arc(10, 8, 7, Math.PI, 0); x.fill(); x.fillStyle = '#c89a00'; x.fillRect(3, 7, 16, 2); }
  if (p.acc === 'shades') { x.fillStyle = '#16121a'; x.fillRect(10, 8, 8, 3); }
  if (p.acc === 'chain') { x.fillStyle = '#ffd23a'; x.fillRect(6, 16, 9, 1); }
  x.fillStyle = p.hi; x.fillRect(12, 5, 2, 2);
  return c.toDataURL('image/png');
}

function buildBackground(level) {
  LV = level; lvIdx = level.index || 0; WORLD = level.world;
  const c = buildFacade();
  return { png: c.toDataURL('image/png'), hydrants: HYD, signposts: FG };
}

function buildSignpost(mono) {
  const [cv, x] = mk(80, 56), c = mono, px = 40;
  x.fillStyle = c[0]; x.fillRect(px - 3, 12, 7, 44);
  x.fillStyle = c[2]; x.fillRect(px - 2, 12, 5, 44); x.fillStyle = c[3]; x.fillRect(px - 2, 12, 1, 44);
  const arm = (y, dir) => {
    x.fillStyle = c[0]; x.beginPath(); x.moveTo(px, y - 1); x.lineTo(px + dir * 30, y - 1); x.lineTo(px + dir * 36, y + 4); x.lineTo(px + dir * 30, y + 9); x.lineTo(px, y + 9); x.fill();
    x.fillStyle = c[3]; x.beginPath(); x.moveTo(px, y); x.lineTo(px + dir * 30, y); x.lineTo(px + dir * 34, y + 4); x.lineTo(px + dir * 30, y + 8); x.lineTo(px, y + 8); x.fill();
    x.fillStyle = c[4]; x.fillRect(dir > 0 ? px + 2 : px - 30, y + 1, 28, 1);
  };
  arm(16, -1); arm(28, 1);
  return cv.toDataURL('image/png');
}

window.Pipeline = { buildSheet, buildPortrait, buildBackground, buildSignpost, buildWeapon, buildItem, buildProp };
