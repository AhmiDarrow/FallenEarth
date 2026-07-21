#!/usr/bin/env python3
"""Biome rule engine for Fallen Earth terrain generation.

Maps the 10 game biomes from data/biomes.json into configs consumable by
terrain_generator.py and WorldGenerator.py.
"""

from dataclasses import dataclass, field
from typing import Literal

# Terrain-class literals shared across the pipeline.
BiomeCategory = Literal["wasteland", "canyon", "wetland", "plain", "forest",
                        "desert", "field", "highland", "marsh", "ruins"]


@dataclass(frozen=True)
class BiomeConfig:
    name: str
    category: str
    avg_height: float
    height_variance: float
    water_temp_modifier: float
    terrain_features: list[str]
    palette_index: int
    difficulty_tier: int = 1
    rift_chance: float = 0.0
    preferred_races: tuple[str, ...] = ()


# ── 10 game biomes from data/biomes.json ───────────────────────────────────
# Slugs are the lowercase-underscore form of the biome name.
BIOME_CONFIGS: dict[str, BiomeConfig] = {
    "ash_wastes": BiomeConfig(
        "Ash Wastes", "wasteland", 0.50, 0.25, 1.5,
        ["toxic_dust", "cracked_earth", "wind_swept_scrub"], 0,
        difficulty_tier=2, rift_chance=0.25,
        preferred_races=("mutant", "human"),
    ),
    "rust_canyons": BiomeConfig(
        "Rust Canyons", "canyon", 0.75, 0.35, 1.2,
        ["deep_canyons", "rusted_hulks", "unstable_bridges",
         "high_rift_density"], 1,
        difficulty_tier=4, rift_chance=0.70,
        preferred_races=("human", "cyborg"),
    ),
    "neon_bogs": BiomeConfig(
        "Neon Bogs", "wetland", 0.35, 0.20, 1.8,
        ["glowing_wetlands", "sunken_ruins", "power_lines", "fog_pockets"], 2,
        difficulty_tier=3, rift_chance=0.40,
        preferred_races=("sentientai", "vesperid"),
    ),
    "scorched_plains": BiomeConfig(
        "Scorched Plains", "plain", 0.45, 0.30, 2.2,
        ["cracked_earth", "heat_haze", "sun_baked_ruins",
         "sparse_vegetation"], 3,
        difficulty_tier=1, rift_chance=0.12,
        preferred_races=("mutant", "revenant"),
    ),
    "ironwood_thicket": BiomeConfig(
        "Ironwood Thicket", "forest", 0.65, 0.28, 1.0,
        ["dense_metallic_forest", "vine_canopy", "magnetic_nodes",
         "twisted_trees"], 4,
        difficulty_tier=3, rift_chance=0.30,
        preferred_races=("vesperid", "chthon"),
    ),
    "glass_dunes": BiomeConfig(
        "Glass Dunes", "desert", 0.55, 0.30, 2.8,
        ["singing_dunes", "glass_crystals", "sunken_structures",
         "prismatic_reflections"], 5,
        difficulty_tier=4, rift_chance=0.75,
        preferred_races=("human", "cyborg"),
    ),
    "corpse_fields": BiomeConfig(
        "Corpse Fields", "field", 0.40, 0.22, 1.6,
        ["mass_graves", "rusting_tanks", "bone_fields", "crater_lakes"], 6,
        difficulty_tier=4, rift_chance=0.55,
        preferred_races=("revenant", "nullborn"),
    ),
    "stormspire_highlands": BiomeConfig(
        "Stormspire Highlands", "highland", 0.85, 0.40, 0.7,
        ["lightning_towers", "wind_swept_plateaus", "frequent_rifts",
         "crackling_spires"], 7,
        difficulty_tier=5, rift_chance=0.92,
        preferred_races=("sentientai", "cyborg"),
    ),
    "toxin_marshes": BiomeConfig(
        "Toxin Marshes", "marsh", 0.30, 0.18, 1.9,
        ["poisoned_waters", "sinking_islands", "bioluminescent_ooze",
         "gas_vents"], 8,
        difficulty_tier=4, rift_chance=0.65,
        preferred_races=("chthon", "vesperid"),
    ),
    "dead_city_outskirts": BiomeConfig(
        "Dead City Outskirts", "ruins", 0.60, 0.32, 0.9,
        ["ruined_skyscrapers", "subway_entrances", "massive_rift_zones",
         "overgrown_streets"], 9,
        difficulty_tier=5, rift_chance=0.88,
        preferred_races=("revenant", "cyborg", "nullborn"),
    ),
}


def _to_slug(name: str) -> str:
    """Normalize a biome name to its slug key."""
    return name.lower().replace(" ", "_")


