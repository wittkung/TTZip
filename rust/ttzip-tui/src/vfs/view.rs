// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! VFS View presentation models for TUI table rendering and visible tree traversal.

use super::node::VfsNode;
use serde::{Deserialize, Serialize};

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

/// Regenerates visible table rows from the tree node hierarchy based on expansion state.
pub fn build_visible_rows(root_nodes: &[VfsNode]) -> Vec<VfsRow> {
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

    build_rows(root_nodes, 0, &mut rows);
    rows
}

/// Traverses tree nodes returning a flat list of all currently visible items in the UI.
pub fn flatten_visible_nodes<'a>(root_nodes: &'a [VfsNode]) -> Vec<VfsVisibleItem<'a>> {
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
                let next_prefix = if depth == 0 { "" } else if is_last { "    " } else { "│   " };
                let combined_prefix = format!("{}{}", prefix, next_prefix);
                traverse(&node.children, depth + 1, &combined_prefix, out);
            }
        }
    }

    traverse(root_nodes, 0, "", &mut items);
    items
}
