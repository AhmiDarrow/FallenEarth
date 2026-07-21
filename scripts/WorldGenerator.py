#!/usr/bin/env python3
"""
WorldGenerator.py: Orchestrates data-driven procedural generation workflow.
Reads from fundamental scripts, generates map state deterministically, 
and writes the result to the canonical WorldMapSchema.json format.
Uses the 10 game biomes from biome_rules.py + data/biomes.json.
"""

import json
import math
import random as _stdlib_random
from typing import Any, Dict, List, Tuple
from datetime import datetime

# ── RNG ────────────────────────────────────────────────────────────────────
class XORShift32:
    def __init__(self, seed: int | None = None) -> None:
        self.state = (0xA515_8D3C if seed is None
                      else (hash(seed) & 0xFFFFFFFF if isinstance(seed, str)
                            else seed & 0xFFFFFFFF))

    def next(self) -> int:
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 7) & 0xFFFFFFFF
        x ^= (x << 15) & 0xFFFFFFFF
        self.state = x
        return self.state

    def uniform(self) -> float:
        return self.next() / 4294967296.0


# ── Biome definitions from the game ────────────────────────────────────────
# Inline the 10 game biomes so this script is self-contained.
GAME_BIOMES: list[dict[str, Any]] = [
    {"name": "Ash Wastes",          "temp": (0.5, 0.7), "rain": (0.3, 0.5), "elev": (0.3, 0.6), "tier": 2},
    {"name": "Rust Canyons",        "temp": (0.3, 0.5), "rain": (0.2, 0.5), "elev": (0.6, 0.9), "tier": 4},
    {"name": "Neon Bogs",           "temp": (0.5, 0.7), "rain": (0.6, 0.9), "elev": (0.0, 0.3), "tier": 3},
    {"name": "Scorched Plains",     "temp": (0.7, 1.0), "rain": (0.1, 0.4), "elev": (0.3, 0.6), "tier": 1},
    {"name": "Ironwood Thicket",    "temp": (0.4, 0.6), "rain": (0.5, 0.8), "elev": (0.3, 0.7), "tier": 3},
    {"name": "Glass Dunes",         "temp": (0.6, 0.9), "rain": (0.0, 0.3), "elev": (0.4, 0.7), "tier": 4},
    {"name": "Corpse Fields",       "temp": (0.3, 0.6), "rain": (0.3, 0.6), "elev": (0.2, 0.5), "tier": 4},
    {"name": "Stormspire Highlands","temp": (0.1, 0.4), "rain": (0.4, 0.7), "elev": (0.7, 1.0), "tier": 5},
    {"name": "Toxin Marshes",       "temp": (0.4, 0.7), "rain": (0.7, 1.0), "elev": (0.0, 0.3), "tier": 4},
    {"name": "Dead City Outskirts",  "temp": (0.3, 0.6), "rain": (0.3, 0.6), "elev": (0.4, 0.7), "tier": 5},
]


def _pick_biome(temp: float, rain: float, elev: float,
                rng: XORShift32) -> dict[str, Any]:
    """Climate-profile scoring — same algorithm as WorldGenerator.gd."""
    best_score = -999.0
    best = GAME_BIOMES[0]
    for b in GAME_BIOMES:
        tlo, thi = b["temp"]
        rlo, rhi = b["rain"]
        elo, ehi = b["elev"]
        t_fit = 1.0 if tlo <= temp <= thi else max(0.0, 1.0 - 3.0 * min(abs(temp - tlo), abs(temp - thi)))
        r_fit = 1.0 if rlo <= rain <= rhi else max(0.0, 1.0 - 3.0 * min(abs(rain - rlo), abs(rain - rhi)))
        e_fit = 1.0 if elo <= elev <= ehi else max(0.0, 1.0 - 3.0 * min(abs(elev - elo), abs(elev - ehi)))
        score = (t_fit + r_fit + e_fit) / 3.0 * 3.0 + rng.uniform() * 0.4 - 0.2
        if score > best_score:
            best_score = score
            best = b
    return dict(best)


# ── Heightmap ──────────────────────────────────────────────────────────────
def generate_heightmap(rng: XORShift32,
                       dimensions: tuple[int, int]) -> dict[str, float]:
    print("Generating deterministic height data...")
    w, h = dimensions
    data = {}
    for x in range(w):
        for y in range(h):
            rng.next()
            n1 = rng.uniform() * 0.4 + ((x % 5) / w * 0.1)
            n2 = rng.uniform() * 0.4 + ((y % 3) / h * 0.1)
            data[f'{x},{y}'] = min(1.0, n1 + n2)
    print("Heightmap generated.")
    return data


# ── Core ───────────────────────────────────────────────────────────────────
def generate_world_schema(seed_str: str,
                          dimensions: tuple[int, int]) -> dict[str, Any] | None:
    """Orchestrate world generation using all 10 game biomes."""

    rng = XORShift32(seed=seed_str)
    print("=" * 50)
    print(f"STARTING WORLD GENERATION (Seed: {seed_str}) — {len(GAME_BIOMES)} biomes")
    print("=" * 50)

    heightmap = generate_heightmap(rng, dimensions)
    if not heightmap:
        return None

    final_tiles: list[dict[str, Any]] = []
    biome_distribution: dict[str, int] = {}

    print("Classifying map tiles via climate-profile scoring...")

    for x in range(dimensions[0]):
        for y in range(dimensions[1]):
            height = heightmap.get(f'{x},{y}')
            if height is None:
                continue

            # Compute simulated temperature / rainfall from height + position
            lat_factor = abs(y / dimensions[1] - 0.5) * 2.0  # 0 equator, 1 pole
            temp = max(0.0, min(1.0, 1.0 - lat_factor * 0.5 - (height - 0.5) * 0.3))
            rain = max(0.0, min(1.0, 0.5 + rng.uniform() * 0.3 - (height - 0.5) * 0.4))

            biome = _pick_biome(temp, rain, height, rng)
            bname = biome["name"]

            tile = {
                "id": f"{x},{y}",
                "biome_name": bname,
                "elevation": height,
                "temperature": round(temp, 3),
                "rainfall": round(rain, 3),
                "tier": biome.get("tier", 1),
                "is_navigable": True,
            }
            final_tiles.append(tile)
            biome_distribution[bname] = biome_distribution.get(bname, 0) + 1

    # Print distribution
    print("Biome distribution:")
    for bname, count in sorted(biome_distribution.items(),
                                key=lambda x: -x[1]):
        print(f"  {bname}: {count} tiles ({count/len(final_tiles)*100:.1f}%)")

    # Assemble the final schema object
    world_schema: dict[str, Any] = {
        "schema_version": "1.1",
        "seed": seed_str,
        "biome_count": len(GAME_BIOMES),
        "dimensions": {"width": dimensions[0], "height": dimensions[1]},
        "tiles": final_tiles,
        "summary_stats": {
            "average_elevation": (sum(t['elevation'] for t in final_tiles)
                                  / len(final_tiles)),
            "biome_distribution": biome_distribution,
        },
        "metadata": {
            "generation_source": "WorldGenerator.py",
            "creation_date_utc": datetime.utcnow().isoformat() + 'Z',
        },
    }
    return world_schema


if __name__ == "__main__":
    SEED = "FallenEarthTest"
    SIZE = (32, 32)

    world_data = generate_world_schema(seed_str=SEED, dimensions=SIZE)

    if world_data:
        file_path = "generated_map_output.json"
        with open(file_path, "w") as f:
            json.dump(world_data, f, indent=4)
        print(f"\nMap saved to {file_path}.")
    else:
        print("\nFATAL: World generation failed.")