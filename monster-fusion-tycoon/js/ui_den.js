// ============================================================================
// ui_den.js — the Breeding Den tab: pick two parents, see cost + odds flavor,
// start the fusion, watch the timer, get the dramatic reveal.
// ============================================================================

import { ELEMENTS } from './config.js';
import { S } from './state.js';
import { fusionCost, fusionTimeSec, canFuse, startFusion, tryResolveFusion } from './fusion.js';
import { spend } from './state.js';
import {
  registerTab, creatureCard, mountArt, fmt, esc, toast, renderResources,
} from './ui.js';
import { rarityColor } from './creature.js';
import { saveGame } from './save.js';

registerTab('den', render);

// Den-local selection state (not saved — it's just UI).
let pickA = null, pickB = null;
let lastRevealId = null; // creature id to show a one-time reveal animation for
let sortBy = 'newest';   // roster sort: newest | tier | rarity | power
let filterEl = '';       // roster element filter ('' = all)

const RARITY_ORDER = ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];

function sortedRoster() {
  let list = Object.values(S.creatures);
  if (filterEl) list = list.filter(c => c.elements.includes(filterEl));
  const cmp = {
    newest: (a, b) => b.bornAt - a.bornAt,
    tier: (a, b) => b.tier - a.tier,
    rarity: (a, b) => RARITY_ORDER.indexOf(b.rarity) - RARITY_ORDER.indexOf(a.rarity),
    power: (a, b) => b.stats.power - a.stats.power,
  }[sortBy];
  return list.sort(cmp);
}

function render(panel) {
  // A fusion in progress owns the whole stage.
  if (S.pendingFusion) return renderPending(panel);

  const roster = sortedRoster();
  // Drop stale picks (parent may have been consumed/released).
  if (pickA && !S.creatures[pickA]) pickA = null;
  if (pickB && !S.creatures[pickB]) pickB = null;

  const a = pickA ? S.creatures[pickA] : null;
  const b = pickB ? S.creatures[pickB] : null;

  let costHtml = '<span class="dim">Select two parents below…</span>';
  let fuseBtn = '';
  if (a && b) {
    const check = canFuse(a, b);
    if (check.ok) {
      const cost = fusionCost(a, b);
      costHtml = `Cost: <b class="gold num">${fmt(cost.coins)}</b> 🪙 +
        <b class="num" style="color:#7cc7e8">${fmt(cost.essence)}</b> 💠 ·
        ⏱️ ${Math.round(fusionTimeSec(a, b))}s
        <div class="dim" style="margin-top:4px">⚠️ Both parents are consumed by the ritual.</div>`;
      fuseBtn = `<button id="btn-fuse" class="primary">🧬 Fuse!</button>`;
    } else {
      costHtml = `<span class="bad">${check.why}</span>`;
    }
  }

  panel.innerHTML = `
    ${lastRevealId && S.creatures[lastRevealId] ? revealHtml(S.creatures[lastRevealId]) : ''}
    <div class="section">
      <h2>🥚 Breeding Den</h2>
      <div class="den-stage">
        <div class="den-slot ${a ? 'filled' : ''}" id="den-a">${a ? '' : 'Parent A'}</div>
        <div class="den-x">✕</div>
        <div class="den-slot ${b ? 'filled' : ''}" id="den-b">${b ? '' : 'Parent B'}</div>
      </div>
      <div style="text-align:center">${costHtml}<div style="margin-top:10px">${fuseBtn}</div></div>
    </div>
    <div class="section">
      <div class="row spread">
        <h3 style="margin:0">Choose parents <span class="dim">(${roster.length} creatures)</span></h3>
        <div class="row">
          <select id="den-sort" title="Sort roster">
            ${['newest', 'tier', 'rarity', 'power'].map(k =>
              `<option value="${k}" ${sortBy === k ? 'selected' : ''}>Sort: ${k}</option>`).join('')}
          </select>
          <select id="den-filter" title="Filter by element">
            <option value="">All elements</option>
            ${Object.entries(ELEMENTS).map(([k, e]) =>
              `<option value="${k}" ${filterEl === k ? 'selected' : ''}>${e.icon} ${e.label}</option>`).join('')}
          </select>
        </div>
      </div>
      <div class="card-grid" id="den-roster" style="margin-top:10px">
        ${roster.length < 2 ? '<div class="dim">You need at least two creatures — hatch eggs in the Shop.</div>' : ''}
      </div>
    </div>`;

  // Selected parents in the stage slots.
  if (a) panel.querySelector('#den-a').appendChild(creatureCard(a, { onClick: () => { pickA = null; render(panel); } }));
  if (b) panel.querySelector('#den-b').appendChild(creatureCard(b, { onClick: () => { pickB = null; render(panel); } }));

  // Roster picker.
  const grid = panel.querySelector('#den-roster');
  for (const c of roster) {
    grid.appendChild(creatureCard(c, {
      selected: c.id === pickA || c.id === pickB,
      onClick: cc => {
        if (cc.id === pickA) pickA = null;
        else if (cc.id === pickB) pickB = null;
        else if (!pickA) pickA = cc.id;
        else if (!pickB) pickB = cc.id;
        else pickB = cc.id; // both full: replace B
        render(panel);
      },
    }));
  }

  panel.querySelector('#den-sort').addEventListener('change', e => { sortBy = e.target.value; render(panel); });
  panel.querySelector('#den-filter').addEventListener('change', e => { filterEl = e.target.value; render(panel); });

  panel.querySelector('#btn-fuse')?.addEventListener('click', () => {
    const res = startFusion(pickA, pickB, spend);
    if (!res.ok) return toast(res.why, 'bad');
    pickA = pickB = null;
    lastRevealId = null;
    toast('The den begins to glow… 🔮');
    saveGame(); renderResources(); render(panel);
  });
}

