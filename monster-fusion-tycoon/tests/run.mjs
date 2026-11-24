// ============================================================================
// tests/run.mjs — Playwright regression suite for Monster Fusion Tycoon.
//
//   node tests/run.mjs            (from monster-fusion-tycoon/)
//
// Starts its own static server, drives the real ES modules in Chromium, and
// exits non-zero on any failure. No test-runner dependency: just `playwright`.
// Covers: smoke (every tab, zero console errors, no 390px overflow), the
// 5/5/5 fusion rules, determinism, v4→v5 save migration (lineage preserved),
// share strings (MFT2 round-trip, MFT1 legacy import, garbage rejected),
// balance guards (no early coin bleed, radiant egg gate, eggs never rare+),
// a 60-fusion playtest, and the single-file dist bundle over file://.
// ============================================================================

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, extname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

// --- tiny static server ------------------------------------------------------
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png' };
const server = createServer(async (req, res) => {
  const path = join(ROOT, decodeURIComponent(req.url.split('?')[0].split('#')[0]).replace(/^\/$/, '/index.html'));
  if (!path.startsWith(ROOT) || !existsSync(path)) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'content-type': MIME[extname(path)] || 'application/octet-stream' });
  res.end(await readFile(path));
});
await new Promise(r => server.listen(0, r));
const BASE = `http://localhost:${server.address().port}/`;

// --- harness -------------------------------------------------------------------
let failures = 0;
const results = [];
async function test(name, fn) {
  try { await fn(); results.push(`✓ ${name}`); }
  catch (e) { failures++; results.push(`✗ ${name}\n    ${e.message.split('\n').join('\n    ')}`); }
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }

const browser = await chromium.launch();

/** Fresh page with error capture. `init` runs before any page script. */
async function openPage(url = BASE, { init = null, width = 390 } = {}) {
  const ctx = await browser.newContext({ viewport: { width, height: 844 } });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  if (init) await ctx.addInitScript(init.fn, init.arg);
  await page.goto(url);
  await page.waitForSelector('#tabs .tab');
  await page.waitForTimeout(300);
  // Close first-visit help if it is open.
  const close = await page.$('#help-close');
  if (close) await close.click();
  return { page, ctx, errors };
}

// ==============================================================================

await test('smoke: every tab renders, zero console errors, no 390px overflow', async () => {
  const { page, ctx, errors } = await openPage();
  for (const t of ['menagerie', 'den', 'shop', 'collection', 'objectives']) {
    await page.click(`#tabs .tab[data-tab="${t}"]`);
    await page.waitForTimeout(250);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    assert(overflow <= 1, `tab ${t} overflows by ${overflow}px at 390px`);
  }
  const dex = await page.textContent('#tab-collection');
  assert(/\/ 125 species/.test(dex), 'collection should show an N / 125 dex counter');
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await ctx.close();
});

