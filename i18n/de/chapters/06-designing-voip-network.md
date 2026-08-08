# Entwurf eines VoIP-Netzwerks

Voice over IP wächst schnell auf dem Telefonie-Markt. Das Paradigma der Konvergenz verändert die Art und Weise, wie wir kommunizieren, senkt die Kosten und verbessert die Art und Weise, wie wir Informationen austauschen. Sprache ist nur der Anfang einer Ära der vollständigen Multimedia-Kommunikation, die Sprache, Video und Präsenz umfasst. In der Zukunft werden wir nicht mehr Menschen zur Arbeit transportieren, sondern die Arbeit zu den Menschen bringen, da dies sauberer, schneller und kostengünstiger ist. VoIP ist nur ein Teil dieser Revolution. Unsere Herausforderung in diesem Kapitel besteht darin, ein VoIP-Netzwerk zu entwerfen. Um dies zu erreichen, müssen wir Konzepte wie Sitzungsprotokolle und codec sowie die Dimensionierung der Anzahl der Leitungen und der Bandbreite verstehen.

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Die Vorteile von VoIP zu verstehen
- Zu beschreiben, wie Asterisk VoIP handhabt
- Die Konzepte der SIP- und IAX-Kanäle zu beschreiben
- Das am besten geeignete Protokoll für einen spezifischen Datenkanal auszuwählen
- Den am besten geeigneten codec für einen spezifischen Datenkanal auszuwählen
- Die erforderliche Anzahl an Kanälen zu dimensionieren
- Die erforderliche Bandbreite zu berechnen

## VoIP-Vorteile

Warum sollten Sie sich für VoIP interessieren? VoIP bietet sowohl Unternehmen als auch Privatpersonen Vorteile. Kostensenkung ist sicherlich einer davon, aber in einigen Umgebungen vereinfacht VoIP die Integration von Computersystemen. Einige der Vorteile werden hier detailliert beschrieben:

### Konvergenz

Der Hauptvorteil von VoIP ist die Zusammenführung von Daten- und Sprachnetzwerken zur Kostensenkung (Konvergenz). Die Analyse der reinen Gesprächsminutenkosten reicht jedoch möglicherweise nicht aus, um die Einführung von VoIP zu rechtfertigen. Der Preis für Minuten, die von Telefongesellschaften verkauft werden, sinkt rapide und ist ein Faktor, der vor der Einführung von VoIP berücksichtigt werden sollte.

### Infrastrukturkosten

Die Nutzung einer einzigen Netzwerkinfrastruktur reduziert die Kosten, die mit Erweiterungen, Entfernungen und Änderungen verbunden sind. Da IP allgegenwärtig geworden ist, hat es VoIP-bezogene Technologie auf verschiedene neue Geräte gebracht, wie Mobiltelefone, PDAs, eingebettete Systeme und Laptops.

### Offene Standards

Schließlich bieten die offenen Standards, auf denen VoIP aufbaut, die Freiheit, zwischen verschiedenen Anbietern zu wählen. Dieser einzelne Vorteil macht den Kunden zum König, anstatt ihn von TELCOS und PBX-Herstellern abhängig zu machen.

### Computer Telephony Integration

Telefonie ist weitaus älter als die Informatik. Telefonie-PBXs basieren auf Leitungsvermittlung, und man verfügt normalerweise über nicht mehr als einen Computer zur Überwachung. Bei VoIP ist die Telefonie von Grund auf auf Basis von Computerstandards geschaffen. Dies macht die Nutzung von Computer Telephony-Anwendungen billiger und einfacher als im alten Modell. Sie können schnell eine lange Liste von Telefonie-Anwendungen auf Basis von Asterisk erstellen. Sie können IVRs, ACDs, CTI, Dialer, Screen-Popups und andere Anwendungen in einem Bruchteil der Zeit entwickeln, die für herkömmliche PBXs erforderlich wäre.

## Asterisk VoIP-Architektur

Die Architektur von Asterisk ist unten dargestellt. Asterisk behandelt alle VoIP-Protokolle als Kanäle. Sie können jeden codec oder jedes Protokoll verwenden. Das hier zu erlernende Konzept ist, dass Asterisk jeden Kanaltyp mit jedem anderen verbindet. Somit können Sie Signalisierungsprotokolle wie SIP und IAX ineinander übersetzen, sogar mit unterschiedlichen codecs. Sie können zum Beispiel einen Anruf von einem SIP-Telefon im lokalen Netzwerk, das den G.711 codec verwendet, zu einem SIP-trunk zu Ihrem VoIP-Anbieter übersetzen, der den G.729 codec verwendet. In den nächsten Kapiteln werden wir die Details der SIP- und IAX-Architektur erläutern. H.323-Unterstützung (über das chan_ooh323-Add-on) ist verfügbar, aber zunehmend selten; SIP/PJSIP ist der Standard für moderne Implementierungen.

