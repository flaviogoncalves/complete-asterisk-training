# Creazione del tuo primo PBX con PJSIP

In questo capitolo, imparerai come eseguire una configurazione di base di un PBX Asterisk. L'obiettivo principale qui è vedere il PBX in funzione per la prima volta, essere in grado di chiamare tra extension, comporre un messaggio in riproduzione e chiamare verso un singolo trunk analogico o SIP. L'idea alla base di questo capitolo è assicurarsi che il tuo Asterisk sia operativo il prima possibile. Dopo aver completato il lavoro in questo capitolo, avrai una base sufficiente per prepararti ai capitoli successivi, dove approfondiremo i dettagli della configurazione.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Comprendere e modificare i file di configurazione;
- Installare softphone basati su SIP;
- Installare e configurare un trunk SIP;
- Installare e configurare una connessione analogica;
- Effettuare chiamate tra extension;
- Effettuare chiamate tra telefoni e destinazioni esterne; e
- Configurare un risponditore automatico (IVR).

## Comprendere i file di configurazione

Asterisk è controllato da file di configurazione testuali situati in /etc/asterisk. Il formato del file è simile ai file “.ini” di Windows. Il punto e virgola viene utilizzato come carattere di commento, i segni “=” e “=>” sono equivalenti e gli spazi vengono ignorati.

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asterisk interpreta “=” e “=>” nello stesso modo. Le differenze nella sintassi vengono utilizzate per distinguere tra oggetti e variabili. Utilizzare “=” quando si desidera dichiarare una variabile e “=>” per designare un oggetto. La sintassi è la stessa tra tutti i file, ma vengono utilizzati tre tipi di grammatica, come discusso di seguito.

## Grammars

| Grammar | Come viene creato l'oggetto | File di conf. | Esempio |
|---------|---------------------------|------------|---------|
| Simple Group | Tutto sulla stessa riga | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| Option Inheritance | Le opzioni vengono definite prima, l'oggetto eredita le opzioni | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| Complex Entity | Ogni entità riceve un context | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### Simple Group

Il formato simple group utilizzato in `extensions.conf` e `voicemail.conf` è la grammatica più basilare. Ogni oggetto viene dichiarato con le opzioni sulla stessa riga. Esempio:

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

In questo esempio, l'oggetto 1 viene creato con le opzioni op1, op2 e op3, mentre l'oggetto 2 viene creato con le opzioni op1, op2 e op3.

### Object options inheritance grammar

Questo formato è utilizzato dai file chan_dahdi.conf e agents.conf, dove sono disponibili numerose opzioni e la maggior parte delle interfacce e degli oggetti condivide le stesse opzioni. Tipicamente, una o più sezioni contengono dichiarazioni di oggetti e canali. Le opzioni per l'oggetto vengono dichiarate sopra l'oggetto stesso e possono essere modificate per un altro oggetto. Sebbene questo concetto sia difficile da comprendere, è molto facile da usare. Esempio:

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

Le prime due righe configurano il valore delle opzioni op1 e op2 rispettivamente su “bas” e “adv”. Quando l'oggetto 1 viene istanziato, viene creato utilizzando l'opzione 1 come “bas” e l'opzione 2 come “adv”. Dopo aver definito l'oggetto 1, cambiamo l'opzione 1 in “int”. Successivamente, creiamo l'oggetto 2 con l'opzione 1 come “int” e l'opzione 2 come “adv”.

### Complex entity object

Questo formato è utilizzato da pjsip.conf, iax.conf e altri file di configurazione in cui esistono numerose entità con molte opzioni. Tipicamente, questo formato non condivide un grande volume di configurazioni comuni. Ogni entità riceve un context. A volte esistono context riservati, come [general] per le configurazioni globali. Le opzioni vengono dichiarate nelle dichiarazioni del context. Esempio:

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

L'entità [entity1] ha i valori “value1” e “value2” rispettivamente per le opzioni op1 e op2. L'entità [entity2] ha i valori “value3” e “value4” per le opzioni op1 e op2.

## Opzioni per costruire un LAB per Asterisk

Per configurare un PBX, avrai bisogno di un po' di hardware di base. Non è difficile né costoso, ma ci sono alcune opzioni da considerare. Tutto ciò di cui avrai bisogno sono due telefoni e una connessione alla rete pubblica. Esistono diverse opzioni e combinazioni possibili durante la creazione del tuo lab, che discuteremo di seguito.

### Opzione 1: LAB completo

Con il LAB completo, è possibile testare tutti gli scenari disponibili e confrontare soluzioni come ATA, IP-phones e softphone. Puoi anche imparare a conoscere i trunk analogici e SIP. Avrai bisogno di:

- Un adattatore telefonico analogico (ATA) SIP
- Un IP phone
- Un server dedicato per Asterisk
- Una workstation con un softphone
- Una scheda di interfaccia analogica con almeno due interfacce (1 FXO e 1 FXS)
- Un account presso un provider VoIP

### Opzione 2: LAB economico

Con il LAB economico, semplifichiamo un po' le cose. Utilizziamo l'ATA, che solitamente è meno costoso dell'IP-phone, e una singola scheda FXO, che è davvero economica. Non saremo in grado di utilizzare telefoni analogici collegati direttamente al server, ma questo non accade comunemente nella pratica. Avrai bisogno di:

- Un adattatore telefonico analogico (ATA) SIP
- Un server dedicato per Asterisk
- Una workstation per il softphone
- Una scheda di interfaccia analogica con 1 FXO
- Un account presso un provider VoIP

### Opzione 3: LAB super economico

Il terzo LAB utilizza un server virtualizzato nel notebook dello studente. Il problema di questo modello sono i conflitti generati dalla porta UDP. A volte sia il server Asterisk che il softphone tentano di accedere alla stessa porta, impedendo ad Asterisk di eseguire il binding della porta dell'indirizzo. Un altro problema è la qualità delle chiamate; gli ambienti virtuali non sono indicati per applicazioni real-time come Asterisk. Utilizza un softphone gratuito per il server e la workstation e una connessione trunk a un provider SIP. Avrai bisogno di:

- Un portatile che esegue un softphone
- Una macchina virtuale (VirtualBox, VMware o simili) per installare Asterisk
- Un account presso un provider VoIP

## Sequenza di installazione

Per aiutarti a comprendere la sequenza di installazione, abbiamo delineato la serie di passaggi necessari per installare e configurare Asterisk.

![Layout del laboratorio di riferimento: softphone SIP/IAX, un telefono IP e adattatori analogici come extension (1), il server Asterisk con interfacce ETH0/FXO/FXS (3) e i trunk verso la PSTN tramite un provider VoIP o un collegamento a banda larga (2).](images/lab_layout.png){width=80%}(../images/04-first-pbx-fig01.png)

1. Configurazione delle extension
   - a. Extension SIP (ATA, softphone, telefono IP)
   - b. Extension IAX
   - c. Extension FXS
2. Configurazione dei trunk
   - a. Configurazione di un trunk SIP
   - b. Configurazione di un trunk FXO
3. Creazione di un dialplan di base
   - a. Chiamate tra extension
   - b. Chiamate verso destinazioni esterne
   - c. Ricezione di una chiamata sull'extension dell'operatore
   - d. Ricezione di una chiamata tramite un risponditore automatico (IVR)

## Configurazione delle extension

