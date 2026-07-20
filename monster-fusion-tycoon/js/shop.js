// ============================================================================
// shop.js — exchange shop logic: eggs, resource conversion, staff upgrades.
// All prices live in CONFIG.shop. UI is in ui_shop.js.
// ============================================================================

import { CONFIG } from './config.js';
import { S, spend } from './state.js';
import { makeBaseCreature } from './creature.js';
import { registerDiscovery } from './fusion.js';

const SH = CONFIG.shop;

/** Current egg price — creeps up with every egg ever bought (soft cap). */
export function eggPrice() {
  return Math.round(SH.eggCostCoins * Math.pow(SH.eggCostGrowth, S.counters.eggsBought));
}

/** Buy a base egg → hatches instantly into a random tier-1 creature (reserve). */
export function buyEgg(element = null) {
  if (!spend({ coins: eggPrice() })) return { ok: false, why: 'Not enough coins.' };
  S.counters.eggsBought++;
  const c = makeBaseCreature({ element });
  S.creatures[c.id] = c;
  const isNew = registerDiscovery(c);
  return { ok: true, creature: c, isNew };
}

// --- Resource exchange (all rates deliberately lossy round-trip) -------------

export function sellEssence(n = 1) {
  if (S.resources.essence < n) return { ok: false, why: 'Not enough essence.' };
  S.resources.essence -= n;
  S.resources.coins += SH.coinsPerEssence * n;
  return { ok: true };
}

export function buyEssence(n = 1) {
  if (!spend({ coins: SH.essenceCostCoins * n })) return { ok: false, why: 'Not enough coins.' };
  S.resources.essence += n;
  return { ok: true };
}

export function breakRelic() {
  if (S.resources.relics < 1) return { ok: false, why: 'No relics to break.' };
  S.resources.relics -= 1;
  S.resources.essence += SH.essencePerRelic;
  return { ok: true };
}

export function forgeRelic() {
  if (!spend({ essence: SH.relicCostEssence })) return { ok: false, why: 'Not enough essence.' };
  S.resources.relics += 1;
  return { ok: true };
}

// --- Staff / automation (one-time purchases) ---------------------------------

// Staff hires gate behind progression milestones — they appear in the shop
// once earned, giving the mid-game something to reach for.
export const STAFF = [
  {
    key: 'autoCollector',
    name: '🤖 Auto-Collector',
    cost: { coins: SH.autoCollectorCost },
    desc: 'A tireless clockwork attendant. Revenue is collected automatically every second (no essence trickle — hands-on keepers still profit).',
    unlock: { counter: 'collects', at: 15, label: 'Collect revenue 15 times' },
  },
  {
    key: 'groundskeeper',
    name: '🧑‍🌾 Groundskeeper',
    cost: { relics: SH.groundskeeperCost },
    desc: `A legendary caretaker. +${SH.groundskeeperHappiness} happiness to every creature, forever.`,
    unlock: { counter: 'discoveries', at: 8, label: 'Discover 8 species' },
  },
  {
    key: 'fusionRitualist',
    name: '🧙 Fusion Ritualist',
    cost: { relics: SH.fusionRitualistCost },
    desc: `A robed specialist of the den. Fusion rituals complete ${SH.fusionRitualistSpeed}× faster.`,
    unlock: { counter: 'fusions', at: 10, label: 'Perform 10 fusions' },
  },
];

/** Is this staff member available to hire yet? */
export function staffUnlocked(item) {
  if (!item.unlock) return true;
  return (S.counters[item.unlock.counter] || 0) >= item.unlock.at;
}

export function hireStaff(key) {
  const item = STAFF.find(s => s.key === key);
  if (!item) return { ok: false, why: 'Unknown staff.' };
  if (S.upgrades[key]) return { ok: false, why: 'Already hired.' };
  if (!staffUnlocked(item)) return { ok: false, why: `Locked — ${item.unlock.label} first.` };
  if (!spend(item.cost)) return { ok: false, why: 'Not enough resources.' };
  S.upgrades[key] = true;
  return { ok: true, item };
}
