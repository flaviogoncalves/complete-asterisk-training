# Asterisk Guide — Hands-On Lab Manual

A companion workbook to *Asterisk Guide* (2nd edition, Asterisk 22 LTS), and the lab
track of the **Asterisk Black Belt Academy** course. Both read from these files — there
is one set of labs, not two.

Every lab runs on **one Linux server you build in Lab 0** and keep for the rest of the
course — a virtual machine on your own computer, or, on an Apple Silicon Mac, a cheap
cloud server. It is a real Ubuntu 24.04 LTS server running a real Asterisk 22 under
systemd. Everything you learn on it — `systemctl`, `/etc/asterisk`, `asterisk -rvvv` —
is what you would type on a customer's server.

Work through them in order. Each one starts from the verified end-state of the last, and
ends with a checkpoint you can see or hear.

---

## The labs

| # | Lab | Covers | Time |
|---|---|---|---|
| 0 | [Build Your Lab Machine](lab0-build-machine.md) | VirtualBox or a cloud server, Ubuntu 24.04, networking | 20–50 min |
| 1 | [Install Asterisk 22 From Source](lab1-install.md) | configure, menuselect, make, systemd | 25 min |
| 2 I | [Create SIP Extensions](lab2-part1-extensions.md) | transports, endpoints, auth, AORs | 30 min |
| 2 II | [Register Softphones, First Call](lab2-part2-softphones.md) | REGISTER, digest auth, first dialplan | 35 min |
| 3 | [Connect a SIP Trunk](lab3-trunk.md) | outbound registration, identify, toll-fraud contexts | 30 min |
| 4 | [Build a Real Dialplan](lab4-dialplan.md) | patterns, DIALSTATUS, IVR, context security, time routing | 45 min |
| 5 | [Voicemail, Transfers and a Call Queue](lab5-features-queues.md) | voicemail, transfer, park, pickup, MOH, queues | 50 min |
| 6 | [See What SIP Actually Sends](lab6-sip-in-depth.md) | sngrep, SDP, codecs, NAT, WebRTC, TLS/SRTP | 55 min |
| 7 | [Make Asterisk Talk to Your Own Code](lab7-programmability.md) | CDR to MariaDB, AMI, AGI, ARI/Stasis | 55 min |
| 8 | [Lock It Down and Keep It Running](lab8-security-operations.md) | security log, fail2ban, iptables, systemd, backup, monitoring | 60 min |

Labs 6, 7 and 8 each deliberately cover more than one chapter. Reading about codec
negotiation does not need a checkpoint; *capturing a call and reading its SDP* does — and
that is one lab, not ten.

---

## Lab credentials and quick reference *(keep this page open)*

Everything you need is here. You will not have to invent a username or password.

### Your lab machine

| | |
|---|---|
| Login | `lab` / `lab` |
| Address | run `lab ip` on the VM — it is assigned by your router |
| Asterisk CLI | `sudo asterisk -rvvv` (leave with `Ctrl-C`) |
| One-off command | `asterisk -rx 'core show version'` |
| Configuration | `/etc/asterisk/` |
| Log | `/var/log/asterisk/messages.log` |
| Restore a working config | `sudo lab reset` |

Wherever a lab says **`<your-lab-ip>`**, use the address `lab ip` printed.

### Softphone accounts

Install a softphone on **your own computer**, not inside the VM:

| Platform | Softphone |
|---|---|
| Windows | **MicroSIP** — <https://www.microsip.org> |
| macOS / Linux | **Linphone** — <https://www.linphone.org> |
| Terminal | **baresip** — `apt install baresip` |

| Account | Password | Who |
|---|---|---|
| `6001` | `Lab-6001-secret` | Alice |
| `6002` | `Lab-6002-secret` | Bob |
| `webrtc-1000` | `Lab-webrtc-secret` | Browser phone (Lab 6) |

- **SIP server / domain:** `<your-lab-ip>`, **port 5060**, transport **UDP**
- **Codecs:** μ-law (PCMU) and A-law (PCMA)

### Numbers you will build

| Number | What it does | Built in |
|---|---|---|
| `6001` / `6002` | The desk phones | Lab 2 |
| `600` | Echo test — proves two-way audio | Lab 2 |
| `800` | Echo test *at the gateway*, over the trunk | Lab 3 |
| `6000` | Auto-attendant (IVR) | Lab 4 |
| `*97` | Collect your voicemail (PIN `1234`) | Lab 5 |
| `700` / `701`–`720` | Park a call / retrieve it | Lab 5 |
| `**` | Pick up a colleague's ringing phone | Lab 5 |
| `6500` | The support queue | Lab 5 |

### Services you switch on later

You create these yourself, in the lab named. They are listed here so you never have to
hunt back through a lab for a password.

| Service | Lab | Login |
|---|---|---|
| Voicemail | 5 | mailbox `6001` / `6002`, PIN `1234`, dial `*97` |
| ARI (REST API) | 7 | `labuser` / `Lab-ari-secret` on port `8088` |
| AMI (manager socket) | 7 | `labami` / `Lab-ami-secret` on `127.0.0.1:5038` |
| CDR database | 7 | MariaDB `asterisk` / `Lab-cdr-secret`, database `asterisk` |

### The simulated PSTN gateway (Lab 3)

A real Asterisk server standing in for the public network. Everyone shares it.

| | |
|---|---|
| Host | `sip.flagonc.com` |
| Port | **`5600`** — not 5060 |
| Account | the number you were assigned, in `1010`–`1050` |
| Password | `supersecret` |
| Free echo test | `*98` |

> Use **your assigned account**. Two students on one number fight over the registration
> and both lose it.

---

## The two commands you will use constantly

```bash
# Run one Asterisk command and come straight back to the shell:
sudo asterisk -rx 'pjsip show endpoints'

# Open the live console — this is where calls narrate themselves:
sudo asterisk -rvvv
```

Throughout this manual, **"run in the Asterisk CLI"** means either of those. **"Edit a
file"** always means a file under `/etc/asterisk/` on the lab VM — save it, then reload
as the lab tells you.

---

## If you get stuck

```bash
lab status     # is the network up, is Asterisk running, who is registered?
lab ip         # this machine's address
lab reset      # put /etc/asterisk back to a known-good state
lab logs       # follow the Asterisk log
lab rescue     # reinstall Asterisk unattended, if your Lab 1 build failed
```

`lab reset` saves your current configuration before replacing it, so it is never
destructive. Being stuck is never the end of the course.

---

## The machine you are building on

One Ubuntu 24.04 LTS server — in VirtualBox on your own computer, or rented from a cloud
provider if you are on an Apple Silicon Mac — with Asterisk 22 installed from source and
managed by systemd. Not a container and not a simulator: the commands you type here are
the commands you would type on a customer's server.

That matters most in the last two labs. `systemctl`, `iptables` and `fail2ban` are a real
part of running a PBX, and they only mean something on a real machine.
