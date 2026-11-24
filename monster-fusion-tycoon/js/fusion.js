// ============================================================================
// fusion.js — deterministic fusion/breeding logic.
//
// HARD RULE: fusion resolves instantly and locally. Given the two parents and
// the childSeed, the resulting creature is fully computed synchronously by
// this module — no network, no async. Art loads separately afterwards
// (see art.js); the game is playable even if art never resolves.
//
// Parents are CONSUMED by fusion — that's the core roster tradeoff.
// v5 (5/5/5): a species is element × type × class — 125 in all. Each axis
// resolves independently (see computeChild); dice, variants, traits and
// lineage depth keep individuals varied inside that finite, knowable set.
// ============================================================================

import {
  CONFIG, ELEMENT_CYCLE, CLASS_RECIPES, feedsTarget, overcomesTarget,
} from './config.js';
import { S } from './state.js';
import { mulberry32, hashStr, pick } from './rng.js';
import { nextCreatureId, speciesName, speciesSignature } from './creature.js';
import { rollTraits, fusionMods } from './traits.js';
import { recordFusion } from './lineage.js';

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

// --- Axis rules (pure helpers, shared by computeChild and the den preview) ---

/** How two elements relate on the cycle: 'same' | 'feeds' | 'volatile' | 'other'. */
export function elementBond(ea, eb) {
  if (ea === eb) return 'same';
  if (feedsTarget(ea) === eb || feedsTarget(eb) === ea) return 'feeds';
  if (overcomesTarget(ea) === eb || overcomesTarget(eb) === ea) return 'volatile';
  return 'other'; // unreachable on the 5-cycle; kept as a safe fallback
}

const classCount = (a, b, cls) => (a.cls === cls) + (b.cls === cls);

/** The parent whose type the child favours: higher rarity, then higher tier. */
function rarerParent(a, b) {
  const ra = CONFIG.rarity.order.indexOf(a.rarity), rb = CONFIG.rarity.order.indexOf(b.rarity);
  if (ra !== rb) return ra > rb ? a : b;
  if (a.tier !== b.tier) return a.tier > b.tier ? a : b;
  return null; // dead even → coin flip
}

/**
 * Everything knowable about a pairing BEFORE the seed is rolled. computeChild
 * reads its numbers from here, so the den preview can never drift from the
 * real odds. Returns:
 *   { bond, elementOdds: {el: p}, primaryElement?, mutationChance,
 *     typeOdds: {type: p}, cls, upgradeBonus, statMult }
 * elementOdds are BEFORE mutation; mutation then replaces the element with a
 * uniformly chosen element neither parent has.
 */
export function fusionOdds(a, b) {
  const bond = elementBond(a.element, b.element);
  const elementOdds = {};
  let mutationChance = F.baseMutationChance
    + classCount(a, b, 'trickster') * CONFIG.classes.trickster.fusionMutationBonus;
  if (bond === 'same') elementOdds[a.element] = 1;
  else if (bond === 'feeds') elementOdds[feedsTarget(a.element) === b.element ? b.element : a.element] = 1;
  else if (bond === 'volatile') {
    const overcomer = overcomesTarget(a.element) === b.element ? a : b;
    const overcome = overcomer === a ? b : a;
    elementOdds[overcomer.element] = F.volatileOvercomerWeight;
    elementOdds[overcome.element] = 1 - F.volatileOvercomerWeight;
    mutationChance += F.volatileMutationChance;
  } else {
    elementOdds[a.element] = F.otherPairWeights[0];
    elementOdds[b.element] = (elementOdds[b.element] || 0) + F.otherPairWeights[1];
  }
  mutationChance = Math.min(1, mutationChance);

  const typeOdds = {};
  if (a.type === b.type) typeOdds[a.type] = 1;
  else {
    const rarer = rarerParent(a, b);
    const w = rarer ? F.typeRarerParentWeight : 0.5;
    const first = rarer || a, second = first === a ? b : a;
    typeOdds[first.type] = w;
    typeOdds[second.type] = 1 - w;
  }

  const cls = CLASS_RECIPES[a.cls]?.[b.cls] || a.cls;
  const upgradeBonus = fusionMods(a, b).upgradeBonus
    + classCount(a, b, 'seer') * CONFIG.classes.seer.fusionUpgradeBonus
    + (bond === 'volatile' ? F.volatileUpgradeBonus : 0);
  const statMult = bond === 'feeds' ? 1 + F.feedStatBonus
    : bond === 'volatile' ? 1 + F.volatileStatBonus : 1;
  return { bond, elementOdds, mutationChance, typeOdds, cls, upgradeBonus, statMult };
}

