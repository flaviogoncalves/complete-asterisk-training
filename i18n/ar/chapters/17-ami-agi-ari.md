# توسيع Asterisk باستخدام AMI و AGI

في العديد من المواقف، قد يكون من الضروري توسيع ميزات Asterisk باستخدام تطبيقات خارجية. هناك طرق عديدة ومختلفة يمكن من خلالها توسيع النظام. في هذا الفصل، سنغطي اثنتين من الطرق الكلاسيكية لدمج Asterisk مع أنظمة أخرى: AMI – Asterisk Manager Interface و AGI – Asterisk Gateway Interface. سنلقي نظرة أيضاً على الأمر `asterisk –rx` والتطبيق `system()`. يعتمد اختيار الطريقة التي تريد دمجها مع Asterisk على التطبيق نفسه. بالنسبة لـ AGI، التطبيق الأكثر شيوعاً هو IVR المتصل بقاعدة بيانات. أما بالنسبة لـ AMI، فإن برامج الاتصال (dialers) هي التطبيق الأكثر رواجاً. واجهة ثالثة أكثر حداثة — وهي ARI، أي Asterisk REST Interface — يتم تناولها بشكل منفصل في الفصل التالي.

## الأهداف

بحلول نهاية هذا الفصل، ينبغي أن يكون القارئ قادراً على:

- وصف خيارات الوصول إلى البرامج الخارجية
- استخدام الأمر `asterisk –rx` لتنفيذ أمر عبر وحدة التحكم
- استخدام التطبيق `system()` لاستدعاء برامج خارجية في الـ dialplan
- شرح ماهية AMI وكيفية عملها
- تهيئة ملف `manager.conf` وتفعيل AMI
- تنفيذ أمر AMI من برنامج PHP
- شرح ماهية Asterisk manager proxy وكيفية عملها
- وصف أنواع AGI المختلفة (DeadAGI، AGI، EAGI، FastAGI)
- تنفيذ برنامج AGI بسيط تم إنشاؤه باستخدام PHP

## الطرق الرئيسية لتوسيع Asterisk

يمتلك Asterisk طرقاً مختلفة للربط مع البرامج الخارجية. في هذا الفصل، سنغطي ما يلي:

- سطر أوامر Linux و Asterisk Console
- تطبيق System()
- AMI
- AGI

## توسيع Asterisk باستخدام واجهة سطر الأوامر (CLI)

يمكن لأي تطبيق استدعاء Asterisk بسهولة من غلاف Linux باستخدام الأمر التالي.

```
asterisk -rx <command>
```

مثال:

```
asterisk -rx "stop now"
```

حتى الأوامر التي لها مخرجات يمكن استدعاؤها:

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

## توسيع Asterisk باستخدام تطبيق System()

يُمكّن تطبيق System() نظام Asterisk من استدعاء تطبيق خارجي.

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

مثال: يقوم هذا التطبيق بإظهار نافذة منبثقة (screen-pop) باستخدام netbios WindowsPopup.

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## ما هو AMI؟

يُمكّن AMI برنامج العميل من الاتصال بمثيل Asterisk وإصدار الأوامر أو قراءة الأحداث عبر اتصال TCP. سيجد مُكاملو الأنظمة هذه الموارد مفيدة لتتبع حالات القنوات. يعتمد AMI على مفهوم بسيط لبروتوكول خطي يستخدم أزواج key:value عبر TCP. إن Asterisk بحد ذاته ليس جاهزاً للتعامل مع عدد كبير جداً من الاتصالات عبر هذه الواجهة. إذا كان لديك الكثير من الاتصالات بـ AMI، ففكر في استخدام Asterisk manager proxy.

### ما هي اللغة التي يجب استخدامها لـ AMI

قد يكون اختيار لغة البرمجة أمراً صعباً في هذه الأيام. هناك ببساطة الكثير من الخيارات—Java، وPHP، وPerl، وC، وC#، وPython، وغيرها الكثير. من الممكن استخدام AMI مع أي لغة تدعم واجهة socket أو telnet. لقد اخترنا PHP لهذا الكتاب بسبب شعبيتها.

### سلوك بروتوكول AMI

- قبل إرسال أي أوامر إلى Asterisk، تحتاج إلى إنشاء جلسة AMI
- سيكون للسطر الأول من الحزمة المفتاح “Action” عند إرساله من عميل
- سيكون للسطر الأول من الحزمة المفتاح “Response” أو “Event” عند قدومه من Asterisk
- يمكن نقل الحزم في أي اتجاه بعد المصادقة

### أنواع الحزم

يتم تحديد نوع الحزمة من خلال وجود المفاتيح التالية:

