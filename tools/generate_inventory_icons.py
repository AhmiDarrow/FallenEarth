#!/usr/bin/env python3
"""Generate 1 PixelLab icon per inventory item (size=180, 1-direction, no review).

Submits 21 create_1_direction_object jobs, polls each until completed,
downloads the resulting PNG, and saves it to assets/sprites/items/<item>.png.

Replaces any pre-existing icon at that path.
"""

import json
import re
import time
import urllib.request
import urllib.error
from pathlib import Path

API = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP = "https://api.pixellab.ai/mcp"
DLH = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "image/png,image/*;q=0.8,*/*;q=0.5",
    "Referer": "https://pixellab.ai/",
}

PROJECT = Path(r"C:\Users\Administrator\FallenEarth")
ICON_DIR = PROJECT / "assets" / "sprites" / "items"

# (item_id, prompt). 1 per item, 1-direction, no review pack.
ITEMS = [
    ("stick", "Inventory icon: a small rough wooden stick, light brown, isolated on transparent background, top-down view, simple game item sprite."),
    ("stone", "Inventory icon: a small grey cobblestone, rough surface, isolated on transparent background, top-down view, simple game item sprite."),
    ("withered_branch", "Inventory icon: a dry twisted withered tree branch, dark grey-brown, isolated on transparent background, top-down view, simple game item sprite."),
    ("raw_meat", "Inventory icon: a chunk of raw red meat with fatty marbling, isolated on transparent background, top-down view, simple game item sprite."),
    ("kelp_fibre", "Inventory icon: a bundle of slimy fibrous kelp strands, dark green-teal, isolated on transparent background, top-down view, simple game item sprite."),
    ("ironwood_bark", "Inventory icon: a piece of metallic dark-iron-coloured bark, ridged texture, isolated on transparent background, top-down view, simple game item sprite."),
    ("iron_ore", "Inventory icon: a chunk of rusty iron ore, brown-red with metallic flecks, isolated on transparent background, top-down view, simple game item sprite."),
    ("copper_ore", "Inventory icon: a chunk of copper ore, green-tinged patina, polished surface, isolated on transparent background, top-down view, simple game item sprite."),
    ("starmetal_ore", "Inventory icon: a chunk of glowing starmetal ore, faintly luminous pale blue, isolated on transparent background, top-down view, simple game item sprite."),
    ("teal_crystal", "Inventory icon: a teal crystal geode cluster, bioluminescent glow, isolated on transparent background, top-down view, simple game item sprite."),
    ("void_shard", "Inventory icon: a void crystal shard cluster, dark purple-black with crystalline facets, isolated on transparent background, top-down view, simple game item sprite."),
    ("ember_crystal", "Inventory icon: an ember crystal gem, warm glowing orange-red, isolated on transparent background, top-down view, simple game item sprite."),
    ("living_metal_sample", "Inventory icon: a chunk of living metal, faintly pulsing bio-mechanical ridges, isolated on transparent background, top-down view, simple game item sprite."),
    ("rusted_scrap", "Inventory icon: a piece of rusted scrap metal, corroded brown-orange surface, isolated on transparent background, top-down view, simple game item sprite."),
    ("bandage", "Inventory icon: a rolled white bandage with red cross stitching, isolated on transparent background, top-down view, simple game item sprite."),
    ("axe_stone", "Inventory icon: a stone axe tool with a stone blade bound to a wooden handle with cord, isolated on transparent background, top-down view, simple game item sprite."),
    ("pickaxe_stone", "Inventory icon: a stone pickaxe tool with a chipped stone head bound to a wooden handle, isolated on transparent background, top-down view, simple game item sprite."),
    ("sleeping_bag", "Inventory icon: a rolled-up sleeping bag, dark color fabric with strap, isolated on transparent background, top-down view, simple game item sprite."),
    ("cooked_meat", "Inventory icon: a cooked meat ration, brown seared surface, isolated on transparent background, top-down view, simple game item sprite."),
    ("antidote", "Inventory icon: a glass vial of green antidote potion, glowing liquid inside, isolated on transparent background, top-down view, simple game item sprite."),
    ("mana_potion", "Inventory icon: a glass vial of blue mana potion, glowing liquid inside, isolated on transparent background, top-down view, simple game item sprite."),
]


