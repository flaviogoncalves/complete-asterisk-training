# Lab 2 Part I: Create SIP Extensions

**Time:** ~30 minutes
**Prerequisites:** Lab 1 — Asterisk 22.10.0 is installed and running on your lab machine.

At the end of Lab 1 you ran `pjsip show endpoints` and Asterisk answered
`No objects found.` You have a PBX that knows about no telephones at all.

In this lab you write the configuration that gives it two: extensions `6001` and
`6002`. You will not copy a finished file — you will build it up a piece at a time and
watch Asterisk pick up each piece, because when this goes wrong in production it goes
wrong one object at a time.

Nothing registers a phone in this lab. That is Part II. Here you are working purely on
the server side.

---

## Step 1 — The four objects a telephone needs

Old Asterisk used one `sip.conf` block per device. PJSIP splits that into small objects
that reference each other by name. It feels like more typing until the first time you
need two phones to share one set of credentials, or one phone to answer on three
addresses.

For one working desk phone you need four:

| Object | Answers the question | Think of it as |
|---|---|---|
| **transport** | On which IP, port and protocol does Asterisk listen? | the socket |
| **endpoint** | What is this phone allowed to do? | the phone's personality |
| **auth** | What username and password will it prove itself with? | the credentials |
| **aor** | Where is the phone right now? | the address book entry |

A transport is shared by every phone. The other three are per phone.

> **The naming rule that catches everyone:** an endpoint finds its auth and its aor
> **by section name**. `auth=6001` means "the section called `[6001]` that has
> `type=auth`". Three different objects can — and here, do — all share the name `6001`,
> and Asterisk tells them apart by their `type=`. Get a name wrong and Asterisk does not
> error; the phone simply never works.

---

## Step 2 — Start a fresh pjsip.conf

`make samples` in Lab 1 left a large `pjsip.conf` full of commented-out examples. It is
worth reading one day, but not today. Move it aside and start clean:

```bash
sudo mv /etc/asterisk/pjsip.conf /etc/asterisk/pjsip.conf.sample
sudo nano /etc/asterisk/pjsip.conf
```

> `nano` saves with **Ctrl-O**, then **Enter**, and exits with **Ctrl-X**. Use `vim` if
> you prefer it.

---

## Step 3 — The transport

Type this in — it is the first thing every PJSIP config needs:

```ini
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

`0.0.0.0` means "every address this machine has". Whichever path you took in Lab 0 — a
bridged adapter on your own network, or a server with its own public address — that
includes the address `lab ip` reported, which is where your softphone will send its
packets in Part II.

Save, then tell Asterisk to re-read the file:

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
```

Check it took:

```bash
sudo asterisk -rx 'pjsip show transports'
```

**You should see** one transport, `transport-udp`, bound to `0.0.0.0:5060`.

> If you see nothing, the file did not parse. Run
> `sudo asterisk -rx 'module reload res_pjsip.so'` again and watch for an error, or check
> `sudo tail -20 /var/log/asterisk/messages.log`. A missing `]` is the usual cause.

---

## Step 4 — Your first endpoint

Now add `6001`. Append all three objects to `/etc/asterisk/pjsip.conf`:

```ini
;=============================== 6001 ===================================
[6001]
type=endpoint
context=internal
disallow=all
allow=ulaw
allow=alaw
auth=6001
aors=6001
callerid=Alice <6001>

[6001]
type=auth
auth_type=userpass
username=6001
password=Lab-6001-secret

[6001]
type=aor
max_contacts=1
```

Line by line, because every one of these earns its place:

| Line | What it does |
|---|---|
| `context=internal` | Which part of the dialplan this phone's calls enter. **This is a security control, not a label** — it decides what the phone is allowed to dial. You will build the `internal` context in Part II. |
| `disallow=all` then `allow=ulaw` | Clear the codec list, then permit only what you want. Always in that order; `allow` without `disallow=all` first leaves the defaults in place. |
| `auth=6001` / `aors=6001` | The name links to the two sections below. |
| `callerid=Alice <6001>` | What the other phone displays. |
| `max_contacts=1` | One device may register as `6001` at a time. Raise it if you want a desk phone and a mobile on one extension. |

Reload and look:

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
sudo asterisk -rx 'pjsip show endpoints'
```

**You should see:**

```
 Endpoint:  6001/6001                                          Unavailable   0 of inf
     InAuth:  6001/6001
        Aor:  6001                                             1
```

> **Why `6001/6001` and not just `6001`?** That column is headed
> `<Endpoint/CID...>` — it shows the endpoint name, then the caller ID number. You set
> `callerid=Alice <6001>`, so the CID is `6001`. Drop the `callerid` line and it would
> read `6001/` with nothing after the slash.

**`Unavailable` is correct.** It means "this endpoint is defined, but no telephone has
registered to it". You have described a phone; no phone has turned up yet.

The two indented lines are the proof your names matched. `InAuth: 6001/6001` means the
endpoint found its auth object. `Aor: 6001` means it found its aor. If you had
mistyped `auth=6002`, those lines would be missing — and that is the fastest way to
spot the mistake.

---

## Step 5 — Look at the objects individually

Three commands worth learning now, because you will use them for the rest of your
career:

```bash
sudo asterisk -rx 'pjsip show endpoint 6001'
```

Everything Asterisk believes about this phone — every codec, NAT setting and timer,
including the defaults you never wrote down. Long output; skim it.

```bash
sudo asterisk -rx 'pjsip show aors'
```

**You should see** `6001` with a `Contacts` column that is empty. That column is the
whole job of an AOR: it fills in when a phone registers, and empties when it goes away.

```bash
sudo asterisk -rx 'pjsip show auths'
```

**You should see** the `6001` auth object, `userpass`.

---

## Step 6 — Now do it yourself: add 6002

This one is yours. Add extension **`6002`** for **Bob**, password **`Lab-6002-secret`**,
following exactly the pattern of `6001`.

Four things must change from the block you just wrote, and nothing else:

- the three section names
- `username=`
- `password=`
- `callerid=`

Write it, save, and reload:

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
sudo asterisk -rx 'pjsip show endpoints'
```

