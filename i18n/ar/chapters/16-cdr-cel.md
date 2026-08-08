# سجلات تفاصيل المكالمات في Asterisk

يسمح Asterisk، مثل غيره من منصات الاتصالات الهاتفية، بإصدار فواتير المكالمات الهاتفية. تتوفر في السوق العديد من البرامج التي يمكنها استيراد السجلات التي يتم إنشاؤها بواسطة PBXs. تُستخدم هذه السجلات للتحقق من صحة مبالغ الفواتير والإحصائيات، من بين أمور أخرى.

## الأهداف

بحلول نهاية هذا الفصل، ينبغي أن يكون القارئ قادراً على:

- وصف مكان وتنسيق السجلات التي يتم إنشاؤها
- إنشاء السجلات باستخدام ODBC (Open Database Connectivity)
- تنفيذ نظام مصادقة متكامل مع نظام الفوترة

## تنسيق سجل تفاصيل المكالمات (CDR) في Asterisk

يقوم Asterisk بإنشاء سجل تفاصيل المكالمات (CDR) لكل مكالمة. يتم تخزين هذه السجلات، افتراضياً، في ملف نصي بتنسيق القيم المفصولة بفواصل (CSV) في المسار /var/log/asterisk/cdr-csv. يتم تنظيم الملف في الحقول التالية:

| الحقل | الوصف | النوع |
|-------|-------------|------|
| Accountcode | رقم الحساب المستخدم | String |
| Src | رقم معرف المتصل | String |
| Dst | الـ extension الوجهة | String |
| Dcontext | الـ context الوجهة | String |
| Clid | معرف المتصل مع النص | String |
| Channel | القناة المستخدمة | String |
| Dstchannel | القناة الوجهة | String |
| Lastapp | آخر تطبيق تم استخدامه | String |
| Lastdata | بيانات آخر تطبيق | String |
| Start | وقت بدء المكالمة | Date/Time |
| Answer | وقت الرد على المكالمة | Date/Time |
| End | وقت إنهاء المكالمة | Date/Time |
| Duration | الوقت المستغرق من الطلب حتى إنهاء المكالمة | Integer (seconds) |
| Billsec | الوقت المستغرق من الرد حتى إنهاء المكالمة | Integer (seconds) |
| Disposition | ما حدث للمكالمة (ANSWERED, NO ANSWER, BUSY, FAILED, CONGESTION) | String |
| Amaflags | الأعلام (DEFAULT, OMIT, BILLING, DOCUMENTATION) | String |
| Userfield | حقل معرف من قبل المستخدم | String |

نموذج لملف CSV. يمثل كل سطر سجلاً واحداً؛ وتظهر الحقول بنفس ترتيب الجدول أعلاه (`accountcode` أولاً، و`amaflags` أخيراً):

```text
# accountcode,src,dst,dcontext,clid,channel,dstchannel,lastapp,lastdata,
#   start,answer,end,duration,billsec,disposition,amaflags
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-5f30","PJSIP/8584-9153","Dial","PJSIP/8584,30,tT","2006-03-27 16:05:00","2006-03-27 16:05:00","2006-03-27 16:05:00","0","0","ANSWERED","DOCUMENTATION"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-96f5","PJSIP/8584-3312","Dial","PJSIP/8584,30,tT","2006-03-27 16:16:00","2006-03-27 16:16:00","2006-03-27 16:16:00","0","0","ANSWERED","BILLING"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-74ac","PJSIP/8584-297b","Dial","PJSIP/8584,30,tT","2006-03-27 16:22:00","2006-03-27 16:22:00","2006-03-27 16:22:00","0","0","ANSWERED","BILLING"
"1234","4830258576","2012348584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-2c5d","PJSIP/8584-9870","Dial","PJSIP/8584,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
"1234","4830258584","2012348576","default","""Luis Sample"" <4830258584>","PJSIP/8584-03fd","PJSIP/8576-645c","Dial","PJSIP/8576,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
```

