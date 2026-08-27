#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TimelineTrack {
    pub sample_rate_hz: u32,
    pub total_frames: u64,
    pub start_frame: u64,
    pub replay_gain_db: Option<f64>,
    pub peak: Option<f64>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PlaybackPlan {
    pub current_start_frame: u64,
    pub current_frame_count: u64,
    pub next_start_engine_frame: u64,
    pub current_gain_linear: f64,
    pub next_gain_linear: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlaybackPlanError {
    InvalidSampleRate,
    StartBeyondEnd,
    InvalidGain,
    InvalidPeak,
    FrameOverflow,
}

pub fn plan_playback_pair(
    engine_sample_rate_hz: u32,
    current: TimelineTrack,
    next: TimelineTrack,
) -> Result<PlaybackPlan, PlaybackPlanError> {
    if engine_sample_rate_hz == 0 || current.sample_rate_hz == 0 || next.sample_rate_hz == 0 {
        return Err(PlaybackPlanError::InvalidSampleRate);
    }
    if current.start_frame > current.total_frames || next.start_frame > next.total_frames {
        return Err(PlaybackPlanError::StartBeyondEnd);
    }

    let current_frame_count = current.total_frames - current.start_frame;
    let scaled_frames = u128::from(current_frame_count)
        .checked_mul(u128::from(engine_sample_rate_hz))
        .ok_or(PlaybackPlanError::FrameOverflow)?;
    let current_rate = u128::from(current.sample_rate_hz);
    let rounded_engine_frames = scaled_frames
        .checked_add(current_rate / 2)
        .ok_or(PlaybackPlanError::FrameOverflow)?
        / current_rate;
    let next_start_engine_frame =
        u64::try_from(rounded_engine_frames).map_err(|_| PlaybackPlanError::FrameOverflow)?;

    Ok(PlaybackPlan {
        current_start_frame: current.start_frame,
        current_frame_count,
        next_start_engine_frame,
        current_gain_linear: gain_linear(current.replay_gain_db, current.peak)?,
        next_gain_linear: gain_linear(next.replay_gain_db, next.peak)?,
    })
}

fn gain_linear(gain_db: Option<f64>, peak: Option<f64>) -> Result<f64, PlaybackPlanError> {
    let gain_db = gain_db.unwrap_or(0.0);
    if !gain_db.is_finite() {
        return Err(PlaybackPlanError::InvalidGain);
    }
    let mut gain = 10_f64.powf(gain_db / 20.0).min(4.0);
    if let Some(peak) = peak {
        if !peak.is_finite() || peak <= 0.0 {
            return Err(PlaybackPlanError::InvalidPeak);
        }
        gain = gain.min(1.0 / peak);
    }
    if !gain.is_finite() || gain < 0.0 {
        return Err(PlaybackPlanError::InvalidGain);
    }
    Ok(gain)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn schedules_next_track_on_the_exact_engine_timeline() {
        let plan = plan_playback_pair(
            48_000,
            TimelineTrack {
                sample_rate_hz: 44_100,
                total_frames: 441_000,
                start_frame: 44_100,
                replay_gain_db: Some(-6.0),
                peak: None,
            },
            TimelineTrack {
                sample_rate_hz: 48_000,
                total_frames: 960_000,
                start_frame: 0,
                replay_gain_db: None,
                peak: None,
            },
        )
        .unwrap();

        assert_eq!(plan.current_frame_count, 396_900);
        assert_eq!(plan.next_start_engine_frame, 432_000);
        assert!((plan.current_gain_linear - 0.501_187).abs() < 0.000_001);
        assert_eq!(plan.next_gain_linear, 1.0);
    }

    #[test]
    fn peak_clamps_replay_gain_before_the_limiter() {
        let track = TimelineTrack {
            sample_rate_hz: 48_000,
            total_frames: 48_000,
            start_frame: 0,
            replay_gain_db: Some(6.0),
            peak: Some(0.8),
        };
        let plan = plan_playback_pair(48_000, track, track).unwrap();
        assert_eq!(plan.current_gain_linear, 1.25);
    }

    #[test]
    fn invalid_timeline_fails_closed() {
        let invalid = TimelineTrack {
            sample_rate_hz: 0,
            total_frames: 1,
            start_frame: 2,
            replay_gain_db: Some(f64::NAN),
            peak: None,
        };
        assert_eq!(
            plan_playback_pair(48_000, invalid, invalid),
            Err(PlaybackPlanError::InvalidSampleRate)
        );
    }
}
