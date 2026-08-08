# AMI और AGI के साथ Asterisk का विस्तार

कई स्थितियों में, बाहरी अनुप्रयोगों (external applications) का उपयोग करके Asterisk सुविधाओं का विस्तार करना आवश्यक हो सकता है। इसे विस्तारित करने के कई अलग-अलग तरीके हैं। इस अध्याय में, हम Asterisk को अन्य प्रणालियों के साथ एकीकृत करने के दो क्लासिक तरीकों को कवर करेंगे: AMI – Asterisk Manager Interface और AGI – Asterisk Gateway Interface। हम `asterisk –rx` कमांड और `system()` एप्लिकेशन पर भी नज़र डालेंगे। आप Asterisk के साथ किस तरह से एकीकृत करना चाहते हैं, यह एप्लिकेशन पर निर्भर करता है। AGI के लिए सबसे सामान्य एप्लिकेशन डेटाबेस से जुड़ा IVR है। AMI के लिए, डायलर सबसे लोकप्रिय ऐप हैं। एक तीसरा, अधिक आधुनिक इंटरफ़ेस — ARI, यानी Asterisk REST Interface — को अगले अध्याय में अलग से कवर किया गया है।

## Objectives

इस अध्याय के अंत तक, पाठक निम्नलिखित में सक्षम होंगे:

- बाहरी प्रोग्रामों तक पहुँचने के विकल्पों का वर्णन करना
- कंसोल कमांड निष्पादित करने के लिए `asterisk –rx` कमांड का उपयोग करना
- dialplan में बाहरी प्रोग्रामों को कॉल करने के लिए `system()` ऐप का उपयोग करना
- यह समझाना कि AMI क्या है और यह कैसे काम करता है
- `manager.conf` फ़ाइल को कॉन्फ़िगर करना और AMI को सक्षम करना
- PHP प्रोग्राम से AMI कमांड निष्पादित करना
- यह समझाना कि Asterisk manager proxy क्या है और यह कैसे काम करता है
- विभिन्न AGI Flavors (DeadAGI, AGI, EAGI, FastAGI) का वर्णन करना
- PHP के साथ बनाए गए एक सरल AGI प्रोग्राम को निष्पादित करना

## Asterisk को विस्तारित करने के प्रमुख तरीके

Asterisk में बाहरी प्रोग्रामों के साथ इंटरफेस करने के विभिन्न तरीके हैं। इस अध्याय में, हम निम्नलिखित को कवर करेंगे:

- Linux कमांड लाइन और Asterisk Console
- System() Application
- AMI
- AGI

## कंसोल CLI के साथ Asterisk का विस्तार करना

एक एप्लिकेशन Linux शेल से निम्नलिखित कमांड का उपयोग करके आसानी से Asterisk को कॉल कर सकता है।

```
asterisk -rx <command>
```

उदाहरण:

```
asterisk -rx "stop now"
```

यहाँ तक कि आउटपुट वाले कमांड को भी कॉल किया जा सकता है:

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

## System() एप्लिकेशन का उपयोग करके Asterisk का विस्तार करना

System() एप्लिकेशन Asterisk को किसी बाहरी एप्लिकेशन को कॉल करने में सक्षम बनाता है।

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

उदाहरण: यह एप्लिकेशन netbios WindowsPopup का उपयोग करके स्क्रीन-पॉप करता है।

```
exten => 9000,1,System(/bin/echo -e "'Incoming Call From -> ${CALLERID(num)}
\\r Received: ${DATETIME}'"|/usr/bin/smbclient -M target_netbiosname)
exten => 9000,2,Dial(PJSIP/9000,15,t)
exten => 9000,3,Hangup
```

## AMI क्या है?

