// ============================================================================
// art.js — THE ART ASYNC BOUNDARY.
//
// All creature visuals come from generateCreatureArt(creature), which returns
// a Promise. Today it resolves to procedurally-drawn SVG markup derived
// deterministically from the creature's own data (elements, archetype, rarity,
// seed). No network, no external assets.
//
// SWAPPING IN A REAL IMAGE API LATER (e.g. xAI Grok Imagine):
//   - Keep the signature: generateCreatureArt(creature) -> Promise<ArtResult>
//     where ArtResult = { kind: 'svg'|'url', svg?: string, url?: string }.
//   - Replace the body with a fetch to YOUR OWN server proxy which holds the
//     key and calls the image API. Return { kind:'url', url } instead.
//   - Callers already render both kinds and show a silhouette until the
//     promise resolves, so no caller changes are needed.
//   // TODO: route through server proxy before wiring a real key.
//   //       NEVER put an API key in this file or anywhere client-side.
// ============================================================================

import { ELEMENTS } from './config.js';
import { mulberry32 } from './rng.js';

const artCache = new Map(); // seed+rarity -> resolved ArtResult (art is deterministic, cache freely)

/**
 * Async art boundary. Resolves with { kind:'svg', svg } for the stub.
 * Deliberately async (microtask + tiny delay) so callers are forced to handle
 * the pending state — exactly what a real image API will need.
 */
export function generateCreatureArt(creature) {
  const key = `${creature.seed}|${creature.rarity}|${creature.elements.join(',')}|${creature.archetype}`;
  if (artCache.has(key)) return Promise.resolve(artCache.get(key));
  return new Promise(resolve => {
    // Small artificial latency keeps the async path honest in the UI.
    setTimeout(() => {
      const result = { kind: 'svg', svg: drawCreatureSVG(creature) };
      artCache.set(key, result);
      resolve(result);
    }, 60);
  });
}

/** Placeholder shown while art is pending (or if it never resolves). */
export function silhouetteSVG() {
  return `<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
    <ellipse cx="50" cy="62" rx="26" ry="22" fill="#2a2f3a"/>
    <circle cx="50" cy="34" r="15" fill="#2a2f3a"/>
    <text x="50" y="58" text-anchor="middle" font-size="10" fill="#555c69">?</text>
  </svg>`;
}

// ---------------------------------------------------------------------------
// Procedural drawing. Everything below is the stub implementation and can be
// deleted wholesale when a real image API replaces it.
// ---------------------------------------------------------------------------

