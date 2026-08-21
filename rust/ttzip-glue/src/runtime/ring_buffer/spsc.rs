// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Single-Producer Single-Consumer (SPSC) lock-free bounded ring buffer.
//!
//! Features:
//! - Hardware cache line separation via `CachePadded<AtomicUsize>` preventing false sharing.
//! - Shadow caching on both producer and consumer sides avoiding L1/L2 coherence invalidation.
//! - Power-of-two bitmask indexing.

use crossbeam_utils::CachePadded;
use std::cell::{Cell, UnsafeCell};
use std::mem::MaybeUninit;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

struct SpscInner<T> {
    buffer: Box<[UnsafeCell<MaybeUninit<T>>]>,
    capacity: usize,
    mask: usize,
    head: CachePadded<AtomicUsize>, // Written by producer
    tail: CachePadded<AtomicUsize>, // Written by consumer
    shadow_tail: CachePadded<UnsafeCell<usize>>, // Cached tail for producer
    shadow_head: CachePadded<UnsafeCell<usize>>, // Cached head for consumer
}

unsafe impl<T: Send> Send for SpscInner<T> {}
unsafe impl<T: Send> Sync for SpscInner<T> {}

impl<T> Drop for SpscInner<T> {
    fn drop(&mut self) {
        let head = self.head.load(Ordering::Relaxed);
        let mut tail = self.tail.load(Ordering::Relaxed);
        while tail != head {
            unsafe {
                let slot = self.buffer[tail & self.mask].get();
                std::ptr::drop_in_place((*slot).as_mut_ptr());
            }
            tail = tail.wrapping_add(1);
        }
    }
}

/// SPSC Lock-Free Ring Buffer.
pub struct SpscRingBuffer<T> {
    inner: Arc<SpscInner<T>>,
}

/// Producer endpoint of an SPSC ring buffer.
pub struct SpscProducer<T> {
    inner: Arc<SpscInner<T>>,
    cached_tail: Cell<usize>,
}

/// Consumer endpoint of an SPSC ring buffer.
pub struct SpscConsumer<T> {
    inner: Arc<SpscInner<T>>,
    cached_head: Cell<usize>,
}

unsafe impl<T: Send> Send for SpscProducer<T> {}
unsafe impl<T: Send> Send for SpscConsumer<T> {}
impl<T> std::panic::UnwindSafe for SpscRingBuffer<T> {}
impl<T> std::panic::RefUnwindSafe for SpscRingBuffer<T> {}
impl<T> std::panic::UnwindSafe for SpscProducer<T> {}
impl<T> std::panic::RefUnwindSafe for SpscProducer<T> {}
impl<T> std::panic::UnwindSafe for SpscConsumer<T> {}
impl<T> std::panic::RefUnwindSafe for SpscConsumer<T> {}

impl<T> SpscRingBuffer<T> {
    /// Creates a new SPSC ring buffer with at least the requested capacity.
    /// The actual capacity is rounded up to the nearest power of two (minimum 2).
    pub fn new(capacity: usize) -> Self {
        let cap = capacity.max(2).next_power_of_two();
        let mask = cap - 1;

        let mut raw_vec = Vec::with_capacity(cap);
        for _ in 0..cap {
            raw_vec.push(UnsafeCell::new(MaybeUninit::uninit()));
        }

        let inner = Arc::new(SpscInner {
            buffer: raw_vec.into_boxed_slice(),
            capacity: cap,
            mask,
            head: CachePadded::new(AtomicUsize::new(0)),
            tail: CachePadded::new(AtomicUsize::new(0)),
            shadow_tail: CachePadded::new(UnsafeCell::new(0)),
            shadow_head: CachePadded::new(UnsafeCell::new(0)),
        });

        Self { inner }
    }

    /// Splits the buffer into distinct producer and consumer endpoints with local shadow caches.
    pub fn split(self) -> (SpscProducer<T>, SpscConsumer<T>) {
        let producer = SpscProducer {
            inner: Arc::clone(&self.inner),
            cached_tail: Cell::new(0),
        };
        let consumer = SpscConsumer {
            inner: self.inner,
            cached_head: Cell::new(0),
        };
        (producer, consumer)
    }

