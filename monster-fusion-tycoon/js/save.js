// ============================================================================
// save.js — versioned localStorage persistence.
// The save is the whole state object from state.js, stamped with
// CONFIG.save.schemaVersion. On load, MIGRATIONS run the save forward one
// version at a time, so old saves keep working as the schema evolves.
// ============================================================================

import { CONFIG } from './config.js';
import { S, setState, freshState } from './state.js';
import { syncIdCounter } from './creature.js';

// Each entry migrates FROM that version TO version+1. Add one per schema bump.
// Example for a future v1 -> v2:
//   1: (save) => { save.newField = defaultValue; save.version = 2; return save; },
const MIGRATIONS = {};

/** True if localStorage is actually usable (private mode / quota can kill it). */
function storageAvailable() {
  try {
    const k = '__mft_test__';
    localStorage.setItem(k, '1');
    localStorage.removeItem(k);
    return true;
  } catch {
    return false;
  }
}
const HAS_STORAGE = storageAvailable();

export function saveGame() {
  if (!HAS_STORAGE) return false;
  try {
    S.lastSeen = Date.now();
    localStorage.setItem(CONFIG.save.key, JSON.stringify(S));
    return true;
  } catch (e) {
    console.warn('MFT: save failed', e);
    return false;
  }
}

/**
 * Load save if present, migrating as needed. Returns seconds elapsed since
 * last seen (for offline progress), or 0 for a fresh game.
 */
export function loadGame() {
  if (!HAS_STORAGE) return 0;
  let raw;
  try {
    raw = localStorage.getItem(CONFIG.save.key);
  } catch {
    return 0;
  }
  if (!raw) return 0;
  let save;
  try {
    save = JSON.parse(raw);
  } catch (e) {
    console.warn('MFT: corrupt save, starting fresh', e);
    return 0;
  }
  // Run migrations forward one version at a time.
  while (save.version < CONFIG.save.schemaVersion) {
    const step = MIGRATIONS[save.version];
    if (!step) {
      console.warn(`MFT: no migration from v${save.version}, starting fresh`);
      return 0;
    }
    save = step(save);
  }
  if (save.version > CONFIG.save.schemaVersion) {
    console.warn('MFT: save from a newer version, starting fresh');
    return 0;
  }
  // Backfill any fields a hand-edited/old save might lack, then adopt it.
  const merged = Object.assign(freshState(), save);
  setState(merged);
  syncIdCounter(merged.counters.creatureId ?? 1);
  const elapsed = Math.max(0, (Date.now() - (merged.lastSeen || Date.now())) / 1000);
  return elapsed;
}

export function wipeSave() {
  if (HAS_STORAGE) {
    try { localStorage.removeItem(CONFIG.save.key); } catch { /* ignore */ }
  }
  setState(freshState());
}
