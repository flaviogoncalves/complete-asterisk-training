# Asterisk Guide — Hands-On Lab Manual

A companion workbook to *Asterisk Guide* (2nd edition, Asterisk 22 LTS). Every lab here runs
on your own computer — **Windows, macOS, or Linux** — inside a reproducible **Docker**
environment. No server, no SIP hardware, no analog cards, and nothing legacy: it is pure
**PJSIP** on **Asterisk 22.10.0**, exactly like the book.

Work through the labs in order. Each one is self-contained, takes 10–30 minutes, and ends with
a checkpoint you can see or hear. If something breaks, every lab has a Troubleshooting table.

---

## Lab Credentials & Quick Reference  *(keep this page open)*

Everything you need to log in, anywhere in this manual, is here. You will not have to invent a
single username or password.

### Softphone accounts (your PBX, created by the lab)

**Get the softphone:** download the **SipPulse Softphone** from
<https://www.sippulse.com/produtos/softphone> (Windows/macOS/Linux), or use the no-install
browser version at <https://softphone.sippulse.com.br/crosscall/>.

| Account | Password | What it is |
|--------:|----------|------------|
| `6001` | `Lab-6001-secret` | Desk phone "Alice" |
| `6002` | `Lab-6002-secret` | Desk phone "Bob" |
| `webrtc-1000` | `Lab-webrtc-secret` | Browser phone (Lab 6) |

- **SIP server / domain:** your own computer — **`127.0.0.1`** (or your machine's LAN IP if the
  softphone runs on a different device), **UDP port 5060**.
- **Transport:** UDP. **Codecs:** μ-law (PCMU), A-law (PCMA).

### SIP trunk (shared lab provider — for Lab 5)

| Setting | Value |
|---------|-------|
| Provider host | `sip.flagonc.com` |
| Port | **`5600`** (not 5060) |
| Account (pick one) | `1010`–`1050` |
| Password | `supersecret` (same for every account) |
| Provider echo test | dial `*98` over the trunk (free) |

> Pick **any one** account in `1010`–`1050` — they all share the password `supersecret`. So your
> account doesn't clash with another student's, use the number your instructor assigns you. This
> manual's worked example uses **`1020`**.

### Services you will switch on later

| Service | Where | Login |
|---------|-------|-------|
| Voicemail PIN (Lab 3) | dial `*97` | mailbox `6001`/`6002`, PIN `1234` |
| ARI REST API (Lab 8) | `http://localhost:8088/ari` | `labuser` / `Lab-ari-secret` |
| WebRTC signaling (Lab 6) | `wss://localhost:8089/ws` | account `webrtc-1000` |

### The two commands you will use constantly

```bash
# 1) Run any Asterisk CLI command from your normal shell (Terminal or PowerShell):
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show endpoints'

# 2) Open a live, interactive Asterisk console (Ctrl-C to leave):
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rvvv
```

Throughout this manual, **"run in the Asterisk CLI"** means form (1) or typing the command at
the `*CLI>` prompt of form (2). **"Edit a file"** always means a file under
`lab/asterisk/etc/` on your computer — save it, then reload as the lab tells you.

---

## Lab 0 — Set up the lab on your computer

> **You will:** get the Asterisk 22 lab running on Windows, macOS, or Linux and place your
> first registration.
> **Time:** ~20 min   **Prerequisites:** none.

### Step 1 — Install Docker

You need Docker with the `docker compose` command.

- **Windows 10/11:** install **Docker Desktop** from <https://www.docker.com/products/docker-desktop/>.
  Accept the WSL 2 backend when prompted, then reboot. Launch Docker Desktop and wait for the
  whale icon to say *"Engine running."*
- **macOS (Intel or Apple Silicon):** install **Docker Desktop** from the same page and launch
  it. (OrbStack also works.)
- **Linux:** install **Docker Engine** + the compose plugin —
  `sudo apt-get install docker.io docker-compose-plugin` (Debian/Ubuntu) or follow
  <https://docs.docker.com/engine/install/>. Add yourself to the `docker` group
  (`sudo usermod -aG docker $USER`) and log out/in.

Confirm it works — in **Terminal** (macOS/Linux) or **PowerShell** (Windows):

```bash
docker --version
docker compose version
```

You should see a Docker version `24.x` or newer and a Compose `v2.x` line.

### Step 2 — Get the lab files

