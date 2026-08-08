# Legacy-Kanäle: analog, TDM & IAX2

In einer Welt, die 2026 rein auf VoIP setzt, werden die in diesem Kapitel behandelten Kanaltypen immer seltener: Die meisten neuen Implementierungen basieren auf SIP-Trunks und PJSIP-endpoints über Ethernet, ganz ohne Telefonie-Hardware. Asterisk 22 unterstützt dennoch weiterhin die meisten davon vollständig. Analoge (FXO/FXS) und digitale TDM-Konnektivität (E1/T1/ISDN PRI/BRI) wird über DAHDI bereitgestellt — den Treiberstapel, der ursprünglich von Digium entwickelt wurde, welches 2018 von Sangoma übernommen wurde, nachdem die früheren Zaptel-Treiber infolge eines Markenrechtsstreits umbenannt worden waren. Die Server-zu-Server-Konnektivität über IAX2 wird durch `chan_iax2` bereitgestellt, das weiterhin ausgeliefert und unterstützt wird, aber mittlerweile fest als Legacy-Protokoll gilt.

Dieses Kapitel fasst zudem das Material zu **Legacy SIP** zusammen: den alten `chan_sip`-Treiber und dessen `sip.conf`-Konfiguration — in Asterisk 21 entfernt und in Asterisk 22 nicht mehr vorhanden — zusammen mit einer vollständigen Anleitung zur Migration eines bestehenden `sip.conf`-Systems auf PJSIP. Wenn Sie einen reinen SIP-Betrieb auf PJSIP ohne Telefoniekarten, ohne IAX2-Trunks und ohne zu konvertierendes Legacy-`sip.conf` betreiben, können Sie dieses Kapitel getrost überspringen.

## Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Asterisk über DAHDI mit analogen Leitungen und Telefonen mit FXO/FXS-Schnittstellen zu verbinden;
- digitale TDM-Konnektivität (E1/T1, ISDN PRI/BRI) zu erkennen und zu verstehen, wie diese konfiguriert wird;
- IAX2 (`chan_iax2`) für Server-zu-Server-Trunks zu konfigurieren und zu verstehen, warum es mittlerweile als veraltet gilt;
- den ausgemusterten `chan_sip`-Treiber und die `sip.conf`-Syntax zu identifizieren, auf die Sie möglicherweise noch stoßen; und
- ein bestehendes `chan_sip`/`sip.conf`-System auf PJSIP zu migrieren.

## Analoge Kanäle (FXO/FXS)

Ab Asterisk 22 werden DAHDI und analoge Telefoniekarten weiterhin vollständig unterstützt, und DAHDI lässt sich nach wie vor mit aktuellen Kerneln kompilieren. Die Mehrheit der neuen Implementierungen ist jedoch reines VoIP (SIP-Trunks, PJSIP), weshalb analoge/TDM-Hardware heute eine Nischenwahl darstellt – sie findet sich hauptsächlich in Legacy-Umgebungen, bei der Anbindung ländlicher PSTN-Anschlüsse oder in regulierten Märkten. Alles Folgende gilt weiterhin für diese Szenarien.

Es gibt verschiedene Möglichkeiten, das öffentliche Telefonnetz (PSTN) anzubinden. Der beste Weg hängt davon ab, wie die Telefongesellschaft diese Verbindung in Ihrer Region bereitstellt. Der einfachste Weg ist die Verwendung einer analogen Leitung, ähnlich der Leitung, die Sie zu Hause nutzen. In diesem Abschnitt zeigen wir Ihnen, wie Sie analoge Karten von Sangoma™ (ehemals Digium™) und Xorcom™ konfigurieren.

### Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Die wichtigsten Telefoniebegriffe und Akronyme zu erkennen;
- Zu verstehen, wann digitale und analoge Schaltkreise zu verwenden sind;
- Den Unterschied zwischen FXS und FXO zu erkennen; und
- Asterisk für FXS und FXO zu konfigurieren.

### Grundlagen der Telefonie

Die meisten analogen Implementierungen verwenden ein Paar Kupferleitungen, die als Tip und Ring bezeichnet werden. Wenn eine Schleife geschlossen wird, erhält das Telefon das Freizeichen von der Vermittlungsstelle (oder der privaten PBX). Die am häufigsten verwendete Signalisierung ist Loop-Start; andere, weniger verbreitete Signalisierungsarten umfassen Ground-Start, das in einigen Ländern verwendet wird. Die drei Kategorien der Signalisierung sind:

- Überwachungssignalisierung (Supervision signaling)
- Adresssignalisierung
- Informationssignalisierung

#### Überwachungssignalisierung

Die wichtigsten Überwachungssignale sind On-Hook, Off-Hook und Ringing.

- **On-Hook** – Wenn ein Benutzer den Hörer auflegt, unterbricht die PBX die Verbindung und lässt keinen elektrischen Strom fließen. In diesem Zustand wird der Schaltkreis als On-Hook bezeichnet. In dieser Position ist nur der Klingelmechanismus aktiv.
- **Off-Hook** – Vor dem Starten eines Telefonats muss das Telefon in den Off-Hook-Zustand übergehen. Das Abnehmen des Hörers schließt die Schleife und signalisiert der PBX, dass der Benutzer einen Anruf tätigen möchte. Nach Erhalt dieser Anzeige erzeugt die PBX ein Freizeichen, das dem Benutzer signalisiert, dass sie bereit ist, die Zieladresse (d. h. die Telefonnummer) entgegenzunehmen.
- **Ringing** – Wenn ein Benutzer ein anderes Telefon anruft, erzeugt es eine Spannung für den Klingelmechanismus, die den anderen Benutzer über einen eingehenden Anruf informiert. Die Signalisierung variiert je nach Land, mit unterschiedlichen Tönen für verschiedene Länder.

Sie können die Asterisk-Töne an Ihr Land anpassen, indem Sie die Datei indications.conf bearbeiten. Zum Beispiel:

```
[br]
description=Brazil
ringcadance=1000,4000
dial=425
busy=425/250,0/250
ring=425/1000,0/4000
congestion=425/250,0/250,425/750,0/250
callwaiting=425/50,0/1000
```

#### Adresssignalisierung

Sie können zwei Arten der Signalisierung für das Wählen verwenden. Die erste und gebräuchlichste ist Dual Tone Multi-Frequency (DTMF), während die andere die Impulswahl (verwendet in alten Wählscheibentelefonen) ist. Telefone haben ein Tastenfeld zum Wählen, und jede Taste ist mit zwei Frequenzen verknüpft: einer hohen und einer niedrigen. Bei der DTMF-Signalisierung zeigt die Kombination dieser Töne an, welche Ziffer gedrückt wird. MFC/R2 verwendet einen von DTMF verschiedenen Mehrfrequenzton.

#### Informationssignalisierung

Die Informationssignalisierung zeigt den Fortschritt des Anrufs und verschiedene Ereignisse an.

- Freizeichen (Dial tone)
- Besetztzeichen (Busy Tone)
- Rufzeichen (Ringback)
- Überlastung (Congestion)
- Ungültige Nummer
- Bestätigungston

### PSTN-Schnittstellen

Wie bei alten PBXs ist es oft erforderlich, die Asterisk PBX mit dem PSTN zu verbinden. Hier zeigen wir Ihnen, wie das geht. Normalerweise haben Sie drei Optionen für Telefonleitungen.

- Analog: Die häufigste Form für Privathaushalte und kleine Unternehmen, normalerweise bereitgestellt über ein metallisches Kupferleitungspaar.
- Digital: Wird verwendet, wenn viele Leitungen erforderlich sind. Eine digitale Leitung wird normalerweise von einem CSU/DSU oder einem Glasfaser-Multiplexer bereitgestellt. Der Endbenutzeranschluss ist normalerweise ein RJ45. In einigen Ländern werden E1-Leitungen über zwei koaxiale BNC-Anschlüsse geliefert; in diesem Fall benötigen Sie einen Balun, um die Verbindung zur RJ45-Buchse der Telefoniekarte herzustellen.
- SIP: Diese Option wurde kürzlich entwickelt. Die Telefonleitung wird über eine Datenverbindung mit SIP-Signalisierung (VoIP) bereitgestellt. Dies ist eine gute Option für Asterisk, da Sie keine Telefoniekarte kaufen müssen. Telefonanrufe werden direkt an den Ethernet-Port geliefert. Ein weiterer Vorteil ist, dass Sie möglicherweise Ressourcen Ihrer CPU freigeben können, indem Sie Codec-Transcoding vermeiden.

### Analoge FXS-, FXO- und E&M-Schnittstellen

Es sind verschiedene Arten von analogen Schnittstellen verfügbar. Es ist grundlegend, die Unterschiede zwischen diesen Schnittstellen zu verstehen, um zu lernen, wie man eine Verbindung zum Telefonnetz sowie zu anderen PBXs herstellt. Hier zeigen wir Ihnen die E&M-Schnittstelle. Obwohl sie derzeit für Asterisk nicht verfügbar ist und von mehreren Herstellern eingestellt wurde, finden Sie möglicherweise Router und PBXs mit dieser Art von Schnittstelle, daher ist es besser zu wissen, womit Sie es zu tun haben.

#### Foreign eXchange (FX) Schnittstellen

FX-Schnittstellen sind analog. Der Begriff „Foreign eXchange“ wird auf Zugangstrunks zu einer PSTN-Vermittlungsstelle (CO) angewendet. Foreign eXchange Office (FXO)

![Asterisk zwischen einem analogen Telefon (FXS) und der Telco-Leitung (FXO): Die FXS-Seite liefert Freizeichen und Klingeln an das Telefon, während die FXO-Seite das Freizeichen von der Vermittlungsstelle bezieht.](../images/10-legacy-fig01.png)

Die FXO-Schnittstelle wird verwendet, um eine Verbindung zu einer Vermittlungsstelle (CO) oder einer Nebenstelle einer anderen PBX herzustellen. Sie kommuniziert direkt mit einer Telefonleitung, die vom PSTN kommt. Eine weitere Option ist die Verbindung der FXO-Schnittstelle mit einer bestehenden PBX, was die Kommunikation zwischen Asterisk und der Legacy-PBX ermöglicht. Die Verbindung von Asterisk mit einem PBX-Port und die Bereitstellung einer entfernten Nebenstelle mittels VoIP wird oft als Off-Premises Extension (OPX) bezeichnet. Eine FXO-Schnittstelle empfängt ein Freizeichen. Foreign eXchange Station (FXS) Die FXS-Schnittstelle speist ein analoges Telefon, Modem oder Fax. Die FXS liefert das Freizeichen und die Stromversorgung für ein Telefon.

#### Trunk-Signalisierung

- Loop-Start
- Ground-Start
- Kewlstart

Die Verwendung der Kewlstart-Signalisierung in Asterisk ist fast Standard. Kewlstart ist keine Signalisierung an sich, sondern fügt dem Schaltkreis Intelligenz hinzu, indem es überwacht, was auf der anderen Seite passiert. Kewlstart basiert auf Loop-Start. Die meisten Vermittlungsstellen unterstützen diese Funktion nicht, die dazu dient, die Auflegen-Benachrichtigung zu erhalten.

- Loopstart: Wird in den meisten analogen Leitungen verwendet; es ermöglicht dem Telefon, „On-Hook“ und „Off-Hook“ zu signalisieren, und der Vermittlungsstelle, „Ring“ und „No-Ring“ zu signalisieren. Dies ist wahrscheinlich das, was die meisten Leute zu Hause haben. Der Name kommt daher, dass die Leitung immer offen ist. Wenn Sie die Schleife schließen, stellt Ihnen die Vermittlungsstelle ein Freizeichen bereit. Ein eingehender Anruf wird durch eine 100V-Klingelspannung über das offene Paar signalisiert.

![Asterisk als VoIP-Gateway: Ein FXO-Port verbindet sich mit einer Legacy-PBX-Nebenstelle, während ein entfernter Asterisk diese Leitung über IP durch einen FXS-Port an ein analoges Telefon liefert (eine Off-Premises Extension oder OPX).](../images/10-legacy-fig02.png)

- Groundstart: Ähnlich wie Loopstart. Wenn Sie einen Anruf tätigen möchten, wird eine Seite der Leitung kurzgeschlossen. Wenn die Vermittlungsstelle diesen Zustand identifiziert, kehrt sie die Spannung über das offene Paar um, und dann wird die Schleife geschlossen. Folglich wird die Leitung zuerst belegt, bevor sie dem Anrufer angeboten wird.
- Kewlstart: Fügt den Schaltkreisen Intelligenz hinzu und ermöglicht die Überwachung der anderen Seite. Kewlstart integriert viele Vorteile von Loop-Start.

### Einrichtung der Asterisk-Telefoniekanäle

Um eine Telefonieschnittstellenkarte zu konfigurieren, sind mehrere Schritte erforderlich. In diesem Kapitel zeigen wir drei der häufigsten Szenarien:

- Analoge Verbindung mittels FXS
- Analoge Verbindung mittels FXO
- Verbindung eines Astribank™ mit FXS- und FXO-Schnittstellen

### Konfigurationsverfahren (in beiden Fällen gültig)

Bevor Sie Hardware für Asterisk auswählen, sollten Sie die Anzahl der gleichzeitigen Anrufe, Dienste und Codecs berücksichtigen, die installiert und aktiviert werden sollen. Asterisk ist eine CPU-intensive Anwendung, weshalb wir eine dedizierte Maschine für Asterisk empfehlen. Die Anzahl der im Computer installierten Schnittstellenkarten ist durch die Anzahl der verfügbaren Steckplätze und Interrupts begrenzt. Es ist vorzuziehen, eine einzelne Karte mit acht Sprachschnittstellen zu installieren als zwei Karten mit vier. Eine weitere Option ist die Verwendung einer USB-Channel-Bank, wie z. B. die Xorcom Astribank. Kürzlich haben einige Hersteller (z. B. CIANET) begonnen, TDMoE-Channel-Banks zu produzieren, was es noch einfacher macht, Dutzende analoger Schnittstellen anzuschließen.

![Eine Xorcom Astribank: eine 19-Zoll-Rack-montierbare USB-Channel-Bank, die Dutzende von FXS/FXO-Ports bereitstellt (hier eine 32-Port-Einheit), ohne PCI-Steckplätze im Host zu verbrauchen.](../images/10-legacy-fig03.png)

#### Beispiel 1: Eine FXO-, eine FXS-Installation

In diesem Beispiel verwenden wir eine Sangoma TDM400 Telefonieschnittstellenkarte (ehemals als Digium TDM400 verkauft) mit einem FXS- und einem FXO-Modul. Die erforderlichen Schritte sind unten aufgeführt:

1. Installieren Sie die analoge Karte FXS, FXO oder beide.
2. Konfigurieren Sie die Datei `/etc/dahdi/system.conf` (ehemals `/etc/zaptel.conf`).
3. Generieren Sie die Konfigurationsdateien mittels `dahdi_genconf`.
4. Laden Sie den Treiber für die DAHDI-Schnittstelle.
5. Führen Sie `dahdi_test` aus, um Interrupt-Verluste zu überprüfen.
6. Führen Sie `dahdi_cfg` aus, um den Treiber zu konfigurieren.
7. Konfigurieren Sie den DAHDI-Kanal in der Datei `chan_dahdi.conf`, dann laden Sie Asterisk.

##### Schritt 1: Installieren der TDM400-Karte

Die TDM404P-Karte enthält FXS- und FXO-Module. Verbinden Sie die FXS- (S110M, grün) und FXO- (X100M, rot) Module. Wenn Sie FXS-Module verwenden, verbinden Sie die Karte direkt mit der Stromquelle über einen Molex-Anschluss. Bitte tragen Sie einen elektrostatischen Schutz, bevor Sie Schnittstellenkarten handhaben, um Schäden an der Hardware zu vermeiden. Sangoma (ehemals Digium) Analogkarten unterstützen auch ein Hardware-Echokompensationsmodul VPMADT032.

##### Schritt 2: Generieren der Konfiguration mit dahdi_genconf

Die gute Nachricht bei der Konfiguration ist das neue Dienstprogramm `dahdi_genconf`, das automatisch die DAHDI-Schnittstellen erkennt und die Konfiguration generiert. Das Dienstprogramm generiert zwei Dateien:

- `/etc/dahdi/system.conf`
- `/etc/asterisk/dahdi-channels.conf`
- `/etc/asterisk/users.conf` (mit der Option `users`)
- Alle diese Dateien verwenden die Option `chan_dahdi full`

Bevor Sie `dahdi_genconf` ausführen können, ist es wichtig, die Datei `genconf_parameters` (oft als `gen_parameters.conf` bezeichnet) zu konfigurieren:

![Eine Sangoma/Digium TDM404P Analogkarte: bis zu vier FXS- oder FXO-Module werden in die nummerierten Ports gesteckt, mit einer optionalen Hardware-Echokompensations-Tochterkarte und einem dedizierten 12-V-Stromanschluss für FXS-Module.](../images/10-legacy-fig04.png)

```
#
# /etc/dahdi/genconf_parameters
#
# This file contains parameters that affect the
# dahdi_genconf configurator generator.
#
#base_exten          4000
#fxs_immediate       no
#fxs_default_start   ks
#lc_country          il
#context_lines       from-pstn
#context_phones      from-internal
#context_input       astbank-input
#context_output      astbank-output
#group_phones        0
#group_lines         5
#brint_overlap
#bri_sig_style       bri_ptmp
#
# The echo canceller to use. If you have a hardware echo canceller, just
# leave it be, as this one won't be used anyway.
#
# The default is mg2, but it may change in the future. E.g: a packager
# that bundles a better echo canceller may set it as the default, or
# dahdi_genconf will scan for the "best" echo canceller.
#
#echo_can            hpec
#echo_can            oslec
#echo_can            none   # to avoid echo cancellers altogether
# bri_hardhdlc: If this parameter is set to 'yes', in the entries for
# BRI cards 'hardhdlc' will be used instead of 'dchan' (an alias for
# 'fcshdlc').
#
#bri_hardhdlc        yes
# For MFC/R2 Support
#pri_connection_type R2
#r2_idle_bits        1101
# pri_types contains a list of settings:
# Currently the only setting is for TE or NT (the default is TE)
#
#pri_termtype
# SPAN/2              NT
# SPAN/4              NT
```

Die Datei `genconf_parameters` lässt Sie Ihre Konfiguration anpassen. Die wichtigsten Parameter für analoge Leitungen sind:

```
base_exten          4000
fxs_immediate       no
fxs_default_start   ks
lc_country          br
context_lines       from-pstn
context_phones      from-internal
context_input       astbank-input
context_output      astbank-output
group_phones        0
group_lines         5
#echo_can           hpec
#echo_can           oslec
echo_can            MG2
```

Warnung: Es ist erforderlich, dass Sie mindestens den Echokompensationsalgorithmus für die Kanäle konfigurieren. Der Parameter base_exten definiert den grundlegenden Dialplan für FXS-Nebenstellen. In diesem Fall erhält der erste FXS-Kanal die Nebenstellennummer 4000, der zweite 4001 und so weiter. Der Kontext, in dem die Leitungen (context_phones) und Trunks (context_lines) erstellt werden, ist sehr wichtig. Nach dem Generieren der Dateien sollten Sie die Datei `/etc/asterisk/dahdi-channels.conf` in die Datei `/etc/asterisk/chan_dahdi.conf` einbinden:

```
#include dahdi-channels.conf
```

Hinweis: Analoge Signalisierung ist etwas verwirrend; sie ist immer das Inverse der Karte. FXS-Karten werden mit FXO signalisiert, während FXO-Karten mit FXS signalisiert werden. Asterisk spricht mit diesen Geräten, als ob es sich auf der gegenüberliegenden Seite befände.

##### Schritt 3: Laden der Kernel-Treiber

Jetzt müssen Sie das Modul chan_dahdi und den zugehörigen Karten-Kernel-Treiber laden. Verwenden Sie dahdi_hardware, um Ihre Karte und den Treibernamen zu erkennen. Zum Beispiel:

| Karte | Treiber | Beschreibung |
| --- | --- | --- |
| TE410P | wct4xxp | 4xE1/T1 - 3.3V PCI |
| TE405P | wct4xxp | 4xE1/T1 - 5V PCI |
| TDM400P | wctdm | 4 FXS/FXO |
| T100P | wct1xxp | 1 T1 |
| E100P | wct1xxp | 1 E1 |
| X100P | wcfxo | 1 FXO |

Befehle zum Laden der Treiber:

```
modprobe dahdi
modprobe wctdm
```

##### Schritt 4: Verwenden des Dienstprogramms dahdi_test

Ein wichtiges Dienstprogramm ist dahdi_test, das verwendet wird, um Interrupt-Verluste in der DAHDI-Karte zu überprüfen. Audioqualitätsprobleme hängen oft mit Interrupt-Konflikten zusammen. Um zu überprüfen, ob Ihre DAHDI-Karte keinen Interrupt mit anderen Karten teilt, verwenden Sie den folgenden Befehl:

```
#cat /proc/interrupts
```

Sie können die Anzahl der Interrupt-Verluste mit dem Dienstprogramm dahdi_test überprüfen, das mit den DAHDI-Karten kompiliert wurde. Eine Zahl unter 99.987% deutet auf mögliche Probleme hin.

##### Schritt 5: Verwenden des Dienstprogramms dahdi_cfg zur Konfiguration des Treibers

DAHDI hat ein ungewöhnliches System zum Laden der Treiber. Konfigurieren Sie zuerst die /etc/dahdi/system.conf und wenden Sie diese Konfigurationen dann mit dahdi_cfg auf den DAHDI-Treiber an. In diesem Fall wird dahdi_cfg verwendet, um die Signalisierung für die FX-Schnittstellen zu konfigurieren. Um die Ergebnisse zu sehen, können Sie „-vvvvv“ an den Befehl für Verbose anhängen.

```
#
/sbin/dahdi_cfg -vv
Dahdi Configuration
======================
Channel map:
Channel 01: FXS Kewlstart (Default) (Slaves: 01)
Channel 02: FXO Kewlstart (Default) (Slaves: 02)
2 channels configured.
```

