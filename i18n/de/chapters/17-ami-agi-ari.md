# Erweiterung von Asterisk mit AMI und AGI

In verschiedenen Situationen kann es notwendig sein, die Funktionen von Asterisk mithilfe externer Anwendungen zu erweitern. Es gibt viele verschiedene Möglichkeiten, wie dies geschehen kann. In diesem Kapitel behandeln wir zwei der klassischen Methoden zur Integration von Asterisk mit anderen Systemen: AMI – Asterisk Manager Interface und AGI – Asterisk Gateway Interface. Wir werden uns auch den Befehl asterisk –rx und die Anwendung system() ansehen. Die Wahl der Integrationsmethode für Asterisk hängt von der jeweiligen Anwendung ab. Für AGI ist die gebräuchlichste Anwendung ein IVR, das mit einer Datenbank verbunden ist. Für AMI sind Dialer die beliebteste App. Eine dritte, modernere Schnittstelle – ARI, das Asterisk REST Interface – wird separat im nächsten Kapitel behandelt.

## Ziele

Nach Abschluss dieses Kapitels sollte der Leser in der Lage sein:

- Zugriffsmöglichkeiten auf externe Programme zu beschreiben
- Den Befehl `asterisk -rx` zu verwenden, um einen Konsolenbefehl auszuführen
- Die Anwendung `system()` zu nutzen, um externe Programme im dialplan aufzurufen
- Zu erklären, was AMI ist und wie es funktioniert
- Die Datei `manager.conf` zu konfigurieren und AMI zu aktivieren
- Einen AMI-Befehl aus einem PHP-Programm heraus auszuführen
- Zu erklären, was der Asterisk manager proxy ist und wie er funktioniert
- Verschiedene AGI-Varianten (DeadAGI, AGI, EAGI, FastAGI) zu beschreiben
- Ein einfaches, mit PHP erstelltes AGI-Programm auszuführen

## Wichtige Methoden zur Erweiterung von Asterisk

Asterisk bietet verschiedene Möglichkeiten, um mit externen Programmen zu kommunizieren. In diesem Kapitel behandeln wir:

- Linux-Befehlszeile und Asterisk-Konsole
- System() Applikation
- AMI
- AGI

## Erweitern von Asterisk mit der Konsolen-CLI

Eine Anwendung kann Asterisk einfach über die Linux-Shell mit dem folgenden Befehl aufrufen.

```
asterisk -rx <command>
```

Beispiel:

```
asterisk -rx "stop now"
```

Sogar ein Befehl mit einer Ausgabe kann aufgerufen werden:

```
asterisk:~# asterisk -rx "pjsip show endpoints"
Endpoint:  <Endpoint/CID.....................................>  <State.....>  <Channels.>
    I/OAuth:  <AuthId/UserName..............................>
         Aor:  <Aor............................................>  <MaxContact>
       Contact:  <Aor/ContactUri..........................> <Hash....> <Status> <RTT(ms)..>
   Transport:  <TransportId........>  <Type>  <cos>  <tos>  <BindAddress..................>
    Identify:  <Identify/Endpoint.........................................................>
         Match:  <criteria.........................>
     Channel:  <ChannelId......................................>  <State.....>  <Time.....>
       Exten: <DialedExten...........>  CLCID: <ConnectedLineCID.......>
=========================================================================================

 Endpoint:  4000                                                 Not in use    0 of inf
```

## Erweitern von Asterisk mit der System() Anwendung

Die Anwendung system() ermöglicht es Asterisk, eine externe Anwendung aufzurufen.

```
asterisk*CLI> core show application System
  -= Info about application 'System' =-
[Synopsis]
Execute a system command
[Description]
  System(command): Executes a command  by  using  system(). If the command
fails, the console should report a fallthrough.
Result of execution is returned in the SYSTEMSTATUS channel variable:
   FAILURE      Could not execute the specified command
   SUCCESS      Specified command successfully executed
```

