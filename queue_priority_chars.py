#!/usr/bin/env python3
"""
Targeted queue for the 21 missing race+gender character bases (neutral underclothing only).
Uses direct prompt with IPAdapter + master_style.png for style lock.
Run with the Comfy venv python after server is up.
"""

import os
import time
import requests
import shutil

COMFY_URL = "http://127.0.0.1:8188"
COMFY_OUTPUT = r"C:\Users\Administrator\Documents\comfy\ComfyUI\output"
DEST_ROOT = r"C:\Users\Administrator\FallenEarth\assets\characters"

# Current priority low-count or poor quality race/gender (neutral base only)
MISSING = [
    ("human", "male"),
    ("mutant", "female"),
    ("vesperid", "nonbinary"),
]

POSES = ["front_idle", "side_idle", "back_idle", "front_walk_1"]

MASTER_BASE = (
    "2D hand-drawn illustrated style like the reference image, top-down 2.5D game assets, "
    "charming yet gritty post-apocalyptic sci-fi Earth IV wasteland, cozy grim survival with cosmic horror elements, "
    "detailed hand-crafted look with wooden structures, earthy tones, green vegetation, "
    "muted color palette: rusty oranges, deep reds, toxic greens, void blues, warm browns, soft atmospheric lighting, "
    "readable silhouettes for tiles and sprites, high quality consistent game art"
)

NEG = "blurry, deformed, text, watermark, people with gear, oversaturated, low contrast, pixel art, realistic, photo, cartoon, bright, clean"

def build_char_prompt(race, gender, pose):
    return (
        f"{MASTER_BASE}, EXACT charming hand-drawn 2.5D style of master_test_01.png but STRICTLY SINGLE ISOLATED HUMANOID BASE CHARACTER SPRITE ONLY - exactly ONE full body figure per image, clear head torso arms legs visible, race and gender specific face and body shape traits, neutral simple underclothing rags or plain bodysuit ONLY no armor no weapons no gear no class no masks, "
        f"grim post-apocalyptic hand-drawn {race} {gender} character base, top-down 2.5D angled game sprite pose {pose}, standing centered in frame, THE PERSON IS THE ONLY SUBJECT 100%, NO UI frames NO multiple characters NO sprite sheets NO composites, NO buildings NO trees NO platforms NO wood NO debris NO props NO background scenery NO landscape, clean isolated on solid plain muted beige/gray/earth background or minimal, centered strong readable silhouette, full body in view, high quality hand-drawn consistent game asset sprite"
    )

def queue_one(prompt_text, prefix, batch=2):
    # Working basic graph (IPAdapter node validation often fails; basic + strong style prompt produces good platform matches to master_test_01.png)
    prompt = {
        "1": {"inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}, "class_type": "CheckpointLoaderSimple"},
        "2": {"inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.1, "strength_clip": 0.05}, "class_type": "LoraLoader"},
        "3": {"inputs": {"text": prompt_text, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEG, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": batch}, "class_type": "EmptyLatentImage"},
        "6": {"inputs": {"seed": int(time.time() * 1000) % 1000000000, "steps": 22, "cfg": 6.5, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0]}, "class_type": "KSampler"},
        "7": {"inputs": {"samples": ["6", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
        "8": {"inputs": {"filename_prefix": f"FallenEarth_Handdrawn/char_{prefix}", "images": ["7", 0]}, "class_type": "SaveImage"},
    }
    try:
        r = requests.post(f"{COMFY_URL}/prompt", json={"prompt": prompt}, timeout=15)
        if r.status_code == 200:
            pid = r.json()["prompt_id"]
            print(f"Queued {prefix} -> {pid}")
            return pid
    except Exception as e:
        print(f"Queue error {prefix}: {e}")
    return None

def copy_results(prefixes, timeout=600):
    print("Waiting for results and copying...")
    t0 = time.time()
    copied = 0
    while time.time() - t0 < timeout and copied < len(prefixes) * 2:
        for fn in os.listdir(COMFY_OUTPUT):
            for pfx in prefixes:
                if fn.endswith((".png", ".jpg")) and pfx in fn:
                    src = os.path.join(COMFY_OUTPUT, fn)
                    # target folder
                    parts = pfx.split("_", 2)  # e.g. char_human_female_front_idle -> human_female
                    if len(parts) >= 3:
                        race = parts[1] if parts[0]=='char' else parts[0]
                        gender = parts[2] if parts[0]=='char' else parts[1]
                    else:
                        continue
                    dst_dir = os.path.join(DEST_ROOT, f"{race}_{gender}")
                    os.makedirs(dst_dir, exist_ok=True)
                    dst = os.path.join(dst_dir, fn)
                    if not os.path.exists(dst):
                        shutil.copy(src, dst)
                        copied += 1
                        print("  copied", fn)
        time.sleep(6)
    print(f"Copied {copied} files.")

def wait_server(timeout=180):
    print("Waiting for ComfyUI to be ready...")
    for _ in range(timeout):
        try:
            if requests.get(f"{COMFY_URL}/system_stats", timeout=3).status_code == 200:
                print("Server ready. Extra settle time for models...")
                time.sleep(25)
                return True
        except:
            pass
        time.sleep(3)
    print("Server never became ready.")
    return False

def main():
    if not wait_server():
        print("Start ComfyUI and re-run this script.")
        return
    print("=== Priority missing characters queue ===")
    pids = {}
    prefixes = []
    for race, gender in MISSING:
        folder = f"{race}_{gender}"
        os.makedirs(os.path.join(DEST_ROOT, folder), exist_ok=True)
        for pose in POSES[:2]:  # start with 2 poses to keep reasonable
            pr = build_char_prompt(race, gender, pose)
            pid = queue_one(pr, f"{folder}_{pose}", batch=3)
            if pid:
                pids[pid] = f"{folder}_{pose}"
                prefixes.append(f"{folder}_{pose}")
            time.sleep(1.2)
    print(f"Queued {len(pids)} character batches.")
    copy_results(prefixes)
    print("Done priority chars. Run full generator or repeat for more poses / other assets.")

if __name__ == "__main__":
    main()