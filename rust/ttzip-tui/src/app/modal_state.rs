// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! State machine components for multi-modal overlays.

use crate::cli::braille_plotter::{get_standard_benchmark_dataset, BenchmarkCodecItem};

/// State structure for Password Recovery Modal.
#[derive(Debug, Clone)]
pub struct RecoveryModalState {
    pub dictionary_path: String,
    pub custom_dict_path: String,
    pub dict_choice: usize,
    pub threads: u32,
    pub is_running: bool,
    pub tested_keys: usize,
    pub total_keys: usize,
    pub speed_keys_per_sec: f64,
    pub elapsed_secs: f64,
    pub eta_secs: f64,
    pub found_password: Option<String>,
    pub status_message: Option<String>,
    pub error_message: Option<String>,
    pub selected_field: usize,
}

impl Default for RecoveryModalState {
    fn default() -> Self {
        Self {
            dictionary_path: "passwords.txt".to_string(),
            custom_dict_path: String::new(),
            dict_choice: 0,
            threads: rayon::current_num_threads().max(1) as u32,
            is_running: false,
            tested_keys: 0,
            total_keys: 0,
            speed_keys_per_sec: 0.0,
            elapsed_secs: 0.0,
            eta_secs: 0.0,
            found_password: None,
            status_message: None,
            error_message: None,
            selected_field: 0,
        }
    }
}

/// State structure for Self-Healing Repair Wizard Modal.
#[derive(Debug, Clone)]
pub struct RepairModalState {
    pub output_path: String,
    pub format_override: Option<String>,
    pub is_running: bool,
    pub salvaged_entries: usize,
    pub status_message: Option<String>,
    pub error_message: Option<String>,
    pub selected_field: usize,
}

impl RepairModalState {
    pub fn new(default_output: String) -> Self {
        Self {
            output_path: default_output,
            format_override: None,
            is_running: false,
            salvaged_entries: 0,
            status_message: None,
            error_message: None,
            selected_field: 0,
        }
    }
}

/// Pareto filtering categories for 2D Canvas exploration.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ParetoFilter {
    All,
    ParetoOptimal,
    ConvexHull,
    TTZipOnly,
}

impl ParetoFilter {
    pub const ALL: [ParetoFilter; 4] = [
        ParetoFilter::All,
        ParetoFilter::ParetoOptimal,
        ParetoFilter::ConvexHull,
        ParetoFilter::TTZipOnly,
    ];

    pub fn next(&self) -> Self {
        match self {
            Self::All => Self::ParetoOptimal,
            Self::ParetoOptimal => Self::ConvexHull,
            Self::ConvexHull => Self::TTZipOnly,
            Self::TTZipOnly => Self::All,
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            Self::All => "All Codecs",
            Self::ParetoOptimal => "Pareto Optimal",
            Self::ConvexHull => "Convex Hull",
            Self::TTZipOnly => "TTZip Engine",
        }
    }
}

/// State structure for Interactive 2D Pareto Benchmark Modal.
#[derive(Debug, Clone)]
pub struct ParetoModalState {
    pub items: Vec<BenchmarkCodecItem>,
    pub selected_index: usize,
    pub active_tab: usize,
    pub filter: ParetoFilter,
    pub zoom_level: f64,
    pub dict_mb: u32,
    pub threads: u32,
    pub iterations: u32,
    pub is_benchmarking: bool,
    pub mips_summary: Option<String>,
    pub status_message: Option<String>,
}

impl Default for ParetoModalState {
    fn default() -> Self {
        Self::new()
    }
}

impl ParetoModalState {
    pub fn new() -> Self {
        let items = get_standard_benchmark_dataset();
        Self {
            items,
            selected_index: 0,
            active_tab: 0,
            filter: ParetoFilter::All,
            zoom_level: 1.0,
            dict_mb: 32,
            threads: rayon::current_num_threads().max(1) as u32,
            iterations: 1,
            is_benchmarking: false,
            mips_summary: None,
            status_message: None,
        }
    }

