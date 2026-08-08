# Asterisk Call Detail Records

Asterisk ermöglicht, wie andere Telefonie-Plattformen auch, die Abrechnung von Telefonaten. Es gibt verschiedene Programme auf dem Markt, die die von PBXs erzeugten Datensätze importieren können. Diese Datensätze werden unter anderem dazu verwendet, die korrekte Höhe der Rechnung sowie Statistiken zu überprüfen.

## Ziele

Nach Abschluss dieses Kapitels sollte der Leser in der Lage sein:

- Zu beschreiben, wo und in welchem Format die Datensätze generiert werden
- Datensätze unter Verwendung von ODBC (Open Database Connectivity) zu generieren
- Ein in die Abrechnung integriertes Authentifizierungsschema zu implementieren

## Asterisk CDR-Format

Asterisk generiert für jeden Anruf einen Call Detail Record (CDR). Diese Datensätze werden standardmäßig in einer Textdatei im CSV-Format (Comma Separated Value) unter `/var/log/asterisk/cdr-csv` gespeichert. Die Datei ist in die folgenden Felder unterteilt:

| Feld | Beschreibung | Typ |
|-------|-------------|------|
| Accountcode | Zu verwendende Kontonummer | String |
| Src | Caller ID-Nummer | String |
| Dst | Ziel-extension | String |
| Dcontext | Ziel-context | String |
| Clid | Caller ID mit Text | String |
| Channel | Verwendeter Kanal | String |
| Dstchannel | Zielkanal | String |
| Lastapp | Letzte Anwendung | String |
| Lastdata | Daten der letzten Anwendung | String |
| Start | Beginn des Anrufs | Datum/Uhrzeit |
| Answer | Annahme des Anrufs | Datum/Uhrzeit |
| End | Ende des Anrufs | Datum/Uhrzeit |
| Duration | Zeit vom Wählen bis zum Auflegen | Ganzzahl (Sekunden) |
| Billsec | Zeit von der Annahme bis zum Auflegen | Ganzzahl (Sekunden) |
| Disposition | Was mit dem Anruf geschah (ANSWERED, NO ANSWER, BUSY, FAILED, CONGESTION) | String |
| Amaflags | Flags (DEFAULT, OMIT, BILLING, DOCUMENTATION) | String |
| Userfield | Benutzerdefiniertes Feld | String |

Beispiel einer CSV-Datei. Jede Zeile ist ein Datensatz; die Felder erscheinen in der gleichen Reihenfolge wie in der obigen Tabelle (`accountcode` zuerst, `amaflags` zuletzt):

```text
# accountcode,src,dst,dcontext,clid,channel,dstchannel,lastapp,lastdata,
#   start,answer,end,duration,billsec,disposition,amaflags
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-5f30","PJSIP/8584-9153","Dial","PJSIP/8584,30,tT","2006-03-27 16:05:00","2006-03-27 16:05:00","2006-03-27 16:05:00","0","0","ANSWERED","DOCUMENTATION"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-96f5","PJSIP/8584-3312","Dial","PJSIP/8584,30,tT","2006-03-27 16:16:00","2006-03-27 16:16:00","2006-03-27 16:16:00","0","0","ANSWERED","BILLING"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-74ac","PJSIP/8584-297b","Dial","PJSIP/8584,30,tT","2006-03-27 16:22:00","2006-03-27 16:22:00","2006-03-27 16:22:00","0","0","ANSWERED","BILLING"
"1234","4830258576","2012348584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-2c5d","PJSIP/8584-9870","Dial","PJSIP/8584,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
"1234","4830258584","2012348576","default","""Luis Sample"" <4830258584>","PJSIP/8584-03fd","PJSIP/8576-645c","Dial","PJSIP/8576,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
```

## Account codes und automatisierte Message Accounting

Sie können account codes und amaflags für jeden Kanal festlegen. Normalerweise geschieht dies in der Konfigurationsdatei des Kanals (z. B. chan_dahdi.conf, pjsip.conf). Der Parameter amaflags definiert, was mit dem CDR-Datensatz geschehen soll. Die möglichen amaflag-Werte sind:

- Default
- Omit
- Billing
- Documentation

