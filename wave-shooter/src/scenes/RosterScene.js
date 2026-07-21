import Phaser from 'phaser';
import { VIEW_W, VIEW_H } from '../config.js';
import { GRID } from '../data/progression.js';
import { CLASSES } from '../data/classes.js';
import { LOADOUTS } from '../data/loadouts.js';
import { save } from '../systems/SaveManager.js';
import { describeCell } from '../systems/build.js';
import { sfx, unlockAudio } from '../systems/sfx.js';

const FONT = 'Consolas, "Courier New", monospace';

// Roster screen: the progression grid. Classes across, loadouts down.
// Unlocked cells are selectable; locked cells show their cost and what they
// change; buying requires adjacency to an unlocked cell.
export default class RosterScene extends Phaser.Scene {
  constructor() { super('Roster'); }

  create() {
    this.input.once('pointerdown', unlockAudio);
    this.selected = { ...save.lastSelected };
    if (!save.isUnlocked(this.selected.col, this.selected.row)) {
      this.selected = { col: 0, row: 0 };
    }

    this.add.text(VIEW_W / 2, 22, 'WAVE SHOOTER', {
      fontFamily: FONT, fontSize: '30px', color: '#ffd54f', stroke: '#000', strokeThickness: 4
    }).setOrigin(0.5, 0);

    this.statsText = this.add.text(VIEW_W / 2, 60, '', {
      fontFamily: FONT, fontSize: '14px', color: '#b0bec5'
    }).setOrigin(0.5, 0);

    this.infoTitle = this.add.text(48, 500, '', {
      fontFamily: FONT, fontSize: '16px', color: '#e8eaed'
    });
    this.infoBody = this.add.text(48, 524, '', {
      fontFamily: FONT, fontSize: '13px', color: '#90a4ae', wordWrap: { width: 620 }
    });

    // start button
    const startBg = this.add.rectangle(VIEW_W - 120, 545, 180, 52, 0x2e7d32)
      .setStrokeStyle(2, 0x66bb6a).setInteractive({ useHandCursor: true });
    this.add.text(VIEW_W - 120, 545, 'DEPLOY', {
      fontFamily: FONT, fontSize: '22px', color: '#e8f5e9'
    }).setOrigin(0.5);
    startBg.on('pointerdown', () => {
      sfx.click();
      save.setSelected(this.selected.col, this.selected.row);
      this.scene.start('Game', { cell: { ...this.selected } });
    });

    // reset save (small, out of the way)
    const reset = this.add.text(16, VIEW_H - 22, '[wipe save]', {
      fontFamily: FONT, fontSize: '11px', color: '#546e7a'
    }).setInteractive({ useHandCursor: true });
    reset.on('pointerdown', () => {
      save.reset();
      this.scene.restart();
    });

    this.add.text(VIEW_W / 2, VIEW_H - 22, 'WASD move · mouse aim · LMB fire · SHIFT/RMB ability', {
      fontFamily: FONT, fontSize: '12px', color: '#546e7a'
    }).setOrigin(0.5, 0);

    this.gridObjects = [];
    this.buildGrid();
    this.refreshTexts();
    this.showInfo(this.selected.col, this.selected.row);
  }

  refreshTexts() {
    this.statsText.setText(
      `credits: ${save.credits}   best score: ${save.bestScore}   best wave: ${save.bestWave}`
    );
  }

