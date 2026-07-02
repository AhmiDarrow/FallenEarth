import json
import time
import requests
import shutil
import os
import subprocess
import sys

COMFY_DIR = r"C:\Users\Administrator\Documents\comfy\ComfyUI"
PROJECT_DIR = r"C:\Users\Administrator\FallenEarth"
OUTPUT_DIR = os.path.join(COMFY_DIR, "output")
TARGET_DIR = os.path.join(PROJECT_DIR, "assets", "style_references")

os.makedirs(TARGET_DIR, exist_ok=True)

COMFY_URL = "http://127.0.0.1:8188"

# The 5 positive prompts
prompts = {
    "01_balanced": "grim post-apocalyptic sci-fi Earth IV, stylish cyberpunk decay mixed with cosmic eldritch horror, Shadowrun x Cthulhu vibes, rusted metal towers and corporate wreckage, glowing blue and sickly green fissures leaking Underearth energy, twisted mutated organic growths and chitinous structures, neon signs flickering in toxic fog and ash, brutal yet strangely beautiful, top-down 2.5D game asset style reference, highly detailed worn textures, consistent dramatic lighting with harsh overhead sun and eerie bioluminescent glows, muted earth tones with rusty oranges, deep reds, toxic greens and void blues, atmospheric dust storms and low visibility, no characters, no text, high quality consistent 2D game art style suitable for Godot sprites and tiles, tileable and sprite-friendly",
    "02_neon": "grim post-apocalyptic sci-fi Earth IV, heavy cyberpunk neon decay, flickering corporate holograms and rusted megastructure ruins, electric blue and toxic green energy cracks, layered neon signs in thick toxic fog, brutal urban wasteland beauty, top-down 2.5D game asset style reference, highly detailed worn textures, dramatic high contrast lighting with glowing accents, muted earth tones with strong neon pops of cyan and magenta, atmospheric dust and ash, no characters, no text, high quality consistent 2D game art style suitable for Godot sprites and tiles, tileable and sprite-friendly",
    "03_eldritch": "grim post-apocalyptic sci-fi Earth IV, dominant cosmic eldritch horror, ancient rusted wreckage twisted by void energies, glowing unnatural runes and fissures leaking sickly light, writhing chitinous and organic mutations, reality distortion and impossible angles, Cthulhu shadowrun atmosphere, top-down 2.5D game asset style reference, highly detailed worn textures, eerie bioluminescent and void lighting, deep void blues, toxic greens, rusty reds, low visibility fog, no characters, no text, high quality consistent 2D game art style suitable for Godot sprites and tiles, tileable and sprite-friendly",
    "04_desolate": "grim post-apocalyptic sci-fi Earth IV, desolate irradiated wasteland, endless cracked toxic earth and windblown ash dunes, sparse mutated scrub and rusted husks of old world machines, subtle glowing blue fissures, harsh unforgiving sun, brutal raw survival beauty, top-down 2.5D game asset style reference, highly detailed worn textures, strong dramatic overhead lighting with dust haze, heavily muted earth tones, rusty oranges, desaturated greens and browns, low visibility, no characters, no text, high quality consistent 2D game art style suitable for Godot sprites and tiles, tileable and sprite-friendly",
    "05_stylized": "grim post-apocalyptic sci-fi Earth IV, clean stylized top-down game asset style, cyberpunk decay meets cosmic horror, rusted towers, glowing energy fissures, mutated growths, toxic fog, strong readable silhouettes and shapes, consistent dramatic lighting, limited but rich color palette of rusty oranges, deep reds, sickly greens and void blues, highly detailed yet optimized for sprites and hex tiles, no characters, no text, perfect for Godot 2.5D, sharp edges, good contrast, tileable and sprite-friendly"
}

negative = "cartoon, cute, bright colors, clean modern, high fantasy, realistic photography, blurry, deformed, text, watermark, people, characters, oversaturated, low contrast, flat lighting, modern clean sci-fi, high detail photoreal, vibrant, cheerful"

def wait_for_server(timeout=60):
    print("Checking server...")
    for _ in range(timeout):
        try:
            r = requests.get(f"{COMFY_URL}/system_stats", timeout=3)
            if r.status_code == 200:
                print("Server ready.")
                return True
        except:
            pass
        time.sleep(1)
    return False

