//! `notify`-backed tailing of EVE `Gamelogs/*.txt` (UTF-8) and
//! `Chatlogs/*.txt` (UTF-16LE BOM).
//!
//! The tailer is synchronous and deterministic so tests can drive it
//! directly; in the app a dedicated worker thread owns it (see
//! `src/app/shell.rs`) and forwards each line as
//! `BackendMsg::LogEvent(LogEvent)` through the existing
//! `BackendSender`, which wakes the UI with `ctx.request_repaint()`.
//! No parsing or file I/O happens on the UI thread.
//!
//! Missing log folders are a clean status ([`DaemonStatus::LogsMissing`]),
//! never an error loop. Truncation/rotation (`len < offset`, or a new
//! Unix `(dev, ino)` for the same path) resets the tracked offset to 0
//! without panicking. Buffers are bounded: at most a 4 KiB header
//! window is read for files present at startup, at most 256 KiB is
//! read per poll per file, and a pending partial line is capped at
//! 64 KiB (overlong lines are dropped and counted).

use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{channel, Receiver, RecvTimeoutError};
use std::time::{Duration, Instant};

#[cfg(unix)]
use std::os::unix::fs::MetadataExt;

use notify::{RecommendedWatcher, RecursiveMode, Watcher};

use super::utf16_chatlog::{
    decode_utf16le, decode_utf16le_bom, parse_chatlog_header, parse_chatlog_line, ChatlogHeader,
};

/// Bytes read from the start of a pre-existing file to learn its
/// `Listener:` / `Channel Name:` header; the body is never read.
pub const HEADER_WINDOW_BYTES: usize = 4 * 1024;
/// Maximum bytes read from one file in a single poll; any remainder
/// is picked up by the next event or fallback scan.
pub const READ_CHUNK_CAP_BYTES: u64 = 256 * 1024;
/// Maximum bytes held for one unterminated line; beyond this the
/// partial line is dropped and counted.
pub const PENDING_CAP_BYTES: usize = 64 * 1024;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogSource {
    GameLog,
    ChatLog,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogEventKind {
    Combat,
    Notify,
    Mining,
    Chat,
    Other,
}

/// One typed log line. All display strings are already text from the
/// log file (character/channel names); no raw numeric EVE IDs are
/// surfaced — channel IDs in headers are deliberately not stored.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LogEvent {
    pub source: LogSource,
    pub kind: LogEventKind,
    pub timestamp: Option<String>,
    pub listener: Option<String>,
    pub channel: Option<String>,
    pub speaker: Option<String>,
    pub body: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DaemonStatus {
    Watching,
    LogsMissing,
    WatchFailed,
}

impl DaemonStatus {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Watching => "Watching EVE logs",
            Self::LogsMissing => "EVE logs folder not found yet",
            Self::WatchFailed => "EVE logs watcher unavailable",
        }
    }
}

/// Platform default EVE logs directory (`~/Documents/EVE/logs` via
/// the `directories` crate). Pure path computation: creates nothing.
pub fn default_eve_logs_dir() -> PathBuf {
    if let Some(dirs) = directories::UserDirs::new() {
        if let Some(doc) = dirs.document_dir() {
            return doc.join("EVE").join("logs");
        }
        return dirs.home_dir().join("Documents").join("EVE").join("logs");
    }
    PathBuf::from("Documents/EVE/logs")
}

fn parse_timestamped(rest_line: &str) -> Option<(String, &str)> {
    let after = rest_line.trim_start().strip_prefix('[')?;
    let (ts, rest) = after.split_once(']')?;
    Some((ts.trim().to_string(), rest.trim()))
}

/// Parse one gamelog body line such as
/// `[ 2026.11.28 10:01:02 ] (combat) Your weapon hits ...`.
pub fn parse_gamelog_line(line: &str, listener: Option<&str>) -> Option<LogEvent> {
    let (timestamp, rest) = parse_timestamped(line)?;
    let (kind, body) = if let Some(after) = rest.strip_prefix('(') {
        if let Some((tag, body)) = after.split_once(')') {
            let kind = match tag.trim() {
                "combat" => LogEventKind::Combat,
                "notify" => LogEventKind::Notify,
                "mining" => LogEventKind::Mining,
                _ => LogEventKind::Other,
            };
            (kind, body.trim().to_string())
        } else {
            (LogEventKind::Other, rest.to_string())
        }
    } else {
        (LogEventKind::Other, rest.to_string())
    };
    Some(LogEvent {
        source: LogSource::GameLog,
        kind,
        timestamp: Some(timestamp),
        listener: listener.map(str::to_string),
        channel: None,
        speaker: None,
        body,
    })
}

