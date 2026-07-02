#!/usr/bin/env python3
"""
Reliable starter: launch ComfyUI, wait for the 'To see the GUI' line in its log,
then immediately queue a substantial batch of the missing assets (priority on characters).

This is the way to get the absolute rest generated when the server is flaky.
"""
import os
import sys
import time
import subprocess
import requests
import shutil

COMFY_DIR = r"C:\Users\Administrator\Documents\comfy\ComfyUI"
VENV_PY = os.path.join(COMFY_DIR, ".venv", "Scripts", "python.exe")
LOG_FILE = os.path.join(os.getcwd(), "comfy_live.log")
OUT_DIR = os.path.join(COMFY_DIR, "output")
ASSETS = os.path.join(os.getcwd(), "assets")

BASE = open(os.path.join("comfyui_workflows", "handdrawn_master_prompt.txt")).read().strip()
NEG = "blurry, deformed, text, pixel art, realistic, photo, oversaturated"

def start_server():
    print("Starting ComfyUI...")
    # Clean old log
    if os.path.exists(LOG_FILE):
        os.remove(LOG_FILE)
    cmd = [VENV_PY, "main.py", "--listen", "--port", "8188", "--disable-auto-launch"]
    proc = subprocess.Popen(cmd, cwd=COMFY_DIR, stdout=open(LOG_FILE, "w"), stderr=subprocess.STDOUT)
    return proc

def wait_for_gui_line(timeout=180):
    print("Waiting for server to print GUI line...")
    start = time.time()
    while time.time() - start < timeout:
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE, "r", errors="ignore") as f:
                content = f.read()
                if "To see the GUI go to" in content:
                    print("GUI line seen. Giving models extra time to load...")
                    time.sleep(35)  # important
                    return True
        time.sleep(2)
    return False

def wait_system_stats(timeout=60):
    for _ in range(timeout):
        try:
            if requests.get("http://127.0.0.1:8188/system_stats", timeout=2).status_code == 200:
                return True
        except:
            pass
        time.sleep(2)
    return False

