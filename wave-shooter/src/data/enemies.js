// =============================================================================
// ENEMIES — all enemy stats live here as data. Adding a new enemy type means
// adding an entry here (plus a texture key in BootScene), not new systems.
//
// Fields:
//   hp / speed          — pool and max px/s
//   bodyScale           — sprite/hitbox scale
//   score               — points on kill (feeds the unlock currency)
//   texture             — placeholder texture key generated in BootScene
//   contact             — melee: { damage, cooldownMs } dealt on touch
//   weapon              — ranged: projectile stats + burst pattern
//   usesCover           — shooter-style: seeks a position behind cover
//                         relative to the player between bursts
//   preferredRange      — ranged: tries to hover near this distance
//   orbit               — flanker-style: circles the player instead of
//                         charging straight in
// =============================================================================

export const ENEMIES = {
  rusher: {
    name: 'Rusher',
    hp: 30,
    speed: 190,
    bodyScale: 1.0,
    score: 50,
    texture: 'enemy_rusher',
    contact: { damage: 14, cooldownMs: 650 },
    usesCover: false
  },

  shooter: {
    name: 'Shooter',
    hp: 55,
    speed: 140,
    bodyScale: 1.0,
    score: 100,
    texture: 'enemy_shooter',
    usesCover: true,
    preferredRange: 330,
    weapon: {
      damage: 9,
      projectileSpeed: 380,
      burst: 3,             // shots per burst
      burstIntervalMs: 160, // gap between shots inside a burst
      cooldownMs: 1700,     // gap between bursts
      spreadDeg: 4,
      range: 620
    }
  },

  heavy: {
    name: 'Heavy',
    hp: 260,
    speed: 70,
    bodyScale: 1.6,
    score: 250,
    texture: 'enemy_heavy',
    usesCover: false,       // pressure unit: walks straight through the fight
    preferredRange: 240,
    contact: { damage: 30, cooldownMs: 900 },
    weapon: {
      damage: 22,
      projectileSpeed: 300,
      burst: 1,
      burstIntervalMs: 0,
      cooldownMs: 1500,
      spreadDeg: 2,
      range: 700
    }
  },

  flanker: {
    name: 'Flanker',
    hp: 40,
    speed: 260,
    bodyScale: 0.9,
    score: 150,
    texture: 'enemy_flanker',
    contact: { damage: 10, cooldownMs: 500 },
    usesCover: false,
    orbit: { radius: 180, closeAfterMs: 2200 } // circles, then dives in
  }
};
