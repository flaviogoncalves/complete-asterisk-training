# Asterisk 22 इंस्टॉल करना

पहले अध्याय में, हमने टेलीफोनी वातावरण में Asterisk के उपयोगी होने के बारे में थोड़ा सीखा था। इस अध्याय में, हम Asterisk को डाउनलोड और इंस्टॉल करने के तरीके को कवर करेंगे। शुरू करने से पहले, यह सीखना आवश्यक है कि इसे कंपाइल और इंस्टॉल कैसे किया जाए। पारंपरिक Microsoft™ Windows™ उपयोगकर्ताओं के लिए कंपाइलेशन प्रक्रिया अजीब लग सकती है, लेकिन Linux™ वातावरण में यह काफी सामान्य है। Asterisk को कंपाइल करते समय कोई भी अपने हार्डवेयर के लिए अनुकूलित कोड प्राप्त कर सकता है, और हम यहाँ यही करेंगे। Asterisk कई ऑपरेटिंग सिस्टम पर चलता है, लेकिन हम चीजों को आसान रखेंगे और केवल एक का उपयोग करेंगे: Linux। हम **Ubuntu 24.04 LTS** का उपयोग करते हैं क्योंकि इसकी निर्भरताएँ (dependencies) इंस्टॉल करना आसान है और यह कम फुटप्रिंट वाला एक स्थिर, अच्छी तरह से समर्थित सर्वर वितरण है। यदि आप किसी अन्य वितरण को प्राथमिकता देते हैं, तो पैकेज के नामों को तदनुसार समायोजित करें।

यह संस्करण **Asterisk 22 LTS** (2024-10-16 को जारी; 2028-10-16 तक पूर्ण समर्थन, 2029-10-16 तक सुरक्षा सुधार) को लक्षित करता है। Asterisk 22 वर्तमान लॉन्ग-टर्म सपोर्ट रिलीज़ है। ध्यान दें कि 2018 में Digium का अधिग्रहण **Sangoma** द्वारा किया गया था, और Asterisk अब Sangoma द्वारा प्रायोजित है — इस पूरे अध्याय में "Digium" के संदर्भ ऐतिहासिक हार्डवेयर के लिए लीगेसी ब्रांड को संदर्भित करते हैं।

## उद्देश्य

इस अध्याय के अंत तक आप निम्नलिखित कार्य करने में सक्षम होंगे:

- Asterisk के लिए हार्डवेयर आवश्यकताओं का निर्धारण करना;
- आवश्यक निर्भरताओं (dependencies) के साथ Linux इंस्टॉल करना;
- HTTPS के माध्यम से एक स्थिर (stable) संस्करण डाउनलोड करना;
- Asterisk को कंपाइल करना; और
- यह सीखना कि बूट समय पर Asterisk को कैसे शुरू किया जाए।

## Minimum Hardware Required

Asterisk को चलाने के लिए बहुत अधिक हार्डवेयर की आवश्यकता नहीं होती है, हालाँकि आपकी आवश्यकताओं के लिए सर्वोत्तम हार्डवेयर चुनने के लिए कुछ सुझाव दिए गए हैं। अपना हार्डवेयर चुनते समय आपको निम्नलिखित मुख्य कारकों पर विचार करना चाहिए:

- पंजीकृत उपयोगकर्ताओं की कुल संख्या। यह परिभाषित करें कि आपको प्रति सेकंड कितने रजिस्ट्रेशन का समर्थन करने की आवश्यकता है।
- एक साथ होने वाली कॉलों की कुल संख्या। यह परिभाषित करें कि आपको Asterisk सर्वर पर नेटवर्क एडेप्टर और ब्रिज में कितनी नेटवर्क बातचीत को प्रोसेस करने की आवश्यकता है।
- आपको किन codecs का समर्थन करने की आवश्यकता है। उच्च जटिलता वाले codecs के लिए आपके सर्वर में बहुत अधिक CPU/FPU पावर की आवश्यकता होगी; उदाहरण के लिए, iLBC को इसके निर्माता (Global IP Sound) द्वारा TI C54x DSP पर 30 ms फ्रेम के लिए लगभग 18 MIPS (और 20 ms फ्रेम के लिए लगभग 15 MIPS) पर मापा गया था।
- Echo cancellation। Echo cancellation में बहुत अधिक CPU/FPU लग सकता है, कुछ मामलों में आपको टेलीफोनी इंटरफ़ेस कार्ड में DSP का उपयोग करके हार्डवेयर Echo cancellation चुनना चाहिए।
- उपलब्धता। उपलब्धता बढ़ाने के लिए RAID1 या 5 का उपयोग करें। याद रखें, Asterisk एक 24x7 एप्लिकेशन है।

