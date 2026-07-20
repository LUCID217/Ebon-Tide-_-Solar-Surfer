// ============================================================================
// ui_help.js — the "how to play" modal. Shown on first boot and from the ❓
// topbar button. Pure UI, no state.
// ============================================================================

import { openModal, closeModal } from './ui.js';
import { TRAITS } from './traits.js';

export function showHelp() {
  const m = openModal(`
    <h2>🧬 How to run a monster menagerie</h2>
    <div style="line-height:1.55">
      <p><b>🏞️ Menagerie</b> — creatures placed in habitats earn coins over time.
      <b>Collect</b> often (it also trickles 💠 essence). Every creature charges
      upkeep <i>whether or not it earns</i> — an unhappy or unplaced monster is
      pure loss.</p>
      <p><b>😊 Happiness</b> — match a creature's element to its habitat's biome,
      add decorations, avoid overcrowding. Below 35 happiness a creature sulks:
      zero income, full upkeep.</p>
      <p><b>🥚 Breeding Den</b> — fuse two creatures into one hybrid. Parents are
      consumed! Elements merge (sometimes mutate), rarity can spike, and every
      new species pays an essence bounty and fills the Collection.</p>
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
