# طوابير المكالمات

أصبحت طوابير المكالمات، المعروفة أيضاً باسم ACD (توزيع المكالمات التلقائي)، تكتسب أهمية متزايدة للرد على مكالمات العملاء بكفاءة. يمكن لموزع المكالمات التلقائي أن يساعد في خفض التكاليف، وزيادة مستوى الخدمة، وتحسين المبيعات، حيث تؤثر موزعات المكالمات على كيفية عمل نشاطك التجاري — ليس لبضعة أيام فحسب، بل لسنوات عديدة. في بيئة مراكز الاتصال، العامل الأول والأهم هو العنصر البشري؛ فهم المورد الأكثر تكلفة. يتطلب توظيف وتدريب وتحفيز الوكلاء وقتاً ومالاً وصبراً. باستخدام ACD، يمكنك زيادة إنتاجية الوكلاء إلى أقصى حد من خلال تحديد عدد الوكلاء المطلوب بدقة، ومراقبة أداء الموظفين الجيد والسيئ، وتحليل تدفق المكالمات.

## الأهداف

بحلول نهاية هذا الفصل، ينبغي أن تكون قادراً على:

- فهم سبب وكيفية استخدام طوابير الانتظار (call queues)
- فهم النظرية الأساسية لطوابير الانتظار
- تثبيت وتهيئة نظام الطوابير

## كيف تعمل طوابير الانتظار؟

طوابير الانتظار للمكالمات ليست بالأمر الجديد تماماً. عندما يكون لديك تدفق عالٍ للمكالمات الواردة، يصبح من الصعب توزيع المكالمات بشكل مناسب. إن استخدام استراتيجية المجموعة حيث ترن الهواتف في وقت واحد لدى جميع الوكلاء لا يبدو فعالاً، إلا إذا كان لديك عدد قليل فقط من الوكلاء. ومع ذلك، فإن طابور انتظار المكالمات يقوم بتوصيل المكالمات إلى وكيل واحد متاح في كل مرة، ويضع العميل في حالة انتظار مع تشغيل موسيقى في حال عدم توفر وكلاء. يعمل الطابور عن طريق الاحتفاظ بالمكالمة أثناء البحث عن وكيل غير مشغول للرد عليها. إحدى أكبر فوائد الطابور هي تجنب فقدان المكالمات مع توفير إمكانية إنشاء إحصائيات.

![طابور انتظار المكالمات: المكالمات الواردة عبر 1-800 تدخل الطابور وتقوم استراتيجية ACD (مثل ringall، وrrmemory، وleastrecent، وpriority، وغيرها) بتوزيعها على الوكلاء المتاحين](../images/14-queues-fig01.png)

عادةً، يعمل طابور انتظار المكالمات على النحو التالي:

- يقوم الوكلاء بتسجيل الدخول إلى الطابور.
- يتم وضع المكالمات الواردة في الطابور.
- تُستخدم استراتيجية طابور لتوزيع المكالمات وإرسالها إلى الوكلاء.
- يتم تشغيل موسيقى الانتظار بينما ينتظر المتصل.
- يمكن تقديم إعلانات للمتصلين لإخطارهم بوقت الانتظار.
- يتم الرد على المكالمة من قبل الوكيل وتُنشأ الإحصائيات.

التطبيق الرئيسي للطوابير هو خدمة العملاء. عند استخدام الطوابير، تتجنب فقدان المكالمات عندما يكون وكلاؤك مشغولين. يمكنك إضافة وكلاء جدد إلى الطابور إذا وجدت أن عدد المتصلين في الطابور في تزايد. ميزة أخرى للطوابير هي أنه يمكنك الآن الحصول على إحصائيات مثل معدل التخلي عن المكالمات، ومتوسط مدة المكالمة، وهدف الرد على المكالمات. ستساعدك هذه الإحصائيات في تحديد عدد الوكلاء الذين يجب استخدامهم لتقديم خدمة أفضل لعملائك.

### بنية ACD

تتكون بنية ACD من طوابير ووكلاء. يمكن لوكيل واحد أن يكون في طابورين في نفس الوقت. يمكن أن يحتوي الطابور على وكلاء، وقنوات، ومجموعات وكلاء.

![بنية ACD: كل طابور (خدمة العملاء، المبيعات الداخلية) يتم تغذيته بواسطة رقم هاتف ويوصل المكالمات إلى الوكلاء، الذين يرتبطون بدورهم بقنوات مادية](../images/14-queues-fig02.png)

