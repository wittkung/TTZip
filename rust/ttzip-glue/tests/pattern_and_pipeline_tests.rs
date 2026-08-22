// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Pattern and Pipeline Integration Tests (Feature 186 - Task T001).
//!
//! Validates:
//! - Rayon producer-consumer streaming pipeline with lock-free SPSC / MPMC ring buffers.
//! - Event-driven work-stealing task dispatcher lifecycle, dynamic scaling, and panic isolation.
//! - In-Place transactional archive editing, commit verification, and rollback cleanup.
//! - Password Vault NIST SP 800-38D AES-256-GCM, zeroize compiler fences, and tamper defense.
//! - Hierarchical VFS tree aggregation, ASCII/Unicode rendering, and fuzzy search scoring.

use std::ffi::{CStr, CString};
use std::fs;
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;
use tempfile::tempdir;

use ttzip_glue::archive::in_place_edit::{detect_archive_format, InPlaceArchiveSession};
use ttzip_glue::crypto::vault::{
    aes256_gcm_decrypt, aes256_gcm_encrypt, secure_wipe, secure_wipe_slice,
};
use ttzip_glue::ffi::*;
use ttzip_glue::fs::vfs::{fuzzy_match, VfsEntry, VfsTree};
use ttzip_glue::runtime::ring_buffer::{MpmcRingBuffer, SpscRingBuffer};
use ttzip_glue::runtime::worker_pool::{EventDrivenWorkerPool, WorkerPoolState};
use ttzip_glue::sevenz::{create_7z_solid_archive_bytes, SevenZArchive};
use ttzip_glue::types::{
    TTZipArchiveFormat, TTZipEncryptionMethod, TTZipEntryMetadata, TTZipStatus,
};
use ttzip_glue::zip::{
    assemble_zip_archive, compress_items_parallel, ZipArchive, ZipInputItem,
};

#[test]
fn test_rayon_producer_consumer_streaming_pipeline() {
    // 1. Single-Producer Single-Consumer (SPSC) lock-free streaming pipeline
    let spsc = SpscRingBuffer::<u64>::new(1024);
    let (producer, consumer) = spsc.split();
    let num_items = 10000u64;

    let prod_handle = thread::spawn(move || {
        for i in 0..num_items {
            let mut val = i;
            while let Err(returned) = producer.push(val) {
                val = returned;
                thread::yield_now();
            }
        }
    });

    let cons_handle = thread::spawn(move || {
        let mut received = Vec::with_capacity(num_items as usize);
        while received.len() < num_items as usize {
            if let Some(val) = consumer.pop() {
                received.push(val);
            } else {
                thread::yield_now();
            }
        }
        received
    });

    prod_handle.join().unwrap();
    let received = cons_handle.join().unwrap();
    assert_eq!(received.len(), num_items as usize);
    for (i, &val) in received.iter().enumerate() {
        assert_eq!(val, i as u64);
    }

    // 2. Multi-Producer Multi-Consumer (MPMC) lock-free pipeline with Rayon
    let mpmc = Arc::new(MpmcRingBuffer::<u64>::new(512));
    let total_producers = 4;
    let items_per_producer = 2500u64;
    let expected_total_items = (total_producers as u64) * items_per_producer;

    let sum_produced = Arc::new(AtomicU64::new(0));
    let sum_consumed = Arc::new(AtomicU64::new(0));
    let count_consumed = Arc::new(AtomicUsize::new(0));
    let done_producing = Arc::new(AtomicBool::new(false));

    // Spawn producer threads
    let mut prod_threads = Vec::new();
    for p_id in 0..total_producers {
        let q = Arc::clone(&mpmc);
        let sum_p = Arc::clone(&sum_produced);
        prod_threads.push(thread::spawn(move || {
            let base = (p_id as u64) * items_per_producer;
            for i in 0..items_per_producer {
                let val = base + i + 1;
                while q.push(val).is_err() {
                    thread::yield_now();
                }
                sum_p.fetch_add(val, Ordering::Relaxed);
            }
        }));
    }

    // Spawn consumer threads
    let mut cons_threads = Vec::new();
    for _ in 0..4 {
        let q = Arc::clone(&mpmc);
        let sum_c = Arc::clone(&sum_consumed);
        let count_c = Arc::clone(&count_consumed);
        let done_p = Arc::clone(&done_producing);
        cons_threads.push(thread::spawn(move || {
            while !done_p.load(Ordering::Acquire) || !q.is_empty() {
                if let Some(val) = q.pop() {
                    sum_c.fetch_add(val, Ordering::Relaxed);
                    count_c.fetch_add(1, Ordering::Relaxed);
                } else {
                    thread::yield_now();
                }
            }
        }));
    }

    for t in prod_threads {
        t.join().unwrap();
    }
    done_producing.store(true, Ordering::Release);

    for t in cons_threads {
        t.join().unwrap();
    }

    assert_eq!(count_consumed.load(Ordering::SeqCst), expected_total_items as usize);
    assert_eq!(
        sum_produced.load(Ordering::SeqCst),
        sum_consumed.load(Ordering::SeqCst)
    );
}

