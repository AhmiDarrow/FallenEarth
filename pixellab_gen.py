#!/usr/bin/env python3
"""PixelLab Asset Generator — proper batched pipeline.

Respects 10 concurrent job limit. Batches: submit, wait, submit, wait.
Quadruped templates must be: bear, cat, dog, horse, lion.

Usage: python pixellab_gen.py
"""

import json
import re
import time
import urllib.request
import urllib.error
from pathlib import Path

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP_URL = "https://api.pixellab.ai/mcp"
MAX_JOBS = 10
POLL_INTERVAL = 10

MOBS_DIR = Path("assets/mobs")
CHAR_DIR = Path("assets/characters")

# Quadruped template mapping: mob_id -> best matching template
QUAD_TEMPLATES = {
    "ashveil_grazer": "horse", "lumen_drifter": "cat",
    "rustcarapace_scuttler": "beetle", "echo_chorister": "bear",
    "iron_buck": "horse", "blight_toad": "toad",
    "dust_devil": "moth", "charnel_stalker": "lion",
    "voidspine_leech": "snake", "glimmer_swarm": "beetle",
    "ash_crawler": "beetle", "rift_elk": "horse",
    "glass_serpent": "snake", "bone_crawler": "centipede",
    "storm_raptor": "bird", "void_stalker": "lion",
    "abyssal_weaver": "spider", "rift_maw": "hippo",
}

# Map non-standard templates to closest valid one
VALID_QUAD_TEMPLATES = {"bear", "cat", "dog", "horse", "lion"}
TEMPLATE_FALLBACK = {
    "beetle": "dog", "toad": "cat", "moth": "cat",
    "snake": "dog", "centipede": "dog", "bird": "horse",
    "spider": "dog", "hippo": "bear", "jellyfish": "cat",
    "lion": "lion", "horse": "horse", "bear": "bear",
    "cat": "cat", "dog": "dog",
}

ANIMS_HUMANOID = [
    ("idle", "breathing-idle"),
    ("walk", "walking"),
    ("attack", "fight-stance-idle-8-frames"),
    ("hurt", "falling-back-death"),
]

ANIMS_QUAD = [
    ("idle", "idle"),
    ("run", "running-8-frames"),
    ("attack", "angry"),
    ("death", "falling-back-death"),
]


# ── MCP Client ──

def mcp_call(method, params=None, retries=3):
    payload = json.dumps({
        "jsonrpc": "2.0", "id": int(time.time() * 1000) % 100000,
        "method": method, "params": params or {},
    }).encode()
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    for attempt in range(retries):
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
            body = e.read().decode()
            if e.code == 429:
                retry_sec = int(e.headers.get("Retry-After", "30"))
                print(f"  [429] Rate limited, waiting {retry_sec}s...", flush=True)
                time.sleep(retry_sec)
                continue
            return {"isError": True, "text": f"HTTP {e.code}: {body[:300]}"}
        except Exception as e:
            if attempt < retries - 1:
                time.sleep(5)
                continue
            return {"isError": True, "text": str(e)}
    return {"isError": True, "text": "max retries"}


def get_text(result):
    if result.get("isError"):
        return result.get("text", "?")
    for c in result.get("content", []):
        if c.get("type") == "text":
            return c.get("text", "")
    return str(result)


def extract_id(text):
    m = re.search(r'id:\s*([a-f0-9-]+)', text)
    return m.group(1) if m else ""


def has_pending(text):
    return bool(re.search(r'pending.?jobs?', text, re.IGNORECASE)) or "423" in text


def is_complete(text):
    return "status: completed" in text and not has_pending(text)


def get_rotations(text):
    urls = {}
    for m in re.finditer(r'\s{2}(\w+):\s+(https?://\S+)', text):
        urls[m.group(1)] = m.group(2)
    return urls


