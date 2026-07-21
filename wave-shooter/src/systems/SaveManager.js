// Persistence behind a tiny interface so localStorage can be swapped for a
// backend later without touching game code. Everything else in the game goes
// through save/load/reset here.

import { GRID } from '../data/progression.js';

const KEY = 'wave-shooter-save-v1';

function cellKey(col, row) {
  return `${col},${row}`;
}

function defaultSave() {
  const startCol = GRID.classes.indexOf(GRID.start.classId);
  const startRow = GRID.loadouts.indexOf(GRID.start.loadoutId);
  return {
    credits: 0,
    unlocked: [cellKey(startCol, startRow)],
    bestScore: 0,
    bestWave: 0,
    lastSelected: { col: startCol, row: startRow }
  };
}

class SaveManager {
  constructor() {
    this.data = this._read();
  }

  _read() {
    try {
      const raw = localStorage.getItem(KEY);
      if (!raw) return defaultSave();
      const parsed = JSON.parse(raw);
      // merge over defaults so new fields survive old saves
      return { ...defaultSave(), ...parsed };
    } catch {
      return defaultSave();
    }
  }

  _write() {
    try {
      localStorage.setItem(KEY, JSON.stringify(this.data));
    } catch {
      // storage full / private mode — play on without persistence
    }
  }

  get credits() { return this.data.credits; }
  get bestScore() { return this.data.bestScore; }
  get bestWave() { return this.data.bestWave; }
  get lastSelected() { return this.data.lastSelected; }

  isUnlocked(col, row) {
    return this.data.unlocked.includes(cellKey(col, row));
  }

  // A cell is buyable if locked and orthogonally adjacent to an unlocked cell.
  isAdjacentToUnlocked(col, row) {
    return [[1, 0], [-1, 0], [0, 1], [0, -1]].some(([dc, dr]) =>
      this.isUnlocked(col + dc, row + dr)
    );
  }

  tryUnlock(col, row, cost) {
    if (this.isUnlocked(col, row)) return false;
    if (!this.isAdjacentToUnlocked(col, row)) return false;
    if (this.data.credits < cost) return false;
    this.data.credits -= cost;
    this.data.unlocked.push(cellKey(col, row));
    this._write();
    return true;
  }

  setSelected(col, row) {
    this.data.lastSelected = { col, row };
    this._write();
  }

  // Called at the end of a run: banks score as credits, records bests.
  recordRun({ score, wave }) {
    this.data.credits += score;
    if (score > this.data.bestScore) this.data.bestScore = score;
    if (wave > this.data.bestWave) this.data.bestWave = wave;
    this._write();
  }

  reset() {
    this.data = defaultSave();
    this._write();
  }
}

// Singleton — one save, shared by all scenes.
export const save = new SaveManager();
