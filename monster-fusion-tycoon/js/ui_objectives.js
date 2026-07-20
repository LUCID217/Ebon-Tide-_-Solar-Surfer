// ============================================================================
// ui_objectives.js — the Objectives tab: today's dailies + lifetime milestones.
// Claimable count also feeds a badge on the tab button (see updateBadge).
// ============================================================================

import { CONFIG } from './config.js';
import {
  ensureDailies, dailyProgress, claimDaily, milestoneList, claimMilestone, claimableCount,
} from './objectives.js';
import { S } from './state.js';
import { registerTab, fmt, toast, renderResources, renderActiveTab } from './ui.js';
import { saveGame } from './save.js';

registerTab('objectives', render);

function render(panel) {
  ensureDailies();
  const O = CONFIG.objectives;

  const dailies = S.objectives.daily.map((d, i) => {
    const prog = dailyProgress(d);
    const done = prog >= d.target;
    return `
      <div class="objective ${done ? 'done' : ''}">
        <span>${d.label}</span>
        <div class="obar"><div style="width:${(100 * prog / d.target).toFixed(0)}%"></div></div>
        <span class="num dim">${fmt(prog)}/${fmt(d.target)}</span>
        ${d.claimed
          ? '<span class="good">✅</span>'
          : done ? `<button class="primary" data-daily="${i}">Claim</button>` : ''}
      </div>`;
  }).join('');

  const ms = milestoneList().map(m => `
    <div class="objective ${m.done ? 'done' : ''}">
      <span>${m.label}</span>
      <div class="obar"><div style="width:${(100 * m.value / m.target).toFixed(0)}%"></div></div>
      <span class="num dim">${fmt(m.value)}/${fmt(m.target)}</span>
      ${m.claimed
        ? '<span class="good">✅</span>'
        : m.done ? `<button class="primary" data-milestone="${m.id}">🏺 Claim</button>` : ''}
    </div>`).join('');

  panel.innerHTML = `
    <div class="section">
      <h2>📅 Today's objectives
        <span class="dim">— reward: ${O.dailyRewardCoins} 🪙 + ${O.dailyRewardEssence} 💠 each · reset daily</span></h2>
      ${dailies}
    </div>
    <div class="section">
      <h2>🏆 Milestones <span class="dim">— each pays ${O.milestoneRelics} 🏺 relic (the only source besides forging)</span></h2>
      ${ms}
    </div>`;

  panel.querySelectorAll('button[data-daily]').forEach(b =>
    b.addEventListener('click', () => {
      const res = claimDaily(S.objectives.daily[+b.dataset.daily]);
      if (!res.ok) return toast(res.why, 'bad');
      toast(`Objective complete! +${res.coins} 🪙 +${res.essence} 💠`, 'gold');
      saveGame(); renderResources(); renderActiveTab(); updateBadge();
    }));

  panel.querySelectorAll('button[data-milestone]').forEach(b =>
    b.addEventListener('click', () => {
      const res = claimMilestone(b.dataset.milestone);
      if (!res.ok) return toast(res.why, 'bad');
      toast(`Milestone reached! +${res.relics} 🏺 relic`, 'gold');
      saveGame(); renderResources(); renderActiveTab(); updateBadge();
    }));
}

/** Show/refresh the claimable-count badge on the Objectives tab button. */
export function updateBadge() {
  const btn = document.querySelector('#tabs [data-tab="objectives"]');
  if (!btn) return;
  let badge = btn.querySelector('.badge');
  const n = claimableCount();
  if (n > 0) {
    if (!badge) {
      badge = document.createElement('span');
      badge.className = 'badge';
      btn.appendChild(badge);
    }
    badge.textContent = n;
  } else if (badge) {
    badge.remove();
  }
}
