const normalizedIndex = (tracks, index) => {
  if (!Array.isArray(tracks) || tracks.length === 0) return -1;
  return Number.isInteger(index)
    ? Math.min(tracks.length - 1, Math.max(0, index))
    : 0;
};

const dislikedSet = (ids) => ids instanceof Set ? ids : new Set(ids || []);

const isPlayable = (tracks, index, disliked) => {
  const track = tracks[index];
  return Boolean(track) && !disliked.has(track.id);
};

/**
 * Finds the next playable queue index without probabilistic retry loops.
 * Manual next wraps; natural completion only wraps when repeat-all is active.
 * Shuffle samples the exact eligible set and avoids replaying the current item
 * whenever another playable item exists.
 */
export const findNextPlayableIndex = ({
  tracks,
  currentIndex,
  dislikedIds = [],
  shuffle = false,
  repeat = false,
  autoEnded = false,
  random = Math.random
}) => {
  const current = normalizedIndex(tracks, currentIndex);
  if (current < 0) return null;
  const disliked = dislikedSet(dislikedIds);

  if (shuffle) {
    let candidates = tracks
      .map((_, index) => index)
      .filter(index => isPlayable(tracks, index, disliked));
    if (candidates.length > 1) {
      candidates = candidates.filter(index => index !== current);
    }
    if (candidates.length === 0) return null;
    const sample = Number(random());
    const bounded = Number.isFinite(sample)
      ? Math.min(0.9999999999999999, Math.max(0, sample))
      : 0;
    return candidates[Math.floor(bounded * candidates.length)];
  }

  const allowWrap = Boolean(repeat) || !autoEnded;
  for (let step = 1; step <= tracks.length; step += 1) {
    let candidate = current + step;
    if (candidate >= tracks.length) {
      if (!allowWrap) return null;
      candidate %= tracks.length;
    }
    if (isPlayable(tracks, candidate, disliked)) return candidate;
  }
  return null;
};

/** Finds the previous playable item, wrapping exactly once. */
export const findPreviousPlayableIndex = ({ tracks, currentIndex, dislikedIds = [] }) => {
  const current = normalizedIndex(tracks, currentIndex);
  if (current < 0) return null;
  const disliked = dislikedSet(dislikedIds);
  for (let step = 1; step <= tracks.length; step += 1) {
    const candidate = (current - step + tracks.length) % tracks.length;
    if (isPlayable(tracks, candidate, disliked)) return candidate;
  }
  return null;
};
