# Lab 2 Part II: Register Softphones and Make Your First Call

**Time:** ~35 minutes
**Prerequisites:** Lab 2 Part I — `pjsip show endpoints` lists `6001` and `6002`, both `Unavailable`.

Two endpoints exist and no telephone has ever contacted them. Now you bring the phones.

By the end of this lab a call will cross your PBX and you will have watched, packet by
packet, how the phone proved who it was.

---

## Step 1 — What you need

You need **two** phones, because one phone cannot demonstrate a call. Options:

| Your computer | Softphone | Notes |
|---|---|---|
| Windows | **MicroSIP** — <https://www.microsip.org> | Small, free, no account required. Run two copies for two extensions. |
| macOS / Linux | **Linphone** — <https://www.linphone.org> | Free, handles multiple accounts in one app. |
| Linux, or you like the terminal | **baresip** — `sudo apt install baresip` | Command-line. Excellent for seeing exactly what SIP is doing. |

You can also use a real desk phone — it is on the same network as the lab now, so it
will work. And your mobile: Linphone and Zoiper both have free apps, and your phone is
on the same wifi.

> **Two extensions, two phones.** The simplest arrangement is your computer running two
> softphone instances. Second simplest is your computer plus your mobile.

**Get your lab's address** — on the VM:

```bash
lab ip
```

Everywhere below that says `<your-lab-ip>`, use that number.

---

## Step 2 — Watch what happens, as it happens

Before you register anything, turn on SIP logging. This is the single most useful thing
in Asterisk and most people meet it far too late.

On the VM, open the console:

```bash
sudo asterisk -rvvv
```

At the `*CLI>` prompt:

```
pjsip set logger on
```

Leave this window open and visible. Every SIP packet in and out now prints here.

---

## Step 3 — Register 6001

In your softphone, create an account:

| Field | Value |
|-------|-------|
| Username / Auth user | `6001` |
| Password | `Lab-6001-secret` |
| Domain / SIP server / Registrar | `<your-lab-ip>` |
| Port | `5060` |
| Transport | **UDP** |

*baresip users:* create `~/.baresip/accounts` containing one line —
`<sip:6001@<your-lab-ip>>;auth_pass=Lab-6001-secret;transport=udp` — then run `baresip`.

Save it, and watch the CLI window.

**You should see** something close to this — and it is worth reading properly, because
this exchange is the whole of SIP authentication:

```
<--- Received SIP request (....) from udp:192.168.1.20:5060 --->
REGISTER sip:192.168.1.47 SIP/2.0
...
<--- Transmitting SIP response (....) to udp:192.168.1.20:5060 --->
SIP/2.0 401 Unauthorized
...
WWW-Authenticate: Digest realm="asterisk",nonce="1a2b3c..."

<--- Received SIP request (....) from udp:192.168.1.20:5060 --->
REGISTER sip:192.168.1.47 SIP/2.0
...
Authorization: Digest username="6001",realm="asterisk",nonce="1a2b3c...",response="9f8e7d..."

<--- Transmitting SIP response (....) to udp:192.168.1.20:5060 --->
SIP/2.0 200 OK
```

**What just happened, and why it matters:**

1. The phone said "I am 6001" — with **no password**.
2. Asterisk replied **401 Unauthorized** with a `nonce`: a one-time random value.
3. The phone hashed its password together with that nonce and sent the result.
4. Asterisk did the same hash and compared. They matched, so: **200 OK**.

The password itself never crossed the network — only a hash of it, salted with a value
that will never be used again. That is digest authentication, and it is why the first
REGISTER is *supposed* to fail. When you see a 401 in a log, your first thought should
be "normal", not "broken".

Now confirm from the PBX's own point of view:

```
pjsip show endpoint 6001
```

**You should see** the state change from `Unavailable` to **`Not in use`**, and a new
line:

```
      Contact:  6001/sip:6001@192.168.1.20:5060      Avail
```

That contact is what the AOR is for. Asterisk now knows *where* 6001 is. Before this it
knew only that 6001 was allowed to exist.

> `Not in use` means "registered, and idle". You will see `In use` during a call. The
> word "Available" appears against the *contact*, not the endpoint — two different
> things that both mean roughly "alive".

---

## Step 4 — Register 6002

Same again on your second phone, with `6002` / `Lab-6002-secret`.

```
pjsip show endpoints
```

**You should see** both `Not in use`.

```
pjsip show aors
```

**You should see** each AOR with one contact now — the column that was empty at the end
of Part I.

Turn the logger off; it has done its job and it is noisy:

```
pjsip set logger off
```

---

## Step 5 — Give them somewhere to call

Both phones are registered and **neither can call anything**. A registered phone with no
dialplan is a phone that can only be called, never dial.

Remember `context=internal` on each endpoint in Part I? That is the name of the part of
the dialplan those phones enter. It does not exist yet. Create it.

Move the sample dialplan aside and start clean:

```bash
sudo mv /etc/asterisk/extensions.conf /etc/asterisk/extensions.conf.sample
sudo nano /etc/asterisk/extensions.conf
```

Type in:

```ini
[internal]

; phone to phone
exten => 6001,1,Dial(PJSIP/6001,20)
 same => n,Hangup()

exten => 6002,1,Dial(PJSIP/6002,20)
 same => n,Hangup()

; echo test — proves audio works in both directions
exten => 600,1,Answer()
 same => n,Playback(demo-echotest)
 same => n,Echo()
 same => n,Playback(demo-echodone)
 same => n,Hangup()
```

