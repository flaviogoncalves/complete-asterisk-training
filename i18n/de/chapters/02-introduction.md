# Einführung in Asterisk PBX

Die Popularität von sofort einsatzbereiten Distributionen wie FreePBX und Issabel ist in letzter Zeit gewachsen. In diesem Buch behandeln wir das klassische Asterisk, welches die Grundlage für das Verständnis dieser Distributionen bildet. Asterisk PBX ist eine Open-Source-Software, die in der Lage ist, einen gewöhnlichen PC in eine leistungsstarke Multiprotokoll-PBX zu verwandeln. In diesem Kapitel lernen wir die Möglichkeiten dieser neuen Technologie und ihre grundlegende Architektur kennen.

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Zu erklären, was Asterisk ist und was es tut;
- Die Rolle von Digium™ und dessen Nachfolger Sangoma zu beschreiben;
- Die grundlegende Architektur von Asterisk und seine Komponenten zu erkennen;
- Auf verschiedene Einsatzszenarien hinzuweisen; und
- Informations- und Hilfsquellen zu identifizieren.

## Was ist Asterisk

Asterisk ist eine Open-Source-PBX-Software, die einen gewöhnlichen Computer in eine voll ausgestattete PBX für Privatanwender, Unternehmen, VoIP-Dienstanbieter und Telefongesellschaften verwandelt. Asterisk ist sowohl eine Open-Source-Community als auch ein Projekt, das von Sangoma Technologies (die 2018 Digium übernahmen) gesponsert wird. Es steht Ihnen frei, Asterisk zu nutzen und an Ihre Bedürfnisse anzupassen. Asterisk ermöglicht eine Echtzeit-Konnektivität zwischen PSTN- und VoIP-Netzwerken. Da Asterisk weit mehr als eine PBX ist, erhalten Sie nicht nur ein außergewöhnliches Upgrade für Ihre bestehende PBX, sondern können auch neue Dinge in der Telefonie umsetzen, wie zum Beispiel:

- Verbindung von Mitarbeitern im Homeoffice mit einer Office-PBX über Breitband-Internet;
- Verbindung mehrerer Standorte an verschiedenen Orten über ein IP-Netzwerk, ein privates Netzwerk oder sogar über das Internet selbst;
- Bereitstellung einer in das Web und E-Mail integrierten voicemail für Ihre Mitarbeiter;
- Entwicklung von Anwendungen wie IVRs, die Verbindungen zu Ihrem Bestellsystem oder anderen Anwendungen ermöglichen;
- Zugriff für reisende Benutzer auf die Firmen-PBX von überall aus mit einer einfachen Breitband- oder VPN-Verbindung; und
- vieles mehr....

Asterisk umfasst mehrere fortschrittliche Ressourcen, die zuvor nur in High-End-Systemen zu finden waren, wie zum Beispiel:

- Musik für Kunden in der Warteschleife, mit Unterstützung für Media-Streaming und MP3-Dateien;
- Call queues, bei denen ein Team von Agenten Anrufe entgegennehmen und Warteschlangen überwachen kann;
- Integration mit Text-to-Speech und Spracherkennung;
- Detaillierte Aufzeichnungen, die sowohl in Textdateien als auch in SQL-Datenbanken übertragen werden; und
- PSTN-Konnektivität über sowohl digitale als auch analoge Leitungen.

## Was ist AsteriskNOW (historisch) und FreePBX

Asterisk in seiner reinsten Form, auch bekannt als „classic asterisk“ (Bezeichnung im Debian-Paket), wird eher als Entwicklungswerkzeug denn als fertiges Produkt an sich betrachtet. AsteriskNOW war eine Initiative, um Asterisk in eine Soft-Appliance zu verwandeln. Die Distribution enthielt CentOS als Betriebssystem und FreePBX als grafische Oberfläche. AsteriskNOW wurde inzwischen eingestellt.

Heute ist die standardmäßige schlüsselfertige Asterisk-Distribution **FreePBX** (gepflegt von Sangoma), die Asterisk mit einer webbasierten Administrations-GUI und einem Modul-Ökosystem bündelt. FreePBX ist unter der GPL lizenziert und kann frei von www.freepbx.org heruntergeladen werden. Für kommerzielle Implementierungen bietet Sangoma zudem die **FreePBX Distro** (ein vollständiges Linux-Image) sowie das kommerzielle Produkt **PBXact** an.

## Rolle von Digium™ und Sangoma

Digium, ein Unternehmen mit Sitz in Huntsville, Alabama, war seit seiner Gründung im Jahr 1999 der Schöpfer und Hauptentwickler von Asterisk. Neben der Rolle als Hauptsponsor der Asterisk-Entwicklung produzierte Digium Telefonie-Schnittstellenkarten und andere Hardware für Asterisk PBXs und schuf kommerzielle Produkte wie Switchvox (das auf den KMU-Markt ausgerichtet ist). Im Jahr 2018 wurde Digium von **Sangoma Technologies** übernommen, einem kanadischen Unternehmen für Unified Communications. Seit der Übernahme sponsert Sangoma weiterhin die Asterisk-Entwicklung und fungiert als dessen Hauptverwalter, wobei das Open-Source-Projekt unter www.asterisk.org gepflegt wird.

