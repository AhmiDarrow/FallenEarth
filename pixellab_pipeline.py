#!/usr/bin/env python3
"""PixelLab Pipeline — step by step, respecting 10 concurrent job limit."""

import json, re, time, urllib.request, urllib.error
from pathlib import Path

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP_URL = "https://api.pixellab.ai/mcp"
POLL = 10

MOBS = Path("assets/mobs")
CHARS = Path("assets/characters")
BGS = Path("assets/backgrounds")

def mcp(method, params=None):
    payload = json.dumps({
        "jsonrpc": "2.0", "id": int(time.time()*1000)%100000,
        "method": method, "params": params or {},
    }).encode()
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    for _ in range(3):
        try:
            req = urllib.request.Request(MCP_URL, data=payload, headers=headers, method="POST")
            resp = urllib.request.urlopen(req)
            body = resp.read().decode()
            for eb in body.strip().split("\n\n"):
                for line in eb.split("\n"):
                    if line.startswith("data: "):
                        data = json.loads(line[6:])
                        if "result" in data:
                            return data["result"]
                        return data
            return {"raw": body}
        except urllib.error.HTTPError as e:
            if e.code == 429:
                sec = int(e.headers.get("Retry-After", "30"))
                print(f"  [429] wait {sec}s", flush=True)
                time.sleep(sec)
                continue
            return {"isError": True, "text": e.read().decode()[:200]}
        except Exception as e:
            time.sleep(5)
    return {"isError": True, "text": "max retries"}

def txt(r):
    if r.get("isError"): return r.get("text","?")
    for c in r.get("content",[]):
        if c.get("type") == "text":
            return c.get("text","")
    return str(r)

def get_id(text):
    m = re.search(r'id:\s*([a-f0-9-]+)', text)
    return m.group(1) if m else ""

def is_ready(text):
    return "status: completed" in text and "pending" not in text.lower()

def poll_until_ready(char_id, label, timeout_mins=15):
    for i in range(timeout_mins * 6):
        time.sleep(POLL)
        r = mcp("tools/call", {"name":"get_character","arguments":{"character_id":char_id,"include_preview":False}})
        t = txt(r)
        if is_ready(t):
            print(f"  [DONE] {label} ({(i+1)*POLL}s)", flush=True)
            return t
        if i % 12 == 0:
            pct = re.search(r'(\d+)%', t)
            s = f"{pct.group(1)}%" if pct else "?"
            jobs = "pending" if "pending" in t.lower() else "creating"
            print(f"  {label}: {jobs} {s}", flush=True)
    print(f"  [TIMEOUT] {label}", flush=True)
    return ""

def download_rotations(text, label, team="mob"):
    urls = {}
    for m in re.finditer(r'\s{2}(\w+):\s+(https?://\S+)', text):
        urls[m.group(1)] = m.group(2)
    if "south" in urls:
        if team == "player":
            race, gender = label.split("_", 1)
            dest = CHARS / f"{race}_{gender}" / f"{race}_{gender}_S.png"
        else:
            dest = MOBS / f"{label}.png"
        download(urls["south"], dest)

def download_anims(text, label, team="mob"):
    current = None
    for line in text.split("\n"):
        am = re.match(r'\s{2}([^(]+)\s\((\w+),\s*(\d+)f?\)', line)
        if am:
            current = am.group(1).strip()
        fm = re.match(r'\s{4}frames:\s+(.+)', line)
        if fm and current:
            urls = [u.strip() for u in fm.group(1).split(",")]
            if team == "player":
                race, gender = label.split("_", 1)
                adir = CHARS / f"{race}_{gender}" / current
            else:
                adir = MOBS / label / current
            adir.mkdir(parents=True, exist_ok=True)
            for i, url in enumerate(urls):
                download(url, adir / f"frame_{i:02d}.png")
            print(f"    {current}: {len(urls)} frames", flush=True)