await test('fusion rules: element / type / class axes', async () => {
  const { page, ctx, errors } = await openPage();
  const out = await page.evaluate(async () => {
    const C = await import('/js/config.js');
    const { makeBaseCreature } = await import('/js/creature.js');
    const { computeChild, fusionOdds } = await import('/js/fusion.js');
    const mk = (element, type, cls, rarity = 'common', seed = 7) =>
      ({ ...makeBaseCreature({ element, rarity, seed }), type, cls, traits: [] });
    const fails = [];
    const N = 4000;
    // Same element kept (ignoring the small base mutation chance).
    { const a = mk('ember', 'beast', 'seer'), b = mk('ember', 'beast', 'seer', 'common', 9);
      let kept = 0; for (let s = 0; s < N; s++) { const c = computeChild(a, b, s); if (c.element === 'ember') kept++; if (c.mutated && c.element === 'ember') fails.push('mutation kept same element'); }
      const exp = 1 - fusionOdds(a, b).mutationChance;
      if (Math.abs(kept / N - exp) > 0.03) fails.push(`same-element kept ${kept / N} vs ${exp}`);
      if (computeChild(a, b, 1).type !== 'beast') fails.push('same type not kept');
      if (computeChild(a, b, 1).cls !== 'seer') fails.push('same class not kept'); }
    // Every feeds pair gives the fed element (unless mutated), both orders.
    for (const el of C.ELEMENT_CYCLE) {
      const fed = C.feedsTarget(el);
      for (const [x, y] of [[el, fed], [fed, el]]) {
        const a = mk(x, 'wyrm', 'brute'), b = mk(y, 'wyrm', 'brute', 'common', 3);
        const o = fusionOdds(a, b);
        if (o.bond !== 'feeds' || o.elementOdds[fed] !== 1) fails.push(`feeds ${x}+${y} → ${JSON.stringify(o.elementOdds)}`);
        for (let s = 0; s < 200; s++) { const c = computeChild(a, b, s); if (!c.mutated && c.element !== fed) fails.push(`feeds child ${c.element}`); }
      }
    }
    // Overcomes pairs are volatile; mutation goes to a THIRD element only.
    const pairs = [['ember', 'frost'], ['stone', 'tide'], ['frost', 'grove'], ['tide', 'ember'], ['grove', 'stone']];
    for (const [x, y] of pairs) {
      const a = mk(x, 'avian', 'tender'), b = mk(y, 'avian', 'tender', 'common', 5);
      const o = fusionOdds(a, b);
      if (o.bond !== 'volatile') fails.push(`${x}>${y} not volatile`);
      let mut = 0;
      for (let s = 0; s < N; s++) {
        const c = computeChild(a, b, s);
        if (c.mutated) { mut++; if (c.element === x || c.element === y) fails.push('volatile mutation reused a parent element'); }
        else if (c.element !== x && c.element !== y) fails.push('volatile non-mutant got a third element');
      }
      if (Math.abs(mut / N - o.mutationChance) > 0.03) fails.push(`volatile mutation ${mut / N} vs ${o.mutationChance}`);
    }
    // Type: 60/40 favouring the rarer parent.
    { const a = mk('ember', 'beast', 'brute', 'rare', 11), b = mk('ember', 'crawler', 'brute', 'common', 12);
      let rarer = 0; for (let s = 0; s < N; s++) if (computeChild(a, b, s).type === 'beast') rarer++;
      if (Math.abs(rarer / N - C.CONFIG.fusion.typeRarerParentWeight) > 0.03) fails.push(`type rarer share ${rarer / N}`); }
    // Class: every cell of the recipe table, both orders.
    for (const x of C.CLASS_KEYS) for (const y of C.CLASS_KEYS) {
      const c = computeChild(mk('stone', 'construct', x), mk('stone', 'construct', y, 'common', 2), 99);
      if (c.cls !== C.CLASS_RECIPES[x][y] || C.CLASS_RECIPES[x][y] !== C.CLASS_RECIPES[y][x]) fails.push(`recipe ${x}+${y}`);
    }
    // Determinism: same parents + seed → identical child.
    { const a = mk('tide', 'wyrm', 'seer'), b = mk('grove', 'avian', 'trickster', 'uncommon', 4);
      const strip = c => JSON.stringify({ ...c, id: 0, bornAt: 0 });
      for (let s = 0; s < 50; s++) if (strip(computeChild(a, b, s)) !== strip(computeChild(a, b, s))) fails.push('non-deterministic child'); }
    // 125 distinct species names.
    const { speciesName } = await import('/js/creature.js');
    const names = new Set();
    for (const element of C.ELEMENT_CYCLE) for (const type of C.TYPE_KEYS) for (const cls of C.CLASS_KEYS) names.add(speciesName({ element, type, cls }));
    if (names.size !== 125) fails.push(`expected 125 species names, got ${names.size}`);
    return fails.slice(0, 10);
  });
  assert(out.length === 0, out.join('\n'));
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await ctx.close();
});

