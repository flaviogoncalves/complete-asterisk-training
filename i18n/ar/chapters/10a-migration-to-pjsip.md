# الانتقال من chan_sip إلى PJSIP: دليل عملي

إذا كنت تقرأ هذا بينما لا يزال لديك خادم Asterisk يعمل بإصدار 13 أو 16 أو 18 في بيئة الإنتاج، فأنت أمام موعد نهائي. إن `chan_sip` — وهو برنامج تشغيل قناة SIP الأصلي الذي يتم ضبطه عبر `sip.conf` — قد **تم إيقاف دعمه في Asterisk 17، وإزالته من البناء الافتراضي في Asterisk 19، وحذفه بالكامل في Asterisk 21**. وهو غير موجود في Asterisk 22 LTS. لا يوجد خيار لإعادة تفعيله، ولا يوجد `noload` للالتفاف عليه، ولا حزمة إضافية يمكن تثبيتها. برنامج تشغيل قناة SIP الوحيد في Asterisk 22 هو **PJSIP** (المكون من `res_pjsip` بالإضافة إلى `chan_pjsip`)، والذي يتم ضبطه عبر `pjsip.conf`.

لذا، فإن الترقية إلى Asterisk 22 تعد بالنسبة لمعظم المواقع *مشروع ترحيل SIP* بقدر ما هي ترقية للإصدار. الخبر السار هو أن البروتوكول المستخدم عبر الشبكة لا يتغير — فالهاتف الذي قام بالتسجيل وإجراء المكالمات بالأمس سيقوم بذلك غداً — كما يوفر Asterisk أداة تحويل للقيام بـ 80% من عملية الترجمة نيابة عنك. هذا الفصل عبارة عن دليل عملي: يغطي مفاهيم الربط، ونص التحويل، وترجمات `sip.conf` → `pjsip.conf` جنباً إلى جنب للحالات التي تستخدمها فعلياً، وتغييرات dialplan و CLI التي تصاحب هذا الانتقال، وترحيل realtime (قاعدة البيانات)، بالإضافة إلى قائمة مراجعة وأبرز العقبات التي قد تواجه المستخدمين.

تم التحقق من كل ما ورد هنا مقابل مختبر Asterisk 22.10.0 الخاص بهذا الكتاب. أما المواد المتعلقة بالإرث البرمجي العميق لـ `chan_sip` ذاته — وعملية تحويل شاملة من البداية إلى النهاية لـ `sip.conf` متعدد الأجهزة — فهي موجودة في فصل *Legacy channels*؛ بينما يعد هذا الفصل رفيقاً مركزاً وموجهاً بأسلوب الوصفات العملية لذلك الفصل.

## الأهداف

بحلول نهاية هذا الفصل، يجب أن تكون قادراً على:

- شرح سبب إزالة `chan_sip` في Asterisk 22 وما الذي يحل محله
- تعيين نموذج peer/user/friend الخاص بـ `sip.conf` على نموذج كائنات PJSIP (endpoint + aor + auth + identify + transport + registration)
- تشغيل نص التحويل `sip_to_pjsip.py` ومراجعة مخرجاته بشكل نقدي
- ترجمة أنواع الأجهزة الشائعة (هاتف مسجل، trunk وارد، تسجيل صادر) من `sip.conf` إلى `pjsip.conf` يدوياً
- ترحيل إعدادات NAT، والوسائط، وDTMF، وcodec، والمصادقة خياراً بخيار
- تحديث الـ dialplan (من `SIP/` إلى `PJSIP/`) وواجهة سطر الأوامر (من `sip show` إلى `pjsip show`)
- ترحيل نشر realtime/ARA من `sippeers`/`sipregs` إلى جداول Sorcery `ps_*`
- العمل من خلال قائمة مراجعة الترحيل وتجنب المخاطر التقليدية

## لماذا يجب عليك الترحيل على الإطلاق

لقد خدم `chan_sip` نظام Asterisk لما يقرب من عقدين من الزمن، لكنه كان يحمل ديوناً معمارية: وحدة نمطية متجانسة، وكتلة تكوين واحدة لكل جهاز، ودعم ضعيف للنقل المتعدد، ومكدس SIP كان قد تخلف عن مواكبة معايير RFCs. أما **PJSIP** — الذي تم بناؤه على مكدس pjproject الناضج من شركة Teluu وتم تقديمه في Asterisk 12 — فقد كان البديل الذي تم بناؤه من الصفر. وبحلول الإصدار Asterisk 21، أنهى مشروع Asterisk المهمة وأزال `chan_sip` من الشجرة البرمجية.

