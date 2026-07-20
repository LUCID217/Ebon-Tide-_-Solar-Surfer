// ============================================================================
// economy.js — the tycoon heart: habitats, happiness, passive revenue,
// maintenance drain, upgrades, expansion, offline progress.
//
// Design intent (see CONFIG.economy):
//  - Creatures only earn while placed in a habitat, and only if happy enough.
//  - Maintenance is charged ALWAYS (even for miserable or reserve creatures),
//    so high-rarity monsters are a genuine liability when mismanaged.
//  - Revenue accrues into S.collectPool; the player manually collects (grind
//    loop + essence trickle) unless they've bought the Auto-Collector.
// ============================================================================

import { CONFIG } from './config.js';
import { S, creaturesInHabitat, habitatCapacity, earnCoins, spend } from './state.js';
import { baseRevenuePerSec, maintenancePerSec } from './creature.js';

const E = CONFIG.economy;
const H = CONFIG.habitats;

let habitatIdCounter = 1;

// --- Habitats ----------------------------------------------------------------

const BIOME_NAMES = {
  meadow: 'Meadow Pen', fire: 'Ember Ridge', water: 'Tidal Cove', earth: 'Stone Hollow',
  air: 'Skyloft Roost', nature: 'Verdant Grove', shadow: 'Gloom Warren', light: 'Dawn Terrace',
  storm: 'Tempest Spire',
};

export function makeHabitat(biome) {
  const id = `h${habitatIdCounter++}`;
  return { id, biome, level: 1, decorations: 0, name: BIOME_NAMES[biome] || biome };
}

/** Called once on new game: the starter habitat. */
export function ensureStarterHabitat() {
  if (S.habitatOrder.length > 0) {
    // Re-sync the id counter after a load so new ids never collide.
    for (const id of S.habitatOrder) {
      const n = parseInt(id.slice(1), 10);
      if (!Number.isNaN(n)) habitatIdCounter = Math.max(habitatIdCounter, n + 1);
    }
    return;
  }
  const h = makeHabitat('meadow');
  S.habitats[h.id] = h;
  S.habitatOrder.push(h.id);
}

/** Cost of the NEXT new habitat (exponential expansion wall). */
export function nextHabitatCost() {
  const owned = S.habitatOrder.length;
  return Math.round(H.newHabitatBaseCost * Math.pow(H.newHabitatCostGrowth, owned - 1));
}

export function buyHabitat(biome) {
  if (S.habitatOrder.length >= H.maxHabitats) return { ok: false, why: 'Menagerie is at maximum size.' };
  const cost = { coins: nextHabitatCost() };
  if (!spend(cost)) return { ok: false, why: 'Not enough coins.' };
  const h = makeHabitat(biome);
  S.habitats[h.id] = h;
  S.habitatOrder.push(h.id);
  S.counters.habitatsBuilt++;
  return { ok: true, habitat: h };
}

export function upgradeCost(h) {
  return Math.round(H.upgradeBaseCost * Math.pow(H.upgradeCostGrowth, h.level - 1));
}

export function upgradeHabitat(h) {
  if (h.level >= H.maxLevel) return { ok: false, why: 'Already at max level.' };
  if (!spend({ coins: upgradeCost(h) })) return { ok: false, why: 'Not enough coins.' };
  h.level++;
  return { ok: true };
}

export function addDecoration(h) {
  if (h.decorations >= H.maxDecorations) return { ok: false, why: 'No decoration slots left.' };
  if (!spend({ coins: H.decorationCost })) return { ok: false, why: 'Not enough coins.' };
  h.decorations++;
  return { ok: true };
}

/** Habitat revenue multiplier from its upgrade level. */
export function habitatQualityMult(h) {
  return H.baseQualityMult + (h.level - 1) * H.qualityPerLevel;
}

