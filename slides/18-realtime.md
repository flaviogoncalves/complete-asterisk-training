---
theme: seriph
title: 'Realtime (ARA)'
info: |
  ## Asterisk Guide — Chapter 16
  Realtime (ARA). Asterisk 22 LTS, PJSIP-first.
class: text-center
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
transition: slide-left
mdc: true
colorSchema: light
---

# Realtime (ARA)

Chapter 16

<div class="abs-bl m-6 text-sm opacity-70">
  Asterisk Guide · Asterisk 22 LTS · PJSIP-first
</div>

<style>
h1 { color: #1C5D99; }
/* QA: keep code inside the 16:9 frame — shrink slightly + wrap long lines (lossless) */
.slidev-layout pre { font-size: 0.8em; line-height: 1.32; }
.slidev-layout pre code { white-space: pre-wrap; overflow-wrap: anywhere; }
</style>

---
layout: default
---

# Objectives

By the end of this chapter you will be able to:

<v-clicks>

- **Understand** the advantages and limitations of Asterisk Realtime
- **Use** ODBC as the backend for ARA
- **Configure** and install ARA, including the PJSIP `ps_*` tables
- **Test** realtime endpoints and dial plan in a lab environment

</v-clicks>

<!--
ARA = Asterisk Realtime Architecture. The chapter modernizes the old chan_sip realtime
to the PJSIP/Sorcery model on Asterisk 22.
-->

---
layout: section
---

# Why Realtime?

---

# The limits of text-file configuration

Asterisk is normally configured with text files in `/etc/asterisk`. Easy — but it has known drawbacks.

<div grid="~ cols-2 gap-8" class="mt-4">
<div>

**Drawbacks of static text files**

- Must **reload** Asterisk after every change
- High **memory use** for large user volumes
- Hard to build a **provisioning interface** on top
- No **integration** with existing databases

</div>
<div>

**What ARA gives you**

- Configuration lives in a **SQL database** (or LDAP)
- Dynamic objects loaded **on demand** — no reload
- Created by Minessale II, Spencer & Filin
- A.k.a. *Asterisk External Configuration*

</div>
</div>

<div class="mt-4 text-sm opacity-70">
Configured in <code>/etc/asterisk/extconfig.conf</code>: map config files to tables (static) or load objects in realtime (dynamic).
</div>

---

# How Asterisk Realtime works

Database-specific code moved into the channel/object layer; the channel just calls a generic lookup.

<div grid="~ cols-3 gap-4 text-sm mt-2">
<div>

**STATIC**
Loads a static configuration when a module is loaded.

</div>
<div>

**REALTIME**
Searches objects during a call or another event.

</div>
<div>

**UPDATE**
Updates objects in the backend.

</div>
</div>

<div class="mt-4 p-3 text-sm" style="border-left: 4px solid #1C5D99;">
On Asterisk 22, SIP endpoints are handled by the <strong>PJSIP</strong> stack (<code>res_pjsip</code>), built on the
<strong>Sorcery</strong> object model. The <code>realtime</code> wizard loads each PJSIP object from the database on demand —
they then exist as <em>ordinary configured PJSIP objects</em>.
</div>

<div class="mt-3 text-sm opacity-80">
Because they are real objects, <strong>NAT traversal, qualify, and MWI</strong> all work normally. Changes are picked up on the next lookup — no reload after every edit.
</div>

<!--
The retired chan_sip realtime model (sippeers/sipusers) is covered only in the Legacy Channels chapter.
-->

---
layout: section
---

# extconfig.conf

---
layout: image-right
image: /images/18-realtime-fig01.png
backgroundSize: contain
---

# Two sections in extconfig.conf

ARA is configured in `extconfig.conf`, which has two clear parts.

<v-clicks>

- **Static configuration** — substitute text config files with database tables; read at load (some modules re-read on reload).
- **Realtime configuration** — map families to database tables for dynamic objects, loaded on demand.

</v-clicks>

<div class="mt-4 text-sm opacity-70">
A common pattern: keep <strong>static</strong> sections in text files and put only the <strong>dynamic</strong> entries in the database.
</div>

<!--
Figure: config files + static DB tables load at startup; realtime tables are read on demand during a call.
-->

---

# Static configuration section

Store the equivalent of a config file in the database. Syntax:

```ini
; <conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf  => odbc,asteriskdb,pjsip_conf
iax.conf    => ldap,MyBaseDN,iax
```

<div class="mt-3 text-sm">

- `queues.conf` → table `queues_conf` in `asteriskdb`
- `pjsip.conf` → table `pjsip_conf` (ODBC)
- `iax.conf` → an LDAP directory rooted at `MyBaseDN`

</div>

<div class="mt-4 p-3 text-sm" style="border-left: 4px solid #1C5D99;">
Static file mapping is best for files with <strong>no per-object realtime equivalent</strong>. For PJSIP, prefer the
per-object families (<code>ps_endpoints</code>, <code>ps_aors</code>, …) instead of mapping the whole <code>pjsip.conf</code>.
</div>

---

# Realtime configuration section

The second part of `extconfig.conf` maps **families** to tables. No reload needed — objects are loaded, updated, and unloaded in realtime.

```ini
; <family name> => <driver>,<database name>[,table_name]
ps_endpoints  => odbc,asterisk,ps_endpoints
ps_aors       => odbc,asterisk,ps_aors
queues        => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail     => odbc,asterisk,test
```

<div class="mt-3 text-sm">
Each PJSIP object type (endpoint, aor, auth, contact) gets its own family and table.
The <code>voicemail</code>, <code>extensions</code>, <code>queues</code>, and <code>queue_members</code> families are all still valid in Asterisk 22.
</div>

---
layout: section
---

# PJSIP Realtime (Sorcery)

---

# One account → several Sorcery objects

PJSIP splits a SIP account into typed objects, each stored in its own realtime table.

<div class="text-sm">

| Sorcery object type | Realtime table | What it holds |
|---------------------|----------------|---------------|
| endpoint | `ps_endpoints` | per-account settings (context, codecs, DTMF, …) |
| aor (address of record) | `ps_aors` | registration limits and `qualify` settings |
| auth | `ps_auths` | `username` / `password` credentials |
| contact | `ps_contacts` | the dynamically registered location |
| domain alias | `ps_domain_aliases` | alternate SIP domains for an endpoint |
| endpoint identifier by IP | `ps_endpoint_id_ips` | matching an endpoint by source IP |

</div>

<div class="mt-3 text-sm opacity-70">
A minimal realtime endpoint is one row each in <code>ps_auths</code>, <code>ps_aors</code>, and <code>ps_endpoints</code>.
</div>

---

# Enabling PJSIP realtime — step 1

First, map the Sorcery object types to realtime families in **`extconfig.conf`**:

```ini
[settings]
ps_endpoints       => odbc,asterisk
ps_aors            => odbc,asterisk
ps_auths           => odbc,asterisk
ps_contacts        => odbc,asterisk
ps_domain_aliases  => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

<div class="mt-4 text-sm opacity-70">
This tells Asterisk <em>where</em> each family lives. Next we tell Sorcery to actually use the <code>realtime</code> wizard.
</div>

---

# Enabling PJSIP realtime — step 2

Second, point Sorcery at the `realtime` wizard in **`sorcery.conf`**. The mapping name (`res_pjsip`) is the module; the value names the family from `extconfig.conf`.

```ini
[res_pjsip]
endpoint=realtime,ps_endpoints
aor=realtime,ps_aors
auth=realtime,ps_auths
domain_alias=realtime,ps_domain_aliases
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
```

<div class="mt-4 p-3 text-sm" style="border-left: 4px solid #1C5D99;">
You can <strong>mix static and realtime</strong>. Omit a type from <code>sorcery.conf</code> and it keeps reading from <code>pjsip.conf</code> —
e.g. keep transports and globals static, store endpoints/aors/auths/contacts in the DB.
</div>

---

# Building the schema with Alembic

Asterisk ships DB migrations for every realtime schema under `contrib/ast-db-manage`. This is the **supported** way to create and version-upgrade the `ps_*` tables — no more hand-written DDL.

```bash
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

<div class="mt-3 text-sm">
The <code>config</code> migration set builds <code>ps_endpoints</code>, <code>ps_aors</code>, <code>ps_auths</code>, <code>ps_contacts</code> and the rest with the
correct columns for the running version. Needs Python <code>alembic</code> + a SQLAlchemy driver (<code>pymysql</code> or <code>psycopg2</code>).
</div>

---

# A minimal realtime endpoint

Endpoint `6010` is three rows — auth, aor, endpoint:

```sql
-- ps_auths
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('6010-auth', 'userpass', '6010', 'supersecret');

-- ps_aors
INSERT INTO ps_aors (id, max_contacts) VALUES ('6010', 1);

-- ps_endpoints
INSERT INTO ps_endpoints
  (id, transport, aors, auth, context, disallow, allow, direct_media)
VALUES
  ('6010', 'transport-udp', '6010', '6010-auth',
   'from-internal', 'all', 'ulaw', 'no');
```

After inserting the rows there is **nothing to reload** — the next REGISTER/INVITE pulls the objects from the database.

```text
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

---

# Columns map to config options

Each DB column matches an **option name** from the corresponding config file. The `pjsip.conf` endpoint below…

```ini
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

…is stored as one row across three tables: `ps_endpoints` (`id=4000, context, disallow, allow, auth, aors`),
`ps_auths` (`id=4000, auth_type=userpass, username, password`), and `ps_aors` (`id=4000, max_contacts=1`).

<div class="mt-3 text-sm opacity-70">
Populate only the columns you use — any column left <code>NULL</code> falls back to the option's default. Want <code>callerid</code>? Fill the <code>callerid</code> column of <code>ps_endpoints</code>.
</div>

---
layout: image-right
image: /images/18-realtime-fig02.png
backgroundSize: contain
---

# Realtime dial plan with switch

ARA can also serve the dial plan. The `switch` statement pulls extension rows from a table into the normal dial plan.

The `extensions` table:

<div class="text-sm">

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | `PJSIP/4000` |

</div>

```ini
[local]
switch => realtime
; or, fully qualified:
; switch => realtime/from-internal@extensions
```

<div class="mt-3 text-sm opacity-70">
The <code>extensions</code> family is unchanged in Asterisk 22 — just make sure <code>appdata</code> dials PJSIP channels, e.g. <code>PJSIP/4000</code>.
</div>

---
layout: center
class: text-center
---

# 🧪 Labs

**Build the tables, then wire up ARA**

This chapter has two in-chapter labs:

- **Installing & creating the database tables** — Alembic builds the `ps_*` schema
- **Configuring & testing ARA** — map families in `extconfig.conf`, register endpoint `6010`, dial a realtime extension

See the matching lab in `labs/LAB-GUIDE.md`

<div class="mt-4 text-sm opacity-70">
Reuses the ODBC + MySQL (<code>astdb</code> / <code>supersecret</code>) setup from the CDR chapter.
</div>

---

# Lab: verify the tables

After `alembic -c config.ini upgrade head`, confirm the realtime tables exist:

```bash
mysql -u astdb -p astdb
```

```text
mysql> show tables;
+----------------------------+
| Tables_in_astdb            |
+----------------------------+
| ps_aors                    |
| ps_auths                   |
| ps_contacts                |
| ps_domain_aliases          |
| ps_endpoint_id_ips         |
| ps_endpoints               |
| ps_registrations           |
| extensions                 |
| voicemail                  |
+----------------------------+
```

<div class="mt-2 text-sm opacity-70">
Alembic creates more tables than these — the list shows the ones relevant to the lab.
</div>

---
layout: section
---

# Summary

---

# Summary

<v-clicks>

- **ARA** moves configuration from text files into a **SQL database** (or LDAP) — no reload per change.
- `extconfig.conf` has two parts: **static** (file → table) and **realtime** (family → table).
- On Asterisk 22, PJSIP/**Sorcery** stores accounts in `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts` — enabled via `extconfig.conf` **and** `sorcery.conf`.
- Build the schema with **Alembic** (`contrib/ast-db-manage`) — version-correct, no hand-written DDL.
- DB **columns map to config options**; the dial plan can be served via `switch => realtime`.

</v-clicks>

<div class="mt-6 text-sm opacity-70">
Native realtime drivers: <strong>ODBC</strong> (any UnixODBC backend), <strong>MySQL</strong>, <strong>PostgreSQL</strong>, plus <strong>LDAP</strong>.
</div>

---
layout: center
class: text-center
---

# Quiz

Ten questions at the end of Chapter 16 in *Asterisk Guide*.

<div class="mt-4 text-sm opacity-70">
e.g. <em>On Asterisk 22, what is the version-correct way to create the PJSIP <code>ps_*</code> realtime tables?</em>
</div>
