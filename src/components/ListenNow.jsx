import React, { useState } from 'react';
import { Disc, Flame, Headphones, Play, Save, Search, Trash2, Volume2 } from 'lucide-react';
import { useAudio } from '../context/AudioContext';
import defaultCover from '../assets/default-cover.svg';
import './ListenNow.css';

const ListenNow = () => {
  const { playlist, currentTrack, currentTrackIndex, isPlaying, selectTrack, clearPlaylist, createPlaylist } = useAudio();
  const [searchQuery, setSearchQuery] = useState('');

  const filteredPlaylist = playlist.filter((track) =>
    track.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    track.artist.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const playFirstTrack = () => {
    if (playlist.length > 0) selectTrack(0);
  };

  return (
    <main className="listen-now" aria-labelledby="main-heading">
      <header className="listen-header">
        <div>
          <p className="eyebrow">AEROMUSIC / LISTENING ROOM</p>
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
        <div className="hero-sleeve" aria-label={currentTrack ? `目前曲目：${currentTrack.title}` : '尚未選取曲目'}>
          <div className="hero-sleeve-shadow" />
          <img
            src={currentTrack?.cover || defaultCover}
            onError={(event) => { event.currentTarget.src = defaultCover; }}
            alt={currentTrack ? `${currentTrack.title} 封面` : '預設唱片封面'}
          />
          <div className="hero-sleeve-label">
            <span>{currentTrack ? 'NOW SPINNING' : 'AEROMUSIC'}</span>
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
              onClick={() => {
                const name = prompt('請輸入新播放清單名稱：', '新歌單');
                if (name) {
                  createPlaylist(name, playlist);
                  alert(`歌單「${name}」已成功儲存！`);
                }
              }}
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

        {filteredPlaylist.length > 0 ? (
          <div className="tracks-grid" id="tracks-grid">
            {filteredPlaylist.map((track, index) => {
              const trackIdx = playlist.findIndex((item) => item.id === track.id);
              const isCurrentTrack = trackIdx === currentTrackIndex;
              const isPlayingThis = isCurrentTrack && isPlaying;
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
                      src={track.cover || defaultCover}
                      onError={(event) => { event.currentTarget.src = defaultCover; }}
                      alt={`${track.title} 封面`}
                    />
                    <div className="track-overlay" aria-hidden="true">
                      <span className="track-play-icon">
                        {isPlayingThis ? <Volume2 size={18} /> : <Play size={18} fill="currentColor" />}
                      </span>
                    </div>
                    <span className="track-index">{String(trackIdx + 1).padStart(2, '0')}</span>
                  </div>
                  <div className="track-info">
                    <h4 title={track.title}>{track.title}</h4>
                    <p title={track.artist}>{track.artist}</p>
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
    </main>
  );
};

export default ListenNow;