/** Pick a key from {key: p} with one rng draw (keys in insertion order). */
function rollOdds(rng, odds) {
  const r = rng();
  let acc = 0;
  const keys = Object.keys(odds);
  for (const k of keys) { acc += odds[k]; if (r < acc) return k; }
  return keys[keys.length - 1];
}

/**
 * The deterministic core: compute the child from parents + seed, one axis at
 * a time (element → type → class → rarity → stats). Pure function of its
 * inputs — every die is drawn from mulberry32(childSeed), in a fixed order.
 */
export function computeChild(a, b, childSeed) {
  const rng = mulberry32(childSeed);
  const tier = Math.min(F.maxTier, Math.max(a.tier, b.tier) + 1);
  const odds = fusionOdds(a, b);

  // --- Element ---
  let element = rollOdds(rng, odds.elementOdds);
  let mutated = false;
  if (rng() < odds.mutationChance) {
    const outside = ELEMENT_CYCLE.filter(e => e !== a.element && e !== b.element);
    if (outside.length) { element = pick(rng, outside); mutated = true; }
  }

  // --- Type ---
  const type = rollOdds(rng, odds.typeOdds);

  // --- Class: the learnable recipe table (no dice) ---
  const cls = odds.cls;

  // --- Rarity: floor at higher parent, chance to spike (or slip) ---
  const startIdx = Math.max(R.order.indexOf(a.rarity), R.order.indexOf(b.rarity));
  const bonus = odds.upgradeBonus;
  let idx = startIdx;
  const roll = rng();
  if (roll < R.doubleUpgradeChance + bonus / 2) idx += 2;
  else if (roll < R.doubleUpgradeChance + R.upgradeChance + bonus) idx += 1;
  else if (roll > 1 - R.downgradeChance) idx -= 1;
  idx = Math.max(0, Math.min(R.order.length - 1, idx));
  const rarity = R.order[idx];

  // --- Stats: parent average ± variance, tier growth, bond bonus ---
  const inherit = (sa, sb) => {
    const avg = (sa + sb) / 2;
    const varied = avg * (1 + (rng() * 2 - 1) * F.statVariance);
    return Math.min(F.statCap, Math.max(1, Math.round(varied * (1 + F.statTierBonus * tier) * odds.statMult)));
  };
  const stats = {
    power: inherit(a.stats.power, b.stats.power),
    charm: inherit(a.stats.charm, b.stats.charm),
    vitality: inherit(a.stats.vitality, b.stats.vitality),
  };

  const child = {
    id: nextCreatureId(),
    seed: childSeed,
    element, type, cls, tier, rarity, stats,
    parents: [a.name, b.name],
    habitatId: null,
    bornAt: Date.now(),
    fusedCount: 0,
    mutated,          // flavor flag for the reveal UI
    bond: odds.bond,  // 'same' | 'feeds' | 'volatile' — reveal flavour
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
    startedAt: Date.now(),                  // persisted: progress bar survives reloads
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
  // Ancestry ledger: the only moment both consumed parents still exist in
  // full — snapshot them before the pendingFusion record is discarded.
  recordFusion(child, p.parentSnapshotA, p.parentSnapshotB);
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
    // The dex shows the best specimen seen: rarer (or deeper) wins.
    const ord = R.order;
    if (ord.indexOf(c.rarity) > ord.indexOf(entry.rarity)
      || (c.rarity === entry.rarity && c.tier > entry.tier)) {
      entry.rarity = c.rarity; entry.tier = c.tier; entry.seed = c.seed;
    }
    return false; // already known
  }
  S.discovered[sig] = {
    name: c.name, element: c.element, type: c.type, cls: c.cls,
    rarity: c.rarity, seed: c.seed, tier: c.tier,
    firstAt: Date.now(), count: 1,
  };
  // New species pay an essence bounty — exploration feeds the breeding loop.
  S.resources.essence += CONFIG.economy.discoveryEssenceBonus;
  S.counters.discoveries++;
  return true; // new discovery!
}
