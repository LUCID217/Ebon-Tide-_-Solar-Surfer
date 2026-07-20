// ============================================================================
// state.js — single owner of mutable game state.
// Every other module imports `S` (the live state object) and the helpers here,
// rather than scattering globals. save.js serializes exactly this shape.
// ============================================================================

import { CONFIG } from './config.js';

/** Build a brand-new game state (fresh save). Shape == save schema v1. */
export function freshState() {
  return {
    version: CONFIG.save.schemaVersion,
    resources: {
      coins: CONFIG.economy.startingCoins,
      essence: CONFIG.economy.startingEssence,
      relics: CONFIG.economy.startingRelics,
    },
    creatures: {},        // id -> creature (see creature.js)
    habitats: {},         // id -> { id, biome, level, decorations, name }
    habitatOrder: [],     // display order of habitat ids
    pendingFusion: null,  // { parentAId, parentBId, resolveAt, childSeed } | null
    collectPool: 0,       // uncollected coins (manual-collect grind loop)
    discovered: {},       // speciesSignature -> { name, elements, archetype, rarity, firstAt, count }
    upgrades: {           // one-time shop purchases
      autoCollector: false,
      groundskeeper: false,
      fusionRitualist: false,
    },
    counters: {           // lifetime stats driving milestones/objectives
      fusions: 0,
      eggsBought: 0,
      coinsEarned: 0,
      collects: 0,
      habitatsBuilt: 1,
      creatureId: 1,
    },
    objectives: {
      dailyDate: null,    // 'YYYY-MM-DD' the current dailies were rolled for
      daily: [],          // [{ id, kind, target, progress, done, claimed }]
      milestonesClaimed: {}, // e.g. { 'fusion_5': true }
    },
    lastSeen: Date.now(), // for offline progress on load
  };
}

/** The live state. Replaced wholesale by load/wipe via setState(). */
export let S = freshState();

export function setState(next) { S = next; }

// --- Small shared helpers ---------------------------------------------------

export function creaturesInHabitat(habitatId) {
  return Object.values(S.creatures).filter(c => c.habitatId === habitatId);
}

/** Creatures not assigned to any habitat (the "reserve pen" — they earn nothing). */
export function reserveCreatures() {
  return Object.values(S.creatures).filter(c => c.habitatId === null);
}

export function habitatCapacity(h) {
  return CONFIG.habitats.baseCapacity + (h.level - 1) * CONFIG.habitats.capacityPerLevel;
}

export function canAfford(cost) {
  return (cost.coins ?? 0) <= S.resources.coins
    && (cost.essence ?? 0) <= S.resources.essence
    && (cost.relics ?? 0) <= S.resources.relics;
}

/** Deduct a {coins?, essence?, relics?} cost. Returns false (no-op) if unaffordable. */
export function spend(cost) {
  if (!canAfford(cost)) return false;
  S.resources.coins -= cost.coins ?? 0;
  S.resources.essence -= cost.essence ?? 0;
  S.resources.relics -= cost.relics ?? 0;
  return true;
}

export function earnCoins(n) {
  S.resources.coins += n;
  S.counters.coinsEarned += n;
}
