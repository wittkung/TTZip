// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! High-performance event-driven worker pool with zero-polling kernel synchronization.
//!
//! Features:
//! - Direct kernel-level suspension via `parking_lot::Condvar` (macOS `__ulock_wait`).
//! - 0.0% CPU consumption during idle states.
//! - Microsecond-level dispatch latency upon task submission.
//! - Dynamic worker scaling, graceful drain, pause/resume, and Rayon interop.

use parking_lot::{Condvar, Mutex};
use std::collections::VecDeque;
use std::sync::Arc;
use std::thread;

/// Type alias for heap-allocated unit of work.
pub type WorkerJob = Box<dyn FnOnce() + Send + 'static>;

/// Represents current lifecycle state of the worker pool.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(C)]
pub enum WorkerPoolState {
    Idle = 0,
    Running = 1,
    Paused = 2,
    Draining = 3,
    Shutdown = 4,
}

struct PoolStateInner {
    state: WorkerPoolState,
    target_workers: usize,
    live_threads: usize,
    active_workers: usize,
    completed_tasks: u64,
    failed_tasks: u64,
    queue: VecDeque<WorkerJob>,
}

struct WorkerPoolInner {
    state: Mutex<PoolStateInner>,
    work_condvar: Condvar,
    drain_condvar: Condvar,
}

fn worker_loop(inner: Arc<WorkerPoolInner>) {
    loop {
        let mut state = inner.state.lock();
        loop {
            if state.state == WorkerPoolState::Shutdown {
                state.live_threads -= 1;
                return;
            }

            // Check if thread pool is scaled down
            if state.live_threads > state.target_workers && state.queue.is_empty() {
                state.live_threads -= 1;
                return;
            }

            if state.state == WorkerPoolState::Running || state.state == WorkerPoolState::Draining {
                if let Some(job) = state.queue.pop_front() {
                    state.active_workers += 1;
                    drop(state);

                    let res = std::panic::catch_unwind(std::panic::AssertUnwindSafe(job));

                    let mut state = inner.state.lock();
                    state.active_workers -= 1;
                    if res.is_ok() {
                        state.completed_tasks += 1;
                    } else {
                        state.failed_tasks += 1;
                    }

                    if state.state == WorkerPoolState::Draining
                        && state.queue.is_empty()
                        && state.active_workers == 0
                    {
                        state.state = WorkerPoolState::Idle;
                        inner.drain_condvar.notify_all();
                    }
                    break;
                } else if state.state == WorkerPoolState::Draining && state.active_workers == 0 {
                    state.state = WorkerPoolState::Idle;
                    inner.drain_condvar.notify_all();
                }
            }

            // Suspend thread in kernel space until notified (0.0% CPU)
            inner.work_condvar.wait(&mut state);
        }
    }
}

/// Zero-polling event-driven worker pool.
pub struct EventDrivenWorkerPool {
    inner: Arc<WorkerPoolInner>,
}

unsafe impl Send for EventDrivenWorkerPool {}
unsafe impl Sync for EventDrivenWorkerPool {}

impl EventDrivenWorkerPool {
    /// Creates a new event driven worker pool with the specified concurrency budget.
    pub fn new(worker_count: usize) -> Self {
        let count = worker_count.max(1);
        let inner = Arc::new(WorkerPoolInner {
            state: Mutex::new(PoolStateInner {
                state: WorkerPoolState::Idle,
                target_workers: count,
                live_threads: 0,
                active_workers: 0,
                completed_tasks: 0,
                failed_tasks: 0,
                queue: VecDeque::new(),
            }),
            work_condvar: Condvar::new(),
            drain_condvar: Condvar::new(),
        });

        {
            let mut state = inner.state.lock();
            state.live_threads = count;
            for _ in 0..count {
                let inner_clone = Arc::clone(&inner);
                thread::Builder::new()
                    .name("ttzip-worker-thread".to_string())
                    .spawn(move || worker_loop(inner_clone))
                    .expect("Failed to spawn TTZip worker thread");
            }
        }
        Self { inner }
    }

    /// Submits a task to the pool. Wakes up a waiting worker thread in microsecond latency.
    pub fn submit<F>(&self, job: F) -> bool
    where
        F: FnOnce() + Send + 'static,
    {
        let mut state = self.inner.state.lock();
        if state.state == WorkerPoolState::Shutdown {
            return false;
        }
        if state.state == WorkerPoolState::Idle {
            state.state = WorkerPoolState::Running;
        }
        state.queue.push_back(Box::new(job));
        if state.state == WorkerPoolState::Running {
            self.inner.work_condvar.notify_one();
        }
        true
    }

