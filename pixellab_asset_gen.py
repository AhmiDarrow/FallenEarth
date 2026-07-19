#!/usr/bin/env python3
"""PixelLab Asset Generator — queued batch pipeline via MCP SSE protocol.

Concurrency limit: 10 simultaneous jobs (PixelLab API restriction).
Uses direct SSE/JSON-RPC against https://api.pixellab.ai/mcp.

Workflow:
  1. Submit create_character for all 43 entities (16 players + 27 mobs).
  2. On each character completion, queue animate_character (idle, walk, attack, death/hurt).
  3. Submit create_ui_asset for 10 biome backgrounds.
  4. Poll results, download PNGs, save to correct asset paths.
"""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP_URL = "https://api.pixellab.ai/mcp"
CONCURRENCY = 10

ASSETS_DIR = Path("assets")
MOBS_DIR = ASSETS_DIR / "mobs"
CHAR_DIR = ASSETS_DIR / "characters"
BACKGROUNDS_DIR = ASSETS_DIR / "backgrounds"


# ── MCP SSE Client (synchronous, single-threaded but non-blocking via polling) ──

_next_id = 1
def next_id():
    global _next_id
    _next_id += 1
    return _next_id - 1


def mcp_call(method: str, params: dict = None) -> dict:
    """Send a JSON-RPC request to the MCP SSE endpoint. Returns the result dict."""
    rid = next_id()
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": rid,
        "method": method,
        "params": params or {}
    }).encode()
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json, text/event-stream",
    }
    req = urllib.request.Request(MCP_URL, data=payload, headers=headers, method="POST")
    try:
        resp = urllib.request.urlopen(req)
        body = resp.read().decode()
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        if e.code == 429:
            retry = int(e.headers.get("Retry-After", "5"))
            print(f"  [429] Rate limited, waiting {retry}s...")
            time.sleep(retry)
            return mcp_call(method, params)
        print(f"  [HTTP {e.code}] {method}: {body[:200]}")
        return {"error": str(e.code), "detail": body[:200]}
    except Exception as e:
        print(f"  [ERROR] {method}: {e}")
        return {"error": str(e)}

    # Parse SSE events
    # MCP responds with SSE: "event: message\ndata: {...}\n\n"
    for event_block in body.strip().split("\n\n"):
        event_type = ""
        data_str = ""
        for line in event_block.split("\n"):
            if line.startswith("event: "):
                event_type = line[7:].strip()
            elif line.startswith("data: "):
                data_str = line[6:].strip()
        if event_type == "message" and data_str:
            try:
                msg = json.loads(data_str)
                if msg.get("id") == rid:
                    if "result" in msg:
                        return msg["result"]
                    elif "error" in msg:
                        print(f"  [RPC ERROR] {method}: {msg['error']}")
                        return msg["error"]
            except json.JSONDecodeError:
                pass

    print(f"  [NO RESPONSE] {method}")
    return {"status": "no_response"}


# ── MCP Tool Wrappers ──

def create_character(name: str, body_type: str, prompt: str, n_directions: int = 1,
                     mode: str = "standard", size: int = 128, template: str = None) -> dict:
    params = {
        "name": name,
        "body_type": body_type,
        "n_directions": n_directions,
        "mode": mode,
        "size": size,
        "prompt": prompt,
    }
    if template:
        params["template"] = template
    return mcp_call("tools/call", {
        "name": "create_character",
        "arguments": params,
    })


def get_character(character_id: str) -> dict:
    return mcp_call("tools/call", {
        "name": "get_character",
        "arguments": {"character_id": character_id},
    })


def animate_character(character_id: str, template_animation_id: str,
                      directions: list = None, mode: str = "template",
                      frame_count: int = 8) -> dict:
    params = {
        "character_id": character_id,
        "template_animation_id": template_animation_id,
        "mode": mode,
        "frame_count": frame_count,
    }
    if directions:
        params["directions"] = directions
    return mcp_call("tools/call", {
        "name": "animate_character",
        "arguments": params,
    })


def create_ui_asset(name: str, width: int, height: int, prompt: str) -> dict:
    return mcp_call("tools/call", {
        "name": "create_ui_asset",
        "arguments": {
            "name": name,
            "width": width,
            "height": height,
            "prompt": prompt,
        },
    })


def get_object(object_id: str) -> dict:
    return mcp_call("tools/call", {
        "name": "get_object",
        "arguments": {"object_id": object_id},
    })


def extract_result_data(result: dict) -> dict:
    """Extract the actual content from an MCP tool result."""
    if "content" in result and isinstance(result["content"], list):
        for item in result["content"]:
            if isinstance(item, dict) and "text" in item:
                try:
                    return json.loads(item["text"])
                except (json.JSONDecodeError, TypeError):
                    return {"raw": item["text"]}
    return result


