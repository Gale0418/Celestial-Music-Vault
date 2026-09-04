const assert = require('node:assert/strict');

(async () => {
  const {
    findNextPlayableIndex,
    findPreviousPlayableIndex
  } = await import('../src/utils/queueNavigation.js');

  const tracks = [{ id: 'a' }, { id: 'b' }, { id: 'c' }, { id: 'd' }];

  assert.equal(findNextPlayableIndex({
    tracks,
    currentIndex: 0,
    dislikedIds: new Set(['b', 'd']),
    shuffle: true,
    random: () => 0.999
  }), 2, 'shuffle must sample the exact eligible set instead of retrying random duplicates');

  assert.equal(findNextPlayableIndex({
    tracks,
    currentIndex: 2,
    dislikedIds: ['a', 'b', 'd'],
    shuffle: true,
    random: () => 0.5
  }), 2, 'the current item remains playable when every alternative is disliked');

  assert.equal(findNextPlayableIndex({
    tracks,
    currentIndex: 1,
    dislikedIds: tracks.map(track => track.id),
    shuffle: true
  }), null, 'all-disliked queues must terminate without an unbounded retry loop');

  assert.equal(findNextPlayableIndex({
    tracks,
    currentIndex: 3,
    autoEnded: true,
    repeat: false
  }), null, 'natural completion must stop at the end when repeat-all is disabled');

  assert.equal(findNextPlayableIndex({
    tracks,
    currentIndex: 3,
    autoEnded: false,
    repeat: false
  }), 0, 'manual next should wrap to the beginning');

  assert.equal(findNextPlayableIndex({
    tracks,
    currentIndex: 0,
    dislikedIds: ['b', 'c'],
    autoEnded: true,
    repeat: false
  }), 3, 'linear navigation must skip every disliked item ahead');

  assert.equal(findPreviousPlayableIndex({
    tracks,
    currentIndex: 0,
    dislikedIds: ['d', 'c']
  }), 1, 'previous navigation must wrap once and skip disliked items');

  assert.equal(findPreviousPlayableIndex({
    tracks,
    currentIndex: 0,
    dislikedIds: tracks.map(track => track.id)
  }), null, 'previous navigation must terminate when no playable item exists');

  console.log('queue navigation regression tests passed');
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
