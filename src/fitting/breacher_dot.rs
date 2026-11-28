//! Pure SCARAB Breacher Pod damage-over-time math
//! (Revenant expansion, Deathless Cenotaph/Tholos).
//!
//! A breacher pod stream deals raw hit points per second
//! equal to `min(flat_dps, pct_max_hp * target_total_hp)`:
//! the percent term scales with the target's total
//! (shield + armor + hull) hit points until the flat cap
//! binds. The damage bypasses shield/armor/hull
//! resistances entirely — the pod description in the SDE
//! ("bypassing traditional damage resistances") and the
//! expansion audit in `mimir-context-library`
//! (`platform-specs/10-research-validation/
//! eve-ecosystem-and-expansion-audit-2026.md`) agree — so
//! resistances are accepted in the target profile only to
//! prove they change nothing. Streams from multiple
//! attackers do not stack: the single largest stream wins
//! (`max`, never a sum).
//!
//! Pod constants come from the bundled SDE rows: SCARAB
//! Breacher Pod S (85088) carries attribute 5736 = 200.0
//! (flat DPS cap) and 5737 = 0.6 (percent of target max HP
//! per second); Pod M (85089) carries 5736 = 600.0 and
//! 5737 = 0.6 (`assets/sde/dogma.json` type rows; the older
//! `scripts/sde/dgmTypeAttributes.csv.bz2` cache reads
//! 160/800 and 0.8 on the M pod — the bundled asset wins
//! and the divergence is disclosed here rather than
//! averaged). The `fitting_types.json` extract does not
//! carry 5736/5737, so pods arrive as explicit
//! [`BreacherPod`] inputs like every other unbaked SDE
//! operand in this crate.
//!
//! Pure computation only — no egui, no state, no network,
//! no database. Logs nothing (render cadence precedent).

use crate::fitting::ship_resistances::ResistLayer;

/// One SCARAB Breacher Pod charge's DoT inputs.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BreacherPod {
    /// Flat DPS cap in raw HP/s (SDE attribute 5736).
    pub flat_dps: f64,
    /// Percent of target total HP per second, as a plain
    /// percent (SDE attribute 5737: 0.6 means 0.6%/s).
    pub pct_max_hp_per_sec: f64,
}

/// SCARAB Breacher Pod S (type 85088): 200 flat, 0.6%/s.
pub const SCARAB_POD_S: BreacherPod = BreacherPod {
    flat_dps: 200.0,
    pct_max_hp_per_sec: 0.6,
};

/// SCARAB Breacher Pod M (type 85089): 600 flat, 0.6%/s.
pub const SCARAB_POD_M: BreacherPod = BreacherPod {
    flat_dps: 600.0,
    pct_max_hp_per_sec: 0.6,
};

/// A breacher target: total raw hit points and, for
/// provenance, the resistances the pod ignores. The resist
/// layers are never read by the math; they exist so a
/// caller can prove the bypass beside a conventional EHP
/// number.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BreacherTarget {
    /// Shield + armor + hull hit points.
    pub total_hp: f64,
    /// Ignored by design (resistance bypass).
    pub resistances_ignored: Option<ResistLayer>,
}

fn usable(value: f64) -> Option<f64> {
    (value.is_finite() && value >= 0.0).then_some(value)
}

/// Effective raw HP/s of one pod stream against a target
/// with `target_total_hp` total hit points:
/// `min(flat_dps, pct_max_hp_per_sec / 100 * total_hp)`.
/// `None` on unusable input — never a silent zero.
pub fn breacher_dps(pod: &BreacherPod, target_total_hp: f64) -> Option<f64> {
    let flat = usable(pod.flat_dps)?;
    let pct = usable(pod.pct_max_hp_per_sec)?;
    let hp = usable(target_total_hp)?;
    let dps = flat.min(pct / 100.0 * hp);
    dps.is_finite().then_some(dps)
}

/// Effective raw HP/s against a full target profile.
/// Resistances change nothing: the result is exactly
/// [`breacher_dps`] over the target's total HP.
pub fn breacher_dps_against(pod: &BreacherPod, target: &BreacherTarget) -> Option<f64> {
    breacher_dps(pod, target.total_hp)
}

/// Combined raw HP/s when several pod streams hit one
/// target: streams never stack, so the maximum single
/// stream wins. An empty stream list is a known `Some(0.0)`.
/// `None` only when the target HP itself is unusable;
/// an unusable pod contributes no stream (it cannot raise
/// the maximum) — callers needing per-pod disclosure call
/// [`breacher_dps`] per pod.
pub fn breacher_dps_multi(pods: &[BreacherPod], target_total_hp: f64) -> Option<f64> {
    usable(target_total_hp)?;
    let mut best = 0.0_f64;
    for pod in pods {
        if let Some(dps) = breacher_dps(pod, target_total_hp) {
            best = best.max(dps);
        }
    }
    Some(best)
}

