//! Mimir entry point: tracing init, tokio runtime, database open, egui.
//! Access and refresh tokens are never logged.

use std::io::Write;
use std::sync::{Arc, Mutex};

use mimir::app::shell::{Backends, MimirApp};
use mimir::app::state::View;
use mimir::auth::jwt_verify::JwtVerifier;
use mimir::auth::token_store::TokenStore;
use mimir::portraits::PortraitService;
use mimir::storage::db;
use mimir::EsiClient;

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

fn main() -> eframe::Result<()> {
    let args: Vec<String> = std::env::args().collect();
    let demo =
        mimir::demo::data::is_demo_requested(&args, std::env::var("MIMIR_DEMO").ok().as_deref());
    let initial_view = parse_view_arg(&args);
    let log_buffer: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    init_tracing(log_buffer.clone());
    tracing::info!(
        "[STARTUP] Mimir starting demo={} initial_view={:?}",
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
    let db_result = if demo {
        tracing::info!("[DEMO] using in-memory database; live database path untouched");
        db::open_in_memory()
    } else {
        db::open_db(&db::db_path())
    };
    let backends = match db_result {
        Ok(conn) => {
            if !demo {
                tracing::info!(
                    "[DB] startup database open ok path={}",
                    db::db_path().display()
                );
            }
            let token_store = Arc::new(TokenStore::new(db::app_data_dir()));
            // One shared verifier so login, step-up, and refresh see a
            // single JWKS cache. Construction makes no network call;
            // demo mode skips it entirely (zero verification calls).
            let jwt_verifier = if demo {
                tracing::debug!("[AUTH] JWT verifier skipped in demo mode");
                None
            } else {
                match JwtVerifier::new() {
                    Ok(verifier) => Some(Arc::new(verifier)),
                    Err(e) => {
                        tracing::warn!("[AUTH] JWT verifier construction failed: {}", e);
                        None
                    }
                }
            };
            let attach_verifier = |client: EsiClient| match &jwt_verifier {
                Some(verifier) => client.with_jwt_verifier(verifier.clone()),
                None => client,
            };
            // Portrait service construction performs no network or
            // disk I/O, so it runs in demo mode too; the shell
            // drain guarantees demo mode never spawns a fetch.
            let portraits = Arc::new(PortraitService::new(db::app_cache_dir()));
            match EsiClient::new() {
                Ok(client) => Some(Backends {
                    esi: Arc::new(attach_verifier(
                        client.with_token_store(token_store.clone()),
                    )),
                    token_store,
                    db: Arc::new(Mutex::new(conn)),
                    jwt_verifier,
                    portraits,
                }),
                Err(e) => {
                    tracing::warn!("[ESI] client construction failed: {}", e);
                    Some(Backends {
                        esi: Arc::new(attach_verifier(EsiClient::default())),
                        token_store,
                        db: Arc::new(Mutex::new(conn)),
                        jwt_verifier,
                        portraits,
                    })
                }
            }
        }
        Err(e) => {
            tracing::warn!("[DB] startup database open failed: {}", e);
            None
        }
    };

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1280.0, 800.0])
            .with_title("Mimir — EVE Online Companion"),
        ..Default::default()
    };

    eframe::run_native(
        "Mimir",
        options,
        Box::new(move |cc| {
            tracing::info!("[STARTUP] egui frame created");
            mimir::ui::theme::apply(&cc.egui_ctx);
            let mut app = MimirApp::new(demo, log_buffer, runtime, backends);
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
}