Asterisk सर्वर के लिए मुख्य घटक नेटवर्क एडेप्टर है। एक अच्छे सर्वर नेटवर्क एडेप्टर की अनुशंसा की जाती है। जब आपको g.729 और iLBC जैसे उच्च जटिलता वाले codecs और Echo cancellation का समर्थन करने की आवश्यकता होती है, तो CPU महत्वपूर्ण होता है। आप इसे समर्पित DSPs पर ऑफलोड करना चुन सकते हैं: Sangoma (पूर्व में Digium) TC400B नामक एक DSP कार्ड प्रदान करता है जो 120 G.729 एक साथ कॉलों का समर्थन करने में सक्षम है।

सबसे अच्छा अभ्यास किसी ज्ञात निर्माता से एक नया, सर्वर क्लास कंप्यूटर चुनना है। यह जानने के लिए कि कोई विशिष्ट मशीन वास्तव में कितनी एक साथ कॉलों या कितने पंजीकृत उपयोगकर्ताओं का समर्थन कर सकती है, आपको SIPP (http://sipp.sourceforge.net) जैसे स्ट्रेस टेस्ट टूल के साथ इस हार्डवेयर का परीक्षण करना चाहिए। Xorcom (http://www.xorcom.com) जैसे कुछ हार्डवेयर निर्माता अपनी वेबसाइट पर इसके परिणाम प्रकाशित करते हैं।

नोट: कुछ Asterisk एप्लिकेशन, जैसे ConfBridge और music on hold, को एक आंतरिक टाइमिंग स्रोत की आवश्यकता होती है। आधुनिक Linux पर यह इन-बिल्ट `res_timing_timerfd` मॉड्यूल द्वारा स्वचालित रूप से प्रदान किया जाता है — किसी टेलीफोनी हार्डवेयर की आवश्यकता नहीं है। (पुराना `dahdi_dummy` सॉफ़्टवेयर टाइमर अब मौजूद नहीं है; इसकी कार्यक्षमता को DAHDI Linux 2.3.0 में मुख्य `dahdi` कर्नेल मॉड्यूल में शामिल कर दिया गया था।) आप CLI कमांड `timing test` के साथ सक्रिय टाइमर की पुष्टि कर सकते हैं।

### Hardware configuration

Asterisk हार्डवेयर का परिष्कृत होना आवश्यक नहीं है। आपको महंगे वीडियो कार्ड या कई पेरिफेरल्स की आवश्यकता नहीं है। हार्डवेयर कॉन्फ़िगरेशन के बारे में कुछ सुझाव:

- अनावश्यक इंटरप्ट्स की खपत से बचने के लिए अप्रयुक्त USB, सीरियल और पैरेलल पोर्ट को अक्षम करें।
- एक मजबूत नेटवर्क इंटरफ़ेस कार्ड आवश्यक है।
- यदि आप टेलीफोनी इंटरफ़ेस कार्ड का उपयोग कर रहे हैं तो विशेष सावधानी बरतें। कुछ कार्ड 3.3 वोल्ट PCI बस का उपयोग करते हैं, और उनके लिए मदरबोर्ड ढूंढना आसान नहीं है। इन दिनों, PCI express अधिक आसानी से मिल जाता है।
- हार्ड डिस्क पर पूरा ध्यान दें, PBX 24x7 शासन में काम करने के लिए उपयोग किया जाता है जबकि डेस्कटॉप 8x5 काम करते हैं। PBX के लिए डेस्कटॉप हार्डवेयर का उपयोग न करें, आमतौर पर हार्ड डिस्क पहले वर्ष से पहले ही विफल हो जाती है। मेरी अनुशंसा एक सर्वर मशीन या 24x7 एप्लिकेशन चलाने के लिए डिज़ाइन किए गए उपकरण का उपयोग करने की है।

### IRQ sharing (legacy PCI cards only)

यह चिंता **केवल** तभी लागू होती है यदि आप भौतिक PCI/PCI-Express टेलीफोनी कार्ड (DAHDI हार्डवेयर) स्थापित करते हैं। ऐसे कार्ड बड़ी संख्या में इंटरप्ट्स उत्पन्न करते हैं, और पुराने सिंगल-CPU सिस्टम पर, किसी अन्य डिवाइस के साथ IRQ लाइन साझा करने से ड्राइवर की कार्यक्षमता कम हो सकती है और वॉयस क्वालिटी खराब हो सकती है। यदि आप टेलीफोनी कार्ड का उपयोग करते हैं, तो मशीन को Asterisk के लिए समर्पित करें, BIOS में किसी भी अप्रयुक्त ऑन-बोर्ड डिवाइस को अक्षम करें, और `cat /proc/interrupts` के साथ असाइन किए गए इंटरप्ट्स की जांच करें। MSI/MSI-X इंटरप्ट्स का उपयोग करने वाले आधुनिक मल्टी-कोर सर्वर व्यवहार में IRQ शेयरिंग को कोई समस्या नहीं बनाते हैं, और एक शुद्ध-VoIP परिनियोजन (कोई कार्ड नहीं) को इसके बारे में बिल्कुल भी चिंता करने की आवश्यकता नहीं है।

## Linux डिस्ट्रिब्यूशन का चयन

Asterisk को शुरू में Linux पर चलाने के लिए विकसित किया गया था। हालाँकि, यह BSD Unix या macOS पर भी चल सकता है। यदि आप Asterisk में नए हैं, तो पहले Linux का उपयोग करने का प्रयास करें क्योंकि यह बहुत आसान है। Asterisk आधिकारिक तौर पर RHEL परिवार (CentOS/RHEL/Fedora), Ubuntu, और Debian को लक्षित करता है। आज के समय में अच्छे व्यावहारिक विकल्प **Debian 12**, **Ubuntu 22.04 LTS / 24.04 LTS**, और **Rocky Linux 9 / AlmaLinux 9** हैं — CentOS Linux का जीवनकाल समाप्त हो चुका है, इसलिए RHEL-परिवार के सिस्टम पर Rocky या AlmaLinux को प्राथमिकता दें। इस पुस्तक के लिए मैं Ubuntu 24.04 LTS का उपयोग करूँगा। नीचे दी गई आधिकारिक रिलीज़ निर्देशिका से नवीनतम 24.04 पॉइंट-रिलीज़ सर्वर इमेज डाउनलोड करें (सटीक फ़ाइल नाम में वर्तमान पॉइंट रिलीज़ शामिल है, उदाहरण के लिए `ubuntu-24.04.4-live-server-amd64.iso`):

```
https://releases.ubuntu.com/24.04/
```

### Asterisk के लिए Linux तैयार करना

Asterisk को कंपाइल करने से पहले आपको एक कार्यशील Linux सिस्टम की आवश्यकता होती है जिसमें बिल्ड पैकेज इंस्टॉल हों। **Ubuntu 24.04 LTS Server** को एक वर्चुअल मशीन या समर्पित बॉक्स पर इंस्टॉल करें (64-बिट इमेज का उपयोग करें; इस पुस्तक में सब कुछ 64-बिट है, हालाँकि Asterisk स्वयं अभी भी 32-बिट x86 का समर्थन करता है)। हमने इस प्रशिक्षण के लिए VirtualBox का उपयोग किया है; आप <https://releases.ubuntu.com/24.04> से इमेज डाउनलोड कर सकते हैं। Linux को इंस्टॉल करना इस पुस्तक के दायरे से बाहर है — बुनियादी Linux ज्ञान एक पूर्वापेक्षा है। Linux इंस्टॉल हो जाने के बाद, आप Asterisk बिल्ड डिपेंडेंसी जोड़ेंगे (नीचे *डिपेंडेंसी इंस्टॉल करना* देखें) और फिर Asterisk को कंपाइल करेंगे।

## Asterisk के लिए Linux इंस्टॉल करना

Linux को सामान्य रूप से इंस्टॉल करें, बिना किसी ग्राफिकल डेस्कटॉप के। इंस्टॉलेशन के दौरान, एक मेल ट्रांसफर एजेंट (हम **exim4** का उपयोग करते हैं) को भी सक्षम करें — इस पुस्तक में बाद में voicemail-to-email सूचनाएं भेजने के लिए Asterisk को इसकी आवश्यकता होगी। **सावधानी:** ऑपरेटिंग सिस्टम इंस्टॉल करने से टारगेट डिस्क का डेटा मिट जाता है। यदि आप इसे फिजिकल हार्डवेयर पर इंस्टॉल कर रहे हैं, तो पहले अपने डेटा का बैकअप लें; वर्चुअल मशीन में इंस्टॉल करने से आपका होस्ट सुरक्षित रहता है। Ubuntu Server ISO (या VM की वर्चुअल ऑप्टिकल ड्राइव) से इंस्टॉलर को बूट करें और प्रॉम्प्ट्स का उत्तर दें — अधिकांश सीधे और सरल हैं।

## Installing dependencies

Asterisk और DAHDI को इंस्टॉल करने के लिए आपको कई सॉफ्टवेयर डिपेंडेंसीज इंस्टॉल करनी होंगी। Asterisk 22 में ऐसा करने का अनुशंसित तरीका सोर्स ट्री के साथ आने वाली स्क्रिप्ट का उपयोग करना है, जो प्रत्येक समर्थित डिस्ट्रीब्यूशन के लिए सही पैकेज नामों को जानती है। Asterisk सोर्स को डाउनलोड और एक्सट्रैक्ट करने के बाद (नीचे "Compiling Asterisk" देखें), इसे चलाएं:

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. root के रूप में लॉगिन करें (या `sudo` का उपयोग करें)।
2. यदि आप Debian/Ubuntu सिस्टम पर डिपेंडेंसीज को मैन्युअल रूप से इंस्टॉल करना पसंद करते हैं, तो समकक्ष पैकेज सूची यह है:

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

ध्यान दें कि Asterisk सोर्स अब Git पर होस्ट किया जाता है, इसलिए `subversion` की अब आवश्यकता नहीं है, और आधुनिक Debian/Ubuntu में वर्शन्ड `libncurses5-dev` के बजाय `libncurses-dev` आता है। मैन्युअल रूप से बनाए रखी गई सूची के बजाय `./contrib/scripts/install_prereq install` को प्राथमिकता दें, क्योंकि स्क्रिप्ट हमेशा आपके डिस्ट्रीब्यूशन के लिए सही पैकेज नामों को ट्रैक करती है।

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) एनालॉग और डिजिटल कार्ड के लिए ड्राइवर्स का आर्किटेक्चर है। Asterisk इंस्टॉल करने से पहले, यदि आप एनालॉग या डिजिटल इंटरफेस का उपयोग करने की योजना बना रहे हैं, तो DAHDI इंस्टॉल करना महत्वपूर्ण है। DAHDI अभी भी एनालॉग/डिजिटल टेलीफोनी कार्ड के लिए मौजूद है लेकिन यह तेजी से विशिष्ट (niche) होता जा रहा है — अधिकांश आधुनिक डिप्लॉयमेंट पूरी तरह से VoIP हैं और इस सेक्शन को पूरी तरह से छोड़ सकते हैं। DAHDI केवल तभी इंस्टॉल करें यदि आपके पास भौतिक टेलीफोनी इंटरफेस हार्डवेयर है। सोर्स फाइल्स को प्राप्त करने के लिए इसका उपयोग करें:

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

