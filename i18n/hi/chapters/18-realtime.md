# Asterisk Real-Time

जैसा कि आप जानते हैं, Asterisk कॉन्फ़िगरेशन /etc/asterisk डायरेक्टरी में कई टेक्स्ट फ़ाइलों के उपयोग के माध्यम से प्राप्त किया जाता है। टेक्स्ट फ़ाइलों का उपयोग करने की सरलता के बावजूद, कुछ ज्ञात कमियां हैं:

- हर बार फ़ाइलों के बदले जाने पर Asterisk को रिलोड करने की आवश्यकता
- उपयोगकर्ताओं की बड़ी संख्या के लिए मेमोरी का अधिक उपयोग
- टेक्स्ट फ़ाइलों का उपयोग करके प्रोविज़निंग इंटरफ़ेस को कोड करना कठिन है
- मौजूदा डेटाबेस के साथ एकीकरण की कोई संभावना नहीं

ARA या Asterisk Realtime, जैसा कि इसे जाना जाता है, को Anthony Minessale II, Mark Spencer, और Constantine Filin द्वारा बनाया गया था और इसे SQL डेटाबेस के साथ पारदर्शी एकीकरण की अनुमति देने के लिए डिज़ाइन किया गया था। एक LDAP इंटरफ़ेस भी उपलब्ध है। इस सिस्टम को Asterisk External Configuration के रूप में भी जाना जाता है और इसे /etc/asterisk/extconfig.conf में कॉन्फ़िगर किया जाता है। आप कॉन्फ़िगरेशन फ़ाइलों को डेटाबेस में तालिकाओं (स्टैटिक कॉन्फ़िगरेशन) और Asterisk को रिलोड करने की आवश्यकता के बिना ऑब्जेक्ट्स के डायनामिक निर्माण के लिए रियल-टाइम प्रविष्टियों (real-time entries) में मैप कर सकते हैं।

## Objectives

इस अध्याय के अंत तक, पाठक निम्नलिखित में सक्षम होंगे:

- Asterisk Real Time के लाभों और सीमाओं को समझना।
- ARA के साथ उपयोग के लिए ODBC का उपयोग करना।
- ODBC का उपयोग करके ARA को कंपाइल और इंस्टॉल करना।
- लैब वातावरण में सिस्टम का परीक्षण करना।

## Asterisk Real Time कैसे काम करता है?

नई Real Time आर्किटेक्चर में, सभी डेटाबेस-विशिष्ट कोड को चैनल ड्राइवरों में स्थानांतरित कर दिया गया था। चैनल केवल एक सामान्य रूटीन को कॉल करता है जो डेटाबेस को खोजता है। सोर्स कोड के दृष्टिकोण से परिणाम बहुत सरल और स्वच्छ प्रक्रिया है। डेटाबेस को तीन फंक्शन द्वारा एक्सेस किया जाता है:

- STATIC: मॉड्यूल लोड होने पर एक स्टेटिक कॉन्फ़िगरेशन सेट करने के लिए उपयोग किया जाता है।
- REALTIME: कॉल या किसी अन्य इवेंट के दौरान ऑब्जेक्ट्स को खोजने के लिए उपयोग किया जाता है।


- UPDATE: ऑब्जेक्ट्स को अपडेट करने के लिए उपयोग किया जाता है।

Asterisk 22 पर, SIP endpoints को **PJSIP** स्टैक (`res_pjsip`) द्वारा संभाला जाता है, जो **Sorcery** ऑब्जेक्ट मॉडल पर निर्मित है। `realtime` विज़ार्ड के साथ, Sorcery प्रत्येक PJSIP ऑब्जेक्ट को मांग पर डेटाबेस से लोड करता है, और वे ऑब्जेक्ट्स तब सामान्य कॉन्फ़िगर किए गए PJSIP ऑब्जेक्ट्स के रूप में मौजूद होते हैं — न कि उन थ्रोअवे realtime पीयर्स के रूप में जिन्हें पुराना SIP ड्राइवर प्रत्येक कॉल के बाद हटा देता था।

