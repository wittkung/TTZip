// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! TTZip Standalone Native CLI & Interactive TUI Application Entry Point.
//!
//! Provides:
//! 1. Headless CLI subcommands (`list`/`l`, `extract`/`x`, `create`/`c`).
//! 2. Machine-readable JSON output conforming to `contracts/tui_vfs_tree_contract.json`.
//! 3. Interactive terminal TUI browser entrypoint powered by `ratatui` and `crossterm`.

use clap::{Parser, Subcommand};
use crossterm::event::{DisableMouseCapture, EnableMouseCapture};
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use serde::{Deserialize, Serialize};
use std::ffi::CString;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::time::{Duration, Instant};
use ttzip_glue::sevenz::{create_7z_archive, SevenZArchive};
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipCompressionLevel, TTZipCreateOptions, TTZipEncryptionMethod,
    TTZipExtractOptions,
};
use ttzip_glue::zip::{create_zip_archive, ZipArchive};
use ttzip_tui::app::{AppMode, AppState};
use ttzip_tui::event::EventHandler;
use ttzip_tui::ui;

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

/// Unified entry metadata extracted from any supported archive format.
#[derive(Debug, Clone)]
pub struct ArchiveEntryInfo {
    pub name: String,
    pub relative_path: String,
    pub is_directory: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
}

/// Detected archive container format.
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum ContainerFormat {
    Zip,
    SevenZip,
    Unknown,
}

impl ContainerFormat {
    pub fn name(&self) -> &'static str {
        match self {
            ContainerFormat::Zip => "ZIP",
            ContainerFormat::SevenZip => "7Z",
            ContainerFormat::Unknown => "UNKNOWN",
        }
    }
}

/// Detects archive container format from file extension and magic signature bytes.
pub fn detect_archive_format(path: &Path, data: &[u8]) -> ContainerFormat {
    if data.len() >= 6 && &data[0..6] == b"7z\xBC\xAF\x27\x1C" {
        return ContainerFormat::SevenZip;
    }
    if data.len() >= 4 && (&data[0..4] == b"PK\x03\x04" || &data[0..4] == b"PK\x05\x06" || &data[0..4] == b"PK\x07\x08") {
        return ContainerFormat::Zip;
    }
    if let Some(ext) = path.extension().and_then(|s| s.to_str()) {
        let ext_lower = ext.to_lowercase();
        if ext_lower == "7z" || ext_lower == "cb7" {
            return ContainerFormat::SevenZip;
        }
        if ext_lower == "zip" || ext_lower == "jar" || ext_lower == "apk" || ext_lower == "cbz" {
            return ContainerFormat::Zip;
        }
    }
    ContainerFormat::Unknown
}

/// Formats byte sizes into human-readable strings.
pub fn format_bytes(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;

    if bytes < KB {
        format!("{} B", bytes)
    } else if bytes < MB {
        format!("{:.1} KB", bytes as f64 / KB as f64)
    } else if bytes < GB {
        format!("{:.1} MB", bytes as f64 / MB as f64)
    } else {
        format!("{:.2} GB", bytes as f64 / GB as f64)
    }
}

