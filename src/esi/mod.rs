//! ESI client, typed endpoints, and response models (`[ESI]` tag; feature
//! tags `[CHAR]`/`[SKILLS]`/`[WALLET]` on domain calls).

pub mod client;
pub mod endpoints;
pub mod models;

pub use client::{EsiClient, EsiMeta};
