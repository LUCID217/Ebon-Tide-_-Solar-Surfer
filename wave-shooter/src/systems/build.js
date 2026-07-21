// Resolves a grid cell (class column + loadout row) into the concrete stat
// block a run uses: class chassis stats + loadout weapon/ability with class
// modifiers baked in. GameScene receives one of these and never needs to
// know about the grid.

import { CLASSES } from '../data/classes.js';
import { LOADOUTS } from '../data/loadouts.js';
import { ABILITIES } from '../data/abilities.js';
import { GRID } from '../data/progression.js';

export function resolveBuild(col, row) {
  const classId = GRID.classes[col];
  const loadoutId = GRID.loadouts[row];
  const cls = CLASSES[classId];
  const loadout = LOADOUTS[loadoutId];
  const abilityDef = ABILITIES[loadout.ability];
  const m = cls.mods;

  return {
    classId,
    loadoutId,
    className: cls.name,
    loadoutName: loadout.name,
    color: cls.color,
    bodyScale: cls.bodyScale,

    // chassis
    speed: cls.speed,
    health: cls.health,
    shield: cls.shield,
    shieldRegenDelayMs: cls.shieldRegenDelayMs,
    shieldRegenRate: cls.shieldRegenRate,

    // weapon with class mods applied
    weapon: {
      ...loadout.weapon,
      damage: loadout.weapon.damage * m.damage,
      fireRate: loadout.weapon.fireRate * m.fireRate,
      projectileSpeed: loadout.weapon.projectileSpeed * m.projectileSpeed
    },

    // ability with class cooldown mod applied
    ability: {
      id: loadout.ability,
      ...abilityDef,
      cooldownMs: abilityDef.cooldownMs * m.cooldown
    }
  };
}

// One-line description of what a cell changes — shown on locked roster cells.
export function describeCell(col, row) {
  const cls = CLASSES[GRID.classes[col]];
  const loadout = LOADOUTS[GRID.loadouts[row]];
  const ability = ABILITIES[loadout.ability];
  return `${loadout.weapon.name} + ${ability.name}`;
}
