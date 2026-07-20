// ============================================================================
// ui.js — UI core: tab registry, shared widgets (creature cards, modal,
// toasts, resource bar). Per-tab renderers live in ui_*.js files and register
// themselves via registerTab(), so tabs can ship incrementally.
// ============================================================================

import { CONFIG, ELEMENTS } from './config.js';
import { S } from './state.js';
import { generateCreatureArt, silhouetteSVG } from './art.js';
import { rarityColor } from './creature.js';
import { incomeBreakdown, happinessOf } from './economy.js';
import { traitsOf, traitChips } from './traits.js';

// --- Tab registry ------------------------------------------------------------

const tabRenderers = {}; // name -> render(panelEl)
let activeTab = 'menagerie';

export function registerTab(name, renderFn) { tabRenderers[name] = renderFn; }

export function switchTab(name) {
  activeTab = name;
  document.querySelectorAll('#tabs .tab').forEach(b =>
    b.classList.toggle('active', b.dataset.tab === name));
  document.querySelectorAll('#main .panel').forEach(p =>
    p.classList.toggle('active', p.id === `tab-${name}`));
  renderActiveTab();
}

/** Re-render only the visible tab (called every UI frame — keep renderers cheap). */
export function renderActiveTab() {
  const panel = document.getElementById(`tab-${activeTab}`);
  if (!panel) return;
  // Don't clobber a text field the player is typing in (import box, etc.) —
  // the periodic tick re-render would wipe their input mid-keystroke.
  const ae = document.activeElement;
  if (ae && panel.contains(ae) && ['INPUT', 'TEXTAREA', 'SELECT'].includes(ae.tagName)) return;
  const fn = tabRenderers[activeTab];
  if (fn) fn(panel);
  else panel.innerHTML = `<div class="section dim">🚧 Under construction.</div>`;
}

export function wireTabs() {
  document.querySelectorAll('#tabs .tab').forEach(btn =>
    btn.addEventListener('click', () => switchTab(btn.dataset.tab)));
}

// --- Formatting --------------------------------------------------------------

/** Compact number: 1234 -> 1.23k, 5,600,000 -> 5.6M. */
export function fmt(n) {
  const abs = Math.abs(n);
  if (abs >= 1e9) return (n / 1e9).toFixed(2) + 'B';
  if (abs >= 1e6) return (n / 1e6).toFixed(2) + 'M';
  if (abs >= 1e4) return (n / 1e3).toFixed(1) + 'k';
  if (abs >= 100) return Math.round(n).toString();
  return (Math.round(n * 10) / 10).toString();
}

export function fmtSigned(n) { return (n >= 0 ? '+' : '') + fmt(n); }

export function elementIcons(c) {
  return c.elements.map(e => ELEMENTS[e]?.icon || '❓').join('');
}

