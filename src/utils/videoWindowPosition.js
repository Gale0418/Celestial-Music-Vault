export const DEFAULT_VIDEO_WINDOW_SIZE = Object.freeze({ width: 380, height: 240 });

const clamp = (value, minimum, maximum) => Math.min(Math.max(value, minimum), maximum);

export const clampVideoPosition = (
  position,
  viewport,
  windowSize = DEFAULT_VIDEO_WINDOW_SIZE,
) => {
  const maxX = Math.max(0, viewport.width - windowSize.width);
  const maxY = Math.max(0, viewport.height - windowSize.height);

  return {
    x: clamp(Number.isFinite(position.x) ? position.x : 0, 0, maxX),
    y: clamp(Number.isFinite(position.y) ? position.y : 0, 0, maxY),
  };
};

// Coalesces a burst of pointer events into one visual update per paint frame.
export const createRafThrottledUpdater = (update, scheduleFrame, cancelFrame = () => {}) => {
  let frameId = null;
  let latestValue;

  const flush = () => {
    frameId = null;
    if (latestValue === undefined) return;
    const value = latestValue;
    latestValue = undefined;
    update(value);
  };

  const enqueue = (value) => {
    latestValue = value;
    if (frameId !== null) return;
    frameId = scheduleFrame(flush);
  };

  enqueue.cancel = () => {
    latestValue = undefined;
    if (frameId !== null) {
      cancelFrame(frameId);
    }
    frameId = null;
  };

  return enqueue;
};
