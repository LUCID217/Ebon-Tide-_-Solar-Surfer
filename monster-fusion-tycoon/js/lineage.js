// ============================================================================
// lineage.js — the ancestry ledger (save schema v4).
//
// Fusion consumes both parents, so without this ledger a creature's ancestry
// is unrecoverable the moment the ritual resolves. One compact record is
// appended per fusion event, keyed by the CHILD's id:
//
//   S.lineage[childId] = { at, a: <snapshot>, b: <snapshot> }
//
// Snapshots hold only what the tree view needs to name, badge, and redraw an
// ancestor (art regenerates deterministically from seed via art.js) — NOT the
// full creature object. Measured cost: ~0.3 KB of JSON per fusion record, so
// even a 1000-fusion save spends ~300 KB of its ~5 MB localStorage budget.
//
// The ledger is append-only and survives the death/sale of every creature in
// it. Ancestors that were themselves fused chain back through their own
// records; ids with no record are roots (eggs, starters, imports).
// Lineage does NOT travel in share strings — it is local history.
// ============================================================================

import { S } from './state.js';

/** Minimal ancestor snapshot: identity + everything the art stub draws from. */
export function snapCreature(c) {
  return {
    id: c.id,
    name: c.name || 'Unnamed', // real creatures always carry a name; guard hand-edited saves
    tier: c.tier,
    rarity: c.rarity,
    elements: [...c.elements],
    archetype: c.archetype,
    seed: c.seed,
    traits: [...(c.traits || [])],
    mutated: !!c.mutated,
  };
}

/** Append the ledger record for a resolved fusion. Called once per fusion,
 *  from tryResolveFusion — the only moment both parents still exist in full. */
export function recordFusion(child, parentA, parentB) {
  if (!S.lineage) S.lineage = {}; // belt-and-braces for pre-v4 states
  S.lineage[child.id] = { at: Date.now(), a: snapCreature(parentA), b: snapCreature(parentB) };
}

/** The fusion record that produced this creature id, or null (= root). */
export function lineageRecord(id) {
  return (S.lineage && S.lineage[id]) || null;
}

/**
 * Generation number: roots (eggs/starters/imports) are Gen 1; a fused child
 * is 1 + max(parent generations). Pure walk over the ledger; the `seen` set
 * guards against (theoretically impossible) cycles in hand-edited saves.
 */
export function generationOf(id, seen = new Set()) {
  const rec = lineageRecord(id);
  if (!rec || seen.has(id)) return 1;
  seen.add(id);
  return 1 + Math.max(generationOf(rec.a.id, seen), generationOf(rec.b.id, seen));
}

/** Total distinct ancestor records behind this creature (bragging rights). */
export function ancestorCount(id, seen = new Set()) {
  const rec = lineageRecord(id);
  if (!rec || seen.has(id)) return 0;
  seen.add(id);
  return 2 + ancestorCount(rec.a.id, seen) + ancestorCount(rec.b.id, seen);
}
