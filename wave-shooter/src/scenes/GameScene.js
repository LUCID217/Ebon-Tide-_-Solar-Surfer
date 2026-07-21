import Phaser from 'phaser';
import { WORLD_W, WORLD_H, DEPTHS } from '../config.js';
import { ARENAS, DEFAULT_ARENA } from '../data/arenas.js';
import { WAVE_CONFIG } from '../data/waves.js';
import { resolveBuild } from '../systems/build.js';
import InputController from '../systems/InputController.js';
import WaveDirector from '../systems/WaveDirector.js';
import { save } from '../systems/SaveManager.js';
import { sfx, unlockAudio } from '../systems/sfx.js';
import Player from '../entities/Player.js';
import Enemy from '../entities/Enemy.js';
import { makeBulletGroup } from '../entities/Projectiles.js';

export default class GameScene extends Phaser.Scene {
  constructor() { super('Game'); }

  init(data) {
    // roster passes the selected grid cell; default to saved selection
    const sel = data.cell ?? save.lastSelected;
    this.cell = sel;
    this.build = resolveBuild(sel.col, sel.row);
  }

  create() {
    const arena = ARENAS[DEFAULT_ARENA];
    this.physics.world.setBounds(0, 0, WORLD_W, WORLD_H);
    this.input.once('pointerdown', unlockAudio);

    // floor
    this.add.tileSprite(WORLD_W / 2, WORLD_H / 2, WORLD_W, WORLD_H, 'floor').setDepth(DEPTHS.floor);

    // --- cover ---
    this.coverGroup = this.physics.add.staticGroup();
    for (const c of arena.cover) this.addCover(c.x, c.y, c.w, c.h, c.type, c.hp);

    // --- player ---
    this.playerInput = new InputController(this);
    this.player = new Player(this, arena.playerStart.x, arena.playerStart.y, this.build, this.playerInput);

    // --- projectile pools ---
    this.playerBullets = makeBulletGroup(this, 128);
    this.enemyBullets = makeBulletGroup(this, 128);

    // --- enemies ---
    this.enemies = this.physics.add.group();

    // --- collisions ---
    this.physics.add.collider(this.player, this.coverGroup);
    this.physics.add.collider(this.enemies, this.coverGroup);
    this.physics.add.collider(this.enemies, this.enemies);

    // projectiles stop on cover; destructible cover takes damage
    this.physics.add.collider(this.playerBullets, this.coverGroup, this.onBulletHitsCover, null, this);
    this.physics.add.collider(this.enemyBullets, this.coverGroup, this.onBulletHitsCover, null, this);

    this.physics.add.overlap(this.playerBullets, this.enemies, this.onPlayerBulletHitsEnemy, null, this);
    this.physics.add.overlap(this.enemyBullets, this.player, this.onEnemyBulletHitsPlayer, null, this);
    this.physics.add.overlap(this.player, this.enemies, this.onEnemyTouchesPlayer, null, this);

    // --- camera ---
    this.cameras.main.setBounds(0, 0, WORLD_W, WORLD_H);
    this.cameras.main.startFollow(this.player, true, 0.12, 0.12);

    // --- fx ---
    this.hitEmitter = this.add.particles(0, 0, 'particle', {
      speed: { min: 60, max: 200 },
      lifespan: 300,
      scale: { start: 1, end: 0 },
      emitting: false
    }).setDepth(DEPTHS.fx);

    // --- run state ---
    this.score = 0;
    this.kills = 0;
    this.combo = 1;
    this.lastKillAt = -Infinity;
    this.runOver = false;

    // --- waves ---
    this.director = new WaveDirector(this, arena.spawnPoints);
    this.events.on('wave-clear', (wave) => {
      this.score += WAVE_CONFIG.score.waveClearBonus * wave;
    });
    this.events.emit('run-start', this.build);
    this.director.start();

    this.scene.launch('HUD');
    this.events.on('shutdown', () => {
      this.director.stop();
      this.scene.stop('HUD');
    });
  }

  update(time, delta) {
    const dtSec = delta / 1000;
    this.playerInput.update();
    this.player.update(time, dtSec);
    for (const e of this.enemies.getChildren()) e.update(time);

    // combo decay
    if (this.combo > 1 && time - this.lastKillAt > WAVE_CONFIG.score.comboWindowMs) {
      this.combo = 1;
    }
  }

  // --- cover -------------------------------------------------------------

  addCover(x, y, w, h, type, hp) {
    const cover = this.coverGroup.create(x, y, type);
    cover.setDisplaySize(w, h).setDepth(DEPTHS.cover);
    cover.refreshBody();
    cover.destructible = type !== 'wall';
    cover.hp = hp ?? Infinity;
    cover.maxHp = cover.hp;
    return cover;
  }

  // Deployable barricade from the Tech ability — temporary destructible cover.
  spawnBarrier(x, y, w, h, hp, lifetimeMs) {
    const barrier = this.addCover(x, y, w, h, 'barrier', hp);
    this.time.delayedCall(lifetimeMs, () => {
      if (barrier.active) this.destroyCover(barrier);
    });
    return barrier;
  }

