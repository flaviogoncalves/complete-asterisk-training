# Human Verification Checklist

Everything in the labs that a machine cannot check for you.

The automated verifier (`lab-vm/build/verify-labs.sh`) covers 21 checks and reports
`0 failed`. It cannot check anything you have to **hear**, anything needing **two phones
at once**, or anything needing a **browser**. That is this list.

Run it once, on a VM that has completed Labs 0–8, with two softphones registered.
Roughly 40 minutes.

---

## Setup

- Lab VM running, `lab status` all green
- Softphone A registered as `6001` / `Lab-6001-secret`
- Softphone B registered as `6002` / `Lab-6002-secret`
- Both pointed at the address `lab ip` reports, port 5060 UDP

> Two instances of MicroSIP on Windows, or Linphone with two accounts, or your computer
> plus your mobile on the same wifi.

---

## Lab 2 Part II — the foundation

| # | Do this | Expect |
|---|---|---|
| 2.1 | From `6001`, dial `600` | Hear a prompt, then **your own voice echoed back** |
| 2.2 | From `6001`, dial `6002`, answer on B | **Both parties hear each other** |
| 2.3 | During that call, on the VM: `sudo asterisk -rx 'core show channels'` | Two channels, `1 active call` |

**2.1 is the single most important check in this document.** If audio fails here,
everything after it is built on sand — and it is the check the old Docker lab never made.

---

## Lab 4 — dialplan and IVR

| # | Do this | Expect |
|---|---|---|
| 4.1 | Dial `6002` and let it ring out (20s) | Hear *"the party you are calling is currently unavailable"* |
| 4.2 | Set B to Do Not Disturb, dial `6002` | Hear the **busy** message, not the unavailable one |
| 4.3 | Have a normal call and let **B hang up first** | Caller hears **nothing extra** — no "unavailable" after a good call |
| 4.4 | Dial `6000` | IVR prompt plays |
| 4.5 | Press `1` during the prompt | Prompt **stops immediately**, `6001` rings |
| 4.6 | Dial `6000`, press `9` | Echo test |
| 4.7 | Dial `6000`, press `5` | *"invalid"*, then the menu again |
| 4.8 | Dial `6000`, press nothing | Goodbye, then hangup |

**4.3 is the regression test for a bug I fixed** — `DIALSTATUS=ANSWER` used to fall
through to the failure branch, telling people their colleague was unavailable after a
ten-minute conversation.

**4.5 proves `Background()` not `Playback()`** — if the prompt plays to the end before
responding, the IVR is using the wrong application.

---

## Lab 5 — features and queues

| # | Do this | Expect |
|---|---|---|
| 5.1 | Dial `6002`, let it ring out, leave a message | Unavailable greeting, then a beep |
| 5.2 | On the VM: `asterisk -rx 'voicemail show users'` | `6002` shows **1** new message |
| 5.3 | Check softphone B | Message-waiting indicator lit *(some softphones never show this — 5.2 is the truth)* |
| 5.4 | From `6002`, dial `*97`, PIN `1234` | Your message plays back |
| 5.5 | A calls B, answer. On B press `#2`, dial `600`, then hang up B | A ends up connected to the echo test |
| 5.6 | A calls B, answer. On B press `#1`, dial `700` | Asterisk **announces a slot number** (701) |
| 5.7 | From B, dial that slot | Reconnected to A |
| 5.8 | Park a call and wait 45 s without retrieving | Call **comes back** to the phone that parked it |
| 5.9 | Ring `6002` from the IVR; on `6001` dial `**` | `6001` answers it, `6002` stops ringing |
| 5.10 | Dial `6500` | **Alice (`6001`) rings first** — penalty 0 before penalty 1 |
| 5.11 | Do not answer for 15 s | **Bob (`6002`) rings** |
| 5.12 | Answer on B, then on the VM: `asterisk -rx 'queue show support'` | Caller listed, agent `In use` |
| 5.13 | `sudo tail /var/log/asterisk/queue_log` | `ENTERQUEUE` and `CONNECT` records |

