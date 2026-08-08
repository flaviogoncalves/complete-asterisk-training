# Call Queues

Call Queues, auch bekannt als ACD (Automatic Call Distribution), werden immer wichtiger, um Kundenanrufe effizient zu beantworten. Ein automatischer Anrufverteiler kann dazu beitragen, Kosten zu senken, den Service zu verbessern und den Umsatz zu steigern, da Anrufverteiler die Arbeitsweise Ihres Unternehmens beeinflussen – nicht nur für ein paar Tage, sondern für viele Jahre. In einer Call-Center-Umgebung ist der wichtigste Faktor der Mensch; er ist die teuerste Ressource. Es kostet Zeit, Geld und Geduld, Agenten einzustellen, zu schulen und zu motivieren. Mit einer ACD können Sie die Produktivität der Agenten maximieren, indem Sie die Anzahl der benötigten Agenten präzise dimensionieren, gute und schlechte Mitarbeiter steuern und den Anruffluss analysieren.

## Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Zu verstehen, warum und wie man Warteschlangen verwendet
- Die grundlegende Theorie von Warteschlangen zu verstehen
- Das Warteschlangensystem zu installieren und zu konfigurieren

## Wie funktionieren Warteschlangen?

Warteschlangen sind keine wirkliche Neuheit. Wenn Sie ein hohes Aufkommen an eingehenden Anrufen haben, ist es schwierig, diese angemessen zu verteilen. Die Verwendung einer Gruppenstrategie, bei der die Telefone aller Agenten gleichzeitig klingeln, scheint nicht zu funktionieren, es sei denn, Sie haben nur wenige Agenten. Eine Warteschlange hingegen stellt Anrufe jeweils nur an einen einzigen verfügbaren Agenten zu und versetzt den Kunden in die Warteschleife mit Musik, wenn keine Agenten verfügbar sind. Die Warteschlange funktioniert, indem sie den Anruf hält, während sie einen freien Agenten findet, der den Anruf entgegennimmt. Einer der größten Vorteile der Warteschlange besteht darin, Anrufe nicht zu verlieren und gleichzeitig die Möglichkeit zu bieten, Statistiken zu erstellen.

![Eine Warteschlange: Eingehende 1-800-Anrufe gelangen in die Warteschlange und eine ACD-Strategie (ringall, rrmemory, leastrecent, priority und andere) verteilt sie an die verfügbaren Agenten](../images/14-queues-fig01.png)

Normalerweise funktioniert eine Warteschlange wie folgt:

- Agenten melden sich in der Warteschlange an.
- Eingehende Anrufe werden in die Warteschlange eingereiht.
- Eine Warteschlangenstrategie zur Verteilung der Anrufe wird verwendet, um Anrufe an Agenten weiterzuleiten.
- Während der Anrufer wartet, wird Musik in der Warteschleife abgespielt.
- Anrufern können Ansagen gemacht werden, die sie über die Wartezeit informieren.
- Der Anruf wird vom Agenten entgegengenommen und Statistiken werden generiert.

Der Haupteinsatzbereich für Warteschlangen ist der Kundenservice. Durch die Verwendung von Warteschlangen vermeiden Sie es, Anrufe zu verlieren, wenn Ihre Agenten beschäftigt sind. Sie können der Warteschlange neue Agenten hinzufügen, wenn Sie feststellen, dass die Anzahl der Anrufer in der Warteschlange wächst. Ein weiterer Vorteil von Warteschlangen ist, dass Sie nun Statistiken wie die Abbruchrate, die durchschnittliche Anrufdauer und das Anrufannahmeziel erhalten können. Diese Statistiken helfen Ihnen dabei zu bestimmen, wie viele Agenten Sie einsetzen müssen, um Ihren Kunden einen besseren Service zu bieten.

### ACD-Architektur

Die ACD-Architektur besteht aus Warteschlangen und Agenten. Ein Agent kann gleichzeitig in zwei Warteschlangen sein. Eine Warteschlange kann Agenten, Kanäle und Agentengruppen enthalten.

![ACD-Architektur: Jede Warteschlange (Kundenservice, Vertrieb) wird durch eine Telefonnummer gespeist und leitet Anrufe an Agenten weiter, die wiederum an physische Kanäle gebunden sind](../images/14-queues-fig02.png)