#[derive(Default)]
struct FileState {
    offset: u64,
    pending: Vec<u8>,
    seen: bool,
    bom_stripped: bool,
    listener: Option<String>,
    channel: Option<String>,
    chat_header: ChatlogHeader,
    /// Unix `(dev, ino)` of the file at the tracked offset, used to
    /// detect replacement (rotation) even when the new file is at
    /// least as long as the old offset. `None` off Unix.
    file_id: Option<(u64, u64)>,
}

fn file_id_of(metadata: &std::fs::Metadata) -> Option<(u64, u64)> {
    #[cfg(unix)]
    {
        Some((metadata.dev(), metadata.ino()))
    }
    #[cfg(not(unix))]
    {
        let _ = metadata;
        None
    }
}

#[derive(Default)]
struct IngestStats {
    dropped_lines: u64,
    invalid_utf8_lines: u64,
}

/// Incremental tailer over both log folders. Synchronous `poll_once`
/// is the deterministic core; the `notify` watcher only wakes it.
pub struct LogTailer {
    gamelogs_dir: PathBuf,
    chatlogs_dir: PathBuf,
    files: HashMap<PathBuf, FileState>,
    status: DaemonStatus,
    missing_logged: bool,
    /// True until the first directory scan completes. Files first
    /// seen while this is set are pre-existing history (header only);
    /// files first seen afterwards are read from offset 0.
    initial_scan_pending: bool,
    dropped_lines: u64,
    invalid_utf8_lines: u64,
}

impl LogTailer {
    pub fn new(gamelogs_dir: &Path, chatlogs_dir: &Path) -> Self {
        let status = if gamelogs_dir.is_dir() || chatlogs_dir.is_dir() {
            DaemonStatus::Watching
        } else {
            DaemonStatus::LogsMissing
        };
        Self {
            gamelogs_dir: gamelogs_dir.to_path_buf(),
            chatlogs_dir: chatlogs_dir.to_path_buf(),
            files: HashMap::new(),
            status,
            missing_logged: false,
            initial_scan_pending: true,
            dropped_lines: 0,
            invalid_utf8_lines: 0,
        }
    }

    pub fn status(&self) -> &DaemonStatus {
        &self.status
    }

    /// Lines dropped because a pending partial line exceeded the cap.
    pub fn dropped_lines(&self) -> u64 {
        self.dropped_lines
    }

    /// Gamelog lines skipped because they were not valid UTF-8.
    pub fn invalid_utf8_lines(&self) -> u64 {
        self.invalid_utf8_lines
    }

    /// Number of files currently tracked (deleted files are pruned).
    pub fn tracked_file_count(&self) -> usize {
        self.files.len()
    }

    fn scan_dir(&self, dir: &Path) -> Vec<PathBuf> {
        let Ok(entries) = std::fs::read_dir(dir) else {
            return Vec::new();
        };
        let mut paths: Vec<PathBuf> = entries
            .filter_map(|e| e.ok().map(|e| e.path()))
            .filter(|p| {
                p.extension()
                    .map(|e| e.eq_ignore_ascii_case("txt"))
                    .unwrap_or(false)
            })
            .collect();
        paths.sort();
        paths
    }

