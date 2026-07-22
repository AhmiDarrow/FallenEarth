#!/usr/bin/env python3
"""Download PixelLab Wang tilesets from catalog into assets/tilesets/<biome>/wang/."""
from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from pathlib import Path

import os
API = os.environ.get("PIXELLAB_API_KEY", "0f2b1429-289e-4ce2-bddb-5ed4a460619d")
BASE = "https://api.pixellab.ai/mcp/tilesets"
PROJECT = Path(r"C:\Users\Administrator\FallenEarth")
CATALOG = PROJECT / "tools" / "pixellab_tileset_catalog.json"
HEADERS = {
    "Authorization": f"Bearer {API}",
    "User-Agent": "FallenEarth-wang-download/1.0",
    "Accept": "*/*",
}

# Skip superseded / lava-cliff / non-MVP entries
SKIP_IDS = {
    "bff069e5-5fd5-4ca9-8e0e-ad19e59a7333",  # old muddy water
    "aa0ac765-a54b-4e2b-9be5-11077a156e29",  # old unchained water
    "bf59d255-3a31-45b3-a289-ae510e1a9724",  # lava cliff water
    "0a68bddc-074c-45fc-8a46-a372f0943822",  # 25 cliff skip
    "01a09e4a-0410-4f50-86b9-d769642a7b7d",  # 25 cliff skip
}


def download(url: str, dest: Path) -> bool:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 100:
        print(f"  skip exists {dest.relative_to(PROJECT)}")
        return True
    req = urllib.request.Request(url, headers=HEADERS)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = resp.read()
    except urllib.error.HTTPError as e:
        print(f"  FAIL HTTP {e.code} {url}")
        return False
    except Exception as e:
        print(f"  FAIL {e} {url}")
        return False
    if len(data) < 50:
        print(f"  FAIL tiny response {len(data)}B {url}")
        return False
    dest.write_bytes(data)
    print(f"  ok {dest.relative_to(PROJECT)} ({len(data)}B)")
    return True


def main() -> int:
    cat = json.loads(CATALOG.read_text(encoding="utf-8"))
    tilesets = cat.get("tilesets", {})
    ok = 0
    fail = 0
    for tid, info in tilesets.items():
        if tid in SKIP_IDS or info.get("mvp") is False:
            print(f"SKIP {tid[:8]} {info.get('name', '')}")
            continue
        biomes = info.get("biomes") or []
        stem = info.get("stem")
        if not biomes or not stem:
            print(f"SKIP {tid[:8]} no biomes/stem ({info.get('name', '')})")
            continue
        name = str(info.get("name", "")).replace("\u2192", "->")
        print(f"GET {tid[:8]} stem={stem} biomes={biomes} - {name}")
        # Download once to temp, then copy to each biome
        cache = PROJECT / "tools" / "_wang_cache" / tid
        img = cache / "image.png"
        meta = cache / "metadata.json"
        img_ok = download(f"{BASE}/{tid}/image", img)
        time.sleep(0.15)
        meta_ok = download(f"{BASE}/{tid}/metadata", meta)
        time.sleep(0.15)
        if not (img_ok and meta_ok):
            fail += 1
            continue
        for biome in biomes:
            out_dir = PROJECT / "assets" / "tilesets" / biome / "wang"
            out_img = out_dir / f"{stem}_image.png"
            out_meta = out_dir / f"{stem}_metadata.json"
            out_dir.mkdir(parents=True, exist_ok=True)
            out_img.write_bytes(img.read_bytes())
            out_meta.write_bytes(meta.read_bytes())
            print(f"  → {biome}/wang/{stem}_*")
            ok += 1
    print(f"\nDone installs={ok} fails={fail}")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
