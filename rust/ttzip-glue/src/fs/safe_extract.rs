// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Safe extraction pipeline with ZipSlip path traversal defense and two-stage
//! bottom-up POSIX permission and timestamp restoration.

use crate::types::TTZipStatus;
use std::ffi::CString;
use std::fs::{self, File};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::path::{Component, Path, PathBuf};

/// Sanitizes a relative entry path and strictly validates that it does not escape `dest_dir`.
///
/// Defends against:
/// 1. Path traversal (`..`, `../..`, `/..`)
/// 2. Absolute root paths (`/etc/passwd`, `\Windows\System32`, `C:\`)
/// 3. Embedded null bytes (`\0`)
/// 4. Windows UNC paths (`\\server\share`)
pub fn sanitize_and_validate_path(dest_dir: &Path, raw_entry_path: &str) -> Result<PathBuf, TTZipStatus> {
    if raw_entry_path.is_empty() || raw_entry_path.contains('\0') {
        return Err(TTZipStatus::ErrSecurityViolation);
    }

    // Reject Windows drive letters (e.g. "C:", "D:") and UNC paths
    if raw_entry_path.len() >= 2 {
        let bytes = raw_entry_path.as_bytes();
        if bytes[1] == b':' && bytes[0].is_ascii_alphabetic() {
            return Err(TTZipStatus::ErrSecurityViolation);
        }
        if raw_entry_path.starts_with(r"\\") || raw_entry_path.starts_with("//") {
            return Err(TTZipStatus::ErrSecurityViolation);
        }
    }

    if raw_entry_path.starts_with('/') || raw_entry_path.starts_with('\\') || raw_entry_path.contains("://") {
        return Err(TTZipStatus::ErrSecurityViolation);
    }

    let normalized_slashes = raw_entry_path.replace('\\', "/");
    let input_path = Path::new(&normalized_slashes);
    let mut normalized_components = Vec::new();

    for comp in input_path.components() {
        match comp {
            Component::Normal(c) => {
                let s = c.to_string_lossy();
                // Reject internal ".." and multi-dot obfuscation (e.g. "...", "....")
                // Redundant check for internal ".." or multi-dot sequences
                if s.contains("..") || s.chars().all(|c| c == '.') {
                    return Err(TTZipStatus::ErrSecurityViolation);
                }
                normalized_components.push(s.to_string());
            }
            Component::CurDir => {
                // Ignore current directory '.'
            }
            Component::RootDir | Component::Prefix(_) | Component::ParentDir => {
                // Reject absolute root paths and parent traversals
                return Err(TTZipStatus::ErrSecurityViolation);
            }
        }
    }

    if normalized_components.is_empty() {
        return Err(TTZipStatus::ErrSecurityViolation);
    }

    let mut target = dest_dir.to_path_buf();
    for seg in normalized_components {
        target.push(seg);
    }

    // Ensure normalized path starts with destination directory prefix
    if !target.starts_with(dest_dir) {
        return Err(TTZipStatus::ErrSecurityViolation);
    }

    Ok(target)
}

/// Metadata record for deferred application after archive extraction completes.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeferredEntryMetadata {
    pub path: PathBuf,
    pub mode: u32,
    pub mtime_epoch_secs: i64,
    pub mtime_nanos: u32,
    pub is_directory: bool,
}

impl DeferredEntryMetadata {
    /// Depth of the directory tree for bottom-up sorting.
    pub fn depth(&self) -> usize {
        self.path.components().count()
    }
}

/// Engine managing two-stage safe extraction and bottom-up metadata application.
#[derive(Debug, Default)]
pub struct SafeExtractEngine {
    deferred_entries: Vec<DeferredEntryMetadata>,
}

impl SafeExtractEngine {
    pub fn new() -> Self {
        Self {
            deferred_entries: Vec::new(),
        }
    }

    /// Registers an entry for deferred metadata application.
    pub fn register_entry(
        &mut self,
        path: PathBuf,
        mode: u32,
        mtime_epoch_secs: i64,
        mtime_nanos: u32,
        is_directory: bool,
    ) {
        self.deferred_entries.push(DeferredEntryMetadata {
            path,
            mode,
            mtime_epoch_secs,
            mtime_nanos,
            is_directory,
        });
    }

