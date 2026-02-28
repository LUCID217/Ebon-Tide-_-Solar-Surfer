# EBON TIDE - Economy & Monetization Design Document
## Version 1.0 | Mobile F2P + Premium Lite Hybrid

---

# EXECUTIVE SUMMARY

Ebon Tide is a free-to-play endless runner with a $9.99 ad-free premium option. The game monetizes through rewarded ads, cosmetic purchases, and the one-time premium pass. The economy is designed to:

1. Respect player time (no paywalls on content)
2. Reward engagement (daily play = faster progression)
3. Convert ad-haters to premium ($9.99)
4. Extract value from cosmetic whales (unlimited spend ceiling)
5. Grow MAU 5-8% month-over-month through retention and viral mechanics

**Revenue Split Target (at scale):**
- 45% Rewarded Ads
- 30% Ebon Pass ($9.99)
- 25% Cosmetic IAPs

---

# CURRENCY SYSTEM

## Primary Currency: Drift Coins (◈)

**What they are:** Soft currency earned through gameplay.

**How players earn them:**
| Source | Amount | Frequency |
|--------|--------|-----------|
| Per coin collected in-run | 1 ◈ | Unlimited |
| Run completion bonus | distance/10 ◈ | Per run |
| Daily login (Day 1-6) | 50-150 ◈ | Daily |
| Daily login (Day 7) | 500 ◈ | Weekly |
| Daily challenge complete | 100-300 ◈ | Daily |
| Weekly challenge complete | 750 ◈ | Weekly |
| Achievement unlock | 100-1000 ◈ | One-time |
| Ad watch (post-run 2x) | 2x run earnings | Optional |
| Ad watch (free spin) | 50-500 ◈ | 3x daily |

**What they buy:**
| Item | Cost | Notes |
|------|------|-------|
| New Crew (common) | 1,500 ◈ | 3 unlockable |
| New Crew (rare) | 4,000 ◈ | 2 unlockable |
| New Vessel (common) | 2,000 ◈ | 3 unlockable |
| New Vessel (rare) | 5,000 ◈ | 2 unlockable |
| Basic skin | 3,000 ◈ | Recolors |
| Continue (revive) | 500 ◈ | Or watch ad |

**Economy pacing:**
- Average run (60-90 sec): 40-80 ◈ collected + 30-60 ◈ distance bonus = ~100 ◈
- With 2x ad bonus: ~200 ◈
- Daily engaged player (10 runs + dailies): ~2,500 ◈
- Time to first crew unlock (1,500 ◈): 1-2 days
- Time to rare crew (4,000 ◈): 3-5 days
- Time to unlock ALL crew/vessels: 4-6 weeks (engaged player)

This pacing is intentional: fast early unlocks create investment, later unlocks require commitment.

---

## Premium Currency: Ember Shards (🔥)

**What they are:** Hard currency, purchased with real money or earned rarely.

**How players get them:**
| Source | Amount | Notes |
|--------|--------|-------|
| Purchase $0.99 | 100 🔥 | Starter pack |
| Purchase $4.99 | 600 🔥 | Best "value" |
| Purchase $9.99 | 1,400 🔥 | Whale tier |
| Purchase $19.99 | 3,200 🔥 | Big whale |
| Season pass level-up | 10-50 🔥 | Free track |
| Achievement (rare) | 25-100 🔥 | One-time |
| 7-day login streak | 50 🔥 | Weekly |
| Event placement | 100-500 🔥 | Competitive |

**What they buy:**
| Item | Cost | Notes |
|------|------|-------|
| Premium skin | 300-800 🔥 | Unique models/effects |
| Legendary skin | 1,200 🔥 | Animated, trails |
| Season Pass | 800 🔥 | ~$5-6 value |
| Skin bundle | 1,500 🔥 | 3-4 items |
| Skip crew unlock | 400 🔥 | Impatient players |
| Skip vessel unlock | 500 🔥 | Impatient players |

**Ember Shards CANNOT buy:**
- Revives/continues (soft currency or ads only)
- Gameplay advantages
- Exclusive crew/vessels (only skins)

