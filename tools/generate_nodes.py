#!/usr/bin/env python3
"""Generate resource node sprites via PIL (procedural, no API calls).

Saves 24x24 PNGs to assets/sprites/resource_nodes/{sprite_id}.png for
every entry in data/resource_nodes.json (trees, formations, ore, crystals,
fauna) plus a generic placeholder. Idempotent: skips existing files.
Use --force to overwrite.

Style: each sprite is a small shape on a transparent background, with
a per-category color palette. Designed to read at native 24x24 when
rendered at NEAREST filter in-game.
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
NODES_JSON = ROOT / "data" / "resource_nodes.json"
OUT_DIR = ROOT / "assets" / "sprites" / "resource_nodes"
GDFILE = OUT_DIR / ".gdignore"

CELL = 32

# Per-category palette: {category: (fill_rgb, accent_rgb, outline_rgb)}
CATEGORY_PALETTES = {
    "trees":       (( 92,  70,  48), ( 60,  90,  44), ( 30,  20,  10)),
    "formations":  ((112, 100,  88), ( 70,  60,  48), ( 40,  32,  24)),
    "ore":         ((140, 130, 120), ( 90,  70,  50), ( 40,  30,  20)),
    "crystals":    ((150, 180, 220), (180, 140, 220), ( 60,  40,  90)),
    "fauna":       ((120, 120, 110), (170, 150,  90), ( 30,  20,  10)),
}


def _draw_tree(draw: ImageDraw.ImageDraw, fill, accent, outline, cell: int) -> None:
    # Trunk: 3px wide vertical
    tw = 3
    th = cell // 2
    tx = (cell - tw) // 2
    ty = cell - th
    draw.rectangle([tx, ty, tx + tw - 1, cell - 1], fill=outline)
    # Canopy: blob with a couple of highlight pixels
    cx, cy = cell // 2, cell // 3
    r = cell // 3
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline)
    # Highlight
    draw.point((cx - 2, cy - 1), fill=accent)


def _draw_formation(draw: ImageDraw.ImageDraw, fill, accent, outline, cell: int) -> None:
    # Stacked rectangles: a 16x6 base + 10x6 mid + 6x4 top
    draw.rectangle([2, cell - 6, cell - 3, cell - 1], fill=fill, outline=outline)
    draw.rectangle([5, cell - 12, cell - 6, cell - 7], fill=accent, outline=outline)
    draw.rectangle([8, cell - 16, cell - 9, cell - 13], fill=outline)


def _draw_ore(draw: ImageDraw.ImageDraw, fill, accent, outline, cell: int) -> None:
    # Cluster of 3 rocks
    draw.ellipse([3,  cell - 14, 11, cell -  6], fill=fill, outline=outline)
    draw.ellipse([10, cell - 11, 18, cell -  4], fill=accent, outline=outline)
    draw.ellipse([6,  cell -  6, 14, cell -  1], fill=fill, outline=outline)
    # Highlight
    draw.point((5, cell - 11), fill=(255, 255, 255))


def _draw_crystal(draw: ImageDraw.ImageDraw, fill, accent, outline, cell: int) -> None:
    # Diamond / gem
    cx = cell // 2
    pts = [(cx, 2), (cell - 3, cell // 2), (cx, cell - 2), (3, cell // 2)]
    draw.polygon(pts, fill=fill, outline=outline)
    # Inner facet
    inner = [(cx, 6), (cell - 6, cell // 2), (cx, cell - 6), (6, cell // 2)]
    draw.polygon(inner, fill=accent)


def _draw_fauna(draw: ImageDraw.ImageDraw, fill, accent, outline, cell: int) -> None:
    # Blob body with eyes
    body_w = 14
    body_h = 8
    bx = (cell - body_w) // 2
    by = (cell - body_h) // 2
    draw.rounded_rectangle([bx, by, bx + body_w - 1, by + body_h - 1],
                            radius=2, fill=fill, outline=outline)
    # Eyes
    draw.point((bx + 4, by + 3), fill=(255, 255, 255))
    draw.point((bx + 9, by + 3), fill=(255, 255, 255))
    draw.point((bx + 4, by + 3), fill=outline)
    draw.point((bx + 9, by + 3), fill=outline)
    # Highlight
    draw.point((bx + 6, by + 1), fill=accent)


RENDERERS = {
    "trees": _draw_tree,
    "formations": _draw_formation,
    "ore": _draw_ore,
    "crystals": _draw_crystal,
    "fauna": _draw_fauna,
}


def render(category: str, sprite_id: str, force: bool) -> str:
    out_path = OUT_DIR / f"{sprite_id}.png"
    if out_path.exists() and not force:
        return "skip"
    pal = CATEGORY_PALETTES.get(category, ((128, 128, 128), (180, 180, 180), (20, 20, 20)))
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    RENDERERS[category](draw, pal[0], pal[1], pal[2], CELL)
    img.save(out_path, "PNG")
    return "ok"


def collect_node_ids(force_biome: str | None = None) -> list[tuple[str, str]]:
    """Return [(category, sprite_id), ...] from resource_nodes.json."""
    if not NODES_JSON.exists():
        return []
    data = json.loads(NODES_JSON.read_text())
    out: list[tuple[str, str]] = []
    biomes = data.get("biomes", {})
    for biome_name, biome in biomes.items():
        if force_biome and biome_name != force_biome:
            continue
        for category in ("trees", "formations", "ore", "crystals", "fauna"):
            for entry in biome.get(category, []):
                sprite_id = entry.get("sprite")
                if sprite_id:
                    out.append((category, sprite_id))
    return out


def write_gdignore() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if not GDFILE.exists():
        GDFILE.write_text("# generated by tools/generate_nodes.py\n")


def remove_gdignore() -> None:
    if GDFILE.exists():
        GDFILE.unlink()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--biome", help="only this biome (e.g. 'Ash Wastes')")
    p.add_argument("--force", action="store_true")
    args = p.parse_args()

    ids = collect_node_ids(args.biome)
    print(f"Rendering {len(ids)} unique node sprites...")
    write_gdignore()
    try:
        ok = skip = fail = 0
        seen: set[str] = set()
        for category, sprite_id in ids:
            if sprite_id in seen:
                continue
            seen.add(sprite_id)
            try:
                status = render(category, sprite_id, args.force)
            except Exception as e:
                print(f"  FAIL {category}/{sprite_id}: {e}")
                fail += 1
                continue
            if status == "ok":
                ok += 1
                print(f"  ok   {category}/{sprite_id}.png")
            else:
                skip += 1
        # Also write a generic placeholder
        generic_path = OUT_DIR / "_generic.png"
        if not generic_path.exists() or args.force:
            img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)
            draw.ellipse([3, 3, CELL - 4, CELL - 4], fill=(140, 140, 140), outline=(20, 20, 20))
            draw.point((CELL // 2, CELL // 2), fill=(255, 255, 255))
            img.save(generic_path, "PNG")
            ok += 1
            print(f"  ok   _generic.png (fallback)")
        print(f"Done. ok={ok} skip={skip} fail={fail}")
        return 0 if fail == 0 else 2
    finally:
        remove_gdignore()


if __name__ == "__main__":
    sys.exit(main())
