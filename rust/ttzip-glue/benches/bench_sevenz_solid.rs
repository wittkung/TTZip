// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Criterion micro-benchmarks for 7z Solid archive on-demand selective entry extraction latency.
//!
//! Evaluates random single-entry slice extraction response time across early, middle, and tail
//! positions in solid streams of varying sizes (10, 50 entries) for LZMA2.

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion};
use ttzip_glue::sevenz::{create_7z_solid_archive_bytes, SevenZArchive};
use ttzip_glue::zip::writer::ZipInputItem;

fn generate_7z_solid_dataset(num_entries: usize, entry_size: usize) -> Vec<ZipInputItem> {
    let mut items = Vec::with_capacity(num_entries);
    let sample = b"TTZip 7z Solid on-demand streaming random access latency verification dataset 2026.\n";

    for i in 0..num_entries {
        let mut data = Vec::with_capacity(entry_size);
        while data.len() < entry_size {
            let chunk = (entry_size - data.len()).min(sample.len());
            data.extend_from_slice(&sample[..chunk]);
        }

        items.push(ZipInputItem {
            rel_path: format!("solid_dir/entry_{:03}.dat", i),
            data,
            mtime_epoch_secs: (1700000000 + i * 10) as u32,
            mode: 0o644,
            is_directory: false,
        });
    }

    items
}

fn bench_sevenz_selective_extraction_latency(c: &mut Criterion) {
    let mut group = c.benchmark_group("sevenz_solid_selective_latency");

    // Test with 10-entry archive and 50-entry archive (each entry 32KB)
    for &num_entries in &[10, 50] {
        let items = generate_7z_solid_dataset(num_entries, 32 * 1024);
        let archive_bytes = create_7z_solid_archive_bytes(&items, 3, 2).expect("create 7z solid");

        // Benchmark opening metadata header
        group.bench_with_input(
            BenchmarkId::new("open_metadata", format!("{}_entries", num_entries)),
            &archive_bytes,
            |b, bytes| {
                b.iter(|| {
                    let archive = SevenZArchive::open_slice(black_box(bytes)).unwrap();
                    black_box(archive.len());
                });
            },
        );

        let positions = [
            ("first_entry", 0),
            ("middle_entry", num_entries / 2),
            ("last_entry", num_entries - 1),
        ];

        for (pos_name, entry_idx) in positions {
            group.bench_with_input(
                BenchmarkId::new(
                    format!("extract_{}", pos_name),
                    format!("{}_entries", num_entries),
                ),
                &archive_bytes,
                |b, bytes| {
                    b.iter(|| {
                        let archive = SevenZArchive::open_slice(black_box(bytes)).unwrap();
                        let entry_data = archive.extract_entry_bytes(entry_idx, None).unwrap();
                        black_box(entry_data);
                    });
                },
            );
        }
    }

    group.finish();
}

criterion_group!(benches, bench_sevenz_selective_extraction_latency);
criterion_main!(benches);
