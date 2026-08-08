# SIP & PJSIP بعمق

SIP هو البروتوكول؛ و PJSIP هو الطريقة التي يتحدث بها Asterisk 22. إن **PJSIP** (المشار إليه في `chan_pjsip`، والذي يتم تهيئته عبر `pjsip.conf`) هو برنامج تشغيل قناة SIP الوحيد في Asterisk 22 LTS. يغطي هذا الفصل أساسيات بروتوكول SIP (وهي على مستوى البروتوكول وتظل صالحة بنسبة 100%) ونموذج كائن PJSIP والتهيئة التي تستخدمها كل يوم. تمت تغطية برنامج التشغيل القديم الذي تم إيقافه ودليل الترحيل في فصل *Legacy channels*.

## الأهداف

بنهاية هذا الفصل، يجب أن تكون قادراً على:

- شرح دور وكلاء مستخدم SIP، والوكلاء (proxies)، ومسجل النظام (registrar)، والبوابات (gateways)؛
- تتبع مسار مكالمة SIP أساسية (REGISTER، وINVITE، والاستجابات المؤقتة والنهائية، وACK، وBYE) وقراءة رسالة SIP؛
- وصف كيفية تفاوض SDP على جلسة الوسائط وكيف يؤثر NAT على إشارات SIP وRTP؛
- تعيين نموذج كائن PJSIP — `endpoint`، و`auth`، و`aor`، و`transport`، و`identify`، و`registration` — وكيفية إشارة الكائنات إلى بعضها البعض؛
- تكوين هواتف SIP وtrunks في `pjsip.conf`، بما في ذلك خيارات تجاوز NAT؛ و
- التحقق من endpoints واستكشاف أخطائها وإصلاحها باستخدام أوامر CLI الخاصة بـ `pjsip show …`.

## أساسيات بروتوكول SIP

بروتوكول بدء الجلسة (SIP) هو بروتوكول نصي يشبه HTTP و SMTP، وقد صُمم لتهيئة جلسات الاتصال التفاعلية بين المستخدمين، والحفاظ عليها، وإنهاؤها. قد تشمل هذه الجلسات الصوت، والفيديو، والدردشة، والألعاب التفاعلية، وغيرها. تم تعريف SIP بواسطة IETF وأصبح المعيار الفعلي لاتصالات الصوت. من المهم جداً فهم كيفية عمل SIP. في Asterisk 22، يوجد إعداد SIP في `pjsip.conf`، وهو أحد أكثر الملفات التي يتم تعديلها تكراراً في الأنظمة القائمة على SIP (مباشرة بعد `extensions.conf`).

### نظرية التشغيل

SIP هو بروتوكول إشارات يتكون من المكونات التالية: عميل وكيل المستخدم (UAC)، وخوادم وكيل المستخدم (UAS)، ووكلاء SIP، وبوابات SIP. يوضح الشكل التالي العلاقات بين هذه المكونات.

- UAC (عميل وكيل المستخدم) – العميل أو الجهاز الطرفي الذي يبدأ إشارات SIP.
- UAS (خادم وكيل المستخدم) – الخادم الذي يستجيب لإشارات SIP القادمة من UAC.
- UA (وكيل المستخدم) – جهاز SIP الطرفي (الهواتف أو البوابات التي تحتوي على كل من UAC و UAS).
- خادم الوكيل (Proxy Server) – يستقبل الطلبات من UA وينقلها إلى وكلاء SIP آخرين إذا كانت المحطة المعنية ليست تحت إدارتهم.
- خادم إعادة التوجيه (Redirect Server) – يستقبل الطلبات ويرسلها مرة أخرى إلى UA، متضمنة بيانات الوجهة، بدلاً من إعادة توجيهها مباشرة إلى الوجهة.
- خادم الموقع (Location Server) – يستقبل الطلبات من UA ويحدث قاعدة بيانات الموقع بهذه المعلومات.

عادةً ما يتم استضافة خوادم الوكيل، وإعادة التوجيه، والموقع داخل نفس الأجهزة وتستخدم نفس البرنامج، الذي نسميه وكيل SIP. وكيل SIP مسؤول عن صيانة قاعدة بيانات الموقع، وإنشاء الاتصال، وإنهاء الجلسة.

![المكونات الرئيسية لـ SIP: وكلاء المستخدم (UAC/UAS/UA)، وخادم التسجيل/الوكيل/إعادة التوجيه، وبوابة إلى PSTN، مع تدفق وسائط RTP مباشرة بين نقاط النهاية](../images/07-sip-and-pjsip-fig01.png)

#### عملية التسجيل في SIP

قبل أن يتمكن الهاتف من استقبال المكالمات، يجب تسجيله في قاعدة بيانات الموقع. في قاعدة بيانات الموقع، سيتم ربط عنوان IP بالاسم. في المثال التالي، سيتم ربط extension 8500 بعنوان IP 200.180.1.1. لست بحاجة بالضرورة إلى استخدام أرقام هواتف. في بنية SIP، يمكن أن يكون الـ extension المسجل هو flavio@voip.school أيضاً.

![تسجيل SIP: يرسل الهاتف REGISTER لربط extension 8500 بعنوان IP الخاص به، ويقوم المسجل بتخزين جهة الاتصال في قاعدة بيانات الموقع والرد بـ 200 OK](../images/07-sip-and-pjsip-fig02.png)

#### تشغيل الوكيل (Proxy)

عند العمل كوكيل SIP، يظل خادم SIP في منتصف الإشارات ويكون قادراً على التوجيه المتقدم والفوترة. لا يزال تدفق الوسائط، القائم على بروتوكول الوقت الحقيقي (RTP)، يمر مباشرة بين نقاط النهاية.

![تشغيل الوكيل: يظل وكيل SIP في مسار الإشارات (INVITE/200 OK) ويبحث عن الطرف المتصل به في خادم الموقع، بينما تتدفق وسائط RTP مباشرة بين نقطتي النهاية](../images/07-sip-and-pjsip-fig03.png)