Beispiel: Diese Anwendung führt ein Screen-Pop mittels netbios WindowsPopup durch.

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## Was ist AMI?

AMI ermöglicht es einem Client-Programm, eine Verbindung zu einer Asterisk-Instanz herzustellen, um Befehle zu erteilen oder Ereignisse über eine TCP-Verbindung zu lesen. Systemintegratoren werden diese Ressourcen nützlich finden, um Kanalzustände zu verfolgen. AMI basiert auf einem einfachen Konzept eines Leitungsprotokolls, das key:value-Paare über TCP verwendet. Asterisk selbst ist nicht darauf ausgelegt, zu viele Verbindungen über diese Schnittstelle zu verarbeiten. Wenn Sie viele Verbindungen zu AMI haben, sollten Sie die Verwendung eines Asterisk manager proxy in Betracht ziehen.

### Welche Sprache soll für AMI verwendet werden?

Die Auswahl einer Programmiersprache kann heutzutage schwierig sein. Es gibt einfach zu viele Optionen – Java, PHP, Perl, C, C#, Python und einige andere. Es ist möglich, AMI mit jeder Sprache zu verwenden, die eine Socket- oder telnet-Schnittstelle unterstützt. Wir haben uns für dieses Buch aufgrund ihrer Popularität für PHP entschieden.

### Verhalten des AMI-Protokolls

- Bevor Sie Befehle an Asterisk senden, müssen Sie eine AMI-Sitzung aufbauen
- Die erste Zeile eines Pakets enthält den Schlüssel „Action“, wenn sie von einem Client gesendet wird
- Die erste Zeile eines Pakets enthält den Schlüssel „Response“ oder „Event“, wenn sie von Asterisk kommt
- Pakete können nach der Authentifizierung in jede Richtung übertragen werden

### Pakettypen

Der Typ des Pakets wird durch das Vorhandensein der folgenden Schlüssel bestimmt:

- Action: Ein Paket, das von einem mit AMI verbundenen Client gesendet wird und eine bestimmte Aktion anfordert. Es gibt eine begrenzte Anzahl von Aktionen, die Clients zur Verfügung stehen. Die geladenen Module bestimmen diese Aktionen. Ein Paket enthält den Aktionsnamen und seine Parameter.
- Response: Die Antwort, die von Asterisk auf die letzte vom Client gesendete Aktion gesendet wird.
- Event: Daten, die zu einem Ereignis gehören, das im Asterisk-Kern oder von einem Modul generiert wurde.

Wenn ein Client Pakete vom Typ Action sendet, wird ein Parameter namens ActionID eingefügt. Da die Reihenfolge, in der die Antworten von Asterisk gesendet werden, nicht vorhersehbar ist, wird ActionID verwendet, um Aktionen und Antworten zuzuordnen. Event-Pakete werden in zwei verschiedenen Kontexten verwendet. Erstens informieren Ereignisse den Client über Änderungen in Asterisk (z. B. neu erstellte Kanäle, getrennte Kanäle oder Agenten, die sich bei einer Warteschlange an- oder abmelden). Zweitens werden Ereignisse verwendet, um Antworten auf eine Client-Aktion zu übertragen.

## Konfiguration von Benutzern und Berechtigungen

Um auf AMI zuzugreifen, ist es erforderlich, eine TCP-Verbindung zu einem TCP-Port (üblicherweise 5038) herzustellen. Sie müssen die Datei /etc/asterisk/manager.conf konfigurieren, um ein Benutzerkonto und Berechtigungen zu erstellen. Es gibt eine begrenzte Anzahl an Berechtigungen: „read“, „write“ oder beides. Diese Berechtigungen werden definiert in der

```
manager.conf file.
[general]
enabled=yes
port=5038
bindaddr=127.0.0.1
[admin]
secret=senha
read=system,call,log,verbose,command,agent,user
write=system,call,log,verbose,command,agent,user
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.255
```

