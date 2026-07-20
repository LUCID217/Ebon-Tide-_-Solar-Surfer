// ============================================================================
// rng.js — seeded, deterministic RNG.
// Everything gameplay-visible that involves "chance" (fusion outcomes, art
// geometry, egg rolls) goes through a seeded stream so results are
// reproducible from creature data alone (needed for share-strings & art).
// ============================================================================

/** mulberry32 — small, fast, good-enough 32-bit seeded PRNG. Returns () => [0,1). */
export function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Hash a string to a 32-bit seed (FNV-1a). */
export function hashStr(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** Fresh non-deterministic seed for brand-new creatures (eggs, starters). */
export function freshSeed() {
  return (Date.now() ^ (Math.random() * 0xffffffff)) >>> 0;
}

/** Pick one element of arr using rng stream. */
export function pick(rng, arr) {
  return arr[Math.floor(rng() * arr.length)];
}

/** Weighted pick: weights is {key: weight}. Returns a key. */
export function weightedPick(rng, weights) {
  const entries = Object.entries(weights).filter(([, w]) => w > 0);
  const total = entries.reduce((s, [, w]) => s + w, 0);
  let roll = rng() * total;
  for (const [key, w] of entries) {
    roll -= w;
    if (roll <= 0) return key;
  }
  return entries[entries.length - 1][0];
}
