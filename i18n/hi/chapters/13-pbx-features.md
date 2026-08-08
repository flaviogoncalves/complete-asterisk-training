# PBX सुविधाओं का उपयोग करना

SIP सिस्टम में, अधिकांश फोन सुविधाएं endpoint में कार्यान्वित की जाती हैं। विभिन्न प्रकार के SIP फोन और निर्माता मौजूद हैं, और इंटरऑपरेबिलिटी की गारंटी नहीं है। Asterisk डेवलपमेंट टीम ने अधिकांश सुविधाओं को स्वयं PBX में कार्यान्वित करने का अद्भुत काम किया है, जिससे Asterisk लगभग endpoint से स्वतंत्र हो गया है। हालाँकि, कभी-कभी आप पाएंगे कि वही कार्य फोन और Asterisk दोनों द्वारा किया जा रहा है। फोन और PBX का एकीकरण उपयोगिता के मामले में अगली सीमा है और यही वह जगह है जहाँ प्रोप्रायटरी सिस्टम अभी ध्यान केंद्रित कर रहे हैं। इस अध्याय में, आप सीखेंगे कि इन अधिकांश सुविधाओं का उपयोग कैसे किया जाए।

## Objectives

इस अध्याय के अंत तक, आप निम्नलिखित को समझने और उपयोग करने में सक्षम होंगे:

- Call Parking
- Call Pickup
- Call Transfer
- Call Conference (ConfBridge)
- Call Recording
- Music on hold

## जहाँ फीचर्स लागू किए जाते हैं

सबसे पहले और सबसे महत्वपूर्ण, यह समझना जरूरी है कि PBX फीचर्स कब निष्पादित (execute) हो रहे हैं और कब फोन सारा काम कर रहा है। उदाहरण के लिए, आप फोन पर TRANSFER बटन का उपयोग करके या # डायल करके (PBX द्वारा स्वयं निष्पादित बिना शर्त ट्रांसफर) कॉल ट्रांसफर कर सकते हैं।

## Asterisk द्वारा कार्यान्वित सुविधाएँ

ये सुविधाएँ Asterisk कोड द्वारा PBX में कार्यान्वित की जाती हैं:

- Music on hold
- Call parking
- Call pickup
- Call recording
- ConfBridge conference room
- Call transfer (blind and consultative)

## dial plan द्वारा आमतौर पर कार्यान्वित की जाने वाली सुविधाएँ

इन सुविधाओं को Asterisk dial plan (extensions.conf) में प्रोग्राम करने की आवश्यकता होती है:

- व्यस्त होने पर कॉल फॉरवर्ड करना (Call forward on busy)
- तत्काल कॉल फॉरवर्ड करना (Call forward immediate)
- अनुत्तरित होने पर कॉल फॉरवर्ड करना (Call forward on unanswered)
- कॉल फ़िल्टरिंग (ब्लैकलिस्ट) (Call filtering (blacklist))
- परेशान न करें (Do not disturb)
- पुनः डायल करना (Redial)

## फोन द्वारा आमतौर पर कार्यान्वित की जाने वाली सुविधाएं

ये सुविधाएं फोन के फर्मवेयर द्वारा कार्यान्वित की जाती हैं:

![PBX सुविधाएं आमतौर पर कहाँ कार्यान्वित की जाती हैं: Asterisk में, dialplan में, या फोन में](../images/13-pbx-features-fig01.png)

- Call on hold
- Blind transfer
- Consultative transfer
- Three-way conference
- Message waiting indicator

## फीचर्स कॉन्फ़िगरेशन फ़ाइल

इस अध्याय में प्रस्तुत कुछ फीचर्स को features.conf कॉन्फ़िगरेशन फ़ाइल में कॉन्फ़िगर किया गया है। इस फ़ाइल को संशोधित करके कुछ फीचर्स के व्यवहार को बदलना संभव है। हमने नीचे प्रासंगिक अंश शामिल किया है। इस अध्याय के अगले अनुभागों में, हम प्रत्येक फीचर का वर्णन करेंगे। नमूना फ़ाइल (Asterisk 22) से अंश

![features.conf का `[featuremap]` अनुभाग, डिफ़ॉल्ट DTMF फीचर कोड के साथ](../images/13-pbx-features-fig02.png)

Asterisk 12 के बाद से, कॉल पार्किंग को `features.conf` से हटाकर इसके अपने मॉड्यूल, `res_parking` में स्थानांतरित कर दिया गया है, जिसका कॉन्फ़िगरेशन `res_parking.conf` में है। नीचे दिया गया parking-lot ब्लॉक (`parkext`, `parkpos`, `context`, `parkingtime`, इत्यादि) `res_parking.conf` में रहता है। `[featuremap]` अनुभाग (DTMF फीचर कोड, जिसमें `parkcall` शामिल है) `features.conf` में रहता है।

