# WebRTC con Asterisk

WebRTC (Web Real-Time Communication) consente a un browser web di effettuare e ricevere chiamate senza plugin e senza alcun softphone esterno: bastano JavaScript, un microfono e una connessione sicura verso Asterisk. Asterisk è in grado di agire come server WebRTC fin dalla versione Asterisk 11 e, dall'introduzione dello stack PJSIP (`res_pjsip`) in Asterisk 12, questo è diventato il metodo consigliato; in Asterisk 22 la configurazione si è consolidata in una manciata di opzioni ben definite. Questo capitolo mostra come trasformare un endpoint PJSIP in un telefono basato su browser, come funziona il percorso multimediale sicuro e quando è opportuno ricorrere al supporto WebRTC integrato di Asterisk rispetto a un gateway dedicato.

Tutto ciò che è contenuto in questo capitolo è stato verificato con il laboratorio Asterisk 22 del libro; la configurazione mostrata è la stessa presente in `lab/asterisk/etc`.

## Obiettivi

Al termine di questo capitolo, sarai in grado di:

- Spiegare cosa aggiunge WebRTC ad Asterisk e quando utilizzarlo
- Descrivere in che modo la sicurezza dei media WebRTC (DTLS-SRTP) e ICE differiscono dal SIP standard
- Abilitare il server HTTP di Asterisk e l'endpoint WebSocket sicuro (`wss`)
- Configurare un trasporto PJSIP `wss` e un endpoint WebRTC con `webrtc=yes`
- Connettere un softphone basato su browser (SIP.js) ed effettuare una chiamata
- Decidere tra l'implementazione WebRTC nativa di Asterisk e un media gateway come Janus

## Perché WebRTC con Asterisk

Un endpoint WebRTC è, dal punto di vista di Asterisk, semplicemente un altro endpoint PJSIP. Ciò che cambia è *come* il browser lo raggiunge e come viene protetto il media. Gli utilizzi tipici includono:

- **Click-to-call** su un sito web — un visitatore chiama una coda o una extension da una pagina web.
- **Agenti basati sul web** — un agente di un contact-center lavora interamente nel browser, senza softphone desktop da installare o aggiornare.
- **Chiamate integrate** nella propria applicazione web — ad esempio, il softphone web SipPulse che comunica con Asterisk.
- **Telefoni interni senza installazione** — il personale utilizza una scheda del browser invece di un telefono hardware o di un client installato.

Il grande vantaggio è la portata: ogni browser moderno parla già WebRTC. Il costo è che WebRTC è rigoroso — *richiede* media crittografati e un trasporto sicuro, quindi c'è più da configurare rispetto a un semplice telefono SIP UDP.

## In che modo WebRTC differisce dal SIP standard

Un telefono SIP tradizionale comunica tramite UDP/TCP e solitamente trasporta l'audio come RTP semplice. Un client browser WebRTC è diverso per tre aspetti importanti, e Asterisk deve gestire ciascuno di essi:

- **La segnalazione viaggia su un WebSocket.** Invece del SIP su porta UDP 5060, il browser apre un WebSocket sicuro (`wss://`) verso il server HTTP integrato di Asterisk. I messaggi SIP viaggiano all'interno di tale WebSocket.
- **I media sono sempre crittografati con DTLS-SRTP.** I browser rifiutano l'RTP semplice. Le due parti eseguono un handshake DTLS (autenticato tramite impronte digitali dei certificati scambiate nell'SDP) e ne derivano le chiavi SRTP.
- **La connettività viene negoziata con ICE.** Invece di presupporre un IP e una porta raggiungibili, entrambe le parti raccolgono indirizzi candidati (host, STUN-reflexive, TURN-relayed) e li testano finché uno non funziona. RTP e RTCP sono solitamente multiplexati su una singola porta (`rtcp_mux`).

La buona notizia: in Asterisk 22 una singola opzione di endpoint, `webrtc=yes`, attiva tutto questo con impostazioni predefinite sensate. Vedremo esattamente cosa configura.

## Step 1 — il server HTTP e il WebSocket

La segnalazione WebRTC è gestita dal server HTTP integrato di Asterisk (`res_http_websocket` espone il percorso `/ws` su di esso). I browser richiedono un WebSocket *sicuro*, quindi abilitiamo TLS. Modifica `http.conf`:

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

