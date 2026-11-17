//! Portrait and logo rendering for the character surfaces
//! (Characters list and detail, Dashboard grid): upload each
//! decoded image to an egui texture exactly once per
//! `(ImageKind, id)`, and draw the honest placeholder for every
//! other state (the name initial for portraits, a blank box for
//! logos). Fetch, cache, and landing live in `crate::portraits`
//! and `crate::app::state` / `crate::app::shell`; this module
//! only turns ready state into widgets. The shell owns the
//! `PortraitImageCache`: a `TextureHandle` must outlive the frame
//! that created it, so textures can never be per-frame uploads.
//!
//! Logging follows the view-layer convention: the per-frame render
//! path is log-free (one visible portrait renders once per frame,
//! and frame-rate lines would flood the log buffer); the
//! once-per-something events — texture upload, replacement, and
//! prune, plus the request transition delegated to
//! `AppState::request_portrait` — carry `[PORTRAIT]` logs.
//! Character ids are plain integers (the `[CHAR]`/`[ESI]`
//! convention); character names never appear in logs.

use std::collections::HashMap;
use std::sync::Arc;

use crate::app::state::{AppState, PortraitState};
use crate::portraits::{initial_for_name, ImageKind};

/// Render size of a list or grid-row portrait, in points. The
/// decoded image is 256px; views downscale it, never upscale.
pub const LIST_PORTRAIT_PX: f32 = 32.0;
/// Render size of the active-character detail portrait, in points.
pub const DETAIL_PORTRAIT_PX: f32 = 96.0;
/// Render size of a detail corporation or alliance logo, in
/// points: left of the resolved name, matching the Flutter
/// overview tab's icon size.
pub const DETAIL_LOGO_PX: f32 = 20.0;

/// One uploaded image: the decoded image it was built from
/// (identity check via `Arc::ptr_eq`) plus its live texture.
struct CachedTexture {
    source: Arc<image::DynamicImage>,
    handle: egui::TextureHandle,
}

/// Per-application image textures, owned by `MimirApp` and
/// passed into the character views. Upload happens once per
/// `(kind, id)` image; a replaced image (remove and re-add)
/// uploads anew and never shows the old one.
#[derive(Default)]
pub struct PortraitImageCache {
    textures: HashMap<(ImageKind, i64), CachedTexture>,
}

impl PortraitImageCache {
    /// An empty cache. Construction uploads nothing.
    pub fn new() -> Self {
        Self::default()
    }

    /// Drop textures for entities the state no longer knows,
    /// freeing the GPU texture so a removed entity's image cannot
    /// linger — and a later re-added entity re-uploads. Retention
    /// uses the same `image_id_known` guard as fetching (rows, the
    /// loaded character detail, or the loaded standings), so a logo
    /// known only from standings is not dropped and re-uploaded
    /// every frame while rows are still stale.
    pub fn prune(&mut self, state: &AppState) {
        let before = self.textures.len();
        self.textures
            .retain(|(kind, id), _| state.image_id_known(*kind, *id));
        if self.textures.len() != before {
            tracing::debug!(
                "[PORTRAIT] image textures pruned remaining={}",
                self.textures.len()
            );
        }
    }

    /// Number of textures currently held.
    pub fn len(&self) -> usize {
        self.textures.len()
    }

    /// Whether no texture is currently held.
    pub fn is_empty(&self) -> bool {
        self.textures.is_empty()
    }