Ähnlich wie ein Datensatz für Billing oder Documentation markiert werden kann, lässt sich für jeden Datensatz ein account code festlegen. Der account code ist eine frei wählbare Zeichenkette (die `accountcode` endpoint-Option akzeptiert jeden String, und der CDR-Datensatz speichert ihn in einem 80-Zeichen-Feld), die üblicherweise verwendet wird, um einen Datensatz einer Abteilung oder Geschäftseinheit zuzuordnen. Beispiel: pjsip.conf endpoint-Sektion

```
[8576]
type=endpoint
accountcode=Support
```

Das AMA-Flag ist in Asterisk 22 keine `pjsip.conf` endpoint-Option; setzen Sie es pro Anruf aus dem dialplan heraus mit der `CHANNEL` Funktion (zum Beispiel `Set(CHANNEL(amaflags)=billing)`) oder mit `Set(CDR(amaflags)=billing)`.

## Ändern des CSV- und/oder CDR-Formats

Sie können das CSV-Format ändern, indem Sie die Datei cdr_custom.conf anpassen.

```
;
; Mappings for custom config file
;
[mappings]
Master.csv =>
"${CDR(clid)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}"
,"${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${C
DR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposit
ion)}","${CDR(amaflags)}","${CDR(accountcode)}","${CDR(uniqueid)}","${CDR(userf
ield)}"
```

Sie können das CDR-Format in der Datei cdr_custom.conf ändern.

## CDR-Speicherung

Die CDR-Speicherung kann auf verschiedene Arten erreicht werden. Die wichtigste Methode sind CSV-Textdateien, die einfach in Tabellenkalkulationen importiert werden können. Für kleine Unternehmen ist dies in der Regel ausreichend. Einige Abrechnungssoftware-Lösungen akzeptieren standardmäßig CSV-Dateien. Das Speichern von CDRs in einer Datenbank ist jedoch wesentlich besser und sicherer. Asterisk unterstützt verschiedene Datenbankvarianten. Es gibt einige grafische Oberflächen für die Abrechnung auf dem Markt. Bei so vielen Treibern, welchen sollte man wählen?

### Verfügbare Speichertreiber

- cdr_csv – Textdateien mit durch Kommas getrennten Werten
- cdr_custom – Anpassbare Textdateien mit durch Kommas getrennten Werten
- cdr_adaptive_odbc – Adaptives ODBC-Backend (bevorzugt für die Datenbank-Speicherung)
- cdr_odbc – unixODBC-unterstützte Datenbanken (veraltet; cdr_adaptive_odbc wird bevorzugt)
- cdr_pgsql – Postgres-Datenbanken
- cdr_tds (cdr_freetds) – Sybase- und MSSQL-Datenbanken via FreeTDS
- cdr_manager – CDR an das Manager Interface
- cdr_radius – CDR-RADIUS-Schnittstelle
- cdr_sqlite3_custom – Benutzerdefiniertes SQLite3-CDR-Modul

Das Modul `cdr_addon_mysql` (cdr_mysql), das in älteren Anleitungen empfohlen wurde, wurde in Asterisk 19 entfernt, daher gibt es in Asterisk 22 keinen nativen MySQL-CDR-Treiber mehr. Um CDRs in MySQL/MariaDB zu schreiben, verwenden Sie `cdr_adaptive_odbc` zusammen mit einem MySQL-ODBC-Treiber – der Ansatz, der in diesem Kapitel verwendet wird.

Die CDR-Aufzeichnung erfolgt für alle aktiven Module, die in der Datei /etc/asterisk/modules.conf geladen sind. Wenn der Parameter autoload=yes gesetzt ist, werden alle Module geladen. Um zu überprüfen, welche cdr_drivers aktuell im System geladen sind, verwenden Sie den folgenden Befehl:

```
asterisk*CLI> module show like cdr_
Module                 Description                              Use Count  Status
Support Level
cdr_adaptive_odbc.so   Adaptive ODBC CDR backend                0          Running
core
cdr_csv.so             Comma Separated Values CDR Backend       0          Running
extended
cdr_custom.so          Customizable Comma Separated Values CDR  0          Running
core
cdr_manager.so         Asterisk Manager Interface CDR Backend   0          Running
core
cdr_odbc.so            ODBC CDR Backend                         0          Running
extended
cdr_sqlite3_custom.so  SQLite3 Custom CDR Module                0          Not Running
extended
6 modules loaded
```

