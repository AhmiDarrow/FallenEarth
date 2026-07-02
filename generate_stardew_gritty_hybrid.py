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

COMBINED_POS = """2D hand-drawn style combining Stardew Valley charming detailed hand-drawn environments with gritty cosmic horror, RimWorld inspired readable top-down game assets, cozy yet grim post-apocalyptic sci-fi Earth IV wasteland survival, hand-crafted illustrated look with detailed foliage and structures in the wasteland, decayed ruins, unnatural growths and energy fissures, glowing elements, harsh yet atmospheric lighting, rich muted colors with eerie highlights, sprite and tile friendly for Godot, no characters, no text"""

NEGATIVE = "cartoon, cute, bright colors, clean modern, high fantasy, realistic photography, blurry, deformed, text, watermark, people, characters, oversaturated, low contrast, flat lighting, modern clean sci-fi, high detail photoreal, vibrant, cheerful, pixel art, 8bit, lowres"

def start_comfy():
    print("Launching ComfyUI...")
    py = os.path.join(COMFY_ROOT, ".venv", "Scripts", "python.exe")
    cmd = [py, "main.py", "--listen", "--port", "8188", "--disable-auto-launch"]
    flags = subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform.startswith("win") else 0
    proc = subprocess.Popen(cmd, cwd=COMFY_ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, creationflags=flags)
    print(f"Started PID {proc.pid}")
    return proc

def wait_server(timeout=180):
    print("Waiting for ComfyUI server and model load (this can take 60-90s)...")
    for i in range(timeout):
        try:
            r = requests.get(f"{COMFY_URL}/system_stats", timeout=5)
            if r.status_code == 200:
                # Extra check: try a light endpoint or just wait more
                if i > 25:  # give at least ~30s after first response
                    print("Server responding. Assuming models loaded.")
                    return True
        except:
            pass
        time.sleep(1)
        if i % 15 == 0 and i > 0:
            print(f"  Still waiting... ({i}s elapsed)")
    print("Timeout.")
    return False

def build_prompt(batch=4):
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
        "3": {"inputs": {"text": COMBINED_POS, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEGATIVE, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": batch}, "class_type": "EmptyLatentImage"},
        "6": {
            "inputs": {
                "seed": 987654321,
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
            "inputs": {"filename_prefix": "FallenEarth_Style/handdrawn_stardew_gritty", "images": ["7", 0]},
            "class_type": "SaveImage"
        }
    }

def main():
    start_comfy()
    if not wait_server():
        print("Could not get a ready server. You may need to start ComfyUI manually.")
        return

    print("Queuing Stardew + Gritty hybrid (batch=4)...")
    pd = build_prompt()
    try:
        r = requests.post(f"{COMFY_URL}/prompt", json={"prompt": pd}, timeout=30)
        if r.status_code != 200:
            print("Queue failed:", r.text)
            return
        pid = r.json()["prompt_id"]
        print(f"Queued successfully -> {pid}")
    except Exception as e:
        print("Queue error:", e)
        return

    print("Waiting for images (up to 6 minutes)...")
    for _ in range(72):
        try:
            hist = requests.get(f"{COMFY_URL}/history", timeout=10).json()
            if pid in hist:
                print("Generation finished!")
                break
        except:
            pass
        time.sleep(5)
    else:
        print("Timed out waiting.")
        return

    print("Copying results...")
    hist = requests.get(f"{COMFY_URL}/history").json()[pid]
    count = 1
    for node in hist.get("outputs", {}).values():
        for im in node.get("images", []):
            fn = im["filename"]
            src = os.path.join(OUTPUT_DIR, fn)
            if os.path.exists(src):
                dst = os.path.join(TARGET_DIR, f"handdrawn_test_stardew_gritty_{count:03d}.png")
                shutil.copy(src, dst)
                print("  Saved:", os.path.basename(dst))
                count += 1

    print("\nHybrid test complete. Look in assets/style_references/ for the new handdrawn_test_stardew_gritty_*.png files.")

if __name__ == "__main__":
    main()
