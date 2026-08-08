# chan_sip से PJSIP पर माइग्रेशन: एक कुकबुक

यदि आप इसे Asterisk 13, 16, या 18 बॉक्स के साथ पढ़ रहे हैं जो अभी भी प्रोडक्शन में है, तो आपके पास एक समय सीमा है। `chan_sip` — जिसे `sip.conf` के माध्यम से कॉन्फ़िगर किया जाता था, वह मूल SIP चैनल ड्राइवर है — जिसे **Asterisk 17 में डेप्रिकेट (deprecated) कर दिया गया था, Asterisk 19 में डिफ़ॉल्ट बिल्ड से हटा दिया गया था, और Asterisk 21 में पूरी तरह से डिलीट कर दिया गया था**। यह Asterisk 22 LTS में मौजूद नहीं है। इसे वापस चालू करने के लिए कोई फ्लैग नहीं है, बचने के लिए कोई `noload` नहीं है, और इंस्टॉल करने के लिए कोई पैकेज नहीं है। Asterisk 22 में एकमात्र SIP चैनल ड्राइवर **PJSIP** (`res_pjsip` और `chan_pjsip`) है, जिसे `pjsip.conf` के माध्यम से कॉन्फ़िगर किया जाता है।

इसलिए अधिकांश साइटों के लिए Asterisk 22 पर अपग्रेड करना, वर्जन अपडेट होने के साथ-साथ एक *SIP माइग्रेशन प्रोजेक्ट* भी है। अच्छी खबर यह है कि वायर पर प्रोटोकॉल नहीं बदलता है — जो फोन कल रजिस्टर और कॉल करता था, वह कल भी रजिस्टर और कॉल करेगा — और Asterisk अनुवाद का शुरुआती 80% काम आपके लिए करने हेतु एक कन्वर्जन टूल प्रदान करता है। यह अध्याय एक व्यावहारिक कुकबुक है: कॉन्सेप्ट मैपिंग, कन्वर्जन स्क्रिप्ट, आपके पास मौजूद मामलों के लिए साइड-बाय-साइड `sip.conf` → `pjsip.conf` अनुवाद, इस बदलाव के साथ आने वाले dialplan और CLI परिवर्तन, realtime (डेटाबेस) माइग्रेशन, और एक चेकलिस्ट के साथ-साथ वे नुकसान जो लोगों को परेशान करते हैं।

यहाँ दी गई हर चीज़ को इस पुस्तक की Asterisk 22.10.0 लैब के विरुद्ध सत्यापित किया गया है। `chan_sip` पर गहन लीगेसी सामग्री — और मल्टी-डिवाइस `sip.conf` का एक पूर्ण कन्वर्जन — *Legacy channels* अध्याय में मौजूद है; यह अध्याय उसका केंद्रित, रेसिपी-शैली का साथी है।

## Objectives

इस अध्याय के अंत तक, आप निम्नलिखित कार्य करने में सक्षम होंगे:

- यह समझाना कि Asterisk 22 में `chan_sip` क्यों हटा दिया गया है और इसकी जगह क्या आया है
- `sip.conf` पीयर/यूज़र/फ्रेंड मॉडल को PJSIP ऑब्जेक्ट मॉडल (endpoint + aor + auth + identify + transport + registration) पर मैप करना
- `sip_to_pjsip.py` कन्वर्जन स्क्रिप्ट को चलाना और उसके आउटपुट की गंभीरता से समीक्षा करना
- सामान्य डिवाइस प्रकारों (रजिस्टरिंग फोन, इनबाउंड trunk, आउटबाउंड रजिस्ट्रेशन) को `sip.conf` से `pjsip.conf` में मैन्युअल रूप से अनुवादित करना
- NAT, मीडिया, DTMF, codec, और ऑथेंटिकेशन सेटिंग्स को विकल्प-दर-विकल्प माइग्रेट करना
- dialplan (`SIP/` → `PJSIP/`) और CLI (`sip show` → `pjsip show`) को अपडेट करना
- एक realtime/ARA डिप्लॉयमेंट को `sippeers`/`sipregs` से Sorcery `ps_*` टेबल्स में माइग्रेट करना
- माइग्रेशन चेकलिस्ट के माध्यम से काम करना और सामान्य गलतियों से बचना

## माइग्रेट क्यों करें

`chan_sip` ने लगभग दो दशकों तक Asterisk की सेवा की, लेकिन इस पर आर्किटेक्चरल ऋण था: एक अखंड मॉड्यूल, प्रति डिवाइस एक सिंगल कॉन्फ़िगरेशन ब्लॉक, कमजोर मल्टी-ट्रांसपोर्ट सपोर्ट, और एक SIP स्टैक जो RFCs से पीछे छूट गया था। **PJSIP** — जिसे Teluu के परिपक्व pjproject स्टैक पर बनाया गया और Asterisk 12 में पेश किया गया — इसे पूरी तरह से बदलने के लिए लाया गया था। Asterisk 21 तक, Asterisk प्रोजेक्ट ने अपना काम पूरा कर लिया और `chan_sip` को ट्री से हटा दिया।