### Anmeldung am AMI

Um sich am AMI anzumelden und zu authentifizieren, müssen Sie ein Action-Paket vom Typ login mit einem Benutzernamen und einem in der manager.conf erstellten Konto senden.

```
Action:login
Username:admin
Secret:password
```

Beispiel: Anmeldung am AMI mit php

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

Wenn Sie keine Events empfangen müssen, können Sie „Events Off“ verwenden.

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### Action-Pakete

Wenn Sie ein Action-Paket an Asterisk senden, können Sie einige zusätzliche Schlüssel (z. B. die gewählte Nummer) angeben, indem Sie key:value-Paare nach der Action übergeben. Es ist auch möglich, Channel- und globale Variablen an den dialplan zu übergeben.

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### Action-Befehle

Sie können den CLI-Befehl manager show commands verwenden, um die verfügbaren Actions aufzulisten. In Asterisk 22 umfasst der Kernsatz an Befehlen (diese Liste ist repräsentativ; geladene Module fügen weitere hinzu):

```
Action Privilege Synopsis
  WaitEvent        <none>           Wait for an event to occur
  ModuleCheck      system,all       Check if module is loaded
  ModuleLoad       system,all       Module management
  CoreShowChannels system,reportin  List currently active channels
  Reload           system,config,a  Send a reload event
  CoreStatus       system,reportin  Show PBX core status variables
  CoreSettings     system,reportin  Show PBX core settings (version etc)
  VoicemailUsersL  call,reporting,  List All Voicemail User Information
  UserEvent        user,all         Send an arbitrary event
  SendText         call,all         Send text message to channel
  ListCommands     <none>           List available manager commands
  MailboxCount     call,reporting,  Check Mailbox Message Count
  MailboxStatus    call,reporting,  Check Mailbox
  AbsoluteTimeout  system,call,all  Set Absolute Timeout
  ExtensionState   call,reporting,  Check Extension Status
  Command          command,all      Execute Asterisk CLI Command
  Originate        originate,all    Originate Call
  Atxfer           call,all         Attended transfer
  Redirect         call,all         Redirect (transfer) a call
  ListCategories   config,all       List categories in configuration file
  CreateConfig     config,all       Creates an empty file in the configuration directory
  UpdateConfig     config,all       Update basic configuration
  GetConfigJSON    system,config,a  Retrieve configuration (JSON format)
  GetConfig        system,config,a  Retrieve configuration
  Getvar           call,reporting,  Gets a Channel Variable
  Setvar           call,all         Set Channel Variable
  Status           system,call,rep  Lists channel status
  Hangup           system,call,all  Hangup Channel
  Challenge        <none>           Generate Challenge for MD5 Auth
  Login            <none>           Login Manager
  Logoff           <none>           Logoff Manager
  Events           <none>           Control Event Flow
  Ping             <none>           Keepalive command
  DAHDIRestart     <none>           Fully Restart DAHDI channels (terminates calls)
  DAHDIShowChanne  <none>           Show status DAHDI channels
  DAHDIDNDoff      <none>           Toggle DAHDI channel Do Not Disturb status OFF
  DAHDIDNDon       <none>           Toggle DAHDI channel Do Not Disturb status ON
  DAHDIDialOffhoo  <none>           Dial over DAHDI channel while offhook
  DAHDIHangup      <none>           Hangup DAHDI Channel
  DAHDITransfer    <none>           Transfer DAHDI Channel
  IAXnetstats      system,reportin  Show IAX Netstats
  IAXpeerlist      system,reportin  List IAX Peers
  IAXpeers         system,reportin  List IAX Peers
  QueueRule        <none>           Queue Rules
  QueuePenalty     agent,all        Set the penalty for a queue member
  QueueLog         agent,all        Adds custom entry in queue_log
  QueuePause       agent,all        Makes a queue member temporarily unavailable
  QueueRemove      agent,all        Remove interface from queue.
  QueueAdd         agent,all        Add interface to queue.
  QueueSummary     <none>           Queue Summary
  QueueStatus      <none>           Queue Status
  Queues           <none>           Queues
  AgentLogoff      agent,all        Sets an agent as no longer logged in
  Agents           agent,all        Lists agents and their status
  PlayDTMF                        call,all         Play DTMF signal on a specific channel.
  PJSIPShowEndpoints              system,reportin  Lists PJSIP endpoints
  PJSIPShowEndpoint               system,reportin  Detail listing of an endpoint
  PJSIPQualify                    system,all       Qualify a chan_pjsip endpoint
  PJSIPShowRegistrationsOutbound  system,reportin  Lists outbound registrations
  PJSIPShowContacts               system,reportin  Lists PJSIP Contacts
```

