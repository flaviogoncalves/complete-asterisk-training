# Migration von chan_sip zu PJSIP: ein Kochbuch

Wenn Sie dies mit einem Asterisk 13, 16 oder 18 System lesen, das sich noch im Produktivbetrieb befindet, haben Sie eine Frist. `chan_sip` — der ursprüngliche SIP-Kanal-Treiber, der über `sip.conf` konfiguriert wurde — wurde **in Asterisk 17 als veraltet markiert, in Asterisk 19 aus dem Standard-Build entfernt und in Asterisk 21 vollständig gelöscht**. Er existiert in Asterisk 22 LTS nicht mehr. Es gibt kein Flag, um ihn wieder zu aktivieren, keinen `noload`, um dies zu umgehen, und kein Paket, das man installieren könnte. Der einzige SIP-Kanal-Treiber in Asterisk 22 ist **PJSIP** (`res_pjsip` plus `chan_pjsip`), konfiguriert über `pjsip.conf`.

Ein Upgrade auf Asterisk 22 ist daher für die meisten Standorte ebenso ein *SIP-Migrationsprojekt* wie ein Versionssprung. Die gute Nachricht ist, dass sich das Protokoll auf der Leitung nicht ändert — ein Telefon, das gestern registriert war und Anrufe tätigte, wird dies auch morgen tun — und Asterisk liefert ein Konvertierungstool mit, das die ersten 80 % der Übersetzung für Sie erledigt. Dieses Kapitel ist ein praktisches Kochbuch: die Konzeptzuordnung, das Konvertierungsskript, direkte `sip.conf` → `pjsip.conf` Übersetzungen für die Fälle, die Sie tatsächlich haben, die dialplan- und CLI-Änderungen, die mit dem Umstieg einhergehen, die realtime (Datenbank)-Migration sowie eine Checkliste und die Fallstricke, die Anwendern Probleme bereiten.

Alles hier wurde anhand der Asterisk 22.10.0-Laborumgebung des Buches überprüft. Das tiefgreifende Legacy-Material zu `chan_sip` selbst — sowie eine vollständige End-to-End-Konvertierung eines `sip.conf` mit mehreren Geräten — finden Sie im Kapitel *Legacy channels*; dieses Kapitel ist die fokussierte, rezeptartige Ergänzung dazu.

## Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Zu erklären, warum `chan_sip` in Asterisk 22 nicht mehr vorhanden ist und was es ersetzt
- Das `sip.conf` peer/user/friend-Modell auf das PJSIP-Objektmodell abzubilden
  (endpoint + aor + auth + identify + transport + registration)
- Das `sip_to_pjsip.py` Konvertierungsskript auszuführen und dessen Ausgabe kritisch zu prüfen
- Die gängigen Gerätetypen (registrierendes Telefon, eingehender trunk, ausgehende
  registration) manuell von `sip.conf` nach `pjsip.conf` zu übersetzen
- NAT-, media-, DTMF-, codec- und Authentifizierungseinstellungen Option für Option zu migrieren
- Den dialplan (`SIP/` → `PJSIP/`) und die CLI (`sip show` → `pjsip show`) zu aktualisieren
- Eine realtime/ARA-Bereitstellung von `sippeers`/`sipregs` auf die Sorcery
  `ps_*` Tabellen zu migrieren
- Eine Migrations-Checkliste abzuarbeiten und die klassischen Fallstricke zu vermeiden

## Warum überhaupt migrieren

`chan_sip` diente Asterisk fast zwei Jahrzehnte lang, war jedoch mit architektonischen Altlasten behaftet: ein monolithisches Modul, ein einzelner Konfigurationsblock pro Gerät, schwache Unterstützung für mehrere Transporte und ein SIP-Stack, der hinter den RFCs zurückgeblieben war. **PJSIP** — basierend auf dem ausgereiften pjproject-Stack von Teluu und eingeführt in Asterisk 12 — war der vollständige Ersatz von Grund auf. Mit Asterisk 21 hat das Asterisk-Projekt die Arbeit abgeschlossen und `chan_sip` aus dem Quellcode entfernt.

