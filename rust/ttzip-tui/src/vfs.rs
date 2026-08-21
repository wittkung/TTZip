// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Archive Virtual File System (VFS) Tree and Instant Fuzzy Search Matcher.
//!
//! Conforms to `specs/170-rust-interactive-tui-engine/contracts/tui_vfs_tree_contract.json`
//! and `data-model.md`.

use fuzzy_matcher::skim::SkimMatcherV2;
use fuzzy_matcher::FuzzyMatcher;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Clean, safe representation of an archive entry's metadata.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsEntryMeta {
    pub path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub mtime_epoch_secs: i64,
    pub mode: u32,
    pub is_directory: bool,
    pub is_encrypted: bool,
    #[serde(default)]
    pub entry_idx: Option<usize>,
}

impl From<&ttzip_glue::TTZipEntryMetadata> for VfsEntryMeta {
    fn from(m: &ttzip_glue::TTZipEntryMetadata) -> Self {
        let path = if !m.path.is_null() {
            unsafe { std::ffi::CStr::from_ptr(m.path) }
                .to_str()
                .unwrap_or("")
                .to_string()
        } else {
            String::new()
        };
        Self {
            path,
            uncompressed_size: m.uncompressed_size,
            compressed_size: m.compressed_size,
            crc32: m.crc32,
            mtime_epoch_secs: m.mtime_epoch_secs,
            mode: m.mode,
            is_directory: m.is_directory,
            is_encrypted: m.is_encrypted,
            entry_idx: None,
        }
    }
}

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

/// Formatted row in the visible table for TUI rendering.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VfsRow {
    pub depth: usize,
    pub is_dir: bool,
    pub is_selected: bool,
    pub is_expanded: bool,
    pub icon: &'static str,
    pub display_name: String,
    pub node_path: String,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
    pub entry_idx: Option<usize>,
}

/// An entry in a flattened visible view of the tree (for terminal rendering).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VfsVisibleItem<'a> {
    pub node: &'a VfsNode,
    pub depth: usize,
    pub is_last_child: bool,
    pub indent_prefix: String,
}

/// Result of a fuzzy search operation.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsSearchResult {
    pub name: String,
    pub relative_path: String,
    #[serde(rename = "isDirectory")]
    pub is_dir: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
    pub score: i64,
    pub match_indices: Vec<usize>,
    pub entry_idx: Option<usize>,
}

/// Type alias for backward compatibility.
pub type FuzzySearchResult = VfsSearchResult;

/// Virtual File System Tree managing hierarchical nodes of an archive.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VfsTree {
    pub root_path: String,
    pub total_entries_count: usize,
    pub total_uncompressed_bytes: u64,
    #[serde(default)]
    pub total_compressed_bytes: u64,
    #[serde(rename = "nodes")]
    pub root_nodes: Vec<VfsNode>,
    #[serde(skip)]
    pub visible_rows: Vec<VfsRow>,
}

impl VfsTree {
    /// Creates an empty VFS tree.
    pub fn new(root_path: String) -> Self {
        Self {
            root_path,
            total_entries_count: 0,
            total_uncompressed_bytes: 0,
            total_compressed_bytes: 0,
            root_nodes: Vec::new(),
            visible_rows: Vec::new(),
        }
    }

    /// Builds a VfsTree from raw tuple array `(path, is_dir, uncomp_size, comp_size, crc32, is_enc, entry_idx)`.
    pub fn build_from_raw_entries(
        root_path: String,
        entries: &[(String, bool, u64, u64, u32, bool, usize)],
    ) -> Self {
        let metas: Vec<VfsEntryMeta> = entries
            .iter()
            .map(|(path, is_dir, uncomp, comp, crc, enc, idx)| VfsEntryMeta {
                path: path.clone(),
                uncompressed_size: *uncomp,
                compressed_size: *comp,
                crc32: *crc,
                mtime_epoch_secs: 0,
                mode: if *is_dir { 0o755 } else { 0o644 },
                is_directory: *is_dir,
                is_encrypted: *enc,
                entry_idx: Some(*idx),
            })
            .collect();
        Self::from_metadata_list(&root_path, &metas)
    }

