//! Skill plans: user-authored per-character training plans.
//!
//! Pure domain logic — no egui, no `AppState`, no network, no database,
//! following the `src/fitting/` pure-module precedent (design section 4).

pub mod plans;
pub mod prereqs;
pub mod training;