// A hand-built schema-v4 save: old elements/archetypes everywhere, a lineage
// ledger with 2 records (3 generations), a pending fusion, and an old biome.
const V4_SAVE = {
  version: 4,
  resources: { coins: 1234, essence: 50, relics: 2 },
  creatures: {
    cA: { id: 'cA', seed: 111, elements: ['fire', 'light'], archetype: 'Drake', tier: 3, rarity: 'rare', stats: { power: 60, charm: 50, vitality: 40 }, parents: ['Old X', 'Old Y'], habitatId: 'h2', bornAt: 1, fusedCount: 0, traits: ['prodigy'], name: 'Pyro-Volt Drake' },
    cB: { id: 'cB', seed: 222, elements: ['nature'], archetype: 'Moth', tier: 1, rarity: 'common', stats: { power: 30, charm: 30, vitality: 30 }, parents: null, habitatId: 'h1', bornAt: 2, fusedCount: 0, traits: [], name: 'Bloom Moth' },
    cC: { id: 'cC', seed: 333, elements: ['light', 'shadow', 'water'], archetype: 'Unknownium', tier: 2, rarity: 'uncommon', stats: { power: 40, charm: 40, vitality: 40 }, parents: null, habitatId: null, bornAt: 3, fusedCount: 0, traits: ['frugal'], name: 'Lumen-Umbra-Aqua Thing' },
  },
  habitats: { h1: { id: 'h1', biome: 'meadow', level: 1, decorations: 0, name: 'Meadow Pen' }, h2: { id: 'h2', biome: 'fire', level: 2, decorations: 1, name: 'Ember Ridge' } },
  habitatOrder: ['h1', 'h2'],
  collectPool: 0,
  discovered: {
    'fire+light|Drake': { name: 'Pyro-Volt Drake', elements: ['fire', 'light'], archetype: 'Drake', rarity: 'rare', seed: 111, tier: 3, firstAt: 10, count: 2 },
    'fire|Drake': { name: 'Pyro Drake', elements: ['fire'], archetype: 'Drake', rarity: 'common', seed: 5, tier: 1, firstAt: 5, count: 3 },
    'nature|Moth': { name: 'Bloom Moth', elements: ['nature'], archetype: 'Moth', rarity: 'common', seed: 222, tier: 1, firstAt: 7, count: 1 },
  },
  lineage: {
    cA: { at: 100, a: { id: 'p1', name: 'Pyro Drake', tier: 2, rarity: 'uncommon', elements: ['fire'], archetype: 'Drake', seed: 5, traits: [], mutated: false },
                   b: { id: 'p2', name: 'Volt Wisp', tier: 1, rarity: 'common', elements: ['storm'], archetype: 'Wisp', seed: 6, traits: [], mutated: false } },
    p1: { at: 50, a: { id: 'g1', name: 'Ember Imp', tier: 1, rarity: 'common', elements: ['fire'], archetype: 'Imp', seed: 8, traits: [], mutated: false },
                  b: { id: 'g2', name: 'Clay Golem', tier: 1, rarity: 'common', elements: ['earth'], archetype: 'Golem', seed: 9, traits: [], mutated: false } },
  },
  pendingFusion: null,
  counters: { fusions: 2, eggsBought: 1, coinsEarned: 5000, creatureId: 10, collects: 3, habitatsBuilt: 1, discoveries: 3, habitatUpgrades: 1 },
  upgrades: { autoCollector: false, groundskeeper: false, fusionRitualist: false },
  objectives: { dailyDate: null, daily: [], milestonesClaimed: { fusion_1: true } },
  lastSeen: Date.now(),
};

