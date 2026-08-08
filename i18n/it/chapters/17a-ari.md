# L'Asterisk REST Interface (ARI)

Il capitolo precedente ha trattato AMI e AGI, i due metodi classici per integrare logica esterna in Asterisk. Entrambi precedono il web moderno: AMI fornisce un flusso di eventi grezzo e orientato alle righe su un socket TCP, mentre AGI assegna un singolo canale a uno script per la durata di una chiamata. Nessuno dei due è stato progettato per il tipo di applicazioni stateful, asincrone e multi-canale che si costruiscono oggi: IVR che comunicano con servizi web, dashboard click-to-call, controller per conferenze o voicebot che trasmettono audio a un motore di sintesi vocale.

ARI — l'Asterisk REST Interface — è stata introdotta in Asterisk 12 per colmare tale lacuna e, in Asterisk 22, rappresenta l'interfaccia raccomandata per la creazione di nuove applicazioni di telefonia. L'idea alla base di ARI è una netta separazione delle responsabilità: **Asterisk diventa un motore multimediale** (risponde ai canali, gestisce i bridge, riproduce e registra audio, invia DTMF) e **la tua applicazione fornisce tutta la logica di controllo della chiamata** attraverso una combinazione di API REST (HTTP) e un flusso di eventi WebSocket.

## Obiettivi

Al termine di questo capitolo, il lettore sarà in grado di:

- Spiegare cos'è ARI e in cosa differisce da AMI e AGI
- Decidere quando ARI è l'interfaccia giusta per un progetto
- Configurare `ari.conf` e `http.conf` per abilitare ARI e creare un utente
- Connettersi al flusso di eventi WebSocket di ARI
- Descrivere l'applicazione del dialplan Stasis e gli eventi `StasisStart`/`StasisEnd`
- Descrivere il modello di risorse ARI: channels, bridges, playbacks, recordings, endpoints e device states
- Scrivere una semplice applicazione Stasis in Python che risponde a un channel, riproduce un suono e chiude la chiamata
- Spiegare cos'è il channel `externalMedia` e perché è importante per le integrazioni con AI e voicebot

## Che cos'è ARI e quando utilizzarlo

ARI si basa su due trasporti che lavorano insieme:

- **Una REST (HTTP) API** che la tua applicazione chiama per *fare* delle cose: originare un canale, rispondere, riprodurre un suono, creare un bridge, avviare una registrazione, riagganciare. Si tratta di normali richieste HTTP (`GET`, `POST`, `DELETE`) verso `http://asterisk-host:8088/ari/...`.
- **Un flusso di eventi WebSocket** tramite il quale Asterisk *informa* la tua applicazione su ciò che sta accadendo: un canale è stato creato, è arrivata una cifra DTMF, una riproduzione è terminata, un canale ha lasciato la tua applicazione. Gli eventi vengono consegnati come oggetti JSON.

Il pattern è asincrono: effettui una richiesta e il *risultato* di tale richiesta solitamente arriva in seguito sotto forma di evento. Ad esempio, invii `POST` una richiesta per riprodurre un suono; Asterisk risponde immediatamente con un oggetto `Playback` e, alcuni secondi dopo, ricevi un evento `PlaybackFinished` quando l'audio è terminato.

Scegli ARI invece di AMI e AGI quando:

- Hai bisogno di un **controllo granulare su canali e bridge**: costruire conferenze, parcheggi, code o flussi di chiamata personalizzati partendo da primitive invece di fare affidamento sulle applicazioni del dialplan.
- La tua applicazione è **stateful e a lunga durata**, gestisce diversi canali contemporaneamente e reagisce agli eventi su tutti loro.
- Vuoi integrare **servizi web, message bus o motori di AI/speech** e preferisci JSON su HTTP rispetto a un protocollo a riga di comando o a uno script stdin/stdout.
- Stai iniziando un **nuovo progetto** e desideri l'interfaccia che il progetto Asterisk raccomanda attivamente.

AMI rimane lo strumento giusto quando hai solo bisogno di *osservare* il sistema o inviare comandi occasionali (dialer, wallboard, monitoraggio). AGI è ancora conveniente per uno script IVR rapido e autonomo. Ma per tutto ciò che orchestra le chiamate, ARI è la risposta moderna.

> ARI non sostituisce il dialplan, lo integra. Un canale viene eseguito nel dialplan come di consueto finché non raggiunge l'applicazione `Stasis()`, momento in cui il controllo viene passato alla tua applicazione ARI. Quando la tua applicazione ha terminato, il canale può essere rimandato nel dialplan o riagganciato.

