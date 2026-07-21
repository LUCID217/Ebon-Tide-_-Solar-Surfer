// =============================================================================
// WAVE DIRECTOR CONFIG — waves are composed from a point budget, not authored
// per-wave, so difficulty tuning is a data edit.
//
// Budget for wave N = baseBudget + budgetGrowth * (N - 1) ^ budgetPower.
// The director spends that budget on enemy types whose `fromWave` has been
// reached, weighted by `weight`. Cost = how much budget one spawn consumes.
//
// Modifiers kick in from `modifiers.fromWave`: each wave after that picks one
// at random (weighted) and applies its effects for that wave only.
// =============================================================================

export const WAVE_CONFIG = {
  baseBudget: 5,
  budgetGrowth: 3.0,
  budgetPower: 1.18,

  breatherMs: 3800,      // pause between waves
  spawnIntervalMs: 550,  // trickle-spawn gap so waves don't appear all at once
  maxAlive: 26,          // hard cap on simultaneous enemies
  minSpawnDistance: 340, // never spawn a point this close to the player

  // Enemy roster availability & budget costs.
  roster: [
    { type: 'rusher',  fromWave: 1, cost: 1,  weight: 10 },
    { type: 'shooter', fromWave: 3, cost: 3,  weight: 6 },
    { type: 'flanker', fromWave: 5, cost: 2,  weight: 4 },
    { type: 'heavy',   fromWave: 7, cost: 8,  weight: 3 }
  ],

  // Guarantee some minimum variety once types are unlocked: every Nth wave
  // forces at least one of the type in, budget permitting.
  guarantees: [
    { type: 'heavy', everyNWaves: 3, fromWave: 7 }
  ],

  modifiers: {
    fromWave: 5,
    pool: [
      {
        id: 'frenzy',
        name: 'FRENZY',
        desc: 'Enemies move 30% faster',
        weight: 4,
        effects: { enemySpeedMult: 1.3 }
      },
      {
        id: 'armored',
        name: 'ARMORED',
        desc: 'Enemies have 40% more HP',
        weight: 4,
        effects: { enemyHpMult: 1.4 }
      },
      {
        id: 'horde',
        name: 'HORDE',
        desc: 'More enemies, but weaker',
        weight: 3,
        effects: { budgetMult: 1.5, enemyHpMult: 0.8 }
      },
      {
        id: 'heavies',
        name: 'HEAVY DROP',
        desc: 'Extra heavies inbound',
        weight: 2,
        effects: { extraSpawns: [{ type: 'heavy', count: 2 }] }
      }
    ]
  },

  // Scoring
  score: {
    waveClearBonus: 100,        // * wave number
    comboWindowMs: 3500,        // kills within this window grow the multiplier
    comboMax: 5
  }
};