    /// Pushes an item into the ring buffer.
    #[inline]
    pub fn push(&self, item: T) -> Result<(), T> {
        let head = self.inner.head.load(Ordering::Relaxed);
        let shadow_tail_ptr = self.inner.shadow_tail.get();
        let cached_tail = unsafe { *shadow_tail_ptr };

        if head.wrapping_sub(cached_tail) >= self.inner.capacity {
            let tail = self.inner.tail.load(Ordering::Acquire);
            unsafe { *shadow_tail_ptr = tail };
            if head.wrapping_sub(tail) >= self.inner.capacity {
                return Err(item);
            }
        }

        unsafe {
            let slot = self.inner.buffer[head & self.inner.mask].get();
            (*slot).write(item);
        }
        self.inner.head.store(head.wrapping_add(1), Ordering::Release);
        Ok(())
    }

    /// Pops an item from the ring buffer.
    #[inline]
    pub fn pop(&self) -> Option<T> {
        let tail = self.inner.tail.load(Ordering::Relaxed);
        let shadow_head_ptr = self.inner.shadow_head.get();
        let cached_head = unsafe { *shadow_head_ptr };

        if tail == cached_head {
            let head = self.inner.head.load(Ordering::Acquire);
            unsafe { *shadow_head_ptr = head };
            if tail == head {
                return None;
            }
        }

        let item = unsafe {
            let slot = self.inner.buffer[tail & self.inner.mask].get();
            (*slot).assume_init_read()
        };
        self.inner.tail.store(tail.wrapping_add(1), Ordering::Release);
        Some(item)
    }

    /// Returns the buffer capacity.
    #[inline]
    pub fn capacity(&self) -> usize {
        self.inner.capacity
    }

    /// Returns the approximate number of elements in the buffer.
    #[inline]
    pub fn len(&self) -> usize {
        let head = self.inner.head.load(Ordering::Relaxed);
        let tail = self.inner.tail.load(Ordering::Relaxed);
        head.wrapping_sub(tail)
    }

    /// Returns true if the buffer is empty.
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Returns true if the buffer is full.
    #[inline]
    pub fn is_full(&self) -> bool {
        self.len() >= self.inner.capacity
    }
}

impl<T> SpscProducer<T> {
    /// Pushes an item via dedicated producer handle using local shadow cache.
    #[inline]
    pub fn push(&self, item: T) -> Result<(), T> {
        let head = self.inner.head.load(Ordering::Relaxed);
        let cached_tail = self.cached_tail.get();

        if head.wrapping_sub(cached_tail) >= self.inner.capacity {
            let tail = self.inner.tail.load(Ordering::Acquire);
            self.cached_tail.set(tail);
            if head.wrapping_sub(tail) >= self.inner.capacity {
                return Err(item);
            }
        }

        unsafe {
            let slot = self.inner.buffer[head & self.inner.mask].get();
            (*slot).write(item);
        }
        self.inner.head.store(head.wrapping_add(1), Ordering::Release);
        Ok(())
    }

    #[inline]
    pub fn capacity(&self) -> usize {
        self.inner.capacity
    }

    #[inline]
    pub fn is_full(&self) -> bool {
        let head = self.inner.head.load(Ordering::Relaxed);
        let tail = self.inner.tail.load(Ordering::Acquire);
        head.wrapping_sub(tail) >= self.inner.capacity
    }
}

impl<T> SpscConsumer<T> {
    /// Pops an item via dedicated consumer handle using local shadow cache.
    #[inline]
    pub fn pop(&self) -> Option<T> {
        let tail = self.inner.tail.load(Ordering::Relaxed);
        let cached_head = self.cached_head.get();

        if tail == cached_head {
            let head = self.inner.head.load(Ordering::Acquire);
            self.cached_head.set(head);
            if tail == head {
                return None;
            }
        }

        let item = unsafe {
            let slot = self.inner.buffer[tail & self.inner.mask].get();
            (*slot).assume_init_read()
        };
        self.inner.tail.store(tail.wrapping_add(1), Ordering::Release);
        Some(item)
    }

    #[inline]
    pub fn is_empty(&self) -> bool {
        let head = self.inner.head.load(Ordering::Acquire);
        let tail = self.inner.tail.load(Ordering::Relaxed);
        head == tail
    }
}
