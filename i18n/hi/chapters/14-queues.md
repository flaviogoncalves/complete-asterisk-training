# Call Queues

Call queues, जिन्हें ACD (Automatic Call Distribution) के रूप में भी जाना जाता है, ग्राहकों की कॉलों का कुशलतापूर्वक उत्तर देने के लिए तेजी से महत्वपूर्ण होते जा रहे हैं। एक automatic call distributor लागत कम करने, सेवा बढ़ाने और बिक्री में सुधार करने में मदद कर सकता है क्योंकि call distributors इस बात को प्रभावित करते हैं कि आपका व्यवसाय कैसे काम करता है—कुछ दिनों के लिए नहीं, बल्कि कई वर्षों के लिए। एक call center के वातावरण में, सबसे महत्वपूर्ण कारक लोग हैं; वे सबसे महंगे संसाधन हैं। एजेंटों को काम पर रखने, प्रशिक्षित करने और प्रेरित करने में समय, पैसा और धैर्य लगता है। एक ACD के साथ, आप आवश्यक एजेंटों की संख्या को सटीक रूप से निर्धारित करके, अच्छे और खराब अटेंडेंट्स को नियंत्रित करके, और call flow का विश्लेषण करके एजेंटों की उत्पादकता को अधिकतम कर सकते हैं।

## Objectives

इस अध्याय के अंत तक, आप निम्नलिखित में सक्षम होंगे:

- यह समझना कि call queues का उपयोग क्यों और कैसे किया जाता है
- call queues के मूल सिद्धांत को समझना
- queue सिस्टम को इंस्टॉल और कॉन्फ़िगर करना

## How queues work?

Call queues कोई नई बात नहीं है। जब आपके पास इनबाउंड कॉल का प्रवाह अधिक होता है, तो कॉल्स को उचित रूप से वितरित करना कठिन होता है। एक ग्रुप स्ट्रेटेजी का उपयोग करना जहाँ फोन सभी agents पर एक साथ बजता है, तब तक काम नहीं करता जब तक कि आपके पास केवल कुछ ही agents न हों। हालाँकि, एक call queue हर बार केवल एक उपलब्ध agent को कॉल डिलीवर करेगी और जब कोई agent उपलब्ध नहीं होगा, तो ग्राहक को music on hold पर रखेगी। Queue कॉल को तब तक बनाए रखकर काम करती है जब तक कि कॉल का उत्तर देने के लिए कोई खाली agent न मिल जाए। Queue का सबसे बड़ा लाभ यह है कि यह कॉल खोने से बचाती है और साथ ही आँकड़े (statistics) उत्पन्न करने की संभावना भी प्रदान करती है।

![A call queue: incoming 1-800 calls enter the queue and an ACD strategy (ringall, rrmemory, leastrecent, priority, and others) distributes them to the available agents](../images/14-queues-fig01.png)

आमतौर पर, एक call queue इस तरह काम करती है:

- Agents queue में लॉग इन करते हैं।
- आने वाली कॉल्स को queue में रखा जाता है।
- कॉल्स को agents तक भेजने के लिए उन्हें वितरित करने वाली एक queuing strategy का उपयोग किया जाता है।
- जब कॉलर प्रतीक्षा करता है तो music on hold बजाया जाता है।
- कॉलर्स को घोषणाएं (announcements) की जा सकती हैं, जो उन्हें प्रतीक्षा समय के बारे में सूचित करती हैं।
- कॉल का उत्तर agent द्वारा दिया जाता है और आँकड़े उत्पन्न किए जाते हैं।

Queues के लिए मुख्य एप्लिकेशन ग्राहक सेवा (customer service) है। Queues का उपयोग करते समय, आप अपने agents के व्यस्त होने पर कॉल खोने से बचते हैं। यदि आप पाते हैं कि queue में कॉलर्स की संख्या बढ़ रही है, तो आप queue में नए agents जोड़ सकते हैं। Queues का एक और लाभ यह है कि अब आपके पास call abandon rate, average call duration, और call answering target जैसे आँकड़े हो सकते हैं। ये आँकड़े आपको यह निर्धारित करने में मदद करेंगे कि अपने ग्राहकों को बेहतर सेवा प्रदान करने के लिए कितने agents का उपयोग करना है।

### ACD architecture

