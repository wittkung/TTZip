// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Criterion micro-benchmarks for single-core compression and decompression codecs.
//!
//! Measures MB/s throughput across `libdeflate`, `zstd`, `fast-lzma2`, `snappy`, `lz4`, and Apple `lzfse`
//! on standard realistic compressible data blocks (64KB, 1MB).

use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use ttzip_glue::codecs::{
    deflate::{deflate_compress, deflate_compress_bound, deflate_decompress},
    fast_blocks::{
        lz4_compress, lz4_compress_bound, lz4_decompress, lzfse_compress, lzfse_decompress,
        snappy_compress, snappy_decompress, snappy_max_compressed_length,
    },
    lzma2::{fl2_compress, fl2_compress_bound, fl2_decompress},
    zstd::{zstd_compress, zstd_compress_bound, zstd_decompress},
};

fn generate_realistic_compressible_corpus(size: usize) -> Vec<u8> {
    let source_text = b"TTZip High-Performance Archiving Engine for macOS. \
        Features Safe Rust core, hardware NEON vector acceleration, libdeflate, \
        Facebook Zstandard, fast-lzma2 multi-threading, Apple LZFSE, Snappy, and LZ4. \
        {\"status\": 200, \"engine\": \"ttzip-glue\", \"version\": \"1.0.0\", \"arch\": \"aarch64\"}\n";
    let mut out = Vec::with_capacity(size);
    while out.len() < size {
        let rem = size - out.len();
        let chunk_len = rem.min(source_text.len());
        out.extend_from_slice(&source_text[..chunk_len]);
    }
    out
}

fn bench_libdeflate(c: &mut Criterion) {
    let mut group = c.benchmark_group("codec_libdeflate_single_core");
    let sizes = [64 * 1024, 1024 * 1024];
    let levels = [1, 6, 9, 12];

    for &size in &sizes {
        let corpus = generate_realistic_compressible_corpus(size);
        group.throughput(Throughput::Bytes(size as u64));

        for &level in &levels {
            let mut comp_buf = vec![0u8; deflate_compress_bound(size, level) + 1024];
            let comp_len = deflate_compress(&corpus, &mut comp_buf, level).expect("compress");
            let comp_data = comp_buf[..comp_len].to_vec();

            // Benchmark Compression
            group.bench_with_input(
                BenchmarkId::new(format!("deflate_compress_lvl{}", level), size),
                &corpus,
                |b, data| {
                    b.iter(|| {
                        black_box(deflate_compress(black_box(data), black_box(&mut comp_buf), level)).unwrap();
                    });
                },
            );

            // Benchmark Decompression
            let mut decomp_buf = vec![0u8; size];
            group.bench_with_input(
                BenchmarkId::new(format!("deflate_decompress_lvl{}", level), size),
                &comp_data,
                |b, cdata| {
                    b.iter(|| {
                        black_box(deflate_decompress(black_box(cdata), black_box(&mut decomp_buf))).unwrap();
                    });
                },
            );
        }
    }

    group.finish();
}

fn bench_zstd(c: &mut Criterion) {
    let mut group = c.benchmark_group("codec_zstd_single_core");
    let sizes = [64 * 1024, 1024 * 1024];
    let levels = [1, 3, 7, 15];

    for &size in &sizes {
        let corpus = generate_realistic_compressible_corpus(size);
        group.throughput(Throughput::Bytes(size as u64));

        for &level in &levels {
            let mut comp_buf = vec![0u8; zstd_compress_bound(size) + 1024];
            let comp_len = zstd_compress(&corpus, &mut comp_buf, level).expect("zstd compress");
            let comp_data = comp_buf[..comp_len].to_vec();

            // Benchmark Compression
            group.bench_with_input(
                BenchmarkId::new(format!("zstd_compress_lvl{}", level), size),
                &corpus,
                |b, data| {
                    b.iter(|| {
                        black_box(zstd_compress(black_box(data), black_box(&mut comp_buf), level)).unwrap();
                    });
                },
            );

            // Benchmark Decompression
            let mut decomp_buf = vec![0u8; size];
            group.bench_with_input(
                BenchmarkId::new(format!("zstd_decompress_lvl{}", level), size),
                &comp_data,
                |b, cdata| {
                    b.iter(|| {
                        black_box(zstd_decompress(black_box(cdata), black_box(&mut decomp_buf))).unwrap();
                    });
                },
            );
        }
    }

    group.finish();
}

