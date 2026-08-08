# PJSIP के साथ अपना पहला PBX बनाना

इस अध्याय में, आप सीखेंगे कि बुनियादी Asterisk PBX कॉन्फ़िगरेशन कैसे किया जाता है। यहाँ मुख्य उद्देश्य PBX को पहली बार चलते हुए देखना, extension के बीच कॉल करना, एक संदेश को डायल करके सुनना, और एक सिंगल एनालॉग या SIP trunk पर डायल करने में सक्षम होना है। इस अध्याय के पीछे का विचार यह सुनिश्चित करना है कि आपका Asterisk जल्द से जल्द चालू हो जाए। इस अध्याय में कार्य पूरा करने के बाद, आपके पास बाद के अध्यायों की तैयारी के लिए पर्याप्त पृष्ठभूमि होगी, जहाँ हम कॉन्फ़िगरेशन के विवरणों में गहराई से उतरेंगे।

## Objectives

इस अध्याय के अंत तक, आप निम्नलिखित कार्य करने में सक्षम होंगे:

- कॉन्फ़िगरेशन फ़ाइलों को समझना और संपादित करना;
- SIP पर आधारित softphone इंस्टॉल करना;
- एक SIP trunk इंस्टॉल और कॉन्फ़िगर करना;
- एक एनालॉग कनेक्शन इंस्टॉल और कॉन्फ़िगर करना;
- extensions के बीच कॉल करना;
- फ़ोन और बाहरी गंतव्यों के बीच कॉल करना; और
- एक auto attendant कॉन्फ़िगर करना।

## कॉन्फ़िगरेशन फ़ाइलों को समझना

Asterisk को /etc/asterisk में स्थित टेक्स्ट कॉन्फ़िगरेशन फ़ाइलों द्वारा नियंत्रित किया जाता है। फ़ाइल का प्रारूप Windows की “.ini” फ़ाइलों के समान है। एक सेमीकोलन (semicolon) का उपयोग टिप्पणी वर्ण के रूप में किया जाता है, “=” और “=>” चिह्न समान हैं, और स्पेस (spaces) को अनदेखा कर दिया जाता है।

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asterisk “=” और “=>” की व्याख्या एक ही तरह से करता है। सिंटैक्स में अंतर का उपयोग ऑब्जेक्ट्स और वेरिएबल्स के बीच अंतर करने के लिए किया जाता है। जब आप कोई वेरिएबल घोषित करना चाहते हैं तो “=” का उपयोग करें और किसी ऑब्जेक्ट को निर्दिष्ट करने के लिए “=>” का उपयोग करें। सभी फ़ाइलों के बीच सिंटैक्स समान है, लेकिन नीचे चर्चा किए गए अनुसार तीन प्रकार के व्याकरण का उपयोग किया जाता है।

## Grammars

| Grammar | How the object is created | Conf. file | Example |
|---------|---------------------------|------------|---------|
| Simple Group | सभी एक ही पंक्ति में | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| Option Inheritance | विकल्प पहले परिभाषित किए जाते हैं, ऑब्जेक्ट विकल्पों को इनहेरिट करता है | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| Complex Entity | प्रत्येक एंटिटी को एक context प्राप्त होता है | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### Simple Group

`extensions.conf` और `voicemail.conf` में उपयोग किया जाने वाला simple group प्रारूप सबसे बुनियादी grammar है। प्रत्येक ऑब्जेक्ट को एक ही पंक्ति में विकल्पों के साथ घोषित किया जाता है। उदाहरण:

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

इस उदाहरण में, object 1 को op1, op2, और op3 विकल्पों के साथ बनाया गया है, जबकि object 2 को op1, op2, और op3 विकल्पों के साथ बनाया गया है।

### Object options inheritance grammar

यह प्रारूप chan_dahdi.conf और agents.conf फाइलों द्वारा उपयोग किया जाता है, जहाँ कई विकल्प उपलब्ध होते हैं, और अधिकांश इंटरफेस और ऑब्जेक्ट समान विकल्पों को साझा करते हैं। आमतौर पर, एक या अधिक सेक्शन में ऑब्जेक्ट और चैनल घोषणाएं होती हैं। ऑब्जेक्ट के विकल्प ऑब्जेक्ट के ऊपर घोषित किए जाते हैं और उन्हें किसी अन्य ऑब्जेक्ट के लिए बदला जा सकता है। हालाँकि इस अवधारणा को समझना कठिन है, लेकिन इसका उपयोग करना बहुत आसान है। उदाहरण:

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

पहली दो पंक्तियाँ op1 और op2 विकल्पों के मान को क्रमशः “bas” और “adv” के रूप में कॉन्फ़िगर करती हैं। जब object 1 को इंस्टेंस किया जाता है, तो इसे option 1 को “bas” और option 2 को “adv” के रूप में उपयोग करके बनाया जाता है। object 1 को परिभाषित करने के बाद, हम option 1 को बदलकर “int” कर देते हैं। इसके बाद, हम object 2 को option 1 के “int” और option 2 के “adv” मान के साथ बनाते हैं।

### Complex entity object

यह प्रारूप pjsip.conf, iax.conf, और अन्य कॉन्फ़िगरेशन फाइलों द्वारा उपयोग किया जाता है जिनमें कई विकल्पों वाली अनेक एंटिटी मौजूद होती हैं। आमतौर पर, यह प्रारूप सामान्य कॉन्फ़िगरेशन की बड़ी मात्रा को साझा नहीं करता है। प्रत्येक एंटिटी को एक context प्राप्त होता है। कभी-कभी आरक्षित context मौजूद होते हैं, जैसे वैश्विक कॉन्फ़िगरेशन के लिए [general]। विकल्प context घोषणाओं में घोषित किए जाते हैं। उदाहरण:

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

एंटिटी [entity1] में op1 और op2 विकल्पों के लिए क्रमशः “value1” और “value2” मान हैं। एंटिटी [entity2] में op1 और op2 विकल्पों के लिए “value3” और “value4” मान हैं।

## Asterisk के लिए LAB बनाने के विकल्प

एक PBX को कॉन्फ़िगर करने के लिए, आपको कुछ बुनियादी हार्डवेयर की आवश्यकता होगी। यह कठिन या महंगा नहीं है, लेकिन कुछ विकल्प हैं जिन पर विचार किया जाना चाहिए। आपको केवल दो फोन और सार्वजनिक नेटवर्क से एक कनेक्शन की आवश्यकता होगी। अपना LAB बनाते समय कुछ विकल्प और संयोजन संभव हैं, जिन पर हम नीचे चर्चा करेंगे।

### विकल्प 1: पूर्ण LAB

पूर्ण LAB के साथ, उपलब्ध सभी परिदृश्यों का परीक्षण करना और ATA, IP-phones, और softphones जैसे समाधानों की तुलना करना संभव है। आप analog और SIP trunks के बारे में भी सीख सकते हैं। आपको इनकी आवश्यकता होगी:

- एक SIP analog telephone adapter (ATA)
- एक IP phone
- Asterisk के लिए एक समर्पित सर्वर
- softphone के साथ एक वर्कस्टेशन
- कम से कम दो इंटरफेस (1 FXO और 1 FXS) वाला एक analog interface card
- एक VoIP provider खाता

### विकल्प 2: किफायती LAB

किफायती LAB के साथ, हम इसे थोड़ा सरल बनाते हैं। हम ATA का उपयोग करते हैं, जो आमतौर पर IP-phone से सस्ता होता है, और एक एकल FXO कार्ड, जो वास्तव में सस्ता होता है। हम सीधे सर्वर से जुड़े analog phones का उपयोग करने में सक्षम नहीं होंगे, लेकिन व्यवहार में ऐसा आमतौर पर नहीं होता है। आपको इनकी आवश्यकता होगी:

- एक SIP analog telephone adapter (ATA)
- Asterisk के लिए एक समर्पित सर्वर
- softphone के लिए एक वर्कस्टेशन
- 1 FXO वाला एक analog interface card
- एक VoIP provider के साथ एक खाता

### विकल्प 3: सुपर किफायती LAB

तीसरा LAB छात्र के अपने नोटबुक में वर्चुअलाइज्ड सर्वर का उपयोग करता है। इस मॉडल के साथ समस्या UDP पोर्ट द्वारा उत्पन्न संघर्ष है। कभी-कभी Asterisk सर्वर और softphone दोनों एक ही पोर्ट तक पहुंचने का प्रयास करते हैं, जिससे Asterisk को एड्रेस पोर्ट बाइंड करने से रोका जाता है। एक और मुद्दा कॉल की गुणवत्ता है; वर्चुअल वातावरण Asterisk जैसे real-time अनुप्रयोगों के लिए उपयुक्त नहीं हैं। सर्वर और वर्कस्टेशन के लिए एक मुफ्त softphone और एक SIP provider के लिए trunk कनेक्शन का उपयोग करें। आपको इनकी आवश्यकता होगी:

- softphone चलाने वाला एक लैपटॉप
- Asterisk इंस्टॉल करने के लिए एक वर्चुअल मशीन (VirtualBox, VMware, या समान)
- एक VoIP provider के साथ एक खाता

## इंस्टॉलेशन अनुक्रम

इंस्टॉलेशन अनुक्रम को समझने में आपकी सहायता के लिए, हमने Asterisk को इंस्टॉल और कॉन्फ़िगर करने के लिए आवश्यक चरणों का क्रम रेखांकित किया है।

![संदर्भ लैब लेआउट: SIP/IAX सॉफ्टफ़ोन, एक IP फ़ोन और एनालॉग एडेप्टर एक्सटेंशन (1) के रूप में, ETH0/FXO/FXS इंटरफ़ेस (3) के साथ Asterisk सर्वर, और VoIP प्रदाता या ब्रॉडबैंड लिंक (2) के माध्यम से PSTN के लिए ट्रंक।](../images/04-first-pbx-fig01.png)

1. एक्सटेंशन कॉन्फ़िगरेशन
   - a. SIP एक्सटेंशन (ATA, Softphone, IP Phone)
   - b. IAX एक्सटेंशन
   - c. FXS एक्सटेंशन
