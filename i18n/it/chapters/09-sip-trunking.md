# SIP trunking, DID & la PSTN

Un PBX che può chiamare solo se stesso non è molto utile. Prima o poi ogni sistema deve raggiungere il resto del mondo — la PSTN (public switched telephone network), un provider SIP o un altro PBX. Il collegamento che trasporta queste chiamate è un **trunk**. Nell'era TDM un trunk era un circuito fisico: una PRI T1/E1 o un gruppo di linee analogiche FXO. Oggi è quasi sempre un **SIP trunk** — una connessione logica verso un ITSP (Internet Telephony Service Provider) trasportata sulla stessa rete IP di tutto il resto.

Questo capitolo mostra come connettere Asterisk 22 a un ITSP con PJSIP, come scegliere tra un trunk basato su registrazione e uno basato su IP, come instradare i numeri DID in entrata verso la destinazione corretta, come inviare chiamate in uscita con il corretto caller-ID e la formattazione E.164, e come costruire meccanismi di failover e least-cost routing attraverso diversi trunk. Concludiamo con la gestione del NAT per i trunk e un laboratorio che configura un secondo Asterisk (e SIPp) come un ITSP simulato, in modo da poter effettuare chiamate reali attraverso un trunk.

Tutto ciò che è riportato qui è verificato rispetto al laboratorio Asterisk 22.10.0 del libro; il pattern dell'oggetto trunk è lo stesso introdotto in *Building your first PBX with PJSIP* e *SIP & PJSIP in depth*.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Connettere Asterisk 22 a un ITSP tramite PJSIP
- Scegliere tra trunk basati su registrazione e trunk basati su IP (statici)
- Instradare i DID in entrata verso l'extension, l'IVR o la coda corretti
- Instradare le chiamate in uscita con il corretto caller-ID e la formattazione E.164
- Configurare il failover dei trunk e il least-cost routing con `${DIALSTATUS}`
- Gestire il NAT per i trunk sul transport e sull'endpoint

## Che cos'è un SIP trunk

Un SIP trunk è un percorso vocale logico tra il tuo PBX e un altro sistema SIP. In pratica, quell'"altro sistema" è una di queste due cose:

- **Un ITSP (Internet Telephony Service Provider).** Un operatore commerciale che ti vende l'origine e la terminazione delle chiamate e, solitamente, un blocco di numeri telefonici (DID). Indirizzi Asterisk verso l'host di segnalazione del provider e il provider connette le tue chiamate alla più ampia PSTN. È così che la maggior parte dei sistemi moderni raggiunge la rete telefonica: non è richiesto alcun hardware di telefonia.
- **Un gateway PSTN.** Un dispositivo (o un altro Asterisk) che dispone di interfacce PSTN fisiche — una scheda PRI, porte FXO analogiche o un gateway GSM/4G — e le presenta al tuo PBX come SIP. Il gateway esegue la conversione da TDM a SIP; dal punto di vista di Asterisk, è solo un altro SIP trunk.

In entrambi i casi, in PJSIP un trunk è **semplicemente un endpoint**. La stessa famiglia di oggetti che hai usato per un telefono — `endpoint`, `auth`, `aor`, opzionalmente `identify` e `registration` — crea un trunk. Le differenze stanno nei dettagli: un trunk autentica in *uscita* (tu sei il client, quindi le credenziali vanno in `outbound_auth`, non in `auth`), solitamente non registra un user agent verso di te (tu ti registri *presso di esso*, oppure esso ti invia traffico da un IP noto) e fa atterrare le chiamate in entrata in un context dedicato come `from-pstn` invece di `from-internal`.

> **Confronto con il vecchio trunk TDM.** Una PRI ti forniva un numero fisso di canali B (23 su una T1, 30 su una E1) e segnalava l'impostazione della chiamata su un canale D dedicato (vedi il capitolo *Legacy channels*). Un SIP trunk non ha un conteggio fisso di canali: la capacità è determinata dalla tua larghezza di banda, dalla politica del tuo provider e da qualsiasi limite di `max_contacts`/chiamate simultanee. Il Caller-ID, il DID e l'avanzamento della chiamata che un tempo viaggiavano sugli elementi informativi ISDN ora viaggiano su header SIP e SDP.