BIOME_ORDER: list[str] = [
    "scorched_plains",       # tier 1
    "ash_wastes",            # tier 2
    "neon_bogs",             # tier 3
    "ironwood_thicket",      # tier 3
    "rust_canyons",          # tier 4
    "glass_dunes",           # tier 4
    "corpse_fields",         # tier 4
    "toxin_marshes",         # tier 4
    "stormspire_highlands",  # tier 5
    "dead_city_outskirts",   # tier 5
]

# Full display names in the same order
BIOME_DISPLAY_NAMES = [cfg.name for cfg in BIOME_CONFIGS.values()]


def get_biome_config(name: str) -> BiomeConfig | None:
    slug = _to_slug(name)
    if slug in BIOME_CONFIGS:
        return BIOME_CONFIGS[slug]
    # Fallback: try partial match on display name
    for cfg in BIOME_CONFIGS.values():
        if cfg.name.lower() == name.lower():
            return cfg
    return None


def get_biome_index(name: str) -> int:
    """Return the position of *name* in BIOME_ORDER, or -1."""
    slug = _to_slug(name)
    if slug in BIOME_ORDER:
        return BIOME_ORDER.index(slug)
    return -1


def get_random_biome(rng) -> str:
    """Return a random biome name using the given RNG."""
    import random
    if rng is None:
        rng = random
    names = list(BIOME_CONFIGS.keys())
    return names[rng.randint(0, len(names) - 1)]


def _is_biome(x: float, y: float, biome_slug: str) -> bool:
    """Check if the coordinate pair roughly matches a biome spatial zone.

    A simple hash-based spatial check so that terrain_generator can
    seed biome regions from coordinates alone.
    """
    xi, yi = int(x * 10) & 0xFF, int(y * 10) & 0xFF
    combined = (xi << 8) | yi
    idx = abs(hash(f"{biome_slug}#{combined}")) % len(BIOME_CONFIGS)
    slug = list(BIOME_CONFIGS.keys())[idx]
    return slug == biome_slug


def get_biome_feature_type(x: float, y: float) -> str:
    """Return a pseudo-deterministic feature type for a coordinate."""
    xi, yi = int(x * 10) & 0xFF, int(y * 10) & 0xFF
    features = [
        "hill", "depression", "ridge", "outcrop",
        "basin", "escarpment", "plateau", "valley",
    ]
    idx = abs(hash(f"feature#{xi},{yi}")) % len(features)
    return features[idx]


def get_difficulty_by_biome(name: str) -> int:
    cfg = get_biome_config(name)
    return cfg.difficulty_tier if cfg else 1


def get_weather_by_biome(name: str) -> str:
    weather_map = {
        "ash_wastes":       "ash_storm",
        "rust_canyons":     "dust_devils",
        "neon_bogs":        "acid_fog",
        "scorched_plains":  "heat_wave",
        "ironwood_thicket": "magnetic_storm",
        "glass_dunes":      "glass_storm",
        "corpse_fields":    "bone_wind",
        "stormspire_highlands": "lightning_storm",
        "toxin_marshes":    "toxic_fog",
        "dead_city_outskirts": "radiation_gust",
    }
    slug = _to_slug(name)
    return weather_map.get(slug, "clear")


def get_biome_color_map() -> dict[str, tuple[int, int, int]]:
    """Return a dict of biome slug → (R, G, B) colour tuple."""
    return {
        "ash_wastes":          (191, 166, 128),
        "rust_canyons":        (217, 115, 89),
        "neon_bogs":           (102, 217, 140),
        "scorched_plains":     (230, 153, 77),
        "ironwood_thicket":    (89, 153, 89),
        "glass_dunes":         (179, 204, 242),
        "corpse_fields":       (140, 115, 128),
        "stormspire_highlands":(128, 140, 191),
        "toxin_marshes":       (115, 179, 102),
        "dead_city_outskirts": (128, 128, 140),
    }


def _lerp(a: float, b: float, r: float) -> float:
    return a + (b - a) * r


def blend_biomes(biome_a: BiomeConfig, biome_b: BiomeConfig,
                 ratio_a: float = 0.5) -> dict:
    """Blend properties between two biomes using lerp."""
    ratio_b = 1.0 - ratio_a
    return {
        "avg_height": _lerp(biome_a.avg_height, biome_b.avg_height, ratio_a),
        "height_variance": _lerp(biome_a.height_variance,
                                  biome_b.height_variance, ratio_a),
        "water_temp_modifier": _lerp(biome_a.water_temp_modifier,
                                      biome_b.water_temp_modifier, ratio_a),
        "terrain_features": list(
            set(biome_a.terrain_features + biome_b.terrain_features)
        ),
        "palette_index": biome_a.palette_index,
    }