import Phaser from 'phaser';
import { DEPTHS } from '../config.js';
import { runAbility } from '../systems/AbilitySystem.js';
import { sfx } from '../systems/sfx.js';

// The player avatar. All stats come from the resolved build (systems/build.js)
// — nothing here is hardcoded to a specific class or loadout.
export default class Player extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, x, y, build, input) {
    super(scene, x, y, 'player');
    this.build = build;
    this.input = input;

    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setDepth(DEPTHS.player);
    this.setScale(build.bodyScale);
    this.setTint(build.color);
    this.body.setCircle(14).setOffset(2, 2);
    this.setCollideWorldBounds(true);

    // vitals
    this.health = build.health;
    this.shield = build.shield;
    this.overshield = 0;
    this.overshieldMax = 0;
    this.overshieldDecay = 0;
    this.lastDamagedAt = -Infinity;
    this.invulnUntil = 0;
    this.dashUntil = 0;

    // weapon / ability timers
    this.nextShotAt = 0;
    this.abilityReadyAt = 0;

    this.tookDamageThisWave = false; // for scoring hooks later
  }

  get alive() { return this.health > 0; }

  update(time, dtSec) {
    if (!this.alive) return;
    const { build, input } = this;

    // --- movement (dash overrides normal steering while active) ---
    if (time > this.dashUntil) {
      this.body.velocity.set(input.moveX * build.speed, input.moveY * build.speed);
    }

    // --- aim: rotate toward the cursor, independent of movement ---
    this.setRotation(Phaser.Math.Angle.Between(this.x, this.y, input.aimX, input.aimY));

    // --- shooting ---
    if (input.firing && time >= this.nextShotAt) {
      this.shoot(time);
    }

    // --- ability ---
    if (input.abilityHeld && time >= this.abilityReadyAt) {
      this.abilityReadyAt = time + build.ability.cooldownMs;
      runAbility(this.scene, this, build.ability);
    }

    // --- overshield decay ---
    if (this.overshield > 0) {
      this.overshield = Math.max(0, this.overshield - this.overshieldDecay * dtSec);
    }

    // --- shield regen after a quiet window ---
    if (this.shield < build.shield && time - this.lastDamagedAt > build.shieldRegenDelayMs) {
      this.shield = Math.min(build.shield, this.shield + build.shieldRegenRate * dtSec);
    }
  }

  shoot(time) {
    const w = this.build.weapon;
    this.nextShotAt = time + 1000 / w.fireRate;

    const muzzleDist = 18 * this.build.bodyScale;
    const baseAngle = this.rotation;
    const mx = this.x + Math.cos(baseAngle) * muzzleDist;
    const my = this.y + Math.sin(baseAngle) * muzzleDist;

    for (let i = 0; i < w.pellets; i++) {
      const spread = Phaser.Math.DegToRad(w.spreadDeg);
      const angle = baseAngle + Phaser.Math.FloatBetween(-spread, spread);
      const bullet = this.scene.playerBullets.get(mx, my);
      if (bullet) bullet.fire(mx, my, angle, w.projectileSpeed, w.damage, w.range, 0xfff59d);
    }

    sfx.shot(w.sfxFreq);
    this.scene.muzzleFlash(mx, my);
    // tiny kick opposite the shot — cheap game feel
    this.x -= Math.cos(baseAngle) * 1.5;
    this.y -= Math.sin(baseAngle) * 1.5;
  }

  takeDamage(amount) {
    if (!this.alive || this.scene.time.now < this.invulnUntil) return;
    this.lastDamagedAt = this.scene.time.now;
    this.tookDamageThisWave = true;

    // damage order: overshield -> shield -> health
    if (this.overshield > 0) {
      const absorbed = Math.min(this.overshield, amount);
      this.overshield -= absorbed;
      amount -= absorbed;
    }
    if (amount > 0 && this.shield > 0) {
      const absorbed = Math.min(this.shield, amount);
      this.shield -= absorbed;
      amount -= absorbed;
      if (this.shield <= 0) sfx.shieldDown();
    }
    if (amount > 0) {
      this.health -= amount;
      sfx.playerHurt();
    }

    this.scene.onPlayerDamaged();
    if (this.health <= 0) {
      this.health = 0;
      this.die();
    }
  }

  die() {
    this.body.enable = false;
    this.setActive(false);
    this.setVisible(false);
    this.scene.onPlayerDied();
  }
}
