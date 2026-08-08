# واجهة Asterisk REST (ARI)

غطى الفصل السابق AMI و AGI، وهما الطريقتان التقليديتان لربط المنطق الخارجي بـ Asterisk. كلاهما يسبق عصر الويب الحديث: حيث تمنحك AMI تدفق أحداث خام وموجه نحو الأسطر عبر مقبس TCP، بينما تمنح AGI قناة واحدة لبرنامج نصي طوال مدة المكالمة. لم يتم تصميم أي منهما للتطبيقات الحديثة التي تعتمد على الحالة، وغير المتزامنة، ومتعددة القنوات التي يبنيها الناس اليوم — مثل IVR التي تتصل بخدمات الويب، ولوحات تحكم النقر للاتصال (click-to-call)، وأجهزة التحكم في المؤتمرات، أو روبوتات الصوت التي تبث الصوت إلى محرك تحويل الكلام.

تم تقديم ARI — واجهة Asterisk REST — في Asterisk 12 لسد هذه الفجوة، وفي Asterisk 22 أصبحت الواجهة الموصى بها لبناء تطبيقات هاتفية جديدة. الفكرة وراء ARI هي الفصل الواضح بين المهام: **يصبح Asterisk محرك وسائط** (يقوم بالرد على القنوات، ودمج الجسور، وتشغيل وتسجيل الصوت، وإرسال DTMF)، و**يقدم تطبيقك كل منطق التحكم في المكالمات** من خلال مزيج من واجهة برمجة تطبيقات REST (HTTP) وتدفق أحداث WebSocket.

## الأهداف

بحلول نهاية هذا الفصل، ينبغي أن يكون القارئ قادراً على:

- شرح ماهية ARI وكيف تختلف عن AMI و AGI
- تحديد متى تكون ARI هي الواجهة المناسبة لمشروع ما
- تهيئة `ari.conf` و `http.conf` لتمكين ARI وإنشاء مستخدم
- الاتصال ببث أحداث WebSocket الخاص بـ ARI
- وصف تطبيق dialplan المسمى Stasis وأحداث `StasisStart`/`StasisEnd`
- وصف نموذج موارد ARI: القنوات (channels)، والجسور (bridges)، والتشغيل (playbacks)، والتسجيلات (recordings)، و endpoints، وحالات الأجهزة (device states)
- كتابة تطبيق Stasis بسيط بلغة Python يقوم بالرد على قناة، وتشغيل صوت، وإنهاء المكالمة
- شرح ماهية القناة `externalMedia` وسبب أهميتها لتكاملات الذكاء الاصطناعي وروبوتات الصوت (voicebot)

## ما هو ARI، ومتى يجب استخدامه

يعتمد ARI على بروتوكولي نقل يعملان معاً:

- **واجهة برمجة تطبيقات REST (HTTP)** التي يستدعيها تطبيقك *للقيام* بأشياء معينة — مثل إنشاء قناة، أو الرد عليها، أو تشغيل صوت، أو إنشاء جسر (bridge)، أو بدء تسجيل، أو إنهاء المكالمة. هذه طلبات HTTP عادية (`GET`، `POST`، `DELETE`) يتم توجيهها إلى `http://asterisk-host:8088/ari/...`.
- **تدفق أحداث WebSocket** الذي يخبر Asterisk من خلاله تطبيقك بما يحدث — مثل إنشاء قناة، أو وصول رقم DTMF، أو انتهاء تشغيل صوت، أو خروج قناة من تطبيقك. يتم تسليم الأحداث ككائنات JSON.

النمط هنا غير متزامن (asynchronous): أنت ترسل طلباً، وعادة ما تعود *نتيجة* هذا الطلب لاحقاً كحدث. على سبيل المثال، أنت ترسل `POST` طلباً لتشغيل صوت؛ فيرد Asterisk فوراً بكائن `Playback`، وبعد بضع ثوانٍ تتلقى حدث `PlaybackFinished` عند انتهاء الصوت.

اختر ARI بدلاً من AMI و AGI عندما:

- تحتاج إلى **تحكم دقيق في القنوات والجسور** — مثل بناء المؤتمرات، أو الانتظار (parking)، أو الطوابير، أو مسارات مكالمات مخصصة باستخدام عناصر أولية بدلاً من الاعتماد على تطبيقات dialplan.
- يكون تطبيقك **محتفظاً بالحالة (stateful) وطويل الأمد**، حيث يتعامل مع عدة قنوات في وقت واحد ويتفاعل مع الأحداث عبرها جميعاً.
- ترغب في التكامل مع **خدمات الويب، أو ناقلات الرسائل، أو محركات الذكاء الاصطناعي/الكلام** وتفضل استخدام JSON عبر HTTP بدلاً من بروتوكول خطي أو سكربت يعتمد على stdin/stdout.
- تبدأ **مشروعاً جديداً** وتريد الواجهة التي يوصي بها مشروع Asterisk بشكل نشط.

لا يزال AMI الأداة المناسبة عندما تحتاج فقط إلى *مراقبة* النظام أو إرسال أوامر عرضية (مثل برامج الاتصال، أو لوحات العرض، أو المراقبة). ولا يزال AGI مناسباً لسكربت IVR سريع ومستقل. ولكن بالنسبة لأي شيء يقوم بتنسيق المكالمات، فإن ARI هو الحل الحديث.

> لا يحل ARI محل dialplan — بل يكمله. تعمل القناة في dialplan كالمعتاد حتى تصل إلى تطبيق `Stasis()`، وعند هذه النقطة يتم تسليم التحكم إلى تطبيق ARI الخاص بك. وعندما ينتهي تطبيقك من عمله، يمكن إعادة القناة إلى dialplan أو إنهاؤها.

## تفعيل ARI: ملفا http.conf و ari.conf

يعمل ARI فوق خادم HTTP المدمج في Asterisk، لذا يتطلب الأمر التعامل مع ملفي إعداد: يقوم `http.conf` بتفعيل خادم الويب، بينما يقوم `ari.conf` بتفعيل ARI وتحديد مستخدميه.

### http.conf

يجب تفعيل خادم HTTP وربطه بعنوان ومنفذ محددين. المنفذ التقليدي لـ ARI هو **8088**.

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
```

بالنسبة لبيئات الإنتاج، يجب عليك وضع ARI خلف بروتوكول TLS. يمكن لـ Asterisk تقديم خدمة HTTPS مباشرة (`tlsenable=yes`، `tlsbindaddr`، `tlscertfile`، `tlsprivatekey`)، أو يمكنك إنهاء اتصال TLS في وكيل عكسي (reverse proxy) أمام المنفذ 8088. عبر TLS، تصبح عناوين URL هي `https://` و `wss://` بدلاً من `http://` و `ws://`.

يمكنك التأكد من عمل خادم HTTP من خلال واجهة سطر الأوامر CLI:

```
asterisk*CLI> http show status
HTTP Server Status:
Server Enabled and Bound to 0.0.0.0:8088
```

### ari.conf

يحتوي `ari.conf` على قسم `[general]` وقسم واحد لكل مستخدم.

```ini
[general]
enabled=yes
pretty=yes              ; pretty-print JSON responses (handy while learning)

[asterisk]
type=user
read_only=no            ; set to yes for a user that may only issue GET requests
password=secret
password_format=plain   ; "plain" (default) or "crypt"
```

بعض الملاحظات حول هذه الخيارات:

- يقوم `enabled` بتشغيل أو إيقاف ARI على المستوى العام.
- يقوم `pretty` بتنسيق استجابات JSON لتكون مقروءة للبشر؛ قم بإيقاف هذا الخيار في بيئة الإنتاج.
- كل مستخدم هو عبارة عن قسم مسمى باستخدام `type=user`.
- يقوم `read_only=yes` بتقييد ذلك المستخدم بطلبات القراءة فقط (GET).
- قد يكون `password_format` إما `plain` (كلمة المرور بنص صريح) أو `crypt` (كلمة مرور مشفرة، يتم إنشاؤها باستخدام `mkpasswd -m sha-512`).
- تسمح `permit` و `deny` و `acl` بفرض قيود على عناوين IP لكل مستخدم، باتباع نفس قواعد `acl.conf`.

بعد تعديل الملفات، أعد تحميل الوحدات ذات الصلة (`module reload res_ari.so` و `module reload http.so`) أو أعد تشغيل Asterisk. يمكنك التحقق من أن ARI يعمل باستخدام:

```
asterisk*CLI> module show like res_ari
res_ari.so          Asterisk RESTful Interface          Running
res_ari_channels.so RESTful API module - Channel res... Running
res_ari_bridges.so  RESTful API module - Bridge reso... Running
...

asterisk*CLI> ari show apps
Application Name
=========================
```

