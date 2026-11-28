//! Exploration domain (#646): tuple-cost routing, probe
//! notebook, Eve-Scout highways. Pure/offline-first; notebook
//! data never transmits externally and unverified scans never
//! become route edges. Logs use `[EXPLORE]` (in LOG_TAGS).

pub mod evescout;
pub mod notebook;
pub mod router;
