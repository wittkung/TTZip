// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Multi-volume split container and virtual continuous reader module.

mod reader;
mod writer;

pub use reader::{detect_volume_chain, VirtualMultiVolumeReader, VolumeSegment};
pub use writer::{compute_volume_path, SplitVolumeWriter};

/// Naming convention for multi-volume archive segments.
#[repr(C)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum VolumeNamingScheme {
    /// Numbered extensions: archive.7z.001, archive.zip.001, archive.tar.001
    NumberedExtension = 0,
    /// PKZIP spanned standard: archive.z01, archive.z02, ... archive.zip
    PkzipSpanned = 1,
    /// Raw split: archive.001, archive.002
    RawSplit = 2,
}

impl From<i32> for VolumeNamingScheme {
    fn from(val: i32) -> Self {
        match val {
            1 => VolumeNamingScheme::PkzipSpanned,
            2 => VolumeNamingScheme::RawSplit,
            _ => VolumeNamingScheme::NumberedExtension,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::io::{Read, Seek, SeekFrom, Write};
    use tempfile::tempdir;

    #[test]
    fn test_split_writer_boundary_rollover_and_precise_counts() {
        let dir = tempdir().unwrap();
        let base_path = dir.path().join("archive.7z");
        let volume_size = 1000; // 1000 bytes per volume

        let mut writer = SplitVolumeWriter::new(
            &base_path,
            volume_size,
            VolumeNamingScheme::NumberedExtension,
        )
        .unwrap();

        // 2500 bytes payload -> 3 volumes: 1000, 1000, 500
        let payload = vec![0xABu8; 2500];
        writer.write_all(&payload).unwrap();
        let volumes = writer.close().unwrap();

        assert_eq!(volumes.len(), 3);
        assert_eq!(writer.total_bytes(), 2500);

        assert_eq!(fs::metadata(&volumes[0]).unwrap().len(), 1000);
        assert_eq!(fs::metadata(&volumes[1]).unwrap().len(), 1000);
        assert_eq!(fs::metadata(&volumes[2]).unwrap().len(), 500);
    }

    #[test]
    fn test_split_writer_pkzip_spanned_naming() {
        let dir = tempdir().unwrap();
        let base_path = dir.path().join("archive.zip");
        let volume_size = 1000;

        let mut writer =
            SplitVolumeWriter::new(&base_path, volume_size, VolumeNamingScheme::PkzipSpanned)
                .unwrap();

        let payload = vec![0x33u8; 2400]; // 1000 (.z01), 1000 (.z02), 400 (.zip)
        writer.write_all(&payload).unwrap();
        let volumes = writer.close().unwrap();

        assert_eq!(volumes.len(), 3);
        assert!(volumes[0].to_string_lossy().ends_with(".z01"));
        assert!(volumes[1].to_string_lossy().ends_with(".z02"));
        assert!(volumes[2].to_string_lossy().ends_with(".zip"));

        assert_eq!(fs::metadata(&volumes[0]).unwrap().len(), 1000);
        assert_eq!(fs::metadata(&volumes[1]).unwrap().len(), 1000);
        assert_eq!(fs::metadata(&volumes[2]).unwrap().len(), 400);
    }

    #[test]
    fn test_virtual_multi_volume_reader_topology_detection_and_seeking() {
        let dir = tempdir().unwrap();
        let base_path = dir.path().join("data.tar");
        let volume_size = 512;

        let mut writer =
            SplitVolumeWriter::new(&base_path, volume_size, VolumeNamingScheme::NumberedExtension)
                .unwrap();

        let mut sample_data = Vec::with_capacity(1500);
        for i in 0..1500 {
            sample_data.push((i % 251) as u8);
        }
        writer.write_all(&sample_data).unwrap();
        let volumes = writer.close().unwrap();
        assert_eq!(volumes.len(), 3); // 512, 512, 476

        // Test opening from the middle volume (.002)
        let middle_vol = &volumes[1];
        let mut reader = VirtualMultiVolumeReader::open_from_any_volume(middle_vol).unwrap();

        assert_eq!(reader.total_size(), 1500);
        assert_eq!(reader.volume_paths().len(), 3);

        // Read all sequentially
        let mut read_buf = Vec::new();
        reader.read_to_end(&mut read_buf).unwrap();
        assert_eq!(read_buf, sample_data);

        // Test seeking across volume boundaries
        reader.seek(SeekFrom::Start(600)).unwrap(); // in volume 2
        let mut small_buf = [0u8; 100];
        reader.read_exact(&mut small_buf).unwrap();
        assert_eq!(&small_buf[..], &sample_data[600..700]);

        // Seek to volume 3
        reader.seek(SeekFrom::Start(1100)).unwrap();
        let mut end_buf = [0u8; 400];
        reader.read_exact(&mut end_buf).unwrap();
        assert_eq!(&end_buf[..], &sample_data[1100..1500]);
    }
}
