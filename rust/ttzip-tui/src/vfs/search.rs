// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! VFS Instant Fuzzy Search match structures and algorithms.

use super::node::VfsNode;
use fuzzy_matcher::skim::SkimMatcherV2;
use fuzzy_matcher::FuzzyMatcher;
use serde::{Deserialize, Serialize};

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

/// Performs fuzzy search on a node hierarchy recursively using `SkimMatcherV2`.
pub fn fuzzy_search_nodes(root_nodes: &[VfsNode], query: &str) -> Vec<VfsSearchResult> {
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

    for node in root_nodes {
        search_node(&matcher, trimmed, node, &mut results);
    }

    results.sort_by(|a, b| b.score.cmp(&a.score));
    results
}