How to read `exten => 6001,1,Dial(PJSIP/6001,20)`:

| Part | Meaning |
|---|---|
| `exten =>` | this line defines a dialable number |
| `6001` | the digits the caller dialled |
| `1` | priority — the first step. `same => n` means "next step" |
| `Dial(PJSIP/6001,20)` | call the PJSIP endpoint named `6001`, ring for 20 seconds |

The number dialled and the endpoint called happen to share the name `6001` here, and
that trips people up. They are unrelated: the left `6001` is *what the caller typed*,
the right one is *which phone to ring*. You could dial `7` and ring `PJSIP/6001`.

Load it:

```bash
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'dialplan show internal'
```

**You should see** all three extensions listed, with `600` showing four priorities.

---

## Step 6 — The echo test first

Always prove audio before you blame anything else.

**From phone 6001, dial `600`.**

**You should hear** a short recorded message, then your own voice back with a delay.
Talk and listen.

That one test proves: the phone can signal to Asterisk, Asterisk can answer, media
flows out, and media flows back. Almost everything that breaks in VoIP breaks one of
those four.

> **Silence?** The most likely cause is that the sound packages were not selected during
> `make menuselect` in Lab 1. Check with `ls /var/lib/asterisk/sounds/en/ | head`. If it
> is empty, go back to Lab 1 Step 3 and enable `CORE-SOUNDS-EN-ULAW`, then
> `sudo make install` again.

---

## Step 7 — Your first real call

**From phone 6001, dial `6002`.**

Phone 6002 should ring. Answer it. Talk.

Watch it in the CLI while it is up:

```bash
sudo asterisk -rx 'core show channels'
```

**You should see** two channels — one per phone — and `1 active call`. A call is always
two channels in Asterisk: the leg that came in, and the leg it went out on. That model
will make sense of queues, transfers and everything else later.

Hang up, and look at what was recorded:

```bash
sudo tail -3 /var/log/asterisk/cdr-csv/Master.csv
```

**You should see** a call detail record: who called whom, when, for how long, and
`ANSWERED`. Every call your PBX handles leaves one of these. You will send them to a
database in the Programmability section.

---

## ✅ Checkpoint

You have finished this lab when all four are true:

1. `pjsip show endpoints` shows `6001` and `6002` both **`Not in use`**
2. `pjsip show aors` shows a contact for each
3. Dialling `600` gives you **your own voice back**
4. **6001 rings 6002, you answer, and you can hear each other** — and a CDR records it

You now have a working two-extension PBX that you configured from an empty file.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Phone never registers, nothing in the SIP log | Packets are not arriving | From your computer: `ping <your-lab-ip>`. No reply → on a VM, Adapter 1 is not Bridged (Lab 0 Step 3); on a cloud server, your public address has changed and the provider firewall no longer allows it (Lab 0 Step C2). Reply but still nothing → a firewall on your computer is blocking outbound 5060/UDP, or the cloud firewall is missing the UDP 5060 rule. |
| Log shows REGISTER then repeated `401`, never `200` | Wrong password | It is case-sensitive: `Lab-6001-secret`. Also check the softphone's *auth user* is `6001` and not your name. |
| `403 Forbidden`, and it worked five minutes ago | **A stale contact is still bound.** Your endpoint has `max_contacts=1`, and the previous registration is still there — so the new one is refused. This happens whenever a softphone is force-quit or crashes instead of unregistering cleanly. | `sudo asterisk -rx 'pjsip show contacts'`. If you see a contact you no longer have a phone for, remove it: `sudo asterisk -rx 'pjsip show aors'` to confirm, then either wait for it to expire, or raise `max_contacts=2` on the AOR while you are experimenting. |
| `403 Forbidden` on a first-ever registration | Username does not match any endpoint | `pjsip show endpoints` — is it really `6001`? Check for a trailing space in the config. |
| Registers, then drops after ~30s | Registration expiry not being refreshed | Usually a NAT device between phone and VM. On one LAN there should be none — check the phone is on the same network, not a guest wifi. |
| `Not in use` on both, but dialling gives "not in service" | Dialplan not loaded, or wrong context | `dialplan show internal`. If empty, the reload failed — `sudo tail -20 /var/log/asterisk/messages.log`. Confirm each endpoint says `context=internal`. |
| Phone rings, answered, but **silence both ways** | Media not flowing | `sudo asterisk -rx 'rtp set debug on'` and place another call. No RTP at all → firewall. RTP one way → check the phone's own audio device settings. |
| Silence **one way only** | Nearly always the phone, on a flat LAN | Test the other phone against `600`. The one that fails the echo test is the broken one. |
| You have lost track | — | `sudo lab reset`, then redo from Part I Step 3. |

---

## Two commands to keep

```bash
sudo asterisk -rx 'pjsip show endpoints'    # who is registered
sudo asterisk -rx 'pjsip set logger on'     # what is actually being said
```

Between them they answer most "the phone isn't working" questions before you have
finished reading the ticket.

---

**Next:** Lab 3 — you connect this PBX to the outside world with a SIP trunk, and
make a call that leaves your network.
