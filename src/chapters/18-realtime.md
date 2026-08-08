# Asterisk Real-Time

As you know, the Asterisk configuration is achieved through the use of several text files in the /etc/asterisk directory. Despite the ease of using text files, there are some known drawbacks:

- The need to reload Asterisk each time the files are changed
- Increased memory usage for a large volume of users
- It is difficult to code a provisioning interface using text files
- No possibility of integration to existing databases

ARA or Asterisk Realtime, as it is known, was created by Anthony Minessale II, Mark Spencer, and Constantine Filin and was designed to allow transparent integration with SQL databases. An LDAP interface is available too. This system is also known as Asterisk External Configuration and is configured in /etc/asterisk/extconfig.conf. You can map configuration files to tables in a database (static configuration) and real-time entries for the dynamic creation of objects without the need to reload Asterisk.

## Objectives

By the end of this chapter, the reader should be able to:

- Understand advantages and limitations of Asterisk Real Time.
- Use ODBC for use with ARA
- Compile and install ARA using ODBC
- Test the system in a lab environment

## How does Asterisk Real Time work?

In the new Real Time architecture, all database-specific code was moved to channel drivers. The channel only calls a generic routine that searches the database. The result is a much simpler and cleaner process from the source code point of view. The database is accessed by three functions:

- STATIC: Used to set up a static configuration when a module is loaded.
- REALTIME: Used to search objects during a call or another event.


- UPDATE: Used to update objects.

On Asterisk 22, SIP endpoints are handled by the **PJSIP** stack (`res_pjsip`), which is built on the **Sorcery** object model. With the `realtime` wizard, Sorcery loads each PJSIP object from the database on demand, and those objects then exist as ordinary configured PJSIP objects — not as the throwaway realtime peers the old SIP driver discarded after each call.

Because they are real objects, NAT traversal, qualify, and message waiting indication (MWI) all work normally for realtime endpoints. (Sorcery can additionally be told to cache objects in memory via a `memory_cache` wizard, but that is opt-in and separate from realtime loading.) When you change an object in the database, the change is picked up on the next lookup; you do not need to reload after every edit. (The retired `chan_sip` realtime model, with its `sippeers`/`sipusers` families, is covered only in the *Legacy Channels* chapter.)

## Configuring Asterisk Real Time

For this lab, we will assume that you already have ODBC installed from the CDR chapter. ARA is configured in the extconfig.conf text file, where two sections can be easily seen. The first one is the static configuration files section, where you can substitute the text configuration files for database tables. The second section is the realtime configuration engine, where you configure database tables for dynamic objects (peers/users). It is not unusual to use text files for the static configuration and the database for dynamic entries. In this case, the first section is untouched.

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Asterisk Real Time architecture: configuration files and static database tables are loaded when Asterisk starts, while realtime database tables provide dynamic configuration that is read on demand during a call.](../images/18-realtime-fig01.png)

```
;
[settings]
;
; Static configuration files:
;
; file.conf => driver,database[,table]
;
; maps a particular configuration file to the given
; database driver, database and table (or uses the
; name of the file as the table if not specified)
;
;uncomment to load queues.conf via the odbc engine.
;
;queues.conf => odbc,asterisk,ast_config
;
; The following files CANNOT be loaded from Realtime storage:
;       asterisk.conf
;       extconfig.conf (this file)
;       logger.conf
;
; Additionally, the following files cannot be loaded from
; Realtime storage unless the storage driver is loaded
; early using 'preload' statements in modules.conf:
;       manager.conf
;       cdr.conf
;       rtp.conf
;
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
;example => odbc,asterisk,alttable
;ps_endpoints => odbc,asterisk
;ps_aors => odbc,asterisk
;ps_auths => odbc,asterisk
;ps_contacts => odbc,asterisk
;voicemail => odbc,asterisk
;extensions => odbc,asterisk
;queues => odbc,asterisk
;queue_members => odbc,asterisk
```


### Static configuration section

The static configuration section is where you store the equivalent to configuration files in the database. These configurations are read during the Asterisk load. Some modules reread the database when you reload. Examples of the static configuration are:

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

