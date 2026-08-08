# SIP trunking, DID और PSTN

एक PBX जो केवल खुद को ही कॉल कर सकता है, वह बहुत उपयोगी नहीं है। देर-सवेर हर सिस्टम को दुनिया के बाकी हिस्सों तक पहुंचना ही पड़ता है — पब्लिक स्विच्ड टेलीफोन नेटवर्क (PSTN), एक SIP प्रदाता, या कोई अन्य PBX। उन कॉल्स को ले जाने वाली कड़ी को **trunk** कहा जाता है। TDM युग में एक trunk एक भौतिक सर्किट होता था: एक T1/E1 PRI या एनालॉग FXO लाइनों का एक बंडल। आज यह लगभग हमेशा एक **SIP trunk** होता है — एक इंटरनेट टेलीफोनी सर्विस प्रोवाइडर (ITSP) के साथ एक तार्किक कनेक्शन, जो बाकी सब चीजों की तरह ही उसी IP नेटवर्क पर चलता है।

यह अध्याय दिखाता है कि PJSIP के साथ Asterisk 22 को एक ITSP से कैसे कनेक्ट किया जाए, रजिस्ट्रेशन-आधारित और IP-आधारित trunk के बीच चुनाव कैसे करें, इनबाउंड DID नंबरों को सही गंतव्य तक कैसे रूट करें, सही caller-ID और E.164 फॉर्मेटिंग के साथ आउटबाउंड कॉल्स कैसे भेजें, और कई trunks के बीच फेलओवर और लीस्ट-कॉस्ट रूटिंग कैसे बनाएं। हम trunks के लिए NAT हैंडलिंग और एक लैब के साथ समाप्त करते हैं जो एक दूसरे Asterisk (और SIPp) को एक मॉक ITSP के रूप में खड़ा करता है ताकि आप एक trunk के माध्यम से वास्तविक कॉल्स कर सकें।

यहाँ सब कुछ पुस्तक की Asterisk 22.10.0 लैब के विरुद्ध सत्यापित है; trunk ऑब्जेक्ट पैटर्न वही है जिसे *Building your first PBX with PJSIP* और *SIP & PJSIP in depth* में पेश किया गया था।

## Objectives

इस अध्याय के अंत तक, आप निम्नलिखित कार्य करने में सक्षम होंगे:

- Asterisk 22 को PJSIP के साथ एक ITSP से जोड़ना
- रजिस्ट्रेशन-आधारित और IP-आधारित (स्टेटिक) trunk के बीच चयन करना
- इनबाउंड DID को सही extension, IVR या queue पर रूट करना
- सही caller-ID और E.164 फॉर्मेटिंग के साथ आउटबाउंड कॉल को रूट करना
- `${DIALSTATUS}` के साथ trunk फेलओवर और लीस्ट-कॉस्ट रूटिंग बनाना
- ट्रांसपोर्ट और endpoint पर trunk के लिए NAT को हैंडल करना

## SIP trunk क्या है

SIP trunk आपके PBX और किसी अन्य SIP सिस्टम के बीच एक तार्किक (logical) वॉयस पाथ है। व्यवहार में वह "अन्य सिस्टम" दो चीजों में से एक होता है:

- **एक ITSP (Internet Telephony Service Provider)।** एक व्यावसायिक कैरियर जो आपको कॉल ओरिजिनेशन और टर्मिनेशन, और आमतौर पर फोन नंबरों (DIDs) का एक ब्लॉक बेचता है। आप Asterisk को प्रदाता के सिग्नलिंग होस्ट की ओर निर्देशित करते हैं, और प्रदाता आपकी कॉल्स को व्यापक PSTN से जोड़ता है। आधुनिक सिस्टम इसी तरह फोन नेटवर्क तक पहुँचते हैं — किसी टेलीफोनी हार्डवेयर की आवश्यकता नहीं होती।
- **एक PSTN gateway।** एक उपकरण (या कोई अन्य Asterisk) जिसमें भौतिक PSTN इंटरफेस होते हैं — एक PRI कार्ड, एनालॉग FXO पोर्ट, या एक GSM/4G gateway — और उन्हें आपके PBX के सामने SIP के रूप में प्रस्तुत करता है। गेटवे TDM-to-SIP रूपांतरण करता है; Asterisk के दृष्टिकोण से यह सिर्फ एक और SIP trunk है।

किसी भी तरह, PJSIP में एक trunk **सिर्फ एक endpoint** है। वही ऑब्जेक्ट फैमिली जिसका उपयोग आपने फोन के लिए किया था — `endpoint`, `auth`, `aor`, वैकल्पिक रूप से `identify` और `registration` — एक trunk बनाती है। अंतर विवरणों में है: एक trunk *outbound* प्रमाणीकरण करता है (आप क्लाइंट हैं, इसलिए क्रेडेंशियल्स `outbound_auth` में जाते हैं, `auth` में नहीं), यह आमतौर पर आपके लिए यूजर एजेंट को रजिस्टर नहीं करता है (आप *उसमें* रजिस्टर करते हैं, या वह आपको एक ज्ञात IP से ट्रैफिक भेजता है), और यह इनबाउंड कॉल्स को `from-internal` के बजाय `from-pstn` जैसे समर्पित context में लैंड करता है।