  damageCover(cover, amount) {
    if (!cover.destructible || !cover.active) return;
    cover.hp -= amount;
    // darken as it takes damage so its state reads at a glance
    const t = Math.max(0.4, cover.hp / cover.maxHp);
    cover.setTint(Phaser.Display.Color.GetColor(255 * t, 255 * t, 255 * t));
    if (cover.hp <= 0) this.destroyCover(cover);
  }

  destroyCover(cover) {
    this.hitEmitter.explode(12, cover.x, cover.y);
    sfx.kill();
    this.coverGroup.remove(cover, true, true);
  }

  // --- collision handlers --------------------------------------------------

  onBulletHitsCover(bullet, cover) {
    if (!bullet.active) return;
    this.damageCover(cover, bullet.damage);
    this.hitEmitter.explode(3, bullet.x, bullet.y);
    bullet.kill();
  }

  onPlayerBulletHitsEnemy(bullet, enemy) {
    if (!bullet.active || !enemy.active) return;
    bullet.kill();
    this.hitEmitter.explode(4, bullet.x, bullet.y);
    enemy.takeDamage(bullet.damage);
  }

  onEnemyBulletHitsPlayer(player, bullet) {
    if (!bullet.active || !player.alive) return;
    bullet.kill();
    player.takeDamage(bullet.damage);
  }

  onEnemyTouchesPlayer(player, enemy) {
    const contact = enemy.def.contact;
    if (!contact || !enemy.active || !player.alive) return;
    if (this.time.now < enemy.nextContactAt) return;
    enemy.nextContactAt = this.time.now + contact.cooldownMs;
    player.takeDamage(contact.damage);
    // flankers dive once, then back off into orbit again
    if (enemy.def.orbit) {
      enemy.diving = false;
      enemy.orbitCloseAt = this.time.now + enemy.def.orbit.closeAfterMs;
    }
  }

  // --- spawning / combat hooks ---------------------------------------------

  spawnEnemy(type, def, x, y, mods) {
    const enemy = new Enemy(this, x, y, type, def, mods);
    this.enemies.add(enemy);
    // spawn telegraph
    const ring = this.add.circle(x, y, 26, 0xffffff, 0.25).setDepth(DEPTHS.fx);
    this.tweens.add({ targets: ring, scale: 0, duration: 250, onComplete: () => ring.destroy() });
    return enemy;
  }

  explode(x, y, radius, damage) {
    this.hitEmitter.explode(24, x, y);
    const ring = this.add.circle(x, y, radius, 0xffcc80, 0.35).setDepth(DEPTHS.fx);
    this.tweens.add({ targets: ring, alpha: 0, scale: 1.2, duration: 260, onComplete: () => ring.destroy() });
    this.cameras.main.shake(160, 0.012);
    sfx.explosion();

    for (const enemy of [...this.enemies.getChildren()]) {
      if (!enemy.active) continue;
      if (Phaser.Math.Distance.Between(x, y, enemy.x, enemy.y) <= radius + enemy.displayWidth / 2) {
        enemy.takeDamage(damage);
      }
    }
    // explosions chew through destructible cover too
    for (const cover of [...this.coverGroup.getChildren()]) {
      if (cover.destructible && Phaser.Math.Distance.Between(x, y, cover.x, cover.y) <= radius) {
        this.damageCover(cover, damage);
      }
    }
  }

  muzzleFlash(x, y) {
    const flash = this.add.circle(x, y, 7, 0xfff59d, 0.9).setDepth(DEPTHS.fx);
    this.time.delayedCall(40, () => flash.destroy());
  }

  onEnemyKilled(enemy) {
    this.kills++;
    // combo multiplier: chain kills inside the window to bank more score
    const now = this.time.now;
    if (now - this.lastKillAt <= WAVE_CONFIG.score.comboWindowMs) {
      this.combo = Math.min(WAVE_CONFIG.score.comboMax, this.combo + 1);
    }
    this.lastKillAt = now;
    this.score += enemy.scoreValue * this.combo;

    this.hitEmitter.explode(10, enemy.x, enemy.y);
    this.cameras.main.shake(60, 0.004);
    sfx.kill();
    this.director.onEnemyKilled();
  }

  onPlayerDamaged() {
    this.cameras.main.shake(90, 0.008);
    this.cameras.main.flash(60, 120, 0, 0);
  }

  onPlayerDied() {
    if (this.runOver) return;
    this.runOver = true;
    this.director.stop();
    sfx.gameOver();
    this.hitEmitter.explode(30, this.player.x, this.player.y);
    this.cameras.main.shake(400, 0.02);

    const summary = {
      score: this.score,
      wave: this.director.wave,
      kills: this.kills,
      cell: this.cell
    };
    save.recordRun({ score: this.score, wave: this.director.wave });

    this.time.delayedCall(1200, () => {
      this.scene.stop('HUD');
      this.scene.start('GameOver', summary);
    });
  }
}
