#!/usr/bin/env python3
"""
Upload a built lab image to Cloudflare R2 and verify what the bucket serves.

    python3 upload-ova.py ../../asterisk-lab-base-1.0.ova

Credentials come from backend/.env (R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY) and
are never printed. The point of the verify step at the end is that the lab tells
students to check a SHA-256 — if the bucket serves different bytes, every one of
them concludes their download is corrupt.
"""
import hashlib
import time
import os
import sys
import urllib.request
from pathlib import Path

import boto3
from boto3.s3.transfer import TransferConfig

ACCOUNT = "caef7c33730937961aafc2a49a849e32"
ENDPOINT = f"https://{ACCOUNT}.r2.cloudflarestorage.com"
BUCKET = "courses"
PUBLIC = "https://pub-d6afaeeb01b74b1eb49d4564ab14ee61.r2.dev"


def load_env(path: Path) -> dict:
    env = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip().strip('"').strip("'")
    return env


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    src = Path(sys.argv[1]).resolve()
    if not src.is_file():
        print(f"not found: {src}")
        return 1

    env_path = Path(__file__).resolve().parents[3] / "sip-lab-explorer" / "backend" / ".env"
    env = load_env(env_path)
    key_id = env.get("R2_ACCESS_KEY_ID")
    secret = env.get("R2_SECRET_ACCESS_KEY")
    if not key_id or not secret:
        print(f"R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY not found in {env_path}")
        return 1

    local_hash = sha256(src)
    size = src.stat().st_size
    print(f"file   {src.name}")
    print(f"size   {size:,} bytes ({size / 1048576:.0f} MB)")
    print(f"sha256 {local_hash}")

    s3 = boto3.client(
        "s3",
        endpoint_url=ENDPOINT,
        aws_access_key_id=key_id,
        aws_secret_access_key=secret,
        region_name="auto",
    )

    seen = [0]

    def progress(n: int) -> None:
        seen[0] += n
        pct = seen[0] * 100 // size
        print(f"\r  uploading… {pct:3d}%  ({seen[0] / 1048576:.0f} MB)", end="", flush=True)

    print(f"\nuploading to s3://{BUCKET}/{src.name}")
    s3.upload_file(
        str(src),
        BUCKET,
        src.name,
        # Version is in the filename, so it can be cached hard and forever.
        ExtraArgs={
            "ContentType": "application/x-virtualbox-ova",
            "CacheControl": "public, max-age=31536000, immutable",
        },
        Config=TransferConfig(multipart_threshold=64 * 1024 * 1024,
                              multipart_chunksize=64 * 1024 * 1024),
        Callback=progress,
    )
    print("\nupload complete")

    head = s3.head_object(Bucket=BUCKET, Key=src.name)
    remote_size = head["ContentLength"]
    print(f"bucket reports {remote_size:,} bytes — {'match' if remote_size == size else 'MISMATCH'}")

    url = f"{PUBLIC}/{src.name}"
    print(f"\nverifying what the public URL actually serves:\n  {url}")
    h = hashlib.sha256()
    # R2 needs a moment after a multipart upload completes before the object
    # is readable at the public edge. Checking immediately returns 403, which
    # looks like a permissions problem and is not one.
    for attempt in range(1, 13):
        try:
            with urllib.request.urlopen(url, timeout=180) as resp:
                code, h, got = resp.status, hashlib.sha256(), 0
                while chunk := resp.read(1 << 20):
                    h.update(chunk)
                    got += len(chunk)
            break
        except urllib.error.HTTPError as exc:
            if exc.code not in (403, 404) or attempt == 12:
                raise
            print(f"  edge not ready ({exc.code}), retrying in 10s... [{attempt}/12]")
            time.sleep(10)
    served = h.hexdigest()

    print(f"  HTTP {code}, {got:,} bytes")
    print(f"  sha256 {served}")
    if served == local_hash:
        print("\nOK — the bucket serves exactly the bytes the lab tells students to expect.")
        print(f"\nPut this in labs/lab0-build-machine.md:\n  {url}")
        return 0
    print("\nMISMATCH — students would all think their download is corrupt. Do not publish.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
