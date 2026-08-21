// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! Interactive modal overlays and multi-step dialog wizards.

pub mod pareto;
pub mod recovery;
pub mod repair;
pub mod split;

pub use pareto::render_pareto_modal;
pub use recovery::render_recovery_modal;
pub use repair::render_repair_modal;
pub use split::render_split_modal;

use crate::ui::theme::Theme;
use ratatui::layout::Rect;
use ratatui::style::Style;
use ratatui::widgets::{Block, BorderType, Borders, Clear};
use ratatui::Frame;

/// Adaptive centered rectangle calculator for modal popups with min dimensions and max screen percentages.
pub fn centered_rect_adaptive(
    min_w: u16,
    max_w_pct: u16,
    min_h: u16,
    max_h_pct: u16,
    area: Rect,
) -> Rect {
    if area.width == 0 || area.height == 0 {
        return Rect::default();
    }
    let target_w = ((area.width as u32 * max_w_pct as u32) / 100) as u16;
    let width = target_w.max(min_w).min(area.width);

    let target_h = ((area.height as u32 * max_h_pct as u32) / 100) as u16;
    let height = target_h.max(min_h).min(area.height);

    let x = area.x + (area.width.saturating_sub(width)) / 2;
    let y = area.y + (area.height.saturating_sub(height)) / 2;

    Rect::new(x, y, width, height)
}

/// Constructs a standard modal block with double gold borders and dark overlay background.
pub fn double_gold_modal_block(title: &str) -> Block<'static> {
    Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(Theme::ACCENT_GOLD))
        .title(format!(" {} ", title))
        .title_style(Theme::style_title())
        .style(Style::default().bg(Theme::BG_OVERLAY))
}

/// Clears the popup background and renders the double-gold border container,
/// returning the inner drawing area.
pub fn render_modal_container(frame: &mut Frame, area: Rect, title: &str) -> Rect {
    frame.render_widget(Clear, area);
    let block = double_gold_modal_block(title);
    let inner = block.inner(area);
    frame.render_widget(block, area);
    inner
}
