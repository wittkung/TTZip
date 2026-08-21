// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Stream adapter unit tests.

use super::*;
use std::io::{Cursor, SeekFrom};

#[test]
fn test_stream_reader_state_reading() {
    let sample_data = b"Hello, TTZip streaming micro-buffer pipeline!";
    let cursor = Cursor::new(sample_data.to_vec());
    let mut state = StreamReaderState::new(cursor, 16);

    let (ptr, len) = state.read_chunk().expect("read_chunk should succeed");
    assert_eq!(len, sample_data.len());
    let slice = unsafe { std::slice::from_raw_parts(ptr, len) };
    assert_eq!(&slice[..sample_data.len()], sample_data);
    assert_eq!(state.bytes_consumed, sample_data.len() as u64);

    let (_, len2) = state.read_chunk().expect("read_chunk at EOF");
    assert_eq!(len2, 0);
    assert!(state.is_eof);
}

#[test]
fn test_stream_reader_state_seek_and_skip() {
    let sample_data = b"0123456789ABCDEF";
    let cursor = Cursor::new(sample_data.to_vec());
    let mut state = StreamReaderState::new(cursor, 64 * 1024);

    let skipped = state.skip(4).expect("skip forward");
    assert_eq!(skipped, 4);

    let new_pos = state.seek(SeekFrom::Start(10)).expect("seek to 10");
    assert_eq!(new_pos, 10);

    let new_pos2 = state.seek(SeekFrom::End(-2)).expect("seek from end");
    assert_eq!(new_pos2, 14);
}

#[test]
fn test_stream_writer_state_writing() {
    let mut output = Vec::new();
    let mut state = StreamWriterState::new(&mut output, 64 * 1024);

    let chunk1 = b"Chunk 1: Hello World; ";
    let chunk2 = b"Chunk 2: TTZip Rust Glue!";
    let n1 = state.write_chunk(chunk1).expect("write chunk 1");
    let n2 = state.write_chunk(chunk2).expect("write chunk 2");

    assert_eq!(n1, chunk1.len());
    assert_eq!(n2, chunk2.len());
    assert_eq!(state.bytes_written, (chunk1.len() + chunk2.len()) as u64);
    assert_eq!(output, [chunk1.as_slice(), chunk2.as_slice()].concat());
}

#[test]
fn test_read_callback_trampoline_panic_catch() {
    unsafe {
        let res = archive_read_callback_trampoline::<Cursor<Vec<u8>>>(
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            std::ptr::null_mut(),
        );
        assert_eq!(res, ARCHIVE_FATAL as libc::ssize_t);
    }
}

#[test]
fn test_seek_callback_trampoline_panic_catch() {
    unsafe {
        let res = archive_seek_callback_trampoline::<Cursor<Vec<u8>>>(
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            0,
            libc::SEEK_SET,
        );
        assert_eq!(res, ARCHIVE_FATAL as i64);
    }
}
