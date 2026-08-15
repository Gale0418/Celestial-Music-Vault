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
  assert.deepEqual(
    themeModule.THEME_OPTIONS.map((theme) => theme.name),
    ['緋紅漆藝', '曜黑鈦界', '翠綠王庭', '鎏黃琥珀'],
    'the four stable theme IDs must map to the red, black, green, and yellow worlds',
  );
  assert.deepEqual(
    themeModule.THEME_OPTIONS.map((theme) => theme.swatches[1]),
    ['#ff2f3f', '#f4f1ea', '#2bea91', '#171307'],
    'theme selector swatches must expose each world’s action color',
  );

  const css = require('node:fs').readFileSync(path.join(__dirname, '..', 'src', 'index.css'), 'utf8');
  const listenCss = require('node:fs').readFileSync(path.join(__dirname, '..', 'src', 'components', 'ListenNow.css'), 'utf8');
  assert.match(css, /--on-primary:\s*#ffdb3b/, 'yellow theme needs a readable foreground on its dark accent');
  assert.match(listenCss, /\.track-play-icon[^}]*color:\s*var\(--listen-accent-ink\)/s, 'track controls must use theme-aware accent foreground');
  assert.match(listenCss, /data-theme="sakura-night"[^}]*\.tracks-grid[^}]*repeat\(2/s, 'light theme must collapse to two columns at the mobile breakpoint');

  console.log(`PASS: AeroMusic theme registry (${ids.length} themes)`);
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