    /// Applies all deferred metadata with permissions preserved.
    pub fn apply_all(&mut self) -> Result<(), TTZipStatus> {
        self.apply_deferred_metadata(true)
    }

    /// Creates directory hierarchy with temporary restricted `0700` POSIX permissions.
    pub fn create_dir_all_secure(&mut self, path: &Path, mode: u32, mtime_secs: i64) -> std::io::Result<()> {
        let mut builder = fs::DirBuilder::new();
        builder.recursive(true);
        builder.mode(0o700); // Stage 1: Temporary restricted permissions

        builder.create(path)?;

        self.deferred_entries.push(DeferredEntryMetadata {
            path: path.to_path_buf(),
            mode,
            mtime_epoch_secs: mtime_secs,
            mtime_nanos: 0,
            is_directory: true,
        });

        Ok(())
    }

    /// Securely creates and opens a destination file with `O_NOFOLLOW` flag to prevent symlink hijack.
    pub fn create_file_secure(
        &mut self,
        path: &Path,
        mode: u32,
        mtime_secs: i64,
        overwrite_existing: bool,
    ) -> std::io::Result<File> {
        let mut options = fs::OpenOptions::new();
        options.write(true).create(true);

        if overwrite_existing {
            options.truncate(true);
        } else {
            options.create_new(true);
        }

        // Apply O_NOFOLLOW to ensure we never follow symlinks during file creation
        options.custom_flags(libc::O_NOFOLLOW);
        options.mode(0o600); // Stage 1: Temporary restricted user-only mode

        let file = options.open(path)?;

        self.deferred_entries.push(DeferredEntryMetadata {
            path: path.to_path_buf(),
            mode,
            mtime_epoch_secs: mtime_secs,
            mtime_nanos: 0,
            is_directory: false,
        });

        Ok(file)
    }

    /// Stage 2: Post-extraction deferred metadata application in Bottom-Up order.
    ///
    /// Directories are sorted deepest-first (longest path / highest component count)
    /// to prevent changing parent permissions (e.g. to read-only 0555) before child
    /// entries have their metadata and timestamps applied.
    pub fn apply_deferred_metadata(&mut self, preserve_permissions: bool) -> Result<(), TTZipStatus> {
        // Separate files and directories
        let mut files = Vec::new();
        let mut dirs = Vec::new();

        for entry in self.deferred_entries.drain(..) {
            if entry.is_directory {
                dirs.push(entry);
            } else {
                files.push(entry);
            }
        }

        // 1. Apply file metadata first
        for file in files {
            Self::apply_single_entry_metadata(&file, preserve_permissions)?;
        }

        // 2. Sort directories Bottom-Up (descending depth, deepest child first)
        dirs.sort_by(|a, b| b.depth().cmp(&a.depth()).then_with(|| b.path.cmp(&a.path)));

        // 3. Apply directory metadata in bottom-up sequence
        for dir in dirs {
            Self::apply_single_entry_metadata(&dir, preserve_permissions)?;
        }

        Ok(())
    }

