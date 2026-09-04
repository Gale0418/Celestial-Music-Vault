#![deny(unsafe_op_in_unsafe_fn)]

use std::panic::{AssertUnwindSafe, catch_unwind};
use std::ptr;

use cmv_core_rs::{
    Availability, CacheEntry, DJTrack, PlaybackPlan, ReconcileError, Reconciliation, ScannedFile,
    SearchTrack, TimelineTrack, TrackSnapshot, UpsertKind, analyze_pcm, eviction_plan, make_queue,
    plan_playback_pair, reconcile_scan, search_tracks,
};

const MAGIC: &[u8; 4] = b"CMV1";
const ABI_VERSION: u16 = 1;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct CMVOwnedBufferV1 {
    pub ptr: *mut u8,
    pub len: usize,
}

impl Default for CMVOwnedBufferV1 {
    fn default() -> Self {
        Self {
            ptr: ptr::null_mut(),
            len: 0,
        }
    }
}

#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CMVStatusV1 {
    Ok = 0,
    InvalidArgument = 1,
    InvalidPayload = 2,
    ReconciliationFailed = 3,
    PlaybackPlanFailed = 4,
    SearchFailed = 5,
    AnalysisFailed = 6,
    DJFailed = 7,
    CacheFailed = 8,
    Panic = 255,
}

#[unsafe(no_mangle)]
pub extern "C" fn cmv_core_abi_version_v1() -> u32 {
    u32::from(ABI_VERSION)
}

/// Reconciles one complete scan encoded with the CMVCore v1 binary contract.
///
/// # Safety
///
/// `input_ptr` must address `input_len` readable bytes for the duration of this
/// call. `out_buffer` must point to writable storage for one
/// [`CMVOwnedBufferV1`]. On success, the caller owns the returned buffer and
/// must release it exactly once with [`cmv_core_buffer_free_v1`].
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_reconcile_v1(
    input_ptr: *const u8,
    input_len: usize,
    out_buffer: *mut CMVOwnedBufferV1,
) -> i32 {
    if !out_buffer.is_null() {
        unsafe { out_buffer.write(CMVOwnedBufferV1::default()) };
    }
    if out_buffer.is_null() || (input_ptr.is_null() && input_len != 0) {
        return CMVStatusV1::InvalidArgument as i32;
    }

    let status = catch_unwind(AssertUnwindSafe(|| {
        let input = if input_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
        };
        let request = match decode_request(input) {
            Ok(request) => request,
            Err(()) => return CMVStatusV1::InvalidPayload,
        };
        let reconciliation = match reconcile_scan(
            &request.existing,
            &request.scanned,
            request.source_reachable,
        ) {
            Ok(result) => result,
            Err(error) => return status_for_reconcile_error(error),
        };
        let bytes = encode_response(&reconciliation);
        let owned = leak_bytes(bytes);
        unsafe { out_buffer.write(owned) };
        CMVStatusV1::Ok
    }));

    match status {
        Ok(status) => status as i32,
        Err(_) => CMVStatusV1::Panic as i32,
    }
}

/// Builds a deterministic two-track sample timeline and safe linear gains.
///
/// # Safety
///
/// The pointer and ownership requirements are identical to
/// [`cmv_core_reconcile_v1`].
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_plan_playback_v1(
    input_ptr: *const u8,
    input_len: usize,
    out_buffer: *mut CMVOwnedBufferV1,
) -> i32 {
    if !out_buffer.is_null() {
        unsafe { out_buffer.write(CMVOwnedBufferV1::default()) };
    }
    if out_buffer.is_null() || (input_ptr.is_null() && input_len != 0) {
        return CMVStatusV1::InvalidArgument as i32;
    }

    let status = catch_unwind(AssertUnwindSafe(|| {
        let input = if input_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
        };
        let request = match decode_playback_request(input) {
            Ok(request) => request,
            Err(()) => return CMVStatusV1::InvalidPayload,
        };
        let plan = match plan_playback_pair(
            request.engine_sample_rate_hz,
            request.current,
            request.next,
        ) {
            Ok(plan) => plan,
            Err(_) => return CMVStatusV1::PlaybackPlanFailed,
        };
        let owned = leak_bytes(encode_playback_response(plan));
        unsafe { out_buffer.write(owned) };
        CMVStatusV1::Ok
    }));

    match status {
        Ok(status) => status as i32,
        Err(_) => CMVStatusV1::Panic as i32,
    }
}

