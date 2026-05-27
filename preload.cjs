const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  showItemInFolder: (path) => ipcRenderer.send('show-item-in-folder', path),
  scanFolderForAudio: (folderPath) => ipcRenderer.invoke('scan-folder-for-audio', folderPath),
  isDirectory: (filePath) => ipcRenderer.invoke('is-directory', filePath),
  selectFolders: () => ipcRenderer.invoke('select-folders'),
  loadUserData: () => ipcRenderer.invoke('load-user-data'),
  saveUserData: (data) => ipcRenderer.invoke('save-user-data', data),
});
