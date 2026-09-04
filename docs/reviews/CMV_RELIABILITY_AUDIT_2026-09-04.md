# CMV reliability audit — 2026-09-04

Task scope: adversarial end-to-end source review of the current Native 2.0 and retained Electron 1.3.2 safety ship. The review prompt is versioned at `docs/reviews/STRICT_RELIABILITY_REVIEW_PROMPT.md`.

This audit deliberately does **not** use GitHub Actions. The account has no Actions quota available, so executable checks were run in an isolated local sandbox from current `main` source. Apple-only Xcode/device qualification remains an explicit external gate and is not fabricated as passing.

## Review method

Three independent passes were repeated after every repair:

- **Pass A — data/state/concurrency:** SwiftData transactions, source bookmarks, scanner reconciliation, cache transactions, audio/video queue state, rollback, stale async work, optimistic UI state.
- **Pass B — Rust/FFI/security/performance:** integer/float boundaries, malformed payloads, output ownership, panic containment, cache accounting, search correctness, PCM/DJ invariants, path authorization.
- **Pass C — UI/Legacy/release tooling:** pagination generations, importer error semantics, accessibility values, Electron protocol/scan consistency, dependency gates, and release-document truthfulness.

A finding was accepted only if it had an exact trigger, observable failure, smallest safe fix and deterministic regression strategy. Speculative rewrites were rejected.

## Repairs made during this audit

### Source authorization and scanning

- Security-scoped bookmark creation and stale refresh now balance `startAccessingSecurityScopedResource()` internally.
- Scope-consumption failure during source probing is classified as permission-required rather than ordinary offline state.
- Refreshed bookmark/status persistence rolls memory state back if SwiftData save fails instead of displaying false success.
- Native incremental scanning rejects symbolic-link media entries.
- Electron scanning also rejects symbolic links, keeping scan results consistent with the realpath-enforced playback/trash boundary.

### SwiftData and destructive operations

- Search no longer uses a corpus-dependent exact-token posting shortcut that could hide legitimate substring matches.
- Mutations for missing tracks/playlists fail rather than reporting success.
- Playlist additions validate target tracks.
- Save failures roll the ModelContext back.
- Listening counters saturate instead of overflowing.
- Physical Trash first captures playlist membership; if the filesystem trash operation fails, the track and playlist membership are restored. Rollback failure is surfaced separately rather than hidden.

### Cache integrity

- Rust cache budget totals use exact `u128` accumulation rather than saturating `u64` arithmetic.
- Smart-cache manifest read/corruption no longer permanently converts the cache into an empty manifest. Existing files/checksums can be re-indexed and verified.
- Pinned-safe eviction semantics remain deterministic.

### Audio playback state machine

- Seek and manual skip transitions are transactional with rollback of the previous queue/timeline when a replacement schedule fails.
- A failed rollback fails closed instead of leaving a half-scheduled queue.
- Background next-track state is recorded only after the AVAudioPlayerNode segment is actually scheduled.
- Timeline frame addition checks overflow.
- Frame/sample-rate/gain/volume/EQ/meter numeric inputs reject non-finite or narrowing-overflow values.
- Remote command and engine-recovery failures are surfaced instead of swallowed.
- Shuffle + manual Next now advances to the already-prepared logical next track **before** shuffling later tracks, preventing UI-track/audio-file identity mismatch.

### Video playback

- `AVPlayerItem.status == .failed` is observed with generation/item identity guards and surfaced to the app error banner.
- Video seek/volume/current-time/duration paths reject NaN/Inf.
- Item/time observers are invalidated when playback stops.

### Swift ↔ Rust FFI

- Status 7/8 are explicit DJ/cache failures rather than unknown statuses.
- Owned output buffers are freed on every return path.
- Negative limits, invalid PCM shape, non-finite analysis/DJ values and unreasonable decoded counts fail closed.
- Search/analysis/DJ/playback decoders reject malformed/non-finite responses before constructing Swift domain values.

### Rust analysis and Smart DJ

- PCM analysis rejects non-frame-aligned input and NaN/Inf in the Rust core even if a caller bypasses Swift validation.
- Swift validates sample rate/channel count before narrowing to `UInt32`/`UInt16`.
- K-weighting uses a single preallocated output buffer rather than creating a temporary vector per frame.
- Smart DJ clamps corrupted ratings to 0…5, rejects invalid BPM reasons and normalizes invalid energy inside Rust rather than trusting persistence/UI callers.

