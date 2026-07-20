// ============================================================================
// ui_menagerie.js — the Menagerie tab: habitats with their residents,
// collect button, per-second balance sheet, habitat upgrades/expansion,
// and the reserve pen for unplaced creatures.
// ============================================================================

import { CONFIG, ELEMENTS } from './config.js';
import { S, creaturesInHabitat, reserveCreatures, habitatCapacity } from './state.js';
import {
  totalPerSec, collectRevenue, upgradeCost, upgradeHabitat, addDecoration,
  habitatQualityMult, placeCreature, buyHabitat, nextHabitatCost,
  themedExhibitElement, sellValue, sellCreature, rebiomeCost, rebiomeHabitat,
} from './economy.js';
import {
  registerTab, creatureCard, fmt, fmtSigned, esc, toast,
  showCreatureModal, closeModal, renderResources,
} from './ui.js';
import { saveGame } from './save.js';
import { showShareModal } from './ui_share.js';

registerTab('menagerie', render);

function render(panel) {
  const { revenue, maintenance, net } = totalPerSec();
  const H = CONFIG.habitats;
  const canExpand = S.habitatOrder.length < H.maxHabitats;

  let html = `
    <div class="section row spread">
      <div>
        <div class="dim">Menagerie balance</div>
        <div class="num" style="font-size:1.05rem">
          <span class="good">+${fmt(revenue)}/s</span> ·
          <span class="bad">−${fmt(maintenance)}/s</span> ·
          net <b class="${net >= 0 ? 'good' : 'bad'}">${fmtSigned(net)}/s</b>
        </div>
      </div>
      <button id="btn-collect" class="primary" ${S.collectPool < 1 ? 'disabled' : ''}>
        🪙 Collect ${fmt(S.collectPool)}
      </button>
    </div>`;

  for (const hid of S.habitatOrder) html += habitatHtml(S.habitats[hid]);

  html += `
    <div class="section">
      <div class="row spread">
        <h2 style="margin:0">🏗️ Expand</h2>
        ${canExpand
          ? `<span class="dim">New habitat: <b class="gold num">${fmt(nextHabitatCost())}</b> 🪙</span>`
          : '<span class="dim">Maximum size reached</span>'}
      </div>
      ${canExpand ? `<div class="row" style="margin-top:8px" id="biome-buttons">
        ${CONFIG.habitats.biomes.map(b =>
          `<button data-biome="${b}">${ELEMENTS[b]?.icon || '🌾'} ${b}</button>`).join('')}
      </div>` : ''}
    </div>`;

  const reserve = reserveCreatures();
  html += `
    <div class="section">
      <h2>🎒 Reserve pen <span class="dim">(${reserve.length}) — creatures here earn nothing but still cost upkeep</span></h2>
      <div class="card-grid" id="reserve-grid">
        ${reserve.length === 0 ? '<div class="dim">Empty. Hatch eggs in the Shop or fuse in the Breeding Den.</div>' : ''}
      </div>
    </div>`;

  panel.innerHTML = html;

  // -- wire: collect
  panel.querySelector('#btn-collect')?.addEventListener('click', () => {
    const got = collectRevenue();
    if (got > 0) toast(`Collected <b class="gold">${fmt(got)}</b> 🪙 (+${CONFIG.economy.essenceTricklePerCollect} 💠)`, 'gold');
    renderResources(); render(panel);
  });

  // -- wire: habitats
  for (const hid of S.habitatOrder) wireHabitat(panel, S.habitats[hid]);

  // -- wire: expansion
  panel.querySelector('#biome-buttons')?.querySelectorAll('button').forEach(btn =>
    btn.addEventListener('click', () => {
      const res = buyHabitat(btn.dataset.biome);
      if (!res.ok) return toast(res.why, 'bad');
      toast(`Built <b>${esc(res.habitat.name)}</b>!`);
      saveGame(); renderResources(); render(panel);
    }));

  // -- wire: reserve creatures
  const grid = panel.querySelector('#reserve-grid');
  for (const c of reserve) grid.appendChild(creatureCard(c, { showNet: true, onClick: openCreature }));
}

