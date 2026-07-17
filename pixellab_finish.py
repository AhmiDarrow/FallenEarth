#!/usr/bin/env python3
"""Quick download + remaining creation, one at a time (serial, no concurrency issues)."""

import json, re, time, urllib.request, urllib.error
from pathlib import Path

API_KEY = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP_URL = "https://api.pixellab.ai/mcp"

DL_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "image/png,image/*;q=0.8,*/*;q=0.5",
    "Referer": "https://pixellab.ai/",
}

def mcp(method, params=None):
    payload = json.dumps({"jsonrpc":"2.0","id":int(time.time()*1000)%100000,"method":method,"params":params or {}}).encode()
    headers = {"Authorization":f"Bearer {API_KEY}","Content-Type":"application/json","Accept":"application/json, text/event-stream"}
    try:
        resp = urllib.request.urlopen(urllib.request.Request(MCP_URL, data=payload, headers=headers, method="POST"), timeout=120)
        body = resp.read().decode()
        for eb in body.strip().split("\n\n"):
            for line in eb.split("\n"):
                if line.startswith("data: "):
                    d = json.loads(line[6:])
                    if "result" in d: return d["result"]
        return {}
    except urllib.error.HTTPError as e:
        return {"error":str(e.code),"body":e.read().decode()[:200]}

def txt(r):
    if r.get("error"): return f"error: {r['error']}"
    for c in r.get("content",[]):
        if c.get("type")=="text": return c.get("text","")
    return str(r)

def is_ready(t):
    return "status: completed" in t

def uid_from(t):
    m = re.search(r'id:\s*([a-f0-9-]+)', t)
    return m.group(1) if m else ""

def download(url, dest):
    if not url: return
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        data = urllib.request.urlopen(urllib.request.Request(url, headers=DL_HEADERS)).read()
        dest.write_bytes(data)
        print(f"  {dest.name} ({len(data)}B)", flush=True)
    except Exception as e:
        print(f"  FAIL {dest.name}: {e}", flush=True)

def fetch_char(uid):
    return mcp("tools/call", {"name":"get_character","arguments":{"character_id":uid,"include_preview":False}})

def parse_and_download(t, cid, team):
    """Download rotation + all animation frames from character response text."""
    # Rotation
    m = re.search(r'south:\s+(https?://\S+)', t)
    if m:
        dest = (Path(f"assets/characters/{cid.split('_')[0]}_{cid.split('_')[1]}/{cid}_S.png") if team=="player"
                else Path(f"assets/mobs/{cid}.png"))
        download(m.group(1), dest)
    # Anim frames
    current = None
    for line in t.split("\n"):
        am = re.match(r'\s{2}(\S[^(]*?)\s\(south.*?(\d+)f\)', line)
        if am: current = am.group(1).strip().rstrip(",")
        fm = re.match(r'\s{4}frames:\s+(.+)', line)
        if fm and current:
            urls = [u.strip() for u in fm.group(1).split(",")]
            base = (Path(f"assets/characters/{cid.split('_')[0]}_{cid.split('_')[1]}")
                    if team=="player" else Path(f"assets/mobs/{cid}"))
            adir = base / current.replace(" ", "_").replace("-", "_").replace(",","")
            adir.mkdir(parents=True, exist_ok=True)
            for i, u in enumerate(urls): download(u, adir/f"frame_{i:02d}.png")
            current = None

def poll_and_dl(uid, cid, team, label, max_mins=15):
    for i in range(max_mins*6):
        time.sleep(10)
        t = txt(fetch_char(uid))
        if is_ready(t):
            print(f"  [{label}] {cid} ready ({(i+1)*10}s)", flush=True)
            parse_and_download(t, cid, team)
            return t
    print(f"  [TIMEOUT] {cid}", flush=True)
    return ""

def create(method, args):
    t = txt(mcp("tools/call", {"name":method,"arguments":args}))
    return t

# ── ALL KNOWN UIDs from all runs ──
ALL_CHARS = {
    # Players
    "human_male": "b4a12c49-7e18-4b7f-88ef-aa243142be1b",
    "human_female": "2e872b24-772c-41cf-87b9-933efdedd051",
    "mutant_male": "9ba08023-6548-4ed4-9b5a-94a8a8a354ac",
    "mutant_female": "88671592-ebcd-4d6a-a0d2-eaafda412bc2",
    "sentientai_male": "e2ec51df-0808-4524-97db-2dc22b08ca80",
    "sentientai_female": "9454832e-823b-4772-a2e3-0479287a9834",
    "cyborg_male": "3e77535e-9e0d-4bab-ba64-4b9169f2dadf",
    "cyborg_female": "6d7d2944-f6b0-409c-bb43-e15ce5b5462c",
    "chthon_male": "4325ebaf-74ae-4a09-a0f3-a7c1a6bf8325",
    "chthon_female": "13979e12-26c0-4eb5-8ec5-d67cfb7a6495",
    "vesperid_female": "04e680c4-98e2-4c8c-bdfe-cb5d69dc8962",
    "nullborn_male": "370e9d31-712c-4ec7-8c73-49398ce1820c",
    "nullborn_female": "47911b25-b3b3-4514-b2f0-4d92f3ba64e0",
    "revenant_female": "c915ca30-a7cd-47f1-8ed3-497c7a643594",
    # Mobs
    "ashveil_grazer": "baa5181d-9687-4dc4-b5c1-92c81374cb41",
    "lumen_drifter": "355538d5-b063-4c45-aac3-3297d34a6e48",
}

def main():
    print("=== 1: Download + queue anims for existing chars ===", flush=True)
    for cid, uid in ALL_CHARS.items():
        team = "player" if cid in [c for c in ALL_CHARS if c.count("_")==1 and c not in ["ashveil_grazer","lumen_drifter"]] else "mob"
        # Handle team detection properly
        if cid in ["human_male","human_female","mutant_male","mutant_female",
                   "sentientai_male","sentientai_female","cyborg_male","cyborg_female",
                   "chthon_male","chthon_female","vesperid_female",
                   "nullborn_male","nullborn_female","revenant_female"]:
            team = "player"
        else:
            team = "mob"
        t = txt(fetch_char(uid))
        if is_ready(t):
            parse_and_download(t, cid, team)
            # Check anims
            ac = len(re.findall(r'\s{2}\S[^(]*?\(south', t))
            print(f"  {cid}: {ac}/4 anims", flush=True)
            if ac < 4:
                for tid in ["breathing-idle","walking","fight-stance-idle-8-frames","falling-back-death"]:
                    create("animate_character", {"character_id":uid,"template_animation_id":tid,
                        "directions":["south"],"mode":"template","frame_count":8})
                    time.sleep(1)
        else:
            print(f"  {cid}: not ready, retrying later", flush=True)

    # Wait for pending anims
    print("\n=== 2: Wait for anims ===", flush=True)
    for cid, uid in ALL_CHARS.items():
        t = poll_and_dl(uid, cid, "player" if cid in ["human_male","human_female","mutant_male","mutant_female",
                   "sentientai_male","sentientai_female","cyborg_male","cyborg_female",
                   "chthon_male","chthon_female","vesperid_female",
                   "nullborn_male","nullborn_female","revenant_female"] else "mob", "ANIM", max_mins=20)

    print("\n=== DONE ===", flush=True)
    print("Remaining to create manually:", flush=True)
    print("  Players: vesperid_male, revenant_male", flush=True)
    print("  Mobs: 25 more", flush=True)
    print("  Backgrounds: 10", flush=True)

if __name__ == "__main__":
    main()
