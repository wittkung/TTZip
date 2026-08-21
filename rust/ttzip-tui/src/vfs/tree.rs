// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! VFS Tree Container, mutation operations, tree traversal, and contract JSON serialization.

use super::meta::VfsEntryMeta;
use super::node::VfsNode;
use super::search::{fuzzy_search_nodes, VfsSearchResult};
use super::view::{build_visible_rows, flatten_visible_nodes, VfsRow, VfsVisibleItem};
use serde::{Deserialize, Serialize};

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

        tree.root_nodes.sort_by(|a, b| match (a.is_dir, b.is_dir) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => a.name.to_lowercase().cmp(&b.name.to_lowercase()),
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
                        let dir_node = VfsNode::new_dir(segment.to_string(), accumulated_path.clone());
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
        self.visible_rows = build_visible_rows(&self.root_nodes);
    }

    /// Returns a flat list of all nodes currently visible in the UI according to `is_expanded`.
    pub fn flatten_visible(&self) -> Vec<VfsVisibleItem<'_>> {
        flatten_visible_nodes(&self.root_nodes)
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
        fuzzy_search_nodes(&self.root_nodes, query)
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
