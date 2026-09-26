const { app, BrowserWindow, ipcMain, shell, dialog, protocol, net } = require('electron');
const path = require('path');
const fs = require('fs');
const { pathToFileURL } = require('url');
const { Readable } = require('stream');
const {
  atomicWriteUserDataFile,
  createSerialWriter,
  filterPersistedUserData: filterPersistedUserDataForRoots,
  loadUserDataFile
} = require('./lib/user-data-store.cjs');

const AUDIO_EXTENSIONS = new Set([
  '.mp3', '.wav', '.ogg', '.m4a', '.mp4', '.flac', '.aac', '.wma', '.opus',
  '.aiff', '.aif', '.alac', '.mov', '.m4v'
]);
const MEDIA_CONTENT_TYPES = new Map([
  ['.aac', 'audio/aac'],
  ['.aif', 'audio/aiff'],
  ['.aiff', 'audio/aiff'],
  ['.alac', 'audio/mp4'],
  ['.flac', 'audio/flac'],
  ['.m4a', 'audio/mp4'],
  ['.mp3', 'audio/mpeg'],
  ['.mp4', 'video/mp4'],
  ['.m4v', 'video/x-m4v'],
  ['.mov', 'video/quicktime'],
  ['.ogg', 'audio/ogg'],
  ['.opus', 'audio/ogg'],
  ['.wav', 'audio/wav'],
  ['.wma', 'audio/x-ms-wma']
]);
const REMOTE_MEDIA_HOSTS = new Set(['www.soundhelix.com']);
const APP_SCHEME = 'cmv';
const approvedScanRoots = new Set();
const APPROVED_ROOTS_REGISTRY = 'approved-roots.json';
const APPROVED_ROOTS_VERSION = 1;
let approvedRootsRegistryState = 'uninitialized';
let persistenceWritesBlocked = false;

protocol.registerSchemesAsPrivileged([
  {
    scheme: APP_SCHEME,
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      stream: true
    }
  }
]);

function toMediaUrl(filePath) {
  return `${APP_SCHEME}://app/media/${encodeURIComponent(filePath)}`;
}

function ensureApprovedRemoteMediaUrl(rawUrl) {
  const remoteUrl = new URL(rawUrl);
  if (remoteUrl.protocol !== 'https:' ||
      !REMOTE_MEDIA_HOSTS.has(remoteUrl.hostname) ||
      (remoteUrl.port && remoteUrl.port !== '443')) {
    throw new Error('Remote media host is not approved');
  }
  return remoteUrl.toString();
}

function resolveExistingPath(targetPath) {
  return fs.realpathSync.native ? fs.realpathSync.native(targetPath) : fs.realpathSync(targetPath);
}

function registerApprovedPaths(paths) {
  const registered = [];
  for (const rawPath of paths || []) {
    if (typeof rawPath !== 'string' || !path.isAbsolute(rawPath)) continue;
    try {
      const resolved = resolveExistingPath(rawPath);
      const stat = fs.statSync(resolved);
      const isDirectory = stat.isDirectory();
      if (!isDirectory && !stat.isFile()) continue;
      approvedScanRoots.add(resolved);
      registered.push({ path: resolved, isDirectory });
    } catch (e) {
      console.warn('Skipping unapproved root candidate:', rawPath, e.message);
    }
  }
  return registered;
}

function rememberApprovedRoots(paths) {
  return registerApprovedPaths(paths).map(entry => entry.path);
}

function isPathWithinApprovedRoots(targetPath) {
  try {
    const resolved = resolveExistingPath(targetPath);
    for (const root of approvedScanRoots) {
      const relative = path.relative(root, resolved);
      if (relative === '' || (!relative.startsWith('..' + path.sep) && relative !== '..' && !path.isAbsolute(relative))) {
        return true;
      }
    }
  } catch {
    return false;
  }
  return false;
}

function ensureApprovedDirectory(dirPath) {
  const resolved = resolveExistingPath(dirPath);
  const stat = fs.statSync(resolved);
  if (!stat.isDirectory()) {
    throw new Error('Approved scan target must be a directory');
  }
  if (!isPathWithinApprovedRoots(resolved)) {
    throw new Error('Directory is outside approved music roots');
  }
  return resolved;
}

