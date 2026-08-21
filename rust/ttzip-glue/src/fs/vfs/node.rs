// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! VFS Node hierarchy, directory size aggregation, and ASCII tree rendering.

use std::cmp::Ordering;

/// Raw metadata describing an entry to insert into the VFS tree.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VfsEntry {
    pub path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
}

/// A node in the hierarchical VFS tree.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VfsNode {
    pub name: String,
    pub path: String,
    pub is_directory: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_encrypted: bool,
    pub children: Vec<VfsNode>,
}

impl VfsNode {
    pub fn new_dir(name: &str, path: &str) -> Self {
        Self {
            name: name.to_string(),
            path: path.to_string(),
            is_directory: true,
            uncompressed_size: 0,
            compressed_size: 0,
            crc32: 0,
            mtime_epoch_secs: 0,
            mode: 0o755,
            is_encrypted: false,
            children: Vec::new(),
        }
    }

    pub fn new_file(name: &str, entry: &VfsEntry) -> Self {
        Self {
            name: name.to_string(),
            path: entry.path.clone(),
            is_directory: entry.is_directory,
            uncompressed_size: entry.uncompressed_size,
            compressed_size: entry.compressed_size,
            crc32: entry.crc32,
            mtime_epoch_secs: entry.mtime_epoch_secs,
            mode: entry.mode,
            is_encrypted: entry.is_encrypted,
            children: Vec::new(),
        }
    }

    /// Recursively recalculates uncompressed & compressed sizes for directory nodes.
    pub fn recalculate_sizes(&mut self) -> (u64, u64) {
        if self.is_directory {
            let mut uncomp = 0u64;
            let mut comp = 0u64;
            for child in &mut self.children {
                let (u, c) = child.recalculate_sizes();
                uncomp = uncomp.saturating_add(u);
                comp = comp.saturating_add(c);
            }
            self.uncompressed_size = uncomp;
            self.compressed_size = comp;
            (uncomp, comp)
        } else {
            (self.uncompressed_size, self.compressed_size)
        }
    }

    /// Sorts children: directories first, then alphabetical by name.
    pub fn sort_recursive(&mut self) {
        for child in &mut self.children {
            child.sort_recursive();
        }
        self.children.sort_by(|a, b| match (a.is_directory, b.is_directory) {
            (true, false) => Ordering::Less,
            (false, true) => Ordering::Greater,
            _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
        });
    }

    /// Counts total leaf files under this node.
    pub fn total_files(&self) -> usize {
        if !self.is_directory {
            1
        } else {
            self.children.iter().map(|c| c.total_files()).sum()
        }
    }

    /// Counts total directory containers under this node.
    pub fn total_directories(&self) -> usize {
        if !self.is_directory {
            0
        } else {
            let direct_dirs = self.children.iter().filter(|c| c.is_directory).count();
            let nested: usize = self.children.iter().map(|c| c.total_directories()).sum();
            direct_dirs + nested
        }
    }

    /// Recursively renders ASCII/Unicode tree formatting.
    pub fn render_tree(&self, prefix: &str, is_last: bool, out: &mut String) {
        let display_name = if self.name.is_empty() { "." } else { &self.name };
        let size_str = if self.is_directory {
            "<DIR>".to_string()
        } else {
            format_byte_size(self.uncompressed_size)
        };

        if prefix.is_empty() {
            out.push_str(&format!("{} ({})\n", display_name, size_str));
        } else {
            let connector = if is_last { "└── " } else { "├── " };
            out.push_str(&format!("{}{}{} ({})\n", prefix, connector, display_name, size_str));
        }

        let child_prefix = if prefix.is_empty() {
            String::new()
        } else if is_last {
            format!("{}    ", prefix)
        } else {
            format!("{}│   ", prefix)
        };

        let count = self.children.len();
        for (i, child) in self.children.iter().enumerate() {
            child.render_tree(&child_prefix, i + 1 == count, out);
        }
    }
}

/// Formats byte count into human-readable representation.
pub fn format_byte_size(bytes: u64) -> String {
    if bytes < 1024 {
        format!("{} B", bytes)
    } else if bytes < 1024 * 1024 {
        let kb = bytes as f64 / 1024.0;
        if (kb.fract() * 10.0).round() == 0.0 {
            format!("{:.0} KB", kb)
        } else {
            format!("{:.1} KB", kb)
        }
    } else if bytes < 1024 * 1024 * 1024 {
        let mb = bytes as f64 / (1024.0 * 1024.0);
        if (mb.fract() * 10.0).round() == 0.0 {
            format!("{:.0} MB", mb)
        } else {
            format!("{:.1} MB", mb)
        }
    } else {
        let gb = bytes as f64 / (1024.0 * 1024.0 * 1024.0);
        format!("{:.2} GB", gb)
    }
}
