import React, { useState, useRef, useEffect, useMemo } from 'react';
import { UploadCloud, Music, Play, Disc, FolderOpen, MoreVertical, Heart, Plus, Trash, Trash2, CheckSquare, Square, ListPlus, PlayCircle } from 'lucide-react';
import { useAudio } from '../context/AudioContext';
import { sortTracksWithOriginalIndex } from '../utils/trackSorting';

const dropdownItemStyle = {
  display: 'block',
  width: '100%',
  textAlign: 'left',
  padding: '8px 12px',
  borderRadius: '6px',
  border: 'none',
  background: 'transparent',
  color: 'var(--text-primary)',
  fontSize: '13px',
  cursor: 'pointer',
  transition: 'background 0.1s'
};

const ALL_COLUMNS = [
  { id: 'index',   label: '#' },
  { id: 'title',   label: '歌名' },
  { id: 'artist',  label: '藝術家' },
  { id: 'album',   label: '專輯' },
  { id: 'rating',  label: '星星評分' },
  { id: 'actions', label: '操作' },
];

const DEFAULT_VISIBLE_COLUMNS = ALL_COLUMNS.map(({ id }) => id);
const VALID_COLUMN_IDS = new Set(ALL_COLUMNS.map(({ id }) => id));

const normalizeVisibleColumns = (columns) => {
  const validColumns = [...new Set(columns.filter((id) => VALID_COLUMN_IDS.has(id)))];
  if (validColumns.length === 0) return DEFAULT_VISIBLE_COLUMNS;
  return validColumns.includes('title') ? validColumns : [...validColumns, 'title'];
};

