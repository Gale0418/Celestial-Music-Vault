import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react';

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
  const currentTrackIdRef = useRef(null);
  
  useEffect(() => {
    if (playlist[currentTrackIndex]) {
      currentTrackIdRef.current = playlist[currentTrackIndex].id;
    }
  }, [playlist, currentTrackIndex]);

  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0); // 0 to 100
  const [currentTime, setCurrentTime] = useState(0); // in seconds
  const [duration, setDuration] = useState(0); // in seconds
  const [volume, setVolume] = useState(0.8);
  const [isMuted, setIsMuted] = useState(false);
  const [isShuffle, setIsShuffle] = useState(false);
  const [isRepeat, setIsRepeat] = useState(false); // false: no, true: repeat queue, 'one': repeat track
  const [eqPreset, setEqPreset] = useState('Flat'); // Flat, Bass Boost, Vocal, Electronic
  const [loadingState, setLoadingState] = useState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
  const [showVideo, setShowVideo] = useState(false);
  const [hasVideoTrack, setHasVideoTrack] = useState(false);

  // New Ultimate Features
  const [dislikedTracks, setDislikedTracks] = useState([]);
  const [trackRatings, setTrackRatings] = useState({}); // { trackId: 0~5 }
  const [sleepTimerEndsAt, setSleepTimerEndsAt] = useState(null);
  
  // Sleep Timer effect
  useEffect(() => {
    if (!sleepTimerEndsAt) return;
    const interval = setInterval(() => {
      if (Date.now() >= sleepTimerEndsAt) {
        if (audioRef.current && isPlaying) {
          audioRef.current.pause();
          setIsPlaying(false);
        }
        setSleepTimerEndsAt(null);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [sleepTimerEndsAt, isPlaying]);

  // New features: Persistence collections & views
  const [favorites, setFavorites] = useState([]);
  const [playlists, setPlaylists] = useState([]);
  const [library, setLibrary] = useState([]);
  const [activeView, setActiveView] = useState('all'); // 'all' (lofi), 'library', 'favorites', 'playlist-{id}'
  const [playbackSource, setPlaybackSource] = useState(null); // Keep track of which view is currently providing the playlist
  const [hasLoadedInitialData, setHasLoadedInitialData] = useState(false);
  
  const initialPlaybackTimeRef = useRef(0);
  const activeViewRef = useRef('all');
  
  // Keep activeViewRef updated
  useEffect(() => {
    activeViewRef.current = activeView;
  }, [activeView]);

  // Global Video Element Ref instead of background Audio
  const videoRef = useRef(null);
  const audioRef = useRef(null);
  const audioContextRef = useRef(null);
  const sourceRef = useRef(null);
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
    audio.crossOrigin = 'anonymous';
    audioRef.current = audio;

    // Helper to safely load audio source
    const setAudioSource = (track) => {
      if (!audio || !track) return;
      audio.src = track.url;
      audio.load();
    };

    // Load initial track without autoplay
    setAudioSource(currentTrack);
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

      // If we have a pending initial playback time to restore, do it once!
      if (initialPlaybackTimeRef.current > 0) {
        audio.currentTime = initialPlaybackTimeRef.current;
        setCurrentTime(initialPlaybackTimeRef.current);
        setProgress((initialPlaybackTimeRef.current / audio.duration) * 100);
        initialPlaybackTimeRef.current = 0; // reset
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

      // Connect nodes: Source -> LowEQ -> MidEQ -> HighEQ -> Destination
      source.connect(lowFilter);
      lowFilter.connect(midFilter);
      midFilter.connect(highFilter);
      highFilter.connect(ctx.destination);

      // Save refs
      sourceRef.current = source;
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

  // --- DATA PERSISTENCE SYSTEM ---
  
  // Helper to save all user data including playlists, favorites, library and current playback state
  const saveAllData = (updatedLibrary = library, updatedFavorites = favorites, updatedPlaylists = playlists, currentView = activeView, updatedRatings = trackRatings) => {
    if (!window.electronAPI) return;
    
    const audio = videoRef.current;
    const playbackState = {
      currentTrackPath: currentTrack ? (currentTrack.path || '') : '',
      currentTrackId: currentTrack ? currentTrack.id : '',
      currentTime: audio ? audio.currentTime : 0,
      volume,
      isMuted,
      activeView: currentView
    };

    window.electronAPI.saveUserData({
      library: updatedLibrary,
      favorites: updatedFavorites,
      playlists: updatedPlaylists,
      trackRatings: updatedRatings,
      playbackState
    });
  };

  // 1. Initial Load on Mount
  useEffect(() => {
    const loadData = async () => {
      if (!window.electronAPI) return;
      try {
        const data = await window.electronAPI.loadUserData();
        if (data) {
          const loadedLibrary = data.library || [];
          const loadedFavorites = data.favorites || [];
          const loadedPlaylists = data.playlists || [];
          const loadedRatings = data.trackRatings || {};
          
          setLibrary(loadedLibrary);
          setFavorites(loadedFavorites);
          setPlaylists(loadedPlaylists);
          setTrackRatings(loadedRatings);

          const pb = data.playbackState;
          if (pb) {
            if (pb.volume !== undefined) {
              setVolume(pb.volume);
              if (audioRef.current) audioRef.current.volume = pb.volume;
            }
            if (pb.isMuted !== undefined) {
              setIsMuted(pb.isMuted);
              if (audioRef.current) audioRef.current.muted = pb.isMuted;
            }
            if (pb.activeView) {
              setActiveView(pb.activeView);
            }

            // Determine active playlist based on saved activeView
            let targetPlaylist = DEFAULT_PLAYLIST;
            if (pb.activeView === 'library' && loadedLibrary.length > 0) {
              targetPlaylist = loadedLibrary;
            } else if (pb.activeView === 'favorites' && loadedFavorites.length > 0) {
              targetPlaylist = loadedFavorites;
            } else if (pb.activeView && pb.activeView.startsWith('playlist-')) {
              const playlistId = pb.activeView.replace('playlist-', '');
              const foundPlaylist = loadedPlaylists.find(p => p.id === playlistId);
              if (foundPlaylist && foundPlaylist.tracks.length > 0) {
                targetPlaylist = foundPlaylist.tracks;
              }
            }

            setPlaylist(targetPlaylist);

            // Find index of the last played track
            let trackIndex = 0;
            if (pb.currentTrackPath) {
              const foundIdx = targetPlaylist.findIndex(t => t.path === pb.currentTrackPath);
              if (foundIdx !== -1) trackIndex = foundIdx;
            } else if (pb.currentTrackId) {
              const foundIdx = targetPlaylist.findIndex(t => t.id === pb.currentTrackId);
              if (foundIdx !== -1) trackIndex = foundIdx;
            }
            
            setCurrentTrackIndex(trackIndex);

            if (pb.currentTime) {
              initialPlaybackTimeRef.current = pb.currentTime;
            }
          }
        }
      } catch (err) {
        console.error("Failed to restore playback state:", err);
      } finally {
        setHasLoadedInitialData(true);
      }
    };
    loadData();
  }, []);

  // 2. Autosave collections when they change
  useEffect(() => {
    if (!hasLoadedInitialData) return;
    saveAllData(library, favorites, playlists, activeView);
  }, [library, favorites, playlists, activeView]);

  // 3. Autosave state periodically (every 10 seconds) during playback to keep it lightweight
  useEffect(() => {
    if (!isPlaying) return;
    const interval = setInterval(() => {
      saveAllData(library, favorites, playlists, activeView);
    }, 10000);
    return () => clearInterval(interval);
  }, [isPlaying, library, favorites, playlists, currentTrackIndex, activeView, volume, isMuted]);

  // 4. Save state when window beforeunload triggers
  useEffect(() => {
    const handleUnload = () => {
      saveAllData(library, favorites, playlists, activeView);
    };
    window.addEventListener('beforeunload', handleUnload);
    return () => window.removeEventListener('beforeunload', handleUnload);
  }, [library, favorites, playlists, currentTrackIndex, activeView, volume, isMuted]);

  // --- PLAYLISTS & FAVORITES HELPER FUNCTIONS ---
  
  const toggleFavorite = (track) => {
    setFavorites(prev => {
      const sameTrack = (t) => (t.id && track.id && t.id === track.id) || (!!t.path && !!track.path && t.path === track.path);
      const exists = prev.some(sameTrack);
      if (exists) {
        return prev.filter(t => !sameTrack(t));
      } else {
        return [...prev, track];
      }
    });
  };

  const createPlaylist = (name, initialTracks = []) => {
    const newPlaylist = {
      id: `playlist-${Date.now()}`,
      name,
      tracks: [...initialTracks]
    };
    setPlaylists(prev => [...prev, newPlaylist]);
    return newPlaylist;
  };

  const deletePlaylist = (playlistId) => {
    setPlaylists(prev => prev.filter(p => p.id !== playlistId));
    if (activeView === `playlist-${playlistId}`) {
      setActiveView('all');
    }
  };

  const addTrackToPlaylist = (playlistId, track) => {
    setPlaylists(prev => prev.map(p => {
      if (p.id === playlistId) {
        const sameTrack = (t) => (t.id && track.id && t.id === track.id) || (!!t.path && !!track.path && t.path === track.path);
        const exists = p.tracks.some(sameTrack);
        if (exists) return p;
        return { ...p, tracks: [...p.tracks, track] };
      }
      return p;
    }));
  };

  const removeTrackFromPlaylist = (playlistId, trackId) => {
    setPlaylists(prev => prev.map(p => {
      if (p.id === playlistId) {
        return { ...p, tracks: p.tracks.filter(t => t.id !== trackId) };
      }
      return p;
    }));
  };

  // Track switching effect
  useEffect(() => {
    if (!audioRef.current) return;
    
    const wasPlaying = isPlaying;
    
    // Use the same helper function we use inside useEffect
    const setAudioSource = (track) => {
      if (!audioRef.current || !track) return;
      audioRef.current.src = track.url;
      audioRef.current.load();
    };

    setAudioSource(currentTrack);
    
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
    if (!audioRef.current) return;
    if (currentTime > 5) {
      // restart current song if playing for more than 5s
      audioRef.current.currentTime = 0;
      return;
    }

    let prevIndex = currentTrackIndex;
    let attempts = 0;
    const maxAttempts = playlist.length;

    do {
      prevIndex = prevIndex - 1;
      if (prevIndex < 0) {
        prevIndex = playlist.length - 1;
      }
      attempts++;
    } while (
      dislikedTracks.includes(playlist[prevIndex]?.id) && 
      attempts < maxAttempts
    );
    
    const track = playlist[prevIndex];
    if (track) {
      setCurrentTrackIndex(prevIndex);
      try {
        audioRef.current.src = track.url;
        audioRef.current.load();
        audioRef.current.play()
          .then(() => setIsPlaying(true))
          .catch(() => setIsPlaying(false));
      } catch (err) {
        console.warn("Direct navigation error:", err);
      }
    }
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

    let nextIndex = currentTrackIndex;
    let attempts = 0;
    const maxAttempts = playlist.length;
    
    do {
      if (isShuffle) {
        nextIndex = Math.floor(Math.random() * playlist.length);
      } else {
        nextIndex = nextIndex + 1;
        if (nextIndex >= playlist.length) {
          if (isRepeat || !autoEnded) {
            nextIndex = 0; // loop back to first song
          } else {
            setIsPlaying(false);
            return;
          }
        }
      }
      attempts++;
    } while (
      dislikedTracks.includes(playlist[nextIndex]?.id) &&
      attempts < maxAttempts
    );

    const track = playlist[nextIndex];
    if (track) {
      setCurrentTrackIndex(nextIndex);
      try {
        audioRef.current.src = track.url;
        audioRef.current.load();
        audioRef.current.play()
          .then(() => setIsPlaying(true))
          .catch(() => setIsPlaying(false));
      } catch (err) {
        console.warn("Direct navigation error:", err);
      }
    }
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

  const toggleDislike = (trackId) => {
    setDislikedTracks(prev => {
      if (prev.includes(trackId)) {
        return prev.filter(id => id !== trackId);
      } else {
        return [...prev, trackId];
      }
    });
    // If we dislike the currently playing song, skip it immediately
    if (currentTrack?.id === trackId) {
      handleNextTrack();
    }
  };

  const setTrackRating = (trackId, rating) => {
    const updatedRatings = { ...trackRatings, [trackId]: rating };
    setTrackRatings(updatedRatings);
    // 即時持久化評分
    saveAllData(library, favorites, playlists, activeView, updatedRatings);
  };


  const clearPlaylist = () => {
    setPlaylist([]);
    setCurrentTrackIndex(0);
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.currentTime = 0;
    }
    setIsPlaying(false);
  };

  const clearLibrary = () => {
    setLibrary([]);
    if (activeView === 'library') {
      clearPlaylist();
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
      setLibrary(prev => {
        const existingPaths = new Set(prev.map(t => t.path).filter(Boolean));
        const filteredNew = newTracks.filter(t => !t.path || !existingPaths.has(t.path));
        const updatedLib = [...prev, ...filteredNew];
        
        setPlaylist(updatedLib);
        setActiveView('library');
        
        const targetIndex = prev.length;
        setCurrentTrackIndex(targetIndex);
        
        return updatedLib;
      });

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
      setLibrary(prev => {
        const existingPaths = new Set(prev.map(t => t.path));
        const filteredNew = newTracks.filter(t => !existingPaths.has(t.path));
        const updatedLib = [...prev, ...filteredNew];
        
        setPlaylist(updatedLib);
        setActiveView('library');
        
        const targetIndex = prev.length;
        setCurrentTrackIndex(targetIndex);
        
        return updatedLib;
      });
      
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
    setIsRepeat(prev => {
      if (prev === false) return true;
      if (prev === true) return 'one';
      return false;
    });
  };

  // Dynamic atomic play function to avoid React batched updates race-conditions
  const playTrackInList = (targetPlaylist, index, sourceView = null) => {
    initWebAudio();
    if (audioContextRef.current && audioContextRef.current.state === 'suspended') {
      audioContextRef.current.resume();
    }
    
    // Atomically sync the playlist queue and current index
    setPlaylist(targetPlaylist);
    setCurrentTrackIndex(index);
    if (sourceView) {
      setPlaybackSource(sourceView);
    }
    
    // Directly inject the track source into HTML5 Audio to bypass React update latency!
    const track = targetPlaylist[index];
    if (track && audioRef.current) {
      try {
        audioRef.current.src = track.url;
        audioRef.current.load();
        audioRef.current.play()
          .then(() => setIsPlaying(true))
          .catch(() => setIsPlaying(false));
      } catch (err) {
        console.warn("Direct playTrackInList error:", err);
      }
    }
  };

  const syncPlaylist = useCallback((newPlaylist) => {
    if (!newPlaylist || newPlaylist.length === 0) return;
    
    setPlaylist(prev => {
      // Avoid unnecessary updates if the list is identical (prevents infinite loops)
      if (prev.length === newPlaylist.length && prev.every((t, i) => t.id === newPlaylist[i].id)) {
        return prev;
      }
      
      // If we have a current track, maintain its playback by updating the index
      if (currentTrackIdRef.current) {
        const newIdx = newPlaylist.findIndex(t => t.id === currentTrackIdRef.current);
        if (newIdx !== -1) {
          setCurrentTrackIndex(newIdx);
        }
      }
      return newPlaylist;
    });
  }, []);

  const removeTrackFromLibrary = (trackId) => {
    setLibrary(prev => {
      const removedTrack = prev.find(t => t.id === trackId);
      if (removedTrack && removedTrack.url && removedTrack.url.startsWith('blob:')) {
        URL.revokeObjectURL(removedTrack.url);
      }
      const updated = prev.filter(t => t.id !== trackId);
      if (activeView === 'library') {
        setPlaylist(updated);
      }
      return updated;
    });
  };

  const playNext = (track) => {
    setPlaylist(prev => {
      const currentIndex = currentTrackIndex;
      const filtered = prev.filter((t, i) => t.id !== track.id || i === currentIndex);
      
      let activeIndex = currentIndex;
      if (track.id !== currentTrack.id) {
        activeIndex = filtered.findIndex(t => t.id === currentTrack.id);
        if (activeIndex === -1) activeIndex = currentIndex;
        setCurrentTrackIndex(activeIndex);
      }
      
      const updated = [...filtered];
      updated.splice(activeIndex + 1, 0, track);
      return updated;
    });
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
        setPlaylist,
        currentTrack,
        currentTrackIndex,
        setCurrentTrackIndex,
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
        selectTrack,
        prevTrack: handlePrevTrack,
        nextTrack: () => handleNextTrack(false),
        seekTo,
        setVolume: handleVolumeChange,
        toggleMute,
        toggleShuffle: () => setIsShuffle(prev => !prev),
        cycleRepeat,
        importLocalFiles,
        importLocalFilesByPaths,
        loadingState,
        setLoadingState,
        showVideo,
        hasVideoTrack,
        setShowVideo,
        
        // New Persistence features
        favorites,
        playlists,
        library,
        setLibrary,
        activeView,
        setActiveView,
        toggleFavorite,
        createPlaylist,
        deletePlaylist,
        addTrackToPlaylist,
        removeTrackFromPlaylist,
        playTrackInList,
        removeTrackFromLibrary,
        playNext,
        playbackSource,
        syncPlaylist,
        sleepTimerEndsAt,
        setSleepTimerEndsAt,
        dislikedTracks,
        toggleDislike,
        trackRatings,
        setTrackRating,
        clearPlaylist,
        clearLibrary
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