Wenn Sie den obigen Screenshot sehen, laufen mindestens cdr_adaptive_odbc, cdr_csv, cdr_custom, cdr_manager, cdr_odbc und cdr_sqlite3_custom. In den letzten Jahren, nach einigen Astricons, wurde mir klar, dass das Asterisk-Team ODBC bevorzugt. Es ist der einzige Treiber, der Connection Pooling unterstützt. Connection Pooling ist ein großer Vorteil in Bezug auf die Leistung, da Sie nicht für jeden Vorgang eine neue Verbindung öffnen müssen. Dieses Kapitel wurde zuvor mit cdr_mysql geschrieben. Ich bin für diese Ausgabe auf cdr_adaptive_odbc umgestiegen, auch wenn ich weiß, dass die Einrichtung etwas komplexer ist. Die Wahl für cdr_adaptive_odbc ermöglicht es uns auch, die CDR anzupassen. Sie können einfach eine neue CDR-Variable im dialplan setzen und die entsprechende Spalte zur Datenbank hinzufügen. Um beispielsweise den Audio-Jitter aufzuzeichnen:

```
Set(CDR(jitter)=${RTPAUDIOQOSJITTER})
```

### CSV-Speicherung

Wie bereits erwähnt, sendet Asterisk standardmäßig alle CDRs unter Verwendung des Moduls cdr_csv.so an eine CSV-Textdatei. Wenn Sie die Dateien in /var/log/asterisk/cdr-csv nicht sehen können, überprüfen Sie mit dem CLI-Befehl module show, ob das Modul geladen wird. Wenn es nicht geladen ist, überprüfen Sie die modules.conf. In diesem Kapitel werden wir CDRs als Backup an cdr_csv senden.

### Konfiguration der Datei modules.conf

Um nur die entsprechenden Module zu laden, verwenden Sie die folgenden Zeilen in der Datei modules.conf

```
noload => cdr_custom.so
noload => cdr_odbc.so
noload => cdr_manager.so
noload => cdr_sqlite3_custom.so
```

Jetzt haben wir nur noch cdr_csv und cdr_adaptive_odbc geladen.

## Installation und Konfiguration von ODBC unter Ubuntu 22.04

Ich bedauere es immer, detaillierte Anleitungen in einem Buch zu veröffentlichen. Sie ändern sich manchmal schneller, als das Buch veröffentlicht werden kann. Versionen ändern sich, Module ändern sich, versuchen Sie also, die hier aufgeführten Befehle an Ihre eigene Situation anzupassen. Meistens reichen geringfügige Änderungen aus, um die Installation zu reproduzieren. Achten Sie auf die Schritte, da selbst erfahrene Linux-Benutzer die Installation der ODBC-Treiber oft als schwierig empfinden.

Schritt 1 - Installieren Sie die erforderlichen Pakete:

```
apt-get install mysql-server unixodbc unixodbc-dev libltdl-dev libtool
```

Schritt 2 - Erstellen Sie eine Datenbank und einen Benutzer:

```
mysql -u root -p
```

(Verwenden Sie das Passwort, das Sie bei der Erstellung des mysql-Servers festgelegt haben) Geben Sie diese Befehle in der mysql-Befehlszeile ein:

```
CREATE USER 'astdb'@'%' IDENTIFIED BY 'supersecret';
CREATE DATABASE cdr;
GRANT ALL PRIVILEGES ON cdr.* TO 'astdb'@'%';
FLUSH PRIVILEGES;
EXIT
```

Schritt 3 - Erstellen Sie die Datenbank:

```
cd /usr/src/asterisk-22.*/contrib/scripts/realtime/mysql
mysql -u root -p astdb <mysql_cdr.sql
```

Schritt 4: Laden Sie den MySQL ODBC connector von Oracle herunter. Überprüfen Sie Ihr Betriebssystem mit: `lsb_release -a`. Besuchen Sie für Ubuntu 22.04 (x86_64) https://dev.mysql.com/downloads/connector/odbc/ und wählen Sie die aktuelle 8.x- oder 9.x-Version für Ubuntu 22.04. Der genaue Dateiname und die Versionsnummer ändern sich im Laufe der Zeit, setzen Sie also `VER` (unten) auf den Namen des aktuellen Linux glibc-Builds.

```
cd /usr/src
# Pick the current Linux (glibc) build for your platform from
# https://dev.mysql.com/downloads/connector/odbc/ and set VER to its name:
VER=mysql-connector-odbc-9.0.0-linux-glibc2.28-x86-64bit
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/9.0/$VER.tar.gz
tar -xzvf $VER.tar.gz
```

