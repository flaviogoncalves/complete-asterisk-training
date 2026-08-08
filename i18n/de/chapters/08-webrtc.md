# WebRTC mit Asterisk

WebRTC (Web Real-Time Communication) ermöglicht es einem Webbrowser, Anrufe ohne Plugins und ohne externes softphone zu tätigen und zu empfangen — alles, was benötigt wird, sind JavaScript, ein Mikrofon und eine sichere Verbindung zu Asterisk. Asterisk kann seit Asterisk 11 als WebRTC-Server fungieren, und seit die PJSIP-Stack (`res_pjsip`) in Asterisk 12 eingeführt wurde, ist dies der empfohlene Weg; in Asterisk 22 hat sich die Konfiguration auf eine Handvoll gut verständlicher Optionen eingependelt. Dieses Kapitel zeigt, wie man einen PJSIP-endpoint in ein Browser-Telefon verwandelt, wie der sichere Medienpfad funktioniert und wann Sie auf die integrierte WebRTC-Unterstützung von Asterisk zurückgreifen sollten anstatt auf ein dediziertes Gateway.

Alles in diesem Kapitel wurde mit der Asterisk 22-Laborumgebung des Buches verifiziert; die gezeigte Konfiguration ist dieselbe wie in `lab/asterisk/etc`.

## Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Zu erklären, was WebRTC zu Asterisk hinzufügt und wann es eingesetzt werden sollte
- Zu beschreiben, wie sich WebRTC-Mediensicherheit (DTLS-SRTP) und ICE von einfachem SIP unterscheiden
- Den Asterisk HTTP-Server und den sicheren WebSocket (`wss`) endpoint zu aktivieren
- Einen `wss` PJSIP transport und einen WebRTC endpoint mit `webrtc=yes` zu konfigurieren
- Ein Browser-softphone (SIP.js) zu verbinden und einen Anruf zu tätigen
- Zwischen nativem Asterisk WebRTC und einem Media Gateway wie Janus zu entscheiden

## Warum WebRTC mit Asterisk

Ein WebRTC endpoint ist aus Sicht von Asterisk lediglich ein weiterer PJSIP endpoint. Was sich ändert, ist *wie* der Browser ihn erreicht und wie die Medienübertragung gesichert wird. Typische Anwendungsfälle sind:

- **Click-to-call** auf einer Website — ein Besucher ruft eine Warteschlange oder eine extension von einer Webseite aus an.
- **Webbasierte Agenten** — ein Mitarbeiter im Contact-Center arbeitet vollständig im Browser, ohne dass ein Desktop-softphone installiert oder aktualisiert werden muss.
- **Eingebettete Telefonie** in Ihrer eigenen Webanwendung — zum Beispiel das SipPulse Web-softphone, das mit Asterisk kommuniziert.
- **Installationsfreie interne Telefone** — Mitarbeiter verwenden einen Browser-Tab anstelle eines Hardware-Telefons oder eines installierten Clients.

Der große Vorteil ist die Reichweite: Jeder moderne Browser beherrscht bereits WebRTC. Der Preis dafür ist, dass WebRTC streng ist — es *erfordert* verschlüsselte Medien und einen sicheren Transport, daher gibt es mehr zu konfigurieren als bei einem einfachen UDP SIP-Telefon.

## Wie sich WebRTC von einfachem SIP unterscheidet

Ein reguläres SIP-Telefon signalisiert über UDP/TCP und überträgt Audio normalerweise als einfaches RTP. Ein WebRTC-Browser-Client unterscheidet sich in drei wichtigen Punkten, und Asterisk muss jeden davon berücksichtigen:

- **Die Signalisierung erfolgt über ein WebSocket.** Anstelle von SIP über den UDP-Port 5060 öffnet der Browser ein sicheres WebSocket (`wss://`) zum integrierten HTTP-Server von Asterisk. SIP-Nachrichten werden innerhalb dieses WebSockets übertragen.
- **Medien werden immer mit DTLS-SRTP verschlüsselt.** Browser lehnen einfaches RTP ab. Die beiden Seiten führen einen DTLS-Handshake durch (authentifiziert durch Zertifikats-Fingerabdrücke, die im SDP ausgetauscht werden) und leiten daraus SRTP-Schlüssel ab.
- **Die Konnektivität wird mit ICE ausgehandelt.** Anstatt von einer erreichbaren IP und einem Port auszugehen, sammeln beide Seiten Kandidatenadressen (Host, STUN-reflexiv, TURN-relayed) und prüfen diese, bis eine funktioniert. RTP und RTCP werden normalerweise auf einem einzigen Port gemultiplext (`rtcp_mux`).