## رموز الحساب ومحاسبة الرسائل المؤتمتة

يمكنك تحديد رموز الحساب و ama flags لكل قناة. عادةً ما يتم ذلك في ملف إعدادات القناة (على سبيل المثال، chan_dahdi.conf أو pjsip.conf). يحدد المعامل amaflags الإجراء الذي يجب اتخاذه مع سجل CDR. قيم amaflag الممكنة هي:

- Default
- Omit
- Billing
- Documentation

على غرار الطريقة التي يمكن بها وضع علامة على سجل لأغراض الفوترة أو التوثيق، يمكن تعيين رمز حساب لكل سجل. رمز الحساب هو سلسلة نصية حرة (خيار endpoint `accountcode` يقبل أي String، ويقوم سجل CDR بتخزينه في حقل مكون من 80 حرفاً) يُستخدم عادةً لتعيين سجل إلى قسم أو وحدة عمل. مثال: قسم endpoint في pjsip.conf

```
[8576]
type=endpoint
accountcode=Support
```

لا يعد AMA flag خياراً لـ endpoint `pjsip.conf` في Asterisk 22؛ قم بتعيينه لكل مكالمة من الـ dialplan باستخدام الدالة `CHANNEL` (على سبيل المثال `Set(CHANNEL(amaflags)=billing)`)، أو باستخدام `Set(CDR(amaflags)=billing)`.

## تغيير تنسيق CSV و/أو CDR

يمكنك تغيير تنسيق CSV عن طريق تعديل ملف cdr_custom.conf.

```
;
; Mappings for custom config file
;
[mappings]
Master.csv =>
"${CDR(clid)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}"
,"${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${C
DR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposit
ion)}","${CDR(amaflags)}","${CDR(accountcode)}","${CDR(uniqueid)}","${CDR(userf
ield)}"
```

يمكنك تغيير تنسيق CDR في ملف cdr_custom.conf.

## تخزين CDR

يمكن تحقيق تخزين CDR بعدة طرق. الطريقة الأكثر أهمية هي ملفات النصوص CSV التي يمكن استيرادها بسهولة إلى برامج الجداول الحسابية. بالنسبة للشركات الصغيرة، عادة ما يكون هذا كافياً. تقبل بعض برامج الفوترة ملفات CSV بشكل افتراضي. ومع ذلك، فإن تخزين CDRs في قاعدة بيانات يعد أفضل وأكثر أماناً بكثير. يدعم Asterisk العديد من أنواع قواعد البيانات. توجد بعض الواجهات الرسومية للفوترة في السوق. مع وجود العديد من برامج التشغيل، أياً منها يجب اختياره؟

### برامج التشغيل المتاحة للتخزين

- cdr_csv – ملفات نصوص ذات قيم مفصولة بفواصل
- cdr_custom – ملفات نصوص ذات قيم مفصولة بفواصل قابلة للتخصيص
- cdr_adaptive_odbc – واجهة خلفية من نوع Adaptive ODBC (مفضلة لتخزين قواعد البيانات)
- cdr_odbc – قواعد البيانات المدعومة عبر unixODBC (قديمة؛ يفضل استخدام cdr_adaptive_odbc)
- cdr_pgsql – قواعد بيانات Postgres
- cdr_tds (cdr_freetds) – قواعد بيانات Sybase و MSSQL عبر FreeTDS
- cdr_manager – واجهة CDR إلى Manager Interface
- cdr_radius – واجهة CDR عبر RADIUS
- cdr_sqlite3_custom – وحدة CDR مخصصة لـ SQLite3

تمت إزالة وحدة `cdr_addon_mysql` (cdr_mysql) التي كانت توصي بها الأدلة القديمة في Asterisk 19، لذا لا يوجد برنامج تشغيل CDR أصلي لـ MySQL في Asterisk 22. لكتابة CDRs إلى MySQL/MariaDB، استخدم `cdr_adaptive_odbc` مع برنامج تشغيل MySQL ODBC — وهو النهج المستخدم في هذا الفصل.

