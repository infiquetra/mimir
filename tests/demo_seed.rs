//! Demo mode end to end without network or display: bundle loading,
//! skill-queue finish math at a fixed instant, wallet aggregation,
//! journal balance-chain consistency, name-resolution fallbacks, and
//! `AppState` seeding. Every display string must be a resolved EVE name,
//! never a raw numeric ID (SDE misses show "Unknown Skill").

use mimir::app::state::BlueprintKindFilter;
use mimir::app::state::{AppState, LoadState};
use mimir::demo::data::{
    apply_character, currently_training, demo_resolver, is_demo_requested, journal_since,
    load_demo_bundle, load_demo_names, net_by_ref_type, parse_esi_datetime, queue_end,
    seconds_until_finish, seed_demo_state, summarize_wallet, training_progress,
};
use mimir::names::resolver::{UNKNOWN_ITEM, UNKNOWN_LOCATION};
use mimir::names::sde::Sde;
use mimir::ui::assets::group_assets;
use mimir::ui::characters::{
    attribute_rows, clone_display_name, implant_names, standing_counts, standing_groups,
};
use mimir::ui::industry::{
    blueprint_counts, blueprint_rows, filter_blueprint_rows, industry_job_rows, job_counts,
};
use mimir::ui::market::{character_order_rows, region_label, summarize_history, summarize_orders};
use mimir::ui::planets::{
    colony_rows, extractor_product_rows, pin_type_counts, planet_type_label, storage_content_rows,
};

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
        assert!(!per.assets.is_empty(), "assets for {}", character.name);
        for asset in &per.assets {
            assert_ne!(
                resolver.name(asset.type_id),
                UNKNOWN_ITEM,
                "asset type {}",
                asset.type_id
            );
            assert_ne!(
                resolver.location_name(asset.location_id),
                UNKNOWN_LOCATION,
                "asset location {}",
                asset.location_id
            );
        }
        // Every character-detail ID of design section 8 resolves too.
        let detail = per.detail.as_ref().expect("demo detail present");
        for implant_id in detail.implants.as_ref().expect("implants ok") {
            assert_ne!(resolver.name(*implant_id), UNKNOWN_ITEM);
        }
        let clones = detail.clones.as_ref().expect("clones ok");
        for clone in &clones.jump_clones {
            assert_ne!(resolver.location_name(clone.location_id), UNKNOWN_LOCATION);
            for implant_id in &clone.implants {
                assert_ne!(resolver.name(*implant_id), UNKNOWN_ITEM);
            }
        }
        if let Some(home) = &clones.home_location {
            assert_ne!(resolver.location_name(home.location_id), UNKNOWN_LOCATION);
        }
        for standing in detail.standings.as_ref().expect("standings ok") {
            assert_ne!(resolver.name(standing.from_id), UNKNOWN_ITEM);
        }
        let location = detail.location.as_ref().expect("location ok");
        assert_ne!(
            resolver.location_name(location.solar_system_id),
            UNKNOWN_LOCATION
        );
        if let Some(docked_id) = location.docked_location_id() {
            assert_ne!(resolver.location_name(docked_id), UNKNOWN_LOCATION);
        }
        assert_ne!(
            resolver.name(detail.ship.as_ref().expect("ship ok").ship_type_id),
            UNKNOWN_ITEM
        );
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

    // Character details seed Ready and both summaries carry resolved
    // location/ship names (never raw IDs).
    assert!(matches!(state.character_details, LoadState::Ready(_)));
    let aria_summary = state.summaries.get(&ARIA).expect("aria summary");
    assert_eq!(
        aria_summary.location_name.as_deref(),
        Some("Jita IV - Moon 4 - Caldari Navy Assembly Plant")
    );
    assert_eq!(
        aria_summary.ship_name.as_deref(),
        Some("Aria's Rifter (Rifter)")
    );
    let marcus_summary = state.summaries.get(&MARCUS).expect("marcus summary");
    assert_eq!(
        marcus_summary.location_name.as_deref(),
        Some("Amarr VIII (Oris) - Emperor Family Academy")
    );
    assert_eq!(
        marcus_summary.ship_name.as_deref(),
        Some("Marcus's Rifter (Rifter)")
    );

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
    let marcus_details = state
        .character_details
        .as_ready()
        .expect("marcus character details ready");
    assert_eq!(
        marcus_details
            .attributes
            .as_ref()
            .expect("attributes ok")
            .intelligence,
        20
    );
    assert!(!marcus_details.online.as_ref().expect("online ok").online);
}