يسرد `ari show apps` تطبيقات Stasis المسجلة حالياً بواسطة العملاء المتصلين. يكون هذا السجل فارغاً حتى يتصل عميل ما، وهو بالضبط ما سنقوم به تالياً.

### عنوان URL لأحداث WebSocket

يشترك العميل في تدفق الأحداث عن طريق فتح اتصال WebSocket إلى نقطة النهاية `/ari/events`، مع تسمية تطبيق Stasis الذي ينفذه وتمرير بيانات اعتماده:

```
ws://asterisk-host:8088/ari/events?app=hello&api_key=asterisk:secret
```

معاملات الاستعلام هي:

- `app` — اسم تطبيق Stasis الخاص بك. هذا هو نفس الاسم الذي ستستخدمه في استدعاء `Stasis()` داخل الـ dialplan. يمكنك تمرير عدة أسماء مفصولة بفواصل.
- `api_key` — بيانات الاعتماد، بصيغة `username:password`، والتي تطابق مستخدماً في `ari.conf`.
- `subscribeAll` — قيمة منطقية اختيارية (الافتراضي هو `false`)؛ عندما تكون `true`، يتلقى التطبيق جميع الأحداث، وليس فقط تلك المتعلقة بالموارد التي يمتلكها.

تُستخدم نفس بيانات اعتماد `user:pass` كـ HTTP Basic auth في طلبات REST (أو تُلحق كمعامل استعلام `api_key` هناك أيضاً).

## Stasis: تسليم القناة إلى تطبيقك

الجسر الرابط بين الـ dialplan و ARI هو تطبيق الـ dialplan المسمى **`Stasis()`** (يُطلق اسم Stasis أيضاً على الإطار البرمجي الأساسي). عندما تصل القناة إلى `Stasis(appname[,args])`، يقوم Asterisk بتسليم تلك القناة إلى تطبيق ARI المسجل تحت `appname` ويتوقف عن تنفيذ الـ dialplan الخاص بها. الآن، أصبحت السيطرة في يد الكود الخاص بك.

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

عندما تدخل القناة إلى التطبيق، يتلقى كل عميل متصل ومشترك في `hello` حدث **`StasisStart`** عبر الـ WebSocket، والذي يحمل كائن القناة بالكامل (معرفه، واسمه، ومعرف المتصل، وحالته، وأي وسائط تم تمريرها إلى `Stasis()`). هذه هي إشارتك للبدء في التحكم في القناة.

عندما تغادر القناة التطبيق — سواء لأن الكود الخاص بك أعادها إلى الـ dialplan باستخدام `continueInDialplan`، أو لأنه تم إنهاء المكالمة — تتلقى حدث **`StasisEnd`**. بعد أن يعود `Stasis()` إلى الـ dialplan، فإنه يقوم بضبط متغير القناة `STASISSTATUS` (على `SUCCESS` أو `FAILED`)، بحيث يمكن للـ dialplan التفرع بناءً على النتيجة.

## نموذج موارد ARI

يكشف ARI عن الأجزاء الداخلية لـ Asterisk كمجموعة صغيرة من موارد REST. يعيش كل مورد تحت `/ari/<resource>` ويتم التعامل معه باستخدام طرق HTTP القياسية. أهم هذه الموارد هي:

| المورد | ما يمثله | عمليات مثال |
|----------|--------------------|--------------------|
| **channels** | طرف اتصال واحد | originate, answer, play, record, hangup |
| **bridges** | نقطة دمج تربط القنوات | create, add/remove channels, play to the bridge |
| **playbacks** | تشغيل وسائط قيد التنفيذ | get status, stop, pause/unpause |
| **recordings** | تسجيلات مباشرة ومخزنة | start, stop, list stored, delete |
| **endpoints** | الأقران المكونة (PJSIP، إلخ) | list, get state, send a message |
| **deviceStates** | حالات الجهاز المخصصة | list, get, set, delete |

بعض استدعاءات REST الملموسة (المسارات تظهر مع البادئة `/ari` التي تظهر على الشبكة):

