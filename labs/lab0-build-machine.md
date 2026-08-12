# Lab 0: Build Your Lab Machine

**Time:** 20 minutes (Path A) · about an hour (Path B) · 25 minutes (Path C)
**You need:** 4 GB of free RAM and 20 GB of free disk on a Windows, Linux or Intel Mac
computer — or, on an Apple Silicon Mac, a cloud account and roughly US$25 for the month
you spend on the course.
**Prerequisites:** none — this is the first thing you do.

The last few lessons told you Asterisk runs on Ubuntu 24.04 LTS Server. They did not
tell you where that Ubuntu is going to live. That is this lab.

You are going to build one Linux server and keep it for the rest of the course. You
install Asterisk on it in Lab 1, configure phones on it in Lab 2, and you are still using
the same machine in the security and operations labs at the end.

Nothing here touches your own operating system.

---

## Step 1 — Choose your path

Three ways to get the lab machine. **They end at exactly the same place** — an Ubuntu
24.04 server with the Asterisk source waiting to be built.

| | **Path A — Ready-made VM** | **Path B — Build the VM yourself** | **Path C — A server in the cloud** |
|---|---|---|---|
| Runs on | Windows, Linux, Intel Mac | Windows, Linux, Intel Mac | **any computer, including Apple Silicon Macs** |
| Time | ~15 minutes | ~50 minutes | ~25 minutes |
| Cost | free | free | ~US$25/month, billed hourly |
| Download | 776 MB appliance | 3.2 GB Ubuntu ISO | nothing |
| You do | Import and start it | Install Ubuntu, then run one script | Create a server, lock it down, run one script |
| Good if | You want to get to Asterisk today | You want to have installed a Linux server yourself | You are on a Mac, or your computer has no RAM to spare |

Paths A and B use VirtualBox on your own computer. Path B is the one the last lessons
described — you install the operating system, exactly as you would on a real server.

**If you have never installed Linux, take Path B once.** You will meet a real Ubuntu
installer, partitioning, and a first boot, and none of that will be mysterious the next
time. If you are short on time, Path A loses you nothing that later labs depend on.

> ### On a Mac? It depends which Mac.
>
> Check first:  **→ About This Mac**. If it says **Chip: Apple M1/M2/M3/M4**, you have
> an Apple Silicon Mac. If it says **Processor: Intel**, you have an Intel Mac.
>
> **Intel Mac — use Path A or B like everybody else.** VirtualBox has a macOS/Intel
> build on the same download page, and every instruction below applies unchanged.
>
> **Apple Silicon Mac — take Path C.** VirtualBox's macOS/Arm64 build is an unsupported
> developer preview that runs arm64 guests only, and the ready-made appliance is an
> x86-64 image, so there is nothing to import and nothing to fall back on. **This course
> does not support running the lab on Apple Silicon.** Rent a Linux server for the
> duration instead — same Ubuntu, a few dollars, destroy it when you are done. Path C is
> written for exactly this.
>
> Parallels Desktop, VMware Fusion and UTM *will* run an **arm64** Ubuntu 24.04 on
> Apple Silicon, and Asterisk does build from source on arm64. That route is not tested
> for this course and no lab assumes it: you would be doing Path B with the arm64
> installer image and sorting out any architecture differences yourself. Nothing stops
> you — but if it breaks, the course cannot help you.

Jump to **Path A**, **Path B** or **Path C** below. Paths A and B then continue at
**Step 3**; Path C goes straight to **Step 4**.

---

## Step 2 — Install VirtualBox *(Paths A and B only — Path C, skip to Path C)*

VirtualBox is the program that runs virtual machines. Download it for your operating
system from <https://www.virtualbox.org/wiki/Downloads> and install with the defaults.
Take **Windows hosts**, **Linux distributions**, or **macOS / Intel hosts** — *not* the
macOS / Arm64 developer preview, which cannot run this machine. Your network will drop
for a second during installation — that is normal, it is inserting a virtual network
adapter.

Check it worked — **PowerShell** (Windows) or **Terminal** (macOS/Linux):

```
VBoxManage --version
```

