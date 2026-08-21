// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Coding State Machine (CSM) for Multi-Byte Character Encodings.
//!
//! Provides strict byte-level syntax verification and multi-byte token extraction
//! for UTF-8, GB18030, Shift-JIS, Big5, and EUC-KR.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CsmState {
    Start,
    NextByte(u8),
    Error,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CharsetKind {
    Utf8,
    Gb18030,
    ShiftJis,
    Big5,
    EucKr,
    Windows1252,
}

impl CharsetKind {
    pub fn canonical_name(&self) -> &'static str {
        match self {
            CharsetKind::Utf8 => "UTF-8",
            CharsetKind::Gb18030 => "GB18030",
            CharsetKind::ShiftJis => "Shift_JIS",
            CharsetKind::Big5 => "Big5",
            CharsetKind::EucKr => "EUC-KR",
            CharsetKind::Windows1252 => "windows-1252",
        }
    }
}

/// Abstract Coding State Machine tracking multi-byte tokens and state transitions.
#[derive(Debug, Clone)]
pub struct CodingStateMachine {
    kind: CharsetKind,
    state: CsmState,
    pending_bytes: [u8; 4],
    pending_len: usize,
    total_chars: usize,
    multibyte_chars: usize,
    error_count: usize,
}

impl CodingStateMachine {
    pub fn new(kind: CharsetKind) -> Self {
        Self {
            kind,
            state: CsmState::Start,
            pending_bytes: [0; 4],
            pending_len: 0,
            total_chars: 0,
            multibyte_chars: 0,
            error_count: 0,
        }
    }

    pub fn kind(&self) -> CharsetKind {
        self.kind
    }

    pub fn is_valid(&self) -> bool {
        self.error_count == 0 && self.state != CsmState::Error
    }

    pub fn total_chars(&self) -> usize {
        self.total_chars
    }

    pub fn multibyte_chars(&self) -> usize {
        self.multibyte_chars
    }

    pub fn reset(&mut self) {
        self.state = CsmState::Start;
        self.pending_len = 0;
        self.total_chars = 0;
        self.multibyte_chars = 0;
        self.error_count = 0;
    }

    /// Feeds one byte and returns whether a complete multi-byte token (2-4 bytes) was completed.
    pub fn feed_byte(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        if self.state == CsmState::Error {
            self.error_count += 1;
            return None;
        }

        match self.kind {
            CharsetKind::Utf8 => self.feed_utf8(b),
            CharsetKind::Gb18030 => self.feed_gb18030(b),
            CharsetKind::ShiftJis => self.feed_shift_jis(b),
            CharsetKind::Big5 => self.feed_big5(b),
            CharsetKind::EucKr => self.feed_euc_kr(b),
            CharsetKind::Windows1252 => self.feed_windows1252(b),
        }
    }

