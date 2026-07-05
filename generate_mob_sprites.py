#!/usr/bin/env python3
"""Generate simple mob sprite placeholders."""

import os
import json
from PIL import Image, ImageDraw

SPRITE_SIZE = 64
ASSETS_DIR = "assets/mobs"

# Read mob definitions
with open("data/mob_sprites.json", "r") as f:
    mob_data = json.load(f)

sprites = mob_data.get("sprites", {})

# Color palette
COLORS = {
    "sand": (196, 168, 106),
    "neon": (0, 212, 170),
    "iron": (90, 90, 90),
    "marsh": (59, 94, 59),
    "bone": (212, 197, 169),
    "toxic": (0, 255, 159),
    "stone": (122, 122, 122),
    "rust": (139, 90, 43),
    "ash": (92, 64, 51),
    "storm": (74, 90, 122),
}


def create_mob_sprite(mob_id, archetype, color_name):
    """Create a simple sprite for a mob."""
    img = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    base_color = COLORS.get(color_name, (128, 128, 128))
    
    # Simple shape based on archetype
    if archetype == "quadruped":
        # Body
        draw.ellipse([16, 24, 48, 44], fill=base_color + (255,))
        # Head
        draw.ellipse([36, 16, 48, 28], fill=base_color + (255,))
        # Legs
        draw.rectangle([18, 44, 22, 56], fill=base_color + (255,))
        draw.rectangle([26, 44, 30, 56], fill=base_color + (255,))
        draw.rectangle([34, 44, 38, 56], fill=base_color + (255,))
        draw.rectangle([42, 44, 46, 56], fill=base_color + (255,))
        
    elif archetype == "insectoid":
        # Body
        draw.ellipse([20, 20, 44, 44], fill=base_color + (255,))
        # Head
        draw.ellipse([28, 12, 36, 20], fill=base_color + (255,))
        # Legs (6)
        for i in range(6):
            y = 28 + i * 3
            draw.line([12, y, 20, y + 4], fill=base_color + (255,), width=2)
            draw.line([44, y, 52, y + 4], fill=base_color + (255,), width=2)
            
    elif archetype == "floater":
        # Body (jellyfish-like)
        draw.ellipse([16, 16, 48, 40], fill=base_color + (255,))
        # Tentacles
        for i in range(5):
            x = 20 + i * 6
            draw.line([x, 40, x - 2, 56], fill=base_color + (200,), width=2)
            
    elif archetype == "behemoth":
        # Large body
        draw.ellipse([8, 16, 56, 48], fill=base_color + (255,))
        # Head
        draw.ellipse([40, 8, 56, 24], fill=base_color + (255,))
        # Legs
        draw.rectangle([12, 48, 20, 60], fill=base_color + (255,))
        draw.rectangle([24, 48, 32, 60], fill=base_color + (255,))
        draw.rectangle([36, 48, 44, 60], fill=base_color + (255,))
        draw.rectangle([48, 48, 56, 60], fill=base_color + (255,))
        
    else:
        # Default: simple circle
        draw.ellipse([16, 16, 48, 48], fill=base_color + (255,))
    
    return img


def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)
    
    created = 0
    for mob_id, data in sprites.items():
        archetype = data.get("archetype", "default")
        color_range = data.get("color_range", {})
        color_name = color_range.get("base", "stone")
        
        sprite = create_mob_sprite(mob_id, archetype, color_name)
        sprite_path = os.path.join(ASSETS_DIR, f"{mob_id}.png")
        sprite.save(sprite_path)
        created += 1
    
    print(f"Created {created} mob sprites in {ASSETS_DIR}/")


if __name__ == "__main__":
    main()
