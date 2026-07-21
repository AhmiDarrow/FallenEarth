#!/usr/bin/env python3
"""Download completed PixelLab resource node objects to assets/sprites/resource_nodes/"""
import os
import requests
import time

PROJECT = r"C:\Users\Administrator\FallenEarth"
SPRITE_DIR = os.path.join(PROJECT, "assets", "sprites", "resource_nodes")
os.makedirs(SPRITE_DIR, exist_ok=True)

# Map: (object_id, sprite_filename)
DOWNLOADS = [
    # Trees
    ("1bf60712-4552-4a88-a6b6-c3109c99b639", "tree_withered_oak"),
    ("839a13fa-1003-46b8-82d2-35f97bd80b7b", "tree_withered_oak_alt"),
    ("76b4e95f-49d0-45cf-ac79-3bd4d3e59398", "tree_pine"),
    ("12f1d413-057d-4d15-950c-126cae1f688e", "tree_pine_alt"),
    ("9b97a94f-a66a-4b37-9032-e8d7df7519a1", "tree_ironwood"),
    ("efa98cb1-4252-4413-bd83-7deebb7c8a86", "tree_ironwood_alt"),
    ("1f0115ec-3168-4e77-8376-7595e813397a", "tree_glass_cactus"),
    ("508c8bac-ffe2-4152-9c2f-cc3c3fe64bf6", "tree_glass_cactus_alt"),
    # Ores
    ("85b97af4-5bf0-48fb-a097-358491154273", "ore_iron"),
    ("9d8f6d98-e1f8-457d-a191-336bc3f4f932", "ore_iron_alt"),
    ("2c14ec92-ce72-4dfa-99a9-e2a41622112a", "ore_copper"),
    ("8043b550-38da-4495-b8db-fce024c2a5ca", "ore_copper_alt"),
    ("5d899bf0-b613-489a-8e6a-03b119d16160", "ore_starmetal"),
    ("f876db52-3935-4546-aefb-13b0db063ea8", "ore_starmetal_alt"),
    # Crystals
    ("ecdc6340-6189-4877-a89b-9d2a46a51def", "crystal_teal"),
    ("90a9b260-14ea-40b4-b818-d594184e7fee", "crystal_teal_alt"),
    ("d5ee72eb-1b6a-4c88-acd1-c78647c5e839", "crystal_void"),
    ("7683a673-23bc-4189-8d7d-48cdd9824fd6", "crystal_void_alt"),
    # Formations
    ("fd74c401-3630-430c-b15b-53a54a791b43", "formation_rust_pipe"),
    ("8ac29687-67ee-49ec-8ac6-f34161b30b87", "formation_rust_pipe_alt"),
]

API_BASE = "https://api.pixellab.ai/mcp/objects"

for obj_id, sprite_name in DOWNLOADS:
    url = f"{API_BASE}/{obj_id}/download"
    out_path = os.path.join(SPRITE_DIR, f"{sprite_name}.png")
    if os.path.exists(out_path):
        print(f"  SKIP (exists): {sprite_name}")
        continue
    print(f"  Downloading {sprite_name}...")
    try:
        r = requests.get(url, timeout=30)
        if r.status_code == 200:
            with open(out_path, "wb") as f:
                f.write(r.content)
            print(f"    OK ({len(r.content)} bytes)")
        else:
            print(f"    FAIL: HTTP {r.status_code}")
    except Exception as e:
        print(f"    ERROR: {e}")
    time.sleep(0.3)

print(f"\nDone. Files in {SPRITE_DIR}")