AMI एक क्लाइंट प्रोग्राम को Asterisk इंस्टेंस से कनेक्ट करने और TCP कनेक्शन पर कमांड जारी करने या इवेंट्स को पढ़ने में सक्षम बनाता है। सिस्टम इंटीग्रेटर्स को चैनल स्टेट्स को ट्रैक करने के लिए ये संसाधन उपयोगी लगेंगे। AMI TCP पर key:value पेयर्स का उपयोग करने वाले लाइन प्रोटोकॉल की एक सरल अवधारणा पर निर्भर करता है। Asterisk अपने आप में इस इंटरफ़ेस पर बहुत अधिक कनेक्शन संभालने के लिए तैयार नहीं है। यदि आपके पास AMI के लिए बहुत सारे कनेक्शन हैं, तो Asterisk manager proxy का उपयोग करने पर विचार करें।

### AMI के लिए किस भाषा का उपयोग करें

आजकल प्रोग्रामिंग भाषा का चयन करना कठिन हो सकता है। बहुत सारे विकल्प उपलब्ध हैं—Java, PHP, Perl, C, C#, Python, और कई अन्य। किसी भी ऐसी भाषा के साथ AMI का उपयोग करना संभव है जो socket या telnet इंटरफ़ेस का समर्थन करती है। हमने इस पुस्तक के लिए PHP को उसकी लोकप्रियता के कारण चुना है।

### AMI प्रोटोकॉल व्यवहार

- Asterisk को कोई भी कमांड भेजने से पहले, आपको एक AMI सेशन स्थापित करने की आवश्यकता है
- जब क्लाइंट से भेजा जाता है, तो पैकेट की पहली लाइन में “Action” की होगी
- जब Asterisk से आता है, तो पैकेट की पहली लाइन में “Response” या “Event” की होगी
- प्रमाणीकरण के बाद पैकेट किसी भी दिशा में प्रसारित किए जा सकते हैं

### पैकेट के प्रकार

पैकेट का प्रकार निम्नलिखित कीज़ (keys) के अस्तित्व से निर्धारित होता है:

- Action: AMI से जुड़े क्लाइंट द्वारा किसी विशिष्ट कार्य के लिए भेजा गया पैकेट। क्लाइंट्स के लिए उपलब्ध एक्शन्स का एक सीमित सेट होता है। लोड किए गए मॉड्यूल्स इन एक्शन्स को निर्धारित करते हैं। एक पैकेट में एक्शन का नाम और उसके पैरामीटर्स होते हैं।
- Response: क्लाइंट द्वारा भेजे गए अंतिम एक्शन के जवाब में Asterisk द्वारा भेजा गया रिस्पॉन्स।
- Event: Asterisk कोर या किसी मॉड्यूल द्वारा उत्पन्न इवेंट से संबंधित डेटा।

जब कोई क्लाइंट Action प्रकार के पैकेट भेजता है, तो ActionID नामक एक पैरामीटर शामिल किया जाता है। चूंकि Asterisk से भेजे गए रिस्पॉन्स के क्रम की भविष्यवाणी नहीं की जा सकती है, इसलिए ActionID का उपयोग एक्शन्स और रिस्पॉन्स को सहसंबद्ध (correlate) करने के लिए किया जाता है। Event पैकेट का उपयोग दो अलग-अलग संदर्भों में किया जाता है। पहला, इवेंट्स क्लाइंट को Asterisk में होने वाले परिवर्तनों के बारे में सूचित करते हैं (उदाहरण के लिए, नए बनाए गए चैनल, डिस्कनेक्ट हुए चैनल, या एजेंटों का कतार में लॉग इन और आउट होना)। दूसरा, इवेंट्स का उपयोग क्लाइंट एक्शन के रिस्पॉन्स को ट्रांसपोर्ट करने के लिए किया जाता है।

## उपयोगकर्ताओं और अनुमतियों को कॉन्फ़िगर करना

AMI तक पहुँचने के लिए, एक TCP पोर्ट (आमतौर पर 5038) पर सुनने वाले TCP कनेक्शन को स्थापित करना आवश्यक है। आपको एक उपयोगकर्ता खाता और अनुमतियाँ बनाने के लिए /etc/asterisk/manager.conf फ़ाइल को कॉन्फ़िगर करना होगा। अनुमतियों का एक सीमित सेट है: "read", "write", या दोनों। ये अनुमतियाँ इसमें परिभाषित की गई हैं:

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

