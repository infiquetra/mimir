//! Cross-character Pantry indexer (card #642): aggregates every
//! linked character's assets into location buckets and per-type
//! totals. Pure functions over in-memory rows — no DB, no network —
//! so demo mode and tests exercise the exact live code path.
//! Display strings are always resolved names supplied by the
//! caller; raw numeric EVE ids stay in state fields only and are
//! never formatted into a bucket name or a log line.

use std::collections::{BTreeMap, HashMap, HashSet};
use std::hash::{BuildHasherDefault, Hasher};

/// Splitmix-style single-word hasher for `i64` keys: the std
/// SipHash map costs ~450 ns/op in debug builds, which alone
/// would blow the 2 ms / 25,000-row preparation budget.
#[derive(Debug, Default)]
struct FastHasher(u64);

impl Hasher for FastHasher {
    fn finish(&self) -> u64 {
        self.0
    }

    fn write(&mut self, bytes: &[u8]) {
        for byte in bytes {
            self.0 = (self.0 ^ u64::from(*byte)).wrapping_mul(0x0100_0000_01b3);
        }
    }

    fn write_i64(&mut self, value: i64) {
        let mut z = (value as u64).wrapping_add(0x9E37_79B9_7F4A_7C15);
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        self.0 = z ^ (z >> 31);
    }
}

type FastMap<K, V> = HashMap<K, V, BuildHasherDefault<FastHasher>>;

/// Resolve through a small linear cache (characters and places
/// are naturally few) without paying map hashing per row.
fn resolve_linear<'a>(
    cache: &'a mut Vec<(i64, String)>,
    id: i64,
    resolve: &impl Fn(i64) -> String,
) -> &'a str {
    if let Some(position) = cache.iter().position(|(cached_id, _)| *cached_id == id) {
        return &cache[position].1;
    }
    cache.push((id, resolve(id)));
    &cache.last().expect("just pushed").1
}

use crate::esi::models::AssetItem;
use crate::storage::repositories::CharacterAssetRow;

/// Deterministic bucket name for holdings whose Upwell structure
/// name could not be resolved (HTTP 403). Never carries an id.
pub const UNRESOLVED_STRUCTURE: &str = "Unresolved Structure";

/// Per-frame cap on newly queued type-icon fetches (preserved
/// from the Assets view contract; virtualization must not lift it).
pub const MAX_NEW_ICON_FETCHES_PER_FRAME: usize = 100;

/// The assets scope whose absence produces a step-up badge.
pub const ASSETS_SCOPE: &str = "esi-assets.read_assets.v1";

/// One owned item instance in the cross-character index.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct PantryItem {
    pub character_id: i64,
    pub item_id: i64,
    pub type_id: i64,
    pub location_id: i64,
    pub location_flag: String,
    pub location_type: String,
    pub quantity: i64,
    pub is_singleton: bool,
    pub is_blueprint_copy: bool,
}

impl PantryItem {
    pub fn from_asset(character_id: i64, item: &AssetItem) -> Self {
        Self {
            character_id,
            item_id: item.item_id,
            type_id: item.type_id,
            location_id: item.location_id,
            location_flag: item.location_flag.clone(),
            location_type: item.location_type.clone(),
            quantity: item.quantity,
            is_singleton: item.is_singleton,
            is_blueprint_copy: item.is_blueprint_copy == Some(true),
        }
    }

    pub fn from_row(row: &CharacterAssetRow) -> Self {
        Self {
            character_id: row.character_id,
            item_id: row.item_id,
            type_id: row.type_id,
            location_id: row.location_id,
            location_flag: row.location_flag.clone(),
            location_type: String::new(),
            quantity: row.quantity,
            is_singleton: row.is_singleton,
            is_blueprint_copy: false,
        }
    }

    pub fn to_row(&self) -> CharacterAssetRow {
        CharacterAssetRow {
            character_id: self.character_id,
            item_id: self.item_id,
            type_id: self.type_id,
            location_id: self.location_id,
            location_flag: self.location_flag.clone(),
            quantity: self.quantity,
            is_singleton: self.is_singleton,
        }
    }
}

