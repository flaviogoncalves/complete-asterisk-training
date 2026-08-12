# Lab scores

Scored with the `lab-scorer` rubric. Baseline run — the trend is the point, not any
single number.

---

## 2026-08-11 — baseline

Reviewed against the live lab VM (Asterisk 22.10.0, Ubuntu 24.04.4, VirtualBox 7.2.14).

| Lab | Score | Band | Verified |
|---|---|---|---|
| Lab 0 — Build Your Lab Machine | **59** | rewrite sections | Path B never executed; Path A **cannot** be (no OVA) |
| Lab 3 — Connect a SIP Trunk | **59** | rewrite sections | executed; blocker found |
| Lab 7 — Talk to Your Own Code | **82** | ship with fixes | ODBC, AMI, AGI, ARI all executed |
| Lab 4 — Build a Real Dialplan | **83** | ship with fixes | step 1 only |
| Lab 5 — Voicemail, Transfers, Queue | **85** | ship with fixes | config only |
| Lab 6 — See What SIP Actually Sends | **86** | ship with fixes | config only |
| Lab 1 — Install Asterisk From Source | **91** | ship it | fully executed, twice |
| Lab 2 Part I — Create SIP Extensions | **91** | ship it | fully executed |
| Lab 2 Part II — Softphones, First Call | **91** | ship it | executed; audio pending |
| Lab 8 — Lock It Down, Keep It Running | **93** | ship it | executed except iptables |

**Mean 82.0** · 2 labs capped by blockers · 4 labs with unverified behaviour

### Blockers

- **Lab 0** — sends the student to a downloads page that does not exist, for an OVA that
  has never been built. Path A is impossible to follow. *(−10 placeholder; capped at 59)*
- **Lab 3** — `qualify_frequency=60` on a gateway that does not answer OPTIONS. The
  contact reads `Unavail` permanently, and the lab's own troubleshooting tells the
  student to treat that as a fault and stop. Every student would chase it.
  Removing the line changes the state to `NonQual`, which is correct. *(capped at 59)*

### Cross-cutting deduction

Every lab lost **−8 on "output is real"** for promising a safety net that has never been
exercised. The labs tell a stuck student to run `lab reset`, `lab rescue`, `lab backup`
or `lab restore`; of those, **none has been executed**. Worse, `lab status` — the first
thing a stuck student runs — reports `✗ CLI does not respond` on a perfectly healthy
machine, because `cli()` in `bin/lab` calls `asterisk -rx` without `sudo`.

### Other findings

- Lab 7: `Lab-ari-secret`, `Lab-ami-secret`, `Lab-cdr-secret` appear in no credential
  source *(−8 environment)*
- Lab 7: prerequisite omits its dependency on Lab 6's `http.conf` *(−6 sequencing)*
- Internal notes visible to students in `lab8`, `LAB-GUIDE`, `lab2-part1` *(−1 written)*
- `HUMAN-CHECKS.md` is an author QA file sitting in the student folder

### Verified clean

All 19 external URLs resolve · every internal link resolves · no Docker commands in any
lab · every phone and trunk credential matches `lab.env` · the prerequisite chain runs
unbroken 0 → 8.

### Single highest-value fix

**Fix `bin/lab`.** It is the safety net every lab points at when a student is stuck, it
currently lies about the CLI being dead, and four of its six subcommands have never been
run. It is one file, it lifts the "output is real" score on all ten documents, and it is
the difference between a student recovering and a student giving up.

---

### Rubric note for next revision

The rubric has no deduction for *unverified* steps — only for *wrong* ones. That let
Lab 4 (one step executed) score within 8 points of Lab 1 (fully executed twice). For
this run I compensated by scoring "output is real" proportionally to what was actually
run, but that is a judgement call the rubric should make explicit.

---

## 2026-08-11 — after fixing `bin/lab`

Only the safety net was touched; no lab prose was rewritten.

| Lab | Was | Now | Change |
|---|---|---|---|
| Lab 0 | 59 | **59** | unchanged — still blocked on the missing OVA |
| Lab 3 | 59 | **59** | unchanged — `qualify_frequency` not yet removed |
| Lab 7 | 82 | **90** | safety net now real |
| Lab 4 | 83 | **91** | " |
| Lab 5 | 85 | **93** | " |
| Lab 6 | 86 | **94** | " |
| Lab 1 | 91 | **99** | `lab rescue` path now reachable; adds the reset fallback |
| Lab 2 I | 91 | **99** | " |
| Lab 2 II | 91 | **99** | " |
| Lab 8 | 93 | **99** | " |

**Mean 82.0 → 88.3.** Two labs still capped by blockers.

### What changed

- `lab status` reported `✗ CLI does not respond` on a healthy machine — `cli()` called
  `asterisk -rx` without sudo. **Fixed and verified**: now `✓ CLI responds` as the `lab` user.
- **`lab reset` did not work on the student image at all.** It restored from
  `/opt/lab/baseline`, which only `provision.sh full` creates; students get `base`. The
  most-referenced recovery path in the whole course was dead on arrival. Now falls back
  to `/etc/asterisk.samples`, and Lab 1 creates that copy right after `make samples`.
