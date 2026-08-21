// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-frequency Simplified Chinese character and bigram probability distribution tables for GB18030 / GBK.

/// Returns a frequency weight (0..=100) for a 2-byte GBK/GB18030 sequence `[b0, b1]`.
pub fn score_gb18030_2byte(b0: u8, b1: u8) -> u32 {
    let code = ((b0 as u16) << 8) | (b1 as u16);

    // 1. Top ultra-high frequency Simplified Chinese characters (Score 100)
    match code {
        0xB5C4 // 的
        | 0xD2BB // 一
        | 0xCAD7 // 是
        | 0xB2BB // 不
        | 0xC1CB // 了
        | 0xD4DA // 在
        | 0xC8CB // 人
        | 0xD3D0 // 有
        | 0xCED2 // 我
        | 0xCBFB // 他
        | 0xD5E2 // 这
        | 0xD6D0 // 中
        | 0xB4F3 // 大
        | 0xC0B4 // 来
        | 0xC9CF // 上
        | 0xB9FA // 国
        | 0xB8F6 // 个
        | 0xB5BD // 到
        | 0xCB55 // 说
        | 0xC3C7 // 们
        | 0xCEAA // 为
        | 0xD7D3 // 子
        | 0xBACD // 和
        | 0xC4E3 // 你
        | 0xBAC3 // 好
        | 0xB2E2 // 测
        | 0xCAD4 // 试
        | 0xCEC4 // 文
        | 0xBCFE // 件
        | 0xB5B5 // 档
        | 0xD1B9 // 压
        | 0xCBF5 // 缩
        | 0xD7CA // 资
        | 0xC1CF // 料
        | 0xB1A4 // 包
        | 0xBCD0 // 夹
        | 0xCDC3 // 图
        | 0xC6AC // 片
        | 0xD0C2 // 新
        | 0xBDA8 // 建
        | 0xD2F4 // 音
        | 0xC6B5 // 频
        | 0xCAD3 // 视
        | 0xB1ED // 表
        | 0xB8F1 // 格
        | 0xCCE1 // 提
        | 0xCAA6 // 示
        | 0xCDB3 // 统
        | 0xCEBB // 位
        | 0xC0FA // 历
        | 0xCAB7 // 史
        | 0xBFEC // 快
        | 0xBDDD // 捷
        | 0xB7BD // 方
        | 0xCABD // 式
        | 0xC4BF // 目
        | 0xC2BC // 录
        | 0xB8B4 // 复
        | 0xD6C6 // 制
        | 0xB7D6 // 分
        | 0xBEED // 卷
        | 0xBAEC // 合
        | 0xB2A2 // 并
        | 0xBEB5 // 镜
        | 0xCFF1 // 像
        | 0xC7FD // 驱
        | 0xB6AF // 动
        | 0xC8ED // 软
        => 100,

        // 2. High frequency Common Hanzi Zone in GB2312 (Level 1 Hanzi: 0xB0A1..=0xD7F9)
        _ if (0xB0..=0xD7).contains(&b0) && (0xA1..=0xFE).contains(&b1) => 60,

        // 3. Level 2 Hanzi in GB2312: (0xD8..=0xF7, 0xA1..=0xFE)
        _ if (0xD8..=0xF7).contains(&b0) && (0xA1..=0xFE).contains(&b1) => 40,

        // 4. Extended GBK User Defined / Rare Char Zone: 0x81..0xFE with 0x40..0xFE
        _ if (0x81..=0xFE).contains(&b0) && ((0x40..=0x7E).contains(&b1) || (0x80..=0xFE).contains(&b1)) => 20,

        _ => 0,
    }
}
