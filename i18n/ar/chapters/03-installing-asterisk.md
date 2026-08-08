# تثبيت Asterisk 22

في الفصل الأول، تعلمنا القليل حول كيفية كون Asterisk مفيداً في بيئة الاتصالات الهاتفية. في هذا الفصل، سنغطي كيفية تنزيل وتثبيت Asterisk. قبل البدء، من الضروري تعلم كيفية تجميع وتثبيت البرنامج. قد تبدو عملية التجميع غريبة لمستخدمي Microsoft™ Windows™ التقليديين، لكنها شائعة جداً في بيئة Linux™. يمكن للمرء الحصول على كود مُحسّن لجهازه عند تجميع Asterisk، وهو ما سنقوم به هنا. يعمل Asterisk على العديد من أنظمة التشغيل، لكننا سنجعل الأمور سهلة وسنستخدم نظاماً واحداً فقط: Linux. نحن نستخدم **Ubuntu 24.04 LTS** لأن تبعاته سهلة التثبيت، ولأنه توزيعة خادم مستقرة ومدعومة جيداً وذات بصمة منخفضة. إذا كنت تفضل توزيعة أخرى، فقم بتعديل أسماء الحزم وفقاً لذلك.

تستهدف هذه النسخة **Asterisk 22 LTS** (تم إصداره في 2024-10-16؛ دعم كامل حتى 2028-10-16، وإصلاحات أمنية حتى 2029-10-16). يُعد Asterisk 22 هو إصدار الدعم طويل الأمد الحالي. لاحظ أن شركة Digium استحوذت عليها **Sangoma** في عام 2018، وأصبح Asterisk الآن برعاية Sangoma — الإشارات إلى "Digium" في جميع أنحاء هذا الفصل تشير إلى العلامة التجارية القديمة للأجهزة التاريخية.

## الأهداف

بحلول نهاية هذا الفصل، ستكون قادراً على:

- تحديد متطلبات العتاد (Hardware) اللازمة لـ Asterisk؛
- تثبيت نظام Linux مع الاعتمادات (Dependencies) المطلوبة؛
- تنزيل إصدار مستقر عبر HTTPS؛
- تجميع (Compile) برنامج Asterisk؛ و
- تعلم كيفية تشغيل Asterisk تلقائياً عند بدء تشغيل النظام.

## الحد الأدنى من الأجهزة المطلوبة

لا يحتاج Asterisk إلى الكثير من الأجهزة للتشغيل، ومع ذلك هناك بعض النصائح لاختيار أفضل الأجهزة التي تلبي متطلباتك. يجب عليك أن تأخذ في الاعتبار العوامل الرئيسية التالية عند اختيار أجهزتك:

- إجمالي عدد المستخدمين المسجلين. حدد عدد عمليات التسجيل في الثانية التي تحتاج إلى دعمها.
- إجمالي عدد المكالمات المتزامنة. حدد عدد المحادثات الشبكية التي تحتاج إلى معالجتها في محول الشبكة والجسر (bridge) على خادم Asterisk.
- برامج الترميز (codecs) التي تحتاج إلى دعمها. تتطلب برامج الترميز ذات التعقيد العالي الكثير من طاقة المعالج (CPU/FPU) في خادمك؛ فعلى سبيل المثال، تم قياس iLBC من قبل مبتكرها (Global IP Sound) بحوالي 18 MIPS لكل قناة لإطارات 30 ms (وحوالي 15 MIPS لإطارات 20 ms) على معالج إشارة رقمية (DSP) من نوع TI C54x.
- إلغاء الصدى (Echo cancellation). قد يستهلك إلغاء الصدى الكثير من طاقة المعالج (CPU/FPU)، وفي بعض الحالات يجب عليك اختيار إلغاء الصدى المعتمد على الأجهزة باستخدام معالجات الإشارة الرقمية (DSPs) في بطاقة واجهة الهاتف.
- التوافر. استخدم RAID1 أو 5 لزيادة التوافر. تذكر أن Asterisk هو تطبيق يعمل على مدار الساعة طوال أيام الأسبوع (24x7).