आप किसी भी Asterisk 22 सिस्टम पर स्थिति की पुष्टि कर सकते हैं:

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip` *0 modules loaded* लौटाता है — यह वहां मौजूद ही नहीं है। PJSIP के अलावा माइग्रेट करने के लिए और कुछ नहीं है, इसलिए एकमात्र वास्तविक प्रश्न *कैसे* है, *क्या* नहीं।

## वैचारिक मानचित्रण: कोई एकल "peer" नहीं होता

वह मानसिक बदलाव जो `sip.conf` से आने वाले हर व्यक्ति को उलझा देता है, वह यह है: **PJSIP में कोई `[peer]` नहीं होता।** `sip.conf` में एक ब्रैकेट वाला ब्लॉक — एक `peer`, एक `user`, या एक `friend` — किसी डिवाइस के बारे में *सब कुछ* वर्णित करता था: उसके क्रेडेंशियल्स, उस तक पहुँचने का स्थान, उसके codec, उसका NAT व्यवहार, उसका dialplan context। PJSIP जानबूझकर उस एकल ब्लॉक को कई छोटे, एकल-उद्देश्य वाले ऑब्जेक्ट्स में विभाजित करता है, जिनमें से प्रत्येक को एक `type=` के साथ टैग किया जाता है, जो *एक-दूसरे को नाम से संदर्भित करते हैं*:

| PJSIP ऑब्जेक्ट (`type=`) | जिम्मेदारी |
| --- | --- |
| `endpoint` | डिवाइस की कॉल-हैंडलिंग पहचान: codec, context, DTMF, मीडिया, NAT, और उसके `auth`/`aors`/`transport` के संदर्भ |
| `aor` (Address of Record) | डिवाइस तक *कहाँ* पहुँचना है — पंजीकृत या स्थिर संपर्क, `max_contacts`, qualify |
| `auth` | इनबाउंड और/या आउटबाउंड प्रमाणीकरण के लिए क्रेडेंशियल्स (उपयोगकर्ता नाम/पासवर्ड) |
| `identify` | `From` उपयोगकर्ता के बजाय **source IP** द्वारा एक इनबाउंड अनुरोध को एक endpoint से मिलाना |
| `transport` | लिसनिंग सॉकेट(s): प्रोटोकॉल, बाइंड एड्रेस/पोर्ट, NAT/बाहरी पते |
| `registration` | Asterisk से किसी प्रदाता के लिए एक **outbound** REGISTER |

`friend`/`peer`/`user` का अंतर पूरी तरह से समाप्त हो जाता है — PJSIP में सब कुछ एक `endpoint` है। इसलिए एक एकल `sip.conf` friend आमतौर पर तीन ऑब्जेक्ट्स (`endpoint` + `auth` + `aor`) बन जाता है जो एक नाम साझा करते हैं और एक-दूसरे की ओर इशारा करते हैं:

```
                sip.conf                              pjsip.conf
            ┌──────────────┐              ┌──────────┐   ┌──────┐   ┌─────┐
            │   [2000]     │   becomes    │ endpoint │──▶│ auth │   │ aor │
            │ type=friend  │  ─────────▶  │  [2000]  │   │[2000]│   │[2000]│
            │ host=dynamic │              │  auth=───┼──▶└──────┘   └──────┘
            │ secret=...   │              │  aors=───┼───────────────▶ ▲
            └──────────────┘              └────┬─────┘
                                               │ transport=
                                               ▼
                                          ┌───────────┐
                                          │ transport │  (shared by all endpoints)
                                          └───────────┘
```

endpoint वह गोंद है जो सबको जोड़ता है। यह एक `transport` (या डिफ़ॉल्ट को इनहेरिट करता है), एक `auth` ऑब्जेक्ट, और एक या अधिक `aors` को नाम देता है। ऑब्जेक्ट मॉडल को *SIP & PJSIP in depth* में विस्तार से कवर किया गया है; यहाँ हमें इसकी आवश्यकता केवल हर अनुवाद के लक्ष्य के रूप में है।

## `sip_to_pjsip.py` रूपांतरण टूल

Asterisk एक Python स्क्रिप्ट के साथ आता है जो मौजूदा `sip.conf` को पढ़ता है और एक `pjsip.conf` लिखता है। यह CLI कमांड के रूप में नहीं चलता है — यह **Asterisk source tree** में रहता है, न कि इंस्टॉल की गई बाइनरी में:

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

लैब के Asterisk 22.10.0 पर इसका पूर्ण पथ, उदाहरण के लिए, `/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py` है। उसी डायरेक्टरी में `sip_to_pjsql.py` (realtime/SQL वैरिएंट, जिसे बाद में कवर किया गया है) और सहायक मॉड्यूल `astconfigparser.py`, `astdicts.py`, और `sqlconfigparser.py` मौजूद हैं।

### इसे चलाना

यह स्क्रिप्ट वैकल्पिक पोजीशनल आर्ग्युमेंट्स लेती है — `[input-file [output-file]]` — जो डिफ़ॉल्ट रूप से वर्तमान डायरेक्टरी में `sip.conf` और `pjsip.conf` होते हैं:

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

इसके एकमात्र वास्तविक विकल्प ये हैं:

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

यह इनपुट को पढ़ता है, `Converting to PJSIP...` प्रिंट करता है, और आउटपुट फ़ाइल लिखता है। आंतरिक रूप से यह प्रत्येक `sip.conf` सेक्शन को स्कैन करता है, और प्रति डिवाइस, मेल खाने वाले `endpoint`, `auth`, `aor`, `registration`, और (जहाँ यह उनका अनुमान लगा सकता है) `transport` ऑब्जेक्ट्स को उत्सर्जित करता है, और अगले सेक्शन में दिए गए विकल्प मैपिंग को स्वचालित रूप से लागू करता है।

### यह क्या करता है — और इसकी सीमाएँ

आउटपुट को **पहला ड्राफ्ट मानें, न कि तैयार फ़ाइल।** यह स्क्रिप्ट अपनी कमियों के बारे में स्पष्ट है: जो कुछ भी यह स्पष्ट रूप से मैप नहीं कर सकती, उसे आउटपुट फ़ाइल के शीर्ष पर एक स्पष्ट रूप से फेन्स्ड ब्लॉक में लिख दिया जाता है:

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[softphone]
qualify = yes
...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
```