Static file mapping is most useful for configuration files that have no per-object realtime equivalent. For PJSIP, prefer the per-object realtime families (`ps_endpoints`, `ps_aors`, and so on) described later in this chapter rather than mapping the whole `pjsip.conf` as a static file.

Three examples are described above. In the first one, you bind queues.conf to a table queues in the asteriskdb database. In the second example, you bind pjsip.conf to the table pjsip_conf in the database asteriskdb defined in the odbc configuration. In the last example, you bind iax.conf to an LDAP directory. MyBaseDN is the base DN to be searched. In the previous example, the application app_queue.so is loaded while MySQL driver queries the database and gets the required information.

### Real Time configuration section

The real-time configuration (second part of the extconfig.conf file) is where the configuration piece to be loaded is configured, updated, and unloaded in real time. With real time, it is not necessary to reload the configurations. The real-time syntax follows:

```
<family name> => <driver>,<database name>[,table_name]
```

Example:

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

Here we have five configuration lines. In the first line, you bind the PJSIP/Sorcery family `ps_endpoints` to a table `ps_endpoints` in the asteriskdb database. In the last, you bind the voicemail family to the test table in the asteriskdb database. Each PJSIP object type (endpoint, aor, auth, contact) gets its own family and table; the full set is shown in the "PJSIP Realtime (Sorcery)" section below. The `voicemail`, `extensions`, `queues`, and `queue_members` families are still valid in Asterisk 22.

## PJSIP Realtime (Sorcery)

On Asterisk 22, SIP endpoints are handled exclusively by the **PJSIP** stack (`res_pjsip`), which is built on the **Sorcery** object abstraction layer. Rather than a single SIP "peer", PJSIP splits a SIP account into several object types, each stored in its own realtime table:

| Sorcery object type | Realtime table | What it holds |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | per-account settings (context, codecs, DTMF, etc.) |
| aor (address of record) | ps_aors | registration limits and `qualify` settings |
| auth | ps_auths | `username` / `password` credentials |
| contact | ps_contacts | the dynamically registered location |
| domain alias | ps_domain_aliases | alternate SIP domains for an endpoint |
| endpoint identifier by IP | ps_endpoint_id_ips | matching an endpoint by source IP |

Realtime for PJSIP is enabled in two places. First, map the Sorcery object types to realtime in `extconfig.conf`:

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

Second, tell Sorcery to use the `realtime` wizard for those object types in `sorcery.conf`. The mapping name (here `res_pjsip`) is the module whose objects you are relocating, and the right-hand value points at the family you defined in `extconfig.conf`:

```
[res_pjsip]
endpoint=realtime,ps_endpoints
aor=realtime,ps_aors
auth=realtime,ps_auths
domain_alias=realtime,ps_domain_aliases
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
```

You can mix static and realtime objects. If you omit a type from `sorcery.conf`, that object type keeps reading from `pjsip.conf`. A common pattern is to keep static transports and global settings in `pjsip.conf` while storing endpoints, aors, auths, and contacts in the database.

### Creating the PJSIP realtime schema with Alembic

Asterisk ships database migrations for all of its realtime schemas under `contrib/ast-db-manage`. This is the supported way to create (and version-upgrade) the PJSIP tables — you no longer hand-write the `ps_*` table definitions. The `config` migration set contains the PJSIP/Sorcery tables.

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

