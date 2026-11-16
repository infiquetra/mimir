//! Pure mapping from a fitting (imported or copied) to the ESI
//! save body. Both save sources funnel through
//! [`build_save_request`]; the confirmation renders the exact
//! strings this mapping produces, so what is confirmed is what
//! is sent. Logs carry counts only — fitting names and
//! descriptions (user text) never enter a log line.

use std::collections::HashSet;

use crate::esi::models::{CharacterFitting, FittingItem, SaveFittingRequest};

/// Why one source item was left out of the save body.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DropReason {
    /// Slot index beyond the ESI flag enum, or a flag string that
    /// is not exactly one enum member (`Invalid` included).
    NoEsiFlag,
    /// Stacked-category item with quantity <= 0, or a
    /// non-positive type id.
    NotSaveable,
    /// Second or later item claiming the same slot flag.
    DuplicateSlot,
}

/// One source item left out of the save body, for the
/// pre-confirm disclosure. `type_id` and `flag` are carried so
/// the view can resolve a name; nothing here is rendered as a
/// raw number.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DroppedFittingItem {
    pub type_id: i64,
    pub flag: String,
    pub reason: DropReason,
}

/// The finished save body plus the normalization facts the
/// confirmation discloses. Un-saveable when `ship_type_id <= 0`,
/// when `request.items` is empty (ESI requires at least one
/// item), or when `request.items` exceeds 512 (the ESI
/// maximum): truncating would silently change what the user
/// confirmed, so refusing is the honest outcome.
#[derive(Debug, Clone)]
pub struct SaveMapping {
    pub request: SaveFittingRequest,
    /// True when the name was empty/whitespace and the fallback
    /// was used.
    pub name_was_fallback: bool,
    /// `Some(original_char_count)` when the name exceeded 50
    /// characters.
    pub name_truncated_from: Option<usize>,
    /// True when the source description exceeded 500 characters.
    pub description_truncated: bool,
    pub dropped: Vec<DroppedFittingItem>,
}

const FALLBACK_NAME: &str = "Unnamed fit";
const FALLBACK_DESCRIPTION: &str = "Saved from Mimir";
const MAX_NAME_CHARS: usize = 50;
const MAX_DESCRIPTION_CHARS: usize = 500;

