//! Headless `egui_kittest` Tier 1 suite (card #653, ADR-013).
//!
//! Single integration target: downstream UI cards add exactly one
//! `mod <area>;` line below plus their own file beside this one,
//! reusing [`harness`] so snapshot names stay prefixed per card
//! (for example `card_653/...`, `card_642/...`).

mod harness;

mod card_653;
mod exploration;
mod pantry;
