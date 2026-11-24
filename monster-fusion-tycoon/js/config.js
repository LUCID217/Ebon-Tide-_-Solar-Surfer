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
    maxTier: 12,                // creatures at this tier can no longer be fused (endgame trophies)

    // --- 5/5/5 axis rules (schema v5). Each axis resolves independently. ---
    // ELEMENT: same → kept. "Feeds" pair (A feeds B, next on the cycle) →
    // child takes the FED element + a stat bonus. "Overcomes" pair (two steps
    // apart) → volatile: dice between the parents, with a chance to mutate
    // into a third element. On the 5-cycle every distinct pair is one or the
    // other, so `otherPairWeights` is only a fallback for unknown elements.
    feedStatBonus: 0.08,         // ×1.08 to all child stats on a feeds pairing
    volatileOvercomerWeight: 0.5,// overcomes pair: chance the child keeps the OVERCOMING parent's element
    volatileMutationChance: 0.20,// overcomes pair: chance to mutate into one of the other 3 elements
    volatileStatBonus: 0.10,     // ×1.10 to all child stats on a volatile pairing
    volatileUpgradeBonus: 0.05,  // + rarity upgradeChance on a volatile pairing (replaces old element-diversity bonus)
    baseMutationChance: 0.04,    // any pairing: small chance the element mutates anyway (keeps surprises alive)
    otherPairWeights: [0.5, 0.5],// fallback weighted dice [parentA, parentB]
    // TYPE: same → kept. Otherwise 60/40 in favour of the RARER parent
    // (higher rarity; tie → higher tier; full tie → coin flip).
    typeRarerParentWeight: 0.60,
    // CLASS: resolved by the learnable recipe table CLASS_RECIPES below.
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
  // CLASSES — gear + tycoon role. Every creature has exactly one class.
  // Numbers here are the whole effect; economy.js / fusion.js / shop.js read
  // them through small helpers and never hard-code class behaviour.
  // --------------------------------------------------------------------------
  classes: {
    brute:     { revenueMult: 1.30, maintMult: 1.60 },  // earns big, eats big
    guardian:  { habitatHappiness: 6 },                 // +happiness to EVERY resident of its habitat (itself included)
    tender:    { ownMaintMult: 0.60, habitatMaintMult: 0.90 }, // −40% own upkeep, −10% upkeep for habitat-mates
    seer:      { fusionUpgradeBonus: 0.04,              // + rarity upgradeChance per Seer parent
                 eggUncommonWeightPer: 5,               // + uncommon weight on base eggs per Seer ON EXHIBIT...
                 eggUncommonWeightCap: 15 },            // ...capped. Eggs stay common/uncommon only — never an upkeep bomb.
    trickster: { fusionMutationBonus: 0.08 },           // + element mutation chance per Trickster parent
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
    // (v5: the old per-element diversity bonus is gone — creatures carry one
    //  element now. See fusion.volatileUpgradeBonus + classes.seer instead.)
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
    biomes: ['meadow', 'ember', 'stone', 'frost', 'tide', 'grove'],
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
    schemaVersion: 5,           // bump + add a migration in save.js when shape changes
                                // v2: creatures gained `traits` (rolled from seed)
                                // v3: counters gained discoveries/habitatUpgrades
                                // v4: lineage ledger (childId -> parent snapshots)
                                // v5: 5/5/5 restructure — elements[]+archetype → element/type/cls
    autosaveSeconds: 20,
  },
};

// ----------------------------------------------------------------------------
// ELEMENTS — the 5-element cycle (identity data, not balance).
//   Ember → Stone → Frost → Tide → Grove → Ember
//   FEEDS:     each element feeds the NEXT one   (ember feeds stone, …)
//   OVERCOMES: each element overcomes the one TWO steps ahead
//              (ember > frost, stone > tide, frost > grove, tide > ember, grove > stone)
// `palette` is the 3–4 colour flat/2-tone set the layered art uses:
//   [base, shade, accent, highlight].
// ----------------------------------------------------------------------------
export const ELEMENT_CYCLE = ['ember', 'stone', 'frost', 'tide', 'grove'];

export const ELEMENTS = {
  ember: { icon: '🔥', label: 'Ember', color: '#e8603c', dark: '#7a2812', palette: ['#e8603c', '#a83a1e', '#ffc04d', '#ffe3b0'] },
  stone: { icon: '⛰️', label: 'Stone', color: '#a08a6a', dark: '#4d3f2a', palette: ['#a08a6a', '#6b5a42', '#d9c9a3', '#f0e6cf'] },
  frost: { icon: '❄️', label: 'Frost', color: '#8fd0e8', dark: '#2f6a80', palette: ['#8fd0e8', '#4f93b0', '#e8f8ff', '#ffffff'] },
  tide:  { icon: '🌊', label: 'Tide',  color: '#3c8fe8', dark: '#123f7a', palette: ['#3c8fe8', '#1f5aa8', '#5fe0d0', '#c8f2ff'] },
  grove: { icon: '🌿', label: 'Grove', color: '#57b452', dark: '#1f5a1c', palette: ['#57b452', '#2f7a2b', '#e8d05c', '#d6f5c0'] },
};

