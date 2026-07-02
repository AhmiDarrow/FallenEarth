import json
import time
import requests
import shutil
import os
import glob

COMFY_URL = "http://127.0.0.1:8188"
WORKFLOWS_DIR = r"comfyui_workflows"
OUTPUT_DIR = r"C:\Users\Administrator\Documents\comfy\ComfyUI\output"
TARGET_DIR = r"assets\style_references"

os.makedirs(TARGET_DIR, exist_ok=True)

tests = [
    ("style_test_01_balanced.json", "01_balanced"),
    ("style_test_02_neon_cyberpunk.json", "02_neon"),
    ("style_test_03_eldritch.json", "03_eldritch"),
    ("style_test_04_desolate.json", "04_desolate"),
    ("style_test_05_stylized.json", "05_stylized"),
]

def convert_workflow_to_api(workflow_json):
    """Convert ComfyUI saved list-of-nodes to API dict format + include workflow for UI info."""
    prompt = {}
    for node in workflow_json.get("nodes", []):
        nid = str(node["id"])
        node_data = {k: v for k, v in node.items() if k not in ["id", "pos", "size", "flags", "order", "mode", "properties", "isCollapsed", "bounding"]}
        # widgets_values stay
        prompt[nid] = node_data
    
    return {
        "prompt": prompt,
        "workflow": workflow_json   # include original for full compatibility
    }

def queue_workflow(full_path, label):
    with open(full_path, "r", encoding="utf-8") as f:
        wf = json.load(f)
    
    payload = convert_workflow_to_api(wf)
    
    r = requests.post(f"{COMFY_URL}/prompt", json=payload, timeout=30)
    if r.status_code == 200:
        pid = r.json().get("prompt_id")
        print(f"Queued {label} -> {pid}")
        return pid
    else:
        print(f"Failed {label}: {r.status_code} {r.text[:300]}")
        return None

def main():
    print("Queuing 5 style test workflows via API...")
    pids = []
    labels = []
    for fname, label in tests:
        path = os.path.join(WORKFLOWS_DIR, fname)
        pid = queue_workflow(path, label)
        if pid:
            pids.append(pid)
            labels.append(label)
        time.sleep(1)

    if not pids:
        print("Nothing queued. Check server or workflow validity.")
        return

    print("Waiting for completion (this can take 5-15+ minutes for all 10 images)...")
    done = {}
    start = time.time()
    while len(done) < len(pids) and time.time() - start < 600:
        try:
            hist = requests.get(f"{COMFY_URL}/history", timeout=10).json()
            for pid, lab in zip(pids, labels):
                if pid in hist and pid not in done:
                    done[pid] = (lab, hist[pid])
                    print(f"  {lab} finished")
        except Exception as e:
            print("poll error", e)
        time.sleep(5)

    print("Copying generated images...")
    for pid, (lab, hist) in done.items():
        for node_data in hist.get("outputs", {}).values():
            for img in node_data.get("images", []):
                fname = img["filename"]
                src = os.path.join(OUTPUT_DIR, img.get("subfolder", ""), fname)
                if os.path.exists(src):
                    dst = os.path.join(TARGET_DIR, f"style_{lab}_{fname}")
                    shutil.copy2(src, dst)
                    print("  Saved:", os.path.basename(dst))

    print("\nAll done! Check assets/style_references/ for the style_*.png test images.")
    print("Generated files:")
    for f in sorted(glob.glob(os.path.join(TARGET_DIR, "style_*.png"))):
        print("  ", os.path.basename(f))

if __name__ == "__main__":
    main()
