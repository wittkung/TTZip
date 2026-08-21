// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Multi-core password recovery runner and candidate dispatch pipeline.

use crate::event::AppEvent;
use crossbeam_channel::Sender;
use std::fs;
use std::thread;
use std::time::Instant;
use ttzip_glue::crypto::recovery::{
    recover_7z_aes_rayon, recover_winzip_aes_rayon, recover_zipcrypto_rayon,
};
use ttzip_glue::runtime::cancellation::CancellationToken;
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::zip::parser::parse_local_file_header;
use ttzip_glue::zip::ZipArchive;

/// High-frequency dictionary base word list for built-in attacks.
const BASE_DICTIONARY: &[&str] = &[
    "123456", "password", "12345678", "qwerty", "123456789", "12345", "1234", "111111",
    "1234567", "dragon", "123123", "baseball", "football", "letmein", "monkey", "sunshine",
    "master", "welcome", "shadow", "666666", "123321", "admin", "admin123", "root", "toor",
    "pass", "secret", "ttzip", "macos", "apple", "iloveyou", "princess", "starwars",
    "myspace1", "default", "testing", "trustno1", "superman", "killer", "matrix", "freedom",
    "whatever", "ninja", "mustang", "cheese", "pokemon", "michael", "charlie", "jordan",
    "harley", "robert", "thomas", "daniel", "william", "matthew", "andrew", "donald",
    "joseph", "george", "charles", "edward", "brian", "kevin", "ronald", "anthony",
    "system", "access", "login", "guest", "oracle", "database", "server", "backup",
    "archive", "zip", "encrypted", "qwertyuiop", "asdfghjkl", "zxcvbnm", "000000",
    "11111111", "222222", "333333", "444444", "555555", "777777", "888888", "999999",
    "qwerty123", "password123", "welcome1", "summer2026", "winter2026", "spring2026", "autumn2026",
    "MyWinZipSecret2026", "SecretPassword123", "TestPassword", "test1234", "admin@123",
];

/// Target archive cryptographic verification payload.
#[derive(Debug, Clone)]
pub enum ArchiveRecoveryTarget {
    ZipCrypto {
        enc_header: [u8; 12],
        check_byte: u8,
    },
    WinZipAes {
        salt: [u8; 16],
        stored_pvv: [u8; 2],
    },
    SevenZAes {
        salt: Vec<u8>,
        num_cycles_power: u32,
        probe_cipher: Vec<u8>,
    },
}

/// Generates top high-frequency passwords and variations.
pub fn get_top_passwords() -> Vec<String> {
    let mut words = Vec::with_capacity(BASE_DICTIONARY.len() * 10);
    for &base in BASE_DICTIONARY {
        words.push(base.to_string());
        words.push(format!("{}!", base));
        words.push(format!("{}1", base));
        words.push(format!("{}123", base));
        words.push(format!("{}2026", base));
        words.push(base.to_uppercase());
    }
    words.dedup();
    words
}

/// Generates 4-digit and 6-digit numeric PIN combinations.
pub fn generate_numeric_pins() -> Vec<String> {
    let mut pins = Vec::with_capacity(10_000 + 1_000_000);
    for n in 0..10_000 {
        pins.push(format!("{:04}", n));
    }
    for n in 0..1_000_000 {
        pins.push(format!("{:06}", n));
    }
    pins
}

/// Loads a custom wordlist from local disk path.
pub fn load_custom_wordlist(path: &str) -> Result<Vec<String>, String> {
    let text = fs::read_to_string(path)
        .map_err(|e| format!("Failed to read custom wordlist {}: {}", path, e))?;
    let words: Vec<String> = text
        .lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect();
    if words.is_empty() {
        return Err("Custom dictionary contains no valid words".to_string());
    }
    Ok(words)
}

/// Extracts verification header and salt payload from raw archive buffer.
pub fn extract_recovery_target(raw_data: &[u8], format: &str) -> Result<ArchiveRecoveryTarget, String> {
    if format == "ZIP" {
        let archive = ZipArchive::open_slice(raw_data)
            .map_err(|e| format!("Failed to parse ZIP archive: {:?}", e))?;
        let enc_entry = archive
            .entries()
            .iter()
            .find(|e| e.is_encrypted)
            .ok_or_else(|| "No encrypted entries found in ZIP archive".to_string())?;

        let (payload_offset, _) = parse_local_file_header(raw_data, enc_entry.lfh_offset as usize)
            .map_err(|e| format!("Failed to parse local file header: {:?}", e))?;
        let comp_size = enc_entry.compressed_size as usize;
        if payload_offset + comp_size > raw_data.len() {
            return Err("Corrupted ZIP payload boundary".to_string());
        }
        let raw_payload = &raw_data[payload_offset..payload_offset + comp_size];

        if enc_entry.aes_strength > 0 || enc_entry.compression_method == 99 {
            if raw_payload.len() < 18 {
                return Err("Insufficient WinZip AES payload length".to_string());
            }
            let salt: [u8; 16] = raw_payload[0..16].try_into().map_err(|_| "Salt slice error")?;
            let stored_pvv: [u8; 2] = raw_payload[16..18].try_into().map_err(|_| "PVV slice error")?;
            Ok(ArchiveRecoveryTarget::WinZipAes { salt, stored_pvv })
        } else {
            if raw_payload.len() < 12 {
                return Err("Insufficient ZipCrypto payload length".to_string());
            }
            let enc_header: [u8; 12] = raw_payload[0..12].try_into().map_err(|_| "Header slice error")?;
            let check_byte = (enc_entry.crc32 >> 24) as u8;
            Ok(ArchiveRecoveryTarget::ZipCrypto { enc_header, check_byte })
        }
    } else if format == "7-Zip" {
        let archive = SevenZArchive::open_slice(raw_data)
            .map_err(|e| format!("Failed to open 7z archive: {:?}", e))?;
        let info = archive.info();
        if !info.is_encrypted {
            return Err("7-Zip archive is not password encrypted".to_string());
        }
        let salt = info.aes_salt[..info.aes_salt_len].to_vec();
        let num_cycles_power = info.aes_num_cycles_power;
        let probe_cipher = if info.payload_len > 0 && info.payload_offset + info.payload_len <= raw_data.len() {
            raw_data[info.payload_offset..info.payload_offset + info.payload_len.min(64)].to_vec()
        } else {
            Vec::new()
        };
        Ok(ArchiveRecoveryTarget::SevenZAes {
            salt,
            num_cycles_power,
            probe_cipher,
        })
    } else {
        Err(format!("Password recovery unsupported for format: {}", format))
    }
}