## Abilitazione di ARI: http.conf e ari.conf

ARI si appoggia al server HTTP integrato di Asterisk, quindi sono coinvolti due file di configurazione: `http.conf` abilita il server web, mentre `ari.conf` abilita ARI e definisce i suoi utenti.

### http.conf

Il server HTTP deve essere abilitato e associato a un indirizzo e a una porta. La porta convenzionale per ARI è la **8088**.

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
```

Per la produzione, è opportuno inserire ARI dietro TLS. Asterisk può gestire HTTPS direttamente (`tlsenable=yes`, `tlsbindaddr`, `tlscertfile`, `tlsprivatekey`), oppure è possibile terminare il TLS in un reverse proxy davanti alla porta 8088. Tramite TLS, gli URL diventano `https://` e `wss://` invece di `http://` e `ws://`.

È possibile verificare che il server HTTP sia attivo dalla CLI:

```
asterisk*CLI> http show status
HTTP Server Status:
Server Enabled and Bound to 0.0.0.0:8088
```

### ari.conf

`ari.conf` presenta una sezione `[general]` e una sezione per ogni utente.

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

Alcune note su queste opzioni:

- `enabled` attiva o disattiva ARI a livello globale.
- `pretty` formatta le risposte JSON in modo che siano leggibili dall'uomo; disattivalo in produzione.
- Ogni utente è una sezione nominata con `type=user`.
- `read_only=yes` limita l'utente a richieste di sola lettura (GET).
- `password_format` può essere `plain` (la password è in chiaro) o `crypt` (una password hashata, generata con `mkpasswd -m sha-512`).
- `permit`, `deny` e `acl` consentono restrizioni IP per utente, seguendo le stesse regole di `acl.conf`.

Dopo aver modificato i file, ricarica i moduli pertinenti (`module reload res_ari.so` e `module reload http.so`) o riavvia Asterisk. Puoi verificare che ARI sia in esecuzione con:

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

`ari show apps` elenca le applicazioni Stasis attualmente registrate dai client connessi. È vuoto finché un client non si connette, che è esattamente ciò che faremo in seguito.

### L'URL degli eventi WebSocket

Un client si iscrive al flusso di eventi aprendo un WebSocket verso l'endpoint `/ari/events`, specificando l'applicazione Stasis che implementa e passando le proprie credenziali:

```
ws://asterisk-host:8088/ari/events?app=hello&api_key=asterisk:secret
```

I parametri della query sono:

- `app` — il nome della tua applicazione Stasis. È lo stesso nome che userai nella chiamata `Stasis()` del dialplan. Puoi passare diversi nomi separati da virgola.
- `api_key` — le credenziali, nel formato `username:password`, corrispondenti a un utente in `ari.conf`.
- `subscribeAll` — booleano opzionale (predefinito `false`); quando è `true`, l'applicazione riceve tutti gli eventi, non solo quelli relativi alle risorse che possiede.

Le stesse credenziali `user:pass` vengono utilizzate come autenticazione HTTP Basic nelle chiamate REST (o aggiunte anche lì come parametro di query `api_key`).

## Stasis: passare un canale alla propria applicazione

Il ponte tra il dialplan e ARI è l'applicazione per il dialplan **`Stasis()`** (il framework sottostante è anch'esso chiamato Stasis). Quando un canale raggiunge `Stasis(appname[,args])`, Asterisk passa quel canale all'applicazione ARI registrata sotto `appname` e interrompe l'esecuzione del dialplan per esso. Il controllo ora appartiene al proprio codice.

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

Quando il canale entra nell'applicazione, ogni client connesso iscritto a `hello` riceve un evento **`StasisStart`** tramite WebSocket, contenente l'intero oggetto canale (il suo ID, nome, caller ID, stato ed eventuali argomenti passati a `Stasis()`). Questo è il segnale per iniziare a controllare il canale.

Quando il canale lascia l'applicazione — perché il proprio codice lo ha riportato al dialplan con `continueInDialplan`, o perché è stato terminato — si riceve un evento **`StasisEnd`**. Dopo che `Stasis()` ritorna al dialplan, esso imposta la variabile di canale `STASISSTATUS` (`SUCCESS` o `FAILED`), in modo che il dialplan possa ramificarsi in base al risultato.

## Il modello di risorse ARI

ARI espone le funzionalità interne di Asterisk come un piccolo insieme di risorse REST. Ogni risorsa risiede sotto `/ari/<resource>` e viene manipolata con metodi HTTP standard. Le più importanti sono:

| Risorsa | Cosa rappresenta | Operazioni di esempio |
|----------|--------------------|--------------------|
| **channels** | Un singolo segmento di chiamata | originate, answer, play, record, hangup |
| **bridges** | Un punto di missaggio che unisce i canali | create, add/remove channels, play to the bridge |
| **playbacks** | Una riproduzione multimediale in corso | get status, stop, pause/unpause |
| **recordings** | Registrazioni dal vivo e archiviate | start, stop, list stored, delete |
| **endpoints** | Peer configurati (PJSIP, ecc.) | list, get state, send a message |
| **deviceStates** | Stati dei dispositivi personalizzati | list, get, set, delete |

Alcune chiamate REST concrete (i percorsi sono mostrati con il prefisso `/ari` che appare sulla rete):

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

Il parametro `media` in una richiesta `play` accetta un URI multimediale. La forma più comune è un URI `sound:` che nomina un suono integrato, ad esempio `sound:hello-world` o `sound:tt-monkeys`. Quando l'audio termina, Asterisk emette un evento `PlaybackFinished` per quell'ID di riproduzione, che è il modo in cui la tua applicazione sa di poter procedere.

I canali e i bridge sono i due elementi costitutivi che combini per creare flussi di chiamata. Per connettere due chiamanti, ad esempio, origini o accetti due canali, crei un bridge `mixing` con `POST /ari/bridges` e aggiungi entrambi i canali ad esso con `POST /ari/bridges/{bridgeId}/addChannel`. Per costruire una conferenza, continui semplicemente ad aggiungere canali allo stesso bridge.

## Un esempio pratico: una applicazione Stasis minimale

Costruiamo la più piccola applicazione ARI utile. Quando viene composta una qualsiasi extension, la chiamata entra nella nostra applicazione Stasis, che risponde, riproduce il classico prompt `hello-world` e riaggancia.

### Il dialplan

In `extensions.conf`, invia il canale a Stasis:

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

Il nome dell'applicazione `hello` corrisponde al `app=hello` che utilizziamo durante la connessione.

### Il client Python

Questo client utilizza due librerie ben note: `requests` per le chiamate REST e `websocket-client` per il flusso di eventi. Installale con `pip install requests websocket-client`.

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

Esegui lo script, quindi componi un numero qualsiasi da un endpoint registrato. Dovresti sentire "Hello, world", dopodiché la chiamata viene rilasciata. Sulla console di Asterisk, `ari show apps` ora elencherà `hello` mentre il client è connesso.

Vale la pena tracciare il flusso una volta:

1. Il dialplan esegue `Stasis(hello)`; Asterisk passa il canale alla nostra applicazione e invia un evento `StasisStart`.
2. Rispondiamo al canale, quindi chiediamo ad Asterisk di riprodurre `sound:hello-world`. Asterisk restituisce un oggetto `Playback` di cui memorizziamo il `id`.
3. Quando l'audio termina, Asterisk invia `PlaybackFinished` con quel `id` di riproduzione; cerchiamo il canale e lo riagganciamo.
4. Il riaggancio causa l'uscita del canale da Stasis, producendo un evento `StasisEnd`.

> **Una nota sulle librerie client.** Esiste un wrapper di livello superiore chiamato `ari-py` (il pacchetto `ari`), ma non è più mantenuto ed è stato scritto per un'era precedente di Python e degli strumenti Swagger. Per nuovi lavori su Asterisk 22, preferisci l'approccio esplicito `requests` + WebSocket mostrato sopra, oppure una libreria asyncio come `asyncari` se hai bisogno di concorrenza. L'approccio "raw" ti mantiene vicino alle chiamate REST e agli eventi reali, che è esattamente ciò che desideri mentre impari ARI.

## externalMedia: la porta verso l'IA e i voicebot

Le risorse sopra descritte consentono di riprodurre e registrare *file*. Tuttavia, le moderne applicazioni vocali — trascrizione speech-to-text, voicebot basati su IA, analisi in tempo reale — richiedono che il *flusso audio in tempo reale* di una chiamata venga recapitato a un processo esterno e necessitano di iniettare audio in ritorno.

ARI fornisce questa funzionalità tramite il **`externalMedia` channel**. Una richiesta `POST /ari/channels/externalMedia` crea un canale speciale che, invece di comunicare con un telefono, trasmette il flusso media RTP della chiamata verso (e da) un host esterno. Si mette in bridge questo canale con quello del chiamante e, a quel punto, il proprio programma esterno si trova nel percorso audio: riceve l'audio del chiamante come RTP e può inviare audio sintetizzato in risposta.

La richiesta richiede solo:

- `app` — l'applicazione Stasis che possiede il nuovo canale.
- `format` — il formato audio, ad esempio `ulaw` o `slin16`.

