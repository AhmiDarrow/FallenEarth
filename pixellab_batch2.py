#!/usr/bin/env python3
"""PixelLab Batch 2: Create remaining 25 mobs + 10 backgrounds. Run standalone.

Usage: python pixellab_batch2.py

Tries each creation up to 3 times, polls until complete, downloads assets.
Serial processing: one at a time to avoid overwhelming the API.
Expected runtime: ~2-3 hours.
"""

import json, re, time, urllib.request, urllib.error
from pathlib import Path

API = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP = "https://api.pixellab.ai/mcp"
DLH = {"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
       "Accept":"image/png","Referer":"https://pixellab.ai/"}

def mcp(method, params=None):
    p = json.dumps({"jsonrpc":"2.0","id":int(time.time()*1000)%100000,"method":method,"params":params or {}}).encode()
    h = {"Authorization":f"Bearer {API}","Content-Type":"application/json","Accept":"application/json, text/event-stream"}
    try:
        b = urllib.request.urlopen(urllib.request.Request(MCP, data=p, headers=h, method="POST"), timeout=120).read().decode()
        for eb in b.strip().split("\n\n"):
            for l in eb.split("\n"):
                if l.startswith("data: "):
                    d = json.loads(l[6:])
                    if "result" in d: return d["result"]
        return {}
    except Exception as e: return {"error": str(e)}

def txt(r):
    for c in r.get("content",[]):
        if c.get("type")=="text": return c.get("text","")
    return str(r)

def uid_from(t):
    m = re.search(r'id:\s*([a-f0-9-]+)', t)
    return m.group(1) if m else ""

def is_ready(t):
    return "status: completed" in t

def download(url, dest):
    if not url: return
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        d = urllib.request.urlopen(urllib.request.Request(url, headers=DLH)).read()
        dest.write_bytes(d)
        print(f"  {dest.name} ({len(d)}B)", flush=True)
    except Exception as e:
        print(f"  FAIL {dest.name}: {e}", flush=True)

def create_with_retry(name, desc, body_type="humanoid", max_retries=5):
    for attempt in range(max_retries):
        t = txt(mcp("tools/call", {"name":"create_character","arguments":{
            "name":name,"description":desc+", pixel art top-down view, single color black outline, 128x128",
            "body_type":body_type,"n_directions":4,"mode":"standard","size":128,
            "view":"low top-down","outline":"single color black outline","detail":"medium detail",
        }}))
        uid = uid_from(t)
        if uid: return uid
        print(f"  Retry {attempt+1}/{max_retries}...", flush=True)
        time.sleep(15)
    return ""

def poll_with_retry(uid, cid, max_mins=15):
    for i in range(max_mins*6):
        time.sleep(10)
        t = txt(mcp("tools/call",{"name":"get_character","arguments":{"character_id":uid,"include_preview":False}}))
        if is_ready(t):
            print(f"  {cid} ready ({(i+1)*10}s)", flush=True)
            m = re.search(r'south:\s+(https?://\S+)', t)
            if m: download(m.group(1), Path("assets/mobs") / f"{cid}.png")
            cur = None
            for line in t.split("\n"):
                am = re.match(r'\s{2}(\S[^(]*?)\s\(south.*?(\d+)f\)', line)
                if am: cur = am.group(1).strip().rstrip(",")
                fm = re.match(r'\s{4}frames:\s+(.+)', line)
                if fm and cur:
                    s = cur.replace(" ","_").replace("-","_").replace(",","").strip("_")
                    base = Path("assets/mobs") / cid / s
                    base.mkdir(parents=True, exist_ok=True)
                    for i2, u in enumerate([x.strip() for x in fm.group(1).split(",")]):
                        download(u, base / f"frame_{i2:02d}.png")
                    cur = None
            return True
        if i > 0 and i % 9 == 0:
            print(f"  {cid}: still waiting ({i*10}s)...", flush=True)
    print(f"  [TIMEOUT] {cid}", flush=True)
    return False