> **पुराने TDM trunk के साथ तुलना।** एक PRI आपको B-channels की एक निश्चित संख्या (T1 पर 23, E1 पर 30) देता था और एक समर्पित D-channel पर कॉल सेटअप का संकेत देता था (*Legacy channels* अध्याय देखें)। एक SIP trunk में कोई निश्चित चैनल संख्या नहीं होती है — क्षमता वही होती है जो आपकी बैंडविड्थ, आपके प्रदाता की नीति, और किसी भी `max_contacts`/concurrent-call सीमा की अनुमति देती है। कॉलर-ID, DID, और कॉल प्रोग्रेस जो पहले ISDN इंफॉर्मेशन एलिमेंट्स पर निर्भर थे, अब SIP हेडर और SDP पर निर्भर हैं।

ITSP आपके साथ ट्रैफिक का आदान-प्रदान करने के लिए दो तरीकों से सहमत होगा, और वे निर्धारित करते हैं कि आप trunk कैसे बनाते हैं: **registration-based** और **IP-based (static)**। हम बारी-बारी से प्रत्येक को कवर करेंगे।

## Registration-based trunks

Registration-based trunk वह मॉडल है जिसका उपयोग तब किया जाता है जब प्रदाता यह अपेक्षा करता है कि *आप* उनके सिस्टम में लॉग इन करें। आपका Asterisk समय-समय पर प्रदाता को एक SIP `REGISTER` भेजता है, जिसमें यूजरनेम और पासवर्ड के साथ प्रमाणीकरण (authentication) किया जाता है, ठीक उसी तरह जैसे कोई फोन आपके PBX में रजिस्टर होता है। यह तब सामान्य होता है जब आपका पब्लिक IP डायनामिक हो, जब आप NAT के पीछे हों, या जब प्रदाता ग्राहकों की पहचान IP एड्रेस के बजाय SIP क्रेडेंशियल्स से करता हो।

PJSIP में आउटबाउंड लॉगिन एक समर्पित `registration` ऑब्जेक्ट में रहता है। यह उस एकल `register =>` लाइन की जगह लेता है जिसका उपयोग हटाए गए `chan_sip` ड्राइवर द्वारा `sip.conf` में किया जाता था। यहाँ एक काल्पनिक प्रदाता के लिए एक पूर्ण रजिस्टरिंग trunk दिया गया है, जो पिछले अध्यायों के सत्यापित पैटर्न का पालन करता है — ध्यान दें `outbound_auth` (न कि `auth`), `server_uri`/`client_uri` (न कि `server`/`client`), endpoint पर `from_user`/`from_domain`, और `dtmf_mode=rfc4733`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-auth]
type=auth
auth_type=digest
username=4830001000
password=Lab-itsp-secret

[itsp-aor]
type=aor
contact=sip:itsp.example.com:5060

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:itsp.example.com:5060
client_uri=sip:4830001000@itsp.example.com:5060
contact_user=4830001000
retry_interval=60
```

ध्यान देने योग्य कुछ बातें:

- **`auth_type=digest`, न कि `userpass`।** दोनों एक ही डाइजेस्ट ऑथेंटिकेशन उत्पन्न करते हैं, लेकिन Asterisk 22 में `userpass` (और पुराना `md5`) **deprecated हैं और चुपचाप `digest` में परिवर्तित हो जाते हैं**। नए कॉन्फ़िगरेशन में `digest` को प्राथमिकता दें; आप अभी भी पुरानी फाइलों और इस पुस्तक के पिछले अध्यायों में `userpass` देखेंगे।
- **endpoint और registration दोनों पर `outbound_auth`।** Registration इसका उपयोग `REGISTER` को प्रमाणित करने के लिए करता है; endpoint इसका उपयोग उस `407 Proxy Authentication Required` का उत्तर देने के लिए करता है जिसे प्रदाता आउटबाउंड `INVITE` पर वापस भेजता है। वे एक `auth` ऑब्जेक्ट साझा कर सकते हैं।
- **`from_user` / `from_domain`।** कई प्रदाता उन कॉल्स को अस्वीकार कर देते हैं जिनके `From` हेडर में आपका अकाउंट नंबर और उनका डोमेन नहीं होता है। ये दो विकल्प ठीक यही सेट करते हैं।
- **`contact_user=4830001000`।** यह उस `Contact` का यूजर पार्ट बन जाता है जिसे आप रजिस्टर करते हैं, ताकि प्रदाता को पता चल सके कि इनबाउंड कॉल्स किस नंबर पर डिलीवर करनी हैं। यह पुरानी `register =>` लाइन पर `/9999` सफिक्स का आधुनिक समकक्ष है।
- **`retry_interval=60`।** यदि रजिस्ट्रेशन विफल हो जाता है, तो हर 60 सेकंड में पुनः प्रयास करें।

रीलोड के बाद, `pjsip show registrations` के साथ रजिस्ट्रेशन की पुष्टि करें। लैब में — जहाँ `itsp.example.com` वास्तव में उत्तर नहीं देता है — टेबल इस तरह दिखती है:

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

`(exp. Ns)` सफिक्स अगले प्रयास तक के सेकंड की गिनती करता है; एक बार जब यह शून्य से नीचे चला जाता है, तो पुनः प्रयास शुरू होने से पहले यह संक्षेप में `(exp. Ns ago)` पढ़ता है। एक लाइव प्रदाता के विरुद्ध, `Status` कॉलम में अगले रिफ्रेश तक शेष सेकंड के साथ `Registered` दिखाई देता है। `Rejected` (या `Unregistered`) का अर्थ है कि प्रदाता ने लॉगिन स्वीकार नहीं किया — `pjsip set logger on` चालू करें और `401`/`403` उत्तर पढ़ें, जो लगभग हमेशा गलत यूजरनेम, पासवर्ड, या `client_uri` डोमेन के कारण होता है।

## IP-based (static) trunks

दूसरा मॉडल किसी भी प्रकार के पंजीकरण (registration) की आवश्यकता नहीं रखता है। प्रदाता आपके सार्वजनिक IP पते को जानता है और कॉल सीधे उसी पर भेजता है; आप, बदले में, प्रदाता के ज्ञात सिग्नलिंग IP पर कॉल भेजते हैं। प्रमाणीकरण **source IP address** द्वारा होता है, न कि SIP क्रेडेंशियल्स द्वारा। यह उन trunks के लिए सामान्य है जो आपके द्वारा नियंत्रित दो सर्वरों के बीच होते हैं, या किसी ऐसे एंटरप्राइज़ trunk के लिए जहाँ दोनों पक्षों के पास static पते होते हैं।

मुख्य ऑब्जेक्ट `identify` है। यह Asterisk को बताता है: "*इस* IP से आने वाला कोई भी SIP अनुरोध *उस* endpoint से संबंधित है।" इसके बिना, PJSIP एक इनबाउंड अनुरोध को `From` उपयोगकर्ता द्वारा endpoint से मिलाने का प्रयास करता है, जिसे कैरियर का ट्रैफ़िक पूरा नहीं करेगा — इसलिए कॉल अस्वीकार कर दी जाएगी या `anonymous` endpoint पर चली जाएगी।

एक static trunk `registration` ऑब्जेक्ट को हटा देता है और `identify` को जोड़ता है:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-aor]
type=aor
contact=sip:203.0.113.10:5060

[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
```