    /// Poll every known file once; returns only newly completed lines.
    pub fn poll_once(&mut self) -> Vec<LogEvent> {
        let game_files = self.scan_dir(&self.gamelogs_dir);
        let chat_files = self.scan_dir(&self.chatlogs_dir);
        // Prune deleted files from the tracking map on every scan.
        let known: std::collections::HashSet<&Path> = game_files
            .iter()
            .chain(chat_files.iter())
            .map(PathBuf::as_path)
            .collect();
        self.files.retain(|path, _| known.contains(path.as_path()));
        if game_files.is_empty() && chat_files.is_empty() {
            if self.status != DaemonStatus::WatchFailed {
                self.status = DaemonStatus::LogsMissing;
            }
            if !self.missing_logged {
                tracing::info!("[DAEMON] log tailer status=missing folders_found=0");
                self.missing_logged = true;
            }
            self.initial_scan_pending = false;
            return Vec::new();
        }
        self.status = DaemonStatus::Watching;
        self.missing_logged = false;
        let mut events = Vec::new();
        for path in game_files {
            events.extend(self.poll_file(&path, LogSource::GameLog));
        }
        for path in chat_files {
            events.extend(self.poll_file(&path, LogSource::ChatLog));
        }
        self.initial_scan_pending = false;
        if !events.is_empty() {
            tracing::debug!("[DAEMON] log events emitted count={}", events.len());
        }
        events
    }

    /// Poll only the given paths (the files a `notify` event named).
    /// Unknown or directory paths fall back to a full scan.
    pub fn poll_paths(&mut self, paths: &[PathBuf]) -> Vec<LogEvent> {
        tracing::debug!("[DAEMON] log tailer poll paths={}", paths.len());
        let mut events = Vec::new();
        let mut needs_full_scan = paths.is_empty();
        for path in paths {
            if !path.exists() {
                self.files.remove(path);
                continue;
            }
            let is_txt = path
                .extension()
                .map(|e| e.eq_ignore_ascii_case("txt"))
                .unwrap_or(false);
            if !is_txt {
                needs_full_scan = true;
                continue;
            }
            let source = if path.starts_with(&self.chatlogs_dir) {
                LogSource::ChatLog
            } else if path.starts_with(&self.gamelogs_dir) {
                LogSource::GameLog
            } else {
                needs_full_scan = true;
                continue;
            };
            events.extend(self.poll_file(path, source));
        }
        if needs_full_scan {
            events.extend(self.poll_once());
        } else if !events.is_empty() {
            self.status = DaemonStatus::Watching;
            tracing::debug!("[DAEMON] log events emitted count={}", events.len());
        }
        events
    }

    fn poll_file(&mut self, path: &Path, source: LogSource) -> Vec<LogEvent> {
        let Ok(metadata) = std::fs::metadata(path) else {
            self.files.remove(path);
            return Vec::new();
        };
        let len = metadata.len();
        let current_id = file_id_of(&metadata);
        let mut stats = IngestStats::default();
        let events = {
            let state = self.files.entry(path.to_path_buf()).or_default();
            // Rotation by replacement: same path, different file.
            let replaced = match (state.file_id, current_id) {
                (Some(old), Some(new)) => old != new,
                _ => false,
            };
            if replaced || len < state.offset {
                tracing::debug!("[DAEMON] log truncated offset_reset=0 source={source:?}");
                state.offset = 0;
                state.pending.clear();
                state.bom_stripped = false;
                state.listener = None;
                state.channel = None;
                state.chat_header = ChatlogHeader::default();
                // Replacement content is new: emit it, never suppress.
                state.seen = true;
            }
            state.file_id = current_id;
            if !state.seen && self.initial_scan_pending {
                // Pre-existing file: learn the header from a bounded
                // window only, then jump to end-of-file. No body read.
                Self::init_from_header(state, path, source, len);
                Vec::new()
            } else if len == state.offset {
                state.seen = true;
                Vec::new()
            } else {
                let Ok(mut file) = File::open(path) else {
                    return Vec::new();
                };
                if file.seek(SeekFrom::Start(state.offset)).is_err() {
                    return Vec::new();
                }
                let mut bytes = Vec::new();
                let read_result = file.take(READ_CHUNK_CAP_BYTES).read_to_end(&mut bytes);
                if read_result.is_err() {
                    return Vec::new();
                }
                state.offset = state.offset.saturating_add(bytes.len() as u64);
                // Files reaching here are not pre-existing history
                // (that case is handled above): emit from offset 0.
                let emit = true;
                let (events, file_stats) = match source {
                    LogSource::GameLog => Self::ingest_game(state, &bytes, emit),
                    LogSource::ChatLog => Self::ingest_chat(state, &bytes, emit),
                };
                stats = file_stats;
                state.seen = true;
                events
            }
        };
        self.dropped_lines = self.dropped_lines.saturating_add(stats.dropped_lines);
        self.invalid_utf8_lines = self
            .invalid_utf8_lines
            .saturating_add(stats.invalid_utf8_lines);
        events
    }

