import React, { useState } from 'react';
import { 
  Play, Pause, SkipForward, SkipBack, Shuffle, Repeat, Repeat1,
  Volume2, VolumeX, Sliders, Heart,
  Video, VideoOff, Timer, Ban, Maximize, PictureInPicture2, Star
} from 'lucide-react';
import { useAudio } from '../context/AudioContext';
import defaultCover from '../assets/default-cover.svg';

const PlaybackBar = ({ onToggleMini, onToggleImmersion }) => {
  const {
    currentTrack,
    isPlaying,
    progress,
    currentTime,
    duration,
    volume,
    isMuted,
    isShuffle,
    isRepeat,
    eqPreset,
    setEqPreset,
    togglePlay,
    prevTrack,
    nextTrack,
    seekTo,
    setVolume,
    toggleMute,
    toggleShuffle,
    cycleRepeat,
    showVideo,
    hasVideoTrack,
    setShowVideo,
    favorites,
    toggleFavorite,
    sleepTimerEndsAt,
    setSleepTimerEndsAt,
    dislikedTracks,
    toggleDislike,
    trackRatings,
    setTrackRating
  } = useAudio();

  const [showEqMenu, setShowEqMenu] = useState(false);
  const [showTimerMenu, setShowTimerMenu] = useState(false);
  const isFavorite = currentTrack ? favorites.some(f => f.id === currentTrack.id) : false;
  const isDisliked = currentTrack ? dislikedTracks.includes(currentTrack.id) : false;
  const currentRating = currentTrack ? (trackRatings[currentTrack.id] || 0) : 0;

  const setTimer = (mins) => {
    if (mins === 0) {
      setSleepTimerEndsAt(null);
    } else {
      setSleepTimerEndsAt(Date.now() + mins * 60 * 1000);
    }
    setShowTimerMenu(false);
  };

  const getTimerText = () => {
    if (!sleepTimerEndsAt) return null;
    const diff = Math.max(0, Math.floor((sleepTimerEndsAt - Date.now()) / 1000 / 60));
    return `${diff}m`;
  };

  // Format seconds to mm:ss
  const formatTime = (secs) => {
    if (isNaN(secs)) return '0:00';
    const minutes = Math.floor(secs / 60);
    const seconds = Math.floor(secs % 60);
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  };

  const handleSeekChange = (e) => {
    seekTo(parseFloat(e.target.value));
  };

  const handleVolumeSliderChange = (e) => {
    setVolume(parseFloat(e.target.value));
  };

  const eqPresets = ['Flat', 'Bass Boost', 'Vocal', 'Electronic'];

  return (
    <footer className="glass-effect" style={{
      height: 'var(--playback-bar-height)',
      width: '100%',
      borderTop: '1px solid var(--border-glass)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 24px',
      position: 'relative',
      zIndex: 100,
      backgroundColor: 'rgba(18, 20, 26, 0.9)',
      boxShadow: '0 -10px 30px rgba(0,0,0,0.4)'
    }} id="playback-bar">
      
      {/* LEFT: Current Track Details */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '14px', width: '30%', minWidth: '220px' }}>
        <div style={{ position: 'relative', width: '52px', height: '52px' }}>
          <img
            src={currentTrack?.cover || defaultCover}
            onError={(event) => { event.currentTarget.src = defaultCover; }}
            alt={currentTrack?.title}
            style={{
              width: '100%',
              height: '100%',
              borderRadius: '50%',
              objectFit: 'cover',
              border: '2px solid rgba(255, 255, 255, 0.1)',
              animation: isPlaying ? 'spin 18s linear infinite' : 'none',
              boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
              transition: 'transform 0.5s ease'
            }}
          />
          {/* Middle spindle hole to make it look like a vinyl record */}
          <div style={{
            position: 'absolute',
            top: '50%',
            left: '50%',
            transform: 'translate(-50%, -50%)',
            width: '10px',
            height: '10px',
            borderRadius: '50%',
            backgroundColor: 'var(--bg-color-solid)',
            border: '1px solid rgba(255, 255, 255, 0.2)'
          }} />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden', gap: '2px', flex: 1 }}>
          <div className="marquee-text-container">
            <span className={currentTrack?.title?.length > 18 ? 'marquee-text' : ''} style={{
              fontWeight: 600,
              fontSize: '14px',
              color: '#fff',
              display: 'inline-block'
            }}>
              {currentTrack?.title}
            </span>
          </div>
          <span style={{
            fontSize: '12px',
            color: 'var(--text-secondary)',
            whiteSpace: 'nowrap',
            overflow: 'hidden',
            textOverflow: 'ellipsis'
          }}>
            {currentTrack?.artist}
          </span>
        </div>

        <button 
          onClick={() => { if (currentTrack) toggleFavorite(currentTrack); }}
          style={{
            border: 'none',
            background: 'transparent',
            cursor: 'pointer',
            padding: '4px',
            color: isFavorite ? 'var(--primary-color)' : 'var(--text-muted)',
            transition: 'transform 0.2s, color 0.2s',
            outline: 'none'
          }}
          onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.2)'}
          onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
          id="favorite-btn"
        >
          <Heart size={16} fill={isFavorite ? 'var(--primary-color)' : 'none'} />
        </button>

        {/* Star Rating */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '2px', marginLeft: '4px' }}>
          {[1, 2, 3, 4, 5].map(star => (
            <button
              key={star}
              onClick={() => {
                if (currentTrack) {
                  // Toggle off if clicking the same rating
                  setTrackRating(currentTrack.id, currentRating === star ? 0 : star);
                }
              }}
              style={{
                border: 'none',
                background: 'transparent',
                cursor: 'pointer',
                padding: '2px',
                color: star <= currentRating ? '#ffcc00' : 'var(--text-muted)',
                outline: 'none',
                transition: 'transform 0.1s'
              }}
              onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.2)'}
              onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
              title={`${star} 顆星`}
            >
              <Star size={14} fill={star <= currentRating ? '#ffcc00' : 'none'} />
            </button>
          ))}
        </div>

        {/* Window Modes (Mini Player / Immersion) */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginLeft: '4px' }}>
          <button
            onClick={onToggleMini}
            style={{
              border: 'none',
              background: 'transparent',
              padding: '6px',
              borderRadius: '6px',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
              transition: 'all 0.2s',
              outline: 'none'
            }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = 'var(--text-secondary)'}
            title="迷你播放器"
          >
            <PictureInPicture2 size={16} />
          </button>
          
          <button
            onClick={onToggleImmersion}
            style={{
              border: 'none',
              background: 'transparent',
              padding: '6px',
              borderRadius: '6px',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
              transition: 'all 0.2s',
              outline: 'none'
            }}
            onMouseEnter={e => e.currentTarget.style.color = '#fff'}
            onMouseLeave={e => e.currentTarget.style.color = 'var(--text-secondary)'}
            title="沉浸全螢幕模式"
          >
            <Maximize size={16} />
          </button>
        </div>

        {/* Dislike button */}
        <button
          onClick={() => currentTrack && toggleDislike(currentTrack.id)}
          disabled={!currentTrack}
          style={{
            border: 'none',
            background: 'transparent',
            cursor: currentTrack ? 'pointer' : 'default',
            color: isDisliked ? '#ff9500' : 'var(--text-secondary)',
            outline: 'none',
            transition: 'transform 0.1s',
            opacity: currentTrack ? 1 : 0.5
          }}
          onMouseDown={(e) => { if(currentTrack) e.currentTarget.style.transform = 'scale(0.8)' }}
          onMouseUp={(e) => { if(currentTrack) e.currentTarget.style.transform = 'scale(1)' }}
          onMouseLeave={(e) => { if(currentTrack) e.currentTarget.style.transform = 'scale(1)' }}
          id="dislike-btn"
          title="隱藏此歌曲"
        >
          <Ban size={16} />
        </button>
      </div>

      {/* MIDDLE: Primary Playback Controls & Progress Slider */}
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: '8px',
        width: '40%',
        maxWidth: '600px'
      }}>
        {/* Buttons */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
          <button
            onClick={toggleShuffle}
            style={{
              background: isShuffle ? 'rgba(255, 45, 85, 0.12)' : 'transparent',
              cursor: 'pointer',
              color: isShuffle ? 'var(--primary-color)' : 'var(--text-secondary)',
              outline: 'none',
              transition: 'all 0.2s cubic-bezier(0.25, 0.8, 0.25, 1)',
              padding: '6px 10px',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: isShuffle ? '0 0 12px rgba(255, 45, 85, 0.25)' : 'none',
              border: isShuffle ? '1px solid rgba(255, 45, 85, 0.25)' : '1px solid transparent'
            }}
            onMouseEnter={(e) => {
              if (!isShuffle) e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
            }}
            onMouseLeave={(e) => {
              if (!isShuffle) e.currentTarget.style.background = 'transparent';
            }}
            title="隨機播放"
            id="shuffle-btn"
          >
            <Shuffle size={16} />
          </button>

          <button
            onClick={prevTrack}
            style={{
              border: 'none',
              background: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-primary)',
              outline: 'none',
              transition: 'transform 0.1s'
            }}
            onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.9)'}
            onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
            title="上一首"
            id="prev-btn"
          >
            <SkipBack size={20} fill="currentColor" />
          </button>

          {/* Central Play/Pause with Circle Gradient Glow */}
          <button
            onClick={togglePlay}
            style={{
              border: 'none',
              background: 'var(--primary-gradient)',
              width: '40px',
              height: '40px',
              borderRadius: '50%',
              cursor: 'pointer',
              color: '#fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 14px var(--primary-glow)',
              outline: 'none',
              transition: 'transform 0.2s, box-shadow 0.2s'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'scale(1.08)';
              e.currentTarget.style.boxShadow = '0 6px 18px var(--primary-glow)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.boxShadow = '0 4px 14px var(--primary-glow)';
            }}
            title={isPlaying ? '暫停' : '播放'}
            id="play-pause-btn"
          >
            {isPlaying ? (
              <Pause size={18} fill="#fff" />
            ) : (
              <Play size={18} fill="#fff" style={{ marginLeft: '2px' }} />
            )}
          </button>

          <button
            onClick={nextTrack}
            style={{
              border: 'none',
              background: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-primary)',
              outline: 'none',
              transition: 'transform 0.1s'
            }}
            onMouseDown={(e) => e.currentTarget.style.transform = 'scale(0.9)'}
            onMouseUp={(e) => e.currentTarget.style.transform = 'scale(1)'}
            title="下一首"
            id="next-btn"
          >
            <SkipForward size={20} fill="currentColor" />
          </button>

          <button
            onClick={cycleRepeat}
            style={{
              background: isRepeat ? 'rgba(255, 45, 85, 0.12)' : 'transparent',
              cursor: 'pointer',
              color: isRepeat ? 'var(--primary-color)' : 'var(--text-secondary)',
              outline: 'none',
              position: 'relative',
              transition: 'all 0.2s cubic-bezier(0.25, 0.8, 0.25, 1)',
              padding: '6px 10px',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: isRepeat ? '0 0 12px rgba(255, 45, 85, 0.25)' : 'none',
              border: isRepeat ? '1px solid rgba(255, 45, 85, 0.25)' : '1px solid transparent'
            }}
            onMouseEnter={(e) => {
              if (!isRepeat) e.currentTarget.style.background = 'rgba(255, 255, 255, 0.05)';
            }}
            onMouseLeave={(e) => {
              if (!isRepeat) e.currentTarget.style.background = 'transparent';
            }}
            title={isRepeat === 'one' ? '單曲循環' : isRepeat ? '全部循環' : '重複播放'}
            id="repeat-btn"
          >
            {isRepeat === 'one' ? <Repeat1 size={16} /> : <Repeat size={16} />}
          </button>
        </div>

        {/* Progress Bar & Timers */}
        <div style={{ display: 'flex', alignItems: 'center', width: '100%', gap: '10px' }}>
          <span style={{ fontSize: '11px', color: 'var(--text-secondary)', minWidth: '32px', textAlign: 'right' }}>
            {formatTime(currentTime)}
          </span>
          
          <input
            type="range"
            min="0"
            max="100"
            value={progress}
            onChange={handleSeekChange}
            style={{ flex: 1 }}
            title="調整進度"
            id="seek-slider"
          />

          <span style={{ fontSize: '11px', color: 'var(--text-secondary)', minWidth: '32px' }}>
            {formatTime(duration)}
          </span>
        </div>
      </div>

      {/* RIGHT: Volume, Equalizer (EQ) Toggle */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'flex-end',
        gap: '16px',
        width: '30%',
        position: 'relative'
      }}>
        
        {/* Sleep Timer */}
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setShowTimerMenu(!showTimerMenu)}
            style={{
              border: 'none',
              background: sleepTimerEndsAt ? 'var(--bg-glass-active)' : 'transparent',
              padding: '6px',
              borderRadius: '6px',
              cursor: 'pointer',
              color: sleepTimerEndsAt ? '#af52de' : 'var(--text-secondary)',
              outline: 'none',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              transition: 'all 0.2s'
            }}
            title="睡眠定時器"
            id="timer-menu-btn"
          >
            <Timer size={16} />
            {sleepTimerEndsAt && <span className="eq-badge" style={{ background: 'linear-gradient(135deg, #af52de, #5856d6)' }}>{getTimerText()}</span>}
          </button>

          {showTimerMenu && (
            <div className="glass-effect" style={{
              position: 'absolute',
              bottom: '45px',
              right: '0',
              borderRadius: '10px',
              padding: '8px',
              display: 'flex',
              flexDirection: 'column',
              gap: '4px',
              width: '120px',
              boxShadow: 'var(--shadow-card)',
              zIndex: 1000
            }}>
              {[
                { label: '關閉定時', value: 0 },
                { label: '15 分鐘', value: 15 },
                { label: '30 分鐘', value: 30 },
                { label: '60 分鐘', value: 60 }
              ].map(opt => (
                <button
                  key={opt.label}
                  onClick={() => setTimer(opt.value)}
                  style={{
                    border: 'none',
                    padding: '8px 12px',
                    borderRadius: '6px',
                    textAlign: 'left',
                    background: 'transparent',
                    color: '#fff',
                    fontSize: '12px',
                    cursor: 'pointer',
                    transition: 'all 0.15s'
                  }}
                  onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(255,255,255,0.05)'}
                  onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
                >
                  {opt.label}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Equalizer Controller */}
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setShowEqMenu(!showEqMenu)}
            style={{
              border: 'none',
              background: showEqMenu ? 'var(--bg-glass-active)' : 'transparent',
              padding: '6px',
              borderRadius: '6px',
              cursor: 'pointer',
              color: eqPreset !== 'Flat' ? 'var(--primary-color)' : 'var(--text-secondary)',
              outline: 'none',
              display: 'flex',
              alignItems: 'center',
              gap: '4px',
              transition: 'all 0.2s'
            }}
            title="等化器 (EQ)"
            id="eq-menu-btn"
          >
            <Sliders size={16} />
            {eqPreset !== 'Flat' && <span className="eq-badge">{eqPreset}</span>}
          </button>

          {showEqMenu && (
            <div className="glass-effect" style={{
              position: 'absolute',
              bottom: '45px',
              right: '0',
              borderRadius: '10px',
              padding: '8px',
              width: '130px',
              display: 'flex',
              flexDirection: 'column',
              gap: '4px',
              boxShadow: 'var(--shadow-window)'
            }}>
              {eqPresets.map((preset) => (
                <button
                  key={preset}
                  onClick={() => {
                    setEqPreset(preset);
                    setShowEqMenu(false);
                  }}
                  style={{
                    padding: '8px 10px',
                    borderRadius: '6px',
                    border: 'none',
                    textAlign: 'left',
                    background: eqPreset === preset ? 'var(--bg-glass-active)' : 'transparent',
                    color: eqPreset === preset ? 'var(--primary-color)' : '#fff',
                    fontSize: '12px',
                    fontWeight: eqPreset === preset ? 600 : 500,
                    cursor: 'pointer',
                    transition: 'all 0.15s'
                  }}
                  onMouseEnter={(e) => {
                    if (eqPreset !== preset) e.currentTarget.style.background = 'rgba(255,255,255,0.05)';
                  }}
                  onMouseLeave={(e) => {
                    if (eqPreset !== preset) e.currentTarget.style.background = 'transparent';
                  }}
                >
                  {preset === 'Flat' ? '標準 (Flat)' : preset}
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Video Toggle for MP4 files */}
        {hasVideoTrack && (
          <button
            onClick={() => setShowVideo(!showVideo)}
            style={{
              background: showVideo ? 'rgba(255, 45, 85, 0.15)' : 'transparent',
              padding: '6px',
              borderRadius: '6px',
              cursor: 'pointer',
              color: showVideo ? '#ff2d55' : 'var(--text-secondary)',
              outline: 'none',
              transition: 'all 0.2s',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              border: showVideo ? '1px solid rgba(255, 45, 85, 0.3)' : '1px solid transparent'
            }}
            title={showVideo ? "隱藏影片畫面" : "顯示影片畫面"}
            id="video-toggle-btn"
          >
            {showVideo ? <Video size={17} /> : <VideoOff size={17} />}
          </button>
        )}

        {/* Volume Slider & Mute Icon */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={toggleMute}
            style={{
              border: 'none',
              background: 'transparent',
              cursor: 'pointer',
              color: 'var(--text-secondary)',
              outline: 'none',
              padding: '2px',
              transition: 'color 0.2s'
            }}
            id="mute-btn"
          >
            {isMuted ? <VolumeX size={17} /> : <Volume2 size={17} />}
          </button>
          
          <input
            type="range"
            min="0"
            max="1"
            step="0.05"
            value={isMuted ? 0 : volume}
            onChange={handleVolumeSliderChange}
            style={{ width: '70px' }}
            title="音量"
            id="volume-slider"
          />
        </div>
      </div>

      <style dangerouslySetInnerHTML={{__html: `
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}} />
    </footer>
  );
};

export default PlaybackBar;
