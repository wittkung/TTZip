// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Terminal Event Loop and Cross-Thread Channel Dispatch.

use crate::ui::progress::ProgressSnapshot;
use crossbeam_channel::{bounded, Receiver, Sender};
use crossterm::event::{self, Event as CrosstermEvent, KeyEvent, MouseEvent};
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

/// Normalized application event dispatched to main TUI state machine.
#[derive(Debug, Clone)]
pub enum AppEvent {
    Key(KeyEvent),
    Mouse(MouseEvent),
    Resize(u16, u16),
    Progress(ProgressSnapshot),
    TaskCompleted(Result<String, String>),
    CancellationRequested,
    Tick,
    // Multi-modal notification events
    RecoveryProgress {
        tested: usize,
        total: usize,
        speed: f64,
        elapsed_secs: f64,
        eta_secs: f64,
    },
    RecoveryCompleted(Result<Option<String>, String>),
    RepairCompleted(Result<usize, String>),
    ParetoBenchmarkCompleted(Result<String, String>),
    SplitCompleted(Result<Vec<String>, String>),
}

/// JSON payload schema conforming to `contracts/tui_event_contract.json`.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TUIEventPayload {
    #[serde(rename = "actionType")]
    pub action_type: String,
    #[serde(rename = "keyChar", skip_serializing_if = "Option::is_none")]
    pub key_char: Option<String>,
    #[serde(rename = "windowCols", skip_serializing_if = "Option::is_none")]
    pub window_cols: Option<u16>,
    #[serde(rename = "windowRows", skip_serializing_if = "Option::is_none")]
    pub window_rows: Option<u16>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TUIEventContract {
    #[serde(rename = "eventKind")]
    pub event_kind: String,
    #[serde(rename = "timestampEpochMs")]
    pub timestamp_epoch_ms: u64,
    pub payload: TUIEventPayload,
}

impl TUIEventContract {
    pub fn new(event_kind: &str, action_type: &str) -> Self {
        let timestamp_epoch_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);

        Self {
            event_kind: event_kind.to_string(),
            timestamp_epoch_ms,
            payload: TUIEventPayload {
                action_type: action_type.to_string(),
                key_char: None,
                window_cols: None,
                window_rows: None,
            },
        }
    }
}

/// Event loop coordinator managing terminal inputs and background worker channels.
pub struct EventHandler {
    pub sender: Sender<AppEvent>,
    pub receiver: Receiver<AppEvent>,
    is_running: Arc<AtomicBool>,
}

impl EventHandler {
    /// Spawns background event reader thread with ~60 FPS (16ms) polling cadence.
    pub fn new(tick_rate: Duration) -> Self {
        let (sender, receiver) = bounded(256);
        let is_running = Arc::new(AtomicBool::new(true));

        let thread_sender = sender.clone();
        let thread_running = Arc::clone(&is_running);

        thread::spawn(move || {
            let mut last_tick = Instant::now();

            while thread_running.load(Ordering::Relaxed) {
                let timeout = tick_rate
                    .checked_sub(last_tick.elapsed())
                    .unwrap_or(Duration::from_millis(0));

                if event::poll(timeout).unwrap_or(false) {
                    match event::read() {
                        Ok(CrosstermEvent::Key(key)) => {
                            let _ = thread_sender.send(AppEvent::Key(key));
                        }
                        Ok(CrosstermEvent::Mouse(mouse)) => {
                            let _ = thread_sender.send(AppEvent::Mouse(mouse));
                        }
                        Ok(CrosstermEvent::Resize(w, h)) => {
                            let _ = thread_sender.send(AppEvent::Resize(w, h));
                        }
                        _ => {}
                    }
                }

                if last_tick.elapsed() >= tick_rate {
                    let _ = thread_sender.send(AppEvent::Tick);
                    last_tick = Instant::now();
                }
            }
        });

        Self {
            sender,
            receiver,
            is_running,
        }
    }

    /// Receives next available event.
    pub fn next(&self) -> Result<AppEvent, crossbeam_channel::RecvError> {
        self.receiver.recv()
    }

    /// Tries to receive next available event non-blocking.
    pub fn try_next(&self) -> Result<AppEvent, crossbeam_channel::TryRecvError> {
        self.receiver.try_recv()
    }

    /// Closes event stream and notifies worker thread.
    pub fn stop(&self) {
        self.is_running.store(false, Ordering::Release);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tui_event_contract_serialization() {
        let mut contract = TUIEventContract::new("keyInput", "navigateDown");
        contract.payload.key_char = Some("j".to_string());

        let json_val = serde_json::to_value(&contract).expect("serialize");
        assert_eq!(json_val["eventKind"], "keyInput");
        assert_eq!(json_val["payload"]["actionType"], "navigateDown");
        assert_eq!(json_val["payload"]["keyChar"], "j");
        assert!(json_val["timestampEpochMs"].as_u64().unwrap() > 0);
    }
}