/// Parses archive metadata and returns unified entry records.
pub fn parse_archive_entries(path: &Path, data: &[u8]) -> Result<(ContainerFormat, Vec<ArchiveEntryInfo>), String> {
    let format = detect_archive_format(path, data);
    match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(data).map_err(|e| format!("Failed to parse ZIP archive: {:?}", e))?;
            let mut entries = Vec::with_capacity(archive.len());
            for entry in archive.entries() {
                let name = Path::new(&entry.rel_path)
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_else(|| entry.rel_path.clone());
                entries.push(ArchiveEntryInfo {
                    name,
                    relative_path: entry.rel_path.clone(),
                    is_directory: entry.is_directory,
                    uncompressed_size: entry.uncompressed_size,
                    compressed_size: entry.compressed_size,
                    crc32: entry.crc32,
                    is_encrypted: entry.is_encrypted,
                });
            }
            Ok((format, entries))
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(data).map_err(|e| format!("Failed to parse 7z archive: {:?}", e))?;
            let mut entries = Vec::with_capacity(archive.len());
            let info = archive.info();
            let is_archive_enc = info.is_encrypted;
            let mut stream_idx = 0usize;
            for file in &info.files {
                let (u_sz, crc) = if !file.is_directory && !file.is_empty_stream {
                    let sz = info.stream_sizes.get(stream_idx).copied().unwrap_or(0);
                    let c = info.stream_crcs.get(stream_idx).copied().unwrap_or(0);
                    stream_idx += 1;
                    (sz, c)
                } else {
                    (0, 0)
                };

                let name = Path::new(&file.rel_path)
                    .file_name()
                    .map(|n| n.to_string_lossy().to_string())
                    .unwrap_or_else(|| file.rel_path.clone());
                entries.push(ArchiveEntryInfo {
                    name,
                    relative_path: file.rel_path.clone(),
                    is_directory: file.is_directory,
                    uncompressed_size: u_sz,
                    compressed_size: if u_sz > 0 { info.payload_len as u64 / info.stream_sizes.len().max(1) as u64 } else { 0 },
                    crc32: crc,
                    is_encrypted: is_archive_enc,
                });
            }
            Ok((format, entries))
        }
        ContainerFormat::Unknown => Err(format!(
            "Unsupported or unrecognized archive format for: {}",
            path.display()
        )),
    }
}

/// Executes headless `list` subcommand.
pub fn execute_list(archive_path: &Path, _password: Option<&str>, json: bool) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }
    let data = fs::read(archive_path).map_err(|e| format!("Failed to read archive: {}", e))?;
    let (format, entries) = parse_archive_entries(archive_path, &data)?;

    let total_uncompressed: u64 = entries.iter().map(|e| e.uncompressed_size).sum();
    let _total_compressed: u64 = entries.iter().map(|e| e.compressed_size).sum();
    let dir_count = entries.iter().filter(|e| e.is_directory).count();
    let file_count = entries.len() - dir_count;

    if json {
        let nodes: Vec<VfsNodeContractDto> = entries
            .iter()
            .map(|e| VfsNodeContractDto {
                name: e.name.clone(),
                relative_path: e.relative_path.clone(),
                is_directory: e.is_directory,
                uncompressed_size: e.uncompressed_size,
                compressed_size: e.compressed_size,
                crc32: e.crc32,
                is_encrypted: e.is_encrypted,
                match_indices: None,
            })
            .collect();

        let contract = VfsTreeContractDto {
            root_path: archive_path.to_string_lossy().to_string(),
            total_entries_count: entries.len(),
            total_uncompressed_bytes: total_uncompressed,
            nodes,
        };

        let json_str = serde_json::to_string_pretty(&contract)
            .map_err(|e| format!("Failed to serialize contract JSON: {}", e))?;
        println!("{}", json_str);
        return Ok(());
    }

    println!(
        "Archive: {} (Format: {}, Entries: {})",
        archive_path.display(),
        format.name(),
        entries.len()
    );
    println!("{:-<80}", "");
    println!(
        "{:<36} {:>12} {:>15} {:>7}  {:>10}",
        "Path", "Uncompressed", "Compressed", "Ratio", "CRC32"
    );
    println!("{:-<80}", "");

    for entry in &entries {
        let ratio = if entry.uncompressed_size > 0 {
            format!(
                "{:.1}%",
                (entry.compressed_size as f64 / entry.uncompressed_size as f64) * 100.0
            )
        } else {
            "-".to_string()
        };

        let path_display = if entry.is_directory {
            format!("{}/", entry.relative_path.trim_end_matches('/'))
        } else {
            entry.relative_path.clone()
        };

        let path_truncated = if path_display.len() > 36 {
            format!("...{}", &path_display[path_display.len() - 33..])
        } else {
            path_display
        };

        let crc_str = if entry.is_directory {
            "-".to_string()
        } else {
            format!("0x{:08X}", entry.crc32)
        };

        println!(
            "{:<36} {:>12} {:>15} {:>7}  {:>10}",
            path_truncated,
            format_bytes(entry.uncompressed_size),
            format_bytes(entry.compressed_size),
            ratio,
            crc_str
        );
    }

    println!("{:-<80}", "");
    println!(
        "Total: {} files, {} ({} directories)",
        file_count,
        format_bytes(total_uncompressed),
        dir_count
    );

    Ok(())
}