function renderPending(panel) {
  const p = S.pendingFusion;
  const total = p.resolveAt - (p.startedAt ?? (p.startedAt = p.resolveAt - remainingGuess(p)));
  const remaining = Math.max(0, p.resolveAt - Date.now());
  const pct = total > 0 ? 100 * (1 - remaining / total) : 100;
  panel.innerHTML = `
    <div class="section fusion-progress">
      <h2>🔮 Fusion in progress…</h2>
      <div class="dim">${esc(p.parentSnapshotA.name)} × ${esc(p.parentSnapshotB.name)}</div>
      <div class="fusion-bar"><div style="width:${pct.toFixed(1)}%"></div></div>
      <div class="num dim">${Math.ceil(remaining / 1000)}s remaining</div>
    </div>`;
  // main.js's tick calls tryResolveFusion(); reveal happens on next render.
}

/** First render after a fusion resolves shows the newborn full-width. */
function revealHtml(c) {
  return `
    <div class="section reveal" style="text-align:center;border-color:${rarityColor(c)}">
      <div class="dim">A new creature emerges!</div>
      <div class="art-big" id="reveal-art" style="width:120px;height:120px;margin:6px auto"></div>
      <h2 style="color:${rarityColor(c)}">${esc(c.name)}</h2>
      <div class="dim">Tier ${c.tier} · ${c.rarity}${c.mutated ? ' · <span class="gold">⚡ unexpected mutation!</span>' : ''}</div>
    </div>`;
}

function remainingGuess(p) { return Math.max(1000, p.resolveAt - Date.now()); }

/** Called from the main loop when a fusion resolves, so any tab can toast it. */
export function onFusionResolved(child, isNewSpecies) {
  lastRevealId = child.id;
  toast(`🧬 <b style="color:${rarityColor(child)}">${esc(child.name)}</b> is born!` +
    (isNewSpecies ? ' <span class="gold">✦ New species discovered!</span>' : ''), 'gold');
}

// Post-reveal art mount happens after render; watch for the container.
const observer = new MutationObserver(() => {
  const el = document.getElementById('reveal-art');
  if (el && lastRevealId && S.creatures[lastRevealId] && !el.dataset.mounted) {
    el.dataset.mounted = '1';
    mountArt(el, S.creatures[lastRevealId]);
  }
});
observer.observe(document.body, { childList: true, subtree: true });
