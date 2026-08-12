# Lab 7: Make Asterisk Talk to Your Own Code

**Time:** ~55 minutes
**Prerequisites:** Lab 6 — specifically **Step 5, where you switched on Asterisk's HTTP
server**. ARI is served by it, so if you skipped that part every `curl` in Step 4 will
refuse the connection. Check before you start:

```bash
sudo asterisk -rx 'http show status'
```

**You should see** `Server Enabled and Bound to 0.0.0.0:8088`. If not, go back to Lab 6
Step 5 — it is five lines of `http.conf`.

A PBX that only does what its config file says is a phone system. A PBX other software can
query, drive and extend is infrastructure.

This lab connects Asterisk to four things: a database for call records, a management
socket you can script, a dialplan hook that runs your program, and a REST API that lets
your application control calls directly.

---

## Step 1 — Call records where you can query them

You have been reading CDRs out of a CSV since Lab 2. That is fine for one machine and
useless for reporting.

MariaDB is already installed. Create the database:

```bash
sudo mariadb <<'SQL'
CREATE DATABASE IF NOT EXISTS asterisk;
CREATE USER IF NOT EXISTS 'asterisk'@'localhost' IDENTIFIED BY 'Lab-cdr-secret';
GRANT ALL ON asterisk.* TO 'asterisk'@'localhost';
FLUSH PRIVILEGES;
USE asterisk;
CREATE TABLE IF NOT EXISTS cdr (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  calldate      DATETIME NOT NULL DEFAULT '1900-01-01 00:00:00',
  clid          VARCHAR(80)  NOT NULL DEFAULT '',
  src           VARCHAR(80)  NOT NULL DEFAULT '',
  dst           VARCHAR(80)  NOT NULL DEFAULT '',
  dcontext      VARCHAR(80)  NOT NULL DEFAULT '',
  channel       VARCHAR(80)  NOT NULL DEFAULT '',
  dstchannel    VARCHAR(80)  NOT NULL DEFAULT '',
  lastapp       VARCHAR(80)  NOT NULL DEFAULT '',
  lastdata      VARCHAR(80)  NOT NULL DEFAULT '',
  duration      INT NOT NULL DEFAULT 0,
  billsec       INT NOT NULL DEFAULT 0,
  disposition   VARCHAR(45)  NOT NULL DEFAULT '',
  amaflags      VARCHAR(45)  NOT NULL DEFAULT '',
  accountcode   VARCHAR(20)  NOT NULL DEFAULT '',
  uniqueid      VARCHAR(150) NOT NULL DEFAULT '',
  userfield     VARCHAR(255) NOT NULL DEFAULT '',
  INDEX (calldate), INDEX (src), INDEX (dst)
);
SQL
echo "database ready"
```

> Those indexes are not decoration. A CDR table is the fastest-growing table you will
> own; a year in, an unindexed `WHERE calldate BETWEEN` is a full table scan.

### Connect it through ODBC

Asterisk reaches databases through **unixODBC**, which is why it can talk to MariaDB,
PostgreSQL and SQL Server with the same code. Two files.

`/etc/odbcinst.ini` — describes the *driver*:

```ini
[MariaDB]
Description = MariaDB ODBC driver
Driver      = /usr/lib/x86_64-linux-gnu/odbc/libmaodbc.so
```

`/etc/odbc.ini` — describes a *connection* using that driver:

```ini
[asterisk-cdr]
Description = Asterisk CDR
Driver      = MariaDB
Server      = localhost
Database    = asterisk
Port        = 3306
```

Test it **before involving Asterisk** — this is the step that saves an hour:

```bash
isql -v asterisk-cdr asterisk Lab-cdr-secret
```

**You should see** `Connected!` and an `SQL>` prompt. Type `quit`.

If that fails, Asterisk will fail too, and its error will be less clear. Fix it here.

### Tell Asterisk to use it

`/etc/asterisk/res_odbc.conf`:

```ini
[asterisk]
enabled => yes
dsn => asterisk-cdr
username => asterisk
password => Lab-cdr-secret
pre-connect => yes
```

`/etc/asterisk/cdr_adaptive_odbc.conf`:

```ini
[cdr]
connection=asterisk
table=cdr
alias start => calldate
```

**Adaptive** ODBC means Asterisk inspects the table and writes whatever columns exist. Add
a column, it starts populating it — no code change.

**That last line is not optional, and leaving it out fails in the worst possible way.**
Adaptive ODBC matches columns to CDR *variable names*, and the variable holding the start
time is called **`start`**, not `calldate`. Without the alias, rows still appear — the
call, the numbers, the duration, the disposition, all correct — but every `calldate` is
`1900-01-01 00:00:00`, the column default.

Nothing errors. Nothing warns. You find out months later when someone asks for last
quarter's call volumes and every record is dated 1900.

`calldate` is the traditional name from the old `cdr_mysql` schema, which is why almost
every CDR table you meet uses it — and why this alias is almost always needed.

```bash
sudo asterisk -rx 'module reload res_odbc.so'
sudo asterisk -rx 'module reload cdr_adaptive_odbc.so'
sudo asterisk -rx 'odbc show all'
```

**You should see:**

```
  Name:   asterisk
  DSN:    asterisk-cdr
    Number of active connections: 1 (out of 1)
```

**`Number of active connections: 1`** is the line that matters — it means Asterisk
opened the connection at load time, because you set `pre-connect => yes`. A `0` there
means the credentials or the DSN are wrong, and no CDR will ever be written.

> Older documentation shows a `Logged in: yes` line here. Asterisk 22 does not print it;
> do not go looking for it.

### Test

Place a call — dial `600` and hang up. Then:

```bash
sudo mariadb -e "SELECT calldate,src,dst,disposition,billsec FROM asterisk.cdr ORDER BY id DESC LIMIT 5;"
```

**You should see** your call — and check the **`calldate` column has a real date in it**,
not `1900-01-01`. If it does not, the `alias` line above is missing or misspelled.

Every call from now on lands in a table you can report from.

---

## Step 2 — AMI: drive Asterisk from a script

The **Asterisk Manager Interface** is a TCP socket that emits events and accepts commands.
Every "click to dial" button and every wallboard is built on it.

`/etc/asterisk/manager.conf`:

```ini
[general]
enabled = yes
port = 5038
bindaddr = 127.0.0.1

[labami]
secret = Lab-ami-secret
read = system,call,agent,user,cdr,dialplan
write = system,call,agent,user,originate
```

**`bindaddr = 127.0.0.1` is deliberate.** AMI is a full remote-control interface with a
plaintext password. Exposing it on `0.0.0.0` hands your PBX to anyone who can reach port
5038. Bind it to loopback and reach it over SSH.

```bash
sudo asterisk -rx 'module reload manager'
sudo asterisk -rx 'manager show users'
```

**You should see** the `labami` user.

### Talk to it by hand

AMI is line-based text, so `nc` is enough to understand it:

```bash
nc 127.0.0.1 5038
```

Type this, ending with a **blank line**:

```
Action: Login
Username: labami
Secret: Lab-ami-secret

```

**You should see** `Response: Success` — then a flood of events as things happen.

Now originate a call. Type:

```
Action: Originate
Channel: PJSIP/6001
Context: internal
Exten: 600
Priority: 1
CallerID: AMI Test <9999>

```

**You should see** phone `6001` ring. Answer it and you are in the echo test — a call
created by a socket command, with no one dialling anything.

Type `Action: Logoff` and a blank line to exit.

### Script it

