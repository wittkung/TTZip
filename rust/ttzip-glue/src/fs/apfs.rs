// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! APFS optimizations, 16KB page-aligned allocations, and macOS CoW cloning.

use std::alloc::{alloc_zeroed, dealloc, Layout};
use std::ffi::CString;
use std::os::unix::io::RawFd;
use std::path::Path;
use std::ptr::NonNull;

/// Apple Silicon standard memory page size (16 KB).
pub const APPLE_SILICON_PAGE_SIZE: usize = 16384;

/// APFS `F_PREALLOCATE` command constants on macOS.
pub const F_PREALLOCATE: libc::c_int = 42;
pub const F_ALLOCATECONTIG: u32 = 0x00000002;
pub const F_ALLOCATEALL: u32 = 0x00000004;
pub const F_PEOFPOSMODE: i32 = 3;

/// `copyfile.h` clone flags.
pub const COPYFILE_DATA: u32 = 1 << 1;
pub const COPYFILE_CLONE: u32 = 1 << 24;

/// macOS kernel `fstore_t` structure for `F_PREALLOCATE` fcntl calls.
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct fstore_t {
    pub fst_flags: u32,
    pub fst_posmode: i32,
    pub fst_offset: i64,
    pub fst_length: i64,
    pub fst_bytesalloc: i64,
}

/// Aligns a byte size up to the next 16KB boundary.
#[inline]
pub fn align_up_16k(size: usize) -> usize {
    (size + APPLE_SILICON_PAGE_SIZE - 1) & !(APPLE_SILICON_PAGE_SIZE - 1)
}

/// Returns true if the pointer is aligned to a 16KB Apple Silicon page boundary.
#[inline]
pub fn is_16k_aligned(ptr: *const u8) -> bool {
    (ptr as usize) % APPLE_SILICON_PAGE_SIZE == 0
}

/// RAII memory buffer guaranteed to be 16KB page-aligned for Apple Silicon SIMD and DMA I/O.
pub struct AlignedBuffer {
    ptr: NonNull<u8>,
    capacity: usize,
    layout: Layout,
}

impl AlignedBuffer {
    /// Allocates a new 16KB page-aligned zero-initialized buffer.
    pub fn new(capacity: usize) -> Result<Self, crate::types::TTZipStatus> {
        let aligned_cap = align_up_16k(capacity.max(APPLE_SILICON_PAGE_SIZE));
        let layout = Layout::from_size_align(aligned_cap, APPLE_SILICON_PAGE_SIZE)
            .map_err(|_| crate::types::TTZipStatus::ErrOutOfMemory)?;

        let raw_ptr = unsafe { alloc_zeroed(layout) };
        let ptr = NonNull::new(raw_ptr).ok_or(crate::types::TTZipStatus::ErrOutOfMemory)?;

        Ok(Self {
            ptr,
            capacity: aligned_cap,
            layout,
        })
    }


    #[inline]
    pub fn as_ptr(&self) -> *const u8 {
        self.ptr.as_ptr()
    }

    #[inline]
    pub fn as_mut_ptr(&mut self) -> *mut u8 {
        self.ptr.as_ptr()
    }

    #[inline]
    pub fn capacity(&self) -> usize {
        self.capacity
    }

    #[inline]
    pub fn as_slice(&self) -> &[u8] {
        unsafe { std::slice::from_raw_parts(self.ptr.as_ptr(), self.capacity) }
    }

    #[inline]
    pub fn as_mut_slice(&mut self) -> &mut [u8] {
        unsafe { std::slice::from_raw_parts_mut(self.ptr.as_ptr(), self.capacity) }
    }
}

impl Drop for AlignedBuffer {
    fn drop(&mut self) {
        unsafe {
            dealloc(self.ptr.as_ptr(), self.layout);
        }
    }
}

unsafe impl Send for AlignedBuffer {}
unsafe impl Sync for AlignedBuffer {}

extern "C" {
    #[cfg(target_os = "macos")]
    fn clonefile(src: *const libc::c_char, dst: *const libc::c_char, flags: u32) -> libc::c_int;
    #[cfg(target_os = "macos")]
    fn fcopyfile(
        in_fd: libc::c_int,
        out_fd: libc::c_int,
        state: *mut libc::c_void,
        flags: u32,
    ) -> libc::c_int;
}