    /// Learn `Listener:` / `Channel Name:` from at most the first
    /// [`HEADER_WINDOW_BYTES`] of a pre-existing file and set the
    /// offset to end-of-file without reading or emitting the body.
    fn init_from_header(state: &mut FileState, path: &Path, source: LogSource, len: u64) {
        state.offset = len;
        state.pending.clear();
        state.seen = true;
        let Ok(file) = File::open(path) else {
            return;
        };
        let mut window = Vec::new();
        if file
            .take(HEADER_WINDOW_BYTES as u64)
            .read_to_end(&mut window)
            .is_err()
        {
            return;
        }
        match source {
            LogSource::GameLog => {
                let text = String::from_utf8_lossy(&window);
                for line in text.lines() {
                    let trimmed = line.trim();
                    if let Some(value) = trimmed.strip_prefix("Listener:") {
                        state.listener = Some(value.trim().to_string());
                    }
                }
            }
            LogSource::ChatLog => {
                state.bom_stripped = true;
                if let Ok(text) = decode_utf16le_bom(&window) {
                    let header = parse_chatlog_header(&text);
                    if header.listener.is_some() {
                        state.listener = header.listener.clone();
                    }
                    if header.channel_name.is_some() {
                        state.channel = header.channel_name.clone();
                    }
                    state.chat_header = header;
                }
            }
        }
        tracing::debug!(
            "[DAEMON] log header learned source={source:?} listener_present={} channel_present={}",
            state.listener.is_some(),
            state.channel.is_some()
        );
    }

    fn ingest_game(
        state: &mut FileState,
        bytes: &[u8],
        emit: bool,
    ) -> (Vec<LogEvent>, IngestStats) {
        state.pending.extend_from_slice(bytes);
        let mut stats = IngestStats::default();
        // Pending cap: an unterminated line may not grow without bound.
        while state.pending.len() > PENDING_CAP_BYTES
            && !state.pending[..PENDING_CAP_BYTES].contains(&b'\n')
        {
            match state.pending.iter().position(|b| *b == b'\n') {
                Some(pos) => {
                    state.pending.drain(..=pos);
                }
                None => state.pending.clear(),
            }
            stats.dropped_lines = stats.dropped_lines.saturating_add(1);
            tracing::debug!("[DAEMON] log overlong line dropped source=GameLog");
        }
        let mut events = Vec::new();
        // Single pass with a cursor; one drain per batch, not per line.
        let mut cursor = 0usize;
        while let Some(rel) = state.pending[cursor..].iter().position(|b| *b == b'\n') {
            let pos = cursor + rel;
            let line_bytes = state.pending[cursor..pos].to_vec();
            cursor = pos + 1;
            let Ok(line) = String::from_utf8(line_bytes) else {
                stats.invalid_utf8_lines = stats.invalid_utf8_lines.saturating_add(1);
                tracing::debug!("[DAEMON] log invalid utf8 line counted source=GameLog");
                continue;
            };
            let line = line.trim_end_matches(['\r', '\n']);
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("---") {
                continue;
            }
            if let Some(value) = trimmed.strip_prefix("Listener:") {
                state.listener = Some(value.trim().to_string());
                continue;
            }
            if trimmed == "Gamelog"
                || trimmed.starts_with("Session Started:")
                || trimmed.starts_with("Session started:")
            {
                continue;
            }
            if !emit {
                continue;
            }
            if let Some(event) = parse_gamelog_line(line, state.listener.as_deref()) {
                events.push(event);
            } else {
                events.push(LogEvent {
                    source: LogSource::GameLog,
                    kind: LogEventKind::Other,
                    timestamp: None,
                    listener: state.listener.clone(),
                    channel: None,
                    speaker: None,
                    body: trimmed.to_string(),
                });
            }
        }
        state.pending.drain(..cursor);
        (events, stats)
    }

