import Phaser from 'phaser';
import { WAVE_CONFIG } from '../data/waves.js';
import { ENEMIES } from '../data/enemies.js';
import { sfx } from './sfx.js';

// Composes and spawns waves from the point-budget config in data/waves.js.
// Emits on scene.events:
//   'wave-start'  (waveNumber, modifier|null)
//   'wave-clear'  (waveNumber)
//   'enemies-left' (count)
export default class WaveDirector {
  constructor(scene, spawnPoints) {
    this.scene = scene;
    this.cfg = WAVE_CONFIG;
    this.spawnPoints = spawnPoints;
    this.wave = 0;
    this.queue = [];        // enemy types still to spawn this wave
    this.spawnTimer = null;
    this.activeModifier = null;
    this.betweenWaves = true;
  }

  start() {
    this.scheduleNextWave(1200); // short lead-in before wave 1
  }

  stop() {
    this.spawnTimer?.remove();
    this.waveDelay?.remove();
  }

  scheduleNextWave(delayMs = this.cfg.breatherMs) {
    this.betweenWaves = true;
    this.waveDelay = this.scene.time.delayedCall(delayMs, () => this.beginWave());
  }

  beginWave() {
    this.wave++;
    this.betweenWaves = false;
    this.activeModifier = this.rollModifier();
    this.queue = this.composeWave(this.wave, this.activeModifier);
    this.scene.events.emit('wave-start', this.wave, this.activeModifier);
    sfx.waveStart();

    this.spawnTimer = this.scene.time.addEvent({
      delay: this.cfg.spawnIntervalMs,
      loop: true,
      callback: () => this.trickleSpawn()
    });
  }

  rollModifier() {
    const m = this.cfg.modifiers;
    if (this.wave < m.fromWave) return null;
    const total = m.pool.reduce((s, mod) => s + mod.weight, 0);
    let r = Math.random() * total;
    for (const mod of m.pool) {
      r -= mod.weight;
      if (r <= 0) return mod;
    }
    return m.pool[m.pool.length - 1];
  }

  // Spend the wave budget on available enemy types, weighted-random.
  composeWave(wave, modifier) {
    const effects = modifier?.effects ?? {};
    let budget = (this.cfg.baseBudget + this.cfg.budgetGrowth * Math.pow(wave - 1, this.cfg.budgetPower))
      * (effects.budgetMult ?? 1);

    const available = this.cfg.roster.filter(e => wave >= e.fromWave);
    const queue = [];

    // guaranteed spawns first (e.g. a heavy every 3rd wave)
    for (const g of this.cfg.guarantees) {
      if (wave >= g.fromWave && wave % g.everyNWaves === 0) {
        const entry = this.cfg.roster.find(e => e.type === g.type);
        if (entry && budget >= entry.cost) {
          queue.push(g.type);
          budget -= entry.cost;
        }
      }
    }

    // modifier extras (free — they're the modifier's threat, not the budget's)
    for (const extra of effects.extraSpawns ?? []) {
      for (let i = 0; i < extra.count; i++) queue.push(extra.type);
    }

    // spend the rest
    const cheapest = Math.min(...available.map(e => e.cost));
    let guard = 200;
    while (budget >= cheapest && guard-- > 0) {
      const affordable = available.filter(e => e.cost <= budget);
      const total = affordable.reduce((s, e) => s + e.weight, 0);
      let r = Math.random() * total;
      let pick = affordable[0];
      for (const e of affordable) {
        r -= e.weight;
        if (r <= 0) { pick = e; break; }
      }
      queue.push(pick.type);
      budget -= pick.cost;
    }

    Phaser.Utils.Array.Shuffle(queue);
    return queue;
  }

  trickleSpawn() {
    if (this.queue.length === 0) {
      this.spawnTimer.remove();
      return;
    }
    if (this.scene.enemies.countActive(true) >= this.cfg.maxAlive) return;

    const type = this.queue.shift();
    const point = this.pickSpawnPoint();
    const mods = this.activeModifier?.effects ?? {};
    this.scene.spawnEnemy(type, ENEMIES[type], point.x, point.y, mods);
    this.emitRemaining();
  }

  pickSpawnPoint() {
    const p = this.scene.player;
    const far = this.spawnPoints.filter(sp =>
      Phaser.Math.Distance.Between(sp.x, sp.y, p.x, p.y) >= this.cfg.minSpawnDistance
    );
    const pool = far.length > 0 ? far : this.spawnPoints;
    return Phaser.Utils.Array.GetRandom(pool);
  }

  get remaining() {
    return this.queue.length + this.scene.enemies.countActive(true);
  }

  emitRemaining() {
    this.scene.events.emit('enemies-left', this.remaining);
  }

  // Called by GameScene whenever an enemy dies.
  onEnemyKilled() {
    this.emitRemaining();
    if (!this.betweenWaves && this.remaining === 0) {
      this.scene.events.emit('wave-clear', this.wave);
      this.scheduleNextWave();
    }
  }
}
