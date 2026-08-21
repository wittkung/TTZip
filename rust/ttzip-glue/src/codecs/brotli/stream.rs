// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! RAII-governed streaming Brotli compressor and decompressor handle wrappers.

use crate::types::TTZipStatus;
use brotli::{CompressorWriter, Decompressor};
use std::io::{Read, Write};

/// Configuration parameters for Brotli streaming compression.
#[derive(Debug, Clone)]
pub struct BrotliConfig {
    pub quality: u32,
    pub lgwin: u32,
    pub buffer_size: usize,
}

impl Default for BrotliConfig {
    fn default() -> Self {
        Self {
            quality: 6,
            lgwin: 22,
            buffer_size: 65536,
        }
    }
}

/// RAII wrapper around `brotli::CompressorWriter`.
pub struct BrotliCompressorWriter<W: Write> {
    inner: Option<CompressorWriter<W>>,
}

impl<W: Write> BrotliCompressorWriter<W> {
    pub fn new(writer: W, config: &BrotliConfig) -> Self {
        let q = config.quality.clamp(0, 11);
        let lg = if config.lgwin == 0 { 22 } else { config.lgwin.clamp(10, 24) };
        let buf_size = if config.buffer_size == 0 { 65536 } else { config.buffer_size };
        let inner = CompressorWriter::new(writer, buf_size, q, lg);
        Self {
            inner: Some(inner),
        }
    }

    pub fn write_chunk(&mut self, data: &[u8]) -> Result<usize, TTZipStatus> {
        match &mut self.inner {
            Some(w) => w.write(data).map_err(|_| TTZipStatus::ErrCompressionFailed),
            None => Err(TTZipStatus::ErrInvalidParam),
        }
    }

    pub fn finish(mut self) -> Result<W, TTZipStatus> {
        match self.inner.take() {
            Some(w) => Ok(w.into_inner()),
            None => Err(TTZipStatus::ErrInvalidParam),
        }
    }
}

impl<W: Write> Write for BrotliCompressorWriter<W> {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        match &mut self.inner {
            Some(w) => w.write(buf),
            None => Err(std::io::Error::new(std::io::ErrorKind::Other, "closed stream")),
        }
    }

    fn flush(&mut self) -> std::io::Result<()> {
        match &mut self.inner {
            Some(w) => w.flush(),
            None => Ok(()),
        }
    }
}

/// RAII wrapper around `brotli::Decompressor`.
pub struct BrotliDecompressorReader<R: Read> {
    inner: Decompressor<R>,
}

impl<R: Read> BrotliDecompressorReader<R> {
    pub fn new(reader: R, buffer_size: usize) -> Self {
        let buf_size = if buffer_size == 0 { 65536 } else { buffer_size };
        Self {
            inner: Decompressor::new(reader, buf_size),
        }
    }
}

impl<R: Read> Read for BrotliDecompressorReader<R> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        self.inner.read(buf)
    }
}