`match` एक IP पता, एक CIDR रेंज, या एक होस्टनेम स्वीकार करता है। **होस्टनेम को कॉन्फ़िगरेशन लोड होने के समय केवल एक बार रिज़ॉल्व किया जाता है**, इसलिए यदि आपके प्रदाता का IP बदलता है तो आपको रिलोड करना होगा। ऐसे कैरियर के लिए जो कई मीडिया गेटवे प्रकाशित करता है, प्रत्येक सिग्नलिंग IP को सूचीबद्ध करें — आप `match` को दोहरा सकते हैं या एक CIDR दे सकते हैं:

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

`pjsip show identifies` के साथ सत्यापित करें कि Asterisk क्या स्वीकार करेगा। लैब से कैप्चर किया गया (`sipp-identify` लाइन लैब का पहले से मौजूद SIPp endpoint है):

```
*CLI> pjsip show identifies

 Identify:  <Identify/Endpoint...........................................................>
      Match:  <criteria...........................>
==========================================================================================

 Identify:  itsp-identify/itsp
      Match: 172.30.0.50/32

 Identify:  sipp-identify/sipp
      Match: 172.30.0.0/24

Objects found: 2
```

### सुरक्षा निहितार्थ

बिना प्रमाणीकरण वाला IP-आधारित trunk एक दरवाज़ा है, और `identify`/`match` उस पर लगा एकमात्र ताला है। यदि आप `match` को बहुत व्यापक रेंज देते हैं — या यदि कोई हमलावर source IP को स्पूफ (spoof) कर सकता है — तो कॉल आपके `from-pstn` context में बिना प्रमाणीकरण के आ जाती हैं। दो सुरक्षा उपाय, जिन्हें एक साथ उपयोग किया जाना चाहिए:

- **जितना संभव हो उतना संकीर्ण मिलान करें।** व्यापक CIDR के बजाय विशिष्ट होस्ट IP को प्राथमिकता दें। केवल प्रदाता के वास्तविक सिग्नलिंग IP ही `match` में होने चाहिए।
- **इसे ACL के साथ जोड़ें।** PJSIP किसी endpoint तक पहुँचने से पहले ही SIP लेयर पर ट्रैफ़िक को ड्रॉप कर सकता है, इसके लिए `type=acl` ऑब्जेक्ट (या `acl.conf`) का उपयोग करें:

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

एक `type=acl` सेक्शन को किसी संदर्भ की आवश्यकता नहीं होती है: `res_pjsip_acl` ऐसे प्रत्येक ऑब्जेक्ट को किसी भी endpoint तक पहुँचने से पहले *सभी* इनबाउंड SIP ट्रैफ़िक पर लागू करता है। (ऑब्जेक्ट पर `acl` और `contact_acl` विकल्प `acl.conf` से नामित नियम सूचियों को खींचते हैं, बजाय इसके कि ऊपर की तरह `permit`/`deny` को इनलाइन सूचीबद्ध किया जाए।) सिद्धांत वही है जो SIP अध्याय में था: सब कुछ अस्वीकार करें, फिर केवल उसी की अनुमति दें जिस पर आप भरोसा करते हैं। और आपका trunk context जो कुछ भी करे, **इसे कभी भी ऐसे context तक न पहुँचने दें जो PSTN पर वापस कॉल कर सके** बिना किसी जानबूझकर किए गए, प्रमाणित नियम के — यह टोल-फ्रॉड का क्लासिक छेद है।

> **मुझे किस मॉडल का उपयोग करना चाहिए?** यदि प्रदाता आपको उपयोगकर्ता नाम और पासवर्ड देता है, तो **registration** trunk का उपयोग करें। यदि वे आपका IP पता मांगते हैं और आपको अपना देते हैं, तो **identify** trunk का उपयोग करें। कुछ प्रदाता दोनों का समर्थन करते हैं; कई वास्तविक trunks एक पंजीकरण (ताकि प्रदाता आपको ढूंढ सके) को एक पहचान (ताकि प्रदाता के मीडिया गेटवे से इनबाउंड INVITEs का मिलान तब भी हो सके जब वे रजिस्ट्रार के अलावा किसी अन्य IP से आते हैं) के साथ जोड़ते हैं।