2. ट्रंक कॉन्फ़िगरेशन
   - a. SIP ट्रंक का कॉन्फ़िगरेशन
   - b. FXO ट्रंक का कॉन्फ़िगरेशन
3. एक बुनियादी dialplan बनाना
   - a. एक्सटेंशन के बीच डायल करना
   - b. बाहरी गंतव्यों पर डायल करना
   - c. ऑपरेटर एक्सटेंशन में कॉल प्राप्त करना
   - d. ऑटो-अटेंडेंट में कॉल प्राप्त करना

## extensions का कॉन्फ़िगरेशन

extensions वे SIP, IAX, या एनालॉग फोन हैं जो FXS पोर्ट से जुड़े होते हैं। एक extension को कॉन्फ़िगर करने के लिए, आपको चैनल से संबंधित कॉन्फ़िगरेशन फ़ाइल (pjsip.conf, iax.conf, chan_dahdi.conf) को संपादित करना चाहिए।

### SIP extensions

Asterisk 22 पर, PJSIP (`res_pjsip` स्टैक, जिसे `/etc/asterisk/pjsip.conf` में कॉन्फ़िगर किया गया है) SIP चैनल ड्राइवर है। यह प्रति endpoint कई transports का समर्थन करता है, सक्रिय रूप से मेंटेन किया जाता है, और यह एकमात्र SIP ड्राइवर है जो इस प्लेटफ़ॉर्म के साथ आता है। (मूल `chan_sip` ड्राइवर को Asterisk 21 में हटा दिया गया था — यदि आपको पुराने कॉन्फ़िगरेशन को माइग्रेट करने की आवश्यकता है, तो *Legacy channels* अध्याय देखें।)

यहाँ विचार एक साधारण PBX को कॉन्फ़िगर करना है। (बाद के अध्याय सभी विवरणों के साथ एक संपूर्ण SIP/PJSIP सत्र प्रदान करते हैं।) PJSIP को `/etc/asterisk/pjsip.conf` में कॉन्फ़िगर किया जाता है और इसमें SIP फोन और VoIP प्रदाताओं से संबंधित सभी पैरामीटर होते हैं। कॉल करने और प्राप्त करने से पहले SIP क्लाइंट्स को कॉन्फ़िगर करना आवश्यक है।

#### transport

PJSIP में, लिसनर कॉन्फ़िगरेशन (bind एड्रेस, पोर्ट, प्रोटोकॉल) एक `transport` ऑब्जेक्ट में रहता है। Asterisk में यूज़रनेम का अनुमान लगाने के खिलाफ इन-बिल्ट सुरक्षा है — यह अज्ञात और ज्ञात उपयोगकर्ताओं के लिए हमेशा एक समान प्रमाणीकरण चुनौती (authentication challenge) लौटाता है, और एक ही IP से बार-बार आने वाले अज्ञात अनुरोधों को `[global]` विकल्पों `unidentified_request_count`/`unidentified_request_period` के माध्यम से दर-सीमित (rate-limited) किया जाता है। एक transport के मुख्य विकल्प हैं:

- protocol: transport प्रोटोकॉल — `udp`, `tcp`, `tls`, `ws`, या `wss`।
- bind: वह एड्रेस और पोर्ट जिससे लिसनर बाइंड होता है। यदि आप एड्रेस को `0.0.0.0` पर सेट करते हैं, तो यह सभी इंटरफेस से बाइंड हो जाता है; SIP पोर्ट UDP/TCP के लिए डिफ़ॉल्ट रूप से 5060 होता है।

एक न्यूनतम UDP transport:

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

Codec चयन (`disallow`/`allow`) और डिफ़ॉल्ट `context` को प्रत्येक `endpoint` (नीचे दिखाया गया है) पर कॉन्फ़िगर किया जाता है, न कि transport पर। Anonymous/guest कॉल्स को `anonymous` नामक एक `endpoint` द्वारा संभाला जाता है। रजिस्ट्रेशन टाइमर को प्रति-AOR `maximum_expiration`/`default_expiration` के माध्यम से नियंत्रित किया जाता है।

#### SIP क्लाइंट्स

transport अनुभाग को पूरा करने के बाद, अब SIP क्लाइंट्स को सेट करने का समय है। मैं एक बार फिर पाठक को याद दिलाना चाहूंगा कि पुस्तक में बाद में हमारे पास एक पूरा SIP/PJSIP अध्याय होगा। अभी के लिए, आइए मूल बातों पर ध्यान केंद्रित करें और विवरणों को बाद के लिए छोड़ दें।

PJSIP में एक SIP क्लाइंट संबंधित ऑब्जेक्ट्स के एक सेट से बनता है, जो नाम संदर्भ द्वारा एक साथ जुड़े होते हैं:

- `endpoint`: कॉल व्यवहार — codecs (`allow`/`disallow`), dialplan `context`, और यह किन `auth` और `aors` का उपयोग करता है।
- `auth`: क्रेडेंशियल्स। `username` SIP प्रमाणीकरण उपयोगकर्ता है और `password` डिवाइस को प्रमाणित करने के लिए उपयोग किया जाने वाला गुप्त पासवर्ड है।
- `aor`: "address of record" — जहाँ तक endpoint पहुँचा जा सकता है। या तो एक स्थिर `contact=` (एक निश्चित IP वाले डिवाइस के लिए) या `max_contacts=` ताकि डिवाइस को गतिशील रूप से रजिस्टर करने की अनुमति मिल सके।

चेतावनी: कम से कम 8 वर्णों वाले मजबूत पासवर्ड का उपयोग करें, जिसमें अल्फ़ान्यूमेरिक और संख्यात्मक वर्ण हों, और कम से कम एक प्रतीक हो। मेलिंग सूचियों में हैक किए गए सर्वरों की रिपोर्ट सामने आई है, और SIP के लिए ब्रूट फोर्स पासवर्ड क्रैकर्स स्क्रिप्ट किडीज़ के लिए आसानी से उपलब्ध हैं। टोल धोखाधड़ी से उपभोक्ताओं और प्रदाताओं को हजारों डॉलर का नुकसान होता है।

Endpoint 6000 एक निश्चित IP वाला डिवाइस है, इसलिए इसका AOR रजिस्ट्रेशन की अनुमति देने के बजाय एक स्थिर `contact` रखता है। Endpoint 6001 एक ऐसा डिवाइस है जो रजिस्टर करता है, इसलिए इसका AOR इसे रजिस्टर करने की अनुमति देता है (`max_contacts=1`):

```
[6000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6000-auth
aors=6000

[6000-auth]
type=auth
auth_type=digest
username=6000
password=#MySecret1#7

[6000]
type=aor
contact=sip:6000@10.1.30.50

[6001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6001-auth
aors=6001

[6001-auth]
type=auth
auth_type=digest
username=6001
password=Mys3cr3t#

[6001]
type=aor
max_contacts=1
```

PJSIP `endpoint`, `auth`, और `aor` अनुभागों को एक ही अनुभाग नाम साझा करने की अनुमति देता है (उदाहरण के लिए ऊपर दिए गए दो `[6001]` ब्लॉक, जो उनके `type=` द्वारा अलग किए गए हैं); कई एडमिन पठनीयता के लिए उन्हें प्रत्यय (suffix) देते हैं (`[6001]`, `[6001-auth]`, `[6001]` aor)। जो डिवाइस रजिस्टर करता है, उसके लिए संपर्क (contact) तब गतिशील रूप से सीखा जाता है जब फोन रजिस्टर होता है, इसलिए AOR को किसी स्थिर `contact` की आवश्यकता नहीं होती है।

## IAX Extensions

`chan_iax2` अभी भी Asterisk 22 के साथ आता है लेकिन अब यह लेगेसी (legacy) है; नए डिप्लॉयमेंट के लिए SIP/PJSIP पसंदीदा प्रोटोकॉल है।

आप IAX extensions भी बना सकते हैं। यह प्रोटोकॉल Asterisk के लिए नेटिव है, और इस पुस्तक में बाद में हम इसके लिए एक पूरा सेक्शन समर्पित करेंगे। अभी के लिए, आइए इस प्रोटोकॉल का उपयोग करके कुछ extensions बनाते हैं। कॉन्फ़िगर किए जाने वाले पहले सेक्शन के रूप में, [general] सेक्शन में कुछ पैरामीटर्स कॉन्फ़िगर किए जाने होते हैं। मुख्य विकल्प इस प्रकार हैं:

- allow/disallow: यह परिभाषित करता है कि किन codecs का उपयोग किया जाएगा।
- bindaddr: वह पता जिस पर IAX2 लिसनर बाइंड होता है। यदि आप इसे 0.0.0.0 (डिफ़ॉल्ट) के रूप में सेट करते हैं, तो यह सभी इंटरफ़ेस पर बाइंड हो जाएगा।
- context: क्लाइंट सेक्शन में बदले जाने तक सभी क्लाइंट्स के लिए डिफ़ॉल्ट context सेट करता है। हमने सुरक्षा कारणों से dummy का उपयोग किया है। जब allowguest विकल्प को yes पर सेट किया जाता है, तो अनधिकृत उपयोगकर्ता इस context में आ जाते हैं।
- bindport: IAX2 UDP पोर्ट जिस पर लिसन करना है (डिफ़ॉल्ट 4569)।
- delayreject: जब इसे yes पर सेट किया जाता है, तो यह REGREQ या AUTHREQ के लिए ऑथेंटिकेशन रिजेक्ट भेजने में देरी करता है, जो ब्रूट-फोर्स पासवर्ड हमलों के खिलाफ सुरक्षा में सुधार करता है।
- bandwidth: जब इसे high पर सेट किया जाता है, तो यह उच्च बैंडविड्थ वाले codecs के चयन की अनुमति देता है, जैसे कि उनके वेरिएंट ulaw और alaw में g711।

iax.conf फ़ाइल के [general] सेक्शन का एक नमूना नीचे दिया गया है।

```
[general]
bindport = 4569
bindaddr = 10.1.30.45 ;(use your IP)
context = dummy
delayreject=yes
bandwidth=high
disallow = all
allow = ulaw
```

### IAX Clients

general सेक्शन पूरा करने के बाद, अब IAX clients को सेट अप करने का समय है।

