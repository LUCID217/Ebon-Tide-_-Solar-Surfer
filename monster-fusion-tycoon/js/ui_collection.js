// ============================================================================
// ui_collection.js — the Collection tab: the open-ended discovery log.
// Every species signature ever created/hatched/imported is remembered here,
// even after the creature itself is gone. Art regenerates deterministically
// from the stored seed + traits.
// ============================================================================

import { CONFIG, ELEMENTS, ELEMENT_CYCLE, TYPE_KEYS, TYPES, CLASS_KEYS, CLASSES } from './config.js';
import { S } from './state.js';
import { registerTab, mountArt, esc } from './ui.js';
import { tryImportString } from './ui_share.js';
import { speciesName, speciesSignature } from './creature.js';

registerTab('collection', render);

// v5: the collection is a finite dex — 5 elements × 5 bodies × 5 classes =
// 125 slots in canonical order. Undiscovered slots show as ??? silhouettes.
// (Secret recipes, a later pass, will add hidden "???" slots beyond these.)
const ALL_SPECIES = [];
for (const element of ELEMENT_CYCLE) for (const type of TYPE_KEYS) for (const cls of CLASS_KEYS) {
  ALL_SPECIES.push({ element, type, cls });
}
export const DEX_SIZE = ALL_SPECIES.length;

// Tab-local filter state (UI only, not saved).
let logFilterEl = '';     // '' = all elements
let logFilterRarity = ''; // '' = any (a rarity hides undiscovered slots)
let showMissing = true;   // show ??? slots
let lastKey = '';         // skip re-rendering when nothing visible changed

function render(panel) {
  const disc = S.discovered;
  const found = Object.keys(disc).length;
  const key = [found, Object.values(disc).reduce((n, e) => n + (e.count || 0), 0),
    logFilterEl, logFilterRarity, showMissing].join('|');
  if (key === lastKey && panel.querySelector('#log-grid')) return;
  lastKey = key;

  let slots = ALL_SPECIES.map(sp => ({ sp, sig: speciesSignature(sp), e: disc[speciesSignature(sp)] }));
  if (logFilterEl) slots = slots.filter(x => x.sp.element === logFilterEl);
  if (logFilterRarity) slots = slots.filter(x => x.e && x.e.rarity === logFilterRarity);
  if (!showMissing) slots = slots.filter(x => x.e);

  // Per-element completion — the collector's to-do list.
  const perEl = ELEMENT_CYCLE.map(el => {
    const n = ALL_SPECIES.filter(sp => sp.element === el && disc[speciesSignature(sp)]).length;
    return `<span class="rarity-tag" style="--rarity:${ELEMENTS[el].color}">${ELEMENTS[el].icon} ${n}/25</span>`;
  }).join(' ');

  panel.innerHTML = `
    <div class="section row spread">
      <div>
        <h2 style="margin:0">📖 Species dex</h2>
        <div class="dim"><b class="num" style="color:var(--text)">${found}</b> / ${DEX_SIZE} species discovered</div>
      </div>
      <div>${perEl}</div>
    </div>
    <div class="section row">
      <select id="log-el">
        <option value="">All elements</option>
        ${Object.entries(ELEMENTS).map(([k, e]) => `<option value="${k}" ${logFilterEl === k ? 'selected' : ''}>${e.icon} ${e.label}</option>`).join('')}
      </select>
      <select id="log-rar">
        <option value="">Any rarity</option>
        ${CONFIG.rarity.order.map(r => `<option value="${r}" ${logFilterRarity === r ? 'selected' : ''}>${r}</option>`).join('')}
      </select>
      <label class="dim"><input type="checkbox" id="log-missing" ${showMissing ? 'checked' : ''}> show undiscovered</label>
      <span class="dim">${slots.length} shown</span>
    </div>
    <div class="section">
      <h3>📥 Import a shared creature</h3>
      <div class="row">
        <input type="text" id="import-box" placeholder="Paste an MFT2.… share string or URL" style="flex:1;min-width:200px">
        <button id="import-btn" class="primary">View</button>
      </div>
    </div>
    <div class="log-grid" id="log-grid">
      ${slots.length === 0 ? '<div class="dim section">Nothing here yet.</div>' : ''}
    </div>`;

  const sel = (id, fn) => panel.querySelector('#' + id).addEventListener('change', e => { fn(e.target); render(panel); });
  sel('log-el', t => logFilterEl = t.value);
  sel('log-rar', t => logFilterRarity = t.value);
  sel('log-missing', t => showMissing = t.checked);

  const doImport = () => tryImportString(panel.querySelector('#import-box').value);
  panel.querySelector('#import-btn').addEventListener('click', doImport);
  panel.querySelector('#import-box').addEventListener('keydown', e => { if (e.key === 'Enter') doImport(); });

  const grid = panel.querySelector('#log-grid');
  for (const { sp, e } of slots) {
    const el = document.createElement('div');
    el.className = 'log-entry' + (e ? '' : ' missing');
    if (!e) {
      // Undiscovered: show the element + body as a hint, hide the class.
      el.innerHTML = `
        <div class="art dex-unknown">?</div>
        <div class="lname">???</div>
        <div class="lmeta">${ELEMENTS[sp.element].icon}${TYPES[sp.type].icon} ·
          <span title="Class unknown">❔</span></div>`;
      grid.appendChild(el);
      continue;
    }
    el.style.setProperty('--rarity', CONFIG.rarity.colors[e.rarity]);
    el.innerHTML = `
      <div class="art"></div>
      <div class="lname">${esc(speciesName(sp))}</div>
      <div class="lmeta">${ELEMENTS[sp.element].icon}${TYPES[sp.type].icon}${CLASSES[sp.cls].icon} · best ${e.rarity} T${e.tier} · ×${e.count}</div>`;
    // Rebuild a minimal creature-shaped object so the art stub can draw it.
    mountArt(el.querySelector('.art'), { seed: e.seed, rarity: e.rarity, tier: e.tier, ...sp });
    grid.appendChild(el);
  }
}
