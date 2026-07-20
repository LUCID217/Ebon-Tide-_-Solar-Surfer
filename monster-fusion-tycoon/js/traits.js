// ============================================================================
// traits.js — passive creature traits: the roster-management puzzle.
//
// Boons make a creature (or its habitat-mates) stronger; burdens make it
// expensive or antisocial. Legendary+ creatures ALWAYS carry a burden next to
// their boon, so the strongest monsters are net-NEGATIVE unless placed and
// supported deliberately. All numbers live in CONFIG.traits.
//
// Effect hooks (consumed by economy.js and fusion.js):
//   ownRevenueMult / ownMaintMult          — self multipliers
//   habitatRevenueMult / habitatHappiness  — aura on OTHERS in same habitat
//   fusionUpgradeBonus / fusionCostMult    — apply when this creature is a parent
// ============================================================================

import { CONFIG } from './config.js';
import { mulberry32 } from './rng.js';
import { S, creaturesInHabitat } from './state.js';

// key -> definition. `boon: true` = positive; burdens are the tax on power.
export const TRAITS = {
  // --- Boons ---
  prodigy:    { boon: true,  icon: '🌟', name: 'Prodigy',     desc: '+50% own revenue.',                          ownRevenueMult: 1.5 },
  frugal:     { boon: true,  icon: '🍃', name: 'Frugal',      desc: '−40% own maintenance.',                      ownMaintMult: 0.6 },
  gildedAura: { boon: true,  icon: '✨', name: 'Gilded Aura', desc: '+25% revenue to habitat-mates.',             habitatRevenueMult: 1.25 },
  muse:       { boon: true,  icon: '🎶', name: 'Muse',        desc: '+15 happiness to habitat-mates.',            habitatHappiness: 15 },
  prismHeart: { boon: true,  icon: '💎', name: 'Prism Heart', desc: '+15% rarity-upgrade chance as a parent.',    fusionUpgradeBonus: 0.15 },
  fertile:    { boon: true,  icon: '🌱', name: 'Fertile',     desc: '−30% fusion cost as a parent.',              fusionCostMult: 0.7 },
  // --- Burdens ---
  ravenous:   { boon: false, icon: '🍖', name: 'Ravenous',    desc: '×1.8 own maintenance.',                      ownMaintMult: 1.8 },
  tyrant:     { boon: false, icon: '👑', name: 'Tyrant',      desc: '−12 happiness to habitat-mates, +30% own revenue.', habitatHappiness: -12, ownRevenueMult: 1.3 },
  fragile:    { boon: false, icon: '🥀', name: 'Fragile',     desc: 'Own revenue −25%.',                          ownRevenueMult: 0.75 },
  hoarder:    { boon: false, icon: '🪙', name: 'Hoarder',     desc: '−15% revenue from habitat-mates.',           habitatRevenueMult: 0.85 },
};

const BOON_KEYS = Object.keys(TRAITS).filter(k => TRAITS[k].boon);
const BURDEN_KEYS = Object.keys(TRAITS).filter(k => !TRAITS[k].boon);

/**
 * Roll traits for a creature, deterministically from its seed.
 * Counts come from CONFIG.traits.countsByRarity: [boons, burdens].
 * Called at creation time (base creatures AND fusion children).
 */
export function rollTraits(creature) {
  const [nBoons, nBurdens] = CONFIG.traits.countsByRarity[creature.rarity] || [0, 0];
  const rng = mulberry32(creature.seed ^ 0x7247);
  const take = (pool, n) => {
    const bag = [...pool], out = [];
    while (out.length < n && bag.length) out.push(bag.splice(Math.floor(rng() * bag.length), 1)[0]);
    return out;
  };
  return [...take(BOON_KEYS, nBoons), ...take(BURDEN_KEYS, nBurdens)];
}

/** Safe accessor — old saves may predate traits. */
export function traitsOf(c) {
  return (c.traits || []).map(k => TRAITS[k]).filter(Boolean);
}

// --- Aggregated effect queries (the only API economy/fusion should use) ------

/** Own multipliers from the creature's own traits: { revenue, maint }. */
export function ownMults(c) {
  let revenue = 1, maint = 1;
  for (const t of traitsOf(c)) {
    revenue *= t.ownRevenueMult ?? 1;
    maint *= t.ownMaintMult ?? 1;
  }
  return { revenue, maint };
}

/**
 * Aura effects ON creature c FROM its habitat-mates: { revenueMult, happiness }.
 * A creature's aura affects others, never itself.
 */
export function auraOn(c) {
  let revenueMult = 1, happiness = 0;
  if (c.habitatId === null) return { revenueMult, happiness };
  for (const mate of creaturesInHabitat(c.habitatId)) {
    if (mate.id === c.id) continue;
    for (const t of traitsOf(mate)) {
      revenueMult *= t.habitatRevenueMult ?? 1;
      happiness += t.habitatHappiness ?? 0;
    }
  }
  return { revenueMult, happiness };
}

/** Fusion modifiers from a parent pair: { upgradeBonus, costMult }. */
export function fusionMods(a, b) {
  let upgradeBonus = 0, costMult = 1;
  for (const p of [a, b]) {
    for (const t of traitsOf(p)) {
      upgradeBonus += t.fusionUpgradeBonus ?? 0;
      costMult *= t.fusionCostMult ?? 1;
    }
  }
  return { upgradeBonus, costMult };
}

/** UI chip line for a creature's traits. */
export function traitChips(c) {
  return traitsOf(c).map(t =>
    `<span title="${t.desc}" style="cursor:help">${t.icon}</span>`).join('');
}
