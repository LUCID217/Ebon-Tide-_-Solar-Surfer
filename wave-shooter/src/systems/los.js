import Phaser from 'phaser';

// Line-of-sight helpers for the cover system. Cover objects are static
// arcade bodies; a shot (or an AI sight-line) is blocked if the segment
// between shooter and target crosses any cover rectangle.

const tmpLine = { x1: 0, y1: 0, x2: 0, y2: 0 };

function segmentHitsRect(x1, y1, x2, y2, rect) {
  tmpLine.x1 = x1; tmpLine.y1 = y1; tmpLine.x2 = x2; tmpLine.y2 = y2;
  return Phaser.Geom.Intersects.LineToRectangle(tmpLine, rect);
}

/**
 * True if there's an unobstructed line between two points.
 * @param {Phaser.GameObjects.Group} coverGroup group of cover sprites
 */
export function hasLineOfSight(x1, y1, x2, y2, coverGroup) {
  const children = coverGroup.getChildren();
  for (let i = 0; i < children.length; i++) {
    const c = children[i];
    if (!c.active) continue;
    if (segmentHitsRect(x1, y1, x2, y2, c.getBounds())) return false;
  }
  return true;
}

/**
 * Finds a position behind cover relative to a threat, for AI cover-seeking.
 * Returns {x, y} or null if no cover is close enough.
 */
export function findCoverPoint(fromX, fromY, threatX, threatY, coverGroup, maxDist = 420) {
  let best = null;
  let bestDist = Infinity;
  for (const c of coverGroup.getChildren()) {
    if (!c.active) continue;
    const d = Phaser.Math.Distance.Between(fromX, fromY, c.x, c.y);
    if (d > maxDist || d >= bestDist) continue;
    // point on the far side of the cover from the threat
    const dx = c.x - threatX;
    const dy = c.y - threatY;
    const len = Math.hypot(dx, dy) || 1;
    const pad = Math.max(c.displayWidth, c.displayHeight) / 2 + 26;
    best = { x: c.x + (dx / len) * pad, y: c.y + (dy / len) * pad };
    bestDist = d;
  }
  return best;
}
