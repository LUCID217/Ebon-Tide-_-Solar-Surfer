import Phaser from 'phaser';

// =============================================================================
// BootScene — generates placeholder textures so the game runs with zero asset
// files. This doubles as the ASSET MANIFEST: every texture key the game uses
// is created here. To swap in real art, replace a generateTexture block with
// this.load.image(key, url) in preload() — nothing else changes.
//
// Texture keys:
//   player        — 36x32, white (tinted per class), barrel points +X
//   enemy_rusher  — red wedge
//   enemy_shooter — orange gunner
//   enemy_heavy   — dark red slab
//   enemy_flanker — magenta dart
//   bullet        — small white round (tinted per side)
//   grenade       — olive ball
//   crate         — brown destructible cover
//   wall          — gray indestructible cover (stretched per layout)
//   barrier       — cyan deployable cover
//   floor         — dark 64px tile
//   particle      — 6px white square for all fx
// =============================================================================

export default class BootScene extends Phaser.Scene {
  constructor() { super('Boot'); }

  create() {
    const g = this.add.graphics();

    // player: white circle + barrel (rotation 0 faces +X), tinted per class
    g.clear().fillStyle(0xffffff);
    g.fillCircle(16, 16, 14);
    g.fillRect(16, 12, 18, 8);
    g.generateTexture('player', 36, 32);

    // rusher: wedge charging right
    g.clear().fillStyle(0xef5350);
    g.fillTriangle(0, 0, 28, 14, 0, 28);
    g.lineStyle(2, 0xb71c1c).strokeTriangle(0, 0, 28, 14, 0, 28);
    g.generateTexture('enemy_rusher', 28, 28);

    // shooter: square body + barrel
    g.clear().fillStyle(0xffa726);
    g.fillRect(2, 4, 22, 22);
    g.fillRect(14, 11, 16, 8);
    g.lineStyle(2, 0xe65100).strokeRect(2, 4, 22, 22);
    g.generateTexture('enemy_shooter', 30, 30);

    // heavy: big slab
    g.clear().fillStyle(0x8e2424);
    g.fillRoundedRect(1, 1, 42, 42, 8);
    g.lineStyle(3, 0x4a0f0f).strokeRoundedRect(1, 1, 42, 42, 8);
    g.fillStyle(0xd32f2f).fillRect(20, 16, 22, 12);
    g.generateTexture('enemy_heavy', 44, 44);

    // flanker: dart
    g.clear().fillStyle(0xd81be0);
    g.fillTriangle(0, 6, 26, 13, 0, 20);
    g.fillTriangle(6, 0, 14, 13, 6, 26);
    g.generateTexture('enemy_flanker', 26, 26);

    // bullet
    g.clear().fillStyle(0xffffff);
    g.fillCircle(5, 5, 4);
    g.generateTexture('bullet', 10, 10);

    // grenade
    g.clear().fillStyle(0x7a8a3a);
    g.fillCircle(6, 6, 5);
    g.lineStyle(1, 0x2f3a12).strokeCircle(6, 6, 5);
    g.generateTexture('grenade', 12, 12);

    // crate (destructible)
    g.clear().fillStyle(0x8d6e46);
    g.fillRect(0, 0, 48, 48);
    g.lineStyle(3, 0x5d4428).strokeRect(1, 1, 46, 46);
    g.lineStyle(2, 0x5d4428);
    g.lineBetween(0, 0, 48, 48).lineBetween(48, 0, 0, 48);
    g.generateTexture('crate', 48, 48);

    // wall (indestructible, stretched via setDisplaySize)
    g.clear().fillStyle(0x5c6570);
    g.fillRect(0, 0, 64, 64);
    g.lineStyle(4, 0x39404a).strokeRect(2, 2, 60, 60);
    g.generateTexture('wall', 64, 64);

    // deployable barrier
    g.clear().fillStyle(0x26c6da);
    g.fillRect(0, 0, 64, 64);
    g.lineStyle(4, 0x00838f).strokeRect(2, 2, 60, 60);
    g.generateTexture('barrier', 64, 64);

    // floor tile
    g.clear().fillStyle(0x151a22);
    g.fillRect(0, 0, 64, 64);
    g.lineStyle(1, 0x1d2430);
    g.strokeRect(0, 0, 64, 64);
    g.generateTexture('floor', 64, 64);

    // generic fx particle
    g.clear().fillStyle(0xffffff);
    g.fillRect(0, 0, 6, 6);
    g.generateTexture('particle', 6, 6);

    g.destroy();
    this.scene.start('Roster');
  }
}