parking-lot विकल्प `res_parking.conf` में रहते हैं। `default` नामक एक पार्किंग लॉट हमेशा मौजूद रहता है, भले ही वह कॉन्फ़िगरेशन फ़ाइल में मौजूद न हो। नीचे दिया गया अंश Asterisk 22 `res_parking.conf.sample` से लिया गया है:

```
; res_parking.conf
[default]                       ; Default Parking Lot
parkext => 700                  ; What extension to dial to park. (optional; if
                                ; specified, extensions will be created for parkext and
                                ; the whole range of parkpos)
parkpos => 701-720              ; What range of parking spaces to use - must be numeric.
                                ; Creates these spaces as extensions if parkext is set.
context => parkedcalls          ; Which context parked calls and the default park
                                ; extension are created in
;parkingtime => 45             ; Number of seconds a call can be parked before returning
;comebacktoorigin = yes        ; When a parked call times out, attempt to send it back to
                               ; the peer that parked it (default is yes)
;courtesytone = beep           ; Sound file to play when someone picks up a parked call
;parkedplay = caller           ; Who to play courtesytone to: parked, caller, both (default caller)
;parkedcalltransfers = caller  ; Enable DTMF transfers when picking up a parked call (default no)
;parkedcallreparking = caller  ; Enable DTMF parking when picking up a parked call (default no)
;parkedcallhangup = caller     ; Enable DTMF hangups when picking up a parked call (default no)
;findslot => next              ; 'next' uses the next space after the most recently used one;
                               ; 'first' (default) uses the lowest-numbered space available
;parkedmusicclass = default    ; MOH class to use for the parked channel
```

DTMF फीचर कोड (वन-स्टेप `parkcall` सहित) `features.conf` के `[featuremap]` अनुभाग में रहते हैं:

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## कॉल ट्रांसफर

कॉल ट्रांसफर को फोन द्वारा, ATA द्वारा, या स्वयं Asterisk द्वारा कार्यान्वित किया जा सकता है। कॉल कैसे ट्रांसफर किए जाते हैं, यह समझने के लिए अपने फोन के मैनुअल को देखें। यदि आपका फोन कॉल ट्रांसफर का समर्थन नहीं करता है, तो आप इस कार्य को पूरा करने के लिए Asterisk का उपयोग कर सकते हैं। कॉल ट्रांसफर दो अलग-अलग तरीकों से कार्यान्वित किया जाता है।

पहला तरीका ब्लाइंड ट्रांसफर फीचर का उपयोग करना है: # डायल करें और उसके बाद वह नंबर डायल करें जिस पर ट्रांसफर करना है। कभी-कभी आप अपने IP फोन या IP softphone के ट्रांसफर फीचर का उपयोग करेंगे। आप features.conf फाइल में blindxfer पैरामीटर को संपादित करके ट्रांसफर कैरेक्टर को बदल सकते हैं।

आप features.conf फाइल में atxfer पैरामीटर के पहले लगे ; को हटाकर Asterisk में असिस्टेड ट्रांसफर को सक्षम कर सकते हैं। बातचीत के दौरान, आप *2 दबाएंगे। Asterisk "transfer" कहेगा और आपको डायल टोन देगा। कॉलर को music on hold पर भेज दिया जाता है। गंतव्य व्यक्ति से बात करने और फोन रखने के बाद, सिस्टम कॉलर को गंतव्य से जोड़ देता है।