फाइल्स को अनकंप्रेस करने के लिए इसका उपयोग करें:

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### Compiling DAHDI drivers

आपको DAHDI मॉड्यूल्स को कंपाइल करना होगा। कमांड ./configure और make menuselect को कई साल पहले पेश किया गया था। बाद वाला आपको यह चुनने में सक्षम बनाता है कि किन यूटिलिटीज और मॉड्यूल्स को बिल्ड करना है। निम्नलिखित कमांड्स ऐसा करेंगी:

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

make install-config DAHDI को कॉन्फ़िगर कर दिया गया है। यदि आपके पास कोई DAHDI हार्डवेयर है, तो अब यह अनुशंसित है कि आप /etc/dahdi/modules को एडिट करें ताकि केवल इस सिस्टम में इंस्टॉल किए गए DAHDI हार्डवेयर के लिए सपोर्ट लोड हो सके। डिफ़ॉल्ट रूप से, DAHDI स्टार्ट होने पर सभी DAHDI हार्डवेयर के लिए सपोर्ट लोड हो जाता है। मुझे लगता है कि आपके सिस्टम पर मौजूद DAHDI हार्डवेयर यह है: usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware यह स्क्रीन (ऊपर) आपसे /etc/dahdi/modules फाइल को बदलने के लिए कहती है ताकि केवल आपके विशिष्ट कॉन्फ़िगरेशन के लिए आवश्यक ड्राइवर्स लोड हों और पता लगाया गया हार्डवेयर दिखाई दे। /etc/dahdi/modules फाइल को एडिट करें और केवल आवश्यक हार्डवेयर लोड करें। मेरे मामले में, मैं Xorcom Astribank 6FXS और 2FXO के साथ एक टेस्ट मशीन का उपयोग कर रहा था। फाइल नीचे दिखाई गई है।

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