## Queues

Queues werden in der Konfigurationsdatei queues.conf definiert. Agents sind Mitarbeiter, die sich anmelden und Mitglieder von Queues sind. Agents werden in der Datei agents.conf definiert. Das Queue-System ist über viele Versionen hinweg erheblich gewachsen, was die Konfigurationsdatei umfangreich macht. Wir werden einige der wichtigsten Parameter erläutern. Ein allgemeiner Parameter, der hervorzuheben ist, ist `autofill`:

```
autofill=yes
```

Das alte Verhalten der Queue war vom Typ serial. Die Queue wartete darauf, dass ein Anruf zugestellt wurde, bevor der nachfolgende Anruf an den nächsten Agenten gesendet wurde. Wenn ein Agent 15 Sekunden brauchte, um einen Anruf anzunehmen, mussten die anderen Anrufe in der Queue warten, bis dieser Anruf beantwortet wurde. Für Queues mit hohem Anrufaufkommen war dieses Verhalten ineffizient. Das neue Verhalten autofill=yes wartet nicht, bis ein Anruf beantwortet wurde, sondern arbeitet parallel. Sie können die Anrufe in der Queue mit der Option mixmonitor aufzeichnen. In diesem Modus werden Anrufe gleichzeitig aufgezeichnet und gemischt.

### Queue-Konfigurationsdatei

Queues werden in der Datei queues.conf konfiguriert. In der Abbildung finden Sie ein funktionierendes Beispiel einer Queue.

![Ein funktionierendes Beispiel der Datei queues.conf, das den allgemeinen Abschnitt und eine customerservice-Queue mit Strategie, Service-Level, Ankündigungen, Aufzeichnung und Mitgliedern zeigt](../images/14-queues-fig03.png)

### Agents

Sie können Ihre Agents in der Datei agents.conf konfigurieren. Agents können sich von jeder extension aus anmelden, um Anrufe entgegenzunehmen. Sie können einen Agenten anrufen mit:

```
Dial(agent/<name>)
```

#### Agent-Anmeldung

Der Anmeldevorgang für Agent 300 funktioniert wie folgt:

- Der Benutzer wählt eine extension, die die Anwendung `AgentLogin()` ausführt.
- `AgentLogin()` wird ausgeführt und der Agent wird mit dem aktuellen Kanal verknüpft.
- Sie können den Status der Agents mit dem Befehl `agent show all` überprüfen.

![Agents: Ein Benutzer meldet sich an, indem er eine extension wählt, die die Anwendung agentlogin ausführt, welche Agent 300 an den aktuellen Kanal bindet; Sie können den Agent-Status mit `agent show all` überprüfen](../images/14-queues-fig04.png)

Sie können die Agents in der Datei agents.conf definieren

```
; Agent configuration
[general]
persistentagents=yes
[agents]
autologoff=15
autologoffunavail=yes
ackcall=no
endcall=yes
wrapuptime=5000
musiconhold => default
;
;This section contains the agent definitions, in the form:
;
; agent => agentid,agentpassword,name
;
agent => 300,300
agent => 301,301
```

### Mitglieder

Mitglieder sind aktive Kanäle, die auf die Queue reagieren. Mitglieder können direkte Kanäle (PJSIP, DAHDI) oder Agents sein, die sich anmelden, bevor sie Anrufe entgegennehmen.


### Strategien

Anrufe werden gemäß einer dieser Strategien unter den Mitgliedern verteilt:

- ringall: Lässt alle verfügbaren Kanäle klingeln, bis jemand abhebt.
- leastrecent: Verteilt an das Mitglied, das am längsten keinen Anruf erhalten hat.
- fewestcalls: Verteilt an das Mitglied mit den wenigsten Anrufen.
- random: Lässt eine zufällige Schnittstelle klingeln.
- wrandom: Lässt eine zufällige Schnittstelle klingeln, verwendet jedoch die Strafe (penalty) des Mitglieds als Gewichtung bei der Berechnung der Metrik.
- rrmemory: Verwendet Round Robin mit Speicher; es merkt sich, wo es beim letzten Durchgang mit dem Anruf aufgehört hat.
- rrordered: Dasselbe wie rrmemory, außer dass die Reihenfolge der Queue-Mitglieder aus der Konfigurationsdatei beibehalten wird.
- linear: Lässt Mitglieder in der Reihenfolge klingeln, in der sie in queues.conf aufgelistet sind; bei dynamischen Mitgliedern in der Reihenfolge, in der sie hinzugefügt wurden.