```
  AGI              agi,all          Add an AGI command to execute by Async AGI
  MixMonitor       system,all       Record a call and mix the audio during recording
  StopMixMonitor   system,call,all  Stop recording a call through MixMonitor
  MixMonitorMute   system,call,all  Mute / unMute a Mixmonitor recording
  ShowDialPlan     config,reportin  List dialplan
  DBDelTree        system,all       Delete DB Tree
  DBDel            system,all       Delete DB Entry
  DBPut            system,all       Put DB Entry
  DBGet            system,reportin  Get DB Entry
  Bridge           call,all         Bridge two channels already in the PBX
  Park             call,all         Park a channel
  ParkedCalls      <none>           List parked calls
```

Wenn Sie spezifische Befehlsparameter benötigen, verwenden Sie manager show command <command>. Beispiel:

```
asterisk*CLI> manager show command Originate

  -= Info about Manager Command 'Originate' =-

[Synopsis]
Originate a call.

[Provided By]
builtin

[Since]
0.2.0

[Description]
Generates an outgoing call to a <Extension>/<Context>/<Priority> or
<Application>/<Data>

[Syntax]
Action: Originate
[ActionID:] <value>
Channel: <value>
[Exten:] <value>
[Context:] <value>
[Priority:] <value>
[Application:] <value>
[Data:] <value>
[Timeout:] <value>
[CallerID:] <value>
[Variable:] <value>
[Account:] <value>
[EarlyMedia:] <value>
[Async:] <value>
[Codecs:] <value>
[ChannelId:] <value>
[OtherChannelId:] <value>
[PreDialGoSub:] <value>

[Arguments]
Channel
    Channel name to call.
Exten
    Extension to use (requires 'Context' and 'Priority')
Context
    Context to use (requires 'Exten' and 'Priority')
Priority
    Priority to use (requires 'Exten' and 'Context')
Application
    Application to execute.
Data
    Data to use (requires 'Application').
Timeout
    How long to wait for call to be answered (in ms.).
CallerID
    Caller ID to be set on the outgoing channel.
Variable
    Channel variable to set, multiple Variable: headers are allowed.
Account
    Account code.
EarlyMedia
    Set to 'true' to force call bridge on early media.
Async
    Set to 'true' for fast origination.
Codecs
    Comma-separated list of codecs to use for this call.
ChannelId
    Channel UniqueId to be set on the channel.
OtherChannelId
    Channel UniqueId to be set on the second local channel.
PreDialGoSub
    Context,Extension,Priority to set options/headers needed before
    starting the outgoing extension.

[Privilege]
originate,all

[See Also]
OriginateResponse
```

### Event-Pakete

Events werden auf dem manager interface generiert, wann immer etwas in Asterisk passiert —
ein Channel wird erstellt oder ändert seinen Status, zwei Channels werden gebridged oder das Bridging wird aufgehoben, eine Registrierung ändert sich, ein queue member wird hinzugefügt, und so weiter. Jedes Event ist ein Block von
`Key: value` Zeilen, die mit einem `Event:` Header beginnen.