/// Executes headless `extract` subcommand.
pub fn execute_extract(
    archive_path: &Path,
    output_dir: Option<&Path>,
    password: Option<&str>,
    threads: u32,
    _verbose: bool,
) -> Result<(), String> {
    if !archive_path.exists() {
        return Err(format!("Archive file not found: {}", archive_path.display()));
    }

    let start_time = Instant::now();
    let dest_dir = output_dir.unwrap_or_else(|| Path::new("."));
    fs::create_dir_all(dest_dir)
        .map_err(|e| format!("Failed to create output directory {}: {}", dest_dir.display(), e))?;

    let data = fs::read(archive_path).map_err(|e| format!("Failed to read archive: {}", e))?;
    let format = detect_archive_format(archive_path, &data);

    let password_c = password.map(|p| CString::new(p).unwrap_or_default());
    let password_ptr = password_c.as_ref().map(|c| c.as_ptr()).unwrap_or(std::ptr::null());

    let options = TTZipExtractOptions {
        destination_path: std::ptr::null(),
        password: password_ptr,
        thread_budget: threads.max(1),
        overwrite_existing: true,
        preserve_permissions: true,
        dry_run: false,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let report = match format {
        ContainerFormat::Zip => {
            let archive = ZipArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open ZIP archive: {:?}", e))?;
            archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("ZIP extraction failed: {:?}", e))?
        }
        ContainerFormat::SevenZip => {
            let archive = SevenZArchive::open_slice(&data)
                .map_err(|e| format!("Failed to open 7z archive: {:?}", e))?;
            archive
                .extract_all(dest_dir, &options)
                .map_err(|e| format!("7z extraction failed: {:?}", e))?
        }
        ContainerFormat::Unknown => {
            return Err(format!(
                "Cannot extract unrecognized archive: {}",
                archive_path.display()
            ));
        }
    };

    let elapsed = start_time.elapsed();
    println!(
        "Extracted {} entries ({}) to {} in {:.2?}",
        report.processed_entries_count,
        format_bytes(report.total_uncompressed_bytes),
        dest_dir.display(),
        elapsed
    );

    Ok(())
}

/// Executes headless `create` subcommand.
pub fn execute_create(
    archive_path: &Path,
    sources: &[PathBuf],
    format_opt: Option<&str>,
    level: u8,
    password: Option<&str>,
    threads: u32,
) -> Result<(), String> {
    if sources.is_empty() {
        return Err("No source files specified for archive creation".to_string());
    }

    for src in sources {
        if !src.exists() {
            return Err(format!("Source file/directory not found: {}", src.display()));
        }
    }

    let start_time = Instant::now();

    // Determine target format
    let target_format = if let Some(fmt) = format_opt {
        match fmt.to_lowercase().as_str() {
            "7z" | "sevenzip" => ContainerFormat::SevenZip,
            "zip" => ContainerFormat::Zip,
            other => return Err(format!("Unsupported format: {}", other)),
        }
    } else if let Some(ext) = archive_path.extension().and_then(|s| s.to_str()) {
        if ext.eq_ignore_ascii_case("7z") {
            ContainerFormat::SevenZip
        } else {
            ContainerFormat::Zip
        }
    } else {
        ContainerFormat::Zip
    };

    let compression_level = match level {
        0 => TTZipCompressionLevel::Store,
        1..=2 => TTZipCompressionLevel::Fastest,
        3..=5 => TTZipCompressionLevel::Fast,
        6..=8 => TTZipCompressionLevel::Normal,
        9..=11 => TTZipCompressionLevel::Maximum,
        _ => TTZipCompressionLevel::Ultra,
    };

    let password_c = password.map(|p| CString::new(p).unwrap_or_default());
    let password_ptr = password_c.as_ref().map(|c| c.as_ptr()).unwrap_or(std::ptr::null());

    let encryption_method = if password.is_some() {
        TTZipEncryptionMethod::Aes256
    } else {
        TTZipEncryptionMethod::None
    };

    let options = TTZipCreateOptions {
        format: match target_format {
            ContainerFormat::Zip => TTZipArchiveFormat::Zip,
            ContainerFormat::SevenZip => TTZipArchiveFormat::SevenZip,
            _ => TTZipArchiveFormat::Zip,
        },
        level: compression_level,
        encryption: encryption_method,
        password: password_ptr,
        thread_budget: threads.max(1),
        solid_block_size_mb: 64,
        progress_callback: None,
        user_data: std::ptr::null_mut(),
    };

    let report = match target_format {
        ContainerFormat::Zip => create_zip_archive(archive_path, sources, &options)
            .map_err(|e| format!("Failed to create ZIP archive: {:?}", e))?,
        ContainerFormat::SevenZip => create_7z_archive(archive_path, sources, &options)
            .map_err(|e| format!("Failed to create 7z archive: {:?}", e))?,
        _ => return Err("Invalid format".to_string()),
    };

    let elapsed = start_time.elapsed();
    println!(
        "Created {} archive {} with {} entries ({} -> {}) in {:.2?}",
        target_format.name(),
        archive_path.display(),
        report.total_entries,
        format_bytes(report.total_uncompressed_bytes),
        format_bytes(report.total_compressed_bytes),
        elapsed
    );

    Ok(())
}

