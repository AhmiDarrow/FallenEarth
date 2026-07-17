#!/usr/bin/env python3
"""Recovery: queue anims for 23 mobs + handle 2 failed + 10 backgrounds.

UIDs sourced from batch2 log output.
"""

import json, time, urllib.request, urllib.error, os, re
from pathlib import Path

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP_URL = "https://api.pixellab.ai/mcp"
DLH = {"User-Agent":"Mozilla/5.0","Accept":"image/png","Referer":"https://pixellab.ai/"}

def mcp(method, params=None, retries=3):
    for a in range(retries):
        p = json.dumps({"jsonrpc":"2.0","id":int(time.time()*1000)%100000,"method":method,"params":params or {}}).encode()
        h = {"Authorization":f"Bearer {API_KEY}","Content-Type":"application/json","Accept":"application/json, text/event-stream"}
        try:
            b = urllib.request.urlopen(urllib.request.Request(MCP_URL, data=p, headers=h, method="POST"), timeout=180).read().decode()
            for eb in b.strip().split("\n\n"):
                for l in eb.split("\n"):
                    if l.startswith("data: "):
                        d = json.loads(l[6:])
                        if "result" in d: return d["result"]
            return {}
        except Exception as e:
            if a < retries-1: time.sleep(10)
            else: return {"error": str(e)}

def txt(r):
    for c in r.get("content",[]):
        if c.get("type")=="text": return c.get("text","")
    return str(r)

def uid_from(t):
    m = re.search(r'id:\s*([a-f0-9-]+)', t)
    return m.group(1) if m else ""

def ready(t):
    return "status: completed" in t

def dl(url, dest):
    if not url: return
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        d = urllib.request.urlopen(urllib.request.Request(url, headers=DLH)).read()
        dest.write_bytes(d)
        print(f"  {dest.name} ({len(d)}B)", flush=True)
    except Exception as e:
        print(f"  FAIL {dest.name}: {e}", flush=True)

def wait_and_dl(uid, cid, team, label, max_mins=10):
    for i in range(max_mins*6):
        time.sleep(10)
        t = txt(mcp("tools/call", {"name":"get_character","arguments":{"character_id":uid,"include_preview":False}}))
        if ready(t):
            print(f"  [{label}] {cid} ({(i+1)*10}s)", flush=True)
            # DL rotation
            m = re.search(r'south:\s+(https?://\S+)', t)
            base = f"assets/characters/{cid.split('_')[0]}_{cid.split('_')[1]}" if team=="player" else f"assets/mobs/{cid}"
            if m:
                fname = f"{base}/{cid}_S.png" if team=="player" else f"assets/mobs/{cid}.png"
                dl(m.group(1), fname)
            # DL anim frames
            cur = None
            for line in t.split("\n"):
                am = re.match(r'\s{2}(\S[^(]*?)\s\(south.*?(\d+)f\)', line)
                if am: cur = am.group(1).strip().rstrip(",")
                fm = re.match(r'\s{4}frames:\s+(.+)', line)
                if fm and cur:
                    safe = cur.replace(" ","_").replace("-","_").replace(",","").strip("_")
                    for i2, u in enumerate([x.strip() for x in fm.group(1).split(",")]):
                        dl(u, f"{base}/{safe}/frame_{i2:02d}.png")
                    cur = None
            return True
        if "failed" in t:
            print(f"  [FAILED] {cid}: {t[:100]}", flush=True)
            return False
    print(f"  [TIMEOUT] {cid}", flush=True)
    return False