## इनबाउंड रूटिंग और DID हैंडलिंग

एक बार जब इनबाउंड कॉल आ जाती हैं, तो वे endpoint के `context` में पहुँचती हैं — यहाँ `from-pstn`। एक **DID** (Direct Inward Dialing number) केवल वह डायल किया गया नंबर है जिसे प्रदाता आपको request URI में देता है। dialplan में आपका काम प्रत्येक DID को एक गंतव्य (destination) पर मैप करना है: एक एकल extension, एक IVR, एक queue, या एक ring group।

प्रदाता द्वारा भेजा गया नंबर `from-pstn` में `${EXTEN}` के रूप में मैच किया जाता है। आप इसका कितना हिस्सा देखते हैं, यह प्रदाता पर निर्भर करता है — कुछ पूर्ण E.164 नंबर (`+4830001000`) भेजते हैं, कुछ राष्ट्रीय नंबर भेजते हैं, और कुछ केवल अंतिम कुछ अंक भेजते हैं। पैटर्न लिखने से पहले `pjsip set logger on` के साथ एक वास्तविक इनबाउंड कॉल का निरीक्षण करें और request URI को देखें।

### एक DID से एक extension

सबसे सरल मामला — एक एकल DID जिसे सीधे एक फोन पर रूट किया गया है:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### एक DID से एक IVR (ऑटो अटेंडेंट)

एक मुख्य नंबर जिसे फोन बजाने के बजाय एक मेनू के साथ उत्तर देना चाहिए:

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` वह ऑटो-अटेंडेंट context है जिसे आपने dialplan अध्यायों (`Background()` + `WaitExten()`) में बनाया था। DID को रूट करना केवल एक `Goto` है।

### एक DID से एक queue

एक सपोर्ट लाइन जिसे एक कॉल queue में जाना चाहिए:

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### एक साथ कई DID

जब आप नंबरों का एक ब्लॉक खरीदते हैं, तो एक पैटर्न dialplan को छोटा रखता है। मान लीजिए कि आपकी DID रेंज `4830003000`–`4830003099` है और प्रदाता पूरा नंबर भेजता है; प्रत्येक DID के अंतिम दो अंकों को extension `60xx` पर मैप करें:

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}` अंतिम दो अंक लेता है (negative offset दाईं ओर से गिना जाता है), इसलिए `4830003007` पर `PJSIP/6007` बजता है। `GoSub` या एक Asterisk डेटाबेस (`AstDB`/`func_odbc`) के साथ बनाई गई एक `did => extension` लुकअप टेबल और भी बेहतर तरीके से स्केल करती है, लेकिन कुछ नंबरों के लिए स्पष्ट पैटर्न सबसे सरल होते हैं।

> **बेमेल (unmatched) DID को पकड़ें।** `from-pstn` में एक `i` (invalid) extension जोड़ें ताकि गलत तरीके से रूट किया गया इनबाउंड नंबर चुपचाप ड्रॉप होने के बजाय कोई घोषणा बजाए या ऑपरेटर को रिंग करे:
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## आउटबाउंड रूटिंग, caller-ID और E.164

आउटबाउंड कॉल दूसरी दिशा में प्रवाहित होती हैं: एक इंटरनल फोन एक नंबर डायल करता है, आपका dialplan उससे मेल खाता है, किसी भी एक्सेस प्रीफिक्स को हटाता है, वह caller-ID सेट करता है जिसकी प्रदाता अपेक्षा करता है, और कॉल को `Dial(PJSIP/<number>@itsp)` के साथ trunk endpoint को सौंप देता है।

### कॉल को trunk पर भेजना

एक trunk के लिए चैनल सिंटैक्स `PJSIP/<number>@<endpoint>` है: `@` से पहले का भाग आउटबाउंड रिक्वेस्ट URI का यूजर हिस्सा बन जाता है, और `@` के बाद का भाग उस endpoint का नाम बताता है जिसका `aor` `contact` डेस्टिनेशन होस्ट प्रदान करता है। एक क्लासिक "बाहरी लाइन के लिए 9 डायल करें" नियम:

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` नंबर भेजे जाने से पहले शुरुआती `9` एक्सेस कोड को हटा देता है। पैटर्न `_9NXXXXXXXXX` `9` और 10-अंकों के नंबर से मेल खाता है जिसका पहला अंक 2–9 है; इसे अपने dialplan के अनुसार समायोजित करें।

### आउटबाउंड कॉल पर Caller-ID

अधिकांश ITSP उस caller-ID को अनदेखा कर देते हैं — या सक्रिय रूप से अस्वीकार कर देते हैं — जो आपके स्वामित्व वाला नंबर नहीं है। आउटबाउंड caller-ID नंबर को ऊपर दिखाए अनुसार `Dial()` से पहले `CALLERID(num)` फंक्शन के साथ अपने DIDs में से एक पर सेट करें। आप नाम भी सेट कर सकते हैं:

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

यदि प्रदाता अभी भी आपके caller-ID नाम को हटा देता है या ओवरराइड कर देता है, तो यह उनकी नीति है — कई कैरियर प्रदर्शित नाम को नंबर पर आधारित अपने स्वयं के CNAM डेटाबेस से लेते हैं, न कि आपके `From` हेडर से।

दो endpoint विकल्प इसके साथ इंटरैक्ट करते हैं:

- **`from_user`** SIP स्तर पर `From` हेडर का यूजर हिस्सा सेट करता है, जिसका उपयोग कुछ प्रदाता `CALLERID(num)` की परवाह किए बिना आपके खाते की पहचान करने के लिए करते हैं।
- **`trust_id_outbound`** (डिफ़ॉल्ट `no`) यह नियंत्रित करता है कि क्या Asterisk आउटबाउंड रूप से गोपनीयता-संवेदनशील पहचान हेडर (`P-Asserted-Identity`/`P-Preferred-Identity`) भेजेगा। इसे तब तक बंद रखें जब तक कि आपका प्रदाता यह दस्तावेजीकरण न करे कि उन्हें PAI चाहिए, ऐसी स्थिति में `trust_id_outbound=yes` और `send_pai=yes` सेट करें।

### E.164 में सामान्यीकरण (Normalizing)

E.164 अंतरराष्ट्रीय नंबर प्रारूप है: एक शुरुआती `+`, कंट्री कोड, फिर राष्ट्रीय नंबर, जिसमें कोई स्पेस या विराम चिह्न नहीं होता (उदाहरण के लिए `+5548999990000` या `+14155550100`)। कैरियर तेजी से trunk पर E.164 की अपेक्षा करते हैं — या मांग करते हैं। dialplan में फॉर्मेटिंग को बिखेरने के बजाय, आउटबाउंड context में एक बार सामान्यीकरण करें।

एक उत्तर-अमेरिकी उदाहरण जो 10-अंकों के स्थानीय नंबर, 11-अंकों के `1`-प्रीफिक्स वाले नंबर, या पहले से E.164 नंबर को स्वीकार करता है, और हमेशा trunk को `+1…` प्रस्तुत करता है:

```
[from-internal]
; 10-digit local: 4155550100  -> +14155550100
exten => _NXXNXXXXXX,1,Set(E164=+1${EXTEN})
 same =>            n,Goto(send-pstn,${E164},1)

