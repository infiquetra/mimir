//! Alidade entry point: tracing init, tokio runtime, database open, egui.
//! Access and refresh tokens are never logged.

use std::io::Write;
use std::sync::{Arc, Mutex};

use mimir::app::shell::{Backends, MimirApp};
use mimir::app::state::View;
use mimir::auth::token_store::TokenStore;
use mimir::portraits::PortraitService;
use mimir::storage::db;
use mimir::EsiClient;

/// User-facing desktop application name. The crate, binary, and
/// repository slug stay `mimir`; only window chrome and `.app`
/// packaging carry the Alidade brand.
const APP_DISPLAY_NAME: &str = "Alidade";

/// Native window title shown in desktop chrome.
fn window_title() -> &'static str {
    "Alidade — EVE Online Companion"
}

/// Apply platform window-chrome settings to the root viewport:
/// on macOS the content view fills the window under a hidden
/// titlebar (the shell clears the traffic lights with
/// `mimir::ui::theme::traffic_light_inset`); elsewhere native
/// chrome is unchanged.
#[cfg(target_os = "macos")]
fn apply_platform_chrome(viewport: egui::ViewportBuilder) -> egui::ViewportBuilder {
    tracing::debug!(
        "[STARTUP] macOS chrome applied: fullsize_content_view=true titlebar_shown=false title_shown=false"
    );
    viewport
        .with_fullsize_content_view(true)
        .with_titlebar_shown(false)
        .with_title_shown(false)
}

/// Apply platform window-chrome settings to the root viewport;
/// a no-op off macOS.
#[cfg(not(target_os = "macos"))]
fn apply_platform_chrome(viewport: egui::ViewportBuilder) -> egui::ViewportBuilder {
    tracing::debug!(
        "[STARTUP] native chrome applied: platform default (no macOS titlebar overrides)"
    );
    viewport
}

/// Build native options; demo mode disables eframe window-state
/// persistence so `--demo` writes no window geometry to disk.
fn native_options(viewport: egui::ViewportBuilder, demo: bool) -> eframe::NativeOptions {
    let mut options = eframe::NativeOptions {
        viewport,
        ..Default::default()
    };
    if demo {
        options.persist_window = false;
        tracing::debug!("[STARTUP] demo mode: eframe persist_window=false (no disk window state)");
    }
    options
}

/// Parse `--view <name>` or `--view=<name>` from CLI arguments.
fn parse_view_arg(args: &[String]) -> Option<View> {
    let mut iter = args.iter().skip(1);
    while let Some(arg) = iter.next() {
        let raw = if arg == "--view" {
            match iter.next() {
                Some(val) => val.as_str(),
                None => {
                    tracing::warn!("[STARTUP] --view flag missing value");
                    return None;
                }
            }
        } else if let Some(val) = arg.strip_prefix("--view=") {
            val
        } else {
            continue;
        };
        if let Some(view) = View::from_cli_name(raw) {
            return Some(view);
        }
        tracing::warn!("[STARTUP] ignoring unknown --view value {:?}", raw);
    }
    None
}

/// Writer that mirrors formatted log lines into the in-app log buffer.
struct BufferWriter(Arc<Mutex<Vec<String>>>);

impl Write for BufferWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        // Mirror to stderr so headless and CLI runs still produce logs.
        let _ = std::io::stderr().write_all(buf);
        let text = String::from_utf8_lossy(buf);
        if let Ok(mut lines) = self.0.lock() {
            for line in text.lines() {
                if !line.trim().is_empty() {
                    lines.push(line.to_string());
                }
            }
            if lines.len() > 500 {
                let excess = lines.len() - 500;
                lines.drain(0..excess);
            }
        }
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

struct BufferMakeWriter(Arc<Mutex<Vec<String>>>);

impl<'a> tracing_subscriber::fmt::MakeWriter<'a> for BufferMakeWriter {
    type Writer = BufferWriter;

    fn make_writer(&'a self) -> Self::Writer {
        BufferWriter(self.0.clone())
    }
}

fn init_tracing(log_buffer: Arc<Mutex<Vec<String>>>) {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("mimir=debug,info"));
    // Console layer plus in-app buffer. `try_init` keeps repeat calls safe.
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_writer(BufferMakeWriter(log_buffer))
        .with_ansi(false)
        .try_init();
}

const APP_ICON_PNG: &[u8] = include_bytes!("../assets/macos/AppIcon.png");

fn load_app_icon() -> Option<Arc<egui::IconData>> {
    match image::load_from_memory(APP_ICON_PNG) {
        Ok(img) => {
            let rgba = img.to_rgba8();
            let (width, height) = rgba.dimensions();
            Some(Arc::new(egui::IconData {
                rgba: rgba.into_raw(),
                width,
                height,
            }))
        }
        Err(e) => {
            tracing::warn!("[STARTUP] failed to decode embedded app icon: {}", e);
            None
        }
    }
}

