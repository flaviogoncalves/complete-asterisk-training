# Lab 5: Voicemail, Transfers and a Call Queue

**Time:** ~50 minutes
**Prerequisites:** Lab 4 — you have the `features` / `outbound` / `internal` context chain, the `_60XX` pattern, and a working IVR on `6000`.

Everything so far has been about getting a call from A to B. This lab is about what
happens when B does not answer, when B needs to hand the call to C, and when there are
more callers than people to take them.

These are the features people actually buy a PBX for.

Keep a CLI open throughout:

```bash
sudo asterisk -rvvv
```

---

## Step 1 — Voicemail

A call that rings out currently plays "the party you are calling is currently
unavailable" and hangs up. Give the caller somewhere to leave a message instead.

Edit `/etc/asterisk/voicemail.conf`. Find the `[default]` context near the bottom and add
two mailboxes:

```ini
[default]
6001 => 1234,Alice,alice@example.com
6002 => 1234,Bob,bob@example.com
```

The format is `mailbox => PIN,Full Name,email`. The PIN is what the user types to collect
messages — `1234` for both, because this is a lab.

Now use it. In `/etc/asterisk/extensions.conf`, replace the `noanswer` and `busy` labels
in your `_60XX` rule so they send the caller to voicemail rather than a dead end:

```ini
exten => _60XX,1,NoOp(Internal call to ${EXTEN} from ${CALLERID(num)})
 same => n,Dial(PJSIP/${EXTEN},20)
 same => n,NoOp(Dial finished with status: ${DIALSTATUS})
 same => n,GotoIf($["${DIALSTATUS}" = "ANSWER"]?done)
 same => n,GotoIf($["${DIALSTATUS}" = "BUSY"]?busy:noanswer)

 same => n(busy),VoiceMail(${EXTEN}@default,b)
 same => n,Hangup()

 same => n(noanswer),VoiceMail(${EXTEN}@default,u)
 same => n,Hangup()

 same => n(done),Hangup()
```

The letter after the mailbox chooses the greeting: **`u`** for *unavailable*, **`b`** for
*busy*. Two different messages, and the caller hears the right one — which is the whole
reason you checked `${DIALSTATUS}` in Lab 3 instead of treating every failure the same.

Add a way to collect messages, in the `[features]` context:

```ini
exten => *97,1,NoOp(Voicemail collection for ${CALLERID(num)})
 same => n,VoiceMailMain(${CALLERID(num)}@default)
 same => n,Hangup()
```

`VoiceMailMain(${CALLERID(num)})` logs the caller into *their own* mailbox — it reads who
is calling rather than asking. Reload both:

```bash
sudo asterisk -rx 'voicemail reload'
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'voicemail show users'
```

**You should see** both mailboxes listed in context `default`.

### Test it

1. From `6001`, dial `6002` and let it ring out. **You should hear** the unavailable
   greeting and a beep. Leave a message and hang up.
2. **You should see** on `6002`'s softphone a message-waiting indicator — a light, a
   badge, or an envelope icon depending on the phone.
3. From `6002`, dial `*97`, enter PIN `1234`, and listen to the message.

```bash
sudo asterisk -rx 'voicemail show users'
```

**You should see** `6002` now has 1 new message.

> **No message-waiting light?** That is MWI, and it needs the endpoint to subscribe.
> Add `mailboxes=6002@default` to the `[6002]` **endpoint** section in `pjsip.conf` (not
> the aor), then `module reload res_pjsip.so` and re-register the phone. Some softphones
> do not show MWI at all — check `voicemail show users` for the truth.

---

## Step 2 — Transfers

A receptionist who cannot transfer a call is not a receptionist.

Transfers live in `/etc/asterisk/features.conf`, in the `[featuremap]` section. Make it
read:

```ini
[featuremap]
blindxfer => #1
atxfer => #2
disconnect => *0
```

**Two of those are commented out in the shipped file and one is missing entirely.**
`blindxfer` and `disconnect` are present with a leading `;` — uncomment them. **`atxfer`
is not in the file at all**; you have to add the line yourself.