ACD architecture queues और agents द्वारा बनता है। एक agent एक ही समय में दो queues में हो सकता है। एक queue में agents, channels, और agent groups हो सकते हैं।

![ACD architecture: each queue (Customer Service, Inside Sales) is fed by a phone number and delivers calls to agents, who are in turn bound to physical channels](../images/14-queues-fig02.png)

## Queues

Queues को queues.conf कॉन्फ़िगरेशन फ़ाइल में परिभाषित किया जाता है। Agents वे अटेंडेंट होते हैं जो लॉग इन करते हैं और queues के सदस्य होते हैं। Agents को agents.conf फ़ाइल में परिभाषित किया जाता है। कई रिलीज़ के दौरान queue सिस्टम काफ़ी विकसित हुआ है, जिससे इसकी कॉन्फ़िगरेशन फ़ाइल विस्तृत हो गई है। हम कुछ प्रमुख पैरामीटर्स की व्याख्या करेंगे। एक सामान्य पैरामीटर जिसे हाइलाइट करना उचित है, वह है `autofill`:

```
autofill=yes
```

queue के लिए पुराना व्यवहार serial प्रकार का था। queue अगले agent को कॉल भेजने से पहले कॉल के डिस्पैच होने का इंतज़ार करती थी। यदि किसी agent को कॉल का उत्तर देने में 15 सेकंड लगते थे, तो queue में मौजूद अन्य कॉल्स को तब तक इंतज़ार करना पड़ता था जब तक कि उस कॉल का उत्तर न मिल जाए। उच्च-वॉल्यूम वाली queues के लिए, यह व्यवहार अक्षम था। नया व्यवहार autofill=yes कॉल के उत्तर दिए जाने तक इंतज़ार नहीं करता, बल्कि समानांतर (parallel) रूप से काम करता है। आप mixmonitor विकल्प का उपयोग करके queue में कॉल्स को रिकॉर्ड कर सकते हैं। इस मोड में, कॉल्स को एक ही समय में रिकॉर्ड और मिक्स किया जाता है।

### Queue कॉन्फ़िगरेशन फ़ाइल

Queues को queues.conf फ़ाइल में कॉन्फ़िगर किया जाता है। चित्र में, आपको एक queue का कार्यशील उदाहरण मिलेगा।

![queues.conf फ़ाइल का एक कार्यशील उदाहरण, जो general सेक्शन और strategy, service level, announcements, recording, और members के साथ एक customerservice queue को दर्शाता है](../images/14-queues-fig03.png)

### Agents

आप अपने agents को agents.conf फ़ाइल में कॉन्फ़िगर कर सकते हैं। Agents कॉल प्राप्त करने के लिए किसी भी extension से लॉग इन कर सकते हैं। आप निम्न का उपयोग करके एक agent को डायल कर सकते हैं:

```
Dial(agent/<name>)
```

#### Agent login

Agent 300 के लिए लॉगिन फ़्लो इस प्रकार काम करता है:

- उपयोगकर्ता एक ऐसे extension को डायल करता है जो `AgentLogin()` एप्लिकेशन चलाता है।
- `AgentLogin()` निष्पादित होता है और agent वर्तमान channel के साथ जुड़ जाता है।
- आप `agent show all` कमांड का उपयोग करके agents की स्थिति की जाँच कर सकते हैं।

![Agents: एक उपयोगकर्ता एक ऐसे extension को डायल करके लॉग इन करता है जो agentlogin एप्लिकेशन चलाता है, जो Agent 300 को वर्तमान channel से जोड़ता है; आप `agent show all` के साथ agent की स्थिति की जाँच कर सकते हैं](../images/14-queues-fig04.png)

आप agents को agents.conf फ़ाइल में परिभाषित कर सकते हैं

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

### Members

Members वे सक्रिय channels हैं जो queue को प्रतिक्रिया देते हैं। Members सीधे channels (PJSIP, DAHDI) या वे agents हो सकते हैं जो कॉल प्राप्त करने से पहले लॉग इन करते हैं।


### Strategies

कॉल्स को इन रणनीतियों (strategies) में से एक के अनुसार members के बीच वितरित किया जाता है:

- ringall: उपलब्ध सभी channels को तब तक रिंग करता है जब तक कोई उत्तर न दे दे।
- leastrecent: सबसे कम हाल ही में कॉल प्राप्त करने वाले member को वितरित करता है।
- fewestcalls: सबसे कम कॉल्स वाले member को वितरित करता है।
- random: यादृच्छिक (random) इंटरफ़ेस को रिंग करता है।
- wrandom: यादृच्छिक इंटरफ़ेस को रिंग करता है, लेकिन उनके मेट्रिक की गणना करते समय member की पेनल्टी को वेट (weight) के रूप में उपयोग करता है।
- rrmemory: मेमोरी के साथ round robin का उपयोग करता है; यह याद रखता है कि पिछली बार कॉल के साथ यह कहाँ रुका था।
- rrordered: rrmemory के समान, सिवाय इसके कि कॉन्फ़िगरेशन फ़ाइल से queue member का क्रम संरक्षित रहता है।
- linear: queues.conf में सूचीबद्ध क्रम में members को रिंग करता है; डायनामिक members के लिए, उस क्रम में जिसमें उन्हें जोड़ा गया था।

पुरानी `roundrobin` रणनीति को Asterisk 1.4 में ही हटा (deprecated) दिया गया था। यह अब एक प्रलेखित रणनीति नहीं है और इसका उपयोग नहीं किया जाना चाहिए: Asterisk 22 में पार्सर अभी भी `roundrobin` शब्द को स्वीकार करता है, लेकिन केवल एक बैकवर्ड-कम्पैटिबिलिटी उपनाम के रूप में जो `rrmemory` पर मैप होता है। इसके बजाय स्पष्ट रूप से `rrmemory` (या `rrordered`) का उपयोग करें। उपरोक्त सूची Asterisk 22 `queues.conf` में `strategy` विकल्प के लिए प्रलेखित रणनीतियों का समूह है।

## Agents

Agents को प्रॉक्सी चैनल्स के रूप में कार्यान्वित किया जाता है। इनका उपयोग queues के अंदर किया जा सकता है। एजेंट चैनल्स का एक और उपयोग extension mobility है। उपयोगकर्ता किसी भी फोन का उपयोग करके लॉग इन कर सकता है और अपनी कॉल प्राप्त कर सकता है। यह उपयोगकर्ता को किसी भी कमरे में जाकर उसे अपना कार्यालय बनाने की सुविधा देता है। आप dialplan में dial(agent/<name>) का उपयोग करके किसी एजेंट को डायल कर सकते हैं। आप agents.conf फाइल में एजेंट्स को परिभाषित करते हैं।

![Agent mobility: उपयोगकर्ता किसी भी फोन को उठाता है, एक लॉगिन extension डायल करता है, और एजेंट नंबर तथा पासवर्ड दर्ज करता है; agentlogin() के सफल होने के बाद एजेंट (Agent 300) कॉल लेने के लिए तैयार हो जाता है, और आप CLI कमांड `agent show all` के साथ स्थिति की जांच कर सकते हैं](../images/14-queues-fig05.png)

### Agent Groups

आप एजेंट ग्रुप्स का उपयोग करना चुन सकते हैं। यह फंक्शन ACD रणनीतियों को ध्यान में नहीं रखता है। आप संभवतः सभी एजेंट्स को व्यक्तिगत रूप से सूचीबद्ध करना पसंद करेंगे। यदि आप किसी एजेंट ग्रुप में ट्रांसफर करना चाहते हैं, तो आप `queues.conf` का उपयोग कर सकते हैं:

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### The configuration file for agents

एजेंट्स को agents.conf फाइल में परिभाषित किया गया है। नीचे फाइल का एक कार्यशील उदाहरण दिया गया है।

![agents.conf फाइल का एक कार्यशील उदाहरण: persistentagents के साथ एक general सेक्शन, डिफ़ॉल्ट पैरामीटर्स (autologoff, ackcall, endcall, wrapuptime, musiconhold) के साथ एक agents सेक्शन, और दो एजेंट परिभाषाएँ (300 और 301)](../images/14-queues-fig06.png)

## ACD-संबंधित एप्लिकेशन

Asterisk कतार प्रणाली dialplan में कतारों को लागू करने के लिए कई एप्लिकेशन उपलब्ध कराती है। नीचे, हम उनमें से कुछ को दर्शाते हैं।

### एप्लिकेशन queue()

