//! Demo mode end to end without network or display: bundle loading,
//! skill-queue finish math at a fixed instant, wallet aggregation,
//! journal balance-chain consistency, name-resolution fallbacks, and
//! `AppState` seeding. Every display string must be a resolved EVE name,
//! never a raw numeric ID (SDE misses show "Unknown Skill").

use mimir::app::state::{AppState, LoadState};
use mimir::demo::data::{
    apply_character, currently_training, demo_resolver, is_demo_requested, journal_since,
    load_demo_bundle, load_demo_names, net_by_ref_type, parse_esi_datetime, queue_end,
    seconds_until_finish, seed_demo_state, summarize_wallet, training_progress,
};
use mimir::names::resolver::{UNKNOWN_ITEM, UNKNOWN_LOCATION};
use mimir::names::sde::Sde;

const ARIA: i64 = 90000001;
const MARCUS: i64 = 90000002;

fn now() -> chrono::DateTime<chrono::Utc> {
    parse_esi_datetime("2026-11-15T12:00:00Z").expect("fixed now parses")
}

fn approx(a: f64, b: f64) -> bool {
    (a - b).abs() < 0.001
}

#[test]
fn demo_bundle_has_two_characters_with_queues_and_wallets() {
    let bundle = load_demo_bundle().expect("demo bundle loads");
    assert_eq!(bundle.characters.len(), 2);
    assert_eq!(bundle.characters[0].name, "Aria Voss");
    assert_eq!(bundle.characters[1].name, "Marcus Hale");
    for character in &bundle.characters {
        let per = bundle
            .character_data(character.character_id)
            .expect("per-character data exists");
        assert!(!per.queue.is_empty(), "queue for {}", character.name);
        assert!(!per.skills.skills.is_empty());
        assert!(!per.journal.is_empty(), "journal for {}", character.name);
        assert!(!per.transactions.is_empty());
        assert!(per.balance > 0.0);
        assert!(per.skills.total_sp > 0);
    }
}

#[test]
fn demo_selection_by_flag_and_env() {
    let plain = vec!["mimir".to_string()];
    assert!(!is_demo_requested(&plain, None));
    assert!(is_demo_requested(&plain, Some("true")));
    assert!(is_demo_requested(
        &["mimir".to_string(), "--demo".to_string()],
        None
    ));
}

#[test]
fn queue_finish_math_for_both_characters() {
    let bundle = load_demo_bundle().expect("bundle");
    let now = now();

    // Aria: Gunnery V runs 2026-11-10 -> 11-20, so at 11-15T12:00 exactly
    // half the span has elapsed and 5 days remain; queue ends 11-28.
    let aria = bundle.character_data(ARIA).expect("aria data");
    let training = currently_training(&aria.queue, now).expect("aria is training");
    assert_eq!(training.skill_id, 3300);
    assert_eq!(seconds_until_finish(training, now), Some(5 * 24 * 3600));
    let progress = training_progress(training, now).expect("progress");
    assert!(approx(progress, 0.5));
    assert_eq!(
        queue_end(&aria.queue),
        parse_esi_datetime("2026-11-28T12:00:00Z")
    );

    // Marcus: Spaceship Command V runs 2026-11-12 -> 11-22 (7 days left).
    let marcus = bundle.character_data(MARCUS).expect("marcus data");
    let training = currently_training(&marcus.queue, now).expect("marcus is training");
    assert_eq!(training.skill_id, 3327);
    assert_eq!(seconds_until_finish(training, now), Some(7 * 24 * 3600));
    let progress = training_progress(training, now).expect("progress");
    assert!(approx(progress, 0.3));

    // The training skills resolve to real SDE names for display.
    let sde = Sde::load_bundled().expect("SDE loads");
    assert_eq!(sde.skill_name(3300), "Gunnery");
    assert_eq!(sde.skill_name(3327), "Spaceship Command");
}