चूंकि वे वास्तविक ऑब्जेक्ट्स हैं, इसलिए NAT traversal, qualify, और message waiting indication (MWI) सभी realtime endpoints के लिए सामान्य रूप से काम करते हैं। (Sorcery को अतिरिक्त रूप से `memory_cache` विज़ार्ड के माध्यम से मेमोरी में ऑब्जेक्ट्स को कैश करने के लिए कहा जा सकता है, लेकिन यह विकल्प वैकल्पिक है और realtime लोडिंग से अलग है।) जब आप डेटाबेस में किसी ऑब्जेक्ट को बदलते हैं, तो परिवर्तन अगले लुकअप पर ले लिया जाता है; आपको प्रत्येक संपादन के बाद रिलोड करने की आवश्यकता नहीं है। (सेवानिवृत्त `chan_sip` realtime मॉडल, अपने `sippeers`/`sipusers` परिवारों के साथ, केवल *Legacy Channels* अध्याय में कवर किया गया है।)

## Asterisk Real Time कॉन्फ़िगर करना

इस लैब के लिए, हम यह मानकर चलेंगे कि आपने CDR अध्याय से ODBC पहले ही इंस्टॉल कर लिया है। ARA को `extconfig.conf` टेक्स्ट फ़ाइल में कॉन्फ़िगर किया जाता है, जहाँ दो सेक्शन आसानी से देखे जा सकते हैं। पहला सेक्शन स्टेटिक कॉन्फ़िगरेशन फ़ाइलों का है, जहाँ आप टेक्स्ट कॉन्फ़िगरेशन फ़ाइलों को डेटाबेस टेबल से बदल सकते हैं। दूसरा सेक्शन रियलटाइम कॉन्फ़िगरेशन इंजन है, जहाँ आप डायनामिक ऑब्जेक्ट्स (peers/users) के लिए डेटाबेस टेबल कॉन्फ़िगर करते हैं। स्टेटिक कॉन्फ़िगरेशन के लिए टेक्स्ट फ़ाइलों और डायनामिक प्रविष्टियों के लिए डेटाबेस का उपयोग करना असामान्य नहीं है। इस मामले में, पहला सेक्शन अछूता रहता है।

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Asterisk Real Time आर्किटेक्चर: कॉन्फ़िगरेशन फ़ाइलें और स्टेटिक डेटाबेस टेबल तब लोड होते हैं जब Asterisk शुरू होता है, जबकि रियलटाइम डेटाबेस टेबल डायनामिक कॉन्फ़िगरेशन प्रदान करते हैं जिसे कॉल के दौरान मांग पर पढ़ा जाता है।](../images/18-realtime-fig01.png)

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


### स्टेटिक कॉन्फ़िगरेशन सेक्शन

स्टेटिक कॉन्फ़िगरेशन सेक्शन वह जगह है जहाँ आप डेटाबेस में कॉन्फ़िगरेशन फ़ाइलों के समकक्ष डेटा स्टोर करते हैं। ये कॉन्फ़िगरेशन Asterisk लोड होने के दौरान पढ़े जाते हैं। कुछ मॉड्यूल आपके द्वारा रिलोड करने पर डेटाबेस को फिर से पढ़ते हैं। स्टेटिक कॉन्फ़िगरेशन के उदाहरण हैं:

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

स्टेटिक फ़ाइल मैपिंग उन कॉन्फ़िगरेशन फ़ाइलों के लिए सबसे उपयोगी है जिनका कोई प्रति-ऑब्जेक्ट (per-object) रियलटाइम समकक्ष नहीं है। PJSIP के लिए, इस अध्याय में बाद में वर्णित प्रति-ऑब्जेक्ट रियलटाइम फैमिलीज (`ps_endpoints`, `ps_aors`, आदि) को प्राथमिकता दें, न कि पूरे `pjsip.conf` को स्टेटिक फ़ाइल के रूप में मैप करने के।

ऊपर तीन उदाहरण वर्णित हैं। पहले उदाहरण में, आप `queues.conf` को `asteriskdb` डेटाबेस में `queues` टेबल से बाइंड करते हैं। दूसरे उदाहरण में, आप `pjsip.conf` को `odbc` कॉन्फ़िगरेशन में परिभाषित `asteriskdb` डेटाबेस में `pjsip_conf` टेबल से बाइंड करते हैं। अंतिम उदाहरण में, आप `iax.conf` को एक LDAP डायरेक्टरी से बाइंड करते हैं। `MyBaseDN` वह बेस DN है जिसे खोजा जाना है। पिछले उदाहरण में, एप्लिकेशन `app_queue.so` लोड होता है जबकि MySQL ड्राइवर डेटाबेस से क्वेरी करता है और आवश्यक जानकारी प्राप्त करता है।

