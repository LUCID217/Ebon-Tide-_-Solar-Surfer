// =============================================================================
// LOADOUTS — the rows of the progression grid.
//
// A loadout defines the KIT: one weapon + one active ability. Combined with a
// class (column) it produces a grid cell. Weapon stats here are BASE values;
// the class's `mods` multipliers are applied on top when a run starts
// (see systems/build.js).
//
// Weapon fields:
//   fireRate        — shots per second (hold LMB)
//   damage          — per projectile
//   pellets         — projectiles per shot (shotguns > 1)
//   spreadDeg       — random cone half-angle in degrees
//   projectileSpeed — px/s
//   range           — px before the projectile despawns
//   sfxFreq         — placeholder audio pitch for the shot blip
//
// `ability` is an id into data/abilities.js.
// =============================================================================

export const LOADOUTS = {
  assault: {
    name: 'Assault',
    blurb: 'Full-auto rifle and a frag grenade. The all-rounder kit.',
    ability: 'grenade',
    weapon: {
      name: 'Pulse Rifle',
      fireRate: 7,
      damage: 11,
      pellets: 1,
      spreadDeg: 3.5,
      projectileSpeed: 640,
      range: 560,
      sfxFreq: 440
    }
  },

  marksman: {
    name: 'Marksman',
    blurb: 'Slow, punishing DMR and a combat dash. Keep distance, pick shots.',
    ability: 'dash',
    weapon: {
      name: 'Long Rifle',
      fireRate: 2.2,
      damage: 42,
      pellets: 1,
      spreadDeg: 0.6,
      projectileSpeed: 980,
      range: 900,
      sfxFreq: 300
    }
  },

  breacher: {
    name: 'Breacher',
    blurb: 'Scattergun and an overshield burst. Get close, survive the approach.',
    ability: 'overshield',
    weapon: {
      name: 'Scattergun',
      fireRate: 1.6,
      damage: 9,
      pellets: 7,
      spreadDeg: 11,
      projectileSpeed: 560,
      range: 260,
      sfxFreq: 200
    }
  },

  tech: {
    name: 'Tech',
    blurb: 'Rapid SMG and a deployable barricade. Make your own cover.',
    ability: 'barrier',
    weapon: {
      name: 'Needler SMG',
      fireRate: 12,
      damage: 6,
      pellets: 1,
      spreadDeg: 6,
      projectileSpeed: 580,
      range: 420,
      sfxFreq: 560
    }
  }
};