def mcp(method, params=None):
    p = json.dumps({"jsonrpc": "2.0", "id": int(time.time() * 1000) % 100000,
                    "method": method, "params": params or {}}).encode()
    h = {"Authorization": f"Bearer {API}", "Content-Type": "application/json",
         "Accept": "application/json, text/event-stream"}
    try:
        b = urllib.request.urlopen(urllib.request.Request(MCP, data=p, headers=h, method="POST"),
                                   timeout=120).read().decode()
        for eb in b.strip().split("\n\n"):
            for l in eb.split("\n"):
                if l.startswith("data: "):
                    d = json.loads(l[6:])
                    if "result" in d:
                        return d["result"]
        return {}
    except Exception as e:
        return {"error": str(e)}


def txt(r):
    for c in r.get("content", []):
        if c.get("type") == "text":
            return c.get("text", "")
    return str(r)


def uid_from(text):
    m = re.search(r"id:\s*([a-f0-9-]+)", text)
    return m.group(1) if m else ""


def is_completed(text):
    return "status: completed" in text or "status: review" not in text and "status: creating" not in text and "status: processing" not in text


def download(url, dest):
    if not url:
        return False
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        d = urllib.request.urlopen(urllib.request.Request(url, headers=DLH)).read()
        dest.write_bytes(d)
        return True
    except Exception as e:
        print(f"  FAIL download {dest.name}: {e}", flush=True)
        return False


def get_url_from_text(text):
    # Look for "south: <url>" line (1-direction output)
    m = re.search(r"(?:^|\n)\s*(?:south|S):\s+(https?://\S+)", text)
    if m:
        return m.group(1)
    # Otherwise look for any https image URL.
    m = re.search(r"(https?://\S+\.(?:png|jpg|jpeg))", text)
    if m:
        return m.group(1)
    return None


def poll_for_completion(uid, max_mins=10):
    for i in range(max_mins * 6):
        time.sleep(10)
        t = txt(mcp("tools/call", {"name": "get_object",
                                    "arguments": {"object_id": uid, "include_preview": False}}))
        if "status: completed" in t:
            return t
        if "status:" in t:
            pass  # still processing
    return None


def main():
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    total = len(ITEMS)
    print(f"=== 1/2: Queue {total} create_1_direction_object jobs (cap 5 in flight) ===", flush=True)
    jobs = []
    BATCH_SIZE = 5
    for batch_start in range(0, total, BATCH_SIZE):
        batch = ITEMS[batch_start:batch_start + BATCH_SIZE]
        for item_id, desc in batch:
            out_path = ICON_DIR / f"{item_id}.png"
            queued = False
            for attempt in range(8):
                t = txt(mcp("tools/call", {"name": "create_1_direction_object",
                                            "arguments": {"description": desc,
                                                           "size": 180,
                                                           "view": "top-down"}}))
                if "rate limit exceeded" in t:
                    print(f"  {item_id}: rate-limited, sleeping 60s...", flush=True)
                    time.sleep(60)
                    continue
                uid = uid_from(t)
                if uid:
                    jobs.append((item_id, uid, out_path))
                    print(f"  {item_id}: queued {uid}", flush=True)
                    queued = True
                else:
                    print(f"  {item_id}: FAILED to queue, response:", flush=True)
                    print(t[:400], flush=True)
                break
            if not queued:
                print(f"  {item_id}: giving up after retries", flush=True)
            time.sleep(0.8)
        # After each batch, poll the items in this batch to completion
        # before queuing the next batch — keeps us under the 20-concurrent
        # cap and avoids the rate-limiter.
        for item_id, uid, out_path in [(j[0], j[1], j[2]) for j in jobs[batch_start:batch_start + BATCH_SIZE]]:
            print(f"  polling {item_id} ({uid})...", flush=True)
            text = poll_for_completion(uid, max_mins=8)
            if not text:
                print(f"  TIMEOUT {item_id}", flush=True)
                continue
            url = get_url_from_text(text)
            if not url:
                print(f"  no url in response for {item_id}:", flush=True)
                print(text[:400], flush=True)
                continue
            if download(url, out_path):
                print(f"  [OK] {item_id} -> {out_path.name}", flush=True)
            time.sleep(0.4)

    print(f"\n=== DONE: regenerated {len(jobs)} icons ===", flush=True)


if __name__ == "__main__":
    main()
