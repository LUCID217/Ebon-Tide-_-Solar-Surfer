// ============================================================================
// creature.js — the creature data model.
// A creature is plain JSON (safe for localStorage + share strings). All
// derived values (name, signature) are computed deterministically from its
// data, so two copies of the same creature always agree.
// ============================================================================

import { CONFIG, ELEMENTS, TYPE_KEYS, CLASS_KEYS, CLASSES, BODY_NAMES } from './config.js';
import { mulberry32, pick, weightedPick, freshSeed } from './rng.js';
import { rollTraits } from './traits.js';

let idCounter = 0;
/** Unique-enough runtime id (persisted; counter re-synced on load). */
export function nextCreatureId() {
  return `c${Date.now().toString(36)}_${(idCounter++).toString(36)}`;
}
export function syncIdCounter(n) { idCounter = Math.max(idCounter, n); }

// --- Species naming ---------------------------------------------------------
// v5: a species is element × type × class (125 of them). The body name comes
// from the 5×5 BODY_NAMES table (element × type) and the class is the title,
// e.g. "Cinderhound Brute". Every individual of a species shares the name —
// individuality lives in stats, colour/pattern variant, traits and lineage.

/** Deterministic species name. */
export function speciesName(c) {
  const body = BODY_NAMES[c.element]?.[c.type] || 'Oddling';
  return `${body} ${CLASSES[c.cls]?.label || ''}`.trim();
}

/** Species signature — the collection/dex key: "element|type|cls". */
export function speciesSignature(c) {
  return `${c.element}|${c.type}|${c.cls}`;
}

/** Colour/pattern variant (0..2) — part of the cheap variation layer.
 *  Derived from seed, never stored, so it can't drift. */
export function variantOf(c) {
  const r = mulberry32((c.seed >>> 0) ^ 0x7a71)();
  return r < 0.70 ? 0 : r < 0.92 ? 1 : 2; // 70% standard, 22% dusk, 8% bright
}
export const VARIANT_LABELS = ['', 'Dusk variant', 'Bright variant'];

// --- Construction -----------------------------------------------------------

/**
 * Create a brand-new base creature (starter or shop egg).
 * Tier 1, single element, stats rolled from seed.
 */
export function makeBaseCreature({ element = null, rarity = null, seed = null, rarityWeights = null } = {}) {
  const s = seed ?? freshSeed();
  const rng = mulberry32(s);
  const el = element ?? pick(rng, Object.keys(ELEMENTS));
  const rar = rarity ?? weightedPick(rng, rarityWeights || CONFIG.rarity.eggWeights);
  const rarityIdx = CONFIG.rarity.order.indexOf(rar);
  // Base stats 20..50, nudged up by rarity (+8 per rarity step).
  const stat = () => Math.round(20 + rng() * 30 + rarityIdx * 8);
  const stats = { power: stat(), charm: stat(), vitality: stat() };
  const c = {
    id: nextCreatureId(),
    seed: s,
    element: el,
    type: pick(rng, TYPE_KEYS),
    cls: pick(rng, CLASS_KEYS),
    tier: 1,
    rarity: rar,
    stats,
    parents: null,           // [nameA, nameB] for hybrids; null for base
    habitatId: null,         // which habitat it lives in (null = reserve/pen)
    bornAt: Date.now(),
    fusedCount: 0,           // times used as a fusion parent (flavor stat)
  };
  c.traits = rollTraits(c);  // passive traits, deterministic from seed+rarity
  c.name = speciesName(c);
  return c;
}

// --- Derived economy values (see economy.js for the tick that uses these) ----

/** Coins/sec this creature generates BEFORE happiness/habitat multipliers. */
export function baseRevenuePerSec(c) {
  const classMult = CONFIG.classes[c.cls]?.revenueMult ?? 1; // Brutes earn big
  return CONFIG.economy.rarityRevenuePerSec[c.rarity] * (c.stats.power / 100) * classMult;
}

/** Coins/sec upkeep. High vitality discounts maintenance (up to 50%). */
export function maintenancePerSec(c) {
  const base = CONFIG.economy.rarityMaintenancePerSec[c.rarity];
  const discount = 1 - CONFIG.economy.vitalityMaintDiscount * Math.min(c.stats.vitality, 100) / 100;
  const classMult = CONFIG.classes[c.cls]?.maintMult ?? 1; // ...and eat big
  return base * discount * classMult;
}

export function rarityColor(c) {
  return CONFIG.rarity.colors[c.rarity];
}
