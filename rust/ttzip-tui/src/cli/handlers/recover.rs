// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handler: recover (multi-core dictionary attack with real-time speed).

use crate::cli::args::RecoverResultDto;
use crate::cli::format::{detect_archive_format, read_archive_data_auto, ContainerFormat};
use std::fs;
use std::path::Path;
use std::time::Instant;
use ttzip_glue::crypto::recovery::{
    recover_7z_aes_rayon, recover_winzip_aes_rayon, recover_zipcrypto_rayon,
};
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::zip::parser::parse_local_file_header;
use ttzip_glue::zip::ZipArchive;

/// Executes headless `recover` subcommand.
pub fn execute_recover(
    archive_path: &Path,
    dictionary_path: &Path,
    threads_opt: Option<u32>,
    json: bool,
) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }
    if !dictionary_path.exists() {
        return Err(format!(
            "Dictionary file not found: {}",
            dictionary_path.display()
        ));
    }

    let dict_text = fs::read_to_string(dictionary_path)
        .map_err(|e| format!("Failed to read dictionary file: {}", e))?;
    let words: Vec<&str> = dict_text
        .lines()
        .map(|l| l.trim())
        .filter(|l| !l.is_empty())
        .collect();

    if words.is_empty() {
        return Err("Dictionary file contains no valid words".to_string());
    }

    let (_volumes, data) = read_archive_data_auto(archive_path)?;
    let format = detect_archive_format(archive_path, &data);

    let thread_count = threads_opt.unwrap_or_else(|| rayon::current_num_threads().max(1) as u32);
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(thread_count as usize)
        .build()
        .map_err(|e| format!("Failed to build Rayon thread pool: {}", e))?;

    let start_time = Instant::now();
    let total_words = words.len();
    let chunk_size = 5000usize;
    let mut tested_count = 0usize;
    let mut recovered_password: Option<String> = None;

    match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open ZIP archive: {:?}", e))?;
            let enc_entry = archive
                .entries()
                .iter()
                .find(|e| e.is_encrypted)
                .ok_or_else(|| "No encrypted entries found in ZIP archive".to_string())?;

            let (payload_offset, _) = parse_local_file_header(&data, enc_entry.lfh_offset as usize)
                .map_err(|e| format!("Failed to parse local file header: {:?}", e))?;
            let comp_size = enc_entry.compressed_size as usize;
            if payload_offset + comp_size > data.len() {
                return Err("Corrupted ZIP payload boundary".to_string());
            }
            let raw_payload = &data[payload_offset..payload_offset + comp_size];

            if enc_entry.aes_strength > 0 || enc_entry.compression_method == 99 {
                if raw_payload.len() < 18 {
                    return Err("Insufficient WinZip AES payload length".to_string());
                }
                let salt: [u8; 16] = raw_payload[0..16].try_into().unwrap();
                let stored_pvv: [u8; 2] = raw_payload[16..18].try_into().unwrap();

                for chunk in words.chunks(chunk_size) {
                    let found = pool.install(|| {
                        recover_winzip_aes_rayon(chunk, &salt, &stored_pvv)
                    });
                    tested_count += chunk.len();

                    let elapsed_secs = start_time.elapsed().as_secs_f64().max(0.0001);
                    let speed = tested_count as f64 / elapsed_secs;

                    if !json {
                        let pct = (tested_count as f64 / total_words as f64) * 100.0;
                        print!(
                            "\r[Recovering WinZip AES-256] {:.1}% ({}/{} keys) - Speed: {:.0} keys/s",
                            pct, tested_count, total_words, speed
                        );
                        let _ = std::io::Write::flush(&mut std::io::stdout());
                    }

                    if let Some(pwd) = found {
                        recovered_password = Some(pwd);
                        break;
                    }
                }
            } else {
                if raw_payload.len() < 12 {
                    return Err("Insufficient ZipCrypto payload length".to_string());
                }
                let enc_header: [u8; 12] = raw_payload[0..12].try_into().unwrap();
                let check_byte = (enc_entry.crc32 >> 24) as u8;

                for chunk in words.chunks(chunk_size) {
                    let found = pool.install(|| {
                        recover_zipcrypto_rayon(chunk, &enc_header, check_byte)
                    });
                    tested_count += chunk.len();

                    let elapsed_secs = start_time.elapsed().as_secs_f64().max(0.0001);
                    let speed = tested_count as f64 / elapsed_secs;

                    if !json {
                        let pct = (tested_count as f64 / total_words as f64) * 100.0;
                        print!(
                            "\r[Recovering ZipCrypto] {:.1}% ({}/{} keys) - Speed: {:.0} keys/s",
                            pct, tested_count, total_words, speed
                        );
                        let _ = std::io::Write::flush(&mut std::io::stdout());
                    }

                    if let Some(pwd) = found {
                        recovered_password = Some(pwd);
                        break;
                    }
                }
            }
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open 7z archive: {:?}", e))?;
            let info = archive.info();
            if !info.is_encrypted {
                return Err("7-Zip archive is not password encrypted".to_string());
            }

            let salt = &info.aes_salt[..info.aes_salt_len];
            let num_cycles_power = info.aes_num_cycles_power;
            let probe_slice = if info.payload_len > 0 && info.payload_offset + info.payload_len <= data.len() {
                &data[info.payload_offset..info.payload_offset + info.payload_len.min(64)]
            } else {
                &[]
            };

            for chunk in words.chunks(chunk_size.min(1000)) {
                let found = pool.install(|| {
                    recover_7z_aes_rayon(chunk, salt, num_cycles_power, probe_slice, &[])
                });
                tested_count += chunk.len();

                let elapsed_secs = start_time.elapsed().as_secs_f64().max(0.0001);
                let speed = tested_count as f64 / elapsed_secs;

                if !json {
                    let pct = (tested_count as f64 / total_words as f64) * 100.0;
                    print!(
                        "\r[Recovering 7z AES-256] {:.1}% ({}/{} keys) - Speed: {:.0} keys/s",
                        pct, tested_count, total_words, speed
                    );
                    let _ = std::io::Write::flush(&mut std::io::stdout());
                }

                if let Some(pwd) = found {
                    recovered_password = Some(pwd);
                    break;
                }
            }
        }
        _ => {
            return Err(format!(
                "Password recovery not supported for format: {}",
                format.name()
            ));
        }
    }

    let elapsed = start_time.elapsed();
    let elapsed_ms = elapsed.as_millis() as u64;
    let elapsed_secs = elapsed.as_secs_f64().max(0.0001);
    let speed_keys_per_sec = tested_count as f64 / elapsed_secs;

    if json {
        let dto = RecoverResultDto {
            archive: archive_path.to_string_lossy().to_string(),
            recovered: recovered_password.is_some(),
            password: recovered_password,
            total_tested: tested_count,
            elapsed_ms,
            speed_keys_per_sec,
        };
        let json_str = serde_json::to_string_pretty(&dto)
            .map_err(|e| format!("Failed to serialize recovery JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!(); // Clear progress line
    if let Some(ref pwd) = recovered_password {
        println!("{:=<80}", "");
        println!("TTZip Password Recovery: SUCCESS");
        println!("{:=<80}", "");
        println!("Archive:        {}", archive_path.display());
        println!("Password Found: \"{}\"", pwd);
        println!("Keys Tested:    {} / {}", tested_count, total_words);
        println!("Speed:          {:.0} keys/s", speed_keys_per_sec);
        println!("Duration:       {:.2?}", elapsed);
        println!("{:=<80}", "");
    } else {
        println!("{:=<80}", "");
        println!("TTZip Password Recovery: FAILED");
        println!("{:=<80}", "");
        println!("Archive:        {}", archive_path.display());
        println!("Status:         Password not found in dictionary");
        println!("Keys Tested:    {} / {}", tested_count, total_words);
        println!("Speed:          {:.0} keys/s", speed_keys_per_sec);
        println!("Duration:       {:.2?}", elapsed);
        println!("{:=<80}", "");
    }

    Ok(())
}