- Action: حزمة يتم إرسالها من عميل متصل بـ AMI تطلب إجراءً محدداً. هناك مجموعة محدودة من الإجراءات المتاحة للعملاء. تحدد الوحدات النمطية (modules) المحملة هذه الإجراءات. تحتوي الحزمة على اسم الإجراء ومعلماته.
- Response: الاستجابة المرسلة من Asterisk للإجراء الأخير المرسل من العميل.
- Event: بيانات تنتمي إلى حدث تم إنشاؤه في نواة Asterisk أو بواسطة وحدة نمطية.

عندما يرسل العميل حزمًا من نوع Action، يتم تضمين معلمة تسمى ActionID. نظراً لأنه لا يمكن التنبؤ بالترتيب الذي يتم به إرسال الاستجابات من Asterisk، يتم استخدام ActionID لربط الإجراءات بالاستجابات. تُستخدم حزم Event في سياقين مختلفين. أولاً، تُعلم الأحداث العميل بالتغييرات في Asterisk (على سبيل المثال، قنوات تم إنشاؤها حديثاً، أو قنوات تم قطع اتصالها، أو وكلاء يقومون بتسجيل الدخول والخروج من طابور انتظار). ثانياً، تُستخدم الأحداث لنقل الاستجابات إلى إجراء العميل.

## إعداد المستخدمين والصلاحيات

للوصول إلى AMI، من الضروري إنشاء اتصال TCP يستمع إلى منفذ TCP (عادةً 5038). ستحتاج إلى إعداد ملف /etc/asterisk/manager.conf لإنشاء حساب مستخدم وصلاحيات. هناك مجموعة محدودة من الصلاحيات: "read" (قراءة)، أو "write" (كتابة)، أو كليهما. يتم تعريف هذه الصلاحيات في

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

### تسجيل الدخول إلى AMI

لتسجيل الدخول إلى AMI والمصادقة، ستحتاج إلى إرسال حزمة إجراء (action packet) من نوع login مع اسم المستخدم والحساب الذي تم إنشاؤه في manager.conf.

```
Action:login
Username:admin
Secret:password
```

مثال: تسجيل الدخول إلى AMI باستخدام php

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

إذا كنت لا تحتاج إلى تلقي الأحداث، يمكنك استخدام "Events Off".

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### حزم الإجراءات (Action packets)

عند إرسال حزمة إجراء إلى Asterisk، يمكنك توفير بعض المفاتيح الإضافية (على سبيل المثال، الرقم المطلوب) عن طريق تمرير أزواج key:value بعد الإجراء. من الممكن أيضاً تمرير متغيرات القناة والمتغيرات العامة إلى الـ dialplan.

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### أوامر الإجراءات (Action commands)

يمكنك استخدام تعليمات CLI المسماة manager show commands لسرد الإجراءات المتاحة. في Asterisk 22، تتضمن المجموعة الأساسية من الأوامر ما يلي (هذه القائمة تمثيلية؛ حيث تضيف الوحدات المحملة المزيد):

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

إذا كنت بحاجة إلى معرفة معلمات أمر محدد، استخدم manager show command <command>. مثال:

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

### حزم الأحداث (Event packets)

يتم إنشاء الأحداث على واجهة المدير (manager interface) كلما حدث شيء ما في Asterisk — مثل إنشاء قناة أو تغير حالتها، أو ربط قناتين أو فك الربط بينهما، أو تغير في التسجيل، أو إضافة عضو إلى قائمة انتظار، وما إلى ذلك. كل حدث عبارة عن كتلة من

`Key: value` أسطر تبدأ بترويسة `Event:`.

تعتمد المجموعة الدقيقة للأحداث على الوحدات المحملة وإصدار Asterisk، لذا بدلاً من إعادة إنتاج قائمة قد تصبح قديمة بسرعة، قم بالاستعلام عن الخادم قيد التشغيل للحصول على المجموعة الموثوقة:

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

على سبيل المثال، يتم الإبلاغ عن ربط المكالمات من خلال أحداث `BridgeCreate` و `BridgeEnter` و `BridgeLeave` و `BridgeDestroy` (حيث أن `BridgeEnter` تعني "يتم إطلاقها عندما تدخل قناة إلى جسر"). تمت إزالة أحداث `Link`/`Unlink` الأقدم في Asterisk 12.

## Asterisk Gateway Interface

AGI هي واجهة بوابة لـ Asterisk تشبه CGI المستخدمة من قبل خوادم الويب. وهي تسمح باستخدام لغات عالية المستوى مثل Perl و PHP و Python لتوسيع وظائف Asterisk. التطبيق الرئيسي لـ CGI هو بناء IVR. هناك أربعة أنواع من AGI:

- AGI العادي (Normal AGI)، والذي يستدعي برنامجاً داخل صندوق Asterisk.
- Fast AGI، والذي يستدعي AGI في خادم آخر باستخدام مقابس TCP.
- EAGI، والذي يتيح الوصول إلى القناة الصوتية والتحكم فيها من خلال AGI.
- DeadAGI، والذي يمنح الوصول إلى القناة حتى بعد hangup(). يُستدعى عادةً في الـ extension المسمى ‘h’. لاحظ أنه في Asterisk 22، أصبح تطبيق `DeadAGI` مهملاً — حيث يقوم تطبيق `AGI` العادي باكتشاف القناة المعلقة وتشغيل البرنامج النصي في وضع "dead" تلقائياً، لذا يجب على الـ dialplan الجديدة استدعاء `AGI()` بدلاً من ذلك.

تنسيق التطبيق:

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

يمكنك عرض أوامر AGI المتاحة باستخدام الأمر `agi show commands` (المخرجات أدناه تمثيلية؛ يضيف Asterisk 22 بضعة أوامر إضافية):

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

لتصحيح الأخطاء، استخدم agi debug.

### استخدام AGI

في هذا المثال، سنستخدم php-cli، وهي نسخة سطر الأوامر من php. قم بتثبيت php-cli إذا لم يكن مثبتاً بالفعل. اتبع هذه الخطوات لاستخدام برامج AGI النصية بلغة php.

1. توجد جميع برامج AGI النصية في `/var/lib/asterisk/agi-bin`
2. قم بتغيير الأذونات للسماح بالتنفيذ.

```
chmod 755 *.php
```

3. واجهة Shell (خاصة بـ php). يجب أن تكون الأسطر الأولى من البرنامج النصي كالتالي:

```
#!/usr/bin/php -q
<?php
```

4. فتح قنوات الإدخال/الإخراج (I/O):

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. إدارة مخرجات Asterisk. يرسل Asterisk المعلومات المحددة في كل مرة يتم فيها استدعاء AGI.

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

احفظ المعلومات المرسلة:

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

سيقوم البرنامج النصي السابق بإنشاء مصفوفة تسمى $agi. الخيارات المتاحة هي:

- agi_request – اسم ملف AGI
- agi_channel – القناة التي نشأ منها AGI
- agi_language – اللغة المحددة
- agi_type – نوع القناة (مثلاً: SIP, DAHDI)
- agi_uniqueid – معرف فريد
- agi_callerid – معرف المتصل (مثال: Flavio <8590>)
- agi_context – الـ context الأصلي
- agi_extension – الـ extensions المطلوبة
- agi_priority – الأولوية
- agi_accountcode – رمز الحساب الأصلي

لاستدعاء متغير يسمى agi_extensions، استخدم $agi[agi_extensions].

6. استخدام قناة AGI. في هذه المرحلة، يمكنك البدء في التحدث إلى Asterisk. استخدم الأمر fputs لإرسال الأوامر إلى AGI. يمكنك أيضاً استخدام الأمر echo.

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

ملاحظات حول استخدام علامات الاقتباس:

- خيارات أمر AGI ليست اختيارية
- بعض الخيارات تحتاج إلى وضعها بين علامات اقتباس <escape digits>
- بعض الخيارات يجب ألا توضع بين علامات اقتباس <digit string>
- بعض الخيارات يمكنها استخدام كلا التنسيقين
- يمكنك استخدام علامات اقتباس مفردة

الخطوة 7 – تمرير المتغيرات: يمكن تعيين متغيرات القناة في AGI، ولكن لا يمكن استخدامها داخل AGI. المثال التالي لا يعمل داخل AGI.

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

المثال التالي يعمل:

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

الخطوة 8: استجابات Asterisk: ما يلي ضروري للتحقق من الاستجابات الواردة من Asterisk:

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

الخطوة 9: إنهاء العمليات العالقة (zombie): إذا فشل البرنامج النصي لسبب ما، فستتعلق العملية. استخدم الأمر killproc لتنظيفها قبل الاختبار مرة أخرى.

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

يُستخدم DeadAGI عندما لا يكون لديك قناة نشطة. عادةً ما تقوم بتنفيذ DeadAGI في الـ extension المسمى ´h´. في Asterisk 22، أصبح تطبيق `DeadAGI` مهملاً وقد تتم إزالته في إصدار مستقبلي؛ حيث يتعامل تطبيق `AGI` القياسي الآن مع القنوات المعلقة ("dead") تلقائياً، لذا يفضل استخدام `AGI()` في الـ dialplan الجديدة.

