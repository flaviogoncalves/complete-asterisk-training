# Installation von Asterisk 22

Im ersten Kapitel haben wir ein wenig darüber gelernt, wie Asterisk in der Telefonieumgebung nützlich ist. In diesem Kapitel werden wir behandeln, wie man Asterisk herunterlädt und installiert. Bevor wir beginnen, ist es wichtig zu lernen, wie man es kompiliert und installiert. Der Kompilierungsprozess mag für traditionelle Microsoft™ Windows™-Benutzer seltsam erscheinen, aber er ist in der Linux™-Umgebung ziemlich üblich. Man kann beim Kompilieren von Asterisk einen für die eigene Hardware optimierten Code erhalten, was wir hier tun werden. Asterisk läuft auf verschiedenen Betriebssystemen, aber wir halten die Dinge einfach und verwenden nur eines: Linux. Wir verwenden **Ubuntu 24.04 LTS**, da dessen Abhängigkeiten einfach zu installieren sind und es eine stabile, gut unterstützte Server-Distribution mit geringem Ressourcenbedarf ist. Falls Sie eine andere Distribution bevorzugen, passen Sie die Paketnamen entsprechend an.

Diese Ausgabe zielt auf **Asterisk 22 LTS** ab (veröffentlicht am 2024-10-16; voller Support bis 2028-10-16, Sicherheitsupdates bis 2029-10-16). Asterisk 22 ist die aktuelle Long-Term-Support-Version. Beachten Sie, dass Digium 2018 von **Sangoma** übernommen wurde und Asterisk nun von Sangoma gesponsert wird – Verweise auf "Digium" in diesem Kapitel beziehen sich auf die ehemalige Marke für historische Hardware.

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Die Hardwareanforderungen für Asterisk zu bestimmen;
- Linux mit den erforderlichen Abhängigkeiten zu installieren;
- Eine stabile Version über HTTPS herunterzuladen;
- Asterisk zu kompilieren; und
- Zu lernen, wie Asterisk beim Systemstart automatisch gestartet wird.

## Minimale Hardwareanforderungen

Asterisk benötigt nicht viel Hardware für den Betrieb, es gibt jedoch einige Tipps zur Auswahl der besten Hardware für Ihre Anforderungen. Sie sollten die folgenden Hauptfaktoren bei der Auswahl Ihrer Hardware berücksichtigen:

- Gesamtzahl der registrierten Benutzer. Definieren Sie, wie viele Registrierungen pro Sekunde Sie unterstützen müssen.
- Gesamtzahl der gleichzeitigen Anrufe. Definieren Sie, wie viele Netzwerkgespräche Sie im Netzwerkadapter verarbeiten und auf dem Asterisk Server überbrücken müssen.
- Welche codecs Sie unterstützen müssen. Codecs mit hoher Komplexität erfordern viel CPU/FPU-Leistung auf Ihrem Server; iLBC wurde beispielsweise von seinem Entwickler (Global IP Sound) mit etwa 18 MIPS pro Kanal für 30 ms Frames (und etwa 15 MIPS für 20 ms Frames) auf einem TI C54x DSP gemessen.
- Echounterdrückung. Die Echounterdrückung kann viel CPU/FPU beanspruchen; in einigen Fällen sollten Sie eine hardwarebasierte Echounterdrückung mittels DSPs auf der Telefonieschnittstellenkarte wählen.
- Verfügbarkeit. Verwenden Sie RAID1 oder 5, um die Verfügbarkeit zu erhöhen. Denken Sie daran, Asterisk ist eine 24x7-Anwendung.

Die Hauptkomponente für einen Asterisk Server ist der Netzwerkadapter. Ein guter Server-Netzwerkadapter wird empfohlen. Die CPU ist wichtig, wenn Sie komplexe codecs wie g.729 und iLBC sowie Echounterdrückung unterstützen müssen. Sie können dies auf dedizierte DSPs auslagern: Sangoma (ehemals Digium) bietet eine DSP-Karte namens TC400B an, die 120 gleichzeitige G.729-Anrufe unterstützen kann.

