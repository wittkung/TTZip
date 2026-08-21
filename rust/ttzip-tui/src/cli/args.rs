// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! CLI Argument Parsing & JSON Contract DTO definitions.

use clap::{Parser, Subcommand};
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

/// TTZip modern interactive terminal TUI and standalone CLI engine.
#[derive(Parser, Debug, Clone)]
#[command(
    name = "ttzip",
    author = "Witt Kung <witt.w.kung@gmail.com>",
    version = "1.0.0",
    about = "TTZip: High-performance native archiving and terminal TUI engine for macOS",
    long_about = "TTZip provides an ultra-fast interactive TUI archive explorer and a standalone zero-dependency CLI engine for ZIP, 7z, TAR, Snappy, and Brotli archives on macOS."
)]
pub struct Cli {
    /// Target archive path (opens interactive TUI browser when specified without subcommand)
    #[arg(value_name = "ARCHIVE")]
    pub archive: Option<PathBuf>,

    /// Subcommands for headless operations
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand, Debug, Clone)]
pub enum Commands {
    /// List entries and metadata inside an archive (aliases: l, list)
    #[command(name = "list", alias = "l")]
    List {
        /// Path to the archive file
        #[arg(value_name = "ARCHIVE")]
        archive: PathBuf,

        /// Optional password for encrypted archives
        #[arg(short, long)]
        password: Option<String>,

        /// Output in JSON format conforming to TUIVfsTreeContract
        #[arg(long)]
        json: bool,
    },

    /// Extract archive entries to destination directory (aliases: x, extract)
    #[command(name = "extract", alias = "x")]
    Extract {
        /// Path to the archive file
        #[arg(value_name = "ARCHIVE")]
        archive: PathBuf,

        /// Destination output directory (default: current directory)
        #[arg(short = 'o', long = "output")]
        output: Option<PathBuf>,

        /// Optional password for encrypted archives
        #[arg(short, long)]
        password: Option<String>,

        /// Number of parallel extraction threads
        #[arg(short = 't', long = "threads", default_value_t = 4)]
        threads: u32,

        /// Verbose log output
        #[arg(short, long)]
        verbose: bool,
    },

    /// Create a new archive from source files/directories (aliases: c, create)
    #[command(name = "create", alias = "c")]
    Create {
        /// Destination archive path (e.g. output.zip, backup.7z)
        #[arg(value_name = "ARCHIVE")]
        archive: PathBuf,

        /// Source files or directories to include
        #[arg(value_name = "SOURCES", required = true)]
        sources: Vec<PathBuf>,

        /// Archive format (zip, 7z; default: auto-detected from archive extension)
        #[arg(short = 'f', long = "format")]
        format: Option<String>,

        /// Compression level (0 = Store, 1 = Fastest, 6 = Normal, 9 = Maximum, 12 = Ultra)
        #[arg(short = 'l', long = "level", default_value_t = 6)]
        level: u8,

        /// Optional password for encryption
        #[arg(short, long)]
        password: Option<String>,

        /// Number of parallel compression threads
        #[arg(short = 't', long = "threads", default_value_t = 4)]
        threads: u32,

        /// Volume chunk size for multi-volume creation (e.g. "10M", "100MB", "1G")
        #[arg(short = 'v', long = "volume-size")]
        volume_size: Option<String>,
    },

    /// Recover password of encrypted archive using multi-core dictionary attack (aliases: rec, recover)
    #[command(name = "recover", alias = "rec")]
    Recover {
        /// Path to the encrypted archive file
        #[arg(value_name = "ARCHIVE")]
        archive: PathBuf,

        /// Path to the password dictionary / wordlist file
        #[arg(short = 'd', long = "dict", alias = "dictionary")]
        dictionary: PathBuf,

        /// Number of parallel recovery threads (default: system logical cores)
        #[arg(short = 't', long = "threads")]
        threads: Option<u32>,

        /// Output in JSON format
        #[arg(long)]
        json: bool,
    },

