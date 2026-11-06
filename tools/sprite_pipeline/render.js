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
  jab:       { state: 'attack', atk: 'jab' },
  cross:     { state: 'attack', atk: 'cross' },
  hook:      { state: 'attack', atk: 'hook' },
  lowkick:   { state: 'attack', atk: 'lowkick' },
  kick:      { state: 'attack', atk: 'kick' },
  punch:     { state: 'attack', atk: 'thugJab' },
  windup:    { state: 'windup', frames: 1, tpf: 1, loop: true, fields: () => ({ t: 0, type: 'thug' }) },
  jump:      { state: 'jump', frames: 1, tpf: 1, loop: true, fields: () => ({ jk: false }) },
  jpunch:    { state: 'jump', frames: 1, tpf: 1, loop: true, fields: () => ({ jk: true, atk: 'jpunch' }) },
  jkick:     { state: 'jump', frames: 1, tpf: 1, loop: true, fields: () => ({ jk: true, atk: 'jkick' }) },
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
    r.list.forEach((f, col) => {
      const e = fakeUnit(def, f);
      renderSprite(e);
      postProcess(def.palette.outline, false);
      sx.drawImage(SB, AX - ax, AY - ay, cw, ch, col * cw, row * ch, cw, ch);
    });
    const m = { row, frames: r.list.length, ticks_per_frame: r.tpf, loop: r.loop };
    if (r.active) m.active_frames = r.active;
    meta.anims[def.anims[row]] = m;
  });
  return { png: sheet.toDataURL('image/png'), meta };
}

function buildPortrait(def) {
  const [c, x] = mk(20, 20), p = def.palette;
  x.fillStyle = '#1e1c28'; x.beginPath(); x.arc(10, 10, 8, 0, 6.283); x.fill();
  x.fillStyle = p.shade; x.beginPath(); x.arc(10, 10, 7, 0, 6.283); x.fill();
  x.fillStyle = p.main; x.beginPath(); x.arc(11, 9, 6, 0, 6.283); x.fill();
  if (p.visor) { x.fillStyle = p.visor; x.fillRect(11, 7, 7, 4); }
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

window.Pipeline = { buildSheet, buildPortrait, buildBackground, buildSignpost };