![Modulare Architektur von Asterisk: Anwendungen und Kanäle verbinden sich über APIs mit dem PBX-Switch-Kern, wobei codec-Übersetzungs- und Dateiformat-Module dynamisch geladen werden.](../images/06-voip-network-fig01.png)

## VoIP-Protokolle und der Netzwerk-Stack

VoIP verwendet eine Reihe verschiedener Protokolle, die zusammenarbeiten. Es ist verlockend, sie dem siebenstufigen OSI-Referenzmodell gegenüberzustellen, und viele ältere Diagramme tun genau das — sie ordnen SIP und H.323 der „Sitzungsschicht“ (Session Layer) und die codecs der „Darstellungsschicht“ (Presentation Layer) zu. Diese Zuordnung war schon immer umstritten. Die IETF, die SIP standardisiert, verwendet nicht das OSI-Modell; sie folgt dem älteren vierstufigen TCP/IP-Modell (DoD), und RFC 3261 definiert **SIP als ein Protokoll der Anwendungsschicht**. Die Medien folgen demselben Muster: RTP und die codecs befinden sich in der Nutzlast der Anwendung und werden über UDP auf der Transportschicht übertragen. Die folgende Tabelle ordnet die wichtigsten VoIP-Protokolle dem TCP/IP-Modell zu, das die IETF tatsächlich verwendet, wobei das ungefähre OSI-Äquivalent nur als Referenz dient.

| TCP/IP (IETF) Schicht | Protokolle | Ungefähres OSI-Äquivalent |
|---|---|---|
| Anwendung | SIP, H.323, MGCP, IAX2-Signalisierung; RTP/RTCP; codecs (G.711, G.729, Opus…) | Anwendung / Darstellung / Sitzung |
| Transport | UDP, TCP | Transport |
| Internet | IP (mit QoS wie DiffServ) | Netzwerk |
| Verbindung | Ethernet, PPP, Frame Relay… | Sicherung / Physikalisch |

QoS-Mechanismen wie DiffServ arbeiten auf der IP-Schicht, um Sprachpakete zu priorisieren und die Anrufqualität zu verbessern. Einige Protokollspezifika:

- **SIP** verwendet UDP oder TCP auf Port 5060 (TLS auf 5061) zur Übertragung der Signalisierung. Das Audio wird separat per RTP über einen konfigurierbaren UDP-Portbereich übertragen (das mit Asterisk ausgelieferte `rtp.conf` Beispiel verwendet 10000 bis 20000), kodiert mit einem codec wie G.711.
- **H.323** überträgt die Anrufsignalisierung über TCP (H.225-Anrufsignalisierung auf Port 1720), während der H.225-RAS-Kanal UDP auf Port 1719 verwendet; RTP transportiert das Audio.
- **IAX2** ist ungewöhnlich: Es multiplext sowohl Signalisierung als auch Medien über einen einzigen UDP-Port (4569), was die NAT- und Firewall-Traversal vereinfacht.


## Die Wahl des richtigen Protokolls

Angesichts der vielen verfügbaren Protokolle stellt sich die Frage, wie Sie das beste für Ihr Netzwerk auswählen können. In diesem Abschnitt beleuchten wir die Vor- und Nachteile der einzelnen Protokolle.

### SIP - Session Initiated Protocol

SIP ist ein offener Standard der Internet Engineering Task Force (IETF), der größtenteils in RFC 3261 definiert ist. Die meisten modernen VoIP-Anbieter nutzen SIP; tatsächlich entwickelt es sich zum populärsten VoIP-Standard. Die Stärke von SIP liegt darin, dass es ein IETF-basierter Standard ist. SIP ist im Vergleich zum älteren H.323 leichtgewichtig. Die größte Schwäche von SIP ist das NAT-Traversal – eine Herausforderung für die meisten SIP-VoIP-Anbieter. Die IETF hat SIP nicht mit dem Ziel der Abrechnung entwickelt, sondern für die offene Kommunikation zwischen Peers. Die Abrechnung ist jedoch meist ein wichtiges Anliegen für VoIP-Anbieter.

### IAX – Inter Asterisk eXchange

IAX ist ein offenes Protokoll, das ursprünglich von Digium (heute Sangoma) entwickelt wurde. IAX ist ein All-in-One-Protokoll, da es Signalisierung und Medien über denselben UDP-Port (4569) überträgt. Mark Spencer entwickelte IAX als binäres Protokoll zur Reduzierung der Bandbreite. Die Hauptstärke von IAX ist der geringere Bandbreitenverbrauch (es verwendet kein RTP); zudem ist es sehr einfach für NAT- und Firewall-Traversal, da es nur einen einzigen UDP-Port (4569) nutzt.

