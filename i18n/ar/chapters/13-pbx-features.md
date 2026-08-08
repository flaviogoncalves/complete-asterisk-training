# استخدام ميزات PBX

في أنظمة SIP، يتم تنفيذ معظم ميزات الهاتف في الـ endpoint. توجد مجموعة متنوعة من هواتف SIP والشركات المصنعة، ولا يمكن ضمان التوافقية بينها. لقد قام فريق تطوير Asterisk بعمل رائع في تنفيذ معظم الميزات داخل الـ PBX نفسه، مما يجعل Asterisk مستقلاً تقريباً عن الـ endpoint. ومع ذلك، ستجد أحياناً أن الوظيفة نفسها يتم تنفيذها بواسطة الهاتف و Asterisk معاً. إن تكامل الهاتف مع الـ PBX هو الحدود التالية في سهولة الاستخدام، وهو المجال الذي تركز عليه الأنظمة الاحتكارية حالياً. في هذا الفصل، ستتعلم كيفية استخدام معظم هذه الميزات.

## الأهداف

بحلول نهاية هذا الفصل، ستكون قادراً على فهم واستخدام ما يلي:

- إيقاف المكالمات (Call Parking)
- التقاط المكالمات (Call Pickup)
- تحويل المكالمات (Call Transfer)
- مؤتمرات المكالمات (ConfBridge)
- تسجيل المكالمات (Call Recording)
- موسيقى الانتظار (Music on hold)

## أين يتم تنفيذ الميزات

أولاً وقبل كل شيء، من المهم فهم متى يتم تنفيذ ميزات PBX مقابل الوقت الذي يقوم فيه الهاتف بكل العمل. على سبيل المثال، قد تقوم بتحويل مكالمة باستخدام زر TRANSFER الموجود على الهاتف أو عن طريق طلب # (تحويل غير مشروط يتم تنفيذه بواسطة Asterisk نفسه).

## الميزات التي ينفذها Asterisk

يتم تنفيذ هذه الميزات في نظام PBX بواسطة كود Asterisk:

- Music on hold
- Call parking
- Call pickup
- Call recording
- ConfBridge conference room
- Call transfer (blind and consultative)

## الميزات التي يتم تنفيذها عادةً بواسطة الـ dial plan

تحتاج هذه الميزات إلى البرمجة في الـ dial plan الخاص بـ Asterisk (في الملف extensions.conf):

- تحويل المكالمات عند الانشغال (Call forward on busy)
- تحويل المكالمات الفوري (Call forward immediate)
- تحويل المكالمات عند عدم الرد (Call forward on unanswered)
- تصفية المكالمات (القائمة السوداء) (Call filtering (blacklist))
- عدم الإزعاج (Do not disturb)
- إعادة الاتصال (Redial)

## الميزات التي يتم تنفيذها عادةً بواسطة الهاتف

يتم تنفيذ هذه الميزات بواسطة البرامج الثابتة (firmware) الخاصة بالهاتف:

![مكان تنفيذ ميزات PBX عادةً: في Asterisk نفسه، أو في الـ dialplan، أو في الهاتف](../images/13-pbx-features-fig01.png)

- تعليق المكالمة (Call on hold)
- التحويل الأعمى (Blind transfer)
- التحويل الاستشاري (Consultative transfer)
- المؤتمرات ثلاثية الأطراف (Three-way conference)
- مؤشر انتظار الرسائل (Message waiting indicator)

## ملف إعدادات الميزات

يتم إعداد بعض الميزات المعروضة في هذا الفصل في ملف الإعدادات features.conf. من الممكن تغيير سلوك بعض الميزات عن طريق تعديل هذا الملف. لقد قمنا بتضمين المقتطف ذي الصلة أدناه. في الأقسام التالية من هذا الفصل، سنقوم بوصف كل ميزة. مقتطف من الملف النموذجي (Asterisk 22)

![قسم `[featuremap]` من ملف features.conf، مع رموز ميزات DTMF الافتراضية](../images/13-pbx-features-fig02.png)