Die bewährte Methode ist die Wahl eines neuen Computers der Serverklasse von einem bekannten Hersteller. Um genau zu wissen, wie viele gleichzeitige Anrufe oder wie viele registrierte Benutzer eine bestimmte Maschine unterstützen kann, sollten Sie diese Hardware mit einem Stresstest-Tool wie SIPP (http://sipp.sourceforge.net) testen. Einige Hardwarehersteller wie Xorcom (http://www.xorcom.com) veröffentlichen ihre Ergebnisse auf ihrer Website.

Hinweis: Einige Asterisk-Anwendungen, wie ConfBridge und music on hold, benötigen eine interne Zeitquelle. Auf modernem Linux wird dies automatisch durch das integrierte `res_timing_timerfd` Modul bereitgestellt — es ist keine Telefonie-Hardware erforderlich. (Der alte `dahdi_dummy` Software-Timer existiert nicht mehr; seine Funktionalität wurde in das Hauptmodul `dahdi` in DAHDI Linux 2.3.0 integriert.) Sie können den aktiven Timer mit dem CLI-Befehl `timing test` bestätigen.

### Hardwarekonfiguration

Die Asterisk-Hardware muss nicht komplex sein. Sie benötigen keine teure Grafikkarte oder zahlreiche Peripheriegeräte. Einige Tipps zur Hardwarekonfiguration:

- Deaktivieren Sie ungenutzte USB-, serielle und parallele Anschlüsse, um den Verbrauch unnötiger Interrupts zu vermeiden.
- Eine robuste Netzwerkschnittstellenkarte ist unerlässlich.
- Seien Sie besonders vorsichtig, wenn Sie Telefonieschnittstellenkarten verwenden. Einige Karten verwenden einen 3,3-Volt-PCI-Bus, und es ist nicht einfach, Motherboards dafür zu finden. Heutzutage ist PCI Express leichter zu finden.
- Achten Sie genau auf die Festplatte; eine PBX arbeitet normalerweise im 24x7-Betrieb, während Desktop-Computer 8x5 arbeiten. Verwenden Sie keine Desktop-Hardware für eine PBX, da die Festplatte normalerweise vor dem ersten Jahr ausfällt. Meine Empfehlung ist die Verwendung einer Servermaschine oder eines Geräts, das für 24x7-Anwendungen ausgelegt ist.

### IRQ-Sharing (nur bei älteren PCI-Karten)

Dieses Problem betrifft **nur** die Installation physischer PCI/PCI-Express-Telefoniekarten (DAHDI-Hardware). Solche Karten erzeugen eine große Anzahl von Interrupts, und auf älteren Single-CPU-Systemen könnte das Teilen einer IRQ-Leitung mit einem anderen Gerät den Treiber ausbremsen und die Sprachqualität verschlechtern. Wenn Sie Telefoniekarten verwenden, widmen Sie die Maschine ausschließlich Asterisk, deaktivieren Sie alle ungenutzten On-Board-Geräte im BIOS und überprüfen Sie die zugewiesenen Interrupts mit `cat /proc/interrupts`. Moderne Multi-Core-Server, die MSI/MSI-X-Interrupts verwenden, machen IRQ-Sharing in der Praxis zu einem vernachlässigbaren Problem, und bei einer reinen VoIP-Bereitstellung (ohne Karten) müssen Sie sich darüber überhaupt keine Sorgen machen.

## Auswahl einer Linux-Distribution

Asterisk wurde ursprünglich für den Betrieb unter Linux entwickelt. Es kann jedoch auch unter BSD Unix oder macOS ausgeführt werden. Wenn Sie neu bei Asterisk sind, versuchen Sie es zunächst mit Linux, da dies wesentlich einfacher ist. Asterisk zielt offiziell auf die RHEL-Familie (CentOS/RHEL/Fedora), Ubuntu und Debian ab. Gute praktische Optionen sind heute **Debian 12**, **Ubuntu 22.04 LTS / 24.04 LTS** und **Rocky Linux 9 / AlmaLinux 9** — da CentOS Linux das Ende seines Lebenszyklus erreicht hat, sollten Sie auf Systemen der RHEL-Familie Rocky oder AlmaLinux bevorzugen. Für dieses Buch werde ich Ubuntu 24.04 LTS verwenden. Laden Sie das neueste 24.04 Point-Release-Server-Image aus dem offiziellen Release-Verzeichnis unten herunter (der genaue Dateiname enthält das aktuelle Point-Release, z. B. `ubuntu-24.04.4-live-server-amd64.iso`):

```
https://releases.ubuntu.com/24.04/
```

### Vorbereitung von Linux für Asterisk

Bevor Sie Asterisk kompilieren, benötigen Sie ein funktionierendes Linux-System, auf dem die Build-Pakete installiert sind. Installieren Sie **Ubuntu 24.04 LTS Server** in einer virtuellen Maschine oder auf einem dedizierten Rechner (verwenden Sie das 64-Bit-Image; alles in diesem Buch ist 64-Bit, obwohl Asterisk selbst immer noch 32-Bit x86 unterstützt). Wir haben für dieses Training VirtualBox verwendet; Sie können das Image unter <https://releases.ubuntu.com/24.04> herunterladen. Die Installation von Linux selbst liegt außerhalb des Rahmens dieses Buches — grundlegende Linux-Kenntnisse sind eine Voraussetzung. Sobald Linux installiert ist, fügen Sie die Asterisk-Build-Abhängigkeiten hinzu (siehe *Abhängigkeiten installieren* unten) und kompilieren anschließend Asterisk.

## Installation von Linux für Asterisk

Installieren Sie Linux wie gewohnt, ohne grafische Benutzeroberfläche. Aktivieren Sie während der Installation auch einen Mail Transfer Agent (wir verwenden **exim4**) — Asterisk wird diesen später in diesem Buch benötigen, um Voicemail-zu-E-Mail-Benachrichtigungen zu versenden. **Achtung:** Die Installation eines Betriebssystems löscht die Zielfestplatte. Wenn Sie auf physischer Hardware installieren, sichern Sie zuerst Ihre Daten; die Installation in einer virtuellen Maschine lässt Ihren Host unberührt. Starten Sie das Installationsprogramm von der Ubuntu Server ISO (oder dem virtuellen optischen Laufwerk der VM) und beantworten Sie die Eingabeaufforderungen — die meisten sind selbsterklärend.

## Abhängigkeiten installieren

Um Asterisk und DAHDI zu installieren, müssen Sie zahlreiche Software-Abhängigkeiten installieren. Der empfohlene Weg hierfür in Asterisk 22 ist die Verwendung des Skripts, das mit dem Quellcode-Baum ausgeliefert wird, da dieses die korrekten Paketnamen für jede unterstützte Distribution kennt. Nachdem Sie den Asterisk-Quellcode heruntergeladen und entpackt haben (siehe „Asterisk kompilieren“ weiter unten), führen Sie Folgendes aus:

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. Melden Sie sich als root an (oder verwenden Sie `sudo`).
2. Falls Sie die Abhängigkeiten auf einem Debian/Ubuntu-System lieber manuell installieren möchten, lautet die entsprechende Paketliste:

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

Beachten Sie, dass der Asterisk-Quellcode mittlerweile auf Git gehostet wird, weshalb `subversion` nicht mehr benötigt wird und moderne Debian/Ubuntu-Systeme `libncurses-dev` anstelle der versionierten `libncurses5-dev` bereitstellen. Bevorzugen Sie `./contrib/scripts/install_prereq install` gegenüber einer manuell gepflegten Liste, da das Skript stets die korrekten Paketnamen für Ihre Distribution nachverfolgt.

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) ist die Architektur der Treiber für analoge und digitale Karten. Vor der Installation von Asterisk ist es wichtig, DAHDI zu installieren, falls Sie analoge oder digitale Schnittstellen verwenden möchten. DAHDI existiert weiterhin für analoge/digitale Telefoniekarten, ist jedoch zunehmend ein Nischenprodukt — die meisten modernen Implementierungen sind reine VoIP-Lösungen und können diesen Abschnitt vollständig überspringen. Installieren Sie DAHDI nur, wenn Sie physische Telefonie-Schnittstellenhardware besitzen. Laden Sie die Quelldateien mit folgendem Befehl herunter:

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