Hätte ein traditioneller PBX-Hersteller IAX entwickelt, hätte er das Protokoll wahrscheinlich als „die beste Erfindung seit es Eiscreme gibt“ vermarktet; in manchen Situationen kann IAX im trunk-Modus den Sprachbandbreitenverbrauch um ein Drittel senken. IAX2 (Version 2) wird in Asterisk 22 weiterhin über das Modul `chan_iax2` ausgeliefert und bleibt nützlich für Asterisk-zu-Asterisk-trunks, obwohl es als veraltet gilt; für neue Implementierungen werden SIP/PJSIP bevorzugt. IAX2 ist in [RFC 5456](https://datatracker.ietf.org/doc/html/rfc5456)(https://www.rfc-editor.org/rfc/rfc5456) (informativ) spezifiziert.

### MGCP – Media Gateway Control Protocol

MGCP ist ein Protokoll, das in Verbindung mit H.323, SIP und IAX verwendet wird. Sein größter Vorteil ist die Skalierbarkeit. Es wird im call agent anstatt in den Gateways konfiguriert. Dies vereinfacht den Konfigurationsprozess und ermöglicht eine zentralisierte Verwaltung. Die Asterisk-Implementierung ist jedoch nicht vollständig, und es scheint, dass es nur von wenigen Leuten genutzt wird.

### H.323

H.323 wird weitgehend im VoIP-Bereich eingesetzt. Es ist eines der ersten VoIP-Protokolle und ist essenziell für die Anbindung älterer VoIP-Infrastrukturen, die auf Gateways basieren. H.323 ist nach wie vor der Standard auf dem Gateway-Markt, obwohl der Markt langsam zu SIP migriert. Zu den Stärken von H.323 zählen die große Marktakzeptanz und die Reife. Die Schwächen von H.323 liegen in der Komplexität der Implementierung und den damit verbundenen Kosten der Standardisierungsgremien.

### Protokoll-Vergleichstabelle

Die folgende Tabelle fasst die Unterschiede zwischen den Sitzungsprotokollen zusammen.

| Protokoll | Standardisierungsgremium | Asterisk 22 Modul / Status | Verwendung für |
|----------|---------------|-----------------------------|----------|
| SIP | IETF-Standard | `chan_pjsip` (Kern; der einzige SIP-Treiber — `chan_sip` wurde in Asterisk 21 entfernt) | SIP-Telefone; Verbindung zu SIP-Dienstanbietern |
| IAX2 | RFC 5456 (informativ) | `chan_iax2` (Kern; weiterhin enthalten, gilt als veraltet) | Asterisk-zu-Asterisk-trunks; IAX2-Telefone; IAX-Dienstanbieter |
| H.323 | ITU-Standard | `chan_ooh323` (externes Community-Add-on, nicht im Basis-Build enthalten) | H.323-Telefone und Gateways (kann einen externen Gatekeeper nutzen, kann selbst keiner sein) |
| MGCP | IETF/ITU | `chan_mgcp` in Asterisk 21 entfernt — nicht mehr verfügbar | (veraltete MGCP-Telefone) |
| SCCP (Skinny) | Cisco proprietär | `chan_skinny` in Asterisk 21 entfernt — nicht mehr verfügbar | (veraltete Cisco-Telefone) |

## Ein endpoint pro Gerät

In Asterisk 22 modelliert der PJSIP-Stack jedes Telefon, jeden trunk oder jedes Gateway als ein einziges **endpoint**-Objekt in `pjsip.conf`. Ein endpoint tätigt und empfängt Anrufe; seine Anmeldedaten befinden sich in einem `auth`-Objekt, seine registrierte Adresse in einem `aor` und sein Netzwerkpfad in einem `transport`. Sie konfigurieren einen endpoint pro Gerät und fügen die benötigten Komponenten hinzu – es gibt keine getrennte "user"- oder "peer"-Rolle, über die man nachdenken müsste. (Das vollständige Objektmodell wird in *SIP & PJSIP in depth* behandelt.)

## Codecs und Codec-Übersetzung

Sie verwenden einen codec, um die Stimme von einer analogen Welle in ein digitales Signal umzuwandeln. Codecs unterscheiden sich voneinander in Aspekten wie Klangqualität, Kompressionsrate, Bandbreite und Rechenanforderungen. Dienste, Telefone und Gateways unterstützen in der Regel mehrere dieser Aspekte. Der codec G.729 ist sehr beliebt. Er ist nicht Teil des Standard-Asterisk 22-Builds; stattdessen wird er als externes Add-on-Modul (`codec_g729`) ausgeliefert, das Sie von Digium (jetzt Sangoma) herunterladen. Die `menuselect`-Quelle von Asterisk führt ihn mit `support_level=external` auf und merkt deutlich an: "Download the g729a codec from Digium. A license must be purchased for this codec." Mit anderen Worten: Die rechtmäßige Nutzung von G.729 erfordert eine erworbene Lizenz pro Kanal. (Eine Open-Source-Alternative, `bcg729`, existiert ebenfalls.)

![Pulse Code Modulation (PCM): Ein analoges 4000-Hz-Signal wird 8000 Mal pro Sekunde abgetastet (Nyquist-Theorem) und in einen digitalen 64-Kbps-Bitstrom kodiert.](../images/06-voip-network-fig04.png)

Asterisk 22 unterstützt (unter anderem) die folgenden Codecs:

- GSM: 13 Kbps
- iLBC: 13.3 Kbps
- ITU G.711 (ulaw/alaw): 64 Kbps — Standard-PSTN-Qualität; ulaw ist in Nordamerika verbreitet, alaw in Europa und Lateinamerika
- ITU G.722: 64 Kbps — Breitband (HD-Stimme), gute Qualität bei gleicher Bandbreite wie G.711
- ITU G.723.1: 5.3/6.3 Kbps
- ITU G.726: 16/24/32/40 Kbps
- ITU G.729: 8 Kbps — externes `codec_g729` Binärmodul, das von Digium/Sangoma heruntergeladen wird (`support_level=external`; für die Nutzung muss eine Lizenz erworben werden)
- Speex: 2.15 bis 44.2 Kbps
- LPC10: 2.4 Kbps
- **Opus**: 6–510 Kbps, variabel — moderner Breitband-/Fullband-codec; exzellente Qualität und Widerstandsfähigkeit gegen Paketverlust; wird als externes `codec_opus` Binärmodul bereitgestellt, das von Digium/Sangoma heruntergeladen wird (`support_level=external`; im Gegensatz zu G.729 ist kein Lizenzkauf vermerkt); empfohlen für WebRTC und moderne SIP-endpoints. (Open-Source-Build-Alternativen existieren auf GitHub.)

Darüber hinaus erlaubt Asterisk die Übersetzung zwischen Codecs. In einigen Fällen ist dies nicht möglich, wie etwa bei g723, das nur im Pass-thru-Modus unterstützt wird. Die Übersetzung von einem codec in einen anderen verbraucht viele CPU-Ressourcen. Vermeiden Sie dies daher nach Möglichkeit vollständig.

## Auswahl eines Codec

Die Auswahl eines Codec hängt von verschiedenen Faktoren ab, wie zum Beispiel:

- Tonqualität
- Lizenzkosten
- CPU-Verbrauch
- Bandbreitenanforderungen
- Verschleierung von Paketverlusten (Packet-loss concealment)
- Verfügbarkeit für Asterisk und Endgeräte

Die folgende Tabelle vergleicht die gängigsten Codecs. Die Qualität dieser Codecs wird als „toll“-Qualität betrachtet – mit anderen Worten, vergleichbar mit dem PSTN.

| Codec | G.711 | G.722 | Opus | G.729A | iLBC | GSM |
|---|---|---|---|---|---|---|
| Audioband | Schmal | Breit (HD) | Schmal–voll | Schmal | Schmal | Schmal |
| Bandbreite (Kbps) | 64 | 64 | 6–510 | 8 | 13.33 | 13 |
| Kosten/Kanal | Kostenlos | Kostenlos | Kostenlos | Lizenz¹ | Kostenlos | Kostenlos |
| Frame-erasure² | Keine | Niedrig | Exzellent | ~3% | ~5% | ~3% |
| CPU-Kosten | Sehr niedrig | Niedrig | Mod.–hoch | Hoch | Hoch | Niedrig |

Die Asterisk 22 Module sind: G.711 `codec_ulaw` / `codec_alaw` (Kern), G.722 `codec_g722` (Kern), Opus `codec_opus` (extern), G.729 `codec_g729` (extern), iLBC `codec_ilbc` (Kern) und GSM `codec_gsm` (Kern). Opus ist „Schmal–voll“, da es von Schmalband bis Vollband skaliert; seine Bandbreite (6–510 Kbps) ist variabel und seine Widerstandsfähigkeit gegen Frame-Erasure stammt aus integriertem FEC/PLC.

Die PSTN-Basislinie ist **G.711** — sie ist die Referenz für „toll“-Qualität und transkodiert kostenlos innerhalb von Asterisk. **G.722** liefert Breitband-Sprache (HD) bei denselben 64 Kbps und ist eine gute Wahl für LAN/interne Verbindungen. **Opus** ist der moderne Standard für WebRTC und fähige SIP endpoints: Er passt seine Bitrate an, verfügt über integrierte Vorwärtsfehlerkorrektur (FEC) und ist resistent gegen Paketverluste; er wird als externes `codec_opus` Binärpaket ausgeliefert (kostenloser Download). **G.729** bleibt nützlich für WAN trunks mit geringer Bandbreite, aber die rechtmäßige Nutzung erfordert entweder das lizenzierte `codec_g729` von Sangoma (kostenloser Download, pro-Kanal-Lizenz zur Nutzung erforderlich) oder die Open-Source-Implementierung **bcg729** als Alternative.

¹ Das `codec_g729` Binärpaket von Sangoma ist kostenlos herunterladbar, erfordert jedoch eine erworbene pro-Kanal-Lizenz für die rechtmäßige Nutzung. Das Open-Source-Modul `bcg729` ist eine lizenzfreie Alternative.

² Die Widerstandsfähigkeit gegen Frame-Erasure bezieht sich darauf, wie gut die wahrgenommene Qualität (MOS) bei Paketverlusten erhalten bleibt. Der genaue Übergangspunkt variiert je nach Paketierung und Netzwerkbedingungen; verwenden Sie diese Spalte für einen relativen Vergleich, nicht als präzisen Wert.

**Codec-Empfehlungen für Asterisk 22:**

- **G.711 (ulaw/alaw):** Zu verwenden für PSTN trunks und maximale Interoperabilität; keine Transkodierungskosten innerhalb von Asterisk.
- **G.729:** Nützlich für WAN trunks mit geringer Bandbreite; das `codec_g729` Modul von Sangoma ist kostenlos herunterladbar, erfordert jedoch eine erworbene pro-Kanal-Lizenz zur Nutzung.
- **G.722:** Gute Wahl für Breitband (HD-Sprache) bei LAN/internen extensions; gleiche Bandbreite wie G.711 bei besserer Qualität.
- **Opus:** Empfohlen für moderne endpoints, WebRTC-Clients und jede Bereitstellung, bei der das endpoint dies unterstützt. Adaptive Bitrate, exzellente Widerstandsfähigkeit gegen Paketverluste, frei verfügbar über das `codec_opus` Binärmodul von Sangoma.

## Overhead durch Protokoll-Header

Obwohl Codecs nur wenig Bandbreite beanspruchen, müssen wir den Overhead berücksichtigen, der durch Protokoll-Header wie Ethernet, IP, UDP und RTP entsteht. Daher hängt die tatsächlich verbrauchte Bandbreite von den verwendeten Headern ab. In einem Ethernet-Netzwerk ist der Bedarf höher als in einem PPP-Netzwerk, da der PPP-Header kürzer ist als der Ethernet-Header. Ein einzelnes G.729-Sprachpaket enthält beispielsweise nur 20 Bytes an Nutzdaten, ist aber in etwa 58 Bytes an Ethernet-, IP-, UDP- und RTP-Headern verpackt – somit dominieren die Header, nicht der Codec, die Bandbreite (siehe die Abbildung unten).

![Ein einzelnes G.729-Sprachpaket über Ethernet: 20 Bytes Nutzdaten verpackt in 58 Bytes Ethernet-, IP-, UDP- und RTP-Header – eine G.729-Konversation verbraucht 31,2 Kbps.]((../images/06-voip-network-fig05.png))

- Ethernet (Ethernet+IP+UDP+RTP+G.711) = 95,2 Kbps
- PPP (PPP+IP+UDP+RTP+G.711) = 82,4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.711) = 82,8 Kbps

