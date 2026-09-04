# CMV UI performance review — 2026-09-05

Scope: AERO-F26 sensory/performance regression plus the macOS/iPad queue panel hitch reported against `main` at `f90da0c078696d985b7fdf9cbbdd3cde260a3bab`.

No GitHub Actions workflow was started. This review uses source inspection, portable Swift syntax/concurrency checks, deterministic algorithm checks, prior-art comparison, and fresh diff review. Apple-runtime FPS/build/device qualification is intentionally not fabricated.

## Evidence and prior art

- Apple `Understanding and improving SwiftUI performance`: reduce update frequency and isolate state dependencies so unrelated observable changes do not invalidate expensive view hierarchies.
- Apple Observation / `withObservationTracking`: track only properties read by the isolated observer and re-register after changes.
- `GRimAce11/WaveformKit`: bounded circular waveform geometry, decoupled audio capture/resampling and presentation cadence, no need to render an unbounded number of bars.
- `dmrschmidt/DSWaveformImage`: separates waveform data/analysis from rendering and supports circular/live waveform presentation.
- `pbakaus/impeccable`: applied `audit`, `animate`, and `optimize` principles — preserve purposeful motion, reduce unnecessary rendering/compositing, and avoid decorative work becoming the interaction bottleneck.
- CMV Mission Center already records AERO-F26's 80-segment geometry budget; current `main` had regressed to 120 segments.

No third-party source code was copied and no runtime dependency was added.

## Root causes

### P1 — queue panel invalidation storm

`NativePlaybackEngine` publishes elapsed time every 0.25 s. `AppModel` bridges all playback `objectWillChange` events through the same `playbackRevision`, and `displayQueue` reads that revision. The old queue view therefore joined elapsed-time invalidation even when its queue did not change.

The panel also used translucent material over the animated celestial background, increasing compositor work during those unnecessary updates.

### P1 — moon-ring temporal ordering bug

`AudioEnergySnapshot` is a circular buffer and records `writeIndex` / `previousWriteIndex`, but the renderer sampled arrays as if index zero were permanently the oldest sample. Once the buffer wrapped, spatial waveform order no longer matched temporal order.

### P1 — moon-ring motion aliasing / regression

The latest source used 120 segments and a 4-second revolution at a nominal 30 fps. That is 3 degrees per nominal frame and 3 degrees per segment, so the entire radial geometry advances exactly one slot per frame. With changing bar heights and any dropped frames, continuous rotation is easily perceived as discrete image replacement. Mission Center's earlier AERO-F26 budget was 80 segments, so 120 was also a documented regression.

### P2 — paused rotation resumed from wall-clock phase

The original ring derives angle from absolute reference time. Because `TimelineView` is paused when playback or the scene is inactive, resuming can jump immediately to a different wall-clock angle instead of continuing from the last displayed phase.

## Repairs

### Queue rendering

- Added `QueuePanelSnapshot`, an Observation isolation boundary that consumes the existing coarse `displayQueue` signal but republishes only when order, current index, visible metadata, or current track actually changes.
- The unchanged hot path performs an allocation-free comparison; artwork bytes are deliberately excluded because the panel does not render them. Ratings and pin state remain directly observed from their dedicated AppModel properties.
- Duplicate tracks remain supported by using queue index identity, matching the old queue semantics.
- Replaced the macOS queue's live `.ultraThinMaterial` backdrop with a mostly opaque themed surface plus a cheap gradient. The animated star field no longer has to be continuously blurred through the queue column.
- The existing `QueueView` is retained as compiled legacy code for now; `RootView` routes both macOS and iPad inspector presentation to `PerformantQueueView`. Full queue-model consolidation belongs to AERO-Q12 rather than being mixed into this regression repair.

### Moon ring

- Restored the AERO-F26 geometry budget from 120 to 80 segments.
- Slowed the scan from 4 s to 6 s, removing the one-segment-per-frame resonance at nominal 30 fps.
- Rotates the `GraphicsContext` once per frame instead of rotating every segment vector individually.
- Samples the circular energy history relative to `writeIndex` and `previousWriteIndex`, keeping chronological order stable through wraparound while preserving the existing three-tap smoothing and frame interpolation.
- Added an active-time rotation clock. Playback/scene pauses accumulate completed rotation time and resume from the same phase instead of jumping to current wall-clock phase.
- Accessibility Reduce Motion still disables rotation.

## Strict review loop

Review prompt used verbatim:

> 不要相信前一輪結論，重新從正確性、回歸風險、效能、安全、資源使用與可維護性挑毛病，按照Mission Center標出待修優先度，只有真的沒有值得修的 P2 以上問題才准通過。

A separate model/subagent runtime is not available in this chat environment, and CodeRabbit CLI is not installed; therefore this is recorded as repeated fresh-pass adversarial review, not falsely labeled as an external model review.

1. **Pass 1 — FAIL / P2 resource usage:** initial snapshot allocated a complete UUID array on every coarse playback revision. Replaced by allocation-free field-by-field hot-path comparison; allocation occurs only when the queue actually changes.
2. **Pass 2 — FAIL / P1 correctness:** initial row identity used `track.id`, which breaks legitimate queues containing the same track more than once. Restored index identity.
3. **Pass 3 — FAIL / P2 motion correctness:** absolute-time rotation would still jump after pause / scene suspension. Added active-time phase accumulation.
4. **Pass 4 — FAIL / P0 correctness:** first phase-clock draft force-unwrapped a nil rotation anchor when the ring could render while paused. Replaced with a nil-safe zero delta before any branch update.
5. **Pass 5 — PASS within this repair scope:** fresh correctness, regression, performance, safety, resource, accessibility, and maintainability review found no remaining P0/P1/P2 defect introduced by or directly belonging to this queue/moon-ring repair.

## Portable validation

Executed without GitHub Actions:

- Swift 6.2.1 `swiftc -parse` on the new queue-panel source — pass.
- Swift 6.2.1 `swiftc -parse` on an exact extracted final `AudioEnergyRing` implementation — pass.
- Standalone Swift 6.2.1 `-strict-concurrency=complete` type-check of the same `@MainActor` + `withObservationTracking` re-registration pattern — pass.
- Circular-buffer deterministic check: physical `[5,2,3,4]` with `writeIndex == 1` reconstructs chronological `[2,3,4,5]` — pass.
- Candidate commit fresh-diff inspection after every repair — pass at stop condition.

These checks do not substitute for Xcode type-check/build or Instruments on macOS/iPadOS. The existing AERO-F26 sensory gate therefore remains meaningful: verify sustained playback, pause/resume, rapid track switching, and real NAS playback on an Apple runtime.

## Existing risks deliberately not misrepresented as fixed

The 2026-09-04 reliability audit already records two separate residual design edges: playback replacement failure does not fully restore user-visible position, and extremely large cross-source queues are prepared too eagerly. This patch does not alter those state machines and does not claim to close them. They remain under their existing playback/queue follow-up scope.

## Stop condition

For the reported right-column hitch and moon-ring stutter/regression, the final candidate has no remaining source-level P2-or-higher finding in the repeated strict review. Runtime frame pacing must still be measured on Apple hardware; until that sensory gate is exercised, this report claims source convergence, not measured FPS.
