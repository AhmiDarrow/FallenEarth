import json
import time
import requests
import shutil
import os
import subprocess
import sys

COMFY_ROOT = r"C:\Users\Administrator\Documents\comfy\ComfyUI"
OUTPUT_DIR = os.path.join(COMFY_ROOT, "output")
TARGET_DIR = r"assets\style_references"
COMFY_URL = "http://127.0.0.1:8188"

os.makedirs(TARGET_DIR, exist_ok=True)

# Extracted positives from the handdrawn tests
POSITIVES = {
    "01_balanced": "2D hand-drawn illustration style for top-down 2.5D game assets, blending RimWorld iconic simplicity and Stardew Valley charm, grim post-apocalyptic sci-fi Earth IV wasteland with cosmic horror elements, detailed hand-drawn textures, rusted metal towers and wreckage, glowing blue and sickly green fissures, twisted mutated organic growths, neon signs in toxic fog and ash, brutal yet strangely beautiful, readable silhouettes for sprites and tiles, consistent dramatic lighting, muted earth tones with rusty oranges, deep reds, toxic greens and void blues, atmospheric dust, no characters, no text, high quality consistent 2D hand-drawn game art style, tileable and sprite-friendly",
    "02_illustrative": "highly detailed 2D hand-drawn illustrated top-down game art style, inspired by RimWorld and Stardew Valley but fully hand-drawn not pixel, charming yet gritty post-apoc sci-fi wasteland, intricate linework and painterly details, rusted corporate ruins with eldritch mutations, bioluminescent glows, toxic fog, strong readable forms for Godot sprites and hex tiles, warm yet ominous atmosphere, limited but rich color palette, no characters no text",
    "03_rimworld": "2D hand-drawn iconic style like RimWorld blended with Stardew charm, simple yet expressive hand-drawn top-down sprites and tiles, post-apocalyptic sci-fi Earth IV, abstract but identifiable designs, rusted wasteland with cosmic horror touches, clean lines, modular feel, muted colors with accents, perfect for survival game assets, tileable, no text",
    "04_stardew": "2D hand-drawn charming style like Stardew Valley with RimWorld influence, detailed hand-drawn environments and characters for top-down view, cozy grim post-apoc sci-fi survival, hand-crafted illustrated look, detailed foliage and structures in wasteland, glowing elements, atmospheric, rich colors in muted tones, sprite and tile friendly for Godot, no characters no text",
    "05_gritty": "gritty 2D hand-drawn horror style for top-down game, RimWorld Stardew inspired but darker cosmic horror sci-fi wasteland, detailed ink and wash illustration feel, decayed ruins, unnatural growths, energy fissures, harsh lighting, detailed textures, readable for gameplay assets, muted desaturated palette with eerie highlights, tileable hand-drawn tiles and sprites"
}

NEGATIVE = "cartoon, cute, bright colors, clean modern, high fantasy, realistic photography, blurry, deformed, text, watermark, people, characters, oversaturated, low contrast, flat lighting, modern clean sci-fi, high detail photoreal, vibrant, cheerful, pixel art, 8bit, lowres"

def start_comfy():
    print("Launching ComfyUI...")
    py = os.path.join(COMFY_ROOT, ".venv", "Scripts", "python.exe")
    cmd = [py, "main.py", "--listen", "--port", "8188", "--disable-auto-launch"]
    flags = subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform.startswith("win") else 0
    proc = subprocess.Popen(cmd, cwd=COMFY_ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)
    print(f"Started PID {proc.pid}")
    return proc

def wait_server(timeout=120):
    print("Waiting for server...")
    for _ in range(timeout):
        try:
            if requests.get(f"{COMFY_URL}/system_stats", timeout=3).status_code == 200:
                print("Server up. Waiting extra for model load...")
                time.sleep(30)  # Important: give time for SDXL + LoRA to load
                return True
        except:
            pass
        time.sleep(1)
    return False

def build_prompt(pos_text, batch=3):
    return {
        "1": {"inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}, "class_type": "CheckpointLoaderSimple"},
        "2": {
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": "pixel-art-xl.safetensors",
                "strength_model": 0.1,
                "strength_clip": 0.1
            },
            "class_type": "LoraLoader"
        },
        "3": {"inputs": {"text": pos_text, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEGATIVE, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": batch}, "class_type": "EmptyLatentImage"},
        "6": {
            "inputs": {
                "seed": 123456789 + hash(pos_text) % 100000,
                "steps": 30,
                "cfg": 7,
                "sampler_name": "euler",
                "scheduler": "normal",
                "denoise": 1,
                "model": ["2", 0],
                "positive": ["3", 0],
                "negative": ["4", 0],
                "latent_image": ["5", 0]
            },
            "class_type": "KSampler"
        },
        "7": {"inputs": {"samples": ["6", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
        "8": {
            "inputs": {"filename_prefix": "FallenEarth_Style/handdrawn_test", "images": ["7", 0]},
            "class_type": "SaveImage"
        }
    }

def queue(pos_key, label):
    pd = build_prompt(POSITIVES[pos_key])
    r = requests.post(f"{COMFY_URL}/prompt", json={"prompt": pd})
    if r.status_code == 200:
        pid = r.json()["prompt_id"]
        print(f"Queued {label} ({pos_key}) -> {pid}")
        return pid
    print(f"Queue failed for {label}: {r.text}")
    return None

def main():
    start_comfy()
    if not wait_server():
        print("Server not ready. Start manually and rerun.")
        return

    pids = {}
    for key, label in [("01_balanced", "01"), ("02_illustrative","02"), ("03_rimworld","03"), ("04_stardew","04"), ("05_gritty","05")]:
        pid = queue(key, label)
        if pid:
            pids[pid] = label
        time.sleep(2)

    print("Waiting for generations...")
    done = {}
    t0 = time.time()
    while len(done) < len(pids) and time.time() - t0 < 600:
        hist = requests.get(f"{COMFY_URL}/history").json()
        for pid, lab in list(pids.items()):
            if pid in hist:
                done[pid] = lab
                print(f"{lab} done")
                del pids[pid]
        time.sleep(5)

    print("Copying images...")
    for pid, lab in done.items():
        hist = requests.get(f"{COMFY_URL}/history").json()[pid]
        for node in hist.get("outputs", {}).values():
            for im in node.get("images", []):
                fn = im["filename"]
                src = os.path.join(OUTPUT_DIR, fn)
                if os.path.exists(src):
                    dst = os.path.join(TARGET_DIR, f"handdrawn_test_{lab}_{fn}")
                    shutil.copy(src, dst)
                    print("Copied:", os.path.basename(dst))

    print("Done. Check assets/style_references/ for handdrawn_test_* files.")

if __name__ == "__main__":
    main()
