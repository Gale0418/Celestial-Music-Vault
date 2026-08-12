const fs = require('fs');
const path = require('path');

function isPathInsideRoot(rootPath, targetPath) {
  if (typeof rootPath !== 'string' || typeof targetPath !== 'string') return false;
  const root = path.resolve(rootPath);
  const target = path.resolve(targetPath);
  const relative = path.relative(root, target);
  return relative === '' || (
    relative !== '..' &&
    !relative.startsWith(`..${path.sep}`) &&
    !path.isAbsolute(relative)
  );
}

function isPersistedTrackAllowed(track, approvedRoots) {
  if (!track || typeof track !== 'object' || typeof track.path !== 'string' || !track.path) {
    return false;
  }
  return Array.from(approvedRoots || []).some((root) => isPathInsideRoot(root, track.path));
}

function filterPersistedTrackList(tracks, approvedRoots, toMediaUrl) {
  return Array.isArray(tracks)
    ? tracks.filter((track) => isPersistedTrackAllowed(track, approvedRoots)).map((track) => ({
      ...track,
      url: toMediaUrl(track.path)
    }))
    : [];
}

function filterPersistedUserData(data, approvedRoots, toMediaUrl) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return null;
  return {
    ...data,
    library: filterPersistedTrackList(data.library, approvedRoots, toMediaUrl),
    favorites: filterPersistedTrackList(data.favorites, approvedRoots, toMediaUrl),
    playlists: Array.isArray(data.playlists)
      ? data.playlists.filter((playlist) => playlist && typeof playlist === 'object').map((playlist) => ({
        ...playlist,
        tracks: filterPersistedTrackList(playlist.tracks, approvedRoots, toMediaUrl)
      }))
      : []
  };
}

async function readJsonFile(filePath) {
  const text = await fs.promises.readFile(filePath, 'utf8');
  return { value: JSON.parse(text), text };
}

async function loadUserDataFile(dataPath, logger = console) {
  try {
    return (await readJsonFile(dataPath)).value;
  } catch (primaryError) {
    if (primaryError.code === 'ENOENT') return null;
    logger.warn('主要使用者資料損壞，嘗試讀取備份：', primaryError.message);
    try {
      const recovered = (await readJsonFile(`${dataPath}.bak`)).value;
      logger.warn('已從上一份有效備份復原使用者資料。');
      return recovered;
    } catch (backupError) {
      logger.error('使用者資料與備份皆無法讀取：', backupError.message);
      return null;
    }
  }
}

async function writeFileDurably(filePath, content) {
  await fs.promises.writeFile(filePath, content, { encoding: 'utf8', flush: true });
}

async function atomicWriteUserDataFile(dataPath, data) {
  const directory = path.dirname(dataPath);
  const uniqueSuffix = `${process.pid}.${Date.now()}.${Math.random().toString(16).slice(2)}`;
  const tempPath = `${dataPath}.${uniqueSuffix}.tmp`;
  const backupPath = `${dataPath}.bak`;
  const backupTempPath = `${backupPath}.${uniqueSuffix}.tmp`;
  const serialized = JSON.stringify(data, null, 2);

  await fs.promises.mkdir(directory, { recursive: true });
  try {
    await writeFileDurably(tempPath, serialized);

    try {
      const current = await readJsonFile(dataPath);
      await writeFileDurably(backupTempPath, current.text);
      await fs.promises.rename(backupTempPath, backupPath);
    } catch (error) {
      // 第一次存檔或主檔已損壞時，不得覆寫最後一份有效備份。
      if (error.code !== 'ENOENT' && !(error instanceof SyntaxError)) throw error;
    }

    await fs.promises.rename(tempPath, dataPath);
  } finally {
    await fs.promises.rm(tempPath, { force: true }).catch(() => {});
    await fs.promises.rm(backupTempPath, { force: true }).catch(() => {});
  }
}

function createSerialWriter(writeOperation) {
  let queue = Promise.resolve();
  return (dataPath, data) => {
    const pending = queue.catch(() => {}).then(() => writeOperation(dataPath, data));
    queue = pending.catch(() => {});
    return pending;
  };
}

module.exports = {
  atomicWriteUserDataFile,
  createSerialWriter,
  filterPersistedUserData,
  isPathInsideRoot,
  isPersistedTrackAllowed,
  loadUserDataFile
};
