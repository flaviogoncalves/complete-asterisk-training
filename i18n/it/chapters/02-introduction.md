# Introduzione ad Asterisk PBX

La popolarità di distribuzioni pronte all'uso come FreePBX e Issabel è cresciuta recentemente. In questo libro, tratteremo l'Asterisk classico, che è la base per comprendere queste distribuzioni. Asterisk PBX è un software open-source in grado di trasformare un normale PC in un potente PBX multiprotocollo. In questo capitolo, impareremo a conoscere le possibilità di questa nuova tecnologia e la sua architettura di base.

## Obiettivi

Al termine di questo capitolo dovresti essere in grado di:

- Spiegare cos'è Asterisk e cosa fa;
- Descrivere il ruolo di Digium™ e del suo successore Sangoma;
- Riconoscere l'architettura di base di Asterisk e i suoi componenti;
- Indicare diversi scenari di utilizzo; e
- Identificare le fonti di informazione e supporto.

## Che cos'è Asterisk

Asterisk è un software PBX open-source che trasforma un normale computer in un PBX completo per utenti domestici, aziende, fornitori di servizi VoIP e compagnie telefoniche. Asterisk è sia una comunità open-source che un progetto sponsorizzato da Sangoma Technologies (che ha acquisito Digium nel 2018). Sei libero di utilizzare e modificare Asterisk per soddisfare le tue esigenze. Asterisk consente la connettività in tempo reale tra reti PSTN e VoIP. Poiché Asterisk è molto più di un semplice PBX, non solo avrai un eccezionale aggiornamento del tuo PBX esistente, ma potrai anche fare cose nuove nel campo della telefonia, come:

- Collegare i dipendenti che lavorano da casa a un PBX aziendale tramite Internet a banda larga;
- Collegare diversi uffici in luoghi differenti tramite una rete IP, una rete privata o persino attraverso Internet stesso;
- Fornire ai tuoi dipendenti una voicemail integrata con il web e l'e-mail;
- Creare applicazioni come IVR che consentono connessioni al tuo sistema di ordinazione o ad altre applicazioni;
- Dare agli utenti in viaggio l'accesso al PBX aziendale da qualsiasi luogo con una semplice connessione a banda larga o VPN; e
- molto altro ancora....

Asterisk include diverse risorse avanzate precedentemente presenti solo in sistemi di fascia alta, come:

- Musica per i clienti in attesa nelle code di chiamata, con supporto per lo streaming multimediale e file MP3;
- Code di chiamata, grazie alle quali un team di agenti può rispondere alle chiamate e monitorare le code;
- Integrazione con text-to-speech e riconoscimento vocale;
- Registri dettagliati trasferiti sia su file di testo che su database SQL; e
- Connettività PSTN tramite linee sia digitali che analogiche.

## Che cos'è AsteriskNOW (storico) e FreePBX

Asterisk nella sua forma più pura, noto anche come "classic asterisk" (denominazione del pacchetto Debian), è considerato più uno strumento di sviluppo che un prodotto finito di per sé. AsteriskNOW era un'iniziativa volta a trasformare Asterisk in una soft-appliance. La distribuzione includeva CentOS come sistema operativo e FreePBX come interfaccia grafica. AsteriskNOW è stato successivamente dismesso.

