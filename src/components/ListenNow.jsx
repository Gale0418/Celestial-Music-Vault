import React, { useState } from 'react';
import { Search, Play, Volume2, Sparkles, Flame, Headphones, Disc, Trash2, Save } from 'lucide-react';
import { useAudio } from '../context/AudioContext';

const ListenNow = () => {
  const { playlist, currentTrackIndex, isPlaying, selectTrack, togglePlay, clearPlaylist, createPlaylist } = useAudio();
  const [searchQuery, setSearchQuery] = useState('');

  const filteredPlaylist = playlist.filter(track => 
    track.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    track.artist.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div style={{
      padding: '40px 30px',
      height: '100%',
      overflowY: 'auto',
      width: '100%',
      position: 'relative',
      zIndex: 1
    }}>
      {/* TOP HEADER: Page Title & Search Bar */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '32px'
      }}>
        <h1 style={{
          fontFamily: 'var(--font-display)',
          fontSize: '32px',
          fontWeight: 800,
          background: 'linear-gradient(135deg, #fff 0%, #a1a1a6 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          letterSpacing: '-1px'
        }} id="main-heading">
          現在收聽
        </h1>

        {/* Search Bar */}
        <div style={{
          position: 'relative',
          width: '260px'
        }}>
          <input
            type="text"
            placeholder="搜尋歌曲、藝術家..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{
              width: '100%',
              padding: '8px 16px 8px 36px',
              borderRadius: '20px',
              background: 'rgba(255,255,255,0.06)',
              border: '1px solid var(--border-glass)',
              color: '#fff',
              fontSize: '13px',
              outline: 'none',
              transition: 'all 0.25s ease'
            }}
            onFocus={(e) => {
              e.target.style.background = 'rgba(255,255,255,0.12)';
              e.target.style.borderColor = 'rgba(255,255,255,0.25)';
              e.target.style.boxShadow = '0 0 10px rgba(255,255,255,0.1)';
            }}
            onBlur={(e) => {
              e.target.style.background = 'rgba(255,255,255,0.06)';
              e.target.style.borderColor = 'var(--border-glass)';
              e.target.style.boxShadow = 'none';
            }}
            id="search-input"
          />
          <Search size={14} style={{
            position: 'absolute',
            left: '12px',
            top: '50%',
            transform: 'translateY(-50%)',
            color: 'var(--text-muted)'
          }} />
        </div>
      </div>

      {/* HERO BANNER CARD */}
      <div className="glow-loading" style={{
        background: 'linear-gradient(135deg, rgba(255,45,85,0.3) 0%, rgba(175,82,222,0.3) 50%, rgba(0,122,255,0.2) 100%)',
        border: '1px solid rgba(255,255,255,0.12)',
        borderRadius: 'var(--radius-lg)',
        padding: '32px 40px',
        marginBottom: '36px',
        position: 'relative',
        overflow: 'hidden',
        boxShadow: 'var(--shadow-card)',
        backdropFilter: 'blur(10px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: '20px'
      }}>
        {/* Floating gradient orb in card */}
        <div style={{
          position: 'absolute',
          top: '-20%',
          right: '10%',
          width: '200px',
          height: '200px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(255,45,85,0.4) 0%, transparent 70%)',
          filter: 'blur(40px)',
          zIndex: 0
        }} />

        <div style={{ position: 'relative', zIndex: 1, flex: 1 }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            color: 'var(--primary-color)',
            fontSize: '12px',
            fontWeight: 700,
            textTransform: 'uppercase',
            letterSpacing: '1.5px',
            marginBottom: '10px'
          }}>
            <Sparkles size={14} />
            <span>GENIUS PLAYLIST</span>
          </div>
          
          <h2 style={{
            fontSize: '26px',
            fontWeight: 800,
            color: '#fff',
            marginBottom: '10px',
            lineHeight: 1.3,
            letterSpacing: '-0.5px'
          }}>
            寫程式的極致專注旋律
          </h2>
          
          <p style={{
            color: 'var(--text-secondary)',
            fontSize: '14px',
            lineHeight: 1.5,
            maxWidth: '480px',
            marginBottom: '20px'
          }}>
            「真是拿你沒辦法，主人！我都特地幫你整理出這些超級棒的 Lofi 輕音樂了，就請主人一邊聽一邊好好寫出頂級的 Code 吧！我們一起加油！💕」
          </p>

          <button
            onClick={() => selectTrack(0)}
            style={{
              padding: '10px 22px',
              borderRadius: '20px',
              border: 'none',
              background: '#fff',
              color: '#000',
              fontWeight: 700,
              fontSize: '13px',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
              boxShadow: '0 4px 12px rgba(255,255,255,0.2)',
              transition: 'transform 0.2s'
            }}
            onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.05)'}
            onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
            id="hero-play-btn"
          >
            <Play size={14} fill="#000" />
            <span>立即播第一首</span>
          </button>
        </div>

        <div style={{ position: 'relative', zIndex: 1, display: 'none', mdDisplay: 'block' }}>
          <div style={{
            width: '120px',
            height: '120px',
            borderRadius: '20px',
            background: 'var(--bg-glass-active)',
            border: '1px solid rgba(255,255,255,0.1)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: 'var(--shadow-card)'
          }}>
            <Headphones size={48} color="rgba(255,255,255,0.6)" />
          </div>
        </div>
      </div>

      {/* FEATURED TRACKS SECTION */}
      <div style={{ marginBottom: '36px' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '16px'
        }}>
          <h3 style={{
            fontSize: '20px',
            fontWeight: 700,
            color: '#fff',
            display: 'flex',
            alignItems: 'center',
            gap: '8px'
          }}>
            <Flame size={18} color="var(--primary-color)" />
            <span>目前播放佇列 ({playlist.length})</span>
          </h3>

          <div style={{ display: 'flex', gap: '8px' }}>
            <button
              onClick={() => {
                const name = prompt('請輸入新播放清單名稱：', '新歌單');
                if (name) {
                  const newPl = createPlaylist(name, playlist);
                  alert(`歌單 "${name}" 已成功儲存！`);
                }
              }}
              style={{
                background: 'rgba(255, 255, 255, 0.1)',
                border: 'none',
                color: '#fff',
                padding: '6px 12px',
                borderRadius: '8px',
                fontSize: '12px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                transition: 'background 0.2s'
              }}
              onMouseEnter={e => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.2)'}
              onMouseLeave={e => e.currentTarget.style.background = 'rgba(255, 255, 255, 0.1)'}
            >
              <Save size={14} /> 儲存佇列
            </button>
            <button
              onClick={() => {
                if (window.confirm('確定要清空目前的播放佇列嗎？')) {
                  clearPlaylist();
                }
              }}
              style={{
                background: 'rgba(255, 59, 48, 0.15)',
                border: '1px solid rgba(255, 59, 48, 0.3)',
                color: '#ff3b30',
                padding: '6px 12px',
                borderRadius: '8px',
                fontSize: '12px',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '6px',
                transition: 'background 0.2s'
              }}
              onMouseEnter={e => e.currentTarget.style.background = 'rgba(255, 59, 48, 0.25)'}
              onMouseLeave={e => e.currentTarget.style.background = 'rgba(255, 59, 48, 0.15)'}
            >
              <Trash2 size={14} /> 清空
            </button>
          </div>
        </div>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))',
          gap: '20px'
        }} id="tracks-grid">
          {filteredPlaylist.map((track) => {
            const trackIdx = playlist.findIndex(t => t.id === track.id);
            const isCurrentTrack = trackIdx === currentTrackIndex;
            const isPlayingThis = isCurrentTrack && isPlaying;
            
            return (
              <div
                key={track.id}
                className="glass-card"
                onClick={() => selectTrack(trackIdx)}
                style={{
                  padding: '16px',
                  cursor: 'pointer',
                  position: 'relative'
                }}
              >
                {/* Album Cover Container with Hover Overlay */}
                <div style={{
                  position: 'relative',
                  width: '100%',
                  paddingBottom: '100%',
                  borderRadius: '12px',
                  overflow: 'hidden',
                  marginBottom: '12px',
                  boxShadow: '0 4px 12px rgba(0,0,0,0.3)'
                }}>
                  <img
                    src={track.cover}
                    alt={track.title}
                    style={{
                      position: 'absolute',
                      top: 0,
                      left: 0,
                      width: '100%',
                      height: '100%',
                      objectFit: 'cover'
                    }}
                  />
                  {/* Hover Overlay */}
                  <div style={{
                    position: 'absolute',
                    top: 0,
                    left: 0,
                    width: '100%',
                    height: '100%',
                    backgroundColor: 'rgba(0,0,0,0.4)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    opacity: isPlayingThis ? 1 : 0,
                    transition: 'opacity 0.25s ease',
                    borderRadius: '12px'
                  }}
                  className="play-overlay"
                  >
                    <div style={{
                      background: 'var(--primary-gradient)',
                      width: '42px',
                      height: '42px',
                      borderRadius: '50%',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      boxShadow: '0 4px 10px var(--primary-glow)'
                    }}>
                      {isPlayingThis ? (
                        <Volume2 size={18} color="#fff" />
                      ) : (
                        <Play size={18} fill="#fff" color="#fff" style={{ marginLeft: '2px' }} />
                      )}
                    </div>
                  </div>
                </div>

                {/* Info */}
                <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  <h4 style={{
                    fontSize: '14px',
                    fontWeight: 600,
                    color: isCurrentTrack ? 'var(--primary-color)' : '#fff',
                    marginBottom: '4px'
                  }}>
                    {track.title}
                  </h4>
                  <p style={{
                    fontSize: '12px',
                    color: 'var(--text-secondary)'
                  }}>
                    {track.artist}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* TECH FEATURES SECTION */}
      <div>
        <h3 style={{
          fontSize: '18px',
          fontWeight: 700,
          color: '#fff',
          marginBottom: '16px'
        }}>
          🔧 天才級播放器黑科技
        </h3>

        <div style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
          gap: '16px'
        }}>
          {/* Card 1 */}
          <div className="glass-card" style={{ padding: '16px 20px', background: 'rgba(255,255,255,0.03)' }}>
            <h4 style={{ fontSize: '14px', fontWeight: 600, color: 'var(--primary-color)', marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Disc size={16} />
              <span>Apple Dynamic Flow</span>
            </h4>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              背景會自動提取當前播放歌曲的色彩，產生出夢幻且平滑的流動漸層效果，讓主人的眼睛隨時享受大師級的視覺盛宴。
            </p>
          </div>

          {/* Card 2 */}
          <div className="glass-card" style={{ padding: '16px 20px', background: 'rgba(255,255,255,0.03)' }}>
            <h4 style={{ fontSize: '14px', fontWeight: 600, color: 'var(--accent-blue)', marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Headphones size={16} />
              <span>Web Audio EQ 等化器</span>
            </h4>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              搭載強大的 Web Audio API 濾波節點，支援標準、人聲加強、電音重低音 (Bass Boost) 等音效，低音沉穩、高音清亮。
            </p>
          </div>

          {/* Card 3 */}
          <div className="glass-card" style={{ padding: '16px 20px', background: 'rgba(255,255,255,0.03)' }}>
            <h4 style={{ fontSize: '14px', fontWeight: 600, color: 'var(--accent-green)', marginBottom: '6px', display: 'flex', alignItems: 'center', gap: '6px' }}>
              <Sparkles size={16} />
              <span>本地 MP3 即時讀取</span>
            </h4>
            <p style={{ fontSize: '12px', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
              只要點擊「本地音樂庫」分頁，就可以把主人隨身碟或硬碟中的 MP3 音檔直接拖進來播，立刻升級高品質視覺化！
            </p>
          </div>
        </div>
      </div>

      <style dangerouslySetInnerHTML={{__html: `
        .glass-card:hover .play-overlay {
          opacity: 1 !important;
        }
        @media (max-width: 768px) {
          /* Responsive adjustments if needed */
        }
      `}} />
    </div>
  );
};

export default ListenNow;
