# CMVCore C ABI v1

The ABI exposes a deliberately small bytes-in/owned-buffer-out contract. Swift
never passes SwiftData models, security-scoped URLs, AVFoundation objects, or
Rust-owned handles across the boundary.

All integers are little-endian. Strings use a `u32` byte length followed by
UTF-8 bytes. Counts are `u32` and implementations reject truncated, invalid,
unknown-version, invalid-UTF-8, duplicate-identity, or trailing input.

## Request

```text
"CMV1" | u16 version=1 | u8 source_reachable
u32 existing_count | u32 scanned_count
existing[]: string id | string path | u64 size | i64 modified_ms |
            string title | u8 availability
scanned[]:  string id | string path | u64 size | i64 modified_ms |
            string title
```

Availability is `0 available`, `1 source_offline`, `2 missing`, or
`3 permission_required`.

## Response

```text
"CMV1" | u16 version=1 | u32 upsert_count
upserts[]: u8 kind | scanned-file fields
u32 missing_count | missing[]: string identifier
```

Upsert kind is `0 insert` or `1 update`.

## Playback plan request

```text
"CMV1" | u16 version=1 | u32 engine_sample_rate_hz
current track | next track
track: u32 sample_rate_hz | u64 total_frames | u64 start_frame |
       optional f64 replay_gain_db | optional f64 peak
optional f64: u8 present | f64 value when present=1
```

The playback response is:

```text
"CMV1" | u16 version=1 | u64 current_start_frame |
u64 current_frame_count | u64 next_start_engine_frame |
f64 current_gain_linear | f64 next_gain_linear
```

Timeline math uses integer frame ratios and nearest-frame rounding. ReplayGain
is converted to linear gain, capped at +12 dB, and further clamped by peak when
present so the Apple limiter remains a final safety net rather than the primary
normalizer.

On success Swift owns `CMVOwnedBufferV1` and releases it exactly once through
`cmv_core_buffer_free_v1`. Every failure initializes the output to the zero
buffer. No Rust panic may unwind across the C boundary. Status `0` is success;
`1`/`2` are invalid pointer/payload, `3` reconciliation failure, `4` playback
failure, `5` search failure, `6` analysis failure, `7` Smart DJ failure, `8`
cache failure, and `255` is a caught Rust panic.

## Search request

```text
"CMV1" | u16 version=1 | string query | u32 limit | u32 track_count
tracks[]: string id | string title | string artist | string album |
          u8 favorite | u8 rating
```

The search response is:

```text
"CMV1" | u16 version=1 | u32 result_count
results[]: string identifier | u32 score
```

Rust lowercases and normalizes whitespace, requires every query token to match,
then scores exact/word/substring matches with favorite and rating tie-breakers.
Sorting is deterministic by score, normalized title, identifier, and input
position. Metadata extraction and SwiftData persistence remain on the Apple
side; only value DTOs cross the ABI.

## PCM analysis request

`cmv_core_analyze_pcm_v1` accepts:

```text
"CMV1" | u16 version=1 | u32 sample_rate_hz | u16 channels |
u32 sample_count | sample_count × little-endian f32 samples
```

Samples are interleaved normalized PCM. The response is versioned and contains
integrated loudness (LUFS), peak, energy, brightness, and optional BPM and
pitch-class key. Analysis version `2` applies the BS.1770 K-weighting cascade,
400 ms blocks with 75% overlap, and absolute (−70 LUFS) plus relative (−10 dB)
gating. Swift owns AVFoundation file access and PCM acquisition; Rust owns
deterministic feature calculation. The response wire layout is:

```text
"CMV1" | u16 version=1 | u32 analysis_version |
f64 integrated_loudness_lufs | f64 peak | f64 energy | f64 brightness |
u8 bpm_present | f64 bpm when present=1 |
u8 musical_key_present | u8 pitch_class when present=1
```

Invalid input returns status `6`; the output buffer is empty on failure.
The analyzer processes complete 400 ms windows only. For the common six-channel
interleaving `(L, R, C, LFE, Ls, Rs)`, BS.1770 applies unity front-channel gain,
1.41 surround gain, and excludes LFE; other channel counts use unity weights
because the v1 ABI intentionally carries no channel-layout object.

## Smart DJ request

`cmv_core_make_dj_v1` accepts:

```text
"CMV1" | u16 version=1 | u32 limit | u32 track_count |
track_count × (string identifier | string title | u8 favorite | u8 rating |
               u8 bpm_present | f64 bpm when present=1 |
               f64 energy | u32 play_count | u32 skip_count)
```

The response is:

```text
"CMV1" | u16 version=1 | u32 result_count |
result_count × (string identifier | f64 score | u32 reason_count |
                reason_count × string reason)
```

It is fully offline and deterministic; status `7` is reserved for DJ failures.

## Cache eviction request

`cmv_core_eviction_plan_v1` accepts:

```text
"CMV1" | u16 version=1 | u64 budget_bytes | u32 entry_count
entries[]: string identifier | u64 size_bytes | u8 pinned | u64 last_access_order
```

The response is:

```text
"CMV1" | u16 version=1 | u32 eviction_count | eviction_count × string identifier
```

Rust sorts unpinned entries by `last_access_order` and identifier, returning
the oldest entries required to meet the budget. Swift owns all file deletion,
manifest persistence, and checksum verification.
