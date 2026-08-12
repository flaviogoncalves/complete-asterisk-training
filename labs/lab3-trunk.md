# Lab 3: Connect a SIP Trunk

**Time:** ~30 minutes
**Prerequisites:** Lab 2 Part II — `6001` and `6002` are registered and can call each other.
**You also need:** your assigned trunk account number, between `1010` and `1050`.

Your PBX can call itself. That is not yet a telephone system.

In this lab you connect it to a SIP trunk — a gateway that stands in for the public
telephone network — so calls can leave your network and arrive from outside it.

---

## Step 1 — The idea that trips everyone up

In Part II, phones registered **to** your PBX. Now your PBX registers **to** somebody
else. Same protocol, opposite direction, and the configuration reflects that:

| | Phone → your PBX (Part II) | Your PBX → the gateway (now) |
|---|---|---|
| Who proves who they are | the phone, to you | you, to the gateway |
| Object that does it | `type=auth` + `auth=` | `type=auth` + **`outbound_auth=`** |
| Who initiates REGISTER | the phone | **you**, via `type=registration` |
| Where the AOR points | wherever the phone turns up | a **fixed address** — the gateway |

`auth=` means "challenge them with this". `outbound_auth=` means "answer their challenge
with this". Using the wrong one is the single most common trunk mistake, and it fails
with a confusing `401` loop rather than a clear error.

**Your gateway:**

| Setting | Value |
|---|---|
| Host | `sip.flagonc.com` |
| Port | **`5600`** — not 5060 |
| Account | your assigned number in `1010`–`1050` |
| Password | `supersecret` |
| Free echo test | `*98` |

> Everyone on this course shares this gateway, so **use the account you were assigned**.
> Two students on the same number will fight over the registration and both will see it
> flapping between `Registered` and `Unregistered`. The examples below use `1020` —
> replace every `1020` with your own number.

---

## Step 2 — Define the trunk

Append to `/etc/asterisk/pjsip.conf`:

```ini
;=============================== PSTN gateway ============================
[pstn]
type=endpoint
context=from-pstn
transport=transport-udp
disallow=all
allow=ulaw
allow=alaw
direct_media=no
outbound_auth=pstn
aors=pstn
from_user=1020

[pstn]
type=aor
contact=sip:sip.flagonc.com:5600

[pstn]
type=auth
auth_type=userpass
username=1020
password=supersecret

[pstn]
type=registration
transport=transport-udp
outbound_auth=pstn
server_uri=sip:sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com:5600
contact_user=1020
retry_interval=60

[pstn]
type=identify
endpoint=pstn
match=sip.flagonc.com
```

Six objects, and each is doing a job:

| Object | Job |
|---|---|
| `endpoint` | How to talk to the gateway, and — critically — **which context its calls land in**. |
| `aor` | Where the gateway is. Fixed, because a gateway does not move. |
| `auth` | Your credentials, used **outbound** only. |
| `registration` | Tells Asterisk to actively register to them, and to keep retrying. |
| `identify` | Matches inbound calls to this endpoint **by source address** instead of by the `From` header — which anyone can forge. |

Two lines deserve special attention:

- **`from_user=1020`** — what the gateway sees as the caller. Without it your outbound
  INVITEs go out as `6001`, which means nothing to them, and you get `403 Forbidden`.
- **`context=from-pstn`** — calls arriving from the gateway enter `from-pstn`, **never
  `internal`**. Step 5 explains why that one word is the most important security setting
  in this lab.

---

## Step 3 — Register, and watch it happen

```bash
sudo asterisk -rvvv
```

At the CLI:

```
pjsip set logger on
module reload res_pjsip.so
```

**You should see** your PBX send a REGISTER *outward*, get challenged, and answer:

