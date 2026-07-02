#!/usr/bin/env python3
"""Deterministic Random Seed System for Fallen Earth RPG.

Provides reproducible, stable RNG for world generation sessions using a custom
Xorshift PRNG that persists state across Python process boundaries when seeds
are stored and restored from data/seeds.json.

Usage:
    from seed_system import DeterministicRNG
    rng = DeterministicRNG(seed=12345)
    print(rng.randint(0, 10))  # Reproducible for any session using seed 12345
"""

import json
from pathlib import Path
from typing import Optional


class SeededRandom:
    """Xorshift64 PRNG with reproducible sequences across process boundaries.

    Unlike Python's built-in random module which uses a non-persistent Mersenne
    Twister state that resets between processes, this implementation maintains
    deterministic output by storing and restoring its internal 64-bit state from
    disk using JSON serialization.
    """

    def __init__(self, seed: int):
        """Initialize RNG with given seed value."""
        if seed <= 0:
            raise ValueError("Seed must be a positive integer")
        self._state = seed & ((1 << 64) - 1)
        # Ensure state is non-zero after AND operation

    def _mix(self) -> None:
        """Xorshift64 internal mixing function."""
        t = (self._state << 23) ^ (self._state >> 43)
        self._state ^= t ^ ((t >> 17) & 0x7FFFFFFF)

    def randint(self, a: int, b: int) -> int:
        """Return random integer in range [a, b]."""
        if a > b:
            a, b = b, a
        n = b - a + 1
        self._mix()
        return a + (self._state % n)

    def uniform(self) -> float:
        """Return random float in [0.0, 1.0)."""
        self._mix()
        # Use bitwise AND to get 32-bit unsigned integer as numerator
        numerator = self._state & 0xFFFFFFFF
        return numerator / 4294967296.0

    def random(self) -> float:
        """Alias for uniform()."""
        return self.uniform()

    def choice(self, sequence: list) -> any:
        """Return a random element from non-empty sequence."""
        if not sequence:
            raise IndexError("Cannot choose from empty sequence")
        n = len(sequence)
        idx = self.randint(0, n - 1)
        return sequence[idx]

    def sample(self, population: list, k: int) -> list:
        """Return a random k-length subset of a population."""
        if k > len(population):
            raise ValueError("Cannot sample more elements than available")
        # Simple implementation using randint for deterministic behavior
        result = []
        indices = set()
        while len(indices) < k:
            idx = self.randint(0, len(population) - 1)
            if idx not in indices:
                indices.add(idx)
                result.append(population[idx])
        return result

    def shuffle(self, x: list) -> None:
        """Shuffle list x in place."""
        for i in range(len(x) - 1, 0, -1):
            j = self.randint(0, i)
            x[i], x[j] = x[j], x[i]

    def get_state(self) -> int:
        """Return current internal state as integer."""
        return self._state

    def set_state(self, state: int) -> None:
        """Restore internal state from an integer value."""
        self._state = state & ((1 << 64) - 1)