Der genaue Satz an Events hängt von den geladenen Modulen und der Asterisk-Version ab. Anstatt also eine Liste wiederzugeben, die schnell veraltet, fragen Sie den laufenden Server nach dem maßgeblichen Satz:

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

Zum Beispiel wird das Bridging von Anrufen durch die Events `BridgeCreate`, `BridgeEnter`,
`BridgeLeave` und `BridgeDestroy` gemeldet (`BridgeEnter` wird „ausgelöst, wenn ein Channel in eine bridge eintritt“). Die älteren Events `Link`/`Unlink` wurden in Asterisk 12 entfernt.

## Asterisk Gateway Interface

AGI ist eine Gateway-Schnittstelle zu Asterisk, ähnlich wie CGI, das von Webservern verwendet wird. Sie ermöglicht die Verwendung von Hochsprachen wie Perl, PHP und Python, um die Funktionalität von Asterisk zu erweitern. Die Hauptanwendung für CGIs ist die Erstellung von IVR. Es gibt vier Arten von AGI:

- Normales AGI, das ein Programm innerhalb der Asterisk-Umgebung aufruft.
- Fast AGI, das ein AGI auf einem anderen Server über TCP-Sockets aufruft.
- EAGI, das den Zugriff auf den Sound-Kanal und dessen Steuerung vom AGI aus ermöglicht.
- DeadAGI, das den Zugriff auf den Kanal auch nach einem hangup() ermöglicht. Wird normalerweise in der Extension ‚h‘ aufgerufen. Beachten Sie, dass in Asterisk 22 die Anwendung `DeadAGI` als veraltet markiert ist — die reguläre Anwendung `AGI` erkennt einen aufgelegten Kanal und führt das Skript automatisch im "dead"-Modus aus, daher sollten neue dialplans stattdessen einfach `AGI()` aufrufen.

Anwendungsformat:

```
asterisk*CLI> core show application AGI
  -= Info about Application 'AGI' =-
[Synopsis]
Executes an AGI compliant application.
[Description]
Executes an Asterisk Gateway Interface compliant program on a channel. AGI
allows Asterisk to launch external programs written in any language to control
a telephony channel, play audio, read DTMF digits, etc. by communicating with
the AGI protocol.
The following variants of AGI exist, and are chosen based on the value passed
to <command>:
    AGI - The classic variant of AGI, this will launch the script specified by
    <command> as a new process. Communication with the script occurs on 'stdin'
    and 'stdout'.
    FastAGI - Connect Asterisk to a FastAGI server using a TCP connection. The
    URI to the FastAGI server should be given in the form
    '[scheme]://host.domain[:port][/script/name]', where <scheme> is either
    'agi' or 'hagi'.
    AsyncAGI - Use AMI to control the channel in AGI. AsyncAGI should be invoked
    by passing 'agi:async' to the <command> parameter.
This application sets the channel variable ${AGISTATUS} on completion, one of:
SUCCESS, FAILURE, NOTFOUND, HANGUP.
[Syntax]
AGI(command[,arg1[,arg2[,...]]])
Use the CLI command 'agi show commands' to list available agi commands
```

Sie können die verfügbaren AGI-Befehle mit dem Befehl `agi show commands` anzeigen (die Ausgabe unten ist repräsentativ; Asterisk 22 fügt einige zusätzliche Befehle hinzu):