Ricarica (`module reload res_http_websocket` o riavvia) e conferma:

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

Il browser si connetterà a `wss://your-asterisk:8089/ws`.

### Informazioni sul certificato

Il certificato TLS qui protegge il *WebSocket* (il canale di segnalazione). In un laboratorio, un certificato autofirmato va bene: lo si accetta una volta nel browser. In produzione, utilizza un certificato reale (ad esempio Let's Encrypt) il cui nome corrisponda all'host a cui si connette il browser, altrimenti il browser rifiuterà il WebSocket.

Per il laboratorio, `lab/make-certs.sh` genera un certificato autofirmato con `CN=localhost` (più i SAN `localhost`/`127.0.0.1`) e lo scrive in `asterisk/etc/keys/`. Per una distribuzione pubblica, ottieni invece un certificato reale, ad esempio con Let's Encrypt:

```
certbot certonly --standalone -d voip.example.com
```

Quindi punta `http.conf` ai file emessi e ricarica `res_http_websocket`:

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

Assicurati che il nome del certificato corrisponda all'host a cui si connette il browser e rinnovalo (il timer di certbot lo fa automaticamente) prima che scada, altrimenti il WebSocket fallirà.

Questo certificato **non** è lo stesso del certificato DTLS utilizzato per crittografare i media: Asterisk genera quello automaticamente, come vedremo.

## Passaggio 2 — il trasporto WSS

PJSIP necessita di un trasporto di tipo `wss`. Aggiungilo a `pjsip.conf`:

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

Verifica che sia stato caricato:

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

Non lasciarti ingannare dal `0.0.0.0:5060` mostrato per il trasporto `wss` — il WebSocket
**non** viene servito sulla porta 5060. La segnalazione WebRTC viene gestita dal server HTTP che
hai configurato nel Passaggio 1 (porta 8089 per `wss`). Il trasporto PJSIP `wss` è un sottile strato
sopra `res_http_websocket`, quindi l'indirizzo `bind` stampato per esso è puramente estetico e può essere
ignorato; la porta che conta è `tlsbindaddr` in `http.conf`.

## Passaggio 3 — l'endpoint WebRTC

Ora l'endpoint vero e proprio. La chiave è `webrtc=yes`:

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

`webrtc=yes` è un'opzione di comodità. È equivalente all'impostazione manuale di tutte le opzioni richieste da WebRTC. Puoi verificare esattamente cosa ha attivato:

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

Leggendo quell'output:

- `media_encryption: dtls` e `dtls_auto_generate_cert: Yes` — il media è DTLS-SRTP, e Asterisk genera automaticamente il certificato DTLS, quindi **non** devi crearne uno tu stesso. L'impronta digitale (fingerprint) viene pubblicizzata nell'SDP (`SHA-256`).
- `ice_support: true` — Asterisk raccoglie e negozia i candidati ICE.
- `rtcp_mux: true` — RTP e RTCP condividono una porta, come previsto dai browser.
- `use_avpf: true` — il profilo RTP AVPF (feedback), richiesto da WebRTC.

`allow=opus` è raccomandato — Opus è il codec preferito dai browser. Asterisk 22 fornisce il *passthrough* di Opus nel core (il modulo `res_format_attr_opus`), che è sufficiente per inoltrare Opus tra due segmenti in grado di gestire Opus senza ricodifica. La *transcodifica* di Opus verso un altro codec richiede il modulo separato `codec_opus`, che la guida ufficiale WebRTC elenca come opzionale ma altamente raccomandato e che si installa sopra la build di base; vedi la discussione sui codec in *Designing a VoIP network*. Mantieni `ulaw` come fallback per il bridging verso segmenti non WebRTC che non supportano Opus.

## Step 4 — ICE, STUN e TURN

Su una LAN piatta, ICE con host candidate è sufficiente e non serve altro. Attraverso internet di solito si aggiunge un server STUN in modo che Asterisk e il browser possano scoprire i propri indirizzi pubblici, e un server TURN per i casi in cui il media diretto è impossibile (NAT simmetrico, firewall restrittivi). Punta Asterisk verso di essi in `rtp.conf`:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

Il browser viene configurato con i propri server ICE in JavaScript (la lista `RTCPeerConnection` `iceServers`). Per un'implementazione puramente interna è possibile ignorare completamente STUN/TURN.

`turnaddr` accetta una porta opzionale (predefinita `3478`); `turnusername` e `turnpassword` autenticano verso il relay. STUN aiuta solo un peer a *scoprire* il proprio indirizzo pubblico: quando entrambe le estremità si trovano dietro un NAT simmetrico o un firewall restrittivo, il media diretto è impossibile e un relay TURN è l'unica cosa che permette al flusso audio di passare.

**Raccomandazione per la produzione:** un server STUN pubblico (come quello di Google) va bene per la scoperta degli indirizzi, ma **non** fare affidamento su un TURN pubblico per il traffico reale: TURN inoltra tutto il tuo media, quindi vuoi che sia sotto il tuo controllo. Esegui il tuo server [coturn](https://github.com/coturn/coturn). Un `/etc/turnserver.conf` minimale con credenziali a lungo termine appare così:

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

Quindi punta Asterisk verso di esso in `rtp.conf`:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

Fornisci al browser lo stesso server TURN nella sua lista `iceServers` in modo che entrambi i rami possano fare relay. Per la produzione con utenti su reti mobili o dietro firewall aziendali, un coturn auto-ospitato è praticamente obbligatorio.

## Passaggio 5 — il client browser

Qualsiasi libreria SIP WebRTC funziona; due tra le più utilizzate sono **SIP.js** e **JsSIP**. Il laboratorio include un softphone SIP.js minimale in `lab/webrtc/index.html`. La parte essenziale è l'URL di trasporto e le credenziali:

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

Due realtà del browser da ricordare:

- **Contesto sicuro.** `getUserMedia` (accesso al microfono) funziona solo su pagine `https://` o `http://localhost`. In produzione, servire la pagina tramite HTTPS.
- **Accettare il certificato una volta.** Con un certificato di laboratorio autofirmato, visitare prima `https://your-asterisk:8089/ws` nello stesso browser e accettare l'avviso, altrimenti il WebSocket fallirà silenziosamente.

Il softphone web SipPulse è un client di riferimento di livello professionale costruito sulle stesse primitive.

## Verifica di una chiamata WebRTC

Con il browser registrato, `pjsip show contacts` mostra il contatto dinamico e una chiamata attiva il canale:

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

Se l'audio è unidirezionale o assente, si tratta quasi sempre di ICE o del certificato — vedere la risoluzione dei problemi di seguito.

## Asterisk WebRTC contro un media gateway

Asterisk può terminare WebRTC direttamente, ma non è sempre lo strumento giusto:

- **Utilizza il WebRTC nativo di Asterisk** quando il browser è un *telefono* sul tuo PBX — un agente, un extension interno, un click-to-call che approda nel tuo dialplan. Il browser è semplicemente un altro endpoint e tutto (code, voicemail, IVR) funziona.
- **Utilizza un gateway dedicato (es. Janus)** quando hai bisogno di scalare molte sessioni browser indipendentemente dal controllo di chiamata, effettuare inoltri selettivi per grandi conferenze/streaming, o mantenere il piano media separato dal PBX. Un gateway fa da ponte tra WebRTC e SIP standard, e Asterisk vede quindi una normale tratta SIP.

Molti sistemi reali combinano entrambi: Asterisk per il controllo di chiamata, un gateway per lo scaling dei media lato browser. (Questa è l'architettura alla base dello stack di SipPulse.)

## Risoluzione dei problemi

- **WebSocket non si connette:** il browser ha rifiutato il certificato TLS. Apri
  `https://host:8089/ws` direttamente e accettalo, oppure installa un certificato attendibile.
- **Si registra ma non c'è audio:** ICE non riuscito — aggiungi STUN, e TURN se attraverso NAT. Controlla
  `pjsip set logger on` e osserva i candidati SDP.
- **Audio unidirezionale:** solitamente NAT/ICE su un lato, o un codec senza una corrispondenza comune —
  assicurati che `allow=opus,ulaw`.
- **La chiamata cade alla risposta:** handshake DTLS fallito; conferma che `dtls_auto_generate_cert`
  sia `Yes` e che l'orologio di sistema sia corretto (i certificati sono sensibili al tempo).

## Laboratorio

1. Eseguire `./lab.sh up`, quindi `bash lab/make-certs.sh` e riavviare Asterisk.
2. Servire `lab/webrtc/index.html` (`python3 -m http.server` da `lab/webrtc`) e aprirlo; accettare il certificato su `https://localhost:8089/ws`.
3. Registrarsi come `webrtc-1000` ed effettuare una chiamata verso `600` (test eco) — dovresti sentire la tua voce.
4. Dal softphone SipPulse registrato come `6001`, comporre `1000` per far squillare il browser.
5. Ispezionare la negoziazione: `pjsip set logger on`, effettuare una chiamata e trovare il fingerprint DTLS e i candidati ICE nell'SDP.

## Riepilogo

WebRTC trasforma un browser in un endpoint Asterisk di prima classe. La ricetta è breve ma rigorosa: abilitare il server HTTP con TLS affinché il browser possa aprire un WebSocket sicuro, aggiungere un trasporto PJSIP `wss` e impostare `webrtc=yes` sull'endpoint — il che attiva DTLS-SRTP (con un certificato generato automaticamente), ICE, multiplexing RTP/RTCP e il profilo AVPF. Aggiungere STUN/TURN quando si attraversa un NAT, servire la propria pagina tramite HTTPS e puntare un client SIP.js (o JsSIP) su `wss://asterisk:8089/ws`. Per telefoni basati su browser nel proprio PBX, il WebRTC nativo di Asterisk è la strada più semplice; per media su larga scala, è consigliabile abbinarlo a un gateway.

## Quiz

1. Quale trasporto utilizza un client browser WebRTC per veicolare la segnalazione SIP verso Asterisk?
   - A. UDP semplice sulla porta 5060
   - B. Un WebSocket sicuro (`wss://`) verso il server HTTP di Asterisk
   - C. TLS sulla porta 5061
   - D. Un socket TCP raw sulla porta 8088

2. Il media WebRTC tra il browser e Asterisk viene crittografato utilizzando quale meccanismo?
   - A. SDES-SRTP (chiavi scambiate nell'SDP)
   - B. DTLS-SRTP (chiavi derivate da un handshake DTLS)
   - C. IPsec
   - D. RTP semplice — WebRTC non crittografa i media

3. Vero o falso: quando si imposta `webrtc=yes`, è necessario generare e installare manualmente il certificato DTLS utilizzato per crittografare i media.

4. Su quale porta il server HTTP di Asterisk del laboratorio espone il WebSocket **sicuro** per WebRTC?
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. Quale delle seguenti opzioni viene attivata per impostazione predefinita da `webrtc=yes`? (Scegliere tutte le opzioni applicabili.)
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. Completa la frase: WebRTC negozia la connettività facendo in modo che entrambe le parti raccolgano e verifichino gli indirizzi candidati (host, STUN-reflexive, TURN-relayed) utilizzando il framework ________.

7. In `rtp.conf`, quali due impostazioni puntano Asterisk verso un server esterno in modo che possa scoprire il proprio indirizzo pubblico e inoltrare i media quando i percorsi diretti falliscono? (Scegliere tutte le opzioni applicabili.)
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. Il percorso URL che il `res_http_websocket` di Asterisk espone per la segnalazione WebRTC è ________.

9. Secondo il capitolo, quando dovresti ricorrere a un media gateway dedicato (come Janus) invece del WebRTC nativo di Asterisk?
   - A. Ogni volta che un browser deve effettuare una chiamata
   - B. Quando è necessario scalare molte sessioni media da browser indipendentemente dal controllo di chiamata, eseguire l'inoltro selettivo per grandi conferenze o mantenere il piano media separato dal PBX
   - C. Solo quando il browser non supporta DTLS
   - D. Quando vuoi che voicemail e IVR funzionino per l'endpoint browser

10. Vero o falso: `getUserMedia` (accesso al microfono) funziona su qualsiasi pagina `http://`, quindi servire il softphone via browser tramite HTTPS è facoltativo.

**Risposte:** 1 — B · 2 — B · 3 — Falso (Asterisk genera automaticamente il certificato DTLS; `dtls_auto_generate_cert: Yes`) · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — Falso (richiesto contesto sicuro: `getUserMedia` funziona solo su `https://` o `http://localhost`)
