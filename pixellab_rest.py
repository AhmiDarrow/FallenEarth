#!/usr/bin/env python3
"""Rest API approach - call PixelLab REST API directly instead of MCP."""

import json, time, urllib.request, urllib.error, os, re
from pathlib import Path

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP_URL = "https://api.pixellab.ai/mcp"
DLH = {"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
       "Accept":"image/png,image/*;q=0.8,*/*;q=0.5","Referer":"https://pixellab.ai/"}

def mcp(method, params=None, retries=3):
    for attempt in range(retries):
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
        except urllib.error.HTTPError as e:
            err = e.read().decode()[:200]
            if attempt < retries-1:
                time.sleep(5)
                continue
            return {"error": str(e.code), "body": err}
        except Exception as e:
            if attempt < retries-1:
                time.sleep(5)
                continue
            return {"error": str(e)}

def text(r):
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
        return True
    except Exception as e:
        print(f"  FAIL {dest.name}: {e}", flush=True)
        return False

def poll(uid, label, max_mins=10):
    for i in range(max_mins*6):
        time.sleep(10)
        t = text(mcp("tools/call", {"name":"get_character","arguments":{"character_id":uid,"include_preview":False}}))
        if ready(t):
            print(f"  [{label}] done ({(i+1)*10}s)", flush=True)
            return t
        if "failed" in t or "error" in t:
            print(f"  [{label}] FAILED: {t[:100]}", flush=True)
            return None
    print(f"  [{label}] TIMEOUT", flush=True)
    return None

def dl_char(t, cid, team):
    m = re.search(r'south:\s+(https?://\S+)', t)
    if m:
        dest = f"assets/characters/{cid.split('_')[0]}_{cid.split('_')[1]}/{cid}_S.png" if team=="player" else f"assets/mobs/{cid}.png"
        dl(m.group(1), dest)
    cur = None
    for line in t.split("\n"):
        am = re.match(r'\s{2}(\S[^(]*?)\s\(south.*?(\d+)f\)', line)
        if am: cur = am.group(1).strip().rstrip(",")
        fm = re.match(r'\s{4}frames:\s+(.+)', line)
        if fm and cur:
            base = f"assets/characters/{cid.split('_')[0]}_{cid.split('_')[1]}" if team=="player" else f"assets/mobs/{cid}"
            safe = cur.replace(" ","_").replace("-","_").replace(",","").strip("_")
            for i2, u in enumerate([x.strip() for x in fm.group(1).split(",")]):
                dl(u, f"{base}/{safe}/frame_{i2:02d}.png")
            cur = None

# Background prompts
BGS = [
    ("bg_ash_wastes", "Ash Wastes", "Barren toxic dust plains, cracked earth, twisted irradiated scrub, constant wind-blown ash, low visibility, orange-brown haze"),
    ("bg_rust_canyons", "Rust Canyons", "Deep canyons filled with rusted wreckage from old corporate wars, red-brown rock walls, broken machinery, smoke haze"),
    ("bg_neon_bogs", "Neon Bogs", "Toxic wetlands with glowing neon pollution, purple-green water, bioluminescent fungi, mist, industrial runoff"),
    ("bg_scorched_plains", "Scorched Plains", "Endless sun-baked cracked mud flats, distant heat shimmer, bleached bones, sparse dry grass, white-yellow sky"),
    ("bg_ironwood_thicket", "Ironwood Thicket", "Dense metallic-barked forest, dark twisted ironwood trees, blue-green undergrowth, dim light, rust-colored leaves"),
    ("bg_glass_dunes", "Glass Dunes", "Vast desert of fused silica sand dunes, glass shards embedded, shimmering heat waves, pale blue-white sky"),
    ("bg_corpse_fields", "Corpse Fields", "Mass grave battlefield, scattered bones and wreckage, grey decaying earth, mist, carrion birds circling, dead trees"),
    ("bg_stormspire_highlands", "Stormspire Highlands", "High rocky peaks with constant lightning storms, purple-black clouds, tall stone spires, electrical arcs in sky"),
    ("bg_toxin_marshes", "Toxin Marshes", "Acidic swamps with bubbling toxic pools, yellow-green fog, mutated cattails, rusty metal structures half-sunken"),
    ("bg_dead_city_outskirts", "Dead City Outskirts", "Ruined suburban sprawl, collapsed buildings, overgrown roads, rusted cars, grey concrete, fading graffiti"),
]

