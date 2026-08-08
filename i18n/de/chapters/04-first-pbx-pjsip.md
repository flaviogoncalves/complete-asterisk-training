# Aufbau Ihrer ersten PBX mit PJSIP

In diesem Kapitel lernen Sie, wie Sie eine grundlegende Asterisk PBX-Konfiguration durchführen. Das Hauptziel besteht darin, die PBX zum ersten Mal in Betrieb zu nehmen, Anrufe zwischen extensions zu tätigen, eine abgespielte Nachricht anzurufen und einen Anruf über ein einzelnes analoges oder SIP trunk zu führen. Die Idee hinter diesem Kapitel ist es, sicherzustellen, dass Ihr Asterisk so schnell wie möglich einsatzbereit ist. Nachdem Sie die Arbeit in diesem Kapitel abgeschlossen haben, verfügen Sie über ausreichend Hintergrundwissen, um sich auf die nachfolgenden Kapitel vorzubereiten, in denen wir tiefer in die Konfigurationsdetails eintauchen werden.

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Konfigurationsdateien zu verstehen und zu bearbeiten;
- Softphones auf Basis von SIP zu installieren;
- Einen SIP trunk zu installieren und zu konfigurieren;
- Eine analoge Verbindung zu installieren und zu konfigurieren;
- Zwischen extensions zu wählen;
- Zwischen Telefonen und externen Zielen zu wählen; und
- Einen IVR zu konfigurieren.

## Verständnis der Konfigurationsdateien

Asterisk wird über Text-Konfigurationsdateien gesteuert, die sich unter /etc/asterisk befinden. Das Dateiformat ähnelt den Windows-“.ini”-Dateien. Ein Semikolon wird als Kommentarzeichen verwendet, die Zeichen “=” und “=>” sind gleichwertig und Leerzeichen werden ignoriert.

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asterisk interpretiert “=” und “=>” auf die gleiche Weise. Unterschiede in der Syntax werden verwendet, um zwischen Objekten und Variablen zu unterscheiden. Verwenden Sie “=”, wenn Sie eine Variable deklarieren möchten, und “=>”, um ein Objekt zu bezeichnen. Die Syntax ist in allen Dateien gleich, aber es werden drei Arten von Grammatik verwendet, wie unten erläutert.

## Grammars

| Grammatik | Wie das Objekt erstellt wird | Konfig.-Datei | Beispiel |
|---------|---------------------------|------------|---------|
| Simple Group | Alles in derselben Zeile | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| Option Inheritance | Optionen werden zuerst definiert, das Objekt erbt die Optionen | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| Complex Entity | Jede Entität erhält einen context | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### Simple Group

Das in `extensions.conf` und `voicemail.conf` verwendete Simple-Group-Format ist die grundlegendste Grammatik. Jedes Objekt wird zusammen mit seinen Optionen in derselben Zeile deklariert. Beispiel:

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

In diesem Beispiel wird Objekt 1 mit den Optionen op1, op2 und op3 erstellt, während Objekt 2 ebenfalls mit den Optionen op1, op2 und op3 erstellt wird.

### Object options inheritance grammar

Dieses Format wird von den Dateien chan_dahdi.conf und agents.conf verwendet, wo zahlreiche Optionen verfügbar sind und die meisten Schnittstellen und Objekte dieselben Optionen teilen. Typischerweise enthalten ein oder mehrere Abschnitte Deklarationen für Objekte und Kanäle. Optionen für das Objekt werden oberhalb des Objekts deklariert und können für ein anderes Objekt geändert werden. Obwohl dieses Konzept schwer zu verstehen ist, ist es sehr einfach anzuwenden. Beispiel:

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

Die ersten beiden Zeilen konfigurieren den Wert der Optionen op1 und op2 auf „bas“ beziehungsweise „adv“. Wenn Objekt 1 instanziiert wird, wird es mit Option 1 als „bas“ und Option 2 als „adv“ erstellt. Nach der Definition von Objekt 1 ändern wir Option 1 auf „int“. Als Nächstes erstellen wir Objekt 2 mit Option 1 als „int“ und Option 2 als „adv“.

### Complex entity object

Dieses Format wird von pjsip.conf, iax.conf und anderen Konfigurationsdateien verwendet, in denen zahlreiche Entitäten mit vielen Optionen existieren. Typischerweise teilt dieses Format kein großes Volumen an gemeinsamen Konfigurationen. Jede Entität erhält einen context. Manchmal existieren reservierte contexts, wie [general] für globale Konfigurationen. Optionen werden innerhalb der context-Deklarationen deklariert. Beispiel:

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

Die Entität [entity1] hat die Werte „value1“ und „value2“ für die Optionen op1 beziehungsweise op2. Die Entität [entity2] hat die Werte „value3“ und „value4“ für die Optionen op1 und op2.

## Optionen zum Aufbau eines LAB für Asterisk

Um eine PBX zu konfigurieren, benötigen Sie einige grundlegende Hardware. Dies ist weder schwierig noch teuer, aber es gibt einige Optionen, die in Betracht gezogen werden sollten. Alles, was Sie benötigen, sind zwei Telefone und eine Verbindung zum öffentlichen Netzwerk. Beim Erstellen Ihres LAB sind einige Optionen und Kombinationen möglich, die wir im Folgenden besprechen werden.

### Option 1: Vollständiges LAB

Mit dem vollständigen LAB ist es möglich, alle verfügbaren Szenarien zu testen und Lösungen wie ATA, IP-phones und softphones zu vergleichen. Sie können auch etwas über analoge und SIP trunks lernen. Sie benötigen:

- Einen SIP analog telephone adapter (ATA)
- Ein IP phone
- Einen dedizierten Server für Asterisk
- Eine Workstation mit einem softphone
- Eine analoge Schnittstellenkarte mit mindestens zwei Schnittstellen (1 FXO und 1 FXS)
- Ein Konto bei einem VoIP provider

### Option 2: Economy LAB

Mit dem economy LAB vereinfachen wir das Ganze ein wenig. Wir verwenden den ATA, der normalerweise weniger teuer ist als das IP-phone, und eine einzelne FXO-Karte, die wirklich kostengünstig ist. Wir werden keine analogen Telefone direkt an den Server anschließen können, aber dies kommt in der Praxis normalerweise nicht vor. Sie benötigen:

- Einen SIP analog telephone adapter (ATA)
- Einen dedizierten Server für Asterisk
- Eine Workstation für das softphone
- Eine analoge Schnittstellenkarte mit 1 FXO
- Ein Konto bei einem VoIP provider

### Option 3: Super economy LAB

Das dritte LAB verwendet einen virtualisierten Server auf dem eigenen Notebook des Studenten. Das Problem bei diesem Modell sind die Konflikte, die durch den UDP-Port entstehen. Manchmal versuchen sowohl der Asterisk-Server als auch das softphone, auf denselben Port zuzugreifen, was verhindert, dass Asterisk den Adress-Port bindet. Ein weiteres Problem ist die Qualität der Anrufe; virtuelle Umgebungen sind für Echtzeitanwendungen wie Asterisk nicht geeignet. Verwenden Sie ein kostenloses softphone für den Server und die Workstation sowie eine trunk-Verbindung zu einem SIP provider. Sie benötigen:

- Einen Laptop, auf dem ein softphone läuft
- Eine virtuelle Maschine (VirtualBox, VMware oder ähnlich), um Asterisk zu installieren
- Ein Konto bei einem VoIP provider

## Installationsreihenfolge

Um Ihnen das Verständnis der Installationsreihenfolge zu erleichtern, haben wir die notwendigen Schritte zur Installation und Konfiguration von Asterisk skizziert.

![Referenz-Laboraufbau: SIP/IAX-Softphones, ein IP-Telefon und analoge Adapter als Extensions (1), der Asterisk-Server mit ETH0/FXO/FXS-Schnittstellen (3) sowie die Trunks zum PSTN über einen VoIP-Anbieter oder eine Breitbandverbindung (2).](images/lab_layout.png){width=100%}(../images/04-first-pbx-fig01.png)

1. Konfiguration der Extensions
   - a. SIP-Extensions (ATA, Softphone, IP-Telefon)
   - b. IAX-Extensions
   - c. FXS-Extensions
2. Konfiguration der Trunks
   - a. Konfiguration eines SIP-Trunks
   - b. Konfiguration eines FXO-Trunks
3. Erstellung eines grundlegenden dialplan
   - a. Wählen zwischen Extensions
   - b. Wählen externer Ziele
   - c. Entgegennahme eines Anrufs an der Operator-Extension
   - d. Entgegennahme eines Anrufs in einem IVR

## Konfiguration der extensions