#[test]
fn demo_assets_render_with_resolved_names_for_both_characters() {
    let bundle = load_demo_bundle().expect("bundle");
    let resolver = demo_resolver().expect("demo resolver");
    let mut state = AppState::new(true);
    seed_demo_state(&mut state);

    // Aria is active after seeding: assets Ready, grouped, named.
    let aria_assets = state.assets.as_ready().expect("aria assets ready");
    assert_eq!(aria_assets.items.len(), 5);
    let aria_groups = group_assets(aria_assets, &resolver);
    assert_eq!(aria_groups.len(), 2, "aria assets span two stations");
    assert!(aria_groups
        .iter()
        .flat_map(|g| &g.rows)
        .any(|r| r.display_name == "Aria's Rifter" && r.type_name == "Rifter"));
    assert!(aria_groups
        .iter()
        .flat_map(|g| &g.rows)
        .any(|r| r.display_name == "Bantam Blueprint (copy)"));

    // Switching swaps in Marcus's assets, not Aria's.
    state.set_active_character(MARCUS);
    apply_character(&mut state, &bundle, MARCUS);
    let marcus_assets = state.assets.as_ready().expect("marcus assets ready");
    assert_eq!(marcus_assets.items.len(), 5);
    assert!(marcus_assets.items.iter().all(|a| a.item_id >= 710000101));
    let marcus_groups = group_assets(marcus_assets, &resolver);
    assert_eq!(marcus_groups.len(), 2);
    assert!(marcus_groups
        .iter()
        .flat_map(|g| &g.rows)
        .any(|r| r.display_name == "Marcus's Rifter"));

    // No group or row name is Unknown or a raw numeric ID for either.
    for groups in [&aria_groups, &marcus_groups] {
        for group in groups.iter() {
            assert_ne!(group.location_name, UNKNOWN_LOCATION);
            assert!(group.location_name.parse::<i64>().is_err());
            for row in &group.rows {
                assert_ne!(row.type_name, UNKNOWN_ITEM);
                assert!(row.display_name.parse::<i64>().is_err());
                assert!(row.type_name.parse::<i64>().is_err());
            }
        }
    }
    assert!(!state.assets_needs_reauthorize);
}

