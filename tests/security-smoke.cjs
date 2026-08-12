const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = path.join(__dirname, '..');
const mainText = fs.readFileSync(path.join(root, 'main.cjs'), 'utf8');
const audioContextText = fs.readFileSync(path.join(root, 'src', 'context', 'AudioContext.jsx'), 'utf8');
const localLibraryText = fs.readFileSync(path.join(root, 'src', 'components', 'LocalLibrary.jsx'), 'utf8');
const indexText = fs.readFileSync(path.join(root, 'index.html'), 'utf8');

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
assert.match(mainText, /sandbox:\s*true/);
assert.doesNotMatch(mainText, /shell\.openExternal/);
assert.doesNotMatch(audioContextText, /(?:audio|audioRef\.current)\.src = track\.url/);
assert.match(audioContextText, /audio\.src = resolveMediaUrl\(track\.url\)/);
assert.match(localLibraryText, /useMemo\([\s\S]*sortTracksWithOriginalIndex\(view\.viewTracks, sortKey, sortDirection\)/);
assert.doesNotMatch(indexText, /fonts\.googleapis\.com|fonts\.gstatic\.com/);
assert.doesNotMatch(indexText, /img-src[^;]*https:/);

console.log('PASS: AeroMusic main process hardening checks look correct');
