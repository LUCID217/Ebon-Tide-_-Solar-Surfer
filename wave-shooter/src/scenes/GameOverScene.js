import Phaser from 'phaser';
import { VIEW_W, VIEW_H } from '../config.js';
import { save } from '../systems/SaveManager.js';
import { sfx } from '../systems/sfx.js';

const FONT = 'Consolas, "Courier New", monospace';

// Run summary. Score has already been banked as credits by GameScene.
export default class GameOverScene extends Phaser.Scene {
  constructor() { super('GameOver'); }

  init(data) { this.summary = data; }

  create() {
    const s = this.summary;
    const cx = VIEW_W / 2;

    this.add.text(cx, 120, 'RUN OVER', {
      fontFamily: FONT, fontSize: '44px', color: '#ef5350', stroke: '#000', strokeThickness: 5
    }).setOrigin(0.5);

    const isBest = s.score > 0 && s.score >= save.bestScore;
    const lines = [
      `waves survived: ${Math.max(0, s.wave - 1)}`,
      `kills: ${s.kills}`,
      `score: ${s.score}${isBest ? '   ★ NEW BEST' : ''}`,
      '',
      `+${s.score} credits banked (total: ${save.credits})`
    ];
    this.add.text(cx, 220, lines.join('\n'), {
      fontFamily: FONT, fontSize: '18px', color: '#e8eaed', align: 'center', lineSpacing: 8
    }).setOrigin(0.5, 0);

    this.makeButton(cx - 110, 460, 'RETRY', 0x2e7d32, 0x66bb6a, () => {
      this.scene.start('Game', { cell: s.cell });
    });
    this.makeButton(cx + 110, 460, 'ROSTER', 0x37474f, 0x90a4ae, () => {
      this.scene.start('Roster');
    });
  }

  makeButton(x, y, label, fill, stroke, onClick) {
    const bg = this.add.rectangle(x, y, 180, 52, fill)
      .setStrokeStyle(2, stroke).setInteractive({ useHandCursor: true });
    this.add.text(x, y, label, {
      fontFamily: FONT, fontSize: '20px', color: '#e8eaed'
    }).setOrigin(0.5);
    bg.on('pointerdown', () => { sfx.click(); onClick(); });
  }
}
