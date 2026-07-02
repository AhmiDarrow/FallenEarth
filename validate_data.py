#!/usr/bin/env python3
import json, os

base = r"C:\Users\Administrator\FallenEarth"

with open(f'{base}/data/races.json') as f:
    try:
        races = json.load(f)
        print('[races] VALID JSON ({} entries)'.format(len(races)))
        if 'upworld' in races and 'underworld' in races:
            print('  ✓ Has upworld ({}) + underworld ({})'.format(
                len(races['upworld']), len(races['underworld'])))
    except json.JSONDecodeError as e:
        print('[races] INVALID JSON - {}'.format(e))

with open(f'{base}/data/biomes.json') as f:
    try:
        biomes = json.load(f)
        print('[biomes] VALID JSON ({} entries)'.format(len(biomes)))
        if biomes and isinstance(biomes[0], dict):
            print('  ✓ First biome keys: {}'.format(list(biomes[0].keys())))
    except json.JSONDecodeError as e:
        print('[biomes] INVALID JSON - {}'.format(e))

with open(f'{base}/data/mobs.json') as f:
    try:
        mobs = json.load(f)
        print('[mobs] VALID JSON')
        for k, v in mobs.items():
            if isinstance(v, list):
                print('  {} array ({} entries)'.format(k, len(v)))
            elif isinstance(v, dict):
                print('  {} object ({})'.format(k, list(v.keys())))
    except json.JSONDecodeError as e:
        print('[mobs] INVALID JSON - {}'.format(e))

with open(f'{base}/data/character_classes.json') as f:
    try:
        classes = json.load(f)
        print('[classes] VALID JSON ({} entries)'.format(len(classes)))
        if classes and isinstance(classes[0], dict):
            print('  ✓ First class keys: {}'.format(list(classes[0].keys())))
    except json.JSONDecodeError as e:
        print('[classes] INVALID JSON - {}'.format(e))

print()
print('=== VALIDATION COMPLETE ===')