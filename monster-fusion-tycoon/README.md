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

- **Breeding Den** — pick two parents, pay coins + essence, watch the ritual
  resolve. Parents are consumed. Element sets merge open-endedly (union +
  mutation chance), rarity can spike, stats inherit with variance. The outcome
  is sealed the moment you press Fuse (seeded RNG — no save-scumming).
  **Volatile pairings**: fusing opposing elements (🔥/💧, ✨/🌑, ⛰️/🌪️) raises
  mutation odds and surges stats. The den previews element pool, mutation %,
  and rarity odds before you commit.
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
- **Collection** — an open-ended Pokédex of every species signature ever
  created. Fusion makes the space effectively unbounded.
- **Objectives** — date-seeded dailies + lifetime milestones. Milestones are
  the only faucet for relics (premium material — earned, never bought).
- **Sharing** — export any creature as an offline share string / URL; import
  and adopt someone else's for essence.

## Rendering choice: DOM + inline SVG

The game is management-UI-heavy (panels, lists, shops, logs) — DOM handles that
natively with layout and accessibility for free. Creature art is procedural
**inline SVG**: deterministic geometry derived from each creature's own data
(elements, archetype, rarity, seed). SVG scales crisply at any size, costs
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
```

Module rule: `state.js` owns all mutable state; logic modules mutate it through
their own functions; `ui_*.js` renders and calls logic — no stray globals.

## CONFIG tuning knobs (`js/config.js`)

Everything a designer would tune, in one block, grouped:

| Group | What lives there |
|---|---|
| `CONFIG.fusion` | fusion coin/essence costs + per-tier scaling, resolve time, stat variance (±25%), per-tier stat growth, max elements per hybrid, **mutationChance** (new-element rate — the open-endedness dial), archetype shift chance, max tier |
| `CONFIG.economy` | per-rarity revenue/sec and maintenance/sec tables, vitality upkeep discount, happiness→revenue curve, the sulk threshold (below it: zero income, full upkeep), happiness drivers (biome match, crowding, charm, decorations), collect-pool cap, offline cap, starting resources |
| `CONFIG.traits` | how many boons/burdens each rarity rolls (`countsByRarity`) — effect sizes are in `traits.js` definitions |
| `CONFIG.rarity` | rarity ladder, spike/downgrade odds, element-diversity bonus, per-rarity UI colors, egg odds |
| `CONFIG.habitats` | base capacity, capacity/quality per level, upgrade cost + exponential growth, new-habitat cost + growth, decoration cost/slots, biome list |
| `CONFIG.shop` | egg price + creep rate, all exchange rates (deliberately lossy), staff prices/effects |
| `CONFIG.objectives` | daily count + rewards, milestone thresholds, relic payout |
| `CONFIG.save` | localStorage key, **schemaVersion**, autosave interval |

`ELEMENTS` and `ARCHETYPES` (identity data, not balance) sit below CONFIG in
the same file — adding an element there flows into fusion, art, naming,
habitats, and the log automatically.

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
   building the prompt from `creature.elements / archetype / rarity`, and
   resolve `{ kind: 'url', url }`.
3. Done — no caller changes. `mountArt()` in ui.js already renders both kinds,
   keeps the silhouette on failure, and caches by creature identity.

## Save schema

- The save is the whole state object from `state.js` (resources, creatures,
  habitats, pending fusion, discovery log, upgrades, counters, objectives,
  `lastSeen` for offline progress).
- Key: `mft_save`; current **schemaVersion: 3**.
- Migrations live in `save.js` (`MIGRATIONS[fromVersion]`), run forward one
  version at a time on load. v1→v2 backfilled creature `traits` (rolled
  deterministically from each creature's seed, so migrated saves match fresh
  rolls); v2→v3 added the discovery/upgrade lifetime counters. Unknown/newer
  versions fall back to a fresh game instead of crashing.

## Share-string format

```
MFT1.<payload>.<checksum>
```

- `MFT1` — format tag + version (bump to `MFT2` on field changes).
- `<payload>` — base64url-encoded JSON of the creature's identity fields:
  `seed, elements, archetype, tier, rarity, stats, parents`.
- `<checksum>` — FNV-1a hash of the payload, base36 — catches paste mangling.
- Share URL = game URL + `#c=<string>`; the hash is parsed on boot, shown in a
  viewer modal, and cleared. Adopting costs essence (scaled by tier + rarity).
- Traits and species name are *not* encoded — they re-derive deterministically
  from the seed on import.
- Decoding validates and clamps every field (external input).
- **Future online gallery seam:** `share.js` is the module a gallery would
  build on — POST the same string to a server, list + import identically.
  Nothing in this build assumes a backend exists.

## Security / content rules honored

- No API keys or secrets anywhere in shipped files.
- No external fetches, CDNs, or copyrighted art — everything is generated
  in-page from the creature's own data.
- Sharing is fully offline (string/URL encoding, no server).
