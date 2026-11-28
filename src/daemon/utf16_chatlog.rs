//! UTF-16LE `Chatlogs/*.txt` decoding and parsing.
//!
//! EVE writes chat logs as UTF-16LE with a byte-order mark. Decoding is
//! strict: malformed code units return an error instead of inserting
//! U+FFFD replacement characters.

/// Header parsed from the top of one chat log file.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ChatlogHeader {
    pub listener: Option<String>,
    pub channel_name: Option<String>,
    pub session_started: Option<String>,
}

/// One parsed chat message line.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ChatMessage {
    pub listener: Option<String>,
    pub channel_name: Option<String>,
    pub timestamp: String,
    pub speaker: String,
    pub body: String,
}

/// Decode UTF-16LE bytes, stripping a leading FF FE byte-order mark.
///
/// Returns `Err` on odd byte counts or unpaired surrogates so callers
/// never silently receive U+FFFD replacement characters.
pub fn decode_utf16le_bom(bytes: &[u8]) -> Result<String, String> {
    let body = if bytes.starts_with(&[0xFF, 0xFE]) {
        tracing::debug!("[DAEMON] utf16 chatlog bom=present bytes={}", bytes.len());
        &bytes[2..]
    } else {
        bytes
    };
    decode_utf16le(body)
}

/// Decode UTF-16LE bytes without any byte-order mark.
pub fn decode_utf16le(bytes: &[u8]) -> Result<String, String> {
    if !bytes.len().is_multiple_of(2) {
        return Err("odd byte count for UTF-16LE".to_string());
    }
    let units: Vec<u16> = bytes
        .as_chunks::<2>()
        .0
        .iter()
        .map(|pair| u16::from_le_bytes(*pair))
        .collect();
    let text: String = char::decode_utf16(units)
        .collect::<Result<String, _>>()
        .map_err(|_| "unpaired surrogate in UTF-16LE".to_string())?;
    // A decoded U+FEFF at the start is the character form of the BOM.
    Ok(text.strip_prefix('\u{FEFF}').unwrap_or(&text).to_string())
}

fn header_value(line: &str, key: &str) -> Option<String> {
    let trimmed = line.trim();
    trimmed
        .strip_prefix(key)
        .map(|rest| rest.trim().to_string())
        .filter(|value| !value.is_empty())
}

/// Parse the `Listener:` / `Channel Name:` header block of a chat log.
pub fn parse_chatlog_header(text: &str) -> ChatlogHeader {
    let mut header = ChatlogHeader::default();
    for line in text.lines() {
        if let Some(value) = header_value(line, "Listener:") {
            header.listener = Some(value);
        } else if let Some(value) = header_value(line, "Channel Name:") {
            header.channel_name = Some(value);
        } else if let Some(value) = header_value(line, "Session started:")
            .or_else(|| header_value(line, "Session Started:"))
        {
            header.session_started = Some(value);
        }
    }
    tracing::debug!(
        "[DAEMON] chatlog header listener_present={} channel_present={}",
        header.listener.is_some(),
        header.channel_name.is_some()
    );
    header
}

/// Parse one `[ YYYY.MM.DD HH:MM:SS ] Speaker > body` chat line.
pub fn parse_chatlog_line(line: &str, header: &ChatlogHeader) -> Option<ChatMessage> {
    let line = line.trim_end_matches(['\r', '\n']);
    let after_bracket = line.trim_start().strip_prefix('[')?;
    let (timestamp, rest) = after_bracket.split_once(']')?;
    let rest = rest.trim();
    let (speaker, body) = rest.split_once('>')?;
    let speaker = speaker.trim();
    if speaker.is_empty() {
        return None;
    }
    Some(ChatMessage {
        listener: header.listener.clone(),
        channel_name: header.channel_name.clone(),
        timestamp: timestamp.trim().to_string(),
        speaker: speaker.to_string(),
        body: body.trim_start().to_string(),
    })
}

/// Parse every message line in a fully decoded chat log.
pub fn parse_chatlog(text: &str) -> (ChatlogHeader, Vec<ChatMessage>) {
    let header = parse_chatlog_header(text);
    let messages = text
        .lines()
        .filter_map(|line| parse_chatlog_line(line, &header))
        .collect();
    (header, messages)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn utf16le_bom_fixture() -> Vec<u8> {
        let text = concat!(
            "---------------------------------------------------------------\r\n",
            "  Channel ID:      (('solarsystemid2', 30000142),)\r\n",
            "  Channel Name:    Local\r\n",
            "  Listener:        Jane Capsuleer\r\n",
            "  Session started: 2026.11.28 10:00:00\r\n",
            "---------------------------------------------------------------\r\n",
            "\r\n",
            "[ 2026.11.28 10:01:02 ] Jane Capsuleer > hostiles in system\r\n",
            "[ 2026.11.28 10:02:03 ] Other Pilot > copy that\r\n",
        );
        let mut bytes = vec![0xFF, 0xFE];
        for unit in text.encode_utf16() {
            bytes.extend_from_slice(&unit.to_le_bytes());
        }
        bytes
    }

    #[test]
    fn decodes_bom_with_zero_replacement_chars() {
        let text = decode_utf16le_bom(&utf16le_bom_fixture()).expect("decode");
        assert_eq!(text.matches('\u{FFFD}').count(), 0);
        assert!(!text.starts_with('\u{FEFF}'));
    }

    #[test]
    fn extracts_listener_channel_timestamp_and_body() {
        let text = decode_utf16le_bom(&utf16le_bom_fixture()).expect("decode");
        let (header, messages) = parse_chatlog(&text);
        assert_eq!(header.listener.as_deref(), Some("Jane Capsuleer"));
        assert_eq!(header.channel_name.as_deref(), Some("Local"));
        assert_eq!(messages.len(), 2);
        let first = &messages[0];
        assert_eq!(first.listener.as_deref(), Some("Jane Capsuleer"));
        assert_eq!(first.channel_name.as_deref(), Some("Local"));
        assert_eq!(first.timestamp, "2026.11.28 10:01:02");
        assert_eq!(first.speaker, "Jane Capsuleer");
        assert_eq!(first.body, "hostiles in system");
        assert_eq!(messages[1].body, "copy that");
    }

    #[test]
    fn rejects_odd_bytes_and_unpaired_surrogates_without_replacement() {
        assert!(decode_utf16le_bom(&[0xFF, 0xFE, 0x61]).is_err());
        // Lone high surrogate.
        assert!(decode_utf16le(&[0x00, 0xD8]).is_err());
    }

    #[test]
    fn non_message_lines_are_ignored() {
        let header = ChatlogHeader {
            listener: Some("Jane Capsuleer".to_string()),
            channel_name: Some("Local".to_string()),
            session_started: None,
        };
        assert_eq!(parse_chatlog_line("  Listener: Jane", &header), None);
        assert_eq!(parse_chatlog_line("", &header), None);
    }
}
