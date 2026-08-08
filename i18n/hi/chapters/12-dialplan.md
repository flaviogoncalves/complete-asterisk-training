# Dial Plan की उन्नत विशेषताएँ

अध्याय 3 में dial plan की मूल बातों पर चर्चा की गई थी। शैक्षणिक कारणों से, हमने सभी विशेषताओं की व्याख्या नहीं की थी, बल्कि केवल कुछ सबसे महत्वपूर्ण विशेषताओं के बारे में बताया था। यह अध्याय dial plan में गहराई से उतरते हुए, उन्नत तकनीकों, नए applications और अवधारणाओं का वर्णन करेगा।

## उद्देश्य

इस अध्याय के अंत तक, आप निम्नलिखित कार्य करने में सक्षम होंगे:

- अपनी extension प्रविष्टियों को सरल बनाना
- dialplan सुरक्षा और फ़िल्टरिंग extensions को संबोधित करना
- IVR मेनू का उपयोग करके कॉल प्राप्त करना
- अनावश्यक पुनर्लेखन से बचने के लिए सबरूटीन का उपयोग करना
- "Include" का उपयोग करके कुछ dialplan सुरक्षा लागू करना
- AsteriskDB का उपयोग करके follow-me लागू करना
- अपने PBX में कार्य-समय के बाद का व्यवहार लागू करना
- किसी अन्य PBX पर स्थानांतरित करने के लिए switch कमांड का उपयोग करना
- प्राइवेसी मैनेजर लागू करना
- voicemail लागू करना
- कॉर्पोरेट डायरेक्टरी लागू करना

## अपने dialplan को सरल बनाना

आप एक extension को परिभाषित करने के लिए “same” कीवर्ड का उपयोग करके अपने dialplan को सरल बना सकते हैं। इससे dialplan में टाइपिंग की गलतियों की संख्या कम होनी चाहिए। नीचे दिए गए उदाहरण को देखें:

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Dial Plan Security

Asterisk dial plan में एक खामी पाई गई है जो एक उपयोगकर्ता को आपके dial plan में एक नया channel और dial number इंजेक्ट करने की अनुमति देती है। मान लीजिए कि आपके सर्वर `exten=>_X.,1,Dial(PJSIP/${EXTEN})` में निम्नलिखित पंक्ति है और किसी दुर्भावनापूर्ण उपयोगकर्ता ने softphone में नंबर `3000&DAHDI/1/011551123456789` डायल किया है। SIP प्रोटोकॉल, डिफ़ॉल्ट रूप से, किसी भी अल्फ़ान्यूमेरिक वर्णों को स्वीकार करता है, इसलिए डायल किया गया extension वास्तव में दो कॉल ट्रिगर करेगा: एक channel PJSIP/3000 के लिए और दूसरा channel DAHDI/011551123456789 के लिए, जो एक अंतरराष्ट्रीय नंबर है। इस प्रकार, extension तक पहुंच रखने वाला कोई भी उपयोगकर्ता वास्तव में दुनिया में कहीं भी कॉल कर सकता है। इस व्यवहार से बचने का सबसे आसान तरीका dial application को कॉल करने से पहले नंबरों को फ़िल्टर करना है। इसके लिए FILTER() फ़ंक्शन बहुत उपयोगी है। उदाहरण:

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

एप्लिकेशन फ़िल्टर आपको डायल किए गए नंबर से 0 से 9 तक की संख्याओं को छोड़कर सभी वर्णों को फ़िल्टर करने की अनुमति देगा। अधिक जानकारी Asterisk से उपलब्ध फ़ाइल README-SERIOUSLY.bestpractices.txt में पाई जा सकती है।

## IVR मेनू का उपयोग करके कॉल प्राप्त करना।

पिछले अनुभाग में, आपने DID का उपयोग करके या ऑपरेटर को फॉरवर्ड करके सभी कॉल प्राप्त किए थे। अब आप सीखेंगे कि IVR मेनू कैसे लागू किया जाता है और एक ऑटो-अटेंडेंट सेवा कैसे बनाई जाती है। विवरण में जाने से पहले, आइए कुछ नए अनुप्रयोगों (applications) की जांच करें। हमने पाठकों के लिए इसे आसान बनाने के लिए नीचे `core show application` कमांड का आउटपुट रखा है। आप `core show application <application_name>` का उपयोग करके स्वयं ये विवरण प्राप्त कर सकते हैं।

### Background() एप्लिकेशन

यह एप्लिकेशन कॉलिंग चैनल द्वारा extension डायल किए जाने की प्रतीक्षा करते समय दी गई फ़ाइलों की सूची को चलाएगा (play करेगा)। इस एप्लिकेशन द्वारा फ़ाइलों को चलाना समाप्त करने के बाद अंकों की प्रतीक्षा जारी रखने के लिए, WaitExten एप्लिकेशन का उपयोग किया जाना चाहिए। langoverride विकल्प स्पष्ट रूप से निर्दिष्ट करता है कि अनुरोधित ध्वनि फ़ाइलों के लिए किस भाषा का उपयोग करने का प्रयास करना है। जो भी context निर्दिष्ट किया जाएगा, वह dialplan context होगा जिसका उपयोग यह एप्लिकेशन डायल किए गए extension पर बाहर निकलते समय करता है। यदि अनुरोधित ध्वनि फ़ाइलों में से कोई मौजूद नहीं है, तो कॉल प्रोसेसिंग समाप्त कर दी जाएगी। विकल्प:

- s - यदि चैनल 'up' स्थिति में नहीं है (अर्थात, अभी तक उत्तर नहीं दिया गया है), तो संदेश के प्लेबैक को छोड़ने का कारण बनता है। यदि ऐसा होता है, तो एप्लिकेशन तुरंत वापस आ जाएगा।
- n - फ़ाइलों को चलाने से पहले चैनल का उत्तर न दें।
- m - केवल तभी रुकें जब कोई अंक हिट गंतव्य context में एक-अंकीय extension से मेल खाता हो।

### Record() एप्लिकेशन

यह एप्लिकेशन चैनल से एक दिए गए फ़ाइल नाम में रिकॉर्ड करता है। यदि फ़ाइल मौजूद है, तो उसे ओवरराइट कर दिया जाएगा।

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' रिकॉर्ड की जाने वाली फ़ाइल प्रकार का प्रारूप है (wav, gsm, आदि)।
- 'silence' वापस आने से पहले अनुमत मौन (silence) के सेकंड की संख्या है।
- 'maxduration' सेकंड में अधिकतम रिकॉर्डिंग अवधि है; यदि यह गायब है या शून्य है, तो कोई अधिकतम सीमा नहीं है।
- 'options' में निम्नलिखित में से कोई भी अक्षर हो सकते हैं:
    - `a` — मौजूदा रिकॉर्डिंग को बदलने के बजाय उसमें जोड़ता है
    - `n` — उत्तर न दें, लेकिन यदि लाइन का अभी तक उत्तर नहीं दिया गया है तो भी रिकॉर्ड करें
    - `q` — शांत (बीप टोन न बजाएं)
    - `s` — यदि लाइन का अभी तक उत्तर नहीं दिया गया है तो रिकॉर्डिंग छोड़ देता है
    - `t` — डिफ़ॉल्ट `#` के बजाय वैकल्पिक `*` टर्मिनेटर कुंजी (DTMF) का उपयोग करें
    - `x` — सभी टर्मिनेटर कुंजियों (DTMF) को अनदेखा करें और हैंग-अप होने तक रिकॉर्डिंग जारी रखें

यदि फ़ाइल नाम में %d शामिल है, तो इन वर्णों को हर बार फ़ाइल रिकॉर्ड होने पर एक से बढ़ाई गई संख्या से बदल दिया जाएगा। अपने सिस्टम पर उपलब्ध प्रारूपों को देखने के लिए core show file formats का उपयोग करें। उपयोगकर्ता रिकॉर्डिंग समाप्त करने और अगली प्राथमिकता पर जाने के लिए # दबा सकता है। यदि उपयोगकर्ता रिकॉर्डिंग के दौरान हैंग अप करता है, तो सारा डेटा खो जाएगा और एप्लिकेशन समाप्त हो जाएगा।

