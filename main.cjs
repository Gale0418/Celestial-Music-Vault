const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');

const AUDIO_EXTENSIONS = new Set(['.mp3', '.wav', '.ogg', '.m4a', '.mp4', '.flac', '.aac', '.wma', '.opus', '.aiff']);

// Fast recursive directory scanner using Node.js fs.promises (avoids WebKit FileSystem API limitations)
async function scanAudioFiles(dirPath, results = []) {
  try {
    const entries = await fs.promises.readdir(dirPath, { withFileTypes: true });
    const promises = [];
    for (const entry of entries) {
      // Skip hidden files/folders and dev junk
      if (entry.name.startsWith('.') || entry.name === 'node_modules' || entry.name === '__MACOSX') continue;
      const fullPath = path.join(dirPath, entry.name);
      if (entry.isDirectory()) {
        promises.push(scanAudioFiles(fullPath, results));
      } else {
        const ext = path.extname(entry.name).toLowerCase();
        if (AUDIO_EXTENSIONS.has(ext)) {
          results.push(fullPath);
        }
      }
    }
    await Promise.all(promises);
  } catch (e) {
    console.warn('Scan error (skipping):', dirPath, e.message);
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
  return result.filePaths;
});

// IPC: Fast Node.js folder scanner
ipcMain.handle('scan-folder-for-audio', async (event, folderPath) => {
  return scanAudioFiles(folderPath);
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