#### تشغيل إعادة التوجيه (Redirect)

عند إعادة التوجيه، يرسل خادم SIP ببساطة رسالة (على سبيل المثال، 302 moved temporarily) إلى وكيل المستخدم ويبقى خارج مسار الرسائل الجديدة. إنه خفيف جداً من حيث استخدام الموارد، لكن ليس لديك أي تحكم على الإطلاق. تُستخدم إعادة التوجيه أحياناً في تصميمات موازنة الحمل.

![تشغيل إعادة التوجيه: يجيب خادم إعادة التوجيه على INVITE بـ 302 Moved Temporarily حاملاً جهة الاتصال، ثم يتنحى جانباً بينما يعيد المتصل إرسال INVITE/ACK مباشرة إلى الموقع الجديد](../images/07-sip-and-pjsip-fig04.png)

#### كيف يتعامل Asterisk مع SIP

من المهم أن نفهم أن Asterisk ليس وكيل SIP ولا موجه إعادة توجيه SIP. يمكن لـ Asterisk القيام بدور المسجل وخادم الموقع؛ ومع ذلك، فهو يربط فقط اثنين من UACs بنفسه. لذلك، يعتبر Asterisk وكيل مستخدم متصل (B2BUA). وبعبارة أخرى، فهو يربط قناتي SIP، ويقوم بعمل جسر بينهما. يحتوي Asterisk على آلية re-invite يمكنها جعل قنوات SIP تتحدث مع بعضها البعض مباشرة بدلاً من المرور عبر Asterisk. في endpoint من نوع PJSIP، يتم التحكم في هذا بواسطة المعلمة `direct_media`. عند استخدام `direct_media=yes`، يتدفق RTP مباشرة من نقطة نهاية إلى أخرى، مما يوفر موارد الخادم.

#### تشغيل SIP مع direct_media=yes

![تشغيل SIP مع directmedia=yes: تتدفق إشارات SIP عبر Asterisk بينما يذهب صوت RTP مباشرة بين الهاتفين، مما يوفر موارد الخادم](../images/07-sip-and-pjsip-fig05.png)

ومع ذلك، إذا كنت بحاجة إلى تحويل المكالمة أو تسجيلها باستخدام Asterisk، فقد تستخدم المعلمة `direct_media=no` لإجبار تدفق RTP على المرور عبر خادم Asterisk.

#### تشغيل SIP مع direct_media=no

![تشغيل SIP مع directmedia=no: يتم تثبيت كل من إشارات SIP وصوت RTP عبر Asterisk، مما يسمح له بتسجيل المكالمة أو تحويلها أو تحويل ترميزها (transcode)](../images/07-sip-and-pjsip-fig06.png)

#### رسائل SIP

رسائل SIP الأساسية هي:

- INVITE – إنشاء الاتصال
- ACK – تأكيد الاستلام
- BYE – إنهاء الاتصال
- CANCEL – إنهاء الاتصال لمكالمة لم يتم إنشاؤها
- REGISTER – تسجيل UAC في وكيل SIP
- OPTIONS – يمكن استخدامها للتحقق من التوفر
- REFER – تحويل مكالمة SIP إلى شخص آخر
- SUBSCRIBE – الاشتراك في أحداث الإشعارات
- NOTIFY – إرسال معلومات القناة
- INFO – إرسال رسائل متنوعة (على سبيل المثال، DTMF)
- MESSAGE – إرسال رسائل فورية

استجابات SIP تكون بتنسيق نصي وهي سهلة القراءة (تشبه رسائل HTTP). أهم الاستجابات هي:

- 1XX – رسائل معلوماتية (100–trying, 180–ringing, 183–progress)
- 2XX – طلب ناجح مكتمل (200 – OK)
- 3XX – إعادة توجيه المكالمة، يجب توجيه الطلب إلى مكان آخر (302 – moved temporarily, 305 – use proxy)
- 4XX – خطأ (403 – Forbidden)
- 5XX – خطأ في الخادم (500 – Internal Server Error; 501 – Not implemented)
- 6XX – فشل عالمي (606 – Not acceptable)

على سبيل المثال:

```
INVITE sip:2000@192.168.1.133 SIP/2.0
Via: SIP/2.0/UDP
192.168.1.116;rport;branch=z9hG4bKc0a8017400000063452fafbb00006967000000d2
From: "unknown"<sip:2001@192.168.1.133>;tag=1556140623845
To: <sip:2000@192.168.1.133>
Contact: <sip:2001@192.168.1.116>
Call-ID: 64B4C8EC-FCFC-49E9-98B1-90982EEEBED3@192.168.1.116
CSeq: 2 INVITE
Max-Forwards: 70
User-Agent: SJphone/1.61.312b (SJ Labs)
Content-Length: 335
Content-Type: application/sdp
Proxy-Authorization: Digest
username="2001",realm="asterisk",nonce="6c55905e",uri="sip:2000@192.168.1.133",
response="983c0099eea125d8cdfe93b0ec99f3ec",algorithm=MD5
```

#### بروتوكول وصف الجلسة (SDP)

تم تعريف SDP في الأصل في IETF RFC 2327، والذي تم استبداله الآن بـ RFC 4566. وهو مخصص لوصف جلسات الوسائط المتعددة لأغراض إعلان الجلسة، ودعوة الجلسة، وأشكال أخرى من بدء جلسات الوسائط المتعددة. يتضمن SDP:

- بروتوكول النقل (RTP/UDP/IP)
- نوع الوسائط (نص، صوت، فيديو)
- تنسيق الوسائط أو codec (فيديو H.261، صوت g.711، إلخ)
- المعلومات اللازمة لاستقبال هذه الوسائط (العناوين، المنافذ، إلخ)

المثال التالي هو نسخة من SDP يصف مكالمة بين هاتفين.

