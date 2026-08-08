# Asterisk REST Interface (ARI)

पिछले अध्याय में AMI और AGI को कवर किया गया था, जो Asterisk के साथ बाहरी लॉजिक जोड़ने के दो क्लासिक तरीके हैं। दोनों ही आधुनिक वेब से पहले के हैं: AMI आपको TCP सॉकेट पर एक रॉ, लाइन-ओरिएंटेड इवेंट स्ट्रीम देता है, और AGI कॉल की अवधि के लिए एक स्क्रिप्ट को एक सिंगल चैनल सौंपता है। इनमें से कोई भी उस तरह के स्टेटफुल, एसिंक्रोनस, मल्टी-चैनल एप्लिकेशन के लिए डिज़ाइन नहीं किया गया था जिन्हें लोग आज बनाते हैं — जैसे IVR जो वेब सेवाओं से बात करते हैं, क्लिक-टू-कॉल डैशबोर्ड, कॉन्फ्रेंस कंट्रोलर, या वॉइसबॉट्स जो स्पीच इंजन को ऑडियो स्ट्रीम करते हैं।

ARI — Asterisk REST Interface — को उस कमी को पूरा करने के लिए Asterisk 12 में पेश किया गया था, और Asterisk 22 में यह नए टेलीफोनी एप्लिकेशन बनाने के लिए अनुशंसित इंटरफ़ेस है। ARI के पीछे का विचार चिंताओं का स्पष्ट पृथक्करण है: **Asterisk एक मीडिया इंजन बन जाता है** (यह चैनलों का उत्तर देता है, ब्रिज को मिक्स करता है, ऑडियो चलाता और रिकॉर्ड करता है, DTMF भेजता है), और **आपका एप्लिकेशन REST (HTTP) API और WebSocket इवेंट स्ट्रीम के संयोजन के माध्यम से सभी कॉल-कंट्रोल लॉजिक प्रदान करता है**।

## उद्देश्य

इस अध्याय के अंत तक, पाठक निम्नलिखित में सक्षम होंगे:

- यह समझाना कि ARI क्या है और यह AMI और AGI से किस प्रकार भिन्न है
- यह निर्णय लेना कि किसी प्रोजेक्ट के लिए ARI सही इंटरफ़ेस कब है
- ARI को सक्षम करने और एक उपयोगकर्ता बनाने के लिए `ari.conf` और `http.conf` को कॉन्फ़िगर करना
- ARI WebSocket इवेंट स्ट्रीम से कनेक्ट करना
- Stasis dialplan एप्लिकेशन और `StasisStart`/`StasisEnd` इवेंट्स का वर्णन करना
- ARI रिसोर्स मॉडल का वर्णन करना: channels, bridges, playbacks, recordings, endpoints, और device states
- Python में एक न्यूनतम Stasis एप्लिकेशन लिखना जो एक channel का उत्तर देता है, एक ध्वनि बजाता है, और कॉल काट देता है
- यह समझाना कि `externalMedia` channel क्या है और यह AI और voicebot एकीकरण के लिए क्यों महत्वपूर्ण है

## ARI क्या है, और इसका उपयोग कब करें

ARI दो ट्रांसपोर्ट्स पर आधारित है जो एक साथ काम करते हैं:

- **एक REST (HTTP) API** जिसे आपका एप्लिकेशन चीजें *करने* के लिए कॉल करता है — एक चैनल शुरू करना, उसका उत्तर देना, ध्वनि बजाना, ब्रिज बनाना, रिकॉर्डिंग शुरू करना, कॉल काटना। ये सामान्य HTTP अनुरोध (`GET`, `POST`, `DELETE`) हैं जो `http://asterisk-host:8088/ari/...` के विरुद्ध किए जाते हैं।
- **एक WebSocket इवेंट स्ट्रीम** जिसके माध्यम से Asterisk आपके एप्लिकेशन को *बताता* है कि क्या हो रहा है — एक चैनल बनाया गया, एक DTMF अंक प्राप्त हुआ, प्लेबैक समाप्त हुआ, एक चैनल ने आपके एप्लिकेशन को छोड़ दिया। इवेंट्स JSON ऑब्जेक्ट्स के रूप में डिलीवर किए जाते हैं।

