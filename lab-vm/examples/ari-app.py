#!/usr/bin/env python3
"""
Minimal ARI application.

Asterisk hands a call to this program when the dialplan runs Stasis(lab-app).
From that moment the dialplan is out of the picture: this code decides what
happens to the call, and Asterisk carries out the instructions.

Run it, then dial 6700 from a phone.
"""
import asyncio
import base64
import json
import urllib.request

import websockets

USER = "labuser"
PASSWORD = "Lab-ari-secret"
HOST = "localhost:8088"
APP = "lab-app"

AUTH = base64.b64encode(f"{USER}:{PASSWORD}".encode()).decode()


def rest(method, path):
    """Call one ARI REST endpoint. This is how you act on a channel."""
    request = urllib.request.Request(f"http://{HOST}/ari{path}", method=method)
    request.add_header("Authorization", "Basic " + AUTH)
    try:
        return urllib.request.urlopen(request, timeout=5).read()
    except Exception as exc:                      # noqa: BLE001 - lab code
        print(f"  rest error: {exc}", flush=True)
        return None


async def main():
    # Events arrive over a WebSocket; actions go back over REST. Two channels,
    # one conversation — that split is the whole shape of ARI.
    url = f"ws://{HOST}/ari/events?app={APP}&api_key={USER}:{PASSWORD}"

    async with websockets.connect(url) as socket:
        print(f"connected to ARI, waiting for calls on app: {APP}", flush=True)

        async for message in socket:
            event = json.loads(message)
            kind = event.get("type")

            if kind == "StasisStart":
                channel = event["channel"]["id"]
                caller = event["channel"]["caller"]["number"] or "unknown"
                print(f"StasisStart: {caller} -> channel {channel}", flush=True)

                # Nothing in the dialplan told Asterisk to do this. We did.
                rest("POST", f"/channels/{channel}/play?media=sound:demo-congrats")

            elif kind == "StasisEnd":
                channel = event["channel"]["id"]
                print(f"StasisEnd: {channel}", flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nstopped")
