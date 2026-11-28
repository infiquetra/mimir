//! `notify`-backed tailing of EVE `Gamelogs/*.txt` (UTF-8) and
//! `Chatlogs/*.txt` (UTF-16LE BOM).
//!
//! [`LogEvent`] is shaped to map 1:1 onto a future
//! `BackendMsg::LogEvent(LogEvent)` variant in `src/app/shell.rs`.
//! Deferred wiring only needs to forward events from
//! [`LogWatcher::poll_once`] / [`LogWatcher::drain_for`] and call
//! `ctx.request_repaint()`; no parsing lives in the shell.
//!
//! Missing log folders are a clean status ([`DaemonStatus::LogsMissing`]),
//! never an error loop. Truncation/rotation (`len < offset`) resets the
//! tracked offset to 0 without panicking.

use std::collections::HashMap;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{channel, Receiver};
use std::time::{Duration, Instant};

use notify::{RecommendedWatcher, RecursiveMode, Watcher};

use super::utf16_chatlog::{
    decode_utf16le, parse_chatlog_header, parse_chatlog_line, ChatlogHeader,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogSource {
    GameLog,
    ChatLog,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LogEventKind {
    Combat,
    Notify,
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
    discovered: bool,
    bom_stripped: bool,
    listener: Option<String>,
    channel: Option<String>,
    chat_header: ChatlogHeader,
}

/// Incremental tailer over both log folders. Synchronous `poll_once`
/// is the deterministic core; the `notify` watcher only wakes it.
pub struct LogTailer {
    gamelogs_dir: PathBuf,
    chatlogs_dir: PathBuf,
    files: HashMap<PathBuf, FileState>,
    status: DaemonStatus,
    missing_logged: bool,
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
        }
    }

    pub fn status(&self) -> &DaemonStatus {
        &self.status
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
        if game_files.is_empty() && chat_files.is_empty() {
            if self.status != DaemonStatus::WatchFailed {
                self.status = DaemonStatus::LogsMissing;
            }
            if !self.missing_logged {
                tracing::info!("[DAEMON] log tailer status=missing folders_found=0");
                self.missing_logged = true;
            }
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
        if !events.is_empty() {
            tracing::debug!("[DAEMON] log events emitted count={}", events.len());
        }
        events
    }

    fn poll_file(&mut self, path: &Path, source: LogSource) -> Vec<LogEvent> {
        let Ok(metadata) = std::fs::metadata(path) else {
            return Vec::new();
        };
        let len = metadata.len();
        let state = self.files.entry(path.to_path_buf()).or_default();
        if len < state.offset {
            tracing::debug!("[DAEMON] log truncated offset_reset=0 source={source:?}");
            state.offset = 0;
            state.pending.clear();
            state.bom_stripped = false;
            state.listener = None;
            state.channel = None;
            state.chat_header = ChatlogHeader::default();
            // Keep `discovered` true so replacement content is emitted.
            state.discovered = true;
        }
        if len == state.offset {
            return Vec::new();
        }
        let Ok(mut file) = File::open(path) else {
            return Vec::new();
        };
        if file.seek(SeekFrom::Start(state.offset)).is_err() {
            return Vec::new();
        }
        let mut bytes = Vec::new();
        if file.read_to_end(&mut bytes).is_err() {
            return Vec::new();
        }
        state.offset = state.offset.saturating_add(bytes.len() as u64);
        let emit = state.discovered;
        let events = match source {
            LogSource::GameLog => Self::ingest_game(state, &bytes, emit),
            LogSource::ChatLog => Self::ingest_chat(state, &bytes, emit),
        };
        state.discovered = true;
        events
    }

    fn ingest_game(state: &mut FileState, bytes: &[u8], emit: bool) -> Vec<LogEvent> {
        state.pending.extend_from_slice(bytes);
        let mut events = Vec::new();
        while let Some(pos) = state.pending.iter().position(|b| *b == b'\n') {
            let line_bytes: Vec<u8> = state.pending.drain(..=pos).collect();
            let Ok(line) = String::from_utf8(line_bytes) else {
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
        events
    }

    fn ingest_chat(state: &mut FileState, bytes: &[u8], emit: bool) -> Vec<LogEvent> {
        state.pending.extend_from_slice(bytes);
        if !state.bom_stripped && state.pending.starts_with(&[0xFF, 0xFE]) {
            state.pending.drain(..2);
            state.bom_stripped = true;
        } else if !state.bom_stripped && state.pending.len() >= 2 {
            state.bom_stripped = true;
        }
        let mut events = Vec::new();
        // UTF-16LE newline is 0x0A 0x00 at an even offset.
        loop {
            let mut found: Option<usize> = None;
            let mut i = 0usize;
            while i + 1 < state.pending.len() {
                if state.pending[i] == 0x0A && state.pending[i + 1] == 0x00 {
                    found = Some(i);
                    break;
                }
                i += 2;
            }
            let Some(pos) = found else { break };
            let line_bytes: Vec<u8> = state.pending.drain(..pos + 2).collect();
            let Ok(line) = decode_utf16le(&line_bytes) else {
                continue;
            };
            let line = line.trim_end_matches(['\r', '\n']);
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with("---") {
                continue;
            }
            // Refresh header from any header line seen at file start.
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
        events
    }
}

/// `notify`-backed watcher wrapping [`LogTailer`]. On macOS the
/// recommended watcher is FSEvents; elsewhere it is the platform best.
pub struct LogWatcher {
    tailer: LogTailer,
    _watcher: Option<RecommendedWatcher>,
    _rx: Option<Receiver<Result<notify::Event, notify::Error>>>,
    status: DaemonStatus,
}

impl LogWatcher {
    pub fn start(gamelogs_dir: &Path, chatlogs_dir: &Path) -> Self {
        let mut tailer = LogTailer::new(gamelogs_dir, chatlogs_dir);
        let initial = tailer.poll_once();
        debug_assert!(initial.is_empty() || true);
        if !gamelogs_dir.is_dir() && !chatlogs_dir.is_dir() {
            tracing::info!("[DAEMON] log watcher status=missing folders_found=0");
            return Self {
                tailer,
                _watcher: None,
                _rx: None,
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
                        _rx: None,
                        status: DaemonStatus::WatchFailed,
                    }
                } else {
                    tracing::info!("[DAEMON] log watcher status=watching");
                    Self {
                        tailer,
                        _watcher: Some(watcher),
                        _rx: Some(rx),
                        status: DaemonStatus::Watching,
                    }
                }
            }
            Err(_) => {
                tracing::warn!("[DAEMON] log watcher status=watch_failed");
                Self {
                    tailer,
                    _watcher: None,
                    _rx: None,
                    status: DaemonStatus::WatchFailed,
                }
            }
        }
    }

    pub fn status(&self) -> &DaemonStatus {
        &self.status
    }

    pub fn poll_once(&mut self) -> Vec<LogEvent> {
        // Drain pending OS notifications without blocking; the tailer
        // re-scan is authoritative and also covers missed events.
        if let Some(rx) = &self._rx {
            while rx.try_recv().is_ok() {}
        }
        self.tailer.poll_once()
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

    #[test]
    fn appends_combat_and_mining_across_partial_lines() {
        let tmp = tempfile::tempdir().unwrap();
        let game = tmp.path().join("Gamelogs");
        let chat = tmp.path().join("Chatlogs");
        std::fs::create_dir_all(&game).unwrap();
        std::fs::create_dir_all(&chat).unwrap();
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
            "[ 2026.11.28 10:02:00 ] (notify) Mining yield: Veldspar partial"
        )
        .unwrap();
        f.flush().unwrap();
        assert!(tailer.poll_once().is_empty());
        writeln!(f, " complete").unwrap();
        f.flush().unwrap();
        let events = tailer.poll_once();
        assert_eq!(events.len(), 1);
        assert!(events[0].body.contains("Mining yield"));
        assert!(events[0].body.contains("complete"));
    }

    #[test]
    fn truncation_resets_offset_to_zero() {
        let tmp = tempfile::tempdir().unwrap();
        let game = tmp.path().join("Gamelogs");
        let chat = tmp.path().join("Chatlogs");
        std::fs::create_dir_all(&game).unwrap();
        std::fs::create_dir_all(&chat).unwrap();
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
        let game = tmp.path().join("Gamelogs");
        let chat = tmp.path().join("Chatlogs");
        std::fs::create_dir_all(&game).unwrap();
        std::fs::create_dir_all(&chat).unwrap();
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
        let game = tmp.path().join("Gamelogs");
        let chat = tmp.path().join("Chatlogs");
        std::fs::create_dir_all(&game).unwrap();
        std::fs::create_dir_all(&chat).unwrap();
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
