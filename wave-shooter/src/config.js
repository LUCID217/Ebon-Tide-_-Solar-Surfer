// Global game constants. Gameplay tuning lives in src/data/* — this file is
// only for engine-level values that rarely change.

export const VIEW_W = 960;   // camera / canvas size
export const VIEW_H = 640;

export const WORLD_W = 1600; // arena world size (camera scrolls)
export const WORLD_H = 1200;

export const DEPTHS = {
  floor: 0,
  cover: 10,
  corpse: 15,
  enemy: 20,
  player: 25,
  projectile: 30,
  fx: 40,
  ui: 100
};

// Physics groups collide with cover; these are shared collision sizes.
export const PLAYER_RADIUS = 14;
export const BULLET_LIFETIME_MS = 1400; // hard cap; weapons can shorten via range
