# AeroCoreRS

`AeroCoreRS` is AeroMusic's platform-neutral Rust shadow core. Swift remains the
owner of SwiftUI, SwiftData, security-scoped URLs, AVFoundation, AVKit, and
MediaPlayer.

The initial crate deliberately uses only the Rust standard library and forbids
unsafe code. Its contracts are deterministic value policies:

- scan reconciliation (offline-safe upserts/missing decisions);
- sample-timeline and gain planning for gapless playback;
- normalized search ranking and paging;
- versioned PCM feature extraction and explainable Smart DJ ranking;
- pinned-safe deterministic cache eviction planning.

Swift owns all Apple platform boundaries: AVFoundation decoding and rendering,
SwiftData persistence, security-scoped bookmarks, file copying/checksums, and
SwiftUI/AVKit/MediaPlayer presentation. The Rust decisions cross a narrow,
versioned C ABI as immutable value DTOs; Rust never owns URLs, file handles, or
Apple framework objects.

Build artifacts must stay on local storage:

```bash
CARGO_TARGET_DIR=/tmp/aeromusic-cargo-target cargo fmt --check
CARGO_TARGET_DIR=/tmp/aeromusic-cargo-target cargo clippy --all-targets -- -D warnings
CARGO_TARGET_DIR=/tmp/aeromusic-cargo-target cargo test
./scripts/test-swift-bridge.sh
```

The Swift runtime injects the Rust cache planner while retaining a deterministic
Swift fallback for package-only tests. Shared fixtures and both Apple platform
builds must pass before changing any other platform boundary.

`ffi/` exposes the versioned C ABI consumed by Swift. Xcode invokes
`scripts/build-xcode.sh`, which selects the matching Apple Rust target and
places only the selected static library in DerivedData; Cargo artifacts remain
under `/tmp/aeromusic-cargo-target` by default.
