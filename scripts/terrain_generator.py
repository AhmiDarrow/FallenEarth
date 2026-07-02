"""
Fallen Earth Terrain Generator Module

Generates procedural terrain maps for Fallen Earth with support for:
- Multiple biome types (desert, forest, swamp, tundra, ocean)
- Procedural terrain height variation
- Water level and flood zones
- Biome adjacency and transition rules
- Map export to binary format compatible with game engine
"""

import argparse
import os
import random
import sys
from typing import Tuple, Dict, Any, Optional

# Add parent directory to path for biome_rules import
sys.path.insert(0, os.path.dirname(__file__))

# Import what is actually available from biome_rules;
# BIOME_RULES / BIOME_TYPES may be missing there -- define fallbacks below.
try:
    from biome_rules import (
        get_biome_color_map,
        get_difficulty_by_biome,
        get_weather_by_biome,
        _is_biome,
        get_random_biome,
        get_biome_feature_type,
    )
except ImportError:
    pass  # biome_rules may not export everything terrain_generator needs

# ---- Fallback biome definitions (used when biome_rules is incomplete) ----
# Maps uppercase biome names to integer indices used throughout this module.
# These mirrors BIOME_ORDER from biome_rules.py and the BIOME_TYPES dict it should have.
BIOME_INDEX = {
    "DESERT": 0,
    "TUNDRA": 1,
    "FOREST": 2,
    "SWAMP": 3,
    "OCEAN": 4,
}

# Reverse lookup: index -> biome name (uppercase)
_INDEX_TO_BIOME = {v: k for k, v in BIOME_INDEX.items()}

# Integer aliases used by the rest of this module.
BIOME_TYPES: Dict[str, int] = {k: v for k, v in BIOME_INDEX.items()}


class _BiomeRule:
    """Minimal biome rule shim so that code expecting rules.name etc. won't crash."""

    def __init__(self, name: str, base_terrain: int, terrain_noise: float):
        self.name = name
        self.base_terrain = base_terrain
        self.terrain_noise = terrain_noise


# Map integer biome indices -> rule objects (mirrors BIOME_RULES in biome_rules.py)
BIOME_RULES: Dict[int, "_BiomeRule"] = {
    0: _BiomeRule("desert", 1, 1.2),
    1: _BiomeRule("tundra", 2, 1.8),
    2: _BiomeRule("forest", 1, 1.4),
    3: _BiomeRule("swamp", 0, 1.1),
    4: _BiomeRule("ocean", 0, 1.0),
}


# ============== MAP CONFIGURATION ==============

MAP_SIZE = 128  # Map dimensions (128x128 tiles)
BIOME_SAMPLE_RADIUS = 50  # Radius for sampling biome positions
NOISE_STRENGTH_MULTIPLIER = 1.8  # Amplifies noise values for terrain variation


def _build_biome_adjacency() -> Dict[int, set]:
    """Build adjacency lookup: biome index -> set of compatible neighbor indices."""
    # Name-level adjacency map (forest borders everything; desert is limited)
    adj_names: Dict[str, set] = {
        "forest": {"savanna", "desert", "tundra", "mountain", "grassland", "swamp"},
        "savanna": {"savanna", "forest", "desert", "grassland", "mountain", "swamp"},
        "desert": {"desert", "savanna", "grassland", "swamp"},
        "tundra": {"tundra", "forest", "mountain", "snow", "ice_cap"},
        "mountain": {"mountain", "forest", "savanna", "tundra", "grassland", "desert"},
        "grassland": {"grassland", "forest", "savanna", "desert", "mountain", "swamp"},
    }

    # Map all known biome keys (from BIOME_TYPES + extra names) to indices.
    # Direct mapping for our 5 biome indices.
    result = {}
    compat_sets = {
        0: {0, 2, 3},       # DESERT -> desert, forest, swamp
        1: {1, 2, 4},       # TUNDRA -> tundra, forest, ocean
        2: {0, 1, 2, 3, 4}, # FOREST -> all (forest is universal)
        3: {0, 2, 3},       # SWAMP -> desert, forest, swamp
        4: {1, 2, 4},       # OCEAN -> tundra, forest, ocean
    }
    for idx, neighbors in compat_sets.items():
        result[idx] = set(neighbors)
    return result


# Module-level adjacency cache (built lazily on first use)
_BIOME_ADJ_CACHE: Optional[Dict[int, set]] = None


