// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! File preview extraction and syntax highlighting integration.

use super::state::AppState;
use crate::preview::{generate_preview, PreviewData};
use ttzip_glue::sevenz::SevenZArchive;
use ttzip_glue::zip::ZipArchive;

impl AppState {
    /// Updates preview buffer for the currently selected item.
    pub fn update_preview_content(&mut self) {
        let node_info = {
            let visible = self.vfs.flatten_visible();
            visible.get(self.selected_index).map(|item| {
                (
                    item.node.is_dir,
                    item.node.name.clone(),
                    item.node.uncompressed_size,
                    item.node.relative_path.clone(),
                )
            })
        };

        if let Some((is_dir, filename, full_size, rel_path)) = node_info {
            if is_dir {
                self.preview_content = Some(PreviewData::Unsupported {
                    reason: "Directories cannot be previewed".to_string(),
                    file_size_bytes: 0,
                });
                self.preview_scroll = 0;
                return;
            }

            let raw_data = self.archive_raw_data.clone();

            // Extract stream bytes for preview
            let preview_bytes = if self.archive_format == "ZIP" {
                if let Ok(archive) = ZipArchive::open_slice(&raw_data) {
                    if let Some(idx) = archive.entries().iter().position(|e| e.rel_path == rel_path) {
                        archive.extract_entry_bytes(idx, None).unwrap_or_default()
                    } else {
                        Vec::new()
                    }
                } else {
                    Vec::new()
                }
            } else if self.archive_format == "7-Zip" {
                if let Ok(archive) = SevenZArchive::open_slice(&raw_data) {
                    if let Some(idx) = archive.files().iter().position(|f| f.rel_path == rel_path) {
                        archive.extract_entry_bytes(idx, None).unwrap_or_default()
                    } else {
                        Vec::new()
                    }
                } else {
                    Vec::new()
                }
            } else {
                Vec::new()
            };

            let preview = generate_preview(&filename, &preview_bytes, full_size, &self.highlighter);
            self.preview_content = Some(preview);
            self.preview_scroll = 0;
        }
    }
}