    /// Builds a VfsTree from a slice of safe metadata items.
    pub fn from_metadata_list(root_path: &str, entries: &[VfsEntryMeta]) -> Self {
        let mut tree = Self::new(root_path.to_string());
        let mut total_uncomp = 0u64;
        let mut total_comp = 0u64;
        let mut count = 0usize;

        for meta in entries {
            if meta.path.trim().is_empty() {
                continue;
            }
            count += 1;
            total_uncomp = total_uncomp.saturating_add(meta.uncompressed_size);
            total_comp = total_comp.saturating_add(meta.compressed_size);
            tree.insert_entry(meta);
        }

        for node in &mut tree.root_nodes {
            node.recalculate_dir_sizes();
            node.sort_children();
        }

        tree.root_nodes.sort_by(|a, b| {
            match (a.is_dir, b.is_dir) {
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
            }
        });

        tree.total_entries_count = count;
        tree.total_uncompressed_bytes = total_uncomp;
        tree.total_compressed_bytes = total_comp;
        tree.update_visible_rows();
        tree
    }

    /// Builds a VfsTree from raw C-ABI `TTZipEntryMetadata` slice.
    pub fn from_c_metadata_slice(
        root_path: &str,
        entries: &[ttzip_glue::TTZipEntryMetadata],
    ) -> Self {
        let metas: Vec<VfsEntryMeta> = entries.iter().map(VfsEntryMeta::from).collect();
        Self::from_metadata_list(root_path, &metas)
    }

    /// Inserts a single metadata item into the hierarchical tree.
    fn insert_entry(&mut self, meta: &VfsEntryMeta) {
        let clean_path = meta.path.trim_matches('/');
        if clean_path.is_empty() {
            return;
        }

        let segments: Vec<&str> = clean_path.split('/').collect();
        if segments.is_empty() {
            return;
        }

        let mut current_nodes = &mut self.root_nodes;
        let mut accumulated_path = String::new();

        for (idx, &segment) in segments.iter().enumerate() {
            let is_last = idx == segments.len() - 1;
            if !accumulated_path.is_empty() {
                accumulated_path.push('/');
            }
            accumulated_path.push_str(segment);

            if is_last {
                if let Some(pos) = current_nodes.iter().position(|n| n.name == segment) {
                    let existing = &mut current_nodes[pos];
                    existing.is_dir = meta.is_directory;
                    existing.uncompressed_size = meta.uncompressed_size;
                    existing.compressed_size = meta.compressed_size;
                    existing.crc32 = meta.crc32;
                    existing.is_encrypted = meta.is_encrypted;
                    existing.entry_idx = meta.entry_idx;
                } else {
                    let node = if meta.is_directory {
                        VfsNode::new_dir(segment.to_string(), accumulated_path.clone())
                    } else {
                        VfsNode::new_file(segment.to_string(), meta)
                    };
                    current_nodes.push(node);
                }
            } else {
                let pos = match current_nodes.iter().position(|n| n.name == segment && n.is_dir) {
                    Some(p) => p,
                    None => {
                        let dir_node =
                            VfsNode::new_dir(segment.to_string(), accumulated_path.clone());
                        current_nodes.push(dir_node);
                        current_nodes.len() - 1
                    }
                };
                current_nodes = &mut current_nodes[pos].children;
            }
        }
    }

    /// Regenerates `visible_rows` from the tree hierarchy.
    pub fn update_visible_rows(&mut self) {
        let mut rows = Vec::new();

        fn build_rows(nodes: &[VfsNode], depth: usize, out: &mut Vec<VfsRow>) {
            for node in nodes {
                out.push(VfsRow {
                    depth,
                    is_dir: node.is_dir,
                    is_selected: node.is_selected,
                    is_expanded: node.is_expanded,
                    icon: node.icon(),
                    display_name: node.name.clone(),
                    node_path: node.relative_path.clone(),
                    uncompressed_size: node.uncompressed_size,
                    compressed_size: node.compressed_size,
                    crc32: node.crc32,
                    is_encrypted: node.is_encrypted,
                    entry_idx: node.entry_idx,
                });

                if node.is_dir && node.is_expanded && !node.children.is_empty() {
                    build_rows(&node.children, depth + 1, out);
                }
            }
        }

        build_rows(&self.root_nodes, 0, &mut rows);
        self.visible_rows = rows;
    }

    /// Returns a flat list of all nodes currently visible in the UI according to `is_expanded`.
    pub fn flatten_visible(&self) -> Vec<VfsVisibleItem<'_>> {
        let mut items = Vec::new();