def _get_biome_adjacency() -> Dict[int, set]:
    """Return biome adjacency rules (lazy-init)."""
    global _BIOME_ADJ_CACHE
    if _BIOME_ADJ_CACHE is None:
        _BIOME_ADJ_CACHE = _build_biome_adjacency()
    return _BIOME_ADJ_CACHE


def generate_terrain_map() -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """Generate a complete terrain map with biomes, terrain types, and features.

    Returns:
        Tuple containing (map_data, metadata) dictionaries
    """
    print(f"[Terrain Generator] Initializing terrain generation for {MAP_SIZE}x{MAP_SIZE} map...")

    # Initialize data structures
    biome_map: Dict[Tuple[int, int], int] = {}  # (x, y) -> biome_type_index
    terrain_map: Dict[Tuple[int, int], int] = {}  # (x, y) -> terrain_type
    water_level_map: Dict[Tuple[int, int], float] = {}  # (x, y) -> water level
    feature_map: Dict[Tuple[int, int], str] = {}  # (x, y) -> feature_type

    # Generate biomes for all map positions
    _generate_biome_layer(biome_map, terrain_map, water_level_map, feature_map)

    # Apply biome adjacency rules - ensure valid borders between adjacent tiles
    _apply_biome_adjacency_rules(biome_map)

    # Calculate terrain roughness based on biome types
    _calculate_terrain_roughness(terrain_map, biome_map)

    # Store generation metadata
    metadata: Dict[str, Any] = {
        "map_size": MAP_SIZE,
        "biome_count": len(set(biome_map.values())) if biome_map else 0,
        "unique_features": len(set(feature_map.values())) if feature_map else 0,
        "total_tiles": MAP_SIZE * MAP_SIZE,
        "generator_version": "1.0",
    }

    # Calculate additional stats
    biome_distribution = _calculate_biome_distribution(biome_map)
    metadata["biome_distribution"] = biome_distribution

    print(f"[Terrain Generator] Generated map with {metadata['biome_count']} biomes")
    for biome_idx, count in sorted(biome_distribution.items()):
        name: str = BIOME_RULES.get(biome_idx).name if biome_idx in BIOME_RULES else f"Biome{biome_idx}"
        pct = biome_distribution[biome_idx] * 100
        print(f"[Terrain Generator]   {name}: {count} tiles ({pct:.1f}%)")

    # Build map_data dict from the individual maps (was previously 'map_data' which was never defined)
    map_data: Dict[str, Any] = {
        "biomes": biome_map,
        "terrain": terrain_map,
        "water_level": water_level_map,
        "features": feature_map,
    }
    return map_data, metadata


def _generate_biome_layer(
    biome_map: Dict[Tuple[int, int], int],
    terrain_map: Dict[Tuple[int, int], int],
    water_level_map: Dict[Tuple[int, int], float],
    feature_map: Dict[Tuple[int, int], str],
) -> None:
    """Generate the biome layer by sampling random positions and expanding outward."""

    # Sample a few random starting positions across the map
    num_samples = 20
    sample_positions = [(random.uniform(-5.0, 5.0), random.uniform(-5.0, 5.0)) for _ in range(num_samples)]

    print(f"[Terrain Generator] Sampling {num_samples} initial biome positions...")

    for x_center, y_center in sample_positions:
        # Find the primary biome at this location
        primary_biome = _find_primary_biome(x_center, y_center)

        if primary_biome is not None:
            # Expand outward from this center point to fill connected region
            _expand_biome_region(
                x_center, y_center, primary_biome, biome_map, terrain_map,
                water_level_map, feature_map, sample_radius=BIOME_SAMPLE_RADIUS,
            )


def _find_primary_biome(x: float, y: float) -> Optional[int]:
    """Find the primary biome that contains a given coordinate."""
    # Check from most restrictive to least restrictive (desert first, then ocean)
    for name in ["DESERT", "TUNDRA", "FOREST", "SWAMP"]:
        biome_type = BIOME_TYPES[name]
        if _is_biome(x, y, biome_type):
            return biome_type

    # Default to ocean for edge positions
    if _is_biome(x, y, BIOME_TYPES["OCEAN"]):
        return BIOME_TYPES["OCEAN"]

    return BIOME_TYPES["FOREST"]  # Fallback