يمكنك التأكد من الوضع على أي نظام Asterisk 22:

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

يعيد الأمر `chan_sip` النتيجة *0 modules loaded* — فهو ببساطة غير موجود. لا يوجد شيء للترحيل *إليه* سوى PJSIP، لذا فإن السؤال الحقيقي الوحيد هو *كيف*، وليس *ما إذا كان يجب القيام بذلك*.

## التعيين المفاهيمي: لا يوجد "نظير" (peer) واحد

التحول الذهني الذي يعيق كل من يأتي من `sip.conf` هو التالي: **PJSIP لا يمتلك `[peer]`.** في `sip.conf` كانت كتلة واحدة بين قوسين — سواء كانت `peer` أو `user` أو `friend` — تصف *كل شيء* يتعلق بالجهاز: بيانات اعتماده، ومكان الوصول إليه، و codec الخاصة به، وسلوك NAT الخاص به، و context الخاص بـ dialplan. يتعمد PJSIP تقسيم تلك الكتلة الواحدة إلى عدة كائنات أصغر ذات غرض واحد، حيث يتم وسم كل منها بـ `type=`، والتي *تشير إلى بعضها البعض بالاسم*:

| كائن PJSIP (`type=`) | المسؤولية |
| --- | --- |
| `endpoint` | هوية معالجة المكالمات الخاصة بالجهاز: codec، و context، و DTMF، والوسائط، و NAT، والمراجع إلى `auth`/`aors`/`transport` الخاصة به |
| `aor` (عنوان السجل) | *أين* يمكن الوصول إلى الجهاز — جهات الاتصال المسجلة أو الثابتة، و `max_contacts`، و qualify |
| `auth` | بيانات الاعتماد (اسم المستخدم/كلمة المرور) للمصادقة الواردة و/أو الصادرة |
| `identify` | مطابقة الطلب الوارد بـ endpoint عن طريق **IP المصدر** بدلاً من المستخدم في `From` |
| `transport` | مقبس (مقابس) الاستماع: البروتوكول، وعنوان/منفذ الربط، وعناوين NAT/الخارجية |
| `registration` | عملية REGISTER **صادرة** من Asterisk إلى مزود الخدمة |

يختفي التمييز بين `friend`/`peer`/`user` تماماً — ففي PJSIP كل شيء هو `endpoint`. لذا، فإن صديق `sip.conf` الواحد يصبح عادةً ثلاثة كائنات (`endpoint` + `auth` + `aor`) تتشارك في اسم واحد وتشير إلى بعضها البعض:

```
                sip.conf                              pjsip.conf
            ┌──────────────┐              ┌──────────┐   ┌──────┐   ┌─────┐
            │   [2000]     │   becomes    │ endpoint │──▶│ auth │   │ aor │
            │ type=friend  │  ─────────▶  │  [2000]  │   │[2000]│   │[2000]│
            │ host=dynamic │              │  auth=───┼──▶└──────┘   └──────┘
            │ secret=...   │              │  aors=───┼───────────────▶ ▲
            └──────────────┘              └────┬─────┘
                                               │ transport=
                                               ▼
                                          ┌───────────┐
                                          │ transport │  (shared by all endpoints)
                                          └───────────┘
```

يعتبر الـ endpoint هو الرابط. فهو يسمي `transport` (أو يرث الافتراضي)، وكائن `auth`، وواحد أو أكثر من `aors`. يتم تغطية نموذج الكائن بعمق في *SIP & PJSIP in depth*؛ وهنا نحتاجه فقط كهدف لكل عملية ترجمة.

## أداة التحويل `sip_to_pjsip.py`

يأتي Asterisk مزوداً بسكريبت Python يقرأ ملف `sip.conf` موجوداً ويكتب ملف `pjsip.conf`. لا يتم تشغيل هذا السكريبت كأمر CLI، بل يوجد في **شجرة مصدر Asterisk**، وليس في الملفات الثنائية المثبتة:

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

في إصدار Asterisk 22.10.0 الخاص بالمختبر، المسار الكامل هو، على سبيل المثال، `/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`. يحتوي المجلد نفسه على `sip_to_pjsql.py` (متغير realtime/SQL، الذي سيتم تناوله لاحقاً) ووحدات المساعدة `astconfigparser.py` و `astdicts.py` و `sqlconfigparser.py`.

### تشغيل الأداة

يأخذ السكريبت وسائط موضعية اختيارية — `[input-file [output-file]]` — والتي تكون افتراضياً `sip.conf` و `pjsip.conf` في المجلد الحالي:

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