    fn ingest_chat(
        state: &mut FileState,
        bytes: &[u8],
        emit: bool,
    ) -> (Vec<LogEvent>, IngestStats) {
        state.pending.extend_from_slice(bytes);
        let mut stats = IngestStats::default();
        if !state.bom_stripped && state.pending.starts_with(&[0xFF, 0xFE]) {
            state.pending.drain(..2);
            state.bom_stripped = true;
        } else if !state.bom_stripped && state.pending.len() >= 2 {
            state.bom_stripped = true;
        }
        while state.pending.len() > PENDING_CAP_BYTES {
            let mut found = false;
            let mut i = 0usize;
            while i + 1 < state.pending.len() {
                if state.pending[i] == 0x0A && state.pending[i + 1] == 0x00 {
                    found = true;
                    break;
                }
                i += 2;
            }
            if found && i < PENDING_CAP_BYTES {
                break;
            }
            if found {
                state.pending.drain(..i + 2);
            } else {
                state.pending.clear();
            }
            stats.dropped_lines = stats.dropped_lines.saturating_add(1);
            tracing::debug!("[DAEMON] log overlong line dropped source=ChatLog");
        }
        let mut events = Vec::new();
        // UTF-16LE newline is 0x0A 0x00 at an even offset. Single
        // pass with a cursor; one drain per batch, not per line.
        let mut cursor = 0usize;
        loop {
            let mut found: Option<usize> = None;
            let mut i = cursor;
            while i + 1 < state.pending.len() {
                if state.pending[i] == 0x0A && state.pending[i + 1] == 0x00 {
                    found = Some(i);
                    break;
                }
                i += 2;
            }
            let Some(pos) = found else { break };
            let line_bytes = state.pending[cursor..pos].to_vec();
            cursor = pos + 2;
            let Ok(line) = decode_utf16le(&line_bytes) else {
                continue;
            };
            let line = line.trim_end_matches(['\r', '\n']);
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("---") {
                continue;
            }
            let header = parse_chatlog_header(line);
            if header.listener.is_some() {
                state.chat_header.listener = header.listener.clone();
                state.listener = header.listener;
            }
            if header.channel_name.is_some() {
                state.chat_header.channel_name = header.channel_name.clone();
                state.channel = header.channel_name;
            }
            if header.session_started.is_some() {
                state.chat_header.session_started = header.session_started;
            }
            if trimmed.starts_with("Channel ID:")
                || trimmed.starts_with("Channel Name:")
                || trimmed.starts_with("Listener:")
                || trimmed.starts_with("Session started:")
                || trimmed.starts_with("Session Started:")
            {
                continue;
            }
            if !emit {
                continue;
            }
            if let Some(msg) = parse_chatlog_line(line, &state.chat_header) {
                events.push(LogEvent {
                    source: LogSource::ChatLog,
                    kind: LogEventKind::Chat,
                    timestamp: Some(msg.timestamp),
                    listener: msg.listener,
                    channel: msg.channel_name,
                    speaker: Some(msg.speaker),
                    body: msg.body,
                });
            }
        }
        state.pending.drain(..cursor);
        (events, stats)
    }
}

/// `notify`-backed watcher wrapping [`LogTailer`]. On macOS the
/// recommended watcher is FSEvents; elsewhere it is the platform best.
/// This type is owned by the shell's log-worker thread in the app;
/// tests may also drive it directly.
pub struct LogWatcher {
    tailer: LogTailer,
    _watcher: Option<RecommendedWatcher>,
    rx: Option<Receiver<Result<notify::Event, notify::Error>>>,
    status: DaemonStatus,
}