def _expand_biome_region(
    x_center: float,
    y_center: float,
    primary_biome: int,
    biome_map: Dict[Tuple[int, int], int],
    terrain_map: Dict[Tuple[int, int], int],
    water_level_map: Dict[Tuple[int, int], float],
    feature_map: Dict[Tuple[int, int], str],
    sample_radius: float = 50.0,
    visited: Optional[set] = None,
) -> None:
    """Expand a biome region outward from a center point using flood-fill."""

    if visited is None:
        visited = set()

    rules = BIOME_RULES.get(primary_biome)
    if rules is None:
        return  # Unknown biome index; skip

    # Generate terrain for this biome's default characteristics
    base_terrain = rules.base_terrain
    noise_strength = rules.terrain_noise * NOISE_STRENGTH_MULTIPLIER

    # Determine water level range for this biome
    water_range: Dict[int, Tuple[float, float]] = {
        BIOME_TYPES["DESERT"]: (-2.5, -1.8),
        BIOME_TYPES["FOREST"]: (-2.0, -1.3),
        BIOME_TYPES["SWAMP"]: (-1.5, -0.5),
        BIOME_TYPES["TUNDRA"]: (-2.8, -2.2),
        BIOME_TYPES["OCEAN"]: (0.8, 2.0),
    }
    water_min, water_max = water_range.get(primary_biome, (-2.0, -1.5))

    # Generate random terrain variation within this region
    base_noise = random.uniform(0.3, 0.9)  # Base noise level for this region

    def _sample_tile(pt_x: float, pt_y: float) -> bool:
        """Sample a tile and add it to the maps if not already visited."""
        if (pt_x, pt_y) in visited:
            return False

        tile_x = int(round(pt_x))
        tile_y = int(round(pt_y))

        # Apply noise-based terrain variation
        noise_value = random.gauss(0, 1) * base_noise
        terrain_variation = noise_value * (noise_strength - 1.0 + base_terrain)

        # Set biome for this tile
        biome_map[(tile_x, tile_y)] = primary_biome

        # Calculate terrain type based on noise and base terrain
        final_terrain = min(2, max(0, int(base_terrain + terrain_variation)))
        terrain_map[(tile_x, tile_y)] = final_terrain

        # Generate water level with variation around biome default
        random_water = random.uniform(water_min, water_max)
        water_level_map[(tile_x, tile_y)] = round(random_water, 2)

        # Add a feature to the map (80% chance)
        if random.random() < 0.8:
            feature_type = get_biome_feature_type(x_center, y_center)
            feature_map[(tile_x, tile_y)] = feature_type

        visited.add((tile_x, tile_y))
        return True

    # Flood-fill using simple iterative approach with radius sampling
    to_process = [(x_center, y_center)]

    while to_process and len(visited) < 500:  # Limit processing per region
        cx, cy = to_process.pop()

        if not _sample_tile(cx, cy):
            continue

        # Sample surrounding tiles within the radius
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                tx = cx + dx * sample_radius / 3
                ty = cy + dy * sample_radius / 3
                if _sample_tile(tx, ty):
                    to_process.append((tx, ty))


def _apply_biome_adjacency_rules(biome_map: Dict[Tuple[int, int], int]) -> None:
    """Ensure biome borders follow adjacency rules and create natural transitions."""

    print("[Terrain Generator] Applying biome adjacency rules...")

    # Create a set of all map positions for quick lookup
    all_positions = set(biome_map.keys())

    # Process each tile and fix invalid adjacencies
    changed = True
    iterations = 0
    max_iterations = 10
    adj = _get_biome_adjacency()

    while changed and iterations < max_iterations:
        changed = False
        iterations += 1

        for (x, y), biome_type in list(biome_map.items()):
            # Find neighbors of this tile
            neighbors = []
            for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                if (x + dx, y + dy) in biome_map:
                    nb_biome = biome_map[(x + dx, y + dy)]
                    neighbors.append((x + dx, y + dy, nb_biome))

            # Check each neighbor for valid adjacency
            for nx, ny, neighbor_biome in neighbors:
                allowed = adj.get(biome_type, {biome_type})

                if neighbor_biome not in allowed:
                    # Need to transition - find an intermediate biome
                    valid_transitions = adj.get(neighbor_biome, set())

                    # Check if any allowed biome for current tile can also border the neighbor
                    bridge_found = None
                    for allowed_biome in sorted(allowed):
                        if allowed_biome in valid_transitions:
                            bridge_found = allowed_biome
                            break

                    # If no direct bridge, use forest as universal connector
                    if bridge_found is None:
                        bridge_found = BIOME_TYPES["FOREST"]

                    # Update the neighbor tile to use the bridge biome
                    biome_map[(nx, ny)] = bridge_found
                    changed = True

    print(f"[Terrain Generator] Applied {iterations} adjacency rule passes")