### रियल टाइम कॉन्फ़िगरेशन सेक्शन

रियल-टाइम कॉन्फ़िगरेशन (`extconfig.conf` फ़ाइल का दूसरा भाग) वह जगह है जहाँ लोड किए जाने वाले कॉन्फ़िगरेशन पीस को रियल टाइम में कॉन्फ़िगर, अपडेट और अनलोड किया जाता है। रियल टाइम के साथ, कॉन्फ़िगरेशन को रिलोड करना आवश्यक नहीं है। रियल-टाइम सिंटैक्स इस प्रकार है:

```
<family name> => <driver>,<database name>[,table_name]
```

उदाहरण:

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

यहाँ हमारे पास पाँच कॉन्फ़िगरेशन लाइनें हैं। पहली लाइन में, आप PJSIP/Sorcery फैमिली `ps_endpoints` को `asteriskdb` डेटाबेस में `ps_endpoints` टेबल से बाइंड करते हैं। अंतिम में, आप `voicemail` फैमिली को `asteriskdb` डेटाबेस में `test` टेबल से बाइंड करते हैं। प्रत्येक PJSIP ऑब्जेक्ट प्रकार (endpoint, aor, auth, contact) को अपनी फैमिली और टेबल मिलती है; पूरा सेट नीचे "PJSIP Realtime (Sorcery)" सेक्शन में दिखाया गया है। `voicemail`, `extensions`, `queues`, और `queue_members` फैमिलीज Asterisk 22 में अभी भी मान्य हैं।

## PJSIP Realtime (Sorcery)

Asterisk 22 पर, SIP endpoint को विशेष रूप से **PJSIP** स्टैक (`res_pjsip`) द्वारा नियंत्रित किया जाता है, जो **Sorcery** ऑब्जेक्ट एब्स्ट्रैक्शन लेयर पर निर्मित है। एक एकल SIP "peer" के बजाय, PJSIP एक SIP अकाउंट को कई ऑब्जेक्ट प्रकारों में विभाजित करता है, जिनमें से प्रत्येक को अपनी स्वयं की realtime टेबल में संग्रहीत किया जाता है:

| Sorcery object type | Realtime table | What it holds |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | प्रति-अकाउंट सेटिंग्स (context, codecs, DTMF, आदि) |
| aor (address of record) | ps_aors | पंजीकरण सीमाएं और `qualify` सेटिंग्स |
| auth | ps_auths | `username` / `password` क्रेडेंशियल्स |
| contact | ps_contacts | गतिशील रूप से पंजीकृत स्थान |
| domain alias | ps_domain_aliases | एक endpoint के लिए वैकल्पिक SIP डोमेन |
| endpoint identifier by IP | ps_endpoint_id_ips | स्रोत IP द्वारा एक endpoint का मिलान |

PJSIP के लिए Realtime को दो स्थानों पर सक्षम किया जाता है। सबसे पहले, Sorcery ऑब्जेक्ट प्रकारों को `extconfig.conf` में realtime पर मैप करें:

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

दूसरा, Sorcery को `sorcery.conf` में उन ऑब्जेक्ट प्रकारों के लिए `realtime` विज़ार्ड का उपयोग करने के लिए कहें। मैपिंग नाम (यहाँ `res_pjsip`) वह मॉड्यूल है जिसके ऑब्जेक्ट्स को आप स्थानांतरित कर रहे हैं, और दाईं ओर का मान उस फैमिली की ओर इशारा करता है जिसे आपने `extconfig.conf` में परिभाषित किया है:

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

आप static और realtime ऑब्जेक्ट्स को मिला सकते हैं। यदि आप `sorcery.conf` से किसी प्रकार को छोड़ देते हैं, तो वह ऑब्जेक्ट प्रकार `pjsip.conf` से पढ़ना जारी रखता है। एक सामान्य पैटर्न static ट्रांसपोर्ट और ग्लोबल सेटिंग्स को `pjsip.conf` में रखना है, जबकि endpoints, aors, auths और contacts को डेटाबेस में संग्रहीत करना है।