/// Where a holding physically sits, derived from ESI fields only.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LocationKind {
    NpcStation,
    UpwellHangar,
    NestedContainer,
    InfrastructureHold,
}

impl LocationKind {
    pub fn label(&self) -> &'static str {
        match self {
            LocationKind::NpcStation => "Station",
            LocationKind::UpwellHangar => "Structure hangar",
            LocationKind::NestedContainer => "Container",
            LocationKind::InfrastructureHold => "Infrastructure hold",
        }
    }
}

/// Classify one item. `item_ids` holds every owned item id, so a
/// `location_id` pointing at another owned item is a nested
/// container (or a fitted ship) rather than a place.
pub fn classify(item: &PantryItem, item_ids: &HashSet<i64>) -> LocationKind {
    if item.location_flag == "InfrastructureHold" {
        LocationKind::InfrastructureHold
    } else if item_ids.contains(&item.location_id) {
        LocationKind::NestedContainer
    } else if item.location_type == "item" {
        LocationKind::UpwellHangar
    } else {
        LocationKind::NpcStation
    }
}

/// Walk container parents to the root place id. Bounded and
/// cycle-safe: a parent cycle stops at the last seen id.
pub fn root_location_id(item: &PantryItem, by_item: &HashMap<i64, &PantryItem>) -> i64 {
    let mut current = item.location_id;
    let mut seen: HashSet<i64> = HashSet::new();
    while let Some(parent) = by_item.get(&current) {
        if !seen.insert(current) {
            break;
        }
        current = parent.location_id;
    }
    current
}

/// All holdings at one root location, across every character.
#[derive(Debug, Clone, PartialEq)]
pub struct LocationBucket {
    /// State-only root id; never rendered.
    pub location_id: i64,
    /// Resolved place name, or [`UNRESOLVED_STRUCTURE`].
    pub display_name: String,
    pub kind: LocationKind,
    pub items: Vec<PantryItem>,
    pub total_quantity: i64,
    pub type_count: usize,
    pub blueprint_count: usize,
}

/// Group items into root-location buckets. `resolve_name` maps a
/// root id to its display name; `is_unresolved_structure` marks
/// structure ids whose name lookup was denied, and those buckets
/// are renamed to the deterministic [`UNRESOLVED_STRUCTURE`]
/// label (merged per root id, never per raw id in the label).
pub fn build_buckets(
    items: &[PantryItem],
    resolve_name: impl Fn(i64) -> String,
    is_unresolved_structure: impl Fn(i64) -> bool,
) -> Vec<LocationBucket> {
    let item_ids: HashSet<i64> = items.iter().map(|i| i.item_id).collect();
    let by_item: HashMap<i64, &PantryItem> = items.iter().map(|i| (i.item_id, i)).collect();
    let mut grouped: BTreeMap<i64, Vec<PantryItem>> = BTreeMap::new();
    for item in items {
        grouped
            .entry(root_location_id(item, &by_item))
            .or_default()
            .push(item.clone());
    }
    let mut buckets: Vec<LocationBucket> = grouped
        .into_iter()
        .map(|(location_id, bucket_items)| {
            let display_name = if is_unresolved_structure(location_id) {
                UNRESOLVED_STRUCTURE.to_string()
            } else {
                resolve_name(location_id)
            };
            let kind = bucket_items
                .iter()
                .map(|i| classify(i, &item_ids))
                .find(|k| *k != LocationKind::NestedContainer)
                .unwrap_or(LocationKind::NestedContainer);
            let total_quantity = bucket_items
                .iter()
                .fold(0i64, |acc, i| acc.saturating_add(i.quantity));
            let type_count = bucket_items
                .iter()
                .map(|i| i.type_id)
                .collect::<HashSet<_>>()
                .len();
            let blueprint_count = bucket_items.iter().filter(|i| i.is_blueprint_copy).count();
            LocationBucket {
                location_id,
                display_name,
                kind,
                type_count,
                total_quantity,
                blueprint_count,
                items: bucket_items,
            }
        })
        .collect();
    buckets.sort_by(|a, b| {
        a.display_name
            .cmp(&b.display_name)
            .then(a.location_id.cmp(&b.location_id))
    });
    tracing::debug!(
        "[PANTRY] built buckets items={} buckets={}",
        items.len(),
        buckets.len()
    );
    buckets
}

