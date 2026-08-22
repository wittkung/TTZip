// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Multi-Producer Multi-Consumer (MPMC) lock-free bounded ring buffer.
//!
//! Based on Dmitry Vyukov's bounded lock-free MPMC queue algorithm:
//! - Per-cell sequence counter atomics.
//! - Non-blocking push and pop operations with CAS contention handling.
//! - Hardware cache line padded enqueue and dequeue position pointers.

use crossbeam_utils::CachePadded;
use std::cell::UnsafeCell;
use std::mem::MaybeUninit;
use std::sync::atomic::{AtomicUsize, Ordering};

struct Cell<T> {
    sequence: AtomicUsize,
    value: UnsafeCell<MaybeUninit<T>>,
}

/// Bounded Multi-Producer Multi-Consumer (MPMC) lock-free ring buffer.
pub struct MpmcRingBuffer<T> {
    buffer: Box<[Cell<T>]>,
    mask: usize,
    capacity: usize,
    enqueue_pos: CachePadded<AtomicUsize>,
    dequeue_pos: CachePadded<AtomicUsize>,
}

unsafe impl<T: Send> Send for MpmcRingBuffer<T> {}
unsafe impl<T: Send> Sync for MpmcRingBuffer<T> {}
impl<T> std::panic::UnwindSafe for MpmcRingBuffer<T> {}
impl<T> std::panic::RefUnwindSafe for MpmcRingBuffer<T> {}

impl<T> MpmcRingBuffer<T> {
    /// Creates a new bounded MPMC ring buffer.
    /// Capacity is rounded up to the nearest power of two (minimum 2).
    pub fn new(capacity: usize) -> Self {
        let cap = capacity.max(2).next_power_of_two();
        let mask = cap - 1;

        let mut cells = Vec::with_capacity(cap);
        for i in 0..cap {
            cells.push(Cell {
                sequence: AtomicUsize::new(i),
                value: UnsafeCell::new(MaybeUninit::uninit()),
            });
        }

        Self {
            buffer: cells.into_boxed_slice(),
            mask,
            capacity: cap,
            enqueue_pos: CachePadded::new(AtomicUsize::new(0)),
            dequeue_pos: CachePadded::new(AtomicUsize::new(0)),
        }
    }

    /// Attempts to push an element to the queue without blocking.
    /// Returns `Err(item)` if the queue is full.
    pub fn push(&self, item: T) -> Result<(), T> {
        let mut pos = self.enqueue_pos.load(Ordering::Relaxed);
        loop {
            let cell = &self.buffer[pos & self.mask];
            let seq = cell.sequence.load(Ordering::Acquire);
            let diff = (seq as isize).wrapping_sub(pos as isize);

            if diff == 0 {
                match self.enqueue_pos.compare_exchange_weak(
                    pos,
                    pos.wrapping_add(1),
                    Ordering::Relaxed,
                    Ordering::Relaxed,
                ) {
                    Ok(_) => {
                        // SAFETY: Successful CAS guarantees exclusive write access to this cell at pos
                        unsafe {
                            let slot = cell.value.get();
                            (*slot).write(item);
                        }
                        cell.sequence.store(pos.wrapping_add(1), Ordering::Release);
                        return Ok(());
                    }
                    Err(actual) => pos = actual,
                }
            } else if diff < 0 {
                return Err(item);
            } else {
                pos = self.enqueue_pos.load(Ordering::Relaxed);
            }
        }
    }

    /// Attempts to pop an element from the queue without blocking.
    /// Returns `None` if the queue is empty.
    pub fn pop(&self) -> Option<T> {
        let mut pos = self.dequeue_pos.load(Ordering::Relaxed);
        loop {
            let cell = &self.buffer[pos & self.mask];
            let seq = cell.sequence.load(Ordering::Acquire);
            let diff = (seq as isize).wrapping_sub((pos.wrapping_add(1)) as isize);

            if diff == 0 {
                match self.dequeue_pos.compare_exchange_weak(
                    pos,
                    pos.wrapping_add(1),
                    Ordering::Relaxed,
                    Ordering::Relaxed,
                ) {
                    Ok(_) => {
                        // SAFETY: Successful CAS guarantees exclusive read access to initialized value
                        let val = unsafe {
                            let slot = cell.value.get();
                            (*slot).assume_init_read()
                        };
                        cell.sequence.store(
                            pos.wrapping_add(self.mask).wrapping_add(1),
                            Ordering::Release,
                        );
                        return Some(val);
                    }
                    Err(actual) => pos = actual,
                }
            } else if diff < 0 {
                return None;
            } else {
                pos = self.dequeue_pos.load(Ordering::Relaxed);
            }
        }
    }

    /// Returns the buffer capacity.
    #[inline]
    pub fn capacity(&self) -> usize {
        self.capacity
    }

    /// Returns the approximate number of items currently in the buffer.
    #[inline]
    pub fn len(&self) -> usize {
        let head = self.enqueue_pos.load(Ordering::Relaxed);
        let tail = self.dequeue_pos.load(Ordering::Relaxed);
        head.saturating_sub(tail)
    }

    /// Returns true if the buffer is empty.
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Returns true if the buffer is full.
    #[inline]
    pub fn is_full(&self) -> bool {
        self.len() >= self.capacity
    }
}

impl<T> Drop for MpmcRingBuffer<T> {
    fn drop(&mut self) {
        while self.pop().is_some() {}
    }
}