Die extensions sind SIP-, IAX- oder analoge Telefone, die an einen FXS-Port angeschlossen sind. Um eine extension zu konfigurieren, sollten Sie die Konfigurationsdatei bearbeiten, die sich auf den jeweiligen Kanal bezieht (pjsip.conf, iax.conf, chan_dahdi.conf).

### SIP extensions

In Asterisk 22 ist PJSIP (der `res_pjsip` Stack, konfiguriert in `/etc/asterisk/pjsip.conf`) der SIP-Kanaltreiber. Er unterstützt mehrere Transporte pro endpoint, wird aktiv gepflegt und ist der einzige SIP-Treiber, der mit der Plattform ausgeliefert wird. (Der ursprüngliche `chan_sip` Treiber wurde in Asterisk 21 entfernt – siehe das Kapitel *Legacy channels*, falls Sie eine alte Konfiguration migrieren müssen.)

Die Idee hier ist, eine einfache PBX zu konfigurieren. (Nachfolgende Kapitel bieten eine vollständige SIP/PJSIP-Sitzung mit allen Details.) PJSIP wird in `/etc/asterisk/pjsip.conf` konfiguriert und enthält alle Parameter, die sich auf SIP-Telefone und VoIP-Provider beziehen. SIP-Clients müssen konfiguriert werden, bevor Sie Anrufe tätigen und empfangen können.

#### Der Transport

In PJSIP befindet sich die Listener-Konfiguration (Bind-Adresse, Port, Protokoll) in einem `transport` Objekt. Asterisk verfügt über einen eingebauten Schutz gegen das Erraten von Benutzernamen – es gibt für unbekannte und bekannte Benutzer immer eine identische Authentifizierungsaufforderung zurück, und wiederholte nicht identifizierte Anfragen von einer IP werden über die `[global]` Optionen `unidentified_request_count`/`unidentified_request_period` ratenbegrenzt. Die wichtigsten Optionen eines Transports sind:

- protocol: Das Transportprotokoll – `udp`, `tcp`, `tls`, `ws` oder `wss`.
- bind: Adresse und Port, an die der Listener gebunden wird. Wenn Sie die Adresse auf `0.0.0.0` setzen, bindet er an alle Schnittstellen; der SIP-Port ist standardmäßig 5060 für UDP/TCP.

Ein minimaler UDP-Transport:

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

Die codec-Auswahl (`disallow`/`allow`) und der standardmäßige `context` werden auf jedem `endpoint` (unten dargestellt) konfiguriert, nicht auf dem Transport. Anonyme/Gast-Anrufe werden von einem `endpoint` namens `anonymous` behandelt. Registrierungs-Timer werden pro AOR über `maximum_expiration`/`default_expiration` gesteuert.

#### SIP-Clients

Nachdem der Transport-Abschnitt abgeschlossen ist, ist es an der Zeit, die SIP-Clients einzurichten. Ich möchte den Leser noch einmal daran erinnern, dass wir später im Buch ein vollständiges SIP/PJSIP-Kapitel haben werden. Konzentrieren wir uns für den Moment auf die Grundlagen und überlassen die Details dem späteren Verlauf.

In PJSIP wird ein SIP-Client aus einer Reihe zusammengehöriger Objekte aufgebaut, die durch Namensreferenz miteinander verbunden sind:

- `endpoint`: Das Anrufverhalten – codecs (`allow`/`disallow`), der dialplan `context` sowie welche `auth` und `aors` verwendet werden.
- `auth`: Die Anmeldedaten. `username` ist der SIP-Authentifizierungsbenutzer und `password` ist das secret, das zur Authentifizierung des Geräts verwendet wird.
- `aor`: Die "address of record" – wo der endpoint erreicht werden kann. Entweder ein statischer `contact=` (für ein Gerät mit fester IP) oder `max_contacts=`, damit sich das Gerät dynamisch registrieren kann.

Warnung: Verwenden Sie starke Passwörter mit mindestens 8 Zeichen, alphanumerischen und numerischen Zeichen sowie mindestens einem Symbol. Berichte über gehackte Server sind in den Mailinglisten aufgetaucht, und Brute-Force-Passwort-Cracker für SIP sind für Script-Kiddies leicht verfügbar. Gebührenbetrug kostet Verbraucher und Anbieter Tausende von Dollar.

Endpoint 6000 ist ein Gerät mit einer festen IP, daher trägt sein AOR einen statischen `contact`, anstatt eine Registrierung zu erlauben. Endpoint 6001 ist ein Gerät, das sich registriert, daher erlaubt sein AOR die Registrierung (`max_contacts=1`):

```
[6000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6000-auth
aors=6000

[6000-auth]
type=auth
auth_type=digest
username=6000
password=#MySecret1#7

[6000]
type=aor
contact=sip:6000@10.1.30.50

[6001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6001-auth
aors=6001

[6001-auth]
type=auth
auth_type=digest
username=6001
password=Mys3cr3t#

[6001]
type=aor
max_contacts=1
```

PJSIP erlaubt es den Abschnitten `endpoint`, `auth` und `aor`, denselben Abschnittsnamen zu verwenden (z. B. die beiden `[6001]` Blöcke oben, unterschieden durch ihr `type=`); viele Administratoren hängen stattdessen Suffixe an (`[6001]`, `[6001-auth]`, `[6001]` aor), um die Lesbarkeit zu verbessern. Bei einem Gerät, das sich registriert, wird der Kontakt dynamisch gelernt, wenn sich das Telefon registriert, daher benötigt der AOR keinen statischen `contact`.

## IAX Extensions

`chan_iax2` wird in Asterisk 22 zwar noch mitgeliefert, gilt aber inzwischen als veraltet; SIP/PJSIP ist das bevorzugte Protokoll für neue Implementierungen.

Sie können auch IAX extensions erstellen. Dieses Protokoll ist nativ für Asterisk, und wir werden diesem Thema später in diesem Buch einen eigenen Abschnitt widmen. Erstellen wir für den Moment einige extensions unter Verwendung dieses Protokolls. Als erster zu konfigurierender Abschnitt enthält der Bereich [general] bestimmte Parameter, die konfiguriert werden müssen. Die wichtigsten Optionen sind:

- allow/disallow: Definiert, welche codecs verwendet werden sollen.
- bindaddr: Adresse, an die der IAX2-Listener gebunden wird. Wenn Sie sie auf 0.0.0.0 (Standard) setzen, wird er an alle Schnittstellen gebunden.
- context: Legt den Standard-context für alle Clients fest, sofern dies nicht im Client-Abschnitt geändert wird. Wir haben aus Sicherheitsgründen dummy verwendet. Nicht authentifizierte Benutzer gelangen in diesen context, wenn die Option allowguest auf yes gesetzt ist.
- bindport: IAX2 UDP-Port, auf dem gelauscht werden soll (Standard 4569).
- delayreject: Wenn auf yes gesetzt, verzögert dies das Senden einer Authentifizierungsablehnung für ein REGREQ oder AUTHREQ, was die Sicherheit gegen Brute-Force-Passwortangriffe verbessert.
- bandwidth: Wenn auf high gesetzt, ermöglicht dies die Auswahl von codecs mit hoher Bandbreite, wie z. B. g711 in den Varianten ulaw und alaw.

Das Folgende ist ein Beispiel für den [general]-Abschnitt der Datei iax.conf.

```
[general]
bindport = 4569
bindaddr = 10.1.30.45 ;(use your IP)
context = dummy
delayreject=yes
bandwidth=high
disallow = all
allow = ulaw
```

### IAX Clients

Nachdem die allgemeinen Abschnitte fertiggestellt sind, ist es an der Zeit, die IAX clients einzurichten.

- `[name]`: Der Abschnittsname ist der IAX peer/user-Name; eine eingehende IAX-Verbindung wird anhand des Namens zugeordnet.
- `type`: Die Verbindungsklasse — `peer`, `user` oder `friend`:
  - `peer`: Asterisk sendet Anrufe an einen peer.
  - `user`: Asterisk empfängt Anrufe von einem user.
  - `friend`: beide Richtungen gleichzeitig.
- `host`: IP-Adresse oder Hostname. Der gebräuchlichste Wert ist `dynamic`, der verwendet wird, wenn sich das Gerät bei Asterisk registriert.
- `secret`: Passwort zur Authentifizierung von peers und users.

Warnung: Verwenden Sie starke Passwörter mit mindestens 8 Zeichen, alphanumerischen und numerischen Zeichen sowie mindestens einem Symbol. Berichte über gehackte Server sind in den Mailinglisten aufgetaucht, und Brute-Force-Passwort-Cracker für IAX md5-Hashes sind für Script-Kiddies verfügbar. Gebührenbetrug kostet Verbraucher und Anbieter Tausende von Dollar. Beispiel:

```
[guest]
type=user
context=dummy
callerid="Guest IAX User"
[6003]
type=friend
context=from-internal
secret=#sup3rs3cr3t#
host=dynamic
[6004]
type=friend
context=from-internal
secret=#s3cr3ts3cr3t#
host=dynamic
```