/// Scores a value-only track snapshot with normalized query tokens.
///
/// # Safety
///
/// The pointer and ownership requirements are identical to
/// [`cmv_core_reconcile_v1`].
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_search_v1(
    input_ptr: *const u8,
    input_len: usize,
    out_buffer: *mut CMVOwnedBufferV1,
) -> i32 {
    if !out_buffer.is_null() {
        unsafe { out_buffer.write(CMVOwnedBufferV1::default()) };
    }
    if out_buffer.is_null() || (input_ptr.is_null() && input_len != 0) {
        return CMVStatusV1::InvalidArgument as i32;
    }

    let status = catch_unwind(AssertUnwindSafe(|| {
        let input = if input_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
        };
        let request = match decode_search_request(input) {
            Ok(request) => request,
            Err(()) => return CMVStatusV1::InvalidPayload,
        };
        let result = search_tracks(&request.query, &request.tracks, request.limit);
        let owned = leak_bytes(encode_search_response(&result));
        unsafe { out_buffer.write(owned) };
        CMVStatusV1::Ok
    }));

    match status {
        Ok(status) => status as i32,
        Err(_) => CMVStatusV1::Panic as i32,
    }
}

/// Extracts deterministic audio features from interleaved normalized PCM.
///
/// # Safety
///
/// `input_ptr` must address `input_len` readable bytes for the duration of the
/// call. `out_buffer` must point to writable storage for one owned buffer.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_analyze_pcm_v1(
    input_ptr: *const u8,
    input_len: usize,
    out_buffer: *mut CMVOwnedBufferV1,
) -> i32 {
    if !out_buffer.is_null() {
        unsafe { out_buffer.write(CMVOwnedBufferV1::default()) };
    }
    if out_buffer.is_null() || (input_ptr.is_null() && input_len != 0) {
        return CMVStatusV1::InvalidArgument as i32;
    }
    let status = catch_unwind(AssertUnwindSafe(|| {
        let input = if input_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
        };
        let request = match decode_analysis_request(input) {
            Ok(request) => request,
            Err(()) => return CMVStatusV1::InvalidPayload,
        };
        let result = match analyze_pcm(&request.samples, request.sample_rate_hz, request.channels) {
            Ok(result) => result,
            Err(_) => return CMVStatusV1::AnalysisFailed,
        };
        unsafe { out_buffer.write(leak_bytes(encode_analysis_response(&result))) };
        CMVStatusV1::Ok
    }));
    match status {
        Ok(status) => status as i32,
        Err(_) => CMVStatusV1::Panic as i32,
    }
}

/// Builds an explainable Smart DJ queue from value-only snapshots.
///
/// # Safety
///
/// `input_ptr` must address `input_len` readable bytes and `out_buffer` must
/// point to writable storage for one owned buffer for the duration of this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_make_dj_v1(
    input_ptr: *const u8,
    input_len: usize,
    out_buffer: *mut CMVOwnedBufferV1,
) -> i32 {
    if !out_buffer.is_null() {
        unsafe { out_buffer.write(CMVOwnedBufferV1::default()) };
    }
    if out_buffer.is_null() || (input_ptr.is_null() && input_len != 0) {
        return CMVStatusV1::InvalidArgument as i32;
    }
    let status = catch_unwind(AssertUnwindSafe(|| {
        let input = if input_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
        };
        let request = match decode_dj_request(input) {
            Ok(request) => request,
            Err(()) => return CMVStatusV1::InvalidPayload,
        };
        let result = make_queue(request.tracks, request.limit);
        unsafe { out_buffer.write(leak_bytes(encode_dj_response(&result))) };
        CMVStatusV1::Ok
    }));
    match status {
        Ok(status) => status as i32,
        Err(_) => CMVStatusV1::Panic as i32,
    }
}

