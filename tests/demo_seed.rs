//! Demo seed populates view state and shows resolved names, not raw IDs.

use mimir::app::state::{AppState, LoadState};
use mimir::demo::data::{load_demo_bundle, load_demo_names, seed_demo_state};
use mimir::names::sde::Sde;

#[test]
fn demo_bundle_loads() {
    let bundle = load_demo_bundle().expect("demo bundle loads");
    assert!(!bundle.characters.is_empty());
    assert!(!bundle.skill_queue.is_empty());
    assert!(bundle.balance > 0.0);
}

#[test]
fn demo_seed_populates_state() {
    let mut state = AppState::new(true);
    seed_demo_state(&mut state);
    assert!(!state.characters.is_empty());
    assert!(state.active_character().is_some());
    assert!(matches!(state.skills, LoadState::Ready(_)));
    assert!(matches!(state.wallet, LoadState::Ready(_)));
}

#[test]
fn demo_skill_names_resolve_from_sde() {
    let sde = Sde::load_bundled().expect("SDE loads");
    assert_eq!(sde.skill_name(3300), "Gunnery");
    // The only raw-ID-shaped fallback allowed is the SDE-miss form.
    assert_eq!(sde.skill_name(999999999), "Skill #999999999");
    let names = load_demo_names().expect("demo names load");
    assert!(names.iter().all(|n| !n.name.is_empty()));
    assert!(names.iter().all(|n| n.name.parse::<i64>().is_err()));
}