## Konfiguration der SIP-Geräte

Nachdem die Telefone in der Asterisk-Konfigurationsdatei definiert wurden, ist es an der Zeit, das Telefon selbst zu konfigurieren. In diesem Beispiel zeigen wir, wie man ein kostenloses softphone konfiguriert — das SipPulse Softphone (herunterzuladen unter https://www.sippulse.com/produtos/softphone). Überprüfen Sie das Handbuch Ihres Geräts, um die Parameter Ihres Telefons zu verstehen. Schritt 1: Konfigurieren Sie das Telefon für die Verwendung der extension 6000. Führen Sie das Installationsprogramm aus. Öffnen Sie nach der Ausführung die Konto-/SIP-Einstellungen und fügen Sie ein neues SIP-Konto hinzu. Geben Sie die erforderlichen Informationen ein.

![Der Kontobildschirm des SipPulse Softphone — geben Sie den Server (Ihre Asterisk IP oder Domain), den Benutzernamen, das Passwort und den Anzeigenamen ein und wählen Sie dann den Transport (UDP, TCP oder TLS).](../images/softphone/sipphone-account.png){width=35%}

Anzeigename: 6000  Benutzername: 6000  Passwort: #MySecret1#7  Autorisierungs-Benutzername: 6000  Domain: ip_of_your_server. Bestätigen Sie, dass Ihr Telefon registriert ist, indem Sie den Konsolenbefehl `pjsip show endpoints` (oder `pjsip show endpoint 6000` für Details; `pjsip show contacts` zeigt die registrierten AOR-Kontakte) verwenden. Wiederholen Sie die Konfiguration für das Telefon 6001.

![Ein registriertes SipPulse Softphone — der grüne Punkt und die Kontozeile (`1001@softphone.sippulse.com.br`) bestätigen die Registrierung; tätigen Sie einen Anruf über das Tastenfeld oder die Anruf-/Video-Schaltflächen.](../images/softphone/sipphone-registered.png){width=35%}

## Konfigurieren der IAX-Geräte

IAX2 ist ein veraltetes Protokoll (siehe das Kapitel *Legacy channels*), und das SipPulse Softphone unterstützt nur SIP, daher kann es kein IAX-Konto registrieren. Wenn Sie IAX2 testen müssen, verwenden Sie ein Softphone, das dies noch unterstützt. Erstellen Sie ein neues IAX-Konto,

3. Wählen Sie ein neues IAX-Konto aus.
4. Geben Sie die zugehörigen Optionen für das 6003-Telefon und optional für das 6004 ein.
5. Speichern Sie die Konfiguration und überprüfen Sie mit `iax2 show peers`, ob das Telefon registriert ist.

Wichtig: Verwenden Sie ein Konto für SIP und ein anderes für IAX. Wenn Sie das System so konfigurieren möchten, dass es sowohl IAX als auch SIP gleichzeitig klingeln lässt, zeigen wir Ihnen im Abschnitt zum dialplan, wie das geht.

### Konfigurieren einer PSTN-Schnittstelle

Um eine Verbindung zum PSTN herzustellen, benötigen Sie eine Foreign Exchange Office (FXO)-Schnittstelle und eine Telefonleitung. Sie können auch eine bestehende PBX-extension verwenden. Sie können eine Telefonieschnittstellenkarte mit einer FXO-Schnittstelle von verschiedenen Herstellern beziehen. In diesem Beispiel zeigen wir Ihnen, wie Sie eine DAHDI-Schnittstellenkarte installieren.

![FXS- und FXO-Ports: Der FXS-Port steuert ein analoges Telefon (liefert Wählton und Klingelsignal), während der FXO-Port Asterisk mit der Telco-Leitung verbindet.](FXS_FXO.png)(../images/04-first-pbx-fig02.png)

### Analoge Leitungen mit DAHDI

Sie können eine zu DAHDI kompatible Analogkarte von verschiedenen Herstellern kaufen. Die X100P war eine der ersten Digium-Karten und wird bereits nicht mehr hergestellt. Einige Hersteller produzieren immer noch ähnliche Klone. Neben dem Preis der X100P haben wir einige Probleme zwischen diesen Karten und neuen Hauptplatinen festgestellt, verwenden Sie sie daher mit Vorsicht. Die X100P ist meiner Meinung nach keine gute Wahl für eine Produktionsumgebung. Jede zu DAHDI kompatible Karte sollte funktionieren. Dank des Teams der DAHDI-Entwickler haben wir jetzt ein Werkzeug, um die Schnittstellenkarten fast automatisch zu erkennen und zu konfigurieren. Wenn Sie die DAHDI-Treiber gerade erst installiert haben, vergessen Sie bitte nicht, make config auszuführen und die Maschine neu zu starten, um sie automatisch zu laden. Sie können die unten stehenden Befehle verwenden, um Ihre Karte zu erkennen und zu konfigurieren. Schritt 1: Um Ihre Hardware zu erkennen, verwenden Sie:

```
dahdi_hardware
```

Schritt 2: Zur Konfiguration verwenden Sie:

```
dahdi_genconf
```

Der obige Befehl generiert zwei Dateien: /etc/dahdi/system.conf und /etc/asterisk/dahdi-channels.conf. Die Standardparameter für dahdi_genconf sind normalerweise in Ordnung, aber Sie können sie in der Datei /etc/dahdi/genconf_parameters ändern. Standardmäßig fügt es die Leitungen (FXO) in den context from-pstn und die Telefone (FXS) in den context from-internal ein. Schritt 3: Fügen Sie nach dem Ausführen von dahdi_genconf in der letzten Zeile der Datei /etc/asterisk/chan_dahdi.conf die folgende Zeile ein:

```
#include dahdi-channels.conf
```

Schritt 4: Bearbeiten Sie die Datei /etc/dahdi/modules und kommentieren Sie alle nicht verwendeten Treiber aus. Starten Sie neu, bevor Sie fortfahren, und überprüfen Sie mit folgendem Befehl, ob die Kanäle erkannt werden:

```
*CLI> dahdi show channels
```

### Verbindung zum PSTN über einen VoIP-Anbieter

Wenn Ihr Budget sehr begrenzt ist, können Sie einen SIP-trunk konfigurieren, um eine Verbindung zum PSTN herzustellen. Dies ist sicherlich der günstigste Weg, um eine Verbindung zum PSTN herzustellen. Weltweit gibt es Tausende von VoIP-Anbietern. Um eine Verbindung zu einem von ihnen herzustellen, benötigen Sie einige Parameter. Parameter, die vom SIP-Anbieter bereitgestellt werden.

- username: login
- password: secret
- Provider’s domain: domain
- UDP port: 5060
- Allowed codecs: g729, ilbc, alaw

Zwei Parameter sollten von Ihnen bestimmt werden.

- extension für den Empfang von Anrufen – in diesem Fall: 9999
- context: from-sip

In PJSIP wird ein registrierender SIP-trunk aus derselben Objektfamilie aufgebaut, die auch für einen endpoint verwendet wird, zuzüglich expliziter `registration` und `identify` Objekte. Das `registration` Objekt weist Asterisk an, sich beim Anbieter zu registrieren, das `identify` Objekt gleicht eingehenden Datenverkehr von der IP des Anbieters mit dem endpoint ab (PJSIP authentifiziert eingehende INVITEs anhand der Quell-IP), und `outbound_auth` liefert die Anmeldeinformationen für ausgehende Anrufe und die Registrierung:

```
[siptrunk]
type=endpoint
context=from-sip
disallow=all
allow=ilbc
allow=alaw
allow=g729
dtmf_mode=rfc4733
outbound_auth=siptrunk-auth
aors=siptrunk
from_user=login
from_domain=domain

[siptrunk-auth]
type=auth
auth_type=digest
username=login
password=secret

[siptrunk]
type=aor
contact=sip:domain:5060

[siptrunk]
type=identify
endpoint=siptrunk
match=domain

[siptrunk-reg]
type=registration
transport=transport-udp
outbound_auth=siptrunk-auth
server_uri=sip:domain:5060
client_uri=sip:login@domain:5060
contact_user=9999
retry_interval=60
```

Um auf diesen trunk zuzugreifen, verwenden wir den Kanalnamen `PJSIP/siptrunk`. Die Einstellung `dtmf_mode=rfc4733` überträgt DTMF out-of-band (RFC 4733 ersetzt das ältere RFC 2833; die Nutzlast ist identisch). Die Option `identify`/`match` akzeptiert IP-Adressen, CIDRs oder Hostnamen, aber Hostnamen werden nur einmal zum Zeitpunkt des Konfigurationsladens aufgelöst. Geben Sie daher bei einem Anbieter mit wechselnden IPs die Signalisierungs-IP(s) explizit an. Bestätigen Sie die Registrierung mit `pjsip show registrations`.

## Einführung in den Dial plan

Der Dial plan ist wie das Herz von Asterisk. Er definiert, wie Asterisk jeden einzelnen Anruf an die PBX verarbeitet. Er besteht aus extensions, die eine Anweisungsliste für Asterisk erstellen, der dieser folgen soll. Die Anweisungen werden durch Ziffern ausgelöst, die vom Kanal oder der Anwendung empfangen werden. Um Asterisk erfolgreich zu konfigurieren, ist es entscheidend, den Dial plan zu verstehen. Der Großteil des Dial plan ist in der Datei extensions.conf im Verzeichnis /etc/asterisk enthalten. Diese Datei verwendet die einfache Gruppengrammatik und basiert auf vier Hauptkonzepten:

- Extensions
- Priorities
- Applications
- Contexts

Lassen Sie uns einen grundlegenden Dial plan erstellen. In späteren Abschnitten dieses Buches werde ich dem Dial plan ein eigenes Kapitel widmen. Wenn Sie die Beispieldateien installiert haben (make samples), existiert die extensions.conf bereits. Speichern Sie sie unter einem anderen Namen und beginnen Sie mit einer leeren Datei.

## Die Struktur der Datei extensions.conf

Die Datei extensions.conf ist in Abschnitte unterteilt. Der erste ist der Abschnitt [general], gefolgt vom Abschnitt [globals]. Der Beginn jedes Abschnitts startet mit seiner Namensdefinition (z. B. [default]) und endet, wenn ein neuer Abschnitt erstellt wird.

### Der Abschnitt [general]

Der Abschnitt general befindet sich am Anfang der Datei. Bevor Sie mit der Konfiguration des dialplan beginnen, ist es hilfreich, die allgemeinen Optionen zu kennen, die bestimmte Verhaltensweisen des dialplan steuern. Diese Optionen sind:

- static und write protect: Wenn `static=yes` und `writeprotect=no` gesetzt sind, können Sie den laufenden dialplan mit dem CLI-Befehl auf die Festplatte speichern:

```
*CLI> dialplan save
```

Warnung: Wenn Sie einen `dialplan save` Befehl über die CLI ausführen, gehen alle Anmerkungen und Kommentare in der Datei verloren.

- autofallthrough: Wenn autofallthrough gesetzt ist und eine extension keine weiteren Aufgaben mehr hat, wird der Anruf mit BUSY, CONGESTION oder HANGUP beendet, je nachdem, was Asterisk als am wahrscheinlichsten erachtet. Dies ist die Standardeinstellung. Wenn autofallthrough nicht gesetzt ist, wartet Asterisk, falls eine extension keine weiteren Aufgaben mehr hat, darauf, dass eine neue extension gewählt wird.
- clearglobalvars: Wenn clearglobalvars gesetzt ist, werden globale Variablen bei einem dialplan reload oder Asterisk reload gelöscht und neu eingelesen. Wenn clearglobalvars nicht gesetzt ist, bleiben globale Variablen über Neuladevorgänge hinweg bestehen – selbst wenn sie aus der extensions.conf oder einer der eingebundenen Dateien gelöscht werden, behalten sie ihren vorherigen Wert bei.
- extenpatternmatchnew: Verwendet einen schnelleren Algorithmus für den Musterabgleich, was bei einer großen Anzahl von extensions spürbar hilft. Der Standardwert ist no.
- userscontext: Dies ist der context, in dem die Einträge aus der users.conf registriert werden.

### Der Abschnitt [globals]

Im Abschnitt [globals] definieren Sie globale Variablen und deren Anfangswerte. Sie können im dialplan mit ${GLOBAL(variable)} auf die Variable zugreifen. Sie können sogar auf Variablen zugreifen, die in der linux/unix-Umgebung definiert sind, indem Sie ${ENV(variable)} verwenden. Bei globalen Variablen wird nicht zwischen Groß- und Kleinschreibung unterschieden. Ein paar Beispiele könnten sein:

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

Im folgenden Beispiel können Sie eine globale Variable im dialplan setzen und testen.

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Context ist die benannte Partition des dialplan. Nach den Abschnitten [general] und [globals] besteht der dialplan aus einer Reihe von contexts, in denen jeder context mehrere extensions besitzt, jede extension mehrere priorities hat und jede priority eine application mit mehreren Argumenten aufruft.

![Asterisk-Anruffluss: Jeder Anruf kommt auf einem Kanal (IAX, SIP und andere) als eingehender Anrufzweig an; der context des Kanals — der global oder pro Kanal in der Konfigurationsdatei des Kanals festgelegt wird — entscheidet, welcher context in extensions.conf den Anruf verarbeitet, bevor er über den ausgehenden Zweig weitergeleitet wird.](../images/04-first-pbx-fig03.png)

![Anrufverarbeitung: Der für einen Kanal definierte `context=` (in chan_dahdi.conf oder pjsip.conf) benennt den passenden context in extensions.conf, in dem der dialplan den Anruf verarbeitet.](../images/04-first-pbx-fig04.png)

Sie können einen einfachen dialplan erstellen, um andere Telefone und das PSTN zu erreichen. Asterisk ist jedoch weitaus leistungsfähiger als das. Unser Ziel ist es, Ihnen weitere Details darüber zu vermitteln, was im dialplan möglich ist.

## Extensions

Im Gegensatz zu einer herkömmlichen PBX, bei der Extensions mit Telefonen, Schnittstellen, Menüs usw. verknüpft sind, ist eine Extension in Asterisk eine Liste von Befehlen, die verarbeitet werden, wenn eine bestimmte Extensions-Nummer oder ein Name ausgelöst wird. Die Befehle werden in der Reihenfolge ihrer Priorität verarbeitet.

![Extension-Syntax: `exten => number(name),{priority|label}[(alias)],application`. Extensions können numerisch, alphanumerisch, numerisch mit Caller ID, ein Muster oder eine Standard-Extension wie `s` sein; Prioritäten können eine Zahl, `n` (nächste), `s` (dieselbe), ein Offset oder ein `hint` sein.](../images/04-first-pbx-fig05.png)

Eine Extension kann literal, standard oder speziell sein. Eine Standard-Extension enthält nur Zahlen oder Namen sowie die Zeichen * und #; 12#89* ist eine gültige literale Extension. Namen können ebenfalls für den Abgleich von Extensions verwendet werden. Bei Extensions wird zwischen Groß- und Kleinschreibung unterschieden. Sie können jedoch nicht zwei Extensions mit demselben Namen, aber unterschiedlicher Groß-/Kleinschreibung erstellen. Wenn eine Extension gewählt wird, wird der Befehl mit der ersten Priorität ausgeführt, gefolgt vom Befehl mit Priorität 2 und so weiter. Dies geschieht, bis der Anruf getrennt wird oder ein Befehl die Zahl eins zurückgibt, was auf einen Fehler hinweist. Was Asterisk tut, wenn die letzte Priorität ausgeführt wurde, wird durch den Parameter autofallthrough geregelt. Siehe den Abschnitt [general] in diesem Kapitel. Beispiel:

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

Oben finden Sie die Liste der Anweisungen, die verarbeitet werden, wenn die Extension 123 gewählt wird. Die erste Priorität besteht darin, den Kanal anzunehmen (notwendig, wenn sich der Kanal im Ruhezustand befindet: z. B. FXO-Kanäle). Die zweite Priorität besteht darin, eine Audiodatei namens tt-weasels abzuspielen. Die dritte Priorität legt den Kanal auf. Eine weitere Option besteht darin, den Anruf gemäß der Caller ID zu behandeln. Sie können das Zeichen / verwenden, um die zu verarbeitende Caller ID anzugeben. Beispiele:

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

Dieses Beispiel löst die Extension 123 aus und führt die folgenden Optionen nur aus, wenn die Caller ID 100 ist. Dies kann auch durch die Verwendung des unten beschriebenen Musters erreicht werden:

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint: ordnet eine Extension einem Kanal zu. Es wird verwendet, um den Kanalstatus zu überwachen. Es wird in Verbindung mit Presence verwendet. Das Telefon muss dies unterstützen.

#### Muster

Sie können Muster und Literale im dialplan verwenden. Muster sind sehr nützlich, um die Größe des dialplan zu reduzieren. Alle Muster beginnen mit dem Zeichen „_“. Die folgenden Zeichen können verwendet werden, um ein Muster zu definieren. Die Abbildung zeigt die Muster, die für die Verwendung mit Asterisk verfügbar sind.

![Musterabgleich-Zeichen: `_` startet ein Muster, `.` entspricht einem oder mehreren Zeichen, `!` entspricht null oder mehr, `[123-7]` entspricht einer beliebigen aufgeführten Ziffer oder einem Bereich, `X` ist 0-9, `Z` ist 1-9 und `N` ist 2-9 — mit Beispielen für die Zuordnung von Büro-Extension-Bereichen.](../images/04-first-pbx-fig06.png)

### Spezielle Extensions

Asterisk verwendet einige Extension-Namen als Standard-Extensions.

![Spezielle Asterisk-Extensions: `i` (ungültig), `s` (Start), `h` (Auflegen), `t` (Zeitüberschreitung), `T` (absolute Zeitüberschreitung), `o` (Operator), `a` (gedrückt `*` in voicemail), `fax` (Faxerkennung) und `Talk` (verwendet mit BackgroundDetect).](../images/04-first-pbx-fig07.png)

Beschreibung:

- **s**: Start. Es wird verwendet, um einen Anruf zu bearbeiten, wenn keine Nummer gewählt wurde. Es ist nützlich für FXO-trunks und Menü-Verarbeitung.
- **t**: Timeout. Es wird verwendet, wenn Anrufe inaktiv bleiben, nachdem eine Aufforderung abgespielt wurde. Es wird auch verwendet, um eine inaktive Leitung aufzulegen.
- **T**: AbsoluteTimeout. Wenn Sie ein Anruflimit mithilfe der dialplan-Funktion `TIMEOUT(absolute)` festlegen, wird der Anruf nach Überschreiten des definierten Limits an die T-Extension gesendet.
- **h**: Hangup. Es wird aufgerufen, nachdem der Benutzer den Anruf getrennt hat.
- **i**: Invalid. Es wird ausgelöst, wenn Sie eine nicht existierende Extension im context anrufen. Die Verwendung dieser Extensions kann den Inhalt von CDR-Datensätzen beeinflussen – insbesondere das Feld dst, das nicht die gewählte Nummer enthält.
- **o**: Operator. Es wird verwendet, um zum Operator zu gelangen, wenn der Benutzer während der voicemail „0“ drückt.

Die Verwendung dieser Extensions kann den Inhalt der Abrechnungsdatensätze (CDR) verändern – insbesondere enthält das Feld dst nicht die gewählte Nummer. Um dieses Problem zu umgehen, sollten Sie die Option g in der dial()-Anwendung verwenden und die Funktionen resetcdr(w) und/oder nocdr() in Betracht ziehen.

## Variablen

In der Asterisk PBX können Variablen global, kanalspezifisch oder umgebungsspezifisch sein. Sie können die Anwendung NoOP() verwenden, um den Inhalt einer Variablen in der Konsole zu sehen. Sie kann eine globale Variable oder eine kanalspezifische Variable als Argumente für Anwendungen verwenden. Auf eine Variable kann wie im folgenden Beispiel verwiesen werden, wobei varname der Name der Variablen ist.

```
${varname}
```

Ein Variablenname kann eine alphanumerische Zeichenfolge sein, die mit einem Buchstaben beginnt. Globale Variablennamen unterscheiden nicht zwischen Groß- und Kleinschreibung. Systemvariablen (von Asterisk definierte oder kanaldefinierte) unterscheiden jedoch zwischen Groß- und Kleinschreibung. Daher ist die Variable ${EXTEN} etwas anderes als ${exten}.

### Globale Variablen

Globale Variablen können im Abschnitt [global] in der Datei extensions.conf oder unter Verwendung der Anwendung konfiguriert werden:

```
set(Global(variable)=content)
```

### Kanalspezifische Variablen

Kanalspezifische Variablen werden unter Verwendung der Anwendung set() konfiguriert. Jeder Kanal erhält seinen eigenen Variablenbereich. Es besteht keine Gefahr von Kollisionen zwischen Variablen verschiedener Kanäle. Eine kanalspezifische Variable wird gelöscht, wenn der Kanal aufgelegt wird. Einige der am häufigsten verwendeten Variablen sind:

- ${EXTEN} Gewählte extension
- ${CONTEXT} Aktueller context
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} Aktuelle Caller ID
- ${PRIORITY} Aktuelle Priorität