/** Move a creature into a habitat (or null → reserve). Enforces capacity. */
export function placeCreature(creature, habitatId) {
  if (habitatId !== null) {
    const h = S.habitats[habitatId];
    if (!h) return { ok: false, why: 'No such habitat.' };
    if (creaturesInHabitat(habitatId).length >= habitatCapacity(h)) {
      return { ok: false, why: `${h.name} is full.` };
    }
  }
  creature.habitatId = habitatId;
  return { ok: true };
}

// --- Happiness ---------------------------------------------------------------

/**
 * Happiness 0..100, recomputed live (not stored): base + element/biome match
 * + charm + decorations + groundskeeper − crowding. Reserve creatures pin to 0.
 */
export function happinessOf(c) {
  if (c.habitatId === null) return 0;
  const h = S.habitats[c.habitatId];
  if (!h) return 0;
  let hp = E.happinessBase;
  if (c.elements.includes(h.biome)) hp += E.happinessElementMatch;
  hp += c.stats.charm * E.happinessCharmFactor;
  hp += h.decorations * E.happinessDecorPer;
  if (S.upgrades.groundskeeper) hp += CONFIG.shop.groundskeeperHappiness;
  const cap = habitatCapacity(h);
  const fill = creaturesInHabitat(c.habitatId).length / cap;
  hp -= E.happinessCrowdPenalty * Math.max(0, (fill - 0.5) * 2); // penalty ramps in above half-full
  return Math.max(0, Math.min(100, Math.round(hp)));
}

// --- Per-creature net income (also used by UI to show the balance sheet) -----

/** Coins/sec this creature earns after happiness + habitat quality (0 if reserve/unhappy). */
export function revenuePerSec(c) {
  if (c.habitatId === null) return 0;
  const hp = happinessOf(c);
  if (hp < E.unhappyThreshold) return 0; // sulking: earns nothing, still costs upkeep
  const h = S.habitats[c.habitatId];
  return baseRevenuePerSec(c) * Math.pow(hp / 100, E.happinessRevenueCurve) * habitatQualityMult(h);
}

/** Full breakdown for the UI: { revenue, maintenance, net } per second. */
export function incomeBreakdown(c) {
  const revenue = revenuePerSec(c);
  const maintenance = maintenancePerSec(c);
  return { revenue, maintenance, net: revenue - maintenance };
}

/** Menagerie-wide totals per second. */
export function totalPerSec() {
  let revenue = 0, maintenance = 0;
  for (const c of Object.values(S.creatures)) {
    revenue += revenuePerSec(c);
    maintenance += maintenancePerSec(c);
  }
  return { revenue, maintenance, net: revenue - maintenance };
}

// --- The tick ----------------------------------------------------------------

/**
 * Advance the economy by dt seconds. Revenue accrues to the collect pool
 * (capped); maintenance drains coins directly (can push you toward zero —
 * that's the pressure that makes roster choices matter). Coins floor at 0:
 * we don't do debt, the punishment is stalled progress.
 */
export function economyTick(dt) {
  const { revenue, maintenance } = totalPerSec();
  S.collectPool = Math.min(S.collectPool + revenue * dt, revenue * E.collectCapSeconds);
  S.resources.coins = Math.max(0, S.resources.coins - maintenance * dt);
  if (S.upgrades.autoCollector && S.collectPool > 0) collectRevenue(true);
}

/** Manual collect: pool → coins, plus an essence trickle (the grind loop). */
export function collectRevenue(auto = false) {
  const amount = S.collectPool;
  if (amount <= 0) return 0;
  S.collectPool = 0;
  earnCoins(amount);
  if (!auto) {
    S.resources.essence += E.essenceTricklePerCollect;
    S.counters.collects++;
  }
  return amount;
}

/** Offline progress: simulate elapsed seconds (capped) in one coarse step. */
export function applyOfflineProgress(elapsedSec) {
  const dt = Math.min(elapsedSec, E.offlineCapSeconds);
  if (dt <= 1) return null;
  const before = { pool: S.collectPool, coins: S.resources.coins };
  economyTick(dt);
  return {
    seconds: dt,
    earned: S.collectPool - before.pool,
    drained: Math.max(0, before.coins - S.resources.coins),
  };
}
