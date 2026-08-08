# SIP & PJSIP in profondità

SIP è il protocollo; PJSIP è il modo in cui Asterisk 22 lo parla. **PJSIP** (`chan_pjsip`, configurato tramite `pjsip.conf`) è l'unico driver di canale SIP in Asterisk 22 LTS. Questo capitolo copre i fondamenti del protocollo SIP (che sono a livello di protocollo e rimangono validi al 100%) e il modello a oggetti e la configurazione di PJSIP che utilizzi ogni giorno. Il driver legacy ritirato e una guida alla migrazione sono trattati nel capitolo *Legacy channels*.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Spiegare il ruolo dei SIP user agent, proxy, registrar e gateway;
- Seguire un flusso di chiamata SIP di base (REGISTER, INVITE, risposte provvisorie e finali, ACK, BYE) e leggere un messaggio SIP;
- Descrivere come SDP negozia la sessione multimediale e come il NAT influisce sulla segnalazione SIP e sul traffico RTP;
- Mappare il modello a oggetti di PJSIP — `endpoint`, `auth`, `aor`, `transport`, `identify` e `registration` — e come gli oggetti si riferiscono l'uno all'altro;
- Configurare telefoni SIP e trunk in `pjsip.conf`, incluse le opzioni per l'attraversamento NAT; e
- Verificare e risolvere i problemi degli endpoint con i comandi CLI `pjsip show …`.

## Fondamenti del protocollo SIP

Il Session Initiation Protocol (SIP) è un protocollo basato su testo, simile a HTTP e SMTP, progettato per inizializzare, mantenere e terminare sessioni di comunicazione interattiva tra utenti. Queste sessioni possono includere voce, video, chat, giochi interattivi e altro. SIP è stato definito dall'IETF ed è diventato lo standard de facto per le comunicazioni vocali. È molto importante comprendere come funziona SIP. Su Asterisk 22, la configurazione SIP risiede in `pjsip.conf`, che è uno dei file modificati più frequentemente su un sistema basato su SIP (subito dopo `extensions.conf`).

### Teoria del funzionamento

SIP è un protocollo di segnalazione con i seguenti componenti: User Agent Client, User Agent Server, SIP Proxy e SIP Gateway. La figura seguente illustra le relazioni tra questi componenti.

- UAC (user agent client) – Il client o terminale che inizializza la segnalazione SIP.
- UAS (user agent server) – Il server che risponde a una segnalazione SIP proveniente da un UAC.
- UA (user agent) – Il terminale SIP (telefoni o gateway che contengono sia UAC che UAS).
- Proxy Server – Riceve le richieste da un UA e le trasferisce ad altri SIP Proxy se la stazione specifica non è sotto la loro amministrazione.
- Redirect Server – Riceve le richieste e le invia nuovamente all'UA, includendo i dati di destinazione, invece di inoltrarle direttamente alla destinazione.
- Location Server – Riceve le richieste da un UA e aggiorna il database di localizzazione con queste informazioni.

Solitamente, i server proxy, di reindirizzamento e di localizzazione sono ospitati sullo stesso hardware e utilizzano lo stesso software, che chiamiamo SIP proxy. Il SIP proxy è responsabile della manutenzione del database di localizzazione, dello stabilimento della connessione e della terminazione della sessione.

![I componenti SIP principali: user agent (UAC/UAS/UA), il server registrar/proxy/redirect e un gateway verso la PSTN, con il flusso multimediale RTP che transita direttamente tra gli endpoint](../images/07-sip-and-pjsip-fig01.png)

#### Processo di registrazione SIP

Prima che un telefono possa ricevere chiamate, deve essere registrato in un database di localizzazione. Nel database di localizzazione, l'indirizzo IP verrà associato al nome. Nell'esempio seguente, l'extension 8500 verrà associata all'indirizzo IP 200.180.1.1. Non è necessario utilizzare numeri di telefono. Nell'architettura SIP, l'extension registrata potrebbe essere anche flavio@voip.school.

