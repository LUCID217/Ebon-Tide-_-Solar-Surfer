// ============================================================================
// share.js — offline-first creature sharing.
//
// FORMAT (documented in README): `MFT1.<payload>.<checksum>`
//   - MFT1      : format tag + version. Bump to MFT2 if fields change.
//   - <payload> : base64url( JSON of the minimal creature fields )
//   - <checksum>: FNV-1a hash (base36) of the payload — catches paste mangling.
// The full creature is encoded; no server is needed to view or adopt one.
// A shareable URL is just the game URL with `#c=<string>` appended.
//
// FUTURE ONLINE GALLERY: this module is the seam. A gallery would POST the
// same string to a server and list them; import stays identical. Nothing
// here assumes a backend exists.
// ============================================================================

import { S } from './state.js';
import { hashStr } from './rng.js';
import { nextCreatureId, speciesName } from './creature.js';
import { registerDiscovery } from './fusion.js';
import { rollTraits } from './traits.js';

const FORMAT_TAG = 'MFT1';

// --- base64url helpers (unicode-safe) ---------------------------------------

function b64urlEncode(str) {
  const bytes = new TextEncoder().encode(str);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlDecode(s) {
  const b64 = s.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - s.length % 4) % 4);
  const bin = atob(b64);
  const bytes = Uint8Array.from(bin, ch => ch.charCodeAt(0));
  return new TextDecoder().decode(bytes);
}

// --- Export ------------------------------------------------------------------

/** Encode a creature into a share string. Only identity fields travel. */
export function exportCreature(c) {
  const payload = b64urlEncode(JSON.stringify({
    seed: c.seed,
    elements: c.elements,
    archetype: c.archetype,
    tier: c.tier,
    rarity: c.rarity,
    stats: c.stats,
    parents: c.parents,   // ancestor names — pure flavor, fine to share
  }));
  return `${FORMAT_TAG}.${payload}.${hashStr(payload).toString(36)}`;
}

/** Shareable URL for the current page.
 *  Built from location.href, NOT location.origin — origin is the string
 *  "null" on file:// and in sandboxed embeds, which mangled the URL. */
export function exportURL(c) {
  const base = location.href.split('#')[0];
  return `${base}#c=${exportCreature(c)}`;
}

// --- Import ------------------------------------------------------------------

/**
 * Decode a share string. Returns { ok, creature? , why? }.
 * The decoded creature is NOT added to the game — callers decide (view/adopt).
 */
export function decodeShareString(raw) {
  const str = (raw || '').trim();
  // Accept full URLs too — pull out the #c= fragment.
  const m = str.match(/#c=([^&\s]+)/);
  const token = m ? m[1] : str;
  const parts = token.split('.');
  if (parts.length !== 3 || parts[0] !== FORMAT_TAG) {
    return { ok: false, why: 'Not a valid share string (expected MFT1.…).' };
  }
  const [, payload, check] = parts;
  if (hashStr(payload).toString(36) !== check) {
    return { ok: false, why: 'Checksum mismatch — the string got mangled in transit.' };
  }
  let data;
  try {
    data = JSON.parse(b64urlDecode(payload));
  } catch {
    return { ok: false, why: 'Could not decode the payload.' };
  }
  // Validate shape defensively — this is external input.
  if (!Number.isFinite(data.seed) || !Array.isArray(data.elements) || !data.elements.length
    || typeof data.archetype !== 'string' || !Number.isFinite(data.tier)
    || typeof data.rarity !== 'string' || typeof data.stats !== 'object' || data.stats === null) {
    return { ok: false, why: 'Share string is missing creature fields.' };
  }
  const clampStat = v => Math.max(1, Math.min(999, Math.round(Number(v) || 1)));
  const creature = {
    id: null, // assigned on adopt
    seed: data.seed >>> 0,
    elements: data.elements.slice(0, 3).map(String),
    archetype: String(data.archetype),
    tier: Math.max(1, Math.min(12, Math.round(data.tier))),
    rarity: ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'].includes(data.rarity) ? data.rarity : 'common',
    stats: {
      power: clampStat(data.stats.power),
      charm: clampStat(data.stats.charm),
      vitality: clampStat(data.stats.vitality),
    },
    parents: Array.isArray(data.parents) ? data.parents.slice(0, 2).map(String) : null,
    habitatId: null,
    bornAt: Date.now(),
    fusedCount: 0,
  };
  creature.traits = rollTraits(creature); // deterministic from seed — travels for free
  creature.name = speciesName(creature);
  return { ok: true, creature };
}

/** Essence cost to adopt an imported creature (scales with tier + rarity). */
export function adoptCost(c) {
  const rIdx = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'].indexOf(c.rarity);
  return 10 + c.tier * 5 + rIdx * rIdx * 15;
}

/** Adopt a decoded creature into the reserve pen (pays essence). */
export function adoptCreature(c) {
  const cost = adoptCost(c);
  if (S.resources.essence < cost) return { ok: false, why: `Adoption needs ${cost} 💠 essence.` };
  S.resources.essence -= cost;
  const adopted = { ...c, id: nextCreatureId(), bornAt: Date.now() };
  S.creatures[adopted.id] = adopted;
  const isNew = registerDiscovery(adopted);
  return { ok: true, creature: adopted, isNew };
}
