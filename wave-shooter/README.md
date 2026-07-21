# Wave Shooter

A top-down twin-stick wave survival shooter (Halo: Spartan Assault vibes) built
with **Phaser 3 + Vite**. Fixed roster of characters with hand-authored
loadouts, line-of-sight cover, escalating waves, and a grid of unlockable
(class × loadout) combos. No loot — every unlock changes how a run plays, not
how big the numbers are.

## Run it

```bash
npm install
npm run dev      # dev server with HMR
npm run build    # static build in dist/ — deploy anywhere
npm run preview  # serve the production build locally
```

Desktop browser, keyboard + mouse.

## Controls

| Input | Action |
|---|---|
| **WASD / arrows** | Move (8-directional) |
| **Mouse** | Aim (independent of movement) |
| **LMB** | Fire |
| **SHIFT / RMB** | Ability |

## How it plays

1. Pick an unlocked **class × loadout** cell on the roster grid and deploy.
2. Clear escalating waves: rushers → shooters (cover-seeking) → flankers → heavies.
3. From wave 5, random **modifiers** apply (frenzy, armored, horde, heavy drop).
4. Chain kills inside the combo window for up to **x5 score**.
5. Death ends the run; score banks 1:1 as **credits**.
6. Spend credits on grid cells **adjacent to ones you own**.

Shields regen after a few quiet seconds; health doesn't. Cover blocks shots
both ways — crates are destructible, walls aren't, and the Tech kit deploys
its own barricade.

## Project layout

```
src/
  data/        ← THE TUNING SURFACE. Classes, loadouts, abilities, enemies,
                 wave curve/modifiers, arena layouts, progression grid+costs.
                 Adding content = adding entries here, not writing systems.
  systems/     ← SaveManager (localStorage behind an interface), WaveDirector,
                 ability behavior library, LOS/cover helpers, input layer,
                 build resolver (class mods × loadout), placeholder WebAudio sfx.
  entities/    ← Player, Enemy (state machine AI), pooled projectiles.
  scenes/      ← Boot (generates all placeholder textures = asset manifest),
                 Roster (progression grid), Game, HUD, GameOver.
```

## Swapping in real art / sound

- Every texture key is generated in `scenes/BootScene.js` — replace a
  `generateTexture` block with `this.load.image(key, url)` and nothing else
  changes.
- All sound goes through `systems/sfx.js`'s named functions — same deal.

## Save data

Progress (credits, unlocked cells, bests) lives in `localStorage` under
`wave-shooter-save-v1`, wrapped by `systems/SaveManager.js` so a backend could
replace it later. The roster screen has a small `[wipe save]` link.
