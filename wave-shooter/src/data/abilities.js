// =============================================================================
// ABILITIES — data definitions referencing a small library of behaviors.
//
// `behavior` must match a function registered in systems/AbilitySystem.js.
// Everything else is tuning data passed to that behavior. Cooldowns are BASE
// values; the class `cooldown` modifier scales them.
// =============================================================================

export const ABILITIES = {
  grenade: {
    name: 'Frag Grenade',
    behavior: 'grenade',
    cooldownMs: 6000,
    // grenade tuning
    damage: 70,
    radius: 110,
    throwSpeed: 520,   // px/s of the lobbed grenade
    maxThrow: 480      // max throw distance
  },

  dash: {
    name: 'Combat Dash',
    behavior: 'dash',
    cooldownMs: 3200,
    speedMult: 3.4,    // dash velocity = move speed * this
    durationMs: 160,
    // dashing grants brief invulnerability — the whole point of the ability
    iframesMs: 260
  },

  overshield: {
    name: 'Overshield Burst',
    behavior: 'overshield',
    cooldownMs: 9000,
    amount: 90,        // temporary shield points layered over normal shield
    durationMs: 5000   // decays to zero over this window
  },

  barrier: {
    name: 'Deployable Barricade',
    behavior: 'barrier',
    cooldownMs: 8000,
    hp: 160,           // barricade is destructible cover
    lifetimeMs: 12000,
    width: 84,
    height: 18,
    distance: 56       // spawned this far from the player, facing the cursor
  }
};
