#!/usr/bin/env python3
"""
Generate the absolute rest of hand-drawn assets for FallenEarth using local ComfyUI.
Uses direct prompt construction (reliable) + master ref IPAdapter where possible.
Tiles for all 10 biomes (complete sets), all 24 race+gender chars (multiple poses), equipment, UI, props, rifts, backgrounds.
Run after comfy server up. Outputs copied to assets/...
Master style ref must be in Comfy input as master_style.png
"""

import os
import time
import json
import shutil
import requests
import subprocess
import sys
from glob import glob

COMFY_DIR = r"C:\Users\Administrator\Documents\comfy\ComfyUI"
OUTPUT_DIR = os.path.join(COMFY_DIR, "output")
PROJECT_DIR = r"C:\Users\Administrator\FallenEarth"
ASSETS_DIR = os.path.join(PROJECT_DIR, "assets")
COMFY_URL = "http://127.0.0.1:8188"

os.makedirs(os.path.join(ASSETS_DIR, "tilesets"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, "characters"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, "equipment"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, "ui"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, "props_mobs"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, "rifts"), exist_ok=True)
os.makedirs(os.path.join(ASSETS_DIR, "backgrounds"), exist_ok=True)

BIOMES = [
    "ash_wastes", "rust_canyons", "neon_bogs", "scorched_plains",
    "ironwood_thicket", "glass_dunes", "toxin_marshes", "stormspire_highlands",
    "corpse_fields", "dead_city_outskirts"
]

RACES_GENDERS = [
    ("human", "male"), ("human", "female"), ("human", "nonbinary"),
    ("mutant", "male"), ("mutant", "female"), ("mutant", "nonbinary"),
    ("cyborg", "male"), ("cyborg", "female"), ("cyborg", "nonbinary"),
    ("sentientai", "male"), ("sentientai", "female"), ("sentientai", "nonbinary"),
    ("chthon", "male"), ("chthon", "female"), ("chthon", "nonbinary"),
    ("vesperid", "male"), ("vesperid", "female"), ("vesperid", "nonbinary"),
    ("nullborn", "male"), ("nullborn", "female"), ("nullborn", "nonbinary"),
    ("revenant", "male"), ("revenant", "female"), ("revenant", "nonbinary"),
]

POSES = ["front_idle", "side_idle", "back_idle", "front_walk_1", "front_walk_2", "attack", "hurt"]

MASTER_PROMPT_BASE = (
    "2D hand-drawn illustrated style like the reference image, top-down 2.5D game assets, "
    "charming yet gritty post-apocalyptic sci-fi Earth IV wasteland, cozy grim survival with cosmic horror elements, "
    "detailed hand-crafted look with wooden structures, earthy tones, green vegetation, "
    "muted color palette: rusty oranges, deep reds, toxic greens, void blues, warm browns, soft atmospheric lighting, "
    "readable silhouettes for tiles and sprites, no characters, no text, high quality consistent game art"
)

NEGATIVE = "blurry, deformed, text, watermark, people, characters, oversaturated, low contrast, flat lighting, pixel art, 8bit, lowres, cartoon, realistic, photo"

def wait_server(timeout=180):
    print("Waiting for ComfyUI server...")
    for _ in range(timeout):
        try:
            r = requests.get(f"{COMFY_URL}/system_stats", timeout=3)
            if r.status_code == 200:
                print("Server up!")
                time.sleep(20)  # models load time
                return True
        except:
            pass
        time.sleep(2)
    print("Server not responding in time.")
    return False

def fix_status():
    # patch status code attr
    pass

def build_tile_prompt(biome: str, category: str) -> str:
    biome_desc = {
        "ash_wastes": "barren toxic dust plains, cracked earth, irradiated scrub",
        "rust_canyons": "deep rusted canyons, wrecked metal, unstable rock",
        "neon_bogs": "glowing polluted wetlands, bioluminescent flora, toxic neon",
        "scorched_plains": "cracked baked earth, heat haze, sparse dead grass",
        "ironwood_thicket": "dense twisted ironwood trees, metallic foliage",
        "glass_dunes": "shimmering glass sand dunes, reflective shards",
        "toxin_marshes": "bubbling toxin pools, mutated reeds, sickly vapors",
        "stormspire_highlands": "wind swept rocky highlands, lightning struck spires",
        "corpse_fields": "bone and wreck littered fields, eerie fog",
        "dead_city_outskirts": "ruined concrete outskirts, collapsed buildings, rebar",
    }.get(biome, "wasteland terrain")
    return (
        f"{MASTER_PROMPT_BASE}, seamless top-down hex tileable texture for {biome.replace('_',' ')}, "
        f"{biome_desc}, {category} features, consistent hand-drawn style, tile friendly for Godot hex TileMap"
    )

