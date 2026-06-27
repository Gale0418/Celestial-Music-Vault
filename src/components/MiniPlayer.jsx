import React from 'react';
import { Play, Pause, SkipForward, SkipBack, Maximize2 } from 'lucide-react';
import { useAudio } from '../context/AudioContext';

const MiniPlayer = ({ onExit }) => {
  const {
    currentTrack,
    isPlaying,
    togglePlay,
    prevTrack,
    nextTrack,
    progress
  } = useAudio();

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'row',
      alignItems: 'center',
      height: '100%',
      width: '100%',
      padding: '12px',
      background: 'rgba(18, 20, 26, 0.95)',
      boxShadow: 'var(--shadow-card)',
      WebkitAppRegion: 'drag', // Make whole mini player draggable
      position: 'relative',
      overflow: 'hidden'
    }}>
      {/* Background Blur of Current Track */}
      {currentTrack?.cover && (
        <div style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          backgroundImage: `url(${currentTrack.cover})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          filter: 'blur(30px)',
          opacity: 0.3,
          zIndex: 0
        }} />
      )}

      {/* Progress Bar (Top Edge) */}
      <div style={{
        position: 'absolute',
        top: 0,
        left: 0,
        height: '3px',
        width: `${progress}%`,
        background: 'var(--primary-color)',
        zIndex: 2,
        transition: 'width 0.1s linear'
      }} />

      <div style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'center', width: '100%', gap: '12px' }}>
        {/* Cover Art */}
        <div style={{
          width: '64px',
          height: '64px',
          borderRadius: '8px',
          overflow: 'hidden',
          flexShrink: 0,
          boxShadow: '0 4px 12px rgba(0,0,0,0.5)'
        }}>
          <img 
            src={currentTrack?.cover || 'https://via.placeholder.com/64'} 
            style={{ width: '100%', height: '100%', objectFit: 'cover' }} 
            alt="cover" 
          />
        </div>

        {/* Track Info */}
        <div style={{ flex: 1, minWidth: 0 }}>
          <h4 style={{ 
            fontSize: '14px', 
            fontWeight: 700, 
            color: '#fff', 
            whiteSpace: 'nowrap', 
            overflow: 'hidden', 
            textOverflow: 'ellipsis',
            marginBottom: '4px'
          }}>
            {currentTrack?.title || 'No Track Playing'}
          </h4>
          <p style={{ 
            fontSize: '11px', 
            color: 'var(--text-secondary)',
            whiteSpace: 'nowrap', 
            overflow: 'hidden', 
            textOverflow: 'ellipsis'
          }}>
            {currentTrack?.artist || 'Unknown Artist'}
          </p>
        </div>

        {/* Controls */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          WebkitAppRegion: 'no-drag' // Buttons need to be clickable
        }}>
          <button onClick={prevTrack} style={btnStyle}><SkipBack size={16} /></button>
          
          <button 
            onClick={togglePlay} 
            style={{ ...btnStyle, background: 'rgba(255,255,255,0.1)', padding: '8px', borderRadius: '50%' }}
          >
            {isPlaying ? <Pause size={16} fill="#fff" /> : <Play size={16} fill="#fff" style={{ marginLeft: '2px' }}/>}
          </button>
          
          <button onClick={nextTrack} style={btnStyle}><SkipForward size={16} /></button>

          {/* Exit Mini Player */}
          <button 
            onClick={onExit} 
            style={{ ...btnStyle, marginLeft: '8px' }}
            title="回到主畫面"
          >
            <Maximize2 size={14} />
          </button>
        </div>
      </div>
    </div>
  );
};

const btnStyle = {
  border: 'none',
  background: 'transparent',
  color: '#fff',
  cursor: 'pointer',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  outline: 'none',
  transition: 'transform 0.1s'
};

export default MiniPlayer;
