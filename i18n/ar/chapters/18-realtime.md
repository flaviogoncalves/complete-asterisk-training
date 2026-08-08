# Asterisk Real-Time

كما تعلم، يتم إعداد تكوين Asterisk من خلال استخدام العديد من الملفات النصية الموجودة في الدليل /etc/asterisk. وعلى الرغم من سهولة استخدام الملفات النصية، إلا أن هناك بعض العيوب المعروفة:

- الحاجة إلى إعادة تحميل Asterisk في كل مرة يتم فيها تغيير الملفات
- زيادة استهلاك الذاكرة عند وجود عدد كبير من المستخدمين
- صعوبة برمجة واجهة توفير (provisioning) باستخدام الملفات النصية
- عدم إمكانية التكامل مع قواعد البيانات الموجودة

تم إنشاء ARA أو Asterisk Realtime، كما هو معروف، بواسطة Anthony Minessale II و Mark Spencer و Constantine Filin، وصُمم للسماح بالتكامل الشفاف مع قواعد بيانات SQL. كما تتوفر واجهة LDAP أيضاً. يُعرف هذا النظام أيضاً باسم Asterisk External Configuration ويتم تكوينه في /etc/asterisk/extconfig.conf. يمكنك تعيين ملفات التكوين إلى جداول في قاعدة بيانات (تكوين ثابت) وإدخالات في الوقت الفعلي للإنشاء الديناميكي للكائنات دون الحاجة إلى إعادة تحميل Asterisk.

## الأهداف

بحلول نهاية هذا الفصل، يجب أن يكون القارئ قادراً على:

- فهم مزايا وقيود Asterisk Real Time.
- استخدام ODBC للعمل مع ARA.
- تجميع وتثبيت ARA باستخدام ODBC.
- اختبار النظام في بيئة معملية.

## كيف يعمل Asterisk Real Time؟

في بنية Real Time الجديدة، تم نقل جميع الأكواد البرمجية الخاصة بقواعد البيانات إلى برامج تشغيل القنوات (channel drivers). حيث تستدعي القناة فقط روتينًا عامًا يبحث في قاعدة البيانات. والنتيجة هي عملية أبسط وأنظف بكثير من وجهة نظر الكود المصدري. يتم الوصول إلى قاعدة البيانات من خلال ثلاث وظائف:

- STATIC: تُستخدم لإعداد تكوين ثابت عند تحميل وحدة نمطية (module).
- REALTIME: تُستخدم للبحث عن الكائنات أثناء مكالمة أو حدث آخر.


- UPDATE: تُستخدم لتحديث الكائنات.

في Asterisk 22، تتم معالجة نقاط نهاية SIP بواسطة مكدس **PJSIP** (`res_pjsip`)، والذي تم بناؤه على نموذج كائنات **Sorcery**. باستخدام المعالج (wizard) `realtime`، يقوم Sorcery بتحميل كل كائن PJSIP من قاعدة البيانات عند الطلب، وتوجد تلك الكائنات بعد ذلك ككائنات PJSIP مهيأة بشكل عادي — وليس كأقران realtime مؤقتة كان برنامج تشغيل SIP القديم يتخلص منها بعد كل مكالمة.

ولأنها كائنات حقيقية، فإن اجتياز NAT، و qualify، ومؤشر انتظار الرسائل (MWI) تعمل جميعها بشكل طبيعي لنقاط نهاية realtime. (يمكن توجيه Sorcery إضافيًا لتخزين الكائنات مؤقتًا في الذاكرة عبر معالج `memory_cache`، ولكن هذا خيار إضافي ومنفصل عن التحميل عبر realtime.) عندما تقوم بتغيير كائن في قاعدة البيانات، يتم التقاط التغيير في عملية البحث التالية؛ ولست بحاجة إلى إعادة التحميل بعد كل تعديل. (نموذج realtime المتقاعد `chan_sip`، مع عائلات `sippeers`/`sipusers` الخاصة به، مغطى فقط في فصل *Legacy Channels*.)

