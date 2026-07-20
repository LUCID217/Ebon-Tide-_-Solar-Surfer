// ============================================================================
// objectives.js — daily objectives + lifetime milestones.
// Dailies roll deterministically from the date; milestones read the lifetime
// counters in S.counters. Rewards come from CONFIG.objectives.
// ============================================================================

import { CONFIG } from './config.js';
import { S } from './state.js';
import { mulberry32, hashStr } from './rng.js';

const O = CONFIG.objectives;

// The pool of daily objective templates. `measure` reads live state; dailies
// store the counter baseline at roll time so progress counts from today.
const DAILY_POOL = [
  { kind: 'fuse',     label: n => `Perform ${n} fusion${n > 1 ? 's' : ''}`,        targets: [1, 2, 3], counter: 'fusions' },
  { kind: 'collect',  label: n => `Collect revenue ${n} times`,                     targets: [3, 5, 10], counter: 'collects' },
  { kind: 'egg',      label: n => `Hatch ${n} shop egg${n > 1 ? 's' : ''}`,         targets: [1, 2, 3], counter: 'eggsBought' },
  { kind: 'earn',     label: n => `Earn ${n.toLocaleString()} coins`,               targets: [500, 2000, 8000], counter: 'coinsEarned' },
];

function todayStr() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Roll (or keep) today's dailies. Call every tick — cheap when date matches. */
export function ensureDailies() {
  const today = todayStr();
  if (S.objectives.dailyDate === today) return;
  const rng = mulberry32(hashStr('daily' + today));
  // Pick dailyCount distinct templates for today.
  const pool = [...DAILY_POOL];
  const picked = [];
  while (picked.length < Math.min(O.dailyCount, pool.length)) {
    picked.push(pool.splice(Math.floor(rng() * pool.length), 1)[0]);
  }
  S.objectives.dailyDate = today;
  S.objectives.daily = picked.map((tpl, i) => {
    const target = tpl.targets[Math.floor(rng() * tpl.targets.length)];
    return {
      id: `${today}_${i}`,
      kind: tpl.kind,
      label: tpl.label(target),
      target,
      baseline: S.counters[tpl.counter],   // progress counts from today only
      counter: tpl.counter,
      claimed: false,
    };
  });
}

export function dailyProgress(d) {
  return Math.min(d.target, Math.max(0, S.counters[d.counter] - d.baseline));
}

export function claimDaily(d) {
  if (d.claimed || dailyProgress(d) < d.target) return { ok: false, why: 'Not complete yet.' };
  d.claimed = true;
  S.resources.essence += O.dailyRewardEssence;
  S.resources.coins += O.dailyRewardCoins;
  return { ok: true, essence: O.dailyRewardEssence, coins: O.dailyRewardCoins };
}

// --- Milestones (lifetime; each step pays relics — the premium material) -----

export function milestoneList() {
  const defs = [
    { key: 'fusion', label: 'Total fusions', value: S.counters.fusions, steps: O.fusionMilestones },
    { key: 'discovery', label: 'Species discovered', value: Object.keys(S.discovered).length, steps: O.discoveryMilestones },
    { key: 'coins', label: 'Lifetime coins earned', value: Math.floor(S.counters.coinsEarned), steps: O.coinMilestones },
  ];
  const list = [];
  for (const def of defs) {
    for (const step of def.steps) {
      const id = `${def.key}_${step}`;
      list.push({
        id, label: `${def.label}: ${step.toLocaleString()}`,
        value: Math.min(def.value, step), target: step,
        done: def.value >= step,
        claimed: !!S.objectives.milestonesClaimed[id],
      });
    }
  }
  return list;
}

export function claimMilestone(id) {
  const m = milestoneList().find(x => x.id === id);
  if (!m || !m.done || m.claimed) return { ok: false, why: 'Not ready.' };
  S.objectives.milestonesClaimed[id] = true;
  S.resources.relics += O.milestoneRelics;
  return { ok: true, relics: O.milestoneRelics };
}

/** Count of claimable things — drives the tab badge. */
export function claimableCount() {
  ensureDailies();
  let n = S.objectives.daily.filter(d => !d.claimed && dailyProgress(d) >= d.target).length;
  n += milestoneList().filter(m => m.done && !m.claimed).length;
  return n;
}