### Playback() एप्लिकेशन

यह एप्लिकेशन दिए गए फ़ाइल नामों को चलाता है (extension शामिल न करें)। पाइप प्रतीक के बाद विकल्प भी शामिल किए जा सकते हैं। 'skip' विकल्प संदेश के प्लेबैक को छोड़ने का कारण बनता है यदि चैनल 'up' स्थिति में नहीं है (अर्थात, अभी तक उत्तर नहीं दिया गया है)।

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

यदि 'skip' निर्दिष्ट है, तो चैनल के हुक पर न होने पर एप्लिकेशन तुरंत वापस आ जाएगा। अन्यथा, जब तक 'noanswer' निर्दिष्ट न हो, ध्वनि बजाने से पहले चैनल का उत्तर दिया जाएगा। सभी चैनल हुक पर रहते हुए संदेश चलाने का समर्थन नहीं करते हैं। यदि 'j' निर्दिष्ट है, तो फ़ाइल मौजूद न होने पर एप्लिकेशन प्राथमिकता n+101 पर कूद जाएगा, यदि मौजूद हो। यह एप्लिकेशन पूरा होने पर निम्नलिखित चैनल वेरिएबल सेट करता है:

- PLAYBACKSTATUS — टेक्स्ट स्ट्रिंग के रूप में प्लेबैक प्रयास की स्थिति, इनमें से एक:
    - `SUCCESS`
    - `FAILED`

### Read() एप्लिकेशन

यह एप्लिकेशन उपयोगकर्ता से दिए गए वेरिएबल में, एक निश्चित संख्या में, पूर्व निर्धारित संख्या में स्ट्रिंग अंक पढ़ता है।

