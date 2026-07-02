#!/usr/bin/env python3
"""Biome rule engine for hexasphere terrain generation."""

from dataclasses import dataclass
from typing import Literal


@dataclass(frozen=True)
class BiomeConfig:
    name: str
    primary_biome: Literal["forest", "desert", "tundra", "mountain", "grassland"]
    avg_height: float
    height_variance: float
    water_temp_modifier: float
    terrain_features: list[str]
    palette_index: int


BIOME_CONFIGS = {
    "forest": BiomeConfig("Forest", "forest", 0.65, 0.25, 1.2, ["dense_trees"], 0),
    "savanna": BiomeConfig("Savanna", "grassland", 0.55, 0.20, 1.8, [], 1),
    "desert": BiomeConfig("Desert", "desert", 0.35, 0.30, 2.8, [], 2),
    "tundra": BiomeConfig("Tundra", "tundra", 0.45, 0.35, 0.6, [], 3),
    "mountain": BiomeConfig("Mountain", "mountain", 0.85, 0.40, 0.8, [], 4),
    "grassland": BiomeConfig("Grassland", "grassland", 0.50, 0.18, 1.5, [], 5),
}

BIOME_ORDER = ["ice_cap", "snow", "tundra", "grassland", "desert", "forest", "jungle"]


def get_biome_config(name: str) -> BiomeConfig | None:
    normalized = name.lower().replace(" ", "_")
    if normalized in BIOME_CONFIGS:
        return BIOME_CONFIGS[normalized]
    aliases = {"icecap": "ice_cap", "tundras": "tundra"}
    return BIOME_CONFIGS.get(aliases.get(normalized))


def get_biome_index(name: str) -> int:
    if name in BIOME_ORDER:
        return BIOME_ORDER.index(name)
    return -1


def _lerp(a: float, b: float, r: float) -> float:
    return a + (b - a) * r


def blend_biomes(biome_a: BiomeConfig, biome_b: BiomeConfig, ratio_a: float = 0.5) -> dict:
    """Blend properties between two biomes using lerp.
    Note: returns mixed types (floats + list for features); annotation relaxed.
    """
    ratio_b = 1.0 - ratio_a
    return {
        "avg_height": _lerp(biome_a.avg_height, biome_b.avg_height, ratio_a),
        "height_variance": _lerp(biome_a.height_variance, biome_b.height_variance, ratio_a),
        "water_temp_modifier": _lerp(biome_a.water_temp_modifier, biome_b.water_temp_modifier, ratio_a),
        "terrain_features": list(set(biome_a.terrain_features + biome_b.terrain_features)),
        "palette_index": biome_a.palette_index,
    }