`external_host` (il `host:port` della propria applicazione media) è opzionale nello schema — può essere vuoto per una connessione in stile WebSocket-server — ma per un classico voicebot RTP sarà necessario fornirlo. Il parametro `encapsulation` ha come valore predefinito `rtp` e `transport` quello di `udp`, che è esattamente ciò che serve per un endpoint di streaming media.

```
POST /ari/channels/externalMedia
    app=hello
    external_host=127.0.0.1:9000
    format=slin16
```

Questa singola funzionalità è ciò che trasforma Asterisk in un front-end per l'IA: la rete telefonica termina su Asterisk, ARI orchestra la chiamata e `externalMedia` convoglia l'audio verso un motore di sintesi vocale/IA e viceversa. Questo è il meccanismo su cui sono costruiti i servizi di IA e i voicebot.

## Riepilogo

ARI è l'interfaccia moderna e consigliata per creare applicazioni di telefonia su Asterisk 22. Suddivide il lavoro in modo netto: Asterisk funge da motore multimediale, mentre la tua applicazione — comunicando tramite JSON su HTTP e WebSocket — fornisce la logica di controllo delle chiamate. Si abilita tramite `http.conf` (il server web integrato sulla porta 8088) e `ari.conf` (che attiva ARI e definisce gli utenti).

L'applicazione del dialplan `Stasis()` trasferisce un canale alla tua applicazione, sollevando `StasisStart` quando vi entra e `StasisEnd` quando ne esce. Da lì, manipoli un piccolo set di risorse REST — channels, bridges, playbacks, recordings, endpoints e device states — per rispondere, riprodurre, registrare, mettere in bridge e terminare le chiamate.

Abbiamo costruito una minima applicazione Stasis in Python che risponde a una chiamata, riproduce un messaggio vocale e termina la comunicazione, e abbiamo visto come il canale `externalMedia` trasmetta RTP in tempo reale a un programma esterno — la base per le integrazioni di AI e voicebot.

## Quiz

1. In quale versione di Asterisk è stato introdotto ARI?
   - A. Asterisk 1.4
   - B. Asterisk 11
   - C. Asterisk 12
   - D. Asterisk 18
2. Nel modello ARI, Asterisk funge da motore multimediale mentre la tua applicazione esterna fornisce la logica di controllo delle chiamate.
   - A. Vero
   - B. Falso
3. ARI utilizza due trasporti congiuntamente. Quale coppia è corretta?
   - A. Un'API REST/HTTP per inviare comandi e un flusso WebSocket per ricevere eventi
   - B. Un protocollo di linea TCP e uno script stdin/stdout
   - C. SNMP e SMTP
   - D. Due socket UDP separati
4. Quali due file di configurazione devono essere impostati per abilitare ARI?
   - A. `manager.conf` e `agi.conf`
   - B. `http.conf` e `ari.conf`
   - C. `sip.conf` e `rtp.conf`
   - D. `modules.conf` e `cdr.conf`
5. La porta TCP convenzionale per il server HTTP di Asterisk (e quindi per ARI) è ____.
6. Quale applicazione del dialplan trasferisce un canale a un'applicazione ARI?
   - A. `AGI()`
   - B. `Dial()`
   - C. `Stasis()`
   - D. `System()`
7. Quando un canale entra in un'applicazione Stasis, quale evento viene inviato al client connesso?
   - A. `ChannelDestroyed`
   - B. `StasisStart`
   - C. `Newchannel`
   - D. `Hangup`
8. Quale richiesta ARI crea un punto di missaggio in grado di unire due o più canali?
   - A. `POST /ari/channels`
   - B. `POST /ari/bridges`
   - C. `GET /ari/endpoints`
   - D. `DELETE /ari/recordings/stored`
9. Per riprodurre un prompt integrato su un canale, quale evento comunica alla tua applicazione che l'audio è terminato, consentendole di proseguire?
   - A. `PlaybackStarted`
   - B. `DTMFReceived`
   - C. `PlaybackFinished`
   - D. `ChannelTalkingFinished`
10. Il canale `externalMedia` viene utilizzato principalmente per:
    - A. Registrare una chiamata in un file WAV locale
    - B. Trasmettere l'audio live della chiamata (RTP) verso e da un'applicazione esterna, ad esempio un motore AI/vocale
    - C. Registrare un endpoint PJSIP
    - D. Ricaricare il dialplan

**Risposte:** 1 — C · 2 — A · 3 — A · 4 — B · 5 — `8088` · 6 — C · 7 — B · 8 — B · 9 — C · 10 — B