#[test]
fn test_event_driven_work_stealing_task_dispatcher() {
    let pool = EventDrivenWorkerPool::new(4);
    assert_eq!(pool.worker_count(), 4);
    assert_eq!(pool.state(), WorkerPoolState::Idle);

    // 1. Submit single task and verify execution
    let counter = Arc::new(AtomicUsize::new(0));
    let c_clone = Arc::clone(&counter);
    assert!(pool.submit(move || {
        c_clone.fetch_add(10, Ordering::SeqCst);
    }));
    pool.drain();
    assert_eq!(counter.load(Ordering::SeqCst), 10);
    assert_eq!(pool.completed_tasks(), 1);

    // 2. Submit batch tasks
    let batch_counter = Arc::new(AtomicUsize::new(0));
    let jobs: Vec<_> = (0..20)
        .map(|_| {
            let bc = Arc::clone(&batch_counter);
            move || {
                bc.fetch_add(1, Ordering::SeqCst);
            }
        })
        .collect();

    assert!(pool.submit_batch(jobs));
    pool.drain();
    assert_eq!(batch_counter.load(Ordering::SeqCst), 20);
    assert_eq!(pool.completed_tasks(), 21);

    // 3. Dynamic scaling: scale up to 8, scale down to 2
    pool.set_worker_count(8);
    assert_eq!(pool.worker_count(), 8);

    let scale_counter = Arc::new(AtomicUsize::new(0));
    for _ in 0..16 {
        let sc = Arc::clone(&scale_counter);
        pool.submit(move || {
            sc.fetch_add(1, Ordering::SeqCst);
        });
    }
    pool.drain();
    assert_eq!(scale_counter.load(Ordering::SeqCst), 16);

    pool.set_worker_count(2);
    assert_eq!(pool.worker_count(), 2);

    // 4. Pause and Resume lifecycle
    pool.pause();
    assert_eq!(pool.state(), WorkerPoolState::Paused);
    let paused_flag = Arc::new(AtomicBool::new(false));
    let pf = Arc::clone(&paused_flag);
    pool.submit(move || {
        pf.store(true, Ordering::SeqCst);
    });

    thread::sleep(std::time::Duration::from_millis(20));
    assert!(!paused_flag.load(Ordering::SeqCst));

    pool.resume();
    pool.drain();
    assert!(paused_flag.load(Ordering::SeqCst));

    // 5. Panic isolation: failing tasks increment failed_tasks without crashing pool
    let initial_failed = pool.failed_tasks();
    pool.submit(|| {
        panic!("Intentional test panic to verify worker pool isolation");
    });
    pool.drain();
    assert_eq!(pool.failed_tasks(), initial_failed + 1);

    // Ensure pool remains fully operational after panic
    let post_panic_check = Arc::new(AtomicBool::new(false));
    let ppc = Arc::clone(&post_panic_check);
    pool.submit(move || {
        ppc.store(true, Ordering::SeqCst);
    });
    pool.drain();
    assert!(post_panic_check.load(Ordering::SeqCst));

    // 6. Rayon task execution interop
    let rayon_executed = Arc::new(AtomicBool::new(false));
    let re = Arc::clone(&rayon_executed);
    pool.execute_rayon(move || {
        re.store(true, Ordering::SeqCst);
    });
    thread::sleep(std::time::Duration::from_millis(50));
    assert!(rayon_executed.load(Ordering::SeqCst));

    pool.shutdown();
    assert_eq!(pool.state(), WorkerPoolState::Shutdown);
}