# ── All UIDs from batch2 log ──
MOB_UID = {
    "rustcarapace_scuttler": "04a965b1-df7f-4d81-9160-bcd8bb7b5531",
    "silkroot_tapper": "2e69effa-d25b-4ccb-9336-8a7a82e7aaf2",
    "echo_chorister": "352d8e10-5c69-4303-9a14-77754f2a3f3f",
    "iron_buck": "f7b4928e-0272-4fd5-b08a-a80d1cdbb066",
    "blight_toad": "5314a71e-ca8a-4c86-bc84-56d94b74a482",
    "dust_devil": "ae460e08-404f-4f2a-9f31-491092063a36",
    "charnel_stalker": "0a63cbfd-732c-45d4-a0ac-90c589a68cec",
    "voidspine_leech": "50336749-90ec-4e83-865a-70ac2b5805be",
    "mycelial_behemoth": "0e456e83-6c92-4bb8-9013-6fe1c10cf652",
    "glimmer_swarm": "816d233e-2733-4d75-93c7-57d7205cd6b7",
    "ferroclaw_reaver": "9cba5615-345a-4c9b-8a61-f71e802bccf9",
    "ash_crawler": "6ea47fff-2250-4f36-b03c-8cdf9aace405",
    "rift_elk": "095d736c-2cd6-4f8f-b49f-263c9fda3438",
    "fungal_hurler": "1cd4a321-ef5b-446b-9f2e-4cef63ca2213",
    "glass_serpent": "58ad51ba-6aa4-46c0-b709-8881a6c88e4e",
    "bone_crawler": "80fb6618-7977-4fc9-8f8e-a6e1a4ab7539",
    "storm_raptor": "7b5ba9b0-ce3b-4162-9b43-f390bdea28de",
    "void_stalker": "4ee7a6ee-5ec7-488b-b748-b06e1f69fade",
    "abyssal_weaver": "68d069e0-8e27-4cbb-8a4a-57eac2988741",
    "lifecycle_horror": "dfc93fe4-ea04-4483-b203-eeeabfc58729",
    "spore_phantom": "e393529c-8bf0-41a0-a849-633ebf9423f1",
    "arc_dynamo": "6879dcac-153e-464b-bd5e-0541c19bb9b8",
    "storm_herald": "5c2bd0eb-b800-4404-8012-f5317a77325f",
    "rift_maw": "3ac6a661-3463-42e7-9780-19fcee685eea",
}

# Mob prompts
MOB_DESC = {
    "rustcarapace_scuttler": "Armored scrap cleaner beetle, segmented rust-brown carapace",
    "silkroot_tapper": "Rooted stationary plant creature, woody trunk body",
    "echo_chorister": "Singing burrow creature, bear-sized quadruped, shaggy brown fur",
    "iron_buck": "Metallic forest stag, iron-gray metallic hide, chrome antlers",
    "blight_toad": "Bloated toxic toad, warty greenish-yellow skin, bulging eyes",
    "dust_devil": "Dust-colored moth swarm, dusty tan wings, swirling dust cloud",
    "charnel_stalker": "Pack-hunting predator, lean feline, patchy dark fur",
    "voidspine_leech": "Parasitic eel-like purple-black body, void energy spine",
    "mycelial_behemoth": "Massive spore-hurling fungal humanoid, mushroom cap head",
    "glimmer_swarm": "Coordinated iridescent green-purple beetles forming swarm",
    "ferroclaw_reaver": "Ferro-organic horror, fused metal scrap and tissue",
    "ash_crawler": "Ash-colored scavenger beetle, chitinous dusty brown carapace",
    "rift_elk": "Large elk with glowing antlers, muscular dark brown fur",
    "fungal_hurler": "Spore-throwing brute, massive mushroom cap head, purple gills",
    "glass_serpent": "Crystalline desert serpent, translucent glass-like yellow plates",
    "bone_crawler": "Bone-armored centipede, each segment with white bone plates",
    "storm_raptor": "Lightning-fast highland raptor, bird-like predator, wings",
    "void_stalker": "Fast void hunter phasing between realities, purple-black",
    "abyssal_weaver": "Void web-spider, eight legs, dark purple crystal chitin",
    "lifecycle_horror": "Regenerating multi-limbed amorphous pale flesh entity",
    "spore_phantom": "Floating spore cloud, vaguely humanoid pale green-gray",
    "arc_dynamo": "Orbital energy construct, mechanical orb, blue energy",
    "storm_herald": "Massive energy boss, humanoid of crackling electrical energy",
    "rift_maw": "Rift core guardian, massive quadruped, living rift portal body",
    "null_shade": "Stealth void wraith, tall gaunt transparent humanoid dark smoke",
}

print("="*60, flush=True)
print("PixelLab Recovery: anims for 23 mobs + 2 failures + 10 bgs", flush=True)
print("="*60, flush=True)

# ── Step 1: Queue animations for existing mobs ──
print("\n--- Step 1: Queue anims for 24 mobs ---", flush=True)
queued = 0
for cid, uid in MOB_UID.items():
    has_dir = os.path.isdir(f"assets/mobs/{cid}")
    if has_dir:
        # Check if anims already downloaded
        anim_count = len([d for d in os.listdir(f"assets/mobs/{cid}") if os.path.isdir(f"assets/mobs/{cid}/{d}")])
        if anim_count >= 4:
            print(f"  {cid}: {anim_count} anims already (skip)", flush=True)
            continue

    print(f"  {cid}: queueing 4 anims...", flush=True)
    for tid in ["breathing-idle","walking","fight-stance-idle-8-frames","falling-back-death"]:
        mcp("tools/call", {"name":"animate_character","arguments":{
            "character_id": uid, "template_animation_id": tid,
            "directions": ["south"], "mode": "template", "frame_count": 8
        }})
        time.sleep(1)
    queued += 1

