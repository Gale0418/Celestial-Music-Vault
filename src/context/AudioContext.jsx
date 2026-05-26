import React, { createContext, useContext, useState, useEffect, useRef } from 'react';

const AudioContext = createContext();

// Pre-loaded premium royalty-free streams with CORS enabled
const DEFAULT_PLAYLIST = [
  {
    id: 'lofi-1',
    title: 'Aero Space Chill',
    artist: 'Lofi Dreamer',
    album: 'Cosmic Beats Vol. 1',
    cover: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80', // Beautiful dynamic 3D abstract art
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    colors: ['#ff2d55', '#af52de', '#007aff'],
    duration: '6:12'
  },
  {
    id: 'lofi-2',
    title: 'Midnight Coding',
    artist: 'Synth Wave Girl',
    album: 'Neon Cyberpunk',
    cover: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=400&q=80', // Dark neon grid
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    colors: ['#007aff', '#34c759', '#af52de'],
    duration: '7:05'
  },
  {
    id: 'lofi-3',
    title: 'Morning Matcha',
    artist: 'Coffee & Books',
    album: 'Cafe Study Sessions',
    cover: 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=400&q=80', // Warm coffee aesthetic
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    colors: ['#ff9500', '#ffcc00', '#34c759'],
    duration: '5:44'
  },
  {
    id: 'lofi-4',
    title: 'Rainy Afternoon',
    artist: 'Tokyo Rain',
    album: 'City Lights Ambient',
    cover: 'https://images.unsplash.com/photo-1534274988757-a28bf1a57c17?w=400&q=80', // Rainy aesthetic
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    colors: ['#007aff', '#5856d6', '#ff2d55'],
    duration: '5:02'
  },
  {
    id: 'lofi-5',
    title: 'Sunset Boulevard',
    artist: 'Retro Horizon',
    album: 'Dreamwave Rides',
    cover: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=400&q=80', // Retro synthwave sunset
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    colors: ['#ff2d55', '#ff9500', '#af52de'],
    duration: '6:03'
  }
];

