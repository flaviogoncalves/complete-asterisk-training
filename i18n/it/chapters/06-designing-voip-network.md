# Progettazione di una rete VoIP

Il Voice over IP sta crescendo rapidamente nel mercato della telefonia. Il paradigma della convergenza sta cambiando il modo in cui comunichiamo, riducendo i costi e migliorando il modo in cui scambiamo informazioni. La voce è solo l'inizio di un'era di comunicazione multimediale completa, che include voce, video e presenza. In futuro, non trasporteremo le persone al lavoro, ma il lavoro alle persone perché è più pulito, più veloce e più economico. Il VoIP è solo una parte di questa rivoluzione. La nostra sfida in questo capitolo è progettare una rete VoIP. Per farlo, dovremo comprendere concetti come i protocolli di sessione e i codec, oltre a come dimensionare il numero di circuiti e la larghezza di banda.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Comprendere i vantaggi del VoIP
- Descrivere come Asterisk gestisce il VoIP
- Descrivere i concetti dei canali SIP e IAX
- Scegliere il protocollo più adeguato per uno specifico canale dati
- Scegliere il codec più adeguato per uno specifico canale dati
- Dimensionare il numero di canali richiesti
- Calcolare la larghezza di banda necessaria

## Vantaggi del VoIP

Perché dovresti interessarti al VoIP? Il VoIP offre vantaggi sia alle aziende che ai privati. La riduzione dei costi è certamente uno di questi, ma in alcuni ambienti il VoIP semplifica l'integrazione dei sistemi informatici. Alcuni dei vantaggi sono descritti in dettaglio qui:

### Convergenza

Il vantaggio principale del VoIP è la combinazione di reti dati e voce per ridurre i costi (convergenza). Tuttavia, analizzare solo i costi al minuto della voce potrebbe non essere sufficiente per giustificare l'adozione del VoIP. Il prezzo dei minuti venduti dalle compagnie telefoniche sta diventando rapidamente più economico ed è un aspetto da considerare prima di adottare il VoIP.

### Costi dell'infrastruttura

L'utilizzo di un'unica infrastruttura di rete riduce i costi associati ad aggiunte, rimozioni e modifiche. Poiché l'IP è diventato pervasivo, ha portato la tecnologia legata al VoIP su diversi nuovi dispositivi, come telefoni cellulari, PDA, sistemi embedded e laptop.

### Standard aperti

Infine, gli standard aperti su cui è costruito il VoIP offrono la libertà di scegliere tra diversi fornitori. Questo singolo vantaggio rende il cliente il re, invece di un subordinato delle TELCO e dei produttori di PBX.

### Integrazione di Telefonia e Computer (CTI)

La telefonia è molto più antica dell'informatica. I PBX telefonici sono basati sulla commutazione di circuito e di solito non si dispone di più di un computer per la supervisione. Con il VoIP, la telefonia è creata fin dalle fondamenta basandosi sugli standard informatici. Questo rende l'uso delle applicazioni di Computer Telephony più economico e semplice rispetto al vecchio modello. È possibile creare rapidamente un lungo elenco di applicazioni di telefonia basate su Asterisk. Puoi sviluppare IVR, ACD, CTI, dialer, popup a schermo e altre applicazioni in una frazione del tempo richiesto per i PBX tradizionali.

## Architettura VoIP di Asterisk

