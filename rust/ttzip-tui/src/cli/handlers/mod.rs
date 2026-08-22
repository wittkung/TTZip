// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Subcommand execution handlers for all headless CLI commands.

pub mod bench;
pub mod cat;
pub mod check;
pub mod comment;
pub mod convert;
pub mod create;
pub mod delete;
pub mod diff;
pub mod doctor;
pub mod extract;
pub mod hash;
pub mod info;
pub mod list;
pub mod lock;
pub mod recover;
pub mod repair;
pub mod split;
pub mod tree;
pub mod update;

pub use bench::*;
pub use cat::*;
pub use check::*;
pub use comment::*;
pub use convert::*;
pub use create::*;
pub use delete::*;
pub use diff::*;
pub use doctor::*;
pub use extract::*;
pub use hash::*;
pub use info::*;
pub use list::*;
pub use lock::*;
pub use recover::*;
pub use repair::*;
pub use split::*;
pub use tree::*;
pub use update::*;
