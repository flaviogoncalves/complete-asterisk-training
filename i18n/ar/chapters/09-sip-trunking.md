# SIP trunking, DID & the PSTN

إن نظام PBX الذي لا يمكنه الاتصال إلا بنفسه ليس مفيداً جداً. عاجلاً أم آجلاً، يجب على كل نظام الوصول إلى بقية العالم — شبكة الهاتف العامة (PSTN)، أو مزود SIP، أو نظام PBX آخر. الرابط الذي يحمل تلك المكالمات هو **trunk**. في عصر TDM، كان الـ trunk عبارة عن دائرة مادية: خط T1/E1 PRI أو مجموعة من خطوط FXO التناظرية. أما اليوم، فهو دائماً تقريباً **SIP trunk** — وهو اتصال منطقي بمزود خدمة هاتف عبر الإنترنت (ITSP) يتم نقله عبر نفس شبكة IP التي يُنقل عبرها كل شيء آخر.

يوضح هذا الفصل كيفية توصيل Asterisk 22 بمزود ITSP باستخدام PJSIP، وكيفية الاختيار بين الـ trunk القائم على التسجيل والـ trunk القائم على IP، وكيفية توجيه أرقام DID الواردة إلى الوجهة الصحيحة، وكيفية إجراء المكالمات الصادرة مع معرف المتصل الصحيح وتنسيق E.164، وكيفية بناء آليات تجاوز الفشل (failover) والتوجيه بأقل تكلفة عبر عدة trunks. نختتم الفصل بمعالجة NAT للـ trunks ومختبر عملي يقوم بإعداد نظام Asterisk ثانٍ (مع SIPp) كمزود ITSP وهمي حتى تتمكن من إجراء مكالمات حقيقية عبر الـ trunk.

تم التحقق من كل ما ورد هنا مقابل مختبر Asterisk 22.10.0 الخاص بالكتاب؛ ونمط كائن الـ trunk هو نفس النمط الذي تم تقديمه في *Building your first PBX with PJSIP* و *SIP & PJSIP in depth*.

## الأهداف

بحلول نهاية هذا الفصل، يجب أن تكون قادراً على:

- توصيل Asterisk 22 بمزود خدمة اتصالات عبر الإنترنت (ITSP) باستخدام PJSIP
- الاختيار بين الـ trunks القائمة على التسجيل (registration-based) وتلك القائمة على عنوان IP (ثابتة)
- توجيه الـ DIDs الواردة إلى الـ extension أو الـ IVR أو قائمة الانتظار الصحيحة
- توجيه المكالمات الصادرة مع معرف المتصل (caller-ID) الصحيح وتنسيق E.164
- بناء آلية تجاوز فشل الـ trunk وتوجيه المكالمات بأقل تكلفة باستخدام `${DIALSTATUS}`
- التعامل مع الـ NAT للـ trunks على مستوى الـ transport والـ endpoint

## ما هو الـ SIP trunk

الـ SIP trunk هو مسار صوتي منطقي بين نظام الـ PBX الخاص بك ونظام SIP آخر. من الناحية العملية، يكون ذلك "النظام الآخر" أحد أمرين:

- **مزود خدمة هاتفية عبر الإنترنت (ITSP).** وهو ناقل تجاري يبيعك خدمات إنشاء وإنهاء المكالمات، وعادةً ما يبيعك مجموعة من أرقام الهواتف (DIDs). تقوم بتوجيه Asterisk إلى مضيف الإشارات الخاص بالمزود، ويقوم المزود بتوصيل مكالماتك بشبكة PSTN الأوسع. هكذا تصل معظم الأنظمة الحديثة إلى شبكة الهاتف — دون الحاجة إلى أجهزة هاتفية.
- **بوابة PSTN.** جهاز (أو نظام Asterisk آخر) يحتوي على واجهات PSTN مادية — مثل بطاقة PRI، أو منافذ FXO تناظرية، أو بوابة GSM/4G — ويقدمها لنظام الـ PBX الخاص بك كـ SIP. تقوم البوابة بتحويل TDM إلى SIP؛ ومن وجهة نظر Asterisk، يعتبر هذا مجرد SIP trunk آخر.

في كلتا الحالتين، في PJSIP يعتبر الـ trunk **مجرد endpoint**. نفس عائلة الكائنات التي استخدمتها للهاتف — `endpoint`، و`auth`، و`aor`، واختياريًا `identify` و`registration` — هي التي تبني الـ trunk. تكمن الاختلافات في التفاصيل: يقوم الـ trunk بالمصادقة *صادرة* (أنت العميل، لذا توضع بيانات الاعتماد في `outbound_auth` وليس في `auth`)، وعادةً لا يقوم بتسجيل user agent لديك (أنت من يسجل *لديه*، أو يرسل إليك حركة المرور من IP معروف)، ويقوم بتوجيه المكالمات الواردة إلى context مخصص مثل `from-pstn` بدلاً من `from-internal`.