print("="*60, flush=True)
print("PixelLab REST: Animations + Backgrounds (serial, reliable)", flush=True)
print("="*60, flush=True)

# Step 1: Get all mob UIDs from the existing rotation PNGs
# We need to check what IDs are on PixelLab side
# For mobs that already have rotation PNGs, we need to either:
# A) Re-create them and attach new anims, or
# B) Find their existing UIDs

# Since batch2's UIDs were lost, we need to recreate
# But first try to see if get_character works with known IDs
KNOWN = {
    "ashveil_grazer": ["baa5181d-9687-4dc4-b5c1-92c81374cb41"],
    "lumen_drifter": ["355538d5-b063-4c45-aac3-3297d34a6e48"],
}

MOBS = [
    "rustcarapace_scuttler", "silkroot_tapper", "echo_chorister", "iron_buck", "blight_toad",
    "dust_devil", "charnel_stalker", "voidspine_leech", "mycelial_behemoth", "glimmer_swarm",
    "ferroclaw_reaver", "ash_crawler", "rift_elk", "fungal_hurler", "glass_serpent",
    "bone_crawler", "storm_raptor", "void_stalker", "abyssal_weaver", "null_shade",
    "lifecycle_horror", "spore_phantom", "arc_dynamo", "storm_herald", "rift_maw",
]
DESC = [
    "Armored scrap cleaner, beetle-like, segmented rust-brown carapace, six jointed legs, mandibles",
    "Rooted stationary plant creature, woody trunk body, root tendrils, branch arms with leaves",
    "Singing burrow creature, bear-sized quadruped, shaggy dusty brown fur, large ears, vocal sac",
    "Metallic forest stag, iron-gray metallic hide, chrome-like branching antlers, lean body",
    "Bloated toxic toad, wide squat warty greenish-yellow skin, bulging eyes, toxin sacs",
    "Dust-colored moth swarm, dusty tan wings with veins, cloud of swirling dust, indistinct edges",
    "Pack-hunting predator, lean feline with patchy dark fur, barbed tendrils, glowing yellow eyes",
    "Parasitic energy drainer, eel-like purple-black body with void energy spine, sucker mouth",
    "Massive spore-hurling hulk, fungal humanoid, broad shoulders, one club fist, mushroom cap head",
    "Coordinated acidic insects, iridescent green-purple beetles forming mobile swarm",
    "Ferro-organic horror, fused metal scrap and tissue, drilling claw arm, magnetic claw",
    "Ash-colored scavenger beetle, segmented chitinous dusty gray-brown carapace, six legs",
    "Large elk with glowing antlers, muscular dark brown fur, branching antlers glowing blue-white",
    "Spore-throwing brute, massive mushroom cap head with purple gills, shelf fungi body",
    "Crystalline desert serpent, translucent glass-like pale yellow segmented plates",
    "Bone-armored centipede, each segment with curved white bone plates, dozens of legs",
    "Lightning-fast highland raptor, bipedal bird-like predator, folded wings, feathered crest",
    "Fast void hunter phasing between realities, feline purple-black void energy, chitin patches",
    "Void web-spider, eight legs, dark purple crystal chitin, glowing rift patterns on abdomen",
    "Stealth void wraith, tall gaunt transparent humanoid of dark smoke, white dot eyes",
    "Regenerating multi-limbed amorphous pale flesh entity, limbs at odd angles, faces on torso",
    "Floating spore cloud, vaguely humanoid upper body of pale green-gray spores",
    "Orbital energy construct, hovering mechanical orb with white panels, blue energy cores",
    "Massive energy boss, enormous humanoid of crackling electrical energy and storm cloud",
    "Rift core guardian, massive quadruped with body like living rift portal, concentric teeth",
]