Sie können die Situation auf jedem Asterisk 22-System bestätigen:

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip` gibt *0 modules loaded* zurück — es ist schlichtweg nicht mehr vorhanden. Es gibt nichts, *zu* dem man migrieren könnte, außer PJSIP; die einzige wirkliche Frage ist also das *Wie*, nicht das *Ob*.

## Die konzeptionelle Abbildung: Es gibt keinen einzelnen "Peer"

Der mentale Wandel, der jeden stolpern lässt, der von `sip.conf` kommt, ist dieser: **PJSIP hat kein `[peer]`.** In `sip.conf` beschrieb ein einziger eingeklammerter Block — ein `peer`, ein `user` oder ein `friend` — *alles* über ein Gerät: seine Anmeldedaten, wie man es erreicht, seine codecs, sein NAT-Verhalten, seinen dialplan context. PJSIP zerlegt diesen einzelnen Block bewusst in mehrere kleinere, zweckgebundene Objekte, die jeweils mit einem `type=` versehen sind und *sich gegenseitig beim Namen referenzieren*:

| PJSIP-Objekt (`type=`) | Verantwortlichkeit |
| --- | --- |
| `endpoint` | Die Identität des Geräts bei der Anrufbehandlung: codecs, context, DTMF, Medien, NAT und Verweise auf seine `auth`/`aors`/`transport` |
| `aor` (Address of Record) | *Wo* das Gerät zu erreichen ist — registrierte oder statische Kontakte, `max_contacts`, qualify |
| `auth` | Anmeldedaten (Benutzername/Passwort) für eingehende und/oder ausgehende Authentifizierung |
| `identify` | Abgleich einer eingehenden Anfrage mit einem endpoint anhand der **Quell-IP** anstelle des `From` Benutzers |
| `transport` | Der/die abhörende(n) Socket(s): Protokoll, Bind-Adresse/Port, NAT/externe Adressen |
| `registration` | Ein **ausgehendes** REGISTER von Asterisk an einen Provider |

Die Unterscheidung zwischen `friend`/`peer`/`user` verschwindet vollständig — in PJSIP ist alles ein `endpoint`. Ein einzelner `sip.conf` friend wird daher typischerweise zu drei Objekten (`endpoint` + `auth` + `aor`), die sich einen Namen teilen und aufeinander verweisen:

```
                sip.conf                              pjsip.conf
            ┌──────────────┐              ┌──────────┐   ┌──────┐   ┌─────┐
            │   [2000]     │   becomes    │ endpoint │──▶│ auth │   │ aor │
            │ type=friend  │  ─────────▶  │  [2000]  │   │[2000]│   │[2000]│
            │ host=dynamic │              │  auth=───┼──▶└──────┘   └──────┘
            │ secret=...   │              │  aors=───┼───────────────▶ ▲
            └──────────────┘              └────┬─────┘
                                               │ transport=
                                               ▼
                                          ┌───────────┐
                                          │ transport │  (shared by all endpoints)
                                          └───────────┘
```

Der endpoint ist das Bindeglied. Er benennt einen `transport` (oder erbt den Standardwert), ein `auth` Objekt und einen oder mehrere `aors`. Das Objektmodell wird ausführlich in *SIP & PJSIP in depth* behandelt; hier benötigen wir es lediglich als Ziel jeder Übersetzung.

## Das `sip_to_pjsip.py` Konvertierungstool

Asterisk wird mit einem Python-Skript ausgeliefert, das eine bestehende `sip.conf` liest und eine `pjsip.conf` schreibt. Es wird nicht als CLI-Befehl ausgeführt — es befindet sich im **Asterisk-Quellcodeverzeichnis**, nicht in den installierten Binärdateien:

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Auf dem Asterisk 22.10.0 des Labors lautet der vollständige Pfad zum Beispiel `/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`. Dasselbe Verzeichnis enthält `sip_to_pjsql.py` (die realtime/SQL-Variante, die später behandelt wird) sowie die Hilfsmodule `astconfigparser.py`, `astdicts.py` und `sqlconfigparser.py`.

### Ausführung

Das Skript akzeptiert optionale Positionsargumente — `[input-file [output-file]]` — die standardmäßig auf `sip.conf` und `pjsip.conf` im aktuellen Verzeichnis gesetzt sind:

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

Die einzigen wirklichen Optionen sind:

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

Es liest die Eingabe, gibt `Converting to PJSIP...` aus und schreibt die Ausgabedatei. Intern durchläuft es jeden `sip.conf` Abschnitt und erstellt pro Gerät die passenden `endpoint`, `auth`, `aor`, `registration` und (sofern es diese ableiten kann) `transport` Objekte, wobei die Optionszuordnungen im nächsten Abschnitt automatisch angewendet werden.

### Was es tut — und seine Grenzen

Betrachten Sie die Ausgabe als **ersten Entwurf, nicht als fertige Datei.** Das Skript ist ehrlich bezüglich seiner eigenen Lücken: Alles, was nicht sauber zugeordnet werden kann, wird in einen klar abgegrenzten Block am Anfang der Ausgabedatei geschrieben:

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[softphone]
qualify = yes
...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
```