Check your work, because this one misleads people:

```bash
grep -n 'xfer' /etc/asterisk/features.conf
```

Several shipped lines contain `atxfer` as part of a *longer* option name —
`atxferabort`, `atxfercallbackretries`, `atxferdropcall`. It is easy to see those, think
attended transfer is already configured, and spend twenty minutes wondering why `#2` does
nothing.

These define **DTMF feature codes** — key sequences a party can press *during* a call to
make Asterisk do something.

| Code | Feature | What happens |
|---|---|---|
| `#1` | Blind transfer | You press `#1`, dial a number, and hang up immediately. The call is handed over whether or not anyone answers. |
| `#2` | Attended transfer | You press `#2`, dial, **talk to the person first**, then hang up to connect them. If they refuse, you get the caller back. |
| `*0` | Disconnect | Ends the call. |

Feature codes only work if the channel is told to listen for them. In your dialplan, the
`Dial()` needs flags:

```ini
 same => n,Dial(PJSIP/${EXTEN},20,tT)
```

- **`t`** — allow the **called** party to transfer
- **`T`** — allow the **calling** party to transfer

Capital and lowercase mean different things here, and getting them the wrong way round is
a classic. Add `tT` to the `_60XX` Dial in `[features]`.

```bash
sudo asterisk -rx 'module reload features'
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'features show'
```

**You should see** your feature codes listed under Dynamic Features / Feature Map.

### Test it

You need three parties, so use your two softphones plus the IVR echo test as the third
destination.

1. `6001` calls `6002`. Answer.
2. On `6002`, press **`#2`** — the caller hears hold music.
3. Dial `600` and press `#`. You are now talking to the echo test.
4. Hang up `6002`. `6001` is now connected to the echo test.

**You should see** in the CLI the channels being re-bridged as the transfer completes.

> Pressing `#2` does nothing? Your softphone is probably sending DTMF as SIP INFO while
> Asterisk expects RFC 4733. Set `dtmf_mode=rfc4733` on the endpoint (it is the default),
> and check the phone's own DTMF setting matches. `pjsip set logger on` shows you which
> is being used.

---

## Step 3 — Music on hold

That hold music during the transfer came from the `default` MOH class, which
`make samples` populated. Confirm:

```bash
sudo asterisk -rx 'moh show classes'
```

**You should see** class `default`, mode `files`, pointing at
`/var/lib/asterisk/moh`.

Add a second class so you can hear the difference. In `/etc/asterisk/musiconhold.conf`:

```ini
[queue-hold]
mode=files
directory=moh
sort=random
```

`sort=random` matters more than it sounds: with the default alphabetical sort, every
caller hears the same track from the beginning, and a queue full of people hears the same
music in lockstep.

```bash
sudo asterisk -rx 'moh reload'
sudo asterisk -rx 'moh show classes'
```

---

## Step 4 — Call parking

A transfer sends a call to a person. **Parking** puts a call somewhere and tells you the
slot number, so anyone can collect it — the PBX equivalent of "hold line 2".

Open `/etc/asterisk/res_parking.conf` and find the `[default]` lot — **it is already
there**, and already says what you need:

```ini
[default]
parkext => 700
parkpos => 701-720
context => parkedcalls
parkingtime => 45
findslot => first
comebacktoorigin => yes
```

Read it rather than retyping it. **Do not add a second lot** with its own `parkext => 700`:
two lots claiming the same extension is a conflict, the new lot silently fails to load,
and `parking show <yourlot>` answers `Could not find parking lot`.

- `parkext => 700` — dial 700 (or transfer to it) to park a call
- `parkpos => 701-720` — the slots calls land in
- `parkingtime => 45` — after 45 seconds unparked, it comes back to whoever parked it

That last one matters. Without it a forgotten call sits on hold forever and the caller
eventually gives up on your company.

Make the parking lot reachable from `[features]`:

```ini
include => parkedcalls
exten => 700,1,Park()
```

```bash
sudo asterisk -rx 'module reload res_parking.so'
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'parking show default'
```

