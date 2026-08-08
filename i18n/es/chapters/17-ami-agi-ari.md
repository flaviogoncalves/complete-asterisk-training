# Extendiendo Asterisk con AMI y AGI

En diversas situaciones, puede ser necesario extender las funcionalidades de Asterisk mediante aplicaciones externas. Existen muchas formas diferentes en las que puede ser extendido. En este capítulo, cubriremos dos de las formas clásicas de integrar Asterisk con otros sistemas: AMI – Asterisk Manager Interface y AGI – Asterisk Gateway Interface. También veremos el comando asterisk –rx y la aplicación system(). Elegir qué forma desea utilizar para integrarse con Asterisk depende de la aplicación. Para AGI, la aplicación más habitual es el IVR conectado a una base de datos. Para AMI, los marcadores son la aplicación más popular. Una tercera interfaz, más moderna — ARI, la Asterisk REST Interface — se trata por separado en el siguiente capítulo.

## Objetivos

Al finalizar este capítulo, el lector debería ser capaz de:

- Describir las opciones de acceso a programas externos
- Usar el comando asterisk –rx para ejecutar un comando de consola
- Usar la aplicación system() para llamar a programas externos en el dialplan
- Explicar qué es AMI y cómo funciona
- Configurar el archivo manager.conf y habilitar AMI
- Ejecutar un comando AMI desde un programa PHP
- Explicar qué es Asterisk manager proxy y cómo funciona
- Describir las diferentes variantes de AGI (DeadAGI, AGI, EAGI, FastAGI)
- Ejecutar un programa AGI simple creado con PHP

## Principales formas de extender Asterisk

Asterisk cuenta con diferentes formas de interactuar con programas externos. En este capítulo, cubriremos:

- Línea de comandos de Linux y la consola de Asterisk
- Aplicación System()
- AMI
- AGI

## Extensión de Asterisk con la CLI de consola

Una aplicación puede llamar fácilmente a Asterisk desde la shell de Linux utilizando el siguiente comando.

```
asterisk -rx <command>
```

Ejemplo:

```
asterisk -rx "stop now"
```

Incluso se puede llamar a un comando que tenga una salida:

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

## Extensión de Asterisk mediante la aplicación System()

La aplicación system() permite que Asterisk llame a una aplicación externa.

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

Ejemplo: Esta aplicación realiza un screen-pop utilizando netbios WindowsPopup.

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## ¿Qué es AMI?

AMI permite que un programa cliente se conecte a una instancia de Asterisk y emita comandos o lea eventos a través de una conexión TCP. Los integradores de sistemas encontrarán estos recursos útiles para rastrear los estados de los canales. AMI se basa en un concepto simple de protocolo de línea que utiliza pares de key:value sobre TCP. Asterisk por sí solo no está preparado para manejar demasiadas conexiones a través de esta interfaz. Si tiene muchas conexiones a AMI, considere utilizar un Asterisk manager proxy.

### Qué lenguaje utilizar para AMI

Seleccionar un lenguaje de programación puede ser difícil hoy en día. Simplemente hay demasiadas opciones: Java, PHP, Perl, C, C#, Python y varias otras. Es posible utilizar AMI con cualquier lenguaje que soporte una interfaz de socket o telnet. Hemos elegido PHP para este libro debido a su popularidad.

### Comportamiento del protocolo AMI

- Antes de enviar cualquier comando a Asterisk, necesita establecer una sesión AMI
- La primera línea de un paquete tendrá la clave “Action” cuando se envíe desde un cliente
- La primera línea de un paquete tendrá la clave “Response” o “Event” cuando provenga de Asterisk
- Los paquetes pueden ser transmitidos en cualquier dirección después de la autenticación

### Tipos de paquetes

El tipo de paquete se determina por la existencia de las siguientes claves:

- Action: Un paquete enviado desde un cliente conectado a AMI solicitando una acción específica. Existe un conjunto finito de acciones disponibles para los clientes. Los módulos cargados determinan estas acciones. Un paquete contiene el nombre de la acción y sus parámetros.
- Response: La respuesta enviada desde Asterisk a la última acción enviada desde el cliente.
- Event: Datos pertenecientes a un evento generado en el núcleo de Asterisk o por un módulo.

Cuando un cliente envía paquetes del tipo Action, se incluye un parámetro llamado ActionID. Dado que el orden en el que se envían las respuestas desde Asterisk no puede predecirse, ActionID se utiliza para correlacionar acciones y respuestas. Los paquetes de tipo Event se utilizan en dos contextos diferentes. Primero, los eventos informan al cliente sobre cambios en Asterisk (por ejemplo, canales recién creados, canales desconectados o agentes iniciando y cerrando sesión en una cola). Segundo, los eventos se utilizan para transportar respuestas a una acción del cliente.

## Configuración de usuarios y permisos

