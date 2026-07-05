#!/usr/bin/env python3
"""Generate top-down building sprites for settlement interiors.

Each building is drawn procedurally with PIL at 24px per cell.
Output: assets/sprites/buildings/{sprite_id}.png

This is a BUILD-TIME tool. Godot loads these pre-rendered PNGs.
Idempotent. Use --force to overwrite.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BUILDING_DIR = ROOT / "assets" / "sprites" / "buildings"

CELL = 24

# Building definitions: (sprite_id, w_cells, h_cells, base_color, roof_color, detail_color)
BUILDINGS = [
    ("tavern",        3, 3, (140, 100, 60),  (100, 70, 40),  (200, 160, 80)),
    ("trader",        3, 3, (120, 110, 90),  (90, 80, 65),   (180, 160, 120)),
    ("worktable",     2, 2, (110, 100, 80),  (85, 75, 60),   (160, 140, 100)),
    ("armor_table",   2, 2, (100, 105, 110), (75, 80, 85),   (150, 155, 160)),
    ("blacksmith",    2, 2, (90, 85, 80),    (65, 60, 55),   (180, 100, 60)),
    ("quest_board",   1, 1, (130, 110, 70),  (100, 85, 55),  (180, 160, 100)),
    ("faction_hq",    4, 3, (110, 100, 95),  (80, 72, 68),   (160, 145, 130)),
    ("auction_house", 3, 3, (130, 120, 100), (95, 88, 72),   (190, 170, 130)),
    ("arena",         5, 5, (140, 130, 110), (110, 100, 85),  (170, 155, 125)),
]


def _draw_building(sprite_id: str, w: int, h: int, base: tuple, roof: tuple, detail: tuple) -> Image.Image:
    """Draw a top-down building sprite."""
    pw = w * CELL
    ph = h * CELL
    img = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Foundation / floor (inner area, 1-cell inset)
    for cy in range(h):
        for cx in range(w):
            x0 = cx * CELL
            y0 = cy * CELL
            # Floor
            draw.rectangle([x0, y0, x0 + CELL - 1, y0 + CELL - 1], fill=base)
            # Floor texture: sparse darker pixels
            for py in range(y0 + 2, y0 + CELL - 2, 3):
                for px in range(x0 + 2, x0 + CELL - 2, 3):
                    if (px + py) % 7 == 0:
                        darker = tuple(max(0, c - 20) for c in base)
                        draw.point((px, py), fill=darker)

    # Walls (border around the building)
    wall_color = tuple(max(0, c - 30) for c in base)
    # Top wall
    draw.rectangle([0, 0, pw - 1, 3], fill=wall_color)
    # Bottom wall
    draw.rectangle([0, ph - 4, pw - 1, ph - 1], fill=wall_color)
    # Left wall
    draw.rectangle([0, 0, 3, ph - 1], fill=wall_color)
    # Right wall
    draw.rectangle([pw - 4, 0, pw - 1, ph - 1], fill=wall_color)

    # Roof / awning (top 40% of building, different color)
    roof_h = max(4, int(ph * 0.35))
    for y in range(4, roof_h):
        alpha = 180 + int(75 * (y - 4) / max(1, roof_h - 4))
        for x in range(4, pw - 4):
            if (x + y) % 3 == 0:
                img.putpixel((x, y), roof + (alpha,))

    # Door (center of bottom wall)
    door_x = pw // 2 - CELL // 4
    door_w = CELL // 2
    draw.rectangle([door_x, ph - 5, door_x + door_w - 1, ph - 1], fill=detail)

    # Windows (if building is large enough)
    if w >= 2 and h >= 2:
        win_color = (200, 200, 160, 200)
        # Left window
        wx = 6
        wy = ph // 2 - 2
        draw.rectangle([wx, wy, wx + 3, wy + 3], fill=win_color)
        # Right window
        if w >= 3:
            wx = pw - 10
            draw.rectangle([wx, wy, wx + 3, wy + 3], fill=win_color)

    # Special details per building type
    if sprite_id == "blacksmith":
        # Anvil in center
        ax, ay = pw // 2 - 3, ph // 2 + 2
        draw.rectangle([ax, ay, ax + 5, ay + 3], fill=(80, 75, 70, 220))
        # Forge glow (small orange circle)
        draw.ellipse([ax + 6, ay - 2, ax + 10, ay + 2], fill=(200, 120, 40, 180))
    elif sprite_id == "tavern":
        # Table in center
        tx, ty = pw // 2 - 4, ph // 2
        draw.rectangle([tx, ty, tx + 7, ty + 4], fill=(160, 120, 60, 200))
    elif sprite_id == "quest_board":
        # Notice board (vertical rectangle)
        bx, by = 4, 3
        draw.rectangle([bx, by, bx + 15, by + 17], fill=(140, 110, 60, 200))
        # Papers pinned
        draw.rectangle([bx + 3, by + 2, bx + 7, by + 6], fill=(220, 210, 180, 200))
        draw.rectangle([bx + 9, by + 4, bx + 13, by + 8], fill=(220, 210, 180, 180))
    elif sprite_id == "arena":
        # Fighting ring (circle in center)
        cx, cy = pw // 2, ph // 2
        r = min(pw, ph) // 2 - 6
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(120, 100, 80, 200), width=2)
    elif sprite_id == "faction_hq":
        # Banner (colored rectangle on top)
        bx = pw // 2 - 4
        draw.rectangle([bx, 6, bx + 7, 14], fill=(180, 60, 60, 200))

    return img


def main():
    parser = argparse.ArgumentParser(description="Generate building sprites")
    parser.add_argument("--force", action="store_true", help="Overwrite existing")
    args = parser.parse_args()

    BUILDING_DIR.mkdir(parents=True, exist_ok=True)

    generated = 0
    skipped = 0
    for sprite_id, w, h, base, roof, detail in BUILDINGS:
        out = BUILDING_DIR / f"{sprite_id}.png"
        if out.exists() and not args.force:
            skipped += 1
            continue
        img = _draw_building(sprite_id, w, h, base, roof, detail)
        img.save(out)
        generated += 1
        print(f"  {sprite_id}.png ({w}x{h} = {w*CELL}x{h*CELL}px)")

    print(f"Building sprites: {generated} generated, {skipped} skipped (already exist).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