### AMI में लॉग इन करना

AMI में लॉग इन करने और प्रमाणित करने के लिए, आपको manager.conf में बनाए गए उपयोगकर्ता नाम और खाते के साथ login प्रकार का एक action पैकेट भेजना होगा।

```
Action:login
Username:admin
Secret:password
```

उदाहरण: php का उपयोग करके AMI में लॉग इन करना

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
?>
```

यदि आपको इवेंट्स प्राप्त करने की आवश्यकता नहीं है, तो आप "Events Off" का उपयोग कर सकते हैं।

```
<?php
$socket = fsockopen("127.0.0.1","5038", $errno, $errstr, $timeout);
fputs($socket, "Action: Login\r\n");
fputs($socket, "UserName: admin\r\n");
fputs($socket, "Secret: senha\r\n\r\n");
fputs($socket, "Events: off\r\n\r\n");
?>
```

### Action पैकेट

जब आप Asterisk को एक action पैकेट भेजते हैं, तो आप action के बाद key:value जोड़े पास करके कुछ अतिरिक्त कुंजियाँ (जैसे, called number) प्रदान कर सकते हैं। dialplan में channel और global वेरिएबल्स को पास करना भी संभव है।

```
Action: <action type><CRLF>
<Key 1>: <Value 1><CRLF>
<Key 2>: <Value 2><CRLF>
Variable: <Variable 1>=<Value 1><CRLF>
Variable: <Variable 2>=<Value 2><CRLF>
...
<CRLF>
```

### Action कमांड्स

उपलब्ध actions की सूची देखने के लिए आप CLI निर्देश manager show commands का उपयोग कर सकते हैं। Asterisk 22 में कमांड्स के मुख्य सेट में शामिल हैं (यह सूची प्रतिनिधि है; लोड किए गए मॉड्यूल्स और अधिक जोड़ते हैं):

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

यदि आपको विशिष्ट कमांड पैरामीटर्स जानने की आवश्यकता है, तो manager show command <command> का उपयोग करें। उदाहरण:

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

### Event पैकेट

जब भी Asterisk में कुछ होता है, तो manager इंटरफ़ेस पर इवेंट्स उत्पन्न होते हैं — एक channel बनाया जाता है या स्थिति बदलता है, दो channels को ब्रिज या अनब्रिज किया जाता है, एक पंजीकरण बदलता है, एक queue सदस्य जोड़ा जाता है, आदि। प्रत्येक इवेंट `Key: value` लाइनों का एक ब्लॉक है जो एक `Event:` हेडर से शुरू होता है।

इवेंट्स का सटीक सेट लोड किए गए मॉड्यूल्स और Asterisk संस्करण पर निर्भर करता है, इसलिए ऐसी सूची को पुन: प्रस्तुत करने के बजाय जो जल्दी ही पुरानी हो जाती है, आधिकारिक सेट के लिए चल रहे सर्वर से क्वेरी करें:

```
asterisk*CLI> manager show events             ; list every event this build can emit
asterisk*CLI> manager show event BridgeEnter  ; describe one event and its fields
```

उदाहरण के लिए, कॉल ब्रिजिंग की रिपोर्ट `BridgeCreate`, `BridgeEnter`, `BridgeLeave`, और `BridgeDestroy` इवेंट्स के माध्यम से दी जाती है (`BridgeEnter` का अर्थ है "जब कोई channel ब्रिज में प्रवेश करता है तो उठाया जाता है")। पुराने `Link`/`Unlink` इवेंट्स को Asterisk 12 में हटा दिया गया था।

## Asterisk Gateway Interface

AGI, वेब सर्वर द्वारा उपयोग किए जाने वाले CGI के समान Asterisk के लिए एक गेटवे इंटरफ़ेस है। यह Asterisk की कार्यक्षमता को बढ़ाने के लिए Perl, PHP, और Python जैसी उच्च-स्तरीय भाषाओं के उपयोग की अनुमति देता है। CGI का मुख्य अनुप्रयोग IVR निर्माण है। AGI के चार प्रकार होते हैं:

- Normal AGI, जो Asterisk बॉक्स के अंदर एक प्रोग्राम को कॉल करता है।
- Fast AGI, जो TCP सॉकेट का उपयोग करके किसी अन्य सर्वर में AGI को कॉल करता है।
- EAGI, जो AGI से साउंड चैनल एक्सेस और नियंत्रण को सक्षम बनाता है।
- DeadAGI, जो hangup() के बाद भी चैनल तक पहुंच प्रदान करता है। आमतौर पर इसे ‘h’ extension में कॉल किया जाता है। ध्यान दें कि Asterisk 22 में `DeadAGI` एप्लिकेशन को deprecated कर दिया गया है — सामान्य `AGI` एप्लिकेशन स्वचालित रूप से एक हैंग-अप चैनल का पता लगाता है और स्क्रिप्ट को "dead" मोड में चलाता है, इसलिए नए dialplan में केवल `AGI()` को कॉल करना चाहिए।

एप्लिकेशन प्रारूप:

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

आप `agi show commands` कमांड का उपयोग करके उपलब्ध AGI कमांड दिखा सकते हैं (नीचे दिया गया आउटपुट प्रतिनिधि है; Asterisk 22 कुछ अतिरिक्त कमांड जोड़ता है):

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

डीबग करने के लिए, agi debug का उपयोग करें।

### AGI का उपयोग करना

इस उदाहरण में, हम php-cli, यानी php कमांड लाइन संस्करण का उपयोग करेंगे। यदि php-cli पहले से इंस्टॉल नहीं है, तो इसे इंस्टॉल करें। php AGI स्क्रिप्ट का उपयोग करने के लिए इन चरणों का पालन करें।

1. सभी AGI स्क्रिप्ट `/var/lib/asterisk/agi-bin` में स्थित होती हैं।
2. निष्पादन (execution) की अनुमति देने के लिए अनुमतियाँ बदलें।

```
chmod 755 *.php
```

3. शेल इंटरफ़ेस (php विशिष्ट)। स्क्रिप्ट की पहली पंक्तियाँ ये होनी चाहिए:

```
#!/usr/bin/php -q
<?php
```

4. I/O चैनल खोलें:

```
$stdin = fopen('php://stdin', 'r');
$stdout = fopen('php://stdout', 'w');
$stdlog = fopen('agi.log', 'w');
```

5. Asterisk आउटपुट प्रबंधित करें। हर बार AGI कॉल होने पर Asterisk जानकारी सेट भेजता है।

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

भेजी गई जानकारी को सहेजें:

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

पिछली स्क्रिप्ट $agi नामक एक ऐरे बनाएगी। उपलब्ध विकल्प हैं:

- agi_request – AGI फ़ाइल का नाम
- agi_channel – AGI ओरिजिनेटिंग चैनल
- agi_language – भाषा सेट
- agi_type – चैनल का प्रकार (जैसे, SIP, DAHDI)
- agi_uniqueid – अद्वितीय पहचानकर्ता
- agi_callerid – CallerID (उदाहरण: Flavio <8590>)
- agi_context – ओरिजिनेटिंग context
- agi_extension – कॉल किए गए extensions
- agi_priority – प्राथमिकता
- agi_accountcode – ओरिजिनेटिंग अकाउंट कोड

agi_extensions नामक वेरिएबल को कॉल करने के लिए, $agi[agi_extensions] का उपयोग करें।

6. चैनल AGI का उपयोग करें। इस बिंदु पर, आप Asterisk से बात करना शुरू कर सकते हैं। AGI को कमांड भेजने के लिए fputs कमांड का उपयोग करें। आप echo कमांड का भी उपयोग कर सकते हैं।

```
fputs($stdout,"SAY NUMBER 4000 '79#' \n");
fflush($stdout);
```

कोट्स (quotes) के उपयोग के बारे में नोट्स:

- AGI कमांड विकल्प वैकल्पिक नहीं हैं
- कुछ विकल्पों को कोट्स में बंद करने की आवश्यकता होती है <escape digits>
- कुछ विकल्पों को कोट्स में बंद नहीं किया जाना चाहिए <digit string>
- कुछ विकल्प दोनों प्रारूपों का उपयोग कर सकते हैं
- आप सिंगल कोट्स का उपयोग कर सकते हैं

चरण 7 – वेरिएबल पास करना: चैनल वेरिएबल को AGI में सेट किया जा सकता है, लेकिन AGI के अंदर उपयोग नहीं किया जा सकता है। निम्नलिखित उदाहरण AGI के अंदर काम नहीं करता है।

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/${EXTEN}"
```

