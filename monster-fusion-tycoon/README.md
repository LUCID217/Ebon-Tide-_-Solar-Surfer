# Monster Fusion Tycoon

A browser-based monster-fusion collection + tycoon game. Breed and fuse fantasy
creatures into unique hybrids, then run a menagerie that turns those creatures
into a self-sustaining economy — grind it, expand it, optimise it.

## Run it

```
cd monster-fusion-tycoon
python3 -m http.server 8000
# open http://localhost:8000
```

No build step, no dependencies, no network calls, no console errors.
Vanilla HTML + CSS + JS (ES modules). All persistence is `localStorage`.

## The game

- **Species: 5 × 5 × 5 = 125.** Every creature is an **element** (Ember,
  Stone, Frost, Tide, Grove) × a **body type** (Beast, Wyrm, Avian, Crawler,
  Construct) × a **class** (Brute, Guardian, Tender, Seer, Trickster). The set
  is finite and knowable; dice, colour/pattern variants, traits and lineage
  depth keep individuals varied inside it.
- **Breeding Den** — pick two parents, pay coins + essence, watch the ritual
  resolve. Parents are consumed. The child resolves **one axis at a time**:
  - *Element* follows the cycle Ember → Stone → Frost → Tide → Grove → Ember.
    Same element is kept. A **feeds** pair (neighbours) gives the fed element
    plus a stat bonus. An **overcomes** pair (two apart: Ember > Frost,
    Stone > Tide, Frost > Grove, Tide > Ember, Grove > Stone) is ⚡ volatile:
    dice between the parents, a chance to mutate into a third element, a stat
    surge and a rarity bonus. (On a 5-cycle every distinct pair is one or the
    other, so the "weighted dice" fallback never fires with real elements.)
  - *Body type*: same is kept, otherwise 60/40 for the rarer parent's.
  - *Class*: a learnable, symmetric 5×5 recipe table (`CLASS_RECIPES`).
  Rarity can spike, stats inherit with variance. The outcome is sealed the
  moment you press Fuse (seeded RNG — no save-scumming). The den previews the
  odds on every axis, straight from the same `fusionOdds()` the roll uses.
- **Classes are tycoon roles**: 🪓 Brute earns ×1.3 but bills ×1.6 upkeep;
  🛡️ Guardian adds happiness to its whole habitat; 🧺 Tender cuts its own and
  its habitat-mates' upkeep; 🔮 Seer improves base-egg odds while on exhibit
  (still common/uncommon only) and rarity spikes as a parent; 🎭 Trickster
  raises a fusion's mutation chance. Numbers in `CONFIG.classes`.
- **Menagerie** — creatures live in biome habitats you build, upgrade, and
  decorate. They earn passively, scaled by rarity, happiness, habitat quality,
  and traits. **Meadows are sanctuaries**: residents bill zero upkeep (exotic
  rare+ creatures earn only 50% there) — the safe sandbox where a new player
  can buy eggs and fuse without going broke. **Elemental habitats** pay far
  more via biome-match happiness and theming, but charge maintenance whether
  or not the creature earns — powerful monsters are a liability unless placed
  deliberately. A Keeper's Advisor names every money-loser and why.
- **Traits** — epic+ creatures carry passive boons (auras, multipliers, fusion
  perks) *and* burdens (Ravenous upkeep, Tyrant sourness). Legendary+ always
  has a burden: the strongest creature in the game is net-negative if you just
  hoard it. Some boons are biome-conditional (Nightbloom/Sunborn/Tidebound
  only fire in their matching habitat), tying the trait roll to placement.
  Full list in `traits.js` and the in-game ❓ help.
- **Shop** — eggs hatch common/uncommon only (fusion is the rarity engine;
  price creeps up; free when you're down to <2 creatures — the anti-softlock
  mercy rule), radiant eggs (guaranteed rare+, locked until 15 fusions), lossy
  resource exchange (coins ⇄ essence ⇄ relics), and permanent staff hires
  gated behind progression. Habitats can be upgraded, decorated, re-biomed,
  and expanded; creatures can be sold/retired for coins.
- **Collection** — a 125-slot species dex in canonical order, with per-element
  completion. Undiscovered slots show as ??? with their element and body as a
  hint. (Hidden secret recipes are a planned later pass.)
- **Objectives** — date-seeded dailies + lifetime milestones. Milestones are
  the only faucet for relics (premium material — earned, never bought).
- **Lineage** — every fusion is recorded in an append-only ancestry ledger
  (`S.lineage`, childId → parent snapshots, ~0.4 KB of JSON per fusion — a
  1000-fusion save spends ~400 KB of the ~5 MB localStorage budget). The 🌳
  button on any creature opens its family tree: focus creature at top, each
  ancestor pair indented beneath, walking back to wild-born roots (🥚).
  Ancestors still alive in the menagerie get a 🏡 jump button; consumed ones
  render from their snapshots, art regenerated deterministically from stored
  seeds. Generations beyond grandparents collapse behind native `<details>`
  expanders, so the vertical layout never overflows at 390px. A creature's
  Gen number (1 + max parent gen) shows in its modal and the tree header.
  Lineage is local history — it does not travel in share strings.
