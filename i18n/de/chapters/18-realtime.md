# Asterisk Real-Time

Wie Sie wissen, erfolgt die Konfiguration von Asterisk durch die Verwendung mehrerer Textdateien im Verzeichnis /etc/asterisk. Trotz der einfachen Handhabung von Textdateien gibt es einige bekannte Nachteile:

- Die Notwendigkeit, Asterisk bei jeder Änderung der Dateien neu zu laden
- Erhöhter Speicherverbrauch bei einer großen Anzahl von Benutzern
- Schwierigkeiten bei der Programmierung einer Provisionierungsschnittstelle unter Verwendung von Textdateien
- Keine Möglichkeit der Integration in bestehende Datenbanken

ARA oder Asterisk Realtime, wie es genannt wird, wurde von Anthony Minessale II, Mark Spencer und Constantine Filin entwickelt und wurde konzipiert, um eine transparente Integration mit SQL-Datenbanken zu ermöglichen. Eine LDAP-Schnittstelle ist ebenfalls verfügbar. Dieses System ist auch als Asterisk External Configuration bekannt und wird in /etc/asterisk/extconfig.conf konfiguriert. Sie können Konfigurationsdateien auf Tabellen in einer Datenbank abbilden (statische Konfiguration) sowie Echtzeit-Einträge für die dynamische Erstellung von Objekten verwenden, ohne Asterisk neu laden zu müssen.

## Ziele

Nach Abschluss dieses Kapitels sollte der Leser in der Lage sein:

- Die Vorteile und Einschränkungen von Asterisk Real Time zu verstehen.
- ODBC für die Verwendung mit ARA zu nutzen.
- ARA unter Verwendung von ODBC zu kompilieren und zu installieren.
- Das System in einer Laborumgebung zu testen.

## Wie funktioniert Asterisk Real Time?

In der neuen Real Time-Architektur wurde der gesamte datenbankspezifische Code in die Channel-Treiber verschoben. Der Channel ruft lediglich eine generische Routine auf, die die Datenbank durchsucht. Das Ergebnis ist ein aus Sicht des Quellcodes wesentlich einfacherer und saubererer Prozess. Der Zugriff auf die Datenbank erfolgt über drei Funktionen:

- STATIC: Wird verwendet, um eine statische Konfiguration einzurichten, wenn ein Modul geladen wird.
- REALTIME: Wird verwendet, um Objekte während eines Anrufs oder eines anderen Ereignisses zu suchen.


- UPDATE: Wird verwendet, um Objekte zu aktualisieren.

Unter Asterisk 22 werden SIP-endpoints vom **PJSIP**-Stack (`res_pjsip`) verarbeitet, der auf dem **Sorcery**-Objektmodell basiert. Mit dem `realtime`-Wizard lädt Sorcery jedes PJSIP-Objekt bei Bedarf aus der Datenbank, und diese Objekte existieren dann als gewöhnliche konfigurierte PJSIP-Objekte — nicht als die temporären Realtime-Peers, die der alte SIP-Treiber nach jedem Anruf verwarf.

Da es sich um echte Objekte handelt, funktionieren NAT-Traversal, Qualify und Message Waiting Indication (MWI) für Realtime-endpoints ganz normal. (Sorcery kann zusätzlich angewiesen werden, Objekte über einen `memory_cache`-Wizard im Arbeitsspeicher zwischenzuspeichern, aber das ist optional und unabhängig vom Realtime-Ladevorgang.) Wenn Sie ein Objekt in der Datenbank ändern, wird die Änderung bei der nächsten Abfrage übernommen; Sie müssen nicht nach jeder Bearbeitung neu laden. (Das ausgemusterte `chan_sip`-Realtime-Modell mit seinen `sippeers`/`sipusers`-Familien wird nur im Kapitel *Legacy Channels* behandelt.)

## Konfiguration von Asterisk Real Time