![कॉल ट्रांसफर: ब्लाइंड ट्रांसफर (कॉल के दौरान # दबाएं) और अटेंडेड ट्रांसफर (कॉल के दौरान *2 दबाएं) के चरण](../images/13-pbx-features-fig03.png)

### कॉन्फ़िगरेशन कार्य सूची

1. PJSIP endpoint के लिए, सुनिश्चित करें कि विकल्प `direct_media` को `no` पर सेट किया गया है (ताकि मीडिया Asterisk के माध्यम से प्रवाहित हो और फीचर कोड का पता लगाया जा सके), या `Dial()` एप्लिकेशन में `t`/`T` विकल्प का उपयोग करें।

## Call parking

यह सुविधा कॉल को पार्क करने के लिए उपयोग की जाती है। यह उदाहरण के लिए तब सहायक होता है, जब आप अपने कमरे के बाहर फोन कॉल का उत्तर दे रहे हों और आप कॉल को वापस अपने डेस्क पर ट्रांसफर करना चाहते हों। आप इसे एक extension में कॉल को पार्क करके पूरा कर सकते हैं। एक बार जब आप अपने डेस्क पर पहुँच जाते हैं, तो कॉल को पुनः प्राप्त करने के लिए बस पार्किंग extension का नंबर डायल करें।

![Call parking: कॉल को पहले खाली स्लॉट (701–720) में पार्क करने के लिए 700 डायल करें; Asterisk स्लॉट की घोषणा करता है, जिसे आप कॉल पुनः प्राप्त करने के लिए किसी भी फोन से डायल करते हैं](../images/13-pbx-features-fig04.png)

डिफ़ॉल्ट रूप से, 700 extension का उपयोग कॉल को पार्क करने के लिए किया जाता है। बातचीत के बीच में, कॉल को 700 extension पर ट्रांसफर करने के लिए # दबाएं। अब Asterisk आपके पार्किंग extension की घोषणा करेगा, जैसे 701 या 702। फोन काट दें, और कॉलर को होल्ड पर रखा जाएगा। अपने डेस्क फोन पर जाएं और कॉल को पुनः प्राप्त करने के लिए घोषित पार्किंग extension डायल करें। यदि कॉलर को लंबे समय तक पार्क किया जाता है, तो टाइमआउट सुविधा सक्रिय हो जाएगी और मूल रूप से डायल किया गया extension फिर से बजने लगेगा।

### Configuration task list

Call parking को सक्षम करने के लिए नीचे दिए गए चरणों का पालन करें। चरण 1: पार्किंग लॉट को अपने dialplan से पहुँच योग्य बनाएं (आवश्यक)। डिफ़ॉल्ट पार्किंग लॉट का `context` `parkedcalls` है (`res_parking.conf` में सेट किया गया है)। उस context को उस context में शामिल करें जहाँ से आपके फोन डायल करते हैं, `extensions.conf` में:

```
include => parkedcalls
```

चरण 2: #700 डायल करके Call parking सुविधा का परीक्षण करें। नोट्स:

- पार्किंग extension dialplan show CLI कमांड में नहीं दिखाई देगा।
- पार्किंग कॉन्फ़िगरेशन फ़ाइल को बदलने के बाद पार्किंग मॉड्यूल को पुनः लोड करना आवश्यक है: `module reload res_parking.so`। features.conf परिवर्तनों के लिए, `module reload features.so`।
- कॉल पार्क करने के लिए, आपको #700 पर ट्रांसफर करने की आवश्यकता है। `Dial()` एप्लिकेशन में `t` और `T` विकल्पों को सत्यापित करें।

## Call pickup

Call pickup आपको अपने ही call group में किसी सहकर्मी की कॉल को उठाने की सुविधा देता है। उदाहरण के लिए, यह आपको उस कॉल को उठाने के लिए अपनी जगह से उठने से बचने में मदद करता है जो आपके कमरे में किसी अन्य व्यक्ति के लिए बज रही है, लेकिन वह व्यक्ति वहां मौजूद नहीं है। *8 डायल करके, आप अपने call group के भीतर कॉल को उठा सकते हैं। इस नंबर को `features.conf` फ़ाइल में संशोधित किया जा सकता है।

![Call pickup: सदस्य केवल अपने समूह के भीतर ही कॉल उठा सकते हैं; ऑपरेटर (pickupgroup=1,2,3) हर समूह से कॉल उठा सकता है](../images/13-pbx-features-fig05.png)

### Configuration task list

Call pickup सुविधा को कॉन्फ़िगर करने के लिए नीचे दिए गए चरणों का पालन करें। चरण 1: अपने extensions के लिए एक call group कॉन्फ़िगर करें। यह चैनल कॉन्फ़िगरेशन फ़ाइल (pjsip.conf, iax.conf, chan_dahdi.conf) में किया जाता है। PJSIP endpoints के लिए, `pjsip.conf` के endpoint सेक्शन में `call_group` और `pickup_group` सेट करें (pjsip.conf में snake_case विकल्प नामों का उपयोग होता है)। यह कार्य आवश्यक है।

PJSIP (pjsip.conf) के लिए:
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


चरण 2: call-pickup सुविधा नंबर बदलें (वैकल्पिक)। यह `pjsip.conf` में नहीं, बल्कि `features.conf` के `[general]` सेक्शन में सेट किया जाता है:

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## Conference (कॉल कॉन्फ्रेंस)

Asterisk पर कॉन्फ्रेंस लागू करने के कई अलग-अलग तरीके हैं। पहला विकल्प केवल फोन की थ्री-वे कॉन्फ्रेंस क्षमता का उपयोग करना है। फोन में इस सुविधा का उपयोग करके आपको सर्वर पर किसी भी सपोर्ट की आवश्यकता नहीं होती है। हालाँकि, जब आप 3 से अधिक लोगों के साथ कॉन्फ्रेंस करना चाहते हैं, तो आपको एक कॉन्फ्रेंस रूम चलाना चाहिए। Asterisk का आधुनिक कॉन्फ्रेंस एप्लिकेशन ConfBridge (`app_confbridge`) है।

ConfBridge HD वॉयस कॉन्फ्रेंस और वीडियो कॉन्फ्रेंसिंग को सपोर्ट करता है। वीडियो कॉन्फ्रेंसिंग के लिए कुछ सीमाएँ हैं जैसे कि कोई ट्रांसकोडिंग नहीं — सभी प्रतिभागियों को एक ही codec और प्रोफाइल का उपयोग करना होगा। वीडियो कॉन्फ्रेंस 'फॉलो-द-टॉकर' मोड का उपयोग करती है, जो बोलने वाले अंतिम व्यक्ति की छवि प्रदर्शित करती है। आप ConfBridge में आसानी से नए DTMF मेनू कॉन्फ़िगर कर सकते हैं।

ConfBridge पुराने MeetMe एप्लिकेशन की जगह लेता है, जिसे Asterisk 19 में हटा दिया गया था। MeetMe अभी भी Asterisk 22 सोर्स ट्री में आता है, लेकिन यह DAHDI पर निर्भर करता है और डिफ़ॉल्ट रूप से बिल्ड नहीं होता है, इसलिए एक सामान्य PJSIP इंस्टॉलेशन पर यह उपलब्ध नहीं होता है — ConfBridge ही समर्थित कॉन्फ्रेंस एप्लिकेशन है। MeetMe के विपरीत, ConfBridge को DAHDI या हार्डवेयर टाइमिंग सोर्स की आवश्यकता **नहीं** होती है: यह Asterisk के इन-बिल्ट टाइमिंग इंटरफ़ेस (Linux पर `res_timing_timerfd`, या `res_timing_pthread`) पर निर्भर करता है, इसलिए किसी `dahdi_dummy` मॉड्यूल की आवश्यकता नहीं है। यदि आप किसी पुराने सिस्टम से माइग्रेट कर रहे हैं जो `MeetMe()` और `meetme.conf` का उपयोग करता था, तो उन्हें नीचे बताए अनुसार `ConfBridge()` और `confbridge.conf` से बदलें।

### ConfBridge

कॉन्फ्रेंस रूम शुरू करने के लिए, सिंटैक्स नीचे सूचीबद्ध है।

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

कमांड का पूरा विवरण प्राप्त करने के लिए आप core show application confbridge का उपयोग कर सकते हैं।

![`core show application confbridge` का आउटपुट, जो सारांश, सिंटैक्स, और bridge_profile, user_profile, तथा menu तर्कों को दर्शाता है](../images/13-pbx-features-fig06.png)

![कई PJSIP endpoint एक नामित ConfBridge कॉन्फ्रेंस (101) में शामिल होते हैं; एक प्रतिभागी एडमिन है। मिक्सिंग और टाइमिंग को `app_confbridge` द्वारा `bridge_softmix` और इन-बिल्ट `res_timing_*` टाइमर के साथ संभाला जाता है — किसी DAHDI की आवश्यकता नहीं है।](../images/13-pbx-features-fig09.png)

जैसा कि आप ऊपर देख सकते हैं, तीन महत्वपूर्ण तर्क हैं, जिनमें से प्रत्येक `confbridge.conf` में एक सेक्शन प्रकार से मैप होता है। **bridge_profile** (एक `type=bridge` सेक्शन): यहाँ आप प्रतिभागियों की अधिकतम संख्या (`max_members`), रिकॉर्डिंग (`record_conference`), `video_mode`, और कई अन्य ब्रिज-वाइड पैरामीटर चुनते हैं।

यहाँ पूरी उदाहरण फ़ाइल को पुन: प्रस्तुत करने का कोई मतलब नहीं है, इसलिए मैं आपको confbridge.conf फ़ाइल में bridge_profile को कॉन्फ़िगर करने का एक सरल उदाहरण देता हूँ।

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile** (एक `type=user` सेक्शन): यहाँ आप प्रति-उपयोगकर्ता विशिष्ट विकल्प परिभाषित करते हैं, जैसे कि क्या उपयोगकर्ता एक एडमिनिस्ट्रेटर है (`admin=yes`), क्या वे म्यूट होकर शुरू करते हैं (`startmuted=yes`), म्यूजिक ऑन होल्ड, और कई अन्य प्रति-उपयोगकर्ता विकल्प। उदाहरण:

```
[admin_user]
type=user
admin=yes
```

**menu** (एक `type=menu` सेक्शन): यहाँ आप कॉन्फ्रेंस के लिए कीपैड (DTMF) मैपिंग परिभाषित करते हैं — उदाहरण के लिए कौन सी कुंजी म्यूट को टॉगल करती है, वॉल्यूम समायोजित करती है, या कॉन्फ्रेंस छोड़ती है। सभी उपलब्ध क्रियाओं को देखने के लिए `confbridge.conf.sample` फ़ाइल देखें। उदाहरण:

```
[my_menu]
type=menu
*=playback_and_continue
1=toggle_mute
2=decrease_listening_volume
3=increase_listening_volume
4=decrease_talking_volume
5=increase_talking_volume
6=leave_conference
```

#### Confbridge फंक्शन्स

कॉन्फ्रेंस ब्रिज विकल्पों को dialplan में CONFBRIDGE() फंक्शन का उपयोग करके गतिशील रूप से पास किया जा सकता है। नीचे दिए गए उदाहरण देखें:

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### ConfBridge एडमिन कमांड और MeetMe से माइग्रेशन

यदि आप MeetMe से आ रहे हैं, तो जिन एडमिन फंक्शन्स का उपयोग आपने `MeetMeAdmin()` और `a` (एडमिन) विकल्प के माध्यम से किया था, वे अब **admin user profile** (`admin=yes`) और **menu** क्रियाओं के माध्यम से व्यक्त किए जाते हैं। एक एडमिनिस्ट्रेटर जो एडमिन प्रोफाइल और एडमिन क्रियाओं वाले मेनू के साथ जुड़ता है, वह रूम को लॉक कर सकता है, उपयोगकर्ताओं को बाहर निकाल सकता है, और कीपैड से सीधे प्रतिभागियों को म्यूट कर सकता है। `confbridge.conf` में प्रासंगिक मेनू क्रियाएं हैं:

- `admin_kick_last` -- अंतिम जुड़े उपयोगकर्ता को बाहर निकालें
- `admin_toggle_mute_participants` -- सभी गैर-एडमिन प्रतिभागियों को म्यूट/अनम्यूट करें
- `toggle_mute` -- स्वयं को म्यूट/अनम्यूट करें
- `participant_count` -- प्रतिभागियों की संख्या की घोषणा करें
- `leave_conference` -- ब्रिज छोड़ें और dialplan में जारी रखें

ये MeetMe `MeetMe()` विकल्प फ्लैग्स (`a`, `A`, `m`, `M`, `l`, `x`, …) और `MeetMeAdmin()` कमांड्स (`k`, `K`, `L`, `M`, `N`, …) की जगह लेते हैं। एक आधुनिक PJSIP इंस्टॉलेशन पर आप `app_meetme` को बिल्कुल भी लोड नहीं करेंगे; सभी कॉन्फ्रेंस कॉन्फ़िगरेशन `confbridge.conf` में रहते हैं, और परिवर्तन `module reload app_confbridge.so` के साथ लागू किए जाते हैं (ConfBridge लॉजिक `app_confbridge` में रहता है; कोई `res_confbridge` मॉड्यूल नहीं है)।

### ConfBridge उदाहरण

extension 500 पर पहुँचने योग्य कॉन्फ्रेंस रूम बनाने के लिए, `extensions.conf` में:

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

500 डायल करने वाला पहला कॉलर कॉन्फ्रेंस `101` बनाता है; बाद के कॉलर इसमें शामिल हो जाते हैं। यहाँ संदर्भित प्रोफाइल और मेनू (`default_bridge`, `default_user`, `sample_user_menu`) `confbridge.conf` में परिभाषित हैं। PIN की आवश्यकता के लिए, user profile में `pin=` सेट करें; किसी प्रतिभागी को कॉन्फ्रेंस एडमिनिस्ट्रेटर बनाने के लिए, उन्हें `admin=yes` के साथ एक user profile दें।

## Call Recording

Asterisk में कॉल रिकॉर्ड करने के कई तरीके हैं। आप कॉल को आसानी से रिकॉर्ड करने के लिए `MixMonitor()` एप्लिकेशन का उपयोग कर सकते हैं। (पुराना `Monitor` एप्लिकेशन, जो दो अलग-अलग फाइलें रिकॉर्ड करता था, उसे हटा दिया गया है; इसके बजाय `MixMonitor` का उपयोग करें।)

### MixMonitor एप्लिकेशन का उपयोग करना

`MixMonitor` एप्लिकेशन वर्तमान channel में ऑडियो को निर्दिष्ट फाइल में रिकॉर्ड करता है। यदि फाइल का नाम एक absolute path है, तो यह उस path का उपयोग करता है। अन्यथा, यह asterisk.conf से कॉन्फ़िगर की गई monitoring directory में फाइल बनाता है।

![MixMonitor() एप्लिकेशन: एक channel के ऑडियो को रिकॉर्ड और मिक्स करके एक फाइल में डालता है, जिसमें append, bridged-only, और volume adjustment के विकल्प होते हैं](../images/13-pbx-features-fig09.png)

### MixMonitor()

कॉल रिकॉर्ड करें और रिकॉर्डिंग के दौरान ऑडियो को मिक्स करें। सिंटैक्स: `MixMonitor(filename.extension[,options[,command]])`। वर्तमान channel पर ऑडियो को निर्दिष्ट फाइल में रिकॉर्ड करता है। मान्य विकल्प:

- a - फाइल को ओवरराइट करने के बजाय उसमें जोड़ता (append) है।
- b - केवल तब ऑडियो को फाइल में सहेजता है जब channel bridged हो।
- नोट: इसमें कॉन्फ्रेंस शामिल नहीं हैं।
- v(<x>) - श्रव्य (audible) वॉल्यूम को <x> के कारक (factor) से समायोजित करता है (-4 से 4 तक)।
- V(<x>) - बोले गए वॉल्यूम को <x> के कारक से समायोजित करता है (-4 से 4 तक)।
- W(<x>) - श्रव्य और बोले गए दोनों वॉल्यूम को <x> के कारक से समायोजित करता है (-4 से 4 तक)।
- <command> रिकॉर्डिंग समाप्त होने पर निष्पादित किया जाएगा। ^{X} से मेल खाने वाली कोई भी स्ट्रिंग ${X} में unescape हो जाएगी और उस समय सभी variables का मूल्यांकन किया जाएगा। MIXMONITOR_FILENAME variable में रिकॉर्डिंग के लिए उपयोग की गई फाइल का नाम होगा।

एक दिलचस्प संसाधन वन-टच रिकॉर्डिंग फीचर `automixmon` है, जो एक पार्टी को कॉल के दौरान DTMF कोड (`features.conf` नमूना `*3` का सुझाव देता है; कोई इन-बिल्ट डिफ़ॉल्ट नहीं है, इसलिए आपको इसे सेट करना होगा) डायल करने की अनुमति देता है ताकि तुरंत रिकॉर्डिंग शुरू (और बंद) की जा सके। यह MixMonitor पर आधारित है, इसलिए यह एक सिंगल मिक्स्ड फाइल लिखता है। उदाहरण:

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

`X` और `x` विकल्प क्रमशः कॉलर और कैली (callee) के लिए वन-टच MixMonitor फीचर को सक्षम करते हैं। चूंकि MixMonitor एक सिंगल मिक्स्ड फाइल रिकॉर्ड करता है, इसलिए बाद में अलग-अलग IN/OUT फाइलों को संयोजित करने की कोई आवश्यकता नहीं है (पुराना `automon`/`Monitor` दृष्टिकोण, जो `soxmix` के लिए दो फाइलें बनाता था, उसे `Monitor` एप्लिकेशन के साथ हटा दिया गया था)।

यदि आप Dial() एप्लिकेशन से पहले Set() का उपयोग नहीं करना चाहते हैं, तो आप इसे globals सेक्शन में सेट कर सकते हैं:

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### Music on hold

Music on hold (MOH) संस्करण 1.0, 1.2, और 1.4 के बीच कई बार बदल चुका है। नवीनतम संस्करण में, MOH डिफ़ॉल्ट रूप से "FILE-BASED" होता है। दूसरे शब्दों में, Asterisk g729, alaw, ulaw, और gsm जैसे फॉर्मेट में MOH फाइलें प्रदान करेगा। इस प्रकार, संगीत को channel पर भेजने से पहले उसे transcode करना आवश्यक नहीं है। यह प्रोसेसर का समय बचाता है, जो प्रोडक्शन सिस्टम के साथ काम करने वालों के लिए एक स्वागत योग्य संशोधन है।

पुराने संस्करणों में, MOH आमतौर पर MP3 द्वारा प्रदान किया जाता था (इसे अभी भी उस तरह से कॉन्फ़िगर किया जा सकता है)। MP3 का उपयोग करके MOH प्रदान करने के लिए Asterisk को transcode करना पड़ता है, जिससे इस प्रक्रिया में मूल्यवान CPU शक्ति खर्च होती है।

नई कॉन्फ़िगरेशन फाइल नीचे दिखाई गई है। ध्यान दें कि डिफ़ॉल्ट क्लास अब नेटिव फाइल फॉर्मेट mode=files का उपयोग करती है। अन्य सभी मोड कमेंट किए गए हैं। इस बिंदु पर एकमात्र अनकमेंटेड क्लास default है। यदि आप अलग-अलग फाइलों के लिए अलग-अलग क्लास रखना चाहते हैं, तो आपको नए सेक्शन (क्लास) बनाने होंगे।

![musiconhold.conf नमूना कॉन्फ़िगरेशन, मान्य MOH मोड (quietmp3, mp3, custom, files, …) को सूचीबद्ध करता है](../images/13-pbx-features-fig10.png)

```
; Music on Hold -- Sample Configuration
;[samplemp3]
;mode=quietmp3
;directory=/var/lib/asterisk/mohmp3
;
; valid mode options:
; quietmp3      -- default
; mp3           -- loud
; mp3nb         -- unbuffered
; quietmp3nb    -- quiet unbuffered
; custom        -- run a custom application (See examples below)
; files         -- read files from a directory in any Asterisk supported
;                  media format. (See examples below)
;[manual]
;mode=custom
; Note that with mode=custom, a directory is not required, such as when reading
; from a stream.
;directory=/var/lib/asterisk/mohmp3
;application=/usr/bin/mpg123 -q -r 8000 -f 8192 -b 2048 --mono -s
;[ulawstream]
;mode=custom
;application=/usr/bin/streamplayer 192.168.100.52 888
;format=ulaw
; mpg123 on Solaris does not always exit properly; madplay may be a better
; choice
;[solaris]
;mode=custom
;directory=/var/lib/asterisk/mohmp3
;application=/site/sw/bin/madplay -Q -o raw:- --mono -R 8000 -a -12
;
;
; File-based (native) music on hold
;
; This plays files directly from the specified directory, no external
; processes are required. Files are played in normal sorting order
; (same as a sorted directory listing), and no volume or other
; sound adjustments are available. If the file is available in
; the same format as the channel's codec, then it will be played
; without transcoding (same as Playback would do in the dialplan).
; Files can be present in as many formats as you wish, and the
; 'best' format will be chosen at playback time.
;
; NOTE:
; If you are not using "autoload" in modules.conf, then you
; must ensure that the format modules for any formats you wish
; to use are loaded _before_ res_musiconhold. If you do not do
; this, res_musiconhold will skip the files it is not able to
; understand when it loads.
;
[default]
mode=files
directory=/var/lib/asterisk/moh
;
;[native-random]
;mode=files
;directory=/var/lib/asterisk/moh
;random=yes     ; Play the files in a random order
```

### MOH कॉन्फ़िगरेशन कार्य

अब, music on hold का उपयोग करने के लिए, channel कॉन्फ़िगरेशन फाइलों (chan_dahdi.conf, pjsip.conf, iax.conf, आदि) में MOH क्लास सेट करें। PJSIP endpoints के लिए, `pjsip.conf` के endpoint सेक्शन में `moh_suggest` सेट करें (पुराना `musicclass` विकल्प नाम chan_dahdi और अन्य channel ड्राइवर्स पर लागू होता है, PJSIP पर नहीं)। इंस्टॉल की गई freeplay धुनें अब wav फॉर्मेट में हैं। इंस्टॉलेशन के समय, आप उपलब्ध MOH फाइल फॉर्मेट का चयन कर सकते हैं (make menuselect का उपयोग करके)। यदि आप नई MOH फाइलें जोड़ना चाहते हैं, तो आपको उन्हें आवश्यक फॉर्मेट में प्रदान करना होगा। उदाहरण के लिए:

`/etc/asterisk/chan_dahdi.conf` में, `musiconhold` लाइन जोड़ें:

```
[channels]
musiconhold=default
```

फिर उस क्लास को परिभाषित करने के लिए `/etc/asterisk/musiconhold.conf` को एडिट करें:

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

Dialplan में, आप `StartMusicOnHold` के साथ एक channel पर music on hold शुरू कर सकते हैं (और `StopMusicOnHold` के साथ इसे रोक सकते हैं):

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

त्वरित परीक्षण के रूप में एक निश्चित समय के लिए music on hold चलाने के लिए, अवधि (सेकंड में) के साथ `MusicOnHold` एप्लिकेशन का उपयोग करें:

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## Application Maps

Application maps आपको features.conf फ़ाइल के `[applicationmap]` सेक्शन का उपयोग करके नई सुविधाएँ जोड़ने की अनुमति देते हैं। मान लीजिए कि आपको कॉल सेंटर में कॉल का उत्तर देते समय ग्राहक के प्रकार की पहचान करने की आवश्यकता है। आप प्रत्येक ग्राहक प्रकार के लिए एक application map बना सकते हैं, जो प्रति प्रकार उत्तर दिए गए ग्राहकों की संख्या की गणना कर सकता है।

## सारांश

इस अध्याय में आपने सीखा कि Asterisk की PBX विशेषताएं कहाँ स्थित होती हैं — कुछ कोर में, कुछ dialplan में, और कुछ फोन पर — और DTMF फीचर कोड को `features.conf` के `[featuremap]` अनुभाग में कैसे मैप किया जाता है। आपने **call transfer** (ब्लाइंड और अटेंडेड) और **call parking** (`res_parking.conf`, `k`/`K` Dial विकल्पों और `parkedcalls` लॉट के साथ), समूह द्वारा **call pickup**, और **ConfBridge** (`confbridge.conf` ब्रिज/यूज़र/मेनू प्रोफाइल) के साथ **conferencing** को कॉन्फ़िगर किया, जो पुराने MeetMe की जगह लेता है। आपने MixMonitor (`automixmon`, `X`/`x` Dial विकल्प, और `DYNAMIC_FEATURES`) के साथ **one-touch recording** सेट अप की, **music on hold** को कॉन्फ़िगर किया, और देखा कि कैसे **application maps** आपको अपने स्वयं के dialplan लॉजिक को DTMF अनुक्रम से जोड़ने की अनुमति देते हैं। इन बिल्डिंग ब्लॉक्स के साथ आप वे दैनिक विशेषताएं प्रदान कर सकते हैं जिनकी उपयोगकर्ता एक व्यावसायिक PBX से अपेक्षा करते हैं।

## Quiz

1. कॉल पार्किंग के बारे में कौन से कथन सत्य हैं?
   - A. डिफ़ॉल्ट रूप से, कॉल पार्किंग के लिए extension 800 का उपयोग किया जाता है।
   - B. जब आप अपनी डेस्क से दूर होते हैं और आपको कॉल प्राप्त होती है, तो आप उसे पार्क कर सकते हैं; सिस्टम पार्किंग स्लॉट की घोषणा करता है, और आप कॉल को पुनः प्राप्त करने के लिए किसी भी फोन से उस स्लॉट को डायल करते हैं।
   - C. डिफ़ॉल्ट रूप से, extension 700 एक कॉल को पार्क करता है, और कॉल 701–720 स्लॉट में पार्क की जाती हैं।
   - D. पार्क की गई कॉल को पुनः प्राप्त करने के लिए आप 700 डायल करते हैं।
2. कॉल-पिकअप सुविधा का उपयोग करने के लिए, सभी extensions को एक ही ___ में होना चाहिए। DAHDI चैनल्स के लिए इसे ___ फ़ाइल में कॉन्फ़िगर किया जाता है।
3. कॉल ट्रांसफर करते समय आप ___ ट्रांसफर के बीच चयन कर सकते हैं, जहाँ डेस्टिनेशन से पहले परामर्श नहीं किया जाता है, और एक ___ ट्रांसफर, जहाँ आप इसे पूरा करने से पहले डेस्टिनेशन से बात करते हैं।
4. अटेंडेड (परामर्शपूर्ण) ट्रांसफर करने के लिए आप ___ अनुक्रम का उपयोग करते हैं; ब्लाइंड ट्रांसफर के लिए आप ___ का उपयोग करते हैं।
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. Asterisk 22 में कॉन्फ्रेंस कॉल होस्ट करने के लिए, आप ___ एप्लिकेशन का उपयोग करते हैं।
6. ConfBridge में, किसी प्रतिभागी को एडमिनिस्ट्रेटर विशेषाधिकार (किक करना, दूसरों को म्यूट करना, रूम लॉक करना) उनके यूजर प्रोफाइल (`confbridge.conf`) में ___ सेट करके दिए जाते हैं:
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. म्यूजिक ऑन होल्ड के लिए सबसे अच्छा फॉर्मेट MP3 है, क्योंकि यह Asterisk सर्वर पर बहुत कम प्रोसेसिंग पावर का उपयोग करता है।
   - A. सत्य
   - B. असत्य
8. किसी विशिष्ट कॉल ग्रुप से कॉल पिक अप करने के लिए, आपको मिलान वाले ___ ग्रुप में होना चाहिए।
9. आप MixMonitor() एप्लिकेशन या वन-टच रिकॉर्डिंग (`automixmon`) सुविधा के साथ कॉल रिकॉर्ड कर सकते हैं। `features.conf` सैंपल में, `automixmon` को ___ DTMF अनुक्रम के साथ मैप किया गया है।
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. ConfBridge में, कौन सा `confbridge.conf` यूजर-प्रोफाइल विकल्प प्रतिभागी को म्यूट होकर शामिल होने के लिए बाध्य करता है (वे कॉन्फ्रेंस सुन सकते हैं लेकिन अनम्यूट होने तक उन्हें सुना नहीं जा सकता)?
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**उत्तर:** 1 — B, C · 2 — pickup group; `chan_dahdi.conf` · 3 — blind; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