- `[name]`: सेक्शन का नाम IAX पीयर/यूज़र का नाम है; एक इनकमिंग IAX कनेक्शन का मिलान नाम के आधार पर इससे किया जाता है।
- `type`: कनेक्शन क्लास — `peer`, `user`, या `friend`:
  - `peer`: Asterisk एक पीयर को कॉल भेजता है।
  - `user`: Asterisk एक यूज़र से कॉल प्राप्त करता है।
  - `friend`: दोनों दिशाओं में एक साथ।
- `host`: IP पता या होस्ट नाम। सबसे सामान्य मान `dynamic` है, जिसका उपयोग तब किया जाता है जब डिवाइस Asterisk पर रजिस्टर होता है।
- `secret`: पीयर्स और यूज़र्स को ऑथेंटिकेट करने के लिए पासवर्ड।

चेतावनी: कम से कम 8 वर्णों, अल्फ़ान्यूमेरिक और संख्यात्मक वर्णों, और कम से कम एक प्रतीक वाले मज़बूत पासवर्ड का उपयोग करें। मेलिंग लिस्ट में हैक किए गए सर्वर्स की रिपोर्ट सामने आई हैं, और IAX md5 हैश के लिए ब्रूट फोर्स पासवर्ड क्रैकर्स स्क्रिप्ट किडीज़ के लिए उपलब्ध हैं। टोल फ्रॉड (toll fraud) उपभोक्ताओं और प्रदाताओं के लिए हज़ारों डॉलर का नुकसान करा सकता है। उदाहरण:

```
[guest]
type=user
context=dummy
callerid="Guest IAX User"
[6003]
type=friend
context=from-internal
secret=#sup3rs3cr3t#
host=dynamic
[6004]
type=friend
context=from-internal
secret=#s3cr3ts3cr3t#
host=dynamic
```

## SIP डिवाइसेस को कॉन्फ़िगर करना