impl LogWatcher {
    pub fn start(gamelogs_dir: &Path, chatlogs_dir: &Path) -> Self {
        let mut tailer = LogTailer::new(gamelogs_dir, chatlogs_dir);
        // Initial scan: pre-existing files contribute headers only.
        let _initial = tailer.poll_once();
        if !gamelogs_dir.is_dir() && !chatlogs_dir.is_dir() {
            tracing::info!("[DAEMON] log watcher status=missing folders_found=0");
            return Self {
                tailer,
                _watcher: None,
                rx: None,
                status: DaemonStatus::LogsMissing,
            };
        }
        let (tx, rx) = channel();
        let watcher = notify::recommended_watcher(move |res| {
            let _ = tx.send(res);
        });
        match watcher {
            Ok(mut watcher) => {
                let mut failed = false;
                for dir in [gamelogs_dir, chatlogs_dir] {
                    if dir.is_dir() && watcher.watch(dir, RecursiveMode::NonRecursive).is_err() {
                        failed = true;
                    }
                }
                if failed {
                    tracing::warn!("[DAEMON] log watcher status=watch_failed");
                    Self {
                        tailer,
                        _watcher: None,
                        rx: None,
                        status: DaemonStatus::WatchFailed,
                    }
                } else {
                    tracing::info!("[DAEMON] log watcher status=watching");
                    Self {
                        tailer,
                        _watcher: Some(watcher),
                        rx: Some(rx),
                        status: DaemonStatus::Watching,
                    }
                }
            }
            Err(_) => {
                tracing::warn!("[DAEMON] log watcher status=watch_failed");
                Self {
                    tailer,
                    _watcher: None,
                    rx: None,
                    status: DaemonStatus::WatchFailed,
                }
            }
        }
    }

    pub fn status(&self) -> &DaemonStatus {
        &self.status
    }

    pub fn tailer(&self) -> &LogTailer {
        &self.tailer
    }

    /// Full rescan (worker fallback and tests). Reads every file.
    pub fn poll_once(&mut self) -> Vec<LogEvent> {
        if let Some(rx) = &self.rx {
            while rx.try_recv().is_ok() {}
        }
        let events = self.tailer.poll_once();
        self.status = self.tailer.status().clone();
        events
    }

    /// Block up to `timeout` for a filesystem notification, then read
    /// only the files that notification named. A timeout returns no
    /// events without touching the filesystem, so a missing or quiet
    /// logs folder never wakes the caller in a loop. When no OS
    /// watcher exists this simply waits out the timeout.
    pub fn poll_notified(&mut self, timeout: Duration) -> Vec<LogEvent> {
        let Some(rx) = &self.rx else {
            std::thread::sleep(timeout);
            return Vec::new();
        };
        match rx.recv_timeout(timeout) {
            Ok(Ok(event)) => {
                let mut paths: Vec<PathBuf> = event.paths.clone();
                while let Ok(Ok(extra)) = rx.try_recv() {
                    paths.extend(extra.paths.iter().cloned());
                }
                tracing::debug!("[DAEMON] log notify wake paths={}", paths.len());
                let events = self.tailer.poll_paths(&paths);
                self.status = self.tailer.status().clone();
                events
            }
            Ok(Err(_)) => Vec::new(),
            Err(RecvTimeoutError::Timeout) => Vec::new(),
            Err(RecvTimeoutError::Disconnected) => Vec::new(),
        }
    }