Historisch gesehen bot Digium Asterisk unter drei Arten von Lizenzvereinbarungen an:

- General Public License (GPL) Asterisk. Dies ist die am häufigsten verwendete Version. Sie enthält alle Funktionen und kann gemäß den Bedingungen der GPL-Lizenz kostenlos genutzt und modifiziert werden.
- Asterisk Business Edition war eine kommerzielle Version von Asterisk. Einige Unternehmen nutzten die Business Edition, weil sie die GPL-Lizenz nicht wollten oder nicht nutzen konnten – meist, weil sie ihren Quellcode nicht zusammen mit Asterisk veröffentlichen wollten. **Hinweis:** Die Asterisk Business Edition wurde eingestellt; heute wird Asterisk ausschließlich unter der GPL vertrieben.
- Asterisk OEM-Lizenzierung. Nachdem Digium den Einzelhandelsverkauf der Asterisk Business Edition eingestellt hatte, lizenzierte es diese kommerzielle Edition weiterhin an OEM-Kunden – Gerätehersteller, die proprietäre Produkte auf Basis von Asterisk entwickeln wollten, ohne ihren eigenen Quellcode unter der GPL veröffentlichen zu müssen.

### Das Zapata-Projekt und seine Beziehung zu Asterisk

Das Zapata-Projekt wurde von Jim Dixon entwickelt, der auch für das revolutionäre Hardware-Design verantwortlich war, das mit Asterisk verwendet wird. Die Hardware ist ebenfalls Open-Source; daher kann sie von jedem Unternehmen verwendet werden, und heute produzieren mehrere Hersteller Karten, die mit dieser Architektur kompatibel sind.

Das Zapata-Projekt brachte eine Architektur namens Zaptel hervor, die später in DAHDI (Digium/Asterisk Hardware Device Interface) umbenannt wurde. Einer der Hauptvorteile dieser Architektur ist die Möglichkeit, die PC-CPU zur Verarbeitung von Media-Streaming, Echokompensation und Transcoding zu nutzen. Im Gegensatz dazu verwenden die meisten existierenden Karten digitale Signalprozessoren (DSP), um diese Aufgaben auszuführen. Die Nutzung der PC-CPU anstelle dedizierter DSPs senkt den Preis der Karte drastisch. Somit sind diese Karten deutlich günstiger als zuvor erhältliche Schnittstellen anderer Hersteller. Andererseits benötigen diese Karten viel CPU-Leistung; eine Fehlbelastung der PC-CPU kann die Sprachqualität erheblich beeinträchtigen. Kürzlich hat Digium eine Koprozessorkarte auf den Markt gebracht, die DSPs zum Kodieren und Dekodieren von G.729 und G.723 verwendet, was eine bessere Skalierbarkeit für eine große Anzahl von Kanälen ermöglicht.

## Warum Asterisk?

Ich erinnere mich an meinen ersten Kontakt mit Asterisk. Normalerweise ist die erste Reaktion auf etwas Neues – besonders auf etwas, das mit dem konkurriert, was man bereits kennt – Ablehnung! Genau das passierte im Jahr 2003. Asterisk konkurrierte mit einer Lösung, die ich gerade einem Kunden verkaufte (4 E1 VoIP Gateway), und es war zehnmal günstiger als das, was ich für die Lösung berechnete, die ich bereits kannte. Dieser unverhältnismäßige Preis veranlasste mich dazu, Asterisk zu studieren, um potenzielle Fallstricke und Nachteile zu identifizieren. Ich stellte zum Beispiel fest, dass die PC-CPU zu dieser Zeit keine 120 gleichzeitigen g.729-Sitzungen unterstützen würde; am Ende des Tages gewann ich das Angebot mit meiner Gateway-Lösung.

Diese Übung führte mich jedoch zu der Entdeckung, dass Asterisk eine Vielzahl sehr teurer Probleme für meinen Kundenstamm lösen konnte. Wir hatten Probleme mit teuren Angeboten für IVR, Unified Messaging, Anrufaufzeichnung und Dialer; bei entsprechender Dimensionierung konnten die CPU-Probleme umgangen werden. Tatsächlich wurde Asterisk in nur drei Jahren zum Flaggschiff-Produkt meines Unternehmens (ich entschied mich sogar, ein weiteres Unternehmen nur für das Asterisk-Geschäft zu gründen). Meiner Meinung nach ist Asterisk eine Revolution in der Telekommunikation, die für die IP-Telefonie das darstellt, was Apache für Webdienste bedeutet.

### Extreme Kostensenkung

Wenn man eine traditionelle PBX mit Asterisk in Bezug auf digitale Schnittstellen und Telefone vergleicht, ist Asterisk etwas günstiger als diese PBXs. Asterisk zahlt sich jedoch erst richtig aus, wenn man erweiterte Funktionen wie voicemail, ACD, IVR und CTI hinzufügt. Mit diesen erweiterten Funktionen wird Asterisk deutlich günstiger als traditionelle PBXs. Tatsächlich ist der Vergleich von Asterisk PBXs mit analogen Low-End-PBXs unfair, da Asterisk so viele Funktionen bietet, die in analogen Low-End-Systemen nicht verfügbar sind.

