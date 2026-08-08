# Estendendo o Asterisk com AMI e AGI

Em diversas situações, pode ser necessário estender as funcionalidades do Asterisk usando aplicações externas. Existem muitas maneiras diferentes pelas quais ele pode ser estendido. Neste capítulo, abordaremos duas das formas clássicas de integrar o Asterisk com outros sistemas: AMI – Asterisk Manager Interface e AGI – Asterisk Gateway Interface. Também veremos o comando asterisk –rx e a aplicação system(). A escolha de qual forma você deseja integrar com o Asterisk depende da aplicação. Para AGI, a aplicação mais comum é a IVR conectada a um banco de dados. Para AMI, discadores são a aplicação mais popular. Uma terceira interface, mais moderna — ARI, a Asterisk REST Interface — é abordada separadamente no próximo capítulo.

## Objetivos

Ao final deste capítulo, o leitor deverá ser capaz de:

- Descrever as opções de acesso a programas externos
- Usar o comando asterisk –rx para executar um comando de console
- Usar o aplicativo system() para chamar programas externos no dialplan
- Explicar o que é AMI e como ele funciona
- Configurar o arquivo manager.conf e habilitar o AMI
- Executar um comando AMI a partir de um programa PHP
- Explicar o que é o Asterisk manager proxy e como ele funciona
- Descrever diferentes tipos de AGI (DeadAGI, AGI, EAGI, FastAGI)
- Executar um programa AGI simples criado com PHP

## Principais formas de estender o Asterisk

O Asterisk possui diferentes maneiras de interagir com programas externos. Neste capítulo, abordaremos:

- Linha de comando do Linux e Console do Asterisk
- Aplicação System()
- AMI
- AGI

## Estendendo o Asterisk com a CLI do console

Uma aplicação pode facilmente chamar o Asterisk a partir do shell do Linux usando o seguinte comando.

```
asterisk -rx <command>
```

Exemplo:

```
asterisk -rx "stop now"
```

Até mesmo um comando com uma saída pode ser chamado:

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

## Estendendo o Asterisk usando a aplicação System()

A aplicação system() permite que o Asterisk chame uma aplicação externa.

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

Exemplo: Esta aplicação realiza um screen-pop usando o netbios WindowsPopup.

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## O que é o AMI?

O AMI permite que um programa cliente se conecte a uma instância do Asterisk e emita comandos ou leia eventos através de uma conexão TCP. Integradores de sistemas acharão esses recursos úteis para rastrear estados de canais. O AMI baseia-se em um conceito simples de protocolo de linha usando pares chave:valor sobre TCP. O Asterisk, por si só, não está preparado para lidar com muitas conexões através desta interface. Se você tiver muitas conexões com o AMI, considere usar um Asterisk manager proxy.

### Qual linguagem usar para o AMI

Selecionar uma linguagem de programação pode ser difícil hoje em dia. Existem simplesmente opções demais — Java, PHP, Perl, C, C#, Python e várias outras. É possível usar o AMI com qualquer linguagem que suporte uma interface de socket ou telnet. Escolhemos o PHP para este livro devido à sua popularidade.

### Comportamento do protocolo AMI

- Antes de enviar quaisquer comandos para o Asterisk, você precisa estabelecer uma sessão AMI
- A primeira linha de um pacote terá a chave “Action” quando enviada de um cliente
- A primeira linha de um pacote terá a chave “Response” ou “Event” quando vier do Asterisk
- Pacotes podem ser transmitidos em qualquer direção após a autenticação

### Tipos de pacotes

O tipo do pacote é determinado pela existência das seguintes chaves:

- Action: Um pacote enviado de um cliente conectado ao AMI solicitando uma ação específica. Existe um conjunto finito de ações disponíveis para os clientes. Os módulos carregados determinam essas ações. Um pacote contém o nome da ação e seus parâmetros.
- Response: A resposta enviada do Asterisk para a última ação enviada pelo cliente.
- Event: Dados pertencentes a um evento gerado no núcleo do Asterisk ou por um módulo.

Quando um cliente envia pacotes do tipo Action, um parâmetro chamado ActionID é incluído. Como a ordem na qual as respostas enviadas pelo Asterisk não pode ser prevista, o ActionID é usado para correlacionar ações e respostas. Pacotes de eventos são usados em dois contextos diferentes. Primeiro, os eventos informam o cliente sobre mudanças no Asterisk (por exemplo, canais recém-criados, canais desconectados ou agentes entrando e saindo de uma fila). Segundo, os eventos são usados para transportar respostas para uma ação do cliente.

## Configurando usuários e permissões