خياراته الفعلية الوحيدة هي:

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

يقوم السكريبت بقراءة المدخلات، وطباعة `Converting to PJSIP...`، وكتابة ملف المخرجات. داخلياً، يقوم السكريبت بالمرور على كل قسم `sip.conf`، ويصدر لكل جهاز كائنات `endpoint` و `auth` و `aor` و `registration` و (حيثما أمكن استنتاجها) `transport` المطابقة، مع تطبيق تعيينات الخيارات الموضحة في القسم التالي تلقائياً.

### ما تقوم به الأداة — وحدودها

تعامل مع المخرجات كـ **مسودة أولية، وليس كملف نهائي.** السكريبت صادق بشأن فجواته الخاصة: أي شيء لا يمكن تعيينه بشكل نظيف يُكتب في كتلة محددة بوضوح في أعلى ملف المخرجات:

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[softphone]
qualify = yes
...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
```

لاحظ في ذلك الجزء الفعلي أن `qualify = yes` من نظير `sip.conf` انتهى به المطاف في الكتلة *غير المعينة* — لأن PJSIP يقوم بالتأهيل على **aor** باستخدام `qualify_frequency` (بالثواني)، وليس كقيمة منطقية (boolean) على الجهاز، لذا يتركها السكريبت لك لتقوم بتعيينها بدقة. القيود العملية التي يجب التخطيط لها هي:

- **يتم تخمين النواقل (Transports) ولا يتم تصميمها.** يصدر السكريبت `transport-udp` أساسياً من `bindport`/`bindaddr`، لكنه لا يمكنه معرفة شهادات TLS الخاصة بك، أو احتياجات TCP، أو تخطيط الربط المتعدد الخاص بك. قم بمراجعة وإعادة كتابة الناقل.
- **تحتاج إعدادات NAT والعناوين الخارجية إلى تدخل بشري.** قد لا يتم نقل `externaddr`/`localnet` بشكل سليم؛ تأكد من `external_media_address` و `external_signaling_address` و `local_net` على الناقل يدوياً.
- **`qualify` والمؤقتات المخصصة وحفنة من الخيارات تنتهي في "غير المعينة".** اقرأ تلك الكتلة من الأعلى إلى الأسفل وحدد مصير كل منها.
- **تحتاج قوائم codec و contexts والأمان إلى مراجعة.** تحقق من `allow`/`disallow`، و dialplan الخاص بـ `context`، وتأكد من عدم ترك أي جهاز مفتوحاً دون قصد.

وبالتالي، فإن سير العمل هو: تشغيل السكريبت في ملف *مؤقت*، ومقارنته ومراجعته، ثم دمج الأجزاء الصحيحة في ملف `pjsip.conf` الفعلي الخاص بك، ثم الاختبار بشكل شامل قبل الانتقال إلى بيئة الإنتاج.

## الترجمات جنباً إلى جنب

هذه هي الوصفات. `sip.conf` على اليسار، وما يعادلها من `pjsip.conf` الموثق على اليمين (مكدسة هنا لتناسب عرض الصفحة). تم التحقق من كل اسم خيار وقيمة على اليمين مقابل مختبر Asterisk 22 باستخدام `config show help res_pjsip ...`.

### هاتف يقوم بالتسجيل (`host=dynamic`)

الجهاز الأكثر شيوعاً: هاتف مكتبي أو softphone يقوم بتسجيل الدخول باستخدام secret ويسجل موقعه الخاص.

**النسخة القديمة `sip.conf`:**

```
[2000]
type=friend
host=dynamic
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmfmode=rfc2833
secret=Sup3rSecret
qualify=yes
```

**Asterisk 22 `pjsip.conf`:**

```
[2000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
auth=2000
aors=2000

[2000]
type=auth
auth_type=digest
username=2000
password=Sup3rSecret

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

الخطوات الرئيسية: يتحول `host=dynamic` إلى `aor` مع `max_contacts` (يقوم الجهاز بعمل REGISTER لملء جهة الاتصال الخاصة به)؛ يتحول `secret=` إلى `password=` داخل `type=auth`؛ يتحول `qualify=yes` إلى `qualify_frequency=60` (بالثواني) على الـ **aor**، وليس على الـ endpoint. لا تقم بضبط `max_contacts` على قيمة أعلى من 1 إلا إذا كنت ترغب حقاً في استخدام نفس الحساب على عدة أجهزة في وقت واحد.

### خط وارد (`host=<ip>` / `type=peer`)

مزود يرسل لك مكالمات من عنوان IP معروف. لا يوجد تسجيل هنا — أنت تقوم بمصادقة *حركة مرور الناقل (carrier) من خلال عنوان IP المصدر الخاص به* باستخدام `identify`.

**النسخة القديمة `sip.conf`:**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp-in]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw

[itsp-in]
type=aor
contact=sip:203.0.113.10:5060

[itsp-in]
type=identify
endpoint=itsp-in
match=203.0.113.10
```

الترجمة الحاسمة هي **`insecure=invite` → `identify`**. في `chan_sip`، كان `insecure=invite` يخبر Asterisk "لا تتحدَّ طلبات INVITE الواردة من هذا الـ peer للمصادقة". يحقق PJSIP نفس التأثير عن طريق *مطابقة عنوان IP المصدر مع الـ endpoint* باستخدام `type=identify`/`match=`، وهو أمر أكثر وضوحاً وأكثر أماناً في آن واحد. يتحول الـ `host=` الثابت إلى `contact=` دائم على الـ `aor` حتى تتمكن أيضاً من الاتصال *خارجاً* إلى الناقل. يقبل `match=` عنوان IP، أو نطاق CIDR، أو اسم مضيف (يتم حله في وقت تحميل الإعدادات — قم بإعادة التحميل إذا تغير عنوان IP الخاص بالمزود).

### تسجيل صادر (`register =>`)

عندما يريد المزود *منك* تسجيل الدخول *إليهم*، كان `chan_sip` يستخدم سطراً واحداً من نوع `register =>` في `[general]`. يستبدله PJSIP بكائن `type=registration` مخصص بالإضافة إلى `outbound_auth`.

**النسخة القديمة `sip.conf`:**

```
[general]
register => 1020:supersecret@sip.example.com:5600/9999

[itsp]
type=peer
host=sip.example.com
port=5600
defaultuser=1020
secret=supersecret
fromuser=1020
fromdomain=sip.example.com
context=from-pstn
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
outbound_auth=itsp-auth
aors=itsp-aor
from_user=1020
from_domain=sip.example.com

[itsp-auth]
type=auth
auth_type=digest
username=1020
password=supersecret

[itsp-aor]
type=aor
contact=sip:sip.example.com:5600

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:sip.example.com:5600
client_uri=sip:1020@sip.example.com:5600
contact_user=9999
retry_interval=60
```

قم بمطابقة حقول `register =>` واحداً لواحد: تصبح بيانات اعتماد `1020:supersecret` هي كائن `auth` (يشار إليه باسم `outbound_auth`)؛ ويصبح `@sip.example.com:5600` هو `server_uri`؛ أما لاحقة `/9999` — وهي جزء المستخدم الذي يرسل المزود المكالمات الواردة إليه — فتصبح `contact_user=9999`. يتحول `defaultuser`/`fromuser` و `fromdomain` إلى `from_user` و `from_domain` على الـ endpoint. لاحظ أن `outbound_auth` يظهر *مرتين*: يستخدمه التسجيل لعملية REGISTER، ويستخدمه الـ endpoint للرد على تحدي `407` في طلبات INVITE الصادرة.

## مرجع ترحيل الخيارات خياراً بخيار

عندما تقوم بالترجمة يدوياً (أو تدقيق مخرجات البرنامج النصي)، فإن هذا الجدول هو مرجعك. تم التحقق من كل اسم خيار في PJSIP ومكانه (endpoint / aor / auth / transport) مقابل مختبر Asterisk 22.

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | المكان |
| --- | --- | --- |
| `[peer]` / `[user]` / `[friend]` | `type=endpoint` (+ `auth` + `aor`) | — |
| `host=dynamic` | `max_contacts=1` (device REGISTERs) | aor |
| `host=<ip/host>` | `contact=sip:<host>:<port>` | aor |
| `register => u:p@host/ext` | `type=registration` + `outbound_auth` | registration |
| `secret=` | `password=` | auth |
| `username=` / `defaultuser=` | `username=` | auth |
| `secret=` (auth method) | `auth_type=digest` | auth |
| `nat=force_rport,comedia` | `force_rport=yes` + `rewrite_contact=yes` + `rtp_symmetric=yes` | endpoint |
| `directmedia=yes/no` | `direct_media=yes/no` | endpoint |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` | endpoint |
| `disallow=` / `allow=` | `disallow=` / `allow=` (same syntax) | endpoint |
| `context=` | `context=` | endpoint |
| `qualify=yes` | `qualify_frequency=<seconds>` | aor |
| `insecure=invite` | omit auth; use `type=identify` + `match=` | identify |
| `fromuser=` / `fromdomain=` | `from_user=` / `from_domain=` | endpoint |
| `externaddr=` / `externip=` | `external_media_address=` + `external_signaling_address=` | transport |
| `localnet=` | `local_net=` | transport |