await test('migration: v4 save → v5, creatures carry over, lineage preserved', async () => {
  const { page, ctx, errors } = await openPage(BASE, {
    init: { fn: save => { if (!sessionStorage.getItem('seeded')) { localStorage.setItem('mft_save', JSON.stringify(save)); sessionStorage.setItem('seeded', '1'); } }, arg: V4_SAVE },
  });
  const out = await page.evaluate(async () => {
    const { S } = await import('/js/state.js');
    const C = await import('/js/config.js');
    const fails = [];
    if (S.version !== 5) fails.push('version ' + S.version);
    for (const c of Object.values(S.creatures)) {
      if (!C.ELEMENTS[c.element] || !C.TYPES[c.type] || !C.CLASSES[c.cls]) fails.push('bad creature ' + JSON.stringify(c));
      if ('elements' in c || 'archetype' in c) fails.push('legacy fields left on ' + c.id);
    }
    const a = S.creatures.cA;
    if (!a || a.element !== 'ember' || a.type !== 'wyrm' || a.cls !== 'brute') fails.push('cA remap ' + JSON.stringify(a));
    if (a && (a.stats.power !== 60 || a.seed !== 111 || a.traits[0] !== 'prodigy' || a.tier !== 3)) fails.push('cA lost data');
    if (a && a.legacyName !== 'Pyro-Volt Drake') fails.push('legacyName not kept');
    if (S.creatures.cB.element !== 'grove' || S.creatures.cB.type !== 'avian') fails.push('cB remap');
    if (Object.keys(S.lineage).length !== 2) fails.push('lineage records lost');
    for (const rec of Object.values(S.lineage)) for (const s of [rec.a, rec.b]) {
      if (!C.ELEMENTS[s.element] || !C.TYPES[s.type] || !C.CLASSES[s.cls]) fails.push('bad snapshot ' + JSON.stringify(s));
    }
    const { generationOf } = await import('/js/lineage.js');
    if (generationOf('cA') !== 3) fails.push('generation ' + generationOf('cA'));
    // fire+light|Drake and fire|Drake both → ember|wyrm|brute: merged.
    const d = S.discovered['ember|wyrm|brute'];
    if (!d || d.count !== 5 || d.rarity !== 'rare' || d.firstAt !== 5) fails.push('discovery merge ' + JSON.stringify(d));
    for (const k of Object.keys(S.discovered)) if (k.split('|').length !== 3) fails.push('bad dex key ' + k);
    if (S.habitats.h2.biome !== 'ember') fails.push('biome remap ' + S.habitats.h2.biome);
    if (S.resources.coins < 1000) fails.push('coins lost');
    return fails;
  });
  assert(out.length === 0, out.join('\n'));
  // Lineage modal renders migrated snapshots.
  await page.evaluate(async () => {
    const { S } = await import('/js/state.js');
    const { showLineageModal } = await import('/js/ui_lineage.js');
    showLineageModal(S.creatures.cA);
  });
  await page.waitForTimeout(300);
  const nodes = await page.$$eval('.lin-node', ns => ns.length);
  assert(nodes === 5, `lineage tree should show 5 nodes, got ${nodes}`);
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await ctx.close();
});