Asterisk कॉन्फ़िगरेशन फ़ाइल में फ़ोन को परिभाषित करने के बाद, अब फ़ोन को स्वयं कॉन्फ़िगर करने का समय है। इस उदाहरण में, हम दिखाएंगे कि एक मुफ्त softphone — SipPulse Softphone (इसे https://www.sippulse.com/produtos/softphone से डाउनलोड करें) को कैसे कॉन्फ़िगर किया जाए। अपने फ़ोन के पैरामीटर्स को समझने के लिए अपने डिवाइस के मैनुअल की जाँच करें। चरण 1: फ़ोन को extension 6000 का उपयोग करने के लिए कॉन्फ़िगर करें। इंस्टॉलेशन प्रोग्राम को निष्पादित करें। निष्पादन के बाद, account/SIP सेटिंग्स खोलें और एक नया SIP अकाउंट जोड़ें। आवश्यक जानकारी भरें।

![SipPulse Softphone अकाउंट स्क्रीन — सर्वर (आपका Asterisk IP या डोमेन), Username, Password, और Display Name दर्ज करें, फिर Transport (UDP, TCP, या TLS) चुनें।](../images/softphone/sipphone-account.png){width=35%}

Display Name: 6000  User Name: 6000  Password: #MySecret1#7  Authorization User Name: 6000  Domain: ip_of_your_server. पुष्टि करें कि आपका फ़ोन कंसोल कमांड `pjsip show endpoints` (या विवरण के लिए `pjsip show endpoint 6000`; `pjsip show contacts` पंजीकृत AOR कॉन्टैक्ट्स दिखाता है) का उपयोग करके पंजीकृत है। फ़ोन 6001 के लिए कॉन्फ़िगरेशन दोहराएं।

![एक पंजीकृत SipPulse Softphone — हरा बिंदु और अकाउंट लाइन (`1001@softphone.sippulse.com.br`) पंजीकरण की पुष्टि करते हैं; कीपैड या कॉल/वीडियो बटन से कॉल करें।](../images/softphone/sipphone-registered.png){width=35%}

## IAX डिवाइस को कॉन्फ़िगर करना

IAX2 एक पुराना प्रोटोकॉल है (*Legacy channels* अध्याय देखें), और SipPulse Softphone केवल SIP-आधारित है, इसलिए यह IAX अकाउंट को रजिस्टर नहीं कर सकता है। यदि आपको IAX2 का परीक्षण करने की आवश्यकता है, तो ऐसे softphone का उपयोग करें जो अभी भी इसका समर्थन करता हो। एक नया IAX अकाउंट बनाएं,

3. नया IAX अकाउंट चुनें।
4. 6003 फोन के लिए संबंधित विकल्प डालें और वैकल्पिक रूप से 6004 के लिए भी।
5. कॉन्फ़िगरेशन को सेव करें और जांचें कि क्या फोन `iax2 show peers` का उपयोग करके रजिस्टर हो गया है।

महत्वपूर्ण: SIP के लिए एक अकाउंट और IAX के लिए दूसरा अकाउंट उपयोग करें। यदि आप सिस्टम को इस तरह कॉन्फ़िगर करना चाहते हैं कि IAX और SIP दोनों पर एक ही समय में रिंग बजे, तो हम आपको dialplan अनुभाग में दिखाएंगे कि ऐसा कैसे करना है।

### PSTN इंटरफ़ेस को कॉन्फ़िगर करना

PSTN से कनेक्ट करने के लिए, आपको एक इंटरफ़ेस foreign exchange office (FXO) और एक टेलीफोन लाइन की आवश्यकता होगी। आप मौजूदा PBX extension का भी उपयोग कर सकते हैं। आप कई निर्माताओं से FXO इंटरफ़ेस वाला टेलीफोनी इंटरफ़ेस कार्ड प्राप्त कर सकते हैं। इस उदाहरण में, हम आपको दिखाएंगे कि DAHDI इंटरफ़ेस कार्ड कैसे इंस्टॉल किया जाए।

![FXS और FXO पोर्ट: FXS पोर्ट एक एनालॉग फोन को चलाता है (डायल टोन और रिंग प्रदान करता है), जबकि FXO पोर्ट Asterisk को Telco लाइन से जोड़ता है।](../images/04-first-pbx-fig02.png)

### DAHDI का उपयोग करके एनालॉग लाइनें

आप कई निर्माताओं से DAHDI के साथ संगत एनालॉग कार्ड खरीद सकते हैं। X100P पहले Digium कार्डों में से एक था और इसे बंद कर दिया गया है। कुछ निर्माता अभी भी समान क्लोन का उत्पादन करते हैं। X100P की कीमत के अलावा, हमने इन कार्डों और नए मदरबोर्ड के बीच कई समस्याएं पाई हैं, इसलिए इसका सावधानी से उपयोग करें। मेरी राय में, X100P प्रोडक्शन वातावरण के लिए एक अच्छा विकल्प नहीं है। DAHDI के साथ संगत कोई भी कार्ड काम करना चाहिए। DAHDI डेवलपर्स की टीम को धन्यवाद, हमारे पास अब इंटरफ़ेस कार्ड को लगभग स्वचालित रूप से पहचानने और कॉन्फ़िगर करने के लिए एक टूल है। यदि आपने अभी-अभी DAHDI ड्राइवर इंस्टॉल किए हैं, तो कृपया make config चलाना न भूलें और इसे स्वचालित रूप से लोड करने के लिए मशीन को रीबूट करें। आप अपने कार्ड का पता लगाने और उसे कॉन्फ़िगर करने के लिए नीचे दिए गए कमांड का उपयोग कर सकते हैं। चरण 1: अपने हार्डवेयर का पता लगाने के लिए, उपयोग करें:

```
dahdi_hardware
```

चरण 2: कॉन्फ़िगर करने के लिए उपयोग करें:

```
dahdi_genconf
```

उपरोक्त कमांड दो फाइलें /etc/dahdi/system.conf और /etc/asterisk/dahdi-channels.conf उत्पन्न करेगा। dahdi_genconf के लिए डिफ़ॉल्ट पैरामीटर आमतौर पर ठीक होते हैं, लेकिन आप उन्हें /etc/dahdi/genconf_parameters फाइल में बदल सकते हैं। डिफ़ॉल्ट रूप से, यह लाइनों (FXO) को context from-pstn में और फोन (FXS) को context from-internal में डालेगा। चरण 3: dahdi_genconf चलाने के बाद, /etc/asterisk/chan_dahdi.conf फाइल की अंतिम पंक्ति में निम्नलिखित पंक्ति डालें:

```
#include dahdi-channels.conf
```

चरण 4: /etc/dahdi/modules फाइल को एडिट करें और सभी अप्रयुक्त ड्राइवरों के लिए कमेंट करें। आगे बढ़ने से पहले रीबूट करें और जांचें कि क्या चैनल ```
*CLI> dahdi show channels
``` का उपयोग करके पहचाने जा रहे हैं।

### VoIP प्रदाता का उपयोग करके PSTN से कनेक्ट करना

यदि आपका बजट वास्तव में सीमित है, तो आप PSTN से कनेक्ट करने के लिए एक SIP trunk कॉन्फ़िगर कर सकते हैं। यह निश्चित रूप से PSTN से कनेक्ट करने का सबसे किफायती तरीका है। दुनिया भर में हजारों VoIP प्रदाता मौजूद हैं। उनमें से किसी एक से कनेक्ट करने के लिए, आपको कुछ पैरामीटर्स की आवश्यकता होगी। SIP प्रदाता द्वारा प्रदान किए गए पैरामीटर्स।

- username: login
- password: secret
- Provider’s domain: domain
- UDP port: 5060
- Allowed codecs: g729, ilbc, alaw

दो पैरामीटर्स आपके द्वारा निर्धारित किए जाने चाहिए।

- कॉल प्राप्त करने के लिए extension—इस मामले में: 9999
- context: from-sip

PJSIP में, एक रजिस्टर होने वाला SIP trunk उसी ऑब्जेक्ट परिवार से बनाया जाता है जिसका उपयोग endpoint के लिए किया जाता है, साथ ही स्पष्ट `registration` और `identify` ऑब्जेक्ट्स का उपयोग किया जाता है। `registration` ऑब्जेक्ट Asterisk को प्रदाता के पास रजिस्टर करने के लिए कहता है, `identify` ऑब्जेक्ट प्रदाता के IP से आने वाले ट्रैफ़िक को endpoint से मिलाता है (PJSIP सोर्स IP द्वारा इनबाउंड INVITEs को प्रमाणित करता है), और `outbound_auth` आउटबाउंड कॉल और पंजीकरण के लिए क्रेडेंशियल्स प्रदान करता है:

```
[siptrunk]
type=endpoint
context=from-sip
disallow=all
allow=ilbc
allow=alaw
allow=g729
dtmf_mode=rfc4733
outbound_auth=siptrunk-auth
aors=siptrunk
from_user=login
from_domain=domain

[siptrunk-auth]
type=auth
auth_type=digest
username=login
password=secret

[siptrunk]
type=aor
contact=sip:domain:5060

[siptrunk]
type=identify
endpoint=siptrunk
match=domain

[siptrunk-reg]
type=registration
transport=transport-udp
outbound_auth=siptrunk-auth
server_uri=sip:domain:5060
client_uri=sip:login@domain:5060
contact_user=9999
retry_interval=60
```

इस trunk तक पहुँचने के लिए, हम चैनल नाम `PJSIP/siptrunk` का उपयोग करेंगे। `dtmf_mode=rfc4733` सेटिंग DTMF को बैंड के बाहर ले जाती है (RFC 4733 पुराने RFC 2833 को प्रतिस्थापित करता है; पेलोड समान है)। `identify`/`match` विकल्प IP पते, CIDRs, या होस्टनाम स्वीकार करता है, लेकिन होस्टनाम कॉन्फ़िगरेशन लोड होने के समय एक बार रिज़ॉल्व किए जाते हैं, इसलिए बदलते IP वाले प्रदाता के लिए सिग्नलिंग IP को स्पष्ट रूप से सूचीबद्ध करें। `pjsip show registrations` के साथ पंजीकरण की पुष्टि करें।

## Dial plan का परिचय

Dial plan Asterisk का हृदय है। यह निर्धारित करता है कि Asterisk PBX पर आने वाली प्रत्येक कॉल को कैसे संभालता है। इसमें ऐसे extension शामिल होते हैं जो Asterisk के पालन करने के लिए निर्देशों की एक सूची बनाते हैं। निर्देश चैनल या application से प्राप्त अंकों (digits) द्वारा शुरू किए जाते हैं। Asterisk को सफलतापूर्वक कॉन्फ़िगर करने के लिए, dial plan को समझना महत्वपूर्ण है। अधिकांश dial plan /etc/asterisk डायरेक्टरी में स्थित extensions.conf फ़ाइल में निहित होता है। यह फ़ाइल सरल समूह व्याकरण (group grammar) का उपयोग करती है और इसमें चार प्रमुख अवधारणाएं हैं:

- Extensions
- Priorities
- Applications
- Contexts

आइए एक बुनियादी dial plan बनाएं। इस पुस्तक के बाद के अनुभागों में, मैं एक अध्याय विशेष रूप से dial plan को समर्पित करूँगा। यदि आपने नमूना फ़ाइलें (make samples) इंस्टॉल की हैं, तो extensions.conf पहले से ही मौजूद है। इसे किसी अन्य नाम से सहेजें और एक खाली फ़ाइल के साथ शुरुआत करें।

## extensions.conf फ़ाइल की संरचना

extensions.conf फ़ाइल को अलग-अलग सेक्शन में विभाजित किया गया है। पहला [general] सेक्शन है, जिसके बाद [globals] सेक्शन आता है। प्रत्येक सेक्शन की शुरुआत उसके नाम की परिभाषा (जैसे, [default]) से होती है और यह तब समाप्त होता है जब कोई दूसरा सेक्शन बनाया जाता है।

### [general] सेक्शन

general सेक्शन फ़ाइल के सबसे ऊपर स्थित होता है। dialplan को कॉन्फ़िगर करना शुरू करने से पहले, उन सामान्य विकल्पों को जानना उपयोगी होता है जो dialplan के कुछ व्यवहारों को नियंत्रित करते हैं। ये विकल्प इस प्रकार हैं:

- static और write protect: यदि `static=yes` और `writeprotect=no` है, तो आप चल रहे dialplan को CLI कमांड के साथ डिस्क पर वापस सेव कर सकते हैं:

```
*CLI> dialplan save
```

चेतावनी: यदि आप CLI से `dialplan save` कमांड जारी करते हैं, तो आप फ़ाइल में मौजूद सभी टिप्पणियों (remarks) और कमेंट्स को खो देंगे।

- autofallthrough: यदि autofallthrough सेट है, तो यदि किसी extension के पास करने के लिए कुछ नहीं बचता है, तो यह Asterisk के सर्वोत्तम अनुमान के आधार पर BUSY, CONGESTION, या HANGUP के साथ कॉल को समाप्त कर देगा। यह डिफ़ॉल्ट है। यदि autofallthrough सेट नहीं है, तो यदि किसी extension के पास करने के लिए कुछ नहीं बचता है, तो Asterisk नए extension के डायल होने की प्रतीक्षा करेगा।
- clearglobalvars: यदि clearglobalvars सेट है, तो dialplan reload या Asterisk reload होने पर ग्लोबल वेरिएबल्स को क्लियर कर दिया जाएगा और उन्हें फिर से पार्स किया जाएगा। यदि clearglobalvars सेट नहीं है, तो ग्लोबल वेरिएबल्स रीलोड के दौरान बने रहेंगे—और भले ही उन्हें extensions.conf या इसकी किसी शामिल फ़ाइल से हटा दिया जाए—वे अपने पिछले मान (value) पर ही सेट रहेंगे।
- extenpatternmatchnew: यह एक तेज़ पैटर्न-मैचिंग एल्गोरिदम का उपयोग करता है, जो तब विशेष रूप से सहायक होता है जब आपके पास बड़ी संख्या में extensions हों। इसका डिफ़ॉल्ट मान no है।
- userscontext: यह वह context है जहाँ users.conf की प्रविष्टियाँ पंजीकृत होती हैं।

### [globals] सेक्शन

[globals] सेक्शन में आप ग्लोबल वेरिएबल्स और उनके प्रारंभिक मानों को परिभाषित करेंगे। आप ${GLOBAL(variable)} का उपयोग करके dialplan में वेरिएबल तक पहुँच सकते हैं। आप ${ENV(variable)} का उपयोग करके linux/unix वातावरण में परिभाषित वेरिएबल्स तक भी पहुँच सकते हैं। ग्लोबल वेरिएबल्स केस-सेंसिटिव नहीं होते हैं। कुछ उदाहरण इस प्रकार हो सकते हैं:

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

निम्नलिखित उदाहरण में, आप dialplan में एक ग्लोबल वेरिएबल सेट और टेस्ट कर सकते हैं।

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Context, dial plan का एक नामित विभाजन (named partition) है। [general] और [globals] अनुभागों के बाद, dial plan context का एक समूह होता है जिसमें प्रत्येक context में कई extension होते हैं, प्रत्येक extension में कई priority होती हैं, और प्रत्येक priority कई तर्कों (arguments) के साथ एक application को कॉल करती है।

![Asterisk कॉल फ़्लो: प्रत्येक कॉल एक चैनल (IAX, SIP, और अन्य) पर एक इनकमिंग कॉल लेग के रूप में आती है; चैनल का context — जिसे वैश्विक स्तर पर या चैनल कॉन्फ़िगरेशन फ़ाइल में प्रति-चैनल सेट किया जाता है — यह तय करता है कि आउटगोइंग लेग पर जाने से पहले extensions.conf में कौन सा context कॉल को प्रोसेस करेगा।](../images/04-first-pbx-fig03.png)

![कॉल प्रोसेसिंग: एक चैनल के लिए परिभाषित `context=` (chan_dahdi.conf या pjsip.conf में) extensions.conf में उस मिलान वाले context का नाम बताता है जहाँ dial plan कॉल को हैंडल करता है।](../images/04-first-pbx-fig04.png)

आप अन्य फ़ोन और PSTN तक पहुँचने के लिए एक सरल dial plan बना सकते हैं। हालाँकि, Asterisk उससे कहीं अधिक शक्तिशाली है। हमारा उद्देश्य आपको dial plan में जो कुछ भी संभव है, उसके बारे में अधिक विस्तार से सिखाना है।

## Extensions

पारंपरिक PBX के विपरीत, जहाँ extension फोन, इंटरफेस, मेनू आदि से जुड़े होते हैं, Asterisk में एक extension उन कमांड्स की एक सूची है जिन्हें तब प्रोसेस किया जाता है जब कोई विशिष्ट extension नंबर या नाम ट्रिगर होता है। कमांड्स को प्राथमिकता (priority) के क्रम में प्रोसेस किया जाता है।

![Extension syntax: `exten => number(name),{priority|label}[(alias)],application`। Extensions संख्यात्मक, अल्फ़ान्यूमेरिक, कॉलर ID के साथ संख्यात्मक, एक पैटर्न, या `s` जैसा एक मानक extension हो सकते हैं; प्राथमिकताएँ एक संख्या, `n` (अगला), `s` (समान), एक ऑफसेट, या एक `hint` हो सकती हैं।](../images/04-first-pbx-fig05.png)

एक extension शाब्दिक (literal), मानक, या विशेष हो सकता है। एक मानक extension में केवल संख्याएँ या नाम और * तथा # वर्ण शामिल होते हैं; 12#89* एक वैध शाब्दिक extension है। नामों का उपयोग भी extension मिलान के लिए किया जा सकता है। Extensions केस-सेंसिटिव होते हैं। हालाँकि, आप एक ही नाम के दो extension नहीं बना सकते जो केवल केस में भिन्न हों। जब कोई extension डायल किया जाता है, तो पहली प्राथमिकता वाला कमांड निष्पादित होता है, उसके बाद प्राथमिकता 2 वाला कमांड, और इसी तरह आगे। यह तब तक होता है जब तक कॉल डिस्कनेक्ट न हो जाए या कोई कमांड संख्या एक न लौटा दे, जो विफलता का संकेत देता है। जब अंतिम प्राथमिकता निष्पादित हो जाती है तो Asterisk क्या करता है, यह autofallthrough पैरामीटर द्वारा विनियमित होता है। इस अध्याय में [general] सेक्शन देखें। उदाहरण:

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

ऊपर आपको उन निर्देशों की सूची मिलेगी जिन्हें extension 123 डायल होने पर प्रोसेस किया जाता है। पहली प्राथमिकता चैनल का उत्तर देना है (यह तब आवश्यक है जब चैनल रिंगिंग स्थिति में हो: जैसे, FXO चैनल)। दूसरी प्राथमिकता tt-weasels नामक एक ऑडियो फाइल को प्लेबैक करना है। तीसरी प्राथमिकता चैनल को हैंग अप करती है। एक अन्य विकल्प कॉलर ID के अनुसार कॉल को हैंडल करना है। आप प्रोसेस किए जाने वाले कॉलर ID को निर्दिष्ट करने के लिए / वर्ण का उपयोग कर सकते हैं। उदाहरण:

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

यह उदाहरण extension 123 को ट्रिगर करेगा और निम्नलिखित विकल्पों को केवल तभी निष्पादित करेगा यदि कॉलर ID 100 है। यह नीचे वर्णित पैटर्न का उपयोग करके भी किया जा सकता है:

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint: एक extension को एक चैनल से मैप करता है। इसका उपयोग चैनल की स्थिति की निगरानी के लिए किया जाता है। इसका उपयोग presence के साथ संयोजन में किया जाता है। फोन को इसका समर्थन करना चाहिए।

#### Patterns

आप dialplan में पैटर्न और शाब्दिक मानों का उपयोग कर सकते हैं। पैटर्न dialplan के आकार को कम करने के लिए बहुत उपयोगी हैं। सभी पैटर्न “_” वर्ण से शुरू होते हैं। पैटर्न को परिभाषित करने के लिए निम्नलिखित वर्णों का उपयोग किया जा सकता है। चित्र Asterisk के साथ उपयोग के लिए उपलब्ध पैटर्न की पहचान करता है।

![Pattern matching characters: `_` एक पैटर्न शुरू करता है, `.` एक या अधिक वर्णों का मिलान करता है, `!` शून्य या अधिक का मिलान करता है, `[123-7]` किसी भी सूचीबद्ध अंक या रेंज का मिलान करता है, `X` 0-9 है, `Z` 1-9 है, और `N` 2-9 है — कार्यालय extension रेंज को मैप करने वाले उदाहरणों के साथ।](../images/04-first-pbx-fig06.png)

### Special extensions

Asterisk कुछ extension नामों का उपयोग मानक extensions के रूप में करता है।

![Asterisk special extensions: `i` (अमान्य), `s` (प्रारंभ), `h` (हैंगअप), `t` (टाइमआउट), `T` (पूर्ण टाइमआउट), `o` (ऑपरेटर), `a` (voicemail में `*` दबाया गया), `fax` (फैक्स पहचान), और `Talk` (BackgroundDetect के साथ उपयोग किया गया)।](../images/04-first-pbx-fig07.png)

विवरण:

- **s**: Start (प्रारंभ)। इसका उपयोग तब कॉल को हैंडल करने के लिए किया जाता है जब कोई डायल किया गया नंबर नहीं होता है। यह FXO trunks और इन-मेनू प्रोसेसिंग के लिए उपयोगी है।
- **t**: Timeout (टाइमआउट)। इसका उपयोग तब किया जाता है जब प्रॉम्प्ट बजाए जाने के बाद कॉल निष्क्रिय रहती है। इसका उपयोग निष्क्रिय लाइन को हैंग अप करने के लिए भी किया जाता है।
- **T**: AbsoluteTimeout (पूर्ण टाइमआउट)। यदि आप `TIMEOUT(absolute)` dialplan फंक्शन का उपयोग करके कॉल सीमा निर्धारित करते हैं, तो एक बार जब कॉल परिभाषित सीमा से अधिक हो जाती है, तो इसे T extension पर भेज दिया जाएगा।
- **h**: Hangup (हैंगअप)। इसे उपयोगकर्ता द्वारा कॉल डिस्कनेक्ट करने के बाद कॉल किया जाता है।
- **i**: Invalid (अमान्य)। यह तब ट्रिगर होता है जब आप context में किसी गैर-मौजूद extension पर कॉल करते हैं। इन extensions का उपयोग CDR रिकॉर्ड की सामग्री को प्रभावित कर सकता है—विशेष रूप से, dst जिसमें डायल किया गया नंबर नहीं होता है।
- **o**: Operator (ऑपरेटर)। इसका उपयोग ऑपरेटर के पास जाने के लिए किया जाता है जब उपयोगकर्ता voicemail के दौरान "0" दबाता है।

इन extensions का उपयोग बिलिंग रिकॉर्ड (CDR) की सामग्री को बदल सकता है—विशेष रूप से, dst फ़ील्ड में डायल किया गया नंबर नहीं होगा। इस समस्या को हल करने के लिए, आपको dial() एप्लिकेशन में g विकल्प का उपयोग करना चाहिए और resetcdr(w) और/या nocdr() फंक्शन्स पर विचार करना चाहिए।

## Variables

Asterisk PBX में, variables ग्लोबल, चैनल-विशिष्ट और एनवायरनमेंट-विशिष्ट हो सकते हैं। आप कंसोल में किसी variable की सामग्री देखने के लिए NoOP() application का उपयोग कर सकते हैं। यह application arguments के रूप में एक ग्लोबल variable या चैनल-विशिष्ट variable का उपयोग कर सकता है। एक variable को निम्नलिखित उदाहरण की तरह संदर्भित किया जा सकता है, जहाँ varname उस variable का नाम है।

```
${varname}
```

एक variable का नाम एक अल्फ़ान्यूमेरिक स्ट्रिंग हो सकता है जो एक अक्षर से शुरू होता है। ग्लोबल variable नाम केस-सेंसिटिव नहीं होते हैं। हालाँकि, सिस्टम variables (Asterisk-defined या channel-defined) केस-सेंसिटिव होते हैं। इस प्रकार, variable ${EXTEN} और ${exten} अलग-अलग हैं।

### Global variables

ग्लोबल variables को extensions.conf फ़ाइल के [global] सेक्शन में या application का उपयोग करके कॉन्फ़िगर किया जा सकता है:

```
set(Global(variable)=content)
```

### Channel-specific variables

चैनल-विशिष्ट variables को set() application का उपयोग करके कॉन्फ़िगर किया जाता है। प्रत्येक चैनल को अपना स्वयं का variable स्पेस मिलता है। विभिन्न चैनलों के variables के बीच टकराव की कोई संभावना नहीं होती है। जब चैनल हैंग-अप होता है तो एक चैनल-विशिष्ट variable नष्ट हो जाता है। सबसे अधिक उपयोग किए जाने वाले कुछ variables हैं:

- ${EXTEN} डायल किया गया extension
- ${CONTEXT} वर्तमान context
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} वर्तमान caller ID
- ${PRIORITY} वर्तमान priority