```bash
cat > ~/click2dial.sh <<'EOF'
#!/usr/bin/env bash
# Usage: ./click2dial.sh <extension-to-ring> <number-to-dial>
FROM="${1:?which extension should ring}"
TO="${2:?what should it dial}"
printf 'Action: Login\r\nUsername: labami\r\nSecret: Lab-ami-secret\r\n\r\n%s\r\n' \
  "Action: Originate
Channel: PJSIP/${FROM}
Context: internal
Exten: ${TO}
Priority: 1
Async: true
" | tr '\n' '\r' | sed 's/\r/\r\n/g' | nc -q3 127.0.0.1 5038
EOF
chmod +x ~/click2dial.sh
~/click2dial.sh 6001 600
```

**You should see** `6001` ring again. That script is, in essence, the click-to-dial button
in every CRM you have ever used.

> `Async: true` matters. Without it the connection blocks until the call finishes, and a
> web app doing that will hang.

---

## Step 3 — AGI: run your program inside the dialplan

AMI controls calls from outside. **AGI** runs your program *during* a call, as a dialplan
step: Asterisk passes the call's variables in on stdin, your program writes commands on
stdout.

```bash
sudo tee /var/lib/asterisk/agi-bin/callerinfo.py >/dev/null <<'EOF'
#!/usr/bin/env python3
"""Minimal AGI: read the call environment, speak a decision back."""
import sys

# Asterisk sends the call environment as key: value lines, ending with a blank line.
env = {}
while True:
    line = sys.stdin.readline().strip()
    if line == "":
        break
    if ':' in line:
        k, v = line.split(':', 1)
        env[k.strip()] = v.strip()

def agi(cmd):
    """Send one AGI command and read its result line."""
    sys.stdout.write(cmd + "\n")
    sys.stdout.flush()
    return sys.stdin.readline().strip()

caller = env.get('agi_callerid', 'unknown')
exten  = env.get('agi_extension', 'unknown')

# Anything on stderr goes to the Asterisk log — this is how you debug an AGI.
sys.stderr.write(f"callerinfo: {caller} dialled {exten}\n")

agi('VERBOSE "AGI running for caller %s" 1' % caller)
agi('SET VARIABLE AGI_RESULT "seen-%s"' % caller)
agi('STREAM FILE demo-congrats ""')
EOF
sudo chmod +x /var/lib/asterisk/agi-bin/callerinfo.py
sudo chown asterisk:asterisk /var/lib/asterisk/agi-bin/callerinfo.py
```

Wire it into `[features]`:

```ini
exten => 6600,1,NoOp(AGI demo)
 same => n,Answer()
 same => n,AGI(callerinfo.py)
 same => n,NoOp(AGI set the variable to: ${AGI_RESULT})
 same => n,Hangup()
```

```bash
sudo asterisk -rx 'dialplan reload'
```

**Dial `6600`.** You should hear the prompt, and in the CLI:

```
AGI running for caller ...
AGI set the variable to: seen-...
```

The important part is `SET VARIABLE`: your program handed a value **back into the
dialplan**, which can then route on it. That is how database lookups, blacklists and
customer routing get built.

> AGI is synchronous — the call waits for your script. A slow database query is dead air.
> For anything that might block, use ARI instead.

---

## Step 4 — ARI: control calls from an application

AGI runs a script per call. **ARI** is different in kind: your application connects once
over WebSocket, receives events, and manipulates channels over REST. The call lives in a
**Stasis** application — Asterisk hands it over and stops applying dialplan.

`/etc/asterisk/ari.conf`:

```ini
[general]
enabled = yes
pretty = yes

[labuser]
type = user
password = Lab-ari-secret
```

```bash
sudo asterisk -rx 'module reload res_ari.so'
sudo asterisk -rx 'ari show users'
```

**You should see** `labuser`.

Query it — ARI is plain REST, so `curl` works. If these return nothing at all rather
than an error, the HTTP server is off; see the prerequisite at the top.

```bash
curl -s -u labuser:Lab-ari-secret http://localhost:8088/ari/asterisk/info | jq '.system'
```

**You should see** the system name and version as JSON.