यह पैटर्न एसिंक्रोनस (asynchronous) है: आप एक अनुरोध करते हैं, और उस अनुरोध का *परिणाम* आमतौर पर बाद में एक इवेंट के रूप में वापस आता है। उदाहरण के लिए, आप ध्वनि बजाने के लिए एक `POST` अनुरोध करते हैं; Asterisk तुरंत एक `Playback` ऑब्जेक्ट के साथ उत्तर देता है, और कुछ सेकंड बाद जब ऑडियो समाप्त हो जाता है तो आपको एक `PlaybackFinished` इवेंट प्राप्त होता है।

AMI और AGI के बजाय ARI चुनें जब:

- आपको **चैनलों और ब्रिजों पर सूक्ष्म नियंत्रण (fine-grained control)** की आवश्यकता हो — डायलप्लान एप्लिकेशन पर निर्भर रहने के बजाय प्रिमिटिव्स से कॉन्फ्रेंस, पार्किंग, कतारें, या कस्टम कॉल फ्लो बनाना।
- आपका एप्लिकेशन **स्टेटफुल और लंबे समय तक चलने वाला (long-lived)** हो, जो एक साथ कई चैनलों को संभाले और उन सभी में होने वाले इवेंट्स पर प्रतिक्रिया दे।
- आप **वेब सेवाओं, मैसेज बसों, या AI/स्पीच इंजनों** के साथ एकीकृत करना चाहते हैं और लाइन प्रोटोकॉल या stdin/stdout स्क्रिप्ट के बजाय HTTP पर JSON को प्राथमिकता देते हैं।
- आप एक **नया प्रोजेक्ट** शुरू कर रहे हैं और वह इंटरफ़ेस चाहते हैं जिसकी Asterisk प्रोजेक्ट सक्रिय रूप से अनुशंसा करता है।

AMI अभी भी सही टूल है जब आपको केवल सिस्टम का *अवलोकन* करने या कभी-कभार कमांड (डायलर्स, वॉलबोर्ड, मॉनिटरिंग) भेजने की आवश्यकता हो। AGI अभी भी एक त्वरित, स्व-निहित IVR स्क्रिप्ट के लिए सुविधाजनक है। लेकिन किसी भी ऐसी चीज़ के लिए जो कॉल्स को व्यवस्थित (orchestrate) करती है, ARI आधुनिक उत्तर है।

> ARI डायलप्लान को प्रतिस्थापित नहीं करता है — यह इसका पूरक है। एक चैनल सामान्य रूप से डायलप्लान में तब तक चलता है जब तक वह `Stasis()` एप्लिकेशन तक नहीं पहुँच जाता, जिस बिंदु पर नियंत्रण आपके ARI एप्लिकेशन को सौंप दिया जाता है। जब आपका एप्लिकेशन अपना काम पूरा कर लेता है, तो चैनल को वापस डायलप्लान में भेजा जा सकता है या कॉल काटी जा सकती है।

## ARI को सक्षम करना: http.conf और ari.conf

ARI, Asterisk के इन-बिल्ट HTTP सर्वर के ऊपर चलता है, इसलिए इसमें दो कॉन्फ़िगरेशन फ़ाइलों की आवश्यकता होती है: `http.conf` वेब सर्वर को सक्षम करता है, और `ari.conf` ARI को सक्षम करता है और इसके उपयोगकर्ताओं को परिभाषित करता है।

### http.conf