    /// Wait up to `timeout` for at least one new event, polling the
    /// tailer at a short interval so delivery stays well under 250 ms.
    pub fn drain_for(&mut self, timeout: Duration) -> Vec<LogEvent> {
        let start = Instant::now();
        loop {
            let events = self.poll_once();
            if !events.is_empty() || start.elapsed() >= timeout {
                return events;
            }
            std::thread::sleep(Duration::from_millis(5));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_game_header(dir: &Path) -> PathBuf {
        let path = dir.join("20261128_100000.txt");
        let mut f = File::create(&path).unwrap();
        writeln!(
            f,
            "------------------------------------------------------------"
        )
        .unwrap();
        writeln!(f, "  Gamelog").unwrap();
        writeln!(f, "  Listener:  Jane Capsuleer").unwrap();
        writeln!(f, "  Session Started: 2026.11.28 10:00:00").unwrap();
        writeln!(
            f,
            "------------------------------------------------------------"
        )
        .unwrap();
        path
    }

    fn dirs(tmp: &tempfile::TempDir) -> (PathBuf, PathBuf) {
        let game = tmp.path().join("Gamelogs");
        let chat = tmp.path().join("Chatlogs");
        std::fs::create_dir_all(&game).unwrap();
        std::fs::create_dir_all(&chat).unwrap();
        (game, chat)
    }

    #[test]
    fn appends_combat_and_mining_across_partial_lines() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty(), "header alone emits nothing");

        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        writeln!(
            f,
            "[ 2026.11.28 10:01:00 ] (combat) Your 200mm AutoCannon hits Target for 100"
        )
        .unwrap();
        f.flush().unwrap();
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].kind, LogEventKind::Combat);
        assert_eq!(events[0].listener.as_deref(), Some("Jane Capsuleer"));
        assert_eq!(events[0].timestamp.as_deref(), Some("2026.11.28 10:01:00"));

        // Partial line: no newline yet -> no event, then completion.
        write!(
            f,
            "[ 2026.11.28 10:02:00 ] (mining) Mining yield: Veldspar partial"
        )
        .unwrap();
        f.flush().unwrap();
        assert!(tailer.poll_once().is_empty());
        writeln!(f, " complete").unwrap();
        f.flush().unwrap();
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].kind, LogEventKind::Mining);
        assert!(events[0].body.contains("Mining yield"));
        assert!(events[0].body.contains("complete"));
    }

    #[test]
    fn header_window_reads_no_body_of_large_preexisting_file() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        for i in 0..500 {
            writeln!(
                f,
                "[ 2026.11.28 10:01:{:02} ] (combat) historical hit {i}",
                i % 60
            )
            .unwrap();
        }
        f.flush().unwrap();
        drop(f);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(
            tailer.poll_once().is_empty(),
            "pre-existing body lines must NOT be emitted"
        );
        // Header was still learned; appends after startup are emitted.
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        writeln!(f, "[ 2026.11.28 12:00:00 ] (combat) fresh hit").unwrap();
        f.flush().unwrap();
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert!(events[0].body.contains("fresh hit"));
        assert_eq!(events[0].listener.as_deref(), Some("Jane Capsuleer"));
    }

    #[test]
    fn new_file_after_start_is_read_from_zero() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty(), "initial scan of empty dirs");
        // File created AFTER startup: header + first lines all read.
        let path = write_game_header(&game);
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        writeln!(f, "[ 2026.11.28 10:01:00 ] (combat) first session hit").unwrap();
        f.flush().unwrap();
        drop(f);
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1, "new file must be read from offset 0");
        assert!(events[0].body.contains("first session hit"));
        assert_eq!(events[0].listener.as_deref(), Some("Jane Capsuleer"));
    }

    #[test]
    fn pending_cap_drops_overlong_line_and_counts_it() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty());
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        let overlong = "x".repeat(PENDING_CAP_BYTES + 1024);
        write!(f, "{overlong}").unwrap();
        f.flush().unwrap();
        assert!(tailer.poll_once().is_empty());
        assert!(
            tailer.dropped_lines() >= 1,
            "overlong line must be dropped and counted, got {}",
            tailer.dropped_lines()
        );
        writeln!(f, "[ 2026.11.28 10:03:00 ] (combat) after drop").unwrap();
        f.flush().unwrap();
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert!(events[0].body.contains("after drop"));
    }

    #[test]
    fn rotation_by_replacement_file_same_name_is_detected() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty());
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        writeln!(
            f,
            "[ 2026.11.28 10:01:00 ] (combat) before rotation with padding padding"
        )
        .unwrap();
        f.flush().unwrap();
        drop(f);
        assert_eq!(tailer.poll_once().len(), 1);
        // Replacement written while the old file exists (distinct
        // inode guaranteed), then renamed over the same name. Its
        // length is >= the old offset, so len<offset cannot catch it.
        let staging = game.join("staging.txt");
        let mut replacement = String::new();
        replacement.push_str("[ 2026.11.28 11:00:00 ] (combat) after replacement rotation line that is long enough\n");
        replacement.push_str(
            "[ 2026.11.28 11:01:00 ] (combat) second replacement line also fairly long here\n",
        );
        std::fs::write(&staging, &replacement).unwrap();
        std::fs::rename(&staging, &path).unwrap();
        let events = tailer.poll_once();
        assert_eq!(
            events.len(),
            2,
            "replacement file must be re-read from 0: {events:?}"
        );
        assert!(events[0].body.contains("after replacement"));
    }

    #[test]
    fn invalid_utf8_gamelog_line_is_counted_not_silent() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty());
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        f.write_all(&[0xFF, 0xFE, 0x41, b'\n']).unwrap();
        writeln!(f, "[ 2026.11.28 10:04:00 ] (combat) valid after bad").unwrap();
        f.flush().unwrap();
        drop(f);
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert!(events[0].body.contains("valid after bad"));
        assert_eq!(tailer.invalid_utf8_lines(), 1);
    }

    #[test]
    fn deleted_files_are_pruned_from_tracking() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty());
        assert_eq!(tailer.tracked_file_count(), 1);
        std::fs::remove_file(&path).unwrap();
        assert!(tailer.poll_once().is_empty());
        assert_eq!(
            tailer.tracked_file_count(),
            0,
            "deleted file must be pruned"
        );
    }

    #[test]
    fn truncation_resets_offset_to_zero() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty());
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        writeln!(f, "[ 2026.11.28 10:01:00 ] (combat) first hit").unwrap();
        f.flush().unwrap();
        assert_eq!(tailer.poll_once().len(), 1);
        drop(f);
        // Truncate/rotate: shorter replacement file (len < offset).
        let mut f = File::create(&path).unwrap();
        writeln!(f, "[ 2026.11.28 11:00:00 ] (combat) after rotation").unwrap();
        f.flush().unwrap();
        drop(f);
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1, "rotation must not panic or lose line");
        assert!(events[0].body.contains("after rotation"));
    }

    #[test]
    fn missing_folder_is_clean_status_without_spam() {
        let tmp = tempfile::tempdir().unwrap();
        let game = tmp.path().join("nope-game");
        let chat = tmp.path().join("nope-chat");
        let mut tailer = LogTailer::new(&game, &chat);
        assert_eq!(tailer.status(), &DaemonStatus::LogsMissing);
        assert!(tailer.poll_once().is_empty());
        assert!(tailer.poll_once().is_empty());
        assert_eq!(tailer.status().label(), "EVE logs folder not found yet");
    }

    #[test]
    fn watcher_delivers_appended_line_within_250ms() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = write_game_header(&game);
        let mut watcher = LogWatcher::start(&game, &chat);
        assert_eq!(watcher.status(), &DaemonStatus::Watching);
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        writeln!(f, "[ 2026.11.28 10:05:00 ] (combat) watcher hit").unwrap();
        f.flush().unwrap();
        let started = Instant::now();
        let events = watcher.drain_for(Duration::from_millis(250));
        assert!(!events.is_empty(), "watcher must deliver within 250ms");
        assert!(started.elapsed() < Duration::from_millis(250));
        assert!(events[0].body.contains("watcher hit"));
    }

    #[test]
    fn chatlog_tail_decodes_utf16_and_attaches_header() {
        let tmp = tempfile::tempdir().unwrap();
        let (game, chat) = dirs(&tmp);
        let path = chat.join("20261128_100000_Local.txt");
        let header = "---------------------------------------------------------------\r\n  Channel Name:    Local\r\n  Listener:        Jane Capsuleer\r\n  Session started: 2026.11.28 10:00:00\r\n---------------------------------------------------------------\r\n";
        let mut bytes = vec![0xFF, 0xFE];
        for unit in header.encode_utf16() {
            bytes.extend_from_slice(&unit.to_le_bytes());
        }
        std::fs::write(&path, &bytes).unwrap();
        let mut tailer = LogTailer::new(&game, &chat);
        assert!(tailer.poll_once().is_empty());
        // Append one UTF-16LE chat line (no second BOM).
        let line = "[ 2026.11.28 10:09:00 ] Jane Capsuleer > intel here\r\n";
        let mut extra = Vec::new();
        for unit in line.encode_utf16() {
            extra.extend_from_slice(&unit.to_le_bytes());
        }
        let mut f = std::fs::OpenOptions::new()
            .append(true)
            .open(&path)
            .unwrap();
        f.write_all(&extra).unwrap();
        f.flush().unwrap();
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].source, LogSource::ChatLog);
        assert_eq!(events[0].channel.as_deref(), Some("Local"));
        assert_eq!(events[0].listener.as_deref(), Some("Jane Capsuleer"));
        assert_eq!(events[0].speaker.as_deref(), Some("Jane Capsuleer"));
        assert_eq!(events[0].body, "intel here");
        assert!(!events[0].body.contains('\u{FFFD}'));
    }
}