await test('share strings: MFT2 round-trip, MFT1 legacy import, garbage fails gracefully', async () => {
  const { page, ctx, errors } = await openPage();
  const out = await page.evaluate(async () => {
    const { exportCreature, decodeShareString } = await import('/js/share.js');
    const { makeBaseCreature } = await import('/js/creature.js');
    const { hashStr } = await import('/js/rng.js');
    const fails = [];
    const c = makeBaseCreature({ element: 'frost', rarity: 'uncommon', seed: 4242 });
    const str = exportCreature(c);
    if (!str.startsWith('MFT2.')) fails.push('not MFT2');
    const r = decodeShareString(str);
    if (!r.ok || r.creature.element !== c.element || r.creature.type !== c.type || r.creature.cls !== c.cls || r.creature.name !== c.name) fails.push('round trip ' + JSON.stringify(r));
    // Hand-built MFT1 string (old format).
    const enc = s => btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    const p1 = enc(JSON.stringify({ seed: 99, elements: ['water', 'storm'], archetype: 'Kraken', tier: 2, rarity: 'rare', stats: { power: 50, charm: 50, vitality: 50 }, parents: null }));
    const r1 = decodeShareString(`MFT1.${p1}.${hashStr(p1).toString(36)}`);
    if (!r1.ok || r1.creature.type !== 'crawler' || r1.creature.cls !== 'brute' || !['tide', 'frost'].includes(r1.creature.element)) fails.push('MFT1 import ' + JSON.stringify(r1));
    // Garbage and wrong shapes fail with a reason, never throw.
    const bad = ['', 'hello', 'MFT9.abc.def', 'MFT2.abc.def', `MFT2.${enc('{"seed":1}')}.${hashStr(enc('{"seed":1}')).toString(36)}`,
      `MFT1.${enc('{"seed":1,"elements":[]}')}.${hashStr(enc('{"seed":1,"elements":[]}')).toString(36)}`, `MFT2.${enc('null')}.${hashStr(enc('null')).toString(36)}`];
    for (const b of bad) { try { const x = decodeShareString(b); if (x.ok || !x.why) fails.push('accepted garbage ' + b); } catch (e) { fails.push('threw on ' + b + ': ' + e.message); } }
    return fails;
  });
  assert(out.length === 0, out.join('\n'));
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await ctx.close();
});

await test('balance: no early coin bleed, radiant egg gate, eggs never rare+', async () => {
  const { page, ctx, errors } = await openPage();
  const out = await page.evaluate(async () => {
    const { S } = await import('/js/state.js');
    const { CONFIG } = await import('/js/config.js');
    const econ = await import('/js/economy.js');
    const shop = await import('/js/shop.js');
    const { makeBaseCreature } = await import('/js/creature.js');
    const fails = [];
    // Fresh game: starters bill zero upkeep and the menagerie nets ≥ 0.
    const t = econ.totalPerSec();
    if (t.maintenance !== 0) fails.push('fresh game upkeep ' + t.maintenance);
    if (t.net < 0) fails.push('fresh game net ' + t.net);
    // Commons are free to keep for every class (Brute ×1.6 of 0 is 0).
    for (const cls of ['brute', 'guardian', 'tender', 'seer', 'trickster']) {
      const c = { ...makeBaseCreature({ rarity: 'common', seed: 1 }), cls, habitatId: null };
      S.creatures[c.id] = c;
      if (econ.upkeepPerSec(c) !== 0) fails.push(`common ${cls} bills upkeep in reserve`);
      // Uncommons in a meadow sanctuary bill nothing either.
      c.rarity = 'uncommon'; c.habitatId = S.habitatOrder[0];
      if (econ.upkeepPerSec(c) !== 0) fails.push(`uncommon ${cls} bills upkeep in meadow`);
      delete S.creatures[c.id];
    }
    // Radiant egg: locked before 15 fusions, weights unchanged.
    S.resources.relics = 5;
    if (shop.buyRadiantEgg().ok) fails.push('radiant egg bought before unlock');
    if (CONFIG.shop.radiantEggUnlockFusions !== 15 || CONFIG.shop.radiantEggRelics !== 1) fails.push('radiant gate changed');
    if (JSON.stringify(CONFIG.shop.radiantEggWeights) !== JSON.stringify({ common: 0, uncommon: 0, rare: 70, epic: 25, legendary: 5, mythic: 0 })) fails.push('radiant weights changed');
    // 10 Seers on exhibit: egg luck capped, still common/uncommon only.
    for (let i = 0; i < 10; i++) { const c = { ...makeBaseCreature({ seed: 500 + i }), cls: 'seer', habitatId: S.habitatOrder[0] }; S.creatures[c.id] = c; }
    const w = shop.eggWeights().weights;
    if (w.rare || w.epic || w.legendary || w.mythic) fails.push('seer luck enabled rare+ eggs');
    if (w.uncommon - CONFIG.rarity.eggWeights.uncommon > CONFIG.classes.seer.eggUncommonWeightCap) fails.push('seer luck uncapped');
    S.resources.coins = 1e15;
    for (let i = 0; i < 150; i++) {
      const r = shop.buyEgg();
      if (!r.ok) { fails.push('egg purchase failed: ' + r.why); break; }
      if (!['common', 'uncommon'].includes(r.creature.rarity)) fails.push('egg hatched ' + r.creature.rarity);
    }
    return fails;
  });
  assert(out.length === 0, out.join('\n'));
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await ctx.close();
});

