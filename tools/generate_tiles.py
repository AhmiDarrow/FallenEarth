#!/usr/bin/env python3
"""Generate 24x24 terrain tiles for all 10 biomes procedurally.

Pixflux reliably produces icon-style illustrations even with strict
"no focal point" prompts — its weights steer it toward detailed scenes. For
cohesive world backgrounds we want flat, low-contrast tileable surfaces, so
this generator builds each tile deterministically with PIL using a per-biome
palette + sparse pixel noise + (for rift_scar) thin crack lines.

Output: assets/tilesets/{biome_dir}/{terrain}.png — 24x24 RGBA8 PNG.

This is a BUILD-TIME tool. There is no procedural drawing in the engine
runtime — the TileSetService loads these pre-rendered PNGs.

Idempotent. Use --force to overwrite.
"""

import argparse
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
TILESET_DIR = ROOT / "assets" / "tilesets"
GDFILE = TILESET_DIR / ".gdignore"

CELL = 24

# Per-biome palette: (ground, debris, vegetation, rock, rift_accent, ground_alt).
# rock is the color of boulder/rock overlays in the BLOCKED tile, drawn on
# top of the ground base so blocked cells look like rocks embedded in the
# ground rather than a separate dark slab. rift_accent is the bright crack
# color for rift_scar (warm orange-amber, like a glowing earth crack).
PALETTES = {
    "ash_wastes":          ((148, 130, 108), (110, 96, 80),  (104, 122, 78), (96, 84, 72),  (220, 140, 80),  (158, 140, 118)),
    "rust_canyons":        ((148, 96, 72),   (118, 78, 60),  (98, 100, 68),  (108, 70, 52), (220, 130, 80),  (138, 86, 64)),
    "neon_bogs":           ((72, 84, 64),    (60, 72, 56),   (62, 90, 60),   (50, 58, 48),  (220, 180, 110), (82, 92, 70)),
    "scorched_plains":     ((186, 168, 132), (152, 136, 108),(132, 138, 88), (140, 124, 100),(220, 150, 80),  (176, 158, 124)),
    "ironwood_thicket":    ((86, 76, 60),    (72, 64, 50),   (74, 88, 58),   (66, 60, 50),  (220, 170, 100), (96, 86, 70)),
    "glass_dunes":         ((196, 184, 158), (172, 160, 134),(154, 152, 116),(150, 140, 120),(220, 180, 120), (186, 174, 148)),
    "corpse_fields":       ((118, 110, 96),  (98, 92, 80),   (94, 100, 78),  (86, 80, 72),  (220, 140, 90),  (128, 120, 104)),
    "stormspire_highlands":((102, 100, 96),  (88, 86, 82),   (94, 104, 86),  (80, 78, 76),  (220, 170, 110), (112, 110, 104)),
    "toxin_marshes":       ((102, 110, 70),  (88, 96, 64),   (90, 110, 68),  (76, 80, 60),  (220, 180, 110), (112, 118, 80)),
    "dead_city_outskirts": ((100, 100, 100), (86, 86, 86),   (92, 102, 90),  (78, 78, 78),  (220, 150, 100), (108, 108, 108)),
}


def _seeded_rng(biome: str, terrain: str, x: int, y: int) -> random.Random:
    s = f"{biome}|{terrain}|{x}|{y}"
    return random.Random(s)


def _clamp(v: int) -> int:
    return max(0, min(255, v))


def _shift(color: tuple[int, int, int], amount: int) -> tuple[int, int, int]:
    return (_clamp(color[0] + amount), _clamp(color[1] + amount), _clamp(color[2] + amount))


