const { contextBridge, ipcRenderer, webUtils } = require('electron');

function pathForFile(file) {
  try {
    if (!file) return '';
    return webUtils.getPathForFile(file) || '';
  } catch {
    return '';
  }
}

contextBridge.exposeInMainWorld('electronAPI', {
  showItemInFolder: (path) => ipcRenderer.send('show-item-in-folder', path),
  scanFolderForAudio: (folderPath) => ipcRenderer.invoke('scan-folder-for-audio', folderPath),
  selectFolders: () => ipcRenderer.invoke('select-folders'),
  registerSelectedFiles: (files) => {
    const paths = Array.from(files || []).map(pathForFile).filter(Boolean);
    return paths.length > 0
      ? ipcRenderer.invoke('register-user-selected-paths', paths)
      : Promise.resolve([]);
  },
  toMediaUrl: (filePath) => `cmv://app/media/${encodeURIComponent(filePath)}`,
  toRemoteMediaUrl: (url) => `cmv://app/remote/${encodeURIComponent(url)}`,
  loadUserData: () => ipcRenderer.invoke('load-user-data'),
  saveUserData: (data) => ipcRenderer.invoke('save-user-data', data),
  showErrorBox: (title, content) => ipcRenderer.send('show-error-box', title, content),
  trashItem: (filePath) => ipcRenderer.invoke('trash-item', filePath),
  showMessageBox: (options) => ipcRenderer.invoke('show-message-box', options),
  toggleMiniPlayer: (isMini) => ipcRenderer.send('toggle-mini-player', isMini),
  toggleFullscreen: (isFullscreen) => ipcRenderer.send('toggle-fullscreen', isFullscreen),
});