fn main() -> eframe::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let demo =
        mimir::demo::data::is_demo_requested(&args, std::env::var("MIMIR_DEMO").ok().as_deref());
    let initial_view = parse_view_arg(&args);
    let log_buffer: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    init_tracing(log_buffer.clone());
    tracing::info!(
        "[STARTUP] Alidade starting demo={} initial_view={:?}",
        demo,
        initial_view.map(|v| v.label())
    );

    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .ok();
    if runtime.is_none() {
        tracing::warn!("[STARTUP] tokio runtime failed to build; continuing UI-only");
    }

    // Open the database eagerly so schema errors surface at startup, then
    // hand the shared connection plus token store and ESI client to the app.
    // Demo mode uses an isolated in-memory database so live storage is untouched.
    // Token values are never logged.
    let backends = if demo {
        tracing::info!("[DEMO] using in-memory database; live database path untouched");
        match db::open_in_memory() {
            Ok(conn) => {
                let token_store = Arc::new(TokenStore::file_only(
                    std::env::temp_dir().join("mimir-demo-unused-tokens.json"),
                ));
                let portraits = Arc::new(PortraitService::new(db::app_cache_dir()));
                let esi = match EsiClient::new() {
                    Ok(client) => client.with_token_store(token_store.clone()),
                    Err(e) => {
                        tracing::warn!("[ESI] client construction failed: {}", e);
                        EsiClient::default().with_token_store(token_store.clone())
                    }
                };
                Some(Backends {
                    esi: Arc::new(esi),
                    token_store,
                    db: Arc::new(Mutex::new(conn)),
                    jwt_verifier: None,
                    portraits,
                })
            }
            Err(e) => {
                tracing::warn!("[DB] in-memory demo database open failed: {}", e);
                None
            }
        }
    } else {
        Backends::open_live()
    };

    let mut viewport = apply_platform_chrome(
        egui::ViewportBuilder::default()
            .with_inner_size([1280.0, 800.0])
            .with_title(window_title()),
    );
    if let Some(icon) = load_app_icon() {
        viewport = viewport.with_icon(icon);
    }
    let options = native_options(viewport, demo);

    eframe::run_native(
        APP_DISPLAY_NAME,
        options,
        Box::new(move |cc| {
            tracing::info!("[STARTUP] egui frame created");
            mimir::ui::theme::apply(&cc.egui_ctx);
            let mut app = MimirApp::new(demo, log_buffer, runtime, backends);
            app.attach_egui_ctx(cc.egui_ctx.clone());
            if let Some(view) = initial_view {
                app.apply_initial_view(view);
            }
            Ok(Box::new(app))
        }),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_view_arg_supports_space_and_equals_forms() {
        let s = |v: &[&str]| v.iter().map(|x| (*x).to_string()).collect::<Vec<_>>();
        assert_eq!(
            parse_view_arg(&s(&["mimir", "--demo", "--view", "fittings"])),
            Some(View::Fittings)
        );
        assert_eq!(
            parse_view_arg(&s(&["mimir", "--view=Planets"])),
            Some(View::Planets)
        );
        assert_eq!(
            parse_view_arg(&s(&["mimir", "--view", "PI"])),
            Some(View::Planets)
        );
        assert_eq!(parse_view_arg(&s(&["mimir", "--view", "unknown"])), None);
        assert_eq!(parse_view_arg(&s(&["mimir", "--view"])), None);
        assert_eq!(parse_view_arg(&s(&["mimir"])), None);
    }

    #[test]
    fn embedded_app_icon_decodes_to_1024_rgba() {
        let icon = load_app_icon().expect("embedded app icon decodes");
        assert_eq!(icon.width, 1024);
        assert_eq!(icon.height, 1024);
        assert_eq!(icon.rgba.len(), 1024 * 1024 * 4);
    }

    #[test]
    fn alidade_window_title_and_display_name() {
        assert_eq!(APP_DISPLAY_NAME, "Alidade");
        assert_eq!(window_title(), "Alidade — EVE Online Companion");
        let viewport =
            apply_platform_chrome(egui::ViewportBuilder::default().with_title(window_title()));
        assert_eq!(viewport.title.as_deref(), Some(window_title()));
    }

    #[test]
    fn macos_chrome_hides_titlebar_and_clears_traffic_lights() {
        let viewport = apply_platform_chrome(egui::ViewportBuilder::default());
        #[cfg(target_os = "macos")]
        {
            assert_eq!(viewport.fullsize_content_view, Some(true));
            assert_eq!(viewport.titlebar_shown, Some(false));
            assert_eq!(viewport.title_shown, Some(false));
            assert_eq!(mimir::ui::theme::traffic_light_inset(), 78.0);
        }
        #[cfg(not(target_os = "macos"))]
        {
            assert_eq!(viewport.fullsize_content_view, None);
            assert_eq!(viewport.title_shown, None);
            assert_eq!(mimir::ui::theme::traffic_light_inset(), 0.0);
        }
    }

    #[test]
    fn demo_disables_persist_window_live_keeps_it_on() {
        let demo_options = native_options(egui::ViewportBuilder::default(), true);
        assert!(!demo_options.persist_window);
        let live_options = native_options(egui::ViewportBuilder::default(), false);
        assert!(live_options.persist_window);
    }

    #[test]
    fn parse_view_arg_ignores_macos_finder_psn_argument() {
        let s = |v: &[&str]| v.iter().map(|x| (*x).to_string()).collect::<Vec<_>>();
        assert_eq!(parse_view_arg(&s(&["mimir", "-psn_0_123456"])), None);
        assert_eq!(
            parse_view_arg(&s(&["mimir", "-psn_0_123456", "--view", "market"])),
            Some(View::Market)
        );
    }
}