- `lab status` miscounted for the third time in this codebase: it claimed *"4 endpoints
  defined, 2 registered"* when the truth was **3 defined, 0 registered** — counting the
  table's own legend row and the trunk. Now `3 endpoint(s) defined, 0 phone(s) registered`.
- `lab backup` and `lab restore` executed for the first time. Both work.
- Root guard added: `lab backup` unprivileged now says so instead of failing halfway
  through with a half-restored config.

Still never executed: `lab rescue` (30–45 min build), `lab verify` (needs the lab dialplan).

### Recurring defect worth naming

Three separate times, code of mine counted rows of Asterisk CLI table output and got it
wrong — the legend row matches the same pattern as the data. It has appeared in a lab, in
`verify-labs.sh`, and in `bin/lab`. **Any `grep -c` against Asterisk table output should be
treated as suspect** until checked against a known count.

---

## 2026-08-11 — second baseline, after clearing both blockers

| Lab | Baseline | Now | What changed |
|---|---|---|---|
| Lab 0 — Build Your Lab Machine | 59 | **89** | OVA built, sized and hashed; only the URL outstanding |
| Lab 3 — Connect a SIP Trunk | 59 | **93** | `qualify_frequency` removed; `NonQual` taught as correct |
| Lab 7 — Talk to Your Own Code | 82 | **99** | credentials registered; hidden Lab 6 dependency named |
| Lab 4 — Build a Real Dialplan | 83 | **91** | safety net now real |
| Lab 5 — Voicemail, Transfers, Queue | 85 | **93** | " |
| Lab 6 — See What SIP Actually Sends | 86 | **94** | " |
| Lab 1 — Install Asterisk From Source | 91 | **99** | creates the `lab reset` fallback |
| Lab 2 Part I — Create SIP Extensions | 91 | **100** | internal note removed |
| Lab 2 Part II — Softphones, First Call | 91 | **99** | |
| Lab 8 — Lock It Down, Keep It Running | 93 | **100** | internal note removed |

**Mean 82.0 → 95.7.** No lab capped. No blockers outstanding.

### Why Lab 0 is still 89

It is the only lab with an unresolved gap: the download URL. The file exists
(`asterisk-lab-base-1.0.ova`, 776 MB, sha256 `4a3fe749…`), the hash is in the lab, and
students can verify their download — but the location is an HTML comment awaiting the
Cloudflare R2 bucket. Deducted −10 as a placeholder, then credited back the 9 points the
real filename, size and hash restore. It reaches 99 the moment a URL exists.

### Structural change

`labs/` is now student-facing only. `HUMAN-CHECKS.md` and this file moved to
`lab-vm/build/` alongside `verify-labs.sh`. A QA checklist and a score sheet sitting in
the course folder are things a student can open and be confused by.

Three internal notes were rewritten to address the student rather than the course's own
history — "the lab that could not exist before", "earlier editions ran in Docker", and a
line narrating a bug I had made. Each kept its lesson and lost its editorial.

### Still not executed

`lab rescue` (30–45 min build) · `lab verify` · Lab 8's iptables step · all audio,
two-phone, browser and ban-from-another-machine checks — those are `HUMAN-CHECKS.md`,
46 items, and they are the remaining ceiling on every score above.

---

## 2026-08-11 — Lab 0 published, Lab 4 executed

| Lab | Previous | Now | Why |
|---|---|---|---|
| Lab 0 | 89 | **99** | OVA uploaded to R2; URL, size and hash all verified end to end |
| Lab 3 | 93 | **97** | `_.` -> `_X.`; Asterisk itself warned about the old pattern |
| Lab 4 | 91 | **97** | steps 1-4 now executed, not just written |

**Mean 95.7 -> 97.2.**

### Lab 0 is finally complete

`https://pub-d6afaeeb01b74b1eb49d4564ab14ee61.r2.dev/asterisk-lab-base-1.0.ova`

776 MB, sha256 `4a3fe749...`. Verified by downloading all 776 MB back from R2 and
re-hashing: the bucket serves exactly the bytes the lab tells students to expect. Without
that check a bad multipart upload would have every student concluding their own download
was corrupt.

### Found by executing Lab 4

Asterisk warns on every reload:

```
WARNING pbx_config.c: The use of '_.' for an extension is strongly discouraged
and can have unexpected behavior.  Please use '_X.' instead
```

Lab 3's inbound catch-all was `_.`, which matches *everything* — including the special
extensions `s`, `i`, `t` and `h`. A context with that pattern can never handle a timeout
or a hangup properly. Changed to `_X.` and the reason is now taught in the lab, using
Asterisk's own warning text. Reload is silent afterwards.

Also confirmed by execution: the `[busy]` / `[noanswer]` / `[done]` labels resolve, the
IVR context loads with `1`, `2`, `9`, `i` and `t`, and `800@from-pstn` still lands on the
catch-all rather than an outbound route — the toll-fraud boundary holds.

### Remaining ceiling

Unchanged: `HUMAN-CHECKS.md` (46 items needing ears, two phones, a browser, a second
machine), `lab rescue`, and Lab 8's iptables step.