Andere kanalspezifische Variablen werden komplett in Großbuchstaben geschrieben. Sie können den Inhalt mehrerer Variablen mit der Anwendung dumpchan() einsehen. Unten ist ein einfacher Auszug von dump-channel Variablen.

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Dumpchan Ausgabe:

```
Dumping Info For Channel: PJSIP/4400-00000001:
================================================================================
Info:
Name=               PJSIP/4400-00000001
Type=               PJSIP
UniqueID=           1161186526.1
LinkedID=           1161186526.0
CallerIDNum=        4400
CallerIDName=       laptop
ConnectedLineIDNum= (N/A)
ConnectedLineIDName=(N/A)
DNIDDigits=         9001
RDNIS=              (N/A)
Parkinglot=
Language=           en
State=              Ring (4)
Rings=              0
NativeFormat=       (ulaw)
WriteFormat=        ulaw
ReadFormat=         ulaw
RawWriteFormat=     ulaw
RawReadFormat=      ulaw
WriteTranscode=     No
ReadTranscode=      No
1stFileDescriptor=  16
Framesin=           0
Framesout=          0
TimetoHangup=       0
ElapsedTime=        0h0m0s
BridgeID=           (Not bridged)
Context=            default
Extension=          9001
Priority=           1
CallGroup=
PickupGroup=
Application=        DumpChan
Data=               (Empty)
Blocking_in=        (Not Blocking)
Variables:
```