function drawCreatureSVG(c) {
  const rng = mulberry32(c.seed ^ 0xa47);
  const cols = c.elements.map(e => ELEMENTS[e]?.color || '#888');
  const darks = c.elements.map(e => ELEMENTS[e]?.dark || '#333');
  const primary = cols[0], secondary = cols[1] || darks[0], tertiary = cols[2] || primary;
  const gid = `g${c.seed.toString(36)}`;
  const jitter = (base, amt) => base + (rng() - 0.5) * amt;

  const parts = [];
  // Multi-element gradient body fill.
  parts.push(`<defs><linearGradient id="${gid}" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="${primary}"/>
    <stop offset="60%" stop-color="${secondary}"/>
    <stop offset="100%" stop-color="${tertiary}"/>
  </linearGradient></defs>`);

  // Rarity aura ring behind the body.
  const auraOpacity = { common: 0, uncommon: 0.12, rare: 0.2, epic: 0.3, legendary: 0.42, mythic: 0.55 }[c.rarity] ?? 0;
  if (auraOpacity > 0) {
    parts.push(`<circle cx="50" cy="52" r="${jitter(40, 4).toFixed(1)}" fill="${primary}" opacity="${auraOpacity}"/>`);
  }

  parts.push(bodyFor(c.archetype, rng, gid, primary, secondary));

  // Coat pattern — spots or stripes, seed-chosen, clipped near the body mass.
  const patternRoll = rng();
  const clipId = `cl${c.seed.toString(36)}`;
  if (patternRoll < 0.55) {
    parts.push(`<clipPath id="${clipId}"><ellipse cx="50" cy="55" rx="28" ry="26"/></clipPath>`);
    const patCol = tertiary === primary ? darks[0] : tertiary;
    if (patternRoll < 0.28) {
      // Spots
      let spots = '';
      const n = 3 + Math.floor(rng() * 4);
      for (let i = 0; i < n; i++) {
        spots += `<circle cx="${(30 + rng() * 40).toFixed(1)}" cy="${(40 + rng() * 30).toFixed(1)}" r="${(2 + rng() * 3).toFixed(1)}" fill="${patCol}" opacity="0.5"/>`;
      }
      parts.push(`<g clip-path="url(#${clipId})">${spots}</g>`);
    } else {
      // Stripes
      let stripes = '';
      const n = 2 + Math.floor(rng() * 3);
      for (let i = 0; i < n; i++) {
        const x = 34 + i * (30 / n) + rng() * 4;
        stripes += `<rect x="${x.toFixed(1)}" y="30" width="3.5" height="50" fill="${patCol}" opacity="0.4" transform="rotate(${jitter(12, 18).toFixed(0)} ${x.toFixed(1)} 55)"/>`;
      }
      parts.push(`<g clip-path="url(#${clipId})">${stripes}</g>`);
    }
  }

  // Legendary+ get orbiting sparkles on top of the aura.
  if (c.rarity === 'legendary' || c.rarity === 'mythic') {
    const n = c.rarity === 'mythic' ? 6 : 4;
    for (let i = 0; i < n; i++) {
      const ang = (i / n) * Math.PI * 2 + rng();
      const sx = 50 + Math.cos(ang) * 42, sy = 52 + Math.sin(ang) * 40;
      parts.push(`<path d="M${sx.toFixed(1)} ${(sy - 2.4).toFixed(1)} l1.4 2.4 -1.4 2.4 -1.4 -2.4 Z" fill="${primary}" opacity="0.9"/>`);
    }
  }

  // Eyes — count varies by seed (1..3), glow color from last element.
  const eyeCol = darks[darks.length - 1];
  const eyes = 1 + Math.floor(rng() * 3);
  for (let i = 0; i < eyes; i++) {
    const ex = 44 + i * 7 - (eyes - 1) * 3 + jitter(0, 3);
    const ey = jitter(36, 5);
    parts.push(`<circle cx="${ex.toFixed(1)}" cy="${ey.toFixed(1)}" r="3.2" fill="#fff"/>
      <circle cx="${ex.toFixed(1)}" cy="${ey.toFixed(1)}" r="1.6" fill="${eyeCol}"/>`);
  }

  // Element markings — one small motif per element beyond the first.
  for (let i = 1; i < c.elements.length; i++) {
    const mx = jitter(35 + i * 18, 6), my = jitter(66, 8);
    parts.push(`<circle cx="${mx.toFixed(1)}" cy="${my.toFixed(1)}" r="${jitter(4, 2).toFixed(1)}" fill="${cols[i]}" opacity="0.85"/>`);
  }

  // Tier notches along the bottom — quick visual read of fusion depth.
  for (let i = 0; i < Math.min(c.tier, 12); i++) {
    parts.push(`<rect x="${20 + i * 5.2}" y="95" width="3.4" height="3.4" rx="1" fill="${primary}" opacity="0.8"/>`);
  }

  return `<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg>`;
}