```
Dead                        Command   Description
   No                         answer   Answer channel
   No                 channel status   Returns status of the connected channel
  Yes                   database del   Removes database key/value
  Yes               database deltree   Removes database keytree/value
  Yes                   database get   Gets database value
  Yes                   database put   Adds/updates database value
  Yes                           exec   Executes a given Application
   No                       get data   Prompts for DTMF on a channel
  Yes              get full variable   Evaluates a channel expression
   No                     get option   Stream file, prompt for DTMF, with timeout
  Yes                   get variable   Gets a channel variable
   No                         hangup   Hangup the current channel
  Yes                           noop   Does nothing
   No                   receive char   Receives one character from channels supporting it
   No                   receive text   Receives text from channels supporting it
   No                    record file   Records to a given file
   No                      say alpha   Says a given character string
   No                     say digits   Says a given digit string
   No                     say number   Says a given number
   No                   say phonetic   Says a given character string with phonetics
   No                       say date   Says a given date
   No                       say time   Says a given time
   No                   say datetime   Says a given time as specfied by the format given
   No                     send image   Sends images to channels supporting it
   No                      send text   Sends text to channels supporting it
   No                 set autohangup   Autohangup channel in some time
   No                   set callerid   Sets callerid for the current channel
   No                    set context   Sets channel context
   No                  set extension   Changes channel extension
   No                      set music   Enable/Disable Music on hold generator
   No                   set priority   Set channel dialplan priority
  Yes                   set variable   Sets a channel variable
   No                    stream file   Sends audio file on channel
   No            control stream file   Sends audio file and allows the listener cont.the
stream
   No                       tdd mode   Toggles TDD mode (for the deaf)
  Yes                        verbose   Logs a message to the asterisk verbose log
   No                 wait for digit   Waits for a digit to be pressed
   No                  speech create   Creates a speech object
   No                     speech set   Sets a speech engine setting
  Yes                 speech destroy   Destroys a speech object
   No            speech load grammar   Loads a grammar
  Yes          speech unload grammar   Unloads a grammar
   No        speech activate grammar   Activates a grammar
   No      speech deactivate grammar   Deactivates a grammar
   No               speech recognize   Recognizes speech
   No                          gosub   Execute a dialplan subroutine
```

Verwenden Sie zum Debuggen agi debug.

### Verwendung von AGI

In diesem Beispiel verwenden wir php-cli, die Befehlszeilenversion von PHP. Installieren Sie php-cli, falls es noch nicht installiert ist. Befolgen Sie diese Schritte, um PHP-AGI-Skripte zu verwenden.

1. Alle AGI-Skripte befinden sich in `/var/lib/asterisk/agi-bin`
2. Ändern Sie die Berechtigungen, um die Ausführung zu ermöglichen.

```
chmod 755 *.php
```

3. Shell-Schnittstelle (PHP-spezifisch). Die ersten Zeilen des Skripts müssen wie folgt lauten:

```
#!/usr/bin/php -q
<?php
```

4. I/O-Kanäle öffnen:

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. Die Asterisk-Ausgabe verwalten. Asterisk sendet die Informationen jedes Mal, wenn AGI aufgerufen wird.

```
agi_request:testephp
agi_channel: Dahdi/1-1
agi_language: en
agi_type: Dahdi
agi_callerid:
agi_dnid:
agi_context: default
agi_extension: 4000
agi_priority: 1
```

Speichern Sie die gesendeten Informationen:

```
while (!feof($stdin)) {
  $temp = fgets($stdin);
  $temp = str_replace("\n","",$temp);
  $s = explode(":",$temp);
  $agi[$s[0]] = trim($s[1]);
  if (($temp == "") || ($temp == "\n")) {
    break;
  }
}
```

Das vorherige Skript erstellt ein Array namens $agi. Verfügbare Optionen sind:

- agi_request – AGI-Dateiname
- agi_channel – AGI-Ursprungskanal
- agi_language – Eingestellte Sprache
- agi_type – Kanaltyp (z. B. SIP, DAHDI)
- agi_uniqueid – Eindeutige Kennung
- agi_callerid – CallerID (z. B. Flavio <8590>)
- agi_context – Ursprungs-context
- agi_extension – Angerufene extensions
- agi_priority – Priorität
- agi_accountcode – Ursprungs-accountcode

Um eine Variable namens agi_extensions aufzurufen, verwenden Sie $agi[agi_extensions].

6. Kanal-AGI verwenden. An diesem Punkt können Sie beginnen, mit Asterisk zu kommunizieren. Verwenden Sie den Befehl fputs, um Befehle an AGI zu senden. Sie können auch den Befehl echo verwenden.

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

