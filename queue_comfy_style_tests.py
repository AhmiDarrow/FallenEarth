import json
import time
import requests
import shutil
import os
from pathlib import Path

COMFY_DIR = r"C:\Users\Administrator\Documents\comfy\ComfyUI"
PROJECT_DIR = r"C:\Users\Administrator\FallenEarth"
WORKFLOWS_DIR = os.path.join(PROJECT_DIR, "comfyui_workflows")
OUTPUT_DIR = os.path.join(COMFY_DIR, "output")
TARGET_DIR = os.path.join(PROJECT_DIR, "assets", "style_references")

# Ensure target
os.makedirs(TARGET_DIR, exist_ok=True)

# The 5 test files
tests = [
    ("style_test_01_balanced.json", "test_01_balanced"),
    ("style_test_02_neon_cyberpunk.json", "test_02_neon"),
    ("style_test_03_eldritch.json", "test_03_eldritch"),
    ("style_test_04_desolate.json", "test_04_desolate"),
    ("style_test_05_stylized.json", "test_05_stylized"),
]

COMFY_URL = "http://127.0.0.1:8188"

def wait_for_server(timeout=120):
    print("Waiting for ComfyUI server...")
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(f"{COMFY_URL}/system_stats", timeout=5)
            if r.status_code == 200:
                print("ComfyUI server is ready!")
                return True
        except:
            pass
        time.sleep(3)
    print("Server did not start in time.")
    return False

def queue_workflow(workflow_path, client_id="grok-style-test"):
    with open(workflow_path, "r", encoding="utf-8") as f:
        workflow = json.load(f)
    
    # Set a higher batch for more variations? For now keep as-is (user can adjust), or force batch=1 or 2
    # To get one good image per test, we'll leave it or set to 1
    for node in workflow.get("nodes", []):
        if node.get("type") == "EmptyLatentImage":
            # Keep current batch or force 2 for options
            # widgets_values is [width, height, batch]
            if len(node.get("widgets_values", [])) >= 3:
                node["widgets_values"][2] = 2   # 2 images per test
            break
    
    payload = {
        "prompt": workflow,
        "client_id": client_id
    }
    
    resp = requests.post(f"{COMFY_URL}/prompt", json=payload)
    if resp.status_code != 200:
        print(f"Failed to queue {workflow_path}: {resp.text}")
        return None
    
    data = resp.json()
    prompt_id = data.get("prompt_id")
    print(f"Queued {os.path.basename(workflow_path)} -> prompt_id: {prompt_id}")
    return prompt_id

def wait_for_completion(prompt_ids, timeout=300):
    print("Waiting for generations to complete...")
    completed = {}
    start = time.time()
    while time.time() - start < timeout:
        try:
            r = requests.get(f"{COMFY_URL}/history", timeout=10)
            history = r.json()
            all_done = True
            for pid in prompt_ids:
                if pid in history:
                    completed[pid] = history[pid]
                else:
                    all_done = False
            if all_done:
                print("All prompts completed!")
                return completed
        except Exception as e:
            pass
        time.sleep(5)
    print("Timeout waiting for some images.")
    return completed

def copy_outputs(completed, tests_map):
    print("Copying generated images...")
    copied = []
    for pid, hist in completed.items():
        outputs = hist.get("outputs", {})
        for node_id, node_out in outputs.items():
            images = node_out.get("images", [])
            for img in images:
                filename = img.get("filename")
                if not filename:
                    continue
                src = os.path.join(OUTPUT_DIR, filename)
                if not os.path.exists(src):
                    # Sometimes subfolders
                    src = os.path.join(OUTPUT_DIR, img.get("subfolder", ""), filename)
                if os.path.exists(src):
                    # Find matching test name
                    label = "unknown"
                    for wf, lab in tests_map.items():
                        if lab in filename or lab.split("_")[1] in filename.lower():
                            label = lab
                            break
                    dst_name = f"{label}_{filename}"
                    dst = os.path.join(TARGET_DIR, dst_name)
                    shutil.copy2(src, dst)
                    copied.append(dst)
                    print(f"  Copied: {dst_name}")
    return copied

def main():
    # Start server if not running? For now assume or start
    print("=== Starting ComfyUI (this may take time to load models) ===")
    
    # Use Start-Process equivalent in python? Use subprocess
    import subprocess
    import sys
    
    # Launch in background
    launch_cmd = [
        os.path.join(COMFY_DIR, ".venv", "Scripts", "python.exe"),
        "main.py",
        "--listen",
        "--port", "8188",
        "--disable-auto-launch"
    ]
    
    # Start detached
    proc = subprocess.Popen(
        launch_cmd,
        cwd=COMFY_DIR,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform == "win32" else 0
    )
    print(f"ComfyUI started with PID {proc.pid}. Waiting for ready...")
    
    if not wait_for_server(timeout=180):
        print("Could not connect to server. Please start ComfyUI manually and rerun.")
        return
    
    # Now queue all tests
    prompt_ids = []
    tests_map = {}
    for wf_name, label in tests:
        wf_path = os.path.join(WORKFLOWS_DIR, wf_name)
        if not os.path.exists(wf_path):
            print(f"Missing workflow: {wf_path}")
            continue
        pid = queue_workflow(wf_path)
        if pid:
            prompt_ids.append(pid)
            tests_map[pid] = label
        time.sleep(1)
    
    if not prompt_ids:
        print("No prompts queued.")
        return
    
    # Wait
    completed = wait_for_completion(prompt_ids)
    
    # Copy results
    copied = copy_outputs(completed, tests_map)
    
    print("\n=== Done ===")
    print(f"Generated and copied {len(copied)} test images to {TARGET_DIR}")
    for c in copied:
        print(" -", os.path.basename(c))
    
    print("\nPlease review the images in assets/style_references/ (the test_*.png files)")
    print("Then tell me which one you like best (e.g. 'test_03_eldritch is the winner').")

if __name__ == "__main__":
    main()