    /// The texture for one `(kind, id)`'s `Ready` image, uploading
    /// the decoded image exactly once. `None` for every non-Ready
    /// state: only `Ready` under that exact key renders an image,
    /// never a fabricated face, never another entity's. The
    /// `to_rgba8` into `from_rgba_unmultiplied` upload carries
    /// PNG logo alpha to the screen unchanged; the kind is part
    /// of the texture name so two kinds never share a texture.
    pub fn texture(
        &mut self,
        ctx: &egui::Context,
        state: &AppState,
        kind: ImageKind,
        id: i64,
    ) -> Option<egui::TextureHandle> {
        let image = match state.portrait_state(kind, id) {
            PortraitState::Ready(image) => image,
            PortraitState::NotRequested | PortraitState::Loading | PortraitState::Failed => {
                return None;
            }
        };
        let replaced = match self.textures.get(&(kind, id)) {
            Some(cached) if Arc::ptr_eq(&cached.source, image) => {
                return Some(cached.handle.clone());
            }
            Some(_) => true,
            None => false,
        };
        let rgba = image.to_rgba8();
        let (width, height) = (rgba.width(), rgba.height());
        let color = egui::ColorImage::from_rgba_unmultiplied(
            [width as usize, height as usize],
            rgba.as_raw(),
        );
        let texture_name = match kind {
            ImageKind::Character => format!("portrait-{id}"),
            ImageKind::Corporation => format!("logo-corp-{id}"),
            ImageKind::Alliance => format!("logo-alliance-{id}"),
            ImageKind::Faction => format!("logo-faction-{id}"),
        };
        let handle = ctx.load_texture(texture_name, color, egui::TextureOptions::default());
        if replaced {
            tracing::info!(
                "[PORTRAIT] image texture replaced kind={} id={}",
                kind.as_str(),
                id
            );
        } else {
            tracing::info!(
                "[PORTRAIT] image texture uploaded kind={} id={} {width}x{height}",
                kind.as_str(),
                id
            );
        }
        self.textures.insert(
            (kind, id),
            CachedTexture {
                source: Arc::clone(image),
                handle: handle.clone(),
            },
        );
        Some(handle)
    }
}

/// Queue a portrait fetch for one visible character, but only when
/// nothing is in flight and nothing has failed yet. A `Failed`
/// portrait is deliberately not re-requested from the render path:
/// that would retry-loop against the image service at frame rate.
/// A failed portrait retries through the detail view's retry
/// button, which calls `AppState::request_portrait` directly.
/// In demo mode the queued request is drained by the shell
/// without spawning, so demo still makes zero network calls.
pub fn ensure_portrait_requested(state: &mut AppState, character_id: i64) {
    if matches!(
        state.portrait_state(ImageKind::Character, character_id),
        PortraitState::NotRequested
    ) {
        state.request_portrait(ImageKind::Character, character_id);
    }
}

/// Queue a logo fetch for one corporation, alliance, or faction,
/// with the same rule as `ensure_portrait_requested`: only a
/// `NotRequested` key queues, a `Failed` logo retries through the
/// detail view's retry button, and an unknown id queues nothing
/// through the state guard. In demo mode the queued request is
/// drained by the shell without spawning, so demo still makes
/// zero network calls.
pub fn ensure_logo_requested(state: &mut AppState, kind: ImageKind, id: i64) {
    if matches!(state.portrait_state(kind, id), PortraitState::NotRequested) {
        state.request_portrait(kind, id);
    }
}

/// Status line for a placeholder portrait: what the user is
/// looking at and why there is no image. `Ready` maps to `""`
/// because an image, not a placeholder, renders.
pub fn placeholder_status(demo: bool, portrait: &PortraitState) -> &'static str {
    match portrait {
        PortraitState::Ready(_) => "",
        _ if demo => "Portraits are not fetched in demo mode.",
        PortraitState::NotRequested | PortraitState::Loading => "Loading portrait...",
        PortraitState::Failed => "Portrait unavailable.",
    }
}

/// Render one character's portrait, `size_px` points square: the
/// image when `Ready` for that exact character id, otherwise the
/// initial placeholder — never a fabricated or stock face.
pub fn show_portrait(
    ui: &mut egui::Ui,
    cache: &mut PortraitImageCache,
    state: &AppState,
    character_id: i64,
    name: &str,
    size_px: f32,
) -> egui::Response {
    if let Some(handle) = cache.texture(ui.ctx(), state, ImageKind::Character, character_id) {
        let image = egui::Image::new((handle.id(), handle.size_vec2()))
            .fit_to_exact_size(egui::Vec2::splat(size_px));
        ui.add(image)
    } else {
        let initial = initial_for_name(name)
            .map(|c| c.to_string())
            .unwrap_or_else(|| "?".to_string());
        let (response, painter) =
            ui.allocate_painter(egui::Vec2::splat(size_px), egui::Sense::hover());
        painter.text(
            response.rect.center(),
            egui::Align2::CENTER_CENTER,
            initial,
            egui::FontId::proportional(size_px * 0.5),
            ui.visuals().text_color(),
        );
        response
    }
}