### ملاحظة حول `secret` → `auth` و `auth_type`

يصبح `secret=` الخاص بـ `chan_sip` هو حقل `password=` لكائن `type=auth`. يتم تعيين **طريقة المصادقة** باستخدام `auth_type`. استخدم `auth_type=digest`. لا تزال القيم القديمة `userpass` و `md5` تعمل ولكنها **مهملة ويتم تحويلها بصمت إلى `digest`** — تم التحقق من ذلك مباشرة من المختبر:

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

سترى `auth_type=userpass` في التكوينات القديمة وفي مخرجات برنامج التحويل (وفي الفصول السابقة من هذا الكتاب). إنه غير ضار، ولكن اكتب `digest` في أي شيء جديد.

### NAT والوسائط و DTMF بالتفصيل

هذه الثلاثة هي مصدر معظم تذاكر الدعم الفني بعد الترحيل التي تقول "إنه يسجل ولكن لا يوجد صوت". اختصار `chan_sip` المتمثل في `nat=force_rport,comedia` كان يجمع ثلاثة سلوكيات في خيار واحد؛ بينما يقوم PJSIP بتقسيمها حتى تتمكن من فهم كل منها على حدة:

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

بالنسبة **للوسائط**، يصبح `directmedia` هو `direct_media` (الشرطة السفلية هي التغيير الوحيد)؛ احتفظ بـ `direct_media=no` كلما وجب تثبيت المكالمة على Asterisk — عبر NAT، أو للتسجيل/إعادة الترميز/التحويل. بالنسبة لـ **DTMF**، تمت إعادة ترقيم RFC: أصبح `dtmfmode=rfc2833` الخاص بـ `chan_sip` هو `dtmf_mode=rfc4733` في PJSIP (نفس آلية telephone-event خارج النطاق، رقم RFC الحالي). يؤكد المختبر أن قيم `dtmf_mode` الصالحة هي `rfc4733` و `inband` و `info` و `auto` و `auto_info`، والقيمة الافتراضية هي `rfc4733`.

بالنسبة **لـ codecs**، لا يتغير شيء: استخدام `disallow=all` متبوعاً بـ `allow=ulaw` (إلخ) يستخدم نفس الصيغة تماماً على PJSIP endpoint.

## تغييرات الـ dialplan و CLI

لا تتوقف عملية الترحيل عند `pjsip.conf`. هناك أمران يُستخدمان يومياً قد تغيرا.

### سلاسل القنوات: `SIP/` → `PJSIP/`

يجب تحديث كل `Dial()` ومرجع للقناة في `extensions.conf` كان يشير إلى التقنية القديمة:

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

تتبع سلاسل الاتصال الخاصة بالـ trunk النمط نفسه — حيث تصبح `Dial(SIP/${EXTEN}@itsp)` هي `Dial(PJSIP/${EXTEN}@itsp)`. يضيف PJSIP أيضاً وظيفة `PJSIP_DIAL_CONTACTS()` للاتصال بكل جهة اتصال مرتبطة بـ AOR في وقت واحد، بالإضافة إلى وظائف الـ dialplan المسماة `PJSIP_HEADER()` / `PJSIP_MEDIA_OFFER()`؛ قم بالبحث في الـ dialplan الخاص بك عن مراجع SIP التالية: `SIP/` و `SIPPEER` و `SIPCHANINFO` و `CHANNEL(...)` وقم بترجمة كل منها.

### واجهة سطر الأوامر (CLI): `sip show ...` → `pjsip show ...`

تمت إزالة شجرة أوامر `sip ...` بالكامل مع البرنامج المشغل (driver). البدائل هي:

| أمر `chan_sip` | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (أو `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (أو `core reload`) |

الأوامر القديمة لا تعمل بشكل مختلف فحسب، بل إنها لم تعد موجودة. في المختبر، يُرجع الأمر `sip show peers` رسالة *No such command*، بينما تتوفر الأوامر `pjsip show endpoints` و `pjsip show aors` و `pjsip show auths` و `pjsip show contacts` و `pjsip show registrations` و `pjsip show identifies`. أما أمر استكشاف الأخطاء وإصلاحها الأكثر فائدة — وهو مسجل حزم SIP الذي كان يطبع كل رسالة باستخدام `sip set debug` — فقد أصبح الآن **`pjsip set logger on`** (مع استخدام `pjsip set logger host <ip>` للتركيز على peer واحد).

## ترحيل Realtime (ARA)

إذا كنت تشغل `chan_sip` من قاعدة بيانات (Asterisk Realtime Architecture)، فإن أجهزتك كانت موجودة في الجدول `sippeers` وعمليات التسجيل في `sipregs`. يستخدم PJSIP طبقة تخزين مختلفة تماماً — **Sorcery** — مع جدول واحد *لكل نوع كائن*. إليك التعيين:

| جدول realtime الخاص بـ `chan_sip` | جداول PJSIP / Sorcery |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (صف واحد لكل منها، مقسمة) |
| `sipregs` | `ps_contacts` (التسجيلات الديناميكية) |
| — (صادر `register=>`) | `ps_registrations` |
| — (مطابقة IP) | `ps_endpoint_id_ips` (كائنات `identify`) |
| — (أسماء النطاقات المستعارة) | `ps_domain_aliases` |

الانقسام المفاهيمي هو نفسه في حالة الملفات المسطحة: صف واحد من `sippeers` يصبح *ثلاثة* صفوف في ثلاثة جداول (`ps_endpoints` + `ps_aors` + `ps_auths`) تشير إلى بعضها البعض بواسطة اسم الـ endpoint.

هناك أمران يجعلان هذا الأمر قابلاً للتنفيذ:

- **المخطط (schema) يتم إنشاؤه لك.** يوفر Asterisk عمليات ترحيل Alembic تحت `contrib/ast-db-manage/` التي تنشئ كل جدول `ps_*`. قم بتشغيل `alembic upgrade head` مقابل قاعدة البيانات `config` لبناء مخطط PJSIP الحالي بدلاً من كتابة DDL يدوياً.
- **يوجد برنامج نصي لتحويل SQL.** إلى جانب `sip_to_pjsip.py` يوجد **`sip_to_pjsql.py`** في نفس الدليل `contrib/scripts/sip_to_pjsip/`؛ وهو يعيد استخدام نفس منطق `convert()` ولكنه يصدر ملف `pjsip.sql` يحتوي على عبارات `INSERT` لجداول `ps_*` بدلاً من ملف إعدادات مسطح. كما هو الحال مع أداة الملفات المسطحة، راجع المخرجات قبل تحميلها.

أخيراً، وجه `sorcery.conf` إلى قاعدة بياناتك حتى يقرأ PJSIP الـ endpoints، والـ aors، والـ auths، والـ contacts من جداول `ps_*` (عبر `res_config_odbc` / `res_pjsip_realtime`)، تماماً كما كان `extconfig.conf` يوجه `sippeers` سابقاً إلى قاعدة البيانات من أجل `chan_sip`. تمت تغطية آليات Realtime في فصل *Realtime*؛ والنقطة الخاصة بالترحيل هي ببساطة *أي الجداول يتم تعيينها لأي منها*.

## قائمة التحقق من الترحيل

ترتيب عملي للعمليات من أجل الانتقال إلى بيئة الإنتاج:

1. **الجرد.** قم بإدراج كل جهاز، و trunk، و `register =>` في `sip.conf` (أو كل صف `sippeers`/`sipregs`). دوّن إعدادات NAT، و codec، و DTMF المخصصة.
2. **تشغيل المحول في ملف تجريبي.**
   `sip_to_pjsip.py sip.conf pjsip_generated.conf`. لا تقم بتوجيهه إلى `pjsip.conf` المباشر الخاص بك.
3. **قراءة كتلة "Non mapped elements"** في أعلى المخرجات وحل كل سطر — خاصة `qualify`، والمؤقتات، وأي شيء متعلق بـ NAT.
4. **تصميم الـ transport(s) يدوياً.** واحد transport لكل IP/port؛ أضف TLS/TCP حسب الحاجة؛ اضبط `external_*_address` و `local_net` لصناديق السحابة/NAT.
5. **التحقق من المصادقة.** تأكد من `auth_type=digest`، وأسماء المستخدمين، وكلمات المرور في كل كائن `auth`.
6. **التحقق من NAT/media/DTMF.** اضبط `force_rport`/`rewrite_contact`/`rtp_symmetric`، و `direct_media`، و `dtmf_mode=rfc4733` لكل endpoint حسب المتطلبات.
7. **تحديث الـ dialplan.** قم بتغيير `SIP/` إلى `PJSIP/` في كل مكان؛ تحقق من وظائف `SIP*` ومتغيرات القناة.
8. **تحديث البرامج النصية والمراقبة.** أي أداة أو مستهلك AMI كان يحلل مخرجات `sip show ...` يجب أن ينتقل إلى إجراءات `pjsip show ...` / PJSIP AMI.
9. **إعادة التحميل والتحقق.** استخدم `module reload res_pjsip.so`، ثم `pjsip show endpoints`، و `pjsip show registrations`، و `pjsip show identifies`.
10. **الاختبار باستخدام مسجل الحزم.** استخدم `pjsip set logger on`؛ قم بإجراء تسجيل، ومكالمة واردة، ومكالمة صادرة، واقرأ تبادل SIP من البداية إلى النهاية.

## المزالق الشائعة

- **`alwaysauthreject` مدمج الآن — لا تبحث عنه.** كان `chan_sip` يحتاج إلى `alwaysauthreject=yes` حتى لا يسرب معلومات حول الامتدادات الموجودة عن طريق الرد بشكل مختلف على أسماء المستخدمين غير الصحيحة. يقوم PJSIP بالأمر الآمن حسب التصميم: فهو لا يكشف أبداً عما إذا كان الـ endpoint موجوداً. لا يوجد خيار `alwaysauthreject` لضبطه. الحماية ذات الصلة — تقييد المرسلين غير المعروفين — هي الخيار العام `unidentified_request_count` / `unidentified_request_period`، وهو مفعل افتراضياً.

- **`insecure=invite` ليس خياراً في PJSIP — استخدم `identify`.** لا يوجد `insecure=` في `pjsip.conf`. الطريقة لقبول طلبات INVITE غير الموثقة من مزود خدمة معروف هي *تحديد الـ endpoint عن طريق عنوان IP المصدر* باستخدام `type=identify` / `match=`. طابق النطاق بأضيق قدر ممكن (عناوين IP محددة للمضيف، وليس نطاقات CIDR واسعة)، وادعم ذلك باستخدام `type=acl` — فوجود trunk مطابق لعنوان IP بدون مصادقة يعد هدفاً للاحتيال الهاتفي.

- **نقل واحد لكل عنوان IP/منفذ.** لا يمكنك ربط وسيلتي نقل (transports) بنفس عنوان IP:المنفذ، ولا يمكنك ربط عدة وسائل نقل TCP أو TLS من نفس إصدار IP. قد يقوم برنامج التحويل بإنشاء وسيلة نقل تتعارض مع وسيلة موجودة لديك بالفعل — قم بدمجها في طبقة نقل واحدة مصممة بعناية.

- **`qualify=yes` لا يتحول إلى قيمة منطقية (boolean).** إنه ينتمي إلى **aor** كـ `qualify_frequency=<seconds>`. يقوم المحول بإسقاط `qualify=yes` في الكتلة غير المعينة (non-mapped block) تحديداً لأنه لا يوجد ما يعادله من نوع boolean في الـ endpoint.

- **`secret=` ليس خياراً للـ endpoint.** بيانات الاعتماد توجد فقط في كائن `type=auth` الذي يشير إليه الـ endpoint (`auth=` للوارد، `outbound_auth=` للصادر). وضع كلمة مرور على الـ endpoint لا يؤدي إلى أي نتيجة.

- **واجهة CLI وأي برامج نصية للاستخراج تتوقف عن العمل بصمت.** يعيد `sip show ...` رسالة "No such command"، وليس خطأ قد تلتقطه أدوات المراقبة الخاصة بك بالضرورة. قم بمراجعة كل مهمة cron، وفحص Nagios، وعميل AMI بحثاً عن أوامر `sip ` قبل الانتقال للنظام الجديد.

## ملخص

يعني الانتقال إلى Asterisk 22 التخلي عن `chan_sip`، نظرًا لأنه تمت إزالة هذا المشغل في Asterisk 21 وأصبح PJSIP هو قناة SIP الوحيدة المتبقية. يتمثل جوهر العمل في إعادة صياغة كل `sip.conf` من نوع `peer`/`user`/`friend` — التي كانت تجمع كل شيء في كتلة واحدة — كمجموعة من كائنات PJSIP المتعاونة: `endpoint` بالإضافة إلى `auth`، و `aor`، واعتمادًا على الجهاز، `identify` (لخط الربط الوارد)، و `registration` (لتسجيل الخروج)، و `transport` مشترك. يقوم البرنامج النصي `sip_to_pjsip.py` الموجود في `contrib/scripts/sip_to_pjsip/` بمعظم عملية التحويل ويحدد بصدق ما لا يمكن تعيينه في كتلة "العناصر غير المعينة"، ولكن مخرجاته تعتبر مسودة أولية: قم بتصميم النقل (transport)، و NAT، والأمان يدويًا واختبر ذلك قبل الانتقال إلى بيئة الإنتاج. فيما يتعلق بالإعدادات، قم بتحديث الـ dialplan (من `SIP/` إلى `PJSIP/`) وقم بتحديث ممارساتك والبرامج النصية الخاصة بك (من `sip show` إلى `pjsip show`، ومن `sip set debug` إلى `pjsip set logger`). تنتقل عمليات النشر التي تستخدم Realtime من جداول `sippeers`/`sipregs` إلى جداول Sorcery الخاصة بـ `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts`، مع الاستعانة بـ `sip_to_pjsql.py` ومخطط `contrib/ast-db-manage` للمساعدة. انتبه إلى العقبات — فـ `alwaysauthreject` مدمج، و `insecure=invite` يصبح `identify`، و `qualify=yes` يصبح `qualify_frequency`، مع الالتزام بقاعدة نقل واحد لكل IP/port — وستجد أن عملية الانتقال ميكانيكية وليست غامضة.

## اختبار

1. لماذا يجب أن يستخدم نشر Asterisk 22 بروتوكول PJSIP لـ SIP؟
   - A. `chan_sip` أبطأ ولكنه لا يزال متاحاً
   - B. تمت إزالة `chan_sip` في Asterisk 21 وهو غير موجود في Asterisk 22
   - C. PJSIP هو الافتراضي ولكن يمكن تحميل `chan_sip` باستخدام `modules.conf`
   - D. `chan_sip` يعمل فقط مع TLS في Asterisk 22

2. كتلة `sip.conf` `type=friend` الواحدة تتحول في الغالب إلى أي مجموعة من كائنات PJSIP؟
   - A. `type=peer` واحدة
   - B. `type=endpoint` فقط
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. في `sip.conf`، يتم تعيين `host=dynamic` (يقوم الجهاز بتسجيل موقعه الخاص) إلى:
   - A. `type=identify` مع `match=dynamic`
   - B. `type=aor` مع `max_contacts` (يقوم الجهاز بعمل REGISTER)
   - C. `direct_media=yes` على الـ endpoint
   - D. `type=registration`

4. برنامج التحويل `sip_to_pjsip.py` هو:
   - A. أمر CLI: `asterisk -rx 'sip_to_pjsip'`
   - B. برنامج Python في شجرة مصدر Asterisk تحت `contrib/scripts/sip_to_pjsip/`
   - C. وحدة برمجية مترجمة يتم تحميلها عند الإقلاع
   - D. جزء من `res_pjsip.so`

5. صح أم خطأ: مخرجات `sip_to_pjsip.py` جاهزة للإنتاج ويجب تحميلها دون مراجعة.

6. الاختصار `chan_sip` المسمى `nat=force_rport,comedia` يترجم في الـ endpoint الخاص بـ PJSIP إلى أي من الخيارات الثلاثة التالية؟
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. يتحول `dtmfmode=rfc2833` الخاص بـ `sip.conf` إلى أي إعداد في PJSIP؟
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. في Asterisk 22، يجب أن يستخدم كائن `auth` أي `auth_type`، وما هي حالة `userpass`؟
   - A. `auth_type=userpass`؛ وهي القيمة الصالحة الوحيدة
   - B. `auth_type=digest`؛ تم إهمال `userpass` وتحويله إلى `digest`
   - C. `auth_type=md5`؛ تم إهمال `digest`
   - D. `auth_type=plaintext`؛ تمت إزالة `digest`

9. يتم ترحيل نظير مزود `chan_sip` مع `insecure=invite` (قبول طلبات INVITE غير الموثقة من عنوان IP معروف) إلى PJSIP باستخدام:
   - A. `insecure=invite` على الـ endpoint
   - B. `allowguest=yes` في `[global]`
   - C. كائن `type=identify` مع `match=<provider IP>`
   - D. `auth_type=anonymous`

10. في ترحيل realtime، يتم استبدال جدول `chan_sip` `sippeers` بأي من جداول PJSIP/Sorcery؟
    - A. جدول `pjsip_peers` واحد
    - B. `ps_endpoints`, `ps_aors`, و `ps_auths`
    - C. `sipregs` و `voicemail`
    - D. `ps_contacts` فقط

**الإجابات:** 1 — B · 2 — C · 3 — B · 4 — B · 5 — خطأ · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
