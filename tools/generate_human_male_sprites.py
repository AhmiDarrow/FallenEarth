#!/usr/bin/env python3
"""Generate a basic human male sprite via PixelLab API."""

import base64
import io
import requests
from pathlib import Path
from PIL import Image

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
BASE_URL = "https://api.pixellab.ai/v2"
HEADERS = {"Authorization": f"Bearer {API_KEY}", "Content-Type": "application/json"}

OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "characters" / "human_male"
OUT_DIR.mkdir(parents=True, exist_ok=True)

prompt = (
    "top-down pixel art human male, bare skin in underwear only, "
    "no armor no weapons no clothing, simple base character sprite, "
    "2.5D game character facing south, post-apocalyptic wasteland palette, "
    "rust, dust brown, pallid skin, subtle eldritch cyan undertone, "
    "consistent pixel art style"
)

payload = {
    "description": prompt,
    "image_size": {"width": 128, "height": 128},
    "no_background": True,
    "view": "low top-down",
    "direction": "south",
}

print("Generating base sprite...")
r = requests.post(f"{BASE_URL}/create-image-pixflux", json=payload, headers=HEADERS, timeout=120)
print(f"Status: {r.status_code}")
if r.status_code != 200:
    print(f"Response: {r.text[:500]}")
r.raise_for_status()
data = r.json()
img_data = data["image"]["base64"]
raw = base64.b64decode(img_data)
img = Image.open(io.BytesIO(raw)).convert("RGBA")

out_path = OUT_DIR / "human_male_base.png"
img.save(out_path, "PNG")
print(f"Saved: {out_path} ({img.size[0]}x{img.size[1]})")