/// Render one corporation, alliance, or faction logo,
/// `size_px` points square: the image when `Ready` for that exact `(kind, id)`,
/// otherwise a blank box of the theme's faint background color —
/// never a fabricated or stock mark. There is deliberately no
/// `name` parameter: a logo placeholder shows no initial and no
/// letter, so a name cannot be formatted into its slot by
/// accident, and no raw id is formatted either. The resolved
/// name the caller draws beside the box carries the meaning,
/// so nothing is lost while the logo loads or after it fails.
pub fn show_logo(
    ui: &mut egui::Ui,
    cache: &mut PortraitImageCache,
    state: &AppState,
    kind: ImageKind,
    id: i64,
    size_px: f32,
) -> egui::Response {
    if let Some(handle) = cache.texture(ui.ctx(), state, kind, id) {
        let image = egui::Image::new((handle.id(), handle.size_vec2()))
            .fit_to_exact_size(egui::Vec2::splat(size_px));
        ui.add(image)
    } else {
        let (response, painter) =
            ui.allocate_painter(egui::Vec2::splat(size_px), egui::Sense::hover());
        painter.rect_filled(response.rect, 2.0, ui.visuals().faint_bg_color);
        response
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::app::state::{CharacterDetailData, LoadState};
    use crate::esi::models::{
        CharacterAttributes, CharacterClones, CharacterLocation, CharacterOnline, CharacterShip,
        Standing,
    };
    use crate::storage::repositories::CharacterRow;

    fn test_row(id: i64, name: &str) -> CharacterRow {
        CharacterRow {
            character_id: id,
            name: name.to_string(),
            corporation_id: 1000166,
            alliance_id: None,
            is_active: false,
        }
    }

    fn state_with_ids(ids: &[i64]) -> AppState {
        let mut state = AppState::default();
        for id in ids {
            state.characters.push(test_row(*id, "Test Pilot"));
        }
        state
    }

    fn ready_image(width: u32, height: u32) -> Arc<image::DynamicImage> {
        Arc::new(image::DynamicImage::new_rgb8(width, height))
    }

    #[test]
    fn placeholder_status_covers_every_state() {
        let ready = PortraitState::Ready(ready_image(8, 8));
        assert_eq!(placeholder_status(false, &ready), "");
        assert_eq!(placeholder_status(true, &ready), "");
        assert_eq!(
            placeholder_status(false, &PortraitState::NotRequested),
            "Loading portrait..."
        );
        assert_eq!(
            placeholder_status(false, &PortraitState::Loading),
            "Loading portrait..."
        );
        assert_eq!(
            placeholder_status(false, &PortraitState::Failed),
            "Portrait unavailable."
        );
        assert_eq!(
            placeholder_status(true, &PortraitState::NotRequested),
            "Portraits are not fetched in demo mode."
        );
        assert_eq!(
            placeholder_status(true, &PortraitState::Loading),
            "Portraits are not fetched in demo mode."
        );
        assert_eq!(
            placeholder_status(true, &PortraitState::Failed),
            "Portraits are not fetched in demo mode."
        );
    }

    #[test]
    fn ensure_requests_only_unrequested_portraits() {
        let mut state = state_with_ids(&[1, 2, 3, 4]);
        state
            .portraits
            .insert((ImageKind::Character, 2), PortraitState::Loading);
        state.portraits.insert(
            (ImageKind::Character, 3),
            PortraitState::Ready(ready_image(8, 8)),
        );
        state
            .portraits
            .insert((ImageKind::Character, 4), PortraitState::Failed);

        ensure_portrait_requested(&mut state, 1);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Character, 1)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 1),
            PortraitState::Loading
        ));

        // Loading, Ready, and Failed are all left alone: Failed in
        // particular never re-queues from the render path, so a
        // failed portrait cannot retry-loop at frame rate.
        ensure_portrait_requested(&mut state, 2);
        ensure_portrait_requested(&mut state, 3);
        ensure_portrait_requested(&mut state, 4);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Character, 1)]);
        assert!(matches!(
            state.portrait_state(ImageKind::Character, 4),
            PortraitState::Failed
        ));

        // Unknown ids queue nothing and fabricate no entry.
        ensure_portrait_requested(&mut state, 999);
        assert_eq!(state.portrait_requests, vec![(ImageKind::Character, 1)]);
    }

    #[test]
    fn prune_on_an_empty_cache_keeps_it_empty() {
        let mut cache = PortraitImageCache::new();
        assert!(cache.is_empty());
        cache.prune(&state_with_ids(&[]));
        cache.prune(&state_with_ids(&[1]));
        assert!(cache.is_empty());
        assert_eq!(cache.len(), 0);
    }

    #[test]
    fn texture_is_none_until_ready() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1, 2, 3, 4]);
        let mut cache = PortraitImageCache::new();

        assert!(cache
            .texture(&ctx, &state, ImageKind::Character, 1)
            .is_none());
        state
            .portraits
            .insert((ImageKind::Character, 2), PortraitState::Loading);
        assert!(cache
            .texture(&ctx, &state, ImageKind::Character, 2)
            .is_none());
        state
            .portraits
            .insert((ImageKind::Character, 3), PortraitState::Failed);
        assert!(cache
            .texture(&ctx, &state, ImageKind::Character, 3)
            .is_none());
        state.portraits.insert(
            (ImageKind::Character, 4),
            PortraitState::Ready(ready_image(8, 8)),
        );
        assert!(cache
            .texture(&ctx, &state, ImageKind::Character, 4)
            .is_some());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn texture_uploads_once_per_image() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1]);
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Character, 1),
            PortraitState::Ready(ready_image(8, 8)),
        );

        let first = cache
            .texture(&ctx, &state, ImageKind::Character, 1)
            .expect("ready uploads");
        let again = cache
            .texture(&ctx, &state, ImageKind::Character, 1)
            .expect("ready reuses");
        assert_eq!(first.id(), again.id(), "one upload per image");

        // A replaced image object for the same character uploads
        // anew instead of showing the old face.
        state.portraits.insert(
            (ImageKind::Character, 1),
            PortraitState::Ready(ready_image(8, 8)),
        );
        let replaced = cache
            .texture(&ctx, &state, ImageKind::Character, 1)
            .expect("replaced uploads");
        assert_ne!(first.id(), replaced.id());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn prune_frees_removed_characters_and_reuploads() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1, 2]);
        let mut cache = PortraitImageCache::new();
        for id in [1i64, 2] {
            state.portraits.insert(
                (ImageKind::Character, id),
                PortraitState::Ready(ready_image(8, 8)),
            );
            let _ = cache
                .texture(&ctx, &state, ImageKind::Character, id)
                .expect("upload");
        }
        assert_eq!(cache.len(), 2);

        let kept_id = cache
            .texture(&ctx, &state, ImageKind::Character, 1)
            .expect("reuse")
            .id();
        let old_id = cache
            .texture(&ctx, &state, ImageKind::Character, 2)
            .expect("reuse")
            .id();
        cache.prune(&state_with_ids(&[1]));
        assert_eq!(cache.len(), 1);

        // The still-listed character keeps its texture; the pruned
        // one re-uploads when it returns.
        assert_eq!(
            cache
                .texture(&ctx, &state, ImageKind::Character, 1)
                .expect("kept")
                .id(),
            kept_id
        );
        assert_ne!(
            cache
                .texture(&ctx, &state, ImageKind::Character, 2)
                .expect("re-upload")
                .id(),
            old_id
        );
        cache.prune(&state_with_ids(&[]));
        assert!(cache.is_empty());
        assert!(cache
            .texture(&ctx, &state, ImageKind::Character, 1)
            .is_some());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn show_portrait_runs_headless() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1, 2]);
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Character, 1),
            PortraitState::Ready(ready_image(8, 8)),
        );
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                show_portrait(ui, &mut cache, &state, 1, "Test Pilot", LIST_PORTRAIT_PX);
                show_portrait(ui, &mut cache, &state, 2, "Test Pilot", LIST_PORTRAIT_PX);
            });
        });
        assert_eq!(cache.len(), 1, "only the Ready portrait uploaded");
    }

    #[test]
    fn ensure_logo_requests_only_unrequested_known_logos() {
        // `test_row` carries corporation 1000166, so that key is
        // known by row; each state below isolates one status.
        let mut unrequested = state_with_ids(&[1]);
        ensure_logo_requested(&mut unrequested, ImageKind::Corporation, 1000166);
        assert_eq!(
            unrequested.portrait_requests,
            vec![(ImageKind::Corporation, 1000166)]
        );
        assert!(matches!(
            unrequested.portrait_state(ImageKind::Corporation, 1000166),
            PortraitState::Loading
        ));

        for (label, entry) in [
            ("loading", PortraitState::Loading),
            ("ready", PortraitState::Ready(ready_image(8, 8))),
            ("failed", PortraitState::Failed),
        ] {
            let mut state = state_with_ids(&[1]);
            state
                .portraits
                .insert((ImageKind::Corporation, 1000166), entry);
            ensure_logo_requested(&mut state, ImageKind::Corporation, 1000166);
            assert!(
                state.portrait_requests.is_empty(),
                "{label} must queue nothing"
            );
        }

        // Unknown ids queue nothing and fabricate no entry.
        let mut unknown = state_with_ids(&[1]);
        ensure_logo_requested(&mut unknown, ImageKind::Corporation, 9999999);
        assert!(unknown.portrait_requests.is_empty());
    }

    #[test]
    fn same_numeric_id_in_two_kinds_uploads_two_textures() {
        let ctx = egui::Context::default();
        // Row id 1000166 doubles as corporation 1000166.
        let mut state = state_with_ids(&[1000166]);
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Character, 1000166),
            PortraitState::Ready(ready_image(8, 8)),
        );
        state.portraits.insert(
            (ImageKind::Corporation, 1000166),
            PortraitState::Ready(ready_image(8, 8)),
        );

        let portrait = cache
            .texture(&ctx, &state, ImageKind::Character, 1000166)
            .expect("portrait uploads");
        let logo = cache
            .texture(&ctx, &state, ImageKind::Corporation, 1000166)
            .expect("logo uploads");
        assert_eq!(cache.len(), 2);
        assert_ne!(portrait.id(), logo.id());
    }

    #[test]
    fn same_numeric_id_in_corporation_and_faction_uploads_two_textures() {
        let ctx = egui::Context::default();
        // State entries pin each kind to its own image; the cache
        // must upload the same number under two kinds as two
        // textures, never one shared upload.
        let mut state = state_with_ids(&[1]);
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Corporation, 500001),
            PortraitState::Ready(ready_image(8, 8)),
        );
        state.portraits.insert(
            (ImageKind::Faction, 500001),
            PortraitState::Ready(ready_image(8, 8)),
        );

        let corp = cache
            .texture(&ctx, &state, ImageKind::Corporation, 500001)
            .expect("corp uploads");
        let faction = cache
            .texture(&ctx, &state, ImageKind::Faction, 500001)
            .expect("faction uploads");
        assert_eq!(cache.len(), 2);
        assert_ne!(corp.id(), faction.id());
    }

    #[test]
    fn prune_is_kind_aware_for_corporation_logos() {
        let ctx = egui::Context::default();
        // Two rows share corporation 1000166 (the `test_row`
        // default); pruning to one such row keeps the logo.
        let mut state = state_with_ids(&[1, 2]);
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Corporation, 1000166),
            PortraitState::Ready(ready_image(8, 8)),
        );
        let uploaded = cache
            .texture(&ctx, &state, ImageKind::Corporation, 1000166)
            .expect("upload")
            .id();
        cache.prune(&state_with_ids(&[1]));
        assert_eq!(cache.len(), 1);
        assert_eq!(
            cache
                .texture(&ctx, &state, ImageKind::Corporation, 1000166)
                .expect("kept")
                .id(),
            uploaded
        );

        // Pruning to a state whose only row carries a different
        // corporation frees it; the next lookup re-uploads.
        let mut other_state = state_with_ids(&[1]);
        other_state.characters[0].corporation_id = 1000125;
        cache.prune(&other_state);
        assert_eq!(cache.len(), 0);
        assert_ne!(
            cache
                .texture(&ctx, &state, ImageKind::Corporation, 1000166)
                .expect("re-upload")
                .id(),
            uploaded
        );
    }

    fn bundle_with_faction_standing() -> CharacterDetailData {
        CharacterDetailData {
            attributes: Ok(CharacterAttributes::default()),
            implants: Ok(Vec::new()),
            clones: Ok(CharacterClones::default()),
            standings: Ok(vec![Standing {
                from_id: 500001,
                from_type: "faction".to_string(),
                standing: 3.25,
            }]),
            location: Ok(CharacterLocation::default()),
            ship: Ok(CharacterShip::default()),
            online: Ok(CharacterOnline::default()),
        }
    }

    #[test]
    fn prune_is_kind_aware_for_standings_faction_logos() {
        let ctx = egui::Context::default();
        // The bundle's faction standing is 500001's only backing:
        // prune retains the texture while the bundle is loaded and
        // frees it once the bundle is gone (character switch puts
        // `character_details` back to `Loading`).
        let mut state = state_with_ids(&[1]);
        state.character_details = LoadState::Ready(bundle_with_faction_standing());
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Faction, 500001),
            PortraitState::Ready(ready_image(8, 8)),
        );
        let uploaded = cache
            .texture(&ctx, &state, ImageKind::Faction, 500001)
            .expect("upload")
            .id();
        cache.prune(&state);
        assert_eq!(cache.len(), 1);
        assert_eq!(
            cache
                .texture(&ctx, &state, ImageKind::Faction, 500001)
                .expect("kept")
                .id(),
            uploaded
        );

        let mut loading = state_with_ids(&[1]);
        loading.character_details = LoadState::Loading;
        cache.prune(&loading);
        assert_eq!(cache.len(), 0);
        assert_ne!(
            cache
                .texture(&ctx, &state, ImageKind::Faction, 500001)
                .expect("re-upload")
                .id(),
            uploaded
        );
    }

    #[test]
    fn logo_texture_is_some_only_when_ready() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1]);
        let mut cache = PortraitImageCache::new();

        assert!(cache
            .texture(&ctx, &state, ImageKind::Corporation, 1000166)
            .is_none());
        state
            .portraits
            .insert((ImageKind::Corporation, 1000166), PortraitState::Loading);
        assert!(cache
            .texture(&ctx, &state, ImageKind::Corporation, 1000166)
            .is_none());
        state
            .portraits
            .insert((ImageKind::Corporation, 1000166), PortraitState::Failed);
        assert!(cache
            .texture(&ctx, &state, ImageKind::Corporation, 1000166)
            .is_none());
        state.portraits.insert(
            (ImageKind::Corporation, 1000166),
            PortraitState::Ready(ready_image(8, 8)),
        );
        assert!(cache
            .texture(&ctx, &state, ImageKind::Corporation, 1000166)
            .is_some());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn show_logo_runs_headless() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1]);
        let mut cache = PortraitImageCache::new();
        state.portraits.insert(
            (ImageKind::Corporation, 1000166),
            PortraitState::Ready(ready_image(8, 8)),
        );
        // Corporation 1000125 has no entry: the placeholder.
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                show_logo(
                    ui,
                    &mut cache,
                    &state,
                    ImageKind::Corporation,
                    1000166,
                    DETAIL_LOGO_PX,
                );
                show_logo(
                    ui,
                    &mut cache,
                    &state,
                    ImageKind::Corporation,
                    1000125,
                    DETAIL_LOGO_PX,
                );
            });
        });
        assert_eq!(cache.len(), 1, "only the Ready logo uploaded");
    }
}
