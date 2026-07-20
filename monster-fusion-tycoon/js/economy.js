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
import { ownMults, auraOn } from './traits.js';

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
  S.counters.habitatUpgrades++;
  return { ok: true };
}

/** Convert a habitat's biome (keeps level/decorations). Cost scales with level. */
export function rebiomeCost(h) {
  return H.rebiomeCostPerLevel * h.level;
}

export function rebiomeHabitat(h, biome) {
  if (!H.biomes.includes(biome)) return { ok: false, why: 'Unknown biome.' };
  if (biome === h.biome) return { ok: false, why: 'Already that biome.' };
  if (!spend({ coins: rebiomeCost(h) })) return { ok: false, why: 'Not enough coins.' };
  h.biome = biome;
  h.name = BIOME_NAMES[biome] || biome;
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

/**
 * Themed exhibit: 2+ residents who ALL share at least one element earn a
 * habitat-wide revenue bonus. Rewards curated placement over dumping.
 * Returns the shared element key, or null.
 */
export function themedExhibitElement(habitatId) {
  const residents = creaturesInHabitat(habitatId);
  if (residents.length < 2) return null;
  let shared = [...residents[0].elements];
  for (const c of residents.slice(1)) {
    shared = shared.filter(e => c.elements.includes(e));
    if (!shared.length) return null;
  }
  return shared[0];
}

/** Coins received for selling/retiring a creature (rarity + tier scaled). */
export function sellValue(c) {
  return E.sellValueByRarity[c.rarity] + E.sellValuePerTier * (c.tier - 1);
}

export function sellCreature(c) {
  if (!S.creatures[c.id]) return { ok: false, why: 'Already gone.' };
  const value = sellValue(c);
  delete S.creatures[c.id];
  earnCoins(value);
  return { ok: true, value };
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
 * Happiness breakdown — the explainable version. Returns
 * { total, parts: [[label, amount], …] } where parts list every contributor.
 * This is the single source of truth; happinessOf() just takes the total.
 * Reserve creatures pin to 0 (they're in a holding pen, not an exhibit).
 */
export function happinessBreakdown(c) {
  if (c.habitatId === null || !S.habitats[c.habitatId]) {
    return { total: 0, parts: [['In reserve pen — not on exhibit', 0]] };
  }
  const h = S.habitats[c.habitatId];
  const parts = [['Base contentment', E.happinessBase]];
  parts.push(c.elements.includes(h.biome)
    ? [`Biome match (${h.biome})`, E.happinessElementMatch]
    : [`No biome match (wants ${c.elements.join('/')})`, 0]);
  parts.push(['Charm', Math.round(c.stats.charm * E.happinessCharmFactor)]);
  if (h.decorations) parts.push([`Decorations ×${h.decorations}`, h.decorations * E.happinessDecorPer]);
  if (S.upgrades.groundskeeper) parts.push(['Groundskeeper', CONFIG.shop.groundskeeperHappiness]);
  const fill = creaturesInHabitat(c.habitatId).length / habitatCapacity(h);
  const crowd = Math.round(E.happinessCrowdPenalty * Math.max(0, (fill - 0.5) * 2));
  if (crowd) parts.push(['Crowded habitat', -crowd]);
  const aura = auraOn(c).happiness;
  if (aura) parts.push(['Habitat-mates’ auras', aura]);
  const own = ownMults(c).happiness;
  if (own) parts.push(['Own trait (biome bonus)', own]);
  const total = Math.max(0, Math.min(100, Math.round(parts.reduce((s, [, v]) => s + v, 0))));
  return { total, parts };
}

/** Happiness 0..100 (see happinessBreakdown for the why). */
export function happinessOf(c) {
  return happinessBreakdown(c).total;
}

// --- Per-creature net income (also used by UI to show the balance sheet) -----

/** Coins/sec this creature earns after happiness + habitat quality + traits
 *  (own multipliers and habitat-mates' auras). 0 if reserve/unhappy. */
export function revenuePerSec(c) {
  if (c.habitatId === null) return 0;
  const hp = happinessOf(c);
  if (hp < E.unhappyThreshold) return 0; // sulking: earns nothing, still costs upkeep
  const h = S.habitats[c.habitatId];
  const themed = themedExhibitElement(c.habitatId) ? 1 + H.themedExhibitBonus : 1;
  return baseRevenuePerSec(c)
    * Math.pow(hp / 100, E.happinessRevenueCurve)
    * habitatQualityMult(h)
    * themed
    * ownMults(c).revenue
    * auraOn(c).revenueMult;
}

/** Coins/sec upkeep after trait multipliers (Ravenous, Frugal…). Always charged. */
export function upkeepPerSec(c) {
  return maintenancePerSec(c) * ownMults(c).maint;
}

/** Full breakdown for the UI: { revenue, maintenance, net } per second. */
export function incomeBreakdown(c) {
  const revenue = revenuePerSec(c);
  const maintenance = upkeepPerSec(c);
  return { revenue, maintenance, net: revenue - maintenance };
}

/**
 * Money doctor: if this creature is costing the player, return a short
 * human-readable diagnosis (string) — else null. Drives the menagerie advisor.
 */
export function moneyIssueOf(c) {
  const { revenue, maintenance, net } = incomeBreakdown(c);
  if (c.habitatId === null) {
    return maintenance > 0
      ? `sits in the reserve pen paying ${maintenance.toFixed(1)}/s upkeep and earning nothing — place it in a habitat or sell it`
      : null; // free-to-keep commons can idle in reserve harmlessly
  }
  const hb = happinessBreakdown(c);
  if (hb.total < E.unhappyThreshold) {
    const worst = hb.parts.filter(([, v]) => v < 0).sort((a, b) => a[1] - b[1])[0];
    const missing = hb.parts.find(([label]) => label.startsWith('No biome match'));
    const cause = worst ? worst[0].toLowerCase() : (missing ? missing[0].toLowerCase() : 'low happiness');
    return `is sulking (happiness ${hb.total} < ${E.unhappyThreshold}): earns NOTHING but still bills upkeep — main cause: ${cause}`;
  }
  if (net < 0) {
    return `runs at a loss (${revenue.toFixed(1)}/s earned vs ${maintenance.toFixed(1)}/s upkeep) — try a matching biome, decorations, or sell it`;
  }
  return null;
}

/** Menagerie-wide totals per second. */
export function totalPerSec() {
  let revenue = 0, maintenance = 0;
  for (const c of Object.values(S.creatures)) {
    revenue += revenuePerSec(c);
    maintenance += upkeepPerSec(c);
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