- **Sharing** — export any creature as an offline share string / URL; import
  and adopt someone else's for essence.

## Rendering choice: DOM + inline SVG

The game is management-UI-heavy (panels, lists, shops, logs) — DOM handles that
natively with layout and accessibility for free. Creature art is procedural
**inline SVG**: deterministic geometry derived from each creature's own data
(element, type, class, rarity, seed), composed in layers: body (5, by type) →
element palette (5) → class gear (5) — 15 parts that cover all 125 species.
The layers are independent functions in `art.js` (`BODIES`, `paletteFor`,
`GEAR`), so a final style (vinyl toy or papercut/sticker) can replace them
part by part. SVG scales crisply at any size, costs
nothing to cache, and swaps trivially for real raster art later. Canvas would
buy nothing here and cost us layout.

## Folder structure

```
monster-fusion-tycoon/
  index.html         — page shell, tab layout, modal/toast containers
  css/style.css      — all styling (theme via CSS custom properties)
  js/
    config.js        — THE tuning file: every balance knob, grouped & commented
    rng.js           — seeded deterministic RNG (mulberry32, FNV-1a hashing)
    creature.js      — creature model, species naming, base revenue/upkeep
    traits.js        — passive boons/burdens + aggregated effect queries
    art.js           — generateCreatureArt() async boundary (procedural SVG stub)
    fusion.js        — deterministic fusion + discovery log registration
    economy.js       — habitats, happiness, revenue/maintenance tick, offline
    shop.js          — eggs, resource exchange, staff logic
    objectives.js    — dailies + milestones logic
    save.js          — schema-versioned localStorage + migrations
    legacy.js        — pre-v5 → 5/5/5 remap (shared by save migration + MFT1 import)
    share.js         — share-string encode/decode/adopt
    state.js         — single owner of mutable state (S) + shared helpers
    ui.js            — UI core: tab registry, cards, modal, toasts, formatting
    ui_menagerie.js  — Menagerie tab
    ui_den.js        — Breeding Den tab
    ui_shop.js       — Shop tab
    ui_collection.js — Collection tab (+ import box)
    ui_objectives.js — Objectives tab (+ claimable badge)
    ui_share.js      — share/import modals, #c= URL handling
    main.js          — bootstrap + 1s game loop + autosave
  tests/run.mjs      — Playwright regression suite (node tests/run.mjs)
  tools/build-single.mjs — bundles everything into dist/monster-fusion-tycoon.html
```

Module rule: `state.js` owns all mutable state; logic modules mutate it through
their own functions; `ui_*.js` renders and calls logic — no stray globals.

## CONFIG tuning knobs (`js/config.js`)

Everything a designer would tune, in one block, grouped:

| Group | What lives there |
|---|---|
| `CONFIG.fusion` | fusion coin/essence costs + per-tier scaling, resolve time, stat variance (±25%), per-tier stat growth, max tier, and the per-axis rules: feeds stat bonus, volatile odds/mutation/stat/rarity bonuses, base mutation chance, the rarer-parent type weight |
| `CONFIG.classes` | Brute revenue/upkeep multipliers, Guardian happiness, Tender upkeep cuts, Seer egg luck + rarity bonus, Trickster mutation bonus |
| `CONFIG.economy` | per-rarity revenue/sec and maintenance/sec tables, vitality upkeep discount, happiness→revenue curve, the sulk threshold (below it: zero income, full upkeep), happiness drivers (biome match, crowding, charm, decorations), collect-pool cap, offline cap, starting resources |
| `CONFIG.traits` | how many boons/burdens each rarity rolls (`countsByRarity`) — effect sizes are in `traits.js` definitions |
| `CONFIG.rarity` | rarity ladder, spike/downgrade odds, per-rarity UI colors, egg odds |
| `CONFIG.habitats` | base capacity, capacity/quality per level, upgrade cost + exponential growth, new-habitat cost + growth, decoration cost/slots, biome list |
| `CONFIG.shop` | egg price + creep rate, all exchange rates (deliberately lossy), staff prices/effects |
| `CONFIG.objectives` | daily count + rewards, milestone thresholds, relic payout |
| `CONFIG.save` | localStorage key, **schemaVersion**, autosave interval |

Identity data sits below CONFIG in the same file: `ELEMENT_CYCLE` +
`ELEMENTS` (icons, palettes), `TYPES`, `CLASSES`, the `CLASS_RECIPES` table,
`BODY_NAMES` (25 element × type names; the class is the title, e.g.
"Cinderhound Brute"), and the `LEGACY_*` maps used to remap pre-v5 data.