Schritt 5: Installieren Sie den ODBC-Treiber:

```
cd /usr/src/$VER
cp bin/* /usr/local/bin
cp lib/* /usr/local/lib
myodbc-installer -a -d -n "MySQL" -t "Driver=/usr/local/lib/libmyodbc9w.so"
```

Schritt 6 - Konfigurieren Sie den ODBC connector, bearbeiten Sie die Datei /etc/odbc.ini, um den DSN (Data Source Name) zu erstellen:

```
[astconn]
Description = MySQL connector for astdb database
Driver = /usr/local/lib/libmyodbc9w.so
Database = astdb
Server = localhost
Port = 3306
```

Schritt 7: Testen Sie den Treiberzugriff mit iSQL. iSQL ist ein Befehlszeilen-Dienstprogramm, um über unixodbc eine Verbindung zur Datenbank herzustellen.

```
isql -v astconn astdb supersecret
>show tables
```

Bitte fahren Sie nicht mit der Asterisk-Konfiguration fort, wenn Sie das Ergebnis des isql-Befehls nicht sehen können.

### Konfigurieren von ODBC in Asterisk

Bevor Sie cdr_adaptive_odbc konfigurieren können, sollten Sie zuerst die ODBC-Ressourcendatei konfigurieren.

Schritt 1 - Verbinden Sie Asterisk mit ODBC. Bearbeiten Sie die Datei res_odbc.conf:

```
[cdr]
enabled => yes
dsn => astconn
username => astdb
password => supersecret
pre-connect => yes
```

Schritt 2 – Starten Sie Asterisk neu und testen Sie es mit:

```
asterisk*CLI> odbc show
```

Die Ausgabe wird unten angezeigt.

```
asterisk*CLI> odbc show
ODBC DSN Settings
-----------------
Name:   cdr
DSN:    astconn
  Number of active connections: 1 (out of 20)
```

Schritt 3 – Konfigurieren Sie den adaptiven ODBC-Treiber in /etc/asterisk/cdr_adaptive_odbc.conf:

```
[cdr]
connection=cdr
table=cdr
```

Hier verweist `connection` auf den in `res_odbc.conf` definierten `[cdr]`-Verbindungsabschnitt, und `table` ist die Datenbanktabelle, in die CDRs geschrieben werden.

Schritt 4 – Laden Sie das Modul cdr_adaptive_odbc.so neu:

```
asterisk*CLI> reload cdr_adaptive_odbc
```

Schritt 5 – Führen Sie einige Anrufe durch und überprüfen Sie die Datenbank auf neue Datensätze. Um die Datenbank zu überprüfen:

```
mysql -u root -p
>use astdb
>select * from cdr;
```

## Anwendungen und Funktionen

Mehrere Anwendungen stehen im Zusammenhang mit der Abrechnung.

### CDR(accountcode)

Legt einen Account-Code fest, bevor eine andere Anwendung dial() aufgerufen wird; zum Beispiel: Format:

```
Set(CDR(accountcode)=account)
```

Der Account-Code kann mithilfe der Channel-Variable ${CDR(accountcode)} überprüft werden.

### CDR(amaflags)

Setzt ein Flag für Abrechnungszwecke. Die Optionen sind default, omit, documentation und billing.

```
Set(CDR(amaflags)=amaflags)
```

### Set(CDR_PROP(disable)=1)

Deaktiviert die CDR-Aufzeichnung für den aktuellen Channel, sodass kein CDR in die Datei oder Datenbank geschrieben wird. Das Zurücksetzen auf `0` aktiviert die Aufzeichnung wieder.

```
Set(CDR_PROP(disable)=1)
```

Die Anwendung `NoCDR()`, die in früheren Ausgaben hierfür verwendet wurde, wurde in Asterisk 21 entfernt; in Asterisk 22 deaktivieren Sie den CDR eines Channels stattdessen mit `Set(CDR_PROP(disable)=1)`.

### ResetCDR()

Setzt den Call Data Record zurück: Die `start`-Zeit (und, falls beantwortet, die `answer`-Zeit) wird auf die aktuelle Zeit gesetzt und alle CDR-Variablen werden gelöscht. Wenn die Option `v` gesetzt ist, bleiben die CDR-Variablen während des Zurücksetzens erhalten.

### Set(CDR(userfield)=Value)

