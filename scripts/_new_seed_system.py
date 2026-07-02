#!/usr/bin/env python3
"""Deterministic random seed system for Fallen Earth RPG."""
import json
from pathlib import Path


class XORShift:
    """XORshift32 PRNG - deterministic, reproducible random numbers from a given seed."""

    def __init__(self, seed):
        self.state = seed & 0xFFFFFFFF or 1

    def next(self) -> int:
        if self.state == 0:
            self.state = 1
        s = self.state
        s ^= (s << 5)
        s ^= (s >> 29)
        s ^= ((s & 1) << 31)
        self.state = s or 1
        return self.state

    def randint(self, low: int, high: int) -> int:
        """Return random integer in range [low, high]."""
        if high < low:
            raise ValueError("high must be >= low")
        return low + (self.next() % (high - low + 1))

    def choice(self, seq):
        """Pick a random element from non-empty sequence."""
        if not seq:
            raise IndexError("choice from empty sequence")
        return seq[self.randint(0, len(seq) - 1)]


class SeedSystem:
    """Persistent deterministic RNG system with per-category seeds."""

    SEED_FILE = Path(__file__).parent.parent / "data" / "seeds.json"

    def __init__(self):
        self.rng = XORShift(99887766)

    def _load_seed(self, category):
        try:
            data = self.SEED_FILE.read_text()
            stored = json.loads(data) if data.strip() else {}
            return stor