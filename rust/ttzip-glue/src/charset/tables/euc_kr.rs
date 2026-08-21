// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-frequency Korean Hangul syllable and bigram distribution tables for EUC-KR / CP949.

/// Returns a frequency weight (0..=100) for a 2-byte EUC-KR/CP949 sequence `[b0, b1]`.
pub fn score_euc_kr_2byte(b0: u8, b1: u8) -> u32 {
    let code = ((b0 as u16) << 8) | (b1 as u16);

    // 1. Top ultra-high frequency Korean syllables
    match code {
        0xB0A1 // 가
        | 0xB0ED // 고
        | 0xB1A3 // 과
        | 0xB1B8 // 구
        | 0xB1D7 // 그
        | 0xB1E2 // 기
        | 0xB2D9 // 나
        | 0xB4C2 // 는
        | 0xB4D9 // 다
        | 0xB5B5 // 도
        | 0xB5C8 // 된
        | 0xB7CE // 로
        | 0xB8A6 // 를
        | 0xB8AE // 리
        | 0xB8B8 // 만
        | 0xB8F0 // 모
        | 0xB9AB // 무
        | 0xB9AE // 문
        | 0xBCAD // 서
        | 0xBDC3 // 수
        | 0xBDBA // 스
        | 0xBFCD // 시
        | 0xC0A7 // 에
        | 0xC0E7 // 여
        | 0xC0EB // 연
        | 0xC1A4 // 오
        | 0xC1CD // 와
        | 0xC1DF // 요
        | 0xC1EB // 용
        | 0xC2A5 // 우
        | 0xC3A1 // 원
        | 0xC3E0 // 유
        | 0xC7B8 // 으
        | 0xC7BA // 은
        | 0xC7BB // 을
        | 0xC7BD // 음
        | 0xC7C7 // 응
        | 0xC7CC // 이
        | 0xC7CE // 인
        | 0xC7CF // 일
        | 0xC7D6 // 있
        | 0xC7DA // 자
        | 0xC7E5 // 장
        | 0xC7EC // 재
        | 0xC8A1 // 저
        | 0xC8A4 // 전
        | 0xC8A6 // 제
        | 0xC8B6 // 조
        | 0xC8F6 // 지
        | 0xC8F9 // 진
        | 0xC6D0 // 파
        | 0xC6F8 // 트
        | 0xC7D1 // 한
        | 0xB1B9 // 국
        | 0xC0EE // 어
        | 0xC8A3 // 화
        | 0xBEC8 // 안
        | 0xB3E7 // 녕
        | 0xBCBC // 세
        | 0xBD80 // 부
        | 0xB0FD // 개
        | 0xB3D7 // 네
        => 100,

        // 2. Standard KS X 1001 Hangul Syllable Zone (0xB0A1..=0xC8FE)
        _ if (0xB0..=0xC8).contains(&b0) && (0xA1..=0xFE).contains(&b1) => 70,

        // 3. Extended CP949 Hangul Syllables (0x81..0xA0 and non-standard range)
        _ if (0x81..=0xFE).contains(&b0) && ((0x41..=0x5A).contains(&b1) || (0x61..=0x7A).contains(&b1) || (0x81..=0xFE).contains(&b1)) => 30,

        _ => 0,
    }
}