Dieser Befehl setzt ein Benutzerfeld im CDR. Bei Verwendung von `cdr_adaptive_odbc` wird das Benutzerfeld automatisch gespeichert, wenn eine Spalte `userfield` in der CDR-Tabelle existiert — eine Neukompilierung des Quellcodes ist nicht erforderlich. Für CSV-Textdateien müssen Sie den Quellcode (cdr_csv.c) bearbeiten und Asterisk neu kompilieren, wenn Sie Benutzerfelder verwenden möchten.

Frühere Ausgaben speicherten CDRs in MySQL mit dem Modul `cdr_addon_mysql` (`cdr_mysql.conf`). Dieses Modul wurde in Asterisk 19 entfernt und ist daher in Asterisk 22 nicht verfügbar. Der unterstützte Weg ist nun `cdr_adaptive_odbc` mit einem MySQL-ODBC-Treiber, der das Benutzerfeld — sowie jede andere benutzerdefinierte Spalte — nativ durch sein adaptives Spalten-Mapping speichert.

### Anhängen an das Benutzerfeld

Frühere Ausgaben verwendeten die Anwendung `AppendCDRUserField()`, um Daten an das CDR-Benutzerfeld anzuhängen. Diese Anwendung wurde aus Asterisk entfernt; in Asterisk 22 hängen Sie Daten an das Benutzerfeld an, indem Sie es lesen und mit der Funktion `CDR` neu setzen, zum Beispiel `Set(CDR(userfield)=${CDR(userfield)}extra)`.

![13-call-detail-records Abbildung 1](../images/13-call-detail-records-img01.png)

## Benutzerauthentifizierung

Einige Unternehmen stellen ihren Mitarbeitern die geführten Gespräche in Rechnung. In Asterisk können Sie ein Authentifizierungsschema einrichten, das es Ihnen ermöglicht, den authentifizierten Benutzer in den CDR abzurechnen. Diese Authentifizierung kann mithilfe eines Passworts erfolgen, das als Parameter an die Authenticate-Anwendung übergeben wird – entweder als Passwortdatei, gekennzeichnet durch einen / (Schrägstrich) vor dem Parameter, oder als Asterisk-Datenbankschlüssel (unter Verwendung der Option `d`). Format:

```
Authenticate(password[,options[,maxdigits[,prompt]]])
Authenticate(/passwdfile[,options])
```

Optionen:

- a – Setzt den Account-Code des Kanals auf das eingegebene Passwort.
- d – Interpretiert den angegebenen Pfad als Asterisk-DB-Schlüssel anstelle einer literalen Datei.
- m – Interpretiert den Pfad als eine Datei mit `accountcode:passwordhash` Zeilen.
- r – Entfernt den Datenbankschlüssel nach erfolgreicher Authentifizierung (nur gültig mit `d`).

Wenn der Anrufer alle drei Versuche nicht besteht, wird der Kanal aufgelegt; die Ausführung des dialplan wird nicht fortgesetzt, behandeln Sie daher den Fehlerpfad in der Zeile nach `Authenticate()`. Beispiel (Internationale Anrufe):

```
exten=_9011.,1,Authenticate(/password,d)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

Die alte Option `j` (Sprung zur Priorität n+101 bei Fehler) und die Prioritätskonvention `+101` wurden schon vor langer Zeit aus Asterisk entfernt; ein fehlgeschlagenes `Authenticate()` legt einfach auf.

Um das Passwort von der Konsole aus in einen DB-Schlüssel einzufügen:

```
asterisk*CLI> database put senha 123456 1
```

## Verwendung von Passwörtern aus voicemail

Diese Anwendung bewirkt dasselbe wie authenticate, verwendet jedoch die Konfigurationsdatei von voicemail für das Passwort.

```
VMAuthenticate([mailbox][@context][,options])
```

Wenn eine Mailbox angegeben ist, wird nur das Passwort dieser Mailbox als gültig betrachtet. Wenn die Mailbox nicht angegeben ist, wird die Channel-Variable `${AUTH_MAILBOX}` mit der authentifizierten Mailbox gesetzt. Wenn die Option `s` gesetzt ist, werden die anfänglichen Ansagen übersprungen. Beispiel (Internationale Anrufe):

```
exten=_9011.,1,VMAuthenticate(${CALLERID(num)}@local,s)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

## Channel Event Logging (CEL)