## إعداد Asterisk Real Time

بالنسبة لهذا المختبر، سنفترض أنك قمت بالفعل بتثبيت ODBC من فصل CDR. يتم تكوين ARA في ملف النص extconfig.conf، حيث يمكن رؤية قسمين بسهولة. القسم الأول هو قسم ملفات التكوين الثابتة، حيث يمكنك استبدال ملفات التكوين النصية بجداول قاعدة البيانات. القسم الثاني هو محرك التكوين في الوقت الفعلي (realtime)، حيث تقوم بتكوين جداول قاعدة البيانات للكائنات الديناميكية (peers/users). ليس من غير المعتاد استخدام ملفات نصية للتكوين الثابت وقاعدة البيانات للمدخلات الديناميكية. في هذه الحالة، يظل القسم الأول دون تغيير.

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![بنية Asterisk Real Time: يتم تحميل ملفات التكوين وجداول قاعدة البيانات الثابتة عند بدء تشغيل Asterisk، بينما توفر جداول قاعدة البيانات في الوقت الفعلي تكويناً ديناميكياً يُقرأ عند الطلب أثناء المكالمة.](../images/18-realtime-fig01.png)

```
;
[settings]
;
; Static configuration files:
;
; file.conf => driver,database[,table]
;
; maps a particular configuration file to the given
; database driver, database and table (or uses the
; name of the file as the table if not specified)
;
;uncomment to load queues.conf via the odbc engine.
;
;queues.conf => odbc,asterisk,ast_config
;
; The following files CANNOT be loaded from Realtime storage:
;       asterisk.conf
;       extconfig.conf (this file)
;       logger.conf
;
; Additionally, the following files cannot be loaded from
; Realtime storage unless the storage driver is loaded
; early using 'preload' statements in modules.conf:
;       manager.conf
;       cdr.conf
;       rtp.conf
;
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
;example => odbc,asterisk,alttable
;ps_endpoints => odbc,asterisk
;ps_aors => odbc,asterisk
;ps_auths => odbc,asterisk
;ps_contacts => odbc,asterisk
;voicemail => odbc,asterisk
;extensions => odbc,asterisk
;queues => odbc,asterisk
;queue_members => odbc,asterisk
```


### قسم التكوين الثابت

قسم التكوين الثابت هو المكان الذي تخزن فيه ما يعادل ملفات التكوين في قاعدة البيانات. تُقرأ هذه التكوينات أثناء تحميل Asterisk. تقوم بعض الوحدات بإعادة قراءة قاعدة البيانات عند إعادة التحميل. أمثلة على التكوين الثابت هي:

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

يعد تعيين الملفات الثابتة أكثر فائدة لملفات التكوين التي ليس لها ما يعادلها في الوقت الفعلي لكل كائن. بالنسبة لـ PJSIP، يفضل استخدام عائلات الوقت الفعلي لكل كائن (`ps_endpoints`، و`ps_aors`، وما إلى ذلك) الموضحة لاحقاً في هذا الفصل بدلاً من تعيين ملف `pjsip.conf` بالكامل كملف ثابت.

تم وصف ثلاثة أمثلة أعلاه. في المثال الأول، تقوم بربط queues.conf بجدول queues في قاعدة بيانات asteriskdb. في المثال الثاني، تقوم بربط pjsip.conf بجدول pjsip_conf في قاعدة البيانات asteriskdb المحددة في تكوين odbc. في المثال الأخير، تقوم بربط iax.conf بدليل LDAP. MyBaseDN هو الـ DN الأساسي الذي سيتم البحث فيه. في المثال السابق، يتم تحميل التطبيق app_queue.so بينما يقوم برنامج تشغيل MySQL بالاستعلام عن قاعدة البيانات والحصول على المعلومات المطلوبة.

