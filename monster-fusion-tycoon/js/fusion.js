// ============================================================================
// fusion.js — deterministic fusion/breeding logic.
//
// HARD RULE: fusion resolves instantly and locally. Given the two parents and
// the childSeed, the resulting creature is fully computed synchronously by
// this module — no network, no async. Art loads separately afterwards
// (see art.js); the game is playable even if art never resolves.
//
// Parents are CONSUMED by fusion — that's the core roster tradeoff.
// Element sets merge open-endedly (union + possible mutation), so new species
// keep emerging as the tree deepens instead of exhausting a lookup table.
// ============================================================================

import { CONFIG, ELEMENTS, ARCHETYPES } from './config.js';
import { S } from './state.js';
import { mulberry32, hashStr, pick } from './rng.js';
import { nextCreatureId, speciesName, speciesSignature } from './creature.js';
import { rollTraits, fusionMods } from './traits.js';

const F = CONFIG.fusion;
const R = CONFIG.rarity;

/** Cost of fusing these two parents: scales with combined tier.
 *  Fertile-trait parents discount it (see traits.js fusionMods). */
export function fusionCost(a, b) {
  const t = a.tier + b.tier;
  const { costMult } = fusionMods(a, b);
  return {
    coins: Math.round((F.baseCostCoins + F.costCoinsPerTier * (t - 2)) * costMult),
    essence: Math.round((F.baseCostEssence + F.costEssencePerTier * (t - 2)) * costMult),
  };
}

/** Fusion resolve time in seconds (halved if the Fusion Ritualist is hired). */
export function fusionTimeSec(a, b) {
  const t = Math.min(F.maxTimeSec, F.baseTimeSec + F.timePerTierSec * (a.tier + b.tier - 2));
  return S.upgrades.fusionRitualist ? t / CONFIG.shop.fusionRitualistSpeed : t;
}

export function canFuse(a, b) {
  if (!a || !b || a.id === b.id) return { ok: false, why: 'Pick two different creatures.' };
  if (a.tier >= F.maxTier || b.tier >= F.maxTier) return { ok: false, why: `Tier ${F.maxTier} creatures are beyond fusion.` };
  if (S.pendingFusion) return { ok: false, why: 'The den is already glowing — one fusion at a time.' };
  return { ok: true };
}

/**
 * The deterministic core: compute the child from parents + seed.
 * Pure function of its inputs — used by resolve, and reusable by future
 * "preview possible outcomes" UI without touching game state.
 */
/** Count opposing element pairs across the two parents (volatile pairings). */
export function volatilePairCount(a, b) {
  const pool = new Set([...a.elements, ...b.elements]);
  return F.volatilePairs.filter(([x, y]) => pool.has(x) && pool.has(y)).length;
}