Das oben dargestellte Feldlayout ist die Ausgabe von Asterisk 22 `DumpChan` (ein echter `PJSIP/...` Kanalname, die Felder `CallerIDNum`/`ConnectedLineID` und die Zeilen `Raw*`/`Transcode`/`BridgeID`, die PJSIP Kanäle belegen). Im Gegensatz zum alten Treiber setzt ein PJSIP Kanal nicht automatisch `SIPCALLID`/`SIPUSERAGENT` Kanalvariablen; die entsprechenden SIP Details werden bei Bedarf mit den dialplan Funktionen `PJSIP_HEADER()` und `CHANNEL()` gelesen — zum Beispiel `${CHANNEL(pjsip,call-id)}`, `${PJSIP_HEADER(read,User-Agent)}` und `${CHANNEL(rtp,dest)}` für die entfernte RTP Adresse.

### Umgebungsspezifische Variablen

Umgebungsspezifische Variablen können verwendet werden, um auf Variablen zuzugreifen, die im Betriebssystem definiert sind. Sie können umgebungsspezifische Variablen mit der Funktion ENV() setzen. Zum Beispiel:

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### Anwendungsspezifische Variablen

Einige Anwendungen verwenden Variablen für die Dateneingabe und -ausgabe. Sie können Variablen setzen, bevor Sie die Anwendung aufrufen, oder die Variable nach der Ausführung der Anwendung abrufen. Zum Beispiel: Die Dial Anwendung gibt die folgenden Variablen zurück:

- ${DIALEDTIME} -> Dies ist die Zeit vom Wählen eines Kanals bis zu dessen Trennung.
- ${ANSWEREDTIME} -> Dies ist die Zeitdauer für das eigentliche Gespräch.
- ${DIALSTATUS} Dies ist der Status des Anrufs: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> Fehlermeldung für den Anruf.

## Ausdrücke

Ausdrücke können im dialplan sehr nützlich sein. Sie werden verwendet, um Zeichenfolgen zu bearbeiten sowie mathematische und logische Operationen durchzuführen.

![Übersicht über Asterisk-Ausdrücke — `$[expression1 operator expression2]` — Gruppierung der mathematischen, logischen, Vergleichs-, regulären Ausdrucks- und bedingten Operatoren, die im dialplan verfügbar sind.](../images/04-first-pbx-fig08.png)

Die Syntax für Ausdrücke ist wie folgt definiert:

```
$[expression1 operator expression2]
```

Nehmen wir an, wir haben eine Variable namens „I“ und möchten 100 zu dieser Variable addieren:

```
$[${I}+100]
```

Wenn Asterisk einen Ausdruck im dialplan findet, ersetzt es den gesamten Ausdruck durch den resultierenden Wert.

### Operatoren

Die folgenden Operatoren können verwendet werden, um Ausdrücke zu bilden. Es ist wichtig, die Operatorrangfolge zu beachten.

1. Klammern „()“
2. Unäre Operatoren „! -“
3. Regulärer Ausdruck „: =~“
4. Multiplikative Operatoren „* / %“
5. Additive Operatoren „+ -“
6. Vergleichsoperatoren
7. Logische Operatoren
8. Bedingte Operatoren

#### Mathematische Operatoren

- Addition (+)
- Subtraktion (-)
- Multiplikation (*)
- Division (/)
- Modulo (%)

#### Logische Operatoren

