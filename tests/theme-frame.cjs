const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const indexCss = fs.readFileSync(path.join(__dirname, '..', 'src', 'index.css'), 'utf8');
const listenCss = fs.readFileSync(path.join(__dirname, '..', 'src', 'components', 'ListenNow.css'), 'utf8');

const themeBlocks = [...indexCss.matchAll(/:root\[data-theme="[^"]+"\]\s*\{([^}]+)\}/g)]
  .filter(([, declarations]) => declarations.includes('--theme-surface-gradient'));
assert.equal(themeBlocks.length, 3, 'three non-default theme token blocks must exist');
for (const [, declarations] of themeBlocks) {
  assert.doesNotMatch(declarations, /--sidebar-width\s*:/, 'themes must not change the sidebar width');
  assert.doesNotMatch(declarations, /--playback-bar-height\s*:/, 'themes must not change playback height');
}

assert.match(listenCss, /\.listen-header\s*\{[^}]*height:\s*84px/s, 'header frame height is fixed');
assert.match(listenCss, /\.listen-hero\s*\{[^}]*height:\s*400px/s, 'hero frame height is fixed');
assert.doesNotMatch(indexCss, /data-theme="[^"]+"[^{}]*\.playback-dock\s*\{[^}]*\bmargin\s*:/s, 'themes must not move playback dock');
assert.doesNotMatch(indexCss, /data-theme="[^"]+"[^{}]*\.app-sidebar\s*\{[^}]*\bmargin\s*:/s, 'themes must not move sidebar');

console.log('PASS: AeroMusic theme frame contract');
