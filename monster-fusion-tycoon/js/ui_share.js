// ============================================================================
// ui_share.js — share/import UI: export modal (string + URL + copy),
// import viewer with adopt action, and #c= URL-hash handling on boot.
// ============================================================================

import { exportCreature, exportURL, decodeShareString, adoptCost, adoptCreature } from './share.js';
import { openModal, closeModal, mountArt, esc, toast, renderResources, elementIcons } from './ui.js';
import { rarityColor } from './creature.js';
import { saveGame } from './save.js';

/** Export modal: the encoded string and a shareable URL, with copy buttons. */
export function showShareModal(c) {
  const str = exportCreature(c);
  const url = exportURL(c);
  const m = openModal(`
    <h2>📤 Share ${esc(c.name)}</h2>
    <div class="dim" style="margin-bottom:8px">Anyone can paste this into their own menagerie — no server involved.</div>
    <label class="dim">Share string</label>
    <textarea id="share-str" readonly rows="3" style="width:100%;font-size:.75rem;word-break:break-all">${str}</textarea>
    <div class="row" style="margin:6px 0 12px"><button id="copy-str">📋 Copy string</button></div>
    <label class="dim">Share URL</label>
    <textarea id="share-url" readonly rows="2" style="width:100%;font-size:.75rem;word-break:break-all">${esc(url)}</textarea>
    <div class="row spread" style="margin-top:6px">
      <button id="copy-url">📋 Copy URL</button>
      <button id="modal-close2">Close</button>
    </div>`);
  const copy = (id, srcId) => m.querySelector('#' + id).addEventListener('click', async () => {
    const text = m.querySelector('#' + srcId).value;
    try {
      // Feature-detect: clipboard API needs a secure context.
      if (navigator.clipboard?.writeText) await navigator.clipboard.writeText(text);
      else throw new Error('no clipboard API');
      toast('Copied! 📋');
    } catch {
      m.querySelector('#' + srcId).select();
      toast('Press Ctrl+C to copy (auto-copy unavailable here).');
    }
  });
  copy('copy-str', 'share-str');
  copy('copy-url', 'share-url');
  m.querySelector('#modal-close2').addEventListener('click', closeModal);
}

/** Import viewer: show the decoded creature; adopting costs essence. */
export function showImportModal(decoded) {
  const c = decoded;
  const cost = adoptCost(c);
  const m = openModal(`
    <div style="text-align:center">
      <div class="dim">A traveling creature arrives…</div>
      <div class="art-big"></div>
      <h2 style="color:${rarityColor(c)}">${esc(c.name)}</h2>
      <div class="dim">${elementIcons(c)} Tier ${c.tier} ·
        <span class="rarity-tag" style="--rarity:${rarityColor(c)}">${c.rarity}</span></div>
      <div class="dim" style="margin-top:4px">
        ⚔️ ${c.stats.power} · 💖 ${c.stats.charm} · 🛡️ ${c.stats.vitality}</div>
      ${c.parents ? `<div class="dim" style="margin-top:4px">Lineage: ${esc(c.parents[0])} × ${esc(c.parents[1])}</div>` : ''}
    </div>
    <div class="row" style="justify-content:center;margin-top:14px;gap:10px">
      <button id="btn-adopt" class="primary">🏡 Adopt — ${cost} 💠</button>
      <button id="btn-decline">Just admiring</button>
    </div>`);
  mountArt(m.querySelector('.art-big'), c);
  m.querySelector('#btn-adopt').addEventListener('click', () => {
    const res = adoptCreature(c);
    if (!res.ok) return toast(res.why, 'bad');
    toast(`🏡 <b>${esc(res.creature.name)}</b> adopted into the reserve pen!` +
      (res.isNew ? ' <span class="gold">✦ New species!</span>' : ''), 'gold');
    saveGame(); renderResources(); closeModal();
  });
  m.querySelector('#btn-decline').addEventListener('click', closeModal);
}

/** Paste-box flow used from the Collection tab. */
export function tryImportString(raw) {
  const res = decodeShareString(raw);
  if (!res.ok) return toast(res.why, 'bad');
  showImportModal(res.creature);
}

/** On boot: a #c=… hash means someone followed a share URL. */
export function handleShareHash() {
  if (!location.hash.startsWith('#c=')) return;
  const res = decodeShareString(location.hash);
  // Clear the hash either way so refresh doesn't re-trigger.
  history.replaceState(null, '', location.pathname + location.search);
  if (res.ok) showImportModal(res.creature);
  else toast(res.why, 'bad');
}
