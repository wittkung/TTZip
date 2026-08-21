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
    long_about = "TTZip provides an ultra-fast interactive TUI archive explorer and a standalone zero-dependency CLI engine for ZIP and 7z archives on macOS."
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
