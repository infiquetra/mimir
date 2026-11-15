//! Temp-database schema checks and repository round-trips, ending with a
//! full demo seed read back through the same repositories the live ESI
//! refresh writes through. No network and no display are involved.

use mimir::demo::data::{load_demo_bundle, seed_into_db};
use mimir::storage::db;
use mimir::storage::repositories::*;

fn approx(a: f64, b: f64) -> bool {
    (a - b).abs() < 0.001
}

#[test]
fn schema_migrates_on_empty_db() {
    let conn = db::open_in_memory().expect("in-memory db opens");
    assert_eq!(
        db::schema_version(&conn).expect("version"),
        db::SCHEMA_VERSION
    );
    let tables: i64 = conn
        .query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN \
             ('characters','skill_queue','character_skills','wallet_balances',\
              'wallet_journal','wallet_transactions','loyalty_points',\
              'universe_names','app_settings')",
            [],
            |row| row.get(0),
        )
        .expect("table count readable");
    assert_eq!(tables, 9);
}

#[test]
fn character_and_wallet_repositories_roundtrip() {
    let conn = db::open_in_memory().expect("in-memory db opens");
    let row = CharacterRow {
        character_id: 90000001,
        name: "Aria Voss".to_string(),
        corporation_id: 1000166,
        alliance_id: None,
        is_active: true,
    };
    upsert_character(&conn, &row).expect("upsert");
    let listed = list_characters(&conn).expect("list");
    assert_eq!(listed, vec![row.clone()]);
    assert_eq!(
        active_character(&conn)
            .expect("active")
            .map(|c| c.character_id),
        Some(90000001)
    );

    set_wallet_balance(
        &conn,
        &WalletBalanceRow {
            character_id: 90000001,
            balance: 1234.5,
        },
    )
    .expect("set balance");
    assert_eq!(
        wallet_balance(&conn, 90000001).expect("balance"),
        Some(1234.5)
    );
    assert!(approx(
        combined_wallet_balance(&conn).expect("combined"),
        1234.5
    ));

    let journal = vec![WalletJournalRow {
        id: 1,
        character_id: 90000001,
        amount: 100.0,
        balance: 1234.5,
        date: "2026-11-15T00:00:00Z".to_string(),
        description: "Fixture bounty".to_string(),
        ref_type: "bounty_prizes".to_string(),
        first_party_id: Some(1000125),
        second_party_id: Some(90000001),
    }];
    upsert_journal(&conn, &journal).expect("journal upsert");
    assert_eq!(
        list_journal(&conn, 90000001).expect("journal list"),
        journal
    );
    assert_eq!(
        max_journal_id(&conn, 90000001).expect("max journal id"),
        Some(1)
    );
}

#[test]
fn skill_and_name_repositories_roundtrip() {
    let conn = db::open_in_memory().expect("in-memory db opens");
    let queue = vec![SkillQueueRow {
        character_id: 90000001,
        queue_position: 0,
        skill_id: 3300,
        finished_level: 5,
        start_date: Some("2026-11-10T12:00:00Z".to_string()),
        finish_date: Some("2026-11-20T12:00:00Z".to_string()),
    }];
    replace_skill_queue(&conn, 90000001, &queue).expect("replace queue");
    assert_eq!(
        list_skill_queue(&conn, 90000001).expect("queue list"),
        queue
    );

    let skills = vec![CharacterSkillRow {
        character_id: 90000001,
        skill_id: 3300,
        active_skill_level: 4,
        trained_skill_level: 4,
        skillpoints_in_skill: 45255,
    }];
    replace_character_skills(&conn, 90000001, &skills).expect("replace skills");
    assert_eq!(
        list_character_skills(&conn, 90000001).expect("skills list"),
        skills
    );
    assert_eq!(total_skillpoints(&conn, 90000001).expect("sp"), 45255);

    let names = vec![UniverseNameRow {
        id: 34,
        name: "Tritanium".to_string(),
        category: "inventory_type".to_string(),
    }];
    upsert_universe_names(&conn, &names).expect("names upsert");
    assert_eq!(
        get_universe_name(&conn, 34)
            .expect("name get")
            .map(|n| n.name),
        Some("Tritanium".to_string())
    );
    assert_eq!(get_universe_name(&conn, 999).expect("missing name"), None);

    set_setting(&conn, "demo_test_key", "1").expect("set setting");
    assert_eq!(
        get_setting(&conn, "demo_test_key").expect("get setting"),
        Some("1".to_string())
    );
}

#[test]
fn temp_file_db_opens_and_migrates() {
    let dir = tempfile::tempdir().expect("tempdir");
    let path = dir.path().join("mimir.db");
    let _conn = db::open_db(&path).expect("file db opens");
    assert!(path.exists());
}

#[test]
fn demo_seed_roundtrips_through_repositories() {
    let conn = db::open_in_memory().expect("in-memory db opens");
    seed_into_db(&conn).expect("demo seed");
    let bundle = load_demo_bundle().expect("bundle");

    let stored = list_characters(&conn).expect("characters");
    assert_eq!(stored.len(), 2);
    assert_eq!(stored.iter().filter(|c| c.is_active).count(), 1);

    for character in &bundle.characters {
        let per = bundle
            .character_data(character.character_id)
            .expect("per-character data");
        let queue = list_skill_queue(&conn, character.character_id).expect("queue");
        assert_eq!(queue.len(), per.queue.len());
        assert_eq!(queue[0].skill_id, per.queue[0].skill_id);
        assert_eq!(queue[0].finish_date, per.queue[0].finish_date);

        let balance = wallet_balance(&conn, character.character_id).expect("balance");
        assert_eq!(balance, Some(per.balance));

        let journal = list_journal(&conn, character.character_id).expect("journal");
        assert_eq!(journal.len(), per.journal.len());
        let net: f64 = journal.iter().map(|j| j.amount).sum();
        let expected: f64 = per.journal.iter().map(|j| j.amount).sum();
        assert!(approx(net, expected));

        let transactions = list_transactions(&conn, character.character_id).expect("transactions");
        assert_eq!(transactions.len(), per.transactions.len());

        let loyalty = list_loyalty(&conn, character.character_id).expect("loyalty");
        assert_eq!(loyalty.len(), per.loyalty.len());
    }

    // Demo universe names are persisted for the resolver's DB tier.
    assert_eq!(
        get_universe_name(&conn, 34).expect("name").map(|n| n.name),
        Some("Tritanium".to_string())
    );
    assert!(!list_universe_names(&conn).expect("names").is_empty());

    // Seeding twice converges (upserts/replaces, no duplicate rows).
    seed_into_db(&conn).expect("second seed");
    assert_eq!(list_characters(&conn).expect("characters").len(), 2);
    assert_eq!(
        list_journal(&conn, 90000001).expect("journal").len(),
        bundle.character_data(90000001).expect("data").journal.len()
    );
}