अपने कंप्यूटर को री-इनिशियलाइज़ करें और ड्राइवर्स के सही लोडिंग को सत्यापित करें।

## कौन सा संस्करण चुनें

अंगूठे के नियम के रूप में, आपको उन सुविधाओं वाले संस्करण का उपयोग करना चाहिए जिनकी आपको आवश्यकता है। Asterisk LTS (लॉन्ग-टर्म सपोर्ट) और मानक रिलीज़ के वैकल्पिक रिलीज़ मॉडल का पालन करता है। इस संस्करण के समय, **Asterisk 22 वर्तमान LTS रिलीज़ है** (अक्टूबर 2024 में जारी; नवीनतम पॉइंट रिलीज़ 22.10.0 है), जो इसे अभी चुनने के लिए सबसे अच्छा विकल्प बनाता है। Asterisk 20 पिछला LTS है, और संस्करण 16 (जिसका उपयोग पहले संस्करण में किया गया था) का जीवनकाल समाप्त हो चुका है। प्रोडक्शन सिस्टम के लिए, हमेशा LTS रिलीज़ ही चुनें।

## Asterisk को कंपाइल करना

यदि आपने पहले कभी सॉफ़्टवेयर कंपाइल किया है, तो Asterisk को कंपाइल करना एक आसान कार्य होगा। Asterisk को कंपाइल और इंस्टॉल करने के लिए निम्नलिखित कमांड चलाएँ। याद रखें, आप `make menuselect` का उपयोग करके यह चुन सकते हैं कि कौन से एप्लिकेशन और मॉड्यूल बनाने हैं। चरण 1: सोर्स कोड डाउनलोड करें

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