Clone the repository (install Git first if needed), then move into it:

```bash
git clone https://github.com/flaviogoncalves/asterisk-guide.git
cd asterisk-guide
```

> No Git? Download the repo's ZIP from GitHub ("Code → Download ZIP"), unzip it, and `cd` into
> the unzipped folder. On Windows, **use VS Code or another editor — not Notepad —** to edit
> config files later, so line endings stay correct.

### Step 3 — Start the lab

```bash
docker compose -f lab/docker-compose.yml up -d --build
```

The first run downloads and compiles Asterisk 22.10.0 from source, so it can take several
minutes. When it finishes, check it is healthy:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'core show version'
```

**You should see:**

```
Asterisk 22.10.0 built by root @ ... running Linux
```

### Step 4 — Look at what is already configured

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show endpoints'
```

**You should see** four endpoints — `6001`, `6002`, `sipp`, `webrtc-1000` — all
`Unavailable` (no phone has registered *yet*):

```
 Endpoint:  6001                                                 Unavailable   0 of inf
     InAuth:  6001/6001
        Aor:  6001                                               1
 Endpoint:  6002                                                 Unavailable   0 of inf
...
Objects found: 4
```

### Step 5 — Install a softphone and register `6001`

Download the **SipPulse Softphone** for Windows, macOS, or Linux from
<https://www.sippulse.com/produtos/softphone> (or, to skip installing, use the browser version
at <https://softphone.sippulse.com.br/crosscall/>). Then create an account with the credentials
from the front page:

| Field | Value |
|-------|-------|
| Username / Auth user | `6001` |
| Password | `Lab-6001-secret` |
| Domain / SIP server | `127.0.0.1` (same computer) — or your machine's LAN IP |
| Port | `5060`, transport **UDP** |

Save and let it register. Now re-check from the Asterisk CLI:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show endpoint 6001'
```

### ✅ Checkpoint

`pjsip show endpoint 6001` reports the endpoint **`Not in use`** (instead of `Unavailable`) and
lists a **Contact** with a `sip:` URI from your phone. Your softphone shows *Registered* /
*Online*. The lab is alive.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Softphone never registers | Wrong domain/port, or firewall | Use `127.0.0.1:5060` UDP if the phone is on the same computer; allow Docker through the firewall when Windows/macOS prompts. |
| `endpoint ... Unavailable` still | Phone not actually registered | Re-check username `6001` and password `Lab-6001-secret` exactly; watch `pjsip set logger on` for a `401`. |
| `port is already allocated` on `up` | Something else uses 5060/8088/8089 | Stop the other SIP app, or edit the host-side ports in `lab/docker-compose.yml`. |

### Clean up

Leave the lab running for the next labs. To stop it later:
`docker compose -f lab/docker-compose.yml down`.

---

## Lab 1 — Your first calls

> **You will:** call between two softphones and run the classic echo test.
> **Time:** ~15 min   **Prerequisites:** Lab 0. Register **both** `6001` and `6002` (use a
> second softphone, a second device, or a second profile).
> **Book chapter:** *Building Your First PBX*.

### Step 1 — See the dialplan you already have

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'dialplan show internal'
```

**You should see** the `internal` context with extensions `600`, `6001`, `6002`, `9000`,
`1000`:

```
  '600' =>          1. Answer()
                    2. Playback(demo-echotest)
                    3. Echo()
                    4. Hangup()
  '6001' =>         1. Dial(PJSIP/6001,20)
  '6002' =>         1. Dial(PJSIP/6002,20)
-= 5 extensions (11 priorities) in 1 context. =-
```

### Step 2 — Call phone to phone

From the softphone registered as `6001`, dial **`6002`**. The other phone rings; answer it and
talk. Then hang up and call the other way.