/** The element that `el` feeds (next on the cycle). */
export function feedsTarget(el) {
  const i = ELEMENT_CYCLE.indexOf(el);
  return i < 0 ? null : ELEMENT_CYCLE[(i + 1) % 5];
}
/** The element that `el` overcomes (two steps ahead). */
export function overcomesTarget(el) {
  const i = ELEMENT_CYCLE.indexOf(el);
  return i < 0 ? null : ELEMENT_CYCLE[(i + 2) % 5];
}

// ----------------------------------------------------------------------------
// CREATURE TYPES — body bases (art silhouettes + naming).
// ----------------------------------------------------------------------------
export const TYPES = {
  beast:     { icon: '🐾', label: 'Beast' },
  wyrm:      { icon: '🐉', label: 'Wyrm' },
  avian:     { icon: '🪶', label: 'Avian' },
  crawler:   { icon: '🦂', label: 'Crawler' },
  construct: { icon: '🗿', label: 'Construct' },
};
export const TYPE_KEYS = Object.keys(TYPES);

// ----------------------------------------------------------------------------
// CLASSES — gear set + tycoon role (numbers live in CONFIG.classes).
// ----------------------------------------------------------------------------
export const CLASSES = {
  brute:     { icon: '🪓', label: 'Brute',     role: 'High earnings, high upkeep' },
  guardian:  { icon: '🛡️', label: 'Guardian',  role: 'Raises habitat happiness' },
  tender:    { icon: '🧺', label: 'Tender',    role: 'Lowers upkeep' },
  seer:      { icon: '🔮', label: 'Seer',      role: 'Better egg and rare-find luck' },
  trickster: { icon: '🎭', label: 'Trickster', role: 'Higher mutation chance' },
};
export const CLASS_KEYS = Object.keys(CLASSES);

// ----------------------------------------------------------------------------
// CLASS RECIPES — the learnable 5×5 table. Symmetric (parent order never
// matters) and balanced: same class breeds true, and every class is the
// result of exactly two mixed pairings. Rule of thumb for players, with the
// classes in ring order Brute → Guardian → Tender → Seer → Trickster:
//   • neighbours make the class OPPOSITE them on the ring
//   • one-apart pairs make the class BETWEEN them
// Tune freely — fusion.js only ever reads this table.
// ----------------------------------------------------------------------------
export const CLASS_RECIPES = {
  brute:     { brute: 'brute',     guardian: 'seer',      tender: 'guardian',  seer: 'trickster', trickster: 'tender' },
  guardian:  { brute: 'seer',      guardian: 'guardian',  tender: 'trickster', seer: 'tender',    trickster: 'brute' },
  tender:    { brute: 'guardian',  guardian: 'trickster', tender: 'tender',    seer: 'brute',     trickster: 'seer' },
  seer:      { brute: 'trickster', guardian: 'tender',    tender: 'brute',     seer: 'seer',      trickster: 'guardian' },
  trickster: { brute: 'tender',    guardian: 'brute',     tender: 'seer',      seer: 'guardian',  trickster: 'trickster' },
};

// ----------------------------------------------------------------------------
// SPECIES NAMES — 25 body names (element × type); the class is the title.
// 25 × 5 classes = the 125 base species, e.g. "Cinderhound Brute".
// ----------------------------------------------------------------------------
export const BODY_NAMES = {
  ember: { beast: 'Cinderhound', wyrm: 'Scorchcoil', avian: 'Flarewing', crawler: 'Ashmite',    construct: 'Kilnheart' },
  stone: { beast: 'Cragmaw',     wyrm: 'Bouldrake',  avian: 'Slatebeak', crawler: 'Gravelback', construct: 'Pillarborn' },
  frost: { beast: 'Rimefang',    wyrm: 'Glaciwyrm',  avian: 'Sleetwing', crawler: 'Icetick',    construct: 'Shardsentry' },
  tide:  { beast: 'Surfmane',    wyrm: 'Brinecoil',  avian: 'Spraywing', crawler: 'Reefcrab',   construct: 'Coralforge' },
  grove: { beast: 'Mossback',    wyrm: 'Vinecoil',   avian: 'Leafwing',  crawler: 'Thornmite',  construct: 'Barkwarden' },
};

// ----------------------------------------------------------------------------
// LEGACY (schema ≤4 / MFT1 share strings) → 5/5/5 remap. Used by the v4→v5
// save migration AND by share-string import (see legacy.js), so both agree.
// ----------------------------------------------------------------------------
export const LEGACY_ELEMENT_MAP = {
  fire: 'ember', light: 'ember',     // heat and sunfire
  earth: 'stone', shadow: 'stone',   // deep rock, caves
  air: 'frost', storm: 'frost',      // high cold skies
  water: 'tide',
  nature: 'grove',
};
export const LEGACY_ARCHETYPE_MAP = {
  // archetype: [type, class]
  Drake:    ['wyrm', 'brute'],
  Wyrm:     ['wyrm', 'seer'],
  Serpent:  ['wyrm', 'trickster'],
  Fang:     ['beast', 'brute'],
  Stag:     ['beast', 'guardian'],
  Imp:      ['beast', 'trickster'],
  Moth:     ['avian', 'seer'],
  Sprite:   ['avian', 'tender'],
  Kraken:   ['crawler', 'brute'],
  Basilisk: ['crawler', 'guardian'],
  Golem:    ['construct', 'guardian'],
  Wisp:     ['construct', 'tender'],
};