Für dieses Lab setzen wir voraus, dass Sie ODBC bereits aus dem CDR-Kapitel installiert haben. ARA wird in der Textdatei extconfig.conf konfiguriert, in der zwei Abschnitte leicht zu erkennen sind. Der erste ist der Abschnitt für statische Konfigurationsdateien, in dem Sie die Textkonfigurationsdateien durch Datenbanktabellen ersetzen können. Der zweite Abschnitt ist die Realtime-Konfigurations-Engine, in der Sie Datenbanktabellen für dynamische Objekte (peers/users) konfigurieren. Es ist nicht ungewöhnlich, Textdateien für die statische Konfiguration und die Datenbank für dynamische Einträge zu verwenden. In diesem Fall bleibt der erste Abschnitt unverändert.

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Architektur von Asterisk Real Time: Konfigurationsdateien und statische Datenbanktabellen werden beim Start von Asterisk geladen, während Realtime-Datenbanktabellen eine dynamische Konfiguration bereitstellen, die bei Bedarf während eines Anrufs gelesen wird.](../images/18-realtime-fig01.png)

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


### Abschnitt für statische Konfiguration

Im Abschnitt für statische Konfiguration speichern Sie das Äquivalent zu Konfigurationsdateien in der Datenbank. Diese Konfigurationen werden beim Laden von Asterisk gelesen. Einige Module lesen die Datenbank erneut, wenn Sie einen Reload durchführen. Beispiele für die statische Konfiguration sind:

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

Das Mapping statischer Dateien ist am nützlichsten für Konfigurationsdateien, die kein objektbezogenes Realtime-Äquivalent haben. Für PJSIP sollten Sie die objektbezogenen Realtime-Familien (`ps_endpoints`, `ps_aors` usw.), die später in diesem Kapitel beschrieben werden, dem Mapping der gesamten `pjsip.conf` als statische Datei vorziehen.

Oben sind drei Beispiele beschrieben. Im ersten binden Sie queues.conf an eine Tabelle queues in der Datenbank asteriskdb. Im zweiten Beispiel binden Sie pjsip.conf an die Tabelle pjsip_conf in der Datenbank asteriskdb, die in der odbc-Konfiguration definiert ist. Im letzten Beispiel binden Sie iax.conf an ein LDAP-Verzeichnis. MyBaseDN ist der Basis-DN, der durchsucht werden soll. Im vorherigen Beispiel wird die Anwendung app_queue.so geladen, während der MySQL-Treiber die Datenbank abfragt und die erforderlichen Informationen abruft.

### Abschnitt für Real Time-Konfiguration

Die Real-Time-Konfiguration (der zweite Teil der Datei extconfig.conf) ist der Ort, an dem das zu ladende Konfigurationsstück in Echtzeit konfiguriert, aktualisiert und entladen wird. Mit Real Time ist es nicht notwendig, die Konfigurationen neu zu laden. Die Real-Time-Syntax lautet wie folgt:

```
<family name> => <driver>,<database name>[,table_name]
```

Beispiel:

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

Hier haben wir fünf Konfigurationszeilen. In der ersten Zeile binden Sie die PJSIP/Sorcery-Familie `ps_endpoints` an eine Tabelle `ps_endpoints` in der Datenbank asteriskdb. In der letzten binden Sie die voicemail-Familie an die Tabelle test in der Datenbank asteriskdb. Jeder PJSIP-Objekttyp (endpoint, aor, auth, contact) erhält seine eigene Familie und Tabelle; der vollständige Satz wird im Abschnitt „PJSIP Realtime (Sorcery)“ weiter unten gezeigt. Die Familien `voicemail`, `extensions`, `queues` und `queue_members` sind in Asterisk 22 weiterhin gültig.

## PJSIP Realtime (Sorcery)

Unter Asterisk 22 werden SIP endpoints ausschließlich über den **PJSIP**-Stack (`res_pjsip`) verwaltet, der auf der **Sorcery**-Objekt-Abstraktionsschicht basiert. Anstatt eines einzelnen SIP-"Peers" unterteilt PJSIP ein SIP-Konto in mehrere Objekttypen, die jeweils in ihrer eigenen Realtime-Tabelle gespeichert werden:

| Sorcery-Objekttyp | Realtime-Tabelle | Inhalt |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | kontospezifische Einstellungen (context, codecs, DTMF, etc.) |
| aor (address of record) | ps_aors | Registrierungslimits und `qualify`-Einstellungen |
| auth | ps_auths | `username` / `password`-Anmeldedaten |
| contact | ps_contacts | der dynamisch registrierte Standort |
| domain alias | ps_domain_aliases | alternative SIP-Domains für einen endpoint |
| endpoint identifier by IP | ps_endpoint_id_ips | Zuordnung eines endpoint anhand der Quell-IP |

Realtime für PJSIP wird an zwei Stellen aktiviert. Zuerst müssen die Sorcery-Objekttypen in `extconfig.conf` auf Realtime gemappt werden:

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

Zweitens muss Sorcery angewiesen werden, den `realtime`-Wizard für diese Objekttypen in `sorcery.conf` zu verwenden. Der Mapping-Name (hier `res_pjsip`) ist das Modul, dessen Objekte Sie verschieben, und der Wert auf der rechten Seite verweist auf die Familie, die Sie in `extconfig.conf` definiert haben:

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

Sie können statische und Realtime-Objekte mischen. Wenn Sie einen Typ in `sorcery.conf` weglassen, liest dieser Objekttyp weiterhin aus `pjsip.conf`. Ein gängiges Muster ist es, statische Transports und globale Einstellungen in `pjsip.conf` zu belassen, während endpoints, aors, auths und contacts in der Datenbank gespeichert werden.

### Erstellen des PJSIP Realtime-Schemas mit Alembic

Asterisk liefert Datenbank-Migrationen für alle seine Realtime-Schemata unter `contrib/ast-db-manage` mit. Dies ist der unterstützte Weg, um die PJSIP-Tabellen zu erstellen (und Versions-Upgrades durchzuführen) — Sie müssen die `ps_*`-Tabellendefinitionen nicht mehr manuell schreiben. Das `config`-Migrationsset enthält die PJSIP/Sorcery-Tabellen.

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

Dies erstellt `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts` und die anderen PJSIP-Tabellen mit den korrekten Spalten für die laufende Asterisk-Version. (Alembic erfordert das Python-Paket `alembic` sowie einen SQLAlchemy-Treiber wie `pymysql` für MySQL/MariaDB oder `psycopg2` für PostgreSQL.)

Ein minimaler Realtime-endpoint besteht dann aus jeweils einer Zeile in drei Tabellen — zum Beispiel für den endpoint `6010`:

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

Nach dem Einfügen der Zeilen ist kein Neuladen erforderlich — das nächste REGISTER/INVITE ruft die Objekte aus der Datenbank ab. Sie können mit folgendem Befehl überprüfen, was Realtime zurückgegeben hat:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## Datenbankkonfiguration

Nachdem wir nun die Datei extconfig.conf konfiguriert haben, erstellen wir die Tabellen. Allgemein gesprochen entspricht jede Datenbankspalte einem Optionsnamen aus der entsprechenden Konfigurationsdatei. Die PJSIP `ps_*` Tabellen folgen dieser Regel: Jede `ps_endpoints` Spalte ist nach einer `pjsip.conf` endpoint Option benannt, jede `ps_auths` Spalte nach einer auth Option und so weiter. Zum Beispiel wird der folgende `pjsip.conf` endpoint,

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

als eine Zeile über drei Tabellen hinweg gespeichert. Die `ps_endpoints` Zeile enthält `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000`; die `ps_auths` Zeile enthält `id=4000, auth_type=userpass, username=4000, password=supersecret`; und die `ps_aors` Zeile enthält `id=4000, max_contacts=1`. Sie müssen nur die Spalten befüllen, die Sie tatsächlich verwenden — jede Spalte, die Sie NULL lassen, greift auf den Standardwert der Option zurück. Wenn Sie zum Beispiel den `callerid` Parameter für einen endpoint wünschen, füllen Sie die `callerid` Spalte von `ps_endpoints` aus (der Spaltenname ist identisch mit dem `pjsip.conf` Optionsnamen).

