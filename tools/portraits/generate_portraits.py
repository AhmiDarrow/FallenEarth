"""
Portrait Generator for Fallen Earth
Uses ComfyUI API + Flux.2 Klein 9B to generate 96 portraits
(8 races x 2 genders x 6 portraits each)
"""

import json
import os
import random
import time
import urllib.request
import urllib.parse
import sys
from pathlib import Path

COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_PATH = Path(__file__).parent / "portrait_workflow.json"
OUTPUT_BASE = Path(r"C:\Users\Administrator\FallenEarth\assets\portraits")

RACES = [
    "human", "mutant", "cyborg", "sentientai",
    "chthon", "vesperid", "nullborn", "revenant"
]
GENDERS = ["male", "female"]
PORTRAITS_PER_COMBO = 6

RACE_PROMPTS = {
    "human": "a human wasteland survivor, weathered face, determined expression, scars, gritty realism",
    "mutant": "a mutant with subtle mutations, glowing veins, scarred skin, asymmetric features, wasteland survivor",
    "cyborg": "a cyborg with cybernetic facial implants, metallic plates, glowing circuit lines, half-organic half-machine",
    "sentientai": "an artificial sentient being, holographic skin patterns, ethereal glow, synthetic yet expressive features",
    "chthon": "an underground dweller, pale luminous skin, bioluminescent markings, dark adaptive eyes, cave-born",
    "vesperid": "an alien humanoid, iridescent skin, unusual bone structure, otherworldly elegance, extraterrestrial",
    "nullborn": "a void-touched being, ashen grey skin, hollow luminous eyes, mysterious ethereal aura, shadow-touched",
    "revenant": "an undead warrior, partially decayed face, ghostly pale aura, ancient armor remnants, risen from death"
}

BASE_PROMPT = (
    "classical portrait painting, face-on view, detailed face, "
    "cinematic lighting, sharp focus, professional portrait, "
    "photorealistic, bust shot, neutral dark background, "
    "masterpiece, best quality, 8k uhd"
)


def load_workflow():
    with open(WORKFLOW_PATH, "r") as f:
        return json.load(f)


def queue_prompt(workflow, seed, positive_prompt, filename_prefix):
    wf = json.loads(json.dumps(workflow))

    wf["4"]["inputs"]["text"] = positive_prompt
    wf["6"]["inputs"]["seed"] = seed
    wf["8"]["inputs"]["filename_prefix"] = filename_prefix

    payload = json.dumps({"prompt": wf}).encode("utf-8")
    req = urllib.request.Request(
        f"{COMFYUI_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
    return result["prompt_id"]


def poll_history(prompt_id, timeout=300):
    start = time.time()
    while time.time() - start < timeout:
        try:
            req = urllib.request.Request(f"{COMFYUI_URL}/history/{prompt_id}")
            with urllib.request.urlopen(req) as resp:
                history = json.loads(resp.read())
            if prompt_id in history:
                return history[prompt_id]
        except Exception:
            pass
        time.sleep(2)
    return None


def download_image(filename, subfolder, dest_path):
    params = urllib.parse.urlencode({
        "filename": filename,
        "subfolder": subfolder,
        "type": "output"
    })
    req = urllib.request.Request(f"{COMFYUI_URL}/view?{params}")
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dest_path, "wb") as f:
        f.write(data)


def check_server():
    try:
        req = urllib.request.Request(f"{COMFYUI_URL}/system_stats")
        with urllib.request.urlopen(req, timeout=5) as resp:
            stats = json.loads(resp.read())
        vram = stats.get("devices", [{}])[0].get("vram_total", 0)
        print(f"ComfyUI running. VRAM: {vram / 1e9:.1f} GB")
        return True
    except Exception as e:
        print(f"ComfyUI not reachable: {e}")
        return False


def generate_all():
    if not check_server():
        print("ERROR: Start ComfyUI first: python main.py --listen")
        sys.exit(1)

    workflow = load_workflow()
    total = len(RACES) * len(GENDERS) * PORTRAITS_PER_COMBO
    generated = 0
    failed = 0

    print(f"\nGenerating {total} portraits...")
    print(f"Output: {OUTPUT_BASE}\n")

    for race in RACES:
        for gender in GENDERS:
            race_gender_dir = OUTPUT_BASE / f"{race}_{gender}"
            race_gender_dir.mkdir(parents=True, exist_ok=True)

            for i in range(PORTRAITS_PER_COMBO):
                portrait_num = i + 1
                filename = f"portrait_{portrait_num:02d}"

                race_mod = RACE_PROMPTS.get(race, "")
                positive = f"{BASE_PROMPT}, {race_mod}"
                seed = random.randint(0, 2**32 - 1)

                print(f"[{generated+1}/{total}] {race}_{gender} portrait {portrait_num} (seed: {seed})")

                try:
                    prompt_id = queue_prompt(
                        workflow, seed, positive,
                        f"{race}_{gender}_{filename}"
                    )
                    print(f"  Queued: {prompt_id}")

                    result = poll_history(prompt_id, timeout=120)
                    if result is None:
                        print(f"  TIMEOUT waiting for result")
                        failed += 1
                        continue

                    outputs = result.get("outputs", {})
                    saved = False
                    for node_id, node_output in outputs.items():
                        images = node_output.get("images", [])
                        for img in images:
                            dest = race_gender_dir / f"{filename}.png"
                            download_image(img["filename"], img.get("subfolder", ""), dest)
                            print(f"  Saved: {dest}")
                            saved = True
                            break
                        if saved:
                            break

                    if not saved:
                        print(f"  No image in output")
                        failed += 1

                    generated += 1

                except Exception as e:
                    print(f"  ERROR: {e}")
                    failed += 1
                    generated += 1

    print(f"\nDone! Generated: {generated - failed}/{total}, Failed: {failed}")
    print(f"Output directory: {OUTPUT_BASE}")


if __name__ == "__main__":
    generate_all()