### قسم التكوين في الوقت الفعلي

التكوين في الوقت الفعلي (الجزء الثاني من ملف extconfig.conf) هو المكان الذي يتم فيه تكوين وتحديث وإلغاء تحميل جزء التكوين المراد تحميله في الوقت الفعلي. مع الوقت الفعلي، ليس من الضروري إعادة تحميل التكوينات. يتبع بناء جملة الوقت الفعلي ما يلي:

```
<family name> => <driver>,<database name>[,table_name]
```

مثال:

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

هنا لدينا خمسة أسطر تكوين. في السطر الأول، تقوم بربط عائلة PJSIP/Sorcery `ps_endpoints` بجدول `ps_endpoints` في قاعدة بيانات asteriskdb. في السطر الأخير، تقوم بربط عائلة voicemail بجدول test في قاعدة بيانات asteriskdb. يحصل كل نوع كائن PJSIP (endpoint، aor، auth، contact) على عائلته وجدوله الخاص؛ تظهر المجموعة الكاملة في قسم "PJSIP Realtime (Sorcery)" أدناه. لا تزال العائلات `voicemail` و`extensions` و`queues` و`queue_members` صالحة في Asterisk 22.

## PJSIP Realtime (Sorcery)

في Asterisk 22، تتم معالجة نقاط نهاية SIP حصرياً بواسطة حزمة **PJSIP** (`res_pjsip`)، والتي تم بناؤها على طبقة تجريد الكائنات **Sorcery**. بدلاً من "نظير" SIP واحد، يقوم PJSIP بتقسيم حساب SIP إلى عدة أنواع من الكائنات، يتم تخزين كل منها في جدول realtime الخاص به:

| نوع كائن Sorcery | جدول Realtime | ما يحتويه |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | إعدادات كل حساب (context، codecs، DTMF، إلخ) |
| aor (address of record) | ps_aors | حدود التسجيل وإعدادات `qualify` |
| auth | ps_auths | بيانات اعتماد `username` / `password` |
| contact | ps_contacts | الموقع المسجل ديناميكياً |
| domain alias | ps_domain_aliases | نطاقات SIP بديلة لنقطة النهاية |
| endpoint identifier by IP | ps_endpoint_id_ips | مطابقة نقطة النهاية حسب عنوان IP المصدر |

يتم تمكين Realtime لـ PJSIP في مكانين. أولاً، قم بتعيين أنواع كائنات Sorcery إلى realtime في `extconfig.conf`:

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

ثانياً، أخبر Sorcery باستخدام معالج `realtime` لأنواع الكائنات تلك في `sorcery.conf`. اسم التعيين (هنا `res_pjsip`) هو الوحدة التي تقوم بنقل كائناتها، وتشير القيمة الموجودة على اليمين إلى العائلة التي حددتها في `extconfig.conf`:

```
[res_pjsip]
endpoint=realtime,ps_endpoints
aor=realtime,ps_aors
auth=realtime,ps_auths
domain_alias=realtime,ps_domain_aliases
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
```

يمكنك الجمع بين الكائنات الثابتة و realtime. إذا قمت بحذف نوع من `sorcery.conf`، فسيستمر نوع الكائن هذا في القراءة من `pjsip.conf`. النمط الشائع هو الاحتفاظ بالنواقل الثابتة والإعدادات العامة في `pjsip.conf` مع تخزين endpoints و aors و auths و contacts في قاعدة البيانات.

### إنشاء مخطط PJSIP realtime باستخدام Alembic

يوفر Asterisk عمليات ترحيل قاعدة البيانات لجميع مخططات realtime الخاصة به تحت `contrib/ast-db-manage`. هذه هي الطريقة المدعومة لإنشاء (وترقية إصدار) جداول PJSIP — لم تعد تكتب تعريفات جداول `ps_*` يدوياً. تحتوي مجموعة ترحيل `config` على جداول PJSIP/Sorcery.

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

