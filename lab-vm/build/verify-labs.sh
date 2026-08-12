#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Run every lab checkpoint against a real lab VM and report pass/fail.
#
#   ./verify-labs.sh            # run on the lab VM itself
#
# This runs the SAME commands the labs tell students to run, and asserts the
# SAME output the labs tell them to expect. When a lab and this script
# disagree, one of them is wrong — that is the point.
#
# What it cannot check: anything you have to hear. Audio checkpoints are
# reported as MANUAL and must be confirmed by a person with a softphone.
# ---------------------------------------------------------------------------
# Deliberately NO `pipefail`.
#
# Every check here is `asterisk -rx ... | grep -q ...`. `grep -q` exits the
# moment it matches, which sends SIGPIPE to asterisk — and under pipefail the
# pipeline then reports failure. The effect is that a check fails precisely
# when its pattern appears EARLY in the output, and passes when it appears
# late. That produced a verifier which claimed context 'internal' was missing
# while simultaneously finding three extensions inside it.
set -u

pass=0; fail=0; manual=0
ok()   { printf '  \033[1;32mPASS\033[0m  %s\n' "$*"; pass=$((pass+1)); }
no()   { printf '  \033[1;31mFAIL\033[0m  %s\n' "$*"; fail=$((fail+1)); }
man()  { printf '  \033[1;33mMANUAL\033[0m %s\n' "$*"; manual=$((manual+1)); }
grp()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

cli() { sudo asterisk -rx "$1" 2>/dev/null; }

# --- the scripts themselves ------------------------------------------------
grp "Lab tooling"

# A shell script with CRLF line endings fails on the very first `set` line with
# "pipefail: invalid option name", which reads as a bash version problem rather
# than what it is. Easy to introduce when the files are authored on Windows.
crlf=""
for f in /usr/local/bin/lab /opt/lab/asterisk.service /etc/modprobe.d/blacklist-raid.conf; do
    [[ -f "$f" ]] && grep -qU $'\r' "$f" 2>/dev/null && crlf="${crlf} $f"
done
[[ -z "${crlf}" ]] && ok "lab scripts have Unix line endings" \
  || no "CRLF line endings in:${crlf} — these will fail to run"

# --- Lab 0 -----------------------------------------------------------------
grp "Lab 0 — Build your lab machine"

lsb_release -d 2>/dev/null | grep -q "24.04" \
  && ok "Ubuntu 24.04 LTS" || no "not Ubuntu 24.04"

ip=$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
[[ -n "${ip}" ]] && ok "has a LAN address (${ip})" || no "no global IPv4 — is Adapter 1 bridged?"

[[ -d /usr/src/asterisk-22.10.0 ]] \
  && ok "Asterisk source staged in /usr/src" || no "/usr/src/asterisk-22.10.0 missing"

# --- Lab 1 -----------------------------------------------------------------
grp "Lab 1 — Install Asterisk 22 from source"

systemctl is-active --quiet asterisk \
  && ok "asterisk.service is active (running)" || no "asterisk.service is not running"

grep -q '^RuntimeDirectory=asterisk' /etc/systemd/system/asterisk.service 2>/dev/null \
  && ok "unit has RuntimeDirectory=asterisk" \
  || no "unit is MISSING RuntimeDirectory=asterisk — the CLI will be unreachable"

[[ "$(stat -c '%U' /run/asterisk 2>/dev/null)" == "asterisk" ]] \
  && ok "/run/asterisk owned by asterisk" || no "/run/asterisk not owned by asterisk"

cli 'core show version' | grep -q '22.10.0' \
  && ok "core show version reports 22.10.0" || no "wrong or unreachable Asterisk version"

# The log file the troubleshooting tables point at must actually exist.
[[ -f /var/log/asterisk/messages.log ]] \
  && ok "/var/log/asterisk/messages.log exists" \
  || no "messages.log missing — troubleshooting steps reference it"

# Sound prompts. A missing one is silence at runtime, never an error, so it has
# to be checked here rather than discovered by a student mid-call.
missing=""
for s in demo-echotest demo-echodone demo-congrats hello-world invalid vm-goodbye \
         the-party-you-are-calling is-curntly-busy is-curntly-unavail; do
    ls /var/lib/asterisk/sounds/en/${s}.* >/dev/null 2>&1 || missing="${missing} ${s}"
