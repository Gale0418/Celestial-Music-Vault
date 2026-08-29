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

const AUDIO_EXTENSIONS = new Set(['.mp3', '.wav', '.ogg', '.m4a', '.mp4', '.flac', '.aac', '.wma', '.opus', '.aiff']);
const MEDIA_CONTENT_TYPES = new Map([
  ['.aac', 'audio/aac'],
  ['.aiff', 'audio/aiff'],
  ['.flac', 'audio/flac'],
  ['.m4a', 'audio/mp4'],
  ['.mp3', 'audio/mpeg'],
  ['.mp4', 'audio/mp4'],
  ['.ogg', 'audio/ogg'],
  ['.opus', 'audio/ogg'],
  ['.wav', 'audio/wav'],
  ['.wma', 'audio/x-ms-wma']
]);
const REMOTE_MEDIA_HOSTS = new Set(['www.soundhelix.com']);
const APP_SCHEME = 'cmv';
const approvedScanRoots = new Set();
const APPROVED_ROOTS_REGISTRY = 'approved-roots.json';

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
  if (remoteUrl.protocol !== 'https:' || !REMOTE_MEDIA_HOSTS.has(remoteUrl.hostname)) {
    throw new Error('Remote media host is not approved');
  }
  return remoteUrl.toString();
}

function resolveExistingPath(targetPath) {
  return fs.realpathSync.native ? fs.realpathSync.native(targetPath) : fs.realpathSync(targetPath);
}

function rememberApprovedRoots(paths) {
  for (const rawPath of paths || []) {
    if (!rawPath) continue;
    try {
      const resolved = resolveExistingPath(rawPath);
      const stat = fs.statSync(resolved);
      approvedScanRoots.add(stat.isDirectory() ? resolved : path.dirname(resolved));
    } catch (e) {
      console.warn('Skipping unapproved root candidate:', rawPath, e.message);
    }
  }
}

