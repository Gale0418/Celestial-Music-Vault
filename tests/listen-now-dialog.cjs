const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const listenNow = fs.readFileSync(path.join(__dirname, '..', 'src', 'components', 'ListenNow.jsx'), 'utf8');

assert.match(listenNow, /savePlaylistButtonRef\s*=\s*useRef\(null\)/, 'save trigger must retain a ref');
assert.match(listenNow, /playlistNameInputRef\s*=\s*useRef\(null\)/, 'dialog input must retain a ref');
assert.match(listenNow, /isSaveDialogOpen[\s\S]*playlistNameInputRef\.current\?\.focus\(\)/, 'opening the dialog must focus its name input');
assert.match(listenNow, /savePlaylistButtonRef\.current\?\.focus\(\)/, 'closing the dialog must restore trigger focus');
assert.match(listenNow, /focusableSelector[\s\S]*activeElement[\s\S]*preventDefault\(\)/, 'dialog must trap Tab focus');
assert.match(listenNow, /event\.key === ['"]Escape['"][\s\S]*closeSaveDialog/, 'Escape must cancel the dialog');

console.log('PASS: ListenNow playlist dialog focus contract');
