#!/usr/bin/env python3
"""
Heightmap module: Provides deterministic generation of 2D height data for world chunks
using a provided RNG object.
Requires seed_system.py to be imported and passed an XORShift32 instance.
"""
from scripts.seed_system import XORShift32
from typing import Tuple

def generate_heightmap(rng: XORShift32, dimensions: tuple[int, int]) -> dict[str, float] | None:
    """Generates a height map dictionary based on the provided seed RNG."""
    
    print("🌐 Generating Heightmap...")
    if dimensions[0] <= 0 or dimensions[1] <= 0:
        print("ERROR: Dimensions must be positive.")
        return None

    # Dictionary keys are "x,y" strings for easy lookup. Values are height floats [0, 1].
    heightmap_data = {}
    w, h = dimensions

    # Simple pseudo-noise generation based on the seed and location (x, y)
    for x in range(w):
        for y in range(h):
            # Use a derived value from RNG to ensure determinism per coordinate
            key_seed = rng.next() ^ (x * 0xFFB) ^ (y * 0xFFA)
            rng.state = key_seed # Reset state temporarily for repeatable noise calculation
            height = rng.uniform() * 1.0 + ((x % 5) / w * 0.1) # Introduce a slight gradient based on X

            # Clamp height between valid range [0, 1]
            final_height = max(0.0, min(1.0, height))
            heightmap_data[f'{x},{y}'] = final_height
            
    print(f"✅ Heightmap successfully generated for {w}x{h}.")
    return heightmap_data