/// Seconds for one pod stream to chew through a target's
/// full raw HP from full, ignoring repair and resistances.
/// `None` when the stream deals no damage (division by a
/// zero rate is never a duration).
pub fn breacher_time_to_kill_secs(pod: &BreacherPod, target_total_hp: f64) -> Option<f64> {
    let dps = breacher_dps(pod, target_total_hp).filter(|d| *d > 0.0)?;
    let hp = usable(target_total_hp)?;
    let secs = hp / dps;
    secs.is_finite().then_some(secs)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_close(actual: f64, expected: f64, label: &str) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "{label}: expected {expected}, got {actual}"
        );
    }

    // Hull total HP from the bundled catalogue (shield +
    // armor + hull): Rifter 450+450+350 = 1250; Raven
    // 7700+6380+7040 = 21120; Thanatos 55500+69500+83500
    // = 208500.

    #[test]
    fn percent_term_binds_on_a_frigate() {
        // Pod S vs Rifter: min(200, 0.006 * 1250) = 7.5.
        let dps = breacher_dps(&SCARAB_POD_S, 1250.0).expect("usable inputs");
        assert_close(dps, 7.5, "Pod S vs frigate");
    }

    #[test]
    fn percent_term_scales_on_a_battleship() {
        // Pod M vs Raven: min(600, 0.006 * 21120) = 126.72.
        let dps = breacher_dps(&SCARAB_POD_M, 21120.0).expect("usable inputs");
        assert_close(dps, 126.72, "Pod M vs battleship");
    }

    #[test]
    fn flat_cap_binds_on_a_capital() {
        // Pod M vs Thanatos: 0.006 * 208500 = 1251 > 600,
        // so the flat cap wins.
        let dps = breacher_dps(&SCARAB_POD_M, 208500.0).expect("usable inputs");
        assert_close(dps, 600.0, "Pod M vs capital");
    }

    #[test]
    fn ninety_percent_resists_change_nothing() {
        let brick = BreacherTarget {
            total_hp: 21120.0,
            resistances_ignored: Some(ResistLayer {
                em: Some(90.0),
                thermal: Some(90.0),
                kinetic: Some(90.0),
                explosive: Some(90.0),
            }),
        };
        let naked = BreacherTarget {
            total_hp: 21120.0,
            resistances_ignored: Some(ResistLayer {
                em: Some(0.0),
                thermal: Some(0.0),
                kinetic: Some(0.0),
                explosive: Some(0.0),
            }),
        };
        let brick_dps = breacher_dps_against(&SCARAB_POD_M, &brick).expect("usable inputs");
        let naked_dps = breacher_dps_against(&SCARAB_POD_M, &naked).expect("usable inputs");
        assert_close(brick_dps, 126.72, "90% resist target");
        assert_close(naked_dps, brick_dps, "resistances ignored");
    }

    #[test]
    fn streams_do_not_stack_max_wins() {
        // Two Pod M attackers plus one Pod S on a Raven:
        // max(126.72, 126.72, 126.72) — the percent term is
        // identical, and the answer is one stream, never
        // 3 x or a sum. On a Thanatos the caps differ:
        // max(600, 600, 200) = 600, never 1400.
        let raven = breacher_dps_multi(&[SCARAB_POD_M, SCARAB_POD_M, SCARAB_POD_S], 21120.0)
            .expect("usable inputs");
        assert_close(raven, 126.72, "multi vs battleship");
        let thanatos = breacher_dps_multi(&[SCARAB_POD_M, SCARAB_POD_M, SCARAB_POD_S], 208500.0)
            .expect("usable inputs");
        assert_close(thanatos, 600.0, "multi vs capital");
    }

    #[test]
    fn empty_streams_are_a_known_zero() {
        assert_eq!(breacher_dps_multi(&[], 21120.0), Some(0.0));
    }

    #[test]
    fn time_to_kill_uses_raw_hp_not_ehp() {
        // Raven under Pod M: 21120 / 126.72 = 166.666... s.
        let secs = breacher_time_to_kill_secs(&SCARAB_POD_M, 21120.0).expect("usable inputs");
        assert_close(secs, 21120.0 / 126.72, "time to kill");
        // A pod with a zero percent and zero flat deals
        // nothing: no duration exists.
        let dud = BreacherPod {
            flat_dps: 0.0,
            pct_max_hp_per_sec: 0.0,
        };
        assert_eq!(breacher_time_to_kill_secs(&dud, 21120.0), None);
    }

    #[test]
    fn unusable_inputs_are_none() {
        assert_eq!(breacher_dps(&SCARAB_POD_S, -1.0), None);
        assert_eq!(
            breacher_dps(
                &BreacherPod {
                    flat_dps: f64::NAN,
                    pct_max_hp_per_sec: 0.6
                },
                1250.0
            ),
            None
        );
        assert_eq!(breacher_dps_multi(&[SCARAB_POD_S], f64::INFINITY), None);
    }
}
