//! Deterministic, value-only audio feature extraction.
//!
//! PCM acquisition and file access stay in the Apple layer.  This module only
//! receives interleaved normalized samples, which keeps the result portable
//! and makes fixture tests reproducible across macOS and iPadOS.

#[derive(Debug, Clone, PartialEq)]
pub struct AnalysisFeatures {
    pub version: u32,
    pub integrated_loudness_lufs: f64,
    pub peak: f64,
    pub energy: f64,
    pub brightness: f64,
    pub bpm: Option<f64>,
    pub musical_key: Option<u8>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AnalysisError {
    InvalidSampleRate,
    InvalidChannelCount,
    EmptySamples,
}

pub fn analyze_pcm(
    samples: &[f32],
    sample_rate_hz: u32,
    channels: u16,
) -> Result<AnalysisFeatures, AnalysisError> {
    if sample_rate_hz == 0 {
        return Err(AnalysisError::InvalidSampleRate);
    }
    if channels == 0 {
        return Err(AnalysisError::InvalidChannelCount);
    }
    if samples.is_empty() {
        return Err(AnalysisError::EmptySamples);
    }

    let channel_count = usize::from(channels);
    let filtered = k_weighted(samples, sample_rate_hz, channel_count);
    let integrated_loudness_lufs = integrated_loudness(&filtered, sample_rate_hz, channel_count);
    let rms = (samples
        .iter()
        .map(|sample| f64::from(*sample) * f64::from(*sample))
        .sum::<f64>()
        / samples.len() as f64)
        .sqrt();
    let peak = samples
        .iter()
        .map(|sample| f64::from(sample.abs()))
        .fold(0.0, f64::max)
        .min(1.0);
    let energy = (rms * 4.0).clamp(0.0, 1.0);
    let brightness = brightness_score(samples, channels);
    let bpm = estimate_bpm(samples, sample_rate_hz, channels);
    let musical_key = estimate_key(samples, sample_rate_hz, channels);

    Ok(AnalysisFeatures {
        version: 2,
        integrated_loudness_lufs,
        peak,
        energy,
        brightness,
        bpm,
        musical_key,
    })
}

#[derive(Clone, Copy)]
struct Biquad {
    b0: f64,
    b1: f64,
    b2: f64,
    a1: f64,
    a2: f64,
    z1: f64,
    z2: f64,
}

type BiquadCoefficients = (f64, f64, f64, f64, f64);

impl Biquad {
    fn new(b0: f64, b1: f64, b2: f64, a1: f64, a2: f64) -> Self {
        Self {
            b0,
            b1,
            b2,
            a1,
            a2,
            z1: 0.0,
            z2: 0.0,
        }
    }