Entpacken Sie die Dateien mit:

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### DAHDI-Treiber kompilieren

Sie müssen die DAHDI-Module kompilieren. Die Befehle ./configure und make menuselect wurden vor einigen Jahren eingeführt. Letzterer ermöglicht es Ihnen, auszuwählen, welche Dienstprogramme und Module erstellt werden sollen. Die folgenden Befehle führen dies aus:

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

make install-config DAHDI wurde konfiguriert. Wenn Sie DAHDI-Hardware besitzen, wird nun empfohlen, /etc/dahdi/modules zu bearbeiten, um nur die Unterstützung für die in diesem System installierte DAHDI-Hardware zu laden. Standardmäßig wird beim Start von DAHDI die Unterstützung für sämtliche DAHDI-Hardware geladen. Ich denke, dass die DAHDI-Hardware, die Sie auf Ihrem System haben, folgende ist: usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware Dieser Bildschirm (oben) fordert Sie auf, die Datei /etc/dahdi/modules zu ändern, um nur die erforderlichen Treiber für Ihre spezifische Konfiguration zu laden und die erkannte Hardware anzuzeigen. Bearbeiten Sie die Datei /etc/dahdi/modules und laden Sie nur die benötigte Hardware. In meinem Fall verwendete ich eine Testmaschine mit einer Xorcom Astribank 6FXS und 2FXO. Die Datei ist unten dargestellt.

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