HTTP सर्वर को सक्षम किया जाना चाहिए और एक एड्रेस और पोर्ट से बाइंड किया जाना चाहिए। पारंपरिक ARI पोर्ट **8088** है।

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
```

प्रोडक्शन के लिए आपको ARI को TLS के पीछे रखना चाहिए। Asterisk सीधे HTTPS सर्व कर सकता है (`tlsenable=yes`, `tlsbindaddr`, `tlscertfile`, `tlsprivatekey`), या आप पोर्ट 8088 के सामने एक रिवर्स प्रॉक्सी में TLS को टर्मिनेट कर सकते हैं। TLS पर URL `http://` और `ws://` के बजाय `https://` और `wss://` हो जाते हैं।

आप CLI से पुष्टि कर सकते हैं कि HTTP सर्वर चालू है:

```
asterisk*CLI> http show status
HTTP Server Status:
Server Enabled and Bound to 0.0.0.0:8088
```

### ari.conf

`ari.conf` में एक `[general]` सेक्शन और प्रति उपयोगकर्ता एक सेक्शन होता है।

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

इन विकल्पों पर कुछ नोट्स:

- `enabled` ARI को विश्व स्तर पर चालू या बंद करता है।
- `pretty` JSON रिस्पॉन्स को मानव-पठनीय (human-readable) बनाने के लिए फॉर्मेट करता है; प्रोडक्शन में इसे बंद रखें।
- प्रत्येक उपयोगकर्ता `type=user` के साथ एक नामित सेक्शन है।
- `read_only=yes` उस उपयोगकर्ता को केवल-पढ़ने (read-only) (GET) अनुरोधों तक सीमित करता है।
- `password_format` `plain` (पासवर्ड प्लेनटेक्स्ट में है) या `crypt` (एक हैशेड पासवर्ड, जिसे `mkpasswd -m sha-512` के साथ जेनरेट किया गया है) हो सकता है।
- `permit`, `deny`, और `acl` प्रति-उपयोगकर्ता IP प्रतिबंधों की अनुमति देते हैं, जो `acl.conf` के समान नियमों का पालन करते हैं।

फ़ाइलों को संपादित करने के बाद, संबंधित मॉड्यूल (`module reload res_ari.so` और `module reload http.so`) को रीलोड करें या Asterisk को रीस्टार्ट करें। आप यह सत्यापित कर सकते हैं कि ARI चल रहा है:

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

`ari show apps` कनेक्टेड क्लाइंट्स द्वारा वर्तमान में पंजीकृत Stasis एप्लिकेशन को सूचीबद्ध करता है। यह तब तक खाली रहता है जब तक कोई क्लाइंट कनेक्ट नहीं होता, जो कि हम आगे करने वाले हैं।

### WebSocket इवेंट्स URL

एक क्लाइंट `/ari/events` एंडपॉइंट पर एक WebSocket खोलकर इवेंट स्ट्रीम की सदस्यता लेता है, उस Stasis एप्लिकेशन का नाम बताता है जिसे वह लागू करता है और अपने क्रेडेंशियल्स पास करता है:

```
ws://asterisk-host:8088/ari/events?app=hello&api_key=asterisk:secret
```

क्वेरी पैरामीटर्स इस प्रकार हैं:

- `app` — आपके Stasis एप्लिकेशन का नाम। यह वही नाम है जिसका उपयोग आप dialplan के `Stasis()` कॉल में करेंगे। आप अल्पविराम से अलग किए गए कई नाम पास कर सकते हैं।
- `api_key` — क्रेडेंशियल्स, `username:password` के रूप में, जो `ari.conf` में एक उपयोगकर्ता से मेल खाते हैं।
- `subscribeAll` — वैकल्पिक बूलियन (डिफ़ॉल्ट `false`); जब `true` होता है, तो एप्लिकेशन को सभी इवेंट्स प्राप्त होते हैं, न कि केवल उन संसाधनों के लिए जिन्हें वह नियंत्रित करता है।