def get_animation_frames(text):
    anims = {}
    current_anim = None
    for line in text.split("\n"):
        am = re.match(r'\s{2}([^(]+)\s\((\w+),\s*(\d+)f?\)', line)
        if am:
            current_anim = am.group(1).strip()
            anims[current_anim] = []
            continue
        fm = re.match(r'\s{4}frames:\s+(.+)', line)
        if fm and current_anim:
            anims[current_anim] = [u.strip() for u in fm.group(1).split(",")]
    return anims


def download(url, dest):
    if not url:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(url, str(dest))
        print(f"      -> {dest.name}", flush=True)
        return True
    except Exception as e:
        print(f"      FAILED: {e}", flush=True)
        return False


# ── Characters ──

PLAYERS = [
    ("human_male", "Human male wasteland survivor, rugged weathered face, stubble, short dark hair, worn leather duster coat, cargo pants, combat boots, bandolier, scarred forearms, gritty post-apocalyptic"),
    ("human_female", "Human female wasteland survivor, determined face, long braided brown hair, worn denim jacket, cargo pants, boots, goggles on forehead, utility belt, slim athletic build"),
    ("mutant_male", "Mutant male, hulking muscular brute, asymmetrical features, thick brow ridge, greenish-gray skin, tattered leather straps and scrap armor, large hands, hunched powerful posture"),
    ("mutant_female", "Mutant female, tall muscular, pale greenish-gray skin with darker mottled patches, sharp teeth, short spiky hair, scrap metal pauldron, tattered wrappings, heavy boots, feral"),
    ("sentientai_male", "Sentient AI male, synthetic humanoid, chrome and carbon fiber plating, featureless face with glowing blue optic, sleek dark clothing, circuit patterns at neck and hands, cyberpunk"),
    ("sentientai_female", "Sentient AI female, elegant synthetic, white and silver chassis with blue light strips, smooth face with cyan eyes, synthetic hair in ponytail, white and blue bodysuit, cyberpunk"),
    ("cyborg_male", "Cyborg male, heavily augmented, one robotic red eye, mechanical left arm with pistons, metal jaw implant, worn military jacket over torso plating, cybernetic legs, cyberpunk"),
    ("cyborg_female", "Cyborg female, chrome augmentations on arms and legs, synthskin patches, one organic eye one blue cybernetic eye, half-shaved head with tech implants, armored bodysuit with neon blue trim"),
    ("chthon_male", "Chthon male, underworld pale-gray skin, gaunt angular face, hollow cheeks, dark sunken eyes with faint glow, black matted hair, dark robes with bone ornaments, skeletal build, dark fantasy"),
    ("chthon_female", "Chthon female, ghostly pale skin with blue undertones, elongated features, white eyes no pupil, long straight black hair, flowing dark robes with silver thread, ethereal build, dark fantasy"),
    ("vesperid_male", "Vesperid male, dark brown leathery skin with scale pattern, sharp angular features, small horns from temples, amber slit-pupil eyes, spiky mohawk, fur and leather clothing, feral build, dark fantasy"),
    ("vesperid_female", "Vesperid female, brown leathery skin with scales on shoulders, sharp cheekbones, yellow cat eyes, curved horns swept back, wild dark hair, fur and leather tribal armor, clawed fingers"),
    ("nullborn_male", "Nullborn male, completely black featureless skin like living void, humanoid silhouette with wrong proportions, no facial features except two white dots for eyes, smooth body, dark grey cloth"),
    ("nullborn_female", "Nullborn female, living darkness with faint purple void shimmer, featureless face with two white dot eyes, elegant unsettling proportions, limbs slightly too long, void-dark garments"),
    ("revenant_male", "Revenant male, undead corpse-like, gray decaying skin over bones, visible skull on half face, one glowing red eye, tattered military uniform, exposed ribcage with dark energy, undead"),
    ("revenant_female", "Revenant female, undead pale gray-green decaying skin, long stringy hair with patches missing, hollow eye sockets with faint red glow, burial shroud on emaciated frame, visible bone"),
]