Hinweise zur Verwendung von Anführungszeichen:

- AGI-Befehlsoptionen sind nicht optional
- Einige Optionen müssen in Anführungszeichen gesetzt werden <escape digits>
- Einige Optionen sollten nicht in Anführungszeichen gesetzt werden <digit string>
- Einige Optionen können beide Formate verwenden
- Sie können einfache Anführungszeichen verwenden

Schritt 7 – Variablen übergeben Kanalvariablen können im AGI gesetzt werden, können aber nicht innerhalb des AGI verwendet werden. Das folgende Beispiel funktioniert innerhalb eines AGI nicht.

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

Das folgende Beispiel funktioniert:

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

Schritt 8: Asterisk-Antworten Das Folgende ist notwendig, um Antworten von Asterisk zu verifizieren:

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

Schritt 9: Die gesperrten (Zombie-)Prozesse beenden Wenn Ihr Skript aus irgendeinem Grund fehlschlägt, bleibt der Prozess hängen. Verwenden Sie den Befehl killproc, um ihn vor einem erneuten Test zu bereinigen.

```
 #!/usr/bin/php -q
 <?php
 ob_implicit_flush(true);
 set_time_limit(6);
 $in = fopen("php://stdin","r");
 $stdlog = fopen("/var/log/asterisk/agi.log", "w");
 // Enable debug (more verbose)
 $debug = false;
 // Functions definition
 function read() {
   global $in, $debug, $stdlog;
   $input = str_replace("\n", "", fgets($in, 4096));
   if ($debug) fputs($stdlog, "read: $input\n");
   return $input;
 }
 function errlog($line) {
   global $err;
   echo "VERBOSE \"$line\"\n";
 }
 function write($line) {
   global $debug, $stdlog;
   if ($debug) fputs($stdlog, "write: $line\n");
   echo $line."\n";
 }
 // Put agi headers in the array
 while ($env=read()) {
   $s = split(": ",$env);
   $agi[str_replace("agi_","",$s[0])] = trim($s[1]);
   if (($env == "") || ($env == "\n")) {
     break;
   }
 }
 // main program
 echo "VERBOSE \"Start here!\" 2\n";
 read();
 errlog("Call from ".$agi['channel']." - Phone ringing ");
 read();
 write("SAY DIGITS 22 X"); // X is the escape digit. since X is not DTMF, no ex
it is possible
 read();
 write("SAY NUMBER 2233 X"); // X is the escape digit. since X is not DTMF, no
exit is possible
 read();
 // clean up file handlers etc.
 fclose($in);
 fclose($stdlog);
 exit;
 ?>
```

### DeadAGI

DeadAGI wird verwendet, wenn Sie keinen aktiven Kanal haben. Normalerweise führen Sie das DeadAGI in der Extension ‚h‘ aus. In Asterisk 22 ist die Anwendung `DeadAGI` als veraltet markiert und kann in einer zukünftigen Version entfernt werden; die Standardanwendung `AGI` verarbeitet jetzt aufgelegte ("dead") Kanäle automatisch, daher sollten Sie in neuen dialplans `AGI()` bevorzugen.

### FASTAGI

