#!/usr/bin/env python3
"""Queue tiles for the 7+ biomes that need full sets (ground, debris, vegetation, etc)."""
import time, requests, os, shutil

COMFY = "http://127.0.0.1:8188"
OUT = r"C:\Users\Administrator\Documents\comfy\ComfyUI\output"
DEST = r"C:\Users\Administrator\FallenEarth\assets\tilesets"

BIOMES = ["scorched_plains", "ironwood_thicket", "glass_dunes", "toxin_marshes", "stormspire_highlands", "corpse_fields", "dead_city_outskirts"]
CATS = ["ground", "debris", "vegetation", "transition", "rift"]

BASE = "2D hand-drawn illustrated style like the reference image, top-down 2.5D game assets, charming yet gritty post-apocalyptic sci-fi Earth IV wasteland, cozy grim survival with cosmic horror elements, detailed hand-crafted look with wooden structures, earthy tones, green vegetation, muted color palette: rusty oranges, deep reds, toxic greens, void blues, warm browns, soft atmospheric lighting, readable silhouettes for tiles and sprites, no characters, no text, high quality consistent game art"
NEG = "blurry, deformed, text, pixel art, realistic, photo"

def wait_ready(timeout=180):
    print("Waiting for server...")
    for _ in range(timeout):
        try:
            if requests.get(f"{COMFY}/system_stats", timeout=3).status_code == 200:
                print("Server ready")
                time.sleep(20)
                return True
        except:
            pass
        time.sleep(3)
    return False

def queue(pr, prefix, bsz=4):
    # Basic payload like chars for reliability (IPAdapter can fail)
    p = {
        "1": {"inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}, "class_type": "CheckpointLoaderSimple"},
        "2": {"inputs": {"model": ["1", 0], "clip": ["1", 1], "lora_name": "pixel-art-xl.safetensors", "strength_model": 0.1, "strength_clip": 0.05}, "class_type": "LoraLoader"},
        "3": {"inputs": {"text": pr, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "4": {"inputs": {"text": NEG, "clip": ["2", 1]}, "class_type": "CLIPTextEncode"},
        "5": {"inputs": {"width": 512, "height": 512, "batch_size": bsz}, "class_type": "EmptyLatentImage"},
        "6": {"inputs": {"seed": int(time.time() * 1000) % 1000000000, "steps": 22, "cfg": 6.5, "sampler_name": "euler", "scheduler": "normal", "denoise": 1.0, "model": ["2", 0], "positive": ["3", 0], "negative": ["4", 0], "latent_image": ["5", 0]}, "class_type": "KSampler"},
        "7": {"inputs": {"samples": ["6", 0], "vae": ["1", 2]}, "class_type": "VAEDecode"},
        "8": {"inputs": {"filename_prefix": f"FallenEarth_Handdrawn/{prefix}", "images": ["7", 0]}, "class_type": "SaveImage"},
    }
    try:
        r = requests.post(f"{COMFY}/prompt", json={"prompt": p}, timeout=25)
        if r.status_code == 200:
            pid = r.json().get("prompt_id")
            print("Queued", prefix, pid)
            return pid
    except Exception as e:
        print("Err", prefix, str(e)[:60])
    return None

def main():
    if not wait_ready():
        print("Server not ready in time")
        return
    print("Queuing remaining biome tiles...")
    for b in BIOMES:
        for c in CATS:
            pr = BASE + f", seamless top-down hex tileable for {b.replace('_',' ')}, {c} features, consistent hand-drawn style, readable for Godot hex tiles"
            queue(pr, f"tile_{b}_{c}", 4)
            time.sleep(1.5)
    print("Tile batches queued. Monitor output and copy to assets/tilesets/")

if __name__ == "__main__":
    main()