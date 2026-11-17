//! Portrait rendering for the character surfaces (Characters list
//! and detail, Dashboard grid): upload each decoded portrait to an
//! egui texture exactly once per character, and draw the honest
//! initial placeholder for every other state. Fetch, cache, and
//! landing live in `crate::portraits` and `crate::app::state` /
//! `crate::app::shell`; this module only turns ready state into
//! widgets. The shell owns the `PortraitImageCache`: a
//! `TextureHandle` must outlive the frame that created it, so
//! textures can never be per-frame uploads.
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
use crate::portraits::initial_for_name;
use crate::storage::repositories::CharacterRow;

/// Render size of a list or grid-row portrait, in points. The
/// decoded image is 256px; views downscale it, never upscale.
pub const LIST_PORTRAIT_PX: f32 = 32.0;
/// Render size of the active-character detail portrait, in points.
pub const DETAIL_PORTRAIT_PX: f32 = 96.0;

/// One uploaded portrait: the decoded image it was built from
/// (identity check via `Arc::ptr_eq`) plus its live texture.
struct CachedTexture {
    source: Arc<image::DynamicImage>,
    handle: egui::TextureHandle,
}

/// Per-application portrait textures, owned by `MimirApp` and
/// passed into the character views. Upload happens once per
/// character image; a replaced image (remove and re-add) uploads
/// anew and never shows the old face.
#[derive(Default)]
pub struct PortraitImageCache {
    textures: HashMap<i64, CachedTexture>,
}

impl PortraitImageCache {
    /// An empty cache. Construction uploads nothing.
    pub fn new() -> Self {
        Self::default()
    }

