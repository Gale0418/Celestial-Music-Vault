import React, { useState, useEffect } from 'react';
import { Play, Pause, SkipForward, SkipBack, Minimize2 } from 'lucide-react';
import { useAudio } from '../context/AudioContext';
import defaultCover from '../assets/default-cover.svg';

const ImmersionView = ({ onExit }) => {
  const {
    currentTrack,
    isPlaying,
    togglePlay,
    prevTrack,
    nextTrack,
    progress,
    currentTime,
    duration,
    seekTo
  } = useAudio();

  const [showControls, setShowControls] = useState(true);
  
  // Auto hide controls after 3 seconds of inactivity
  useEffect(() => {
    let timeout;
    const revealControls = () => {
      setShowControls(true);
      clearTimeout(timeout);
      timeout = setTimeout(() => setShowControls(false), 3000);
    };
    const handleKeyDown = (event) => {
      if (event.key === 'Escape') {
        onExit();
        return;
      }
      revealControls();
    };

    window.addEventListener('mousemove', revealControls);
    window.addEventListener('keydown', handleKeyDown);
    revealControls();
    
    return () => {
      window.removeEventListener('mousemove', revealControls);
      window.removeEventListener('keydown', handleKeyDown);
      clearTimeout(timeout);
    };
  }, [onExit]);

  const formatTime = (secs) => {
    if (isNaN(secs)) return '0:00';
    const minutes = Math.floor(secs / 60);
    const seconds = Math.floor(secs % 60);
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  };

  return (
    <div className="immersion-view" style={{
      position: 'fixed',
      top: 0,
      left: 0,
      width: '100vw',
      height: '100vh',
      backgroundColor: 'var(--bg-color-solid)',
      zIndex: 99999,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      alignItems: 'center',
      overflow: 'hidden'
    }}>
      {/* Dynamic Background Blur */}
      {currentTrack?.cover && (
        <div style={{
          position: 'absolute',
          top: '-10%',
          left: '-10%',
          width: '120%',
          height: '120%',
          backgroundImage: `url(${currentTrack.cover})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          filter: 'blur(100px) brightness(0.4)',
          zIndex: 0,
          transition: 'background-image 1s ease-in-out'
        }} />
      )}

      {/* Main Cover Art */}
      <div style={{
        position: 'relative',
        zIndex: 1,
        width: '45vh',
        height: '45vh',
        borderRadius: 'var(--radius-xl)',
        overflow: 'hidden',
        boxShadow: '0 30px 60px rgba(0,0,0,0.6)',
        transition: 'transform 0.5s cubic-bezier(0.2, 0.8, 0.2, 1)',
        transform: isPlaying ? 'scale(1.02)' : 'scale(1)'
      }}>
        <img
          key={currentTrack?.id || 'default-cover'}
          src={currentTrack?.cover || defaultCover}
          onError={(event) => {
            if (event.currentTarget.dataset.fallbackApplied) return;
            event.currentTarget.dataset.fallbackApplied = 'true';
            event.currentTarget.src = defaultCover;
          }}
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
          alt={currentTrack?.title ? `${currentTrack.title} 封面` : '預設唱片封面'}
        />
      </div>

      {/* Song Info */}
      <div style={{
        position: 'relative',
        zIndex: 1,
        marginTop: '40px',
        textAlign: 'center'
      }}>
        <h1 style={{ 
          fontSize: '36px', 
          fontWeight: 800, 
          color: 'var(--text-primary)',
          marginBottom: '10px',
          textShadow: '0 4px 12px rgba(0,0,0,0.5)'
        }}>
          {currentTrack?.title || 'No Track Playing'}
        </h1>
        <p style={{ 
          fontSize: '18px', 
          color: 'rgba(255,255,255,0.7)',
          textShadow: '0 2px 8px rgba(0,0,0,0.5)'
        }}>
          {currentTrack?.artist || 'Unknown Artist'}
        </p>
      </div>

      {/* Controls Overlay */}
      <div style={{
        position: 'absolute',
        bottom: 0,
        left: 0,
        width: '100%',
        padding: '40px 10%',
        background: 'linear-gradient(to top, rgba(0,0,0,0.8) 0%, transparent 100%)',
        zIndex: 2,
        opacity: showControls ? 1 : 0,
        transition: 'opacity 0.5s ease',
        display: 'flex',
        flexDirection: 'column',
        gap: '20px'
      }}>
        
        {/* Progress */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px', color: 'rgba(255,255,255,0.7)', fontSize: '13px' }}>
          <span>{formatTime(currentTime)}</span>
          <input
            type="range"
            min="0"
            max="100"
            value={progress}
            onChange={(e) => seekTo(parseFloat(e.target.value))}
            style={{ flex: 1, height: '4px', accentColor: 'var(--primary-color)' }}
          />
          <span>{formatTime(duration)}</span>
        </div>

        {/* Buttons */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '32px' }}>
          <button onClick={prevTrack} aria-label="上一首" style={iconBtnStyle}><SkipBack size={28} /></button>
          
          <button 
            onClick={togglePlay}
            aria-label={isPlaying ? '暫停' : '播放'}
            style={{
              ...iconBtnStyle,
              background: 'rgba(255,255,255,0.2)',
              padding: '16px',
              borderRadius: '50%',
              backdropFilter: 'blur(10px)'
            }}
          >
            {isPlaying ? <Pause size={32} fill="#fff" /> : <Play size={32} fill="#fff" style={{ marginLeft: '4px' }}/>}
          </button>
          
          <button onClick={nextTrack} aria-label="下一首" style={iconBtnStyle}><SkipForward size={28} /></button>
        </div>

        {/* Top Right Exit Button */}
        <button 
          onClick={onExit}
          aria-label="退出沉浸模式"
          style={{
            position: 'fixed',
            top: '24px',
            right: '40px',
            ...iconBtnStyle,
            background: 'rgba(255,255,255,0.1)',
            padding: '12px',
            borderRadius: '50%',
            backdropFilter: 'blur(10px)'
          }}
          title="退出沉浸模式"
        >
          <Minimize2 size={24} />
        </button>
      </div>
    </div>
  );
};

const iconBtnStyle = {
  border: 'none',
  background: 'transparent',
  color: 'var(--text-primary)',
  cursor: 'pointer',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  outline: 'none',
  transition: 'transform 0.2s',
  opacity: 0.9
};

export default ImmersionView;