يؤدي هذا إلى إنشاء `ps_endpoints` و `ps_aors` و `ps_auths` و `ps_contacts` وجداول PJSIP الأخرى بالأعمدة الصحيحة لإصدار Asterisk قيد التشغيل. (يتطلب Alembic حزمة `alembic` الخاصة بـ Python بالإضافة إلى برنامج تشغيل SQLAlchemy مثل `pymysql` لـ MySQL/MariaDB أو `psycopg2` لـ PostgreSQL.)

تتكون نقطة نهاية realtime البسيطة بعد ذلك من صف واحد في كل جدول من الجداول الثلاثة — على سبيل المثال نقطة النهاية `6010`:

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

بعد إدراج الصفوف، لا يوجد شيء لإعادة التحميل — حيث يقوم طلب REGISTER/INVITE التالي بسحب الكائنات من قاعدة البيانات. يمكنك تأكيد ما أعاده realtime باستخدام:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## إعداد قاعدة البيانات

الآن بعد أن قمنا بتهيئة ملف extconfig.conf، دعنا ننشئ الجداول. بشكل عام، يطابق كل عمود في قاعدة البيانات اسم خيار من ملف الإعدادات المقابل. تتبع جداول PJSIP `ps_*` هذه القاعدة: كل عمود `ps_endpoints` مسمى على اسم خيار endpoint في `pjsip.conf`، وكل عمود `ps_auths` مسمى على اسم خيار auth، وهكذا. على سبيل المثال، الـ endpoint المسمى `pjsip.conf` أدناه،

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

يتم تخزينه كصف واحد عبر ثلاثة جداول. يحمل الصف `ps_endpoints` بيانات `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000`؛ ويحمل الصف `ps_auths` بيانات `id=4000, auth_type=userpass, username=4000, password=supersecret`؛ ويحمل الصف `ps_aors` بيانات `id=4000, max_contacts=1`. تحتاج فقط إلى ملء الأعمدة التي تستخدمها فعلياً — أي عمود تتركه NULL سيعود إلى القيمة الافتراضية للخيار. إذا كنت ترغب، على سبيل المثال، في ضبط المعامل `callerid` على endpoint، فقم بملء العمود `callerid` في `ps_endpoints` (اسم العمود هو نفسه اسم خيار `pjsip.conf`).

يتبع جدول voicemail نفس الفكرة. حيث تتطابق أعمدته مع حقول `voicemail.conf`:

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

يجب أن يكون `uniqueid` فريداً لكل مستخدم voicemail ويمكن أن يكون ذاتي الزيادة (autoincrement). لا يحتاج إلى وجود أي علاقة بـ mailbox أو context.

### بناء dialplan باستخدام Asterisk Real Time

يمكنك أيضاً استخدام نظام الوقت الفعلي (real-time) لإنشاء الـ dialplan. يستخدم ARA العبارة `switch` لتضمين الـ extensions ذات الوقت الفعلي في الـ dialplan العادي الموجود في ملف extensions.conf. يجب أن يبدو جدول extension مثل الجدول أدناه:

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

عائلة الوقت الفعلي `extensions` لم تتغير في Asterisk 22؛ فقط تأكد من أن العمود `appdata` يقوم بطلب قنوات PJSIP، على سبيل المثال `PJSIP/4000`. في الـ dialplan، يجب عليك استخدام الأمر `switch` لاستخدام الوقت الفعلي.

