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
  const audioContext = require('node:fs').readFileSync(path.join(__dirname, '..', 'src', 'context', 'AudioContext.jsx'), 'utf8');
  const listenCss = require('node:fs').readFileSync(path.join(__dirname, '..', 'src', 'components', 'ListenNow.css'), 'utf8');
  assert.match(css, /--on-primary:\s*#ffdb3b/, 'yellow theme needs a readable foreground on its dark accent');
  assert.match(css, /--primary-button-ink:\s*#171307/, 'yellow gradient buttons need a dark readable foreground');
  assert.equal((css.match(/--theme-texture:/g) || []).length, 4, 'every theme needs its own material texture');
  assert.equal((css.match(/--theme-sweep:/g) || []).length, 4, 'every theme needs its own light sweep');
  assert.match(listenCss, /\.track-play-icon[^}]*color:\s*var\(--listen-accent-ink\)/s, 'track controls must use theme-aware accent foreground');
  assert.match(listenCss, /animation:\s*themeLightSweep/, 'the listening hero needs a premium light sweep');
  assert.match(listenCss, /prefers-reduced-motion:[^)]+\)[\s\S]*animation:\s*none\s*!important/, 'light sweep must respect reduced-motion preferences');
  assert.match(listenCss, /data-theme="sakura-night"[^}]*\.tracks-grid[^}]*repeat\(2/s, 'light theme must collapse to two columns at the mobile breakpoint');
  assert.match(css, /@media \(prefers-contrast: more\)[\s\S]*:root\[data-theme="neon-city"\][\s\S]*--text-secondary:/, 'high contrast must override the neon theme tokens');
  assert.match(css, /@media \(prefers-contrast: more\)[\s\S]*:root\[data-theme="vinyl-club"\][\s\S]*--text-secondary:/, 'high contrast must override the vinyl theme tokens');
  assert.match(css, /@media \(prefers-contrast: more\)[\s\S]*:root\[data-theme="sakura-night"\][\s\S]*--text-secondary:\s*#3f3006/s, 'high contrast sakura text must remain dark');
  assert.match(audioContext, /const latestPlaybackRef = useRef\(/, 'playback persistence must keep a latest-value ref');
  assert.match(audioContext, /\}, \[favorites, library, playlists, trackRatings\]\);/, 'saveAllData must only depend on collection data');
  assert.match(audioContext, /setInterval\(\(\) => \{\s*saveAllData\(\);\s*\}, 10000\);[\s\S]*\}, \[isPlaying, saveAllData\]\);/, 'playback autosave must retain a stable interval contract');

  console.log(`PASS: CMV theme registry (${ids.length} themes)`);
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
