// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-frequency Traditional Chinese character and bigram probability distribution tables for Big5.

/// Returns a frequency weight (0..=100) for a 2-byte Big5 sequence `[b0, b1]`.
pub fn score_big5_2byte(b0: u8, b1: u8) -> u32 {
    let code = ((b0 as u16) << 8) | (b1 as u16);

    // 1. Top ultra-high frequency Traditional Chinese characters in Big5
    match code {
        0xAAF7 // 的
        | 0xA440 // 一
        | 0xAC4F // 是
        | 0xA4A3 // 不
        | 0xA446 // 了
        | 0xA662 // 在
        | 0xA448 // 人
        | 0xA6B3 // 有
        | 0xA7DA // 我
        | 0xA54C // 他
        | 0xB36F // 這
        | 0xAD47 // 個
        | 0xADCC // 們
        | 0xA4A4 // 中
        | 0xA8D3 // 來
        | 0xA457 // 上
        | 0xA46A // 大
        | 0xACAB // 為
        | 0xA94D // 和
        | 0xB0EA // 國
        | 0xA741 // 你
        | 0xA66E // 好
        | 0xB4FA // 測
        | 0xB8D5 // 試
        | 0xA4E5 // 文
        | 0xA5F3 // 件
        | 0xC0C9 // 檔
        | 0xC0A3 // 壓
        | 0xC159 // 縮
        | 0xBBA1 // 說
        | 0xB77C // 會
        | 0xB8EA // 資
        | 0xAEA6 // 料
        | 0xB9CF // 圖
        | 0xA4F9 // 片
        | 0xBC76 // 影
        | 0xB773 // 新
        | 0xBC57 // 增
        | 0xA9FA // 明
        | 0xC163 // 繁
        | 0xC5E9 // 體
        | 0xADBB // 香
        | 0xB4E4 // 港
        | 0xA578 // 台
        | 0xC657 // 灣
        | 0xB16A // 專
        | 0xAEF7 // 案
        | 0xA5D8 // 目
        | 0xBFFD // 錄
        | 0xB8D1 // 解
        => 100,

        // 2. High frequency Common Big5 Characters (0xA440..=0xC67E: Level 1 Common Hanzi)
        _ if (0xA4..=0xC6).contains(&b0) && ((0x40..=0x7E).contains(&b1) || (0xA1..=0xFE).contains(&b1)) => 60,

        // 3. Secondary Big5 Characters (0xC940..=0xF9D5: Level 2 Hanzi)
        _ if (0xC9..=0xF9).contains(&b0) && ((0x40..=0x7E).contains(&b1) || (0xA1..=0xFE).contains(&b1)) => 40,

        // 4. Other Big5 User-Defined / Extended Zone
        _ if (0x81..=0xFE).contains(&b0) && ((0x40..=0x7E).contains(&b1) || (0xA1..=0xFE).contains(&b1)) => 20,

        _ => 0,
    }
}