Codec G.729 (8 Kbps)

- Ethernet (Ethernet+IP+UDP+RTP+G.729) = 31,2 Kbps
- PPP (PPP+IP+UDP+RTP+G.729) = 26,4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.729) = 26,8 Kbps

Sie können weitere Bandbreitenanforderungen einfach mit einem Online-VoIP-Bandbreitenrechner wie <https://www.voip.school/bandcalc/bandcalc.php> berechnen.


## Traffic Engineering

Ein Hauptaspekt bei der Konzeption von VoIP-Netzwerken ist die Dimensionierung der Anzahl der Leitungen und der erforderlichen Bandbreite zu einem bestimmten Ziel, wie etwa einer Außenstelle oder einem Dienstanbieter. Ebenso wichtig ist die Dimensionierung der Anzahl der gleichzeitigen Anrufe für Asterisk (der Hauptparameter für die Dimensionierung von Asterisk).

### Vereinfachungen

Die primäre und am häufigsten verwendete Vereinfachung besteht darin, die Anzahl der Anrufe nach Benutzertyp zu schätzen. Zum Beispiel:

- Geschäftliche PBXs (ein gleichzeitiger Anruf für jeweils fünf extensions)
- Privatnutzer (ein gleichzeitiger Anruf für jeweils sechzehn Benutzer)

