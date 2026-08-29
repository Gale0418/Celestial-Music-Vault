//! Explainable, deterministic Smart DJ scoring over value snapshots.

#[derive(Debug, Clone, PartialEq)]
pub struct DJTrack {
    pub identifier: String,
    pub title: String,
    pub favorite: bool,
    pub rating: u8,
    pub bpm: Option<f64>,
    pub energy: f64,
    pub play_count: u32,
    pub skip_count: u32,
}

#[derive(Debug, Clone, PartialEq)]
pub struct DJSelection {
    pub identifier: String,
    pub score: f64,
    pub reasons: Vec<String>,
}

pub fn make_queue(mut tracks: Vec<DJTrack>, limit: usize) -> Vec<DJSelection> {
    let mut selections: Vec<DJSelection> = tracks
        .drain(..)
        .map(|track| {
            let mut score = f64::from(track.rating) * 0.7 + if track.favorite { 2.0 } else { 0.0 };
            score += track.energy.clamp(0.0, 1.0) * 0.25;
            score += f64::from(track.play_count).mul_add(0.12, 0.0).min(2.0);
            score -= f64::from(track.skip_count).mul_add(0.45, 0.0).min(4.0);
            let mut reasons = Vec::new();
            if track.favorite {
                reasons.push("已加入最愛".to_owned());
            }
            if track.rating >= 4 {
                reasons.push("評分很高".to_owned());
            }
            if let Some(bpm) = track.bpm {
                reasons.push(format!("節奏約 {:.0} BPM", bpm));
            }
            if reasons.is_empty() {
                reasons.push(
                    if track.play_count == 0 {
                        "尚未播放過"
                    } else {
                        "依聆聽習慣推薦"
                    }
                    .to_owned(),
                );
            }
            DJSelection {
                identifier: track.identifier,
                score,
                reasons,
            }
        })
        .collect();
    selections.sort_by(|left, right| {
        right
            .score
            .total_cmp(&left.score)
            .then_with(|| left.identifier.cmp(&right.identifier))
    });
    selections.truncate(limit);
    selections
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn favorite_high_rating_beats_skipped_track_with_reason() {
        let result = make_queue(
            vec![
                DJTrack {
                    identifier: "skip".into(),
                    title: "跳過".into(),
                    favorite: false,
                    rating: 0,
                    bpm: None,
                    energy: 0.4,
                    play_count: 0,
                    skip_count: 10,
                },
                DJTrack {
                    identifier: "favorite".into(),
                    title: "收藏".into(),
                    favorite: true,
                    rating: 5,
                    bpm: Some(120.0),
                    energy: 0.8,
                    play_count: 0,
                    skip_count: 0,
                },
            ],
            2,
        );
        assert_eq!(
            result.first().map(|item| item.identifier.as_str()),
            Some("favorite")
        );
        assert!(
            result[0]
                .reasons
                .iter()
                .any(|reason| reason.contains("最愛"))
        );
        assert!(
            result[0]
                .reasons
                .iter()
                .any(|reason| reason.contains("120"))
        );
    }

    #[test]
    fn ties_are_sorted_by_identifier_and_limit_is_respected() {
        let tracks = ["z", "a", "m"]
            .into_iter()
            .map(|identifier| DJTrack {
                identifier: identifier.into(),
                title: identifier.into(),
                favorite: false,
                rating: 0,
                bpm: None,
                energy: 0.0,
                play_count: 0,
                skip_count: 0,
            })
            .collect();
        let result = make_queue(tracks, 2);
        assert_eq!(
            result
                .iter()
                .map(|item| item.identifier.as_str())
                .collect::<Vec<_>>(),
            ["a", "m"]
        );
    }
}