يتم تسجيل CDR لجميع الوحدات النشطة التي يتم تحميلها في الملف /etc/asterisk/modules.conf. إذا تم ضبط المعامل autoload=yes، فسيتم تحميل جميع الوحدات. للتحقق من برامج تشغيل cdr_drivers المحملة حالياً في النظام، استخدم الأمر أدناه:

```
asterisk*CLI> module show like cdr_
Module                 Description                              Use Count  Status
Support Level
cdr_adaptive_odbc.so   Adaptive ODBC CDR backend                0          Running
core
cdr_csv.so             Comma Separated Values CDR Backend       0          Running
extended
cdr_custom.so          Customizable Comma Separated Values CDR  0          Running
core
cdr_manager.so         Asterisk Manager Interface CDR Backend   0          Running
core
cdr_odbc.so            ODBC CDR Backend                         0          Running
extended
cdr_sqlite3_custom.so  SQLite3 Custom CDR Module                0          Not Running
extended
6 modules loaded
```

إذا رأيت لقطة الشاشة أعلاه، فهذا يعني أن cdr_adaptive_odbc و cdr_csv و cdr_custom و cdr_manager و cdr_odbc و cdr_sqlite3_custom تعمل على الأقل. في السنوات الأخيرة وبعد بعض مؤتمرات Astricon، أصبح من الواضح لي أن فريق Asterisk يفضل ODBC. إنه برنامج التشغيل الوحيد الذي يدعم تجميع الاتصالات (connection pooling). يعد تجميع الاتصالات ميزة رائعة من حيث الأداء لأنك لا تضطر إلى فتح اتصال جديد لكل عملية. تمت كتابة هذا الفصل سابقاً باستخدام cdr_mysql. لقد انتقلت إلى cdr_adaptive_odbc في هذه الطبعة رغم علمي بأنه أكثر تعقيداً قليلاً في الإعداد. كما يسمح لنا اختيار cdr_adaptive_odbc بتخصيص CDR. يمكنك ببساطة تعيين متغير CDR جديد في الـ dialplan وإضافة العمود المطابق إلى قاعدة البيانات. على سبيل المثال، لتسجيل تذبذب الصوت (audio jitter):

```
Set(CDR(jitter)=${RTPAUDIOQOSJITTER})
```

### التخزين بصيغة CSV

كما قلنا سابقاً، يقوم Asterisk افتراضياً بإرسال جميع CDR إلى ملف نصي بصيغة CSV باستخدام الوحدة cdr_csv.so. إذا لم تتمكن من رؤية الملفات في /var/log/asterisk/cdr-csv، فتحقق مما إذا كانت الوحدة يتم تحميلها باستخدام أمر CLI module show. إذا لم تكن محملة، فتحقق من modules.conf. في هذا الفصل، سنقوم بإرسال cdrs إلى cdr_csv كنسخة احتياطية.

### تهيئة ملف modules.conf

لتحميل الوحدات المناسبة فقط، استخدم الأسطر أدناه في ملف modules.conf

```
noload => cdr_custom.so
noload => cdr_odbc.so
noload => cdr_manager.so
noload => cdr_sqlite3_custom.so
```

الآن أصبح لدينا cdr_csv و cdr_adaptive_odbc فقط محملين.

## تثبيت وتهيئة ODBC على نظام Ubuntu 22.04

أشعر دائماً بالأسف عند نشر تعليمات مفصلة في الكتاب. فهي تتغير أحياناً قبل نشر الكتاب بوقت قصير. تتغير الإصدارات وتتغير الوحدات النمطية، لذا حاول تكييف الأوامر الواردة هنا لتناسب وضعك الخاص. في معظم الأحيان، تكفي تغييرات طفيفة لإعادة تنفيذ عملية التثبيت. انتبه للخطوات، حتى المستخدمون ذوو الخبرة في Linux سيجدون صعوبة في تثبيت تعريفات ODBC.