While a call is up, watch it live:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'core show channels'
```

You will see two `PJSIP/…` channels bridged together.

### Step 3 — Run the echo test

From either phone, dial **`600`**. Asterisk answers, plays a short prompt, then echoes your
microphone back to your ear with a tiny delay. This is the fastest way to prove two-way audio
(RTP) is flowing.

### ✅ Checkpoint

You can hold a two-way conversation between `6001` and `6002`, and dialling `600` plays your
own voice back. If `600` is silent in one direction, your RTP/audio path has a NAT or firewall
problem — see the table.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Phone rings but no audio | RTP blocked | Make sure the lab's `10000-10100/udp` ports aren't blocked by your firewall; keep both phones on the same machine for the simplest path. |
| "All circuits are busy" / 404 | Dialled an unknown extension | Only `600`, `6001`, `6002`, `9000`, `1000` exist until you add more. |
| Calls drop after 20 s on no-answer | `Dial(...,20)` timeout | Expected — answer within 20 seconds. |

### Clean up

Nothing to undo — you only placed calls.

---

## Lab 2 — A dial plan with an auto-attendant (IVR)

> **You will:** build a small voice menu: "Press 1 for Alice, 2 for Bob, 0 for the echo test."
> **Time:** ~20 min   **Prerequisites:** Lab 1.
> **Book chapter:** *Building an Interactive Dial Plan*.

### Step 1 — Add an IVR context

Open `lab/asterisk/etc/extensions.conf` in your editor and add this new context at the bottom:

```ini
[ivr]
exten => start,1,Answer()
 same  =>       n,Wait(1)
 same  =>       n(menu),Background(demo-instruct)   ; play the menu, listen for a digit
 same  =>       n,WaitExten(5)                      ; wait 5s for the caller to press a key

exten => 1,1,Dial(PJSIP/6001,20)
exten => 2,1,Dial(PJSIP/6002,20)
exten => 0,1,Goto(internal,600,1)                   ; echo test
exten => i,1,Playback(pbx-invalid)                  ; invalid key
 same  =>  n,Goto(ivr,start,menu)
exten => t,1,Playback(vm-goodbye)                   ; timed out
 same  =>  n,Hangup()
```

### Step 2 — Give your phones a way to reach the menu

Still in `extensions.conf`, add one line to the existing `[internal]` context so dialling
**`500`** enters the IVR:

```ini
exten => 500,1,Goto(ivr,start,1)
```

### Step 3 — Reload and verify

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'dialplan reload'
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'dialplan show ivr'
```

**You should see** the `ivr` context with `start`, `1`, `2`, `0`, `i`, `t`.

### Step 4 — Try it

From `6001`, dial **`500`**. Listen to the prompt, then press **`2`** — phone `6002` rings.
Hang up, dial `500` again, and press **`0`** for the echo test. Press a wrong key (e.g. `9`) to
hear the invalid-key handling.

### ✅ Checkpoint

Dialling `500` answers with a menu, and `1`/`2`/`0` route the call as configured; a bad key
re-plays the menu.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `dialplan reload` shows no `ivr` | Typo / unbalanced context | Re-check the `[ivr]` header and indentation; run the reload again and read for a parse error. |
| Key presses ignored | DTMF mode mismatch | The lab uses RFC 4733 DTMF by default; set the same in your softphone (often "RFC2833"). |
| "Invalid" every time | Prompt still playing | `Background` lets you dial *during* the prompt; wait a beat or press the key again. |

### Clean up