उस वास्तविक अंश में ध्यान दें कि एक `sip.conf` पीयर से `qualify = yes` *non-mapped* ब्लॉक में चला गया — क्योंकि PJSIP, `qualify_frequency` (सेकंड) के साथ **aor** पर क्वालिफाई करता है, न कि डिवाइस पर किसी बूलियन के साथ, इसलिए स्क्रिप्ट इसे आपके द्वारा जानबूझकर सेट करने के लिए छोड़ देती है। व्यावहारिक सीमाएँ जिनके लिए योजना बनानी चाहिए:

- **Transports का अनुमान लगाया जाता है, डिज़ाइन नहीं किया जाता।** स्क्रिप्ट `bindport`/`bindaddr` से एक बुनियादी `transport-udp` उत्सर्जित करती है, लेकिन यह आपके TLS certs, आपकी TCP आवश्यकताओं, या आपके multi-bind लेआउट को नहीं जान सकती। ट्रांसपोर्ट की समीक्षा करें और उसे फिर से लिखें।
- **NAT और external addresses के लिए एक इंसान की आवश्यकता होती है।** `externaddr`/`localnet` शायद ठीक से न बच पाएँ; ट्रांसपोर्ट पर `external_media_address`, `external_signaling_address`, और `local_net` की मैन्युअल रूप से पुष्टि करें।
- **`qualify`, कस्टम टाइमर, और कुछ विकल्प "non-mapped" में चले जाते हैं।** उस ब्लॉक को ऊपर से नीचे तक पढ़ें और प्रत्येक के बारे में निर्णय लें।
- **Codec सूचियाँ, contexts, और सुरक्षा की समीक्षा की आवश्यकता है।** `disallow`/`allow`, dialplan `context` को सत्यापित करें, और सुनिश्चित करें कि कोई भी डिवाइस अनजाने में खुला न रह जाए।

इसलिए कार्यप्रवाह यह है: स्क्रिप्ट को एक *scratch* फ़ाइल में चलाएँ, उसका diff निकालें और समीक्षा करें, अच्छे हिस्सों को अपने वास्तविक `pjsip.conf` में शामिल करें, और फिर प्रोडक्शन से पहले पूरी तरह से परीक्षण करें।

## साइड-बाय-साइड अनुवाद

ये रेसिपी हैं। बाईं ओर `sip.conf`, दाईं ओर सत्यापित `pjsip.conf` समकक्ष (पृष्ठ की चौड़ाई के लिए यहाँ स्टैक किया गया है)। दाईं ओर के प्रत्येक option नाम और value की Asterisk 22 लैब में `config show help res_pjsip ...` के साथ जाँच की गई है।

### एक रजिस्टर होने वाला फोन (`host=dynamic`)

सबसे सामान्य डिवाइस: एक डेस्क फोन या softphone जो एक secret के साथ लॉग इन करता है और अपना स्थान रजिस्टर करता है।

**Legacy `sip.conf`:**

```
[2000]
type=friend
host=dynamic
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmfmode=rfc2833
secret=Sup3rSecret
qualify=yes
```

**Asterisk 22 `pjsip.conf`:**

```
[2000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
auth=2000
aors=2000

[2000]
type=auth
auth_type=digest
username=2000
password=Sup3rSecret

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

मुख्य कदम: `host=dynamic` एक `aor` बन जाता है जिसमें `max_contacts` होता है (डिवाइस अपना contact भरने के लिए REGISTER करता है); `secret=`, `type=auth` के अंदर `password=` बन जाता है; `qualify=yes`, endpoint पर नहीं, बल्कि **aor** पर `qualify_frequency=60` (सेकंड) बन जाता है। `max_contacts` को 1 से ऊपर तभी सेट करें यदि आप वास्तव में एक ही account को एक साथ कई डिवाइस पर चाहते हैं।

### एक इनबाउंड trunk (`host=<ip>` / `type=peer`)

एक प्रदाता जो आपको एक ज्ञात IP पते से कॉल भेजता है। यहाँ कोई पंजीकरण नहीं है — आप `identify` का उपयोग करके *carrier के ट्रैफ़िक को उसके स्रोत IP द्वारा* प्रमाणित करते हैं।

**Legacy `sip.conf`:**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp-in]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw

[itsp-in]
type=aor
contact=sip:203.0.113.10:5060

[itsp-in]
type=identify
endpoint=itsp-in
match=203.0.113.10
```