चरण 2: बिल्ड पूर्वापेक्षाएँ (build prerequisites) इंस्टॉल करें (ऊपर "Installing dependencies" देखें)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

चरण 3: बिल्ड को कॉन्फ़िगर करें

```
./configure
```

चरण 4: बनाने के लिए मॉड्यूल चुनें

```
make menuselect
```

केवल आवश्यक मॉड्यूल इंस्टॉल करने के लिए `make menuselect` का उपयोग करें। Asterisk 22 में SIP चैनल **chan_pjsip** है (जो डिफ़ॉल्ट रूप से बिल्ड होता है); पुराना **chan_sip** Asterisk 21 में हटा दिया गया था और अब मौजूद नहीं है। Opus *pass-through* सीधे काम करता है (इन-ट्री `res_format_attr_opus` मॉड्यूल SDP नेगोशिएशन को संभालता है), लेकिन **codec_opus** ट्रांसकोडिंग मॉड्यूल अभी भी Sangoma/Digium का एक बाहरी, क्लोज्ड-सोर्स बाइनरी है — इसे menuselect में चुनने पर यह Digium के सर्वर से डाउनलोड हो जाता है। यह बाइनरी निःशुल्क है। विवरण के लिए नीचे "Selecting modules with menuselect" देखें।

चरण 5: Asterisk को बिल्ड और इंस्टॉल करें, फिर डिफ़ॉल्ट कॉन्फ़िगरेशन और सैंपल फ़ाइलें बनाएँ

```
make
make install
make samples
make config
ldconfig
```

`make install` बाइनरी और मॉड्यूल को इंस्टॉल करता है, `make samples` सैंपल कॉन्फ़िगरेशन फ़ाइलों को `/etc/asterisk` में लिखता है, `make config` आपके द्वारा पहचाने गए डिस्ट्रिब्यूशन के लिए SysV init स्टार्टअप स्क्रिप्ट को इंस्टॉल करता है (उदाहरण के लिए Debian/Ubuntu पर `/etc/init.d/asterisk`), और `ldconfig` शेयर्ड-लाइब्रेरी कैश को रिफ्रेश करता है। एक systemd यूनिट भी सोर्स ट्री में `contrib/systemd/asterisk.service` पर उपलब्ध होती है, लेकिन `make config` इसे स्वचालित रूप से इंस्टॉल नहीं करता है — यदि आप Asterisk को systemd के अंतर्गत चलाना पसंद करते हैं, तो इसे स्वयं कॉपी करके सही स्थान पर रखें (नीचे देखें)।

### menuselect के साथ मॉड्यूल चुनना

`make menuselect` एक टेक्स्ट-आधारित मेनू खोलता है जहाँ आप चुनते हैं कि वास्तव में कौन से एप्लिकेशन, codec, चैनल और रिसोर्स बनाने हैं। Asterisk 22 के लिए कुछ विशेष नोट्स:

- **chan_pjsip** (*Channel Drivers* के अंतर्गत) आधुनिक SIP चैनल है और डिफ़ॉल्ट रूप से सक्षम है; यह Asterisk 22 में एकमात्र SIP चैनल है।
- **codec_opus** (*Codec Translators* के अंतर्गत) एक **external** मॉड्यूल है (इसका menuselect प्रविष्टि "Download the Opus codec from Digium" पढ़ती है); इसे सक्षम करने पर `make` Sangoma/Digium से निःशुल्क, क्लोज्ड-सोर्स बाइनरी को फेच करता है। Opus pass-through के लिए किसी अतिरिक्त मॉड्यूल की आवश्यकता नहीं होती है। Sangoma का **codec_g729** मॉड्यूल भी उपलब्ध है — बाइनरी डाउनलोड करने के लिए निःशुल्क है, लेकिन वैध G.729 ट्रांसकोडिंग के लिए खरीदे गए प्रति-चैनल लाइसेंस की आवश्यकता होती है।
- *Core Sound Packages*, *Music On Hold File Packages*, और *Extras Sound Packages* मेनू में वे साउंड फॉर्मेट और भाषाएँ चुनें जिन्हें आप चाहते हैं; आप वहाँ जिसे भी चेक करते हैं, वह `make install` के दौरान स्वचालित रूप से डाउनलोड और इंस्टॉल हो जाता है।

