#!/usr/bin/env python3
"""Phase 4 equipment sprite generator.

Produces per-tier PNGs for weapons (6 classes x 26 tiers = 156) and
armor (6 classes x 4 slots x 13 tiers = 312). Each sprite is a
procedural PIL image: a simple base shape (sword / pistol / rifle /
heavy_blade / focus / shield_hammer for weapons; helmet / chestplate /
leggings / boots for armor) with a per-tier color shift applied
(tier 0 = base, tier 25 = darkest / most saturated).

The data file `data/weapons.json` and `data/armor.json` carry the
sprite_base + tier color shift; this generator mirrors that logic
and writes one PNG per (class, tier) or (class, slot, tier).

Output:
  assets/sprites/equipment/<sprite_name>.png   (32x32 RGBA, NEAREST)
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
WEAPONS_JSON = ROOT / "data" / "weapons.json"
ARMOR_JSON = ROOT / "data" / "armor.json"
OUT_DIR = ROOT / "assets" / "sprites" / "equipment"
GDFILE = OUT_DIR / ".gdignore"

CELL = 32

CLASSES = ["Scavenger", "Technician", "Survivor", "Striker", "Riftbinder", "Warden"]
ARMOR_SLOTS = ["head", "chest", "legs", "boots"]


def _hsv_shift(base: dict, shift: dict, tier: int) -> tuple:
	"""Return (h, s, v) for the given tier, applying the per-tier
	shift deltas to the base color. Inputs are dicts with 'h', 's', 'v'."""
	h = float(base.get("h", 0.0))
	s = float(base.get("s", 0.0))
	v = float(base.get("v", 0.5))
	h_off = float(shift.get("hue_offset", [0.0])[tier]) if tier < len(shift.get("hue_offset", [0.0])) else 0.0
	s_off = float(shift.get("sat_offset", [0.0])[tier]) if tier < len(shift.get("sat_offset", [0.0])) else 0.0
	v_off = float(shift.get("value_offset", [0.0])[tier]) if tier < len(shift.get("value_offset", [0.0])) else 0.0
	return (
		(h + h_off) % 1.0,
		max(0.0, min(1.0, s + s_off)),
		max(0.0, min(1.0, v + v_off)),
	)


def _to_rgb(h: float, s: float, v: float) -> tuple:
	# Simple HSV -> RGB
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


def _draw_weapon(draw, kind: str, color: tuple) -> None:
	r, g, b = color
	dark = (max(0, r - 50), max(0, g - 50), max(0, b - 50))
	outline = (max(0, r - 100), max(0, g - 100), max(0, b - 100))
	if kind == "blade":
		# Diagonal blade
		draw.polygon([(8, 24), (10, 22), (24, 6), (26, 8)], fill=(r, g, b), outline=outline)
		draw.rectangle([14, 18, 18, 22], fill=(150, 100, 60), outline=outline)  # hilt
	elif kind == "pistol":
		draw.rectangle([10, 14, 24, 18], fill=(r, g, b), outline=outline)  # barrel
		draw.rectangle([8, 16, 14, 24], fill=(r, g, b), outline=outline)  # grip
		draw.rectangle([20, 12, 24, 14], fill=(255, 220, 100))  # sight
	elif kind == "rifle":
		draw.rectangle([4, 14, 26, 16], fill=(r, g, b), outline=outline)  # long barrel
		draw.rectangle([10, 16, 16, 22], fill=(r, g, b), outline=outline)  # stock
		draw.rectangle([18, 12, 22, 14], fill=(255, 220, 100))  # sight
	elif kind == "heavy_blade":
		# Big chunky blade
		draw.polygon([(6, 24), (8, 20), (22, 4), (26, 8), (24, 16)], fill=(r, g, b), outline=outline)
		draw.rectangle([12, 16, 16, 22], fill=(120, 80, 40), outline=outline)  # hilt
	elif kind == "focus":
		# Crystal focus / staff
		draw.rectangle([14, 14, 18, 30], fill=dark)  # staff
		draw.ellipse([8, 4, 24, 20], fill=(r, g, b), outline=outline)  # crystal
		draw.point([16, 12], fill=(255, 255, 255))
	elif kind == "shield_hammer":
		# Hammer head + handle
		draw.rectangle([4, 6, 16, 16], fill=(r, g, b), outline=outline)  # head
		draw.rectangle([8, 16, 12, 28], fill=(120, 80, 40), outline=outline)  # handle
		draw.rectangle([6, 4, 14, 6], fill=dark)  # top edge
	else:
		# Default: simple icon
		draw.ellipse([6, 6, 26, 26], fill=(r, g, b), outline=outline)


def _draw_armor(draw, slot: str, color: tuple) -> None:
	r, g, b = color
	dark = (max(0, r - 50), max(0, g - 50), max(0, b - 50))
	outline = (max(0, r - 100), max(0, g - 100), max(0, b - 100))
	if slot == "head":
		# Helmet
		draw.ellipse([6, 6, 26, 22], fill=(r, g, b), outline=outline)
		draw.rectangle([6, 18, 26, 24], fill=dark, outline=outline)
		draw.rectangle([12, 8, 20, 12], fill=(50, 50, 50))  # visor slot
	elif slot == "chest":
		# Chestplate
		draw.polygon([(4, 8), (28, 8), (24, 24), (8, 24)], fill=(r, g, b), outline=outline)
		draw.line([(16, 10), (16, 22)], fill=dark, width=2)
		draw.rectangle([8, 14, 24, 18], fill=dark)  # belt
	elif slot == "legs":
		# Leggings
		draw.rectangle([8, 6, 14, 26], fill=(r, g, b), outline=outline)
		draw.rectangle([18, 6, 24, 26], fill=(r, g, b), outline=outline)
		draw.rectangle([8, 4, 24, 8], fill=dark)  # belt
	elif slot == "boots":
		# Boots
		draw.rectangle([4, 16, 14, 28], fill=(r, g, b), outline=outline)
		draw.rectangle([18, 16, 28, 28], fill=(r, g, b), outline=outline)
		draw.rectangle([4, 12, 28, 16], fill=dark)  # calf


def _load_json(path: Path):
	if not path.exists():
		return None
	with open(path) as f:
		return json.load(f)


def _weapon_suffix(idx: int) -> str:
	# Same as in data/weapons.json
	suffixes = ["", "_ii", "_iii", "_iv", "_v", "_vi", "_vii", "_viii", "_ix", "_x",
		"_xi", "_xii", "_xiii", "_xiv", "_xv", "_xvi", "_xvii", "_xviii", "_xix", "_xx",
		"_xxi", "_xxii", "_xxiii", "_xxiv", "_xxv", "_xxvi"]
	return suffixes[idx] if idx < len(suffixes) else ""


def _armor_suffix(idx: int) -> str:
	suffixes = ["", "_ii", "_iii", "_iv", "_v", "_vi", "_vii", "_viii", "_ix", "_x",
		"_xi", "_xii", "_xiii"]
	return suffixes[idx] if idx < len(suffixes) else ""


def generate_weapons(weapons: dict, force: bool = False) -> list:
	classes = weapons.get("classes", {})
	tier_shift = weapons.get("tier_color_shift", {})
	tier_curve = weapons.get("tier_curve", {})
	results = []
	for class_id, c in classes.items():
		kind = c.get("weapon_kind", "blade")
		base_color = c.get("base_color", {"h": 0.0, "s": 0.0, "v": 0.5})
		sprite_base = c.get("sprite_base", "")
		max_tier = len(tier_curve.get("levels", [1]))
		for tier in range(max_tier):
			suffix = _weapon_suffix(tier)
			sprite_name = f"{sprite_base}{suffix}"
			out_path = OUT_DIR / f"{sprite_name}.png"
			if out_path.exists() and not force:
				results.append(f"skip {sprite_name}")
				continue
			h, s, v = _hsv_shift(base_color, tier_shift, tier)
			color = _to_rgb(h, s, v)
			img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
			draw = ImageDraw.Draw(img)
			_draw_weapon(draw, kind, color)
			img.save(out_path, "PNG")
			results.append(f"ok {sprite_name}")
	return results


def generate_armor(armor: dict, force: bool = False) -> list:
	classes = armor.get("classes", {})
	slots = armor.get("slots", {})
	tier_shift = armor.get("tier_color_shift", {})
	tier_curve = armor.get("tier_curve", {})
	results = []
	for class_id, c in classes.items():
		sprite_base = c.get("sprite_base", "")
		max_tier = len(tier_curve.get("levels", [1]))
		for slot in ARMOR_SLOTS:
			base_color = slots.get(slot, {}).get("base_color", {"h": 0.0, "s": 0.0, "v": 0.5})
			for tier in range(max_tier):
				suffix = _armor_suffix(tier)
				sprite_name = f"{sprite_base}_{slot}{suffix}"
				out_path = OUT_DIR / f"{sprite_name}.png"
				if out_path.exists() and not force:
					results.append(f"skip {sprite_name}")
					continue
				h, s, v = _hsv_shift(base_color, tier_shift, tier)
				color = _to_rgb(h, s, v)
				img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
				draw = ImageDraw.Draw(img)
				_draw_armor(draw, slot, color)
				img.save(out_path, "PNG")
				results.append(f"ok {sprite_name}")
	return results


def main() -> int:
	p = argparse.ArgumentParser()
	p.add_argument("--force", action="store_true")
	args = p.parse_args()
	weapons = _load_json(WEAPONS_JSON) or {}
	armor = _load_json(ARMOR_JSON) or {}
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	if not GDFILE.exists():
		GDFILE.write_text("# generated by tools/generate_equipment_sprites.py\n")
	w = generate_weapons(weapons, args.force)
	a = generate_armor(armor, args.force)
	ok = sum(1 for r in w + a if r.startswith("ok"))
	skip = sum(1 for r in w + a if r.startswith("skip"))
	print(f"Done. ok={ok} skip={skip} (weapons: {len(w)}, armor: {len(a)})")
	return 0


if __name__ == "__main__":
	sys.exit(main())
