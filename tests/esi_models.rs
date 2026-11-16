//! Fixture JSON parses into every Phase-1 ESI model. All fixture data is
//! invented; no network is involved.

use mimir::esi::models::*;

fn parse<T: serde::de::DeserializeOwned>(json: &str) -> T {
    serde_json::from_str(json).expect("fixture parses")
}

#[test]
fn character_fixture_parses() {
    let info: CharacterPublicInfo = parse(include_str!("fixtures/character.json"));
    assert_eq!(info.name, "Fixture Capsuleer");
    assert_eq!(info.corporation_id, 1000166);
    assert_eq!(info.security_status, 2.5);
}

#[test]
fn skills_and_attributes_fixtures_parse() {
    let skills: CharacterSkills = parse(include_str!("fixtures/skills.json"));
    assert_eq!(skills.total_sp, 1_000_000);
    assert_eq!(skills.unallocated_sp, Some(1000));
    assert_eq!(skills.skills.len(), 1);
    assert_eq!(skills.skills[0].skill_id, 3300);
    assert_eq!(skills.skills[0].trained_skill_level, 5);

    let attrs: CharacterAttributes = parse(include_str!("fixtures/attributes.json"));
    assert_eq!(attrs.intelligence, 27);
    assert_eq!(attrs.perception, 25);
}

#[test]
fn skillqueue_fixture_parses_with_dates() {
    let queue: Vec<SkillQueueItem> = parse(include_str!("fixtures/skillqueue.json"));
    assert_eq!(queue.len(), 1);
    assert_eq!(queue[0].finished_level, 5);
    assert_eq!(
        queue[0].finish_date.as_deref(),
        Some("2026-11-20T12:00:00Z")
    );
}

#[test]
fn wallet_fixtures_parse() {
    let journal: Vec<WalletJournalItem> = parse(include_str!("fixtures/wallet_journal.json"));
    assert_eq!(journal.len(), 1);
    assert_eq!(journal[0].ref_type, "bounty_prizes");
    assert_eq!(journal[0].amount, 1000.0);

    let transactions: Vec<WalletTransactionItem> =
        parse(include_str!("fixtures/wallet_transactions.json"));
    assert_eq!(transactions.len(), 1);
    assert!(transactions[0].is_buy);
    assert_eq!(transactions[0].type_id, 34);
    assert_eq!(transactions[0].location_id, 60003760);
    assert_eq!(
        transactions[0].quantity as f64 * transactions[0].unit_price,
        77_500.0
    );

    let loyalty: Vec<LoyaltyPointItem> = parse(include_str!("fixtures/loyalty.json"));
    assert_eq!(loyalty.len(), 2);
    assert_eq!(loyalty[0].loyalty_points, 15250);
}

#[test]
fn location_ship_and_online_fixtures_parse() {
    let root: serde_json::Value = parse(include_str!("fixtures/location_ship_online.json"));
    let location: CharacterLocation =
        serde_json::from_value(root["location"].clone()).expect("location parses");
    assert_eq!(location.solar_system_id, 30000142);
    assert_eq!(location.station_id, Some(60003760));
    assert_eq!(location.structure_id, None);

    let ship: CharacterShip = serde_json::from_value(root["ship"].clone()).expect("ship parses");
    assert_eq!(ship.ship_name, "Fixture Frigate");
    assert_eq!(ship.ship_type_id, 587);

    let online: CharacterOnline =
        serde_json::from_value(root["online"].clone()).expect("online parses");
    assert!(online.online);
    assert_eq!(online.logins, Some(412));
}

#[test]
fn clones_and_standings_fixtures_parse() {
    let root: serde_json::Value = parse(include_str!("fixtures/clones_standings.json"));
    let clones: CharacterClones =
        serde_json::from_value(root["clones"].clone()).expect("clones parse");
    assert_eq!(clones.jump_clones.len(), 1);
    assert_eq!(clones.jump_clones[0].implants, vec![22119, 22120]);
    assert_eq!(clones.jump_clones[0].location_type, "station");

    let standings: Vec<Standing> =
        serde_json::from_value(root["standings"].clone()).expect("standings parse");
    assert_eq!(standings.len(), 2);
    assert_eq!(standings[1].standing, -1.5);
}