REST कॉल्स पर HTTP Basic auth के रूप में उन्हीं `user:pass` क्रेडेंशियल्स का उपयोग किया जाता है (या वहां भी एक `api_key` क्वेरी पैरामीटर के रूप में जोड़ा जाता है)।

## Stasis: किसी चैनल को अपने एप्लिकेशन को सौंपना

dialplan और ARI के बीच का सेतु **`Stasis()`** dialplan एप्लिकेशन है (अंतर्निहित फ्रेमवर्क को भी Stasis कहा जाता है)। जब कोई चैनल `Stasis(appname[,args])` तक पहुँचता है, तो Asterisk उस चैनल को `appname` के अंतर्गत पंजीकृत ARI एप्लिकेशन को सौंप देता है और उसके लिए dialplan को निष्पादित करना बंद कर देता है। अब नियंत्रण आपके कोड के पास होता है।

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

जब चैनल एप्लिकेशन में प्रवेश करता है, तो `hello` की सदस्यता लेने वाला प्रत्येक कनेक्टेड क्लाइंट WebSocket पर एक **`StasisStart`** इवेंट प्राप्त करता है, जिसमें पूर्ण चैनल ऑब्जेक्ट (इसकी ID, नाम, caller ID, स्थिति, और `Stasis()` को पास किए गए कोई भी तर्क) शामिल होते हैं। यह चैनल को नियंत्रित करना शुरू करने के लिए आपका संकेत है।

जब चैनल एप्लिकेशन छोड़ता है — क्योंकि आपके कोड ने इसे `continueInDialplan` के साथ वापस dialplan में भेज दिया, या क्योंकि इसे हैंग-अप कर दिया गया — तो आपको एक **`StasisEnd`** इवेंट प्राप्त होता है। `Stasis()` के dialplan में वापस लौटने के बाद, यह `STASISSTATUS` चैनल वेरिएबल (`SUCCESS` या `FAILED`) को सेट करता है, ताकि dialplan परिणाम के आधार पर शाखा बना सके।

## ARI रिसोर्स मॉडल

ARI, Asterisk के इंटरनल्स को REST रिसोर्स के एक छोटे सेट के रूप में प्रदर्शित करता है। प्रत्येक रिसोर्स `/ari/<resource>` के अंतर्गत रहता है और इसे मानक HTTP विधियों के साथ मैनिपुलेट किया जाता है। सबसे महत्वपूर्ण रिसोर्स निम्नलिखित हैं:

| रिसोर्स | यह क्या दर्शाता है | उदाहरण ऑपरेशन्स |
|----------|--------------------|--------------------|
| **channels** | एक सिंगल कॉल लेग | originate, answer, play, record, hangup |
| **bridges** | एक मिक्सिंग पॉइंट जो channels को जोड़ता है | create, add/remove channels, play to the bridge |
| **playbacks** | एक चल रहा मीडिया प्लेबैक | get status, stop, pause/unpause |
| **recordings** | लाइव और संग्रहीत रिकॉर्डिंग | start, stop, list stored, delete |
| **endpoints** | कॉन्फ़िगर किए गए पीयर्स (PJSIP, आदि) | list, get state, send a message |
| **deviceStates** | कस्टम डिवाइस स्टेट्स | list, get, set, delete |

कुछ ठोस REST कॉल्स (पाथ `/ari` प्रीफिक्स के साथ दिखाए गए हैं जो वायर पर दिखाई देते हैं):

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

`play` रिक्वेस्ट पर `media` पैरामीटर एक मीडिया URI लेता है। सबसे सामान्य रूप एक `sound:` URI है जो एक इन-बिल्ट साउंड का नाम बताता है, उदाहरण के लिए `sound:hello-world` या `sound:tt-monkeys`। जब ऑडियो समाप्त हो जाता है, तो Asterisk उस प्लेबैक ID के लिए एक `PlaybackFinished` इवेंट उत्सर्जित करता है, जिससे आपके एप्लिकेशन को पता चलता है कि वह आगे बढ़ सकता है।