def _calculate_terrain_roughness(
    terrain_map: Dict[Tuple[int, int], int],
    biome_map: Dict[Tuple[int, int], int],
) -> None:
    """Apply additional roughness based on biome type and map features."""

    print("[Terrain Generator] Calculating terrain roughness...")

    # Identify edges between biomes for mountain ranges
    edge_tiles = set()
    for (x, y), biome_type in biome_map.items():
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            if (x + dx, y + dy) in biome_map:
                if biome_map[(x + dx, y + dy)] != biome_type:
                    edge_tiles.add((x, y))

    # Apply roughness near biome edges
    for (x, y) in edge_tiles:
        noise = random.gauss(0.5, 0.3)

        # Tundra and ocean borders get mountainous terrain
        if biome_map[(x, y)] in (BIOME_TYPES["TUNDRA"], BIOME_TYPES["OCEAN"]):
            terrain_map[(x, y)] = max(terrain_map.get((x, y), 0) + int(noise * 2), 1)
        # Forest edges can be hilly
        elif biome_map[(x, y)] == BIOME_TYPES["FOREST"]:
            terrain_map[(x, y)] = max(terrain_map.get((x, y), 0) + int(noise), 0)


def _calculate_biome_distribution(
    biome_map: Dict[Tuple[int, int], int],
) -> Dict[int, float]:
    """Calculate the distribution percentage of each biome type."""

    total = len(biome_map)
    if total == 0:
        return {}

    distribution: Dict[int, float] = {}
    for biome_idx in BIOME_INDEX.values():
        count = sum(1 for b in biome_map.values() if b == biome_idx)
        distribution[biome_idx] = count / total

    # Round to 3 decimal places
    return {k: round(v, 3) for k, v in distribution.items()}


# ============== MAP EXPORT ==============

def export_map_to_binary(
    map_data: Dict[str, Any],
    output_path: str = "maps/sample_map.bmap",
) -> bool:
    """Export the generated map to binary format (.bmap)."""

    try:
        print(f"[Terrain Generator] Exporting map to {output_path}...")

        # Create parent directory if it doesn't exist
        dir_name = os.path.dirname(output_path)
        if dir_name:
            os.makedirs(dir_name, exist_ok=True)

        biome_data = map_data.get("biomes", {})
        map_info = {
            "width": MAP_SIZE,
            "height": MAP_SIZE,
            "biome_count": len(set(biome_data.values())),
            "version": 1,
        }

        # Write header and data (simplified)
        with open(output_path, 'wb') as f:
            # Header: magic number + version
            f.write(b'\x42\x4D\x41\x50')  # "BMAP"
            f.write((map_info["version"] & 0xFF).to_bytes(1))

            # Map dimensions
            f.write((map_info["width"] & 0xFF).to_bytes(1) +
                    (map_info["height"] & 0xFF).to_bytes(1))

            # Biome count and data would go here
            biomes_list = sorted([(k[0], k[1], v) for k, v in biome_data.items()])
            f.write(len(biomes_list).to_bytes(4))

            for _, _, biome_idx in biomes_list:
                f.write((biome_idx & 0xFF).to_bytes(1) +
                        (biome_idx >> 8 & 0xFF).to_bytes(1))

        print(f"[Terrain Generator] Successfully exported map: {output_path}")
        return True

    except Exception as exc:
        print(f"[Terrain Generator] Export failed: {exc}")
        return False


# ============== MAIN ENTRY POINT ==============

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Generate Fallen Earth terrain maps"
    )
    parser.add_argument(
        "-o", "--output",
        default="maps/sample_map.bmap",
        help="Output path for the map file",
    )

    args = parser.parse_args()

    print("=" * 60)
    print("FALLEN EARTH TERRAIN GENERATOR v1.0")
    print("=" * 60)
    print()

    # Generate the terrain map
    map_data, metadata = generate_terrain_map()

    print()
    print(f"[Terrain Generator] Map Generation Complete!")
    print(f"  Biomes: {metadata['biome_count']} unique types")
    print(f"  Tiles: {metadata['total_tiles']} total tiles")
    print(f"  Features: {metadata['unique_features']} unique terrain features")

    # Export to binary format
    if export_map_to_binary(map_data, args.output):
        print()
        print("[Terrain Generator] Ready for import into Fallen Earth!")
