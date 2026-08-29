use std::collections::BTreeMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Availability {
    Available,
    SourceOffline,
    Missing,
    PermissionRequired,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScannedFile {
    pub identifier: String,
    pub relative_path: String,
    pub file_size: u64,
    pub modified_at_millis: i64,
    pub title: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrackSnapshot {
    pub identifier: String,
    pub relative_path: String,
    pub file_size: u64,
    pub modified_at_millis: i64,
    pub title: String,
    pub availability: Availability,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UpsertKind {
    Insert,
    Update,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Upsert {
    pub kind: UpsertKind,
    pub file: ScannedFile,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Reconciliation {
    pub upserts: Vec<Upsert>,
    pub missing_identifiers: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReconcileError {
    DuplicateExistingIdentifier(String),
    DuplicateScannedIdentifier(String),
    EmptyIdentifier,
}

/// Compares one complete, reachable scan with the existing catalog.
///
/// Output order is stable by identifier. An unreachable source never creates
/// mutations, because temporary NAS unavailability is not deletion.
pub fn reconcile_scan(
    existing: &[TrackSnapshot],
    scanned: &[ScannedFile],
    source_reachable: bool,
) -> Result<Reconciliation, ReconcileError> {
    if !source_reachable {
        return Ok(Reconciliation::default());
    }

    let mut existing_by_id = BTreeMap::new();
    for track in existing {
        validate_identifier(&track.identifier)?;
        if existing_by_id
            .insert(track.identifier.as_str(), track)
            .is_some()
        {
            return Err(ReconcileError::DuplicateExistingIdentifier(
                track.identifier.clone(),
            ));
        }
    }

    let mut scanned_by_id = BTreeMap::new();
    for file in scanned {
        validate_identifier(&file.identifier)?;
        if scanned_by_id
            .insert(file.identifier.as_str(), file)
            .is_some()
        {
            return Err(ReconcileError::DuplicateScannedIdentifier(
                file.identifier.clone(),
            ));
        }
    }

    let mut result = Reconciliation::default();
    for (identifier, file) in scanned_by_id {
        match existing_by_id.remove(identifier) {
            None => result.upserts.push(Upsert {
                kind: UpsertKind::Insert,
                file: file.clone(),
            }),
            Some(track) if needs_update(track, file) => result.upserts.push(Upsert {
                kind: UpsertKind::Update,
                file: file.clone(),
            }),
            Some(_) => {}
        }
    }

    result.missing_identifiers.extend(
        existing_by_id
            .into_values()
            .filter(|track| track.availability != Availability::Missing)
            .map(|track| track.identifier.clone()),
    );
    Ok(result)
}

fn validate_identifier(identifier: &str) -> Result<(), ReconcileError> {
    if identifier.is_empty() {
        Err(ReconcileError::EmptyIdentifier)
    } else {
        Ok(())
    }
}

fn needs_update(track: &TrackSnapshot, file: &ScannedFile) -> bool {
    track.relative_path != file.relative_path
        || track.file_size != file.file_size
        || track.modified_at_millis != file.modified_at_millis
        || track.title != file.title
        || track.availability != Availability::Available
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scanned(identifier: &str, revision: i64) -> ScannedFile {
        ScannedFile {
            identifier: identifier.into(),
            relative_path: format!("Album/{identifier}.flac"),
            file_size: revision as u64,
            modified_at_millis: revision,
            title: identifier.into(),
        }
    }

    fn existing(identifier: &str, revision: i64, availability: Availability) -> TrackSnapshot {
        let file = scanned(identifier, revision);
        TrackSnapshot {
            identifier: file.identifier,
            relative_path: file.relative_path,
            file_size: file.file_size,
            modified_at_millis: file.modified_at_millis,
            title: file.title,
            availability,
        }
    }

    #[test]
    fn inserts_updates_reappearing_tracks_and_marks_only_unseen_tracks_missing() {
        let existing = vec![
            existing("a", 1, Availability::Available),
            existing("b", 2, Availability::Available),
            existing("c", 3, Availability::Missing),
        ];
        let scanned = vec![scanned("d", 4), scanned("c", 3), scanned("a", 10)];

        let result = reconcile_scan(&existing, &scanned, true).unwrap();

        assert_eq!(
            result
                .upserts
                .iter()
                .map(|upsert| (upsert.file.identifier.as_str(), upsert.kind))
                .collect::<Vec<_>>(),
            vec![
                ("a", UpsertKind::Update),
                ("c", UpsertKind::Update),
                ("d", UpsertKind::Insert)
            ]
        );
        assert_eq!(result.missing_identifiers, ["b"]);
    }

    #[test]
    fn unreachable_source_never_mutates_the_catalog() {
        let result =
            reconcile_scan(&[existing("a", 1, Availability::Available)], &[], false).unwrap();

        assert_eq!(result, Reconciliation::default());
    }

    #[test]
    fn rejects_duplicate_identifiers_instead_of_silently_overwriting() {
        let duplicate = scanned("a", 1);
        assert_eq!(
            reconcile_scan(&[], &[duplicate.clone(), duplicate], true),
            Err(ReconcileError::DuplicateScannedIdentifier("a".into()))
        );
    }

    #[test]
    fn output_order_is_deterministic() {
        let result = reconcile_scan(
            &[],
            &[scanned("z", 1), scanned("a", 1), scanned("m", 1)],
            true,
        )
        .unwrap();

        assert_eq!(
            result
                .upserts
                .iter()
                .map(|upsert| upsert.file.identifier.as_str())
                .collect::<Vec<_>>(),
            ["a", "m", "z"]
        );
    }
}