/// Returns deterministic smart-cache identifiers to evict. Rust owns only the
/// value policy; Swift remains responsible for deleting files and manifests.
///
/// # Safety
///
/// `input_ptr` must address `input_len` readable bytes and `out_buffer` must
/// point to writable storage for one owned buffer for the duration of this call.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_eviction_plan_v1(
    input_ptr: *const u8,
    input_len: usize,
    out_buffer: *mut CMVOwnedBufferV1,
) -> i32 {
    if !out_buffer.is_null() {
        unsafe { out_buffer.write(CMVOwnedBufferV1::default()) };
    }
    if out_buffer.is_null() || (input_ptr.is_null() && input_len != 0) {
        return CMVStatusV1::InvalidArgument as i32;
    }
    let status = catch_unwind(AssertUnwindSafe(|| {
        let input = if input_len == 0 {
            &[]
        } else {
            unsafe { std::slice::from_raw_parts(input_ptr, input_len) }
        };
        let request = match decode_cache_request(input) {
            Ok(request) => request,
            Err(()) => return CMVStatusV1::InvalidPayload,
        };
        let identifiers = eviction_plan(&request.entries, request.budget_bytes);
        unsafe { out_buffer.write(leak_bytes(encode_cache_response(&identifiers))) };
        CMVStatusV1::Ok
    }));
    match status {
        Ok(status) => status as i32,
        Err(_) => CMVStatusV1::Panic as i32,
    }
}

/// Releases a buffer returned by [`cmv_core_reconcile_v1`].
///
/// # Safety
///
/// A non-null buffer must have been returned by this ABI and must not have
/// already been released. Passing the zero/default buffer is a no-op.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn cmv_core_buffer_free_v1(buffer: CMVOwnedBufferV1) {
    if buffer.ptr.is_null() {
        return;
    }
    let slice = ptr::slice_from_raw_parts_mut(buffer.ptr, buffer.len);
    unsafe { drop(Box::from_raw(slice)) };
}

struct ReconcileRequest {
    source_reachable: bool,
    existing: Vec<TrackSnapshot>,
    scanned: Vec<ScannedFile>,
}

struct PlaybackRequest {
    engine_sample_rate_hz: u32,
    current: TimelineTrack,
    next: TimelineTrack,
}

struct SearchRequest {
    query: String,
    limit: usize,
    tracks: Vec<SearchTrack>,
}

struct AnalysisRequest {
    sample_rate_hz: u32,
    channels: u16,
    samples: Vec<f32>,
}

struct DJRequest {
    limit: usize,
    tracks: Vec<DJTrack>,
}

struct CacheRequest {
    budget_bytes: u64,
    entries: Vec<CacheEntry>,
}

fn status_for_reconcile_error(_error: ReconcileError) -> CMVStatusV1 {
    CMVStatusV1::ReconciliationFailed
}

fn leak_bytes(bytes: Vec<u8>) -> CMVOwnedBufferV1 {
    if bytes.is_empty() {
        return CMVOwnedBufferV1::default();
    }
    let boxed = bytes.into_boxed_slice();
    let len = boxed.len();
    let ptr = Box::into_raw(boxed).cast::<u8>();
    CMVOwnedBufferV1 { ptr, len }
}

fn decode_request(bytes: &[u8]) -> Result<ReconcileRequest, ()> {
    let mut decoder = Decoder::new(bytes);
    decoder.expect_magic()?;
    if decoder.u16()? != ABI_VERSION {
        return Err(());
    }
    let source_reachable = match decoder.u8()? {
        0 => false,
        1 => true,
        _ => return Err(()),
    };
    let existing_count = decoder.count()?;
    let scanned_count = decoder.count()?;
    let minimum_bytes = existing_count
        .checked_mul(29)
        .and_then(|value| {
            scanned_count
                .checked_mul(28)
                .and_then(|other| value.checked_add(other))
        })
        .ok_or(())?;
    decoder.ensure_bytes(minimum_bytes)?;
    let mut existing = Vec::with_capacity(existing_count);
    let mut scanned = Vec::with_capacity(scanned_count);

    for _ in 0..existing_count {
        existing.push(TrackSnapshot {
            identifier: decoder.string()?,
            relative_path: decoder.string()?,
            file_size: decoder.u64()?,
            modified_at_millis: decoder.i64()?,
            title: decoder.string()?,
            availability: decode_availability(decoder.u8()?)?,
        });
    }
    for _ in 0..scanned_count {
        scanned.push(ScannedFile {
            identifier: decoder.string()?,
            relative_path: decoder.string()?,
            file_size: decoder.u64()?,
            modified_at_millis: decoder.i64()?,
            title: decoder.string()?,
        });
    }
    if !decoder.is_finished() {
        return Err(());
    }
    Ok(ReconcileRequest {
        source_reachable,
        existing,
        scanned,
    })
}