```
# Channels
POST   /ari/channels                          # originate a new channel
POST   /ari/channels/{channelId}/answer       # answer an incoming channel
POST   /ari/channels/{channelId}/play         # play media (body: media=sound:hello-world)
POST   /ari/channels/{channelId}/record       # record the channel
DELETE /ari/channels/{channelId}              # hang up the channel

# Bridges
POST   /ari/bridges                           # create a bridge (e.g. type=mixing)
POST   /ari/bridges/{bridgeId}/addChannel     # add a channel (param: channel=<id>)
POST   /ari/bridges/{bridgeId}/play           # play media to everyone in the bridge
DELETE /ari/bridges/{bridgeId}                # destroy the bridge

# Read-only resources
GET    /ari/endpoints
GET    /ari/deviceStates
GET    /ari/recordings/stored
GET    /ari/playbacks/{playbackId}
```

يأخذ المعامل `media` في طلب `play` عنوان URI للوسائط. الشكل الأكثر شيوعاً هو عنوان URI من النوع `sound:` الذي يسمي صوتاً مدمجاً، على سبيل المثال `sound:hello-world` أو `sound:tt-monkeys`. عند انتهاء الصوت، يصدر Asterisk حدث `PlaybackFinished` لمعرف التشغيل ذلك، وهي الطريقة التي يعرف بها تطبيقك أنه يمكنه المتابعة.

القنوات والجسور هي اللبنتان الأساسيتان اللتان تجمعهما لإنشاء مسارات المكالمات. لربط متصلين، على سبيل المثال، تقوم بإنشاء أو قبول قناتين، وإنشاء جسر `mixing` باستخدام `POST /ari/bridges`، وإضافة كلتا القناتين إليه باستخدام `POST /ari/bridges/{bridgeId}/addChannel`. لبناء مؤتمر، ما عليك سوى الاستمرار في إضافة القنوات إلى نفس الجسر.

## مثال عملي: تطبيق Stasis مصغر

لنقم ببناء أصغر تطبيق مفيد باستخدام ARI. عند طلب أي extension، تدخل المكالمة إلى تطبيق Stasis الخاص بنا، والذي يقوم بالرد عليها، وتشغيل رسالة `hello-world` الكلاسيكية، ثم إنهاء المكالمة.

### الـ dialplan

في `extensions.conf`، قم بتوجيه القناة إلى Stasis:

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

اسم التطبيق `hello` يطابق الـ `app=hello` الذي نستخدمه عند الاتصال.

### عميل Python

يستخدم هذا العميل مكتبتين معروفتين: `requests` لطلبات REST و `websocket-client` لدفق الأحداث. قم بتثبيتهما باستخدام `pip install requests websocket-client`.

```python
#!/usr/bin/env python3
"""Minimal ARI Stasis app: answer, play hello-world, hang up."""
import json
import requests
from websocket import create_connection

ARI_HOST = "127.0.0.1"
ARI_PORT = 8088
ARI_USER = "asterisk"
ARI_PASS = "secret"
APP = "hello"

BASE = f"http://{ARI_HOST}:{ARI_PORT}/ari"
AUTH = (ARI_USER, ARI_PASS)

def answer(channel_id):
    requests.post(f"{BASE}/channels/{channel_id}/answer", auth=AUTH)

def play(channel_id, media):
    # Returns the Playback object; we could track its id to await PlaybackFinished.
    r = requests.post(
        f"{BASE}/channels/{channel_id}/play",
        params={"media": media},
        auth=AUTH,
    )
    return r.json()

def hangup(channel_id):
    requests.delete(f"{BASE}/channels/{channel_id}", auth=AUTH)

def main():
    ws_url = (
        f"ws://{ARI_HOST}:{ARI_PORT}/ari/events"
        f"?app={APP}&api_key={ARI_USER}:{ARI_PASS}"
    )
    ws = create_connection(ws_url)
    print(f"Connected to ARI, waiting for calls into Stasis app '{APP}'...")

    # Track which channel each playback belongs to, so we hang up when it ends.
    playback_owner = {}

    while True:
        event = json.loads(ws.recv())
        kind = event["type"]

        if kind == "StasisStart":
            channel_id = event["channel"]["id"]
            print(f"StasisStart on channel {channel_id}")
            answer(channel_id)
            pb = play(channel_id, "sound:hello-world")
            playback_owner[pb["id"]] = channel_id

        elif kind == "PlaybackFinished":
            pb_id = event["playback"]["id"]
            channel_id = playback_owner.pop(pb_id, None)
            if channel_id:
                print(f"Playback done, hanging up {channel_id}")
                hangup(channel_id)

        elif kind == "StasisEnd":
            print(f"StasisEnd on channel {event['channel']['id']}")

if __name__ == "__main__":
    main()
```