- Logisches „UND“ (&)
- Logisches „ODER“ (|)
- Logische unäre Komplementbildung (!)

#### Operatoren für reguläre Ausdrücke

- Übereinstimmung mit regulärem Ausdruck (:)
- Exakte Übereinstimmung mit regulärem Ausdruck (=~)

Ein regulärer Ausdruck ist eine spezielle Textzeichenfolge, die verwendet wird, um ein Suchmuster zu beschreiben. Sie können sich reguläre Ausdrücke wie Platzhalter vorstellen. Reguläre Ausdrücke werden verwendet, um eine Zeichenfolge mit einem Muster abzugleichen und die Übereinstimmung zu prüfen. Wenn die Übereinstimmung erfolgreich ist und der reguläre Ausdruck mindestens eine Übereinstimmung enthält, wird die erste Übereinstimmung zurückgegeben; andernfalls ist das Ergebnis die Anzahl der übereinstimmenden Zeichen.

#### Vergleichsoperatoren

Das Ergebnis eines Vergleichs ist 1, wenn die Beziehung wahr ist, oder 0, wenn sie falsch ist.

- = gleich
- != ungleich
- < kleiner als
- > größer als
- <= kleiner oder gleich
- >= größer oder gleich

### LAB. Werten Sie die folgenden Ausdrücke aus:

Fügen Sie diese Ausdrücke in Ihren dialplan ein und verwenden Sie die Anwendung NoOP(), um die Ausdrücke auszuwerten. Wählen Sie 9002 und untersuchen Sie die Ergebnisse in der Asterisk-Konsole. Verwenden Sie verbose 15, um die Ergebnisse anzuzeigen.

```
exten=9002,1,set(NAME="FLAVIO")                 ;Set NAME=FLAVIO
exten=9002,n,set(I=4)
exten=9002,n,set(URI="40001@voip.school")
exten=9002,n,NoOP(${NAME})
exten=9002,n,NoOP(${I})
exten=9002,n,NoOP($[${I}+${I}])
exten=9002,n,NoOP($[${I}=4])
exten=9002,n,NoOP($[${I}=4 & ${NAME}=FLAVIO])
exten=9002,n,NoOP($[${URI} =~ "4[0-9][0-9][0-9][0-9]@."])
exten=9002,n,NoOP($[${I}=4?"MATCH"::"DO NOT MATCH"])
exten=9002,n,hangup
```

## Funktionen

Einige Anwendungen wurden durch Funktionen ersetzt, die eine fortgeschrittenere Verarbeitung von Variablen ermöglichen, als dies mit Ausdrücken allein möglich wäre. Sie können die vollständige Liste der Funktionen einsehen, indem Sie den folgenden Konsolenbefehl ausführen:

```
*CLI> core show functions
```

String-Länge: ${LEN(string)} gibt die Länge des Strings zurück

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

Beim ersten Vorgang zeigt das System 5 als Ergebnis an (die Anzahl der Buchstaben im Wort „fruit“). Der zweite Vorgang gibt die Zahl 4 zurück (die Anzahl der Buchstaben im Wort „pear“). Teil-Strings: Gibt den Teil-String zurück, beginnend an der durch den Parameter „offset“ definierten Position, mit der im Parameter „length“ definierten Länge. Wenn der Offset negativ ist, beginnt die Zählung von rechts nach links, ausgehend vom Ende des Strings. Wenn die Länge weggelassen wird oder negativ ist, wird der gesamte String ab dem Offset übernommen.

```
${string:offset:length }
```

Beispiel #1: Mehrere Teil-Strings

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

Beispiel #2: Die Vorwahl aus den ersten drei Ziffern entnehmen.

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

Beispiel #3: Nimmt alle Ziffern aus der Variable ${EXTEN}, mit Ausnahme der Vorwahl.

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### String-Verkettung

Um zwei Strings zu verketten, schreiben Sie diese einfach hintereinander.

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Anwendungen

Um einen dialplan zu erstellen, müssen wir das Konzept der Anwendungen verstehen. Sie verwenden Anwendungen, um den channel im dialplan zu verarbeiten. Anwendungen sind in verschiedenen Modulen implementiert. Die verfügbaren Anwendungen hängen von den Modulen ab. Sie können alle Asterisk Anwendungen mit dem Konsolenbefehl anzeigen:

```
*CLI> core show applications
```

Alternativ können Sie Details zu einer bestimmten Anwendung mithilfe des folgenden Beispiels anzeigen:

```
*CLI> core show application Dial
```

Um einen einfachen dialplan zu erstellen, müssen Sie einige Anwendungen kennen. Wir werden später im Buch fortgeschrittenere Beispiele besprechen.

![Die Handvoll Anwendungen, die zum Erstellen eines einfachen dialplan benötigt werden: Answer (einen Kanal annehmen), Dial (einen anderen Kanal anrufen), Hangup (einen Kanal auflegen), Playback (eine Audiodatei abspielen) und Goto (zu einer Priorität, extension oder context springen).](../images/04-first-pbx-fig09.png)

Wir werden diese Anwendungen (oben) verwenden, um einen einfachen dialplan für zwei grundlegende PBXs zu erstellen.

### Answer()

[Synopsis] Nimmt einen klingelnden Kanal an [Description] Answer([delay]): Wenn der Anruf noch nicht angenommen wurde, wird die Anwendung ihn annehmen. Andernfalls hat sie keine Auswirkung auf den Anruf. Wenn eine Verzögerung angegeben ist, wartet Asterisk die in ‚delay‘ angegebene Anzahl an Millisekunden, bevor der Anruf angenommen wird.

### Dial()

Die folgende Beschreibung kann durch die Eingabe von show application dial im dialplan abgerufen werden. Zur einfacheren Suche ist sie unten wiedergegeben. Die Syntax für die Anwendung Dial wird ebenfalls unten gezeigt:

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

Diese Anwendung baut Anrufe zu einem oder mehreren angegebenen Kanälen auf. Sobald einer der angeforderten Kanäle antwortet, wird der ursprüngliche Kanal beantwortet – sofern dies nicht bereits geschehen ist. Diese beiden Kanäle werden dann in einem gebrückten Anruf aktiv sein. Alle anderen angeforderten Kanäle werden daraufhin aufgelegt. Sofern kein Timeout angegeben ist, wartet die Dial Anwendung unbegrenzt, bis einer der angerufenen Kanäle antwortet, der Benutzer auflegt oder alle angerufenen Kanäle besetzt oder nicht verfügbar sind. Die Ausführung des dialplan wird fortgesetzt, wenn keine der angeforderten Kanäle angerufen werden können oder wenn das Timeout abläuft. Diese Anwendung setzt nach Abschluss die folgenden Kanalvariablen:

- DIALEDTIME - Dies ist die Zeit vom Wählen eines Kanals bis zu dem Zeitpunkt, an dem die Verbindung getrennt wird.
- ANSWEREDTIME - Dies ist die Dauer des eigentlichen Gesprächs.
- DIALSTATUS - Dies ist der Status des Anrufs: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