Para acceder a AMI, es necesario establecer una conexión TCP escuchando en un puerto TCP (usualmente 5038). Necesitará configurar el archivo /etc/asterisk/manager.conf para crear una cuenta de usuario y permisos. Existe un conjunto finito de permisos: “read”, “write” o ambos. Estos permisos se definen en el

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

### Inicio de sesión en AMI

Para iniciar sesión y autenticarse en AMI, deberá enviar un paquete de acción del tipo login con un nombre de usuario y una cuenta creados en manager.conf.

```
Action:login
Username:admin
Secret:password
```

Ejemplo: Inicio de sesión en AMI usando php

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

Si no necesita recibir los eventos, puede usar “Events Off”.

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### Paquetes de acción

Cuando envía un paquete de acción a Asterisk, puede proporcionar algunas claves adicionales (por ejemplo, el número llamado) pasando pares clave:valor después de la acción. También es posible pasar variables de canal y variables globales al dialplan.

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### Comandos de acción

Puede usar la instrucción de CLI manager show commands para listar las acciones disponibles. En Asterisk 22, el conjunto principal de comandos incluye (esta lista es representativa; los módulos cargados añaden más):

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

Si necesita conocer los parámetros específicos de un comando, use manager show command <command>. Ejemplo:

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

### Paquetes de eventos

Los eventos se generan en la interfaz del manager cada vez que sucede algo en Asterisk: se crea un canal o cambia de estado, dos canales son puenteados o despuenteados, un registro cambia, se añade un miembro a una cola, etcétera. Cada evento es un bloque de

`Key: value` líneas que comienza con un encabezado `Event:`.

El conjunto exacto de eventos depende de los módulos cargados y de la versión de Asterisk, así que, en lugar de reproducir una lista que rápidamente queda obsoleta, consulte al servidor en ejecución para obtener el conjunto autorizado:

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

Por ejemplo, el puenteo de llamadas se reporta a través de los eventos `BridgeCreate`, `BridgeEnter`, `BridgeLeave` y `BridgeDestroy` (`BridgeEnter` es "Raised when a channel enters a bridge"). Los eventos más antiguos `Link`/`Unlink` fueron eliminados en Asterisk 12.

## Asterisk Gateway Interface

AGI es una interfaz de puerta de enlace para Asterisk similar a CGI utilizada por los servidores web. Permite el uso de lenguajes de alto nivel como Perl, PHP y Python para extender la funcionalidad de Asterisk. La aplicación principal para los CGI es la creación de IVR. Existen cuatro tipos de AGI:

- AGI normal, que llama a un programa dentro del servidor de Asterisk.
- Fast AGI, que llama a un AGI en otro servidor utilizando sockets TCP.
- EAGI, que permite el acceso y control del canal de audio desde el AGI.
- DeadAGI, que brinda acceso al canal incluso después de un hangup(). Por lo general, se llama en la extension ‘h’. Tenga en cuenta que en Asterisk 22 la aplicación `DeadAGI` está obsoleta; la aplicación regular `AGI` detecta un canal colgado y ejecuta el script en modo "dead" automáticamente, por lo que los nuevos dialplan deberían simplemente llamar a `AGI()` en su lugar.

Formato de la aplicación:

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

Puede mostrar los comandos AGI disponibles utilizando el comando `agi show commands` (la salida a continuación es representativa; Asterisk 22 añade algunos comandos adicionales):

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

Para depurar, utilice agi debug.

### Uso de AGI

En este ejemplo, utilizaremos php-cli, la versión de línea de comandos de php. Instale php-cli si aún no está instalado. Siga estos pasos para utilizar scripts AGI en php.

1. Todos los scripts AGI se encuentran en `/var/lib/asterisk/agi-bin`
2. Cambie los permisos para permitir la ejecución.

```
chmod 755 *.php
```

3. Interfaz de shell (específico de php). Las primeras líneas del script deben ser:

```
#!/usr/bin/php -q
<?php
```

4. Abrir canales de E/S:

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. Gestionar la salida de Asterisk. Asterisk envía la información establecida cada vez que se llama a AGI.

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

Guardar la información enviada:

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

El script anterior creará un arreglo llamado $agi. Las opciones disponibles son:

- agi_request – Nombre del archivo AGI
- agi_channel – Canal de origen del AGI
- agi_language – Idioma configurado
- agi_type – Tipo de canal (ej. SIP, DAHDI)
- agi_uniqueid – Identificador único
- agi_callerid – CallerID (Ej. Flavio <8590>)
- agi_context – Contexto de origen
- agi_extension – Extensiones llamadas
- agi_priority – Prioridad
- agi_accountcode – Código de cuenta de origen

Para llamar a una variable llamada agi_extensions, utilice $agi[agi_extensions].

6. Usar AGI de canal. En este punto, puede comenzar a hablar con Asterisk. Utilice el comando fputs para enviar comandos a AGI. También puede utilizar el comando echo.

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

Notas sobre el uso de comillas:

- Las opciones de los comandos AGI no son opcionales
- Algunas opciones deben estar encerradas entre comillas <escape digits>
- Algunas opciones no deben estar encerradas entre comillas <digit string>
- Algunas opciones pueden usar ambos formatos
- Puede usar comillas simples

Paso 7 – Pasar variables. Las variables de canal se pueden establecer en el AGI, pero no se pueden usar dentro del AGI. El siguiente ejemplo no funciona dentro de un AGI.

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

El siguiente ejemplo sí funciona:

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

Paso 8: Respuestas de Asterisk. Lo siguiente es necesario para verificar las respuestas de Asterisk:

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

Paso 9: Matar los procesos bloqueados (zombie). Si su script falla por alguna razón, el proceso se colgará. Utilice el comando killproc para limpiarlo antes de volver a probar.

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

DeadAGI se utiliza cuando no se tiene un canal activo. Por lo general, se ejecuta el DeadAGI en la extension ´h´. En Asterisk 22 la aplicación `DeadAGI` está obsoleta y podría eliminarse en una versión futura; la aplicación estándar `AGI` ahora maneja los canales colgados ("dead") automáticamente, por lo que se debe preferir `AGI()` en los nuevos dialplan.

### FASTAGI

Fast AGI implementa AGI utilizando un puerto TCP (4573 por defecto) como canal de entrada/salida. El formato de FastAGI es (agi://). Por ejemplo:

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

Cuando la conexión TCP se pierde o se desconecta, el AGI finaliza y la conexión TCP se cierra, seguido de una desconexión de la llamada. Este recurso es útil para aliviar la carga de CPU de su servidor Asterisk ejecutando scripts en un servidor externo. Puede obtener más detalles sobre FastAGI en el directorio del código fuente (consulte el archivo “agi/fastagi-test”). La biblioteca Asterisk-Java proporciona una implementación de servidor FastAGI para Java. Para obtener más información, consulte https://github.com/asterisk-java/asterisk-java

ARI, la moderna interfaz REST/WebSocket, tiene su propio capítulo a continuación.

## Modificación del código fuente

Asterisk está desarrollado en lenguaje C (no C++). Enseñar programación en C está fuera del alcance de este documento. Si le interesa, encontrará documentación relacionada en https://docs.asterisk.org, la cual ofrece buenos consejos sobre cómo aplicar y crear parches para Asterisk, así como documentación de la API generada principalmente por el software Doxygen. Para aquellos familiarizados con la programación en C, modificar el código fuente de las aplicaciones puede ser la forma más poderosa (y peligrosa) de extender Asterisk.

## Resumen

En este capítulo, usted ha aprendido cómo conectar programas externos al PBX Asterisk. Comenzamos con asterisk –rx pasando comandos desde la shell de Linux a la consola de Asterisk. A continuación, aprendimos sobre la aplicación System(), la cual permite llamar a un programa externo desde el dialplan. AMI es la interfaz más cercana a una interfaz CTI común en los PBX tradicionales. Para llamar a una aplicación desde el dialplan, utilizamos AGI, con una muestra de sus diferentes variantes: DeadAGI para canales muertos, EAGI para manejar el flujo de audio, Fast AGI para utilizar sockets TCP como interfaz de entrada/salida, y AGI normal para llamar y procesar los scripts dentro de la misma caja de Asterisk. El siguiente capítulo está dedicado a ARI, la moderna API REST/WebSocket que brinda a las aplicaciones externas control total de los canales y bridges de Asterisk.

## Cuestionario

1. ¿Cuál de los siguientes NO es un método de interfaz para Asterisk?
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. AMI permite enviar comandos de Asterisk a través de sockets TCP, y esta interfaz está habilitada por defecto en una instalación nueva de Asterisk.
   - A. Verdadero
   - B. Falso
3. AMI es muy seguro, porque su autenticación utiliza desafío/respuesta MD5.
   - A. Verdadero
   - B. Falso
4. FastAGI permite que el dialplan llame a scripts externos en otra máquina a través de sockets TCP (usualmente el puerto 4573).
   - A. Verdadero
   - B. Falso
5. DeadAGI se utiliza en canales activos. Puede utilizarse en canales DAHDI pero no en canales SIP o IAX.
   - A. Verdadero
   - B. Falso
6. AGI solo admite PHP como lenguaje de scripting.
   - A. Verdadero
   - B. Falso
7. El comando ___ muestra todos los comandos AGI disponibles.
8. El comando ___ muestra todos los comandos AMI disponibles.
9. En un paquete de acción de AMI, ¿qué encabezado debe incluir el cliente para que las respuestas asíncronas y los eventos que regresan de Asterisk puedan correlacionarse con la acción que los provocó?
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. ¿Qué clase de permiso de manager.conf de AMI debe tener un usuario para poder ejecutar la acción `Originate` y realizar una llamada saliente?
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**Respuestas:** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
