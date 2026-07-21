// =============================================================================
// PROGRESSION GRID — classes across (columns), loadouts down (rows).
// Each cell = a (class, loadout) combo the player can unlock and select.
//
// Rules:
//   - The starting cell is free and always unlocked.
//   - A locked cell can be bought only if ORTHOGONALLY ADJACENT to an
//     unlocked cell (progression spreads outward across the grid).
//   - Currency = credits, earned 1:1 from run score.
//
// costs[row][col] — row order matches `loadouts`, col order matches `classes`.
// Costs rise with distance from the start cell; none of these grant raw
// power, only different playstyles, so pricing is about pacing not balance.
// =============================================================================

export const GRID = {
  classes: ['ranger', 'juggernaut', 'wraith', 'warden'],   // columns
  loadouts: ['assault', 'marksman', 'breacher', 'tech'],   // rows

  start: { classId: 'ranger', loadoutId: 'assault' },      // cell (0,0)

  costs: [
    //ranger jugg  wraith warden
    [0,     900,  1400,  2200],  // assault
    [700,   1600, 2000,  2800],  // marksman
    [1200,  2000, 2600,  3400],  // breacher
    [1800,  2600, 3200,  4200]   // tech
  ]
};