This keeps the economy "fair" - whales look cooler, but don't play better.

---

# EBON PASS (Ad-Free Premium) - $9.99

## What it includes:

### Permanent Benefits:
1. **No forced ads ever** - No interstitials, no "ad failed to load" waits
2. **No ad prompts** - Buttons that say "Watch Ad" become "Claim"
3. **Auto 1.5x coins** - Every run, automatically (vs 2x for watching ad)
4. **1 free revive per run** - No ad required
5. **Exclusive "Founder's Flame" sail skin** - Shows you're a supporter
6. **Exclusive ember trail effect** - Visible to other players in future multiplayer
7. **100 Ember Shards** - One-time bonus (~$1 value)
8. **"Ebon Patron" profile badge** - Permanent flex

### Why $9.99 is the right price:
- $4.99 = impulse but feels "cheap," leaves money on table
- $7.99 = awkward price point, no psychological anchor
- $9.99 = "one nice coffee" rationalization, standard mobile premium
- $14.99 = too much friction for impulse, only hardcore buy

### Conversion funnel:
1. Player sees 5-10 ads in first session
2. Post-run prompt: "Tired of ads? Go ad-free forever for $9.99"
3. Soft reminder every 10 runs (not annoying, just present)
4. After 50 runs: "You've watched 47 ads. Remove them forever?"

**Target conversion rate:** 3-5% of D7 retained players

---

# AD PLACEMENTS

## Rewarded Ads (Player-Initiated)

These are GOOD. Players choose to watch, feel rewarded, not resentful.

| Placement | Reward | Frequency Cap |
|-----------|--------|---------------|
| Post-run 2x coins | Double run earnings | Every run |
| Revive/Continue | One more chance | 1 per run |
| Daily bonus boost | 2x daily reward | 1 per day |
| Lucky spin | 50-500 ◈ | 3 per day |
| Skip unlock timer | Instant unlock | When applicable |

## Interstitial Ads (Forced)

These are BAD but necessary for non-payers. Minimize friction.

| Placement | Frequency | Notes |
|-----------|-----------|-------|
| After every 3rd run | 15-30 sec | Skippable after 5s |
| After death (before results) | 15-30 sec | NOT after personal best |
| Return from background (5+ min) | 15-30 sec | Only once per return |

**Rules:**
- NEVER during gameplay
- NEVER before first run of session
- NEVER after a purchase
- NEVER after personal best (reward the moment!)
- MAX 3 interstitials per 15-minute session

## Banner Ads

Small, ignorable, but consistent revenue.

| Placement | Size | Notes |
|-----------|------|-------|
| Main menu bottom | 320x50 | Always visible |
| Results screen | 300x250 | Above buttons |
| NOT during gameplay | - | Never |

---

# RETENTION SYSTEMS

## Daily Login Rewards

| Day | Reward |
|-----|--------|
| 1 | 50 ◈ |
| 2 | 75 ◈ |
| 3 | 100 ◈ |
| 4 | 25 🔥 |
| 5 | 150 ◈ |
| 6 | 200 ◈ |
| 7 | 500 ◈ + Spin Ticket |

**Streak bonus:** 
- Complete all 7 days: Bonus 50 🔥
- Streak resets on miss (no "catch up" mechanic - creates urgency)

## Daily Challenges