### FASTAGI

يطبق Fast AGI واجهة AGI باستخدام منفذ TCP (المنفذ 4573 افتراضياً) كقناة للإدخال/الإخراج. تنسيق FastAGI هو (agi://). على سبيل المثال:

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

عند فقدان اتصال TCP أو انقطاعه، ينتهي AGI ويتم إغلاق اتصال TCP، متبوعاً بقطع المكالمة. هذا المورد مفيد لتخفيف حمل وحدة المعالجة المركزية (CPU) عن خادم Asterisk الخاص بك الذي يشغل برامج نصية في خادم خارجي. يمكنك الحصول على مزيد من التفاصيل حول FastAGI في دليل الكود المصدري (يرجى الاطلاع على الملف “agi/fastagi-test”). توفر مكتبة Asterisk-Java تنفيذاً لخادم FastAGI للغة Java. لمزيد من المعلومات، راجع https://github.com/asterisk-java/asterisk-java

سيكون ARI، وهو واجهة REST/WebSocket الحديثة، موضوع الفصل التالي.

## تغيير الكود المصدري

تم تطوير Asterisk بلغة C (وليس C++). إن تعليم برمجة C يقع خارج نطاق هذا المستند. إذا كنت مهتماً، فستجد وثائق ذات صلة على الرابط https://docs.asterisk.org، والذي يقدم نصائح جيدة حول كيفية تطبيق وإنشاء تصحيحات (patches) لـ Asterisk بالإضافة إلى وثائق API التي يتم إنشاؤها غالباً بواسطة برنامج Doxygen. بالنسبة لأولئك الملمين ببرمجة C، يمكن أن يكون تغيير الكود المصدري للتطبيقات الطريقة الأكثر قوة (والأكثر خطورة) لتوسيع نطاق Asterisk.

## ملخص

في هذا الفصل، تعلمت كيفية ربط البرامج الخارجية بـ Asterisk PBX. بدأنا باستخدام `asterisk -rx` لتمرير الأوامر من غلاف Linux إلى وحدة تحكم Asterisk. بعد ذلك، تعرفنا على تطبيق `System()`، الذي يسمح باستدعاء برنامج خارجي من الـ dialplan. تُعد AMI الواجهة الأقرب إلى واجهة CTI الشائعة في أنظمة PBX التقليدية. لاستدعاء تطبيق من الـ dialplan، استخدمنا AGI، مع استعراض نكهاته المختلفة: `DeadAGI` للقنوات الميتة، و `EAGI` للتعامل مع تدفق الصوت، و `Fast AGI` لاستخدام مقابس TCP كواجهة إدخال/إخراج، و `AGI` العادي لاستدعاء ومعالجة النصوص البرمجية داخل نفس صندوق Asterisk. الفصل التالي مخصص لـ ARI، وهي واجهة برمجة تطبيقات REST/WebSocket الحديثة التي تمنح التطبيقات الخارجية تحكماً كاملاً في قنوات وجسور Asterisk.

## اختبار

1. أي مما يلي ليس طريقة ربط (interfacing method) لـ Asterisk؟
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. تسمح واجهة AMI بتمرير أوامر Asterisk عبر مقابس TCP، ويتم تفعيل هذه الواجهة افتراضياً في تثبيت Asterisk الجديد.
   - A. صواب
   - B. خطأ
3. واجهة AMI آمنة جداً، لأن عملية المصادقة فيها تستخدم تحدي/استجابة MD5.
   - A. صواب
   - B. خطأ
4. تتيح FastAGI لـ dialplan استدعاء نصوص برمجية خارجية على جهاز آخر عبر مقابس TCP (عادةً المنفذ 4573).
   - A. صواب
   - B. خطأ
5. تُستخدم DeadAGI على القنوات النشطة. ويمكن استخدامها على قنوات DAHDI ولكن ليس على قنوات SIP أو IAX.
   - A. صواب
   - B. خطأ
6. تدعم AGI لغة PHP فقط كلغة برمجة.
   - A. صواب
   - B. خطأ
7. الأمر ___ يعرض جميع أوامر AGI المتاحة.
8. الأمر ___ يعرض جميع أوامر AMI المتاحة.
9. في حزمة إجراءات AMI، ما هو الترويسة (header) التي يدرجها العميل بحيث يمكن ربط الاستجابات والأحداث غير المتزامنة القادمة من Asterisk بالإجراء الذي أطلقها؟
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. أي فئة صلاحيات في ملف manager.conf الخاص بـ AMI يجب أن يمتلكها المستخدم من أجل تشغيل الإجراء `Originate` وإجراء مكالمة صادرة؟
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**الإجابات:** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