**5.5 depends on `atxfer => #2` being present** — it is missing from the shipped
`features.conf` and must be added, not uncommented. If `#2` does nothing, check that
first, then check the softphone's DTMF mode.

---

## Lab 6 — SIP in depth

| # | Do this | Expect |
|---|---|---|
| 6.1 | `sudo sngrep`, then dial `600` | Call appears; Enter shows the ladder INVITE → 100 → 200 OK → ACK |
| 6.2 | Open the INVITE, find the SDP | `m=audio <port> RTP/AVP 0 8 101` and the `c=` line |
| 6.3 | Open Asterisk's 200 OK | **Shorter** `m=` line — one codec chosen |
| 6.4 | Swap `allow=alaw` before `allow=ulaw` on `6001`, reload, redial | 200 OK now answers **`8`** instead of `0` |
| 6.5 | Visit `https://<your-lab-ip>:8089/ws`, accept the warning | Browser accepts the certificate |
| 6.6 | Open the WebRTC page, log in as `webrtc-1000` | Registers — `pjsip show endpoint webrtc-1000` becomes `Not in use` |
| 6.7 | Dial `600` from the browser | **Hear the echo test from a web page** |
| 6.8 | Look at that call in sngrep | SDP says **`RTP/SAVPF`** |
| 6.9 | Point `6002` at port **5061**, transport **TLS**, register, call `600` | Registers, call works |
| 6.10 | Watch that call in sngrep | Contents are **encrypted / unreadable** |

**6.5 is the step everyone skips**, and the browser then fails the WebSocket silently.

---

## Lab 7 — programmability

| # | Do this | Expect |
|---|---|---|
| 7.1 | Place a call, then `mariadb -e "SELECT * FROM asterisk.cdr ORDER BY id DESC LIMIT 1;"` | Your call is in the table |
| 7.2 | AMI `Originate` via `nc`, per the lab | **`6001` rings**; answer and reach the echo test |
| 7.3 | `~/click2dial.sh 6001 600` | Same thing, from a script |
| 7.4 | Dial `6600` | Prompt plays; CLI shows `AGI set the variable to: seen-...` |
| 7.5 | Run `~/ari-app.py`, then dial `6700` | `StasisStart` printed, **prompt plays** |

---

## Lab 8 — security and operations

| # | Do this | Expect |
|---|---|---|
| 8.1 | From **your computer**, register with a **wrong password** 4–5 times | — |
| 8.2 | `sudo cat /var/log/asterisk/security` | `InvalidPassword` / `InvalidAccountID` with **your** address |
| 8.3 | `sudo fail2ban-client status asterisk` | Your address under **Currently banned** |
| 8.4 | `sudo iptables -L f2b-asterisk -n` | A `REJECT` rule for it |
| 8.5 | Try to register normally | **Blocked** — cannot reach the PBX at all |
| 8.6 | `sudo fail2ban-client set asterisk unbanip <your-ip>` | Registration works again |
| 8.7 | Apply the firewall, then place a call | Calls **still work** with policy `DROP` |
| 8.8 | `sudo pkill -9 asterisk`, wait 8 s | systemd has **restarted it** |
| 8.9 | Delete `pjsip.conf`, restore from backup per the lab | Endpoints **come back** |

**8.1–8.5 must be run from a machine other than the VM.** `127.0.0.1` is in fail2ban's
`ignoreip`, so you cannot ban yourself locally — correct behaviour, but it means a
loopback test proves nothing.

**8.7 carries real risk on a remote server.** Keep the VirtualBox console open; if SSH
freezes, recover there with `sudo iptables -P INPUT ACCEPT`.

---

## Recording the result

Anything that fails is a bug in the lab, not in you — the whole point of this list is to
find them before students do. Note the check number, what you saw instead, and the output
of the nearest CLI command.