الخطوة 1 - تثبيت الحزم المطلوبة:

```
apt-get install mysql-server unixodbc unixodbc-dev libltdl-dev libtool
```

الخطوة 2 - إنشاء قاعدة بيانات ومستخدم:

```
mysql -u root -p
```

(استخدم كلمة المرور التي حددتها عند إنشاء خادم mysql) اكتب هذه الأوامر في سطر أوامر mysql

```
CREATE USER 'astdb'@'%' IDENTIFIED BY 'supersecret';
CREATE DATABASE cdr;
GRANT ALL PRIVILEGES ON cdr.* TO 'astdb'@'%';
FLUSH PRIVILEGES;
EXIT
```

الخطوة 3 - إنشاء قاعدة البيانات

```
cd /usr/src/asterisk-22.*/contrib/scripts/realtime/mysql
mysql -u root -p astdb <mysql_cdr.sql
```

الخطوة 4: قم بتنزيل موصل MySQL ODBC من Oracle. تحقق من نظام التشغيل الخاص بك باستخدام: `lsb_release -a`. بالنسبة لنظام Ubuntu 22.04 (x86_64)، قم بزيارة https://dev.mysql.com/downloads/connector/odbc/ واختر إصدار 8.x أو 9.x الحالي لنظام Ubuntu 22.04. يتغير اسم الملف الدقيق ورقم الإصدار بمرور الوقت، لذا اضبط `VER` (أدناه) على أي اسم يطلق على إصدار Linux glibc الحالي.

```
cd /usr/src
# Pick the current Linux (glibc) build for your platform from
# https://dev.mysql.com/downloads/connector/odbc/ and set VER to its name:
VER=mysql-connector-odbc-9.0.0-linux-glibc2.28-x86-64bit
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/9.0/$VER.tar.gz
tar -xzvf $VER.tar.gz
```

الخطوة 5: تثبيت تعريف ODBC

```
cd /usr/src/$VER
cp bin/* /usr/local/bin
cp lib/* /usr/local/lib
myodbc-installer -a -d -n "MySQL" -t "Driver=/usr/local/lib/libmyodbc9w.so"
```

الخطوة 6 - تهيئة موصل ODBC، قم بتحرير الملف /etc/odbc.ini لإنشاء DSN (اسم مصدر البيانات)

```
[astconn]
Description = MySQL connector for astdb database
Driver = /usr/local/lib/libmyodbc9w.so
Database = astdb
Server = localhost
Port = 3306
```

الخطوة 7: اختبار الوصول إلى التعريف باستخدام iSQL. أداة iSQL هي أداة سطر أوامر للاتصال بقاعدة البيانات عبر unixodbc.

```
isql -v astconn astdb supersecret
>show tables
```

يرجى عدم المتابعة في تهيئة Asterisk إذا لم تتمكن من رؤية نتيجة أمر isql.

### تهيئة ODBC في Asterisk

قبل أن تتمكن من تهيئة cdr_adaptive_odbc، يجب عليك أولاً تهيئة ملف موارد ODBC.

الخطوة 1 - توصيل Asterisk بـ ODBC. قم بتحرير الملف res_odbc.conf:

```
[cdr]
enabled => yes
dsn => astconn
username => astdb
password => supersecret
pre-connect => yes
```

الخطوة 2 - إعادة تشغيل Asterisk والاختبار باستخدام

```
asterisk*CLI> odbc show
```

يظهر المخرج أدناه.

```
asterisk*CLI> odbc show
ODBC DSN Settings
-----------------
Name:   cdr
DSN:    astconn
  Number of active connections: 1 (out of 20)
```