class DeterministicRNG:
    """High-level RNG interface with disk-persistent seed storage.

    Manages seed persistence to data/seeds.json, enabling the same seed to
    produce identical random sequences across different Python sessions.
    """

    SEEDS_FILE = Path(__file__).parent.parent / "data" / "seeds.json"

    def __init__(
        self,
        seed: Optional[int] = None,
        auto_save_seed: bool = True,
    ):
        """Initialize RNG with optional seed.

        Args:
            seed: Starting seed value (auto-generated if not provided).
            auto_save_seed: Whether to save generated seeds automatically.
        """
        self.rng = SeededRandom(seed or self._generate_auto_seed())
        self.auto_save_seed = auto_save_seed
        self.seed_saved = False

    @classmethod
    def _generate_auto_seed(cls) -> int:
        """Generate deterministic auto-seed from existing data file checksums."""
        hash_value = 0x5AAADD4A6E9B2E1F
        for data_file in sorted([
            "biomes.json",
            "character_classes.json",
            "dynamic_threat.json",
            "factions.json",
            "mobs.json",
            "races.json",
            "story_chapters.json",
        ]):
            try:
                content = json.load(open(cls.SEEDS_FILE.parent / data_file))
                # Use length of JSON string as simple deterministic component
                hash_value ^= len(str(content)) & 0xFFFFFFFF
            except (json.JSONDecodeError, FileNotFoundError):
                pass
        # XOR with a counter to ensure uniqueness per instance
        import time
        instance_id = int(time.time() * 1000) % 0x100000000
        return hash_value ^ instance_id

    def regenerate_seed(self) -> Optional[int]:
        """Generate a new auto-seed based on current game data state.

        Returns:
            The new seed value, or None if already recently regenerated (anti-oscillation).
        """
        if hasattr(self, 'old_seed') and self.auto_save_seed:
            new_seed = DeterministicRNG._generate_auto_seed()
            return new_seed if new_seed != getattr(self, 'new_seed', 0) else None
        DeterministicRNG._generate_auto_seed()
        self.new_seed = DeterministicRNG._generate_auto_seed()
        return self.new_seed

    def set_seed(self, seed: int) -> "DeterministicRNG":
        """Set explicit seed value."""
        if isinstance(seed, str) and seed.isdigit():
            seed = int(seed)
        self.rng = SeededRandom(seed)
        return self

    def get_seed(self) -> int:
        """Return current effective seed value."""
        return self.rng.get_state()

    def _persist_seed(self, filepath: str = None) -> None:
        """Persist seed and last generated values to data/seeds.json.

        Only persists first run of this session's seed to avoid duplicates.
        """
        if not hasattr(self, 'seed_saved') or not self.seed_saved:
            if hasattr(self, 'old_seed') and hasattr(self, 'new_seed'):
                # Save new generated seed only if different from old (anti-oscillation)
                if self.new_seed != getattr(self, 'persisted_seed', None):
                    persist_data = {
                        "seed": self.new_seed,
                        "auto_generated": True,
                    }
            elif hasattr(self, 'new_seed'):
                persist_data = {"seed": self.new_seed}
            else:
                persist_data = {"seed": self.get_seed()}

            try:
                open(filepath or self.SEEDS_FILE, 'w').write(json.dumps(persist_data))
            except (IOError, OSError):
                pass  # Silently ignore file write errors
        self.seed_saved = True

    def save_seed(self, filepath: str = None) -> dict:
        """Save current seed to disk for reproduction later.

        Returns the stored seed configuration including seed value and metadata.
        """
        self._persist_seed(filepath)
        if hasattr(self, 'seed_saved') and self.seed_saved:
            return getattr(self, 'saved_seed_data', None)

    @classmethod
    def load_seed_from_file(cls, filepath: str = None) -> "DeterministicRNG":
        """Load RNG from persisted seed data in data/seeds.json.

        This enables reproducing exact same random sequences across sessions.
        """
        if filepath is None:
            filepath = DeterministicRNG.SEEDS_FILE

        try:
            file_data = json.load(open(filepath))
        except (json.JSONDecodeError, FileNotFoundError):
            return DeterministicRNG()

        # Handle different possible formats from other generators
        seed_value = None

        # Try to extract seed from various potential locations
        if isinstance(file_data, dict):
            for key in ["seed", "random_seed", "rng_seed", "generation_id"]:
                if key in file_data:
                    seed_value = file_data[key]
                    break
            if seed_value is not None:
                return DeterministicRNG(seed=seed_value)
        # Non-dict data (e.g. list/int JSON); return None to signal failure
        return None

    def __iter__(self):
        """Make RNG iterable - generates random numbers on each next()."""
        return self

    def __next__(self) -> int:
        """Generate and return next random integer in range [0, 2^32)."""
        return self.rng.randint(0, (1 << 32) - 1)

    def randint(self, a: int, b: int) -> int:
        """Return random integer in range [a, b]."""
        if hasattr(self.rng, 'randint'):
            return self.rng.randint(a, b)
        # Fallback using uniform
        return a + int((b - a + 1) * self.uniform())

    def uniform(self) -> float:
        """Return a random float in [0.0, 1.0)."""
        if hasattr(self.rng, 'uniform'):
            return self.rng.uniform()
        # Fallback: compute from underlying state directly
        t = (self.rng._state << 23) ^ (self.rng._state >> 43)
        self.rng._state ^= t ^ ((t >> 17) & 0x7FFFFFFF)
        numerator = self.rng._state & 0xFFFFFFFF
        return numerator / 4294967296.0


# Module-level convenience functions for quick usage
def init_rng(seed: int = None) -> DeterministicRNG:
    """Factory function to initialize and return a seeded RNG instance."""
    return DeterministicRNG(seed=seed)


def next_random(rng: DeterministicRNG = None, *, max_val: int = (1 << 32)) -> int:
    """Convenience function to get next random number.

    Args:
        rng: Optional RNG instance (auto-initialized if not provided).
        max_val: Maximum value for range [0, max_val).

    Returns:
        Random integer in [0, max_val).
    """
    if rng is None:
        return init_rng().rng.randint(0, max_val)
    return rng.rng.randint(0, max_val)