![بناء dialplan باستخدام Asterisk Real Time: يستخدم extensions.conf عبارة `switch => realtime` لجلب صفوف الـ extension (context, exten, priority, app, data) من جدول قاعدة البيانات بدلاً من ملف نصي.](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

أو

```
[local]
switch => realtime/from-internal@extensions
```

## مختبر: تثبيت وإنشاء جداول قاعدة البيانات

في هذا المختبر، سنقوم بإعداد قاعدة البيانات لاستقبال معاملات Asterisk. سنقوم بإعداد جداول REALTIME فقط. سيتم ترك الإعدادات الثابتة لملفات الإعدادات النصية (أمر رائع، أليس كذلك؟). فيما يلي عملية إنشاء الجداول في MySQL.

الخطوة 1: ادخل إلى قاعدة بيانات MySQL بصلاحيات root.

```
mysql -u root -p
```

الخطوة 2: سجل الدخول إلى خادم MySQL الذي تم إنشاؤه في مختبرات CDR.

```
mysql -u astdb -p
```

عندما يُطلب منك كلمة المرور، اكتب supersecret.

الخطوة 3: أنشئ الجداول اللازمة. لا تزال ملفات المخطط الثابت القديمة تُشحن تحت `contrib/realtime/` (على سبيل المثال `/usr/src/asterisk-22.x/contrib/realtime/mysql`)، ولكن في Asterisk 22، الطريقة الموصى بها والصحيحة من حيث الإصدار لبناء جداول realtime — وخاصة جداول PJSIP `ps_*` — هي عمليات ترحيل **Alembic** تحت `contrib/ast-db-manage` (راجع قسم "إنشاء مخطط PJSIP realtime باستخدام Alembic" أعلاه).

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

تقوم مجموعة ترحيل Alembic `config` ببناء جداول PJSIP `ps_*` (جنبًا إلى جنب مع `voicemail` و `extensions` ومخططات realtime الأخرى) بالأعمدة التي يتوقعها إصدار Asterisk قيد التشغيل تمامًا، بحيث يتطابق المخطط دائمًا مع الإصدار.

استخدم supersecret ككلمة مرور.

الخطوة 4: تحقق من إنشاء الجداول.

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

يجب أن ترى جداول PJSIP `ps_*` (التي تم إنشاؤها بواسطة ترحيل Alembic `config`)، جنبًا إلى جنب مع `voicemail` و `extensions` وجداول realtime الأخرى:

```
mysql> show tables;
+----------------------------+
| Tables_in_astdb            |
+----------------------------+
| ps_aors                    |
| ps_auths                   |
| ps_contacts                |
| ps_domain_aliases          |
| ps_endpoint_id_ips         |
| ps_endpoints               |
| ps_registrations           |
| extensions                 |
| voicemail                  |
+----------------------------+
```

(يقوم Alembic بإنشاء جداول أكثر من هذه — القائمة أعلاه تعرض الجداول ذات الصلة بهذا المختبر.)

الخطوة 5: قاعدة البيانات مهيأة بالفعل لـ ODBC (منذ مختبر CDR)، لذا لا يلزم إجراء إعداد إضافي لـ ODBC هنا.

الخطوة 6: افحص الجداول وقم بتعبئتها من عميل MySQL. لا تحتاج إلى أداة رسومية مثل phpMyAdmin — فكل خطوة في هذا الفصل عبارة عن SQL بسيط قابل للنسخ واللصق يتم تشغيله من سطر أوامر `mysql`. اتصل بقاعدة بيانات `astdb` (استخدم `supersecret` عند المطالبة):

```
mysql -u astdb -p astdb
```

يمكنك التأكد من أعمدة أي جدول في أي وقت باستخدام `DESCRIBE`، على سبيل المثال:

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

تم إنشاء هذه الجداول بواسطة ترحيل Alembic `config`، لذا فإن أعمدتها تتطابق بالفعل مع أسماء خيارات `pjsip.conf` لإصدار Asterisk قيد التشغيل — ما عليك سوى ملء الأعمدة التي تحتاجها فقط.

## مختبر: تهيئة واختبار ARA

في هذا المختبر، سنقوم بتغيير تهيئة `extconfig.conf` لتعكس تهيئة قاعدة البيانات والجداول الخاصة بنا.

الخطوة 1: تهيئة `extconfig.conf` وإعادة تحميل Asterisk.

```
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
ps_endpoints => odbc,cdr
ps_aors => odbc,cdr
ps_auths => odbc,cdr
ps_contacts => odbc,cdr
voicemail => odbc,cdr,voicemail
extensions => odbc,cdr,extensions
```

لاحظ عائلات `ps_endpoints` و `ps_aors` و `ps_auths` و `ps_contacts` أعلاه؛ فبالاشتراك مع تعيينات `sorcery.conf` المطابقة (انظر قسم "PJSIP Realtime (Sorcery)")، فإنها تجعل PJSIP يقرأ حساباته من قاعدة البيانات. وتكمل عائلتا `voicemail` و `extensions` هذا المثال.

الخطوة 2: اختبار extension في الوقت الفعلي (Real Time). قم بإنشاء endpoint جديد من نوع `6010` عن طريق إدراج صف واحد في كل من `ps_auths` و `ps_aors` و `ps_endpoints`، ثم حاول تسجيل هذا الـ endpoint باستخدام softphone. قم بتشغيل SQL التالي في عميل `mysql` (`mysql -u astdb -p astdb`):

```sql
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('6010-auth', 'userpass', '6010', 'supersecret');

INSERT INTO ps_aors (id, max_contacts)
VALUES ('6010', 1);

INSERT INTO ps_endpoints
  (id, transport, aors, auth, context, disallow, allow, dtmf_mode, direct_media)
VALUES
  ('6010', 'transport-udp', '6010', '6010-auth', 'from-internal',
   'all', 'ulaw', 'rfc4733', 'no');
```

تصف الصفوف الثلاثة معاً حساب SIP واحداً. تتوزع إعدادات الحساب المتبقية عبر كائنات PJSIP: حيث توجد الـ context، و codecs، ووضع DTMF، ومعالجة الوسائط في الـ endpoint (الأعمدة الستة الأخيرة أعلاه)؛ بينما يوجد التسجيل الديناميكي في الـ AOR. لا توجد علامة "ديناميكية" منفصلة — حيث يقبل الـ AOR طلبات REGISTER الديناميكية طالما أن `max_contacts` أكبر من صفر، ويتم كتابة كل موقع مسجل في `ps_contacts`.

في PJSIP، يُسمى وضع DTMF خارج النطاق (out-of-band) وفقاً لـ RFC 2833 / RFC 4733 باسم `rfc4733`، و `dtmf_mode=rfc4733` هو الإعداد الافتراضي — لذا فإن عمود `dtmf_mode` أعلاه اختياري ويظهر فقط للتوضيح.

الخطوة 3: حاول تسجيل الهاتف الجديد باستخدام softphone عبر اسم المستخدم `6010` وكلمة المرور `supersecret`. أكد التسجيل على واجهة سطر أوامر Asterisk:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

الخطوة 4: تضمين الـ extensions في قاعدة البيانات.

```
mysql -u astdb -p
```

أدخل كلمة المرور:

استخدم supersecret عند الطلب، ثم أدخل صف الـ extension من عميل MySQL:

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

الخطوة 5: تضمين Asterisk Real Time في الـ dialplan. في الـ context المسمى `default`:

```
switch => realtime/test@extensions
```

أعد تحميل الـ extensions لتفعيل التغيير.

```
asterisk-server*CLI> extensions reload
```

الخطوة 6: أعد تهيئة أحد الهواتف لاسم المستخدم `bria`، إذا لم تكن قد قمت بذلك بالفعل.

الخطوة 7: اتصل بالرقم 6007 من هاتف موجود؛ يجب أن يرن هاتف `bria`.

## ملخص

في هذا الفصل، تعلمت أن Asterisk Real Time يتيح لك وضع إعداداتك في قاعدة بيانات. يوفر Asterisk برامج تشغيل (drivers) أصلية للعمل بنظام الوقت الفعلي (realtime) لكل من ODBC (الذي يصل إلى أي قاعدة بيانات مدعومة من UnixODBC، بما في ذلك MySQL/MariaDB و SQLite) و PostgreSQL، بالإضافة إلى برنامج تشغيل LDAP للعمل بنظام الوقت الفعلي للخوادم الدليلية (directory backends). يتم الوصول إلى MySQL/MariaDB من خلال ODBC، كما فعلنا في هذا الفصل (توجد أيضاً إضافة `res_config_mysql` مخصصة، لكنها تقع خارج نطاق البناء الأساسي، لذا فإن ODBC هو المسار الشائع). تنقسم الإعدادات إلى إعدادات ثابتة (static) وإعدادات الوقت الفعلي (real time). تحل الإعدادات الثابتة محل ملفات الإعدادات، بينما تنشئ إعدادات الوقت الفعلي كائنات ديناميكية يتم تحميلها فقط عند حدوث مكالمة أو أي حدث آخر ذي صلة. اختتمنا الفصل بمختبر عملي حول كيفية تثبيت وإعداد ARA.

## اختبار

1. يعتبر Asterisk Realtime جزءاً من توزيعة Asterisk القياسية.
   - A. صح
   - B. خطأ
2. يتم تكوين معلمات الاتصال الخاصة بخادم قاعدة البيانات في الملف:
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. يقوم الملف `extconfig.conf` بتهيئة الجداول المستخدمة بواسطة Realtime. وهو يحتوي على قسمين متميزين (اختر اثنين):
   - A. التكوين الثابت (Static configuration)
   - B. تكوين Realtime
   - C. مسارات الاتصال الصادرة (Outbound routes)
   - D. عناوين IP ومنافذ قاعدة البيانات
4. في التكوين الثابت، بمجرد تحميل الكائنات من قاعدة البيانات، يتم الاحتفاظ بها في ذاكرة Asterisk ولا يتم تحديثها إلا عند البدء أو إعادة التحميل.
   - A. صح
   - B. خطأ
5. يدعم PJSIP realtime (Sorcery) بشكل كامل `qualify` و MWI لنقاط النهاية (endpoints) في وضع Realtime، لأن Sorcery يقوم بتحميلها ككائنات PJSIP مهيأة عادية بدلاً من التخلص منها بعد كل مكالمة كما كان يحدث مع أقران SIP realtime القدامى.
   - A. صح
   - B. خطأ
6. في PJSIP realtime، ما هي الجداول التي تحتوي على نقاط النهاية (endpoints) وجهات الاتصال المسجلة الخاصة بها؟
   - A. `ps_endpoints` و `ps_contacts`
   - B. `ps_peers` و `ps_registry`
   - C. `ps_config` و `ps_data`
   - D. `extconfig` و `res_odbc`
7. لا يزال بإمكانك استخدام ملفات التكوين النصية حتى بعد تمكين ARA.
   - A. صح
   - B. خطأ
8. يعتبر phpMyAdmin إلزامياً عند استخدام Realtime.
   - A. صح
   - B. خطأ
9. يجب إنشاء قاعدة البيانات مع كل حقل موجود في ملف التكوين.
   - A. صح
   - B. خطأ
10. في Asterisk 22، ما هي الطريقة الموصى بها والصحيحة من حيث الإصدار لإنشاء جداول PJSIP realtime (`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`)؟
    - A. كتابة عبارات `CREATE TABLE` يدوياً لكل جدول `ps_*`
    - B. استيراد `mysql_config.sql` القديم من `contrib/realtime/`
    - C. تشغيل عمليات ترحيل Alembic `config` تحت `contrib/ast-db-manage` (`alembic -c config.ini upgrade head`)
    - D. يتم إنشاء الجداول تلقائياً في المرة الأولى التي يبدأ فيها Asterisk

**الإجابات:** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
