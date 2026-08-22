// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Streaming PAX-format TAR Archive Generator.
//!
//! Generates POSIX.1-2001 PAX compliant archives supporting arbitrary path lengths,
//! large file sizes (>8GB), symlinks, directories, and 512-byte alignment padding.

use super::header::*;
use super::pax::build_pax_payload;
use crate::types::TTZipStatus;
use std::collections::HashMap;
use std::io::Write;

/// Streaming PAX format TAR Archive Writer.
pub struct TarWriter<W: Write> {
    inner: W,
    finished: bool,
}

impl<W: Write> TarWriter<W> {
    /// Creates a new streaming TAR writer wrapping any `std::io::Write` sink.
    pub fn new(inner: W) -> Self {
        Self {
            inner,
            finished: false,
        }
    }

    /// Appends a regular file entry to the TAR archive.
    pub fn append_file(
        &mut self,
        rel_path: &str,
        data: &[u8],
        mode: u32,
        mtime: i64,
    ) -> Result<(), TTZipStatus> {
        self.append_custom_entry(rel_path, data, mode, mtime, TYPE_REGULAR, None, None)
    }

    /// Appends a directory entry to the TAR archive.
    pub fn append_dir(&mut self, rel_path: &str, mode: u32, mtime: i64) -> Result<(), TTZipStatus> {
        let mut dir_path = rel_path.to_string();
        if !dir_path.ends_with('/') {
            dir_path.push('/');
        }
        self.append_custom_entry(&dir_path, &[], mode, mtime, TYPE_DIRECTORY, None, None)
    }

    /// Appends a symbolic link entry to the TAR archive.
    pub fn append_symlink(
        &mut self,
        rel_path: &str,
        target: &str,
        mode: u32,
        mtime: i64,
    ) -> Result<(), TTZipStatus> {
        self.append_custom_entry(rel_path, &[], mode, mtime, TYPE_SYMLINK, Some(target), None)
    }

    /// Appends an entry with custom typeflag, link target, and optional PAX extra records.
    #[allow(clippy::too_many_arguments)]
    pub fn append_custom_entry(
        &mut self,
        rel_path: &str,
        data: &[u8],
        mode: u32,
        mtime: i64,
        typeflag: u8,
        link_target: Option<&str>,
        pax_extra: Option<&HashMap<String, String>>,
    ) -> Result<(), TTZipStatus> {
        let normalized_path = rel_path.replace('\\', "/");
        let path_len = normalized_path.len();
        let size = data.len() as u64;
        let link_len = link_target.map(|s| s.len()).unwrap_or(0);

        // Check if PAX Extended Header is necessary
        let needs_pax = path_len > 100
            || link_len > 100
            || size >= 0o77777777777 // 8GB octal limit
            || mtime > 0o77777777777
            || pax_extra.is_some();

        if needs_pax {
            let mut pax_records = Vec::new();
            if path_len > 100 {
                pax_records.push(("path", normalized_path.as_str()));
            }
            if let Some(target) = link_target {
                if link_len > 100 {
                    pax_records.push(("linkpath", target));
                }
            }
            let size_str;
            if size >= 0o77777777777 {
                size_str = size.to_string();
                pax_records.push(("size", &size_str));
            }
            let mtime_str;
            if mtime > 0o77777777777 {
                mtime_str = mtime.to_string();
                pax_records.push(("mtime", &mtime_str));
            }

            if let Some(extra) = pax_extra {
                for (k, v) in extra {
                    pax_records.push((k.as_str(), v.as_str()));
                }
            }

            let pax_payload = build_pax_payload(&pax_records);
            let pax_filename = format!("PaxHeaders.0/{}", normalized_path.rsplit('/').next().unwrap_or("entry"));
            let pax_header = TarHeader {
                name: pax_filename,
                mode: 0o644,
                uid: 0,
                gid: 0,
                size: pax_payload.len() as u64,
                mtime: mtime.max(0),
                chksum: 0,
                typeflag: TYPE_PAX_EXT_HEADER,
                linkname: String::new(),
                magic: *MAGIC_USTAR,
                version: *VERSION_USTAR,
                uname: "root".to_string(),
                gname: "root".to_string(),
                devmajor: 0,
                devminor: 0,
                prefix: String::new(),
            };

            let pax_block = build_tar_header_block(&pax_header);
            self.inner
                .write_all(&pax_block)
                .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
            self.inner
                .write_all(&pax_payload)
                .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

            let pax_pad = (TAR_BLOCK_SIZE - (pax_payload.len() % TAR_BLOCK_SIZE)) % TAR_BLOCK_SIZE;
            if pax_pad > 0 {
                self.inner
                    .write_all(&vec![0u8; pax_pad])
                    .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
            }
        }

        // Standard ustar Header
        let short_name = if normalized_path.len() > 100 {
            normalized_path[..100].to_string()
        } else {
            normalized_path.clone()
        };

        let short_link = link_target
            .map(|s| {
                if s.len() > 100 {
                    s[..100].to_string()
                } else {
                    s.to_string()
                }
            })
            .unwrap_or_default();

        let header = TarHeader {
            name: short_name,
            mode: if mode != 0 { mode } else if typeflag == TYPE_DIRECTORY { 0o755 } else { 0o644 },
            uid: 0,
            gid: 0,
            size,
            mtime: mtime.max(0),
            chksum: 0,
            typeflag,
            linkname: short_link,
            magic: *MAGIC_USTAR,
            version: *VERSION_USTAR,
            uname: String::new(),
            gname: String::new(),
            devmajor: 0,
            devminor: 0,
            prefix: String::new(),
        };

        let block = build_tar_header_block(&header);
        self.inner
            .write_all(&block)
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

        // Write payload
        if !data.is_empty() {
            self.inner
                .write_all(data)
                .map_err(|_| TTZipStatus::ErrCompressionFailed)?;

            let pad = (TAR_BLOCK_SIZE - (data.len() % TAR_BLOCK_SIZE)) % TAR_BLOCK_SIZE;
            if pad > 0 {
                self.inner
                    .write_all(&vec![0u8; pad])
                    .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
            }
        }

        Ok(())
    }

    /// Finishes the archive by writing the standard two 512-byte zero blocks.
    pub fn finish(&mut self) -> Result<(), TTZipStatus> {
        if self.finished {
            return Ok(());
        }
        let zero_blocks = [0u8; TAR_BLOCK_SIZE * 2];
        self.inner
            .write_all(&zero_blocks)
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        self.inner
            .flush()
            .map_err(|_| TTZipStatus::ErrCompressionFailed)?;
        self.finished = true;
        Ok(())
    }
}