Channels और bridges वे दो बिल्डिंग ब्लॉक्स हैं जिन्हें आप कॉल फ्लो बनाने के लिए जोड़ते हैं। उदाहरण के लिए, दो कॉलर्स को जोड़ने के लिए, आप दो channels को originate या accept करते हैं, `POST /ari/bridges` के साथ एक `mixing` bridge बनाते हैं, और `POST /ari/bridges/{bridgeId}/addChannel` के साथ दोनों channels को इसमें जोड़ते हैं। एक कॉन्फ्रेंस बनाने के लिए, आप बस उसी bridge में channels जोड़ते रहते हैं।

## एक कार्यशील उदाहरण: एक न्यूनतम Stasis एप्लिकेशन

आइए सबसे छोटा उपयोगी ARI एप्लिकेशन बनाएं। जब कोई भी extension डायल किया जाता है, तो कॉल हमारे Stasis ऐप में प्रवेश करती है, जो इसे answer करती है, क्लासिक `hello-world` प्रॉम्प्ट बजाती है, और कॉल काट देती है।

### dialplan

`extensions.conf` में, चैनल को Stasis पर भेजें:

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

एप्लिकेशन का नाम `hello` उस `app=hello` से मेल खाता है जिसका उपयोग हम कनेक्ट करते समय करते हैं।

### Python क्लाइंट

यह क्लाइंट दो प्रसिद्ध लाइब्रेरी का उपयोग करता है: REST कॉल्स के लिए `requests` और इवेंट स्ट्रीम के लिए `websocket-client`। इन्हें `pip install requests websocket-client` के साथ इंस्टॉल करें।

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

स्क्रिप्ट चलाएं, फिर किसी भी रजिस्टर्ड endpoint से कोई भी नंबर डायल करें। आपको "Hello, world" सुनाई देना चाहिए, जिसके बाद कॉल समाप्त हो जाएगी। Asterisk कंसोल पर, `ari show apps` अब `hello` को सूचीबद्ध करेगा जब तक कि क्लाइंट कनेक्टेड है।

इस प्रवाह को एक बार समझना उपयोगी है:

1. dialplan `Stasis(hello)` चलाता है; Asterisk चैनल को हमारे ऐप को सौंप देता है और एक `StasisStart` इवेंट भेजता है।
2. हम चैनल को answer करते हैं, फिर Asterisk से `sound:hello-world` बजाने के लिए कहते हैं। Asterisk एक `Playback` ऑब्जेक्ट लौटाता है जिसके `id` को हम याद रखते हैं।
3. जब ऑडियो समाप्त हो जाता है, तो Asterisk उस प्लेबैक `id` के साथ `PlaybackFinished` भेजता है; हम चैनल को देखते हैं और उसे hang up कर देते हैं।
4. hang up करने से चैनल Stasis से बाहर निकल जाता है, जिससे एक `StasisEnd` इवेंट उत्पन्न होता है।

> **क्लाइंट लाइब्रेरी पर एक नोट।** `ari-py` (`ari` पैकेज) नामक एक उच्च-स्तरीय रैपर मौजूद है, लेकिन यह अब मेंटेन नहीं किया जाता है और इसे Python और Swagger टूलिंग के पुराने युग के लिए लिखा गया था। Asterisk 22 पर नए काम के लिए, ऊपर दिखाए गए स्पष्ट `requests` + WebSocket दृष्टिकोण को प्राथमिकता दें, या यदि आपको कॉन्करेंसी की आवश्यकता है तो `asyncari` जैसी asyncio लाइब्रेरी का उपयोग करें। रॉ दृष्टिकोण आपको वास्तविक REST कॉल्स और इवेंट्स के करीब रखता है, जो कि ARI सीखते समय आप वास्तव में चाहते हैं।

## externalMedia: AI और voicebots के लिए द्वार