#[test]
fn test_in_place_editing_transaction_rollback_and_commit() {
    let dir = tempdir().unwrap();
    let zip_path = dir.path().join("archive.zip");
    let sevenz_path = dir.path().join("archive.7z");

    // Prepare initial files for ZIP
    let f1 = dir.path().join("file1.txt");
    let f2 = dir.path().join("file2.txt");
    let f3 = dir.path().join("file3.txt");
    fs::write(&f1, b"Original Content 1").unwrap();
    fs::write(&f2, b"Original Content 2").unwrap();
    fs::write(&f3, b"Original Content 3").unwrap();

    let initial_items = vec![
        ZipInputItem { rel_path: "file1.txt".to_string(), data: b"Original Content 1".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ZipInputItem { rel_path: "file2.txt".to_string(), data: b"Original Content 2".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
        ZipInputItem { rel_path: "file3.txt".to_string(), data: b"Original Content 3".to_vec(), mtime_epoch_secs: 1700000000, mode: 0o644, is_directory: false },
    ];
    let compressed = compress_items_parallel(initial_items.clone(), 6, TTZipEncryptionMethod::None, None, 2).unwrap();
    let zip_bytes = assemble_zip_archive(&compressed).unwrap();
    fs::write(&zip_path, &zip_bytes).unwrap();

    assert_eq!(detect_archive_format(&zip_path), TTZipArchiveFormat::Zip);

    // 1. Test ZIP Transaction Rollback
    let f_replace = dir.path().join("rep.txt");
    fs::write(&f_replace, b"Mutated Content").unwrap();

    let mut session = InPlaceArchiveSession::begin(&zip_path, Some(TTZipArchiveFormat::Zip)).unwrap();
    session.replace("file2.txt", &f_replace).unwrap();
    session.delete("file1.txt").unwrap();
    session.rollback().unwrap();

    // Verify original archive unchanged after rollback
    let zip_data = fs::read(&zip_path).unwrap();
    let zip = ZipArchive::open_slice(&zip_data).unwrap();
    assert_eq!(zip.len(), 3);
    assert_eq!(zip.extract_entry_bytes(1, None).unwrap(), b"Original Content 2");

    // 2. Test ZIP Transaction Commit
    let mut session = InPlaceArchiveSession::begin(&zip_path, Some(TTZipArchiveFormat::Zip)).unwrap();
    let f_append = dir.path().join("app.txt");
    fs::write(&f_append, b"Appended Content 4").unwrap();

    session.replace("file2.txt", &f_replace).unwrap();
    session.delete("file1.txt").unwrap();
    session.append("file4.txt", &f_append).unwrap();
    session.commit().unwrap();

    // Verify mutated archive after commit
    let zip_data_mut = fs::read(&zip_path).unwrap();
    let zip_mut = ZipArchive::open_slice(&zip_data_mut).unwrap();
    let paths: Vec<String> = zip_mut.entries().iter().map(|e| e.rel_path.clone()).collect();
    assert!(!paths.contains(&"file1.txt".to_string()));
    assert!(paths.contains(&"file2.txt".to_string()));
    assert!(paths.contains(&"file3.txt".to_string()));
    assert!(paths.contains(&"file4.txt".to_string()));

    let idx2 = zip_mut.entries().iter().position(|e| e.rel_path == "file2.txt").unwrap();
    assert_eq!(zip_mut.extract_entry_bytes(idx2, None).unwrap(), b"Mutated Content");

    let idx3 = zip_mut.entries().iter().position(|e| e.rel_path == "file3.txt").unwrap();
    assert_eq!(zip_mut.extract_entry_bytes(idx3, None).unwrap(), b"Original Content 3");

    // 3. Test 7z In-Place Rollback and Commit
    let sevenz_bytes = create_7z_solid_archive_bytes(&initial_items, 6, 2).unwrap();
    fs::write(&sevenz_path, &sevenz_bytes).unwrap();
    assert_eq!(detect_archive_format(&sevenz_path), TTZipArchiveFormat::SevenZip);

    let mut session_7z = InPlaceArchiveSession::begin(&sevenz_path, Some(TTZipArchiveFormat::SevenZip)).unwrap();
    session_7z.delete("file1.txt").unwrap();
    session_7z.replace("file2.txt", &f_replace).unwrap();
    session_7z.rollback().unwrap();

    let sz_data = fs::read(&sevenz_path).unwrap();
    let sz = SevenZArchive::open_slice(&sz_data).unwrap();
    assert_eq!(sz.len(), 3);

    // Commit 7z
    let mut session_7z = InPlaceArchiveSession::begin(&sevenz_path, Some(TTZipArchiveFormat::SevenZip)).unwrap();
    session_7z.delete("file1.txt").unwrap();
    session_7z.replace("file2.txt", &f_replace).unwrap();
    session_7z.commit().unwrap();

    let sz_mut_data = fs::read(&sevenz_path).unwrap();
    let sz_mut = SevenZArchive::open_slice(&sz_mut_data).unwrap();
    assert_eq!(sz_mut.len(), 2);

    // 4. Test FFI In-Place Session C-ABI
    let c_zip_path = CString::new(zip_path.to_str().unwrap()).unwrap();
    let mut ffi_session: *mut TTZipInPlaceSession = std::ptr::null_mut();
    unsafe {
        let st = ttzip_rust_inplace_session_begin(c_zip_path.as_ptr(), 1, &mut ffi_session);
        assert_eq!(st, TTZipStatus::Ok);
        assert!(!ffi_session.is_null());

        let c_app_name = CString::new("ffi_appended.txt").unwrap();
        let c_app_file = CString::new(f_append.to_str().unwrap()).unwrap();
        assert_eq!(
            ttzip_rust_inplace_session_append(ffi_session, c_app_name.as_ptr(), c_app_file.as_ptr()),
            TTZipStatus::Ok
        );

        assert_eq!(ttzip_rust_inplace_session_commit(ffi_session), TTZipStatus::Ok);
        ttzip_rust_inplace_session_free(ffi_session);
    }
}

#[test]
fn test_password_vault_zeroize_memory_barrier() {
    // 1. NIST SP 800-38D Authenticated Encryption & Decryption
    let key = [0x77u8; 32];
    let iv = [0x88u8; 12];
    let plaintext = b"VaultCredentialsSecretKeyPayload2026";
    let aad = b"VaultMasterHeaderAuthData";

    let mut cipher = vec![0u8; plaintext.len()];
    let mut tag = [0u8; 16];
    aes256_gcm_encrypt(&key, &iv, plaintext, aad, &mut cipher, &mut tag).unwrap();
    assert_ne!(&cipher[..], plaintext);

    let mut decrypted = vec![0u8; cipher.len()];
    aes256_gcm_decrypt(&key, &iv, &cipher, aad, &tag, &mut decrypted).unwrap();
    assert_eq!(&decrypted[..], plaintext);

    // 2. Tampering resistance and memory sanitization
    let mut tampered_tag = tag;
    tampered_tag[0] ^= 0x01; // Tamper 1 bit in tag
    let mut sanitized_out = vec![0xAAu8; cipher.len()];
    let err = aes256_gcm_decrypt(&key, &iv, &cipher, aad, &tampered_tag, &mut sanitized_out);
    assert_eq!(err, Err(TTZipStatus::ErrInvalidPassword));
    assert!(sanitized_out.iter().all(|&b| b == 0)); // Memory barrier wiped

    // Tamper AAD
    let tampered_aad = b"VaultMasterHeaderAuthData_TAMPERED";
    let mut sanitized_out2 = vec![0xBBu8; cipher.len()];
    let err_aad = aes256_gcm_decrypt(&key, &iv, &cipher, tampered_aad, &tag, &mut sanitized_out2);
    assert_eq!(err_aad, Err(TTZipStatus::ErrInvalidPassword));
    assert!(sanitized_out2.iter().all(|&b| b == 0));

    // 3. Dead-Store Elimination immune memory sanitization
    let mut sensitive_buf = [0xFFu8; 128];
    secure_wipe_slice(&mut sensitive_buf);
    assert_eq!(sensitive_buf, [0u8; 128]);

    let mut sensitive_raw = [0x55u8; 64];
    secure_wipe(sensitive_raw.as_mut_ptr(), sensitive_raw.len());
    assert_eq!(sensitive_raw, [0u8; 64]);

    // 4. FFI C-ABI Vault Functions
    let mut ffi_cipher = vec![0u8; plaintext.len()];
    let mut ffi_tag = [0u8; 16];
    unsafe {
        let st_enc = ttzip_rust_vault_encrypt_key(
            key.as_ptr(),
            iv.as_ptr(),
            plaintext.as_ptr(),
            plaintext.len(),
            aad.as_ptr(),
            aad.len(),
            ffi_cipher.as_mut_ptr(),
            ffi_tag.as_mut_ptr(),
        );
        assert_eq!(st_enc, TTZipStatus::Ok);

        let mut ffi_dec = vec![0u8; ffi_cipher.len()];
        let st_dec = ttzip_rust_vault_decrypt_key(
            key.as_ptr(),
            iv.as_ptr(),
            ffi_cipher.as_ptr(),
            ffi_cipher.len(),
            aad.as_ptr(),
            aad.len(),
            ffi_tag.as_ptr(),
            ffi_dec.as_mut_ptr(),
        );
        assert_eq!(st_dec, TTZipStatus::Ok);
        assert_eq!(&ffi_dec[..], plaintext);

        ttzip_rust_vault_wipe(ffi_dec.as_mut_ptr(), ffi_dec.len());
        assert!(ffi_dec.iter().all(|&b| b == 0));
    }
}

#[test]
fn test_vfs_tree_rendering_and_fuzzy_search() {
    let entries = vec![
        VfsEntry {
            path: "TTZipCore/src/archive/writer.rs".to_string(),
            uncompressed_size: 12500,
            compressed_size: 4200,
            crc32: 0x11223344,
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
            is_encrypted: false,
        },
        VfsEntry {
            path: "TTZipCore/src/archive/reader.rs".to_string(),
            uncompressed_size: 15200,
            compressed_size: 5100,
            crc32: 0x55667788,
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
            is_encrypted: false,
        },
        VfsEntry {
            path: "TTZipCore/docs/ArchitectureGuide.md".to_string(),
            uncompressed_size: 8900,
            compressed_size: 3100,
            crc32: 0x99AABBCC,
            mtime_epoch_secs: 1700000000,
            mode: 0o644,
            is_directory: false,
            is_encrypted: false,
        },
    ];

    // 1. Hierarchy Tree Construction & Aggregations
    let tree = VfsTree::build_from_entries(&entries, "TTZipCore");
    assert_eq!(tree.root.total_files(), 3);
    assert_eq!(tree.root.total_directories(), 4); // TTZipCore, src, archive, docs
    assert_eq!(tree.root.uncompressed_size, 12500 + 15200 + 8900);
    assert_eq!(tree.root.compressed_size, 4200 + 5100 + 3100);

    // 2. ASCII/Unicode Layout Rendering
    let rendered = tree.render_tree();
    assert!(rendered.contains("TTZipCore (<DIR>)"));
    assert!(rendered.contains("writer.rs"));
    assert!(rendered.contains("reader.rs"));
    assert!(rendered.contains("ArchitectureGuide.md"));

    // 3. Fuzzy String Matching Algorithm Bonuses
    let match_exact = fuzzy_match("writer.rs", "writer.rs").unwrap();
    let match_prefix = fuzzy_match("writer.rs", "writ").unwrap();
    let match_sub = fuzzy_match("ArchitectureGuide.md", "arch").unwrap();
    assert!(match_exact.0 > match_prefix.0);
    assert!(match_sub.0 > 0);

    // Word boundary bonus & CamelCase bonus verification
    let boundary_match = fuzzy_match("ArchitectureGuide.md", "guide").unwrap();
    assert!(boundary_match.0 > 50);

    // Tree search ranking
    let results = tree.fuzzy_search("writer");
    assert!(!results.is_empty());
    assert_eq!(results[0].name, "writer.rs");

    let doc_results = tree.fuzzy_search("guide");
    assert!(!doc_results.is_empty());
    assert_eq!(doc_results[0].name, "ArchitectureGuide.md");

    // 4. FFI C-ABI VFS Tree and Search
    let mut raw_entries = Vec::new();
    let c_p1 = CString::new("TTZipCore/src/archive/writer.rs").unwrap();
    let c_p2 = CString::new("TTZipCore/docs/ArchitectureGuide.md").unwrap();

    raw_entries.push(TTZipEntryMetadata {
        path: c_p1.as_ptr(),
        uncompressed_size: 12500,
        compressed_size: 4200,
        crc32: 0x11223344,
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
        is_encrypted: false,
        compression_method: 8,
    });
    raw_entries.push(TTZipEntryMetadata {
        path: c_p2.as_ptr(),
        uncompressed_size: 8900,
        compressed_size: 3100,
        crc32: 0x99AABBCC,
        mtime_epoch_secs: 1700000000,
        mode: 0o644,
        is_directory: false,
        is_encrypted: false,
        compression_method: 8,
    });

    let c_root = CString::new("TTZipCore").unwrap();
    unsafe {
        let handle = ttzip_rust_vfs_tree_build(raw_entries.as_ptr(), raw_entries.len(), c_root.as_ptr());
        assert!(!handle.is_null());

        let mut total_files = 0u64;
        let mut total_dirs = 0u64;
        let mut total_size = 0u64;
        ttzip_rust_vfs_tree_get_stats(handle, &mut total_files, &mut total_dirs, &mut total_size);
        assert_eq!(total_files, 2);
        assert_eq!(total_size, 21400);

        let mut rendered_ptr: *mut libc::c_char = std::ptr::null_mut();
        let st_rend = ttzip_rust_vfs_tree_render(handle, &mut rendered_ptr);
        assert_eq!(st_rend, TTZipStatus::Ok);
        assert!(!rendered_ptr.is_null());
        let rend_str = CStr::from_ptr(rendered_ptr).to_str().unwrap();
        assert!(rend_str.contains("writer.rs"));
        ttzip_rust_vfs_free_string(rendered_ptr);

        let search_query = CString::new("arch").unwrap();
        let mut found_count = 0usize;
        unsafe extern "C" fn search_cb(
            result: *const TTZipVfsSearchResultRaw,
            user_data: *mut libc::c_void,
        ) -> bool {
            if !result.is_null() {
                let cnt = &mut *(user_data as *mut usize);
                *cnt += 1;
            }
            true
        }

        let st_search = ttzip_rust_vfs_fuzzy_search(
            handle,
            search_query.as_ptr(),
            Some(search_cb),
            &mut found_count as *mut usize as *mut libc::c_void,
        );
        assert_eq!(st_search, TTZipStatus::Ok);
        assert!(found_count >= 1);

        ttzip_rust_vfs_tree_free(handle);
    }
}