**You should see** **7.2 or higher**, for example `7.2.14r170000`.

> **Do not skip this.** Older VirtualBox releases have emulation bugs that crash the
> *guest kernel*, not Asterisk — and they look like the lab is broken. Building this
> course on 7.1.6 produced three separate kernel-level failures: a panic in the emulated
> Intel network card, a fault in an AVX routine that hung boot, and an RCU stall that
> froze the machine. All three are hypervisor bugs. The image works around the first two,
> but running a current VirtualBox is the real fix.

> Windows, "command not found"? Use the full path:
> `& "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version`

---

# Path A — Download the ready machine

### A1. Download

Download **`asterisk-lab-base-1.0.ova`** — **776 MB**:

<https://pub-d6afaeeb01b74b1eb49d4564ab14ee61.r2.dev/asterisk-lab-base-1.0.ova>

Or from a terminal, which is easier to resume if the connection drops:

```
curl -L -O -C - https://pub-d6afaeeb01b74b1eb49d4564ab14ee61.r2.dev/asterisk-lab-base-1.0.ova
```

It is Ubuntu 24.04 LTS Server with the Asterisk build dependencies already installed and
the Asterisk 22.10.0 source already unpacked — but **Asterisk itself is not installed**.
Installing it is Lab 1, and you do that yourself.

Check the download arrived intact:

```
certutil -hashfile asterisk-lab-base-1.0.ova SHA256      # Windows
shasum -a 256 asterisk-lab-base-1.0.ova                   # macOS / Linux
```

**You should see** exactly this:

```
4a3fe749cc4edad5eba7c8ce6ede07e2d9d1c188f3a871da5a0f19c692aef25c
```

If it differs by a single character, the download is damaged — delete it and fetch it
again. A truncated appliance imports without complaint and then fails to boot, which is
a miserable way to spend an evening.

### A2. Import

Double-click the `.ova`, or in VirtualBox choose **File → Import Appliance** and select
it. Accept the defaults and click **Import**. A minute or two.

> **Do not start it yet.** The appliance ships with its network adapter set to NAT,
> because a *bridged* adapter has to name a network card on **your** computer and there is
> no way to know that in advance. Step 3 sets it. If you start it first, it boots with no
> reachable address and `lab ip` will show `10.0.2.15` — the NAT placeholder, which no
> softphone can call.

Now go to **Step 3**.

---

# Path B — Build it yourself

### B1. Download the Ubuntu installer

Download **`ubuntu-24.04.x-live-server-amd64.iso`** (about 3.2 GB) from
<https://releases.ubuntu.com/24.04/> — take the newest point release listed.

Take the **live-server** image, not Desktop. Asterisk should not share a machine with a
graphical desktop — the lessons made that point, and this is where you act on it.

### B2. Create the virtual machine

In VirtualBox click **New**, then:

| Setting | Value |
|---|---|
| Name | `asterisk-lab` |
| Type / Version | Linux / Ubuntu (64-bit) |
| ISO Image | the ISO you just downloaded |
| Skip Unattended Installation | **tick this box** |
| Memory | **4096 MB** |
| Processors | **2** (more if you have them — Lab 1 compiles faster) |
| Disk | **20 GB** |

Ticking *Skip Unattended Installation* matters: you want to see the installer, which is
the entire point of this path.

Click **Finish**, then **Start**.

### B3. Install Ubuntu

The installer boots. Work through it — the defaults are right nearly everywhere.

| Screen | What to choose |
|---|---|
| Language / keyboard | Yours |
| Type of install | **Ubuntu Server** (not minimized) |
| Network | Leave it — DHCP. Note the address it shows; you will meet it again. |
| Proxy / mirror | Leave blank / default |
| Storage | **Use an entire disk**, then **Done** and **Continue** to confirm |
| Profile | Your name; server name **`asterisk-lab`**; username **`lab`**; password **`lab`** |
| Ubuntu Pro | **Skip for now** |
| SSH | **Tick "Install OpenSSH server"** — you will want this |
| Featured snaps | Select none |

> Use `lab` / `lab` exactly. Every later lab refers to that username. This machine is a
> disposable lab on your own network, not a server.

