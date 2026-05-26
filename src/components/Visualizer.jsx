import React, { useEffect, useRef, useState } from 'react';
import { PlayCircle, Eye, Activity, Sparkles, AlertCircle } from 'lucide-react';
import { useAudio } from '../context/AudioContext';

const Visualizer = () => {
  const { analyserRef, isPlaying, currentTrack } = useAudio();
  const canvasRef = useRef(null);
  const animationRef = useRef(null);
  
  const [visualMode, setVisualMode] = useState('bars'); // 'bars' | 'waves'
  const [hasInteracted, setHasInteracted] = useState(false);

  // Sync state for user interaction check (since analyser won't have data until context starts)
  useEffect(() => {
    if (isPlaying) {
      setHasInteracted(true);
    }
  }, [isPlaying]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Resize Canvas to fit its container
    const resizeCanvas = () => {
      const rect = canvas.parentElement.getBoundingClientRect();
      canvas.width = rect.width;
      canvas.height = rect.height;
    };
    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    // Color definitions based on current track or standard fallbacks
    const themeColors = currentTrack?.colors || ['#ff2d55', '#af52de', '#007aff'];

    // Drawing variables
    let phase = 0;

    const draw = () => {
      animationRef.current = requestAnimationFrame(draw);

      const width = canvas.width;
      const height = canvas.height;
      
      // Setup Analyser
      const analyser = analyserRef.current;
      let bufferLength = 128;
      let dataArray = new Uint8Array(bufferLength);
      
      const activePlaying = isPlaying && analyser;

      if (activePlaying) {
        try {
          bufferLength = analyser.frequencyBinCount;
          dataArray = new Uint8Array(bufferLength);
          analyser.getByteFrequencyData(dataArray);
        } catch (e) {
          // fallback to silent data if analyser isn't fully ready
          dataArray = new Uint8Array(bufferLength);
        }
      } else {
        // Generate simulated breathing sine wave when paused
        bufferLength = 128;
        dataArray = new Uint8Array(bufferLength);
        const time = Date.now() * 0.002;
        for (let i = 0; i < bufferLength; i++) {
          // quiet breathing frequencies
          dataArray[i] = (Math.sin(i * 0.05 + time) * 0.5 + 0.5) * 20 + 2;
        }
      }

      // Clear Canvas with very slight opacity to create a beautiful tail trail
      ctx.fillStyle = 'rgba(13, 14, 18, 0.15)';
      ctx.fillRect(0, 0, width, height);

      // Draw dynamic glowing background aura matching the visualizer
      const centerGlow = ctx.createRadialGradient(
        width / 2, height / 2, 5,
        width / 2, height / 2, Math.max(width, height) * 0.5
      );
      centerGlow.addColorStop(0, `${themeColors[0]}11`);
      centerGlow.addColorStop(0.5, `${themeColors[1]}04`);
      centerGlow.addColorStop(1, 'transparent');
      ctx.fillStyle = centerGlow;
      ctx.fillRect(0, 0, width, height);

      // ==========================================
      // MODE 1: NEON BAR SPECTROGRAM
      // ==========================================
      if (visualMode === 'bars') {
        const barCount = Math.min(60, bufferLength);
        const gap = 6;
        const totalSpacingWidth = (width - 80);
        const barWidth = (totalSpacingWidth - (barCount - 1) * gap) / barCount;
        
        ctx.save();
        ctx.translate(40, 0); // margin left

        // Create linear gradient for the bars
        const grad = ctx.createLinearGradient(0, height - 80, 0, 80);
        grad.addColorStop(0, themeColors[1]); // bottom color
        grad.addColorStop(0.5, themeColors[0]); // middle color
        grad.addColorStop(1, themeColors[2] || '#007aff'); // top color

        for (let i = 0; i < barCount; i++) {
          // Normalize height value
          const value = dataArray[i];
          const percent = value / 255;
          
          // Apply multiplier based on current playing state (make active state taller!)
          const multiplier = activePlaying ? height * 0.55 : height * 0.2;
          const barHeight = Math.max(8, percent * multiplier);
          
          const x = i * (barWidth + gap);
          const y = height / 2 - barHeight / 2; // center bars vertically for an ultra premium Look

          // Draw Glowing shadow for high peaks
          if (percent > 0.4 && activePlaying) {
            ctx.shadowBlur = 18;
            ctx.shadowColor = themeColors[0];
          } else {
            ctx.shadowBlur = 0;
          }

          // Draw Rounded Bars
          ctx.fillStyle = grad;
          ctx.beginPath();
          if (ctx.roundRect) {
            ctx.roundRect(x, y, barWidth, barHeight, barWidth / 2);
          } else {
            ctx.rect(x, y, barWidth, barHeight);
          }
          ctx.fill();
        }
        ctx.restore();
      } 
      
      // ==========================================
      // MODE 2: FLUID SINE WAVES
      // ==========================================
      else if (visualMode === 'waves') {
        ctx.save();
        phase += activePlaying ? 0.05 : 0.01;

        // Extract average frequency to control wave speed and size
        let sum = 0;
        for (let i = 0; i < bufferLength; i++) {
          sum += dataArray[i];
        }
        const average = sum / bufferLength;
        const amplitudeFactor = activePlaying ? (average / 255) * 1.5 + 0.2 : 0.3;

        // Draw 3 layered overlapping waves with different phases, frequencies and opacities
        const waves = [
          { amplitude: 90 * amplitudeFactor, frequency: 0.006, color: themeColors[0], opacity: '44' },
          { amplitude: 60 * amplitudeFactor, frequency: 0.009, color: themeColors[1], opacity: '33' },
          { amplitude: 40 * amplitudeFactor, frequency: 0.004, color: themeColors[2] || '#007aff', opacity: '55' }
        ];

        waves.forEach((wave) => {
          ctx.beginPath();
          ctx.strokeStyle = `${wave.color}${wave.opacity}`;
          ctx.lineWidth = 4;
          
          // Draw Glowing wave line
          ctx.shadowBlur = activePlaying ? 12 : 0;
          ctx.shadowColor = wave.color;

          for (let x = 0; x < width; x++) {
            // calculate y coordinate using multiple nested sine calculations for organic fluidity
            const y = height / 2 + 
              Math.sin(x * wave.frequency + phase) * wave.amplitude +
              Math.cos(x * 0.002 + phase * 0.5) * (wave.amplitude * 0.3);
              
            if (x === 0) {
              ctx.moveTo(x, y);
            } else {
              ctx.lineTo(x, y);
            }
          }
          ctx.stroke();
        });
        
        ctx.restore();
      }
    };

    draw();

    return () => {
      cancelAnimationFrame(animationRef.current);
      window.removeEventListener('resize', resizeCanvas);
    };
  }, [visualMode, currentTrack, isPlaying]);

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      height: '100%',
      width: '100%',
      padding: '40px 30px',
      position: 'relative',
      zIndex: 1,
      overflow: 'hidden'
    }}>
      {/* Title */}
      <div style={{
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: '20px',
        zIndex: 5
      }}>
        <div>
          <h1 style={{
            fontFamily: 'var(--font-display)',
            fontSize: '32px',
            fontWeight: 800,
            background: 'linear-gradient(135deg, #fff 0%, #a1a1a6 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            letterSpacing: '-1px'
          }}>
            音頻視覺化
          </h1>
          <p style={{ color: 'var(--text-secondary)', fontSize: '13px', marginTop: '4px' }}>
            即時讀取音頻訊號解碼，繪製高品質 60fps 雙模式動態頻譜。
          </p>
        </div>

        {/* Mode Switcher */}
        <div className="glass-effect" style={{
          display: 'flex',
          padding: '4px',
          borderRadius: '20px',
          border: '1px solid var(--border-glass)'
        }}>
          <button
            onClick={() => setVisualMode('bars')}
            style={{
              padding: '6px 16px',
              borderRadius: '16px',
              border: 'none',
              background: visualMode === 'bars' ? 'var(--bg-glass-active)' : 'transparent',
              color: visualMode === 'bars' ? 'var(--primary-color)' : 'var(--text-secondary)',
              fontSize: '12px',
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              transition: 'all 0.2s',
              outline: 'none'
            }}
            id="viz-bars-btn"
          >
            <Activity size={12} />
            <span>旋律頻譜</span>
          </button>
          
          <button
            onClick={() => setVisualMode('waves')}
            style={{
              padding: '6px 16px',
              borderRadius: '16px',
              border: 'none',
              background: visualMode === 'waves' ? 'var(--bg-glass-active)' : 'transparent',
              color: visualMode === 'waves' ? 'var(--primary-color)' : 'var(--text-secondary)',
              fontSize: '12px',
              fontWeight: 600,
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
              transition: 'all 0.2s',
              outline: 'none'
            }}
            id="viz-waves-btn"
          >
            <Eye size={12} />
            <span>流體波浪</span>
          </button>
        </div>
      </div>

      {/* AUDIO NOTIFICATION TIPS */}
      {!hasInteracted && (
        <div className="glass-card glow-loading" style={{
          display: 'flex',
          alignItems: 'center',
          gap: '12px',
          padding: '12px 20px',
          marginBottom: '20px',
          borderRadius: 'var(--radius-md)',
          background: 'rgba(255, 149, 0, 0.1)',
          border: '1px solid rgba(255, 149, 0, 0.2)',
          zIndex: 5
        }}>
          <AlertCircle size={18} color="#ff9500" />
          <div style={{ fontSize: '13px', color: '#ff9500', fontWeight: 500 }}>
            主人～瀏覽器的安全防護機制要求主人必須「點擊播放音樂」，Web Audio 音訊視覺化才能順利讀取到解碼資料喔！(｀・ω・´)ゞ
          </div>
        </div>
      )}

      {/* CANVAS CONTAINER */}
      <div style={{
        flex: 1,
        borderRadius: 'var(--radius-lg)',
        border: '1px solid var(--border-glass)',
        overflow: 'hidden',
        background: '#0d0e12',
        position: 'relative',
        boxShadow: 'inset 0 10px 40px rgba(0,0,0,0.8)'
      }}>
        <canvas ref={canvasRef} style={{ display: 'block', width: '100%', height: '100%' }} />

        {/* Ambient music tag */}
        <div style={{
          position: 'absolute',
          bottom: '20px',
          left: '20px',
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '6px 12px',
          borderRadius: '12px',
          background: 'rgba(0,0,0,0.5)',
          border: '1px solid rgba(255,255,255,0.06)'
        }}>
          <Sparkles size={12} color="var(--primary-color)" />
          <span style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-secondary)' }}>
            {currentTrack ? `正在解碼: ${currentTrack.title}` : '等待音樂載入中...'}
          </span>
        </div>
      </div>
    </div>
  );
};

export default Visualizer;
