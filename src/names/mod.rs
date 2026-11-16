//! EVE ID-to-name resolution. Skills come from the bundled SDE extract;
//! everything else resolves memory → database → ESI. The interface shows
//! resolved names only, never raw numeric IDs.

pub mod exploration_ref;
pub mod resolver;
pub mod sde;

pub use resolver::NameResolver;
pub use sde::Sde;