Beispiel #1 Der Hauptsitz des Unternehmens verfügt über 120 extensions und zwei Niederlassungen – die erste mit 30 extensions und die zweite mit 15 extensions. Unser Ziel ist es, die Anzahl der E1 trunks im Hauptsitz sowie die für das Frame-Relay-Netzwerk erforderliche Bandbreite zu dimensionieren.

![Beispiel einer Netzwerktopologie (gleiche Stadt): Der Hauptsitz mit 120 extensions ist über T1-Leitungen mit dem PSTN verbunden sowie über eine Frame-Relay-Cloud mit Niederlassung #1 (30 extensions) und Niederlassung #2 (15 extensions).](images/network_topology.png)(../images/06-voip-network-fig06.png)

1a Anzahl der T1-Leitungen

- Gesamtzahl der extensions, die T1-Leitungen nutzen: 120+30+15=165 Leitungen
- Verwendung eines trunk für jeweils fünf extensions bei geschäftlicher Nutzung
- Gesamtzahl der Leitungen = 33 oder ungefähr 2xT1-Leitungen

1b Bandbreitenanforderungen Wir wählen den g.729 codec aufgrund der Bandbreitenanforderungen, der Klangqualität und des moderaten CPU-Verbrauchs.

Mit einem trunk für jeweils fünf extensions:

- Erforderliche Bandbreite für Niederlassung #1 (Frame-relay): 26.8*6=160.8 Kbps
- Erforderliche Bandbreite für Niederlassung #2 (Frame-relay): 26.8*3= 80.4 Kbps

### Erlang B-Methode

Wenn historische Daten vorliegen, können Sie den trunk wissenschaftlicher dimensionieren, anstatt Vereinfachungen vorzunehmen. Wir nutzen die Arbeit von Agner Karup Erlang (Copenhagen Telephone Company, 1909), der eine Formel zur Berechnung der Anzahl der Leitungen in einer trunk-Gruppe zwischen zwei Städten entwickelte.

Ein **Erlang** ist eine in der Telekommunikation gebräuchliche Einheit zur Verkehrsmessung; sie beschreibt das Verkehrsaufkommen während einer Stunde. Angenommen, es finden 20 Anrufe in einer Stunde statt, mit einer durchschnittlichen Gesprächsdauer von 5 Minuten:

- Gesprächsminuten in der Stunde: 20 × 5 = 100 Minuten
- Stunden an Verkehrsaufkommen innerhalb einer Stunde: 100 / 60 = **1.66 Erlangs**

Sie können diese Messwerte aus einem Anrufprotokoll (Call Logger) ablesen und sie verwenden, um Ihr Netzwerk zu entwerfen und die erforderliche Anzahl an Leitungen zu berechnen. Sobald die Anzahl der Leitungen bekannt ist, können Sie die Bandbreitenanforderungen berechnen.

**Erlang B** ist die am häufigsten verwendete Methode zur Berechnung der Anzahl der Leitungen in einer trunk-Gruppe. Sie geht davon aus, dass Anrufe zufällig eintreffen (eine Poisson-Verteilung) und dass blockierte Anrufe sofort verworfen werden. Sie erfordert die Kenntnis des **Busy Hour Traffic (BHT)**, den Sie aus einem Anrufprotokoll erhalten oder als Vereinfachung schätzen können: BHT = 17% der Anrufminuten eines Tages.

![Erlang B-Rechnerergebnisse: 5 Erlangs bei 1% Blockierung erfordern 11 Leitungen (Hauptsitz zu Niederlassung #1), und 2.83 Erlangs bei 1% Blockierung erfordern 8 Leitungen (Hauptsitz zu Niederlassung #2).](images/erlang_b_calc.png)(../images/06-voip-network-fig07.png)

Eine weitere wichtige Variable ist die Grade of Service (GoS), die die Wahrscheinlichkeit definiert, dass Anrufe aufgrund von Leitungsmangel blockiert werden. Sie können diesen Parameter festlegen, der üblicherweise 0.05 (5% verlorene Anrufe) oder 0.01 (1% verlorene Anrufe) beträgt. Beispiel #1: Unter Verwendung des gleichen Beispiels mit Hauptsitz und zwei Niederlassungen, das bereits in diesem Abschnitt eingeführt wurde, geben wir Ihnen einige Daten zu Verkehrsmustern. Aus dem Anrufprotokoll haben wir folgende Daten ermittelt: Daten aus dem Anrufprotokoll (Anrufminuten und BHT):

- Hauptsitz zu Niederlassung #1 = 2,000 Minuten, BHT = 300 Minuten
- Hauptsitz zu Niederlassung #2 = 1,000 Minuten, BHT = 170 Minuten
- Niederlassung #1 zu Niederlassung #2 = 0, BHT=0

Legen wir GoS=0.01 fest

- Hauptsitz zu Niederlassung #1 - BHT=300 Minuten/60 = 5 Erlangs
- Hauptsitz zu Niederlassung #2 – BHT=170 Minuten/60 = 2.83 Erlangs

Unter Verwendung eines Erlang-Rechners wie <https://www.erlang.com>

- Für den Hauptsitz zu Niederlassung #1 sind 11 Leitungen erforderlich.
- Für den Hauptsitz zu Niederlassung #2 sind 8 Leitungen erforderlich

1.b Erforderliche Bandbreite Wir verwenden ein WAN, in dem Paketverluste selten sind. Wir wählen den g729 codec aufgrund seiner guten Klangqualität und Datenkompression (8 Kbps).

Ausgewählter codec: g729 Datalink-Schicht: Frame-Relay

- Geschätzte Sprachbandbreite für Niederlassung #1: 26.8x11 = 294.8 Kbps
- Geschätzte Sprachbandbreite für Niederlassung #2: 26.8x8 = 214.40 Kbps

## Reduzierung der für VoIP benötigten Bandbreite

Es gibt drei Methoden, um die für VoIP-Anrufe benötigte Bandbreite zu reduzieren:

- RTP-Header-Kompression
- IAX-Trunking
- VoIP-Payload

### RTP-Header-Kompression

In Frame-Relay- und PPP-Netzwerken können Sie die RTP-Header-Kompression verwenden. Die RTP-Header-Kompression wurde in RFC 2508 definiert. Es handelt sich um einen IETF-Standard, der in verschiedenen Routern verfügbar ist. Seien Sie jedoch vorsichtig, da einige Router ein anderes Funktionsset erfordern, damit diese Ressource verfügbar ist. Die Auswirkungen der Verwendung von RTP-Header-Kompression sind fantastisch, da sie die benötigte Bandbreite in unserem Beispiel von 26.8 Kbps pro Sprachverbindung auf 11.2 Kbps reduziert – eine Verringerung um 58.2%!

### IAX2-Trunk-Modus

Wenn Sie zwei Asterisk-Server miteinander verbinden, können Sie das IAX2-Protokoll im Trunk-Modus verwenden. Diese revolutionäre Technologie benötigt keine speziellen Router und kann auf jede Art von Datenverbindung angewendet werden.

![IAX2-Trunk-Modus über Ethernet: Ein einzelner g.729-Anruf benötigt seinen vollständigen Header-Stack (31.2 Kbps), aber ein zweiter Anruf teilt sich diese Header und fügt nur einen kleinen IAX2-Miniframe hinzu, was durchschnittlich etwa 9.6 Kbps zusätzliche Bandbreite pro weiterem Anruf bedeutet.](../images/06-voip-network-fig08.png)

Der IAX2-Trunk-Modus verwendet ab dem zweiten Anruf dieselben Header wieder. Bei Verwendung von g729 in einer PPP-Verbindung verbraucht der erste Anruf 30 Kbps Bandbreite, während der zweite Anruf denselben Header wie der erste verwendet und die notwendige Bandbreite für den zusätzlichen Anruf auf 9.6 Kbps reduziert. Wir können die benötigte Bandbreite im Trunk-Modus wie folgt berechnen: Zweig #1 (11 Anrufe) Bandbreite = 31.2 + (11-1)* 9.6 Kbps = 127.2 Kbps Zweig #2 (8 Anrufe) Bandbreite = 31.2 + (8-1)* 9.6 Kbps = 98.4 Kbps Der erste Anruf verbraucht 31.2 Kbps, der nächste 9.6 und so weiter.

### Erhöhung der Voice-Payload

Diese Methode ist sehr verbreitet, wenn VoIP-Gateways über das Internet genutzt werden. Bei Verwendung einer größeren Payload opfern Sie Latenz zugunsten einer reduzierten Bandbreite. Sie können die RTP-Paketierung ändern, indem Sie die Frame-Größe in der allow-Anweisung an den codec anhängen.

![Erhöhung der Voice-Payload: Das Packen von 60 Bytes g.729-Payload in ein Paket (statt 20) verteilt die 58 Bytes an Headern auf mehr Sprachdaten, wodurch die Bandbreite auf etwa 16.05 Kbps pro Anruf sinkt, auf Kosten einer erhöhten Latenz.](../images/06-voip-network-fig09.png)

Beispiel:

```
allow=ulaw:30
```

Die Zahl nach dem Doppelpunkt ist das Paketierungsintervall in Millisekunden – wie viel Sprache in jedem RTP-Paket transportiert wird. Ein größerer Wert verteilt den festen Header-Overhead auf mehr Audiodaten (weniger Bandbreite) auf Kosten einer erhöhten Latenz. Jeder codec hat seine eigene minimale, maximale und standardmäßige Frame-Größe; G.711 (`ulaw`/`alaw`) beispielsweise hat standardmäßig 20 ms.

## Zusammenfassung

In diesem Kapitel haben Sie gelernt, dass Asterisk VoIP mithilfe von Channels verarbeitet. Es unterstützt SIP (über `chan_pjsip` in Asterisk 22) und IAX2; H.323 ist nur über das Community-Add-on `ooh323` verfügbar, und die älteren MGCP- und SCCP (Skinny)-Channels sind nicht mehr Teil eines Standard-Asterisk 22-Builds. Sie haben die verschiedenen Signalisierungsprotokolle und Codecs für VoIP-Channels verglichen und gelernt, wie man diese auswählt. IAX2 ist bandbreiteneffizienter und kann NAT problemlos durchqueren. SIP/PJSIP ist das von Drittanbietern für Telefone und Gateways am besten unterstützte Protokoll und der einzige SIP-Channel-Treiber in Asterisk 22. Das H.323-Protokoll ist das älteste und sollte für die Verbindung mit älteren VoIP-Infrastrukturen verwendet werden. Im Abschnitt zum Traffic Engineering haben wir gelernt, wie man ein VoIP-Netzwerk entwirft und dimensioniert.

## Quiz

1. Welche der folgenden Punkte sind Vorteile von VoIP, die in diesem Kapitel beschrieben werden (alle zutreffenden auswählen)?
   - A. Konvergenz von Daten- und Sprachnetzwerken zur Kostensenkung
   - B. Geringere Infrastrukturkosten für Hinzufügungen, Entfernungen und Änderungen
   - C. Offene Standards, die Sie von einem einzelnen Anbieter unabhängig machen
   - D. Einfachere und kostengünstigere Computer Telephony Integration
   - E. Garantierte niedrigere Gesprächsgebühren pro Minute als bei jedem Telefonanbieter
2. Konvergenz ist die Integration von Sprache, Daten und Video in einem einzigen Netzwerk; ihr Hauptvorteil ist die Kostensenkung bei der Implementierung und Wartung getrennter Netzwerke.
   - A. Falsch
   - B. Wahr
3. Asterisk behandelt jedes VoIP-Protokoll als einen Kanal und kann jeden Kanaltyp mit jedem anderen verbinden, wobei bei Bedarf eine Transkodierung zwischen codecs erfolgt.
   - A. Falsch
   - B. Wahr
4. In Asterisk 22 wird SIP von welchem Kanaltreiber gehandhabt?
   - A. chan_sip
   - B. chan_pjsip
   - C. chan_skinny
   - D. chan_mgcp
5. Im TCP/IP (IETF)-Modell, auf dem SIP gemäß RFC 3261 tatsächlich definiert ist, arbeiten die Signalisierungsprotokolle SIP, H.323 und IAX2 auf der ___ Schicht.
   - A. Darstellungsschicht (Presentation)
   - B. Anwendungsschicht (Application)
   - C. Bitübertragungsschicht (Physical)
   - D. Sitzungsschicht (Session)
   - E. Sicherungsschicht (Data link)
6. SIP ist das am weitesten verbreitete Protokoll für IP-Telefone und ein offener Standard, der weitgehend von der IETF in RFC 3261 definiert wurde.
   - A. Falsch
   - B. Wahr
7. IAX2 überträgt sowohl Signalisierung als auch Medien über einen einzigen UDP-Port, was es effizient und einfach macht, NAT zu durchqueren. Welchen UDP-Port verwendet IAX2?
   - A. 5060
   - B. 1720
   - C. 4569
   - D. 5061
8. IAX wurde ursprünglich von Digium (jetzt Sangoma) entwickelt. Trotz begrenzter Verbreitung bei Telefonherstellern ist IAX hervorragend geeignet, wenn Sie (alle zutreffenden auswählen):
   - A. Die Bandbreitennutzung reduzieren müssen (es verwendet kein RTP)
   - B. Ein Videomedienformat benötigen
   - C. Einfache NAT- und Firewall-Durchquerung benötigen
   - D. Den trunk-Modus benötigen, um viele Asterisk-zu-Asterisk-Anrufe zu kombinieren und den Header-Overhead zu amortisieren
9. In Asterisk 22 wird ein Gerät als ein einzelnes PJSIP `endpoint` Objekt konfiguriert, das sowohl Anrufe tätigt als auch empfängt — es gibt keine getrennte "user"- oder "peer"-Rolle.
   - A. Falsch
   - B. Wahr
10. Bezüglich codecs in Asterisk 22, wählen Sie alle zutreffenden Aussagen aus:
    - A. G.711 entspricht PCM und verbraucht 64 Kbps Bandbreite.
    - B. Das codec_g729-Modul von Sangoma kann kostenlos heruntergeladen werden, aber die rechtmäßige Nutzung erfordert eine gekaufte Lizenz pro Kanal.
    - C. GSM ist beliebt, weil es etwa 13 Kbps verbraucht und keine Lizenz benötigt.
    - D. G.711 u-law ist in Nordamerika üblich, während a-law in Europa und Lateinamerika verbreitet ist.
    - E. G.729 ist leichtgewichtig und verbraucht im Vergleich zu G.711 nur sehr wenige CPU-Ressourcen zum Enkodieren und Dekodieren.

**Antworten:** 1 — A, B, C, D · 2 — B · 3 — B · 4 — B · 5 — B (Application — SIP ist ein Protokoll der Anwendungsschicht im TCP/IP-Modell, das die IETF verwendet) · 6 — B · 7 — C · 8 — A, C, D · 9 — B · 10 — A, B, C, D