/// The same transformation as the view's `sanitize_single_line`:
/// control characters become spaces and whitespace runs collapse
/// to one space. A seven-line twin, pinned by tests, because
/// the fitting layer must not import the UI layer.
fn sanitize_for_save(raw: &str) -> String {
    let replaced: String = raw
        .chars()
        .map(|c| if c.is_control() { ' ' } else { c })
        .collect();
    replaced.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Slot flag prefixes with their highest valid index, per the
/// ESI flag enum: `HiSlot`/`MedSlot`/`LoSlot` 0–7, `RigSlot`
/// 0–2, `SubSystemSlot` 0–3, `ServiceSlot` 0–7.
const SLOT_FLAGS: [(&str, u32); 6] = [
    ("HiSlot", 7),
    ("MedSlot", 7),
    ("LoSlot", 7),
    ("RigSlot", 2),
    ("SubSystemSlot", 3),
    ("ServiceSlot", 7),
];

/// True when `flag` is exactly one in-range slot enum member.
/// The full string must be prefix + canonical index: `LoSlot8`,
/// `loslot0`, the empty string, and `HiSlot00` are not members.
fn is_slot_flag(flag: &str) -> bool {
    for (prefix, max) in SLOT_FLAGS {
        let Some(rest) = flag.strip_prefix(prefix) else {
            continue;
        };
        let Ok(index) = rest.parse::<u32>() else {
            return false;
        };
        return rest == index.to_string() && index <= max;
    }
    false
}

pub fn build_save_request(source: &CharacterFitting) -> SaveMapping {
    let mut kept: Vec<FittingItem> = Vec::with_capacity(source.items.len());
    let mut dropped: Vec<DroppedFittingItem> = Vec::new();
    let mut seen_slots: HashSet<String> = HashSet::new();
    let drop = |dropped: &mut Vec<DroppedFittingItem>, item: &FittingItem, reason: DropReason| {
        dropped.push(DroppedFittingItem {
            type_id: item.type_id,
            flag: item.flag.clone(),
            reason,
        });
    };
    for item in &source.items {
        if item.type_id <= 0 {
            drop(&mut dropped, item, DropReason::NotSaveable);
        } else if item.flag == "DroneBay" || item.flag == "FighterBay" || item.flag == "Cargo" {
            if item.quantity >= 1 {
                kept.push(item.clone());
            } else {
                drop(&mut dropped, item, DropReason::NotSaveable);
            }
        } else if is_slot_flag(&item.flag) {
            if seen_slots.insert(item.flag.clone()) {
                kept.push(FittingItem {
                    flag: item.flag.clone(),
                    quantity: 1,
                    type_id: item.type_id,
                });
            } else {
                drop(&mut dropped, item, DropReason::DuplicateSlot);
            }
        } else {
            drop(&mut dropped, item, DropReason::NoEsiFlag);
        }
    }

    let sanitized_name = sanitize_for_save(&source.name);
    let (name, name_was_fallback, name_truncated_from) = if sanitized_name.is_empty() {
        (FALLBACK_NAME.to_string(), true, None)
    } else {
        let char_count = sanitized_name.chars().count();
        if char_count > MAX_NAME_CHARS {
            (
                sanitized_name.chars().take(MAX_NAME_CHARS).collect(),
                false,
                Some(char_count),
            )
        } else {
            (sanitized_name, false, None)
        }
    };

    let sanitized_description = source
        .description
        .as_deref()
        .map(sanitize_for_save)
        .unwrap_or_default();
    let (description, description_truncated) = if sanitized_description.is_empty() {
        (FALLBACK_DESCRIPTION.to_string(), false)
    } else {
        let char_count = sanitized_description.chars().count();
        if char_count > MAX_DESCRIPTION_CHARS {
            (
                sanitized_description
                    .chars()
                    .take(MAX_DESCRIPTION_CHARS)
                    .collect(),
                true,
            )
        } else {
            (sanitized_description, false)
        }
    };

    tracing::debug!(
        "[FITTING] build_save_request ship_type_id_present={} kept={} dropped={}",
        source.ship_type_id > 0,
        kept.len(),
        dropped.len()
    );
    SaveMapping {
        request: SaveFittingRequest {
            name,
            description,
            ship_type_id: source.ship_type_id,
            items: kept,
        },
        name_was_fallback,
        name_truncated_from,
        description_truncated,
        dropped,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fitting(name: &str, ship_type_id: i64, items: Vec<FittingItem>) -> CharacterFitting {
        CharacterFitting {
            fitting_id: 1,
            name: name.to_string(),
            description: None,
            ship_type_id,
            items,
        }
    }

    fn item(flag: &str, quantity: i64, type_id: i64) -> FittingItem {
        FittingItem {
            flag: flag.to_string(),
            quantity,
            type_id,
        }
    }

    #[test]
    fn flutter_oracle_slot_flags_map_with_quantity_one() {
        let source = fitting(
            "Rifter",
            587,
            vec![
                item("HiSlot0", 1, 1),
                item("MedSlot3", 1, 2),
                item("LoSlot7", 1, 3),
                item("RigSlot2", 1, 4),
                item("SubSystemSlot3", 1, 5),
            ],
        );
        let mapping = build_save_request(&source);
        let flags: Vec<&str> = mapping
            .request
            .items
            .iter()
            .map(|i| i.flag.as_str())
            .collect();
        assert_eq!(
            flags,
            [
                "HiSlot0",
                "MedSlot3",
                "LoSlot7",
                "RigSlot2",
                "SubSystemSlot3"
            ]
        );
        assert!(mapping.request.items.iter().all(|i| i.quantity == 1));
        assert!(mapping.dropped.is_empty());
    }

    #[test]
    fn flutter_oracle_out_of_range_slot_is_dropped_with_type_id() {
        let source = fitting("Rifter", 587, vec![item("RigSlot3", 1, 4)]);
        let mapping = build_save_request(&source);
        assert!(mapping.request.items.is_empty());
        assert_eq!(mapping.dropped.len(), 1);
        assert_eq!(mapping.dropped[0].type_id, 4);
        assert_eq!(mapping.dropped[0].flag, "RigSlot3");
        assert_eq!(mapping.dropped[0].reason, DropReason::NoEsiFlag);
    }

    #[test]
    fn slot_quantity_is_forced_to_one() {
        let source = fitting("Rifter", 587, vec![item("LoSlot0", 9, 2048)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.items.len(), 1);
        // Passing the quantity through must fail this.
        assert_eq!(mapping.request.items[0].quantity, 1);
    }

    #[test]
    fn slot_boundaries_are_paired_in_range_and_out_of_range() {
        for (kept_flag, dropped_flag) in [
            ("LoSlot7", "LoSlot8"),
            ("RigSlot2", "RigSlot3"),
            ("SubSystemSlot3", "SubSystemSlot4"),
            ("ServiceSlot7", "ServiceSlot8"),
        ] {
            let source = fitting("Rifter", 587, vec![item(kept_flag, 1, 1)]);
            let mapping = build_save_request(&source);
            assert_eq!(mapping.request.items.len(), 1, "{kept_flag} kept");
            assert!(mapping.dropped.is_empty(), "{kept_flag} drops nothing");
            let source = fitting("Rifter", 587, vec![item(dropped_flag, 1, 1)]);
            let mapping = build_save_request(&source);
            assert!(mapping.request.items.is_empty(), "{dropped_flag} dropped");
            assert_eq!(mapping.dropped[0].reason, DropReason::NoEsiFlag);
        }
    }

    #[test]
    fn non_enum_flag_strings_are_dropped_as_no_esi_flag() {
        for flag in ["Invalid", "loslot0", "", "HiSlot00", "Hangar", "HiSlotX"] {
            let source = fitting("Rifter", 587, vec![item(flag, 1, 1)]);
            let mapping = build_save_request(&source);
            assert!(
                mapping.request.items.is_empty(),
                "flag {flag:?} must be dropped"
            );
            assert_eq!(
                mapping.dropped[0].reason,
                DropReason::NoEsiFlag,
                "flag {flag:?}"
            );
        }
    }

    #[test]
    fn duplicate_slot_flag_keeps_first_and_drops_rest() {
        let source = fitting(
            "Rifter",
            587,
            vec![item("HiSlot0", 1, 11), item("HiSlot0", 1, 12)],
        );
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.items.len(), 1);
        assert_eq!(mapping.request.items[0].type_id, 11);
        assert_eq!(mapping.dropped.len(), 1);
        assert_eq!(mapping.dropped[0].type_id, 12);
        assert_eq!(mapping.dropped[0].reason, DropReason::DuplicateSlot);
    }

    #[test]
    fn stacked_categories_keep_quantity_verbatim() {
        for flag in ["DroneBay", "FighterBay", "Cargo"] {
            let source = fitting("Rifter", 587, vec![item(flag, 5, 2456)]);
            let mapping = build_save_request(&source);
            assert_eq!(mapping.request.items.len(), 1, "{flag} kept");
            assert_eq!(mapping.request.items[0].quantity, 5, "{flag} verbatim");
            assert!(mapping.dropped.is_empty());
        }
    }

    #[test]
    fn stacked_categories_with_nonpositive_quantity_are_dropped() {
        for quantity in [0, -3] {
            for flag in ["DroneBay", "FighterBay", "Cargo"] {
                let source = fitting("Rifter", 587, vec![item(flag, quantity, 2456)]);
                let mapping = build_save_request(&source);
                assert!(
                    mapping.request.items.is_empty(),
                    "{flag} quantity {quantity} dropped"
                );
                assert_eq!(mapping.dropped[0].reason, DropReason::NotSaveable);
            }
        }
    }

    #[test]
    fn nonpositive_type_id_is_dropped_even_with_a_valid_flag() {
        for type_id in [0, -1] {
            let source = fitting("Rifter", 587, vec![item("LoSlot0", 1, type_id)]);
            let mapping = build_save_request(&source);
            assert!(mapping.request.items.is_empty());
            assert_eq!(mapping.dropped[0].reason, DropReason::NotSaveable);
        }
    }

    #[test]
    fn kept_items_preserve_source_order() {
        let source = fitting(
            "Rifter",
            587,
            vec![
                item("DroneBay", 2, 30),
                item("LoSlot0", 1, 10),
                item("RigSlot3", 1, 99),
                item("HiSlot1", 1, 20),
            ],
        );
        let mapping = build_save_request(&source);
        let type_ids: Vec<i64> = mapping.request.items.iter().map(|i| i.type_id).collect();
        assert_eq!(type_ids, [30, 10, 20]);
        assert_eq!(mapping.dropped.len(), 1);
        assert_eq!(mapping.dropped[0].type_id, 99);
    }

    #[test]
    fn normal_name_and_description_pass_through() {
        let mut source = fitting("My Rifter", 587, vec![item("LoSlot0", 1, 1)]);
        source.description = Some("close-range brawler".to_string());
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.name, "My Rifter");
        assert!(!mapping.name_was_fallback);
        assert_eq!(mapping.name_truncated_from, None);
        assert_eq!(mapping.request.description, "close-range brawler");
        assert!(!mapping.description_truncated);
    }

    #[test]
    fn empty_and_whitespace_names_fall_back() {
        for name in ["", "   ", "\t\n"] {
            let source = fitting(name, 587, vec![item("LoSlot0", 1, 1)]);
            let mapping = build_save_request(&source);
            assert_eq!(mapping.request.name, "Unnamed fit", "source {name:?}");
            assert!(mapping.name_was_fallback);
        }
    }

    #[test]
    fn name_of_exactly_50_characters_is_untouched() {
        let name = "A".repeat(50);
        let source = fitting(&name, 587, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.name, name);
        assert_eq!(mapping.name_truncated_from, None);
    }

    #[test]
    fn name_of_51_characters_truncates_to_first_50_by_characters() {
        let name = "A".repeat(51);
        let source = fitting(&name, 587, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.name, "A".repeat(50));
        assert_eq!(mapping.name_truncated_from, Some(51));
    }

    #[test]
    fn multibyte_name_truncates_by_characters_not_bytes() {
        // 51 x 'e-acute' (2 bytes each): a byte-based truncation
        // must fail this.
        let name = "é".repeat(51);
        let source = fitting(&name, 587, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.name, "é".repeat(50));
        assert_eq!(mapping.request.name.chars().count(), 50);
        assert_eq!(mapping.name_truncated_from, Some(51));
    }

    #[test]
    fn leading_and_trailing_spaces_are_trimmed_before_counting() {
        let name = format!("  {}  ", "B".repeat(50));
        let source = fitting(&name, 587, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.name, "B".repeat(50));
        assert_eq!(mapping.name_truncated_from, None);
    }

    #[test]
    fn missing_and_empty_descriptions_fall_back() {
        let source = fitting("Rifter", 587, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.description, "Saved from Mimir");

        let mut source = fitting("Rifter", 587, vec![item("LoSlot0", 1, 1)]);
        source.description = Some(String::new());
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.description, "Saved from Mimir");

        let mut source = fitting("Rifter", 587, vec![item("LoSlot0", 1, 1)]);
        source.description = Some("   ".to_string());
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.description, "Saved from Mimir");
    }

    #[test]
    fn description_of_501_characters_truncates_to_500() {
        let mut source = fitting("Rifter", 587, vec![item("LoSlot0", 1, 1)]);
        source.description = Some("D".repeat(501));
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.description, "D".repeat(500));
        assert!(mapping.description_truncated);
    }

    #[test]
    fn sanitize_collapses_controls_like_the_view_twin() {
        assert_eq!(
            sanitize_for_save("a\tb\nc\u{1}d"),
            "a b c d",
            "control characters become spaces"
        );
        assert_eq!(
            sanitize_for_save("  alpha   beta  "),
            "alpha beta",
            "whitespace runs collapse and trim"
        );
        assert_eq!(sanitize_for_save(""), "");
        assert_eq!(sanitize_for_save(" \t\n "), "");
    }

    #[test]
    fn name_is_sanitized_so_confirmation_matches_wire() {
        let source = fitting("My\n\tRifter", 587, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.name, "My Rifter");
    }

    #[test]
    fn whole_fitting_guards_are_read_from_the_mapping() {
        // Empty source items: nothing kept, un-saveable.
        let source = fitting("Rifter", 587, vec![]);
        let mapping = build_save_request(&source);
        assert!(mapping.request.items.is_empty());

        // ship_type_id 0: carried as-is, un-saveable.
        let source = fitting("Rifter", 0, vec![item("LoSlot0", 1, 1)]);
        let mapping = build_save_request(&source);
        assert_eq!(mapping.request.ship_type_id, 0);

        // 512 kept items saveable, 513 not. Stacked flags repeat
        // freely (no duplicate-slot rule), so Cargo repeats.
        let items: Vec<FittingItem> = (0..512).map(|_| item("Cargo", 1, 36)).collect();
        assert_eq!(
            build_save_request(&fitting("R", 587, items))
                .request
                .items
                .len(),
            512
        );
        let items: Vec<FittingItem> = (0..513).map(|_| item("Cargo", 1, 36)).collect();
        assert_eq!(
            build_save_request(&fitting("R", 587, items))
                .request
                .items
                .len(),
            513
        );
    }
}