यह एप्लिकेशन आने वाली कॉल्स को queues.conf में परिभाषित एक विशिष्ट कॉल कतार में डालती है। विकल्प स्ट्रिंग में शून्य या अधिक एकल-अक्षर वाले विकल्प (नीचे चित्र में दिखाए गए हैं) हो सकते हैं। कॉल ट्रांसफर करने के अलावा, एक कॉल को पार्क किया जा सकता है और फिर किसी अन्य उपयोगकर्ता द्वारा उठाया जा सकता है। यदि चैनल इसका समर्थन करता है, तो वैकल्पिक URL को कॉल प्राप्त करने वाले पक्ष को भेजा जाएगा। वैकल्पिक AGI पैरामीटर एक AGI स्क्रिप्ट सेट करेगा जिसे कॉलिंग पार्टी के चैनल पर निष्पादित किया जाएगा, एक बार जब वे कतार के सदस्य से जुड़ जाते हैं। टाइमआउट के कारण कतार एक निर्दिष्ट सेकंड के बाद विफल हो जाएगी, जिसे प्रत्येक टाइमआउट और पुनः प्रयास चक्र के बीच जांचा जाता है। यह एप्लिकेशन पूरा होने पर QUEUE स्थिति चर सेट करता है:

![queue() एप्लिकेशन: इसका सिंटैक्स `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — Asterisk 22 तर्कों को अल्पविराम से अलग करता है (पुराना पाइप `|` फॉर्म अब समाप्त हो गया है) — और उपलब्ध एकल-अक्षर विकल्प (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### एप्लिकेशन agentlogin()

यह एप्लिकेशन एजेंट को सिस्टम में लॉग इन करने के लिए कहती है। यह हमेशा -1 लौटाती है। लॉग इन रहने के दौरान, कॉल प्राप्त करने वाले एजेंट को नई कॉल आने पर बीप सुनाई देगी। एजेंट * कुंजी दबाकर कॉल को डंप कर सकता है।

![agentlogin() एप्लिकेशन: इसका सिंटैक्स `AgentLogin([AgentNo][|options])` और साइलेंट लॉगिन के लिए `s` विकल्प जो लॉगिन पुष्टिकरण की घोषणा नहीं करता है](../images/14-queues-fig08.png)

### एप्लिकेशन addQueueMember()

यह एप्लिकेशन गतिशील रूप से एक डिवाइस (जैसे, PJSIP/3000) को कतार में जोड़ती है। यदि डिवाइस पहले से मौजूद है, तो यह एक त्रुटि लौटाएगी।

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### एप्लिकेशन removeQueueMember()

यह एप्लिकेशन गतिशील रूप से एक डिवाइस को कतार से हटाती है। यदि डिवाइस कतार से संबंधित नहीं है, तो यह एक त्रुटि लौटाएगी।

```
RemoveQueueMember(queuename[|interface])
```

### सपोर्ट एप्लिकेशन और CLI कमांड

कुछ एप्लिकेशन और कंसोल कमांड कतारों के साथ काम करने में मदद करने में सक्षम हैं। निम्नलिखित रूपरेखा बताती है कि प्रत्येक एप्लिकेशन क्या करती है:

![सपोर्ट एप्लिकेशन (AddQueueMember, RemoveQueueMember) और CLI कमांड (agent show all, queue show, queue show <name>) जिनका उपयोग रनटाइम पर कतारों को प्रबंधित करने के लिए किया जाता है](../images/14-queues-fig09.png)

## कॉन्फ़िगरेशन कार्य

नीचे दिया गया चित्र एक कार्यशील कतार (queue) प्रणाली बनाने के मुख्य कार्यों का सारांश प्रस्तुत करता है।

![ACD कॉन्फ़िगरेशन कार्य: (1) कॉल कतार बनाना (आवश्यक), (2) एजेंट पैरामीटर परिभाषित करना (वैकल्पिक), (3) एजेंट बनाना (वैकल्पिक), (4) dialplan में कतार डालना (आवश्यक), (5) एजेंट रिकॉर्डिंग कॉन्फ़िगर करना (वैकल्पिक), और (6) agent show all और queue show के साथ सत्यापित करना (वैकल्पिक)](../images/14-queues-fig10.png)

चरण 1: queues.conf फ़ाइल में कॉल कतार बनाएँ:

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

चरण 2: agents.conf फ़ाइल में एजेंट पैरामीटर परिभाषित करें:

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

चरण 3: agents.conf फ़ाइल में एजेंट बनाएँ:

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

चरण 4: `extensions.conf` फ़ाइल में dialplan के भीतर कतार डालें:

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

### कतार रिकॉर्डिंग कॉन्फ़िगर करें

Asterisk के MixMonitor एप्लिकेशन का उपयोग करके कॉल रिकॉर्ड की जा सकती हैं। (स्टैंडअलोन Monitor एप्लिकेशन को Asterisk 22 में हटा दिया गया था, और queues.conf का `monitor-type` विकल्प अब केवल MixMonitor को स्वीकार करता है।) रिकॉर्डिंग को कतार एप्लिकेशन के भीतर से सक्षम किया जा सकता है, जो तब शुरू होती है जब कॉल वास्तव में पिक अप की जाती है। केवल सफल कॉल ही रिकॉर्ड की जाती हैं, और जब लोग MOH सुन रहे होते हैं तो कोई रिकॉर्डिंग नहीं की जाती है। मॉनिटरिंग सक्षम करने के लिए, बस monitor-format निर्दिष्ट करें। यह सुविधा अन्यथा अक्षम रहती है। आप `Set(MONITOR_FILENAME=<filename>)` का उपयोग करके रिकॉर्डिंग के लिए फ़ाइल नाम सेट कर सकते हैं; अन्यथा यह `MONITOR_FILENAME=${UNIQUEID}` का उपयोग करेगा।

queues.conf फ़ाइल में:

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## Queue operation

निम्नलिखित उदाहरण यह समझाते हैं कि queue का उपयोग कैसे किया जाता है।

1. Agent login. उदाहरण: टेलीमार्केटिंग queue में एक agent फोन उठाता है और #9000 डायल करता है। agent को एक अमान्य लॉगिन संदेश सुनाई देता है और उससे उसका नाम और पासवर्ड मांगा जाता है। ऑडिटिंग queue भी इसी प्रक्रिया का पालन करती है।
2. Queue. एक बार queue में आने के बाद, यदि परिभाषित किया गया है तो agent को MOH सुनाई देगा। जब टेलीमार्केटिंग queue में कोई कॉल आती है, तो agent को एक बीप सुनाई देगी और उसे उस कॉल से जोड़ दिया जाएगा।
3. Call ending. जब agent कॉल समाप्त करता है, तो वह:
   - डिस्कनेक्ट करने और queue में बने रहने के लिए ‘*’ दबा सकता है।
   - फोन डिस्कनेक्ट कर सकता है, जिससे वह queue से डिस्कनेक्ट हो जाएगा।
   - ऑडिटिंग के लिए कॉल ट्रांसफर करने हेतु #8000 दबा सकता है।

## उन्नत संसाधन

Asterisk कतार प्रणाली में कुछ उन्नत सुविधाएँ हैं जो कुछ ग्राहकों और एजेंटों को प्राथमिकता देने के साथ-साथ उपयोगकर्ता मेनू को सक्षम करने की अनुमति देती हैं।

### उपयोगकर्ता मेनू

आप एक-अंकीय extension का उपयोग करके कतार में प्रतीक्षा करते समय उपयोगकर्ता के लिए एक मेनू परिभाषित कर सकते हैं। इस विकल्प को सक्षम करने के लिए, queues.conf कतार कॉन्फ़िगरेशन में एक context परिभाषित करें।

### पेनल्टी

एजेंटों को एक पेनल्टी के साथ कॉन्फ़िगर किया जा सकता है। एक कतार सबसे पहले कम पेनल्टी मान वाले उपयोगकर्ताओं को कॉल भेजेगी। उदाहरण के लिए, चूंकि हम जानते हैं कि हमारे ग्राहक Susan और उसकी मधुर आवाज़ को पसंद करते हैं, इसलिए हम उसे प्राथमिकता 0 सौंपना चुन सकते हैं। वैकल्पिक रूप से, Uber नाम का एजेंट, जिसके पास कम अनुभव है, ग्राहक सेवा के लिए कम पसंद किया जाता है; इसलिए, हम इस एजेंट को प्राथमिकता 10 सौंपते हैं। queues.conf फ़ाइल में:

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### प्राथमिकता

कतारें FIFO (फर्स्ट इन फर्स्ट आउट) मोड में काम करती हैं। यदि आप विशेष ग्राहकों (प्लैटिनम, गोल्ड) के लिए प्राथमिकता देना चाहते हैं, तो आप विभेदित प्राथमिकताएं सेट कर सकते हैं। प्लैटिनम या गोल्ड ग्राहकों के लिए:

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

ब्लू ग्राहकों के लिए:

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## application agentcallbacklogin() को हटा दिया गया है

application `agentcallbacklogin()` को Digium द्वारा Asterisk 1.4 (जुलाई 2006) में deprecated कर दिया गया था और यह अब Asterisk 22 में उपलब्ध नहीं है। अनुशंसित तरीका यह है कि एक queue में गतिशील रूप से callback-style सदस्यों को जोड़ने के लिए PJSIP इंटरफ़ेस के साथ `AddQueueMember()` का उपयोग किया जाए। माइग्रेशन मार्गदर्शन के लिए पुराने Asterisk `/doc` निर्देशिकाओं में `queues-with-callback-members.txt` दस्तावेज़ शामिल किया गया था।

पुराने `chan_agent` channel driver को भी इसी तरह हटा दिया गया था; इसकी कार्यक्षमता को `app_agent_pool` मॉड्यूल के रूप में फिर से लिखा गया था, जो Asterisk 22 में `AgentLogin()`, `AgentRequest()` और `AGENT()` dialplan function प्रदान करता है (ये अभी भी मौजूद हैं — `app_agent_pool.so` एक स्टॉक 22 बिल्ड के साथ आता है)। आधुनिक call centers के लिए, हालांकि, मानक पैटर्न यह है कि agent channels को पूरी तरह से छोड़ दिया जाए और agent के PJSIP device को सीधे `AddQueueMember()`/`RemoveQueueMember()` के साथ queue में जोड़ा जाए (`queues.conf` में स्थिर रूप से, या dialplan या AMI से गतिशील रूप से)। यह सरल है, PJSIP device state के साथ स्पष्ट रूप से एकीकृत होता है, और यही वह दृष्टिकोण है जिसका उपयोग इस अध्याय में किया गया है।

## Queue statistics

Queue से संबंधित सभी इवेंट्स /var/log/asterisk/queue_log में लॉग किए जाते हैं। Queue log का प्रारूप Asterisk डॉक्यूमेंटेशन की /doc डायरेक्टरी में queuelog.txt डॉक्यूमेंट में प्रकाशित किया गया है। नीचे लॉग किए गए कुछ सबसे महत्वपूर्ण इवेंट्स दिए गए हैं।

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

आप इन इवेंट्स को प्रोसेस करने के लिए अपनी खुद की यूटिलिटी बना सकते हैं या उपयोग के लिए तैयार सांख्यिकी पैकेज का उपयोग कर सकते हैं:

- **QueueMetrics** (<https://www.queuemetrics.com/>) – एक कमर्शियल, सक्रिय रूप से मेंटेन किया जाने वाला पैकेज जो `queue_log` को पार्स करता है और Asterisk कॉल सेंटर्स के लिए सबसे पूर्ण रिपोर्टिंग टूल्स में से एक बना हुआ है।
- **Roll your own** – क्योंकि ऊपर दिया गया `queue_log` प्रारूप स्थिर और अच्छी तरह से प्रलेखित (documented) है, इसलिए इसे एक छोटी स्क्रिप्ट (Python, आदि) के साथ पार्स करना और इवेंट्स को डेटाबेस या डैशबोर्ड में फीड करना सीधा और सरल है।

`queue_log` को टेल (tail) करने की तुलना में अधिक इवेंट-संचालित दृष्टिकोण के लिए, **Asterisk REST Interface (ARI)** और **AMI** `QueueSummary`/`QueueStatus` क्रियाएं आपको वास्तविक समय (real-time) में queue की स्थिति के आधार पर लाइव queue डैशबोर्ड और कस्टम इंटीग्रेशन बनाने की सुविधा देती हैं, न कि बाद में लॉग पार्सिंग के माध्यम से। Asterisk 22 में इस प्रकार के कार्य के लिए ARI आधुनिक और समर्थित इंटीग्रेशन इंटरफेस है।

## सारांश

इस अध्याय में आपने सीखा है कि ACD का उपयोग कैसे किया जाता है, इसकी वास्तुकला क्या है, और इसे कॉन्फ़िगर कैसे किया जाता है। प्राथमिकताओं (priorities) और दंड (penalties) जैसी कुछ उन्नत सुविधाओं को भी प्रस्तुत किया गया था।

## प्रश्नोत्तरी

1. निम्नलिखित में से कौन सी `queues.conf` में वैध कतार वितरण रणनीतियाँ (queue distribution strategies) हैं (सभी लागू विकल्पों को चुनें)?
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. आप `queues.conf` फ़ाइल में ___ विकल्प सेट करके कतार के भीतर एक एजेंट और ग्राहक के बीच बातचीत को रिकॉर्ड कर सकते हैं।
3. कौन सी `strategy` सदस्यों को ठीक उसी क्रम में रिंग करती है जिस क्रम में वे `queues.conf` में सूचीबद्ध हैं?
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. टेलीमार्केटिंग उदाहरण में जब एजेंट कॉल समाप्त करता है, तो वे कौन सी क्रियाएं कर सकते हैं (सभी लागू विकल्पों को चुनें)?
   - A. डिस्कनेक्ट करने और कतार में बने रहने के लिए `*` दबाएं
   - B. फ़ोन रखें और कतार से डिस्कनेक्ट हो जाएं
   - C. ऑडिटिंग के लिए कॉल ट्रांसफर करने हेतु `#8000` दबाएं
   - D. सभी कतारों से तुरंत लॉग ऑफ करने के लिए `#` दबाएं
5. एक कार्यशील कतार प्राप्त करने के लिए कौन से दो कार्य *आवश्यक* हैं (सभी लागू विकल्पों को चुनें)?
   - A. कतार बनाएं
   - B. एजेंट बनाएं
   - C. एजेंट पैरामीटर कॉन्फ़िगर करें
   - D. रिकॉर्डिंग कॉन्फ़िगर करें
   - E. कतार को dial plan में डालें
6. कॉल कतार में आप प्रतीक्षा करते समय कॉलर को एक सिंगल-डिजिट मेनू प्रदान कर सकते हैं। यह कतार के `queues.conf` अनुभाग में एक ___ को परिभाषित करके सक्षम किया जाता है:
   - A. agent
   - B. menu
   - C. context
   - D. application
7. सपोर्ट एप्लिकेशन `AddQueueMember()` और `RemoveQueueMember()` का उपयोग रनटाइम पर सदस्यों को जोड़ने या हटाने के लिए ___ में किया जाता है:
   - A. dial plan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. चूंकि Asterisk 21 में chan_sip को हटा दिया गया था, इसलिए एक स्टेटिक कतार सदस्य को `SIP/1001` के बजाय ___ जैसे चैनल का संदर्भ देना चाहिए।
9. `wrapuptime` पैरामीटर वह न्यूनतम समय है जिसके बाद एक एजेंट के कॉल डिस्कनेक्ट करने पर कतार उस एजेंट को एक नई कॉल भेजेगी।
   - A. True
   - B. False
10. `Queue()` को कॉल करने से पहले `QUEUE_PRIO` चैनल वेरिएबल सेट करके कॉलर को उसी कतार में उच्च स्थान दिया जा सकता है।
    - A. True
    - B. False

**उत्तर:** 1 — A, C, D, E, F (roundrobin एक प्रलेखित रणनीति नहीं है; Asterisk 22 में यह केवल rrmemory के लिए एक अप्रचलित उपनाम के रूप में जीवित है) · 2 — `monitor-format` (कतार से रिकॉर्डिंग `monitor-format` निर्दिष्ट करके सक्षम की जाती है; Asterisk 22 में `monitor-type` केवल MixMonitor का समर्थन करता है) · 3 — C (linear) · 4 — A, B, C (`*` डिस्कनेक्ट करता है और बना रहता है; `#` लॉग-ऑफ-ऑल कुंजी नहीं है) · 5 — A, E · 6 — C (`context` विकल्प) · 7 — A (dial plan) · 8 — `PJSIP/1001` (कोई भी `PJSIP/` इंटरफ़ेस) · 9 — True · 10 — True
