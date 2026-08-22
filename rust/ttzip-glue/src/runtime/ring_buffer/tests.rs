// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

use crate::runtime::ring_buffer::mpmc::MpmcRingBuffer;
use crate::runtime::ring_buffer::spsc::SpscRingBuffer;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::thread;

    #[test]
    fn test_spsc_single_thread_push_pop() {
        let rb = SpscRingBuffer::<i32>::new(4);
        assert_eq!(rb.capacity(), 4);
        assert!(rb.is_empty());
        assert_eq!(rb.len(), 0);

        assert!(rb.push(10).is_ok());
        assert!(rb.push(20).is_ok());
        assert!(rb.push(30).is_ok());
        assert!(rb.push(40).is_ok());
        assert!(rb.is_full());
        assert_eq!(rb.push(50), Err(50));

        assert_eq!(rb.pop(), Some(10));
        assert_eq!(rb.pop(), Some(20));
        assert_eq!(rb.pop(), Some(30));
        assert_eq!(rb.pop(), Some(40));
        assert_eq!(rb.pop(), None);
        assert!(rb.is_empty());
    }

    #[test]
    fn test_spsc_split_cross_thread() {
        let rb = SpscRingBuffer::<usize>::new(64);
        let (producer, consumer) = rb.split();

        let count = 10_000;
        let producer_handle = thread::spawn(move || {
            for i in 0..count {
                while producer.push(i).is_err() {
                    std::hint::spin_loop();
                }
            }
        });

        let consumer_handle = thread::spawn(move || {
            let mut received = Vec::with_capacity(count);
            for _ in 0..count {
                loop {
                    if let Some(val) = consumer.pop() {
                        received.push(val);
                        break;
                    }
                    std::hint::spin_loop();
                }
            }
            received
        });

        producer_handle.join().unwrap();
        let received = consumer_handle.join().unwrap();
        assert_eq!(received.len(), count);
        for (i, val) in received.iter().enumerate() {
            assert_eq!(*val, i);
        }
    }

    #[test]
    fn test_mpmc_single_thread() {
        let rb = MpmcRingBuffer::<String>::new(4);
        assert_eq!(rb.capacity(), 4);
        assert!(rb.is_empty());

        assert!(rb.push("item1".to_string()).is_ok());
        assert!(rb.push("item2".to_string()).is_ok());
        assert!(rb.push("item3".to_string()).is_ok());
        assert!(rb.push("item4".to_string()).is_ok());
        assert!(rb.push("item5".to_string()).is_err());

        assert_eq!(rb.pop(), Some("item1".to_string()));
        assert_eq!(rb.pop(), Some("item2".to_string()));
        assert_eq!(rb.pop(), Some("item3".to_string()));
        assert_eq!(rb.pop(), Some("item4".to_string()));
        assert_eq!(rb.pop(), None);
    }

    #[test]
    fn test_mpmc_multi_producer_multi_consumer() {
        let rb = Arc::new(MpmcRingBuffer::<usize>::new(128));
        let num_producers = 4;
        let num_consumers = 4;
        let items_per_producer = 5_000;
        let total_items = num_producers * items_per_producer;

        let mut producer_handles = Vec::new();
        for p in 0..num_producers {
            let rb_clone = Arc::clone(&rb);
            producer_handles.push(thread::spawn(move || {
                for i in 0..items_per_producer {
                    let val = p * items_per_producer + i;
                    while rb_clone.push(val).is_err() {
                        std::hint::spin_loop();
                    }
                }
            }));
        }

        let consumed_count = Arc::new(AtomicUsize::new(0));
        let sum = Arc::new(AtomicUsize::new(0));
        let mut consumer_handles = Vec::new();

        for _ in 0..num_consumers {
            let rb_clone = Arc::clone(&rb);
            let consumed_clone = Arc::clone(&consumed_count);
            let sum_clone = Arc::clone(&sum);

            consumer_handles.push(thread::spawn(move || {
                loop {
                    if consumed_clone.load(Ordering::Relaxed) >= total_items {
                        break;
                    }
                    if let Some(val) = rb_clone.pop() {
                        sum_clone.fetch_add(val, Ordering::Relaxed);
                        consumed_clone.fetch_add(1, Ordering::Relaxed);
                    } else {
                        std::hint::spin_loop();
                    }
                }
            }));
        }

        for h in producer_handles {
            h.join().unwrap();
        }
        for h in consumer_handles {
            h.join().unwrap();
        }

        assert_eq!(consumed_count.load(Ordering::SeqCst), total_items);
        let expected_sum: usize = (0..total_items).sum();
        assert_eq!(sum.load(Ordering::SeqCst), expected_sum);
    }