    pub fn filtered_items(&self) -> Vec<&BenchmarkCodecItem> {
        self.items
            .iter()
            .filter(|it| match self.filter {
                ParetoFilter::All => true,
                ParetoFilter::ParetoOptimal => it.raw.is_pareto_optimal,
                ParetoFilter::ConvexHull => it.raw.is_on_convex_envelope,
                ParetoFilter::TTZipOnly => it.name.starts_with("TTZip"),
            })
            .collect()
    }

    pub fn current_focus_item(&self) -> Option<&BenchmarkCodecItem> {
        let filtered = self.filtered_items();
        if filtered.is_empty() {
            None
        } else {
            let idx = self.selected_index.min(filtered.len() - 1);
            Some(filtered[idx])
        }
    }
}

/// Split chunk preset categories.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SplitPreset {
    Cd700M,
    Dvd4700M,
    Fat32_4G,
    Discord25M,
    Discord500M,
    Custom,
}

impl SplitPreset {
    pub const ALL: [SplitPreset; 6] = [
        SplitPreset::Cd700M,
        SplitPreset::Dvd4700M,
        SplitPreset::Fat32_4G,
        SplitPreset::Discord25M,
        SplitPreset::Discord500M,
        SplitPreset::Custom,
    ];

    pub fn label(&self) -> &'static str {
        match self {
            SplitPreset::Cd700M => "CD (700 MB)",
            SplitPreset::Dvd4700M => "DVD (4.7 GB)",
            SplitPreset::Fat32_4G => "FAT32 (4 GB)",
            SplitPreset::Discord25M => "Discord (25 MB)",
            SplitPreset::Discord500M => "Discord Nitro (500 MB)",
            SplitPreset::Custom => "Custom",
        }
    }

    pub fn byte_size(&self, custom_str: &str) -> Result<u64, String> {
        match self {
            SplitPreset::Cd700M => Ok(700 * 1024 * 1024),
            SplitPreset::Dvd4700M => Ok((4.7 * 1024.0 * 1024.0 * 1024.0) as u64),
            SplitPreset::Fat32_4G => Ok(4 * 1024 * 1024 * 1024 - 1),
            SplitPreset::Discord25M => Ok(25 * 1024 * 1024),
            SplitPreset::Discord500M => Ok(500 * 1024 * 1024),
            SplitPreset::Custom => crate::cli::handlers::split::parse_size_bytes(custom_str),
        }
    }
}

/// State structure for Multi-Volume Split Manager Modal.
#[derive(Debug, Clone)]
pub struct SplitModalState {
    pub preset_index: usize,
    pub custom_size_str: String,
    pub volume_size_str: String,
    pub output_dir: String,
    pub naming_scheme_idx: usize,
    pub table_scroll: usize,
    pub is_running: bool,
    pub created_volumes: Vec<String>,
    pub status_message: Option<String>,
    pub error_message: Option<String>,
    pub selected_field: usize,
}

impl SplitModalState {
    pub fn new(default_output_dir: String) -> Self {
        Self {
            preset_index: 0,
            custom_size_str: "100M".to_string(),
            volume_size_str: "700M".to_string(),
            output_dir: default_output_dir,
            naming_scheme_idx: 0,
            table_scroll: 0,
            is_running: false,
            created_volumes: Vec::new(),
            status_message: None,
            error_message: None,
            selected_field: 0,
        }
    }

    pub fn active_preset(&self) -> SplitPreset {
        SplitPreset::ALL[self.preset_index.min(SplitPreset::ALL.len() - 1)]
    }

    pub fn current_chunk_size_bytes(&self) -> Result<u64, String> {
        self.active_preset().byte_size(&self.custom_size_str)
    }

    pub fn naming_scheme(&self) -> ttzip_glue::archive::split::VolumeNamingScheme {
        match self.naming_scheme_idx % 3 {
            0 => ttzip_glue::archive::split::VolumeNamingScheme::NumberedExtension,
            1 => ttzip_glue::archive::split::VolumeNamingScheme::PkzipSpanned,
            _ => ttzip_glue::archive::split::VolumeNamingScheme::RawSplit,
        }
    }
}