ऊपर दिए गए संसाधन आपको *files* चलाने और रिकॉर्ड करने की सुविधा देते हैं। लेकिन आधुनिक वॉयस एप्लिकेशन — जैसे speech-to-text ट्रांसक्रिप्शन, AI voicebots, रीयल-टाइम एनालिटिक्स — को एक कॉल के *live audio stream* की आवश्यकता होती है जिसे किसी बाहरी प्रक्रिया (external process) तक पहुँचाया जा सके, और उन्हें वापस ऑडियो इंजेक्ट करने की भी आवश्यकता होती है।

ARI यह सुविधा **`externalMedia` channel** के माध्यम से प्रदान करता है। एक `POST /ari/channels/externalMedia` अनुरोध एक विशेष चैनल बनाता है जो किसी फोन से बात करने के बजाय, कॉल के RTP मीडिया को एक बाहरी होस्ट तक (और वहां से) स्ट्रीम करता है। आप इस चैनल को कॉलर के चैनल के साथ ब्रिज करते हैं, और अब आपका बाहरी प्रोग्राम ऑडियो पथ में होता है: यह कॉलर के ऑडियो को RTP के रूप में प्राप्त करता है और वापस सिंथेसाइज्ड ऑडियो भेज सकता है।

इस अनुरोध के लिए केवल निम्नलिखित की आवश्यकता होती है:

- `app` — वह Stasis एप्लिकेशन जो नए चैनल का स्वामी है।
- `format` — ऑडियो फॉर्मेट, उदाहरण के लिए `ulaw` या `slin16`।

`external_host` (आपके मीडिया एप्लिकेशन का `host:port`) स्कीमा में वैकल्पिक है — यह WebSocket-server-style कनेक्शन के लिए खाली हो सकता है — लेकिन एक क्लासिक RTP voicebot के लिए आप इसे प्रदान करेंगे। `encapsulation` पैरामीटर डिफ़ॉल्ट रूप से `rtp` पर और `transport` डिफ़ॉल्ट रूप से `udp` पर सेट होता है, जो कि स्ट्रीमिंग मीडिया endpoint के लिए बिल्कुल वही है जो आपको चाहिए।

```
POST /ari/channels/externalMedia
    app=hello
    external_host=127.0.0.1:9000
    format=slin16
```

यह एकल विशेषता ही वह है जो Asterisk को AI के लिए एक फ्रंट-एंड में बदल देती है: टेलीफोन नेटवर्क Asterisk पर समाप्त होता है, ARI कॉल का संचालन करता है, और `externalMedia` ऑडियो को एक speech/AI इंजन तक और वापस पाइप करता है। यह वही तंत्र है जिस पर AI सेवाएं और voicebots बनाए जाते हैं।

## सारांश

Asterisk 22 पर टेलीफोनी एप्लिकेशन बनाने के लिए ARI आधुनिक और अनुशंसित इंटरफ़ेस है। यह कार्य को स्पष्ट रूप से विभाजित करता है: Asterisk मीडिया इंजन है, और आपका एप्लिकेशन — जो HTTP और WebSocket पर JSON का उपयोग करता है — कॉल-कंट्रोल लॉजिक प्रदान करता है। आप इसे `http.conf` (पोर्ट 8088 पर इन-बिल्ट वेब सर्वर) और `ari.conf` (जो ARI को चालू करता है और उपयोगकर्ताओं को परिभाषित करता है) के माध्यम से सक्षम करते हैं।

`Stasis()` dialplan एप्लिकेशन आपके ऐप को एक चैनल सौंपता है, और जब यह प्रवेश करता है तो `StasisStart` और जब यह बाहर निकलता है तो `StasisEnd` उत्पन्न करता है। वहां से आप REST संसाधनों के एक छोटे सेट — channels, bridges, playbacks, recordings, endpoints, और device states — का उपयोग करके कॉल का उत्तर देने, प्ले करने, रिकॉर्ड करने, ब्रिज करने और हैंग-अप करने का कार्य करते हैं।

