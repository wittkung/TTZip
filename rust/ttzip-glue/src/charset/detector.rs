// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Hybrid Charset Sniffing Engine combining SIMD ASCII validation, strict UTF-8 parsing,
//! Coding State Machine (CSM) pruning, and 2-byte CJK Bigram frequency statistics.

use crate::charset::csm::{CharsetKind, CodingStateMachine};
use crate::charset::tables::{
    score_big5_2byte, score_euc_kr_2byte, score_gb18030_2byte, score_shift_jis_2byte,
};
use chardetng::EncodingDetector;

/// Candidate detection score holding metadata and calculated confidence.
#[derive(Debug, Clone)]
struct CandidateScore {
    kind: CharsetKind,
    is_valid_csm: bool,
    final_confidence: f32,
}

/// Detects character set encoding for given raw byte sequence with confidence score [0.0..1.0].
pub fn detect_charset_with_confidence(data: &[u8]) -> (String, f32) {
    if data.is_empty() {
        return ("ASCII".to_string(), 1.0);
    }

    // 1. SIMD ASCII Fast-Path: If pure 7-bit ASCII, return ASCII immediately.
    if data.is_ascii() {
        return ("ASCII".to_string(), 1.0);
    }

    // Check for explicit UTF-8 BOM
    if data.starts_with(b"\xEF\xBB\xBF") {
        return ("UTF-8".to_string(), 1.0);
    }

    let is_valid_utf8 = std::str::from_utf8(data).is_ok();

    // 2. Chardetng oracle prediction
    let mut chardet = EncodingDetector::new();
    chardet.feed(data, true);
    let chardet_guess = chardet.guess(None, true);
    let chardet_name = chardet_guess.name();

    // 3. CSM State Machine Pruning & 2-Byte Bigram Statistical Evaluation
    let mut csm_gb = CodingStateMachine::new(CharsetKind::Gb18030);
    let mut csm_sjis = CodingStateMachine::new(CharsetKind::ShiftJis);
    let mut csm_big5 = CodingStateMachine::new(CharsetKind::Big5);
    let mut csm_euckr = CodingStateMachine::new(CharsetKind::EucKr);
    let mut csm_win = CodingStateMachine::new(CharsetKind::Windows1252);

    let mut score_gb: u32 = 0;
    let mut score_sjis: u32 = 0;
    let mut score_big5: u32 = 0;
    let mut score_euckr: u32 = 0;

    for &b in data {
        if let Some((tok, len)) = csm_gb.feed_byte(b) {
            if len == 2 {
                score_gb += score_gb18030_2byte(tok[0], tok[1]);
            }
        }
        if let Some((tok, len)) = csm_sjis.feed_byte(b) {
            if len == 2 {
                score_sjis += score_shift_jis_2byte(tok[0], tok[1]);
            }
        }
        if let Some((tok, len)) = csm_big5.feed_byte(b) {
            if len == 2 {
                score_big5 += score_big5_2byte(tok[0], tok[1]);
            }
        }
        if let Some((tok, len)) = csm_euckr.feed_byte(b) {
            if len == 2 {
                score_euckr += score_euc_kr_2byte(tok[0], tok[1]);
            }
        }
        let _ = csm_win.feed_byte(b);
    }

    let is_chardet_gb = chardet_name.eq_ignore_ascii_case("gb18030") || chardet_name.eq_ignore_ascii_case("gbk");
    let is_chardet_sjis = chardet_name.eq_ignore_ascii_case("shift_jis");
    let is_chardet_big5 = chardet_name.eq_ignore_ascii_case("big5");
    let is_chardet_euckr = chardet_name.eq_ignore_ascii_case("euc-kr");
    let is_chardet_utf8 = chardet_name.eq_ignore_ascii_case("utf-8");
    let is_chardet_win1252 = chardet_name.eq_ignore_ascii_case("windows-1252");

    let calc_confidence = |is_valid: bool, mb_count: usize, acc_score: u32, is_chardet: bool| -> f32 {
        if !is_valid {
            return 0.0;
        }
        if mb_count == 0 {
            return if is_chardet { 0.5 } else { 0.1 };
        }
        let base_density = (acc_score as f32) / (mb_count as f32 * 100.0);
        let chardet_boost = if is_chardet { 0.35 } else { 0.0 };
        (base_density * 0.75 + chardet_boost).min(1.0)
    };

    let candidates = [
        CandidateScore {
            kind: CharsetKind::Gb18030,
            is_valid_csm: csm_gb.is_valid(),
            final_confidence: calc_confidence(csm_gb.is_valid(), csm_gb.multibyte_chars(), score_gb, is_chardet_gb),
        },
        CandidateScore {
            kind: CharsetKind::ShiftJis,
            is_valid_csm: csm_sjis.is_valid(),
            final_confidence: calc_confidence(csm_sjis.is_valid(), csm_sjis.multibyte_chars(), score_sjis, is_chardet_sjis),
        },
        CandidateScore {
            kind: CharsetKind::Big5,
            is_valid_csm: csm_big5.is_valid(),
            final_confidence: calc_confidence(csm_big5.is_valid(), csm_big5.multibyte_chars(), score_big5, is_chardet_big5),
        },
        CandidateScore {
            kind: CharsetKind::EucKr,
            is_valid_csm: csm_euckr.is_valid(),
            final_confidence: calc_confidence(csm_euckr.is_valid(), csm_euckr.multibyte_chars(), score_euckr, is_chardet_euckr),
        },
    ];

    // If UTF-8 is strictly valid:
    // If valid UTF-8 and no candidate has overwhelmingly high CJK score (> 0.9) while chardet predicts legacy, prefer UTF-8.
    if is_valid_utf8 {
        let best_legacy = candidates.iter().max_by(|a, b| a.final_confidence.partial_cmp(&b.final_confidence).unwrap());
        if let Some(best) = best_legacy {
            if best.final_confidence > 0.85 && !is_chardet_utf8 {
                return (best.kind.canonical_name().to_string(), best.final_confidence);
            }
        }
        return ("UTF-8".to_string(), if is_chardet_utf8 { 0.99 } else { 0.92 });
    }

    // Find the highest confidence among valid CJK candidates
    let best_candidate = candidates
        .iter()
        .filter(|c| c.is_valid_csm)
        .max_by(|a, b| a.final_confidence.partial_cmp(&b.final_confidence).unwrap());

    if let Some(best) = best_candidate {
        if best.final_confidence > 0.20 {
            return (best.kind.canonical_name().to_string(), best.final_confidence);
        }
    }

    // Fallbacks
    if is_chardet_win1252 || csm_win.is_valid() {
        ("windows-1252".to_string(), 0.5)
    } else {
        ("UTF-8".to_string(), 0.1)
    }
}

/// One-shot charset detection returning canonical charset name string if determined.
pub fn detect_charset(data: &[u8]) -> Option<String> {
    if data.is_empty() {
        return Some("ASCII".to_string());
    }
    let (charset, _conf) = detect_charset_with_confidence(data);
    Some(charset)
}