L'architettura di Asterisk è mostrata di seguito. Asterisk tratta tutti i protocolli VoIP come canali. È possibile utilizzare qualsiasi codec o qualsiasi protocollo. Il concetto da apprendere qui è che Asterisk mette in comunicazione qualsiasi tipo di canale con qualsiasi altro. Pertanto, è possibile tradurre protocolli di segnalazione come SIP e IAX l'uno verso l'altro e persino con codec differenti. Ad esempio, è possibile tradurre una chiamata da un telefono SIP nella rete locale che utilizza il codec G.711 verso un trunk SIP del proprio provider VoIP utilizzando il codec G.729. Nei prossimi capitoli, spiegheremo i dettagli dell'architettura SIP e IAX. Il supporto H.323 (tramite l'add-on chan_ooh323) è disponibile ma sempre più raro; SIP/PJSIP è lo standard per le implementazioni moderne.

![Architettura modulare di Asterisk: applicazioni e canali si connettono al core dello switch PBX tramite API, con moduli di traduzione dei codec e di formato file caricati dinamicamente.]((../images/06-voip-network-fig01.png))

## Protocolli VoIP e stack di rete

Il VoIP utilizza un insieme di protocolli diversi che lavorano insieme. È allettante allinearli al modello di riferimento OSI a sette livelli, e molti diagrammi più datati fanno esattamente questo — posizionando SIP e H.323 al livello di "sessione" e i codec al livello di "presentazione". Tale mappatura è sempre stata controversa. L'IETF, che standardizza SIP, non utilizza il modello OSI; segue il più vecchio modello TCP/IP (DoD) a quattro livelli, e la RFC 3261 definisce **SIP come un protocollo a livello applicativo**. Il media segue lo stesso schema: RTP e i codec risiedono nel payload dell'applicazione, trasportati su UDP al livello di trasporto. La tabella sottostante mappa i principali protocolli VoIP sul modello TCP/IP effettivamente utilizzato dall'IETF, con l'equivalente OSI approssimativo mostrato solo per riferimento.

| Livello TCP/IP (IETF) | Protocolli | Equivalente OSI approssimativo |
|---|---|---|
| Applicazione | SIP, H.323, MGCP, segnalazione IAX2; RTP/RTCP; codec (G.711, G.729, Opus…) | Applicazione / Presentazione / Sessione |
| Trasporto | UDP, TCP | Trasporto |
| Internet | IP (con QoS come DiffServ) | Rete |
| Collegamento | Ethernet, PPP, Frame Relay… | Collegamento dati / Fisico |

I meccanismi di QoS come DiffServ operano a livello IP per dare priorità ai pacchetti vocali e migliorare la qualità della chiamata. Alcune specifiche dei protocolli:

- **SIP** utilizza UDP o TCP sulla porta 5060 (TLS sulla 5061) per trasportare la segnalazione. L'audio viene trasportato separatamente tramite RTP su un intervallo di porte UDP configurabile (il file di esempio `rtp.conf` fornito con Asterisk utilizza da 10000 a 20000), codificato con un codec come G.711.
- **H.323** trasporta la segnalazione di chiamata su TCP (segnalazione di chiamata H.225 sulla porta 1720), mentre il canale RAS H.225 utilizza UDP sulla porta 1719; RTP trasporta l'audio.
- **IAX2** è insolito: multiplexa sia la segnalazione che il media su un'unica porta UDP (4569), il che semplifica l'attraversamento di NAT e firewall.


## Come scegliere un protocollo

Dati i numerosi protocolli, come è possibile scegliere quello migliore per la propria rete? In questa sezione, metteremo in evidenza i vantaggi e gli svantaggi di ciascun protocollo.

### SIP - Session Initiated Protocol

SIP è uno standard aperto dell'Internet Engineering Task Force (IETF), definito in gran parte nella RFC 3261. La maggior parte dei provider VoIP moderni utilizza SIP; di fatto, sta diventando lo standard VoIP più diffuso. Il punto di forza di SIP è quello di essere uno standard basato su IETF. SIP è leggero se confrontato con il più datato H.323. La debolezza principale di SIP è il NAT traversal, una sfida per la maggior parte dei provider VoIP SIP. L'IETF non ha creato SIP pensando alla fatturazione, ma per le comunicazioni aperte tra peer. La fatturazione è solitamente una preoccupazione per i provider VoIP.

### IAX – Inter Asterisk eXchange

IAX è un protocollo aperto sviluppato originariamente da Digium (ora Sangoma). IAX è un protocollo all-in-one poiché trasporta segnalazione e media attraverso la stessa porta UDP (4569). Mark Spencer ha sviluppato IAX come protocollo binario per una larghezza di banda ridotta. Il punto di forza principale di IAX è il suo ridotto utilizzo di larghezza di banda (non utilizza RTP); è inoltre molto semplice per il NAT e il firewall traversal poiché utilizza una sola porta UDP (4569).

Se un produttore di PBX tradizionale avesse creato IAX, probabilmente avrebbe commercializzato il protocollo come "la cosa migliore dopo il gelato"; in alcune situazioni, IAX in modalità trunk può ridurre l'uso della larghezza di banda vocale di un terzo. IAX2 (versione 2) è ancora presente in Asterisk 22 tramite il modulo `chan_iax2` e rimane utile per i trunk tra Asterisk, sebbene sia considerato legacy; SIP/PJSIP è preferito per le nuove implementazioni. IAX2 è specificato nella [RFC 5456](https://www.rfc-editor.org/rfc/rfc5456) (informativa).

### MGCP – Media Gateway Control Protocol

MGCP è un protocollo utilizzato insieme a H.323, SIP e IAX. Il suo maggiore vantaggio è la scalabilità. Viene configurato nel call agent invece che nei gateway. Ciò semplifica il processo di configurazione e consente una gestione centralizzata. Tuttavia, l'implementazione in Asterisk non è completa e sembra che non molte persone lo utilizzino.

### H.323

H.323 è ampiamente utilizzato nel VoIP. È uno dei primi protocolli VoIP ed è essenziale per collegare le infrastrutture VoIP più datate basate su gateway. H.323 è ancora lo standard nel mercato dei gateway, sebbene il mercato stia lentamente migrando verso SIP. I punti di forza di H.323 includono l'ampia adozione sul mercato e la maturità. Le debolezze di H.323 sono legate alla complessità dell'implementazione e ai costi associati agli organismi di standardizzazione.

### Tabella di confronto dei protocolli

La seguente tabella riassume le differenze tra i protocolli di sessione.

| Protocollo | Organismo di standardizzazione | Modulo Asterisk 22 / stato | Utilizzato per |
|----------|---------------|-----------------------------|----------|
| SIP | Standard IETF | `chan_pjsip` (core; l'unico driver SIP — `chan_sip` è stato rimosso in Asterisk 21) | Telefoni SIP; connessione a provider di servizi SIP |
| IAX2 | RFC 5456 (informativa) | `chan_iax2` (core; ancora fornito, considerato legacy) | Trunk tra Asterisk; telefoni IAX2; provider di servizi IAX |
| H.323 | Standard ITU | `chan_ooh323` (componente aggiuntivo della community esterna, non nella build base) | Telefoni e gateway H.323 (può utilizzare un gatekeeper esterno, non può esserlo) |
| MGCP | IETF/ITU | `chan_mgcp` rimosso in Asterisk 21 — non più disponibile | (telefoni MGCP legacy) |
| SCCP (Skinny) | Proprietario Cisco | `chan_skinny` rimosso in Asterisk 21 — non più disponibile | (telefoni Cisco legacy) |

## Un endpoint per dispositivo

In Asterisk 22 lo stack PJSIP modella ogni telefono, trunk o gateway come un singolo oggetto **endpoint** in `pjsip.conf`. Un endpoint effettua e riceve chiamate; le sue credenziali risiedono in un oggetto `auth`, il suo indirizzo registrato in un `aor` e il suo percorso di rete in un `transport`. Si configura un endpoint per dispositivo e si collegano gli elementi di cui ha bisogno: non c'è alcun ruolo separato di "user" rispetto a "peer" su cui ragionare. (Il modello a oggetti completo è trattato in *SIP & PJSIP in depth*.)

## Codec e traduzione di codec

Utilizzerete un codec per convertire la voce da un'onda analogica a un segnale digitale. I codec differiscono l'uno dall'altro per aspetti come la qualità del suono, il tasso di compressione, la larghezza di banda e i requisiti di calcolo. Servizi, telefoni e gateway solitamente supportano diversi di questi aspetti. Il codec G.729 è molto popolare. Non fa parte della build standard di Asterisk 22; viene invece fornito come modulo aggiuntivo esterno (`codec_g729`) che si scarica da Digium (ora Sangoma). Il sorgente `menuselect` di Asterisk lo elenca con `support_level=external` e nota chiaramente: "Scaricare il codec g729a da Digium. Per questo codec deve essere acquistata una licenza." In altre parole, l'uso legale di G.729 richiede una licenza acquistata per canale. (Esiste anche un'alternativa open-source, `bcg729`.)

![Pulse Code Modulation (PCM): un segnale analogico a 4000 Hz viene campionato 8000 volte al secondo (teorema di Nyquist) e codificato in un flusso di bit digitale a 64 Kbps.](../images/06-voip-network-fig04.png)

Asterisk 22 supporta i seguenti codec (tra gli altri):

- GSM: 13 Kbps
- iLBC: 13.3 Kbps
- ITU G.711 (ulaw/alaw): 64 Kbps — qualità PSTN standard; ulaw comune in Nord America, alaw comune in Europa e America Latina
- ITU G.722: 64 Kbps — banda larga (voce HD), buona qualità alla stessa larghezza di banda del G.711
- ITU G.723.1: 5.3/6.3 Kbps
- ITU G.726: 16/24/32/40 Kbps
- ITU G.729: 8 Kbps — modulo binario esterno `codec_g729` scaricato da Digium/Sangoma (`support_level=external`; per utilizzarlo deve essere acquistata una licenza)
- Speex: da 2.15 a 44.2 Kbps
- LPC10: 2.4 Kbps
- **Opus**: 6–510 Kbps, variabile — moderno codec a banda larga/banda intera; eccellente qualità e resilienza alla perdita di pacchetti; fornito come modulo binario esterno `codec_opus` scaricato da Digium/Sangoma (`support_level=external`; nessun acquisto di licenza segnalato, a differenza del G.729); raccomandato per WebRTC e moderni endpoint SIP. (Esistono alternative di build open-source su GitHub.)

Inoltre, Asterisk permette la traduzione tra codec. In alcuni casi, ciò non è possibile, come nel caso del g723, che è supportato solo in modalità pass-thru. La traduzione da un codec all'altro consuma molte risorse della CPU. Pertanto, evitatela del tutto ogni volta che è possibile.

## Come scegliere un codec

La selezione del codec dipende da diverse opzioni, come:

- Qualità del suono
- Costi di licenza
- Consumo di elaborazione CPU
- Requisiti di banda
- Occultamento della perdita di pacchetti
- Disponibilità per Asterisk e dispositivi telefonici

La seguente tabella confronta i codec più diffusi. La qualità di questi codec è considerata “toll”—in altre parole, simile a quella della PSTN.

| Codec | G.711 | G.722 | Opus | G.729A | iLBC | GSM |
|---|---|---|---|---|---|---|
| Banda audio | Stretta | Larga (HD) | Stretta–piena | Stretta | Stretta | Stretta |
| Banda (Kbps) | 64 | 64 | 6–510 | 8 | 13.33 | 13 |
| Costo/canale | Gratuito | Gratuito | Gratuito | Licenza¹ | Gratuito | Gratuito |
| Cancellazione frame² | Nessuna | Bassa | Eccellente | ~3% | ~5% | ~3% |
| Costo CPU | Molto basso | Basso | Mod.–alto | Alto | Alto | Basso |

I moduli di Asterisk 22 sono: G.711 `codec_ulaw` / `codec_alaw` (core), G.722 `codec_g722` (core), Opus `codec_opus` (esterno), G.729 `codec_g729` (esterno), iLBC `codec_ilbc` (core) e GSM `codec_gsm` (core). Opus è "Stretta–piena" perché scala dalla banda stretta fino alla banda piena; la sua larghezza di banda (6–510 Kbps) è variabile e la sua resistenza alla cancellazione dei frame deriva dal FEC/PLC integrato.

Il riferimento per la PSTN è **G.711** — è il punto di riferimento per la qualità "toll" ed effettua la transcodifica gratuitamente all'interno di Asterisk. **G.722** offre voce a banda larga (HD) agli stessi 64 Kbps ed è una buona scelta per LAN/interni. **Opus** è il moderno standard per WebRTC ed endpoint SIP capaci: adatta il proprio bitrate, dispone di correzione degli errori in avanti integrata e resiste bene alla perdita di pacchetti; viene fornito come binario esterno `codec_opus` (scaricabile gratuitamente). **G.729** rimane utile su trunk WAN a bassa larghezza di banda, ma l'uso legale richiede il binario con licenza di Sangoma `codec_g729` (scaricabile gratuitamente, licenza per canale per l'uso) o l'implementazione open-source **bcg729** come alternativa.

¹ Il binario `codec_g729` di Sangoma è scaricabile gratuitamente ma richiede l'acquisto di una licenza per canale per essere utilizzato legalmente. L'alternativa open-source `bcg729` è priva di licenza.

² La resistenza alla cancellazione dei frame si riferisce a quanto bene la qualità percepita (MOS) si mantiene in presenza di perdita di pacchetti. Il punto di crossover esatto varia in base alla pacchettizzazione e alle condizioni di rete; utilizzare questa colonna per un confronto relativo, non come dato preciso.

**Consigli sui codec per Asterisk 22:**

- **G.711 (ulaw/alaw):** Da utilizzare per trunk PSTN e massima interoperabilità; costo di transcodifica zero all'interno di Asterisk.
- **G.729:** Utile per trunk WAN a bassa larghezza di banda; il modulo `codec_g729` di Sangoma è scaricabile gratuitamente ma richiede l'acquisto di una licenza per canale per l'uso.
- **G.722:** Buona scelta per la banda larga (voce HD) su LAN/extension interne; stessa larghezza di banda di G.711 con qualità migliore.
- **Opus:** Consigliato per endpoint moderni, client WebRTC e qualsiasi implementazione in cui l'endpoint lo supporti. Bitrate adattivo, eccellente resilienza alla perdita di pacchetti, disponibile gratuitamente tramite il modulo binario `codec_opus` di Sangoma.

## Overhead causato dagli header di protocollo

Nonostante il fatto che i codec facciano un uso limitato di banda, dobbiamo considerare l'overhead causato dagli header di protocollo come Ethernet, IP, UDP e RTP. Di conseguenza, la banda effettivamente consumata dipende dagli header utilizzati. Su una rete Ethernet il requisito è superiore rispetto a una rete PPP, poiché l'header PPP è più corto di quello Ethernet. Un singolo pacchetto vocale G.729, ad esempio, trasporta solo 20 byte di payload ma è racchiuso in circa 58 byte di header Ethernet, IP, UDP e RTP; quindi sono gli header, non il codec, a dominare la banda (si veda la figura sottostante).

![Un singolo pacchetto vocale G.729 su Ethernet: 20 byte di payload racchiusi in 58 byte di header Ethernet, IP, UDP e RTP — una conversazione G.729 consuma 31.2 Kbps.](figure_g729_overhead.png)(../images/06-voip-network-fig05.png)

- Ethernet (Ethernet+IP+UDP+RTP+G.711) = 95.2 Kbps
- PPP (PPP+IP+UDP+RTP+G.711) = 82.4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.711) = 82.8 Kbps

Codec G.729 (8 Kbps)

- Ethernet (Ethernet+IP+UDP+RTP+G.729) = 31.2 Kbps
- PPP (PPP+IP+UDP+RTP+G.729) = 26.4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.729) = 26.8 Kbps

È possibile calcolare facilmente altri requisiti di banda utilizzando un calcolatore di banda VoIP online come <https://www.voip.school/bandcalc/bandcalc.php>.


## Ingegneria del traffico

Una questione principale nella progettazione di reti VoIP è il dimensionamento del numero di linee e della larghezza di banda richiesta verso una destinazione specifica, come una sede remota o un service provider. È inoltre importante dimensionare il numero di chiamate simultanee di Asterisk (parametro principale per il dimensionamento di Asterisk).

### Semplificazioni

La semplificazione primaria e più utilizzata consiste nello stimare il numero di chiamate per tipo di utente. Ad esempio:

- PBX aziendali (una chiamata simultanea ogni cinque extension)
- Utenti residenziali (una chiamata simultanea ogni sedici utenti)

Esempio #1 La sede centrale dell'azienda ha 120 extension e due filiali: la prima con 30 extension e la seconda con 15 extension. Il nostro obiettivo è dimensionare il numero di trunk E1 nella sede centrale e la larghezza di banda richiesta per la rete Frame-Relay.

![Topologia di rete di esempio (stessa città): la sede centrale con 120 extension si collega alla PSTN tramite linee T1, e alla filiale #1 (30 extension) e alla filiale #2 (15 extension) tramite un cloud Frame-Relay.](images/network_topology.png)(../images/06-voip-network-fig06.png)

1a Numero di linee T1

- Numero totale di extension che utilizzano linee T1: 120+30+15=165 linee
- Utilizzando un trunk ogni cinque extension per uso aziendale
- Numero totale di linee = 33 o approssimativamente 2xT1 linee

1b Requisiti di larghezza di banda Scegliamo il codec g.729 per i requisiti di larghezza di banda, la qualità del suono e il consumo medio di CPU.

Con un trunk ogni cinque extension:

- Larghezza di banda richiesta per la filiale #1 (Frame-relay): 26.8*6=160.8 Kbps
- Larghezza di banda richiesta per la filiale #2 (Frame-relay): 26.8*3= 80.4 Kbps

### Metodo Erlang B

Quando si dispone di dati storici, è possibile dimensionare il trunk in modo più scientifico invece di semplificare. Utilizzeremo il lavoro di Agner Karup Erlang (Copenhagen Telephone Company, 1909), che ha sviluppato una formula per calcolare il numero di linee in un gruppo di trunk tra due città.

Un **Erlang** è un'unità di misura del traffico comune nelle telecomunicazioni; descrive il volume di traffico durante un'ora. Ad esempio, supponiamo che si verifichino 20 chiamate in un'ora, con una media di 5 minuti di conversazione ciascuna:

- Minuti di traffico nell'ora: 20 × 5 = 100 minuti
- Ore di traffico all'interno di un'ora: 100 / 60 = **1.66 Erlang**

È possibile leggere queste misure da un call logger e utilizzarle per progettare la propria rete e calcolare il numero di linee richieste. Una volta noto il numero di linee, è possibile calcolare i requisiti di larghezza di banda.

**Erlang B** è il metodo più comunemente utilizzato per calcolare il numero di linee in un gruppo di trunk. Presuppone che le chiamate arrivino in modo casuale (distribuzione di Poisson) e che le chiamate bloccate vengano immediatamente eliminate. Richiede di conoscere il **Busy Hour Traffic (BHT)**, che è possibile ottenere da un call logger o stimare come semplificazione: BHT = 17% dei minuti di chiamata di un giorno.

![Risultati del calcolatore Erlang B: 5 Erlang all'1% di blocco richiedono 11 linee (dalla sede centrale alla filiale #1), e 2.83 Erlang all'1% di blocco richiedono 8 linee (dalla sede centrale alla filiale #2).](images/erlang_b_calc.png)(../images/06-voip-network-fig07.png)

Un'altra variabile importante è il Grade of Service (GoS), che definisce la probabilità di bloccare le chiamate a causa della carenza di linee. È possibile arbitrare questo parametro, che solitamente è 0.05 (5% di chiamate perse) o 0.01 (1% di chiamate perse). Esempio #1: Utilizzando lo stesso esempio di sede centrale e due filiali introdotto in precedenza in questa sezione, forniremo alcuni dati sui modelli di traffico. Dal call logger, abbiamo scoperto questi dati: Dati dal call logger (minuti di chiamata e BHT):

- Sede centrale verso filiale #1 = 2.000 minuti, BHT = 300 minuti
- Sede centrale verso filiale #2 = 1.000 minuti, BHT = 170 minuti
- Filiale #1 verso filiale #2 = 0, BHT=0

Arbitriamo GoS=0.01

- Sede centrale verso filiale #1 - BHT=300 minuti/60 = 5 Erlang
- Sede centrale verso filiale #2 – BHT=170 minuti/60 = 2.83 Erlang

Utilizzando un calcolatore Erlang come <https://www.erlang.com>

- Per la sede centrale verso la filiale #1, sono richieste 11 linee.
- Per la sede centrale verso la filiale #2, sono richieste 8 linee

1.b Larghezza di banda richiesta Stiamo utilizzando una WAN in cui la perdita di pacchetti è rara. Sceglieremo il codec g729 per la sua buona qualità del suono e la compressione dei dati (8 Kbps).

Codec selezionato: g729 Livello datalink: Frame-Relay

- Larghezza di banda vocale stimata per la filiale #1: 26.8x11 = 294.8 Kbps
- Larghezza di banda vocale stimata per la filiale #2: 26.8x8 = 214.40 Kbps

## Ridurre la larghezza di banda richiesta per il VoIP

Si possono utilizzare tre metodi per ridurre la larghezza di banda richiesta per le chiamate VoIP:

- Compressione dell'intestazione RTP
- IAX Trunked
- Payload VoIP

### Compressione dell'intestazione RTP

Nelle reti Frame-Relay e PPP, è possibile utilizzare la compressione dell'intestazione RTP. La compressione dell'intestazione RTP è stata definita nella RFC 2508. Si tratta di uno standard IETF disponibile in diversi router. Tuttavia, è necessario prestare attenzione, poiché alcuni router richiedono un set di funzionalità diverso affinché questa risorsa sia disponibile. L'impatto dell'utilizzo della compressione dell'intestazione RTP è straordinario, poiché riduce la larghezza di banda richiesta nel nostro esempio da 26.8 Kbps per conversazione vocale a 11.2 Kbps: una riduzione del 58.2%!

### Modalità trunk IAX2

Se si stanno collegando due server Asterisk, è possibile utilizzare il protocollo IAX2 in modalità trunk. Questa tecnologia rivoluzionaria non necessita di router speciali e può essere applicata a qualsiasi tipo di collegamento dati.

![Modalità trunk IAX2 su Ethernet: una singola chiamata g.729 necessita del suo stack di intestazione completo (31.2 Kbps), ma una seconda chiamata condivide tali intestazioni e aggiunge solo un piccolo miniframe IAX2, con una media di circa 9.6 Kbps di larghezza di banda extra per chiamata aggiuntiva.](IAX2_trunk_mode.png)(../images/06-voip-network-fig08.png)

La modalità trunk IAX2 riutilizza le stesse intestazioni dalla seconda chiamata in poi. Utilizzando g729 in un collegamento PPP, la prima chiamata consumerà 30 Kbps di larghezza di banda, mentre la seconda chiamata utilizzerà la stessa intestazione della prima e ridurrà la larghezza di banda necessaria per la chiamata aggiuntiva a 9.6 Kbps. Possiamo calcolare la larghezza di banda richiesta in modalità trunk come segue: Filiale #1 (11 chiamate) Larghezza di banda = 31.2 + (11-1)* 9.6 Kbps = 127.2 Kbps Filiale #2 (8 chiamate) Larghezza di banda = 31.2 + (8-1)* 9.6 Kbps = 98.4 Kbps La prima chiamata utilizza 31.2 Kbps, la successiva 9.6, e così via.

### Aumento del payload vocale

Questo metodo è molto comune quando si utilizzano gateway VoIP su Internet. Quando si utilizza un payload più grande, si sacrifica la latenza a favore di una larghezza di banda ridotta. È possibile modificare la packetization RTP aggiungendo la dimensione del frame al codec nell'istruzione allow.

![Aumento del payload vocale: l'inserimento di 60 byte di payload g.729 in un pacchetto (invece di 20) ammortizza i 58 byte di intestazioni su più voce, riducendo la larghezza di banda a circa 16.05 Kbps per chiamata al costo di una maggiore latenza.](Increasing_voice_payload.png)(../images/06-voip-network-fig09.png)

Esempio:

```
allow=ulaw:30
```

Il numero dopo i due punti è l'intervallo di packetization in millisecondi: quanta voce viene trasportata in ogni pacchetto RTP. Un valore più grande ammortizza l'overhead fisso dell'intestazione su più audio (meno larghezza di banda) al costo di una maggiore latenza. Ogni codec ha la propria dimensione del frame minima, massima e predefinita; G.711 (`ulaw`/`alaw`), ad esempio, ha un valore predefinito di 20 ms.

## Riepilogo

In questo capitolo, hai imparato che Asterisk gestisce il VoIP utilizzando i canali. Supporta SIP (tramite `chan_pjsip` in Asterisk 22) e IAX2; H.323 è disponibile solo attraverso l'add-on della community `ooh323`, mentre i vecchi canali MGCP e SCCP (Skinny) non fanno più parte di una build standard di Asterisk 22. Hai confrontato e imparato come scegliere un protocollo di segnalazione e un codec per i canali VoIP. IAX2 è più efficiente in termini di larghezza di banda e può attraversare il NAT facilmente. SIP/PJSIP è il protocollo più supportato dai fornitori terzi di telefoni e gateway ed è l'unico driver di canale SIP in Asterisk 22. Il protocollo H.323 è il più datato e dovrebbe essere utilizzato per connettersi a infrastrutture VoIP legacy. Nella sezione Traffic Engineering, abbiamo imparato come progettare e dimensionare una rete VoIP.

## Quiz

1. Quali dei seguenti sono vantaggi del VoIP descritti in questo capitolo (seleziona tutte le risposte corrette)?
   - A. Convergenza delle reti dati e voce per ridurre i costi
   - B. Minori costi infrastrutturali per aggiunte, rimozioni e modifiche
   - C. Standard aperti che liberano dal vincolo di un singolo fornitore
   - D. Integrazione di telefonia informatica (Computer Telephony Integration) più semplice ed economica
   - E. Tariffe di chiamata al minuto garantite più basse rispetto a qualsiasi compagnia telefonica
2. La convergenza è l'integrazione di voce, dati e video in un'unica rete; il suo vantaggio principale è la riduzione dei costi nell'implementazione e nella manutenzione di reti separate.
   - A. Falso
   - B. Vero
3. Asterisk tratta ogni protocollo VoIP come un canale e può collegare qualsiasi tipo di canale a qualsiasi altro, effettuando la transcodifica tra codec quando necessario.
   - A. Falso
   - B. Vero
4. In Asterisk 22, SIP è gestito da quale driver di canale?
   - A. chan_sip
   - B. chan_pjsip
   - C. chan_skinny
   - D. chan_mgcp
5. Nel modello TCP/IP (IETF) rispetto al quale SIP è effettivamente definito nella RFC 3261, i protocolli di segnalazione SIP, H.323 e IAX2 operano al livello ___.
   - A. Presentazione
   - B. Applicazione
   - C. Fisico
   - D. Sessione
   - E. Collegamento dati
6. SIP è il protocollo più adottato per i telefoni IP ed è uno standard aperto definito in gran parte dall'IETF nella RFC 3261.
   - A. Falso
   - B. Vero
7. IAX2 trasporta sia la segnalazione che i media su un'unica porta UDP, il che lo rende efficiente e facile da far attraversare attraverso il NAT. Quale porta UDP utilizza IAX2?
   - A. 5060
   - B. 1720
   - C. 4569
   - D. 5061
8. IAX è stato originariamente sviluppato da Digium (ora Sangoma). Nonostante la limitata adozione da parte dei fornitori di telefonia, IAX è eccellente quando è necessario (seleziona tutte le risposte corrette):
   - A. Ridurre l'utilizzo di banda (non utilizza RTP)
   - B. Un formato multimediale video
   - C. Facilitare l'attraversamento di NAT e firewall
   - D. Modalità trunk per combinare molte chiamate tra Asterisk e ammortizzare l'overhead dell'intestazione
9. In Asterisk 22, un dispositivo viene configurato come un singolo oggetto PJSIP `endpoint` che sia effettua che riceve chiamate — non esiste un ruolo separato di "user" o "peer".
   - A. Falso
   - B. Vero
10. Per quanto riguarda i codec in Asterisk 22, seleziona tutte le affermazioni vere:
    - A. G.711 è equivalente a PCM e utilizza 64 Kbps di banda.
    - B. Il modulo codec_g729 di Sangoma è scaricabile gratuitamente, ma l'uso legale richiede l'acquisto di una licenza per canale.
    - C. GSM è popolare perché utilizza circa 13 Kbps e non necessita di licenza.
    - D. G.711 u-law è comune in Nord America, mentre a-law è comune in Europa e America Latina.
    - E. G.729 è leggero e utilizza pochissime risorse CPU per codificare e decodificare rispetto a G.711.

**Risposte:** 1 — A, B, C, D · 2 — B · 3 — B · 4 — B · 5 — B (Applicazione — SIP è un protocollo a livello applicativo nel modello TCP/IP utilizzato dall'IETF) · 6 — B · 7 — C · 8 — A, C, D · 9 — B · 10 — A, B, C, D