def download(url, dest):
    if not url: return
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(url, str(dest))
    except Exception as e:
        print(f"    FAILED {dest.name}: {e}", flush=True)

# The 10 already-created characters
EXISTING = [
    ("human_male", "b4a12c49-7e18-4b7f-88ef-aa243142be1b"),
    ("human_female", "2e872b24-772c-41cf-87b9-933efdedd051"),
    ("mutant_male", "9ba08023-6548-4ed4-9b5a-94a8a8a354ac"),
    ("mutant_female", "88671592-ebcd-4d6a-a0d2-eaafda412bc2"),
    ("sentientai_male", "e2ec51df-0808-4524-97db-2dc22b08ca80"),
    ("sentientai_female", "9454832e-823b-4772-a2e3-0479287a9834"),
    ("cyborg_male", "3e77535e-9e0d-4bab-ba64-4b9169f2dadf"),
    ("cyborg_female", "6d7d2944-f6b0-409c-bb43-e15ce5b5462c"),
    ("chthon_male", "4325ebaf-74ae-4a09-a0f3-a7c1a6bf8325"),
    ("chthon_female", "13979e12-26c0-4eb5-8ec5-d67cfb7a6495"),
]

HUMANOID_ANIMS = [
    ("idle","breathing-idle"), ("walk","walking"),
    ("attack","fight-stance-idle-8-frames"), ("hurt","falling-back-death"),
]

QUAD_ANIMS = [
    ("idle","idle"), ("run","running-8-frames"),
    ("attack","angry"), ("death","falling-back-death"),
]

TEMPLATE_FALLBACK = {
    "beetle":"dog","toad":"cat","moth":"cat","snake":"dog",
    "centipede":"dog","bird":"horse","spider":"dog","hippo":"bear",
    "jellyfish":"cat",
}

def step1_download_existing():
    """Download south rotations + queue + wait for anims for the 10 existing chars."""
    print("\n=== Step 1: Download existing chars + queue anims ===", flush=True)
    for cid, uid in EXISTING:
        r = mcp("tools/call", {"name":"get_character","arguments":{"character_id":uid,"include_preview":False}})
        t = txt(r)
        if is_ready(t):
            download_rotations(t, cid, "player")
            # Queue anims if not already complete
            if "animations:" in t and "none" in t.split("animations:")[1][:10]:
                for alabel, atid in HUMANOID_ANIMS:
                    mcp("tools/call", {"name":"animate_character","arguments":{
                        "character_id":uid,"template_animation_id":atid,
                        "directions":["south"],"mode":"template","frame_count":8,
                    }})
                    print(f"    Queued {cid}/{alabel}", flush=True)
        else:
            print(f"  {cid}: still creating, will queue anims when ready", flush=True)
            t = poll_until_ready(uid, cid)
            if t:
                download_rotations(t, cid, "player")
                for alabel, atid in HUMANOID_ANIMS:
                    mcp("tools/call", {"name":"animate_character","arguments":{
                        "character_id":uid,"template_animation_id":atid,
                        "directions":["south"],"mode":"template","frame_count":8,
                    }})

def step1b_poll_anims():
    """Poll until all animations are done for the 10 existing chars."""
    print("\n=== Step 1b: Wait for animations ===", flush=True)
    for cid, uid in EXISTING:
        t = poll_until_ready(uid, cid, timeout_mins=20)
        if t:
            download_rotations(t, cid, "player")
            download_anims(t, cid, "player")

