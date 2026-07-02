#!/usr/bin/env python3
"""Minimal verify script - just tests that the module can be imported."""
import sys
sys.path.insert(0, r'C:\Users\Administrator\FallenEarth')

try:
    from scripts.character_archetypes import get_archetype, Scavenger, AVAILABLE_ARCHETYPES
    print('✓ Import successful!')
    
    # Test basic instantiation
    s = get_archetype("scavenger")
    print(f'  Created archetype: {type(s).__name__}')
except ImportError as e:
    print(f'✗ Import failed: {e}')
    sys.exit(1)