```
v=0
o=- 3369741883 3369741883 IN IP4 192.168.1.116
s=SJphone
c=IN IP4 192.168.1.116
t=0 0
a=setup:active
m=audio 49160 RTP/AVP 3 97 98 8 0 101
a=rtpmap:3 GSM/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11,16
```

### عبور NAT في SIP

ترجمة عنوان الشبكة (NAT) هي ميزة تستخدمها معظم الشبكات لتوفير عناوين IP للإنترنت. عادةً، تتلقى الشركة كتلة صغيرة من عناوين IP، ويتلقى المستخدمون النهائيون عنوان IP واحداً ديناميكياً عند الاتصال بالإنترنت. يحل NAT مشكلة العنونة عن طريق تعيين العناوين الداخلية إلى عناوين خارجية. يقوم بتخزين تعيين العناوين الداخلية إلى الخارجية في ذاكرته. هذا التعيين صالح لفترة زمنية محددة، وبعد ذلك يتم تجاهل التعيين. يستخدم التعيين أزواج IP:port للعناوين الداخلية والخارجية. توجد أربعة أنواع من NAT:

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

نظرية NAT أدناه — أنواع NAT الأربعة، ومشكلة Contact-header، و keep-alives، وإجبار الوسائط عبر الخادم — هي على مستوى البروتوكول وتنطبق على أي تطبيق SIP. الطريقة التي تقوم بها بتهيئة كل سلوك على Asterisk 22 (PJSIP) مغطاة لاحقاً في هذا الفصل تحت عنوان *Nat traversal on res_pjsip*.

#### Full Cone

أول NAT، وهو full cone، يمثل تعيينًا ثابتاً من زوج IP:port خارجي إلى زوج IP:port داخلي. يمكن لأي كمبيوتر خارجي الاتصال به باستخدام زوج IP:port الخارجي. هذه هي الحالة في جدران الحماية غير المعتمدة على الحالة (non-stateful) التي يتم تنفيذها باستخدام المرشحات.