    /// Repair damaged ZIP or TAR archive and recover salvageable files (aliases: rep, repair)
    #[command(name = "repair", alias = "rep")]
    Repair {
        /// Path to the damaged archive file
        #[arg(value_name = "DAMAGED_ARCHIVE")]
        damaged_archive: PathBuf,

        /// Destination path for repaired archive
        #[arg(short = 'o', long = "output")]
        output: PathBuf,

        /// Archive format override (zip, tar; default: auto-detected)
        #[arg(short = 'f', long = "format")]
        format: Option<String>,

        /// Output in JSON format
        #[arg(long)]
        json: bool,
    },

    /// Split an archive into multi-volume segments (aliases: sp, split)
    #[command(name = "split", alias = "sp")]
    Split {
        /// Path to the source archive file
        #[arg(value_name = "SOURCE_ARCHIVE")]
        source_archive: PathBuf,

        /// Volume chunk size (e.g. "10M", "100MB", "1G")
        #[arg(short = 'v', long = "volume-size", alias = "size")]
        volume_size: String,

        /// Destination directory for output volumes (default: parent directory of source)
        #[arg(short = 'o', long = "output-dir", alias = "output")]
        output_dir: Option<PathBuf>,

        /// Naming scheme (numbered, pkzip, raw; default: numbered)
        #[arg(short = 'n', long = "naming")]
        naming: Option<String>,
    },

    /// Join multi-volume archive segments into a single file (aliases: j, join)
    #[command(name = "join", alias = "j")]
    Join {
        /// Path to the first volume segment in the chain (e.g. archive.7z.001 or archive.z01)
        #[arg(value_name = "FIRST_VOLUME")]
        first_volume: PathBuf,

        /// Destination output archive file
        #[arg(short = 'o', long = "output")]
        output: PathBuf,

        /// Output in JSON format
        #[arg(long)]
        json: bool,
    },

    /// Run compression benchmark & Pareto frontier visualization (aliases: b, bench)
    #[command(name = "bench", alias = "b")]
    Bench {
        /// Run MIPS CPU compression & decompression benchmark
        #[arg(long)]
        mips: bool,

        /// Render ASCII/Unicode Pareto efficiency chart
        #[arg(long)]
        pareto: bool,

        /// Number of benchmark worker threads
        #[arg(short = 't', long = "threads", default_value_t = 4)]
        threads: u32,

        /// Dictionary size in MB for LZMA2 benchmark
        #[arg(short = 'd', long = "dict", default_value_t = 16)]
        dict_mb: u32,

        /// Benchmark iterations count
        #[arg(short = 'i', long = "iterations", default_value_t = 3)]
        iterations: u32,
    },
}

/// JSON Contract representation matching `contracts/tui_vfs_tree_contract.json`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsTreeContractDto {
    pub root_path: String,
    pub total_entries_count: usize,
    pub total_uncompressed_bytes: u64,
    pub nodes: Vec<VfsNodeContractDto>,
}

/// VFS Node representation matching `contracts/tui_vfs_tree_contract.json`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsNodeContractDto {
    pub name: String,
    pub relative_path: String,
    pub is_directory: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub match_indices: Option<Vec<usize>>,
}

/// JSON DTO for password recovery result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RecoverResultDto {
    pub archive: String,
    pub recovered: bool,
    pub password: Option<String>,
    pub total_tested: usize,
    pub elapsed_ms: u64,
    pub speed_keys_per_sec: f64,
}

/// JSON DTO for archive repair result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RepairResultDto {
    pub damaged_archive: String,
    pub repaired_archive: String,
    pub format: String,
    pub salvaged_entries: usize,
    pub elapsed_ms: u64,
}

/// JSON DTO for split archive result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SplitResultDto {
    pub source_archive: String,
    pub volume_count: usize,
    pub volume_size_bytes: u64,
    pub volumes: Vec<String>,
    pub elapsed_ms: u64,
}

/// JSON DTO for multi-volume join result.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct JoinResultDto {
    pub first_volume: String,
    pub output: String,
    pub volume_count: usize,
    pub total_bytes: u64,
    pub volumes: Vec<String>,
    pub elapsed_ms: u64,
}