; 11-digit with national prefix: 14155550100 -> +14155550100
exten => _1NXXNXXXXXX,1,Set(E164=+${EXTEN})
 same =>             n,Goto(send-pstn,${E164},1)

; already E.164: the user dialled + first
exten => _+X.,1,Goto(send-pstn,${EXTEN},1)

[send-pstn]
exten => _+X.,1,Set(CALLERID(num)=+14155550000)
 same =>     n,Dial(PJSIP/${EXTEN}@itsp,60,tT)
 same =>     n,Hangup()
```

कुछ प्रदाता `+` चाहते हैं; अन्य केवल अंक चाहते हैं। यदि आपका प्रदाता `+` को अस्वीकार करता है, तो इसे बाहर जाते समय `Dial` में `${EXTEN:1}` के साथ हटा दें। मुख्य बात यह है कि प्रारूप संबंधी सभी जानकारी एक ही स्थान पर रहती है, इसलिए प्रदाता बदलना — या दूसरा प्रदाता जोड़ना — केवल एक लाइन का बदलाव है।

## Failover और least-cost routing

एक trunk के साथ, प्रदाता (provider) के आउटेज का मतलब है कि कोई आउटबाउंड कॉल नहीं हो पाएगी। दो या अधिक trunk के साथ, आप स्वचालित रूप से failover कर सकते हैं और प्रति गंतव्य सबसे सस्ता मार्ग भी चुन सकते हैं — जिसे *least-cost routing* (LCR) कहा जाता है।

### `${DIALSTATUS}` के साथ Failover

`Dial()` वापस आने पर `${DIALSTATUS}` चैनल वेरिएबल को सेट करता है। failover के लिए जिन मानों (values) की आपको परवाह करनी चाहिए, वे हैं `CHANUNAVAIL` (trunk तक बिल्कुल नहीं पहुँचा जा सका) और `CONGESTION` (कॉल अस्वीकार कर दी गई, उदाहरण के लिए सभी सर्किट व्यस्त हैं)। प्राथमिक trunk का प्रयास करें; यदि वह कॉल को पूरा नहीं कर सका, तो बैकअप पर जाएँ:

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

ध्यान दें कि `BUSY` या `NOANSWER` पर failover **न** करने का जानबूझकर निर्णय लिया गया है — इनका मतलब है कि *कॉल प्राप्त करने वाले पक्ष* तक पहुँचा गया और उन्होंने मना कर दिया, इसलिए किसी अन्य trunk पर पुनः प्रयास करने से वह फोन फिर से बजने लगेगा जिसने पहले ही मना कर दिया है (और इससे आपको दूसरी कॉल का शुल्क भी लग सकता है)। केवल तभी पुनः रूट करें जब *trunk स्वयं* विफल हो गया हो।

### एक पुन: प्रयोज्य (reusable) रूटिंग सबरूटीन

हर dialplan पैटर्न के लिए उस तर्क (logic) को दोहराना त्रुटिपूर्ण हो सकता है। इसे एक `GoSub` रूटीन में बदलें जो गंतव्य संख्या लेता है और प्रत्येक trunk को क्रम से आज़माता है:

```
[from-internal]
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Set(CALLERID(num)=4830001000)
 same =>   n,Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try2:end)
 same =>   n(try2),Dial(PJSIP/${NUM}@itsp_backup,60,tT)
 same =>   n(try2-chk),GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try3:end)
 same =>   n(try3),Dial(PJSIP/${NUM}@itsp_thirdparty,60,tT)
 same =>   n(end),Return()