निम्नलिखित उदाहरण काम करता है:

```
SET VARIABLE MY_DIALCOMMAND "PJSIP/4000"
```

चरण 8: Asterisk प्रतिक्रियाएं: Asterisk से प्रतिक्रियाओं को सत्यापित करने के लिए निम्नलिखित आवश्यक है:

```
$msg  = fgets($stdin,1024);
fputs($stdlog,$msg . "\n");
```

चरण 9: लॉक किए गए (zombie) प्रोसेस को समाप्त करें: यदि आपकी स्क्रिप्ट किसी कारण से विफल हो जाती है, तो प्रोसेस हैंग हो जाएगी। दोबारा परीक्षण करने से पहले इसे साफ करने के लिए killproc कमांड का उपयोग करें।

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

DeadAGI का उपयोग तब किया जाता है जब आपके पास लाइव चैनल नहीं होता है। आमतौर पर आप ´h´ extension में DeadAGI निष्पादित करते हैं। Asterisk 22 में `DeadAGI` एप्लिकेशन को deprecated कर दिया गया है और भविष्य के रिलीज़ में इसे हटाया जा सकता है; मानक `AGI` एप्लिकेशन अब हैंग-अप ("dead") चैनलों को स्वचालित रूप से संभालता है, इसलिए नए dialplan में `AGI()` को प्राथमिकता दें।

