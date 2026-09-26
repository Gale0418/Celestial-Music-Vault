const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const vm = require('vm');

const mainText = fs.readFileSync(path.join(__dirname, '..', 'main.cjs'), 'utf8');
const helperEnd = mainText.indexOf("ipcMain.handle('select-folders'");
const filterStart = mainText.indexOf('function getApprovedRootsRegistryPath');
const filterEnd = mainText.indexOf('const getUserDataPath');
const helperText = mainText.slice(0, helperEnd) + mainText.slice(filterStart, filterEnd);
const registryUserData = path.join(os.tmpdir(), `cmv-registry-${process.pid}`);
let capturedFetch;
const sandboxRequire = (id) => {
  if (id === 'electron') return {
      app: { getPath: () => registryUserData },
      protocol: { registerSchemesAsPrivileged: () => {} },
      net: { fetch: (...args) => {
        capturedFetch = args;
        return Promise.resolve(new Response('fixture'));
      } }
    };
  if (id === './lib/user-data-store.cjs') {
    return require(path.join(__dirname, '..', 'lib', 'user-data-store.cjs'));
  }
  return require(id);
};
const sandbox = { require: sandboxRequire, console, process, URL, Response, Headers, module: { exports: {} }, exports: {}, __dirname: path.join(__dirname, '..') };
vm.runInNewContext(`${helperText}\nmodule.exports = { approvedScanRoots, rememberApprovedRoots, loadApprovedRootsRegistry, persistApprovedRootsRegistry, ensureApprovedDirectory, ensureApprovedFile, filterPersistedUserData, scanAudioFiles, toMediaUrl, ensureApprovedRemoteMediaUrl, resolveBundleFile, handleAppProtocol };`, sandbox, { filename: 'main.cjs' });
const { approvedScanRoots, rememberApprovedRoots, loadApprovedRootsRegistry, persistApprovedRootsRegistry, ensureApprovedDirectory, ensureApprovedFile, filterPersistedUserData, scanAudioFiles, toMediaUrl, ensureApprovedRemoteMediaUrl, resolveBundleFile, handleAppProtocol } = sandbox.module.exports;

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'cmv-security-'));
const approvedRoot = path.join(tempRoot, 'approved');
const outsideRoot = path.join(tempRoot, 'outside');
fs.mkdirSync(approvedRoot);
fs.mkdirSync(outsideRoot);
const song = path.join(approvedRoot, 'song.mp3');
const outsideSong = path.join(outsideRoot, 'outside.mp3');
const siblingSong = path.join(approvedRoot, 'sibling.mp3');
const otherSong = path.join(approvedRoot, 'other.mp3');
fs.writeFileSync(song, 'fixture');
fs.writeFileSync(outsideSong, 'fixture');
fs.writeFileSync(siblingSong, 'fixture');
fs.writeFileSync(otherSong, 'fixture');
const resolvedSong = fs.realpathSync(song);
const resolvedOutsideSong = fs.realpathSync(outsideSong);
rememberApprovedRoots([approvedRoot]);
assert.equal(ensureApprovedDirectory(approvedRoot), fs.realpathSync(approvedRoot));
assert.equal(ensureApprovedFile(song), fs.realpathSync(song));
assert.equal(toMediaUrl(song), `cmv://app/media/${encodeURIComponent(song)}`);
assert.equal(ensureApprovedRemoteMediaUrl('https://www.soundhelix.com/examples/mp3/song.mp3'), 'https://www.soundhelix.com/examples/mp3/song.mp3');
assert.throws(() => ensureApprovedRemoteMediaUrl('http://www.soundhelix.com/song.mp3'));
assert.throws(() => ensureApprovedRemoteMediaUrl('https://example.com/song.mp3'));
assert.equal(resolveBundleFile('/index.html'), path.join(__dirname, '..', 'dist', 'index.html'));
assert.throws(() => resolveBundleFile('/../main.cjs'));
assert.throws(() => ensureApprovedFile(path.join(approvedRoot, '..', 'outside', 'outside.mp3')));
assert.deepEqual(filterPersistedUserData({ library: [{ path: resolvedOutsideSong }], favorites: [{ path: resolvedSong }] }).library, []);
const filteredFavorite = filterPersistedUserData({ favorites: [{ path: resolvedSong, url: 'file:///unsafe' }] }).favorites[0];
assert.equal(filteredFavorite.url, toMediaUrl(resolvedSong));
fs.unlinkSync(song);
assert.throws(() => ensureApprovedFile(song));
return scanAudioFiles(path.join(approvedRoot, 'does-not-exist')).then(async (files) => {
  assert.deepEqual(files, []);

  approvedScanRoots.clear();
  rememberApprovedRoots([siblingSong]);
  assert.deepEqual([...approvedScanRoots], [fs.realpathSync(siblingSong)]);
  assert.equal(ensureApprovedFile(siblingSong), fs.realpathSync(siblingSong));
  assert.throws(() => ensureApprovedFile(otherSong));
  assert.throws(() => ensureApprovedDirectory(approvedRoot));
  await persistApprovedRootsRegistry();
  approvedScanRoots.clear();
  loadApprovedRootsRegistry();
  assert.equal(ensureApprovedFile(siblingSong), fs.realpathSync(siblingSong));
  assert.throws(() => ensureApprovedFile(otherSong));

  approvedScanRoots.clear();
  rememberApprovedRoots([approvedRoot]);
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

  const mediaResponse = await handleAppProtocol({
    url: `cmv://app/media/${encodeURIComponent(outsideSong)}`,
    headers: new Headers({ Range: 'bytes=1-3' })
  });
  assert.equal(mediaResponse.status, 404, 'unapproved media must remain blocked');

  rememberApprovedRoots([approvedRoot]);
  fs.writeFileSync(song, '0123456789');
  const rangedResponse = await handleAppProtocol({
    url: `cmv://app/media/${encodeURIComponent(song)}`,
    headers: new Headers({ Range: 'bytes=2-5', Authorization: 'Bearer should-not-forward' })
  });
  assert.equal(rangedResponse.status, 206);
  assert.equal(rangedResponse.headers.get('content-range'), 'bytes 2-5/10');
  assert.equal(rangedResponse.headers.get('content-length'), '4');
  assert.equal(await rangedResponse.text(), '2345');

  const headResponse = await handleAppProtocol({
    method: 'HEAD',
    url: `cmv://app/media/${encodeURIComponent(song)}`,
    headers: new Headers()
  });
  assert.equal(headResponse.status, 200);
  assert.equal(headResponse.headers.get('content-length'), '10');
  assert.equal(headResponse.body, null, 'HEAD full response must not read or expose a body');

  const headRangeResponse = await handleAppProtocol({
    method: 'HEAD',
    url: `cmv://app/media/${encodeURIComponent(song)}`,
    headers: new Headers({ Range: 'bytes=2-5' })
  });
  assert.equal(headRangeResponse.status, 206);
  assert.equal(headRangeResponse.headers.get('content-range'), 'bytes 2-5/10');
  assert.equal(headRangeResponse.headers.get('content-length'), '4');
  assert.equal(headRangeResponse.body, null, 'HEAD range response must not read or expose a body');

  const invalidRangeResponse = await handleAppProtocol({
    url: `cmv://app/media/${encodeURIComponent(song)}`,
    headers: new Headers({ Range: 'bytes=99-100' })
  });
  assert.equal(invalidRangeResponse.status, 416);
  assert.equal(invalidRangeResponse.headers.get('content-range'), 'bytes */10');

  const headInvalidRangeResponse = await handleAppProtocol({
    method: 'HEAD',
    url: `cmv://app/media/${encodeURIComponent(song)}`,
    headers: new Headers({ Range: 'bytes=99-100' })
  });
  assert.equal(headInvalidRangeResponse.status, 416);
  assert.equal(headInvalidRangeResponse.headers.get('content-range'), 'bytes */10');
  assert.equal(headInvalidRangeResponse.body, null, 'HEAD invalid range response must not expose a body');

  await handleAppProtocol({
    url: 'cmv://app/remote/https%3A%2F%2Fwww.soundhelix.com%2Fexamples%2Fmp3%2Fsong.mp3',
    headers: new Headers({ Range: 'bytes=0-10', Authorization: 'Bearer should-not-forward' })
  });
  assert.equal(capturedFetch[1].headers.Range, 'bytes=0-10');
  assert.equal(capturedFetch[1].headers.Authorization, undefined);

  fs.rmSync(approvedRoot, { recursive: true, force: true });
  approvedScanRoots.clear();
  loadApprovedRootsRegistry();
  assert.equal(approvedScanRoots.size, 1);
  assert.throws(() => ensureApprovedDirectory(approvedRoot));

  fs.rmSync(tempRoot, { recursive: true, force: true });
  fs.rmSync(registryUserData, { recursive: true, force: true });
  approvedScanRoots.clear();
  console.log('PASS: CMV temporary-directory security behavior');
});