Beachten Sie in diesem echten Fragment, dass `qualify = yes` von einem `sip.conf` Peer im *nicht zugeordneten* Block gelandet ist — da PJSIP die Qualifizierung am **aor** mit `qualify_frequency` (Sekunden) vornimmt und nicht als boolescher Wert am Gerät, überlässt das Skript Ihnen die bewusste Einstellung. Die praktischen Einschränkungen, die Sie einplanen sollten:

- **Transports werden geraten, nicht entworfen.** Das Skript erstellt einen einfachen `transport-udp` aus `bindport`/`bindaddr`, kann aber Ihre TLS-Zertifikate, Ihre TCP-Anforderungen oder Ihr Multi-Bind-Layout nicht kennen. Überprüfen und schreiben Sie den Transport neu.
- **NAT und externe Adressen erfordern einen Menschen.** `externaddr`/`localnet` werden möglicherweise nicht sauber übernommen; bestätigen Sie `external_media_address`, `external_signaling_address` und `local_net` am Transport manuell.
- **`qualify`, benutzerdefinierte Timer und eine Handvoll Optionen landen im "nicht zugeordneten" Bereich.** Lesen Sie diesen Block von oben nach unten und entscheiden Sie über jeden Punkt.
- **Codec-Listen, contexts und Sicherheit müssen überprüft werden.** Verifizieren Sie `disallow`/`allow`, den dialplan `context` und stellen Sie sicher, dass kein Gerät unbeabsichtigt offen gelassen wurde.

Der Arbeitsablauf ist daher: Führen Sie das Skript in eine *Entwurfsdatei* aus, vergleichen und überprüfen Sie diese, übernehmen Sie die guten Teile in Ihre echte `pjsip.conf` und testen Sie dann vor dem produktiven Einsatz ausgiebig.

## Side-by-side translations

Dies sind die Rezepte. `sip.conf` auf der linken Seite, das verifizierte `pjsip.conf`
Äquivalent auf der rechten Seite (hier aus Platzgründen untereinander gestapelt). Jeder Optionsname und Wert
auf der rechten Seite wurde mit dem Asterisk 22 Labor unter Verwendung von
`config show help res_pjsip ...` überprüft.

### Ein registrierendes Telefon (`host=dynamic`)

Das gebräuchlichste Gerät: ein Tischtelefon oder softphone, das sich mit einem Passwort anmeldet und
seinen eigenen Standort registriert.

**Legacy `sip.conf`:**

```
[2000]
type=friend
host=dynamic
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmfmode=rfc2833
secret=Sup3rSecret
qualify=yes
```

**Asterisk 22 `pjsip.conf`:**

```
[2000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
auth=2000
aors=2000

[2000]
type=auth
auth_type=digest
username=2000
password=Sup3rSecret

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

Wichtige Schritte: `host=dynamic` wird zu einem `aor` mit `max_contacts` (das Gerät
sendet ein REGISTER, um seinen Kontakt einzutragen); `secret=` wird zu `password=` innerhalb eines
`type=auth`; `qualify=yes` wird zu `qualify_frequency=60` (Sekunden) auf dem
**aor**, nicht dem endpoint. Setzen Sie `max_contacts` nur dann auf einen Wert größer als 1, wenn Sie wirklich
dasselbe Konto auf mehreren Geräten gleichzeitig nutzen möchten.

### Ein eingehender trunk (`host=<ip>` / `type=peer`)

Ein Anbieter, der Ihnen Anrufe von einer bekannten IP-Adresse sendet. Hier findet keine Registrierung statt
— Sie authentifizieren den *Datenverkehr des Anbieters anhand seiner Quell-IP* unter Verwendung von `identify`.

**Legacy `sip.conf`:**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp-in]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw

[itsp-in]
type=aor
contact=sip:203.0.113.10:5060

[itsp-in]
type=identify
endpoint=itsp-in
match=203.0.113.10
```