منذ الإصدار Asterisk 12، تم نقل ميزة انتظار المكالمات (call parking) خارج `features.conf` إلى وحدتها الخاصة، `res_parking`، مع الإعدادات الموجودة في `res_parking.conf`. كتلة parking-lot أدناه (`parkext`، و`parkpos`، و`context`، و`parkingtime`، وما إلى ذلك) توجد في `res_parking.conf`. يظل قسم `[featuremap]` (رموز ميزات DTMF، بما في ذلك `parkcall`) في `features.conf`.

توجد خيارات parking-lot في `res_parking.conf`. توجد دائماً ساحة انتظار (parking lot) تسمى `default`، حتى لو لم تكن موجودة في ملف الإعدادات. المقتطف أدناه مأخوذ من Asterisk 22 `res_parking.conf.sample`:

```
; res_parking.conf
[default]                       ; Default Parking Lot
parkext => 700                  ; What extension to dial to park. (optional; if
                                ; specified, extensions will be created for parkext and
                                ; the whole range of parkpos)
parkpos => 701-720              ; What range of parking spaces to use - must be numeric.
                                ; Creates these spaces as extensions if parkext is set.
context => parkedcalls          ; Which context parked calls and the default park
                                ; extension are created in
;parkingtime => 45             ; Number of seconds a call can be parked before returning
;comebacktoorigin = yes        ; When a parked call times out, attempt to send it back to
                               ; the peer that parked it (default is yes)
;courtesytone = beep           ; Sound file to play when someone picks up a parked call
;parkedplay = caller           ; Who to play courtesytone to: parked, caller, both (default caller)
;parkedcalltransfers = caller  ; Enable DTMF transfers when picking up a parked call (default no)
;parkedcallreparking = caller  ; Enable DTMF parking when picking up a parked call (default no)
;parkedcallhangup = caller     ; Enable DTMF hangups when picking up a parked call (default no)
;findslot => next              ; 'next' uses the next space after the most recently used one;
                               ; 'first' (default) uses the lowest-numbered space available
;parkedmusicclass = default    ; MOH class to use for the parked channel
```

تظل رموز ميزات DTMF (بما في ذلك `parkcall` بخطوة واحدة) في قسم `[featuremap]` من `features.conf`:

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## تحويل المكالمات

يمكن تنفيذ تحويل المكالمات بواسطة الهاتف، أو عبر جهاز ATA، أو بواسطة Asterisk نفسه. ارجع إلى دليل هاتفك لفهم كيفية تحويل المكالمات. إذا كان هاتفك لا يدعم تحويل المكالمات، يمكنك استخدام Asterisk لإنجاز هذه المهمة. يتم تنفيذ تحويل المكالمات بطريقتين مختلفتين.

الطريقة الأولى هي استخدام ميزة التحويل الأعمى (blind transfer): اطلب # متبوعاً بالرقم المراد التحويل إليه. في بعض الأحيان، ستستخدم ميزة التحويل الخاصة بهاتف IP الخاص بك أو هاتف softphone. يمكنك تغيير رمز التحويل عن طريق تعديل المعامل blindxfer في ملف features.conf.

يمكنك تمكين التحويل المساعد (assisted transfer) في Asterisk عن طريق إزالة الفاصلة المنقوطة ; قبل المعامل atxfer في ملف features.conf. أثناء المحادثة، يمكنك الضغط على *2. سيقوم Asterisk بنطق كلمة "transfer" وسيعطيك نغمة اتصال. يتم وضع المتصل في حالة انتظار مع موسيقى (music on hold). بعد أن تتحدث إلى الشخص الوجهة وتغلق الهاتف، يقوم النظام بربط المتصل بالوجهة.