Starten Sie Ihren Computer neu und überprüfen Sie das korrekte Laden der Treiber.

## Welche Version soll man wählen

Als Faustregel gilt, dass Sie die Version mit den benötigten Funktionen verwenden sollten. Asterisk folgt einem Release-Modell, bei dem sich LTS-Releases (Long-Term Support) und Standard-Releases abwechseln. Zum Zeitpunkt dieser Ausgabe ist **Asterisk 22 das aktuelle LTS-Release** (veröffentlicht im Oktober 2024; das neueste Point-Release ist 22.10.0), was es zur besten Wahl für den aktuellen Zeitpunkt macht. Asterisk 20 ist das vorherige LTS-Release, und Version 16 (verwendet in der ersten Ausgabe) hat das Ende ihres Lebenszyklus erreicht. Für Produktionssysteme sollten Sie immer ein LTS-Release wählen.

## Compiling Asterisk

Wenn Sie bereits Software kompiliert haben, wird das Kompilieren von Asterisk eine einfache Aufgabe sein. Führen Sie die folgenden Befehle aus, um Asterisk zu kompilieren und zu installieren. Denken Sie daran, dass Sie mit make menuselect auswählen können, welche Anwendungen und Module erstellt werden sollen. Schritt 1: Laden Sie den Quellcode herunter

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

Schritt 2: Installieren Sie die Build-Voraussetzungen (siehe „Installing dependencies“ oben)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

Schritt 3: Konfigurieren Sie den Build

```
./configure
```

Schritt 4: Wählen Sie die zu erstellenden Module aus

```
make menuselect
```

Verwenden Sie make menuselect, um nur die notwendigen Module zu installieren. In Asterisk 22 ist der SIP-Kanal **chan_pjsip** (standardmäßig erstellt); das alte **chan_sip** wurde in Asterisk 21 entfernt und existiert nicht mehr. Opus *pass-through* funktioniert sofort (das in-tree `res_format_attr_opus` Modul übernimmt die SDP-Aushandlung), aber das **codec_opus** Transcoding-Modul ist weiterhin ein externes, proprietäres Binärpaket von Sangoma/Digium — wenn Sie es in menuselect auswählen, wird es von den Servern von Digium heruntergeladen. Das Binärpaket ist kostenlos. Details finden Sie weiter unten unter „Selecting modules with menuselect“.

Schritt 5: Erstellen und installieren Sie Asterisk und erstellen Sie dann die Standardkonfigurations- und Beispieldateien

```
make
make install
make samples
make config
ldconfig
```

