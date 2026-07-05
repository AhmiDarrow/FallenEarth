#!/usr/bin/env python3
"""Generate mob sprite placeholders with shading + outline so they read against terrain."""

import os
import json
from PIL import Image, ImageDraw

SPRITE_SIZE = 64
ASSETS_DIR = "assets/mobs"
OUTLINE_WIDTH = 2

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


def _shade(rgb, factor):
    """Multiply each channel by `factor` (0.0 black, 1.0 same, >1.0 brighter)."""
    r, g, b = rgb
    return (
        max(0, min(255, int(r * factor))),
        max(0, min(255, int(g * factor))),
        max(0, min(255, int(b * factor))),
    )


def _draw_outline(draw, shape_fn, color, width=OUTLINE_WIDTH):
    """Draw a shape with a darker outline by rendering it slightly larger first."""
    outline = _shade(color, 0.25)
    shape_fn(draw, outline, 0, 0, width)
    shape_fn(draw, color, 0, 0, 0)


def _quadruped(draw, color, ox=0, oy=0, grow=0):
    # Body
    draw.ellipse([16 - grow + ox, 24 - grow + oy, 48 + grow + ox, 44 + grow + oy], fill=color + (255,))
    # Head
    draw.ellipse([36 - grow + ox, 16 - grow + oy, 48 + grow + ox, 28 + grow + oy], fill=color + (255,))
    # Eye on head
    eye = _shade(color, 0.15)
    draw.ellipse([42 + ox, 20 + oy, 46 + ox, 24 + oy], fill=eye + (255,))
    # Legs
    for lx in [18, 26, 34, 42]:
        draw.rectangle([lx - grow + ox, 44 - grow + oy, lx + 4 + grow + ox, 56 + grow + oy], fill=color + (255,))


def _insectoid(draw, color, ox=0, oy=0, grow=0):
    # Body
    draw.ellipse([20 - grow + ox, 20 - grow + oy, 44 + grow + ox, 44 + grow + oy], fill=color + (255,))
    # Head
    draw.ellipse([28 - grow + ox, 12 - grow + oy, 36 + grow + ox, 20 + grow + oy], fill=color + (255,))
    # Mandibles
    draw.polygon([(28 + ox, 16 + oy), (24 + ox, 12 + oy), (24 + ox, 16 + oy)], fill=color + (255,))
    draw.polygon([(36 + ox, 16 + oy), (40 + ox, 12 + oy), (40 + ox, 16 + oy)], fill=color + (255,))
    # Legs (6 per side, 3 visible)
    for i in range(3):
        y = 24 + i * 6
        draw.line([12 + ox, y + oy, 20 + ox, y + 4 + oy], fill=color + (255,), width=2)
        draw.line([44 + ox, y + oy, 52 + ox, y + 4 + oy], fill=color + (255,), width=2)
    # Body segments
    seg = _shade(color, 0.55)
    draw.line([20 + ox, 32 + oy, 44 + ox, 32 + oy], fill=seg + (200,), width=1)


def _floater(draw, color, ox=0, oy=0, grow=0):
    # Dome
    draw.ellipse([16 - grow + ox, 16 - grow + oy, 48 + grow + ox, 40 + grow + oy], fill=color + (255,))
    # Inner glow
    glow = _shade(color, 1.4)
    draw.ellipse([22 + ox, 20 + oy, 42 + ox, 32 + oy], fill=glow + (180,))
    # Tentacles
    for i in range(5):
        x = 20 + i * 6 + ox
        draw.line([x, 40 + oy, x - 2, 56 + oy], fill=color + (220,), width=2)


def _behemoth(draw, color, ox=0, oy=0, grow=0):
    # Large body
    draw.ellipse([8 - grow + ox, 16 - grow + oy, 56 + grow + ox, 48 + grow + oy], fill=color + (255,))
    # Head
    draw.ellipse([40 - grow + ox, 8 - grow + oy, 56 + grow + ox, 24 + grow + oy], fill=color + (255,))
    # Eye
    eye = _shade(color, 0.1)
    draw.ellipse([48 + ox, 14 + oy, 52 + ox, 18 + oy], fill=eye + (255,))
    # Legs
    for lx in [12, 24, 36, 48]:
        draw.rectangle([lx - grow + ox, 48 - grow + oy, lx + 8 + grow + ox, 60 + grow + oy], fill=color + (255,))
    # Back spikes
    spike = _shade(color, 0.4)
    for sx in [18, 28, 38]:
        draw.polygon([(sx + ox, 16 + oy), (sx + 4 + ox, 8 + oy), (sx + 8 + ox, 16 + oy)], fill=spike + (255,))