```

अब प्रत्येक आउटबाउंड पैटर्न एक `GoSub` कॉल है, और trunk का क्रम बिल्कुल एक ही स्थान पर परिभाषित है।

### गंतव्य के अनुसार Least-cost routing

सच्चा LCR यह चुनता है कि कॉल कहाँ जा रही है, उसके आधार पर trunk का चयन करना। एक सामान्य तरीका गंतव्य उपसर्ग (prefix) का मिलान करना और कॉल के प्रत्येक वर्ग को उस प्रदाता को भेजना है जो इसके लिए सबसे सस्ता है — उदाहरण के लिए, अंतर्राष्ट्रीय कॉल को एक थोक वाहक (wholesale carrier) को और स्थानीय/राष्ट्रीय कॉल को अपने प्राथमिक प्रदाता को भेजना:

```
[from-internal]
; international (011 + ...) -> wholesale trunk, then fall back to primary
exten => _9011.,1,GoSub(dialout-intl,s,1(${EXTEN:1}))
 same =>      n,Hangup()
; everything else -> domestic routing
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout-intl]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Dial(PJSIP/${NUM}@itsp_wholesale,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?fb:end)
 same =>   n(fb),Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n(end),Return()
```

कुछ से अधिक उपसर्गों के लिए, रूट टेबल को एक डेटाबेस (`func_odbc`/`AstDB`) में संग्रहीत करें और पैटर्न को हार्ड-कोड करने के बजाय उपसर्ग द्वारा trunk को खोजें। dialplan छोटा रहता है और दरें एक ऐसी तालिका में रहती हैं जिसे आप लॉजिक को पुनः लोड किए बिना संपादित कर सकते हैं।

## NAT और trunks

NAT ट्रंक समस्याओं का सबसे सामान्य कारण है — आमतौर पर एकतरफा ऑडियो (one-way audio), या ऐसा ट्रंक जो रजिस्टर तो हो जाता है लेकिन कभी भी इनबाउंड कॉल प्राप्त नहीं करता है। इसका कारण वही है जो फोन के लिए होता है (जिसके बारे में *SIP & PJSIP in depth* और *Designing a VoIP network* में बताया गया है): Asterisk SIP और SDP में अपने पते के बारे में अपनी जानकारी देता है, और NAT के पीछे वह एक प्राइवेट RFC 1918 पता होता है जिस पर प्रदाता वापस रूट नहीं कर सकता।

ट्रंक के लिए इस समस्या को ठीक करने के दो भाग हैं — **transport** पर सेटिंग्स (आपका पब्लिक एड्रेस) और **endpoint** पर सेटिंग्स (प्रदाता के मीडिया के साथ कैसा व्यवहार करना है)।

### transport पर — आपका पब्लिक एड्रेस

जब Asterisk सर्वर स्वयं NAT के पीछे होता है (एक क्लाउड या ऑन-प्रेम बॉक्स जिसमें प्राइवेट IP और 1:1 पब्लिक IP हो), तो transport को उसका पब्लिक एड्रेस और यह बताएं कि कौन से नेटवर्क लोकल हैं। ये विकल्प एक बार `transport` पर सेट किए जाते हैं, और उस पर होने वाले सभी ट्रैफिक पर लागू होते हैं:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=172.30.0.0/24
local_net=10.0.0.0/8
external_media_address=203.0.113.50
external_signaling_address=203.0.113.50
```

- **`external_signaling_address`** — वह पब्लिक IP जिसे Asterisk `local_net` के बाहर के गंतव्यों के लिए SIP हेडर (`Via`, `Contact`) में लिखता है।
- **`external_media_address`** — वह पब्लिक IP जिसे Asterisk SDP `c=` लाइन में लिखता है ताकि RTP सही जगह पर वापस आ सके। आमतौर पर यह सिग्नलिंग एड्रेस के समान ही होता है।
- **`local_net`** — वे नेटवर्क जिन्हें Asterisk आंतरिक मानता है, ताकि यह LAN पीयर्स के लिए पतों को फिर से न लिखे (rewrite)। प्रत्येक आंतरिक सबनेट को सूचीबद्ध करें।

### endpoint पर — प्रदाता का मीडिया