Fast AGI implementiert AGI unter Verwendung eines TCP-Ports (standardmäßig 4573) als Input/Output-Kanal. Das FastAGI-Format ist (agi://). Zum Beispiel:

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

Wenn die TCP-Verbindung verloren geht oder getrennt wird, endet das AGI und die TCP-Verbindung wird geschlossen, gefolgt von einer Trennung des Anrufs. Diese Ressource ist nützlich, um die CPU-Last Ihres Asterisk-Servers zu verringern, indem Skripte auf einem externen Server ausgeführt werden. Weitere Details zu FastAGI finden Sie im Quellcode-Verzeichnis (siehe bitte die Datei „agi/fastagi-test“). Die Asterisk-Java-Bibliothek bietet eine FastAGI-Serverimplementierung für Java. Weitere Informationen finden Sie unter https://github.com/asterisk-java/asterisk-java

ARI, die moderne REST/WebSocket-Schnittstelle, erhält als Nächstes ein eigenes Kapitel.

## Ändern des Quellcodes

Asterisk wird in der Programmiersprache C entwickelt (nicht C++). Das Vermitteln von C-Programmierung würde den Rahmen dieses Dokuments sprengen. Falls Sie interessiert sind, finden Sie entsprechende Dokumentation unter https://docs.asterisk.org. Dort werden gute Tipps zum Anwenden und Erstellen von Patches für Asterisk sowie eine API-Dokumentation geboten, die größtenteils durch die Software Doxygen generiert wird. Für diejenigen, die mit der C-Programmierung vertraut sind, kann das Ändern des Quellcodes der Anwendungen die mächtigste (und gefährlichste) Methode sein, um Asterisk zu erweitern.

## Zusammenfassung

In diesem Kapitel haben Sie gelernt, wie externe Programme an die Asterisk PBX angebunden werden. Wir haben mit asterisk –rx begonnen, um Befehle von der Linux-Shell an die Asterisk-Konsole zu übergeben. Als Nächstes haben wir die Anwendung System() kennengelernt, die es ermöglicht, ein externes Programm aus dem dialplan heraus aufzurufen. AMI ist die Schnittstelle, die einer CTI-Schnittstelle, wie sie in traditionellen PBXs üblich ist, am nächsten kommt. Um eine Anwendung aus dem dialplan heraus aufzurufen, haben wir AGI verwendet, mit einem Ausblick auf seine verschiedenen Varianten: DeadAGI für beendete Kanäle, EAGI für die Handhabung des Audio-Streamings, Fast AGI für die Nutzung von TCP-Sockets als Ein-/Ausgabeschnittstelle und normales AGI für den Aufruf und die Verarbeitung von Skripten innerhalb desselben Asterisk-Systems. Das nächste Kapitel widmet sich ARI, der modernen REST/WebSocket-API, die externen Anwendungen die volle Kontrolle über Asterisk-Kanäle und -Bridges gibt.

## Quiz

1. Welche der folgenden Methoden ist KEINE Schnittstellenmethode für Asterisk?
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. AMI ermöglicht das Übertragen von Asterisk-Befehlen über TCP-Sockets, und diese Schnittstelle ist bei einer frischen Asterisk-Installation standardmäßig aktiviert.
   - A. Wahr
   - B. Falsch
3. AMI ist sehr sicher, da die Authentifizierung MD5-Challenge/Response verwendet.
   - A. Wahr
   - B. Falsch
4. FastAGI ermöglicht es dem dialplan, externe Skripte auf einer anderen Maschine über TCP-Sockets (normalerweise Port 4573) aufzurufen.
   - A. Wahr
   - B. Falsch
5. DeadAGI wird auf aktiven Kanälen verwendet. Es kann auf DAHDI-Kanälen verwendet werden, jedoch nicht auf SIP- oder IAX-Kanälen.
   - A. Wahr
   - B. Falsch
6. AGI unterstützt nur PHP als Skriptsprache.
   - A. Wahr
   - B. Falsch
7. Der Befehl ___ zeigt alle verfügbaren AGI-Befehle an.
8. Der Befehl ___ zeigt alle verfügbaren AMI-Befehle an.
9. Welchen Header muss der Client in einem AMI-Action-Paket einfügen, damit die asynchronen Antworten und Ereignisse, die von Asterisk zurückkommen, mit der Aktion korreliert werden können, die sie ausgelöst hat?
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. Welche Berechtigungsklasse in manager.conf für AMI muss ein Benutzer besitzen, um die Aktion `Originate` auszuführen und einen ausgehenden Anruf zu tätigen?
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**Antworten:** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