function isPathWithinApprovedRoots(targetPath) {
  try {
    const resolved = resolveExistingPath(targetPath);
    for (const root of approvedScanRoots) {
      const relative = path.relative(root, resolved);
      // path.relative handles separators and prevents prefix/path-traversal tricks.
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
    throw new Error('Approved trash target must be a file');
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
    const requestUrl = new URL(request.url);
    if (requestUrl.host !== 'app') {
      return new Response('Not found', { status: 404 });
    }

    if (requestUrl.pathname.startsWith('/media/')) {
      const encodedPath = requestUrl.pathname.slice('/media/'.length);
      if (!encodedPath) return new Response('Missing media path', { status: 400 });
      const approvedPath = ensureApprovedFile(decodeURIComponent(encodedPath));
      const rangeHeaders = getForwardedRangeHeaders(request.headers);
      return createLocalMediaResponse(approvedPath, rangeHeaders?.Range, request.method);
    }

    if (requestUrl.pathname.startsWith('/remote/')) {
      const encodedUrl = requestUrl.pathname.slice('/remote/'.length);
      if (!encodedUrl) return new Response('Missing remote URL', { status: 400 });
      const approvedUrl = ensureApprovedRemoteMediaUrl(decodeURIComponent(encodedUrl));
      const rangeHeaders = getForwardedRangeHeaders(request.headers);
      return net.fetch(approvedUrl, rangeHeaders ? { headers: rangeHeaders } : undefined);
    }

    const bundlePath = resolveBundleFile(requestUrl.pathname);
    return net.fetch(pathToFileURL(bundlePath).toString());
  } catch (error) {
    console.warn('Blocked CMV protocol request:', error.message);
    return new Response('Not found', { status: 404 });
  }
}

// Iterative scanner keeps large libraries responsive and avoids recursive Promise storms
async function scanAudioFiles(dirPath) {
  const results = [];
  const pending = [dirPath];

  while (pending.length > 0) {
    const currentDir = pending.pop();
    try {
      const entries = await fs.promises.readdir(currentDir, { withFileTypes: true });
      for (const entry of entries) {
        if (entry.name.startsWith('.') || entry.name === 'node_modules' || entry.name === '__MACOSX') continue;
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

// IPC: Native multi-folder selection dialog (supports selecting multiple folders at once!)
ipcMain.handle('select-folders', async (event) => {
  assertTrustedIpcSender(event);
  const result = await dialog.showOpenDialog({
    properties: ['openDirectory', 'multiSelections'],
    title: '選擇音樂資料夾'
  });
  if (result.canceled) return [];
  rememberApprovedRoots(result.filePaths);
  await persistApprovedRootsRegistry();
  return result.filePaths;
});

// IPC: Fast Node.js folder scanner
ipcMain.handle('scan-folder-for-audio', async (event, folderPath) => {
  assertTrustedIpcSender(event);
  const approvedPath = ensureApprovedDirectory(folderPath);
  return scanAudioFiles(approvedPath);
});

// IPC: Check if a path is a directory
ipcMain.handle('is-directory', async (event, filePath) => {
  assertTrustedIpcSender(event);
  try {
    const stat = await fs.promises.stat(filePath);
    return stat.isDirectory();
  } catch {
    return false;
  }
});

// IPC listener to open Finder/File Manager highlighting the specific file path
ipcMain.on('show-item-in-folder', (event, filePath) => {
  assertTrustedIpcSender(event);
  if (!filePath) return;
  try {
    shell.showItemInFolder(ensureApprovedFile(filePath));
  } catch (e) {
    console.warn('Refusing to reveal unapproved item:', e.message);
  }
});

// IPC: Move item to trash
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

// IPC: Show Native Message Box
ipcMain.handle('show-message-box', async (event, options) => {
  assertTrustedIpcSender(event);
  const result = await dialog.showMessageBox(options);
  return result;
});

function getApprovedRootsRegistryPath() {
  return path.join(app.getPath('userData'), APPROVED_ROOTS_REGISTRY);
}

function loadApprovedRootsRegistry() {
  approvedScanRoots.clear();
  try {
    const parsed = JSON.parse(fs.readFileSync(getApprovedRootsRegistryPath(), 'utf8'));
    const roots = Array.isArray(parsed?.roots) ? parsed.roots : [];
    for (const rawPath of roots) {
      if (typeof rawPath !== 'string' || !path.isAbsolute(rawPath)) continue;
      try {
        const resolved = resolveExistingPath(rawPath);
        if (fs.statSync(resolved).isDirectory()) approvedScanRoots.add(resolved);
      } catch {
        // 保留曾由原生挑選器核准、但目前離線的 NAS 根目錄。
        // 實際掃描、播放或刪除時仍必須通過 realpath/stat 驗證。
        approvedScanRoots.add(path.resolve(rawPath));
      }
    }
  } catch (error) {
    if (error.code !== 'ENOENT') {
      console.warn('Ignoring invalid approved-roots registry:', error.message);
    }
  }
}

async function persistApprovedRootsRegistry() {
  const registryPath = getApprovedRootsRegistryPath();
  const tempPath = `${registryPath}.${process.pid}.${Date.now()}.tmp`;
  await fs.promises.mkdir(path.dirname(registryPath), { recursive: true });
  try {
    await fs.promises.writeFile(
      tempPath,
      JSON.stringify({ version: 1, roots: Array.from(approvedScanRoots) }, null, 2),
      'utf8'
    );
    try {
      await fs.promises.rename(tempPath, registryPath);
    } catch (error) {
      if (error.code !== 'EEXIST' && error.code !== 'EPERM') throw error;
      await fs.promises.rm(registryPath, { force: true });
      await fs.promises.rename(tempPath, registryPath);
    }
  } finally {
    await fs.promises.rm(tempPath, { force: true }).catch(() => {});
  }
}

function filterPersistedUserData(data) {
  // 持久化資料只驗證既有授權邊界，不以 NAS 當下是否連線作為刪除依據。
  // 真正讀取或刪除檔案時仍會經過 realpath/stat 的嚴格檢查。
  return filterPersistedUserDataForRoots(data, approvedScanRoots, toMediaUrl);
}
// IPC: User Data Persistence (Favorites, Playlists, Library, Playback States)
const getUserDataPath = () => path.join(app.getPath('userData'), 'user-data.json');
const enqueueUserDataWrite = createSerialWriter(atomicWriteUserDataFile);

ipcMain.handle('load-user-data', async (event) => {
  assertTrustedIpcSender(event);
  try {
    const data = await loadUserDataFile(getUserDataPath());
    return data ? filterPersistedUserData(data) : null;
  } catch (e) {
    console.error('Failed to load user data:', e);
  }
  return null;
});

ipcMain.handle('save-user-data', async (event, data) => {
  assertTrustedIpcSender(event);
  try {
    const filtered = filterPersistedUserData(data);
    if (!filtered) return false;
    await enqueueUserDataWrite(getUserDataPath(), filtered);
    return true;
  } catch (e) {
    console.error('Failed to save user data:', e);
    return false;
  }
});

// Window Mode Toggles
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
  win.setFullScreen(isFullscreen);
});

function createWindow() {
  // Create a stunning premium macOS desktop window frame
  const win = new BrowserWindow({
    width: 1120,
    height: 760,
    minWidth: 960,
    minHeight: 680,
    titleBarStyle: 'hiddenInset', // Seamless macOS Red/Yellow/Green dot integration!
    backgroundColor: '#0d0e12',
    show: false, // show once ready to prevent white flicker
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      preload: path.join(__dirname, 'preload.cjs') // Safe context bridge
    }
  });

  // Block renderer-created windows and navigation outside the app origin.
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

  // Serve the app and approved local media from one secure custom origin.
  win.loadURL(`${APP_SCHEME}://app/index.html`);

  // Display seamlessly once content is parsed
  win.once('ready-to-show', () => {
    win.show();
  });
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

  // macOS standard: keep app running when all windows close unless quit
  app.whenReady().then(() => {
    loadApprovedRootsRegistry();
    protocol.handle(APP_SCHEME, handleAppProtocol);
    // Make sure IPC can receive crash logs and write them to a file
    ipcMain.on('crash-log', (event, errorInfo) => {
      if (!isTrustedIpcSender(event)) return;
      try {
        const fs = require('fs');
        const path = require('path');
        fs.appendFileSync(path.join(app.getPath('userData'), 'crash-log.txt'), new Date().toISOString() + '\n' + errorInfo + '\n\n');
      } catch (e) {
        console.error("Failed to write crash log", e);
      }
    });

    ipcMain.on('show-error-box', (event, title, content) => {
      if (!isTrustedIpcSender(event)) return;
      dialog.showErrorBox(title, content);
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
  AUDIO_EXTENSIONS, approvedScanRoots, rememberApprovedRoots, loadApprovedRootsRegistry, persistApprovedRootsRegistry, resolveExistingPath, isPathWithinApprovedRoots, ensureApprovedDirectory, ensureApprovedFile, scanAudioFiles, filterPersistedUserData
};
