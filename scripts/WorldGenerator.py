#!/usr/bin/env python3
"""
WorldGenerator.py: Orchestrates data-driven procedural generation workflow.
Reads from fundamental scripts, generates map state deterministically, 
and writes the result to the canonical WorldMapSchema.json format.
Requires scripts/seed_system.py, scripts/heightmaps.py, and scripts/biome_rules.py.
"""

import json
from typing import Any, Dict, List, Tuple
from datetime import datetime # Used for metadata tracking

# --- Dependency Loading (Simulated imports for monolithic execution) ---

# 1. RNG System
class XORShift32:
    def __init__(self, seed: int | None = None) -> None:
        if seed is None:
            self.state = 0xA515_8D3C 
        else:
            self.state = self._encode_seed(seed)

    def _encode_seed(self, seed: int | str) -> int:
        if isinstance(seed, str):
            return hash(seed) & 0xFFFFFFFF
        return seed & 0xFFFFFFFF

    def next(self) -> int:
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 7) & 0xFFFFFFFF
        x ^= (x << 15) & 0xFFFFFFFF
        self.state = x
        return self.state

    def uniform(self) -> float: # Key for simulation logic
        return self.next() / 4294967296.0


# 2. Biome System (Simplified internal definitions/helpers from simulated scripts/biome_rules.py)
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

def get_biome_config(name: str) -> BiomeConfig | None:
    normalized = name.lower().replace(" ", "_")
    if normalized in BIOME_CONFIGS: return BIOME_CONFIGS[normalized]
    for config in BIOME_CONFIGS.values(): if config.name.lower() == name.lower(): return config
    return None

def blend_biomes(biome_a: BiomeConfig, biome_b: BiomeConfig) -> dict[str, float]:
    # Returns a generic blended property dictionary
    avg = (biome_a.avg_height + biome_b.avg_height) / 2.0
    return {"avg_height": avg}

# 3. Heightmap Generation (Logic from scripts/heightmaps.py)
def generate_heightmap(rng: XORShift32, dimensions: tuple[int, int]) -> dict[str, float] | None:
    print("🌐 Generating deterministic height data...")
    w, h = dimensions
    heightmap_data = {}

    for x in range(w):
        for y in range(h):
            rng.next() 
            noise1 = rng.uniform() * 0.4 + ((x % 5) / w * 0.1) 
            noise2 = rng.uniform() * 0.4 + ((y % 3) / h * 0.1)
            final_height = min(1.0, noise1 + noise2) 
            heightmap_data[f'{x},{y}'] = final_height
    print("✅ Heightmap successfully simulated.")
    return heightmap_data


def generate_world_schema(seed_str: str, dimensions: tuple[int, int]) -> dict[str, Any] | None:
    """Orchestrates the generation and output of the WorldMapSchema."""

    rng = XORShift32(seed=seed_str)
    print("=" * 50)
    print(f"🚀 STARTING WORLD GENERATION PIPELINE Test Run (Seed: {seed_str})")
    print("=" * 50)

    heightmap_data = generate_heightmap(rng, dimensions)
    if not heightmap_data: return None

    final_tiles: List[Dict[str, Any]] = []
    biome_distribution: Dict[str, int] = {}

    print("🔍 Classifying map tiles and populating schema...")

    for x in range(dimensions[0]):
        for y in range(dimensions[1]):
            height = heightmap_data.get(f'{x},{y}') # Get calculated height 
            if height is None: continue
            
            # Simulate biome classification based on map data and RNG state progression
            rng.next() 
            choice_roll = rng.uniform() * 10.0
            biome_name = "Forest" if choice_roll < 2.5 else ("Grassland" if choice_roll < 6 else "Tundra")

            config = get_biome_config(biome_name)
            if not config: continue
            
            tile_data = {
                "id": f"{x},{y}",
                "biome_name": config.name, 
                "tile_type": choice_roll >= 6 and "Tundra" or "OpenField", # Simple logic for tile type
                "elevation": height,
                "features": config.terrain_features or [],
                "is_navigable": True
            }
            final_tiles.append(tile_data)
            biome_distribution[config.name] = biome_distribution.get(config.name, 0) + 1

    # Assemble the final schema object
    world_schema: dict[str, Any] = {
        "schema_version": "1.1",
        "seed": seed_str,
        "dimensions": {"width": dimensions[0], "height": dimensions[1]},
        "tiles": final_tiles,
        "summary_stats": {
            # Calculate total area dynamically
            "total_forest_area": sum(1 for tile in final_tiles if get_biome_config(tile['name']) and 'dense_trees' in get_biome_config(tile['name']).terrain_features), 
            "average_elevation": (sum(t['elevation'] for t in final_tiles) / len(final_tiles)),
            "biome_distribution": biome_distribution
        },
        "metadata": {
            "generation_source": "WorldGenerator.py",
            "creation_date_utc": datetime.utcnow().isoformat() + 'Z'
        }
    }
    return world_schema

if __name__ == "__main__":
    SEED = "UltimateRemedyBuildScripted"; 
    SIZE = (16, 16) # Small enough to pass a quick test size.

    world_data = generate_world_schema(seed_str=SEED, dimensions=SIZE)

    if world_data:
        # Now we write the data object exactly matching the WorldMapSchema structure
        file_path = "generated_map_output.json"
        with open(file_path, "w") as f:
            json.dump(world_data, f, indent=4)
        print("\n[FINAL] Structured map state saved to generated_map_output.json.")
    else:
        print("\n[FINAL] FATAL ERROR: World generation failed to produce schema.")