def build_payload(positive: str, prefix: str, batch=3):
    return {
        "1": {"inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}, "class_type": "CheckpointLoaderSimple"},
        "2": {"inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.15, "strength_clip": 0.08}, "class_type": "LoraLoader"},
        "3": {"inputs": {"text": positive, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEG, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": batch}, "class_type": "EmptyLatentImage"},
        "6": {"inputs": {"image": "master_style.png"}, "class_type": "LoadImage"},
        "7": {"inputs": {"ipadapter_name": "ip-adapter_sdxl.bin"}, "class_type": "IPAdapterModelLoader"},
        "8": {"inputs": {"model": ["2", 0], "ipadapter": ["7", 0], "image": ["6", 0], "weight": 0.82, "start_at": 0.0, "end_at": 1.0, "weight_type": "standard"}, "class_type": "IPAdapter"},
        "9": {"inputs": {"seed": int(time.time() * 1000) % 1000000000, "steps": 24, "cfg": 6.5, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["8", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0]}, "class_type": "KSampler"},
        "10": {"inputs": {"samples": ["9", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
        "11": {"inputs": {"filename_prefix": f"FallenEarth_Handdrawn/{prefix}", "images": ["10", 0]}, "class_type": "SaveImage"},
    }

def queue(positive: str, prefix: str, batch=3):
    payload = build_payload(positive, prefix, batch)
    try:
        r = requests.post("http://127.0.0.1:8188/prompt", json={"prompt": payload}, timeout=30)
        if r.status_code == 200:
            pid = r.json().get("prompt_id")
            print(f"  Queued {prefix} -> {pid}")
            return pid
        else:
            print(f"  Queue failed {prefix}: {r.status_code}")
    except Exception as e:
        print(f"  Queue error {prefix}: {e}")
    return None

def copy_new(prefixes, dest_subdir, timeout=420):
    print(f"Waiting for results and copying to {dest_subdir}...")
    t0 = time.time()
    copied = 0
    seen = set()
    while time.time() - t0 < timeout:
        for fn in os.listdir(OUT_DIR):
            if fn.endswith(".png"):
                for p in prefixes:
                    if p in fn and fn not in seen:
                        src = os.path.join(OUT_DIR, fn)
                        dst_dir = os.path.join(ASSETS, dest_subdir)
                        os.makedirs(dst_dir, exist_ok=True)
                        # put directly in right subfolder when possible
                        if "char_" in fn:
                            parts = fn.split("char_")[-1].split("_")
                            if len(parts) >= 2:
                                race = parts[0]
                                gender = parts[1]
                                dst_dir = os.path.join(dst_dir, f"{race}_{gender}")
                                os.makedirs(dst_dir, exist_ok=True)
                        shutil.copy(src, os.path.join(dst_dir, fn))
                        seen.add(fn)
                        copied += 1
                        print("   copied", fn)
        time.sleep(5)
    print(f"Copied {copied} files.")

def main():
    proc = start_server()
    if not wait_for_gui_line(180):
        print("GUI line not seen in time. Continuing anyway.")
    if not wait_system_stats(90):
        print("system_stats never came back healthy.")

    print("Server should be ready. Queuing priority missing characters + tiles...")

    # Characters - focus on missing
    char_prefixes = []
    missing = [
        ("human", "female"), ("human", "nonbinary"),
        ("mutant", "male"), ("mutant", "nonbinary"),
        ("cyborg", "male"), ("cyborg", "female"),
        ("chthon", "female"), ("chthon", "nonbinary"),
        ("vesperid", "male"), ("nullborn", "female"), ("revenant", "male"),
    ]
    poses = ["front_idle", "side_idle"]
    for race, gender in missing:
        for pose in poses:
            pr = BASE + f", grim post-apocalyptic hand-drawn {race} {gender}, top-down 2.5D game sprite, baseline {race} features, neutral underclothing (rags or simple jumpsuit), {pose} pose, readable silhouette, high quality hand-drawn game asset, no equipment"
            pid = queue(pr, f"char_{race}_{gender}_{pose}", batch=3)
            if pid:
                char_prefixes.append(f"char_{race}_{gender}_{pose}")
            time.sleep(0.8)

    # Tiles for empty biomes (a decent set)
    tile_prefixes = []
    biomes = ["scorched_plains", "ironwood_thicket", "glass_dunes", "toxin_marshes"]
    cats = ["ground", "debris", "vegetation"]
    for b in biomes:
        for c in cats:
            pr = BASE + f", seamless top-down hex tile texture for {b.replace('_', ' ')}, {c} features, consistent hand-drawn style, readable for Godot"
            pid = queue(pr, f"tile_{b}_{c}", batch=4)
            if pid:
                tile_prefixes.append(f"tile_{b}_{c}")
            time.sleep(0.8)

    # A few equipment / UI / rift samples
    extra = [
        ("equip_head_scav_helm", "hand-drawn post-apoc equipment head slot: scav_helm, neutral, detailed but simple, muted tones"),
        ("ui_button", "hand-drawn UI button for post-apoc menu, readable icon, wood/metal, muted"),
        ("rift_entrance", "hand-drawn rift entrance, glowing cosmic fissures, horror sci-fi"),
    ]
    for pre, desc in extra:
        pr = BASE + ", " + desc
        queue(pr, pre, batch=2)
        time.sleep(0.5)

    print("All batches queued. Now waiting and copying results...")
    all_prefixes = char_prefixes + tile_prefixes + [e[0] for e in extra]
    copy_new(all_prefixes, "characters", timeout=480)
    copy_new([p for p in all_prefixes if p.startswith("tile_")], "tilesets", timeout=300)

    print("Generation of rest complete. Check assets/ folders.")

if __name__ == "__main__":
    main()