महत्वपूर्ण अनुवाद **`insecure=invite` → `identify`** है। `chan_sip` में, `insecure=invite` ने Asterisk को बताया "प्रमाणीकरण के लिए इस peer से आने वाले इनबाउंड INVITEs को चुनौती न दें।" PJSIP उसी प्रभाव को `type=identify`/`match=` के साथ *स्रोत IP को endpoint से मिला कर* प्राप्त करता है, जो अधिक स्पष्ट और अधिक सुरक्षित दोनों है। स्थिर `host=` एक स्थायी `contact=` बन जाता है जो `aor` पर होता है ताकि आप carrier को *आउटबाउंड* कॉल भी कर सकें। `match=` एक IP, एक CIDR रेंज, या एक hostname स्वीकार करता है (config-load के समय हल किया जाता है — यदि प्रदाता का IP बदलता है तो reload करें)।

### एक आउटबाउंड पंजीकरण (`register =>`)

जब प्रदाता चाहता है कि *आप* उनके यहाँ लॉग इन करें, तो `chan_sip` ने `[general]` में एक एकल `register =>` लाइन का उपयोग किया। PJSIP इसे एक समर्पित `type=registration` ऑब्जेक्ट और एक `outbound_auth` के साथ बदल देता है।

**Legacy `sip.conf`:**

```
[general]
register => 1020:supersecret@sip.example.com:5600/9999

[itsp]
type=peer
host=sip.example.com
port=5600
defaultuser=1020
secret=supersecret
fromuser=1020
fromdomain=sip.example.com
context=from-pstn
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
outbound_auth=itsp-auth
aors=itsp-aor
from_user=1020
from_domain=sip.example.com

[itsp-auth]
type=auth
auth_type=digest
username=1020
password=supersecret

[itsp-aor]
type=aor
contact=sip:sip.example.com:5600

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:sip.example.com:5600
client_uri=sip:1020@sip.example.com:5600
contact_user=9999
retry_interval=60
```

`register =>` फ़ील्ड्स को एक-से-एक मैप करें: `1020:supersecret` क्रेडेंशियल्स `auth` ऑब्जेक्ट बन जाते हैं (जिसे `outbound_auth` के रूप में संदर्भित किया जाता है); `@sip.example.com:5600`, `server_uri` बन जाता है; `/9999` प्रत्यय — वह user भाग जिस पर प्रदाता इनबाउंड कॉल डिलीवर करता है — `contact_user=9999` बन जाता है। `defaultuser`/`fromuser` और `fromdomain`, endpoint पर `from_user` और `from_domain` बन जाते हैं। ध्यान दें कि `outbound_auth` *दो बार* दिखाई देता है: पंजीकरण इसे REGISTER के लिए उपयोग करता है, endpoint इसे आउटबाउंड INVITEs पर `407` चुनौती का उत्तर देने के लिए उपयोग करता है।

## विकल्प-दर-विकल्प माइग्रेशन संदर्भ

