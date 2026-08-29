import React, { useEffect, useRef, useState } from 'react';
import { Disc, Flame, Headphones, Play, Save, Search, Trash2, Volume2 } from 'lucide-react';
import { useAudio } from '../context/AudioContext';
import defaultCover from '../assets/default-cover.svg';
import './ListenNow.css';

const ListenNow = () => {
  const { playlist, currentTrack, currentTrackIndex, isPlaying, selectTrack, clearPlaylist, createPlaylist } = useAudio();
  const [searchQuery, setSearchQuery] = useState('');
  const [isSaveDialogOpen, setIsSaveDialogOpen] = useState(false);
  const [playlistName, setPlaylistName] = useState('新歌單');
  const savePlaylistButtonRef = useRef(null);
  const playlistNameInputRef = useRef(null);
  const restoreFocusAfterDialogRef = useRef(false);

  const normalizedSearchQuery = searchQuery.toLocaleLowerCase();
  const filteredPlaylist = playlist.filter((track) => {
    const title = track.title || '';
    const artist = track.artist || '';
    return title.toLocaleLowerCase().includes(normalizedSearchQuery) ||
      artist.toLocaleLowerCase().includes(normalizedSearchQuery);
  });

  const openSaveDialog = () => {
    setPlaylistName('新歌單');
    setIsSaveDialogOpen(true);
  };

  const closeSaveDialog = () => {
    restoreFocusAfterDialogRef.current = true;
    setIsSaveDialogOpen(false);
    setPlaylistName('');
  };

  useEffect(() => {
    if (isSaveDialogOpen) {
      playlistNameInputRef.current?.focus();
      return;
    }

    if (restoreFocusAfterDialogRef.current) {
      restoreFocusAfterDialogRef.current = false;
      savePlaylistButtonRef.current?.focus();
    }
  }, [isSaveDialogOpen]);

  const handleDialogKeyDown = (event) => {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeSaveDialog();
      return;
    }

    if (event.key !== 'Tab') return;

    const focusableSelector = 'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), a[href], [tabindex]:not([tabindex="-1"])';
    const focusableElements = [...event.currentTarget.querySelectorAll(focusableSelector)];
    if (focusableElements.length === 0) {
      event.preventDefault();
      return;
    }

    const firstFocusable = focusableElements[0];
    const lastFocusable = focusableElements[focusableElements.length - 1];
    if (event.shiftKey && document.activeElement === firstFocusable) {
      event.preventDefault();
      lastFocusable.focus();
    } else if (!event.shiftKey && document.activeElement === lastFocusable) {
      event.preventDefault();
      firstFocusable.focus();
    }
  };

  const savePlaylist = () => {
    const name = playlistName.trim();
    if (!name) return;
    createPlaylist(name, playlist);
    closeSaveDialog();
  };

  const playFirstTrack = () => {
    if (playlist.length > 0) selectTrack(0);
  };

  return (
    <section className="listen-now" aria-labelledby="main-heading">
      <header className="listen-header">
        <div>
          <p className="eyebrow">CMVMUSIC / LISTENING ROOM</p>
          <h1 id="main-heading">現在收聽</h1>
        </div>
        <label className="listen-search">
          <Search size={16} aria-hidden="true" />
          <span className="sr-only">搜尋歌曲或藝術家</span>
          <input
            id="search-input"
            type="search"
            placeholder="搜尋歌曲、藝術家…"
            value={searchQuery}
            onChange={(event) => setSearchQuery(event.target.value)}
          />
        </label>
      </header>

      <section className="listen-hero" aria-labelledby="hero-title">
        <div className="hero-copy">
          <p className="eyebrow eyebrow-accent"><span className="eyebrow-mark" />CURRENTLY PLAYING</p>
          <h2 id="hero-title">寫程式的極致專注旋律</h2>
          <p className="hero-description">
            夜深了，讓一張剛好的唱片替你留住專注。把燈調暗，戴上耳機，慢慢寫出今天最好的版本。
          </p>
          <button className="button button-primary" type="button" onClick={playFirstTrack} disabled={!playlist.length} id="hero-play-btn">
            <Play size={15} fill="currentColor" aria-hidden="true" />
            立即播第一首
          </button>
        </div>
        <div className="hero-sleeve" aria-label={currentTrack?.title ? `目前曲目：${currentTrack.title}` : '尚未選取曲目'}>
          <div className="hero-sleeve-shadow" />
          <img
            key={currentTrack?.id || 'default-cover'}
            src={currentTrack?.cover || defaultCover}
            onError={(event) => {
              if (event.currentTarget.dataset.fallbackApplied) return;
              event.currentTarget.dataset.fallbackApplied = 'true';
              event.currentTarget.src = defaultCover;
            }}
            alt={currentTrack?.title ? `${currentTrack.title} 封面` : '預設唱片封面'}
          />
          <div className="hero-sleeve-label">
            <span>{currentTrack ? 'NOW SPINNING' : 'CMVMUSIC'}</span>
            <strong>{currentTrack?.title || '深夜選曲'}</strong>
          </div>
        </div>
      </section>

      <section className="queue-section" aria-labelledby="queue-title">
        <div className="section-heading">
          <div>
            <p className="eyebrow">YOUR SELECTION</p>
            <h3 id="queue-title"><Flame size={17} aria-hidden="true" /> 目前播放佇列 <span>({playlist.length})</span></h3>
          </div>
          <div className="queue-actions">
            <button
              className="button button-quiet"
              type="button"
              ref={savePlaylistButtonRef}
              onClick={openSaveDialog}
            >
              <Save size={14} aria-hidden="true" /> 儲存佇列
            </button>
            <button
              className="button button-danger"
              type="button"
              onClick={() => {
                if (window.confirm('確定要清空目前的播放佇列嗎？')) clearPlaylist();
              }}
            >
              <Trash2 size={14} aria-hidden="true" /> 清空
            </button>
          </div>
        </div>

        {isSaveDialogOpen && (
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="save-playlist-title"
            onKeyDown={handleDialogKeyDown}
            style={{
              position: 'fixed',
              inset: 0,
              zIndex: 10,
              display: 'grid',
              placeItems: 'center',
              padding: '24px',
              background: 'rgba(0, 0, 0, 0.45)'
            }}
            onMouseDown={(event) => {
              if (event.target === event.currentTarget) closeSaveDialog();
            }}
          >
            <form
              onSubmit={(event) => { event.preventDefault(); savePlaylist(); }}
              style={{
                width: 'min(100%, 360px)',
                padding: '24px',
                border: '1px solid var(--listen-line)',
                borderRadius: '8px',
                background: 'var(--listen-panel)',
                boxShadow: '0 20px 60px rgba(0, 0, 0, 0.35)'
              }}
            >
              <h4 id="save-playlist-title" style={{ marginBottom: '16px', fontSize: '16px' }}>儲存播放佇列</h4>
              <label style={{ display: 'grid', gap: '8px', color: 'var(--listen-muted)', fontSize: '12px' }}>
                播放清單名稱
                <input
                  type="text"
                  ref={playlistNameInputRef}
                  value={playlistName}
                  onChange={(event) => setPlaylistName(event.target.value)}
                  aria-label="播放清單名稱"
                  style={{
                    width: '100%',
                    padding: '10px 11px',
                    border: '1px solid var(--listen-line)',
                    borderRadius: '3px',
                    color: 'var(--listen-ink)',
                    background: 'var(--listen-surface-subtle)',
                    outlineColor: 'var(--listen-accent)'
                  }}
                />
              </label>
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px', marginTop: '20px' }}>
                <button className="button button-quiet" type="button" onClick={closeSaveDialog}>取消</button>
                <button className="button button-primary" type="submit" disabled={!playlistName.trim()}>儲存</button>
              </div>
            </form>
          </div>
        )}

        {filteredPlaylist.length > 0 ? (
          <div className="tracks-grid" id="tracks-grid">
            {filteredPlaylist.map((track, index) => {
              const trackIdx = playlist.findIndex((item) => item.id === track.id);
              const isCurrentTrack = trackIdx === currentTrackIndex;
              const isPlayingThis = isCurrentTrack && isPlaying;
              const title = track.title || '未命名歌曲';
              const artist = track.artist || '未知藝術家';
              return (
                <article
                  className={`track-card ${!searchQuery && index === 0 ? 'track-card-featured' : ''} ${isCurrentTrack ? 'is-current' : ''}`}
                  key={track.id}
                  role="button"
                  tabIndex={0}
                  onClick={() => selectTrack(trackIdx)}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter' || event.key === ' ') {
                      event.preventDefault();
                      selectTrack(trackIdx);
                    }
                  }}
                >
                  <div className="track-art-wrap">
                    <img
                      className="track-art"
                      key={track.id}
                      src={track.cover || defaultCover}
                      onError={(event) => {
                        if (event.currentTarget.dataset.fallbackApplied) return;
                        event.currentTarget.dataset.fallbackApplied = 'true';
                        event.currentTarget.src = defaultCover;
                      }}
                      alt={`${title} 封面`}
                    />
                    <div className="track-overlay" aria-hidden="true">
                      <span className="track-play-icon">
                        {isPlayingThis ? <Volume2 size={18} /> : <Play size={18} fill="currentColor" />}
                      </span>
                    </div>
                    <span className="track-index">{String(trackIdx + 1).padStart(2, '0')}</span>
                  </div>
                  <div className="track-info">
                    <h4 title={title}>{title}</h4>
                    <p title={artist}>{artist}</p>
                  </div>
                  {isCurrentTrack && <span className="playing-label">{isPlaying ? 'PLAYING' : 'PAUSED'}</span>}
                </article>
              );
            })}
          </div>
        ) : (
          <div className="empty-state" role="status">
            <Search size={22} aria-hidden="true" />
            <h4>{playlist.length ? '找不到符合的歌曲' : '播放佇列目前是空的'}</h4>
            <p>{playlist.length ? '試試其他歌名或藝術家關鍵字。' : '從本地音樂庫加入歌曲，就能在這裡開始播放。'}</p>
            {searchQuery && <button className="button button-quiet" type="button" onClick={() => setSearchQuery('')}>清除搜尋</button>}
          </div>
        )}
      </section>

      <section className="studio-section" aria-labelledby="studio-title">
        <div className="section-heading section-heading-studio">
          <div>
            <p className="eyebrow">THE LISTENING STUDIO</p>
            <h3 id="studio-title">播放器工作台</h3>
          </div>
        </div>
        <div className="studio-grid">
          <article className="studio-note">
            <Disc size={17} aria-hidden="true" />
            <div><h4>唱片封套視覺</h4><p>以目前曲目封面作為房間的視覺錨點，讓每次切歌都有清楚的章節感。</p></div>
          </article>
          <article className="studio-note">
            <Headphones size={17} aria-hidden="true" />
            <div><h4>Web Audio 等化器</h4><p>標準、人聲加強與重低音預設，讓聲音在夜裡依然保有層次。</p></div>
          </article>
          <article className="studio-note">
            <span className="studio-number">03</span>
            <div><h4>本地 MP3 即時讀取</h4><p>把自己的音樂帶進來，佇列會沿用同一套安靜、清晰的工作台。</p></div>
          </article>
        </div>
      </section>
    </section>
  );
};

export default ListenNow;
