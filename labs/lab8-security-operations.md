# Lab 8: Lock It Down and Keep It Running

**Time:** ~60 minutes
**Prerequisites:** Lab 7 — CDRs land in MariaDB and ARI answers.

Your PBX can now place calls out through a trunk, on an account that costs money. That
makes it a target. Toll fraud is not a hypothetical: attackers scan the internet
continuously for SIP ports, and a PBX found with a weak password can carry thousands of
pounds of international calls before anyone notices — usually over a weekend.

Everything here happens on the machine, not in Asterisk's configuration: the service
manager that restarts it, the firewall in front of it, the jail that bans an attacker,
the backup you restore from. This is the part of running a PBX that has nothing to do
with telephony and everything to do with whether the phones work on Monday.

You will attack your own PBX, watch it get broken into, then stop it.

---

## Step 1 — See the attack surface

```bash
sudo ss -lnptu | grep -E 'asterisk|:5060|:5061|:8088|:8089|:5038'
```

**You should see** Asterisk listening on 5060/UDP (SIP), 5061/TCP (TLS), 8088 and 8089
(HTTP/ARI/WSS), and 5038 on **127.0.0.1** only (AMI, from Lab 7).

Every one of those is a way in. Ask of each: *does this need to be reachable from the
whole network?*

- **5060** — yes, phones need it
- **8088/8089** — only if you use ARI or WebRTC
- **5038** — no. It is on loopback already, which is why that was the right default.

---

## Step 2 — Break into your own PBX

Before defending it, see the attack. `sipp` is already installed.

Watch the log in one terminal:

```bash
sudo tail -f /var/log/asterisk/messages.log
```

In another, register-scan with a wrong password, the way a scanner does:

```bash
for u in 1000 1001 6001 6002 admin; do
  timeout 3 sipp -sn uac 127.0.0.1 -s "$u" -m 1 -r 5 -trace_err 2>/dev/null
done
echo "scan finished"
```

Now ask Asterisk what it saw:

```bash
sudo asterisk -rx 'pjsip show endpoints' | head -5
```

**The problem:** by default, this leaves almost no trace. A stock Asterisk does not log
failed authentication anywhere useful, so an attacker can try thousands of passwords in
silence.

Turn on the security log — this is the single most valuable line in this lab.

Edit `/etc/asterisk/logger.conf` and add to `[logfiles]`:

```ini
security => security
```

```bash
sudo asterisk -rx 'logger reload'
```

Run the scan again, then:

```bash
sudo cat /var/log/asterisk/security
```

**You should see** structured security events — `InvalidAccountID`, `ChallengeSent`,
`InvalidPassword` — each with the source address:

```
SecurityEvent="InvalidAccountID",EventTV=...,Severity="Error",Service="PJSIP",
RemoteAddress="IPV4/UDP/127.0.0.1/5060",AccountID="admin"
```

**That file is what fail2ban reads.** Without it, fail2ban has nothing to work with — and
this is the step most guides omit.

---

## Step 3 — Ban the attacker automatically

fail2ban was installed in Lab 0 and deliberately left switched off. Now configure it.

`/etc/fail2ban/jail.d/asterisk.conf`:

```ini
[asterisk]
enabled  = true
port     = 5060,5061
protocol = udp
filter   = asterisk
logpath  = /var/log/asterisk/security
maxretry = 3
findtime = 300
bantime  = 3600
backend  = auto
```

Read those four numbers as a sentence: **3 failures within 300 seconds gets you banned
for 3600 seconds.**

Choosing them is a judgement call. Too strict and a user with a stale saved password
locks out their whole office, because everyone shares one public IP. Too loose and a
patient attacker walks through. `3 / 5 min / 1 hour` is a reasonable starting point for a
system with human users.

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status asterisk
```

**You should see:**

```
Status for the jail: asterisk
|- Filter
|  `- File list:	/var/log/asterisk/security
`- Actions
   `- Currently banned:	0
```

> **`restart`, not `enable --now`.** If fail2ban is already running — and on Ubuntu it
> often is — `--now` does nothing, your new jail is never read, and
> `fail2ban-client status asterisk` answers **"Sorry but the jail 'asterisk' does not
> exist"** while the service sits there reporting `active`. Check with
> `sudo fail2ban-client status`: the jail list must contain `asterisk`, not just `sshd`.
>
> The `File list:` line is the other thing to confirm. If it is missing, fail2ban is not
> reading Asterisk's security log and will never ban anyone, no matter how hard you are
> attacked.