```
<--- Transmitting SIP request (....) to udp:74.50.97.11:5600 --->
REGISTER sip:sip.flagonc.com:5600 SIP/2.0
...
<--- Received SIP response (....) from udp:74.50.97.11:5600 --->
SIP/2.0 401 Unauthorized
...
<--- Transmitting SIP request (....) to udp:74.50.97.11:5600 --->
REGISTER sip:sip.flagonc.com:5600 SIP/2.0
Authorization: Digest username="1020",...
...
<--- Received SIP response (....) from udp:74.50.97.11:5600 --->
SIP/2.0 200 OK
```

The same 401-then-authenticate dance as Part II, with you on the other side of it.

Confirm:

```
pjsip show registrations
```

**You should see:**

```
 <Registration/ServerURI................................>  <Auth..........>  <Status.......>
 pstn/sip:sip.flagonc.com:5600                             pstn              Registered
Objects found: 1
```

And look at the AOR:

```
pjsip show aors
```

**You should see** the `pstn` AOR with its contact and the status **`NonQual`** —
"not qualified". That is correct here and it is worth understanding.

`qualify` works by sending a SIP `OPTIONS` request every so often and timing the reply,
which is how a PBX notices a dead trunk before a customer does. **This gateway does not
answer OPTIONS**, so switching qualify on would leave the contact permanently reading
`Unavailable` — a trunk that registers, carries calls perfectly, and looks broken.

So this AOR has no `qualify_frequency`, and `NonQual` is the expected state. On a
provider that does answer OPTIONS, add `qualify_frequency=60` and watch for `Avail`
instead. Check before you assume: not every carrier responds.

```
pjsip set logger off
```

---

## Step 4 — Call out

Add to the `[internal]` context in `/etc/asterisk/extensions.conf`:

```ini
; --- outbound over the PSTN gateway ---
exten => 800,1,NoOp(Outbound to the gateway echo test)
 same => n,Dial(PJSIP/*98@pstn,30)
 same => n,Hangup()

; ring another student's lab, e.g. 1011
exten => _10XX,1,NoOp(Outbound to lab account ${EXTEN})
 same => n,Dial(PJSIP/${EXTEN}@pstn,30)
 same => n,Hangup()
```

`Dial(PJSIP/*98@pstn,30)` reads as: **call `*98`, via the endpoint named `pstn`**. The
part after `@` selects which trunk — with two providers you would have two names here,
and that is how least-cost routing starts.

```bash
sudo asterisk -rx 'dialplan reload'
```

**From phone 6001, dial `800`.**

**You should hear** the gateway's echo test — your own voice, having travelled out of
your network and back.

While it is up:

```bash
sudo asterisk -rx 'core show channels'
```

**You should see two channels**: `PJSIP/6001-...` and `PJSIP/pstn-...`. Your phone's leg,
and the trunk's leg. Asterisk is bridging them.

> **`403 Forbidden`?** Almost always a missing or wrong `from_user`. Turn the logger on,
> place the call again, and read the `From:` header your PBX sent — it must contain your
> assigned account number.

---

## Step 5 — Take a call in, safely

Now the other direction. Calls from the gateway arrive in `from-pstn`, a context that
does not exist yet.

**Before you write it, understand what it is for.** Your `internal` context can dial
`_10XX` — out through the trunk, to the real world. If inbound calls landed in
`internal`, anyone who could reach your PBX from outside could dial straight back out
through it, on your account. That is toll fraud, and it is not theoretical: attackers
scan for exactly this and can run up thousands in international calls overnight.

So `from-pstn` gets the absolute minimum it needs, and no route to the outside.

Add at the end of `/etc/asterisk/extensions.conf`:

```ini
;===========================================================================
; from-pstn — calls arriving from the gateway
;===========================================================================
; This context deliberately cannot dial out. Do not add an outbound rule here,
; and never use `include => internal`.
[from-pstn]

exten => 1020,1,NoOp(Inbound from PSTN: ${CALLERID(num)} -> ${EXTEN})
 same => n,Answer()
 same => n,Playback(demo-congrats)
 same => n,Dial(PJSIP/6001,20)
 same => n,Hangup()

; anything else the gateway sends us
exten => _X.,1,NoOp(Inbound to unknown number ${EXTEN})
 same => n,Answer()
 same => n,Playback(demo-congrats)
 same => n,Hangup()
```

