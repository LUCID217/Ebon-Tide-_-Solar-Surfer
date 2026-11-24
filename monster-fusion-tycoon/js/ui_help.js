// ============================================================================
// ui_help.js — the "how to play" modal. Shown on first boot and from the ❓
// topbar button. Pure UI, no state.
// ============================================================================

import {
  CONFIG, ELEMENTS, ELEMENT_CYCLE, CLASSES, CLASS_KEYS, CLASS_RECIPES, TYPES,
  overcomesTarget,
} from './config.js';
import { openModal, closeModal } from './ui.js';
import { TRAITS } from './traits.js';

/** The element cycle as a compact two-line reference. */
export function elementCycleHtml() {
  const ic = k => `${ELEMENTS[k].icon}${ELEMENTS[k].label}`;
  return `<div class="rules-block">
    <div><b>Feeds</b> (child takes the fed element, stat bonus):
      ${ELEMENT_CYCLE.map(k => ic(k)).join(' → ')} → ${ic(ELEMENT_CYCLE[0])}</div>
    <div><b>Overcomes</b> (⚡ volatile — dice, may mutate):
      ${ELEMENT_CYCLE.map(k => `${ELEMENTS[k].icon}&gt;${ELEMENTS[overcomesTarget(k)].icon}`).join(' · ')}</div>
    <div class="dim">Same element is kept. Bodies: same body is kept, otherwise
      ${Math.round(CONFIG.fusion.typeRarerParentWeight * 100)}/${Math.round((1 - CONFIG.fusion.typeRarerParentWeight) * 100)} for the rarer parent's.</div>
  </div>`;
}

/** The learnable 5×5 class recipe table. */
export function classRecipeTableHtml() {
  const ic = k => `<span title="${CLASSES[k].label}: ${CLASSES[k].role}">${CLASSES[k].icon}</span>`;
  return `<table class="recipe-table" aria-label="Class recipes">
    <tr><th></th>${CLASS_KEYS.map(k => `<th>${ic(k)}</th>`).join('')}</tr>
    ${CLASS_KEYS.map(r => `<tr><th>${ic(r)}</th>${CLASS_KEYS.map(c => `<td>${ic(CLASS_RECIPES[r][c])}</td>`).join('')}</tr>`).join('')}
  </table>
  <div class="dim" style="font-size:.75rem">${CLASS_KEYS.map(k => `${CLASSES[k].icon} ${CLASSES[k].label} — ${CLASSES[k].role}`).join(' · ')}</div>`;
}

export function showHelp() {
  const m = openModal(`
    <h2>🧬 How to run a monster menagerie</h2>
    <div style="line-height:1.55">
      <p><b>🏞️ Menagerie</b> — creatures placed in habitats earn coins over time.
      <b>Collect</b> often (it also trickles 💠 essence).</p>
      <p><b>🕊️ Meadows are sanctuaries</b> — creatures housed there bill
      <i>no upkeep, ever</i>. Buy eggs, fuse, experiment: your meadow can't
      bankrupt you. The trade-off: exotic (rare+) creatures only earn half in
      a sanctuary. Serious income means building <b>elemental habitats</b> —
      bigger earnings from biome-matched, happy creatures, but rare+ residents
      bill upkeep there <i>whether or not they earn</i>. That's the tycoon
      game: when coins leak, the 🩺 advisor names the culprit and why.</p>
      <p><b>😊 Happiness</b> — match a creature's element to its habitat's biome,
      add decorations, avoid overcrowding, bring a 🛡️ Guardian.
      🪓 Brutes earn more but eat more; 🧺 Tenders cut upkeep; 🔮 Seers on
      exhibit improve egg luck; 🎭 Tricksters make fusions mutate. Below ${CONFIG.economy.unhappyThreshold}
      happiness a creature sulks: zero income, full upkeep. Click any creature
      for its full happiness &amp; income breakdown.</p>
      <p><b>🥚 Breeding Den</b> — fuse two creatures into one. Parents are
      consumed! Every creature is an <b>element</b> × <b>body</b> × <b>class</b>
      — ${Object.keys(ELEMENTS).length * Object.keys(TYPES).length * CLASS_KEYS.length} species
      to collect. Each axis resolves on its own: elements follow the cycle
      (feeding is safe, overcoming is ⚡ volatile), bodies favour the rarer
      parent, and classes follow a recipe table you can learn. Rarity can spike,
      and every new species pays an essence bounty.</p>
      ${elementCycleHtml()}
      <details>
        <summary style="cursor:pointer"><b>📜 Class recipes &amp; roles</b></summary>
        ${classRecipeTableHtml()}
      </details>
      <p><b>⚖️ The trap</b> — legendary+ creatures carry <i>burdens</i> next to
      their boons. A mismanaged mythic bleeds you dry. Place aura creatures
      (✨🎶) with roommates they help; isolate tyrants 👑; sell 💰 what you
      can't afford.</p>
      <p><b>🏺 Relics</b> — earned only from milestones (or steep essence
      forging). Spend them on permanent staff.</p>
      <p><b>📤 Sharing</b> — export any creature as a string/URL from its card;
      import friends' creatures in the Collection tab.</p>
      <details>
        <summary style="cursor:pointer"><b>📚 Trait reference</b></summary>
        <div style="margin-top:6px;font-size:.85rem">
          ${Object.values(TRAITS).map(t =>
            `<div class="row spread" style="margin:2px 0">
              <span>${t.icon} ${t.name} <span class="dim">${t.boon ? '' : '(burden)'}</span></span>
              <span class="dim">${t.desc}</span></div>`).join('')}
        </div>
      </details>
    </div>
    <div class="row" style="justify-content:flex-end;margin-top:10px">
      <button id="help-close" class="primary">Let me in</button>
    </div>`);
  m.querySelector('#help-close').addEventListener('click', closeModal);
}

export function wireHelpButton() {
  document.getElementById('btn-help')?.addEventListener('click', showHelp);
}