Oggi, la distribuzione Asterisk "chiavi in mano" standard è **FreePBX** (mantenuta da Sangoma), che raggruppa Asterisk con una GUI di amministrazione basata sul web e un ecosistema di moduli. FreePBX è concesso in licenza secondo la GPL e può essere scaricato liberamente da www.freepbx.org. Per le implementazioni commerciali, Sangoma offre anche **FreePBX Distro** (un'immagine Linux completa) e il suo prodotto commerciale **PBXact**.

## Ruolo di Digium™ e Sangoma

Digium, un'azienda con sede a Huntsville, in Alabama, è stata il creatore e il principale sviluppatore di Asterisk sin dalla sua fondazione nel 1999. Oltre a essere il principale sponsor dello sviluppo di Asterisk, Digium ha prodotto schede di interfaccia telefonica e altro hardware per i PBX Asterisk, e ha creato prodotti commerciali come Switchvox (destinato al mercato delle PMI). Nel 2018, Digium è stata acquisita da **Sangoma Technologies**, un'azienda canadese di comunicazioni unificate. Dall'acquisizione, Sangoma ha continuato a sponsorizzare lo sviluppo di Asterisk e funge da suo principale amministratore, mantenendo il progetto open-source su www.asterisk.org.

Storicamente, Digium ha offerto Asterisk secondo tre tipi di accordi di licenza:

- Asterisk con licenza General Public License (GPL). Questa è la versione più utilizzata. Include tutte le funzionalità ed è libera di essere utilizzata e modificata secondo i termini della licenza GPL.
- Asterisk Business Edition era una versione commerciale di Asterisk. Alcune aziende utilizzavano la business edition perché non volevano o non potevano utilizzare la licenza GPL, solitamente perché non desideravano rilasciare il proprio codice sorgente insieme ad Asterisk. **Nota:** Asterisk Business Edition è stata interrotta; oggi Asterisk è distribuito esclusivamente sotto licenza GPL.
- Licenza OEM di Asterisk. Dopo che Digium ha smesso di vendere Asterisk Business Edition al dettaglio, ha continuato a concedere in licenza tale edizione commerciale ai clienti OEM, ovvero fornitori di apparecchiature che desideravano costruire prodotti proprietari basati su Asterisk senza rilasciare il proprio codice sorgente sotto licenza GPL.

### Il progetto Zapata e la sua relazione con Asterisk

Il progetto Zapata è stato sviluppato da Jim Dixon, che è stato anche responsabile del rivoluzionario design hardware utilizzato con Asterisk. Anche l'hardware è open-source; pertanto, può essere utilizzato da qualsiasi azienda e oggi diversi produttori realizzano schede compatibili con questa architettura.

Il progetto Zapata ha prodotto un'architettura chiamata Zaptel, successivamente rinominata DAHDI (Digium/Asterisk Hardware Device Interface). Uno dei principali vantaggi di questa architettura è la capacità di utilizzare la CPU del PC per elaborare lo streaming multimediale, la cancellazione dell'eco e la transcodifica. Al contrario, la maggior parte delle schede esistenti utilizza processori di segnale digitale (DSP) per eseguire queste attività. L'uso della CPU del PC invece di DSP dedicati riduce drasticamente il prezzo della scheda. Pertanto, queste schede sono significativamente più economiche rispetto alle interfacce precedentemente disponibili di altri produttori. D'altra parte, queste schede richiedono molta CPU; un uso improprio della CPU del PC può influire significativamente sulla qualità della voce. Recentemente, Digium ha lanciato una scheda coprocessore che utilizza DSP per codificare e decodificare G.729 e G.723, consentendo una migliore scalabilità per un gran numero di canali.

## Perché Asterisk?

Ricordo il mio primo contatto con Asterisk. Di solito, la prima reazione di fronte a qualcosa di nuovo — specialmente qualcosa che compete con ciò che già conosci — è il rifiuto! Questo è esattamente ciò che è successo nel 2003. Asterisk era in competizione con una soluzione che stavo vendendo a un cliente (un Gateway VoIP 4 E1), ed era dieci volte meno costoso di quanto facessi pagare per la soluzione che già conoscevo. Questo prezzo sproporzionato mi ha spinto a iniziare a studiare Asterisk per identificare potenziali insidie e svantaggi. Ad esempio, ho scoperto che la CPU dei PC di quel tempo non avrebbe supportato 120 sessioni g.729 simultanee; alla fine della giornata, ho vinto la proposta con la mia soluzione Gateway.

Tuttavia, questo esercizio mi ha portato alla scoperta che Asterisk poteva risolvere una varietà di problemi molto costosi per la mia base clienti. Eravamo in difficoltà con preventivi costosi per IVR, messaggistica unificata, registrazione delle chiamate e dialer; con un dimensionamento appropriato, i problemi di CPU potevano essere aggirati. Infatti, in soli tre anni Asterisk è diventato il prodotto di punta della mia azienda (ho deciso di aprire un'altra società proprio per il business di Asterisk). A mio parere, Asterisk è una rivoluzione nelle telecomunicazioni che rappresenta per la telefonia IP ciò che Apache rappresenta per i servizi web.

### Riduzione estrema dei costi

Se confronti un PBX tradizionale con Asterisk per quanto riguarda le interfacce digitali e i telefoni, Asterisk è leggermente più economico di quei PBX. Tuttavia, Asterisk ripaga davvero quando aggiungi funzionalità avanzate come voicemail, ACD, IVR e CTI. Con queste funzionalità avanzate, Asterisk diventa significativamente meno costoso dei PBX tradizionali. Di fatto, confrontare i PBX Asterisk con i PBX analogici di fascia bassa è ingiusto, perché Asterisk offre così tante funzionalità non disponibili nei sistemi analogici di fascia bassa.

### Controllo e indipendenza del sistema di telefonia

Uno dei vantaggi di Asterisk citati più spesso dai clienti è l'indipendenza che esso fornisce. Alcuni dei produttori odierni non forniscono nemmeno al cliente la password del sistema o la documentazione di configurazione. Con l'approccio "fai-da-te" di Asterisk, l'utente ottiene una libertà totale; come bonus, l'utente ha accesso a un'interfaccia standard.

### Ambiente di sviluppo facile e rapido

Asterisk può essere esteso utilizzando linguaggi di scripting come PHP e Perl con le interfacce AMI e AGI. Asterisk è open-source e il suo codice sorgente può essere modificato dall'utente. Il codice sorgente è scritto principalmente nel linguaggio di programmazione ANSI C.

### Ricco di funzionalità

Asterisk possiede diverse funzionalità che non si trovano o sono opzionali nei PBX tradizionali (ad esempio, voicemail, CTI, ACD, IVR, musica d'attesa integrata e registrazione). I costi di queste funzionalità in alcune piattaforme superano il prezzo della piattaforma stessa.

### Contenuto dinamico sul telefono

Asterisk è programmato utilizzando il linguaggio C e altri linguaggi comuni nell'ambiente di sviluppo odierno. La possibilità di fornire contenuti dinamici è praticamente illimitata.

### Dialplan flessibile e potente

Un'altra svolta di Asterisk è il suo potente dialplan. Nei PBX tradizionali, anche funzionalità semplici come il least cost routing (LCR) non sono fattibili o sono opzionali. Con Asterisk, scegliere il percorso migliore è facile e pulito.

### Open-source basato su Linux

Una delle più grandi caratteristiche di Asterisk è la sua community. Sono disponibili diverse risorse, tra cui la documentazione ufficiale di Asterisk (docs.asterisk.org), il wiki VoIP-Info gestito dalla community (www.voip-info.org <http://www.voip-info.org>), liste di distribuzione e-mail e forum. Man mano che Asterisk viene adottato sempre più ampiamente, i bug vengono trovati e corretti rapidamente. Con una vasta base di utenti e un team di sviluppo attivo, Asterisk è tra le piattaforme PBX più ampiamente testate al mondo, il che aiuta a mantenere la base di codice stabile e matura.

### Limitazioni dell'architettura di Asterisk

Alcune limitazioni in Asterisk derivano dall'uso del design di telefonia Zapata. In questo design, Asterisk utilizza la CPU del PC per elaborare i canali vocali invece di processori di segnale digitale (DSP) dedicati, che sono comuni in altre piattaforme. Sebbene ciò consenta un'enorme riduzione dei costi nell'interfaccia hardware, il sistema diventa dipendente dalla CPU del PC. La mia raccomandazione è di eseguire Asterisk su una macchina dedicata ed essere conservativi riguardo al dimensionamento dell'hardware. Puoi anche utilizzare Asterisk in una VLAN separata per evitare broadcast eccessivi che consumano la CPU (tempeste di broadcast causate da loop o virus). Alcune schede di interfaccia più recenti di diversi fornitori includono ora DSP per elaborare la cancellazione dell'eco, i codec e altre funzionalità, il che renderà Asterisk ancora migliore.

## Principali obiezioni al PBX Asterisk

È comune sentire obiezioni all'adozione di Asterisk, che affronteremo qui.

### La quota di mercato di Asterisk è troppo piccola

La quota di mercato viene solitamente misurata in base al numero di PBX venduti. Queste statistiche vengono generalmente acquisite dai maggiori distributori. Asterisk è un software libero che può essere scaricato e distribuito senza che venga registrata alcuna vendita, quindi viene sistematicamente sottostimato in quelle cifre. Ciononostante, Asterisk alimenta una base installata molto ampia in tutto il mondo — dai PBX per ufficio a server singolo fino a grandi implementazioni per carrier e contact-center — e rimane il motore dominante dietro l'ecosistema PBX open-source (incluse distribuzioni chiavi in mano come FreePBX).

### Se è gratuito, come sopravvive il produttore?

In realtà, non esiste un produttore di software open-source nel senso tradizionale del termine. Digium ha sviluppato Asterisk dal 1999, sostenendosi attraverso la vendita di schede di interfaccia telefonica, prodotti PBX commerciali come Switchvox e software correlati. Nel 2018, Sangoma Technologies ha acquisito Digium. Sangoma continua a finanziare lo sviluppo di Asterisk e genera entrate attraverso prodotti commerciali (moduli commerciali FreePBX, PBXact, Switchvox), vendite di hardware e servizi professionali.

### È difficile trovare supporto tecnico!

Sangoma fornisce supporto tecnico commerciale per Asterisk attraverso il suo ecosistema di partner e direttamente tramite le sue offerte di prodotto. Una rete globale di professionisti certificati fornisce supporto di primo livello e servizi professionali. Il supporto della community rimane attivo attraverso i forum di Asterisk e le mailing list su www.asterisk.org.

### Asterisk supporta più di 200 extension?

Sì, assolutamente. Un singolo server Asterisk ben dimensionato può gestire un gran numero di extension, e Asterisk scala ulteriormente distribuendo gli utenti su più server con bilanciamento del carico e failover, consentendo grandi implementazioni multi-sito.

### Solo i “geek” sono in grado di installare Asterisk

Con FreePBX (disponibile come distribuzione autonoma da Sangoma), anche i professionisti con conoscenze limitate di Linux sono in grado di installare e configurare un PBX di media complessità. Con l'aiuto di una GUI, è possibile configurare un intero PBX in poche ore.

### Cosa succede se il server si guasta?

Uno dei principali vantaggi di Asterisk è la sua capacità di funzionare in sistemi tolleranti ai guasti. È relativamente semplice ed economico avere due server in esecuzione in parallelo. Vi sfido a provare questo con un PBX convenzionale!

### La nostra azienda non utilizza software open-source

La vostra azienda probabilmente utilizza software open-source senza nemmeno rendersene conto. Diversi appliance utilizzano Linux come sistema operativo. Inoltre, il supporto commerciale e le implementazioni gestite sono disponibili da Sangoma e dalla sua rete di partner certificati.

### L'utilizzo della CPU del PC per elaborare segnalazione e media non è raccomandato

Asterisk utilizza la CPU del server per elaborare la segnalazione e i media per i canali vocali invece di avere DSP dedicati. Sebbene ciò consenta una riduzione dei costi fino a cinque volte, rende il sistema dipendente dalle prestazioni della CPU principale. Con il corretto dimensionamento, Asterisk è in grado di gestire grandi volumi. Se desiderate comunque sollevare la CPU principale da questi compiti, potete anche utilizzare l'eliminazione dell'eco hardware e persino schede transcodificatore, come la Sangoma (precedentemente Digium) TC400B basata su DSP.

## Architettura di Asterisk

Questa sezione spiegherà come funziona l'architettura di Asterisk. La figura sottostante mostra l'architettura di base di Asterisk. Successivamente, spiegheremo i concetti relativi all'architettura, inclusi i canali, i codec e le applicazioni.

![L'architettura di Asterisk](../images/01-introduction-fig01.png)

### Canali

Un canale è l'equivalente di una linea telefonica, ma in formato digitale. Solitamente consiste in un sistema di segnalazione analogico o digitale (TDM) o in una combinazione di codec e protocollo di segnalazione (ad esempio, SIP-GSM, IAX-uLaw). Inizialmente, tutte le connessioni telefoniche erano analogiche e suscettibili a eco e rumore. Successivamente, la maggior parte dei sistemi è stata convertita in sistemi digitali, con il suono analogico convertito in formato digitale utilizzando la modulazione a impulsi codificati (PCM) nella maggior parte dei casi. Questo formato consente la trasmissione vocale a 64 kilobit/secondo senza compressione.

Canali che si interfacciano con la Public Switched Telephone Network (PSTN):

- `chan_dahdi`: schede TDM analogiche (FXO/FXS) e digitali (E1/T1/PRI) di Sangoma (precedentemente Digium), Xorcom e altri. Costruite separatamente rispetto a DAHDI — vedere il capitolo *Legacy channels*.

Canali che si interfacciano con Voice over IP:

- `chan_pjsip`: SIP — il driver di canale SIP primario e unico in Asterisk 22 LTS. Stringa di composizione: `PJSIP/endpoint_name`. (**Nota:** il vecchio `chan_sip` è stato rimosso in Asterisk 21 e non esiste in Asterisk 22. Vedere *Building your first PBX with PJSIP* per la configurazione.)
- `chan_iax2`: il protocollo IAX2 — ancora fornito in Asterisk 22 ma è legacy; SIP/PJSIP è preferito per le nuove implementazioni. Stringa di composizione: `IAX2/peer`.
- `chan_unistim`: telefoni Nortel/Avaya UNISTIM. Ancora disponibile (supporto esteso) ma raramente utilizzato.

I vecchi canali VoIP non fanno più parte di una build standard di Asterisk 22: `chan_h323` (H.323) sopravvive solo come componente aggiuntivo della community `ooh323`, mentre `chan_mgcp` (MGCP) e `chan_skinny` (Cisco SCCP) sono stati deprecati e rimossi dal set di canali moderno. Se è necessario interagire con tali protocolli, l'approccio abituale consiste nell'utilizzare un gateway davanti ad Asterisk.

Canali vari:

- **Local**: un pseudo-canale (integrato nel core) che esegue il loopback nel dialplan in un context differente — utile per il routing ricorsivo e per distribuire una chiamata verso destinazioni multiple. Stringa di composizione: `Local/extension@context`.

### Codec e traduzione dei codec

Solitamente cerchiamo di inserire il maggior numero possibile di connessioni vocali in una rete dati. I codec abilitano nuove funzionalità nella voce digitale, inclusa la compressione, che è una delle caratteristiche più importanti poiché consente tassi di compressione superiori a 8 a 1. Molti codec definiscono anche funzionalità come il rilevamento dell'attività vocale (soppressione del silenzio), il mascheramento della perdita di pacchetti e la generazione di rumore di comfort, sebbene Asterisk stesso non generi rumore di comfort né esegua la soppressione del silenzio. Diversi codec sono disponibili per Asterisk e possono essere tradotti in modo trasparente l'uno dall'altro. Internamente, Asterisk utilizza slinear come formato di flusso quando deve convertire da un codec all'altro. Alcuni codec in Asterisk sono supportati solo in modalità pass-through; questi codec non possono essere tradotti. Per verificare quali codec sono installati nel proprio sistema, è possibile utilizzare il comando da console:

```
CLI>core show translation
```

I seguenti codec sono supportati:

- G.711 ulaw (USA) - (64 Kbps).
- G.711 alaw (Europa) - (64 Kbps).
- G.722 (Alta Definizione) – (64 Kbps)
- G.723.1 - Solo modalità pass-through
- G.726 - (16/24/32/40kbps)
- G.729 - Modulo codec binario distribuito da Sangoma; il download è gratuito, ma l'uso legale richiede l'acquisto di una licenza per canale (8Kbps)
- GSM - (12-13 Kbps)
- iLBC - (15 Kbps)
- LPC10 - (2.4 Kbps)
- Speex - (2.15-44.2 Kbps)
- Opus - (6-510 Kbps)

### Protocolli

Inviare dati da un telefono all'altro dovrebbe essere facile, a condizione che i dati trovino autonomamente un percorso verso l'altro telefono. Sfortunatamente, non accade in questo modo ed è necessario un protocollo di segnalazione per stabilire connessioni tra i telefoni, scoprire i dispositivi finali e implementare la segnalazione telefonica. SIP è il protocollo di segnalazione dominante nelle implementazioni moderne ed è l'unico canale SIP disponibile in Asterisk 22 LTS (tramite chan_pjsip). IAX2 è ancora disponibile ma considerato legacy. Asterisk supporta i seguenti protocolli.

- SIP — tramite `chan_pjsip`
- IAX2 — legacy, ancora fornito in Asterisk 22
- UNISTIM — telefoni Nortel/Avaya (supporto esteso)
- H.323, MGCP e SCCP (Cisco Skinny) — protocolli legacy non più presenti in una build standard di Asterisk 22 (H.323 solo tramite il componente aggiuntivo della community `ooh323`)

### Applicazioni

Per collegare le chiamate da un telefono all'altro, viene utilizzata l'applicazione dial(). La maggior parte delle funzionalità di Asterisk (ad esempio, voicemail e conferenze) sono implementate come applicazioni. È possibile visualizzare le applicazioni di Asterisk disponibili utilizzando il comando da console core show applications.

```
CLI>core show applications
```

È possibile aggiungere applicazioni dagli add-on di Asterisk, da fornitori terzi o persino da quelle sviluppate personalmente.

## Panoramica di un sistema Asterisk

Asterisk è un PBX open-source che agisce come un PBX ibrido, integrando tecnologie come la telefonia TDM e IP. Asterisk è pronto a implementare funzionalità come l'interactive voice response (IVR) e l'automatic call distribution (ACD); inoltre, come menzionato in precedenza, è aperto allo sviluppo di nuove applicazioni. Questa figura mostra come Asterisk si connette alla PSTN e ai PBX esistenti utilizzando interfacce analogiche e digitali, oltre a supportare telefoni analogici e IP. Può agire come SoftSwitch, media gateway, voicemail, conferenza audio e dispone anche di musica d'attesa integrata.

![Panoramica di un sistema Asterisk](../images/01-introduction-fig02.png)

## Confronto tra il vecchio e il nuovo mondo

Nel vecchio modello di SoftSwitch, tutti i componenti venivano venduti separatamente, il che significava dover acquistare ogni componente singolarmente e poi integrarlo nell'ambiente PBX o SoftSwitch. I costi e i rischi erano elevati e la maggior parte delle apparecchiature era proprietaria.

![Il vecchio mondo: componenti acquistati e integrati separatamente](../images/01-introduction-fig03.png)

### Telefonia tramite Asterisk

Tutte le funzioni sono integrate nella piattaforma Asterisk, nello stesso server o in macchine diverse a seconda del dimensionamento, e sono tutte con licenza GPL. A volte è più semplice installare Asterisk che ottenere le licenze di alcuni dei principali IP-PBX commerciali.

![Telefonia tramite Asterisk: le funzioni sono integrate](../images/01-introduction-fig04.png)

## Costruzione di un sistema di test

Quando si implementa una soluzione Asterisk, il nostro primo passo è generalmente quello di costruire un sistema di test. L'obiettivo è un **1×1 PBX** minimale — un telefono che può chiamarne un altro — in modo da poter provare endpoint, dialplan e funzionalità prima di toccare l'ambiente di produzione. Oggi questo è interamente software: non è necessario alcun hardware di telefonia.

![Un semplice sistema di test Asterisk](../images/01-introduction-fig05.png)

### Il metodo moderno: un laboratorio software (consigliato)

Il sistema di test più veloce è Asterisk 22 in esecuzione all'interno di un container o di una macchina virtuale, con **softphone** come endpoint e, facoltativamente, un **SIP trunk** per raggiungere la rete pubblica:

- **Asterisk 22** su una piccola macchina Linux, VM o container Docker. Questo libro fornisce un laboratorio Docker pronto all'uso (vedi la guida al laboratorio) che avvia un Asterisk 22 completamente configurato con un singolo comando — nessuna compilazione, nessun hardware.
- **Due softphone** registrati come endpoint PJSIP, in modo da poter effettuare una chiamata reale tra di loro. In tutto questo libro utilizziamo il **SipPulse Softphone** (download gratuito: <https://www.sippulse.com/produtos/softphone>), disponibile per desktop e mobile.
- **Un SIP trunk** (opzionale) da un provider VoIP, per quando si desidera raggiungere la PSTN. Nessuna scheda e nessuna linea analogica — solo credenziali.

È così che ogni esempio in questo libro viene costruito e verificato, e puoi riprodurlo su qualsiasi laptop.

### Il metodo tradizionale: schede analogiche/digitali

Prima del VoIP, un PBX di test necessitava di interfacce fisiche: una porta **FXO** per connettersi a una linea telefonica esistente e una porta **FXS** per connettere un telefono analogico, che insieme formavano un PBX 1×1. Una singola scheda dotata di un'interfaccia FXO e una FXS era il classico kit di avvio. Queste schede basate su DAHDI (di Sangoma, precedentemente Digium) esistono ancora per i siti che devono terminare linee analogiche o T1/E1, ma oggi sono di nicchia — la maggior parte delle implementazioni sono puramente VoIP. Se hai bisogno solo di collegare telefoni o linee analogiche, consulta il capitolo *Legacy Channels*; altrimenti puoi ignorare completamente l'hardware di telefonia.

## Scenari Asterisk

Asterisk può essere utilizzato in diversi scenari. Ne elencheremo alcuni spiegando i vantaggi e i possibili limiti di ciascuno.

### IP PBX

Lo scenario più comune è l'installazione di un nuovo PBX o la sostituzione di uno esistente. Se si confronta Asterisk con altre alternative, si scoprirà che è più economico e ricco di funzionalità rispetto alla maggior parte dei PBX attualmente disponibili sul mercato. Diverse aziende stanno ora modificando le proprie specifiche passando ad Asterisk invece di altri PBX di marca.

![Asterisk come IP PBX](../images/01-introduction-fig06.png)

### IP-enabling di PBX legacy

L'immagine seguente illustra una delle configurazioni più comunemente utilizzate. Le grandi aziende generalmente non vogliono correre rischi significativi quando investono in nuove tecnologie e desiderano contemporaneamente preservare i propri investimenti in apparecchiature legacy. L'IP-enabling di un PBX legacy può essere molto costoso; pertanto, collegare un PBX Asterisk utilizzando linee T1/E1 può essere una buona alternativa per i clienti attenti ai costi. Un altro vantaggio è la possibilità di connettersi a un provider di servizi VoIP con tariffe telefoniche migliori.

![IP-enabling di un PBX legacy](../images/01-introduction-fig07.png)

### Toll Bypass

Un'applicazione molto utile per il VoIP è il collegamento di filiali tramite Internet o una WAN. L'utilizzo di una connessione dati esistente consente di evitare i costi di chiamata sostenuti nelle connessioni di telecomunicazione tra la sede centrale e le filiali.

![Toll bypass tra uffici su una WAN](../images/01-introduction-fig08.png)

### Application Server (IVR, conferenze, voicemail)

Asterisk può essere utilizzato come application server per il PBX esistente o essere collegato direttamente alla PSTN. Asterisk offre servizi come voicemail, ricezione fax, registrazione delle chiamate, IVR collegato a un database e un server di audioconferenza. Se si integrano voicemail e fax in un server di posta elettronica esistente, si otterrà un sistema di messaggistica unificata, che solitamente è una soluzione costosa. L'utilizzo di Asterisk come application server offre un'estrema riduzione dei costi rispetto ad altre soluzioni.

![Asterisk come application server](../images/01-introduction-fig09.png)

### Media Gateway

La maggior parte dei provider di servizi voice-over IP utilizza un SIP proxy per ospitare tutta la registrazione, la localizzazione e l'autenticazione degli utenti SIP. Devono comunque inviare le chiamate alla PSTN direttamente o instradarle attraverso un provider di terminazione chiamate wholesale utilizzando una connessione voice-over IP SIP o H.323. Asterisk può agire come back-to-back user agent (B2BUA) o media gateway, sostituendo soft switch o media gateway molto costosi. Confronta il prezzo di un gateway a quattro E1/T1 dei principali produttori sul mercato con Asterisk. La soluzione Asterisk può costare diverse volte meno di altre soluzioni ed è in grado di tradurre protocolli di segnalazione (H.323, SIP, IAX…) e codec (G.711, G.729…).

![Asterisk come media gateway](../images/01-introduction-fig10.png)

### Piattaforma per Contact Center

Un contact center è una soluzione molto complessa che combina diverse tecnologie, come la distribuzione automatica delle chiamate (ACD), l'interactive voice response (IVR) e la supervisione delle chiamate. Fondamentalmente, sono disponibili tre tipi di contact center: inbound, outbound e blended.

I contact center inbound sono molto sofisticati e solitamente richiedono ACD, IVR, CTI, registrazione, supervisione e report. Asterisk dispone di un ACD integrato per mettere in coda le chiamate. L'IVR può essere realizzato utilizzando l'Asterisk Gateway Interface (AGI) o meccanismi interni come l'applicazione background(). La computer telephony integration (CTI) si ottiene utilizzando l'Asterisk Manager Interface (AMI); la registrazione e la reportistica sono integrate in Asterisk.

Per un contact center outbound, un predictive o power dialer è uno dei componenti principali. Sebbene siano disponibili diversi dialer per l'Asterisk open-source, non è difficile costruirne uno personalizzato per la piattaforma, se lo si desidera. Un contact center blended consente operazioni simultanee inbound e outbound, risparmiando denaro garantendo un migliore utilizzo del tempo dell'agente. È possibile utilizzare Asterisk e il suo meccanismo ACD per implementare una soluzione blended.

![Una piattaforma contact-center Asterisk](../images/01-introduction-fig11.png)

## Trovare informazioni e assistenza

Questa sezione fornirà alcune delle principali fonti di informazione relative ad Asterisk.

- Sito ufficiale di Asterisk: <https://www.asterisk.org> Qui è possibile trovare informazioni su:
- Documentazione & Wiki -> <https://docs.asterisk.org>
- Forum della community -> <https://community.asterisk.org>
- Tracciamento dei bug -> <https://github.com/asterisk/asterisk/issues>
- Wiki (legacy, in gran parte sostituita da docs.asterisk.org) -> <https://wiki.asterisk.org>

### Forum della community

Il forum della community di Asterisk ha in gran parte sostituito le vecchie mailing list ed è il posto giusto in cui porre domande. Cerca di raccogliere quante più informazioni possibili prima di pubblicare un post. Nessuno ti aiuterà se non hai fatto i compiti a casa: prova almeno una volta a risolvere il problema da solo.

- <https://community.asterisk.org>

## Riepilogo

Asterisk è un software con licenza GPL che permette a un normale PC di agire come una potente piattaforma IP PBX. Mark Spencer di Digium ha creato Asterisk alla fine degli anni '90 e Digium si è sostenuta vendendo hardware e prodotti commerciali legati ad Asterisk. Digium è stata acquisita da Sangoma Technologies nel 2018; Sangoma ora sponsorizza lo sviluppo di Asterisk. La progettazione dell'interfaccia hardware ha avuto origine nel progetto Zapata sviluppato da Jim Dixon, che ha dato vita a DAHDI.

L'architettura di Asterisk presenta i seguenti componenti principali:

- CHANNELS: Analogici, digitali o voice-over IP. In Asterisk 22 LTS, SIP è gestito esclusivamente da `chan_pjsip`.
- PROTOCOLS: Protocolli di comunicazione, responsabili della segnalazione delle chiamate, inclusi SIP (tramite PJSIP), H.323, MGCP e IAX2.
- CODECS: Traducono i formati digitali della voce consentendo la compressione e il mascheramento della perdita di pacchetti. Si noti che Asterisk di per sé non esegue la soppressione del silenzio (rilevamento dell'attività vocale) o la generazione di comfort-noise; quando gli endpoint utilizzano VAD, il comfort noise dovrebbe essere disabilitato sul lato client.
- APPLICATIONS: Responsabili della funzionalità del PBX Asterisk. Conferenza, voicemail e fax sono esempi di applicazioni Asterisk.

Asterisk può essere utilizzato in vari scenari, da un piccolo IP PBX a un sofisticato contact center. È possibile trovare facilmente aiuto su www.asterisk.org e docs.asterisk.org.

## Quiz

1. Quale azienda ha acquisito Digium nel 2018 e funge ora da principale responsabile del progetto open-source Asterisk?
   - A. Cisco Systems
   - B. Sangoma Technologies
   - C. Nortel Networks
   - D. Red Hat

2. In Asterisk 22 LTS, quale driver di canale fornisce la connettività SIP?
   - A. `chan_sip`
   - B. `chan_skinny`
   - C. `chan_pjsip`
   - D. `chan_h323`

3. Vero o Falso: Il driver di canale `chan_sip` è stato rimosso in Asterisk 21 e non è presente in una build standard di Asterisk 22.

4. Quali dei seguenti canali/protocolli **non fanno più** parte di una build standard di Asterisk 22? (Seleziona tutte le risposte corrette.)
   - A. MGCP (`chan_mgcp`)
   - B. SCCP / Cisco Skinny (`chan_skinny`)
   - C. IAX2 (`chan_iax2`)
   - D. H.323 (`chan_h323`, che sopravvive solo come componente aggiuntivo della community `ooh323`)

5. L'architettura hardware del progetto Zapata, originariamente chiamata Zaptel, è stata successivamente rinominata in ____.
   - A. DAHDI
   - B. PJSIP
   - C. PRI
   - D. mISDN

6. Quando Asterisk deve convertire l'audio da un codec a un altro, attraverso quale formato di flusso interno esegue la traduzione?
   - A. G.711 ulaw
   - B. GSM
   - C. slinear (signed linear)
   - D. Opus

7. Secondo il capitolo, qual è la situazione delle licenze del modulo codec G.729 distribuito da Sangoma?
   - A. È GPL e completamente gratuito per qualsiasi utilizzo.
   - B. Il download è gratuito, ma l'uso legale richiede l'acquisto di una licenza per canale.
   - C. Non può essere ottenuto in alcun modo senza acquistare Asterisk Business Edition.
   - D. Funziona solo in modalità pass-through e non può essere installato.

8. Quale applicazione di Asterisk viene utilizzata per collegare una chiamata da un telefono a un altro?
   - A. `Background()`
   - B. `Dial()`
   - C. `Queue()`
   - D. `Goto()`

9. Che cos'è il canale `Local` in Asterisk?
   - A. Un'interfaccia hardware FXS per telefoni analogici.
   - B. Un trunk SIP verso un fornitore di servizi locale.
   - C. Un pseudo-canale che reindirizza una chiamata nel dialplan in un context differente.
   - D. Un codec utilizzato per le chiamate on-net.

10. In quale scenario di utilizzo Asterisk agisce come back-to-back user agent (B2BUA), traducendo tra protocolli di segnalazione e codec per sostituire costosi SoftSwitch?
    - A. Abilitazione IP di un PBX legacy
    - B. Toll bypass
    - C. Media Gateway
    - D. Piattaforma per Contact Center

**Risposte:** 1 — B · 2 — C · 3 — Vero · 4 — A, B, D · 5 — A · 6 — C · 7 — B · 8 — B · 9 — C · 10 — C