#[test]
fn demo_character_details_render_resolved_for_both() {
    let bundle = load_demo_bundle().expect("bundle");
    let resolver = demo_resolver().expect("demo resolver");
    let mut state = AppState::new(true);
    seed_demo_state(&mut state);

    // Aria after seeding: every section renders through the pure helpers
    // with resolved names, none of them a raw numeric ID.
    let aria = state
        .character_details
        .as_ready()
        .expect("aria character details ready")
        .clone();
    let aria_rows = attribute_rows(aria.attributes.as_ref().expect("attributes ok"));
    assert_eq!(aria_rows.len(), 5);
    assert!(aria_rows.contains(&("Intelligence", 27)));
    let aria_implants = implant_names(aria.implants.as_ref().expect("implants ok"), &resolver);
    assert_eq!(
        aria_implants,
        vec!["Demo Memory Implant", "Demo Perception Implant"]
    );
    let aria_clones = aria.clones.as_ref().expect("clones ok");
    assert_eq!(aria_clones.jump_clones.len(), 2);
    assert_eq!(
        clone_display_name(&aria_clones.jump_clones[0]),
        "Amarr spare"
    );
    assert_eq!(
        clone_display_name(&aria_clones.jump_clones[1]),
        "Jump clone"
    );
    let aria_standings = aria.standings.as_ref().expect("standings ok");
    assert_eq!(standing_counts(aria_standings), (1, 0, 1));
    let aria_groups = standing_groups(aria_standings, &resolver);
    assert_eq!(aria_groups.len(), 2);
    assert!(aria_groups
        .iter()
        .flat_map(|g| &g.rows)
        .any(|r| r.name == "Caldari State" && r.standing_text == "+3.25"));
    assert!(aria_groups
        .iter()
        .flat_map(|g| &g.rows)
        .any(|r| r.name == "CONCORD" && r.standing_text == "-1.50"));

    // Switching swaps in Marcus's entirely different bundle.
    state.set_active_character(MARCUS);
    apply_character(&mut state, &bundle, MARCUS);
    let marcus = state
        .character_details
        .as_ready()
        .expect("marcus character details ready")
        .clone();
    let marcus_rows = attribute_rows(marcus.attributes.as_ref().expect("attributes ok"));
    assert!(marcus_rows.contains(&("Intelligence", 20)));
    assert!(implant_names(marcus.implants.as_ref().expect("implants ok"), &resolver).is_empty());
    let marcus_clones = marcus.clones.as_ref().expect("clones ok");
    assert_eq!(marcus_clones.jump_clones.len(), 1);
    assert_eq!(
        clone_display_name(&marcus_clones.jump_clones[0]),
        "Jump clone"
    );
    let marcus_standings = marcus.standings.as_ref().expect("standings ok");
    assert_eq!(standing_counts(marcus_standings), (1, 1, 1));
    let marcus_groups = standing_groups(marcus_standings, &resolver);
    assert!(marcus_groups
        .iter()
        .any(|g| g.heading == "Other" && g.rows.iter().any(|r| r.name == "Demo Alliance")));
    for groups in [&aria_groups, &marcus_groups] {
        for row in groups.iter().flat_map(|g| &g.rows) {
            assert_ne!(row.name, UNKNOWN_ITEM);
            assert!(row.name.parse::<i64>().is_err(), "raw id: {}", row.name);
        }
    }
}

#[test]
fn demo_market_renders_resolved_for_both_characters() {
    let bundle = load_demo_bundle().expect("bundle");
    let resolver = demo_resolver().expect("demo resolver");

    // Both bundled characters carry a market fixture whose every
    // referenced type, location, and region resolves to words.
    for character in &bundle.characters {
        let per = bundle
            .character_data(character.character_id)
            .expect("per-character data");
        let market = per.market.as_ref().expect("demo market present");
        assert_ne!(resolver.name(market.selected_type_id), UNKNOWN_ITEM);
        let region = region_label(market.region_id, &resolver);
        assert_ne!(region, UNKNOWN_LOCATION);
        assert!(region.parse::<i64>().is_err(), "raw region id: {region}");
        for order in &market.public_orders {
            assert_eq!(order.type_id, market.selected_type_id);
            assert_ne!(
                resolver.location_name(order.location_id),
                UNKNOWN_LOCATION,
                "public location {}",
                order.location_id
            );
        }
        for order in &market.character_orders {
            assert_ne!(resolver.name(order.type_id), UNKNOWN_ITEM);
            assert_ne!(resolver.location_name(order.location_id), UNKNOWN_LOCATION);
        }
        let summary = summarize_orders(&market.public_orders);
        assert!(summary.best_sell.is_some() && summary.best_buy.is_some());
        let history = summarize_history(&market.history);
        assert!(history.days_returned >= 5);
        let rows = character_order_rows(&market.character_orders, market.selected_type_id);
        assert!(
            rows.iter().any(|r| r.matches_selected_type),
            "one own order matches the selected type"
        );
    }

    // Seeding installs Aria's Tritanium book in The Forge; the equal
    // 5.75 sell prices tie-break to the larger remaining volume first.
    let mut state = AppState::new(true);
    seed_demo_state(&mut state);
    let aria = state.market.as_ready().expect("aria market ready");
    assert_eq!(aria.selection.type_name, "Tritanium");
    assert_eq!(aria.selection.character_id, Some(ARIA));
    assert_eq!(state.market_selected_type_id, Some(34));
    assert_eq!(region_label(state.market_region_id, &resolver), "The Forge");
    let aria_public = aria.public_orders.as_ref().expect("public orders ok");
    let aria_summary = summarize_orders(&aria_public.orders);
    assert_eq!(aria_summary.best_sell, Some(5.75));
    assert_eq!(aria_summary.top_sells[0].volume_remain, 120_000);
    let aria_own = aria
        .character_orders
        .as_ref()
        .expect("character orders ok")
        .clone();
    let aria_rows = character_order_rows(&aria_own.orders, aria.selection.type_id);
    let partial = aria_rows
        .iter()
        .find(|r| r.matches_selected_type)
        .expect("partially filled own order");
    assert_eq!(partial.filled, 25_000);
    assert_eq!(partial.volume_total, 50_000);

    // Switching swaps in Marcus's Pyerite book in Domain.
    state.set_active_character(MARCUS);
    apply_character(&mut state, &bundle, MARCUS);
    let marcus = state.market.as_ready().expect("marcus market ready");
    assert_eq!(marcus.selection.type_name, "Pyerite");
    assert_eq!(marcus.selection.character_id, Some(MARCUS));
    assert_eq!(state.market_selected_type_id, Some(35));
    assert_eq!(region_label(state.market_region_id, &resolver), "Domain");
    assert_eq!(
        summarize_orders(
            &marcus
                .public_orders
                .as_ref()
                .expect("public orders ok")
                .orders
        )
        .best_sell,
        Some(8.2)
    );
}

