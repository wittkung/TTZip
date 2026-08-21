// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

fn compile_native_codecs(repo_root: &Path, out_dir: &Path, target: &str) {
    let fast_lzma2_dir = repo_root.join("Sources/CTTZipBridge/fast-lzma2");
    let lzfse_dir = repo_root.join("Sources/CTTZipBridge/lzfse");
    let snappy_dir = repo_root.join("Sources/CTTZipBridge/snappy");

    if !fast_lzma2_dir.exists() || !lzfse_dir.exists() || !snappy_dir.exists() {
        return;
    }

    let mut obj_files = Vec::new();

    // Compile threadpool C source
    let bridge_dir = repo_root.join("Sources/CTTZipBridge");
    let threadpool_src = bridge_dir.join("ttzip_threadpool.c");
    if threadpool_src.exists() {
        let obj_path = out_dir.join("ttzip_threadpool.o");
        let status = Command::new("clang")
            .args(["-O3", "-c", "-target", target, "-mmacosx-version-min=14.0", "-I", bridge_dir.to_str().unwrap(), "-I", bridge_dir.join("include").to_str().unwrap()])
            .arg(&threadpool_src)
            .arg("-o")
            .arg(&obj_path)
            .status()
            .expect("Failed to compile ttzip_threadpool.c");
        assert!(status.success(), "Failed compiling ttzip_threadpool.c");
        obj_files.push(obj_path);
    }

    // Compile fast-lzma2 C files
    let fl2_sources = [
        "dict_buffer.c",
        "fl2_common.c",
        "fl2_compress.c",
        "fl2_decompress.c",
        "fl2_pool.c",
        "fl2_threading.c",
        "lzma2_dec.c",
        "lzma2_enc.c",
        "radix_bitpack.c",
        "radix_mf.c",
        "radix_struct.c",
        "range_enc.c",
        "util.c",
        "xxhash.c",
    ];
    for src in fl2_sources {
        let src_path = fast_lzma2_dir.join(src);
        if !src_path.exists() {
            continue;
        }
        let obj_path = out_dir.join(format!("fl2_{}.o", src));
        let status = Command::new("clang")
            .args(["-O3", "-c", "-target", target, "-mmacosx-version-min=14.0", "-I", fast_lzma2_dir.to_str().unwrap()])
            .arg(&src_path)
            .arg("-o")
            .arg(&obj_path)
            .status()
            .expect("Failed to compile fast-lzma2 source");
        assert!(status.success(), "Failed compiling {}", src);
        obj_files.push(obj_path);
    }

    // Compile lzfse C files
    let lzfse_sources = [
        "lzfse_decode.c",
        "lzfse_decode_base.c",
        "lzfse_encode.c",
        "lzfse_encode_base.c",
        "lzfse_fse.c",
        "lzvn_decode_base.c",
        "lzvn_encode_base.c",
    ];
    for src in lzfse_sources {
        let src_path = lzfse_dir.join(src);
        if !src_path.exists() {
            continue;
        }
        let obj_path = out_dir.join(format!("lzfse_{}.o", src));
        let status = Command::new("clang")
            .args(["-O3", "-c", "-target", target, "-mmacosx-version-min=14.0", "-I", lzfse_dir.to_str().unwrap()])
            .arg(&src_path)
            .arg("-o")
            .arg(&obj_path)
            .status()
            .expect("Failed to compile lzfse source");
        assert!(status.success(), "Failed compiling {}", src);
        obj_files.push(obj_path);
    }

    // Compile snappy C++ files
    let snappy_sources = [
        "snappy.cc",
        "snappy-c.cc",
        "snappy-sinksource.cc",
        "snappy-stubs-internal.cc",
    ];
    for src in snappy_sources {
        let src_path = snappy_dir.join(src);
        if !src_path.exists() {
            continue;
        }
        let obj_path = out_dir.join(format!("snappy_{}.o", src));
        let status = Command::new("clang++")
            .args(["-O3", "-std=c++17", "-c", "-target", target, "-mmacosx-version-min=14.0", "-I", snappy_dir.to_str().unwrap()])
            .arg(&src_path)
            .arg("-o")
            .arg(&obj_path)
            .status()
            .expect("Failed to compile snappy source");
        assert!(status.success(), "Failed compiling {}", src);
        obj_files.push(obj_path);
    }

    if !obj_files.is_empty() {
        let lib_path = out_dir.join("libttzip_native_codecs.a");
        let mut libtool = Command::new("libtool");
        libtool.arg("-static").arg("-no_warning_for_no_symbols").arg("-o").arg(&lib_path);
        for obj in &obj_files {
            libtool.arg(obj);
        }
        let status = libtool.status().expect("Failed to run libtool");
        assert!(status.success(), "Failed creating libttzip_native_codecs.a");

        println!("cargo:rustc-link-search=native={}", out_dir.display());
        println!("cargo:rustc-link-lib=static=ttzip_native_codecs");
    }
}

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let repo_root = manifest_dir
        .parent()
        .and_then(|p| p.parent())
        .map(PathBuf::from)
        .unwrap_or_else(|| manifest_dir.clone());

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let target = env::var("TARGET").unwrap_or_else(|_| "aarch64-apple-darwin".to_string());

    let vendor_dir = repo_root.join("Vendor");
    let vendor_lib_dir = vendor_dir.join("lib");

    // Configure search paths for native static libraries
    if vendor_lib_dir.exists() {
        println!("cargo:rustc-link-search=native={}", vendor_lib_dir.display());
        println!("cargo:rustc-link-lib=static=archive");
        println!("cargo:rustc-link-lib=static=deflate");
        println!("cargo:rustc-link-lib=static=zstd");
        println!("cargo:rustc-link-lib=static=lzma");
        println!("cargo:rustc-link-lib=static=lz4");
        println!("cargo:rustc-link-lib=static=uchardet");
        println!("cargo:rustc-link-lib=static=z");
        println!("cargo:rustc-link-lib=static=b2");
    }

    // Compile and link in-tree native codecs (fast-lzma2, lzfse, snappy)
    compile_native_codecs(&repo_root, &out_dir, &target);

    // System libraries & frameworks required on macOS
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "macos" {
        println!("cargo:rustc-link-lib=bz2");
        println!("cargo:rustc-link-lib=iconv");
        println!("cargo:rustc-link-lib=xml2");
        println!("cargo:rustc-link-lib=expat");
        println!("cargo:rustc-link-lib=c++");
        println!("cargo:rustc-link-lib=compression");
        println!("cargo:rustc-link-lib=framework=Security");
    }

    println!("cargo:rerun-if-changed=build.rs");
}