अपना चयन करने के बाद, **Save & Exit** चुनें और `make` के साथ आगे बढ़ें।

## Asterisk को शुरू और बंद करना

इस न्यूनतम कॉन्फ़िगरेशन के साथ, Asterisk को सफलतापूर्वक शुरू करना संभव है। सीखने और डिबगिंग के लिए, आप Asterisk को कंसोल से जोड़कर फोरग्राउंड में शुरू कर सकते हैं:

```
/usr/sbin/asterisk -vvvgc
```

Asterisk को बंद करने के लिए CLI कमांड `core stop now` का उपयोग करें:

```
*CLI> core stop now
```

### systemd के साथ Asterisk को शुरू करना

आधुनिक Linux वितरणों (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9) पर, सिस्टम सर्विस मैनेजर **systemd** है। Asterisk सोर्स ट्री में `contrib/systemd/asterisk.service` पर एक systemd यूनिट प्रदान करता है; इसे `/etc/systemd/system/asterisk.service` पर कॉपी करें और `systemctl daemon-reload` चलाएं। एक बार इंस्टॉल हो जाने के बाद, प्रोडक्शन में Asterisk को चलाने का अनुशंसित तरीका `systemctl` के माध्यम से है:

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

एक बार जब Asterisk एक सर्विस के रूप में चल रहा हो, तो `asterisk -r` (कनेक्ट) या `asterisk -rvvv` (वर्बोज़ आउटपुट के साथ कनेक्ट) के साथ इसके CLI से जुड़ें।

पुराने सिस्टम पर Asterisk को लेगेसी SysV init स्क्रिप्ट (`/etc/init.d/asterisk`) और **safe_asterisk** रैपर के माध्यम से शुरू किया जाता था, जो क्रैश होने पर Asterisk को स्वचालित रूप से पुनरारंभ कर देता था। systemd के साथ, स्वचालित पुनरारंभ यूनिट फ़ाइल के `Restart=` निर्देश द्वारा नियंत्रित किया जाता है, इसलिए `safe_asterisk` की अब आमतौर पर आवश्यकता नहीं होती है। लेगेसी init/`safe_asterisk` दृष्टिकोण अभी भी काम करता है लेकिन systemd-आधारित वितरणों पर इसे पुराना (deprecated) माना जाता है।

### Asterisk रनटाइम विकल्प

Asterisk की शुरुआत की प्रक्रिया बहुत सरल है। यदि Asterisk को बिना किसी पैरामीटर के चलाया जाता है, तो इसे एक डेमन (daemon) के रूप में लॉन्च किया जाता है।

```
/sbin/asterisk
```

आप निम्नलिखित कमांड निष्पादित करके Asterisk कंसोल तक पहुँच सकते हैं। कृपया ध्यान दें कि एक ही समय में एक से अधिक कंसोल प्रक्रियाएं चलाई जा सकती हैं।

```
/sbin/asterisk -r
```

### Asterisk के लिए उपलब्ध रनटाइम विकल्प

आप `asterisk -h` का उपयोग करके उपलब्ध रनटाइम विकल्प दिखा सकते हैं

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

## इंस्टॉलेशन डायरेक्टरीज़

Asterisk कई डायरेक्टरीज़ में इंस्टॉल होता है, जिन्हें asterisk.conf फ़ाइल में बदला जा सकता है। प्रशिक्षण उद्देश्यों के लिए मैं verbose को 3 से बदलकर 15 कर दूँगा, लेकिन प्रोडक्शन के लिए इसे 3 पर ही रखें। अपने सिस्टम को ओवरलोडिंग से बचाने के लिए `maxcalls` और `maxload` विकल्प अच्छे विकल्प हैं।

### asterisk.conf (अंश)

`[directories]` सेक्शन यह परिभाषित करता है कि Asterisk अपनी कॉन्फ़िगरेशन, मॉड्यूल, डेटा, स्पूल और लॉग्स कहाँ रखता है:

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

`[options]` सेक्शन में रनटाइम ट्यूनिंग होती है। जानने के लिए सबसे उपयोगी विकल्प नीचे दिखाए गए हैं (सक्षम करने के लिए अनकमेंट करें); यह फ़ाइल कई और विकल्पों के साथ आती है, जिनमें से प्रत्येक को इनलाइन कमेंट द्वारा प्रलेखित किया गया है:

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