/// Total quantity per type across every character and location.
/// Quantities saturate: ESI rows decode without range checks.
pub fn aggregate_by_type(items: &[PantryItem]) -> BTreeMap<i64, i64> {
    let mut totals: BTreeMap<i64, i64> = BTreeMap::new();
    for item in items {
        let entry = totals.entry(item.type_id).or_insert(0);
        *entry = entry.saturating_add(item.quantity);
    }
    totals
}

/// One linked character's scope fact for the step-up badge list.
#[derive(Debug, Clone, PartialEq)]
pub struct CharacterScopeFact {
    pub character_id: i64,
    pub character_name: String,
    pub has_assets_scope: bool,
}

/// Explicit badge state for one character missing the assets
/// scope. Authorized characters never produce a badge; their
/// holdings still count toward Pantry totals.
#[derive(Debug, Clone, PartialEq)]
pub struct StepUpBadge {
    pub character_id: i64,
    pub character_name: String,
    pub missing_scope: &'static str,
}

pub fn step_up_badges(facts: &[CharacterScopeFact]) -> Vec<StepUpBadge> {
    let mut badges: Vec<StepUpBadge> = facts
        .iter()
        .filter(|f| !f.has_assets_scope)
        .map(|f| StepUpBadge {
            character_id: f.character_id,
            character_name: f.character_name.clone(),
            missing_scope: ASSETS_SCOPE,
        })
        .collect();
    badges.sort_by_key(|b| b.character_id);
    if !badges.is_empty() {
        tracing::debug!("[PANTRY] step-up badges count={}", badges.len());
    }
    badges
}

/// One flat display row for the virtualized Pantry table. Names
/// are resolved by the caller; ids stay state-only.
#[derive(Debug, Clone, PartialEq)]
pub struct PantryDisplayRow {
    pub item_id: i64,
    pub type_id: i64,
    pub type_name: String,
    pub character_name: String,
    pub location_name: String,
    pub location_flag: String,
    pub quantity: i64,
    pub is_singleton: bool,
    pub is_blueprint_copy: bool,
    /// Lowercased `type / character / location` search key,
    /// built once at row-build time so per-keystroke filtering
    /// is a single substring scan (the Quick-Sight index split).
    pub search_key: String,
    /// Bloom-style byte-trigram mask over `search_key`: a
    /// substring match requires every query trigram bit, so one
    /// integer AND rejects most rows before the exact scan.
    pub trigram_mask: u64,
}

/// Trigram bitmask over raw bytes (sound prefilter: a true
/// substring match always sets every one of its trigram bits).
fn trigram_mask(bytes: &[u8]) -> u64 {
    let mut mask: u64 = 0;
    for window in bytes.windows(3) {
        let hash = (u32::from(window[0]) * 31 + u32::from(window[1])) * 31 + u32::from(window[2]);
        mask |= 1u64 << (hash % 64);
    }
    mask
}

/// Build the full display-row set for a snapshot: names resolve
/// once per distinct id (cached), rows sort by resolved type
/// name then location then item id, and each row precomputes its
/// lowercase search key. This is snapshot-landing work, done
/// once per refresh — never the per-keystroke cost.
pub fn build_display_rows(
    items: &[PantryItem],
    type_name: impl Fn(i64) -> String,
    character_name: impl Fn(i64) -> String,
    location_name: impl Fn(i64) -> String,
) -> Vec<PantryDisplayRow> {
    let mut type_cache: FastMap<i64, String> = FastMap::default();
    let mut character_cache: Vec<(i64, String)> = Vec::new();
    let mut location_cache: Vec<(i64, String)> = Vec::new();
    let mut rows: Vec<PantryDisplayRow> = Vec::with_capacity(items.len());
    for item in items {
        let resolved_type = type_cache
            .entry(item.type_id)
            .or_insert_with(|| type_name(item.type_id))
            .clone();
        let resolved_character =
            resolve_linear(&mut character_cache, item.character_id, &character_name).to_string();
        let resolved_location =
            resolve_linear(&mut location_cache, item.location_id, &location_name).to_string();
        let search_key = format!(
            "{} {} {}",
            resolved_type.to_lowercase(),
            resolved_character.to_lowercase(),
            resolved_location.to_lowercase()
        );
        let mask = trigram_mask(search_key.as_bytes());
        rows.push(PantryDisplayRow {
            item_id: item.item_id,
            type_id: item.type_id,
            type_name: resolved_type,
            character_name: resolved_character,
            location_name: resolved_location,
            location_flag: item.location_flag.clone(),
            quantity: item.quantity,
            is_singleton: item.is_singleton,
            is_blueprint_copy: item.is_blueprint_copy,
            trigram_mask: mask,
            search_key,
        });
    }
    rows.sort_by(|a, b| {
        a.type_name
            .cmp(&b.type_name)
            .then(a.location_name.cmp(&b.location_name))
            .then(a.item_id.cmp(&b.item_id))
    });
    rows
}

