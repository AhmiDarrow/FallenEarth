#!/usr/bin/env python3
"""Generate one base sprite per race×gender combo via PixelLab API.

Skips combos that already have a _base.png file.
"""

import base64
import io
import time
import requests
from pathlib import Path
from PIL import Image

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}

CHAR_DIR = Path(__file__).resolve().parent.parent / "assets" / "characters"

RACES = ["human", "mutant", "sentientai", "cyborg", "chthon", "vesperid", "nullborn", "revenant"]
GENDERS = ["male", "female"]

# Race-specific appearance hints for better prompt results
RACE_HINTS = {
    "human": "human, pale skin, post-apocalyptic wasteland",
    "mutant": "mutant, irradiated skin with glowing veins, hunched posture, post-apocalyptic",
    "sentientai": "sentient AI android, metallic skin with circuit lines, glowing eyes, post-apocalyptic",
    "cyborg": "cyborg, half-flesh half-metal, exposed机械 parts, post-apocalyptic",
    "chthon": "chthon, dark stone skin, crystalline growths, underground dweller, post-apocalyptic",
    "vesperid": "vesperid, pale elongated limbs, bioluminescent markings, post-apocalyptic",
    "nullborn": "nullborn, ethereal translucent skin, void-touched, post-apocalyptic",
    "revenant": "revenant, scarred necrotic skin, spectral glow, post-apocalyptic",
}

GENDER_HINTS = {
    "male": "male, broad shoulders, muscular build",
    "female": "female, softer features, feminine build",

}


def generate_sprite(race: str, gender: str) -> bool:
    out_dir = CHAR_DIR / f"{race}_{gender}"
    out_path = out_dir / f"{race}_{gender}_base.png"

    if out_path.exists():
        print(f"  [skip] {race}_{gender} — already exists")
        return True

    out_dir.mkdir(parents=True, exist_ok=True)

    race_hint = RACE_HINTS.get(race, race)
    gender_hint = GENDER_HINTS.get(gender, gender)

    prompt = (
        f"top-down pixel art {race_hint}, {gender_hint}, "
        f"bare skin in underwear only, no armor no weapons no clothing, "
        f"simple base character sprite, 2.5D game character facing south, "
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
        r = requests.post(f"{BASE_URL}/create-image-pixflux", json=payload, headers=HEADERS, timeout=120)
        if r.status_code != 200:
            print(f"  [FAIL] {race}_{gender} — HTTP {r.status_code}: {r.text[:200]}")
            return False
        data = r.json()
        img_data = data["image"]["base64"]
        raw = base64.b64decode(img_data)
        img = Image.open(io.BytesIO(raw)).convert("RGBA")
        img.save(out_path, "PNG")
        print(f"  [OK] {race}_{gender} — {out_path.name} ({img.size[0]}x{img.size[1]})")
        return True
    except Exception as e:
        print(f"  [FAIL] {race}_{gender} — {e}")
        return False


def main():
    total = len(RACES) * len(GENDERS)
    done = 0
    failed = 0

    print(f"Generating {total} race×gender combos...\n")

    for race in RACES:
        for gender in GENDERS:
            label = f"{race}_{gender}"
            if (CHAR_DIR / label / f"{label}_base.png").exists():
                print(f"  [skip] {label}")
                done += 1
                continue
            ok = generate_sprite(race, gender)
            if ok:
                done += 1
            else:
                failed += 1
            time.sleep(0.5)

    print(f"\nDone: {done}/{total} succeeded, {failed} failed")


if __name__ == "__main__":
    main()