الخطوة 3 - تهيئة تعريف ODBC التكيفي في /etc/asterisk/cdr_adaptive_odbc.conf

```
[cdr]
connection=cdr
table=cdr
```

هنا يشير `connection` إلى قسم الاتصال `[cdr]` المحدد في `res_odbc.conf`، و `table` هو جدول قاعدة البيانات حيث يتم كتابة سجلات CDR.

الخطوة 4 - إعادة تحميل الوحدة النمطية cdr_adaptive_odbc.so:

```
asterisk*CLI> reload cdr_adaptive_odbc
```

الخطوة 5 - قم بإجراء بعض المكالمات وتحقق من قاعدة البيانات بحثاً عن سجلات جديدة. للتحقق من قاعدة البيانات:

```
mysql -u root -p
>use astdb
>select * from cdr;
```

## التطبيقات والوظائف

توجد العديد من التطبيقات المتعلقة بالفوترة.

### CDR(accountcode)

يُستخدم لتعيين رمز حساب قبل استدعاء تطبيق الاتصال dial()؛ على سبيل المثال: التنسيق:

```
Set(CDR(accountcode)=account)
```

يمكن التحقق من رمز الحساب باستخدام متغير القناة ${CDR(accountcode)}

### CDR(amaflags)

يُستخدم لتعيين علامة لأغراض الفوترة. الخيارات المتاحة هي default و omit و documentation و billing.

```
Set(CDR(amaflags)=amaflags)
```

### Set(CDR_PROP(disable)=1)

يعطل تسجيل CDR للقناة الحالية، بحيث لا يتم كتابة أي سجل CDR في الملف أو قاعدة البيانات. إعادة تعيينه إلى `0` تؤدي إلى إعادة تفعيل التسجيل.

```
Set(CDR_PROP(disable)=1)
```

تمت إزالة تطبيق `NoCDR()` الذي كانت تستخدمه الإصدارات السابقة لهذا الغرض في Asterisk 21؛ أما في Asterisk 22، فإنك تقوم بتعطيل CDR الخاص بالقناة باستخدام `Set(CDR_PROP(disable)=1)` بدلاً من ذلك.

### ResetCDR()

يعيد ضبط سجل بيانات المكالمة (Call Data Record): يتم ضبط وقت `start` (وإذا تم الرد، وقت `answer`) على الوقت الحالي، ويتم مسح جميع متغيرات CDR. إذا تم تعيين الخيار `v`، فسيتم الاحتفاظ بمتغيرات CDR أثناء إعادة الضبط.

### Set(CDR(userfield)=Value)

يقوم هذا الأمر بتعيين حقل مستخدم في CDR. عند استخدام `cdr_adaptive_odbc`، يتم تخزين حقل المستخدم تلقائياً إذا كان عمود `userfield` موجوداً في جدول CDR — دون الحاجة إلى إعادة تجميع المصدر. بالنسبة لملفات نصوص CSV، يتعين عليك تعديل الكود المصدري (cdr_csv.c) وإعادة تجميع Asterisk إذا كنت ترغب في استخدام حقول المستخدم.

كانت الإصدارات السابقة تخزن سجلات CDR في MySQL باستخدام وحدة `cdr_addon_mysql` (`cdr_mysql.conf`). تمت إزالة تلك الوحدة في Asterisk 19، لذا فهي غير متوفرة في Asterisk 22. المسار المدعوم الآن هو `cdr_adaptive_odbc` مع برنامج تشغيل MySQL ODBC، والذي يقوم بتخزين حقل المستخدم — وأي عمود مخصص آخر — بشكل أصلي من خلال تعيين الأعمدة التكيفي الخاص به.

### الإلحاق بحقل المستخدم

