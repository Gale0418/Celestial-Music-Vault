const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

const AUDIO_EXTENSIONS = new Set(['.mp3', '.wav', '.ogg', '.m4a', '.mp4', '.flac', '.aac', '.wma', '.opus', '.aiff']);
const approvedScanRoots = new Set();

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

function rememberApprovedRootsFromUserData(data) {
  const roots = [];
  const collections = [data?.library || [], data?.favorites || []];
  for (const playlist of data?.playlists || []) {
    collections.push(playlist?.tracks || []);
  }
  for (const tracks of collections) {
    for (const track of tracks) {
      if (track?.path) {
        roots.push(track.path);
      }
    }
  }
  rememberApprovedRoots(roots);
}

function isPathWithinApprovedRoots(targetPath) {
  try {
    const resolved = resolveExistingPath(targetPath);
    for (const root of approvedScanRoots) {
      if (resolved === root || resolved.startsWith(root + path.sep)) {
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

// IPC: Native multi-folder selection dialog (supports selecting multiple folders at once!)
ipcMain.handle('select-folders', async (event) => {
  const result = await dialog.showOpenDialog({
    properties: ['openDirectory', 'multiSelections'],
    title: '選擇音樂資料夾'
  });
  if (result.canceled) return [];
  rememberApprovedRoots(result.filePaths);
  return result.filePaths;
});

// IPC: Fast Node.js folder scanner
ipcMain.handle('scan-folder-for-audio', async (event, folderPath) => {
  const approvedPath = ensureApprovedDirectory(folderPath);
  return scanAudioFiles(approvedPath);
});

// IPC: Check if a path is a directory
ipcMain.handle('is-directory', async (event, filePath) => {
  try {
    const stat = await fs.promises.stat(filePath);
    return stat.isDirectory();
  } catch {
    return false;
  }
});

// IPC listener to open Finder/File Manager highlighting the specific file path
ipcMain.on('show-item-in-folder', (event, filePath) => {
  if (filePath) {
    shell.showItemInFolder(filePath);
  }
});

// IPC: Move item to trash
ipcMain.handle('trash-item', async (event, filePath) => {
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
  const result = await dialog.showMessageBox(options);
  return result;
});

// IPC: User Data Persistence (Favorites, Playlists, Library, Playback States)
const getUserDataPath = () => path.join(app.getPath('userData'), 'user-data.json');

ipcMain.handle('load-user-data', async () => {
  try {
    const dataPath = getUserDataPath();
    if (fs.existsSync(dataPath)) {
      const data = await fs.promises.readFile(dataPath, 'utf8');
      const parsed = JSON.parse(data);
      rememberApprovedRootsFromUserData(parsed);
      return parsed;
    }
  } catch (e) {
    console.error('Failed to load user data:', e);
  }
  return null;
});

ipcMain.handle('save-user-data', async (event, data) => {
  try {
    rememberApprovedRootsFromUserData(data);
    const dataPath = getUserDataPath();
    const dir = path.dirname(dataPath);
    if (!fs.existsSync(dir)) {
      await fs.promises.mkdir(dir, { recursive: true });
    }
    await fs.promises.writeFile(dataPath, JSON.stringify(data, null, 2), 'utf8');
    return true;
  } catch (e) {
    console.error('Failed to save user data:', e);
    return false;
  }
});

// Window Mode Toggles
ipcMain.on('toggle-mini-player', (event, isMini) => {
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
      webSecurity: false, // Allow file:// protocol for local/NAS audio files
      preload: path.join(__dirname, 'preload.cjs') // Safe context bridge
    }
  });

  // Load the production build index.html from dist folder (strictly local file loading, serverless!)
  win.loadFile(path.join(__dirname, 'dist', 'index.html'));

  // Open external links in default OS browser instead of inside electron window
  win.webContents.setWindowOpenHandler(({ url }) => {
    require('electron').shell.openExternal(url);
    return { action: 'deny' };
  });

  // Display seamlessly once content is parsed
  win.once('ready-to-show', () => {
    win.show();
  });
}

// macOS standard: keep app running when all windows close unless quit
  app.whenReady().then(() => {
    // Make sure IPC can receive crash logs and write them to a file
    ipcMain.on('crash-log', (event, errorInfo) => {
      try {
        const fs = require('fs');
        const path = require('path');
        fs.appendFileSync(path.join(app.getPath('userData'), 'crash-log.txt'), new Date().toISOString() + '\n' + errorInfo + '\n\n');
      } catch (e) {
        console.error("Failed to write crash log", e);
      }
    });

    ipcMain.on('show-error-box', (event, title, content) => {
      dialog.showErrorBox(title, content);
    });

    createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
