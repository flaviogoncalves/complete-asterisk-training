# Lab 1: Install Asterisk 22 From Source

**Time:** ~25 minutes, of which 5–15 is the machine compiling while you read.
**Prerequisites:** Lab 0 — you have the lab VM running and can log in as `lab`.

The last two lessons walked through the installation sequence: configure the build,
select modules, compile, install, install the sample configuration. Now you do it.

This is a real source installation on a real Linux server. When you finish you will
have a working Asterisk 22.10.0 with no configuration at all — no phones, no dialplan,
nothing. That is the correct place to end. Lab 2 is where you start building a PBX.

> **Work over SSH if you can.** `ssh lab@<your-lab-ip>` from your own terminal gives you
> scrollback and copy-paste, which matters in this lab because the build prints
> thousands of lines. Use the address `lab ip` gave you in Lab 0. The console window
> works too.

---

## Step 1 — Go to the source

```bash
cd /usr/src/asterisk-22.10.0
ls
```

**You should see** the source tree — `configure`, `Makefile`, `apps/`, `channels/`,
`res/`, and more.

This is the tarball the lessons told you to `wget` from
`downloads.asterisk.org`, already downloaded and unpacked for you. The build
dependencies from the lesson's `apt-get install` list are already resolved too. Both
were done in advance for one reason: a failed download or a missing library forty
minutes into a compile teaches you nothing, and it is where most people give up.

Everything from here is yours.

---

## Step 2 — Configure the build

```bash
sudo ./configure --with-jansson-bundled --with-pjproject-bundled --with-srtp
```

This takes a minute or two and prints a long stream of `checking for...` lines. It is
inspecting your system — which compiler, which libraries, which headers — and writing
a build configuration that matches.

**You should see** it finish with the Asterisk ASCII-art banner and:

```
configure: Package configured for:
configure: OS type  : linux-gnu
configure: Host CPU : x86_64
```

**What the three options mean:**

| Option | Why |
|---|---|
| `--with-jansson-bundled` | Build the bundled JSON library instead of the system one. Fewer version surprises. |
| `--with-pjproject-bundled` | Build the bundled PJSIP stack. **This is the important one** — it keeps the SIP stack version-matched to Asterisk. |
| `--with-srtp` | Build against libsrtp so encrypted media is possible. You need this for the TLS/SRTP lab later. |

> If `configure` stops with an error about a missing library, something has gone wrong
> with the image rather than with you. Run `sudo apt-get install -f` and try again, and
> tell your instructor.

---

## Step 3 — Choose your modules

```bash
sudo make menuselect
```

A blue text menu opens. This is where you decide what actually gets built. Asterisk
has hundreds of modules and you do not want all of them.

Move with the **arrow keys**, change category with **left/right**, toggle an item with
**Enter** or the **spacebar**. `[*]` means selected, `[ ]` means not.

Turn on four things:

1. **Resource Modules** → find `res_srtp` → make sure it is `[*]`
   Encrypted media. Needed for the TLS/SRTP lab.
2. **Resource Modules** → find `res_http_websocket` → make sure it is `[*]`
   WebSockets. Needed for the browser phone lab.
3. **Core Sound Packages** → `CORE-SOUNDS-EN-ULAW` → `[*]`
   The prompts Asterisk plays. Without these, calls connect and you hear nothing —
   which you will then spend an hour blaming on RTP.
4. **Extras Sound Packages** → `EXTRA-SOUNDS-EN-ULAW` → `[*]`
   Extra prompts used by voicemail and the IVR labs.

Press **F12** or **x** to save and exit. (If `x` does nothing, use **F12**; if neither
works, press **Esc Esc** and check you are not inside a submenu.)

> **Why choose at all?** Every module you build is code that gets compiled, installed
> and loaded. In production, fewer modules means a smaller attack surface and a faster
> start. Being deliberate about this is a habit worth forming now.

---

## Step 4 — Compile

```bash
sudo make -j$(nproc)
```

**This is the slow step.** On the 2-core VM from Lab 0 it takes about **5 minutes**;
on a slower machine, or one core, allow 15. `-j$(nproc)` tells `make` to use every CPU
core your VM has, which is why giving it 2 in Lab 0 mattered.

Leave it running. Do not close the window.

**While it compiles**, here is what is happening. `make` is walking the source tree
directory by directory — `main/` builds the core, `channels/` builds `chan_pjsip` and
friends, `apps/` builds the dialplan applications like `Dial()` and `Voicemail()`, and
`res/` builds resource modules including the whole bundled PJSIP stack. That bundled
stack is why this takes as long as it does: you are compiling a complete SIP protocol
library as well as Asterisk itself.

**You should see** it end with:

```
 +--------- Asterisk Build Complete ---------+
 + Asterisk has successfully been built, and +
 + can be installed by running:              +
 +                                           +
 +                make install               +
 +-------------------------------------------+
```

> **If the build fails**, scroll back and find the *first* error — later ones are
> usually consequences. The most common cause on a small VM is running out of memory,
> which shows up as `cc1plus: out of memory` or the compiler being killed. Fix it by
> giving the VM more RAM, or by building with one job at a time: `sudo make -j1`
> (slower, but it will finish).
>
> Genuinely stuck? `sudo lab rescue` installs a known-good build so you are never
> blocked from continuing the course. Use it if you need it — but try the real build
> first, because the next time you do this it will be on someone's production server.

---

## Step 5 — Install

```bash
sudo make install
```

Copies the binaries, modules and sounds into place. About a minute.

**You should see** a banner at the end pointing out that this did **not** install any
configuration files, and telling you to run `make samples` if you want them. That is
expected — it is the next step.

```bash
sudo make samples
```