قم بتشغيل البرنامج النصي، ثم اطلب أي رقم من أي endpoint مسجل. يجب أن تسمع "Hello, world"، وبعد ذلك يتم إنهاء المكالمة. على وحدة تحكم Asterisk، سيقوم `ari show apps` الآن بسرد `hello` بينما يكون العميل متصلاً.

يجدر بنا تتبع سير العمل مرة واحدة:

1. يقوم الـ dialplan بتشغيل `Stasis(hello)`؛ حيث يسلم Asterisk القناة إلى تطبيقنا ويرسل حدث `StasisStart`.
2. نقوم بالرد على القناة، ثم نطلب من Asterisk تشغيل `sound:hello-world`. يعيد Asterisk كائن `Playback` نحتفظ بـ `id` الخاص به.
3. عند انتهاء الصوت، يرسل Asterisk حدث `PlaybackFinished` مع ذلك الـ playback `id`؛ فنقوم بالبحث عن القناة وإنهاؤها.
4. يؤدي إنهاء المكالمة إلى خروج القناة من Stasis، مما ينتج عنه حدث `StasisEnd`.

> **ملاحظة حول مكتبات العميل.** يوجد غلاف عالي المستوى يسمى `ari-py` (حزمة `ari`)، لكنه غير مدعوم وتمت كتابته لحقبة قديمة من Python وأدوات Swagger. بالنسبة للأعمال الجديدة على Asterisk 22، يفضل استخدام نهج `requests` + WebSocket الصريح الموضح أعلاه، أو مكتبة asyncio مثل `asyncari` إذا كنت بحاجة إلى التزامن. يبقيك النهج المباشر قريباً من طلبات REST والأحداث الفعلية، وهو بالضبط ما تريده أثناء تعلم ARI.

## externalMedia: البوابة نحو الذكاء الاصطناعي والروبوتات الصوتية

تتيح لك الموارد المذكورة أعلاه تشغيل وتسجيل *الملفات*. ولكن تطبيقات الصوت الحديثة — مثل تحويل الكلام إلى نص، وروبوتات الذكاء الاصطناعي الصوتية، والتحليلات في الوقت الفعلي — تتطلب إرسال *بث صوتي مباشر* للمكالمة إلى عملية خارجية، كما تحتاج إلى إعادة حقن الصوت مرة أخرى.

يوفر ARI ذلك من خلال **`externalMedia` channel**. يقوم طلب `POST /ari/channels/externalMedia` بإنشاء قناة خاصة، بدلاً من التحدث إلى هاتف، تقوم ببث وسائط RTP الخاصة بالمكالمة إلى (ومن) مضيف خارجي. أنت تقوم بربط هذه القناة بقناة المتصل، وبذلك يصبح برنامجك الخارجي في مسار الصوت: فهو يستقبل صوت المتصل كـ RTP ويمكنه إرسال صوت مُصنّع (synthesized) مرة أخرى.

يتطلب الطلب فقط:

- `app` — تطبيق Stasis الذي يمتلك القناة الجديدة.
- `format` — تنسيق الصوت، على سبيل المثال `ulaw` أو `slin16`.

`external_host` (وهو `host:port` الخاص بتطبيق الوسائط الخاص بك) اختياري في المخطط — قد يكون فارغاً لاتصال من نوع خادم WebSocket — ولكن بالنسبة لروبوت صوتي يعتمد على RTP التقليدي، ستقوم بتوفيره. المعامل `encapsulation` يكون افتراضياً `rtp` و `transport` يكون افتراضياً `udp`، وهو بالضبط ما تحتاجه لنقطة نهاية وسائط متدفقة.

```
POST /ari/channels/externalMedia
    app=hello
    external_host=127.0.0.1:9000
    format=slin16
```

هذه الميزة الواحدة هي ما يحول Asterisk إلى واجهة أمامية للذكاء الاصطناعي: تنتهي شبكة الهاتف عند Asterisk، ويقوم ARI بتنسيق المكالمة، وتقوم `externalMedia` بنقل الصوت إلى محرك الكلام/الذكاء الاصطناعي وإعادته. هذه هي الآلية التي تُبنى عليها خدمات الذكاء الاصطناعي والروبوتات الصوتية.

## ملخص