Eine voicemail Tabelle folgt dem gleichen Prinzip. Ihre Spalten werden auf die `voicemail.conf` Felder abgebildet:

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

Die `uniqueid` sollte für jeden voicemail Benutzer eindeutig sein und kann ein autoincrement Wert sein. Sie muss keine Beziehung zur mailbox oder zum context haben.

### Erstellen eines dialplan mit Asterisk Real Time

Sie können das Echtzeitsystem auch verwenden, um den dialplan zu erstellen. ARA verwendet die `switch` Anweisung, um die Echtzeit-extensions in den normalen dialplan einzubinden, der in der Datei extensions.conf enthalten ist. Die extension Tabelle sollte wie folgt aussehen:

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

Die `extensions` realtime Familie ist in Asterisk 22 unverändert; stellen Sie nur sicher, dass die `appdata` Spalte PJSIP Kanäle anwählt, zum Beispiel `PJSIP/4000`. Im dialplan müssen Sie den `switch` Befehl verwenden, um die Echtzeit zu nutzen.

![Erstellen eines dialplan mit Asterisk Real Time: extensions.conf verwendet eine `switch => realtime` Anweisung, um extension-Zeilen (context, exten, priority, app, data) aus einer Datenbanktabelle anstelle einer Textdatei abzurufen.](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

oder

```
[local]
switch => realtime/from-internal@extensions
```

## Lab: Installation und Erstellung der Datenbanktabellen

In diesem Lab bereiten wir die Datenbank vor, um Asterisk-Parameter zu empfangen. Wir werden nur die REALTIME-Tabellen vorbereiten. Die statische Konfiguration überlassen wir den Konfigurations-Textdateien (cool, oder?). Die Tabellenerstellung in MySQL folgt hier.

Schritt 1: Melden Sie sich als root bei der MySQL-Datenbank an.

```
mysql -u root -p
```

Schritt 2: Melden Sie sich bei dem MySQL-Server an, der in den CDR-Labs erstellt wurde.

```
mysql -u astdb -p
```

Wenn Sie nach dem Passwort gefragt werden, geben Sie supersecret ein.

Schritt 3: Erstellen Sie die notwendigen Tabellen. Die alten statischen Schema-Dateien werden immer noch unter `contrib/realtime/` ausgeliefert (zum Beispiel `/usr/src/asterisk-22.x/contrib/realtime/mysql`), aber bei Asterisk 22 ist der empfohlene und versionskorrekte Weg zum Aufbau der realtime-Tabellen — insbesondere der PJSIP `ps_*` Tabellen — die Verwendung der **Alembic**-Migrationen unter `contrib/ast-db-manage` (siehe den Abschnitt "Creating the PJSIP realtime schema with Alembic" oben).

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

Der Alembic `config` Migrationssatz erstellt die PJSIP `ps_*` Tabellen (zusammen mit `voicemail`, `extensions` und den anderen realtime-Schemata) mit exakt den Spalten, die die laufende Asterisk-Version erwartet, sodass das Schema immer mit dem Build übereinstimmt.

Verwenden Sie supersecret als Passwort.

Schritt 4: Überprüfen Sie die Erstellung der Tabellen.

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

Sie sollten die PJSIP `ps_*` Tabellen (erstellt durch die Alembic `config` Migration) sehen, zusammen mit den `voicemail`, `extensions` und anderen realtime-Tabellen:

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

(Alembic erstellt mehr Tabellen als diese — die obige Liste zeigt die für dieses Lab relevanten.)

Schritt 5: Die Datenbank ist bereits für ODBC konfiguriert (seit dem CDR-Lab), daher ist hier keine weitere ODBC-Einrichtung erforderlich.

Schritt 6: Untersuchen und befüllen Sie die Tabellen über den MySQL-Client. Sie benötigen kein grafisches Werkzeug wie phpMyAdmin — jeder Schritt in diesem Kapitel besteht aus einfachem, kopierbarem SQL, das über die `mysql` Befehlszeile ausgeführt wird. Verbinden Sie sich mit der `astdb` Datenbank (verwenden Sie `supersecret`, wenn Sie dazu aufgefordert werden):

```
mysql -u astdb -p astdb
```

Sie können die Spalten einer Tabelle jederzeit mit `DESCRIBE` bestätigen, zum Beispiel:

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

Diese Tabellen wurden durch die Alembic `config` Migration erstellt, daher stimmen ihre Spalten bereits mit den `pjsip.conf` Optionsnamen für die laufende Asterisk-Version überein — Sie füllen nur die Spalten aus, die Sie benötigen.

## Lab: Konfiguration und Test von ARA

In diesem Lab werden wir die Konfiguration in extconfig.conf anpassen, um unsere Datenbankkonfiguration und die Tabellen abzubilden.

Schritt 1: Konfigurieren Sie extconfig.conf und laden Sie Asterisk neu.

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

Beachten Sie die Familien `ps_endpoints`, `ps_aors`, `ps_auths` und `ps_contacts` oben; zusammen mit den entsprechenden `sorcery.conf`-Mappings (siehe Abschnitt „PJSIP Realtime (Sorcery)“) sorgen sie dafür, dass PJSIP seine Konten aus der Datenbank liest. Die Familien `voicemail` und `extensions` runden das Beispiel ab.

Schritt 2: Test der Realtime-extension. Erstellen Sie einen neuen `6010` endpoint, indem Sie jeweils eine Zeile in `ps_auths`, `ps_aors` und `ps_endpoints` einfügen, und versuchen Sie dann, diesen endpoint mit einem softphone zu registrieren. Führen Sie das folgende SQL im `mysql`-Client (`mysql -u astdb -p astdb`) aus:

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

Die drei Zeilen zusammen beschreiben ein SIP-Konto. Die übrigen Kontoeinstellungen verteilen sich auf die PJSIP-Objekte: context, codecs, DTMF-Modus und Medienverarbeitung befinden sich auf dem endpoint (die letzten sechs Spalten oben); die dynamische Registrierung befindet sich auf dem AOR. Es gibt kein separates „dynamisch“-Flag – ein AOR akzeptiert dynamische REGISTER-Anfragen, solange `max_contacts` größer als null ist, und jeder registrierte Standort wird in `ps_contacts` geschrieben.

In PJSIP wird der Out-of-Band-DTMF-Modus nach RFC 2833 / RFC 4733 als `rfc4733` bezeichnet, und `dtmf_mode=rfc4733` ist der Standardwert – daher ist die Spalte `dtmf_mode` oben optional und dient nur der Übersichtlichkeit.

Schritt 3: Versuchen Sie, das neue Telefon mit einem softphone unter Verwendung des Benutzernamens `6010` und des Passworts `supersecret` zu registrieren. Bestätigen Sie die Registrierung auf der Asterisk CLI:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

Schritt 4: Fügen Sie die extensions in die Datenbank ein.

```
mysql -u astdb -p
```

Passwort eingeben:

Verwenden Sie supersecret, wenn Sie dazu aufgefordert werden, und fügen Sie dann die extension-Zeile über den MySQL-Client ein:

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

Schritt 5: Binden Sie Asterisk Real Time in den dialplan ein. Im context `default`:

```
switch => realtime/test@extensions
```

Laden Sie die extensions neu, um die Änderung zu aktivieren.

```
asterisk-server*CLI> extensions reload
```

Schritt 6: Konfigurieren Sie eines der Telefone auf den Benutzernamen `bria` um, falls Sie dies noch nicht getan haben.

Schritt 7: Wählen Sie 6007 von einem bestehenden Telefon aus; das `bria`-Telefon sollte klingeln.

## Zusammenfassung

In diesem Kapitel haben Sie gelernt, dass Asterisk Real Time es Ihnen ermöglicht, Ihre Konfigurationen in einer Datenbank abzulegen. Asterisk liefert native Realtime-Treiber für ODBC (welches jede von UnixODBC unterstützte Datenbank erreicht, einschließlich MySQL/MariaDB und SQLite) sowie PostgreSQL mit, ergänzt durch einen LDAP-Realtime-Treiber für Verzeichnis-Backends. MySQL/MariaDB wird über ODBC erreicht, wie wir es in diesem Kapitel getan haben (ein dediziertes `res_config_mysql` Add-on existiert ebenfalls, aber es ist nicht Teil des Core-Builds, daher ist ODBC der übliche Weg). Die Konfiguration wird in statische und Realtime-Konfiguration unterteilt. Die statische Konfiguration ersetzt die Konfigurationsdateien, während die Realtime-Konfiguration dynamische Objekte erstellt, die nur geladen werden, wenn ein Anruf oder ein anderes zugehöriges Ereignis eintritt. Wir schlossen mit einem praktischen Labor ab, in dem gezeigt wurde, wie man ARA installiert und konfiguriert.

## Quiz

1. Asterisk Realtime ist Teil der Standard-Asterisk-Distribution.
   - A. Wahr
   - B. Falsch
2. Die Verbindungsparameter eines Datenbankservers werden in der folgenden Datei konfiguriert:
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. Die Datei `extconfig.conf` konfiguriert die Tabellen, die von Realtime verwendet werden. Sie hat zwei unterschiedliche Abschnitte (wählen Sie zwei):
   - A. Statische Konfiguration
   - B. Realtime-Konfiguration
   - C. Ausgehende Routen
   - D. IP-Adressen und Datenbank-Ports
4. Bei der statischen Konfiguration werden die Objekte nach dem Laden aus der Datenbank im Arbeitsspeicher von Asterisk gehalten und nur beim Start oder Neuladen aktualisiert.
   - A. Wahr
   - B. Falsch
5. PJSIP Realtime (Sorcery) unterstützt vollständig `qualify` und MWI für Realtime-endpoints, da Sorcery diese als gewöhnliche konfigurierte PJSIP-Objekte lädt, anstatt sie nach jedem Anruf zu verwerfen, wie es bei den alten SIP-Realtime-peers der Fall war.
   - A. Wahr
   - B. Falsch
6. Welche Tabellen enthalten in PJSIP Realtime die endpoints und deren registrierte Kontakte?
   - A. `ps_endpoints` und `ps_contacts`
   - B. `ps_peers` und `ps_registry`
   - C. `ps_config` und `ps_data`
   - D. `extconfig` und `res_odbc`
7. Sie können auch nach der Aktivierung von ARA weiterhin Textkonfigurationsdateien verwenden.
   - A. Wahr
   - B. Falsch
8. phpMyAdmin ist zwingend erforderlich, wenn Sie Realtime verwenden.
   - A. Wahr
   - B. Falsch
9. Die Datenbank muss mit jedem Feld erstellt werden, das in der Konfigurationsdatei existiert.
   - A. Wahr
   - B. Falsch
10. Was ist unter Asterisk 22 die empfohlene, versionskorrekte Methode zum Erstellen der PJSIP-Realtime-Tabellen (`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`)?
    - A. Manuelles Schreiben der `CREATE TABLE`-Anweisungen für jede `ps_*`-Tabelle
    - B. Importieren der veralteten `mysql_config.sql` aus `contrib/realtime/`
    - C. Ausführen der Alembic `config`-Migrationen unter `contrib/ast-db-manage` (`alembic -c config.ini upgrade head`)
    - D. Die Tabellen werden beim ersten Start von Asterisk automatisch erstellt

**Antworten:** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
