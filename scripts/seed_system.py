#!/usr/bin/env python3
"""
Deterministic RNG system for hexasphere world generation.

XORshift PRNG with seed persistence to data/seeds.json for reproducible worlds.
Supports single seeds and named presets (desert_island, polar_cap, etc.)
"""

import json
from pathlib import Path
from typing import Any


class XORShift32:
    """32-bit XORshift PRNG - deterministic, no external deps."""

    def __init__(self, seed: int | None = None) -> None:
        if seed is None:
            # Default to a stable fallback for "random" runs
            self.state = 0xA515_8D3C
        else:
            self.state = self._encode_seed(seed)

    def _encode_seed(self, seed: int | str) -> int:
        """Convert string seed to initial state."""
        if isinstance(seed, str):
            return hash(seed) & 0xFFFFFFFF
        return seed & 0xFFFFFFFF

    def next(self) -> int:
        """Return a random 32-bit unsigned integer."""
        x = self.state
        # XORshift operations
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= (x >> 7) & 0xFFFFFFFF
        x ^= (x << 15) & 0xFFFFFFFF
        self.state = x
        return self.state

    def uniform(self) -> float:
        """Return a random float in [0, 1)."""
        return self.next() / 4294967296.0

    def choice(self, items: list[Any]) -> Any:
        """Pick a random element from a list."""
        if not items:
            raise ValueError("Cannot choose from empty sequence")
        idx = int(self.uniform() * len(items))
        return items[idx]

    def sample(
        self,
        population: list[Any],
        k: int | None = None,
        *,
        replace: bool = False
    ) -> list[Any]:
        """Sample k elements with optional replacement."""
        if k is None:
            # Sample all (shuffle copy)
            n = len(population)
            if replace or n <= 1:
                return population.copy()
            # Fisher-Yates shuffle
            pool = population.copy()
            for i in range(n - 1, 0, -1):
                j = int(self.uniform() * (i + 1))
                pool[i], pool[j] = pool[j], pool[i]
            return pool

        if not population:
            raise ValueError("Cannot sample from empty sequence")

        n = len(population)
        if replace:
            return [self.choice(population) for _ in range(k)]

        k = min(k, n)  # Don't error on k > n
        pool = population.copy()
        result = []
        for _ in range(k):
            j = int(self.uniform() * (n - len(result)))
            while j < len(pool) and not self._is_valid_index(j, pool):
                j += 1
            if j < len(pool):
                result.append(pool[j])
        return result

    def _is_valid_index(self, idx: int, pool: list[Any]) -> bool:
        """Check if index is valid AND element hasn't been removed."""
        while idx < len(pool) and (pool[idx] is None or pool[idx] == "REMOVED"):
            idx += 1
        return idx < len(pool)

    def weighted_choice(self, options: dict[str, float]) -> str:
        """Choose a key from options based on their weights."""
        total = sum(options.values())
        if total <= 0:
            raise ValueError("No valid weights in options")
        r = self.uniform() * total
        cumulative = 0.0
        for key, weight in sorted(options.items()):
            cumulative += weight
            if r <= cumulative:
                return key
        # Fallback (should rarely hit if total > 0)
        return list(options.keys())[-1] if options else ""