> **مقارنة بـ TDM trunk القديم.** كان الـ PRI يمنحك عددًا ثابتًا من قنوات B (23 في T1، و30 في E1) ويقوم بإرسال إشارات إعداد المكالمة عبر قناة D مخصصة (راجع فصل *Legacy channels*). لا يحتوي الـ SIP trunk على عدد قنوات ثابت — فالسعة تعتمد على النطاق الترددي الخاص بك، وسياسة المزود، وأي حدود لـ `max_contacts`/concurrent-call. كانت معرف هوية المتصل (Caller-ID)، وDID، وتقدم المكالمة التي كانت تُنقل سابقًا عبر عناصر معلومات ISDN، تُنقل الآن عبر ترويسات SIP وSDP.

هناك طريقتان يوافق بهما الـ ITSP على تبادل حركة المرور معك، وهما تحددان كيفية بناء الـ trunk: **قائمة على التسجيل (registration-based)** و**قائمة على الـ IP (ثابتة/static)**. سنتناول كل واحدة منهما تباعًا.

## الجذوع القائمة على التسجيل

الجذع القائم على التسجيل هو النموذج المستخدم عندما يتوقع المزود أن تقوم *أنت* بتسجيل الدخول *إليهم*. يقوم Asterisk الخاص بك بإرسال `REGISTER` من نوع SIP بشكل دوري إلى المزود، مع المصادقة باستخدام اسم مستخدم وكلمة مرور، تماماً بالطريقة التي يسجل بها الهاتف في نظام PBX الخاص بك. هذا أمر شائع عندما يكون عنوان IP العام الخاص بك ديناميكياً، أو عندما تكون خلف NAT، أو عندما يقوم المزود ببساطة بتحديد هوية العملاء بواسطة بيانات اعتماد SIP بدلاً من عنوان IP.

في PJSIP، يوجد تسجيل الدخول الصادر في كائن `registration` مخصص. وهو يحل محل سطر `register =>` الفردي الذي كان يستخدمه برنامج التشغيل `chan_sip` الذي تمت إزالته في `sip.conf`. إليك جذع تسجيل كامل لمزود خيالي، باتباع النمط الذي تم التحقق منه من الفصول السابقة — لاحظ `outbound_auth` (وليس `auth`)، و `server_uri`/`client_uri` (وليس `server`/`client`)، و `from_user`/`from_domain` على الـ endpoint، و `dtmf_mode=rfc4733`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-auth]
type=auth
auth_type=digest
username=4830001000
password=Lab-itsp-secret

[itsp-aor]
type=aor
contact=sip:itsp.example.com:5060

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:itsp.example.com:5060
client_uri=sip:4830001000@itsp.example.com:5060
contact_user=4830001000
retry_interval=60
```

بضع ملاحظات يجب الانتباه إليها:

- **`auth_type=digest`، وليس `userpass`.** كلاهما ينتج نفس مصادقة الـ digest، ولكن في Asterisk 22، فإن `userpass` (و `md5` القديم) **مهملان ويتم تحويلهما بصمت إلى `digest`**. يفضل استخدام `digest` في التكوين الجديد؛ ستظل ترى `userpass` في الملفات القديمة وفي الفصول السابقة من هذا الكتاب.
- **`outbound_auth` على كل من الـ endpoint وعملية التسجيل.** يستخدم التسجيل هذا الكائن للمصادقة على `REGISTER`؛ ويستخدم الـ endpoint هذا الكائن للرد على `407 Proxy Authentication Required` الذي يرسله المزود عائداً إلى `INVITE` صادر. يمكنهما مشاركة كائن `auth` واحد.
- **`from_user` / `from_domain`.** يرفض العديد من المزودين المكالمات التي لا يحمل ترويسة (header) الـ `From` الخاصة بها رقم حسابك ونطاقهم (domain). هذان الخياران يضبطان ذلك بالضبط.
- **`contact_user=4830001000`.** يصبح هذا جزء المستخدم من الـ `Contact` الذي تسجله، حتى يعرف المزود الرقم الذي يجب توجيه المكالمات الواردة إليه. إنه المعادل الحديث للاحقة `/9999` في سطر `register =>` القديم.
- **`retry_interval=60`.** إذا فشل التسجيل، أعد المحاولة كل 60 ثانية.

بعد إعادة التحميل، قم بتأكيد التسجيل باستخدام `pjsip show registrations`. في المختبر — حيث لا يستجيب `itsp.example.com` فعلياً — يبدو الجدول كالتالي:

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

تقوم لاحقة `(exp. Ns)` بالعد التنازلي للثواني حتى المحاولة التالية؛ بمجرد أن تصل إلى الصفر، تقرأ لفترة وجيزة `(exp. Ns ago)` قبل أن تبدأ إعادة المحاولة. مقابل مزود حقيقي، يقرأ عمود `Status` القيمة `Registered` مع الثواني المتبقية حتى التحديث التالي. تعني `Rejected` (أو `Unregistered`) أن المزود لم يقبل تسجيل الدخول — قم بتفعيل `pjsip set logger on` واقرأ رد `401`/`403`، والذي يكون في الغالب خطأ في اسم المستخدم، أو كلمة المرور، أو نطاق `client_uri`.

## IP-based (static) trunks

النموذج الثاني لا يحتاج إلى أي تسجيل على الإطلاق. يعرف المزود عنوان IP العام الخاص بك ويرسل المكالمات مباشرة إليه؛ وبالمقابل، تقوم أنت بإرسال المكالمات إلى عنوان IP الخاص بالإشارات (signalling) المعروف للمزود. يتم التحقق من الهوية بواسطة **عنوان IP المصدر**، وليس بواسطة بيانات اعتماد SIP. هذا هو النمط المعتاد للـ trunks بين خادمين تتحكم فيهما، أو لـ trunk خاص بالمؤسسات حيث يمتلك كلا الطرفين عناوين ثابتة.

الكائن الرئيسي هو `identify`. فهو يخبر Asterisk بما يلي: "أي طلب SIP يصل من *هذا* الـ IP ينتمي إلى *ذلك* الـ endpoint." وبدونه، يحاول PJSIP مطابقة طلب وارد مع endpoint بواسطة مستخدم `From`، وهو ما لن تستوفيه حركة مرور بيانات شركة الاتصالات — لذا سيتم رفض المكالمة أو تحويلها إلى الـ endpoint المسمى `anonymous`.

يستغني الـ trunk الثابت عن الكائن `registration` ويضيف `identify`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-aor]
type=aor
contact=sip:203.0.113.10:5060

[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
```

