//! Fixture JSON parses into every Phase-1 model it covers.

use mimir::esi::models::*;

#[test]
fn character_fixture_parses() {
    let info: CharacterPublicInfo =
        serde_json::from_str(include_str!("fixtures/character.json")).expect("character parses");
    assert_eq!(info.name, "Fixture Capsuleer");
    assert_eq!(info.corporation_id, 1000166);
}

#[test]
fn skills_fixture_parses() {
    let skills: CharacterSkills =
        serde_json::from_str(include_str!("fixtures/skills.json")).expect("skills parses");
    assert_eq!(skills.total_sp, 1_000_000);
    assert_eq!(skills.skills.len(), 1);
    assert_eq!(skills.skills[0].skill_id, 3300);
}

#[test]
fn skillqueue_fixture_parses() {
    let queue: Vec<SkillQueueItem> =
        serde_json::from_str(include_str!("fixtures/skillqueue.json")).expect("queue parses");
    assert_eq!(queue.len(), 1);
    assert_eq!(queue[0].finished_level, 5);
}

#[test]
fn wallet_journal_fixture_parses() {
    let journal: Vec<WalletJournalItem> =
        serde_json::from_str(include_str!("fixtures/wallet_journal.json")).expect("journal parses");
    assert_eq!(journal.len(), 1);
    assert_eq!(journal[0].ref_type, "bounty_prizes");
}
