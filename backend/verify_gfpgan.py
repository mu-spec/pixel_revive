#!/usr/bin/env python3
"""
Standalone verification: does the version-pinned GFPGAN endpoint work?

This proves the Phase-0 fix is correct BEFORE you redeploy the backend to Vercel.
It calls Replicate DIRECTLY (the same endpoint the fixed backend uses), so you
don't need to redeploy to confirm.

USAGE:
  1. Get your Replicate token (r8_...) from replicate.com → Account → API tokens
  2. Run:
       REPLICATE_API_TOKEN="r8_xxxxx" python3 verify_gfpgan.py

Expected output: "✅ SUCCESS — GFPGAN returned a real image"
If you still see 404, the version hash has changed — fetch the new one from
https://replicate.com/tencentarc/gfpgan/api and update GFPGAN_VERSION below.
"""
import base64
import io
import os
import sys
import time

import requests
from PIL import Image

# Must match backend/server.js GFPGAN_VERSION exactly.
GFPGAN_VERSION = "tencentarc/gfpgan:0fbacf7afc6c144e5be9767cff80f25aff23e52b0708f17e20f9879b2f21516c"

TOKEN = os.environ.get("REPLICATE_API_TOKEN", "").strip()
if not TOKEN:
    print("❌ Set REPLICATE_API_TOKEN first, e.g.:")
    print("   REPLICATE_API_TOKEN='r8_xxx' python3 verify_gfpgan.py")
    sys.exit(1)

# Use a tiny built-in test image (solid color) — cheapest possible call.
# Replace with a real face photo to see a visible improvement.
src = sys.argv[1] if len(sys.argv) > 1 else None
if src:
    img = Image.open(src).convert("RGB")
    img.thumbnail((512, 512))
else:
    img = Image.new("RGB", (256, 256), (150, 130, 120))
buf = io.BytesIO()
img.save(buf, format="JPEG", quality=85)
b64 = base64.b64encode(buf.getvalue()).decode()
data_uri = f"data:image/jpeg;base64,{b64}"

print(f"Calling GFPGAN version endpoint ({GFPGAN_VERSION})...")
t0 = time.time()

create = requests.post(
    "https://api.replicate.com/v1/predictions",
    headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
        "Prefer": "wait=60",
    },
    json={"version": GFPGAN_VERSION, "input": {"img": data_uri, "version": "v1.4", "scale": 2}},
    timeout=120,
)

print(f"Create response: HTTP {create.status_code}")
if create.status_code not in (200, 201):
    print(f"❌ Create failed:\n{create.text[:500]}")
    sys.exit(1)

prediction = create.json()
status = prediction.get("status")
get_url = prediction.get("urls", {}).get("get") or f"https://api.replicate.com/v1/predictions/{prediction.get('id')}"

# Poll until done.
attempts = 0
while status not in ("succeeded", "failed", "canceled") and attempts < 60:
    time.sleep(2)
    attempts += 1
    poll = requests.get(get_url, headers={"Authorization": f"Bearer {TOKEN}"}, timeout=60)
    prediction = poll.json()
    status = prediction.get("status")

if status != "succeeded":
    print(f"❌ Prediction did not succeed: {status} — {prediction.get('error')}")
    sys.exit(1)

out_url = prediction["output"]
out_url = out_url[0] if isinstance(out_url, list) else out_url
img_resp = requests.get(out_url, timeout=60)
if img_resp.status_code != 200:
    print(f"❌ Could not download result: HTTP {img_resp.status_code}")
    sys.exit(1)

dt = time.time() - t0
open("gfpgan_result.png", "wb").write(img_resp.content)
out_img = Image.open(io.BytesIO(img_resp.content))
print(f"\n✅ SUCCESS — GFPGAN returned a real image in {dt:.1f}s")
print(f"   output size: {out_img.size}")
print(f"   saved to: gfpgan_result.png")
print("\nThis confirms the version-pin fix is correct. Redeploy the backend to Vercel,")
print("then the app's Face Enhance / Auto Enhance will work end-to-end.")