## Queues

يتم تعريف Queues في ملف الإعدادات queues.conf. الوكلاء (Agents) هم الموظفون الذين يقومون بتسجيل الدخول ويصبحون أعضاء في Queues. يتم تعريف الوكلاء في ملف agents.conf. لقد نما نظام Queues بشكل ملحوظ عبر العديد من الإصدارات، مما جعل ملف الإعدادات واسع النطاق. سنشرح بعض المعلمات الرئيسية. إحدى المعلمات العامة التي تستحق الإبراز هي `autofill`:

```
autofill=yes
```

كان السلوك القديم لـ Queue هو النوع التسلسلي (serial). حيث كان Queue ينتظر حتى يتم إرسال المكالمة قبل إرسال المكالمة التالية إلى الوكيل التالي. إذا استغرق الوكيل 15 ثانية للرد على مكالمة، كان على المكالمات الأخرى في Queue الانتظار حتى يتم الرد على تلك المكالمة. بالنسبة لـ Queues ذات الحجم الكبير، كان هذا السلوك غير فعال. السلوك الجديد autofill=yes لا ينتظر حتى يتم الرد على المكالمة، بل يعمل بالتوازي. يمكنك تسجيل المكالمات في Queue باستخدام الخيار mixmonitor. في هذا الوضع، يتم تسجيل المكالمات ودمجها في نفس الوقت.

### ملف إعدادات Queue

يتم إعداد Queues في ملف queues.conf. في الشكل، ستجد مثالاً عملياً لـ Queue.

![مثال عملي لملف queues.conf، يوضح القسم العام و Queue لخدمة العملاء مع الاستراتيجية، ومستوى الخدمة، والإعلانات، والتسجيل، والأعضاء](../images/14-queues-fig03.png)

### الوكلاء (Agents)

يمكنك إعداد الوكلاء في ملف agents.conf. يمكن للوكلاء تسجيل الدخول من أي extension لاستقبال المكالمات. يمكنك الاتصال بوكيل باستخدام:

```
Dial(agent/<name>)
```

#### تسجيل دخول الوكيل

يعمل تدفق تسجيل الدخول للوكيل 300 على النحو التالي:

- يقوم المستخدم بطلب extension يقوم بتشغيل تطبيق `AgentLogin()`.
- يتم تنفيذ `AgentLogin()` ويتم ربط الوكيل بـ channel الحالي.
- يمكنك التحقق من حالة الوكلاء باستخدام الأمر `agent show all`.

![الوكلاء: يقوم المستخدم بتسجيل الدخول عن طريق طلب extension يقوم بتشغيل تطبيق agentlogin، والذي يربط الوكيل 300 بـ channel الحالي؛ يمكنك التحقق من حالة الوكيل باستخدام `agent show all`](../images/14-queues-fig04.png)

يمكنك تعريف الوكلاء في ملف agents.conf

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

### الأعضاء (Members)

الأعضاء هم channels نشطة تستجيب لـ Queue. يمكن أن يكون الأعضاء channels مباشرة (PJSIP, DAHDI) أو وكلاء يقومون بتسجيل الدخول قبل استقبال المكالمات.


### الاستراتيجيات (Strategies)

يتم توزيع المكالمات بين الأعضاء وفقاً لإحدى هذه الاستراتيجيات:

- ringall: يقوم برنين جميع channels المتاحة حتى يرد شخص ما.
- leastrecent: يوزع المكالمات على العضو الأقل حداثة في الاستقبال.
- fewestcalls: يوزع المكالمات على العضو الذي لديه أقل عدد من المكالمات.
- random: رنين واجهة عشوائية.
- wrandom: رنين واجهة عشوائية، ولكن مع استخدام عقوبة (penalty) العضو كوزن عند حساب مقياسه.
- rrmemory: يستخدم التوزيع الدائري (round robin) مع الذاكرة؛ حيث يتذكر من أين توقف مع المكالمة في المرة السابقة.
- rrordered: نفس rrmemory، باستثناء أنه يتم الحفاظ على ترتيب أعضاء Queue كما هو في ملف الإعدادات.
- linear: يرن الأعضاء بالترتيب الذي تم إدراجهم به في queues.conf؛ وبالنسبة للأعضاء الديناميكيين، بالترتيب الذي تمت إضافتهم به.

