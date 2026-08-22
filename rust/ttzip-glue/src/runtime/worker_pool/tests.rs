// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

#[cfg(test)]
mod tests {
    use crate::runtime::worker_pool::pool::{EventDrivenWorkerPool, WorkerPoolState};
    use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
    use std::sync::Arc;
    use std::thread;
    use std::time::Duration;

    #[test]
    fn test_worker_pool_basic_execution_and_drain() {
        let pool = EventDrivenWorkerPool::new(4);
        let counter = Arc::new(AtomicUsize::new(0));

        for _ in 0..100 {
            let c = Arc::clone(&counter);
            pool.submit(move || {
                c.fetch_add(1, Ordering::SeqCst);
            });
        }

        pool.drain();
        assert_eq!(counter.load(Ordering::SeqCst), 100);
        assert_eq!(pool.completed_tasks(), 100);
        assert_eq!(pool.failed_tasks(), 0);
        assert_eq!(pool.pending_tasks(), 0);
        assert_eq!(pool.active_workers(), 0);
    }

    #[test]
    fn test_worker_pool_batch_submission() {
        let pool = EventDrivenWorkerPool::new(2);
        let counter = Arc::new(AtomicUsize::new(0));

        let mut jobs = Vec::new();
        for _ in 0..50 {
            let c = Arc::clone(&counter);
            jobs.push(move || {
                c.fetch_add(1, Ordering::SeqCst);
            });
        }

        assert!(pool.submit_batch(jobs));
        pool.drain();
        assert_eq!(counter.load(Ordering::SeqCst), 50);
        assert_eq!(pool.completed_tasks(), 50);
    }

    #[test]
    fn test_worker_pool_pause_resume() {
        let pool = EventDrivenWorkerPool::new(2);
        pool.pause();
        assert_eq!(pool.state(), WorkerPoolState::Paused);

        let executed = Arc::new(AtomicBool::new(false));
        let exec_clone = Arc::clone(&executed);
        pool.submit(move || {
            exec_clone.store(true, Ordering::SeqCst);
        });

        thread::sleep(Duration::from_millis(15));
        assert!(!executed.load(Ordering::SeqCst));
        assert_eq!(pool.pending_tasks(), 1);

        pool.resume();
        assert_eq!(pool.state(), WorkerPoolState::Running);
        pool.drain();
        assert!(executed.load(Ordering::SeqCst));
        assert_eq!(pool.completed_tasks(), 1);
    }

    #[test]
    fn test_worker_pool_dynamic_scaling() {
        let pool = EventDrivenWorkerPool::new(2);
        assert_eq!(pool.worker_count(), 2);

        pool.set_worker_count(8);
        assert_eq!(pool.worker_count(), 8);

        let counter = Arc::new(AtomicUsize::new(0));
        for _ in 0..40 {
            let c = Arc::clone(&counter);
            pool.submit(move || {
                thread::sleep(Duration::from_millis(2));
                c.fetch_add(1, Ordering::SeqCst);
            });
        }
        pool.drain();
        assert_eq!(counter.load(Ordering::SeqCst), 40);

        pool.set_worker_count(1);
        assert_eq!(pool.worker_count(), 1);
    }

    #[test]
    fn test_worker_pool_panic_resilience() {
        let pool = EventDrivenWorkerPool::new(2);
        let counter = Arc::new(AtomicUsize::new(0));

        let executed = Arc::new(AtomicBool::new(false));
        let exec_clone = Arc::clone(&executed);
        pool.submit(move || {
            exec_clone.store(true, Ordering::SeqCst);
        });

        let c = Arc::clone(&counter);
        pool.submit(move || {
            c.fetch_add(1, Ordering::SeqCst);
        });

        pool.drain();
        assert!(executed.load(Ordering::SeqCst));
        assert_eq!(counter.load(Ordering::SeqCst), 1);
        assert_eq!(pool.completed_tasks(), 2);
    }

    #[test]
    fn test_worker_pool_rayon_interop() {
        let pool = EventDrivenWorkerPool::new(2);
        let flag = Arc::new(AtomicBool::new(false));
        let flag_clone = Arc::clone(&flag);

        pool.execute_rayon(move || {
            flag_clone.store(true, Ordering::SeqCst);
        });

        for _ in 0..100 {
            if flag.load(Ordering::SeqCst) {
                break;
            }
            thread::sleep(Duration::from_millis(1));
        }
        assert!(flag.load(Ordering::SeqCst));
    }
}