Die ältere Strategie `roundrobin` wurde bereits in Asterisk 1.4 als veraltet markiert. Sie ist keine dokumentierte Strategie mehr und sollte nicht verwendet werden: In Asterisk 22 akzeptiert der Parser zwar noch das Wort `roundrobin`, aber nur als Alias zur Abwärtskompatibilität, der auf `rrmemory` verweist. Verwenden Sie stattdessen explizit `rrmemory` (oder `rrordered`). Die obige Liste ist die Menge der dokumentierten Strategien für die Option `strategy` in der Asterisk 22 `queues.conf`.

## Agents

Agents werden als Proxy-Channels implementiert. Sie können innerhalb von Queues verwendet werden. Eine weitere Verwendung für Agent-Channels ist die Extension Mobility. Der Benutzer kann sich an einem beliebigen Telefon anmelden und seine Anrufe empfangen. Dies ermöglicht es einem Benutzer, in jeden beliebigen Raum zu gehen und diesen als Büro zu nutzen. Sie können einen Agenten im dialplan mit `dial(agent/<name>)` anrufen. Sie definieren Agenten in der Datei `agents.conf`.

![Agent Mobility: Der Benutzer nimmt ein beliebiges Telefon ab, wählt eine Login-Extension und gibt die Agentennummer sowie das Passwort ein; nachdem `agentlogin()` erfolgreich war, ist der Agent (Agent 300) bereit, Anrufe entgegenzunehmen, und Sie können den Status mit dem CLI-Befehl `agent show all` überprüfen](../images/14-queues-fig05.png)

### Agent Groups

Sie können sich für die Verwendung von Agent Groups entscheiden. Diese Funktion berücksichtigt keine ACD-Strategien. Sie werden es wahrscheinlich vorziehen, alle Agenten einzeln aufzulisten. Wenn Sie an eine Agent Group weiterleiten möchten, können Sie `queues.conf` verwenden:

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### Die Konfigurationsdatei für Agenten

Agenten werden in der Datei `agents.conf` definiert. Nachfolgend finden Sie ein funktionierendes Beispiel für die Datei.

![Ein funktionierendes Beispiel der Datei agents.conf: ein allgemeiner Abschnitt mit persistentagents, ein agents-Abschnitt mit den Standardparametern (autologoff, ackcall, endcall, wrapuptime, musiconhold) und zwei Agentendefinitionen (300 und 301)](../images/14-queues-fig06.png)

## ACD-bezogene Anwendungen

Das Asterisk-Warteschlangensystem stellt verschiedene Anwendungen zur Verfügung, um Warteschlangen im dialplan zu implementieren. Nachfolgend zeigen wir einige davon.

### Die Anwendung queue()

Diese Anwendung reiht eingehende Anrufe in eine bestimmte Warteschlange ein, wie sie in queues.conf definiert ist. Die Optionszeichenfolge kann null oder mehr einbuchstabige Optionen enthalten (in der Abbildung unten dargestellt). Zusätzlich zur Weiterleitung des Anrufs kann ein Anruf geparkt und anschließend von einem anderen Benutzer übernommen werden. Die optionale URL wird an den angerufenen Teilnehmer gesendet, sofern der Kanal dies unterstützt. Der optionale AGI-Parameter richtet ein AGI-Skript ein, das auf dem Kanal des anrufenden Teilnehmers ausgeführt wird, sobald dieser mit einem Warteschlangenmitglied verbunden ist. Der timeout bewirkt, dass die Warteschlange nach einer festgelegten Anzahl von Sekunden abbricht; dies wird zwischen jedem timeout- und retry-Zyklus überprüft. Diese Anwendung setzt nach Abschluss die Statusvariable QUEUE:

![Die Anwendung queue(): ihre Syntax `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — Asterisk 22 trennt die Argumente mit Kommas (die ältere Pipe-Form `|` ist entfallen) — und die verfügbaren einbuchstabigen Optionen (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### Die Anwendung agentlogin()

Diese Anwendung fordert den Agenten auf, sich am System anzumelden. Sie gibt immer -1 zurück. Während der Anmeldung hört der Agent, der Anrufe entgegennimmt, einen Signalton, wenn ein neuer Anruf eingeht. Der Agent kann den Anruf durch Drücken der *-Taste beenden.

![Die Anwendung agentlogin(): ihre Syntax `AgentLogin([AgentNo][|options])` und die Option `s` für eine stille Anmeldung, bei der die Anmeldebestätigung nicht angesagt wird](../images/14-queues-fig08.png)

### Die Anwendung addQueueMember()

Diese Anwendung fügt dynamisch ein Gerät (z. B. PJSIP/3000) zu einer Warteschlange hinzu. Wenn das Gerät bereits existiert, wird ein Fehler zurückgegeben.

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### Die Anwendung removeQueueMember()

Diese Anwendung entfernt dynamisch ein Gerät aus der Warteschlange. Wenn das Gerät nicht zur Warteschlange gehört, wird ein Fehler zurückgegeben.

```
RemoveQueueMember(queuename[|interface])
```

### Unterstützende Anwendungen und CLI-Befehle

Einige Anwendungen und Konsolenbefehle sind hilfreich bei der Arbeit mit Warteschlangen. Im Folgenden wird beschrieben, was die jeweilige Anwendung bewirkt:

![Unterstützende Anwendungen (AddQueueMember, RemoveQueueMember) und CLI-Befehle (agent show all, queue show, queue show <name>), die zur Verwaltung von Warteschlangen zur Laufzeit verwendet werden](../images/14-queues-fig09.png)

## Konfigurationsaufgaben

Die folgende Abbildung fasst die wichtigsten Aufgaben zur Erstellung eines funktionierenden Warteschlangensystems zusammen.

![Die ACD-Konfigurationsaufgaben: (1) Erstellen der Anrufwarteschlange (erforderlich), (2) Definieren der Agentenparameter (optional), (3) Erstellen von Agenten (optional), (4) Einfügen der Warteschlange in den dialplan (erforderlich), (5) Konfigurieren der Agentenaufzeichnung (optional) und (6) Überprüfung mit agent show all und queue show (optional)](../images/14-queues-fig10.png)

Schritt 1: Erstellen der Anrufwarteschlange in der Datei queues.conf:

```
[telemarketing]
music = default
;announce = queue-telemarketing
;context = qoutcon
timeout = 2
retry = 2
maxlen = 0
member => Agent/300
member => Agent/301
[auditing]
music = default
;announce = queue-auditing
;context = qoutcon
timeout = 15
retry = 5
maxlen = 0
member => Agent/600
member => Agent/601
```

Schritt 2: Definieren der Agentenparameter in der Datei agents.conf:

```
debian:/etc/asterisk# cat agents.conf
;
; Agent configuration
;
[agents]
; Define maxlogintries to allow agent to try max logins before
; failed.
; default to 3
maxlogintries=5
; Define autologoff times if appropriate.  This is how long
; the phone has to ring with no answer before the agent is
; automatically logged off (in seconds)
autologoff=15
; Define autologoffunavail to have agents automatically logged
; out when the extension that they are at returns a CHANUNAVAIL
; status when a call is attempted to be sent there.
; Default is "no".
;autologoffunavail=yes
; Define ackcall to require an acknowledgement by '#' when
; an agent logs in using agentcallbacklogin.  Default is "no".
;ackcall=no
; Define endcall to allow an agent to hangup a call by '*'.
; Default is "yes". Set this to "no" to ignore '*'.
;endcall=yes
; Define wrapuptime.  This is the minimum amount of time when
; after disconnecting before the caller can receive a new call
; note this is in milliseconds.
;wrapuptime=5000
; Define the default musiconhold for agents
; musiconhold => music_class
;musiconhold => default
;
; Define the default good bye sound file for agents
; default to vm-goodbye
;agentgoodbye => goodbye_file
; Define updatecdr. This is whether or not to change the source
; channel in the CDR record for this call to agent/agent_id so
; that we know which agent generates the call
;updatecdr=no
;
; Group memberships for agents (may change in mid-file)
;
;group=3
;group=1,2
;group=
```

Schritt 3: Erstellen der Agenten in der Datei agents.conf:

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

Schritt 4: Einfügen der Warteschlange in den dialplan, in der Datei `extensions.conf`:

```
; Telemarketing queue.
exten=>_0800XXXXXXX,1,Answer
exten=>_0800XXXXXXX,2,Set(CHANNEL(musicclass)=default)
exten=>_0800XXXXXXX,3,Set(TIMEOUT(digit)=5)
exten=>_0800XXXXXXX,4,Set(TIMEOUT(response)=10)
exten=>_0800XXXXXXX,5,Background(welcome)
exten=>_0800XXXXXXX,6,Queue(telemarketing)
; Transfer to the queue auditing
exten => 8000,1,Queue(auditing)
exten => 8000,2,Playback(demo-echotest); No auditor available
exten => 8000,3,Goto(8000,1) ; Verify auditor again
; Agent login for the telemarketing and auditing queues
exten => 9000,1,Wait(1)
exten => 9000,2,AgentLogin()
```

### Konfiguration der Warteschlangenaufzeichnung

Anrufe können mithilfe der MixMonitor-Anwendung von Asterisk aufgezeichnet werden. (Die eigenständige Monitor-Anwendung wurde in Asterisk 22 entfernt, und die Option `monitor-type` in queues.conf akzeptiert nun nur noch MixMonitor.) Die Aufzeichnung kann innerhalb der Warteschlangenanwendung aktiviert werden und beginnt, sobald der Anruf tatsächlich entgegengenommen wird. Es werden nur erfolgreiche Anrufe aufgezeichnet, und es finden keine Aufzeichnungen statt, während Anrufer MOH hören. Um die Überwachung zu aktivieren, geben Sie einfach monitor-format an. Diese Funktion ist ansonsten deaktiviert. Sie können den Dateinamen für die Aufzeichnung mithilfe von `Set(MONITOR_FILENAME=<filename>)` festlegen; andernfalls wird `MONITOR_FILENAME=${UNIQUEID}` verwendet.

In der Datei queues.conf:

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## Queue-Betrieb

Die folgenden Beispiele erläutern die Verwendung der Queue.

1. Agenten-Anmeldung. Beispiel: Ein Agent in der Telemarketing-Queue hebt den Hörer ab und wählt #9000. Der Agent hört eine Nachricht über eine ungültige Anmeldung und wird nach seinem Namen und Passwort gefragt. Die Auditing-Queue folgt dem gleichen Verfahren.
2. Queue. Sobald sich der Agent in der Queue befindet, hört er MOH, sofern definiert. Wenn ein Anruf in der Telemarketing-Queue eingeht, hört der Agent einen Signalton und wird mit diesem Anruf verbunden.
3. Anruf beenden. Wenn der Agent das Gespräch beendet, kann er:
   - ‘*’ drücken, um die Verbindung zu trennen und in der Queue zu bleiben.
   - Den Hörer auflegen und sich dadurch von der Queue abmelden.
   - #8000 drücken, um den Anruf für das Auditing weiterzuleiten.

## Erweiterte Ressourcen

Das Asterisk-Warteschlangensystem verfügt über einige erweiterte Funktionen, um bestimmte Kunden und Agenten zu priorisieren sowie ein Benutzermenü zu ermöglichen.

### Benutzermenü

Sie können ein Menü für einen Benutzer definieren, während dieser in der Warteschlange wartet, indem Sie einstellige extension verwenden. Um diese Option zu aktivieren, definieren Sie einen context in der Warteschlangenkonfiguration queues.conf.

### Penalty

Agenten können mit einer Penalty konfiguriert werden. Eine Warteschlange leitet die Anrufe zuerst an Benutzer mit niedrigeren Penalty-Werten weiter. Da wir zum Beispiel wissen, dass unsere Kunden Susan und ihre sanfte Stimme lieben, könnten wir ihr die Priorität 0 zuweisen. Alternativ wird der Agent namens Uber, der weniger Erfahrung hat, für den Kundenservice weniger bevorzugt; daher weisen wir diesem Agenten die Priorität 10 zu. In der Datei queues.conf:

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### Priorität

Warteschlangen arbeiten im FIFO-Modus (First In, First Out). Wenn Sie speziellen Kunden (Platin, Gold) Vorrang einräumen möchten, können Sie differenzierte Prioritäten einrichten. Für Platin- oder Gold-Kunden:

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

Blaue Kunden:

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## Die Anwendung agentcallbacklogin() wurde entfernt

Die Anwendung `agentcallbacklogin()` wurde von Digium in Asterisk 1.4 (Juli 2006) als veraltet markiert und ist in Asterisk 22 nicht mehr verfügbar. Der empfohlene Ansatz ist die Verwendung von `AddQueueMember()` mit einer PJSIP-Schnittstelle, um dynamisch Mitglieder im Callback-Stil zu einer Queue hinzuzufügen. Das Dokument `queues-with-callback-members.txt` war in älteren Asterisk `/doc` Verzeichnissen als Migrationshilfe enthalten.

Der alte `chan_agent` Kanaltreiber wurde ebenfalls entfernt; seine Funktionalität wurde als `app_agent_pool` Modul neu geschrieben, welches in Asterisk 22 `AgentLogin()`, `AgentRequest()` und die `AGENT()` dialplan Funktion bereitstellt (diese sind weiterhin vorhanden — `app_agent_pool.so` wird mit einem Standard-Build von 22 ausgeliefert). Für moderne Callcenter ist es jedoch das Standardmuster, Agentenkanäle komplett zu überspringen und das PJSIP-Gerät des Agenten direkt mit `AddQueueMember()`/`RemoveQueueMember()` zur Queue hinzuzufügen (statisch in `queues.conf` oder dynamisch über den dialplan oder AMI). Dies ist einfacher, lässt sich sauber in den PJSIP-Gerätestatus integrieren und ist der Ansatz, der in diesem Kapitel durchgehend verwendet wird.

## Warteschlangen-Statistiken

Alle Ereignisse von Warteschlangen werden in /var/log/asterisk/queue_log protokolliert. Das Format des Warteschlangen-Protokolls ist im Dokument queuelog.txt im Verzeichnis /doc der Asterisk-Dokumentation veröffentlicht. Nachfolgend sind einige der wichtigsten protokollierten Ereignisse aufgeführt.

- ABANDON(position|origposition|waittime)
- AGENTDUMP
- AGENTLOGIN(channel)
- AGENTLOGOFF(channel|logintime)
- ATTENDEDTRANSFER(destexten|destcontext|holdtime|calltime|origposition)
- BLINDTRANSFER(extension|context|holdtime|calltime|origposition)
- COMPLETEAGENT(holdtime|calltime|origposition)
- COMPLETECALLER(holdtime|calltime|origposition)
- CONFIGRELOAD
- CONNECT(holdtime|bridgedchanneluniqueid)
- ENTERQUEUE(url|callerid)
- EXITEMPTY(position|origposition|waittime)
- EXITWITHKEY(key|position)
- EXITWITHTIMEOUT(position|origposition|waittime)
- QUEUESTART
- RINGNOANSWER(ringtime)
- SYSCOMPAT

Sie können Ihr eigenes Dienstprogramm zur Verarbeitung dieser Ereignisse erstellen oder ein fertiges Statistikpaket verwenden:

- **QueueMetrics** (<https://www.queuemetrics.com/>) – ein kommerzielles, aktiv gepflegtes Paket, das `queue_log` analysiert und eines der vollständigsten Reporting-Tools für Asterisk-Callcenter bleibt.
- **Eigenentwicklung** – da das oben genannte `queue_log` Format stabil und gut dokumentiert ist, ist es unkompliziert, es mit einem kleinen Skript (Python usw.) zu parsen und die Ereignisse in eine Datenbank oder ein Dashboard einzuspeisen.

Für einen ereignisgesteuerten Ansatz, der über das Auslesen von `queue_log` hinausgeht, ermöglichen Ihnen die **Asterisk REST Interface (ARI)** und die **AMI** `QueueSummary`/`QueueStatus` Aktionen den Aufbau von Live-Warteschlangen-Dashboards und benutzerdefinierten Integrationen basierend auf dem Echtzeit-Status der Warteschlange, anstatt Protokolle im Nachhinein zu analysieren. ARI ist die moderne, unterstützte Integrationsschnittstelle für diese Art von Arbeit in Asterisk 22.

## Zusammenfassung

In diesem Kapitel haben Sie gelernt, wie man eine ACD verwendet, wie deren Architektur aufgebaut ist und wie man sie konfiguriert. Einige fortgeschrittene Funktionen wie Prioritäten und Penalties wurden ebenfalls vorgestellt.

## Quiz

1. Welche der folgenden Optionen sind gültige Strategien für die Anrufverteilung in `queues.conf` (wählen Sie alle zutreffenden aus)?
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. Sie können ein Gespräch zwischen einem Agenten und einem Kunden innerhalb der Warteschlange aufzeichnen, indem Sie die Option ___ in der Datei `queues.conf` festlegen.
3. Welche `strategy` lässt die Mitglieder in der exakten Reihenfolge klingeln, in der sie in `queues.conf` aufgelistet sind?
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. Welche Aktionen kann ein Agent im Telemarketing-Beispiel ausführen, nachdem er ein Gespräch beendet hat (wählen Sie alle zutreffenden aus)?
   - A. Drücken von `*`, um die Verbindung zu trennen und in der Warteschlange zu bleiben
   - B. Auflegen des Telefons und Trennen der Verbindung zur Warteschlange
   - C. Drücken von `#8000`, um den Anruf zur Überprüfung weiterzuleiten
   - D. Drücken von `#`, um sich sofort von allen Warteschlangen abzumelden
5. Welche zwei Aufgaben sind *erforderlich*, um eine funktionierende Warteschlange zu erhalten (wählen Sie alle zutreffenden aus)?
   - A. Erstellen der Warteschlange
   - B. Erstellen der Agenten
   - C. Konfigurieren der Agentenparameter
   - D. Konfigurieren der Aufzeichnung
   - E. Einbinden der Warteschlange in den dialplan
6. In einer Anrufwarteschlange können Sie dem Anrufer ein einstelliges Menü anbieten, das er während der Wartezeit wählen kann. Dies wird durch die Definition eines/einer ___ im Abschnitt `queues.conf` der Warteschlange aktiviert:
   - A. agent
   - B. menu
   - C. context
   - D. application
7. Die Support-Anwendungen `AddQueueMember()` und `RemoveQueueMember()` werden im ___ verwendet, um Mitglieder zur Laufzeit hinzuzufügen oder zu entfernen:
   - A. dial plan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. Da chan_sip in Asterisk 21 entfernt wurde, muss ein statisches Warteschlangenmitglied einen Kanal wie ___ anstelle von `SIP/1001` referenzieren.
9. Der Parameter `wrapuptime` ist die Mindestzeit, die vergehen muss, nachdem ein Agent ein Gespräch beendet hat, bevor die Warteschlange diesem Agenten einen neuen Anruf sendet.
   - A. Wahr
   - B. Falsch
10. Einem Anrufer kann eine höhere Position in derselben Warteschlange zugewiesen werden, indem die Kanalvariable `QUEUE_PRIO` vor dem Aufruf von `Queue()` gesetzt wird.
    - A. Wahr
    - B. Falsch

**Antworten:** 1 — A, C, D, E, F (roundrobin ist keine dokumentierte Strategie; in Asterisk 22 existiert sie nur noch als veralteter Alias für rrmemory) · 2 — `monitor-format` (die Aufzeichnung aus der Warteschlange wird durch Angabe von `monitor-format` aktiviert; in Asterisk 22 unterstützt `monitor-type` nur MixMonitor) · 3 — C (linear) · 4 — A, B, C (`*` trennt die Verbindung und bleibt in der Warteschlange; `#` ist keine Taste zur Abmeldung von allen Warteschlangen) · 5 — A, E · 6 — C (die Option `context`) · 7 — A (der dial plan) · 8 — `PJSIP/1001` (jede beliebige `PJSIP/` Schnittstelle) · 9 — Wahr · 10 — Wahr