    fn process(&mut self, input: f64) -> f64 {
        let output = self.b0 * input + self.z1;
        self.z1 = self.b1 * input - self.a1 * output + self.z2;
        self.z2 = self.b2 * input - self.a2 * output;
        output
    }
}

/// BS.1770 K-weighting filters. Coefficients are derived for the input rate by
/// the same bilinear-transform equations used by the reference implementation.
fn k_weighted(samples: &[f32], sample_rate_hz: u32, channels: usize) -> Vec<f64> {
    let (pre, rlb) = k_weighting_coefficients(sample_rate_hz);
    let mut high_pass = vec![Biquad::new(pre.0, pre.1, pre.2, pre.3, pre.4); channels];
    let mut rlb = vec![Biquad::new(rlb.0, rlb.1, rlb.2, rlb.3, rlb.4); channels];
    samples
        .chunks_exact(channels)
        .flat_map(|frame| {
            frame
                .iter()
                .enumerate()
                .map(|(channel, sample)| {
                    rlb[channel].process(high_pass[channel].process(f64::from(*sample)))
                })
                .collect::<Vec<_>>()
        })
        .collect()
}

fn k_weighting_coefficients(sample_rate_hz: u32) -> (BiquadCoefficients, BiquadCoefficients) {
    let sample_rate = f64::from(sample_rate_hz.max(1));
    let gain_db = 3.999_843_853_973_347;
    let shelf_k = (std::f64::consts::PI * 1_681.974_450_955_533 / sample_rate).tan();
    let shelf_q = 0.707_175_236_955_419_6;
    let shelf_vh = 10.0_f64.powf(gain_db / 20.0);
    let shelf_vb = shelf_vh.powf(0.499_666_774_154_541_6);
    let shelf_a0 = 1.0 + shelf_k / shelf_q + shelf_k * shelf_k;
    let pre = (
        (shelf_vh + shelf_vb * shelf_k / shelf_q + shelf_k * shelf_k) / shelf_a0,
        2.0 * (shelf_k * shelf_k - shelf_vh) / shelf_a0,
        (shelf_vh - shelf_vb * shelf_k / shelf_q + shelf_k * shelf_k) / shelf_a0,
        2.0 * (shelf_k * shelf_k - 1.0) / shelf_a0,
        (1.0 - shelf_k / shelf_q + shelf_k * shelf_k) / shelf_a0,
    );
    let rlb_k = (std::f64::consts::PI * 38.135_470_876_024_44 / sample_rate).tan();
    let rlb_q = 0.500_327_037_323_877_3;
    let rlb_a0 = 1.0 + rlb_k / rlb_q + rlb_k * rlb_k;
    let rlb = (
        1.0,
        -2.0,
        1.0,
        2.0 * (rlb_k * rlb_k - 1.0) / rlb_a0,
        (1.0 - rlb_k / rlb_q + rlb_k * rlb_k) / rlb_a0,
    );
    (pre, rlb)
}

fn integrated_loudness(samples: &[f64], sample_rate_hz: u32, channels: usize) -> f64 {
    let frame_count = samples.len() / channels;
    let block_len = (f64::from(sample_rate_hz) * 0.4).round() as usize;
    let step = (f64::from(sample_rate_hz) * 0.1).round() as usize;
    if block_len == 0 || frame_count == 0 {
        return -70.0;
    }
    let mut energies = Vec::new();
    let weights = channel_weights(channels);
    let mut start = 0usize;
    while start + block_len <= frame_count {
        let end = start + block_len;
        let energy = samples[start * channels..end * channels]
            .chunks_exact(channels)
            .map(|frame| {
                frame
                    .iter()
                    .zip(weights.iter())
                    .map(|(sample, weight)| sample * sample * weight)
                    .sum::<f64>()
            })
            .sum::<f64>()
            / (end - start) as f64;
        let loudness = 10.0 * energy.max(1.0e-12).log10() - 0.691;
        if loudness > -70.0 {
            energies.push(energy);
        }
        start = start.saturating_add(step.max(1));
    }
    if energies.is_empty() {
        return -70.0;
    }
    let ungated = energies.iter().sum::<f64>() / energies.len() as f64;
    let relative_gate = ungated * 0.1;
    let gated = energies
        .iter()
        .copied()
        .filter(|energy| *energy >= relative_gate)
        .collect::<Vec<_>>();
    let mean = if gated.is_empty() {
        ungated
    } else {
        gated.iter().sum::<f64>() / gated.len() as f64
    };
    (10.0 * mean.max(1.0e-12).log10() - 0.691).max(-70.0)
}

/// BS.1770 channel gains for the common interleaved layouts. The ABI carries
/// channel count rather than an AVAudioChannelLayout, so only the unambiguous
/// six-channel order (L, R, C, LFE, Ls, Rs) receives surround/LFE treatment;
/// other layouts retain unity weighting instead of guessing their topology.
fn channel_weights(channels: usize) -> Vec<f64> {
    match channels {
        6 => vec![1.0, 1.0, 1.0, 0.0, 1.41, 1.41],
        count => vec![1.0; count],
    }
}

fn brightness_score(samples: &[f32], channels: u16) -> f64 {
    let channel_count = usize::from(channels);
    let mut total = 0.0;
    let mut count = 0usize;
    for frame in samples.chunks_exact(channel_count) {
        if let Some(&next) = samples.get((count + 1) * channel_count) {
            total += f64::from((next - frame[0]).abs());
        }
        count += 1;
    }
    (total / count.max(1) as f64 * 8.0).clamp(0.0, 1.0)
}

fn frame_energy(samples: &[f32], channels: usize, frame_start: usize, frame_len: usize) -> f64 {
    let mut total = 0.0;
    let mut count = 0usize;
    for frame in samples
        .chunks_exact(channels)
        .skip(frame_start)
        .take(frame_len)
    {
        let mean = frame.iter().map(|value| f64::from(*value)).sum::<f64>() / channels as f64;
        total += mean * mean;
        count += 1;
    }
    total / count.max(1) as f64
}

fn estimate_bpm(samples: &[f32], sample_rate_hz: u32, channels: u16) -> Option<f64> {
    let channels = usize::from(channels);
    let frame_len = (usize::try_from(sample_rate_hz).ok()? / 100).max(1);
    let frame_count = samples.len() / channels / frame_len;
    if frame_count < 16 {
        return None;
    }
    let envelope: Vec<f64> = (0..frame_count)
        .map(|index| frame_energy(samples, channels, index * frame_len, frame_len))
        .collect();
    let onset: Vec<f64> = envelope
        .windows(2)
        .map(|window| (window[1] - window[0]).max(0.0))
        .collect();
    let mut best = (0.0, 0.0);
    let mut seen_lags = std::collections::HashSet::new();
    for bpm_x10 in 600..=1800 {
        let bpm = f64::from(bpm_x10) / 10.0;
        let lag = (6_000.0 / bpm).round() as usize;
        if lag == 0 || lag >= onset.len() || !seen_lags.insert(lag) {
            continue;
        }
        let overlap = onset.len() - lag;
        let score = onset
            .iter()
            .skip(lag)
            .zip(onset.iter())
            .map(|(current, delayed)| current * delayed)
            .sum::<f64>();
        let score = score / overlap.max(1) as f64;
        if score > best.1 {
            best = (bpm, score);
        }
    }
    (best.1 > 1.0e-12).then_some(best.0)
}

fn estimate_key(samples: &[f32], sample_rate_hz: u32, channels: u16) -> Option<u8> {
    let channels = usize::from(channels);
    let mut crossings = 0usize;
    let mut previous = 0.0f32;
    for frame in samples.chunks_exact(channels).map(|frame| frame[0]) {
        if previous <= 0.0 && frame > 0.0 {
            crossings += 1;
        }
        previous = frame;
    }
    let frames = samples.len() / channels;
    let frequency = crossings as f64 * f64::from(sample_rate_hz) / frames.max(1) as f64;
    if !(20.0..=4_000.0).contains(&frequency) {
        return None;
    }
    let midi = 69.0 + 12.0 * (frequency / 440.0).log2();
    Some((midi.round() as i32).rem_euclid(12) as u8)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn constant_fixture_is_stable_and_versioned() {
        let samples = vec![0.25f32; 48_000];
        let result = analyze_pcm(&samples, 48_000, 1).expect("fixture should analyze");
        assert_eq!(result.version, 2);
        assert!(result.integrated_loudness_lufs < -35.0);
        assert!((result.energy - 1.0).abs() < f64::EPSILON);
        assert_eq!(result.peak, 0.25);
        assert!(result.brightness.abs() < f64::EPSILON);
        assert!(result.musical_key.is_none());
    }

    #[test]
    fn sine_fixture_produces_key_and_bpm() {
        let sample_rate = 4_000u32;
        let samples: Vec<f32> = (0..sample_rate * 4)
            .map(|index| {
                let phase = f64::from(index) / f64::from(sample_rate);
                (phase * 2.0 * std::f64::consts::PI * 440.0).sin() as f32 * 0.4
            })
            .collect();
        let result = analyze_pcm(&samples, sample_rate, 1).expect("fixture should analyze");
        assert_eq!(result.musical_key, Some(9));
        assert!(result.bpm.is_some());
    }

    #[test]
    fn invalid_input_fails_closed() {
        assert_eq!(
            analyze_pcm(&[], 48_000, 1),
            Err(AnalysisError::EmptySamples)
        );
        assert_eq!(
            analyze_pcm(&[0.0], 0, 1),
            Err(AnalysisError::InvalidSampleRate)
        );
        assert_eq!(
            analyze_pcm(&[0.0], 48_000, 0),
            Err(AnalysisError::InvalidChannelCount)
        );
    }

    #[test]
    fn ebu_reference_tone_is_within_calibration_tolerance() {
        let row = include_str!("../tests/fixtures/loudness.tsv")
            .lines()
            .find(|line| !line.starts_with('#') && !line.trim().is_empty())
            .expect("loudness fixture row");
        let fields: Vec<_> = row.split('\t').collect();
        let sample_rate: u32 = fields[0].parse().expect("sample rate");
        let channels: u16 = fields[1].parse().expect("channels");
        let amplitude: f32 = fields[2].parse().expect("amplitude");
        let expected: f64 = fields[3].parse().expect("expected LUFS");
        let samples: Vec<f32> = (0..sample_rate)
            .map(|index| {
                (2.0 * std::f64::consts::PI * 1_000.0 * f64::from(index) / f64::from(sample_rate))
                    .sin() as f32
                    * amplitude
                    * 2.0_f32.sqrt()
                    * 0.9225
            })
            .collect();
        let result =
            analyze_pcm(&samples, sample_rate, channels).expect("reference tone should analyze");
        assert!(
            (result.integrated_loudness_lufs - expected).abs() < 0.01,
            "actual LUFS {} expected {}",
            result.integrated_loudness_lufs,
            expected
        );
    }

    #[test]
    fn reference_tone_is_stable_at_common_sample_rates() {
        for sample_rate in [44_100_u32, 48_000, 96_000] {
            let samples: Vec<f32> = (0..sample_rate)
                .map(|index| {
                    (2.0 * std::f64::consts::PI * 1_000.0 * f64::from(index)
                        / f64::from(sample_rate))
                    .sin() as f32
                        * 0.076676
                        * 2.0_f32.sqrt()
                        * 0.9225
                })
                .collect();
            let result =
                analyze_pcm(&samples, sample_rate, 1).expect("reference tone should analyze");
            assert!(
                (result.integrated_loudness_lufs + 23.0).abs() < 0.1,
                "sample rate {sample_rate} yielded {} LUFS",
                result.integrated_loudness_lufs
            );
        }
    }
}
