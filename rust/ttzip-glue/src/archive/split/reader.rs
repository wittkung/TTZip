// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Virtual continuous multi-volume reader with topology detection and linear offset table.

use std::fs::{self, File};
use std::io::{self, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

/// Segment information for a single volume file in the virtual chain.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VolumeSegment {
    pub path: PathBuf,
    pub file_size: u64,
    pub virtual_start_offset: u64,
    pub virtual_end_offset: u64, // Exclusive
}

/// Automatically detects the entire volume chain starting from any given volume in the chain.
pub fn detect_volume_chain(seed_path: &Path) -> io::Result<Vec<PathBuf>> {
    if !seed_path.exists() {
        return Err(io::Error::new(
            io::ErrorKind::NotFound,
            format!("Seed volume not found: {}", seed_path.display()),
        ));
    }

    let abs_seed = seed_path.to_path_buf();
    let file_name = match seed_path.file_name().and_then(|n| n.to_str()) {
        Some(name) => name,
        None => return Ok(vec![abs_seed]),
    };
    let parent_dir = seed_path.parent().unwrap_or_else(|| Path::new(""));

    // Case 1: Numbered extension (e.g., .001, .002, .003 or .0001)
    if let Some(dot_pos) = file_name.rfind('.') {
        let ext = &file_name[dot_pos + 1..];
        if ext.len() >= 3 && ext.chars().all(|c| c.is_ascii_digit()) {
            let prefix = &file_name[..dot_pos];
            let width = ext.len();

            let check_0 = parent_dir.join(format!("{}.{:0width$}", prefix, 0, width = width));

            let start_idx = if check_0.exists() {
                0
            } else {
                1
            };

            let mut chain = Vec::new();
            for idx in start_idx.. {
                let p = parent_dir.join(format!("{}.{:0width$}", prefix, idx, width = width));
                if p.exists() {
                    chain.push(p);
                } else {
                    break;
                }
            }

            if !chain.is_empty() {
                return Ok(chain);
            }
        }
    }

    // Case 2: PKZIP spanned (.z01, .z02, ... or final .zip)
    if let Some(dot_pos) = file_name.rfind('.') {
        let ext = &file_name[dot_pos + 1..];
        let is_z_part = ext.starts_with('z')
            && ext.len() >= 3
            && ext[1..].chars().all(|c| c.is_ascii_digit());
        let is_zip_final = ext.eq_ignore_ascii_case("zip");

        if is_z_part || is_zip_final {
            let stem = &file_name[..dot_pos];
            let check_z01 = parent_dir.join(format!("{}.z01", stem));

            if check_z01.exists() {
                let mut chain = Vec::new();
                for idx in 1.. {
                    let zp = parent_dir.join(format!("{}.z{:02}", stem, idx));
                    if zp.exists() {
                        chain.push(zp);
                    } else {
                        break;
                    }
                }
                let final_zip = parent_dir.join(format!("{}.zip", stem));
                if final_zip.exists() {
                    chain.push(final_zip);
                }
                if !chain.is_empty() {
                    return Ok(chain);
                }
            }
        }
    }

    // Case 3: partN pattern (e.g. .part1.rar, .part01.rar, .part1.7z)
    if let Some(part_pos) = file_name.to_lowercase().find(".part") {
        let after_part = &file_name[part_pos + 5..];
        if let Some(dot_after) = after_part.find('.') {
            let num_str = &after_part[..dot_after];
            let suffix = &after_part[dot_after..];
            if !num_str.is_empty() && num_str.chars().all(|c| c.is_ascii_digit()) {
                let prefix = &file_name[..part_pos];
                let width = num_str.len();

                let mut chain = Vec::new();
                for idx in 1.. {
                    let p = parent_dir.join(format!(
                        "{}.part{:0width$}{}",
                        prefix,
                        idx,
                        suffix,
                        width = width
                    ));
                    if p.exists() {
                        chain.push(p);
                    } else {
                        break;
                    }
                }
                if !chain.is_empty() {
                    return Ok(chain);
                }
            }
        }
    }

    // Fallback: Single file volume
    Ok(vec![abs_seed])
}

/// A virtual continuous stream combining multiple physical volume files into a unified linear space.
pub struct VirtualMultiVolumeReader {
    segments: Vec<VolumeSegment>,
    total_size: u64,
    current_virtual_offset: u64,
    active_file: Option<(usize, File)>,
}