كانت الإصدارات السابقة تستخدم تطبيق `AppendCDRUserField()` لإلحاق البيانات بحقل مستخدم CDR. تمت إزالة ذلك التطبيق من Asterisk؛ أما في Asterisk 22، فيمكنك الإلحاق بحقل المستخدم عن طريق قراءته وإعادة تعيينه باستخدام وظيفة `CDR`، على سبيل المثال `Set(CDR(userfield)=${CDR(userfield)}extra)`.

![13-call-detail-records figure 1](../images/13-call-detail-records-img01.png)

## مصادقة المستخدم

تقوم بعض الشركات بفوترة المكالمات لموظفيها. في Asterisk، يمكنك إعداد نظام مصادقة يتيح لك فوترة المستخدم الذي تمت مصادقته في سجلات تفاصيل المكالمات (CDR). يمكن إجراء هذه المصادقة باستخدام كلمة مرور يتم تمريرها كمعامل إلى تطبيق Authenticate—سواء كان ملف كلمات مرور، يُشار إليه بـ / (شرطة مائلة) قبل المعامل، أو مفتاح قاعدة بيانات Asterisk (باستخدام الخيار `d`). الصيغة:

```
Authenticate(password[,options[,maxdigits[,prompt]]])
Authenticate(/passwdfile[,options])
```

الخيارات:

- a – يضبط رمز حساب القناة على كلمة المرور التي تم إدخالها.
- d – يفسر المسار المحدد كمفتاح قاعدة بيانات Asterisk بدلاً من كونه ملفاً حرفياً.
- m – يفسر المسار كملف من أسطر `accountcode:passwordhash`.
- r – يحذف مفتاح قاعدة البيانات بعد نجاح المصادقة (صالح مع `d` فقط).

إذا فشل المتصل في جميع المحاولات الثلاث، يتم إنهاء القناة؛ ولا يستمر تنفيذ الـ dialplan، لذا تعامل مع مسار الفشل في السطر الذي يلي `Authenticate()`. مثال (المكالمات الدولية):

```
exten=_9011.,1,Authenticate(/password,d)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

تمت إزالة الخيار القديم `j` (القفز إلى الأولوية n+101 عند الفشل) واتفاقية الأولوية `+101` من Asterisk منذ فترة طويلة؛ حيث يؤدي فشل `Authenticate()` ببساطة إلى إنهاء المكالمة.

لإدراج كلمة المرور في مفتاح قاعدة بيانات من وحدة التحكم:

```
asterisk*CLI> database put senha 123456 1
```

## استخدام كلمات المرور من voicemail

يقوم هذا التطبيق بنفس وظيفة authenticate، ولكنه يستخدم ملف إعدادات voicemail للتحقق من كلمة المرور.

```
VMAuthenticate([mailbox][@context][,options])
```

إذا تم تحديد mailbox، فسيتم اعتبار كلمة مرور ذلك الـ mailbox فقط صالحة. إذا لم يتم تحديد الـ mailbox، فسيتم ضبط متغير القناة `${AUTH_MAILBOX}` باستخدام الـ mailbox الذي تم التحقق منه. إذا تم ضبط الخيار `s`، فسيتم تخطي المطالبات الأولية. مثال (المكالمات الدولية):

```
exten=_9011.,1,VMAuthenticate(${CALLERID(num)}@local,s)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

## سجل أحداث القناة (CEL)

توفر سجلات CDR صفاً ملخصاً واحداً لكل مكالمة. ولتتبع أكثر تفصيلاً للأحداث — مثل انتقالات حالة القناة الفردية، وأحداث الدخول/الخروج من الجسر، ومراحل التحويل الموجه — يتضمن Asterisk 22 ميزة **سجل أحداث القناة (CEL)**، والتي يتم تهيئتها عبر `/etc/asterisk/cel.conf` وتخزينها من خلال أنظمة خلفية مثل `cel_odbc` أو `cel_custom`.

