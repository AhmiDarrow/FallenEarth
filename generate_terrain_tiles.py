#!/usr/bin/env python3
"""Generate terrain tile assets for all biomes."""

import os
from PIL import Image, ImageDraw, ImageFilter
import random

TILE_SIZE = 24
ASSETS_DIR = "assets/tilesets"

BIOMES = {
    "ash_wastes": {
        "ground": (92, 64, 51),
        "debris": (132, 96, 71),
        "vegetation": (51, 140, 56),
        "blocked": (25, 23, 30),
        "rift": (158, 51, 199),
    },
    "rust_canyons": {
        "ground": (139, 90, 43),
        "debris": (160, 110, 60),
        "vegetation": (80, 120, 40),
        "blocked": (60, 40, 30),
        "rift": (200, 80, 50),
    },
    "neon_bogs": {
        "ground": (26, 58, 58),
        "debris": (40, 80, 70),
        "vegetation": (0, 212, 170),
        "blocked": (20, 40, 40),
        "rift": (184, 85, 255),
    },
    "scorched_plains": {
        "ground": (196, 168, 106),
        "debris": (138, 122, 90),
        "vegetation": (120, 140, 60),
        "blocked": (80, 70, 50),
        "rift": (220, 100, 60),
    },
    "ironwood_thicket": {
        "ground": (90, 74, 58),
        "debris": (107, 78, 53),
        "vegetation": (74, 122, 74),
        "blocked": (42, 42, 26),
        "rift": (184, 85, 255),
    },
    "glass_dunes": {
        "ground": (200, 232, 232),
        "debris": (180, 200, 210),
        "vegetation": (150, 200, 180),
        "blocked": (100, 120, 130),
        "rift": (100, 200, 255),
    },
    "corpse_fields": {
        "ground": (212, 197, 169),
        "debris": (180, 160, 140),
        "vegetation": (100, 130, 80),
        "blocked": (80, 70, 60),
        "rift": (150, 50, 100),
    },
    "stormspire_highlands": {
        "ground": (74, 90, 122),
        "debris": (90, 100, 110),
        "vegetation": (60, 100, 80),
        "blocked": (40, 50, 60),
        "rift": (100, 150, 255),
    },
    "toxin_marshes": {
        "ground": (59, 94, 59),
        "debris": (80, 100, 70),
        "vegetation": (0, 255, 159),
        "blocked": (30, 50, 30),
        "rift": (150, 50, 200),
    },
    "dead_city_outskirts": {
        "ground": (58, 48, 64),
        "debris": (80, 70, 90),
        "vegetation": (60, 80, 60),
        "blocked": (30, 25, 35),
        "rift": (184, 85, 255),
    },
}


def create_seamless_tile(base_color, noise_amount=15):
    """Create a seamless tile with subtle noise."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), base_color + (255,))
    pixels = img.load()
    
    for y in range(TILE_SIZE):
        for x in range(TILE_SIZE):
            r, g, b, a = pixels[x, y]
            noise = random.randint(-noise_amount, noise_amount)
            r = max(0, min(255, r + noise))
            g = max(0, min(255, g + noise))
            b = max(0, min(255, b + noise))
            pixels[x, y] = (r, g, b, a)
    
    return img


def create_debris_tile(base_color):
    """Create debris tile with rubble chunks."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), base_color + (255,))
    draw = ImageDraw.Draw(img)
    
    # Add random debris chunks
    for _ in range(random.randint(4, 8)):
        x = random.randint(2, TILE_SIZE - 8)
        y = random.randint(2, TILE_SIZE - 6)
        w = random.randint(3, 7)
        h = random.randint(3, 5)
        
        # Darker shade for debris
        r, g, b = base_color[:3]
        debris_color = (max(0, r - 30), max(0, g - 20), max(0, b - 10), 255)
        draw.rectangle([x, y, x + w, y + h], fill=debris_color)
    
    return img


def create_vegetation_tile(base_color):
    """Create vegetation tile with plant clusters."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), base_color + (255,))
    draw = ImageDraw.Draw(img)
    
    # Add vegetation circles
    for _ in range(random.randint(3, 6)):
        cx = random.randint(4, TILE_SIZE - 8)
        cy = random.randint(4, TILE_SIZE - 8)
        r = random.randint(3, 6)
        
        # Brighter green for vegetation
        veg_color = (30, 180, 50, 255)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=veg_color)
    
    return img


def create_blocked_tile(base_color):
    """Create blocked tile with X pattern."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), base_color + (255,))
    draw = ImageDraw.Draw(img)
    
    # Draw X pattern
    lighter = (min(255, base_color[0] + 40), min(255, base_color[1] + 35), min(255, base_color[2] + 45), 255)
    draw.line([0, 0, TILE_SIZE, TILE_SIZE], fill=lighter, width=2)
    draw.line([TILE_SIZE, 0, 0, TILE_SIZE], fill=lighter, width=2)
    
    return img


def create_rift_tile(base_color):
    """Create rift scar tile with energy cracks."""
    img = Image.new("RGBA", (TILE_SIZE, TILE_SIZE), base_color + (255,))
    draw = ImageDraw.Draw(img)
    
    # Add energy cracks
    for _ in range(random.randint(2, 4)):
        x1 = random.randint(2, TILE_SIZE - 4)
        y1 = random.randint(2, TILE_SIZE - 4)
        x2 = x1 + random.randint(4, 10)
        y2 = y1 + random.randint(-3, 3)
        
        # Bright energy color
        energy_color = (255, 100, 255, 255)
        draw.line([x1, y1, x2, y2], fill=energy_color, width=2)
    
    return img


def generate_biome_tiles(biome_name, colors):
    """Generate all terrain tiles for a biome."""
    biome_dir = os.path.join(ASSETS_DIR, biome_name)
    os.makedirs(biome_dir, exist_ok=True)
    
    # Ground (seamless)
    ground = create_seamless_tile(colors["ground"], 12)
    ground.save(os.path.join(biome_dir, "ground.png"))
    
    # Debris
    debris = create_debris_tile(colors["debris"])
    debris.save(os.path.join(biome_dir, "debris.png"))
    
    # Vegetation
    vegetation = create_vegetation_tile(colors["vegetation"])
    vegetation.save(os.path.join(biome_dir, "vegetation.png"))
    
    # Blocked
    blocked = create_blocked_tile(colors["blocked"])
    blocked.save(os.path.join(biome_dir, "blocked.png"))
    
    # Rift scar
    rift = create_rift_tile(colors["rift"])
    rift.save(os.path.join(biome_dir, "rift.png"))
    
    print(f"Generated tiles for {biome_name}")


def main():
    random.seed(42)  # Consistent results
    
    for biome_name, colors in BIOMES.items():
        generate_biome_tiles(biome_name, colors)
    
    print(f"\nGenerated terrain tiles for {len(BIOMES)} biomes in {ASSETS_DIR}/")


if __name__ == "__main__":
    main()
