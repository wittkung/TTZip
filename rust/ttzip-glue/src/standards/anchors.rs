// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Format sniffing anchor points.
//!
//! Provides offset resolution for head-based, tail-based, sector-based,
//! and TAR-relative archive magic signatures.

/// Classification of signature anchor locations within binary streams.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Anchor {
    /// Fixed offset from stream start (e.g. offset 0 for standard headers).
    Head(usize),
    /// Fixed offset relative to stream end (e.g. 512 bytes for DMG 'koly' trailer).
    Tail(usize),
    /// Sector-aligned offset (e.g. Sector 16 = 32,768 bytes for ISO 9660).
    Sector(usize),
    /// Offset relative to a 512-byte TAR block (e.g. offset 257 for "ustar").
    TarOffset(usize),
}

impl Anchor {
    /// Resolves the absolute byte offset within a stream of total length `stream_len`.
    ///
    /// Returns `None` if the computed offset or signature window exceeds `stream_len`.
    #[inline]
    pub fn resolve_offset(self, stream_len: usize, match_len: usize) -> Option<usize> {
        if match_len > stream_len {
            return None;
        }

        match self {
            Anchor::Head(offset) => {
                if offset.checked_add(match_len)? <= stream_len {
                    Some(offset)
                } else {
                    None
                }
            }
            Anchor::Tail(tail_dist) => {
                if tail_dist >= match_len && tail_dist <= stream_len {
                    Some(stream_len - tail_dist)
                } else {
                    None
                }
            }
            Anchor::Sector(sector_idx) => {
                let sector_offset = sector_idx.checked_mul(2048)?;
                if sector_offset.checked_add(match_len)? <= stream_len {
                    Some(sector_offset)
                } else {
                    None
                }
            }
            Anchor::TarOffset(offset) => {
                if offset < 512 && offset.checked_add(match_len)? <= stream_len {
                    Some(offset)
                } else {
                    None
                }
            }
        }
    }

    /// Attempts to extract a slice matching this anchor from `buffer`.
    #[inline]
    pub fn slice_buffer<'a>(self, buffer: &'a [u8], match_len: usize) -> Option<&'a [u8]> {
        let offset = self.resolve_offset(buffer.len(), match_len)?;
        buffer.get(offset..offset + match_len)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_head_anchor_resolution() {
        let anchor = Anchor::Head(4);
        assert_eq!(anchor.resolve_offset(10, 4), Some(4));
        assert_eq!(anchor.resolve_offset(7, 4), None);
        assert_eq!(anchor.resolve_offset(8, 4), Some(4));
    }

    #[test]
    fn test_tail_anchor_resolution() {
        let anchor = Anchor::Tail(512);
        assert_eq!(anchor.resolve_offset(1024, 4), Some(512));
        assert_eq!(anchor.resolve_offset(512, 4), Some(0));
        assert_eq!(anchor.resolve_offset(511, 4), None);
    }

    #[test]
    fn test_sector_anchor_resolution() {
        let anchor = Anchor::Sector(16); // 16 * 2048 = 32768
        assert_eq!(anchor.resolve_offset(40000, 5), Some(32768));
        assert_eq!(anchor.resolve_offset(32768 + 5, 5), Some(32768));
        assert_eq!(anchor.resolve_offset(32768, 5), None);
    }

    #[test]
    fn test_tar_offset_anchor_resolution() {
        let anchor = Anchor::TarOffset(257);
        assert_eq!(anchor.resolve_offset(512, 5), Some(257));
        assert_eq!(anchor.resolve_offset(260, 5), None);
    }

    #[test]
    fn test_slice_buffer_success_and_overflow() {
        let data = b"0123456789ABCDEF";
        assert_eq!(Anchor::Head(2).slice_buffer(data, 4), Some(&b"2345"[..]));
        assert_eq!(Anchor::Tail(6).slice_buffer(data, 4), Some(&b"ABCD"[..]));
        assert_eq!(Anchor::Head(14).slice_buffer(data, 4), None);
    }
}