# ── Definitions ──

CHARACTERS = [
    {"id": "human_male", "label": "Human Male", "body_type": "humanoid",
     "prompt": "Human male wasteland survivor, rugged weathered face, stubble, short dark hair, worn leather duster coat over dirty t-shirt, cargo pants, combat boots, bandolier across chest, scarred forearms, gritty post-apocalyptic style, medium build, pixel art top-down view, single color black outline, 128x128"},
    {"id": "human_female", "label": "Human Female", "body_type": "humanoid",
     "prompt": "Human female wasteland survivor, determined face, long braided brown hair, worn denim jacket over tank top, cargo pants, boots, goggles pushed up on forehead, utility belt with pouches, slim athletic build, gritty post-apocalyptic pixel art top-down view, single color black outline, 128x128"},
    {"id": "mutant_male", "label": "Mutant Male", "body_type": "humanoid",
     "prompt": "Mutant male, hulking muscular brute, asymmetrical features, one eye larger than other, thick brow ridge, patchy hair, scarred greenish-gray skin tone, tattered leather straps and scrap armor across chest, large hands, hunched powerful posture, post-apocalyptic pixel art top-down view, single color black outline, 128x128"},
    {"id": "mutant_female", "label": "Mutant Female", "body_type": "humanoid",
     "prompt": "Mutant female, tall muscular build, pale greenish-gray skin with darker mottled patches, sharp protruding teeth, short spiky hair, scrap metal pauldron on one shoulder, tattered cloth wrappings, heavy boots, feral intense expression, post-apocalyptic pixel art top-down view, single color black outline, 128x128"},
    {"id": "sentientai_male", "label": "SentientAI Male", "body_type": "humanoid",
     "prompt": "Sentient AI male, synthetic humanoid form, chrome and dark carbon fiber plating at joints, smooth featureless face with glowing blue single optic line, sleek dark synthetic clothing, precise deliberate posture, glowing circuit patterns at neck and hands, cyberpunk pixel art top-down view, single color black outline, 128x128"},
    {"id": "sentientai_female", "label": "SentientAI Female", "body_type": "humanoid",
     "prompt": "Sentient AI female, elegant synthetic humanoid form, white and silver chassis with blue light strips along limbs, smooth face with two cyan glowing eyes, long synthetic hair in sleek ponytail, form-fitting white and blue bodysuit, graceful precise movements, cyberpunk pixel art top-down view, single color black outline, 128x128"},
    {"id": "cyborg_male", "label": "Cyborg Male", "body_type": "humanoid",
     "prompt": "Cyborg male, heavily augmented human, one robotic eye with red glow, mechanical left arm with visible pistons and plating, right side of face has metal jaw implant, short cropped hair, worn military jacket over reinforced torso plating, utility gear, cybernetic legs with hydraulics, cyberpunk pixel art top-down view, single color black outline, 128x128"},
    {"id": "cyborg_female", "label": "Cyborg Female", "body_type": "humanoid",
     "prompt": "Cyborg female, sleek chrome augmentations on arms and legs, synthskin patches at joints, one organic eye and one glowing blue cybernetic eye, half-shaved head with tech implants at temple, form-fitting armored bodysuit with neon blue trim lines, agile poised stance, cyberpunk pixel art top-down view, single color black outline, 128x128"},
    {"id": "chthon_male", "label": "Chthon Male", "body_type": "humanoid",
     "prompt": "Chthon male, underworld pale-gray skin, gaunt angular face with hollow cheeks, dark sunken eyes with faint glow, black matted hair, tattered dark cloth robes with bone ornaments, ritual scar patterns on exposed arms, thin skeletal build, eerie ominous posture, dark fantasy pixel art top-down view, single color black outline, 128x128"},
    {"id": "chthon_female", "label": "Chthon Female", "body_type": "humanoid",
     "prompt": "Chthon female, ghostly pale skin with blue undertones, elongated features, completely white eyes with no visible pupil, long straight black hair, flowing dark robes with silver thread patterns, bone jewelry at neck and wrists, slender ethereal build, floating graceful movement, dark fantasy pixel art top-down view, single color black outline, 128x128"},
    {"id": "vesperid_male", "label": "Vesperid Male", "body_type": "humanoid",
     "prompt": "Vesperid male, dark brown leathery skin with subtle scale pattern, sharp angular features, two small horns curving back from temples, amber slit-pupil eyes, spiky hair in mohawk, tattered fur and leather clothing with bone spikes, muscular feral build, brutal tribal aesthetic, dark fantasy pixel art top-down view, single color black outline, 128x128"},
    {"id": "vesperid_female", "label": "Vesperid Female", "body_type": "humanoid",
     "prompt": "Vesperid female, brown leathery skin with scale pattern on shoulders and arms, sharp cheekbones, yellow cat-like eyes with vertical pupils, curved horns swept back from temples, wild mane of dark hair, fur and leather tribal armor, clawed fingers, athletic predatory stance, dark fantasy pixel art top-down view, single color black outline, 128x128"},
    {"id": "nullborn_male", "label": "Nullborn Male", "body_type": "humanoid",
     "prompt": "Nullborn male, completely black featureless skin like living void, humanoid silhouette but subtly wrong proportions, no visible facial features except two pinprick white dots for eyes, clean smooth body with no visible texture, wearing simple dark grey wrapped cloth, unnerving still posture, void-touched pixel art top-down view, single color white outline, 128x128"},
    {"id": "nullborn_female", "label": "Nullborn Female", "body_type": "humanoid",
     "prompt": "Nullborn female, body made of living darkness with faint purple void shimmer beneath surface, featureless face with two small white dots for eyes, elegant but unsettling proportions, limbs slightly too long, smooth seamless form wearing void-dark wrapped garments, floating aura of shadow particles, void-touched pixel art top-down view, single color white outline, 128x128"},
    {"id": "revenant_male", "label": "Revenant Male", "body_type": "humanoid",
     "prompt": "Revenant male, undead corpse-like appearance, gray decaying skin stretched over bones, visible skull features on half the face, one eye a glowing red pinpoint, tattered remains of military uniform fused to body, exposed ribcage with dark energy pulsing, ragged decaying posture, undead pixel art top-down view, single color black outline, 128x128"},
    {"id": "revenant_female", "label": "Revenant Female", "body_type": "humanoid",
     "prompt": "Revenant female, undead with pale gray-green decaying skin, long stringy hair with patches missing, hollow eye sockets with faint red glow deep inside, tattered burial shroud and rotted dress hanging from emaciated frame, visible bone at jaw and hands, floating decaying wisps around form, undead pixel art top-down view, single color black outline, 128x128"},
    # Mobs
    {"id": "ashveil_grazer", "label": "Ashveil Grazer", "body_type": "quadruped", "template": "horse",
     "prompt": "Slow fungal herd beast, quadruped with thick dusty-gray hide covered in pale fungal growths and shelf mushrooms, four sturdy legs, broad back with spore nodules, small head with dark eyes and blunt teeth, docile expression, ash wastes biome, wasteland pixel art top-down view, single color black outline, 128x128"},
    {"id": "lumen_drifter", "label": "Lumen Drifter", "body_type": "quadruped", "template": "jellyfish",
     "prompt": "Bioluminescent floating jelly creature, translucent bell-shaped body in pale blue-green with glowing internal organs, trailing bioluminescent tentacles with small light nodes, no visible eyes, ethereal floating appearance with soft glow effect, neon bogs biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "rustcarapace_scuttler", "label": "Rustcarapace Scuttler", "body_type": "quadruped", "template": "beetle",
     "prompt": "Armored scrap cleaner, large beetle-like insectoid with heavily segmented rust-brown carapace showing orange corrosion patterns, six jointed legs with claw tips, two long antennae, mandibles visible at front, compact low-to-ground body, rust canyons biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "silkroot_tapper", "label": "Silkroot Tapper", "body_type": "humanoid",
     "prompt": "Rooted stationary plant creature, thick woody trunk-like body with bark texture, root tendrils spreading into ground, multiple thin branch-like arms ending in leaf clusters, a single large organic eye in center of trunk face, mottled green-brown coloration, small glowing sap droplets on branches, ironwood thicket biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "echo_chorister", "label": "Echo Chorister", "body_type": "quadruped", "template": "bear",
     "prompt": "Singing burrow colony creature, bear-sized quadruped with thick shaggy fur in dusty brown with darker stripes, large rounded ears that cup forward, wide mouth with visible vocal sac at throat, oversized paws with digging claws, small eyes, calm peaceful demeanor, corpse fields biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "iron_buck", "label": "Iron Buck", "body_type": "quadruped", "template": "horse",
     "prompt": "Metallic forest stag, quadruped entirely covered in iron-gray metallic hide with chrome-like sheen on antlers, branching antlers made of twisted metal, hooves are solid iron blocks, lean muscular body, small dark eyes, proud alert posture, ironwood thicket biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "blight_toad", "label": "Blight Toad", "body_type": "quadruped", "template": "toad",
     "prompt": "Bloated toxic toad, wide squat body covered in warty greenish-yellow skin with darker poison patches, huge bulging eyes on top of head, wide mouth with long tongue visible, smaller front legs and powerful back legs, glowing yellow-green toxin sacs on back, neon bogs biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "dust_devil", "label": "Dust Devil", "body_type": "quadruped", "template": "moth",
     "prompt": "Dust-colored moth swarm manifested as a single entity, dusty tan and pale brown wings with darker vein patterns, feathery antennae, multiple legs clustered together, cloud of dust particles swirling around body giving indistinct edges, single entity representing a swarm, ash wastes biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "charnel_stalker", "label": "Charnel Stalker", "body_type": "quadruped", "template": "lion",
     "prompt": "Pack-hunting quadruped predator, lean muscular feline body with patchy mangy fur in dark gray-black, long barbed tendrils extending from shoulders and flank like sensory whips, visible ribs through thin hide, four powerful legs with clawed paws, glowing yellow eyes, aggressive hunched hunting posture, pixel art top-down view, single color black outline, 128x128"},
    {"id": "voidspine_leech", "label": "Voidspine Leech", "body_type": "quadruped", "template": "snake",
     "prompt": "Parasitic energy drainer, eel-like serpentine body in deep purple-black with visible void energy pulsing along spine as dark blue glow lines, elongated head with circular sucker mouth filled with tiny teeth, two small vestigial limbs near front, floating slightly above ground with undulating motion, rift-touched creature, pixel art top-down view, single color black outline, 128x128"},
    {"id": "mycelial_behemoth", "label": "Mycelial Behemoth", "body_type": "humanoid",
     "prompt": "Massive spore-hurling hulk, enormous humanoid shape made of intertwined fungal growth and organic matter, broad hulking shoulders, thick trunk-like legs, one arm is massive club-like fist, other arm is spore-launching growth, head is a large mushroom cap with glowing gills underneath, pale cream and brown coloration with orange spore patches, pixel art top-down view, single color black outline, 128x128"},
    {"id": "glimmer_swarm", "label": "Glimmer Swarm", "body_type": "quadruped", "template": "beetle",
     "prompt": "Coordinated acidic insects, dense cluster of small beetle-like insects forming a single mobile swarm entity, individual insects have iridescent green-purple carapaces, swarm shape shifts and flows with insects at edges separating briefly, green acid drip visible from mandibles, faint bioluminescent glow, pixel art top-down view, single color black outline, 128x128"},
    {"id": "ferroclaw_reaver", "label": "Ferroclaw Reaver", "body_type": "humanoid",
     "prompt": "Ferro-organic horror with magnetic traits, vaguely humanoid shape made of fused metal scrap and organic tissue, one arm ends in massive spinning drilling claw, other arm is magnetic claw pulling metal fragments, fused metal helmet head with single red optic, patchwork iron body with rust and blood stains, pixel art top-down view, single color black outline, 128x128"},
    {"id": "ash_crawler", "label": "Ash Crawler", "body_type": "quadruped", "template": "beetle",
     "prompt": "Ash-colored wasteland scavenger beetle, segmented chitinous carapace in dusty gray-brown tones with darker ridge lines, six armored legs with claw tips, prominent mandibles at front, two short antennae, compact oval body low to ground, ash wastes biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "rift_elk", "label": "Rift Elk", "body_type": "quadruped", "template": "horse",
     "prompt": "Large elk with glowing antlers, majestic quadruped with muscular body covered in dark brown fur with lighter underbelly, enormous branching antlers that glow with crackling blue-white rift energy, antlers semi-translucent at tips, hooves give off faint glow, eyes glow pale blue, noble powerful posture, rift-touched creature, pixel art top-down view, single color black outline, 128x128"},
    {"id": "fungal_hurler", "label": "Fungal Hurler", "body_type": "humanoid",
     "prompt": "Spore-throwing brute with massive mushroom cap head, large humanoid figure with thick muscular build, enormous pale mushroom cap with purple gills growing from shoulders and head, body covered in shelf fungi and moss patches, powerful arms ending in clawed hands, one hand holds growth that launches spore pods, toxin marshes biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "glass_serpent", "label": "Glass Serpent", "body_type": "quadruped", "template": "snake",
     "prompt": "Crystalline desert serpent, long serpentine body made of translucent glass-like segmented plates in pale yellow and clear crystal, internal structure visible through crystalline body, diamond-shaped head with multiple small crystal facet eyes, refractive scales that catch and scatter light, glass dunes biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "bone_crawler", "label": "Bone Crawler", "body_type": "quadruped", "template": "centipede",
     "prompt": "Bone-armored carrion centipede, long segmented body with each segment protected by curved white bone plates like ribs wrapped around, dozens of small legs along underside, head has multiple small eyes and curved mandibles, bone spikes protrude from each segment, pale white and bone-yellow coloration, corpse fields biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "storm_raptor", "label": "Storm Raptor", "body_type": "quadruped", "template": "bird",
     "prompt": "Lightning-fast highland raptor, bipedal bird-like predator with feathered wings folded against body, sleek aerodynamic body in dark blue-gray with white chest, feathered crest on head, sharp curved beak, powerful clawed feet, small lightning arcs crackle between wing feathers, stormspire highlands biome, pixel art top-down view, single color black outline, 128x128"},
    {"id": "void_stalker", "label": "Void Stalker", "body_type": "quadruped", "template": "lion",
     "prompt": "Fast void hunter that phases between realities, sleek feline predator shape made of swirling purple-black void energy with occasional solid patches of dark chitin, body partially transparent at edges as if fading out of existence, four long legs with claws that leave trail of darkness, head with multiple glowing blue eyes arranged in arc, flickering unstable form, pixel art top-down view, single color white outline, 128x128"},
    {"id": "abyssal_weaver", "label": "Abyssal Weaver", "body_type": "quadruped", "template": "spider",
     "prompt": "Void web-spider that traps prey in reality tears, eight-legged spider-like entity with body made of dark purple crystal-like chitin, abdomen has glowing rift patterns that pulse, long thin legs with sharp points, multiple red eyes arranged on front, strands of dark energy web trailing from spinnerets, void rift aesthetic, pixel art top-down view, single color white outline, 128x128"},
    {"id": "null_shade", "label": "Null Shade", "body_type": "humanoid",
     "prompt": "Stealth void wraith that shimmers between dimensions, tall gaunt humanoid silhouette that is mostly transparent and flickering, body composed of dark smoke and void particles with occasional solid glimpses, featureless head with two white pinprick eyes, long arms ending in clawed shadows, trailing wisps of darkness from lower body instead of legs, pixel art top-down view, single color white outline, 128x128"},
    {"id": "lifecycle_horror", "label": "Lifecycle Horror", "body_type": "humanoid",
     "prompt": "Regenerating life-form that splits when damaged, amorphous multi-limbed entity with pale fleshy body, multiple arms and legs growing from central mass at odd angles, several faces partially formed on torso and limbs, body has visible cell-like divisions with cracks of pink light, constantly shifting and writhing form, two main arms ending in lumpy fists, life rift aesthetic, pixel art top-down view, single color black outline, 128x128"},
    {"id": "spore_phantom", "label": "Spore Phantom", "body_type": "humanoid",
     "prompt": "Floating spore cloud that poisons and confuses, vaguely humanoid upper body made of dense spore mass in pale green-gray, lower body trails off into diffuse spore cloud, no distinct face just two glowing yellow points deep within, arms are tendrils of spores that extend and retract, constant particle emission from body, floating above ground, life rift aesthetic, pixel art top-down view, single color black outline, 128x128"},
    {"id": "arc_dynamo", "label": "Arc Dynamo", "body_type": "humanoid",
     "prompt": "Orbital energy construct with lightning arcs, hovering mechanical orb about the size of a human torso, constructed of white metal panels with glowing blue energy cores visible through gaps, four articulated mechanical arms ending in energy emitters extend from central body, constant electrical arcs jump between arms and surrounding air, floating with slight rotation, energy rift aesthetic, pixel art top-down view, single color black outline, 128x128"},
    {"id": "storm_herald", "label": "Storm Herald", "body_type": "humanoid",
     "prompt": "Massive energy boss that commands lightning, enormous humanoid figure made of crackling electrical energy and dark storm cloud matter, towering twice the size of normal entities, head is a brilliant white energy core with no face, shoulders have lightning arcs forming wing-like shapes, arms end in crackling energy claws, body semi-transparent with visible storm inside, energy rift aesthetic, pixel art top-down view, single color black outline, 128x128"},
    {"id": "rift_maw", "label": "Rift Maw", "body_type": "quadruped", "template": "hippo",
     "prompt": "Rift core guardian that devours anything near the core, massive quadrupedal entity with body like a living rift portal, wide body made of swirling purple-black energy with a massive circular mouth taking up most of the front, mouth filled with concentric rings of teeth, four stubby powerful legs, small eyes on stalks on top, tendrils of void energy trail from body, energy rift aesthetic, pixel art top-down view, single color white outline, 128x128"},
]