REMAINING_PLAYERS = [
    ("vesperid_male", "Vesperid male, dark brown leathery skin with scale pattern, sharp angular features, small horns from temples, amber slit-pupil eyes, spiky mohawk, fur and leather clothing, feral build, dark fantasy"),
    ("vesperid_female", "Vesperid female, brown leathery skin with scales on shoulders, sharp cheekbones, yellow cat eyes, curved horns swept back, wild dark hair, fur and leather tribal armor, clawed fingers, dark fantasy"),
    ("nullborn_male", "Nullborn male, completely black featureless skin like living void, humanoid silhouette with wrong proportions, no facial features except two white dots for eyes, smooth body, dark grey cloth, void-touched"),
    ("nullborn_female", "Nullborn female, living darkness with faint purple void shimmer, featureless face with two white dot eyes, elegant unsettling proportions, limbs slightly too long, void-dark garments, void-touched"),
    ("revenant_male", "Revenant male, undead corpse-like, gray decaying skin over bones, visible skull on half face, one glowing red eye, tattered military uniform, exposed ribcage with dark energy, undead"),
    ("revenant_female", "Revenant female, undead pale gray-green decaying skin, long stringy hair with patches missing, hollow eye sockets with faint red glow, burial shroud on emaciated frame, visible bone, undead"),
]

MOBS = [
    ("ashveil_grazer", "quadruped", "horse", "Slow fungal herd beast, dusty-gray hide with pale fungal growths, four sturdy legs, broad back with spore nodules, small head, docile, ash wastes"),
    ("lumen_drifter", "quadruped", "cat", "Bioluminescent floating jelly creature, translucent bell-shaped body in pale blue-green, trailing bioluminescent tentacles, ethereal floating, neon bogs"),
    ("rustcarapace_scuttler", "quadruped", "dog", "Armored scrap cleaner, beetle-like insectoid with segmented rust-brown carapace, six jointed legs, mandibles, compact low body, rust canyons"),
    ("silkroot_tapper", "humanoid", None, "Rooted stationary plant creature, woody trunk-like body with bark texture, root tendrils, branch-like arms with leaf clusters, single large eye, ironwood thicket"),
    ("echo_chorister", "quadruped", "bear", "Singing burrow colony creature, bear-sized quadruped with thick shaggy dusty brown fur, large ears, wide mouth with vocal sac, oversized digging paws, corpse fields"),
    ("iron_buck", "quadruped", "horse", "Metallic forest stag, iron-gray metallic hide with chrome-like antlers, branching twisted metal antlers, lean muscular body, ironwood thicket"),
    ("blight_toad", "quadruped", "cat", "Bloated toxic toad, wide squat warty greenish-yellow skin, bulging eyes, wide mouth, powerful back legs, glowing toxin sacs on back, neon bogs"),
    ("dust_devil", "quadruped", "cat", "Dust-colored moth swarm entity, dusty tan wings with vein patterns, feathery antennae, cloud of dust particles swirling, indistinct edges, ash wastes"),
    ("charnel_stalker", "quadruped", "lion", "Pack-hunting predator, lean muscular feline with patchy dark gray-black fur, long barbed tendrils from shoulders, visible ribs, glowing yellow eyes"),
    ("voidspine_leech", "quadruped", "dog", "Parasitic energy drainer, eel-like serpentine body in deep purple-black with void energy pulsing along spine, sucker mouth, floating undulating"),
    ("mycelial_behemoth", "humanoid", None, "Massive spore-hurling hulk, enormous humanoid of intertwined fungal growth, broad shoulders, trunk-like legs, one club fist, one spore-launching arm, mushroom cap head"),
    ("glimmer_swarm", "quadruped", "dog", "Coordinated acidic insects forming mobile swarm, iridescent green-purple carapaces, shifting flow shape, green acid drip, faint bioluminescent glow"),
    ("ferroclaw_reaver", "humanoid", None, "Ferro-organic horror, humanoid shape of fused metal scrap and tissue, one arm a drilling claw, other a magnetic claw, fused metal helmet head with red optic"),
    ("ash_crawler", "quadruped", "dog", "Ash-colored scavenger beetle, segmented chitinous carapace in dusty gray-brown, six armored legs, mandibles, compact oval body, ash wastes"),
    ("rift_elk", "quadruped", "horse", "Large elk with glowing antlers, muscular dark brown fur, branching antlers glowing blue-white rift energy, hooves and eyes glow pale blue"),
    ("fungal_hurler", "humanoid", None, "Spore-throwing brute, massive mushroom cap head with purple gills, body covered in shelf fungi, powerful clawed hands, launches spore pods, toxin marshes"),
    ("glass_serpent", "quadruped", "dog", "Crystalline desert serpent, translucent glass-like segmented plates in pale yellow, internal structure visible, diamond head with crystal eyes, glass dunes"),
    ("bone_crawler", "quadruped", "dog", "Bone-armored carrion centipede, each segment protected by curved white bone plates, dozens of legs, mandibles, bone spikes, corpse fields"),
    ("storm_raptor", "quadruped", "horse", "Lightning-fast highland raptor, bipedal bird-like predator, folded feathered wings, dark blue-gray with white chest, feathered crest, curved beak, lightning arcs"),
    ("void_stalker", "quadruped", "lion", "Fast void hunter phasing between realities, feline shape of purple-black void energy with dark chitin patches, partially transparent, multiple blue eyes, flickering"),
    ("abyssal_weaver", "quadruped", "dog", "Void web-spider, eight legs, dark purple crystal-like chitin body, glowing rift patterns on abdomen, red eyes, energy web strands trailing"),
    ("null_shade", "humanoid", None, "Stealth void wraith shimmering between dimensions, tall gaunt transparent humanoid of dark smoke and void particles, two white pinprick eyes, clawed shadow arms"),
    ("lifecycle_horror", "humanoid", None, "Regenerating life-form that splits, amorphous multi-limbed pale fleshy entity, multiple arms and legs at odd angles, faces on torso, cracks of pink light"),
    ("spore_phantom", "humanoid", None, "Floating spore cloud, vaguely humanoid upper body of pale green-gray spore mass, lower body diffuses into cloud, two yellow glowing points for eyes"),
    ("arc_dynamo", "humanoid", None, "Orbital energy construct, hovering mechanical orb with white metal panels and blue energy cores, four articulated arms with energy emitters, electrical arcs"),
    ("storm_herald", "humanoid", None, "Massive energy boss, enormous humanoid of crackling electrical energy and storm cloud, white energy core head, lightning wing shoulders, crackling energy claws"),
    ("rift_maw", "quadruped", "bear", "Rift core guardian, massive quadruped with body like living rift portal, swirling purple-black energy, circular mouth with concentric teeth rings, four stubby legs"),
]

