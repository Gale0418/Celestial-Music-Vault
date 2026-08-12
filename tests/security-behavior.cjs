const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const vm = require('vm');

const mainText = fs.readFileSync(path.join(__dirname, '..', 'main.cjs'), 'utf8');
const helperEnd = mainText.indexOf('// IPC: Native multi-folder selection dialog');
const filterStart = mainText.indexOf('function isApprovedExistingTrack');
const filterEnd = mainText.indexOf('// IPC: User Data Persistence');
const helperText = mainText.slice(0, helperEnd) + mainText.slice(filterStart, filterEnd);
const registryUserData = path.join(os.tmpdir(), `aeromusic-registry-${process.pid}`);
const sandboxRequire = (id) => id === 'electron'
  ? {
      app: { getPath: () => registryUserData },
      protocol: { registerSchemesAsPrivileged: () => {} },
      net: { fetch: () => Promise.resolve(new Response('fixture')) }
    }
  : require(id);
const sandbox = { require: sandboxRequire, console, process, URL, module: { exports: {} }, exports: {}, __dirname: path.join(__dirname, '..') };
vm.runInNewContext(`${helperText}\nmodule.exports = { approvedScanRoots, rememberApprovedRoots, loadApprovedRootsRegistry, persistApprovedRootsRegistry, ensureApprovedDirectory, ensureApprovedFile, filterPersistedUserData, scanAudioFiles, toMediaUrl, ensureApprovedRemoteMediaUrl, resolveBundleFile };`, sandbox, { filename: 'main.cjs' });
const { approvedScanRoots, rememberApprovedRoots, loadApprovedRootsRegistry, persistApprovedRootsRegistry, ensureApprovedDirectory, ensureApprovedFile, filterPersistedUserData, scanAudioFiles, toMediaUrl, ensureApprovedRemoteMediaUrl, resolveBundleFile } = sandbox.module.exports;

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'aeromusic-security-'));
const approvedRoot = path.join(tempRoot, 'approved');
const outsideRoot = path.join(tempRoot, 'outside');
fs.mkdirSync(approvedRoot);
fs.mkdirSync(outsideRoot);
const song = path.join(approvedRoot, 'song.mp3');
const outsideSong = path.join(outsideRoot, 'outside.mp3');
fs.writeFileSync(song, 'fixture');
fs.writeFileSync(outsideSong, 'fixture');
rememberApprovedRoots([approvedRoot]);
assert.equal(ensureApprovedDirectory(approvedRoot), fs.realpathSync(approvedRoot));
assert.equal(ensureApprovedFile(song), fs.realpathSync(song));
assert.equal(toMediaUrl(song), `aeromusic://app/media/${encodeURIComponent(song)}`);
assert.equal(ensureApprovedRemoteMediaUrl('https://www.soundhelix.com/examples/mp3/song.mp3'), 'https://www.soundhelix.com/examples/mp3/song.mp3');
assert.throws(() => ensureApprovedRemoteMediaUrl('http://www.soundhelix.com/song.mp3'));
assert.throws(() => ensureApprovedRemoteMediaUrl('https://example.com/song.mp3'));
assert.equal(resolveBundleFile('/index.html'), path.join(__dirname, '..', 'dist', 'index.html'));
assert.throws(() => resolveBundleFile('/../main.cjs'));
assert.throws(() => ensureApprovedFile(path.join(approvedRoot, '..', 'outside', 'outside.mp3')));
assert.deepEqual(filterPersistedUserData({ library: [{ path: outsideSong }], favorites: [{ path: song }] }).library, []);
const filteredFavorite = filterPersistedUserData({ favorites: [{ path: song, url: 'file:///unsafe' }] }).favorites[0];
assert.equal(filteredFavorite.url, toMediaUrl(song));
fs.unlinkSync(song);
assert.throws(() => ensureApprovedFile(song));
return scanAudioFiles(path.join(approvedRoot, 'does-not-exist')).then(async (files) => {
  assert.deepEqual(files, []);
  try {
    const link = path.join(approvedRoot, 'outside-link.mp3');
    fs.symlinkSync(outsideSong, link, 'file');
    assert.throws(() => ensureApprovedFile(link));
  } catch (error) {
    if (error.code !== 'EPERM' && error.code !== 'EACCES') throw error;
  }
  fs.mkdirSync(registryUserData, { recursive: true });
  await persistApprovedRootsRegistry();
  approvedScanRoots.clear();
  loadApprovedRootsRegistry();
  assert.equal(ensureApprovedDirectory(approvedRoot), fs.realpathSync(approvedRoot));

  fs.writeFileSync(
    path.join(registryUserData, 'user-data.json'),
    JSON.stringify({ library: [{ path: outsideSong }] }),
    'utf8'
  );
  approvedScanRoots.clear();
  loadApprovedRootsRegistry();
  assert.throws(() => ensureApprovedFile(outsideSong));

  fs.rmSync(approvedRoot, { recursive: true, force: true });
  approvedScanRoots.clear();
  loadApprovedRootsRegistry();
  assert.equal(approvedScanRoots.size, 0);

  fs.rmSync(tempRoot, { recursive: true, force: true });
  fs.rmSync(registryUserData, { recursive: true, force: true });
  approvedScanRoots.clear();
  console.log('PASS: AeroMusic temporary-directory security behavior');
});