        fn traverse<'a>(
            nodes: &'a [VfsNode],
            depth: usize,
            prefix: &str,
            out: &mut Vec<VfsVisibleItem<'a>>,
        ) {
            let total = nodes.len();
            for (i, node) in nodes.iter().enumerate() {
                let is_last = i + 1 == total;
                let branch = if is_last { "└── " } else { "├── " };
                let indent_prefix = if depth == 0 {
                    String::new()
                } else {
                    format!("{}{}", prefix, branch)
                };

                out.push(VfsVisibleItem {
                    node,
                    depth,
                    is_last_child: is_last,
                    indent_prefix,
                });

                if node.is_dir && node.is_expanded && !node.children.is_empty() {
                    let next_prefix = if depth == 0 {
                        ""
                    } else if is_last {
                        "    "
                    } else {
                        "│   "
                    };
                    let combined_prefix = format!("{}{}", prefix, next_prefix);
                    traverse(&node.children, depth + 1, &combined_prefix, out);
                }
            }
        }

        traverse(&self.root_nodes, 0, "", &mut items);
        items
    }

    /// Toggles the expanded/collapsed state of a directory node by relative path.
    pub fn toggle_expanded(&mut self, relative_path: &str) -> Option<bool> {
        let clean_path = relative_path.trim_matches('/');
        let mut res = None;
        for node in &mut self.root_nodes {
            if let Some(target) = node.find_child_mut(clean_path) {
                if target.is_dir {
                    target.is_expanded = !target.is_expanded;
                    res = Some(target.is_expanded);
                    break;
                }
            }
        }
        if res.is_some() {
            self.update_visible_rows();
        }
        res
    }

    /// Sets expansion state for all directory nodes.
    pub fn set_all_expanded(&mut self, expanded: bool) {
        for node in &mut self.root_nodes {
            node.set_expanded_recursive(expanded);
        }
        self.update_visible_rows();
    }

    /// Toggles the selection checkbox on a node by relative path.
    pub fn toggle_selected(&mut self, relative_path: &str) -> Option<bool> {
        let clean_path = relative_path.trim_matches('/');
        let mut res = None;
        for node in &mut self.root_nodes {
            if let Some(target) = node.find_child_mut(clean_path) {
                let new_state = !target.is_selected;
                target.set_selected_recursive(new_state);
                res = Some(new_state);
                break;
            }
        }
        if res.is_some() {
            self.update_visible_rows();
        }
        res
    }

    /// Sets selection state for all nodes in the tree.
    pub fn select_all(&mut self, selected: bool) {
        for node in &mut self.root_nodes {
            node.set_selected_recursive(selected);
        }
        self.update_visible_rows();
    }

    /// Collects relative paths of all selected entries.
    pub fn get_selected_paths(&self) -> Vec<String> {
        let mut result = Vec::new();
        fn collect_sel(node: &VfsNode, out: &mut Vec<String>) {
            if node.is_selected && !node.is_dir {
                out.push(node.relative_path.clone());
            }
            for child in &node.children {
                collect_sel(child, out);
            }
        }
        for node in &self.root_nodes {
            collect_sel(node, &mut result);
        }
        result
    }

    /// Collects archive entry indices of all selected entries.
    pub fn get_selected_entry_indices(&self) -> Vec<usize> {
        let mut result = Vec::new();
        fn collect_idx(node: &VfsNode, out: &mut Vec<usize>) {
            if node.is_selected && !node.is_dir {
                if let Some(idx) = node.entry_idx {
                    out.push(idx);
                }
            }
            for child in &node.children {
                collect_idx(child, out);
            }
        }
        for node in &self.root_nodes {
            collect_idx(node, &mut result);
        }
        result
    }

    /// Finds a node by relative path.
    pub fn find_node(&self, relative_path: &str) -> Option<&VfsNode> {
        let clean_path = relative_path.trim_matches('/');
        for node in &self.root_nodes {
            if let Some(found) = node.find_child(clean_path) {
                return Some(found);
            }
        }
        None
    }

    /// Finds a mutable node by relative path.
    pub fn find_node_mut(&mut self, relative_path: &str) -> Option<&mut VfsNode> {
        let clean_path = relative_path.trim_matches('/');
        for node in &mut self.root_nodes {
            if let Some(found) = node.find_child_mut(clean_path) {
                return Some(found);
            }
        }
        None
    }

    /// Performs instant fuzzy search against all nodes in the tree using `SkimMatcherV2`.
    pub fn fuzzy_search(&self, query: &str) -> Vec<VfsSearchResult> {
        let trimmed = query.trim();
        if trimmed.is_empty() {
            return Vec::new();
        }

        let matcher = SkimMatcherV2::default();
        let mut results = Vec::new();

        fn search_node(matcher: &SkimMatcherV2, query: &str, node: &VfsNode, out: &mut Vec<VfsSearchResult>) {
            let name_match = matcher.fuzzy_indices(&node.name, query);
            let path_match = matcher.fuzzy_indices(&node.relative_path, query);

            if let Some((score, indices)) = name_match {
                out.push(VfsSearchResult {
                    name: node.name.clone(),
                    relative_path: node.relative_path.clone(),
                    is_dir: node.is_dir,
                    uncompressed_size: node.uncompressed_size,
                    compressed_size: node.compressed_size,
                    crc32: node.crc32,
                    is_encrypted: node.is_encrypted,
                    score: score + 100, // Boost filename match
                    match_indices: indices,
                    entry_idx: node.entry_idx,
                });
            } else if let Some((score, indices)) = path_match {
                out.push(VfsSearchResult {
                    name: node.name.clone(),
                    relative_path: node.relative_path.clone(),
                    is_dir: node.is_dir,
                    uncompressed_size: node.uncompressed_size,
                    compressed_size: node.compressed_size,
                    crc32: node.crc32,
                    is_encrypted: node.is_encrypted,
                    score,
                    match_indices: indices,
                    entry_idx: node.entry_idx,
                });
            }

            for child in &node.children {
                search_node(matcher, query, child, out);
            }
        }

        for node in &self.root_nodes {
            search_node(&matcher, trimmed, node, &mut results);
        }

        results.sort_by(|a, b| b.score.cmp(&a.score));
        results
    }

    /// Exports flattened list of all nodes conforming to `TUIVfsTreeContract`.
    pub fn to_contract_nodes_flat(&self) -> Vec<serde_json::Value> {
        let mut out = Vec::new();
        fn collect(node: &VfsNode, out: &mut Vec<serde_json::Value>) {
            let mut obj = serde_json::json!({
                "name": node.name,
                "relativePath": node.relative_path,
                "isDirectory": node.is_dir,
                "uncompressedSize": node.uncompressed_size,
                "compressedSize": node.compressed_size,
                "crc32": node.crc32,
                "isEncrypted": node.is_encrypted,
            });
            if !node.match_indices.is_empty() {
                obj["matchIndices"] = serde_json::json!(node.match_indices);
            }
            out.push(obj);
            for child in &node.children {
                collect(child, out);
            }
        }
        for node in &self.root_nodes {
            collect(node, &mut out);
        }
        out
    }

    /// Serializes entire tree state into a JSON Value strictly conforming to `tui_vfs_tree_contract.json`.
    pub fn to_contract_json(&self) -> serde_json::Value {
        serde_json::json!({
            "rootPath": self.root_path,
            "totalEntriesCount": self.total_entries_count,
            "totalUncompressedBytes": self.total_uncompressed_bytes,
            "nodes": self.to_contract_nodes_flat()
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_metadata() -> Vec<VfsEntryMeta> {
        vec![
            VfsEntryMeta {
                path: "src/main.rs".to_string(),
                uncompressed_size: 1024,
                compressed_size: 400,
                crc32: 0x12345678,
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
                entry_idx: Some(0),
            },
            VfsEntryMeta {
                path: "src/vfs.rs".to_string(),
                uncompressed_size: 2048,
                compressed_size: 800,
                crc32: 0x87654321,
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
                entry_idx: Some(1),
            },
            VfsEntryMeta {
                path: "src/ui/mod.rs".to_string(),
                uncompressed_size: 512,
                compressed_size: 200,
                crc32: 0xABCDEF01,
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
                entry_idx: Some(2),
            },
            VfsEntryMeta {
                path: "assets/logo.png".to_string(),
                uncompressed_size: 65536,
                compressed_size: 60000,
                crc32: 0xCAFEBABE,
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: true,
                entry_idx: Some(3),
            },
            VfsEntryMeta {
                path: "README.md".to_string(),
                uncompressed_size: 256,
                compressed_size: 128,
                crc32: 0xDEADBEEF,
                mtime_epoch_secs: 1700000000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
                entry_idx: Some(4),
            },
        ]
    }

    #[test]
    fn test_vfs_tree_building_and_structure() {
        let metas = sample_metadata();
        let tree = VfsTree::from_metadata_list("test.zip", &metas);

        assert_eq!(tree.root_path, "test.zip");
        assert_eq!(tree.total_entries_count, 5);
        assert_eq!(tree.total_uncompressed_bytes, 1024 + 2048 + 512 + 65536 + 256);

        // Top level nodes: assets (dir), src (dir), and README.md (file)
        assert_eq!(tree.root_nodes.len(), 3);
        assert_eq!(tree.root_nodes[0].name, "assets");
        assert!(tree.root_nodes[0].is_dir);
        assert_eq!(tree.root_nodes[1].name, "src");
        assert!(tree.root_nodes[1].is_dir);
        assert_eq!(tree.root_nodes[2].name, "README.md");
        assert!(!tree.root_nodes[2].is_dir);

        // Check src directory children (ui dir, main.rs, vfs.rs)
        let src_node = &tree.root_nodes[1];
        assert_eq!(src_node.children.len(), 3);
        assert_eq!(src_node.children[0].name, "ui");
        assert!(src_node.children[0].is_dir);
        assert_eq!(src_node.children[1].name, "main.rs");
        assert_eq!(src_node.children[2].name, "vfs.rs");

        // Check aggregated sizes
        assert_eq!(src_node.uncompressed_size, 512 + 1024 + 2048);
    }

    #[test]
    fn test_toggle_expanded_and_flatten_visible() {
        let metas = sample_metadata();
        let mut tree = VfsTree::from_metadata_list("test.zip", &metas);

        // Initially nothing expanded
        assert_eq!(tree.flatten_visible().len(), 3); // assets, src, README.md
        assert_eq!(tree.visible_rows.len(), 3);

        // Expand src
        let expanded = tree.toggle_expanded("src");
        assert_eq!(expanded, Some(true));

        // assets, src, src/ui, src/main.rs, src/vfs.rs, README.md
        assert_eq!(tree.flatten_visible().len(), 6);
        assert_eq!(tree.visible_rows.len(), 6);

        // Expand src/ui
        let expanded_ui = tree.toggle_expanded("src/ui");
        assert_eq!(expanded_ui, Some(true));

        // assets, src, src/ui, src/ui/mod.rs, src/main.rs, src/vfs.rs, README.md
        assert_eq!(tree.flatten_visible().len(), 7);
        assert_eq!(tree.visible_rows.len(), 7);

        // Collapse src
        tree.toggle_expanded("src");
        assert_eq!(tree.flatten_visible().len(), 3);
        assert_eq!(tree.visible_rows.len(), 3);
    }

    #[test]
    fn test_toggle_selected_and_indices() {
        let metas = sample_metadata();
        let mut tree = VfsTree::from_metadata_list("test.zip", &metas);

        // Select src directory (should select src/main.rs, src/vfs.rs, src/ui/mod.rs)
        tree.toggle_selected("src");
        let selected_indices = tree.get_selected_entry_indices();
        assert_eq!(selected_indices.len(), 3);
        assert!(selected_indices.contains(&0)); // main.rs
        assert!(selected_indices.contains(&1)); // vfs.rs
        assert!(selected_indices.contains(&2)); // ui/mod.rs

        let paths = tree.get_selected_paths();
        assert_eq!(paths.len(), 3);

        // Toggle README.md
        tree.toggle_selected("README.md");
        let paths2 = tree.get_selected_paths();
        assert_eq!(paths2.len(), 4);

        // Deselect src
        tree.toggle_selected("src");
        let paths3 = tree.get_selected_paths();
        assert_eq!(paths3.len(), 1);
        assert_eq!(paths3[0], "README.md");
    }

    #[test]
    fn test_fuzzy_search_matching_and_indices() {
        let metas = sample_metadata();
        let tree = VfsTree::from_metadata_list("test.zip", &metas);

        // Search "vfs"
        let results = tree.fuzzy_search("vfs");
        assert!(!results.is_empty());
        assert_eq!(results[0].name, "vfs.rs");
        assert_eq!(results[0].entry_idx, Some(1));
        assert!(!results[0].match_indices.is_empty());

        // Search "logo"
        let logo_results = tree.fuzzy_search("logo");
        assert!(!logo_results.is_empty());
        assert_eq!(logo_results[0].name, "logo.png");
        assert_eq!(logo_results[0].relative_path, "assets/logo.png");
        assert!(logo_results[0].is_encrypted);

        // Search non-existent
        let empty_res = tree.fuzzy_search("nonexistentqueryxyz");
        assert!(empty_res.is_empty());
    }

    #[test]
    fn test_contract_compliance_json_structure() {
        let metas = sample_metadata();
        let tree = VfsTree::from_metadata_list("archive.zip", &metas);
        let json_val = tree.to_contract_json();

        assert_eq!(json_val["rootPath"], "archive.zip");
        assert_eq!(json_val["totalEntriesCount"], 5);
        assert_eq!(json_val["totalUncompressedBytes"], 1024 + 2048 + 512 + 65536 + 256);

        let nodes = json_val["nodes"].as_array().expect("nodes must be an array");
        assert!(!nodes.is_empty());

        for node in nodes {
            assert!(node.get("name").is_some());
            assert!(node.get("relativePath").is_some());
            assert!(node.get("isDirectory").is_some());
            assert!(node.get("uncompressedSize").is_some());
            assert!(node.get("compressedSize").is_some());
            assert!(node.get("crc32").is_some());
            assert!(node.get("isEncrypted").is_some());
        }
    }
}
