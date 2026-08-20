// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Atomic cancellation tokens and cross-thread notification channels.

use crate::types::TTZipStatus;
use std::sync::atomic::{AtomicBool, AtomicU8, Ordering};
use std::sync::Arc;

/// Cancellation reason conforming to `contracts/ttzip_progress_log_event.json`.
#[repr(u8)]
#[derive(Debug, Copy, Clone, PartialEq, Eq)]
pub enum CancellationReason {
    UserRequested = 0,
    Timeout = 1,
    ResourceExhaustion = 2,
    FatalError = 3,
}

impl CancellationReason {
    pub fn as_str(self) -> &'static str {
        match self {
            CancellationReason::UserRequested => "userRequested",
            CancellationReason::Timeout => "timeout",
            CancellationReason::ResourceExhaustion => "resourceExhaustion",
            CancellationReason::FatalError => "fatalError",
        }
    }

    pub fn from_u8(val: u8) -> Self {
        match val {
            1 => CancellationReason::Timeout,
            2 => CancellationReason::ResourceExhaustion,
            3 => CancellationReason::FatalError,
            _ => CancellationReason::UserRequested,
        }
    }
}

/// Thread-safe atomic cancellation token.
#[derive(Debug, Clone)]
pub struct CancellationToken {
    cancelled: Arc<AtomicBool>,
    reason: Arc<AtomicU8>,
}

impl Default for CancellationToken {
    fn default() -> Self {
        Self::new()
    }
}

impl CancellationToken {
    /// Creates a new uncancelled token.
    pub fn new() -> Self {
        Self {
            cancelled: Arc::new(AtomicBool::new(false)),
            reason: Arc::new(AtomicU8::new(0)),
        }
    }

    /// Signals cancellation with the specified reason.
    pub fn cancel(&self, reason: CancellationReason) {
        self.reason.store(reason as u8, Ordering::Release);
        self.cancelled.store(true, Ordering::Release);
    }

    /// Returns true if cancellation has been signalled.
    #[inline]
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::Acquire)
    }

    /// Returns the cancellation reason if cancelled.
    pub fn cancellation_reason(&self) -> Option<CancellationReason> {
        if self.is_cancelled() {
            Some(CancellationReason::from_u8(self.reason.load(Ordering::Acquire)))
        } else {
            None
        }
    }

    /// Helper that returns `Err(TTZipStatus::Cancelled)` if cancelled, or `Ok(())` otherwise.
    #[inline]
    pub fn check(&self) -> Result<(), TTZipStatus> {
        if self.is_cancelled() {
            Err(TTZipStatus::Cancelled)
        } else {
            Ok(())
        }
    }

    /// Creates a child token that shares cancellation state.
    pub fn child_token(&self) -> Self {
        self.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_cancellation_token_basic() {
        let token = CancellationToken::new();
        assert!(!token.is_cancelled());
        assert_eq!(token.check(), Ok(()));
        assert_eq!(token.cancellation_reason(), None);

        token.cancel(CancellationReason::Timeout);
        assert!(token.is_cancelled());
        assert_eq!(token.check(), Err(TTZipStatus::Cancelled));
        assert_eq!(token.cancellation_reason(), Some(CancellationReason::Timeout));
    }

    #[test]
    fn test_cancellation_token_cross_thread() {
        let token = CancellationToken::new();
        let token_clone = token.child_token();

        let handle = thread::spawn(move || {
            while !token_clone.is_cancelled() {
                thread::yield_now();
            }
            token_clone.cancellation_reason()
        });

        thread::sleep(std::time::Duration::from_millis(10));
        token.cancel(CancellationReason::UserRequested);

        let reason = handle.join().expect("join");
        assert_eq!(reason, Some(CancellationReason::UserRequested));
    }
}