Three new challenges every day at midnight (player's local time).

**Challenge types:**
| Type | Example | Reward |
|------|---------|--------|
| Distance | "Travel 1,000m total" | 100 ◈ |
| Collection | "Collect 200 coins" | 100 ◈ |
| Survival | "Survive 3 runs without damage" | 150 ◈ |
| Character | "Play 2 runs as Mary Korr" | 150 ◈ |
| Hazard | "Survive 2 meteor storms" | 200 ◈ |
| Zone | "Spend 60 seconds in Shadow zones" | 150 ◈ |
| Streak | "Complete all 3 dailies" | 300 ◈ BONUS |

**All-daily completion bonus:** 300 ◈ extra (encourages completing set)

## Weekly Challenges

Larger goals, larger rewards. Reset every Monday.

| Challenge | Reward |
|-----------|--------|
| Travel 10,000m total | 500 ◈ |
| Collect 2,000 coins | 500 ◈ |
| Complete 15 daily challenges | 750 ◈ |
| Play 30 runs | 500 ◈ |
| Try 4 different crew members | 400 ◈ |
| All weeklies complete | 1,000 ◈ + 50 🔥 |

## Achievements (One-Time)

Permanent goals with permanent rewards. ~50 achievements at launch.

**Categories:**
- Distance milestones (500m, 1000m, 2500m, 5000m, 10000m)
- Total coins collected (1k, 10k, 50k, 100k, 500k)
- Runs completed (10, 50, 100, 500, 1000)
- Crew unlocked (all common, all rare, all)
- Vessels unlocked (all common, all rare, all)
- Synergies discovered (5, all 11)
- Storm survivals (1, 10, 50)
- Perfect runs (no damage) - distance thresholds
- Character-specific (1000m as Kane, etc.)
- Near-miss master (100 near misses, 500)
- Boost master (boost for 60 seconds total, 300 seconds)

**Rewards scale:**
- Common achievements: 100-250 ◈
- Rare achievements: 500-1000 ◈
- Epic achievements: 25-50 🔥

---

# SEASON PASS SYSTEM

## Overview

8-week seasons with free and premium tracks.

## Free Track (everyone)

50 levels, rewards at each level:
- Mostly Drift Coins (50-200 ◈)
- Occasional Ember Shards (10-25 🔥)
- 1-2 basic skins per season
- Profile customization items

## Premium Track (800 🔥 / ~$6)

50 levels parallel to free track:
- Better coin rewards (2x free track)
- More Ember Shards (total ~600 🔥 back = net profit)
- 4-6 exclusive skins
- Exclusive trail effects
- Exclusive profile items
- Legendary skin at level 50

## Season XP Sources

| Source | XP | Notes |
|--------|-------|-------|
| Per run completed | 10 XP | Base |
| Per 100m traveled | 5 XP | Distance bonus |
| Daily challenge | 50 XP | Per challenge |
| Weekly challenge | 150 XP | Per challenge |
| Daily login | 25 XP | Just for showing up |

**Leveling curve:**
- Level 1-10: 100 XP each (easy early wins)
- Level 11-30: 200 XP each
- Level 31-50: 300 XP each

**Total XP needed:** ~9,500 XP over 8 weeks
**Daily engaged player earns:** ~200-300 XP
**Can complete in:** 5-6 weeks of engaged play (buffer for casual)

---

# COSMETIC SYSTEM

## Skin Types

### Crew Skins
When we have real 3D models, each crew member can have:

| Tier | Price | What changes |
|------|-------|--------------|
| Recolor | 3,000 ◈ | Color palette swap |
| Outfit | 400 🔥 | Different clothing |
| Legendary | 1,200 🔥 | Full model + effects |

### Vessel Skins

| Tier | Price | What changes |
|------|-------|--------------|
| Recolor | 2,500 ◈ | Hull/sail colors |
| Variant | 350 🔥 | Different hull shape |
| Legendary | 1,000 🔥 | Full model + trail |

### Trail Effects

Particle trails behind the vessel during gameplay.

| Trail | Price | Effect |
|-------|-------|--------|
| Ember Trail | Ebon Pass exclusive | Orange particles |
| Void Trail | 500 🔥 | Purple/black particles |
| Plasma Trail | 600 🔥 | Blue electric |
| Ghost Trail | 800 🔥 | Transparent afterimages |

### Profile Customization

| Item | Price | Notes |
|------|-------|-------|
| Profile border | 200-500 🔥 | Around avatar |
| Title/badge | 100-300 🔥 | "Storm Chaser," "Debt Collector" |
| Death animation | 400 🔥 | How your ship explodes |

---

# GROWTH MECHANICS

## Share & Social

### Post-Run Share
"NEW PERSONAL BEST! 2,847m as Kane on Tidebreaker"
- Auto-generates shareable image
- Deep link back to game
- Reward for sharer: 25 ◈ per share (max 3/day)

### Friend Challenges
- Challenge friend to beat your score
- If they install and play: Both get 500 ◈
- If they beat you: They get 200 ◈ bonus

### Leaderboards
- Daily (resets every 24h)
- Weekly (resets Monday)
- All-time
- Friends-only
- Per-character leaderboards

### Future: Crews/Guilds
- Join a crew (10-50 players)
- Crew challenges
- Crew leaderboards
- Crew chat
- Crew perks (small bonuses for active crews)

---

# LIVE EVENTS

## Weekend Events (Every Weekend)

**Double XP Weekend**
- 2x Season XP all runs
- Drives engagement on weekends

**Character Spotlight**
- "Mary Korr Weekend"
- 1.5x coins when playing as featured character
- Discounted character if locked

**Storm Season**
- 2x meteor storm frequency
- Bonus coins for storm survival
- Limited "Storm Chaser" title

## Limited-Time Events (Monthly)

**The Crimson Tide**
- 2-week event
- Special red-tinted visuals
- Event-specific challenges
- Exclusive "Crimson" skins (never return)
- Event currency that converts to ◈ after

**Founder's Day (Anniversary)**
- Returning players get bonus
- New players get starter pack
- Limited legendary skins

---

# NOTIFICATION STRATEGY

## Push Notifications

**Rules:**
- MAX 1 per day
- Player can set preference (none, important only, all)
- Never between 10pm-8am local time
- Personalized based on behavior

**Types:**

| Trigger | Message | When |
|---------|---------|------|
| Daily reset | "Your daily challenges are ready! 🎯" | 9am local |
| Streak at risk | "Don't break your 5-day streak! Login now" | 6pm if no login |
| New season | "Season 2 is HERE! New rewards await" | Season launch |
| Event start | "The Crimson Tide begins! Limited skins inside" | Event launch |
| Lapsed (D3) | "Your crew misses you, Captain" | 3 days inactive |
| Lapsed (D7) | "Come back for 500 free coins!" | 7 days inactive |
| Personal best beatable | "[Friend] just beat your record!" | When applicable |

---

# ANALYTICS REQUIREMENTS

## Funnel Metrics (Track These)

| Event | Why it matters |
|-------|---------------|
| Install | Top of funnel |
| Tutorial start | Engagement |
| Tutorial complete | Comprehension |
| First run complete | Core loop |
| First death | Expected |
| First ad watched | Monetization |
| First purchase | Conversion |
| D1/D7/D30 retention | Health |
| Session length | Engagement |
| Sessions per day | Habit |
| Runs per session | Core loop health |

## Economy Metrics

| Metric | Target |
|--------|--------|
| Average coins per run | 80-120 |
| Days to first unlock | 1-2 |
| Days to all unlocks | 30-45 |
| % watching rewarded ads | 60-70% |
| % purchasing Ebon Pass | 3-5% |
| % purchasing Ember Shards | 1-2% |
| ARPDAU (avg revenue per daily user) | $0.05-0.10 |

## Death Analytics (Critical for Balance)

Track WHERE and HOW players die:
- Distance at death (histogram)
- Zone at death (shadow/light/super)
- Cause of death (obstacle/storm/other)
- Character at death
- Vessel at death
- Damage state at death (1/2/3 strikes)

This tells you if the game is too hard/easy and where.

---

# PRICE ANCHORING & STORE DESIGN

## Ember Shard Packages

| Package | Price | Shards | Bonus | $/Shard |
|---------|-------|--------|-------|---------|
| Handful | $0.99 | 100 | - | $0.0099 |
| Pouch | $4.99 | 550 | +50 | $0.0091 |
| Chest | $9.99 | 1,200 | +200 | $0.0083 |
| Hoard | $19.99 | 2,800 | +600 | $0.0071 |
| Vault | $49.99 | 7,500 | +1,500 | $0.0067 |

**Design principle:** Bigger packages = better value (encourages larger purchases)

## First Purchase Bonus

First-time buyer gets 2x shards on their first purchase (any tier).
This converts hesitant buyers and sets spending habit.

## Store Layout

```
┌─────────────────────────────────────┐
│  🔥 FEATURED: Crimson Kane Skin    │
│     [800 🔥] [BUY]                  │
├─────────────────────────────────────┤
│  ⭐ EBON PASS - $9.99              │
│     Ad-free forever + bonuses      │
│     [LEARN MORE]                   │
├─────────────────────────────────────┤
│  EMBER SHARDS                       │
│  [100/$0.99] [550/$4.99] [MORE...] │
├─────────────────────────────────────┤
│  SKINS        TRAILS      BUNDLES  │
│  [Browse]     [Browse]    [Browse] │
└─────────────────────────────────────┘
```

---

# ANTI-CHEAT & ECONOMY PROTECTION

## Server Validation

Even for a "single-player" game, validate:
- High scores (flag impossible distances)
- Purchase receipts
- Currency transactions
- Unlock states

## Cheat Detection

Flag accounts that have:
- Impossible distances (>50,000m without upgrades)
- Currency that doesn't match earnings history
- All unlocks with no play time
- Modified client detection

## Soft Bans

Don't ban cheaters outright (they'll leave bad reviews).
Instead:
- Remove from leaderboards silently
- Reduce ad revenue share
- Flag for no customer support priority