Die entscheidende Übersetzung ist **`insecure=invite` → `identify`**. In `chan_sip`
wies `insecure=invite` Asterisk an: "Fordere bei eingehenden INVITEs von diesem Peer keine Authentifizierung an."
PJSIP erreicht denselben Effekt durch den *Abgleich der Quell-IP mit dem endpoint* mittels
`type=identify`/`match=`, was sowohl expliziter als auch sicherer ist. Das statische `host=` wird zu einem permanenten `contact=` auf dem `aor`, sodass Sie auch *ausgehend* zum Anbieter wählen können. `match=` akzeptiert eine IP, einen CIDR-Bereich oder einen Hostnamen (wird beim Laden der Konfiguration aufgelöst — laden Sie neu, falls sich die IP des Anbieters ändert).

### Eine ausgehende Registrierung (`register =>`)

Wenn der Anbieter möchte, dass *Sie* sich bei *ihm* anmelden, verwendete `chan_sip` eine einzelne
`register =>` Zeile in `[general]`. PJSIP ersetzt diese durch ein dediziertes
`type=registration` Objekt sowie ein `outbound_auth`.

**Legacy `sip.conf`:**

```
[general]
register => 1020:supersecret@sip.example.com:5600/9999

[itsp]
type=peer
host=sip.example.com
port=5600
defaultuser=1020
secret=supersecret
fromuser=1020
fromdomain=sip.example.com
context=from-pstn
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
outbound_auth=itsp-auth
aors=itsp-aor
from_user=1020
from_domain=sip.example.com

[itsp-auth]
type=auth
auth_type=digest
username=1020
password=supersecret

[itsp-aor]
type=aor
contact=sip:sip.example.com:5600

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:sip.example.com:5600
client_uri=sip:1020@sip.example.com:5600
contact_user=9999
retry_interval=60
```

Ordnen Sie die `register =>` Felder eins zu eins zu: die `1020:supersecret` Anmeldedaten werden zum
`auth` Objekt (referenziert als `outbound_auth`); `@sip.example.com:5600` wird zum
`server_uri`; das `/9999` Suffix — der Benutzerteil, an den der Anbieter eingehende
Anrufe zustellt — wird zu `contact_user=9999`. `defaultuser`/`fromuser` und `fromdomain`
werden zu `from_user` und `from_domain` auf dem endpoint. Beachten Sie, dass `outbound_auth`
*zweimal* vorkommt: die Registrierung verwendet es für das REGISTER, der endpoint verwendet es, um die
`407` Herausforderung bei ausgehenden INVITEs zu beantworten.

## Referenz zur Migration von Optionen