    /// Submits a batch of tasks to the worker pool.
    pub fn submit_batch<I, F>(&self, jobs: I) -> bool
    where
        I: IntoIterator<Item = F>,
        F: FnOnce() + Send + 'static,
    {
        let mut state = self.inner.state.lock();
        if state.state == WorkerPoolState::Shutdown {
            return false;
        }
        if state.state == WorkerPoolState::Idle {
            state.state = WorkerPoolState::Running;
        }
        let mut count = 0;
        for job in jobs {
            state.queue.push_back(Box::new(job));
            count += 1;
        }
        if count > 0 && state.state == WorkerPoolState::Running {
            self.inner.work_condvar.notify_all();
        }
        true
    }

    /// Spawns a task onto Rayon work-stealing thread pool.
    #[inline]
    pub fn execute_rayon<F>(&self, op: F)
    where
        F: FnOnce() + Send + 'static,
    {
        rayon::spawn(op);
    }

    /// Dynamically scales the active worker thread count.
    pub fn set_worker_count(&self, count: usize) {
        let target = count.max(1);
        let mut state = self.inner.state.lock();
        state.target_workers = target;
        let current_live = state.live_threads;

        if target > current_live && state.state != WorkerPoolState::Shutdown {
            let to_spawn = target - current_live;
            state.live_threads += to_spawn;
            for _ in 0..to_spawn {
                let inner_clone = Arc::clone(&self.inner);
                thread::Builder::new()
                    .name("ttzip-worker-thread".to_string())
                    .spawn(move || worker_loop(inner_clone))
                    .expect("Failed to spawn TTZip worker thread");
            }
        } else if target < current_live {
            self.inner.work_condvar.notify_all();
        }
    }

    /// Pauses task execution on the pool.
    pub fn pause(&self) {
        let mut state = self.inner.state.lock();
        if state.state == WorkerPoolState::Running || state.state == WorkerPoolState::Idle {
            state.state = WorkerPoolState::Paused;
        }
    }

    /// Resumes paused task execution.
    pub fn resume(&self) {
        let mut state = self.inner.state.lock();
        if state.state == WorkerPoolState::Paused {
            if state.queue.is_empty() && state.active_workers == 0 {
                state.state = WorkerPoolState::Idle;
            } else {
                state.state = WorkerPoolState::Running;
            }
            self.inner.work_condvar.notify_all();
        }
    }

    /// Blocks the current thread until all pending and active tasks complete.
    pub fn drain(&self) {
        let mut state = self.inner.state.lock();
        if state.state == WorkerPoolState::Shutdown {
            return;
        }
        if state.queue.is_empty() && state.active_workers == 0 {
            state.state = WorkerPoolState::Idle;
            return;
        }
        state.state = WorkerPoolState::Draining;
        self.inner.work_condvar.notify_all();
        while state.state == WorkerPoolState::Draining {
            self.inner.drain_condvar.wait(&mut state);
        }
    }

    /// Shuts down the worker pool and terminates all worker threads.
    pub fn shutdown(&self) {
        let mut state = self.inner.state.lock();
        state.state = WorkerPoolState::Shutdown;
        state.queue.clear();
        self.inner.work_condvar.notify_all();
        self.inner.drain_condvar.notify_all();
    }

    /// Returns current lifecycle state.
    pub fn state(&self) -> WorkerPoolState {
        self.inner.state.lock().state
    }

    /// Returns the target worker count.
    pub fn worker_count(&self) -> usize {
        self.inner.state.lock().target_workers
    }

    /// Returns the number of currently active workers.
    pub fn active_workers(&self) -> usize {
        self.inner.state.lock().active_workers
    }

    /// Returns the number of pending tasks in queue.
    pub fn pending_tasks(&self) -> usize {
        self.inner.state.lock().queue.len()
    }

    /// Returns total completed tasks count.
    pub fn completed_tasks(&self) -> u64 {
        self.inner.state.lock().completed_tasks
    }

    /// Returns total failed tasks count.
    pub fn failed_tasks(&self) -> u64 {
        self.inner.state.lock().failed_tasks
    }
}

impl Drop for EventDrivenWorkerPool {
    fn drop(&mut self) {
        self.shutdown();
    }
}
