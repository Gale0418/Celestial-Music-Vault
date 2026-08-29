import React, { useLayoutEffect, useMemo, useState } from 'react';
import { AudioProvider, useAudio } from './context/AudioContext';
import Sidebar from './components/Sidebar';
import PlaybackBar from './components/PlaybackBar';
import ListenNow from './components/ListenNow';
import LocalLibrary from './components/LocalLibrary';
import MiniPlayer from './components/MiniPlayer';
import ImmersionView from './components/ImmersionView';
import { DEFAULT_THEME, getTheme, normalizeThemeId } from './theme';

const THEME_STORAGE_KEY = 'cmv-theme';

const getInitialTheme = () => {
  try {
    return normalizeThemeId(localStorage.getItem(THEME_STORAGE_KEY));
  } catch {
    return DEFAULT_THEME;
  }
};

// Content component that consumes AudioContext
const AppContent = () => {
  const [activeTab, setActiveTab] = useState('listen-now');
  const [viewMode, setViewMode] = useState('default'); // 'default', 'mini', 'immersion'
  const [themeId, setThemeId] = useState(getInitialTheme);
  const { currentTrack } = useAudio();

  // Dynamic colors matching currently playing track for Ambient Flow Background
  const selectedTheme = useMemo(() => getTheme(themeId), [themeId]);
  const currentColors = currentTrack?.colors || selectedTheme.ambient;

  useLayoutEffect(() => {
    document.documentElement.dataset.theme = themeId;
    try {
      localStorage.setItem(THEME_STORAGE_KEY, themeId);
    } catch {
      // The selected theme still works for this session when storage is unavailable.
    }
  }, [themeId]);

  const handleToggleMini = () => {
    const newMode = viewMode === 'mini' ? 'default' : 'mini';
    setViewMode(newMode);
    if (window.electronAPI?.toggleMiniPlayer) {
      window.electronAPI.toggleMiniPlayer(newMode === 'mini');
    }
  };

  const handleToggleImmersion = () => {
    const newMode = viewMode === 'immersion' ? 'default' : 'immersion';
    setViewMode(newMode);
    if (window.electronAPI?.toggleFullscreen) {
      window.electronAPI.toggleFullscreen(newMode === 'immersion');
    }
  };

  // Render different views based on mode
  if (viewMode === 'mini') {
    return <MiniPlayer onExit={handleToggleMini} />;
  }

  if (viewMode === 'immersion') {
    return (
      <>
        <ImmersionView onExit={handleToggleImmersion} />
        {/* We keep the ambient background behind just in case, but it's covered */}
      </>
    );
  }

  return (
    <div className="ambient-bg-container">
      {/* Subtle ambient light follows the current track without competing with content. */}
      <div 
        className="ambient-blob blob-1"
        style={{
          background: `radial-gradient(circle, ${currentColors[0]} 0%, transparent 70%)`,
          transition: 'background 4s ease-in-out'
        }}
      />
      <div 
        className="ambient-blob blob-2"
        style={{
          background: `radial-gradient(circle, ${currentColors[1]} 0%, transparent 70%)`,
          transition: 'background 4s ease-in-out'
        }}
      />
      {/* Main Mac OS Simulator Frame */}
      <div className="mac-app-frame">
        {/* Native Electron Draggable Titlebar Area (enables double-click to maximize!) */}
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: '40px',
          WebkitAppRegion: 'drag',
          zIndex: 9999,
        }} />

        {/* Inner App Content */}
        <div className="app-container">
          <Sidebar
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            themeId={themeId}
            onThemeChange={(nextTheme) => setThemeId(normalizeThemeId(nextTheme))}
          />
          
          <main className="main-stage" style={{
            flex: 1,
            height: '100%',
            overflow: 'hidden',
            position: 'relative',
            display: 'flex',
            flexDirection: 'column'
          }}>
            {/* View switching panel */}
            {activeTab === 'listen-now' && <ListenNow />}
            {activeTab === 'local-library' && <LocalLibrary />}
          </main>
        </div>

        {/* Playback Control Bar */}
        <PlaybackBar 
          activeTab={activeTab} 
          setActiveTab={setActiveTab} 
          onToggleMini={handleToggleMini}
          onToggleImmersion={handleToggleImmersion}
        />
      </div>
    </div>
  );
};

// Global App wrapper with Provider
function App() {
  return (
    <AudioProvider>
      <AppContent />
    </AudioProvider>
  );
}

export default App;
