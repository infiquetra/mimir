//! Daemon modules: EVE log tailing and clipboard classification.
//!
//! In the app a dedicated worker thread owns the log watcher and
//! forwards lines as `BackendMsg::LogEvent` (see `src/app/shell.rs`);
//! these modules themselves never read `AppState`, never open the
//! live database, and never spawn tasks. Clipboard contents are
//! classified in memory only, validated against the bundled
//! `FittingTypes` catalogue. `Ignored` text is dropped immediately
//! and is never logged or persisted at any level; daemon logs carry
//! counts and enum variants only.

pub mod clipboard;
pub mod fsevents_logs;
pub mod utf16_chatlog;

pub use clipboard::{
    classify_validated, clipboard_text_hash, poll_clipboard_once, ClipboardGuard, ClipboardKind,
};
pub use fsevents_logs::{
    default_eve_logs_dir, DaemonStatus, LogEvent, LogEventKind, LogSource, LogTailer, LogWatcher,
};

#[cfg(test)]
mod privacy_and_demo {
    use std::cell::Cell;

    use super::clipboard::{poll_clipboard_once, ClipboardGuard, ClipboardKind};
    use crate::names::fitting_types::FittingTypes;

    fn fixture_types() -> FittingTypes {
        FittingTypes::from_json(
            r#"{"types":[
                {"typeId":587,"typeName":"Rifter","categoryId":6,"slotEffects":[]}]}"#,
        )
        .expect("fixture catalogue")
    }

    #[test]
    fn demo_mode_means_zero_clipboard_reads() {
        let types = fixture_types();
        let reads = Cell::new(0usize);
        let guard = ClipboardGuard {
            demo: true,
            clipboard_opt_in: true,
        };
        let out = poll_clipboard_once(guard, &types, || {
            reads.set(reads.get() + 1);
            Some("[Rifter, Fit]".to_string())
        });
        assert_eq!(out, None);
        assert_eq!(reads.get(), 0, "demo must perform zero clipboard reads");
    }

    #[test]
    fn opt_out_means_zero_clipboard_reads() {
        let types = fixture_types();
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
            let out = poll_clipboard_once(guard, &types, || {
                reads.set(reads.get() + 1);
                Some("arbitrary private text".to_string())
            });
            assert_eq!(out, None);
            assert_eq!(reads.get(), 0);
        }
    }

    #[test]
    fn ignored_text_is_not_persisted_or_returned() {
        let types = fixture_types();
        let guard = ClipboardGuard {
            demo: false,
            clipboard_opt_in: true,
        };
        let out = poll_clipboard_once(guard, &types, || {
            Some("totally unrelated paste".to_string())
        });
        assert_eq!(
            out, None,
            "Ignored strings are dropped in memory, never persisted"
        );
        // Recognized text surfaces only the typed kind for a future
        // toast CTA; it never overwrites an active fit by itself.
        let recognized = poll_clipboard_once(guard, &types, || Some("[Rifter, Fit]\n".to_string()));
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