await test('playtest: 60 fusions through the real pipeline, art + share + save on every child', async () => {
  const { page, ctx, errors } = await openPage();
  const out = await page.evaluate(async () => {
    const { S, spend } = await import('/js/state.js');
    const C = await import('/js/config.js');
    const { startFusion, tryResolveFusion } = await import('/js/fusion.js');
    const { buyEgg } = await import('/js/shop.js');
    const { generateCreatureArt } = await import('/js/art.js');
    const { exportCreature, decodeShareString } = await import('/js/share.js');
    const { saveGame } = await import('/js/save.js');
    const fails = [];
    S.resources.coins = 1e9; S.resources.essence = 1e7;
    for (let i = 0; i < 60; i++) {
      while (Object.keys(S.creatures).length < 4) buyEgg();
      const ids = Object.keys(S.creatures).sort((x, y) => S.creatures[y].tier - S.creatures[x].tier);
      const r = startFusion(ids[0], ids[1], spend);
      if (!r.ok) { // tier cap: release one and continue
        delete S.creatures[ids[0]]; continue;
      }
      S.pendingFusion.resolveAt = 0;
      const child = tryResolveFusion();
      if (!child) { fails.push('fusion did not resolve'); break; }
      if (!C.ELEMENTS[child.element] || !C.TYPES[child.type] || !C.CLASSES[child.cls]) fails.push('bad child ' + JSON.stringify(child));
      if (!S.lineage[child.id]) fails.push('no lineage record');
      const art = await generateCreatureArt(child);
      if (art.kind !== 'svg' || !art.svg.includes('<svg')) fails.push('art failed');
      const back = decodeShareString(exportCreature(child));
      if (!back.ok || back.creature.name !== child.name) fails.push('share failed');
      for (const v of Object.values(S.resources)) if (!Number.isFinite(v) || v < 0) fails.push('bad resource ' + v);
    }
    if (!saveGame()) fails.push('save failed');
    return { fails: fails.slice(0, 10), species: Object.keys(S.discovered).length, lineage: Object.keys(S.lineage).length };
  });
  assert(out.fails.length === 0, out.fails.join('\n'));
  assert(out.lineage >= 55, 'lineage records ' + out.lineage);
  assert(out.species <= 125, 'more species than the dex holds: ' + out.species);
  await page.click('#tabs .tab[data-tab="collection"]');
  await page.waitForTimeout(300);
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  results.push(`    (playtest discovered ${out.species}/125 species)`);
  await ctx.close();
});

await test('dist bundle loads over file:// with zero console errors', async () => {
  const dist = join(ROOT, 'dist', 'monster-fusion-tycoon.html');
  assert(existsSync(dist), 'dist bundle missing — run node tools/build-single.mjs');
  const { page, ctx, errors } = await openPage(pathToFileURL(dist).href);
  await page.click('#tabs .tab[data-tab="collection"]');
  await page.waitForTimeout(300);
  const dex = await page.textContent('#tab-collection');
  assert(/\/ 125 species/.test(dex), 'bundle is stale (no 125-species dex) — rebuild it');
  assert(errors.length === 0, 'console errors: ' + errors.join(' | '));
  await ctx.close();
});

await browser.close();
server.close();
console.log(results.join('\n'));
console.log(failures ? `\n${failures} FAILED` : '\nAll green.');
process.exit(failures ? 1 : 0);
