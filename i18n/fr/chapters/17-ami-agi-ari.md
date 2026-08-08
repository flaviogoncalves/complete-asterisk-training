# Étendre Asterisk avec AMI et AGI

Dans plusieurs situations, il peut s'avérer nécessaire d'étendre les fonctionnalités d'Asterisk à l'aide d'applications externes. Il existe de nombreuses façons de l'étendre. Dans ce chapitre, nous aborderons deux des méthodes classiques pour intégrer Asterisk avec d'autres systèmes : AMI – Asterisk Manager Interface et AGI – Asterisk Gateway Interface. Nous examinerons également la commande asterisk –rx et l'application system(). Le choix de la méthode d'intégration avec Asterisk dépend de l'application. Pour AGI, l'application la plus courante est l'IVR connecté à une base de données. Pour AMI, les composeurs automatiques sont l'application la plus populaire. Une troisième interface, plus moderne — ARI, l'Asterisk REST Interface — est traitée séparément dans le chapitre suivant.

## Objectifs

À la fin de ce chapitre, le lecteur devrait être capable de :

- Décrire les options d'accès aux programmes externes
- Utiliser la commande asterisk –rx pour exécuter une commande de console
- Utiliser l'application system() pour appeler des programmes externes dans le dialplan
- Expliquer ce qu'est AMI et comment il fonctionne
- Configurer le fichier manager.conf et activer AMI
- Exécuter une commande AMI depuis un programme PHP
- Expliquer ce qu'est le proxy Asterisk manager et comment il fonctionne
- Décrire les différentes variantes d'AGI (DeadAGI, AGI, EAGI, FastAGI)
- Exécuter un programme AGI simple créé avec PHP

## Principales méthodes pour étendre Asterisk

Asterisk dispose de différentes manières de s'interfacer avec des programmes externes. Dans ce chapitre, nous aborderons :

- La ligne de commande Linux et la console Asterisk
- L'application System()
- AMI
- AGI

## Étendre Asterisk avec la CLI de la console

Une application peut facilement appeler Asterisk depuis le shell Linux en utilisant la commande suivante.

```
asterisk -rx <command>
```

Exemple :

```
asterisk -rx "stop now"
```

Même une commande avec une sortie peut être appelée :

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

## Extension d'Asterisk à l'aide de l'application System()

L'application System() permet à Asterisk d'appeler une application externe.

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

Exemple : Cette application effectue un affichage contextuel (screen-pop) en utilisant netbios WindowsPopup.

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## Qu'est-ce que l'AMI ?

L'AMI permet à un programme client de se connecter à une instance Asterisk et d'émettre des commandes ou de lire des événements via une connexion TCP. Les intégrateurs système trouveront ces ressources utiles pour suivre les états des canaux. L'AMI repose sur un concept simple de protocole de ligne utilisant des paires clé:valeur sur TCP. Asterisk seul n'est pas conçu pour gérer un trop grand nombre de connexions sur cette interface. Si vous avez de nombreuses connexions vers l'AMI, envisagez d'utiliser un proxy Asterisk manager.

### Quel langage utiliser pour l'AMI

Choisir un langage de programmation peut être difficile de nos jours. Il existe tout simplement trop d'options — Java, PHP, Perl, C, C#, Python, et plusieurs autres. Il est possible d'utiliser l'AMI avec n'importe quel langage prenant en charge une interface socket ou telnet. Nous avons choisi PHP pour ce livre en raison de sa popularité.

### Comportement du protocole AMI

- Avant d'envoyer des commandes à Asterisk, vous devez établir une session AMI
- La première ligne d'un paquet contiendra la clé « Action » lorsqu'elle est envoyée depuis un client
- La première ligne d'un paquet contiendra la clé « Response » ou « Event » lorsqu'elle provient d'Asterisk
- Les paquets peuvent être transmis dans n'importe quelle direction après l'authentification

