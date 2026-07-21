import Phaser from 'phaser';
import { DEPTHS } from '../config.js';
import { hasLineOfSight, findCoverPoint } from '../systems/los.js';
import { sfx } from '../systems/sfx.js';

// Data-driven enemy with a simple state machine:
//   seek -> attack -> seekCover/reposition -> (dead)
// No pathfinding: direct steering + arcade collision sliding along cover is
// enough for an open arena. All stats come from data/enemies.js; wave
// modifiers scale hp/speed at spawn time.
export default class Enemy extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, x, y, type, def, mods = {}) {
    super(scene, x, y, def.texture);
    this.type = type;
    this.def = def;

    scene.add.existing(this);
    scene.physics.add.existing(this);
    this.setDepth(DEPTHS.enemy);
    this.setScale(def.bodyScale);
    this.body.setCircle(this.width / 2 * 0.8, this.width * 0.1, this.height * 0.1);
    this.setCollideWorldBounds(true);

    this.hp = def.hp * (mods.enemyHpMult ?? 1);
    this.maxHp = this.hp;
    this.speed = def.speed * (mods.enemySpeedMult ?? 1);
    this.scoreValue = def.score;

    this.state = 'seek';
    this.nextContactAt = 0;   // melee cooldown
    this.nextBurstAt = scene.time.now + Phaser.Math.Between(400, 1200);
    this.burstShotsLeft = 0;
    this.nextBurstShotAt = 0;
    this.coverPoint = null;
    this.coverUntil = 0;
    this.orbitDir = Math.random() < 0.5 ? 1 : -1;
    this.orbitCloseAt = def.orbit ? scene.time.now + def.orbit.closeAfterMs : 0;
    this.diving = false;
  }

  update(time) {
    if (!this.active) return;
    const player = this.scene.player;
    if (!player.alive) {
      this.body.velocity.set(0, 0);
      return;
    }

    const dist = Phaser.Math.Distance.Between(this.x, this.y, player.x, player.y);
    this.setRotation(Phaser.Math.Angle.Between(this.x, this.y, player.x, player.y));

    if (this.def.weapon) {
      this.updateRanged(time, player, dist);
    } else if (this.def.orbit && !this.diving) {
      this.updateOrbit(time, player, dist);
    } else {
      this.steerToward(player.x, player.y);
    }

    // melee contact damage handled via overlap in GameScene; cooldown here
  }

  // --- behaviors -------------------------------------------------------

  updateOrbit(time, player, dist) {
    // circle at radius, then commit to a dive
    if (time >= this.orbitCloseAt) {
      this.diving = true;
      return;
    }
    const o = this.def.orbit;
    const angle = Phaser.Math.Angle.Between(player.x, player.y, this.x, this.y);
    const targetAngle = angle + this.orbitDir * 0.55;
    const tx = player.x + Math.cos(targetAngle) * o.radius;
    const ty = player.y + Math.sin(targetAngle) * o.radius;
    this.steerToward(tx, ty);
  }

  updateRanged(time, player, dist) {
    const w = this.def.weapon;
    const los = hasLineOfSight(this.x, this.y, player.x, player.y, this.scene.coverGroup);

    // fire ongoing burst regardless of state
    if (this.burstShotsLeft > 0 && time >= this.nextBurstShotAt) {
      this.fireShot(player, w);
      this.burstShotsLeft--;
      this.nextBurstShotAt = time + w.burstIntervalMs;
      if (this.burstShotsLeft === 0) {
        this.nextBurstAt = time + w.cooldownMs;
        // after a burst, cover-users duck behind something
        if (this.def.usesCover) this.pickCover(player);
      }
    }

    switch (this.state) {
      case 'seek': {
        if (los && dist <= this.def.preferredRange * 1.15) {
          this.state = 'attack';
          this.body.velocity.set(0, 0);
        } else {
          this.steerToward(player.x, player.y);
        }
        break;
      }
      case 'attack': {
        if (!los || dist > this.def.preferredRange * 1.6) {
          this.state = 'seek';
          break;
        }
        // hold position (drift to keep range), start bursts on cooldown
        if (dist < this.def.preferredRange * 0.6) {
          this.steerToward(this.x * 2 - player.x, this.y * 2 - player.y, 0.6); // back away
        } else {
          this.body.velocity.set(0, 0);
        }
        if (time >= this.nextBurstAt && this.burstShotsLeft === 0) {
          this.burstShotsLeft = w.burst;
          this.nextBurstShotAt = time; // first shot immediately
        }
        break;
      }
      case 'cover': {
        if (!this.coverPoint || time > this.coverUntil) {
          this.state = 'seek';
          break;
        }
        const d = Phaser.Math.Distance.Between(this.x, this.y, this.coverPoint.x, this.coverPoint.y);
        if (d < 12) {
          this.body.velocity.set(0, 0);
          // pop back out when the next burst is ready
          if (time >= this.nextBurstAt) this.state = 'seek';
        } else {
          this.steerToward(this.coverPoint.x, this.coverPoint.y);
        }
        break;
      }
    }
  }

  pickCover(player) {
    const point = findCoverPoint(this.x, this.y, player.x, player.y, this.scene.coverGroup);
    if (point) {
      this.coverPoint = point;
      this.coverUntil = this.scene.time.now + this.def.weapon.cooldownMs + 600;
      this.state = 'cover';
    }
  }

  fireShot(player, w) {
    const spread = Phaser.Math.DegToRad(w.spreadDeg);
    const angle = Phaser.Math.Angle.Between(this.x, this.y, player.x, player.y)
      + Phaser.Math.FloatBetween(-spread, spread);
    const bullet = this.scene.enemyBullets.get(this.x, this.y);
    if (bullet) bullet.fire(this.x, this.y, angle, w.projectileSpeed, w.damage, w.range, 0xff8a80);
    sfx.enemyShot();
  }

  steerToward(tx, ty, speedMult = 1) {
    const angle = Phaser.Math.Angle.Between(this.x, this.y, tx, ty);
    this.body.velocity.set(
      Math.cos(angle) * this.speed * speedMult,
      Math.sin(angle) * this.speed * speedMult
    );
  }

  // --- damage ----------------------------------------------------------

  takeDamage(amount) {
    if (!this.active) return;
    this.hp -= amount;

    // hit flash
    this.setTintFill(0xffffff);
    this.scene.time.delayedCall(50, () => this.active && this.clearTint());
    sfx.hit();

    // being shot pushes cover-seekers to relocate
    if (this.def.usesCover && this.hp < this.maxHp * 0.5 && this.state === 'attack') {
      this.pickCover(this.scene.player);
    }

    if (this.hp <= 0) this.die();
  }

  die() {
    this.scene.onEnemyKilled(this);
    this.destroy();
  }
}