जब आप मैन्युअल रूप से अनुवाद कर रहे हों (या स्क्रिप्ट के आउटपुट का ऑडिट कर रहे हों), तो यह तालिका एक लुकअप के रूप में कार्य करती है। प्रत्येक PJSIP विकल्प का नाम और उसका स्थान (endpoint / aor / auth / transport) Asterisk 22 लैब के विरुद्ध सत्यापित किया गया है।

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | कहाँ |
| --- | --- | --- |
| `[peer]` / `[user]` / `[friend]` | `type=endpoint` (+ `auth` + `aor`) | — |
| `host=dynamic` | `max_contacts=1` (device REGISTERs) | aor |
| `host=<ip/host>` | `contact=sip:<host>:<port>` | aor |
| `register => u:p@host/ext` | `type=registration` + `outbound_auth` | registration |
| `secret=` | `password=` | auth |
| `username=` / `defaultuser=` | `username=` | auth |
| `secret=` (auth method) | `auth_type=digest` | auth |
| `nat=force_rport,comedia` | `force_rport=yes` + `rewrite_contact=yes` + `rtp_symmetric=yes` | endpoint |
| `directmedia=yes/no` | `direct_media=yes/no` | endpoint |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` | endpoint |
| `disallow=` / `allow=` | `disallow=` / `allow=` (same syntax) | endpoint |
| `context=` | `context=` | endpoint |
| `qualify=yes` | `qualify_frequency=<seconds>` | aor |
| `insecure=invite` | omit auth; use `type=identify` + `match=` | identify |
| `fromuser=` / `fromdomain=` | `from_user=` / `from_domain=` | endpoint |
| `externaddr=` / `externip=` | `external_media_address=` + `external_signaling_address=` | transport |
| `localnet=` | `local_net=` | transport |

### `secret` → `auth` और `auth_type` पर एक टिप्पणी

`chan_sip` का `secret=`, `type=auth` ऑब्जेक्ट का `password=` फ़ील्ड बन जाता है। **authentication method** को `auth_type` के साथ सेट किया जाता है। `auth_type=digest` का उपयोग करें। पुराने मान `userpass` और `md5` अभी भी काम करते हैं लेकिन वे **deprecated हैं और चुपचाप `digest` में परिवर्तित हो जाते हैं** — जिसे सीधे लैब से सत्यापित किया गया है:

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

आप पुराने कॉन्फ़िगरेशन और कन्वर्ज़न स्क्रिप्ट के आउटपुट में (और इस पुस्तक के पिछले अध्यायों में) `auth_type=userpass` देखेंगे। यह हानिकारक नहीं है, लेकिन किसी भी नई चीज़ में `digest` लिखें।

### NAT, मीडिया, और DTMF का विवरण

ये तीनों वे क्षेत्र हैं जहाँ माइग्रेशन के बाद की अधिकांश "यह रजिस्टर तो होता है लेकिन ऑडियो नहीं है" वाली समस्याएँ उत्पन्न होती हैं। `chan_sip` शॉर्टहैंड `nat=force_rport,comedia` ने तीन व्यवहारों को एक विकल्प में समेट दिया था; PJSIP उन्हें अलग करता है ताकि आप प्रत्येक के बारे में तर्क कर सकें:

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

**media** के लिए, `directmedia`, `direct_media` बन जाता है (अंडरस्कोर ही पूरा बदलाव है); जब भी कॉल को Asterisk पर एंकर करना हो — NAT के पार, या रिकॉर्ड/ट्रांसकोड/ट्रांसफर करने के लिए — तो `direct_media=no` को बनाए रखें। **DTMF** के लिए, RFC को पुन: क्रमांकित किया गया था: `chan_sip` का `dtmfmode=rfc2833`, PJSIP का `dtmf_mode=rfc4733` है (वही आउट-ऑफ-बैंड telephone-event तंत्र, वर्तमान RFC संख्या)। लैब पुष्टि करती है कि मान्य `dtmf_mode` मान `rfc4733`, `inband`, `info`, `auto`, और `auto_info` हैं, जो डिफ़ॉल्ट रूप से `rfc4733` पर सेट होते हैं।

**codecs** के लिए, कुछ भी नहीं बदलता है: `disallow=all` जिसके बाद `allow=ulaw` (आदि) PJSIP endpoint पर समान सिंटैक्स का उपयोग करते हैं।

## Dialplan और CLI में बदलाव

माइग्रेशन केवल `pjsip.conf` पर ही समाप्त नहीं होता है। दैनिक उपयोग की दो चीजें बदल जाती हैं।

### चैनल स्ट्रिंग्स: `SIP/` → `PJSIP/`

`extensions.conf` में प्रत्येक `Dial()` और चैनल संदर्भ जिसे पुरानी तकनीक का नाम दिया गया था, उसे अपडेट किया जाना चाहिए:

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Trunk डायल स्ट्रिंग्स भी उसी पैटर्न का पालन करती हैं — `Dial(SIP/${EXTEN}@itsp)`, `Dial(PJSIP/${EXTEN}@itsp)` बन जाता है। PJSIP एक साथ AOR से जुड़े प्रत्येक संपर्क को रिंग करने के लिए `PJSIP_DIAL_CONTACTS()` फ़ंक्शन, और `PJSIP_HEADER()` / `PJSIP_MEDIA_OFFER()` dialplan फ़ंक्शंस भी जोड़ता है; अपने dialplan में `SIP/`, `SIPPEER`, `SIPCHANINFO`, और `CHANNEL(...)` SIP संदर्भों के लिए grep का उपयोग करें और प्रत्येक का अनुवाद करें।

### CLI: `sip show ...` → `pjsip show ...`

पूरा `sip ...` कमांड ट्री ड्राइवर के साथ ही समाप्त हो गया है। इसके विकल्प इस प्रकार हैं:

| `chan_sip` कमांड | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (या `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (या `core reload`) |

पुराने कमांड केवल अलग तरह से व्यवहार नहीं करते हैं — वे अब मौजूद ही नहीं हैं। लैब में, `sip show peers` का परिणाम *No such command* आता है, जबकि `pjsip show endpoints`, `pjsip show aors`, `pjsip show auths`, `pjsip show contacts`, `pjsip show registrations`, और `pjsip show identifies` सभी मौजूद हैं। सबसे उपयोगी ट्रबलशूटिंग कमांड — SIP पैकेट लॉगर जो `sip set debug` के साथ प्रत्येक संदेश को प्रिंट करता था — अब **`pjsip set logger on`** है (किसी एक peer पर ध्यान केंद्रित करने के लिए `pjsip set logger host <ip>` के साथ)।

## Realtime (ARA) माइग्रेशन

