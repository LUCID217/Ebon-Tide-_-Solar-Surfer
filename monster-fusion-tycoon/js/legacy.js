// ============================================================================
// legacy.js — remap pre-v5 creature data (8 elements × 12 archetypes) onto
// the 5/5/5 system (element × type × class).
//
// ONE function, used by both the v4→v5 save migration (save.js) and MFT1
// share-string import (share.js), so a creature remaps identically whichever
// way it arrives. Deterministic: any tie is broken from the creature's own
// seed, never Math.random.
// ============================================================================

import {
  ELEMENT_CYCLE, LEGACY_ELEMENT_MAP, LEGACY_ARCHETYPE_MAP, TYPE_KEYS, CLASS_KEYS,
} from './config.js';
import { mulberry32 } from './rng.js';

/** Old element key (or an already-new one) → new element key. */
export function remapElement(el) {
  if (ELEMENT_CYCLE.includes(el)) return el;
  return LEGACY_ELEMENT_MAP[el] || null;
}

/**
 * Pick the single new element for an old multi-element creature: the most
 * common remapped element wins (fire+light → ember twice); ties are broken
 * deterministically from the seed. Unknown input falls back to a seeded pick.
 */
export function remapElements(elements, seed) {
  const rng = mulberry32((seed >>> 0) ^ 0x5e1e);
  const counts = {};
  for (const e of elements || []) {
    const n = remapElement(e);
    if (n) counts[n] = (counts[n] || 0) + 1;
  }
  const keys = Object.keys(counts);
  if (!keys.length) return ELEMENT_CYCLE[Math.floor(rng() * ELEMENT_CYCLE.length)];
  const best = Math.max(...keys.map(k => counts[k]));
  const tied = ELEMENT_CYCLE.filter(k => counts[k] === best); // cycle order = stable
  return tied[Math.floor(rng() * tied.length)];
}

/** Old archetype → [type, cls]. Unknown archetypes get a seeded pick. */
export function remapArchetype(archetype, seed) {
  const hit = LEGACY_ARCHETYPE_MAP[archetype];
  if (hit) return hit;
  const rng = mulberry32((seed >>> 0) ^ 0xa4c7);
  return [TYPE_KEYS[Math.floor(rng() * 5)], CLASS_KEYS[Math.floor(rng() * 5)]];
}

/**
 * Mutates a creature-shaped object (full creature, lineage snapshot,
 * pending-fusion parent, discovery entry) in place: replaces
 * `elements`/`archetype` with `element`/`type`/`cls`. Objects already in
 * v5 shape are left untouched. Returns the object.
 */
export function remapCreatureShape(c) {
  if (!c || typeof c !== 'object') return c;
  if (c.element && c.type && c.cls) return c;
  const seed = Number.isFinite(c.seed) ? c.seed : 0;
  c.element = remapElements(c.elements, seed);
  [c.type, c.cls] = remapArchetype(c.archetype, seed);
  delete c.elements;
  delete c.archetype;
  return c;
}