#[test]
fn demo_industry_renders_resolved_for_both_characters() {
    let bundle = load_demo_bundle().expect("bundle");
    let resolver = demo_resolver().expect("demo resolver");

    // Both bundled characters carry an industry fixture whose every
    // rendered type, facility, and location resolves to words.
    for character in &bundle.characters {
        let per = bundle
            .character_data(character.character_id)
            .expect("per-character data");
        let industry = per.industry.as_ref().expect("demo industry present");
        for job in &industry.jobs {
            let display = job
                .product_type_id
                .filter(|id| *id > 0)
                .unwrap_or(job.blueprint_type_id);
            assert_ne!(resolver.name(display), UNKNOWN_ITEM, "job type {display}");
            assert_ne!(resolver.name(job.blueprint_type_id), UNKNOWN_ITEM);
            assert_ne!(
                resolver.location_name(job.facility_id),
                UNKNOWN_LOCATION,
                "facility {}",
                job.facility_id
            );
        }
        for bp in &industry.blueprints {
            assert_ne!(
                resolver.name(bp.type_id),
                UNKNOWN_ITEM,
                "bp type {}",
                bp.type_id
            );
            assert_ne!(
                resolver.location_name(bp.location_id),
                UNKNOWN_LOCATION,
                "bp location {}",
                bp.location_id
            );
        }
    }

    let mut state = AppState::new(true);
    seed_demo_state(&mut state);

    // Aria after seeding: section-7 builders yield resolved rows,
    // sentinel words, and no instance ID as text.
    let check = |state: &AppState,
                 expected_jobs: usize,
                 expected_blueprints: usize,
                 instance_ids: &[i64]| {
        let industry = state.industry.as_ready().expect("industry ready");
        let jobs = industry.jobs.as_ref().expect("jobs ok");
        let blueprints = industry.blueprints.as_ref().expect("blueprints ok");
        assert_eq!(jobs.jobs.len(), expected_jobs);
        assert_eq!(blueprints.blueprints.len(), expected_blueprints);
        assert!(!jobs.truncated && !blueprints.truncated);
        let job_rows = industry_job_rows(&jobs.jobs, &resolver);
        assert_eq!(job_rows.len(), expected_jobs);
        assert!(job_counts(&job_rows).in_progress > 0);
        for row in &job_rows {
            assert_ne!(row.type_name, UNKNOWN_ITEM);
            assert_ne!(row.facility_name, UNKNOWN_LOCATION);
            for text in [
                row.type_name.as_str(),
                row.facility_name.as_str(),
                row.activity_label,
                row.status_label,
            ] {
                assert!(text.parse::<i64>().is_err(), "raw id: {text}");
                for id in instance_ids {
                    assert_ne!(text, id.to_string(), "instance id leaked");
                }
            }
        }
        let bp_rows = blueprint_rows(&blueprints.blueprints, &resolver);
        let counts = blueprint_counts(&bp_rows);
        assert_eq!(counts.total, expected_blueprints);
        assert_eq!(counts.originals + counts.copies, counts.total);
        assert!(counts.originals > 0 && counts.copies > 0);
        for row in &bp_rows {
            assert_ne!(row.type_name, UNKNOWN_ITEM);
            assert_ne!(row.location_name, UNKNOWN_LOCATION);
            for text in [
                row.type_name.as_str(),
                row.location_name.as_str(),
                row.kind_label,
                row.quantity_label.as_str(),
                row.runs_label.as_str(),
            ] {
                assert!(
                    text.parse::<i64>().is_err() || text == "3" || text == "5",
                    "raw id: {text}"
                );
                assert_ne!(text, "-1");
                assert_ne!(text, "-2");
                for id in instance_ids {
                    assert_ne!(text, id.to_string(), "instance id leaked");
                }
            }
        }
        // Search finds by name, never by numeric ID text.
        assert!(
            !filter_blueprint_rows(&bp_rows, "bantam", BlueprintKindFilter::All).is_empty()
                || !filter_blueprint_rows(&bp_rows, "blueprint", BlueprintKindFilter::All)
                    .is_empty()
        );
        assert!(filter_blueprint_rows(&bp_rows, "681", BlueprintKindFilter::All).is_empty());
        (job_rows, bp_rows)
    };

    let aria_instances = [
        710000101, 710000102, 710000103, 710000104, 710001001, 710001002, 710001003, 710001004,
    ];
    let (aria_jobs, aria_bps) = check(&state, 4, 4, &aria_instances);
    assert!(aria_jobs
        .iter()
        .any(|r| r.type_name == "Rifter" && r.activity_label == "Manufacturing"));
    assert!(aria_bps
        .iter()
        .any(|r| r.quantity_label == "Original" && r.runs_label == "Infinite runs (original)"));
    assert!(aria_bps
        .iter()
        .any(|r| r.quantity_label == "Copy" && r.runs_label == "5 runs"));

    // Switching swaps in Marcus's different bundle, reaction included.
    state.set_active_character(MARCUS);
    apply_character(&mut state, &bundle, MARCUS);
    let marcus_instances = [
        710000201, 710000202, 710000203, 710002001, 710002002, 710002003,
    ];
    let (marcus_jobs, _) = check(&state, 3, 3, &marcus_instances);
    assert!(marcus_jobs
        .iter()
        .any(|r| r.type_name == "Ferrogel" && r.activity_label == "Reaction"));
    assert!(marcus_jobs
        .iter()
        .all(|r| !aria_instances.contains(&r.job_id)));
}

