# Estendere Asterisk con AMI e AGI

In diverse situazioni, potrebbe essere necessario estendere le funzionalità di Asterisk utilizzando applicazioni esterne. Esistono molti modi diversi in cui può essere esteso. In questo capitolo, tratteremo due dei modi classici per integrare Asterisk con altri sistemi: AMI – Asterisk Manager Interface e AGI – Asterisk Gateway Interface. Esamineremo anche il comando `asterisk –rx` e l'applicazione `system()`. La scelta del metodo di integrazione con Asterisk dipende dall'applicazione. Per AGI, l'applicazione più comune è l'IVR collegato a un database. Per AMI, i dialer sono l'applicazione più diffusa. Una terza interfaccia, più moderna — ARI, l'Asterisk REST Interface — viene trattata separatamente nel prossimo capitolo.

## Obiettivi

Al termine di questo capitolo, il lettore dovrebbe essere in grado di:

- Descrivere le opzioni di accesso a programmi esterni
- Utilizzare il comando asterisk –rx per eseguire un comando da console
- Utilizzare l'applicazione system() per richiamare programmi esterni nel dialplan
- Spiegare cos'è AMI e come funziona
- Configurare il file manager.conf e abilitare AMI
- Eseguire un comando AMI da un programma PHP
- Spiegare cos'è Asterisk manager proxy e come funziona
- Descrivere le diverse varianti di AGI (DeadAGI, AGI, EAGI, FastAGI)
- Eseguire un semplice programma AGI creato con PHP

## Principali modalità per estendere Asterisk

Asterisk dispone di diverse modalità per interfacciarsi con programmi esterni. In questo capitolo, tratteremo:

- Riga di comando Linux e Console Asterisk
- Applicazione System()
- AMI
- AGI

## Estendere Asterisk con la CLI della console

Un'applicazione può facilmente richiamare Asterisk dalla shell Linux utilizzando il seguente comando.

```
asterisk -rx <command>
```

Esempio:

```
asterisk -rx "stop now"
```

È possibile richiamare anche un comando con un output:

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

## Estendere Asterisk utilizzando l'applicazione System()

L'applicazione system() consente ad Asterisk di richiamare un'applicazione esterna.

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

Esempio: Questa applicazione esegue uno screen-pop utilizzando netbios WindowsPopup.

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## Che cos'è AMI?

AMI consente a un programma client di connettersi a un'istanza Asterisk e di inviare comandi o leggere eventi tramite una connessione TCP. Gli integratori di sistema troveranno queste risorse utili per tracciare gli stati dei canali. AMI si basa sul semplice concetto di un protocollo di linea che utilizza coppie key:value su TCP. Asterisk di per sé non è pronto a gestire troppe connessioni su questa interfaccia. Se si dispone di molte connessioni ad AMI, si consideri l'utilizzo di Asterisk manager proxy.

### Quale linguaggio utilizzare per AMI

Selezionare un linguaggio di programmazione può essere difficile di questi tempi. Ci sono semplicemente troppe opzioni: Java, PHP, Perl, C, C#, Python e molte altre. È possibile utilizzare AMI con qualsiasi linguaggio che supporti un'interfaccia socket o telnet. Abbiamo scelto PHP per questo libro a causa della sua popolarità.

### Comportamento del protocollo AMI

- Prima di inviare qualsiasi comando ad Asterisk, è necessario stabilire una sessione AMI
- La prima riga di un pacchetto avrà la chiave “Action” quando inviata da un client
- La prima riga di un pacchetto avrà la chiave “Response” o “Event” quando proviene da Asterisk
- I pacchetti possono essere trasmessi in qualsiasi direzione dopo l'autenticazione

### Tipi di pacchetto

Il tipo di pacchetto è determinato dall'esistenza delle seguenti chiavi:

- Action: Un pacchetto inviato da un client connesso ad AMI che richiede un'azione specifica. Esiste un insieme finito di azioni disponibili per i client. I moduli caricati determinano tali azioni. Un pacchetto contiene il nome dell'azione e i suoi parametri.
- Response: La risposta inviata da Asterisk all'ultima azione inviata dal client.
- Event: Dati appartenenti a un evento generato nel core di Asterisk o da un modulo.

Quando un client invia pacchetti di tipo Action, viene incluso un parametro denominato ActionID. Poiché l'ordine in cui le risposte vengono inviate da Asterisk non può essere previsto, ActionID viene utilizzato per correlare azioni e risposte. I pacchetti Event vengono utilizzati in due contesti differenti. Primo, gli eventi informano il client sui cambiamenti in Asterisk (ad esempio, canali appena creati, canali disconnessi o agenti che effettuano il login o il logout da una coda). Secondo, gli eventi vengono utilizzati per trasportare le risposte a un'azione del client.

## Configurazione di utenti e permessi

Per accedere ad AMI, è necessario stabilire una connessione TCP in ascolto su una porta TCP (solitamente 5038). Sarà necessario configurare il file /etc/asterisk/manager.conf per creare un account utente e i relativi permessi. Esiste un insieme finito di permessi: "read", "write", o entrambi. Questi permessi sono definiti nel

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