This writes the stock configuration files into `/etc/asterisk/`. They are almost
entirely commented-out examples, and they are genuinely useful: when you are not sure
what an option does, the sample file usually explains it.

```bash
sudo make install-logrotate
```

Sets up log rotation, so `/var/log/asterisk/messages.log` cannot quietly fill the disk. Skipping
this is a classic way to take down a PBX that has been running happily for a year.

Finally, keep a pristine copy of those stock files:

```bash
sudo cp -a /etc/asterisk /etc/asterisk.samples
```

Thirty seconds now, and it is what `sudo lab reset` restores from when a later lab leaves
you with a PBX that will not start. Every lab from here edits files in `/etc/asterisk/`;
this is the copy nothing ever touches.

---

## Step 6 — Run Asterisk as a service

Asterisk is installed, but nothing is running it yet. On a real server you do not start
a PBX by hand — you let the system do it, so it comes back after a reboot or a crash.

Create a dedicated user for it, rather than running as root:

```bash
sudo adduser --system --group --home /var/lib/asterisk --no-create-home --gecos "Asterisk PBX" asterisk
sudo chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk
sudo usermod -aG asterisk lab
```

Install the service definition. It has been prepared for you — you will take it apart
line by line in the Deployment and Operations section:

```bash
sudo cp /opt/lab/asterisk.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now asterisk
```

Check on it:

```bash
systemctl status asterisk
```

**You should see** `Active: active (running)`. Press `q` to exit.

> `enable` means "start at boot". `--now` means "and start it right now". Together they
> are the two things you almost always want.

---

## Step 7 — Talk to it

Asterisk is running as a background service. Connect to its console:

```bash
sudo asterisk -rvvv
```

**You should see** the Asterisk banner and a prompt like:

```
asterisk-lab*CLI>
```

You are now inside Asterisk. Try:

```
core show version
```

**You should see** `Asterisk 22.10.0 built by root @ asterisk-lab ... running Linux`.

> It says `root` because you built it with `sudo`. The name recorded is whoever ran
> `make`, not who runs the service — Asterisk itself runs as the unprivileged `asterisk`
> user you created in Step 6.

Two more, to see the state of a PBX with no configuration:

```
pjsip show endpoints
```

**You should see** `No objects found.` — there are no phones. Correct.

```
core show channels
```

**You should see** `0 active channels`. Nothing is happening, because nothing can yet.

Leave the console with **Ctrl-C**. That exits the console only; Asterisk keeps running.

> The `-rvvv` matters. `-r` means "connect to the running Asterisk". The `vvv` sets
> verbosity — with it you see calls narrate themselves as they happen, which is how you
> will debug everything from here on. Without it the console is nearly silent.

---

## ✅ Checkpoint

You have finished this lab when all four are true:

1. `systemctl status asterisk` reports `active (running)`
2. `sudo asterisk -rvvv` gives you a `*CLI>` prompt
3. `core show version` reports **22.10.0**
4. `pjsip show endpoints` reports **`No objects found.`**

Point 4 is not a failure. You have installed a PBX; you have not configured one. That
is Lab 2.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `make` killed, or `out of memory` | VM has too little RAM for a parallel build | Shut down, VM → **Settings → System** → raise Base Memory to 4096 MB. Or rebuild with `sudo make -j1`. |
| `configure: error: ... not found` | A build dependency is missing | `sudo apt-get update && sudo apt-get install -f`. If it persists the image is at fault — use `sudo lab rescue` and report it. |
| menuselect will not exit | You are inside a submenu | Press **Esc** to back out, then **F12** to save and exit. |
| `asterisk: command not found` after install | Shell has cached the old PATH lookup | `hash -r`, or log out and back in. |
| `systemctl status` shows `failed` | Permissions on Asterisk's directories | `sudo journalctl -u asterisk -n 50` and read the last error. Then `sudo chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk /var/spool/asterisk`. |
| `systemctl status` says **`active (running)`** but the CLI still says `Unable to connect to remote asterisk` | The service is up but has no control socket | Confirm the unit you copied contains `RuntimeDirectory=asterisk`: `grep RuntimeDirectory /etc/systemd/system/asterisk.service`. That line is what makes systemd create `/run/asterisk` owned by the `asterisk` user. Without it Asterisk runs perfectly and is simply unreachable — `ls -ld /run/asterisk` will show it owned by `root`. Fix the unit, then `sudo systemctl daemon-reload && sudo systemctl restart asterisk`. |
| CLI says `Unable to connect to remote asterisk`, and the service is **not** running | Asterisk stopped or failed to start | `sudo systemctl start asterisk`, then `journalctl -u asterisk -n 50`. |
| Calls later have no sound | Sound packages were not selected in menuselect | Re-run `sudo make menuselect`, enable `CORE-SOUNDS-EN-ULAW`, then `sudo make install && sudo systemctl restart asterisk`. |

---

## What you built, and where it went

| What | Where |
|---|---|
| The `asterisk` binary | `/usr/sbin/asterisk` |
| Configuration | `/etc/asterisk/` |
| Loadable modules | `/usr/lib/asterisk/modules/` |
| Sound prompts | `/var/lib/asterisk/sounds/` |
| Voicemail, recordings, call files | `/var/spool/asterisk/` |
| Logs | `/var/log/asterisk/` — `full` is the one you will read |
| The source you built from | `/usr/src/asterisk-22.10.0` |

Worth knowing now: to *upgrade* Asterisk later you unpack a newer source tree and repeat
Steps 2 to 5. `/etc/asterisk` is not touched by `make install`, so your configuration
survives. That is one of the real arguments for building from source.

---

**Next:** Lab 2 — you open `pjsip.conf`, create two extensions, and register your first
softphone.