/// Preallocates contiguous physical extent space on APFS filesystems.
///
/// Reduces SSD write amplification and fragmentation during high-throughput uncompressed decompression.
pub fn apfs_preallocate(fd: RawFd, target_size: i64) -> std::io::Result<()> {
    if fd < 0 || target_size <= 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Invalid file descriptor or target size",
        ));
    }

    #[cfg(target_os = "macos")]
    {
        let mut fst = fstore_t {
            fst_flags: F_ALLOCATECONTIG | F_ALLOCATEALL,
            fst_posmode: F_PEOFPOSMODE,
            fst_offset: 0,
            fst_length: target_size,
            fst_bytesalloc: 0,
        };

        // Try 1: Attempt contiguous physical allocation
        if unsafe { libc::fcntl(fd, F_PREALLOCATE, &fst) } == 0 {
            return Ok(());
        }

        // Try 2: Fallback to non-contiguous all-at-once allocation on fragmented APFS disks
        fst.fst_flags = F_ALLOCATEALL;
        if unsafe { libc::fcntl(fd, F_PREALLOCATE, &fst) } == 0 {
            return Ok(());
        }
    }

    // Try 3: Standard POSIX ftruncate fallback
    let ret = unsafe { libc::ftruncate(fd, target_size) };
    if ret == 0 {
        Ok(())
    } else {
        Err(std::io::Error::last_os_error())
    }
}

/// Clones a file using APFS Copy-on-Write (CoW) zero-copy metadata clone.
pub fn apfs_clone_file(src: &Path, dst: &Path, overwrite: bool) -> std::io::Result<()> {
    let src_c = CString::new(src.to_str().ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::InvalidInput, "Invalid src path")
    })?)?;
    let dst_c = CString::new(dst.to_str().ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::InvalidInput, "Invalid dst path")
    })?)?;

    if overwrite && dst.exists() {
        let _ = std::fs::remove_file(dst);
    }

    #[cfg(target_os = "macos")]
    {
        let ret = unsafe { clonefile(src_c.as_ptr(), dst_c.as_ptr(), 0) };
        if ret == 0 {
            return Ok(());
        }
    }

    // Fallback: standard file copy if clonefile is unsupported
    std::fs::copy(src, dst)?;
    Ok(())
}

/// Clones file descriptor range using APFS `fcopyfile` zero-copy clone.
pub fn apfs_fcopyfile_clone(in_fd: RawFd, out_fd: RawFd) -> std::io::Result<()> {
    if in_fd < 0 || out_fd < 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "Invalid file descriptors",
        ));
    }

    #[cfg(target_os = "macos")]
    {
        let ret = unsafe { fcopyfile(in_fd, out_fd, std::ptr::null_mut(), COPYFILE_DATA | COPYFILE_CLONE) };
        if ret == 0 {
            return Ok(());
        }
    }

    Err(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        "APFS zero-copy clone not supported or failed",
    ))
}

/// Returns true if the path matches macOS junk metadata artifacts.
pub fn is_mac_junk_file(path: &str) -> bool {
    if path.is_empty() {
        return false;
    }

    if path.contains(".DS_Store")
        || path.contains("__MACOSX")
        || path.contains("Thumbs.db")
        || path.contains(".Spotlight-V100")
        || path.contains(".Trashes")
    {
        return true;
    }

    let filename = path.rsplit('/').next().unwrap_or(path);
    filename.starts_with("._")
}

/// Fast path removal helper.
pub fn ttzip_remove_path_fast(path: &Path) -> std::io::Result<()> {
    let c_path = CString::new(path.to_str().ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::InvalidInput, "Invalid path")
    })?)?;

    unsafe {
        let mut st: libc::stat = std::mem::zeroed();
        if libc::lstat(c_path.as_ptr(), &mut st) != 0 {
            return Err(std::io::Error::last_os_error());
        }

        if (st.st_mode & libc::S_IFMT) == libc::S_IFDIR {
            if libc::rmdir(c_path.as_ptr()) != 0 {
                return Err(std::io::Error::last_os_error());
            }
        } else if libc::unlink(c_path.as_ptr()) != 0 {
            return Err(std::io::Error::last_os_error());
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::os::unix::io::AsRawFd;

    #[test]
    fn test_16k_page_alignment() {
        assert_eq!(align_up_16k(0), 0);
        assert_eq!(align_up_16k(1), 16384);
        assert_eq!(align_up_16k(16384), 16384);
        assert_eq!(align_up_16k(16385), 32768);

        let buf = AlignedBuffer::new(5000).expect("aligned alloc");
        assert_eq!(buf.capacity(), 16384);
        assert!(is_16k_aligned(buf.as_ptr()));
    }

    #[test]
    fn test_mac_junk_detector() {
        assert!(is_mac_junk_file("__MACOSX/._test.txt"));
        assert!(is_mac_junk_file("sub/folder/.DS_Store"));
        assert!(is_mac_junk_file("folder/._hidden_attr"));
        assert!(is_mac_junk_file(".Spotlight-V100/catalog"));
        assert!(!is_mac_junk_file("valid_folder/document.pdf"));
        assert!(!is_mac_junk_file("photo.jpg"));
    }

    #[test]
    fn test_apfs_preallocate_temp_file() {
        let temp_path = std::env::temp_dir().join("ttzip_preallocate_test.bin");
        let file = File::create(&temp_path).expect("create temp file");
        let fd = file.as_raw_fd();

        let res = apfs_preallocate(fd, 65536);
        assert!(res.is_ok());

        drop(file);
        let _ = std::fs::remove_file(&temp_path);
    }
}
