// ============================================================================
// build-single.mjs — bundle the game into ONE self-contained HTML file.
//
// No bundler, no transforms of the code itself: each js/*.js module is
// embedded as a base64 data: URL and wired up with an import map, so real
// ES-module scoping is preserved (no name collisions, no refactoring).
// Relative specifiers ('./x.js') are rewritten to bare names ('x') because
// data: modules can't resolve relative URLs — the import map resolves them.
//
// Usage: node tools/build-single.mjs   → writes dist/monster-fusion-tycoon.html
// The output runs from file:// or any static host. Source of truth stays the
// multi-file project; rebuild after changes.
// ============================================================================

import { readFileSync, writeFileSync, readdirSync, mkdirSync } from 'node:fs';
import { dirname, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// Rewrite relative module specifiers to bare names the import map can serve.
const bareify = src => src
  .replace(/from '\.\/([\w-]+)\.js'/g, "from '$1'")
  .replace(/import '\.\/([\w-]+)\.js'/g, "import '$1'");

const imports = {};
for (const f of readdirSync(join(root, 'js')).filter(f => f.endsWith('.js'))) {
  const src = bareify(readFileSync(join(root, 'js', f), 'utf8'));
  imports[basename(f, '.js')] =
    'data:text/javascript;base64,' + Buffer.from(src, 'utf8').toString('base64');
}

const css = readFileSync(join(root, 'css', 'style.css'), 'utf8');
let html = readFileSync(join(root, 'index.html'), 'utf8');

html = html.replace(
  '<link rel="stylesheet" href="css/style.css">',
  `<style>\n${css}\n</style>`,
);
html = html.replace(
  '<script type="module" src="js/main.js"></script>',
  `<script type="importmap">\n${JSON.stringify({ imports }, null, 1)}\n</script>\n` +
  `<script type="module">import 'main';</script>`,
);

mkdirSync(join(root, 'dist'), { recursive: true });
const out = join(root, 'dist', 'monster-fusion-tycoon.html');
writeFileSync(out, html);
console.log(`wrote ${out} (${(html.length / 1024).toFixed(0)} KiB, ${Object.keys(imports).length} modules)`);
