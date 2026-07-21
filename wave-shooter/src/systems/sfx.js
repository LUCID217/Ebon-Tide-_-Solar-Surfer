// Placeholder SFX via WebAudio oscillators — zero assets, swappable later for
// real sounds by keeping this module's function names as the interface.

let ctx = null;
let master = null;

function ensureCtx() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.16;
    master.connect(ctx.destination);
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

// Call once from a pointerdown handler to satisfy autoplay policies.
export function unlockAudio() {
  ensureCtx();
}

function blip(freq, durMs, type = 'square', vol = 1, slide = 0) {
  const c = ensureCtx();
  if (!c) return;
  const t = c.currentTime;
  const osc = c.createOscillator();
  const gain = c.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, t);
  if (slide) osc.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t + durMs / 1000);
  gain.gain.setValueAtTime(vol, t);
  gain.gain.exponentialRampToValueAtTime(0.001, t + durMs / 1000);
  osc.connect(gain).connect(master);
  osc.start(t);
  osc.stop(t + durMs / 1000 + 0.02);
}

function noise(durMs, vol = 0.8) {
  const c = ensureCtx();
  if (!c) return;
  const t = c.currentTime;
  const len = Math.floor(c.sampleRate * durMs / 1000);
  const buf = c.createBuffer(1, len, c.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / len);
  const src = c.createBufferSource();
  src.buffer = buf;
  const gain = c.createGain();
  gain.gain.value = vol;
  src.connect(gain).connect(master);
  src.start(t);
}

export const sfx = {
  shot(freq = 440) { blip(freq, 70, 'square', 0.5, -freq * 0.4); },
  enemyShot() { blip(180, 90, 'sawtooth', 0.4, -60); },
  hit() { blip(220, 60, 'triangle', 0.6, -80); },
  kill() { noise(120, 0.5); blip(160, 120, 'sawtooth', 0.5, -100); },
  explosion() { noise(320, 1.0); blip(70, 300, 'sine', 0.9, -40); },
  playerHurt() { blip(120, 140, 'sawtooth', 0.8, -60); },
  shieldDown() { blip(500, 250, 'sine', 0.7, -420); },
  shieldUp() { blip(300, 180, 'sine', 0.5, 240); },
  dash() { blip(700, 120, 'sine', 0.5, -400); },
  deploy() { blip(240, 140, 'square', 0.5, 120); },
  waveStart() { blip(330, 160, 'square', 0.6, 110); blip(495, 240, 'square', 0.4, 0); },
  gameOver() { blip(220, 500, 'sawtooth', 0.7, -160); },
  unlock() { blip(520, 120, 'square', 0.6, 0); blip(780, 220, 'square', 0.5, 0); },
  click() { blip(600, 40, 'square', 0.35, 0); },
  denied() { blip(140, 160, 'square', 0.5, -40); }
};