### Kontrolle und Unabhängigkeit des Telefonsystems

Einer der am häufigsten genannten Vorteile von Asterisk durch Kunden ist die Unabhängigkeit, die es bietet. Einige der heutigen Hersteller geben dem Kunden nicht einmal das Systempasswort oder die Konfigurationsdokumentation. Mit dem „Do-it-yourself“-Ansatz von Asterisk erreicht der Benutzer völlige Freiheit; als Bonus hat der Benutzer Zugriff auf eine Standardschnittstelle.

### Einfache und schnelle Entwicklungsumgebung

Asterisk kann mithilfe von Skriptsprachen wie PHP und Perl mit AMI und AGI Schnittstellen erweitert werden. Asterisk ist Open-Source und der Quellcode kann vom Benutzer modifiziert werden. Der Quellcode ist größtenteils in der Programmiersprache ANSI C geschrieben.

### Funktionsreich

Asterisk verfügt über mehrere Funktionen, die in traditionellen PBXs entweder nicht vorhanden oder optional sind (z. B. voicemail, CTI, ACD, IVR, integrierte Warteschleifenmusik und Aufzeichnung). Die Kosten für diese Funktionen übersteigen bei einigen Plattformen den Preis der Plattform selbst.

### Dynamische Inhalte auf dem Telefon

Asterisk wird in der Sprache C und anderen Sprachen programmiert, die in der heutigen Entwicklungsumgebung üblich sind. Die Möglichkeit, dynamische Inhalte bereitzustellen, ist praktisch unbegrenzt.

### Flexibler und leistungsstarker dialplan

Ein weiterer Durchbruch von Asterisk ist sein leistungsstarker dialplan. In traditionellen PBXs sind selbst einfache Funktionen wie Least Cost Routing (LCR) entweder nicht machbar oder optional. Mit Asterisk ist die Wahl der besten Route einfach und sauber.

### Open-Source auf Linux