done
[[ -z "${missing}" ]] && ok "all 9 lab sound prompts present" \
  || no "missing sound prompts:${missing} (enable EXTRA-SOUNDS-EN-ULAW in menuselect)"

# --- Lab 2 Part I ----------------------------------------------------------
grp "Lab 2 Part I — SIP extensions"

cli 'pjsip show transports' | grep -q '0.0.0.0:5060' \
  && ok "transport-udp bound to 0.0.0.0:5060" || no "no UDP transport on 5060"

eps=$(cli 'pjsip show endpoints' | grep -c '^ Endpoint:  [0-9]')
[[ "${eps}" -ge 2 ]] && ok "${eps} numbered endpoints defined" || no "expected at least 2 endpoints, found ${eps}"

for e in 6001 6002; do
    if cli "pjsip show endpoint ${e}" | grep -q 'InAuth:'; then
        ok "${e} resolves its auth object"
    else
        no "${e} has no InAuth — auth= name does not match the [${e}] auth section"
    fi
done

# --- Lab 2 Part II ---------------------------------------------------------
grp "Lab 2 Part II — softphones and the first call"

cli 'dialplan show internal' | grep -q "Context 'internal'" \
  && ok "context 'internal' exists" || no "context 'internal' missing"

for x in 600 6001 6002; do
    cli "dialplan show ${x}@internal" | grep -q "'${x}'" \
      && ok "extension ${x} is reachable in 'internal'" || no "extension ${x} not found in 'internal'"
done

# A registered PHONE is a numbered endpoint that is no longer Unavailable.
#
# Counting `Contact:` lines does not work, for two separate reasons: the table
# prints a legend row containing that literal text, and a SIP trunk's AOR has a
# permanent static contact configured in pjsip.conf. Either one alone makes a
# machine with no phones at all report that a phone is registered.
reg=$(cli 'pjsip show endpoints' | grep -E '^ Endpoint:  [0-9]' | grep -cv 'Unavailable')
[[ "${reg}" -gt 0 ]] && ok "${reg} phone(s) currently registered" \
  || man "no phone registered — register a softphone to complete this checkpoint"

man "dial 600 and hear your own voice (two-way audio)"
man "dial 6002 from 6001, answer, and hear each other"

# --- Lab 2 Part III --------------------------------------------------------
grp "Lab 2 Part III — SIP trunk"

if cli 'pjsip show registrations' | grep -q 'No objects found'; then
    man "no trunk configured yet"
else
    cli 'pjsip show registrations' | grep -q 'Registered' \
      && ok "trunk is Registered to the gateway" \
      || no "trunk is not Registered — check account/password/port 5600"
fi

if cli 'dialplan show from-pstn' | grep -q "Context 'from-pstn'"; then
    ok "context 'from-pstn' exists"
    # The whole point of from-pstn: it must not be able to dial out.
    if cli 'dialplan show from-pstn' | grep -qE 'Include =>|@pstn'; then
        no "from-pstn can reach outbound routes — TOLL FRAUD RISK"
    else
        ok "from-pstn has no outbound route (correct)"
    fi
else
    man "from-pstn not configured yet"
fi

# --- Lab 3 -----------------------------------------------------------------
grp "Lab 3 — Dialplan"

if cli 'dialplan show internal' | grep -q '_60XX'; then
    ok "pattern _60XX in use"
    cli 'dialplan show 6002@internal' | grep -q '_60XX' \
      && ok "6002 resolves via the _60XX pattern" || no "6002 does not resolve to _60XX"
else
    man "Lab 3 not started (no _60XX pattern yet)"
fi

cli 'dialplan show ivr' | grep -q "Context 'ivr'" \
  && ok "IVR context exists" || man "IVR not built yet"

# --- summary ---------------------------------------------------------------
printf '\n\033[1m%d passed, %d failed, %d need a human\033[0m\n' "${pass}" "${fail}" "${manual}"
[[ "${fail}" -eq 0 ]]