![Registrazione SIP: il telefono invia un REGISTER associando l'extension 8500 al proprio indirizzo IP, il registrar memorizza il contatto nel database di localizzazione e risponde con 200 OK](../images/07-sip-and-pjsip-fig02.png)

#### Funzionamento del proxy

Quando opera come SIP proxy, il server SIP rimane al centro della segnalazione ed è in grado di gestire routing e fatturazione avanzati. Il flusso multimediale, basato sul real time protocol (RTP), transita comunque direttamente tra gli endpoint.

![Funzionamento del proxy: il SIP proxy rimane nel percorso di segnalazione (INVITE/200 OK) e cerca il destinatario nel location server, mentre il flusso multimediale RTP transita direttamente tra i due endpoint](../images/07-sip-and-pjsip-fig03.png)

#### Funzionamento del redirect

Durante il reindirizzamento, il server SIP invia semplicemente un messaggio (ad esempio, 302 moved temporarily) all'user agent e rimane fuori dal percorso dei nuovi messaggi. È molto leggero in termini di utilizzo delle risorse, ma non si ha alcun controllo. Il reindirizzamento viene talvolta utilizzato in progetti di bilanciamento del carico.

![Funzionamento del redirect: il redirect server risponde all'INVITE con un 302 Moved Temporarily contenente il contatto, quindi si fa da parte mentre il chiamante invia nuovamente INVITE/ACK direttamente alla nuova posizione](../images/07-sip-and-pjsip-fig04.png)

#### Come Asterisk gestisce SIP

È importante capire che Asterisk non è né un SIP proxy né un SIP redirector. Asterisk può svolgere il ruolo di registrar e location server; tuttavia, collega a sé stesso solo due UAC. Pertanto, Asterisk è considerato un back-to-back user agent (B2BUA). In altre parole, collega due canali SIP, mettendoli in comunicazione. Asterisk dispone di un meccanismo di re-invite che può far comunicare i canali SIP direttamente tra loro invece di passare attraverso Asterisk. Su un endpoint PJSIP, questo è controllato dal parametro `direct_media`. Quando si utilizza `direct_media=yes`, il flusso RTP transita direttamente da un endpoint all'altro, liberando risorse del server.

#### Funzionamento SIP con direct_media=yes

![Funzionamento SIP con directmedia=yes: la segnalazione SIP transita attraverso Asterisk mentre l'audio RTP transita direttamente tra i due telefoni, liberando risorse del server](../images/07-sip-and-pjsip-fig05.png)

Tuttavia, se è necessario trasferire o registrare la chiamata utilizzando Asterisk, è possibile utilizzare il parametro `direct_media=no` per forzare il flusso RTP attraverso il server Asterisk.

#### Funzionamento SIP con direct_media=no

![Funzionamento SIP con directmedia=no: sia la segnalazione SIP che l'audio RTP sono ancorati ad Asterisk, consentendogli di registrare, transcodificare o trasferire la chiamata](../images/07-sip-and-pjsip-fig06.png)

#### Messaggi SIP

I messaggi SIP di base sono:

- INVITE – stabilimento della connessione
- ACK – conferma
- BYE – terminazione della connessione
- CANCEL – terminazione della connessione per una chiamata non stabilita
- REGISTER – registrazione di un UAC presso un SIP proxy
- OPTIONS – può essere utilizzato per verificare la disponibilità
- REFER – trasferimento di una chiamata SIP a qualcun altro
- SUBSCRIBE – sottoscrizione a eventi di notifica
- NOTIFY – invio di informazioni sul canale
- INFO – invio di vari messaggi (ad esempio, DTMF)
- MESSAGE – invio di messaggi istantanei

Le risposte SIP sono in formato testo e sono facilmente leggibili (simili ai messaggi HTTP). Le risposte più importanti sono:

- 1XX – Messaggi informativi (100–trying, 180–ringing, 183–progress)
- 2XX – Richiesta completata con successo (200 – OK)
- 3XX – Reindirizzamento chiamata, la richiesta deve essere diretta altrove (302 – moved temporarily, 305 – use proxy)
- 4XX – Errore (403 – Forbidden)
- 5XX – Errore del server (500 – Internal Server Error; 501 – Not implemented)
- 6XX – Fallimento globale (606 – Not acceptable)

Per esempio:

```
INVITE sip:2000@192.168.1.133 SIP/2.0
Via: SIP/2.0/UDP
192.168.1.116;rport;branch=z9hG4bKc0a8017400000063452fafbb00006967000000d2
From: "unknown"<sip:2001@192.168.1.133>;tag=1556140623845
To: <sip:2000@192.168.1.133>
Contact: <sip:2001@192.168.1.116>
Call-ID: 64B4C8EC-FCFC-49E9-98B1-90982EEEBED3@192.168.1.116
CSeq: 2 INVITE
Max-Forwards: 70
User-Agent: SJphone/1.61.312b (SJ Labs)
Content-Length: 335
Content-Type: application/sdp
Proxy-Authorization: Digest
username="2001",realm="asterisk",nonce="6c55905e",uri="sip:2000@192.168.1.133",
response="983c0099eea125d8cdfe93b0ec99f3ec",algorithm=MD5
```

#### Session description protocol (SDP)

SDP è stato originariamente definito nell'IETF RFC 2327, ora sostituito dall'RFC 4566. È destinato alla descrizione di sessioni multimediali per scopi di annuncio di sessione, invito a sessione e altre forme di inizializzazione di sessioni multimediali. SDP include:

- Protocollo di trasporto (RTP/UDP/IP)
- Tipo di media (testo, audio, video)
- Formato multimediale o codec (video H.261, audio g.711, ecc.)
- Informazioni necessarie per ricevere questi media (indirizzi, porte, ecc.)

L'esempio seguente è una trascrizione di un SDP che descrive una chiamata tra due telefoni.

```
v=0
o=- 3369741883 3369741883 IN IP4 192.168.1.116
s=SJphone
c=IN IP4 192.168.1.116
t=0 0
a=setup:active
m=audio 49160 RTP/AVP 3 97 98 8 0 101
a=rtpmap:3 GSM/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11,16
```

### Attraversamento NAT SIP

Il Network Address Translation (NAT) è una funzionalità utilizzata dalla maggior parte delle reti per risparmiare indirizzi IP Internet. Solitamente, un'azienda riceve un piccolo blocco di indirizzi IP e gli utenti finali ricevono un indirizzo IP dinamicamente quando si connettono a Internet. Il NAT risolve il problema dell'indirizzamento mappando gli indirizzi interni su indirizzi esterni. Memorizza una mappatura degli indirizzi interni verso quelli esterni nella sua memoria. Questa mappatura è valida per un periodo di tempo specifico, dopodiché viene eliminata. La mappatura utilizza coppie IP:porta per gli indirizzi interni ed esterni. Esistono quattro tipi di NAT:

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

La teoria NAT sottostante — i quattro tipi di NAT, il problema dell'header Contact, i keep-alive e la forzatura dei media attraverso il server — è a livello di protocollo e si applica a qualsiasi implementazione SIP. Il modo in cui si configura ciascun comportamento su Asterisk 22 (PJSIP) è trattato più avanti in questo capitolo sotto *Nat traversal on res_pjsip*.

#### Full Cone

Il primo NAT, full cone, rappresenta una mappatura statica da una coppia IP:porta esterna a una coppia IP:porta interna. Qualsiasi computer esterno può connettersi ad esso utilizzando la coppia IP:porta esterna. Questo è il caso dei firewall non stateful implementati con l'uso di filtri.

![Full Cone NAT: l'host interno (10.0.0.1:8000) è mappato staticamente sulla coppia esterna 200.180.4.168:1234, quindi qualsiasi computer esterno può inviare pacchetti a quella coppia e raggiungere l'host interno](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

Nello scenario restricted cone, la coppia IP:porta esterna viene aperta solo quando il computer interno invia dati a un indirizzo esterno. Tuttavia, il NAT restricted cone blocca tutti i pacchetti in entrata provenienti da un indirizzo diverso. In altre parole, il computer interno deve inviare dati a un computer esterno prima di poter ricevere dati indietro.

#### Port Restricted Cone

Il firewall port restricted cone è quasi identico al restricted cone. L'unica differenza è che, ora, il pacchetto in entrata deve provenire esattamente dallo stesso IP e dalla stessa porta del pacchetto inviato.

#### Symmetric

L'ultimo tipo di NAT è chiamato symmetric. Si differenzia dai primi tre in quanto viene effettuata una mappatura specifica per ogni indirizzo esterno. Solo indirizzi esterni specifici possono tornare indietro tramite la mappatura NAT. Non è possibile prevedere la coppia IP:porta esterna che verrà utilizzata dal dispositivo NAT. Gli altri tre tipi di NAT consentono l'uso di un server esterno per scoprire l'indirizzo IP esterno per la comunicazione. Con il NAT symmetric, anche se è possibile connettersi a un server esterno, l'indirizzo scoperto non può essere utilizzato per nessun altro dispositivo eccetto questo server.

![Symmetric NAT: viene allocata una porta sorgente esterna diversa per ogni destinazione, quindi la mappatura scoperta verso un server non può essere riutilizzata da un altro host, il che interrompe l'attraversamento basato su STUN](../images/07-sip-and-pjsip-fig12.png)

#### Tabella firewall NAT

La tabella seguente riassume i quattro tipi di NAT.

| Tipo di NAT | Deve inviare dati per primo | Può determinare l'IP:porta esterno per i pacchetti di ritorno | Limita i pacchetti in entrata all'IP:porta di destinazione |
| --- | --- | --- | --- |
| Full Cone | No | Sì | No |
| Restricted Cone | Sì | Sì | Solo IP |
| Port Restricted Cone | Sì | Sì | Sì |
| Symmetric | Sì | No | Sì |

#### Segnalazione SIP e RTP su NAT

Alcuni dei problemi più grandi nell'attraversamento NAT sono legati alla risoluzione di due problemi: segnalazione SIP e audio (RTP). La maggior parte dei problemi di audio unidirezionale è correlata al NAT. Una cosa interessante di SIP è che, quando un UAC invia un pacchetto, incorpora l'indirizzo IP nel campo header SIP "Contact". Solitamente si tratta di un indirizzo interno (RFC1918); le risposte a questo pacchetto non possono essere instradate su Internet verso l'UAC. Le soluzioni concettuali sono sempre le stesse:

- **Ignorare l'indirizzo Contact/Via e rispondere da dove è effettivamente arrivato il pacchetto.** Questo è il comportamento definito nell'RFC 3581 (`rport`). Su PJSIP è `force_rport=yes`, e `rewrite_contact=yes` riscrive il contatto memorizzato sull'indirizzo sorgente.
- **Inviare i media all'indirizzo da cui è effettivamente arrivato l'RTP** (RTP simmetrico, storicamente chiamato *comedia*). Su PJSIP questo è `rtp_symmetric=yes`.
- **Mantenere aperta la mappatura NAT.** Se la mappatura scade, Asterisk non può più inviare un INVITE all'UAC — il telefono può effettuare chiamate ma non riceverle. L'invio di un OPTIONS periodico (un *qualify*) mantiene aperto il "buco" nel firewall. Su PJSIP questo è `qualify_frequency=` sull'AOR.

Se il NAT dell'utente è di tipo symmetric, non è possibile inviare pacchetti direttamente da un UAC all'altro; in tal caso è necessario forzare l'RTP attraverso Asterisk con `direct_media=no`. Queste configurazioni sono appropriate per la maggior parte dei casi. È possibile ottimizzare il traffico utilizzando tecniche avanzate come Simple Traversal of UDP over NAT (STUN), utile con full cone, restricted cone e port restricted cone, e Application Layer Gateway (ALG). Sfortunatamente, la maggior parte dei firewall odierni — anche i router DSL/cavo domestici — sono symmetric, rendendo STUN inutilizzabile. L'ALG potrebbe risolvere il problema, ma nella maggior parte dei casi non è supportato, non è implementato o presenta bug.

#### Asterisk dietro NAT

A volte il server Asterisk stesso è implementato dietro un firewall con NAT — una situazione molto comune quando si effettua il deployment nel cloud. In questo caso è necessaria una configurazione aggiuntiva affinché Asterisk pubblichi il suo indirizzo **pubblico** negli header SIP e SDP invece di quello privato.

Concettualmente ci sono tre passaggi:

- Inoltrare la porta di segnalazione SIP (UDP 5060 per impostazione predefinita) dal firewall al server Asterisk.
- Inoltrare l'intervallo di porte multimediali RTP (UDP 10000–20000 per impostazione predefinita, impostato in `rtp.conf`) dal firewall al server Asterisk.
- Comunicare ad Asterisk il suo indirizzo esterno e quale rete è locale, in modo che sappia quando sostituire l'indirizzo pubblico negli header.

Su PJSIP questi ultimi due elementi corrispondono a `external_media_address` / `external_signaling_address` e `local_net=` sul **transport**, e l'intervallo di porte RTP è ancora configurato in `rtp.conf`:

```
; RTP Configuration
;
[general]
;
; RTP start and RTP end configure start and end addresses
;
rtpstart=10000
rtpend=20000
```

La configurazione PJSIP completa e funzionante per un server Asterisk dietro NAT è fornita più avanti in questo capitolo sotto *Asterisk Server behind NAT*.

### Limitazioni SIP

Asterisk utilizza il flusso RTP in entrata per sincronizzare il flusso in uscita. Se il flusso in entrata viene interrotto (soppressione del silenzio), la musica d'attesa verrà interrotta. In altre parole, non si dovrebbe utilizzare la soppressione del silenzio nei telefoni o nei provider con Asterisk.

## PJSIP: il canale SIP

PJSIP è il canale SIP in Asterisk. È stato introdotto per la prima volta in Asterisk 12 e, dopo anni di sviluppo, è diventato il canale SIP predefinito e raccomandato; in Asterisk 22 (l'attuale LTS) è l'unico driver per il canale SIP. PJSIP si basa sul progetto di Teluu chiamato pjproject. Lo stack pjproject è utilizzato da molti softphone e implementazioni SIP commerciali. Si tratta di uno stack SIP versatile e maturo.

### Perché usare PJSIP

PJSIP è stato una riprogettazione completa del modo in cui Asterisk gestisce il protocollo SIP, ed è utile comprendere le funzionalità che lo hanno reso lo standard.

#### Funzionalità

Il canale supporta molte funzionalità, alcune delle quali meritano una menzione qui:

- Registrazioni multiple: è possibile utilizzare più di un telefono connesso allo stesso Address of Record. In altre parole, è possibile connettere due telefoni allo stesso endpoint.
- Interfaccia di programmazione dell'applicazione (API) intuitiva. L'API è modulare e facile da estendere, costruita a partire da molti piccoli moduli cooperanti piuttosto che da un unico grande blocco di codice.
- Trasporti multipli: è possibile ascoltare su indirizzi, porte e trasporti multipli quando si utilizza PJSIP. Non si è limitati a un singolo indirizzo di bind per tutti i propri dispositivi. PJSIP è molto flessibile.

#### Una nota sulla configurazione

La configurazione di PJSIP è più prolissa: richiede un po' più di impegno e più righe di configurazione, poiché ogni dispositivo è descritto da diversi oggetti correlati invece che da un unico blocco peer. Quella struttura aggiuntiva è ciò che conferisce a PJSIP la sua flessibilità, e la configurazione guidata (trattata in seguito) mantiene breve il provisioning quotidiano.

### Moduli PJSIP

Il canale PJSIP è implementato da molti moduli descritti di seguito:

#### res_pjsip

Questo è il livello base di PJSIP e il modulo principale. È responsabile di alcuni dei servizi principali.

#### res_pjsip_session

Questo modulo è responsabile delle sessioni multimediali, dell'elaborazione del protocollo di descrizione della sessione (SDP) e di alcuni componenti aggiuntivi.

#### res_pjsip_messaging

Elabora i messaggi SIP e analizza gli header SIP.

#### res_pjsip_registrar

Responsabile della gestione delle registrazioni SIP.

#### res_pjsip_pubsub

Responsabile dell'elaborazione di subscribe, notify e publish. Questi messaggi sono responsabili della gestione della presenza SIP e del BLF (Busy Lamp Field).

### Configurazione PJSIP

PJSIP ha molte sezioni diverse. Il formato della sezione è:

```
[Section Name]
Option = Value
Option = Value
```

#### Sezione End point

L'oggetto di configurazione più importante è l'endpoint. La configurazione dell'endpoint ha funzionalità principali e deve essere associata a una sezione AOR e a una sezione Transport. Esempio:

```
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
```

Se si osserva l'esempio precedente, l'endpoint è una sorta di collante che unisce tutte le sezioni. Specifica un trasporto, l'address of record e l'autenticazione per un telefono. Definisce inoltre la parte più importante, il punto di ingresso del context nel dialplan.

#### Address of Record (AOR)

Questo oggetto indica ad Asterisk dove contattare l'endpoint. Memorizza gli indirizzi di contatto. Consente inoltre la configurazione delle caselle vocali. Esempio:

```
[softphone]
type=aor
max_contacts=2
```

#### Autenticazione

Questa sezione è responsabile dell'autenticazione in entrata e in uscita. La documentazione si trova nel file di esempio pjsip.conf. Esempio:

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### Trasporto

La sezione transport consente di definire indirizzi IPV4 e IPV6 e il protocollo di trasporto, TCP, UDP, TLS, Websockets e così via. In questa sezione è possibile configurare anche indirizzi Natted. È possibile creare trasporti multipli, ma non possono condividere lo stesso IP e porta e non è possibile associare trasporti TCP o TLS multipli della stessa versione IP. Esempio:

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### Registrazione

Questo oggetto viene utilizzato per configurare una registrazione in uscita. Esempio:

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### Identify

Questo oggetto controlla quale richiesta SIP appartiene a ciascun endpoint. Se non si dispone di una sezione identify, il sistema abbinerà il contenuto dell'header "From" con il nome dell'endpoint. Utilizzando questa sezione, è possibile assegnare indirizzi IP specifici a endpoint specifici, identificati da nome utente o IP. Esempio:

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### ACL

L'oggetto ACL consente di configurare reti specifiche con accesso all'endpoint. Ora le ACL sono definite in una sezione specifica o nel file acl.conf. Esempio:

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### Relazione tra le entità

La relazione tra gli oggetti di configurazione offre una grande flessibilità per la configurazione. Tuttavia, sembra un po' complessa per chiunque sia agli inizi.

![Relazioni tra gli oggetti di configurazione PJSIP: l'endpoint si collega a transport, auth e AOR (che contiene i contatti); la registrazione si lega a transport e auth; identify punta all'endpoint, mentre ACL e domain alias sono indipendenti](../images/07-sip-and-pjsip-fig14.png)

Il grafico sopra significa:

#### Relazioni:

| Oggetti | Cardinalità |
| --- | --- |
| ENDPOINT / AOR | molti a molti |
| ENDPOINT / AUTH | da zero a molti, a zero a uno |
| ENDPOINT / IDENTIFY | da zero a uno |
| ENDPOINT / TRANSPORT | da zero a molti, ad almeno uno |
| REGISTRATION / AUTH | da zero a molti, a zero a uno |
| REGISTRATION / TRANSPORT | da zero a molti, ad almeno uno |
| AOR / CONTACT | molti a molti |

ACL e DOMAIN_ALIAS non hanno una relazione di configurazione diretta con gli altri oggetti.

### Configurazione di un Softphone

Per configurare un softphone è necessario definire molte sezioni diverse. Di seguito un esempio su come configurare un softphone. Per il lato client è possibile utilizzare il SipPulse Softphone (https://www.sippulse.com/produtos/softphone), che è possibile scaricare e registrare sull'endpoint sottostante.

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
[softphone]
type=aor
max_contacts=2
```

La configurazione precedente imposta un trasporto per UDP sulla porta 5060, quindi definisce un endpoint, la sua autenticazione tramite nome utente e password e infine l'Address of Record con un massimo di due contatti.

### Configurazione di un trunk SIP

Per configurare un trunk SIP è necessario disporre dell'indirizzo IP o dell'host del trunk SIP, del nome e della password. È necessario creare una nuova sezione di registrazione a questo scopo.

```
[siptrunk]
type=endpoint
transport=transport-udp-main
context=from-siptrunk
direct_media=no
disallow=all
allow=ulaw
outbound_auth=siptrunk
aors=siptrunk
[siptrunk]
type=aor
contact=sip:sip.flagonc.com:5600
[siptrunk]
type=auth
auth_type=digest
username=1020
password=supersecret
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
[siptrunk]
type=identify
endpoint=siptrunk
match=sip.flagonc.com
```

### Attraversamento NAT su res_pjsip

Il Network Address Translation è stato creato molto tempo fa come modo per affrontare la carenza di indirizzi IP versione 4. Molte persone utilizzano il NAT anche come funzionalità di sicurezza, nascondendo gli indirizzi interni di una rete da Internet pubblico. A volte sarà necessario gestire l'attraversamento NAT. In alcuni casi, il server può trovarsi dietro NAT, come quando si distribuisce il server nel cloud. Molte volte, se si distribuisce nel cloud, anche gli utenti si troveranno dietro un router NAT. Per organizzare le cose, divideremo questo argomento in due parti. La prima riguarda il server Asterisk dietro NAT, come in una distribuzione cloud. Nella seconda sezione, tratteremo come supportare i client dietro NAT utilizzando res_pjsip.

#### Server Asterisk dietro NAT

Quando il server Asterisk si trova dietro NAT, è necessario informare gli indirizzi locali esterni e interni nella sezione transport. Avremo le seguenti direttive.

##### direct_media

Il flusso multimediale passa direttamente da peer a peer o attraverso il server? Per il NAT dovrebbe passare attraverso il server. Per il NAT selezionare no. Esempio:

```
direct_media=no
```

##### external_media_address

Indirizzo multimediale per gestire l'RTP esterno. Solitamente è lo stesso dell'external_signaling_address. Utilizzare l'indirizzo IP pubblico del server per i media e la segnalazione. Esempio:

```
external_media_address=54.232.1.20
```

##### external_signaling_address

Indirizzo SIP esterno dove ricevere i messaggi. Esempio:

```
external_signaling_address=54.232.1.20
```

##### local_net

La rete che si considera la propria rete locale. Esempio:

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### Esempio completo di trasporto per un server Asterisk dietro NAT

Per utilizzare un server Asterisk dietro NAT è necessario eseguire due passaggi. Primo, definire un trasporto dietro NAT. Secondo, associare questo trasporto all'endpoint.

##### Creazione del trasporto dietro NAT

Per creare il trasporto dietro NAT nel file pjsip.conf, creare una sezione come quella sottostante.

```
[tnat]
type=transport
protocol=udp
bind=0.0.0.0
local_net=172.16.30.0/24
local_net=127.0.0.1/32
external_media_address=54.232.1.20
external_signaling_address=54.232.1.20
```

Associare il trasporto a un endpoint

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

Per i trunk SIP è necessario associare il trasporto anche alla sezione di registrazione, come di seguito.

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### Utilizzo di Asterisk con client dietro NAT

Per utilizzare telefoni dietro NAT è necessario configurare alcuni parametri aggiuntivi per endpoint.

##### direct_media

Il flusso multimediale passa direttamente da peer a peer o attraverso il server? Per il NAT dovrebbe passare attraverso il server. Esempio:

```
direct_media=no
```

##### rtp_symmetric

Questo è ciò che chiamiamo comedia. Invece di fare affidamento sull'indirizzo definito in questo header SDP come al solito in SIP, utilizzare l'indirizzo da cui si riceve il primo pacchetto RTP e inviare indietro dallo stesso indirizzo. Esempio:

```
rtp_symmetric=yes
```

##### force_rport

Questo è il comportamento definito nella RFC3581. Invece di utilizzare l'indirizzo nell'header VIA, inviare indietro le risposte da dove provengono le richieste. Esempio:

```
force_rport=yes
```

##### qualify_frequency

Questa impostazione deve essere applicata all'AOR (non all'endpoint). C'è anche l'ultimo passaggio, configurare l'opzione qualify. Si dovrebbero sempre avere dei pacchetti che eseguono il ping della destinazione per mantenere aperta la mappatura NAT. Questo è impostato nella sezione AOR. Esempio:

- qualify_frequency=15

Esempio completo di un endpoint in cui il server e il client si trovano dietro NAT

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
force_rport=yes
rtp_symmetric=yes
auth=6000
aors=6000
[6000]
type=aor
qualify_frequency=15
```

### Denominazione dei canali

Come al solito, uno degli aspetti importanti di un canale è la sua denominazione e PJSIP ha alcuni dettagli interessanti. Si chiama un endpoint PJSIP con la tecnologia `PJSIP/`:

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

Una funzionalità utile è la possibilità di chiamare tutti i contatti registrati su un AOR contemporaneamente. La funzione PJSIP_DIAL_CONTACTS verrà tradotta nell'elenco dei contatti da chiamare.

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

Chiamare un trunk è leggermente diverso. Si supponga che il trunk non venga registrato sulla propria piattaforma o non abbia un indirizzo IP associato al proprio Address of Record. È possibile specificare l'indirizzo del trunk direttamente nella riga. Utilizzando una chiamata internazionale come esempio.

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

Se si preferisce specificare l'indirizzo del trunk nella sezione AOR, è possibile utilizzare anche:

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### Configurazione guidata PJSIP

PJSIP è potente ma prolisso da configurare: molte sezioni diverse e modelli che possono confondere all'inizio. La buona notizia è la configurazione guidata PJSIP. Definendo ogni canale in poche righe, consente di creare modelli e semplificare la configurazione di nuovi dispositivi. Utilizzare il file pjsip_wizard.conf per configurare. È comunque necessario definire le sezioni transport e global nel file pjsip.conf. Personalmente, preferisco utilizzare la procedura guidata solo per i telefoni; per i trunk SIP solitamente il numero non è elevato ed è possibile configurare direttamente in pjsip. Il vantaggio maggiore della procedura guidata è la possibilità di utilizzare modelli e creare telefoni rapidamente.

```
[phone_default](!)
type = wizard
accepts_auth = yes
accepts_registrations = yes
transport = tnat
endpoint/allow = ulaw
endpoint/context = from-internal
endpoint/direct_media=no
endpoint/force_rport=yes
endpoint/rtp_symmetric=yes
aor/qualify_frequency=15
[alice](phone_default)
inbound_auth/username = alice
inbound_auth/password = supersecret
[bob](phone_default)
inbound_auth/username = bob
inbound_auth/password = supersecret
```

### Caricamento e scaricamento di PJSIP

PJSIP è l'unico canale SIP in Asterisk 22 e i suoi moduli vengono caricati per impostazione predefinita. In rari casi si potrebbe comunque voler controllare il caricamento dei moduli dal file modules.conf, ad esempio per disabilitare PJSIP su un server che utilizza solo IAX2 o DAHDI.

#### Per disabilitare PJSIP

Modificare il file modules.conf e aggiungere le seguenti righe.

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### Comandi della console

Ora che sono stati configurati gli endpoint PJSIP, è il momento di vedere come verificare la configurazione. Ci sono molti comandi della console per aiutare in questa attività. Dopo aver modificato pjsip.conf, ricaricare la configurazione con:

```
module reload res_pjsip.so
```

Un semplice `reload` (o `core reload`) ricarica tutti i moduli, incluso PJSIP. (Nota: non esiste un comando `pjsip reload` nudo — `pjsip reload` esiste solo nella forma `pjsip reload qualify aor|endpoint`.) È possibile elencare tutti i comandi della console PJSIP disponibili con `help pjsip`.

#### pjsip show endpoints

Questo comando mostra gli endpoint disponibili. Nell'immagine sottostante, abbiamo uno screenshot. È possibile vedere l'indirizzo dell'endpoint softphone e vedere che è disponibile.

![Output di `pjsip show endpoints` che elenca gli endpoint blink, siptrunk e softphone con il loro AOR, auth, transport e disponibilità — il contatto softphone è registrato (Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

Con il comando precedente, è possibile vedere ogni parametro dell'endpoint. L'elenco sottostante è stato tagliato a meno della metà dei parametri correnti.

![Output di `pjsip show endpoint softphone` che mostra l'elenco completo dei parametri per un singolo endpoint, da 100rel e allow=(ulaw) fino a callerid e connected_line_method](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

Questo comando elenca gli oggetti Address of Record configurati e i loro contatti, in modo da poter confermare dove Asterisk invierà le chiamate per ciascun endpoint.

#### pjsip show registrations

Il comando sottostante mostra le registrazioni effettuate dal nostro server.

![Output di `pjsip show registrations`: la registrazione in uscita siptrunk/sip:1020@sip.flagonc.com:5600 viene mostrata con stato Registered](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

Il comando list è un po' più intuitivo e mostra meno dati, ma meglio strutturati. Elenco degli endpoint:

![Output di `pjsip list endpoints`: un elenco compatto di un rigo per endpoint (blink, siptrunk, softphone) con il loro stato e il conteggio dei canali](../images/07-sip-and-pjsip-fig18.png)

Elenco dei contatti:

![Output di `pjsip list contacts` che mostra gli URI dei contatti siptrunk e softphone con il loro hash e lo stato di qualify](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

Il comando di risoluzione dei problemi più utile è il logger dei pacchetti SIP. Stampa ogni richiesta e risposta SIP sulla console man mano che viene inviata o ricevuta, il che è inestimabile durante la diagnosi di problemi di registrazione e di configurazione delle chiamate.

```
pjsip set logger on
pjsip set logger off
```

È anche possibile limitare la registrazione a un singolo host con `pjsip set logger host <ip>`.

#### pjsip set history on

Una grande aggiunta a PJSIP è il concetto di cronologia. È possibile acquisire e analizzare le richieste e le risposte SIP in tempo reale in modo semplice. Per avviare la cronologia utilizzare il comando sottostante.

![L'esecuzione di `pjsip set history on` restituisce "PJSIP History enabled"](../images/07-sip-and-pjsip-fig20.png)

Ora è possibile mostrare la cronologia:

![Output di `pjsip show history`: una tabella numerata di messaggi SIP acquisiti — REGISTER, 401 Unauthorized, REGISTER, 200 OK — con timestamp, direzione e indirizzo](../images/07-sip-and-pjsip-fig21.png)

Quindi, per vedere una richiesta o una risposta specifica, mostrare l'elemento della cronologia:

![Output di `pjsip show history entry`: il testo completo di un singolo messaggio SIP acquisito — qui la risposta `404 Not Found` di Asterisk 22 a una sonda OPTIONS — che mostra gli header Via (con `rport`/`received`), Call-ID, From, To e CSeq, le capacità `Allow`/`Supported` e l'header `Server: Asterisk PBX 22.10.0`](../images/07-sip-and-pjsip-fig22.png)

Molto facile, vero? È anche possibile cancellare la cronologia ogni volta che si desidera utilizzando `pjsip set history clear`.

> **Stai migrando un sistema chan_sip/sip.conf esistente?** Il driver legacy `chan_sip`
> e una **guida completa alla migrazione da sip.conf a pjsip.conf** (inclusa la
> tabella di mappatura dei concetti e lo script di conversione `sip_to_pjsip.py`) sono trattati
> nel capitolo *Canali legacy*.

## Riepilogo

SIP è il protocollo di segnalazione IETF che stabilisce, modifica e termina le sessioni multimediali. I suoi user agent, proxy, registrar e gateway si scambiano messaggi basati su testo — REGISTER, INVITE, le risposte provvisorie e finali, ACK e BYE — mentre SDP negozia i codec e RTP trasporta i media. Tale teoria del protocollo è intramontabile e si applica a qualsiasi implementazione SIP.

In Asterisk 22 si utilizza SIP tramite **PJSIP** (`chan_pjsip`), configurato in `pjsip.conf`. Invece di un peer monolitico, un dispositivo viene modellato come un insieme di piccoli oggetti con riferimenti incrociati: `endpoint` (comportamento delle chiamate e codec), `auth` (credenziali), `aor` (dove è raggiungibile) e `transport` (il listener), oltre a `identify` (corrispondenza di un trunk tramite IP) e `registration` (registrazione in uscita) per i provider di servizi. Hai visto come questi oggetti si integrano tra loro, come configurare sia telefoni che trunk, come le opzioni di NAT-traversal (`force_rport`, `rewrite_contact`, `rtp_symmetric`, `direct_media` e le opzioni `external_*`/`local_net` del transport) risolvano le implementazioni nel mondo reale e come ispezionare il tutto con `pjsip show endpoints`, `aors`, `contacts` e `registrations`.

## Quiz

1. Nell'architettura SIP, quale componente riceve una richiesta e risponde con una risposta di reindirizzamento (come `302 Moved Temporarily`) che contiene la nuova posizione, per poi rimanere fuori dal percorso dei messaggi successivi?
   - A. Proxy server
   - B. Redirect server
   - C. Location server
   - D. Registrar

2. Quale ruolo svolge Asterisk quando gestisce una chiamata SIP tra due telefoni?
   - A. Un SIP proxy che rimane solo nel percorso di segnalazione
   - B. Un SIP redirect server
   - C. Un back-to-back user agent (B2BUA) che collega due canali SIP
   - D. Un SIP load balancer stateless

3. Quale metodo SIP viene utilizzato da un telefono per comunicare al registrar il proprio indirizzo IP corrente, in modo da poter ricevere chiamate in seguito?
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. Vero o Falso: In Asterisk 22, `chan_sip` e `sip.conf` sono ancora disponibili come fallback legacy insieme a PJSIP.

5. Con quali oggetti di configurazione deve essere associato un endpoint affinché Asterisk conosca il socket di ascolto da utilizzare e dove inviare le chiamate per quel dispositivo? (Scegliere tutte le opzioni applicabili.)
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. In un oggetto PJSIP `aor`, quale impostazione mantiene aperta la mappatura NAT qualificando periodicamente il contatto, e qual è la sua unità di misura?
   - A. `qualify=yes` (booleano)
   - B. `qualify_frequency` (secondi)
   - C. `rtp_timeout` (millisecondi)
   - D. `nat=force_rport`

7. Riempi lo spazio vuoto: Per far sì che Asterisk abbini una richiesta SIP in entrata a uno specifico endpoint tramite l'indirizzo IP di origine (invece che tramite l'intestazione `From`), si crea una sezione con `type=________`.

8. Quale oggetto PJSIP viene utilizzato per configurare una registrazione **in uscita** da Asterisk verso un provider di trunk SIP?
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. Sulla CLI di Asterisk 22, quale comando abilita il logger dei pacchetti SIP che stampa ogni richiesta e risposta SIP sulla console?
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. Su un endpoint PJSIP che serve un telefono dietro un NAT simmetrico, quale coppia di impostazioni fa sì che Asterisk risponda all'indirizzo di origine della richiesta (RFC 3581) e invii i media verso il punto da cui arrivano effettivamente i pacchetti RTP?
    - A. `direct_media=yes` e `srvlookup=yes`
    - B. `force_rport=yes` e `rtp_symmetric=yes`
    - C. `allowguest=yes` e `insecure=invite`
    - D. `qualify=yes` e `nat=no`

**Risposte:** 1 — B · 2 — C · 3 — D · 4 — Falso · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