### Now attack it again

```bash
for i in 1 2 3 4 5; do
  timeout 3 sipp -sn uac 127.0.0.1 -s 9999 -m 1 -r 5 2>/dev/null
  sleep 1
done
sudo fail2ban-client status asterisk
```

**You should see** the failure count rise and — because this comes from `127.0.0.1`, which
fail2ban ignores by default — no ban. That is correct behaviour and worth understanding:
loopback is in `ignoreip`, so you cannot ban yourself by accident.

To see a real ban, attack from your own computer instead. From **your machine**, using a
softphone configured with the right username and a deliberately **wrong password**, try to
register four or five times. Then on the VM:

```bash
sudo fail2ban-client status asterisk
sudo iptables -L f2b-asterisk -n
```

**You should see** your computer's address under `Currently banned`, and a `REJECT` rule
for it in the `f2b-asterisk` chain. Your softphone can no longer reach the PBX at all.

Unban yourself:

```bash
sudo fail2ban-client set asterisk unbanip <your-computer-ip>
```

> **The lesson:** fail2ban does not protect Asterisk. It reads Asterisk's log and edits
> the *firewall*. If the security log is not enabled, or the path in `logpath` is wrong,
> fail2ban will sit there reporting zero failures forever while you are being attacked.
> Always verify with a real failed login, exactly as you just did.

---

## Step 4 — A firewall that fails closed

fail2ban blocks who has already misbehaved. A firewall decides who may talk to you at all.

```bash
sudo tee /etc/iptables/rules.v4 >/dev/null <<'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Established traffic and loopback always allowed.
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -i lo -j ACCEPT

# Diagnostics.
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH — restrict the source on a real server.
-A INPUT -p tcp --dport 22 -j ACCEPT

# SIP and RTP from the local network only.
-A INPUT -s 192.168.0.0/16 -p udp --dport 5060 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp --dport 5061 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p udp --dport 10000:20000 -j ACCEPT

# The PSTN gateway must reach us for inbound calls.
-A INPUT -s 74.50.97.11/32 -p udp --dport 5060 -j ACCEPT

# ARI / WebRTC, local network only.
-A INPUT -s 192.168.0.0/16 -p tcp --dport 8088 -j ACCEPT
-A INPUT -s 192.168.0.0/16 -p tcp --dport 8089 -j ACCEPT

COMMIT
EOF
```

The important line is the first: **`:INPUT DROP`**. The default is to refuse. Everything
after it is an exception you chose. A firewall whose default is ACCEPT with a list of
blocks is not a firewall — you will always forget something.

> **Before you apply this, read it again.** `-A INPUT -p tcp --dport 22 -j ACCEPT` is the
> line that keeps your SSH session alive. Removing or mistyping it locks you out of a
> remote server permanently. On a real machine, always have console access before
> touching the firewall.

Apply and verify:

```bash
sudo iptables-restore < /etc/iptables/rules.v4
sudo iptables -L INPUT -n --line-numbers | head -12
```

**You should see** the policy `DROP` and your rules. Your SSH session should still be
alive — if it froze, you made a mistake, and the VM console is how you recover.

Confirm calls still work: register a phone and dial `600`.

Make it survive reboot:

```bash
sudo netfilter-persistent save
sudo systemctl enable netfilter-persistent
```

> **Why the gateway needs its own rule:** inbound calls arrive from `74.50.97.11`, not
> from your LAN. Without that line, outbound calls work and inbound ones silently vanish
> — a genuinely confusing half-working state.

---

## Step 5 — Make the service behave under systemd

You copied a unit file in Lab 1 and never looked inside it. Now read it:

```bash
systemctl cat asterisk
```

Two lines are load-bearing, and one of them cost real debugging time to discover:

| Line | Why |
|---|---|
| `RuntimeDirectory=asterisk` | Creates `/run/asterisk` owned by the `asterisk` user at every boot. `/run` is tmpfs, so it does not survive. **Without this, Asterisk starts, reports `active (running)`, and the CLI is completely unreachable** — a healthy-looking service you cannot talk to. |
| `AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_SYS_NICE` | Lets a non-root process bind low ports and raise RTP thread priority. It is what makes running as the `asterisk` user possible at all. |

