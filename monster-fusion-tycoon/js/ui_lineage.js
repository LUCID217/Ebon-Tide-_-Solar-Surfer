// ============================================================================
// ui_lineage.js — the family-tree view.
//
// Opened from any creature modal (🌳 button — registered into ui.js via
// setLineageOpener, mirroring the tab-registry pattern to avoid an import
// cycle). Layout is a VERTICAL nested tree: focus creature at top, each
// ancestor pair indented one step under its child. Vertical nesting means
// width never grows with depth — mobile (390px) can't overflow horizontally.
//
// Depth handling: focus + parents + grandparents render expanded; deeper
// generations sit inside native <details> elements, collapsed by default —
// "show earlier generations" expands them with zero JS state.
//
// Dead ancestors render from their ledger snapshots (art regenerates
// deterministically from the stored seed via the ONE art path, mountArt →
// generateCreatureArt). Living ancestors get a 🏡 badge + jump button.
// Roots (eggs/starters/imports — no ledger record) get a 🥚 badge.
// ============================================================================

import { S } from './state.js';
import { lineageRecord, generationOf, ancestorCount } from './lineage.js';
import {
  openModal, closeModal, mountArt, esc, elementIcons,
  setLineageOpener, showCreatureModal,
} from './ui.js';
import { rarityColor } from './creature.js';

// Generations beyond this depth start collapsed (focus = depth 0).
const OPEN_DEPTH = 2;

/** One ancestor/focus node card. Returns html; art mounts are queued. */
function nodeHtml(snap, depth, mounts, isFocus = false) {
  const living = !isFocus && !!S.creatures[snap.id];
  const rec = lineageRecord(snap.id);
  const artId = `lin-art-${mounts.length}`;
  mounts.push({ artId, snap });
  return `
    <div class="lin-node ${isFocus ? 'lin-focus' : ''}" style="--rarity:${rarityColor(snap)}">
      <div class="lin-art" id="${artId}"></div>
      <div class="lin-info">
        <div class="lin-name">${esc(snap.name)}
          ${snap.mutated ? '<span title="Gained an element neither parent had">⚡</span>' : ''}</div>
        <div class="lin-meta dim">${elementIcons(snap)} T${snap.tier} ·
          <span class="rarity-tag" style="--rarity:${rarityColor(snap)}">${snap.rarity}</span>
          · Gen ${generationOf(snap.id)}</div>
      </div>
      <div class="lin-badges">
        ${!rec ? '<span class="lin-badge" title="Wild-born: hatched or adopted, not fused">🥚 root</span>' : ''}
        ${living ? `<button class="lin-jump" data-jump="${esc(snap.id)}" title="Still in your menagerie — view it">🏡 alive</button>` : ''}
      </div>
    </div>`;
}

/** Recursive subtree: a node card plus (if fused) its two parents indented. */
function treeHtml(snap, depth, mounts, isFocus = false) {
  const rec = lineageRecord(snap.id);
  let html = nodeHtml(snap, depth, mounts, isFocus);
  if (rec) {
    const children = `
      <div class="lin-children">
        ${treeHtml(rec.a, depth + 1, mounts)}
        ${treeHtml(rec.b, depth + 1, mounts)}
      </div>`;
    html += depth >= OPEN_DEPTH
      ? `<details class="lin-more"><summary class="dim">⤴ show earlier generations</summary>${children}</details>`
      : children;
  }
  return html;
}

/** Open the lineage modal focused on a creature (live object or snapshot). */
export function showLineageModal(c) {
  const rec = lineageRecord(c.id);
  const gen = generationOf(c.id);
  const ancestors = ancestorCount(c.id);
  const mounts = [];
  const body = rec
    ? treeHtml(c, 0, mounts, true)
    : `${nodeHtml(c, 0, mounts, true)}
       <div class="dim" style="margin-top:8px">Wild-born — no ancestry recorded.
       Fused creatures build a family tree here, generation by generation.</div>`;
  const m = openModal(`
    <div class="row spread" style="margin-bottom:8px">
      <h2 style="margin:0">🌳 Lineage</h2>
      <span class="dim">Gen <b class="num" style="color:var(--text)">${gen}</b>
        ${ancestors ? ` · ${ancestors} ancestors` : ''}</span>
    </div>
    <div class="lin-tree">${body}</div>
    <div class="row" style="justify-content:flex-end;margin-top:10px">
      <button id="lin-close">Close</button>
    </div>`);
  // Mount all ancestor art through the single async art boundary.
  for (const { artId, snap } of mounts) {
    const el = m.querySelector('#' + artId);
    if (el) mountArt(el, snap);
  }
  m.querySelector('#lin-close').addEventListener('click', closeModal);
  m.querySelectorAll('.lin-jump').forEach(btn =>
    btn.addEventListener('click', () => {
      const live = S.creatures[btn.dataset.jump];
      if (live) showCreatureModal(live);
    }));
  return m;
}

// Register with the ui core so every creature modal grows a 🌳 button.
setLineageOpener(showLineageModal);