BACKGROUNDS = [
    {"id": "bg_ash_wastes",
     "prompt": "Wasteland horizon with ash-covered twisted ruins under hazy orange sky, cracked barren earth in foreground, distant twisted scrub vegetation silhouettes, dust particles in air, oppressive atmosphere, 688x288 pixel art landscape"},
    {"id": "bg_rust_canyons",
     "prompt": "Deep canyon vista filled with rusted wreckage and crashed vehicles from old corporate wars, red-brown canyon walls with layered strata, twisted metal structures protruding from canyon edges, hazy orange-brown sky with smoke trails, 688x288 pixel art landscape"},
    {"id": "bg_neon_bogs",
     "prompt": "Polluted wetlands with glowing neon pink and green flora, bioluminescent plants and mushrooms reflecting in dark water, old power line towers leaning at angles, toxic fog banks in blue-green tones, eerie beautiful twilight atmosphere, 688x288 pixel art landscape"},
    {"id": "bg_scorched_plains",
     "prompt": "Cracked baked earth stretching to horizon under oppressive bright sun, heat haze shimmer effect, scattered charred ruins of old farm buildings, glass-like patches where sand melted, pale yellow-white sky, barren desolate heat, 688x288 pixel art landscape"},
    {"id": "bg_ironwood_thicket",
     "prompt": "Dense metallic forest with chrome and iron-colored trees with angular branch structures, metallic vines hanging between trunks, blue magnetic energy nodes glowing on some trees, dark shadowy undergrowth, twisted metal roots showing above ground, 688x288 pixel art landscape"},
    {"id": "bg_glass_dunes",
     "prompt": "Shimmering sand dunes made of melted glass fragments in pale yellow, crystal clusters growing from dune surfaces, ancient half-buried structures with geometric shapes, prismatic light reflections and rainbow glints, pale blue sky with heat shimmer, 688x288 pixel art landscape"},
    {"id": "bg_corpse_fields",
     "prompt": "Old battlefield with scattered bones and rusted tank hulls, crater-pocked earth in dark brown and grey, broken weapons and helmets half-buried, twisted barbed wire, dark grey sky with vulture silhouettes, somber memorial atmosphere, 688x288 pixel art landscape"},
    {"id": "bg_stormspire_highlands",
     "prompt": "High plateau with ancient communication towers crackling with blue-white lightning, dark storm clouds swirling above with constant lightning flashes, wind-swept rocky ground with sparse vegetation, distant spires on horizon, dramatic electrical storm atmosphere, 688x288 pixel art landscape"},
    {"id": "bg_toxin_marshes",
     "prompt": "Swamp thick with green-yellow chemical sludge water, dead twisted tree trunks rising from toxic pools, gas bubbles surfacing and popping, sickly green sky with yellow haze, mutated plants with unnatural shapes, hostile poisonous atmosphere, 688x288 pixel art landscape"},
    {"id": "bg_dead_city_outskirts",
     "prompt": "Ruined megacity edges with collapsed skyscrapers silhouetted against orange-brown sky, rubble-filled streets with overgrown vegetation, broken road signs and crushed vehicles, massive crack in reality with purple energy visible in distance gap between buildings, 688x288 pixel art landscape"},
]