Wenn die Kanäle erfolgreich geladen wurden, sehen Sie eine Ausgabe ähnlich der oben gezeigten. Benutzer konfigurieren chan_dahdi.conf oft fälschlicherweise mit invertierter Signalisierung zwischen den Kanälen. Wenn dies passiert, sehen Sie eine Meldung wie die unten gezeigte:

```
DAHDI_CHANCONFIG failed on channel 1: Invalid argument (22)
Did you forget that FXS interfaces are configured with FXO signalling
and that FXO interfaces use FXS signalling?
```

Nach erfolgreicher Konfiguration der Hardware können Sie mit der Asterisk-Konfiguration fortfahren.

##### Schritt 6: Konfigurieren der Datei /etc/asterisk/chan_dahdi.conf

Es klingt seltsam, aber nach der Konfiguration der /etc/dahdi/system.conf haben Sie die Karte selbst konfiguriert. DAHDI kann für andere Zwecke verwendet werden, wie Routing und SS7. Um es mit Asterisk zu verwenden, müssen Sie die Asterisk DAHDI-Kanäle konfigurieren. Jeder Kanal in Asterisk muss definiert werden; SIP/PJSIP-Kanäle werden in pjsip.conf definiert (Hinweis: chan_sip und sip.conf wurden in Asterisk 21 entfernt), während TDM-Kanäle in chan_dahdi.conf definiert werden. Dies erstellt die logischen TDM-Kanäle, die in Ihrem Dialplan verwendet werden sollen.

```
signalling=fxs_ks;                  ; FXS signaling for the FXO interface
group=1;                            ; channel group
context=incoming;                   ; context
channel => 1;                       ; channel number
signalling=fxo_ks;                  ; FXO signaling for the FXS interface
group=2;                            ; channel group
context=extensions;                 ; context
channel => 2                        ; channel number
```

### Konfigurationsoptionen

In der Datei chan_dahdi.conf sind verschiedene Optionen verfügbar. Eine Beschreibung aller Optionen wäre langweilig und kontraproduktiv; stattdessen konzentrieren wir uns auf die wichtigsten Optionsgruppen für ein einfaches Verständnis.

#### Allgemeine Optionen (kanalunabhängig)

Diese Optionen funktionieren für jeden Kanal: context: Definiert den eingehenden Kontext.

```
context=default
```

channel: Definiert den Kanal oder Kanalbereich. Jede Kanaldefinition erbt Optionen, die vor der Deklaration definiert wurden. Kanäle können einzeln oder in derselben Zeile durch Kommatrennung identifiziert werden. Bereiche können mit „-“ definiert werden.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Ermöglicht es, Kanäle als Gruppe zu behandeln. Wenn Sie eine Gruppennummer anstelle einer Kanalnummer wählen, wird der erste verfügbare Kanal verwendet. Wenn es sich bei den Kanälen um Telefone handelt, klingeln bei einem Anruf der Gruppe alle Telefone gleichzeitig. Mit Kommas können Sie mehr als eine Gruppe für denselben Kanal angeben.

```
group=1
group=3,5
```

language: Aktiviert die Internationalisierung und konfiguriert eine Sprache. Diese Funktion konfiguriert Systemmeldungen für eine bestimmte Sprache. Englisch ist die einzige Sprache mit vollständigen Prompts, die über die Standardinstallation verfügbar sind. musiconhold: Wählt die Music-on-Hold-Klasse aus.

#### Caller-ID-Optionen

Es gibt viele Caller-ID-Optionen. Einige können deaktiviert werden, obwohl die meisten standardmäßig aktiviert sind. usecallerid: Aktiviert oder deaktiviert die Caller-ID-Übertragung für die nachfolgenden Kanäle (Yes/No). Hinweis: Wenn Ihr System zwei Klingelzeichen erhält, bevor es antwortet, versuchen Sie, diese Funktion zu deaktivieren. Es sollte sofort antworten. hidecallerid: Definiert, ob die ausgehende Caller-ID verborgen werden soll oder nicht (Yes/No). callerid: Konfiguriert einen Caller-ID-String für einen bestimmten Kanal. Der Anrufer kann mit asreceived konfiguriert werden. Dies wird meist in Trunk-Schnittstellen verwendet, um die eingehende Caller-ID anzuzeigen.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

callwaitingcallerid: Unterstützt Caller-ID während des Anklopfens. useincomingcalleridondahditransfer: Verwendet die eingehende Caller-ID bei einer Weiterleitung.

#### Anklopfen (Call Waiting)

Asterisk unterstützt Anklopfen in FXS-Kanälen. Der Benutzer erhält einen Anklopfton, wenn jemand versucht, die Nebenstelle zu erreichen. Um Anklopfen zu aktivieren:

```
callwaiting=yes
```

Um Caller-ID beim Anklopfen zu unterstützen:

```
callwaitingcallerid=yes
```

#### Audioqualitätsoptionen

Das Einstellen der Echokompensation ist halb technisch, halb Kunst. Diese Optionen passen bestimmte Asterisk-Parameter an, die die Audioqualität in den DAHDI-Kanälen beeinflussen. Sie können helfen, die Audioqualität in analogen Schnittstellen zu verbessern.

#### Das Dienstprogramm fxotune

Das fxotune ist ein Dienstprogramm, das verwendet wird, um bestimmte Parameter für FXO-Module fein abzustimmen. Diese Feinabstimmung ist erforderlich, um Impedanzfehlanpassungen auszugleichen, die durch die Gabelschaltung (Hybrid) verursacht werden. Das Dienstprogramm hat drei Betriebsmodi:

- Erkennung (-i): erkennt und korrigiert die bestehenden FXO-Kanäle und speichert die Konfiguration in

```
fxotune.conf
```

- Dump-Modus (-d): generiert die Wellenformdateien zu fxotune_dump.vals
- Startup-Modus (-s): liest die Datei fxotune.conf und wendet sie auf die FXO-Module an

Es ist wichtig zu verstehen, dass Sie die Anweisung fxotune –s beim Systemstart einfügen müssen, bevor Sie Asterisk starten:

```
#modprobe dahdi
#modprobe wctdm
#fxotune -s
```

### Echokompensation

Die meisten Echokompensationsalgorithmen arbeiten, indem sie mehrere Kopien des empfangenen Signals erzeugen, wobei jede um eine bestimmte Zeit verzögert wird. Die Anzahl der Taps des Filters bestimmt die Größe der Echoverzögerung, die kompensiert werden muss. Diese verzögerten Kopien werden dann angepasst und vom empfangenen Signal subtrahiert. Der Trick besteht darin, nur das verzögerte Signal anzupassen, um das Echo zu entfernen, ohne zu viele CPU-Zyklen zu verbrauchen. Aus Sicht der Benutzer ist es wichtig, einen geeigneten Echokompensationsalgorithmus zu wählen. Der Standard ist MG2; es sind jedoch zwei weitere Optionen verfügbar: die High Performance Echo Cancellation (HPEC) von Sangoma (ehemals Digium) und die Open-Source-Echokompensation (OSLEC), entwickelt von David Rowe.