يقبل `match` عنوان IP، أو نطاق CIDR، أو اسم مضيف (hostname). **يتم حل أسماء المضيفين مرة واحدة فقط، عند تحميل الإعدادات**، لذا إذا تغير عنوان IP الخاص بالمزود، يجب عليك إعادة التحميل. بالنسبة لشركة اتصالات تنشر العديد من بوابات الوسائط (media gateways)، قم بإدراج كل عنوان IP للإشارات — يمكنك تكرار `match` أو إعطاء نطاق CIDR:

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

تحقق مما سيقبله Asterisk باستخدام `pjsip show identifies`. تم التقاط هذا من المختبر (السطر `sipp-identify` هو الـ endpoint الخاص بـ SIPp الموجود مسبقاً في المختبر):

```
*CLI> pjsip show identifies

 Identify:  <Identify/Endpoint...........................................................>
      Match:  <criteria...........................>
==========================================================================================

 Identify:  itsp-identify/itsp
      Match: 172.30.0.50/32

 Identify:  sipp-identify/sipp
      Match: 172.30.0.0/24

Objects found: 2
```

### الآثار الأمنية

يعتبر الـ trunk القائم على IP بدون مصادقة بمثابة باب، و `identify`/`match` هو القفل الوحيد عليه. إذا قمت بـ `match` لنطاق واسع جداً — أو إذا تمكن مهاجم من انتحال عنوان IP المصدر — فإن المكالمات ستصل إلى الـ context المسمى `from-pstn` دون مصادقة. هناك دفاعان، يُستخدمان معاً:

- **طابق بأضيق نطاق ممكن.** فضل عناوين IP المضيفة المحددة على نطاقات CIDR الواسعة. فقط عناوين IP الخاصة بإشارات المزود الحقيقية هي التي يجب أن توضع في `match`.
- **اقرنه بـ ACL.** يمكن لـ PJSIP إسقاط حركة المرور في طبقة SIP قبل أن تصل إلى أي endpoint، باستخدام كائن `type=acl` (أو `acl.conf`):

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

لا يحتاج قسم `type=acl` إلى أي مرجع: يطبق `res_pjsip_acl` كل كائن من هذا النوع على *جميع* حركة مرور SIP الواردة قبل أن تصل إلى أي endpoint. (الخياران `acl` و `contact_acl` في الكائن يسحبان قوائم القواعد المسماة من `acl.conf` بدلاً من إدراج `permit`/`deny` بشكل مضمن كما في المثال أعلاه.) المبدأ هو نفسه المذكور في فصل SIP: ارفض كل شيء، ثم اسمح فقط بما تثق به. ومهما كان ما يفعله الـ trunk context الخاص بك، **لا تسمح له أبداً بالوصول إلى سياق (context) يمكنه الاتصال بالخارج إلى PSTN** دون قاعدة متعمدة وموثقة — فهذه هي الثغرة الكلاسيكية للاحتيال الهاتفي (toll-fraud).

> **أي نموذج يجب أن أستخدم؟** إذا قدم لك المزود اسم مستخدم وكلمة مرور، فاستخدم trunk من نوع **registration**. إذا طلبوا عنوان IP الخاص بك وقدموا لك عنوانهم، فاستخدم trunk من نوع **identify**. يدعم بعض المزودين كلاهما؛ العديد من الـ trunks الحقيقية تجمع بين التسجيل (حتى يتمكن المزود من العثور عليك) و الـ identify (حتى تتم مطابقة طلبات INVITE الواردة من بوابات الوسائط الخاصة بالمزود حتى عندما تصل من عنوان IP مختلف عن عنوان المسجل).

## توجيه المكالمات الواردة والتعامل مع DID

