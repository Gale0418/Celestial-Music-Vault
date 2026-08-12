import React, { useState } from 'react';
import { PlayCircle, HardDrive, Music2, PlusCircle, Radio, Heart, Trash2, Palette } from 'lucide-react';
import { useAudio } from '../context/AudioContext';
import { THEME_OPTIONS } from '../theme';

const Sidebar = ({ activeTab, setActiveTab, themeId, onThemeChange }) => {
  const [isCreatingPlaylist, setIsCreatingPlaylist] = useState(false);
  const [newPlaylistName, setNewPlaylistName] = useState('');
  const { 
    playlists,
    activeView,
    setActiveView,
    createPlaylist,
    deletePlaylist
  } = useAudio();

  const navItems = [
    { id: 'listen-now', label: '現在收聽', icon: PlayCircle },
    { id: 'local-library', label: '本地音樂庫', icon: HardDrive },
  ];

  const handleNavClick = (tabId) => {
    setActiveTab(tabId);
    if (tabId === 'local-library') {
      setActiveView('library');
    }
  };

  const handleViewClick = (viewId) => {
    setActiveTab('local-library');
    setActiveView(viewId);
  };

  const handleCreatePlaylistClick = (e) => {
    e.stopPropagation();
    setIsCreatingPlaylist(true);
    setNewPlaylistName(`我的歌單 ${playlists.length + 1}`);
  };

  const submitNewPlaylist = () => {
    if (newPlaylistName.trim()) {
      const pl = createPlaylist(newPlaylistName.trim());
      handleViewClick(`playlist-${pl.id}`);
    }
    setIsCreatingPlaylist(false);
    setNewPlaylistName('');
  };

  return (
    <aside className="glass-effect app-sidebar" style={{
      width: 'var(--sidebar-width)',
      height: '100%',
      display: 'flex',
      flexDirection: 'column',
      borderRight: '1px solid var(--border-glass)',
      paddingTop: '50px', // leave room for macOS dots
      paddingBottom: '20px',
      position: 'relative',
      zIndex: 10
    }}>
      {/* Brand title */}
      <div style={{
        padding: '0 20px',
        marginBottom: '28px',
        display: 'flex',
        alignItems: 'center',
        gap: '10px'
      }}>
        <div style={{
          background: 'var(--primary-gradient)',
          width: '32px',
          height: '32px',
          borderRadius: '8px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: '0 4px 12px rgba(255, 59, 48, 0.3)'
        }}>
          <Music2 size={18} color="#fff" />
        </div>
        <span style={{
          fontFamily: 'var(--font-display)',
          fontWeight: 800,
          fontSize: '19px',
          letterSpacing: '-0.5px',
          background: 'linear-gradient(to right, #fff, #86868b)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent'
        }}>
          AeroMusic
        </span>
      </div>

      {/* Main navigation */}
      <div style={{ padding: '0 12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <p style={{
          fontSize: '11px',
          fontWeight: 700,
          color: 'var(--text-muted)',
          paddingLeft: '12px',
          marginBottom: '6px',
          textTransform: 'uppercase',
          letterSpacing: '1px'
        }}>
          推薦選單
        </p>
        
        {navItems.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => handleNavClick(item.id)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '12px',
                width: '100%',
                padding: '10px 14px',
                borderRadius: '10px',
                border: 'none',
                background: isActive ? 'var(--bg-glass-active)' : 'transparent',
                color: isActive ? '#fff' : 'var(--text-secondary)',
                fontSize: '14px',
                fontWeight: isActive ? 600 : 500,
                textAlign: 'left',
                cursor: 'pointer',
                transition: 'all 0.2s ease',
                borderLeft: isActive ? '3px solid var(--primary-color)' : '3px solid transparent',
                outline: 'none'
              }}
              className={!isActive ? 'sidebar-item-hover' : ''}
              id={`sidebar-nav-${item.id}`}
            >
              <Icon size={18} color={isActive ? 'var(--primary-color)' : 'inherit'} />
              <span>{item.label}</span>
            </button>
          );
        })}
      </div>

      {/* Separator */}
      <hr style={{
        border: 'none',
        borderTop: '1px solid rgba(255, 255, 255, 0.05)',
        margin: '20px 20px'
      }} />

      {/* Secondary navigation */}
      <div style={{ padding: '0 12px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <p style={{
          fontSize: '11px',
          fontWeight: 700,
          color: 'var(--text-muted)',
          paddingLeft: '12px',
          marginBottom: '6px',
          textTransform: 'uppercase',
          letterSpacing: '1px'
        }}>
          我的收藏庫
        </p>

        {/* Permanent My Library Link */}
        <button
          onClick={() => handleViewClick('library')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            width: '100%',
            padding: '10px 14px',
            borderRadius: '10px',
            border: 'none',
            background: (activeTab === 'local-library' && activeView === 'library') ? 'var(--bg-glass-active)' : 'transparent',
            color: (activeTab === 'local-library' && activeView === 'library') ? '#fff' : 'var(--text-secondary)',
            fontSize: '14px',
            fontWeight: (activeTab === 'local-library' && activeView === 'library') ? 600 : 500,
            textAlign: 'left',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            borderLeft: (activeTab === 'local-library' && activeView === 'library') ? '3px solid var(--primary-color)' : '3px solid transparent',
            outline: 'none'
          }}
          className={(activeTab !== 'local-library' || activeView !== 'library') ? 'sidebar-item-hover' : ''}
        >
          <HardDrive size={18} color={(activeTab === 'local-library' && activeView === 'library') ? 'var(--primary-color)' : 'inherit'} />
          <span>我的音樂庫</span>
        </button>
        
        {/* Persistent Favorites Link */}
        <button
          onClick={() => handleViewClick('favorites')}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            width: '100%',
            padding: '10px 14px',
            borderRadius: '10px',
            border: 'none',
            background: (activeTab === 'local-library' && activeView === 'favorites') ? 'var(--bg-glass-active)' : 'transparent',
            color: (activeTab === 'local-library' && activeView === 'favorites') ? '#fff' : 'var(--text-secondary)',
            fontSize: '14px',
            fontWeight: (activeTab === 'local-library' && activeView === 'favorites') ? 600 : 500,
            textAlign: 'left',
            cursor: 'pointer',
            transition: 'all 0.2s ease',
            borderLeft: (activeTab === 'local-library' && activeView === 'favorites') ? '3px solid var(--primary-color)' : '3px solid transparent',
            outline: 'none'
          }}
          className={(activeTab !== 'local-library' || activeView !== 'favorites') ? 'sidebar-item-hover' : ''}
        >
          <Heart size={18} color={(activeTab === 'local-library' && activeView === 'favorites') ? 'var(--primary-color)' : 'inherit'} fill={(activeTab === 'local-library' && activeView === 'favorites') ? 'var(--primary-color)' : 'transparent'} />
          <span>我的最愛</span>
        </button>

        {/* radio decorative item */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            width: '100%',
            padding: '10px 14px',
            borderRadius: '10px',
            color: 'var(--text-muted)',
            fontSize: '14px',
            fontWeight: 500,
            textAlign: 'left',
            opacity: 0.5,
            cursor: 'not-allowed'
          }}
        >
          <Radio size={18} />
          <span>廣播電台</span>
        </div>
      </div>

      {/* Separator */}
      <hr style={{
        border: 'none',
        borderTop: '1px solid rgba(255, 255, 255, 0.05)',
        margin: '20px 20px'
      }} />

      {/* Playlists */}
      <div style={{ 
        padding: '0 12px', 
        display: 'flex', 
        flexDirection: 'column', 
        gap: '4px',
        flex: 1,
        overflowY: 'auto'
      }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          paddingRight: '8px',
          marginBottom: '6px'
        }}>
          <p style={{
            fontSize: '11px',
            fontWeight: 700,
            color: 'var(--text-muted)',
            paddingLeft: '12px',
            textTransform: 'uppercase',
            letterSpacing: '1px'
          }}>
            播放清單
          </p>
          <button
            onClick={handleCreatePlaylistClick}
            aria-label="建立新歌單"
            style={{ border: 'none', background: 'transparent', padding: 0, outlineOffset: '2px' }}
            className="add-playlist-btn"
          >
            <PlusCircle
              size={15}
              style={{ color: 'var(--text-muted)', cursor: 'pointer', transition: 'color 0.2s' }}
            />
          </button>
        </div>

        {playlists.length === 0 && !isCreatingPlaylist ? (
          <div style={{ padding: '8px 12px', fontSize: '12px', color: 'var(--text-muted)', fontStyle: 'italic' }}>
            點擊 + 建立新歌單
          </div>
        ) : null}

        {isCreatingPlaylist && (
          <div style={{ padding: '8px 12px', display: 'flex', gap: '8px', alignItems: 'center' }}>
            <input
              type="text"
              autoFocus
              value={newPlaylistName}
              onChange={(e) => setNewPlaylistName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') submitNewPlaylist();
                if (e.key === 'Escape') setIsCreatingPlaylist(false);
              }}
              onBlur={submitNewPlaylist}
              style={{
                width: '100%',
                background: 'rgba(0,0,0,0.2)',
                border: '1px solid rgba(255,255,255,0.1)',
                color: '#fff',
                borderRadius: '6px',
                padding: '4px 8px',
                fontSize: '12px',
                outline: 'none'
              }}
            />
          </div>
        )}

        {playlists.map((pl) => {
          const isPlActive = activeTab === 'local-library' && activeView === `playlist-${pl.id}`;
          return (
              <div
                key={pl.id}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  padding: '8px 12px',
                  borderRadius: '8px',
                  fontSize: '13px',
                  background: isPlActive ? 'rgba(255, 255, 255, 0.04)' : 'transparent',
                  color: isPlActive ? '#fff' : 'var(--text-secondary)',
                  fontWeight: isPlActive ? 600 : 500,
                  transition: 'all 0.2s',
                  position: 'relative'
                }}
                className="playlist-sidebar-item"
              >
                <button
                  onClick={() => handleViewClick(`playlist-${pl.id}`)}
                  aria-label={`檢視歌單 ${pl.name}`}
                  style={{
                    border: 'none',
                    background: 'transparent',
                    color: 'inherit',
                    fontFamily: 'inherit',
                    fontSize: 'inherit',
                    fontWeight: 'inherit',
                    textAlign: 'left',
                    cursor: 'pointer',
                    flex: 1,
                    overflow: 'hidden',
                    whiteSpace: 'nowrap',
                    textOverflow: 'ellipsis',
                    padding: 0,
                    outlineOffset: '2px'
                  }}
                  className="playlist-btn"
                >
                  <span style={{ paddingRight: '8px' }}>
                    {pl.name}
                  </span>
                </button>

                {/* Delete button (Trash icon) */}
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    if (window.confirm(`確定要刪除播放清單 "${pl.name}" 嗎？`)) {
                      deletePlaylist(pl.id);
                    }
                  }}
                  aria-label={`刪除歌單 ${pl.name}`}
                  style={{ border: 'none', background: 'transparent', padding: 0, outlineOffset: '2px' }}
                  className="delete-btn"
                >
                  <Trash2
                    size={12}
                    color="rgba(255,255,255,0.3)"
                    style={{ cursor: 'pointer', transition: 'color 0.2s' }}
                  />
                </button>
              </div>
            );
          })}
      </div>

      <section className="theme-switcher" aria-labelledby="theme-switcher-title">
        <div className="theme-switcher-heading">
          <Palette size={14} aria-hidden="true" />
          <span id="theme-switcher-title">畫風</span>
        </div>
        <div className="theme-options" role="radiogroup" aria-label="選擇介面畫風">
          {THEME_OPTIONS.map((theme) => {
            const isSelected = theme.id === themeId;
            return (
              <button
                key={theme.id}
                type="button"
                className={`theme-option${isSelected ? ' is-selected' : ''}`}
                role="radio"
                aria-checked={isSelected}
                aria-label={`${theme.name}：${theme.description}`}
                title={`${theme.name}｜${theme.description}`}
                onClick={() => onThemeChange(theme.id)}
              >
                <span
                  className="theme-swatch"
                  aria-hidden="true"
                  style={{ background: `linear-gradient(135deg, ${theme.swatches[0]} 50%, ${theme.swatches[1]} 50%)` }}
                />
                <span className="theme-option-label" aria-hidden="true">{theme.name}</span>
              </button>
            );
          })}
        </div>
        <p className="theme-current-name">
          {THEME_OPTIONS.find((theme) => theme.id === themeId)?.name}
        </p>
      </section>

      {/* Embedded Styles for hover support */}
      <style dangerouslySetInnerHTML={{__html: `
        .sidebar-item-hover:hover {
          background: rgba(255, 255, 255, 0.04) !important;
          color: #fff !important;
        }
        .add-playlist-btn:hover {
          color: #fff !important;
        }
        .playlist-sidebar-item:hover {
          background: rgba(255, 255, 255, 0.03) !important;
          color: #fff !important;
        }
        .playlist-sidebar-item:hover .delete-playlist-icon {
          display: block !important;
        }
        .delete-playlist-icon:hover {
          color: var(--primary-color) !important;
        }
        .playlist-btn:focus-visible, .add-playlist-btn:focus-visible, .delete-btn:focus-visible {
          outline: 2px solid var(--primary-color);
        }
      `}} />
    </aside>
  );
};

export default Sidebar;
