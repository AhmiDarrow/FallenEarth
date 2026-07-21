"""Regenerate water.png for each biome — solid per-biome color with wave highlight."""
import math
import os
from PIL import Image

TILESETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "tilesets")
TILE_SIZE = 32

BIOME_WATERS = {
    "ash_wastes":         (128, 140, 153),  # grey-blue
    "rust_canyons":       (191, 102, 51),   # rusty orange
    "neon_bogs":          (38,  204, 178),  # neon cyan
    "scorched_plains":    (140, 128, 77),   # brownish
    "ironwood_thicket":   (51,  153, 102),  # forest green
    "glass_dunes":        (140, 178, 230),  # light blue
    "corpse_fields":      (153, 64,  64),   # blood red
    "stormspire_highlands": (51, 77, 191),  # deep blue
    "toxin_marshes":      (115, 191, 51),   # toxic green
    "dead_city_outskirts":(102, 115, 140),  # grey
}

def make_water_tile(biome: str):
    biome_dir = os.path.join(TILESETS_DIR, biome)
    wcol = BIOME_WATERS.get(biome, (51, 115, 191))
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), (0, 0, 0, 0))
    pixels = img.load()
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            wave = math.sin(x * 0.8 + y * 0.4) * 0.06
            r = max(0, min(255, int(wcol[0] + wave * 255)))
            g = max(0, min(255, int(wcol[1] + wave * 0.6 * 255)))
            b = max(0, min(255, int(wcol[2] + wave * 0.3 * 255)))
            pixels[x, y] = (r, g, b, 255)
    out_path = os.path.join(biome_dir, "water.png")
    img.save(out_path)
    print(f"    {biome}/water.png -> ({wcol[0]},{wcol[1]},{wcol[2]})")

def main():
    biomes = sorted(os.listdir(TILESETS_DIR))
    for biome in biomes:
        biome_dir = os.path.join(TILESETS_DIR, biome)
        if not os.path.isdir(biome_dir):
            continue
        make_water_tile(biome)
    print(f"\nDone — 10 tiles regenerated with solid per-biome colors")

if __name__ == "__main__":
    main()