#[test]
fn universe_fixtures_parse() {
    let root: serde_json::Value = parse(include_str!("fixtures/universe.json"));
    let names: Vec<UniverseName> =
        serde_json::from_value(root["names"].clone()).expect("names parse");
    assert_eq!(names[0].name, "Tritanium");
    assert_eq!(names[1].category, "character");

    let station: StationInfo =
        serde_json::from_value(root["station"].clone()).expect("station parses");
    assert!(station.name.contains("Jita IV"));
    assert_eq!(station.system_id, 30000142);

    let structure: StructureInfo =
        serde_json::from_value(root["structure"].clone()).expect("structure parses");
    assert_eq!(structure.name, "Fixture Citadel");

    let corp: CorporationInfo =
        serde_json::from_value(root["corporation"].clone()).expect("corp parses");
    assert_eq!(corp.ticker, "DDL");
    assert_eq!(corp.member_count, 17);

    let alliance: AllianceInfo =
        serde_json::from_value(root["alliance"].clone()).expect("alliance parses");
    assert_eq!(alliance.ticker, "FIX");
}

#[test]
fn assets_fixture_parses() {
    let root: serde_json::Value = parse(include_str!("fixtures/assets.json"));
    let assets: Vec<AssetItem> =
        serde_json::from_value(root["assets"].clone()).expect("assets parse");
    assert_eq!(assets.len(), 5);
    assert_eq!(assets[0].quantity, 150_000);
    assert_eq!(assets[0].type_id, 34);
    assert_eq!(assets[0].location_id, 60003760);
    assert!(!assets[0].is_singleton);
    assert!(assets[1].is_singleton);
    assert_eq!(assets[1].is_blueprint_copy, Some(false));
    assert_eq!(assets[2].is_blueprint_copy, Some(true));
    // Omitted fields default rather than failing.
    assert_eq!(assets[3].is_blueprint_copy, None);
    assert_eq!(assets[3].location_flag, "");
    assert_eq!(assets[4].item_id, 0);

    let names: Vec<AssetName> = serde_json::from_value(root["names"].clone()).expect("names parse");
    assert_eq!(names.len(), 2);
    assert_eq!(names[0].item_id, 710000002);
    assert_eq!(names[0].name, "Aria's Rifter");
    assert_eq!(names[1].name, "None");
}

#[test]
fn market_fixture_parses() {
    let root: serde_json::Value = parse(include_str!("fixtures/market.json"));
    let regional: Vec<RegionalOrder> =
        serde_json::from_value(root["regional_orders"].clone()).expect("regional parse");
    assert_eq!(regional.len(), 2);
    assert_eq!(regional[0].type_id, 34);
    assert!(!regional[0].is_buy_order);
    assert!(regional[1].is_buy_order);
    assert_eq!(regional[1].system_id, 30000142);

    let character: Vec<CharacterOrder> =
        serde_json::from_value(root["character_orders"].clone()).expect("character parse");
    assert_eq!(character.len(), 2);
    assert_eq!(character[0].region_id, 10000002);
    assert_eq!(character[0].escrow, None);
    assert_eq!(character[1].escrow, Some(320000.0));

    let history: Vec<MarketHistoryEntry> =
        serde_json::from_value(root["history"].clone()).expect("history parses");
    assert_eq!(history.len(), 2);
    assert_eq!(history[1].date, "2026-11-14");
    assert_eq!(history[1].volume, 3020000);
}

#[test]
fn industry_fixture_parses() {
    let root: serde_json::Value = parse(include_str!("fixtures/industry.json"));
    let jobs: Vec<IndustryJob> =
        serde_json::from_value(root["industry_jobs"].clone()).expect("jobs parse");
    assert_eq!(jobs.len(), 3);
    assert_eq!(jobs[0].job_id, 710000101);
    assert_eq!(jobs[0].activity_id, 1);
    assert_eq!(jobs[0].status, "active");
    assert_eq!(jobs[0].cost, None, "null cost stays None, never 0.0");
    assert_eq!(jobs[0].product_type_id, Some(587));
    assert_eq!(jobs[1].activity_id, 11, "reaction job row");
    assert_eq!(jobs[1].status, "ready");
    assert_eq!(jobs[2].probability, Some(0.4));
    assert_eq!(jobs[2].successful_runs, Some(1));
    assert_eq!(jobs[2].completed_character_id, Some(90000001));

    let blueprints: Vec<CharacterBlueprint> =
        serde_json::from_value(root["blueprints"].clone()).expect("blueprints parse");
    assert_eq!(blueprints.len(), 4);
    assert_eq!(blueprints[0].quantity, -1);
    assert_eq!(blueprints[0].runs, -1);
    assert_eq!(blueprints[0].material_efficiency, 10);
    assert_eq!(blueprints[1].quantity, -2, "copied blueprint sentinel");
    assert_eq!(blueprints[1].runs, 5);
    assert_eq!(blueprints[2].quantity, 3);
    // Empty-object row defaults rather than failing.
    assert_eq!(blueprints[3].item_id, 0);
    assert_eq!(blueprints[3].type_id, 0);
    assert_eq!(blueprints[3].runs, 0);
}

