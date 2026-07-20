# Monster Fusion Tycoon

A browser-based monster-fusion collection + tycoon game. Breed and fuse fantasy
creatures into unique hybrids, then run a menagerie that turns those creatures
into a self-sustaining economy.

**Status: work in progress — vertical slice under construction.**

## Run it

```
cd monster-fusion-tycoon
python3 -m http.server 8000
# open http://localhost:8000
```

No build step, no dependencies, no network calls. Vanilla HTML + CSS + JS (ES modules).

## Rendering choice: DOM + inline SVG

The game is management-UI-heavy (panels, lists, shops, logs) — DOM handles that
natively with accessibility and layout for free. Creature art is procedurally
generated **inline SVG**: deterministic geometry derived from each creature's
own data (elements, archetype, rarity, seed). SVG scales crisply at any size,
serializes cleanly into share strings, and swaps trivially for real raster art
from an image API later. Canvas would buy nothing here and cost us layout.

## Folder structure

```
monster-fusion-tycoon/
  index.html      — page shell, tab layout, modal containers
  css/style.css   — all styling
  js/
    config.js     — THE tuning file: every balance knob, grouped & commented
    rng.js        — seeded deterministic RNG helpers
    creature.js   — creature data model, species naming, signatures
    art.js        — generateCreatureArt() async boundary (procedural SVG stub)
    fusion.js     — deterministic fusion/breeding logic
    economy.js    — habitats, passive revenue, maintenance, tick loop
    shop.js       — exchange shop: conversions, eggs, upgrades
    objectives.js — daily objectives + milestones
    save.js       — versioned localStorage persistence + migration
    share.js      — offline share-string export/import
    state.js      — central game state module (single owner of mutable state)
    ui.js         — all DOM rendering & event wiring
    main.js       — bootstrap + game loop
```

(Full documentation — CONFIG knobs, art boundary swap instructions, save schema,
share-string format — is filled in at the bottom of this file as systems land.)