export const AudioProvider = ({ children }) => {
  const [playlist, setPlaylist] = useState(DEFAULT_PLAYLIST);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0); // 0 to 100
  const [currentTime, setCurrentTime] = useState(0); // in seconds
  const [duration, setDuration] = useState(0); // in seconds
  const [volume, setVolume] = useState(0.8);
  const [isMuted, setIsMuted] = useState(false);
  const [isShuffle, setIsShuffle] = useState(false);
  const [isRepeat, setIsRepeat] = useState(false); // false: no, true: repeat queue, 'one': repeat track
  const [eqPreset, setEqPreset] = useState('Flat'); // Flat, Bass Boost, Vocal, Electronic
  const [isVisualizerActive, setIsVisualizerActive] = useState(false);
  const [loadingState, setLoadingState] = useState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
  const [showVideo, setShowVideo] = useState(false);
  const [hasVideoTrack, setHasVideoTrack] = useState(false);

  // Global Video Element Ref instead of background Audio
  const videoRef = useRef(null);
  const audioRef = useRef(null);
  const audioContextRef = useRef(null);
  const sourceRef = useRef(null);
  const analyserRef = useRef(null);
  const eqLowRef = useRef(null);
  const eqMidRef = useRef(null);
  const eqHighRef = useRef(null);
  // CRITICAL: Ref to always hold the latest handleNextTrack to avoid stale closure in event listeners!
  const handleNextTrackRef = useRef(null);

  const currentTrack = playlist[currentTrackIndex] || DEFAULT_PLAYLIST[0];

  // Initialize HTML5 Video/Audio Element
  useEffect(() => {
    const audio = videoRef.current;
    if (!audio) return;
    audio.crossOrigin = 'anonymous'; // CRITICAL: enables Web Audio API CORS processing!
    audioRef.current = audio;

    // Load initial track without autoplay
    audio.src = currentTrack.url;
    audio.volume = volume;

    // Event Listeners
    const onTimeUpdate = () => {
      if (audio.duration) {
        setCurrentTime(audio.currentTime);
        setProgress((audio.currentTime / audio.duration) * 100);
      }
    };

    const onLoadedMetadata = () => {
      setDuration(audio.duration);
      // Check if the loaded file contains a valid video track (width > 0)
      if (audio.videoWidth > 0 && audio.videoHeight > 0) {
        setHasVideoTrack(true);
        setShowVideo(true); // Auto show video when starting an MP4 video file!
      } else {
        setHasVideoTrack(false);
        setShowVideo(false);
      }
    };

    const onEnded = () => {
      // Always call the LATEST version of handleNextTrack via ref (fixes stale closure bug!)
      if (handleNextTrackRef.current) handleNextTrackRef.current(true);
    };

    audio.addEventListener('timeupdate', onTimeUpdate);
    audio.addEventListener('loadedmetadata', onLoadedMetadata);
    audio.addEventListener('ended', onEnded);

    return () => {
      audio.pause();
      audio.removeEventListener('timeupdate', onTimeUpdate);
      audio.removeEventListener('loadedmetadata', onLoadedMetadata);
      audio.removeEventListener('ended', onEnded);
    };
  }, []);

  // Set up Web Audio API when user interacts (required by browsers due to autoplay policy)
  const initWebAudio = () => {
    if (audioContextRef.current) return;

    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      const ctx = new AudioCtx();
      audioContextRef.current = ctx;

      // Create nodes
      const source = ctx.createMediaElementSource(audioRef.current);
      const analyser = ctx.createAnalyser();
      analyser.fftSize = 256; // 128 frequency bins, perfect for visualizations
      
      // EQ Filters (BiquadFilterNodes)
      const lowFilter = ctx.createBiquadFilter();
      lowFilter.type = 'lowshelf';
      lowFilter.frequency.value = 320; // low frequencies (bass)

      const midFilter = ctx.createBiquadFilter();
      midFilter.type = 'peaking';
      midFilter.frequency.value = 1000; // mid frequencies (vocals/instruments)
      midFilter.Q.value = 1.0;

      const highFilter = ctx.createBiquadFilter();
      highFilter.type = 'highshelf';
      highFilter.frequency.value = 3200; // high frequencies (treble)

      // Connect nodes: Source -> LowEQ -> MidEQ -> HighEQ -> Analyser -> Destination
      source.connect(lowFilter);
      lowFilter.connect(midFilter);
      midFilter.connect(highFilter);
      highFilter.connect(analyser);
      analyser.connect(ctx.destination);

      // Save refs
      sourceRef.current = source;
      analyserRef.current = analyser;
      eqLowRef.current = lowFilter;
      eqMidRef.current = midFilter;
      eqHighRef.current = highFilter;

      // Apply initial EQ Preset
      applyEqPreset(eqPreset, lowFilter, midFilter, highFilter);
    } catch (e) {
      console.error('Failed to initialize Web Audio API', e);
    }
  };

  // Helper to apply EQ filter gains
  const applyEqPreset = (preset, low = eqLowRef.current, mid = eqMidRef.current, high = eqHighRef.current) => {
    if (!low || !mid || !high) return;
    
    switch (preset) {
      case 'Bass Boost':
        low.gain.value = 7;
        mid.gain.value = 0;
        high.gain.value = -1;
        break;
      case 'Vocal':
        low.gain.value = -3;
        mid.gain.value = 5;
        high.gain.value = 2;
        break;
      case 'Electronic':
        low.gain.value = 5;
        mid.gain.value = -1;
        high.gain.value = 5;
        break;
      case 'Flat':
      default:
        low.gain.value = 0;
        mid.gain.value = 0;
        high.gain.value = 0;
        break;
    }
  };

  // Update EQ when state changes
  useEffect(() => {
    applyEqPreset(eqPreset);
  }, [eqPreset]);

  // Track switching effect
  useEffect(() => {
    if (!audioRef.current) return;
    
    const wasPlaying = isPlaying;
    audioRef.current.src = currentTrack.url;
    audioRef.current.load();
    
    if (wasPlaying) {
      audioRef.current.play()
        .then(() => setIsPlaying(true))
        .catch(() => setIsPlaying(false));
    } else {
      setIsPlaying(false);
      setProgress(0);
      setCurrentTime(0);
    }
  }, [currentTrackIndex, playlist]);

  // Handle Play/Pause
  const togglePlay = () => {
    if (!audioRef.current) return;
    
    initWebAudio(); // Initialize audio context on first interaction

    // Resume AudioContext if suspended (browser security policy)
    if (audioContextRef.current && audioContextRef.current.state === 'suspended') {
      audioContextRef.current.resume();
    }

    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.play()
        .then(() => setIsPlaying(true))
        .catch(err => {
          console.error("Playback interrupted:", err);
          setIsPlaying(false);
        });
    }
  };

  // Skip to specific track
  const selectTrack = (index) => {
    initWebAudio();
    if (audioContextRef.current && audioContextRef.current.state === 'suspended') {
      audioContextRef.current.resume();
    }
    setCurrentTrackIndex(index);
    // Force play on direct select
    setTimeout(() => {
      if (audioRef.current) {
        audioRef.current.play()
          .then(() => setIsPlaying(true))
          .catch(() => setIsPlaying(false));
      }
    }, 50);
  };

  // Previous Track
  const handlePrevTrack = () => {
    if (currentTime > 5) {
      // restart current song if playing for more than 5s
      audioRef.current.currentTime = 0;
      return;
    }

    let prevIndex = currentTrackIndex - 1;
    if (prevIndex < 0) {
      prevIndex = playlist.length - 1;
    }
    setCurrentTrackIndex(prevIndex);
  };

  // Next Track
  const handleNextTrack = (autoEnded = false) => {
    if (autoEnded && isRepeat === 'one') {
      // Repeat current track
      audioRef.current.currentTime = 0;
      audioRef.current.play()
        .then(() => setIsPlaying(true))
        .catch(() => setIsPlaying(false));
      return;
    }

    if (isShuffle) {
      const randomIndex = Math.floor(Math.random() * playlist.length);
      setCurrentTrackIndex(randomIndex);
      return;
    }

    let nextIndex = currentTrackIndex + 1;
    if (nextIndex >= playlist.length) {
      if (isRepeat || !autoEnded) {
        nextIndex = 0; // loop back to first song
      } else {
        setIsPlaying(false);
        return;
      }
    }
    setCurrentTrackIndex(nextIndex);
  };
  // Keep ref always pointing to the latest version (fixes stale closure in onEnded listener!)
  handleNextTrackRef.current = handleNextTrack;

  // Seek Progress
  const seekTo = (value) => {
    if (!audioRef.current || !duration) return;
    const seekSeconds = (value / 100) * duration;
    audioRef.current.currentTime = seekSeconds;
    setProgress(value);
    setCurrentTime(seekSeconds);
  };

  // Volume control
  const handleVolumeChange = (value) => {
    const vol = parseFloat(value);
    setVolume(vol);
    if (audioRef.current) {
      audioRef.current.volume = vol;
      audioRef.current.muted = vol === 0;
    }
    setIsMuted(vol === 0);
  };

  // Toggle Mute
  const toggleMute = () => {
    if (!audioRef.current) return;
    if (isMuted) {
      audioRef.current.muted = false;
      audioRef.current.volume = volume || 0.5;
      setIsMuted(false);
    } else {
      audioRef.current.muted = true;
      setIsMuted(true);
    }
  };

  // Import local music files asynchronously to prevent UI freeze and support progress bar
  const importLocalFiles = async (files) => {
    const fileArray = Array.from(files).filter(file => 
      file.type.startsWith('audio/') || 
      file.type === 'video/mp4' || 
      file.name.toLowerCase().endsWith('.mp4') || 
      file.name.toLowerCase().endsWith('.m4a') ||
      file.name.toLowerCase().endsWith('.wav') ||
      file.name.toLowerCase().endsWith('.ogg') ||
      file.name.toLowerCase().endsWith('.flac')
    );

    if (fileArray.length === 0) return;

    // Show loading spinner (importing phase)
    setLoadingState({ active: true, current: 0, total: fileArray.length, percent: 0, phase: 'importing' });

    const newTracks = [];
    const batchSize = 8; // Process 8 files per batch to remain butter smooth!
    
    for (let i = 0; i < fileArray.length; i += batchSize) {
      const batch = fileArray.slice(i, i + batchSize);
      
      const batchTracks = batch.map((file, idx) => {
        const fileUrl = URL.createObjectURL(file);
        const nameWithoutExt = file.name.substring(0, file.name.lastIndexOf('.'));
        const parts = nameWithoutExt.split(' - ');
        const artist = parts[0] || 'Unknown Artist';
        const title = parts[1] || parts[0] || 'Local Track';
        
        const randomColors = [0, 1, 2].map(() => `hsl(${Math.floor(Math.random() * 360)}, 80%, 45%)`);

        return {
          id: `local-${Date.now()}-${i + idx}`,
          title,
          artist,
          album: 'Local Import',
          cover: 'https://images.unsplash.com/photo-1487180142328-054b783fc471?w=400&q=80',
          url: fileUrl,
          path: file.path || '',
          colors: randomColors,
          duration: '--:--'
        };
      });

      newTracks.push(...batchTracks);
      
      const currentProcessed = Math.min(i + batchSize, fileArray.length);
      const percent = Math.round((currentProcessed / fileArray.length) * 100);
      
      setLoadingState({ active: true, current: currentProcessed, total: fileArray.length, percent, phase: 'importing' });

      // Yield main thread to allow browser rendering
      await new Promise(resolve => setTimeout(resolve, 20));
    }

    if (newTracks.length > 0) {
      setPlaylist(prev => [...prev, ...newTracks]);
      const targetIndex = playlist.length;
      setCurrentTrackIndex(targetIndex);
      setIsPlaying(true);
      setTimeout(() => {
        if (audioRef.current) {
          audioRef.current.play()
            .then(() => setIsPlaying(true))
            .catch(() => setIsPlaying(false));
        }
      }, 100);
    }

    setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
  };

  // Import by native file paths (used for NAS/IPC fast scanner path)
  // Uses file:// protocol - no blob URL needed, works perfectly on NAS drives!
  const importLocalFilesByPaths = async (filePaths) => {
    const AUDIO_EXTS = new Set(['.mp3', '.wav', '.ogg', '.m4a', '.mp4', '.flac', '.aac', '.wma', '.opus', '.aiff']);
    const filtered = filePaths.filter(p => {
      const ext = p.substring(p.lastIndexOf('.')).toLowerCase();
      return AUDIO_EXTS.has(ext);
    });

    if (filtered.length === 0) {
      setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
      return;
    }

    setLoadingState({ active: true, current: 0, total: filtered.length, percent: 0, phase: 'importing' });

    const newTracks = [];
    const batchSize = 50; // Paths are cheap - no blob encoding needed, use larger batches

    for (let i = 0; i < filtered.length; i += batchSize) {
      const batch = filtered.slice(i, i + batchSize);

      const batchTracks = batch.map((filePath, idx) => {
        // Extract filename from path
        const fileName = filePath.replace(/\\/g, '/').split('/').pop();
        const nameWithoutExt = fileName.substring(0, fileName.lastIndexOf('.'));
        const parts = nameWithoutExt.split(' - ');
        const artist = parts.length >= 2 ? parts[0].trim() : 'Unknown Artist';
        const title = parts.length >= 2 ? parts.slice(1).join(' - ').trim() : parts[0].trim() || 'Local Track';

        const randomColors = [0, 1, 2].map(() => `hsl(${Math.floor(Math.random() * 360)}, 80%, 45%)`);

        // Use file:// protocol URL directly - works natively in Electron for local/NAS paths!
        const fileUrl = 'file://' + filePath.replace(/\\/g, '/');

        return {
          id: `local-${Date.now()}-${i + idx}`,
          title,
          artist,
          album: 'Local Import',
          cover: 'https://images.unsplash.com/photo-1487180142328-054b783fc471?w=400&q=80',
          url: fileUrl,
          path: filePath,
          colors: randomColors,
          duration: '--:--'
        };
      });

      newTracks.push(...batchTracks);

      const currentProcessed = Math.min(i + batchSize, filtered.length);
      const percent = Math.round((currentProcessed / filtered.length) * 100);
      setLoadingState({ active: true, current: currentProcessed, total: filtered.length, percent, phase: 'importing' });

      await new Promise(resolve => setTimeout(resolve, 10));
    }

    if (newTracks.length > 0) {
      setPlaylist(prev => [...prev, ...newTracks]);
      const targetIndex = playlist.length;
      setCurrentTrackIndex(targetIndex);
      setTimeout(() => {
        if (audioRef.current) {
          audioRef.current.play()
            .then(() => setIsPlaying(true))
            .catch(() => setIsPlaying(false));
        }
      }, 100);
    }

    setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
  };

  // Cycle repeat modes (off -> all -> one -> off)
  const cycleRepeat = () => {
    if (isRepeat === false) {
      setIsRepeat(true);
    } else if (isRepeat === true) {
      setIsRepeat('one');
    } else {
      setIsRepeat(false);
    }
  };

  const [videoPosition, setVideoPosition] = useState({ x: window.innerWidth - 410, y: 80 });
  const isDragging = useRef(false);
  const dragStart = useRef({ x: 0, y: 0 });

  const handleMouseDown = (e) => {
    isDragging.current = true;
    dragStart.current = {
      x: e.clientX - videoPosition.x,
      y: e.clientY - videoPosition.y
    };
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
  };

  const handleMouseMove = (e) => {
    if (!isDragging.current) return;
    const newX = Math.max(10, Math.min(window.innerWidth - 400, e.clientX - dragStart.current.x));
    const newY = Math.max(10, Math.min(window.innerHeight - 260, e.clientY - dragStart.current.y));
    setVideoPosition({ x: newX, y: newY });
  };

  const handleMouseUp = () => {
    isDragging.current = false;
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  };

  // Adjust position if window is resized
  useEffect(() => {
    const handleResize = () => {
      setVideoPosition(prev => {
        const x = Math.min(window.innerWidth - 410, prev.x);
        const y = Math.min(window.innerHeight - 260, prev.y);
        return { x, y };
      });
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return (
    <AudioContext.Provider
      value={{
        playlist,
        currentTrack,
        currentTrackIndex,
        isPlaying,
        progress,
        currentTime,
        duration,
        volume,
        isMuted,
        isShuffle,
        isRepeat,
        eqPreset,
        isVisualizerActive,
        analyserRef,
        setEqPreset,
        setIsVisualizerActive,
        togglePlay,
        selectTrack,
        prevTrack: handlePrevTrack,
        nextTrack: () => handleNextTrack(false),
        seekTo,
        setVolume: handleVolumeChange,
        toggleMute,
        toggleShuffle: () => setIsShuffle(!isShuffle),
        cycleRepeat,
        importLocalFiles,
        importLocalFilesByPaths,
        loadingState,
        setLoadingState,
        showVideo,
        hasVideoTrack,
        setShowVideo
      }}
    >
      {children}
      
      {/* Global HTML5 Video Element with Frosted Glass macOS frame */}
      <div 
        className="floating-video-window"
        style={{
          position: 'fixed',
          left: `${videoPosition.x}px`,
          top: `${videoPosition.y}px`,
          borderRadius: '16px',
          border: '1px solid rgba(255, 255, 255, 0.12)',
          boxShadow: '0 24px 64px rgba(0, 0, 0, 0.6)',
          background: 'rgba(28, 30, 38, 0.85)',
          backdropFilter: 'blur(30px)',
          WebkitBackdropFilter: 'blur(30px)',
          zIndex: 9000,
          display: (showVideo && hasVideoTrack) ? 'flex' : 'none',
          flexDirection: 'column',
          transition: isDragging.current ? 'none' : 'transform 0.1s ease, opacity 0.2s'
        }}
        id="floating-video-window"
      >
        {/* macOS Small Title Bar */}
        <div 
          onMouseDown={handleMouseDown}
          style={{
            height: '32px',
            background: 'rgba(255, 255, 255, 0.03)',
            borderBottom: '1px solid rgba(255, 255, 255, 0.08)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 12px',
            fontSize: '11px',
            color: 'var(--text-secondary)',
            fontWeight: 600,
            userSelect: 'none',
            cursor: 'move'
          }}
        >
          <span>AeroPlayer - 影片播放視窗 (拖曳移動)</span>
          {/* Close button */}
          <button 
            onClick={() => setShowVideo(false)}
            onMouseDown={(e) => e.stopPropagation()} // Prevent drag when clicking hide button!
            style={{
              border: 'none',
              background: 'rgba(255, 255, 255, 0.1)',
              borderRadius: '4px',
              padding: '2px 6px',
              color: '#fff',
              fontSize: '10px',
              cursor: 'pointer',
              fontWeight: 600,
              transition: 'background 0.2s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)'}
            onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)'}
          >
            隱藏
          </button>
        </div>
        {/* Video stream */}
        <video
          ref={videoRef}
          crossOrigin="anonymous"
          style={{
            flex: 1,
            width: '100%',
            height: 'calc(100% - 32px)',
            background: '#000',
            objectFit: 'contain',
            borderBottomLeftRadius: '16px',
            borderBottomRightRadius: '16px'
          }}
        />
      </div>
    </AudioContext.Provider>
  );
};

export const useAudio = () => {
  const context = useContext(AudioContext);
  if (!context) {
    throw new Error('useAudio must be used within an AudioProvider');
  }
  return context;
};