# Process mobs that already have PNG but no anim dir
total_mobs = len(MOBS)
for idx, (cid, desc) in enumerate(zip(MOBS, DESC)):
    has_png = os.path.exists(f"assets/mobs/{cid}.png")
    has_anim = os.path.isdir(f"assets/mobs/{cid}")
    if has_anim:
        print(f"[{idx+1}/{total_mobs}] {cid}: already has anims", flush=True)
        continue

    print(f"[{idx+1}/{total_mobs}] {cid}: creating...", flush=True)
    t = text(mcp("tools/call", {"name":"create_character","arguments":{
        "name": cid,
        "description": f"{desc}, pixel art top-down view, single color black outline, 128x128",
        "body_type": "humanoid", "n_directions": 4, "mode": "standard", "size": 128,
        "view": "low top-down", "outline": "single color black outline", "detail": "medium detail",
    }}))
    uid = uid_from(t)
    if not uid:
        print(f"  No UID, retrying once...", flush=True)
        time.sleep(5)
        t = text(mcp("tools/call", {"name":"create_character","arguments":{
            "name": cid, "description": f"{desc}, pixel art top-down view, 128x128",
            "body_type": "humanoid", "n_directions": 4, "mode": "standard", "size": 128,
        }}))
        uid = uid_from(t)
    if not uid:
        print(f"  SKIP {cid}: no UID after retry", flush=True)
        continue

    print(f"  UID: {uid}", flush=True)

    # Poll creation
    t = poll(uid, cid, 12)
    if t:
        team = "mob"
        dl_char(t, cid, team)
        # Queue anims
        for tid in ["breathing-idle","walking","fight-stance-idle-8-frames","falling-back-death"]:
            mcp("tools/call", {"name":"animate_character","arguments":{"character_id":uid,"template_animation_id":tid,"directions":["south"],"mode":"template","frame_count":8}})
            time.sleep(1)
        # Poll anims
        t = poll(uid, f"{cid}_anim", 12)
        if t:
            dl_char(t, cid, team)

# Step 3: Backgrounds
print(f"\n{'='*60}", flush=True)
print(f"Creating {len(BGS)} backgrounds...", flush=True)
print(f"{'='*60}", flush=True)
for bslug, bname, bdesc in BGS:
    has_png = os.path.exists(f"assets/backgrounds/{bslug}.png")
    desc = f"{bdesc}, wide landscape background scene, 1024x576, parallax layer, atmospheric, top-down game style"
    # No dedicated background tool - use create_1_direction_object or create_ui_asset
    print(f"  {bslug}: need background tool...", flush=True)
    # Try create_ui_asset
    t = text(mcp("tools/call", {"name":"create_ui_asset","arguments":{
        "name": f"bg_{bname.replace(' ','_').lower()}",
        "description": desc,
        "width": 688, "height": 288,
        "elements": ["panel"],
        "mode": "standard",
    }}))
    wid = uid_from(t)
    if wid:
        print(f"  UID: {wid}", flush=True)
        for i in range(6):
            time.sleep(10)
            t = text(mcp("tools/call", {"name":"get_character","arguments":{"character_id":wid,"include_preview":False}}))
            if "completed" in t:
                m = re.search(r'download_url:\s+(https?://\S+)', t)
                if m:
                    dl(m.group(1), f"assets/backgrounds/{bslug}.png")
                break
    # If ui_asset didn't work, try create_1_direction_object
    if not os.path.exists(f"assets/backgrounds/{bslug}.png"):
        t = text(mcp("tools/call", {"name":"create_1_direction_object","arguments":{
            "name": f"bg_{bname.replace(' ','_').lower()}",
            "description": bdesc + ", landscape background, pixel art, game parallax",
            "width": 256, "height": 256,
        }}))
        wid = uid_from(t)
        if wid:
            for i in range(6):
                time.sleep(10)
                t = text(mcp("tools/call", {"name":"get_character","arguments":{"character_id":wid,"include_preview":False}}))
                if "completed" in t:
                    m = re.search(r'download_url:\s+(https?://\S+)', t)
                    if m:
                        dl(m.group(1), f"assets/backgrounds/{bslug}.png")
                    break

print(f"\n{'='*60}", flush=True)
print("Done!", flush=True)
print(f"{'='*60}", flush=True)
