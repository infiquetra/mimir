//! Live mining domain: session ledger, ESI ledger merge, ore-hold
//! countdowns, and Survey Scanner valuation. Pure computation only.

pub mod ledger;
pub mod survey_scanner;

#[cfg(test)]
mod stepup_scope_guard {
    use crate::config::EveConfig;

    #[test]
    fn mining_scope_is_stepup_only_and_disjoint_from_first_auth() {
        assert_eq!(
            EveConfig::MINING_SCOPES,
            ["esi-industry.read_character_mining.v1"]
        );
        for scope in EveConfig::MINING_SCOPES {
            assert!(
                !EveConfig::FIRST_AUTH_SCOPES.contains(scope),
                "mining step-up scope {scope} must be disjoint from first-auth"
            );
        }
        assert!(!EveConfig::first_auth_scopes_string().contains("read_character_mining"));
    }

    #[test]
    fn first_auth_scopes_exact_contents_pinned() {
        // Byte-identical first-auth set (#648 AC): any addition,
        // removal, or reorder fails here before it ships.
        assert_eq!(
            EveConfig::FIRST_AUTH_SCOPES,
            [
                "publicData",
                "esi-skills.read_skills.v1",
                "esi-skills.read_skillqueue.v1",
                "esi-wallet.read_character_wallet.v1",
                "esi-clones.read_implants.v1",
            ]
            .as_slice()
        );
    }
}
