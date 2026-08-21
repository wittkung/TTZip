// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Criterion micro-benchmarks for multi-threaded parallel ZIP compression and extraction.
//!
//! Evaluates speedup curves and throughput across 1, 2, 4, and 8 worker threads for
//! Deflate Level 6, Store, and WinZip AES-256 encrypted archives.

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use ttzip_glue::types::{TTZipEncryptionMethod, TTZipExtractOptions};
use ttzip_glue::zip::{
    assemble_zip_archive, compress_items_parallel, ZipArchive, ZipInputItem,
};

fn generate_zip_test_dataset(total_target_bytes: usize, num_files: usize) -> (Vec<ZipInputItem>, u64) {
    let mut items = Vec::with_capacity(num_files);
    let avg_size = total_target_bytes / num_files;
    let mut total_bytes = 0u64;

    let sample_text = b"Apple Silicon M-Series hardware vector compression dataset for TTZip Native Rust.\n";

    for i in 0..num_files {
        let file_size = if i % 5 == 0 {
            avg_size * 3 // larger files
        } else {
            avg_size / 2 // smaller files
        };

        let mut data = Vec::with_capacity(file_size);
        while data.len() < file_size {
            let chunk = (file_size - data.len()).min(sample_text.len());
            data.extend_from_slice(&sample_text[..chunk]);
        }

        total_bytes += data.len() as u64;

        items.push(ZipInputItem {
            rel_path: format!("folder_{}/file_{:04}.txt", i / 10, i),
            data,
            mtime_epoch_secs: (1700000000 + i * 60) as u32,
            mode: 0o644,
            is_directory: false,
        });
    }

    (items, total_bytes)
}

fn bench_zip_parallel_compression(c: &mut Criterion) {
    let mut group = c.benchmark_group("zip_parallel_compression");
    let (items, total_bytes) = generate_zip_test_dataset(4 * 1024 * 1024, 32); // 4MB across 32 files
    group.throughput(Throughput::Bytes(total_bytes));

    let thread_counts = [1, 2, 4, 8];

    // 1. Deflate Level 6 Parallel Compression
    for &threads in &thread_counts {
        group.bench_with_input(
            BenchmarkId::new("deflate_lvl6", format!("{}threads", threads)),
            &threads,
            |b, &th| {
                b.iter(|| {
                    let compressed = compress_items_parallel(
                        black_box(items.clone()),
                        6,
                        TTZipEncryptionMethod::None,
                        None,
                        th,
                    ).unwrap();
                    let archive_bytes = assemble_zip_archive(&compressed).unwrap();
                    black_box(archive_bytes);
                });
            },
        );
    }

    // 2. WinZip AES-256 Encrypted Parallel Compression
    for &threads in &thread_counts {
        group.bench_with_input(
            BenchmarkId::new("winzip_aes256", format!("{}threads", threads)),
            &threads,
            |b, &th| {
                b.iter(|| {
                    let compressed = compress_items_parallel(
                        black_box(items.clone()),
                        6,
                        TTZipEncryptionMethod::Aes256,
                        Some("EnterpriseSecurePassword2026!"),
                        th,
                    ).unwrap();
                    let archive_bytes = assemble_zip_archive(&compressed).unwrap();
                    black_box(archive_bytes);
                });
            },
        );
    }

    group.finish();
}

fn bench_zip_parallel_extraction(c: &mut Criterion) {
    let mut group = c.benchmark_group("zip_parallel_extraction");
    let (items, total_bytes) = generate_zip_test_dataset(4 * 1024 * 1024, 32);
    group.throughput(Throughput::Bytes(total_bytes));

    // Pre-create unencrypted ZIP archive bytes
    let comp_items = compress_items_parallel(
        items.clone(),
        6,
        TTZipEncryptionMethod::None,
        None,
        4,
    ).unwrap();
    let zip_bytes = assemble_zip_archive(&comp_items).unwrap();

    let thread_counts = [1, 2, 4, 8];

    for &threads in &thread_counts {
        group.bench_with_input(
            BenchmarkId::new("deflate_extract_all", format!("{}threads", threads)),
            &threads,
            |b, &th| {
                let temp_dir = tempfile::tempdir().unwrap();
                let dest_path = temp_dir.path();

                let options = TTZipExtractOptions {
                    destination_path: std::ptr::null(),
                    password: std::ptr::null(),
                    thread_budget: th,
                    overwrite_existing: true,
                    preserve_permissions: false,
                    dry_run: false,
                    progress_callback: None,
                    user_data: std::ptr::null_mut(),
                };

                b.iter(|| {
                    let archive = ZipArchive::open_slice(black_box(&zip_bytes)).unwrap();
                    let report = archive.extract_all(dest_path, &options).unwrap();
                    black_box(report);
                });
            },
        );
    }

    group.finish();
}

criterion_group!(benches, bench_zip_parallel_compression, bench_zip_parallel_extraction);
criterion_main!(benches);
