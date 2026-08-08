# ميزات dialplan المتقدمة

ناقش الفصل الثالث أساسيات الـ dialplan. لأسباب تعليمية، لم نقم بشرح جميع الميزات، بل اكتفينا بذكر بعض أهمها فقط. سيتعمق هذا الفصل أكثر في الـ dialplan، واصفاً التقنيات المتقدمة، والتطبيقات الجديدة، والمفاهيم المتعلقة به.

## الأهداف

بحلول نهاية هذا الفصل، يجب أن تكون قادراً على:

- تبسيط إدخالات الـ extension الخاصة بك
- معالجة أمن الـ dialplan وتصفية الـ extensions
- استقبال المكالمات باستخدام قائمة IVR
- استخدام الإجراءات الفرعية (subroutines) لتجنب عمليات إعادة الكتابة غير الضرورية
- تنفيذ بعض إجراءات أمن الـ dialplan باستخدام "Include"
- تنفيذ ميزة "اتبعني" (follow-me) باستخدام AsteriskDB
- تنفيذ سلوك خاص بساعات العمل وخارجها في نظام الـ PBX الخاص بك
- استخدام أمر switch للتحويل إلى نظام PBX آخر
- تنفيذ مدير الخصوصية (privacy manager)
- تنفيذ الـ voicemail
- تنفيذ دليل هاتف للشركة

## تبسيط الـ dialplan الخاص بك

يمكنك تبسيط الـ dialplan الخاص بك باستخدام الكلمة المفتاحية "same" لتعريف الـ extension. من شأن ذلك أن يقلل من عدد الأخطاء المطبعية في الـ dialplan. تحقق من المثال أدناه:

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## أمن الـ dialplan

تم اكتشاف ثغرة في الـ dialplan الخاص بـ Asterisk تسمح للمستخدم بحقن قناة جديدة ورقم اتصال في الـ dialplan الخاص بك. لنفترض أن لديك السطر التالي في الخادم الخاص بك `exten=>_X.,1,Dial(PJSIP/${EXTEN})` وقام مستخدم خبيث بطلب الرقم `3000&DAHDI/1/011551123456789` في الـ softphone. بروتوكول SIP، افتراضياً، يقبل أي محارف أبجدية رقمية، لذا فإن الـ extension الذي تم طلبه سيؤدي فعلياً إلى تشغيل مكالمتين: واحدة للقناة PJSIP/3000 والأخرى للقناة DAHDI/011551123456789، وهو رقم دولي. وبذلك، يمكن لأي مستخدم لديه صلاحية الوصول إلى أي extension الاتصال بأي مكان في العالم. أسهل طريقة لتجنب هذا السلوك هي تصفية الأرقام قبل استدعاء تطبيق الاتصال. الدالة FILTER() مفيدة جداً لهذا الغرض. مثال:

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

سيسمح لك تطبيق التصفية بتصفية جميع المحارف من الرقم المطلوب باستثناء الأرقام من 0 إلى 9. يمكن العثور على مزيد من المعلومات في الملف README-SERIOUSLY.bestpractices.txt المتاح من Asterisk.

## استقبال المكالمات باستخدام قائمة IVR.

في القسم الأخير، قمت باستقبال جميع المكالمات باستخدام DID أو إعادة التوجيه إلى المشغل. الآن ستتعلم كيفية تنفيذ قائمة IVR بالإضافة إلى إنشاء خدمة الرد الآلي. قبل الخوض في التفاصيل، دعنا نفحص بعض التطبيقات الجديدة. لقد وضعنا مخرجات الأمر `core show application` أدناه ببساطة لتسهيل الأمر على القراء. يمكنك الحصول على هذه الأوصاف بنفسك باستخدام `core show application <application_name>`.

### تطبيق Background()

يقوم هذا التطبيق بتشغيل قائمة الملفات المحددة أثناء انتظار قيام القناة المتصلة بطلب extension. للاستمرار في انتظار الأرقام بعد انتهاء هذا التطبيق من تشغيل الملفات، يجب استخدام تطبيق WaitExten. يحدد خيار langoverride صراحةً اللغة التي يجب محاولة استخدامها لملفات الصوت المطلوبة. أي context يتم تحديده سيكون هو الـ context الخاص بـ dialplan الذي يستخدمه هذا التطبيق عند الخروج إلى extension مطلوب. إذا كان أحد ملفات الصوت المطلوبة غير موجود، فسيتم إنهاء معالجة المكالمة. الخيارات:

- s - يتسبب في تخطي تشغيل الرسالة إذا لم تكن القناة في حالة 'up' (أي لم يتم الرد عليها بعد). إذا حدث هذا، سيعود التطبيق على الفور.
- n - لا تقم بالرد على القناة قبل تشغيل الملفات.
- m - توقف فقط إذا تطابق الرقم الذي تم إدخاله مع extension مكون من رقم واحد في الـ context الوجهة.

### تطبيق Record()

يقوم هذا التطبيق بالتسجيل من القناة إلى اسم ملف محدد. إذا كان الملف موجوداً، فسيتم الكتابة فوقه.

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' هو تنسيق نوع الملف المراد تسجيله (wav, gsm, إلخ).
- 'silence' هو عدد ثواني الصمت المسموح بها قبل العودة.
- 'maxduration' هو الحد الأقصى لمدة التسجيل بالثواني؛ إذا كان مفقوداً أو صفراً، فلا يوجد حد أقصى.
- 'options' قد تحتوي على أي من الأحرف التالية:
    - `a` — الإلحاق بتسجيل موجود بدلاً من استبداله
    - `n` — لا ترد، ولكن سجل على أي حال إذا لم يتم الرد على الخط بعد
    - `q` — صامت (لا تقم بتشغيل نغمة التنبيه)
    - `s` — تخطي التسجيل إذا لم يتم الرد على الخط بعد
    - `t` — استخدام مفتاح الإنهاء البديل `*` (DTMF) بدلاً من المفتاح الافتراضي `#`
    - `x` — تجاهل جميع مفاتيح الإنهاء (DTMF) والاستمرار في التسجيل حتى قطع الاتصال

إذا كان اسم الملف يحتوي على %d، فسيتم استبدال هذه الأحرف برقم يتم زيادته بمقدار واحد في كل مرة يتم فيها تسجيل الملف. استخدم core show file formats لرؤية التنسيقات المتاحة على نظامك. يمكن للمستخدم الضغط على # لإنهاء التسجيل والانتقال إلى الأولوية التالية. إذا قام المستخدم بقطع الاتصال أثناء التسجيل، فستفقد جميع البيانات وسينتهي التطبيق.

### تطبيق Playback()

يقوم هذا التطبيق بتشغيل أسماء ملفات محددة (لا تقم بتضمين الامتداد). يمكن أيضاً تضمين الخيارات بعد رمز الأنبوب (pipe). يتسبب خيار 'skip' في تخطي تشغيل الرسالة إذا لم تكن القناة في حالة 'up' (أي لم يتم الرد عليها بعد).

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

