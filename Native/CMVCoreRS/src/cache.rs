//! Pure cache eviction policy. File I/O and pinned storage remain in Swift.

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CacheEntry {
    pub identifier: String,
    pub size_bytes: u64,
    pub pinned: bool,
    pub last_access_order: u64,
}

/// Returns smart-cache identifiers to evict, oldest first. Pinned entries are
/// never returned, even when their combined size exceeds the budget.
pub fn eviction_plan(entries: &[CacheEntry], budget_bytes: u64) -> Vec<String> {
    // The aggregate can exceed u64 even though each individual entry cannot.
    // u128 keeps the comparison exact instead of debug-panicking, wrapping in
    // release, or losing the overflow amount through saturation.
    let mut total = entries
        .iter()
        .map(|entry| u128::from(entry.size_bytes))
        .sum::<u128>();
    let budget = u128::from(budget_bytes);
    let mut candidates: Vec<&CacheEntry> = entries.iter().filter(|entry| !entry.pinned).collect();
    candidates.sort_by_key(|entry| (entry.last_access_order, entry.identifier.as_str()));
    let mut evictions = Vec::new();
    for entry in candidates {
        if total <= budget {
            break;
        }
        total -= u128::from(entry.size_bytes);
        evictions.push(entry.identifier.clone());
    }
    evictions
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pinned_entries_are_protected_and_lru_is_deterministic() {
        let entries = vec![
            CacheEntry {
                identifier: "pinned".into(),
                size_bytes: 100,
                pinned: true,
                last_access_order: 0,
            },
            CacheEntry {
                identifier: "old".into(),
                size_bytes: 20,
                pinned: false,
                last_access_order: 1,
            },
            CacheEntry {
                identifier: "new".into(),
                size_bytes: 20,
                pinned: false,
                last_access_order: 2,
            },
        ];
        assert_eq!(eviction_plan(&entries, 100), vec!["old", "new"]);
        assert!(!eviction_plan(&entries, 100).contains(&"pinned".to_owned()));
    }

    #[test]
    fn budget_within_total_keeps_everything() {
        let entry = CacheEntry {
            identifier: "one".into(),
            size_bytes: 1,
            pinned: false,
            last_access_order: 0,
        };
        assert!(eviction_plan(&[entry], 1).is_empty());
    }

    #[test]
    fn aggregate_size_above_u64_max_is_accounted_for_exactly() {
        let entries = vec![
            CacheEntry {
                identifier: "old".into(),
                size_bytes: u64::MAX,
                pinned: false,
                last_access_order: 1,
            },
            CacheEntry {
                identifier: "new".into(),
                size_bytes: 1,
                pinned: false,
                last_access_order: 2,
            },
        ];
        assert_eq!(eviction_plan(&entries, 0), vec!["old", "new"]);
    }
}