impl VirtualMultiVolumeReader {
    /// Opens the entire multi-volume chain automatically discovered from `seed_path`.
    pub fn open_from_any_volume(seed_path: impl AsRef<Path>) -> io::Result<Self> {
        let chain = detect_volume_chain(seed_path.as_ref())?;
        Self::from_volumes(chain)
    }

    /// Constructs a virtual reader from an ordered list of volume file paths.
    pub fn from_volumes(paths: Vec<PathBuf>) -> io::Result<Self> {
        if paths.is_empty() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Volume paths cannot be empty",
            ));
        }

        let mut segments = Vec::with_capacity(paths.len());
        let mut current_start = 0u64;

        for path in paths {
            let meta = fs::metadata(&path)?;
            let size = meta.len();
            let start = current_start;
            let end = current_start + size;
            segments.push(VolumeSegment {
                path,
                file_size: size,
                virtual_start_offset: start,
                virtual_end_offset: end,
            });
            current_start = end;
        }

        Ok(Self {
            segments,
            total_size: current_start,
            current_virtual_offset: 0,
            active_file: None,
        })
    }

    /// Total virtual size across all combined volumes in bytes.
    #[inline]
    pub fn total_size(&self) -> u64 {
        self.total_size
    }

    /// Current virtual read position.
    #[inline]
    pub fn current_offset(&self) -> u64 {
        self.current_virtual_offset
    }

    /// Segments metadata table.
    #[inline]
    pub fn segments(&self) -> &[VolumeSegment] {
        &self.segments
    }

    /// Volume paths in chain order.
    pub fn volume_paths(&self) -> Vec<PathBuf> {
        self.segments.iter().map(|s| s.path.clone()).collect()
    }
}

impl Read for VirtualMultiVolumeReader {
    fn read(&mut self, buf: &mut [u8]) -> io::Result<usize> {
        if buf.is_empty() || self.current_virtual_offset >= self.total_size {
            return Ok(0);
        }

        let mut total_read = 0;
        while total_read < buf.len() && self.current_virtual_offset < self.total_size {
            let seg_idx = self.segments.iter().position(|seg| {
                self.current_virtual_offset >= seg.virtual_start_offset
                    && self.current_virtual_offset < seg.virtual_end_offset
            });

            let segment_idx = match seg_idx {
                Some(idx) => idx,
                None => break,
            };

            let seg = &self.segments[segment_idx];
            let intra_offset = self.current_virtual_offset - seg.virtual_start_offset;
            let rem_in_seg = seg.file_size - intra_offset;
            let to_read = ((buf.len() - total_read) as u64).min(rem_in_seg) as usize;
            if to_read == 0 {
                break;
            }

            let need_open = match &self.active_file {
                Some((idx, _)) => *idx != segment_idx,
                None => true,
            };

            if need_open {
                let mut file = File::open(&seg.path)?;
                file.seek(SeekFrom::Start(intra_offset))?;
                self.active_file = Some((segment_idx, file));
            } else if let Some((_, ref mut file)) = self.active_file {
                let cur_pos = file.stream_position()?;
                if cur_pos != intra_offset {
                    file.seek(SeekFrom::Start(intra_offset))?;
                }
            }

            let (_, ref mut file) = self.active_file.as_mut().unwrap();
            let bytes_read = file.read(&mut buf[total_read..total_read + to_read])?;
            if bytes_read == 0 {
                break;
            }
            self.current_virtual_offset += bytes_read as u64;
            total_read += bytes_read;
        }

        Ok(total_read)
    }
}

impl Seek for VirtualMultiVolumeReader {
    fn seek(&mut self, pos: SeekFrom) -> io::Result<u64> {
        let new_offset = match pos {
            SeekFrom::Start(offset) => offset as i64,
            SeekFrom::Current(delta) => (self.current_virtual_offset as i64)
                .checked_add(delta)
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "Seek offset overflow"))?,
            SeekFrom::End(delta) => (self.total_size as i64)
                .checked_add(delta)
                .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "Seek offset overflow"))?,
        };

        if new_offset < 0 {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Cannot seek to a negative offset",
            ));
        }

        self.current_virtual_offset = new_offset as u64;
        Ok(self.current_virtual_offset)
    }
}