---

# IMPLEMENTATION PRIORITY

## Phase 1: Core Monetization (Before Launch)
1. Rewarded ads (2x coins, revive)
2. Interstitial ads (post-run)
3. Ebon Pass ($9.99)
4. Basic Ember Shard packages
5. Daily login rewards
6. Basic analytics

## Phase 2: Retention (Month 1)
1. Daily challenges
2. Weekly challenges
3. Achievements
4. Share functionality
5. Leaderboards

## Phase 3: Depth (Month 2-3)
1. Season Pass system
2. Cosmetic store
3. Push notifications
4. Friend challenges

## Phase 4: Growth (Month 3+)
1. Limited-time events
2. Crews/Guilds
3. Advanced analytics
4. A/B testing framework

---

# FINANCIAL PROJECTIONS

## Assumptions
- 10,000 installs Month 1 (soft launch)
- 30% D1 retention
- 10% D7 retention
- 3% D30 retention
- 70% of active users watch rewarded ads
- 4% of D7 users buy Ebon Pass
- 1% of D30 users buy Ember Shards (avg $5)

## Month 1 Revenue (10K installs)

| Source | Calculation | Revenue |
|--------|-------------|---------|
| Rewarded ads | 3,000 DAU × 70% × 3 ads × $0.01 | $630 |
| Interstitials | 3,000 DAU × 2 ads × $0.005 | $300 |
| Ebon Pass | 1,000 D7 × 4% × $9.99 | $400 |
| Ember Shards | 300 D30 × 1% × $5 | $15 |
| **Total** | | **~$1,345** |