export function esc(s) {
  return String(s).replace(/[&<>"']/g, ch =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
}

// --- Resource bar ------------------------------------------------------------

export function renderResources() {
  document.querySelector('#res-coins b').textContent = fmt(S.resources.coins);
  document.querySelector('#res-essence b').textContent = fmt(S.resources.essence);
  document.querySelector('#res-relics b').textContent = fmt(S.resources.relics);
}

// --- Async art mounting ------------------------------------------------------
// Cards render a silhouette immediately; art swaps in when the promise
// resolves. Elements are tracked by a data-art key so re-renders reuse work.

export function mountArt(el, creature) {
  el.innerHTML = silhouetteSVG();
  generateCreatureArt(creature).then(result => {
    if (!el.isConnected) return; // card re-rendered/removed while art loaded
    if (result.kind === 'svg') el.innerHTML = result.svg;
    else if (result.kind === 'url') el.innerHTML = `<img src="${esc(result.url)}" alt="" style="width:100%;height:100%">`;
  }).catch(() => { /* art failing must never break play — silhouette stays */ });
}

// --- Creature card widget ----------------------------------------------------

/**
 * Build a creature card element. opts: { onClick(c), selected, showNet }.
 * Used by menagerie, den parent picker, and reserve lists.
 */
export function creatureCard(c, opts = {}) {
  const card = document.createElement('div');
  card.className = 'creature-card' + (opts.selected ? ' selected' : '');
  card.style.setProperty('--rarity', rarityColor(c));
  const { net } = incomeBreakdown(c);
  const netHtml = opts.showNet
    ? `<div class="net num ${net >= 0 ? 'good' : 'bad'}">${fmtSigned(net)}/s</div>` : '';
  card.innerHTML = `
    <div class="art"></div>
    <div class="cname">${esc(c.name)}</div>
    <div class="cmeta">${elementIcons(c)} T${c.tier} · <span class="rarity-tag" style="--rarity:${rarityColor(c)}">${c.rarity}</span> ${traitChips(c)}</div>
    ${netHtml}`;
  mountArt(card.querySelector('.art'), c);
  if (opts.onClick) card.addEventListener('click', () => opts.onClick(c));
  return card;
}

// --- Modal -------------------------------------------------------------------

const backdrop = () => document.getElementById('modal-backdrop');
const modalEl = () => document.getElementById('modal');

export function openModal(html) {
  modalEl().innerHTML = html;
  backdrop().classList.remove('hidden');
  return modalEl();
}
export function closeModal() { backdrop().classList.add('hidden'); }

export function wireModal() {
  backdrop().addEventListener('click', e => { if (e.target === backdrop()) closeModal(); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });
}

/**
 * In-game confirmation dialog. Never use window.confirm(): sandboxed
 * embeds/viewers block native dialogs silently (confirm() returns false),
 * which makes buttons look dead. This modal works everywhere.
 */
export function confirmModal(messageHtml, onYes, yesLabel = 'Yes, do it') {
  const m = openModal(`
    <h3 style="margin-top:0">Are you sure?</h3>
    <div style="margin:10px 0">${messageHtml}</div>
    <div class="row" style="justify-content:flex-end;gap:10px">
      <button id="cfm-no">Cancel</button>
      <button id="cfm-yes" class="primary">${yesLabel}</button>
    </div>`);
  m.querySelector('#cfm-no').addEventListener('click', closeModal);
  m.querySelector('#cfm-yes').addEventListener('click', () => { closeModal(); onYes(); });
}

/** Detail modal for a creature: art, stats, income breakdown, actions. */
export function showCreatureModal(c, extraActionsHtml = '', wireExtra = null) {
  const { revenue, maintenance, net } = incomeBreakdown(c);
  const hp = happinessOf(c);
  const stat = (label, v) => `
    <div class="statbar"><span class="label">${label}</span>
      <div class="track"><div style="width:${Math.min(100, v / 2)}%"></div></div>
      <span class="num">${v}</span></div>`;
  const m = openModal(`
    <div style="text-align:center">
      <div class="art-big"></div>
      <h2 style="margin-bottom:2px">${esc(c.name)}</h2>
      <div class="cmeta dim">${elementIcons(c)} Tier ${c.tier} ·
        <span class="rarity-tag" style="--rarity:${rarityColor(c)}">${c.rarity}</span>
        ${c.mutated ? ' · <span class="gold">⚡ mutant</span>' : ''}</div>
      ${c.parents ? `<div class="dim" style="margin-top:4px">Fused from ${esc(c.parents[0])} × ${esc(c.parents[1])}</div>` : '<div class="dim" style="margin-top:4px">Wild-born</div>'}
    </div>
    <div style="margin:12px 0">
      ${stat('Power', c.stats.power)}${stat('Charm', c.stats.charm)}${stat('Vitality', c.stats.vitality)}
    </div>
    ${traitsOf(c).length ? `<div class="section" style="margin-bottom:10px">
      ${traitsOf(c).map(t => `<div class="row spread" style="margin:2px 0">
        <span>${t.icon} <b>${t.name}</b> <span class="dim" style="font-size:.72rem">${t.boon ? '' : 'burden'}</span></span>
        <span class="dim" style="font-size:.8rem">${t.desc}</span></div>`).join('')}
    </div>` : ''}
    <div class="section" style="margin-bottom:10px">
      <div class="row spread"><span>😊 Happiness</span><b class="num">${hp}/100</b></div>
      <div class="row spread"><span class="good">Revenue</span><b class="num good">+${fmt(revenue)}/s</b></div>
      <div class="row spread"><span class="bad">Maintenance</span><b class="num bad">−${fmt(maintenance)}/s</b></div>
      <div class="row spread"><span>Net</span><b class="num ${net >= 0 ? 'good' : 'bad'}">${fmtSigned(net)}/s</b></div>
    </div>
    ${extraActionsHtml}
    <div class="row" style="justify-content:flex-end;margin-top:10px">
      <button id="modal-close">Close</button>
    </div>`);
  mountArt(m.querySelector('.art-big'), c);
  m.querySelector('#modal-close').addEventListener('click', closeModal);
  if (wireExtra) wireExtra(m);
  return m;
}

// --- Toasts ------------------------------------------------------------------

export function toast(msg, cls = '') {
  const box = document.getElementById('toasts');
  const t = document.createElement('div');
  t.className = 'toast ' + cls;
  t.innerHTML = msg;
  box.appendChild(t);
  setTimeout(() => t.remove(), 4200);
}