CDR-Datensätze liefern eine Zusammenfassungszeile pro Anruf. Für eine detailliertere Ereignisverfolgung — wie etwa individuelle Kanalzustandsübergänge, Bridge-Eintritts-/Austrittsereignisse und vermittelte Transfer-Abschnitte — enthält Asterisk 22 das **Channel Event Logging (CEL)**, das über `/etc/asterisk/cel.conf` konfiguriert und durch Backends wie `cel_odbc` oder `cel_custom` gespeichert wird.

CEL ergänzt CDR, anstatt es zu ersetzen: CDR bleibt der Standard für Abrechnungszusammenfassungen, während CEL granulare Daten pro Ereignis liefert, die für Betrugserkennung, Qualitätsüberwachung und fortgeschrittene Berichterstattung nützlich sind.

Das Konfigurationsmuster von `cel.conf` spiegelt `cdr.conf` wider: Sie aktivieren die gewünschten Ereignistypen im Abschnitt `[general]` von `cel.conf` und konfigurieren dann jedes Speicher-Backend in seiner eigenen Datei — `cel_custom.conf` für CSV, `cel_odbc.conf` für eine ODBC-Datenbank (dieselbe `res_odbc.conf` Verbindung, die auch für CDRs verwendet wird). Sie können mit `cel show status` auf der CLI überprüfen, ob CEL aktiv ist.

## Zusammenfassung

In diesem Kapitel haben wir gelernt, wie man CDR-Aufzeichnungen in Textdateien und in einer MySQL-Datenbank implementiert. Wir haben außerdem gelernt, wie man amaflags und account codes setzt. Am Ende des Kapitels haben wir gelernt, wie man ein in CDR und Abrechnung integriertes Authentifizierungsschema verwendet.

## Quiz

1. Standardmäßig speichert Asterisk die CDR im Verzeichnis /var/log/asterisk/cdr-csv.
   - A. Falsch
   - B. Wahr
2. Asterisk kann CDRs in folgende Ziele schreiben (wählen Sie alle zutreffenden aus):
   - A. MySQL
   - B. Native Oracle
   - C. Microsoft SQL Server
   - D. CSV-Textdateien
   - E. unixODBC-unterstützte Datenbanken
3. Asterisk generiert jeweils nur für eine Art der Speicherung eine CDR.
   - A. Falsch
   - B. Wahr
4. Welche Asterisk amaflags sind verfügbar?
   - A. DEFAULT
   - B. OMIT
   - C. TAX
   - D. RATE
   - E. BILLING
   - F. DOCUMENTATION
5. Um eine Abteilung mit einer CDR zu verknüpfen, verwenden Sie den Befehl ___, und der Account-Code kann mit der Channel-Variable ___ ausgelesen werden.
6. Der Unterschied zwischen `Set(CDR_PROP(disable)=1)` und `ResetCDR()` besteht darin, dass das Deaktivieren der CDR verhindert, dass überhaupt ein Datensatz geschrieben wird, während `ResetCDR()` den aktuellen Datensatz zurücksetzt (auf Null setzt). (Die Anwendung `NoCDR()`, die zuvor CDRs deaktivierte, wurde in Asterisk 21 entfernt.)
   - A. Falsch
   - B. Wahr
7. Um ein benutzerdefiniertes Feld mit dem Modul `cdr_csv.so` zu verwenden, müssen Sie den Quellcode bearbeiten und Asterisk neu kompilieren.
   - A. Falsch
   - B. Wahr
8. Die drei Authentifizierungsmethoden, die für die Anwendung Authenticate() verfügbar sind, lauten:
   - A. Passwort
   - B. Passwortdatei
   - C. Asterisk DB (dbput und dbget)
   - D. Voicemail
9. Voicemail-Passwörter werden in einem separaten Abschnitt von `voicemail.conf` angegeben und sind nicht identisch mit den Voicemail-Benutzern.
   - A. Falsch
   - B. Wahr
10. Channel Event Logging (CEL) ersetzt CDR in Asterisk 22 — sobald CEL aktiviert ist, werden keine CDR-Abrechnungszusammenfassungen mehr erstellt.
    - A. Falsch
    - B. Wahr

**Antworten:** 1 — B · 2 — A, B, C, D, E · 3 — A · 4 — A, B, E, F · 5 — `Set(CDR(accountcode)=...)`; `${CDR(accountcode)}` · 6 — B · 7 — A · 8 — A, B, C · 9 — B · 10 — A