function ensureApprovedFile(filePath) {
  const resolved = resolveExistingPath(filePath);
  const stat = fs.statSync(resolved);
  if (!stat.isFile()) {
    throw new Error('Approved file target must be a file');
  }
  if (!isPathWithinApprovedRoots(resolved)) {
    throw new Error('File is outside approved music roots');
  }
  return resolved;
}

function resolveBundleFile(requestPath) {
  const distRoot = path.resolve(__dirname, 'dist');
  const decodedPath = decodeURIComponent(requestPath || '/index.html');
  const relativePath = decodedPath.replace(/^\/+/, '') || 'index.html';
  const resolved = path.resolve(distRoot, relativePath);
  const relative = path.relative(distRoot, resolved);
  if (relative === '..' || relative.startsWith(`..${path.sep}`) || path.isAbsolute(relative)) {
    throw new Error('Bundle path escapes the application root');
  }
  return resolved;
}

function getForwardedRangeHeaders(headers) {
  const range = typeof headers?.get === 'function' ? headers.get('range') : headers?.Range || headers?.range;
  return range ? { Range: range } : undefined;
}

function parseByteRange(rangeHeader, fileSize) {
  if (!rangeHeader) return null;
  const match = /^bytes=(\d*)-(\d*)$/.exec(rangeHeader.trim());
  if (!match || (!match[1] && !match[2])) return { invalid: true };

  let start;
  let end;
  if (!match[1]) {
    const suffixLength = Number(match[2]);
    if (!Number.isSafeInteger(suffixLength) || suffixLength <= 0 || fileSize === 0) return { invalid: true };
    start = Math.max(fileSize - suffixLength, 0);
    end = fileSize - 1;
  } else {
    start = Number(match[1]);
    end = match[2] ? Number(match[2]) : fileSize - 1;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start >= fileSize || start > end) {
      return { invalid: true };
    }
    end = Math.min(end, fileSize - 1);
  }
  return { start, end };
}

function getMediaContentType(filePath) {
  return MEDIA_CONTENT_TYPES.get(path.extname(filePath).toLowerCase()) || 'application/octet-stream';
}

async function createLocalMediaResponse(filePath, rangeHeader, method = 'GET') {
  const { size } = await fs.promises.stat(filePath);
  const contentType = getMediaContentType(filePath);
  const range = parseByteRange(rangeHeader, size);
  if (range?.invalid) {
    return new Response(null, {
      status: 416,
      headers: { 'Accept-Ranges': 'bytes', 'Content-Range': `bytes */${size}`, 'Content-Length': '0' }
    });
  }

  const start = range?.start ?? 0;
  const end = range?.end ?? Math.max(size - 1, 0);
  const headers = {
    'Accept-Ranges': 'bytes',
    'Content-Length': String(range ? end - start + 1 : size),
    'Content-Type': contentType
  };
  if (range) {
    headers['Content-Range'] = `bytes ${start}-${end}/${size}`;
  }
  if (String(method).toUpperCase() === 'HEAD') {
    return new Response(null, { status: range ? 206 : 200, headers });
  }
  const stream = Readable.toWeb(fs.createReadStream(filePath, range ? { start, end } : undefined));
  return new Response(stream, { status: range ? 206 : 200, headers });
}