अन्य चैनल-विशिष्ट variables सभी अपरकेस में होते हैं। आप dumpchan() application का उपयोग करके कई variables की सामग्री देख सकते हैं। नीचे dump-channel variables का एक सरल अंश दिया गया है।

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Dumpchan आउटपुट:

```
Dumping Info For Channel: PJSIP/4400-00000001:
================================================================================
Info:
Name=               PJSIP/4400-00000001
Type=               PJSIP
UniqueID=           1161186526.1
LinkedID=           1161186526.0
CallerIDNum=        4400
CallerIDName=       laptop
ConnectedLineIDNum= (N/A)
ConnectedLineIDName=(N/A)
DNIDDigits=         9001
RDNIS=              (N/A)
Parkinglot=
Language=           en
State=              Ring (4)
Rings=              0
NativeFormat=       (ulaw)
WriteFormat=        ulaw
ReadFormat=         ulaw
RawWriteFormat=     ulaw
RawReadFormat=      ulaw
WriteTranscode=     No
ReadTranscode=      No
1stFileDescriptor=  16
Framesin=           0
Framesout=          0
TimetoHangup=       0
ElapsedTime=        0h0m0s
BridgeID=           (Not bridged)
Context=            default
Extension=          9001
Priority=           1
CallGroup=
PickupGroup=
Application=        DumpChan
Data=               (Empty)
Blocking_in=        (Not Blocking)
Variables:
```

ऊपर दिया गया फ़ील्ड लेआउट Asterisk 22 `DumpChan` आउटपुट है (एक वास्तविक `PJSIP/...` चैनल नाम, `CallerIDNum`/`ConnectedLineID` फ़ील्ड्स, और `Raw*`/`Transcode`/`BridgeID` पंक्तियाँ जिन्हें PJSIP चैनल पॉप्युलेट करते हैं)। पुराने ड्राइवर के विपरीत, एक PJSIP चैनल स्वचालित रूप से `SIPCALLID`/`SIPUSERAGENT` चैनल variables को सेट नहीं करता है; समकक्ष SIP विवरणों को `PJSIP_HEADER()` और `CHANNEL()` dialplan फ़ंक्शंस के साथ मांग पर पढ़ा जाता है — उदाहरण के लिए रिमोट RTP पते के लिए `${CHANNEL(pjsip,call-id)}`, `${PJSIP_HEADER(read,User-Agent)}`, और `${CHANNEL(rtp,dest)}`।

### Environment-specific variables

ऑपरेटिंग सिस्टम में परिभाषित variables तक पहुँचने के लिए एनवायरनमेंट-विशिष्ट variables का उपयोग किया जा सकता है। आप ENV() फ़ंक्शन का उपयोग करके एनवायरनमेंट-विशिष्ट variables सेट कर सकते हैं। उदाहरण के लिए:

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### Application-specific variables

कुछ applications डेटा इनपुट और आउटपुट के लिए variables का उपयोग करती हैं। आप application को कॉल करने से पहले variables सेट कर सकते हैं या application निष्पादन के बाद variable को पुनः प्राप्त कर सकते हैं। उदाहरण के लिए: Dial application निम्नलिखित variables लौटाती है:

- ${DIALEDTIME} -> यह एक चैनल डायल करने से लेकर उसके डिस्कनेक्ट होने तक का समय है।
- ${ANSWEREDTIME} -> यह वास्तविक कॉल के लिए लगा समय है।
- ${DIALSTATUS} यह कॉल की स्थिति है: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> कॉल के लिए त्रुटि संदेश।

## Expressions

dialplan में Expressions बहुत उपयोगी हो सकते हैं। इनका उपयोग स्ट्रिंग्स में हेरफेर करने और गणितीय तथा तार्किक संचालन (logical operations) करने के लिए किया जाता है।

![Asterisk expressions overview — `$[expression1 operator expression2]` — dialplan में उपलब्ध गणितीय, तार्किक, तुलनात्मक, regular-expression, और conditional ऑपरेटरों का समूहीकरण।](../images/04-first-pbx-fig08.png)

Expression सिंटैक्स को इस प्रकार परिभाषित किया गया है:

```
$[expression1 operator expression2]
```

मान लीजिए कि हमारे पास “I” नामक एक वेरिएबल है और हम उस वेरिएबल में 100 जोड़ना चाहते हैं:

```
$[${I}+100]
```

जब Asterisk को dialplan में कोई expression मिलता है, तो वह पूरे expression को उसके परिणामी मान (resulting value) से बदल देता है।

### Operators

Expressions बनाने के लिए निम्नलिखित ऑपरेटरों का उपयोग किया जा सकता है। ऑपरेटर की प्राथमिकता (precedence) पर ध्यान देना महत्वपूर्ण है।

1. Parentheses “()”
2. Unary operators “! -“
3. Regular expression “: =~
4. Multiplicative operators “* / %”
5. Additive operators “+ -“
6. Comparison operators
7. Logical operators
8. Conditional operators

#### Math Operators

- Addition (+)
- Subtraction (-)
- Multiplication(*)
- Division (/)
- Modulus (%)

#### Logical Operators

- Logical “AND” (&)
- Logical “OR” (|)
- Logical Unary Complement (!)

#### Regular expression operators

- Regular expression matching (:)
- Regular expression exact matching (=~)

Regular expression एक विशेष टेक्स्ट स्ट्रिंग है जिसका उपयोग सर्च पैटर्न का वर्णन करने के लिए किया जाता है। आप regular expressions को वाइल्डकार्ड के रूप में सोच सकते हैं। Regular expressions का उपयोग किसी स्ट्रिंग को पैटर्न से मिलाने और मिलान की जांच करने के लिए किया जाता है। यदि मिलान सफल होता है और regular expression में कम से कम एक मिलान होता है, तो पहला मिलान लौटाया जाता है; अन्यथा, परिणाम मिलान किए गए वर्णों की संख्या होती है।

#### Comparison operators

यदि संबंध सत्य है तो तुलना का परिणाम 1 होता है, और यदि यह असत्य है तो 0 होता है।

- = equal
- != not equal
- < less than
- > greater than
- <= less than or equal to
- >= greater than or equal to

### LAB. निम्नलिखित expressions का मूल्यांकन करें:

इन expressions को अपने dialplan में रखें और expressions का मूल्यांकन करने के लिए NoOP() एप्लिकेशन का उपयोग करें। 9002 डायल करें और Asterisk कंसोल में परिणामों की जांच करें। परिणामों को दिखाने के लिए verbose 15 का उपयोग करें।

```
exten=9002,1,set(NAME="FLAVIO")                 ;Set NAME=FLAVIO
exten=9002,n,set(I=4)
exten=9002,n,set(URI="40001@voip.school")
exten=9002,n,NoOP(${NAME})
exten=9002,n,NoOP(${I})
exten=9002,n,NoOP($[${I}+${I}])
exten=9002,n,NoOP($[${I}=4])
exten=9002,n,NoOP($[${I}=4 & ${NAME}=FLAVIO])
exten=9002,n,NoOP($[${URI} =~ "4[0-9][0-9][0-9][0-9]@."])
exten=9002,n,NoOP($[${I}=4?"MATCH"::"DO NOT MATCH"])
exten=9002,n,hangup
```

## Functions

कुछ applications को functions द्वारा प्रतिस्थापित कर दिया गया है, जो केवल expressions की तुलना में अधिक उन्नत तरीके से variables को process करने की अनुमति देते हैं। आप निम्नलिखित console command जारी करके functions की पूरी सूची देख सकते हैं:

```
*CLI> core show functions
```

String length: ${LEN(string)} string की लंबाई लौटाता है

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

पहले operation में, system परिणाम के रूप में 5 दिखाता है (“fruit” शब्द में अक्षरों की संख्या)। दूसरा 4 संख्या लौटाता है (“pear” शब्द में अक्षरों की संख्या)। Substrings: “offset” parameter द्वारा परिभाषित position से शुरू होकर, “length” parameter में परिभाषित string लंबाई के साथ substring लौटाता है। यदि offset negative है, तो यह string के अंत से शुरू होकर दाएं से बाएं ओर चलता है। यदि length को छोड़ दिया जाता है या negative है, तो यह offset से शुरू होने वाली पूरी string ले लेता है।

```
${string:offset:length }
```

Example #1: कई substrings

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

Example #2: पहले तीन digits से area code लें।

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

Example #3: variable ${EXTEN} से area code को छोड़कर सभी digits लेता है।

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### String concatenation

दो strings को concatenate करने के लिए, उन्हें बस एक साथ लिखें।

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Applications

dialplan बनाने के लिए, हमें applications की अवधारणा को समझना होगा। आप dialplan में channel को संभालने के लिए applications का उपयोग करेंगे। Applications कई modules में कार्यान्वित (implemented) होती हैं। उपलब्ध applications modules पर निर्भर करती हैं। आप console command का उपयोग करके सभी Asterisk applications को देख सकते हैं:

```
*CLI> core show applications
```

वैकल्पिक रूप से, आप निम्नलिखित उदाहरण का उपयोग करके किसी विशिष्ट application का विवरण देख सकते हैं:

```
*CLI> core show application Dial
```

एक सरल dialplan बनाने के लिए, आपको कुछ applications के बारे में जानना होगा। हम पुस्तक में बाद में अधिक उन्नत उदाहरणों पर चर्चा करेंगे।

![एक सरल dialplan बनाने के लिए आवश्यक मुट्ठी भर applications: Answer (एक channel का उत्तर देना), Dial (किसी अन्य channel को कॉल करना), Hangup (एक channel को काटना), Playback (एक ऑडियो फ़ाइल चलाना), और Goto (एक priority, extension, या context पर कूदना)।](../images/04-first-pbx-fig09.png)

हम दो बुनियादी PBXs के लिए एक सरल dialplan बनाने के लिए इन applications (ऊपर) का उपयोग करेंगे।

### Answer()

[Synopsis] यदि घंटी बज रही है तो एक channel का उत्तर देता है [Description] Answer([delay]): यदि कॉल का उत्तर नहीं दिया गया है, तो application इसका उत्तर देगी। अन्यथा, इसका कॉल पर कोई प्रभाव नहीं पड़ता है। यदि delay निर्दिष्ट है, तो Asterisk कॉल का उत्तर देने से पहले ‘delay’ में निर्दिष्ट मिलीसेकंड की संख्या तक प्रतीक्षा करेगा।

### Dial()

निम्नलिखित विवरण dialplan में show application dial जारी करके प्राप्त किया जा सकता है। आसान खोज के लिए, इसे नीचे पुनरुत्पादित किया गया है। Dial application के लिए syntax भी नीचे दिखाया गया है:

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

यह application एक या अधिक निर्दिष्ट channels पर कॉल करेगी। जैसे ही अनुरोधित channels में से कोई एक उत्तर देता है, originating channel का उत्तर दिया जाएगा—यदि पहले से उत्तर नहीं दिया गया है। ये दो channels तब एक bridged कॉल में सक्रिय होंगे। अन्य सभी अनुरोधित channels को तब काट दिया जाएगा। जब तक timeout निर्दिष्ट नहीं किया जाता है, Dial application तब तक अनिश्चित काल तक प्रतीक्षा करेगी जब तक कि कॉल किए गए channels में से कोई एक उत्तर न दे दे, उपयोगकर्ता कॉल न काट दे, या सभी कॉल किए गए channels व्यस्त या अनुपलब्ध न हों। यदि किसी अनुरोधित channel को कॉल नहीं किया जा सकता है या यदि timeout समाप्त हो जाता है, तो dialplan का निष्पादन जारी रहेगा। यह application पूरा होने पर निम्नलिखित channel variables सेट करती है:

- DIALEDTIME - यह एक channel को डायल करने से लेकर उसके डिस्कनेक्ट होने तक का समय है।
- ANSWEREDTIME - यह वास्तविक कॉल के लिए समय की अवधि है।
- DIALSTATUS - यह कॉल की स्थिति है: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

