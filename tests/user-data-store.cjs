const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const {
  atomicWriteUserDataFile,
  createSerialWriter,
  filterPersistedUserData,
  isPathInsideRoot,
  loadUserDataFile
} = require('../lib/user-data-store.cjs');

async function run() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cmv-user-data-'));
  const dataPath = path.join(root, 'user-data.json');
  const approvedRoot = path.join(root, 'offline-nas');
  const offlineTrack = path.join(approvedRoot, 'album', 'missing.mp3');
  const outsideTrack = path.join(root, 'outside.mp3');
  const toMediaUrl = (filePath) => `media:${filePath}`;

  try {
    assert.equal(isPathInsideRoot(approvedRoot, offlineTrack), true);
    assert.equal(isPathInsideRoot(approvedRoot, outsideTrack), false);

    const filtered = filterPersistedUserData({
      library: [{ id: 'offline', path: offlineTrack }, { id: 'outside', path: outsideTrack }],
      favorites: [{ id: 'offline', path: offlineTrack }],
      playlists: [{ id: 'p1', tracks: [{ id: 'offline', path: offlineTrack }] }],
      playbackState: { volume: 0.5 }
    }, new Set([approvedRoot]), toMediaUrl);
    assert.deepEqual(filtered.library.map((track) => track.id), ['offline']);
    assert.equal(filtered.library[0].url, toMediaUrl(offlineTrack));
    assert.equal(filtered.playbackState.volume, 0.5);

    await atomicWriteUserDataFile(dataPath, { revision: 1 });
    assert.deepEqual(JSON.parse(fs.readFileSync(dataPath, 'utf8')), { revision: 1 });
    assert.equal(fs.existsSync(`${dataPath}.bak`), false);

    await atomicWriteUserDataFile(dataPath, { revision: 2 });
    assert.deepEqual(JSON.parse(fs.readFileSync(dataPath, 'utf8')), { revision: 2 });
    assert.deepEqual(JSON.parse(fs.readFileSync(`${dataPath}.bak`, 'utf8')), { revision: 1 });

    fs.writeFileSync(dataPath, '{ broken', 'utf8');
    assert.deepEqual(await loadUserDataFile(dataPath, { warn: () => {}, error: () => {} }), { revision: 1 });

    fs.rmSync(dataPath, { force: true });
    assert.equal(await loadUserDataFile(dataPath, { warn: () => {}, error: () => {} }), null);

    const order = [];
    let shouldFail = true;
    const serialWrite = createSerialWriter(async (_target, value) => {
      order.push(`start-${value}`);
      await new Promise((resolve) => setTimeout(resolve, value === 1 ? 15 : 0));
      if (shouldFail && value === 2) {
        shouldFail = false;
        order.push(`fail-${value}`);
        throw new Error('故障注入');
      }
      order.push(`end-${value}`);
    });
    const results = await Promise.allSettled([
      serialWrite(dataPath, 1),
      serialWrite(dataPath, 2),
      serialWrite(dataPath, 3)
    ]);
    assert.deepEqual(results.map((result) => result.status), ['fulfilled', 'rejected', 'fulfilled']);
    assert.deepEqual(order, ['start-1', 'end-1', 'start-2', 'fail-2', 'start-3', 'end-3']);

    const leftovers = fs.readdirSync(root).filter((name) => name.endsWith('.tmp'));
    assert.deepEqual(leftovers, []);
    console.log('PASS: CMV user data persistence and recovery');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
