use cmv_core_rs::{Availability, ScannedFile, TrackSnapshot, UpsertKind, reconcile_scan};

#[test]
fn shared_fixture_matches_the_approved_reconciliation_contract() {
    let fixture = include_str!("fixtures/reconciliation.tsv");
    let mut existing = Vec::new();
    let mut scanned = Vec::new();
    let mut expected = Vec::new();

    for line in fixture
        .lines()
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
    {
        let columns = line.split('\t').collect::<Vec<_>>();
        assert_eq!(columns.len(), 7, "invalid fixture row: {line}");
        match columns[0] {
            "existing" => existing.push(TrackSnapshot {
                identifier: columns[1].into(),
                relative_path: columns[2].into(),
                file_size: columns[3].parse().unwrap(),
                modified_at_millis: columns[4].parse().unwrap(),
                title: columns[5].into(),
                availability: parse_availability(columns[6]),
            }),
            "scanned" => scanned.push(ScannedFile {
                identifier: columns[1].into(),
                relative_path: columns[2].into(),
                file_size: columns[3].parse().unwrap(),
                modified_at_millis: columns[4].parse().unwrap(),
                title: columns[5].into(),
            }),
            "expected" => expected.push((columns[1], columns[6])),
            role => panic!("unknown fixture role: {role}"),
        }
    }

    let result = reconcile_scan(&existing, &scanned, true).unwrap();
    let mut actual = result
        .upserts
        .iter()
        .map(|upsert| {
            let action = match upsert.kind {
                UpsertKind::Insert => "insert",
                UpsertKind::Update => "update",
            };
            (upsert.file.identifier.as_str(), action)
        })
        .collect::<Vec<_>>();
    actual.extend(
        result
            .missing_identifiers
            .iter()
            .map(|identifier| (identifier.as_str(), "missing")),
    );
    actual.sort_unstable();
    expected.sort_unstable();

    assert_eq!(actual, expected);
}

fn parse_availability(value: &str) -> Availability {
    match value {
        "available" => Availability::Available,
        "source_offline" => Availability::SourceOffline,
        "missing" => Availability::Missing,
        "permission_required" => Availability::PermissionRequired,
        unknown => panic!("unknown availability: {unknown}"),
    }
}