### Types de paquets

Le type de paquet est déterminé par la présence des clés suivantes :

- Action : Un paquet envoyé depuis un client connecté à l'AMI demandant une action spécifique. Il existe un ensemble fini d'actions disponibles pour les clients. Les modules chargés déterminent ces actions. Un paquet contient le nom de l'action et ses paramètres.
- Response : La réponse envoyée par Asterisk à la dernière action envoyée par le client.
- Event : Données appartenant à un événement généré dans le cœur d'Asterisk ou par un module.

Lorsqu'un client envoie des paquets de type Action, un paramètre nommé ActionID est inclus. Étant donné que l'ordre dans lequel les réponses sont envoyées par Asterisk ne peut pas être prédit, ActionID est utilisé pour corréler les actions et les réponses. Les paquets Event sont utilisés dans deux contextes différents. Premièrement, les événements informent le client des changements dans Asterisk (par exemple, nouveaux canaux créés, canaux déconnectés, ou agents se connectant et se déconnectant d'une file d'attente). Deuxièmement, les événements sont utilisés pour transporter les réponses à une action du client.

## Configuration des utilisateurs et des permissions

Pour accéder à AMI, il est nécessaire d'établir une connexion TCP en écoute sur un port TCP (généralement 5038). Vous devrez configurer le fichier /etc/asterisk/manager.conf pour créer un compte utilisateur et définir des permissions. Il existe un ensemble fini de permissions : « read », « write », ou les deux. Ces permissions sont définies dans le

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

### Connexion à l'AMI

Pour vous connecter et vous authentifier sur AMI, vous devrez envoyer un paquet d'action de type login avec un nom d'utilisateur et un compte créés dans le fichier manager.conf.

```
Action:login
Username:admin
Secret:password
```

Exemple : Connexion à AMI en utilisant php

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

Si vous n'avez pas besoin de recevoir les événements, vous pouvez utiliser « Events Off ».

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### Paquets d'action

Lorsque vous envoyez un paquet d'action à Asterisk, vous pouvez fournir des clés supplémentaires (par exemple, le numéro appelé) en passant des paires clé:valeur après l'action. Il est également possible de transmettre des variables de canal et des variables globales au dialplan.

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### Commandes d'action

Vous pouvez utiliser l'instruction CLI manager show commands pour lister les actions disponibles. Dans Asterisk 22, l'ensemble principal des commandes inclut (cette liste est représentative ; les modules chargés en ajoutent davantage) :

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

Si vous avez besoin de connaître les paramètres spécifiques d'une commande, utilisez manager show command <command>. Exemple :

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

### Paquets d'événement

Les événements sont générés sur l'interface manager chaque fois qu'un événement survient dans Asterisk — un canal est créé ou change d'état, deux canaux sont pontés ou dépontés, un enregistrement change, un membre de file d'attente est ajouté, et ainsi de suite. Chaque événement est un bloc de
`Key: value` lignes commençant par un en-tête `Event:`.

L'ensemble exact des événements dépend des modules chargés et de la version d'Asterisk, donc plutôt que de reproduire une liste qui devient rapidement obsolète, interrogez le serveur en cours d'exécution pour obtenir l'ensemble faisant autorité :

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

Par exemple, le pontage d'appel est rapporté via les événements `BridgeCreate`, `BridgeEnter`,
`BridgeLeave` et `BridgeDestroy` (`BridgeEnter` est « Raised when a channel enters a
bridge »). Les anciens événements `Link`/`Unlink` ont été supprimés dans Asterisk 12.

## Asterisk Gateway Interface

AGI est une interface de passerelle vers Asterisk similaire au CGI utilisé par les serveurs web. Elle permet l'utilisation de langages de haut niveau comme Perl, PHP et Python pour étendre les fonctionnalités d'Asterisk. L'application principale des CGI est la création d'IVR. Il existe quatre types d'AGI :

