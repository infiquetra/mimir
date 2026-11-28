//! Pure daemon modules: EVE log tailing and clipboard classification.
//!
//! Shell/state/settings wiring is deferred: these modules never read
//! `AppState`, never open the live database, and never spawn tasks.
//! Events map 1:1 onto a future `BackendMsg::LogEvent(LogEvent)` in
//! `src/app/shell.rs`; the deferred wiring only forwards them.
//! Clipboard contents are classified in memory only. `Ignored` text is
//! dropped immediately and is never logged or persisted at any level;
//! daemon logs carry counts and enum variants only.

pub mod clipboard;
pub mod fsevents_logs;
pub mod utf16_chatlog;

pub use clipboard::{
    classify, clipboard_text_hash, poll_clipboard_once, ClipboardGuard, ClipboardKind,
};
pub use fsevents_logs::{
    default_eve_logs_dir, DaemonStatus, LogEvent, LogEventKind, LogSource, LogTailer, LogWatcher,
};

#[cfg(test)]
mod privacy_and_demo {
    use std::cell::Cell;

    use super::clipboard::{poll_clipboard_once, ClipboardGuard, ClipboardKind};

    #[test]
    fn demo_mode_means_zero_clipboard_reads() {
        let reads = Cell::new(0usize);
        let guard = ClipboardGuard {
            demo: true,
            clipboard_opt_in: true,
        };
        let out = poll_clipboard_once(guard, || {
            reads.set(reads.get() + 1);
            Some("[Rifter, Fit]".to_string())
        });
        assert_eq!(out, None);
        assert_eq!(reads.get(), 0, "demo must perform zero clipboard reads");
    }

    #[test]
    fn opt_out_means_zero_clipboard_reads() {
        for guard in [
            ClipboardGuard {
                demo: false,
                clipboard_opt_in: false,
            },
            ClipboardGuard {
                demo: true,
                clipboard_opt_in: false,
            },
        ] {
            let reads = Cell::new(0usize);
            let out = poll_clipboard_once(guard, || {
                reads.set(reads.get() + 1);
                Some("arbitrary private text".to_string())
            });
            assert_eq!(out, None);
            assert_eq!(reads.get(), 0);
        }
    }

    #[test]
    fn ignored_text_is_not_persisted_or_returned() {
        let guard = ClipboardGuard {
            demo: false,
            clipboard_opt_in: true,
        };
        let out = poll_clipboard_once(guard, || Some("totally unrelated paste".to_string()));
        assert_eq!(
            out, None,
            "Ignored strings are dropped in memory, never persisted"
        );
        // Recognized text surfaces only the typed kind for a future toast
        // CTA; it never overwrites an active fit by itself.
        let recognized = poll_clipboard_once(guard, || Some("[Rifter, Fit]\n".to_string()));
        assert!(matches!(recognized, Some(ClipboardKind::EftFit { .. })));
    }

    #[test]
    fn daemon_guard_requires_both_live_and_opt_in() {
        assert!(!ClipboardGuard {
            demo: true,
            clipboard_opt_in: true
        }
        .may_poll());
        assert!(!ClipboardGuard {
            demo: false,
            clipboard_opt_in: false
        }
        .may_poll());
        assert!(ClipboardGuard {
            demo: false,
            clipboard_opt_in: true
        }
        .may_poll());
    }
}
