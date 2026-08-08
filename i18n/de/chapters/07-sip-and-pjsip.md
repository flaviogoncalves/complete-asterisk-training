# SIP & PJSIP im Detail

SIP ist das Protokoll; PJSIP ist die Art und Weise, wie Asterisk 22 es spricht. **PJSIP** (`chan_pjsip`, konfiguriert über `pjsip.conf`) ist der einzige SIP-Kanal-Treiber in Asterisk 22 LTS. Dieses Kapitel behandelt die Grundlagen des SIP-Protokolls (die auf Protokollebene liegen und zu 100 % gültig bleiben) sowie das PJSIP-Objektmodell und die Konfiguration, die Sie täglich verwenden. Der ausgemusterte Legacy-Treiber und ein Migrationsleitfaden werden im Kapitel *Legacy channels* behandelt.

## Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Die Rolle von SIP User Agents, Proxys, Registraren und Gateways zu erklären;
- Einen grundlegenden SIP-Anrufablauf (REGISTER, INVITE, vorläufige und endgültige Antworten, ACK, BYE) nachzuvollziehen und eine SIP-Nachricht zu lesen;
- Zu beschreiben, wie SDP die Mediensitzung aushandelt und wie NAT die SIP-Signalisierung und RTP beeinflusst;
- Das PJSIP-Objektmodell zuzuordnen — `endpoint`, `auth`, `aor`, `transport`, `identify` und `registration` — und zu verstehen, wie die Objekte aufeinander verweisen;
- SIP-Telefone und trunks in `pjsip.conf` zu konfigurieren, einschließlich der Optionen für NAT-Traversal; und
- Endpoints mit den `pjsip show …` CLI-Befehlen zu überprüfen und Fehler zu beheben.

## SIP-Protokollgrundlagen

Das Session Initiation Protocol (SIP) ist ein textbasiertes Protokoll, ähnlich wie HTTP und SMTP, das entwickelt wurde, um interaktive Kommunikationssitzungen zwischen Benutzern zu initialisieren, aufrechtzuerhalten und zu beenden. Diese Sitzungen können Sprache, Video, Chat, interaktive Spiele und mehr umfassen. SIP wurde von der IETF definiert und hat sich zum De-facto-Standard für Sprachkommunikation entwickelt. Es ist sehr wichtig zu verstehen, wie SIP funktioniert. Auf Asterisk 22 befindet sich die SIP-Konfiguration in `pjsip.conf`, einer der am häufigsten bearbeiteten Dateien auf einem SIP-basierten System (direkt nach `extensions.conf`).

### Funktionsweise

SIP ist ein Signalisierungsprotokoll mit den folgenden Komponenten: User Agent Client, User Agent Servers, SIP Proxies und SIP Gateways. Die folgende Abbildung stellt die Beziehungen zwischen diesen Komponenten dar.

- UAC (user agent client) – Der Client oder das Endgerät, das die SIP-Signalisierung initialisiert.
- UAS (user agent server) – Der Server, der auf eine SIP-Signalisierung reagiert, die von einem UAC kommt.
- UA (user agent) – Das SIP-Endgerät (Telefone oder Gateways, die sowohl UAC als auch UAS enthalten).
- Proxy Server – Empfängt Anfragen von einem UA und leitet sie an andere SIP Proxies weiter, falls die jeweilige Station nicht unter ihrer Verwaltung steht.
- Redirect Server – Empfängt Anfragen und sendet sie mit Zielinformationen an den UA zurück, anstatt sie direkt an das Ziel weiterzuleiten.
- Location Server – Empfängt Anfragen von einem UA und aktualisiert die Standortdatenbank mit diesen Informationen.

Normalerweise werden Proxy-, Redirect- und Location-Server auf derselben Hardware gehostet und verwenden dieselbe Software, die wir als SIP-Proxy bezeichnen. Der SIP-Proxy ist für die Wartung der Standortdatenbank, den Verbindungsaufbau und die Sitzungsbeendigung verantwortlich.

![Die wichtigsten SIP-Komponenten: User Agents (UAC/UAS/UA), der Registrar/Proxy/Redirect-Server und ein Gateway zum PSTN, wobei der RTP-Medienstrom direkt zwischen den Endpunkten fließt](../images/07-sip-and-pjsip-fig01.png)

#### SIP-Registrierungsprozess

Bevor ein Telefon Anrufe empfangen kann, muss es in einer Standortdatenbank registriert werden. In der Standortdatenbank wird die IP-Adresse mit dem Namen verknüpft. Im folgenden Beispiel wird die extension 8500 mit der IP-Adresse 200.180.1.1 verknüpft. Sie müssen nicht zwingend Telefonnummern verwenden. In der SIP-Architektur könnte die registrierte extension auch flavio@voip.school sein.

![SIP-Registrierung: Das Telefon sendet ein REGISTER, das die extension 8500 mit seiner IP-Adresse verknüpft; der Registrar speichert den Kontakt in der Standortdatenbank und antwortet mit 200 OK](../images/07-sip-and-pjsip-fig02.png)

#### Proxy-Betrieb

Wenn der SIP-Server als SIP-Proxy fungiert, bleibt er in der Mitte der Signalisierung und ist zu fortgeschrittenem Routing und zur Abrechnung fähig. Der Medienfluss, basierend auf dem Real-time Transport Protocol (RTP), verläuft weiterhin direkt zwischen den Endpunkten.

![Proxy-Betrieb: Der SIP-Proxy bleibt im Signalisierungspfad (INVITE/200 OK) und sucht den Angerufenen im Location Server, während der RTP-Medienstrom direkt zwischen den beiden Endpunkten fließt](../images/07-sip-and-pjsip-fig03.png)

#### Redirect-Betrieb

