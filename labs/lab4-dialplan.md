# Lab 4: Build a Real Dialplan

**Time:** ~45 minutes
**Prerequisites:** Lab 3 — two phones registered, a trunk registered, `800` reaches the gateway echo test.

Your dialplan is one line per telephone. That does not scale past about four
telephones, and it cannot express a single business rule.

In this lab you replace it with pattern matching, a working auto-attendant, and a
context structure that decides who is allowed to spend your money. Everything the last
five lessons described, applied to the PBX you built.

Keep a CLI open the whole way through — you will use it constantly:

```bash
sudo asterisk -rvvv
```

---

## Step 1 — How Asterisk chooses an extension

Before writing anything, understand the matching rules, because they are the source of
most dialplan surprises.

A pattern always begins with `_`. Inside it:

| Symbol | Matches |
|---|---|
| `X` | one digit, `0`–`9` |
| `Z` | one digit, `1`–`9` |
| `N` | one digit, `2`–`9` |
| `.` | one or more of anything |
| `!` | zero or more of anything |
| `[147]` | one digit from the set |

**When several patterns match, the most specific wins** — not the first one written.
`6001` beats `_60XX`, which beats `_6XXX`, which beats `_.`. Order in the file is
irrelevant, which is exactly what catches people who expect it to read top to bottom.

Try it. Replace your two per-phone lines in `[internal]` with one pattern:

```bash
sudo nano /etc/asterisk/extensions.conf
```

Delete these:

```ini
exten => 6001,1,Dial(PJSIP/6001,20)
 same => n,Hangup()

exten => 6002,1,Dial(PJSIP/6002,20)
 same => n,Hangup()
```

And put this in their place:

```ini
; Any four-digit number starting 60 rings the matching endpoint.
exten => _60XX,1,NoOp(Internal call to ${EXTEN} from ${CALLERID(num)})
 same => n,Dial(PJSIP/${EXTEN},20)
 same => n,Hangup()
```

`${EXTEN}` is the digits that were actually dialled. One rule now serves `6001`, `6002`,
and every extension you ever add.

```bash
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'dialplan show internal'
```

**You should see** `_60XX` where two separate lines used to be.

**Test:** dial `6002` from `6001`. It still rings — but watch the CLI and you will see
your `NoOp` print the caller and the destination. `NoOp` does nothing except write to
the log, and it is the most useful debugging tool in the dialplan.

Now ask Asterisk to explain its own decision:

```bash
sudo asterisk -rx 'dialplan show 6002@internal'
```

**You should see** it resolve `6002` to the `_60XX` rule.

---

## Step 2 — Unanswered calls should do something

`Dial(...,20)` rings for twenty seconds and then falls through to the next priority.
Right now that is `Hangup()`, so the caller gets silence and a dead line.

Asterisk sets `${DIALSTATUS}` after every `Dial`. Use it:

```ini
exten => _60XX,1,NoOp(Internal call to ${EXTEN} from ${CALLERID(num)})
 same => n,Dial(PJSIP/${EXTEN},20)
 same => n,NoOp(Dial finished with status: ${DIALSTATUS})
 same => n,GotoIf($["${DIALSTATUS}" = "ANSWER"]?done)
 same => n,GotoIf($["${DIALSTATUS}" = "BUSY"]?busy:noanswer)

 same => n(busy),Playback(the-party-you-are-calling&is-curntly-busy)
 same => n,Hangup()

 same => n(noanswer),Playback(the-party-you-are-calling&is-curntly-unavail)
 same => n,Hangup()

 same => n(done),Hangup()
```

Four new things:

- **`n(busy)`** gives a priority a *label*, so you can jump to it by name.
- **`GotoIf($[...]?a:b)`** jumps to label `a` if the expression is true, `b` if not. The
  `$[ ]` is what makes it an expression rather than text. With only one label —
  `?done` — it jumps if true and simply falls through to the next priority if false.
- **The `ANSWER` check comes first, and it is not optional.** `Dial()` hands control
  back to the dialplan when the call ends, including when it ended *successfully*. Miss
  this line and a caller whose colleague hangs up first is told "the party you are
  calling is currently unavailable" — after a perfectly good ten-minute conversation.
- **`&`** in `Playback` chains sound files into one sentence.

```bash
sudo asterisk -rx 'dialplan reload'
```

**Test:** dial `6002` and just let it ring out. You should hear "the party you are
calling is currently unavailable", and the CLI should print
`Dial finished with status: NOANSWER`.

Then set phone `6002` to Do Not Disturb, or hang up on the incoming call, and dial it
again — `BUSY`, and the other prompt.