Wenn Sie die Migration manuell durchführen (oder die Ausgabe des Skripts überprüfen), dient diese Tabelle als Nachschlagewerk. Jeder PJSIP-Optionsname und die Platzierung (endpoint / aor / auth / transport) wurde im Asterisk 22 Labor verifiziert.

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | Ort |
| --- | --- | --- |
| `[peer]` / `[user]` / `[friend]` | `type=endpoint` (+ `auth` + `aor`) | — |
| `host=dynamic` | `max_contacts=1` (device REGISTERs) | aor |
| `host=<ip/host>` | `contact=sip:<host>:<port>` | aor |
| `register => u:p@host/ext` | `type=registration` + `outbound_auth` | registration |
| `secret=` | `password=` | auth |
| `username=` / `defaultuser=` | `username=` | auth |
| `secret=` (auth method) | `auth_type=digest` | auth |
| `nat=force_rport,comedia` | `force_rport=yes` + `rewrite_contact=yes` + `rtp_symmetric=yes` | endpoint |
| `directmedia=yes/no` | `direct_media=yes/no` | endpoint |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` | endpoint |
| `disallow=` / `allow=` | `disallow=` / `allow=` (same syntax) | endpoint |
| `context=` | `context=` | endpoint |
| `qualify=yes` | `qualify_frequency=<seconds>` | aor |
| `insecure=invite` | omit auth; use `type=identify` + `match=` | identify |
| `fromuser=` / `fromdomain=` | `from_user=` / `from_domain=` | endpoint |
| `externaddr=` / `externip=` | `external_media_address=` + `external_signaling_address=` | transport |
| `localnet=` | `local_net=` | transport |

### Eine Anmerkung zu `secret` → `auth` und `auth_type`

Das `secret=` von `chan_sip` wird zum Feld `password=` eines `type=auth`-Objekts. Die **Authentifizierungsmethode** wird mit `auth_type` festgelegt. Verwenden Sie `auth_type=digest`. Die älteren Werte `userpass` und `md5` funktionieren zwar noch, sind aber **veraltet und werden stillschweigend in `digest` konvertiert** — direkt aus dem Labor verifiziert:

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

Sie werden `auth_type=userpass` in älteren Konfigurationen und in der Ausgabe des Konvertierungsskripts (sowie in früheren Kapiteln dieses Buches) sehen. Es ist harmlos, aber schreiben Sie `digest` in allen neuen Konfigurationen.

### NAT, Medien und DTMF im Detail

Diese drei Punkte sind die Ursache für die meisten Support-Tickets nach der Migration vom Typ "es registriert sich, hat aber kein Audio". Das `chan_sip`-Kürzel `nat=force_rport,comedia` fasste drei Verhaltensweisen in einer Option zusammen; PJSIP teilt diese auf, damit Sie jede einzeln betrachten können:

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

Bei **Medien** wird aus `directmedia` ein `direct_media` (der Unterstrich ist die einzige Änderung); behalten Sie `direct_media=no` bei, wenn der Anruf zwingend über Asterisk laufen muss — sei es durch NAT, oder um aufzuzeichnen, zu transkodieren oder weiterzuleiten. Für **DTMF** wurde das RFC neu nummeriert: Das `dtmfmode=rfc2833` von `chan_sip` ist das `dtmf_mode=rfc4733` von PJSIP (derselbe Out-of-Band telephone-event Mechanismus, aktuelle RFC-Nummer). Das Labor bestätigt, dass die gültigen `dtmf_mode`-Werte `rfc4733`, `inband`, `info`, `auto` und `auto_info` sind, mit dem Standardwert `rfc4733`.

Bei **codecs** ändert sich nichts: `disallow=all` gefolgt von `allow=ulaw` (usw.) verwendet die identische Syntax am PJSIP endpoint.

## Dialplan und CLI-Änderungen

Die Migration endet nicht bei `pjsip.conf`. Zwei Dinge im täglichen Gebrauch ändern sich.

### Channel-Strings: `SIP/` → `PJSIP/`

Jeder `Dial()` und jede Channel-Referenz im `extensions.conf`, die die alte
Technologie benannte, muss aktualisiert werden:

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Trunk-Dial-Strings folgen demselben Muster — `Dial(SIP/${EXTEN}@itsp)` wird zu
`Dial(PJSIP/${EXTEN}@itsp)`. PJSIP fügt außerdem die Funktion `PJSIP_DIAL_CONTACTS()` hinzu,
um alle an eine AOR gebundenen Kontakte gleichzeitig zu rufen, sowie die Dialplan-Funktionen `PJSIP_HEADER()` /
`PJSIP_MEDIA_OFFER()`; durchsuchen Sie Ihren dialplan mittels grep nach `SIP/`,
`SIPPEER`, `SIPCHANINFO` und `CHANNEL(...)` SIP-Referenzen und übersetzen Sie jede einzelne.

### CLI: `sip show ...` → `pjsip show ...`

Der gesamte `sip ...` Befehlsbaum ist mit dem Treiber verschwunden. Die Ersatzbefehle:

| `chan_sip` Befehl | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (oder `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (oder `core reload`) |

Die alten Befehle verhalten sich nicht nur anders — sie existieren nicht mehr. Im
Labor gibt `sip show peers` *No such command* zurück, während `pjsip show endpoints`,
`pjsip show aors`, `pjsip show auths`, `pjsip show contacts`,
`pjsip show registrations` und `pjsip show identifies` alle vorhanden sind. Der nützlichste
Befehl zur Fehlerbehebung — der SIP-Paket-Logger, der jede Nachricht mit
`sip set debug` ausgab — ist jetzt **`pjsip set logger on`** (mit `pjsip set logger
host <ip>`, um sich auf einen einzelnen Peer zu konzentrieren).

## Realtime (ARA) Migration