بمجرد وصول المكالمات الواردة، فإنها تهبط في `context` الخاص بـ endpoint — وهنا `from-pstn`. إن **DID** (رقم الاتصال المباشر للداخل) هو ببساطة الرقم الذي يتم طلبه والذي يرسله المزود إليك في request URI. تكمن مهمتك في dialplan في تعيين كل DID إلى وجهة محددة: extension واحد، أو IVR، أو قائمة انتظار، أو مجموعة رنين.

يتم مطابقة الرقم الذي يرسله المزود كـ `${EXTEN}` في `from-pstn`. يعتمد مقدار ما تراه منه على المزود — فبعضهم يرسل رقم E.164 الكامل (`+4830001000`)، وبعضهم يرسل الرقم الوطني، وبعضهم يرسل فقط الأرقام القليلة الأخيرة. افحص مكالمة واردة حقيقية باستخدام `pjsip set logger on` وانظر إلى request URI قبل كتابة الأنماط.

### توجيه DID واحد إلى extension واحد

الحالة الأبسط — توجيه DID واحد مباشرة إلى هاتف:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### توجيه DID واحد إلى IVR (مجيب آلي)

رقم رئيسي يجب أن يرد بقائمة بدلاً من رنين هاتف:

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` هو context المجيب الآلي الذي قمت ببنائه في فصول dialplan (`Background()` + `WaitExten()`). توجيه الـ DID هو مجرد `Goto`.

### توجيه DID واحد إلى قائمة انتظار

خط دعم يجب أن يصل إلى قائمة انتظار مكالمات:

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### العديد من أرقام DID في وقت واحد

عندما تشتري مجموعة من الأرقام، فإن استخدام نمط يحافظ على صغر حجم dialplan. لنفترض أن نطاق DID الخاص بك هو `4830003000`–`4830003099` وأن المزود يرسل الرقم الكامل؛ قم بتعيين آخر رقمين من كل DID إلى الـ extension `60xx`:

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

يأخذ `${EXTEN:-2}` آخر رقمين (الإزاحة السالبة تُحسب من اليمين)، لذا فإن `4830003007` يرن على `PJSIP/6007`. إن جدول البحث `did => extension` الذي تم إنشاؤه باستخدام `GoSub` أو قاعدة بيانات Asterisk (`AstDB`/`func_odbc`) يوفر قابلية توسع أكبر، ولكن بالنسبة لعدد قليل من الأرقام، تظل الأنماط الصريحة هي الأكثر وضوحاً.

> **التقاط الـ DID غير المطابق.** أضف extension من نوع `i` (غير صالح) إلى `from-pstn` بحيث يقوم الرقم الوارد الموجه بشكل خاطئ بتشغيل إعلان أو رنين على المشغل بدلاً من إسقاط المكالمة بصمت:
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## التوجيه الصادر، معرف المتصل و E.164

تتدفق المكالمات الصادرة في الاتجاه المعاكس: يقوم هاتف داخلي بطلب رقم، فيقوم الـ dialplan الخاص بك بمطابقته، وإزالة أي بادئة وصول، وتعيين معرف المتصل الذي يتوقعه المزود، ثم تسليم المكالمة إلى الـ endpoint الخاص بالـ trunk باستخدام `Dial(PJSIP/<number>@itsp)`.

### إرسال المكالمة إلى الـ trunk

صيغة الـ channel الخاصة بالـ trunk هي `PJSIP/<number>@<endpoint>`: الجزء الذي يسبق `@` يصبح جزء المستخدم من الـ URI للطلب الصادر، والجزء الذي يلي `@` يسمي الـ endpoint الذي يوفر الـ `aor` `contact` الخاص به مضيف الوجهة. قاعدة كلاسيكية لـ "طلب 9 للحصول على خط خارجي":

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

يقوم `${EXTEN:1}` بإزالة رمز الوصول `9` البادئ قبل إرسال الرقم. النمط `_9NXXXXXXXXX` يطابق `9` بالإضافة إلى رقم مكون من 10 أرقام يبدأ رقمه الأول بـ 2–9؛ قم بتعديله ليتناسب مع الـ dial plan الخاص بك.

### معرف المتصل في المكالمات الصادرة

تتجاهل معظم شركات الـ ITSP — أو ترفض بنشاط — معرف المتصل الذي ليس رقماً تمتلكه. قم بتعيين رقم معرف المتصل الصادر إلى أحد أرقام الـ DID الخاصة بك باستخدام وظيفة `CALLERID(num)` قبل `Dial()`، كما هو موضح أعلاه. يمكنك أيضاً تعيين الاسم:

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

إذا كان المزود لا يزال يزيل أو يتجاوز اسم معرف المتصل الخاص بك، فهذه سياستهم — حيث تستمد العديد من شركات الاتصالات الاسم المعروض من قاعدة بيانات CNAM الخاصة بهم والمفهرسة بناءً على الرقم، وليس من ترويسة الـ `From` الخاصة بك.

هناك خياران للـ endpoint يتفاعلان مع هذا:

- **`from_user`** يضبط جزء المستخدم من ترويسة الـ `From` على مستوى الـ SIP، وهو ما يستخدمه بعض المزودين لتحديد حسابك بغض النظر عن `CALLERID(num)`.
- **`trust_id_outbound`** (الافتراضي هو `no`) يتحكم فيما إذا كان Asterisk سيرسل ترويسات الهوية الحساسة للخصوصية (`P-Asserted-Identity`/`P-Preferred-Identity`) صادرة. اترك هذا الخيار معطلاً ما لم يوثق مزودك حاجته إلى PAI، وفي هذه الحالة قم بضبط `trust_id_outbound=yes` و `send_pai=yes`.

### التنميط إلى E.164

E.164 هو تنسيق الأرقام الدولي: يبدأ بـ `+`، متبوعاً برمز الدولة، ثم الرقم الوطني، بدون مسافات أو علامات ترقيم (على سبيل المثال `+5548999990000` أو `+14155550100`). تتوقع شركات الاتصالات بشكل متزايد — أو تشترط — تنسيق E.164 على الـ trunk. بدلاً من تشتيت التنسيق عبر الـ dialplan، قم بالتنميط مرة واحدة في الـ context الصادر.

مثال من أمريكا الشمالية يقبل رقماً محلياً مكوناً من 10 أرقام، أو رقماً مسبوقاً بـ `1` مكوناً من 11 رقماً، أو رقماً بتنسيق E.164 بالفعل، ويقدم دائماً `+1…` إلى الـ trunk:

```
[from-internal]
; 10-digit local: 4155550100  -> +14155550100
exten => _NXXNXXXXXX,1,Set(E164=+1${EXTEN})
 same =>            n,Goto(send-pstn,${E164},1)