def _mechanical(draw, color, ox=0, oy=0, grow=0):
    # Boxy body
    draw.rectangle([16 - grow + ox, 18 - grow + oy, 48 + grow + ox, 46 + grow + oy], fill=color + (255,))
    # Visor
    visor = _shade(color, 1.5)
    draw.rectangle([20 + ox, 22 + oy, 44 + ox, 30 + oy], fill=visor + (255,))
    # Eye
    eye = (0, 255, 200, 255)
    draw.ellipse([30 + ox, 24 + oy, 34 + ox, 28 + oy], fill=eye)
    # Legs (hydraulic)
    for lx in [20, 40]:
        draw.rectangle([lx + ox, 46 + oy, lx + 4 + ox, 58 + oy], fill=color + (255,))
    # Antennae
    draw.line([24 + ox, 18 + oy, 22 + ox, 10 + oy], fill=color + (255,), width=2)
    draw.line([40 + ox, 18 + oy, 42 + ox, 10 + oy], fill=color + (255,), width=2)


def _aberrant(draw, color, ox=0, oy=0, grow=0):
    # Distorted mass
    draw.ellipse([14 - grow + ox, 18 - grow + oy, 50 + grow + ox, 46 + grow + oy], fill=color + (255,))
    # Tendrils
    for i in range(6):
        x = 16 + i * 5 + ox
        draw.line([x, 46 + oy, x - 4 + (i % 2) * 6, 60 + oy], fill=color + (200,), width=2)
    # Eye cluster
    eye = _shade(color, 0.1)
    for ex, ey in [(26, 28), (32, 24), (38, 28), (30, 34), (38, 34)]:
        draw.ellipse([ex + ox, ey + oy, ex + 4 + ox, ey + 4 + oy], fill=eye + (255,))


def create_mob_sprite(mob_id, archetype, color_name):
    """Create a sprite for a mob with dark outline + shaded body parts."""
    img = Image.new("RGBA", (SPRITE_SIZE, SPRITE_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    base_color = COLORS.get(color_name, (128, 128, 128))

    if archetype == "quadruped":
        shape_fn = _quadruped
    elif archetype == "insectoid":
        shape_fn = _insectoid
    elif archetype == "floater":
        shape_fn = _floater
    elif archetype == "behemoth":
        shape_fn = _behemoth
    elif archetype == "mechanical":
        shape_fn = _mechanical
    elif archetype == "aberrant":
        shape_fn = _aberrant
    else:
        shape_fn = _quadruped

    # Outline pass: draw the shape inflated by OUTLINE_WIDTH in a dark color,
    # then re-draw at normal size on top. Result: dark border around the whole mob.
    outline_color = _shade(base_color, 0.25)
    shape_fn(draw, outline_color, 0, 0, OUTLINE_WIDTH)
    shape_fn(draw, base_color, 0, 0, 0)
    return img


def main():
    os.makedirs(ASSETS_DIR, exist_ok=True)

    created = 0
    skipped = 0
    for mob_id, data in sprites.items():
        archetype = data.get("archetype", "default")
        color_range = data.get("color_range", {})
        color_name = color_range.get("base", "stone")

        sprite = create_mob_sprite(mob_id, archetype, color_name)
        sprite_path = os.path.join(ASSETS_DIR, f"{mob_id}.png")
        sprite.save(sprite_path)
        created += 1

    # Mobs in mobs.json that don't have a sprite definition get a default quadruped
    # based on their visual_preset / archetype. Scan mobs.json for completeness.
    mobs_json_path = "data/mobs.json"
    if os.path.exists(mobs_json_path):
        with open(mobs_json_path, "r") as f:
            mobs = json.load(f)
        for category in ["neutral", "aggressive"]:
            for m in mobs.get("overworld", {}).get(category, []):
                mid = m.get("sprite_id", "")
                if not mid or not os.path.exists(os.path.join(ASSETS_DIR, f"{mid}.png")):
                    if mid:
                        preset = m.get("visual_preset", "beast_quadruped")
                        archetype_map = {
                            "beast_quadruped": "quadruped",
                            "beast_insectoid": "insectoid",
                            "beast_floater": "floater",
                            "beast_behemoth": "behemoth",
                            "mechanical_default": "mechanical",
                            "rift_void": "aberrant",
                            "rift_life": "aberrant",
                            "rift_energy": "aberrant",
                        }
                        archetype = archetype_map.get(preset, "quadruped")
                        sprite = create_mob_sprite(mid, archetype, "stone")
                        sprite_path = os.path.join(ASSETS_DIR, f"{mid}.png")
                        sprite.save(sprite_path)
                        created += 1
        for m in mobs.get("rift_only", []):
            mid = m.get("sprite_id", "")
            if mid and not os.path.exists(os.path.join(ASSETS_DIR, f"{mid}.png")):
                sprite = create_mob_sprite(mid, "aberrant", "stone")
                sprite_path = os.path.join(ASSETS_DIR, f"{mid}.png")
                sprite.save(sprite_path)
                created += 1

    print(f"Created {created} mob sprites in {ASSETS_DIR}/")


if __name__ == "__main__":
    main()