def build_char_prompt(race: str, gender: str, pose: str) -> str:
    return (
        f"{MASTER_PROMPT_BASE}, grim post-apocalyptic hand-drawn {race} {gender}, top-down 2.5D game sprite, "
        f"baseline {race} features, neutral underclothing (rags or simple jumpsuit, no armor/class), "
        f"consistent character design, {pose} pose, readable silhouette, high quality hand-drawn game asset, no equipment"
    )

def build_equipment_prompt(slot: str, name: str) -> str:
    return f"{MASTER_PROMPT_BASE}, hand-drawn post-apoc equipment layer, {slot} slot: {name}, neutral fit on base sprite, detailed but simple, readable, muted tones"

def queue_direct(prompt_text: str, prefix: str, batch_size: int = 4):
    """Direct node graph with IPAdapter + master ref for style cohesion. Low LoRA."""
    # Nodes designed to match handdrawn_*_workflow structure
    prompt = {
        "1": {"inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}, "class_type": "CheckpointLoaderSimple"},
        "2": {"inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.15, "strength_clip": 0.08}, "class_type": "LoraLoader"},
        "3": {"inputs": {"text": prompt_text, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEGATIVE, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": batch_size}, "class_type": "EmptyLatentImage"},
        "6": {"inputs": {"image": "master_style.png"}, "class_type": "LoadImage"},  # ref
        "7": {"inputs": {"ipadapter_name": "ip-adapter_sdxl.bin"}, "class_type": "IPAdapterModelLoader"},
        "8": {"inputs": {
            "model": ["2", 0],
            "ipadapter": ["7", 0],
            "image": ["6", 0],
            "weight": 0.82,
            "start_at": 0.0,
            "end_at": 1.0,
            "weight_type": "standard"
        }, "class_type": "IPAdapter"},
        "9": {"inputs": {
            "seed": int(time.time() * 1000) % 1000000000,
            "steps": 26,
            "cfg": 6.5,
            "sampler_name": "euler",
            "scheduler": "normal",
            "denoise": 1.0,
            "model": ["8", 0],  # IP out
            "positive": ["3", 0],
            "negative": ["4", 0],
            "latent_image": ["5", 0]
        }, "class_type": "KSampler"},
        "10": {"inputs": {"samples": ["9", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
        "11": {"inputs": {"filename_prefix": f"FallenEarth_Handdrawn/{prefix}", "images": ["10", 0]}, "class_type": "SaveImage"},
    }
    try:
        r = requests.post(f"{COMFY_URL}/prompt", json={"prompt": prompt}, timeout=30)
        if r.status_code == 200:
            pid = r.json().get("prompt_id")
            print(f"  Queued {prefix} pid={pid}")
            return pid
        else:
            print(f"  Queue fail {prefix}: {r.status_code} {r.text[:120]}")
    except Exception as e:
        print(f"  Queue error {prefix}: {e}")
    return None

def wait_and_copy(pids, label, dest_subdir, prefix_filter):
    print(f"Waiting on {len(pids)} for {label}...")
    done = set()
    t0 = time.time()
    while len(done) < len(pids) and time.time() - t0 < 900:
        try:
            hist = requests.get(f"{COMFY_URL}/history", timeout=10).json()
            for pid in list(pids.keys()):
                if pid in hist and pid not in done:
                    done.add(pid)
                    print(f"  {label} {pids[pid]} complete")
        except:
            pass
        time.sleep(8)
    # Copy outputs
    copied = 0
    for fn in os.listdir(OUTPUT_DIR):
        if fn.lower().endswith(('.png', '.jpg')) and prefix_filter in fn:
            src = os.path.join(OUTPUT_DIR, fn)
            dst_dir = os.path.join(ASSETS_DIR, dest_subdir)
            os.makedirs(dst_dir, exist_ok=True)
            shutil.copy(src, os.path.join(dst_dir, fn))
            copied += 1
    print(f"Copied ~{copied} to {dest_subdir}")

def generate_tiles():
    print("\n=== Generating full tiles for all biomes ===")
    categories = ["ground", "debris", "vegetation", "transition", "rift"]
    all_pids = {}
    for biome in BIOMES:
        for cat in categories:
            for variant in range(3):  # 3 per type for choice
                pr = build_tile_prompt(biome, cat)
                pid = queue_direct(pr, f"tile_{biome}_{cat}_v{variant}", batch_size=4)
                if pid:
                    all_pids[pid] = f"{biome}_{cat}_{variant}"
                time.sleep(1.5)
    # Wait and copy later in batches or all at end
    return all_pids

def generate_characters():
    print("\n=== Generating full race+gender character bases (neutral) ===")
    all_pids = {}
    for race, gender in RACES_GENDERS:
        folder = f"{race}_{gender}"
        os.makedirs(os.path.join(ASSETS_DIR, "characters", folder), exist_ok=True)
        for pose in POSES:
            pr = build_char_prompt(race, gender, pose)
            pid = queue_direct(pr, f"char_{folder}_{pose}", batch_size=3)
            if pid:
                all_pids[pid] = f"{folder}_{pose}"
            time.sleep(1)
    return all_pids

def generate_equipment_ui_etc():
    print("\n=== Generating equipment layers, UI, props, rifts, backgrounds ===")
    pids = {}
    # Equipment examples (expand as needed)
    equip = [("head", "scav_helm"), ("torso", "leather_tunic"), ("legs", "reinforced_pants"), ("weapon", "pipe_wrench"), ("back", "rucksack")]
    for slot, name in equip:
        pr = build_equipment_prompt(slot, name)
        pid = queue_direct(pr, f"equip_{slot}_{name}", 3)
        if pid: pids[pid] = name
        time.sleep(1)

    # UI elements
    for ui_name in ["button", "panel", "icon_scrap", "health_bar", "rift_marker"]:
        pr = MASTER_PROMPT_BASE + f", clean hand-drawn UI element {ui_name} for post-apoc menu, readable icon"
        pid = queue_direct(pr, f"ui_{ui_name}", 2)
        if pid: pids[pid] = ui_name

    # Props / mobs simple
    for mob in ["feral_scavenger", "rift_horror", "ash_crawler"]:
        pr = MASTER_PROMPT_BASE + f", hand-drawn top-down mob {mob}, readable silhouette, gritty wasteland creature"
        pid = queue_direct(pr, f"mob_{mob}", 3)
        if pid: pids[pid] = mob

    # Rifts + backgrounds
    for rname in ["rift_entrance", "rift_interior_crack"]:
        pr = MASTER_PROMPT_BASE + f", hand-drawn rift portal {rname}, glowing fissures, cosmic horror"
        pid = queue_direct(pr, f"rift_{rname}", 2)
        if pid: pids[pid] = rname

    pr = MASTER_PROMPT_BASE + ", hand-drawn menu background wasteland vista, atmospheric distant ruins"
    pid = queue_direct(pr, "bg_menu_wasteland", 2)
    if pid: pids[pid] = "bg"

    return pids

def organize_outputs():
    print("Organizing generated outputs into biome/character folders (use organize_assets.ps1 for more)...")
    # Simple move by name patterns
    for fn in glob(os.path.join(ASSETS_DIR, "tilesets", "*tile*")):
        pass  # already copied to flat; extend if needed
    print("Done basic organize. Curate keepers manually or run organize script.")

def main():
    if not wait_server():
        print("Start ComfyUI manually (python main.py --listen) and re-run.")
        return
    print("=== Starting absolute rest asset generation (hand-drawn local ComfyUI) ===")
    t_pids = generate_tiles()
    c_pids = generate_characters()
    e_pids = generate_equipment_ui_etc()
    # Wait copies for tiles/chars
    wait_and_copy(t_pids, "tiles", "tilesets", "FallenEarth_Handdrawn")
    wait_and_copy(c_pids, "chars", "characters", "FallenEarth_Handdrawn")
    wait_and_copy(e_pids, "misc", "ui", "FallenEarth_Handdrawn")
    organize_outputs()
    print("Generation of rest complete. Review outputs, curate to selected/ , update Godot builders/manifests.")

if __name__ == "__main__":
    main()