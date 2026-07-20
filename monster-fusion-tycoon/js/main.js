// ============================================================================
// main.js — bootstrap + game loop.
// Order matters: load save → ensure starter content → wire UI shell →
// import tab modules (they self-register) → start the tick.
// ============================================================================

import { CONFIG } from './config.js';
import { S } from './state.js';
import { loadGame, saveGame, wipeSave, storageOk } from './save.js';
import { makeBaseCreature } from './creature.js';
import { ensureStarterHabitat, applyOfflineProgress, economyTick, placeCreature, totalPerSec } from './economy.js';
import { tryResolveFusion, registerDiscovery } from './fusion.js';
import {
  wireTabs, wireModal, switchTab, renderActiveTab, renderResources, toast, fmt, confirmModal,
} from './ui.js';

// Tab modules self-register with the ui.js registry on import.
import './ui_menagerie.js';
import { onFusionResolved } from './ui_den.js';
import './ui_shop.js';
import './ui_collection.js';
import { updateBadge } from './ui_objectives.js';
import { handleShareHash } from './ui_share.js';
import { showHelp, wireHelpButton } from './ui_help.js';
import './ui_lineage.js'; // registers the 🌳 lineage opener into ui.js

// --- New-game setup ----------------------------------------------------------

function setupFreshGame() {
  ensureStarterHabitat();
  // Three starters: two sharing a habitat, one in reserve — teaches placement.
  const starters = [
    makeBaseCreature({ element: 'fire' }),
    makeBaseCreature({ element: 'nature' }),
    makeBaseCreature({ element: 'water' }),
  ];
  const homeId = S.habitatOrder[0];
  for (const c of starters) {
    S.creatures[c.id] = c;
    registerDiscovery(c);
  }
  placeCreature(starters[0], homeId);
  placeCreature(starters[1], homeId);
  // starters[2] stays in reserve on purpose.
}

// --- Boot --------------------------------------------------------------------

function boot() {
  const offlineSec = loadGame();
  const isFresh = Object.keys(S.creatures).length === 0 && S.counters.fusions === 0;

  ensureStarterHabitat();
  if (isFresh) setupFreshGame();

  wireTabs();
  wireModal();

  // Top-bar buttons.
  document.getElementById('btn-save').addEventListener('click', () => {
    toast(saveGame() ? '💾 Saved.' : '⚠️ Save unavailable in this browser.', saveGame() ? '' : 'bad');
  });
  document.getElementById('btn-wipe').addEventListener('click', () => {
    confirmModal('Wipe your save and start over? This cannot be undone.', () => {
      wipeSave();
      setupFreshGame();
      saveGame();
      renderResources();
      switchTab('menagerie');
      toast('Fresh start. Welcome back, keeper. 🌱');
    }, '🗑️ Wipe save');
  });

  // Offline progress report.
  if (offlineSec > 5) {
    const rep = applyOfflineProgress(offlineSec);
    if (rep) {
      toast(`⏳ While you were away (${Math.round(rep.seconds / 60)}m): ` +
        `<b class="gold">+${fmt(rep.earned)}</b> 🪙 accrued, ` +
        `<b class="bad">−${fmt(rep.drained)}</b> 🪙 upkeep.`, 'gold');
    }
  }

  wireHelpButton();

  // Sandboxed viewers / private mode can't persist — play works, saving won't.
  // Say so loudly instead of losing progress silently.
  if (!storageOk()) {
    document.getElementById('btn-save').textContent = '⚠️';
    document.getElementById('btn-save').title = 'Saving unavailable here';
    toast('⚠️ This viewer can\'t save progress. The game is fully playable, ' +
      'but download the file and open it in a browser to keep your menagerie.', 'bad');
  }

  renderResources();
  switchTab('menagerie');
  startLoop();
  saveGame();
  handleShareHash(); // a #c=… share URL opens the import viewer
  if (isFresh && !location.hash) showHelp(); // first visit: quick orientation
}

// --- The loop ----------------------------------------------------------------

let lastTick = Date.now();
let autosaveAcc = 0;
let lastBrokeWarn = 0; // throttle the bankruptcy warning toast

function startLoop() {
  setInterval(() => {
    const now = Date.now();
    const dt = Math.min(5, (now - lastTick) / 1000); // clamp huge gaps (tab slept)
    lastTick = now;

    economyTick(dt);

    // Broke + still paying upkeep? Nudge the keeper toward the fix.
    if (S.resources.coins <= 0 && Date.now() - lastBrokeWarn > 60000) {
      const { maintenance } = totalPerSec();
      if (maintenance > 0) {
        lastBrokeWarn = Date.now();
        toast('💸 The treasury is empty and upkeep looms! Collect revenue, sell a money-pit, or improve happiness.', 'bad');
      }
    }

    // Resolve a finished fusion (deterministic + local; art loads after).
    const child = tryResolveFusion();
    if (child) {
      const isNew = !!S.discovered && S.discovered[`${[...child.elements].sort().join('+')}|${child.archetype}`]?.count === 1;
      onFusionResolved(child, isNew);
      saveGame();
    }

    autosaveAcc += dt;
    if (autosaveAcc >= CONFIG.save.autosaveSeconds) {
      autosaveAcc = 0;
      saveGame();
    }

    renderResources();
    renderActiveTab();
    updateBadge();
  }, CONFIG.economy.tickSeconds * 1000);
}

// Save when the tab is hidden/closed — cheap insurance.
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'hidden') saveGame();
});

boot();