Add restart limits so a crash loop does not hammer the machine:

```bash
sudo systemctl edit asterisk
```

In the editor:

```ini
[Service]
Restart=on-failure
RestartSec=5
StartLimitBurst=5
StartLimitIntervalSec=300
```

```bash
sudo systemctl daemon-reload
sudo systemctl restart asterisk
systemctl show asterisk -p Restart -p RestartUSec -p StartLimitBurst
```

Prove it recovers:

```bash
sudo pkill -9 asterisk
sleep 8
systemctl status asterisk --no-pager | head -4
```

**You should see** it `active (running)` again, restarted by systemd. That is the
difference between an outage and a five-second blip at 3am.

---

## Step 6 — Back it up, and prove the backup

An untested backup is a rumour.

```bash
sudo tee /usr/local/bin/asterisk-backup >/dev/null <<'EOF'
#!/usr/bin/env bash
# Back up everything needed to rebuild this PBX's behaviour.
set -euo pipefail
DEST="/var/backups/asterisk"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "${DEST}"

tar czf "${DEST}/config-${STAMP}.tar.gz" /etc/asterisk 2>/dev/null

# Voicemail messages and recordings are user data, not configuration.
tar czf "${DEST}/spool-${STAMP}.tar.gz" \
    /var/spool/asterisk/voicemail /var/spool/asterisk/monitor 2>/dev/null || true

# CDRs live in the database, so they need a dump of their own.
mariadb-dump --single-transaction asterisk > "${DEST}/cdr-${STAMP}.sql" 2>/dev/null || true

# Keep 14 days.
find "${DEST}" -type f -mtime +14 -delete

echo "backup complete: ${DEST}/*-${STAMP}.*"
ls -lh "${DEST}" | tail -4
EOF
sudo chmod +x /usr/local/bin/asterisk-backup
sudo /usr/local/bin/asterisk-backup
```

**You should see** three files listed.

Note what is backed up and what is not: **configuration, user data, and the database**.
Not the Asterisk binaries — those you rebuild from source, which is why Lab 1 mattered.

### Now restore it, for real

The only way to know a backup works:

```bash
# Break something on purpose.
sudo mv /etc/asterisk/pjsip.conf /tmp/pjsip.saved
sudo systemctl restart asterisk
sleep 5
sudo asterisk -rx 'pjsip show endpoints'
```

**You should see** `No objects found.` — every endpoint gone.

> **`restart`, not `module reload`.** Deleting the file and reloading proves nothing:
> Asterisk keeps the configuration it already has in memory, so all your endpoints stay
> exactly where they were and the "test" passes while the file is in the bin. Only a
> restart forces a read from disk.
>
> This is the same behaviour you met in Lab 2 Part I, and it cuts both ways — it protects
> you from a bad edit, and it will happily fool you into believing an untested backup
> works.

Now restore just that file from the archive:

```bash
LATEST=$(ls -t /var/backups/asterisk/config-*.tar.gz | head -1)
sudo tar xzf "$LATEST" -C / etc/asterisk/pjsip.conf
sudo systemctl restart asterisk
sleep 5
sudo asterisk -rx 'pjsip show endpoints'
```

**You should see** your endpoints return. Now schedule it:

```bash
echo '30 2 * * * root /usr/local/bin/asterisk-backup >> /var/log/asterisk-backup.log 2>&1' \
  | sudo tee /etc/cron.d/asterisk-backup
```

---

## Step 7 — Know when it breaks before your users do

```bash
sudo tee /usr/local/bin/asterisk-health >/dev/null <<'EOF'
#!/usr/bin/env bash
# Five questions worth asking every minute.
fail=0
say() { printf '%-28s %s\n' "$1" "$2"; }

systemctl is-active --quiet asterisk \
  && say "service:" "running" || { say "service:" "DOWN"; fail=1; }

asterisk -rx 'core show version' >/dev/null 2>&1 \
  && say "cli:" "responding" || { say "cli:" "UNREACHABLE"; fail=1; }

reg=$(asterisk -rx 'pjsip show registrations' 2>/dev/null | grep -c 'Registered')
[ "$reg" -gt 0 ] && say "trunk registrations:" "$reg" \
  || { say "trunk registrations:" "NONE — no inbound or outbound calls"; fail=1; }

peers=$(asterisk -rx 'pjsip show aors' 2>/dev/null | grep -cE '^ +Contact:  [^<]')
say "registered phones:" "$peers"

calls=$(asterisk -rx 'core show channels' 2>/dev/null | awk '/active call/{print $1}')
say "active calls:" "${calls:-0}"

df -h /var | awk 'NR==2 {print "disk /var:                   " $5 " used"}'
exit $fail
EOF
sudo chmod +x /usr/local/bin/asterisk-health
sudo /usr/local/bin/asterisk-health
```