تم إهمال استراتيجية `roundrobin` القديمة منذ Asterisk 1.4. لم تعد استراتيجية موثقة ولا ينبغي استخدامها: في Asterisk 22 لا يزال المحلل يقبل الكلمة `roundrobin`، ولكن فقط كاسم مستعار للتوافق مع الإصدارات السابقة والذي يتم تعيينه إلى `rrmemory`. استخدم `rrmemory` (أو `rrordered`) بشكل صريح بدلاً من ذلك. القائمة أعلاه هي مجموعة الاستراتيجيات الموثقة لخيار `strategy` في Asterisk 22 `queues.conf`.

## الوكلاء (Agents)

يتم تنفيذ الوكلاء كقنوات وكيلة (proxy channels). ويمكن استخدامهم داخل طوابير الانتظار (queues). ومن الاستخدامات الأخرى لقنوات الوكلاء هي تنقل الامتدادات (extension mobility). حيث يمكن للمستخدم تسجيل الدخول باستخدام أي هاتف واستقبال مكالماته. وهذا يسمح للمستخدم بالذهاب إلى أي غرفة لجعلها مكتباً له. يمكنك الاتصال بوكيل في الـ dialplan باستخدام `dial(agent/<name>)`. ويتم تعريف الوكلاء في ملف `agents.conf`.

![تنقل الوكيل: يقوم المستخدم برفع سماعة أي هاتف، وطلب امتداد تسجيل الدخول، وإدخال رقم الوكيل وكلمة المرور؛ بعد نجاح `agentlogin()` يصبح الوكيل (Agent 300) جاهزاً لاستقبال المكالمات، ويمكنك التحقق من الحالة باستخدام أمر الـ CLI `agent show all`](../images/14-queues-fig05.png)

### مجموعات الوكلاء (Agent Groups)

قد تختار استخدام مجموعات الوكلاء. هذه الوظيفة لا تأخذ استراتيجيات الـ ACD في الاعتبار. ومن المرجح أنك ستفضل إدراج جميع الوكلاء بشكل فردي. إذا كنت ترغب في التحويل إلى مجموعة وكلاء، يمكنك استخدام `queues.conf`:

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### ملف الإعدادات الخاص بالوكلاء

يتم تعريف الوكلاء في الملف `agents.conf`. فيما يلي مثال عملي للملف.

![مثال عملي لملف `agents.conf`: قسم عام يحتوي على `persistentagents`، وقسم للوكلاء يحتوي على المعلمات الافتراضية (`autologoff`، `ackcall`، `endcall`، `wrapuptime`، `musiconhold`)، وتعريفين لوكيلين (300 و 301)](../images/14-queues-fig06.png)

## تطبيقات متعلقة بـ ACD

يوفر نظام الطوابير في Asterisk العديد من التطبيقات لتنفيذ الطوابير داخل الـ dialplan. فيما يلي، نستعرض بعضاً منها.

### التطبيق queue()

يقوم هذا التطبيق بوضع المكالمات الواردة في طابور مكالمات معين كما هو محدد في queues.conf. قد تحتوي سلسلة الخيارات على صفر أو أكثر من الخيارات المكونة من حرف واحد (موضحة في الشكل أدناه). بالإضافة إلى تحويل المكالمة، يمكن وضع المكالمة في الانتظار (parked) ثم التقاطها من قبل مستخدم آخر. سيتم إرسال الـ URL الاختياري إلى الطرف المتصل إذا كانت القناة تدعم ذلك. سيقوم معامل AGI الاختياري بإعداد سكربت AGI ليتم تنفيذه على قناة الطرف المتصل بمجرد اتصاله بأحد أعضاء الطابور. سيؤدي الـ timeout إلى فشل الطابور بعد عدد محدد من الثواني، يتم التحقق منه بين كل دورة timeout و retry. يقوم هذا التطبيق بضبط متغير الحالة QUEUE عند الانتهاء:

![التطبيق queue(): صيغته `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — يفصل Asterisk 22 بين الوسائط بفواصل (تم الاستغناء عن صيغة الـ pipe `|` القديمة) — والخيارات المتاحة المكونة من حرف واحد (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### التطبيق agentlogin()

يطلب هذا التطبيق من الـ agent تسجيل الدخول إلى النظام. يعيد هذا التطبيق دائماً القيمة -1. أثناء تسجيل الدخول، سيسمع الـ agent الذي يستقبل المكالمات صفيراً عند ورود مكالمة جديدة. يمكن للـ agent إنهاء المكالمة بالضغط على مفتاح *.

![التطبيق agentlogin(): صيغته `AgentLogin([AgentNo][|options])` والخيار `s` لتسجيل دخول صامت لا يعلن عن تأكيد تسجيل الدخول](../images/14-queues-fig08.png)

### التطبيق addQueueMember()

يقوم هذا التطبيق بإضافة جهاز (على سبيل المثال PJSIP/3000) إلى طابور بشكل ديناميكي. إذا كان الجهاز موجوداً بالفعل، فسيقوم بإرجاع خطأ.

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### التطبيق removeQueueMember()

يقوم هذا التطبيق بإزالة جهاز من الطابور بشكل ديناميكي. إذا كان الجهاز لا ينتمي إلى الطابور، فسيقوم بإرجاع خطأ.

```
RemoveQueueMember(queuename[|interface])
```

### تطبيقات الدعم وأوامر CLI

هناك بعض التطبيقات وأوامر وحدة التحكم (console) القادرة على المساعدة في العمل مع الطوابير. يوضح ما يلي وظيفة كل تطبيق:

![تطبيقات الدعم (AddQueueMember, RemoveQueueMember) وأوامر CLI (agent show all, queue show, queue show <name>) المستخدمة لإدارة الطوابير أثناء التشغيل](../images/14-queues-fig09.png)

## مهام الإعداد

يلخص الشكل أدناه المهام الرئيسية لإنشاء نظام طوابير فعال.

![مهام إعداد ACD: (1) إنشاء طابور المكالمات (مطلوب)، (2) تحديد معلمات الوكيل (اختياري)، (3) إنشاء الوكلاء (اختياري)، (4) وضع الطابور في الـ dialplan (مطلوب)، (5) إعداد تسجيل الوكيل (اختياري)، و(6) التحقق باستخدام agent show all و queue show (اختياري)](../images/14-queues-fig10.png)

الخطوة 1: إنشاء طابور المكالمات في الملف queues.conf:

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

الخطوة 2: تحديد معلمات الوكيل في الملف agents.conf:

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

الخطوة 3: إنشاء الوكلاء في الملف agents.conf:

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

الخطوة 4: إدراج الطابور في الـ dialplan، في الملف `extensions.conf`:

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

### إعداد تسجيل الطابور

يمكن تسجيل المكالمات باستخدام تطبيق MixMonitor الخاص بـ Asterisk. (تمت إزالة تطبيق Monitor المستقل في Asterisk 22، وأصبح خيار `monitor-type` في ملف queues.conf يقبل الآن MixMonitor فقط.) يمكن تفعيل التسجيل من داخل تطبيق الطابور، ليبدأ عند الرد الفعلي على المكالمة. يتم تسجيل المكالمات الناجحة فقط، ولا يتم إجراء أي تسجيلات أثناء استماع المتصلين إلى MOH. لتفعيل المراقبة، ما عليك سوى تحديد monitor-format. هذه الميزة معطلة بخلاف ذلك. يمكنك تعيين اسم ملف التسجيل باستخدام `Set(MONITOR_FILENAME=<filename>)`؛ وإلا فسيتم استخدام `MONITOR_FILENAME=${UNIQUEID}`.

في الملف queues.conf:

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## تشغيل قائمة الانتظار (Queue)

تشرح الأمثلة التالية كيفية استخدام قائمة الانتظار.

1. تسجيل دخول الوكيل (Agent). مثال: يقوم وكيل في قائمة انتظار التسويق عبر الهاتف برفع سماعة الهاتف وطلب #9000. يسمع الوكيل رسالة تفيد بأن تسجيل الدخول غير صالح ويُطلب منه إدخال اسمه وكلمة المرور الخاصة به. تتبع قائمة انتظار التدقيق نفس الإجراء.
2. قائمة الانتظار (Queue). بمجرد دخول قائمة الانتظار، سيسمع الوكيل موسيقى الانتظار (MOH)، إذا تم تعريفها. عندما ترد مكالمة إلى قائمة انتظار التسويق عبر الهاتف، سيسمع الوكيل نغمة تنبيه وسيتم توصيله بتلك المكالمة.
3. إنهاء المكالمة. عندما ينهي الوكيل المكالمة، يمكنه/يمكنها القيام بما يلي:
   - الضغط على ‘*’ لقطع الاتصال والبقاء في قائمة الانتظار.
   - فصل الهاتف، وبالتالي قطع الاتصال من قائمة الانتظار.
   - الضغط على #8000 لتحويل المكالمة للتدقيق.

## موارد متقدمة

يحتوي نظام الطوابير في Asterisk على بعض الميزات المتقدمة لتحديد أولويات عملاء ووكلاء معينين، بالإضافة إلى تمكين قائمة للمستخدم.

### قائمة المستخدم

يمكنك تحديد قائمة للمستخدم أثناء انتظاره في الطابور باستخدام extension مكونة من رقم واحد. لتمكين هذا الخيار، قم بتعريف context في إعدادات الطابور داخل ملف queues.conf.

### العقوبة (Penalty)

يمكن تهيئة الوكلاء باستخدام خاصية Penalty. سيقوم الطابور بإرسال المكالمات أولاً إلى المستخدمين ذوي قيم Penalty الأقل. على سبيل المثال، بما أننا نعلم أن عملاءنا يحبون Susan وصوتها الناعم، فقد نختار تعيين أولوية 0 لها. بدلاً من ذلك، الوكيل المسمى Uber، الذي يمتلك خبرة أقل، هو الأقل تفضيلاً لخدمة العملاء؛ لذلك، نقوم بتعيين أولوية 10 لهذا الوكيل. في ملف queues.conf:

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### الأولوية (Priority)

تعمل الطوابير بنظام FIFO (الأول في الدخول، الأول في الخروج). إذا كنت ترغب في منح أولوية لعملاء مميزين (بلاتيني، ذهبي)، يمكنك إعداد أولويات متباينة. بالنسبة للعملاء البلاتينيين أو الذهبيين:

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

العملاء الزرق:

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## تمت إزالة التطبيق agentcallbacklogin()

تم إيقاف دعم التطبيق `agentcallbacklogin()` من قبل Digium في Asterisk 1.4 (يوليو 2006) وهو لم يعد متاحاً في Asterisk 22. النهج الموصى به هو استخدام `AddQueueMember()` مع واجهة PJSIP لإضافة أعضاء بنمط الاتصال العكسي (callback) إلى طابور الانتظار بشكل ديناميكي. تم تضمين المستند `queues-with-callback-members.txt` في أدلة Asterisk `/doc` القديمة لتقديم إرشادات حول الانتقال.

تمت إزالة برنامج تشغيل القناة `chan_agent` القديم بالمثل؛ حيث أُعيدت كتابة وظائفه كوحدة `app_agent_pool`، وهي التي توفر `AgentLogin()` و `AgentRequest()` ودالة dialplan المسماة `AGENT()` في Asterisk 22 (لا تزال هذه العناصر موجودة — حيث يتم شحن `app_agent_pool.so` مع إصدار 22 القياسي). ومع ذلك، بالنسبة لمراكز الاتصال الحديثة، فإن النمط القياسي هو تخطي قنوات الوكيل (agent channels) تماماً وإضافة جهاز PJSIP الخاص بالوكيل مباشرة إلى طابور الانتظار باستخدام `AddQueueMember()`/`RemoveQueueMember()` (سواء بشكل ثابت في `queues.conf`، أو بشكل ديناميكي من الـ dialplan أو AMI). هذا النهج أكثر بساطة، ويتكامل بشكل نظيف مع حالة جهاز PJSIP، وهو النهج المستخدم في جميع أنحاء هذا الفصل.

## إحصائيات طوابير الانتظار

يتم تسجيل جميع الأحداث الصادرة عن طوابير الانتظار في الملف /var/log/asterisk/queue_log. تم نشر تنسيق سجل طابور الانتظار في المستند queuelog.txt الموجود في المجلد /doc ضمن وثائق Asterisk. فيما يلي بعض أهم الأحداث التي يتم تسجيلها.

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

يمكنك بناء أداتك الخاصة لمعالجة هذه الأحداث أو استخدام حزمة إحصائيات جاهزة للتشغيل:

- **QueueMetrics** (<https://www.queuemetrics.com/>) – حزمة تجارية يتم صيانتها بنشاط، تقوم بتحليل `queue_log` وتظل واحدة من أكثر أدوات إعداد التقارير اكتمالاً لمراكز اتصالات Asterisk.
- **بناء أداتك الخاصة** – نظراً لأن تنسيق `queue_log` المذكور أعلاه مستقر وموثق جيداً، فمن السهل تحليله باستخدام برنامج نصي صغير (مثل Python، إلخ) وتغذية الأحداث إلى قاعدة بيانات أو لوحة تحكم.

للحصول على نهج أكثر اعتماداً على الأحداث بدلاً من مراقبة `queue_log`، تتيح لك واجهة **Asterisk REST Interface (ARI)** وإجراءات **AMI** `QueueSummary`/`QueueStatus` بناء لوحات تحكم حية لطوابير الانتظار وعمليات تكامل مخصصة بناءً على حالة طابور الانتظار في الوقت الفعلي بدلاً من تحليل السجلات بعد وقوع الأحداث. تُعد ARI واجهة التكامل الحديثة والمدعومة لهذا النوع من العمل في Asterisk 22.

## ملخص

في هذا الفصل، تعلمت كيفية استخدام ACD، وبنيته الهيكلية، وكيفية تهيئته. كما تم عرض بعض الميزات المتقدمة مثل الأولويات والعقوبات.

## اختبار

1. أي مما يلي يُعد من استراتيجيات توزيع المكالمات الصالحة في `queues.conf` (اختر كل ما ينطبق)؟
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. يمكنك تسجيل محادثة بين وكيل وعميل من داخل قائمة الانتظار عن طريق ضبط خيار ___ في ملف `queues.conf`.
3. أي `strategy` يقوم برنين الأعضاء بالترتيب الدقيق الذي تم إدراجهم به في `queues.conf`؟
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. عندما ينهي الوكيل مكالمة في مثال التسويق عبر الهاتف، ما هي الإجراءات التي يمكنه اتخاذها (اختر كل ما ينطبق)؟
   - A. الضغط على `*` لقطع الاتصال والبقاء في قائمة الانتظار
   - B. إنهاء المكالمة وقطع الاتصال من قائمة الانتظار
   - C. الضغط على `#8000` لتحويل المكالمة للتدقيق
   - D. الضغط على `#` لتسجيل الخروج من جميع قوائم الانتظار فوراً
5. ما هي المهمتان *المطلوبتان* للحصول على قائمة انتظار تعمل (اختر كل ما ينطبق)؟
   - A. إنشاء قائمة الانتظار
   - B. إنشاء الوكلاء
   - C. تهيئة معلمات الوكيل
   - D. تهيئة التسجيل
   - E. وضع قائمة الانتظار في الـ dialplan
6. في قائمة انتظار المكالمات، يمكنك توفير قائمة خيارات ذات رقم واحد يمكن للمتصل طلبها أثناء الانتظار. يتم تمكين ذلك عن طريق تحديد ___ في قسم `queues.conf` الخاص بقائمة الانتظار:
   - A. agent
   - B. menu
   - C. context
   - D. application
7. تُستخدم تطبيقات الدعم `AddQueueMember()` و `RemoveQueueMember()` في ___ لإضافة أو إزالة الأعضاء أثناء وقت التشغيل:
   - A. dial plan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. نظراً لإزالة chan_sip في Asterisk 21، يجب أن يشير عضو قائمة الانتظار الثابت إلى قناة مثل ___ بدلاً من `SIP/1001`.
9. المعلمة `wrapuptime` هي الحد الأدنى من الوقت بعد قيام الوكيل بقطع مكالمة قبل أن ترسل قائمة الانتظار إلى ذلك الوكيل مكالمة جديدة.
   - A. صواب
   - B. خطأ
10. يمكن منح المتصل مركزاً أعلى في نفس قائمة الانتظار عن طريق ضبط متغير القناة `QUEUE_PRIO` قبل استدعاء `Queue()`.
    - A. صواب
    - B. خطأ

**الإجابات:** 1 — A, C, D, E, F (roundrobin ليست استراتيجية موثقة؛ في Asterisk 22 تبقى فقط كاسم مستعار مهمل لـ rrmemory) · 2 — `monitor-format` (يتم تمكين التسجيل من قائمة الانتظار عن طريق تحديد `monitor-format`؛ في Asterisk 22 يدعم `monitor-type` فقط MixMonitor) · 3 — C (linear) · 4 — A, B, C (`*` يقطع الاتصال ويبقى؛ `#` ليس مفتاحاً لتسجيل الخروج من الجميع) · 5 — A, E · 6 — C (خيار `context`) · 7 — A (الـ dial plan) · 8 — `PJSIP/1001` (أي واجهة `PJSIP/`) · 9 — صواب · 10 — صواب
