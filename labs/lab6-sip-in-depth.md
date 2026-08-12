# Lab 6: See What SIP Actually Sends

**Time:** ~55 minutes
**Prerequisites:** Lab 5 — voicemail, transfers and the `support` queue all work.

Five labs of building, and you have never looked at a SIP packet.

Everything so far you diagnosed from Asterisk's point of view — `pjsip show endpoints`,
`core show channels`. That works until the day Asterisk and the phone disagree about
what happened, and then the only source of truth is what actually crossed the wire.

This lab is about reading that. Then you use what you learn to negotiate codecs
deliberately, put a phone in a browser, and encrypt the whole thing.

---

## Step 1 — Watch a call, live

`sngrep` was installed on your lab machine in Lab 0. It is a SIP packet capture tool with
a ladder diagram, and it is the single most useful troubleshooting tool in VoIP.

On the VM:

```bash
sudo sngrep
```

**You should see** an empty list with a header. It is now capturing every SIP packet on
the machine.

Leave it running and, from your softphone, **dial `600`**.

**You should see** a new row appear the instant the call starts — method `INVITE`, from
`6001`, to `600`.

Select it with the arrow keys and press **Enter**.

**You should see** the ladder diagram — time down the left, one column per party, every
message as an arrow:

```
  192.168.1.20                 192.168.1.47
       │                             │
       │ ──────── INVITE ──────────► │
       │ ◄─────── 100 Trying ─────── │
       │ ◄─────── 200 OK ─────────── │
       │ ──────── ACK ─────────────► │
       │                             │
       │ ◄─────── BYE ────────────── │   (or ──── BYE ────►, depending who hung up)
       │ ──────── 200 OK ──────────► │
```

That shape — INVITE, a provisional response, 200 OK, ACK — is the SIP call setup you will
see for the rest of your career. Learn to recognise it and anything abnormal jumps out.

Press **Enter** on the `INVITE` line to read the whole message.

Keys worth knowing: **F2** save to pcap, **F7** filter, **Esc** back, **q** quit.

---

## Step 2 — Read the SDP

Inside the INVITE, below the headers and after a blank line, is the **SDP** — the body
that negotiates media. Scroll to it.

**You should see** something like:

```
v=0
o=- 3950481324 3950481324 IN IP4 192.168.1.20
c=IN IP4 192.168.1.20
m=audio 4002 RTP/AVP 0 8 101
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
```

Four lines carry all the meaning:

| Line | Meaning |
|---|---|
| `c=IN IP4 192.168.1.20` | **Send the audio here.** Not where the SIP came from — where the *media* should go. When these differ, you have NAT. |
| `m=audio 4002 RTP/AVP 0 8 101` | "I will receive audio on **port 4002**, and I support payload types 0, 8 and 101, in that order of preference." |
| `a=rtpmap:0 PCMU/8000` | Payload type 0 is μ-law. |
| `a=rtpmap:101 telephone-event/8000` | DTMF as RFC 4733 — the keypresses that made your transfers work in Lab 5. |

Now look at Asterisk's **200 OK** and find *its* SDP.

**You should see** a much shorter `m=` line — typically `m=audio <port> RTP/AVP 0 101`.

**That is codec negotiation.** The phone offered three; Asterisk replied with the one it
chose. It chose μ-law because your endpoint config said `disallow=all` then `allow=ulaw`
first. The answer is always a subset of the offer.

---

## Step 3 — Change the negotiation and watch it change

Prove the connection between config and packets.

Edit `[6001]`'s **endpoint** section in `/etc/asterisk/pjsip.conf` and reverse the codec
order:

