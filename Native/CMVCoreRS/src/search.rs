#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchTrack {
    pub identifier: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub favorite: bool,
    pub rating: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SearchResult {
    pub identifier: String,
    pub score: u32,
}

/// Scores a value-only library snapshot deterministically.
///
/// Search is intentionally kept independent from SwiftData and Foundation so
/// the same ordering can be used by the app and by fixture tests on every
/// Apple target. Empty queries rank favorites and highly-rated tracks first,
/// then use title order, identifier, and input order as stable tie-breakers.
pub fn search_tracks(query: &str, tracks: &[SearchTrack], limit: usize) -> Vec<SearchResult> {
    let query = normalize(query);
    let mut scored: Vec<(usize, u32, String, String)> = tracks
        .iter()
        .enumerate()
        .filter_map(|(index, track)| {
            let score = score_track(&query, track);
            if !query.is_empty() && score == 0 {
                return None;
            }
            Some((
                index,
                score,
                normalize(&track.title),
                track.identifier.clone(),
            ))
        })
        .collect();

    scored.sort_by(|left, right| {
        right
            .1
            .cmp(&left.1)
            .then_with(|| left.2.cmp(&right.2))
            .then_with(|| left.3.cmp(&right.3))
            .then_with(|| left.0.cmp(&right.0))
    });

    scored
        .into_iter()
        .take(limit)
        .map(|(_, score, _, identifier)| SearchResult { identifier, score })
        .collect()
}

fn score_track(query: &str, track: &SearchTrack) -> u32 {
    let mut score = track.favorite as u32 * 50 + u32::from(track.rating.min(5)) * 10;
    if query.is_empty() {
        return score;
    }

    let title = normalize(&track.title);
    let artist = normalize(&track.artist);
    let album = normalize(&track.album);
    let fields = [(&title, 1_000_u32), (&artist, 600), (&album, 500)];
    for token in query.split_whitespace() {
        let mut matched = false;
        for (field, weight) in fields {
            if field == token {
                score = score.saturating_add(weight);
                matched = true;
            } else if field.split_whitespace().any(|word| word == token) {
                score = score.saturating_add(weight / 2);
                matched = true;
            } else if field.contains(token) {
                score = score.saturating_add(weight / 3);
                matched = true;
            }
        }
        if !matched {
            return 0;
        }
    }
    score
}

fn normalize(value: &str) -> String {
    let lower = value.trim().to_lowercase();
    let mut needs_collapse = false;
    let mut previous_space = false;
    for character in lower.chars() {
        if character == ' ' {
            if previous_space {
                needs_collapse = true;
            }
            previous_space = true;
        } else if character.is_whitespace() {
            needs_collapse = true;
            previous_space = true;
        } else {
            previous_space = false;
        }
    }
    if !needs_collapse {
        return lower;
    }

    let mut normalized = String::with_capacity(lower.len());
    for token in lower.split_whitespace() {
        if !normalized.is_empty() {
            normalized.push(' ');
        }
        normalized.push_str(token);
    }
    normalized
}

#[cfg(test)]
mod tests {
    use super::*;

    fn track(identifier: &str, title: &str, artist: &str, album: &str) -> SearchTrack {
        SearchTrack {
            identifier: identifier.to_owned(),
            title: title.to_owned(),
            artist: artist.to_owned(),
            album: album.to_owned(),
            favorite: false,
            rating: 0,
        }
    }

    #[test]
    fn normalizes_and_ranks_exact_title_before_partial_matches() {
        let results = search_tracks(
            "  星   夜 ",
            &[
                track("partial", "星夜之城", "A", "B"),
                track("exact", "星 夜", "A", "B"),
                track("artist", "其他", "星夜", "B"),
            ],
            10,
        );
        assert_eq!(results[0].identifier, "exact");
        assert!(results[0].score > results[1].score);
    }

    #[test]
    fn requires_every_query_token_and_is_deterministic_on_ties() {
        let results = search_tracks(
            "moon lane",
            &[
                track("b", "Moon Lane", "A", "B"),
                track("a", "Moon Lane", "A", "B"),
                track("no", "Moon", "A", "B"),
            ],
            10,
        );
        assert_eq!(
            results
                .iter()
                .map(|r| r.identifier.as_str())
                .collect::<Vec<_>>(),
            ["a", "b"]
        );
    }

    #[test]
    fn empty_query_returns_title_order_with_preferences() {
        let mut favorite = track("z", "Zeta", "A", "B");
        favorite.favorite = true;
        let results = search_tracks("", &[favorite, track("a", "Alpha", "A", "B")], 10);
        assert_eq!(results[0].identifier, "z");
    }

    #[test]
    fn normalize_preserves_contextual_unicode_lowercase_and_collapses_whitespace() {
        assert_eq!(normalize("ΟΣ"), "ος");
        assert_eq!(normalize("  Moon Lane  "), "moon lane");
        assert_eq!(
            normalize("Moon\tLane\nAlbum\u{00a0}Side"),
            "moon lane album side"
        );
        assert_eq!(normalize("Moon Lane"), normalize("Moon\tLane"));
    }
}