Le extension sono telefoni SIP, IAX o analogici collegati a una porta FXS. Per configurare un'extension, è necessario modificare il file di configurazione relativo al canale (pjsip.conf, iax.conf, chan_dahdi.conf).

### Extension SIP

Su Asterisk 22, PJSIP (lo stack `res_pjsip`, configurato in `/etc/asterisk/pjsip.conf`) è il driver del canale SIP. Supporta trasporti multipli per endpoint, è attivamente mantenuto ed è l'unico driver SIP fornito con la piattaforma. (Il driver originale `chan_sip` è stato rimosso in Asterisk 21 — consultare il capitolo *Legacy channels* se è necessario migrare una vecchia configurazione.)

L'idea qui è quella di configurare un semplice PBX. (I capitoli successivi forniranno un'intera sessione SIP/PJSIP con tutti i dettagli.) PJSIP è configurato in `/etc/asterisk/pjsip.conf` e contiene tutti i parametri relativi ai telefoni SIP e ai provider VoIP. I client SIP devono essere configurati prima di poter effettuare e ricevere chiamate.

#### Il trasporto

In PJSIP, la configurazione del listener (indirizzo di bind, porta, protocollo) risiede in un oggetto `transport`. Asterisk dispone di una protezione integrata contro l'indovinare i nomi utente: restituisce sempre una sfida di autenticazione identica per utenti sconosciuti e noti, e le richieste non identificate ripetute da un singolo IP vengono limitate nella frequenza tramite le opzioni `[global]` `unidentified_request_count`/`unidentified_request_period`. Le opzioni principali di un trasporto sono:

- protocol: Il protocollo di trasporto — `udp`, `tcp`, `tls`, `ws` o `wss`.
- bind: Indirizzo e porta a cui il listener si associa. Se si imposta l'indirizzo su `0.0.0.0`, si associa a tutte le interfacce; la porta SIP predefinita è 5060 per UDP/TCP.

Un trasporto UDP minimale:

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

La selezione dei codec (`disallow`/`allow`) e il `context` predefinito sono configurati su ogni `endpoint` (mostrato di seguito), non sul trasporto. Le chiamate anonime/guest sono gestite da un `endpoint` chiamato `anonymous`. I timer di registrazione sono controllati per AOR tramite `maximum_expiration`/`default_expiration`.

#### Client SIP

Dopo aver completato la sezione del trasporto, è il momento di configurare i client SIP. Vorrei ricordare ancora una volta al lettore che avremo un intero capitolo su SIP/PJSIP più avanti nel libro. Per ora, concentriamoci sulle basi e lasciamo i dettagli per dopo.

In PJSIP un client SIP è costruito da un insieme di oggetti correlati, legati insieme dal riferimento al nome:

- `endpoint`: Il comportamento della chiamata — codec (`allow`/`disallow`), il dialplan `context` e quali `auth` e `aors` utilizza.
- `auth`: Le credenziali. `username` è l'utente di autenticazione SIP e `password` è il segreto utilizzato per autenticare il dispositivo.
- `aor`: L'"address of record" — dove l'endpoint può essere raggiunto. O un `contact=` statico (per un dispositivo con IP fisso) o `max_contacts=` per consentire al dispositivo di registrarsi dinamicamente.

Attenzione: Utilizzare password forti, con almeno 8 caratteri, caratteri alfanumerici e numerici, e almeno un simbolo. Nelle mailing list sono apparse segnalazioni di server hackerati e i programmi per forzare le password SIP sono facilmente disponibili per gli script kiddies. Le frodi telefoniche costano migliaia di dollari a consumatori e provider.

L'endpoint 6000 è un dispositivo con IP fisso, quindi il suo AOR contiene un `contact` statico invece di consentire la registrazione. L'endpoint 6001 è un dispositivo che si registra, quindi il suo AOR gli consente di registrarsi (`max_contacts=1`):

```
[6000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6000-auth
aors=6000

[6000-auth]
type=auth
auth_type=digest
username=6000
password=#MySecret1#7

[6000]
type=aor
contact=sip:6000@10.1.30.50

[6001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6001-auth
aors=6001

[6001-auth]
type=auth
auth_type=digest
username=6001
password=Mys3cr3t#

[6001]
type=aor
max_contacts=1
```

PJSIP consente alle sezioni `endpoint`, `auth` e `aor` di condividere lo stesso nome di sezione (ad esempio i due blocchi `[6001]` sopra, distinti dal loro `type=`); molti amministratori invece aggiungono un suffisso (`[6001]`, `[6001-auth]`, `[6001]` aor) per leggibilità. Per un dispositivo che si registra, il contatto viene appreso dinamicamente quando il telefono si registra, quindi l'AOR non necessita di alcun `contact` statico.

## Estensioni IAX

`chan_iax2` è ancora incluso in Asterisk 22 ma è ormai considerato legacy; SIP/PJSIP è il protocollo preferito per le nuove implementazioni.

È possibile creare anche estensioni IAX. Questo protocollo è nativo di Asterisk e dedicheremo un'intera sezione ad esso più avanti in questo libro. Per ora, creiamo alcune estensioni utilizzando il protocollo. Essendo la prima sezione da configurare, la sezione [general] presenta alcuni parametri da impostare. Le opzioni principali sono:

- allow/disallow: Definisce quali codec verranno utilizzati.
- bindaddr: Indirizzo a cui si associa il listener IAX2. Se impostato come 0.0.0.0 (predefinito), si assocerà a tutte le interfacce.
- context: Imposta il context predefinito per tutti i client, a meno che non venga modificato nella sezione del client. Abbiamo utilizzato dummy per motivi di sicurezza. Gli utenti non autenticati finiscono in questo context quando l'opzione allowguest è impostata su yes.
- bindport: Porta UDP IAX2 su cui rimanere in ascolto (predefinita 4569).
- delayreject: Quando impostato su yes, ritarda l'invio di un rifiuto di autenticazione per una REGREQ o AUTHREQ, il che migliora la sicurezza contro gli attacchi brute-force alle password.
- bandwidth: Quando impostato su high, consente la selezione di codec ad alta larghezza di banda, come il g711 nelle varianti ulaw e alaw.

Il seguente è un esempio della sezione [general] del file iax.conf.

```
[general]
bindport = 4569
bindaddr = 10.1.30.45 ;(use your IP)
context = dummy
delayreject=yes
bandwidth=high
disallow = all
allow = ulaw
```

### Client IAX

Dopo aver terminato le sezioni generali, è il momento di configurare i client IAX.

- `[name]`: Il nome della sezione è il nome del peer/user IAX; una connessione IAX in entrata viene associata ad esso tramite il nome.
- `type`: La classe di connessione — `peer`, `user` o `friend`:
  - `peer`: Asterisk invia chiamate a un peer.
  - `user`: Asterisk riceve chiamate da un user.
  - `friend`: entrambe le direzioni contemporaneamente.
- `host`: Indirizzo IP o nome host. Il valore più comune è `dynamic`, utilizzato quando il dispositivo si registra su Asterisk.
- `secret`: Password per autenticare peer e user.

Avviso: Utilizzare password complesse con almeno 8 caratteri, caratteri alfanumerici e numerici, e almeno un simbolo. Nelle mailing list sono apparse segnalazioni di server hackerati e sono disponibili strumenti di cracking brute force per gli hash md5 di IAX per script kiddies. Le frodi telefoniche costano migliaia di dollari a consumatori e provider. Esempio:

```
[guest]
type=user
context=dummy
callerid="Guest IAX User"
[6003]
type=friend
context=from-internal
secret=#sup3rs3cr3t#
host=dynamic
[6004]
type=friend
context=from-internal
secret=#s3cr3ts3cr3t#
host=dynamic
```

## Configurazione dei dispositivi SIP

Dopo aver definito i telefoni nel file di configurazione di Asterisk, è giunto il momento di configurare il telefono stesso. In questo esempio, mostreremo come configurare un softphone gratuito — il SipPulse Softphone (scaricabile da https://www.sippulse.com/produtos/softphone). Consulta il manuale del tuo dispositivo per comprendere i parametri del tuo telefono. Passaggio 1: Configura il telefono per utilizzare l'extension 6000. Esegui il programma di installazione. Dopo l'esecuzione, apri le impostazioni account/SIP e aggiungi un nuovo account SIP. Inserisci le informazioni richieste.

![Schermata dell'account del SipPulse Softphone — inserisci il Server (il tuo IP o dominio Asterisk), Username, Password e Display Name, quindi scegli il Transport (UDP, TCP o TLS).](../images/softphone/sipphone-account.png){width=35%}

Display Name: 6000  User Name: 6000  Password: #MySecret1#7  Authorization User Name: 6000  Domain: ip_of_your_server. Conferma che il tuo telefono sia registrato utilizzando il comando della console `pjsip show endpoints` (o `pjsip show endpoint 6000` per i dettagli; `pjsip show contacts` mostra i contatti AOR registrati). Ripeti la configurazione per il telefono 6001.

![Un SipPulse Softphone registrato — il punto verde e la riga dell'account (`1001@softphone.sippulse.com.br`) confermano la registrazione; effettua una chiamata dal tastierino o dai pulsanti di chiamata/video.](../images/softphone/sipphone-registered.png){width=35%}

## Configurazione dei dispositivi IAX

IAX2 è un protocollo legacy (si veda il capitolo *Legacy channels*), e il Softphone SipPulse è solo SIP, quindi non può registrare un account IAX. Se hai bisogno di testare IAX2, utilizza un softphone che lo supporti ancora. Crea un nuovo account IAX,

3. Seleziona il nuovo account IAX.
4. Inserisci le opzioni relative per il telefono 6003 e, facoltativamente, per il 6004.
5. Salva la configurazione e verifica se il telefono è registrato utilizzando `iax2 show peers`.

Importante: usa un account per SIP e un altro per IAX. Se desideri configurare il sistema per far squillare sia IAX che SIP contemporaneamente, ti mostreremo come farlo nella sezione del dialplan.

### Configurazione di un'interfaccia PSTN

Per connettersi alla PSTN, avrai bisogno di un'interfaccia foreign exchange office (FXO) e di una linea telefonica. Puoi utilizzare anche un'estensione di un PBX esistente. Puoi ottenere una scheda di interfaccia telefonica con un'interfaccia FXO da diversi produttori. In questo esempio, ti mostreremo come installare una scheda di interfaccia DAHDI.

![Porte FXS e FXO: la porta FXS pilota un telefono analogico (fornisce segnale di linea e suoneria), mentre la porta FXO collega Asterisk alla linea Telco.](../images/04-first-pbx-fig02.png)

### Linee analogiche tramite DAHDI

Puoi acquistare una scheda analogica compatibile con DAHDI da diversi produttori. La X100P è stata una delle prime schede Digium ed è già fuori produzione. Alcuni produttori producono ancora cloni simili. Oltre al prezzo della X100P, abbiamo riscontrato diversi problemi tra queste schede e le nuove schede madri, quindi usala con cautela. La X100P, a mio parere, non è una buona scelta per un ambiente di produzione. Qualsiasi scheda compatibile con DAHDI dovrebbe funzionare. Grazie al team di sviluppatori DAHDI, ora abbiamo uno strumento per rilevare e configurare le schede di interfaccia quasi automaticamente. Se hai appena installato i driver DAHDI, non dimenticare di eseguire make config e riavviare la macchina per caricarli automaticamente. Puoi utilizzare i comandi seguenti per rilevare e configurare la tua scheda. Passaggio 1: Per rilevare il tuo hardware, usa:

```
dahdi_hardware
```

Passaggio 2: Per configurare usa:

```
dahdi_genconf
```

Il comando sopra genererà due file /etc/dahdi/system.conf e /etc/asterisk/dahdi-channels.conf. I parametri predefiniti per dahdi_genconf vanno solitamente bene, ma puoi modificarli nel file /etc/dahdi/genconf_parameters. Per impostazione predefinita, inserirà le linee (FXO) nel context from-pstn e i telefoni (FXS) nel context from-internal. Passaggio 3: Dopo aver eseguito dahdi_genconf, nell'ultima riga del file /etc/asterisk/chan_dahdi.conf inserisci la seguente riga:

```
#include dahdi-channels.conf
```

Passaggio 4: Modifica il file /etc/dahdi/modules e commenta tutti i driver inutilizzati. Riavvia prima di procedere e verifica se i canali vengono riconosciuti utilizzando:

```
*CLI> dahdi show channels
```

### Connessione alla PSTN tramite un provider VoIP

Se il tuo budget è davvero limitato, puoi configurare un trunk SIP per connetterti alla PSTN. È certamente il modo più conveniente per connettersi alla PSTN. Esistono migliaia di provider VoIP in tutto il mondo. Per connetterti a uno di essi, avrai bisogno di alcuni parametri. Parametri forniti dal provider SIP.

- username: login
- password: secret
- Provider’s domain: domain
- UDP port: 5060
- Allowed codecs: g729, ilbc, alaw

Due parametri devono essere determinati da te.

- Extension per ricevere chiamate—in questo caso: 9999
- context: from-sip

In PJSIP, un trunk SIP che effettua la registrazione è costruito dalla stessa famiglia di oggetti utilizzata per un endpoint, più gli oggetti espliciti `registration` e `identify`. L'oggetto `registration` dice ad Asterisk di registrarsi presso il provider, l'oggetto `identify` abbina il traffico in entrata dall'IP del provider all'endpoint (PJSIP autentica gli INVITE in entrata tramite l'IP sorgente), e `outbound_auth` fornisce le credenziali per le chiamate in uscita e la registrazione:

```
[siptrunk]
type=endpoint
context=from-sip
disallow=all
allow=ilbc
allow=alaw
allow=g729
dtmf_mode=rfc4733
outbound_auth=siptrunk-auth
aors=siptrunk
from_user=login
from_domain=domain

[siptrunk-auth]
type=auth
auth_type=digest
username=login
password=secret

[siptrunk]
type=aor
contact=sip:domain:5060

[siptrunk]
type=identify
endpoint=siptrunk
match=domain

[siptrunk-reg]
type=registration
transport=transport-udp
outbound_auth=siptrunk-auth
server_uri=sip:domain:5060
client_uri=sip:login@domain:5060
contact_user=9999
retry_interval=60
```

Per accedere a questo trunk, utilizzeremo il nome canale `PJSIP/siptrunk`. L'impostazione `dtmf_mode=rfc4733` trasporta DTMF fuori banda (RFC 4733 rende obsoleta la precedente RFC 2833; il payload è identico). L'opzione `identify`/`match` accetta indirizzi IP, CIDR o nomi host, ma i nomi host vengono risolti una sola volta al momento del caricamento della configurazione, quindi per un provider con IP variabili elenca esplicitamente gli IP di segnalazione. Conferma la registrazione con `pjsip show registrations`.

## Introduzione al dialplan

Il dialplan è come il cuore di Asterisk. Definisce il modo in cui Asterisk gestisce ogni singola chiamata verso il PBX. È costituito da extension che formano un elenco di istruzioni che Asterisk deve seguire. Le istruzioni vengono attivate dalle cifre ricevute dal canale o dall'applicazione. Per configurare Asterisk con successo, è fondamentale comprendere il dialplan. La maggior parte del dialplan è contenuta nel file extensions.conf nella directory /etc/asterisk. Questo file utilizza una semplice grammatica a gruppi e si basa su quattro concetti principali:

- Extensions
- Priorità
- Applicazioni
- Contexts

Creiamo un dialplan di base. Nelle sezioni successive di questo libro, dedicherò un capitolo esclusivamente al dialplan. Se hai installato i file di esempio (make samples), il file extensions.conf esiste già. Salvalo con un altro nome e inizia con un file vuoto.

## La struttura del file extensions.conf

Il file extensions.conf è suddiviso in sezioni. La prima è la sezione [general] seguita dalla sezione [globals]. L'inizio di ogni sezione comincia con la definizione del suo nome (ad esempio, [default]) e termina quando viene creata un'altra sezione.

### La sezione [general]

La sezione general si trova nella parte superiore del file. Prima di iniziare a configurare il dialplan, è utile conoscere le opzioni generali che controllano determinati comportamenti del dialplan. Queste opzioni sono:

- static e write protect: Se `static=yes` e `writeprotect=no`, è possibile salvare il dialplan in esecuzione su disco con il comando CLI:

```
*CLI> dialplan save
```

Attenzione: Se si esegue un comando `dialplan save` dalla CLI, si perderanno tutte le annotazioni e i commenti presenti nel file.

- autofallthrough: Se autofallthrough è impostato, allora se un'extension termina le operazioni da eseguire, chiuderà la chiamata con BUSY, CONGESTION o HANGUP a seconda della stima migliore di Asterisk. Questa è l'impostazione predefinita. Se autofallthrough non è impostato, allora se un'extension termina le operazioni da eseguire, Asterisk attenderà che venga composta una nuova extension.
- clearglobalvars: Se clearglobalvars è impostato, le variabili globali verranno cancellate e rianalizzate durante un dialplan reload o un Asterisk reload. Se clearglobalvars non è impostato, le variabili globali persisteranno durante i ricaricamenti e, anche se eliminate dal file extensions.conf o da uno dei file inclusi, rimarranno impostate al valore precedente.
- extenpatternmatchnew: Utilizza un algoritmo di corrispondenza dei pattern più veloce, il che aiuta notevolmente quando si dispone di un gran numero di extension. L'impostazione predefinita è no.
- userscontext: Questo è il context in cui vengono registrate le voci provenienti da users.conf.

### La sezione [globals]

Nella sezione [globals] definirai le variabili globali e i loro valori iniziali. Puoi accedere alla variabile nel dialplan utilizzando ${GLOBAL(variable)}. Puoi persino accedere alle variabili definite nell'ambiente linux/unix utilizzando ${ENV(variable)}. Le variabili globali non sono case sensitive. Alcuni esempi potrebbero essere:

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

Nell'esempio seguente, puoi impostare e testare una variabile globale nel dialplan.

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Il context è la partizione denominata del dialplan. Dopo le sezioni [general] e [globals], il dialplan è un insieme di context in cui ogni context ha diverse extension, ogni extension ha diverse priority e ogni priority richiama un'applicazione con diversi argomenti.

![Flusso di una chiamata Asterisk: ogni chiamata arriva su un canale (IAX, SIP e altri) come leg di chiamata in ingresso; il context del canale — impostato globalmente o per singolo canale nel file di configurazione del canale — decide quale context in extensions.conf elabora la chiamata prima che essa prosegua sul leg in uscita.](asterisk_call_flow.png)(../images/04-first-pbx-fig03.png)

![Elaborazione della chiamata: il `context=` definito per un canale (in chan_dahdi.conf o pjsip.conf) indica il context corrispondente in extensions.conf dove il dialplan gestisce la chiamata.](call_processing.png)(../images/04-first-pbx-fig04.png)

È possibile costruire un semplice dialplan per raggiungere altri telefoni e la PSTN. Tuttavia, Asterisk è molto più potente di così. Il nostro obiettivo è insegnarvi ulteriori dettagli su ciò che è possibile realizzare nel dialplan.

## Extensions

A differenza del PBX tradizionale, dove le extension sono associate a telefoni, interfacce, menu e così via, in Asterisk una extension è un elenco di comandi da elaborare quando viene attivato uno specifico numero o nome di extension. I comandi vengono elaborati in ordine di priorità.

![Sintassi delle extension: `exten => number(name),{priority|label}[(alias)],application`. Le extension possono essere numeriche, alfanumeriche, numeriche con caller ID, un pattern o una extension standard come `s`; le priorità possono essere un numero, `n` (successiva), `s` (stessa), un offset o un `hint`.](../images/04-first-pbx-fig05.png)

Un'extension può essere letterale, standard o speciale. Un'extension standard include solo numeri o nomi e i caratteri * e #; 12#89* è un'extension letterale valida. Anche i nomi possono essere utilizzati per la corrispondenza delle extension. Le extension sono case sensitive. Tuttavia, non è possibile creare due extension con lo stesso nome ma con maiuscole/minuscole differenti. Quando viene composta un'extension, viene eseguito il comando con la prima priorità, seguito dal comando con priorità 2 e così via. Ciò avviene finché la chiamata non viene disconnessa o un comando restituisce il numero uno, indicando un errore. Cosa fa Asterisk quando viene eseguita l'ultima priorità è regolato dal parametro autofallthrough. Si veda la sezione [general] in questo capitolo. Esempio:

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

Qui sopra trovate l'elenco delle istruzioni da elaborare quando viene composta l'extension 123. La prima priorità è rispondere al canale (necessario quando il canale è nello stato di squillo: ad esempio, canali FXO). La seconda priorità è riprodurre un file audio chiamato tt-weasels. La terza priorità chiude il canale. Un'altra opzione è gestire la chiamata in base al caller ID. È possibile utilizzare il carattere / per specificare il caller ID da elaborare. Esempi:

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

Questo esempio attiverà l'extension 123 ed eseguirà le seguenti opzioni solo se il caller ID è 100. Questo può essere fatto anche utilizzando il pattern descritto di seguito:

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint: associa un'extension a un canale. Viene utilizzato per monitorare lo stato del canale. È usato in combinazione con la presence. Il telefono deve supportarlo.

#### Pattern

È possibile utilizzare pattern e letterali nel dialplan. I pattern sono molto utili per ridurre le dimensioni del dialplan. Tutti i pattern iniziano con il carattere “_”. I seguenti caratteri possono essere utilizzati per definire un pattern. La figura identifica i pattern disponibili per l'uso con Asterisk.

![Caratteri di pattern matching: `_` avvia un pattern, `.` corrisponde a uno o più caratteri, `!` corrisponde a zero o più, `[123-7]` corrisponde a qualsiasi cifra o intervallo elencato, `X` è 0-9, `Z` è 1-9 e `N` è 2-9 — con esempi che mappano intervalli di extension per ufficio.](../images/04-first-pbx-fig06.png)

### Extension speciali

Asterisk utilizza alcuni nomi di extension come extension standard.

![Extension speciali di Asterisk: `i` (non valida), `s` (avvio), `h` (chiusura), `t` (timeout), `T` (timeout assoluto), `o` (operatore), `a` (premuto `*` in voicemail), `fax` (rilevamento fax) e `Talk` (utilizzato con BackgroundDetect).](../images/04-first-pbx-fig07.png)

Descrizione:

- **s**: Start (Avvio). Viene utilizzato per gestire una chiamata quando non c'è un numero composto. È utile per trunk FXO ed elaborazione all'interno di menu.
- **t**: Timeout. Viene utilizzato quando le chiamate rimangono inattive dopo la riproduzione di un messaggio vocale. Viene anche utilizzato per chiudere una linea inattiva.
- **T**: AbsoluteTimeout. Se si stabilisce un limite di chiamata utilizzando la funzione del dialplan `TIMEOUT(absolute)`, una volta che la chiamata supera il limite definito, verrà inviata all'extension T.
- **h**: Hangup (Chiusura). Viene chiamata dopo che l'utente disconnette la chiamata.
- **i**: Invalid (Non valida). Viene attivata quando si chiama un'extension inesistente nel context. L'utilizzo di queste extension può influire sul contenuto dei record CDR, nello specifico sul campo dst che non contiene il numero composto.
- **o**: Operator (Operatore). Viene utilizzato per passare all'operatore quando l'utente preme "0" durante la voicemail.

L'uso di queste extension può modificare il contenuto dei record di fatturazione (CDR); in particolare, il campo dst non conterrà il numero composto. Per aggirare questo problema, si consiglia di utilizzare l'opzione g nell'applicazione dial() e considerare le funzioni resetcdr(w) e/o nocdr()

## Variabili

Nel PBX Asterisk, le variabili possono essere globali, specifiche del canale o specifiche dell'ambiente. È possibile utilizzare l'applicazione NoOP() per visualizzare il contenuto di una variabile nella console. Essa può utilizzare una variabile globale o una variabile specifica del canale come argomenti dell'applicazione. Una variabile può essere referenziata come nell'esempio seguente, dove varname è il nome della variabile.

```
${varname}
```

Il nome di una variabile può essere una stringa alfanumerica che inizia con una lettera. I nomi delle variabili globali non sono sensibili alle maiuscole (case-insensitive). Tuttavia, le variabili di sistema (definite da Asterisk o definite dal canale) sono sensibili alle maiuscole (case-sensitive). Pertanto, la variabile ${EXTEN} è diversa da ${exten}.

### Variabili globali

Le variabili globali possono essere configurate nella sezione [global] nel file extensions.conf o utilizzando l'applicazione:

```
set(Global(variable)=content)
```

### Variabili specifiche del canale

Le variabili specifiche del canale vengono configurate utilizzando l'applicazione set(). Ogni canale riceve il proprio spazio di variabili. Non c'è possibilità di collisioni tra variabili di canali diversi. Una variabile specifica del canale viene distrutta quando il canale viene terminato (hangup). Alcune delle variabili più comunemente utilizzate sono:

- ${EXTEN} Extension chiamata
- ${CONTEXT} Context corrente
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} Caller ID corrente
- ${PRIORITY} Priorità corrente

Altre variabili specifiche del canale sono tutte in maiuscolo. È possibile visualizzare il contenuto di diverse variabili utilizzando l'applicazione dumpchan(). Di seguito è riportato un semplice estratto delle variabili di dump-channel.

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Output di dumpchan:

```
Dumping Info For Channel: PJSIP/4400-00000001:
================================================================================
Info:
Name=               PJSIP/4400-00000001
Type=               PJSIP
UniqueID=           1161186526.1
LinkedID=           1161186526.0
CallerIDNum=        4400
CallerIDName=       laptop
ConnectedLineIDNum= (N/A)
ConnectedLineIDName=(N/A)
DNIDDigits=         9001
RDNIS=              (N/A)
Parkinglot=
Language=           en
State=              Ring (4)
Rings=              0
NativeFormat=       (ulaw)
WriteFormat=        ulaw
ReadFormat=         ulaw
RawWriteFormat=     ulaw
RawReadFormat=      ulaw
WriteTranscode=     No
ReadTranscode=      No
1stFileDescriptor=  16
Framesin=           0
Framesout=          0
TimetoHangup=       0
ElapsedTime=        0h0m0s
BridgeID=           (Not bridged)
Context=            default
Extension=          9001
Priority=           1
CallGroup=
PickupGroup=
Application=        DumpChan
Data=               (Empty)
Blocking_in=        (Not Blocking)
Variables:
```

Il layout dei campi sopra riportato è l'output di Asterisk 22 `DumpChan` (un nome canale `PJSIP/...` reale, i campi `CallerIDNum`/`ConnectedLineID` e le righe `Raw*`/`Transcode`/`BridgeID` che i canali PJSIP popolano). A differenza del vecchio driver, un canale PJSIP non imposta automaticamente le variabili di canale `SIPCALLID`/`SIPUSERAGENT`; i dettagli SIP equivalenti vengono letti su richiesta con le funzioni del dialplan `PJSIP_HEADER()` e `CHANNEL()` — ad esempio `${CHANNEL(pjsip,call-id)}`, `${PJSIP_HEADER(read,User-Agent)}` e `${CHANNEL(rtp,dest)}` per l'indirizzo RTP remoto.

### Variabili specifiche dell'ambiente

Le variabili specifiche dell'ambiente possono essere utilizzate per accedere alle variabili definite nel sistema operativo. È possibile impostare variabili specifiche dell'ambiente utilizzando la funzione ENV(). Ad esempio:

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### Variabili specifiche dell'applicazione

Alcune applicazioni utilizzano variabili per l'input e l'output dei dati. È possibile impostare le variabili prima di chiamare l'applicazione o recuperare la variabile dopo l'esecuzione dell'applicazione. Ad esempio: l'applicazione Dial restituisce le seguenti variabili:

- ${DIALEDTIME} -> Questo è il tempo trascorso dalla chiamata di un canale fino alla sua disconnessione.
- ${ANSWEREDTIME} -> Questa è la durata effettiva della chiamata.
- ${DIALSTATUS} Questo è lo stato della chiamata: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> Messaggio di errore per la chiamata.

## Espressioni

Le espressioni possono essere molto utili nel dialplan. Vengono utilizzate per manipolare stringhe ed eseguire operazioni matematiche e logiche.

![Panoramica delle espressioni Asterisk — `$[expression1 operator expression2]` — raggruppamento degli operatori matematici, logici, di confronto, di espressione regolare e condizionali disponibili nel dialplan.](../images/04-first-pbx-fig08.png)

La sintassi delle espressioni è definita come segue:

```
$[expression1 operator expression2]
```

Supponiamo di avere una variabile chiamata “I” e di voler aggiungere 100 alla variabile:

```
$[${I}+100]
```

Quando Asterisk trova un'espressione nel dialplan, sostituisce l'intera espressione con il valore risultante.

### Operatori

I seguenti operatori possono essere utilizzati per costruire espressioni. È importante osservare la precedenza degli operatori.

1. Parentesi “()”
2. Operatori unari “! -“
3. Espressione regolare “: =~
4. Operatori moltiplicativi “* / %”
5. Operatori additivi “+ -“
6. Operatori di confronto
7. Operatori logici
8. Operatori condizionali

#### Operatori matematici

- Addizione (+)
- Sottrazione (-)
- Moltiplicazione (*)
- Divisione (/)
- Modulo (%)

#### Operatori logici

- “AND” logico (&)
- “OR” logico (|)
- Complemento unario logico (!)

#### Operatori di espressione regolare

- Corrispondenza di espressione regolare (:)
- Corrispondenza esatta di espressione regolare (=~)

Un'espressione regolare è una stringa di testo speciale utilizzata per descrivere un pattern di ricerca. Si può pensare alle espressioni regolari come a dei caratteri jolly. Le espressioni regolari vengono utilizzate per confrontare una stringa con un pattern per verificarne la corrispondenza. Se la corrispondenza ha successo e l'espressione regolare contiene almeno una corrispondenza, viene restituita la prima corrispondenza; in caso contrario, il risultato è il numero di caratteri corrispondenti.

#### Operatori di confronto

Il risultato di un confronto è 1 se la relazione è vera o 0 se è falsa.

- = uguale
- != diverso
- < minore di
- > maggiore di
- <= minore o uguale a
- >= maggiore o uguale a

### LAB. Valuta le seguenti espressioni:

Inserisci queste espressioni nel tuo dialplan e usa l'applicazione NoOP() per valutare le espressioni. Componi 9002 ed esamina i risultati nella console di Asterisk. Usa verbose 15 per mostrare i risultati.

```
exten=9002,1,set(NAME="FLAVIO")                 ;Set NAME=FLAVIO
exten=9002,n,set(I=4)
exten=9002,n,set(URI="40001@voip.school")
exten=9002,n,NoOP(${NAME})
exten=9002,n,NoOP(${I})
exten=9002,n,NoOP($[${I}+${I}])
exten=9002,n,NoOP($[${I}=4])
exten=9002,n,NoOP($[${I}=4 & ${NAME}=FLAVIO])
exten=9002,n,NoOP($[${URI} =~ "4[0-9][0-9][0-9][0-9]@."])
exten=9002,n,NoOP($[${I}=4?"MATCH"::"DO NOT MATCH"])
exten=9002,n,hangup
```

## Funzioni

Alcune applicazioni sono state sostituite da funzioni, che consentono l'elaborazione delle variabili in modo più avanzato rispetto alle sole espressioni. È possibile visualizzare l'elenco completo delle funzioni impartendo il seguente comando da console:

```
*CLI> core show functions
```

Lunghezza stringa: ${LEN(string)} restituisce la lunghezza della stringa

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

Nella prima operazione, il sistema mostra 5 come risultato (il numero di lettere nella parola “fruit”). La seconda restituisce il numero 4 (il numero di lettere nella parola “pear”). Sottostringhe: Restituisce la sottostringa, a partire dalla posizione definita dal parametro “offset”, con la lunghezza della stringa definita nel parametro “length”. Se l'offset è negativo, inizia da destra verso sinistra, partendo dalla fine della stringa. Se la lunghezza viene omessa o è negativa, prende l'intera stringa a partire dall'offset.

```
${string:offset:length }
```

Esempio #1: Diverse sottostringhe

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

Esempio #2: Prendi il prefisso dalle prime tre cifre.

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

Esempio #3: Prende tutte le cifre dalla variabile ${EXTEN}, eccetto il prefisso.

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### Concatenazione di stringhe

Per concatenare due stringhe, è sufficiente scriverle insieme.

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Applicazioni

Per costruire un dialplan, dobbiamo comprendere il concetto di applicazioni. Utilizzerai le applicazioni per gestire il canale nel dialplan. Le applicazioni sono implementate in diversi moduli. Le applicazioni disponibili dipendono dai moduli. Puoi visualizzare tutte le applicazioni di Asterisk utilizzando il comando della console:

```
*CLI> core show applications
```

In alternativa, puoi visualizzare i dettagli di una specifica applicazione utilizzando il seguente esempio:

```
*CLI> core show application Dial
```

Per costruire un semplice dialplan, devi conoscere alcune applicazioni. Discuteremo esempi più avanzati più avanti nel libro.

![La manciata di applicazioni necessarie per costruire un semplice dialplan: Answer (risponde a un canale), Dial (chiama un altro canale), Hangup (chiude un canale), Playback (riproduce un file audio) e Goto (salta a una priorità, extension o context).](../images/04-first-pbx-fig09.png)

Utilizzeremo queste applicazioni (sopra) per creare un semplice dialplan per due PBX di base.

### Answer()

[Sinossi] Risponde a un canale se sta squillando [Descrizione] Answer([delay]): Se la chiamata non ha ancora ricevuto risposta, l'applicazione risponderà. Altrimenti, non ha alcun effetto sulla chiamata. Se viene specificato un ritardo, Asterisk attenderà il numero di millisecondi specificato in ‘delay’ prima di rispondere alla chiamata.

### Dial()

La seguente descrizione può essere ottenuta eseguendo show application dial nel dialplan. Per facilitarne la ricerca, viene riprodotta di seguito. Anche la sintassi per l'applicazione Dial è mostrata di seguito:

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

Questa applicazione effettuerà chiamate verso uno o più canali specificati. Non appena uno dei canali richiesti risponde, al canale chiamante verrà data risposta, se non lo ha già fatto. Questi due canali saranno quindi attivi in una chiamata in bridge. Tutti gli altri canali richiesti verranno quindi chiusi. A meno che non venga specificato un timeout, l'applicazione Dial attenderà indefinitamente finché uno dei canali chiamati non risponde, l'utente riaggancia o tutti i canali chiamati sono occupati o non disponibili. L'esecuzione del dialplan continuerà se nessun canale richiesto può essere chiamato o se il timeout scade. Questa applicazione imposta le seguenti variabili di canale al completamento:

- DIALEDTIME - Questo è il tempo trascorso dalla composizione di un canale fino al momento in cui viene disconnesso.
- ANSWEREDTIME - Questa è la durata effettiva della chiamata.
- DIALSTATUS - Questo è lo stato della chiamata: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

Per le modalità Privacy e Screening, la variabile DIALSTATUS verrà impostata su DONTCALL se la parte chiamata sceglie di inviare la parte chiamante allo script 'Go Away'. La variabile DIALSTATUS verrà impostata su TORTURE se la parte chiamata desidera inviare il chiamante allo script 'torture'. Questa applicazione segnalerà una terminazione normale se il canale chiamante riaggancia o se la chiamata è in bridge e una delle parti nel bridge termina la chiamata. L'URL opzionale verrà inviato alla parte chiamata se il canale lo supporta. Se la variabile OUTBOUND_GROUP è impostata, tutti i canali peer creati da questa applicazione saranno inclusi in quel gruppo (come in

```
Set(GROUP()=...).
```

La seguente tabella riassume alcune delle opzioni utilizzate più frequentemente per l'applicazione Dial. Per l'elenco completo, utilizza il comando della console `core show application Dial`. In Asterisk 22 queste opzioni sono separate dal canale e dal timeout da virgole — ad esempio `Dial(PJSIP/2000,20,tTm)`.

| Opzione | Descrizione |
|--------|-------------|
| `A(x)` | Riproduce un annuncio alla parte chiamata, utilizzando `x` come file. |
| `C` | Reimposta il CDR per questa chiamata. |
| `d` | Consente all'utente chiamante di comporre un'extension a 1 cifra mentre attende che la chiamata riceva risposta. Esce verso quell'extension se esiste nel context corrente, o verso il context definito nella variabile `EXITCONTEXT`, se esiste. |
| `D([called][:calling])` | Invia le stringhe DTMF specificate dopo che la parte chiamata ha risposto, ma prima che la chiamata venga messa in bridge. La stringa `called` viene inviata alla parte chiamata e la stringa `calling` alla parte chiamante. Entrambi i parametri possono essere utilizzati da soli. |
| `f` | Forza il caller ID del canale chiamante a essere impostato sull'extension associata al canale tramite un `hint` del dialplan. Utile dove la PSTN non consente un caller ID arbitrario. |
| `g` | Procede con l'esecuzione del dialplan all'extension corrente se il canale di destinazione riaggancia. |
| `G(context^exten^pri)` | Se la chiamata riceve risposta, trasferisce la parte chiamante alla priorità specificata e la parte chiamata alla priorità+1. Opzionalmente può essere specificata un'extension (o extension e context); altrimenti viene utilizzata l'extension corrente. |
| `h` | Consente alla parte chiamata di riagganciare inviando la cifra DTMF `*`. |
| `H` | Consente alla parte chiamante di riagganciare inviando la cifra DTMF `*`. |
| `L(x[:y][:z])` | Limita la chiamata a `x` ms, riproduce un avviso quando mancano `y` ms e ripete l'avviso ogni `z` ms. Vedi le variabili `LIMIT_*` di seguito. |
| `m([class])` | Fornisce musica d'attesa alla parte chiamante finché il canale richiesto non risponde. Può essere specificata una classe MusicOnHold specifica. |
| `r` | Indica lo squillo alla parte chiamante e non trasmette alcun audio finché il canale chiamato non risponde. |
| `S(x)` | Chiude la chiamata `x` secondi dopo che la parte chiamata ha risposto. |
| `t` | Consente alla parte chiamata di trasferire la parte chiamante inviando la sequenza DTMF definita in `features.conf`. |
| `T` | Consente alla parte chiamante di trasferire la parte chiamata inviando la sequenza DTMF definita in `features.conf`. |
| `w` | Consente alla parte chiamata di abilitare la registrazione one-touch inviando la sequenza DTMF definita in `features.conf`. |
| `W` | Consente alla parte chiamante di abilitare la registrazione one-touch inviando la sequenza DTMF definita in `features.conf`. |
| `k` | Consente alla parte chiamata di parcheggiare la chiamata inviando la sequenza DTMF definita per il parcheggio di chiamata in `features.conf`. |
| `K` | Consente alla parte chiamante di parcheggiare la chiamata inviando la sequenza DTMF definita per il parcheggio di chiamata in `features.conf`. |

L'opzione `L(x[:y][:z])` può essere regolata con le seguenti variabili speciali:

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no` (predefinito `yes`): riproduce suoni per il chiamante.
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no`: riproduce suoni per la parte chiamata.
- `LIMIT_TIMEOUT_FILE` — file da riprodurre quando il tempo è scaduto.
- `LIMIT_CONNECT_FILE` — file da riprodurre quando inizia la chiamata.
- `LIMIT_WARNING_FILE` — file da riprodurre come avviso quando `y` è definito. Il valore predefinito è pronunciare il tempo rimanente.

Esempio:

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

Nell'esempio sopra, l'applicazione chiamerà il canale PJSIP corrispondente. Sia il chiamante che il chiamato potrebbero trasferire la chiamata (Tt). Si sentirà la musica d'attesa invece del tono di ritorno di chiamata. Se nessuno risponde entro 20 secondi, l'extension passerà alla priorità successiva.

### Hangup()

Chiude il canale chiamante [Descrizione] Hangup([causecode]): Questa applicazione chiuderà il canale chiamante. Se viene fornito un codice di causa, la causa di chiusura del canale verrà impostata sul valore fornito.

### Goto()

Salta a una particolare priorità, extension o context [Descrizione] Goto([[context|]extension|]priority): Questa applicazione farà sì che il canale chiamante continui l'esecuzione del dialplan alla priorità specificata. Se non vengono specificate un'extension (o extension e context) specifica, questa applicazione salterà alla priorità specificata dell'extension corrente. Se il tentativo di saltare in un'altra posizione nel dialplan non ha successo, il canale continuerà alla priorità successiva dell'extension corrente.

## Costruzione di un dialplan

Per costruire un semplice dialplan, è necessario gestire tutte le chiamate in entrata e in uscita creando context ed extension. In questa sezione, mostreremo come costruire le extension più comuni.

### Chiamate tra extension

Per abilitare le chiamate tra extension, potremmo usare la variabile di canale ${EXTEN}, che si riferisce all'extension chiamata. Ad esempio, se l'intervallo delle extension è compreso tra 4000 e 4999 e tutte le extension utilizzano SIP, potremmo adottare il seguente comando:

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### Chiamate verso una destinazione esterna

Per chiamare una destinazione esterna è possibile far precedere il numero composto da un prefisso di instradamento. In Nord America, è comune usare 9 seguito dal numero da chiamare esternamente. Se si utilizza un canale analogico o digitale verso la PSTN, il comando dovrebbe apparire come segue: Se si desidera utilizzare il trunk SIP invece di DAHDI, utilizzare il canale `PJSIP/...@siptrunk`.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

La riga precedente ti permetterà di comporre il 9 e il numero desiderato. Nell'esempio fornito, utilizzerai il primo canale DAHDI (DAHDI/1). Se hai diverse linee e questa è occupata, la chiamata non verrà completata. Tuttavia, potresti utilizzare la riga seguente per scegliere automaticamente il primo canale DAHDI disponibile. Facoltativamente, è possibile utilizzare il trunk SIP invece di DAHDI. Nel formato PJSIP `Dial(PJSIP/number@siptrunk,...)`, il numero chiamato è la parte utente e `siptrunk` è l'endpoint configurato in precedenza.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

Il parametro “g1” cercherà il primo canale disponibile nel gruppo, consentendo l'uso di tutti i canali. Utilizzando la riga sottostante, potresti comporre un numero interurbano.

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### Comporre 9 per ottenere una linea PSTN

Se non hai restrizioni per le chiamate esterne, potresti semplificare e utilizzare quanto segue:

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### Ricevere una chiamata sull'extension dell'operatore

Nell'esempio seguente, l'extension dell'operatore è 4000. La linea PSTN è collegata a un'interfaccia FXO. Nel file chan_dahdi.conf, il context specificato è from-pstn. Qualsiasi chiamata proveniente dalla PSTN verrà instradata verso il context from-pstn nel dialplan. Questa linea non dispone di direct inward dialing (DID); pertanto, dovremo ricevere la chiamata tramite l'extension “s”. Se si riceve dal trunk SIP, utilizzare il context [from-sip].

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
[from-sip]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
```

### Ricevere una chiamata utilizzando il direct inward dialing (DID)

Se disponi di una linea digitale, riceverai l'extension chiamata. Quando questo è il caso, non è necessario inoltrare la chiamata all'operatore; piuttosto, puoi inoltrare la chiamata direttamente alla destinazione. Supponiamo che il tuo intervallo DID vada da 3028550 a 3028599 e che le ultime quattro cifre vengano passate nel DID. La configurazione apparirebbe come nell'esempio seguente:

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### Far squillare diverse extension contemporaneamente

Puoi impostare Asterisk per chiamare un'extension e, se non riceve risposta, chiamarne diverse altre contemporaneamente, come indicato nell'esempio seguente:

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

In questo esempio, quando qualcuno chiama l'operatore, viene inizialmente tentato il canale DAHDI/1. Se nessuno risponde dopo 15 secondi (timeout), i canali DAHDI/1, DAHDI/2 e DAHDI/3 squilleranno contemporaneamente per altri 15 secondi.

### Instradamento tramite Caller ID

In questo esempio, potresti fornire trattamenti diversi in base al Caller ID, il che potrebbe essere utile per gli spammer telefonici. Ad esempio:

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

In questo esempio, abbiamo aggiunto una regola speciale che, se il Caller ID è 4832518888, riproduce un messaggio dal file precedentemente registrato “I-have-moved-to-china”. Le altre chiamate vengono accettate come di consueto.

### Utilizzo di variabili nel dialplan

Asterisk può utilizzare variabili globali e di canale nel dialplan come argomenti per determinate applicazioni. Guarda i seguenti esempi:

```
[globals]
Flavio => DAHDI/1
Daniel => DAHDI/2&PJSIP/pingtel
Anna => DAHDI/3
Christian => DAHDI/4
[mainmenu]
exten => 1,1,Dial(${Daniel}&${Flavio})
exten => 2,1,Dial(${Anna}&${Christian})
exten => 3,1,Dial(${Anna}&${Flavio})
```

L'uso delle variabili rende più facili le modifiche future. Se modifichi la variabile, tutti i riferimenti vengono modificati immediatamente.

### Registrazione di un annuncio

In alcune delle opzioni discusse più avanti in questa sezione, utilizzeremo messaggi registrati. Qui ti mostriamo un modo semplice per registrarli. Utilizzeremo l'applicazione Record() per salvare l'annuncio utilizzando il proprio telefono.

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

Queste istruzioni ti consentono di registrare qualsiasi messaggio da un softphone. Esempio: componendo recordmenu dal softphone, le istruzioni chiameranno la registrazione con la variabile ${EXTEN:6} senza le prime sei lettere. In altre parole, l'istruzione è equivalente a record(menu:gsm). Tutto quello che devi fare è comporre record + nome_del_file_da_registrare, premere # per terminare la registrazione e attendere di ascoltare la registrazione.

### Ricevere le chiamate in un centralino digitale

Ora che abbiamo alcuni esempi semplici, espandiamo la nostra conoscenza sulle applicazioni background() e goto(). La chiave per i sistemi interattivi in Asterisk è l'applicazione background(), che consente di eseguire un file audio che, quando il chiamante preme un tasto, viene interrotto per inviare la chiamata all'extension composta. Sintassi dell'applicazione background():

```
exten=>extension, priority, background(filename)
```

Un'altra applicazione molto utile è goto(). Come suggerisce il nome, salta al context, all'extension e alla priorità indicati. Sintassi dell'applicazione goto():

```
exten=>extension, priority,goto(context, extension, priority)
```

Formati validi per il comando goto():

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

Nell'esempio seguente, creeremo un centralino digitale. È molto semplice modificare il file extensions.conf e configurare le seguenti extension:

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
include=aapstn
[from-sip]
include=aasip
[aapstn]
exten=>s,1,answer()
exten=>s,n,set(TIMEOUT(response)=10)
exten=>s,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>s,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
[aasip]
exten=>9999,1,answer()
exten=>9999,n,set(TIMEOUT(response)=10)
exten=>9999,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>9999,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
```

Le extension SIP utilizzano `PJSIP/` e le extension IAX utilizzano `IAX2/` — entrambi i driver sono inclusi in Asterisk 22, sebbene `chan_iax2` sia ora considerato legacy e SIP/PJSIP sia preferito.

Nel file menu1.gsm, registra il messaggio “premi l'extension o attendi l'operatore”. Quando l'utente compone il numero 6000, verrà inviato all'extension 6000. A questo punto, dovresti avere una chiara comprensione dell'uso di diverse applicazioni, tra cui answer(), background(), goto(), hangup() e playback(). Se non hai una chiara comprensione, ti preghiamo di rileggere questo capitolo finché non ti sentirai a tuo agio con il contenuto. Utilizzerai l'applicazione background molto spesso. Una volta compresi i concetti di base di extension, priorità e applicazioni, sarà facile creare un semplice dialplan. Questi concetti saranno esplorati più approfonditamente più avanti nel libro e vedrai che il dialplan diventerà più potente.

## Riepilogo

In questo capitolo, hai imparato che i file di configurazione sono memorizzati nella directory /etc/asterisk. Per utilizzare Asterisk, è innanzitutto necessario configurare i canali (ad esempio, pjsip, dahdi, iax). Esistono tre diverse grammatiche per i file di configurazione: gruppo semplice, ereditarietà degli oggetti ed entità complessa. Il dialplan viene creato nel file extensions.conf ed è un insieme di context ed extension. Nel dialplan, ogni extension attiva un'applicazione. Hai imparato a utilizzare le applicazioni playback, background, dial, goto, hangup e answer.

## Quiz

1. I file di configurazione dei canali sono (scegliere tutte le opzioni applicabili):
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. Su Asterisk 22, il singolo peer `chan_sip` `[6001]` (`type=friend`/`host=dynamic`) viene sostituito in `pjsip.conf` da quale insieme di oggetti correlati?
   - A. Un `type=peer` e un `type=user`
   - B. Un `type=endpoint`, un `type=auth` e un `type=aor`
   - C. Un singolo `type=friend`
   - D. Un `type=transport` e un `type=global`
3. Definire un context nel file di configurazione del canale è importante perché imposta il context in entrata per le chiamate provenienti da quel canale — una chiamata dal canale viene elaborata nel context corrispondente in `extensions.conf`.
   - A. Vero
   - B. Falso
4. Le differenze principali tra le applicazioni `Playback()` e `Background()` sono (sceglierne due):
   - A. Playback riproduce un messaggio ma non attende l'inserimento di cifre.
   - B. Background riproduce un messaggio ma non attende l'inserimento di cifre.
   - C. Background riproduce un messaggio e attende la pressione di cifre.
   - D. Playback riproduce un messaggio e attende la pressione di cifre.
5. Quando una chiamata entra in Asterisk attraverso una scheda di interfaccia telefonica (FXO) senza DID, viene gestita nell'extension speciale:
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. I formati validi per l'applicazione `Goto()` sono (sceglierne tre):
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. Il pattern `_7[1-5]XX` corrisponde a (scegliere tutte le opzioni applicabili):
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. In `Dial(PJSIP/${EXTEN},20,tTm)`, cosa fa l'opzione `m`?
   - A. Limita la chiamata a una durata massima.
   - B. Fornisce musica d'attesa al chiamante invece del segnale di libero fino a quando il canale non risponde.
   - C. Invia cifre DTMF dopo che la parte chiamata risponde.
   - D. Forza il caller ID utilizzando un hint del dialplan.
9. Nella grammatica di ereditarietà delle opzioni utilizzata da `chan_dahdi.conf`, si deve:
   - A. Definire l'oggetto in una singola riga.
   - B. Definire le opzioni per prime e dichiarare gli oggetti sotto le opzioni definite.
   - C. Definire un context separato per ogni oggetto.
10. Le priorità in un'extension devono essere numerate consecutivamente (1, 2, 3, …) e non possono utilizzare `n`.
    - A. Vero
    - B. Falso

**Risposte:** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