`make install` installiert die Binärdateien und Module, `make samples` schreibt die Beispielkonfigurationsdateien in `/etc/asterisk`, `make config` installiert das SysV init-Startskript für Ihre erkannte Distribution (z. B. `/etc/init.d/asterisk` unter Debian/Ubuntu) und `ldconfig` aktualisiert den Cache der gemeinsam genutzten Bibliotheken. Eine systemd-Unit wird ebenfalls im Quellbaum unter `contrib/systemd/asterisk.service` mitgeliefert, aber `make config` installiert diese nicht automatisch — kopieren Sie sie selbst an den entsprechenden Ort, wenn Sie Asterisk lieber unter systemd ausführen möchten (siehe unten).

### Selecting modules with menuselect

`make menuselect` öffnet ein textbasiertes Menü, in dem Sie genau auswählen können, welche Anwendungen, codecs, Kanäle und Ressourcen erstellt werden sollen. Ein paar spezifische Hinweise zu Asterisk 22:

- **chan_pjsip** (unter *Channel Drivers*) ist der moderne SIP-Kanal und standardmäßig aktiviert; er ist der einzige SIP-Kanal in Asterisk 22.
- **codec_opus** (unter *Codec Translators*) ist ein **externes** Modul (der menuselect-Eintrag lautet „Download the Opus codec from Digium“); wenn Sie es aktivieren, ruft `make` das kostenlose, proprietäre Binärpaket von Sangoma/Digium ab. Opus pass-through selbst benötigt kein zusätzliches Modul. Das **codec_g729** Modul von Sangoma ist ebenfalls verfügbar — das Binärpaket kann kostenlos heruntergeladen werden, aber für legales G.729 Transcoding ist eine kostenpflichtige Lizenz pro Kanal erforderlich.
- Wählen Sie die gewünschten Soundformate und Sprachen in den Menüs *Core Sound Packages*, *Music On Hold File Packages* und *Extras Sound Packages* aus; alles, was Sie dort auswählen, wird während `make install` automatisch heruntergeladen und installiert.

Nachdem Sie Ihre Auswahl getroffen haben, wählen Sie **Save & Exit** und fahren Sie mit `make` fort.

## Starten und Stoppen von Asterisk

Mit dieser minimalen Konfiguration ist es möglich, Asterisk erfolgreich zu starten. Zum Lernen und zur Fehlersuche können Sie Asterisk im Vordergrund starten, wobei es an die Konsole angehängt bleibt:

```
/usr/sbin/asterisk -vvvgc
```

Verwenden Sie den CLI-Befehl `core stop now`, um Asterisk herunterzufahren:

```
*CLI> core stop now
```

### Starten von Asterisk mit systemd

Auf modernen Linux-Distributionen (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9) ist der Systemdienst-Manager **systemd**. Asterisk liefert eine systemd-Unit unter `contrib/systemd/asterisk.service` im Quellbaum mit; kopieren Sie diese nach `/etc/systemd/system/asterisk.service` und führen Sie `systemctl daemon-reload` aus. Sobald Asterisk installiert ist, ist die empfohlene Methode, Asterisk in der Produktion zu betreiben, über `systemctl`:

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

Sobald Asterisk als Dienst läuft, verbinden Sie sich mit dessen CLI über `asterisk -r` (verbinden) oder `asterisk -rvvv` (verbinden mit ausführlicher Ausgabe).

Auf älteren Systemen wurde Asterisk über das klassische SysV-Init-Skript (`/etc/init.d/asterisk`) und den **safe_asterisk**-Wrapper gestartet, der Asterisk bei einem Absturz automatisch neu startete. Bei systemd wird der automatische Neustart durch die `Restart=`-Direktive der Unit-Datei gehandhabt, daher wird `safe_asterisk` im Allgemeinen nicht mehr benötigt. Der klassische Init/`safe_asterisk`-Ansatz funktioniert zwar weiterhin, ist aber auf systemd-basierten Distributionen veraltet.

### Asterisk-Laufzeitoptionen

Der Startprozess von Asterisk ist sehr einfach. Wenn Asterisk ohne Parameter ausgeführt wird, startet es als Daemon.

```
/sbin/asterisk
```

Sie können auf die Asterisk-Konsole zugreifen, indem Sie den folgenden Befehl ausführen. Bitte beachten Sie, dass mehr als ein Konsolenprozess gleichzeitig ausgeführt werden kann.

