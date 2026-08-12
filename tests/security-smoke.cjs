const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = path.join(__dirname, '..');
const mainText = fs.readFileSync(path.join(root, 'main.cjs'), 'utf8');
const audioContextText = fs.readFileSync(path.join(root, 'src', 'context', 'AudioContext.jsx'), 'utf8');

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
assert.doesNotMatch(audioContextText, /(?:audio|audioRef\.current)\.src = track\.url/);
assert.match(audioContextText, /audio\.src = resolveMediaUrl\(track\.url\)/);

console.log('PASS: AeroMusic main process hardening checks look correct');