fn encode_response(result: &Reconciliation) -> Vec<u8> {
    let mut encoder = Encoder::default();
    encoder.bytes.extend_from_slice(MAGIC);
    encoder.u16(ABI_VERSION);
    encoder.u32(result.upserts.len() as u32);
    for upsert in &result.upserts {
        encoder.u8(match upsert.kind {
            UpsertKind::Insert => 0,
            UpsertKind::Update => 1,
        });
        encoder.scanned_file(&upsert.file);
    }
    encoder.u32(result.missing_identifiers.len() as u32);
    for identifier in &result.missing_identifiers {
        encoder.string(identifier);
    }
    encoder.bytes
}

fn decode_playback_request(bytes: &[u8]) -> Result<PlaybackRequest, ()> {
    let mut decoder = Decoder::new(bytes);
    decoder.expect_magic()?;
    if decoder.u16()? != ABI_VERSION {
        return Err(());
    }
    let request = PlaybackRequest {
        engine_sample_rate_hz: decoder.u32()?,
        current: decoder.timeline_track()?,
        next: decoder.timeline_track()?,
    };
    if !decoder.is_finished() {
        return Err(());
    }
    Ok(request)
}

fn encode_playback_response(plan: PlaybackPlan) -> Vec<u8> {
    let mut encoder = Encoder::default();
    encoder.bytes.extend_from_slice(MAGIC);
    encoder.u16(ABI_VERSION);
    encoder.u64(plan.current_start_frame);
    encoder.u64(plan.current_frame_count);
    encoder.u64(plan.next_start_engine_frame);
    encoder.f64(plan.current_gain_linear);
    encoder.f64(plan.next_gain_linear);
    encoder.bytes
}

fn decode_search_request(bytes: &[u8]) -> Result<SearchRequest, ()> {
    let mut decoder = Decoder::new(bytes);
    decoder.expect_magic()?;
    if decoder.u16()? != ABI_VERSION {
        return Err(());
    }
    let query = decoder.string()?;
    let limit = decoder.count()?;
    let count = decoder.count()?;
    decoder.ensure_count_fits(count, 18)?;
    let mut tracks = Vec::with_capacity(count);
    for _ in 0..count {
        tracks.push(SearchTrack {
            identifier: decoder.string()?,
            title: decoder.string()?,
            artist: decoder.string()?,
            album: decoder.string()?,
            favorite: decoder.u8()? != 0,
            rating: decoder.u8()?,
        });
    }
    if !decoder.is_finished() {
        return Err(());
    }
    Ok(SearchRequest {
        query,
        limit,
        tracks,
    })
}

fn encode_search_response(result: &[cmv_core_rs::SearchResult]) -> Vec<u8> {
    let mut encoder = Encoder::default();
    encoder.bytes.extend_from_slice(MAGIC);
    encoder.u16(ABI_VERSION);
    encoder.u32(result.len() as u32);
    for item in result {
        encoder.string(&item.identifier);
        encoder.u32(item.score);
    }
    encoder.bytes
}

fn decode_analysis_request(bytes: &[u8]) -> Result<AnalysisRequest, ()> {
    let mut decoder = Decoder::new(bytes);
    decoder.expect_magic()?;
    if decoder.u16()? != ABI_VERSION {
        return Err(());
    }
    let sample_rate_hz = decoder.u32()?;
    let channels = decoder.u16()?;
    if channels == 0 {
        return Err(());
    }
    let sample_count = decoder.count()?;
    decoder.ensure_count_fits(sample_count, 4)?;
    let mut samples = Vec::with_capacity(sample_count);
    for _ in 0..sample_count {
        samples.push(decoder.f32()?);
    }
    if !decoder.is_finished() || sample_count % usize::from(channels) != 0 {
        return Err(());
    }
    Ok(AnalysisRequest {
        sample_rate_hz,
        channels,
        samples,
    })
}

fn encode_analysis_response(result: &cmv_core_rs::AnalysisFeatures) -> Vec<u8> {
    let mut encoder = Encoder::default();
    encoder.bytes.extend_from_slice(MAGIC);
    encoder.u16(ABI_VERSION);
    encoder.u32(result.version);
    encoder.f64(result.integrated_loudness_lufs);
    encoder.f64(result.peak);
    encoder.f64(result.energy);
    encoder.f64(result.brightness);
    encoder.optional_f64(result.bpm);
    encoder.optional_u8(result.musical_key);
    encoder.bytes
}