यदि आप डेटाबेस (Asterisk Realtime Architecture) से `chan_sip` चलाते थे, तो आपके
डिवाइस `sippeers` टेबल में और रजिस्ट्रेशन `sipregs` में रहते थे। PJSIP एक
पूरी तरह से अलग स्टोरेज लेयर — **Sorcery** — का उपयोग करता है, जिसमें *प्रति ऑब्जेक्ट प्रकार* एक टेबल होती है। मैपिंग इस प्रकार है:

| `chan_sip` realtime table | PJSIP / Sorcery table(s) |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (प्रत्येक एक पंक्ति, अलग-अलग की गई) |
| `sipregs` | `ps_contacts` (डायनामिक रजिस्ट्रेशन) |
| — (आउटबाउंड `register=>`) | `ps_registrations` |
| — (IP मैचिंग) | `ps_endpoint_id_ips` (the `identify` objects) |
| — (डोमेन उपनाम) | `ps_domain_aliases` |

वैचारिक विभाजन वही है जो फ्लैट-फाइल मामले में था: एक `sippeers` पंक्ति तीन टेबल (`ps_endpoints` + `ps_aors` + `ps_auths`) में *तीन* पंक्तियाँ बन जाती है, जो एक-दूसरे को endpoint नाम द्वारा संदर्भित करती हैं।

दो चीजें इसे आसान बनाती हैं:

- **स्कीमा आपके लिए जेनरेट किया जाता है।** Asterisk, `contrib/ast-db-manage/` के अंतर्गत Alembic माइग्रेशन प्रदान करता है जो हर `ps_*` टेबल बनाता है। DDL को हाथ से लिखने के बजाय वर्तमान PJSIP स्कीमा बनाने के लिए `config` डेटाबेस के विरुद्ध `alembic upgrade head` चलाएं।
- **एक SQL कन्वर्जन स्क्रिप्ट उपलब्ध है।** `sip_to_pjsip.py` के साथ उसी `contrib/scripts/sip_to_pjsip/` डायरेक्टरी में **`sip_to_pjsql.py`** स्थित है; यह उसी `convert()` लॉजिक का पुन: उपयोग करता है, लेकिन फ्लैट कॉन्फ़िगरेशन फ़ाइल के बजाय `ps_*` टेबल के लिए `INSERT` स्टेटमेंट की एक `pjsip.sql` फ़ाइल बनाता है। फ्लैट-फाइल टूल की तरह, इसे लोड करने से पहले आउटपुट की समीक्षा करें।

अंत में, `sorcery.conf` को अपने डेटाबेस पर पॉइंट करें ताकि PJSIP, `ps_*` टेबल से (`res_config_odbc` / `res_pjsip_realtime` के माध्यम से) endpoints, aors, auths, और contacts को पढ़ सके, ठीक वैसे ही जैसे `extconfig.conf` कभी `chan_sip` के लिए डेटाबेस पर `sippeers` को पॉइंट करता था। Realtime मैकेनिक्स को *Realtime* अध्याय में कवर किया गया है; माइग्रेशन-विशिष्ट बिंदु केवल यह है कि *कौन सी टेबल किसमें मैप होती है*।

## माइग्रेशन चेकलिस्ट

प्रोडक्शन कटओवर के लिए संचालन का एक व्यावहारिक क्रम:

1. **इन्वेंट्री।** प्रत्येक डिवाइस, trunk, और `register =>` को `sip.conf` (या प्रत्येक `sippeers`/`sipregs` पंक्ति) में सूचीबद्ध करें। कस्टम NAT, codec, और DTMF सेटिंग्स को नोट करें।
2. **कनवर्टर को एक स्क्रैच फ़ाइल में चलाएँ।**
   `sip_to_pjsip.py sip.conf pjsip_generated.conf`। इसे अपने लाइव `pjsip.conf` पर पॉइंट **न** करें।
3. **आउटपुट के शीर्ष पर "Non mapped elements" ब्लॉक को पढ़ें** और प्रत्येक पंक्ति का समाधान करें — विशेष रूप से `qualify`, टाइमर, और NAT से संबंधित कुछ भी।
4. **ट्रांसपोर्ट को हाथ से डिज़ाइन करें।** प्रति IP/port एक ट्रांसपोर्ट; आवश्यकतानुसार TLS/TCP जोड़ें; क्लाउड/NAT बॉक्स के लिए `external_*_address` और `local_net` सेट करें।
5. **ऑथेंटिकेशन सत्यापित करें।** प्रत्येक `auth` ऑब्जेक्ट पर `auth_type=digest`, उपयोगकर्ता नाम और पासवर्ड की पुष्टि करें।
6. **NAT/मीडिया/DTMF सत्यापित करें।** आवश्यकतानुसार प्रति endpoint `force_rport`/`rewrite_contact`/`rtp_symmetric`, `direct_media`, `dtmf_mode=rfc4733`।
7. **dialplan अपडेट करें।** हर जगह `SIP/` → `PJSIP/`; `SIP*` फ़ंक्शंस और चैनल वेरिएबल्स की जाँच करें।
8. **स्क्रिप्ट और मॉनिटरिंग अपडेट करें।** कोई भी टूल या AMI उपभोक्ता जो `sip show ...` आउटपुट को पार्स करता था, उसे `pjsip show ...` / PJSIP AMI क्रियाओं पर जाना होगा।
9. **रीलोड करें और सत्यापित करें।** `module reload res_pjsip.so`, फिर `pjsip show endpoints`, `pjsip show registrations`, `pjsip show identifies`।
10. **पैकेट लॉगर के साथ परीक्षण करें।** `pjsip set logger on`; एक रजिस्ट्रेशन, एक इनबाउंड कॉल, और एक आउटबाउंड कॉल करें और SIP एक्सचेंज को शुरू से अंत तक पढ़ें।