/// Per-keystroke filter over prebuilt rows: one substring scan
/// of each row's precomputed search key, returning matching row
/// indices in build-sort order (no row clones). This is the CPU
/// work the virtualization bench pins (< 2.0 ms over 25,000
/// rows, best of N).
pub fn filter_row_indices(rows: &[PantryDisplayRow], query: &str) -> Vec<usize> {
    let needle = query.trim().to_lowercase();
    let mut indices: Vec<usize> = Vec::new();
    if needle.is_empty() {
        indices.extend(0..rows.len());
        return indices;
    }
    // Queries of 3+ bytes prefilter on the trigram mask (one
    // integer AND per row); candidates verify with the exact
    // substring scan, so results are exact, never approximate.
    let query_mask = if needle.len() >= 3 {
        trigram_mask(needle.as_bytes())
    } else {
        0
    };
    for (index, row) in rows.iter().enumerate() {
        if query_mask != 0 && (row.trigram_mask & query_mask) != query_mask {
            continue;
        }
        if row.search_key.contains(&needle) {
            indices.push(index);
        }
    }
    indices
}

/// Choose which visible type icons may newly queue this frame:
/// order-preserving, de-duplicated, and capped. Returns at most
/// `cap` ids not already in `already_requested`.
pub fn select_new_icon_fetches(
    visible_type_ids: &[i64],
    already_requested: &HashSet<i64>,
    cap: usize,
) -> Vec<i64> {
    let mut chosen: Vec<i64> = Vec::new();
    let mut seen: HashSet<i64> = HashSet::new();
    for type_id in visible_type_ids {
        if chosen.len() >= cap {
            break;
        }
        if already_requested.contains(type_id) || !seen.insert(*type_id) {
            continue;
        }
        chosen.push(*type_id);
    }
    chosen
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(
        character_id: i64,
        item_id: i64,
        type_id: i64,
        location_id: i64,
        flag: &str,
        location_type: &str,
        quantity: i64,
    ) -> PantryItem {
        PantryItem {
            character_id,
            item_id,
            type_id,
            location_id,
            location_flag: flag.to_string(),
            location_type: location_type.to_string(),
            quantity,
            is_singleton: false,
            is_blueprint_copy: false,
        }
    }

    #[test]
    fn aggregates_across_characters_stations_structures_containers_blueprints_and_infra_hold() {
        // Char 1 at an NPC station; char 2 in an Upwell hangar
        // (location_type "item"), a nested container inside that
        // hangar, a blueprint copy, and an InfrastructureHold bay.
        let mut blueprint = item(2, 500, 681, 1_060_000_001, "Hangar", "item", 1);
        blueprint.is_blueprint_copy = true;
        let items = vec![
            item(1, 100, 34, 60003760, "Hangar", "station", 100),
            item(1, 101, 34, 60003760, "Hangar", "station", 50),
            item(2, 200, 34, 1_060_000_001, "Hangar", "item", 25),
            // Container (item 300) sits in the structure hangar;
            // item 301 lives inside container 300.
            item(2, 300, 3465, 1_060_000_001, "Hangar", "item", 1),
            item(2, 301, 35, 300, "Hangar", "item", 40),
            blueprint,
            item(2, 600, 36, 1_060_000_002, "InfrastructureHold", "item", 7),
        ];
        let totals = aggregate_by_type(&items);
        assert_eq!(
            totals.get(&34),
            Some(&175),
            "cross-character station+structure total"
        );
        assert_eq!(
            totals.get(&35),
            Some(&40),
            "nested container contents count"
        );
        assert_eq!(totals.get(&36), Some(&7), "InfrastructureHold counts");

        let buckets = build_buckets(
            &items,
            |id| match id {
                60003760 => "Jita Station".to_string(),
                1_060_000_001 => "Perimeter Keepstar".to_string(),
                1_060_000_002 => "Perimeter Keepstar".to_string(),
                _ => "Unknown Location".to_string(),
            },
            |_| false,
        );
        assert_eq!(buckets.len(), 3, "station + structure + infra roots");
        let structure = buckets
            .iter()
            .find(|b| b.location_id == 1_060_000_001)
            .expect("structure bucket");
        assert_eq!(structure.kind, LocationKind::UpwellHangar);
        assert_eq!(structure.blueprint_count, 1);
        assert!(
            structure.items.iter().any(|i| i.item_id == 301),
            "nested container contents roll up to the root structure"
        );
        let infra = buckets
            .iter()
            .find(|b| b.location_id == 1_060_000_002)
            .expect("infra bucket");
        assert_eq!(infra.kind, LocationKind::InfrastructureHold);
    }

    #[test]
    fn classify_covers_each_location_kind() {
        let ids: HashSet<i64> = [300].into_iter().collect();
        assert_eq!(
            classify(&item(1, 1, 34, 60003760, "Hangar", "station", 1), &ids),
            LocationKind::NpcStation
        );
        assert_eq!(
            classify(&item(1, 1, 34, 999, "Hangar", "item", 1), &ids),
            LocationKind::UpwellHangar
        );
        assert_eq!(
            classify(&item(1, 1, 34, 300, "Hangar", "item", 1), &ids),
            LocationKind::NestedContainer
        );
        assert_eq!(
            classify(&item(1, 1, 34, 999, "InfrastructureHold", "item", 1), &ids),
            LocationKind::InfrastructureHold
        );
    }

    #[test]
    fn unresolved_structure_names_group_deterministically_without_raw_ids() {
        let items = vec![
            item(1, 100, 34, 1_060_000_000_009, "Hangar", "item", 10),
            item(2, 200, 34, 1_060_000_000_009, "Hangar", "item", 5),
        ];
        let buckets = build_buckets(
            &items,
            |_| "Unknown Location".to_string(),
            |id| id == 1_060_000_000_009,
        );
        assert_eq!(buckets.len(), 1);
        assert_eq!(buckets[0].display_name, UNRESOLVED_STRUCTURE);
        assert!(!buckets[0].display_name.chars().any(|c| c.is_ascii_digit()));
        assert_eq!(buckets[0].total_quantity, 15);
    }

    #[test]
    fn missing_assets_scope_yields_per_character_step_up_badge_only() {
        let badges = step_up_badges(&[
            CharacterScopeFact {
                character_id: 2,
                character_name: "Bravo".to_string(),
                has_assets_scope: false,
            },
            CharacterScopeFact {
                character_id: 1,
                character_name: "Alpha".to_string(),
                has_assets_scope: true,
            },
        ]);
        assert_eq!(badges.len(), 1);
        assert_eq!(badges[0].character_name, "Bravo");
        assert_eq!(badges[0].missing_scope, ASSETS_SCOPE);
    }

    #[test]
    fn icon_fetch_selection_is_capped_and_deduplicated() {
        let visible: Vec<i64> = (0..500).collect();
        let already: HashSet<i64> = [0, 1, 2].into_iter().collect();
        let chosen = select_new_icon_fetches(&visible, &already, MAX_NEW_ICON_FETCHES_PER_FRAME);
        assert_eq!(chosen.len(), 100);
        assert!(!chosen.contains(&0));
        let dupes = select_new_icon_fetches(&[34, 34, 35], &HashSet::new(), 100);
        assert_eq!(dupes, vec![34, 35]);
    }
}
