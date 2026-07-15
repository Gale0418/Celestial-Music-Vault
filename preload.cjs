const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  showItemInFolder: (path) => ipcRenderer.send('show-item-in-folder', path),
  scanFolderForAudio: (folderPath) => ipcRenderer.invoke('scan-folder-for-audio', folderPath),
  isDirectory: (filePath) => ipcRenderer.invoke('is-directory', filePath),
  selectFolders: () => ipcRenderer.invoke('select-folders'),
  loadUserData: () => ipcRenderer.invoke('load-user-data'),
  saveUserData: (data) => ipcRenderer.invoke('save-user-data', data),
  showErrorBox: (title, content) => ipcRenderer.send('show-error-box', title, content),
  trashItem: (filePath) => ipcRenderer.invoke('trash-item', filePath),
  showMessageBox: (options) => ipcRenderer.invoke('show-message-box', options),
  toggleMiniPlayer: (isMini) => ipcRenderer.send('toggle-mini-player', isMini),
  toggleFullscreen: (isFullscreen) => ipcRenderer.send('toggle-fullscreen', isFullscreen),
});