def create_and_wait(items, team="mob", batch_size=5):
    """Create characters in batches, wait for each batch, queue anims."""
    results = []
    for i in range(0, len(items), batch_size):
        batch = items[i:i+batch_size]
        print(f"\n  Batch {i//batch_size + 1}/{(len(items)-1)//batch_size + 1}", flush=True)
        submissions = []
        for item in batch:
            cid = item[0]
            if team == "player":
                desc = item[1]
                body_type = "humanoid"
                template = None
            else:
                cid, body_type, template, desc = item
                if body_type == "quadruped" and template:
                    template = TEMPLATE_FALLBACK.get(template, template)

            args = {
                "name": cid,
                "description": desc + ", pixel art top-down view, single color black outline, 128x128",
                "body_type": body_type,
                "n_directions": 4,
                "mode": "standard",
                "size": 128,
                "outline": "single color black outline",
                "detail": "medium detail",
                "view": "low top-down",
            }
            if template and body_type == "quadruped":
                args["template"] = template
            print(f"  Creating {cid}...", flush=True)
            r = mcp("tools/call", {"name":"create_character","arguments":args})
            t = txt(r)
            uid = get_id(t)
            print(f"    -> {uid}", flush=True)
            submissions.append((cid, body_type, uid))
            time.sleep(2)
        results.extend(submissions)

        # Wait for batch creations, queue anims
        for cid, body_type, uid in submissions:
            t = poll_until_ready(uid, cid, timeout_mins=15)
            if t:
                download_rotations(t, cid, team)
                anims = HUMANOID_ANIMS if body_type == "humanoid" else QUAD_ANIMS
                for alabel, atid in anims:
                    res = mcp("tools/call", {"name":"animate_character","arguments":{
                        "character_id":uid,"template_animation_id":atid,
                        "directions":["south"],"mode":"template","frame_count":8,
                    }})
                    rt = txt(res)
                    if "error" in rt and "not available" in rt.lower():
                        mcp("tools/call", {"name":"animate_character","arguments":{
                            "character_id":uid,"template_animation_id":"idle",
                            "directions":["south"],"mode":"template","frame_count":8,
                        }})
                        print(f"      {alabel}: fallback to idle", flush=True)

        # Wait for animations
        for cid, body_type, uid in submissions:
            t = poll_until_ready(uid, cid, timeout_mins=20)
            if t:
                download_anims(t, cid, team)

    return results