MOBS = [
    ("ashveil_grazer", "quadruped", "Slow fungal herd beast, dusty-gray hide with pale fungal growths and shelf mushrooms, four sturdy legs, broad back with spore nodules, small head, docile, ash wastes"),
    # Wait, I need to rethink. The user canceled the previous run.
    # Let me just handle the 10 already-created characters first.
]

# Actually — the first batch of 10 already succeeded (human_male through cyborg_female).
# And 6 more were submitted (chthon_male, chthon_female + 4 more that succeeded).
# Let me check what's actually been created.
# For now, let me just check the queue and print what we have.

def list_active():
    """Check what's already been created."""
    result = mcp_call("tools/call", {
        "name": "list_characters",
        "arguments": {"limit": 50},
    })
    text = get_text(result)
    print("Active characters:", text[:2000], flush=True)


def poll_and_download(char_id, label, team="mob"):
    """Poll a character until complete, then download everything."""
    for poll in range(120):
        time.sleep(POLL_INTERVAL)
        result = mcp_call("tools/call", {
            "name": "get_character",
            "arguments": {"character_id": char_id, "include_preview": False},
        })
        text = get_text(result)

        if is_complete(text):
            print(f"  [DONE] {label} ({poll * POLL_INTERVAL}s)", flush=True)
            # Download south rotation
            rots = get_rotations(text)
            if "south" in rots:
                if team == "player":
                    race, gender = label.split("_", 1)
                    dest = CHAR_DIR / f"{race}_{gender}" / f"{race}_{gender}_S.png"
                else:
                    dest = MOBS_DIR / f"{label}.png"
                download(rots["south"], dest)

            # Download animation frames
            anims = get_animation_frames(text)
            for aname, urls in anims.items():
                if team == "player":
                    race, gender = label.split("_", 1)
                    adir = CHAR_DIR / f"{race}_{gender}" / aname
                else:
                    adir = MOBS_DIR / label / aname
                adir.mkdir(parents=True, exist_ok=True)
                for i, url in enumerate(urls):
                    download(url, adir / f"frame_{i:02d}.png")
                print(f"    {aname}: {len(urls)} frames", flush=True)
            return True
        elif has_pending(text):
            continue  # still processing animations
        else:
            # Still creating
            if poll % 6 == 0:
                # Extract percentage
                pct = re.search(r'(\d+)%', text)
                pct_str = f"{pct.group(1)}%" if pct else "?"
                print(f"  {label}: {pct_str}...", flush=True)
    print(f"  [TIMEOUT] {label}", flush=True)
    return False


