const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = path.join(__dirname, '..');
const mainText = fs.readFileSync(path.join(root, 'main.cjs'), 'utf8');
const audioContextText = fs.readFileSync(path.join(root, 'src', 'context', 'AudioContext.jsx'), 'utf8');
const localLibraryText = fs.readFileSync(path.join(root, 'src', 'components', 'LocalLibrary.jsx'), 'utf8');
const indexText = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
const buildScriptText = fs.readFileSync(path.join(root, 'scripts', 'build-macos.sh'), 'utf8');
const entitlementsText = fs.readFileSync(path.join(root, 'build', 'entitlements.mac.plist'), 'utf8');
const packagingDocsText = fs.readFileSync(path.join(root, 'docs', 'PACKAGING_AND_OPTIMIZATION.md'), 'utf8');

assert.match(mainText, /function isPathWithinApprovedRoots/);
assert.match(mainText, /ipcMain\.handle\('scan-folder-for-audio',[\s\S]*ensureApprovedDirectory/);
assert.match(mainText, /ipcMain\.handle\('trash-item',[\s\S]*ensureApprovedFile/);
assert.doesNotMatch(mainText, /await Promise\.all\(promises\)/);
assert.doesNotMatch(mainText, /await shell\.trashItem\(filePath\)/);
assert.doesNotMatch(mainText, /webSecurity:\s*false/);
assert.match(mainText, /protocol\.handle\(APP_SCHEME, handleAppProtocol\)/);
assert.match(mainText, /win\.loadURL\(`\$\{APP_SCHEME\}:\/\/app\/index\.html`\)/);
assert.match(mainText, /REMOTE_MEDIA_HOSTS = new Set\(\['www\.soundhelix\.com'\]\)/);
assert.match(mainText, /remoteUrl\.protocol !== 'https:'/);
assert.match(mainText, /app\.requestSingleInstanceLock\(\)/);
assert.match(mainText, /win\.webContents\.on\('will-navigate'/);
assert.match(mainText, /function assertTrustedIpcSender/);
for (const channel of ['toggle-mini-player', 'toggle-fullscreen', 'crash-log', 'show-error-box']) {
  const listener = new RegExp(`ipcMain\\.(?:on|handle)\\(['"]${channel}['"][\\s\\S]*?if \\(!isTrustedIpcSender\\(event\\)\\) return;`);
  assert.match(mainText, listener, `${channel} must ignore untrusted senders without throwing`);
}
assert.doesNotMatch(mainText, /ipcMain\.on\(['"](?:toggle-mini-player|toggle-fullscreen|crash-log|show-error-box)['"][\s\S]*?assertTrustedIpcSender\(event\)/);
assert.match(mainText, /function getForwardedRangeHeaders/);
assert.match(mainText, /getForwardedRangeHeaders\(request\.headers\)/);
assert.match(mainText, /status: range \? 206 : 200/);
assert.match(mainText, /Content-Range/);
assert.match(mainText, /status: 416/);
assert.match(mainText, /String\(method\)\.toUpperCase\(\) === 'HEAD'/);
assert.match(mainText, /createLocalMediaResponse\(approvedPath, rangeHeaders\?\.Range, request\.method\)/);
assert.doesNotMatch(mainText, /net\.fetch\(approvedUrl, \{ headers: request\.headers \}\)/);
assert.match(mainText, /sandbox:\s*true/);
assert.doesNotMatch(mainText, /shell\.openExternal/);
assert.match(buildScriptText, /OUTPUT_DIR[\s\S]*危險|OUTPUT_DIR[\s\S]*danger/i);
assert.match(buildScriptText, /rm -rf -- "\$APP_OUTPUT_PATH"/);
assert.match(entitlementsText, /com\.apple\.security\.cs\.allow-jit/);
assert.match(entitlementsText, /com\.apple\.security\.cs\.allow-unsigned-executable-memory/);
assert.doesNotMatch(entitlementsText, /disable-library-validation/);
assert.match(packagingDocsText, /approved roots|核准根目錄/i);
assert.match(packagingDocsText, /allow-jit/);
assert.match(packagingDocsText, /allow-unsigned-executable-memory/);
assert.doesNotMatch(packagingDocsText, /files\.user-selected\.read-write/);
assert.doesNotMatch(audioContextText, /(?:audio|audioRef\.current)\.src = track\.url/);
assert.match(audioContextText, /audio\.src = resolveMediaUrl\(track\.url\)/);
assert.match(localLibraryText, /useMemo\([\s\S]*sortTracksWithOriginalIndex\(view\.viewTracks, sortKey, sortDirection\)/);
assert.doesNotMatch(indexText, /fonts\.googleapis\.com|fonts\.gstatic\.com/);
assert.doesNotMatch(indexText, /img-src[^;]*https:/);

console.log('PASS: CMV main process hardening checks look correct');