def main():
    step1_download_existing()
    step1b_poll_anims()

    print("\n=== Step 2: Create remaining 6 players ===", flush=True)
    create_and_wait(REMAINING_PLAYERS, team="player", batch_size=3)

    print("\n=== Step 3: Create 27 mobs ===", flush=True)
    create_and_wait(MOBS, team="mob", batch_size=5)

    print("\n=== Step 4: Create backgrounds ===", flush=True)
    backgrounds = [
        ("bg_ash_wastes", "Wasteland horizon with ash-covered twisted ruins under hazy orange sky, cracked barren earth, distant twisted scrub, dust, oppressive atmosphere, pixel art landscape"),
        ("bg_rust_canyons", "Deep canyon vista with rusted wreckage and crashed vehicles, red-brown canyon walls, twisted metal structures, hazy orange-brown sky with smoke, pixel art landscape"),
        ("bg_neon_bogs", "Polluted wetlands with glowing neon pink and green flora, bioluminescent plants in dark water, leaning power line towers, toxic fog in blue-green, pixel art landscape"),
        ("bg_scorched_plains", "Cracked baked earth to horizon under bright sun, heat haze, charred farm ruins, glass-like melted sand, pale yellow-white sky, pixel art landscape"),
        ("bg_ironwood_thicket", "Dense metallic forest with chrome and iron trees, metallic vines, blue magnetic energy nodes, shadowy undergrowth, twisted metal roots, pixel art landscape"),
        ("bg_glass_dunes", "Shimmering dunes of melted glass fragments in pale yellow, crystal clusters, half-buried ancient structures, prismatic reflections, pale blue sky, pixel art landscape"),
        ("bg_corpse_fields", "Old battlefield with bones and rusted tank hulls, crater-pocked dark brown earth, broken weapons half-buried, barbed wire, dark grey sky, pixel art landscape"),
        ("bg_stormspire_highlands", "High plateau with towers crackling blue-white lightning, dark storm clouds, wind-swept rocky ground, distant spires, dramatic electrical storm, pixel art landscape"),
        ("bg_toxin_marshes", "Swamp of green-yellow chemical sludge, dead twisted trees in toxic pools, gas bubbles, sickly green sky, mutated plants, hostile atmosphere, pixel art landscape"),
        ("bg_dead_city_outskirts", "Ruined megacity edges with collapsed skyscrapers against orange-brown sky, rubble streets, overgrown vegetation, cracked reality with purple energy, pixel art landscape"),
    ]
    for bid, desc in backgrounds:
        r = mcp("tools/call", {"name":"create_ui_asset","arguments":{
            "name":bid,"description":desc,"width":688,"height":288,
        }})
        print(f"  {bid}: {get_id(txt(r))}", flush=True)
        time.sleep(3)

    print("\n=== ALL DONE ===", flush=True)
    print("Run: python build_spriteframes.py", flush=True)

if __name__ == "__main__":
    main()