**You should see:**

```
Parking Lot: default
Parking Extension   :  700
Parking Context     :  parkedcalls
Parking Spaces      :  701-720
Parking Time        :  45 sec
Comeback to Origin  :  yes
```

> Use `parking show default`, not bare `parking show` — the latter prints only the general
> options and lists no lots at all, which reads as "parking is not configured" when it is
> working perfectly.

### Test it

1. `6001` calls `6002`, answer.
2. On `6002` press `#1` (blind transfer), dial `700`.
3. **You should hear** Asterisk announce a slot number — probably **701**.
4. From `6002`, dial `701`. You are reconnected to `6001`.

```bash
sudo asterisk -rx 'parking show default'
```

Run that while the call is parked and **you should see** it occupying a slot.

---

## Step 5 — Call pickup

The phone on the next desk is ringing and its owner is at lunch. Pickup lets you answer
it from your own phone.

Both endpoints need to be in the same pickup group. In `pjsip.conf`, add to **both**
`[6001]` and `[6002]` endpoint sections:

```ini
callgroup=1
pickupgroup=1
```

- `callgroup` — which group this phone's ringing calls belong to
- `pickupgroup` — which groups this phone is allowed to snatch calls from

They are separate on purpose: a manager can be allowed to pick up their team's calls
without the team being able to pick up the manager's.

In `[features]`:

```ini
exten => *8,1,NoOp(Group pickup by ${CALLERID(num)})
 same => n,PickupChan(PJSIP/${EXTEN})
 same => n,Hangup()

exten => **,1,Pickup()
 same => n,Hangup()
```

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
sudo asterisk -rx 'dialplan reload'
```

### Test it

1. From the IVR or a third phone, call `6002` and let it ring.
2. On `6001`, dial `**`.
3. **You should see** `6001` connected to the caller, and `6002` stops ringing.

---

## Step 6 — A call queue with agents

This is the call-centre part, and it is where a PBX stops being a phone system and
starts being an operations tool.

In `/etc/asterisk/queues.conf`:

```ini
[general]
persistentmembers = yes
monitor-type = MixMonitor

[support]
strategy = rrmemory
timeout = 15
retry = 5
wrapuptime = 10
maxlen = 0
musicclass = queue-hold
announce-frequency = 30
announce-holdtime = yes
joinempty = no
leavewhenempty = no
ringinuse = no

member => PJSIP/6001,0,Alice
member => PJSIP/6002,1,Bob
```

The settings that decide whether your queue behaves sensibly:

| Setting | What it does |
|---|---|
| `strategy = rrmemory` | Round-robin, but it *remembers* where it stopped, so the same agent is not hit first every time. |
| `timeout = 15` | Ring one agent for 15s before moving to the next. |
| `wrapuptime = 10` | Give an agent 10s after a call before sending them another. Without it, agents get a new call while still typing up the last one. |
| `ringinuse = no` | Do not ring an agent already on a call. Sounds obvious; is off by default. |
| `joinempty = no` | Do not let callers into a queue with no logged-in agents — they would wait for nobody. |
| `member => PJSIP/6001,0,Alice` | The `0` is a **penalty**. Lower penalty is tried first, so Bob (1) only rings when Alice (0) is unavailable. That is how you build tiered support. |

Route a number into it, in `[features]`:

```ini
exten => 6500,1,NoOp(Caller ${CALLERID(num)} entering the support queue)
 same => n,Answer()
 same => n,Queue(support,tT)
 same => n,NoOp(Left queue with status ${QUEUESTATUS})
 same => n,Hangup()
```

```bash
sudo asterisk -rx 'module reload app_queue.so'
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'queue show support'
```

**You should see** the queue with both members, their penalties, and `No Callers`.

### Test it

1. Dial `6500` from the IVR path or another phone. Alice (`6001`) should ring first.
2. Do not answer. After 15 seconds Bob (`6002`) rings.
3. Answer on `6002`.

While a caller is waiting:

```bash
sudo asterisk -rx 'queue show support'
```

**You should see** the caller listed with their position and wait time, and the members
marked `In use` or `Not in use`.

---

## Step 7 — Watch the queue like an operations person

```bash
sudo asterisk -rx 'queue show support'
```

**You should see** at the bottom the counters that matter in a real call centre:

```
   No Callers
   Completed: 1
   Abandoned: 0
   Mean Holdtime: 12s
   Service Level: 0.0%
