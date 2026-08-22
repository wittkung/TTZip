// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! In-memory multi-modal synthetic benchmark corpus generators.
//!
//! Generates deterministic datasets representing Calgary, Silesia, XML, Random, and Binary patterns.

use serde::{Deserialize, Serialize};

/// Target corpus types for matrix benchmarking.
#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum BenchmarkCorpusType {
    Calgary = 0,
    Silesia = 1,
    Xml = 2,
    Random = 3,
    Binary = 4,
}

impl BenchmarkCorpusType {
    pub fn from_i32(val: i32) -> Self {
        match val {
            0 => Self::Calgary,
            1 => Self::Silesia,
            2 => Self::Xml,
            3 => Self::Random,
            4 => Self::Binary,
            _ => Self::Silesia,
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            Self::Calgary => "Calgary (English Text & Source)",
            Self::Silesia => "Silesia (Multi-Modal Mixed)",
            Self::Xml => "XML (Structured Markup & JSON)",
            Self::Random => "Random (High Entropy Noise)",
            Self::Binary => "Binary (Machine Code & Structs)",
        }
    }
}

/// Deterministic in-memory synthetic corpus builder.
pub struct BenchmarkCorpusGenerator;

impl BenchmarkCorpusGenerator {
    /// Generates deterministic synthetic corpus buffer matching the requested type and size.
    pub fn generate(corpus_type: BenchmarkCorpusType, size: usize) -> Vec<u8> {
        let size = size.max(1024);
        match corpus_type {
            BenchmarkCorpusType::Calgary => Self::generate_calgary(size),
            BenchmarkCorpusType::Silesia => Self::generate_silesia(size),
            BenchmarkCorpusType::Xml => Self::generate_xml(size),
            BenchmarkCorpusType::Random => Self::generate_random(size),
            BenchmarkCorpusType::Binary => Self::generate_binary(size),
        }
    }

    fn generate_calgary(size: usize) -> Vec<u8> {
        const SEED_TEXT: &[u8] = b"The Calgary Corpus is a collection of text and binary data files \
            used for comparing data compression algorithms. Collected in 1987 by Ian Witten, Timothy Bell, \
            and John Cleary from the University of Calgary, it consists of fourteen files representing \
            various data types including English prose, technical papers, bibliography data, source code in C \
            and Pascal, transscript outputs, and object code.\n\
            struct Node { int key; struct Node *next; char label[32]; };\n\
            while (ptr != NULL) { if (ptr->key == target) return ptr; ptr = ptr->next; }\n";

        let mut buf = Vec::with_capacity(size);
        while buf.len() < size {
            let rem = size - buf.len();
            let chunk = rem.min(SEED_TEXT.len());
            buf.extend_from_slice(&SEED_TEXT[..chunk]);
        }
        buf
    }

    fn generate_silesia(size: usize) -> Vec<u8> {
        const SEED_PROSE: &[u8] = b"<!DOCTYPE html><html><head><title>Silesia Corpus</title></head>\
            <body><h1>Multi-modal compression corpus</h1><p>Contains HTML, dictionary databases, \
            medical image slices, binaries, and source code archives.</p>";
        const SEED_CODE: &[u8] = b"fn process_stream(data: &[u8]) -> usize { \
            let mut crc = 0xFFFFFFFFu32; for &b in data { crc = (crc >> 8) ^ TABLE[(crc as u8 ^ b) as usize]; } crc }\n";
        const SEED_BIN: &[u8] = &[0x55, 0x48, 0x89, 0xE5, 0x48, 0x83, 0xEC, 0x20, 0x89, 0x7D, 0xEC, 0x48, 0x8B, 0x45, 0xF8];

        let mut buf = Vec::with_capacity(size);
        let mut toggle = 0;
        while buf.len() < size {
            let chunk: &[u8] = match toggle % 3 {
                0 => SEED_PROSE,
                1 => SEED_CODE,
                _ => SEED_BIN,
            };
            toggle += 1;
            let rem = size - buf.len();
            let c_len = rem.min(chunk.len());
            buf.extend_from_slice(&chunk[..c_len]);
        }
        buf
    }

    fn generate_xml(size: usize) -> Vec<u8> {
        const XML_HEADER: &[u8] = b"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root version=\"2.0\">\n";
        let mut buf = Vec::with_capacity(size);
        buf.extend_from_slice(XML_HEADER);

        let mut id = 1000u32;
        while buf.len() < size {
            let record = format!(
                "  <record id=\"{}\" status=\"active\" timestamp=\"2026-08-22T08:00:00Z\">\n    \
                    <title>Benchmark Payload Data Unit {}</title>\n    \
                    <attributes compression=\"high\" level=\"9\" algorithm=\"deflate\"/>\n    \
                    <value metric=\"throughput_mb_s\">1420.50</value>\n  \
                 </record>\n",
                id, id
            );
            id += 1;
            let rem = size - buf.len();
            let bytes = record.as_bytes();
            let c_len = rem.min(bytes.len());
            buf.extend_from_slice(&bytes[..c_len]);
        }
        buf
    }

    fn generate_random(size: usize) -> Vec<u8> {
        let mut buf = vec![0u8; size];
        let mut state: u64 = 0x853c49e65ed8de24;
        for chunk in buf.chunks_mut(8) {
            state = state.wrapping_add(0x9e3779b97f4a7c15);
            let mut z = state;
            z = (z ^ (z >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
            z = (z ^ (z >> 27)).wrapping_mul(0x94d049bb133111eb);
            let rand_val = z ^ (z >> 31);
            let bytes = rand_val.to_le_bytes();
            let c_len = chunk.len().min(8);
            chunk[..c_len].copy_from_slice(&bytes[..c_len]);
        }
        buf
    }

    fn generate_binary(size: usize) -> Vec<u8> {
        let mut buf = Vec::with_capacity(size);
        buf.extend_from_slice(&[0xCF, 0xFA, 0xED, 0xFE, 0x0C, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]);
        let arm_instructions = [
            0xD503201F_u32, // nop
            0xD65F03C0_u32, // ret
            0x910003FD_u32, // mov x29, sp
            0xA9BF7BFD_u32, // stp x29, x30, [sp, #-16]!
            0xA8C17BFD_u32, // ldp x29, x30, [sp], #16
        ];
        let mut idx = 0;
        while buf.len() < size {
            let instr = arm_instructions[idx % arm_instructions.len()];
            idx += 1;
            let bytes = instr.to_le_bytes();
            let rem = size - buf.len();
            let c_len = rem.min(4);
            buf.extend_from_slice(&bytes[..c_len]);
        }
        buf
    }
}
