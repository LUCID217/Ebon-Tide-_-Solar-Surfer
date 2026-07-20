// ============================================================================
// ui_collection.js — the Collection tab: the open-ended discovery log.
// Every species signature ever created/hatched/imported is remembered here,
// even after the creature itself is gone. Art regenerates deterministically
// from the stored seed + traits.
// ============================================================================

import { CONFIG, ELEMENTS } from './config.js';
import { S } from './state.js';
import { registerTab, mountArt, esc } from './ui.js';

registerTab('collection', render);

function render(panel) {
  const entries = Object.entries(S.discovered)
    .sort((a, b) => b[1].firstAt - a[1].firstAt);

  // Rarity + element census across discoveries — collection meta-stats.
  const byRarity = {};
  for (const [, e] of entries) byRarity[e.rarity] = (byRarity[e.rarity] || 0) + 1;
  const rarityLine = CONFIG.rarity.order
    .filter(r => byRarity[r])
    .map(r => `<span class="rarity-tag" style="--rarity:${CONFIG.rarity.colors[r]}">${r} ${byRarity[r]}</span>`)
    .join(' ');

  panel.innerHTML = `
    <div class="section row spread">
      <div>
        <h2 style="margin:0">📖 Discovery log</h2>
        <div class="dim">${entries.length} species discovered — fusion keeps the list open-ended.</div>
      </div>
      <div>${rarityLine}</div>
    </div>
    <div class="log-grid" id="log-grid">
      ${entries.length === 0 ? '<div class="dim section">Nothing discovered yet.</div>' : ''}
    </div>`;

  const grid = panel.querySelector('#log-grid');
  for (const [sig, e] of entries) {
    const el = document.createElement('div');
    el.className = 'log-entry';
    el.style.setProperty('--rarity', CONFIG.rarity.colors[e.rarity]);
    el.innerHTML = `
      <div class="art"></div>
      <div class="lname">${esc(e.name)}</div>
      <div class="lmeta">${e.elements.map(x => ELEMENTS[x]?.icon || '❓').join('')} T${e.tier} · seen ×${e.count}</div>`;
    // Rebuild a minimal creature-shaped object so the art stub can draw it.
    mountArt(el.querySelector('.art'), {
      seed: e.seed, rarity: e.rarity, elements: e.elements, archetype: e.archetype, tier: e.tier,
    });
    grid.appendChild(el);
  }
}