```

- **Abandoned** — callers who hung up while waiting. The single most important number in
  a call centre, and the one people forget to look at.
- **Mean Holdtime** — average wait before an agent answered.
- **Service Level** — percentage answered within `servicelevel` seconds. Set
  `servicelevel = 20` in the queue and reload to make it meaningful.

Agents can log in and out at runtime rather than being fixed in the config:

```bash
sudo asterisk -rx 'queue remove member PJSIP/6002 from support'
sudo asterisk -rx 'queue show support'
sudo asterisk -rx 'queue add member PJSIP/6002 to support penalty 1'
```

**You should see** the member list change. This is what a "log out for lunch" button does
underneath — and in the Programmability section you will do exactly this over AMI.

There is also a running log of every queue event:

```bash
sudo tail -20 /var/log/asterisk/queue_log
```

**You should see** `ENTERQUEUE`, `CONNECT`, `COMPLETEAGENT` / `COMPLETECALLER` records.
Every call-centre report ever written is built from this file.

---

## ✅ Checkpoint

You have finished when all six are true:

1. A call that rings out lands in voicemail, and `*97` plays it back
2. `#2` performs an attended transfer between your two phones
3. Parking a call announces a slot, and dialling that slot retrieves it
4. `**` picks up a ringing phone from the other handset
5. `queue show support` lists both agents with different penalties, and a call to `6500`
   rings Alice before Bob
6. `queue_log` contains `ENTERQUEUE` and `CONNECT` for that call

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `VoiceMail()` says the mailbox does not exist | Mailbox not in the `default` context | `voicemail show users`. The dialplan says `${EXTEN}@default`, so the mailbox must be under `[default]` in voicemail.conf. |
| Voicemail records but `*97` finds nothing | Collecting from a phone whose caller ID is not the mailbox number | `VoiceMailMain(${CALLERID(num)})` uses the caller's number. Check `callerid=` on the endpoint. |
| Feature codes do nothing | Missing `tT` on `Dial()`, or DTMF mismatch | `features show` to confirm the codes, then `pjsip set logger on` during a call and look for the DTMF method the phone uses. |
| Transfer drops the call instead | Blind transfer to a number that does not exist | The target must be reachable **from the context the transferring phone is in**. Check with `dialplan show <num>@features`. |
| Parked call never comes back | `comebacktoorigin` off, or the parker hung up | `parking show default` while parked. |
| Pickup says "there is no call to pick up" | Groups do not match, or the phone is not ringing yet | Both endpoints need `callgroup` **and** `pickupgroup`. Reload res_pjsip and re-register. |
| Queue rings nobody | Members not reachable, or `joinempty=no` with no agents | `queue show support` — members must not be `Unavailable`. An unregistered phone is an unavailable agent. |
| Both agents ring at once | `strategy = ringall` | You want `rrmemory`. Check you edited the right queue. |
| Lost the configuration | — | `sudo lab reset` restores the baseline; rebuild from Lab 2. |

---

## What you built

```
  6500 ──► Queue(support)  strategy=rrmemory, wrapuptime=10
              ├─ penalty 0  PJSIP/6001  Alice     ← tried first
              └─ penalty 1  PJSIP/6002  Bob       ← only when Alice is busy

  _60XX ──► Dial(...,20,tT) ──► no answer ──► VoiceMail(u)
                             └─ busy      ──► VoiceMail(b)
                             └─ #1 / #2   ──► transfer
                             └─ 700       ──► park (701-720, 45s timeout)

  *97 ──► VoiceMailMain      ** ──► Pickup
```

---

**Next:** Lab 6 — the SIP and PJSIP in Depth section — you will capture these calls with `sngrep`
and read what actually went across the wire.