Wenn Sie `chan_sip` aus einer Datenbank (Asterisk Realtime Architecture) betrieben haben, befanden sich Ihre Geräte in der Tabelle `sippeers` und Registrierungen in `sipregs`. PJSIP verwendet eine grundlegend andere Speicherschicht — **Sorcery** — mit einer Tabelle *pro Objekttyp*. Die Zuordnung sieht wie folgt aus:

| `chan_sip` Realtime-Tabelle | PJSIP / Sorcery Tabelle(n) |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (jeweils eine Zeile, aufgeteilt) |
| `sipregs` | `ps_contacts` (dynamische Registrierungen) |
| — (ausgehend `register=>`) | `ps_registrations` |
| — (IP-Abgleich) | `ps_endpoint_id_ips` (die `identify` Objekte) |
| — (Domain-Aliase) | `ps_domain_aliases` |

Die konzeptionelle Aufteilung ist dieselbe wie beim Flat-File-Fall: Eine `sippeers` Zeile wird zu *drei* Zeilen in drei Tabellen (`ps_endpoints` + `ps_aors` + `ps_auths`), die sich gegenseitig über den endpoint Namen referenzieren.

Zwei Dinge machen dies handhabbar:

- **Das Schema wird für Sie generiert.** Asterisk liefert Alembic-Migrationen unter `contrib/ast-db-manage/` mit, die jede `ps_*` Tabelle erstellen. Führen Sie `alembic upgrade head` gegen die `config` Datenbank aus, um das aktuelle PJSIP-Schema zu erstellen, anstatt DDL manuell zu schreiben.
- **Es gibt ein SQL-Konvertierungsskript.** Neben `sip_to_pjsip.py` befindet sich **`sip_to_pjsql.py`** im selben `contrib/scripts/sip_to_pjsip/` Verzeichnis; es verwendet dieselbe `convert()` Logik, gibt jedoch eine `pjsip.sql` Datei mit `INSERT` Anweisungen für die `ps_*` Tabellen aus, anstatt eine flache Konfigurationsdatei. Wie beim Flat-File-Tool sollten Sie die Ausgabe überprüfen, bevor Sie sie laden.

Verweisen Sie schließlich `sorcery.conf` auf Ihre Datenbank, damit PJSIP endpoints, aors, auths und contacts aus den `ps_*` Tabellen liest (via `res_config_odbc` / `res_pjsip_realtime`), genau wie `extconfig.conf` einst `sippeers` für `chan_sip` auf die Datenbank verwies. Die Realtime-Mechanismen werden im Kapitel *Realtime* behandelt; der migrationsspezifische Punkt ist lediglich, *welche Tabellen auf welche abgebildet werden*.

## Migrations-Checkliste

Eine pragmatische Reihenfolge der Arbeitsschritte für eine Produktivumstellung:

1. **Inventur.** Listen Sie jedes Gerät, jeden trunk und jede `register =>` in `sip.conf` (oder jede `sippeers`/`sipregs`-Zeile) auf. Notieren Sie benutzerdefinierte NAT-, codec- und DTMF-Einstellungen.
2. **Führen Sie den Konverter in eine temporäre Datei aus.**
   `sip_to_pjsip.py sip.conf pjsip_generated.conf`. Verweisen Sie dabei **nicht** auf Ihr
   live `pjsip.conf`.
3. **Lesen Sie den Block "Non mapped elements"** am Anfang der Ausgabe und lösen Sie
   jede Zeile auf — insbesondere `qualify`, Timer und alles, was mit NAT zu tun hat.
4. **Entwerfen Sie die transport(s) manuell.** Ein transport pro IP/Port; fügen Sie bei Bedarf TLS/TCP hinzu; setzen Sie `external_*_address` und `local_net` für Cloud/NAT-Boxen.
5. **Überprüfen Sie die Authentifizierung.** Bestätigen Sie `auth_type=digest`, Benutzernamen und Passwörter für jedes
   `auth`-Objekt.
6. **Überprüfen Sie NAT/Medien/DTMF.** `force_rport`/`rewrite_contact`/`rtp_symmetric`,
   `direct_media`, `dtmf_mode=rfc4733` pro endpoint nach Bedarf.
7. **Aktualisieren Sie den dialplan.** `SIP/` → `PJSIP/` überall; überprüfen Sie
   `SIP*`-Funktionen und Kanalvariablen.