**You should see** all five green, and a non-zero exit if anything is wrong — which is
what makes it usable from cron, Nagios, or any monitoring system.

The **trunk registration** check is the one people leave out and regret. A PBX whose trunk
has silently dropped looks perfectly healthy: the service runs, phones register, internal
calls work. Nobody notices until a customer says "I have been ringing you all morning."

Finally, keep the logs from filling the disk. You ran `make install-logrotate` in Lab 1;
confirm it took:

```bash
cat /etc/logrotate.d/asterisk
sudo logrotate -d /etc/logrotate.d/asterisk 2>&1 | head -12
```

**You should see** a dry run showing which files would rotate. A PBX taken down by a full
`/var` after a year of uptime is a classic, and entirely preventable.

---

## ✅ Checkpoint

1. `/var/log/asterisk/security` records failed authentication attempts with source addresses
2. `fail2ban-client status asterisk` shows the jail active and reading that file
3. A real wrong-password attempt from your own computer gets that address banned, and a `REJECT` rule appears in `f2b-asterisk`
4. `iptables -L INPUT` shows policy **DROP**, calls still work, and rules survive `netfilter-persistent save`
5. `pkill -9 asterisk` is followed by systemd restarting it within seconds
6. A backup can be taken; deleting `pjsip.conf` **and restarting** empties the endpoints, and restoring from the archive brings them back
7. `asterisk-health` reports service, CLI, trunk, phones, calls and disk, and exits non-zero when the trunk is down

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `/var/log/asterisk/security` never appears | `security => security` not added, or logger not reloaded | Add it under `[logfiles]` in logger.conf, then `asterisk -rx 'logger reload'`. |
| fail2ban shows 0 failures during a real attack | Wrong `logpath`, or the file is empty | `sudo fail2ban-client get asterisk logpath`, then `tail -f` that exact file while attacking. |
| fail2ban will not start | Syntax error in the jail | `sudo fail2ban-client -d` prints the parsed config. |
| `the jail 'asterisk' does not exist`, but the service is `active` | fail2ban was already running and never re-read your config | `sudo systemctl restart fail2ban`, then `sudo fail2ban-client status` — the jail list must include `asterisk`. |
| You cannot ban yourself from the VM | `127.0.0.1` is in `ignoreip` | Correct and deliberate. Attack from another machine to test. |
| SSH froze after applying iptables | The SSH ACCEPT rule is missing or wrong | Get to the console the firewall cannot block — the VirtualBox window, or on a cloud server **Droplet → Access → Launch Recovery Console** — then `sudo iptables -P INPUT ACCEPT` to recover. |
| Inbound trunk calls stop after the firewall | No rule for the gateway address | Add `-A INPUT -s 74.50.97.11/32 -p udp --dport 5060 -j ACCEPT`. Confirm the current address with `getent hosts sip.flagonc.com`. |
| Rules vanish after reboot | Not saved | `sudo netfilter-persistent save` and enable the service. |
| systemd will not restart after repeated crashes | Start limit hit | `sudo systemctl reset-failed asterisk`. Then find out why it is crashing. |
| Restore did not bring endpoints back | Extracted to the wrong place | The archive stores paths relative to `/`, so extract with `-C /`. |

---

## What you have, at the end

A PBX that:

- runs as an unprivileged user under systemd, and restarts itself when it dies
- logs authentication failures, and bans the sources automatically
- refuses everything by default at the firewall, and permits only what you listed
- is backed up nightly, with a restore you have actually performed
- tells you when its trunk drops, before a customer does

That is the difference between something that works on your laptop and something you can
put in front of a business.

---

**This is the last lab.** Your machine still runs everything you built — extensions,
trunk, IVR, queues, browser phone, database CDRs, ARI application. Keep it. It is the
fastest way to test an idea before you try it on a system that matters.