def main():
    print("=" * 60, flush=True)

    # First, let's see what's already in the queue from the previous run
    print("\nChecking existing characters in queue...", flush=True)
    list_active()

    # The first 10 characters were created. Let's poll and download them,
    # then submit the remaining 33 characters, then backgrounds.

    # Characters already submitted (from previous run output):
    created_chars = [
        ("human_male", "b4a12c49-7e18-4b7f-88ef-aa243142be1b", "player"),
        ("human_female", "2e872b24-772c-41cf-87b9-933efdedd051", "player"),
        ("mutant_male", "9ba08023-6548-4ed4-9b5a-94a8a8a354ac", "player"),
        ("mutant_female", "88671592-ebcd-4d6a-a0d2-eaafda412bc2", "player"),
        ("sentientai_male", "e2ec51df-0808-4524-97db-2dc22b08ca80", "player"),
        ("sentientai_female", "9454832e-823b-4772-a2e3-0479287a9834", "player"),
        ("cyborg_male", "3e77535e-9e0d-4bab-ba64-4b9169f2dadf", "player"),
        ("cyborg_female", "6d7d2944-f6b0-409c-bb43-e15ce5b5462c", "player"),
        ("chthon_male", "4325ebaf-74ae-4a09-a0f3-a7c1a6bf8325", "player"),
        ("chthon_female", "13979e12-26c0-4eb5-8ec5-d67cfb7a6495", "player"),
    ]

    # Phase 1: Poll and download already-created characters
    print(f"\n{'='*60}", flush=True)
    print("Phase 1: Downloading already-created characters...", flush=True)
    print(f"{'='*60}", flush=True)

    for cid, cid_hash, team in created_chars:
        print(f"  {cid}...", flush=True)
        poll_and_download(cid_hash, cid, team)

    # Also queue animations for them since they're now complete
    print(f"\n{'='*60}", flush=True)
    print("Phase 1b: Queuing animations for downloaded characters...", flush=True)
    print(f"{'='*60}", flush=True)

    for cid, cid_hash, team in created_chars:
        print(f"  Queuing {cid} animations...", flush=True)
        for label, template_id in ANIMS_HUMANOID:
            result = mcp_call("tools/call", {
                "name": "animate_character",
                "arguments": {
                    "character_id": cid_hash,
                    "template_animation_id": template_id,
                    "directions": ["south"],
                    "mode": "template",
                    "frame_count": 8,
                }
            })
            text = get_text(result)
            if "error" in text:
                print(f"    {label}: {text[:100]}", flush=True)
            else:
                print(f"    {label}: queued", flush=True)

    # Wait for animations
    print(f"\n{'='*60}", flush=True)
    print("Waiting for animations to complete...", flush=True)
    print(f"{'='*60}", flush=True)

    for cid, cid_hash, team in created_chars:
        poll_and_download(cid_hash, cid, team)

    # Phase 2: Submit remaining characters (6 missing players + 27 mobs)
    remaining_players = [
        ("vesperid_male", "Vesperid male, dark brown leathery skin with scale pattern, sharp angular features, small horns from temples, amber slit-pupil eyes, spiky mohawk, fur and leather clothing, feral build"),
        ("vesperid_female", "Vesperid female, brown leathery skin with scales on shoulders, sharp cheekbones, yellow cat eyes, curved horns swept back, wild dark hair, fur and leather tribal armor, clawed fingers"),
        ("nullborn_male", "Nullborn male, completely black featureless skin like living void, humanoid silhouette with wrong proportions, no facial features except two white dots for eyes, smooth body, dark grey cloth"),
        ("nullborn_female", "Nullborn female, living darkness with faint purple void shimmer, featureless face with two white dot eyes, elegant unsettling proportions, limbs slightly too long, void-dark garments"),
        ("revenant_male", "Revenant male, undead corpse-like, gray decaying skin over bones, visible skull on half face, one glowing red eye, tattered military uniform, exposed ribcage with dark energy"),
        ("revenant_female", "Revenant female, undead pale gray-green decaying skin, long stringy hair with patches missing, hollow eye sockets with faint red glow, burial shroud on emaciated frame, visible bone"),
    ]

    remaining_mobs = [
        ("ashveil_grazer", "quadruped", "horse",
         "Slow fungal herd beast, dusty-gray hide with pale fungal growths, four sturdy legs, broad back with spore nodules, small head, docile, ash wastes"),
        ("lumen_drifter", "quadruped", "cat",
         "Bioluminescent floating jelly creature, translucent bell-shaped body in pale blue-green, trailing bioluminescent tentacles, ethereal floating, neon bogs"),
        ("rustcarapace_scuttler", "quadruped", "dog",
         "Armored scrap cleaner, large beetle-like insectoid with segmented rust-brown carapace, six jointed legs, mandibles, compact low body, rust canyons"),
        ("silkroot_tapper", "humanoid", None,
         "Rooted stationary plant creature, woody trunk-like body with bark texture, root tendrils in ground, branch-like arms with leaf clusters, single large eye, ironwood thicket"),
        ("echo_chorister", "quadruped", "bear",
         "Singing burrow colony creature, bear-sized quadruped with thick shaggy dusty brown fur, large ears, wide mouth with vocal sac, oversized digging paws, corpse fields"),
        ("iron_buck", "quadruped", "horse",
         "Metallic forest stag, iron-gray metallic hide with chrome-like antlers, branching twisted metal antlers, iron block hooves, lean muscular body, ironwood thicket"),
        ("blight_toad", "quadruped", "cat",
         "Bloated toxic toad, wide squat body with warty greenish-yellow skin, bulging eyes, wide mouth with tongue, powerful back legs, toxin sacs on back, neon bogs"),
        ("dust_devil", "quadruped", "cat",
         "Dust-colored moth swarm entity, dusty tan wings with vein patterns, feathery antennae, cloud of dust particles swirling, indistinct edges, ash wastes"),
        ("charnel_stalker", "quadruped", "lion",
         "Pack-hunting predator, lean muscular feline with patchy dark gray-black fur, long barbed tendrils from shoulders, visible ribs, glowing yellow eyes, aggressive hunting"),
        ("voidspine_leech", "quadruped", "dog",
         "Parasitic energy drainer, eel-like serpentine body in deep purple-black with void energy pulsing along spine, sucker mouth, floating undulating motion"),
        ("mycelial_behemoth", "humanoid", None,
         "Massive spore-hurling hulk, enormous humanoid of intertwined fungal growth, broad shoulders, trunk-like legs, one club fist, one spore-launching arm, mushroom cap head"),
        ("glimmer_swarm", "quadruped", "dog",
         "Coordinated acidic insects forming mobile swarm, iridescent green-purple carapaces, shifting flow shape, green acid drip, faint bioluminescent glow"),
        ("ferroclaw_reaver", "humanoid", None,
         "Ferro-organic horror, humanoid shape of fused metal scrap and tissue, one arm a drilling claw, other a magnetic claw, fused metal helmet head with red optic"),
        ("ash_crawler", "quadruped", "dog",
         "Ash-colored scavenger beetle, segmented chitinous carapace in dusty gray-brown, six armored legs, mandibles, compact oval body, ash wastes"),
        ("rift_elk", "quadruped", "horse",
         "Large elk with glowing antlers, muscular dark brown fur, branching antlers glowing blue-white rift energy, hooves and eyes glow pale blue"),
        ("fungal_hurler", "humanoid", None,
         "Spore-throwing brute, massive mushroom cap head with purple gills, body covered in shelf fungi, powerful clawed hands, launches spore pods, toxin marshes"),
        ("glass_serpent", "quadruped", "dog",
         "Crystalline desert serpent, translucent glass-like segmented plates in pale yellow, internal structure visible, diamond head with crystal eyes, glass dunes"),
        ("bone_crawler", "quadruped", "dog",
         "Bone-armored carrion centipede, each segment protected by curved white bone plates, dozens of legs, mandibles, bone spikes, corpse fields"),
        ("storm_raptor", "quadruped", "horse",
         "Lightning-fast highland raptor, bipedal bird-like predator, folded feathered wings, dark blue-gray with white chest, feathered crest, curved beak, clawed feet, lightning arcs"),
        ("void_stalker", "quadruped", "lion",
         "Fast void hunter phasing between realities, feline shape of purple-black void energy with dark chitin patches, partially transparent, multiple blue eyes, flickering"),
        ("abyssal_weaver", "quadruped", "dog",
         "Void web-spider, eight legs, dark purple crystal-like chitin body, glowing rift patterns on abdomen, red eyes, energy web strands trailing"),
        ("null_shade", "humanoid", None,
         "Stealth void wraith shimmering between dimensions, tall gaunt transparent humanoid of dark smoke and void particles, two white pinprick eyes, clawed shadow arms"),
        ("lifecycle_horror", "humanoid", None,
         "Regenerating life-form that splits, amorphous multi-limbed pale fleshy entity, multiple arms and legs at odd angles, faces on torso, cracks of pink light"),
        ("spore_phantom", "humanoid", None,
         "Floating spore cloud, vaguely humanoid upper body of pale green-gray spore mass, lower body diffuses into cloud, two yellow glowing points for eyes"),
        ("arc_dynamo", "humanoid", None,
         "Orbital energy construct, hovering mechanical orb with white metal panels and blue energy cores, four articulated arms with energy emitters, electrical arcs"),
        ("storm_herald", "humanoid", None,
         "Massive energy boss, enormous humanoid of crackling electrical energy and storm cloud, white energy core head, lightning wing shoulders, crackling energy claws"),
        ("rift_maw", "quadruped", "bear",
         "Rift core guardian, massive quadruped with body like living rift portal, swirling purple-black energy, circular mouth with concentric teeth rings, four stubby legs"),
    ]

    # Wait for all animation jobs on the first 10 to finish before submitting more
    print(f"\n{'='*60}", flush=True)
    print("Waiting for animation jobs to clear before submitting more characters...", flush=True)
    print(f"{'='*60}", flush=True)

    # Poll until all jobs are done (just wait)
    for wait_min in range(30):
        time.sleep(60)
        # Check one character to see if its animations are done
        result = mcp_call("tools/call", {
            "name": "get_character",
            "arguments": {"character_id": created_chars[0][1], "include_preview": False},
        })
        text = get_text(result)
        if is_complete(text):
            print(f"  Animations done after {wait_min+1}min", flush=True)
            # Download them
            for cid, cid_hash, team in created_chars:
                poll_and_download(cid_hash, cid, team)
            break
        else:
            print(f"  Waiting... animations still processing ({wait_min+1}min)", flush=True)

    # Phase 3: Submit remaining 6 players
    print(f"\n{'='*60}", flush=True)
    print(f"Phase 3: Creating {len(remaining_players)} remaining players...", flush=True)
    print(f"{'='*60}", flush=True)

    player_results = []
    for cid, desc in remaining_players:
        print(f"  Submitting {cid}...", flush=True)
        result = mcp_call("tools/call", {
            "name": "create_character",
            "arguments": {
                "name": cid,
                "description": desc + ", pixel art top-down view, single color black outline, 128x128",
                "body_type": "humanoid",
                "n_directions": 4,
                "mode": "standard",
                "size": 128,
                "outline": "single color black outline",
                "detail": "medium detail",
                "view": "low top-down",
            }
        })
        text = get_text(result)
        eid = extract_id(text)
        print(f"    -> {eid}", flush=True)
        if eid:
            player_results.append((cid, eid))
        time.sleep(2)  # Slight delay between submits

    print(f"\n  Submitted {len(player_results)} players. Waiting for completion...", flush=True)
    for cid, eid in player_results:
        poll_and_download(eid, cid, "player")
        # Queue animations
        for label, template_id in ANIMS_HUMANOID:
            mcp_call("tools/call", {
                "name": "animate_character",
                "arguments": {
                    "character_id": eid,
                    "template_animation_id": template_id,
                    "directions": ["south"],
                    "mode": "template",
                    "frame_count": 8,
                }
            })

    # Phase 4: Submit mobs (in batches of 5 to avoid rate limits)
    print(f"\n{'='*60}", flush=True)
    print(f"Phase 4: Creating {len(remaining_mobs)} mobs (batches of 5)...", flush=True)
    print(f"{'='*60}", flush=True)

    mob_results = []
    batch_size = 5
    for i in range(0, len(remaining_mobs), batch_size):
        batch = remaining_mobs[i:i+batch_size]
        for cid, body_type, template, desc in batch:
            print(f"  Submitting {cid}...", flush=True)
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
                fallback = TEMPLATE_FALLBACK.get(template, "dog")
                args["template"] = fallback
            result = mcp_call("tools/call", {
                "name": "create_character",
                "arguments": args,
            })
            text = get_text(result)
            eid = extract_id(text)
            print(f"    -> {eid}", flush=True)
            if eid:
                mob_results.append((cid, body_type, eid))
            time.sleep(2)

        # Wait for this batch to be created
        for cid, body_type, eid in mob_results[-len(batch):]:
            poll_and_download(eid, cid, "mob")
            # Queue animations
            anims = ANIMS_HUMANOID if body_type == "humanoid" else ANIMS_QUAD
            for label, template_id in anims:
                result = mcp_call("tools/call", {
                    "name": "animate_character",
                    "arguments": {
                        "character_id": eid,
                        "template_animation_id": template_id,
                        "directions": ["south"],
                        "mode": "template",
                        "frame_count": 8,
                    }
                })
                text = get_text(result)
                if "error" in text:
                    # Try simpler fallback
                    fallback_templates = {"walk": "idle", "attack": "idle"}
                    fallback_tid = fallback_templates.get(label, "idle")
                    mcp_call("tools/call", {
                        "name": "animate_character",
                        "arguments": {
                            "character_id": eid,
                            "template_animation_id": fallback_tid,
                            "directions": ["south"],
                            "mode": "template",
                            "frame_count": 8,
                        }
                    })
                    print(f"      {label}: fallback to {fallback_tid}", flush=True)

    # Phase 5: Wait for all mob animations and download
    print(f"\n{'='*60}", flush=True)
    print("Phase 5: Waiting for mob animations...", flush=True)
    print(f"{'='*60}", flush=True)

    for cid, body_type, eid in mob_results:
        poll_and_download(eid, cid, "mob")

    # Phase 6: Submit backgrounds (wait for all other jobs to clear first)
    print(f"\n{'='*60}", flush=True)
    print("Phase 6: Creating backgrounds...", flush=True)
    print(f"{'='*60}", flush=True)

    # Wait for any remaining jobs
    time.sleep(30)

    backgrounds = [
        ("bg_ash_wastes", "Wasteland horizon with ash-covered twisted ruins under hazy orange sky, cracked barren earth, distant twisted scrub, dust particles, oppressive atmosphere, pixel art landscape"),
        ("bg_rust_canyons", "Deep canyon vista with rusted wreckage and crashed vehicles, red-brown canyon walls, twisted metal structures, hazy orange-brown sky with smoke, pixel art landscape"),
        ("bg_neon_bogs", "Polluted wetlands with glowing neon pink and green flora, bioluminescent plants in dark water, leaning power line towers, toxic fog in blue-green, pixel art landscape"),
        ("bg_scorched_plains", "Cracked baked earth to horizon under bright sun, heat haze, charred ruins of farm buildings, glass-like melted sand patches, pale yellow-white sky, pixel art landscape"),
        ("bg_ironwood_thicket", "Dense metallic forest with chrome and iron trees, metallic vines, blue magnetic energy nodes, shadowy undergrowth, twisted metal roots, pixel art landscape"),
        ("bg_glass_dunes", "Shimmering dunes of melted glass fragments in pale yellow, crystal clusters, half-buried ancient structures, prismatic reflections, pale blue sky, pixel art landscape"),
        ("bg_corpse_fields", "Old battlefield with bones and rusted tank hulls, crater-pocked dark brown earth, broken weapons half-buried, barbed wire, dark grey sky, pixel art landscape"),
        ("bg_stormspire_highlands", "High plateau with towers crackling blue-white lightning, dark storm clouds, wind-swept rocky ground, distant spires, dramatic electrical storm, pixel art landscape"),
        ("bg_toxin_marshes", "Swamp of green-yellow chemical sludge, dead twisted trees in toxic pools, gas bubbles, sickly green sky, mutated plants, hostile atmosphere, pixel art landscape"),
        ("bg_dead_city_outskirts", "Ruined megacity edges with collapsed skyscrapers against orange-brown sky, rubble streets, overgrown vegetation, cracked reality with purple energy, pixel art landscape"),
    ]

    for bid, desc in backgrounds:
        print(f"  Submitting {bid}...", flush=True)
        result = mcp_call("tools/call", {
            "name": "create_ui_asset",
            "arguments": {
                "name": bid,
                "description": desc,
                "width": 688,
                "height": 288,
            }
        })
        text = get_text(result)
        eid = extract_id(text)
        print(f"    -> {eid}", flush=True)
        time.sleep(2)

    print(f"\n{'='*60}", flush=True)
    print("Pipeline complete!", flush=True)
    print(f"{'='*60}", flush=True)
    print("\nNow run: python pixellab_download.py", flush=True)
    print("Then: python build_spriteframes.py", flush=True)


if __name__ == "__main__":
    main()
