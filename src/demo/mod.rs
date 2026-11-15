//! Offline demo mode (F4): fictional bundled sample data behind the same
//! ESI model, repository, and `AppState` types as the live path. Selected
//! by the `--demo` flag or the `MIMIR_DEMO` environment variable
//! (`data::demo_requested_from_process`); no network, display, or EVE
//! credentials are needed to load or test it.

pub mod data;