fn decode_dj_request(bytes: &[u8]) -> Result<DJRequest, ()> {
    let mut decoder = Decoder::new(bytes);
    decoder.expect_magic()?;
    if decoder.u16()? != ABI_VERSION {
        return Err(());
    }
    let limit = decoder.count()?;
    let count = decoder.count()?;
    decoder.ensure_count_fits(count, 27)?;
    let mut tracks = Vec::with_capacity(count);
    for _ in 0..count {
        tracks.push(DJTrack {
            identifier: decoder.string()?,
            title: decoder.string()?,
            favorite: decoder.u8()? != 0,
            rating: decoder.u8()?.min(5),
            bpm: decoder.optional_f64()?,
            energy: decoder.f64()?,
            play_count: decoder.u32()?,
            skip_count: decoder.u32()?,
        });
    }
    if !decoder.is_finished() {
        return Err(());
    }
    Ok(DJRequest { limit, tracks })
}

fn encode_dj_response(result: &[cmv_core_rs::DJSelection]) -> Vec<u8> {
    let mut encoder = Encoder::default();
    encoder.bytes.extend_from_slice(MAGIC);
    encoder.u16(ABI_VERSION);
    encoder.u32(result.len() as u32);
    for selection in result {
        encoder.string(&selection.identifier);
        encoder.f64(selection.score);
        encoder.u32(selection.reasons.len() as u32);
        for reason in &selection.reasons {
            encoder.string(reason);
        }
    }
    encoder.bytes
}

fn decode_cache_request(bytes: &[u8]) -> Result<CacheRequest, ()> {
    let mut decoder = Decoder::new(bytes);
    decoder.expect_magic()?;
    if decoder.u16()? != ABI_VERSION {
        return Err(());
    }
    let budget_bytes = decoder.u64()?;
    let count = decoder.count()?;
    decoder.ensure_count_fits(count, 21)?;
    let mut entries = Vec::with_capacity(count);
    for _ in 0..count {
        entries.push(CacheEntry {
            identifier: decoder.string()?,
            size_bytes: decoder.u64()?,
            pinned: match decoder.u8()? {
                0 => false,
                1 => true,
                _ => return Err(()),
            },
            last_access_order: decoder.u64()?,
        });
    }
    if !decoder.is_finished() {
        return Err(());
    }
    Ok(CacheRequest {
        budget_bytes,
        entries,
    })
}

fn encode_cache_response(result: &[String]) -> Vec<u8> {
    let mut encoder = Encoder::default();
    encoder.bytes.extend_from_slice(MAGIC);
    encoder.u16(ABI_VERSION);
    encoder.u32(result.len() as u32);
    for identifier in result {
        encoder.string(identifier);
    }
    encoder.bytes
}

fn decode_availability(value: u8) -> Result<Availability, ()> {
    match value {
        0 => Ok(Availability::Available),
        1 => Ok(Availability::SourceOffline),
        2 => Ok(Availability::Missing),
        3 => Ok(Availability::PermissionRequired),
        _ => Err(()),
    }
}

struct Decoder<'a> {
    bytes: &'a [u8],
    offset: usize,
}