दूसरा भाग उस प्रदाता को संभालता है जो स्वयं NAT के पीछे बैठा है, या जो अपने SDP में दिए गए पते के अलावा किसी अन्य पते से मीडिया भेजता है। इन्हें प्रति ट्रंक endpoint सेट करें:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com
```

- **`direct_media=no`** — मीडिया को दो लेग्स को सीधे बात करने देने के बजाय Asterisk के माध्यम से प्रवाहित होने दें। NAT के पार यह आवश्यक है, और यदि आप कॉल को रिकॉर्ड, ट्रांसकोड या मॉनिटर करना चाहते हैं तो वैसे भी इसकी आवश्यकता होती है।
- **`rtp_symmetric=yes`** — क्लासिक *comedia* व्यवहार: RTP को उस पते पर वापस भेजें जहाँ से मीडिया वास्तव में आया है, न कि उस पते पर जिसका SDP दावा करता है।
- **`force_rport=yes`** — `Via` हेडर पर भरोसा करने के बजाय, अनुरोध के सोर्स IP/पोर्ट (RFC 3581) से SIP का उत्तर दें।
- **`rewrite_contact=yes`** — इस endpoint से आने वाले इनबाउंड SIP संदेशों पर, `Contact` हेडर (या उपयुक्त `Record-Route` हेडर) को उस सोर्स IP एड्रेस और पोर्ट पर फिर से लिखें जहाँ से पैकेट वास्तव में आया था। विकल्प के अपने दस्तावेज़ीकरण के अनुसार, यह "NAT के पीछे मौजूद endpoints के साथ सर्वर को संचार करने में मदद करता है" और "TCP और TLS जैसे विश्वसनीय ट्रांसपोर्ट कनेक्शनों को पुन: उपयोग करने में मदद करता है।"

> **सुझाव — फोन बनाम ट्रंक।** `rewrite_contact` फोन के लिए लगभग हमेशा सही विकल्प होता है, क्योंकि उनका विज्ञापित संपर्क आमतौर पर एक प्राइवेट RFC 1918 पता होता है जो उन तक वापस रूट करने योग्य नहीं होता है। स्टेटिक IP-आधारित ट्रंक पर प्रदाता का संपर्क आमतौर पर पहले से ही एक सही पब्लिक एड्रेस होता है, इसलिए इसे फिर से लिखना अक्सर अनावश्यक होता है; कुछ ऑपरेटर इसे वहां बंद रखना पसंद करते हैं और इसे केवल रजिस्ट्रेशन ट्रंक और NAT वाले फोन के लिए सक्षम करते हैं। विकल्प का प्रलेखित प्रभाव केवल ऊपर दिया गया इनबाउंड `Contact`/`Record-Route` रीराइट है — इसलिए सुरक्षित अभ्यास यह है कि स्टेटिक ट्रंक पर इसे चालू करने से पहले अपने विशिष्ट कैरियर के साथ परीक्षण करें।

आप किसी भी endpoint पर प्रभावी सेटिंग्स की पुष्टि `pjsip show endpoint <name>` के साथ कर सकते हैं — `direct_media`, `rtp_symmetric`, `force_rport`, `rewrite_contact`, और बाकी सभी पैरामीटर डंप में प्रिंट किए जाते हैं।

## Lab — एक दूसरा Asterisk और SIPp के साथ एक मॉक ITSP

अभ्यास करने के लिए आपको किसी सशुल्क trunk की आवश्यकता नहीं है। पुस्तक की लैब पहले से ही एक निजी `172.30.0.0/24` नेटवर्क पर एक Asterisk 22.10.0 कंटेनर और एक SIPp कंटेनर चलाती है; हम SIPp कंटेनर को इनबाउंड कॉल करने वाले "कैरियर" के रूप में मानेंगे, और एक trunk endpoint जोड़ेंगे जो उन कॉल्स को `from-pstn` context में लैंड करेगा।

![Asterisk PBX और ITSP के बीच एक SIP trunk: PBX एक खाते के रूप में रजिस्टर होता है, आउटबाउंड कॉल्स `PJSIP/<num>@trunk` डायल करती हैं, और इनबाउंड कॉल्स `from-pstn` context में लैंड होती हैं।](images/trunk-diagram.png){width=100%}(../images/09-sip-trunking-fig01.png)

### 1. trunk endpoint जोड़ें

`lab/asterisk/etc/pjsip.conf` में एक IP-आधारित trunk जोड़ें जो लैब के SIPp होस्ट से मेल खाता हो और इनबाउंड कॉल्स को `from-pstn` में लैंड करे:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor

[itsp-aor]
type=aor
contact=sip:172.30.0.50:5060

[itsp-identify]
type=identify
endpoint=itsp
match=172.30.0.50
```

### 2. इनबाउंड DID को रूट करें

`lab/asterisk/etc/extensions.conf` में, एक `from-pstn` context जोड़ें जो उस DID का उत्तर दे जिसे मॉक कैरियर डायल करेगा और उसे प्लेबैक करे, फिर एक आउटबाउंड नियम जोड़ें:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID ${EXTEN} from ${CALLERID(num)})
 same =>             n,Answer()
 same =>             n,Playback(demo-congrats)
 same =>             n,Hangup()
exten => i,1,Playback(ss-noservice)
 same =>  n,Hangup()

[from-internal]
; outbound across the trunk
exten => _9X.,1,Set(CALLERID(num)=4830001000)
 same =>     n,Dial(PJSIP/${EXTEN:1}@itsp,30,tT)
 same =>     n,Hangup()