Ci sono due modi in cui un ITSP accetterà di scambiare traffico con te, e questi determinano come costruirai il trunk: **basato su registrazione** e **basato su IP (statico)**. Esaminiamo ciascuno di essi a turno.

## Trunk basati su registrazione

Un trunk basato su registrazione è il modello utilizzato quando il provider si aspetta che sia *tu* ad accedere a *loro*. Il tuo Asterisk invia periodicamente un SIP `REGISTER` al provider, autenticandosi con nome utente e password, esattamente come fa un telefono quando si registra al tuo PBX. Questo è comune quando il tuo IP pubblico è dinamico, quando ti trovi dietro NAT, o quando il provider identifica semplicemente i clienti tramite credenziali SIP anziché tramite indirizzo IP.

In PJSIP il login in uscita risiede in un oggetto `registration` dedicato. Sostituisce la singola riga `register =>` che il driver `chan_sip` rimosso utilizzava in `sip.conf`. Ecco un trunk di registrazione completo verso un provider fittizio, che segue il modello verificato dei capitoli precedenti — nota `outbound_auth` (non `auth`), `server_uri`/`client_uri` (non `server`/`client`), `from_user`/`from_domain` sull'endpoint e `dtmf_mode=rfc4733`:

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

Alcune cose da notare:

- **`auth_type=digest`, non `userpass`.** Entrambi producono la stessa autenticazione digest, ma in Asterisk 22 `userpass` (e il vecchio `md5`) sono **deprecati e convertiti silenziosamente in `digest`**. Preferisci `digest` nelle nuove configurazioni; vedrai ancora `userpass` nei file più vecchi e nei capitoli precedenti di questo libro.
- **`outbound_auth` sia sull'endpoint che sulla registrazione.** La registrazione lo usa per autenticare il `REGISTER`; l'endpoint lo usa per rispondere al `407 Proxy Authentication Required` che il provider invia in risposta a una chiamata in uscita `INVITE`. Possono condividere lo stesso oggetto `auth`.
- **`from_user` / `from_domain`.** Molti provider rifiutano le chiamate il cui header `From` non contiene il tuo numero di account e il loro dominio. Queste due opzioni impostano esattamente questo.
- **`contact_user=4830001000`.** Questa diventa la parte utente del `Contact` che registri, così il provider sa a quale numero recapitare le chiamate in entrata. È l'equivalente moderno del suffisso `/9999` sulla vecchia riga `register =>`.
- **`retry_interval=60`.** Se la registrazione fallisce, riprova ogni 60 secondi.

Dopo un reload, conferma la registrazione con `pjsip show registrations`. Nel laboratorio — dove `itsp.example.com` non risponde effettivamente — la tabella appare così:

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

Il suffisso `(exp. Ns)` conta alla rovescia i secondi fino al tentativo successivo; una volta che arriva a zero, legge brevemente `(exp. Ns ago)` prima che il tentativo venga effettuato. Con un provider reale, la colonna `Status` legge `Registered` con i secondi rimanenti fino al prossimo refresh. `Rejected` (o `Unregistered`) significa che il provider non ha accettato il login — attiva `pjsip set logger on` e leggi la risposta `401`/`403`, quasi sempre dovuta a un nome utente, una password o un dominio `client_uri` errati.

## IP-based (static) trunks

Il secondo modello non richiede alcuna registrazione. Il provider conosce il tuo indirizzo IP pubblico e invia le chiamate direttamente ad esso; tu, a tua volta, invii le chiamate all'IP di segnalazione noto del provider. L'autenticazione avviene tramite **indirizzo IP di origine**, non tramite credenziali SIP. Questo è tipico per i trunk tra due server sotto il tuo controllo, o per un trunk aziendale dove entrambi i lati hanno indirizzi statici.

L'oggetto chiave è `identify`. Esso comunica ad Asterisk: "qualsiasi richiesta SIP in arrivo da *questo* IP appartiene a *quell'* endpoint." Senza di esso, PJSIP tenta di abbinare una richiesta in entrata a un endpoint tramite l'utente `From`, il che non soddisferà il traffico di un carrier — quindi la chiamata verrebbe rifiutata o finirebbe nell'endpoint `anonymous`.

