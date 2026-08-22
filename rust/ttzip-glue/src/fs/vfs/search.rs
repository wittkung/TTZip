// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-performance fuzzy string matching and scoring algorithms for VFS trees.

use super::node::VfsNode;

/// Result of a fuzzy query match against a VFS node.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VfsSearchResult {
    pub name: String,
    pub path: String,
    pub is_directory: bool,
    pub uncompressed_size: u64,
    pub compressed_size: u64,
    pub crc32: u32,
    pub is_encrypted: bool,
    pub score: i64,
    pub match_indices: Vec<usize>,
}

/// Evaluates fuzzy string matching score and byte match indices.
pub fn fuzzy_match(target: &str, pattern: &str) -> Option<(i64, Vec<usize>)> {
    let pat = pattern.trim();
    if pat.is_empty() {
        return Some((0, Vec::new()));
    }

    let target_chars: Vec<char> = target.chars().collect();
    let pat_chars: Vec<char> = pat.chars().collect();
    if pat_chars.len() > target_chars.len() {
        return None;
    }

    let mut t_idx = 0;
    let mut p_idx = 0;
    let mut indices = Vec::with_capacity(pat_chars.len());
    let mut score = 0i64;
    let mut prev_matched_idx: Option<usize> = None;

    while t_idx < target_chars.len() && p_idx < pat_chars.len() {
        let tc = target_chars[t_idx];
        let pc = pat_chars[p_idx];

        if tc.eq_ignore_ascii_case(&pc) {
            indices.push(t_idx);
            let mut char_score = 10i64;
            if tc == pc {
                char_score += 5; // Exact case match
            }

            // Word boundary bonus
            if t_idx == 0 {
                char_score += 30;
            } else {
                let prev_c = target_chars[t_idx - 1];
                if prev_c == '/' || prev_c == '\\' || prev_c == '_' || prev_c == '-' || prev_c == '.' || prev_c == ' ' {
                    char_score += 30;
                } else if prev_c.is_lowercase() && tc.is_uppercase() {
                    char_score += 25; // CamelCase boundary
                }
            }

            // Consecutive match bonus
            if let Some(prev) = prev_matched_idx {
                if t_idx == prev + 1 {
                    char_score += 20;
                } else {
                    char_score -= (t_idx - prev - 1) as i64; // Distance penalty
                }
            }

            score += char_score;
            prev_matched_idx = Some(t_idx);
            p_idx += 1;
        }
        t_idx += 1;
    }

    if p_idx == pat_chars.len() {
        if target.eq_ignore_ascii_case(pat) {
            score += 500;
        } else if target.to_lowercase().starts_with(&pat.to_lowercase()) {
            score += 200;
        }
        Some((score, indices))
    } else {
        None
    }
}

/// Recursively searches nodes in hierarchy and returns sorted matching items.
pub fn fuzzy_search_tree(root_node: &VfsNode, query: &str) -> Vec<VfsSearchResult> {
    let mut results = Vec::new();
    fn traverse(node: &VfsNode, query: &str, out: &mut Vec<VfsSearchResult>) {
        let name_match = fuzzy_match(&node.name, query);
        let path_match = fuzzy_match(&node.path, query);

        if let Some((score, indices)) = name_match {
            out.push(VfsSearchResult {
                name: node.name.clone(),
                path: node.path.clone(),
                is_directory: node.is_directory,
                uncompressed_size: node.uncompressed_size,
                compressed_size: node.compressed_size,
                crc32: node.crc32,
                is_encrypted: node.is_encrypted,
                score: score + 100, // Boost filename matches
                match_indices: indices,
            });
        } else if let Some((score, indices)) = path_match {
            out.push(VfsSearchResult {
                name: node.name.clone(),
                path: node.path.clone(),
                is_directory: node.is_directory,
                uncompressed_size: node.uncompressed_size,
                compressed_size: node.compressed_size,
                crc32: node.crc32,
                is_encrypted: node.is_encrypted,
                score,
                match_indices: indices,
            });
        }

        for child in &node.children {
            traverse(child, query, out);
        }
    }

    for child in &root_node.children {
        traverse(child, query, &mut results);
    }
    results.sort_by_key(|b| std::cmp::Reverse(b.score));
    results
}