Die gute Nachricht: In Asterisk 22 aktiviert eine einzige endpoint-Option, `webrtc=yes`, all dies mit sinnvollen Standardeinstellungen. Wir werden genau sehen, was diese Option bewirkt.

## Schritt 1 — der HTTP-Server und der WebSocket

Die WebRTC-Signalisierung wird über den in Asterisk integrierten HTTP-Server bereitgestellt (`res_http_websocket` stellt den Pfad `/ws` darauf bereit). Browser erfordern einen *sicheren* WebSocket, daher aktivieren wir TLS. Bearbeiten Sie `http.conf`:

```
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088

; TLS / WSS for WebRTC. Browsers require a secure WebSocket (wss://).
tlsenable=yes
tlsbindaddr=0.0.0.0:8089
tlscertfile=/etc/asterisk/keys/asterisk.crt
tlsprivatekey=/etc/asterisk/keys/asterisk.key
```

Führen Sie einen Reload durch (`module reload res_http_websocket` oder einen Neustart) und überprüfen Sie dies:

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

Der Browser wird sich mit `wss://your-asterisk:8089/ws` verbinden.

### Über das Zertifikat

Das TLS-Zertifikat sichert hier den *WebSocket* (den Signalisierungskanal). In einer Testumgebung ist ein selbstsigniertes Zertifikat in Ordnung — Sie akzeptieren es einmalig im Browser. Verwenden Sie in einer Produktionsumgebung ein echtes Zertifikat (zum Beispiel von Let's Encrypt), dessen Name mit dem Host übereinstimmt, mit dem sich der Browser verbindet, da der Browser den WebSocket andernfalls ablehnen wird.

Für die Testumgebung generiert `lab/make-certs.sh` ein selbstsigniertes Zertifikat mit `CN=localhost` (plus `localhost`/`127.0.0.1` SANs) und schreibt es nach `asterisk/etc/keys/`. Für einen öffentlichen Einsatz beschaffen Sie stattdessen ein echtes Zertifikat — zum Beispiel mit Let's Encrypt:

```
certbot certonly --standalone -d voip.example.com
```

Verweisen Sie dann mit `http.conf` auf die ausgestellten Dateien und laden Sie `res_http_websocket` neu:

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

Stellen Sie sicher, dass der Zertifikatsname mit dem Host übereinstimmt, mit dem sich der Browser verbindet, und erneuern Sie es (der Timer von certbot erledigt dies automatisch), bevor es abläuft, da der WebSocket sonst fehlschlägt.

Dieses Zertifikat ist **nicht** dasselbe wie das DTLS-Zertifikat, das zur Verschlüsselung der Medien verwendet wird — Asterisk generiert dieses automatisch, wie wir sehen werden.

## Schritt 2 — der WSS-Transport

PJSIP benötigt einen Transport vom Typ `wss`. Fügen Sie diesen zu `pjsip.conf` hinzu:

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

Überprüfen Sie, ob er geladen wurde:

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

Lassen Sie sich nicht von dem `0.0.0.0:5060` täuschen, das für den `wss` Transport angezeigt wird — der WebSocket wird **nicht** auf Port 5060 bereitgestellt. Die WebRTC-Signalisierung wird von dem HTTP-Server bereitgestellt, den Sie in Schritt 1 konfiguriert haben (Port 8089 für `wss`). Der PJSIP `wss` Transport ist lediglich eine dünne Schicht über `res_http_websocket`, daher ist die für ihn angezeigte `bind` Adresse rein kosmetischer Natur und kann ignoriert werden; der entscheidende Port ist `tlsbindaddr` in `http.conf`.

## Schritt 3 — das WebRTC-endpoint

Nun zum endpoint selbst. Der Schlüssel ist `webrtc=yes`:

```
[webrtc-1000]
type=endpoint
context=internal
disallow=all
allow=opus,ulaw
webrtc=yes
transport=transport-wss
aors=webrtc-1000
auth=webrtc-1000

[webrtc-1000]
type=auth
auth_type=digest
username=webrtc-1000
password=Lab-webrtc-secret

[webrtc-1000]
type=aor
max_contacts=1
```

`webrtc=yes` ist eine praktische Einstellung. Sie entspricht dem manuellen Setzen aller für WebRTC erforderlichen Optionen. Sie können genau überprüfen, was dadurch aktiviert wurde:

```
*CLI> pjsip show endpoint webrtc-1000
 dtls_auto_generate_cert            : Yes
 dtls_fingerprint                   : SHA-256
 dtls_setup                         : actpass
 ice_support                        : true
 media_encryption                   : dtls
 rtcp_mux                           : true
 use_avpf                           : true
 webrtc                             : yes
```

Beim Lesen dieser Ausgabe:

- `media_encryption: dtls` und `dtls_auto_generate_cert: Yes` — Medien sind DTLS-SRTP, und Asterisk generiert das DTLS-Zertifikat automatisch, sodass Sie selbst **keines** erstellen müssen. Der Fingerabdruck wird im SDP (`SHA-256`) bekannt gegeben.
- `ice_support: true` — Asterisk sammelt und verhandelt ICE-Kandidaten.
- `rtcp_mux: true` — RTP und RTCP teilen sich einen Port, wie es von Browsern erwartet wird.
- `use_avpf: true` — das AVPF RTP-Profil (Feedback), das für WebRTC erforderlich ist.

`allow=opus` wird empfohlen — Opus ist der codec, den Browser bevorzugen. Asterisk 22 liefert Opus *passthrough* im Kern aus (das `res_format_attr_opus` Modul), was ausreicht, um Opus zwischen zwei Opus-fähigen Verbindungen ohne Neukodierung weiterzuleiten. Das *Transcoding* von Opus in einen anderen codec erfordert das separate `codec_opus` Modul, das im offiziellen WebRTC-Leitfaden als optional, aber sehr empfehlenswert aufgeführt ist und das Sie zusätzlich zur Basisinstallation installieren; siehe die Diskussion über codecs in *Designing a VoIP network*. Behalten Sie `ulaw` als Fallback für die Überbrückung zu Nicht-WebRTC-Verbindungen bei, die kein Opus sprechen können.

## Schritt 4 — ICE, STUN und TURN

In einem flachen LAN reicht ICE mit Host-Kandidaten aus und es wird nichts weiter benötigt. Über das Internet fügen Sie normalerweise einen STUN-Server hinzu, damit Asterisk und der Browser ihre öffentlichen Adressen ermitteln können, sowie einen TURN-Server für Fälle, in denen direkte Medienübertragung unmöglich ist (symmetrisches NAT, restriktive Firewalls). Verweisen Sie in `rtp.conf` wie folgt auf diese:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

Der Browser wird mit seinen eigenen ICE-Servern in JavaScript konfiguriert (die `RTCPeerConnection` `iceServers` Liste). Für eine rein interne Bereitstellung können Sie STUN/TURN komplett überspringen.

`turnaddr` akzeptiert einen optionalen Port (Standard `3478`); `turnusername` und `turnpassword` authentifizieren sich gegenüber dem Relay. STUN hilft einem Peer lediglich dabei, seine öffentliche Adresse zu *entdecken* — wenn beide Endpunkte hinter einem symmetrischen NAT oder einer restriktiven Firewall sitzen, ist eine direkte Medienübertragung unmöglich und ein TURN-Relay ist die einzige Möglichkeit, den Audiofluss zu ermöglichen.

**Produktionsempfehlung:** Ein öffentlicher STUN-Server (wie der von Google) ist für die Adressermittlung in Ordnung, aber verlassen Sie sich für echten Datenverkehr **nicht** auf öffentliche TURN-Server — TURN leitet Ihre gesamten Medien weiter, daher sollten Sie die Kontrolle darüber behalten. Betreiben Sie Ihren eigenen [coturn](https://github.com/coturn/coturn) Server. Eine minimale `/etc/turnserver.conf` mit Langzeit-Anmeldedaten sieht wie folgt aus:

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

Verweisen Sie dann in `rtp.conf` auf diesen:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

Geben Sie dem Browser denselben TURN-Server in seiner `iceServers` Liste, damit beide Seiten das Relay nutzen können. Für den produktiven Einsatz mit Benutzern in Mobilfunknetzen oder hinter Firmen-Firewalls ist ein selbst gehosteter coturn praktisch zwingend erforderlich.

## Schritt 5 — der Browser-Client

Jede WebRTC SIP-Bibliothek funktioniert; zwei weit verbreitete sind **SIP.js** und **JsSIP**. Das Labor enthält ein minimales SIP.js-softphone unter `lab/webrtc/index.html`. Der wesentliche Teil ist die Transport-URL und die Anmeldedaten:

```javascript
const ua = new SIP.UserAgent({
  uri: SIP.UserAgent.makeURI('sip:webrtc-1000@your-asterisk'),
  transportOptions: { server: 'wss://your-asterisk:8089/ws' },
  authorizationUsername: 'webrtc-1000',
  authorizationPassword: 'Lab-webrtc-secret',
});
await ua.start();
await new SIP.Registerer(ua).register();
// place a call to the echo test
const inviter = new SIP.Inviter(ua, SIP.UserAgent.makeURI('sip:600@your-asterisk'));
await inviter.invite();
```

Zwei Realitäten im Browser sind zu beachten:

- **Sicherer Kontext.** `getUserMedia` (Mikrofonzugriff) funktioniert nur auf `https://`
  Seiten oder `http://localhost`. Stellen Sie die Seite in der Produktion über HTTPS bereit.
- **Zertifikat einmalig akzeptieren.** Besuchen Sie bei einem selbstsignierten Labor-Zertifikat zuerst `https://your-asterisk:8089/ws` im selben Browser und akzeptieren Sie die Warnung, da der WebSocket sonst stillschweigend fehlschlägt.

Das SipPulse Web-softphone ist ein produktionsreifer Referenz-Client, der auf denselben Primitiven basiert.

## Überprüfung eines WebRTC-Anrufs

Nachdem der Browser registriert ist, zeigt `pjsip show contacts` den dynamischen Kontakt an, und ein Anruf aktiviert den Kanal:

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

Wenn die Audioübertragung nur in eine Richtung erfolgt oder ganz fehlt, liegt dies fast immer an ICE oder dem Zertifikat – siehe Fehlerbehebung weiter unten.

## Asterisk WebRTC vs. ein Media Gateway

Asterisk kann WebRTC direkt terminieren, ist aber nicht immer das richtige Werkzeug dafür:

- **Verwenden Sie natives Asterisk-WebRTC**, wenn der Browser ein *Telefon* an Ihrer PBX ist — ein Agent, eine interne extension, ein Click-to-Call, das in Ihrem dialplan landet. Der Browser ist einfach ein weiterer endpoint und alles (Warteschlangen, voicemail, IVR) funktioniert.
- **Verwenden Sie ein dediziertes Gateway (z. B. Janus)**, wenn Sie viele Browser-Sitzungen unabhängig von der Anrufsteuerung skalieren müssen, selektive Weiterleitungen für große Konferenzen/Streaming benötigen oder die Medienebene von der PBX getrennt halten möchten. Ein Gateway überbrückt WebRTC zu einfachem SIP, und Asterisk sieht dann einen gewöhnlichen SIP-Zweig.

Viele reale Systeme kombinieren beides: Asterisk für die Anrufsteuerung, ein Gateway für die Skalierung der Medien auf Browserseite. (Dies ist die Architektur hinter dem eigenen Stack von SipPulse.)

## Fehlerbehebung

- **WebSocket stellt keine Verbindung her:** Der Browser hat das TLS-Zertifikat abgelehnt. Öffnen Sie `https://host:8089/ws` direkt und akzeptieren Sie es, oder installieren Sie ein vertrauenswürdiges Zertifikat.
- **Registrierung erfolgreich, aber kein Ton:** ICE ist fehlgeschlagen — fügen Sie STUN hinzu, und bei NAT-Überschreitung auch TURN. Überprüfen Sie `pjsip set logger on` und betrachten Sie die SDP-Kandidaten.
- **Einseitige Audioübertragung:** Normalerweise liegt ein NAT/ICE-Problem auf einer Seite vor oder es gibt keinen passenden codec — stellen Sie sicher, dass `allow=opus,ulaw` korrekt konfiguriert ist.
- **Anrufabbruch bei Annahme:** DTLS-Handshake fehlgeschlagen; bestätigen Sie, dass `dtls_auto_generate_cert` auf `Yes` gesetzt ist und die Systemzeit korrekt ist (Zertifikate sind zeitkritisch).

## Labor

1. Führen Sie `./lab.sh up` aus, dann `bash lab/make-certs.sh` und starten Sie Asterisk neu.
2. Stellen Sie `lab/webrtc/index.html` bereit (`python3 -m http.server` von `lab/webrtc`) und öffnen Sie
   es; akzeptieren Sie das Zertifikat unter `https://localhost:8089/ws`.
3. Registrieren Sie sich als `webrtc-1000` und rufen Sie `600` (Echo-Test) an — Sie sollten sich selbst hören.
4. Wählen Sie vom SipPulse Softphone, das als `6001` registriert ist, die `1000`, um den Browser klingeln zu lassen.
5. Untersuchen Sie die Aushandlung: `pjsip set logger on`, führen Sie einen Anruf durch und finden Sie den DTLS
   Fingerprint sowie die ICE-Kandidaten im SDP.

## Zusammenfassung

WebRTC macht einen Browser zu einem vollwertigen Asterisk endpoint. Das Rezept ist kurz, aber strikt: Aktivieren Sie den HTTP-Server mit TLS, damit der Browser ein sicheres WebSocket öffnen kann, fügen Sie einen `wss` PJSIP transport hinzu und setzen Sie `webrtc=yes` auf dem endpoint — dies schaltet DTLS-SRTP (mit einem automatisch generierten Zertifikat), ICE, RTP/RTCP-Multiplexing und das AVPF-Profil ein. Fügen Sie STUN/TURN hinzu, wenn Sie NAT durchqueren, stellen Sie Ihre Seite über HTTPS bereit und verweisen Sie einen SIP.js (oder JsSIP) Client auf `wss://asterisk:8089/ws`. Für Browser-Telefone an Ihrer PBX ist das Asterisk-native WebRTC der einfachste Weg; für groß angelegte Medienanwendungen koppeln Sie es mit einem Gateway.

## Quiz

1. Welches Transportprotokoll verwendet ein WebRTC-Browser-Client, um SIP-Signalisierung an Asterisk zu übertragen?
   - A. Unverschlüsseltes UDP auf Port 5060
   - B. Ein sicheres WebSocket (`wss://`) zum HTTP-Server von Asterisk
   - C. TLS auf Port 5061
   - D. Ein roher TCP-Socket auf Port 8088

2. Über welchen Mechanismus werden WebRTC-Medien zwischen dem Browser und Asterisk verschlüsselt?
   - A. SDES-SRTP (Schlüsselaustausch im SDP)
   - B. DTLS-SRTP (Schlüssel werden aus einem DTLS-Handshake abgeleitet)
   - C. IPsec
   - D. Unverschlüsseltes RTP — WebRTC verschlüsselt Medien nicht

3. Wahr oder falsch: Wenn Sie `webrtc=yes` einstellen, müssen Sie das für die Medienverschlüsselung verwendete DTLS-Zertifikat manuell generieren und installieren.

4. Auf welchem Port stellt der Asterisk HTTP-Server des Labs das **sichere** WebSocket für WebRTC bereit?
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. Welche der folgenden Optionen aktiviert `webrtc=yes` standardmäßig? (Wählen Sie alle zutreffenden aus.)
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. Füllen Sie die Lücke aus: WebRTC handelt die Konnektivität aus, indem beide Seiten Kandidaten-Adressen (Host, STUN-reflexiv, TURN-relayed) sammeln und prüfen, wobei das ________ Framework verwendet wird.

7. Welche zwei Einstellungen in `rtp.conf` verweisen Asterisk auf einen externen Server, damit dieser seine öffentliche Adresse ermitteln und Medien weiterleiten kann, wenn direkte Pfade fehlschlagen? (Wählen Sie alle zutreffenden aus.)
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. Der URL-Pfad, den `res_http_websocket` von Asterisk für WebRTC-Signalisierung bereitstellt, ist ________.

9. Wann sollten Sie laut diesem Kapitel auf ein dediziertes Media-Gateway (wie Janus) anstelle der nativen WebRTC-Funktionen von Asterisk zurückgreifen?
   - A. Immer dann, wenn ein Browser einen Anruf tätigen muss
   - B. Wenn Sie viele Browser-Mediensitzungen unabhängig von der Anrufsteuerung skalieren, selektives Forwarding für große Konferenzen durchführen oder die Medienebene von der PBX trennen müssen
   - C. Nur wenn der Browser kein DTLS unterstützt
   - D. Wenn Sie möchten, dass voicemail und IVR für den Browser-endpoint funktionieren

10. Wahr oder falsch: `getUserMedia` (Mikrofonzugriff) funktioniert auf jeder `http://` Seite, daher ist die Bereitstellung des Browser-softphone über HTTPS optional.

**Antworten:** 1 — B · 2 — B · 3 — Falsch (Asterisk generiert das DTLS-Zertifikat automatisch; `dtls_auto_generate_cert: Yes`) · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — Falsch (sicherer Kontext erforderlich: `getUserMedia` funktioniert nur auf `https://` oder `http://localhost`)