8. **Aktualisieren Sie Skripte und Überwachung.** Jedes Tool oder jeder AMI-Consumer, der
   `sip show ...`-Ausgaben geparst hat, muss auf `pjsip show ...` / PJSIP AMI-Aktionen umgestellt werden.
9. **Neu laden und überprüfen.** `module reload res_pjsip.so`, dann
   `pjsip show endpoints`, `pjsip show registrations`, `pjsip show identifies`.
10. **Testen Sie mit dem Paket-Logger.** `pjsip set logger on`; führen Sie eine Registrierung,
    einen eingehenden Anruf und einen ausgehenden Anruf durch und lesen Sie den SIP-Austausch von Anfang bis Ende.

## Häufige Fallstricke

- **`alwaysauthreject` ist jetzt integriert — suchen Sie nicht danach.** `chan_sip` benötigte
  `alwaysauthreject=yes`, damit nicht durch unterschiedliche Antworten auf ungültige Benutzernamen durchsickerte, welche extensions existieren. PJSIP verhält sich von Grund auf sicher: Es verrät niemals, ob ein endpoint existiert. Es gibt keine `alwaysauthreject` Option, die eingestellt werden müsste. Der zugehörige Schutz — das Drosseln nicht identifizierter Absender — ist die globale Einstellung `unidentified_request_count` / `unidentified_request_period`, die standardmäßig aktiviert ist.

- **`insecure=invite` ist keine PJSIP-Option — verwenden Sie `identify`.** Es gibt kein
  `insecure=` in `pjsip.conf`. Der Weg, unauthentifizierte INVITEs von einem bekannten Provider zu akzeptieren, besteht darin, den endpoint anhand der Quell-IP mit `type=identify` / `match=` zu identifizieren. Schränken Sie die Übereinstimmung so weit wie möglich ein (spezifische Host-IPs, keine weiten CIDRs) und sichern Sie dies mit einem `type=acl` ab — ein IP-basierter trunk ohne Authentifizierung ist ein Ziel für Gebührenbetrug.

- **Ein Transport pro IP/Port.** Sie können nicht zwei transports an dieselbe IP:Port-Kombination binden, und Sie können nicht mehrere TCP- oder TLS-transports derselben IP-Version binden. Das Konvertierungsskript erzeugt möglicherweise einen transport, der mit einem bereits vorhandenen kollidiert — konsolidieren Sie dies zu einer einzigen, bewusst entworfenen Transportschicht.

- **`qualify=yes` lässt sich nicht in einen booleschen Wert übersetzen.** Er gehört als `qualify_frequency=<seconds>` zum **aor**. Der Konverter verschiebt `qualify=yes` in den nicht zugeordneten Block, genau deshalb, weil es auf dem endpoint kein äquivalentes boolesches Pendant gibt.

- **`secret=` ist keine endpoint-Option.** Zugangsdaten existieren nur in einem `type=auth` Objekt, auf das der endpoint *verweist* (`auth=` für eingehende, `outbound_auth=` für ausgehende Verbindungen). Ein Passwort direkt am endpoint zu hinterlegen, bewirkt nichts.

- **Das CLI und alle Scraping-Skripte schlagen stillschweigend fehl.** `sip show ...` gibt "No such command" zurück, nicht unbedingt einen Fehler, den Ihre Überwachung bemerken würde. Überprüfen Sie vor der Umstellung jeden Cronjob, jeden Nagios-Check und jeden AMI-Client auf `sip ` Befehle.

## Zusammenfassung