#[test]
fn planets_fixture_parses() {
    let root: serde_json::Value = parse(include_str!("fixtures/planets.json"));
    let colonies: Vec<PlanetColony> =
        serde_json::from_value(root["colonies"].clone()).expect("colonies parse");
    assert_eq!(colonies.len(), 2);
    assert_eq!(colonies[0].planet_id, 700000001);
    assert_eq!(colonies[0].planet_type, "temperate");
    assert_eq!(colonies[0].solar_system_id, 30000142);
    assert_eq!(colonies[0].upgrade_level, 2);
    assert_eq!(colonies[0].num_pins, 9);
    assert_eq!(colonies[1].planet_id, 700000002);
    assert_eq!(colonies[1].solar_system_id, 30002187);

    let detail: PlanetColonyDetail =
        serde_json::from_value(root["detail"].clone()).expect("detail parses");
    assert_eq!(detail.pins.len(), 3);
    let pin = &detail.pins[0];
    assert_eq!(pin.pin_id, 700000011);
    assert_eq!(pin.type_id, 20001);
    let extractor = pin.extractor_details.as_ref().expect("extractor");
    assert_eq!(extractor.product_type_id, Some(34));
    assert_eq!(extractor.qty_per_cycle, Some(120));
    assert_eq!(extractor.cycle_time, Some(7200));
    assert_eq!(pin.schematic_id, Some(15462));
    assert_eq!(pin.contents.len(), 2);
    assert_eq!(pin.contents[0].type_id, 35);
    assert_eq!(pin.contents[0].amount, 500);
    // Repeat pin type: two extractors in this colony.
    assert_eq!(detail.pins[1].type_id, 20001);
    let extractor2 = detail.pins[1]
        .extractor_details
        .as_ref()
        .expect("extractor");
    assert_eq!(extractor2.product_type_id, Some(36));
    assert_eq!(extractor2.qty_per_cycle, None, "null qty stays None");
    // Bare pin: no extractor, no contents, optional dates absent.
    let bare = &detail.pins[2];
    assert!(bare.extractor_details.is_none());
    assert!(bare.contents.is_empty());
    assert_eq!(bare.expiry_time, None);
    assert_eq!(bare.last_cycle_start, None);
    assert_eq!(bare.schematic_id, None);
    // Raw link/route rows carry through untyped.
    assert_eq!(detail.links.len(), 1);
    assert_eq!(detail.routes.len(), 1);
    assert!(detail.links[0].is_object());
}

#[test]
fn empty_payloads_default_instead_of_failing() {
    // ESI occasionally omits optional fields; models must tolerate `{}`.
    let info: CharacterPublicInfo = parse("{}");
    assert_eq!(info.name, "");
    let queue_item: SkillQueueItem = parse("{}");
    assert_eq!(queue_item.finish_date, None);
    let journal_item: WalletJournalItem = parse("{}");
    assert_eq!(journal_item.first_party_id, None);
    let asset_item: AssetItem = parse("{}");
    assert_eq!(asset_item.item_id, 0);
    assert_eq!(asset_item.is_blueprint_copy, None);
    let blueprint: CharacterBlueprint = parse("{}");
    assert_eq!(blueprint.item_id, 0);
    assert_eq!(blueprint.runs, 0);
    let job: IndustryJob = parse("{}");
    assert_eq!(job.job_id, 0);
    assert_eq!(job.cost, None);
    assert_eq!(job.product_type_id, None);
    assert_eq!(job.successful_runs, None);
}