## सामान्य त्रुटियाँ

- **`alwaysauthreject` अब इन-बिल्ट है — इसे खोजने की आवश्यकता नहीं है।** `chan_sip` को `alwaysauthreject=yes` की आवश्यकता होती थी ताकि गलत यूजरनेम का उत्तर अलग तरीके से देकर यह पता न चले कि कौन से extension मौजूद हैं। PJSIP डिज़ाइन के अनुसार सुरक्षित है: यह कभी नहीं बताता कि कोई endpoint मौजूद है या नहीं। इसमें सेट करने के लिए कोई `alwaysauthreject` विकल्प नहीं है। संबंधित सुरक्षा — अज्ञात प्रेषकों को थ्रॉटल करना — वैश्विक `unidentified_request_count` / `unidentified_request_period` है, जो डिफ़ॉल्ट रूप से चालू रहता है।

- **`insecure=invite` कोई PJSIP विकल्प नहीं है — `identify` का उपयोग करें।** `pjsip.conf` में कोई `insecure=` नहीं है। किसी ज्ञात कैरियर से अनधिकृत INVITEs को स्वीकार करने का तरीका यह है कि *endpoint को सोर्स IP द्वारा पहचाना जाए* `type=identify` / `match=` के साथ। जितना संभव हो उतना सटीक मिलान करें (विशिष्ट होस्ट IPs, न कि व्यापक CIDRs), और इसे एक `type=acl` के साथ सुरक्षित करें — बिना ऑथेंटिकेशन वाला IP-मैच्ड trunk टोल-फ्रॉड का आसान लक्ष्य होता है।

- **प्रति IP/पोर्ट एक ट्रांसपोर्ट।** आप एक ही IP:पोर्ट पर दो ट्रांसपोर्ट बाइंड नहीं कर सकते, और आप एक ही IP वर्शन के कई TCP या TLS ट्रांसपोर्ट बाइंड नहीं कर सकते। कन्वर्ज़न स्क्रिप्ट ऐसा ट्रांसपोर्ट बना सकती है जो आपके मौजूदा ट्रांसपोर्ट से टकराए — एक ही, सोच-समझकर डिज़ाइन की गई ट्रांसपोर्ट लेयर पर समेकित करें।

- **`qualify=yes` बूलियन (boolean) में अनुवादित नहीं होता है।** यह `qualify_frequency=<seconds>` के रूप में **aor** पर लागू होता है। कनवर्टर `qualify=yes` को नॉन-मैप्ड ब्लॉक में डाल देता है क्योंकि endpoint पर इसके समकक्ष कोई बूलियन नहीं होता है।

- **`secret=` कोई endpoint विकल्प नहीं है।** क्रेडेंशियल्स केवल एक `type=auth` ऑब्जेक्ट में रहते हैं जिसे endpoint *रेफरेंस* करता है (इनबाउंड के लिए `auth=`, आउटबाउंड के लिए `outbound_auth=`)। endpoint पर पासवर्ड डालने से कुछ नहीं होता।

- **CLI और कोई भी स्क्रैपिंग स्क्रिप्ट चुपचाप काम करना बंद कर देती हैं।** `sip show ...` "No such command" लौटाता है, न कि कोई ऐसी त्रुटि जिसे आपकी मॉनिटरिंग सिस्टम आसानी से पकड़ सके। कटओवर से पहले हर cron जॉब, Nagios चेक, और AMI क्लाइंट के लिए `sip ` कमांड्स का ऑडिट करें।

## सारांश