def build_prompt(pos_text, batch_size=2):
    # Construct a minimal working prompt dict for API
    # Node ids as strings
    p = {
        "1": {
            "inputs": {},
            "class_type": "CheckpointLoaderSimple",
            "meta": {"title": "Load Checkpoint"}
        },
        "2": {
            "inputs": {
                "model": ["1", 0],
                "clip": ["1", 1],
                "lora_name": "pixel-art-xl.safetensors",
                "strength_model": 0.85,
                "strength_clip": 0.85
            },
            "class_type": "LoraLoader",
            "meta": {"title": "Load LoRA"}
        },
        "3": {
            "inputs": {
                "text": pos_text,
                "clip": ["2", 1]
            },
            "class_type": "CLIPTextEncode",
            "meta": {"title": "Positive"}
        },
        "4": {
            "inputs": {
                "text": negative,
                "clip": ["2", 1]
            },
            "class_type": "CLIPTextEncode",
            "meta": {"title": "Negative"}
        },
        "5": {
            "inputs": {
                "width": 512,
                "height": 512,
                "batch_size": batch_size
            },
            "class_type": "EmptyLatentImage",
            "meta": {"title": "Empty Latent"}
        },
        "6": {
            "inputs": {
                "seed": 123456 + int(time.time()) % 100000 ,
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
            "class_type": "KSampler",
            "meta": {"title": "KSampler"}
        },
        "7": {
            "inputs": {
                "samples": ["6", 0],
                "vae": ["1", 2]
            },
            "class_type": "VAEDecode",
            "meta": {"title": "VAE Decode"}
        },
        "8": {
            "inputs": {
                "filename_prefix": f"FallenEarth_Style/style_test",
                "images": ["7", 0]
            },
            "class_type": "SaveImage",
            "meta": {"title": "Save Image"}
        }
    }
    # Note: The LoraLoader in this construction uses the inputs from checkpoint, but to match exactly, we may need to adjust for the exact node wiring.
    # For simplicity, this replicates the core: Checkpoint -> Lora -> CLIP encodes -> KSampler -> VAE -> Save
    return p

def queue(prompt_dict, client_id="grok-test"):
    payload = {"prompt": prompt_dict, "client_id": client_id}
    r = requests.post(f"{COMFY_URL}/prompt", json=payload, timeout=30)
    if r.status_code == 200:
        pid = r.json()["prompt_id"]
        print(f"  Queued prompt_id={pid}")
        return pid
    else:
        print(f"  Queue failed: {r.status_code} {r.text[:200]}")
        return None

def main():
    if not wait_for_server():
        print("Server not available. Exiting.")
        return

    prompt_ids = []
    labels = []
    for key, pos in prompts.items():
        print(f"Queueing variation {key}...")
        pd = build_prompt(pos, batch_size=2)
        pid = queue(pd)
        if pid:
            prompt_ids.append(pid)
            labels.append(key)
        time.sleep(2)

    print("Waiting for images...")
    completed = {}
    t0 = time.time()
    while time.time() - t0 < 300 and len(completed) < len(prompt_ids):
        try:
            hist = requests.get(f"{COMFY_URL}/history").json()
            for pid in prompt_ids:
                if pid in hist and pid not in completed:
                    completed[pid] = hist[pid]
                    print(f"  {pid} done")
        except:
            pass
        time.sleep(4)

    print("Copying results...")
    for pid, hist in completed.items():
        for node_out in hist.get("outputs", {}).values():
            for img in node_out.get("images", []):
                fname = img["filename"]
                src = os.path.join(OUTPUT_DIR, fname)
                if os.path.exists(src):
                    dst = os.path.join(TARGET_DIR, fname.replace("style_test", "style_test_" + labels[0] if labels else "style_test"))
                    # Better naming
                    idx = completed.keys().index(pid) if hasattr(completed.keys(), 'index') else 0
                    label = labels[idx] if idx < len(labels) else "unknown"
                    dst_name = f"style_{label}_{fname}"
                    dst = os.path.join(TARGET_DIR, dst_name)
                    shutil.copy2(src, dst)
                    print("  ->", dst_name)

    print("Test images copied to assets/style_references/")
    print("List:")
    for f in sorted(os.listdir(TARGET_DIR)):
        if f.startswith("style_"):
            print("  ", f)

if __name__ == "__main__":
    main()