- filename -- अंकों या टोन को पढ़ने से पहले चलाने के लिए फ़ाइल (विकल्प i के साथ)
- maxdigits -- अंकों की अधिकतम स्वीकार्य संख्या। maxdigits दर्ज किए जाने के बाद पढ़ना बंद कर देता है (उपयोगकर्ता को # कुंजी दबाने की आवश्यकता के बिना)। डिफ़ॉल्ट 0 है - कोई सीमा नहीं - उपयोगकर्ता के # कुंजी दबाने की प्रतीक्षा करने के लिए। 0 से नीचे का कोई भी मान समान अर्थ रखता है। अधिकतम स्वीकार्य मान 255 है।

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- विकल्प `s`, `i`, `n` हैं:
    - `s` — यदि लाइन अप नहीं है तो तुरंत वापस आएं
    - `i` — filename को अपने `indications.conf` से संकेत टोन के रूप में चलाएं
    - `n` — यदि लाइन अप नहीं है तब भी अंक पढ़ें
- attempts -- यदि 1 से अधिक है, तो कोई डेटा दर्ज न होने पर किए जाने वाले प्रयासों की संख्या
- timeout -- अंक प्रतिक्रिया की प्रतीक्षा करने के लिए सेकंड की एक पूर्णांक संख्या। यदि 0 से अधिक है, तो वह मान डिफ़ॉल्ट टाइमआउट को ओवरराइड कर देगा।

यदि फ़ंक्शन विफल हो जाता है या त्रुटि देता है तो read() एप्लिकेशन को डिस्कनेक्ट कर देना चाहिए।

### Gotoif() एप्लिकेशन

यह एप्लिकेशन कॉलिंग चैनल को दिए गए शर्त के मूल्यांकन के आधार पर dialplan में निर्दिष्ट स्थान पर कूदने का कारण बनेगा। यदि शर्त सत्य है तो चैनल labeliftrue पर जारी रहेगा, या यदि शर्त गलत है तो 'labeliffalse' पर। लेबल को उसी सिंटैक्स के साथ निर्दिष्ट किया जाता है जिसका उपयोग Goto एप्लिकेशन के भीतर किया जाता है। यदि शर्त द्वारा चुना गया लेबल छोड़ दिया जाता है, तो कोई कूद (jump) नहीं किया जाता है; बल्कि, निष्पादन dialplan में अगली प्राथमिकता के साथ जारी रहता है।

### लैब: चरण-दर-चरण IVR मेनू बनाना

आइए निम्नलिखित कार्यक्षमता के साथ एक IVR मेनू बनाएं। डायल किए जाने पर, IVR संदेश के साथ एक ऑडियो फ़ाइल चलाता है “XYZ कॉर्पोरेशन में आपका स्वागत है; सेल्स के लिए 1 दबाएं, तकनीकी सहायता के लिए 2 दबाएं, प्रशिक्षण के लिए 3 दबाएं, या प्रतिनिधि से बात करने के लिए प्रतीक्षा करें।” अंक कॉलर को इस प्रकार रूट करते हैं:

- `1` — सेल्स (PJSIP/4001) पर ट्रांसफर करें
- `2` — तकनीकी सहायता (PJSIP/4002) पर ट्रांसफर करें
- `3` — प्रशिक्षण (PJSIP/4003) पर ट्रांसफर करें
- कोई अंक नहीं दबाया गया — ऑपरेटर (PJSIP/4000) पर ट्रांसफर करें

**चरण 1 – प्रॉम्प्ट रिकॉर्ड करें**

आइए प्रॉम्प्ट रिकॉर्ड करने के लिए एक extension बनाएं। प्रॉम्प्ट रिकॉर्ड करने के लिए, सॉफ्टफ़ोन से `9003<filename>` (उदाहरण के लिए, `9003welcome`) पर डायल करें। जब आप बीप सुनें, तो रिकॉर्डिंग शुरू करें; रोकने के लिए `#` दबाएं। आप एक बीप सुनेंगे, और सिस्टम रिकॉर्ड किए गए प्रॉम्प्ट को वापस चलाएगा।

**चरण 2 – मेनू लॉजिक बनाएं**

9004 extension डायल करते समय, प्रोसेसिंग `s` extension, प्राथमिकता 1 में मेनू पर कूद जाती है।

### डायल करते समय मिलान करना

यह कॉल प्राप्त करने के लिए एक कंपनी सेटअप मेनू है। `Background()` एप्लिकेशन स्वागत प्रॉम्प्ट चलाता है और फिर अंकों की प्रतीक्षा करता है, जो कॉलर द्वारा डायल किए गए अंकों का वर्तमान context में परिभाषित extensions के साथ मिलान करता है।

```
[incoming]
exten=>s,1,Background(welcome)
exten=>1,1,Dial(DAHDI/1)
exten=>2,1,Dial(DAHDI/2)
exten=>21,1,Dial(DAHDI/3)
exten=>22,1,Dial(DAHDI/4)
exten=>31,1,Dial(DAHDI/5)
exten=>32,1,Dial(DAHDI/6)
```

जब आप इस कंपनी को डायल करते हैं, तो स्वागत संदेश पहले चलाया जाता है। उसके बाद, Asterisk डायल किए जाने वाले अंक की प्रतीक्षा करता है:

| डायल किया गया नंबर | Asterisk क्रिया |
|---------------|-----------------|
| 1 | तुरंत `Dial(DAHDI/1)` को कॉल करता है |
| 2 | टाइमआउट की प्रतीक्षा करता है, फिर `Dial(DAHDI/2)` को कॉल करता है |
| 21 | तुरंत `Dial(DAHDI/3)` को कॉल करता है |
| 22 | तुरंत `Dial(DAHDI/4)` को कॉल करता है |
| 3 | टाइमआउट की प्रतीक्षा करता है, फिर डिस्कनेक्ट करता है |
| 31 | तुरंत `Dial(DAHDI/5)` को कॉल करता है |
| 32 | तुरंत `Dial(DAHDI/6)` को कॉल करता है |

मेनू में अस्पष्टता से बचना महत्वपूर्ण है। हर कोई चाहता है कि उन्हें जल्दी उत्तर दिया जाए। इस कारण से, आपको 2, 21, या 22 नंबरों का उपयोग नहीं करना चाहिए।

### लैब: Read() एप्लिकेशन का उपयोग करना

कृपया read() एप्लिकेशन के साथ लैब का प्रयास करें। Read उपयोगकर्ता से अंक स्वीकार करता है और उन्हें निर्दिष्ट वेरिएबल में डालता है; फिर आप कॉल को पुनर्निर्देशित करने के लिए gotoif एप्लिकेशन का उपयोग कर सकते हैं।

## Context inclusion

एक context में दूसरे context की सामग्री शामिल हो सकती है। ऊपर दिए गए उदाहरण में, कोई भी चैनल internal context में किसी भी extension को डायल कर सकता है, लेकिन केवल 4003 चैनल ही international extensions को डायल कर सकता है। आप dialplan निर्माण को आसान बनाने के लिए context inclusion का उपयोग कर सकते हैं। context inclusion का उपयोग करके, आप नियंत्रित कर सकते हैं कि किसके पास किन extensions तक पहुंच है।

### “number not found” संदेश की समस्या निवारण

“number not found” संदेश प्राप्त होना बहुत आम है। अधिकांश लोग included contexts की अवधारणा को लेकर भ्रमित हो जाते हैं क्योंकि यह वास्तव में सहज नहीं है। एक सामान्य नियम के रूप में, पहले incoming channel कॉन्फ़िगरेशन फ़ाइल पर जाएं, जैसे कि `pjsip.conf`, `chan_dahdi.conf`, और `iax.conf`, और वर्तमान context निर्धारित करें। फिर, extensions.conf फ़ाइल में dialplan पर जाएं और जांचें कि क्या डायल किया गया नंबर उस context में पाया जा सकता है। यदि नहीं, तो आपके dialplan में कुछ गड़बड़ है। contexts के सुनहरे नियम ये हैं: 1. एक चैनल केवल उसी context के भीतर नंबर डायल कर सकता है जिसमें वह चैनल है। 2. जिस context में कॉल प्रोसेस की जाती है, उसे incoming channel कॉन्फ़िगरेशन फ़ाइल (`chan_dahdi.conf`, `iax.conf`, `pjsip.conf`) में परिभाषित किया जाता है।

## switch स्टेटमेंट का उपयोग करना

आप switch कमांड का उपयोग करके dialplan प्रोसेसिंग को किसी अन्य सर्वर पर भेज सकते हैं। आपको दूसरे सर्वर का नाम और की (key) की आवश्यकता होगी। context गंतव्य context है।

![10-dialplan-advanced-features चित्र 6](../images/10-dialplan-advanced-features-img06.png)

## Dial plan प्रोसेसिंग क्रम

जब Asterisk को कोई इनकमिंग कॉल प्राप्त होती है, तो यह चैनल द्वारा परिभाषित context में देखता है। कुछ मामलों में, यदि डायल किए गए नंबर से एक से अधिक पैटर्न मेल खाते हैं, तो Asterisk कॉल को उस सटीक तरीके से प्रोसेस नहीं कर पाता है जैसा आप सोचते हैं। आप `dialplan show` CLI कमांड का उपयोग करके मिलान क्रम देख सकते हैं। उदाहरण: मान लीजिए कि आप एक एनालॉग trunk (DAHDI/1) पर रूट करने के लिए 912 डायल करना चाहते हैं और 9 से शुरू होने वाले अन्य सभी नंबरों को दूसरे एनालॉग trunk (DAHDI/2) पर रूट करना चाहते हैं। आप कुछ इस तरह लिखेंगे:

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

यदि दो पैटर्न एक extension से मेल खाते हैं, तो आप यह नियंत्रित कर सकते हैं कि included contexts का उपयोग करके कौन सा extension पहले प्रोसेस किया जाए। एक included context को उसी context में मौजूद पैटर्न की तुलना में बाद में प्रोसेस किया जाता है।

## #INCLUDE स्टेटमेंट

क्या हमें एक बड़ी फ़ाइल का उपयोग करना चाहिए या कई फ़ाइलों का? आप अपनी extensions.conf में अन्य फ़ाइलों को शामिल करने के लिए #include <filename> स्टेटमेंट का उपयोग कर सकते हैं। उदाहरण के लिए, हम स्थानीय उपयोगकर्ताओं के लिए एक users.conf और विशेष सेवाओं के लिए services.conf बना सकते हैं। सावधान रहें कि #include <filename> को इसके साथ भ्रमित न करें

```
include=>context statement.
```

## GOSUB के साथ सबरूटीन

Asterisk के पुराने संस्करणों में आपके पास Macro कमांड हुआ करती थी। इस कमांड को काफी समय पहले GOSUB के पक्ष में हटा दिया गया था। हम यहाँ प्रदर्शित करेंगे कि कैसे voicemail प्रोसेसिंग के लिए आसान और व्यवस्थित तरीके से सबरूटीन बनाए जाते हैं। कमांड का प्रारूप:

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

GOSUB कमांड Asterisk 1.6 के बाद से उपलब्ध है और यह आर्ग्युमेंट्स पास करने का समर्थन करती है (जो सबरूटीन के अंदर `${ARG1}`, `${ARG2}`, आदि के रूप में उपलब्ध होते हैं)। आर्ग्युमेंट्स के साथ, अब पुरानी Macro कमांड को पूरी तरह से बदलना संभव है। Macros (`app_macro`) को Asterisk 21 में हटा दिया गया था; आपको सबरूटीन के लिए GOSUB का उपयोग करना होगा।

### सबरूटीन बनाना

परिभाषा बहुत समान है। नीचे दिए गए voicemail के लिए stdexten नाम से परिभाषित सबरूटीन को देखें (अपनी पसंद का नाम चुनें)। पहले आर्ग्युमेंट (चैनल का नाम) के साथ Dial कमांड को कॉल करने के बाद, हम कॉल लॉजिक को अगले चरण पर भेजने के लिए ${DIALSTATUS} की जाँच करते हैं।

```
[stdexten]
exten=>s,1,Dial(${ARG1},20,tT)
exten=>s,n,Goto(${DIALSTATUS})
exten=>s,n,hangup()
exten=>s,n(BUSY),voicemail(${ARG2},b)
exten=>s,n,hangup()
exten=>s,n(NOANSWER),voicemail(${ARG2},u)
exten=>s,n,hangup()
exten=>s,n(CANCEL),hangup
exten=>s,n(CHANUNAVAIL),hangup
exten=>s,n(CONGESTION),hangup
```

### सबरूटीन को कॉल करना

सबरूटीन को कॉल करते समय ध्यान दें कि पैरामीटर्स से पहले कोष्ठक (parenthesis) का उपयोग करें।

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Asterisk DB का उपयोग करना

कॉल फॉरवर्ड और ब्लैक लिस्ट लागू करने के लिए, हमें डेटा को स्टोर और रिस्टोर करने के किसी तरीके की आवश्यकता होती है। सौभाग्य से, Asterisk एक इन-बिल्ट डेटाबेस से डेटा स्टोर और प्राप्त करने के लिए एक तंत्र प्रदान करता है जिसे AstDB कहा जाता है। आधुनिक Asterisk (Asterisk 22 सहित) में AstDB को **SQLite3** (फ़ाइल `/var/lib/asterisk/astdb.sqlite3`) द्वारा समर्थित किया जाता है; Asterisk 1.8 और उससे पहले के संस्करण Berkeley DB v1 का उपयोग करते थे। यह Windows रजिस्ट्री डेटाबेस के समान है जो family और keys की पदानुक्रमित अवधारणा का उपयोग करता है। डेटा Asterisk के पुनरारंभ (restarts) के बीच बना रहता है। family/key API पुराने बैकएंड से अपरिवर्तित है; केवल ऑन-डिस्क स्टोरेज प्रारूप बदल गया है।

### फंक्शन्स, एप्लीकेशन्स, और CLI कमांड्स

कुछ फंक्शन्स, एप्लीकेशन्स, और CLI कमांड्स हैं जो AstDB के साथ काम करते हैं:

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

उदाहरण:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

AstDB में हेरफेर करने के लिए कुछ एप्लीकेशन्स का उपयोग किया जा सकता है:

- DB_DELETE(<family/key>) — फंक्शन जो एक सिंगल key को रिटर्न और डिलीट करता है
- DBdeltree(<family>) — एप्लीकेशन जो पूरी family/subtree को डिलीट करती है

पुराना `DBdel()` एप्लीकेशन अब Asterisk 22 में मौजूद नहीं है। एक सिंगल key को `DB_DELETE()` dialplan फंक्शन के साथ डिलीट करें — उदाहरण के लिए `Set(x=${DB_DELETE(family/key)})` या, एक राइट ऑपरेशन के रूप में, `Set(DB_DELETE(family/key)=)`। `DBdeltree()` (पूरी family/subtree को डिलीट करना) अभी भी एक एप्लीकेशन है।

keys को सेट और डिलीट करने के लिए CLI कमांड्स का उपयोग करना भी संभव है:

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### कॉल फॉरवर्ड, DND, और ब्लैकलिस्ट लागू करना

इस उदाहरण में, आप सीखेंगे कि कॉल फॉरवर्ड इमीडिएट और कॉल फॉरवर्ड ऑन बिजी को कैसे लागू किया जाए। हम कॉल फॉरवर्ड इमीडिएट को प्रोग्राम करने के लिए *21* और कॉल फॉरवर्ड ऑन बिजी स्टेटस को प्रोग्राम करने के लिए *61* का उपयोग करेंगे। प्रोग्रामिंग को रद्द करने के लिए, क्रमशः #21# और #61# का उपयोग करें। डेटाबेस को पॉप्युलेट करने के लिए उपरोक्त उदाहरण का उपयोग करें। उपयोग की गई families:

- CFIM – Call Forward Immediate
- CFBS – Call Forward on Busy status
- DND – Do Not Disturb

डेटाबेस को डायल करके पॉप्युलेट करने का प्रयास करें:

- *21* (कॉल फॉरवर्डिंग इमीडिएट के लिए डेस्टिनेशन extension)
- *61* (कॉल फॉरवर्डिंग ऑन बिजी स्टेटस के लिए डेस्टिनेशन extension)
- *41* (डू नॉट डिस्टर्ब पर डालने के लिए extension)

जोड़ी गई families, keys, और values को देखने के लिए CLI कमांड database show का उपयोग करें।

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### कॉल फॉरवर्ड, ब्लैकलिस्ट, DND

सब-रूटीन यह सत्यापित करता है कि क्या डेटाबेस में CFIM, CFBS, या DND के अनुरूप key:value जोड़े मौजूद हैं, और फिर उन्हें उचित रूप से संभालता है। निम्नलिखित सब-रूटीन डायलिंग रूटीन को कॉल करता है:

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## ब्लैकलिस्ट का उपयोग करना

पुराने `LookupBlacklist()` एप्लिकेशन को Asterisk से **हटा** दिया गया है (यह पुराने "priority+101 jump" तंत्र के साथ ही गायब हो गया)। Asterisk 22 में आप सीधे `DB_EXISTS()` फ़ंक्शन (जो एक की (key) की जांच करता है और, मिलने पर, उसका मान `${DB_RESULT}` में प्रदर्शित करता है) और `GotoIf` के साथ एक ब्लैकलिस्ट बनाते हैं। प्रत्येक ब्लॉक किए गए नंबर को एक `blacklist` फ़ैमिली में एक की (key) के रूप में स्टोर करें, फिर अपने इनकमिंग context के शीर्ष पर कॉलर ID की जांच करें:

```
[incoming]
exten => s,1,GotoIf($[${DB_EXISTS(blacklist/${CALLERID(num)})}]?blocked,s,1)
exten => s,n,Dial(PJSIP/4000,20,tT)
exten => s,n,Hangup()
[blocked]
exten => s,1,Answer()
exten => s,2,Playback(blockedcall)
exten => s,3,Hangup()
```

`DB_EXISTS(blacklist/${CALLERID(num)})` तब `1` लौटाता है जब कॉलर का नंबर डेटाबेस में मौजूद होता है (कॉल को `blocked` context में भेजते हुए) और अन्यथा `0` लौटाता है, इसलिए कॉल सामान्य `Dial()` पर आगे बढ़ती है।

ब्लैकलिस्ट में एक नंबर डालने के लिए, हम पहले वाले संसाधन का ही उपयोग कर सकते हैं, जिसमें *31* के बाद उन extension को डायल किया जाता है जिन्हें ब्लैकलिस्ट करना है। ब्लैकलिस्ट से कोई नंबर हटाने के लिए, आपको #31# के बाद वह नंबर डायल करना चाहिए जिसे हटाना है।

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

आप कंसोल CLI का उपयोग करके भी ब्लैकलिस्ट में नंबर डाल सकते हैं:

```
*CLI>database put blacklist <name/number> 1
```

नोट: की (key) के साथ कोई भी मान जोड़ा जा सकता है। `DB_EXISTS()` परीक्षण की (key) को खोजता है, मान को नहीं। ब्लैकलिस्ट से नंबर मिटाने के लिए, आप इसका उपयोग कर सकते हैं:

```
*CLI>database del blacklist <name/number>
```

## समय-आधारित contexts

निम्नलिखित चित्र में, हमारे पास तीन contexts वाला एक dialplan है। [incoming] context वह स्थान है जहाँ आमतौर पर कॉल प्राप्त की जाती हैं। हमने इसमें चार पंक्तियाँ शामिल की हैं जो सिस्टम के समय के आधार पर व्यवहार बदलती हैं, जैसा कि नीचे उदाहरण में दिया गया है:

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

आधुनिक Asterisk (22 सहित) time-include फ़ील्ड्स को **commas** से अलग करता है, न कि pipes से। पुराने pipe प्रारूप (`include => context|times|weekdays|mdays|months`) को एक सामान्य literal context नाम के रूप में पार्स किया जाता है और यह बिना किसी त्रुटि के समय की किसी भी शर्त को लागू करने में विफल रहता है।

सामान्य कामकाजी घंटों के दौरान, प्रोसेसिंग को mainmenu पर रीडायरेक्ट कर दिया जाएगा, जहाँ यह संभवतः आने वाली कॉल को संभालने के लिए एक IVR को कॉल करेगा। यदि कॉल कामकाजी घंटों के बाद आती है, तो यह ${SECURITY} variable में परिभाषित security extension को कॉल करेगी। यदि security extension कॉल का उत्तर नहीं देता है, तो इसे ऑपरेटर के voicemail पर भेज दिया जाएगा।

![10-dialplan-advanced-features figure 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figure 12](../images/10-dialplan-advanced-features-img12.png)

## gotoiftime() का उपयोग करके समय-आधारित संदेश

GotoIfTime() का सिंटैक्स नीचे दिखाया गया है।

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

Asterisk 22 में फ़ील्ड विभाजक (field separator) **अल्पविराम (comma)** है, न कि पाइप (पाइप प्रारूप को Asterisk 1.6 में हटा दिया गया था)। एक वैकल्पिक `timezone` फ़ील्ड समर्थित है, और प्रत्येक ब्रांच लेबल सामान्य `[[context,]extension,]priority` प्रारूप का उपयोग करता है।

यह एप्लिकेशन समय-आधारित context को प्रतिस्थापित कर सकता है और इसे समझना तथा पढ़ना आसान लगता है। आप समय को निम्नानुसार निर्दिष्ट कर सकते हैं:

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=1 से 31 तक की संख्या
- <hour>=0 से 23 तक की संख्या
- <minute>=0 से 59 तक की संख्या
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

दिनों और महीनों के नाम केस-सेंसिटिव (case sensitive) नहीं होते हैं।

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

पिछला स्टेटमेंट प्रोसेसिंग को normalhours context में extension s पर स्थानांतरित कर देता है यदि कॉल सोमवार से शुक्रवार तक सुबह 08:00 बजे से शाम 06:00 बजे के बीच आती है।

## DISA का उपयोग करके नया डायल टोन प्राप्त करना

DISA, या "direct inward system access," एक ऐसी प्रणाली है जो उपयोगकर्ताओं को दूसरा डायल टोन प्राप्त करने की अनुमति देती है। यह उपयोगकर्ताओं को किसी अन्य गंतव्य के लिए फिर से डायल करने की अनुमति देता है। इसका उपयोग अक्सर तकनीशियनों द्वारा सप्ताहांत पर तकनीकी सहायता के लिए लंबी दूरी की कॉल डायल करते समय किया जाता है; अपने घरों से सीधे गंतव्य पर डायल करने के बजाय, वे कार्यालय के DISA नंबर पर कॉल करते हैं, एक डायल टोन प्राप्त करते हैं, और फिर गंतव्य पर कॉल करते हैं। लंबी दूरी का शुल्क घर के फोन के बजाय कंपनी पर लगता है।

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

उदाहरण:

```
exten => s,1,DISA(no-password,default)
```

पिछले कथन का उपयोग करते हुए, उपयोगकर्ता PBX को डायल करता है और—बिना किसी पासवर्ड की आवश्यकता के—एक डायल टोन प्राप्त करता है। DISA का उपयोग करने वाली कोई भी कॉल `default` context का उपयोग करके संसाधित की जाएगी। इस एप्लिकेशन के तर्कों में एक वैश्विक पासवर्ड या फ़ाइल के भीतर व्यक्तिगत पासवर्ड शामिल हैं। यदि कोई context निर्दिष्ट नहीं है, तो `disa` context मान लिया जाता है। यदि आप पासवर्ड फ़ाइल का उपयोग करते हैं, तो पूर्ण पथ निर्दिष्ट करना होगा। DISA बाहरी डायलिंग के लिए एक कॉलर ID भी निर्दिष्ट की जा सकती है। उदाहरण:

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22 तर्क विभाजक के रूप में अल्पविराम (commas) का उपयोग करता है (पाइप फॉर्म को 1.6 में हटा दिया गया था)। पहला तर्क या तो एक एकल पासकोड है या पासकोड फ़ाइल का पथ है, और जब कोई context नहीं दिया जाता है तो डिफ़ॉल्ट context `disa` होता है।

## समवर्ती कॉल्स को सीमित करना

GROUP() फ़ंक्शन आपको यह गिनने की अनुमति देता है कि एक ही समय में एक समूह में आपके पास कितने सक्रिय चैनल हैं। उदाहरण: रियो डी जनेरियो में आपकी एक शाखा है, जहाँ फ़ोन “_214X” पैटर्न का पालन करते हैं। यह स्थान एक लीज्ड लाइन द्वारा सेवित है, जिसमें वॉयस बैंडविड्थ के लिए 64K आरक्षित है। इस मामले में, अनुमत कॉल्स की अधिकतम संख्या 2 है (G.729, प्रति कॉल लगभग 31.2K)। रियो के लिए कॉल्स को दो तक सीमित करने के लिए:

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

Voicemail एक कंप्यूटरीकृत टेलीफोन उत्तर देने वाली प्रणाली है जो आने वाले ध्वनि संदेशों को रिकॉर्ड करती है, उन्हें डिस्क पर सहेजती है या ई-मेल के माध्यम से भेजती है। कभी-कभी इसमें एक निर्देशिका होती है जहाँ आप नाम से voicemail बॉक्स खोज सकते हैं। अतीत में, voicemail सिस्टम बहुत महंगे होते थे। अब, IP टेलीफोनी के साथ, voicemail एक मानक विशेषता बनता जा रहा है।

Voicemail को कॉन्फ़िगर करने के लिए, आपको निम्नलिखित चरणों से गुजरना चाहिए।

**चरण 1: `voicemail.conf` को संपादित करें और सामान्य पैरामीटर सेट करें।**

- `format` — संदेश रिकॉर्ड करने के लिए उपयोग किया जाने वाला codec (उदाहरण के लिए, wav49, wav, gsm)
- `serveremail` — ई-मेल सूचना किससे प्राप्त होनी चाहिए
- `maxmsg` — मेलबॉक्स में संदेशों की अधिकतम संख्या; इस सीमा के बाद, संदेशों को हटा दिया जाता है
- `maxsecs` — voicemail संदेश की अधिकतम लंबाई, सेकंड में
- `minsecs` — संदेश की न्यूनतम लंबाई, सेकंड में; इस सीमा से नीचे, कोई संदेश रिकॉर्ड नहीं किया जाता है
- `maxsilence` — संदेश के अंत के रूप में मानने के लिए मौन के कितने सेकंड

**चरण 2: `voicemail.conf` को संपादित करें और उपयोगकर्ताओं के मेलबॉक्स बनाएं।**

### Voicemail.conf

एक मेलबॉक्स को प्रति मेलबॉक्स एक पंक्ति के साथ परिभाषित किया जाता है, इस रूप में:

```
mailboxID => pincode,fullname,email,pager-email,options
```

क्षेत्र इस प्रकार हैं:

- **MailboxID** — आमतौर पर extension नंबर
- **Pincode** — voicemail सिस्टम तक पहुँचने के लिए पासवर्ड
- **Full name** — निर्देशिका एप्लिकेशन द्वारा उपयोग किया जाता है
- **E-mail** — voicemail सूचना के लिए पता
- **Pager e-mail** — SMS गेटवे या पेजर के माध्यम से सूचना के लिए पता
- **Options** — प्रति-मेलबॉक्स विकल्प (वही विकल्प जो `[general]` में हैं, लेकिन इस मेलबॉक्स पर लागू होते हैं)

Voicemail में कई विकल्प होते हैं जो इसके व्यवहार को नियंत्रित करते हैं। अभी के लिए, हम डिफ़ॉल्ट विकल्पों पर टिके रहेंगे और मेलबॉक्स परिभाषा पर ध्यान केंद्रित करेंगे। फ़ाइल में `[general]` अनुभाग के बाद, आप मेलबॉक्स ID को कॉन्फ़िगर करना शुरू करते हैं, प्रत्येक अपने स्वयं के context में। उदाहरण:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

कृपया फ़ाइल `voicemail.conf` में उन्नत विकल्पों की जाँच करें।

**चरण 3: फ़ाइल `extensions.conf` को कॉन्फ़िगर करें।**

पहले दिखाया गया `stdexten` सबरूटीन (*Subroutines with GOSUB* के अंतर्गत) बिल्कुल वही कॉल/voicemail हैंडलर है जिसकी आपको यहाँ आवश्यकता है: यह extension को डायल करता है और कॉल प्रवाह को उचित voicemail ग्रीटिंग (व्यस्त होने के लिए `b`, अनुपलब्ध होने के लिए `u`) पर पुनर्निर्देशित करने के लिए चैनल वेरिएबल `${DIALSTATUS}` के मान का उपयोग करता है। इसे `extensions.conf` में प्रत्येक extension से `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` के साथ कॉल करें।

## VoiceMailMain() एप्लिकेशन का उपयोग करना

voicemailmain() एप्लिकेशन का उपयोग voicemail मेलबॉक्स को कॉन्फ़िगर करने के लिए किया जाता है। उपयोगकर्ता एप्लिकेशन को डायल कर सकते हैं, अपनी ग्रीटिंग रिकॉर्ड कर सकते हैं, और अपना voicemail सुन सकते हैं। dialplan में एप्लिकेशन को कॉल करने के लिए, इसका उपयोग करें:

```
exten=>9000,1,VoiceMailMain()
```

नीचे आपको एप्लिकेशन के लिए उपलब्ध विकल्पों की सूची मिलेगी।

### Voicemail एप्लिकेशन सिंटैक्स

यह एप्लिकेशन कॉल करने वाले को मेलबॉक्स की एक निर्दिष्ट सूची के लिए संदेश छोड़ने की अनुमति देता है। जब कई मेलबॉक्स निर्दिष्ट किए जाते हैं, तो ग्रीटिंग पहले निर्दिष्ट मेलबॉक्स से ली जाएगी। यदि निर्दिष्ट मेलबॉक्स मौजूद नहीं है तो dialplan का निष्पादन रुक जाएगा। सिंटैक्स नीचे दिखाया गया है:

```
 [Synopsis]
Leave a Voicemail message.
[Description]
This application allows the calling party to leave a message for the specified
list of mailboxes. When multiple mailboxes are specified, the greeting will
be taken from the first mailbox specified. Dialplan execution will stop if
the specified mailbox does not exist.
The Voicemail application will exit if any of the following DTMF digits are
received:
    0 - Jump to the 'o' extension in the current dialplan context.
    * - Jump to the 'a' extension in the current dialplan context.
This application will set the following channel variable upon completion:
${VMSTATUS}: This indicates the status of the execution of the VoiceMail
application.
    SUCCESS
    USEREXIT
    FAILED
[Syntax]
VoiceMail(mailbox[@context][&mailbox[@context][&...]][,options])
[Arguments]
options
```

![10-dialplan-advanced-features figure 13](../images/10-dialplan-advanced-features-img13.png)

```
    b: Play the 'busy' greeting to the calling party.
    d([c]): Accept digits for a new extension in context <c>, if played
    during the greeting. Context defaults to the current context.
    g(#): Use the specified amount of gain when recording the voicemail
    message. The units are whole-number decibels (dB). Only works on supported
    technologies, which is DAHDI only.
    s: Skip the playback of instructions for leaving a message to the
    calling party.
    u: Play the 'unavailable' greeting.
    U: Mark message as 'URGENT'.
    P: Mark message as 'PRIORITY'.
```

सभी मामलों में, रिकॉर्डिंग शुरू होने से पहले beep.gsm फ़ाइल बजाई जाएगी। voicemail संदेश inbox डायरेक्टरी में संग्रहीत किए जाएंगे।

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

यदि कोई कॉलर घोषणा के दौरान 0 (शून्य) दबाता है, तो उसे voicemail के वर्तमान context में ‘o’ (आउट) extension पर भेज दिया जाएगा। इसका उपयोग ऑपरेटर के पास जाने के लिए किया जा सकता है। यदि रिकॉर्डिंग के दौरान कॉलर # दबाता है या साइलेंस लिमिट समाप्त हो जाती है, तो रिकॉर्डिंग रुक जाती है और कॉल अगली प्राथमिकता पर चली जाती है। सुनिश्चित करें कि आप voicemail बजने के बाद कॉल को हैंडल करते हैं, जैसा कि नीचे दिखाया गया है।

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### Voicemail संदेशों को urgent के रूप में टैग करना

आप कुछ संदेशों को “urgent” के रूप में टैग कर सकते हैं। इसके लिए दो तरीके उपलब्ध हैं:

- एप्लिकेशन voicemail() में विकल्प ‘U’ पास करें
- voicemail.conf फ़ाइल में review=yes निर्दिष्ट करें। यदि इस विकल्प का उपयोग किया जाता है, तो उपयोगकर्ता वॉयस निर्देश रिकॉर्ड करने के बाद संदेश को urgent के रूप में टैग करने में सक्षम होगा।

## Voicemail को e-mail पर भेजना

कुछ मामलों में (जैसे मेरे मामले में), हम voicemailmain() एप्लिकेशन का उपयोग करके ईमेल नहीं पढ़ते हैं। सभी संदेशों को ऑडियो अटैचमेंट के साथ ईमेल पर भेजना अधिक सरल और व्यावहारिक है। ‘attach’ और ‘delete’ पैरामीटर्स का उपयोग करके, आप सभी मेल को ईमेल पर भेज सकते हैं और उन्हें मेलबॉक्स से हटा सकते हैं।

```
attach=yes
delete=yes
```

Voicemail को ईमेल पर भेजने के लिए, voicemail एप्लिकेशन message transfer agent (MTA) का उपयोग करता है, जो आपके ऑपरेटिंग सिस्टम का एक घटक है। Debian MTA के रूप में Exim का उपयोग करता है। ईमेल भेजने वाला एप्लिकेशन ‘mailcmd’ पैरामीटर में परिभाषित होता है।

```
mailcmd =/usr/sbin/sendmail -t
```

Linux के Debian वितरण में, MTA Exim है। Debian में Exim को कॉन्फ़िगर करने के लिए, इसका उपयोग करें:

```
dpkg-reconfigure exim4-config
```

आप अपने MTA को सीधे SMTP या smarthost (आमतौर पर आपकी कंपनी का मेल सर्वर) के माध्यम से ईमेल भेजने के लिए चुन सकते हैं। Asterisk सर्वर से अपने ईमेल सर्वर पर ईमेल भेजने का सबसे अच्छा तरीका अपने ईमेल एडमिनिस्ट्रेटर के साथ सत्यापित करें।

## ई-मेल संदेश को कस्टमाइज़ करना

आप निम्नलिखित वेरिएबल्स को सेट करके यह नियंत्रित कर सकते हैं कि संदेश कैसे भेजे जाते हैं: ई-मेल विषय और ई-मेल बॉडी के लिए वेरिएबल्स:

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

ई-मेल बॉडी और विषय एक टेम्प्लेट से बनाए जाते हैं जिसे आप `voicemail.conf` के `[general]` सेक्शन में सेट करते हैं। आप बॉडी और विषय दोनों को संशोधित कर सकते हैं, लेकिन संदेश का आकार सीमा 512 बाइट्स है। टेम्प्लेट में, `\n` एक नई लाइन डालता है और `\t` एक टैब डालता है।

नीचे दिया गया `emailsubject` उदाहरण सीधा है। `emailbody` उदाहरण डिफ़ॉल्ट के बहुत करीब है; डिफ़ॉल्ट केवल CIDNAME दिखाता है जब वह null नहीं होता है, अन्यथा CIDNUM, या जब दोनों null होते हैं तो "an unknown caller" दिखाता है।

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Voicemail Web interface

Asterisk सोर्स डिस्ट्रीब्यूशन में `vmail.cgi` नाम की एक Perl स्क्रिप्ट होती है, जो Asterisk सोर्स ट्री में `contrib/scripts/vmail.cgi` पर स्थित है (यह अभी भी Asterisk 22 के साथ आती है)। कमांड `make install` इस इंटरफ़ेस को इंस्टॉल नहीं करती है; आपको सोर्स डायरेक्टरी से `make webvmail` चलाना होगा। इस स्क्रिप्ट के लिए सर्वर पर Perl कमांड इंटरप्रेटर और एक वेब सर्वर (जैसे Apache) का इंस्टॉल होना आवश्यक है।

```
make webvmail
```

`make webvmail` टारगेट स्क्रिप्ट को (setuid root के रूप में) आपके वेब सर्वर की CGI डायरेक्टरी (`HTTP_CGIDIR`) में इंस्टॉल करता है और सपोर्टिंग इमेज को `images/*.gif` से `HTTP_DOCSDIR/_asterisk` (डिफ़ॉल्ट रूप से `/var/www/html/_asterisk`) में कॉपी करता है। यदि वे पाथ आपके वेब सर्वर लेआउट से मेल नहीं खाते हैं, तो टारगेट चलाने से पहले टॉप-लेवल `Makefile` में `HTTP_CGIDIR` और `HTTP_DOCSDIR` वेरिएबल्स को एडिट करें।

## Voicemail notification

आप अपने फोन पर नया voicemail होने पर नोटिफिकेशन संदेश भेजने के लिए voicemail को कॉन्फ़िगर कर सकते हैं। Asterisk 22 में, Message Waiting Indication (MWI) PJSIP और SIP फोन के साथ-साथ DAHDI फोन के साथ भी काम करता है। अनसुने voicemail को इंगित करने के लिए, एक इंडिकेटर लाइट ब्लिंक कर सकती है या फोन एक शटर टोन बजा सकता है। आपको संबंधित चैनल कॉन्फ़िगरेशन फ़ाइल में mailbox को कॉन्फ़िगर करने की आवश्यकता है। उदाहरण: `pjsip.conf` (endpoint सेक्शन में):

```
mailboxes=8590
```

PJSIP में, mailbox हिंट को `pjsip.conf` के endpoint सेक्शन के अंदर `mailboxes` विकल्प के साथ सेट किया जाता है, न कि `sip.conf` के पुराने `mailbox=` के साथ। MWI सब्सक्रिप्शन को `res_pjsip_mwi` मॉड्यूल द्वारा संभाला जाता है।

![The Comedian Mail वेब इंटरफ़ेस (`vmail.cgi`): Asterisk Web-Voicemail लॉगिन — ब्राउज़र से voicemail चलाने, सहेजने, अग्रेषित करने या हटाने के लिए अपना mailbox और पासवर्ड दर्ज करें। यह अभी भी Asterisk 22 के साथ आता है और `make webvmail` के साथ इंस्टॉल होता है।](../images/10-dialplan-advanced-features-img14.png)

### Lab: Message Notification in the Phone

इस लैब का परीक्षण एक SIP softphone का उपयोग करके किया गया था।

1. `pjsip.conf` को संपादित करें और 4401 नामक डिवाइस के लिए endpoint सेक्शन में `mailboxes=4401` जोड़ें।
2. `extensions.conf` को संपादित करें और 4401 extensions पर voicemail रिकॉर्ड करने के लिए एक extension बनाएं।

```
exten=9008,1,voicemail(4401,b)
```

3. कंसोल पर जाएं और रिलोड करें।
4. SipPulse Softphone में, SIP अकाउंट सेटिंग्स खोलें और अकाउंट के लिए voicemail (message-waiting) चेकिंग सक्षम करें।
5. 9008 डायल करें और एक संदेश छोड़ें।
6. फोन पर संदेश आइकन देखें।

## directory एप्लिकेशन का उपयोग करना

यह एप्लिकेशन आपको डायल करने के लिए किसी उपयोगकर्ता को शीघ्रता से खोजने की अनुमति देता है। नामों और संबंधित extension की सूची voicemail कॉन्फ़िगरेशन फ़ाइल voicemail.conf से प्राप्त की जाती है। एप्लिकेशन के लिए सिंटैक्स को core show application directory का उपयोग करके दिखाया जा सकता है:

```
-= Info about application 'Directory' =-
[Synopsis]
Provide directory of voicemail extensions.
[Description]
This application will present the calling channel with a directory of
extensions from which they can search by name. The list of names and
corresponding extensions is retrieved from the voicemail configuration file,
"voicemail.conf".
This application will immediately exit if one of the following DTMF digits
are received and the extension to jump to exists:
'0' - Jump to the 'o' extension, if it exists.
'*' - Jump to the 'a' extension, if it exists.
[Syntax]
Directory([vm-context][,dial-context[,options]])
[Arguments]
vm-context
    This is the context within voicemail.conf to use for the Directory.
    If not specified and 'searchcontexts=no' in "voicemail.conf", then
    'default' will be assumed.
dial-context
    This is the dialplan context to use when looking for an extension
    that the user has selected, or when jumping to the 'o' or 'a' extension.
options
    e: In addition to the name, also read the extension number to the
    caller before presenting dialing options.
    f(n): Allow the caller to enter the first name of a user in the
    directory instead of using the last name.  If specified, the optional
    number argument will be used for the number of characters the user should
    enter.
    l(n): Allow the caller to enter the last name of a user in the
    directory.  This is the default.  If specified, the optional number
    argument will be used for the number of characters the user should enter.
    b(n):  Allow the caller to enter either the first or the last name
    of a user in the directory.  If specified, the optional number argument
    will be used for the number of characters the user should enter.
    m: Instead of reading each name sequentially and asking for
    confirmation, create a menu of up to 8 names.
    p(n): Pause for n milliseconds after the digits are typed.  This
    is helpful for people with cellphones, who are not holding the receiver
    to their ear while entering DTMF.
    NOTE: Only one of the <f>, <l>, or <b> options may be specified.
    *If more than one is specified*, then Directory will act as  if <b> was
    specified.  The number of characters for the user to type defaults to
    '3'.
```

### लैब: directory एप्लिकेशन का उपयोग करना

1. dialplan में दो extension जोड़ने के लिए voicemail.conf फ़ाइल को संपादित करें

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. अपने dialplan में इन extension को बनाएँ

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. कंसोल पर जाएँ और reload करें
4. 9006 डायल करें और प्रत्येक extension (4400, 4401) के लिए एक नाम रिकॉर्ड करें
5. 9007 डायल करें और एक extension के लिए अंतिम नाम के तीन अक्षर चुनें (Eas=327)। यदि यह सही विकल्प है, तो नाम पर ट्रांसफर करने के लिए '1' दबाएँ।

## Lab: Putting it all together

अब तक, आपने dialplan की कई अवधारणाएं सीखी हैं। आइए सभी applications, functions और अवधारणाओं को एक dialplan उदाहरण में रखें ताकि आप समझ सकें कि उन्हें एक साथ कैसे उपयोग किया जाता है। आइए नीचे दिए गए परिदृश्य के लिए आपको पूरे PBX कॉन्फ़िगरेशन के माध्यम से मार्गदर्शन करते हैं।

- 4 analog trunks
- 16 SIP-based extensions
- 3 service classes:
    - restrict (internal, local, और 1-800)
    - ld (long distance)
    - ldi (international)
- After-hours message
- Auto attendant

### Step 1 – Configuring channels

**Analog trunks (`chan_dahdi.conf`)।** सबसे पहले, हम DAHDI चैनल कॉन्फ़िगरेशन फ़ाइल `chan_dahdi.conf` में analog trunks को कॉन्फ़िगर करेंगे। इस मामले में, हम 4 FXO इंटरफेस वाले T400P Digium कार्ड का उपयोग करेंगे। आइए मान लें कि ड्राइवर पहले से लोड है और ड्राइवर कॉन्फ़िगरेशन फ़ाइल (/etc/dahdi/system.conf) सही ढंग से कॉन्फ़िगर की गई है।

![10-dialplan-advanced-features figure 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**SIP channels (`pjsip.conf`)।** हमने 2000 से 2099 तक की dialplan नंबरिंग चुनी है। दो codecs का उपयोग किया जाएगा: G.729 और G.711 ulaw। पहले वाले का उपयोग उन फ़ोनों के लिए किया जाएगा जो Internet या WAN पर Asterisk का उपयोग कर रहे हैं, जबकि दूसरे का उपयोग उन फ़ोनों के लिए किया जाएगा जो local network का उपयोग कर रहे हैं। `pjsip.conf` में, हम यह निर्धारित करेंगे कि कौन से उपकरण सेवा के प्रत्येक वर्ग (restrict, ld, ldi) से संबंधित होंगे। brute force हमलों के प्रति भेद्यता को कम करने के लिए, हम डिवाइस नामों के रूप में फ़ोन के MAC पते का उपयोग करेंगे। मैं दृढ़ता से सलाह देता हूं कि आप brute force हमलों से बचने के लिए मजबूत पासवर्ड का उपयोग करें!

हम एक transport और तीन पुन: प्रयोज्य templates को परिभाषित करते हैं — साझा codecs के साथ एक endpoint base, एक digest auth, और एक single-contact AOR — फिर प्रत्येक डिवाइस को templates से जोड़ते हैं और केवल वही बदलते हैं जो भिन्न है (इसका class-of-service context और credentials)। `host=dynamic` एक AOR बन जाता है जिसके विरुद्ध फ़ोन रजिस्टर होता है, और `directmedia` `direct_media` बन जाता है:

```ini
; pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[endpoint-base](!)
type=endpoint
disallow=all
allow=ulaw,gsm
direct_media=yes

[auth-digest](!)
type=auth
auth_type=digest

[aor-single](!)
type=aor
max_contacts=1

[00001A000002](endpoint-base)
context=restrict
auth=00001A000002
aors=00001A000002
mailboxes=20
[00001A000002](auth-digest)
username=00001A000002
password=#s2cr2t#
[00001A000002](aor-single)

[00001A000003](endpoint-base)
context=ld
dtmf_mode=rfc4733
auth=00001A000003
aors=00001A000003
mailboxes=20
[00001A000003](auth-digest)
username=00001A000003
password=#s3cr3t#
[00001A000003](aor-single)

[00001A000004](endpoint-base)
context=ldi
dtmf_mode=rfc4733
auth=00001A000004
aors=00001A000004
mailboxes=20
[00001A000004](auth-digest)
username=00001A000004
password=#s3cr3t#
[00001A000004](aor-single)
```

### Step 2 – Configure the dial plan

अब extensions.conf को कॉन्फ़िगर करना शुरू करते हैं। internal extensions और local dialing को परिभाषित करें

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

LD (long distance) को परिभाषित करें

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

International calls को परिभाषित करें

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Step 3 - Receiving calls using an auto-attendant

कॉल प्राप्त करने के लिए, दो contexts का उपयोग करें। पहला सामान्य-घंटों के संचालन के लिए है, जहां कॉल एक auto-attendant द्वारा प्राप्त की जाएगी। दूसरा after-hours के लिए है, जहां कॉलर को एक संदेश प्राप्त होगा जैसे "आपने कंपनी XYZ को कॉल किया है, हमारे सामान्य घंटे सुबह 08:00 बजे से शाम 06:00 बजे तक हैं; यदि आप गंतव्य extension नंबर जानते हैं तो आप अभी डायल करने का प्रयास कर सकते हैं या फ़ोन रख सकते हैं।" Menus: Normal-hours, After-hours नीचे दिए गए menus में, सिस्टम कॉलर को चेतावनी देने वाला एक संदेश चलाएगा कि कंपनी तक सामान्य कामकाजी घंटों के बाद संपर्क किया गया है, जिससे कॉलर को गंतव्य extension नंबर डायल करने की अनुमति मिलेगी (हो सकता है कि कोई सामान्य कामकाजी घंटों के बाद काम कर रहा हो)।

```
[incoming]
include=>normalhours,08:00-18:00,mon-fri,*,*
include=>afterhours,18:00-23:59,*,*,*
include=>afterhours,00:00-07:59,*,*,*
include=>afterhours,*,sat-sun,*,*
[normalhours]
exten=>s,1,Goto(mainmenu,s,1)
[afterhours]
exten=>s,1,Background(afterhours)
exten=>s,2,hangup()
exten=>i,1,hangup()
exten=>t,1,hangup()
include=>restrict
```

Menus: Main और Sales सामान्य कामकाजी घंटों के दौरान, कॉल का उत्तर एक auto-attendant menu द्वारा दिया जाता है, जिसे एक संदेश प्राप्त होता है जैसे "XYZ कंपनी में आपका स्वागत है; sales के लिए 1, tech support के लिए 2, training के लिए 3, या वांछित extension नंबर डायल करें"।

```
[globals]
OPERATOR=PJSIP/2060
SALES=PJSIP/2035
TECHSUPPORT=PJSIP/2004
TRAINING=PJSIP/2036
[mainmenu]
exten=> s,1,Background(welcome)
exten=>1,1,Goto(sales,s,1)
exten=>2,1,Goto(techsupport,s,1)
exten=>3,1,Goto(training,s,1)
exten=>i,1,Playback(Invalid)
exten=>i,2,hangup()
exten=>t,1,Dial(${OPERATOR},20,Tt)
include=>restrict
[sales]
exten=>s,1,Dial(${SALES},20,Tt)
[techsupport]
exten=>s,1,Dial(${TECHSUPPORT},20,Tt)
[training]
exten=>s,1,Dial(${TRAINING},20,Tt)
```

इन सभी कथनों के साथ, आपके dialing plan की कार्यक्षमता अब तैयार है। अगले भाग में, हम प्रदर्शित करेंगे कि PBX को कैसे संचालित किया जाए।

## सारांश

इस अध्याय में, आपने सीखा है कि IVR या ऑटो-अटेंडेंट का उपयोग करके कॉल कैसे प्राप्त की जाती हैं। आपने context समावेशन की अवधारणा का अध्ययन किया है और कुछ उदाहरणों को लागू किया है। बार-बार टाइपिंग से बचने के लिए subroutines का उपयोग किया गया था, और डेटा स्टोरेज की आवश्यकता वाले कार्यों (जैसे, call forward, do not disturb, blacklists) के लिए Asterisk डेटाबेस (AstDB, जो Asterisk 22 में SQLite3 द्वारा समर्थित है) का उपयोग किया गया था। अंत में, आपने सीखा है कि after-hours व्यवहार को कैसे लागू किया जाए और इन अवधारणाओं का उपयोग करके एक पूर्ण dialplan को लागू किया है।

## प्रश्नोत्तरी

1. समय-आधारित context include में `include => context,<times>,<weekdays>,<mdays>,<months>` प्रारूप का उपयोग किया जाता है। `include => normalhours,08:00-18:00,mon-fri,*,*` क्या करता है?
   - A. सोमवार से शुक्रवार, 08:00 से 18:00 बजे तक extension निष्पादित करें
   - B. सभी महीनों में हर दिन विकल्प निष्पादित करें
   - C. कुछ नहीं; प्रारूप अमान्य है
2. आधुनिक Asterisk (Asterisk 22 सहित) में, समय-आधारित `include =>` और `GotoIfTime()` के फ़ील्ड किस वर्ण द्वारा अलग किए जाते हैं?
   - A. पाइप `|`
   - B. अल्पविराम (comma) `,`
   - C. अर्धविराम (semicolon) `;`
   - D. स्लैश `/`
3. एक साथ कई channels को डायल करने के लिए (उन्हें एक साथ रिंग करने के लिए), आप उन्हें `Dial()` के भीतर ___ वर्ण के साथ अलग करते हैं।
4. एक voice menu जो caller द्वारा extension डायल करने की प्रतीक्षा करते समय एक prompt बजाता है, उसे आमतौर पर ___ application के साथ बनाया जाता है।
5. आप ___ statement का उपयोग करके `extensions.conf` के भीतर किसी अन्य फ़ाइल की सामग्री को शामिल कर सकते हैं (नोट: यह `include =>` context statement से अलग है)।
6. Asterisk 22 में, इन-बिल्ट AstDB डेटाबेस किसके द्वारा समर्थित है:
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. जब आप `Dial(type1/identifier1&type2/identifier2)` का उपयोग करते हैं, तो Asterisk प्रत्येक channel को क्रमिक रूप से डायल करता है, और उनके बीच 20 सेकंड प्रतीक्षा करता है।
   - A. गलत
   - B. सही
8. Background() application के साथ, आपको विकल्प चुनने के लिए DTMF अंक दबाने से पहले संदेश के समाप्त होने तक प्रतीक्षा करनी होगी।
   - A. गलत
   - B. सही
9. `Goto([[context,]extension,]priority)` सिंटैक्स को देखते हुए, निम्नलिखित में से कौन से Goto() application के मान्य आह्वान (invocations) हैं? (सभी लागू होने वाले विकल्पों को चिह्नित करें)
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Asterisk 22 dialplan में AstDB से एक single key को हटाने के लिए, आप उपयोग करते हैं:
    - A. `DBdel()` application
    - B. `DB_DELETE()` function
    - C. `DBdeltree()` application
    - D. `LookupBlacklist()` application

**उत्तर:** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