; 11-digit with national prefix: 14155550100 -> +14155550100
exten => _1NXXNXXXXXX,1,Set(E164=+${EXTEN})
 same =>             n,Goto(send-pstn,${E164},1)

; already E.164: the user dialled + first
exten => _+X.,1,Goto(send-pstn,${EXTEN},1)

[send-pstn]
exten => _+X.,1,Set(CALLERID(num)=+14155550000)
 same =>     n,Dial(PJSIP/${EXTEN}@itsp,60,tT)
 same =>     n,Hangup()
```

يريد بعض المزودين `+`؛ بينما يريد آخرون الأرقام المجردة. إذا كان مزودك يرفض `+`، قم بإزالته عند الخروج باستخدام `${EXTEN:1}` في الـ `Dial`. المغزى هو أن كل المعرفة بالتنسيق موجودة في مكان واحد، لذا فإن تبديل المزودين — أو إضافة مزود ثانٍ — هو تغيير لسطر واحد فقط.

## تجاوز الفشل والتوجيه بأقل التكاليف

مع وجود trunk واحد، يعني انقطاع الخدمة لدى المزود عدم القدرة على إجراء مكالمات خارجية. أما مع وجود اثنين أو أكثر، يمكنك تجاوز الفشل تلقائياً وحتى اختيار المسار الأرخص لكل وجهة — وهو ما يُعرف بـ *least-cost routing* (LCR).

### تجاوز الفشل باستخدام `${DIALSTATUS}`

تقوم `Dial()` بضبط متغير القناة `${DIALSTATUS}` عند عودتها. القيم التي تهمك لتجاوز الفشل هي `CHANUNAVAIL` (تعني أن الـ trunk لم يكن قابلاً للوصول على الإطلاق) و `CONGESTION` (تعني أن المكالمة رُفضت، على سبيل المثال: جميع الدوائر مشغولة). جرب الـ trunk الأساسي؛ وإذا لم يتمكن من نقل المكالمة، انتقل إلى الـ trunk الاحتياطي:

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

لاحظ الاختيار المتعمد **لعدم** تجاوز الفشل عند `BUSY` أو `NOANSWER` — فهذه القيم تعني أنه تم الوصول إلى *الطرف المتصل به* وقام بالرفض، لذا فإن إعادة المحاولة عبر trunk آخر ستؤدي إلى رنين هاتف رفض المكالمة بالفعل (وقد يكلفك ذلك مكالمة ثانية). أعد التوجيه فقط عندما يفشل الـ trunk نفسه.

### روتين فرعي قابل لإعادة الاستخدام للتوجيه

تكرار هذه المنطق لكل نمط اتصال (dial pattern) هو أمر عرضة للأخطاء. قم بدمجه في روتين `GoSub` يأخذ رقم الوجهة ويجرب كل trunk بالترتيب:

```
[from-internal]
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Set(CALLERID(num)=4830001000)
 same =>   n,Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try2:end)
 same =>   n(try2),Dial(PJSIP/${NUM}@itsp_backup,60,tT)
 same =>   n(try2-chk),GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try3:end)
 same =>   n(try3),Dial(PJSIP/${NUM}@itsp_thirdparty,60,tT)
 same =>   n(end),Return()
```

الآن، كل نمط اتصال خارجي هو عبارة عن استدعاء `GoSub` واحد، ويتم تحديد ترتيب الـ trunk في مكان واحد فقط.

### التوجيه بأقل التكاليف حسب الوجهة

يختار الـ LCR الحقيقي الـ trunk بناءً على وجهة المكالمة. من الأشكال الشائعة مطابقة بادئة الوجهة وإرسال كل فئة من المكالمات إلى المزود الأرخص لها — على سبيل المثال، المكالمات الدولية إلى ناقل جملة والمكالمات المحلية/الوطنية إلى الـ trunk الأساسي الخاص بك:

```
[from-internal]
; international (011 + ...) -> wholesale trunk, then fall back to primary
exten => _9011.,1,GoSub(dialout-intl,s,1(${EXTEN:1}))
 same =>      n,Hangup()