### Accesso ad AMI

Per effettuare il login e autenticarsi su AMI, sarà necessario inviare un pacchetto di azione di tipo login con un nome utente e un account creati nel manager.conf.

```
Action:login
Username:admin
Secret:password
```

Esempio: Accesso ad AMI utilizzando php

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

Se non hai bisogno di ricevere gli eventi, puoi utilizzare "Events Off".

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### Pacchetti di azione

Quando invii un pacchetto di azione ad Asterisk, puoi fornire alcune chiavi aggiuntive (ad esempio, il numero chiamato) passando coppie chiave:valore dopo l'azione. È anche possibile passare variabili di canale e globali al dialplan.

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### Comandi di azione

Puoi utilizzare l'istruzione CLI manager show commands per elencare le azioni disponibili. In Asterisk 22 l'insieme principale di comandi include (questo elenco è rappresentativo; i moduli caricati ne aggiungono altri):

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

Se hai bisogno di conoscere i parametri specifici di un comando, utilizza manager show command <command>. Esempio:

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

### Pacchetti di evento

Gli eventi vengono generati sull'interfaccia manager ogni volta che accade qualcosa in Asterisk — un canale viene creato o cambia stato, due canali vengono messi in bridge o separati, una registrazione cambia, un membro di una coda viene aggiunto, e così via. Ogni evento è un blocco di
`Key: value` righe che inizia con un'intestazione `Event:`.

L'insieme esatto di eventi dipende dai moduli caricati e dalla versione di Asterisk, quindi, invece di riprodurre un elenco che diventa rapidamente obsoleto, interroga il server in esecuzione per ottenere l'insieme autorevole:

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

Ad esempio, il bridging delle chiamate viene segnalato attraverso gli eventi `BridgeCreate`, `BridgeEnter`,
`BridgeLeave` e `BridgeDestroy` (`BridgeEnter` viene "Generato quando un canale entra in un bridge"). I vecchi eventi `Link`/`Unlink` sono stati rimossi in Asterisk 12.

## Asterisk Gateway Interface

AGI è un'interfaccia gateway per Asterisk simile alla CGI utilizzata dai server web. Consente l'uso di linguaggi di alto livello come Perl, PHP e Python per estendere le funzionalità di Asterisk. L'applicazione principale per le CGI è la creazione di IVR. Esistono quattro tipi di AGI:

- AGI normale, che richiama un programma all'interno del box di Asterisk.
- Fast AGI, che richiama un AGI in un altro server utilizzando socket TCP.
- EAGI, che abilita l'accesso e il controllo del canale audio dall'AGI.
- DeadAGI, che fornisce accesso al canale anche dopo hangup(). Solitamente richiamato nell'extension ‘h’. Si noti che in Asterisk 22 l'applicazione `DeadAGI` è deprecata: la normale applicazione `AGI` rileva un canale terminato ed esegue lo script in modalità "dead" automaticamente, quindi i nuovi dialplan dovrebbero semplicemente richiamare `AGI()`.

Formato dell'applicazione:

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