```
/sbin/asterisk -r
```

### Verfügbare Laufzeitoptionen für Asterisk

Sie können die verfügbaren Laufzeitoptionen mit `asterisk -h` anzeigen.

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## Installationsverzeichnisse

Asterisk wird in verschiedenen Verzeichnissen installiert, die in der Datei asterisk.conf geändert werden können. Zu Schulungszwecken würde ich den Wert für verbose von 3 auf 15 erhöhen; für den Produktivbetrieb sollte er auf 3 belassen werden. Die Optionen `maxcalls` und `maxload` sind gute Möglichkeiten, um Ihr System vor Überlastung zu schützen.

### asterisk.conf (Auszug)

Der Abschnitt `[directories]` definiert, wo Asterisk seine Konfiguration, Module, Daten, Spool-Dateien und Protokolle speichert:

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

Der Abschnitt `[options]` enthält Einstellungen zur Laufzeitoptimierung. Die nützlichsten Optionen, die man kennen sollte, sind unten aufgeführt (zum Aktivieren auskommentieren); die Datei wird mit vielen weiteren Optionen ausgeliefert, die jeweils durch einen Kommentar im Code dokumentiert sind:

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## Log-Dateien und Log-Rotation

Asterisk PBX protokolliert seine Meldungen in `/var/log/asterisk`. Die Protokollierung wird über `logger.conf` gesteuert. Der entscheidende Teil ist der Abschnitt `[logfiles]`, in dem jede Zeile einen Log-Kanal und die zu erfassenden Meldungsebenen definiert (Auszug):

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

Wenden Sie die Änderung nach dem Bearbeiten mit `logger reload` an und bestätigen Sie die Kanäle mit `logger show channels`:

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

Die Log-Dateien können schnell anwachsen, rotieren Sie diese daher mit dem System-Daemon `logrotate` — fügen Sie eine Datei unter `/etc/logrotate.d/` hinzu:

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

Weitere Informationen zu logrotate erhalten Sie mit:

```
#man logrotate
```

## Deinstallation von Asterisk

Um Asterisk zu deinstallieren, verwenden Sie:

```
make uninstall
```

Um Asterisk sowie alle Konfigurationsdateien zu deinstallieren, verwenden Sie:

```
make uninstall-all
```

## Asterisk Installationshinweise

Dieser Abschnitt enthält einige Ratschläge zu Themen, die vor der Installation von Asterisk beachtet werden sollten.

### Produktionssysteme

Wenn Asterisk in einer Produktionsumgebung installiert wird, sollten Sie auf das Systemdesign achten. Ein Server muss so optimiert sein, dass Telefonsysteme Vorrang vor anderen Systemprozessen haben. Asterisk sollte nicht zusammen mit prozessorintensiver Software wie X-Windows ausgeführt werden. Wenn Sie CPU-intensive Prozesse (z. B. eine große Datenbank) ausführen müssen, verwenden Sie einen separaten Server. Allgemein gesagt ist Asterisk anfällig für Schwankungen der Hardwareleistung. Versuchen Sie daher, Asterisk in einer Hardwareumgebung zu betreiben, die nicht mehr als 40% der CPU-Auslastung erfordert.

### Netzwerktipps

Wenn Sie planen, IP-Telefone zu verwenden, ist es wichtig, dass Sie auf Ihr Netzwerk achten. Sprachprotokolle sind sehr gut und resistent gegenüber Latenz und sogar Jitter; wenn Sie jedoch ein schlecht konfiguriertes lokales Netzwerk verwenden, wird die Sprachqualität leiden. Eine gute Sprachqualität lässt sich nur durch die Verwendung von Quality of Service (QoS) in Switches und Routern garantieren. Sprache in einem lokalen Netzwerk ist tendenziell gut, aber selbst in einer LAN-Umgebung werden Sie bei 10 Mbps Hubs mit zu vielen Kollisionen eine verzerrte oder schlechte Sprachqualität erhalten. Befolgen Sie diese Empfehlungen, um die bestmögliche Sprachqualität zu gewährleisten:

