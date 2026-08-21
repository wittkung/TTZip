// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Standalone CLI Engine and Interactive TUI Runner for TTZip.

pub mod args;
pub mod braille_plotter;
pub mod format;
pub mod handlers;
pub mod tui_runner;

pub use args::*;
pub use braille_plotter::*;
pub use format::*;
pub use handlers::*;
pub use tui_runner::*;

#[cfg(test)]
mod tests;

#[cfg(test)]
mod tests_integration;