```ini
disallow=all
allow=alaw
allow=ulaw
```

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
```

Re-register the phone if needed, then dial `600` again with `sngrep` running.

**You should see** the 200 OK now answer with **`m=audio <port> RTP/AVP 8 101`** — payload
type 8, A-law. The phone offered the same three codecs; you changed which one Asterisk
picked, from the server side, without touching the phone.

Confirm from Asterisk's side during the call:

```bash
sudo asterisk -rx 'core show channels concise' | head -3
sudo asterisk -rx 'pjsip show channelstats'
```

**You should see** the negotiated codec and live RTP counters — packets sent, received,
and lost.

Put `allow=ulaw` back first when you are done.

> **Why this matters commercially:** G.711 (μ-law/A-law) is 64 kbit/s per call plus
> overhead — about 87 kbit/s on the wire. Thirty concurrent calls is roughly 2.6 Mbit/s
> each way. That calculation, from the `m=` line, is how you size a customer's circuit.

---

## Step 4 — See what breaks with NAT

Your lab has no NAT: the phone and the PBX are on one flat network, which is why audio has
just worked. Most real deployments are not like that, and one-way audio is the single most
common VoIP support call.

You can see the cause without breaking anything. In the INVITE's SDP, compare:

- the **`c=` line** — where the phone says to send audio
- the **actual source IP** of the packet, shown at the top of the sngrep screen

**In your lab these are the same.** Behind NAT they are not: the phone writes its *private*
address into `c=` (`192.168.x.x`), the router rewrites the packet's source to the public
address, and Asterisk dutifully sends audio to a private address that means nothing to it.
The caller hears nothing; the phone's audio still arrives. **One-way audio.**

The fix is telling Asterisk to ignore the SDP and use the address the packets really came
from. Add to an endpoint that sits behind NAT:

```ini
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
```

| Option | What it does |
|---|---|
| `rtp_symmetric=yes` | Send RTP back where it came from, not where `c=` claims. |
| `force_rport=yes` | Reply to the real source port, not the one in the `Via` header. |
| `rewrite_contact=yes` | Replace the `Contact` with the real address, so you can call the phone later. |

Those three lines fix the majority of one-way-audio tickets. You do not need them in this
lab — but you will know why the day you do.

---

## Step 5 — A phone in the browser

WebRTC puts a phone on a web page: no install, no configuration by the user. It needs two
things your PBX does not have yet — a **secure WebSocket** to signal over, and an endpoint
configured for it.

### Give Asterisk a TLS certificate

WebRTC will not run over an insecure connection, so this is not optional.

```bash
sudo lab certs
```

That generates a self-signed certificate for your machine's current IP into
`/etc/asterisk/keys/`. (It also runs at every boot, so the certificate follows your IP if
DHCP changes it.)

### Turn on the HTTP server

Edit `/etc/asterisk/http.conf`:

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
tlsenable=yes
tlsbindaddr=0.0.0.0:8089
tlscertfile=/etc/asterisk/keys/asterisk.pem
tlsprivatekey=/etc/asterisk/keys/asterisk.key
```

```bash
sudo asterisk -rx 'module reload http'
sudo asterisk -rx 'http show status'
```

**You should see** the server enabled, bound on 8088, and a TLS listener on 8089. If the
TLS line is missing, the certificate is not where `http.conf` says it is.

### Add the WebRTC endpoint

Append to `/etc/asterisk/pjsip.conf`:

```ini
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0

[webrtc-1000]
type=endpoint
context=internal
disallow=all
allow=ulaw
allow=opus
aors=webrtc-1000
auth=webrtc-1000
webrtc=yes
transport=transport-wss
callerid=Browser <1000>

[webrtc-1000]
type=auth
auth_type=userpass
username=webrtc-1000
password=Lab-webrtc-secret

[webrtc-1000]
type=aor
max_contacts=1
```

**`webrtc=yes` is doing a lot of work.** It is a shorthand that switches on everything a
browser requires: DTLS media encryption, an auto-generated certificate for it, ICE
support, AVPF, and RTCP multiplexing. Setting those by hand is six more lines and a
common source of "it almost works".

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
sudo asterisk -rx 'pjsip show endpoint webrtc-1000'
```

**You should see** the endpoint, `Unavailable`, on `transport-wss`.

Give it a number, in `[features]`:

```ini
exten => 1000,1,Dial(PJSIP/webrtc-1000,20)
 same => n,Hangup()