MOBS = [
    ("rustcarapace_scuttler", "Armored scrap cleaner, beetle-like, segmented rust-brown carapace, six jointed legs"),
    ("silkroot_tapper", "Rooted stationary plant creature, woody trunk body, root tendrils, branch arms"),
    ("echo_chorister", "Singing burrow creature, bear-sized, shaggy dusty brown fur, large ears, vocal sac"),
    ("iron_buck", "Metallic forest stag, iron-gray metallic hide, chrome-like branching antlers"),
    ("blight_toad", "Bloated toxic toad, wide squat warty greenish-yellow skin, bulging eyes"),
    ("dust_devil", "Dust-colored moth swarm, dusty tan wings, cloud of swirling dust"),
    ("charnel_stalker", "Pack-hunting predator, lean feline with patchy dark fur, barbed tendrils"),
    ("voidspine_leech", "Parasitic energy drainer, eel-like purple-black body with void energy spine"),
    ("mycelial_behemoth", "Massive spore-hurling hulk, fungal humanoid, broad shoulders, mushroom cap head"),
    ("glimmer_swarm", "Coordinated acidic insects, iridescent green-purple beetles forming swarm"),
    ("ferroclaw_reaver", "Ferro-organic horror, fused metal scrap, drilling claw arm"),
    ("ash_crawler", "Ash-colored scavenger beetle, segmented chitinous dusty gray-brown carapace"),
    ("rift_elk", "Large elk with glowing antlers, muscular dark brown fur, branching antlers"),
    ("fungal_hurler", "Spore-throwing brute, massive mushroom cap head with purple gills"),
    ("glass_serpent", "Crystalline desert serpent, translucent glass-like pale yellow segments"),
    ("bone_crawler", "Bone-armored centipede, each segment with curved white bone plates"),
    ("storm_raptor", "Lightning-fast highland raptor, bipedal bird-like predator, folded wings"),
    ("void_stalker", "Fast void hunter phasing between realities, feline purple-black void energy"),
    ("abyssal_weaver", "Void web-spider, eight legs, dark purple crystal chitin body"),
    ("null_shade", "Stealth void wraith, tall gaunt transparent humanoid of dark smoke"),
    ("lifecycle_horror", "Regenerating multi-limbed pale fleshy entity, limbs at odd angles"),
    ("spore_phantom", "Floating spore cloud, vaguely humanoid upper body of pale green-gray spores"),
    ("arc_dynamo", "Orbital energy construct, hovering mechanical orb with blue energy cores"),
    ("storm_herald", "Massive energy boss, enormous humanoid of crackling electrical energy"),
    ("rift_maw", "Rift core guardian, massive quadruped with body like living rift portal"),
]

def main():
    print("="*60, flush=True)
    print("PixelLab Batch 2: Creating 25 mobs + 10 backgrounds", flush=True)
    print("="*60, flush=True)

    # Mobs
    for i, (cid, desc) in enumerate(MOBS):
        print(f"\n[{i+1}/25] {cid}...", flush=True)
        uid = create_with_retry(cid, desc)
        if not uid:
            print(f"  SKIP {cid}: could not create after retries", flush=True)
            continue
        print(f"  UID: {uid}", flush=True)
        time.sleep(5)
        if poll_with_retry(uid, cid, 15):
            # Queue animations
            for tid in ["breathing-idle","walking","fight-stance-idle-8-frames","falling-back-death"]:
                mcp("tools/call",{"name":"animate_character","arguments":{
                    "character_id":uid,"template_animation_id":tid,
                    "directions":["south"],"mode":"template","frame_count":8,
                }})
                time.sleep(1)
            poll_with_retry(uid, cid, 20)  # Wait for anims

    # Backgrounds
    print("\n"+"="*60, flush=True)
    print("Creating 10 backgrounds...", flush=True)
    print("="*60, flush=True)
    BGS = [
        ("bg_ash_wastes", "Wasteland horizon with ash-covered ruins under hazy orange sky, cracked barren earth, dust"),
        ("bg_rust_canyons", "Deep canyon with rusted wreckage, red-brown walls, twisted metal, hazy orange-brown sky"),
        ("bg_neon_bogs", "Polluted wetlands with glowing neon pink/green flora, bioluminescent plants in dark water"),
        ("bg_scorched_plains", "Cracked baked earth to horizon, bright sun, heat haze, charred farm ruins"),
        ("bg_ironwood_thicket", "Dense metallic forest with chrome/iron trees, metallic vines, blue energy nodes"),
        ("bg_glass_dunes", "Shimmering dunes of melted glass fragments, crystal clusters, half-buried structures"),
        ("bg_corpse_fields", "Old battlefield with bones and rusted tank hulls, crater-pocked earth, dark grey sky"),
        ("bg_stormspire_highlands", "High plateau with towers crackling blue-white lightning, dark storm clouds"),
        ("bg_toxin_marshes", "Swamp of green-yellow chemical sludge, dead twisted trees, gas bubbles, sickly sky"),
        ("bg_dead_city_outskirts", "Ruined megacity edges with collapsed skyscrapers, rubble streets, void crack"),
    ]
    for bid, desc in BGS:
        print(f"Creating {bid}...", flush=True)
        t = txt(mcp("tools/call",{"name":"create_ui_asset","arguments":{
            "name":bid,"description":desc+", 688x288 pixel art landscape","width":688,"height":288,
        }}))
        oid = ""
        for m in re.finditer(r'(?:id|object_id):\s*([a-f0-9-]+)', t):
            oid = m.group(1)
        if oid:
            print(f"  -> {oid}", flush=True)
            for i in range(90):
                time.sleep(10)
                r = txt(mcp("tools/call",{"name":"get_object","arguments":{"object_id":oid}}))
                if is_ready(r):
                    print(f"  {bid} ready", flush=True)
                    mu = re.search(r'(?:download_url|url|image_url):\s+(https?://\S+)', r)
                    if mu: download(mu.group(1), Path("assets/backgrounds") / f"{bid}.png")
                    break
                if i % 9 == 0:
                    print(f"  waiting... ({i*10}s)", flush=True)
        else:
            print(f"  no object_id returned: {t[:100]}", flush=True)

    print("\n=== BATCH 2 DONE ===", flush=True)
    print("Run python build_spriteframes.py to create .tres resources", flush=True)

if __name__ == "__main__":
    main()
