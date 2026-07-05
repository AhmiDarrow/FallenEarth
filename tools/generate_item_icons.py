#!/usr/bin/env python3
"""Phase 8 item icon generator.

Produces 24x24 procedural PNGs for every item in data/items.json.
Each icon is a simple shape per item category (consumable / material /
ore / crystal / wood / component / placeable / tool / generic), tinted
by the item's rarity (common / uncommon / rare / epic / legendary).

Output:
  assets/sprites/items/<item_id>.png   (24x24 RGBA, NEAREST)
"""

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ITEMS_JSON = ROOT / "data" / "items.json"
OUT_DIR = ROOT / "assets" / "sprites" / "items"
GDFILE = OUT_DIR / ".gdignore"

CELL = 24

# Item category -> base hue (used to choose the fill color, then
# tinted by rarity).
CATEGORY_HUE = {
	"consumable":  0.05,  # warm yellow
	"material":    0.10,  # brown
	"ore":         0.10,  # brown
	"crystal":     0.62,  # blue-violet
	"component":   0.55,  # cyan-blue
	"placeable":   0.32,  # green
	"station":     0.08,  # warm brown (furniture / workshop)
	"tool":        0.45,  # steel
	"scrap":       0.07,  # rust
	"raw_material":0.10,  # brown
	"ammo":        0.50,  # teal
}

# Rarity multipliers: 0 = common (greyer), +0.2 saturation per step.
RARITY_SAT = {
	"common": 0.20,
	"uncommon": 0.45,
	"rare": 0.70,
	"epic": 0.85,
	"legendary": 0.95,
}

RARITY_VALUE = {
	"common": 0.65,
	"uncommon": 0.75,
	"rare": 0.85,
	"epic": 0.90,
	"legendary": 0.98,
}


def _hsv_to_rgb(h: float, s: float, v: float) -> tuple:
	i = int(h * 6) % 6
	f = h * 6 - int(h * 6)
	p = v * (1 - s)
	q = v * (1 - s * f)
	t = v * (1 - s * (1 - f))
	if i == 0: r, g, b = v, t, p
	elif i == 1: r, g, b = q, v, p
	elif i == 2: r, g, b = p, v, t
	elif i == 3: r, g, b = p, q, v
	elif i == 4: r, g, b = t, p, v
	else:        r, g, b = v, p, q
	return (int(r * 255), int(g * 255), int(b * 255))


def _draw_icon(draw, item: dict) -> None:
	"""Draws a simple shape based on the item's category and tier."""
	category: str = str(item.get("category", "")).lower()
	rarity: str = str(item.get("rarity", "common")).lower()
	hue: float = CATEGORY_HUE.get(category, 0.10)
	sat: float = RARITY_SAT.get(rarity, 0.20)
	val: float = RARITY_VALUE.get(rarity, 0.65)
	fill: tuple = _hsv_to_rgb(hue, sat, val)
	dark: tuple = (max(0, fill[0] - 60), max(0, fill[1] - 60), max(0, fill[2] - 60))
	outline: tuple = (max(0, fill[0] - 100), max(0, fill[1] - 100), max(0, fill[2] - 100))
	# Always draw an outline border
	draw.rectangle([0, 0, CELL - 1, CELL - 1], outline=outline)
	if category == "consumable":
		# Potion bottle: circle + neck
		draw.ellipse([6, 8, CELL - 7, CELL - 4], fill=fill, outline=outline)
		draw.rectangle([10, 4, 13, 8], fill=dark)
	elif category in ("material", "raw_material"):
		# Wood / log: rounded rectangle
		draw.rounded_rectangle([5, 6, CELL - 6, CELL - 7], 3, fill=fill, outline=outline)
		# Wood grain lines
		draw.line([(7, 11), (CELL - 7, 11)], fill=dark, width=1)
		draw.line([(7, 15), (CELL - 7, 15)], fill=dark, width=1)
	elif category == "ore":
		# Rock cluster
		draw.polygon([(8, 16), (12, 8), (CELL - 8, 12), (CELL - 6, CELL - 4), (4, CELL - 6)], fill=fill, outline=outline)
	elif category == "crystal":
		# Diamond / gem
		cx: int = CELL // 2
		cy: int = CELL // 2
		draw.polygon([(cx, 4), (CELL - 4, cy), (cx, CELL - 4), (4, cy)], fill=fill, outline=outline)
	elif category == "component":
		# Chip / circuit
		draw.rectangle([5, 5, CELL - 6, CELL - 6], fill=fill, outline=outline)
		draw.line([(8, 8), (CELL - 8, 8)], fill=dark, width=1)
		draw.line([(8, CELL - 8), (CELL - 8, CELL - 8)], fill=dark, width=1)
	elif category == "placeable":
		# House silhouette
		draw.polygon([(4, 16), (12, 6), (CELL - 4, 16), (CELL - 4, CELL - 4), (4, CELL - 4)], fill=fill, outline=outline)
	elif category == "station":
		# Worktable / crafting station: rectangle with a pot/burner on top
		# Table top
		draw.rectangle([4, 14, CELL - 5, CELL - 6], fill=fill, outline=outline)
		# Legs
		draw.rectangle([5, CELL - 6, 8, CELL - 4], fill=dark)
		draw.rectangle([CELL - 9, CELL - 6, CELL - 6, CELL - 4], fill=dark)
		# Pot / burner on top
		draw.ellipse([9, 6, CELL - 10, 14], fill=dark, outline=outline)
		# Steam wisp
		draw.line([(11, 4), (11, 6)], fill=outline, width=1)
		draw.line([(CELL - 12, 4), (CELL - 12, 6)], fill=outline, width=1)
	elif category == "tool":
		# Wrench / hammer
		draw.rectangle([10, 4, 14, CELL - 4], fill=fill, outline=outline)
		draw.ellipse([6, 8, 18, 16], fill=dark, outline=outline)
	elif category == "scrap":
		# Junk pile
		draw.polygon([(6, 14), (10, 8), (CELL - 8, 12), (CELL - 6, CELL - 6), (4, CELL - 8), (8, 18)], fill=fill, outline=outline)
	elif category == "ammo":
		# Bullet icon
		draw.ellipse([8, 4, CELL - 8, 16], fill=fill, outline=outline)
		draw.rectangle([10, 14, CELL - 10, CELL - 4], fill=dark, outline=outline)
	else:
		# Generic diamond
		cx2: int = CELL // 2
		cy2: int = CELL // 2
		draw.polygon([(cx2, 4), (CELL - 4, cy2), (cx2, CELL - 4), (4, cy2)], fill=fill, outline=outline)


def main() -> int:
	data_path: Path = ITEMS_JSON
	if not data_path.exists():
		print(f"missing {data_path}", file=sys.stderr)
		return 1
	with open(data_path) as f:
		data = json.load(f)
	items = data.get("items", [])
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	if not GDFILE.exists():
		GDFILE.write_text("# generated by tools/generate_item_icons.py\n")
	ok: int = 0
	for item in items:
		item_id: str = str(item.get("id", ""))
		if not item_id:
			continue
		img: Image = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
		draw = ImageDraw.Draw(img)
		_draw_icon(draw, item)
		out_path: Path = OUT_DIR / f"{item_id}.png"
		img.save(out_path, "PNG")
		ok += 1
	print(f"Done. ok={ok} ({len(items)} items)")
	return 0


if __name__ == "__main__":
	sys.exit(main())