### Alembic के साथ PJSIP realtime स्कीमा बनाना

Asterisk अपने सभी realtime स्कीमा के लिए डेटाबेस माइग्रेशन `contrib/ast-db-manage` के अंतर्गत प्रदान करता है। PJSIP टेबल बनाने (और वर्ज़न-अपग्रेड करने) का यही समर्थित तरीका है — अब आप स्वयं `ps_*` टेबल परिभाषाएं नहीं लिखते हैं। `config` माइग्रेशन सेट में PJSIP/Sorcery टेबल शामिल हैं।

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

यह चल रहे Asterisk वर्ज़न के लिए सही कॉलम के साथ `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts` और अन्य PJSIP टेबल बनाता है। (Alembic के लिए Python के `alembic` पैकेज के साथ-साथ MySQL/MariaDB के लिए `pymysql` या PostgreSQL के लिए `psycopg2` जैसे SQLAlchemy ड्राइवर की आवश्यकता होती है।)

एक न्यूनतम realtime endpoint में तीन टेबल में से प्रत्येक में एक पंक्ति होती है — उदाहरण के लिए endpoint `6010`:

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

पंक्तियों को डालने के बाद रीलोड करने के लिए कुछ भी नहीं होता है — अगला REGISTER/INVITE डेटाबेस से ऑब्जेक्ट्स को खींच लेता है। आप पुष्टि कर सकते हैं कि realtime ने क्या लौटाया है:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## Database configuration

अब जब हमने extconfig.conf फ़ाइल को कॉन्फ़िगर कर लिया है, तो आइए टेबल बनाते हैं। सामान्य तौर पर, प्रत्येक डेटाबेस कॉलम संबंधित कॉन्फ़िगरेशन फ़ाइल के एक विकल्प नाम (option name) से मेल खाता है। PJSIP `ps_*` टेबल इस नियम का पालन करती हैं: प्रत्येक `ps_endpoints` कॉलम का नाम एक `pjsip.conf` endpoint विकल्प के नाम पर रखा गया है, प्रत्येक `ps_auths` कॉलम का नाम एक auth विकल्प के नाम पर रखा गया है, और इसी तरह। उदाहरण के लिए, नीचे दिया गया `pjsip.conf` endpoint,

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

तीन टेबल में एक पंक्ति (row) के रूप में संग्रहीत होता है। `ps_endpoints` पंक्ति में `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000` होता है; `ps_auths` पंक्ति में `id=4000, auth_type=userpass, username=4000, password=supersecret` होता है; और `ps_aors` पंक्ति में `id=4000, max_contacts=1` होता है। आपको केवल उन कॉलम को भरने की आवश्यकता है जिनका आप वास्तव में उपयोग करते हैं — कोई भी कॉलम जिसे आप NULL छोड़ते हैं, वह विकल्प के डिफ़ॉल्ट मान पर वापस चला जाता है। यदि आप, उदाहरण के लिए, किसी endpoint पर `callerid` पैरामीटर चाहते हैं, तो `ps_endpoints` के `callerid` कॉलम को भरें (कॉलम का नाम `pjsip.conf` विकल्प के नाम के समान ही है)।

एक voicemail टेबल भी इसी विचार का पालन करती है। इसके कॉलम `voicemail.conf` फ़ील्ड्स के साथ मैप होते हैं:

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

`uniqueid` प्रत्येक voicemail उपयोगकर्ता के लिए अद्वितीय (unique) होना चाहिए और यह autoincrement हो सकता है। इसका mailbox या context से कोई संबंध होना आवश्यक नहीं है।

### Building a dial plan using Asterisk Real Time

आप dial plan बनाने के लिए भी real-time सिस्टम का उपयोग कर सकते हैं। ARA, extensions.conf फ़ाइल में निहित सामान्य dial plan में real-time extensions को शामिल करने के लिए `switch` स्टेटमेंट का उपयोग करता है। extension टेबल नीचे दी गई टेबल जैसी दिखनी चाहिए:

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