    fn apply_single_entry_metadata(entry: &DeferredEntryMetadata, preserve_permissions: bool) -> Result<(), TTZipStatus> {
        let path_str = match entry.path.to_str() {
            Some(s) => s,
            None => return Err(TTZipStatus::ErrInvalidParam),
        };

        let c_path = match CString::new(path_str) {
            Ok(c) => c,
            Err(_) => return Err(TTZipStatus::ErrInvalidParam),
        };

        unsafe {
            // Check using lstat to verify entry is NOT a symlink (TOCTOU defense)
            let mut st: libc::stat = std::mem::zeroed();
            if libc::lstat(c_path.as_ptr(), &mut st) != 0 {
                return Err(TTZipStatus::ErrFileNotFound);
            }

            // Ensure not a symlink
            if (st.st_mode & libc::S_IFMT) == libc::S_IFLNK {
                return Err(TTZipStatus::ErrSecurityViolation);
            }

            // Apply POSIX permissions if requested
            if preserve_permissions && entry.mode != 0 {
                let target_mode = (entry.mode & 0o7777) as libc::mode_t;
                if libc::chmod(c_path.as_ptr(), target_mode) != 0 {
                    return Err(TTZipStatus::ErrExtractionFailed);
                }
            }

            // Apply modified timestamp (mtime)
            if entry.mtime_epoch_secs > 0 {
                let times = [
                    libc::timespec {
                        tv_sec: entry.mtime_epoch_secs as libc::time_t,
                        tv_nsec: entry.mtime_nanos as libc::c_long,
                    },
                    libc::timespec {
                        tv_sec: entry.mtime_epoch_secs as libc::time_t,
                        tv_nsec: entry.mtime_nanos as libc::c_long,
                    },
                ];
                libc::utimensat(libc::AT_FDCWD, c_path.as_ptr(), times.as_ptr(), libc::AT_SYMLINK_NOFOLLOW);
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::os::unix::fs::PermissionsExt;

    #[test]
    fn test_zipslip_traversal_rejection() {
        let dest = Path::new("/tmp/ttzip_safe_extract_test");

        assert_eq!(
            sanitize_and_validate_path(dest, "../../etc/passwd"),
            Err(TTZipStatus::ErrSecurityViolation)
        );
        assert_eq!(
            sanitize_and_validate_path(dest, "/etc/shadow"),
            Err(TTZipStatus::ErrSecurityViolation)
        );
        assert_eq!(
            sanitize_and_validate_path(dest, "a/../../etc/passwd"),
            Err(TTZipStatus::ErrSecurityViolation)
        );
        assert_eq!(
            sanitize_and_validate_path(dest, "C:\\Windows\\System32"),
            Err(TTZipStatus::ErrSecurityViolation)
        );
        assert_eq!(
            sanitize_and_validate_path(dest, "\\\\evil_server\\share"),
            Err(TTZipStatus::ErrSecurityViolation)
        );
        assert_eq!(
            sanitize_and_validate_path(dest, "valid_file.txt\0payload"),
            Err(TTZipStatus::ErrSecurityViolation)
        );
    }

    #[test]
    fn test_valid_path_sanitization() {
        let dest = Path::new("/tmp/ttzip_safe_extract_test");
        let valid = sanitize_and_validate_path(dest, "folder/subfolder/file.txt").unwrap();
        assert_eq!(valid, dest.join("folder/subfolder/file.txt"));

        let dotted = sanitize_and_validate_path(dest, "./dir/./nested/./test.dat").unwrap();
        assert_eq!(dotted, dest.join("dir/nested/test.dat"));
    }

    #[test]
    fn test_two_stage_extraction_and_bottom_up_metadata() {
        let temp_dir = std::env::temp_dir().join("ttzip_test_two_stage");
        let _ = fs::remove_dir_all(&temp_dir);
        fs::create_dir_all(&temp_dir).unwrap();

        let mut engine = SafeExtractEngine::new();

        let sub_dir = temp_dir.join("level1/level2");
        engine.create_dir_all_secure(&sub_dir, 0o755, 1700000000).unwrap();

        let file_path = sub_dir.join("sample.txt");
        let mut f = engine.create_file_secure(&file_path, 0o644, 1700000000, true).unwrap();
        f.write_all(b"Safe extraction content").unwrap();
        drop(f);

        // Verify stage 1 temporary permissions
        let file_meta = fs::metadata(&file_path).unwrap();
        assert_eq!(file_meta.permissions().mode() & 0o777, 0o600);

        // Stage 2: Apply deferred metadata bottom-up
        engine.apply_deferred_metadata(true).unwrap();

        // Verify stage 2 final permissions applied
        let final_file_meta = fs::metadata(&file_path).unwrap();
        assert_eq!(final_file_meta.permissions().mode() & 0o777, 0o644);

        let final_dir_meta = fs::metadata(&sub_dir).unwrap();
        assert_eq!(final_dir_meta.permissions().mode() & 0o777, 0o755);

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
