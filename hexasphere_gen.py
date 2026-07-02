#!/usr/bin/env python3
"""Hexasphere Procedural World Generator for Fallen Earth RPG."""

import json
import math
from pathlib import Path


class SeededRandom:
    """Simple LCG pseudo-random number generator for reproducibility."""
    def __init__(self, seed: int):
        self.seed = seed

    def _next(self) -> int:
        self.seed = (1664525 * self.seed + 1013904223) % 2**31
        return self.seed

    def random(self) -> float:
        return self._next() / 2**31


def seeded_random(seed: int = 42) -> SeededRandom:
    """Get a fresh seeded RNG."""
    return SeededRandom(seed)


class HexasphereGenerator:
    TILE_SIZE = 64
    GRID_RADIUS = 8

    BIOME_NAMES = [
        "Ash Wastes", "Rust Canyons", "Neon Bogs", "Scorched Plains",
        "Ironwood Thicket", "Glass Dunes", "Corpse Fields",
        "Stormspire Highlands", "Toxin Marshes", "Dead City Outskirts"
    ]

    def __init__(self, biome_data: dict, world_seed: int = 0):
        self.biome_rules = {b["name"]: b for b in biome_data}
        self.rng = seeded_random(world_seed)

    def _simple_noise(self, x: float, y: float, octaves: int = 4) -> float:
        """Simple gradient-based noise (Perlin-like)."""
        result = 0.0
        freq_mult = 1.0
        for o in range(octaves):
            nx, ny = x * (2 ** o), y * (2 ** o)
            xi, yi = int(nx) % 256, int(ny) % 256
            xf, yf = nx - xi, ny - yi
            u, v = seeded_random((xi << 13) | yi).random(), seeded_random(((yi << 13) | ((xi + 1) << 13))).random()
            uu, vv = 1.0 - abs(u & 255) / 256.0, 1.0 - abs(v & 255) / 256.0
            r1 = uu * (1 - xf) + uu * xf
            u = (u - xi) * 2
            r2 = vv * (1 - yf) + vv * yf
            v = (v - yi) * 2
            result += ((r1 * r2 + u * v) * freq_mult)
            freq_mult *= 0.5
        return max(0, min(1, result))

    def _determine_biome(self, lat: float, lon: float) -> tuple[str, dict]:
        """Determine biome at a point using multiple environmental factors."""
        noise = self._simple_noise(lat * 0.2, lon * 0.2)
        dist_factor = self.rng.random() * 100
        lat_band = 0.5 if abs(lat) < 30 else (-1.2 if abs(lat) > 70 else seeded_random().random() * 1.4)
        biome_idx = int(((dist_factor * 0.3 + lat_band * 0.4 + noise * len(self.BIOME_NAMES)) % len(self.BIOME_NAMES)))
        return self.BIOME_NAMES[biome_idx], self.biome_rules.get(self.BIOME_NAMES[biome_idx], {})

    def _get_terrain_features(self, biome_name: str, lat: float, lon: float) -> dict:
        """Generate terrain features for a tile."""
        base = self.biome_rules.get(biome_name, {})
... [truncated]
def generate_world(self, world_seed: int = 0, num_tiles: int = 100):
    """Generate list of hex tiles for sphere approx."""
    self.rng = seeded_random(world_seed)
    tiles = []
    for i in range(num_tiles):
        lat = (i / num_tiles * 180) - 90
        lon = (i * 1.7) % 360
        biome_name, rules = self._determine_biome(lat, lon)
        features = self._get_terrain_features(biome_name, lat, lon)
        tile = {
            "id": f"{i}",
            "q": i % 20 - 10,
            "r": i // 20 - 5,
            "biome_name": biome_name,
            "lat": lat,
            "lon": lon,
            "elevation": random.random(),
            "features": features,
            "rift_chance": rules.get("rift_chance", 0.3)
        }
        tiles.append(tile)
    return {"seed": world_seed, "tiles": tiles, "schema_version": "1.0"}

# Monkey patch for test
import random
HexasphereGenerator.generate_world = generate_world
print("Patched")