Bei der Umleitung sendet der SIP-Server einfach eine Nachricht (z. B. 302 moved temporarily) an den User Agent und hält sich aus dem Pfad der neuen Nachrichten heraus. Dies ist sehr ressourcenschonend, bietet jedoch keinerlei Kontrolle. Umleitungen werden manchmal bei Lastverteilungsdesigns verwendet.

![Redirect-Betrieb: Der Redirect-Server beantwortet das INVITE mit einem 302 Moved Temporarily, das den Kontakt enthält, und tritt dann zurück, während der Anrufer das INVITE/ACK direkt an den neuen Standort sendet](../images/07-sip-and-pjsip-fig04.png)

#### Wie Asterisk SIP handhabt

Es ist wichtig zu verstehen, dass Asterisk weder ein SIP-Proxy noch ein SIP-Redirector ist. Asterisk kann die Rolle des Registrars und Location Servers übernehmen; es verbindet jedoch nur zwei UACs mit sich selbst. Daher wird Asterisk als Back-to-Back User Agent (B2BUA) betrachtet. Mit anderen Worten: Es verbindet zwei SIP-Kanäle und überbrückt sie miteinander. Asterisk verfügt über einen Re-Invite-Mechanismus, der dazu führen kann, dass die SIP-Kanäle direkt miteinander kommunizieren, anstatt über Asterisk zu laufen. Bei einem PJSIP-endpoint wird dies durch den Parameter `direct_media` gesteuert. Bei Verwendung von `direct_media=yes` fließt der RTP-Strom direkt von einem Endpunkt zum anderen, was Serverressourcen freigibt.

#### SIP-Betrieb mit direct_media=yes

![SIP-Betrieb mit directmedia=yes: SIP-Signalisierung fließt durch Asterisk, während das RTP-Audio direkt zwischen den beiden Telefonen übertragen wird, was Serverressourcen freigibt](../images/07-sip-and-pjsip-fig05.png)

Wenn Sie jedoch den Anruf über Asterisk weiterleiten oder aufzeichnen müssen, können Sie den Parameter `direct_media=no` verwenden, um den RTP-Strom durch den Asterisk-Server zu erzwingen.

#### SIP-Betrieb mit direct_media=no

![SIP-Betrieb mit directmedia=no: Sowohl die SIP-Signalisierung als auch das RTP-Audio werden über Asterisk verankert, was es ermöglicht, den Anruf aufzuzeichnen, zu transkodieren oder weiterzuleiten](../images/07-sip-and-pjsip-fig06.png)

#### SIP-Nachrichten

Die grundlegenden SIP-Nachrichten sind:

- INVITE – Verbindungsaufbau
- ACK – Bestätigung
- BYE – Verbindungsbeendigung
- CANCEL – Verbindungsbeendigung für einen nicht aufgebauten Anruf
- REGISTER – Registrierung eines UAC an einem SIP-Proxy
- OPTIONS – Kann zur Überprüfung der Verfügbarkeit verwendet werden
- REFER – Weiterleitung eines SIP-Anrufs an jemand anderen
- SUBSCRIBE – Abonnement von Benachrichtigungsereignissen
- NOTIFY – Senden von Kanalinformationen
- INFO – Senden verschiedener Nachrichten (z. B. DTMF)
- MESSAGE – Senden von Sofortnachrichten

Die SIP-Antworten sind im Textformat und leicht lesbar (ähnlich wie HTTP-Nachrichten). Die wichtigsten Antworten sind:

- 1XX – Informationsnachrichten (100–trying, 180–ringing, 183–progress)
- 2XX – Erfolgreiche Anfrage abgeschlossen (200 – OK)
- 3XX – Anrufumleitung, Anfrage muss an einen anderen Ort geleitet werden (302 – moved temporarily, 305 – use proxy)
- 4XX – Fehler (403 – Forbidden)
- 5XX – Serverfehler (500 – Internal Server Error; 501 – Not implemented)
- 6XX – Globaler Fehler (606 – Not acceptable)

Zum Beispiel:

```
INVITE sip:2000@192.168.1.133 SIP/2.0
Via: SIP/2.0/UDP
192.168.1.116;rport;branch=z9hG4bKc0a8017400000063452fafbb00006967000000d2
From: "unknown"<sip:2001@192.168.1.133>;tag=1556140623845
To: <sip:2000@192.168.1.133>
Contact: <sip:2001@192.168.1.116>
Call-ID: 64B4C8EC-FCFC-49E9-98B1-90982EEEBED3@192.168.1.116
CSeq: 2 INVITE
Max-Forwards: 70
User-Agent: SJphone/1.61.312b (SJ Labs)
Content-Length: 335
Content-Type: application/sdp
Proxy-Authorization: Digest
username="2001",realm="asterisk",nonce="6c55905e",uri="sip:2000@192.168.1.133",
response="983c0099eea125d8cdfe93b0ec99f3ec",algorithm=MD5
```

#### Session Description Protocol (SDP)

SDP wurde ursprünglich in IETF RFC 2327 definiert, das nun durch RFC 4566 ersetzt wurde. Es dient der Beschreibung von Multimediasitzungen für Zwecke der Sitzungsankündigung, Sitzungseinladung und anderer Formen der Einleitung von Multimediasitzungen. SDP enthält:

- Transportprotokoll (RTP/UDP/IP)
- Art der Medien (Text, Audio, Video)
- Medienformat oder codec (H.261 Video, g.711 Audio, etc.)
- Informationen, die zum Empfang dieser Medien erforderlich sind (Adressen, Ports, etc.)

Das folgende Beispiel ist eine Transkription eines SDP, das einen Anruf zwischen zwei Telefonen beschreibt.

