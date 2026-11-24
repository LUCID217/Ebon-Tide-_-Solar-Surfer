# CLAUDE.md: Monster Fusion Tycoon

Rules and workflow for any AI agent working in this folder. **README.md is the reference** for the game design, file map, CONFIG knobs, save schema and share format. Read it before changing anything. This file covers how to work here and what never to break.

## What this is
- A fusion/breeding collection game with an idle zoo tycoon layer, played in a mobile browser. Owner: Eugene (ETS / Deadweight Developments).
- **Own IP.** It has nothing to do with Cinderwrought or Ebon Tide, so no dieselpunk, no Thrum, no Solar Surfer lore.
- **Design goal:** fusion should *feel* limitless without *being* limitless. There are 125 species (5 elements × 5 body types × 5 classes), kept varied by dice, traits and lineage.
- **Purpose in the studio:** prove that a large network of art parts can combine coherently (15 layered parts → 125 species).

## Scope
- Work only inside `monster-fusion-tycoon/`. **Never touch the Godot project at the repo root** (Solar Surfer), or any other branch.
- Working branch: `claude/monster-fusion-tycoon-eeqkj1`. Never push to `main`.

## Commands (run from `monster-fusion-tycoon/`)
| Task | Command |
|---|---|
| Dev server | `python3 -m http.server 8000` |
| Build the shipped bundle | `node tools/build-single.mjs` → `dist/monster-fusion-tycoon.html` |
| Tests (needs the `playwright` package + Chromium) | `node tests/run.mjs` |

The dist bundle is what players load (Eugene deploys it to Netlify). **Rebuild it after every source change and commit it with that change**, so the source and the bundle never drift apart.

## Hard rules: never break these
1. **Fusion is deterministic and synchronous.** The outcome is sealed from `childSeed` when Fuse is pressed (seeded `rng.js`, no `Math.random()` in game logic). That rules out save-scumming, network calls and async work in `fusion.js`.
2. **One odds source.** The den preview and the actual roll both use `fusionOdds()`. Never let them diverge.
3. **All balance numbers live in `CONFIG` in `config.js`.** Don't hard-code magic numbers in logic or UI.
4. **`state.js` owns all mutable state (`S`).** UI modules render and call logic. No stray globals.
5. **Saves never break.** Any change to saved data means bumping `CONFIG.save.schemaVersion`, adding a forward step in `MIGRATIONS` and adding a migration test. The lineage ledger is append-only: never rewrite or drop records.
6. **No secrets in the client.** Real image APIs go through a server proxy only (see the TODO in `art.js`). `generateCreatureArt()` stays the single async art boundary, and the game must stay playable if art never loads.
7. **Robustness:** never `window.confirm()` (use the in-game dialog in `ui.js`), use `location.href` and not `location.origin`, guard storage with `storageOk()`, no external fetches or CDNs, zero console errors, no overflow at a 390px width.
8. **Balance guards that have already been fixed and must stay fixed:** no early-game coin bleed (Meadow sanctuaries charge zero upkeep), eggs never hatch rare or above (Seers included), radiant eggs stay locked until 15 fusions, and legendary and above always carry at least one burden. Tests cover all of these, so don't weaken a test to make it pass.

## Workflow: plan, build, test, explain
1. **Understand.** Read README.md and the files you will touch. Say what is there before proposing changes.
2. **Plan.** For anything bigger than a one-file fix, write a short plan covering the files, the approach, the risks and whether the save schema is affected. Wait for Eugene's OK.
3. **Build in small commits.** Each commit does one thing, with a clear message.
4. **Test.** Rebuild the bundle, then run `node tests/run.mjs`. It must be all green. Add a test for every new rule or bug fix.
5. **Explain back.** Finish with a plain-English summary: what changed, why, how it was tested, and anything Eugene should check by playing. Keep it short enough to read on a phone.

## Needs Eugene's sign-off first
- Schema version bumps or migrations
- Balance changes outside the task's stated scope
- Deleting files, features or save data
- New dependencies, network calls, a backend, or anything that costs money (image APIs, Meshy credits)
- Deploying, merging, or any push outside the working branch

## Where decisions live
- **Design decisions** are made in the "Monster Fusion" chat thread with Claude, then written into README.md. If the code and the README disagree, stop and ask rather than guess.
- **Art direction:** vinyl toy style. Modular 2D parts: 5 greyscale bodies recoloured per element, 5 class-gear sets, element FX. Thick dark-plum outline (#2A2238), flat or 2-tone shading. Art is generated in Grok from the "Monster Fusion art context" doc. Original IP only, so never imitate Pokémon, Digimon or Palworld.
- **Planned, not started:** hidden secret recipes (after the 125 base species are working), real art replacing the procedural SVG parts in `art.js` (`BODIES`, `paletteFor`, `GEAR`), and a reusable creature-spec skill.