; everything else -> domestic routing
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout-intl]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Dial(PJSIP/${NUM}@itsp_wholesale,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?fb:end)
 same =>   n(fb),Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n(end),Return()
```

بالنسبة لأكثر من بضع بادئات، قم بتخزين جدول المسارات في قاعدة بيانات (`func_odbc`/`AstDB`) وابحث عن الـ trunk حسب البادئة بدلاً من كتابة الأنماط برمجياً (hard-coding). يظل الـ dialplan صغيراً وتعيش الأسعار في جدول يمكنك تعديله دون إعادة تحميل المنطق.

## NAT و trunks

تعد NAT السبب الأكثر شيوعاً لمشاكل الـ trunks — وعادة ما تظهر في شكل صوت أحادي الاتجاه، أو trunk يقوم بالتسجيل ولكنه لا يستقبل مكالمات واردة أبداً. السبب هو نفسه بالنسبة للهواتف (التي تمت تغطيتها في *SIP & PJSIP in depth* و *Designing a VoIP network*): يقوم Asterisk بالإعلان عن تصوره الخاص لعنوانه في SIP و SDP، وخلف NAT يكون هذا العنوان عبارة عن عنوان خاص من نوع RFC 1918 لا يمكن للمزود توجيه البيانات إليه.

بالنسبة للـ trunks، يتكون الحل من جزأين — إعدادات على الـ **transport** (عنوانك العام) وإعدادات على الـ **endpoint** (كيفية التعامل مع وسائط المزود).

### على الـ transport — عنوانك العام

عندما يكون خادم Asterisk نفسه خلف NAT (جهاز سحابي أو محلي بـ IP خاص و IP عام بنسبة 1:1)، أخبر الـ transport بعنوانه العام وما هي الشبكات المحلية. يتم ضبط هذه الخيارات مرة واحدة، على الـ `transport`، وتطبق على كل حركة المرور عبره:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=172.30.0.0/24
local_net=10.0.0.0/8
external_media_address=203.0.113.50
external_signaling_address=203.0.113.50
```

- **`external_signaling_address`** — الـ IP العام الذي يكتبه Asterisk في ترويسات SIP (`Via`، `Contact`) للوجهات خارج `local_net`.
- **`external_media_address`** — الـ IP العام الذي يكتبه Asterisk في سطر SDP `c=` لكي تعود حزم RTP إلى المكان الصحيح. عادة ما يكون مطابقاً لعنوان الإشارات.
- **`local_net`** — الشبكات التي يعاملها Asterisk كشبكات داخلية، بحيث *لا* يقوم بإعادة كتابة العناوين لأقران الشبكة المحلية (LAN). قم بإدراج كل شبكة فرعية داخلية.

### على الـ endpoint — وسائط المزود

يتعامل النصف الآخر مع مزود يقع هو نفسه خلف NAT، أو ببساطة يرسل الوسائط من عنوان مختلف عن ذلك الموجود في الـ SDP الخاص به. قم بضبط هذه الإعدادات لكل endpoint خاص بالـ trunk:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com
```

- **`direct_media=no`** — الحفاظ على تدفق الوسائط عبر Asterisk بدلاً من السماح للطرفين بالتحدث مباشرة. أمر ضروري عبر NAT، ومطلوب على أي حال إذا كنت ترغب في تسجيل المكالمة أو تحويل ترميزها (transcode) أو مراقبتها.
- **`rtp_symmetric=yes`** — سلوك *comedia* الكلاسيكي: إرسال RTP عائداً إلى العنوان الذي جاءت منه الوسائط فعلياً، وليس العنوان الذي يدعيه الـ SDP.
- **`force_rport=yes`** — الرد على SIP من الـ IP/المنفذ المصدر للطلب (RFC 3581)، بدلاً من الوثوق بترويسة `Via`.
- **`rewrite_contact=yes`** — عند ورود رسائل SIP من هذا الـ endpoint، قم بإعادة كتابة ترويسة `Contact` (أو ترويسة `Record-Route` مناسبة) إلى عنوان الـ IP والمنفذ المصدر الذي جاءت منه الحزمة فعلياً. وفقاً لتوثيق الخيار نفسه، فإن هذا "يساعد الخوادم على التواصل مع الـ endpoints التي تقع خلف NATs" و "يساعد في إعادة استخدام اتصالات النقل الموثوقة مثل TCP و TLS."

> **توصية — الهواتف مقابل الـ trunks.** يعتبر `rewrite_contact` دائماً تقريباً الخيار الصحيح للهواتف، لأن عنوان الاتصال المعلن عنه عادة ما يكون عنواناً خاصاً من نوع RFC 1918 غير قابل للتوجيه إليه. في الـ trunks القائمة على IP ثابت، يكون عنوان اتصال المزود عادةً عنواناً عاماً صحيحاً بالفعل، لذا فإن إعادة كتابته غالباً ما تكون غير ضرورية؛ يفضل بعض المشغلين تركه معطلاً هناك وتفعيله فقط لـ trunks التسجيل والهواتف الموجودة خلف NAT. التأثير الموثق لهذا الخيار هو فقط إعادة كتابة `Contact`/`Record-Route` الواردة المذكورة أعلاه — لذا فإن الممارسة الآمنة هي الاختبار مع مشغل الخدمة الخاص بك قبل تفعيله على trunk ثابت.

يمكنك تأكيد الإعدادات الفعلية على أي endpoint باستخدام `pjsip show endpoint <name>` — حيث يتم طباعة `direct_media`، و `rtp_symmetric`، و `force_rport`، و `rewrite_contact`، والبقية في تفريغ المعلمات.

## مختبر — محاكاة ITSP باستخدام Asterisk ثانٍ و SIPp

لست بحاجة إلى trunk مدفوع للتدريب. يحتوي مختبر الكتاب بالفعل على حاوية Asterisk 22.10.0 وحاوية SIPp على شبكة `172.30.0.0/24` خاصة؛ سنتعامل مع حاوية SIPp كـ "ناقل" (carrier) يقوم بإجراء مكالمات واردة، وسنضيف endpoint لـ trunk يوجه تلك المكالمات إلى سياق `from-pstn`.

![SIP trunk بين Asterisk PBX و ITSP: يسجل الـ PBX كحساب واحد، وتطلب المكالمات الصادرة `PJSIP/<num>@trunk`، بينما تهبط المكالمات الواردة في سياق `from-pstn`.](../images/09-sip-trunking-fig01.png)

### 1. إضافة الـ endpoint الخاص بالـ trunk

أضف trunk يعتمد على IP إلى `lab/asterisk/etc/pjsip.conf` يطابق مضيف SIPp الخاص بالمختبر ويوجه المكالمات الواردة إلى `from-pstn`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor

[itsp-aor]
type=aor
contact=sip:172.30.0.50:5060

[itsp-identify]
type=identify
endpoint=itsp
match=172.30.0.50
```

