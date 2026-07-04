#!/usr/bin/env python3
"""Regenerate specific sprites with adjusted prompts, up to 10 concurrent requests."""

import base64
import io
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from PIL import Image

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}
CHAR_DIR = Path(__file__).resolve().parent.parent / "assets" / "characters"

REMAKE = {
    "revenant_male": {
        "race_hint": "revenant, scarred necrotic skin, spectral glow, post-apocalyptic",
        "gender_hint": "male, matching female revenant style, consistent build",
        "fix": "facing the camera front view, not from behind, character looks towards the viewer, forwards",
    },
}


def generate_one(label: str, cfg: dict) -> tuple[str, bool, str]:
    out_dir = CHAR_DIR / label
    out_path = out_dir / f"{label}_base.png"
    out_dir.mkdir(parents=True, exist_ok=True)

    prompt = (
        f"top-down pixel art {cfg['race_hint']}, {cfg['gender_hint']}, "
        f"{cfg['fix']}, "
        f"bare skin in underwear only, no armor no weapons no clothing, "
        f"simple base character sprite, 2.5D game character, "
        f"consistent pixel art style"
    )

    payload = {
        "description": prompt,
        "image_size": {"width": 128, "height": 128},
        "no_background": True,
        "view": "low top-down",
        "direction": "south",
    }

    try:
        r = requests.post(
            f"{BASE_URL}/create-image-pixflux",
            json=payload,
            headers=HEADERS,
            timeout=120,
        )
        if r.status_code != 200:
            return label, False, f"HTTP {r.status_code}: {r.text[:200]}"
        data = r.json()
        img_data = data["image"]["base64"]
        raw = base64.b64decode(img_data)
        img = Image.open(io.BytesIO(raw)).convert("RGBA")
        img.save(out_path, "PNG")
        return label, True, f"{out_path.name} ({img.size[0]}x{img.size[1]})"
    except Exception as e:
        return label, False, str(e)


def main():
    labels = list(REMAKE.keys())
    print(f"Regenerating {len(labels)} sprites (up to 10 concurrent)...\n")

    ok = 0
    fail = 0
    with ThreadPoolExecutor(max_workers=10) as pool:
        fut_map = {pool.submit(generate_one, label, REMAKE[label]): label for label in labels}
        for fut in as_completed(fut_map):
            label, success, msg = fut.result()
            status = "[OK]" if success else "[FAIL]"
            print(f"  {status} {label} — {msg}")
            if success:
                ok += 1
            else:
                fail += 1

    print(f"\nDone: {ok} succeeded, {fail} failed")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