This creates `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`, and the other PJSIP tables with the correct columns for the running Asterisk version. (Alembic requires Python's `alembic` package plus a SQLAlchemy driver such as `pymysql` for MySQL/MariaDB or `psycopg2` for PostgreSQL.)

A minimal realtime endpoint then consists of one row in each of three tables — for example endpoint `6010`:

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

After inserting the rows there is nothing to reload — the next REGISTER/INVITE pulls the objects from the database. You can confirm what realtime returned with:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## Database configuration

Now that we have configured the extconfig.conf file, let’s create the tables. Generally speaking, each database column matches an option name from the corresponding configuration file. The PJSIP `ps_*` tables follow this rule: every `ps_endpoints` column is named after a `pjsip.conf` endpoint option, every `ps_auths` column after an auth option, and so on. For example, the `pjsip.conf` endpoint below,

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

is stored as one row across three tables. The `ps_endpoints` row holds `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000`; the `ps_auths` row holds `id=4000, auth_type=userpass, username=4000, password=supersecret`; and the `ps_aors` row holds `id=4000, max_contacts=1`. You only need to populate the columns you actually use — any column you leave NULL falls back to the option's default. If you want, for example, the `callerid` parameter on an endpoint, fill in the `callerid` column of `ps_endpoints` (the column name is the same as the `pjsip.conf` option name).

A voicemail table follows the same idea. Its columns map to the `voicemail.conf` fields:

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

The `uniqueid` should be unique to each voicemail user and can be autoincrement. It need not have any relationship to the mailbox or context.

### Building a dial plan using Asterisk Real Time

You can also use the real-time system to create the dial plan. ARA uses the `switch` statement to include the real-time extensions into the normal dial plan contained in the extensions.conf file. The extension table should look like the one below:

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

The `extensions` realtime family is unchanged in Asterisk 22; just make sure the `appdata` column dials PJSIP channels, for example `PJSIP/4000`. In the dial plan, you have to use the `switch` command to use the real time.

![Building a dial plan with Asterisk Real Time: extensions.conf uses a `switch => realtime` statement to pull extension rows (context, exten, priority, app, data) from a database table instead of from the text file.](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

or

```
[local]
switch => realtime/from-internal@extensions
```

## Lab: Installing and creating the database tables

In this lab, we will prepare the database to receive Asterisk parameters. We will prepare just the REALTIME tables. The static configuration will be left to the configuration text files (cool, isn't it?). Table creation in MySQL follows.

Step 1: Get into the MySQL database as root.

```
mysql -u root -p
```

Step 2: Log in to the MySQL server created in the CDR labs.

```
mysql -u astdb -p
```

When asked for the password, type supersecret.

Step 3: Create the necessary tables. The legacy static schema files still ship under `contrib/realtime/` (for example `/usr/src/asterisk-22.x/contrib/realtime/mysql`), but on Asterisk 22 the recommended and version-correct way to build the realtime tables — especially the PJSIP `ps_*` tables — is the **Alembic** migrations under `contrib/ast-db-manage` (see the "Creating the PJSIP realtime schema with Alembic" section above).

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

The Alembic `config` migration set builds the PJSIP `ps_*` tables (along with `voicemail`, `extensions`, and the other realtime schemas) with exactly the columns the running Asterisk version expects, so the schema always matches the build.

Use supersecret as the password.

Step 4: Verify the creation of the tables.

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

You should see the PJSIP `ps_*` tables (created by the Alembic `config` migration), along with the `voicemail`, `extensions`, and other realtime tables:

```
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

(Alembic creates more tables than these — the list above shows the ones relevant to this lab.)

Step 5: The database is already configured for ODBC (since the CDR lab), so no further ODBC setup is needed here.

Step 6: Inspect and populate the tables from the MySQL client. You do not need a graphical tool such as phpMyAdmin — every step in this chapter is plain, copy-pasteable SQL run from the `mysql` command line. Connect to the `astdb` database (use `supersecret` when prompted):

```
mysql -u astdb -p astdb
```

You can confirm the columns of a table at any time with `DESCRIBE`, for example:

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

These tables were created by the Alembic `config` migration, so their columns already match the `pjsip.conf` option names for the running Asterisk version — you only fill in the columns you need.

## Lab: Configuring and testing ARA

In this lab we will change the extconfig.conf configuration to reflect our database configuration and tables.

Step 1: Configure extconfig.conf and reload Asterisk.

```
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
ps_endpoints => odbc,cdr
ps_aors => odbc,cdr
ps_auths => odbc,cdr
ps_contacts => odbc,cdr
voicemail => odbc,cdr,voicemail
extensions => odbc,cdr,extensions
```

Note the `ps_endpoints`, `ps_aors`, `ps_auths`, and `ps_contacts` families above; together with the matching `sorcery.conf` mappings (see the "PJSIP Realtime (Sorcery)" section) they make PJSIP read its accounts from the database. The `voicemail` and `extensions` families round out the example.

Step 2: Real Time extension test. Create a new `6010` endpoint by inserting one row into each of `ps_auths`, `ps_aors`, and `ps_endpoints`, then try to register this endpoint with a softphone. Run the following SQL in the `mysql` client (`mysql -u astdb -p astdb`):

```sql
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('6010-auth', 'userpass', '6010', 'supersecret');

INSERT INTO ps_aors (id, max_contacts)
VALUES ('6010', 1);

INSERT INTO ps_endpoints
  (id, transport, aors, auth, context, disallow, allow, dtmf_mode, direct_media)
VALUES
  ('6010', 'transport-udp', '6010', '6010-auth', 'from-internal',
   'all', 'ulaw', 'rfc4733', 'no');
```

The three rows together describe one SIP account. The remaining account settings are spread across the PJSIP objects: context, codecs, DTMF mode, and media handling live on the endpoint (the last six columns above); dynamic registration lives on the AOR. There is no separate "dynamic" flag — an AOR accepts dynamic REGISTERs as long as `max_contacts` is greater than zero, and each registered location is written to `ps_contacts`.

In PJSIP the RFC 2833 / RFC 4733 out-of-band DTMF mode is named `rfc4733`, and `dtmf_mode=rfc4733` is the default — so the `dtmf_mode` column above is optional and shown only for clarity.

Step 3: Try to register the new phone with a softphone using username `6010` and password `supersecret`. Confirm the registration on the Asterisk CLI:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

Step 4: Include the extensions in the database.

```
mysql -u astdb -p
```

Enter password:

Use supersecret when asked, then insert the extension row from the MySQL client:

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

Step 5: Include Asterisk Real Time in the dial plan. In the context `default`:

```
switch => realtime/test@extensions
```

Reload the extensions to activate the change.

```
asterisk-server*CLI> extensions reload
```

Step 6: Reconfigure one of the phones to the username `bria`, if you have not already done so.

Step 7: Dial 6007 from an existing phone; the `bria` phone should ring.

## Summary

In this chapter, you have learned that Asterisk Real Time allows you to put your configurations into a database. Asterisk ships native realtime drivers for ODBC (which reaches any UnixODBC-supported database, including MySQL/MariaDB and SQLite) and PostgreSQL, plus an LDAP realtime driver for directory backends. MySQL/MariaDB is reached through ODBC, as we did in this chapter (a dedicated `res_config_mysql` add-on also exists, but it lives outside the core build, so ODBC is the common path). The configuration is divided into static and real time. Static configuration replaces the configuration files, while the real-time configuration creates dynamic objects that are loaded only when a call or other related event happens. We concluded with a practical lab on how to install and configure ARA.

## Quiz

1. Asterisk Realtime is part of the standard Asterisk distribution.
   - A. True
   - B. False
2. A database server's connection parameters are configured in the file:
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. The `extconfig.conf` file configures the tables used by Realtime. It has two distinct sections (check two):
   - A. Static configuration
   - B. Realtime configuration
   - C. Outbound routes
   - D. IP addresses and database ports
4. In static configuration, once the objects are loaded from the database they are kept in Asterisk's memory and refreshed only on start or reload.
   - A. True
   - B. False
5. PJSIP realtime (Sorcery) fully supports `qualify` and MWI for realtime endpoints, because Sorcery loads them as ordinary configured PJSIP objects rather than discarding them after each call the way the old SIP realtime peers were.
   - A. True
   - B. False
6. In PJSIP realtime, which tables hold the endpoints and their registered contacts?
   - A. `ps_endpoints` and `ps_contacts`
   - B. `ps_peers` and `ps_registry`
   - C. `ps_config` and `ps_data`
   - D. `extconfig` and `res_odbc`
7. You can still use text configuration files even after enabling ARA.
   - A. True
   - B. False
8. phpMyAdmin is mandatory when you use Realtime.
   - A. True
   - B. False
9. The database must be created with every field that exists in the configuration file.
   - A. True
   - B. False
10. On Asterisk 22, what is the recommended, version-correct way to create the PJSIP realtime tables (`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`)?
    - A. Hand-write the `CREATE TABLE` statements for each `ps_*` table
    - B. Import the legacy `mysql_config.sql` from `contrib/realtime/`
    - C. Run the Alembic `config` migrations under `contrib/ast-db-manage` (`alembic -c config.ini upgrade head`)
    - D. The tables are created automatically the first time Asterisk starts

**Answers:** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
