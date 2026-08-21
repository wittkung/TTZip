// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Interactive terminal TUI runner session and terminal lifecycle.

use crate::app::{AppMode, AppState};
use crate::event::EventHandler;
use crate::ui;
use crossterm::event::{DisableMouseCapture, EnableMouseCapture};
use crossterm::execute;
use crossterm::terminal::{
    disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen,
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use std::io;
use std::path::PathBuf;
use std::time::Duration;

/// Runs interactive terminal TUI session.
pub fn run_interactive_tui(archive_path: PathBuf) -> Result<(), Box<dyn std::error::Error>> {
    let mut app_state = AppState::new(archive_path)
        .map_err(|e| format!("Failed to load archive: {:?}", e))?;

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let event_handler = EventHandler::new(Duration::from_millis(16));

    // Main TUI render & event loop
    loop {
        terminal.draw(|f| {
            ui::render(f, &mut app_state);
        })?;

        let event = event_handler.next()?;
        let sender = event_handler.sender.clone();
        app_state.handle_event(event, sender);

        if app_state.current_mode == AppMode::Exiting {
            break;
        }
    }

    event_handler.stop();

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    Ok(())
}
