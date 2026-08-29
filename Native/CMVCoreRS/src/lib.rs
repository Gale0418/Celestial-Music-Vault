#![forbid(unsafe_code)]

//! Platform-neutral CMV core.
//!
//! This crate starts as a shadow implementation. Apple platform objects and
//! filesystem authorization remain in Swift; this crate accepts owned value
//! snapshots and returns deterministic reconciliation decisions.

mod analysis;
mod cache;
mod dj;
mod playback;
mod reconciliation;
mod search;

pub use analysis::{AnalysisError, AnalysisFeatures, analyze_pcm};
pub use cache::{CacheEntry, eviction_plan};
pub use dj::{DJSelection, DJTrack, make_queue};
pub use playback::{PlaybackPlan, PlaybackPlanError, TimelineTrack, plan_playback_pair};

pub use reconciliation::{
    Availability, ReconcileError, Reconciliation, ScannedFile, TrackSnapshot, Upsert, UpsertKind,
    reconcile_scan,
};

pub use search::{SearchResult, SearchTrack, search_tracks};
