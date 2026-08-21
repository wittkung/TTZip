// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Unified VFS Tree management and entry path hierarchy indexing.

use super::node::{VfsEntry, VfsNode};
use super::search::{fuzzy_search_tree, VfsSearchResult};

/// Unified VFS Tree managing hierarchical archive representation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VfsTree {
    pub root: VfsNode,
    pub total_entries: usize,
}

impl VfsTree {
    pub fn new(root_name: &str) -> Self {
        Self {
            root: VfsNode::new_dir(root_name, ""),
            total_entries: 0,
        }
    }

    /// Constructs a hierarchical VFS tree from a slice of metadata entries.
    pub fn build_from_entries(entries: &[VfsEntry], root_name: &str) -> Self {
        let mut tree = Self::new(root_name);
        for entry in entries {
            tree.insert(entry);
        }
        tree.root.recalculate_sizes();
        tree.root.sort_recursive();
        tree
    }

    /// Inserts a metadata entry into the tree hierarchy.
    pub fn insert(&mut self, entry: &VfsEntry) {
        let clean_path = entry.path.trim_matches('/');
        if clean_path.is_empty() {
            return;
        }

        self.total_entries += 1;
        let segments: Vec<&str> = clean_path.split('/').collect();
        let mut curr = &mut self.root;
        let mut accum_path = String::new();

        for (i, &segment) in segments.iter().enumerate() {
            let is_last = i == segments.len() - 1;
            if !accum_path.is_empty() {
                accum_path.push('/');
            }
            accum_path.push_str(segment);

            if is_last {
                if let Some(pos) = curr.children.iter().position(|c| c.name == segment) {
                    let node = &mut curr.children[pos];
                    node.is_directory = entry.is_directory;
                    node.uncompressed_size = entry.uncompressed_size;
                    node.compressed_size = entry.compressed_size;
                    node.crc32 = entry.crc32;
                    node.mtime_epoch_secs = entry.mtime_epoch_secs;
                    node.mode = entry.mode;
                    node.is_encrypted = entry.is_encrypted;
                } else {
                    let node = if entry.is_directory {
                        VfsNode::new_dir(segment, &accum_path)
                    } else {
                        VfsNode::new_file(segment, entry)
                    };
                    curr.children.push(node);
                }
            } else {
                let pos = match curr.children.iter().position(|c| c.name == segment && c.is_directory) {
                    Some(p) => p,
                    None => {
                        let dir = VfsNode::new_dir(segment, &accum_path);
                        curr.children.push(dir);
                        curr.children.len() - 1
                    }
                };
                curr = &mut curr.children[pos];
            }
        }
    }

    /// Renders ASCII/Unicode tree layout.
    pub fn render_tree(&self) -> String {
        let mut out = String::new();
        self.root.render_tree("", true, &mut out);
        out
    }

    /// Performs fuzzy search across all nodes in the tree hierarchy.
    pub fn fuzzy_search(&self, query: &str) -> Vec<VfsSearchResult> {
        fuzzy_search_tree(&self.root, query)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vfs_tree_build_and_render() {
        let entries = vec![
            VfsEntry {
                path: "Project/src/main.rs".to_string(),
                uncompressed_size: 150,
                compressed_size: 100,
                crc32: 0x1234,
                mtime_epoch_secs: 1000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
            },
            VfsEntry {
                path: "Project/README.md".to_string(),
                uncompressed_size: 200,
                compressed_size: 120,
                crc32: 0x5678,
                mtime_epoch_secs: 1000,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
            },
        ];

        let tree = VfsTree::build_from_entries(&entries, "Project");
        assert_eq!(tree.root.total_files(), 2);
        assert_eq!(tree.root.total_directories(), 2);
        assert_eq!(tree.root.uncompressed_size, 350);

        let rendered = tree.render_tree();
        assert!(rendered.contains("Project (<DIR>)"));
        assert!(rendered.contains("src (<DIR>)"));
        assert!(rendered.contains("main.rs (150 B)"));
        assert!(rendered.contains("README.md (200 B)"));
    }

    #[test]
    fn test_vfs_fuzzy_search() {
        let entries = vec![
            VfsEntry {
                path: "docs/architecture.md".to_string(),
                uncompressed_size: 1000,
                compressed_size: 500,
                crc32: 0,
                mtime_epoch_secs: 0,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
            },
            VfsEntry {
                path: "src/archive/writer.rs".to_string(),
                uncompressed_size: 2000,
                compressed_size: 800,
                crc32: 0,
                mtime_epoch_secs: 0,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
            },
        ];

        let tree = VfsTree::build_from_entries(&entries, "root");
        let results = tree.fuzzy_search("arch");
        assert!(!results.is_empty());
        assert_eq!(results[0].name, "architecture.md");

        let writer_results = tree.fuzzy_search("writer");
        assert!(!writer_results.is_empty());
        assert_eq!(writer_results[0].name, "writer.rs");
    }

    #[test]
    fn test_vfs_nested_deep_tree_sizes() {
        let entries = vec![
            VfsEntry {
                path: "a/b/c/d/file1.bin".to_string(),
                uncompressed_size: 1024,
                compressed_size: 512,
                crc32: 0x1111,
                mtime_epoch_secs: 0,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
            },
            VfsEntry {
                path: "a/b/c/d/file2.bin".to_string(),
                uncompressed_size: 2048,
                compressed_size: 1024,
                crc32: 0x2222,
                mtime_epoch_secs: 0,
                mode: 0o644,
                is_directory: false,
                is_encrypted: false,
            },
        ];

        let tree = VfsTree::build_from_entries(&entries, "root");
        assert_eq!(tree.root.total_files(), 2);
        assert_eq!(tree.root.total_directories(), 4); // a, b, c, d
        assert_eq!(tree.root.uncompressed_size, 3072);
        assert_eq!(tree.root.compressed_size, 1536);
    }
}
