//! Mimir entry point: tracing init, tokio runtime, database open, egui.
//! Access and refresh tokens are never logged.

use std::io::Write;
use std::sync::{Arc, Mutex};

use mimir::app::shell::MimirApp;
use mimir::storage::db;

/// Writer that mirrors formatted log lines into the in-app log buffer.
struct BufferWriter(Arc<Mutex<Vec<String>>>);

impl Write for BufferWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
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
    let demo = std::env::args().any(|a| a == "--demo");
    let log_buffer: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    init_tracing(log_buffer.clone());
    tracing::info!("[STARTUP] Mimir starting demo={}", demo);

    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .ok();
    if runtime.is_none() {
        tracing::warn!("[STARTUP] tokio runtime failed to build; continuing UI-only");
    }

    // Open the database eagerly so schema errors surface at startup. The
    // connection itself is handed to builders via F2 repositories later.
    match db::open_db(&db::db_path()) {
        Ok(_) => tracing::info!(
            "[DB] startup database open ok path={}",
            db::db_path().display()
        ),
        Err(e) => tracing::warn!("[DB] startup database open failed: {}", e),
    }

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([1280.0, 800.0])
            .with_title("Mimir — EVE Online Companion"),
        ..Default::default()
    };

    eframe::run_native(
        "Mimir",
        options,
        Box::new(move |_cc| {
            tracing::info!("[STARTUP] egui frame created");
            Ok(Box::new(MimirApp::new(demo, log_buffer, runtime)))
        }),
    )
}