export function computeChild(a, b, childSeed) {
  const rng = mulberry32(childSeed);
  const tier = Math.min(F.maxTier, Math.max(a.tier, b.tier) + 1);
  const volatile = volatilePairCount(a, b);

  // --- Elements: union of parents, trimmed to maxElements by seeded picks ---
  let pool = [...new Set([...a.elements, ...b.elements])];
  let elements;
  if (pool.length <= F.maxElements) {
    elements = pool;
  } else {
    elements = [];
    const bag = [...pool];
    while (elements.length < F.maxElements) {
      const i = Math.floor(rng() * bag.length);
      elements.push(bag.splice(i, 1)[0]);
    }
  }
  // Mutation: chance to gain an element neither parent has — the open-ended hook.
  // Volatile (opposing-element) pairings destabilize the ritual: more mutations.
  let mutated = false;
  if (rng() < F.mutationChance + volatile * F.volatileMutationBonus) {
    const outside = Object.keys(ELEMENTS).filter(e => !pool.includes(e));
    if (outside.length) {
      const gained = pick(rng, outside);
      if (elements.length >= F.maxElements) elements[Math.floor(rng() * elements.length)] = gained;
      else elements.push(gained);
      mutated = true;
    }
  }
  elements = [...new Set(elements)].sort();

  // --- Archetype: usually inherited, sometimes shifts entirely ---
  let archetype = rng() < 0.5 ? a.archetype : b.archetype;
  if (rng() < F.archetypeShiftChance) {
    const others = ARCHETYPES.filter(x => x !== a.archetype && x !== b.archetype);
    archetype = pick(rng, others);
  }

  // --- Rarity: floor at higher parent, chance to spike (or slip) ---
  // Prism Heart parents add to the upgrade chance (traits unlock rare fusions).
  const startIdx = Math.max(R.order.indexOf(a.rarity), R.order.indexOf(b.rarity));
  const divBonus = R.elementDiversityBonus * (elements.length - 1) + fusionMods(a, b).upgradeBonus;
  let idx = startIdx;
  const roll = rng();
  if (roll < R.doubleUpgradeChance + divBonus / 2) idx += 2;
  else if (roll < R.doubleUpgradeChance + R.upgradeChance + divBonus) idx += 1;
  else if (roll > 1 - R.downgradeChance) idx -= 1;
  idx = Math.max(0, Math.min(R.order.length - 1, idx));
  const rarity = R.order[idx];

  // --- Stats: parent average ± variance, plus flat tier growth ---
  const volatileMult = 1 + volatile * F.volatileStatBonus; // unstable fusions surge
  const inherit = (sa, sb) => {
    const avg = (sa + sb) / 2;
    const varied = avg * (1 + (rng() * 2 - 1) * F.statVariance);
    return Math.min(F.statCap, Math.max(1, Math.round(varied * (1 + F.statTierBonus * tier) * volatileMult)));
  };
  const stats = {
    power: inherit(a.stats.power, b.stats.power),
    charm: inherit(a.stats.charm, b.stats.charm),
    vitality: inherit(a.stats.vitality, b.stats.vitality),
  };

  const child = {
    id: nextCreatureId(),
    seed: childSeed,
    elements, archetype, tier, rarity, stats,
    parents: [a.name, b.name],
    habitatId: null,
    bornAt: Date.now(),
    fusedCount: 0,
    mutated, // flavor flag for the reveal UI
  };
  child.traits = rollTraits(child);
  child.name = speciesName(child);
  return child;
}

/** Deterministic child seed from the parents + how many fusions have happened. */
export function childSeedFor(a, b) {
  return hashStr(`${a.seed}|${b.seed}|${S.counters.fusions}`) >>> 0;
}

/**
 * Kick off a fusion: validates, pays, consumes parents, sets the pending
 * timer. Returns { ok, why? }. Child is computed at resolve time (but its
 * seed is fixed NOW, so the outcome is already sealed — no save-scumming).
 */
export function startFusion(aId, bId, spendFn) {
  const a = S.creatures[aId], b = S.creatures[bId];
  const check = canFuse(a, b);
  if (!check.ok) return check;
  const cost = fusionCost(a, b);
  if (!spendFn(cost)) return { ok: false, why: 'Not enough resources.' };
  const seed = childSeedFor(a, b);
  S.counters.fusions++;
  S.pendingFusion = {
    parentSnapshotA: a, parentSnapshotB: b, // full snapshots: parents leave the roster now
    resolveAt: Date.now() + fusionTimeSec(a, b) * 1000,
    childSeed: seed,
  };
  delete S.creatures[aId];
  delete S.creatures[bId];
  return { ok: true };
}

/**
 * If the pending fusion's timer has elapsed, resolve it: compute the child,
 * add to roster + discovery log. Returns the child, or null if not ready.
 */
export function tryResolveFusion() {
  const p = S.pendingFusion;
  if (!p || Date.now() < p.resolveAt) return null;
  const child = computeChild(p.parentSnapshotA, p.parentSnapshotB, p.childSeed);
  S.creatures[child.id] = child;
  S.pendingFusion = null;
  registerDiscovery(child);
  return child;
}

/** Record a species in the collection log (also used for eggs/starters/imports). */
export function registerDiscovery(c) {
  const sig = speciesSignature(c);
  const entry = S.discovered[sig];
  if (entry) {
    entry.count++;
    return false; // already known
  }
  S.discovered[sig] = {
    name: c.name, elements: c.elements, archetype: c.archetype,
    rarity: c.rarity, seed: c.seed, tier: c.tier,
    firstAt: Date.now(), count: 1,
  };
  // New species pay an essence bounty — exploration feeds the breeding loop.
  S.resources.essence += CONFIG.economy.discoveryEssenceBonus;
  S.counters.discoveries++;
  return true; // new discovery!
}