```
v=0
o=- 3369741883 3369741883 IN IP4 192.168.1.116
s=SJphone
c=IN IP4 192.168.1.116
t=0 0
a=setup:active
m=audio 49160 RTP/AVP 3 97 98 8 0 101
a=rtpmap:3 GSM/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11,16
```

### SIP NAT Traversal

Network Address Translation (NAT) ist eine Funktion, die von den meisten Netzwerken verwendet wird, um Internet-IP-Adressen zu sparen. Normalerweise erhält ein Unternehmen einen kleinen Block von IP-Adressen, und Endbenutzer erhalten eine IP-Adresse dynamisch, wenn sie mit dem Internet verbunden sind. NAT löst das Adressierungsproblem, indem es interne Adressen auf externe Adressen abbildet. Es speichert eine Zuordnung von internen zu externen Adressen in seinem Speicher. Diese Zuordnung ist für eine bestimmte Zeit gültig, danach wird sie verworfen. Die Zuordnung verwendet IP:Port-Paare für die internen und externen Adressen. Es gibt vier Arten von NAT:

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

Die folgende NAT-Theorie — die vier NAT-Typen, das Contact-Header-Problem, Keep-alives und das Erzwingen von Medien durch den Server — ist protokollspezifisch und gilt für jede SIP-Implementierung. Die Konfiguration jedes Verhaltens auf Asterisk 22 (PJSIP) wird später in diesem Kapitel unter *Nat traversal on res_pjsip* behandelt.

#### Full Cone

Das erste NAT, Full Cone, stellt eine statische Zuordnung von einem externen IP:Port-Paar zu einem internen IP:Port-Paar dar. Jeder externe Computer kann sich damit über das externe IP:Port-Paar verbinden. Dies ist bei zustandslosen Firewalls der Fall, die mit Filtern implementiert sind.