- Verwenden Sie nach Möglichkeit oder bei wirtschaftlicher Machbarkeit End-to-End QoS. Mit End-to-End QoS ist die Sprachqualität perfekt. Keine Ausreden!
- Vermeiden Sie die Verwendung von 10/100 Mbps Hubs für Sprache in einer Produktionsumgebung. Kollisionen können Jitter im Netzwerk verursachen. Vollduplex 10/100 Mbps sind zu bevorzugen, da keine Kollisionen auftreten.
- Verwenden Sie VLANs, um unnötige Broadcasts vom Sprachnetzwerk zu trennen. Sie möchten nicht, dass ein Virus Ihr Sprachnetzwerk mit ARP-Broadcasts zerstört.
- Klären Sie die Benutzer über die Erwartungen an ein Sprachnetzwerk auf. Ohne QoS sollten Sie nicht behaupten, dass die Sprache perfekt sein wird, da dies in den meisten Fällen nicht der Fall sein wird. Eine Sprachqualität ähnlich der eines Mobiltelefons wird meistens erreicht. Verwenden Sie hochwertige Telefone, da Probleme mit Firmware und Hardwaredesign häufig vorkommen.

## Zusammenfassung

In diesem Kapitel haben Sie die minimalen Hardwareanforderungen kennengelernt sowie erfahren, wie man Asterisk herunterlädt, installiert und kompiliert. Aus Sicherheitsgründen sollte Asterisk mit einem Nicht-Root-Benutzer ausgeführt werden. Sie sollten Ihre Netzwerkumgebung überprüfen, bevor Sie die Produktionsumgebung starten.

## Quiz

1. Welcher Channel-Treiber bietet in Asterisk 22 SIP-Unterstützung und was ist mit dem älteren `chan_sip` passiert?
   - A. `chan_sip` ist weiterhin der Standard; `chan_pjsip` ist optional.
   - B. `chan_pjsip` ist der Standard-SIP-Channel; `chan_sip` wurde in Asterisk 21 entfernt und existiert nicht mehr.
   - C. Beide werden standardmäßig erstellt und man wählt zur Laufzeit zwischen ihnen.
   - D. Die SIP-Unterstützung wurde zugunsten von IAX2 vollständig entfernt.
2. Telefonie-Schnittstellenkarten für Asterisk verfügen normalerweise über integrierte Digital Signal Processors (DSPs) und benötigen daher kaum CPU-Leistung des PCs.
   - A. Wahr
   - B. Falsch
3. Wenn Sie eine perfekte Sprachqualität wünschen, müssen Sie ein End-to-End Quality of Service (QoS) implementieren.
   - A. Wahr
   - B. Falsch
4. Sie sollten immer die neueste Asterisk-Version wählen, da diese am stabilsten ist.
   - A. Wahr
   - B. Falsch
5. Was ist die empfohlene Methode, um die Build-Abhängigkeiten für Asterisk 22 zu installieren?
6. Wenn Sie keine TDM-Schnittstellenkarte besitzen, verfügen Sie dennoch über eine interne Zeitquelle zur Synchronisation, die durch das `res_timing_timerfd` Modul unter Linux bereitgestellt wird. Dieses Timing wird von Anwendungen wie ________ und ________ verwendet.
7. Bei der Installation von Asterisk ist es besser, Desktop-Umgebungen wie GNOME oder KDE wegzulassen, da grafische Oberflächen CPU-Zyklen verbrauchen.
   - A. Wahr
   - B. Falsch
8. Asterisk-Konfigurationsdateien befinden sich im Verzeichnis ________.
9. Um die Asterisk-Beispielkonfigurationsdateien zu installieren, geben Sie den Befehl ein: ________
10. Warum ist es wichtig, Asterisk als Nicht-Root-Benutzer auszuführen?

**Antworten:** 1 — B · 2 — B · 3 — A · 4 — B · 5 — Führen Sie `./contrib/scripts/install_prereq install` aus dem entpackten Asterisk-Quellverzeichnis aus · 6 — ConfBridge und Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — Sicherheit (begrenzt den Schaden, falls Asterisk kompromittiert wird)