impl<'a> Decoder<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, offset: 0 }
    }

    fn expect_magic(&mut self) -> Result<(), ()> {
        if self.take(MAGIC.len())? == MAGIC {
            Ok(())
        } else {
            Err(())
        }
    }

    fn count(&mut self) -> Result<usize, ()> {
        usize::try_from(self.u32()?).map_err(|_| ())
    }

    fn ensure_count_fits(&self, count: usize, minimum_bytes_per_item: usize) -> Result<(), ()> {
        let required = count.checked_mul(minimum_bytes_per_item).ok_or(())?;
        self.ensure_bytes(required)
    }

    fn ensure_bytes(&self, required: usize) -> Result<(), ()> {
        (required <= self.bytes.len().saturating_sub(self.offset))
            .then_some(())
            .ok_or(())
    }

    fn string(&mut self) -> Result<String, ()> {
        let length = self.count()?;
        let bytes = self.take(length)?;
        std::str::from_utf8(bytes)
            .map(str::to_owned)
            .map_err(|_| ())
    }

    fn u8(&mut self) -> Result<u8, ()> {
        Ok(self.take(1)?[0])
    }

    fn u16(&mut self) -> Result<u16, ()> {
        Ok(u16::from_le_bytes(
            self.take(2)?.try_into().map_err(|_| ())?,
        ))
    }

    fn u32(&mut self) -> Result<u32, ()> {
        Ok(u32::from_le_bytes(
            self.take(4)?.try_into().map_err(|_| ())?,
        ))
    }

    fn u64(&mut self) -> Result<u64, ()> {
        Ok(u64::from_le_bytes(
            self.take(8)?.try_into().map_err(|_| ())?,
        ))
    }

    fn i64(&mut self) -> Result<i64, ()> {
        Ok(i64::from_le_bytes(
            self.take(8)?.try_into().map_err(|_| ())?,
        ))
    }

    fn f64(&mut self) -> Result<f64, ()> {
        let value = f64::from_le_bytes(
            self.take(8)?.try_into().map_err(|_| ())?,
        );
        value.is_finite().then_some(value).ok_or(())
    }

    fn f32(&mut self) -> Result<f32, ()> {
        let value = f32::from_le_bytes(
            self.take(4)?.try_into().map_err(|_| ())?,
        );
        value.is_finite().then_some(value).ok_or(())
    }

    fn optional_f64(&mut self) -> Result<Option<f64>, ()> {
        match self.u8()? {
            0 => Ok(None),
            1 => Ok(Some(self.f64()?)),
            _ => Err(()),
        }
    }

    fn timeline_track(&mut self) -> Result<TimelineTrack, ()> {
        Ok(TimelineTrack {
            sample_rate_hz: self.u32()?,
            total_frames: self.u64()?,
            start_frame: self.u64()?,
            replay_gain_db: self.optional_f64()?,
            peak: self.optional_f64()?,
        })
    }

    fn take(&mut self, length: usize) -> Result<&'a [u8], ()> {
        let end = self.offset.checked_add(length).ok_or(())?;
        let slice = self.bytes.get(self.offset..end).ok_or(())?;
        self.offset = end;
        Ok(slice)
    }

    fn is_finished(&self) -> bool {
        self.offset == self.bytes.len()
    }
}

#[derive(Default)]
struct Encoder {
    bytes: Vec<u8>,
}

impl Encoder {
    fn scanned_file(&mut self, file: &ScannedFile) {
        self.string(&file.identifier);
        self.string(&file.relative_path);
        self.u64(file.file_size);
        self.i64(file.modified_at_millis);
        self.string(&file.title);
    }

    fn string(&mut self, value: &str) {
        self.u32(value.len() as u32);
        self.bytes.extend_from_slice(value.as_bytes());
    }

    fn u8(&mut self, value: u8) {
        self.bytes.push(value);
    }