async function handleAppProtocol(request) {
  try {
    const method = String(request.method || 'GET').toUpperCase();
    if (method !== 'GET' && method !== 'HEAD') {
      return new Response('Method not allowed', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }

    const requestUrl = new URL(request.url);
    if (requestUrl.host !== 'app') {
      return new Response('Not found', { status: 404 });
    }

    if (requestUrl.pathname.startsWith('/media/')) {
      const encodedPath = requestUrl.pathname.slice('/media/'.length);
      if (!encodedPath) return new Response('Missing media path', { status: 400 });
      const approvedPath = ensureApprovedFile(decodeURIComponent(encodedPath));
      const rangeHeaders = getForwardedRangeHeaders(request.headers);
      return createLocalMediaResponse(approvedPath, rangeHeaders?.Range, method);
    }

    if (requestUrl.pathname.startsWith('/remote/')) {
      const encodedUrl = requestUrl.pathname.slice('/remote/'.length);
      if (!encodedUrl) return new Response('Missing remote URL', { status: 400 });
      const approvedUrl = ensureApprovedRemoteMediaUrl(decodeURIComponent(encodedUrl));
      const rangeHeaders = getForwardedRangeHeaders(request.headers);
      return net.fetch(approvedUrl, {
        method,
        redirect: 'error',
        ...(rangeHeaders ? { headers: rangeHeaders } : {})
      });
    }

    const bundlePath = resolveBundleFile(requestUrl.pathname);
    return net.fetch(pathToFileURL(bundlePath).toString(), { method });
  } catch (error) {
    console.warn('Blocked CMV protocol request:', error.message);
    return new Response('Not found', { status: 404 });
  }
}

async function scanAudioFiles(dirPath) {
  const results = [];
  const pending = [dirPath];

  while (pending.length > 0) {
    const currentDir = pending.pop();
    try {
      const entries = await fs.promises.readdir(currentDir, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.name.startsWith('.') || entry.name === 'node_modules' || entry.name === '__MACOSX') continue;
        if (entry.isSymbolicLink()) continue;
        const fullPath = path.join(currentDir, entry.name);
        if (entry.isDirectory()) {
          pending.push(fullPath);
        } else {
          const ext = path.extname(entry.name).toLowerCase();
          if (AUDIO_EXTENSIONS.has(ext)) {
            results.push(fullPath);
          }
        }
      }
    } catch (e) {
      console.warn('Scan error (skipping):', currentDir, e.message);
    }
  }

  return results;
}

function isTrustedIpcSender(event) {
  try {
    const senderUrl = event?.senderFrame?.url || event?.sender?.getURL?.();
    const parsed = new URL(senderUrl);
    return parsed.protocol === `${APP_SCHEME}:` && parsed.host === 'app';
  } catch {
    return false;
  }
}

function assertTrustedIpcSender(event) {
  if (!isTrustedIpcSender(event)) {
    throw new Error('Blocked IPC request from an untrusted renderer');
  }
}

ipcMain.handle('select-folders', async (event) => {
  assertTrustedIpcSender(event);
  const result = await dialog.showOpenDialog({
    properties: ['openDirectory', 'multiSelections'],
    title: '選擇音樂資料夾'
  });
  if (result.canceled) return [];
  const registered = registerApprovedPaths(result.filePaths);
  if (registered.length > 0) await persistApprovedRootsRegistry();
  return registered.filter(entry => entry.isDirectory).map(entry => entry.path);
});

// The preload obtains these paths only from Electron's webUtils.getPathForFile
// for genuine user-selected File objects. Main still canonicalizes/stat-checks
// every value before expanding the persistent approved-root boundary.
ipcMain.handle('register-user-selected-paths', async (event, selectedPaths) => {
  assertTrustedIpcSender(event);
  if (!Array.isArray(selectedPaths)) throw new TypeError('selectedPaths must be an array');
  const registered = registerApprovedPaths(selectedPaths.slice(0, 100_000));
  if (registered.length > 0) await persistApprovedRootsRegistry();
  return registered;
});

ipcMain.handle('scan-folder-for-audio', async (event, folderPath) => {
  assertTrustedIpcSender(event);
  const approvedPath = ensureApprovedDirectory(folderPath);
  return scanAudioFiles(approvedPath);
});

ipcMain.on('show-item-in-folder', (event, filePath) => {
  assertTrustedIpcSender(event);
  if (!filePath) return;
  try {
    shell.showItemInFolder(ensureApprovedFile(filePath));
  } catch (e) {
    console.warn('Refusing to reveal unapproved item:', e.message);
  }
});

ipcMain.handle('trash-item', async (event, filePath) => {
  assertTrustedIpcSender(event);
  try {
    const approvedPath = ensureApprovedFile(filePath);
    await shell.trashItem(approvedPath);
    return true;
  } catch (e) {
    console.error('Failed to trash item', e);
    return false;
  }
});