```

दोनों फाइलों को रीलोड करें (`core reload`) और पुष्टि करें कि trunk लोड हो गया है:

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. trunk के माध्यम से एक इनबाउंड कॉल करें

SIPp परिदृश्य को लक्ष्य उपयोगकर्ता के रूप में DID के साथ PBX की ओर इंगित करें। लैब में पहले से ही `lab/sipp/uac_9000.xml` मौजूद है, जो extension `9000` को INVITE करता है; इसे `uac_did.xml` पर कॉपी करें और request-URI/`To` उपयोगकर्ता को `9000` से बदलकर `4830001000` कर दें, फिर इसे SIPp कंटेनर से चलाएं:

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

Asterisk कंसोल पर कॉल को `from-pstn` पर हिट होते हुए देखें (`pjsip set logger on` इनबाउंड INVITE दिखाता है; `core show channels` `demo-congrats` को प्ले करने वाला `PJSIP/itsp-…` चैनल दिखाता है)। चूंकि SIPp स्रोत IP `identify` से मेल खाता है, इसलिए कॉल को बिना किसी प्रमाणीकरण के स्वीकार कर लिया जाता है — बिल्कुल वैसे ही जैसे एक स्थिर कैरियर trunk व्यवहार करता है।

### 4. trunk का निरीक्षण करें

अपने नोट्स के लिए trunk के पूर्ण कॉन्फ़िगरेशन को कैप्चर करें:

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (स्ट्रेच) इसे एक रजिस्ट्रेशन trunk बनाएं

*दूसरे* Asterisk कंटेनर को एक वास्तविक रजिस्ट्रार के रूप में खड़ा करें: इसे खाते `4830001000` के लिए एक `endpoint`+`auth`+`aor` दें, फिर PBX पर `identify` ब्लॉक को इस अध्याय की शुरुआत से `registration` ब्लॉक के साथ बदलें (`server_uri` को दूसरे कंटेनर के IP पर इंगित करते हुए)। `pjsip show registrations` के साथ पुष्टि करें कि स्थिति `Registered` पढ़ती है, फिर प्रत्येक दिशा में एक कॉल करें।

## सारांश

एक SIP trunk आपके PBX को बाहरी दुनिया से जोड़ता है, और PJSIP में यह केवल एक endpoint है जिसे उसी `endpoint` + `auth` + `aor` परिवार से बनाया गया है जिसे आप पहले से जानते हैं, साथ ही एक `identify` या एक `registration`। जब प्रदाता आपको एक username और password देता है, तो **registration trunk** (`type=registration` के साथ `outbound_auth`) का उपयोग करें; जब प्रमाणीकरण source IP द्वारा होता है, तो **IP-based trunk** (`type=identify` के साथ `match`) का उपयोग करें — और बाद वाले को एक संकीर्ण `match` और एक `acl` के साथ सुरक्षित करें, क्योंकि एक बिना प्रमाणीकरण वाला trunk टोल-फ्रॉड का लक्ष्य होता है। इनबाउंड, प्रदाता का DID आपके `from-pstn` context में `${EXTEN}` के रूप में आता है, जहाँ आप इसे किसी extension, एक IVR, या एक queue पर रूट करते हैं — पैटर्न और `${EXTEN:-N}` DID ब्लॉक को संक्षिप्त रखते हैं। आउटबाउंड, `CALLERID(num)` को उस नंबर पर सेट करें जिसके आप स्वामी हैं, एक स्थान पर E.164 में सामान्यीकृत करें, और कॉल को `PJSIP/<number>@trunk` को सौंप दें। कई trunks को आज़माकर और `${DIALSTATUS}` पर ब्रांचिंग करके लचीलापन बनाएँ (`CHANUNAVAIL`/`CONGESTION` का अर्थ है री-रूट; `BUSY`/`NOANSWER` ऐसा नहीं करते हैं), और least-cost routing को एक `GoSub` तालिका में रखें। अंत में, trunks के लिए NAT दो-तरफा होता है: आपके सार्वजनिक पते के लिए **transport** पर `external_media_address`/`external_signaling_address`/`local_net`, और प्रदाता के मीडिया के लिए **endpoint** पर `direct_media=no`, `rtp_symmetric`, `force_rport`, और `rewrite_contact`।

## प्रश्नोत्तरी

1. PJSIP में, किसी प्रदाता को *आउटबाउंड* कॉल या पंजीकरण प्रमाणित करने के लिए उपयोग किए जाने वाले क्रेडेंशियल्स को किसके द्वारा संदर्भित किया जाता है:
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. आपको `type=registration` ट्रंक का उपयोग कब करना चाहिए:
   - A. जब प्रदाता आपको आपके स्रोत IP पते से पहचानता है।
   - B. जब प्रदाता आपको एक उपयोगकर्ता नाम और पासवर्ड देता है और आपसे लॉग इन करने की अपेक्षा करता है।
   - C. जब आप कभी नहीं चाहते कि Asterisk एक `REGISTER` भेजे।
   - D. जब ट्रंक आपके द्वारा नियंत्रित दो स्टेटिक-IP सर्वरों के बीच हो।
3. `identify` ऑब्जेक्ट का `match` विकल्प क्या स्वीकार करता है (सभी लागू विकल्प चुनें):
   - A. एक IP पता
   - B. एक CIDR रेंज
   - C. एक होस्टनेम (कॉन्फ़िगरेशन लोड होने के समय रिज़ॉल्व किया गया)
   - D. केवल एक SIP उपयोगकर्ता नाम
4. Asterisk 22 पर, `auth_type=userpass` क्या है:
   - A. एकमात्र मान्य मान
   - B. अप्रचलित (deprecated) और `digest` में परिवर्तित
   - C. हटा दिया गया और लोड त्रुटि का कारण बनता है
   - D. आउटबाउंड पंजीकरण के लिए आवश्यक
5. एक इनबाउंड DID नंबर dialplan में इस प्रकार आता है:
   - A. `${CALLERID(num)}`
   - B. ट्रंक endpoint के `context` में `${EXTEN}`
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. डायल किए गए DID `4830003007` के अंतिम दो अंकों को एक extension पर भेजने के लिए, आप किसका उपयोग करेंगे:
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. किसी ट्रंक पर `Dial()` के बाद, आपको एक बैकअप ट्रंक पर फेलओवर करना चाहिए जिस पर `${DIALSTATUS}` मान हों (दो चुनें):
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. बाहर डायल करने से पहले प्रदाता को प्रस्तुत किए जाने वाले कॉलर-ID नंबर को सेट करने के लिए, उपयोग करें:
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. जब सर्वर NAT के पीछे हो तो Asterisk को उसका *सार्वजनिक* पता बताने वाले विकल्प कहाँ सेट किए जाते हैं:
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. ट्रंक endpoint पर `rtp_symmetric=yes` Asterisk को क्या करने के लिए प्रेरित करता है:
    - A. SRTP के साथ RTP को एन्क्रिप्ट करना
    - B. SDP को अनदेखा करते हुए, RTP को उस पते पर वापस भेजना जहाँ से मीडिया वास्तव में आया था
    - C. RTP को पूरी तरह से अक्षम करना
    - D. endpoints के बीच डायरेक्ट मीडिया को बाध्य करना

**उत्तर:** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
