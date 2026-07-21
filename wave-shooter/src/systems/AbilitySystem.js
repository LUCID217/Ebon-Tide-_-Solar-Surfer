import Phaser from 'phaser';
import { DEPTHS } from '../config.js';
import { sfx } from './sfx.js';

// =============================================================================
// Ability behavior library. Ability DEFINITIONS live in data/abilities.js and
// reference one of these behaviors by name; new abilities that reuse existing
// behaviors are pure data additions.
//
// Each behavior is (scene, player, def) => void, fired when the player
// activates their ability off cooldown. `scene` is GameScene, which exposes:
//   scene.enemies        — enemy physics group
//   scene.spawnBarrier() — adds a temporary destructible cover object
//   scene.explode()      — AoE damage + fx at a point
// =============================================================================

const behaviors = {
  dash(scene, player, def) {
    const dirX = player.input.moveX || Math.cos(player.rotation);
    const dirY = player.input.moveY || Math.sin(player.rotation);
    const len = Math.hypot(dirX, dirY) || 1;
    const speed = player.build.speed * def.speedMult;
    player.body.velocity.set((dirX / len) * speed, (dirY / len) * speed);
    player.dashUntil = scene.time.now + def.durationMs;
    player.invulnUntil = scene.time.now + def.iframesMs;
    player.setAlpha(0.5);
    scene.time.delayedCall(def.iframesMs, () => player.active && player.setAlpha(1));
    sfx.dash();
  },

  grenade(scene, player, def) {
    // lob toward the cursor, capped at maxThrow, exploding on arrival
    const dx = player.input.aimX - player.x;
    const dy = player.input.aimY - player.y;
    const dist = Math.min(Math.hypot(dx, dy) || 1, def.maxThrow);
    const angle = Math.atan2(dy, dx);
    const tx = player.x + Math.cos(angle) * dist;
    const ty = player.y + Math.sin(angle) * dist;

    const nade = scene.add.image(player.x, player.y, 'grenade').setDepth(DEPTHS.projectile);
    const flightMs = (dist / def.throwSpeed) * 1000;
    scene.tweens.add({
      targets: nade,
      x: tx, y: ty,
      scale: { from: 1, to: 1.6, yoyo: true }, // fake arc via scale bump
      duration: Math.max(flightMs, 120),
      onComplete: () => {
        nade.destroy();
        scene.explode(tx, ty, def.radius, def.damage);
      }
    });
    sfx.deploy();
  },

  overshield(scene, player, def) {
    player.overshield = def.amount;
    player.overshieldMax = def.amount;
    player.overshieldDecay = def.amount / (def.durationMs / 1000); // pts per sec
    sfx.shieldUp();
  },

  barrier(scene, player, def) {
    const angle = Math.atan2(player.input.aimY - player.y, player.input.aimX - player.x);
    const bx = player.x + Math.cos(angle) * def.distance;
    const by = player.y + Math.sin(angle) * def.distance;
    // barricade faces the cursor: perpendicular wall between player and threat
    const horizontal = Math.abs(Math.cos(angle)) < Math.abs(Math.sin(angle));
    const w = horizontal ? def.width : def.height;
    const h = horizontal ? def.height : def.width;
    scene.spawnBarrier(bx, by, w, h, def.hp, def.lifetimeMs);
    sfx.deploy();
  }
};

export function runAbility(scene, player, def) {
  const fn = behaviors[def.behavior];
  if (!fn) {
    console.warn(`Unknown ability behavior: ${def.behavior}`);
    return;
  }
  fn(scene, player, def);
}
