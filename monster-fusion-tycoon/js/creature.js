// ============================================================================
// creature.js — the creature data model.
// A creature is plain JSON (safe for localStorage + share strings). All
// derived values (name, signature) are computed deterministically from its
// data, so two copies of the same creature always agree.
// ============================================================================

import { CONFIG, ELEMENTS, ARCHETYPES } from './config.js';
import { mulberry32, pick, weightedPick, freshSeed } from './rng.js';
import { rollTraits } from './traits.js';

let idCounter = 0;
/** Unique-enough runtime id (persisted; counter re-synced on load). */
export function nextCreatureId() {
  return `c${Date.now().toString(36)}_${(idCounter++).toString(36)}`;
}
export function syncIdCounter(n) { idCounter = Math.max(idCounter, n); }

// --- Species naming ---------------------------------------------------------
// Names are assembled from element syllables + archetype, so every new
// element-combo × archetype yields a new species name without a lookup table.
const ELEMENT_SYLLABLES = {
  fire:   ['Pyro', 'Ember', 'Cinder', 'Scorch'],
  water:  ['Aqua', 'Tide', 'Brine', 'Mist'],
  earth:  ['Terra', 'Boulder', 'Clay', 'Quake'],
  air:    ['Zephyr', 'Gale', 'Sky', 'Breeze'],
  nature: ['Verdant', 'Bloom', 'Thorn', 'Moss'],
  shadow: ['Umbra', 'Dusk', 'Gloom', 'Void'],
  light:  ['Lumen', 'Dawn', 'Halo', 'Glint'],
  storm:  ['Volt', 'Tempest', 'Arc', 'Thunder'],
};

/**
 * Deterministic species name from elements + archetype + seed.
 * e.g. ['fire','storm'] + 'Drake' -> "Ember-Volt Drake"
 */
export function speciesName(creature) {
  const rng = mulberry32(creature.seed ^ 0xbeef);
  const parts = creature.elements.map(el => pick(rng, ELEMENT_SYLLABLES[el] || ['Odd']));
  return `${parts.join('-')} ${creature.archetype}`;
}

/**
 * Species signature — the collection-log key. Two creatures with the same
 * sorted element set + archetype are the same "species" regardless of stats.
 */
export function speciesSignature(creature) {
  return `${[...creature.elements].sort().join('+')}|${creature.archetype}`;
}

// --- Construction -----------------------------------------------------------

/**
 * Create a brand-new base creature (starter or shop egg).
 * Tier 1, single element, stats rolled from seed.
 */
export function makeBaseCreature({ element = null, rarity = null, seed = null } = {}) {
  const s = seed ?? freshSeed();
  const rng = mulberry32(s);
  const el = element ?? pick(rng, Object.keys(ELEMENTS));
  const rar = rarity ?? weightedPick(rng, CONFIG.rarity.eggWeights);
  const rarityIdx = CONFIG.rarity.order.indexOf(rar);
  // Base stats 20..50, nudged up by rarity (+8 per rarity step).
  const stat = () => Math.round(20 + rng() * 30 + rarityIdx * 8);
  const c = {
    id: nextCreatureId(),
    seed: s,
    elements: [el],
    archetype: pick(rng, ARCHETYPES),
    tier: 1,
    rarity: rar,
    stats: { power: stat(), charm: stat(), vitality: stat() },
    parents: null,           // [signatureA, signatureB] for hybrids; null for base
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
  return CONFIG.economy.rarityRevenuePerSec[c.rarity] * (c.stats.power / 100);
}

/** Coins/sec upkeep. High vitality discounts maintenance (up to 50%). */
export function maintenancePerSec(c) {
  const base = CONFIG.economy.rarityMaintenancePerSec[c.rarity];
  const discount = 1 - CONFIG.economy.vitalityMaintDiscount * Math.min(c.stats.vitality, 100) / 100;
  return base * discount;
}

export function rarityColor(c) {
  return CONFIG.rarity.colors[c.rarity];
}