ipcMain.handle('show-message-box', async (event, options) => {
  assertTrustedIpcSender(event);
  return dialog.showMessageBox(options);
});

function getApprovedRootsRegistryPath() {
  return path.join(app.getPath('userData'), APPROVED_ROOTS_REGISTRY);
}

function loadApprovedRootsRegistry() {
  approvedScanRoots.clear();
  try {
    const parsed = JSON.parse(fs.readFileSync(getApprovedRootsRegistryPath(), 'utf8'));
    if (parsed?.version !== APPROVED_ROOTS_VERSION || !Array.isArray(parsed?.roots)) {
      throw new Error('unsupported or malformed approved-roots registry');
    }
    for (const rawPath of parsed.roots) {
      if (typeof rawPath !== 'string' || !path.isAbsolute(rawPath)) continue;
      try {
        const resolved = resolveExistingPath(rawPath);
        const stat = fs.statSync(resolved);
        if (stat.isDirectory() || stat.isFile()) approvedScanRoots.add(resolved);
      } catch {
        // Preserve a previously approved NAS root while it is temporarily
        // offline. Actual read/trash requests still have to pass realpath/stat.
        approvedScanRoots.add(path.resolve(rawPath));
      }
    }
    approvedRootsRegistryState = 'trusted';
  } catch (error) {
    approvedRootsRegistryState = error.code === 'ENOENT' ? 'missing' : 'corrupt';
    if (error.code !== 'ENOENT') {
      console.warn('Approved-roots registry is unavailable:', error.message);
    }
  }
  return approvedRootsRegistryState;
}

async function persistApprovedRootsRegistry() {
  const registryPath = getApprovedRootsRegistryPath();
  const tempPath = `${registryPath}.${process.pid}.${Date.now()}.tmp`;
  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  try {
    await fs.promises.writeFile(
      tempPath,
      JSON.stringify({ version: APPROVED_ROOTS_VERSION, roots: Array.from(approvedScanRoots) }, null, 2),
      { encoding: 'utf8', flush: true }
    );
    // On the supported macOS target rename replaces the destination atomically.
    // Never delete a known-good registry first: a second rename failure would
    // otherwise turn a transient filesystem error into permanent data loss.
    await fs.promises.rename(tempPath, registryPath);
    approvedRootsRegistryState = 'trusted';
  } finally {
    await fs.promises.rm(tempPath, { force: true }).catch(() => {});
  }
}

function filterPersistedUserData(data) {
  return filterPersistedUserDataForRoots(data, approvedScanRoots, toMediaUrl);
}

function hasPersistedMedia(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return false;
  if (Array.isArray(data.library) && data.library.length > 0) return true;
  if (Array.isArray(data.favorites) && data.favorites.length > 0) return true;
  return Array.isArray(data.playlists) && data.playlists.some(
    playlist => playlist && typeof playlist === 'object' && Array.isArray(playlist.tracks) && playlist.tracks.length > 0
  );
}

function assertApprovedRootsReadyForPersistedMedia(data) {
  if (!hasPersistedMedia(data)) return;
  if (approvedRootsRegistryState === 'trusted' && approvedScanRoots.size > 0) return;
  persistenceWritesBlocked = true;
  const error = new Error(
    'CMV_APPROVED_ROOTS_UNAVAILABLE: 已儲存的音樂授權索引遺失或損壞；請重新選擇原音樂資料夾並重新啟動 CMV。為避免覆寫既有曲庫，本次工作階段已停用自動儲存。'
  );
  error.code = 'CMV_APPROVED_ROOTS_UNAVAILABLE';
  throw error;
}

const getUserDataPath = () => path.join(app.getPath('userData'), 'user-data.json');
const enqueueUserDataWrite = createSerialWriter(atomicWriteUserDataFile);

ipcMain.handle('load-user-data', async (event) => {
  assertTrustedIpcSender(event);
  const data = await loadUserDataFile(getUserDataPath());
  if (!data) return null;
  assertApprovedRootsReadyForPersistedMedia(data);
  return filterPersistedUserData(data);
});