المكون الرئيسي لخادم Asterisk هو محول الشبكة. يوصى باستخدام محول شبكة خادم جيد. يعد المعالج (CPU) مهماً عندما تحتاج إلى دعم برامج ترميز عالية التعقيد مثل g.729 و iLBC وإلغاء الصدى. يمكنك اختيار تفريغ هذه المهام إلى معالجات إشارة رقمية (DSPs) مخصصة: توفر Sangoma (المعروفة سابقاً باسم Digium) بطاقة DSP تسمى TC400B قادرة على دعم 120 مكالمة متزامنة باستخدام g.729.

أفضل ممارسة هي اختيار جهاز كمبيوتر جديد من فئة الخوادم من شركة مصنعة معروفة. لمعرفة عدد المكالمات المتزامنة أو عدد المستخدمين المسجلين الذي يمكن لجهاز معين دعمه بدقة، يجب عليك اختبار هذا الجهاز باستخدام أداة اختبار الضغط مثل SIPP (http://sipp.sourceforge.net). يقوم بعض مصنعي الأجهزة مثل Xorcom (http://www.xorcom.com) بنشر نتائجهم على موقعهم الإلكتروني.

ملاحظة: تحتاج بعض تطبيقات Asterisk، مثل ConfBridge و music on hold، إلى مصدر توقيت داخلي. في أنظمة Linux الحديثة، يتم توفير هذا تلقائياً بواسطة الوحدة المدمجة `res_timing_timerfd` — ولا يلزم وجود أجهزة هاتفية. (لم يعد مؤقت البرمجيات القديم `dahdi_dummy` موجوداً؛ حيث تم دمج وظائفه في وحدة النواة الرئيسية `dahdi` في DAHDI Linux 2.3.0.) يمكنك التأكد من المؤقت النشط باستخدام أمر CLI `timing test`.

### تهيئة الأجهزة

لا تحتاج أجهزة Asterisk إلى أن تكون متطورة. لست بحاجة إلى بطاقة فيديو باهظة الثمن أو العديد من الأجهزة الطرفية. إليك بعض النصائح حول تهيئة الأجهزة:

- قم بتعطيل منافذ USB والتسلسلية والمتوازية غير المستخدمة لتجنب استهلاك المقاطعات (interrupts) غير الضرورية.
- تعد بطاقة واجهة الشبكة القوية أمراً ضرورياً.
- توخَّ حذراً خاصاً إذا كنت تستخدم بطاقات واجهة الهاتف. تستخدم بعض البطاقات ناقل PCI بجهد 3.3 فولت، وليس من السهل العثور على لوحات أم تدعمها. في هذه الأيام، أصبح العثور على PCI express أسهل.
- أولِ اهتماماً وثيقاً للقرص الصلب، حيث تعمل أنظمة PBX بنظام 24x7 بينما تعمل أجهزة الكمبيوتر المكتبية بنظام 8x5. لا تستخدم أجهزة مكتبية لنظام PBX، فعادة ما يتعطل القرص الصلب قبل العام الأول. توصيتي هي استخدام جهاز خادم أو جهاز مخصص (appliance) مصمم لتشغيل تطبيقات 24x7.

### مشاركة IRQ (للبطاقات القديمة من نوع PCI فقط)

ينطبق هذا القلق **فقط** إذا قمت بتثبيت بطاقات هاتفية فيزيائية من نوع PCI/PCI-Express (أجهزة DAHDI). تولد هذه البطاقات أعداداً كبيرة من المقاطعات، وفي أنظمة المعالج الواحد القديمة، قد تؤدي مشاركة خط IRQ مع جهاز آخر إلى حرمان برنامج التشغيل من الموارد وتقليل جودة الصوت. إذا كنت تستخدم بطاقات هاتفية، فخصص الجهاز لـ Asterisk، وقم بتعطيل أي أجهزة داخلية غير مستخدمة في BIOS، وتحقق من المقاطعات المعينة باستخدام `cat /proc/interrupts`. تجعل خوادم المعالجات المتعددة الحديثة التي تستخدم مقاطعات MSI/MSI-X مشاركة IRQ أمراً غير ذي أهمية من الناحية العملية، ولا يحتاج النشر المعتمد على VoIP فقط (بدون بطاقات) إلى القلق بشأن ذلك على الإطلاق.

## اختيار توزيعة Linux

تم تطوير Asterisk في البداية ليعمل على نظام Linux. ومع ذلك، يمكنه أيضاً العمل على أنظمة BSD Unix أو macOS. إذا كنت مبتدئاً في استخدام Asterisk، فحاول استخدام Linux أولاً لأنه أسهل بكثير. يستهدف Asterisk رسمياً عائلة RHEL (مثل CentOS/RHEL/Fedora)، وUbuntu، وDebian. الخيارات العملية الجيدة اليوم هي **Debian 12**، و**Ubuntu 22.04 LTS / 24.04 LTS**، و**Rocky Linux 9 / AlmaLinux 9** — حيث وصل نظام CentOS Linux إلى نهاية عمره الافتراضي، لذا يفضل استخدام Rocky أو AlmaLinux على الأنظمة التابعة لعائلة RHEL. في هذا الكتاب، سأستخدم Ubuntu 24.04 LTS. قم بتنزيل أحدث صورة لخادم 24.04 من دليل الإصدارات الرسمي أدناه (اسم الملف الدقيق يتضمن إصدار النقطة الحالي، على سبيل المثال `ubuntu-24.04.4-live-server-amd64.iso`):

```
https://releases.ubuntu.com/24.04/
```

### إعداد Linux من أجل Asterisk

قبل تجميع Asterisk، تحتاج إلى نظام Linux يعمل مع تثبيت حزم البناء. قم بتثبيت **Ubuntu 24.04 LTS Server** في جهاز افتراضي أو على جهاز مخصص (استخدم صورة 64-bit؛ كل شيء في هذا الكتاب هو 64-bit، على الرغم من أن Asterisk نفسه لا يزال يدعم 32-bit x86). لقد استخدمنا VirtualBox لهذا التدريب؛ يمكنك تنزيل الصورة من <https://releases.ubuntu.com/24.04>. إن تثبيت Linux بحد ذاته خارج نطاق هذا الكتاب — فالمعرفة الأساسية بـ Linux هي شرط أساسي. بعد تثبيت Linux، ستقوم بإضافة تبعيات بناء Asterisk (انظر *تثبيت التبعيات* أدناه) ثم تجميع Asterisk.

## تثبيت Linux من أجل Asterisk

قم بتثبيت Linux كالمعتاد، دون واجهة سطح مكتب رسومية. أثناء التثبيت، قم أيضاً بتمكين وكيل نقل البريد (نستخدم **exim4**) — سيحتاج Asterisk إليه لإرسال إشعارات voicemail-to-email لاحقاً في هذا الكتاب. **تنبيه:** يؤدي تثبيت نظام تشغيل إلى مسح القرص المستهدف. إذا كنت تقوم بالتثبيت على أجهزة فعلية، فقم بنسخ بياناتك احتياطياً أولاً؛ أما التثبيت داخل جهاز افتراضي فيترك جهازك المضيف دون مساس. قم بالإقلاع من مثبت Ubuntu Server ISO (أو محرك الأقراص الضوئي الافتراضي للجهاز) وأجب على المطالبات — معظمها مباشر.

## تثبيت المتطلبات البرمجية

لتثبيت Asterisk و DAHDI، يتعين عليك تثبيت العديد من المتطلبات البرمجية. الطريقة الموصى بها للقيام بذلك في Asterisk 22 هي استخدام البرنامج النصي المرفق مع شجرة المصدر، والذي يعرف أسماء الحزم الصحيحة لكل توزيعة مدعومة. بعد تنزيل واستخراج مصدر Asterisk (انظر "تجميع Asterisk" أدناه)، قم بتشغيل:

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. سجل الدخول بصلاحية root (أو استخدم `sudo`).
2. إذا كنت تفضل تثبيت المتطلبات البرمجية يدوياً على نظام Debian/Ubuntu، فإن قائمة الحزم المكافئة هي:

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

لاحظ أن مصدر Asterisk مستضاف الآن على Git، لذا لم تعد `subversion` مطلوبة، كما أن أنظمة Debian/Ubuntu الحديثة توفر `libncurses-dev` بدلاً من الإصدار المسمى `libncurses5-dev`. يفضل استخدام `./contrib/scripts/install_prereq install` بدلاً من قائمة يتم صيانتها يدوياً، حيث أن البرنامج النصي يتتبع دائماً أسماء الحزم الصحيحة لتوزيعتك.

### DAHDI

تعد DAHDI (واجهة أجهزة Asterisk من Digium/Sangoma) هي بنية برامج التشغيل للبطاقات التناظرية والرقمية. قبل تثبيت Asterisk، من المهم تثبيت DAHDI إذا كنت تخطط لاستخدام واجهات تناظرية أو رقمية. لا تزال DAHDI موجودة لبطاقات الهاتف التناظرية/الرقمية ولكنها أصبحت متخصصة بشكل متزايد — معظم عمليات النشر الحديثة تعتمد بالكامل على VoIP ويمكنها تخطي هذا القسم تماماً. قم بتثبيت DAHDI فقط إذا كان لديك أجهزة واجهة هاتف فعلية. احصل على ملفات المصدر باستخدام:

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

قم بفك ضغط الملفات باستخدام:

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### تجميع برامج تشغيل DAHDI

ستحتاج إلى تجميع وحدات DAHDI. تم تقديم الأمرين ./configure و make menuselect منذ عدة سنوات. يتيح لك الأخير اختيار الأدوات والوحدات التي تريد بناءها. ستقوم الأوامر التالية بذلك:

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

make install-config تم تكوين DAHDI. إذا كان لديك أي أجهزة DAHDI، فمن المستحسن الآن تعديل /etc/dahdi/modules من أجل تحميل الدعم فقط لأجهزة DAHDI المثبتة في هذا النظام. افتراضياً، يتم تحميل الدعم لجميع أجهزة DAHDI عند بدء تشغيل DAHDI. أعتقد أن أجهزة DAHDI الموجودة على نظامك هي: usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware تطلب منك هذه الشاشة (أعلاه) تغيير الملف /etc/dahdi/modules لتحميل برامج التشغيل المطلوبة فقط لتكوينك الخاص وإظهار الأجهزة المكتشفة. قم بتعديل الملف /etc/dahdi/modules وقم بتحميل الأجهزة المطلوبة فقط. في حالتي، كنت أستخدم جهاز اختبار يحتوي على Xorcom Astribank 6FXS و 2FXO. يظهر الملف أدناه.

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

أعد تهيئة جهاز الكمبيوتر الخاص بك وتحقق من التحميل الصحيح لبرامج التشغيل.

## أي إصدار يجب اختياره

كقاعدة عامة، يجب عليك استخدام الإصدار الذي يحتوي على الميزات المطلوبة. يتبع Asterisk نموذج إصدار يتناوب بين إصدارات LTS (دعم طويل الأمد) والإصدارات القياسية. في وقت كتابة هذا الإصدار، **يُعد Asterisk 22 هو إصدار LTS الحالي** (الذي تم إصداره في أكتوبر 2024؛ وأحدث إصدار فرعي هو 22.10.0)، مما يجعله الخيار الأفضل حالياً. يُعد Asterisk 20 هو إصدار LTS السابق، بينما وصل الإصدار 16 (المستخدم في الطبعة الأولى) إلى نهاية عمره الافتراضي. بالنسبة لأنظمة الإنتاج، اختر دائماً إصدار LTS.

## تجميع Asterisk

إذا سبق لك تجميع برمجيات، فإن تجميع Asterisk سيكون مهمة سهلة. قم بتنفيذ الأوامر التالية لتجميع وتثبيت Asterisk. تذكر أنه يمكنك اختيار التطبيقات والوحدات البرمجية التي تريد بناءها باستخدام make menuselect. الخطوة 1: تنزيل الكود المصدري

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

الخطوة 2: تثبيت المتطلبات الأساسية للبناء (انظر "تثبيت التبعيات" أعلاه)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

الخطوة 3: تهيئة عملية البناء

```
./configure
```

الخطوة 4: اختيار الوحدات البرمجية المراد بناؤها

```
make menuselect
```

استخدم make menuselect لتثبيت الوحدات الضرورية فقط. في Asterisk 22، قناة SIP هي **chan_pjsip** (يتم بناؤها افتراضياً)؛ أما **chan_sip** القديمة فقد تمت إزالتها في Asterisk 21 ولم تعد موجودة. تعمل ميزة *pass-through* لترميز Opus بشكل مباشر (حيث تتولى وحدة `res_format_attr_opus` المدمجة مع الكود المصدري عملية تفاوض SDP)، ولكن وحدة تحويل الترميز **codec_opus** لا تزال ثنائية خارجية ومغلقة المصدر من Sangoma/Digium — واختيارها في menuselect يؤدي إلى تنزيلها من خوادم Digium. هذا الملف الثنائي مجاني. انظر "اختيار الوحدات باستخدام menuselect" أدناه للحصول على التفاصيل.

الخطوة 5: بناء وتثبيت Asterisk، ثم إنشاء ملفات الإعدادات الافتراضية والنموذجية

```
make
make install
make samples
make config
ldconfig
```

يقوم `make install` بتثبيت الملفات الثنائية والوحدات البرمجية، بينما يقوم `make samples` بكتابة ملفات الإعدادات النموذجية في `/etc/asterisk`، ويقوم `make config` بتثبيت سكربت بدء التشغيل SysV init الخاص بتوزيعتك المكتشفة (على سبيل المثال `/etc/init.d/asterisk` على Debian/Ubuntu)، ويقوم `ldconfig` بتحديث ذاكرة التخزين المؤقت للمكتبات المشتركة. يتم أيضاً توفير وحدة systemd في شجرة الكود المصدري في `contrib/systemd/asterisk.service`، ولكن `make config` لا يقوم بتثبيتها تلقائياً — انسخها إلى مكانها بنفسك إذا كنت تفضل تشغيل Asterisk تحت systemd (انظر أدناه).

### اختيار الوحدات باستخدام menuselect

يفتح `make menuselect` قائمة نصية حيث يمكنك اختيار التطبيقات، وcodec، وchannels، والموارد التي تريد بناءها بدقة. إليك بعض الملاحظات الخاصة بـ Asterisk 22:

- **chan_pjsip** (تحت *Channel Drivers*) هي قناة SIP الحديثة ويتم تفعيلها افتراضياً؛ وهي قناة SIP الوحيدة في Asterisk 22.
- **codec_opus** (تحت *Codec Translators*) هي وحدة **خارجية** (يظهر مدخلها في menuselect كـ "Download the Opus codec from Digium")؛ وتفعيلها يجعل `make` يجلب الملف الثنائي المجاني ومغلق المصدر من Sangoma/Digium. لا تحتاج ميزة Opus pass-through نفسها إلى أي وحدة إضافية. تتوفر أيضاً وحدة **codec_g729** من Sangoma — الملف الثنائي مجاني للتنزيل، ولكن تحويل ترميز G.729 بشكل قانوني يتطلب شراء ترخيص لكل قناة.
- اختر تنسيقات الصوت واللغات التي تريدها في قوائم *Core Sound Packages*، و*Music On Hold File Packages*، و*Extras Sound Packages*؛ أي شيء تحدده هناك سيتم تنزيله وتثبيته تلقائياً أثناء `make install`.

بعد إجراء اختياراتك، اختر **Save & Exit** وتابع مع `make`.

## بدء وإيقاف Asterisk

باستخدام هذا الإعداد البسيط، من الممكن بدء تشغيل Asterisk بنجاح. لأغراض التعلم وتصحيح الأخطاء، يمكنك بدء تشغيل Asterisk في الواجهة الأمامية (foreground) متصلاً بوحدة التحكم (console):

```
/usr/sbin/asterisk -vvvgc
```

استخدم أمر CLI التالي `core stop now` لإيقاف تشغيل Asterisk:

```
*CLI> core stop now
```

### بدء تشغيل Asterisk باستخدام systemd

في توزيعات Linux الحديثة (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9)، مدير خدمات النظام هو **systemd**. يوفر Asterisk ملف وحدة (unit file) خاص بـ systemd في المسار `contrib/systemd/asterisk.service` ضمن شجرة المصدر؛ قم بنسخه إلى `/etc/systemd/system/asterisk.service` وقم بتشغيل `systemctl daemon-reload`. بمجرد التثبيت، الطريقة الموصى بها لتشغيل Asterisk في بيئة الإنتاج هي من خلال `systemctl`:

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

بمجرد تشغيل Asterisk كخدمة، اتصل بـ CLI الخاص به باستخدام `asterisk -r` (للاتصال) أو `asterisk -rvvv` (للاتصال مع مخرجات تفصيلية).

في الأنظمة الأقدم، كان يتم بدء تشغيل Asterisk عبر سكربت SysV init القديم (`/etc/init.d/asterisk`) وغلاف **safe_asterisk**، الذي كان يعيد تشغيل Asterisk تلقائياً في حال تعطلها. مع systemd، تتم معالجة إعادة التشغيل التلقائي بواسطة توجيه `Restart=` في ملف الوحدة، لذا فإن `safe_asterisk` لم يعد ضرورياً بشكل عام. لا تزال طريقة init/`safe_asterisk` القديمة تعمل ولكنها تعتبر مهملة في التوزيعات التي تعتمد على systemd.

### خيارات وقت التشغيل لـ Asterisk

عملية بدء تشغيل Asterisk بسيطة للغاية. إذا تم تشغيل Asterisk بدون أي معاملات، فسيتم إطلاقه كخدمة (daemon).

```
/sbin/asterisk
```

يمكنك الوصول إلى وحدة تحكم Asterisk عن طريق تنفيذ الأمر التالي. يرجى ملاحظة أنه يمكن تشغيل أكثر من عملية وحدة تحكم في نفس الوقت.

```
/sbin/asterisk -r
```

### خيارات وقت التشغيل المتاحة لـ Asterisk

يمكنك عرض خيارات وقت التشغيل المتاحة باستخدام `asterisk -h`

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## أدلة التثبيت

يتم تثبيت Asterisk في عدة أدلة، والتي يمكن تعديلها في ملف asterisk.conf. لأغراض التدريب، أقوم بتغيير verbose من 3 إلى 15، أما في بيئة الإنتاج فيفضل إبقاؤه عند 3. الخياران `maxcalls` و `maxload` هما خياران جيدان لحماية نظامك من التحميل الزائد.

### asterisk.conf (مقتطف)

يحدد القسم `[directories]` الأماكن التي يحتفظ فيها Asterisk بملفات الإعدادات، والوحدات النمطية (modules)، والبيانات، و spool، والسجلات (logs):

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

يحتوي القسم `[options]` على إعدادات الضبط أثناء التشغيل. الخيارات الأكثر فائدة التي يجب معرفتها موضحة أدناه (قم بإزالة التعليق لتفعيلها)؛ يأتي الملف مع العديد من الخيارات الأخرى، وكل منها موثق بتعليق مضمن:

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## ملفات السجلات وتدوير السجلات

يقوم Asterisk PBX بتسجيل رسائله في `/var/log/asterisk`. يتم التحكم في التسجيل بواسطة `logger.conf`. الجزء الرئيسي هو قسم `[logfiles]`، حيث يحدد كل سطر قناة سجل ومستويات الرسائل التي تلتقطها (مقتطف):

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

بعد التعديل، قم بتطبيق التغيير باستخدام `logger reload` وتأكد من القنوات باستخدام `logger show channels`:

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

يمكن أن تنمو ملفات السجلات بسرعة، لذا قم بتدويرها باستخدام برنامج النظام الخفي `logrotate` — أضف ملفاً تحت `/etc/logrotate.d/`:

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

يمكن الحصول على مزيد من المعلومات حول logrotate باستخدام:

```
#man logrotate
```

## إلغاء تثبيت Asterisk

لإلغاء تثبيت Asterisk، استخدم:

```
make uninstall
```

لإلغاء تثبيت Asterisk وجميع ملفات الإعدادات، استخدم:

```
make uninstall-all
```

## ملاحظات تثبيت Asterisk

سيوفر هذا القسم بعض النصائح حول المشكلات التي يجب معالجتها قبل تثبيت Asterisk.

### أنظمة الإنتاج

إذا تم تثبيت Asterisk في بيئة إنتاج، فيجب عليك الانتباه إلى تصميم النظام. يجب تحسين الخادم بطريقة تمنح أنظمة الهاتف الأولوية على عمليات النظام الأخرى. لا ينبغي تشغيل Asterisk مع برامج تستهلك قدرات المعالج بشكل مكثف مثل X-Windows. إذا كنت بحاجة إلى تشغيل عمليات تستهلك قدرات المعالج (مثل قاعدة بيانات ضخمة)، فاستخدم خادماً منفصلاً. وبشكل عام، يعتبر Asterisk حساساً لتغيرات أداء الأجهزة. لذا، حاول استخدام Asterisk في بيئة أجهزة لا تتطلب أكثر من 40% من استخدام المعالج.

### نصائح الشبكة

إذا كنت تخطط لاستخدام هواتف IP، فمن المهم أن تولي اهتماماً لشبكتك. بروتوكولات الصوت جيدة جداً ومقاومة لزمن الانتقال (latency) وحتى التذبذب (jitters)؛ ومع ذلك، إذا كنت تستخدم شبكة محلية مهيأة بشكل سيئ، فسوف تتأثر جودة الصوت. لا يمكن ضمان جودة صوت جيدة إلا باستخدام جودة الخدمة (QoS) في المحولات (switches) وأجهزة التوجيه (routers). يميل الصوت في الشبكة المحلية إلى أن يكون جيداً، ولكن حتى في بيئة LAN، إذا كان لديك محاور (hubs) بسرعة 10 Mbps مع الكثير من التصادمات، فسينتهي بك الأمر بصوت مشوه أو رديء. اتبع هذه التوصيات لضمان أفضل جودة صوت ممكنة:

- استخدم جودة الخدمة (QoS) من الطرف إلى الطرف (end-to-end) إذا كان ذلك ممكناً أو مجدياً اقتصادياً. مع جودة الخدمة من الطرف إلى الطرف، تكون جودة الصوت مثالية. لا توجد أعذار!
- تجنب استخدام محاور (hubs) بسرعة 10/100 Mbps للصوت في بيئة الإنتاج. يمكن أن تفرض التصادمات تذبذبات (jitters) على الشبكة. يفضل استخدام تقنية الازدواج الكامل (full duplex) بسرعة 10/100 Mbps لأنه لا تحدث أي تصادمات.
- استخدم شبكات VLAN لفصل عمليات البث غير الضرورية عن شبكة الصوت. أنت لا تريد فيروساً يدمر شبكة الصوت الخاصة بك من خلال بث ARP.
- ثقّف المستخدمين حول التوقعات في شبكة الصوت. بدون جودة الخدمة (QoS)، لا تصرح بأن الصوت سيكون مثالياً لأنه في معظم الحالات لن يكون كذلك. غالباً ما يتم تحقيق جودة صوت مشابهة للهاتف المحمول. استخدم هواتف ذات جودة عالية لأن المشكلات المتعلقة بالبرامج الثابتة (firmware) وتصميم الأجهزة شائعة.

## ملخص

في هذا الفصل، تعلمت الحد الأدنى من متطلبات العتاد بالإضافة إلى كيفية تنزيل Asterisk وتثبيته وتجميعه. يجب تشغيل Asterisk باستخدام مستخدم غير الجذر (non-root user) لأسباب أمنية. ينبغي عليك التحقق من بيئة الشبكة الخاصة بك قبل بدء بيئة الإنتاج.

## اختبار

1. في Asterisk 22، أي مشغل قنوات (channel driver) يوفر دعم SIP، وما الذي حدث لـ `chan_sip` الأقدم؟
   - أ. `chan_sip` لا يزال هو الافتراضي؛ و `chan_pjsip` اختياري.
   - ب. `chan_pjsip` هو مشغل SIP الافتراضي؛ أما `chan_sip` فقد تمت إزالته في Asterisk 21 ولم يعد موجوداً.
   - ج. كلاهما يتم بناؤهما افتراضياً وتختار بينهما أثناء التشغيل.
   - د. تمت إزالة دعم SIP بالكامل لصالح IAX2.
2. بطاقات واجهة الهاتف لـ Asterisk تحتوي عادةً على معالجات إشارات رقمية (DSPs) مدمجة، وبالتالي لا تحتاج إلى الكثير من قدرة المعالج (CPU) من جهاز الكمبيوتر.
   - أ. صحيح
   - ب. خطأ
3. إذا كنت ترغب في الحصول على جودة صوت مثالية، فأنت بحاجة إلى تطبيق جودة الخدمة (QoS) من الطرف إلى الطرف.
   - أ. صحيح
   - ب. خطأ
4. يجب عليك دائماً اختيار أحدث إصدار من Asterisk، لأنه الأكثر استقراراً.
   - أ. صحيح
   - ب. خطأ
5. ما هي الطريقة الموصى بها لتثبيت تبعيات البناء (build dependencies) لـ Asterisk 22؟
6. إذا لم تكن لديك بطاقة واجهة TDM، فسيظل لديك مصدر توقيت داخلي للمزامنة، يتم توفيره بواسطة وحدة `res_timing_timerfd` على Linux. يُستخدم هذا التوقيت من قبل تطبيقات مثل ________ و ________.
7. عند تثبيت Asterisk، من الأفضل استبعاد بيئات سطح المكتب مثل GNOME أو KDE، لأن الواجهات الرسومية تستهلك دورات المعالج (CPU).
   - أ. صحيح
   - ب. خطأ
8. توجد ملفات تكوين Asterisk في الدليل ________.
9. لتثبيت ملفات تكوين Asterisk النموذجية، اكتب الأمر: ________
10. لماذا من المهم تشغيل Asterisk كمستخدم غير الجذر (non-root user)؟

**الإجابات:** 1 — ب · 2 — ب · 3 — أ · 4 — ب · 5 — قم بتشغيل `./contrib/scripts/install_prereq install` من شجرة مصدر Asterisk المستخرجة · 6 — ConfBridge و Music on Hold · 7 — أ · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — الأمان (يحد من الضرر في حال تعرض Asterisk للاختراق)