Installation takes 10–20 minutes. When it finishes, choose **Reboot Now**. If it hangs
asking you to remove the installation medium, just press **Enter**.

Log in as `lab`.

### B4. Update, then run the lab setup

```bash
sudo apt-get update && sudo apt-get -y upgrade
```

Then fetch the lab setup and run it:

```bash
sudo apt-get install -y git
git clone https://github.com/flaviogoncalves/asterisk-guide.git
sudo ./asterisk-guide/lab-vm/provision.sh base
```

This takes about 10 minutes. It installs the build dependencies from the lesson's
package list, installs the tools later labs need (`sngrep`, `sipp`, `tcpdump`,
`fail2ban`), downloads and unpacks the Asterisk 22.10.0 source, and installs the `lab`
helper command.

**It does not install Asterisk.** That is Lab 1, and it is yours to do.

**You should see** it finish with:

```
==> Stage 'base' complete — Asterisk source staged in /usr/src/asterisk-22.10.0, not built
```

> Curious what it did? Read it — `asterisk-guide/lab-vm/provision.sh` is commented
> throughout and is deliberately the same sequence the lessons describe.

Now go to **Step 3**.

---

# Path C — Rent a server in the cloud

This is the Mac path, and it is a good path on any computer that cannot spare 4 GB of
RAM. You get the same Ubuntu 24.04 server everybody else has — it simply lives in a data
centre instead of in a window, and you reach it over SSH.

The instructions below use **DigitalOcean** because it is the simplest. Vultr, Hetzner,
Linode and AWS Lightsail all work the same way; only the buttons differ.

> **The one real difference from Paths A and B.** Your lab has a public address on the
> internet. A PBX on a public address is scanned by attackers within minutes of coming
> up — that is not a scare story, it is what the security lab has you read in your own
> logs. Step **C2** is not optional, and it comes *before* you install anything.

### C1. Create the server

Sign in to <https://www.digitalocean.com>, then **Create → Droplets**:

| Setting | Value |
|---|---|
| Region | the one nearest you — this is your audio latency |
| Image | **Ubuntu 24.04 (LTS) x64** |
| Droplet type | **Basic**, Regular (SSD) |
| Size | **4 GB RAM / 2 vCPUs** — 2 GB works but Lab 1's compile is slow; 1 GB is not enough |
| Authentication | **SSH key** if you have one, otherwise a password you choose |
| Hostname | `asterisk-lab` |

Click **Create Droplet**. Half a minute later the control panel shows its **public IPv4
address**. Write that down — everywhere the course says `<your-lab-ip>`, this is it.

> **Billing.** Droplets are billed by the hour for as long as they exist — *including
> while powered off*. At 4 GB / 2 vCPUs that is roughly US$24 a month at the time of
> writing; check the current price on the size selector. When you finish the course,
> **destroy** the droplet (not just power it off). Costs nothing to recreate later.

### C2. Lock it down — before you install anything

First, find the two addresses your firewall must allow.

**Your own computer's public address**, from a terminal on *your* computer:

```
curl -4 ifconfig.me
```

**The lab's simulated PSTN gateway**, which Lab 3 registers to and which sends calls
back to you:

```
getent hosts sip.flagonc.com
```

**You should see** `74.50.97.11`. Use whatever it prints today.

Now in DigitalOcean go to **Networking → Firewalls → Create Firewall**, name it
`asterisk-lab`, and set the **inbound** rules to exactly this — nothing else:

| Type | Protocol | Port range | Sources |
|---|---|---|---|
| SSH | TCP | `22` | your public IP |
| Custom | UDP | `5060` | your public IP, `74.50.97.11` |
| Custom | UDP | `10000-10200` | your public IP, `74.50.97.11` |
| Custom | TCP | `8088-8089` | your public IP |

Leave the **outbound** rules at their defaults (all traffic allowed) — Asterisk has to
reach the gateway and the package archives.

Under **Apply to Droplets**, choose `asterisk-lab`. Create.