#[test]
fn demo_planets_render_resolved_for_both_characters() {
    let bundle = load_demo_bundle().expect("bundle");
    let resolver = demo_resolver().expect("demo resolver");

    // Both bundled characters carry a planets fixture whose every
    // rendered system, pin type, product, and content type resolves
    // to words.
    for character in &bundle.characters {
        let per = bundle
            .character_data(character.character_id)
            .expect("per-character data");
        let planets = per.planets.as_ref().expect("demo planets present");
        for colony in &planets.colonies {
            assert_ne!(
                resolver.location_name(colony.solar_system_id),
                UNKNOWN_LOCATION,
                "system {}",
                colony.solar_system_id
            );
            let label = planet_type_label(&colony.planet_type);
            assert_ne!(label, "Unknown planet type", "type {}", colony.planet_type);
            assert!(label.parse::<i64>().is_err());
        }
        for detail in planets.details.values() {
            for pin in &detail.pins {
                assert_ne!(
                    resolver.name(pin.type_id),
                    UNKNOWN_ITEM,
                    "pin type {}",
                    pin.type_id
                );
                if let Some(details) = &pin.extractor_details {
                    if let Some(product) = details.product_type_id {
                        assert_ne!(resolver.name(product), UNKNOWN_ITEM, "product {product}");
                    }
                }
                for entry in &pin.contents {
                    assert_ne!(
                        resolver.name(entry.type_id),
                        UNKNOWN_ITEM,
                        "content {}",
                        entry.type_id
                    );
                }
            }
        }
    }

    let mut state = AppState::new(true);
    seed_demo_state(&mut state);

    // Aria after seeding: Ready bundle, selection, and matching
    // detail; every aggregated number clamps and resolves.
    let aria = state.planetary.as_ready().expect("aria planetary ready");
    let aria_colonies = aria.colonies.as_ref().expect("colonies ok").clone();
    assert_eq!(aria_colonies.len(), 2);
    assert_eq!(state.planetary_selected_planet_id, Some(700000001));
    let aria_rows = colony_rows(&aria_colonies, &resolver);
    assert_eq!(aria_rows.len(), 2);
    for row in &aria_rows {
        assert_ne!(row.system_name, UNKNOWN_LOCATION);
        assert!(row.system_name.parse::<i64>().is_err());
        assert_ne!(row.planet_type_label, "Unknown planet type");
    }
    assert!(aria_rows.iter().any(|r| r.system_name == "Jita"));
    assert!(aria_rows.iter().any(|r| r.system_name == "Amarr"));
    let aria_detail = aria.detail.as_ref().expect("aria detail").clone();
    assert_eq!(aria_detail.selection.character_id, ARIA);
    assert_eq!(aria_detail.selection.planet_id, 700000001);
    let pins = aria_detail.result.as_ref().expect("detail ok").pins.clone();
    let counts = pin_type_counts(&pins, &resolver);
    assert_eq!(counts.len(), 2);
    assert!(counts
        .iter()
        .any(|r| r.type_name == "Demo Extractor" && r.count >= 2));
    assert!(counts.iter().any(|r| r.type_name == "Demo Factory"));
    let extractors = extractor_product_rows(&pins, &resolver);
    assert!(extractors
        .iter()
        .any(|r| r.product_name == "Tritanium" && r.qty_per_cycle == Some(120)));
    assert!(extractors
        .iter()
        .any(|r| r.product_name == "Mexallon" && r.qty_per_cycle.is_none()));
    // Pyerite is stored on two pins and aggregates; the clamping
    // entry contributes zero, never a negative total.
    let storage = storage_content_rows(&pins, &resolver);
    let pyerite = storage
        .iter()
        .find(|r| r.type_name == "Pyerite")
        .expect("pyerite");
    assert_eq!(pyerite.amount, 800);
    for row in &storage {
        assert_ne!(row.type_name, UNKNOWN_ITEM);
    }

    // Switching swaps in Marcus's colony; his detail has pins but
    // empty contents, so Stored items reports empty in demo.
    state.set_active_character(MARCUS);
    apply_character(&mut state, &bundle, MARCUS);
    let marcus = state.planetary.as_ready().expect("marcus planetary ready");
    let marcus_colonies = marcus.colonies.as_ref().expect("colonies ok").clone();
    assert_eq!(marcus_colonies.len(), 1);
    assert_eq!(state.planetary_selected_planet_id, Some(700000101));
    let marcus_detail = marcus.detail.as_ref().expect("marcus detail").clone();
    assert_eq!(marcus_detail.selection.character_id, MARCUS);
    assert_eq!(marcus_detail.selection.planet_id, 700000101);
    let marcus_pins = marcus_detail
        .result
        .as_ref()
        .expect("detail ok")
        .pins
        .clone();
    assert!(!marcus_pins.is_empty());
    assert!(storage_content_rows(&marcus_pins, &resolver).is_empty());
    assert!(marcus_pins.iter().all(|p| p.contents.is_empty()));
}
