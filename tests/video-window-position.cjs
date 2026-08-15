const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

(async () => {
  const module = await import(pathToFileURL(path.join(__dirname, '..', 'src', 'utils', 'videoWindowPosition.js')));

  assert.deepEqual(
    module.clampVideoPosition({ x: 600, y: -40 }, { width: 1120, height: 760 }),
    { x: 600, y: 0 },
    'the title bar must remain reachable when the window is dragged to the top edge',
  );
  assert.deepEqual(
    module.clampVideoPosition({ x: 9999, y: 9999 }, { width: 1120, height: 760 }),
    { x: 740, y: 520 },
    'the whole video window must remain within the current viewport',
  );
  assert.deepEqual(
    module.clampVideoPosition({ x: 50, y: 50 }, { width: 280, height: 180 }),
    { x: 0, y: 0 },
    'a viewport smaller than the window must still keep its title bar visible',
  );

  const frames = [];
  const updates = [];
  const enqueue = module.createRafThrottledUpdater(
    (position) => updates.push(position),
    (callback) => {
      frames.push(callback);
      return frames.length;
    },
  );
  enqueue({ x: 1, y: 1 });
  enqueue({ x: 2, y: 2 });
  assert.equal(updates.length, 0, 'drag events must wait for the next animation frame');
  assert.equal(frames.length, 1, 'a burst of drag events must schedule only one frame');
  frames[0]();
  assert.deepEqual(updates, [{ x: 2, y: 2 }], 'the frame must apply the latest drag position');

  const audioContextSource = fs.readFileSync(path.join(__dirname, '..', 'src', 'context', 'AudioContext.jsx'), 'utf8');
  const appSource = fs.readFileSync(path.join(__dirname, '..', 'src', 'App.jsx'), 'utf8');
  const floatingLayer = Number(audioContextSource.match(/zIndex:\s*(\d+),[\s\S]{0,180}WebkitAppRegion:\s*'no-drag'/)?.[1]);
  const titlebarLayer = Number(appSource.match(/WebkitAppRegion:\s*'drag',[\s\S]{0,80}zIndex:\s*(\d+)/)?.[1]);
  assert.ok(floatingLayer > titlebarLayer, 'the floating video handle must stay above the native titlebar drag region');
  assert.match(audioContextSource, /translate3d\(var\(--video-position-x\), var\(--video-position-y\), 0\)/, 'dragging must use a compositor transform instead of left/top updates');

  console.log('PASS: AeroMusic floating video position and drag throttling');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