## The `generateCreatureArt()` boundary (`js/art.js`)

All creature visuals come from **one** async function:

```js
generateCreatureArt(creature) -> Promise<{ kind: 'svg', svg } | { kind: 'url', url }>
```

Today it draws deterministic placeholder SVG from the creature's data (no
network, no bundled assets). Callers always render a silhouette first and swap
in the art when the promise resolves — the game is fully playable if art never
loads.

**To wire a real image API (e.g. xAI Grok Imagine) later:**
1. Stand up a *server-side proxy* that holds the API key and exposes an
   endpoint like `POST /art { prompt }` → image URL. The key never ships to
   the client (see the `// TODO: route through server proxy` marker in art.js).
2. Replace the body of `generateCreatureArt()` with a fetch to that proxy,
   building the prompt from `creature.element / type / cls / rarity`, and
   resolve `{ kind: 'url', url }`.
3. Done — no caller changes. `mountArt()` in ui.js already renders both kinds,
   keeps the silhouette on failure, and caches by creature identity.

## Save schema

- The save is the whole state object from `state.js` (resources, creatures,
  habitats, pending fusion, discovery log, upgrades, counters, objectives,
  `lastSeen` for offline progress).
- Key: `mft_save`; current **schemaVersion: 5**.
- Migrations live in `save.js` (`MIGRATIONS[fromVersion]`), run forward one
  version at a time on load. v1→v2 backfilled creature `traits` (rolled
  deterministically from each creature's seed, so migrated saves match fresh
  rolls); v2→v3 added the discovery/upgrade lifetime counters; v3→v4 added
  the lineage ledger (empty on migration — pre-v4 fusions were never recorded,
  so existing creatures read as Gen-1 roots); v4→v5 is the 5/5/5 restructure
  (below). Unknown/newer versions fall back to a fresh game instead of crashing.
- **v4→v5 remap** (`legacy.js`, maps in `config.js`). Elements: fire/light →
  Ember, earth/shadow → Stone, air/storm → Frost, water → Tide, nature → Grove;
  a multi-element creature takes its most common remapped element (ties broken
  from its seed). Archetypes → body + class: Drake → Wyrm Brute, Wyrm → Wyrm
  Seer, Serpent → Wyrm Trickster, Fang → Beast Brute, Stag → Beast Guardian,
  Imp → Beast Trickster, Moth → Avian Seer, Sprite → Avian Tender, Kraken →
  Crawler Brute, Basilisk → Crawler Guardian, Golem → Construct Guardian,
  Wisp → Construct Tender. Ids, seeds, stats, tier, rarity and traits are
  untouched; names are recomputed and the old one kept as `legacyName`. The
  lineage ledger keeps every record — snapshots are remapped in place — and
  the discovery log is re-keyed (merging entries that land on one species).
  Old elemental habitats convert to the matching new biome.

## Share-string format

```
MFT2.<payload>.<checksum>
```

- `MFT2` — format tag + version (v5 creatures).
- `<payload>` — base64url-encoded JSON of the creature's identity fields:
  `seed, element, type, cls, tier, rarity, stats, parents`.
- Old `MFT1` strings (`elements, archetype`) still import: they are remapped
  by the same `legacy.js` code as old saves. Malformed strings of either
  version fail with a readable reason, never an exception.
- `<checksum>` — FNV-1a hash of the payload, base36 — catches paste mangling.
- Share URL = game URL + `#c=<string>`; the hash is parsed on boot, shown in a
  viewer modal, and cleared. Adopting costs essence (scaled by tier + rarity).
- Traits and species name are *not* encoded — they re-derive deterministically
  from the seed on import.
- Decoding validates and clamps every field (external input).
- **Future online gallery seam:** `share.js` is the module a gallery would
  build on — POST the same string to a server, list + import identically.
  Nothing in this build assumes a backend exists.

## Tests

```
node tests/run.mjs
```

A self-contained Playwright suite (starts its own static server; needs only
the `playwright` package): smoke across every tab at 390px with zero console
errors, the 5/5/5 fusion rules (every feeds/overcomes pair, every recipe cell,
determinism, 125 unique names), the v4→v5 migration with lineage, share
strings (MFT2, MFT1, garbage), balance guards (no early coin bleed, radiant
egg gate untouched, eggs never rare+ even with Seers), a 60-fusion playtest,
and the dist bundle over `file://`. Rebuild the bundle before running it.

## Security / content rules honored

- No API keys or secrets anywhere in shipped files.
- No external fetches, CDNs, or copyrighted art — everything is generated
  in-page from the creature's own data.
- Sharing is fully offline (string/URL encoding, no server).