### UI and paging

- Search generation is invalidated before debounce; stale requests cannot publish over a newer query.
- Track-list and catalog pagination are same-generation single-flight and deduplicate appended IDs.
- Old generations cannot clear the loading state owned by a newer generation.
- Playlist menus refresh from `playlistRevision`.
- File importer cancellation is ignored only for real user cancellation; actual picker failures are surfaced.
- Sidebar/favorites/playlists no longer turn database-read failures into misleading legitimate empty/zero states.

### Legacy Electron safety ship

- `.mp4` is served as `video/mp4` rather than `audio/mp4`.
- Symbolic-link scan entries are rejected.
- Current source was locally installed and exercised with `npm test`, `npm run lint`, `npm run build` and a high-severity npm audit gate.

## No-CI executable evidence

The following checks were executed from source downloaded from current `main`, with no GitHub Actions run:

1. Rust toolchain: **Rust 1.98.1**.
2. `cargo fmt --all -- --check` — pass.
3. `cargo clippy --workspace --all-targets -- -D warnings` — pass.
4. `cargo test --workspace` — pass.
5. Rust FFI static library release build — pass.
6. Swift 6 type-check of `CMVCoreRSClient.swift` + Swift bridge against the generated C module — pass.
7. Swift↔Rust linked bridge smoke executable — pass.
8. `swiftc -parse` over the downloaded Native Swift/Package/test source set — pass.
9. Electron safety ship: `npm ci`, tests, lint, Vite build — pass.
10. `npm audit --audit-level=high` — pass.
11. Source hygiene scan for new `fatalError`, `try!`, and forced `as!` in reviewed production source — pass.

These checks validate portable code and syntax, not AVFoundation/SwiftData runtime behavior on Apple hardware.

## Residual source risks — not falsely closed

### R1 — playback replacement failure does not fully restore user-visible position

`NativePlaybackEngine.load` already reconstructs the previous queue if the new files open but later timeline planning/scheduling fails. The reconstruction currently starts at frame 0 and leaves playback paused. A malformed/extreme candidate can therefore disturb an otherwise healthy current song even though the previous queue survives.

This is an uncommon edge because normal inputs are now heavily validated, but the stronger contract should restore old elapsed time and the old playing/paused state as well as the queue. Keep this as a targeted playback regression when the next Apple-side playback slice is edited.

### R2 — huge cross-source queue preparation is too eager

`AppModel.play(tracks:)` prepares cache/source URLs for the contiguous future audio route before starting playback. Normal 200-row UI pages are bounded, but an extremely large playlist can make initial playback latency scale with the full queue; a far-future stale source can also abort preparation before the selected healthy track starts.

The safe follow-up is a bounded/lazy preparation window that preserves gapless identity and mixed-media ordering, not an arbitrary hard queue cap. Do not implement this by merely truncating the visible queue.

### Low-severity hardening note — corrupted playlist membership JSON

`PlaylistRecord.trackIDsData` is decoded through a convenience getter that falls back to an empty array. Normal application writes always encode valid UUID arrays, but an isolated corrupted blob can therefore look like a legitimate empty playlist. A future storage-schema hardening pass should expose decode failure as repository corruption and avoid overwriting the original raw blob until explicit repair/recovery.

## External gates still open

Source review cannot substitute for:

- physical Mac and iPad security-scoped bookmark/reauthorization tests;
- real NAS sleep/reconnect/failure matrix;
- background audio/PiP/Split View/device memory pressure;
- Distribution identity/profiles and strict signed archives;
- App Store Connect/TestFlight state;
- licensed program-level loudness reference material.

Those stay under the existing AERO-V3 / AERO-R3 release gates. Electron retirement remains blocked until Native is approved and stable on both platforms.

## Stop condition result

The final fresh A/B/C pass did not produce a new ordinary-path P0/P1 correctness finding beyond the two explicitly documented edge/design residuals above. This is **not** a claim that the program is mathematically bug-free. It means the source review has converged: remaining material risk now requires targeted Apple-runtime work or the documented lazy-queue/rollback refactor rather than another broad read-through.