```bash
curl -s -u labuser:Lab-ari-secret http://localhost:8088/ari/endpoints | jq '.[] | {resource, state}'
```

**You should see** every endpoint and whether it is online — the same information as
`pjsip show endpoints`, in a form a web app can consume.

### Hand a call to Stasis

Add to `[features]`:

```ini
exten => 6700,1,NoOp(Handing this call to the ARI application)
 same => n,Answer()
 same => n,Stasis(lab-app)
 same => n,Hangup()
```

```bash
sudo asterisk -rx 'dialplan reload'
```

Now write the application. It listens for events and plays a prompt to any call it is
given:

The lab image already has the `websockets` library installed, so this is short:

```bash
cp /opt/lab/examples/ari-app.py ~/ari-app.py
chmod +x ~/ari-app.py
```

Read it — it is about forty lines, and the shape is the whole lesson:

- **Events arrive over a WebSocket**, one JSON object per event.
- **Actions go back over REST**, one HTTP call per thing you want done.

Two channels, one conversation. When `StasisStart` arrives, the program has a channel ID
and decides what to do with it; here it POSTs a `play` to that channel.

> Do not hand-roll the WebSocket. A client must mask its frames, and a naive socket that
> just reads bytes will work on a quiet system and corrupt under load. Use the library.

Run it in one terminal:

```bash
python3 ~/ari-app.py
```

**You should see** `connected to ARI, waiting for calls`.

**Dial `6700`** from your softphone.

**You should see** `StasisStart: 6001 -> channel ...` and hear the prompt — played not by
the dialplan, but by your program deciding to play it.

While the call is up, from another terminal:

```bash
curl -s -u labuser:Lab-ari-secret http://localhost:8088/ari/channels | jq '.[] | {id, name, state}'
```

**You should see** the live channel as JSON.

> **The distinction worth keeping:** in the dialplan, Asterisk decides and your code
> assists. In Stasis, your code decides and Asterisk executes. Everything modern —
> voicebots, browser-based contact centres, AI agents on a call — is built on this side.

---

## ✅ Checkpoint

1. `odbc show all` reports `Number of active connections: 1`, and a call appears in the `asterisk.cdr` table
2. An AMI `Originate` makes `6001` ring
3. `~/click2dial.sh 6001 600` does the same from a script
4. Dialling `6600` runs the AGI script and sets `${AGI_RESULT}` in the dialplan
5. `curl .../ari/endpoints` returns your endpoints as JSON
6. Dialling `6700` produces `StasisStart` in your ARI application, and it plays a prompt

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `isql` fails to connect | Driver path wrong | `ls /usr/lib/x86_64-linux-gnu/odbc/` and correct `Driver =` in odbcinst.ini. |
| `odbc show all` says `Logged in: no` | Credentials, or MariaDB not running | `systemctl status mariadb`, then re-test with `isql` first. |
| CDRs still only in CSV | `cdr_adaptive_odbc` not loaded | `module show like cdr`. Check `cdr_adaptive_odbc.conf` names `connection=asterisk`. |
| CDR row exists but columns are empty | Column names do not match CDR fields | Adaptive ODBC matches on name — `src`, `dst`, `billsec` must be spelled exactly. |
| AMI login fails | Reload not done, or wrong secret | `manager show users`, then `manager show user labami`. |
| AMI `Originate` returns success but nothing rings | The channel is unregistered | `pjsip show endpoints` — you cannot originate to a phone that is not there. |
| AGI does nothing | Not executable, or wrong owner | `ls -l /var/lib/asterisk/agi-bin/` — must be executable and owned by `asterisk`. Check the log for `stderr` output. |
| ARI 401 | Wrong user, or `ari.conf` not reloaded | `ari show users`. |
| ARI connects but no events | Dialplan does not hand the call over | The app name in `Stasis(lab-app)` must match `?app=lab-app` exactly. |

---

**Next:** Lab 8 — locking it down and keeping it running: iptables, fail2ban, systemd,
backups and monitoring.