def extract_job_id(result: dict, default: str = "") -> str:
    """Extract job/character/object ID from an MCP tool result."""
    data = extract_result_data(result)
    if isinstance(data, dict):
        for key in ("character_id", "object_id", "id", "job_id", "animation_id"):
            if key in data:
                return str(data[key])
    if isinstance(result, dict):
        for key in ("character_id", "object_id", "id", "job_id", "animation_id"):
            if key in result:
                return str(result[key])
    return default


def extract_download_url(result: dict) -> str:
    """Extract download URL from a get_character or get_object result."""
    data = extract_result_data(result)
    if isinstance(data, dict):
        for key in ("download_url", "url", "sprite_url", "image_url"):
            if key in data:
                return str(data[key])
    return ""


def extract_status(result: dict) -> str:
    """Extract status from a get_character or get_object result."""
    data = extract_result_data(result)
    if isinstance(data, dict):
        for key in ("status", "state"):
            val = data.get(key, "")
            if val:
                return val
    return "unknown"


def download_file(url: str, dest: Path) -> bool:
    if not url:
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(url, str(dest))
        size = dest.stat().st_size
        print(f"    Downloaded {dest.name} ({size} bytes)")
        return True
    except Exception as e:
        print(f"    FAILED {dest.name}: {e}")
        return False


