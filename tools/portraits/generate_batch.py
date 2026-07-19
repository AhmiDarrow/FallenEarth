"""
Batch Portrait Generator - one race/gender at a time
Usage: python generate_batch.py <race> <gender>
Example: python generate_batch.py human male
"""

import json
import random
import sys
import time
import urllib.request
import urllib.parse
from pathlib import Path

COMFYUI_URL = "http://127.0.0.1:8188"
WORKFLOW_PATH = Path(__file__).parent / "portrait_workflow.json"
OUTPUT_BASE = Path(r"C:\Users\Administrator\FallenEarth\assets\portraits")

RACE_PROMPTS = {
    "human": (
        "close-up portrait of a human wasteland survivor, "
        "weathered tanned skin, deep-set tired eyes, unkempt hair, "
        "small scars on cheeks, sun-damaged complexion, determined gaze, "
        "wearing worn leather collar, neutral expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "mutant": (
        "close-up portrait of a radiation-mutated human, "
        "asymmetric facial features, one eye slightly larger, "
        "visible radiation scars and burn marks, patchy hair, "
        "discolored skin with greenish veins showing through, "
        "missing tooth, rugged desperate expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "cyborg": (
        "close-up portrait of a chrome-augmented cyborg, "
        "half face is organic skin, half is polished metal plating, "
        "one glowing red cybernetic eye with scanning reticle, "
        "exposed wiring along jawline, metallic cheekbone, "
        "steel bolts at temples, stern focused expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "sentientai": (
        "close-up portrait of an artificial humanoid AI, "
        "pale flawless synthetic skin, geometric circuit patterns "
        "glowing faintly under skin on temples and neck, "
        "large luminous eyes with digital iris patterns, "
        "serene calm expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "chthon": (
        "close-up portrait of a pale underground dweller, "
        "extremely pale almost translucent skin, dark adaptive eyes "
        "with reflective tapetum, elongated face and narrow chin, "
        "faint bioluminescent blue veins visible at temples, "
        "pointed ears, no hair, smooth head, eerie calm expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "vesperid": (
        "close-up portrait of an insectoid-human hybrid, "
        "chitinous facial plates replacing skin on cheeks and forehead, "
        "large compound eyes with iridescent facets, "
        "segmented mandible-like jaw structure, antennae stubs at brow, "
        "dark exoskeleton coloring with amber highlights, "
        "alien unreadable expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "nullborn": (
        "close-up portrait of a void-touched being, "
        "complete black sclera eyes with tiny white pinprick pupils, "
        "deep shadow pooling in eye sockets and under cheekbones, "
        "skin like cracked obsidian with faint purple-black undertones, "
        "angular gaunt face, severe cheekbones, sharp chin, "
        "dark veins like cracks on porcelain, "
        "disturbingly still expression, "
        "face centered in frame, looking directly at viewer"
    ),
    "revenant": (
        "close-up portrait of a reanimated corpse, "
        "grey-green decaying skin, sunken hollow cheeks, "
        "one eye cloudy and milky, dark circles under eyes, "
        "exposed tendons at neck, stitched wounds on forehead, "
        "patchy thin hair, ancient weathered face, "
        "tired resigned expression, "
        "face centered in frame, looking directly at viewer"
    ),
}

BASE_STYLE = (
    "digital painting, detailed face, sharp focus, "
    "dramatic lighting, dark moody background, "
    "bust portrait from chest up, character art, "
    "high detail, professional illustration, "
    "no text, no letters, no words, no writing"
)


def load_workflow():
    with open(WORKFLOW_PATH, "r") as f:
        return json.load(f)


GENDER_DESC = {
    "male": "masculine face, strong jawline, broad features",
    "female": "feminine face, soft jawline, delicate features",
}


GENDER_DESC = {
    "male": "masculine face, strong jawline, broad features, short hair",
    "female": "feminine face, softer features, longer hair, more delicate bone structure",
}


def queue_prompt(workflow, seed, prompt, gender, filename_prefix):
    gender_tag = GENDER_DESC.get(gender, "")
    wf = json.loads(json.dumps(workflow))
    wf["4"]["inputs"]["text"] = f"{prompt}, {gender_tag}, {BASE_STYLE}"
    wf["6"]["inputs"]["seed"] = seed
    wf["8"]["inputs"]["filename_prefix"] = filename_prefix

    payload = json.dumps({"prompt": wf}).encode("utf-8")
    req = urllib.request.Request(
        f"{COMFYUI_URL}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
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
    params = urllib.parse.urlencode(
        {"filename": filename, "subfolder": subfolder, "type": "output"}
    )
    req = urllib.request.Request(f"{COMFYUI_URL}/view?{params}")
    with urllib.request.urlopen(req) as resp:
        data = resp.read()
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(dest_path, "wb") as f:
        f.write(data)


def generate_batch(race, gender):
    try:
        req = urllib.request.Request(f"{COMFYUI_URL}/system_stats")
        with urllib.request.urlopen(req, timeout=5) as resp:
            stats = json.loads(resp.read())
        vram = stats.get("devices", [{}])[0].get("vram_total", 0)
        print(f"ComfyUI running. VRAM: {vram / 1e9:.1f} GB")
    except Exception as e:
        print(f"ERROR: ComfyUI not reachable: {e}")
        sys.exit(1)

    workflow = load_workflow()
    out_dir = OUTPUT_BASE / f"{race}_{gender}"
    out_dir.mkdir(parents=True, exist_ok=True)

    prompt_text = RACE_PROMPTS.get(race)
    if not prompt_text:
        print(f"Unknown race: {race}")
        sys.exit(1)

    print(f"\nGenerating 6 portraits: {race} {gender}")
    print(f"Prompt: {prompt_text[:80]}...")
    print(f"Output: {out_dir}\n")

    for i in range(6):
        seed = random.randint(0, 2**32 - 1)
        filename = f"portrait_{i+1:02d}"
        prefix = f"{race}_{gender}_{filename}"

        print(f"[{i+1}/6] seed={seed}")

        try:
            prompt_id = queue_prompt(workflow, seed, prompt_text, gender, prefix)
            print(f"  Queued: {prompt_id}")

            result = poll_history(prompt_id, timeout=180)
            if result is None:
                print(f"  TIMEOUT")
                continue

            outputs = result.get("outputs", {})
            for node_id, node_output in outputs.items():
                images = node_output.get("images", [])
                for img in images:
                    dest = out_dir / f"{filename}.png"
                    download_image(img["filename"], img.get("subfolder", ""), dest)
                    print(f"  Saved: {dest}")
                    break
                else:
                    continue
                break
            else:
                print(f"  No image in output")

        except Exception as e:
            print(f"  ERROR: {e}")

    print(f"\nDone! Portraits saved to: {out_dir}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python generate_batch.py <race> <gender>")
        print(f"Races: {', '.join(RACE_PROMPTS.keys())}")
        print("Genders: male, female")
        sys.exit(1)

    generate_batch(sys.argv[1], sys.argv[2])
