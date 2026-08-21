// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-frequency Japanese character distribution and bigram tables for Shift-JIS (CP932).

/// Returns a frequency weight (0..=100) for a 2-byte Shift-JIS sequence `[b0, b1]`.
pub fn score_shift_jis_2byte(b0: u8, b1: u8) -> u32 {
    let code = ((b0 as u16) << 8) | (b1 as u16);

    // 1. Japanese Hiragana range (0x829F..=0x82F1) - extremely distinctive to Japanese
    if (0x829F..=0x82F1).contains(&code) {
        return 100;
    }

    // 2. Japanese Katakana range (0x8340..=0x8396)
    if (0x8340..=0x8396).contains(&code) {
        return 100;
    }

    // 3. Japanese Punctuation & Symbols (0x8140..=0x81AC, e.g. "ー" 0x815B, "、" 0x8141, "。" 0x8142)
    if (0x8140..=0x81AC).contains(&code) {
        return 90;
    }

    // 4. Ultra-high frequency Kanji in Shift-JIS
    match code {
        0x93FA // 日
        | 0x967B // 本
        | 0x8CEA // 語
        | 0x89E6 // 画
        | 0x919C // 像
        | 0x8F91 // 書
        | 0x97DE // 類
        | 0x8DEC // 作
        | 0x90AC // 成
        | 0x944E // 年
        | 0x8C8E // 月
        | 0x938C // 東
        | 0x8B9E // 京
        | 0x8F6F // 出
        | 0x97CD // 力
        | 0x8F88 // 処
        | 0x979D // 理
        | 0x8E77 // 指
        | 0x92E8 // 定
        | 0x95BD // 閉
        | 0x8A4A // 開
        | 0x8D87 // 再
        | 0x90B6 // 生
        | 0x959F // 表
        | 0x8E8A // 示
        => 100,

        // 5. Shift-JIS Level 1 Kanji Zone (0x889F..=0x9872)
        _ if (0x88..=0x98).contains(&b0) && ((0x40..=0x7E).contains(&b1) || (0x80..=0xFC).contains(&b1)) => 60,

        // 6. Shift-JIS Level 2 Kanji Zone (0x989F..=0xEA40, 0xE0..=0xFC)
        _ if (0xE0..=0xFC).contains(&b0) && ((0x40..=0x7E).contains(&b1) || (0x80..=0xFC).contains(&b1)) => 40,

        _ => 0,
    }
}
