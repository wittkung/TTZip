// SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
//
// Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
// All rights reserved.
//
// TTZip: High-performance native archiving and compression engine for macOS.

//! macOS Dark / Glassmorphic Design Palette and Styling Tokens.

use ratatui::style::{Color, Modifier, Style};
use ratatui::widgets::{Block, BorderType, Borders};

/// Color tokens conforming to macOS Sonoma / Sequoia Glassmorphic Dark styling.
pub struct Theme;

impl Theme {
    // Surface & Background Colors
    pub const BG_BASE: Color = Color::Rgb(20, 22, 28);
    pub const BG_SURFACE: Color = Color::Rgb(28, 32, 40);
    pub const BG_OVERLAY: Color = Color::Rgb(36, 42, 53);
    pub const BG_SELECTED: Color = Color::Rgb(46, 54, 70);

    // Border Colors
    pub const BORDER_NORMAL: Color = Color::Rgb(58, 66, 82);
    pub const BORDER_FOCUSED: Color = Color::Rgb(230, 180, 80); // Kintsugi Gold
    pub const BORDER_MODAL: Color = Color::Rgb(80, 150, 240); // Aqua Blue

    // Text & Content Colors
    pub const TEXT_PRIMARY: Color = Color::Rgb(242, 245, 250);
    pub const TEXT_SECONDARY: Color = Color::Rgb(150, 160, 175);
    pub const TEXT_MUTED: Color = Color::Rgb(95, 105, 120);

    // Accents & Semantics
    pub const ACCENT_GOLD: Color = Color::Rgb(230, 180, 80); // TTZip Gold
    pub const ACCENT_BLUE: Color = Color::Rgb(64, 156, 255); // macOS Aqua
    pub const ACCENT_GREEN: Color = Color::Rgb(52, 199, 89); // Apple Success Green
    pub const ACCENT_RED: Color = Color::Rgb(255, 69, 58); // Apple Destructive Red
    pub const ACCENT_ORANGE: Color = Color::Rgb(255, 149, 0); // Apple Warning Orange
    pub const ACCENT_PURPLE: Color = Color::Rgb(175, 82, 222);

    // Common Text Styles
    pub fn style_title() -> Style {
        Style::default()
            .fg(Self::ACCENT_GOLD)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_primary_text() -> Style {
        Style::default().fg(Self::TEXT_PRIMARY)
    }

    pub fn style_secondary_text() -> Style {
        Style::default().fg(Self::TEXT_SECONDARY)
    }

    pub fn style_muted_text() -> Style {
        Style::default().fg(Self::TEXT_MUTED)
    }

    pub fn style_header_bar() -> Style {
        Style::default()
            .bg(Self::BG_SURFACE)
            .fg(Self::TEXT_PRIMARY)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_footer_bar() -> Style {
        Style::default()
            .bg(Self::BG_SURFACE)
            .fg(Self::TEXT_SECONDARY)
    }

    pub fn style_table_header() -> Style {
        Style::default()
            .fg(Self::ACCENT_GOLD)
            .add_modifier(Modifier::BOLD)
            .bg(Self::BG_SURFACE)
    }

    pub fn style_table_selected() -> Style {
        Style::default()
            .bg(Self::BG_SELECTED)
            .fg(Self::TEXT_PRIMARY)
            .add_modifier(Modifier::BOLD)
    }

    pub fn style_key_shortcut() -> Style {
        Style::default()
            .fg(Self::ACCENT_BLUE)
            .add_modifier(Modifier::BOLD)
    }

    pub fn default_block(title: &'static str) -> Block<'static> {
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Self::BORDER_NORMAL))
            .title(title)
            .title_style(Self::style_title())
    }

    pub fn focused_block(title: &'static str) -> Block<'static> {
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Double)
            .border_style(Style::default().fg(Self::BORDER_FOCUSED))
            .title(title)
            .title_style(Self::style_title())
    }

    pub fn modal_block(title: &'static str) -> Block<'static> {
        Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Thick)
            .border_style(Style::default().fg(Self::BORDER_MODAL))
            .title(title)
            .title_style(Style::default().fg(Self::ACCENT_BLUE).add_modifier(Modifier::BOLD))
            .style(Style::default().bg(Self::BG_OVERLAY))
    }
}
