// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Multi-volume split archive writer with byte-level accuracy and volume rotation.

use super::VolumeNamingScheme;
use std::fs::{self, File};
use std::io::{self, Write};
use std::path::{Path, PathBuf};

/// Computes volume file path for the given 1-based index according to the naming scheme.
pub fn compute_volume_path(
    base_path: &Path,
    index: usize,
    naming_scheme: VolumeNamingScheme,
) -> PathBuf {
    match naming_scheme {
        VolumeNamingScheme::NumberedExtension => {
            // Standard: archive.7z.001, archive.zip.001, archive.tar.001
            PathBuf::from(format!("{}.{:03}", base_path.display(), index))
        }
        VolumeNamingScheme::PkzipSpanned => {
            // PKZIP standard: archive.z01, archive.z02, ... archive.zip (final part renamed on close)
            let parent = base_path.parent().unwrap_or_else(|| Path::new(""));
            let stem = base_path
                .file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or("archive");
            parent.join(format!("{}.z{:02}", stem, index))
        }
        VolumeNamingScheme::RawSplit => {
            // Raw split: archive.001, archive.002
            PathBuf::from(format!("{}.{:03}", base_path.display(), index))
        }
    }
}

/// Zero-copy multi-volume split archive writer sink.
///
/// Intercepts archive byte streams in real time at byte-level accuracy, seamlessly closing
/// the active volume and opening subsequent volume files without intermediate memory copies.
pub struct SplitVolumeWriter {
    base_path: PathBuf,
    volume_size_bytes: u64,
    naming_scheme: VolumeNamingScheme,
    clean_on_failure: bool,
    current_volume_index: usize,
    bytes_written_in_current: u64,
    total_bytes_written: u64,
    active_file: Option<File>,
    generated_volume_paths: Vec<PathBuf>,
    is_closed: bool,
}

impl SplitVolumeWriter {
    /// Creates a new `SplitVolumeWriter` targeting `base_path`.
    pub fn new(
        base_path: impl AsRef<Path>,
        volume_size_bytes: u64,
        naming_scheme: VolumeNamingScheme,
    ) -> io::Result<Self> {
        if volume_size_bytes == 0 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Volume size must be greater than zero",
            ));
        }

        let base_path_buf = base_path.as_ref().to_path_buf();
        if let Some(parent) = base_path_buf.parent() {
            if !parent.as_os_str().is_empty() && !parent.exists() {
                fs::create_dir_all(parent)?;
            }
        }

        let mut writer = Self {
            base_path: base_path_buf,
            volume_size_bytes,
            naming_scheme,
            clean_on_failure: true,
            current_volume_index: 1,
            bytes_written_in_current: 0,
            total_bytes_written: 0,
            active_file: None,
            generated_volume_paths: Vec::new(),
            is_closed: false,
        };

        writer.open_volume(1)?;
        Ok(writer)
    }

    /// Configures whether generated volumes should be purged on cancellation/failure.
    pub fn with_clean_on_failure(mut self, clean: bool) -> Self {
        self.clean_on_failure = clean;
        self
    }

    /// Total bytes written across all volumes so far.
    #[inline]
    pub fn total_bytes(&self) -> u64 {
        self.total_bytes_written
    }

    /// Returns list of all generated volume paths.
    #[inline]
    pub fn generated_volumes(&self) -> &[PathBuf] {
        &self.generated_volume_paths
    }

    /// Whether the writer has been closed.
    #[inline]
    pub fn is_closed(&self) -> bool {
        self.is_closed
    }

    /// Opens a volume file for writing at `index` (1-based).
    fn open_volume(&mut self, index: usize) -> io::Result<()> {
        let path = compute_volume_path(&self.base_path, index, self.naming_scheme);
        if path.exists() {
            let _ = fs::remove_file(&path);
        }

        let file = File::create(&path)?;
        self.active_file = Some(file);
        self.current_volume_index = index;
        self.bytes_written_in_current = 0;
        self.generated_volume_paths.push(path);
        Ok(())
    }

    /// Rotates from the active volume to the next volume index.
    fn rotate_to_next_volume(&mut self) -> io::Result<()> {
        if let Some(mut file) = self.active_file.take() {
            file.flush()?;
        }
        self.open_volume(self.current_volume_index + 1)
    }

    /// Flushes and closes all volume handles, applying final volume naming conventions.
    pub fn close(&mut self) -> io::Result<Vec<PathBuf>> {
        if self.is_closed {
            return Ok(self.generated_volume_paths.clone());
        }
        self.is_closed = true;

        if let Some(mut file) = self.active_file.take() {
            file.flush()?;
        }

        // For PKZIP spanned format, rename the last volume to base_path (e.g. archive.zip)
        if self.naming_scheme == VolumeNamingScheme::PkzipSpanned
            && !self.generated_volume_paths.is_empty()
        {
            let last_path = self.generated_volume_paths.pop().unwrap();
            let final_zip_path = self.base_path.clone();
            if last_path != final_zip_path {
                if final_zip_path.exists() {
                    let _ = fs::remove_file(&final_zip_path);
                }
                fs::rename(&last_path, &final_zip_path)?;
            }
            self.generated_volume_paths.push(final_zip_path);
        }

        Ok(self.generated_volume_paths.clone())
    }

    /// Purges all generated volumes in the event of an archive failure.
    pub fn cancel_and_cleanup(&mut self) {
        self.is_closed = true;
        self.active_file = None;

        if self.clean_on_failure {
            for path in &self.generated_volume_paths {
                let _ = fs::remove_file(path);
            }
        }
        self.generated_volume_paths.clear();
    }
}

impl Write for SplitVolumeWriter {
    fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
        if self.is_closed {
            return Err(io::Error::new(
                io::ErrorKind::Other,
                "Cannot write to a closed SplitVolumeWriter",
            ));
        }

        if buf.is_empty() {
            return Ok(0);
        }

        let mut bytes_remaining = buf.len();
        let mut current_offset = 0;

        while bytes_remaining > 0 {
            let space_in_current = self
                .volume_size_bytes
                .saturating_sub(self.bytes_written_in_current);
            let to_write = (bytes_remaining as u64).min(space_in_current) as usize;

            if to_write > 0 {
                let file = self.active_file.as_mut().ok_or_else(|| {
                    io::Error::new(io::ErrorKind::NotFound, "No active volume file")
                })?;
                file.write_all(&buf[current_offset..current_offset + to_write])?;
                self.bytes_written_in_current += to_write as u64;
                self.total_bytes_written += to_write as u64;
                current_offset += to_write;
                bytes_remaining -= to_write;
            }

            if self.bytes_written_in_current >= self.volume_size_bytes && bytes_remaining > 0 {
                self.rotate_to_next_volume()?;
            }
        }

        Ok(buf.len())
    }

    fn flush(&mut self) -> io::Result<()> {
        if let Some(file) = self.active_file.as_mut() {
            file.flush()
        } else {
            Ok(())
        }
    }
}

impl Drop for SplitVolumeWriter {
    fn drop(&mut self) {
        if !self.is_closed {
            let _ = self.close();
        }
    }
}