## लॉग फ़ाइलें और लॉग रोटेशन

Asterisk PBX अपने संदेशों को `/var/log/asterisk` में लॉग करता है। लॉगिंग को `logger.conf` द्वारा नियंत्रित किया जाता है। इसका मुख्य भाग `[logfiles]` सेक्शन है, जहाँ प्रत्येक पंक्ति एक लॉग चैनल और उसके द्वारा कैप्चर किए जाने वाले संदेश स्तरों को परिभाषित करती है (अंश):

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

संपादन के बाद, परिवर्तनों को `logger reload` के साथ लागू करें और `logger show channels` के साथ चैनलों की पुष्टि करें:

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

लॉग फ़ाइलें तेज़ी से बढ़ सकती हैं, इसलिए उन्हें सिस्टम `logrotate` डेमन के साथ रोटेट करें — `/etc/logrotate.d/` के अंतर्गत एक फ़ाइल जोड़ें:

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

logrotate के बारे में अधिक जानकारी निम्नलिखित का उपयोग करके प्राप्त की जा सकती है:

```
#man logrotate
```

## Asterisk को अनइंस्टॉल करना

Asterisk को अनइंस्टॉल करने के लिए, इसका उपयोग करें:

```
make uninstall
```

Asterisk और सभी कॉन्फ़िगरेशन फ़ाइलों को अनइंस्टॉल करने के लिए, इसका उपयोग करें:

```
make uninstall-all
```

## Asterisk इंस्टॉलेशन नोट्स

यह अनुभाग Asterisk को इंस्टॉल करने से पहले ध्यान देने योग्य मुद्दों के बारे में कुछ सलाह प्रदान करेगा।

### प्रोडक्शन सिस्टम

यदि Asterisk को प्रोडक्शन वातावरण में इंस्टॉल किया जा रहा है, तो आपको सिस्टम डिज़ाइन पर ध्यान देना चाहिए। सर्वर को इस तरह से ऑप्टिमाइज़ किया जाना चाहिए कि टेलीफोनी सिस्टम को अन्य सिस्टम प्रक्रियाओं पर प्राथमिकता मिले। Asterisk को X-Windows जैसे प्रोसेसर-गहन सॉफ़्टवेयर के साथ नहीं चलना चाहिए। यदि आपको CPU-गहन प्रक्रियाओं (जैसे, एक बड़ा डेटाबेस) को चलाने की आवश्यकता है, तो एक अलग सर्वर का उपयोग करें। सामान्य तौर पर, Asterisk हार्डवेयर प्रदर्शन विविधताओं के प्रति संवेदनशील है। इसलिए, Asterisk का उपयोग ऐसे हार्डवेयर वातावरण में करने का प्रयास करें जिसे 40% से अधिक CPU उपयोग की आवश्यकता न हो।

### नेटवर्क टिप्स

यदि आप IP phones का उपयोग करने की योजना बना रहे हैं, तो यह महत्वपूर्ण है कि आप अपने नेटवर्क पर ध्यान दें। वॉइस प्रोटोकॉल बहुत अच्छे होते हैं और लेटेंसी (latency) और यहां तक कि जिटर (jitters) के प्रति प्रतिरोधी होते हैं; हालाँकि, यदि आप खराब तरीके से कॉन्फ़िगर किए गए लोकल एरिया नेटवर्क का उपयोग करते हैं, तो वॉइस क्वालिटी प्रभावित होगी। स्विच और राउटर में क्वालिटी ऑफ सर्विस (QoS) का उपयोग करके ही अच्छी वॉइस क्वालिटी की गारंटी देना संभव है। लोकल एरिया नेटवर्क में वॉइस आमतौर पर अच्छी होती है, लेकिन LAN वातावरण में भी, यदि आपके पास बहुत अधिक कोलिजन (collisions) वाले 10 Mbps हब हैं, तो अंततः आपको विकृत या खराब वॉइस मिलेगी। सर्वोत्तम संभव वॉइस क्वालिटी सुनिश्चित करने के लिए इन सिफारिशों का पालन करें:

- यदि संभव हो या आर्थिक रूप से व्यवहार्य हो तो एंड-टू-एंड QoS का उपयोग करें। एंड-टू-एंड QoS के साथ, वॉइस क्वालिटी एकदम सही होती है। कोई बहाना नहीं!
- प्रोडक्शन वातावरण में वॉइस के लिए 10/100 Mbps हब का उपयोग करने से बचें। कोलिजन नेटवर्क पर जिटर डाल सकते हैं। फुल डुप्लेक्स 10/100 Mbps को प्राथमिकता दी जाती है क्योंकि इसमें कोई कोलिजन नहीं होता है।
- वॉइस नेटवर्क के अनावश्यक ब्रॉडकास्ट को अलग करने के लिए VLANs का उपयोग करें। आप नहीं चाहेंगे कि कोई वायरस ARP ब्रॉडकास्ट के साथ आपके वॉइस नेटवर्क को नष्ट कर दे।
- उपयोगकर्ताओं को वॉइस नेटवर्क में अपेक्षाओं के बारे में शिक्षित करें। QoS के बिना, यह न कहें कि वॉइस एकदम सही होगी क्योंकि अधिकांश मामलों में ऐसा नहीं होगा। मोबाइल फोन के समान वॉइस क्वालिटी अक्सर प्राप्त की जा सकेगी। गुणवत्तापूर्ण फोन का उपयोग करें क्योंकि फर्मवेयर और हार्डवेयर डिज़ाइन के साथ समस्याएं आम हैं।

## सारांश

इस अध्याय में, आपने Asterisk के लिए न्यूनतम हार्डवेयर आवश्यकताओं के साथ-साथ इसे डाउनलोड, इंस्टॉल और कंपाइल करने के तरीके के बारे में सीखा है। सुरक्षा कारणों से Asterisk को नॉन-रूट उपयोगकर्ता के साथ निष्पादित किया जाना चाहिए। प्रोडक्शन वातावरण शुरू करने से पहले आपको अपने नेटवर्क वातावरण की जांच कर लेनी चाहिए।

## प्रश्नोत्तरी

1. Asterisk 22 में, कौन सा चैनल ड्राइवर SIP सपोर्ट प्रदान करता है, और पुराने `chan_sip` का क्या हुआ?
   - A. `chan_sip` अभी भी डिफ़ॉल्ट है; `chan_pjsip` वैकल्पिक है।
   - B. `chan_pjsip` डिफ़ॉल्ट SIP चैनल है; `chan_sip` को Asterisk 21 में हटा दिया गया था और अब यह मौजूद नहीं है।
   - C. दोनों डिफ़ॉल्ट रूप से बिल्ड होते हैं और आप रनटाइम पर उनके बीच चयन करते हैं।
   - D. IAX2 के पक्ष में SIP सपोर्ट को पूरी तरह से हटा दिया गया था।
2. Asterisk के लिए टेलीफोनी इंटरफ़ेस कार्ड में आमतौर पर डिजिटल सिग्नल प्रोसेसर (DSPs) इन-बिल्ट होते हैं और इसलिए उन्हें PC से अधिक CPU की आवश्यकता नहीं होती है।
   - A. सत्य
   - B. असत्य
3. यदि आप उत्तम वॉयस क्वालिटी चाहते हैं, तो आपको एंड-टू-एंड क्वालिटी ऑफ सर्विस (QoS) लागू करने की आवश्यकता है।
   - A. सत्य
   - B. असत्य
4. आपको हमेशा नवीनतम Asterisk संस्करण चुनना चाहिए, क्योंकि यह सबसे स्थिर होता है।
   - A. सत्य
   - B. असत्य
5. Asterisk 22 के लिए बिल्ड डिपेंडेंसी इंस्टॉल करने का अनुशंसित तरीका क्या है?
6. यदि आपके पास TDM इंटरफ़ेस कार्ड नहीं है, तो भी आपके पास सिंक्रोनाइज़ेशन के लिए एक आंतरिक टाइमिंग स्रोत होगा, जो Linux पर `res_timing_timerfd` मॉड्यूल द्वारा प्रदान किया जाता है। इस टाइमिंग का उपयोग ________ और ________ जैसे एप्लिकेशन द्वारा किया जाता है।
7. Asterisk इंस्टॉल करते समय GNOME या KDE जैसे डेस्कटॉप वातावरण को छोड़ देना बेहतर होता है, क्योंकि ग्राफिकल इंटरफेस CPU चक्रों की खपत करते हैं।
   - A. सत्य
   - B. असत्य
8. Asterisk कॉन्फ़िगरेशन फाइलें ________ डायरेक्टरी में स्थित होती हैं।
9. Asterisk सैंपल कॉन्फ़िगरेशन फाइलें इंस्टॉल करने के लिए, यह कमांड टाइप करें: ________
10. Asterisk को नॉन-रूट यूजर के रूप में चलाना क्यों महत्वपूर्ण है?

**उत्तर:** 1 — B · 2 — B · 3 — A · 4 — B · 5 — एक्सट्रैक्ट किए गए Asterisk सोर्स ट्री से `./contrib/scripts/install_prereq install` चलाएं · 6 — ConfBridge और Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — सुरक्षा (यदि Asterisk से समझौता किया जाता है तो नुकसान को सीमित करता है)