Für die Privacy- und Screening-Modi wird die Variable DIALSTATUS auf DONTCALL gesetzt, wenn der Angerufene sich entscheidet, den Anrufer an das 'Go Away'-Skript zu senden. Die Variable DIALSTATUS wird auf TORTURE gesetzt, wenn der Angerufene den Anrufer an das 'torture'-Skript senden möchte. Diese Anwendung meldet eine normale Beendigung, wenn der ursprüngliche Kanal auflegt oder wenn der Anruf gebrückt ist und eine der Parteien in der Brücke das Gespräch beendet. Die optionale URL wird an den Angerufenen gesendet, falls der Kanal dies unterstützt. Wenn die Variable OUTBOUND_GROUP gesetzt ist, werden alle durch diese Anwendung erstellten Peer-Kanäle in diese Gruppe aufgenommen (wie in

```
Set(GROUP()=...).
```

Die folgende Tabelle fasst einige der am häufigsten verwendeten Optionen für die Anwendung Dial zusammen. Für die vollständige Liste verwenden Sie den Konsolenbefehl `core show application Dial`. In Asterisk 22 werden diese Optionen durch Kommas vom Channel und dem Timeout getrennt — zum Beispiel `Dial(PJSIP/2000,20,tTm)`.

| Option | Beschreibung |
|--------|-------------|
| `A(x)` | Spielt eine Ansage für den angerufenen Teilnehmer ab, wobei `x` als Datei verwendet wird. |
| `C` | Setzt die CDR für diesen Anruf zurück. |
| `d` | Ermöglicht es dem anrufenden Benutzer, eine einstellige extension zu wählen, während er auf die Annahme des Anrufs wartet. Springt zu dieser extension, falls sie im aktuellen context existiert, oder zu dem im `EXITCONTEXT` Variable definierten context, falls dieser existiert. |
| `D([called][:calling])` | Sendet die angegebenen DTMF-Zeichenfolgen, nachdem der angerufene Teilnehmer abgenommen hat, aber bevor der Anruf verbunden wird. Die `called` Zeichenfolge wird an den angerufenen Teilnehmer und die `calling` Zeichenfolge an den anrufenden Teilnehmer gesendet. Jeder Parameter kann einzeln verwendet werden. |
| `f` | Erzwingt, dass die Caller ID des anrufenden Kanals auf die extension gesetzt wird, die dem Kanal über einen dialplan `hint` zugeordnet ist. Nützlich, wenn das PSTN keine beliebige Caller ID zulässt. |
| `g` | Fährt mit der Ausführung des dialplan an der aktuellen extension fort, wenn der Zielkanal auflegt. |
| `G(context^exten^pri)` | Wenn der Anruf angenommen wird, wird der anrufende Teilnehmer an die angegebene Priorität und der angerufene Teilnehmer an Priorität+1 übertragen. Optional kann eine extension (oder extension und context) angegeben werden; andernfalls wird die aktuelle extension verwendet. |
| `h` | Ermöglicht es dem angerufenen Teilnehmer, durch Senden der `*` DTMF-Ziffer aufzulegen. |
| `H` | Ermöglicht es dem anrufenden Teilnehmer, durch Senden der `*` DTMF-Ziffer aufzulegen. |
| `L(x[:y][:z])` | Begrenzt den Anruf auf `x` ms, spielt eine Warnung ab, wenn noch `y` ms verbleiben, und wiederholt die Warnung alle `z` ms. Siehe die `LIMIT_*` Variablen unten. |
| `m([class])` | Stellt dem anrufenden Teilnehmer Wartemusik (Music on Hold) zur Verfügung, bis der angeforderte Kanal antwortet. Eine spezifische MusicOnHold-Klasse kann angegeben werden. |
| `r` | Signalisiert dem anrufenden Teilnehmer ein Freizeichen und überträgt kein Audio, bis der angerufene Kanal antwortet. |
| `S(x)` | Beendet den Anruf `x` Sekunden, nachdem der angerufene Teilnehmer abgenommen hat. |
| `t` | Ermöglicht es dem angerufenen Teilnehmer, den anrufenden Teilnehmer durch Senden der in `features.conf` definierten DTMF-Sequenz weiterzuleiten. |
| `T` | Ermöglicht es dem anrufenden Teilnehmer, den angerufenen Teilnehmer durch Senden der in `features.conf` definierten DTMF-Sequenz weiterzuleiten. |
| `w` | Ermöglicht es dem angerufenen Teilnehmer, die One-Touch-Aufzeichnung durch Senden der in `features.conf` definierten DTMF-Sequenz zu aktivieren. |
| `W` | Ermöglicht es dem anrufenden Teilnehmer, die One-Touch-Aufzeichnung durch Senden der in `features.conf` definierten DTMF-Sequenz zu aktivieren. |
| `k` | Ermöglicht es dem angerufenen Teilnehmer, den Anruf durch Senden der für das Parken von Anrufen in `features.conf` definierten DTMF-Sequenz zu parken. |
| `K` | Ermöglicht es dem anrufenden Teilnehmer, den Anruf durch Senden der für das Parken von Anrufen in `features.conf` definierten DTMF-Sequenz zu parken. |

Die Option `L(x[:y][:z])` kann mit den folgenden speziellen Variablen angepasst werden:

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no` (Standardwert `yes`): spielt Töne für den Anrufer ab.
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no`: spielt Töne für den Angerufenen ab.
- `LIMIT_TIMEOUT_FILE` — Datei, die abgespielt wird, wenn die Zeit abgelaufen ist.
- `LIMIT_CONNECT_FILE` — Datei, die abgespielt wird, wenn der Anruf beginnt.
- `LIMIT_WARNING_FILE` — Datei, die als Warnung abgespielt wird, wenn `y` definiert ist. Standardmäßig wird die verbleibende Zeit angesagt.

--- BEGIN MARKDOWN ---
Beispiel:
--- END MARKDOWN ---

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

Im obigen Beispiel wählt die Anwendung den entsprechenden PJSIP-Kanal an. Sowohl der Anrufer als auch der Angerufene könnten den Anruf weiterleiten (Tt). Anstelle des Freizeichens wird Wartemusik (Music on hold) zu hören sein. Wenn niemand innerhalb von 20 Sekunden antwortet, geht die extension zur nächsten Priorität über.

### Hangup()

Legt den anrufenden Kanal auf [Beschreibung] Hangup([causecode]): Diese Anwendung legt den anrufenden Kanal auf. Wenn ein Ursachencode (cause code) angegeben wird, wird die Auflegeursache des Kanals auf den angegebenen Wert gesetzt.

### Goto()

Springt zu einer bestimmten Priorität, extension oder context [Beschreibung] Goto([[context|]extension|]priority): Diese Anwendung veranlasst den anrufenden Kanal dazu, die Ausführung des dialplan an der angegebenen Priorität fortzusetzen. Wenn keine spezifische extension (oder extension und context) angegeben sind, springt diese Anwendung zur angegebenen Priorität der aktuellen extension. Wenn der Versuch, an eine andere Stelle im dialplan zu springen, nicht erfolgreich ist, fährt der Kanal mit der nächsten Priorität der aktuellen extension fort.

## Erstellen eines dialplan

Um einen einfachen dialplan zu erstellen, müssen Sie alle eingehenden und ausgehenden Anrufe behandeln, indem Sie contexts und extensions anlegen. In diesem Abschnitt zeigen wir Ihnen, wie Sie die gängigsten extensions erstellen.

### Wählen zwischen extensions

Um das Wählen zwischen extensions zu ermöglichen, könnten wir die channel-Variable ${EXTEN} verwenden, die sich auf die gewählte extension bezieht. Wenn der extension-Bereich beispielsweise zwischen 4000 und 4999 liegt und alle extensions SIP verwenden, könnten wir den folgenden Befehl übernehmen:

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### Wählen zu einem externen Ziel

Um ein externes Ziel zu wählen, könnten Sie der gewählten Nummer eine Route voranstellen. In Nordamerika ist es üblich, eine 9 gefolgt von der extern zu wählenden Nummer zu verwenden. Wenn Sie einen analogen oder digitalen Kanal zum PSTN verwenden, sollte der Befehl wie folgt aussehen: Wenn Sie den SIP trunk anstelle von DAHDI verwenden möchten, nutzen Sie den `PJSIP/...@siptrunk` channel.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

Die obige Zeile ermöglicht es Ihnen, die 9 und die gewünschte Nummer zu wählen. Im gegebenen Beispiel verwenden Sie den ersten DAHDI channel (DAHDI/1). Wenn Sie mehrere Leitungen haben und diese belegt ist, wird der Anruf nicht durchgestellt. Sie könnten jedoch die folgende Zeile verwenden, um automatisch den ersten verfügbaren DAHDI channel auszuwählen. Optional können Sie den SIP trunk anstelle von DAHDI verwenden. In der PJSIP-Form `Dial(PJSIP/number@siptrunk,...)` ist die gewählte Nummer der Benutzerteil und `siptrunk` ist der oben konfigurierte endpoint.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

Der Parameter „g1“ sucht nach dem ersten verfügbaren channel in der Gruppe, was die Nutzung aller channels ermöglicht. Mit der unten stehenden Zeile könnten Sie eine Ferngesprächsnummer wählen.

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### Wählen der 9 für eine PSTN-Leitung

Wenn Sie keine Einschränkungen für externe Anrufe haben, können Sie es vereinfachen und Folgendes verwenden:

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### Empfangen eines Anrufs in der operator-extension

Im folgenden Beispiel ist die operator-extension 4000. Die PSTN-Leitung ist mit einer FXO-Schnittstelle verbunden. In der Datei chan_dahdi.conf ist der angegebene context from-pstn. Jeder Anruf, der vom PSTN kommt, wird im dialplan an den context from-pstn weitergeleitet. Diese Leitung verfügt nicht über direct inward dialing (DID); daher müssen wir den Anruf über die „s“-extension empfangen. Wenn Sie vom SIP trunk empfangen, verwenden Sie den context [from-sip].

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
[from-sip]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
```

### Empfangen eines Anrufs mittels direct inward dialing (DID)

Wenn Sie eine digitale Leitung haben, empfangen Sie die gewählte extension. In diesem Fall müssen Sie den Anruf nicht an den operator weiterleiten, sondern können ihn direkt an das Ziel weiterleiten. Angenommen, Ihr DID-Bereich reicht von 3028550 bis 3028599 und die letzten vier Ziffern werden in der DID übermittelt. Die Konfiguration würde wie im folgenden Beispiel aussehen:

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### Gleichzeitiges Anrufen mehrerer extensions

Sie können Asterisk so einstellen, dass eine extension gewählt wird und, falls diese nicht abhebt, gleichzeitig mehrere andere extensions angerufen werden, wie im folgenden Beispiel gezeigt:

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

In diesem Beispiel wird, wenn jemand den operator anruft, zunächst der channel DAHDI/1 versucht. Wenn nach 15 Sekunden (timeout) niemand abhebt, klingeln die channels DAHDI/1, DAHDI/2 und DAHDI/3 gleichzeitig für weitere 15 Sekunden.

### Routing nach Caller ID

In diesem Beispiel könnten Sie je nach Caller ID unterschiedliche Behandlungen vornehmen, was für Anruf-Spammer nützlich sein kann. Zum Beispiel:

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

In diesem Beispiel haben wir eine spezielle Regel hinzugefügt, die, wenn die Caller ID 4832518888 ist, eine Nachricht aus der zuvor aufgenommenen Datei „I-have-moved-to-china“ abspielt. Andere Anrufe werden wie gewohnt angenommen.

### Verwendung von Variablen im dialplan

Asterisk kann globale und channel-Variablen im dialplan als Argumente für bestimmte Anwendungen verwenden. Betrachten Sie die folgenden Beispiele:

```
[globals]
Flavio => DAHDI/1
Daniel => DAHDI/2&PJSIP/pingtel
Anna => DAHDI/3
Christian => DAHDI/4
[mainmenu]
exten => 1,1,Dial(${Daniel}&${Flavio})
exten => 2,1,Dial(${Anna}&${Christian})
exten => 3,1,Dial(${Anna}&${Flavio})
```

Die Verwendung von Variablen erleichtert zukünftige Änderungen. Wenn Sie die Variable ändern, werden alle Referenzen sofort geändert.

### Aufnehmen einer Ansage

In einigen der später in diesem Abschnitt besprochenen Optionen werden wir aufgezeichnete Ansagen verwenden. Hier zeigen wir Ihnen einen einfachen Weg, diese aufzunehmen. Wir verwenden die Anwendung Record(), um die Ansage mit dem eigenen Telefon zu speichern.

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

Diese Anweisungen ermöglichen es Ihnen, jede Nachricht von einem softphone aufzunehmen. Beispiel: Wählen von recordmenu vom softphone. Die Anweisungen rufen die Aufnahme mit der Variable ${EXTEN:6} ohne die ersten sechs Buchstaben auf. Mit anderen Worten, die Anweisung entspricht record(menu:gsm). Alles, was Sie tun müssen, ist record + name_der_aufzunehmenden_datei zu wählen, # zu drücken, um die Aufnahme zu beenden, und darauf zu warten, die Aufnahme zu hören.

### Empfangen von Anrufen in einer digitalen Telefonzentrale

Nachdem wir nun einige einfache Beispiele haben, erweitern wir unser Wissen über die Anwendungen background() und goto(). Der Schlüssel für interaktive Systeme in Asterisk ist die Anwendung background(), die es Ihnen ermöglicht, eine Audiodatei auszuführen, die unterbrochen wird, wenn der Anrufer eine Taste drückt, um den Anruf an die gewählte extension zu senden. Syntax der Anwendung background():

```
exten=>extension, priority, background(filename)
```

Eine weitere sehr nützliche Anwendung ist goto(). Wie der Name schon sagt, springt sie zum angegebenen context, zur extension und zur Priorität. Syntax der Anwendung goto():

```
exten=>extension, priority,goto(context, extension, priority)
```

Gültige Formate für den Befehl goto():

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

Im folgenden Beispiel erstellen wir eine digitale Telefonzentrale. Es ist sehr einfach, die Datei extensions.conf zu bearbeiten und die folgenden extensions zu konfigurieren:

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
include=aapstn
[from-sip]
include=aasip
[aapstn]
exten=>s,1,answer()
exten=>s,n,set(TIMEOUT(response)=10)
exten=>s,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>s,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
[aasip]
exten=>9999,1,answer()
exten=>9999,n,set(TIMEOUT(response)=10)
exten=>9999,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>9999,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
```

Die SIP-extensions verwenden `PJSIP/` und die IAX-extensions verwenden `IAX2/` — beide Treiber sind in Asterisk 22 enthalten, obwohl `chan_iax2` mittlerweile als veraltet gilt und SIP/PJSIP bevorzugt wird.

Nehmen Sie in der Datei menu1.gsm die Nachricht „drücken Sie die extension oder warten Sie auf den operator“ auf. Wenn der Benutzer die Nummer 6000 wählt, wird er an die extension 6000 weitergeleitet. An diesem Punkt sollten Sie ein klares Verständnis für die Verwendung verschiedener Anwendungen haben, einschließlich answer(), background(), goto(), hangup() und playback(). Wenn Sie kein klares Verständnis haben, lesen Sie dieses Kapitel bitte erneut, bis Sie sich mit dem Inhalt wohl fühlen. Sie werden die background-Anwendung sehr oft verwenden. Sobald Sie die Grundlagen von extensions, Prioritäten und Anwendungen verstehen, wird es einfach sein, einen einfachen dialplan zu erstellen. Diese Konzepte werden später im Buch eingehender untersucht, und Sie werden sehen, dass der dialplan immer leistungsfähiger wird.

## Zusammenfassung

In diesem Kapitel haben Sie gelernt, dass Konfigurationsdateien im Verzeichnis /etc/asterisk gespeichert werden. Um Asterisk zu verwenden, ist es zunächst erforderlich, die Kanäle (z. B. PJSIP, DAHDI, IAX) zu konfigurieren. Für Konfigurationsdateien existieren drei verschiedene Grammatiken: einfache Gruppierung (simple group), Objektvererbung (object inheritance) und komplexe Entitäten (complex entity). Der dialplan wird in der Datei extensions.conf erstellt und besteht aus einer Reihe von contexts und extensions. Im dialplan löst jede extension eine application aus. Sie haben gelernt, die applications playback, background, dial, goto, hangup und answer zu verwenden.

## Quiz

1. Die Konfigurationsdateien für Channels sind (wählen Sie alle zutreffenden aus):
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. Welcher Satz zusammengehöriger Objekte ersetzt in `pjsip.conf` auf Asterisk 22 den einzelnen `chan_sip` Peer `[6001]` (`type=friend`/`host=dynamic`)?
   - A. Ein `type=peer` und ein `type=user`
   - B. Ein `type=endpoint`, ein `type=auth` und ein `type=aor`
   - C. Ein einzelner `type=friend`
   - D. Ein `type=transport` und ein `type=global`
3. Die Definition eines context in der Konfigurationsdatei für Channels ist wichtig, da sie den eingehenden context für Anrufe von diesem Channel festlegt — ein Anruf von diesem Channel wird im passenden context in `extensions.conf` verarbeitet.
   - A. Wahr
   - B. Falsch
4. Die Hauptunterschiede zwischen den Anwendungen `Playback()` und `Background()` sind (wählen Sie zwei aus):
   - A. Playback spielt eine Ansage ab, wartet aber nicht auf Zifferneingaben.
   - B. Background spielt eine Ansage ab, wartet aber nicht auf Zifferneingaben.
   - C. Background spielt eine Nachricht ab und wartet auf die Eingabe von Ziffern.
   - D. Playback spielt eine Nachricht ab und wartet auf die Eingabe von Ziffern.
5. Wenn ein Anruf über eine Telefonieschnittstellenkarte (FXO) ohne DID in Asterisk eingeht, wird er in der speziellen extension behandelt:
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. Gültige Formate für die Anwendung `Goto()` sind (wählen Sie drei aus):
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. Das Muster `_7[1-5]XX` passt auf (wählen Sie alle zutreffenden aus):
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. Was bewirkt die Option `m` in `Dial(PJSIP/${EXTEN},20,tTm)`?
   - A. Begrenzt den Anruf auf eine maximale Dauer.
   - B. Bietet dem Anrufer Wartemusik anstelle des Freizeichens, bis der Channel antwortet.
   - C. Sendet DTMF-Ziffern, nachdem die angerufene Partei geantwortet hat.
   - D. Erzwingt die Caller ID mithilfe eines dialplan hint.
9. In der von `chan_dahdi.conf` verwendeten Grammatik für die Vererbung von Optionen:
   - A. Definieren Sie das Objekt in einer einzigen Zeile.
   - B. Definieren Sie zuerst die Optionen und deklarieren Sie die Objekte unterhalb der definierten Optionen.
   - C. Definieren Sie einen separaten context für jedes Objekt.
10. Prioritäten in einer extension müssen fortlaufend nummeriert sein (1, 2, 3, …) und können nicht `n` verwenden.
    - A. Wahr
    - B. Falsch

**Antworten:** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