def _fill_flat(color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGBA", (CELL, CELL), (*color, 255))


def _fill_blob(base: tuple[int, int, int], alt: tuple[int, int, int]) -> Image.Image:
    """Flat color with several soft multi-pixel patches of a slightly
    different shade, so the ground reads as natural terrain variation
    rather than a uniform test pattern. Patches are 2-3px wide and placed
    deterministically from a seeded RNG."""
    img = _fill_flat(base)
    draw = ImageDraw.Draw(img)
    rng = _seeded_rng("__blob__", str(base), 0, 0)
    n_patches = rng.randint(3, 6)
    for _ in range(n_patches):
        cx = rng.randrange(1, CELL - 1)
        cy = rng.randrange(1, CELL - 1)
        w = rng.randint(2, 3)
        h = rng.randint(2, 3)
        # Use the alt color, optionally a touch lighter or darker
        shift = rng.choice([-4, -2, 2, 4])
        patch = _shift(alt, shift) if rng.random() < 0.6 else _shift(base, shift)
        draw.rectangle(
            [cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2],
            fill=(*patch, 255),
        )
    return img


def _fill_speckle(base: tuple[int, int, int], alt: tuple[int, int, int], density: float) -> Image.Image:
    """Blob base + sparse single-pixel speckles of a second shade."""
    img = _fill_blob(base, alt)
    px = img.load()
    rng = _seeded_rng("__speckle__", str(base), 0, 0)
    for y in range(CELL):
        for x in range(CELL):
            if rng.random() < density:
                shift = rng.choice([-12, -8, -4, 4, 8, 12])
                r, g, b = _shift(base, shift)
                px[x, y] = (r, g, b, 255)
    return img


def _fill_ground(pal: tuple) -> Image.Image:
    """The most common tile. Earthy base with soft multi-pixel patches of a
    slightly different shade + sparse single-pixel speckles. Reads as
    natural terrain variation across 512x512 cells."""
    return _fill_speckle(pal[0], pal[5], density=0.10)


def _fill_debris(pal: tuple) -> Image.Image:
    """Same earthy base as ground + more obvious dark patches (suggesting
    rubble or rocks) and slightly heavier speckle."""
    img = _fill_blob(pal[0], pal[5])
    px = img.load()
    rng = _seeded_rng("__debris__", str(pal[1]), 0, 0)
    n = rng.randint(2, 4)
    for _ in range(n):
        cx = rng.randrange(2, CELL - 2)
        cy = rng.randrange(2, CELL - 2)
        w = rng.randint(2, 3)
        h = rng.randint(2, 3)
        r, g, b = _shift(pal[1], rng.choice([-4, 4]))
        for dy in range(-h // 2, h // 2 + 1):
            for dx in range(-w // 2, w // 2 + 1):
                xx, yy = cx + dx, cy + dy
                if 0 <= xx < CELL and 0 <= yy < CELL:
                    px[xx, yy] = (r, g, b, 255)
    return img


def _fill_vegetation(pal: tuple) -> Image.Image:
    """Ground base + a few darker green-brown patches (tufts of grass or
    small scrub) and a sparse dusting of green pixels."""
    img = _fill_blob(pal[0], pal[5])
    px = img.load()
    rng = _seeded_rng("__veg__", str(pal[2]), 0, 0)
    n = rng.randint(2, 4)
    for _ in range(n):
        cx = rng.randrange(2, CELL - 2)
        cy = rng.randrange(2, CELL - 2)
        w = rng.randint(2, 3)
        h = rng.randint(2, 3)
        r, g, b = _shift(pal[2], rng.choice([-6, -3, 3, 6]))
        for dy in range(-h // 2, h // 2 + 1):
            for dx in range(-w // 2, w // 2 + 1):
                xx, yy = cx + dx, cy + dy
                if 0 <= xx < CELL and 0 <= yy < CELL:
                    px[xx, yy] = (r, g, b, 255)
    return img


def _fill_blocked(pal: tuple) -> Image.Image:
    """Reads as a rock or boulder embedded in the ground. Same ground base
    as the surrounding cells, with one or two large rock-coloured patches on
    top. The cell still has collision; the visual just blends with the
    terrain instead of looking like a separate dark square."""
    img = _fill_speckle(pal[0], pal[5], density=0.06)
    draw = ImageDraw.Draw(img)
    rng = _seeded_rng("__blocked__", str(pal[3]), 0, 0)
    # One larger rock patch (3-4px) plus one smaller one.
    n = rng.randint(1, 2)
    for _ in range(n):
        cx = rng.randrange(3, CELL - 3)
        cy = rng.randrange(3, CELL - 3)
        w = rng.randint(3, 4)
        h = rng.randint(3, 4)
        shift = rng.choice([-6, -3, 3])
        r, g, b = _shift(pal[3], shift)
        draw.rectangle(
            [cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2],
            fill=(r, g, b, 255),
        )
    return img


def _fill_rift_scar(pal: tuple) -> Image.Image:
    """A glowing crack in the ground. Same ground base as surrounding cells,
    with a clear bright crack (warm amber accent) crossing the tile, a soft
    darker fracture halo around the crack to suggest scorched/burnt earth,
    and a few minor dark fracture lines. Reads as a tear in the ground, not
    a black square with a line on it."""
    img = _fill_speckle(pal[0], pal[5], density=0.06)
    draw = ImageDraw.Draw(img)
    rng = _seeded_rng("__rift__", str(pal[4]), 0, 0)
    # Main bright crack (diagonal across the tile)
    x0 = rng.choice([0, rng.randrange(2, CELL - 2)])
    y0 = rng.randrange(2, CELL - 2) if x0 != 0 else rng.choice([0, CELL - 1])
    x1 = CELL - 1 if x0 != CELL - 1 else rng.randrange(2, CELL - 2)
    y1 = rng.randrange(2, CELL - 2) if y0 not in (0, CELL - 1) else rng.choice([0, CELL - 1])
    if y1 == y0:
        y1 = (y0 + 4) % CELL
    # Scorched halo (slightly darker line just above the bright crack)
    halo_color = _shift(pal[0], -24)
    draw.line([(x0, y0), (x1, y1)], fill=(*halo_color, 255), width=3)
    # Bright amber crack on top
    draw.line([(x0, y0), (x1, y1)], fill=(*pal[4], 255), width=1)
    # 1-2 minor dark fracture lines
    n = rng.randint(1, 2)
    for _ in range(n):
        fx0 = rng.randrange(0, CELL)
        fy0 = rng.randrange(0, CELL)
        fx1 = _clamp(fx0 + rng.choice([-1, 1]) * rng.randint(3, 6))
        fy1 = _clamp(fy0 + rng.choice([-1, 1]) * rng.randint(3, 6))
        draw.line([(fx0, fy0), (fx1, fy1)], fill=(*_shift(pal[0], -16), 255), width=1)
    return img


RENDERERS = {
    "ground":     lambda pal: _fill_ground(pal),
    "debris":     lambda pal: _fill_debris(pal),
    "vegetation": lambda pal: _fill_vegetation(pal),
    "blocked":    lambda pal: _fill_blocked(pal),
    "rift_scar":  lambda pal: _fill_rift_scar(pal),
}


def render(biome_dir: str, force: bool) -> tuple[str, list[str]]:
    pal = PALETTES.get(biome_dir)
    if pal is None:
        return biome_dir, [f"unknown biome {biome_dir}"]
    out_dir = TILESET_DIR / biome_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    results: list[str] = []
    for terrain, fn in RENDERERS.items():
        out_path = out_dir / f"{terrain}.png"
        if out_path.exists() and not force:
            results.append(f"skip {terrain}")
            continue
        img = fn(pal)
        img.save(out_path, "PNG")
        results.append(f"ok {terrain}")
    return biome_dir, results


def write_gdignore():
    TILESET_DIR.mkdir(parents=True, exist_ok=True)
    if not GDFILE.exists():
        GDFILE.write_text("# generated by tools/generate_tiles.py\n")


def remove_gdignore():
    if GDFILE.exists():
        GDFILE.unlink()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--biome", help="only this biome dir (e.g. ash_wastes)")
    p.add_argument("--force", action="store_true", help="overwrite existing tiles")
    args = p.parse_args()

    biomes = list(PALETTES.keys())
    if args.biome:
        if args.biome not in biomes:
            print(f"Unknown biome: {args.biome}. Available: {biomes}")
            return 1
        biomes = [args.biome]

    write_gdignore()
    try:
        total_ok = total_skip = 0
        for b in biomes:
            _, results = render(b, args.force)
            line = f"{b}: " + ", ".join(results)
            print(line)
            for r in results:
                if r.startswith("ok"):
                    total_ok += 1
                elif r.startswith("skip"):
                    total_skip += 1
        print(f"Done. ok={total_ok} skip={total_skip} of {len(biomes) * 5}")
        return 0
    finally:
        remove_gdignore()


if __name__ == "__main__":
    sys.exit(main())