### 2. توجيه الـ DID الوارد

في `lab/asterisk/etc/extensions.conf`، أضف سياق `from-pstn` يقوم بالرد على الـ DID الذي سيطلبه الناقل الوهمي ويقوم بتشغيله، ثم أضف قاعدة للمكالمات الصادرة:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID ${EXTEN} from ${CALLERID(num)})
 same =>             n,Answer()
 same =>             n,Playback(demo-congrats)
 same =>             n,Hangup()
exten => i,1,Playback(ss-noservice)
 same =>  n,Hangup()

[from-internal]
; outbound across the trunk
exten => _9X.,1,Set(CALLERID(num)=4830001000)
 same =>     n,Dial(PJSIP/${EXTEN:1}@itsp,30,tT)
 same =>     n,Hangup()
```

أعد تحميل كلا الملفين (`core reload`) وتحقق من تحميل الـ trunk:

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. إجراء مكالمة واردة عبر الـ trunk

وجه سيناريو SIPp إلى الـ PBX مع جعل الـ DID هو المستخدم المستهدف. يأتي المختبر مرفقاً بـ `lab/sipp/uac_9000.xml`، الذي يقوم بعمل INVITE لـ extension `9000`؛ انسخه إلى `uac_did.xml` وقم بتغيير request-URI/مستخدم `To` من `9000` إلى `4830001000`، ثم قم بتشغيله من حاوية SIPp:

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

راقب المكالمة وهي تصل إلى `from-pstn` على وحدة تحكم Asterisk (يعرض `pjsip set logger on` طلب INVITE الوارد؛ ويعرض `core show channels` قناة `PJSIP/itsp-…` وهي تقوم بتشغيل `demo-congrats`). نظراً لأن IP المصدر لـ SIPp يطابق `identify`، يتم قبول المكالمة بدون مصادقة — وهو بالضبط ما يحدث مع الـ trunk الثابت الخاص بالناقل.

### 4. فحص الـ trunk

التقط التكوين الكامل للـ trunk لملاحظاتك:

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (تحدي إضافي) تحويله إلى trunk تسجيل

قم بتشغيل حاوية Asterisk *الثانية* كـ registrar حقيقي: امنحها `endpoint`+`auth`+`aor` للحساب `4830001000`، ثم على الـ PBX استبدل كتلة `identify` بكتلة `registration` من بداية هذا الفصل (مع توجيه `server_uri` إلى IP الحاوية الثانية). تأكد باستخدام `pjsip show registrations` من أن الحالة تقرأ `Registered`، ثم قم بإجراء مكالمة في كل اتجاه.

## ملخص

يقوم الـ SIP trunk بربط نظام الـ PBX الخاص بك بالعالم الخارجي، وفي PJSIP هو مجرد endpoint مبني من نفس عائلة `endpoint` + `auth` + `aor` التي تعرفها بالفعل، بالإضافة إلى `identify` أو `registration`. استخدم **registration trunk** (`type=registration` مع `outbound_auth`) عندما يزودك المزود باسم مستخدم وكلمة مرور؛ واستخدم **IP-based trunk** (`type=identify` مع `match`) عندما يتم التحقق من الهوية عبر الـ IP المصدر — وقم بتأمين الأخير باستخدام `match` ضيق و `acl`، لأن الـ trunk غير الموثق يعد هدفاً للاحتيال الهاتفي. بالنسبة للمكالمات الواردة، يصل الـ DID الخاص بالمزود كـ `${EXTEN}` في الـ context الخاص بك المسمى `from-pstn`، حيث تقوم بتوجيهه إلى extension، أو IVR، أو طابور انتظار — وتعمل الأنماط و `${EXTEN:-N}` على إبقاء مجموعات الـ DID مدمجة. بالنسبة للمكالمات الصادرة، اضبط `CALLERID(num)` على رقم تمتلكه، وقم بعملية تطبيع (normalize) إلى E.164 في مكان واحد، ثم سلم المكالمة إلى `PJSIP/<number>@trunk`. ابنِ المرونة من خلال تجربة عدة trunks والتفرع بناءً على `${DIALSTATUS}` (حيث تعني `CHANUNAVAIL`/`CONGESTION` إعادة التوجيه؛ بينما لا تعني `BUSY`/`NOANSWER` ذلك)، وضع التوجيه بأقل تكلفة في جدول `GoSub`. أخيراً، الـ NAT للـ trunks ذو جانبين: `external_media_address`/`external_signaling_address`/`local_net` على الـ **transport** لعنوانك العام، و `direct_media=no`، و `rtp_symmetric`، و `force_rport`، و `rewrite_contact` على الـ **endpoint** لوسائط المزود.

## اختبار

1. في PJSIP، تتم الإشارة إلى بيانات الاعتماد المستخدمة لمصادقة مكالمة *صادرة* (outbound) أو تسجيل لدى مزود خدمة من خلال:
   - أ. `auth=`
   - ب. `outbound_auth=`
   - ج. `secret=`
   - د. `remotesecret=`
2. يجب عليك استخدام trunk من نوع `type=registration` عندما:
   - أ. يقوم المزود بتعريفك من خلال عنوان IP المصدر الخاص بك.
   - ب. يمنحك المزود اسم مستخدم وكلمة مرور ويتوقع منك تسجيل الدخول.
   - ج. لا ترغب أبداً في أن يقوم Asterisk بإرسال `REGISTER`.
   - د. يكون الـ trunk بين خادمين ذوي عناوين IP ثابتة تتحكم أنت بهما.
3. الخيار `match` الخاص بالكائن `identify` يقبل (اختر كل ما ينطبق):
   - أ. عنوان IP
   - ب. نطاق CIDR
   - ج. اسم مضيف (يتم حله عند وقت تحميل الإعدادات)
   - د. اسم مستخدم SIP فقط
4. في Asterisk 22، يعتبر `auth_type=userpass`:
   - أ. القيمة الصالحة الوحيدة
   - ب. مهملاً (deprecated) ويتم تحويله إلى `digest`
   - ج. محذوفاً ويسبب خطأ في التحميل
   - د. مطلوباً للتسجيل الصادر
5. يصل رقم DID الوارد إلى الـ dialplan كـ:
   - أ. `${CALLERID(num)}`
   - ب. `${EXTEN}` في الـ `context` الخاص بـ endpoint الـ trunk
   - ج. `${DIALSTATUS}`
   - د. `${CONTEXT}`
6. لإرسال آخر رقمين من الـ DID المطلوب `4830003007` إلى extension، ستستخدم:
   - أ. `${EXTEN:2}`
   - ب. `${EXTEN:0:2}`
   - ج. `${EXTEN:-2}`
   - د. `${EXTEN:8}`
7. بعد `Dial()` إلى trunk، يجب عليك الانتقال إلى trunk احتياطي تكون فيه قيم `${DIALSTATUS}` (اختر اثنتين):
   - أ. `CHANUNAVAIL`
   - ب. `BUSY`
   - ج. `CONGESTION`
   - د. `NOANSWER`
8. لتعيين رقم معرف المتصل (caller-ID) الذي يتم تقديمه للمزود قبل الاتصال بالخارج، استخدم:
   - أ. `Set(CALLERID(num)=4830001000)`
   - ب. `Set(from_user=4830001000)`
   - ج. `Set(DIALSTATUS=4830001000)`
   - د. `Set(CONNECTEDLINE(num)=4830001000)`
9. الخيارات التي تخبر Asterisk بعنوانه *العام* عندما يكون الخادم خلف NAT يتم تعيينها في:
   - أ. `endpoint`
   - ب. `aor`
   - ج. `transport` (`external_media_address` / `external_signaling_address`)
   - د. `registration`
10. يؤدي `rtp_symmetric=yes` على endpoint الـ trunk إلى قيام Asterisk بـ:
    - أ. تشفير RTP باستخدام SRTP
    - ب. إرسال RTP مرة أخرى إلى العنوان الذي وصلت منه الوسائط فعلياً، مع تجاهل SDP
    - ج. تعطيل RTP تماماً
    - د. فرض الوسائط المباشرة بين الـ endpoints

**الإجابات:** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