![Full Cone NAT: Der interne Host (10.0.0.1:8000) wird statisch auf das externe Paar 200.180.4.168:1234 abgebildet, sodass jeder externe Computer Pakete an dieses Paar senden und den internen Host erreichen kann](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

Beim Restricted Cone-Szenario wird das externe IP:Port-Paar nur geöffnet, wenn der interne Computer Daten an eine externe Adresse sendet. Das Restricted Cone NAT blockiert jedoch alle eingehenden Pakete von einer anderen Adresse. Mit anderen Worten: Der interne Computer muss Daten an einen externen Computer senden, bevor dieser Daten zurücksenden kann.

#### Port Restricted Cone

Die Port Restricted Cone-Firewall ist fast identisch mit der Restricted Cone. Der einzige Unterschied besteht darin, dass das eingehende Paket nun exakt von derselben IP und demselben Port des gesendeten Pakets stammen muss.

#### Symmetric

Die letzte Art von NAT wird als symmetrisch bezeichnet. Sie unterscheidet sich von den ersten drei dadurch, dass für jede externe Adresse eine spezifische Zuordnung erfolgt. Nur spezifische externe Adressen dürfen durch die NAT-Zuordnung zurückkommen. Es ist nicht möglich, das externe IP:Port-Paar vorherzusagen, das vom NAT-Gerät verwendet wird. Die anderen drei NAT-Typen erlauben die Verwendung eines externen Servers, um die externe IP-Adresse für die Kommunikation zu ermitteln. Bei symmetrischem NAT kann die ermittelte Adresse selbst dann, wenn Sie eine Verbindung zu einem externen Server herstellen können, für kein anderes Gerät außer diesem Server verwendet werden.

![Symmetric NAT: Ein anderer externer Quellport wird für jedes Ziel zugewiesen, sodass die für einen Server ermittelte Zuordnung nicht von einem anderen Host wiederverwendet werden kann, was STUN-basiertes Traversal unterbricht](../images/07-sip-and-pjsip-fig12.png)

#### NAT-Firewall-Tabelle

Die folgende Tabelle fasst die vier Arten von NAT zusammen.

| NAT-Typ | Muss zuerst Daten senden | Kann externe IP:Port für Rückpakete bestimmen | Beschränkt eingehende Pakete auf Ziel-IP:Port |
| --- | --- | --- | --- |
| Full Cone | Nein | Ja | Nein |
| Restricted Cone | Ja | Ja | Nur IP |
| Port Restricted Cone | Ja | Ja | Ja |
| Symmetric | Ja | Nein | Ja |

#### SIP-Signalisierung und RTP über NAT

Einige der größten Probleme beim NAT Traversal bestehen darin, dass zwei Probleme gelöst werden müssen: SIP-Signalisierung und Audio (RTP). Die meisten Probleme mit einseitigem Audio sind NAT-bedingt. Eine interessante Eigenschaft von SIP ist, dass ein UAC beim Senden eines Pakets die IP-Adresse in das SIP-Header-Feld „Contact“ einbettet. Normalerweise ist dies eine interne (RFC1918) Adresse; Antworten auf dieses Paket können nicht über das Internet zurück zum UAC geroutet werden. Die konzeptionellen Lösungen sind immer dieselben:

- **Ignorieren der Contact/Via-Adresse und Antworten an den Absender, von dem das Paket tatsächlich kam.** Dies ist das in RFC 3581 definierte Verhalten (`rport`). Auf PJSIP ist dies `force_rport=yes`, und `rewrite_contact=yes` schreibt den gespeicherten Kontakt auf die Quelladresse um.
- **Senden der Medien zurück an die Adresse, von der das RTP tatsächlich ankam** (symmetrisches RTP, historisch *comedia* genannt). Auf PJSIP ist dies `rtp_symmetric=yes`.
- **Offenhalten der NAT-Zuordnung.** Wenn die Zuordnung abläuft, kann Asterisk kein INVITE mehr an den UAC senden — das Telefon kann Anrufe tätigen, aber nicht empfangen. Das Senden eines periodischen OPTIONS (ein *qualify*) hält das Pinhole offen. Auf PJSIP ist dies `qualify_frequency=` auf dem AOR.

Wenn das NAT des Benutzers vom symmetrischen Typ ist, ist es nicht möglich, Pakete direkt von einem UAC zum anderen zu senden; in diesem Fall müssen Sie das RTP mit `direct_media=no` durch Asterisk erzwingen. Diese Konfigurationen sind für die meisten Fälle geeignet. Es ist möglich, den Datenverkehr mithilfe fortgeschrittener Techniken wie Simple Traversal of UDP over NAT (STUN), was bei Full Cone, Restricted Cone und Port Restricted Cone nützlich ist, sowie Application Layer Gateway (ALG) zu optimieren. Leider sind die meisten Firewalls heute — selbst Heim-DSL/Kabel-Router — symmetrisch, was STUN unbrauchbar macht. ALG könnte das Problem lösen, wird aber in den meisten Fällen nicht unterstützt, ist nicht implementiert oder fehlerhaft.

#### Asterisk hinter NAT

Manchmal wird der Asterisk-Server selbst hinter einer Firewall mit NAT implementiert — eine sehr häufige Situation bei Bereitstellungen in der Cloud. In diesem Fall ist eine zusätzliche Konfiguration erforderlich, damit Asterisk seine **öffentliche** Adresse in den SIP- und SDP-Headern anstelle seiner privaten Adresse bewirbt.

Konzeptionell gibt es drei Schritte:

- Weiterleitung des SIP-Signalisierungsports (standardmäßig UDP 5060) von der Firewall an den Asterisk-Server.
- Weiterleitung des RTP-Medienportbereichs (standardmäßig UDP 10000–20000, eingestellt in `rtp.conf`) von der Firewall an den Asterisk-Server.
- Mitteilung der externen Adresse an Asterisk und Angabe, welches Netzwerk lokal ist, damit es weiß, wann die öffentliche Adresse in die Header eingefügt werden muss.

Auf PJSIP werden diese letzten beiden Punkte auf `external_media_address` / `external_signaling_address` und `local_net=` auf dem **transport** abgebildet, und der RTP-Portbereich wird weiterhin in `rtp.conf` konfiguriert:

```
; RTP Configuration
;
[general]
;
; RTP start and RTP end configure start and end addresses
;
rtpstart=10000
rtpend=20000
```

Die vollständige, funktionierende PJSIP-Konfiguration für einen Asterisk-Server hinter NAT wird später in diesem Kapitel unter *Asterisk Server behind NAT* angegeben.

### SIP-Einschränkungen

Asterisk verwendet den eingehenden RTP-Strom, um den ausgehenden Strom zu synchronisieren. Wenn der eingehende Strom unterbrochen wird (Stilleunterdrückung), wird die Warteschleifenmusik (Music-on-Hold) unterbrochen. Mit anderen Worten: Sie sollten keine Stilleunterdrückung bei Telefonen oder Anbietern mit Asterisk verwenden.

## PJSIP: der SIP-Kanal

PJSIP ist der SIP-Kanal in Asterisk. Er wurde erstmals in Asterisk 12 eingeführt und entwickelte sich nach Jahren der Entwicklung zum Standard- und empfohlenen SIP-Kanal. In Asterisk 22 (der aktuellen LTS-Version) ist er der einzige verfügbare SIP-Kanaltreiber. PJSIP basiert auf dem Projekt von Teluu namens pjproject. Der pjproject-Stack wird von vielen softphones und kommerziellen SIP-Implementierungen verwendet. Es handelt sich um einen vielseitigen und ausgereiften SIP-Stack.

### Warum PJSIP verwenden?

PJSIP war eine grundlegende Neugestaltung der Art und Weise, wie Asterisk SIP spricht, und es lohnt sich, die Funktionen zu verstehen, die ihn zum Standard gemacht haben.

#### Funktionen

Der Kanal unterstützt viele Funktionen, von denen einige hier erwähnenswert sind:

- Mehrfachregistrierungen: Sie können mehr als ein Telefon verwenden, das mit derselben Address of Record verbunden ist. Mit anderen Worten: Sie können zwei Telefone mit demselben endpoint verbinden.
- Benutzerfreundliche Application Program Interface (API). Die API ist modular und einfach zu erweitern; sie besteht aus vielen kleinen, zusammenarbeitenden Modulen anstatt aus einem großen Codeblock.
- Mehrere Transportwege: Sie können bei der Verwendung von PJSIP auf mehreren Adressen, Ports und Transportprotokollen lauschen. Sie sind nicht auf eine einzige Bind-Adresse für alle Ihre Geräte beschränkt. PJSIP ist sehr flexibel.

#### Ein Hinweis zur Konfiguration

Die PJSIP-Konfiguration ist ausführlicher: Sie erfordert etwas mehr Aufwand und mehr Konfigurationszeilen, da jedes Gerät durch mehrere zusammengehörige Objekte anstatt durch einen einzigen Peer-Block beschrieben wird. Diese zusätzliche Struktur verleiht PJSIP seine Flexibilität, und der Konfigurationsassistent (wird später behandelt) hält die tägliche Bereitstellung kurz.

### PJSIP-Module

Der PJSIP-Kanal wird durch viele Module implementiert, die unten beschrieben werden:

#### res_pjsip

Dies ist die Basisschicht von PJSIP und das Hauptmodul. Es ist für einige der wichtigsten Dienste verantwortlich.

#### res_pjsip_session

Dieses Modul ist für Mediensitzungen, die Verarbeitung des Session Description Protocols und einige Erweiterungen zuständig.

#### res_pjsip_messaging

Verarbeitet SIP-Nachrichten und parst SIP-Header.

#### res_pjsip_registrar

Verantwortlich für die Handhabung von SIP-Registrierungen.

#### res_pjsip_pubsub

Verantwortlich für die Verarbeitung von Subscribe, Notify und Publish. Diese Nachrichten sind für die Handhabung von SIP-Präsenz und BLF (Busy Lamp Field) zuständig.

### PJSIP-Konfiguration

PJSIP hat viele verschiedene Abschnitte. Das Format der Abschnitte ist:

```
[Section Name]
Option = Value
Option = Value
```

#### End point-Abschnitt

Das wichtigste Konfigurationsobjekt ist der endpoint. Die endpoint-Konfiguration verfügt über Kernfunktionalitäten und muss mit einem AOR- und einem Transport-Abschnitt verknüpft werden. Beispiel:

```
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
```

Wenn Sie sich das obige Beispiel ansehen, fungiert der endpoint als eine Art Klebstoff, der alle Abschnitte miteinander verbindet. Er spezifiziert einen Transport, die Address of Record und die Authentifizierung für ein Telefon. Er definiert auch den wichtigsten Teil: den context-Einstiegspunkt im dialplan.

#### Address of Record (AOR)

Dieses Objekt teilt Asterisk mit, wie der endpoint zu kontaktieren ist. Es speichert die Kontaktadressen. Es ermöglicht auch die Konfiguration von Mailboxen. Beispiel:

```
[softphone]
type=aor
max_contacts=2
```

#### Authentifizierung

Dieser Abschnitt ist für die eingehende und ausgehende Authentifizierung zuständig. Die Dokumentation finden Sie in der Beispieldatei pjsip.conf. Beispiel:

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### Transport

Der Transport-Abschnitt ermöglicht es Ihnen, IPv4- und IPv6-Adressen sowie das Transportprotokoll (TCP, UDP, TLS, Websockets usw.) zu definieren. Sie können in diesem Abschnitt auch NAT-Adressen konfigurieren. Sie können mehrere Transportwege erstellen, diese dürfen jedoch nicht dieselbe IP und denselben Port teilen, und Sie können nicht mehrere TCP- oder TLS-Transportwege derselben IP-Version binden. Beispiel:

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### Registrierung

Dieses Objekt wird verwendet, um eine ausgehende Registrierung zu konfigurieren. Beispiel:

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### Identify

Dieses Objekt steuert, welcher SIP-Request zu welchem endpoint gehört. Wenn Sie keinen identify-Abschnitt haben, gleicht das System den Inhalt des „From“-Headers mit dem endpoint-Namen ab. Über diesen Abschnitt können Sie spezifische IP-Adressen bestimmten endpoints zuweisen, identifiziert durch Benutzername oder IP. Beispiel:

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### ACL

Das ACL-Objekt ermöglicht es Ihnen, spezifische Netzwerke mit Zugriff auf den endpoint zu konfigurieren. ACLs werden nun in einem spezifischen Abschnitt oder in der acl.conf definiert. Beispiel:

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### Beziehung zwischen Entitäten

Die Beziehung zwischen den Konfigurationsobjekten bietet eine große Flexibilität bei der Konfiguration. Für Einsteiger wirkt sie jedoch etwas komplex.

![Beziehungen zwischen PJSIP-Konfigurationsobjekten: Der endpoint verlinkt auf Transport, Auth und AOR (welches Kontakte enthält); die Registrierung verknüpft Transport und Auth; Identify zeigt auf den endpoint, während ACL und Domain Alias eigenständig sind](../images/07-sip-and-pjsip-fig14.png)

Die obige Grafik bedeutet:

#### Beziehungen:

| Objekte | Kardinalität |
| --- | --- |
| ENDPOINT / AOR | viele zu viele |
| ENDPOINT / AUTH | null zu viele, zu null zu eins |
| ENDPOINT / IDENTIFY | null zu eins |
| ENDPOINT / TRANSPORT | null zu viele, zu mindestens eins |
| REGISTRATION / AUTH | null zu viele, zu null zu eins |
| REGISTRATION / TRANSPORT | null zu viele, zu mindestens eins |
| AOR / CONTACT | viele zu viele |

ACL und DOMAIN_ALIAS haben keine direkte Konfigurationsbeziehung zu den anderen Objekten.

### Konfiguration eines Softphones

Um ein softphone zu konfigurieren, müssen Sie viele verschiedene Abschnitte definieren. Unten finden Sie ein Beispiel für die Konfiguration eines softphones. Für die Client-Seite können Sie das SipPulse Softphone (https://www.sippulse.com/produtos/softphone) verwenden, das Sie herunterladen und bei dem unten stehenden endpoint registrieren können.

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
[softphone]
type=aor
max_contacts=2
```

Die obige Konfiguration legt einen Transport für UDP auf Port 5060 fest, definiert dann einen endpoint, dessen Authentifizierung per Benutzername und Passwort sowie die Address of Record mit maximal zwei Kontakten.

### Konfiguration eines SIP trunks

Um einen SIP trunk zu konfigurieren, benötigen Sie die IP-Adresse oder den Host des SIP trunks, den Namen und das Passwort. Sie müssen zu diesem Zweck einen neuen Registrierungsabschnitt erstellen.

```
[siptrunk]
type=endpoint
transport=transport-udp-main
context=from-siptrunk
direct_media=no
disallow=all
allow=ulaw
outbound_auth=siptrunk
aors=siptrunk
[siptrunk]
type=aor
contact=sip:sip.flagonc.com:5600
[siptrunk]
type=auth
auth_type=digest
username=1020
password=supersecret
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
[siptrunk]
type=identify
endpoint=siptrunk
match=sip.flagonc.com
```

### NAT-Traversal bei res_pjsip

Network Address Translation wurde vor langer Zeit als Lösung für den Mangel an IPv4-Adressen entwickelt. Viele Menschen nutzen NAT auch als Sicherheitsfunktion, um interne Adressen eines Netzwerks vor dem öffentlichen Internet zu verbergen. Manchmal müssen Sie NAT-Traversal handhaben. In einigen Fällen kann sich der Server hinter einem NAT befinden, etwa wenn Sie den Server in der Cloud bereitstellen. Wenn Sie in der Cloud bereitstellen, befinden sich Ihre Benutzer oft ebenfalls hinter einem NAT-Router. Um die Dinge zu ordnen, teilen wir dies in zwei Teile auf. Der erste ist der Asterisk-Server hinter NAT, wie bei einer Cloud-Bereitstellung. Im zweiten Abschnitt behandeln wir, wie Clients hinter NAT mithilfe von res_pjsip unterstützt werden.

#### Asterisk-Server hinter NAT

Wenn sich der Asterisk-Server hinter einem NAT befindet, sollten Sie die externen und internen lokalen Adressen im Transport-Abschnitt angeben. Wir verwenden die folgenden Anweisungen.

##### direct_media

Fließen die Medien direkt von Peer zu Peer oder über den Server? Für NAT sollten sie über den Server fließen. Wählen Sie für NAT no. Beispiel:

```
direct_media=no
```

##### external_media_address

Medienadresse zur Handhabung externer RTP-Daten. Normalerweise identisch mit der external_signaling_address. Verwenden Sie die öffentliche IP-Adresse Ihres Servers für Medien und Signalisierung. Beispiel:

```
external_media_address=54.232.1.20
```

##### external_signaling_address

Externe SIP-Adresse, an der Nachrichten empfangen werden sollen. Beispiel:

```
external_signaling_address=54.232.1.20
```

##### local_net

Das Netzwerk, das Sie als Ihr lokales Netzwerk betrachten. Beispiel:

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### Vollständiges Beispiel für den Transport eines Asterisk-Servers hinter NAT

Um einen Asterisk-Server hinter NAT zu verwenden, müssen Sie zwei Schritte ausführen. Erstens: Definieren Sie einen Transport hinter NAT. Zweitens: Verknüpfen Sie diesen Transport mit dem endpoint.

##### Erstellen des Transports hinter NAT

Um den Transport hinter NAT in der Datei pjsip.conf zu erstellen, legen Sie einen Abschnitt wie folgt an.

```
[tnat]
type=transport
protocol=udp
bind=0.0.0.0
local_net=172.16.30.0/24
local_net=127.0.0.1/32
external_media_address=54.232.1.20
external_signaling_address=54.232.1.20
```

Verknüpfen Sie den Transport mit einem endpoint

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

Für SIP trunks sollten Sie den Transport auch mit dem Registrierungsabschnitt verknüpfen, wie unten gezeigt.

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### Verwendung von Asterisk mit Clients hinter NAT

Um Telefone hinter NAT zu verwenden, müssen Sie einige zusätzliche Parameter pro endpoint konfigurieren.

##### direct_media

Fließen die Medien direkt von Peer zu Peer oder über den Server? Für NAT sollten sie über den Server fließen. Beispiel:

```
direct_media=no
```

##### rtp_symmetric

Dies nennen wir Comedia. Anstatt sich wie üblich in SIP auf die im SDP-Header definierte Adresse zu verlassen, verwenden Sie die Adresse, von der Sie das erste RTP-Paket empfangen, und senden Sie von derselben Adresse zurück. Beispiel:

```
rtp_symmetric=yes
```

##### force_rport

Dies ist das in RFC3581 definierte Verhalten. Anstatt die Adresse im VIA-Header zu verwenden, senden Sie die Antworten an den Ort zurück, von dem die Requests kommen. Beispiel:

```
force_rport=yes
```

##### qualify_frequency

Diese Einstellung muss auf die AOR angewendet werden (nicht auf den endpoint). Es gibt noch einen letzten Schritt: die Konfiguration der qualify-Option. Sie sollten immer einige Pakete an das Ziel senden (pingen), um das NAT-Mapping offen zu halten. Dies wird im AOR-Abschnitt eingestellt. Beispiel:

- qualify_frequency=15

Vollständiges Beispiel eines endpoints, bei dem sich sowohl Server als auch Client hinter NAT befinden

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
force_rport=yes
rtp_symmetric=yes
auth=6000
aors=6000
[6000]
type=aor
qualify_frequency=15
```

### Kanalbenennung

Wie üblich ist die Benennung ein wichtiger Aspekt eines Kanals, und PJSIP hat einige interessante Details. Sie wählen einen PJSIP-endpoint mit der Technologie `PJSIP/`:

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

Eine nützliche Funktion ist die Möglichkeit, alle bei einer AOR registrierten Kontakte gleichzeitig anzurufen. Die Funktion PJSIP_DIAL_CONTACTS wird in die Liste der anzurufenden Kontakte übersetzt.

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

Einen trunk anzurufen ist etwas anders. Angenommen, der trunk wird nicht bei Ihrer Plattform registriert oder hat keine IP-Adresse, die mit Ihrer AOR (Address of Record) verknüpft ist. Sie können die Adresse des trunks direkt in der Zeile angeben. Als Beispiel ein internationaler Anruf.

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

Wenn Sie es vorziehen, die Adresse des trunks im AOR-Abschnitt anzugeben, können Sie auch Folgendes verwenden.

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### PJSIP-Konfigurationsassistent

PJSIP ist leistungsstark, aber ausführlich in der Konfiguration: viele verschiedene Abschnitte und Vorlagen, die anfangs verwirrend sein können. Die gute Nachricht ist der PJSIP-Konfigurationsassistent. Indem Sie jeden Kanal in wenigen Zeilen definieren, können Sie Vorlagen erstellen und die Konfiguration neuer Geräte vereinfachen. Verwenden Sie die Datei pjsip_wizard.conf zur Konfiguration. Sie müssen dennoch Transport- und globale Abschnitte in der Datei pjsip.conf definieren. Ich persönlich ziehe es vor, den Assistenten nur für Telefone zu verwenden; bei SIP trunks ist die Anzahl meist gering, und man kann sie direkt in pjsip konfigurieren. Der größte Vorteil des Assistenten ist die Möglichkeit, Vorlagen zu verwenden und schnell Telefone zu erstellen.

```
[phone_default](!)
type = wizard
accepts_auth = yes
accepts_registrations = yes
transport = tnat
endpoint/allow = ulaw
endpoint/context = from-internal
endpoint/direct_media=no
endpoint/force_rport=yes
endpoint/rtp_symmetric=yes
aor/qualify_frequency=15
[alice](phone_default)
inbound_auth/username = alice
inbound_auth/password = supersecret
[bob](phone_default)
inbound_auth/username = bob
inbound_auth/password = supersecret
```

### Laden und Entladen von PJSIP

PJSIP ist der einzige SIP-Kanal in Asterisk 22, und seine Module werden standardmäßig geladen. In seltenen Fällen möchten Sie das Laden von Modulen möglicherweise über die Datei modules.conf steuern – zum Beispiel, um PJSIP auf einem Server zu deaktivieren, der nur IAX2 oder DAHDI verwendet.

#### PJSIP deaktivieren

Bearbeiten Sie die Datei modules.conf und fügen Sie die folgenden Zeilen hinzu.

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### Konsolenbefehle

Nachdem Sie Ihre PJSIP-endpoints konfiguriert haben, ist es an der Zeit zu prüfen, wie Sie Ihre Konfiguration überprüfen können. Es gibt viele Konsolenbefehle, die Ihnen bei dieser Aufgabe helfen. Laden Sie nach dem Bearbeiten der pjsip.conf die Konfiguration neu mit:

```
module reload res_pjsip.so
```

Ein einfaches `reload` (oder `core reload`) lädt alle Module einschließlich PJSIP neu. (Beachten Sie, dass es keinen reinen `pjsip reload`-Befehl gibt – `pjsip reload` existiert nur in der Form `pjsip reload qualify aor|endpoint`.) Sie können alle verfügbaren PJSIP-Konsolenbefehle mit `help pjsip` auflisten.

#### pjsip show endpoints

Dieser Befehl zeigt die verfügbaren endpoints an. Im Bild unten sehen Sie einen Screenshot. Sie können die Adresse des softphone-endpoints sehen und feststellen, dass er verfügbar ist.

![Ausgabe von `pjsip show endpoints` mit Auflistung der blink-, siptrunk- und softphone-endpoints mit ihren AOR-, Auth-, Transport- und Verfügbarkeitsdaten – der softphone-Kontakt ist registriert (Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

Mit dem obigen Befehl können Sie jeden Parameter des endpoints einsehen. Die unten stehende Liste wurde auf weniger als die Hälfte der aktuellen Parameter gekürzt.

![Ausgabe von `pjsip show endpoint softphone` mit der vollständigen Parameterliste für einen einzelnen endpoint, von 100rel und allow=(ulaw) bis hin zu callerid und connected_line_method](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

Dieser Befehl listet die konfigurierten Address of Record-Objekte und deren Kontakte auf, sodass Sie bestätigen können, wohin Asterisk Anrufe für jeden endpoint sendet.

#### pjsip show registrations

Der unten stehende Befehl zeigt die von unserem eigenen Server vorgenommenen Registrierungen.

![Ausgabe von `pjsip show registrations`: die ausgehende Registrierung siptrunk/sip:1020@sip.flagonc.com:5600 wird mit dem Status Registered angezeigt](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

Der Befehl list ist etwas benutzerfreundlicher und zeigt weniger, aber besser strukturierte Daten. Auflisten der endpoints:

![Ausgabe von `pjsip list endpoints`: eine kompakte, einzeilige Auflistung pro endpoint (blink, siptrunk, softphone) mit deren Status und Kanalanzahl](../images/07-sip-and-pjsip-fig18.png)

Auflisten der Kontakte:

![Ausgabe von `pjsip list contacts` mit den Kontakt-URIs von siptrunk und softphone sowie deren Hash und Qualify-Status](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

Der nützlichste Befehl zur Fehlerbehebung ist der SIP-Paket-Logger. Er gibt jeden SIP-Request und jede Antwort auf der Konsole aus, sobald sie gesendet oder empfangen werden, was bei der Diagnose von Registrierungs- und Verbindungsaufbauproblemen von unschätzbarem Wert ist.

```
pjsip set logger on
pjsip set logger off
```

Sie können das Logging auch mit `pjsip set logger host <ip>` auf einen einzelnen Host beschränken.

#### pjsip set history on

Eine großartige Ergänzung zu PJSIP ist das Konzept der Historie. Sie können SIP-Requests und -Antworten in Echtzeit auf einfache Weise erfassen und analysieren. Um die Historie zu starten, verwenden Sie den unten stehenden Befehl.

![Ausführung von `pjsip set history on` gibt "PJSIP History enabled" zurück](../images/07-sip-and-pjsip-fig20.png)

Jetzt können Sie die Historie anzeigen:

![Ausgabe von `pjsip show history`: eine nummerierte Tabelle erfasster SIP-Nachrichten – REGISTER, 401 Unauthorized, REGISTER, 200 OK – mit Zeitstempeln, Richtung und Adresse](../images/07-sip-and-pjsip-fig21.png)

Um dann einen spezifischen Request oder eine Antwort zu sehen, zeigen Sie das Historien-Element an:

![Ausgabe von `pjsip show history entry`: der vollständige Text einer einzelnen erfassten SIP-Nachricht – hier die `404 Not Found`-Antwort von Asterisk 22 auf einen OPTIONS-Probe – mit Via (mit `rport`/`received`), Call-ID, From, To und CSeq-Headern, den `Allow`/`Supported`-Fähigkeiten und dem `Server: Asterisk PBX 22.10.0`-Header](../images/07-sip-and-pjsip-fig22.png)

Sehr einfach, nicht wahr? Sie können die Historie auch jederzeit mit `pjsip set history clear` löschen.

> **Migration eines bestehenden chan_sip/sip.conf-Systems?** Der Legacy-Treiber `chan_sip`
> und ein vollständiger **sip.conf → pjsip.conf Migrationsleitfaden** (einschließlich der
> Konzept-Mapping-Tabelle und des `sip_to_pjsip.py`-Konvertierungsskripts) werden im
> Kapitel *Legacy channels* behandelt.

## Zusammenfassung

SIP ist das IETF-Signalisierungsprotokoll, das Mediensitzungen aufbaut, modifiziert und beendet. Seine User Agents, Proxys, Registrar und Gateways tauschen textbasierte Nachrichten aus — REGISTER, INVITE, die vorläufigen und endgültigen Antworten, ACK und BYE —, während SDP die codec aushandelt und RTP die Medien überträgt. Diese Protokolltheorie ist zeitlos und gilt für jede SIP-Implementierung.

In Asterisk 22 kommunizieren Sie SIP über **PJSIP** (`chan_pjsip`), konfiguriert in `pjsip.conf`. Anstelle eines monolithischen Peers wird ein Gerät als eine Menge kleiner, untereinander referenzierter Objekte modelliert: `endpoint` (Anrufverhalten und codec), `auth` (Anmeldeinformationen), `aor` (wo es erreichbar ist) und `transport` (der Listener), sowie `identify` (einen trunk per IP zuordnen) und `registration` (ausgehend registrieren) für Dienstanbieter. Sie haben gesehen, wie diese Objekte zusammenpassen, wie man sowohl Telefone als auch trunks konfiguriert, wie die NAT-Traversal-Optionen (`force_rport`, `rewrite_contact`, `rtp_symmetric`, `direct_media` und das `external_*`/`local_net` des Transports) reale Bereitstellungen lösen und wie man all dies mit `pjsip show endpoints`, `aors`, `contacts` und `registrations` überprüft.

## Quiz

1. Welche Komponente in der SIP-Architektur empfängt eine Anfrage, beantwortet sie mit einer Umleitungsantwort (wie etwa `302 Moved Temporarily`), die den neuen Standort enthält, und hält sich anschließend aus dem Pfad der nachfolgenden Nachrichten heraus?
   - A. Proxy server
   - B. Redirect server
   - C. Location server
   - D. Registrar

2. Welche Rolle spielt Asterisk, wenn es einen SIP-Anruf zwischen zwei Telefonen verarbeitet?
   - A. Ein SIP-Proxy, der nur im Signalisierungspfad verbleibt
   - B. Ein SIP-Redirect-Server
   - C. Ein Back-to-Back User Agent (B2BUA), der zwei SIP-Kanäle überbrückt
   - D. Ein zustandsloser SIP-Load-Balancer

3. Welche SIP-Methode wird von einem Telefon verwendet, um dem Registrar seine aktuelle IP-Adresse mitzuteilen, damit es später Anrufe empfangen kann?
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. Wahr oder Falsch: In Asterisk 22 sind `chan_sip` und `sip.conf` neben PJSIP weiterhin als Legacy-Fallback verfügbar.

5. Mit welchen Konfigurationsobjekten muss ein endpoint verknüpft sein, damit Asterisk weiß, welcher Listening-Socket verwendet werden soll und wohin Anrufe für dieses Gerät gesendet werden müssen? (Wählen Sie alle zutreffenden aus.)
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. Welche Einstellung in einem PJSIP `aor`-Objekt hält das NAT-Mapping durch regelmäßiges Qualifizieren des Kontakts offen, und welche Einheit hat sie?
   - A. `qualify=yes` (boolean)
   - B. `qualify_frequency` (seconds)
   - C. `rtp_timeout` (milliseconds)
   - D. `nat=force_rport`

7. Füllen Sie die Lücke aus: Damit Asterisk eine eingehende SIP-Anfrage anhand der Quell-IP-Adresse (anstatt anhand des `From`-Headers) einem bestimmten endpoint zuordnet, erstellen Sie einen Abschnitt mit `type=________`.

8. Welches PJSIP-Objekt wird verwendet, um eine **ausgehende** Registrierung von Asterisk bei einem SIP-trunk-Anbieter zu konfigurieren?
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. Welcher Befehl auf der Asterisk 22 CLI aktiviert den SIP-Paket-Logger, der jede SIP-Anfrage und -Antwort auf der Konsole ausgibt?
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. Welche Einstellungskombination sorgt bei einem PJSIP-endpoint, der ein Telefon hinter einem symmetrischen NAT bedient, dafür, dass Asterisk an die Quelladresse der Anfrage antwortet (RFC 3581) und Medien an den Ort zurücksendet, von dem das RTP tatsächlich ankommt?
    - A. `direct_media=yes` und `srvlookup=yes`
    - B. `force_rport=yes` und `rtp_symmetric=yes`
    - C. `allowguest=yes` und `insecure=invite`
    - D. `qualify=yes` und `nat=no`

**Antworten:** 1 — B · 2 — C · 3 — D · 4 — Falsch · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
