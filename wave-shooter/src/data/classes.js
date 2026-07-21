// =============================================================================
// CLASSES — the columns of the progression grid.
//
// A class defines the CHASSIS: movement, survivability profile, and a set of
// multipliers that re-flavor whatever loadout (row) it is combined with.
// Classes should change HOW a run feels, not just raise numbers — a Wraith
// with the same loadout plays completely differently from a Juggernaut.
//
// Fields:
//   name / blurb        — shown on the roster screen
//   color               — placeholder tint for the player sprite
//   speed               — max move speed, px/s
//   health              — non-regenerating pool
//   shield              — Halo-style regenerating layer over health
//   shieldRegenDelayMs  — time without damage before shield starts refilling
//   shieldRegenRate     — shield points per second while regenerating
//   bodyScale           — sprite/hitbox scale (bigger = easier to hit)
//   mods                — multipliers applied to the equipped loadout:
//       damage, fireRate, cooldown (ability), projectileSpeed
// =============================================================================

export const CLASSES = {
  ranger: {
    name: 'Ranger',
    blurb: 'Balanced chassis. The baseline every other class deviates from.',
    color: 0x4fc3f7,
    speed: 230,
    health: 100,
    shield: 80,
    shieldRegenDelayMs: 2600,
    shieldRegenRate: 45,
    bodyScale: 1.0,
    mods: { damage: 1.0, fireRate: 1.0, cooldown: 1.0, projectileSpeed: 1.0 }
  },

  juggernaut: {
    name: 'Juggernaut',
    blurb: 'Slow and huge, hits harder, shrugs off fire. Trades escape for endurance.',
    color: 0xffb74d,
    speed: 165,
    health: 160,
    shield: 110,
    shieldRegenDelayMs: 3400,
    shieldRegenRate: 35,
    bodyScale: 1.25,
    mods: { damage: 1.25, fireRate: 0.85, cooldown: 1.2, projectileSpeed: 1.0 }
  },

  wraith: {
    name: 'Wraith',
    blurb: 'Fast and fragile. Abilities come back quicker — live in them.',
    color: 0xba68c8,
    speed: 300,
    health: 70,
    shield: 55,
    shieldRegenDelayMs: 2000,
    shieldRegenRate: 60,
    bodyScale: 0.85,
    mods: { damage: 0.85, fireRate: 1.1, cooldown: 0.65, projectileSpeed: 1.1 }
  },

  warden: {
    name: 'Warden',
    blurb: 'Shield specialist. Thin health under a deep, fast-recovering shield.',
    color: 0x81c784,
    speed: 205,
    health: 60,
    shield: 150,
    shieldRegenDelayMs: 1800,
    shieldRegenRate: 70,
    bodyScale: 1.05,
    mods: { damage: 1.0, fireRate: 0.95, cooldown: 1.0, projectileSpeed: 1.0 }
  }
};
