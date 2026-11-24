// ============================================================================
// art.js — THE ART ASYNC BOUNDARY.
//
// All creature visuals come from generateCreatureArt(creature), which returns
// a Promise. Today it resolves to procedurally-drawn SVG markup derived
// deterministically from the creature's own data (element, type, class,
// rarity, seed), composed in layers: body → element palette → class gear.
// No network, no external assets.
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

const artCache = new Map(); // identity key -> resolved ArtResult (art is deterministic, cache freely)

/** Cache key = everything the art depends on. */
function artKey(c) {
  return `${c.seed}|${c.rarity}|${c.element}|${c.type}|${c.cls}|${c.tier}`;
}

/**
 * Async art boundary. Resolves with { kind:'svg', svg } for the stub.
 * Deliberately async (microtask + tiny delay) so callers are forced to handle
 * the pending state — exactly what a real image API will need.
 */
export function generateCreatureArt(creature) {
  const key = artKey(creature);
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
// LAYERED PROCEDURAL ART (stub). 15 parts → 125 species:
//
//   1. BODY    (5, by type)    — silhouette + anchor points, drawn in palette slots
//   2. PALETTE (5, by element) — fills those slots: base / shade / accent / highlight
//   3. GEAR    (5, by class)   — props hung on the body's anchors
//
// Bodies never name a colour; they paint with `p.base`, `p.shade`, `p.accent`,
// `p.hi` and outline with `p.line`. That keeps the three axes independent so a
// final style (vinyl toy OR papercut/sticker) can drop in by replacing BODIES,
// GEAR and paletteFor() — each part is one function, nothing else changes.
//
// Style rules baked in for 64–96px readability: thick outlines (OUTLINE),
// flat fills plus one shade tone, no gradients, max 4 colours per element.
//
// The variation layer stays cheap: colour variant (palette shift), pattern
// (none / spots / stripes), eye count, rarity aura, tier notches — all from
// the seed, never changing the silhouette, so a species always reads as itself.
// ---------------------------------------------------------------------------

const OUTLINE = 3.2;

/** Element palette, shifted by colour variant (0 std, 1 dusk, 2 bright). */
export function paletteFor(element, variant = 0) {
  const e = ELEMENTS[element] || { palette: ['#999', '#666', '#ccc', '#eee'], dark: '#333' };
  const [base, shade, accent, hi] = e.palette;
  if (variant === 1) return { base: shade, shade: e.dark, accent, hi: base, line: '#14161c' };
  if (variant === 2) return { base: accent, shade: base, accent: hi, hi: '#ffffff', line: e.dark };
  return { base, shade, accent, hi, line: e.dark };
}

const st = p => `stroke="${p.line}" stroke-width="${OUTLINE}" stroke-linejoin="round" stroke-linecap="round"`;

// --- 1. BODIES -------------------------------------------------------------
// Each returns { svg, head:{x,y,r}, hand:{x,y}, top:{x,y}, belly:{cx,cy,rx,ry} }.
// Anchors let gear and faces sit correctly on every body.
export const BODIES = {
  beast: p => ({
    svg: `
      <path d="M74 60 Q90 52 86 36" fill="none" ${st(p)} stroke-width="6"/>
      <path d="M74 60 Q90 52 86 36" fill="none" stroke="${p.shade}" stroke-width="3" stroke-linecap="round"/>
      <rect x="30" y="66" width="9" height="20" rx="3" fill="${p.shade}" ${st(p)}/>
      <rect x="61" y="66" width="9" height="20" rx="3" fill="${p.shade}" ${st(p)}/>
      <ellipse cx="52" cy="60" rx="26" ry="17" fill="${p.base}" ${st(p)}/>
      <rect x="40" y="68" width="9" height="19" rx="3" fill="${p.base}" ${st(p)}/>
      <rect x="54" y="68" width="9" height="19" rx="3" fill="${p.base}" ${st(p)}/>
      <path d="M22 30 L26 14 L34 26 Z M42 26 L48 13 L50 28 Z" fill="${p.shade}" ${st(p)}/>
      <circle cx="35" cy="38" r="15" fill="${p.base}" ${st(p)}/>
      <ellipse cx="29" cy="45" rx="7" ry="5" fill="${p.hi}" ${st(p)} stroke-width="2"/>`,
    head: { x: 35, y: 36, r: 15 }, hand: { x: 74, y: 70 }, top: { x: 36, y: 22 },
    belly: { cx: 54, cy: 60, rx: 22, ry: 14 },
  }),
  wyrm: p => ({
    svg: `
      <path d="M18 84 Q50 98 80 82 Q90 72 76 66 Q50 76 30 66 Q16 70 18 84 Z" fill="${p.shade}" ${st(p)}/>
      <path d="M28 66 Q50 76 74 64 Q80 52 68 48 Q50 56 36 48 Q24 52 28 66 Z" fill="${p.base}" ${st(p)}/>
      <path d="M38 50 Q50 54 64 46 Q66 38 58 34 L44 36 Q36 40 38 50 Z" fill="${p.base}" ${st(p)}/>
      <path d="M40 22 L36 8 L46 18 Z M60 22 L64 8 L54 18 Z" fill="${p.accent}" ${st(p)}/>
      <ellipse cx="50" cy="28" rx="15" ry="12" fill="${p.base}" ${st(p)}/>
      <path d="M40 60 Q50 64 62 58" fill="none" stroke="${p.hi}" stroke-width="2.5" stroke-linecap="round"/>`,
    head: { x: 50, y: 27, r: 13 }, hand: { x: 80, y: 62 }, top: { x: 50, y: 15 },
    belly: { cx: 50, cy: 64, rx: 22, ry: 10 },
  }),
  avian: p => ({
    svg: `
      <path d="M40 82 L34 92 M58 82 L64 92" ${st(p)} stroke="${p.accent}" stroke-width="4"/>
      <path d="M50 78 L40 94 L50 88 L60 94 Z" fill="${p.shade}" ${st(p)}/>
      <path d="M26 54 Q8 44 10 26 Q24 36 34 46 Z" fill="${p.shade}" ${st(p)}/>
      <path d="M74 54 Q92 44 90 26 Q76 36 66 46 Z" fill="${p.shade}" ${st(p)}/>
      <ellipse cx="50" cy="60" rx="22" ry="22" fill="${p.base}" ${st(p)}/>
      <ellipse cx="50" cy="66" rx="12" ry="13" fill="${p.hi}"/>
      <circle cx="50" cy="34" r="14" fill="${p.base}" ${st(p)}/>
      <path d="M46 40 L50 50 L54 40 Z" fill="${p.accent}" ${st(p)} stroke-width="2"/>`,
    head: { x: 50, y: 31, r: 14 }, hand: { x: 78, y: 60 }, top: { x: 50, y: 20 },
    belly: { cx: 50, cy: 62, rx: 18, ry: 18 },
  }),
  crawler: p => ({
    svg: `
      ${[24, 36, 64, 76].map((x, i) => `<path d="M${x} 66 L${x + (i < 2 ? -10 : 10)} 84" ${st(p)} stroke-width="5"/>
      <path d="M${x} 66 L${x + (i < 2 ? -10 : 10)} 84" stroke="${p.shade}" stroke-width="2.5" stroke-linecap="round"/>`).join('')}
      <path d="M32 40 L22 28 L30 36 M68 40 L78 28 L70 36" fill="none" ${st(p)} stroke-width="4"/>
      <ellipse cx="50" cy="62" rx="34" ry="17" fill="${p.base}" ${st(p)}/>
      <path d="M22 60 Q50 44 78 60" fill="none" stroke="${p.shade}" stroke-width="3"/>
      <path d="M28 68 Q50 56 72 68" fill="none" stroke="${p.shade}" stroke-width="3"/>
      <ellipse cx="50" cy="44" rx="16" ry="11" fill="${p.base}" ${st(p)}/>
      <path d="M42 52 L38 58 M58 52 L62 58" ${st(p)} stroke="${p.accent}" stroke-width="3"/>`,
    head: { x: 50, y: 43, r: 11 }, hand: { x: 84, y: 56 }, top: { x: 50, y: 33 },
    belly: { cx: 50, cy: 62, rx: 30, ry: 14 },
  }),
  construct: p => ({
    svg: `
      <rect x="34" y="76" width="12" height="16" rx="2" fill="${p.shade}" ${st(p)}/>
      <rect x="54" y="76" width="12" height="16" rx="2" fill="${p.shade}" ${st(p)}/>
      <rect x="14" y="46" width="13" height="30" rx="4" fill="${p.shade}" ${st(p)}/>
      <rect x="73" y="46" width="13" height="30" rx="4" fill="${p.shade}" ${st(p)}/>
      <rect x="26" y="42" width="48" height="38" rx="6" fill="${p.base}" ${st(p)}/>
      <rect x="35" y="16" width="30" height="26" rx="4" fill="${p.base}" ${st(p)}/>
      <circle cx="32" cy="48" r="2" fill="${p.line}"/><circle cx="68" cy="48" r="2" fill="${p.line}"/>
      <circle cx="32" cy="74" r="2" fill="${p.line}"/><circle cx="68" cy="74" r="2" fill="${p.line}"/>
      <rect x="42" y="54" width="16" height="14" rx="3" fill="${p.accent}" ${st(p)} stroke-width="2"/>`,
    head: { x: 50, y: 28, r: 12 }, hand: { x: 80, y: 76 }, top: { x: 50, y: 16 },
    belly: { cx: 50, cy: 61, rx: 22, ry: 17 },
  }),
};

// --- 3. GEAR ----------------------------------------------------------------
// Class props, positioned only via body anchors. Gear uses the element palette
// for trims so it always harmonises with the body underneath.
export const GEAR = {
  brute: (p, a) => `
    <g transform="translate(${a.hand.x} ${a.hand.y})">
      <rect x="-2.5" y="-26" width="5" height="30" rx="2" fill="#8a6a44" ${st(p)} stroke-width="2.4"/>
      <path d="M2 -26 Q16 -22 14 -10 Q8 -14 2 -12 Z" fill="#cfd5de" ${st(p)} stroke-width="2.4"/>
    </g>
    <path d="M${a.head.x - a.head.r} ${a.head.y - a.head.r * 0.35} L${a.head.x + a.head.r} ${a.head.y - a.head.r * 0.35}" stroke="${p.accent}" stroke-width="4.5" stroke-linecap="round"/>`,
  guardian: (p, a) => `
    <g transform="translate(${a.hand.x - 4} ${a.hand.y - 8})">
      <path d="M-10 -12 L10 -12 L10 2 Q10 12 0 16 Q-10 12 -10 2 Z" fill="${p.accent}" ${st(p)} stroke-width="2.6"/>
      <path d="M0 -8 L0 12 M-7 0 L7 0" stroke="${p.shade}" stroke-width="2.4" stroke-linecap="round"/>
    </g>
    <path d="M${a.top.x - 10} ${a.top.y + 6} Q${a.top.x} ${a.top.y - 8} ${a.top.x + 10} ${a.top.y + 6} Z" fill="#cfd5de" ${st(p)} stroke-width="2.4"/>`,
  tender: (p, a) => `
    <g transform="translate(${a.hand.x - 2} ${a.hand.y - 4})">
      <path d="M-9 -2 L9 -2 L7 10 L-7 10 Z" fill="#c8964f" ${st(p)} stroke-width="2.4"/>
      <path d="M-7 -2 Q0 -14 7 -2" fill="none" stroke="${p.line}" stroke-width="2.4"/>
      <circle cx="-3" cy="-4" r="3" fill="${p.accent}"/><circle cx="3" cy="-5" r="3" fill="${p.hi}"/>
    </g>
    <path d="M${a.top.x} ${a.top.y + 2} Q${a.top.x - 2} ${a.top.y - 8} ${a.top.x - 8} ${a.top.y - 9} Q${a.top.x - 2} ${a.top.y - 3} ${a.top.x} ${a.top.y + 2} Z M${a.top.x} ${a.top.y + 2} Q${a.top.x + 3} ${a.top.y - 7} ${a.top.x + 9} ${a.top.y - 7} Q${a.top.x + 3} ${a.top.y - 1} ${a.top.x} ${a.top.y + 2} Z" fill="#7ccf6a" ${st(p)} stroke-width="2"/>`,
  seer: (p, a) => `
    <circle cx="${a.hand.x}" cy="${a.hand.y - 22}" r="7" fill="${p.hi}" ${st(p)} stroke-width="2.4"/>
    <circle cx="${a.hand.x - 2}" cy="${a.hand.y - 24}" r="2.2" fill="#ffffff"/>
    <path d="M${a.top.x - 5} ${a.top.y + 5} L${a.top.x} ${a.top.y - 2} L${a.top.x + 5} ${a.top.y + 5} L${a.top.x} ${a.top.y + 11} Z" fill="#b48cff" ${st(p)} stroke-width="2"/>`,
  trickster: (p, a) => `
    <path d="M${a.head.x - a.head.r - 1} ${a.head.y - 1} Q${a.head.x} ${a.head.y - 9} ${a.head.x + a.head.r + 1} ${a.head.y - 1} L${a.head.x + a.head.r - 1} ${a.head.y + 6} Q${a.head.x} ${a.head.y + 1} ${a.head.x - a.head.r + 1} ${a.head.y + 6} Z" fill="#3b2f5c" ${st(p)} stroke-width="2"/>
    <path d="M${a.top.x - 12} ${a.top.y + 6} L${a.top.x - 16} ${a.top.y - 10} L${a.top.x} ${a.top.y + 2} L${a.top.x + 16} ${a.top.y - 10} L${a.top.x + 12} ${a.top.y + 6} Z" fill="${p.accent}" ${st(p)} stroke-width="2.4"/>
    <circle cx="${a.top.x - 16}" cy="${a.top.y - 11}" r="3" fill="#ffd34d" ${st(p)} stroke-width="1.6"/>
    <circle cx="${a.top.x + 16}" cy="${a.top.y - 11}" r="3" fill="#ffd34d" ${st(p)} stroke-width="1.6"/>`,
};

// --- Compositor ---------------------------------------------------------------

function drawCreatureSVG(c) {
  const rng = mulberry32((c.seed >>> 0) ^ 0xa47);
  const variant = variantRoll(c.seed);
  const p = paletteFor(c.element, variant);
  const body = (BODIES[c.type] || BODIES.beast)(p);
  const parts = [];

  // Rarity aura ring behind everything.
  const auraOpacity = { common: 0, uncommon: 0.12, rare: 0.2, epic: 0.3, legendary: 0.42, mythic: 0.55 }[c.rarity] ?? 0;
  if (auraOpacity > 0) parts.push(`<circle cx="50" cy="54" r="44" fill="${p.accent}" opacity="${auraOpacity}"/>`);

  // 1+2: body in element palette.
  parts.push(body.svg);

  // Variation: pattern on the belly region (none / spots / stripes).
  const patternRoll = rng();
  const clipId = `cl${(c.seed >>> 0).toString(36)}${c.type[0]}`;
  const b = body.belly;
  if (patternRoll < 0.6) {
    let marks = '';
    if (patternRoll < 0.3) {
      const n = 3 + Math.floor(rng() * 3);
      for (let i = 0; i < n; i++) {
        marks += `<circle cx="${(b.cx - b.rx * 0.7 + rng() * b.rx * 1.4).toFixed(1)}" cy="${(b.cy - b.ry * 0.6 + rng() * b.ry * 1.2).toFixed(1)}" r="${(2.2 + rng() * 2).toFixed(1)}" fill="${p.shade}"/>`;
      }
    } else {
      const n = 2 + Math.floor(rng() * 2);
      for (let i = 0; i < n; i++) {
        const x = b.cx - b.rx * 0.5 + i * (b.rx / n);
        marks += `<rect x="${x.toFixed(1)}" y="${b.cy - b.ry}" width="4" height="${b.ry * 2}" fill="${p.shade}" transform="rotate(14 ${x.toFixed(1)} ${b.cy})"/>`;
      }
    }
    parts.push(`<clipPath id="${clipId}"><ellipse cx="${b.cx}" cy="${b.cy}" rx="${b.rx}" ry="${b.ry}"/></clipPath><g clip-path="url(#${clipId})" opacity="0.75">${marks}</g>`);
  }

  // Face: eyes on the head anchor (1–3, seeded).
  const h = body.head;
  const eyes = 1 + Math.floor(rng() * 3);
  for (let i = 0; i < eyes; i++) {
    const ex = h.x + (i - (eyes - 1) / 2) * h.r * 0.55;
    const ey = h.y - h.r * 0.05;
    parts.push(`<circle cx="${ex.toFixed(1)}" cy="${ey.toFixed(1)}" r="3.4" fill="#fff" stroke="${p.line}" stroke-width="1.6"/>
      <circle cx="${(ex + 0.6).toFixed(1)}" cy="${(ey + 0.4).toFixed(1)}" r="1.7" fill="#14161c"/>`);
  }

  // 3: class gear on top.
  parts.push((GEAR[c.cls] || (() => ''))(p, body));

  // Legendary+ sparkles.
  if (c.rarity === 'legendary' || c.rarity === 'mythic') {
    const n = c.rarity === 'mythic' ? 6 : 4;
    for (let i = 0; i < n; i++) {
      const ang = (i / n) * Math.PI * 2 + rng();
      const sx = 50 + Math.cos(ang) * 44, sy = 52 + Math.sin(ang) * 42;
      parts.push(`<path d="M${sx.toFixed(1)} ${(sy - 3).toFixed(1)} l1.8 3 -1.8 3 -1.8 -3 Z" fill="${p.hi}" stroke="${p.line}" stroke-width="0.8"/>`);
    }
  }

  // Tier notches along the bottom — quick visual read of fusion depth.
  for (let i = 0; i < Math.min(c.tier || 1, 12); i++) {
    parts.push(`<rect x="${(20 + i * 5.2).toFixed(1)}" y="96" width="3.4" height="3.4" rx="1" fill="${p.base}" stroke="${p.line}" stroke-width="0.6"/>`);
  }

  return `<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">${parts.join('')}</svg>`;
}

/** Colour variant from seed (mirrors creature.js variantOf; duplicated here
 *  so the art module stays self-contained for a future swap). */
function variantRoll(seed) {
  const r = mulberry32((seed >>> 0) ^ 0x7a71)();
  return r < 0.70 ? 0 : r < 0.92 ? 1 : 2;
}