Un trunk statico omette l'oggetto `registration` e aggiunge `identify`:

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

`match` accetta un indirizzo IP, un intervallo CIDR o un nome host. **I nomi host vengono risolti una sola volta, al momento del caricamento della configurazione**, quindi se l'IP del tuo provider cambia devi ricaricare. Per un carrier che pubblica diversi gateway multimediali, elenca ogni IP di segnalazione — puoi ripetere `match` o fornire un CIDR:

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

Verifica cosa accetterà Asterisk con `pjsip show identifies`. Catturato dal laboratorio (la riga `sipp-identify` è l'endpoint SIPp preesistente del laboratorio):

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

### L'implicazione di sicurezza

Un trunk basato su IP senza autenticazione è una porta, e `identify`/`match` è l'unica serratura su di essa. Se `match` un intervallo troppo ampio — o se un attaccante riesce a falsificare un IP di origine — le chiamate atterrano nel tuo contesto `from-pstn` senza autenticazione. Due difese, usate insieme:

- **Abbina in modo più restrittivo possibile.** Preferisci IP host specifici rispetto a CIDR ampi. Solo gli IP di segnalazione reali del provider devono essere inclusi in `match`.
- **Abbinalo a una ACL.** PJSIP può scartare il traffico a livello SIP prima ancora che raggiunga un endpoint, utilizzando un oggetto `type=acl` (o `acl.conf`):

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

Una sezione `type=acl` non necessita di riferimenti: `res_pjsip_acl` applica ogni oggetto di questo tipo a *tutto* il traffico SIP in entrata prima che raggiunga qualsiasi endpoint. (Le opzioni `acl` e `contact_acl` sull'oggetto estraggono elenchi di regole denominati da `acl.conf` invece di elencare `permit`/`deny` inline come sopra.) Il principio è lo stesso del capitolo SIP: nega tutto, poi permetti solo ciò di cui ti fidi. E qualunque cosa faccia il tuo contesto di trunk, **non permettere mai che raggiunga un contesto in grado di chiamare verso la PSTN** senza una regola deliberata e autenticata — questo è il classico buco per le frodi telefoniche.

> **Quale modello dovrei usare?** Se il provider ti fornisce un nome utente e una password, usa un trunk di **registrazione**. Se ti chiedono il tuo indirizzo IP e ti forniscono il loro, usa un trunk di **identificazione**. Alcuni provider supportano entrambi; molti trunk reali combinano una registrazione (così il provider può trovarti) con un'identificazione (così gli INVITE in entrata dai gateway multimediali del provider vengono abbinati anche quando arrivano da un IP diverso dal registrar).

## Routing in entrata e gestione dei DID

Una volta che le chiamate in entrata arrivano, esse approdano nel `context` dell'endpoint — qui `from-pstn`. Un **DID** (Direct Inward Dialing number) è semplicemente il numero chiamato che il provider ti fornisce nell'URI della richiesta. Il tuo compito nel dialplan è mappare ogni DID verso una destinazione: un singolo extension, un IVR, una coda o un gruppo di squillo.

Il numero inviato dal provider viene confrontato come `${EXTEN}` in `from-pstn`. Quanto di esso tu riesca a vedere dipende dal provider — alcuni inviano il numero E.164 completo (`+4830001000`), alcuni inviano il numero nazionale, altri inviano solo le ultime cifre. Ispeziona una chiamata in entrata reale con `pjsip set logger on` e osserva l'URI della richiesta prima di scrivere i pattern.

### Da un DID a un singolo extension

Il caso più semplice — un singolo DID instradato direttamente verso un telefono:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### Da un DID a un IVR (risponditore automatico)

Un numero principale che dovrebbe rispondere con un menu invece di far squillare un telefono:

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` è il context del risponditore automatico che hai costruito nei capitoli sul dialplan (`Background()` + `WaitExten()`). L'instradamento del DID è semplicemente un `Goto`.

### Da un DID a una coda

Una linea di supporto che dovrebbe approdare in una coda di chiamate:

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### Molti DID contemporaneamente

Quando acquisti un blocco di numeri, un pattern mantiene il dialplan compatto. Supponiamo che il tuo intervallo di DID sia `4830003000`–`4830003099` e che il provider invii il numero completo; mappa le ultime due cifre di ogni DID verso l'extension `60xx`:

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}` prende le ultime due cifre (l'offset negativo conta da destra), quindi `4830003007` fa squillare `PJSIP/6007`. Una tabella di ricerca `did => extension` costruita con `GoSub` o un database Asterisk (`AstDB`/`func_odbc`) scala ancora meglio, ma per una manciata di numeri i pattern espliciti sono la soluzione più chiara.

> **Intercetta il DID non corrispondente.** Aggiungi un extension `i` (invalid) al `from-pstn` in modo che un numero in entrata instradato erroneamente riproduca un annuncio o faccia squillare l'operatore invece di cadere silenziosamente:
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## Routing in uscita, caller-ID ed E.164

Le chiamate in uscita seguono il percorso inverso: un telefono interno compone un numero, il tuo dialplan lo intercetta, rimuove l'eventuale prefisso di accesso, imposta il caller-ID atteso dal provider e passa la chiamata all'endpoint del trunk con `Dial(PJSIP/<number>@itsp)`.

### Invio della chiamata al trunk

La sintassi del canale per un trunk è `PJSIP/<number>@<endpoint>`: la parte prima del
`@` diventa la porzione utente dell'URI di richiesta in uscita, e la parte dopo il
`@` nomina l'endpoint il cui `aor` `contact` fornisce l'host di destinazione. Una
classica regola "componi 9 per una linea esterna":

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` rimuove il codice di accesso `9` iniziale prima che il numero venga inviato. Il
pattern `_9NXXXXXXXXX` corrisponde a `9` più un numero di 10 cifre la cui prima cifra è
compresa tra 2 e 9; adattalo al tuo dialplan.

### Caller-ID nelle chiamate in uscita

La maggior parte degli ITSP ignora — o rifiuta attivamente — un caller-ID che non sia un numero di tua proprietà.
Imposta il numero del caller-ID in uscita su uno dei tuoi DID con la funzione `CALLERID(num)`
prima di `Dial()`, come mostrato sopra. Puoi anche impostare il nome:

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

Se il provider continua a rimuovere o sovrascrivere il nome del tuo caller-ID, si tratta di una loro
politica — molti operatori ricavano il nome visualizzato dal proprio database CNAM
basandosi sul numero, non dal tuo header `From`.

Due opzioni dell'endpoint interagiscono con questo aspetto:

- **`from_user`** imposta la parte utente dell'header `From` a livello SIP, che
  alcuni provider utilizzano per identificare il tuo account indipendentemente dal `CALLERID(num)`.
- **`trust_id_outbound`** (predefinito `no`) controlla se Asterisk invierà
  header di identità sensibili alla privacy (`P-Asserted-Identity`/`P-Preferred-Identity`)
  in uscita. Lascialo disattivato a meno che il tuo provider non specifichi che richiede PAI, nel qual caso imposta `trust_id_outbound=yes` e `send_pai=yes`.

### Normalizzazione verso E.164

E.164 è il formato numerico internazionale: un `+` iniziale, il prefisso internazionale, poi il
numero nazionale, senza spazi o punteggiatura (ad esempio `+5548999990000` o
`+14155550100`). Gli operatori si aspettano sempre più spesso — o richiedono — il formato E.164 sul trunk.
Invece di disperdere la formattazione nel dialplan, normalizza una sola volta nel
context di uscita.

Un esempio nordamericano che accetta un numero locale di 10 cifre, un numero di 11 cifre
prefissato con `1`, o un numero già in formato E.164, e presenta sempre `+1…` al
trunk:

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

Alcuni provider vogliono il `+`; altri vogliono solo le cifre. Se il tuo rifiuta il
`+`, rimuovilo durante l'invio con `${EXTEN:1}` nel `Dial`. Il punto è che
tutta la logica di formattazione risiede in un unico posto, quindi cambiare provider — o aggiungerne uno secondo — è una modifica di una sola riga.

## Failover e instradamento a costo minimo

Con un solo trunk, un'interruzione del provider significa nessuna chiamata in uscita. Con due o più, è possibile eseguire il failover automaticamente e persino scegliere il percorso più economico per destinazione: *least-cost routing* (LCR).

### Failover con `${DIALSTATUS}`

`Dial()` imposta la variabile di canale `${DIALSTATUS}` al suo ritorno. I valori che interessano per il failover sono `CHANUNAVAIL` (il trunk non è stato affatto raggiunto) e `CONGESTION` (la chiamata è stata rifiutata, ad esempio tutti i circuiti sono occupati). Provare il trunk primario; se non è stato in grado di gestire la chiamata, passare a quello di backup:

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

Si noti la scelta deliberata di **non** eseguire il failover su `BUSY` o `NOANSWER`: questi significano che la *parte chiamata* è stata raggiunta e ha rifiutato, quindi riprovare su un altro trunk farebbe squillare di nuovo un telefono che ha già risposto negativamente (e potrebbe costare una seconda chiamata). Reinstradare solo quando il *trunk stesso* ha fallito.

### Una subroutine di routing riutilizzabile

Ripetere quella logica per ogni pattern di composizione è soggetto a errori. Fattorizzarla in una routine `GoSub` che prende il numero di destinazione e prova ogni trunk in ordine:

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

Ora ogni pattern in uscita è una chiamata `GoSub`, e l'ordine dei trunk è definito in un unico punto.

### Least-cost routing per destinazione

Il vero LCR sceglie il trunk in base alla destinazione della chiamata. Una struttura comune consiste nel far corrispondere il prefisso di destinazione e inviare ogni classe di chiamata al provider più economico per essa: ad esempio, le chiamate internazionali a un operatore all'ingrosso e le chiamate locali/nazionali a quello primario:

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

Per più di pochi prefissi, memorizzare la tabella di routing in un database (`func_odbc`/`AstDB`) e cercare il trunk per prefisso invece di codificare i pattern. Il dialplan rimane piccolo e le tariffe risiedono in una tabella che è possibile modificare senza ricaricare la logica.

## NAT e trunk

Il NAT è la causa più comune in assoluto dei problemi con i trunk: tipicamente audio unidirezionale o un trunk che si registra ma non riceve mai chiamate in ingresso. La causa è la stessa dei telefoni (trattata in *SIP & PJSIP in depth* e *Designing a VoIP network*): Asterisk pubblicizza la propria idea del suo indirizzo in SIP e SDP e, dietro NAT, si tratta di un indirizzo privato RFC 1918 verso cui il provider non può instradare il traffico.

Per i trunk, la soluzione si articola in due parti: impostazioni sul **transport** (il tuo indirizzo pubblico) e impostazioni sull'**endpoint** (come gestire i media del provider).

### Sul transport — il tuo indirizzo pubblico

Quando il server Asterisk stesso si trova dietro NAT (una macchina in cloud o on-premise con un IP privato e un IP pubblico 1:1), comunica al transport il suo indirizzo pubblico e quali reti sono locali. Queste opzioni si impostano una volta sola, sul `transport`, e si applicano a tutto il traffico che vi transita:

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

- **`external_signaling_address`** — l'IP pubblico che Asterisk scrive negli header SIP (`Via`, `Contact`) per le destinazioni esterne a `local_net`.
- **`external_media_address`** — l'IP pubblico che Asterisk scrive nella riga SDP `c=` affinché l'RTP torni al posto giusto. Solitamente è identico all'indirizzo di segnalazione.
- **`local_net`** — le reti che Asterisk tratta come interne, in modo da *non* riscrivere gli indirizzi per i peer in LAN. Elenca ogni subnet interna.

### Sull'endpoint — i media del provider

L'altra metà gestisce un provider che a sua volta si trova dietro NAT, o che semplicemente invia i media da un indirizzo diverso da quello indicato nel suo SDP. Imposta questi parametri per ogni endpoint di trunk:

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

- **`direct_media=no`** — mantiene il flusso dei media attraverso Asterisk invece di lasciare che le due tratte comunichino direttamente. È essenziale attraverso il NAT e comunque necessario se si desidera registrare, transcodificare o monitorare la chiamata.
- **`rtp_symmetric=yes`** — il classico comportamento *comedia*: invia l'RTP all'indirizzo da cui provengono effettivamente i media, non all'indirizzo dichiarato nell'SDP.
- **`force_rport=yes`** — risponde al SIP dall'IP/porta sorgente della richiesta (RFC 3581), invece di fidarsi dell'header `Via`.
- **`rewrite_contact=yes`** — sui messaggi SIP in ingresso da questo endpoint, riscrive l'header `Contact` (o un appropriato header `Record-Route`) con l'indirizzo IP e la porta sorgente da cui proviene realmente il pacchetto. Secondo la documentazione dell'opzione, questo "aiuta i server a comunicare con gli endpoint che si trovano dietro NAT" e "aiuta a riutilizzare connessioni di trasporto affidabili come TCP e TLS".

> **Raccomandazione — telefoni vs trunk.** `rewrite_contact` è quasi sempre la scelta giusta per i telefoni, poiché il loro contatto pubblicizzato è tipicamente un indirizzo privato RFC 1918 non instradabile. Su un trunk basato su IP statico, il contatto del provider è solitamente già un indirizzo pubblico corretto, quindi riscriverlo è spesso non necessario; alcuni operatori preferiscono lasciarlo disattivato in quel caso e abilitarlo solo per i trunk con registrazione e per i telefoni dietro NAT. L'effetto documentato dell'opzione è puramente la riscrittura dell'header `Contact`/`Record-Route` in ingresso menzionata sopra: pertanto, la pratica sicura consiste nel testare con il proprio operatore specifico prima di attivarlo su un trunk statico.

Puoi verificare le impostazioni effettive su qualsiasi endpoint con `pjsip show endpoint <name>` — `direct_media`, `rtp_symmetric`, `force_rport`, `rewrite_contact` e il resto vengono tutti stampati nel dump dei parametri.

## Lab — un ITSP simulato con un secondo Asterisk e SIPp

Non è necessario un trunk a pagamento per fare pratica. Il laboratorio del libro esegue già un container Asterisk 22.10.0 e un container SIPp su una rete privata `172.30.0.0/24`; tratteremo il container SIPp come il "carrier" che effettua chiamate in ingresso e aggiungeremo un endpoint trunk che fa terminare tali chiamate in un context `from-pstn`.

![Un trunk SIP tra il PBX Asterisk e l'ITSP: il PBX si registra come un account, le chiamate in uscita compongono `PJSIP/<num>@trunk` e le chiamate in ingresso terminano nel context `from-pstn`.](../images/09-sip-trunking-fig01.png)

### 1. Aggiungere l'endpoint trunk

Aggiungere un trunk basato su IP a `lab/asterisk/etc/pjsip.conf` che corrisponda all'host SIPp del laboratorio e faccia terminare le chiamate in ingresso in `from-pstn`:

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

### 2. Instradare il DID in ingresso

In `lab/asterisk/etc/extensions.conf`, aggiungere un context `from-pstn` che risponda al DID che il carrier simulato comporrà e lo riproduca, quindi aggiungere una regola in uscita:

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

Ricaricare entrambi i file (`core reload`) e verificare che il trunk sia stato caricato:

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. Effettuare una chiamata in ingresso attraverso il trunk

Puntare uno scenario SIPp verso il PBX usando il DID come utente di destinazione. Il laboratorio include già `lab/sipp/uac_9000.xml`, che invia un INVITE all'extension `9000`; copiarlo in `uac_did.xml` e modificare la request-URI/`To` dell'utente da `9000` a `4830001000`, quindi eseguirlo dal container SIPp:

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

Osservare la chiamata che arriva su `from-pstn` nella console di Asterisk (`pjsip set logger on` mostra l'INVITE in ingresso; `core show channels` mostra il canale `PJSIP/itsp-…` che riproduce `demo-congrats`). Poiché l'IP sorgente di SIPp corrisponde al `identify`, la chiamata viene accettata senza autenticazione: esattamente come si comporta un trunk statico di un carrier.

### 4. Ispezionare il trunk

Acquisire la configurazione completa del trunk per i propri appunti:

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (Approfondimento) renderlo un trunk con registrazione

Configurare il *secondo* container Asterisk come registrar reale: fornire un `endpoint`+`auth`+`aor` per l'account `4830001000`, quindi sul PBX sostituire il blocco `identify` con il blocco `registration` dall'inizio di questo capitolo (puntando `server_uri` all'IP del secondo container). Confermare con `pjsip show registrations` che lo stato sia `Registered`, quindi effettuare una chiamata in ciascuna direzione.

## Riepilogo

Un trunk SIP collega il tuo PBX al mondo esterno e, in PJSIP, è semplicemente un endpoint costruito a partire dalla stessa famiglia `endpoint` + `auth` + `aor` che già conosci, più un `identify` o un `registration`. Utilizza un **trunk di registrazione** (`type=registration` con `outbound_auth`) quando il provider ti fornisce un nome utente e una password; utilizza un **trunk basato su IP** (`type=identify` con `match`) quando l'autenticazione avviene tramite IP di origine — e proteggi quest'ultimo con un `match` ristretto e un `acl`, poiché un trunk non autenticato è un bersaglio per le frodi telefoniche. In entrata, il DID del provider arriva come `${EXTEN}` nel tuo context `from-pstn`, dove lo instradi verso una extension, un IVR o una coda — i pattern e i `${EXTEN:-N}` mantengono compatti i blocchi di DID. In uscita, imposta `CALLERID(num)` su un numero di tua proprietà, normalizza verso E.164 in un unico punto e passa la chiamata a `PJSIP/<number>@trunk`. Costruisci resilienza provando più trunk e ramificando in base a `${DIALSTATUS}` (`CHANUNAVAIL`/`CONGESTION` significano re-instradamento; `BUSY`/`NOANSWER` no), e inserisci il routing a costo minimo in una tabella `GoSub`. Infine, il NAT per i trunk è bidirezionale: `external_media_address`/`external_signaling_address`/`local_net` sul **transport** per il tuo indirizzo pubblico, e `direct_media=no`, `rtp_symmetric`, `force_rport` e `rewrite_contact` sull'**endpoint** per i media del provider.

## Quiz

1. In PJSIP, le credenziali utilizzate per autenticare una chiamata *outbound* o una registrazione verso un provider sono referenziate con:
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. Dovresti utilizzare un trunk `type=registration` quando:
   - A. Il provider ti identifica tramite il tuo indirizzo IP sorgente.
   - B. Il provider ti fornisce un nome utente e una password e si aspetta che tu effettui il login.
   - C. Non vuoi mai che Asterisk invii un `REGISTER`.
   - D. Il trunk è tra due server con IP statico sotto il tuo controllo.
3. L'opzione `match` dell'oggetto `identify` accetta (seleziona tutte le opzioni applicabili):
   - A. Un indirizzo IP
   - B. Un intervallo CIDR
   - C. Un hostname (risolto al momento del caricamento della configurazione)
   - D. Solo un nome utente SIP
4. Su Asterisk 22, `auth_type=userpass` è:
   - A. L'unico valore valido
   - B. Deprecato e convertito in `digest`
   - C. Rimosso e causa un errore di caricamento
   - D. Richiesto per la registrazione outbound
5. Un numero DID in ingresso arriva nel dialplan come:
   - A. `${CALLERID(num)}`
   - B. `${EXTEN}` nel `context` dell'endpoint del trunk
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. Per inviare le ultime due cifre del DID chiamato `4830003007` a un'extension, utilizzeresti:
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. Dopo `Dial()` verso un trunk, dovresti passare a un trunk di backup su cui `${DIALSTATUS}` valori (scegline due)?
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. Per impostare il numero caller-ID presentato al provider prima di effettuare una chiamata in uscita, usa:
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. Le opzioni che indicano ad Asterisk il suo indirizzo *pubblico* quando il server si trova dietro NAT sono impostate su:
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. `rtp_symmetric=yes` su un endpoint di tipo trunk fa sì che Asterisk:
    - A. Cripti RTP con SRTP
    - B. Invii RTP all'indirizzo da cui il media è effettivamente arrivato, ignorando l'SDP
    - C. Disabiliti completamente RTP
    - D. Forzi il direct media tra gli endpoint

**Risposte:** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
