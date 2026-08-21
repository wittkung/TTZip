// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Core Application State Machine, Key Action Dispatch, and Safe Extraction Integration.

pub mod extract;
pub mod input;
pub mod preview;
pub mod state;
pub mod types;

pub use state::*;
pub use types::*;

#[cfg(test)]
mod tests;