Asterisk 22 पर माइग्रेट करने का अर्थ है `chan_sip` से बाहर निकलना, क्योंकि इस ड्राइवर को Asterisk 21 में हटा दिया गया था और PJSIP ही एकमात्र शेष SIP चैनल है। इस कार्य का मुख्य भाग प्रत्येक `sip.conf` `peer`/`user`/`friend` को फिर से व्यक्त करना है — जो सब कुछ एक ब्लॉक में पैक करता था — इसे PJSIP ऑब्जेक्ट्स के एक समूह के रूप में व्यवस्थित करना है: एक `endpoint` और एक `auth`, एक `aor`, और डिवाइस के आधार पर, एक `identify` (इनबाउंड trunk), एक `registration` (आउटबाउंड लॉगिन), और एक साझा `transport`। `contrib/scripts/sip_to_pjsip/` में स्थित `sip_to_pjsip.py` स्क्रिप्ट अधिकांश अनुवाद का कार्य करती है और ईमानदारी से उन चीजों को "Non mapped elements" ब्लॉक में चिह्नित करती है जिन्हें वह मैप नहीं कर सकती, लेकिन इसका आउटपुट केवल एक पहला ड्राफ्ट है: transport, NAT, और सुरक्षा को मैन्युअल रूप से डिज़ाइन करें और प्रोडक्शन से पहले परीक्षण करें। कॉन्फ़िगरेशन के साथ-साथ, dialplan (`SIP/` → `PJSIP/`) और अपनी उंगलियों तथा स्क्रिप्ट्स (`sip show` → `pjsip show`, `sip set debug` → `pjsip set logger`) को अपडेट करें। Realtime डिप्लॉयमेंट `sippeers`/`sipregs` से Sorcery `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts` टेबल्स पर चले जाते हैं, जिसमें सहायता के लिए `sip_to_pjsql.py` और `contrib/ast-db-manage` स्कीमा उपलब्ध है। सावधानियों पर ध्यान दें — `alwaysauthreject` इन-बिल्ट है, `insecure=invite` अब `identify` बन जाता है, `qualify=yes` अब `qualify_frequency` बन जाता है, और प्रति IP/पोर्ट एक transport — और इस प्रकार कटओवर रहस्यमय होने के बजाय यांत्रिक हो जाता है।

## प्रश्नोत्तरी

1. Asterisk 22 परिनियोजन (deployment) में SIP के लिए PJSIP का उपयोग करना क्यों आवश्यक है?
   - A. `chan_sip` धीमा है लेकिन अभी भी उपलब्ध है
   - B. `chan_sip` को Asterisk 21 में हटा दिया गया था और यह Asterisk 22 में मौजूद नहीं है
   - C. PJSIP डिफ़ॉल्ट है लेकिन `chan_sip` को `modules.conf` के साथ लोड किया जा सकता है
   - D. `chan_sip` Asterisk 22 में केवल TLS के साथ काम करता है

2. एक एकल `sip.conf` `type=friend` ब्लॉक सबसे सामान्य रूप से PJSIP ऑब्जेक्ट्स के किस सेट में बदल जाता है?
   - A. एक एकल `type=peer`
   - B. केवल `type=endpoint`
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. `sip.conf` में, `host=dynamic` (डिवाइस अपना स्थान स्वयं पंजीकृत करता है) का मिलान किससे होता है:
   - A. `match=dynamic` के साथ `type=identify`
   - B. `max_contacts` के साथ एक `type=aor` (डिवाइस REGISTER करता है)
   - C. endpoint पर `direct_media=yes`
   - D. `type=registration`

4. `sip_to_pjsip.py` रूपांतरण स्क्रिप्ट क्या है:
   - A. एक CLI कमांड: `asterisk -rx 'sip_to_pjsip'`
   - B. Asterisk सोर्स ट्री में `contrib/scripts/sip_to_pjsip/` के अंतर्गत एक Python स्क्रिप्ट
   - C. बूट पर लोड किया गया एक संकलित (compiled) मॉड्यूल
   - D. `res_pjsip.so` का हिस्सा

5. सही या गलत: `sip_to_pjsip.py` का आउटपुट प्रोडक्शन-रेडी है और इसे बिना समीक्षा के लोड किया जाना चाहिए।

6. `chan_sip` शॉर्टहैंड `nat=force_rport,comedia`, PJSIP endpoint पर किन तीन विकल्पों में अनुवादित होता है?
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. `sip.conf` का `dtmfmode=rfc2833` किस PJSIP सेटिंग में बदल जाता है?
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. Asterisk 22 पर, एक `auth` ऑब्जेक्ट को किस `auth_type` का उपयोग करना चाहिए, और `userpass` की स्थिति क्या है?
   - A. `auth_type=userpass`; यह एकमात्र मान्य मान है
   - B. `auth_type=digest`; `userpass` को deprecated कर दिया गया है और इसे `digest` में परिवर्तित कर दिया गया है
   - C. `auth_type=md5`; `digest` को deprecated कर दिया गया है
   - D. `auth_type=plaintext`; `digest` को हटा दिया गया है

9. `insecure=invite` (ज्ञात IP से अनधिकृत INVITEs स्वीकार करें) वाले एक `chan_sip` प्रदाता पीयर को PJSIP में माइग्रेट करने के लिए किसका उपयोग किया जाता है:
   - A. endpoint पर `insecure=invite`
   - B. `[global]` में `allowguest=yes`
   - C. `match=<provider IP>` के साथ एक `type=identify` ऑब्जेक्ट
   - D. `auth_type=anonymous`

10. एक realtime माइग्रेशन में, `chan_sip` `sippeers` टेबल को किन PJSIP/Sorcery टेबल्स द्वारा प्रतिस्थापित किया जाता है?
    - A. एक एकल `pjsip_peers` टेबल
    - B. `ps_endpoints`, `ps_aors`, और `ps_auths`
    - C. `sipregs` और `voicemail`
    - D. केवल `ps_contacts`

**उत्तर:** 1 — B · 2 — C · 3 — B · 4 — B · 5 — False · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
