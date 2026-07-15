const fs = require('fs');
const path = require('path');
const assert = require('assert');

const root = 'D:/MyGame/music';
const mainText = fs.readFileSync(path.join(root, 'main.cjs'), 'utf8');

assert.match(mainText, /function isPathWithinApprovedRoots/);
assert.match(mainText, /ipcMain\.handle\('scan-folder-for-audio',[\s\S]*ensureApprovedDirectory/);
assert.match(mainText, /ipcMain\.handle\('trash-item',[\s\S]*ensureApprovedFile/);
assert.doesNotMatch(mainText, /await Promise\.all\(promises\)/);
assert.doesNotMatch(mainText, /await shell\.trashItem\(filePath\)/);

console.log('PASS: AeroMusic main process hardening checks look correct');