  buildGrid() {
    for (const obj of this.gridObjects) obj.destroy();
    this.gridObjects = [];

    const cellW = 168, cellH = 74, gapX = 10, gapY = 10;
    const labelW = 100;
    const gridW = GRID.classes.length * (cellW + gapX) - gapX;
    const x0 = (VIEW_W - gridW + labelW) / 2;
    const y0 = 140;

    // column headers (classes)
    GRID.classes.forEach((classId, col) => {
      const cls = CLASSES[classId];
      const t = this.add.text(x0 + col * (cellW + gapX) + cellW / 2, y0 - 26, cls.name.toUpperCase(), {
        fontFamily: FONT, fontSize: '14px',
        color: Phaser.Display.Color.IntegerToColor(cls.color).rgba
      }).setOrigin(0.5);
      this.gridObjects.push(t);
    });

    // row labels (loadouts)
    GRID.loadouts.forEach((loadoutId, row) => {
      const t = this.add.text(x0 - 14, y0 + row * (cellH + gapY) + cellH / 2,
        LOADOUTS[loadoutId].name.toUpperCase(), {
          fontFamily: FONT, fontSize: '13px', color: '#b0bec5'
        }).setOrigin(1, 0.5);
      this.gridObjects.push(t);
    });

    // cells
    GRID.loadouts.forEach((loadoutId, row) => {
      GRID.classes.forEach((classId, col) => {
        const x = x0 + col * (cellW + gapX) + cellW / 2;
        const y = y0 + row * (cellH + gapY) + cellH / 2;
        this.buildCell(x, y, cellW, cellH, col, row);
      });
    });
  }

  buildCell(x, y, w, h, col, row) {
    const unlocked = save.isUnlocked(col, row);
    const buyable = !unlocked && save.isAdjacentToUnlocked(col, row);
    const isSelected = unlocked && this.selected.col === col && this.selected.row === row;
    const cost = GRID.costs[row][col];
    const clsColor = CLASSES[GRID.classes[col]].color;

    let fill = 0x11151c, stroke = 0x2a323d, alpha = 0.55;
    if (unlocked) { fill = 0x1a2230; stroke = clsColor; alpha = 1; }
    if (isSelected) { fill = 0x27354d; }
    if (buyable) { alpha = 0.85; stroke = 0x8d6e46; }

    const rect = this.add.rectangle(x, y, w, h, fill)
      .setStrokeStyle(isSelected ? 3 : 2, stroke)
      .setAlpha(alpha)
      .setInteractive({ useHandCursor: unlocked || buyable });
    this.gridObjects.push(rect);

    if (unlocked) {
      const t1 = this.add.text(x, y - 12, describeCell(col, row), {
        fontFamily: FONT, fontSize: '11px', color: '#e8eaed', align: 'center',
        wordWrap: { width: w - 12 }
      }).setOrigin(0.5);
      const t2 = this.add.text(x, y + 18, isSelected ? '▶ SELECTED' : 'click to select', {
        fontFamily: FONT, fontSize: '10px', color: isSelected ? '#ffd54f' : '#546e7a'
      }).setOrigin(0.5);
      this.gridObjects.push(t1, t2);
    } else {
      const affordable = save.credits >= cost;
      const t1 = this.add.text(x, y - 14, `🔒 ${cost}cr`, {
        fontFamily: FONT, fontSize: '13px',
        color: buyable ? (affordable ? '#ffd54f' : '#ef9a9a') : '#546e7a'
      }).setOrigin(0.5);
      const t2 = this.add.text(x, y + 12, describeCell(col, row), {
        fontFamily: FONT, fontSize: '10px', color: '#78909c', align: 'center',
        wordWrap: { width: w - 12 }
      }).setOrigin(0.5);
      this.gridObjects.push(t1, t2);
    }

    rect.on('pointerover', () => this.showInfo(col, row));
    rect.on('pointerdown', () => {
      if (unlocked) {
        sfx.click();
        this.selected = { col, row };
        save.setSelected(col, row);
        this.buildGrid();
        this.showInfo(col, row);
      } else if (buyable && save.tryUnlock(col, row, cost)) {
        sfx.unlock();
        this.buildGrid();
        this.refreshTexts();
        this.showInfo(col, row);
      } else {
        sfx.denied();
      }
    });
  }

  showInfo(col, row) {
    const cls = CLASSES[GRID.classes[col]];
    const loadout = LOADOUTS[GRID.loadouts[row]];
    this.infoTitle.setText(`${cls.name} · ${loadout.name}  (${describeCell(col, row)})`);
    this.infoBody.setText(`${cls.blurb}\n${loadout.blurb}`);
  }
}
