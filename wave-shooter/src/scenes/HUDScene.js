import Phaser from 'phaser';
import { VIEW_W, VIEW_H } from '../config.js';

const FONT = 'Consolas, "Courier New", monospace';

// Overlay scene: vitals, ability cooldown, wave/score readouts, and wave
// banners. Reads live state straight off GameScene each frame; event
// listeners only drive transient banners.
export default class HUDScene extends Phaser.Scene {
  constructor() { super('HUD'); }

  create() {
    this.game_ = this.scene.get('Game');
    this.bars = this.add.graphics();

    const style = (size, color = '#e8eaed') => ({
      fontFamily: FONT, fontSize: `${size}px`, color, stroke: '#000', strokeThickness: 3
    });

    this.waveText = this.add.text(VIEW_W / 2, 14, '', style(22, '#ffd54f')).setOrigin(0.5, 0);
    this.leftText = this.add.text(VIEW_W / 2, 42, '', style(13, '#b0bec5')).setOrigin(0.5, 0);
    this.scoreText = this.add.text(VIEW_W - 16, 14, '', style(18)).setOrigin(1, 0);
    this.comboText = this.add.text(VIEW_W - 16, 40, '', style(14, '#ffd54f')).setOrigin(1, 0);
    this.buildText = this.add.text(16, 64, '', style(12, '#90a4ae'));
    this.abilityText = this.add.text(70, VIEW_H - 58, '', style(13));
    this.banner = this.add.text(VIEW_W / 2, VIEW_H * 0.32, '', style(30, '#ffd54f'))
      .setOrigin(0.5).setAlpha(0);
    this.bannerSub = this.add.text(VIEW_W / 2, VIEW_H * 0.32 + 34, '', style(15, '#ef9a9a'))
      .setOrigin(0.5).setAlpha(0);

    const g = this.game_;
    this.buildText.setText(`${g.build.className} · ${g.build.loadoutName}`);
    this.abilityText.setText(`${g.build.ability.name}  [SHIFT / RMB]`);

    g.events.on('wave-start', this.onWaveStart, this);
    g.events.on('wave-clear', this.onWaveClear, this);
    this.events.on('shutdown', () => {
      g.events.off('wave-start', this.onWaveStart, this);
      g.events.off('wave-clear', this.onWaveClear, this);
    });
  }

  onWaveStart(wave, modifier) {
    this.showBanner(`WAVE ${wave}`, modifier ? `${modifier.name} — ${modifier.desc}` : '');
  }

  onWaveClear(wave) {
    this.showBanner('WAVE CLEARED', '');
  }

  showBanner(text, sub) {
    this.banner.setText(text).setAlpha(1);
    this.bannerSub.setText(sub).setAlpha(sub ? 1 : 0);
    this.tweens.add({ targets: [this.banner, this.bannerSub], alpha: 0, delay: 1600, duration: 500 });
  }

  update() {
    const g = this.game_;
    const p = g.player;
    if (!p) return;

    const b = this.bars.clear();
    const x = 16, w = 220;

    // health (red) with shield (blue) above it, overshield (gold) on top
    b.fillStyle(0x263238).fillRect(x, 34, w, 12);
    b.fillStyle(0xef5350).fillRect(x, 34, w * Math.max(0, p.health / p.build.health), 12);
    b.fillStyle(0x263238).fillRect(x, 18, w, 10);
    b.fillStyle(0x42a5f5).fillRect(x, 18, w * Math.max(0, p.shield / p.build.shield), 10);
    if (p.overshieldMax > 0 && p.overshield > 0) {
      b.fillStyle(0xffd54f).fillRect(x, 10, w * (p.overshield / p.overshieldMax), 5);
    }

    // ability cooldown box (fills up as it recharges)
    const now = g.time.now;
    const cd = p.build.ability.cooldownMs;
    const readyIn = Math.max(0, p.abilityReadyAt - now);
    const frac = 1 - readyIn / cd;
    b.fillStyle(0x263238).fillRect(x, VIEW_H - 60, 44, 44);
    b.fillStyle(readyIn <= 0 ? 0x66bb6a : 0x546e7a)
      .fillRect(x, VIEW_H - 60 + 44 * (1 - frac), 44, 44 * frac);
    b.lineStyle(2, 0x90a4ae).strokeRect(x, VIEW_H - 60, 44, 44);

    this.waveText.setText(g.director.wave > 0 ? `WAVE ${g.director.wave}` : 'GET READY');
    this.leftText.setText(g.director.betweenWaves ? 'stand by…' : `enemies left: ${g.director.remaining}`);
    this.scoreText.setText(`SCORE ${g.score}`);
    this.comboText.setText(g.combo > 1 ? `x${g.combo} combo` : '');
  }
}
