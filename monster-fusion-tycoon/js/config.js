// ============================================================================
// CONFIG — THE tuning file.
// Every balance knob in the game lives here, grouped the way a designer tunes:
//   FUSION / ECONOMY / RARITY / HABITATS / SHOP / OBJECTIVES / SAVE.
// Nothing below should require hunting through code to rebalance.
// ============================================================================

export const CONFIG = {

  // --------------------------------------------------------------------------
  // FUSION — costs, timing, inheritance variance, mutation
  // --------------------------------------------------------------------------
  fusion: {
    baseCostCoins: 50,          // coin cost of a tier-1 fusion...
    costCoinsPerTier: 60,       // ...+ this per (combined parent tier)
    baseCostEssence: 5,         // essence cost of a tier-1 fusion...
    costEssencePerTier: 4,      // ...+ this per (combined parent tier)
    baseTimeSec: 6,             // fusion resolve time at tier 1 (kept short: it's drama, not a wall)
    timePerTierSec: 4,          // + seconds per combined parent tier
    maxTimeSec: 90,             // hard cap so deep fusions never feel punitive

    statVariance: 0.25,         // stats inherit parent avg ±25% (uniform)
    statTierBonus: 0.06,        // +6% flat stat growth per child tier (fusion should trend upward)
    statCap: 999,               // absolute stat ceiling

    maxElements: 3,             // hybrids carry at most this many elements
    mutationChance: 0.12,       // chance a fusion gains an element NEITHER parent has (keeps the tree open-ended)
    archetypeShiftChance: 0.22, // chance the child's body archetype differs from both parents
    maxTier: 12,                // creatures at this tier can no longer be fused (endgame trophies)

    // Volatile pairings: fusing OPPOSING elements is unstable — higher
    // mutation odds and a flat stat surge. Rewards breeding across the
    // elemental wheel instead of stacking one element forever.
    volatilePairs: [['fire', 'water'], ['light', 'shadow'], ['earth', 'air']],
    volatileMutationBonus: 0.25, // added to mutationChance when a pair opposes
    volatileStatBonus: 0.10,     // ×1.10 to all child stats per opposing pair
  },

  // --------------------------------------------------------------------------
  // ECONOMY — passive revenue, maintenance, happiness, offline progress
  // --------------------------------------------------------------------------
  economy: {
    tickSeconds: 1,             // simulation granularity
    // Revenue: coins/sec = rarityBase * (power/100) * happinessMult * habitatQualityMult * traits
    rarityRevenuePerSec: {      // base coins/sec by rarity (before all multipliers)
      common: 1.0, uncommon: 2.5, rare: 6.5, epic: 16, legendary: 42, mythic: 110,
    },
    // Maintenance: coins/sec drained per creature. Scales super-linearly with
    // rarity so top creatures are only worth keeping if well-managed.
    // ON-RAMP: commons are FREE to keep — a new player's roster can never
    // bleed them dry. Upkeep is a mechanic you grow into as you fuse upward.
    // NOTE: creatures housed in a SANCTUARY biome (see habitats.sanctuaryBiomes)
    // bill NO upkeep at all — the meadow is the safe sandbox.
    rarityMaintenancePerSec: {
      common: 0, uncommon: 0.25, rare: 1.2, epic: 4, legendary: 14, mythic: 45,
    },
    vitalityMaintDiscount: 0.5, // at vitality 100, maintenance is reduced by up to 50%
    happinessRevenueCurve: 1.3, // revenueMult = (happiness/100)^this — unhappy creatures crater fast
    unhappyThreshold: 25,       // below this happiness, a creature earns NOTHING (still costs maintenance!)

    // Happiness drivers (recomputed continuously, 0..100):
    happinessBase: 55,
    happinessElementMatch: 25,  // habitat biome matches one of creature's elements
    happinessCrowdPenalty: 14,  // full habitat: up to -14 scaled by fill (a squeeze, not a death trap)
    happinessCharmFactor: 0.2,  // + charm * this
    happinessDecorPer: 4,       // + per decoration in the habitat (see habitats.maxDecorations)

    collectCapSeconds: 3600,    // uncollected revenue pool caps at 1 hour of income
    offlineCapSeconds: 7200,    // offline progress simulated up to 2 hours
    startingCoins: 250,
    startingEssence: 20,
    startingRelics: 0,
    essenceTricklePerCollect: 1, // small essence gain each manual collect (grind loop beyond fusion)

    // Selling/retiring creatures (also the anti-softlock valve — you can
    // always liquidate a money-losing monster):
    sellValueByRarity: {
      common: 30, uncommon: 90, rare: 300, epic: 1000, legendary: 3200, mythic: 10000,
    },
    sellValuePerTier: 25,       // + coins per tier above 1
    discoveryEssenceBonus: 5,   // essence granted whenever a NEW species is logged
  },

  // --------------------------------------------------------------------------
  // TRAITS — how many passive traits each rarity carries: [boons, burdens].
  // Burden counts are the "power tax": legendary+ creatures are net-NEGATIVE
  // if parked carelessly. Trait effect numbers live in traits.js definitions.
  // --------------------------------------------------------------------------
  traits: {
    countsByRarity: {
      common: [0, 0], uncommon: [1, 0], rare: [1, 0],
      epic: [2, 1], legendary: [2, 1], mythic: [3, 2],
    },
  },

  // --------------------------------------------------------------------------
  // RARITY — odds, spikes, colors
  // --------------------------------------------------------------------------
  rarity: {
    order: ['common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'],
    // Fusion child rarity: start from the HIGHER parent rarity, then roll:
    upgradeChance: 0.20,        // chance to spike +1 tier
    doubleUpgradeChance: 0.04,  // chance to spike +2 tiers (checked first)
    downgradeChance: 0.10,      // chance to drop -1 (fusion isn't free progress)
    elementDiversityBonus: 0.05,// + to upgradeChance per element the child has beyond 1
    colors: {                   // UI accent per rarity (borders, glows, log entries)
      common: '#9aa5b1', uncommon: '#4caf7d', rare: '#4a90d9',
      epic: '#a45de2', legendary: '#e8a33d', mythic: '#e84d6f',
    },
    eggWeights: {               // rarity odds when buying a base egg from the shop.
      // Commons/uncommons ONLY: eggs are raw material — FUSION is the rarity
      // engine. A new player must never be handed an upkeep bomb by the shop.
      common: 75, uncommon: 25, rare: 0, epic: 0, legendary: 0, mythic: 0,
    },
  },

  // --------------------------------------------------------------------------
  // HABITATS — biomes, capacity, upgrade & expansion costs
  // --------------------------------------------------------------------------
  habitats: {
    baseCapacity: 3,            // creature slots at level 1
    capacityPerLevel: 1,        // + slots per upgrade level
    maxLevel: 8,
    baseQualityMult: 1.0,       // revenue multiplier at level 1...
    qualityPerLevel: 0.15,      // ...+15% per level
    upgradeBaseCost: 200,       // coins for level 1→2...
    upgradeCostGrowth: 1.9,     // ...×1.9 each further level (exponential wall)
    newHabitatBaseCost: 400,    // coins for your 2nd habitat...
    newHabitatCostGrowth: 2.2,  // ...×2.2 each additional habitat
    maxHabitats: 10,
    maxDecorations: 5,          // decoration slots per habitat
    decorationCost: 120,        // coins per decoration (each adds economy.happinessDecorPer happiness)
    themedExhibitBonus: 0.25,   // +25% habitat revenue when 2+ residents all share an element
    rebiomeCostPerLevel: 150,   // coins per habitat level to convert its biome (keeps upgrades)

    // SANCTUARIES — the safe sandbox at the heart of the on-ramp.
    // Creatures housed in these biomes bill ZERO upkeep, so a new player can
    // buy eggs and fuse freely without ever going broke. The trade-off:
    // exotic creatures (rare+) only earn a fraction there — serious income
    // means moving them to elemental habitats and accepting the upkeep bill.
    sanctuaryBiomes: ['meadow'],
    sanctuaryExoticRevenueMult: 0.5, // rare+ earn this fraction inside a sanctuary
    // Biomes a habitat can be built as. 'meadow' is neutral (no element match bonus).
    biomes: ['meadow', 'fire', 'water', 'earth', 'air', 'nature', 'shadow', 'light', 'storm'],
  },

  // --------------------------------------------------------------------------
  // SHOP — eggs, resource exchange rates, staff/automation
  // --------------------------------------------------------------------------
  shop: {
    eggCostCoins: 100,          // a base (tier-1, random element) creature egg
    eggCostGrowth: 1.15,        // egg price ×1.15 per egg ever bought (soft cap on egg spam)
    // Exchange rates (all conversions are lossy — relics are precious):
    coinsPerEssence: 15,        // sell 1 essence for this many coins
    essenceCostCoins: 25,       // buy 1 essence for this many coins (worse than selling — intended)
    essencePerRelic: 40,        // break 1 relic into essence
    relicCostEssence: 120,      // trade essence up into 1 relic (steep!)
    // Radiant egg — a relic sink that guarantees a high-rarity base creature.
    // GATED: locked until the player has fused enough to understand upkeep —
    // early milestone relics must not buy a money-pit on day one.
    radiantEggRelics: 1,
    radiantEggUnlockFusions: 15,
    radiantEggWeights: { common: 0, uncommon: 0, rare: 70, epic: 25, legendary: 5, mythic: 0 },
    // Staff / automation (one-time purchases):
    autoCollectorCost: 1500,    // coins: collects revenue automatically every tick
    groundskeeperCost: 3,       // relics: +10 happiness to ALL creatures, forever
    groundskeeperHappiness: 10,
    fusionRitualistCost: 5,     // relics: fusion timers run 2x faster
    fusionRitualistSpeed: 2,
  },

  // --------------------------------------------------------------------------
  // OBJECTIVES — dailies + milestone rewards
  // --------------------------------------------------------------------------
  objectives: {
    dailyCount: 3,              // dailies offered per day
    dailyRewardEssence: 10,
    dailyRewardCoins: 200,
    // Milestone thresholds → each step pays milestoneRelics
    fusionMilestones: [1, 5, 15, 40, 100, 250],
    discoveryMilestones: [3, 8, 20, 50, 120],
    coinMilestones: [1000, 10000, 100000, 1000000],
    eggMilestones: [3, 10, 25, 60],
    habitatMilestones: [2, 4, 7, 10],
    milestoneRelics: 1,
  },

  // --------------------------------------------------------------------------
  // SAVE — persistence
  // --------------------------------------------------------------------------
  save: {
    key: 'mft_save',            // localStorage key
    schemaVersion: 3,           // bump + add a migration in save.js when shape changes
                                // v2: creatures gained `traits` (rolled from seed)
                                // v3: counters gained discoveries/habitatUpgrades
    autosaveSeconds: 20,
  },
};