That is SIP signalling, the RTP media range from `lab.env`, and the HTTP/WebSocket ports
Labs 6 and 7 use — each one reachable only from you, and 5060 also from the gateway so
inbound trunk calls arrive.

> **Home addresses change.** If your ISP hands you a new one, every single thing stops
> working at once — SSH included. Re-run `curl -4 ifconfig.me` and update the firewall's
> sources. If you are locked out, DigitalOcean's **Droplet → Access → Launch Recovery
> Console** gets you in over the web regardless of the firewall. That console is your
> equivalent of the VirtualBox window, and Lab 8 will remind you of it.

### C3. Create the `lab` user

Connect as root, using the address from C1:

```
ssh root@<your-lab-ip>
```

Every lab from here on assumes the user `lab`, so create it:

```bash
adduser lab                 # password: lab
usermod -aG sudo lab
```

If you used an SSH key in C1, copy it across so you can log in as `lab` directly:

```bash
rsync --archive --chown=lab:lab ~/.ssh /home/lab
```

Then become that user — or log out and back in as `ssh lab@<your-lab-ip>`:

```bash
su - lab
```

### C4. Run the lab setup

```bash
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get install -y git
git clone https://github.com/flaviogoncalves/asterisk-guide.git
sudo ./asterisk-guide/lab-vm/provision.sh base
```

Same script, same ten minutes, same result as Path B — build dependencies, the lab
tooling (`sngrep`, `sipp`, `tcpdump`, `fail2ban`), the Asterisk 22.10.0 source unpacked,
and the `lab` command.

**You should see** it finish with:

```
==> Stage 'base' complete — Asterisk source staged in /usr/src/asterisk-22.10.0, not built
```

**Skip Step 3** — there is no virtual network adapter to change. Your server already has
its own public address, and no NAT sits between it and your softphone, which is exactly
the arrangement Step 3 builds for the other two paths. Go straight to **Step 4**.

---

# Step 3 — Put the machine on your network *(Paths A and B)*

**This step is why the appliance ships on NAT — do it before the first boot.**

