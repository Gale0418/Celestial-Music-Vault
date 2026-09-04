import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useLayoutEffect,
  useRef,
  useCallback,
  useMemo
} from 'react';
import defaultCover from '../assets/default-cover.svg';
import { clampVideoPosition, createRafThrottledUpdater } from '../utils/videoWindowPosition';
import { findNextPlayableIndex, findPreviousPlayableIndex } from '../utils/queueNavigation';

const AudioContext = createContext();

const LOCAL_MEDIA_EXTENSIONS = new Set([
  '.mp3', '.wav', '.ogg', '.m4a', '.mp4', '.flac', '.aac', '.wma', '.opus',
  '.aiff', '.aif', '.alac', '.mov', '.m4v'
]);

const resolveMediaUrl = (url) => {
  if (typeof url === 'string' && url.startsWith('https://') && window.electronAPI?.toRemoteMediaUrl) {
    return window.electronAPI.toRemoteMediaUrl(url);
  }
  return url;
};

const fileExtension = (name = '') => {
  const index = name.lastIndexOf('.');
  return index >= 0 ? name.slice(index).toLowerCase() : '';
};

const sameTrack = (left, right) => Boolean(left && right) && (
  (left.id && right.id && left.id === right.id) ||
  (left.path && right.path && left.path === right.path)
);

const trackKey = (track) => track
  ? `${track.id || ''}\u0000${track.path || ''}\u0000${track.url || ''}`
  : '';