Use **your** account number in place of `1020`.

> **`_X.` and not `_.`** — the difference is not cosmetic. `_.` matches *one or more of
> anything*, which includes Asterisk's own special extensions: `s` (start), `i`
> (invalid), `t` (timeout) and `h` (hangup). A catch-all written `_.` swallows those, so
> the context can never handle a timeout or a hangup properly. Asterisk warns about it on
> every reload:
>
> ```
> WARNING pbx_config.c: The use of '_.' for an extension is strongly discouraged
> and can have unexpected behavior.  Please use '_X.' instead
> ```
>
> `_X.` means "a digit, then one or more of anything" — every real phone number, and none
> of the special names.

```bash
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'dialplan show from-pstn'
```

**You should see** both entries.

### Test it

**From phone 6002, dial your own trunk number** — `1020`, or whatever yours is.

The call goes out through the gateway, the gateway routes it straight back to you, and
it arrives as a genuine inbound call. You should hear the congratulations prompt, then
phone `6001` rings.

Watch both legs:

```bash
sudo asterisk -rx 'core show channels'
```

**You should see** an inbound `PJSIP/pstn-...` channel sitting in `from-pstn`.

---

## ✅ Checkpoint

You have finished this lab when all four are true:

1. `pjsip show registrations` reads **`Registered`**
2. `pjsip show aors` shows the `pstn` contact as **`NonQual`** — and you can say why
3. Dialling **`800`** reaches the gateway echo test and you hear yourself
4. Dialling **your own trunk number** comes back in as an inbound call in `from-pstn`

And one you should be able to answer out loud: **why must `from-pstn` not be allowed to
dial out?**

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Rejected` | Wrong credentials, or an account outside `1010`–`1050` | Password is `supersecret`, port is **5600** not 5060. `pjsip set logger on` and look at the failure. |
| Stuck `Unregistered` | Cannot reach the gateway | On the VM: `getent hosts sip.flagonc.com` should resolve. Then check outbound UDP is not blocked — a corporate firewall or VPN is the usual culprit. |
| Registered, then flapping | Someone else is using your account number | Use the number you were assigned. Two registrations for one account fight and both lose. |
| AOR shows `Unavailable` | You added `qualify_frequency` and the gateway ignores OPTIONS | Remove it. `Unavailable` here means "did not answer a keepalive", not "unreachable" — the trunk still carries calls. |
| Outbound `403 Forbidden` | Gateway cannot identify you | `from_user=` on the `[pstn]` endpoint must be your account number. |
| Outbound rings, then silence | No media path | `sudo asterisk -rx 'rtp set debug on'` during the call. Confirm `direct_media=no` is present — without it Asterisk tries to hand media directly between phone and gateway, which will not work from a private network. |
| Inbound never arrives | Gateway is not matching you to the endpoint | `pjsip show identifies` — the `pstn` identify must be listed. If the gateway's IP changed, `match=sip.flagonc.com` re-resolves on reload. |
| Inbound arrives but drops instantly | It landed in a context with no matching extension | `sudo asterisk -rvvv` during the call and read the context and extension it reports. Add it to `from-pstn`. |

---

## What you have now

```
   6001 ──┐
          ├── [internal] ──► Dial(PJSIP/*98@pstn) ──┐
   6002 ──┘                                          │
                                                     ▼
                                          sip.flagonc.com:5600
                                                     │
          [from-pstn] ◄── inbound ────────────────────┘
             │
             └── Answer, greet, ring 6001
                 (and deliberately nothing else)
```

---

**Next:** Lab 4 — the dialplan itself. Pattern matching, call routing, and making the
`internal` context do something more interesting than one line per phone.
