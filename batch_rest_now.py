#!/usr/bin/env python3
"""Submit a large batch for the absolute rest using the currently working basic direct graph."""
import requests
import time
import json

BASE = open("comfyui_workflows/handdrawn_master_prompt.txt").read().strip()
NEG = "blurry, deformed, text, pixel art, realistic"

def basic_payload(pos, prefix, bsz=2):
    return {
        "1": {"inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}, "class_type": "CheckpointLoaderSimple"},
        "2": {"inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.12, "strength_clip": 0.05}, "class_type": "LoraLoader"},
        "3": {"inputs": {"text": pos, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEG, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": bsz}, "class_type": "EmptyLatentImage"},
        "6": {"inputs": {"seed": int(time.time() * 1000) % 1000000000, "steps": 22, "cfg": 6.5, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0]}, "class_type": "KSampler"},
        "7": {"inputs": {"samples": ["6", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
        "8": {"inputs": {"filename_prefix": f"FallenEarth_Handdrawn/{prefix}", "images": ["7", 0]}, "class_type": "SaveImage"},
    }

def q(pos, pre, b=2):
    r = requests.post("http://127.0.0.1:8188/prompt", json={"prompt": basic_payload(pos, pre, b)}, timeout=20)
    if r.ok:
        print("QUEUED", pre, r.json().get("prompt_id"))
        return True
    print("FAIL", pre, r.status_code)
    return False

def main():
    print("Submitting large batch for the absolute rest...")

    # All 24 race+gender (priority for visual review)
    races_genders = [
        ("human", "male"), ("human", "female"), ("human", "nonbinary"),
        ("mutant", "male"), ("mutant", "female"), ("mutant", "nonbinary"),
        ("cyborg", "male"), ("cyborg", "female"), ("cyborg", "nonbinary"),
        ("sentientai", "male"), ("sentientai", "female"), ("sentientai", "nonbinary"),
        ("chthon", "male"), ("chthon", "female"), ("chthon", "nonbinary"),
        ("vesperid", "male"), ("vesperid", "female"), ("vesperid", "nonbinary"),
        ("nullborn", "male"), ("nullborn", "female"), ("nullborn", "nonbinary"),
        ("revenant", "male"), ("revenant", "female"), ("revenant", "nonbinary"),
    ]
    for race, gender in races_genders:
        for pose in ["front_idle", "side_idle"]:
            pos = BASE + f", exactly in the charming hand-drawn illustrated top-down 2.5D game asset style of the reference image (wooden platforms, cozy earthy hand-crafted look), isolated clean game sprite of grim post-apoc {race} {gender}, neutral simple underclothing only (rags or plain jumpsuit, NO armor NO mask NO gear), full body {pose} view, readable strong silhouette, front or side, no background no environment, matching the style of master_test_01.png exactly, high quality consistent sprite"
            q(pos, f"char_{race}_{gender}_{pose}", 2)
            time.sleep(0.3)

    # Tiles for all 10 biomes (at least some variety)
    biomes = ["ash_wastes", "rust_canyons", "neon_bogs", "scorched_plains", "ironwood_thicket", "glass_dunes", "toxin_marshes", "stormspire_highlands", "corpse_fields", "dead_city_outskirts"]
    cats = ["ground", "debris", "vegetation"]
    for b in biomes:
        for c in cats:
            pos = BASE + f", seamless top-down hex tile texture for {b.replace('_', ' ')} {c}"
            q(pos, f"tile_{b}_{c}", 3)
            time.sleep(0.2)

    print("Batch submitted. Watch the output folder and the generator logs.")

if __name__ == "__main__":
    main()