ipcMain.handle('save-user-data', async (event, data) => {
  assertTrustedIpcSender(event);
  try {
    if (persistenceWritesBlocked) return false;
    if (hasPersistedMedia(data) && approvedRootsRegistryState !== 'trusted') return false;
    const filtered = filterPersistedUserData(data);
    if (!filtered) return false;
    await enqueueUserDataWrite(getUserDataPath(), filtered);
    return true;
  } catch (e) {
    console.error('Failed to save user data:', e);
    return false;
  }
});

ipcMain.on('toggle-mini-player', (event, isMini) => {
  if (!isTrustedIpcSender(event)) return;
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win) return;
  if (isMini) {
    win.setMinimumSize(350, 120);
    win.setSize(350, 120, true);
    win.setAlwaysOnTop(true, 'floating');
    win.setFullScreenable(false);
  } else {
    win.setMinimumSize(960, 680);
    win.setSize(1120, 760, true);
    win.setAlwaysOnTop(false);
    win.setFullScreenable(true);
  }
});

ipcMain.on('toggle-fullscreen', (event, isFullscreen) => {
  if (!isTrustedIpcSender(event)) return;
  const win = BrowserWindow.fromWebContents(event.sender);
  if (!win) return;
  win.setFullScreen(Boolean(isFullscreen));
});

function createWindow() {
  const win = new BrowserWindow({
    width: 1120,
    height: 760,
    minWidth: 960,
    minHeight: 680,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0d0e12',
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      preload: path.join(__dirname, 'preload.cjs')
    }
  });

  win.webContents.setWindowOpenHandler(({ url }) => {
    console.warn('Blocked request to open a new window:', url);
    return { action: 'deny' };
  });

  win.webContents.on('will-navigate', (event, navigationUrl) => {
    try {
      const parsed = new URL(navigationUrl);
      if (parsed.protocol === `${APP_SCHEME}:` && parsed.host === 'app') return;
    } catch {
      // Malformed URL is denied below.
    }
    event.preventDefault();
    console.warn('Blocked renderer navigation:', navigationUrl);
  });

  win.loadURL(`${APP_SCHEME}://app/index.html`);
  win.once('ready-to-show', () => win.show());
}

function focusPrimaryWindow() {
  const [win] = BrowserWindow.getAllWindows();
  if (!win) return;
  if (win.isMinimized()) win.restore();
  win.show();
  win.focus();
}

const hasSingleInstanceLock = app.requestSingleInstanceLock();
if (!hasSingleInstanceLock) {
  app.quit();
} else {
  app.on('second-instance', focusPrimaryWindow);

  app.whenReady().then(() => {
    loadApprovedRootsRegistry();
    protocol.handle(APP_SCHEME, handleAppProtocol);
    ipcMain.on('crash-log', (event, errorInfo) => {
      if (!isTrustedIpcSender(event)) return;
      const safeInfo = String(errorInfo ?? '').slice(0, 65_536);
      fs.promises.appendFile(
        path.join(app.getPath('userData'), 'crash-log.txt'),
        `${new Date().toISOString()}\n${safeInfo}\n\n`,
        'utf8'
      ).catch(error => console.error('Failed to write crash log', error));
    });

    ipcMain.on('show-error-box', (event, title, content) => {
      if (!isTrustedIpcSender(event)) return;
      dialog.showErrorBox(String(title ?? '').slice(0, 256), String(content ?? '').slice(0, 16_384));
    });

    createWindow();

    app.on('activate', () => {
      if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
      }
    });
  });
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

module.exports = {
  AUDIO_EXTENSIONS,
  approvedScanRoots,
  rememberApprovedRoots,
  registerApprovedPaths,
  loadApprovedRootsRegistry,
  persistApprovedRootsRegistry,
  resolveExistingPath,
  isPathWithinApprovedRoots,
  ensureApprovedDirectory,
  ensureApprovedFile,
  scanAudioFiles,
  filterPersistedUserData,
  hasPersistedMedia,
  assertApprovedRootsReadyForPersistedMedia,
  parseByteRange,
  getMediaContentType
};
