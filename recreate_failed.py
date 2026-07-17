#!/usr/bin/env python3
"""Recreate failed characters + queue anims for 6 players that only have rotation."""

import json, re, time, urllib.request
from pathlib import Path

API = "0f2b1429-289e-4ce2-bddb-5ed4a460619d"
MCP = "https://api.pixellab.ai/mcp"
DLH = {"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
       "Accept":"image/png,image/*;q=0.8,*/*;q=0.5","Referer":"https://pixellab.ai/"}

def mcp(method, params=None):
    p = json.dumps({"jsonrpc":"2.0","id":int(time.time()*1000)%100000,"method":method,"params":params or {}}).encode()
    h = {"Authorization":f"Bearer {API}","Content-Type":"application/json","Accept":"application/json, text/event-stream"}
    r = urllib.request.Request(MCP, data=p, headers=h, method="POST")
    try:
        b = urllib.request.urlopen(r, timeout=120).read().decode()
        for eb in b.strip().split("\n\n"):
            for l in eb.split("\n"):
                if l.startswith("data: "):
                    d = json.loads(l[6:])
                    if "result" in d: return d["result"]
        return {}
    except Exception as e: return {"error":str(e)}

def txt(r):
    for c in r.get("content",[]):
        if c.get("type")=="text": return c.get("text","")
    return str(r)

def uid_from(t):
    m = re.search(r'id:\s*([a-f0-9-]+)', t)
    return m.group(1) if m else ""

def is_ready(t):
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

def safe_anim_name(name):
    return name.replace(" ","_").replace("-","_").replace(",","").strip("_")

def poll_and_dl(uid, cid, team, label, max_mins=15):
    for i in range(max_mins*6):
        time.sleep(10)
        t = txt(mcp("tools/call",{"name":"get_character","arguments":{"character_id":uid,"include_preview":False}}))
        if is_ready(t):
            print(f"  [{label}] {cid} ({(i+1)*10}s)", flush=True)
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
                    safe = safe_anim_name(cur)
                    base = f"assets/characters/{cid.split('_')[0]}_{cid.split('_')[1]}" if team=="player" else f"assets/mobs/{cid}"
                    for i2, u in enumerate([x.strip() for x in fm.group(1).split(",")]):
                        dl(u, f"{base}/{safe}/frame_{i2:02d}.png")
                    cur = None
            return t
    print(f"  [TIMEOUT] {cid}", flush=True)
    return ""

# 1. Fix vesperid_male and revenant_male
print("=== Fixing failed chars ===", flush=True)
for cid, prompt in [
    ("vesperid_male","Vesperid male, dark brown leathery skin with scale pattern, sharp angular features, small horns, amber slit eyes, spiky mohawk, fur and leather, feral build"),
    ("revenant_male","Revenant male, undead corpse-like, gray decaying skin over bones, skull visible on half face, one red eye, tattered military uniform, exposed ribcage, undead"),
]:
    print(f"Creating {cid}...", flush=True)
    t = txt(mcp("tools/call",{"name":"create_character","arguments":{
        "name":cid,"description":prompt+", pixel art top-down view, single color black outline, 128x128",
        "body_type":"humanoid","n_directions":4,"mode":"standard","size":128,
        "view":"low top-down","outline":"single color black outline","detail":"medium detail",
    }}))
    uid = uid_from(t)
    print(f"  -> {uid}", flush=True)
    if not uid:
        print("  No UID returned, sleeping 10s then retry...", flush=True)
        time.sleep(10)
        t = txt(mcp("tools/call",{"name":"create_character","arguments":{
            "name":cid,"description":prompt+", pixel art top-down view, single color black outline, 128x128",
            "body_type":"humanoid","n_directions":4,"mode":"standard","size":128,
            "view":"low top-down","outline":"single color black outline","detail":"medium detail",
        }}))
        uid = uid_from(t)
        print(f"  -> {uid}", flush=True)
    if uid:
        time.sleep(3)
        poll_and_dl(uid, cid, "player", "CREATE", 15)
        for tid in ["breathing-idle","walking","fight-stance-idle-8-frames","falling-back-death"]:
            mcp("tools/call",{"name":"animate_character","arguments":{"character_id":uid,"template_animation_id":tid,"directions":["south"],"mode":"template","frame_count":8}})
            time.sleep(1)
        poll_and_dl(uid, cid, "player", "ANIM", 20)

# 2. Poll and download pending anims for 6 chars that only got rotation
print("\n=== Checking pending anims ===", flush=True)
ANIM_PENDING = {
    "chthon_female":"13979e12-26c0-4eb5-8ec5-d67cfb7a6495",
    "chthon_male":"4325ebaf-74ae-4a09-a0f3-a7c1a6bf8325",
    "cyborg_female":"6d7d2944-f6b0-409c-bb43-e15ce5b5462c",
    "sentientai_female":"9454832e-823b-4772-a2e3-0479287a9834",
}
for cid, uid in ANIM_PENDING.items():
    poll_and_dl(uid, cid, "player", "ANIM", 20)

print("\n=== DONE ===", flush=True)
