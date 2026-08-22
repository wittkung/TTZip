// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: hash / checksum.

use crate::cli::args::HashResultDto;
use std::fs;
use std::path::Path;
use std::time::Instant;
use ttzip_glue::crypto::adler32::adler32_fast;
use ttzip_glue::crypto::crc32::crc32_fast;
use ttzip_glue::crypto::crc64::crc64_fast;
use ttzip_glue::crypto::sha256::FastSha256;

/// Executes headless `hash` subcommand.
pub fn execute_hash(path: &Path, algorithm: &str, json: bool) -> Result<(), String> {
    if !path.exists() {
        return Err(format!("File or archive not found: {}", path.display()));
    }

    let start = Instant::now();
    let data = fs::read(path).map_err(|e| format!("Failed to read target file {}: {}", path.display(), e))?;
    let algo_lower = algorithm.to_lowercase();

    let compute_all = algo_lower == "all";
    let crc32_val = if compute_all || algo_lower == "crc32" {
        Some(format!("0x{:08X}", crc32_fast(0, &data)))
    } else {
        None
    };

    let crc64_val = if compute_all || algo_lower == "crc64" {
        Some(format!("0x{:016X}", crc64_fast(&data)))
    } else {
        None
    };

    let adler32_val = if compute_all || algo_lower == "adler32" {
        Some(format!("0x{:08X}", adler32_fast(1, &data)))
    } else {
        None
    };

    let sha256_val = if compute_all || algo_lower == "sha256" {
        let mut hasher = FastSha256::new();
        hasher.update(&data);
        let digest = hasher.finalize();
        Some(hex_encode(&digest))
    } else {
        None
    };

    let elapsed = start.elapsed().as_millis() as u64;

    if json {
        let dto = HashResultDto {
            target: path.to_string_lossy().to_string(),
            size_bytes: data.len() as u64,
            crc32: crc32_val,
            crc64: crc64_val,
            sha256: sha256_val,
            adler32: adler32_val,
            elapsed_ms: elapsed,
        };

        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize hash JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!("{:=<60}", "");
    println!("  TTZip Checksum & Digest: {}", path.display());
    println!("{:=<60}", "");
    println!("  File Size:  {} bytes", data.len());
    if let Some(ref c32) = crc32_val {
        println!("  CRC-32:     {}", c32);
    }
    if let Some(ref c64) = crc64_val {
        println!("  CRC-64:     {}", c64);
    }
    if let Some(ref adler) = adler32_val {
        println!("  Adler-32:   {}", adler);
    }
    if let Some(ref s256) = sha256_val {
        println!("  SHA-256:    {}", s256);
    }
    println!("  Elapsed:    {} ms", elapsed);
    println!("{:=<60}", "");

    Ok(())
}

fn hex_encode(bytes: &[u8]) -> String {
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        use std::fmt::Write;
        let _ = write!(s, "{:02x}", b);
    }
    s
}