हमने एक न्यूनतम Python Stasis ऐप बनाया जो कॉल का उत्तर देता है, एक प्रॉम्प्ट प्ले करता है, और हैंग-अप करता है, और हमने देखा कि कैसे `externalMedia` चैनल लाइव RTP को एक बाहरी प्रोग्राम में स्ट्रीम करता है — जो AI और voicebot इंटीग्रेशन के लिए आधार है।

## प्रश्नोत्तरी

1. Asterisk के किस संस्करण में ARI को पेश किया गया था?
   - A. Asterisk 1.4
   - B. Asterisk 11
   - C. Asterisk 12
   - D. Asterisk 18
2. ARI मॉडल में, Asterisk एक मीडिया इंजन के रूप में कार्य करता है जबकि आपका बाहरी एप्लिकेशन कॉल-कंट्रोल लॉजिक प्रदान करता है।
   - A. सत्य
   - B. असत्य
3. ARI एक साथ दो ट्रांसपोर्ट का उपयोग करता है। कौन सा युग्म सही है?
   - A. कमांड जारी करने के लिए एक REST/HTTP API और इवेंट प्राप्त करने के लिए एक WebSocket स्ट्रीम
   - B. एक TCP लाइन प्रोटोकॉल और एक stdin/stdout स्क्रिप्ट
   - C. SNMP और SMTP
   - D. दो अलग-अलग UDP सॉकेट
4. ARI को सक्षम करने के लिए किन दो कॉन्फ़िगरेशन फ़ाइलों को सेट अप किया जाना चाहिए?
   - A. `manager.conf` और `agi.conf`
   - B. `http.conf` और `ari.conf`
   - C. `sip.conf` और `rtp.conf`
   - D. `modules.conf` और `cdr.conf`
5. Asterisk HTTP सर्वर (और इसलिए ARI) के लिए पारंपरिक TCP पोर्ट ____ है।
6. कौन सा dialplan एप्लिकेशन एक चैनल को ARI एप्लिकेशन को सौंपता है?
   - A. `AGI()`
   - B. `Dial()`
   - C. `Stasis()`
   - D. `System()`
7. जब कोई चैनल Stasis एप्लिकेशन में प्रवेश करता है, तो कनेक्टेड क्लाइंट को कौन सा इवेंट भेजा जाता है?
   - A. `ChannelDestroyed`
   - B. `StasisStart`
   - C. `Newchannel`
   - D. `Hangup`
8. कौन सा ARI अनुरोध एक मिक्सिंग पॉइंट बनाता है जो दो या दो से अधिक चैनलों को एक साथ जोड़ सकता है?
   - A. `POST /ari/channels`
   - B. `POST /ari/bridges`
   - C. `GET /ari/endpoints`
   - D. `DELETE /ari/recordings/stored`
9. किसी चैनल पर इन-बिल्ट प्रॉम्प्ट चलाने के लिए, कौन सा इवेंट आपके एप्लिकेशन को बताता है कि ऑडियो समाप्त हो गया है ताकि वह आगे बढ़ सके?
   - A. `PlaybackStarted`
   - B. `DTMFReceived`
   - C. `PlaybackFinished`
   - D. `ChannelTalkingFinished`
10. `externalMedia` चैनल का उपयोग मुख्य रूप से किसके लिए किया जाता है:
    - A. कॉल को स्थानीय WAV फ़ाइल में रिकॉर्ड करना
    - B. कॉल के लाइव ऑडियो (RTP) को किसी बाहरी एप्लिकेशन, जैसे कि AI/स्पीच इंजन, में स्ट्रीम करना
    - C. PJSIP endpoint को रजिस्टर करना
    - D. dialplan को पुनः लोड करना

**उत्तर:** 1 — C · 2 — A · 3 — A · 4 — B · 5 — `8088` · 6 — C · 7 — B · 8 — B · 9 — C · 10 — B