- AGI normal, qui appelle un programme à l'intérieur de la machine Asterisk.
- Fast AGI, qui appelle un AGI sur un autre serveur en utilisant des sockets TCP.
- EAGI, qui permet l'accès et le contrôle du canal audio depuis l'AGI.
- DeadAGI, qui donne accès au canal même après un hangup(). Généralement appelé dans l'extension ‘h’. Notez qu'avec Asterisk 22, l'application `DeadAGI` est obsolète — l'application régulière `AGI` détecte un canal raccroché et exécute le script en mode "dead" automatiquement, donc les nouveaux dialplan devraient simplement appeler `AGI()` à la place.

Format de l'application :

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

Vous pouvez afficher les commandes AGI disponibles en utilisant la commande `agi show commands` (la sortie ci-dessous est représentative ; Asterisk 22 ajoute quelques commandes supplémentaires) :

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

Pour le débogage, utilisez agi debug.

### Utilisation d'AGI

Dans cet exemple, nous utiliserons php-cli, la version en ligne de commande de php. Installez php-cli s'il n'est pas déjà installé. Suivez ces étapes pour utiliser des scripts AGI en php.

1. Tous les scripts AGI sont situés dans `/var/lib/asterisk/agi-bin`
2. Modifiez les permissions pour autoriser l'exécution.

```
chmod 755 *.php
```

3. Interface shell (spécifique à php). Les premières lignes du script doivent être :

```
#!/usr/bin/php -q
<?php
```

4. Ouvrir les canaux d'E/S :

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. Gérer la sortie d'Asterisk. Asterisk envoie les informations définies à chaque fois que l'AGI est appelé.

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

Enregistrez les informations envoyées :

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

Le script précédent créera un tableau nommé $agi. Les options disponibles sont :

- agi_request – Nom du fichier AGI
- agi_channel – Canal d'origine de l'AGI
- agi_language – Langue définie
- agi_type – Type de canal (ex. SIP, DAHDI)
- agi_uniqueid – Identifiant unique
- agi_callerid – CallerID (Ex. Flavio <8590>)
- agi_context – Contexte d'origine
- agi_extension – Extensions appelées
- agi_priority – Priorité
- agi_accountcode – Code de compte d'origine

Pour appeler une variable nommée agi_extensions, utilisez $agi[agi_extensions].

6. Utiliser le canal AGI. À ce stade, vous pouvez commencer à communiquer avec Asterisk. Utilisez la commande fputs pour envoyer des commandes à l'AGI. Vous pouvez également utiliser la commande echo.

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

Notes sur l'utilisation des guillemets :

- Les options de commande AGI ne sont pas facultatives
- Certaines options doivent être entourées de guillemets <escape digits>
- Certaines options ne doivent pas être entourées de guillemets <digit string>
- Certaines options peuvent utiliser les deux formats
- Vous pouvez utiliser des guillemets simples

Étape 7 – Passer des variables Les variables de canal peuvent être définies dans l'AGI, mais ne peuvent pas être utilisées à l'intérieur de l'AGI. L'exemple suivant ne fonctionne pas à l'intérieur d'un AGI.

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

L'exemple suivant fonctionne :

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

Étape 8 : Réponses d'Asterisk Ce qui suit est nécessaire pour vérifier les réponses d'Asterisk :

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

Étape 9 : Tuer les processus verrouillés (zombies) Si votre script échoue pour une raison quelconque, le processus restera bloqué. Utilisez la commande killproc pour le nettoyer avant de tester à nouveau.

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

DeadAGI est utilisé lorsque vous n'avez pas de canal actif. Habituellement, vous exécutez le DeadAGI dans l'extension ´h´. Avec Asterisk 22, l'application `DeadAGI` est obsolète et pourrait être supprimée dans une future version ; l'application standard `AGI` gère désormais automatiquement les canaux raccrochés ("dead"), donc préférez `AGI()` dans les nouveaux dialplan.