Privacy और Screening Modes के लिए, यदि called party, calling party को 'Go Away' स्क्रिप्ट पर भेजने का विकल्प चुनती है, तो DIALSTATUS variable को DONTCALL पर सेट किया जाएगा। यदि called party, caller को 'torture' स्क्रिप्ट पर भेजना चाहती है, तो DIALSTATUS variable को TORTURE पर सेट किया जाएगा। यदि originating channel कॉल काट देता है या यदि कॉल bridged है और bridge में मौजूद पक्षों में से कोई भी कॉल समाप्त करता है, तो यह application सामान्य समाप्ति की रिपोर्ट करेगी। यदि channel इसका समर्थन करता है तो वैकल्पिक URL called party को भेजा जाएगा। यदि OUTBOUND_GROUP variable सेट है, तो इस application द्वारा बनाए गए सभी peer channels उस समूह में शामिल किए जाएंगे (जैसा कि

```
Set(GROUP()=...).
```

निम्नलिखित तालिका Dial application के लिए सबसे अधिक उपयोग किए जाने वाले कुछ विकल्पों का सारांश प्रस्तुत करती है। पूरी सूची के लिए, console command `core show application Dial` का उपयोग करें। Asterisk 22 में ये विकल्प channel और timeout से अल्पविराम (commas) द्वारा अलग किए जाते हैं — उदाहरण के लिए `Dial(PJSIP/2000,20,tTm)`।

| विकल्प | विवरण |
|--------|-------------|
| `A(x)` | `x` को फ़ाइल के रूप में उपयोग करके called party को एक घोषणा सुनाता है। |
| `C` | इस कॉल के लिए CDR को रीसेट करता है। |
| `d` | कॉल का उत्तर दिए जाने की प्रतीक्षा करते समय calling उपयोगकर्ता को 1-अंकीय extension डायल करने की अनुमति देता है। यदि वह extension वर्तमान context में मौजूद है, या यदि यह मौजूद है तो `EXITCONTEXT` variable में परिभाषित context में बाहर निकलता है। |
| `D([called][:calling])` | called party द्वारा उत्तर देने के बाद, लेकिन कॉल के bridged होने से पहले निर्दिष्ट DTMF स्ट्रिंग्स भेजता है। `called` स्ट्रिंग called party को और `calling` स्ट्रिंग calling party को भेजी जाती है। किसी भी पैरामीटर का उपयोग अकेले किया जा सकता है। |
| `f` | calling channel के caller ID को dialplan `hint` के माध्यम से channel से जुड़े extension पर सेट करने के लिए मजबूर करता है। वहां उपयोगी है जहां PSTN मनमाना caller ID की अनुमति नहीं देता है। |
| `g` | यदि destination channel कॉल काट देता है तो वर्तमान extension पर dialplan निष्पादन के साथ आगे बढ़ता है। |
| `G(context^exten^pri)` | यदि कॉल का उत्तर दिया जाता है, तो calling party को निर्दिष्ट priority पर और called party को priority+1 पर स्थानांतरित करता है। वैकल्पिक रूप से एक extension (या extension और context) निर्दिष्ट किया जा सकता है; अन्यथा वर्तमान extension का उपयोग किया जाता है। |
| `h` | called party को `*` DTMF अंक भेजकर कॉल काटने की अनुमति देता है। |
| `H` | calling party को `*` DTMF अंक भेजकर कॉल काटने की अनुमति देता है। |
| `L(x[:y][:z])` | कॉल को `x` ms तक सीमित करता है, जब `y` ms शेष रहते हैं तो चेतावनी देता है, और हर `z` ms पर चेतावनी को दोहराता है। नीचे `LIMIT_*` variables देखें। |
| `m([class])` | अनुरोधित channel के उत्तर देने तक calling party को music on hold प्रदान करता है। एक विशिष्ट MusicOnHold क्लास निर्दिष्ट की जा सकती है। |
| `r` | calling party को रिंगिंग का संकेत देता है और जब तक called channel उत्तर नहीं देता तब तक कोई ऑडियो पास नहीं करता है। |
| `S(x)` | called party द्वारा उत्तर देने के `x` सेकंड बाद कॉल काट देता है। |
| `t` | called party को `features.conf` में परिभाषित DTMF अनुक्रम भेजकर calling party को स्थानांतरित करने की अनुमति देता है। |
| `T` | calling party को `features.conf` में परिभाषित DTMF अनुक्रम भेजकर called party को स्थानांतरित करने की अनुमति देता है। |
| `w` | called party को `features.conf` में परिभाषित DTMF अनुक्रम भेजकर वन-टच रिकॉर्डिंग सक्षम करने की अनुमति देता है। |
| `W` | calling party को `features.conf` में परिभाषित DTMF अनुक्रम भेजकर वन-टच रिकॉर्डिंग सक्षम करने की अनुमति देता है। |
| `k` | called party को `features.conf` में कॉल पार्किंग के लिए परिभाषित DTMF अनुक्रम भेजकर कॉल पार्क करने की अनुमति देता है। |
| `K` | calling party को `features.conf` में कॉल पार्किंग के लिए परिभाषित DTMF अनुक्रम भेजकर कॉल पार्क करने की अनुमति देता है। |

`L(x[:y][:z])` विकल्प को निम्नलिखित विशेष variables के साथ ट्यून किया जा सकता है:

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no` (डिफ़ॉल्ट `yes`): caller के लिए ध्वनियाँ बजाता है।
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no`: called party के लिए ध्वनियाँ बजाता है।
- `LIMIT_TIMEOUT_FILE` — समय समाप्त होने पर बजाई जाने वाली फ़ाइल।
- `LIMIT_CONNECT_FILE` — कॉल शुरू होने पर बजाई जाने वाली फ़ाइल।
- `LIMIT_WARNING_FILE` — जब `y` परिभाषित होता है तो चेतावनी के रूप में बजाई जाने वाली फ़ाइल। डिफ़ॉल्ट शेष समय बताना है।

उदाहरण:

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

ऊपर दिए गए उदाहरण में, application संबंधित PJSIP channel पर डायल करेगी। caller और called दोनों कॉल (Tt) को स्थानांतरित कर सकते हैं। रिंग बैक के बजाय music on hold सुनाई देगा। यदि 20 सेकंड के भीतर कोई उत्तर नहीं देता है, तो extension अगली priority पर चला जाएगा।

### Hangup()

calling channel को काटता है [Description] Hangup([causecode]): यह application calling channel को काट देगी। यदि cause code दिया गया है, तो channel का hang-up cause दिए गए मान पर सेट हो जाएगा।

### Goto()

किसी विशेष priority, extension, या context पर कूदें [Description] Goto([[context|]extension|]priority): यह application calling channel को निर्दिष्ट priority पर dialplan निष्पादन जारी रखने का कारण बनेगी। यदि कोई विशिष्ट extension (या extension और context) निर्दिष्ट नहीं है, तो यह application वर्तमान extension की निर्दिष्ट priority पर कूद जाएगी। यदि dialplan में किसी अन्य स्थान पर कूदने का प्रयास सफल नहीं होता है, तो channel वर्तमान extension की अगली priority पर जारी रहेगा।

## dial plan बनाना

एक सरल dial plan बनाने के लिए, आपको contexts और extensions बनाकर सभी आने वाली और जाने वाली कॉल्स को हैंडल करना होगा। इस अनुभाग में, हम आपको सबसे सामान्य extensions बनाना सिखाएंगे।

### extensions के बीच कॉल करना

extensions के बीच कॉलिंग सक्षम करने के लिए, हम channel variable ${EXTEN} का उपयोग कर सकते हैं, जो डायल किए गए extension को संदर्भित करता है। उदाहरण के लिए, यदि extension रेंज 4000 और 4999 के बीच है और सभी extensions SIP का उपयोग करते हैं, तो हम निम्नलिखित कमांड अपना सकते हैं:

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### बाहरी गंतव्य (external destination) पर कॉल करना

किसी बाहरी गंतव्य पर कॉल करने के लिए आप डायल किए गए नंबर के आगे एक रूट लगा सकते हैं। उत्तरी अमेरिका में, बाहरी रूप से डायल किए जाने वाले नंबर के बाद 9 का उपयोग करना सामान्य है। यदि आप PSTN के लिए analog या digital channel का उपयोग कर रहे हैं, तो कमांड कुछ इस तरह दिखनी चाहिए: यदि आप DAHDI के बजाय SIP trunk का उपयोग करना चाहते हैं, तो `PJSIP/...@siptrunk` channel का उपयोग करें।

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

उपरोक्त लाइन आपको 9 और वांछित नंबर डायल करने की अनुमति देगी। दिए गए उदाहरण में, आप पहले DAHDI channel (DAHDI/1) का उपयोग करेंगे। यदि आपके पास कई लाइनें हैं और यह व्यस्त है, तो कॉल पूरी नहीं होगी। हालाँकि, आप स्वचालित रूप से पहले उपलब्ध DAHDI channel को चुनने के लिए निम्नलिखित लाइन का उपयोग कर सकते हैं। वैकल्पिक रूप से, आप DAHDI के बजाय SIP trunk का उपयोग कर सकते हैं। PJSIP फॉर्म `Dial(PJSIP/number@siptrunk,...)` में, डायल किया गया नंबर user part है और `siptrunk` ऊपर कॉन्फ़िगर किया गया endpoint है।

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

“g1” पैरामीटर समूह में पहले उपलब्ध channel की खोज करेगा, जिससे सभी channels का उपयोग संभव हो सकेगा। नीचे दी गई लाइन का उपयोग करके, आप एक लंबी दूरी (long distance) का नंबर डायल कर सकते हैं।

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### PSTN लाइन प्राप्त करने के लिए 9 डायल करना

यदि आपके पास बाहरी कॉलिंग पर कोई प्रतिबंध नहीं है, तो आप इसे सरल बना सकते हैं और निम्नलिखित का उपयोग कर सकते हैं:

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### ऑपरेटर extension पर कॉल प्राप्त करना

निम्नलिखित उदाहरण में, ऑपरेटर extension 4000 है। PSTN लाइन एक FXO interface से जुड़ी है। chan_dahdi.conf फ़ाइल में, निर्दिष्ट context from-pstn है। PSTN से आने वाली कोई भी कॉल dial plan में from-pstn context पर रूट की जाएगी। इस लाइन में direct inward dialing (DID) नहीं है; इसलिए, हमें “s” extension के माध्यम से कॉल प्राप्त करनी होगी। यदि SIP trunk से प्राप्त कर रहे हैं, तो [from-sip] context का उपयोग करें।

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
[from-sip]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
```

### direct inward dialing (DID) का उपयोग करके कॉल प्राप्त करना

यदि आपके पास digital लाइन है, तो आप डायल किया गया extension प्राप्त करेंगे। जब ऐसा होता है, तो आपको कॉल को ऑपरेटर को फॉरवर्ड करने की आवश्यकता नहीं होती है; बल्कि, आप कॉल को सीधे गंतव्य पर फॉरवर्ड कर सकते हैं। मान लीजिए कि आपकी DID रेंज 3028550 से 3028599 तक है और अंतिम चार नंबर DID में पास किए जाते हैं। कॉन्फ़िगरेशन निम्नलिखित उदाहरण जैसा दिखेगा:

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### कई extensions को एक साथ बजाना

आप Asterisk को एक extension डायल करने के लिए सेट कर सकते हैं और, यदि उसका उत्तर नहीं दिया जाता है, तो निम्नलिखित उदाहरण में दिखाए अनुसार कई अन्य extensions को एक साथ डायल कर सकते हैं:

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

इस उदाहरण में, जब कोई ऑपरेटर को डायल करता है, तो शुरू में DAHDI/1 channel का प्रयास किया जाता है। यदि 15 सेकंड (timeout) के बाद कोई उत्तर नहीं देता है, तो DAHDI/1, DAHDI/2 और DAHDI/3 channels एक साथ 15 सेकंड के लिए बजेंगे।

### Caller ID द्वारा रूटिंग

इस उदाहरण में, आप caller ID के आधार पर अलग-अलग उपचार दे सकते हैं, जो कॉल स्पैमर्स के लिए उपयोगी हो सकता है। उदाहरण के लिए:

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

इस उदाहरण में, हमने एक विशेष नियम जोड़ा है कि, यदि caller ID 4832518888 है, तो आप पहले से रिकॉर्ड की गई फ़ाइल “I-have-moved-to-china” से एक संदेश चलाएं। अन्य कॉल्स को सामान्य रूप से स्वीकार किया जाता है।

### dial plan में variables का उपयोग करना

Asterisk कुछ applications के लिए तर्क (arguments) के रूप में dial plan में global और channel variables का उपयोग कर सकता है। निम्नलिखित उदाहरण देखें:

```
[globals]
Flavio => DAHDI/1
Daniel => DAHDI/2&PJSIP/pingtel
Anna => DAHDI/3
Christian => DAHDI/4
[mainmenu]
exten => 1,1,Dial(${Daniel}&${Flavio})
exten => 2,1,Dial(${Anna}&${Christian})
exten => 3,1,Dial(${Anna}&${Flavio})
```

variables का उपयोग करने से भविष्य में बदलाव करना आसान हो जाता है। यदि आप variable बदलते हैं, तो सभी संदर्भ तुरंत बदल जाते हैं।

### घोषणा (announcement) रिकॉर्ड करना

इस अनुभाग में बाद में चर्चा किए गए कुछ विकल्पों में, हम रिकॉर्ड किए गए प्रॉम्प्ट का उपयोग करेंगे। यहाँ हम आपको उन्हें रिकॉर्ड करने का एक आसान तरीका दिखाते हैं। हम अपने स्वयं के फ़ोन का उपयोग करके घोषणा को सहेजने के लिए Record() application का उपयोग करेंगे।

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

ये निर्देश आपको softphone से कोई भी संदेश रिकॉर्ड करने की अनुमति देते हैं। उदाहरण: softphone से recordmenu डायल करना। निर्देश ${EXTEN:6} variable के साथ रिकॉर्डिंग को कॉल करेंगे, जिसमें पहले छह अक्षर नहीं होंगे। दूसरे शब्दों में, निर्देश record(menu:gsm) के बराबर है। आपको बस record + name_of_the_file_to_be_recorded डायल करना है, रिकॉर्डिंग समाप्त करने के लिए # दबाएं, और रिकॉर्डिंग सुनने के लिए प्रतीक्षा करें।

### digital receptionist में कॉल प्राप्त करना

अब जब हमारे पास कुछ सरल उदाहरण हैं, तो आइए applications background() और goto() के बारे में अपनी सीख का विस्तार करें। Asterisk में इंटरैक्टिव सिस्टम के लिए कुंजी background() application है, जो आपको एक ऑडियो फ़ाइल निष्पादित करने की अनुमति देती है जो, जब कॉलर कोई कुंजी दबाता है, तो डायल किए गए extension पर कॉल भेजने के लिए बाधित हो जाती है। background() application का सिंटैक्स:

```
exten=>extension, priority, background(filename)
```

एक और बहुत उपयोगी application goto() है। जैसा कि नाम से पता चलता है, यह निर्दिष्ट context, extension और priority पर कूद जाता है। goto() application का सिंटैक्स:

```
exten=>extension, priority,goto(context, extension, priority)
```

goto() कमांड के लिए मान्य प्रारूप:

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

निम्नलिखित उदाहरण में, हम एक digital receptionist बनाएंगे। extensions.conf फ़ाइल को संपादित करना और निम्नलिखित extensions को कॉन्फ़िगर करना बहुत सरल है:

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
include=aapstn
[from-sip]
include=aasip
[aapstn]
exten=>s,1,answer()
exten=>s,n,set(TIMEOUT(response)=10)
exten=>s,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>s,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
[aasip]
exten=>9999,1,answer()
exten=>9999,n,set(TIMEOUT(response)=10)
exten=>9999,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>9999,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
```

SIP extensions `PJSIP/` का उपयोग करते हैं और IAX extensions `IAX2/` का उपयोग करते हैं — दोनों drivers Asterisk 22 में आते हैं, हालाँकि `chan_iax2` को अब legacy माना जाता है और SIP/PJSIP को प्राथमिकता दी जाती है।

menu1.gsm फ़ाइल में, “press the extension or wait for the operator” संदेश रिकॉर्ड करें। जब उपयोगकर्ता 6000 नंबर डायल करता है, तो उसे extension 6000 पर भेज दिया जाएगा। इस बिंदु पर, आपको answer(), background(), goto(), hangup(), और playback() सहित कई applications के उपयोग की स्पष्ट समझ होनी चाहिए। यदि आपको स्पष्ट समझ नहीं है, तो कृपया इस अध्याय को तब तक दोबारा पढ़ें जब तक आप सामग्री के साथ सहज महसूस न करें। आप background application का बहुत बार उपयोग करेंगे। एक बार जब आप extensions, priorities और applications की मूल बातें समझ लेते हैं, तो एक सरल dial plan बनाना आसान हो जाएगा। इन अवधारणाओं को पुस्तक में बाद में अधिक गहराई से खोजा जाएगा, और आप देखेंगे कि dial plan अधिक शक्तिशाली हो जाएगा।

## सारांश

इस अध्याय में, आपने सीखा कि कॉन्फ़िगरेशन फ़ाइलें /etc/asterisk डायरेक्टरी में संग्रहीत होती हैं। Asterisk का उपयोग करने के लिए, सबसे पहले चैनलों (जैसे, PJSIP, DAHDI, IAX) को कॉन्फ़िगर करना आवश्यक है। कॉन्फ़िगरेशन फ़ाइलों के लिए तीन अलग-अलग व्याकरण मौजूद हैं: सिंपल ग्रुप, ऑब्जेक्ट इनहेरिटेंस, और कॉम्प्लेक्स एंटिटी। dialplan को extensions.conf फ़ाइल में बनाया जाता है और यह context और extension का एक समूह है। dialplan में, प्रत्येक extension एक एप्लिकेशन को ट्रिगर करता है। आपने playback, background, dial, goto, hangup, और answer एप्लिकेशन का उपयोग करना सीखा है।

## प्रश्नोत्तरी

1. चैनल कॉन्फ़िगरेशन फ़ाइलें हैं (सभी लागू विकल्प चुनें):
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. Asterisk 22 पर, एकल `chan_sip` पीयर `[6001]` (`type=friend`/`host=dynamic`) को `pjsip.conf` में संबंधित ऑब्जेक्ट्स के किस सेट द्वारा प्रतिस्थापित किया गया है?
   - A. एक `type=peer` और एक `type=user`
   - B. एक `type=endpoint`, एक `type=auth`, और एक `type=aor`
   - C. एक एकल `type=friend`
   - D. एक `type=transport` और एक `type=global`
3. चैनल कॉन्फ़िगरेशन फ़ाइल में एक context को परिभाषित करना महत्वपूर्ण है क्योंकि यह उस चैनल से आने वाली कॉल्स के लिए इनकमिंग context सेट करता है — चैनल से आने वाली कॉल को `extensions.conf` में मिलान वाले context में प्रोसेस किया जाता है।
   - A. सत्य
   - B. असत्य
4. `Playback()` और `Background()` एप्लिकेशन के बीच मुख्य अंतर हैं (दो चुनें):
   - A. Playback एक प्रॉम्प्ट चलाता है लेकिन डिजिट्स (अंकों) के लिए प्रतीक्षा नहीं करता है।
   - B. Background एक प्रॉम्प्ट चलाता है लेकिन डिजिट्स के लिए प्रतीक्षा नहीं करता है।
   - C. Background एक संदेश चलाता है और डिजिट्स दबाए जाने की प्रतीक्षा करता है।
   - D. Playback एक संदेश चलाता है और डिजिट्स दबाए जाने की प्रतीक्षा करता है।
5. जब कोई कॉल बिना DID वाले टेलीफोनी इंटरफ़ेस कार्ड (FXO) के माध्यम से Asterisk में प्रवेश करती है, तो इसे विशेष extension में हैंडल किया जाता है:
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. `Goto()` एप्लिकेशन के लिए मान्य प्रारूप हैं (तीन चुनें):
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. पैटर्न `_7[1-5]XX` मिलान करता है (सभी लागू विकल्प चुनें):
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. `Dial(PJSIP/${EXTEN},20,tTm)` में, `m` विकल्प क्या करता है?
   - A. कॉल को अधिकतम अवधि तक सीमित करता है।
   - B. चैनल के उत्तर देने तक कॉलर को रिंगबैक के बजाय होल्ड पर संगीत (music on hold) प्रदान करता है।
   - C. कॉल किए गए पक्ष के उत्तर देने के बाद DTMF डिजिट्स भेजता है।
   - D. dialplan हिंट का उपयोग करके कॉलर ID को बाध्य करता है।
9. `chan_dahdi.conf` द्वारा उपयोग किए जाने वाले विकल्प-विरासत (option-inheritance) व्याकरण में, आप:
   - A. ऑब्जेक्ट को एक ही पंक्ति में परिभाषित करते हैं।
   - B. पहले विकल्पों को परिभाषित करते हैं और परिभाषित विकल्पों के नीचे ऑब्जेक्ट्स को घोषित करते हैं।
   - C. प्रत्येक ऑब्जेक्ट के लिए एक अलग context परिभाषित करते हैं।
10. एक extension में प्राथमिकताएं (priorities) क्रमिक रूप से (1, 2, 3, …) क्रमांकित होनी चाहिए और `n` का उपयोग नहीं कर सकती हैं।
    - A. सत्य
    - B. असत्य

**उत्तर:** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