Die Migration auf Asterisk 22 bedeutet die Abkehr von `chan_sip`, da der Treiber in Asterisk 21 entfernt wurde und PJSIP der einzige verbleibende SIP-Kanal ist. Der Kern der Arbeit besteht darin, jedes `sip.conf` `peer`/`user`/`friend` — das alles in einem Block zusammenfasste — als eine Reihe von zusammenwirkenden PJSIP-Objekten neu zu formulieren: ein `endpoint` plus ein `auth`, ein `aor` und, je nach Gerät, ein `identify` (eingehender trunk), ein `registration` (ausgehende Anmeldung) und ein gemeinsam genutztes `transport`. Das Skript `sip_to_pjsip.py` in `contrib/scripts/sip_to_pjsip/` übernimmt den Großteil der Übersetzung und markiert ehrlicherweise alles, was es nicht zuordnen kann, in einem Block "Non mapped elements", aber seine Ausgabe ist lediglich ein erster Entwurf: Entwerfen Sie den transport, NAT und die Sicherheit manuell und testen Sie diese vor dem produktiven Einsatz. Aktualisieren Sie rund um die Konfiguration den dialplan (`SIP/` → `PJSIP/`) sowie Ihre Fingerfertigkeiten und Skripte (`sip show` → `pjsip show`, `sip set debug` → `pjsip set logger`). Realtime-Bereitstellungen wechseln von `sippeers`/`sipregs` zu den Sorcery `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts` Tabellen, wobei `sip_to_pjsql.py` und das `contrib/ast-db-manage` Schema als Hilfestellung dienen. Achten Sie auf die Fallstricke — `alwaysauthreject` ist integriert, `insecure=invite` wird zu `identify`, `qualify=yes` wird zu `qualify_frequency` und es gilt ein transport pro IP/port — und die Umstellung ist eher mechanisch als mysteriös.

## Quiz

1. Warum muss eine Asterisk 22-Bereitstellung PJSIP für SIP verwenden?
   - A. `chan_sip` ist langsamer, aber immer noch verfügbar
   - B. `chan_sip` wurde in Asterisk 21 entfernt und existiert in Asterisk 22 nicht mehr
   - C. PJSIP ist der Standard, aber `chan_sip` kann mit `modules.conf` geladen werden
   - D. `chan_sip` funktioniert in Asterisk 22 nur mit TLS

2. Ein einzelner `sip.conf` `type=friend`-Block wird üblicherweise zu welchem Satz von
   PJSIP-Objekten?
   - A. Ein einzelnes `type=peer`
   - B. Nur `type=endpoint`
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. In `sip.conf` bildet `host=dynamic` (das Gerät registriert seinen eigenen Standort) ab auf:
   - A. `type=identify` mit `match=dynamic`
   - B. ein `type=aor` mit `max_contacts` (das Gerät sendet REGISTER)
   - C. `direct_media=yes` auf dem endpoint
   - D. `type=registration`

4. Das `sip_to_pjsip.py`-Konvertierungsskript ist:
   - A. Ein CLI-Befehl: `asterisk -rx 'sip_to_pjsip'`
   - B. Ein Python-Skript im Asterisk-Quellbaum unter
     `contrib/scripts/sip_to_pjsip/`
   - C. Ein kompiliertes Modul, das beim Booten geladen wird
   - D. Teil von `res_pjsip.so`

5. Wahr oder Falsch: Die Ausgabe von `sip_to_pjsip.py` ist produktionsreif und sollte ohne Überprüfung geladen werden.

6. Die `chan_sip`-Kurzschreibweise `nat=force_rport,comedia` übersetzt sich bei einem PJSIP
   endpoint in welche drei Optionen?
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. `sip.conf`s `dtmfmode=rfc2833` wird zu welcher PJSIP-Einstellung?
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. Auf Asterisk 22 sollte ein `auth`-Objekt welches `auth_type` verwenden, und was ist der
   Status von `userpass`?
   - A. `auth_type=userpass`; es ist der einzige gültige Wert
   - B. `auth_type=digest`; `userpass` ist veraltet und wird zu `digest` konvertiert
   - C. `auth_type=md5`; `digest` ist veraltet
   - D. `auth_type=plaintext`; `digest` wurde entfernt

9. Ein `chan_sip`-Provider-Peer mit `insecure=invite` (akzeptiere unauthentifizierte
   INVITEs von einer bekannten IP) wird zu PJSIP migriert unter Verwendung von:
   - A. `insecure=invite` auf dem endpoint
   - B. `allowguest=yes` in `[global]`
   - C. einem `type=identify`-Objekt mit `match=<provider IP>`
   - D. `auth_type=anonymous`

10. Bei einer realtime-Migration wird die `chan_sip` `sippeers`-Tabelle durch welche
    PJSIP/Sorcery-Tabellen ersetzt?
    - A. Eine einzelne `pjsip_peers`-Tabelle
    - B. `ps_endpoints`, `ps_aors` und `ps_auths`
    - C. `sipregs` und `voicemail`
    - D. Nur `ps_contacts`

**Antworten:** 1 — B · 2 — C · 3 — B · 4 — B · 5 — Falsch · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