![Full Cone NAT: المضيف الداخلي (10.0.0.1:8000) معين بشكل ثابت للزوج الخارجي 200.180.4.168:1234، لذا يمكن لأي كمبيوتر خارجي إرسال حزم إلى ذلك الزوج والوصول إلى المضيف الداخلي](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

في سيناريو restricted cone، يتم فتح زوج IP:port الخارجي فقط عندما يرسل الكمبيوتر الداخلي بيانات إلى عنوان خارجي. ومع ذلك، يقوم NAT من نوع restricted cone بحظر أي حزم واردة من عنوان مختلف. وبعبارة أخرى، يجب على الكمبيوتر الداخلي إرسال بيانات إلى كمبيوتر خارجي قبل أن يتمكن من إرسال بيانات مرة أخرى.

#### Port Restricted Cone

جدار حماية port restricted cone مطابق تقريباً لـ restricted cone. الفرق الوحيد هو أنه الآن، يجب أن تأتي الحزمة الواردة من نفس عنوان IP ومنفذ الحزمة المرسلة تماماً.

#### Symmetric

آخر نوع من NAT يسمى symmetric. وهو يختلف عن الأنواع الثلاثة الأولى في أنه يتم إجراء تعيين محدد لكل عنوان خارجي. يُسمح فقط لعناوين خارجية محددة بالعودة بواسطة تعيين NAT. ليس من الممكن التنبؤ بزوج IP:port الخارجي الذي سيستخدمه جهاز NAT. تسمح الأنواع الثلاثة الأخرى من NAT باستخدام خادم خارجي لاكتشاف عنوان IP الخارجي للاتصال. مع symmetric NAT، حتى لو تمكنت من الاتصال بخادم خارجي، لا يمكن استخدام العنوان المكتشف لأي جهاز آخر باستثناء هذا الخادم.

![Symmetric NAT: يتم تخصيص منفذ مصدر خارجي مختلف لكل وجهة، لذا لا يمكن إعادة استخدام التعيين المكتشف تجاه خادم واحد بواسطة مضيف آخر، مما يكسر العبور القائم على STUN](../images/07-sip-and-pjsip-fig12.png)

#### جدول جدار حماية NAT

يلخص الجدول التالي الأنواع الأربعة من NAT.

| نوع NAT | يجب إرسال البيانات أولاً | يمكن تحديد IP:port الخارجي للحزم العائدة | يقيد الحزم الواردة بـ IP:port الوجهة |
| --- | --- | --- | --- |
| Full Cone | لا | نعم | لا |
| Restricted Cone | نعم | نعم | IP فقط |
| Port Restricted Cone | نعم | نعم | نعم |
| Symmetric | نعم | لا | نعم |

#### إشارات SIP و RTP عبر NAT

بعض أكبر المشكلات في عبور NAT هي أنه يجب عليك حل مشكلتين: إشارات SIP والصوت (RTP). معظم مشاكل الصوت أحادي الاتجاه تتعلق بـ NAT. الشيء المثير للاهتمام في SIP هو أنه عندما يرسل UAC حزمة، فإنه يضمن عنوان IP في حقل رأس "Contact" الخاص بـ SIP. عادةً ما يكون هذا عنواناً داخلياً (RFC1918)؛ ولا يمكن توجيه الردود على هذه الحزمة عبر الإنترنت مرة أخرى إلى UAC. الإصلاحات المفاهيمية هي دائماً نفسها:

- **تجاهل عنوان Contact/Via والرد على المكان الذي جاءت منه الحزمة فعلياً.** هذا هو السلوك المحدد في RFC 3581 (`rport`). في PJSIP هو `force_rport=yes`، و `rewrite_contact=yes` يعيد كتابة جهة الاتصال المخزنة إلى عنوان المصدر.
- **إرسال الوسائط مرة أخرى إلى العنوان الذي وصلت منه RTP فعلياً** (RTP متماثل، يسمى تاريخياً *comedia*). في PJSIP هذا هو `rtp_symmetric=yes`.
- **إبقاء تعيين NAT مفتوحاً.** إذا انتهت مهلة التعيين، لم يعد بإمكان Asterisk إرسال INVITE إلى UAC — يمكن للهاتف إجراء مكالمات ولكن لا يمكنه استقبالها. إرسال OPTIONS دوري (*qualify*) يبقي المنفذ مفتوحاً. في PJSIP هذا هو `qualify_frequency=` على AOR.

إذا كان NAT الخاص بالمستخدم من النوع symmetric، فليس من الممكن إرسال حزم من UAC إلى آخر مباشرة؛ في هذه الحالة يجب عليك إجبار RTP عبر Asterisk باستخدام `direct_media=no`. هذه الإعدادات مناسبة لمعظم الحالات. من الممكن تحسين حركة المرور باستخدام تقنيات متقدمة مثل Simple Traversal of UDP over NAT (STUN)، وهو مفيد مع full cone و restricted cone و port restricted cone، و Application Layer Gateway (ALG). لسوء الحظ، معظم جدران الحماية اليوم — حتى أجهزة توجيه DSL/cable المنزلية — هي symmetric، مما يجعل STUN غير قابل للاستخدام. يمكن لـ ALG حل المشكلة، لكنه غير مدعوم أو غير منفذ أو يحتوي على أخطاء في معظم الحالات.

#### Asterisk خلف NAT

في بعض الأحيان يتم تنفيذ خادم Asterisk نفسه خلف جدار حماية مع NAT — وهو وضع شائع جداً عند النشر في السحابة. في هذه الحالة، من الضروري إجراء بعض الإعدادات الإضافية حتى يعلن Asterisk عن عنوانه **العام** في رؤوس SIP و SDP بدلاً من عنوانه الخاص.

من الناحية المفاهيمية هناك ثلاث خطوات:

- إعادة توجيه منفذ إشارات SIP (UDP 5060 افتراضياً) من جدار الحماية إلى خادم Asterisk.
- إعادة توجيه نطاق منفذ وسائط RTP (UDP 10000–20000 افتراضياً، مضبوط في `rtp.conf`) من جدار الحماية إلى خادم Asterisk.
- إخبار Asterisk بعنوانه الخارجي وما هي الشبكة المحلية، حتى يعرف متى يستبدل العنوان العام في الرؤوس.

في PJSIP، يتم تعيين هذين العنصرين الأخيرين إلى `external_media_address` / `external_signaling_address` و `local_net=` على **النقل (transport)**، ولا يزال نطاق منفذ RTP مضبوطاً في `rtp.conf`:

```
; RTP Configuration
;
[general]
;
; RTP start and RTP end configure start and end addresses
;
rtpstart=10000
rtpend=20000
```

يتم تقديم إعداد PJSIP الكامل والمجرب لخادم Asterisk خلف NAT لاحقاً في هذا الفصل تحت عنوان *Asterisk Server behind NAT*.

### قيود SIP

يستخدم Asterisk تدفق RTP الوارد لمزامنة التدفق الصادر. إذا تمت مقاطعة التدفق الوارد (قمع الصمت)، فسيتم قطع موسيقى الانتظار (music-on-hold). وبعبارة أخرى، لا يجب عليك استخدام قمع الصمت في الهواتف أو مع مزودي الخدمة مع Asterisk.

## PJSIP: قناة SIP

تعد PJSIP قناة SIP في Asterisk. تم تقديمها لأول مرة في Asterisk 12، وبعد سنوات من التطوير، أصبحت قناة SIP الافتراضية والموصى بها، وفي Asterisk 22 (إصدار LTS الحالي) أصبحت هي برنامج تشغيل قناة SIP الوحيد. تعتمد PJSIP على مشروع Teluu المسمى pjproject. يتم استخدام حزمة pjproject من قبل العديد من تطبيقات softphone وتنفيذات SIP التجارية. إنها حزمة SIP متعددة الاستخدامات وناضجة.

### لماذا نستخدم PJSIP

كانت PJSIP إعادة تصميم شاملة لكيفية تحدث Asterisk ببروتوكول SIP، ومن الجدير فهم الميزات التي جعلتها المعيار القياسي.

#### الميزات

تدعم القناة العديد من الميزات، وبعضها يستحق الذكر هنا:

- تسجيلات متعددة: يمكنك استخدام أكثر من هاتف متصل بنفس Address of Record. بعبارة أخرى، يمكنك توصيل هاتفين بنفس endpoint.
- واجهة برمجة تطبيقات (API) سهلة الاستخدام: الواجهة معيارية وسهلة التوسيع، ومبنية من العديد من الوحدات الصغيرة المتعاونة بدلاً من كتلة واحدة كبيرة من الكود.
- وسائل نقل متعددة: يمكنك الاستماع إلى عناوين ومنافذ ووسائل نقل متعددة عند استخدام PJSIP. أنت لست مقيداً بعنوان ربط واحد لجميع أجهزتك. PJSIP مرنة للغاية.

#### ملاحظة حول التكوين

تكوين PJSIP أكثر تفصيلاً: فهو يتطلب جهداً أكبر قليلاً والمزيد من أسطر التكوين، حيث يتم وصف كل جهاز بواسطة العديد من الكائنات ذات الصلة بدلاً من كتلة peer واحدة. هذا الهيكل الإضافي هو ما يمنح PJSIP مرونتها، كما أن معالج التكوين (الذي سيتم تغطيته لاحقاً) يجعل عملية التزويد اليومية قصيرة.

### وحدات PJSIP

يتم تنفيذ قناة PJSIP بواسطة العديد من الوحدات الموضحة أدناه:

#### res_pjsip

هذه هي الطبقة الأساسية لـ PJSIP والوحدة الرئيسية. وهي مسؤولة عن بعض الخدمات الرئيسية.

#### res_pjsip_session

هذه الوحدة مسؤولة عن جلسات الوسائط، ومعالجة بروتوكول وصف الجلسة (SDP)، وبعض الإضافات.

#### res_pjsip_messaging

معالجة رسائل SIP وتحليل ترويسات SIP.

#### res_pjsip_registrar

مسؤولة عن التعامل مع تسجيلات SIP.

#### res_pjsip_pubsub

مسؤولة عن معالجة الاشتراك (subscribe) والإشعار (notify) والنشر (publish). هذه الرسائل مسؤولة عن التعامل مع حالة SIP و BLF (Busy Lamp Field).

### تكوين PJSIP

تحتوي PJSIP على العديد من الأقسام المختلفة. تنسيق القسم هو:

```
[Section Name]
Option = Value
Option = Value
```

#### قسم End point

أهم كائن تكوين هو endpoint. يحتوي تكوين endpoint على الوظائف الأساسية ويجب ربطه بقسم AOR وقسم Transport. مثال:

```
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
```

إذا نظرت إلى المثال أعلاه، فإن endpoint هو نوع من الغراء الذي يربط جميع الأقسام ببعضها البعض. فهو يحدد وسيلة نقل (transport)، وعنوان السجل (address of record)، والمصادقة للهاتف. كما يحدد الجزء الأكثر أهمية، وهو نقطة دخول السياق (context) في الـ dialplan.

#### Address of Record (AOR)

يخبر هذا الكائن Asterisk بمكان الاتصال بـ endpoint. وهو يخزن عناوين الاتصال. كما يسمح بتكوين صناديق البريد الصوتي (mailboxes). مثال:

```
[softphone]
type=aor
max_contacts=2
```

#### المصادقة (Authentication)

هذا القسم مسؤول عن المصادقة الواردة والصادرة. توجد الوثائق في ملف المثال pjsip.conf. مثال:

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### وسيلة النقل (Transport)

يسمح لك قسم النقل بتحديد عناوين IPV4 و IPV6 وبروتوكول النقل، مثل TCP و UDP و TLS و Websockets وما إلى ذلك. يمكنك أيضاً تكوين عناوين NAT في هذا القسم. يمكنك إنشاء وسائل نقل متعددة، ولكن لا يمكنها مشاركة نفس عنوان IP والمنفذ، ولا يمكنك ربط وسائل نقل TCP أو TLS متعددة لنفس إصدار IP. مثال:

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### التسجيل (Registration)

يستخدم هذا الكائن لتكوين تسجيل صادر. مثال:

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### التعريف (Identify)

يتحكم هذا الكائن في طلب SIP الذي ينتمي إلى كل endpoint. إذا لم يكن لديك قسم identify، فسيقوم النظام بمطابقة محتوى ترويسة "From" مع اسم endpoint. باستخدام هذا القسم، يمكنك تعيين عناوين IP محددة لـ endpoints محددة، يتم تحديدها بواسطة اسم المستخدم أو عنوان IP. مثال:

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### قائمة التحكم بالوصول (ACL)

يسمح لك كائن ACL بتكوين شبكات محددة ذات وصول إلى endpoint. الآن يتم تعريف ACLs في قسم محدد أو في ملف acl.conf. مثال:

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### العلاقة بين الكيانات

توفر العلاقة بين كائنات التكوين مرونة كبيرة للتكوين. ومع ذلك، يبدو الأمر معقداً بعض الشيء لأي شخص مبتدئ.

![العلاقات بين كائنات تكوين PJSIP: يرتبط endpoint بـ transport و auth و AOR (الذي يحمل جهات الاتصال)؛ يرتبط التسجيل بـ transport و auth؛ يشير identify إلى endpoint، بينما تقف ACL و domain alias بشكل مستقل](../images/07-sip-and-pjsip-fig14.png)

الرسم البياني أعلاه يعني:

#### العلاقات:

| الكائنات | التعددية (Cardinality) |
| --- | --- |
| ENDPOINT / AOR | متعدد إلى متعدد |
| ENDPOINT / AUTH | صفر إلى متعدد، إلى صفر إلى واحد |
| ENDPOINT / IDENTIFY | صفر إلى واحد |
| ENDPOINT / TRANSPORT | صفر إلى متعدد، إلى واحد على الأقل |
| REGISTRATION / AUTH | صفر إلى متعدد، إلى صفر إلى واحد |
| REGISTRATION / TRANSPORT | صفر إلى متعدد، إلى واحد على الأقل |
| AOR / CONTACT | متعدد إلى متعدد |

لا تمتلك ACL و DOMAIN_ALIAS علاقة تكوين مباشرة بالكائنات الأخرى.

### تكوين Softphone

لتكوين softphone، يجب عليك تحديد العديد من الأقسام المختلفة. أدناه مثال على كيفية تكوين softphone. بالنسبة لجانب العميل، يمكنك استخدام SipPulse Softphone (https://www.sippulse.com/produtos/softphone)، والذي يمكنك تنزيله والتسجيل مقابل endpoint أدناه.

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
[softphone]
type=aor
max_contacts=2
```

يحدد التكوين أعلاه وسيلة نقل لـ UDP في المنفذ 5060، ثم يحدد endpoint، ومصادقته بواسطة اسم المستخدم وكلمة المرور، ثم Address of Record بحد أقصى جهتي اتصال.

### تكوين SIP trunk

لتكوين SIP trunk، تحتاج إلى الحصول على عنوان IP أو مضيف (Host) الخاص بـ SIP trunk، والاسم وكلمة المرور. يجب عليك إنشاء قسم تسجيل جديد لهذا الغرض.

```
[siptrunk]
type=endpoint
transport=transport-udp-main
context=from-siptrunk
direct_media=no
disallow=all
allow=ulaw
outbound_auth=siptrunk
aors=siptrunk
[siptrunk]
type=aor
contact=sip:sip.flagonc.com:5600
[siptrunk]
type=auth
auth_type=digest
username=1020
password=supersecret
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
[siptrunk]
type=identify
endpoint=siptrunk
match=sip.flagonc.com
```

### اجتياز NAT في res_pjsip

تم إنشاء ترجمة عنوان الشبكة (NAT) منذ فترة طويلة كوسيلة للتعامل مع نقص عناوين IP الإصدار 4. يستخدم الكثير من الناس أيضاً NAT كميزة أمنية لإخفاء العناوين الداخلية للشبكة عن الإنترنت العام. في بعض الأحيان سيتعين عليك التعامل مع اجتياز NAT. في بعض الحالات، يمكن أن يكون الخادم خلف NAT، مثل عندما تقوم بنشر الخادم في السحابة. في كثير من الأحيان إذا كنت تنشر في السحابة، سيكون مستخدموك أيضاً خلف جهاز توجيه NAT. لتنظيم الأمور، سنقسم هذا إلى جزأين. الأول هو خادم Asterisk خلف NAT مثل النشر في السحابة. في القسم الثاني، سنغطي كيفية دعم العملاء خلف NAT باستخدام res_pjsip.

#### خادم Asterisk خلف NAT

عندما يكون خادم Asterisk خلف NAT، يجب عليك إبلاغ العناوين المحلية الخارجية والداخلية في قسم النقل. سيكون لدينا التوجيهات التالية.

##### direct_media

هل تتدفق الوسائط مباشرة من نظير إلى نظير أم عبر الخادم؟ بالنسبة لـ NAT، يجب أن تتدفق عبر الخادم. بالنسبة لـ NAT، اختر no. مثال:

```
direct_media=no
```

##### external_media_address

عنوان الوسائط للتعامل مع RTP الخارجي. عادة ما يكون هو نفسه external_signaling_address. استخدم عنوان IP العام لخادمك للوسائط والإشارات. مثال:

```
external_media_address=54.232.1.20
```

##### external_signaling_address

عنوان SIP الخارجي حيث يتم استقبال الرسائل. مثال:

```
external_signaling_address=54.232.1.20
```

##### local_net

الشبكة التي تعتبرها شبكتك المحلية. مثال:

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### مثال كامل للنقل لخادم Asterisk خلف NAT

لاستخدام خادم Asterisk خلف NAT، يجب عليك القيام بخطوتين. أولاً، حدد وسيلة نقل خلف NAT. ثانياً، اربط وسيلة النقل هذه بـ endpoint.

##### إنشاء وسيلة النقل خلف NAT

لإنشاء وسيلة النقل خلف NAT في ملف pjsip.conf، قم بإنشاء قسم كما هو موضح أدناه.

```
[tnat]
type=transport
protocol=udp
bind=0.0.0.0
local_net=172.16.30.0/24
local_net=127.0.0.1/32
external_media_address=54.232.1.20
external_signaling_address=54.232.1.20
```

اربط وسيلة النقل بـ endpoint

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

بالنسبة لـ SIP trunks، يجب عليك أيضاً ربط وسيلة النقل بقسم التسجيل كما هو موضح أدناه.

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### استخدام Asterisk مع عملاء خلف NAT

لاستخدام الهواتف خلف NAT، يجب عليك تكوين بعض المعلمات الإضافية لكل endpoint.

##### direct_media

هل تتدفق الوسائط مباشرة من نظير إلى نظير أم عبر الخادم؟ بالنسبة لـ NAT، يجب أن تتدفق عبر الخادم. مثال:

```
direct_media=no
```

##### rtp_symmetric

هذا ما نسميه comedia. بدلاً من الاعتماد على العنوان المحدد في ترويسة SDP هذه كما هو معتاد في SIP، استخدم العنوان الذي تستقبل منه أول حزمة RTP وأرسل الرد من نفس العنوان. مثال:

```
rtp_symmetric=yes
```

##### force_rport

هذا هو السلوك المحدد في RFC3581. بدلاً من استخدام العنوان في ترويسة VIA، أرسل الردود من حيث تأتي الطلبات. مثال:

```
force_rport=yes
```

##### qualify_frequency

يجب تطبيق هذا الإعداد على AOR (وليس endpoint). هناك أيضاً الخطوة الأخيرة، وهي تكوين خيار qualify. يجب أن يكون لديك دائماً بعض الحزم التي تقوم بعمل ping للوجهة لإبقاء تعيين NAT مفتوحاً. يتم تعيين هذا في قسم AOR. مثال:

- qualify_frequency=15

مثال كامل لـ endpoint حيث يكون الخادم والعميل خلف NAT

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
force_rport=yes
rtp_symmetric=yes
auth=6000
aors=6000
[6000]
type=aor
qualify_frequency=15
```

### تسمية القنوات

كالعادة، أحد الجوانب المهمة للقناة هو تسميتها، ولدى PJSIP بعض التفاصيل المثيرة للاهتمام. يمكنك الاتصال بـ PJSIP endpoint باستخدام تقنية `PJSIP/`:

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

ميزة مفيدة هي إمكانية الاتصال بجميع جهات الاتصال المسجلة في AOR في وقت واحد. سيتم ترجمة الدالة PJSIP_DIAL_CONTACTS إلى قائمة جهات الاتصال المراد الاتصال بها.

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

الاتصال بـ trunk مختلف قليلاً. افترض أن trunk لن يتم تسجيله في منصتك أو لا يحتوي على عنوان IP مرتبط بـ AOR الخاص بك. يمكنك تحديد عنوان trunk مباشرة في السطر. باستخدام الاتصال الدولي كمثال.

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

إذا كنت تفضل تحديد عنوان trunk في قسم AOR، يمكنك أيضاً استخدام.

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### معالج تكوين PJSIP

تعد PJSIP قوية ولكنها مفصلة في التكوين: العديد من الأقسام المختلفة، والقوالب التي يمكن أن تكون مربكة في البداية. الخبر السار هو معالج تكوين PJSIP. من خلال تحديد كل قناة في بضعة أسطر، فإنه يسمح لك بإنشاء قوالب وتبسيط تكوين الأجهزة الجديدة. استخدم ملف pjsip_wizard.conf للتكوين. لا يزال يتعين عليك تحديد أقسام النقل (transport) والأقسام العامة (global) في ملف pjsip.conf. شخصياً، أفضل استخدام المعالج للهواتف فقط، أما بالنسبة لـ SIP trunks فعادة ما يكون العدد ليس كبيراً ويمكنك التكوين مباشرة في pjsip. أكبر ميزة للمعالج هي إمكانية استخدام القوالب وإنشاء الهواتف بسرعة.

```
[phone_default](!)
type = wizard
accepts_auth = yes
accepts_registrations = yes
transport = tnat
endpoint/allow = ulaw
endpoint/context = from-internal
endpoint/direct_media=no
endpoint/force_rport=yes
endpoint/rtp_symmetric=yes
aor/qualify_frequency=15
[alice](phone_default)
inbound_auth/username = alice
inbound_auth/password = supersecret
[bob](phone_default)
inbound_auth/username = bob
inbound_auth/password = supersecret
```

### تحميل وإلغاء تحميل PJSIP

تعد PJSIP قناة SIP الوحيدة في Asterisk 22، ويتم تحميل وحداتها افتراضياً. في حالات نادرة، قد ترغب في التحكم في تحميل الوحدات من ملف modules.conf - على سبيل المثال، لتعطيل PJSIP على خادم يستخدم فقط IAX2 أو DAHDI.

#### لتعطيل PJSIP

قم بتحرير ملف modules.conf وأضف الأسطر التالية.

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### أوامر وحدة التحكم

الآن بعد أن قمت بتكوين PJSIP endpoints الخاصة بك، حان الوقت لمعرفة كيفية التحقق من التكوين الخاص بك. هناك العديد من أوامر وحدة التحكم لمساعدتك في هذه المهمة. بعد تحرير pjsip.conf، أعد تحميل التكوين باستخدام:

```
module reload res_pjsip.so
```

يقوم أمر `reload` (أو `core reload`) عادي بإعادة تحميل جميع الوحدات بما في ذلك PJSIP. (لاحظ أنه لا يوجد أمر `pjsip reload` مجرد - `pjsip reload` موجود فقط في شكل `pjsip reload qualify aor|endpoint`.) يمكنك سرد جميع أوامر وحدة تحكم PJSIP المتاحة باستخدام `help pjsip`.

#### pjsip show endpoints

يعرض هذا الأمر endpoints المتاحة. في الصورة أدناه، لدينا لقطة شاشة. يمكنك رؤية عنوان softphone endpoint ورؤية أنه متاح.

![مخرجات `pjsip show endpoints` التي تسرد endpoints blink و siptrunk و softphone مع AOR و auth و transport وتوافرها - جهة اتصال softphone مسجلة (Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

باستخدام الأمر أعلاه، يمكنك رؤية كل معلمة من معلمات endpoint. تم قص القائمة أدناه إلى أقل من نصف المعلمات الحالية.

![مخرجات `pjsip show endpoint softphone` التي تعرض قائمة المعلمات الكاملة لـ endpoint واحد، من 100rel و allow=(ulaw) وصولاً إلى callerid و connected_line_method](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

يسرد هذا الأمر كائنات Address of Record المكونة وجهات اتصالها، بحيث يمكنك التأكد من المكان الذي سيرسل إليه Asterisk المكالمات لكل endpoint.

#### pjsip show registrations

يعرض الأمر أدناه التسجيلات التي أجراها خادمنا الخاص.

![مخرجات `pjsip show registrations`: يظهر التسجيل الصادر siptrunk/sip:1020@sip.flagonc.com:5600 مع حالة Registered](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

أمر القائمة أكثر ودية قليلاً ويعرض بيانات أقل، ولكنه أفضل تنظيماً. سرد endpoints:

![مخرجات `pjsip list endpoints`: قائمة مدمجة بسطر واحد لكل endpoint (blink, siptrunk, softphone) مع حالتها وعدد القنوات](../images/07-sip-and-pjsip-fig18.png)

سرد جهات الاتصال:

![مخرجات `pjsip list contacts` التي تعرض URIs لجهات اتصال siptrunk و softphone مع الـ hash وحالة qualify الخاصة بها](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

أكثر أوامر استكشاف الأخطاء وإصلاحها فائدة هو مسجل حزم SIP. فهو يطبع كل طلب ورد SIP إلى وحدة التحكم عند إرساله أو استقباله، وهو أمر لا يقدر بثمن عند تشخيص مشاكل التسجيل وإعداد المكالمات.

```
pjsip set logger on
pjsip set logger off
```

يمكنك أيضاً تقييد التسجيل على مضيف واحد باستخدام `pjsip set logger host <ip>`.

#### pjsip set history on

إضافة رائعة إلى PJSIP هي مفهوم التاريخ (history). يمكنك التقاط وتحليل طلبات وردود SIP في الوقت الفعلي بطريقة سهلة. لبدء التاريخ استخدم الأمر أدناه.

![تشغيل `pjsip set history on` يعيد "PJSIP History enabled"](../images/07-sip-and-pjsip-fig20.png)

الآن يمكنك عرض التاريخ:

![مخرجات `pjsip show history`: جدول مرقم لرسائل SIP الملتقطة - REGISTER, 401 Unauthorized, REGISTER, 200 OK - مع الطوابع الزمنية والاتجاه والعنوان](../images/07-sip-and-pjsip-fig21.png)

ثم لرؤية طلب أو رد محدد، اعرض عنصر التاريخ:

![مخرجات `pjsip show history entry`: النص الكامل لرسالة SIP ملتقطة واحدة - هنا رد `404 Not Found` الخاص بـ Asterisk 22 على فحص OPTIONS - يوضح ترويسات Via (مع `rport`/`received`) و Call-ID و From و To و CSeq، وقدرات `Allow`/`Supported`، وترويسة `Server: Asterisk PBX 22.10.0`](../images/07-sip-and-pjsip-fig22.png)

سهل جداً، أليس كذلك؟ يمكنك أيضاً مسح التاريخ وقتما تشاء باستخدام `pjsip set history clear`.

> **هل تهاجر من نظام chan_sip/sip.conf موجود؟** يتم تغطية برنامج التشغيل القديم `chan_sip` ودليل **ترحيل sip.conf → pjsip.conf الكامل** (بما في ذلك جدول تعيين المفاهيم وبرنامج التحويل `sip_to_pjsip.py`) في فصل *القنوات القديمة (Legacy channels)*.

## ملخص

SIP هو بروتوكول الإشارات الخاص بـ IETF الذي يقوم بإنشاء وتعديل وإنهاء جلسات الوسائط. تتبادل وكلاء المستخدم، والوكلاء (proxies)، والمُسجل (registrar)، والبوابات (gateways) رسائل نصية — مثل REGISTER و INVITE، والاستجابات المؤقتة والنهائية، و ACK، و BYE — بينما يتولى SDP التفاوض على الـ codec، ويقوم RTP بنقل الوسائط. هذه النظرية الخاصة بالبروتوكول خالدة وتنطبق على أي تطبيق لـ SIP.

في Asterisk 22، أنت تتعامل مع SIP من خلال **PJSIP** (`chan_pjsip`)، والذي يتم تكوينه في `pjsip.conf`. بدلاً من وجود نظير متجانس واحد، يتم تصميم الجهاز كمجموعة من الكائنات الصغيرة المتقاطعة: `endpoint` (سلوك المكالمات والـ codec)، و `auth` (بيانات الاعتماد)، و `aor` (مكان إمكانية الوصول إليه)، و `transport` (المستمع)، بالإضافة إلى `identify` (مطابقة الـ trunk عبر IP) و `registration` (تسجيل الصادر) لمزودي الخدمة. لقد رأيت كيف تتناسب هذه الكائنات مع بعضها البعض، وكيفية تكوين كل من الهواتف والـ trunks، وكيف تحل خيارات تجاوز الـ NAT (مثل `force_rport` و `rewrite_contact` و `rtp_symmetric` و `direct_media` و `external_*`/`local_net` الخاصة بالنقل) مشاكل النشر في العالم الحقيقي، وكيفية فحص كل ذلك باستخدام `pjsip show endpoints` و `aors` و `contacts` و `registrations`.

## اختبار

1. في بنية SIP، أي مكون يستقبل طلباً ويجيب عليه باستجابة إعادة توجيه (مثل `302 Moved Temporarily`) تحمل الموقع الجديد، ثم يظل خارج مسار الرسائل اللاحقة؟
   - A. خادم الوكيل (Proxy server)
   - B. خادم إعادة التوجيه (Redirect server)
   - C. خادم الموقع (Location server)
   - D. المسجل (Registrar)

2. ما هو الدور الذي يلعبه Asterisk عندما يتعامل مع مكالمة SIP بين هاتفين؟
   - A. وكيل SIP يظل فقط في مسار الإشارات
   - B. خادم إعادة توجيه SIP
   - C. وكيل مستخدم متصل (B2BUA) يقوم بربط قناتي SIP
   - D. موازن أحمال SIP عديم الحالة (Stateless)

3. ما هي طريقة SIP التي يستخدمها الهاتف لإخبار المسجل بعنوان IP الحالي الخاص به حتى يتمكن لاحقاً من استقبال المكالمات؟
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. صواب أم خطأ: في Asterisk 22، لا يزال `chan_sip` و `sip.conf` متاحين كخيار احتياطي قديم إلى جانب PJSIP.

5. ما هي كائنات التكوين التي يجب ربط endpoint بها حتى يعرف Asterisk مقبس الاستماع (listening socket) الذي يجب استخدامه وأين يرسل المكالمات لذلك الجهاز؟ (اختر كل ما ينطبق.)
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. في كائن PJSIP من نوع `aor`، أي إعداد يحافظ على بقاء تعيين NAT مفتوحاً عن طريق التحقق الدوري من جهة الاتصال (qualifying the contact)، وما هي وحدته؟
   - A. `qualify=yes` (قيمة منطقية)
   - B. `qualify_frequency` (ثوانٍ)
   - C. `rtp_timeout` (ملي ثانية)
   - D. `nat=force_rport`

7. املأ الفراغ: لجعل Asterisk يطابق طلب SIP وارد بـ endpoint معين عن طريق عنوان IP المصدر (بدلاً من ترويسة `From`)، قم بإنشاء قسم باستخدام `type=________`.

8. أي كائن PJSIP يُستخدم لتكوين تسجيل **صادر** من Asterisk إلى مزود trunk من نوع SIP؟
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. في واجهة سطر أوامر Asterisk 22، ما هو الأمر الذي يفعّل مسجل حزم SIP الذي يطبع كل طلب ورد SIP على وحدة التحكم؟
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. على endpoint من نوع PJSIP يخدم هاتفاً خلف NAT متماثل، أي زوج من الإعدادات يجعل Asterisk يرد على عنوان مصدر الطلب (RFC 3581) ويرسل الوسائط (media) إلى المكان الذي تصل منه حزم RTP فعلياً؟
    - A. `direct_media=yes` و `srvlookup=yes`
    - B. `force_rport=yes` و `rtp_symmetric=yes`
    - C. `allowguest=yes` و `insecure=invite`
    - D. `qualify=yes` و `nat=no`

**الإجابات:** 1 — B · 2 — C · 3 — D · 4 — خطأ · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