    fn feed_utf8(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        if self.pending_len == 0 {
            if b <= 0x7F {
                self.total_chars += 1;
                self.state = CsmState::Start;
                None
            } else if (0xC2..=0xDF).contains(&b) {
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(1);
                None
            } else if (0xE0..=0xEF).contains(&b) {
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(2);
                None
            } else if (0xF0..=0xF4).contains(&b) {
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(3);
                None
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else {
            let lead = self.pending_bytes[0];
            let idx = self.pending_len;
            let needed = match self.state {
                CsmState::NextByte(rem) => rem,
                _ => 0,
            };

            // UTF-8 continuation validation
            let valid = match (lead, idx) {
                (0xE0, 1) => (0xA0..=0xBF).contains(&b),
                (0xED, 1) => (0x80..=0x9F).contains(&b),
                (0xF0, 1) => (0x90..=0xBF).contains(&b),
                (0xF4, 1) => (0x80..=0x8F).contains(&b),
                _ => (0x80..=0xBF).contains(&b),
            };

            if !valid {
                self.state = CsmState::Error;
                self.error_count += 1;
                return None;
            }

            self.pending_bytes[idx] = b;
            self.pending_len += 1;

            if needed == 1 {
                let token_len = self.pending_len;
                let token = self.pending_bytes;
                self.pending_len = 0;
                self.state = CsmState::Start;
                self.total_chars += 1;
                self.multibyte_chars += 1;
                Some((token, token_len))
            } else {
                self.state = CsmState::NextByte(needed - 1);
                None
            }
        }
    }

    fn feed_gb18030(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        if self.pending_len == 0 {
            if b <= 0x7F {
                self.total_chars += 1;
                self.state = CsmState::Start;
                None
            } else if (0x81..=0xFE).contains(&b) {
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(1);
                None
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else if self.pending_len == 1 {
            let _lead = self.pending_bytes[0];
            if (0x30..=0x39).contains(&b) {
                // 4-byte sequence lead: 0x81..0xFE 0x30..0x39
                self.pending_bytes[1] = b;
                self.pending_len = 2;
                self.state = CsmState::NextByte(2);
                None
            } else if (0x40..=0x7E).contains(&b) || (0x80..=0xFE).contains(&b) {
                // 2-byte GBK sequence
                self.pending_bytes[1] = b;
                let token = self.pending_bytes;
                self.pending_len = 0;
                self.state = CsmState::Start;
                self.total_chars += 1;
                self.multibyte_chars += 1;
                Some((token, 2))
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else if self.pending_len == 2 {
            if (0x81..=0xFE).contains(&b) {
                self.pending_bytes[2] = b;
                self.pending_len = 3;
                self.state = CsmState::NextByte(1);
                None
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else if self.pending_len == 3 {
            if (0x30..=0x39).contains(&b) {
                self.pending_bytes[3] = b;
                let token = self.pending_bytes;
                self.pending_len = 0;
                self.state = CsmState::Start;
                self.total_chars += 1;
                self.multibyte_chars += 1;
                Some((token, 4))
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else {
            self.state = CsmState::Error;
            self.error_count += 1;
            None
        }
    }

    fn feed_shift_jis(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        if self.pending_len == 0 {
            if b <= 0x7F || (0xA1..=0xDF).contains(&b) {
                // ASCII or Single-byte Katakana
                self.total_chars += 1;
                self.state = CsmState::Start;
                None
            } else if (0x81..=0x9F).contains(&b) || (0xE0..=0xFC).contains(&b) {
                // Double-byte lead
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(1);
                None
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else {
            if (0x40..=0x7E).contains(&b) || (0x80..=0xFC).contains(&b) {
                self.pending_bytes[1] = b;
                let token = self.pending_bytes;
                self.pending_len = 0;
                self.state = CsmState::Start;
                self.total_chars += 1;
                self.multibyte_chars += 1;
                Some((token, 2))
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        }
    }

    fn feed_big5(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        if self.pending_len == 0 {
            if b <= 0x7F {
                self.total_chars += 1;
                self.state = CsmState::Start;
                None
            } else if (0x81..=0xFE).contains(&b) {
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(1);
                None
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else {
            // Big5 trail byte: 0x40..=0x7E or 0xA1..=0xFE (0x7F and 0x80..0xA0 are invalid)
            if (0x40..=0x7E).contains(&b) || (0xA1..=0xFE).contains(&b) {
                self.pending_bytes[1] = b;
                let token = self.pending_bytes;
                self.pending_len = 0;
                self.state = CsmState::Start;
                self.total_chars += 1;
                self.multibyte_chars += 1;
                Some((token, 2))
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        }
    }

    fn feed_euc_kr(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        if self.pending_len == 0 {
            if b <= 0x7F {
                self.total_chars += 1;
                self.state = CsmState::Start;
                None
            } else if (0x81..=0xFE).contains(&b) {
                self.pending_bytes[0] = b;
                self.pending_len = 1;
                self.state = CsmState::NextByte(1);
                None
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        } else {
            // EUC-KR / CP949 trail byte: 0x41..=0x5A, 0x61..=0x7A, 0x81..=0xFE
            if (0x41..=0x5A).contains(&b) || (0x61..=0x7A).contains(&b) || (0x81..=0xFE).contains(&b) {
                self.pending_bytes[1] = b;
                let token = self.pending_bytes;
                self.pending_len = 0;
                self.state = CsmState::Start;
                self.total_chars += 1;
                self.multibyte_chars += 1;
                Some((token, 2))
            } else {
                self.state = CsmState::Error;
                self.error_count += 1;
                None
            }
        }
    }

    fn feed_windows1252(&mut self, b: u8) -> Option<([u8; 4], usize)> {
        // Windows-1252 has single-byte values for almost all 0x00..0xFF,
        // with invalid undefined values: 0x81, 0x8D, 0x8F, 0x90, 0x9D
        if matches!(b, 0x81 | 0x8D | 0x8F | 0x90 | 0x9D) {
            self.state = CsmState::Error;
            self.error_count += 1;
            None
        } else {
            self.total_chars += 1;
            self.state = CsmState::Start;
            None
        }
    }
}