/// Spawns background multi-threaded Rayon worker pool to recover password.
pub fn spawn_recovery_worker(
    target: ArchiveRecoveryTarget,
    words: Vec<String>,
    threads: u32,
    token: CancellationToken,
    event_sender: Sender<AppEvent>,
) {
    thread::spawn(move || {
        let pool = match rayon::ThreadPoolBuilder::new()
            .num_threads(threads.max(1) as usize)
            .build()
        {
            Ok(p) => p,
            Err(e) => {
                let _ = event_sender.send(AppEvent::RecoveryCompleted(Err(format!(
                    "Failed to create Rayon worker pool: {}",
                    e
                ))));
                return;
            }
        };

        let start_time = Instant::now();
        let total_words = words.len();
        let chunk_size = match &target {
            ArchiveRecoveryTarget::SevenZAes { .. } => 100,
            _ => 1000,
        };
        let mut tested_count = 0usize;

        for chunk in words.chunks(chunk_size) {
            if token.is_cancelled() {
                let _ = event_sender.send(AppEvent::RecoveryCompleted(Err(
                    "Recovery cancelled by user".to_string(),
                )));
                return;
            }

            let chunk_refs: Vec<&str> = chunk.iter().map(|s| s.as_str()).collect();
            let found = pool.install(|| match &target {
                ArchiveRecoveryTarget::ZipCrypto { enc_header, check_byte } => {
                    recover_zipcrypto_rayon(&chunk_refs, enc_header, *check_byte)
                }
                ArchiveRecoveryTarget::WinZipAes { salt, stored_pvv } => {
                    recover_winzip_aes_rayon(&chunk_refs, salt, stored_pvv)
                }
                ArchiveRecoveryTarget::SevenZAes { salt, num_cycles_power, probe_cipher } => {
                    recover_7z_aes_rayon(&chunk_refs, salt, *num_cycles_power, probe_cipher, &[])
                }
            });

            tested_count += chunk.len();
            let elapsed = start_time.elapsed().as_secs_f64().max(0.0001);
            let speed = tested_count as f64 / elapsed;
            let eta = if speed > 0.0 && total_words > tested_count {
                (total_words - tested_count) as f64 / speed
            } else {
                0.0
            };

            let _ = event_sender.send(AppEvent::RecoveryProgress {
                tested: tested_count,
                total: total_words,
                speed,
                elapsed_secs: elapsed,
                eta_secs: eta,
            });

            if let Some(pwd) = found {
                let _ = event_sender.send(AppEvent::RecoveryCompleted(Ok(Some(pwd))));
                return;
            }
        }

        let _ = event_sender.send(AppEvent::RecoveryCompleted(Ok(None)));
    });
}

impl crate::app::state::AppState {
    /// Launches the asynchronous password recovery runner with active dictionary.
    pub fn start_recovery_runner(&mut self, event_sender: Sender<AppEvent>) {
        let state = match &mut self.recovery_modal_state {
            Some(s) => s,
            None => return,
        };

        state.is_running = true;
        state.tested_keys = 0;
        state.found_password = None;
        state.status_message = Some("Recovery in progress...".to_string());
        state.error_message = None;

        let words = match state.dict_choice {
            0 => get_top_passwords(),
            1 => generate_numeric_pins(),
            _ => {
                let p = if state.custom_dict_path.is_empty() {
                    &state.dictionary_path
                } else {
                    &state.custom_dict_path
                };
                match load_custom_wordlist(p) {
                    Ok(w) => w,
                    Err(err) => {
                        state.is_running = false;
                        state.error_message = Some(err);
                        return;
                    }
                }
            }
        };

        state.total_keys = words.len();
        self.cancellation_token = CancellationToken::new();
        let token = self.cancellation_token.clone();

        let target = match extract_recovery_target(&self.archive_raw_data, &self.archive_format) {
            Ok(t) => t,
            Err(err) => {
                state.is_running = false;
                state.error_message = Some(err);
                return;
            }
        };

        spawn_recovery_worker(target, words, state.threads, token, event_sender);
    }
}