Eines der größten Merkmale von Asterisk ist seine Community. Es stehen verschiedene Ressourcen zur Verfügung, darunter die offizielle Asterisk-Dokumentation (docs.asterisk.org), das von der Community gepflegte VoIP-Info Wiki (www.voip-info.org <http://www.voip-info.org>), E-Mail-Verteilerlisten und Foren. Da Asterisk immer häufiger eingesetzt wird, werden Fehler schnell gefunden und behoben. Mit einer großen Benutzerbasis und einem aktiven Entwicklungsteam gehört Asterisk zu den am weitesten getesteten PBX-Plattformen der Welt, was dazu beiträgt, die Codebasis stabil und ausgereift zu halten.

### Einschränkungen der Asterisk-Architektur

Einige Einschränkungen in Asterisk beruhen auf der Verwendung des Zapata-Telefoniedesigns. Bei diesem Design verwendet Asterisk die PC-CPU zur Verarbeitung von Sprachkanälen anstelle von dedizierten digitalen Signalprozessoren (DSPs), die in anderen Plattformen üblich sind. Obwohl dies eine enorme Kostensenkung bei der Hardwareschnittstelle ermöglicht, wird das System von der PC-CPU abhängig. Meine Empfehlung ist, Asterisk auf einer dedizierten Maschine zu betreiben und bei der Hardwaredimensionierung konservativ zu sein. Sie können Asterisk auch in einem separaten VLAN verwenden, um übermäßige Broadcasts zu vermeiden, die die CPU belasten (Broadcast-Stürme, die durch Schleifen oder Viren verursacht werden). Einige neuere Schnittstellenkarten verschiedener Hersteller enthalten mittlerweile DSPs zur Verarbeitung von Echounterdrückung, codecs und anderen Funktionen, was Asterisk noch besser machen wird.

## Hauptsächliche Einwände gegen Asterisk PBX

Es ist üblich, Einwände gegen die Einführung von Asterisk zu hören, auf die wir hier eingehen werden.

### Der Marktanteil von Asterisk ist zu gering

Der Marktanteil wird üblicherweise an der Anzahl der verkauften PBX-Systeme gemessen. Diese Statistiken werden im Allgemeinen von den größten Distributoren erhoben. Asterisk ist freie Software, die heruntergeladen und bereitgestellt werden kann, ohne dass ein Verkauf registriert wird, weshalb es in diesen Zahlen systematisch untererfasst wird. Dennoch treibt Asterisk weltweit eine sehr große installierte Basis an — von Büro-PBX-Systemen auf einem einzelnen Server bis hin zu großen Carrier- und Contact-Center-Bereitstellungen — und bleibt die dominierende Engine hinter dem Open-Source-PBX-Ökosystem (einschließlich schlüsselfertiger Distributionen wie FreePBX).

### Wenn es kostenlos ist, wie überlebt der Hersteller?

Tatsächlich gibt es keinen Open-Source-Softwarehersteller im traditionellen Sinne. Digium entwickelte Asterisk seit 1999 und finanzierte sich durch den Verkauf von Telefonie-Schnittstellenkarten, kommerziellen PBX-Produkten wie Switchvox und zugehöriger Software. Im Jahr 2018 erwarb Sangoma Technologies Digium. Sangoma finanziert weiterhin die Asterisk-Entwicklung und generiert Einnahmen durch kommerzielle Produkte (kommerzielle FreePBX-Module, PBXact, Switchvox), Hardwareverkäufe und professionelle Dienstleistungen.

### Es ist schwer, technischen Support zu finden!

Sangoma bietet kommerziellen technischen Support für Asterisk über sein Partner-Ökosystem und direkt über seine Produktangebote an. Ein globales Netzwerk zertifizierter Fachleute bietet First-Line-Support und professionelle Dienstleistungen. Der Community-Support bleibt über die Asterisk-Foren und Mailinglisten unter www.asterisk.org aktiv.

### Unterstützt Asterisk mehr als 200 extensions?

Ja, absolut. Ein einzelner, gut dimensionierter Asterisk-Server kann eine große Anzahl von extensions verarbeiten, und Asterisk skaliert weiter, indem Benutzer über mehrere Server mit Load Balancing und Failover verteilt werden, was große standortübergreifende Bereitstellungen ermöglicht.

### Nur „Geeks“ sind in der Lage, Asterisk zu installieren

Mit FreePBX (als eigenständige Distribution von Sangoma erhältlich) sind selbst Fachleute mit begrenzten Linux-Kenntnissen in der Lage, eine PBX mittlerer Komplexität zu installieren und zu konfigurieren. Mit Hilfe einer GUI ist es möglich, eine komplette PBX in nur wenigen Stunden zu konfigurieren.

### Was passiert, wenn der Server ausfällt?

Einer der Hauptvorteile von Asterisk ist seine Fähigkeit, in fehlertoleranten Systemen zu laufen. Es ist relativ einfach und kostengünstig, zwei Server parallel zu betreiben. Ich fordere Sie heraus, dies mit einer herkömmlichen PBX zu versuchen!

### Unser Unternehmen verwendet keine Open-Source-Software

Ihr Unternehmen verwendet wahrscheinlich Open-Source-Software, ohne es überhaupt zu merken. Mehrere Appliances verwenden Linux als Betriebssystem. Darüber hinaus sind kommerzieller Support und verwaltete Bereitstellungen von Sangoma und seinem zertifizierten Partnernetzwerk verfügbar.

### Die Verwendung der PC-CPU zur Verarbeitung von Signalisierung und Medien wird nicht empfohlen

Asterisk verwendet die CPU des Servers, um Signalisierung und Medien für Sprachkanäle zu verarbeiten, anstatt dedizierte DSPs zu haben. Obwohl dies eine Kostenreduzierung um das bis zu Fünffache ermöglicht, macht es das System von der Leistung der Haupt-CPU abhängig. Bei korrekter Dimensionierung ist Asterisk in der Lage, große Volumina zu bewältigen. Wenn Sie die Haupt-CPU dennoch von diesen Aufgaben entlasten möchten, können Sie auch Hardware-Echokompensation und sogar Transcoder-Karten verwenden, wie die Sangoma (ehemals Digium) TC400B, die auf DSPs basiert.

## Asterisk Architektur

Dieser Abschnitt erläutert die Funktionsweise der Architektur von Asterisk. Die folgende Abbildung zeigt die grundlegende Asterisk Architektur. Im Anschluss werden wir architekturbezogene Konzepte erläutern, einschließlich Channels, Codecs und Anwendungen.

![Die Asterisk Architektur](../images/01-introduction-fig01.png)

### Channels

Ein Channel ist das Äquivalent zu einer Telefonleitung, jedoch in einem digitalen Format. Er besteht normalerweise aus einem analogen oder digitalen (TDM) Signalisierungssystem oder einer Kombination aus Codec und Signalisierungsprotokoll (z. B. SIP-GSM, IAX-uLaw). Ursprünglich waren alle Telefonieverbindungen analog und anfällig für Echo und Rauschen. Später wurden die meisten Systeme auf digitale Systeme umgestellt, wobei der analoge Ton in den meisten Fällen mittels Pulscodemodulation (PCM) in ein digitales Format umgewandelt wurde. Dieses Format ermöglicht die Sprachübertragung mit 64 Kilobit pro Sekunde ohne Komprimierung.

Channels zur Anbindung an das Public Switched Telephone Network (PSTN):

- `chan_dahdi`: analoge (FXO/FXS) und digitale (E1/T1/PRI) TDM-Karten von Sangoma (ehemals Digium), Xorcom und anderen. Separat gegen DAHDI gebaut — siehe das Kapitel *Legacy channels*.

Channels zur Anbindung an Voice over IP:

- `chan_pjsip`: SIP — der primäre und einzige SIP-Channel-Treiber in Asterisk 22 LTS. Dial-String: `PJSIP/endpoint_name`. (**Hinweis:** der alte `chan_sip` wurde in Asterisk 21 entfernt und existiert in Asterisk 22 nicht mehr. Siehe *Building your first PBX with PJSIP* für die Konfiguration.)
- `chan_iax2`: das IAX2-Protokoll — wird in Asterisk 22 noch mitgeliefert, ist aber veraltet (Legacy); SIP/PJSIP wird für neue Implementierungen bevorzugt. Dial-String: `IAX2/peer`.
- `chan_unistim`: Nortel/Avaya UNISTIM-Telefone. Immer noch verfügbar (erweiterter Support), aber selten genutzt.

Die älteren VoIP-Channels sind nicht mehr Teil eines Standard-Asterisk 22-Builds: `chan_h323` (H.323) überlebt nur als Community-Add-on `ooh323`, und `chan_mgcp` (MGCP) sowie `chan_skinny` (Cisco SCCP) wurden als veraltet markiert und aus dem modernen Channel-Set entfernt. Wenn Sie mit diesen Protokollen zusammenarbeiten müssen, ist ein Gateway vor Asterisk der übliche Ansatz.

Sonstige Channels:

- **Local**: ein Pseudo-Channel (im Kern integriert), der in den dialplan in einem anderen context zurückführt — nützlich für rekursives Routing und um einen Anruf an mehrere Ziele zu verteilen. Dial-String: `Local/extension@context`.

### Codec und Codec-Übersetzung

Wir versuchen normalerweise, so viele Sprachverbindungen wie möglich in einem Datennetzwerk unterzubringen. Codecs ermöglichen neue Funktionen in der digitalen Sprachübertragung, einschließlich der Komprimierung, die eines der wichtigsten Merkmale ist, da sie Komprimierungsraten von mehr als 8 zu 1 ermöglicht. Viele Codecs definieren auch Funktionen wie Voice Activity Detection (Stilleunterdrückung), Packet Loss Concealment und Comfort Noise Generation, obwohl Asterisk selbst kein Comfort Noise erzeugt oder eine Stilleunterdrückung durchführt. Für Asterisk sind verschiedene Codecs verfügbar, die transparent ineinander übersetzt werden können. Intern verwendet Asterisk slinear als Stream-Format, wenn es von einem Codec in einen anderen konvertieren muss. Einige Codecs in Asterisk werden nur im Pass-Through-Modus unterstützt; diese Codecs können nicht übersetzt werden. Um zu überprüfen, welche Codecs auf Ihrem System installiert sind, können Sie den Konsolenbefehl verwenden:

```
CLI>core show translation
```

Die folgenden Codecs werden unterstützt:

- G.711 ulaw (USA) - (64 Kbps).
- G.711 alaw (Europa) - (64 Kbps).
- G.722 (High Definition) – (64 Kbps)
- G.723.1 - Nur Pass-Through-Modus
- G.726 - (16/24/32/40kbps)
- G.729 - Binäres Codec-Modul, vertrieben von Sangoma; der Download ist kostenlos, aber die rechtmäßige Nutzung erfordert den Erwerb einer Lizenz pro Channel (8Kbps)
- GSM - (12-13 Kbps)
- iLBC - (15 Kbps)
- LPC10 - (2.4 Kbps)
- Speex - (2.15-44.2 Kbps)
- Opus - (6-510 Kbps)

### Protokolle

Das Senden von Daten von einem Telefon zum anderen sollte einfach sein, vorausgesetzt, die Daten finden ihren Weg zum anderen Telefon von selbst. Leider ist dies nicht der Fall, und ein Signalisierungsprotokoll ist erforderlich, um Verbindungen zwischen Telefonen herzustellen, Endgeräte zu entdecken und Telefoniesignalisierung zu implementieren. SIP ist das dominierende Signalisierungsprotokoll in modernen Implementierungen und der einzige SIP-Channel, der in Asterisk 22 LTS verfügbar ist (via chan_pjsip). IAX2 ist weiterhin verfügbar, gilt aber als veraltet (Legacy). Asterisk unterstützt die folgenden Protokolle.

- SIP — via `chan_pjsip`
- IAX2 — veraltet (Legacy), wird in Asterisk 22 noch mitgeliefert
- UNISTIM — Nortel/Avaya-Telefone (erweiterter Support)
- H.323, MGCP und SCCP (Cisco Skinny) — veraltete Protokolle, die nicht mehr in einem Standard-Asterisk 22-Build enthalten sind (H.323 nur über das Community-Add-on `ooh323`)

### Anwendungen

Um Anrufe von einem Telefon zum anderen zu überbrücken, wird die Anwendung dial() verwendet. Die meisten Asterisk-Funktionen (z. B. voicemail und Konferenzen) sind als Anwendungen implementiert. Sie können die verfügbaren Asterisk-Anwendungen mit dem Konsolenbefehl core show applications anzeigen.

```
CLI>core show applications
```

Sie können Anwendungen aus Asterisk-Add-ons, von Drittanbietern oder sogar solche, die Sie selbst entwickeln, hinzufügen.

## Überblick über ein Asterisk-System

Asterisk ist eine Open-Source-PBX, die wie eine hybride PBX fungiert und Technologien wie TDM und IP-Telefonie integriert. Asterisk ist bereit für die Implementierung von Funktionen wie interactive voice response (IVR) und automatic call distribution (ACD); darüber hinaus ist es, wie bereits erwähnt, offen für die Entwicklung neuer Anwendungen. Diese Abbildung zeigt, wie Asterisk über analoge und digitale Schnittstellen eine Verbindung zum PSTN und zu bestehenden PBXs herstellt sowie analoge und IP-Telefone unterstützt. Es kann als SoftSwitch, Media Gateway, voicemail, Audio-Konferenzsystem fungieren und verfügt zudem über eine integrierte Wartemusik (music on hold).

![Überblick über ein Asterisk-System](../images/01-introduction-fig02.png)

## Vergleich der alten und der neuen Welt

Im alten SoftSwitch-Modell wurden alle Komponenten separat verkauft, was bedeutete, dass man jede Komponente einzeln erwerben und dann in die PBX- oder SoftSwitch-Umgebung integrieren musste. Die Kosten und Risiken waren hoch und die meisten Geräte waren proprietär.

![Die alte Welt: Komponenten wurden separat gekauft und integriert](../images/01-introduction-fig03.png)

### Telefonie mit Asterisk

Alle Funktionen sind in der Asterisk-Plattform integriert, entweder in derselben oder in verschiedenen Boxen, je nach Dimensionierung, und alle sind unter der GPL lizenziert. Manchmal ist es einfacher, Asterisk zu installieren, als einige der gängigen IP-PBXs zu lizenzieren.

![Telefonie mit Asterisk: die Funktionen sind integriert](../images/01-introduction-fig04.png)

## Aufbau eines Testsystems

Bei der Implementierung einer Asterisk-Lösung besteht unser erster Schritt im Allgemeinen darin, ein Testsystem aufzubauen. Das Ziel ist eine minimale **1×1 PBX** — ein Telefon, das ein anderes anrufen kann —, damit Sie endpoints, dialplan und Funktionen ausprobieren können, bevor Sie das Produktionssystem anfassen. Heutzutage ist dies rein softwarebasiert: Sie benötigen keinerlei Telefonie-Hardware.

![Ein einfaches Asterisk-Testsystem](../images/01-introduction-fig05.png)

### Der moderne Weg: ein Software-Labor (empfohlen)

Das schnellste Testsystem ist Asterisk 22, das in einem Container oder einer virtuellen Maschine läuft, mit **softphones** als endpoints und optional einem **SIP trunk**, um das öffentliche Netz zu erreichen:

- **Asterisk 22** auf einem kleinen Linux-Rechner, einer VM oder einem Docker-Container. Dieses Buch enthält ein fertiges Docker-Labor (siehe Laboranleitung), das mit einem einzigen Befehl ein vollständig konfiguriertes Asterisk 22 startet — ohne Kompilierung, ohne Hardware.
- **Zwei softphones**, die als PJSIP endpoints registriert sind, sodass Sie einen echten Anruf zwischen ihnen tätigen können. In diesem Buch verwenden wir das **SipPulse Softphone** (kostenloser Download: <https://www.sippulse.com/produtos/softphone>), das für Desktop und Mobilgeräte verfügbar ist.
- **Ein SIP trunk** (optional) von einem VoIP-Anbieter, falls Sie das PSTN erreichen möchten. Keine Karte und keine analoge Leitung — nur Zugangsdaten.

So wird jedes Beispiel in diesem Buch erstellt und verifiziert, und Sie können es auf jedem Laptop reproduzieren.

### Der klassische Weg: analoge/digitale Karten

Vor VoIP benötigte eine Test-PBX physische Schnittstellen: einen **FXO**-Port zum Anschluss an eine bestehende Telefonleitung und einen **FXS**-Port zum Anschluss eines analogen Telefons, was zusammen eine 1×1 PBX ergab. Eine einzelne Karte mit einer FXO- und einer FXS-Schnittstelle war das klassische Starter-Kit. Diese DAHDI-basierten Karten (von Sangoma, ehemals Digium) existieren immer noch für Standorte, die analoge oder T1/E1-Leitungen terminieren müssen, sind aber heute eine Nische — die meisten Implementierungen sind reine VoIP-Lösungen. Wenn Sie nur analoge Telefone oder Leitungen anschließen müssen, lesen Sie das Kapitel *Legacy Channels*; ansonsten können Sie auf Telefonie-Hardware vollständig verzichten.

## Asterisk Szenarien

Asterisk kann in verschiedenen Szenarien eingesetzt werden. Wir werden einige davon auflisten und die Vorteile sowie mögliche Einschränkungen für jedes einzelne erläutern.

### IP PBX

Das häufigste Szenario ist die Installation einer neuen oder der Ersatz einer bestehenden PBX. Wenn Sie Asterisk mit anderen Alternativen vergleichen, werden Sie feststellen, dass es kostengünstiger und funktionsreicher ist als die meisten derzeit auf dem Markt erhältlichen PBXs. Viele Unternehmen ändern ihre Spezifikationen mittlerweile auf Asterisk anstelle von anderen Marken-PBXs.

![Asterisk als IP PBX](../images/01-introduction-fig06.png)

### IP-Anbindung für Legacy-PBXs

Das folgende Bild veranschaulicht eines der am häufigsten verwendeten Setups. Große Unternehmen möchten im Allgemeinen kein nennenswertes Risiko eingehen, wenn sie in neue Technologien investieren, und gleichzeitig ihre Investitionen in bestehende Geräte bewahren. Die IP-Anbindung einer Legacy-PBX kann sehr teuer sein; daher kann die Verbindung einer Asterisk PBX über T1/E1-Leitungen eine gute Alternative für kostenbewusste Kunden sein. Ein weiterer Vorteil ist die Möglichkeit, sich mit einem VoIP-Dienstanbieter mit besseren Telefontarifen zu verbinden.

![IP-Anbindung einer Legacy-PBX](../images/01-introduction-fig07.png)

### Toll Bypass

Eine sehr nützliche Anwendung für VoIP ist die Verbindung von Niederlassungen über das Internet oder ein WAN. Die Nutzung einer bestehenden Datenverbindung ermöglicht es Ihnen, die Gebühren für Telekommunikationsverbindungen zwischen Hauptsitz und Niederlassungen zu umgehen.

![Toll Bypass zwischen Büros über ein WAN](../images/01-introduction-fig08.png)

### Anwendungsserver (IVR, Konferenz, Voicemail)

Asterisk kann als Anwendungsserver für eine bestehende PBX verwendet oder direkt mit dem PSTN verbunden werden. Asterisk bietet Dienste wie voicemail, Faxempfang, Anrufaufzeichnung, mit einer Datenbank verbundenes IVR und einen Audiokonferenzserver. Wenn Sie voicemail und Fax in einen bestehenden E-Mail-Server integrieren, erhalten Sie ein Unified-Messaging-System, was normalerweise eine teure Lösung ist. Die Verwendung von Asterisk als Anwendungsserver bietet eine extreme Kostenreduzierung im Vergleich zu anderen Lösungen.

![Asterisk als Anwendungsserver](../images/01-introduction-fig09.png)

### Media Gateway

Die meisten VoIP-Dienstanbieter verwenden einen SIP-Proxy, um die gesamte Registrierung, Lokalisierung und Authentifizierung von SIP-Benutzern zu hosten. Sie müssen Anrufe dennoch direkt an das PSTN senden oder sie über einen Wholesale-Anbieter für Anrufbeendigung mittels einer SIP- oder H.323-VoIP-Verbindung routen. Asterisk kann als Back-to-Back User Agent (B2BUA) oder Media Gateway fungieren und sehr teure SoftSwitch-Systeme oder Media Gateways ersetzen. Vergleichen Sie den Preis eines vier E1/T1-Gateways der führenden Markthersteller mit Asterisk. Die Asterisk-Lösung kann um ein Vielfaches günstiger sein als andere Lösungen und ist in der Lage, Signalisierungsprotokolle (H.323, SIP, IAX…) und codecs (G.711, G.729…) zu übersetzen.

![Asterisk als Media Gateway](../images/01-introduction-fig10.png)

### Contact Center Plattform

Ein Contact Center ist eine sehr komplexe Lösung, die verschiedene Technologien kombiniert, wie z. B. automatische Anrufverteilung (ACD), IVR und Anrufüberwachung. Grundsätzlich sind drei Arten von Contact Centern verfügbar: Inbound, Outbound und Blended.

Inbound-Contact-Center sind sehr anspruchsvoll und erfordern in der Regel ACD, IVR, CTI, Aufzeichnung, Überwachung und Berichte. Asterisk verfügt über eine integrierte ACD, um die Anrufe in Warteschlangen zu stellen. IVR kann mithilfe der AGI oder interner Mechanismen wie der Anwendung background() realisiert werden. CTI wird mithilfe der AMI erreicht; Aufzeichnung und Berichterstattung sind in Asterisk integriert.

Für ein Outbound-Contact-Center ist ein Predictive oder Power Dialer eine der Hauptkomponenten. Obwohl mehrere Dialer für das Open-Source-Asterisk verfügbar sind, ist es nicht schwer, bei Bedarf einen eigenen für die Plattform zu erstellen. Ein Blended-Contact-Center ermöglicht den gleichzeitigen Inbound- und Outbound-Betrieb und spart Geld, indem eine bessere Auslastung der Agentenzeit sichergestellt wird. Es ist möglich, Asterisk und seinen ACD-Mechanismus zu verwenden, um eine Blended-Lösung zu implementieren.

![Eine Asterisk Contact-Center-Plattform](../images/01-introduction-fig11.png)

## Informationen und Hilfe finden

Dieser Abschnitt bietet einige der wichtigsten Informationsquellen rund um Asterisk.

- Offizielle Asterisk-Website: <https://www.asterisk.org> Hier finden Sie Informationen zu:
- Dokumentation & Wiki -> <https://docs.asterisk.org>
- Community-Forum -> <https://community.asterisk.org>
- Fehlerverfolgung (Bug Tracking) -> <https://github.com/asterisk/asterisk/issues>
- Wiki (veraltet, weitgehend durch docs.asterisk.org ersetzt) -> <https://wiki.asterisk.org>

### Community-Forum

Das Asterisk-Community-Forum hat die alten Mailinglisten weitgehend ersetzt und ist der Ort, an dem man Fragen stellen kann. Versuchen Sie, so viele Informationen wie möglich zu sammeln, bevor Sie einen Beitrag verfassen. Niemand wird Ihnen helfen, wenn Sie Ihre Hausaufgaben nicht gemacht haben — versuchen Sie zumindest einmal, das Problem selbst zu lösen.

- <https://community.asterisk.org>

## Zusammenfassung

Asterisk ist eine unter der GPL lizenzierte Software, die es einem gewöhnlichen PC ermöglicht, als leistungsstarke IP PBX-Plattform zu fungieren. Mark Spencer von Digium entwickelte Asterisk in den späten 1990er Jahren, und Digium finanzierte sich durch den Verkauf von Asterisk-bezogener Hardware und kommerziellen Produkten. Digium wurde 2018 von Sangoma Technologies übernommen; Sangoma sponsert heute die Entwicklung von Asterisk. Das Design der Hardwareschnittstellen hat seinen Ursprung im Zapata-Projekt, das von Jim Dixon entwickelt wurde und aus dem DAHDI hervorging.

Die Asterisk-Architektur besteht aus den folgenden Hauptkomponenten:

- CHANNELS: Analog, digital oder Voice-over-IP. In Asterisk 22 LTS wird SIP ausschließlich durch `chan_pjsip` gehandhabt.
- PROTOCOLS: Kommunikationsprotokolle, die für die Signalisierung der Anrufe verantwortlich sind, einschließlich SIP (via PJSIP), H.323, MGCP und IAX2.
- CODECS: Übersetzen digitale Formate von Sprache und ermöglichen Komprimierung sowie die Verschleierung von Paketverlusten. Beachten Sie, dass Asterisk selbst keine Stilleunterdrückung (Voice Activity Detection) oder die Erzeugung von Komfortrauschen durchführt; wenn endpoints VAD verwenden, sollte das Komfortrauschen auf der Client-Seite deaktiviert werden.
- APPLICATIONS: Verantwortlich für die Asterisk PBX-Funktionalität. Konferenz, voicemail und Fax sind Beispiele für Asterisk-Anwendungen.

Asterisk kann in verschiedenen Szenarien eingesetzt werden, von einer kleinen IP PBX bis hin zu einem hochentwickelten Contact Center. Hilfe finden Sie ganz einfach unter www.asterisk.org und docs.asterisk.org.

## Quiz

1. Welches Unternehmen hat Digium im Jahr 2018 übernommen und fungiert nun als primärer Verwalter des Asterisk Open-Source-Projekts?
   - A. Cisco Systems
   - B. Sangoma Technologies
   - C. Nortel Networks
   - D. Red Hat

2. Welcher Channel-Treiber stellt in Asterisk 22 LTS die SIP-Konnektivität bereit?
   - A. `chan_sip`
   - B. `chan_skinny`
   - C. `chan_pjsip`
   - D. `chan_h323`

3. Wahr oder Falsch: Der Channel-Treiber `chan_sip` wurde in Asterisk 21 entfernt und ist in einem Standard-Build von Asterisk 22 nicht mehr enthalten.

4. Welche der folgenden Channels/Protokolle sind **nicht mehr** Teil eines Standard-Builds von Asterisk 22? (Wählen Sie alle zutreffenden aus.)
   - A. MGCP (`chan_mgcp`)
   - B. SCCP / Cisco Skinny (`chan_skinny`)
   - C. IAX2 (`chan_iax2`)
   - D. H.323 (`chan_h323`, nur noch als Community-Add-on `ooh323` verfügbar)

5. Die Hardware-Architektur des Zapata-Projekts, ursprünglich Zaptel genannt, wurde später umbenannt in ____.
   - A. DAHDI
   - B. PJSIP
   - C. PRI
   - D. mISDN

6. Über welches interne Stream-Format übersetzt Asterisk, wenn Audio von einem codec in einen anderen konvertiert werden muss?
   - A. G.711 ulaw
   - B. GSM
   - C. slinear (signed linear)
   - D. Opus

7. Wie ist laut diesem Kapitel die Lizenzsituation des von Sangoma vertriebenen G.729 codec-Moduls?
   - A. Es ist GPL und für jede Nutzung komplett kostenlos.
   - B. Der Download ist kostenlos, aber die rechtmäßige Nutzung erfordert den Erwerb einer Lizenz pro Kanal.
   - C. Es ist ohne den Kauf der Asterisk Business Edition überhaupt nicht erhältlich.
   - D. Es funktioniert nur im Pass-Through-Modus und kann nicht installiert werden.

8. Welche Asterisk-Anwendung wird verwendet, um einen Anruf von einem Telefon zu einem anderen zu verbinden?
   - A. `Background()`
   - B. `Dial()`
   - C. `Queue()`
   - D. `Goto()`

9. Was ist der `Local` Channel in Asterisk?
   - A. Eine Hardware-FXS-Schnittstelle für analoge Telefone.
   - B. Ein SIP-trunk zu einem lokalen Dienstanbieter.
   - C. Ein Pseudo-Channel, der einen Anruf in einem anderen context zurück in den dialplan leitet.
   - D. Ein codec, der für On-Net-Anrufe verwendet wird.

10. In welchem Nutzungsszenario fungiert Asterisk als Back-to-Back User Agent (B2BUA), der zwischen Signalisierungsprotokollen und codecs übersetzt, um teure SoftSwitch-Lösungen zu ersetzen?
    - A. IP-Anbindung einer bestehenden PBX
    - B. Toll Bypass
    - C. Media Gateway
    - D. Contact Center Plattform

**Antworten:** 1 — B · 2 — C · 3 — Wahr · 4 — A, B, D · 5 — A · 6 — C · 7 — B · 8 — B · 9 — C · 10 — C