    /// Drop textures for characters that no longer exist, freeing
    /// the GPU texture so a removed character's face cannot
    /// linger — and a later re-added character re-uploads.
    pub fn prune(&mut self, characters: &[CharacterRow]) {
        let before = self.textures.len();
        self.textures
            .retain(|id, _| characters.iter().any(|c| c.character_id == *id));
        if self.textures.len() != before {
            tracing::debug!(
                "[PORTRAIT] portrait textures pruned remaining={}",
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

    /// The texture for one character's `Ready` portrait, uploading
    /// the decoded image exactly once. `None` for every non-Ready
    /// state: only `Ready` for that exact character id renders an
    /// image, never a fabricated face, never another character's.
    pub fn texture(
        &mut self,
        ctx: &egui::Context,
        state: &AppState,
        character_id: i64,
    ) -> Option<egui::TextureHandle> {
        let image = match state.portrait_state(character_id) {
            PortraitState::Ready(image) => image,
            PortraitState::NotRequested | PortraitState::Loading | PortraitState::Failed => {
                return None;
            }
        };
        let replaced = match self.textures.get(&character_id) {
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
        let handle = ctx.load_texture(
            format!("portrait-{character_id}"),
            color,
            egui::TextureOptions::default(),
        );
        if replaced {
            tracing::info!(
                "[PORTRAIT] portrait texture replaced character_id={}",
                character_id
            );
        } else {
            tracing::info!(
                "[PORTRAIT] portrait texture uploaded character_id={} {width}x{height}",
                character_id
            );
        }
        self.textures.insert(
            character_id,
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
        state.portrait_state(character_id),
        PortraitState::NotRequested
    ) {
        state.request_portrait(character_id);
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
    if let Some(handle) = cache.texture(ui.ctx(), state, character_id) {
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

#[cfg(test)]
mod tests {
    use super::*;
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
        state.portraits.insert(2, PortraitState::Loading);
        state
            .portraits
            .insert(3, PortraitState::Ready(ready_image(8, 8)));
        state.portraits.insert(4, PortraitState::Failed);

        ensure_portrait_requested(&mut state, 1);
        assert_eq!(state.portrait_requests, vec![1]);
        assert!(matches!(state.portrait_state(1), PortraitState::Loading));

        // Loading, Ready, and Failed are all left alone: Failed in
        // particular never re-queues from the render path, so a
        // failed portrait cannot retry-loop at frame rate.
        ensure_portrait_requested(&mut state, 2);
        ensure_portrait_requested(&mut state, 3);
        ensure_portrait_requested(&mut state, 4);
        assert_eq!(state.portrait_requests, vec![1]);
        assert!(matches!(state.portrait_state(4), PortraitState::Failed));

        // Unknown ids queue nothing and fabricate no entry.
        ensure_portrait_requested(&mut state, 999);
        assert_eq!(state.portrait_requests, vec![1]);
    }

    #[test]
    fn prune_on_an_empty_cache_keeps_it_empty() {
        let mut cache = PortraitImageCache::new();
        assert!(cache.is_empty());
        cache.prune(&[]);
        cache.prune(&[test_row(1, "Test Pilot")]);
        assert!(cache.is_empty());
        assert_eq!(cache.len(), 0);
    }

    #[test]
    fn texture_is_none_until_ready() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1, 2, 3, 4]);
        let mut cache = PortraitImageCache::new();

        assert!(cache.texture(&ctx, &state, 1).is_none());
        state.portraits.insert(2, PortraitState::Loading);
        assert!(cache.texture(&ctx, &state, 2).is_none());
        state.portraits.insert(3, PortraitState::Failed);
        assert!(cache.texture(&ctx, &state, 3).is_none());
        state
            .portraits
            .insert(4, PortraitState::Ready(ready_image(8, 8)));
        assert!(cache.texture(&ctx, &state, 4).is_some());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn texture_uploads_once_per_image() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1]);
        let mut cache = PortraitImageCache::new();
        state
            .portraits
            .insert(1, PortraitState::Ready(ready_image(8, 8)));

        let first = cache.texture(&ctx, &state, 1).expect("ready uploads");
        let again = cache.texture(&ctx, &state, 1).expect("ready reuses");
        assert_eq!(first.id(), again.id(), "one upload per image");

        // A replaced image object for the same character uploads
        // anew instead of showing the old face.
        state
            .portraits
            .insert(1, PortraitState::Ready(ready_image(8, 8)));
        let replaced = cache.texture(&ctx, &state, 1).expect("replaced uploads");
        assert_ne!(first.id(), replaced.id());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn prune_frees_removed_characters_and_reuploads() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1, 2]);
        let mut cache = PortraitImageCache::new();
        for id in [1i64, 2] {
            state
                .portraits
                .insert(id, PortraitState::Ready(ready_image(8, 8)));
            let _ = cache.texture(&ctx, &state, id).expect("upload");
        }
        assert_eq!(cache.len(), 2);

        let kept_id = cache.texture(&ctx, &state, 1).expect("reuse").id();
        let old_id = cache.texture(&ctx, &state, 2).expect("reuse").id();
        cache.prune(&[test_row(1, "Test Pilot")]);
        assert_eq!(cache.len(), 1);

        // The still-listed character keeps its texture; the pruned
        // one re-uploads when it returns.
        assert_eq!(cache.texture(&ctx, &state, 1).expect("kept").id(), kept_id);
        assert_ne!(
            cache.texture(&ctx, &state, 2).expect("re-upload").id(),
            old_id
        );
        cache.prune(&[]);
        assert!(cache.is_empty());
        assert!(cache.texture(&ctx, &state, 1).is_some());
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn show_portrait_runs_headless() {
        let ctx = egui::Context::default();
        let mut state = state_with_ids(&[1, 2]);
        let mut cache = PortraitImageCache::new();
        state
            .portraits
            .insert(1, PortraitState::Ready(ready_image(8, 8)));
        let _ = ctx.run(egui::RawInput::default(), |ctx| {
            egui::CentralPanel::default().show(ctx, |ui| {
                show_portrait(ui, &mut cache, &state, 1, "Test Pilot", LIST_PORTRAIT_PX);
                show_portrait(ui, &mut cache, &state, 2, "Test Pilot", LIST_PORTRAIT_PX);
            });
        });
        assert_eq!(cache.len(), 1, "only the Ready portrait uploaded");
    }
}