```

### Connect a browser

Serve the client page that ships with the lab:

```bash
cd ~/asterisk-guide/lab/webrtc && python3 -m http.server 8000
```

On your own computer, first visit **`https://<your-lab-ip>:8089/ws`** and accept the
certificate warning — the browser will refuse the WebSocket silently otherwise, and this
is the step everyone skips.

Then open **`http://<your-lab-ip>:8000`**, log in as `webrtc-1000` / `Lab-webrtc-secret`,
and allow microphone access.

```bash
sudo asterisk -rx 'pjsip show endpoint webrtc-1000'
```

**You should see** it become `Not in use` with a contact.

**Dial `600` from the browser.** You should hear the echo test — from a web page, with
nothing installed.

Look at that call in `sngrep`: the SDP now says **`RTP/SAVPF`**, not `RTP/AVP`. `S` for
secure, `F` for feedback. The media is DTLS-encrypted end to end.

---

## Step 6 — Encrypt a normal SIP phone too

WebRTC is encrypted because the browser insists. Your desk phones are not — everything in
Labs 2 to 5 crossed the network in clear text, and `sngrep` read it as easily as you did.

Two separate things need encrypting, and people routinely confuse them:

| | Protects | Mechanism |
|---|---|---|
| **TLS** | the signalling — who called whom, and the passwords | `transport-tls` |
| **SRTP** | the audio itself | `media_encryption=sdes` |

TLS alone still sends the conversation in the clear. Do both.

Add a TLS transport to `pjsip.conf`:

```ini
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.pem
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

And require encryption on `6002`'s **endpoint** section:

```ini
transport=transport-tls
media_encryption=sdes
```

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
sudo asterisk -rx 'pjsip show transports'
```

**You should see** `transport-tls` on `0.0.0.0:5061`.

Point the `6002` softphone at **port 5061, transport TLS**, and accept the certificate.
Register, then call `600` with `sngrep` running.

**You should see** — and this is the point — that sngrep can no longer show you the
message contents. The signalling is encrypted. The SDP will say `RTP/SAVP`.

```bash
sudo asterisk -rx 'pjsip show endpoint 6002'
```

**You should see** `media_encryption: sdes`.

> **Self-signed certificates are for labs.** A real deployment uses a certificate from a
> CA the phones already trust, or you will spend your life clicking through warnings —
> and teaching users to click through certificate warnings is worse than no TLS at all.

---

## ✅ Checkpoint

1. `sngrep` shows a ladder diagram for a call to `600`, and you can read its SDP
2. Reversing `allow=` order changes the negotiated payload type from `0` to `8` in the 200 OK
3. You can point at the `c=` line and say what would break behind NAT, and which three options fix it
4. The browser phone registers and `600` echoes your voice through it
5. That call's SDP shows `RTP/SAVPF`
6. `6002` registers over TLS on 5061, and sngrep can no longer read the signalling

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| sngrep shows nothing | Capturing the wrong interface | `sudo sngrep -d any`. Confirm the phone is actually sending: `sudo tcpdump -ni any port 5060`. |
| Codec change has no effect | Reload rejected, old config still loaded | `sudo tail -5 /var/log/asterisk/messages.log` and look for `Retaining existing configuration`. |
| `http show status` shows no TLS listener | Certificate missing or unreadable | `sudo lab certs`, then check `ls -l /etc/asterisk/keys/` — the key must be readable by the `asterisk` user. |
| Browser never registers | Certificate not accepted | Visit `https://<your-lab-ip>:8089/ws` directly first and accept the warning. Then check the browser console. |
| Browser registers but no audio | Microphone permission, or ICE | The browser must have mic access on an `https` or `localhost` page. Check `pjsip show endpoint webrtc-1000` shows `webrtc=yes` took effect. |
| TLS phone will not register | Wrong port or protocol on the phone | Must be **5061** and **TLS**, not 5060/TCP. `pjsip set logger on` shows whether anything arrives at all. |
| `media_encryption` rejected | Phone does not support SRTP | Try `media_encryption_optimistic=yes` to allow fallback while testing. |

---

**Next:** Lab 7 — making Asterisk talk to other software: call records in a database, and
controlling calls from your own code.