fn bench_fast_lzma2(c: &mut Criterion) {
    let mut group = c.benchmark_group("codec_fast_lzma2_single_core");
    let sizes = [64 * 1024, 1024 * 1024];
    let levels = [1, 3, 6];

    for &size in &sizes {
        let corpus = generate_realistic_compressible_corpus(size);
        group.throughput(Throughput::Bytes(size as u64));

        for &level in &levels {
            let mut comp_buf = vec![0u8; fl2_compress_bound(size) + 4096];
            let comp_len = fl2_compress(&corpus, &mut comp_buf, level, 1).expect("fl2 compress");
            let comp_data = comp_buf[..comp_len].to_vec();

            // Benchmark Compression (Single Core threads=1)
            group.bench_with_input(
                BenchmarkId::new(format!("fl2_compress_lvl{}", level), size),
                &corpus,
                |b, data| {
                    b.iter(|| {
                        black_box(fl2_compress(black_box(data), black_box(&mut comp_buf), level, 1)).unwrap();
                    });
                },
            );

            // Benchmark Decompression
            let mut decomp_buf = vec![0u8; size];
            group.bench_with_input(
                BenchmarkId::new(format!("fl2_decompress_lvl{}", level), size),
                &comp_data,
                |b, cdata| {
                    b.iter(|| {
                        black_box(fl2_decompress(black_box(cdata), black_box(&mut decomp_buf), 1)).unwrap();
                    });
                },
            );
        }
    }

    group.finish();
}

fn bench_ultra_fast_codecs(c: &mut Criterion) {
    let mut group = c.benchmark_group("codec_fast_blocks");
    let sizes = [64 * 1024, 1024 * 1024];

    for &size in &sizes {
        let corpus = generate_realistic_compressible_corpus(size);
        group.throughput(Throughput::Bytes(size as u64));

        // 1. Snappy
        {
            let mut comp_buf = vec![0u8; snappy_max_compressed_length(size) + 1024];
            let comp_len = snappy_compress(&corpus, &mut comp_buf).expect("snappy compress");
            let comp_data = comp_buf[..comp_len].to_vec();

            group.bench_with_input(BenchmarkId::new("snappy_compress", size), &corpus, |b, data| {
                b.iter(|| {
                    black_box(snappy_compress(black_box(data), black_box(&mut comp_buf))).unwrap();
                });
            });

            let mut decomp_buf = vec![0u8; size];
            group.bench_with_input(BenchmarkId::new("snappy_decompress", size), &comp_data, |b, cdata| {
                b.iter(|| {
                    black_box(snappy_decompress(black_box(cdata), black_box(&mut decomp_buf))).unwrap();
                });
            });
        }

        // 2. LZ4
        {
            let mut comp_buf = vec![0u8; lz4_compress_bound(size) + 1024];
            let comp_len = lz4_compress(&corpus, &mut comp_buf).expect("lz4 compress");
            let comp_data = comp_buf[..comp_len].to_vec();

            group.bench_with_input(BenchmarkId::new("lz4_compress", size), &corpus, |b, data| {
                b.iter(|| {
                    black_box(lz4_compress(black_box(data), black_box(&mut comp_buf))).unwrap();
                });
            });

            let mut decomp_buf = vec![0u8; size];
            group.bench_with_input(BenchmarkId::new("lz4_decompress", size), &comp_data, |b, cdata| {
                b.iter(|| {
                    black_box(lz4_decompress(black_box(cdata), black_box(&mut decomp_buf))).unwrap();
                });
            });
        }

        // 3. LZFSE (Apple)
        {
            let mut comp_buf = vec![0u8; size + 4096];
            let comp_len = lzfse_compress(&corpus, &mut comp_buf).expect("lzfse compress");
            let comp_data = comp_buf[..comp_len].to_vec();

            group.bench_with_input(BenchmarkId::new("lzfse_compress", size), &corpus, |b, data| {
                b.iter(|| {
                    black_box(lzfse_compress(black_box(data), black_box(&mut comp_buf))).unwrap();
                });
            });

            let mut decomp_buf = vec![0u8; size];
            group.bench_with_input(BenchmarkId::new("lzfse_decompress", size), &comp_data, |b, cdata| {
                b.iter(|| {
                    black_box(lzfse_decompress(black_box(cdata), black_box(&mut decomp_buf))).unwrap();
                });
            });
        }
    }

    group.finish();
}

criterion_group!(benches, bench_libdeflate, bench_zstd, bench_fast_lzma2, bench_ultra_fast_codecs);
criterion_main!(benches);