**You should see both** `6001` and `6002`, each `Unavailable`, each with its own
`InAuth` and `Aor` lines, and `Objects found: 2`.

> Only got one? The commonest causes, in order: a section name still says `6001`; a
> `type=` line is missing; or the file did not parse at all — in which case
> `pjsip show endpoints` still shows the *previous* configuration and nothing looks
> wrong. Always check `Objects found:` actually changed.

---

## Step 7 — Prove the config is what you think it is

There is a difference between "the file on disk" and "what Asterisk currently has
loaded". After a failed reload those are not the same thing, and chasing that gap has
cost people entire evenings.

```bash
sudo asterisk -rx 'pjsip show endpoints' | grep 'Objects found:'
```

**You should see** `Objects found: 2`.

> Use `Objects found:` rather than counting `Endpoint:` lines yourself. The table prints
> a legend row that also begins `Endpoint:`, so a naive `grep -c` comes out one too high.
> Asterisk's CLI tables are for reading, not for counting — when you need a number, find
> the one Asterisk already gives you.

Now deliberately break it, so you know what a failure looks like *before* it happens by
accident. In the `[6001]` **endpoint** section, change `allow=ulaw` to a codec that does
not exist:

```ini
allow=notacodec
```

Reload, and look at what Asterisk reports:

```bash
sudo asterisk -rx 'module reload res_pjsip.so'
```

**You should see** `Module 'res_pjsip.so' reloaded successfully.` — which is a lie, or
at least badly incomplete. Check the endpoints:

```bash
sudo asterisk -rx 'pjsip show endpoints' | grep 'Objects found:'
```

**Still `Objects found: 2`.** Nothing appears wrong anywhere. Now read the log:

```bash
sudo tail -5 /var/log/asterisk/messages.log
```

**You should see:**

```
ERROR  res_sorcery_config.c: Could not create an object of type 'endpoint' with id
       '6001' from configuration file 'pjsip.conf'
NOTICE res_sorcery_config.c: Retaining existing configuration for object of type
       'endpoint' with id '6001'
```

**"Retaining existing configuration"** is the sentence to remember. Asterisk rejected
your edit and carried on with the version it already had in memory — rather than
dropping a working endpoint and everyone's calls with it.

That is the right behaviour, and it has a consequence you must build a habit around:
**the file on disk and the configuration Asterisk is running are two different things.**
After a rejected reload they disagree, silently, and every subsequent edit you make will
seem to have no effect. People lose entire evenings to this.

So: after any reload, verify the *result* — not the fact that a reload happened.

Put `allow=ulaw` back, reload, and confirm the log is clean.

---

## ✅ Checkpoint

You have finished this lab when all four are true:

1. `pjsip show transports` shows `transport-udp` on `0.0.0.0:5060`
2. `pjsip show endpoints` shows `6001` and `6002`, `Objects found: 2`
3. Each endpoint shows its own `InAuth:` and `Aor:` lines
4. `pjsip show aors` shows both, with **no contacts** — no phone has registered yet

Point 4 is the correct end state. Part II is where the telephones arrive.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `pjsip show endpoints` → `No objects found.` | The file did not parse, or `pjsip.conf` is in the wrong place | `sudo tail -20 /var/log/asterisk/messages.log`. Confirm the path is exactly `/etc/asterisk/pjsip.conf`. |
| Endpoint listed, but no `InAuth:` / `Aor:` lines | Names do not match | The `auth=` and `aors=` values must equal the section names exactly. Case matters. |
| Changes appear to do nothing | The reload failed and the old config is still loaded | Check `Objects found:` really changed. Read the log. |
| `Unable to connect to remote asterisk` | Asterisk is not running | `sudo systemctl status asterisk`, then `sudo journalctl -u asterisk -n 50`. |
| You have lost track of the file | — | `sudo lab reset` restores a known-good configuration, then start again from Step 3. |

---

## What you built

```
                 ┌──────────────────┐
                 │ transport-udp    │   0.0.0.0:5060/UDP
                 └────────┬─────────┘
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
┌───────▼────────┐                 ┌────────▼───────┐
│ endpoint 6001  │                 │ endpoint 6002  │
│ context=internal│                │ context=internal│
└───┬────────┬───┘                 └───┬────────┬───┘
    │        │                         │        │
┌───▼───┐ ┌──▼────┐               ┌────▼──┐ ┌───▼───┐
│auth   │ │aor    │               │auth   │ │aor    │
│6001   │ │6001   │               │6002   │ │6002   │
└───────┘ └───────┘               └───────┘ └───────┘
                                   (no contacts yet)
```

---

**Next:** Lab 2 Part II — you register real softphones against these two endpoints, watch the
SIP REGISTER exchange as it happens, and place your first call.