إذا تم تحديد 'skip'، فسيعود التطبيق على الفور إذا لم تكن القناة مرفوعة السماعة. بخلاف ذلك، ما لم يتم تحديد 'noanswer'، سيتم الرد على القناة قبل تشغيل الصوت. لا تدعم جميع القنوات تشغيل الرسائل أثناء بقاء السماعة مرفوعة. إذا تم تحديد 'j'، فسيقفز التطبيق إلى الأولوية n+101 عندما لا يكون الملف موجوداً، إذا كان ذلك متاحاً. يقوم هذا التطبيق بتعيين متغير القناة التالي عند الانتهاء:

- PLAYBACKSTATUS — حالة محاولة التشغيل كسلسلة نصية، واحدة من:
    - `SUCCESS`
    - `FAILED`

### تطبيق Read()

يقوم هذا التطبيق بقراءة عدد محدد مسبقاً من أرقام السلسلة، لعدد معين من المرات، من المستخدم إلى المتغير المحدد.

- filename -- الملف الذي سيتم تشغيله قبل قراءة الأرقام أو النغمة مع الخيار i
- maxdigits -- الحد الأقصى لعدد الأرقام المقبول. يتوقف عن القراءة بعد إدخال maxdigits (دون مطالبة المستخدم بالضغط على مفتاح #). الافتراضي هو 0 - لا يوجد حد - لانتظار المستخدم للضغط على مفتاح #. أي قيمة أقل من 0 تعني نفس الشيء. الحد الأقصى للقيمة المقبولة هو 255.

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- الخيارات هي `s`, `i`, `n`:
    - `s` — العودة فوراً إذا لم يكن الخط في حالة up
    - `i` — تشغيل filename كنغمة إشارة من الـ `indications.conf` الخاص بك
    - `n` — قراءة الأرقام حتى لو لم يكن الخط في حالة up
- attempts -- إذا كانت أكبر من 1، فسيتم إجراء عدد المحاولات في حالة عدم إدخال أي بيانات
- timeout -- عدد صحيح من الثواني للانتظار لاستجابة رقمية. إذا كانت أكبر من 0، فستتجاوز تلك القيمة مهلة الانتظار الافتراضية.

يجب أن يقوم تطبيق read() بقطع الاتصال إذا فشلت الوظيفة أو حدث خطأ.

### تطبيق Gotoif()

سيؤدي هذا التطبيق إلى قفز القناة المتصلة إلى الموقع المحدد في الـ dialplan بناءً على تقييم الشرط المعطى. ستستمر القناة عند labeliftrue إذا كان الشرط صحيحاً، أو 'labeliffalse' إذا كان الشرط خاطئاً. يتم تحديد التسميات (labels) بنفس الصيغة المستخدمة داخل تطبيق Goto. إذا تم حذف التسمية المختارة بواسطة الشرط، فلن يتم تنفيذ أي قفزة؛ بل يستمر التنفيذ مع الأولوية التالية في الـ dialplan.

### مختبر: بناء قائمة IVR خطوة بخطوة

دعنا ننشئ قائمة IVR بالوظائف التالية. عند الاتصال، تقوم قائمة IVR بتشغيل ملف صوتي برسالة “مرحباً بكم في شركة XYZ؛ اضغط 1 للمبيعات، 2 للدعم الفني، 3 للتدريب، أو انتظر للتحدث إلى ممثل.” تقوم الأرقام بتوجيه المتصل كما يلي:

- `1` — تحويل إلى المبيعات (PJSIP/4001)
- `2` — تحويل إلى الدعم الفني (PJSIP/4002)
- `3` — تحويل إلى التدريب (PJSIP/4003)
- لم يتم الضغط على أي رقم — تحويل إلى المشغل (PJSIP/4000)

**الخطوة 1 – تسجيل المطالبات**

دعنا ننشئ extension لتسجيل المطالبات. لتسجيل مطالبة، اتصل من softphone إلى `9003<filename>` (على سبيل المثال، `9003welcome`). عندما تسمع صوت التنبيه، ابدأ التسجيل؛ اضغط على `#` للتوقف. ستسمع صوت تنبيه، وسيقوم النظام بتشغيل المطالبة المسجلة.

**الخطوة 2 – إنشاء منطق القائمة**

عند طلب الـ extension 9004، تقفز المعالجة إلى القائمة في الـ extension `s`، الأولوية 1.

### المطابقة أثناء الطلب

هذه قائمة إعداد شركة لاستقبال المكالمات. يقوم تطبيق `Background()` بتشغيل مطالبة الترحيب ثم ينتظر الأرقام، ويطابق ما يطلبه المتصل مقابل الـ extensions المحددة في الـ context الحالي.

```
[incoming]
exten=>s,1,Background(welcome)
exten=>1,1,Dial(DAHDI/1)
exten=>2,1,Dial(DAHDI/2)
exten=>21,1,Dial(DAHDI/3)
exten=>22,1,Dial(DAHDI/4)
exten=>31,1,Dial(DAHDI/5)
exten=>32,1,Dial(DAHDI/6)
```

عندما تتصل بهذه الشركة، يتم تشغيل رسالة الترحيب أولاً. بعد ذلك، ينتظر Asterisk طلب رقم:

| الرقم المطلوب | إجراء Asterisk |
|---------------|-----------------|
| 1 | يتصل فوراً بـ `Dial(DAHDI/1)` |
| 2 | ينتظر انتهاء المهلة، ثم يتصل بـ `Dial(DAHDI/2)` |
| 21 | يتصل فوراً بـ `Dial(DAHDI/3)` |
| 22 | يتصل فوراً بـ `Dial(DAHDI/4)` |
| 3 | ينتظر انتهاء المهلة، ثم يقطع الاتصال |
| 31 | يتصل فوراً بـ `Dial(DAHDI/5)` |
| 32 | يتصل فوراً بـ `Dial(DAHDI/6)` |

من المهم تجنب الغموض في القوائم. الجميع يريد أن يتم الرد عليهم بسرعة. لهذا السبب، يجب ألا تستخدم الأرقام 2 أو 21 أو 22.

### مختبر: استخدام تطبيق Read()

يرجى تجربة المختبر باستخدام تطبيق read(). يقوم read بقبول الأرقام من المستخدم وإدراجها في المتغير المحدد؛ يمكنك بعد ذلك استخدام تطبيق gotoif لإعادة توجيه المكالمة.

## تضمين السياق (Context inclusion)

يمكن للسياق (context) أن يتضمن محتويات سياق آخر. في المثال أعلاه، يمكن لأي قناة (channel) الاتصال بأي extension في السياق الداخلي (internal context)، ولكن القناة 4003 فقط هي التي يمكنها الاتصال بـ extensions دولية. يمكنك استخدام تضمين السياق لتسهيل إنشاء الـ dialplan. باستخدام تضمين السياق، يمكنك التحكم في من لديه صلاحية الوصول إلى أي extensions.

### استكشاف أخطاء الرسالة "number not found" وإصلاحها

من الشائع جداً تلقي الرسالة "number not found". يخلط معظم الناس بين مفهوم السياقات المضمنة لأنها في الواقع ليست بديهية. كقاعدة عامة، انتقل أولاً إلى ملف تكوين القناة الواردة، مثل `pjsip.conf` و `chan_dahdi.conf` و `iax.conf`، وحدد الـ context الحالي. ثم انتقل إلى الـ dialplan في الملف extensions.conf وتحقق مما إذا كان الرقم المطلوب يمكن العثور عليه في ذلك الـ context. إذا لم يكن الأمر كذلك، فهناك خطأ ما في الـ dialplan الخاص بك. القواعد الذهبية للـ contexts هي: 1. لا يمكن للقناة الاتصال إلا بالأرقام الموجودة ضمن نفس الـ context الخاص بالقناة. 2. يتم تحديد الـ context الذي تتم فيه معالجة المكالمة في ملف تكوين القناة الواردة (`chan_dahdi.conf` و `iax.conf` و `pjsip.conf`).

## استخدام عبارة switch

يمكنك إرسال معالجة الـ dialplan إلى خادم آخر باستخدام الأمر switch. ستحتاج إلى اسم ومفتاح الخادم الآخر. الـ context هو الـ context الوجهة.

![10-dialplan-advanced-features figure 6](../images/10-dialplan-advanced-features-img06.png)

## ترتيب معالجة الـ dialplan

عندما يستقبل Asterisk مكالمة واردة، فإنه يبحث في الـ context المحدد بواسطة القناة. في بعض الحالات، إذا تطابق أكثر من نمط مع الرقم المطلوب، فقد لا يتمكن Asterisk من معالجة المكالمة بالطريقة التي تتوقعها بالضبط. يمكنك رؤية ترتيب المطابقة باستخدام أمر الـ CLI `dialplan show`. مثال: لنفترض أنك تريد طلب 912 لتوجيهه إلى trunk تناظري (DAHDI/1) وجميع الأرقام الأخرى التي تبدأ بـ 9 إلى trunk تناظري آخر (DAHDI/2). ستكتب شيئاً كهذا:

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

إذا تطابق نمطان مع extension معين، يمكنك التحكم في أي extension تتم معالجته أولاً باستخدام الـ contexts المضمنة (included contexts). تتم معالجة الـ context المضمن لاحقاً مقارنة بالنمط الموجود في نفس الـ context.

## العبارة #INCLUDE

هل ينبغي علينا استخدام ملف واحد كبير أم عدة ملفات؟ يمكنك استخدام العبارة #include <filename> لتضمين ملفات أخرى في ملف extensions.conf الخاص بك. على سبيل المثال، يمكننا إنشاء ملف users.conf للمستخدمين المحليين وملف services.conf للخدمات الخاصة. احذر من الخلط بين #include <filename> و

```
include=>context statement.
```

## الإجراءات الفرعية باستخدام GOSUB

في الإصدارات القديمة من Asterisk، كان لديك الأمر Macro. تم إيقاف هذا الأمر منذ فترة طويلة لصالح GOSUB. سنوضح هنا كيفية إنشاء إجراءات فرعية لمعالجة voicemail بطريقة سهلة ومنظمة. تنسيق الأمر هو:

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

الأمر GOSUB متاح منذ الإصدار Asterisk 1.6 ويدعم تمرير الوسائط (المتاحة داخل الإجراء الفرعي كـ `${ARG1}` و `${ARG2}` وما إلى ذلك). مع وجود الوسائط، أصبح من الممكن الآن استبدال أوامر Macro القديمة بالكامل. تمت إزالة Macros (`app_macro`) في الإصدار Asterisk 21؛ يجب عليك استخدام GOSUB للإجراءات الفرعية.

### إنشاء الإجراء الفرعي

التعريف مشابه جداً. انظر إلى الإجراء الفرعي أدناه المعرف لـ voicemail بالاسم stdexten (اختر الاسم الذي تفضله). بعد استدعاء الأمر Dial مع الوسيط الأول (اسم القناة)، نتحقق من ${DIALSTATUS} لتوجيه منطق المكالمة إلى الخطوة التالية.

```
[stdexten]
exten=>s,1,Dial(${ARG1},20,tT)
exten=>s,n,Goto(${DIALSTATUS})
exten=>s,n,hangup()
exten=>s,n(BUSY),voicemail(${ARG2},b)
exten=>s,n,hangup()
exten=>s,n(NOANSWER),voicemail(${ARG2},u)
exten=>s,n,hangup()
exten=>s,n(CANCEL),hangup
exten=>s,n(CHANUNAVAIL),hangup
exten=>s,n(CONGESTION),hangup
```

### استدعاء إجراء فرعي

انتبه عند استدعاء الإجراء الفرعي لاستخدام الأقواس قبل المعاملات.

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## استخدام Asterisk DB

لتنفيذ تحويل المكالمات والقوائم السوداء، نحتاج إلى طريقة لتخزين البيانات واستعادتها. لحسن الحظ، يوفر Asterisk آلية لتخزين واسترجاع البيانات من قاعدة بيانات مدمجة تسمى AstDB. في إصدارات Asterisk الحديثة (بما في ذلك Asterisk 22)، يتم دعم AstDB بواسطة **SQLite3** (الملف `/var/lib/asterisk/astdb.sqlite3`)؛ بينما استخدم Asterisk 1.8 والإصدارات الأقدم Berkeley DB v1. يشبه هذا قاعدة بيانات سجل Windows (registry) باستخدام مفهوم التسلسل الهرمي للعائلات والمفاتيح. تظل البيانات محفوظة بين عمليات إعادة تشغيل Asterisk. لم تتغير واجهة برمجة التطبيقات (API) الخاصة بالعائلة/المفتاح عن النظام الخلفي القديم؛ فقط تنسيق التخزين على القرص هو الذي تغير.

### الدوال، والتطبيقات، وأوامر CLI

هناك بعض الدوال، والتطبيقات، وأوامر CLI التي تعمل مع AstDB:

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

أمثلة:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

يمكن استخدام بعض التطبيقات لمعالجة AstDB:

- DB_DELETE(<family/key>) — دالة تقوم بإرجاع وحذف مفتاح واحد
- DBdeltree(<family>) — تطبيق يقوم بحذف عائلة/شجرة فرعية كاملة

تطبيق `DBdel()` القديم لم يعد موجوداً في Asterisk 22. احذف مفتاحاً واحداً باستخدام دالة dialplan المسماة `DB_DELETE()` — على سبيل المثال `Set(x=${DB_DELETE(family/key)})` أو، كعملية كتابة، `Set(DB_DELETE(family/key)=)`. لا يزال `DBdeltree()` (لحذف عائلة/شجرة فرعية كاملة) تطبيقاً متاحاً.

من الممكن أيضاً استخدام أوامر CLI لتعيين وحذف المفاتيح:

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### تنفيذ تحويل المكالمات، وDND، والقوائم السوداء

في هذا المثال، ستتعلم كيفية تنفيذ تحويل المكالمات الفوري وتحويل المكالمات عند الانشغال. سنستخدم *21* لبرمجة تحويل المكالمات الفوري و*61* لبرمجة تحويل المكالمات عند حالة الانشغال. لإلغاء البرمجة، استخدم #21# و #61# على التوالي. استخدم المثال أعلاه لملء قاعدة البيانات. العائلات المستخدمة هي:

- CFIM – تحويل المكالمات الفوري (Call Forward Immediate)
- CFBS – تحويل المكالمات عند الانشغال (Call Forward on Busy status)
- DND – عدم الإزعاج (Do Not Disturb)

جرب ملء قاعدة البيانات عن طريق الاتصال بـ:

- *21* (رقم extension الوجهة لتحويل المكالمات الفوري)
- *61* (رقم extension الوجهة لتحويل المكالمات عند حالة الانشغال)
- *41* (رقم extension المراد وضعه في حالة عدم الإزعاج)

استخدم أمر CLI المسمى database show لرؤية العائلات والمفاتيح والقيم المضافة.

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### تحويل المكالمات، القائمة السوداء، وDND

يتحقق الروتين الفرعي (subroutine) مما إذا كانت قاعدة البيانات تحتوي على أزواج المفتاح:القيمة المقابلة لـ CFIM أو CFBS أو DND، ثم يتعامل معها بشكل مناسب. يقوم الروتين الفرعي التالي باستدعاء روتين الاتصال:

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## استخدام القائمة السوداء

تم **إزالة** تطبيق `LookupBlacklist()` القديم من Asterisk (وقد اختفى مع الآلية القديمة "priority+101 jump"). في Asterisk 22، يمكنك إنشاء قائمة سوداء مباشرة باستخدام وظيفة `DB_EXISTS()` (التي تقوم باختبار المفتاح، وعند العثور عليه، تعرض قيمته في `${DB_RESULT}`) بالإضافة إلى `GotoIf`. قم بتخزين كل رقم محظور كمفتاح في عائلة `blacklist`، ثم تحقق من معرف المتصل (caller ID) في أعلى الـ context الخاص بالاتصالات الواردة:

```
[incoming]
exten => s,1,GotoIf($[${DB_EXISTS(blacklist/${CALLERID(num)})}]?blocked,s,1)
exten => s,n,Dial(PJSIP/4000,20,tT)
exten => s,n,Hangup()
[blocked]
exten => s,1,Answer()
exten => s,2,Playback(blockedcall)
exten => s,3,Hangup()
```

تُرجع `DB_EXISTS(blacklist/${CALLERID(num)})` القيمة `1` عندما يكون رقم المتصل موجوداً في قاعدة البيانات (مما يؤدي إلى إرسال المكالمة إلى الـ context المسمى `blocked`) وتُرجع `0` في حال عدم وجوده، وبذلك تستمر المكالمة إلى الـ `Dial()` العادي.

لإدراج رقم في القائمة السوداء، يمكننا استخدام نفس المورد كما في السابق، باستخدام *31* متبوعاً بالأرقام المراد حظرها. لإزالة رقم من القائمة السوداء، يجب عليك استخدام #31# متبوعاً بالرقم المراد إزالته.

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

يمكنك أيضاً إدراج الأرقام في القائمة السوداء باستخدام واجهة سطر الأوامر (CLI) الخاصة بـ Asterisk:

```
*CLI>database put blacklist <name/number> 1
```

ملاحظة: يمكن ربط أي قيمة بالمفتاح. يقوم اختبار `DB_EXISTS()` بالبحث عن المفتاح، وليس القيمة. لمسح الرقم من القائمة السوداء، يمكنك استخدام:

```
*CLI>database del blacklist <name/number>
```

## سياقات تعتمد على الوقت

في الشكل التالي، لدينا dialplan يحتوي على ثلاثة سياقات. السياق [incoming] هو المكان الذي يتم فيه عادةً استقبال المكالمات. لقد قمنا بتضمين أربعة أسطر تغير السلوك بناءً على وقت النظام، كما هو موضح أدناه:

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

يقوم Asterisk الحديث (بما في ذلك 22) بفصل حقول time-include باستخدام **الفواصل**، وليس باستخدام الرموز العمودية (pipes). يتم تحليل صيغة الرمز العمودي القديمة (`include => context|times|weekdays|mdays|months`) كاسم سياق حرفي عادي ويفشل تطبيق أي شرط زمني بصمت.

خلال ساعات العمل العادية، ستتم إعادة توجيه المعالجة إلى mainmenu، حيث سيقوم على الأرجح باستدعاء IVR للتعامل مع المكالمة الواردة. إذا تمت المكالمة خارج ساعات العمل، فسيتم استدعاء extension الأمان المحدد في المتغير ${SECURITY}. إذا لم يقم extension الأمان بالرد على المكالمة، فسيتم إرسالها إلى voicemail الخاص بالمشغل.

![10-dialplan-advanced-features figure 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figure 12](../images/10-dialplan-advanced-features-img12.png)

## الرسائل المعتمدة على الوقت باستخدام gotoiftime()

يظهر بناء جملة GotoIfTime() أدناه.

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

في Asterisk 22، يكون فاصل الحقول هو **فاصلة** (comma)، وليس خطاً عمودياً (تم إيقاف استخدام صيغة الخط العمودي في Asterisk 1.6). يتم دعم حقل اختياري `timezone`، ويستخدم كل ملصق فرعي صيغة `[[context,]extension,]priority` المعتادة.

يمكن لهذا التطبيق أن يحل محل الـ context المعتمد على الوقت، ويبدو أسهل في الفهم والقراءة. يمكنك تحديد الوقت كما يلي:

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=رقم من 1 إلى 31
- <hour>=رقم من 0 إلى 23
- <minute>=رقم من 0 إلى 59
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

أسماء الأيام والأشهر لا تتأثر بحالة الأحرف (كبيرة أو صغيرة).

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

تقوم العبارة السابقة بنقل المعالجة إلى الـ extension المسمى s في الـ context المسمى normalhours إذا كانت المكالمة بين الساعة 08:00 صباحاً والساعة 06:00 مساءً من يوم الاثنين إلى يوم الجمعة.

## استخدام DISA للحصول على نغمة اتصال جديدة

تُعد DISA، أو "الوصول المباشر للنظام الداخلي" (direct inward system access)، نظاماً يسمح للمستخدمين بالحصول على نغمة اتصال ثانية. وهي تتيح للمستخدمين الاتصال مرة أخرى بوجهة أخرى. غالباً ما يستخدمها الفنيون عند إجراء مكالمات المسافات الطويلة للحصول على الدعم الفني في عطلات نهاية الأسبوع؛ فبدلاً من الاتصال من منازلهم مباشرة بالوجهة، يتصلون برقم DISA الخاص بالمكتب، ويحصلون على نغمة اتصال، ثم يتصلون بالوجهة. وبذلك تُحتسب تكاليف المسافات الطويلة على الشركة بدلاً من هاتف المنزل.

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

مثال:

```
exten => s,1,DISA(no-password,default)
```

باستخدام العبارة السابقة، يتصل المستخدم بـ PBX—ودون الحاجة إلى أي كلمة مرور—يحصل على نغمة اتصال. ستتم معالجة أي مكالمة تستخدم DISA باستخدام الـ context المسمى `default`. تتضمن وسائط هذا التطبيق كلمة مرور عامة أو كلمة مرور فردية داخل ملف. إذا لم يتم تحديد context، فسيتم افتراض الـ context المسمى `disa`. إذا كنت تستخدم ملف كلمات مرور، فيجب تحديد المسار الكامل. يمكن أيضاً تحديد معرف المتصل (caller ID) للاتصال الخارجي عبر DISA. مثال:

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

يستخدم Asterisk 22 الفواصل كفواصل بين الوسائط (تم إيقاف استخدام صيغة الأنبوب | في الإصدار 1.6). الوسيط الأول هو إما رمز مرور واحد أو المسار إلى ملف رموز المرور، والـ context الافتراضي عند عدم تحديد أي منها هو `disa`.

## تحديد المكالمات المتزامنة

تسمح لك الدالة GROUP() بحساب عدد القنوات النشطة التي لديك في مجموعة واحدة في نفس الوقت. مثال: لديك فرع في ريو دي جانيرو، حيث تتبع الهواتف النمط "_214X". يتم تقديم الخدمة لهذا الموقع عبر خط مؤجر، مع حجز 64K من النطاق الترددي للصوت. في هذه الحالة، الحد الأقصى لعدد المكالمات المسموح به هو 2 (باستخدام G.729، حوالي 31.2K لكل مكالمة). لتحديد المكالمات إلى ريو باثنتين:

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

نظام Voicemail هو نظام آلي للرد الهاتفي يقوم بتسجيل الرسائل الصوتية الواردة، وحفظها على القرص أو إرسالها عبر البريد الإلكتروني. في بعض الأحيان، يحتوي النظام على دليل يمكنك من خلاله البحث عن صناديق البريد الصوتي بالاسم. في الماضي، كانت أنظمة Voicemail باهظة الثمن للغاية. أما الآن، ومع تقنية IP telephony، أصبح Voicemail ميزة قياسية.

لتهيئة Voicemail، يجب عليك اتباع الخطوات التالية.

**الخطوة 1: قم بتحرير `voicemail.conf` وضبط المعلمات العامة.**

- `format` — الـ codec المستخدم لتسجيل الرسالة (على سبيل المثال، wav49، wav، gsm)
- `serveremail` — الجهة التي يجب أن يظهر إشعار البريد الإلكتروني وكأنه قادم منها
- `maxmsg` — الحد الأقصى لعدد الرسائل في صندوق البريد؛ بعد تجاوز هذا الحد، يتم تجاهل الرسائل الجديدة
- `maxsecs` — الحد الأقصى لطول رسالة Voicemail، بالثواني
- `minsecs` — الحد الأدنى لطول الرسالة، بالثواني؛ إذا كانت الرسالة أقصر من هذا الحد، فلن يتم تسجيلها
- `maxsilence` — عدد ثواني الصمت التي يتم التعامل معها على أنها نهاية الرسالة

**الخطوة 2: قم بتحرير `voicemail.conf` وإنشاء صناديق بريد المستخدمين.**

### Voicemail.conf

يتم تعريف صندوق البريد بسطر واحد لكل صندوق، بالصيغة التالية:

```
mailboxID => pincode,fullname,email,pager-email,options
```

الحقول هي:

- **MailboxID** — عادة ما يكون رقم الـ extension
- **Pincode** — كلمة المرور للوصول إلى نظام Voicemail
- **Full name** — يُستخدم بواسطة تطبيق الدليل
- **E-mail** — عنوان البريد الإلكتروني لإشعارات Voicemail
- **Pager e-mail** — عنوان للإشعارات عبر بوابة SMS أو جهاز النداء (pager)
- **Options** — خيارات خاصة بكل صندوق بريد (نفس الخيارات الموجودة في `[general]`، ولكن يتم تطبيقها على صندوق البريد هذا فقط)

يحتوي Voicemail على العديد من الخيارات التي تتحكم في سلوكه. في الوقت الحالي، سنلتزم بالخيارات الافتراضية ونركز على تعريف صندوق البريد. بعد قسم `[general]` في الملف، تبدأ في تهيئة معرفات صناديق البريد، كل منها في الـ context الخاص به. مثال:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

يرجى التحقق من الخيارات المتقدمة في الملف `voicemail.conf`.

**الخطوة 3: تهيئة الملف `extensions.conf`.**

الـ subroutine المسمى `stdexten` الذي تم عرضه سابقاً (تحت عنوان *Subroutines with GOSUB*) هو بالضبط معالج المكالمات/Voicemail الذي تحتاجه هنا: فهو يقوم بطلب الـ extension ويستخدم قيمة متغير القناة `${DIALSTATUS}` لتوجيه مسار المكالمة إلى الترحيب المناسب في Voicemail (`b` في حالة الانشغال، `u` في حالة عدم التوفر). قم باستدعائه باستخدام `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` من كل extension في `extensions.conf`.

## استخدام تطبيق VoiceMailMain()

يُستخدم التطبيق voicemailmain() لتهيئة صندوق البريد الصوتي. يمكن للمستخدمين الاتصال بالتطبيق، وتسجيل رسالة الترحيب الخاصة بهم، والاستماع إلى بريدهم الصوتي. للاتصال بالتطبيق في الـ dialplan، استخدم:

```
exten=>9000,1,VoiceMailMain()
```

ستجد أدناه قائمة بالخيارات المتاحة لهذا التطبيق.

### صيغة تطبيق Voicemail

يسمح هذا التطبيق للطرف المتصل بترك رسالة لقائمة محددة من صناديق البريد. عند تحديد صناديق بريد متعددة، سيتم أخذ رسالة الترحيب من أول صندوق بريد محدد. سيتوقف تنفيذ الـ dialplan إذا لم يكن صندوق البريد المحدد موجوداً. تظهر الصيغة أدناه:

```
 [Synopsis]
Leave a Voicemail message.
[Description]
This application allows the calling party to leave a message for the specified
list of mailboxes. When multiple mailboxes are specified, the greeting will
be taken from the first mailbox specified. Dialplan execution will stop if
the specified mailbox does not exist.
The Voicemail application will exit if any of the following DTMF digits are
received:
    0 - Jump to the 'o' extension in the current dialplan context.
    * - Jump to the 'a' extension in the current dialplan context.
This application will set the following channel variable upon completion:
${VMSTATUS}: This indicates the status of the execution of the VoiceMail
application.
    SUCCESS
    USEREXIT
    FAILED
[Syntax]
VoiceMail(mailbox[@context][&mailbox[@context][&...]][,options])
[Arguments]
options
```

![10-dialplan-advanced-features figure 13](../images/10-dialplan-advanced-features-img13.png)

```
    b: Play the 'busy' greeting to the calling party.
    d([c]): Accept digits for a new extension in context <c>, if played
    during the greeting. Context defaults to the current context.
    g(#): Use the specified amount of gain when recording the voicemail
    message. The units are whole-number decibels (dB). Only works on supported
    technologies, which is DAHDI only.
    s: Skip the playback of instructions for leaving a message to the
    calling party.
    u: Play the 'unavailable' greeting.
    U: Mark message as 'URGENT'.
    P: Mark message as 'PRIORITY'.
```

في جميع الحالات، سيتم تشغيل الملف beep.gsm قبل بدء التسجيل. سيتم تخزين رسائل البريد الصوتي في دليل inbox.

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

إذا ضغط المتصل على 0 (صفر) أثناء الإعلان، فسيتم تحويله إلى الـ extension 'o' (خارج) في الـ context الحالي للبريد الصوتي. يمكن استخدام هذا للخروج إلى عامل الهاتف (operator). إذا ضغط المتصل على # أثناء التسجيل أو انتهت مهلة الصمت، يتوقف التسجيل وينتقل الاتصال إلى الأولوية التالية. تأكد من معالجة الاتصال بعد تشغيل البريد الصوتي، كما هو موضح أدناه.

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### تصنيف رسائل البريد الصوتي كرسائل عاجلة

يمكنك تصنيف بعض الرسائل على أنها "عاجلة" (urgent). تتوفر طريقتان للقيام بذلك:

- تمرير الخيار 'U' في تطبيق voicemail()
- تحديد review=yes في ملف voicemail.conf. عند استخدام هذا الخيار، سيتمكن المستخدم من تصنيف الرسالة كعاجلة بعد تسجيل التعليمات الصوتية.

## إرسال البريد الصوتي إلى البريد الإلكتروني

في بعض الحالات (مثل حالتي)، نحن ببساطة لا نستخدم تطبيق voicemailmain() لقراءة البريد الإلكتروني. من الأبسط والأكثر عملية إرسال جميع الرسائل إلى البريد الإلكتروني مع إرفاق الصوت. باستخدام المعاملين ‘attach’ و ‘delete’، يمكنك إرسال جميع الرسائل إلى البريد الإلكتروني وحذفها من صندوق البريد.

```
attach=yes
delete=yes
```

لإرسال البريد الصوتي إلى البريد الإلكتروني، يستخدم تطبيق voicemail وكيل نقل الرسائل (MTA)، وهو أحد مكونات نظام التشغيل لديك. يستخدم Debian نظام Exim كـ MTA. يتم تعريف التطبيق الذي يرسل البريد الإلكتروني في المعامل ‘mailcmd’.

```
mailcmd =/usr/sbin/sendmail -t
```

في توزيعة Debian من Linux، يكون الـ MTA هو Exim. لتهيئة Exim في Debian، استخدم:

```
dpkg-reconfigure exim4-config
```

يمكنك اختيار جعل الـ MTA الخاص بك يرسل بريداً إلكترونياً مباشرة عبر SMTP أو عبر smarthost (عادةً ما يكون خادم البريد الخاص بشركتك). تحقق مع مسؤول البريد الإلكتروني لديك من أفضل طريقة لإرسال البريد الإلكتروني من خادم Asterisk إلى خادم البريد الإلكتروني الخاص بك.

## تخصيص رسالة البريد الإلكتروني

يمكنك التحكم في كيفية إرسال الرسائل من خلال إعداد المتغيرات التالية: متغيرات موضوع البريد الإلكتروني ونص البريد الإلكتروني:

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

يتم إنشاء نص وموضوع البريد الإلكتروني من قالب تقوم بتعيينه في قسم `[general]` من `voicemail.conf`. يمكنك تعديل كل من النص والموضوع، ولكن الحد الأقصى لحجم الرسالة هو 512 بايت. في القالب، يقوم `\n` بإدراج سطر جديد ويقوم `\t` بإدراج علامة تبويب (tab).

مثال `emailsubject` أدناه مباشر. مثال `emailbody` قريب جداً من الإعداد الافتراضي؛ حيث يعرض الإعداد الافتراضي CIDNAME فقط عندما لا يكون فارغاً، وإلا فإنه يعرض CIDNUM، أو "an unknown caller" عندما يكون كلاهما فارغاً.

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## واجهة الويب للبريد الصوتي

يوجد نص برمجي بلغة Perl في توزيعة المصدر يسمى `vmail.cgi`، ويقع في `contrib/scripts/vmail.cgi` ضمن شجرة مصدر Asterisk (ولا يزال يُشحن مع Asterisk 22). لا يقوم الأمر `make install` بتثبيت هذه الواجهة؛ بل يجب عليك تشغيل `make webvmail` من دليل المصدر. يتطلب هذا النص البرمجي وجود مفسر أوامر Perl وخادم ويب (مثل Apache) مثبتين على الخادم.

```
make webvmail
```

يقوم الهدف `make webvmail` بتثبيت النص البرمجي (بصلاحية setuid root) في دليل CGI الخاص بخادم الويب لديك (`HTTP_CGIDIR`) ونسخ الصور الداعمة من `images/*.gif` إلى `HTTP_DOCSDIR/_asterisk` (افتراضياً `/var/www/html/_asterisk`). إذا كانت تلك المسارات لا تتطابق مع تخطيط خادم الويب الخاص بك، فقم بتعديل المتغيرين `HTTP_CGIDIR` و `HTTP_DOCSDIR` في الملف `Makefile` الموجود في المستوى الأعلى قبل تشغيل الهدف.

## إشعارات البريد الصوتي

يمكنك تهيئة البريد الصوتي لإرسال رسالة إشعار إلى هاتفك عند وجود بريد صوتي جديد. في Asterisk 22، تعمل خاصية مؤشر انتظار الرسائل (MWI) مع هواتف PJSIP و SIP بالإضافة إلى هواتف DAHDI. للإشارة إلى وجود بريد صوتي لم يتم الاستماع إليه، قد يومض ضوء المؤشر أو قد يصدر الهاتف نغمة تنبيه. تحتاج إلى تهيئة صندوق البريد في ملف تهيئة القناة المقابل. مثال: `pjsip.conf` (في قسم endpoint):

```
mailboxes=8590
```

في PJSIP، يتم تعيين تلميح صندوق البريد باستخدام الخيار `mailboxes` داخل قسم endpoint في `pjsip.conf`، بدلاً من الخيار القديم `mailbox=` في `sip.conf`. تتم معالجة اشتراكات MWI بواسطة الوحدة النمطية `res_pjsip_mwi`.

![واجهة الويب لـ Comedian Mail (`vmail.cgi`): تسجيل الدخول إلى البريد الصوتي عبر الويب في Asterisk — أدخل صندوق البريد وكلمة المرور الخاصة بك لتشغيل البريد الصوتي أو حفظه أو إعادة توجيهه أو حذفه من المتصفح. لا يزال هذا التطبيق يأتي مع Asterisk 22 ويتم تثبيته باستخدام `make webvmail`.](../images/10-dialplan-advanced-features-img14.png)

### مختبر: إشعار الرسائل في الهاتف

تم اختبار هذا المختبر باستخدام softphone من نوع SIP.

1. قم بتحرير `pjsip.conf` وأضف `mailboxes=4401` في قسم endpoint للجهاز المسمى 4401.
2. قم بتحرير `extensions.conf` وأنشئ extension لتسجيل بريد صوتي إلى extensions الخاصة بـ 4401.

```
exten=9008,1,voicemail(4401,b)
```

3. انتقل إلى وحدة التحكم (console) وقم بإعادة التحميل.
4. في SipPulse Softphone، افتح إعدادات حساب SIP وقم بتمكين فحص البريد الصوتي (message-waiting) للحساب.
5. اتصل بالرقم 9008 واترك رسالة.
6. لاحظ أيقونة الرسالة على الهاتف.

## استخدام تطبيق الدليل (directory)

يسمح لك هذا التطبيق بالعثور بسرعة على مستخدم للاتصال به. يتم استرجاع قائمة الأسماء والـ extensions المقابلة لها من ملف إعدادات الـ voicemail المسمى voicemail.conf. يمكن عرض صيغة التطبيق باستخدام الأمر core show application directory:

```
-= Info about application 'Directory' =-
[Synopsis]
Provide directory of voicemail extensions.
[Description]
This application will present the calling channel with a directory of
extensions from which they can search by name. The list of names and
corresponding extensions is retrieved from the voicemail configuration file,
"voicemail.conf".
This application will immediately exit if one of the following DTMF digits
are received and the extension to jump to exists:
'0' - Jump to the 'o' extension, if it exists.
'*' - Jump to the 'a' extension, if it exists.
[Syntax]
Directory([vm-context][,dial-context[,options]])
[Arguments]
vm-context
    This is the context within voicemail.conf to use for the Directory.
    If not specified and 'searchcontexts=no' in "voicemail.conf", then
    'default' will be assumed.
dial-context
    This is the dialplan context to use when looking for an extension
    that the user has selected, or when jumping to the 'o' or 'a' extension.
options
    e: In addition to the name, also read the extension number to the
    caller before presenting dialing options.
    f(n): Allow the caller to enter the first name of a user in the
    directory instead of using the last name.  If specified, the optional
    number argument will be used for the number of characters the user should
    enter.
    l(n): Allow the caller to enter the last name of a user in the
    directory.  This is the default.  If specified, the optional number
    argument will be used for the number of characters the user should enter.
    b(n):  Allow the caller to enter either the first or the last name
    of a user in the directory.  If specified, the optional number argument
    will be used for the number of characters the user should enter.
    m: Instead of reading each name sequentially and asking for
    confirmation, create a menu of up to 8 names.
    p(n): Pause for n milliseconds after the digits are typed.  This
    is helpful for people with cellphones, who are not holding the receiver
    to their ear while entering DTMF.
    NOTE: Only one of the <f>, <l>, or <b> options may be specified.
    *If more than one is specified*, then Directory will act as  if <b> was
    specified.  The number of characters for the user to type defaults to
    '3'.
```

### مختبر: استخدام تطبيق الدليل (directory)

1. قم بتحرير ملف voicemail.conf لإضافة اثنين من الـ extensions في الـ dialplan

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. قم بإنشاء هذه الـ extensions في الـ dialplan الخاص بك

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. انتقل إلى الـ console وقم بإعادة التحميل reload
4. اتصل بالرقم 9006 وقم بتسجيل اسم لكل extension (4400, 4401)
5. اتصل بالرقم 9007 وحدد الأحرف الثلاثة الأولى من اسم العائلة لأحد الـ extensions (على سبيل المثال Eas=327). إذا كان هذا هو الخيار الصحيح، اضغط على ‘1’ للتحويل إلى الاسم.

## Lab: Putting it all together

حتى الآن، تعلمت العديد من مفاهيم الـ dialplan. دعنا نضع كل التطبيقات، والوظائف، والمفاهيم في مثال لـ dialplan حتى تتمكن من فهم كيفية استخدامها معاً. دعنا نرشدك خلال إعداد الـ PBX بالكامل للسيناريو الموضح أدناه.

- 4 analog trunks
- 16 SIP-based extensions
- 3 service classes:
    - restrict (internal, local, and 1-800)
    - ld (long distance)
    - ldi (international)
- After-hours message
- Auto attendant

### Step 1 – Configuring channels

**Analog trunks (`chan_dahdi.conf`).** أولاً، سنقوم بتهيئة الـ analog trunks في ملف تهيئة قنوات DAHDI المسمى `chan_dahdi.conf`. في هذه الحالة، سنستخدم بطاقة T400P من Digium مع 4 واجهات FXO. لنفترض أن المشغل (driver) قد تم تحميله بالفعل وأن ملف تهيئة المشغل (/etc/dahdi/system.conf) مهيأ بشكل صحيح.

![10-dialplan-advanced-features figure 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**SIP channels (`pjsip.conf`).** لقد اخترنا ترقيم الـ dialplan من 2000 إلى 2099. سيتم استخدام اثنين من الـ codec: G.729 و G.711 ulaw. سيتم استخدام الأول للهواتف التي تستخدم Asterisk عبر الإنترنت أو WAN، بينما سيتم استخدام الثاني للهواتف التي تستخدم الشبكة المحلية. في `pjsip.conf`، سنقوم بتحديد الأجهزة التي ستنتمي إلى كل فئة من فئات الخدمة (restrict, ld, ldi). لتقليل التعرض لهجمات القوة الغاشمة (brute force)، سنستخدم عناوين MAC الخاصة بالهواتف كأسماء للأجهزة. أنصحك بشدة باستخدام كلمات مرور قوية لتجنب هجمات القوة الغاشمة!

نقوم بتعريف transport وثلاثة قوالب قابلة لإعادة الاستخدام — قاعدة endpoint مع الـ codecs المشتركة، و digest auth، و AOR بجهة اتصال واحدة — ثم نربط كل جهاز بالقوالب ونقوم فقط بتجاوز ما يختلف (سياق فئة الخدمة الخاص به وبيانات الاعتماد). يصبح `host=dynamic` عبارة عن AOR يسجل الهاتف نفسه عليه، ويصبح `directmedia` هو `direct_media`:

```ini
; pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[endpoint-base](!)
type=endpoint
disallow=all
allow=ulaw,gsm
direct_media=yes

[auth-digest](!)
type=auth
auth_type=digest

[aor-single](!)
type=aor
max_contacts=1

[00001A000002](endpoint-base)
context=restrict
auth=00001A000002
aors=00001A000002
mailboxes=20
[00001A000002](auth-digest)
username=00001A000002
password=#s2cr2t#
[00001A000002](aor-single)

[00001A000003](endpoint-base)
context=ld
dtmf_mode=rfc4733
auth=00001A000003
aors=00001A000003
mailboxes=20
[00001A000003](auth-digest)
username=00001A000003
password=#s3cr3t#
[00001A000003](aor-single)

[00001A000004](endpoint-base)
context=ldi
dtmf_mode=rfc4733
auth=00001A000004
aors=00001A000004
mailboxes=20
[00001A000004](auth-digest)
username=00001A000004
password=#s3cr3t#
[00001A000004](aor-single)
```

### Step 2 – Configure the dial plan

الآن لنبدأ في تهيئة extensions.conf. قم بتعريف الـ extensions الداخلية والاتصال المحلي

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

تعريف LD (long distance)

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

تعريف المكالمات الدولية

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Step 3 - Receiving calls using an auto-attendant

لاستقبال المكالمات، استخدم سياقين (contexts). الأول مخصص للتشغيل في ساعات العمل العادية، حيث سيتم استقبال المكالمة بواسطة auto-attendant. الثاني مخصص لساعات ما بعد العمل، حيث سيتلقى المتصل رسالة مثل "لقد اتصلت بشركة XYZ، ساعات عملنا العادية هي من 08:00 صباحاً إلى 06:00 مساءً؛ إذا كنت تعرف رقم الـ extension الوجهة، يمكنك محاولة طلبه الآن أو إنهاء المكالمة." القوائم: ساعات العمل العادية، ساعات ما بعد العمل. في القوائم أدناه، سيقوم النظام بتشغيل رسالة تحذر المتصل من أن الشركة تم الوصول إليها بعد ساعات العمل العادية، مما يسمح للمتصل بطلب رقم الـ extension الوجهة (قد يكون هناك شخص ما يعمل بعد ساعات العمل العادية).

```
[incoming]
include=>normalhours,08:00-18:00,mon-fri,*,*
include=>afterhours,18:00-23:59,*,*,*
include=>afterhours,00:00-07:59,*,*,*
include=>afterhours,*,sat-sun,*,*
[normalhours]
exten=>s,1,Goto(mainmenu,s,1)
[afterhours]
exten=>s,1,Background(afterhours)
exten=>s,2,hangup()
exten=>i,1,hangup()
exten=>t,1,hangup()
include=>restrict
```

القوائم: الرئيسية والمبيعات. خلال ساعات العمل العادية، يتم الرد على المكالمة بواسطة قائمة auto-attendant، حيث يتلقى المتصل رسالة مثل "مرحباً بكم في شركة XYZ؛ اطلب 1 للمبيعات، 2 للدعم الفني، 3 للتدريب، أو رقم الـ extension المطلوب".

```
[globals]
OPERATOR=PJSIP/2060
SALES=PJSIP/2035
TECHSUPPORT=PJSIP/2004
TRAINING=PJSIP/2036
[mainmenu]
exten=> s,1,Background(welcome)
exten=>1,1,Goto(sales,s,1)
exten=>2,1,Goto(techsupport,s,1)
exten=>3,1,Goto(training,s,1)
exten=>i,1,Playback(Invalid)
exten=>i,2,hangup()
exten=>t,1,Dial(${OPERATOR},20,Tt)
include=>restrict
[sales]
exten=>s,1,Dial(${SALES},20,Tt)
[techsupport]
exten=>s,1,Dial(${TECHSUPPORT},20,Tt)
[training]
exten=>s,1,Dial(${TRAINING},20,Tt)
```

مع كل هذه العبارات، أصبحت وظائف الـ dialplan الخاصة بك جاهزة الآن. في القسم التالي، سنوضح كيفية تشغيل الـ PBX.

## ملخص

في هذا الفصل، تعلمت كيفية استقبال المكالمات باستخدام IVR أو المجيب الآلي. لقد درست مفهوم تضمين الـ context وطبقت بضعة أمثلة. تم استخدام الـ subroutines لتجنب التكرار في الكتابة، واستُخدمت قاعدة بيانات Asterisk (المعروفة بـ AstDB، والتي تعتمد على SQLite3 في Asterisk 22) للوظائف التي تتطلب تخزين البيانات (مثل تحويل المكالمات، خاصية عدم الإزعاج، والقوائم السوداء). وأخيراً، تعلمت كيفية تنفيذ سلوكيات ما بعد ساعات العمل، وقمنا بتنفيذ dialplan كامل باستخدام هذه المفاهيم.

## اختبار

1. يستخدم تضمين context المعتمد على الوقت الصيغة `include => context,<times>,<weekdays>,<mdays>,<months>`. ماذا تفعل `include => normalhours,08:00-18:00,mon-fri,*,*`؟
   - أ. تنفيذ الـ extensions من الاثنين إلى الجمعة، من 08:00 إلى 18:00
   - ب. تنفيذ الخيارات كل يوم في جميع الأشهر
   - ج. لا شيء؛ الصيغة غير صالحة
2. في Asterisk الحديث (بما في ذلك Asterisk 22)، يتم فصل حقول `include =>` المعتمدة على الوقت و `GotoIfTime()` بأي رمز؟
   - أ. الرمز `|`
   - ب. الفاصلة `,`
   - ج. الفاصلة المنقوطة `;`
   - د. الشرطة المائلة `/`
3. للاتصال بعدة قنوات في وقت واحد (رنينها جميعاً في آن واحد)، تقوم بفصلها داخل `Dial()` باستخدام الرمز ___.
4. قائمة صوتية تقوم بتشغيل رسالة توجيهية أثناء انتظار المتصل لطلب extension يتم إنشاؤها عادةً باستخدام التطبيق ___.
5. يمكنك تضمين محتويات ملف آخر داخل `extensions.conf` باستخدام العبارة ___ (ملاحظة: هذا يختلف عن عبارة context الخاصة بـ `include =>`).
6. في Asterisk 22، يتم دعم قاعدة بيانات AstDB المدمجة بواسطة:
   - أ. Berkeley DB v1
   - ب. MySQL
   - ج. SQLite3
   - د. PostgreSQL
7. عند استخدام `Dial(type1/identifier1&type2/identifier2)`، يقوم Asterisk بالاتصال بكل قناة بالتسلسل، منتظراً 20 ثانية بينها.
   - أ. خطأ
   - ب. صح
8. مع تطبيق Background()، يجب عليك الانتظار حتى تنتهي الرسالة من التشغيل قبل أن تتمكن من الضغط على رقم DTMF لاختيار خيار.
   - أ. خطأ
   - ب. صح
9. بالنظر إلى الصيغة `Goto([[context,]extension,]priority)`، أي مما يلي يعد استدعاءً صالحاً لتطبيق Goto()؟ (حدد كل ما ينطبق)
   - أ. Goto(context,extension)
   - ب. Goto(context,extension,priority)
   - ج. Goto(extension,priority)
   - د. Goto(priority)
10. لحذف مفتاح واحد من AstDB في dialplan الخاص بـ Asterisk 22، تستخدم:
    - أ. التطبيق `DBdel()`
    - ب. الدالة `DB_DELETE()`
    - ج. التطبيق `DBdeltree()`
    - د. التطبيق `LookupBlacklist()`

**الإجابات:** 1 — أ · 2 — ب · 3 — `&` · 4 — Background() · 5 — #include · 6 — ج · 7 — أ · 8 — أ · 9 — ب، ج، د · 10 — ب
