#!/usr/bin/env python3
"""Phase 6 base sprite generator.

Produces 11 procedural base sprites at 64x64 (Phase 6) — one per
upgrade tier (0 through 10). Each tier adds more visual elements:
walls, a window, a door, then a chimney, watchtower, courtyard, etc.
Tiers go from a small one-room hut (tier 0) to a full compound
(tier 10). Per-tier HSV color shift is also applied.

Output:
  assets/sprites/base/base_t<1-11>.png   (64x64 RGBA, NEAREST)
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BASE_JSON = ROOT / "data" / "base.json"
OUT_DIR = ROOT / "assets" / "sprites" / "base"
GDFILE = OUT_DIR / ".gdignore"

CELL = 64

# Tier-to-color mapping (HSV). Each tier darkens and shifts hue.
TIER_COLORS = [
	(0.08, 0.20, 0.55),  # 0 — base
	(0.10, 0.25, 0.50),  # 1
	(0.10, 0.30, 0.45),  # 2
	(0.10, 0.35, 0.40),  # 3
	(0.10, 0.40, 0.35),  # 4
	(0.12, 0.45, 0.40),  # 5 — fortified
	(0.13, 0.50, 0.45),  # 6
	(0.14, 0.55, 0.50),  # 7
	(0.15, 0.60, 0.55),  # 8
	(0.16, 0.65, 0.60),  # 9
	(0.18, 0.70, 0.65),  # 10
]


def _hsv_to_rgb(h: float, s: float, v: float) -> tuple:
	i = int(h * 6)
	f = h * 6 - i
	p = v * (1 - s)
	q = v * (1 - s * f)
	t = v * (1 - s * (1 - f))
	i = i % 6
	if i == 0: r, g, b = v, t, p
	elif i == 1: r, g, b = q, v, p
	elif i == 2: r, g, b = p, v, t
	elif i == 3: r, g, b = p, q, v
	elif i == 4: r, g, b = t, p, v
	else: r, g, b = v, p, q
	return (int(r * 255), int(g * 255), int(b * 255))


def _load_json(path: Path):
	if not path.exists():
		return None
	with open(path) as f:
		return json.load(f)


def _draw_base(draw, tier: int, color: tuple, size_tiles: tuple) -> None:
	"""Draws the base structure for the given tier. The base grows
	from a small one-room hut (tier 0/1) to a multi-building compound
	(tier 10)."""
	r, g, b = color
	dark = (max(0, r - 50), max(0, g - 50), max(0, b - 50))
	outline = (max(0, r - 90), max(0, g - 90), max(0, b - 90))
	wall = (r, g, b)
	roof = (max(0, r - 30), max(0, g - 20), max(0, b - 10))
	ground = (60, 50, 40)
	window_color = (180, 220, 240)
	door_color = (40, 30, 20)
	# Ground patch
	draw.rectangle([2, CELL - 12, CELL - 2, CELL - 2], fill=ground, outline=outline)
	# Main building (centered, taller with tier)
	main_w: int = 28 + tier * 2
	main_h: int = 18 + tier
	main_x: int = (CELL - main_w) // 2
	main_y: int = CELL - 14 - main_h
	# Wall
	draw.rectangle([main_x, main_y, main_x + main_w - 1, main_y + main_h - 1], fill=wall, outline=outline)
	# Roof (triangle)
	draw.polygon([(main_x - 2, main_y), (main_x + main_w + 1, main_y), (main_x + main_w // 2, main_y - 6 - tier // 2)], fill=roof, outline=outline)
	# Door
	door_w: int = 4
	door_h: int = 8
	draw.rectangle([main_x + main_w // 2 - door_w // 2, main_y + main_h - door_h, main_x + main_w // 2 + door_w // 2 - 1, main_y + main_h - 1], fill=door_color)
	# Window (one on each side of the door)
	if tier >= 2:
		draw.rectangle([main_x + 4, main_y + 4, main_x + 7, main_y + 7], fill=window_color)
		draw.rectangle([main_x + main_w - 8, main_y + 4, main_x + main_w - 5, main_y + 7], fill=window_color)
	if tier >= 3:
		# Chimney
		draw.rectangle([main_x + main_w - 8, main_y - 4, main_x + main_w - 5, main_y - 1], fill=dark)
	if tier >= 4:
		# Side wing (left)
		draw.rectangle([main_x - 8, main_y + 4, main_x - 1, main_y + main_h - 1], fill=wall, outline=outline)
		draw.polygon([(main_x - 10, main_y + 4), (main_x - 1, main_y + 4), (main_x - 5, main_y - 2)], fill=roof, outline=outline)
	if tier >= 5:
		# Side wing (right)
		draw.rectangle([main_x + main_w, main_y + 4, main_x + main_w + 7, main_y + main_h - 1], fill=wall, outline=outline)
		draw.polygon([(main_x + main_w, main_y + 4), (main_x + main_w + 8, main_y + 4), (main_x + main_w + 4, main_y - 2)], fill=roof, outline=outline)
	if tier >= 6:
		# Watchtower (left)
		draw.rectangle([main_x - 12, main_y - 8, main_x - 7, main_y + main_h - 4], fill=wall, outline=outline)
		draw.polygon([(main_x - 13, main_y - 8), (main_x - 6, main_y - 8), (main_x - 9, main_y - 14)], fill=roof, outline=outline)
	if tier >= 7:
		# Watchtower (right)
		draw.rectangle([main_x + main_w + 6, main_y - 8, main_x + main_w + 11, main_y + main_h - 4], fill=wall, outline=outline)
		draw.polygon([(main_x + main_w + 5, main_y - 8), (main_x + main_w + 12, main_y - 8), (main_x + main_w + 8, main_y - 14)], fill=roof, outline=outline)
	if tier >= 8:
		# Fence / wall around the compound
		fence_h: int = 6
		draw.rectangle([4, CELL - 12, CELL - 5, CELL - 7], fill=dark)  # left fence
		draw.rectangle([4, CELL - 6, 8, CELL - 3], fill=dark)
		draw.rectangle([CELL - 9, CELL - 12, CELL - 5, CELL - 7], fill=dark)  # right fence
		draw.rectangle([CELL - 9, CELL - 6, CELL - 5, CELL - 3], fill=dark)
	if tier >= 9:
		# Courtyard path
		draw.rectangle([CELL // 2 - 3, main_y + main_h, CELL // 2 + 2, CELL - 12], fill=ground, outline=outline)
		# Garden plot
		draw.rectangle([8, CELL - 14, 14, CELL - 8], fill=(40, 80, 40), outline=outline)
		draw.rectangle([CELL - 15, CELL - 14, CELL - 9, CELL - 8], fill=(40, 80, 40), outline=outline)
	if tier >= 10:
		# Compound expansion: outer fence, banner
		draw.rectangle([2, CELL - 14, CELL - 3, CELL - 10], fill=outline)  # full perimeter top edge
		draw.polygon([(CELL // 2 - 5, main_y - 12), (CELL // 2 + 5, main_y - 12), (CELL // 2, main_y - 18)], fill=(180, 30, 30), outline=outline)


def main() -> int:
	data = _load_json(BASE_JSON)
	if data is None:
		print("base.json missing", file=sys.stderr)
		return 1
	upgrades: list = data.get("upgrades", [])
	if not upgrades:
		print("base.json has no upgrades", file=sys.stderr)
		return 1
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	if not GDFILE.exists():
		GDFILE.write_text("# generated by tools/generate_base_sprites.py\n")
	ok = 0
	for tier_idx, _ in enumerate(upgrades):
		tier: int = tier_idx + 1
		h, s, v = TIER_COLORS[min(tier, len(TIER_COLORS) - 1)]
		color = _hsv_to_rgb(h, s, v)
		size_tiles = upgrades[tier_idx].get("size_tiles", [4, 4])
		img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
		draw = ImageDraw.Draw(img)
		_draw_base(draw, tier, color, size_tiles)
		sprite_name: str = f"base_t{tier}"
		out_path: Path = OUT_DIR / f"{sprite_name}.png"
		img.save(out_path, "PNG")
		print(f"  ok   {sprite_name}.png (tier {tier}, size {size_tiles[0]}x{size_tiles[1]})")
		ok += 1
	print(f"Done. ok={ok}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
