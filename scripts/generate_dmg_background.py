#!/usr/bin/env python3
# SPDX-License-Identifier: LicenseRef-TTZip-Source-Available-1.0
#
# Copyright (c) 2026 Witt Kung <witt.w.kung@gmail.com>
# All rights reserved.
#
# TTZip: High-performance native archiving and compression engine for macOS.
#
# generate_dmg_background.py: Generates high-DPI Retina DMG background artboard.

import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_dmg_background(output_path, width=1200, height=800):
    # 1. Base dark canvas with subtle gradient
    img = Image.new("RGBA", (width, height), (20, 20, 23, 255))
    draw = ImageDraw.Draw(img)
    
    # 2. Radial gold aura in center
    aura = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    aura_draw = ImageDraw.Draw(aura)
    center_x, center_y = width // 2, height // 2
    
    for r in range(400, 0, -10):
        alpha = int(14 * (1.0 - r / 400.0))
        aura_draw.ellipse(
            (center_x - r, center_y - r * 0.7, center_x + r, center_y + r * 0.7),
            fill=(212, 175, 55, alpha)
        )
    
    aura = aura.filter(ImageFilter.GaussianBlur(radius=20))
    img = Image.alpha_composite(img, aura)
    draw = ImageDraw.Draw(img)
    
    # 3. Fonts
    font_paths = [
        "/System/Library/Fonts/SFProDisplay-Bold.otf",
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
        "/Library/Fonts/Arial.ttf"
    ]
    
    def get_font(size, bold=False):
        for p in font_paths:
            if os.path.exists(p):
                try:
                    return ImageFont.truetype(p, size)
                except Exception:
                    continue
        return ImageFont.load_default()

    font_title = get_font(44, bold=True)
    font_subtitle = get_font(22, bold=False)
    font_instruction = get_font(24, bold=False)
    font_pill = get_font(18, bold=True)
    
    # 4. Header Titles
    title_text = "TTZip for macOS"
    subtitle_text = "Apple Silicon Native Archiving & Compression Engine"
    
    # Center title
    bbox_title = draw.textbbox((0, 0), title_text, font=font_title)
    w_t = bbox_title[2] - bbox_title[0]
    draw.text(((width - w_t) // 2, 70), title_text, fill=(245, 244, 240, 255), font=font_title)
    
    # Subtitle
    bbox_sub = draw.textbbox((0, 0), subtitle_text, font=font_subtitle)
    w_s = bbox_sub[2] - bbox_sub[0]
    draw.text(((width - w_s) // 2, 130), subtitle_text, fill=(161, 161, 170, 230), font=font_subtitle)
    
    # 5. Icon target drop zones (Cards at x=280 and x=920, y=410)
    card_w, card_h = 240, 240
    card1_x = 280 - card_w // 2
    card2_x = 920 - card_w // 2
    card_y = 410 - card_h // 2
    
    # Subtle frosted glass backdrop for app & applications
    card_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    card_draw = ImageDraw.Draw(card_layer)
    
    # Rounded rectangles
    card_draw.rounded_rectangle((card1_x, card_y, card1_x + card_w, card_y + card_h), radius=28, fill=(255, 255, 255, 10), outline=(212, 175, 55, 60), width=2)
    card_draw.rounded_rectangle((card2_x, card_y, card2_x + card_w, card_y + card_h), radius=28, fill=(255, 255, 255, 10), outline=(255, 255, 255, 30), width=2)
    
    img = Image.alpha_composite(img, card_layer)
    draw = ImageDraw.Draw(img)
    
    # 6. Kintsugi Gold Connector Arrow
    arrow_y = 410
    start_x = 440
    end_x = 760
    
    # Dashed line
    dash_len = 16
    gap_len = 10
    curr_x = start_x
    while curr_x < end_x - 30:
        draw.line([(curr_x, arrow_y), (min(curr_x + dash_len, end_x - 30), arrow_y)], fill=(212, 175, 55, 180), width=4)
        curr_x += dash_len + gap_len
    
    # Arrow head
    draw.polygon([
        (end_x - 10, arrow_y),
        (end_x - 36, arrow_y - 16),
        (end_x - 30, arrow_y),
        (end_x - 36, arrow_y + 16)
    ], fill=(212, 175, 55, 240))
    
    # 7. Drag & Drop instruction pill
    inst_text = "Drag TTZip to Applications to install"
    bbox_inst = draw.textbbox((0, 0), inst_text, font=font_instruction)
    w_i = bbox_inst[2] - bbox_inst[0]
    h_i = bbox_inst[3] - bbox_inst[1]
    
    pill_pad_x, pill_pad_y = 32, 14
    pill_w = w_i + pill_pad_x * 2
    pill_h = h_i + pill_pad_y * 2
    pill_x = (width - pill_w) // 2
    pill_y = 660
    
    pill_layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pill_draw = ImageDraw.Draw(pill_layer)
    pill_draw.rounded_rectangle(
        (pill_x, pill_y, pill_x + pill_w, pill_y + pill_h),
        radius=pill_h // 2,
        fill=(255, 255, 255, 14),
        outline=(212, 175, 55, 100),
        width=2
    )
    img = Image.alpha_composite(img, pill_layer)
    draw = ImageDraw.Draw(img)
    
    draw.text((pill_x + pill_pad_x, pill_y + pill_pad_y), inst_text, fill=(228, 228, 231, 255), font=font_instruction)
    
    # 8. Save Retina @2x image
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"  ✓ Retina DMG background generated: {output_path} ({width}x{height})")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    workspace = os.path.dirname(script_dir)
    res_dir = os.path.join(workspace, "resources")
    out_file = os.path.join(res_dir, "dmg_background.png")
    create_dmg_background(out_file)