/// Runs interactive terminal TUI session.
pub fn run_interactive_tui(archive_path: PathBuf) -> Result<(), Box<dyn std::error::Error>> {
    let mut app_state = AppState::new(archive_path)
        .map_err(|e| format!("Failed to load archive: {:?}", e))?;

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let event_handler = EventHandler::new(Duration::from_millis(16));

    // Main TUI render & event loop
    loop {
        terminal.draw(|f| {
            ui::render(f, &mut app_state);
        })?;

        let event = event_handler.next()?;
        let sender = event_handler.sender.clone();
        app_state.handle_event(event, sender);

        if app_state.current_mode == AppMode::Exiting {
            break;
        }
    }

    event_handler.stop();

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    Ok(())
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Some(Commands::List {
            archive,
            password,
            json,
        }) => execute_list(&archive, password.as_deref(), json).map_err(|e| e.into()),
        Some(Commands::Extract {
            archive,
            output,
            password,
            threads,
            verbose,
        }) => execute_extract(&archive, output.as_deref(), password.as_deref(), threads, verbose).map_err(|e| e.into()),
        Some(Commands::Create {
            archive,
            sources,
            format,
            level,
            password,
            threads,
        }) => execute_create(
            &archive,
            &sources,
            format.as_deref(),
            level,
            password.as_deref(),
            threads,
        ).map_err(|e| e.into()),
        None => {
            if let Some(archive_path) = cli.archive {
                if !archive_path.exists() {
                    eprintln!("[ERROR] Target archive does not exist: {}", archive_path.display());
                    std::process::exit(1);
                }
                run_interactive_tui(archive_path)
            } else {
                use clap::CommandFactory;
                let mut cmd = Cli::command();
                let _ = cmd.print_help();
                println!();
                Ok(())
            }
        }
    };

    if let Err(err) = result {
        eprintln!("[ERROR] {}", err);
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn test_format_bytes() {
        assert_eq!(format_bytes(18), "18 B");
        assert_eq!(format_bytes(1024), "1.0 KB");
        assert_eq!(format_bytes(1024 * 1024), "1.0 MB");
        assert_eq!(format_bytes(1024 * 1024 * 1024), "1.00 GB");
    }

    #[test]
    fn test_cli_parsing_subcommands() {
        let cli = Cli::parse_from(["ttzip", "list", "test.zip"]);
        match cli.command {
            Some(Commands::List { archive, json, .. }) => {
                assert_eq!(archive, PathBuf::from("test.zip"));
                assert!(!json);
            }
            _ => panic!("Expected List subcommand"),
        }

        let cli_json = Cli::parse_from(["ttzip", "l", "test.7z", "--json"]);
        match cli_json.command {
            Some(Commands::List { archive, json, .. }) => {
                assert_eq!(archive, PathBuf::from("test.7z"));
                assert!(json);
            }
            _ => panic!("Expected List subcommand with alias l"),
        }

        let cli_extract = Cli::parse_from(["ttzip", "extract", "test.zip", "-o", "./out_dir", "-t", "8"]);
        match cli_extract.command {
            Some(Commands::Extract {
                archive,
                output,
                threads,
                ..
            }) => {
                assert_eq!(archive, PathBuf::from("test.zip"));
                assert_eq!(output, Some(PathBuf::from("./out_dir")));
                assert_eq!(threads, 8);
            }
            _ => panic!("Expected Extract subcommand"),
        }

        let cli_create = Cli::parse_from([
            "ttzip",
            "create",
            "out.7z",
            "file1.txt",
            "dir2",
            "-l",
            "9",
            "-f",
            "7z",
        ]);
        match cli_create.command {
            Some(Commands::Create {
                archive,
                sources,
                level,
                format,
                ..
            }) => {
                assert_eq!(archive, PathBuf::from("out.7z"));
                assert_eq!(sources, vec![PathBuf::from("file1.txt"), PathBuf::from("dir2")]);
                assert_eq!(level, 9);
                assert_eq!(format, Some("7z".to_string()));
            }
            _ => panic!("Expected Create subcommand"),
        }
    }

    #[test]
    fn test_headless_create_list_extract_roundtrip_zip() {
        let temp_dir = tempdir().expect("tempdir failed");
        let source_file = temp_dir.path().join("sample.txt");
        fs::write(&source_file, b"Hello TTZip TUI headless test!").expect("write failed");

        let archive_file = temp_dir.path().join("test_archive.zip");
        let sources = vec![source_file.clone()];

        // 1. Create ZIP
        let create_res = execute_create(
            &archive_file,
            &sources,
            Some("zip"),
            6,
            None,
            2,
        );
        assert!(create_res.is_ok(), "create_res: {:?}", create_res);
        assert!(archive_file.exists());

        // 2. List ZIP (text)
        let list_res = execute_list(&archive_file, None, false);
        assert!(list_res.is_ok(), "list_res: {:?}", list_res);

        // 3. List ZIP (JSON conforming to TUIVfsTreeContract)
        let data = fs::read(&archive_file).expect("read failed");
        let (fmt, entries) = parse_archive_entries(&archive_file, &data).expect("parse failed");
        assert_eq!(fmt, ContainerFormat::Zip);
        assert_eq!(entries.len(), 1);
        assert_eq!(entries[0].name, "sample.txt");
        assert_eq!(entries[0].uncompressed_size, 30);

        // 4. Extract ZIP
        let out_dir = temp_dir.path().join("extracted");
        let extract_res = execute_extract(&archive_file, Some(&out_dir), None, 2, false);
        assert!(extract_res.is_ok(), "extract_res: {:?}", extract_res);

        let extracted_file = out_dir.join("sample.txt");
        assert!(extracted_file.exists());
        let extracted_bytes = fs::read(&extracted_file).expect("read extracted failed");
        assert_eq!(extracted_bytes, b"Hello TTZip TUI headless test!");
    }

    #[test]
    fn test_headless_create_list_extract_roundtrip_7z() {
        let temp_dir = tempdir().expect("tempdir failed");
        let source_file = temp_dir.path().join("doc.md");
        fs::write(&source_file, b"# 7z Compression Test in TTZip TUI").expect("write failed");

        let archive_file = temp_dir.path().join("test_archive.7z");
        let sources = vec![source_file.clone()];

        // 1. Create 7z
        let create_res = execute_create(
            &archive_file,
            &sources,
            Some("7z"),
            3,
            None,
            2,
        );
        assert!(create_res.is_ok(), "create_res 7z: {:?}", create_res);
        assert!(archive_file.exists());

        // 2. List 7z
        let list_res = execute_list(&archive_file, None, false);
        assert!(list_res.is_ok(), "list_res 7z: {:?}", list_res);

        // 3. Extract 7z
        let out_dir = temp_dir.path().join("extracted_7z");
        let extract_res = execute_extract(&archive_file, Some(&out_dir), None, 2, false);
        assert!(extract_res.is_ok(), "extract_res 7z: {:?}", extract_res);

        let extracted_file = out_dir.join("doc.md");
        assert!(extracted_file.exists());
        let extracted_bytes = fs::read(&extracted_file).expect("read extracted 7z failed");
        assert_eq!(extracted_bytes, b"# 7z Compression Test in TTZip TUI");
    }
}