> **Check the names before you trust them.** `ls /var/lib/asterisk/sounds/en/ | grep curntly`
> — and yes, `is-curntly-busy` and `is-curntly-unavail` really are spelled that way.
> Asterisk has shipped those since the beginning.
>
> These two prompts live in the **extra** sound package, not the core one. If you hear
> only the first half of the sentence, `EXTRA-SOUNDS-EN-ULAW` was not selected in
> `make menuselect` back in Lab 1. `Playback` skips a file it cannot find and carries on
> without an error, so a missing prompt is silence, never a message.

---

## Step 3 — An auto-attendant

A menu that answers, speaks, and waits for a digit. Add a new context at the end of the
file:

```ini
;===========================================================================
; ivr — the auto-attendant
;===========================================================================
[ivr]

exten => s,1,NoOp(IVR entered by ${CALLERID(num)})
 same => n,Answer()
 same => n,Wait(1)
 same => n(menu),Background(demo-congrats)
 same => n,WaitExten(7)

exten => 1,1,NoOp(Caller chose sales)
 same => n,Dial(PJSIP/6001,20)
 same => n,Hangup()

exten => 2,1,NoOp(Caller chose support)
 same => n,Dial(PJSIP/6002,20)
 same => n,Hangup()

exten => 9,1,Playback(demo-echotest)
 same => n,Echo()
 same => n,Hangup()

; caller pressed something that is not on the menu
exten => i,1,Playback(invalid)
 same => n,Goto(s,menu)

; caller pressed nothing at all
exten => t,1,Playback(vm-goodbye)
 same => n,Hangup()
```

The special extension names are the point of this step:

| Extension | Fires when |
|---|---|
| `s` | the call **s**tarts — entered the context without a number |
| `i` | the caller pressed an **i**nvalid option |
| `t` | the caller **t**imed out and pressed nothing |

And the two applications that make a menu work:

- **`Background()`** plays a prompt but keeps listening for digits, so a caller who knows
  the menu can interrupt it. `Playback()` will not — a menu built on `Playback` forces
  everyone to sit through the whole recording.
- **`WaitExten(7)`** waits seven more seconds for a digit after the prompt ends.

> Notice there is nothing after `WaitExten`. There is no point putting anything there:
> on timeout, control jumps to the `t` extension, and on an invalid key to `i`. Any
> priority written after `WaitExten` in the `s` extension is unreachable. A dialplan
> that looks like it loops back to the menu but never does is a genuinely hard bug to
> see, so it is worth knowing why this one stops here.

Give the IVR a number from `[internal]`:

```ini
exten => 6000,1,Goto(ivr,s,1)
```

```bash
sudo asterisk -rx 'dialplan reload'
```

**Test:** dial `6000`. You should hear the prompt. Press `1` — phone 6001 rings. Call
again, press `9` — echo test. Call again, press `5` — "invalid". Call again, press
nothing — goodbye, then hangup.

Watch the CLI through all of it. Every choice prints its `NoOp`.

---

## Step 4 — Contexts are a security boundary

This is the part that matters more than everything above it.

A context is not a folder for organising your dialplan. It is a statement of **what a
caller is permitted to do**. A phone in `internal` can dial `_10XX` — out through your
trunk, at your expense. A caller in `from-pstn` cannot, because you never gave that
context an outbound rule.

`include` is how you grant permission. Build a tier of access:

```ini
;===========================================================================
; Access tiers. Each includes the one below it.
;===========================================================================

; Everyone gets these. No outbound, no cost.
[features]
exten => 600,1,Answer()
 same => n,Playback(demo-echotest)
 same => n,Echo()
 same => n,Hangup()

exten => 6000,1,Goto(ivr,s,1)

exten => _60XX,1,NoOp(Internal call to ${EXTEN} from ${CALLERID(num)})
 same => n,Dial(PJSIP/${EXTEN},20)
 same => n,NoOp(Dial finished with status: ${DIALSTATUS})
 same => n,GotoIf($["${DIALSTATUS}" = "ANSWER"]?done)
 same => n,GotoIf($["${DIALSTATUS}" = "BUSY"]?busy:noanswer)
 same => n(busy),Playback(the-party-you-are-calling&is-curntly-busy)
 same => n,Hangup()
 same => n(noanswer),Playback(the-party-you-are-calling&is-curntly-unavail)
 same => n,Hangup()
 same => n(done),Hangup()

; Calls that leave the building and cost money.
[outbound]
include => features

exten => 800,1,NoOp(Outbound to the gateway echo test)
 same => n,Dial(PJSIP/*98@pstn,30)
 same => n,Hangup()

exten => _10XX,1,NoOp(Outbound to lab account ${EXTEN})
 same => n,Dial(PJSIP/${EXTEN}@pstn,30)
 same => n,Hangup()

; What the desk phones actually use.
[internal]
include => outbound
```

Move your existing extensions into these contexts so `[internal]` contains nothing but
the `include`, exactly as above.

```bash
sudo asterisk -rx 'dialplan reload'
sudo asterisk -rx 'dialplan show internal'
```