const localTrackID = () => `local-${globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`}`;

const DEFAULT_PLAYLIST = [
  {
    id: 'lofi-1', title: 'CMV Space Chill', artist: 'Lofi Dreamer', album: 'Cosmic Beats Vol. 1',
    cover: defaultCover, url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    colors: ['#ff2d55', '#af52de', '#007aff'], duration: '6:12'
  },
  {
    id: 'lofi-2', title: 'Midnight Coding', artist: 'Synth Wave Girl', album: 'Neon Cyberpunk',
    cover: defaultCover, url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
    colors: ['#007aff', '#34c759', '#af52de'], duration: '7:05'
  },
  {
    id: 'lofi-3', title: 'Morning Matcha', artist: 'Coffee & Books', album: 'Cafe Study Sessions',
    cover: defaultCover, url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
    colors: ['#ff9500', '#ffcc00', '#34c759'], duration: '5:44'
  },
  {
    id: 'lofi-4', title: 'Rainy Afternoon', artist: 'Tokyo Rain', album: 'City Lights Ambient',
    cover: defaultCover, url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
    colors: ['#007aff', '#5856d6', '#ff2d55'], duration: '5:02'
  },
  {
    id: 'lofi-5', title: 'Sunset Boulevard', artist: 'Retro Horizon', album: 'Dreamwave Rides',
    cover: defaultCover, url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
    colors: ['#ff2d55', '#ff9500', '#af52de'], duration: '6:03'
  }
];

export const AudioProvider = ({ children }) => {
  const [playlist, setPlaylist] = useState(DEFAULT_PLAYLIST);
  const [currentTrackIndex, setCurrentTrackIndex] = useState(0);
  const [mediaRequestVersion, setMediaRequestVersion] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const [progress, setProgress] = useState(0);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [volume, setVolume] = useState(0.8);
  const [isMuted, setIsMuted] = useState(false);
  const [isShuffle, setIsShuffle] = useState(false);
  const [isRepeat, setIsRepeat] = useState(false);
  const [eqPreset, setEqPreset] = useState('Flat');
  const [loadingState, setLoadingState] = useState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
  const [showVideo, setShowVideo] = useState(false);
  const [hasVideoTrack, setHasVideoTrack] = useState(false);
  const [dislikedTracks, setDislikedTracks] = useState([]);
  const [trackRatings, setTrackRatings] = useState({});
  const [sleepTimerEndsAt, setSleepTimerEndsAt] = useState(null);
  const [favorites, setFavorites] = useState([]);
  const [playlists, setPlaylists] = useState([]);
  const [library, setLibrary] = useState([]);
  const [activeView, setActiveView] = useState('all');
  const [playbackSource, setPlaybackSource] = useState(null);
  const [hasLoadedInitialData, setHasLoadedInitialData] = useState(false);

  const currentTrack = playlist[currentTrackIndex] || null;
  const dislikedTrackSet = useMemo(() => new Set(dislikedTracks), [dislikedTracks]);
  const currentTrackIdRef = useRef(currentTrack?.id || null);
  const initialVolumeRef = useRef(volume);
  const pendingRestoreRef = useRef(null);
  const pendingAutoplayRef = useRef(false);
  const activeMediaKeyRef = useRef('');
  const mediaRequestGenerationRef = useRef(0);
  const activeViewRef = useRef('all');
  const libraryRef = useRef([]);
  const persistenceBlockedRef = useRef(false);
  const latestPlaybackRef = useRef({ currentTrack, volume, isMuted, activeView });

  const videoRef = useRef(null);
  const audioRef = useRef(null);
  const audioContextRef = useRef(null);
  const sourceRef = useRef(null);
  const eqLowRef = useRef(null);
  const eqMidRef = useRef(null);
  const eqHighRef = useRef(null);
  const handleNextTrackRef = useRef(null);

  latestPlaybackRef.current = { currentTrack, volume, isMuted, activeView };

  useEffect(() => {
    activeViewRef.current = activeView;
  }, [activeView]);

  useEffect(() => {
    libraryRef.current = library;
  }, [library]);

  useEffect(() => {
    currentTrackIdRef.current = currentTrack?.id || null;
  }, [currentTrack]);

  useEffect(() => {
    if (!sleepTimerEndsAt) return;
    const interval = setInterval(() => {
      if (Date.now() >= sleepTimerEndsAt) {
        audioRef.current?.pause();
        setSleepTimerEndsAt(null);
      }
    }, 1000);
    return () => clearInterval(interval);
  }, [sleepTimerEndsAt]);

  const attemptPlay = useCallback((audio, label = 'Playback') => {
    if (!audio) return;
    const generation = mediaRequestGenerationRef.current;
    void audio.play().catch(error => {
      if (generation !== mediaRequestGenerationRef.current) return;
      console.error(`${label} interrupted:`, error);
    });
  }, []);

  useEffect(() => {
    const audio = videoRef.current;
    if (!audio) return;
    audio.crossOrigin = 'anonymous';
    audioRef.current = audio;
    audio.volume = initialVolumeRef.current;

    const onTimeUpdate = () => {
      if (Number.isFinite(audio.duration) && audio.duration > 0 && Number.isFinite(audio.currentTime)) {
        setCurrentTime(Math.max(0, audio.currentTime));
        setProgress(Math.min(100, Math.max(0, (audio.currentTime / audio.duration) * 100)));
      }
    };

    const onLoadedMetadata = () => {
      const mediaDuration = Number.isFinite(audio.duration) && audio.duration > 0 ? audio.duration : 0;
      setDuration(mediaDuration);
      const hasVideo = audio.videoWidth > 0 && audio.videoHeight > 0;
      setHasVideoTrack(hasVideo);
      setShowVideo(hasVideo);

      const pending = pendingRestoreRef.current;
      if (pending?.mediaKey === activeMediaKeyRef.current && pending.seconds > 0 && mediaDuration > 0) {
        const restored = Math.min(mediaDuration, pending.seconds);
        audio.currentTime = restored;
        setCurrentTime(restored);
        setProgress((restored / mediaDuration) * 100);
        pendingRestoreRef.current = null;
      }
    };

    const onEnded = () => handleNextTrackRef.current?.(true);
    const onPlay = () => setIsPlaying(true);
    const onPause = () => setIsPlaying(false);
    const onError = () => {
      setIsPlaying(false);
      console.warn('Media element failed to load:', audio.error?.message || audio.error?.code || 'unknown error');
    };

    audio.addEventListener('timeupdate', onTimeUpdate);
    audio.addEventListener('loadedmetadata', onLoadedMetadata);
    audio.addEventListener('ended', onEnded);
    audio.addEventListener('play', onPlay);
    audio.addEventListener('pause', onPause);
    audio.addEventListener('error', onError);

    return () => {
      mediaRequestGenerationRef.current += 1;
      audio.pause();
      audio.removeEventListener('timeupdate', onTimeUpdate);
      audio.removeEventListener('loadedmetadata', onLoadedMetadata);
      audio.removeEventListener('ended', onEnded);
      audio.removeEventListener('play', onPlay);
      audio.removeEventListener('pause', onPause);
      audio.removeEventListener('error', onError);
    };
  }, []);

  const applyEqPreset = useCallback((preset, low = eqLowRef.current, mid = eqMidRef.current, high = eqHighRef.current) => {
    if (!low || !mid || !high) return;
    switch (preset) {
      case 'Bass Boost': low.gain.value = 7; mid.gain.value = 0; high.gain.value = -1; break;
      case 'Vocal': low.gain.value = -3; mid.gain.value = 5; high.gain.value = 2; break;
      case 'Electronic': low.gain.value = 5; mid.gain.value = -1; high.gain.value = 5; break;
      default: low.gain.value = 0; mid.gain.value = 0; high.gain.value = 0; break;
    }
  }, []);

  const initWebAudio = useCallback(() => {
    if (audioContextRef.current || !audioRef.current) return;
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const source = ctx.createMediaElementSource(audioRef.current);
      const low = ctx.createBiquadFilter();
      const mid = ctx.createBiquadFilter();
      const high = ctx.createBiquadFilter();
      low.type = 'lowshelf'; low.frequency.value = 320;
      mid.type = 'peaking'; mid.frequency.value = 1000; mid.Q.value = 1;
      high.type = 'highshelf'; high.frequency.value = 3200;
      source.connect(low); low.connect(mid); mid.connect(high); high.connect(ctx.destination);
      audioContextRef.current = ctx;
      sourceRef.current = source;
      eqLowRef.current = low;
      eqMidRef.current = mid;
      eqHighRef.current = high;
      applyEqPreset(eqPreset, low, mid, high);
    } catch (error) {
      console.error('Failed to initialize Web Audio API', error);
    }
  }, [applyEqPreset, eqPreset]);

  useEffect(() => {
    applyEqPreset(eqPreset);
  }, [applyEqPreset, eqPreset]);

  const saveAllData = useCallback(async (
    updatedLibrary = library,
    updatedFavorites = favorites,
    updatedPlaylists = playlists,
    currentView = latestPlaybackRef.current.activeView,
    updatedRatings = trackRatings
  ) => {
    if (!window.electronAPI || persistenceBlockedRef.current) return false;
    const audio = videoRef.current;
    const { currentTrack: latestTrack, volume: latestVolume, isMuted: latestIsMuted } = latestPlaybackRef.current;
    const playbackState = {
      currentTrackPath: latestTrack?.path || '',
      currentTrackId: latestTrack?.id || '',
      currentTime: Number.isFinite(audio?.currentTime) ? Math.max(0, audio.currentTime) : 0,
      volume: Number.isFinite(latestVolume) ? Math.min(1, Math.max(0, latestVolume)) : 0.8,
      isMuted: Boolean(latestIsMuted),
      activeView: currentView
    };
    try {
      return await window.electronAPI.saveUserData({
        library: updatedLibrary,
        favorites: updatedFavorites,
        playlists: updatedPlaylists,
        trackRatings: updatedRatings,
        playbackState
      });
    } catch (error) {
      console.error('Failed to save user data:', error);
      return false;
    }
  }, [favorites, library, playlists, trackRatings]);

  useEffect(() => {
    const loadData = async () => {
      if (!window.electronAPI) {
        setHasLoadedInitialData(true);
        return;
      }
      try {
        const data = await window.electronAPI.loadUserData();
        if (!data) return;
        const loadedLibrary = Array.isArray(data.library) ? data.library : [];
        const loadedFavorites = Array.isArray(data.favorites) ? data.favorites : [];
        const loadedPlaylists = Array.isArray(data.playlists) ? data.playlists : [];
        const loadedRatings = data.trackRatings && typeof data.trackRatings === 'object' ? data.trackRatings : {};
        libraryRef.current = loadedLibrary;
        setLibrary(loadedLibrary);
        setFavorites(loadedFavorites);
        setPlaylists(loadedPlaylists);
        setTrackRatings(loadedRatings);

        const pb = data.playbackState;
        if (!pb || typeof pb !== 'object') return;
        const restoredVolume = Number(pb.volume);
        if (Number.isFinite(restoredVolume)) {
          const clamped = Math.min(1, Math.max(0, restoredVolume));
          setVolume(clamped);
          if (audioRef.current) audioRef.current.volume = clamped;
        }
        if (pb.isMuted !== undefined) {
          const muted = Boolean(pb.isMuted);
          setIsMuted(muted);
          if (audioRef.current) audioRef.current.muted = muted;
        }
        if (typeof pb.activeView === 'string' && pb.activeView) setActiveView(pb.activeView);

        let targetPlaylist = DEFAULT_PLAYLIST;
        if (pb.activeView === 'library') {
          targetPlaylist = loadedLibrary;
        } else if (pb.activeView === 'favorites') {
          targetPlaylist = loadedFavorites;
        } else if (typeof pb.activeView === 'string' && pb.activeView.startsWith('playlist-')) {
          const playlistId = pb.activeView.replace('playlist-', '');
          const found = loadedPlaylists.find(item => item.id === playlistId);
          targetPlaylist = Array.isArray(found?.tracks) ? found.tracks : [];
        }

        let index = 0;
        if (pb.currentTrackPath) {
          const found = targetPlaylist.findIndex(track => track.path === pb.currentTrackPath);
          if (found >= 0) index = found;
        } else if (pb.currentTrackId) {
          const found = targetPlaylist.findIndex(track => track.id === pb.currentTrackId);
          if (found >= 0) index = found;
        }
        const safeIndex = targetPlaylist.length > 0 ? Math.min(index, targetPlaylist.length - 1) : 0;
        const restoredTime = Number(pb.currentTime);
        const restoredTrack = targetPlaylist[safeIndex];
        if (restoredTrack && Number.isFinite(restoredTime) && restoredTime > 0) {
          pendingRestoreRef.current = {
            mediaKey: trackKey(restoredTrack),
            seconds: restoredTime
          };
        }
        setPlaylist(targetPlaylist);
        setCurrentTrackIndex(safeIndex);
      } catch (error) {
        const message = String(error?.message || error || 'Unknown persistence error');
        console.error('Failed to restore playback state:', error);
        if (message.includes('CMV_APPROVED_ROOTS_UNAVAILABLE')) {
          persistenceBlockedRef.current = true;
          window.electronAPI.showErrorBox(
            'CMV 需要重新授權音樂資料夾',
            '既有曲庫資料仍保留，但音樂來源授權索引遺失或損壞。請重新選擇原音樂資料夾後重新啟動 CMV；本次工作階段不會覆寫既有曲庫。'
          );
        }
      } finally {
        setHasLoadedInitialData(true);
      }
    };
    loadData();
  }, []);

  useEffect(() => {
    if (!hasLoadedInitialData || persistenceBlockedRef.current) return;
    void saveAllData(library, favorites, playlists, activeView);
  }, [activeView, favorites, hasLoadedInitialData, library, playlists, saveAllData]);

  useEffect(() => {
    if (!isPlaying || persistenceBlockedRef.current) return;
    const interval = setInterval(() => { void saveAllData(); }, 10000);
    return () => clearInterval(interval);
  }, [isPlaying, saveAllData]);

  useEffect(() => {
    const handleUnload = () => {
      if (!persistenceBlockedRef.current) void saveAllData();
    };
    window.addEventListener('beforeunload', handleUnload);
    return () => window.removeEventListener('beforeunload', handleUnload);
  }, [saveAllData]);

  const toggleFavorite = (track) => {
    if (!track) return;
    setFavorites(prev => prev.some(item => sameTrack(item, track))
      ? prev.filter(item => !sameTrack(item, track))
      : [...prev, track]);
  };

  const createPlaylist = (name, initialTracks = []) => {
    const newPlaylist = {
      id: `playlist-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      name: String(name || '').trim() || '未命名歌單',
      tracks: Array.isArray(initialTracks) ? [...initialTracks] : []
    };
    setPlaylists(prev => [...prev, newPlaylist]);
    return newPlaylist;
  };

  const deletePlaylist = (playlistId) => {
    setPlaylists(prev => prev.filter(item => item.id !== playlistId));
    if (activeView === `playlist-${playlistId}`) setActiveView('all');
  };

  const addTrackToPlaylist = (playlistId, track) => {
    if (!track) return;
    setPlaylists(prev => prev.map(item => {
      if (item.id !== playlistId || item.tracks.some(existing => sameTrack(existing, track))) return item;
      return { ...item, tracks: [...item.tracks, track] };
    }));
  };

  const removeTrackFromPlaylist = (playlistId, trackId) => {
    setPlaylists(prev => prev.map(item => item.id === playlistId
      ? { ...item, tracks: item.tracks.filter(track => track.id !== trackId) }
      : item));
  };

  const currentTrackMediaKey = trackKey(currentTrack);
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    const track = latestPlaybackRef.current.currentTrack;
    const mediaKey = trackKey(track);
    const generation = mediaRequestGenerationRef.current + 1;
    mediaRequestGenerationRef.current = generation;
    activeMediaKeyRef.current = mediaKey;
    if (pendingRestoreRef.current && pendingRestoreRef.current.mediaKey !== mediaKey) {
      pendingRestoreRef.current = null;
    }

    const shouldAutoplay = pendingAutoplayRef.current || !audio.paused;
    pendingAutoplayRef.current = false;
    audio.pause();
    setProgress(0);
    setCurrentTime(0);
    setDuration(0);
    setHasVideoTrack(false);
    setShowVideo(false);

    if (!track?.url) {
      audio.removeAttribute('src');
      audio.load();
      return;
    }

    audio.src = resolveMediaUrl(track.url);
    audio.load();
    if (shouldAutoplay) attemptPlay(audio, 'Track transition');
  }, [attemptPlay, currentTrackMediaKey, mediaRequestVersion]);

  const prepareAudioGraph = () => {
    initWebAudio();
    if (audioContextRef.current?.state === 'suspended') {
      void audioContextRef.current.resume();
    }
  };

  const requestTrackTransition = (index, autoplay = true) => {
    if (!Number.isInteger(index) || !playlist[index]) return false;
    if (autoplay) prepareAudioGraph();
    pendingAutoplayRef.current = autoplay;
    setCurrentTrackIndex(index);
    setMediaRequestVersion(version => version + 1);
    return true;
  };

  const togglePlay = () => {
    const audio = audioRef.current;
    if (!audio || !currentTrack?.url) return;
    prepareAudioGraph();
    if (!audio.paused) {
      audio.pause();
    } else {
      attemptPlay(audio);
    }
  };

  const selectTrack = (index) => {
    requestTrackTransition(index, true);
  };

  const handlePrevTrack = () => {
    const audio = audioRef.current;
    if (!audio || playlist.length === 0) return;
    if (currentTime > 5) {
      audio.currentTime = 0;
      return;
    }
    const previousIndex = findPreviousPlayableIndex({
      tracks: playlist,
      currentIndex: currentTrackIndex,
      dislikedIds: dislikedTrackSet
    });
    if (previousIndex == null) {
      audio.pause();
      return;
    }
    requestTrackTransition(previousIndex, true);
  };

  const handleNextTrack = (autoEnded = false, dislikedIds = dislikedTrackSet) => {
    const audio = audioRef.current;
    if (!audio || playlist.length === 0) {
      audio?.pause();
      return;
    }
    if (autoEnded && isRepeat === 'one') {
      audio.currentTime = 0;
      prepareAudioGraph();
      attemptPlay(audio, 'Repeat-one playback');
      return;
    }

    const nextIndex = findNextPlayableIndex({
      tracks: playlist,
      currentIndex: currentTrackIndex,
      dislikedIds,
      shuffle: isShuffle,
      repeat: isRepeat,
      autoEnded
    });
    if (nextIndex == null) {
      audio.pause();
      return;
    }
    requestTrackTransition(nextIndex, true);
  };
  handleNextTrackRef.current = handleNextTrack;

  const seekTo = (value) => {
    const requested = Number(value);
    if (!audioRef.current || !Number.isFinite(duration) || duration <= 0 || !Number.isFinite(requested)) return;
    const percent = Math.min(100, Math.max(0, requested));
    const seconds = (percent / 100) * duration;
    audioRef.current.currentTime = seconds;
    setProgress(percent);
    setCurrentTime(seconds);
  };

  const handleVolumeChange = (value) => {
    const requested = Number(value);
    if (!Number.isFinite(requested)) return;
    const nextVolume = Math.min(1, Math.max(0, requested));
    setVolume(nextVolume);
    if (audioRef.current) {
      audioRef.current.volume = nextVolume;
      audioRef.current.muted = nextVolume === 0;
    }
    setIsMuted(nextVolume === 0);
  };

  const toggleMute = () => {
    if (!audioRef.current) return;
    const nextMuted = !isMuted;
    audioRef.current.muted = nextMuted;
    if (!nextMuted && audioRef.current.volume === 0) {
      const restored = volume > 0 ? volume : 0.5;
      audioRef.current.volume = restored;
      setVolume(restored);
    }
    setIsMuted(nextMuted);
  };

  const toggleDislike = (trackId) => {
    if (!trackId) return;
    const wasDisliked = dislikedTrackSet.has(trackId);
    const next = new Set(dislikedTrackSet);
    if (wasDisliked) next.delete(trackId);
    else next.add(trackId);
    setDislikedTracks(Array.from(next));
    if (!wasDisliked && currentTrack?.id === trackId) {
      handleNextTrack(false, next);
    }
  };

  const setTrackRating = (trackId, rating) => {
    if (!trackId) return;
    const numeric = Number(rating);
    if (!Number.isFinite(numeric)) return;
    const normalized = Math.min(5, Math.max(0, Math.round(numeric)));
    setTrackRatings(previous => ({ ...previous, [trackId]: normalized }));
  };

  const clearPlaylist = () => {
    mediaRequestGenerationRef.current += 1;
    pendingAutoplayRef.current = false;
    pendingRestoreRef.current = null;
    setPlaylist([]);
    setCurrentTrackIndex(0);
    currentTrackIdRef.current = null;
    if (audioRef.current) {
      audioRef.current.pause();
      audioRef.current.removeAttribute('src');
      audioRef.current.load();
    }
    setIsPlaying(false);
    setProgress(0);
    setCurrentTime(0);
    setDuration(0);
    setHasVideoTrack(false);
    setShowVideo(false);
  };

  const isRemovedTrack = (track, removedIDs, removedPaths) => Boolean(track) && (
    (track.id && removedIDs.has(track.id)) ||
    (track.path && removedPaths.has(track.path))
  );

  const removeTracksFromLibrary = (trackIds) => {
    const removedIDs = new Set(Array.from(trackIds || []).filter(Boolean));
    if (removedIDs.size === 0) return;
    const existingLibrary = libraryRef.current;
    const removedTracks = existingLibrary.filter(track => removedIDs.has(track.id));
    if (removedTracks.length === 0) return;
    const removedPaths = new Set(removedTracks.map(track => track.path).filter(Boolean));
    removedTracks.forEach(track => {
      if (track.url?.startsWith('blob:')) URL.revokeObjectURL(track.url);
    });
    const updatedLibrary = existingLibrary.filter(track => !removedIDs.has(track.id));
    libraryRef.current = updatedLibrary;
    setLibrary(updatedLibrary);
    setFavorites(previous => previous.filter(track => !isRemovedTrack(track, removedIDs, removedPaths)));
    setPlaylists(previous => previous.map(item => ({
      ...item,
      tracks: item.tracks.filter(track => !isRemovedTrack(track, removedIDs, removedPaths))
    })));
    setDislikedTracks(previous => previous.filter(id => !removedIDs.has(id)));
    setTrackRatings(previous => Object.fromEntries(Object.entries(previous).filter(([id]) => !removedIDs.has(id))));
    setPlaylist(previous => {
      const filtered = previous.filter(track => !isRemovedTrack(track, removedIDs, removedPaths));
      if (filtered.length === 0) {
        queueMicrotask(clearPlaylist);
        return [];
      }
      const currentID = currentTrackIdRef.current;
      const retainedIndex = currentID ? filtered.findIndex(track => track.id === currentID) : -1;
      setCurrentTrackIndex(retainedIndex >= 0 ? retainedIndex : Math.min(currentTrackIndex, filtered.length - 1));
      return filtered;
    });
  };

  const removeTrackFromLibrary = (trackId) => removeTracksFromLibrary([trackId]);
  const clearLibrary = () => removeTracksFromLibrary(libraryRef.current.map(track => track.id));

  const commitImportedTracks = (newTracks, autoplay = false) => {
    if (!Array.isArray(newTracks) || newTracks.length === 0) return false;
    const previous = libraryRef.current;
    const existingPaths = new Set(previous.map(track => track.path).filter(Boolean));
    const accepted = [];
    for (const track of newTracks) {
      if (track.path && existingPaths.has(track.path)) {
        if (track.url?.startsWith('blob:')) URL.revokeObjectURL(track.url);
        continue;
      }
      if (track.path) existingPaths.add(track.path);
      accepted.push(track);
    }
    if (accepted.length === 0) return false;
    const updated = [...previous, ...accepted];
    libraryRef.current = updated;
    if (autoplay) prepareAudioGraph();
    pendingAutoplayRef.current = autoplay;
    setLibrary(updated);
    setPlaylist(updated);
    setActiveView('library');
    setPlaybackSource('library');
    setCurrentTrackIndex(previous.length);
    setMediaRequestVersion(version => version + 1);
    return true;
  };

  const importLocalFilesByPaths = async (filePaths) => {
    const filtered = Array.from(new Set(filePaths || [])).filter(filePath =>
      typeof filePath === 'string' && LOCAL_MEDIA_EXTENSIONS.has(fileExtension(filePath))
    );
    if (filtered.length === 0) {
      setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
      return false;
    }
    setLoadingState({ active: true, current: 0, total: filtered.length, percent: 0, phase: 'importing' });
    const newTracks = [];
    const batchSize = 50;
    for (let i = 0; i < filtered.length; i += batchSize) {
      const batch = filtered.slice(i, i + batchSize);
      for (const filePath of batch) {
        const fileName = filePath.replace(/\\/g, '/').split('/').pop() || 'Local Track';
        const dot = fileName.lastIndexOf('.');
        const nameWithoutExt = dot > 0 ? fileName.slice(0, dot) : fileName;
        const parts = nameWithoutExt.split(' - ');
        const artist = parts.length >= 2 ? parts[0].trim() : 'Unknown Artist';
        const title = parts.length >= 2 ? parts.slice(1).join(' - ').trim() : (parts[0].trim() || 'Local Track');
        newTracks.push({
          id: localTrackID(), title, artist, album: 'Local Import', cover: defaultCover,
          url: window.electronAPI?.toMediaUrl ? window.electronAPI.toMediaUrl(filePath) : `file://${filePath.replace(/\\/g, '/')}`,
          path: filePath,
          colors: [0, 1, 2].map(() => `hsl(${Math.floor(Math.random() * 360)}, 80%, 45%)`),
          duration: '--:--'
        });
      }
      const current = Math.min(i + batchSize, filtered.length);
      setLoadingState({ active: true, current, total: filtered.length, percent: Math.round((current / filtered.length) * 100), phase: 'importing' });
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    const added = commitImportedTracks(newTracks, true);
    setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
    return added;
  };

  const importLocalFiles = async (files) => {
    const fileArray = Array.from(files || []).filter(file => {
      const type = String(file.type || '').toLowerCase();
      return type.startsWith('audio/') || type.startsWith('video/') || LOCAL_MEDIA_EXTENSIONS.has(fileExtension(file.name));
    });
    if (fileArray.length === 0) return false;

    if (window.electronAPI?.registerSelectedFiles) {
      try {
        const registered = await window.electronAPI.registerSelectedFiles(fileArray);
        const paths = registered.filter(entry => !entry.isDirectory).map(entry => entry.path);
        if (paths.length === fileArray.length && paths.length > 0) {
          return importLocalFilesByPaths(paths);
        }
      } catch (error) {
        console.warn('Could not register selected disk files, using transient blobs:', error);
      }
    }

    setLoadingState({ active: true, current: 0, total: fileArray.length, percent: 0, phase: 'importing' });
    const newTracks = [];
    const batchSize = 8;
    for (let i = 0; i < fileArray.length; i += batchSize) {
      const batch = fileArray.slice(i, i + batchSize);
      for (const file of batch) {
        const dot = file.name.lastIndexOf('.');
        const nameWithoutExt = dot > 0 ? file.name.slice(0, dot) : file.name;
        const parts = nameWithoutExt.split(' - ');
        const artist = parts.length >= 2 ? parts[0].trim() : 'Unknown Artist';
        const title = parts.length >= 2 ? parts.slice(1).join(' - ').trim() : (parts[0].trim() || 'Local Track');
        newTracks.push({
          id: localTrackID(), title, artist, album: 'Local Import', cover: defaultCover,
          url: URL.createObjectURL(file), path: '',
          colors: [0, 1, 2].map(() => `hsl(${Math.floor(Math.random() * 360)}, 80%, 45%)`),
          duration: '--:--'
        });
      }
      const current = Math.min(i + batchSize, fileArray.length);
      setLoadingState({ active: true, current, total: fileArray.length, percent: Math.round((current / fileArray.length) * 100), phase: 'importing' });
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    const added = commitImportedTracks(newTracks, true);
    setLoadingState({ active: false, current: 0, total: 0, percent: 0, phase: 'scanning' });
    return added;
  };

  const cycleRepeat = () => setIsRepeat(previous => previous === false ? true : (previous === true ? 'one' : false));

  const playTrackInList = (targetPlaylist, index, sourceView = null) => {
    if (!Array.isArray(targetPlaylist) || !Number.isInteger(index) || !targetPlaylist[index]) return;
    prepareAudioGraph();
    pendingAutoplayRef.current = true;
    setPlaylist(targetPlaylist);
    setCurrentTrackIndex(index);
    setMediaRequestVersion(version => version + 1);
    if (sourceView) setPlaybackSource(sourceView);
  };

  const syncPlaylist = useCallback((newPlaylist) => {
    const normalized = Array.isArray(newPlaylist) ? newPlaylist : [];
    if (normalized.length === 0) {
      mediaRequestGenerationRef.current += 1;
      pendingAutoplayRef.current = false;
      pendingRestoreRef.current = null;
      setPlaylist([]);
      setCurrentTrackIndex(0);
      currentTrackIdRef.current = null;
      audioRef.current?.pause();
      if (audioRef.current) {
        audioRef.current.removeAttribute('src');
        audioRef.current.load();
      }
      setIsPlaying(false);
      setProgress(0);
      setCurrentTime(0);
      setDuration(0);
      return;
    }
    setPlaylist(previous => {
      if (previous.length === normalized.length && previous.every((track, index) => trackKey(track) === trackKey(normalized[index]))) {
        return previous;
      }
      const currentID = currentTrackIdRef.current;
      const nextIndex = currentID ? normalized.findIndex(track => track.id === currentID) : -1;
      setCurrentTrackIndex(nextIndex >= 0 ? nextIndex : 0);
      return normalized;
    });
  }, []);

  const playNext = (track) => {
    if (!track) return;
    setPlaylist(previous => {
      if (previous.length === 0) return [track];
      const activeTrack = previous[currentTrackIndex];
      const filtered = previous.filter((item, index) => !sameTrack(item, track) || index === currentTrackIndex);
      let activeIndex = activeTrack ? filtered.findIndex(item => sameTrack(item, activeTrack)) : currentTrackIndex;
      if (activeIndex < 0) activeIndex = Math.min(currentTrackIndex, filtered.length - 1);
      setCurrentTrackIndex(Math.max(0, activeIndex));
      const updated = [...filtered];
      updated.splice(Math.max(0, activeIndex) + 1, 0, track);
      return updated;
    });
  };

  const initialVideoPosition = clampVideoPosition(
    { x: window.innerWidth - 410, y: 80 },
    { width: window.innerWidth, height: window.innerHeight }
  );
  const videoPositionRef = useRef(initialVideoPosition);
  const videoWindowRef = useRef(null);
  const isDragging = useRef(false);
  const dragStart = useRef({ x: 0, y: 0 });
  const rafPositionUpdater = useRef(null);
  const handleMouseMoveRef = useRef(null);
  const handleMouseUpRef = useRef(null);

  const getVideoViewport = useCallback(() => ({
    width: document.documentElement.clientWidth || window.innerWidth,
    height: document.documentElement.clientHeight || window.innerHeight
  }), []);
  const getVideoWindowSize = useCallback(() => {
    const bounds = videoWindowRef.current?.getBoundingClientRect();
    return { width: bounds?.width || 380, height: bounds?.height || 240 };
  }, []);
  const applyVideoPosition = useCallback((position) => {
    if (!videoWindowRef.current) return;
    videoWindowRef.current.style.setProperty('--video-position-x', `${position.x}px`);
    videoWindowRef.current.style.setProperty('--video-position-y', `${position.y}px`);
  }, []);

  if (!rafPositionUpdater.current) {
    rafPositionUpdater.current = createRafThrottledUpdater(
      applyVideoPosition,
      callback => window.requestAnimationFrame(callback),
      frameId => window.cancelAnimationFrame(frameId)
    );
  }

  useLayoutEffect(() => {
    applyVideoPosition(videoPositionRef.current);
  }, [applyVideoPosition]);

  const handleMouseMove = useCallback((event) => {
    if (!isDragging.current) return;
    const next = clampVideoPosition(
      { x: event.clientX - dragStart.current.x, y: event.clientY - dragStart.current.y },
      getVideoViewport(), getVideoWindowSize()
    );
    videoPositionRef.current = next;
    rafPositionUpdater.current?.(next);
  }, [getVideoViewport, getVideoWindowSize]);

  const handleMouseUp = useCallback(() => {
    if (!isDragging.current) return;
    isDragging.current = false;
    videoWindowRef.current?.removeAttribute('data-dragging');
    if (handleMouseMoveRef.current) document.removeEventListener('mousemove', handleMouseMoveRef.current);
    if (handleMouseUpRef.current) document.removeEventListener('mouseup', handleMouseUpRef.current);
  }, []);
  handleMouseMoveRef.current = handleMouseMove;
  handleMouseUpRef.current = handleMouseUp;

  const handleMouseDown = useCallback((event) => {
    if (event.button !== 0) return;
    isDragging.current = true;
    videoWindowRef.current?.setAttribute('data-dragging', 'true');
    const position = videoPositionRef.current;
    dragStart.current = { x: event.clientX - position.x, y: event.clientY - position.y };
    document.addEventListener('mousemove', handleMouseMoveRef.current);
    document.addEventListener('mouseup', handleMouseUpRef.current);
  }, []);

  useEffect(() => () => {
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
    rafPositionUpdater.current?.cancel?.();
  }, [handleMouseMove, handleMouseUp]);

  useEffect(() => {
    const handleResize = () => {
      const next = clampVideoPosition(videoPositionRef.current, getVideoViewport(), getVideoWindowSize());
      videoPositionRef.current = next;
      applyVideoPosition(next);
    };
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, [applyVideoPosition, getVideoViewport, getVideoWindowSize]);

  return (
    <AudioContext.Provider value={{
      playlist, setPlaylist, currentTrack, currentTrackIndex, setCurrentTrackIndex,
      isPlaying, progress, currentTime, duration, volume, isMuted, isShuffle, isRepeat,
      eqPreset, setEqPreset, togglePlay, selectTrack, prevTrack: handlePrevTrack,
      nextTrack: () => handleNextTrack(false), seekTo, setVolume: handleVolumeChange,
      toggleMute, toggleShuffle: () => setIsShuffle(previous => !previous), cycleRepeat,
      importLocalFiles, importLocalFilesByPaths, loadingState, setLoadingState,
      showVideo, hasVideoTrack, setShowVideo, favorites, playlists, library, setLibrary,
      activeView, setActiveView, toggleFavorite, createPlaylist, deletePlaylist,
      addTrackToPlaylist, removeTrackFromPlaylist, playTrackInList,
      removeTrackFromLibrary, removeTracksFromLibrary, playNext, playbackSource, syncPlaylist,
      sleepTimerEndsAt, setSleepTimerEndsAt, dislikedTracks, toggleDislike,
      trackRatings, setTrackRating, clearPlaylist, clearLibrary
    }}>
      {children}
      <div
        className="floating-video-window"
        ref={videoWindowRef}
        style={{
          position: 'fixed', left: 0, top: 0,
          transform: 'translate3d(var(--video-position-x), var(--video-position-y), 0)',
          borderRadius: '16px', border: '1px solid rgba(255, 255, 255, 0.12)',
          boxShadow: '0 24px 64px rgba(0, 0, 0, 0.6)', background: 'rgba(28, 30, 38, 0.85)',
          backdropFilter: 'blur(30px)', WebkitBackdropFilter: 'blur(30px)', zIndex: 10000,
          display: (showVideo && hasVideoTrack) ? 'flex' : 'none', flexDirection: 'column',
          transition: 'opacity 0.2s ease', WebkitAppRegion: 'no-drag'
        }}
        id="floating-video-window"
      >
        <div
          onMouseDown={handleMouseDown}
          style={{
            height: '32px', background: 'rgba(255, 255, 255, 0.03)',
            borderBottom: '1px solid rgba(255, 255, 255, 0.08)', display: 'flex',
            alignItems: 'center', justifyContent: 'space-between', padding: '0 12px',
            fontSize: '11px', color: 'var(--text-secondary)', fontWeight: 600,
            userSelect: 'none', cursor: 'move', WebkitAppRegion: 'no-drag'
          }}
        >
          <span>CMVPlayer - 影片播放視窗 (拖曳移動)</span>
          <button
            onClick={() => setShowVideo(false)}
            onMouseDown={event => event.stopPropagation()}
            style={{
              border: 'none', background: 'rgba(255, 255, 255, 0.1)', borderRadius: '4px',
              padding: '2px 6px', color: '#fff', fontSize: '10px', cursor: 'pointer',
              fontWeight: 600, transition: 'background 0.2s'
            }}
            onMouseEnter={event => { event.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)'; }}
            onMouseLeave={event => { event.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)'; }}
          >隱藏</button>
        </div>
        <video
          ref={videoRef}
          style={{
            flex: 1, width: '100%', height: 'calc(100% - 32px)', background: '#000',
            objectFit: 'contain', borderBottomLeftRadius: '16px', borderBottomRightRadius: '16px'
          }}
        />
      </div>
    </AudioContext.Provider>
  );
};

export const useAudio = () => {
  const context = useContext(AudioContext);
  if (!context) throw new Error('useAudio must be used within an AudioProvider');
  return context;
};
