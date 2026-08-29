const assert = require('assert');
const path = require('path');
const { pathToFileURL } = require('url');

async function run() {
  const moduleUrl = pathToFileURL(path.join(__dirname, '..', 'src', 'utils', 'trackSorting.js')).href;
  const { sortTracksWithOriginalIndex } = await import(moduleUrl);
  const tracks = Array.from({ length: 20000 }, (_, index) => ({
    id: `track-${index}`,
    title: `歌曲 ${String(20000 - index).padStart(5, '0')}`,
    artist: index % 2 ? '乙' : '甲'
  }));

  const startedAt = performance.now();
  const sorted = sortTracksWithOriginalIndex(tracks, 'title', 'asc');
  const elapsedMs = performance.now() - startedAt;

  assert.equal(sorted.length, tracks.length);
  assert.equal(sorted[0].id, 'track-19999');
  assert.equal(sorted.at(-1).id, 'track-0');
  assert.ok(elapsedMs < 5000, `大型曲庫排序耗時過長：${elapsedMs.toFixed(1)}ms`);
  assert.deepEqual(
    sortTracksWithOriginalIndex(tracks.slice(0, 3), 'default', 'desc').map((track) => track.originalIndex),
    [2, 1, 0]
  );
  console.log(`PASS: CMV 20,000-track sorting (${elapsedMs.toFixed(1)}ms)`);
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