تُعد CEL مكملاً لـ CDR وليست بديلاً عنها: حيث تظل CDR هي المعيار لملخصات الفوترة، بينما توفر CEL بيانات دقيقة لكل حدث، وهي مفيدة للكشف عن الاحتيال، ومراقبة الجودة، وإعداد التقارير المتقدمة.

يعكس نمط تهيئة `cel.conf` نظيره في `cdr.conf`: حيث تقوم بتمكين أنواع الأحداث التي تريدها في قسم `[general]` من ملف `cel.conf`، ثم تقوم بتهيئة كل نظام تخزين خلفي في ملفه الخاص — `cel_custom.conf` لملفات CSV، و `cel_odbc.conf` لقاعدة بيانات ODBC (نفس اتصال `res_odbc.conf` المستخدم لـ CDRs). يمكنك التأكد مما إذا كانت CEL نشطة باستخدام الأمر `cel show status` على واجهة CLI.

## ملخص

في هذا الفصل، تعلمنا كيفية تنفيذ تسجيل CDR في ملفات نصية وفي قاعدة بيانات MySQL. كما تعلمنا كيفية ضبط amaflags و account codes. وفي نهاية الفصل، تعلمنا كيفية استخدام نظام مصادقة مدمج مع CDR والفوترة.

## اختبار

1. افتراضياً، يقوم Asterisk بتسجيل CDR في المجلد /var/log/asterisk/cdr-csv.
   - A. خطأ
   - B. صح
2. يمكن لـ Asterisk كتابة سجلات CDR إلى (اختر كل ما ينطبق):
   - A. MySQL
   - B. Native Oracle
   - C. Microsoft SQL Server
   - D. ملفات نصية بتنسيق CSV
   - E. قواعد البيانات المدعومة عبر unixODBC
3. يقوم Asterisk بإنشاء CDR لنوع واحد فقط من التخزين في كل مرة.
   - A. خطأ
   - B. صح
4. ما هي خيارات amaflags المتاحة في Asterisk؟
   - A. DEFAULT
   - B. OMIT
   - C. TAX
   - D. RATE
   - E. BILLING
   - F. DOCUMENTATION
5. لربط قسم معين بسجل CDR، تستخدم الأمر ___، ويمكن قراءة رمز الحساب (account code) باستخدام متغير القناة ___.
6. الفرق بين `Set(CDR_PROP(disable)=1)` و `ResetCDR()` هو أن تعطيل CDR يمنع كتابة أي سجل، بينما تقوم `ResetCDR()` بإعادة ضبط (تصفير) السجل الحالي. (تمت إزالة تطبيق `NoCDR()` الذي كان يعطل سجلات CDR سابقاً في إصدار Asterisk 21.)
   - A. خطأ
   - B. صح
7. لاستخدام حقل محدد من قبل المستخدم مع وحدة `cdr_csv.so`، يجب عليك تعديل الكود المصدري وإعادة تجميع Asterisk.
   - A. خطأ
   - B. صح
8. طرق المصادقة الثلاث المتاحة لتطبيق Authenticate() هي:
   - A. كلمة المرور (Password)
   - B. ملف كلمات المرور (Password file)
   - C. قاعدة بيانات Asterisk (dbput و dbget)
   - D. البريد الصوتي (Voicemail)
9. يتم تحديد كلمات مرور البريد الصوتي في قسم منفصل من `voicemail.conf` وهي ليست نفس كلمات مرور مستخدمي البريد الصوتي.
   - A. خطأ
   - B. صح
10. يحل سجل أحداث القناة (CEL) محل CDR في Asterisk 22 — بمجرد تمكين CEL، لن يتم إنتاج ملخصات فواتير CDR بعد الآن.
    - A. خطأ
    - B. صح

**الإجابات:** 1 — B · 2 — A, B, C, D, E · 3 — A · 4 — A, B, E, F · 5 — `Set(CDR(accountcode)=...)`; `${CDR(accountcode)}` · 6 — B · 7 — A · 8 — A, B, C · 9 — B · 10 — A
