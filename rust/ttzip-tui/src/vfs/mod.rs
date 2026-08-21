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

pub mod meta;
pub mod node;
pub mod search;
pub mod tree;
pub mod view;

pub use meta::*;
pub use node::*;
pub use search::*;
pub use tree::*;
pub use view::*;

#[cfg(test)]
mod tests;