# ── Step 2: Fix null_shade and ash_crawler ──
print(f"\n--- Step 2: Fix 2 failed mobs ---", flush=True)
for cid in ["ash_crawler", "null_shade"]:
    has_png = os.path.exists(f"assets/mobs/{cid}.png")
    if has_png:
        print(f"  {cid}: PNG exists but may need UID", flush=True)
    print(f"  Creating {cid}...", flush=True)
    t = txt(mcp("tools/call", {"name":"create_character","arguments":{
        "name": cid,
        "description": MOB_DESC.get(cid, "") + ", pixel art top-down view, single color black outline, 128x128",
        "body_type": "humanoid", "n_directions": 4, "mode": "standard", "size": 128,
    }}))
    uid = uid_from(t)
    if uid:
        print(f"  {cid} UID: {uid}", flush=True)
        wait_and_dl(uid, cid, "mob", "CREATE", 12)
        for tid in ["breathing-idle","walking","fight-stance-idle-8-frames","falling-back-death"]:
            mcp("tools/call", {"name":"animate_character","arguments":{"character_id":uid,"template_animation_id":tid,"directions":["south"],"mode":"template","frame_count":8}})
            time.sleep(1)
        wait_and_dl(uid, cid, "mob", "ANIM", 12)
    else:
        print(f"  SKIP {cid}: no UID", flush=True)

# Step 3: Check which anims are ready and download
print(f"\n--- Step 3: Poll and download completed anims ---", flush=True)

# Process: for each mob UID, check if frames now exist, download them
for cid, uid in MOB_UID.items():
    wait_and_dl(uid, cid, "mob", "POLL", 5)

# Step 4: Backgrounds (simple, no UIDs needed since they failed)
print(f"\n--- Step 4: Backgrounds ---", flush=True)
BGS = [
    ("bg_ash_wastes", "Barren toxic dust plains, cracked earth, ash, orange-brown haze"),
    ("bg_rust_canyons", "Deep canyons filled with rusted wreckage, red-brown rock"),
    ("bg_neon_bogs", "Toxic wetlands with glowing neon pollution, purple-green water"),
    ("bg_scorched_plains", "Endless sun-baked cracked mud flats, heat shimmer, dry grass"),
    ("bg_ironwood_thicket", "Dense metallic-barked forest, twisted ironwood trees"),
    ("bg_glass_dunes", "Vast desert of fused silica sand dunes, glass shards"),
    ("bg_corpse_fields", "Mass grave battlefield, bones, grey decaying earth, mist"),
    ("bg_stormspire_highlands", "High rocky peaks with lightning storms, purple-black clouds"),
    ("bg_toxin_marshes", "Acidic swamps with bubbling toxic pools, yellow-green fog"),
    ("bg_dead_city_outskirts", "Ruined suburban sprawl, collapsed buildings, rusted cars"),
]
for bslug, bdesc in BGS:
    if os.path.exists(f"assets/backgrounds/{bslug}.png"):
        print(f"  {bslug}: already exists", flush=True)
        continue
    print(f"  {bslug}: creating...", flush=True)
    t = txt(mcp("tools/call", {"name":"create_1_direction_object","arguments":{
        "name": bslug,
        "description": f"{bdesc}, wide landscape background, pixel art, game parallax, widescreen",
        "width": 256, "height": 256,
    }}))
    uid = uid_from(t)
    if uid:
        print(f"  UID: {uid}", flush=True)
        for i in range(15):
            time.sleep(10)
            t = txt(mcp("tools/call", {"name":"get_character","arguments":{"character_id":uid,"include_preview":False}}))
            if ready(t):
                m = re.search(r'download_url:\s+(https?://\S+)', t)
                if m: dl(m.group(1), f"assets/backgrounds/{bslug}.png")
                break
    else:
        # Try ui_asset as fallback
        t = txt(mcp("tools/call", {"name":"create_ui_asset","arguments":{
            "name": bslug, "description": bdesc + ", game UI background landscape",
            "width": 688, "height": 288, "elements": ["panel"], "mode": "standard",
        }}))
        uid = uid_from(t)
        if uid:
            print(f"  bg UID (ui): {uid}", flush=True)
            for i in range(15):
                time.sleep(10)
                t = txt(mcp("tools/call", {"name":"get_character","arguments":{"character_id":uid,"include_preview":False}}))
                if ready(t):
                    m = re.search(r'download_url:\s+(https?://\S+)', t)
                    if m: dl(m.group(1), f"assets/backgrounds/{bslug}.png")
                    break

print(f"\n{'='*60}", flush=True)
print("Done! Run 'python build_spriteframes.py' after.", flush=True)
print(f"{'='*60}", flush=True)