const LocalLibrary = () => {
  const { 
    playlist, 
    setPlaylist,
    currentTrack,
    isPlaying, 
    importLocalFiles, 
    importLocalFilesByPaths, 
    loadingState, 
    setLoadingState,
    favorites,
    playlists,
    library,
    setLibrary,
    activeView,
    toggleFavorite,
    addTrackToPlaylist,
    removeTrackFromPlaylist,
    playTrackInList,
    removeTrackFromLibrary,
    playNext,
    playbackSource,
    syncPlaylist,
    clearLibrary,
    trackRatings,
    setTrackRating
  } = useAudio();
  
  const [isDragOver, setIsDragOver] = useState(false);
  const [contextMenu, setContextMenu] = useState(null);
  const [selectedTrackIds, setSelectedTrackIds] = useState(new Set());

  useEffect(() => {
    setSelectedTrackIds(new Set());
  }, [activeView]);
  const [lastSelectedIndex, setLastSelectedIndex] = useState(null);
  const [showPlaylistDropdown, setShowPlaylistDropdown] = useState(false);
  const [showColumnPicker, setShowColumnPicker] = useState(false);
  const [sortKey, setSortKey] = useState('default');
  const [sortDirection, setSortDirection] = useState('asc');
  const [visibleColumns, setVisibleColumns] = useState(() => {
    try {
      const saved = JSON.parse(localStorage.getItem('aeromusic-columns'));
      if (Array.isArray(saved)) return normalizeVisibleColumns(saved);
    } catch {
      // Ignore invalid saved column preferences and use the defaults below.
    }
    return DEFAULT_VISIBLE_COLUMNS;
  });

  const toggleColumn = (colId) => {
    // Never allow hiding title
    if (colId === 'title') return;
    const next = visibleColumns.includes(colId)
      ? visibleColumns.filter(c => c !== colId)
      : [...visibleColumns, colId];
    setVisibleColumns(next);
    localStorage.setItem('aeromusic-columns', JSON.stringify(next));
  };

  const col = (id) => visibleColumns.includes(id);

  const fileInputRef = useRef(null);
  const dirInputRef = useRef(null);

  const { viewTracks, viewTitle, viewDesc, showDropZone, sortedTracks } = useMemo(() => {
    let view;
    if (activeView === 'library') {
      view = {
        viewTracks: library,
        viewTitle: '本地音樂庫',
        viewDesc: '支援將整批音訊檔案或整個資料夾拖放進來播放！您的永久音樂庫會安全地儲存起來。',
        showDropZone: true
      };
    } else if (activeView === 'favorites') {
      view = {
        viewTracks: favorites,
        viewTitle: '我的最愛',
        viewDesc: '集中瀏覽已收藏的曲目；按愛心即可加入或移除。',
        showDropZone: false
      };
    } else if (activeView.startsWith('playlist-')) {
      const playlistId = activeView.replace('playlist-', '');
      const currentPlaylist = playlists.find((item) => item.id === playlistId);
      if (currentPlaylist) {
        view = {
          viewTracks: currentPlaylist.tracks,
          viewTitle: currentPlaylist.name,
          viewDesc: `這是一個自訂播放清單，共有 ${currentPlaylist.tracks.length} 首歌曲。主人可以在其他清單對歌曲點擊滑鼠「右鍵」來加入這裡喔！`,
          showDropZone: false
        };
      }
    }
    if (!view) {
      view = {
        viewTracks: playlist,
        viewTitle: '本地音樂庫',
        viewDesc: '支援將整批音訊檔案或整個資料夾拖放進來播放！',
        showDropZone: true
      };
    }
    return {
      ...view,
      sortedTracks: sortTracksWithOriginalIndex(view.viewTracks, sortKey, sortDirection)
    };
  }, [activeView, favorites, library, playlist, playlists, sortDirection, sortKey]);

  // 播放「排序後列表」中指定 index 的歌 — 讓 playlist 狀態與 UI 顯示完全一致
  const handlePlayTrack = (sortedIndex, currentSortedTracks) => {
    playTrackInList(currentSortedTracks, sortedIndex, activeView);
  };

  // 處理多選點擊
  const handleRowClick = (e, index, track) => {
    e.stopPropagation();

    if (e.shiftKey && lastSelectedIndex !== null) {
      // Shift-click: select range
      const start = Math.min(lastSelectedIndex, index);
      const end = Math.max(lastSelectedIndex, index);
      const newSelection = new Set(selectedTrackIds);
      for (let i = start; i <= end; i++) {
        newSelection.add(sortedTracks[i].id);
      }
      setSelectedTrackIds(newSelection);
    } else if (e.metaKey || e.ctrlKey) {
      // Cmd/Ctrl-click: toggle individual
      const newSelection = new Set(selectedTrackIds);
      if (newSelection.has(track.id)) {
        newSelection.delete(track.id);
      } else {
        newSelection.add(track.id);
      }
      setSelectedTrackIds(newSelection);
      setLastSelectedIndex(index);
    } else {
      // Normal click: just play the track
      handlePlayTrack(index, sortedTracks);
      setLastSelectedIndex(index);
      // Optional: auto-clear selection on normal play
      if (selectedTrackIds.size > 0) {
        setSelectedTrackIds(new Set());
      }
    }
  };

  const handleCheckboxClick = (e, index, track) => {
    e.stopPropagation();
    const newSelection = new Set(selectedTrackIds);
    if (newSelection.has(track.id)) {
      newSelection.delete(track.id);
    } else {
      newSelection.add(track.id);
    }
    setSelectedTrackIds(newSelection);
    setLastSelectedIndex(index);
  };

  const handleSort = (key) => {
    if (sortKey === key) {
      setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
    } else {
      setSortKey(key);
      setSortDirection('asc');
    }
  };

  // 當畫面排序改變時，如果目前正在播放這個畫面，則同步更新播放清單，這樣下一首就會照新排序播
  useEffect(() => {
    if (playbackSource === activeView) {
      syncPlaylist(sortedTracks);
    }
  }, [sortedTracks, playbackSource, activeView, syncPlaylist]);

  // Close context menu on window click
  useEffect(() => {
    const handleWindowClick = () => {
      setContextMenu(null);
    };
    window.addEventListener('click', handleWindowClick);
    return () => window.removeEventListener('click', handleWindowClick);
  }, []);

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragOver(true);
  };

  const handleDragLeave = () => {
    setIsDragOver(false);
  };

  // Helper for recursive folder scanning - optimized to prevent freezes by skipping hidden files, non-audio files, and node_modules
  const scanFileEntry = async (entry, filesToImport) => {
    // Ignore hidden files/folders (starting with .) or node_modules
    if (entry.name.startsWith('.') || entry.name === 'node_modules') {
      return;
    }

    if (entry.isFile) {
      // Fast extension check before generating browser file descriptor (huge speedup!)
      const dotIdx = entry.name.lastIndexOf('.');
      if (dotIdx !== -1) {
        const ext = entry.name.substring(dotIdx).toLowerCase();
        const supportedExts = ['.mp3', '.wav', '.ogg', '.m4a', '.mp4'];
        if (supportedExts.includes(ext)) {
          const file = await new Promise((resolve) => entry.file(resolve, (err) => {
            console.error('File read error:', err);
            resolve(null);
          }));
          if (file) filesToImport.push(file);
        }
      }
    } else if (entry.isDirectory) {
      const dirReader = entry.createReader();
      const readAllEntries = async () => {
        // Resolve empty array on read errors to prevent infinite loops
        const entries = await new Promise((resolve) => {
          dirReader.readEntries(resolve, (err) => {
            console.error('Directory read error:', err);
            resolve([]);
          });
        });

        if (entries && entries.length > 0) {
          const subPromises = [];
          for (const subEntry of entries) {
            subPromises.push(scanFileEntry(subEntry, filesToImport));
          }
          await Promise.all(subPromises);
          await readAllEntries(); // recurse to read remaining pages
        }
      };
      await readAllEntries();
    }
  };

  const handleDrop = async (e) => {
    e.preventDefault();
    setIsDragOver(false);

    // ⚠️ CRITICAL: Must synchronously extract ALL dataTransfer data BEFORE any await!
    // After any await, the DataTransfer object is cleared by the browser.
    const extractedItems = [];

    // Use e.dataTransfer.files (FileList) - more reliable for folders in Electron
    // item.getAsFile() can return null for folders, but FileList always includes them
    const fileList = e.dataTransfer.files;
    const itemList = e.dataTransfer.items;

    if (fileList && fileList.length > 0) {
      for (let i = 0; i < fileList.length; i++) {
        const file = fileList[i];
        if (!file) continue;
        // Correlate with items to get directory info via webkitGetAsEntry
        const entry = itemList && itemList[i] ? itemList[i].webkitGetAsEntry() : null;
        extractedItems.push({
          path: file.path || '',
          isDirectory: entry ? entry.isDirectory : (file.size === 0 && file.type === ''),
          entry: entry,
          file: file,
        });
      }
    }

    if (extractedItems.length === 0) {
      return; // Nothing dropped
    }

    // NOW safe to await - DataTransfer already fully read above
    setLoadingState({ active: true, current: 0, total: 0, percent: 0, phase: 'scanning' });
    await new Promise(resolve => setTimeout(resolve, 40));

    // === FAST PATH: Electron IPC + Node.js fs.promises (perfect for NAS!) ===
    if (window.electronAPI && window.electronAPI.scanFolderForAudio) {
      const allFilePaths = [];
      const promises = [];

      for (const info of extractedItems) {
        if (!info.path) continue;
        if (info.isDirectory) {
          promises.push(
            window.electronAPI.scanFolderForAudio(info.path)
              .then(paths => allFilePaths.push(...paths))
              .catch(err => console.warn('IPC scan error:', err))
          );
        } else {
          allFilePaths.push(info.path);
        }
      }

      await Promise.all(promises);

      if (allFilePaths.length > 0) {
        importLocalFilesByPaths(allFilePaths);
      } else {
        setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
      }
      return;
    }

    // === FALLBACK: WebKit FileSystem API (non-Electron) ===
    const filesToImport = [];
    const scanPromises = extractedItems
      .filter(info => info.entry)
      .map(info => scanFileEntry(info.entry, filesToImport));

    await Promise.all(scanPromises);

    if (filesToImport.length > 0) {
      importLocalFiles(filesToImport);
    } else {
      // If no entries but have files (plain file drop without FileSystem API)
      const plainFiles = extractedItems.map(i => i.file).filter(Boolean);
      if (plainFiles.length > 0) importLocalFiles(plainFiles);
      else setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
    }
  };

  const handleFileSelect = (e) => {
    if (e.target.files && e.target.files.length > 0) {
      importLocalFiles(e.target.files);
    }
  };

  const triggerFileInput = () => {
    if (fileInputRef.current) fileInputRef.current.click();
  };

  // Native Electron multi-folder dialog (supports selecting multiple folders at once!)
  const handleSelectFolders = async (e) => {
    e.stopPropagation();
    if (!window.electronAPI || !window.electronAPI.selectFolders) {
      // Fallback for non-Electron: use the old webkitdirectory input
      if (dirInputRef.current) dirInputRef.current.click();
      return;
    }
    const folderPaths = await window.electronAPI.selectFolders();
    if (!folderPaths || folderPaths.length === 0) return;

    setLoadingState({ active: true, current: 0, total: 0, percent: 0, phase: 'scanning' });
    await new Promise(resolve => setTimeout(resolve, 40));

    const allFilePaths = [];
    await Promise.all(
      folderPaths.map(fp =>
        window.electronAPI.scanFolderForAudio(fp)
          .then(paths => allFilePaths.push(...paths))
          .catch(err => console.warn('Scan error:', err))
      )
    );

    if (allFilePaths.length > 0) {
      importLocalFilesByPaths(allFilePaths);
    } else {
      setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
    }
  };

  const handleRowContextMenu = (e, track) => {
    e.preventDefault();
    setContextMenu({
      x: e.clientX,
      y: e.clientY,
      track: track
    });
  };

  const handleShowInFinder = (track) => {
    if (window.electronAPI && track.path) {
      window.electronAPI.showItemInFolder(track.path);
    } else {
      alert(`「在 Finder 中顯示」只支援在原生 Mac App 中執行喔！目前檔案的本機路徑是：\n${track.path || '無本機路徑'}`);
    }
  };

  return (
    <div className="library-view" style={{
      padding: '40px 30px',
      height: '100%',
      overflowY: 'auto',
      width: '100%',
      position: 'relative',
      zIndex: 1
    }}>
      <div style={{ marginBottom: '32px' }}>
        <h1 style={{
          fontFamily: 'var(--font-display)',
          fontSize: '32px',
          fontWeight: 800,
          background: 'none',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'var(--text-primary)',
          color: 'var(--text-primary)',
          letterSpacing: '-1px'
        }}>
          {viewTitle}
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '6px' }}>
          {viewDesc}
        </p>
      </div>

      {/* DRAG AND DROP ZONE */}
      {showDropZone && (
        <div
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
          style={{
            border: isDragOver ? '2px dashed var(--primary-color)' : '2px dashed var(--border-glass-bright)',
            borderRadius: 'var(--radius-lg)',
            padding: '48px 30px',
            textAlign: 'center',
            background: isDragOver ? 'var(--primary-soft)' : 'var(--bg-glass-light)',
            cursor: 'pointer',
            transition: 'all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1)',
            marginBottom: '36px',
            boxShadow: isDragOver ? 'var(--shadow-glow)' : 'none',
            transform: isDragOver ? 'scale(1.01)' : 'scale(1)'
          }}
          id="drop-zone"
          className="library-drop-zone"
        >
        <input
          type="file"
          ref={fileInputRef}
          onChange={handleFileSelect}
          multiple
          accept="audio/*,video/mp4,.m4a,.mp4"
          style={{ display: 'none' }}
        />
        <input
          type="file"
          ref={dirInputRef}
          onChange={handleFileSelect}
          multiple
          webkitdirectory="true"
          directory="true"
          style={{ display: 'none' }}
        />
        
        <div style={{
          background: isDragOver ? 'var(--primary-gradient)' : 'var(--bg-glass-active)',
          width: '64px',
          height: '64px',
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 16px auto',
          boxShadow: isDragOver ? '0 4px 14px var(--primary-glow)' : 'none',
          transition: 'all 0.3s'
        }}>
          <UploadCloud size={32} color={isDragOver ? '#fff' : 'var(--text-secondary)'} aria-hidden="true" />
        </div>

        <h3 style={{ fontSize: '16px', fontWeight: 600, color: 'var(--text-primary)', marginBottom: '8px' }}>
          {isDragOver ? '放下檔案或整個資料夾即可匯入！' : '將檔案或「整包資料夾」拖曳到此處'}
        </h3>
        
        <p style={{ fontSize: '12px', color: 'var(--text-muted)', maxWidth: '400px', margin: '0 auto 16px auto' }}>
          支援一次匯入多個檔案或整個資料夾；原始檔案不會被搬動。
        </p>

        {/* Select buttons for Files or Folders */}
        <div style={{ display: 'flex', gap: '16px', justifyContent: 'center', marginTop: '16px' }}>
          <button 
            onClick={(e) => { e.stopPropagation(); triggerFileInput(); }}
            style={{
              padding: '8px 18px',
              borderRadius: '20px',
              border: 'none',
              background: 'var(--primary-gradient)',
              color: '#fff',
              fontWeight: 700,
              cursor: 'pointer',
              fontSize: '12px',
              boxShadow: '0 4px 10px var(--primary-glow)',
              transition: 'transform 0.15s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.05)'}
            onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
          >
            選擇音樂檔案
          </button>
          
          {/* Native Electron dialog: supports multi-folder selection! */}
          <button 
            onClick={handleSelectFolders}
            style={{
              padding: '8px 18px',
              borderRadius: '20px',
              border: '1px solid var(--border-glass)',
              background: 'var(--bg-glass-light)',
              color: 'var(--text-primary)',
              fontWeight: 700,
              cursor: 'pointer',
              fontSize: '12px',
              transition: 'transform 0.15s, background 0.15s'
            }}
            onMouseEnter={(e) => { e.currentTarget.style.transform = 'scale(1.05)'; e.currentTarget.style.background = 'var(--bg-glass-active)'; }}
            onMouseLeave={(e) => { e.currentTarget.style.transform = 'scale(1)'; e.currentTarget.style.background = 'var(--bg-glass-light)'; }}
          >
            選擇資料夾（可複選）
          </button>
        </div>
      </div>
      )}

      {/* LOCAL SONGS LIST */}
      <div>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '16px'
        }}>
          <h3 style={{
            fontSize: '18px',
            fontWeight: 700,
            color: 'var(--text-primary)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            <Disc size={18} color="var(--primary-color)" />
            <span>{viewTitle} 歌曲 ({viewTracks.length})</span>
            <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 500, marginLeft: '6px' }}>
              Cmd/Ctrl 或 Shift 多選，右鍵開啟更多操作
            </span>
          </h3>

          {/* 清空音樂庫按鈕 */}
          {activeView === 'library' && viewTracks.length > 0 && (
            <button
              type="button"
              aria-label="清空本地音樂庫"
              onClick={() => {
                if (window.confirm('確定要清空整個本地音樂庫嗎？這將移除所有載入的清單（但不影響實際檔案）。')) {
                  clearLibrary();
                  setSelectedTrackIds(new Set());
                }
              }}
              style={{
                background: 'rgba(255, 59, 48, 0.15)',
                border: '1px solid rgba(255, 59, 48, 0.3)',
                color: '#ff3b30',
                padding: '6px 12px',
                borderRadius: '8px',
                fontSize: '12px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                transition: 'background 0.2s'
              }}
              onMouseEnter={e => e.currentTarget.style.background = 'rgba(255, 59, 48, 0.25)'}
              onMouseLeave={e => e.currentTarget.style.background = 'rgba(255, 59, 48, 0.15)'}
            >
              <Trash2 size={14} /> 清空庫存
            </button>
          )}

          {/* ⚙️ 欄位選擇器 */}
          <div style={{ position: 'relative' }}>
            <button
              type="button"
              aria-expanded={showColumnPicker}
              aria-label="自訂顯示欄位"
              onClick={() => setShowColumnPicker(v => !v)}
              style={{
                background: showColumnPicker ? 'var(--bg-glass-active)' : 'var(--bg-glass-light)',
                border: '1px solid var(--border-glass)',
                color: 'var(--text-secondary)',
                padding: '6px 12px',
                borderRadius: '8px',
                fontSize: '12px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '5px',
                transition: 'all 0.2s'
              }}
              title="自訂欄位"
            >
              欄位
            </button>

            {showColumnPicker && (
              <div
                style={{
                  position: 'absolute',
                  top: 'calc(100% + 8px)',
                  right: 0,
                  background: 'var(--bg-glass-heavy)',
                  backdropFilter: 'blur(20px)',
                  border: '1px solid var(--border-glass-bright)',
                  borderRadius: '12px',
                  padding: '8px',
                  minWidth: '170px',
                  boxShadow: 'var(--shadow-card)',
                  zIndex: 99999
                }}
                onClick={e => e.stopPropagation()}
              >
                <div style={{ padding: '4px 10px 8px', fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.5px', borderBottom: '1px solid var(--border-glass)', marginBottom: '4px' }}>
                  顯示欄位
                </div>
                {ALL_COLUMNS.map(column => (
                  <button
                    key={column.id}
                    onClick={() => toggleColumn(column.id)}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '10px',
                      width: '100%',
                      padding: '7px 10px',
                      borderRadius: '6px',
                      border: 'none',
                      background: 'transparent',
                      color: column.id === 'title' ? 'var(--text-muted)' : 'var(--text-primary)',
                      fontSize: '13px',
                      cursor: column.id === 'title' ? 'not-allowed' : 'pointer',
                      textAlign: 'left',
                      transition: 'background 0.15s'
                    }}
                    onMouseEnter={e => { if (column.id !== 'title') e.currentTarget.style.background = 'var(--bg-glass-active)'; }}
                    onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                  >
                    <span style={{
                      width: '16px',
                      height: '16px',
                      borderRadius: '4px',
                      border: '1.5px solid',
                      borderColor: visibleColumns.includes(column.id) ? 'var(--primary-color)' : 'var(--border-glass-bright)',
                      background: visibleColumns.includes(column.id) ? 'var(--primary-color)' : 'transparent',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      flexShrink: 0,
                      fontSize: '10px',
                      color: '#fff'
                    }}>
                      {visibleColumns.includes(column.id) && '✓'}
                    </span>
                    {column.label}
                    {column.id === 'title' && <span style={{ fontSize: '10px', color: 'var(--text-muted)', marginLeft: 'auto' }}>(必須)</span>}
                  </button>
                ))}
              </div>
            )}
          </div>
        </div>


        {viewTracks.length === 0 ? (
          /* Empty State */
          <div className="glass-effect" style={{
            borderRadius: 'var(--radius-md)',
            padding: '40px',
            textAlign: 'center',
            background: 'var(--bg-glass-light)',
            border: '1px solid var(--border-glass)'
          }}>
            <Music size={40} color="var(--text-muted)" style={{ marginBottom: '12px', opacity: 0.5 }} />
            <p style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '4px' }}>
              音樂庫目前沒有曲目
            </p>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
              將音樂檔案或資料夾拖曳到上方，即可開始建立收藏。
            </p>
          </div>
        ) : (
          /* Songs Table */
          <div className="glass-effect" style={{
            borderRadius: 'var(--radius-md)',
            overflow: 'hidden',
            border: '1px solid var(--border-glass)',
            boxShadow: 'var(--shadow-card)'
          }}>
            <table style={{
              width: '100%',
              borderCollapse: 'collapse',
              textAlign: 'left'
            }} id="local-songs-table">
              <thead>
                <tr style={{
                  borderBottom: '1px solid var(--border-glass)',
                  background: 'var(--bg-glass-light)'
                }}>
                  <th style={{ padding: '12px 10px 12px 20px', width: '30px' }}>
                    <button
                      type="button"
                      aria-label="全選或取消全選歌曲"
                      onClick={() => {
                        if (selectedTrackIds.size === sortedTracks.length) {
                          setSelectedTrackIds(new Set());
                        } else {
                          setSelectedTrackIds(new Set(sortedTracks.map(t => t.id)));
                        }
                      }}
                      style={{
                        background: 'transparent',
                        border: 'none',
                        color: selectedTrackIds.size === sortedTracks.length && sortedTracks.length > 0 ? 'var(--primary-color)' : 'var(--text-muted)',
                        cursor: 'pointer',
                        padding: 0,
                        display: 'flex'
                      }}
                    >
                      {selectedTrackIds.size === sortedTracks.length && sortedTracks.length > 0 ? <CheckSquare size={16} /> : <Square size={16} />}
                    </button>
                  </th>
                  {col('index') && <th onClick={() => handleSort('default')} style={{ padding: '12px 10px', fontSize: '12px', color: sortKey === 'default' ? 'var(--primary-color)' : 'var(--text-secondary)', fontWeight: 600, cursor: 'pointer', transition: 'color 0.2s' }}># {sortKey === 'default' && (sortDirection === 'asc' ? '▲' : '▼')}</th>}
                  {col('title') && <th onClick={() => handleSort('title')} style={{ padding: '12px 20px', fontSize: '12px', color: sortKey === 'title' ? 'var(--primary-color)' : 'var(--text-secondary)', fontWeight: 600, cursor: 'pointer', transition: 'color 0.2s' }}>歌名 {sortKey === 'title' && (sortDirection === 'asc' ? '▲' : '▼')}</th>}
                  {col('artist') && <th onClick={() => handleSort('artist')} style={{ padding: '12px 20px', fontSize: '12px', color: sortKey === 'artist' ? 'var(--primary-color)' : 'var(--text-secondary)', fontWeight: 600, cursor: 'pointer', transition: 'color 0.2s' }}>藝術家 {sortKey === 'artist' && (sortDirection === 'asc' ? '▲' : '▼')}</th>}
                  {col('album') && <th onClick={() => handleSort('album')} style={{ padding: '12px 20px', fontSize: '12px', color: sortKey === 'album' ? 'var(--primary-color)' : 'var(--text-secondary)', fontWeight: 600, cursor: 'pointer', transition: 'color 0.2s' }}>專輯 {sortKey === 'album' && (sortDirection === 'asc' ? '▲' : '▼')}</th>}
                  {col('rating') && <th style={{ padding: '12px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600 }}>評分</th>}
                  {col('actions') && <th style={{ padding: '12px 20px', fontSize: '12px', color: 'var(--text-secondary)', fontWeight: 600, textAlign: 'right' }}>操作</th>}
                </tr>
              </thead>
              <tbody>
                {sortedTracks.map((track, index) => {
                  // 用 track.id 對照 currentTrack.id 判斷是否正在播放（不受 index 影響）
                  const isCurrentTrack = track.id === currentTrack?.id;
                  const isPlayingThis = isCurrentTrack && isPlaying;
                    const isFav = favorites.some(f => (f.id && track.id && f.id === track.id) || (!!f.path && !!track.path && f.path === track.path));
                  const isSelected = selectedTrackIds.has(track.id);
                  
                  return (
                    <tr
                      key={track.id}
                      onClick={(e) => handleRowClick(e, index, track)}
                      onContextMenu={(e) => handleRowContextMenu(e, track)}
                      style={{
                        borderBottom: '1px solid var(--border-glass)',
                        cursor: 'pointer',
                        background: isSelected ? 'var(--primary-soft)' : (isCurrentTrack ? 'var(--bg-glass-active)' : 'transparent'),
                        transition: 'background 0.15s',
                        contentVisibility: 'auto',
                        containIntrinsicSize: '56px'
                      }}
                      className="table-row-hover"
                    >
                      {/* Checkbox Column */}
                      <td style={{ padding: '14px 10px 14px 20px', width: '30px' }}>
                        <button
                          type="button"
                          aria-label={`${isSelected ? '取消選取' : '選取'} ${track.title}`}
                          onClick={(e) => handleCheckboxClick(e, index, track)}
                          style={{
                            background: 'transparent',
                            border: 'none',
                            color: isSelected ? 'var(--primary-color)' : 'var(--text-muted)',
                            cursor: 'pointer',
                            padding: 0,
                            display: 'flex',
                            opacity: isSelected ? 1 : 0.4
                          }}
                          className="row-checkbox"
                        >
                          {isSelected ? <CheckSquare size={16} /> : <Square size={16} />}
                        </button>
                      </td>

                      {/* # Column */}
                      {col('index') && (
                        <td style={{ padding: '14px 10px', fontSize: '13px', color: isCurrentTrack ? 'var(--primary-color)' : 'var(--text-secondary)', width: '50px' }}>
                          {isPlayingThis ? (
                            <div style={{ display: 'flex', gap: '3px', alignItems: 'flex-end', height: '12px' }}>
                              <div className="bar-anim" style={{ width: '2px', height: '100%', background: 'var(--primary-color)', transformOrigin: 'bottom', animation: 'meterPulse 1s cubic-bezier(.22,1,.36,1) infinite alternate' }} />
                              <div className="bar-anim" style={{ width: '2px', height: '60%', background: 'var(--primary-color)', transformOrigin: 'bottom', animation: 'meterPulse 0.8s cubic-bezier(.22,1,.36,1) infinite alternate 0.2s' }} />
                              <div className="bar-anim" style={{ width: '2px', height: '80%', background: 'var(--primary-color)', transformOrigin: 'bottom', animation: 'meterPulse 1.2s cubic-bezier(.22,1,.36,1) infinite alternate 0.1s' }} />
                            </div>
                          ) : index + 1}
                        </td>
                      )}

                      {/* Title Column */}
                      {col('title') && (
                        <td style={{ padding: '14px 20px', fontSize: '14px', fontWeight: 600, color: isCurrentTrack ? 'var(--primary-color)' : 'var(--text-primary)' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                            <button
                              onClick={(e) => { e.stopPropagation(); toggleFavorite(track); }}
                              aria-label={isFav ? `取消收藏 ${track.title}` : `收藏 ${track.title}`}
                              style={{ border: 'none', background: 'transparent', cursor: 'pointer', padding: '2px', display: 'flex', alignItems: 'center', color: isFav ? 'var(--primary-color)' : 'var(--text-muted)', transition: 'transform 0.2s, color 0.2s' }}
                              onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.2)'}
                              onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
                              title={isFav ? '取消最愛收藏' : '加入我的最愛'}
                            >
                              <Heart size={14} fill={isFav ? 'var(--primary-color)' : 'transparent'} />
                            </button>
                            <Music size={14} color={isCurrentTrack ? 'var(--primary-color)' : 'var(--text-muted)'} />
                            <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '300px', display: 'inline-block' }}>{track.title}</span>
                          </div>
                        </td>
                      )}

                      {/* Artist Column */}
                      {col('artist') && (
                        <td style={{ padding: '14px 20px', fontSize: '13px', color: 'var(--text-secondary)' }}>{track.artist}</td>
                      )}

                      {/* Album Column */}
                      {col('album') && (
                        <td style={{ padding: '14px 20px', fontSize: '13px', color: 'var(--text-muted)' }}>{track.album}</td>
                      )}

                      {/* Rating Column */}
                      {col('rating') && (
                        <td style={{ padding: '14px 20px' }} onClick={e => e.stopPropagation()}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '2px' }}>
                            {[1,2,3,4,5].map(star => {
                              const currentRating = trackRatings?.[track.id] || 0;
                              return (
                                <button
                                  key={star}
                                  onClick={(e) => { e.stopPropagation(); setTrackRating(track.id, currentRating === star ? 0 : star); }}
                                  aria-label={`${track.title} 評分 ${star} 顆星`}
                                  style={{
                                    border: 'none',
                                    background: 'transparent',
                                    color: star <= currentRating ? '#ffcc00' : 'var(--border-glass-bright)',
                                    cursor: 'pointer',
                                    padding: '1px',
                                    fontSize: '13px',
                                    lineHeight: 1,
                                    transition: 'transform 0.1s'
                                  }}
                                  onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.3)'}
                                  onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
                                >
                                  ★
                                </button>
                              );
                            })}
                          </div>
                        </td>
                      )}

                      {/* Actions Column */}
                      {col('actions') && (
                        <td style={{ padding: '14px 20px', fontSize: '13px', textAlign: 'right' }}>
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'flex-end', gap: '8px' }}>
                            <button type="button" aria-label={`開啟 ${track.title} 的更多操作`} onClick={(e) => { e.stopPropagation(); handleRowContextMenu(e, track); }} style={{ border: 'none', background: 'transparent', color: 'var(--text-muted)', cursor: 'pointer', padding: '4px', borderRadius: '4px' }} className="more-btn"><MoreVertical size={14} aria-hidden="true" /></button>
                            <button
                              type="button"
                              onClick={(event) => {
                                event.stopPropagation();
                                handlePlayTrack(index, sortedTracks);
                              }}
                              aria-label={`播放 ${track.title}`}
                              style={{ border: 'none', background: isCurrentTrack ? 'var(--primary-gradient)' : 'var(--bg-glass-active)', width: '28px', height: '28px', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', cursor: 'pointer' }}
                              title="播放這首"
                            >
                              <Play size={12} fill="currentColor" style={{ marginLeft: '1px' }} aria-hidden="true" />
                            </button>
                          </div>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* ACTION BAR (Multi-selection) */}
      {selectedTrackIds.size > 0 && (
        <div style={{
          position: 'fixed',
          bottom: '100px', // Above PlaybackBar
          left: '50%',
          transform: 'translateX(-50%)',
          background: 'var(--bg-glass-heavy)',
          backdropFilter: 'blur(20px)',
          border: '1px solid var(--border-glass-bright)',
          borderRadius: '16px',
          padding: '12px 24px',
          display: 'flex',
          alignItems: 'center',
          gap: '24px',
          boxShadow: 'var(--shadow-card)',
          zIndex: 9999
        }}>
          <div style={{ color: 'var(--text-primary)', fontSize: '14px', fontWeight: 600 }}>
            已選擇 <span style={{ color: 'var(--primary-color)' }}>{selectedTrackIds.size}</span> 首歌曲
          </div>
          
          <div style={{ display: 'flex', gap: '8px', position: 'relative' }}>
            {/* 加入指定歌單 */}
            <div style={{ position: 'relative' }}>
              <button
                onClick={() => setShowPlaylistDropdown(v => !v)}
                style={{
                  background: 'var(--bg-glass-active)',
                  border: 'none',
                  padding: '8px 16px',
                  borderRadius: '8px',
                  color: 'var(--text-primary)',
                  fontSize: '13px',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  transition: 'background 0.2s'
                }}
                onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-glass-active)'}
                onMouseLeave={e => e.currentTarget.style.background = 'var(--bg-glass-light)'}
              >
                <ListPlus size={16} /> 加入歌單 ▾
              </button>

              {/* Dropdown */}
              {showPlaylistDropdown && (
                <div
                  style={{
                    position: 'absolute',
                    bottom: 'calc(100% + 8px)',
                    left: 0,
                    background: 'var(--bg-glass-heavy)',
                    backdropFilter: 'blur(20px)',
                    border: '1px solid var(--border-glass-bright)',
                    borderRadius: '10px',
                    padding: '6px',
                    minWidth: '180px',
                    boxShadow: 'var(--shadow-card)',
                    zIndex: 99999
                  }}
                  onClick={e => e.stopPropagation()}
                >
                  {/* 加入目前播放佇列 */}
                  <button
                    onClick={() => {
                      const selected = sortedTracks.filter(t => selectedTrackIds.has(t.id));
                      setPlaylist([...playlist, ...selected]);
                      setSelectedTrackIds(new Set());
                      setShowPlaylistDropdown(false);
                    }}
                    style={dropdownItemStyle}
                    onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-glass-active)'}
                    onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                  >
                    加入目前播放佇列
                  </button>

                  {playlists.length > 0 && (
                    <div style={{ borderTop: '1px solid var(--border-glass)', margin: '4px 0' }} />
                  )}

                  {playlists.map(pl => (
                    <button
                      key={pl.id}
                      onClick={() => {
                        const selected = sortedTracks.filter(t => selectedTrackIds.has(t.id));
                        selected.forEach(track => addTrackToPlaylist(pl.id, track));
                        setSelectedTrackIds(new Set());
                        setShowPlaylistDropdown(false);
                        alert(`已將 ${selected.length} 首歌曲加入「${pl.name}」！`);
                      }}
                      style={dropdownItemStyle}
                      onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-glass-active)'}
                      onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
                    >
                      📋 {pl.name}
                    </button>
                  ))}

                  {playlists.length === 0 && (
                    <div style={{ padding: '6px 12px', fontSize: '12px', color: 'var(--text-muted)' }}>
                      尚未建立任何歌單
                    </div>
                  )}
                </div>
              )}
            </div>

            {/* Play Now Selection */}
            <button
              type="button"
              aria-label="播放所選歌曲"
              onClick={() => {
                const selected = sortedTracks.filter(t => selectedTrackIds.has(t.id));
                setPlaylist(selected);
                playTrackInList(selected, 0, activeView);
                setSelectedTrackIds(new Set());
              }}
              style={{
                background: 'var(--primary-gradient)',
                border: 'none',
                padding: '8px 16px',
                borderRadius: '8px',
                color: '#fff',
                fontSize: '13px',
                fontWeight: 600,
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxShadow: '0 4px 12px var(--primary-glow)'
              }}
            >
              <PlayCircle size={16} /> 播放所選
            </button>
            
            {/* Delete Selection (only in active views where deletion makes sense) */}
            <button
              onClick={() => {
                if (window.confirm(`確定要從清單移除這 ${selectedTrackIds.size} 首歌曲嗎？`)) {
                  // Actually implement batch delete based on activeView
                  if (activeView === 'library') {
                    // Revoke object URLs to avoid memory leaks
                    const removedTracks = library.filter(t => selectedTrackIds.has(t.id));
                    removedTracks.forEach(track => {
                      if (track.url && track.url.startsWith('blob:')) {
                        URL.revokeObjectURL(track.url);
                      }
                    });
                    const newLib = library.filter(t => !selectedTrackIds.has(t.id));
                    setLibrary(newLib);
                  } else if (activeView.startsWith('playlist-')) {
                    const pid = activeView.replace('playlist-', '');
                    selectedTrackIds.forEach(id => removeTrackFromPlaylist(pid, id));
                  }
                  setSelectedTrackIds(new Set());
                }
              }}
              style={{
                background: 'rgba(255, 59, 48, 0.1)',
                border: '1px solid rgba(255, 59, 48, 0.3)',
                padding: '8px 16px',
                borderRadius: '8px',
                color: '#ff3b30',
                fontSize: '13px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                transition: 'background 0.2s'
              }}
              onMouseEnter={e => e.currentTarget.style.background = 'rgba(255, 59, 48, 0.2)'}
              onMouseLeave={e => e.currentTarget.style.background = 'rgba(255, 59, 48, 0.1)'}
            >
              <Trash2 size={16} /> 移除所選
            </button>
          </div>

          <button
            onClick={() => setSelectedTrackIds(new Set())}
            style={{
              background: 'transparent',
              border: 'none',
              color: 'var(--text-muted)',
              cursor: 'pointer',
              marginLeft: '8px',
              padding: '4px'
            }}
          >
            ✕
          </button>
        </div>
      )}

      {/* FLOAT GLASSMORPHIC CONTEXT MENU */}
      {contextMenu && (() => {
        const isContextMenuFav = favorites.some(f => (f.id && contextMenu.track.id && f.id === contextMenu.track.id) || (!!f.path && !!contextMenu.track.path && f.path === contextMenu.track.path));
        return (
          <div
            className="glass-effect"
            style={{
              position: 'fixed',
              top: `${contextMenu.y}px`,
              left: `${contextMenu.x}px`,
              borderRadius: '10px',
              padding: '6px',
              width: '200px',
              display: 'flex',
              flexDirection: 'column',
              gap: '2px',
              boxShadow: 'var(--shadow-card)',
              border: '1px solid var(--border-glass-bright)',
              zIndex: 99999,
              backgroundColor: 'var(--bg-glass-heavy)',
              backdropFilter: 'blur(30px)'
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header Title */}
            <div style={{
              padding: '6px 12px',
              fontSize: '11px',
              color: 'var(--text-muted)',
              fontWeight: 700,
              textTransform: 'uppercase',
              letterSpacing: '0.5px',
              borderBottom: '1px solid var(--border-glass)',
              marginBottom: '4px',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis'
            }}>
              {contextMenu.track.title}
            </div>

            {/* Option: Play */}
            <button
              onClick={() => {
                // 找到此 track 在目前 sortedTracks 中的 index，然後用排序後列表播放
                const sortedIdx = sortedTracks.findIndex(t => t.id === contextMenu.track.id);
                if (sortedIdx !== -1) handlePlayTrack(sortedIdx, sortedTracks);
                setContextMenu(null);
              }}
              className="menu-item"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '8px 12px',
                borderRadius: '6px',
                border: 'none',
                background: 'transparent',
                color: 'var(--text-primary)',
                fontSize: '13px',
                fontWeight: 500,
                cursor: 'pointer',
                textAlign: 'left',
                width: '100%',
                transition: 'background 0.1s'
              }}
            >
              <Play size={14} color="var(--primary-color)" />
              <span>立即播放</span>
            </button>

            {/* Option: Favorites Toggle */}
            <button
              onClick={() => {
                toggleFavorite(contextMenu.track);
                setContextMenu(null);
              }}
              className="menu-item"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '8px 12px',
                borderRadius: '6px',
                border: 'none',
                background: 'transparent',
                color: 'var(--text-primary)',
                fontSize: '13px',
                fontWeight: 500,
                cursor: 'pointer',
                textAlign: 'left',
                width: '100%',
                transition: 'background 0.1s'
              }}
            >
              <Heart size={14} color="var(--primary-color)" fill={isContextMenuFav ? "var(--primary-color)" : "transparent"} />
              <span>{isContextMenuFav ? "取消最愛收藏" : "加入我的最愛"}</span>
            </button>

            {/* Option: Play Next */}
            <button
              onClick={() => {
                playNext(contextMenu.track);
                setContextMenu(null);
              }}
              className="menu-item"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '8px 12px',
                borderRadius: '6px',
                border: 'none',
                background: 'transparent',
                color: 'var(--text-primary)',
                fontSize: '13px',
                fontWeight: 500,
                cursor: 'pointer',
                textAlign: 'left',
                width: '100%',
                transition: 'background 0.1s'
              }}
            >
              <Plus size={14} color="var(--accent-blue)" />
              <span>設為下一首播放</span>
            </button>

            {/* Option: Remove from Library */}
            {activeView === 'library' && (
              <button
                onClick={async () => {
                  if (window.electronAPI) {
                    const response = await window.electronAPI.showMessageBox({
                      type: 'question',
                      buttons: ['從音樂庫移除', '一併移至垃圾桶', '取消'],
                      defaultId: 0,
                      cancelId: 2,
                      title: '移除歌曲',
                      message: `確定要移除「${contextMenu.track.title}」嗎？`,
                      detail: '你可以選擇僅從音樂庫中移除，或是將實體檔案一併移至系統垃圾桶。'
                    });
                    
                    if (response.response === 0) {
                      // 僅移除
                      removeTrackFromLibrary(contextMenu.track.id);
                    } else if (response.response === 1) {
                      // 移至垃圾桶
                      if (contextMenu.track.path) {
                        const success = await window.electronAPI.trashItem(contextMenu.track.path);
                        if (success) {
                          removeTrackFromLibrary(contextMenu.track.id);
                        } else {
                          window.electronAPI.showErrorBox('移除失敗', '無法將檔案移至垃圾桶，可能檔案已遺失或權限不足。');
                        }
                      } else {
                        removeTrackFromLibrary(contextMenu.track.id);
                      }
                    }
                  } else {
                    if (confirm(`確定要從『我的音樂庫』中移除這首歌嗎？`)) {
                      removeTrackFromLibrary(contextMenu.track.id);
                    }
                  }
                  setContextMenu(null);
                }}
                className="menu-item"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '8px 12px',
                  borderRadius: '6px',
                  border: 'none',
                  background: 'transparent',
                  color: 'var(--primary-color)',
                  fontSize: '13px',
                  fontWeight: 500,
                  cursor: 'pointer',
                  textAlign: 'left',
                  width: '100%',
                  transition: 'background 0.1s'
                }}
              >
                <Trash size={14} color="var(--primary-color)" />
                <span>從音樂庫中移除</span>
              </button>
            )}

            {/* Option: Remove from current playlist */}
            {activeView.startsWith('playlist-') && (
              <button
                onClick={() => {
                  const playlistId = activeView.replace('playlist-', '');
                  removeTrackFromPlaylist(playlistId, contextMenu.track.id);
                  setContextMenu(null);
                }}
                className="menu-item"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '8px 12px',
                  borderRadius: '6px',
                  border: 'none',
                  background: 'transparent',
                  color: 'var(--primary-color)',
                  fontSize: '13px',
                  fontWeight: 500,
                  cursor: 'pointer',
                  textAlign: 'left',
                  width: '100%',
                  transition: 'background 0.1s'
                }}
              >
                <Trash size={14} color="var(--primary-color)" />
                <span>從此播放清單移除</span>
              </button>
            )}

            {/* Option: Show in Finder */}
            <button
              onClick={() => {
                handleShowInFinder(contextMenu.track);
                setContextMenu(null);
              }}
              className="menu-item"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '10px',
                padding: '8px 12px',
                borderRadius: '6px',
                border: 'none',
                background: 'transparent',
                color: 'var(--text-primary)',
                fontSize: '13px',
                fontWeight: 500,
                cursor: 'pointer',
                textAlign: 'left',
                width: '100%',
                transition: 'background 0.1s'
              }}
            >
              <FolderOpen size={14} color="var(--accent-blue)" />
              <span>在 Finder 中顯示</span>
            </button>

            {/* Option: Copy native path */}
            {contextMenu.track.path && (
              <button
                onClick={() => {
                  navigator.clipboard.writeText(contextMenu.track.path);
                  alert('已將本機檔案完整路徑複製到剪貼簿！');
                  setContextMenu(null);
                }}
                className="menu-item"
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  padding: '8px 12px',
                  borderRadius: '6px',
                  border: 'none',
                  background: 'transparent',
                  color: 'var(--text-primary)',
                  fontSize: '13px',
                  fontWeight: 500,
                  cursor: 'pointer',
                  textAlign: 'left',
                  width: '100%',
                  transition: 'background 0.1s'
                }}
              >
                <Disc size={14} color="var(--accent-purple)" />
                <span style={{ fontSize: '12px' }}>複製檔案路徑</span>
              </button>
            )}

            {/* Sub-menu section: Add to other playlists */}
            {playlists.length > 0 && !activeView.startsWith('playlist-') && (
              <>
                <div style={{
                  padding: '6px 12px 4px 12px',
                  fontSize: '10px',
                  color: 'var(--text-muted)',
                  fontWeight: 700,
                  borderTop: '1px solid var(--border-glass)',
                  marginTop: '4px',
                  letterSpacing: '0.5px'
                }}>
                  加入自訂歌單
                </div>
                
                <div style={{ maxHeight: '120px', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: '2px' }}>
                  {playlists.map(pl => (
                    <button
                      key={pl.id}
                      onClick={() => {
                        addTrackToPlaylist(pl.id, contextMenu.track);
                        alert(`已將歌曲成功加入歌單「${pl.name}」！`);
                        setContextMenu(null);
                      }}
                      className="menu-item"
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: '8px',
                        padding: '6px 12px',
                        borderRadius: '6px',
                        border: 'none',
                        background: 'transparent',
                        color: 'var(--text-secondary)',
                        fontSize: '12px',
                        fontWeight: 500,
                        cursor: 'pointer',
                        textAlign: 'left',
                        width: '100%',
                        transition: 'background 0.1s'
                      }}
                    >
                      <Plus size={12} color="var(--text-muted)" />
                      <span style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{pl.name}</span>
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
        );
      })()}

      {/* GORGEOUS FROSTED GLASS LOADING PROGRESS OVERLAY */}
      {loadingState.active && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'color-mix(in srgb, var(--bg-color-solid) 78%, transparent)',
          backdropFilter: 'blur(30px)',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 999999,
          transition: 'all 0.3s'
        }}>
          <div className="glass-effect glow-loading" style={{
            padding: '40px',
            borderRadius: '24px',
            textAlign: 'center',
            border: '1px solid var(--border-glass-bright)',
            maxWidth: '450px',
            width: '90%',
            boxShadow: 'var(--shadow-card)',
            background: 'var(--bg-glass-heavy)'
          }}>
            {/* Spinning Record Spindle */}
            <div style={{
              width: '80px',
              height: '80px',
              borderRadius: '50%',
              background: loadingState.phase === 'scanning' ? 'linear-gradient(135deg, #af52de, #5856d6)' : 'var(--primary-gradient)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              margin: '0 auto 24px auto',
              boxShadow: loadingState.phase === 'scanning' ? '0 4px 20px rgba(175,82,222,0.5)' : '0 4px 20px var(--primary-glow)',
              animation: 'spin 3s linear infinite'
            }}>
              <Disc size={40} color="#fff" />
            </div>
            
            <h2 style={{ fontSize: '20px', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '8px', letterSpacing: '-0.5px' }}>
              {loadingState.phase === 'scanning'
                ? '正在掃描資料夾中... 🔍'
                : '正在匯入音樂庫'
              }
            </h2>
            
            <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '24px' }}>
              {loadingState.phase === 'scanning'
                ? '正在讀取資料夾結構；大型曲庫可能需要一些時間。'
                : '正在解析音軌資訊。'
              }
            </p>
            
            {/* Progress Bar Container - only show in importing phase */}
            {loadingState.phase === 'importing' && (
              <>
                <div style={{
                  width: '100%',
                  height: '6px',
                  background: 'var(--bg-glass-light)',
                  borderRadius: '3px',
                  overflow: 'hidden',
                  marginBottom: '12px',
                  position: 'relative'
                }}>
                  <div style={{
                    width: '100%',
                    height: '100%',
                    background: 'var(--primary-gradient)',
                    borderRadius: '3px',
                    transform: `scaleX(${loadingState.percent / 100})`,
                    transformOrigin: 'left center',
                    transition: 'transform 0.1s cubic-bezier(.22,1,.36,1)',
                    boxShadow: '0 0 10px var(--primary-glow)'
                  }} />
                </div>

                {/* Progress Percentage Numbers */}
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: 'var(--text-muted)' }}>
                  <span>已處理 {loadingState.current} / {loadingState.total} 首歌曲</span>
                  <span style={{ fontWeight: 700, color: 'var(--primary-color)' }}>{loadingState.percent}%</span>
                </div>
              </>
            )}

            {/* Scanning phase: show animated dots instead of progress bar */}
            {loadingState.phase === 'scanning' && (
              <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', marginTop: '4px' }}>
                {[0, 1, 2].map(i => (
                  <div key={i} style={{
                    width: '8px',
                    height: '8px',
                    borderRadius: '50%',
                    background: 'rgba(175, 82, 222, 0.8)',
                    animation: `scanDot 1.2s ease-in-out ${i * 0.2}s infinite`
                  }} />
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      <style dangerouslySetInnerHTML={{__html: `
        .table-row-hover:hover {
          background: var(--bg-glass-active) !important;
        }
        .table-row-hover:hover .more-btn {
          color: var(--text-primary) !important;
        }
        .menu-item:hover {
          background: var(--bg-glass-active) !important;
        }
        @keyframes meterPulse {
          0% { transform: scaleY(0.25); }
          100% { transform: scaleY(1); }
        }
        @keyframes scanDot {
          0%, 100% { opacity: 0.2; transform: scale(0.8); }
          50% { opacity: 1; transform: scale(1.2); }
        }
      `}} />
    </div>
  );
};

export default LocalLibrary;