def poll_until_complete(get_func, job_id, meta, max_polls=60, interval=10):
    """Poll get_character or get_object until status is complete."""
    for attempt in range(max_polls):
        time.sleep(interval)
        result = get_func(job_id)
        status = extract_status(result)
        dl_url = extract_download_url(result)
        if status in ("complete", "completed", "ready"):
            print(f"  [DONE] {meta.get('type','')} {meta.get('id','')} ({attempt*interval}s)")
            return result, dl_url, status
        elif status in ("failed", "error"):
            print(f"  [FAILED] {meta.get('type','')} {meta.get('id','')}: {result}")
            return result, "", status
        if attempt % 6 == 0 and attempt > 0:
            print(f"  ...waiting for {meta.get('type','')} {meta.get('id','')} ({attempt*interval}s)")
    print(f"  [TIMEOUT] {meta.get('type','')} {meta.get('id','')}")
    return None, "", "timeout"


# ── Main ──

def main():
    print("=" * 60)
    print("PixelLab Asset Generator Pipeline")
    print(f"Concurrency: {CONCURRENCY}")
    print("=" * 60)

    all_char_results = []
    all_bg_results = []

    # Phase 1: Submit all character creation jobs (batched to concurrency)
    print(f"\n{'='*60}")
    print(f"Phase 1: Creating {len(CHARACTERS)} characters...")
    print(f"{'='*60}")

    active = 0
    char_queue = list(CHARACTERS)
    char_map = {}  # id -> info
    submitted_ids = []

    while char_queue or active > 0:
        # Submit up to concurrency limit
        while char_queue and active < CONCURRENCY:
            c = char_queue.pop(0)
            params = {
                "name": c["label"],
                "body_type": c["body_type"],
                "n_directions": 1,
                "mode": "standard",
                "size": 128,
                "prompt": c["prompt"],
            }
            if "template" in c:
                params["template"] = c["template"]
            print(f"  Submitting {c['label']}...")
            result = mcp_call("tools/call", {
                "name": "create_character",
                "arguments": params,
            })
            job_id = extract_job_id(result)
            char_map[c["id"]] = {
                "job_id": job_id,
                "label": c["label"],
                "team": "player" if c["id"] in [x["id"] for x in CHARACTERS[:16]] else "mob",
                "template": c.get("template", ""),
            }
            print(f"    -> job {job_id}")
            submitted_ids.append(c["id"])
            active += 1

        # Poll one job to check completion (while respecting concurrency)
        if active > 0:
            polled = False
            for cid in submitted_ids:
                info = char_map.get(cid)
                if not info or info.get("_completed"):
                    continue
                result = get_character(info["job_id"])
                status = extract_status(result)
                dl_url = extract_download_url(result)

                if status in ("complete", "completed", "ready"):
                    print(f"  [DONE] {info['label']}: {dl_url[:60] if dl_url else 'no URL'}")
                    info["_completed"] = True
                    info["_download_url"] = dl_url
                    info["_result"] = result
                    all_char_results.append(info)
                    active -= 1
                    polled = True
                elif status in ("failed", "error"):
                    print(f"  [FAILED] {info['label']}: {result}")
                    info["_completed"] = True
                    active -= 1
                    polled = True

                if polled:
                    break

            if not polled:
                time.sleep(5)

    print(f"\n  All {len(all_char_results)} characters created.")

    # Phase 2: Submit animations for completed characters
    print(f"\n{'='*60}")
    print("Phase 2: Submitting animations for completed characters...")
    print(f"{'='*60}")

    anim_entries = []
    active = 0
    anim_queue = []

    for cid, cinfo in char_map.items():
        if not cinfo.get("_completed") or not cinfo.get("job_id"):
            continue
        is_player = cinfo["team"] == "player"
        anims = [
            {"label": "idle", "template": "breathing-idle", "frames": 8},
            {"label": "walk", "template": "walking", "frames": 8},
            {"label": "attack", "template": "fight-stance-idle", "frames": 8},
        ]
        if is_player:
            anims.append({"label": "hurt", "template": "hurt-stumble", "frames": 4})
        else:
            anims.append({"label": "death", "template": "death-fall", "frames": 4})
        for a in anims:
            anim_queue.append({**a, "char_id": cid, "char_job_id": cinfo["job_id"], "char_label": cinfo["label"]})

    while anim_queue or active > 0:
        while anim_queue and active < CONCURRENCY:
            a = anim_queue.pop(0)
            print(f"  Submitting {a['char_label']}/{a['label']}...")
            result = mcp_call("tools/call", {
                "name": "animate_character",
                "arguments": {
                    "character_id": a["char_job_id"],
                    "template_animation_id": a["template"],
                    "directions": ["south"],
                    "mode": "template",
                    "frame_count": a["frames"],
                },
            })
            job_id = extract_job_id(result)
            a["_anim_job_id"] = job_id
            a["_result"] = result
            print(f"    -> job {job_id}")
            anim_entries.append(a)
            active += 1

        if active > 0:
            # Poll one animation
            completed_any = False
            for a in anim_entries:
                if a.get("_completed"):
                    continue
                result = mcp_call("tools/call", {
                    "name": "get_character",
                    "arguments": {"character_id": a["char_job_id"]},
                })
                status = extract_status(result)
                if status in ("complete", "completed", "ready"):
                    a["_completed"] = True
                    active -= 1
                    completed_any = True
                    print(f"  [DONE] {a['char_label']}/{a['label']} animation")
                elif status in ("failed", "error"):
                    a["_completed"] = True
                    active -= 1
                    completed_any = True
            if not completed_any:
                time.sleep(5)

    print(f"\n  All animations submitted.")

    # Phase 3: Submit backgrounds
    print(f"\n{'='*60}")
    print(f"Phase 3: Creating {len(BACKGROUNDS)} backgrounds...")
    print(f"{'='*60}")

    for bg in BACKGROUNDS:
        print(f"  Submitting {bg['id']}...")
        result = mcp_call("tools/call", {
            "name": "create_ui_asset",
            "arguments": {
                "name": bg["id"],
                "width": 688,
                "height": 288,
                "prompt": bg["prompt"],
            },
        })
        job_id = extract_job_id(result)
        bg["_job_id"] = job_id
        print(f"    -> job {job_id}")

    # Poll backgrounds
    for bg in BACKGROUNDS:
        job_id = bg.get("_job_id", "")
        if not job_id:
            continue
        print(f"  Waiting for {bg['id']}...")
        result, dl_url, status = poll_until_complete(get_object, job_id, {"type": "background", "id": bg["id"]})
        bg["_download_url"] = dl_url
        bg["_status"] = status

    # Phase 4: Download results
    print(f"\n{'='*60}")
    print("Phase 4: Downloading assets...")
    print(f"{'='*60}")

    results_summary = {"characters": [], "animations": [], "backgrounds": []}
    download_tasks = []

    # Download character sprites
    for cid, cinfo in char_map.items():
        dl_url = cinfo.get("_download_url", "")
        if not dl_url:
            continue
        if cinfo["team"] == "player":
            parts = cid.split("_", 1)
            if len(parts) == 2:
                race, gender = parts
                dest = CHAR_DIR / f"{race}_{gender}" / f"{race}_{gender}_S.png"
            else:
                continue
        else:
            dest = MOBS_DIR / f"{cid}.png"
        if download_file(dl_url, dest):
            results_summary["characters"].append({
                "id": cid, "label": cinfo["label"], "team": cinfo["team"],
                "path": str(dest),
            })

    # Download background images
    for bg in BACKGROUNDS:
        dl_url = bg.get("_download_url", "")
        if not dl_url:
            continue
        dest = BACKGROUNDS_DIR / f"{bg['id']}.png"
        if download_file(dl_url, dest):
            results_summary["backgrounds"].append({
                "id": bg["id"], "path": str(dest),
            })

    # Animation download URLs are embedded in character data
    print(f"\n{'='*60}")
    print("Phase 5: Downloading animation spritesheets...")
    print(f"{'='*60}")

    for cid, cinfo in char_map.items():
        # Re-fetch character to get animation URLs
        result = get_character(cinfo["job_id"])
        data = extract_result_data(result)
        if not isinstance(data, dict):
            continue

        # PixelLab returns animations as part of character data
        animations = data.get("animations", data.get("animation_data", {}))
        if isinstance(animations, dict):
            for anim_name, anim_info in animations.items():
                if isinstance(anim_info, dict):
                    url = anim_info.get("download_url", anim_info.get("url", ""))
                elif isinstance(anim_info, str):
                    url = anim_info
                else:
                    continue
                if not url:
                    continue

                if cinfo["team"] == "player":
                    parts = cid.split("_", 1)
                    if len(parts) == 2:
                        race, gender = parts
                        dest = CHAR_DIR / f"{race}_{gender}" / f"{anim_name}.png"
                    else:
                        continue
                else:
                    dest = MOBS_DIR / cid / f"{anim_name}.png"
                if download_file(url, dest):
                    results_summary["animations"].append({
                        "id": cid, "anim": anim_name, "path": str(dest),
                    })

    # Save manifest
    manifest_path = Path("pixellab_results.json")
    manifest_path.write_text(json.dumps(results_summary, indent=2))
    print(f"\n  Results manifest saved to {manifest_path}")

    print(f"\n{'='*60}")
    print("Pipeline complete!")
    print(f"{'='*60}")
    print(f"\nNext: Run 'python build_spriteframes.py' to create .tres resources")
    print(f"Then: Godot script changes (CombatPawn3D.gd -> AnimatedSprite3D)")


if __name__ == "__main__":
    main()