#[test]
fn wallet_aggregation_and_balance_chain() {
    let bundle = load_demo_bundle().expect("bundle");
    let aria = bundle.character_data(ARIA).expect("aria data");

    let summary = summarize_wallet(&aria.journal);
    assert!(approx(summary.income, 26_650_000.0));
    assert!(approx(summary.expense, -2_150_000.0));
    assert!(approx(summary.net, 24_500_000.0));
    assert_eq!(summary.entries, 8);

    let by_ref = net_by_ref_type(&aria.journal);
    let bounty = by_ref
        .iter()
        .find(|(r, _)| r == "bounty_prizes")
        .expect("bounty group");
    assert!(approx(bounty.1, 10_600_000.0));
    let grouped_net: f64 = by_ref.iter().map(|(_, v)| v).sum();
    assert!(approx(grouped_net, summary.net));

    // Windows at the fixed instant: 7 days keeps 11-08..11-15 entries,
    // 30 days also keeps 10-20, neither keeps the 10-01 donation.
    assert_eq!(journal_since(&aria.journal, now(), 7).len(), 6);
    assert_eq!(journal_since(&aria.journal, now(), 30).len(), 7);

    // Balance chain: oldest to newest, balance == previous + amount, and
    // the newest balance equals the stored wallet balance.
    let mut ascending = aria.journal.clone();
    ascending.sort_by(|a, b| a.date.cmp(&b.date));
    for pair in ascending.windows(2) {
        assert!(
            approx(pair[1].balance, pair[0].balance + pair[1].amount),
            "chain broken at journal id {}",
            pair[1].id
        );
    }
    assert!(approx(
        ascending.last().expect("newest").balance,
        aria.balance
    ));
}

#[test]
fn name_resolution_covers_every_demo_id_and_falls_back_safely() {
    let bundle = load_demo_bundle().expect("bundle");
    let resolver = demo_resolver().expect("demo resolver");
    let sde = Sde::load_bundled().expect("SDE loads");

    // Every id a view would render resolves to a real name.
    for character in &bundle.characters {
        let per = bundle
            .character_data(character.character_id)
            .expect("per-character data");
        assert_eq!(resolver.name(character.character_id), character.name);
        assert_ne!(resolver.name(character.corporation_id), UNKNOWN_ITEM);
        for item in &per.queue {
            let shown = sde.skill_name(item.skill_id);
            assert!(
                !shown.starts_with("Skill #"),
                "queue skill unresolved: {shown}"
            );
        }
        for entry in &per.journal {
            for party in [entry.first_party_id, entry.second_party_id]
                .into_iter()
                .flatten()
            {
                assert_ne!(resolver.name(party), UNKNOWN_ITEM, "party {party}");
            }
        }
        for tx in &per.transactions {
            assert_ne!(
                resolver.name(tx.type_id),
                UNKNOWN_ITEM,
                "type {}",
                tx.type_id
            );
            assert_ne!(resolver.name(tx.client_id), UNKNOWN_ITEM);
            assert_ne!(
                resolver.location_name(tx.location_id),
                UNKNOWN_LOCATION,
                "location {}",
                tx.location_id
            );
        }
        for lp in &per.loyalty {
            assert_ne!(resolver.name(lp.corporation_id), UNKNOWN_ITEM);
        }
    }

    // Fallbacks for unknown ids are words, never the raw number.
    assert_eq!(resolver.name(424242424), UNKNOWN_ITEM);
    assert_eq!(resolver.location_name(424242424), UNKNOWN_LOCATION);
    assert_eq!(sde.skill_name(999999999), "Unknown Skill");

    // No bundled display name is empty or a bare numeric id.
    let names = load_demo_names().expect("demo names load");
    assert!(names.iter().all(|n| !n.name.is_empty()));
    assert!(names.iter().all(|n| n.name.parse::<i64>().is_err()));
}

#[test]
fn demo_seed_populates_state_and_switching_characters_works() {
    let mut state = AppState::new(true);
    seed_demo_state(&mut state);
    assert!(state.demo);
    assert_eq!(state.characters.len(), 2);
    assert_eq!(
        state.active_character().map(|c| c.name.as_str()),
        Some("Aria Voss")
    );
    assert!(matches!(state.skills, LoadState::Ready(_)));
    assert!(matches!(state.wallet, LoadState::Ready(_)));
    assert!(matches!(state.dashboard, LoadState::Ready(_)));

    // Overview summaries carry resolved skill names, not skill ids.
    assert_eq!(state.summaries.len(), 2);
    for summary in state.summaries.values() {
        let name = summary
            .training_skill_name
            .as_deref()
            .expect("training skill name present");
        assert!(!name.is_empty());
        assert!(name.parse::<i64>().is_err(), "raw id shown: {name}");
        assert!(summary.balance.unwrap_or(0.0) > 0.0);
        assert!(summary.queue_len.unwrap_or(0) > 0);
    }

    // Switching to the second character swaps the per-view data.
    let bundle = load_demo_bundle().expect("bundle");
    state.set_active_character(MARCUS);
    apply_character(&mut state, &bundle, MARCUS);
    let wallet = state.wallet.as_ready().expect("wallet ready");
    assert!(approx(wallet.balance, 48_200_000.0));
    let skills = state.skills.as_ready().expect("skills ready");
    assert_eq!(skills.queue[0].skill_id, 3327);
    let detail = state.character_detail.as_ready().expect("detail ready");
    assert_eq!(detail.name, "Marcus Hale");
}