// ----------------------------------------------------------------------------
// ELEMENTS — identity data (not balance): display + color per element.
// Adding an element here automatically flows into fusion, art, habitats, log.
// ----------------------------------------------------------------------------
export const ELEMENTS = {
  fire:   { icon: '🔥', color: '#e8603c', dark: '#7a2812', label: 'Fire' },
  water:  { icon: '💧', color: '#3c8fe8', dark: '#123f7a', label: 'Water' },
  earth:  { icon: '⛰️', color: '#a07648', dark: '#4d3417', label: 'Earth' },
  air:    { icon: '🌪️', color: '#8fd0dd', dark: '#3a6a75', label: 'Air' },
  nature: { icon: '🌿', color: '#57b452', dark: '#1f5a1c', label: 'Nature' },
  shadow: { icon: '🌑', color: '#6b5a91', dark: '#241b3d', label: 'Shadow' },
  light:  { icon: '✨', color: '#e8d05c', dark: '#8a7a1a', label: 'Light' },
  storm:  { icon: '⚡', color: '#7c6ce8', dark: '#2c2079', label: 'Storm' },
};

// Body archetypes — drive both art silhouettes and species naming.
export const ARCHETYPES = ['Drake', 'Wisp', 'Golem', 'Serpent', 'Sprite', 'Fang', 'Moth', 'Kraken', 'Stag', 'Imp', 'Wyrm', 'Basilisk'];