### FASTAGI

Fast AGI, इनपुट/आउटपुट चैनल के रूप में TCP पोर्ट (डिफ़ॉल्ट रूप से 4573) का उपयोग करके AGI को लागू करता है। FastAGI प्रारूप (agi://) है। उदाहरण के लिए:

```
exten => 0800400001, 1, Agi(agi://192.168.0.1)
```

जब TCP कनेक्शन खो जाता है या डिस्कनेक्ट हो जाता है, तो AGI समाप्त हो जाता है और TCP कनेक्शन बंद हो जाता है, जिसके बाद कॉल डिस्कनेक्ट हो जाती है। यह संसाधन बाहरी सर्वर में स्क्रिप्ट चलाने वाले आपके Asterisk सर्वर से CPU लोड को कम करने के लिए उपयोगी है। आप सोर्स कोड डायरेक्टरी में FastAGI के बारे में अधिक विवरण प्राप्त कर सकते हैं (कृपया “agi/fastagi-test” फ़ाइल देखें)। Asterisk-Java लाइब्रेरी Java के लिए एक FastAGI सर्वर कार्यान्वयन प्रदान करती है। अधिक जानकारी के लिए, https://github.com/asterisk-java/asterisk-java देखें।

ARI, आधुनिक REST/WebSocket इंटरफ़ेस, का अपना अध्याय आगे है।

## सोर्स कोड में बदलाव करना

Asterisk को C भाषा (C++ नहीं) में विकसित किया गया है। C प्रोग्रामिंग सिखाना इस दस्तावेज़ के दायरे से बाहर है। यदि आप रुचि रखते हैं, तो आपको https://docs.asterisk.org पर संबंधित दस्तावेज़ मिल जाएंगे, जो Asterisk में पैच लागू करने और बनाने के तरीके के साथ-साथ मुख्य रूप से Doxygen सॉफ़्टवेयर द्वारा जनरेट किए गए API दस्तावेज़ों पर अच्छे सुझाव प्रदान करते हैं। जो लोग C प्रोग्रामिंग से परिचित हैं, उनके लिए एप्लिकेशन के सोर्स कोड को बदलना Asterisk का विस्तार करने का सबसे शक्तिशाली (और खतरनाक) तरीका हो सकता है।

## सारांश

इस अध्याय में, आपने सीखा है कि Asterisk PBX के साथ बाहरी प्रोग्रामों को कैसे इंटरफ़ेस किया जाए। हमने Linux शेल से Asterisk कंसोल तक कमांड भेजने के लिए `asterisk –rx` के साथ शुरुआत की। इसके बाद, हमने `System()` एप्लिकेशन के बारे में सीखा, जो dialplan से किसी बाहरी प्रोग्राम को कॉल करने की अनुमति देता है। AMI, पारंपरिक PBXs में सामान्य CTI इंटरफ़ेस के सबसे करीब का इंटरफ़ेस है। dialplan से किसी एप्लिकेशन को कॉल करने के लिए, हमने AGI का उपयोग किया, जिसके विभिन्न प्रकारों की जानकारी ली: मृत चैनलों (dead channels) के लिए DeadAGI, ऑडियो स्ट्रीमिंग को संभालने के लिए EAGI, इनपुट/आउटपुट इंटरफ़ेस के रूप में TCP सॉकेट का उपयोग करने के लिए Fast AGI, और उसी Asterisk बॉक्स के भीतर स्क्रिप्ट को कॉल करने और संसाधित करने के लिए सामान्य AGI। अगला अध्याय ARI को समर्पित है, जो आधुनिक REST/WebSocket API है और बाहरी एप्लिकेशन को Asterisk चैनलों और ब्रिजों का पूर्ण नियंत्रण देता है।

## प्रश्नोत्तरी

1. निम्नलिखित में से कौन सा Asterisk के लिए इंटरफेसिंग विधि नहीं है?
   - A. AMI
   - B. AGI
   - C. `asterisk -rx`
   - D. System()
   - E. External()
2. AMI, TCP सॉकेट पर Asterisk कमांड भेजने की अनुमति देता है, और यह इंटरफेस एक नए Asterisk इंस्टॉलेशन में डिफ़ॉल्ट रूप से सक्षम होता है।
   - A. सही
   - B. गलत
3. AMI बहुत सुरक्षित है, क्योंकि इसका प्रमाणीकरण (authentication) MD5 चैलेंज/रिस्पॉन्स का उपयोग करता है।
   - A. सही
   - B. गलत
4. FastAGI, dialplan को TCP सॉकेट (आमतौर पर पोर्ट 4573) पर किसी अन्य मशीन पर बाहरी स्क्रिप्ट कॉल करने की सुविधा देता है।
   - A. सही
   - B. गलत
5. DeadAGI का उपयोग सक्रिय चैनलों पर किया जाता है। इसका उपयोग DAHDI चैनलों पर किया जा सकता है लेकिन SIP या IAX चैनलों पर नहीं।
   - A. सही
   - B. गलत
6. AGI केवल स्क्रिप्टिंग भाषा के रूप में PHP का समर्थन करता है।
   - A. सही
   - B. गलत
7. कमांड ___ सभी उपलब्ध AGI कमांड दिखाता है।
8. कमांड ___ सभी उपलब्ध AMI कमांड दिखाता है।
9. AMI एक्शन पैकेट में, क्लाइंट कौन सा हेडर शामिल करता है ताकि Asterisk से वापस आने वाले एसिंक्रोनस रिस्पॉन्स और इवेंट्स को उस एक्शन के साथ जोड़ा जा सके जिसने उन्हें ट्रिगर किया था?
   - A. `ActionID`
   - B. `Variable`
   - C. `Secret`
   - D. `Event`
10. `Originate` एक्शन चलाने और आउटबाउंड कॉल करने के लिए उपयोगकर्ता के पास कौन सा AMI manager.conf अनुमति वर्ग (permission class) होना चाहिए?
    - A. `originate`
    - B. `verbose`
    - C. `log`
    - D. `reporting`

**उत्तर:** 1 — E · 2 — B · 3 — B · 4 — A · 5 — B · 6 — B · 7 — `agi show commands` · 8 — `manager show commands` · 9 — A · 10 — A
