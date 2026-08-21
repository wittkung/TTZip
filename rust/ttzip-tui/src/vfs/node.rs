// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! VFS Hierarchical Node representation, recursive navigation, and icon rendering.

use super::meta::VfsEntryMeta;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// A node in the virtual file system hierarchical tree.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsNode {
    pub name: String,
    pub relative_path: String,
    #[serde(rename = "isDirectory")]
    pub is_dir: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub children: Vec<VfsNode>,
    #[serde(default)]
    pub is_expanded: bool,
    #[serde(default)]
    pub is_selected: bool,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub match_indices: Vec<usize>,
    #[serde(default)]
    pub entry_idx: Option<usize>,
}

impl VfsNode {
    /// Creates a new directory node.
    pub fn new_dir(name: String, relative_path: String) -> Self {
        Self {
            name,
            relative_path,
            is_dir: true,
            uncompressed_size: 0,
            compressed_size: 0,
            crc32: 0,
            is_encrypted: false,
            children: Vec::new(),
            is_expanded: false,
            is_selected: false,
            match_indices: Vec::new(),
            entry_idx: None,
        }
    }

    /// Creates a new file node from entry metadata.
    pub fn new_file(name: String, meta: &VfsEntryMeta) -> Self {
        Self {
            name,
            relative_path: meta.path.clone(),
            is_dir: meta.is_directory,
            uncompressed_size: meta.uncompressed_size,
            compressed_size: meta.compressed_size,
            crc32: meta.crc32,
            is_encrypted: meta.is_encrypted,
            children: Vec::new(),
            is_expanded: false,
            is_selected: false,
            match_indices: Vec::new(),
            entry_idx: meta.entry_idx,
        }
    }

    /// Recursively sets the selection state of this node and all of its descendants.
    pub fn set_selected_recursive(&mut self, selected: bool) {
        self.is_selected = selected;
        for child in &mut self.children {
            child.set_selected_recursive(selected);
        }
    }

    /// Recursively sets the expansion state for all directory nodes.
    pub fn set_expanded_recursive(&mut self, expanded: bool) {
        if self.is_dir {
            self.is_expanded = expanded;
            for child in &mut self.children {
                child.set_expanded_recursive(expanded);
            }
        }
    }

    /// Finds a node by its relative path.
    pub fn find_child(&self, relative_path: &str) -> Option<&VfsNode> {
        if self.relative_path == relative_path {
            return Some(self);
        }
        for child in &self.children {
            if let Some(found) = child.find_child(relative_path) {
                return Some(found);
            }
        }
        None
    }

    /// Finds a mutable node by its relative path.
    pub fn find_child_mut(&mut self, relative_path: &str) -> Option<&mut VfsNode> {
        if self.relative_path == relative_path {
            return Some(self);
        }
        for child in &mut self.children {
            if let Some(found) = child.find_child_mut(relative_path) {
                return Some(found);
            }
        }
        None
    }

    /// Recursively updates aggregated sizes for directory nodes.
    pub fn recalculate_dir_sizes(&mut self) {
        if self.is_dir {
            let mut uncomp = 0u64;
            let mut comp = 0u64;
            for child in &mut self.children {
                child.recalculate_dir_sizes();
                uncomp = uncomp.saturating_add(child.uncompressed_size);
                comp = comp.saturating_add(child.compressed_size);
            }
            self.uncompressed_size = uncomp;
            self.compressed_size = comp;
        }
    }

    /// Sorts children: directories first (alphabetically), then files (alphabetically).
    pub fn sort_children(&mut self) {
        for child in &mut self.children {
            child.sort_children();
        }
        self.children.sort_by(|a, b| {
            match (a.is_dir, b.is_dir) {
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
            }
        });
    }

    /// Determines appropriate icon for terminal rendering.
    pub fn icon(&self) -> &'static str {
        if self.is_dir {
            if self.is_expanded {
                "📂 "
            } else {
                "📁 "
            }
        } else if self.is_encrypted {
            "🔒 "
        } else {
            let path = Path::new(&self.name);
            let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
            match ext.to_lowercase().as_str() {
                "rs" => "🦀 ",
                "swift" => "🕊️ ",
                "c" | "h" | "cpp" | "hpp" => "🇨 ",
                "json" | "toml" | "yaml" | "yml" | "xml" | "plist" => "⚙️ ",
                "md" | "txt" | "log" => "📝 ",
                "zip" | "7z" | "tar" | "gz" | "bz2" | "xz" | "zst" => "📦 ",
                "png" | "jpg" | "jpeg" | "gif" | "webp" | "svg" | "icns" => "🖼️ ",
                "sh" | "bash" | "zsh" => "🐚 ",
                _ => "📄 ",
            }
        }
    }
}
