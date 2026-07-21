// =============================================================================
// ARENAS — static layout data: cover objects and enemy spawn points.
// Coordinates are in world space (see WORLD_W/WORLD_H in config.js: 1600x1200).
//
// Cover fields:
//   x, y      — center position
//   w, h      — size in px
//   type      — 'wall' (indestructible) or 'crate' (destructible)
//   hp        — only for destructible cover
// =============================================================================

export const ARENAS = {
  foundry: {
    name: 'The Foundry',
    playerStart: { x: 800, y: 600 },

    cover: [
      // Central cross of walls — the anchor of the arena
      { x: 800, y: 430, w: 200, h: 26, type: 'wall' },
      { x: 800, y: 770, w: 200, h: 26, type: 'wall' },

      // Corner crate clusters (destructible — cover erodes over a run)
      { x: 380, y: 300, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 440, y: 300, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 380, y: 360, w: 48, h: 48, type: 'crate', hp: 80 },

      { x: 1220, y: 300, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 1160, y: 300, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 1220, y: 360, w: 48, h: 48, type: 'crate', hp: 80 },

      { x: 380, y: 900, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 440, y: 900, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 380, y: 840, w: 48, h: 48, type: 'crate', hp: 80 },

      { x: 1220, y: 900, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 1160, y: 900, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 1220, y: 840, w: 48, h: 48, type: 'crate', hp: 80 },

      // Mid-lane walls left/right
      { x: 340, y: 600, w: 26, h: 180, type: 'wall' },
      { x: 1260, y: 600, w: 26, h: 180, type: 'wall' },

      // Loose crates near mid for shooter AI to duck behind
      { x: 640, y: 600, w: 48, h: 48, type: 'crate', hp: 80 },
      { x: 960, y: 600, w: 48, h: 48, type: 'crate', hp: 80 }
    ],

    // Enemies spawn at these points (director picks ones far from the player)
    spawnPoints: [
      { x: 90, y: 90 }, { x: 800, y: 70 }, { x: 1510, y: 90 },
      { x: 70, y: 600 }, { x: 1530, y: 600 },
      { x: 90, y: 1110 }, { x: 800, y: 1130 }, { x: 1510, y: 1110 }
    ]
  }
};

export const DEFAULT_ARENA = 'foundry';