È possibile visualizzare i comandi AGI disponibili utilizzando il comando `agi show commands` (l'output sottostante è rappresentativo; Asterisk 22 aggiunge alcuni comandi aggiuntivi):

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

Per il debug, utilizzare agi debug.

### Utilizzo di AGI

In questo esempio, utilizzeremo php-cli, la versione a riga di comando di php. Installare php-cli se non è già installato. Seguire questi passaggi per utilizzare gli script AGI in php.

1. Tutti gli script AGI si trovano in `/var/lib/asterisk/agi-bin`
2. Modificare i permessi per consentire l'esecuzione.

```
chmod 755 *.php
```

3. Interfaccia shell (specifica per php). Le prime righe dello script devono essere:

```
#!/usr/bin/php -q
<?php
```

4. Aprire i canali I/O:

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. Gestire l'output di Asterisk. Asterisk invia le informazioni impostate ogni volta che viene richiamato l'AGI.

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

Salvare le informazioni inviate:

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

Lo script precedente creerà un array chiamato $agi. Le opzioni disponibili sono:

- agi_request – Nome del file AGI
- agi_channel – Canale di origine dell'AGI
- agi_language – Lingua impostata
- agi_type – Tipo di canale (es. SIP, DAHDI)
- agi_uniqueid – Identificativo univoco
- agi_callerid – CallerID (Es. Flavio <8590>)
- agi_context – Context di origine
- agi_extension – Extension chiamata
- agi_priority – Priorità
- agi_accountcode – Account code di origine

Per richiamare una variabile chiamata agi_extensions, utilizzare $agi[agi_extensions].

6. Utilizzare l'AGI del canale. A questo punto, è possibile iniziare a comunicare con Asterisk. Utilizzare il comando fputs per inviare comandi all'AGI. È anche possibile utilizzare il comando echo.

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

Note sull'uso delle virgolette:

- Le opzioni dei comandi AGI non sono facoltative
- Alcune opzioni devono essere racchiuse tra virgolette <escape digits>
- Alcune opzioni non devono essere racchiuse tra virgolette <digit string>
- Alcune opzioni possono utilizzare entrambi i formati
- È possibile utilizzare virgolette singole

Passaggio 7 – Passare variabili Le variabili di canale possono essere impostate nell'AGI, ma non possono essere utilizzate all'interno dell'AGI. Il seguente esempio non funziona all'interno di un AGI.

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

Il seguente esempio funziona:

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

Passaggio 8: Risposte di Asterisk Quanto segue è necessario per verificare le risposte da Asterisk:

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

Passaggio 9: Terminare i processi bloccati (zombie) Se lo script fallisce per qualche motivo, il processo rimarrà in sospeso. Utilizzare il comando killproc per pulirlo prima di testare nuovamente.

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

DeadAGI viene utilizzato quando non si dispone di un canale attivo. Solitamente si esegue il DeadAGI nell'extension ´h´. In Asterisk 22 l'applicazione `DeadAGI` è deprecata e potrebbe essere rimossa in una versione futura; l'applicazione standard `AGI` ora gestisce automaticamente i canali terminati ("dead"), quindi preferire `AGI()` nei nuovi dialplan.

### FASTAGI

Fast AGI implementa AGI utilizzando una porta TCP (4573 per impostazione predefinita) come canale di Input/Output. Il formato FastAGI è (agi://). Ad esempio:

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

Quando la connessione TCP viene persa o disconnessa, l'AGI termina e la connessione TCP viene chiusa, seguita dalla disconnessione della chiamata. Questa risorsa è utile per alleggerire il carico della CPU dal server Asterisk eseguendo script su un server esterno. È possibile ottenere maggiori dettagli su FastAGI nella directory del codice sorgente (consultare il file “agi/fastagi-test”). La libreria Asterisk-Java fornisce un'implementazione di server FastAGI per Java. Per ulteriori informazioni, consultare https://github.com/asterisk-java/asterisk-java

ARI, la moderna interfaccia REST/WebSocket, avrà un capitolo dedicato a seguire.

## Modifica del codice sorgente

Asterisk è sviluppato in linguaggio C (non C++). Insegnare la programmazione in C esula dagli scopi di questo documento. Se sei interessato, troverai la documentazione correlata su https://docs.asterisk.org, che offre ottimi suggerimenti su come applicare e creare patch per Asterisk, oltre alla documentazione delle API generata principalmente dal software Doxygen. Per coloro che hanno familiarità con la programmazione in C, modificare il codice sorgente delle applicazioni può essere il modo più potente (e pericoloso) per estendere Asterisk.

## Riepilogo

In questo capitolo, hai imparato come interfacciare programmi esterni al PBX Asterisk. Abbiamo iniziato con asterisk –rx per passare comandi dalla shell Linux alla console di Asterisk. Successivamente, abbiamo appreso dell'applicazione System(), che consente di richiamare un programma esterno dal dialplan. AMI è l'interfaccia più vicina a un'interfaccia CTI comune nei PBX tradizionali. Per richiamare un'applicazione dal dialplan, abbiamo utilizzato AGI, con un assaggio delle sue diverse varianti: DeadAGI per i canali terminati, EAGI per la gestione dello streaming audio, Fast AGI per l'utilizzo di socket TCP come interfaccia di input/output e AGI normale per richiamare ed elaborare gli script all'interno della stessa macchina Asterisk. Il capitolo successivo è dedicato ad ARI, la moderna API REST/WebSocket che offre alle applicazioni esterne il controllo completo dei canali e dei bridge di Asterisk.

## Quiz

1. Quale dei seguenti NON è un metodo di interfaccia per Asterisk?
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. AMI consente di inviare comandi Asterisk tramite socket TCP, e questa interfaccia è abilitata per impostazione predefinita in un'installazione pulita di Asterisk.
   - A. Vero
   - B. Falso
3. AMI è molto sicuro, poiché la sua autenticazione utilizza challenge/response MD5.
   - A. Vero
   - B. Falso
4. FastAGI consente al dialplan di richiamare script esterni su un'altra macchina tramite socket TCP (solitamente sulla porta 4573).
   - A. Vero
   - B. Falso
5. DeadAGI viene utilizzato su canali attivi. Può essere utilizzato su canali DAHDI ma non su canali SIP o IAX.
   - A. Vero
   - B. Falso
6. AGI supporta solo PHP come linguaggio di scripting.
   - A. Vero
   - B. Falso
7. Il comando ___ mostra tutti i comandi AGI disponibili.
8. Il comando ___ mostra tutti i comandi AMI disponibili.
9. In un pacchetto di azione AMI, quale header deve includere il client affinché le risposte asincrone e gli eventi provenienti da Asterisk possano essere correlati all'azione che li ha generati?
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. Quale classe di autorizzazione di manager.conf in AMI deve possedere un utente per poter eseguire l'azione `Originate` ed effettuare una chiamata in uscita?
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**Risposte:** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