    fn u16(&mut self, value: u16) {
        self.bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn u32(&mut self, value: u32) {
        self.bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn u64(&mut self, value: u64) {
        self.bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn i64(&mut self, value: i64) {
        self.bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn f64(&mut self, value: f64) {
        self.bytes.extend_from_slice(&value.to_le_bytes());
    }

    #[allow(dead_code)]
    fn f32(&mut self, value: f32) {
        self.bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn optional_f64(&mut self, value: Option<f64>) {
        match value {
            Some(value) => {
                self.u8(1);
                self.f64(value);
            }
            None => self.u8(0),
        }
    }

    fn optional_u8(&mut self, value: Option<u8>) {
        match value {
            Some(value) => {
                self.u8(1);
                self.u8(value);
            }
            None => self.u8(0),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn abi_reconciles_and_returns_owned_bytes() {
        let request = encode_test_request();
        let mut output = CMVOwnedBufferV1::default();
        let status = unsafe { cmv_core_reconcile_v1(request.as_ptr(), request.len(), &mut output) };

        assert_eq!(status, CMVStatusV1::Ok as i32);
        assert!(!output.ptr.is_null());
        assert!(output.len > 10);
        let response = unsafe { std::slice::from_raw_parts(output.ptr, output.len) };
        assert_eq!(&response[..4], MAGIC);
        unsafe { cmv_core_buffer_free_v1(output) };
    }

    #[test]
    fn invalid_payload_initializes_output_and_returns_an_error() {
        let mut output = CMVOwnedBufferV1 {
            ptr: ptr::dangling_mut(),
            len: 99,
        };
        let status = unsafe { cmv_core_reconcile_v1(ptr::null(), 0, &mut output) };

        assert_eq!(status, CMVStatusV1::InvalidPayload as i32);
        assert!(output.ptr.is_null());
        assert_eq!(output.len, 0);
    }

    #[test]
    fn invalid_arguments_zero_non_null_outputs_for_every_endpoint() {
        let endpoints: &[unsafe extern "C" fn(*const u8, usize, *mut CMVOwnedBufferV1) -> i32] = &[
            cmv_core_reconcile_v1,
            cmv_core_plan_playback_v1,
            cmv_core_search_v1,
            cmv_core_analyze_pcm_v1,
            cmv_core_make_dj_v1,
            cmv_core_eviction_plan_v1,
        ];

        for endpoint in endpoints {
            let mut output = CMVOwnedBufferV1 {
                ptr: ptr::dangling_mut(),
                len: 99,
            };
            let status = unsafe { endpoint(ptr::null(), 1, &mut output) };

            assert_eq!(status, CMVStatusV1::InvalidArgument as i32);
            assert!(output.ptr.is_null());
            assert_eq!(output.len, 0);
        }
    }

    #[test]
    fn null_output_is_rejected_without_reading_input() {
        let status = unsafe { cmv_core_reconcile_v1(ptr::null(), 0, ptr::null_mut()) };
        assert_eq!(status, CMVStatusV1::InvalidArgument as i32);
    }

    #[test]
    fn panic_boundary_maps_panics_to_status_code() {
        let result = catch_unwind(AssertUnwindSafe(|| -> CMVStatusV1 { panic!("fixture") }));
        let status = match result {
            Ok(status) => status,
            Err(_) => CMVStatusV1::Panic,
        };
        assert_eq!(status, CMVStatusV1::Panic);
    }

    #[test]
    fn abi_builds_playback_timeline_and_owned_response() {
        let mut encoder = Encoder::default();
        encoder.bytes.extend_from_slice(MAGIC);
        encoder.u16(ABI_VERSION);
        encoder.u32(48_000);
        encode_test_timeline_track(&mut encoder, 44_100, 441_000, 44_100, Some(-6.0));
        encode_test_timeline_track(&mut encoder, 48_000, 960_000, 0, None);

        let mut output = CMVOwnedBufferV1::default();
        let status = unsafe {
            cmv_core_plan_playback_v1(encoder.bytes.as_ptr(), encoder.bytes.len(), &mut output)
        };
        assert_eq!(status, CMVStatusV1::Ok as i32);
        let response = unsafe { std::slice::from_raw_parts(output.ptr, output.len) };
        assert_eq!(&response[..4], MAGIC);
        assert_eq!(
            u64::from_le_bytes(response[22..30].try_into().unwrap()),
            432_000
        );
        unsafe { cmv_core_buffer_free_v1(output) };
    }

    #[test]
    fn abi_searches_and_returns_ranked_owned_results() {
        let mut encoder = Encoder::default();
        encoder.bytes.extend_from_slice(MAGIC);
        encoder.u16(ABI_VERSION);
        encoder.string("moon");
        encoder.u32(10);
        encoder.u32(2);
        encoder.string("b");
        encoder.string("Moon Lane");
        encoder.string("Artist");
        encoder.string("Album");
        encoder.u8(0);
        encoder.u8(0);
        encoder.string("a");
        encoder.string("Moon");
        encoder.string("Artist");
        encoder.string("Album");
        encoder.u8(1);
        encoder.u8(5);

        let mut output = CMVOwnedBufferV1::default();
        let status =
            unsafe { cmv_core_search_v1(encoder.bytes.as_ptr(), encoder.bytes.len(), &mut output) };
        assert_eq!(status, CMVStatusV1::Ok as i32);
        let response = unsafe { std::slice::from_raw_parts(output.ptr, output.len) };
        assert_eq!(&response[..4], MAGIC);
        assert_eq!(u32::from_le_bytes(response[6..10].try_into().unwrap()), 2);
        unsafe { cmv_core_buffer_free_v1(output) };
    }

    #[test]
    fn abi_analyzes_pcm_and_returns_versioned_features() {
        let mut encoder = Encoder::default();
        encoder.bytes.extend_from_slice(MAGIC);
        encoder.u16(ABI_VERSION);
        encoder.u32(4_000);
        encoder.u16(1);
        encoder.u32(4_000);
        for index in 0..4_000 {
            let phase = f64::from(index) / 4_000.0;
            encoder.f32((phase * 2.0 * std::f64::consts::PI * 440.0).sin() as f32);
        }
        let mut output = CMVOwnedBufferV1::default();
        let status = unsafe {
            cmv_core_analyze_pcm_v1(encoder.bytes.as_ptr(), encoder.bytes.len(), &mut output)
        };
        assert_eq!(status, CMVStatusV1::Ok as i32);
        let response = unsafe { std::slice::from_raw_parts(output.ptr, output.len) };
        assert_eq!(&response[..4], MAGIC);
        assert_eq!(u32::from_le_bytes(response[6..10].try_into().unwrap()), 2);
        unsafe { cmv_core_buffer_free_v1(output) };
    }

    #[test]
    fn non_finite_float_payloads_are_rejected() {
        let mut pcm = Encoder::default();
        pcm.bytes.extend_from_slice(MAGIC);
        pcm.u16(ABI_VERSION);
        pcm.u32(4_000);
        pcm.u16(1);
        pcm.u32(1);
        pcm.f32(f32::NAN);
        let mut output = CMVOwnedBufferV1::default();
        let status = unsafe {
            cmv_core_analyze_pcm_v1(pcm.bytes.as_ptr(), pcm.bytes.len(), &mut output)
        };
        assert_eq!(status, CMVStatusV1::InvalidPayload as i32);
        assert!(output.ptr.is_null());
        assert_eq!(output.len, 0);

        let mut playback = Encoder::default();
        playback.bytes.extend_from_slice(MAGIC);
        playback.u16(ABI_VERSION);
        playback.u32(48_000);
        encode_test_timeline_track(&mut playback, 44_100, 441_000, 44_100, Some(f64::NAN));
        encode_test_timeline_track(&mut playback, 48_000, 960_000, 0, None);
        let status = unsafe {
            cmv_core_plan_playback_v1(
                playback.bytes.as_ptr(),
                playback.bytes.len(),
                &mut output,
            )
        };
        assert_eq!(status, CMVStatusV1::InvalidPayload as i32);
        assert!(output.ptr.is_null());
        assert_eq!(output.len, 0);

        for (bpm, energy) in [(Some(f64::NAN), 0.5), (None, f64::INFINITY)] {
            let request = encode_test_dj_request(bpm, energy);
            let status = unsafe {
                cmv_core_make_dj_v1(request.as_ptr(), request.len(), &mut output)
            };
            assert_eq!(status, CMVStatusV1::InvalidPayload as i32);
            assert!(output.ptr.is_null());
            assert_eq!(output.len, 0);
        }
    }

    fn encode_test_request() -> Vec<u8> {
        let mut encoder = Encoder::default();
        encoder.bytes.extend_from_slice(MAGIC);
        encoder.u16(ABI_VERSION);
        encoder.u8(1);
        encoder.u32(1);
        encoder.u32(1);
        encoder.string("a");
        encoder.string("a.flac");
        encoder.u64(10);
        encoder.i64(100);
        encoder.string("Old A");
        encoder.u8(0);
        encoder.string("a");
        encoder.string("new/a.flac");
        encoder.u64(11);
        encoder.i64(101);
        encoder.string("New A");
        encoder.bytes
    }

    fn encode_test_dj_request(bpm: Option<f64>, energy: f64) -> Vec<u8> {
        let mut encoder = Encoder::default();
        encoder.bytes.extend_from_slice(MAGIC);
        encoder.u16(ABI_VERSION);
        encoder.u32(1);
        encoder.u32(1);
        encoder.string("track");
        encoder.string("Track");
        encoder.u8(0);
        encoder.u8(0);
        encoder.optional_f64(bpm);
        encoder.f64(energy);
        encoder.u32(0);
        encoder.u32(0);
        encoder.bytes
    }

    fn encode_test_timeline_track(
        encoder: &mut Encoder,
        sample_rate_hz: u32,
        total_frames: u64,
        start_frame: u64,
        replay_gain_db: Option<f64>,
    ) {
        encoder.u32(sample_rate_hz);
        encoder.u64(total_frames);
        encoder.u64(start_frame);
        if let Some(gain) = replay_gain_db {
            encoder.u8(1);
            encoder.f64(gain);
        } else {
            encoder.u8(0);
        }
        encoder.u8(0);
    }
}
