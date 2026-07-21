import Phaser from 'phaser';
import { DEPTHS, BULLET_LIFETIME_MS } from '../config.js';

// Pooled projectile. One Bullet class serves both player and enemy fire —
// which group it lives in decides what it collides with.
// Extends Arcade.Sprite (not Image) so preUpdate exists on the super chain
// and the update list drives lifetime/range checks.
export class Bullet extends Phaser.Physics.Arcade.Sprite {
  constructor(scene, x, y) {
    super(scene, x, y, 'bullet');
    this.damage = 0;
    this.rangeSq = 0;
    this.startX = 0;
    this.startY = 0;
    this.setDepth(DEPTHS.projectile);
  }

  fire(x, y, angle, speed, damage, range, tint) {
    this.enableBody(true, x, y, true, true);
    this.startX = x;
    this.startY = y;
    this.damage = damage;
    this.rangeSq = range * range;
    this.setRotation(angle);
    this.setTint(tint);
    this.body.setSize(8, 8, true);
    this.scene.physics.velocityFromRotation(angle, speed, this.body.velocity);
    this.lifeEnd = this.scene.time.now + BULLET_LIFETIME_MS;
  }

  kill() {
    this.disableBody(true, true);
  }

  preUpdate(time, delta) {
    super.preUpdate(time, delta);
    if (!this.active) return;
    const dx = this.x - this.startX;
    const dy = this.y - this.startY;
    if (dx * dx + dy * dy > this.rangeSq || time > this.lifeEnd) this.kill();
  }
}

export function makeBulletGroup(scene, maxSize) {
  return scene.physics.add.group({
    classType: Bullet,
    maxSize,
    runChildUpdate: false // preUpdate runs automatically for active children
  });
}