Para acessar o AMI, é necessário estabelecer uma conexão TCP escutando em uma porta TCP (geralmente 5038). Você precisará configurar o arquivo /etc/asterisk/manager.conf para criar uma conta de usuário e permissões. Existe um conjunto finito de permissões: “read”, “write” ou ambos. Essas permissões são definidas no

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

### Efetuando login no AMI

Para efetuar login e autenticar no AMI, você precisará enviar um pacote de ação do tipo login com um nome de usuário e conta criados no manager.conf.

```
Action:login
Username:admin
Secret:password
```

Exemplo: Efetuando login no AMI usando php

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

Se você não precisar receber os eventos, pode usar “Events Off”.

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### Pacotes de ação

Ao enviar um pacote de ação para o Asterisk, você pode fornecer algumas chaves extras (por exemplo, número chamado) passando pares chave:valor após a ação. Também é possível passar variáveis de canal e globais para o dialplan.

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### Comandos de ação

Você pode usar a instrução de CLI manager show commands para listar as ações disponíveis. No Asterisk 22, o conjunto principal de comandos inclui (esta lista é representativa; módulos carregados adicionam mais):

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

Se você precisar saber parâmetros específicos de um comando, use o manager show command <command>. Exemplo:

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

### Pacotes de evento

Eventos são gerados na interface do manager sempre que algo acontece no Asterisk — um canal é criado ou muda de estado, dois canais são conectados (bridged) ou desconectados, um registro muda, um membro de fila é adicionado, e assim por diante. Cada evento é um bloco de

`Key: value` linhas começando com um cabeçalho `Event:`.

O conjunto exato de eventos depende dos módulos carregados e da versão do Asterisk, portanto, em vez de reproduzir uma lista que rapidamente se torna obsoleta, consulte o servidor em execução para obter o conjunto oficial:

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

Por exemplo, a conexão de chamadas (bridging) é relatada através dos eventos `BridgeCreate`, `BridgeEnter`, `BridgeLeave` e `BridgeDestroy` (`BridgeEnter` é "Disparado quando um canal entra em uma bridge"). Os eventos mais antigos `Link`/`Unlink` foram removidos no Asterisk 12.

## Asterisk Gateway Interface

AGI é uma interface de gateway para o Asterisk semelhante ao CGI usado por servidores web. Ela permite o uso de linguagens de alto nível como Perl, PHP e Python para estender a funcionalidade do Asterisk. A principal aplicação para CGIs é a construção de IVR. Existem quatro tipos de AGI:

- AGI normal, que chama um programa dentro da caixa do Asterisk.
- Fast AGI, que chama uma AGI em outro servidor usando sockets TCP.
- EAGI, que permite acesso e controle do canal de áudio a partir da AGI.
- DeadAGI, que dá acesso ao canal mesmo após o hangup(). Geralmente chamado na extension ‘h’. Observe que no Asterisk 22 a aplicação `DeadAGI` está obsoleta — a aplicação regular `AGI` detecta um canal desligado e executa o script em modo "dead" automaticamente, portanto, novos dialplans devem apenas chamar `AGI()` em vez disso.

Formato da aplicação:

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

Você pode exibir os comandos AGI disponíveis usando o comando `agi show commands` (a saída abaixo é representativa; o Asterisk 22 adiciona alguns comandos adicionais):

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

Para depurar, use agi debug.

### Usando AGI

Neste exemplo, usaremos o php-cli, a versão de linha de comando do PHP. Instale o php-cli se ele ainda não estiver instalado. Siga estes passos para usar scripts AGI em PHP.

1. Todos os scripts AGI estão localizados em `/var/lib/asterisk/agi-bin`
2. Altere as permissões para permitir a execução.

```
chmod 755 *.php
```

3. Interface de shell (específico para PHP). As primeiras linhas do script devem ser:

```
#!/usr/bin/php -q
<?php
```

4. Abrir canais de E/S:

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. Gerenciar a saída do Asterisk. O Asterisk envia as informações definidas cada vez que a AGI é chamada.

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

Salve as informações enviadas:

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

O script anterior criará um array chamado $agi. As opções disponíveis são:

- agi_request – Nome do arquivo AGI
- agi_channel – Canal de origem da AGI
- agi_language – Idioma definido
- agi_type – Tipo de canal (ex.: SIP, DAHDI)
- agi_uniqueid – Identificador único
- agi_callerid – CallerID (Ex. Flavio <8590>)
- agi_context – Contexto de origem
- agi_extension – Extensions chamadas
- agi_priority – Prioridade
- agi_accountcode – Código de conta de origem

Para chamar uma variável chamada agi_extensions, use $agi[agi_extensions].

6. Usar AGI de canal. Neste ponto, você pode começar a falar com o Asterisk. Use o comando fputs para enviar comandos para a AGI. Você também pode usar o comando echo.

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

Notas sobre o uso de aspas:

- As opções de comando AGI não são opcionais
- Algumas opções precisam ser colocadas entre aspas <escape digits>
- Algumas opções não devem ser colocadas entre aspas <digit string>
- Algumas opções podem usar ambos os formatos
- Você pode usar aspas simples

Passo 7 – Passar variáveis Variáveis de canal podem ser definidas na AGI, mas não podem ser usadas dentro da AGI. O exemplo a seguir não funciona dentro de uma AGI.

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

O exemplo a seguir funciona:

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

Passo 8: Respostas do Asterisk O seguinte é necessário para verificar as respostas do Asterisk:

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

Passo 9: Matar os processos travados (zumbis) Se o seu script falhar por algum motivo, o processo ficará travado. Use o comando killproc para limpá-lo antes de testar novamente.

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

DeadAGI é usado quando você não tem um canal ativo. Geralmente, você executa a DeadAGI na extension ´h´. No Asterisk 22, a aplicação `DeadAGI` está obsoleta e pode ser removida em uma versão futura; a aplicação padrão `AGI` agora lida com canais desligados ("dead") automaticamente, portanto, prefira `AGI()` em novos dialplans.

### FASTAGI

Fast AGI implementa AGI usando uma porta TCP (4573 por padrão) como canal de Entrada/Saída. O formato FastAGI é (agi://). Por exemplo:

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

Quando a conexão TCP é perdida ou desconectada, a AGI termina e a conexão TCP é fechada, seguida pela desconexão da chamada. Este recurso é útil para aliviar a carga da CPU do seu servidor Asterisk executando scripts em um servidor externo. Você pode obter mais detalhes sobre o FastAGI no diretório de código-fonte (por favor, veja o arquivo “agi/fastagi-test”). A biblioteca Asterisk-Java fornece uma implementação de servidor FastAGI para Java. Para mais informações, veja https://github.com/asterisk-java/asterisk-java

ARI, a interface moderna REST/WebSocket, terá seu próprio capítulo a seguir.

## Alterando o código-fonte

O Asterisk é desenvolvido na linguagem C (não C++). Ensinar programação em C está fora do escopo deste documento. Se você estiver interessado, encontrará documentação relacionada em https://docs.asterisk.org, que oferece boas dicas sobre como aplicar e criar patches para o Asterisk, bem como documentação de API gerada principalmente pelo software Doxygen. Para aqueles familiarizados com a programação em C, alterar o código-fonte das aplicações pode ser a maneira mais poderosa (e perigosa) de estender o Asterisk.

## Resumo

Neste capítulo, você aprendeu como fazer a interface de programas externos com o Asterisk PBX. Começamos com o `asterisk -rx`, passando comandos do shell do Linux para o console do Asterisk. Em seguida, aprendemos sobre a aplicação `System()`, que permite chamar um programa externo a partir do dialplan. O AMI é a interface mais próxima de uma interface CTI comum em PBXs tradicionais. Para chamar uma aplicação a partir do dialplan, usamos o AGI, com uma amostra de seus diferentes sabores: DeadAGI para canais mortos, EAGI para manipular o fluxo de áudio, Fast AGI para usar sockets TCP como interface de entrada/saída e o AGI normal para chamar e processar scripts dentro da mesma máquina Asterisk. O próximo capítulo é dedicado ao ARI, a moderna API REST/WebSocket que dá às aplicações externas controle total dos canais e bridges do Asterisk.

## Quiz

1. Qual dos seguintes NÃO é um método de interface para o Asterisk?
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. O AMI permite enviar comandos do Asterisk via sockets TCP, e essa interface é habilitada por padrão em uma instalação nova do Asterisk.
   - A. Verdadeiro
   - B. Falso
3. O AMI é muito seguro, porque sua autenticação utiliza desafio/resposta MD5.
   - A. Verdadeiro
   - B. Falso
4. O FastAGI permite que o dialplan chame scripts externos em outra máquina via sockets TCP (geralmente na porta 4573).
   - A. Verdadeiro
   - B. Falso
5. O DeadAGI é usado em canais ativos. Ele pode ser usado em canais DAHDI, mas não em canais SIP ou IAX.
   - A. Verdadeiro
   - B. Falso
6. O AGI suporta apenas PHP como linguagem de script.
   - A. Verdadeiro
   - B. Falso
7. O comando ___ mostra todos os comandos AGI disponíveis.
8. O comando ___ mostra todos os comandos AMI disponíveis.
9. Em um pacote de ação AMI, qual cabeçalho o cliente inclui para que as respostas assíncronas e os eventos retornados pelo Asterisk possam ser correlacionados com a ação que os disparou?
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. Qual classe de permissão do manager.conf do AMI um usuário deve ter para executar a ação `Originate` e realizar uma chamada de saída?
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**Respostas:** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