**You should see** `internal` listing `Include => outbound`, and the extensions
inherited through the chain.

Nothing changed for your phones — they still reach everything. But you can now demote a
phone to internal-only by changing **one word** in `pjsip.conf`.

**Test that.** Edit the `6002` endpoint, change `context=internal` to `context=features`,
then:

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
```

From `6002`, dial `6001` — works. Now dial `800` — it fails, and the CLI prints
something like:

```
NOTICE: Call from '6002' to extension '800' rejected because extension not found in context 'features'
```

That single line is what a toll-fraud attempt looks like when your contexts are right.

Put `6002` back to `context=internal` and reload.

---

## Step 5 — Route by time of day

Businesses are not open at 3am, and neither should your IVR be.

```ini
[features]
; ... your existing entries ...

exten => 6000,1,NoOp(Main number, checking office hours)
 same => n,GotoIfTime(09:00-18:00,mon-fri,*,*?open,1)
 same => n,Goto(closed,1)

exten => open,1,Goto(ivr,s,1)

exten => closed,1,Answer()
 same => n,Playback(vm-goodbye)
 same => n,Hangup()
```

Replace your earlier one-line `6000` with this.

`GotoIfTime(times,days-of-week,days-of-month,months?destination)` — the `*` means "any".

```bash
sudo asterisk -rx 'dialplan reload'
```

**Test:** dial `6000`. Whether you get the menu or the goodbye depends on when you are
reading this. To test the other branch without waiting, temporarily narrow the window
to a range that excludes right now — for example `00:00-00:01` — reload, and dial again.

Check the machine agrees with you about the time:

```bash
date
```

A PBX with the wrong timezone routes calls to the wrong place and stamps every CDR
incorrectly. If it is wrong: `sudo timedatectl set-timezone America/Sao_Paulo`.

---

## Step 6 — Read the dialplan the way Asterisk does

Three commands worth keeping:

```bash
sudo asterisk -rx 'dialplan show internal'
```
Everything reachable from `internal`, includes followed.

```bash
sudo asterisk -rx 'dialplan show 800@internal'
```
Resolves one number. The fastest answer to "why does this go there?"

```bash
sudo asterisk -rx 'dialplan show'
```
Every context. Long, but it is the whole map.

---

## ✅ Checkpoint

You have finished when all six are true:

1. `_60XX` rings any `60xx` extension — one rule, not one line per phone
2. Letting a call ring out plays "not available"; a busy phone plays "busy"
3. Dialling `6000` reaches the IVR; `1` rings 6001, `9` echoes, an invalid key says so, silence times out
4. `dialplan show internal` shows the include chain `internal → outbound → features`
5. Moving `6002` to `context=features` **blocks** `800`, and the CLI logs the rejection
6. `6000` routes differently inside and outside office hours

Number 5 is the one to be sure of. If a context change does not restrict what a phone
can dial, your contexts are decorative — and that is how PBXs get robbed.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Reload seems to do nothing | Parse error; the old dialplan is still loaded | `sudo tail -20 /var/log/asterisk/messages.log`. Check the extension count in `dialplan show` actually changed. |
| Pattern never matches | Missing the leading `_` | `_60XX` is a pattern; `60XX` is a literal extension made of the characters `6`, `0`, `X`, `X`. |
| A more general pattern wins | It is genuinely more specific than you think | `dialplan show 6002@internal` shows which rule won. Remember `.` matches one *or more*, so `_6.` also matches `6002`. |
| `GotoIf` always takes the same branch | Missing `$[ ]`, or unquoted variable | It must be `$["${DIALSTATUS}" = "BUSY"]` — with the quotes. An empty variable without quotes makes the expression malformed. |
| IVR plays but digits do nothing | Used `Playback` instead of `Background` | `Playback` does not listen. Only `Background` collects digits. |
| Digits work but land in the wrong place | The digit extensions are in the wrong context | `1`, `2`, `9`, `i`, `t` must all be in `[ivr]`, alongside `s`. |
| `include` seems ignored | Included context defined after use — this is fine — or a typo in the name | `dialplan show internal` lists includes. Names are case-sensitive. |
| Lost the file | — | `sudo lab reset`, then rebuild from Lab 2 Part II Step 5. |

---

## What you built

```
  6001, 6002 ──► context=internal
                      │
                      └─ include ─► outbound          800, _10XX   (costs money)
                                        │
                                        └─ include ─► features     600, 6000, _60XX
                                                          │
                                                          └─ 6000 ─► [ivr]  1 / 2 / 9 / i / t

  gateway ──────► context=from-pstn     (no include — cannot dial out, by design)
```

The shape of that diagram *is* your security policy. Everything a phone may do, it may
do because a line in `pjsip.conf` put it in a context that reaches it.

---

**Next:** Lab 5 — voicemail, transfers, parking, music on hold, and queues with real
agents.