تُعد ARI الواجهة الحديثة والموصى بها لبناء تطبيقات الهاتف عبر Asterisk 22. فهي تفصل العمل بشكل نظيف: حيث يعمل Asterisk كمحرك للوسائط، بينما يوفر تطبيقك — الذي يتحدث بلغة JSON عبر HTTP و WebSocket — منطق التحكم في المكالمات. يمكنك تفعيلها من خلال `http.conf` (خادم الويب المدمج على المنفذ 8088) و `ari.conf` (الذي يقوم بتشغيل ARI وتحديد المستخدمين).

يقوم تطبيق dialplan المسمى `Stasis()` بتسليم القناة إلى تطبيقك، مما يؤدي إلى إطلاق `StasisStart` عند دخولها و `StasisEnd` عند خروجها. ومن هناك، يمكنك معالجة مجموعة صغيرة من موارد REST — القنوات (channels)، والجسور (bridges)، والتشغيل (playbacks)، والتسجيلات (recordings)، و endpoint، وحالات الأجهزة (device states) — للرد على المكالمات، وتشغيل الصوت، والتسجيل، والربط، وإنهاء المكالمة.

لقد قمنا ببناء تطبيق Stasis بسيط بلغة Python يقوم بالرد على مكالمة، وتشغيل رسالة صوتية، وإنهاء المكالمة، ورأينا كيف تقوم القناة `externalMedia` ببث RTP مباشر إلى برنامج خارجي — وهو الأساس لعمليات دمج الذكاء الاصطناعي و voicebot.

## اختبار

1. في أي إصدار من Asterisk تم تقديم ARI؟
   - A. Asterisk 1.4
   - B. Asterisk 11
   - C. Asterisk 12
   - D. Asterisk 18
2. في نموذج ARI، يعمل Asterisk كمحرك وسائط بينما يوفر تطبيقك الخارجي منطق التحكم في المكالمات.
   - A. صواب
   - B. خطأ
3. يستخدم ARI وسيلتي نقل معاً. أي زوج هو الصحيح؟
   - A. واجهة برمجة تطبيقات REST/HTTP لإصدار الأوامر وتدفق WebSocket لاستقبال الأحداث
   - B. بروتوكول خط TCP وسكريبت stdin/stdout
   - C. SNMP و SMTP
   - D. مقبسا UDP منفصلان
4. ما هما ملفا الإعداد اللذان يجب تهيئتهما لتمكين ARI؟
   - A. `manager.conf` و `agi.conf`
   - B. `http.conf` و `ari.conf`
   - C. `sip.conf` و `rtp.conf`
   - D. `modules.conf` و `cdr.conf`
5. منفذ TCP التقليدي لخادم HTTP الخاص بـ Asterisk (وبالتالي ARI) هو ____.
6. أي تطبيق في dialplan يقوم بتسليم القناة إلى تطبيق ARI؟
   - A. `AGI()`
   - B. `Dial()`
   - C. `Stasis()`
   - D. `System()`
7. عندما تدخل قناة إلى تطبيق Stasis، أي حدث يتم إرساله إلى العميل المتصل؟
   - A. `ChannelDestroyed`
   - B. `StasisStart`
   - C. `Newchannel`
   - D. `Hangup`
8. أي طلب ARI يقوم بإنشاء نقطة دمج يمكنها ربط قناتين أو أكثر معاً؟
   - A. `POST /ari/channels`
   - B. `POST /ari/bridges`
   - C. `GET /ari/endpoints`
   - D. `DELETE /ari/recordings/stored`
9. لتشغيل رسالة صوتية مدمجة على قناة ما، أي حدث يخبر تطبيقك بأن الصوت قد انتهى حتى يتمكن من المتابعة؟
   - A. `PlaybackStarted`
   - B. `DTMFReceived`
   - C. `PlaybackFinished`
   - D. `ChannelTalkingFinished`
10. تُستخدم القناة `externalMedia` بشكل أساسي لـ:
    - A. تسجيل مكالمة في ملف WAV محلي
    - B. بث الصوت المباشر للمكالمة (RTP) من وإلى تطبيق خارجي، على سبيل المثال محرك ذكاء اصطناعي/نطق
    - C. تسجيل endpoint خاص بـ PJSIP
    - D. إعادة تحميل الـ dialplan

**الإجابات:** 1 — C · 2 — A · 3 — A · 4 — B · 5 — `8088` · 6 — C · 7 — B · 8 — B · 9 — C · 10 — B