### FASTAGI

Fast AGI implémente AGI en utilisant un port TCP (4573 par défaut) comme canal d'entrée/sortie. Le format FastAGI est (agi://). Par exemple :

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

Lorsque la connexion TCP est perdue ou déconnectée, l'AGI se termine et la connexion TCP est fermée, suivie d'une déconnexion de l'appel. Cette ressource est utile pour alléger la charge CPU de votre serveur Asterisk en exécutant des scripts sur un serveur externe. Vous pouvez obtenir plus de détails sur FastAGI dans le répertoire du code source (veuillez consulter le fichier “agi/fastagi-test”). La bibliothèque Asterisk-Java fournit une implémentation de serveur FastAGI pour Java. Pour plus d'informations, consultez https://github.com/asterisk-java/asterisk-java

ARI, l'interface moderne REST/WebSocket, aura son propre chapitre ensuite.

## Modification du code source

Asterisk est développé en langage C (et non C++). L'enseignement de la programmation en C dépasse le cadre de ce document. Si cela vous intéresse, vous trouverez une documentation associée sur https://docs.asterisk.org, qui propose de bons conseils sur la manière d'appliquer et de créer des correctifs pour Asterisk, ainsi qu'une documentation API principalement générée par le logiciel Doxygen. Pour ceux qui maîtrisent la programmation en C, modifier le code source des applications peut être le moyen le plus puissant (et le plus dangereux) d'étendre Asterisk.

## Résumé

Dans ce chapitre, vous avez appris comment interfacer des programmes externes avec le PBX Asterisk. Nous avons commencé par `asterisk -rx` pour transmettre des commandes depuis le shell Linux vers la console Asterisk. Ensuite, nous avons étudié l'application `System()`, qui permet d'appeler un programme externe depuis le dialplan. AMI est l'interface la plus proche d'une interface CTI courante dans les PBX traditionnels. Pour appeler une application depuis le dialplan, nous avons utilisé AGI, avec un aperçu de ses différentes variantes : DeadAGI pour les canaux morts, EAGI pour la gestion du flux audio, Fast AGI pour l'utilisation de sockets TCP comme interface d'entrée/sortie, et AGI standard pour appeler et traiter les scripts au sein de la même machine Asterisk. Le chapitre suivant est consacré à ARI, l'API REST/WebSocket moderne qui donne aux applications externes un contrôle total sur les canaux et les ponts Asterisk.

## Quiz

1. Laquelle des méthodes suivantes n'est PAS une méthode d'interface pour Asterisk ?
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. AMI permet de transmettre des commandes Asterisk via des sockets TCP, et cette interface est activée par défaut dans une installation propre d'Asterisk.
   - A. Vrai
   - B. Faux
3. AMI est très sécurisé, car son authentification utilise un mécanisme de défi/réponse MD5.
   - A. Vrai
   - B. Faux
4. FastAGI permet au dialplan d'appeler des scripts externes sur une autre machine via des sockets TCP (généralement sur le port 4573).
   - A. Vrai
   - B. Faux
5. DeadAGI est utilisé sur des canaux actifs. Il peut être utilisé sur des canaux DAHDI mais pas sur des canaux SIP ou IAX.
   - A. Vrai
   - B. Faux
6. AGI ne prend en charge que PHP comme langage de script.
   - A. Vrai
   - B. Faux
7. La commande ___ affiche toutes les commandes AGI disponibles.
8. La commande ___ affiche toutes les commandes AMI disponibles.
9. Dans un paquet d'action AMI, quel en-tête le client doit-il inclure afin que les réponses asynchrones et les événements renvoyés par Asterisk puissent être corrélés avec l'action qui les a déclenchés ?
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. Quelle classe de permission manager.conf AMI un utilisateur doit-il posséder pour exécuter l'action `Originate` et passer un appel sortant ?
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**Réponses :** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