To return to the base dial plan, delete the `[ivr]` context and the `exten => 500` line you
added, then `dialplan reload`. (Or keep them — later labs don't conflict.)

---

## Lab 3 — Voicemail

> **You will:** send unanswered calls to voicemail and retrieve messages with `*97`.
> **Time:** ~20 min   **Prerequisites:** Lab 1.
> **Book chapter:** *Voicemail*.

### Step 1 — Create the mailboxes

Create a **new file** `lab/asterisk/etc/voicemail.conf` with two mailboxes (PIN `1234`):

```ini
[general]
format=wav49|gsm|wav
maxmsg=100

[default]
6001 => 1234,Alice Lab,alice@example.com
6002 => 1234,Bob Lab,bob@example.com
```

Reload and confirm:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'voicemail reload'
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'voicemail show users'
```

**You should see:**

```
Context    Mbox  User                      Zone       NewMsg
default    6001  Alice Lab                                 0
default    6002  Bob Lab                                   0
2 voicemail users configured.
```

### Step 2 — Send unanswered calls to voicemail

Edit `lab/asterisk/etc/extensions.conf`. Replace the two existing phone lines in `[internal]`:

```ini
exten => 6001,1,Dial(PJSIP/6001,20)
exten => 6002,1,Dial(PJSIP/6002,20)
```

with versions that fall through to voicemail when the call isn't answered in 20 seconds:

```ini
exten => 6001,1,Dial(PJSIP/6001,20)
 same  =>      n,VoiceMail(6001@default,u)
 same  =>      n,Hangup()
exten => 6002,1,Dial(PJSIP/6002,20)
 same  =>      n,VoiceMail(6002@default,u)
 same  =>      n,Hangup()
```

Add an extension to **check** your own messages:

```ini
exten => *97,1,VoiceMailMain(${CALLERID(num)}@default)
```

Reload: `docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'dialplan reload'`.

### Step 3 — Leave and retrieve a message

1. From `6001`, call `6002` and **don't answer**. After 20 s you hear the "please leave a
   message" prompt — record one and hang up.
2. From `6002`, dial **`*97`**, enter PIN **`1234`**, and follow the prompts to hear the
   message.

### ✅ Checkpoint

`voicemail show users` shows `NewMsg` `1` for `6002` after you leave a message, and `*97` plays
it back.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| No "leave a message" prompt | Dialplan not reloaded, or call answered | Reload, and make sure the called phone truly rings out (don't pick up). |
| `*97` asks for a mailbox number | Caller ID not set to `6001`/`6002` | Enter the mailbox number manually, then PIN `1234`. |
| "Sorry, I can't let you do that" | Wrong PIN | The PIN is `1234`. |

### Clean up

Delete `voicemail.conf`, revert the `[internal]` phone lines, remove `*97`, then
`dialplan reload` and `voicemail reload`.

---

## Lab 4 — A call queue

> **You will:** put callers in a queue that rings both agents.
> **Time:** ~15 min   **Prerequisites:** Lab 1.
> **Book chapter:** *Queues and Call Centers*.

### Step 1 — Define the queue

Create a **new file** `lab/asterisk/etc/queues.conf`:

```ini
[general]

[support]
strategy=ringall
timeout=15
member => PJSIP/6001
member => PJSIP/6002
```

Reload and check:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'module reload app_queue.so'
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'queue show support'
```

**You should see:**

```
support has 0 calls (max unlimited) in 'ringall' strategy ...
   Members:
      PJSIP/6002 (ringinuse enabled) (Unavailable) has taken no calls yet ...
      PJSIP/6001 (ringinuse enabled) (Unavailable) has taken no calls yet ...
   No Callers
```

(Members read `Unavailable` until their softphones are registered.)

### Step 2 — Route a number into the queue

Add to `[internal]` in `extensions.conf`, then `dialplan reload`:

```ini
exten => 700,1,Answer()
 same  =>     n,Queue(support)
 same  =>     n,Hangup()
```

### Step 3 — Test

Register both `6001` and `6002`. From a third identity (or the WebRTC phone from Lab 6, or by
temporarily un-registering one agent), dial **`700`**. Both agents' phones ring; whoever
answers takes the call. Watch it:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'queue show support'
```

### ✅ Checkpoint

Dialling `700` rings the registered agents, and `queue show support` shows the caller in queue
then the answering agent's call count increment.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Members always `Unavailable` | Agents not registered | Register `6001`/`6002` first; re-run `queue show support`. |
| Caller hears silence | No agents available | Register at least one agent; `ringall` needs a reachable member. |

### Clean up

Delete `queues.conf` and the `exten => 700` block; `dialplan reload` and
`module reload app_queue.so`.

---

## Lab 5 — Connect a real SIP trunk

> **You will:** register your lab PBX to a real ITSP (`sip.flagonc.com`) and route calls over
> it.
> **Time:** ~25 min   **Prerequisites:** Lab 1. Internet access from the container.
> **Book chapter:** *SIP Trunking and DID*.
>
> *Lab sponsor:* this trunk lab is served by the shared provider on `sip.flagonc.com`.

### Step 1 — Add the trunk to PJSIP

Edit `lab/asterisk/etc/pjsip.conf` and append a trunk. **Use the account assigned to you**
(`1010`–`1050`); this example uses `1020`. Note the provider port is **`5600`**, and the
`from_user` line is what lets the provider recognize your outbound calls:

```ini
; ---- SIP trunk: sip.flagonc.com ----
[flagonc]
type=registration
outbound_auth=flagonc-auth
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999

[flagonc-auth]
type=auth
auth_type=userpass
username=1020
password=supersecret

[flagonc]
type=endpoint
context=from-pstn
transport=transport-udp
disallow=all
allow=ulaw
direct_media=no
outbound_auth=flagonc-auth
aors=flagonc
from_user=1020
from_domain=sip.flagonc.com

[flagonc]
type=aor
contact=sip:sip.flagonc.com:5600

[flagonc]
type=identify
endpoint=flagonc
match=sip.flagonc.com
```

### Step 2 — Reload and confirm registration

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'module reload res_pjsip.so'
# give it a few seconds, then:
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show registrations'
```

**You should see** `Status` **`Registered`**:

```
 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================
 flagonc/sip:1020@sip.flagonc.com:5600                   flagonc-auth                Registered        (exp. 3554s)
```

If it says **`Rejected`**, the account/password was refused (see Troubleshooting). If it stays
**`Unregistered`** for more than ~15 s, the provider didn't answer — check connectivity.

### Step 3 — Receive an inbound call (free, no charges)

Add a landing place for inbound calls. In `extensions.conf`, add a `from-pstn` context:

```ini
[from-pstn]
exten => 9999,1,NoOp(Inbound from trunk, caller ${CALLERID(num)})
 same  =>      n,Answer()
 same  =>      n,Playback(demo-congrats)
 same  =>      n,Goto(ivr,start,1)        ; hand off to your IVR from Lab 2 (optional)
exten => _.,1,Goto(9999,1)                ; catch any inbound number
```

Reload (`dialplan reload`). Now trigger an inbound call. Two ways:

- **Self-test (no second person):** once the outbound rule from Step 4 is in place, dial **your
  own trunk number** — e.g. from `6001` dial `1050` (your account). The call goes out to the
  provider, which routes it straight back to your registered phone as a genuine *inbound* call,
  landing in `from-pstn`.
- **From outside:** have a classmate dial your account number, or use the provider's web
  click-to-call.

Watch the inbound leg arrive — you'll see a `PJSIP/flagonc-…` channel in **`from-pstn`** answer
and play the prompt:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'core show channels'
```

```
PJSIP/flagonc-00000005   9999@from-pstn:3   Up   Playback(demo-congrats)
```

### Step 4 — Place an outbound call (free, over the trunk)

The provider hosts a **free echo test on `*98`** and lets accounts call each other, so you can
test outbound without any PSTN charges. Add an outbound rule to `[internal]`:

```ini
exten => 800,1,Dial(PJSIP/*98@flagonc,30)        ; provider echo test (free)
exten => _10XX,1,Dial(PJSIP/${EXTEN}@flagonc,30) ; ring another lab account (e.g. 1011)
exten => _20XX,1,Dial(PJSIP/${EXTEN}@flagonc,30) ; ring a 20xx lab account
```

`dialplan reload`, then from `6001` dial **`800`** — the call goes out over the trunk to the
provider's echo test and you hear yourself. Or dial another live account (e.g. `1011`) to ring a
classmate. Watch it go out:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'core show channels'
```

You'll see a `PJSIP/flagonc-…` channel reach **`Up`**.

### ✅ Checkpoint

`pjsip show registrations` reads **`Registered`**; dialling `800` reaches the provider's echo
test over the trunk (a `PJSIP/flagonc-…` channel goes `Up`); and dialling your own number (the
self-test above) comes back as an **inbound** `PJSIP/flagonc-…` channel in `from-pstn`.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Rejected` | Wrong password, or an account outside `1010`–`1050` | Confirm port `5600`, password `supersecret`, and an account in `1010`–`1050`. A `403 Forbidden` in `pjsip set logger on` means the credentials were refused (e.g. account `1001` doesn't exist). |
| Outbound `403 Forbidden` | Provider can't identify the caller | Make sure `from_user=<your account>` is on the `[flagonc]` endpoint — without it the provider rejects your INVITE. |
| `Unregistered`, never changes | No route to `sip.flagonc.com:5600` | From the container: `getent hosts sip.flagonc.com` should resolve; check your network/VPN/firewall allows outbound UDP. |
| Registered but inbound silent | One-way audio / NAT | Keep `direct_media=no` (already set); inbound media returns via Asterisk. |

### Clean up

Remove the `[flagonc*]` blocks from `pjsip.conf` and the `from-pstn`/`_9.` lines from
`extensions.conf`, then `module reload res_pjsip.so` and `dialplan reload`.

---

## Lab 6 — A WebRTC phone in the browser

> **You will:** register and call from a web browser with no softphone installed.
> **Time:** ~25 min   **Prerequisites:** Lab 0.
> **Book chapter:** *WebRTC*.

### Step 1 — Generate the WebRTC certificate

WebRTC requires TLS. Generate the lab's self-signed cert and restart Asterisk:

```bash
bash lab/make-certs.sh
docker compose -f lab/docker-compose.yml restart asterisk
```

(On Windows, run `bash lab/make-certs.sh` from **Git Bash** or **WSL**.)

### Step 2 — Serve the browser client

The lab ships a minimal WebRTC page at `lab/webrtc/index.html`. Serve it locally:

```bash
cd lab/webrtc
python3 -m http.server 8000
```

Open **`http://localhost:8000`** in Chrome or Edge.

### Step 3 — Trust the certificate

In a new tab, visit **`https://localhost:8089/ws`** and accept/proceed past the
self-signed-certificate warning once. This lets the browser open the secure WebSocket to
Asterisk.

### Step 4 — Register and call

In the WebRTC page, connect as **`webrtc-1000`** / **`Lab-webrtc-secret`**. Then:

- Dial **`600`** — the echo test; you should hear yourself in the browser.
- From the SipPulse Softphone registered as `6001`, dial **`1000`** — the browser rings.

Confirm the browser is registered:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show endpoint webrtc-1000'
```

### ✅ Checkpoint

The browser registers as `webrtc-1000`, the echo test plays your voice back, and `6001` can
ring the browser by dialling `1000`.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Browser won't connect to WSS | Cert not trusted | Visit `https://localhost:8089/ws` and accept the warning first. |
| Mic blocked | Browser permission | Allow microphone access for `localhost`; WebRTC needs a secure context. |
| `8089` refused | Cert not generated / Asterisk not restarted | Re-run `lab/make-certs.sh`, then restart the container. |

### Clean up

Stop the `python3 -m http.server` (Ctrl-C). The cert can stay; it's gitignored.

---

## Lab 7 — Secure your SIP with TLS and SRTP

> **You will:** offer encrypted signaling (TLS) and encrypted media (SRTP) to a phone.
> **Time:** ~20 min   **Prerequisites:** Lab 6 (certificate already generated).
> **Book chapter:** *Securing Asterisk*.

### Step 1 — Add a TLS transport

The lab's WebRTC transport already uses the cert from Lab 6. Add a SIP-over-TLS transport for
softphones. Append to `lab/asterisk/etc/pjsip.conf`:

```ini
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

You'll also need to publish port `5061`. Add `- "5061:5061/tcp"` under `ports:` in
`lab/docker-compose.yml`, then recreate the container:

```bash
docker compose -f lab/docker-compose.yml up -d
```

### Step 2 — Require encrypted media on an endpoint

Make `6001` use TLS + SRTP by adding `media_encryption` to it. The simplest way in the lab is to
append an override; in `pjsip.conf` set on the `6001` endpoint:

```ini
media_encryption=sdes
```

Reload: `docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'module reload res_pjsip.so'`.

### Step 3 — Point the softphone at TLS

In the SipPulse Softphone account for `6001`, change the transport to **TLS**, port **`5061`**,
and accept the self-signed certificate. Re-register.

### Step 4 — Verify encryption

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show endpoint 6001'
```

Place a call to `600` and confirm in `pjsip set logger on` that signaling is over TLS and the
SDP offers `RTP/SAVP` (SRTP).

### ✅ Checkpoint

`6001` registers over **TLS/5061**, and a call to the echo test negotiates **SRTP** (`RTP/SAVP`
in the SDP). Audio still works end to end.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| TLS handshake fails | Cert not trusted by phone | Accept/import the self-signed cert in the softphone; for the lab, disable strict cert verification. |
| Registers on UDP not TLS | Phone still on 5060/UDP | Set transport TLS and port `5061` in the phone. |
| No audio with SRTP | One side not offering SRTP | Confirm `media_encryption=sdes` on the endpoint and SRTP enabled in the phone. |

### Clean up

Remove `[transport-tls]`, the `media_encryption` line, and the `5061` port mapping; recreate
the container and reload.

---

## Lab 8 — Control Asterisk with ARI

> **You will:** call the Asterisk REST Interface (ARI) and originate a call from a script.
> **Time:** ~20 min   **Prerequisites:** Lab 1.
> **Book chapter:** *The Asterisk REST Interface (ARI)*.

### Step 1 — Enable ARI

Create a **new file** `lab/asterisk/etc/ari.conf`:

```ini
[general]
enabled=yes

[labuser]
type=user
password=Lab-ari-secret
```

Reload ARI:

```bash
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'module reload res_ari.so'
```

(The lab already enables the HTTP server on `8088` and publishes it to your computer.)

### Step 2 — Query ARI from your computer

ARI is plain HTTP + JSON. From your normal shell:

```bash
curl -s -u labuser:Lab-ari-secret http://localhost:8088/ari/asterisk/info
```

**You should see** JSON describing the running system — note `"version":"22.10.0"`:

```json
{"build":{"os":"Linux", ... ,"date":"2026-06-19 00:12:19 UTC","user":"root"},
 "system":{"version":"22.10.0","entity_id":"..."},
 "config":{"name":"","default_language":"en", ...},
 "status":{"startup_time":"...","last_reload_time":"..."}}
```

> On Windows, `curl` ships with Windows 10/11; in PowerShell use `curl.exe` (with the `.exe`) so
> you get real curl and not the PowerShell alias.

### Step 3 — List your endpoints over ARI

```bash
curl -s -u labuser:Lab-ari-secret http://localhost:8088/ari/endpoints
```

You'll get a JSON array of your PJSIP endpoints (`6001`, `6002`, …) with their states.

### Step 4 — Originate a call from the API

Make Asterisk ring `6001` and drop it into the echo test — no dialplan trigger, driven entirely
by the REST call:

```bash
curl -s -u labuser:Lab-ari-secret -X POST \
  "http://localhost:8088/ari/channels?endpoint=PJSIP/6001&extension=600&context=internal&priority=1&callerId=ARI"
```

Your `6001` softphone rings; answer it and you're in the echo test.

### ✅ Checkpoint

`/ari/asterisk/info` returns `22.10.0`, `/ari/endpoints` lists your phones, and the originate
POST makes `6001` ring.

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `401 Unauthorized` | Wrong ARI credentials | Use `labuser` / `Lab-ari-secret` exactly; confirm `ari.conf` reloaded. |
| `curl: connection refused` | 8088 not reachable | Ensure the lab was recreated after the compose change (`up -d`); ARI is on `localhost:8088`. |
| Originate returns 4xx | Endpoint offline | Register `6001` first; check the JSON error message. |

### Clean up

Delete `ari.conf` and `module reload res_ari.so`.

---

## Appendix A — Everyday lab commands

```bash
# Start / stop / rebuild
docker compose -f lab/docker-compose.yml up -d          # start (or apply compose changes)
docker compose -f lab/docker-compose.yml down           # stop and remove
docker compose -f lab/docker-compose.yml restart asterisk

# Live console and one-shot commands
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rvvv
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'pjsip show endpoints'
docker compose -f lab/docker-compose.yml exec asterisk asterisk -rx 'core show channels'

# Reloads (narrowest that works)
... -rx 'dialplan reload'            # extensions.conf
... -rx 'module reload res_pjsip.so' # pjsip.conf
... -rx 'voicemail reload'           # voicemail.conf
... -rx 'module reload app_queue.so' # queues.conf
... -rx 'module reload res_ari.so'   # ari.conf

# See SIP on the wire
... -rx 'pjsip set logger on'        # ... 'pjsip set logger off'

# Tail the logs
docker compose -f lab/docker-compose.yml logs -f asterisk
```

## Appendix B — Editing config files safely

- All config lives under **`lab/asterisk/etc/`** on your computer. The folder is mounted into
  the container, so your edits appear instantly — you only need to *reload*.
- On **Windows**, edit with **VS Code** (or any editor that keeps **LF** line endings). Notepad
  may insert Windows line endings that confuse Asterisk.
- After every edit, run the matching reload from Appendix A and read its output for parse
  errors.
- To get back to a clean slate at any time:
  `git checkout -- lab/asterisk/etc/` then `docker compose -f lab/docker-compose.yml restart asterisk`.

## Appendix C — Resetting everything

```bash
docker compose -f lab/docker-compose.yml down
git checkout -- lab/asterisk/etc/        # discard your config edits
docker compose -f lab/docker-compose.yml up -d --build
```

---

*Asterisk Guide — Hands-On Lab Manual. Asterisk 22.10.0, PJSIP-only, hardware-free. Every
command in this manual was verified against the lab. Licensed CC BY-NC-SA 4.0.*