/** Body silhouette per archetype — simple geometry, distinct at a glance. */
function bodyFor(arch, rng, gid, primary, secondary) {
  const j = (b, a) => (b + (rng() - 0.5) * a).toFixed(1);
  const fill = `url(#${gid})`;
  switch (arch) {
    case 'Drake': return `
      <path d="M50 ${j(20,4)} L${j(72,6)} ${j(45,4)} L${j(66,4)} 78 L${j(34,4)} 78 L${j(28,6)} ${j(45,4)} Z" fill="${fill}"/>
      <path d="M28 45 L${j(12,6)} ${j(30,8)} L30 55 Z" fill="${secondary}"/>
      <path d="M72 45 L${j(88,6)} ${j(30,8)} L70 55 Z" fill="${secondary}"/>`;
    case 'Wisp': return `
      <circle cx="50" cy="${j(45,6)}" r="${j(24,5)}" fill="${fill}" opacity="0.9"/>
      <path d="M40 65 Q${j(50,10)} ${j(88,8)} 60 65 Z" fill="${fill}" opacity="0.6"/>`;
    case 'Golem': return `
      <rect x="${j(28,4)}" y="${j(30,4)}" width="44" height="46" rx="8" fill="${fill}"/>
      <rect x="${j(20,4)}" y="${j(44,6)}" width="12" height="26" rx="5" fill="${secondary}"/>
      <rect x="${j(68,4)}" y="${j(44,6)}" width="12" height="26" rx="5" fill="${secondary}"/>`;
    case 'Serpent': return `
      <path d="M20 80 Q${j(30,10)} ${j(40,12)} 50 55 Q${j(70,10)} ${j(38,10)} 72 ${j(28,6)} Q80 ${j(20,6)} 84 30 Q76 40 62 60 Q45 82 20 80 Z" fill="${fill}"/>
      <circle cx="${j(76,4)}" cy="${j(30,4)}" r="9" fill="${fill}"/>`;
    case 'Sprite': return `
      <ellipse cx="50" cy="${j(52,4)}" rx="${j(16,4)}" ry="${j(24,4)}" fill="${fill}"/>
      <ellipse cx="${j(32,4)}" cy="${j(42,6)}" rx="12" ry="6" fill="${secondary}" opacity="0.8" transform="rotate(-25 32 42)"/>
      <ellipse cx="${j(68,4)}" cy="${j(42,6)}" rx="12" ry="6" fill="${secondary}" opacity="0.8" transform="rotate(25 68 42)"/>`;
    case 'Fang': return `
      <ellipse cx="50" cy="${j(58,4)}" rx="${j(28,4)}" ry="${j(20,4)}" fill="${fill}"/>
      <path d="M${j(30,4)} 42 L${j(36,4)} ${j(22,6)} L44 42 Z" fill="${secondary}"/>
      <path d="M${j(70,4)} 42 L${j(64,4)} ${j(22,6)} L56 42 Z" fill="${secondary}"/>`;
    case 'Moth': return `
      <ellipse cx="50" cy="55" rx="8" ry="${j(22,4)}" fill="${secondary}"/>
      <ellipse cx="${j(32,4)}" cy="${j(48,6)}" rx="${j(17,4)}" ry="${j(23,5)}" fill="${fill}" opacity="0.9"/>
      <ellipse cx="${j(68,4)}" cy="${j(48,6)}" rx="${j(17,4)}" ry="${j(23,5)}" fill="${fill}" opacity="0.9"/>`;
    case 'Kraken': {
      let tent = '';
      for (let t = 0; t < 5; t++) {
        tent += `<path d="M${32 + t * 9} 62 Q${j(30 + t * 9, 14)} ${j(88, 8)} ${36 + t * 9} 92" stroke="${fill}" stroke-width="6" fill="none" stroke-linecap="round"/>`;
      }
      return `<ellipse cx="50" cy="${j(42,4)}" rx="${j(24,4)}" ry="${j(20,4)}" fill="${fill}"/>${tent}`;
    }
    case 'Stag': return `
      <ellipse cx="50" cy="${j(60,4)}" rx="${j(22,4)}" ry="${j(18,4)}" fill="${fill}"/>
      <circle cx="50" cy="${j(36,3)}" r="11" fill="${fill}"/>
      <path d="M42 28 L${j(32,6)} ${j(10,6)} M40 26 L${j(26,6)} ${j(20,6)}" stroke="${secondary}" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path d="M58 28 L${j(68,6)} ${j(10,6)} M60 26 L${j(74,6)} ${j(20,6)}" stroke="${secondary}" stroke-width="3" fill="none" stroke-linecap="round"/>`;
    case 'Imp': default: return `
      <ellipse cx="50" cy="${j(56,4)}" rx="${j(18,4)}" ry="${j(20,4)}" fill="${fill}"/>
      <path d="M38 40 L${j(34,4)} ${j(24,6)} L46 38 Z" fill="${secondary}"/>
      <path d="M62 40 L${j(66,4)} ${j(24,6)} L54 38 Z" fill="${secondary}"/>
      <path d="M62 70 Q${j(84,8)} ${j(72,10)} ${j(80,6)} ${j(52,8)}" stroke="${secondary}" stroke-width="4" fill="none" stroke-linecap="round"/>`;
  }
}