If you already started the machine, shut it down first (`sudo poweroff`, or the VirtualBox
window's close button → *Power off*). Then select **asterisk-lab** → **Settings** →
**Network** → **Adapter 1**:

| Setting | Value |
|---|---|
| Attached to | **Bridged Adapter** |
| Name | the network card your computer is actually using — the wifi or ethernet adapter |

**Bridged** puts the VM on your network as though it were a separate physical computer
plugged into the same switch. It gets its own address from your router, exactly as a
real PBX would. Your softphone reaches it there — and so can a real desk phone on the
same network, if you have one.

> **Not NAT.** VirtualBox defaults to NAT, which hides the VM behind your computer and
> makes incoming SIP unreachable. When a phone will not register in Lab 2, this setting
> is the first thing to check.

Click **OK** and **Start** the machine.

---

# Step 4 — Confirm the machine is what you think it is

Log in as `lab` (password `lab` on Paths A and B; whatever you set on Path C). Four
questions worth answering before you build anything on it.

> **Paths A and B:** the VM window captures your mouse when you click in it. Release it
> with the **Host key** — **Right Ctrl** on Windows/Linux, **Left ⌘** on an Intel Mac.
> It is shown in the bottom-right of the window.

**Which Ubuntu is this?**

```bash
lsb_release -d
```

**You should see** `Description: Ubuntu 24.04.x LTS` — the distribution the lessons
specified.

**What is my IP address?** This is the most important thing to come out of this lab.
Write it down; every later lab needs it.

```bash
lab ip
```

**You should see** an address, and the line you will need in Lab 2:

```
192.168.1.47

Point your softphone at: 192.168.1.47:5060 (UDP)
```

Yours will differ — on Paths A and B it is whatever your router handed out; on Path C it
is your server's public address. Wherever the course says **`<your-lab-ip>`**, this is
the number.

> Paths A and B: nothing, or an address starting `10.0.2.`? Adapter 1 is still on NAT.
> Shut down, fix it as in Step 3, start again.
>
> Path C: it must match the public IPv4 address in your provider's control panel. If it
> prints a `10.` address instead, use the panel's public address for the rest of the
> course.

**Can it reach the internet?**

```bash
ping -c 3 downloads.asterisk.org
```

**You should see** replies.

**Is Asterisk installed?** It should not be — that is the point.

```bash
asterisk -V
```

**You should see** `asterisk: command not found`. Correct. There is no PBX here yet.

Now look at what is waiting:

```bash
ls /usr/src/asterisk-22.10.0
```

**You should see** the unpacked source — `configure`, `Makefile`, `channels/`, `apps/`.
The same tarball the lessons told you to `wget`, already downloaded so a slow network
cannot end your lab twenty minutes in. In Lab 1 you build it.

---

## ✅ Checkpoint

Whichever path you took, you are finished when all four are true:

1. You are logged in as `lab`
2. `lsb_release -d` reports **Ubuntu 24.04**
3. `lab ip` prints an address you can reach from your own computer, and you have written
   it down
4. `asterisk -V` says **command not found**, and `/usr/src/asterisk-22.10.0` exists

Point 4 is not a failure. You have built a server. You have not built a PBX.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "VT-x is disabled in the BIOS", VM will not start | Hardware virtualization is off | Reboot into BIOS/UEFI and enable **Intel VT-x** or **AMD-V**. On Windows also run `bcdedit /set hypervisorlaunchtype off` as administrator and reboot — Hyper-V and VirtualBox compete for the same hardware. |
| VM is very slow | Too little RAM or one CPU | **Settings → System**: 4096 MB, 2+ processors. |
| VM freezes, panics, or hangs at boot with kernel messages | Almost always an old VirtualBox, not Asterisk | Check `VBoxManage --version`. Anything below **7.2** is worth upgrading before you debug anything else — these show up as `Kernel panic`, `BUG: unable to handle`, or `rcu_preempt self-detected stall` on the console. |
| `lab ip` prints nothing, or `10.0.2.15` (Paths A/B) | Adapter 1 still on NAT | **Settings → Network → Adapter 1** → *Bridged Adapter*, pick the card you are really using. Restart. |
| `lab ip` gives an address your computer cannot ping (Paths A/B) | Bridged to the wrong physical card — e.g. ethernet while you are on wifi | Same setting, change **Name**. |
| `lab: command not found` (Paths B/C) | `provision.sh base` did not finish | Re-run it and read the last lines for the error. |
| Path B: installer hangs on "remove installation medium" | Normal | Press **Enter**. If it persists, **Devices → Optical Drives → Remove disk**, then reset the VM. |
| Import fails partway (Path A) | Corrupt download | Re-download and compare the SHA-256 against the one in step A1. |
| Path C: SSH suddenly refuses to connect | Your home IP changed and the firewall no longer allows it | `curl -4 ifconfig.me` on your computer, update the firewall sources. Locked out entirely: **Droplet → Access → Launch Recovery Console**. |
| Path C: `lab ip` shows a `10.` address | It picked the provider's private/anchor interface | Use the public IPv4 address shown in the control panel wherever the labs say `<your-lab-ip>`. |
| VirtualBox installs on an Apple Silicon Mac but the appliance will not import, or the VM will not start | The macOS/Arm64 build is an unsupported preview and runs arm64 guests only; the appliance is x86-64 | Not fixable — take **Path C**. Skip Step 2 entirely; Path C needs nothing on your Mac but the SSH client macOS already has. |

---

## Working comfortably (optional, recommended)

*Paths A and B:* the VirtualBox console window has no scrollback and no copy-paste. From
Lab 1 on you will be reading long build output, so connect over SSH from your own
terminal instead:

```
ssh lab@<your-lab-ip>
```

Password `lab`. You get scrollback, copy-paste, and a resizable window. The VM must be
running, but you can then minimise it and forget about it.

*Path C:* you are already doing this — that is all a cloud server ever gives you.

---

**Next:** Lab 1 — you install Asterisk 22 on this machine, by hand, following the
sequence from the last two lessons.

To finish a session: `sudo poweroff` on Paths A and B, then **Start** the machine in
VirtualBox next time. On Path C leave it running — and when you reach the end of the
course, **destroy** the droplet so it stops billing.
