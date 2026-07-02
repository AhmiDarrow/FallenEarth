#!/usr/bin/env python3
"""Verify script - checks module can be imported and instantiated."""
import sys
sys.path.insert(0, r'C:\Users\Administrator\FallenEarth')

from scripts.character_archetypes import (
    get_archetype, Scavenger, Technician, Survivor,
    AVAILABLE_ARCHETYPES
)

# Test factory function
print(f"✓ Factory function works: {type(get_archetype('scavenger')).__name__}")

# Test direct instantiation
s = Scavenger()
t = Technician()
sv = Survivor()