OSLEC (https://www.rowetel.com/?page_id=454) wurde in den Linux-Kernel integriert – es befindet sich im `drivers/staging/echo`-Bereich des Kernels – und DAHDI wird dagegen kompiliert, anstatt einen separaten Download auszuliefern. Um den Echokompensationsalgorithmus zu ändern, setzen Sie den Parameter `echo_can` in `/etc/dahdi/system.conf`. Zum Beispiel:

```
echo_can=oslec
```

Die Echokompensation in Asterisk wird durch drei Parameter in der Datei /etc/asterisk/chan- gesteuert.

```
dahdi.conf.
```

- **echocancel**: Deaktiviert oder aktiviert die Echokompensation. Sie sollten diese Funktion aktiviert lassen. Sie akzeptiert "yes" oder die Anzahl der Taps. (Erklärung: Wie funktioniert Echokompensation? Die meisten Echokompensationsalgorithmen arbeiten, indem sie mehrere Kopien eines empfangenen Signals erzeugen, wobei jede um ein kleines Intervall verzögert wird. Dieser kleine Fluss wird als "Tap" bezeichnet. Die Anzahl der Taps bestimmt die Echoverzögerung, die kompensiert werden kann. Diese Kopien werden verzögert, angepasst und vom ursprünglichen Signal subtrahiert. Der Trick besteht darin, das verzögerte Signal genau auf das Notwendige anzupassen, um das Echo zu entfernen.)
- **echocancelwhenbridged**: Aktiviert oder deaktiviert den Echokompensator während eines reinen TDM-Anrufs. Dies ist normalerweise nicht erforderlich.
- **rxgain**: Passt die Audioempfangsverstärkung an, um die Empfangslautstärke entweder zu erhöhen oder zu verringern (-100% bis 100%).
- **txgain**: Passt die Audioübertragungsverstärkung an, um die Übertragungslautstärke entweder zu erhöhen oder zu verringern (-100% bis 100%).

Zum Beispiel:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Abrechnungsoptionen

Diese Optionen ändern, wie Anrufinformationen in der Call Detail Records (CDR)-Datenbank aufgezeichnet werden. amaflags: Konfiguriert die AMA-Flags, die die CDR-Kategorisierung beeinflussen. Es akzeptiert die folgenden Werte:

- billing
- documentation
- omit
- default

accountcode: Konfiguriert einen Account-Code für einen bestimmten Kanal. Er kann jeden alphanumerischen Wert enthalten – normalerweise die Abteilung oder den Benutzernamen.

```
accountcode=finance
amaflags=billing
```

### Anruffortschrittsoptionen

Diese Elemente werden verwendet, um Informationen über den Fortschritt des Anrufs zu erhalten. Bei öffentlichen Schnittstellen kann es nützlich sein, den Anruffortschritt zu erkennen und festzustellen, ob er beantwortet wurde oder besetzt ist. Die Besetzterkennung ist hochgradig experimentell und durch spezifische Parameter reguliert.

```
busydetect=yes
busycount=4
busypattern=500,500
callprogress=yes
progzone=br
```

Diese Parameter (oben) geben an, ob die Schnittstelle versuchen soll, das Besetztzeichen zu erkennen, wie viele Töne für eine erfolgreiche Erkennung verwendet werden und was das Besetztmuster ist. Die Besetzterkennung ist weitgehend experimentell, und einige zusätzliche Parameter können im Makefile geändert werden. Um die Antwort eines Anrufs zu erkennen, was für eine präzise Abrechnung unerlässlich ist, ist es möglich, die Polaritätsumkehr zu verwenden, um die genaue Antwortzeit zu signalisieren. Dies ist wichtig, wenn Sie den Anruf in Rechnung stellen möchten oder einfach eine präzise Abrechnung zum Vergleich wünschen. Normalerweise müssen Sie die Telefongesellschaft kontaktieren, um diesen Dienst anzufordern.

```
answeronpolarityswitch=yes
```

In einigen Ländern ist es auch möglich, das Auflegen des Anrufs mittels Polaritätsumkehr zu erkennen.

```
hanguponpolarityswitch=yes
```

#### Optionen für Telefone

Diese Optionen werden für Telefone verwendet, die mit den FXS-Schnittstellen verbunden sind. Alle Funktionen, die an analoge Telefone geliefert werden, die direkt mit den DAHDI-Schnittstellen verbunden sind, werden von Asterisk gesteuert.

- **adsi** (Analog Display Services Interface): Dies ist eine Reihe von Telekommunikationsstandards, die von einigen Telefongesellschaften verwendet werden, um Dienste wie Ticketkauf anzubieten.
- **cancallforward**: Aktiviert oder deaktiviert die Anrufweiterleitung (*72 zum Aktivieren und *73 zum Deaktivieren).
- **calleridcallwaiting**: Aktiviert die Caller-ID, die während einer Anklopfanzeige empfangen wird (Yes/No).
- **immediate**: Im Immediate-Modus springt der Kanal, anstatt ein Freizeichen bereitzustellen, sofort zur "s"-Nebenstelle im definierten Kontext. Dies wird verwendet, um Hotlines zu erstellen.
- **threewaycalling**: Aktiviert oder deaktiviert Drei-Wege-Konferenzen.
- **mailbox**: Warnt den Benutzer über verfügbare Voicemail-Nachrichten. Es kann ein akustisches Signal oder eine visuelle Anzeige sein (wenn das Telefon diese Funktion unterstützt). Das Argument ist die Mailbox-Nummer.
- **callgroup**: Gruppieren Sie Telefone zum Wählen oder zum Heranholen.
- **pickupgroup**: Gruppe von Telefonen für das Heranholen von Anrufen.

### Nützliche DAHDI CLI-Befehle

Sobald Asterisk mit geladenen DAHDI-Kanälen läuft, können Sie den Kanalstatus über die Asterisk CLI überprüfen. Diese Befehle bleiben in Asterisk 22 aktuell:

```
*CLI> dahdi show channels
*CLI> dahdi show channel 1
*CLI> module reload chan_dahdi.so
```

### DAHDI-Kanalformat

DAHDI-Kanäle verwenden das folgende Format im Dialplan:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Zum Beispiel:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## Digitale Kanäle (E1/T1/PRI / TDM)

Ab Asterisk 22 werden DAHDI und libpri weiterhin vollständig unterstützt, jedoch werden digitale TDM-Trunks (E1/T1/ISDN PRI) bei neuen Implementierungen zunehmend durch SIP-Trunks ersetzt. Dieser Abschnitt bleibt voll anwendbar, wo TDM-Konnektivität erforderlich ist; in Greenfield-Umgebungen liefert SIP-Trunking (Kapitel 3) normalerweise die gleiche Kanaldichte ohne Telefonie-Hardware.

Digitale Kanäle sind extrem verbreitet, daher müssen Sie lernen, wie diese Kanäle implementiert werden, wenn Sie sich auf große Kunden konzentrieren möchten. Wenn die Anzahl der Kanäle hoch ist – normalerweise mehr als 8 –, ist es ziemlich üblich, digitale Schnittstellen wie T1/E1/J1 zu verwenden. T1 ist in den USA sehr verbreitet, während E1 in Europa und J1 in Japan üblich ist. Diese Arten von Kanälen ermöglichen eine gute Dichte an Leitungen – 24 pro T1-Kanal und 30 für E1-Kanäle.

In Lateinamerika, China und Afrika ist es üblich, eine Art von Channel Associated Signaling (CAS) zu verwenden, das als MFC/R2 bekannt ist. Dieses Kapitel untersucht, wie MFC/R2 unter Verwendung der Bibliothek OpenR2 implementiert wird. In den USA und Europa ist Integrated Services Digital Networks (ISDN) PRI die gebräuchlichste Signalisierung. Das Kapitel wird auch das ISDN Basic Rate Interface (BRI) diskutieren, das in Europa bei Anwendungen im mittleren Bereich sehr verbreitet ist.

Alle Beispiele in diesem Buch konzentrieren sich auf DAHDI-Kanäle. Einige Karten werden unter Verwendung proprietärer Kanäle implementiert, daher erkundigen Sie sich bitte bei Ihrem Hersteller nach weiteren Details zur Konfiguration Ihrer spezifischen Karte.

### Ziele

Am Ende dieses Kapitels werden Sie in der Lage sein:

- Die wichtigsten Begriffe der digitalen Telefonie zu erkennen
- CAS- und CCS-Signalisierung zu unterscheiden
- R2- und ISDN-Signalisierung zu unterscheiden
- Schnittstellen mit ISDN-Signalisierung zu konfigurieren
- Schnittstellen mit R2-Signalisierung zu konfigurieren

### E1/T1 digitale Leitungen

Digitale Leitungen E1/T1 sind eine Option, wann immer Sie eine große Anzahl von Kanälen implementieren müssen. Ein einzelner E1-Schaltkreis ist zu 30 gleichzeitigen Anrufen fähig, und Sie können Funktionen wie Direct Inward Dial (DID), Caller ID (Anruferidentifizierung) und erweiterte Signalisierung nutzen. Die E1/T1-Leitung kann je nach Land auf verschiedene Weise in Ihrem Unternehmen ankommen, unter Verwendung von verdrillten Paaren, Glasfaser und Mikrowellen. Digitale Leitungen werden mittels UTP, Glasfaser oder Mikrowellen an Ihr Unternehmen geliefert. Modems und Multiplexer (MUX) werden verwendet, um die physische Leitung bereitzustellen. Die Verbindung zu einer T1-Leitung basiert immer auf einem RJ45-Anschluss. E1-Leitungen können jedoch auch mittels BNC bereitgestellt werden. Es ist sehr wichtig, im Voraus zu wissen, welche Art von Anschluss Sie erhalten werden, hauptsächlich bei E1-Leitungen. Normalerweise wird die gesamte Ausrüstung bis zum RJ45 vom TELCO bereitgestellt.

![Wie E1/T1-Schaltkreise bereitgestellt werden: Der Telco kann den Trunk über UTP-Kupfer (HDSL-Modem für E1 oder eine direkte Kartenverbindung für T1), über Glasfaser durch einen optischen Multiplexer oder über eine Mikrowellen-Funkverbindung liefern.](../images/10-legacy-fig05.png)

![UTP oder BNC? Die meisten digitalen Karten verwenden RJ45 (UTP)-Anschlüsse, aber einige E1-Leitungen werden über duale BNC-Koaxialkabel geliefert, in welchem Fall ein Balun benötigt wird, um das Koaxialpaar an die RJ45-Buchse der Karte anzupassen.](../images/10-legacy-fig06.png)

#### Wie wird die Stimme in Bits umgewandelt?

Das analoge Signal wird 8.000 Mal pro Sekunde abgetastet, um eine digitale Version der analogen Stimme zu erstellen. Diese Kodierung ist als Pulse Code Modulation (PCM) bekannt. In den USA und Japan wird das Signal unter Verwendung von law (in Asterisk als ulaw bezeichnet) kodiert. Im Rest der Welt ist die Kodierung alaw.

![Pulse Code Modulation (PCM): Das 4 kHz analoge Sprachsignal wird 8.000 Mal pro Sekunde abgetastet (Nyquist) und in einen digitalen 64 Kbps Bitstrom kodiert.](../images/10-legacy-fig07.png)

#### Zeitmultiplexverfahren (Time Division Multiplexing)

Analoge Leitungen sind sinnvoll, wenn Sie nur wenige Kanäle benötigen. Bei der Verwendung von Time Division Multiplexing (TDM) ist es möglich, mehrere Kanäle in eine einzige Datenverbindung zu packen. Wenn Sie eine große Anzahl von Leitungen wünschen, stellt Ihnen die Telefongesellschaft normalerweise einen digitalen Trunk zur Verfügung, bei dem es sich um einen Datenstrom handelt, in dem die Stimme in einem digitalen Format mittels PCM transportiert wird. Jeder Zeitschlitz verwendet 64 Kbps Bandbreite, um einen einzelnen Sprachkanal zu transportieren.

![Time-Division Multiplexing bei E1 und T1: Ein E1-Frame überträgt 32 Zeitschlitze bei 2048 Kbps (DS0 #0 für Frame-Synchronisation, DS0 #16 für Signalisierung), während ein T1-Frame 24 Zeitschlitze bei 1544 Kbps überträgt, wobei ein Bit für die Synchronisation und ein Robbed-Bit-Schema für die Signalisierung verwendet wird.](../images/10-legacy-fig08.png)

In den USA ist der gebräuchlichste digitale Trunk T1, der über 24 verfügbare Leitungen verfügt; in Europa und Lateinamerika haben E1-Trunks 30 Leitungen. Einige Unternehmen bieten einen fraktionierten T1/E1 mit weniger Kanälen an. Robbed Bit Signaling: Manchmal verwendet ein T1-Trunk ein Robbed-Bit-Schema, bei dem ein Bit für die Signalisierung ausgeliehen wird. Bei T1-Trunks wird der Daten-/Sprachkanal mit 56 Kbps auf jedem Zeitschlitz übertragen. Wie Sie vielleicht feststellen, verliert der T1-Schaltkreis bei Verwendung des Robbed-Bits keine zwei Schlitze für Synchronisation und Signalisierung.

#### T1/E1 Leitungskodierung

T1s und E1s sind eigentlich Datenleitungen und haben eine Datenkodierung, die bestimmt, wie die Bits interpretiert werden. Für E1s ist der gebräuchlichste Leitungscode HDB3 für Layer 1 und CCS für Layer 2. Der einfachste Weg, um herauszufinden, wie Ihr digitaler Trunk konfiguriert ist, besteht darin, den TELCO nach diesen Informationen zu fragen. Sie benötigen diese Informationen, um die Datei /etc/dahdi/system.conf zu konfigurieren.

#### T1/E1 Signalisierung

Es ist wichtig zu verstehen, dass T1/E1-Leitungen mit verschiedenen Arten der Signalisierung geliefert werden können, wie zum Beispiel:

- T1 mit Robbed-Bit-Signalisierung
- T1 mit ISDN-Signalisierung
- E1 mit MFC/R2 (CAS - Channel Associated Signaling)
- E1 mit ISDN-Signalisierung

ISDN wird oft in Europa und den USA verwendet. Es ist ein digitales Sprachnetzwerk, das 1984 von der International Telecommunications Union (ITU) standardisiert wurde. ISDN bietet zwei Arten von Kanälen:

- Bearer-Kanäle
  - Stimme
  - Daten
- Datenkanäle
  - Out-of-Band-Signalisierung
  - LAPD-Signalisierung
  - Q.931

Normalerweise wird eine ISDN-Leitung über zwei physische Wege bereitgestellt:

- Basic Rate Interface (BRI)
  - Bekannt als 2B+D
  - Zwei Bearer-Kanäle (64K) und ein Datenkanal (16K)
  - Verwendet ein Paar Kupferdrähte mit 148Kbps.
- Primary Rate Interface (PRI)
  - Geliefert über einen T1/E1-Trunk
  - 23B+D für T1s
  - 30B+D für E1s

Manchmal verwenden E1-Schaltkreise ein CAS-Signalisierungsschema namens MFC/R2, das von der ITU als Standard Q.421/Q441 definiert wurde. Dies ist häufig in Lateinamerika und Asien anzutreffen. Mehrere Telefongesellschaften in diesen Ländern verwenden angepasste Varianten von MFC/R2. Daher müssen Sie die korrekte Ländervariante kennen, damit es funktioniert.

### ISDN BRI

Kanäle, die ISDN BRI-Signalisierung verwenden, sind in Europa sehr beliebt. Die meisten ISDN BRI-Karten für Asterisk unterstützen eine S/T-Schnittstelle mit NT- und TE-Fähigkeiten. Die TE (Terminal)-Verbindung wird verwendet, um eine Verbindung zum TELCO oder zu anderen PBXs herzustellen, die als Network Termination (NT) konfiguriert sind. Der NT wird verwendet, um Telefone und PBXs anzuschließen, die als TE konfiguriert sind. ISDN BRI bietet zwei Daten-/Sprachkanäle und einen Signalisierungskanal. ISDN BRI-Karten sind von verschiedenen Anbietern von Schnittstellenkarten für Asterisk erhältlich.

### Auswahl einer Telefoniekarte für Ihren Asterisk-Server

Es gibt mehrere Hersteller für digitale Karten, die mit Asterisk kompatibel sind. Die Wahl einer Karte hängt von einigen der folgenden Faktoren ab:

#### Datenbus

Es gibt verschiedene Arten von Bussen auf Ihrem PC. Es ist sehr wichtig, dass Sie die richtige Karte für Ihren Server haben. Der folgende Überblick skizziert die am häufigsten verwendeten Karten:

- 32 Bit PCI 5V, zu finden in den meisten Computern, einschließlich Desktops
  - Sangoma (ehemals Digium) TE405, TE407, TE205, TE207, TE120, TE122, B410, TDM2400, TDM800, TDM410 und TC400
  - Sangoma A101, A102 und A104
- 32/64 Bit PCI 3.3V, grundsätzlich in Servern zu finden
  - Sangoma (ehemals Digium) TE410, TE412, TE210, TE212, TE120, TE122, B410, TDM2400, TDM800, TDM410 und TC400
- PCI Express, zu finden auf Desktops und Servern
  - Sangoma (ehemals Digium) TE420, TE220, TE121, AEX2400 und AEX800
  - Sangoma A101, A102 und A104

Diese Kartenfamilien stammten von Digium, das 2018 von Sangoma übernommen wurde; sie werden jetzt unter der Marke Sangoma verkauft und unterstützt. Viele der hier aufgeführten älteren SKUs wurden eingestellt, bestätigen Sie daher die Verfügbarkeit aktueller Modelle unter www.sangoma.com vor dem Kauf.

- MiniPCI, zu finden in eingebetteten Systemen
  - OpenVOX A100M(FXO), B100M(ISDN BRI), B200M(ISDN BRI) und B400M(ISDN BRI)
- USB 2.0, zu finden in den meisten modernen PCs. Lösungen auf USB-Basis ermöglichen eine hohe Dichte an analogen und digitalen Kanälen. Dieser Bus unterstützt 480 Mbps, und jeder Sprachkanal belegt 64 Kbps. Bei der Verwendung von USB-Hubs ist es möglich, Dichten von bis zu tausend analogen Ports an einem einzigen Port zu erreichen.
  - Xorcom Astribank (FXS, FXO, E1-ISDN, E1-R2)
- Ethernet. Der größte Vorteil von Ethernet besteht darin, dass die Karte von mehr als einem Server verbunden werden kann. Hochverfügbarkeitslösungen sind normalerweise die Kernanwendung für diese Geräte. Die Stärke dieser Lösung ist die Verwendung von Servern ohne freie PCI-Steckplätze oder Blade-Server.
  - Redfone FoneBridge (bis zu vier E1-Schaltkreise)

### Verwendung von Hardware-Echokompensation

Hardware-Echokompensation reduziert die Last der Host-CPU. Bei Karten mit mehr als einer E1-Schnittstelle kann Hardware-Echokompensation helfen, Ihren Prozessor zu entlasten. Neue verbesserte Software-Echokompensatoren wie der OSLEC reduzieren den Bedarf an einem Hardware-Echokompensator. Um zwischen Hardware- und Software-Echokompensatoren zu wählen, sollten Sie die verfügbare Rechenleistung Ihres Servers und die Anzahl der E1-Schaltkreise berücksichtigen. Ein Echokompensationsprozess kann bis zu neun MIPS (Millionen Instruktionen pro Sekunde) pro Sprachkanal mit 128 Taps Amplitude unter Verwendung von OSLEC verbrauchen (Referenz: Xorcom Ltd.). Wenn man 1 CPU-Zyklus pro Instruktion annimmt (was basierend auf dem Prozessor und der Softwareimplementierung selbst nicht immer korrekt ist), sprechen wir von 1,080 GHz für vier E1s.

#### Art der Signalisierung

Die Auswahl der Signalisierungsart (z. B. T1 CAS, T1 PRI, E1 CAS R2 oder E1 CAS ISDN) ist keine leichte Aufgabe. Es hängt wirklich davon ab, was in Ihrer Gegend verfügbar ist und zu welchem Preis. Common Channel Signaling (CCS) ist oft besser als Channel Associated Signaling (CAS). Es ist jedoch oft nicht verfügbar. In den USA können Sie normalerweise wählen, da die meisten TELCOS T1 CAS für normale Benutzer und T1 PRI für fortgeschrittene Benutzer (z. B. Callcenter) anbieten. In Lateinamerika ist E1 CAS R2 vorherrschend, aber ISDN PRI ist in einigen Städten verfügbar.

![Die DAHDI-Softwarearchitektur: Asterisk kommuniziert mit dem `chan_dahdi` Kanaltreiber, der wiederum die Protokollbibliotheken libpri (ISDN), libopenr2 (MFC/R2) und libss7 (SS7) lädt; diese sitzen auf der `/dev/dahdi` Schnittstelle, dem DAHDI-Kernel-Treiber und dem kartenspezifischen Schnittstellen-Kernel-Treiber.](../images/10-legacy-fig09.png)

Die Implementierung von R2 ist für die Installation einer Bibliothek namens OpenR2 (www.libopenr2.org) erforderlich, die von Moises Silva entwickelt wurde, sowie für das Patchen von Asterisk vor der Installation – ein einfaches Verfahren, das später in diesem Kapitel gezeigt wird. Die Bibliothek hat mehrere Tests bestanden und ist bei mehreren unserer Kunden im produktiven Einsatz. ISDN ist meiner Meinung nach immer die beste Wahl, falls verfügbar. Einige Anbieter haben möglicherweise Zugriff auf Signaling System 7 (SS7), eine CCS-Signalisierung, die zwischen Telefongesellschaften verfügbar ist. Proprietäre und Open-Source-Lösungen sind für SS7 verfügbar. Die Bibliothek libss7 wird verwendet, um SS7 auf Asterisk zu unterstützen.

### Einrichtung der Asterisk-Telefoniekanäle

Die Konfiguration einer Telefonie-Schnittstellenkarte umfasst mehrere notwendige Schritte. In diesem Kapitel zeigen wir drei der häufigsten Szenarien:

- Digitale Verbindung mittels ISDN PRI
- Digitale Verbindung mittels ISDN BRI
- Digitale Verbindung mittels MFC/R2

Es gibt zwei Möglichkeiten, DAHDI-Kanäle zu konfigurieren. Die erste besteht darin, sie manuell mit voller Kontrolle über alle Parameter zu konfigurieren. Die zweite Möglichkeit besteht darin, das Dienstprogramm dahdi_genconf zu verwenden, um die Karten zu erkennen und zu konfigurieren.

#### Automatische Erkennung und Konfiguration

Dank des DAHDI-Entwicklungsteams haben wir jetzt eine automatische Erkennung und Konfiguration der Karten. Schritt 1: Um die Konfiguration automatisch zu generieren, verwenden Sie das Dienstprogramm dahdi_genconf, das die Karte erkennt und die Dateien /etc/dahdi/system.conf und dahdi-channels.conf generiert.

```
dahdi_genconf
```

Schritt 2: Fügen Sie in der letzten Zeile der Datei chan_dahdi.conf die Datei dahdi-channels.conf hinzu.

```
#include dahdi_channels.conf
```

Schritt 3: Kommentieren Sie alle ungenutzten Module in der Datei modules aus oder verwenden Sie einfach:

```
dahdi_genconf modules
```

#### Manuelle Konfiguration

Eine weitere Option ist die manuelle Konfiguration der Schnittstellen. Nachfolgend finden Sie einige Beispiele für die Konfiguration von DAHDI-Kanälen.

##### Beispiel #1 – Zwei T1/E1-Kanäle mittels ISDN

Erforderliche Schritte:

1. TE205P oder TE210P Installation
2. `/etc/dahdi/system.conf` Dateikonfiguration
3. DAHDI-Treiber laden
4. `dahdi_test` Dienstprogramm
5. `dahdi_cfg` Dienstprogramm
6. `chan_dahdi.conf` Dateikonfiguration
7. Asterisk laden und testen

Schritt 1: TE205P Installation. Vor der Installation der TE205P ist es wichtig, die Unterschiede zwischen den Karten TE205P und TE210P zu verstehen. Die TE210P-Karte verwendet einen 64-Bit-Bus, der mit 3,3 Volt betrieben wird und fast nur auf Server-Mainboards zu finden ist. Seien Sie vorsichtig, wenn Sie diese Schnittstellenkarte spezifizieren; stellen Sie sicher, dass Ihre Hardware einen 64-Bit, 3,3V-Bus unterstützt. Die TE205P-Karte verwendet einen 5V PCI, der oft in Desktop-Computern zu finden ist. Wir haben die TE205P-Schnittstellenkarte mit zwei Spans für dieses Beispiel gewählt, da es einfacher ist, sie auf eine Karte mit einem Span zu reduzieren oder auf eine Karte mit vier Spans zu erweitern. Diese Karten werden jetzt unter der Marke Sangoma (ehemals Digium) verkauft.

![Eine Sangoma/Digium TE205P Dual-Span E1/T1-Karte: Die beiden RJ45-Ports akzeptieren die digitalen Trunks, und ein On-Board-Jumper (der E1/T1/J1-Wahlschalter) stellt den Leitungsstandard ein.](../images/10-legacy-fig10.png)

```
Step 2: /etc/dahdi/system.conf configuration file
```

Die Konfiguration von digitalen TDM-Karten unterscheidet sich ein wenig von der Konfiguration ihrer analogen Gegenstücke. Zuerst müssen wir die Board-Spans und dann die Kanäle konfigurieren. Spans werden sequenziell nummeriert, abhängig von der Erkennungsreihenfolge der Karten. Mit anderen Worten, wenn Sie mehr als eine Schnittstellenkarte haben, ist es schwer zu wissen, welcher Span zu welcher gehört. Verwenden Sie dahdi_hardware, um zu überprüfen, welche Hardware auf welchem Span installiert ist. Beispiel #1 (2xT1 PRI)

```
span=1,1,0,esf,b8zs
span=2,0,0,esf,b8zs
bchan=1-23
dchan=24
bchan=25-47
dchan=48
defaultzone=us
loadzone=us
```

Beispiel #2 (2xE1 PRI)

```
span=1,1,0,ccs,hdb3,crc4 # not always necessary, consult Telco.
span=2,0,0,ccs,hdb3,crc4
bchan=1-15, 17-31
dchan=16
bchan=33-47, 49-63
dchan=48
defaultzone=br
loadzone=br
```

Beispiel #3 (4xBRI)

```
loadzone=de
defaultzone=de
span=1,1,0,ccs,ami
bchan=1,2
hardhdlc=3
span=2,0,0,ccs,ami
bchan=4,5
hardhdlc=6
span=3,0,0.ccs.ami
bchan=7,8
hardhdlc=9
span=4,0,0,ccs,ami
bchan=10,11
hardhdlc=12
```

Schritt 3: Kernel-Treiber laden. Überprüfen Sie mit dahdi_hardware, welchen Treiber Sie installieren müssen.

```
dahdi_hardware
pci:0000:04:02.0     wcte2xxp    e159:0001 Sangoma Wildcard TE205P T1/E1 Board
```

Zum Laden verwenden Sie:

```
modprobe dahdi
modprobe wct2xxp
```

Schritt 4: Überprüfung auf fehlende Interrupts mit dahdi_test. Sie können die Anzahl der Interrupt-Verluste mit dem Dienstprogramm dahdi_test überprüfen, das mit den DAHDI-Karten kompiliert wurde. Eine Zahl unter 99,987% deutet auf mögliche Probleme hin. Sie finden dahdi_test in

```
/usr/sbin.
#./dahdi_test
Opened pseudo zap interface, measuring accuracy...
99.987793% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 99.987793% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000%
--- Results after 26 passes ---
Best: 100.000000 -- Worst: 99.987793 -- Average: 99.999061
```

Schritt 5: Verwendung des Dienstprogramms dahdi_cfg. Dies ist die korrekte Ausgabe von dahdi_cfg für einen fraktionierten E1-Span (15 Ports) und zwei FXO-Ports.

```
#./dahdi_cfg -vvvv
Dahdi configuration
======================
SPAN 1: CCS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: Clear channel (Default) (Slaves: 01)
Channel 02: Clear channel (Default) (Slaves: 02)
Channel 03: Clear channel (Default) (Slaves: 03)
Channel 04: Clear channel (Default) (Slaves: 04)
Channel 05: Clear channel (Default) (Slaves: 05)
Channel 06: Clear channel (Default) (Slaves: 06)
Channel 07: Clear channel (Default) (Slaves: 07)
Channel 08: Clear channel (Default) (Slaves: 08)
Channel 09: Clear channel (Default) (Slaves: 09)
Channel 10: Clear channel (Default) (Slaves: 10)
Channel 11: Clear channel (Default) (Slaves: 11)
Channel 12: Clear channel (Default) (Slaves: 12)
Channel 13: Clear channel (Default) (Slaves: 13)
Channel 14: Clear channel (Default) (Slaves: 14)
Channel 15: Clear channel (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
16 channels configured.
```

Schritt 6: Konfiguration von DAHDI in der Datei /etc/asterisk/chan_dahdi.conf. Beispiel #1 (2xT1)

```
callerid="John Doe"<(555)555-1111>
switchtype=national
signalling =pri_cpe
context=from-pstn
group = 1
channel => 1-23
group =2
channel => 25-47
```

Beispiel #2 (2xE1)

```
callerid="Flavio Eduardo" <4830258580>
switchtype=euroisdn
signalling = pri_cpe
group = 1
channel => 1-15;17-31
group =2
channel => 32-46;48-62
```

Beispiel #3 (4xBRI)

```
signaling=bri_cpe
switchtype=euroisdn
group=1
context=from-pstn
channel=>1,2,4,5,7,8,10,11
```

Verwenden Sie signaling=bri_cpe_ptmp für Punkt-zu-Mehrpunkt-BRI. Derzeit wird BRI Punkt-zu-Mehrpunkt im NT-Modus nicht unterstützt.

#### Laden der Kernel-Treiber

Nach der Konfiguration der Treiber können Sie den Server einfach neu starten. Wenn Sie DAHDI mit make config installiert haben, müssen Sie nichts weiter tun. Der Kernel-Treiber wird automatisch geladen und konfiguriert. Manchmal ist es jedoch nützlich, die Treiber manuell zu laden und zu entladen. Beispiel:

```
modprobe wct11xp
dahdi_cfg -vvvvv
```

Der erste Befehl lädt den Treiber und der zweite, dahdi_cfg, wendet die Konfiguration auf den Kernel-Treiber an.

### Fehlerbehebung

Manchmal funktionieren Dinge nicht beim ersten Mal. Lassen Sie uns einige Ressourcen zur Fehlerbehebung bei DAHDI überprüfen. Schritt 1: Überprüfen Sie, ob die Karte vom Betriebssystem erkannt wird. Sangoma/Digium-Karten werden normalerweise als ISDN-Modem erkannt.

```
lspci -v
00:00.0 Host bridge: Intel Corporation E7230/3000/3010 Memory Controller Hub
00:01.0 PCI bridge: Intel Corporation E7230/3000/3010 PCI Express Root Port
00:1c.0 PCI bridge: Intel Corporation 82801G (ICH7 Family) PCI Express Port 1 (rev 01)
00:1c.4 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 5 (rev
01)
00:1c.5 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 6 (rev
01)
00:1d.0 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #1 (rev
01)
00:1d.1 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #2 (rev
01)
00:1d.2 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #3 (rev
01)
00:1d.7 USB Controller: Intel Corporation 82801G (ICH7 Family) USB2 EHCI Controller (rev 01)
00:1e.0 PCI bridge: Intel Corporation 82801 PCI Bridge (rev e1)
00:1f.0 ISA bridge: Intel Corporation 82801GB/GR (ICH7 Family) LPC Interface Bridge (rev 01)
00:1f.1 IDE interface: Intel Corporation 82801G (ICH7 Family) IDE Controller (rev 01)
00:1f.2 IDE interface: Intel Corporation 82801GB/GR/GH (ICH7 Family) SATA IDE Controller (rev
01)
00:1f.3 SMBus: Intel Corporation 82801G (ICH7 Family) SMBus Controller (rev 01)
01:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
01:00.1 PIC: Intel Corporation 6700/6702PXH I/OxAPIC Interrupt Controller A (rev 09)
02:08.0 SCSI storage controller: LSI Logic / Symbios Logic SAS1068 PCI-X Fusion-MPT SAS (rev
01)
03:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
04:02.0 Network controller: Tiger Jet Network Inc. Tiger3XX Modem/ISDN interface
05:00.0 Ethernet controller: Broadcom Corporation NetXtreme BCM5721 Gig. Eth.PCI Express (rev
11)
07:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL-8139/8139C/8139C+ (rev 10)
07:05.0 VGA compatible controller: ATI Technologies Inc ES1000 (rev 02)
```

Schritt 2: Überprüfen Sie mit folgendem Befehl, ob der Kernel-Treiber korrekt geladen wird:

```
modprobe wct11xp
dmesg
TE110P: Setting up global serial parameters for E1 FALC V1.2
TE110P: Successfully initialized serial bus for card
TE110P: Span configured for CAS/HDB3
Calling startup (flags is 4099)
Found a Wildcard: Sangoma Wildcard TE110P T1/E1
TE110P: Span configured for CCS/HDB3/CRC4
Calling startup (flags is 4099)
dahdi: Registered tone zone 0 (United States / North America)
wcte1xxp: Setting yellow alarm
```

Schritt 3: Überprüfen Sie den Status der Alarme in Bezug auf die physische Schicht der Verbindung. Um die physische Schicht der E1-Verbindung zu überprüfen, können Sie den folgenden Asterisk CLI-Befehl verwenden.

```
dahdi show status
```

Die Alarme zeigen Probleme mit dem Port an: Roter Alarm: Kann die Synchronisation mit dem Remote-Switch nicht aufrechterhalten. Dies ist normalerweise ein physisches Problem, wie z. B. eine Nichtübereinstimmung von Leitungscode oder Framing. Gelber Alarm: Signalisierte, dass sich der Remote-Switch im roten Alarm befindet. Dies zeigt an, dass der Remote-Switch Ihre Übertragungen nicht empfängt. Blauer Alarm: Empfängt alle unframed 1s auf allen Zeitschlitzen; dahdi_tool erkennt derzeit keinen blauen Alarm. Loopback: Der Port befindet sich entweder im lokalen oder Remote-Loopback.

```
vtsvoffice*CLI> dahdi show status
Description                              Alarms     IRQ        bpviol     CRC4
Sangoma Wildcard E100P E1/PRA Card 0      OK         0          0          0
Wildcard X100P Board 1                   OK         0          0          0
Wildcard X100P Board 2                   RED        0          0          0
```

Schritt 4: Um Probleme mit DAHDI auf dem Asterisk-Server zu erkennen, überprüfen Sie zuerst mit folgendem Befehl, ob die Kanäle erkannt werden:

```
dahdi show channels
pabxip01*CLI> dahdi show channels
   Chan Extension  Context         Language   MOH Interpret
 pseudo            default                    default
      1            from-pstn                  default
      2            from-pstn                  default
      3            from-pstn                  default
      4            from-pstn                  default
      5            from-pstn                  default
      6            from-pstn                  default
      7            from-pstn                  default
      8            from-pstn                  default
      9            from-pstn                  default
     10            from-pstn                  default
     11            from-pstn                  default
     12            from-pstn                  default
     13            from-pstn                  default
     14            from-pstn                  default
     15            from-pstn                  default
     17            from-pstn                  default
     18            from-pstn                  default
     19            from-pstn                  default
     20            from-pstn                  default
     21            from-pstn                  default
     22            from-pstn                  default
     23            from-pstn                  default
     24            from-pstn                  default
     25            from-pstn                  default
     26            from-pstn                  default
     27            from-pstn                  default
     28            from-pstn                  default
     29            from-pstn                  default
     30 2171       from-pstn                  default
     31 2171       from-pstn                  default
```

Schritt 5: Überprüfen Sie den Status der ISDN-Schicht 3, auch bekannt als q.931. Sie können überprüfen, ob die ISDN-Schicht 3 aktiv ist, indem Sie `pri show spans` (um alle Spans aufzulisten) oder `pri show span <n>` für einen bestimmten Span verwenden:

```
vtsvoffice*CLI> pri show span 1
Primary D-channel: 16
Status: Provisioned, Up, Active
Switchtype: EuroISDN
Type: CPE
Window Length: 0/7
Sentrej: 0
SolicitFbit: 0
Retrans: 0
Busy: 0
Overlap Dial: 0
T200 Timer: 1000
T203 Timer: 10000
T305 Timer: 30000
T308 Timer: 4000
T313 Timer: 4000
N200 Counter: 3
```

Verwenden Sie `pri show spans` (Plural), um den Status aller konfigurierten PRI-Spans auf einmal aufzulisten.

Überprüfen Sie einen bestimmten Kanal. dahdi show channel x:

```
vtsvoffice*CLI> dahdi show channel 1
Channel: 1
File Descriptor: 21
Span: 1
Extension:
Dialing: no
Context: entrada
Caller ID: 4832341689
Calling TON: 33
Caller ID name:
Destroy: 0
InAlarm: 0
Signalling Type: PRI Signalling
Radio: 0
Owner: <None>
Real: <None>
Callwait: <None>
Threeway: <None>
Confno: -1
Propagated Conference: -1
Real in conference: 0
DSP: no
Relax DTMF: no
Dialing/CallwaitCAS: 0/0
Default law: alaw
```

debug pri span x: Wenn Sie nach allem immer noch Probleme haben, beginnen Sie mit dem Debuggen des PRI-Spans. Dieser Befehl ermöglicht ein detailliertes Debugging von ISDN-Anrufen. Es ist ein wichtiger Befehl, wenn Sie glauben, dass etwas nicht korrekt ist. Sie können falsch gewählte Ziffern und andere Probleme erkennen. Nachfolgend präsentieren wir das Beispiel einer Debugging-Ausgabe für einen erfolgreichen Anruf. Beziehen Sie sich auf dieses Beispiel, wenn Sie einen nicht erfolgreichen Anruf mit einem fehlerfreien vergleichen müssen. Ein Tipp ist die Verwendung von core set verbose=0, um nur die ISDN q.931-Nachrichten zu erhalten.

```
-- Making new call for cr 32833
> Protocol Discriminator: Q.931 (8)  len=57
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: SETUP (5)
> [04 03 80 90 a3]
> Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
>                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
>                              Ext: 1  User information layer 1: A-Law (35)
> [18 03 a9 83 81]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 1 ]
> [28 0e 46 6c 61 76 69 6f 20 45 64 75 61 72 64 6f]
> Display (len=14) @h@>[ Flavio Eduardo ]
> [6c 0c 21 80 34 38 33 30 32 35 38 35 39 30]
> Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
>                           Presentation: Presentation permitted, user number not screened
(0) '4830258590' ]
> [70 09 a1 33 32 32 34 38 35 38 30]
> Called Number (len=11) [ Ext: 1  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '32248580' ]
> [a1]
> Sending Complete (len= 1)
< Protocol Discriminator: Q.931 (8)  len=10
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CALL PROCEEDING (2)
< [18 03 a9 83 81]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 1 ]
-- Processing IE 24 (cs0, Channel Identification)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: ALERTING (1)
< [1e 02 84 88]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Inband information or
appropriate pattern now available. (8) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=64
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: SETUP (5)
< [04 03 80 90 a3]
< Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
<                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
<                              Ext: 1  User information layer 1: A-Law (35)
< [18 03 a1 83 82]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Preferred Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 2 ]
< [1c 15 91 a1 12 02 01 bc 02 01 0f 30 0a 02 01 01 0a 01 00 a1 02 82 00]
< Facility (len=23, codeset=0) [ 0x91, 0xa1, 0x12, 0x02, 0x01, 0xbc, 0x02, 0x01, 0x0f, '0',
0x0a, 0x02, 0x01, 0x01, 0x0a, 0x01, 0x00, 0xa1, 0x02, 0x82, 0x00 ]
< [1e 02 82 83]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the local user (2)
<                               Ext: 1  Progress Description: Calling equipment is non-ISDN.
(3) ]
< [6c 0c 21 83 34 38 33 32 32 34 38 35 38 30]
< Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
<                           Presentation: Presentation allowed of network provided number (3)
'4832248580' ]
< [70 05 c1 38 35 38 30]
< Called Number (len= 7) [ Ext: 1  TON: Subscriber Number (4)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '8580' ]
< [a1]
< Sending Complete (len= 1)
-- Making new call for cr 5720
-- Processing Q.931 Call Setup
-- Processing IE 4 (cs0, Bearer Capability)
-- Processing IE 24 (cs0, Channel Identification)
-- Processing IE 28 (cs0, Facility)
Handle Q.932 ROSE Invoke component
-- Processing IE 30 (cs0, Progress Indicator)
-- Processing IE 108 (cs0, Calling Party Number)
-- Processing IE 112 (cs0, Called Party Number)
-- Processing IE 161 (cs0, Sending Complete)
> Protocol Discriminator: Q.931 (8)  len=10
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CALL PROCEEDING (2)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> Protocol Discriminator: Q.931 (8)  len=14
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CONNECT (7)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> [1e 02 81 82]
> Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Private network serving the local user (1)
>                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: CONNECT ACKNOWLEDGE (15)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: PROGRESS (3)
< [1e 02 84 82]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CONNECT (7)
> Protocol Discriminator: Q.931 (8)  len=5
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: CONNECT ACKNOWLEDGE (15)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Active, peerstate Connect Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: DISCONNECT (69)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: RELEASE (77)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Release Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: RELEASE COMPLETE (90)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: DISCONNECT (69)
< [08 02 82 90]
< Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Public network
serving the local user (2)
<                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
-- Processing IE 8 (cs0, Cause)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Disconnect Indication, peerstate Disconnect
Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: RELEASE (77)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: RELEASE COMPLETE (90)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
```

### Konfigurationsoptionen in chan_dahdi.conf

Im Datein chan_dahdi.conf sind verschiedene Optionen verfügbar. Eine Beschreibung aller Optionen wäre langweilig und kontraproduktiv. Hier werden wir die wichtigsten Optionsgruppen detailliert beschreiben, um ein besseres Verständnis zu ermöglichen.

#### Allgemeine Optionen (kanalunabhängig)

context: Definiert den eingehenden Kontext.

```
context=default
```

channel: Definiert den Kanal oder Kanalbereich. Jede Kanaldefinition erbt Optionen, die vor der Deklaration definiert wurden. Kanäle können einzeln oder in derselben Zeile durch Kommas getrennt identifiziert werden. Bereiche können mit „-“ definiert werden.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Ermöglicht es, Kanäle als Gruppe zu behandeln. Wenn Sie eine Gruppennummer anstelle einer Kanalnummer wählen, wird der erste verfügbare Kanal verwendet. Wenn es sich bei den Kanälen um Telefone handelt, klingeln bei einem Anruf einer Gruppe alle Telefone gleichzeitig. Durch Kommas können Sie mehr als eine Gruppe für denselben Kanal angeben.

```
group=1
group=3,5
```

language: Aktiviert die Internationalisierung und konfiguriert eine Sprache. Diese Funktion konfiguriert Systemmeldungen für eine bestimmte Sprache. Englisch ist die einzige Sprache mit vollständigen Prompts, die in der Standardinstallation verfügbar sind. musiconhold: Wählt die Musik-in-Warteschleife-Klasse aus.

#### ISDN-Optionen

switchtype: Ist abhängig von der verwendeten PBX oder dem Switch. In Europa und Lateinamerika ist EuroISDN üblich.

- 5ess: Lucent 5ESS
- euroisdn: EuroISDN
- national: National ISDN
- dms100: Nortel DMS100
- 4ess: AT&T 4ESS
- Qsig: Q.SIG

```
switchtype = EuroISDN
```

pridialplan: Erforderlich für einige Switches, die eine Dialplan-Spezifikation benötigen. Diese Option wird von vielen Switches ignoriert. Die gültigen Optionen sind private, national, international und unknown.

```
pridialplan = unknown
```

prilocaldialplan: Notwendig für einige Switches, normalerweise unknown.

```
prilocaldialplan = unknown
```

overlapdial: Overlap-Dialing wird verwendet, wenn Sie Ziffern übergeben, nachdem die Verbindung hergestellt wurde. Sie können den Block-Modus (overlapdial=no) oder den Ziffern-Modus (overlapdial=yes) verwenden. Der Block-Modus wird oft von Betreibern verwendet. signaling: Konfiguriert den Signalisierungstyp für die nachfolgenden Kanäle. Diese Parameter sollten denen in der Datei chan_dahdi.conf entsprechen. Korrekte Entscheidungen basieren auf dem verfügbaren Kanal. Für ISDN können Sie fünf Optionen wählen:

- pri_cpe: Wird verwendet, wenn das Gerät ein CPE ist, manchmal als Client, Benutzer oder Slave bezeichnet. Dies ist die einfachste und am häufigsten verwendete Form der Signalisierung. Manchmal, wenn Sie versuchen, eine Verbindung zu einer privaten PBX herzustellen, wurde die PBX ebenfalls als CPE konfiguriert. Verwenden Sie in diesem Fall pri_net-Signalisierung in Asterisk.
- pri_net: Wird verwendet, wenn Asterisk mit einer privaten PBX verbunden ist, die als CPE konfiguriert ist. Die Signalisierung wird oft als Host, Master oder Netzwerk bezeichnet.
- bri_cpe: Wird verwendet, wenn Asterisk als CPE mit einem ISDN BRI-Trunk verbunden ist.
- bri_net: Wird verwendet, wenn Asterisk mit einem ISDN-Telefon oder einer PBX verbunden ist, die als Terminal (TE) konfiguriert ist.
- bri_cpe_ptmp: Dasselbe wie bri_cpe, aber in einer Punkt-zu-Mehrpunkt-Architektur.

#### CallerID-Optionen

Viele Caller ID-Optionen sind verfügbar. Einige können deaktiviert werden, obwohl die meisten standardmäßig aktiviert sind. usecallerid: Aktiviert oder deaktiviert die Caller ID-Übertragung für die nachfolgenden Kanäle (Yes/No). Hinweis: Wenn Ihr System zwei Klingeltöne vor dem Abheben erfordert, versuchen Sie, diese Funktion zu deaktivieren, damit es sofort abhebt. hidecallerid: Verbirgt die Caller ID (Yes/No). calleridcallwaiting: Ermöglicht den Empfang der Caller ID während einer Anklopfanzeige (Yes/No). callerid: Konfiguriert eine Caller ID-Zeichenfolge für einen bestimmten Kanal. Der Anrufer kann bei Trunk-Schnittstellen mit „asreceived“ konfiguriert werden, um die Caller ID weiterzuleiten.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

Hinweis: Die meisten TELCOs schreiben vor, dass Sie Ihre korrekte Caller ID konfigurieren. Wenn Sie nicht die richtige Caller ID übergeben, sollten Sie nicht in der Lage sein, über den TELCO nach außen zu wählen. Andererseits können Sie Anrufe auch ohne Konfiguration der Caller ID empfangen.

#### Audioqualitätsoptionen

Diese Optionen passen bestimmte Asterisk-Parameter an, die die Audioqualität in DAHDI-Kanälen beeinflussen.

- **echocancel**: Deaktiviert oder aktiviert die Echokompensation. Sie sollten diese Funktion aktiviert lassen. Sie akzeptiert "yes" oder die Anzahl der Taps. (Erklärung: Wie funktioniert Echokompensation? Die meisten Echokompensationsalgorithmen arbeiten, indem sie mehrere Kopien eines empfangenen Signals erzeugen, wobei jede um ein kleines Intervall verzögert wird. Dieser kleine Fluss wird "Tap" genannt. Die Anzahl der Taps bestimmt die Echoverzögerung, die kompensiert werden kann. Diese Kopien werden verzögert, angepasst und vom ursprünglichen Signal subtrahiert. Der Trick besteht darin, das verzögerte Signal genau auf das anzupassen, was erforderlich ist, um das Echo zu entfernen.)
- **echocancelwhenbridged**: Aktiviert oder deaktiviert den Echokompensator während eines reinen TDM-Anrufs. Dies ist normalerweise nicht erforderlich.
- **rxgain**: Passt die Audioempfangsverstärkung an, um die Empfangslautstärke zu erhöhen oder zu verringern (-100% bis 100%).
- **txgain**: Passt die Audioübertragungsverstärkung an, um die Übertragungslautstärke zu erhöhen oder zu verringern (-100% bis 100%).

Beispiel:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Abrechnungsoptionen

Diese Optionen ändern die Art und Weise, wie Anrufinformationen in der Datenbank für Anrufdetailaufzeichnungen (CDR) aufgezeichnet werden. amaflags: Beeinflusst die Kategorisierung von CDR. Es akzeptiert diese Werte:

- billing
- documentation
- omit
- default

accountcode: Es konfiguriert einen Kontocode für einen bestimmten Kanal. Er kann jeden alphanumerischen Wert enthalten, normalerweise den Abteilungs- oder Benutzernamen.

```
accountcode=finance
amaflags=billing
```

### MFC/R2 Konfiguration

MFC/R2 wird in mehreren Ländern in Lateinamerika, China und Afrika sowie in einigen europäischen Ländern verwendet. ISDN ist überlegen und wird bevorzugt, falls in Ihrer Gegend verfügbar.

#### Das Problem verstehen

Die Karte, die für die Signalisierung von MFC/R2 verwendet wird, ist dieselbe, die für die Signalisierung von ISDN verwendet wird. Es ist möglich, MFC/R2 auf DAHDI-Kanälen unter Verwendung der Bibliothek namens libopenR2 (www.libopenr2.com) zu verwenden. Diese Bibliothek war vor den Versionen 1.6.2 kein Teil von Asterisk.

##### Das MFC/R2-Protokoll verstehen

Das MFC/R2-Protokoll kombiniert In-Band- und Out-of-Band-Signalisierung. Adresssignalisierung wird In-Band unter Verwendung einer Reihe von Tönen weitergeleitet, während Kanalinformationen über Zeitschlitz 16 als Out-of-Band-Signalisierung übertragen werden.

**Leitungssignalisierung (ITU-T Q.421).** In Zeitschlitz 16 verwendet jeder Sprachkanal vier ABCD-Bits, um seine Zustände und die Anrufsteuerung zu signalisieren. Die Bits C und D werden selten verwendet. In einigen Ländern können sie für die Gebührenerfassung (Impulszählung für die Abrechnung) verwendet werden. In einem normalen Gespräch arbeiten beide Seiten: die Anruferseite und die angerufene Seite. Die Signalisierung von der Anruferseite wird als Vorwärtssignalisierung bezeichnet, während die angerufene Seite die Rückwärtssignalisierung verwendet. Wir bezeichnen Af und Bf für die Vorwärtssignalisierung und Ab und Bb für die Rückwärtssignalisierung.

| Zustand | ABCD vorwärts | ABCD rückwärts |
| --- | --- | --- |
| Leerlauf/Freigegeben | 1001 | 1001 |
| Belegt | 0001 | 1001 |
| Belegungsbestätigung | 0001 | 1101 |
| Angenommen | 0001 | 0101 |
| ClearBack | 0001 | 1101 |
| ClearFwd (vor Clear-Back) | 1001 | 0101 |
| ClearFwd (Trennbestätigung) | 1001 | 1001 |
| Blockiert | 1001 | 1101 |

MFC/R2 wurde von der ITU definiert. Leider haben mehrere Länder den Standard an ihre eigenen Bedürfnisse angepasst. Infolgedessen entstanden Variationen in den Standards zwischen den Ländern.

**Inter-Register-Signale (ITU-T Q.441).** MFC/R2-Signalisierung verwendet eine Kombination aus zwei Tönen. Die Tabellen unten zeigen den ITU-Standard.

Signalgruppe I (vorwärts):

| Beschreibung | Vorwärtssignal |
| --- | --- |
| Ziffer 1 | I-1 |
| Ziffer 2 | I-2 |
| Ziffer 3 | I-3 |
| Ziffer 4 | I-4 |
| Ziffer 5 | I-5 |
| Ziffer 6 | I-6 |
| Ziffer 7 | I-7 |
| Ziffer 8 | I-8 |
| Ziffer 9 | I-9 |
| Ziffer 0 | I-10 |
| Ländercode-Indikator, ausgehender Halb-Echounterdrücker erforderlich | I-11 |
| Ländercode-Indikator, kein Echounterdrücker erforderlich | I-12 |
| Testanruf-Indikator | I-13 |
| Ländercode-Indikator, ausgehender Halb-Echounterdrücker eingefügt | I-14 |
| Nicht verwendet | I-15 |

Signalgruppe II (vorwärts):

| Beschreibung | Vorwärtssignal |
| --- | --- |
| Teilnehmer ohne Priorität | II-1 |
| Teilnehmer mit Priorität | II-2 |
| Wartungsausrüstung | II-3 |
| Reserve | II-4 |
| Operator | II-5 |
| Datenübertragung | II-6 |
| Teilnehmer oder Operator ohne Vorwärtsübertragungseinrichtung | II-7 |
| Datenübertragung | II-8 |
| Teilnehmer mit Priorität | II-9 |
| Operator mit Vorwärtsübertragungseinrichtung | II-10 |
| Reserve | II-11 |
| Reserve | II-12 |
| Reserve | II-13 |
| Reserve | II-14 |
| Reserve | II-15 |

Signalgruppe A (rückwärts):

| Beschreibung | Rückwärtssignal |
| --- | --- |
| Sende nächste Ziffer (n+1) | A-1 |
| Sende vorletzte Ziffer (n-1) | A-2 |
| Adresse vollständig, Umschaltung auf Empfang von Gruppe B-Signalen | A-3 |
| Überlastung im nationalen Netzwerk | A-4 |
| Sende Kategorie des anrufenden Teilnehmers | A-5 |
| Adresse vollständig, Gebühr, Sprachbedingungen einrichten | A-6 |
| Sende vorvorletzte Ziffer (n-2) | A-7 |
| Sende vorvorvorletzte Ziffer (n-3) | A-8 |
| Reserve | A-9 |
| Reserve | A-10 |
| Sende Ländercode-Indikator | A-11 |
| Sende Sprach- oder Unterscheidungsziffer | A-12 |
| Sende Art des Schaltkreises | A-13 |
| Informationen über Verwendung des Echounterdrückers anfordern | A-14 |
| Überlastung in einer internationalen Vermittlungsstelle oder an deren Ausgang | A-15 |

Signalgruppe B (rückwärts):

| Beschreibung | Rückwärtssignal |
| --- | --- |
| Reserve | B-1 |
| Sende speziellen Informationston | B-2 |
| Teilnehmerleitung besetzt | B-3 |
| Überlastung (nach Umschaltung Gruppe A auf B) | B-4 |
| Nicht zugewiesene Nummer | B-5 |
| Teilnehmerleitung frei, Gebühr | B-6 |
| Teilnehmerleitung frei, keine Gebühr | B-7 |
| Teilnehmerleitung außer Betrieb | B-8 |
| Reserve | B-9 |
| Reserve | B-10 |
| Reserve | B-11 |
| Reserve | B-12 |
| Reserve | B-13 |
| Reserve | B-14 |
| Reserve | B-15 |

#### MFC/R2-Sequenz

Die folgende Sequenz veranschaulicht einen Anruf, der von einer Nebenstelle eines Asterisk zu einem Endgerät im PSTN ausgeht. Das PSTN bricht den Anruf ab und beendet die Kommunikation.

![Ein vollständiger MFC/R2-Anruffluss zwischen Asterisk und dem Telco: Leitungssignalisierung (Leerlauf, Belegt, Belegungsbestätigung, Angenommen, Clearback, Clear Forward) wird im Zeitschlitz 16 ausgetauscht, die gewählten Ziffern und Rückwärts-"Sende nächste Ziffer"-Signale (Gruppen I/A/B) reisen In-Band, und die hörbaren Töne erreichen den Teilnehmer.](../images/10-legacy-fig11.png)

### Verwendung des Treibers libopenr2

Das von Moises Silva initiierte Projekt wurde vom Unicall-Kanaltreiber inspiriert, der von Steve Underwood geschrieben wurde. Die OpenR2-Bibliothek ist derzeit die stabilste Softwarelösung für Asterisk. Mit dieser Lösung können wir jede digitale Karte verwenden, die mit DAHDI kompatibel ist. Zuvor waren nur proprietäre Lösungen für MFC/R2 verfügbar; eine der besten, die ich verwendet habe, ist die von Khomp, www.khomp.com.br. In Asterisk 22 ist die MFC/R2-Unterstützung über libopenR2 integriert, wenn die Bibliothek zum Zeitpunkt der Kompilierung vorhanden ist – es ist kein externer Patch erforderlich. Die folgenden Schritte zeigen die historische manuelle Installation als Referenz; auf modernen Systemen installieren Sie `libopenr2-dev` über den Paketmanager Ihrer Distribution, bevor Sie `./configure` ausführen, und aktivieren dann `chan_dahdi` in `make menuselect`.

Die folgenden Schritte bauen openr2 und Asterisk aus ihren aktuellen Git-Repositories auf. Sie werden als Referenz für Standorte beibehalten, die aus dem Quellcode bauen; auf einer modernen Distribution können Sie sie normalerweise vollständig überspringen, indem Sie das Paket `libopenr2-dev` und einen paketierten Asterisk 22-Build installieren, da `chan_dahdi` die R2-Unterstützung direkt gegen libopenr2 ohne externen Patch kompiliert.

Schritt 1: Installieren Sie die benötigten Build-Tools.

```
apt-get install git
```

Schritt 2: Klonen Sie die openr2-Bibliothek und den Asterisk-Quellcode. Auf Asterisk 22 ist kein spezieller gepatchter Baum erforderlich – ein Standard-Checkout baut die R2-Unterstützung, solange libopenr2 vorhanden ist.

```
cd /usr/src
git clone https://github.com/moises-silva/openr2.git
git clone https://github.com/asterisk/asterisk.git
```

Schritt 3: Kompilieren und installieren. Bitte sichern Sie Ihren Server, bevor Sie fortfahren.

```
cd /usr/src/openr2
./configure && make && make install && ldconfig
cd /usr/src/asterisk
./configure && make menuselect && make && make install
```

Hinweis: Führen Sie nicht „make samples“ aus, um ein Überschreiben Ihrer Konfigurationsdateien zu vermeiden.

```
Step 4: Changing the file /etc/dahdi/system.conf:
vim /etc/dahdi/system.conf
```

Nehmen wir an, Sie haben eine Karte mit einer E1-Schnittstelle.

```
span=1,1,0,cas,hdb3
cas=1-15:1101
cas=17-31:1101
dchan=16
loadzone=br
defaultzone=br
```

Schritt 5: Führen Sie den Befehl dahdi_cfg aus, um die Änderungen auf den Treiber anzuwenden:

```
dahdi_cfg -vvvvvvvv
Dahdi Version:SVN-branch-1.4-r4348
Echo Canceller: MG2
Configuration
======================
SPAN 1: CAS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: CAS / User (Default) (Slaves: 01)
Channel 02: CAS / User (Default) (Slaves: 02)
Channel 03: CAS / User (Default) (Slaves: 03)
Channel 04: CAS / User (Default) (Slaves: 04)
Channel 05: CAS / User (Default) (Slaves: 05)
Channel 06: CAS / User (Default) (Slaves: 06)
Channel 07: CAS / User (Default) (Slaves: 07)
Channel 08: CAS / User (Default) (Slaves: 08)
Channel 09: CAS / User (Default) (Slaves: 09)
Channel 10: CAS / User (Default) (Slaves: 10)
Channel 11: CAS / User (Default) (Slaves: 11)
Channel 12: CAS / User (Default) (Slaves: 12)
Channel 13: CAS / User (Default) (Slaves: 13)
Channel 14: CAS / User (Default) (Slaves: 14)
Channel 15: CAS / User (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
Channel 17: CAS / User (Default) (Slaves: 17)
Channel 18: CAS / User (Default) (Slaves: 18)
Channel 19: CAS / User (Default) (Slaves: 19)
Channel 20: CAS / User (Default) (Slaves: 20)
Channel 21: CAS / User (Default) (Slaves: 21)
Channel 22: CAS / User (Default) (Slaves: 22)
Channel 23: CAS / User (Default) (Slaves: 23)
Channel 24: CAS / User (Default) (Slaves: 24)
Channel 25: CAS / User (Default) (Slaves: 25)
Channel 26: CAS / User (Default) (Slaves: 26)
Channel 27: CAS / User (Default) (Slaves: 27)
Channel 28: CAS / User (Default) (Slaves: 28)
Channel 29: CAS / User (Default) (Slaves: 29)
Channel 30: CAS / User (Default) (Slaves: 30)
Channel 31: CAS / User (Default) (Slaves: 31)
31 channels to configure.
-----------------------------------------------------------------------
```

Schritt 5: Ändern Sie die Datei chan_dahdi.conf

```
vim /etc/asterisk/chan_dahdi.conf
[channels]
usecallerid=yes
callwaiting=yes
usecallingpres=yes
callwaitingcallerid=yes
threewaycalling=yes
transfer=yes
canpark=yes
cancallforward=yes
callreturn=yes
echocancel=yes
echotrainning=yes
echocancelwhenbridged=yes
signalling=mfcr2
mfcr2_variant=br
mfcr2_get_ani_first=no
mfcr2_max_ani=20
mfcr2_max_dnis=4
mfcr2_category=national_subscriber
mfcr2_logdir=span1
mfcr2_logging=all
group=1
callgroup=1
pickupgroup=1
callerid=asreceived
context=from-mfcr2
channel => 1-15,17-31
```

Schritt 6: Ändern Sie den Dialplan in der Datei extensions.conf

```
vim /etc/asterisk/extensions.conf
[default]
exten => _XXXXXXXX,1,Set(CALLERID(num)=1145678990)
exten => _XXXXXXXX,n,Dial(DAHDI/g1/${EXTEN},60,tT)
```

Hinweis: Einige TELCOs akzeptieren keine Anrufe ohne Caller ID. Bitte setzen Sie die Caller ID auf eine der DID-Nummern, die vom Betreiber zugewiesen wurden. In einigen Ländern ist dieser Schritt nicht erforderlich. Schritt 7: Testen Sie die Lösung: Rufen Sie nun mit einer Nebenstelle im Kontext from-internal eine beliebige Nummer an und beobachten Sie die Konsole. Überprüfen Sie, ob Fehler auftreten. -- Executing Set("SIP/8564-081ca5d8", "CALLERID(num)=1145678990") in new stack -- Executing Dial("SIP/8564-081ca5d8", "DAHDI/g1/35678899|60|tT") in new stack

#### Debugging von OpenR2

Um Fehler bei Anrufen zu erkennen, können Sie das Debugging aktivieren. Befolgen Sie dazu die folgenden Schritte.

1. Bearbeiten Sie die Datei `chan_dahdi.conf` und fügen Sie die folgenden drei Zeilen zur Konfiguration hinzu:

```
mfcr2_logdir=span1
mfcr2_logging=all
mfcr2_call_files=yes
```

2. Starten Sie den Asterisk-Server neu
3. Testen Sie den Anruf und überprüfen Sie die Anrufdateien unter `/var/log/asterisk/mfcr2/span1`

Nachfolgend finden Sie eine Ablaufverfolgung für einen normalen Anruf. Vergleichen Sie sie mit dem, was Sie bei Ihrem Anruf erhalten.

```
[15:05:47:710] [Thread: 3078019984] [Chan 1] - Call started at Mon Jul  6 15:05:47 2009 on
chan 1
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Tx >> [SEIZE] 0x00
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x01
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Bits changed from 0x08 to 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - CAS Rx << [SEIZE ACK] 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 2
[15:05:47:951] [Thread: 3078019984] [Chan 1] - timer id 2 found, cancelling it now
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 3
[15:05:47:951] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 0
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 2
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 4
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - Sending ANI digit 4
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - Sending ANI digit 8
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - Sending ANI digit 3
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - Sending ANI digit 0
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - Sending more ANI unavailable
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Tx >> F [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Tx >> F [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:53:430] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Tx >> [CLEAR FORWARD] 0x08
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x09
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Bits changed from 0x0C to 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - CAS Rx << [IDLE] 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Call ended
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Cannot cancel timer 0
```

#### MFC/R2 Konfiguration

Die Optionen sind in der Datei chan_dahdi.conf dokumentiert. Einige der wichtigsten Optionen werden hier detailliert beschrieben. Obligatorische Parameter: mfcr2_variant, mfcr2_max_ani und mfcr2_max_dnis. mfcr2_variant: Ländervariante.

```
r2test -l
Variant Code        Country
AR                  Argentina
BR                  Brazil
CN                  China
CZ                  Czech Republic
CO                  Colombia
EC                  Ecuador
ITU                 International Telecommunication Union
MX                  Mexico
PH                  Philippines
VE                  Venezuela
```

mfcr2_max_ani: Maximale Anzahl von ANI-Ziffern, die angefordert werden sollen. mfcr2_max_dnis: Maximale Anzahl von DNIS-Ziffern, die angefordert werden sollen. mfcr2_get_ani_first: Ob ANI vor DNIS abgerufen werden soll oder nicht (von einigen TELCOs erforderlich). mfcr2_category: Anruferkategorie. Sie können die Variable MFCR2_CATEGORY vor dem Starten des Anrufs setzen. mfcr2_logdir: Verzeichnis zum Protokollieren der Anrufdateien. (/var/log/asterisk/mfcr2/directory) mfcr2_call_files: Ob Anrufe protokolliert werden sollen oder nicht.

- mfcr2_logging: Protokollierungswerte
- cas – ABCD-Bits für Senden und Empfangen
- mf – Multifrequenztöne
- stack – ausführliche Ausgabe des Kanal- und Kontext-Stacks
- all – alle Aktivitäten
- nothing – nichts protokollieren

mfcr2_mfback_timeout: Dieser Wert verdient es, erwähnt zu werden. Manchmal, wenn Sie ein Mobiltelefon anrufen oder einen Anruf tätigen, der lange dauert, bis er abgeschlossen ist, kann dieser Parameter eine Zeitüberschreitung verursachen, daher wird er oft zur Feinabstimmung geändert. Wenn einige Ihrer Anrufe nicht abgeschlossen werden, ist dies der Parameter, den Sie zuerst ändern sollten. mfcr2_metering_pulse_timeout: Impulse werden von einigen R2-Varianten verwendet, um Kosten anzuzeigen. mfcr2_allow_collect_calls: In Brasilien wird der Ton II-8 verwendet, um ein R-Gespräch (Collect Call) anzuzeigen; dieser Parameter ermöglicht es Ihnen, R-Gespräche zu blockieren. mfcr2_double_answer: Wird ebenfalls verwendet, um R-Gespräche zu vermeiden, wenn eine doppelte Antwort erforderlich ist. Mit double_answer=yes blockieren Sie tatsächlich die R-Gespräche. mfcr2_immediate_accept: Ermöglicht es Ihnen, die Verwendung von Gruppe B/II-Signalen zu überspringen und direkt zum akzeptierten Zustand überzugehen. mfcr2_forced_release: Ermöglicht es Ihnen, die Freigabe des Anrufs zu beschleunigen; funktioniert für die brasilianische Variante.

#### ANI und DNIS

Automatic Number Identification (ANI) ist die Nummer des Anrufers. Dialed Number Identification Service (DNIS) ist die angerufene Nummer oder, mit anderen Worten, die gewählte Nummer. Wenn ein Anruf eingeht, werden normalerweise die letzten vier Nummern an die PBX in einem Prozess übergeben, der als Direct Inward Dial (DID) bezeichnet wird. Die ANI-Nummer ist eigentlich die Caller ID. ANI enthält die Nebenstelle des Anrufers beim Wählen, während DNIS das Anrufziel enthält. Es ist wichtig, dass diese Parameter korrekt konfiguriert sind. Einige Switches senden nur die letzten vier Ziffern, während andere die vollständige Nummer senden.

### DAHDI-Kanalformat

DAHDI-Kanäle verwenden das folgende Format im Dialplan:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Beispiele:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## Das IAX2-Protokoll

In diesem Kapitel lernen wir das Inter-Asterisk eXchange (IAX) Protokoll kennen, einschließlich seiner Stärken und Schwächen. Details wie der Trunk-Modus und die Verbindung zweier Asterisk-Server werden ebenfalls behandelt. Alle Verweise in diesem Dokument beziehen sich auf die IAX-Version 2.

Das IAX-Protokoll bietet Medientransport und Signalisierung für Sprache und Video. IAX ist sehr innovativ; es spart Bandbreite im Trunk-Modus und ist bei der Überwindung von NAT wesentlich einfacher als SIP. Die Hauptanwendung für IAX ist heutzutage die Verbindung von Asterisk-Servern untereinander. IAX wurde primär für Sprache entwickelt, kann aber auch Video und andere Multimedia-Streams übertragen.

IAX wurde von anderen VoIP-Protokollen wie SIP und MGCP inspiriert. Anstatt zwei getrennte Protokolle für Signalisierung und Medien zu verwenden, hat IAX diese zu einem einzigen Protokoll vereint. IAX verwendet kein RTP für den Medientransport; stattdessen bettet es die Medien in dieselbe UDP-Verbindung ein.

**Status in Asterisk 22.** `chan_iax2` ist in Asterisk 22 LTS weiterhin enthalten und vollständig unterstützt, daher bleibt alles in diesem Abschnitt gültig. IAX2 ist jedoch ein Legacy-Protokoll, das relativ wenig neue Implementierungen erfährt: Die Industrie hat sich weitgehend auf SIP (via `chan_pjsip` in Asterisk 22) sowohl für Provider-Trunking als auch für Server-Verbindungen geeinigt. Der verbleibende Hauptvorteil von IAX2 ist sein Single-Port-Design – die gesamte Signalisierung und die Medien fließen über einen einzigen UDP-Port (standardmäßig 4569), was die Firewall- und NAT-Konfiguration im Vergleich zu SIP und seinen separaten RTP-Streams vereinfacht. Für einen neuen Asterisk-zu-Asterisk-Trunk, bei dem NAT kein Problem darstellt, ist ein PJSIP-Trunk der empfohlene moderne Ansatz; IAX2 wird hier behandelt, da es eine valide Wahl bleibt, insbesondere wenn nur ein UDP-Port durch eine Firewall geöffnet werden kann.

### Lernziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Stärken und Schwächen des IAX-Protokolls zu identifizieren
- Einsatzszenarien für das IAX-Protokoll zu beschreiben
- Die Vorteile des IAX-Trunk-Modus zu beschreiben
- iax.conf für Telefone zu konfigurieren
- iax.conf für die Verbindung zu einem VoIP-Provider zu konfigurieren
- iax.conf für die Asterisk-Verbindung zu konfigurieren
- IAX-Authentifizierung zu verstehen

### IAX-Design

Die Hauptziele für das IAX-Design sind:

- Die für Medientransport und Signalisierung erforderliche Bandbreite zu reduzieren
- NAT-Transparenz zu bieten
- Die Übertragung von dialplan-Informationen zu ermöglichen
- Die effiziente Nutzung von Paging und Intercom zu unterstützen

IAX ist ein Peer-to-Peer-Signalisierungs- und Medienprotokoll, das SIP ähnelt, jedoch ohne RTP auskommt. Der grundlegende Ansatz besteht darin, die Multimedia-Streams über eine einzige UDP-Verbindung zwischen zwei Hosts zu multiplexen. Der größte Vorteil dieses Ansatzes ist seine Einfachheit beim Durchqueren von Verbindungen über NAT, wie sie regelmäßig bei xDSL-Modems vorkommen. IAX verwendet einen einzelnen Port, standardmäßig UDP 4569, und nutzt dann eine 15-Bit-Anrufnummer, um alle Streams zu multiplexen. Das IAX-Protokoll verwendet Registrierungs- und Authentifizierungsprozesse, die dem SIP-Protokoll ähneln. Eine Beschreibung des Protokolls finden Sie unter http://www.ietf.org/internet-drafts/draft-guy-iax-05.txt

![Das IAX-Protokoll multiplext viele Anrufe zwischen zwei endpoints über einen einzigen UDP-Port (standardmäßig 4569) und verwendet eine 15-Bit-Anrufnummer, um die Streams getrennt zu halten – was das NAT-Traversal vereinfacht.](../images/10-legacy-fig12.png)

### Bandbreitennutzung

Die in VoIP-Netzwerken verwendete Bandbreite wird von mehreren Faktoren beeinflusst; codecs und Protokoll-Header sind dabei am wichtigsten. Das IAX-Protokoll verfügt über eine überraschende Funktion namens Trunk-Modus, bei der es mehrere Anrufe mit einem einzigen Header multiplext. Wenn Sie mit dem Asterisk-Bandbreitenrechner experimentieren, werden Sie sehen, wie IAX-Trunks bei mehreren Anrufen bis zu 80 % des Datenverkehrs einsparen können.

![Vergleich von IAX- und SIP-Overhead: Zwei SIP/RTP-Anrufe benötigen zwei Pakete (40 Bytes Nutzlast bei 156 Bytes Overhead), während der IAX2-Trunk-Modus beide Anrufe in einem einzigen Paket überträgt (40 Bytes Nutzlast bei nur 66 Bytes Overhead), indem ein IP/UDP-Header über viele Mini-Frames hinweg geteilt wird.](../images/10-legacy-fig13.png)

### Kanalbenennung

Es ist wichtig, die Konventionen zur Kanalbenennung zu verstehen, da Sie diese Namen verwenden werden, wenn Sie einen Kanal im dialplan angeben. Das Format eines IAX-Kanalnamens für ausgehende Kanäle lautet:

```
IAX/[<user>[:<secret>]@]<peer>[:<portno>][/<exten>[@<context>][/<options>]
```

- `<user>` — UserID auf dem entfernten Peer oder Name des in iax.conf konfigurierten Clients
- `<secret>` — Das Passwort. Alternativ kann dies der Dateiname für einen RSA-Schlüssel ohne die nachgestellte Erweiterung (.key oder .pub) sein, eingeschlossen in eckige Klammern
- `<peer>` — Name des Servers, zu dem eine Verbindung hergestellt werden soll
- `<portno>` — Portnummer für die Verbindung
- `<exten>` — extension auf dem entfernten Asterisk-Server
- `<context>` — context auf dem entfernten Asterisk-Server
- `<options>` — Die einzige verfügbare Option ist 'a', was 'request autoanswer' bedeutet

#### Beispiel für ausgehende Kanäle:

Ausgehende Kanäle werden in der Asterisk-Konsole angezeigt.

- `IAX2/8590:secret@myserver/8590@default` — Ruft die extension 8590 auf myserver an. Verwendet 8590:secret als Name/Passwort-Paar
- `IAX2/iaxphone` — Ruft "iaxphone" an
- `IAX2/judy:[judyrsa]@somewhere.com` — Ruft somewhere.com unter Verwendung von judy als Benutzername und einem RSA-Schlüssel zur Authentifizierung an

#### Das Format eines eingehenden IAX-Kanals lautet:

Eingehende Kanäle werden in der Asterisk-Konsole angezeigt.

```
IAX2/[<username>@]<host>]-<callno>
```

- `<username>` — Benutzername, falls bekannt
- `<host>` — Verbindender Host
- `<callno>` — Lokale Anrufnummer

Beispiel für einen eingehenden Kanal:

- `IAX2[flavio@8.8.30.34]/10` — Anrufnummer 10 von IP-Adresse 8.8.30.34 unter Verwendung von flavio als Benutzer.
- `IAX2[8.8.30.50]/11` — Anrufnummer 11 von IP-Adresse 8.8.30.50.

### Verwendung von IAX

Sie können IAX auf verschiedene Weise nutzen. In diesem Abschnitt zeigen wir Ihnen, wie Sie IAX für verschiedene Szenarien konfigurieren, darunter:

- Verbindung eines softphone über IAX
- Verbindung von IAX zu einem VoIP-Provider über IAX
- Verbindung zweier Server über IAX
- Verbindung zweier Server über IAX im Trunk-Modus
- Debugging einer IAX-Verbindung
- Verwendung von RSA-Schlüsselpaaren zur Authentifizierung

#### Verbindung eines softphone über IAX

Asterisk unterstützt IP-Telefone auf IAX-Basis wie das ATCOM und das alte ATA von Digium (genannt IAXy) sowie softphones, die das IAX2-Protokoll implementieren. Der Prozess für softphones, ATAs und Hard-Phones ist ähnlich. Um ein IAX-Gerät zu konfigurieren, müssen Sie die Datei iax.conf in /etc/asterisk bearbeiten.

```
directory.
```

Wir verwenden ein IAX2-fähiges softphone als Beispiel.

1. Erstellen Sie ein Backup der ursprünglichen `iax.conf` Datei mit:

```
#cd /etc/asterisk
#mv iax.conf iax.conf.backup
```

2. Beginnen Sie mit der Bearbeitung einer neuen `iax.conf` Datei:

```
[general]
bindport=4569
bindaddr=8.8.1.4
bandwidth=high
```

- ; Sehr wichtiger Parameter, er ändert die verfügbaren codecs

```
disallow=all
allow=ulaw
jitterbuffer=no
forcejitterbuffer=no
tos=lowdelay
autokill=yes
[guest]
type=user
context=guest
callerid="Guest IAX User"
; Trust Caller*ID Coming from iaxtel.com
;
[iaxtel]
type=user
context=default
auth=rsa
inkeys=iaxtel
;
; Trust Caller*ID Coming from iax.fwdnet.net
;
[iaxfwd]
type=user
context=default
auth=rsa
inkeys=freeworlddialup
;
; Trust callerid delivered over DUNDi/e164
;
;
;[dundi]
;type=user
;dbsecret=dundi/secret
;context=dundi-e164-local
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

Ich habe versucht, die Standardzeilen (nicht auskommentiert) der Beispieldatei beizubehalten. Die folgenden Parameter wurden geändert:

```
bandwidth=high
```

Diese Zeile beeinflusst die codec-Auswahl. Die Einstellung high ermöglicht die Auswahl eines codecs mit hoher Bandbreite und hoher Qualität, wie z. B. g.711, definiert durch das Schlüsselwort ulaw. Wenn Sie den Standardparameter beibehalten, können Sie ulaw nicht auswählen. In diesem Fall gibt Ihnen Asterisk für die unten stehende Konfiguration die Meldung „no codec available“.

```
disallow=all
allow=ulaw
```

In den oben beschriebenen Befehlen haben wir alle codecs deaktiviert und nur ulaw aktiviert. In LANs bevorzugen die meisten Leute ulaw, da es nicht prozessorintensiv ist und CPU-Zyklen spart. Auch wenn es mehr Bandbreite verbraucht, ist dieser codec vorzuziehen, da Sie in LANs normalerweise ein 100-Megabit-Ethernet oder sogar ein Gigabit-Netzwerk haben. Ein Sprachanruf mit ulaw verbraucht fast 100 Kilobit pro Sekunde an Bandbreite in Ihrem Netzwerk, was für die heutigen Hochgeschwindigkeits-LANs eine sehr geringe Belastung darstellt. In WAN- oder Internet-Netzwerken deaktivieren Sie normalerweise ulaw und tauschen einige verfügbare CPU-Zyklen gegen Sprachkompression für eine bessere Bandbreitennutzung. Die codecs gsm, g729 und ilbc bieten ebenfalls einen guten Kompressionsfaktor.

```
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

In den obigen Befehlen haben wir einen friend namens [2003] definiert. Der context ist der Standard (in den ersten Übungen verwenden wir immer den Standard-context, um Verwirrung zu vermeiden; dieser context wird vollständig erklärt, wenn wir den dialplan behandeln). Die Zeile „host=dynamic“ ermöglicht eine dynamische Registrierung der IP-Adresse des Telefons.

3. Laden Sie ein IAX2-fähiges softphone herunter und installieren Sie es. Sie können für die Übung jedes softphone wählen, das das IAX2-Protokoll noch unterstützt.
4. Konfigurieren Sie ein IAX-Konto im Client (typischerweise *Add account* → IAX). Beachten Sie, dass das SipPulse Softphone nur SIP unterstützt und sich nicht über IAX2 registrieren kann. Für IAX-Tests benötigen Sie also einen Client, der das Protokoll noch unterstützt.

5. Konfigurieren Sie die `extensions.conf` Datei, um Ihr IAX-Gerät zu testen.

```
[default]
exten=>2000,1,Dial(SIP/2000)
exten=>2001,1,Dial(SIP/2001)
exten=>2003,1,Dial(IAX2/2003)
```

Jetzt können Sie zwischen den in Kapitel 3 erstellten SIP-Telefonen und dem in der Übung erstellten IAX-Telefon wählen.

#### Verbindung zu einem VoIP-Provider über IAX

Einige VoIP-Provider unterstützen IAX. Sie können leicht einen IAX-Provider finden, indem Sie nach „IAX providers“ suchen. Die Nutzung eines IAX-Providers ist sehr sinnvoll, da IAX viel Bandbreite sparen kann, NAT problemlos durchquert und sich mittels RSA-Schlüsselpaaren authentifizieren kann.

![Ein Asterisk eines Kunden, das über einen IAX-Trunk über das Internet mit einem VoIP-Provider verbunden ist: Ein einziger Trunk überträgt alle Anrufe zum und vom Provider.](../images/10-legacy-fig14.png)

Die Anzahl der IAX-fähigen kommerziellen VoIP-Provider ist in den letzten Asterisk-Releases stark zurückgegangen; die meisten Provider bieten heute ausschließlich SIP/PJSIP-Trunks an. Bevor Sie sich für einen IAX-Provider entscheiden, bestätigen Sie, dass dieser seine IAX-Infrastruktur aktiv pflegt. Für eine neue Provider-Integration ist ein PJSIP-Trunk (Kapitel 3) die empfohlene Alternative.

#### Verbindung zu einem Provider über IAX

Schritt 1: Eröffnen Sie ein Konto bei Ihrem bevorzugten Provider. Ihr Provider wird Ihnen drei Dinge zur Verfügung stellen:

- Name
- Secret
- IP-Adresse oder Hostname
- RSA public key

Schritt 2: Konfigurieren Sie die Datei iax.conf, um Ihren Asterisk bei Ihrem Provider zu registrieren. Fügen Sie die folgenden Zeilen zum [general]-Abschnitt der Datei hinzu.

```
[general]
register=>name:secret@hostname/2003
```

In den oben beschriebenen Anweisungen haben Sie sich bei Ihrem Provider mit Ihrem Konto und Passwort registriert. Sobald Sie einen Anruf erhalten, wird dieser an die extension 2003 weitergeleitet.

```
[name]
```

- ; Ihr Kontoname oder Ihre Nummer

```
type=peer
secret=secret
; Your password
host=hostname
```

In den oben beschriebenen Anweisungen haben wir einen peer erstellt, der dem Provider für Wählzwecke entspricht.

```
[nameiax]
type=user
context=default
auth=rsa
inkeys=hostname
```

Dies ist für die RSA-Authentifizierung erforderlich. Die Verwendung des public key Ihres Providers stellt sicher, dass der eingehende Anruf tatsächlich vom echten Provider stammt. Wenn jemand anderes versucht, denselben Pfad zu verwenden, kann er sich nicht authentifizieren, da er nicht über den entsprechenden private key verfügt. Schritt 4: Testen Sie die Verbindung. Um die Verbindung zu testen, rufen Sie eine beliebige Nummer an. Einige Anbieter bieten einen Echotest an. Um dies zu erreichen, bearbeiten Sie bitte die Datei extensions.conf.

```
[default]
exten=>*98,1,Dial(IAX2/name:secret@hostname/*98,20,r)
```

Gehen Sie zur Asterisk-CLI und führen Sie ein reload aus. Um zu überprüfen, ob Asterisk beim Provider registriert ist, verwenden Sie den nächsten Befehl.

```
*CLI>reload
*CLI>iax2 show register
```

Wählen Sie nun einfach *98 auf dem softphone, das mit dem Asterisk-Server verbunden ist.

#### Verbindung zweier Asterisk-Server über einen IAX-Trunk

Es ist sehr einfach, einen Server mit einem anderen zu verbinden. Sie müssen sie nicht registrieren, da die IP-Adressen bereits bekannt sind. Sie müssen die peers und users in der Datei iax.conf erstellen. Alle extensions am Standort HQ beginnen mit 20, gefolgt von zwei Ziffern (z. B. 2000). In der Niederlassung (Branch) beginnen alle extensions mit 22, gefolgt von zwei Ziffern (z. B. 2200). Wir werden den Trunk verwenden. Sie benötigen eine DAHDI-Zeitquelle, um diese Funktion zu aktivieren. Schritt 1: Bearbeiten Sie die Datei iax.conf auf dem Branch-Server.

![Verbindung zweier Asterisk-Server mit einem IAX-Trunk: Der HQ-Server (192.168.1.1, extensions 20xx) und der Branch-Server (192.168.1.2, extensions 22xx) erreichen sich über einen einzigen IAX-Trunk – es ist keine Registrierung erforderlich, da beide IP-Adressen fest und bekannt sind.](../images/10-legacy-fig15.png)

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;allow=gsm
[Branch]
type=user
context=default
secret=password
host=192.168.2.10
trunk=yes
notransfer=yes
[HQ]
type=peer
context=default
username=HQ
secret=password
host=192.168.2.10
callerID='HQ'
trunk=yes
notransfer=yes
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2000'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2001'
```

Schritt 2: Konfigurieren Sie die Datei extensions.conf auf dem Branch-Server

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_20XX,1,dial(IAX2/HQ/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

Schritt 3: Konfigurieren Sie die Datei iax.conf auf dem HQ-Server

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
[Branch]
type=peer
context=default
username=Branch
secret=password
host=192.168.2.9
callerid="Branch"
trunk=yes
notransfer=yes
[HQ]
type=user
secret=password
context=default
host=192.168.2.9
callerid="HQ"
trunk=yes
notransfer=yes
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2200"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2201"
host=dynamic
```

Schritt 4: Konfigurieren Sie die Datei extensions.conf auf dem HQ-Server.

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_22XX,1,Dial(IAX2/Branch/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Schritt 5: Testen Sie einen Anruf vom Telefon 2000 auf dem HQ-Server zum Telefon 2200 auf dem Branch-Server.

### IAX-Authentifizierung

Lassen Sie uns nun den IAX-Authentifizierungsprozess aus praktischer Sicht analysieren, um Ihnen bei der Auswahl der besten Methode für jede spezifische Anforderung zu helfen.

#### Eingehende Verbindungen

![Der IAX-Authentifizierungsentscheidungsfluss für einen eingehenden Anruf: Asterisk verzweigt danach, ob ein Benutzername angegeben ist, ob er mit einem Abschnitt übereinstimmt, ob die Quell-IP erlaubt ist und ob das secret (Klartext, MD5 oder RSA) übereinstimmt – und akzeptiert den Anruf mit dem context und den peer-Optionen dieses Abschnitts oder lehnt ihn ab.](../images/10-legacy-fig16.png)

Wenn Asterisk eine eingehende Verbindung empfängt, können die anfänglichen Informationen einen Benutzernamen (aus dem Feld "username=") enthalten oder nicht. Die eingehende Verbindung hat auch eine IP-Adresse, die Asterisk ebenfalls zur Authentifizierung verwendet.

Wenn ein Benutzer angegeben ist, führt Asterisk Folgendes aus:

1. Durchsucht iax.conf nach einem Eintrag mit type=user (oder type=friend mit einem Abschnittsnamen, der mit dem Benutzernamen übereinstimmt). Wenn er nicht gefunden wird, verweigert Asterisk die Verbindung.
2. Wenn der gefundene Eintrag deny/allow-Konfigurationen enthält, vergleicht er die IP-Adresse des Anrufers, um zu bestimmen, ob der Anruf basierend auf den deny/allow-Klauseln akzeptiert werden soll oder nicht.
3. Er überprüft das Passwort (secret) mittels Klartext, MD5 oder RSA.
4. Er akzeptiert die Verbindung und sendet den Anruf an den context, der in der Zeile "context=" in der Datei iax.conf angegeben ist.

Wenn kein Benutzername angegeben ist, führt Asterisk Folgendes aus:

1. Sucht nach einem Eintrag mit type=user (oder type=friend) in der Datei iax.conf ohne angegebenes secret. Er überprüft auch die deny/allow-Klauseln. Wenn ein Eintrag gefunden wird, wird die Verbindung akzeptiert und der Abschnittsname als Benutzername verwendet.
2. Sucht nach einem Eintrag mit type=user (oder type=friend) in der Datei iax.conf mit einem angegebenen secret oder RSA-Schlüssel. Er überprüft die deny/allow-Klauseln. Wenn ein Eintrag gefunden wird, versucht er, den Anrufer mit dem angegebenen secret zu authentifizieren; wenn es übereinstimmt, akzeptiert er die Verbindung. Der Abschnittsname ist der Benutzername.

Nehmen wir an, Ihre Datei iax.conf enthält die folgenden Einträge:

```
[guest]
type=user
context=guest
[iaxtel]
type=user
context=incoming
auth=rsa
inkeys=iaxtel
[iax-gateway]
type=friend
allow=192.168.0.1
context=incoming
host=192.168.0.1
[iax-friend]
type=user
secret=this_is_secret
auth=md5
context=incoming
```

Wenn ein Anruf einen angegebenen Benutzernamen hat, wie z. B.:

- guest
- iaxtel
- iax-gateway
- iax-friend

wird Asterisk versuchen, den Anruf nur mit dem entsprechenden Eintrag in der Datei iax.conf zu authentifizieren. Wenn andere Namen angegeben sind, würde der Anruf abgelehnt. Wenn kein Benutzer angegeben ist, versucht Asterisk, die Verbindung als guest zu authentifizieren. Wenn jedoch kein guest existiert, versucht er andere Verbindungen mit einem übereinstimmenden secret. Mit anderen Worten: Wenn Sie keinen guest-Abschnitt in Ihrer Datei iax.conf haben, könnte ein böswilliger Benutzer versuchen, ein passendes secret zu erraten, indem er keinen Benutzernamen angibt. Die deny/allow-Beschränkungen für IP-Adressen gelten ebenfalls. Ein guter Weg, um das Erraten von secrets zu vermeiden, ist die Verwendung der RSA-Authentifizierung. Eine weitere Methode besteht darin, die IP-Adressen einzuschränken, die anrufen dürfen.

#### IP-Adressbeschränkungen

Der Zugriff wird mit den Zeilen `permit` und `deny` gesteuert:

```
permit = <ipaddr>/<netmask>
deny = <ipaddr>/<netmask>
```

Regeln werden der Reihe nach interpretiert und alle werden ausgewertet (dieses Konzept unterscheidet sich von den ACLs, die normalerweise in Routern und Firewalls zu finden sind). Die letzte übereinstimmende Anweisung ersetzt die vorherigen.

Beispiel #1:

```
permit=0.0.0.0/0.0.0.0
deny=192.168.0.0/255.255.255.0
```

Dies verweigert jedes Paket aus dem Netzwerk 192.168.0.0/24.

Beispiel #2:

```
deny=192.168.0.0/255.255.255.0
permit=0.0.0.0/0.0.0.0
```

Dies erlaubt jedes Paket, da die letzte Anweisung die erste ersetzt.

#### Ausgehende Verbindungen

Ausgehende Verbindungen erhalten Authentifizierungsinformationen mit den folgenden Methoden:

- Die IAX2-Kanalbeschreibung, die von der dial()-Anwendung übergeben wird.
- Ein Eintrag mit type=peer oder type=friend in der Datei iax.conf.
- Eine Kombination aus beiden Methoden.

#### Verbindung zweier Asterisk-Server mit RSA-Schlüsseln

Es ist möglich, IAX mit starker Authentifizierung unter Verwendung asymmetrischer RSA-Schlüssel zu nutzen. Laut Quellcode (res_krypto.c) verwendet Asterisk RSA-Schlüssel mit einem SHA-1-Algorithmus für Message Digests anstelle des schwächeren MD5. Nachfolgend finden Sie eine Schritt-für-Schritt-Anleitung für die Einrichtung zweier Server mit RSA-Schlüsseln.

##### Konfiguration des Servers für die Niederlassung (Branch)

Schritt 1: Generieren Sie die RSA-Schlüssel auf dem Branch-Server

```
astgenkey -n
```

Verwenden Sie bei der Abfrage den Schlüsselnamen branch. Wir haben den Parameter –n verwendet, um zu vermeiden, dass bei jedem Neustart von Asterisk eine Passphrase eingegeben werden muss. Wenn Sie die Sicherheit erhöhen möchten, verwenden Sie nicht –n und starten Sie Asterisk mit asterisk -i. Schritt 2: Kopieren Sie die Schlüssel in das Verzeichnis /var/lib/asterisk/keys

```
cp branch.* /var/lib/asterisk/keys
```

Schritt 3: Kopieren Sie den public key auf den HQ-Server

```
scp branch.pub root@hq_ip_address:/var/lib/asterisk/keys
```

Schritt 4: Bearbeiten Sie die Datei iax.conf auf dem Branch-Server.

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;Create an entry for the HQ server
[hq]
type=user
context=default
host=192.168.2.10
trunk=yes
notransfer=yes
auth=rsa
inkeys=hq
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2200'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2201'
```

Schritt 8: Konfigurieren Sie die Datei extensions.conf auf dem Branch-Server

```
 [default]
exten=>_20XX,1,dial(IAX2/branch:[branch]@192.168.2.10/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

##### Konfiguration des Servers für die Zentrale (Headquarters)

Schritt 1: Generieren Sie die RSA-Schlüssel auf dem HQ-Server

```
astgenkey -n
```

Verwenden Sie bei der Abfrage den Schlüsselnamen hq. Schritt 2: Kopieren Sie die Schlüssel in das Verzeichnis /var/lib/asterisk/keys

```
cp hq.* /var/lib/asterisk/keys
```

Schritt 3: Kopieren Sie den public key auf den BRANCH-Server

```
scp hq.pub root@branch_ip_address:/var/lib/asterisk/keys
```

Schritt 4: Konfigurieren Sie die Datei iax.conf auf dem HQ-Server

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
;Configure an entry for the branch server
[branch]
type=user
context=default
host=192.168.2.9
trunk=yes
notransfer=yes
auth=rsa
inkeys=branch
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2000"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2001"
host=dynamic
```

Schritt 10: Konfigurieren Sie die Datei extensions.conf auf dem HQ-Server.

```
[default]
exten=>_22XX,1,Dial(IAX2/hq:[hq]@192.168.2.9/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Schritt 11: Testen Sie einen Anruf vom Telefon 2000 auf dem HQ-Server zum Telefon 2200 auf dem Branch-Server.

### Die Konfiguration der Datei iax.conf

Die Datei iax.conf hat mehrere Parameter; jeden Parameter einzeln zu besprechen, wäre langweilig und kontraproduktiv. Alle Parameter sowie eine Beschreibung finden Sie in der Beispieldatei. Im Wiki www.voip-info.org finden Sie detaillierte Informationen zu jedem einzelnen. Hier zeigen wir einige der wichtigsten Parameter für die Konfiguration des allgemeinen Abschnitts, der peers und der users.

#### [General]-Abschnitt

Server-Adressen:

- `bindport = <portnum>` — Konfiguriert den IAX-UDP-Port. Standard ist 4569.
- `bindaddr = <ipaddr>` — Verwenden Sie 0.0.0.0, um Asterisk an alle Schnittstellen zu binden, oder geben Sie die IP-Adresse einer bestimmten Schnittstelle an.

Codec-Auswahl:

- `bandwidth = [low|medium|high]` — High = alle codecs; Medium = alle codecs außer ulaw und alaw; Low = codecs mit niedriger Bandbreite.
- `allow/disallow = [alaw|ulaw|gsm|g.729| etc.]` — Feinabstimmung der codec-Auswahl.

### Jitter-Buffer

Jitter ist die Verzögerungsvariation zwischen Paketen. Er ist der wichtigste Faktor, der die Sprachqualität beeinflusst. Ein Jitter-Buffer wird verwendet, um die Verzögerungsvariation auszugleichen. Er opfert Latenz zugunsten eines geringeren Jitters. Sie können eine Analogie zwischen dem Jitter-Buffer und einem Wassertank ziehen. Beide können Pakete oder Wasser in unregelmäßigen Abständen empfangen, liefern aber letztendlich einen gleichmäßigen Fluss.

![Der Jitter-Buffer als Wassertank: Pakete kommen unregelmäßig aus dem Netzwerk an und füllen den Buffer, der sie dann mit einer konstanten Rate freigibt, um einen gleichmäßigen Sprachfluss zu erzeugen. Die Buffer-Größe (in ms) tauscht ein wenig Latenz gegen geringeren Jitter; das Excess-Buffer-Band lässt Asterisk den Buffer vergrößern oder verkleinern, wenn sich die Netzwerkbedingungen ändern.](../images/10-legacy-fig17.png)

Ein kleiner Jitter (d. h. unter 20 ms) ist normalerweise nicht wahrnehmbar. Jitter über diesem Wert ist jedoch störend. Die Latenz oder Verzögerung sollte unter 150 ms gehalten werden. Das Erstellen eines Jitter-Buffers opfert etwas Verzögerung für einen geringeren Jitter – ein Konzept, das als „Delay-Budget“ bekannt ist. Sie können den Jitter-Buffer mit diesen Parametern beeinflussen:

- Jitterbuffer=<yes/no> – Aktiviert oder deaktiviert
- Dropcount=<number> - Maximale Anzahl von Frames, die in den letzten zwei Sekunden verzögert werden sollten. Die empfohlene Einstellung ist 3 (1,5 % der verworfenen Frames)
- Maxjitterbuffer=<ms> - Normalerweise unter 100 ms
- Maxexcessbuffer=<ms> - Wenn sich die Netzwerkverzögerung verbessert, könnte der Jitter-Buffer überdimensioniert sein. Folglich wird Asterisk versuchen, ihn zu reduzieren.
- Minexcessbuffer=<ms> - Sobald der überschüssige Buffer auf diesen Wert fällt, beginnt Asterisk, die Buffer-Größe zu erhöhen.

### Frame-Tagging

Der unten stehende Parameter markiert das IP-Paket im Type-of-Service-Feld. Router können dieses Tag lesen und so den Datenverkehr priorisieren. Asterisk verwendet DSCP-Codes für dieses Feld (RFC 2474). Zulässige Werte sind CS0, CS1, CS2, CS3, CS4, CS5, CS6, CS7, AF11, AF12, AF13, AF21, AF22, AF23, AF31, AF32, AF33, AF41, AF42, AF43 und ef (d. h. expedited forwarding).

```
tos=ef
```

### IAX2-Verschlüsselung

IAX unterstützt die Anrufverschlüsselung unter Verwendung einer symmetrischen 128-Bit-Blockchiffre namens AES (Advanced Encryption Standard). Es ist sehr einfach, die Verschlüsselung zwischen IAX-Trunks zu aktivieren. Verwenden Sie in der Datei iax.conf:

```
encryption=yes
```

Um die Verschlüsselung zu erzwingen:

```
forceencryption=yes
```

Um die Kompatibilität mit älteren Versionen zu gewährleisten, müssen Sie möglicherweise die Schlüsselrotation deaktivieren:

```
keyrotate=no
```

### IAX2-Debug-Befehle

Nachfolgend finden Sie einige der wichtigsten Konsolenbefehle zur Fehlerbehebung für Asterisk.

```
iax2 show netstats
vtsvoffice*CLI> iax2 show netstats
                        -------- LOCAL ---------------------  -------- REMOTE ---------------
-----
Channel           RTT  Jit  Del  Lost   %  Drop  OOO  Kpkts  Jit  Del  Lost   %  Drop  OOO
Kpkts
IAX2/8590-1        16   -1    0    -1  -1     0   -1      1   60  110     3   0     0    0
0
iax2 show channels
vtsvoffice*CLI> iax2 show channels
Channel       Peer             Username    ID (Lo/Rem)  Seq (Tx/Rx)  Lag      Jitter  JitBuf
Format
IAX2/8590-2   8.8.30.43        8590        00002/26968  00004/00003  00000ms  -0001ms  0000ms
unknow
iax2 show peers
vtsvoffice*CLI> iax2 show peers
Name/Username    Host                 Mask             Port          Status
8584             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8564             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8576             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8572             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8571             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8585             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8589             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8590             8.8.30.43       (D)  255.255.255.255  4569          OK (16 ms)
3232             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
9 iax2 peers [1 online, 8 offline, 0 unmonitored]
iax2 debug
```

Identifizieren Sie anhand dieser Ausgabe den Beginn und das Ende des Anrufs. Beobachten Sie die Verzögerungs- und Jitter-Informationen, die mit poke- und pong-Paketen ermittelt wurden. Diese Pakete helfen bei der Erstellung der Ausgabe des Befehls „iax2 show netstats“.

```
vtsvoffice*CLI> iax2 debug
IAX2 Debugging Enabled
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: REGREQ
   Timestamp: 00003ms  SCall: 26975  DCall: 00000 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: REGAUTH
   Timestamp: 00009ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 137472844
   USERNAME        : 8590
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: REGREQ
   Timestamp: 00016ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
   MD5 RESULT      : f772b6512e77fa4a44c2f74ef709e873
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: REGACK
   Timestamp: 00025ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   USERNAME        : 8590
   DATE TIME       : 2006-04-17  16:03:00
   REFRESH         : 60
   APPARENT ADDRES : IPV4 8.8.30.43:4569
   CALLING NUMBER  : 4830258590
   CALLING NAME    : Flavio
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00025ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: POKE
   Timestamp: 00003ms  SCall: 00006  DCall: 00000 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: PONG
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Tx-Frame Retry[-01] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00006  DCall: 26976 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: AUTHREQ
   Timestamp: 00007ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 190271661
   USERNAME        : 8590
Rx-Frame Retry[Yes] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[-01] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: AUTHREP
   Timestamp: 00063ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   MD5 RESULT      : 57cc5c48affba14106c29439944413a1
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: ACCEPT
   Timestamp: 00054ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   FORMAT          : 1024
Tx-Frame Retry[000] -- OSeqno: 002 ISeqno: 002 Type: CONTROL Subclass: ANSWER
   Timestamp: 00057ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 003 ISeqno: 002 Type: VOICE   Subclass: 138
   Timestamp: 00090ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00054ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00057ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: IAX     Subclass: ACK
   Timestamp: 00090ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: VOICE   Subclass: 138
   Timestamp: 00210ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[-01] -- OSeqno: 004 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00210ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 003 ISeqno: 004 Type: IAX     Subclass: PING
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 004 ISeqno: 004 Type: IAX     Subclass: PONG
   Timestamp: 02083ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: ACK
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: HANGUP
   Timestamp: 08693ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   CAUSE           : Dumped Call
```

Um das Debugging zu deaktivieren, verwenden Sie:

```
vtsvoffice*CLI>iax2 no debug
```

### Zusammenfassung

Dieses Kapitel hat die Stärken und Schwächen des IAX-Protokolls beleuchtet. Es wurde gezeigt, wie IAX in verschiedenen Szenarien funktioniert, wie z. B. bei softphones und einem Trunk zwischen zwei Asterisk-Servern. Der Trunk-Modus ermöglicht es Ihnen, Bandbreite zu sparen, indem mehr als ein Anruf in einem einzigen Paket übertragen wird. Schließlich haben Sie Konsolenbefehle kennengelernt, mit denen Sie den Status überprüfen und das Protokoll debuggen können.

## Legacy SIP: chan_sip und sip.conf (entfernt in Asterisk 21+)

> **Legacy / historisch:** Alles in diesem Abschnitt verwendet den alten `chan_sip`
> Treiber und seine `sip.conf` Konfigurationsdatei. `chan_sip` war über
> mehrere Releases hinweg als veraltet markiert und wurde **in Asterisk 21 entfernt**,
> daher **existiert es in Asterisk 22 nicht mehr**. Keines der folgenden `sip.conf`
> Beispiele wird auf einem aktuellen System funktionieren — sie werden hier nur
> aufbewahrt, um zu dokumentieren, wie Legacy-Bereitstellungen funktionierten, und
> um Sie bei deren Migration zu unterstützen. Für den modernen, unterstützten Weg,
> dies zu erreichen, lesen Sie den Abschnitt *PJSIP: the SIP channel* im Kapitel
> *SIP & PJSIP in depth*. Die Theorie zum SIP-*Protokoll* (Methoden, Registrierung,
> Proxy/Redirect, SDP, NAT-Typen) ist protokollspezifisch und findet sich in jenem
> Kapitel; was folgt, ist rein die entfernte `chan_sip` **Konfiguration**.

Auf Legacy-Systemen bis einschließlich Asterisk 20 wurde SIP in `/etc/asterisk/sip.conf` konfiguriert, was früher die am zweithäufigsten geänderte Datei war (direkt nach `extensions.conf`). Die folgenden Abschnitte zeigen, wie `chan_sip` Asterisk mit einem SIP-Provider verband, wie man zwei Asterisk-Instanzen mittels SIP verbindet, sowie Informationen zu Domain-Unterstützung, Presence, Codec/DTMF/QoS-Optionen, Authentifizierung und NAT — gefolgt von einem Leitfaden zur Migration all dieser Einstellungen auf PJSIP.

### Verbinden von Asterisk mit einem SIP-Provider (sip.conf)

Asterisk wird häufig verwendet, um eine Verbindung zu einem SIP-VoIP-Provider herzustellen. VoIP-Provider bieten in der Regel günstigere Tarife für Telefonate als herkömmliche Anbieter. Ein weiterer interessanter und attraktiver Punkt bei VoIP-Providern ist die Möglichkeit, DID-Nummern in anderen Städten – sogar in fremden Ländern – zu erwerben. Dies sind gute Gründe, VoIP für die Telekommunikation zu nutzen. In diesem Abschnitt erfahren Sie, wie das Legacy-System `chan_sip` Asterisk mit einem VoIP-Provider verband. Um Asterisk mit einem SIP-Provider zu verbinden, sind drei Schritte erforderlich. Tests können durchgeführt werden, indem Sie ein Konto bei Ihrem bevorzugten Anbieter einrichten. Schritt 1: Registrierung bei einem SIP-Provider in der sip.conf. Um eine Verbindung zu einem SIP-Provider herzustellen, benötigen Sie die folgenden Informationen vom Anbieter:

![Asterisk verbunden mit einem VoIP-Dienstanbieter über das Internet oder ein privates WAN, mit lokalen SIP-Telefonen, die am Asterisk-Server registriert sind](../images/07-sip-and-pjsip-fig07.png)

- Benutzername
- secret und remotesecret (Verwenden Sie secret zur Authentifizierung eingehender Anfragen und remotesecret für ausgehende Anfragen)
- Hostname
- Domain
- Erlaubte Codecs

Diese Konfiguration ermöglicht es Ihrem Provider, die IP-Adresse von Asterisk zu lokalisieren. In der folgenden Anweisung weisen wir Asterisk an, sich bei einem SIP-Provider zu registrieren, der durch den Hostnamen definiert ist, und den Provider über die IP-Adresse von Asterisk zu informieren. Die Anweisung besagt, dass Sie Anrufe an die extension 4100 empfangen möchten. Geben Sie im Abschnitt [general] der Datei sip.conf die folgende Zeile ein:

```
register=>name:secret@hostname/4100
```

Schritt 2: Konfigurieren des [peer] in der sip.conf. Erstellen Sie einen Eintrag vom Typ peer für den gewünschten Provider, um das Wählen über Asterisk zu vereinfachen.

```
[provider]
context=incoming
type=friend
dtmfmode=rfc2833
directmedia=no
username=username
remotesecret=secret
host=hostname
fromuser=username
fromdomain=domain
insecure=invite
disallow=all
allow=ulaw ; or any other codec available from your provider
```

Schritt 3: Erstellen einer Route zum Provider im dialplan. Wir wählen die Ziffern 010 als Zielroute zum Provider. Um #610000 beim Provider zu wählen, wählen Sie einfach 010610000.

```
exten=>_010.,1,Set(CALLERID(num)=username)
exten=>_010.,n,Set(CALLERID(Name)="Flavio Gonçalves")
exten=>_010.,n,Dial(SIP/${EXTEN:3}@provider)
exten=>_010.,n,Hangup
```

#### SIP-Optionen spezifisch für das Provider-Szenario

Die folgende Diskussion untersucht die Details der Optionen, die in der Datei sip.conf für die Verbindung zu einem VoIP-Provider festgelegt werden.

```
register=>username:password@hostname/4100
```

Die Anweisung register in der Datei sip.conf wird verwendet, um sich bei einem Provider zu registrieren. Die register-Transaktion wird mit dem Namen und dem secret authentifiziert. Sie können einen Schrägstrich („/“) verwenden, um eine extension für eingehende Anrufe anzugeben. Technisch gesehen wird die extension im „Contact“-Header-Feld der SIP-Anfrage platziert. Das Registrierungsverhalten kann durch bestimmte Parameter gesteuert werden:

```
registertimeout=20
registerattempts=10
```

Um zu überprüfen, ob die Registrierung erfolgreich war, lautete der Legacy-Konsolenbefehl `sip show registry`. In Asterisk 22 ist der entsprechende Befehl `pjsip show registrations` (für ausgehende Registrierungen) und `pjsip show endpoints` für den Status des endpoint.

Der Parameter „username“ wird im Authentifizierungs-Digest verwendet. Der Digest wird unter Verwendung von username, secret und realm berechnet:

```
username=username
```

Host definiert die Adresse oder den Namen des VoIP-Providers:

```
host=hostname
```

Die Parameter Fromuser und Fromdomain sind manchmal für die Authentifizierung erforderlich. Diese Parameter werden im SIP-From-Header-Feld verwendet:

```
fromuser=username
fromdomain=hostname
```

Wenn Sie eine Verbindung zu einem VoIP-Provider herstellen, sind Anmeldeinformationen erforderlich. Nach der ersten INVITE-Anfrage sendet Ihnen der Provider eine Nachricht namens „407 Proxy Authentication Required“; Sie geben die Anmeldeinformationen in der nachfolgenden INVITE-Nachricht an. Für eingehende Anrufe fragt Ihr Asterisk-Server nach Anmeldeinformationen für den Provider. Offensichtlich verfügt der Provider über keine gültigen Anmeldeinformationen für Ihren Asterisk-Server. Wenn Sie insecure=invite verwenden, weisen Sie Asterisk an, die Nachricht „407 Proxy Authentication Required“ nicht an den Provider zu senden und eingehende Anrufe zu akzeptieren. Sie können auch insecure=port, invite verwenden, um den peer basierend auf der IP-Adresse abzugleichen, ohne die Portnummer abzugleichen.

```
insecure=invite, port
```

### Verbinden zweier Asterisk-Server mittels SIP (sip.conf)

Sie können SIP verwenden, um zwei Asterisk-Systeme miteinander zu verbinden. Es ist wichtig, auf den dialplan zu achten, bevor Sie mit dieser Konfiguration fortfahren. Benutzer möchten im Allgemeinen andere PBXs mit minimalem Aufwand verbinden. Die Idee hierbei ist, eine extension-Nummer nur dazu zu verwenden, eine Verbindung zur anderen PBX herzustellen. Schritt 1: Bearbeiten Sie die Datei sip.conf auf Server A:

```
[B]
type=user
secret=B
host=A
disallow=all
allow=ulaw
directmedia=no
[B-out]
type=peer
fromuser=A
username=A
remotesecret=A
host=B
disallow=all
allow=ulaw
directmedia=no
```

Schritt 2: Bearbeiten Sie die Datei sip.conf auf Server B:

```
[A]
type=user
host=B
secret=A
disallow=all
allow=ulaw
directmedia=no
[A-out]
```

![Verbinden zweier Asterisk-Server mittels SIP: Server A (extensions 4400/4401) und Server B (extensions 4500/4501) tauschen SIP-Signalisierung aus, sodass Benutzer auf jeder PBX die andere anrufen können](../images/07-sip-and-pjsip-fig08.png)

```
type=peer
host=A
fromuser=B
username=B
remotesecret=B
disallow=all
allow=ulaw
directmedia=no
```

Schritt 3: Bearbeiten Sie die Datei extensions.conf auf Server A:

```
[default]
exten=_44XX,1,dial(SIP/${EXTEN},20)
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/B-out/${EXTEN})
exten=_45XX,2,hangup()
```

Schritt 4: Bearbeiten Sie die Datei extensions.conf auf Server B:

```
[default]
exten=_44XX,1,dial(SIP/A-out/${EXTEN})
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/${EXTEN})
exten=_45XX,2,hangup()
```

### Asterisk Domain-Unterstützung (sip.conf)

Das SIP-Protokoll folgt der Internet-Architektur. Das Erste, was vor der Konfiguration von SIP zu tun ist, ist die korrekte Einrichtung der DNS-Server. In einer SIP-Umgebung können Sie einen Benutzer anrufen, der sich bei einem beliebigen SIP-Proxy befindet, und andere Benutzer können Sie ebenfalls über Ihren SIP Uniform Resource Identifier (URI) anrufen. Um einen DNS-Server für SIP einzurichten, müssen Sie SRV-Einträge zu Ihrem DNS-Server hinzufügen.

```
; SIP server/proxy and its backup server/proxy
sip1.yourdomain.com
21600 IN A
200.180.4.169
sip2.yourdomain.com
21600 IN A
200.175.61.150
;
; DNS SRV records for SIP
_sip._udp.yourdomain.com  21600 IN SRV 10 0 5060 sip1.voip.school.
_sip._udp.yourdomain.com  21600 IN SRV 20 0 5060 sip2.voip.school.
```

Nach der Konfiguration des DNS können Sie den URI verwenden, der auf einen SIP-Benutzer, ein SIP-Telefon oder eine Telefon-extension verweist. Ein SIP-URI sieht ähnlich aus wie eine E-Mail-Adresse (z. B. sip:chuck@yourpartnerdomain.com). Bei Verwendung von SIP-URIs ist keine Telefonnummer erforderlich, um einen Anruf von einem SIP-Telefon zu einem anderen zu tätigen. Um einen externen Benutzer anzurufen, verwenden Sie einfach eine Anweisung wie die unten gezeigte.

```
exten=4000,1,dial(SIP/chuck@yourpartnerdomain.com)
```

Bestimmte Parameter können das Domain-Verhalten steuern.

```
srvlookup=yes
```

Dieser Parameter aktiviert DNS-SRV-Lookups bei ausgehenden Anrufen. Mit diesem Parameter ist es möglich, Anrufe unter Verwendung von SIP-Namen basierend auf der Domain zu tätigen.

```
allowguest=yes
```

Dieser Parameter ermöglicht es, eine externe INVITE-Anfrage ohne Authentifizierung zu verarbeiten. Er verarbeitet den Anruf innerhalb des im general-Abschnitt oder in der domain-Anweisung definierten context. Warnung: Wenn Sie einen context im general-Abschnitt mit Zugriff auf das PSTN definieren, kann ein externer Benutzer das PSTN über Ihre PBX anrufen. In diesem Fall fallen für Sie alle Gebühren an. Erlauben Sie in dem im general-Abschnitt definierten context nur Ihre eigenen extensions.

![Verbindung zu anderen SIP-Servern nach Domain: youdomain.com und yourpartnerdomain.com tauschen SIP-Signalisierung aus, sodass Benutzer wie lee und bruce chuck und norris mittels SIP-URIs anrufen können](../images/07-sip-and-pjsip-fig09.png)

```
domain=acme.com,default
```

Der domain-Befehl ermöglicht es Ihnen, mehr als eine Domain innerhalb von Asterisk zu verwalten. Wenn ein Anruf von einer bestimmten Domain kommt, wird er an einen bestimmten context weitergeleitet.

```
;autodomain=yes
```

Dieser Parameter schließt die lokale IP und den Hostnamen in die erlaubten Domains ein.

```
;allowexternaldomains=no
```

Der Standardwert ist yes. Entfernen Sie das Kommentarzeichen vor der Zeile, um Anrufe an externe Domains zu unterbinden.

### SIP-Erweiterte Konfigurationen (sip.conf)

Dieser Abschnitt erläutert einige erweiterte Parameter des Legacy-SIP-Kanals, wie Presence, Codec-Auswahl, DTMF-Optionen und QoS-Paketmarkierung. Die **Konzepte** (BLF/Presence, Codec-Aushandlung, DTMF-Modi, DSCP-Markierung) gelten auch für PJSIP, aber die hier gezeigten `sip.conf` Parameternamen existieren in Asterisk 22 **nicht**. Bei PJSIP ist der DTMF-Modus `dtmf_mode=` an einem endpoint, und Codecs werden mit `allow=`/`disallow=` eingestellt.

#### SIP Presence

SIP Presence ist in Asterisk teilweise implementiert. Asterisk unterstützt Anfragen wie SUBSCRIBE und NOTIFY für Benutzer in Abhängigkeit vom Status eines Kanals. Asterisk unterstützt die SIP-Methode PUBLISH nicht. Mit anderen Worten: Sie können die Zustände (besetzt, frei und klingelnd) eines Kanals abonnieren, aber keine Informationen wie „abwesend“ oder „nicht stören“ veröffentlichen. Das häufigste Szenario für Presence ist das Busy Lamp Field (BLF), bei dem Sie das Verhalten eines KS-Systems mit Lampen für jede extension und jeden trunk simulieren. SIP-Parameter für Presence:

- allowsubscribe=yes: Erlaubt SIP-Abonnement-Methoden
- subscribecontext=sip_subscribers: Context, in dem nach Hints gesucht werden soll
- notifyring=yes: Sendet SIP NOTIFY bei Klingeln
- notifyhold=yes: Sendet SIP NOTIFY bei Halten
- counteronpeer (umbenannt von limitonpeer für Asterisk 1.4.x): Wendet den Zähler nur auf der Peer-Seite an
- callcounter=yes: Aktiviert Anrufzähler im Gerät.
- busylevel=1: Schwellenwert für die Anzahl der Anrufe, ab dem das Gerät als besetzt gilt.

Zum Beispiel: Schritt 1: Das Testen von SIP-Presence mit Asterisk ist nicht schwer. Konfigurieren wir zunächst die Dateien sip.conf und extensions.conf.

In der Datei sip.conf

```
[general]
bindaddr=0.0.0.0
bindport=5060
disallow=all
allow=ulaw
allowsubscribe=yes
notifyringing=yes
notifyhold=yes
limitonpeer=yes
counteronpeer=yes
subscribecontext=default
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
[2001]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
In the file extensions.conf
[default]
exten=2000,hint,SIP/2000
exten=2001,hint,SIP/2001
exten=_20XX,1,dial(SIP/${EXTEN})
exten=_20XX,n,Hangup()
```

Schritt 2: Konfigurieren Sie nun das Softphone für die Nutzung von Presence. Wir zeigen Ihnen, wie Sie das SipPulse Softphone konfigurieren.

- Sequenz: Rechtsklick->SIP Account Settings->Properties->Presence
- Ändern Sie das Presence-Modell von Peer-to-Peer auf Presence Agent, wodurch das Softphone Asterisk für SIP-Ereignisse abonniert.

Schritt 3: Fügen Sie den Kontakt zu anderen Softphones hinzu. In diesem Beispiel ist das SipPulse Softphone Konto 2000, also fügen wir einen Kontakt für Konto 2001 hinzu. Sequenz: Öffnen Sie das rechte Panel (Presence-Panel im Softphone)->Klicken Sie auf Contacts->Add a contact. Geben Sie den Namen 2001 ein. Anzeigen als 2001 und vergessen Sie nicht, das Kästchen Show this contact’s availability zu aktivieren.

Schritt 4: Rufen Sie nun die extension 2001 an und überprüfen Sie den Status des Telefons im rechten Panel des Softphones. Verwenden Sie den Konsolenbefehl `core show hints`, um zu sehen, wie sich der Presence-Status auf dem Server ändert (im Legacy chan_sip zeigte `sip show inuse` an, wie viele Anrufe Sie auf jeder Leitung hatten). Verwenden Sie in Asterisk 22 `pjsip show endpoints`, um den Status von endpoint und Kanal zu überprüfen. Der Presence/BLF-Status erscheint in den Kontakten oder im BLF-Panel des Softphones — wie genau dies angezeigt wird, hängt vom Client ab.

#### Codec-Konfiguration

Die Codec-Konfiguration ist einfach und unkompliziert. Sie können die Wörter allow und disallow im [general]-Abschnitt oder im Peer/User-Abschnitt festlegen. Die bewährte Methode ist die Standardisierung des Codecs, um Transcoding zu vermeiden, das prozessorintensiv ist. Bitte verwenden Sie denselben Codec für Nachrichten und Ansagen.

```
[general]
disallow=all
allow=g729
```

#### DTMF-Optionen

Gelegentlich leiten Sie Ziffern an eine Anwendung wie Voicemail oder ein Interactive Voice Response (IVR) weiter. Es ist wichtig, DTMF korrekt zu übermitteln. Die einfachste Methode zur Übermittlung von DTMF heißt inband. Sie wird im [general]- oder Peer/User-Abschnitt der Datei sip.conf eingestellt. Wenn Sie dtmfmode=inband einstellen, werden DTMF-Töne als Töne im Audiokanal erzeugt. Das Hauptproblem bei dieser Methode ist, dass bei der Komprimierung des Audiokanals mit einem Codec wie g729 die Töne verzerrt werden und DTMF-Töne nicht ordnungsgemäß erkannt werden. Wenn Sie planen, dtmfmode=inband zu verwenden, nutzen Sie den g.711-Codec (ulaw und alaw).

```
dtmfmode=inband
```

Ein anderer Ansatz ist die Verwendung von RFC2833, das es Ihnen ermöglicht, DTMF-Töne als benannte Ereignisse in den RTP-Paketen zu übermitteln.

```
dtmfmode=rfc2833
```

Schließlich können Sie DTMF-Ziffern innerhalb von SIP-Paketen anstelle von RTP-Paketen übermitteln. Diese Methode ist in RFC3265 (Signalisierungsereignisse) und RFC2976 definiert.

```
dtmfmode=info
```

Seit der Veröffentlichung von Version 1.2 ist es möglich, Folgendes zu verwenden:

```
dtmfmode=auto
```

Dies versucht, RFC2833 zu verwenden; falls dies nicht möglich ist, werden Inband-Töne verwendet.

#### Konfiguration der Quality of Service (QoS)-Markierung

QoS ist eine Reihe von Techniken, die für die Sprachqualität verantwortlich sind. QoS ist so implementiert, dass Bandbreite, Latenz und Jitter reduziert werden. Die wichtigsten QoS-Funktionen sind Paketplanung, Fragmentierung und Header-Komprimierung. QoS wird in Switches und Routern implementiert, nicht von Asterisk selbst. Asterisk kann jedoch Routern und Switches helfen, indem es Pakete für die Express-Zustellung markiert. Die Markierung erfolgt unter Verwendung von Differentiated Services Code Points (DSCP), die in RFC 2474 und RFC 2475 definiert sind.

```
tos_sip=cs3
tos_audio=ef
tos_video=af41
```

Ab Version 1.4 können Sie unterschiedliche Codes für Signalisierung (SIP), Audio (RTP) und Video (RTP) angeben.

### SIP-Authentifizierung (sip.conf)

Wenn das Legacy-System `chan_sip` einen SIP-Anruf empfing, folgte es den im folgenden Diagramm beschriebenen Regeln. Drei Parameter spielten eine wichtige Rolle bei der SIP-Authentifizierung. In Asterisk 22 wird die Authentifizierung stattdessen mit PJSIP `auth` Objekten (`type=auth`, `auth_type=userpass`, `username=`, `password=`) konfiguriert, auf die ein endpoint verweist, und die IP-Zugriffskontrolle erfolgt mit `permit=`/`deny=` am endpoint oder über eine `acl`.

![Entscheidungsfluss der Legacy chan_sip-Authentifizierung: Asterisk prüft den From-Header gegen die sip.conf, versucht den passenden type=user/peer-Abschnitt und MD5-Anmeldeinformationen und greift auf insecure=invite oder allowguest zurück, bevor der Anruf erlaubt oder verweigert wird](../images/07-sip-and-pjsip-fig10.png)

```
allowguest=yes/no
```

Dieser Parameter steuert, ob ein Benutzer ohne entsprechenden peer ohne Namen und secret authentifizieren kann. Wir haben diesen Parameter im Abschnitt zur Domain-Unterstützung diskutiert.

```
insecure=invite,port
```

Wenn wir insecure=invite verwenden, generiert Asterisk nicht die Nachricht „407 Proxy Authentication Required“. Ohne diese Nachricht kann der Benutzer einen Anruf ohne Authentifizierung tätigen. Dies wird häufig verwendet, um eine Verbindung zu VoIP-Dienstanbietern herzustellen. Die Anrufe, die vom VoIP-Dienstanbieter kommen, sind in der Regel nicht authentifiziert.

```
autocreatepeer=yes/no
```

Dieser Befehl wird verwendet, wenn Asterisk mit einem SIP-Proxy verbunden ist. Er erstellt dynamisch einen peer für jeden Anruf. Wenn diese Option aktiviert ist, kann sich jeder UAC mit dem Asterisk-Server verbinden. Es ist wichtig, die IP-Verbindung auf den SIP-Proxy zu beschränken. Der SIP-Proxy wiederum kümmert sich um die Zugriffskontrolle. Die Peer-Konfiguration basiert auf den allgemeinen Optionen sowie dem „Contact“-Header-Feld des SIP-Pakets. Warnung: Verwenden Sie dies mit äußerster Vorsicht, da es Asterisk vollständig öffnet.

```
secret=secret, remotesecret=secret
```

Dieser Parameter konfiguriert das secret für die Authentifizierung; verwenden Sie secret für eingehende Anfragen und remotesecret für ausgehende Anfragen. Wenn Sie die secrets nicht in Textdateien präsentieren möchten, können Sie md5secret verwenden, um einen Hash anstelle des secrets einzufügen. Um das MD5-secret zu generieren, können Sie Folgendes verwenden:

```
echo -n "username:realm:secret" |md5sum
```

Verwenden Sie dann die folgende Anweisung:

```
md5secret=0b0e5d467890....
```

Warnung: Vergessen Sie nicht, den Parameter –n zu verwenden; der Zeilenumbruch wird bei der MD5-Berechnung verwendet.

```
deny=0.0.0.0/0.0.0.0
permit=192.168.1.0/255.255.255.0
```

Die obigen Anweisungen verweigern alle IP-Adressen und erlauben UACs nur aus dem lokalen Netzwerk (192.168.1.0/24).

#### RTP-Optionen

Es ist möglich, einige RTP-Parameter zu steuern.

```
rtptimeout=60
```

Dies beendet Anrufe ohne RTP-Aktivität für mehr als 60 Sekunden, wenn sie nicht gehalten werden.

```
rtpholdtimeout=120
```

Dies beendet Anrufe ohne RTP-Aktivität auch im Haltezustand (sollte größer als rtptimeout sein).

### SIP NAT-Traversal (sip.conf)

Die NAT-*Theorie* (die vier NAT-Typen, das Contact-Header-Problem, Keep-alives und das Erzwingen von Medien durch den Server) ist protokollspezifisch und wird im Kapitel *SIP & PJSIP in depth* behandelt. Die hier gezeigten `sip.conf` Parameter (`nat=`, `qualify=`, `directmedia=`, `externaddr=`, `localnet=`) sind **Legacy chan_sip** und wurden in Asterisk 21+ entfernt. Bei PJSIP werden diese auf Transport/Endpoint-Einstellungen wie `rewrite_contact=yes`, `force_rport=yes`, `rtp_symmetric=yes`, `direct_media=no`, `external_media_address`, `external_signaling_address` und `local_net=` am Transport sowie `qualify_frequency=` am AOR abgebildet.

Im Legacy chan_sip hatte der Parameter `nat` fünf Optionen:

- nat = no — Keine spezielle NAT-Behandlung außer RFC3581
- nat = force_rport — So tun, als gäbe es einen rport-Parameter, auch wenn keiner vorhanden war
- nat = comedia — Medien an den Port senden, von dem Asterisk sie empfangen hat, unabhängig davon, wohin das SDP das Senden vorgibt.
- nat = auto_force_rport — Die Option force_rport setzen, wenn Asterisk NAT erkennt (Standard)
- nat = auto_comedia — Die Option comedia setzen, wenn Asterisk NAT erkennt

Wenn Sie die Anweisung „nat=force_rport“ in die Datei sip.conf schreiben, weisen Sie Asterisk an, die Adresse im „Contact“-Header-Feld des SIP-Headers zu ignorieren und die Quell-IP-Adresse und den Port im IP-Header des Pakets zu verwenden, sowie die Medien an die Adresse zurückzusenden, von der sie empfangen wurden, wobei der Inhalt des SDP-Headers ignoriert wird.

```
nat=force_rport,comedia
```

Es ist notwendig, die NAT-Zuordnung offen zu halten. Wenn das NAT-Timeout abläuft, kann Asterisk kein INVITE an den UAC senden. Der UAC kann zwar Anrufe tätigen, aber keine empfangen. Die folgende Anweisung kann verwendet werden, um NAT offen zu halten.

```
qualify=yes
```

Qualify sendet regelmäßig ein SIP-Paket unter Verwendung der OPTIONS-Methode, was dazu beiträgt, NAT offen zu halten. Qualify sendet alle 60 Sekunden ein OPTIONS-Paket und alle 10 Sekunden, wenn der Host nicht erreichbar ist. Sie können „sip show peers“ verwenden, um die Latenz für die Peers zu sehen. Wenn das NAT des Benutzers vom symmetrischen Typ ist, ist es nicht möglich, Pakete direkt von einem UAC zum anderen zu senden; in diesem Fall müssen Sie das RTP mittels Asterisk erzwingen:

```
directmedia=no
```

#### Asterisk hinter NAT (sip.conf)

Alle vorherigen Szenarien setzen voraus, dass der Asterisk-Server eine externe (gültige) Internetadresse hat. Manchmal wird der Asterisk-Server hinter einer Firewall mit NAT implementiert. In diesem Fall sind einige zusätzliche Konfigurationen erforderlich.

![Asterisk hinter NAT: eine Firewall bildet die öffentliche Adresse 200.180.4.168 auf den internen Asterisk-Server (192.168.1.100) ab und leitet SIP auf UDP 5060 sowie den RTP-Bereich UDP 10000–20000, der in rtp.conf definiert ist, weiter](../images/07-sip-and-pjsip-fig13.png)

1. Konfigurieren Sie die Firewall so, dass der UDP-Port 5060 statisch an den Asterisk-Server weitergeleitet wird.
2. Konfigurieren Sie die Firewall so, dass die UDP-Ports von 10000 bis 20000 statisch weitergeleitet werden.

Wenn Sie die Anzahl der geöffneten Ports einschränken möchten, können Sie die Datei `rtp.conf` bearbeiten, um den RTP-Portbereich zu ändern. Ein anderer Weg ist die Verwendung einer intelligenten Firewall, die das SIP-Protokoll unterstützt, um die RTP-Ports dynamisch zu öffnen.

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

Schritt 3: Konfigurieren Sie Asterisk so, dass die externe Adresse in die Header-Felder der SIP-Pakete einschließlich Session Description Protocol (SDP) aufgenommen wird. Sie können dies erreichen, indem Sie die folgenden zwei Anweisungen zur Datei sip.conf hinzufügen:

```
externaddr=200.180.4.168
;External IP address
localnet=192.168.1.0/255.255.255.0
;Internal Network Address
nat=force_rport,comedia
```

Der erste Parameter externaddr weist Asterisk an, die externe IP-Adresse innerhalb der SIP-Header für externe Ziele einzufügen. Der zweite Parameter localnet ermöglicht es Asterisk, zwischen externen und internen Adressen zu unterscheiden. Optional können Sie externhost verwenden, wenn Sie ein dynamisches DNS mit einer DHCP-Adresse auf dem Server nutzen.

### SIP-Wählstrings (chan_sip)

Die unten gezeigte `SIP/...` Wählstring-Technologie ist der entfernte chan_sip-Treiber. Verwenden Sie in Asterisk 22 stattdessen die `PJSIP/...` Technologie — zum Beispiel `Dial(PJSIP/2000)` oder `Dial(PJSIP/${EXTEN}@provider)`. Die Formen und die Bedeutung sind ansonsten analog.

Sie können ein Legacy-SIP-Ziel mit verschiedenen Wählstrings anrufen:

```
SIP/peer
```

- ; Erfordert einen definierten peer in der sip.conf

```
SIP/flavio@voffice.com.br ; By the URI
SIP/[exten@]peer[:portno]
SIP/[user:password@domain/extension
```

Beispiele hierfür sind:

```
exten=>s,1,Dial(SIP/ipphone)
exten=>s,1,Dial(SIP/info@voffice.com.br)
exten=>s,1,Dial(SIP/192.168.1.8:5060,20)
exten=>s,1,Dial(SIP/8500@sip.com:9876)
```

## Migration eines Legacy-chan_sip-Systems auf PJSIP

Da `chan_sip` in Asterisk 21 entfernt wurde und in Asterisk 22 nicht mehr vorhanden ist, muss jede bestehende `sip.conf`-Bereitstellung auf PJSIP migriert werden. Die größte konzeptionelle Änderung besteht darin, dass ein einzelner `sip.conf` `[peer]` oder `[friend]` in mehrere PJSIP-Objekte aufgeteilt wird, von denen jedes eine `type=` besitzt: ein **endpoint** (Einstellungen für Anruf/codec/Medien), ein oder mehrere **aor**-Objekte (wo das Gerät erreichbar ist / Registrierung), ein **auth**-Objekt (Anmeldedaten) und ein gemeinsamer **transport** (der Socket, der auf Verbindungen wartet, NAT-Adressen). Die folgende Tabelle ordnet die gängigsten Konzepte ein.

| Legacy sip.conf Konzept | PJSIP Äquivalent (pjsip.conf) |
| --- | --- |
| `[peer]` / `[friend]` Block | `type=endpoint` + `type=aor` + `type=auth` (referenziert über `auth=` und `aors=`) |
| `type=friend` / `type=peer` / `type=user` | ein einzelner `type=endpoint` (PJSIP unterscheidet nicht zwischen friend/peer/user) |
| `host=dynamic` (Gerät registriert sich) | `type=aor` mit `max_contacts=1`; das Gerät führt ein REGISTER aus, um seinen Kontakt zu aktualisieren |
| `host=<ip/hostname>` (statisch) | `type=aor` mit einem statischen `contact=sip:host:port` |
| `register=>user:secret@host/ext` (ausgehend) | `type=registration` (`server_uri=`, `client_uri=`, `outbound_auth=`) |
| `secret=` / `username=` | `type=auth`, `auth_type=userpass`, `username=`, `password=` |
| `context=` | `context=` auf dem endpoint |
| `disallow=all` / `allow=ulaw` | `disallow=all` / `allow=ulaw` auf dem endpoint (gleiche Syntax) |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` (PJSIP) — auch `inband`, `info`, `auto` |
| `directmedia=yes/no` | `direct_media=yes/no` auf dem endpoint |
| `nat=force_rport,comedia` | `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes` (endpoint) |
| `qualify=yes` | `qualify_frequency=` (Sekunden) auf dem **aor** |
| `externaddr=` | `external_media_address=` und `external_signaling_address=` auf dem **transport** |
| `localnet=` | `local_net=` auf dem **transport** |
| `insecure=invite` (Provider, keine Authentifizierung) | `auth=`/`outbound_auth=` weglassen und `identify` verwenden (`type=identify`, `match=`) |
| `allowguest=yes` | `anonymous` endpoint + `allow_unauthenticated_options` (mit Vorsicht verwenden) |
| `tos_sip` / `tos_audio` | `tos_audio` / `tos_video` (und `cos_audio` / `cos_video`) auf dem endpoint |

Eine registrierende extension, die in der Legacy-`sip.conf` so aussah:

```
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
disallow=all
allow=ulaw
secret=senha
```

wird in `pjsip.conf` unter Asterisk 22 zu folgendem:

```
[2000]
type=endpoint
context=default
disallow=all
allow=ulaw
dtmf_mode=rfc4733
direct_media=no
auth=2000
aors=2000

[2000]
type=auth
auth_type=userpass
username=2000
password=senha

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

### Das Konvertierungsskript sip_to_pjsip.py

Asterisk liefert ein Hilfsskript mit, **`sip_to_pjsip.py`**, das eine bestehende `sip.conf` liest und eine `pjsip.conf` erstellt. Sie können es direkt im Verzeichnis /etc/asterisk ausführen. Das Dienstprogramm befindet sich im Asterisk-Quellcodebaum unter `contrib/scripts/sip_to_pjsip/`, wobei `${PATH_TO_ASTERISK_SOURCE}` der Pfad ist, in dem sich die Asterisk-Quelldateien befinden (normalerweise /usr/src/asterisk-22.x.y/):

```
${PATH_TO_ASTERISK_SOURCE}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Wenn Sie es mit der Option `--help` ausführen, sehen Sie die verfügbaren Optionen:

```
-h, --help                help
-p, --prefix PREFIX       prefix to use for the included config files
-q, --quiet               suppress warnings and informational messages
```

Es akzeptiert auch optionale Positionsargumente — `[input-file [output-file]]`, wobei standardmäßig `sip.conf` und `pjsip.conf` im aktuellen Verzeichnis verwendet werden.

Betrachten Sie die Ausgabe als **Ausgangspunkt**: Überprüfen Sie jedes generierte Objekt, insbesondere transports, NAT-Einstellungen und codec-Listen, und testen Sie gründlich, bevor Sie in die Produktion gehen.

Lassen Sie uns die sip.conf in unseren begleitenden Labs an der VoIP School Blackbelt (voip.school) migrieren.

#### sip.conf

```
[general]
bindport=5060
bindaddr=0.0.0.0
context=dummy
disallow=all
allow=ulaw
alwaysauthreject=yes
allowguest=no
register=>1020:supersecret@sip.flagonc.com:5600/9999
[alice]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[bob]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[siptrunk]
type=peer
defaultuser=1020
secret=supersecret
port=5600 ; nor 5060, 5600
insecure=invite
host=sip.flagonc.com
fromuser=1020
fromdomain=sip.flagonc.com
context=from-siptrunk
```

#### pjsip.conf

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[alice]
qualify = yes
[bob]
qualify = yes
[siptrunk]
defaultuser = 1020
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
[reg_sip.flagonc.com]
type = registration
retry_interval = 20
max_retries = 10
contact_user = 9999
expiration = 120
transport = transport-udp
outbound_auth = auth_reg_sip.flagonc.com
client_uri = sip:1020@sip.flagonc.com:5600
server_uri = sip:sip.flagonc.com:5600
[auth_reg_sip.flagonc.com]
type = auth
password = supersecret
username = 1020
[alice]
type = aor
max_contacts = 1
[alice]
type = auth
username = alice
password = #supersecret#
[alice]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = alice
outbound_auth = alice
aors = alice
[bob]
type = aor
max_contacts = 1
[bob]
type = auth
username = bob
password = #supersecret#
[bob]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = bob
outbound_auth = bob
aors = bob
[siptrunk]
type = aor
contact = sip:1020@sip.flagonc.com:5600
[siptrunk]
type = identify
endpoint = siptrunk
match = sip.flagonc.com
[siptrunk]
type = auth
username = siptrunk
password = supersecret
[siptrunk]
type = endpoint
context = from-siptrunk
disallow = all
allow = ulaw
from_user = 1020
from_domain = sip.flagonc.com
auth = siptrunk
outbound_auth = siptrunk
aors = siptrunk
```

Obwohl die Konvertierung in Ordnung zu sein scheint, können wir sehen, dass einige Elemente wie qualify=yes nicht direkt zugeordnet werden können. Um dies zu beheben, müssen Sie im aor-Abschnitt den Befehl qualify_frequency=time in Sekunden hinzufügen. Siehe das Beispiel unten.

```
[bob]
type = aor
max_contacts = 1
qualify_frequency=15
```

Die vollständige PJSIP-Konfiguration wird im Kapitel *SIP & PJSIP in depth* behandelt, und die offizielle Dokumentation unter docs.asterisk.org bietet eine umfassende Abdeckung des Channels. In unseren begleitenden Labs unter voip.school können Sie in Lab 5 das gerade Gelernte praktisch anwenden.

## Zusammenfassung

Dieses Kapitel fasste die Kanaltechnologien zusammen, die älter sind als die heutigen reinen VoIP-Implementierungen, die aber von Asterisk 22 weiterhin unterstützt werden. Sie haben gesehen, wie **analog**e Leitungen und Telefone über **FXO/FXS**-Schnittstellen an DAHDI angebunden werden, wie **digital**e **TDM**-Verbindungen (E1/T1 und ISDN PRI/BRI) bereitgestellt werden und wie **IAX2** (`chan_iax2`) auch heute noch als effizienter, NAT-freundlicher Server-zu-Server-trunk dient, obwohl es mittlerweile als veraltet gilt. Sie haben sich zudem erneut mit dem ausgemusterten **`chan_sip`**-Treiber und dessen `sip.conf`-Syntax befasst – die Sie in älteren Systemen antreffen werden, die aber in Asterisk 22 nicht mehr existiert – und haben die Migration eines solchen Systems auf PJSIP mithilfe der Konzept-Zuordnungstabelle und des `sip_to_pjsip.py`-Skripts durchgearbeitet. Die Faustregel lautet: Greifen Sie nur dann auf die Inhalte dieses Kapitels zurück, wenn echte Hardware oder ein bestehendes Altsystem Sie dazu zwingen; bei allen neuen Projekten ist PJSIP über IP der Standard.

## Quiz

1. Markieren Sie bezüglich der beiden analogen Foreign eXchange-Schnittstellen die korrekten Aussagen (wählen Sie alle zutreffenden aus):
   - A. Eine FXO-Schnittstelle verbindet sich mit der Vermittlungsstelle des PSTN und bezieht von dort ein Freizeichen.
   - B. Eine FXS-Schnittstelle stellt einem analogen Standardtelefon, Fax oder Modem ein Freizeichen und Rufspannung zur Verfügung.
   - C. Eine FXS-Schnittstelle ist der korrekte Weg, um Asterisk mit einer Telefonleitung zu verbinden.
   - D. Eine FXO-Schnittstelle kann auch an einen Nebenstellenanschluss einer alten PBX angeschlossen werden.
2. Welche der folgenden Punkte gehören zur Überwachungssignalisierung (Supervision Signaling) auf einer analogen Leitung (wählen Sie alle zutreffenden aus)?
   - A. On-hook
   - B. Off-hook
   - C. Ringing
   - D. DTMF
3. Echo, Knacken und Rauschen auf einer analogen DAHDI-Karte werden meist verursacht durch:
   - A. Die Art und Weise, wie Asterisk kompiliert wurde
   - B. PCI-Interrupt-Konflikte
   - C. Einen inkorrekten SIP-codec
   - D. Einen fehlenden dialplan
4. Für eine präzise Abrechnung bei analogen Kanälen müssen Sie genau erkennen, wann die Gegenseite abhebt. Welche Funktion aktivieren Sie in Asterisk (und fordern sie beim Telefonanbieter an), um dies zu erreichen?
   - A. Answer reversal
   - B. Billing reversal
   - C. Polarity reversal
   - D. Dial-tone generation
5. Die DAHDI-Hardware ist unabhängig von Asterisk: Die physische Karte wird in `/etc/dahdi/system.conf` konfiguriert, während `chan_dahdi.conf` die Asterisk-Kanäle definiert, nicht die Hardware selbst.
   - A. Wahr
   - B. Falsch
6. Markieren Sie bezüglich der Kapazität und Signalisierung von digitalen trunks die korrekten Aussagen (wählen Sie alle zutreffenden aus):
   - A. Ein E1-trunk überträgt 30 Sprachkanäle und ein T1-trunk überträgt 24.
   - B. Ein ISDN PRI verwendet 30B+D auf einer E1 und 23B+D auf einer T1.
   - C. ISDN ist ein Beispiel für CCS-Signalisierung, während MFC/R2 ein Beispiel für CAS-Signalisierung ist.
   - D. T1 ist der digitale trunk, der am häufigsten in Europa und Lateinamerika verwendet wird.
7. Welches Dienstprogramm erkennt DAHDI-Karten automatisch und generiert `/etc/dahdi/system.conf` und `dahdi-channels.conf`?
   - A. dahdi_generator
   - B. dahdi_genconf
   - C. dahdi_cfg
   - D. generate_dahdi
8. Bei der Migration eines alten `sip.conf` `[friend]` zu PJSIP muss ein einzelner Block in mehrere Objekte aufgeteilt werden. Welche Gruppe von PJSIP `type=`-Objekten ersetzt normalerweise einen registrierenden `[friend]`?
   - A. `type=endpoint`, `type=aor` und `type=auth`
   - B. `type=peer` und `type=user`
   - C. Nur `type=sip`
   - D. `type=channel` und `type=device`
9. Was ist der größte praktische Vorteil bei der Verwendung des IAX2-trunk-Modus zwischen zwei Asterisk-Servern?
   - A. Er verschlüsselt standardmäßig jeden Anruf mit TLS
   - B. Er überträgt mehrere Anrufe unter einem einzigen Header, was Bandbreite spart
   - C. Er macht jegliche Art von codec überflüssig
   - D. Er weist für eine bessere Qualität einen separaten UDP-Port pro Anruf zu
10. RSA-Schlüssel können für die IAX2-Authentifizierung verwendet werden. Welchen Schlüssel müssen Sie geheim halten und welchen geben Sie an den anderen Server weiter?
    - A. Den öffentlichen Schlüssel geheim halten; den privaten Schlüssel teilen
    - B. Den privaten Schlüssel geheim halten; den öffentlichen Schlüssel teilen
    - C. Den gemeinsamen Schlüssel geheim halten; den privaten Schlüssel teilen
    - D. Beide Schlüssel müssen geteilt werden

**Antworten:** 1 — A, B, D · 2 — A, B, C · 3 — B · 4 — C · 5 — A · 6 — A, B, C · 7 — B · 8 — A · 9 — B · 10 — B