Asterisk 22 में `extensions` realtime फ़ैमिली अपरिवर्तित है; बस यह सुनिश्चित करें कि `appdata` कॉलम PJSIP चैनलों को डायल करता है, उदाहरण के लिए `PJSIP/4000`। dial plan में, real time का उपयोग करने के लिए आपको `switch` कमांड का उपयोग करना होगा।

![Asterisk Real Time के साथ dial plan बनाना: extensions.conf एक `switch => realtime` स्टेटमेंट का उपयोग करता है ताकि टेक्स्ट फ़ाइल के बजाय डेटाबेस टेबल से extension पंक्तियों (context, exten, priority, app, data) को निकाला जा सके।](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

या

```
[local]
switch => realtime/from-internal@extensions
```

## लैब: डेटाबेस टेबल इंस्टॉल करना और बनाना

इस लैब में, हम Asterisk पैरामीटर्स प्राप्त करने के लिए डेटाबेस तैयार करेंगे। हम केवल REALTIME टेबल तैयार करेंगे। स्टेटिक कॉन्फ़िगरेशन को कॉन्फ़िगरेशन टेक्स्ट फ़ाइलों के लिए छोड़ दिया जाएगा (शानदार है, है ना?)। MySQL में टेबल निर्माण नीचे दिया गया है।

चरण 1: root के रूप में MySQL डेटाबेस में प्रवेश करें।

```
mysql -u root -p
```

चरण 2: CDR लैब में बनाए गए MySQL सर्वर में लॉग इन करें।

```
mysql -u astdb -p
```

जब पासवर्ड पूछा जाए, तो supersecret टाइप करें।

चरण 3: आवश्यक टेबल बनाएं। लेगेसी स्टेटिक स्कीमा फ़ाइलें अभी भी `contrib/realtime/` के अंतर्गत आती हैं (उदाहरण के लिए `/usr/src/asterisk-22.x/contrib/realtime/mysql`), लेकिन Asterisk 22 पर realtime टेबल बनाने का अनुशंसित और संस्करण-सही तरीका — विशेष रूप से PJSIP `ps_*` टेबल के लिए — `contrib/ast-db-manage` के अंतर्गत **Alembic** माइग्रेशन है (ऊपर "Alembic के साथ PJSIP realtime स्कीमा बनाना" अनुभाग देखें)।

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

Alembic `config` माइग्रेशन सेट PJSIP `ps_*` टेबल (`voicemail`, `extensions`, और अन्य realtime स्कीमा के साथ) को बिल्कुल उन कॉलम के साथ बनाता है जिनकी चल रहे Asterisk संस्करण को अपेक्षा होती है, इसलिए स्कीमा हमेशा बिल्ड से मेल खाता है।

पासवर्ड के रूप में supersecret का उपयोग करें।

चरण 4: टेबल के निर्माण को सत्यापित करें।

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

आपको PJSIP `ps_*` टेबल (Alembic `config` माइग्रेशन द्वारा बनाई गई) दिखाई देनी चाहिए, साथ ही `voicemail`, `extensions`, और अन्य realtime टेबल भी:

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

(Alembic इनसे अधिक टेबल बनाता है — ऊपर दी गई सूची उन टेबल को दर्शाती है जो इस लैब के लिए प्रासंगिक हैं।)

चरण 5: डेटाबेस पहले से ही ODBC के लिए कॉन्फ़िगर किया गया है (CDR लैब के बाद से), इसलिए यहाँ किसी और ODBC सेटअप की आवश्यकता नहीं है।

चरण 6: MySQL क्लाइंट से टेबल का निरीक्षण करें और उनमें डेटा भरें। आपको phpMyAdmin जैसे ग्राफिकल टूल की आवश्यकता नहीं है — इस अध्याय का प्रत्येक चरण सरल है, जिसे `mysql` कमांड लाइन से कॉपी-पेस्ट करके SQL चलाया जा सकता है। `astdb` डेटाबेस से कनेक्ट करें (प्रॉम्प्ट मिलने पर `supersecret` का उपयोग करें):

```
mysql -u astdb -p astdb
```

आप किसी भी समय `DESCRIBE` के साथ टेबल के कॉलम की पुष्टि कर सकते हैं, उदाहरण के लिए:

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

ये टेबल Alembic `config` माइग्रेशन द्वारा बनाई गई थीं, इसलिए उनके कॉलम पहले से ही चल रहे Asterisk संस्करण के लिए `pjsip.conf` विकल्प नामों से मेल खाते हैं — आप केवल उन कॉलम को भरें जिनकी आपको आवश्यकता है।

## लैब: ARA को कॉन्फ़िगर और टेस्ट करना

इस लैब में हम अपनी डेटाबेस कॉन्फ़िगरेशन और टेबल्स को दर्शाने के लिए extconfig.conf कॉन्फ़िगरेशन को बदलेंगे।

चरण 1: extconfig.conf को कॉन्फ़िगर करें और Asterisk को रीलोड करें।

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

ऊपर दी गई `ps_endpoints`, `ps_aors`, `ps_auths`, और `ps_contacts` फैमिलीज पर ध्यान दें; मेल खाती हुई `sorcery.conf` मैपिंग्स ( "PJSIP Realtime (Sorcery)" सेक्शन देखें) के साथ मिलकर, ये PJSIP को डेटाबेस से अपने अकाउंट्स पढ़ने में सक्षम बनाती हैं। `voicemail` और `extensions` फैमिलीज इस उदाहरण को पूरा करती हैं।

चरण 2: Real Time एक्सटेंशन टेस्ट। `ps_auths`, `ps_aors`, और `ps_endpoints` में से प्रत्येक में एक रो (row) डालकर एक नया `6010` endpoint बनाएं, फिर इस endpoint को एक softphone के साथ रजिस्टर करने का प्रयास करें। `mysql` क्लाइंट (`mysql -u astdb -p astdb`) में निम्नलिखित SQL चलाएँ:

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

ये तीन रो मिलकर एक SIP अकाउंट का वर्णन करती हैं। बाकी अकाउंट सेटिंग्स PJSIP ऑब्जेक्ट्स में फैली हुई हैं: context, codecs, DTMF मोड, और मीडिया हैंडलिंग endpoint पर रहते हैं (ऊपर के अंतिम छह कॉलम); डायनामिक रजिस्ट्रेशन AOR पर रहता है। इसमें कोई अलग "dynamic" फ्लैग नहीं है — एक AOR डायनामिक REGISTERs को तब तक स्वीकार करता है जब तक `max_contacts` शून्य से अधिक है, और प्रत्येक रजिस्टर्ड लोकेशन को `ps_contacts` में लिखा जाता है।

PJSIP में RFC 2833 / RFC 4733 आउट-ऑफ-बैंड DTMF मोड का नाम `rfc4733` है, और `dtmf_mode=rfc4733` डिफ़ॉल्ट है — इसलिए ऊपर दिया गया `dtmf_mode` कॉलम वैकल्पिक है और केवल स्पष्टता के लिए दिखाया गया है।

चरण 3: username `6010` और password `supersecret` का उपयोग करके softphone के साथ नए फोन को रजिस्टर करने का प्रयास करें। Asterisk CLI पर रजिस्ट्रेशन की पुष्टि करें:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

चरण 4: डेटाबेस में extensions को शामिल करें।

```
mysql -u astdb -p
```

पासवर्ड दर्ज करें:

पूछे जाने पर supersecret का उपयोग करें, फिर MySQL क्लाइंट से एक्सटेंशन रो डालें:

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

चरण 5: dialplan में Asterisk Real Time को शामिल करें। context `default` में:

```
switch => realtime/test@extensions
```

बदलाव को सक्रिय करने के लिए extensions को रीलोड करें।

```
asterisk-server*CLI> extensions reload
```

चरण 6: यदि आपने पहले से ऐसा नहीं किया है, तो फोन में से एक को username `bria` पर रीकॉन्फ़िगर करें।

चरण 7: किसी मौजूदा फोन से 6007 डायल करें; `bria` फोन बजना चाहिए।

## सारांश

इस अध्याय में, आपने सीखा कि Asterisk Real Time आपको अपने कॉन्फ़िगरेशन को डेटाबेस में रखने की अनुमति देता है। Asterisk में ODBC (जो MySQL/MariaDB और SQLite सहित किसी भी UnixODBC-समर्थित डेटाबेस तक पहुँचता है) और PostgreSQL के लिए नेटिव realtime ड्राइवर, साथ ही डायरेक्टरी बैकएंड के लिए एक LDAP realtime ड्राइवर शामिल हैं। MySQL/MariaDB तक ODBC के माध्यम से पहुँचा जाता है, जैसा कि हमने इस अध्याय में किया (एक समर्पित `res_config_mysql` ऐड-ऑन भी मौजूद है, लेकिन यह कोर बिल्ड के बाहर रहता है, इसलिए ODBC ही सामान्य मार्ग है)। कॉन्फ़िगरेशन को स्टैटिक और real time में विभाजित किया गया है। स्टैटिक कॉन्फ़िगरेशन कॉन्फ़िगरेशन फ़ाइलों की जगह लेता है, जबकि real-time कॉन्फ़िगरेशन ऐसे डायनामिक ऑब्जेक्ट बनाता है जो केवल तब लोड होते हैं जब कोई कॉल या अन्य संबंधित घटना होती है। हमने ARA को इंस्टॉल और कॉन्फ़िगर करने के तरीके पर एक व्यावहारिक लैब के साथ समापन किया।

## प्रश्नोत्तरी

1. Asterisk Realtime मानक Asterisk वितरण का हिस्सा है।
   - A. सत्य
   - B. असत्य
2. डेटाबेस सर्वर के कनेक्शन पैरामीटर किस फ़ाइल में कॉन्फ़िगर किए जाते हैं:
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. `extconfig.conf` फ़ाइल Realtime द्वारा उपयोग की जाने वाली तालिकाओं को कॉन्फ़िगर करती है। इसके दो अलग-अलग भाग हैं (दो चुनें):
   - A. Static configuration
   - B. Realtime configuration
   - C. Outbound routes
   - D. IP addresses and database ports
4. Static configuration में, एक बार जब ऑब्जेक्ट्स को डेटाबेस से लोड कर लिया जाता है, तो वे Asterisk की मेमोरी में रहते हैं और केवल स्टार्ट या रीलोड होने पर ही रिफ्रेश होते हैं।
   - A. सत्य
   - B. असत्य
5. PJSIP realtime (Sorcery) पूरी तरह से `qualify` और realtime endpoints के लिए MWI का समर्थन करता है, क्योंकि Sorcery उन्हें प्रत्येक कॉल के बाद पुराने SIP realtime peers की तरह हटाने के बजाय सामान्य कॉन्फ़िगर किए गए PJSIP ऑब्जेक्ट्स के रूप में लोड करता है।
   - A. सत्य
   - B. असत्य
6. PJSIP realtime में, कौन सी तालिकाएं endpoints और उनके पंजीकृत contacts को रखती हैं?
   - A. `ps_endpoints` और `ps_contacts`
   - B. `ps_peers` और `ps_registry`
   - C. `ps_config` और `ps_data`
   - D. `extconfig` और `res_odbc`
7. ARA सक्षम करने के बाद भी आप टेक्स्ट कॉन्फ़िगरेशन फ़ाइलों का उपयोग कर सकते हैं।
   - A. सत्य
   - B. असत्य
8. Realtime का उपयोग करते समय phpMyAdmin अनिवार्य है।
   - A. सत्य
   - B. असत्य
9. डेटाबेस को कॉन्फ़िगरेशन फ़ाइल में मौजूद प्रत्येक फ़ील्ड के साथ बनाया जाना चाहिए।
   - A. सत्य
   - B. असत्य
10. Asterisk 22 पर, PJSIP realtime तालिकाएं (`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`) बनाने का अनुशंसित, संस्करण-सही तरीका क्या है?
    - A. प्रत्येक `ps_*` तालिका के लिए `CREATE TABLE` स्टेटमेंट हाथ से लिखें
    - B. `contrib/realtime/` से लेगेसी `mysql_config.sql` आयात करें
    - C. `contrib/ast-db-manage` (`alembic -c config.ini upgrade head`) के अंतर्गत Alembic `config` माइग्रेशन चलाएं
    - D. Asterisk के पहली बार स्टार्ट होने पर तालिकाएं अपने आप बन जाती हैं

**उत्तर:** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
