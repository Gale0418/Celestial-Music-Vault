import React from 'react';
import { PlayCircle, HardDrive, Activity, Music2, PlusCircle, Radio, Heart } from 'lucide-react';
import { useAudio } from '../context/AudioContext';

const Sidebar = ({ activeTab, setActiveTab }) => {
  const { isVisualizerActive, setIsVisualizerActive } = useAudio();

  const navItems = [
    { id: 'listen-now', label: '現在收聽', icon: PlayCircle },
    { id: 'local-library', label: '本地音樂庫', icon: HardDrive },
    { id: 'visualizer', label: '音頻視覺化', icon: Activity },
  ];

  const secondaryItems = [
    { id: 'favorites', label: '我的最愛', icon: Heart, disabled: true },
    { id: 'radio', label: '廣播電台', icon: Radio, disabled: true },
  ];

  const dummyPlaylists = [
    '🎧 Lofi Chill Beats',
    '💻 Code & Focus Flow',
    '🌧️ Ambient Rain Sleep',
    '🌅 Retro Synthwave Boulevard',
  ];

  const handleNavClick = (tabId) => {
    setActiveTab(tabId);
    if (tabId === 'visualizer') {
      setIsVisualizerActive(true);
    } else {
      setIsVisualizerActive(false);
    }
  };

  return (
    <aside className="glass-effect" style={{
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
        
        {secondaryItems.map((item) => {
          const Icon = item.icon;
          return (
            <div
              key={item.id}
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
                opacity: 0.6,
                cursor: 'not-allowed'
              }}
            >
              <Icon size={18} />
              <span>{item.label}</span>
            </div>
          );
        })}
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
          <PlusCircle size={14} style={{ color: 'var(--text-muted)', cursor: 'pointer' }} />
        </div>

        {dummyPlaylists.map((pl, idx) => (
          <div
            key={idx}
            style={{
              padding: '8px 12px',
              borderRadius: '8px',
              fontSize: '13px',
              color: 'var(--text-secondary)',
              cursor: 'pointer',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              transition: 'color 0.2s'
            }}
            onMouseEnter={(e) => e.target.style.color = '#fff'}
            onMouseLeave={(e) => e.target.style.color = 'var(--text-secondary)'}
          >
            {pl}
          </div>
        ))}
      </div>

      {/* Embedded Styles for hover support */}
      <style dangerouslySetInnerHTML={{__html: `
        .sidebar-item-hover:hover {
          background: rgba(255, 255, 255, 0.04) !important;
          color: #fff !important;
        }
      `}} />
    </aside>
  );
};

export default Sidebar;
