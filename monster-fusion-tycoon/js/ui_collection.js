// ============================================================================
// ui_collection.js — the Collection tab: the open-ended discovery log.
// Every species signature ever created/hatched/imported is remembered here,
// even after the creature itself is gone. Art regenerates deterministically
// from the stored seed + traits.
// ============================================================================

import { CONFIG, ELEMENTS } from './config.js';
import { S } from './state.js';
import { registerTab, mountArt, esc } from './ui.js';
import { tryImportString } from './ui_share.js';

registerTab('collection', render);

// Tab-local filter/sort state (UI only, not saved).
let logSort = 'newest';   // newest | rarity | tier
let logFilterEl = '';     // '' = all elements
let logFilterRarity = ''; // '' = all rarities

function render(panel) {
  const RAR = CONFIG.rarity.order;
  let entries = Object.entries(S.discovered);
  if (logFilterEl) entries = entries.filter(([, e]) => e.elements.includes(logFilterEl));
  if (logFilterRarity) entries = entries.filter(([, e]) => e.rarity === logFilterRarity);
  entries.sort({
    newest: (a, b) => b[1].firstAt - a[1].firstAt,
    rarity: (a, b) => RAR.indexOf(b[1].rarity) - RAR.indexOf(a[1].rarity),
    tier: (a, b) => b[1].tier - a[1].tier,
  }[logSort]);

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
        <div class="dim">${Object.keys(S.discovered).length} species discovered — fusion keeps the list open-ended.</div>
      </div>
      <div>${rarityLine}</div>
    </div>
    <div class="section row">
      <select id="log-sort">
        ${['newest', 'rarity', 'tier'].map(k => `<option value="${k}" ${logSort === k ? 'selected' : ''}>Sort: ${k}</option>`).join('')}
      </select>
      <select id="log-el">
        <option value="">All elements</option>
        ${Object.entries(ELEMENTS).map(([k, e]) => `<option value="${k}" ${logFilterEl === k ? 'selected' : ''}>${e.icon} ${e.label}</option>`).join('')}
      </select>
      <select id="log-rar">
        <option value="">All rarities</option>
        ${CONFIG.rarity.order.map(r => `<option value="${r}" ${logFilterRarity === r ? 'selected' : ''}>${r}</option>`).join('')}
      </select>
      <span class="dim">${entries.length} shown</span>
    </div>
    <div class="section">
      <h3>📥 Import a shared creature</h3>
      <div class="row">
        <input type="text" id="import-box" placeholder="Paste an MFT1.… share string or URL" style="flex:1;min-width:200px">
        <button id="import-btn" class="primary">View</button>
      </div>
    </div>
    <div class="log-grid" id="log-grid">
      ${entries.length === 0 ? '<div class="dim section">Nothing discovered yet.</div>' : ''}
    </div>`;

  const sel = (id, fn) => panel.querySelector('#' + id).addEventListener('change', e => { fn(e.target.value); render(panel); });
  sel('log-sort', v => logSort = v);
  sel('log-el', v => logFilterEl = v);
  sel('log-rar', v => logFilterRarity = v);

  const doImport = () => tryImportString(panel.querySelector('#import-box').value);
  panel.querySelector('#import-btn').addEventListener('click', doImport);
  panel.querySelector('#import-box').addEventListener('keydown', e => { if (e.key === 'Enter') doImport(); });

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