## At Scale (100K MAU)

| Source | Revenue |
|--------|---------|
| Ads | ~$15,000/mo |
| Ebon Pass | ~$4,000/mo |
| Cosmetics | ~$3,000/mo |
| **Total** | **~$22,000/mo** |

## Path to $100K/month
- Need ~500K MAU
- Achievable with 5-8% monthly growth over 18-24 months
- Requires: consistent content updates, events, marketing spend

---

# SUMMARY

Ebon Tide's economy is designed to:

1. **Respect players** - Everything is earnable, no paywalls
2. **Reward engagement** - Daily players progress faster
3. **Convert appropriately** - Ads for free players, Ebon Pass for haters, cosmetics for whales
4. **Retain** - Daily/weekly loops, seasons, events
5. **Grow** - Social features, leaderboards, viral mechanics

The $9.99 Ebon Pass is the cornerstone - it's a fair deal that converts the "I hate ads" segment without cannibalizing whale spend on cosmetics.

With proper execution, 5-8% MAU growth is achievable through:
- Strong D1 retention (good first-time experience)
- Daily engagement hooks (challenges, streaks)
- Social pressure (leaderboards, friend challenges)
- Content cadence (seasons, events)
- Smart notification strategy

---

*Document version 1.0 - Ready for implementation review*
