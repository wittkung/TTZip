// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

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