function habitatHtml(h) {
  const residents = creaturesInHabitat(h.id);
  const cap = habitatCapacity(h);
  const biomeCol = ELEMENTS[h.biome]?.color || '#7a8a5a';
  const up = h.level < CONFIG.habitats.maxLevel
    ? `<button class="hb-upgrade" data-h="${h.id}">⬆️ Lv.${h.level + 1} — ${fmt(upgradeCost(h))} 🪙</button>` : '<span class="dim">Max level</span>';
  const dec = h.decorations < CONFIG.habitats.maxDecorations
    ? `<button class="hb-decor" data-h="${h.id}">🌸 Decorate — ${fmt(CONFIG.habitats.decorationCost)} 🪙</button>` : '';
  const rebiome = `<select class="hb-rebiome" data-h="${h.id}" title="Convert biome — ${fmt(rebiomeCost(h))} 🪙 (keeps upgrades)">
    <option value="">🔁 biome…</option>
    ${CONFIG.habitats.biomes.filter(b => b !== h.biome).map(b =>
      `<option value="${b}">${ELEMENTS[b]?.icon || '🌾'} ${b} — ${fmt(rebiomeCost(h))} 🪙</option>`).join('')}
  </select>`;
  return `
    <div class="habitat" style="--biome:${biomeCol}" data-habitat="${h.id}">
      <div class="habitat-head">
        <h3>${ELEMENTS[h.biome]?.icon || '🌾'} ${esc(h.name)}</h3>
        <span class="dim">Lv.${h.level} · ×${habitatQualityMult(h).toFixed(2)} quality ·
          ${residents.length}/${cap} slots${h.decorations ? ' · ' + '🌸'.repeat(h.decorations) : ''}</span>
        ${themedExhibitElement(h.id)
          ? `<span class="gold" title="All residents share an element: +${Math.round(CONFIG.habitats.themedExhibitBonus * 100)}% habitat revenue">
              ${ELEMENTS[themedExhibitElement(h.id)]?.icon || ''} themed exhibit!</span>` : ''}
        <span style="flex:1"></span>
        ${up} ${dec} ${rebiome}
      </div>
      <div class="habitat-slots"></div>
    </div>`;
}

function wireHabitat(panel, h) {
  const root = panel.querySelector(`[data-habitat="${h.id}"]`);
  if (!root) return;
  const slots = root.querySelector('.habitat-slots');
  const residents = creaturesInHabitat(h.id);
  for (const c of residents) slots.appendChild(creatureCard(c, { showNet: true, onClick: openCreature }));
  const cap = habitatCapacity(h);
  for (let i = residents.length; i < cap; i++) {
    const empty = document.createElement('div');
    empty.className = 'slot-empty';
    empty.textContent = 'empty slot';
    slots.appendChild(empty);
  }
  root.querySelector('.hb-upgrade')?.addEventListener('click', () => {
    const res = upgradeHabitat(h);
    if (!res.ok) return toast(res.why, 'bad');
    toast(`${esc(h.name)} upgraded to Lv.${h.level}!`);
    saveGame(); renderResources();
  });
  root.querySelector('.hb-decor')?.addEventListener('click', () => {
    const res = addDecoration(h);
    if (!res.ok) return toast(res.why, 'bad');
    toast(`Decoration added to ${esc(h.name)} 🌸`);
    saveGame(); renderResources();
  });
  root.querySelector('.hb-rebiome')?.addEventListener('change', e => {
    const biome = e.target.value;
    if (!biome) return;
    e.target.value = '';
    const res = rebiomeHabitat(h, biome);
    if (!res.ok) return toast(res.why, 'bad');
    toast(`Converted to ${esc(h.name)} ${ELEMENTS[biome]?.icon || ''}`);
    saveGame(); renderResources();
  });
}

/** Creature modal with a "move to habitat" action row. */
function openCreature(c) {
  const options = S.habitatOrder.map(hid => {
    const h = S.habitats[hid];
    const full = creaturesInHabitat(hid).length >= habitatCapacity(h);
    return `<option value="${hid}" ${hid === c.habitatId ? 'selected' : ''} ${full && hid !== c.habitatId ? 'disabled' : ''}>
      ${ELEMENTS[h.biome]?.icon || '🌾'} ${esc(h.name)}${full && hid !== c.habitatId ? ' (full)' : ''}</option>`;
  }).join('');
  const extra = `
    <div class="row">
      <label class="dim">Home:</label>
      <select id="move-select">
        <option value="" ${c.habitatId === null ? 'selected' : ''}>🎒 Reserve pen</option>
        ${options}
      </select>
      <button id="btn-share" class="ghost" title="Export as a share string">📤 Share</button>
      <button id="btn-release" class="ghost bad" title="Retire this creature for coins">💰 Sell ${fmt(sellValue(c))}</button>
    </div>
    <div class="dim" style="margin-top:6px">Tip: creatures are happiest in habitats matching their element.</div>`;
  showCreatureModal(c, extra, m => {
    m.querySelector('#move-select').addEventListener('change', e => {
      const target = e.target.value === '' ? null : e.target.value;
      const res = placeCreature(c, target);
      if (!res.ok) return toast(res.why, 'bad');
      toast(target ? `${esc(c.name)} moved in.` : `${esc(c.name)} sent to reserve.`);
      saveGame(); closeModal();
    });
    m.querySelector('#btn-share').addEventListener('click', () => showShareModal(c));
    m.querySelector('#btn-release').addEventListener('click', () => {
      if (!confirm(`Sell ${c.name} for ${fmt(sellValue(c))} coins? This is permanent.`)) return;
      const res = sellCreature(c);
      if (!res.ok) return toast(res.why, 'bad');
      toast(`${esc(c.name)} retired to a loving farm. <b class="gold">+${fmt(res.value)}</b> 🪙`, 'gold');
      saveGame(); renderResources(); closeModal();
    });
  });
}