![تحويل المكالمات: خطوات التحويل الأعمى (اضغط # أثناء المكالمة) والتحويل المساعد (اضغط *2)](../images/13-pbx-features-fig03.png)

### قائمة مهام الإعداد

1. بالنسبة لـ endpoint من نوع PJSIP، تأكد من ضبط الخيار `direct_media` على `no` (بحيث تتدفق الوسائط عبر Asterisk ويتم اكتشاف رموز الميزات)، أو استخدم خيار `t`/`T` في تطبيق `Dial()`

## إيقاف المكالمات (Call parking)

تُستخدم هذه الميزة لإيقاف المكالمات مؤقتاً. يساعد هذا، على سبيل المثال، عندما ترد على مكالمة هاتفية خارج غرفتك وترغب في تحويل المكالمة إلى مكتبك. يمكنك تحقيق ذلك عن طريق إيقاف المكالمة في extension مخصص. بمجرد وصولك إلى مكتبك، ما عليك سوى طلب رقم الـ extension الخاص بالإيقاف لاستعادة المكالمة.

![إيقاف المكالمات: اطلب 700 لإيقاف المكالمة في أول خانة متاحة (701–720)؛ يعلن Asterisk عن رقم الخانة، والذي تطلبه من أي هاتف لاستعادة المكالمة](../images/13-pbx-features-fig04.png)

افتراضياً، يتم استخدام الـ extension رقم 700 لإيقاف المكالمة. في منتصف المحادثة، اضغط على # لتحويل المكالمة إلى الـ extension 700. الآن سيقوم Asterisk بالإعلان عن الـ extension الخاص بالإيقاف، مثل 701 أو 702. أغلق الهاتف، وسيتم وضع المتصل في حالة انتظار. اذهب إلى هاتف مكتبك واطلب الـ extension الذي تم الإعلان عنه لاستعادة المكالمة. إذا تم إيقاف المتصل لفترة طويلة، فسيتم تفعيل ميزة المهلة (timeout) وسيرن الـ extension الأصلي الذي تم الاتصال به مرة أخرى.

### قائمة مهام الإعداد

اتبع الخطوات أدناه لتمكين ميزة إيقاف المكالمات. الخطوة 1: اجعل ساحة الإيقاف (parking lot) قابلة للوصول من الـ dialplan الخاص بك (مطلوب). الـ `context` الافتراضي لساحة الإيقاف هو `parkedcalls` (محدد في `res_parking.conf`). قم بتضمين ذلك الـ context في الـ context الذي تتصل منه هواتفك، في `extensions.conf`:

```
include => parkedcalls
```

الخطوة 2: اختبر ميزة إيقاف المكالمات عن طريق طلب #700. ملاحظات:

- لن يظهر الـ extension الخاص بالإيقاف في أمر الـ CLI المسمى dialplan show.
- من الضروري إعادة تحميل وحدة الإيقاف بعد تغيير ملف إعدادات الإيقاف: `module reload res_parking.so`. بالنسبة لتغييرات features.conf، استخدم `module reload features.so`.
- لإيقاف مكالمة، تحتاج إلى التحويل إلى #700. تحقق من الخيارات `t` و `T` في التطبيق `Dial()`.

## التقاط المكالمات

تتيح لك ميزة التقاط المكالمات (Call pickup) استقبال مكالمة موجهة إلى زميل في نفس مجموعة الاتصال. يساعد هذا، على سبيل المثال، في تجنب الاضطرار للنهوض للرد على مكالمة ترن لهاتف شخص آخر في غرفتك وهو غير موجود. عن طريق طلب *8، يمكنك التقاط مكالمة ضمن مجموعة الاتصال الخاصة بك. يمكن تعديل هذا الرقم في ملف `features.conf`.

![التقاط المكالمات: يمكن للأعضاء فقط التقاط المكالمات داخل مجموعتهم الخاصة؛ بينما يمكن للمشغل (pickupgroup=1,2,3) التقاط المكالمات من كل مجموعة](../images/13-pbx-features-fig05.png)

### قائمة مهام الإعداد

اتبع الخطوات أدناه لإعداد ميزة التقاط المكالمات. الخطوة 1: قم بإعداد مجموعة اتصال لـ extensions الخاصة بك. يتم ذلك في ملف إعداد القناة (pjsip.conf, iax.conf, chan_dahdi.conf). بالنسبة لـ endpoints الخاصة بـ PJSIP، قم بضبط `call_group` و `pickup_group` في قسم endpoint من `pjsip.conf` (يستخدم pjsip.conf أسماء خيارات بصيغة snake_case). هذه المهمة مطلوبة.

بالنسبة لـ PJSIP (pjsip.conf):
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


الخطوة 2: تغيير رقم ميزة التقاط المكالمات (اختياري). يتم ضبط هذا في قسم `[general]` من `features.conf`، وليس في `pjsip.conf`:

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## المؤتمر (المكالمات الجماعية)

هناك طرق مختلفة لتنفيذ المؤتمرات على Asterisk. الخيار الأول هو ببساطة استخدام إمكانية المؤتمر ثلاثي الأطراف في الهاتف نفسه. باستخدام هذه الميزة في الهاتف، لن تحتاج إلى أي دعم في الخادم ذاته. ومع ذلك، عندما ترغب في إجراء مؤتمر يضم أكثر من 3 أشخاص، يجب عليك تشغيل غرفة مؤتمرات. تطبيق المؤتمرات الحديث في Asterisk هو ConfBridge (`app_confbridge`).

يدعم ConfBridge مؤتمرات الصوت عالي الدقة (HD) ومؤتمرات الفيديو. هناك بعض القيود على مؤتمرات الفيديو مثل عدم وجود تحويل للترميز (transcoding) — حيث يجب على جميع المشاركين استخدام نفس الـ codec والملف التعريفي. يستخدم مؤتمر الفيديو وضع "متابعة المتحدث"، حيث يتم عرض صورة آخر شخص تحدث. يمكنك بسهولة تكوين قوائم DTMF جديدة في ConfBridge.

يحل ConfBridge محل تطبيق MeetMe القديم، الذي تم إيقاف دعمه في Asterisk 19. لا يزال MeetMe موجوداً في شجرة مصادر Asterisk 22، لكنه يعتمد على DAHDI ولا يتم بناؤه افتراضياً، لذا في تثبيت PJSIP نموذجي يكون غير متاح ببساطة — وConfBridge هو تطبيق المؤتمرات المدعوم. على عكس MeetMe، لا يتطلب ConfBridge وجود DAHDI أو مصدر توقيت عتادي: فهو يعتمد على واجهة التوقيت المدمجة في Asterisk (`res_timing_timerfd` على Linux، أو `res_timing_pthread`)، لذا لا حاجة إلى وحدة `dahdi_dummy`. إذا كنت تقوم بالترحيل من نظام قديم كان يستخدم `MeetMe()` و`meetme.conf`، فاستبدلهما بـ `ConfBridge()` و`confbridge.conf` كما هو موضح أدناه.

### ConfBridge

لبدء غرفة مؤتمرات، يتم سرد الصيغة أدناه.

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

للحصول على وصف كامل للأمر، يمكنك استخدام core show application confbridge.

![مخرجات `core show application confbridge`، توضح الملخص، الصيغة، ووسائط bridge_profile وuser_profile وmenu](../images/13-pbx-features-fig06.png)

![عدة نقاط نهاية PJSIP تنضم إلى مؤتمر ConfBridge واحد مسمى (101)؛ أحد المشاركين هو المسؤول. يتم التعامل مع المزج والتوقيت بواسطة `app_confbridge` جنباً إلى جنب مع `bridge_softmix` ومؤقت `res_timing_*` المدمج — لا حاجة إلى DAHDI.](../images/13-pbx-features-fig09.png)

كما ترى أعلاه، هناك ثلاث وسائط مهمة، كل منها يطابق نوع قسم في `confbridge.conf`. **bridge_profile** (قسم `type=bridge`): هنا تختار الحد الأقصى لعدد المشاركين (`max_members`)، والتسجيل (`record_conference`)، و`video_mode`، والعديد من المعلمات الأخرى الخاصة بالجسر ككل.

ليس من المنطقي إعادة إنتاج ملف المثال بالكامل هنا، لذا سأقدم لك مثالاً بسيطاً حول كيفية تكوين bridge_profile في ملف confbridge.conf.

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile** (قسم `type=user`): هنا تحدد الخيارات الخاصة بكل مستخدم، مثل ما إذا كان المستخدم مسؤولاً (`admin=yes`)، وما إذا كان يبدأ في وضع كتم الصوت (`startmuted=yes`)، وموسيقى الانتظار، والعديد من الخيارات الأخرى لكل مستخدم. مثال:

```
[admin_user]
type=user
admin=yes
```

**menu** (قسم `type=menu`): هنا تحدد تعيين لوحة المفاتيح (DTMF) للمؤتمر — على سبيل المثال، أي مفتاح يقوم بتبديل كتم الصوت، أو ضبط مستوى الصوت، أو مغادرة المؤتمر. تحقق من ملف `confbridge.conf.sample` لرؤية جميع الإجراءات المتاحة. مثال:

```
[my_menu]
type=menu
*=playback_and_continue
1=toggle_mute
2=decrease_listening_volume
3=increase_listening_volume
4=decrease_talking_volume
5=increase_talking_volume
6=leave_conference
```

#### وظائف Confbridge

يمكن تمرير خيارات جسر المؤتمر ديناميكياً في الـ dialplan باستخدام وظيفة CONFBRIDGE(). انظر الأمثلة أدناه:

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### أوامر مسؤول ConfBridge والترحيل من MeetMe

إذا كنت قادماً من MeetMe، فإن وظائف المسؤول التي كنت تستخدمها من خلال `MeetMeAdmin()` وخيار `a` (المسؤول) يتم التعبير عنها الآن من خلال **ملف تعريف المستخدم المسؤول** (`admin=yes`) بالإضافة إلى إجراءات **القائمة**. يمكن للمسؤول الذي ينضم بملف تعريف مسؤول وقائمة تحتوي على إجراءات المسؤول قفل الغرفة، وطرد المستخدمين، وكتم صوت المشاركين مباشرة من لوحة المفاتيح. إجراءات القائمة ذات الصلة في `confbridge.conf` هي:

- `admin_kick_last` -- طرد آخر مستخدم انضم
- `admin_toggle_mute_participants` -- كتم/إلغاء كتم صوت جميع المشاركين غير المسؤولين
- `toggle_mute` -- كتم/إلغاء كتم صوتك
- `participant_count` -- الإعلان عن عدد المشاركين
- `leave_conference` -- مغادرة الجسر والمتابعة في الـ dialplan

تحل هذه محل علامات خيار MeetMe `MeetMe()` (`a`، `A`، `m`، `M`، `l`، `x`، …) وأوامر `MeetMeAdmin()` (`k`، `K`، `L`، `M`، `N`، …). في تثبيت PJSIP حديث، لن تقوم بتحميل `app_meetme` على الإطلاق؛ حيث توجد جميع تكوينات المؤتمرات في `confbridge.conf`، ويتم تطبيق التغييرات باستخدام `module reload app_confbridge.so` (منطق ConfBridge موجود في `app_confbridge`؛ لا توجد وحدة `res_confbridge`).

### مثال على ConfBridge

لإنشاء غرفة مؤتمرات يمكن الوصول إليها عبر الـ extension 500، في `extensions.conf`:

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

أول متصل يتصل بالرقم 500 ينشئ المؤتمر `101`؛ وينضم إليه المتصلون اللاحقون. الملفات التعريفية والقوائم المشار إليها هنا (`default_bridge`، `default_user`، `sample_user_menu`) محددة في `confbridge.conf`. لطلب رمز PIN، قم بتعيين `pin=` في ملف تعريف المستخدم؛ ولجعل مشارك ما مسؤولاً عن المؤتمر، امنحه ملف تعريف مستخدم مع `admin=yes`.

## تسجيل المكالمات

توجد عدة طرق لتسجيل مكالمة في Asterisk. يمكنك استخدام التطبيق `MixMonitor()` لتسجيل المكالمات بسهولة. (تمت إزالة التطبيق الأقدم `Monitor`، الذي كان يسجل ملفين منفصلين؛ استخدم `MixMonitor` بدلاً منه.)

### استخدام تطبيق MixMonitor

يقوم التطبيق `MixMonitor` بتسجيل الصوت في القناة الحالية إلى الملف المحدد. إذا كان اسم الملف مساراً مطلقاً، فإنه يستخدم ذلك المسار. وبخلاف ذلك، يقوم بإنشاء الملف في دليل المراقبة المكون في asterisk.conf.

![تطبيق MixMonitor(): يقوم بتسجيل ودمج صوت القناة في ملف واحد، مع خيارات للإلحاق، والدمج عند التجسير فقط، وتعديل مستوى الصوت](../images/13-pbx-features-fig09.png)

### MixMonitor()

سجل مكالمة وادمج الصوت أثناء التسجيل. الصيغة: `MixMonitor(filename.extension[,options[,command]])`. يسجل الصوت على القناة الحالية إلى الملف المحدد. الخيارات الصالحة هي:

- a - يلحق البيانات بالملف بدلاً من الكتابة فوقه.
- b - يحفظ الصوت في الملف فقط أثناء وجود القناة في حالة تجسير.
- ملاحظة: لا يشمل المؤتمرات.
- v(<x>) - يضبط مستوى الصوت المسموع بمعامل <x> (يتراوح من -4 إلى 4)
- V(<x>) - يضبط مستوى الصوت المنطوق بمعامل <x> (يتراوح من -4 إلى 4)
- W(<x>) - يضبط كلاً من مستوى الصوت المسموع والمنطوق بمعامل <x> (يتراوح من -4 إلى 4)
- سيتم تنفيذ <command> عند انتهاء التسجيل. سيتم فك ترميز أي سلاسل نصية تطابق ^{X} إلى ${X} وسيتم تقييم جميع المتغيرات في ذلك الوقت. سيحتوي المتغير MIXMONITOR_FILENAME على اسم الملف المستخدم للتسجيل.

من الموارد المثيرة للاهتمام ميزة التسجيل بلمسة واحدة `automixmon`، والتي تتيح لأحد الطرفين طلب رمز DTMF (يقترح نموذج `features.conf` الرمز `*3`؛ لا يوجد افتراضي مدمج، لذا يجب عليك تعيينه) أثناء المكالمة لبدء التسجيل (وإيقافه) فوراً. تعتمد هذه الميزة على MixMonitor، لذا فهي تكتب ملفاً مدمجاً واحداً. مثال:

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

يُفعل الخياران `X` و `x` ميزة MixMonitor بلمسة واحدة للمتصل والمستقبل على التوالي. نظراً لأن MixMonitor يسجل ملفاً مدمجاً واحداً، فلا حاجة لدمج ملفات IN/OUT منفصلة بعد ذلك (تمت إزالة نهج `automon`/`Monitor` القديم، الذي كان ينتج ملفين لـ `soxmix`، جنباً إلى جنب مع التطبيق `Monitor`).

إذا كنت لا ترغب في استخدام Set() قبل تطبيق Dial()، يمكنك تعيين ذلك في قسم globals:

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### موسيقى الانتظار

تغيرت موسيقى الانتظار (MOH) عدة مرات بين الإصدارات 1.0 و 1.2 و 1.4. في الإصدار الأحدث، تكون MOH افتراضياً "FILE-BASED". بمعنى آخر، سيوفر Asterisk ملفات MOH بتنسيقات مثل g729 و alaw و ulaw و gsm. وبالتالي، ليس من الضروري إعادة ترميز الموسيقى قبل إرسالها إلى القناة. هذا يوفر وقت المعالج، وهو تعديل مرحب به لأولئك الذين يعملون مع أنظمة الإنتاج.

في الإصدارات الأقدم، كانت MOH تُقدم عادةً بواسطة MP3 (لا يزال من الممكن تكوينها بهذه الطريقة). إن تقديم MOH باستخدام MP3 يجبر Asterisk على إعادة الترميز، مما يستهلك طاقة معالج قيمة في هذه العملية.

يظهر ملف التكوين الجديد أدناه. لاحظ أن الفئة الافتراضية تستخدم الآن وضع تنسيق الملف الأصلي mode=files. جميع الأوضاع الأخرى معلقة (موضوعة في تعليقات). كل قسم هو فئة. الفئة الوحيدة غير المعلقة في هذه المرحلة هي default. إذا كنت ترغب في الحصول على فئات مختلفة لملفات مختلفة، فستحتاج إلى إنشاء أقسام (فئات) جديدة.

![نموذج تكوين musiconhold.conf، الذي يسرد أوضاع MOH الصالحة (quietmp3, mp3, custom, files, …)](../images/13-pbx-features-fig10.png)

```
; Music on Hold -- Sample Configuration
;[samplemp3]
;mode=quietmp3
;directory=/var/lib/asterisk/mohmp3
;
; valid mode options:
; quietmp3      -- default
; mp3           -- loud
; mp3nb         -- unbuffered
; quietmp3nb    -- quiet unbuffered
; custom        -- run a custom application (See examples below)
; files         -- read files from a directory in any Asterisk supported
;                  media format. (See examples below)
;[manual]
;mode=custom
; Note that with mode=custom, a directory is not required, such as when reading
; from a stream.
;directory=/var/lib/asterisk/mohmp3
;application=/usr/bin/mpg123 -q -r 8000 -f 8192 -b 2048 --mono -s
;[ulawstream]
;mode=custom
;application=/usr/bin/streamplayer 192.168.100.52 888
;format=ulaw
; mpg123 on Solaris does not always exit properly; madplay may be a better
; choice
;[solaris]
;mode=custom
;directory=/var/lib/asterisk/mohmp3
;application=/site/sw/bin/madplay -Q -o raw:- --mono -R 8000 -a -12
;
;
; File-based (native) music on hold
;
; This plays files directly from the specified directory, no external
; processes are required. Files are played in normal sorting order
; (same as a sorted directory listing), and no volume or other
; sound adjustments are available. If the file is available in
; the same format as the channel's codec, then it will be played
; without transcoding (same as Playback would do in the dialplan).
; Files can be present in as many formats as you wish, and the
; 'best' format will be chosen at playback time.
;
; NOTE:
; If you are not using "autoload" in modules.conf, then you
; must ensure that the format modules for any formats you wish
; to use are loaded _before_ res_musiconhold. If you do not do
; this, res_musiconhold will skip the files it is not able to
; understand when it loads.
;
[default]
mode=files
directory=/var/lib/asterisk/moh
;
;[native-random]
;mode=files
;directory=/var/lib/asterisk/moh
;random=yes     ; Play the files in a random order
```

### مهام تكوين MOH

الآن، لاستخدام موسيقى الانتظار، قم بتعيين فئة MOH في ملفات تكوين القناة (chan_dahdi.conf و pjsip.conf و iax.conf، وما إلى ذلك). بالنسبة لنقاط نهاية PJSIP، قم بتعيين `moh_suggest` في قسم endpoint من `pjsip.conf` (اسم الخيار القديم `musicclass` ينطبق على chan_dahdi ومشغلات القنوات الأخرى، وليس على PJSIP). أصبحت نغمات freeplay المثبتة الآن بتنسيق wav. في وقت التثبيت، يمكنك تحديد (باستخدام make menuselect) تنسيقات ملفات MOH المتاحة. إذا كنت ترغب في إضافة ملفات MOH جديدة، فسيتعين عليك توفيرها بالتنسيقات المطلوبة. على سبيل المثال:

في `/etc/asterisk/chan_dahdi.conf`، أضف السطر `musiconhold`:

```
[channels]
musiconhold=default
```

ثم قم بتحرير `/etc/asterisk/musiconhold.conf` لتعريف تلك الفئة:

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

في dialplan، يمكنك بدء موسيقى الانتظار على قناة باستخدام `StartMusicOnHold` (وإيقافها باستخدام `StopMusicOnHold`):

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

لتشغيل موسيقى الانتظار لفترة زمنية محددة كاختبار سريع، استخدم التطبيق `MusicOnHold` مع تحديد المدة (بالثواني):

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## خرائط التطبيقات (Application Maps)

تسمح لك خرائط التطبيقات بإضافة ميزات جديدة باستخدام قسم `[applicationmap]` في ملف features.conf. لنفترض أنك بحاجة إلى تحديد نوع العميل الذي تجيب عليه في مركز اتصال. يمكنك إنشاء خريطة تطبيق لكل نوع من أنواع العملاء، والتي يمكنها حساب عدد العملاء الذين تمت الإجابة عليهم لكل نوع.

## ملخص

في هذا الفصل، تعلمت أين توجد ميزات PBX الخاصة بـ Asterisk — بعضها في النواة، وبعضها في الـ dialplan، وبعضها على الهاتف — وكيف يتم تعيين رموز ميزات DTMF في قسم `[featuremap]` من `features.conf`. لقد قمت بتهيئة **تحويل المكالمات** (الأعمى والمباشر) و**انتظار المكالمات** (`res_parking.conf`، مع خيارات Dial في `k`/`K` وساحة `parkedcalls`)، و**التقاط المكالمات** حسب المجموعة، و**المؤتمرات** باستخدام **ConfBridge** (ملفات تعريف bridge/user/menu في `confbridge.conf`)، والتي تحل محل MeetMe القديمة. لقد قمت بإعداد **التسجيل بلمسة واحدة** باستخدام MixMonitor (`automixmon`، وخيارات Dial في `X`/`x`، و`DYNAMIC_FEATURES`)، وتهيئة **موسيقى الانتظار**، ورأيت كيف تتيح لك **خرائط التطبيقات** ربط منطق الـ dialplan الخاص بك بتسلسل DTMF. باستخدام هذه اللبنات الأساسية، يمكنك تقديم الميزات اليومية التي يتوقعها المستخدمون من نظام PBX للأعمال.

## اختبار

1. أي من العبارات التالية صحيحة حول ميزة إيقاف المكالمات (call parking)؟
   - A. افتراضياً، يتم استخدام extension 800 لإيقاف المكالمات.
   - B. عندما تكون بعيداً عن مكتبك وتتلقى مكالمة، يمكنك إيقافها؛ حيث يعلن النظام عن رقم فتحة الإيقاف، ويمكنك طلب ذلك الرقم من أي هاتف لاستعادة المكالمة.
   - C. افتراضياً، يقوم extension 700 بإيقاف المكالمة، ويتم إيقاف المكالمات في الفتحات من 701 إلى 720.
   - D. تقوم بطلب 700 لاستعادة مكالمة متوقفة.
2. لاستخدام ميزة التقاط المكالمات (call-pickup)، يجب أن تكون جميع الـ extensions في نفس الـ ___. بالنسبة لقنوات DAHDI، يتم تكوين هذا في ملف ___.
3. عند تحويل مكالمة، يمكنك الاختيار بين تحويل ___، حيث لا يتم استشارة الوجهة أولاً، وتحويل ___، حيث تتحدث إلى الوجهة قبل إكمال التحويل.
4. لإجراء تحويل مُدار (استشاري)، تستخدم تسلسل ___؛ وللتحويل الأعمى (blind transfer) تستخدم ___.
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. لاستضافة مكالمات جماعية (conference calls) في Asterisk 22، تستخدم تطبيق ___.
6. في ConfBridge، يتم منح المشارك صلاحيات المسؤول (الطرد، كتم صوت الآخرين، قفل الغرفة) عن طريق ضبط ___ في ملف تعريف المستخدم الخاص به (`confbridge.conf`):
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. التنسيق الأفضل للموسيقى أثناء الانتظار (music on hold) هو MP3، لأنه يستهلك القليل جداً من طاقة المعالجة على خادم Asterisk.
   - A. صح
   - B. خطأ
8. لالتقاط مكالمة من مجموعة التقاط (call group) محددة، يجب أن تكون في مجموعة ___ المطابقة.
9. يمكنك تسجيل مكالمة باستخدام تطبيق MixMonitor() أو ميزة التسجيل بلمسة واحدة (`automixmon`). في نموذج `features.conf`، يتم تعيين `automixmon` لتسلسل DTMF التالي:
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. في ConfBridge، أي خيار من خيارات ملف تعريف المستخدم `confbridge.conf` يجعل المشارك ينضم وهو في حالة كتم للصوت (يمكنه سماع المؤتمر ولكن لا يمكن سماعه حتى يتم إلغاء الكتم)؟
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**الإجابات:** 1 — B, C · 2 — pickup group; `chan_dahdi.conf` · 3 — blind; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
