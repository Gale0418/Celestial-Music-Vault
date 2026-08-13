const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const themeModule = await import(pathToFileURL(path.join(__dirname, '..', 'src', 'theme.js')));
  const ids = themeModule.THEME_OPTIONS.map((theme) => theme.id);

  assert.equal(new Set(ids).size, ids.length, 'theme IDs must be unique');
  assert.ok(ids.includes(themeModule.DEFAULT_THEME), 'default theme must be registered');
  assert.equal(themeModule.normalizeThemeId('neon-city'), 'neon-city');
  assert.equal(themeModule.normalizeThemeId('unknown-theme'), themeModule.DEFAULT_THEME);
  assert.ok(themeModule.THEME_OPTIONS.every((theme) => theme.swatches.length === 2));
  assert.ok(themeModule.THEME_OPTIONS.every((theme) => theme.ambient.length === 2));

  const css = require('node:fs').readFileSync(path.join(__dirname, '..', 'src', 'index.css'), 'utf8');
  const listenCss = require('node:fs').readFileSync(path.join(__dirname, '..', 'src', 'components', 'ListenNow.css'), 'utf8');
  assert.match(css, /--on-primary:\s*#ffffff/, 'light theme needs a readable foreground on its dark accent');
  assert.match(listenCss, /\.track-play-icon[^}]*color:\s*var\(--listen-accent-ink\)/s, 'track controls must use theme-aware accent foreground');
  assert.match(listenCss, /data-theme="sakura-night"[^}]*\.tracks-grid[^}]*repeat\(2/s, 'light theme must collapse to two columns at the mobile breakpoint');

  console.log(`PASS: AeroMusic theme registry (${ids.length} themes)`);
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
