# Canali legacy: analogici, TDM e IAX2

In un mondo puramente VoIP nel 2026, i tipi di canale trattati in questo capitolo sono sempre più rari: la maggior parte delle nuove implementazioni utilizza trunk SIP ed endpoint PJSIP su Ethernet, senza alcun hardware di telefonia. Asterisk 22, tuttavia, li supporta ancora quasi tutti pienamente. La connettività analogica (FXO/FXS) e digitale TDM (E1/T1/ISDN PRI/BRI) è fornita tramite DAHDI — lo stack di driver originariamente sviluppato da Digium, acquisita da Sangoma nel 2018, dopo che i precedenti driver Zaptel furono rinominati in seguito a una disputa sui marchi. La connettività server-to-server tramite IAX2 è fornita da `chan_iax2`, che viene ancora distribuito e supportato ma è ormai decisamente un protocollo legacy.

Questo capitolo raccoglie anche il materiale relativo al **SIP legacy**: il vecchio driver `chan_sip` e la sua configurazione `sip.conf` — rimossi in Asterisk 21 e non più presenti in Asterisk 22 — insieme a una guida completa alla migrazione di un sistema `sip.conf` esistente verso PJSIP. Se gestisci un ambiente puramente SIP basato su PJSIP senza schede telefoniche, senza trunk IAX2 e senza alcun `sip.conf` legacy da convertire, puoi tranquillamente saltare questo capitolo.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Connettere Asterisk a linee e telefoni analogici con interfacce FXO/FXS tramite DAHDI;
- Riconoscere la connettività digitale TDM (E1/T1, ISDN PRI/BRI) e come viene configurata;
- Configurare IAX2 (`chan_iax2`) per trunk server-to-server e comprendere perché ora è considerato legacy;
- Identificare il driver ritirato `chan_sip` e la sintassi `sip.conf` che potresti ancora incontrare; e
- Migrare un sistema `chan_sip`/`sip.conf` esistente a PJSIP.

## Canali analogici (FXO/FXS)

A partire da Asterisk 22, DAHDI e le schede di telefonia analogica rimangono pienamente supportati e DAHDI viene ancora compilato con i kernel attuali. La maggior parte delle nuove implementazioni è tuttavia puramente VoIP (trunk SIP, PJSIP), quindi l'hardware analogico/TDM è ora una scelta di nicchia, presente principalmente in ambienti legacy, connettività PSTN rurale o mercati regolamentati. Tutto ciò che segue si applica ancora a tali scenari.

Esistono diversi modi per connettersi alla rete telefonica pubblica commutata (PSTN). Il modo migliore dipende da come la compagnia telefonica rende disponibile questa connessione nella propria zona. Il modo più semplice è utilizzare una linea analogica, simile a quella che si usa a casa. In questa sezione, mostreremo come configurare le schede analogiche di Sangoma™ (precedentemente Digium™) e Xorcom™.

### Obiettivi

Al termine di questo capitolo dovresti essere in grado di:

- Riconoscere i principali termini e acronimi della telefonia;
- Comprendere quando utilizzare circuiti digitali e analogici;
- Riconoscere la differenza tra FXS e FXO; e
- Configurare Asterisk per FXS e FXO.

### Fondamenti di telefonia

La maggior parte delle implementazioni analogiche utilizza una coppia di linee in rame chiamate tip e ring. Quando un loop viene chiuso, il telefono riceve il segnale di linea dallo switch della compagnia telefonica (o dal PBX privato). La segnalazione più frequentemente utilizzata è il loop-start; altri tipi di segnalazione meno comuni includono il ground start, utilizzato in diversi paesi. Le tre categorie di segnalazione sono:

- Segnalazione di supervisione
- Segnalazione di indirizzamento
- Segnalazione di informazione

#### Segnalazione di supervisione

Le principali segnalazioni di supervisione sono on-hook, off-hook e ringing.

- **On-Hook** – Quando un utente riaggancia il telefono, il PBX interrompe e non consente il passaggio della corrente elettrica. In questo stato, il circuito è chiamato on-hook. In questa posizione, è attivo solo il suonatore.
- **Off-Hook** – Prima di iniziare una telefonata, il telefono deve passare allo stato off-hook. Sollevare il ricevitore dal gancio chiude il loop e indica al PBX che l'utente intende effettuare una chiamata. Dopo aver ricevuto questa indicazione, il PBX genera un segnale di linea, indicando all'utente che è pronto ad accettare l'indirizzo di destinazione (ovvero, il numero di telefono).
- **Ringing** – Quando un utente chiama un altro telefono, genera una tensione verso il suonatore che avvisa l'altro utente che è in arrivo una chiamata. La segnalazione varia a seconda del paese, con toni diversi per paesi diversi.

Puoi personalizzare i toni di Asterisk in base al tuo paese modificando il file indications.conf. Ad esempio:

```
[br]
description=Brazil
ringcadance=1000,4000
dial=425
busy=425/250,0/250
ring=425/1000,0/4000
congestion=425/250,0/250,425/750,0/250
callwaiting=425/50,0/1000
```

#### Segnalazione di indirizzamento

È possibile utilizzare due tipi di segnalazione per la composizione. Il primo e più comune è il dual tone multi-frequency (dtmf), mentre l'altro è la composizione a impulsi (utilizzata nei vecchi telefoni a disco). I telefoni hanno un tastierino per la composizione e ogni tasto è associato a due frequenze: una alta e una bassa. Nel caso della segnalazione dtmf, la combinazione di questi toni indica quale cifra viene premuta. MFC/R2 utilizza un tono multifrequenza diverso dal dtmf.

#### Segnalazione di informazione

La segnalazione di informazione mostra l'avanzamento della chiamata e diversi eventi.

- Segnale di linea
- Segnale di occupato
- Ringback
- Congestione
- Numero non valido
- Tono di conferma

### Interfacce PSTN

Come nel caso dei vecchi PBX, è spesso necessario collegare il PBX Asterisk alla PSTN. Qui ti mostreremo come farlo. Di solito hai tre opzioni per le linee telefoniche.

- Analogica: La forma più comune per case e piccole imprese, solitamente fornita con una coppia metallica di linee in rame.
- Digitale: Utilizzata quando sono necessarie molte linee. Una linea digitale viene solitamente fornita da un CSU/DSU o da un multiplexer in fibra. Il connettore per l'utente finale è solitamente un RJ45. In alcuni paesi, le linee E1 vengono fornite utilizzando due connettori BNC coassiali; in questo caso avrai bisogno di un balun per collegare il jack RJ45 alla scheda telefonica.
- SIP: Questa opzione è stata sviluppata di recente. La linea telefonica viene fornita utilizzando una connessione dati con segnalazione SIP (VoIP). Questa è una buona opzione da utilizzare con Asterisk poiché non sarà necessario acquistare una scheda telefonica. Le telefonate verranno consegnate direttamente alla porta Ethernet. Un altro vantaggio è che potresti essere in grado di liberare risorse dalla tua CPU evitando la transcodifica dei codec.

### Interfacce analogiche FXS, FXO ed E&M

Sono disponibili diversi tipi di interfacce analogiche. È fondamentale comprendere le differenze tra queste interfacce per imparare come connettersi alla rete telefonica e ad altri PBX. Qui, mostreremo l'interfaccia E&M. Sebbene non sia attualmente disponibile per Asterisk e sia stata interrotta da diversi fornitori, potresti trovare router e PBX con questo tipo di interfaccia, quindi è meglio sapere con cosa hai a che fare.

#### Interfacce Foreign eXchange (FX)

Le interfacce FX sono analogiche. Il termine "Foreign eXchange" viene applicato ai trunk di accesso a una centrale telefonica (CO) PSTN. Foreign eXchange Office (FXO)

![Asterisk tra un telefono analogico (FXS) e la linea telco (FXO): il lato FXS fornisce segnale di linea e suoneria al telefono, mentre il lato FXO preleva il segnale di linea dalla centrale.](../images/10-legacy-fig01.png)

L'interfaccia FXO viene utilizzata per connettersi a una centrale (CO) o all'estensione di un altro PBX. Comunica direttamente con una linea telefonica proveniente dalla PSTN. Un'altra opzione è collegare l'interfaccia FXO a un PBX esistente, consentendo la comunicazione tra Asterisk e il PBX legacy. Collegare Asterisk a una porta PBX e fornire un'estensione remota utilizzando il VoIP viene spesso definito off-premises extension (OPX). Un'interfaccia FXO riceve un segnale di linea. Foreign eXchange Station (FXS) L'interfaccia FXS alimenta un telefono analogico, un modem o un fax. L'FXS fornisce il segnale di linea e l'alimentazione per un telefono.

#### Segnalazione trunk

- Loop-Start
- Ground-Start
- Kewlstart

L'uso della segnalazione kewlstart in Asterisk è quasi predefinito. Kewlstart non è una segnalazione in sé, ma aggiunge intelligenza al circuito monitorando ciò che sta accadendo dall'altra parte. Kewlstart si basa sul loop-start. La maggior parte degli switch non supporta questa funzione, che viene utilizzata per ottenere la notifica di riaggancio.

- Loopstart: Utilizzato nella maggior parte delle linee analogiche, consente al telefono di indicare "on-hook" e "off-hook" e allo switch di indicare "ring" e "no-ring". Questo è probabilmente ciò che la maggior parte delle persone ha a casa. Il nome deriva dal fatto che la linea è sempre aperta. Quando chiudi il loop, lo switch ti fornisce un segnale di linea. Una chiamata in arrivo viene segnalata da una tensione di suoneria di 100V sulla coppia aperta.

![Asterisk che opera come gateway VoIP: una porta FXO si collega a un'estensione PBX legacy mentre un Asterisk remoto fornisce quella linea a un telefono analogico su IP tramite una porta FXS (un'estensione off-premises, o OPX).](../images/10-legacy-fig02.png)

- Groundstart: Simile al Loopstart. Quando vuoi effettuare una chiamata, un lato della linea viene cortocircuitato. Quando lo switch identifica questo stato, inverte la tensione attraverso la coppia aperta, e quindi il loop viene chiuso. Di conseguenza, la linea diventa prima occupata prima di essere offerta al chiamante.
- Kewlstart: Aggiunge intelligenza ai circuiti, consentendo il monitoraggio dell'altro lato. Kewlstart incorpora molti vantaggi dal loop-start.

### Configurazione dei canali telefonici Asterisk

Per configurare una scheda di interfaccia telefonica, sono necessari diversi passaggi. In questo capitolo, mostreremo tre degli scenari più comuni:

- Connessione analogica tramite FXS
- Connessione analogica tramite FXO
- Connessione di un Astribank™ con interfacce FXS e FXO

### Procedura di configurazione (valida in entrambi i casi)

Prima di scegliere l'hardware per Asterisk, dovresti considerare il numero di chiamate simultanee, i servizi e i codec che verranno installati e abilitati. Asterisk è un'applicazione che richiede molta CPU, motivo per cui consigliamo una macchina dedicata per Asterisk. Il numero di schede di interfaccia installate all'interno del computer è limitato dal numero di slot e interruzioni disponibili. È preferibile installare una singola scheda con otto interfacce vocali piuttosto che due schede con quattro. Un'altra opzione è utilizzare un channel bank USB, come l'Astribank di Xorcom. Recentemente, alcuni produttori (ad esempio, CIANET) hanno iniziato a produrre channel bank TDMoE, rendendo ancora più semplice collegare dozzine di interfacce analogiche.

![Un Astribank Xorcom: un channel bank USB montabile a rack da 19 pollici che espone dozzine di porte FXS/FXO (qui un'unità a 32 porte) senza consumare slot PCI nell'host.](../images/10-legacy-fig03.png)

#### Esempio 1: Installazione di un FXO e un FXS

In questo esempio, utilizzeremo una scheda di interfaccia telefonica Sangoma TDM400 (precedentemente venduta come Digium TDM400) con un modulo FXS e uno FXO. I passaggi richiesti sono elencati di seguito:

1. Installare la scheda analogica FXS, FXO o entrambe.
2. Configurare il file `/etc/dahdi/system.conf` (precedentemente `/etc/zaptel.conf`).
3. Generare i file di configurazione utilizzando `dahdi_genconf`.
4. Caricare il driver per l'interfaccia DAHDI.
5. Eseguire `dahdi_test` per verificare le interruzioni perse.
6. Eseguire `dahdi_cfg` per configurare il driver.
7. Configurare il canale DAHDI nel file `chan_dahdi.conf`, quindi caricare Asterisk.

##### Passaggio 1: Installare la scheda TDM400

La scheda TDM404P contiene moduli FXS e FXO. Collegare i moduli FXS (S110M, verde) e FXO (X100M, rosso). Se si utilizzano moduli FXS, collegare la scheda direttamente alla fonte di alimentazione utilizzando un connettore molex. Si prega di indossare una protezione elettrostatica prima di maneggiare le schede di interfaccia per evitare danni all'hardware. Le schede analogiche Sangoma (precedentemente Digium) supportano anche un modulo hardware di cancellazione dell'eco VPMADT032.

##### Passaggio 2: Generare la configurazione con dahdi_genconf

La buona notizia riguardo alla configurazione è la nuova utility `dahdi_genconf`, che rileva e genera automaticamente la configurazione per le interfacce DAHDI. L'utility genera due file:

- `/etc/dahdi/system.conf`
- `/etc/asterisk/dahdi-channels.conf`
- `/etc/asterisk/users.conf` (con l'opzione `users`)
- Tutti questi file utilizzano l'opzione `chan_dahdi full`

Prima di poter eseguire `dahdi_genconf`, è importante configurare il file `genconf_parameters` (spesso indicato come `gen_parameters.conf`):

![Una scheda analogica Sangoma/Digium TDM404P: fino a quattro moduli FXS o FXO si collegano alle porte numerate, con una scheda figlia opzionale di cancellazione dell'eco hardware e un connettore di alimentazione dedicato a 12 V per i moduli FXS.](../images/10-legacy-fig04.png)

```
#
# /etc/dahdi/genconf_parameters
#
# This file contains parameters that affect the
# dahdi_genconf configurator generator.
#
#base_exten          4000
#fxs_immediate       no
#fxs_default_start   ks
#lc_country          il
#context_lines       from-pstn
#context_phones      from-internal
#context_input       astbank-input
#context_output      astbank-output
#group_phones        0
#group_lines         5
#brint_overlap
#bri_sig_style       bri_ptmp
#
# The echo canceller to use. If you have a hardware echo canceller, just
# leave it be, as this one won't be used anyway.
#
# The default is mg2, but it may change in the future. E.g: a packager
# that bundles a better echo canceller may set it as the default, or
# dahdi_genconf will scan for the "best" echo canceller.
#
#echo_can            hpec
#echo_can            oslec
#echo_can            none   # to avoid echo cancellers altogether
# bri_hardhdlc: If this parameter is set to 'yes', in the entries for
# BRI cards 'hardhdlc' will be used instead of 'dchan' (an alias for
# 'fcshdlc').
#
#bri_hardhdlc        yes
# For MFC/R2 Support
#pri_connection_type R2
#r2_idle_bits        1101
# pri_types contains a list of settings:
# Currently the only setting is for TE or NT (the default is TE)
#
#pri_termtype
# SPAN/2              NT
# SPAN/4              NT
```

Il file `genconf_parameters` ti consente di personalizzare la tua configurazione. I parametri più importanti per le linee analogiche sono:

```
base_exten          4000
fxs_immediate       no
fxs_default_start   ks
lc_country          br
context_lines       from-pstn
context_phones      from-internal
context_input       astbank-input
context_output      astbank-output
group_phones        0
group_lines         5
#echo_can           hpec
#echo_can           oslec
echo_can            MG2
```

Attenzione: è necessario configurare almeno l'algoritmo di cancellazione dell'eco per i canali. Il parametro base_exten definisce il dialplan di base per le estensioni FXS. In questo caso, il primo canale FXS riceverà il numero di estensione 4000, il secondo 4001, e così via. Il contesto in cui vengono creati le linee (context_lines) e i trunk (context_phones) è molto importante. Dopo aver generato i file, dovresti includere il file `/etc/asterisk/dahdi-channels.conf` nel file `/etc/asterisk/chan_dahdi.conf`:

```
#include dahdi-channels.conf
```

Nota: la segnalazione analogica è un po' confusa; è sempre l'inverso della scheda. Le schede FXS vengono segnalate con FXO mentre le schede FXO vengono segnalate con FXS. Asterisk comunica con questi dispositivi come se fosse sul lato opposto.

##### Passaggio 3: Caricare i driver del kernel

Ora devi caricare il modulo chan_dahdi e il relativo driver del kernel della scheda. Usa dahdi_hardware per rilevare la tua scheda e il nome del driver. Ad esempio:

| Scheda | Driver | Descrizione |
| --- | --- | --- |
| TE410P | wct4xxp | 4xE1/T1 - 3.3V PCI |
| TE405P | wct4xxp | 4xE1/T1 - 5V PCI |
| TDM400P | wctdm | 4 FXS/FXO |
| T100P | wct1xxp | 1 T1 |
| E100P | wct1xxp | 1 E1 |
| X100P | wcfxo | 1 FXO |

Comandi per caricare i driver:

```
modprobe dahdi
modprobe wctdm
```

##### Passaggio 4: Utilizzare l'utility dahdi_test

Un'utility importante è dahdi_test, che viene utilizzata per verificare le interruzioni perse nella scheda DAHDI. I problemi di qualità audio sono spesso legati a conflitti di interruzione. Per verificare che la tua scheda DAHDI non stia condividendo un'interruzione con altre schede, usa il seguente comando:

```
#cat /proc/interrupts
```

Puoi verificare il numero di interruzioni perse utilizzando l'utility dahdi_test compilata con le schede DAHDI. Un numero inferiore al 99.987% indica possibili problemi.

##### Passaggio 5: Utilizzare l'utility dahdi_cfg per configurare il driver

DAHDI ha un sistema insolito per il caricamento dei driver. Configura prima /etc/dahdi/system.conf, quindi applica tali configurazioni al driver DAHDI utilizzando dahdi_cfg. In questo caso, dahdi_cfg viene utilizzato per configurare la segnalazione per le interfacce FX. Per vedere i risultati, puoi aggiungere "-vvvvv" al comando per la modalità dettagliata.

```
#
/sbin/dahdi_cfg -vv
Dahdi Configuration
======================
Channel map:
Channel 01: FXS Kewlstart (Default) (Slaves: 01)
Channel 02: FXO Kewlstart (Default) (Slaves: 02)
2 channels configured.
```

Se i canali sono stati caricati correttamente, vedrai un output simile a quello mostrato sopra. Gli utenti spesso configurano erroneamente chan_dahdi.conf con segnalazione invertita tra i canali. Se ciò accade, vedrai un messaggio come quello mostrato di seguito:

```
DAHDI_CHANCONFIG failed on channel 1: Invalid argument (22)
Did you forget that FXS interfaces are configured with FXO signalling
and that FXO interfaces use FXS signalling?
```

Dopo aver configurato correttamente l'hardware, puoi procedere alla configurazione di Asterisk.

##### Passaggio 6: Configurare il file /etc/asterisk/chan_dahdi.conf

Sembra strano, ma dopo aver configurato /etc/dahdi/system.conf, hai configurato la scheda stessa. DAHDI può essere utilizzato per altri scopi, come il routing e SS7. Per utilizzarlo con Asterisk, devi configurare i canali DAHDI di Asterisk. Ogni canale in Asterisk deve essere definito; i canali SIP/PJSIP sono definiti in pjsip.conf (nota: chan_sip e sip.conf sono stati rimossi in Asterisk 21) mentre i canali TDM sono definiti in chan_dahdi.conf. Questo crea i canali TDM logici da utilizzare nel tuo dialplan.

```
signalling=fxs_ks;                  ; FXS signaling for the FXO interface
group=1;                            ; channel group
context=incoming;                   ; context
channel => 1;                       ; channel number
signalling=fxo_ks;                  ; FXO signaling for the FXS interface
group=2;                            ; channel group
context=extensions;                 ; context
channel => 2                        ; channel number
```

### Opzioni di configurazione

Nel file chan_dahdi.conf sono disponibili diverse opzioni. Una descrizione di tutte le opzioni sarebbe noiosa e controproducente; invece, ci concentreremo sui principali gruppi di opzioni disponibili per una facile comprensione.

#### Opzioni generali (indipendenti dal canale)

Queste opzioni funzionano per qualsiasi canale: context: Definisce il contesto in entrata.

```
context=default
```

channel: Definisce il canale o l'intervallo di canali. Ogni definizione di canale erediterà le opzioni definite prima della dichiarazione. I canali possono essere identificati individualmente o sulla stessa riga separati da virgole. Gli intervalli possono essere definiti utilizzando "-".

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Consente ai canali di essere gestiti come un gruppo. Se componi un numero di gruppo invece di un numero di canale, viene utilizzato il primo canale disponibile. Se i canali sono telefoni, quando chiami un gruppo, tutti i telefoni squilleranno contemporaneamente. Con le virgole, puoi specificare più di un gruppo per lo stesso canale.

```
group=1
group=3,5
```

language: Attiva l'internazionalizzazione e configura una lingua. Questa funzione configurerà i messaggi di sistema per una lingua specifica. L'inglese è l'unica lingua con prompt completi disponibili tramite l'installazione standard. musiconhold: Seleziona la classe di musica in attesa.

#### Opzioni Caller ID

Ci sono molte opzioni per il callerid. Alcune possono essere disabilitate, sebbene la maggior parte sia abilitata per impostazione predefinita. usecallerid: Abilita o disabilita la trasmissione del callerid per i canali successivi (Yes/No). Nota: se il tuo sistema riceve due squilli prima di rispondere, prova a disabilitare questa funzione. Dovrebbe rispondere immediatamente. hidecallerid: Definisce se nascondere o meno il callerid in uscita (Yes/No). callerid: Configura una stringa callerid per un canale specifico. Il chiamante può essere configurato con asreceived. Questo viene utilizzato principalmente nelle interfacce trunk per indicare il callerid in entrata.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

callwaitingcallerid: Supporta il callerid durante l'avviso di chiamata. useincomingcalleridondahditransfer: Utilizza il callerid in entrata in un trasferimento.

#### Avviso di chiamata

Asterisk supporta l'avviso di chiamata nei canali FXS. L'utente riceverà un tono di attesa se qualcuno tenta di chiamare l'estensione. Per abilitare l'avviso di chiamata:

```
callwaiting=yes
```

Per supportare il callerid nell'avviso di chiamata:

```
callwaitingcallerid=yes
```

#### Opzioni di qualità audio

Regolare la cancellazione dell'eco è per metà tecnica, per metà arte. Queste opzioni regolano alcuni parametri di Asterisk che influenzano la qualità audio nei canali DAHDI. Possono aiutare a migliorare la qualità audio nelle interfacce analogiche.

#### L'utility fxotune

L'fxotune è un'utility utilizzata per ottimizzare alcuni parametri per i moduli FXO. Questa ottimizzazione è necessaria per regolare il disadattamento di impedenza causato dall'ibrido. L'utility ha tre modalità operative:

- Rilevamento (-i): rileva e corregge i canali FXO esistenti e salva la configurazione in

```
fxotune.conf
```

- Modalità dump (-d): genera i file della forma d'onda in fxotune_dump.vals
- Modalità avvio (-s): legge il file fxotune.conf e lo applica ai moduli FXO

È importante capire che dovrai inserire l'istruzione fxotune –s nel caricamento del sistema prima di avviare Asterisk:

```
#modprobe dahdi
#modprobe wctdm
#fxotune -s
```

### Cancellazione dell'eco

La maggior parte degli algoritmi di cancellazione dell'eco opera generando copie multiple del segnale ricevuto, in cui ognuna viene ritardata di una specifica quantità di tempo. Il numero di tap del filtro determina la dimensione del ritardo dell'eco che deve essere cancellato. Queste copie ritardate vengono quindi regolate e sottratte dal segnale ricevuto. Il trucco è regolare solo il segnale ritardato per rimuovere l'eco senza utilizzare troppi cicli CPU. Dal punto di vista degli utenti, è importante scegliere un algoritmo di cancellazione dell'eco appropriato. L'impostazione predefinita è MG2; tuttavia, sono disponibili altre due opzioni: l'High Performance Echo Cancellation (HPEC) di Sangoma (precedentemente Digium) e la cancellazione dell'eco open-source (OSLEC) sviluppata da David Rowe.

OSLEC (https://www.rowetel.com/?page_id=454) è stato unito al kernel Linux — risiede nell'area `drivers/staging/echo` del kernel — e DAHDI viene compilato con esso invece di distribuire un download separato. Per modificare l'algoritmo di cancellazione dell'eco, imposta il parametro `echo_can` in `/etc/dahdi/system.conf`. Ad esempio:

```
echo_can=oslec
```

La cancellazione dell'eco in Asterisk è controllata da tre parametri nel file /etc/asterisk/chan-

```
dahdi.conf.
```

- **echocancel**: Disabilita o abilita la cancellazione dell'eco. Dovresti mantenere questa funzione abilitata. Accetta "yes" o il numero di tap. (Spiegazione: come funziona la cancellazione dell'eco? La maggior parte degli algoritmi di cancellazione dell'eco opera generando copie multiple di un segnale ricevuto, con ognuna ritardata di un piccolo intervallo. Questo piccolo flusso è chiamato "tap". Il numero di tap determina il ritardo dell'eco che può essere cancellato. Queste copie vengono ritardate, regolate e sottratte dal segnale originale. Il trucco è regolare il segnale ritardato esattamente su ciò che è necessario per rimuovere l'eco.)
- **echocancelwhenbridged**: Abilita o disabilita il cancellatore di eco durante una chiamata TDM pura. Questo di solito non è necessario.
- **rxgain**: Regola il guadagno di ricezione audio per aumentare o diminuire il volume di ricezione (-100% a 100%).
- **txgain**: Regola il guadagno di trasmissione audio per aumentare o diminuire il volume di trasmissione (-100% a 100%).

Ad esempio:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Opzioni di fatturazione

Queste opzioni modificano il modo in cui le informazioni sulle chiamate vengono registrate nel database dei record di dettaglio delle chiamate (CDR). amaflags: Configura i flag AMA che influenzano la categorizzazione CDR. Accetta i seguenti valori:

- billing
- documentation
- omit
- default

accountcode: Configura un codice account per un canale specifico. Può contenere qualsiasi valore alfanumerico, solitamente il dipartimento o il nome utente.

```
accountcode=finance
amaflags=billing
```

### Opzioni di avanzamento chiamata

Questi elementi vengono utilizzati per acquisire informazioni sull'avanzamento della chiamata. Nelle interfacce pubbliche, può essere utile rilevare l'avanzamento della chiamata e determinare se ha risposto o se è occupato. Il rilevamento dell'occupato è altamente sperimentale e regolato da parametri specifici.

```
busydetect=yes
busycount=4
busypattern=500,500
callprogress=yes
progzone=br
```

Questi parametri (sopra) specificano se l'interfaccia tenterà di rilevare il segnale di occupato, quanti toni verranno utilizzati per un rilevamento riuscito e qual è il pattern di occupato. Il rilevamento dell'occupato è in gran parte sperimentale e alcuni parametri aggiuntivi possono essere modificati nel Makefile. Per rilevare la risposta di una chiamata, che è essenziale per una fatturazione precisa, è possibile utilizzare l'inversione di polarità per segnalare l'ora esatta della risposta. Questo è importante se prevedi di addebitare la chiamata o desideri semplicemente avere una fatturazione precisa per il confronto. Di solito devi contattare la compagnia telefonica per richiedere questo servizio.

```
answeronpolarityswitch=yes
```

In alcuni paesi, è possibile rilevare il riaggancio della chiamata utilizzando anche l'inversione di polarità.

```
hanguponpolarityswitch=yes
```

#### Opzioni per i telefoni

Queste opzioni vengono utilizzate per i telefoni collegati alle interfacce FXS. Tutte le funzionalità fornite ai telefoni analogici collegati direttamente alle interfacce DAHDI sono controllate da Asterisk.

- **adsi** (Analog Display Services Interface): Questo è un insieme di standard di telecomunicazione utilizzati da alcune compagnie telefoniche per offrire servizi come l'acquisto di biglietti.
- **cancallforward**: Abilita o disabilita l'inoltro di chiamata (*72 per abilitare e *73 per disabilitare).
- **calleridcallwaiting**: Abilita il callerid ricevuto durante un'indicazione di avviso di chiamata (Yes/No).
- **immediate**: In modalità immediata, invece di fornire un segnale di linea, il canale salta immediatamente all'estensione "s" nel contesto definito. Questo viene utilizzato per creare linee dirette.
- **threewaycalling**: Abilita o disabilita la conferenza a tre.
- **mailbox**: Avvisa l'utente di messaggi vocali disponibili. Può essere un segnale acustico o un indicatore visivo (se il telefono supporta questa funzione). L'argomento è il numero della casella vocale.
- **callgroup**: Raggruppa i telefoni per chiamare o per rispondere.
- **pickupgroup**: Gruppo di telefoni per la risposta alle chiamate.

### Comandi CLI DAHDI utili

Una volta che Asterisk è in esecuzione con i canali DAHDI caricati, puoi ispezionare lo stato del canale dalla CLI di Asterisk. Questi comandi rimangono attuali in Asterisk 22:

```
*CLI> dahdi show channels
*CLI> dahdi show channel 1
*CLI> module reload chan_dahdi.so
```

### Formato del canale DAHDI

I canali DAHDI utilizzano il seguente formato nel dialplan:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Ad esempio:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## Canali digitali (E1/T1/PRI / TDM)

A partire da Asterisk 22, DAHDI e libpri rimangono pienamente supportati, ma i trunk digitali TDM (E1/T1/ISDN PRI) vengono sempre più sostituiti dai trunk SIP nelle nuove implementazioni. Questa sezione rimane pienamente applicabile laddove sia richiesta connettività TDM; negli ambienti greenfield, il trunking SIP (Capitolo 3) solitamente offre la stessa densità di canali senza hardware di telefonia dedicato.

I canali digitali sono estremamente comuni, quindi sarà necessario imparare a implementarli se si desidera lavorare con grandi clienti. Quando il numero di canali è elevato — solitamente superiore a 8 — è piuttosto comune utilizzare interfacce digitali come T1/E1/J1. La T1 è molto comune negli Stati Uniti, mentre la E1 è comune in Europa e la J1 in Giappone. Questi tipi di canali consentono una buona densità di circuiti: 24 per canale T1 e 30 per canale E1.

In America Latina, Cina e Africa, è comune utilizzare un tipo di segnalazione associata al canale (CAS) nota come MFC/R2. Questo capitolo esaminerà come implementare MFC/R2 utilizzando la libreria OpenR2. Negli Stati Uniti e in Europa, la Integrated Services Digital Networks (ISDN) PRI è la segnalazione più comune. Il capitolo discuterà anche la ISDN Basic Rate Interface (BRI), molto comune in Europa nelle applicazioni di fascia media.

Tutti gli esempi nel libro si concentrano sui canali DAHDI. Alcune schede sono implementate utilizzando canali proprietari, quindi si prega di verificare con il produttore per ulteriori dettagli su come configurare la propria scheda specifica.

### Obiettivi

Al termine di questo capitolo sarai in grado di:

- Riconoscere i termini principali utilizzati nella telefonia digitale
- Differenziare la segnalazione CAS e CCS
- Differenziare la segnalazione R2 e ISDN
- Configurare interfacce con segnalazione ISDN
- Configurare interfacce con segnalazione R2

### Linee digitali E1/T1

Le linee digitali E1/T1 sono un'opzione ogni volta che è necessario implementare un gran numero di canali. Un singolo circuito E1 è in grado di gestire 30 chiamate simultanee e si possono avere funzionalità come il direct inward dial (DID), il Caller ID (identificazione del chiamante) e una segnalazione avanzata. La linea E1/T1 può arrivare in azienda in diversi modi utilizzando doppino intrecciato, fibra e microonde, a seconda del paese. Le linee digitali vengono consegnate alla propria azienda utilizzando UTP, fibra o microonde. Modem e multiplexer (MUX) vengono utilizzati per fornire la linea fisica. La connessione a una linea T1 si basa sempre su un connettore RJ45. Tuttavia, le linee E1 possono essere fornite anche utilizzando BNC. È molto importante conoscere in anticipo il tipo di connettore che si riceverà, principalmente nelle linee E1. Solitamente tutta l'attrezzatura fino all'RJ45 è fornita dalla TELCO.

![Come vengono forniti i circuiti E1/T1: la telco può fornire il trunk su rame UTP (modem HDSL per E1, o una connessione diretta alla scheda per T1), su fibra ottica tramite un multiplexer ottico, o su un collegamento radio a microonde.](../images/10-legacy-fig05.png)

![UTP o BNC? La maggior parte delle schede digitali utilizza connettori RJ45 (UTP), ma alcune linee E1 vengono fornite su doppio cavo coassiale BNC, nel qual caso è necessario un balun per adattare la coppia coassiale al jack RJ45 della scheda.](../images/10-legacy-fig06.png)

#### Come viene convertita la voce in bit?

Il segnale analogico viene campionato 8.000 volte al secondo per creare una versione digitale della voce analogica. Questa codifica è nota come pulse code modulation (PCM). Negli Stati Uniti e in Giappone, il segnale viene codificato utilizzando la legge mu (in Asterisk, indicata come ulaw). Nel resto del mondo, la codifica è alaw.

![Pulse code modulation (PCM): il segnale vocale analogico a 4 kHz viene campionato 8.000 volte al secondo (Nyquist) e codificato in un flusso di bit digitale a 64 Kbps.](../images/10-legacy-fig07.png)

#### Time Division Multiplexing

Le linee analogiche hanno senso quando servono solo pochi canali. Quando si utilizza il time division multiplexing (TDM), è possibile inserire più canali in un'unica connessione dati. Quando si desidera un gran numero di circuiti, la compagnia telefonica solitamente fornirà un trunk digitale, che è un circuito dati in cui la voce viene trasportata in formato digitale utilizzando PCM. Ogni timeslot utilizza 64 Kbps di larghezza di banda per trasportare un singolo canale vocale.

![Time-division multiplexing in E1 e T1: un frame E1 trasporta 32 timeslot a 2048 Kbps (DS0 #0 per la sincronizzazione del frame, DS0 #16 per la segnalazione), mentre un frame T1 trasporta 24 timeslot a 1544 Kbps utilizzando un bit per la sincronizzazione e uno schema a bit sottratti per la segnalazione.](../images/10-legacy-fig08.png)

Negli Stati Uniti, il trunk digitale più comune è la T1, che ha 24 linee disponibili; in Europa e America Latina, i trunk E1 hanno 30 linee. Alcune aziende forniscono una T1/E1 frazionata con meno canali. Robbed bit signaling: a volte un trunk T1 utilizza uno schema a bit sottratti (robbed bit) in cui un bit viene preso in prestito per la segnalazione. Sui trunk T1, il canale dati/voce viene trasmesso a 56 Kbps su ogni timeslot. Come si può osservare, quando si utilizza il robbed bit, il circuito T1 non perde due slot per la sincronizzazione e la segnalazione.

#### Codice di linea T1/E1

Le T1 e le E1 sono in realtà circuiti dati e hanno una codifica dei dati che determina il modo in cui i bit vengono interpretati. Per le E1, il codice di linea più comune è HDB3 per il layer 1 e CCS per il layer 2. Il modo più semplice per sapere come è configurato il proprio trunk digitale è chiedere queste informazioni alla TELCO. Saranno necessarie per configurare il file /etc/dahdi/system.conf.

#### Segnalazione T1/E1

È importante capire che le linee T1/E1 possono essere fornite utilizzando diversi tipi di segnalazione, come:

- T1 con segnalazione robbed bit
- T1 con segnalazione ISDN
- E1 con MFC/R2 (CAS - Channel Associated Signaling)
- E1 con segnalazione ISDN

ISDN è spesso utilizzata in Europa e negli Stati Uniti. È una rete vocale digitale, standardizzata dall'International Telecommunications Union (ITU) nel 1984. ISDN fornisce due tipi di canali:

- Canali bearer (portanti)
  - Voce
  - Dati
- Canali dati
  - Segnalazione out of band
  - Segnalazione LAPD
  - Q.931

Solitamente, una linea ISDN viene fornita utilizzando due mezzi fisici:

- Basic rate interface (BRI)
  - Nota come 2B+D
  - Due canali bearer (64K) e un canale dati (16K)
  - Utilizza una coppia di fili di rame a 148Kbps.
- Primary rate interface (PRI)
  - Fornita utilizzando un trunk T1/E1
  - 23B+D per le T1
  - 30B+D per le E1

A volte, i circuiti E1 utilizzano uno schema di segnalazione CAS chiamato MFC/R2, definito dall'ITU come uno standard noto come Q.421/Q441. Si trova frequentemente in America Latina e in Asia. Diverse compagnie telefoniche in questi paesi utilizzano varianti personalizzate di MFC/R2. Pertanto, sarà necessario conoscere la corretta variante nazionale per farla funzionare.

### ISDN BRI

I canali che utilizzano la segnalazione ISDN BRI sono molto popolari in Europa. La maggior parte delle schede ISDN BRI per Asterisk supporta un'interfaccia S/T con capacità NT e TE. La connessione TE (terminale) è quella utilizzata per connettersi alla TELCO o ad altri PBX configurati come terminazione di rete (NT). L'NT viene utilizzato per collegare telefoni e PBX configurati come TE. ISDN BRI fornisce due canali dati/voce e un canale di segnalazione. Le schede ISDN BRI sono disponibili presso diversi fornitori di schede di interfaccia per Asterisk.

### Scelta di una scheda di telefonia per il server Asterisk

Esistono diversi produttori di schede digitali compatibili con Asterisk. La scelta di una scheda dipende da alcuni dei seguenti fattori:

#### Bus dati

Esistono diversi tipi di bus sul PC. È molto importante avere la scheda giusta per il server. La seguente panoramica delinea le schede utilizzate più frequentemente:

- PCI 32 bit 5V presente nella maggior parte dei computer, inclusi i desktop
  - Sangoma (precedentemente Digium) TE405, TE407, TE205, TE207, TE120, TE122, B410, TDM2400, TDM800, TDM410 e TC400
  - Sangoma A101, A102 e A104
- PCI 32/64 bit 3.3V, presente fondamentalmente nei server
  - Sangoma (precedentemente Digium) TE410, TE412, TE210, TE212, TE120, TE122, B410, TDM2400, TDM800, TDM410 e TC400
- PCI Express presente su desktop e server
  - Sangoma (precedentemente Digium) TE420, TE220, TE121, AEX2400 e AEX800
  - Sangoma A101, A102 e A104

Queste famiglie di schede hanno avuto origine in Digium, acquisita da Sangoma nel 2018; ora sono vendute e supportate con il marchio Sangoma. Molti dei vecchi codici prodotto elencati qui sono stati dismessi, quindi verificare l'attuale disponibilità dei modelli su www.sangoma.com prima dell'acquisto.

- MiniPCI presente su sistemi embedded
  - OpenVOX A100M(FXO), B100M(ISDN BRI), B200M(ISDN BRI) e B400M(ISDN BRI)
- USB 2.0 presente nella maggior parte dei PC moderni. Le soluzioni basate su USB consentono una grande densità di canali analogici e digitali. Questo bus supporta 480 Mbps e ogni canale vocale occupa 64 Kbps. Quando si utilizzano hub USB, è possibile ottenere densità fino a mille porte analogiche in una singola porta.
  - Xorcom Astribank (FXS, FXO, E1-ISDN, E1-R2)
- Ethernet. Il più grande vantaggio di Ethernet è consentire alla scheda di essere collegata da più di un server. Le soluzioni ad alta disponibilità sono solitamente l'applicazione principale per questi dispositivi. Il punto di forza di questa soluzione è l'utilizzo di server senza slot PCI liberi o server blade.
  - Redfone FoneBridge (fino a quattro circuiti E1)

### Utilizzo della cancellazione dell'eco hardware

La cancellazione dell'eco hardware riduce il carico sulla CPU host. Per le schede con più di una singola interfaccia E1, la cancellazione dell'eco hardware può aiutare ad alleviare il processore. I nuovi cancellatori di eco software avanzati come OSLEC stanno riducendo la necessità di un cancellatore di eco hardware. Per scegliere tra cancellatori di eco hardware e software, dovresti considerare la potenza di elaborazione disponibile nel tuo server e il numero di circuiti E1. Un processo di cancellazione dell'eco può utilizzare fino a nove MIPS (milioni di istruzioni al secondo) per canale vocale con 128 tap di ampiezza utilizzando OSLEC (Riferimento: Xorcom Ltd.). Se consideri 1 ciclo CPU per ogni istruzione (il che non è sempre corretto in base al processore e all'implementazione software stessa), stiamo parlando di 1.080 Ghz per quattro E1.

#### Tipo di segnalazione

Selezionare il tipo di segnalazione (es. T1 CAS, T1 PRI, E1 CAS R2 o E1 CAS ISDN) non è un compito facile. Dipende davvero da ciò che hai a disposizione nella tua zona e a quale prezzo. La Common Channel Signaling (CCS) è spesso migliore della channel associated signaling (CAS). Tuttavia, spesso non è disponibile. Negli Stati Uniti, di solito puoi scegliere, poiché la maggior parte delle TELCO offre T1 CAS per gli utenti normali e T1 PRI per gli utenti avanzati (es. call center). In America Latina, la E1 CAS R2 è prevalente, ma la ISDN PRI è disponibile in alcune città.

![L'architettura software DAHDI: Asterisk comunica con il driver di canale `chan_dahdi`, che a sua volta carica le librerie di protocollo libpri (ISDN), libopenr2 (MFC/R2) e libss7 (SS7); queste si trovano sopra l'interfaccia `/dev/dahdi`, il driver del kernel DAHDI e il driver del kernel dell'interfaccia specifica della scheda.](../images/10-legacy-fig09.png)

L'implementazione di R2 è necessaria per installare una libreria nota come OpenR2 (www.libopenr2.org), sviluppata da Moises Silva, e per patchare Asterisk prima dell'installazione — una procedura semplice mostrata più avanti in questo capitolo. La libreria ha superato diversi test ed è in produzione presso diversi nostri clienti. ISDN è, a mio parere, sempre la scelta migliore, se disponibile. Alcuni provider possono avere accesso al signaling system 7 (SS7), che è una segnalazione CCS disponibile tra le compagnie telefoniche. Sono disponibili soluzioni proprietarie e open source per SS7. La libreria libss7 viene utilizzata per supportare SS7 su Asterisk.

### Configurazione dei canali di telefonia Asterisk

Configurare una scheda di interfaccia telefonica comporta diversi passaggi necessari. In questo capitolo, mostreremo tre degli scenari più comuni:

- Connessione digitale utilizzando ISDN PRI
- Connessione digitale utilizzando ISDN BRI
- Connessione digitale utilizzando MFC/R2

Esistono due modi per configurare i canali DAHDI. Il primo consiste nel configurarli manualmente con il controllo completo di tutti i parametri. Il secondo modo consiste nell'utilizzare l'utility dahdi_genconf per rilevare e configurare le schede.

#### Rilevamento e configurazione automatici

Grazie al team di sviluppo DAHDI, ora abbiamo il rilevamento e la configurazione automatici delle schede. Passaggio 1: Per generare la configurazione automaticamente, utilizzare l'utility dahdi_genconf, che rileverà la scheda e genererà i file /etc/dahdi/system.conf e dahdi-channels.conf.

```
dahdi_genconf
```

Passaggio 2: Nell'ultima riga del file chan_dahdi.conf, includere il file dahdi-channels.conf

```
#include dahdi_channels.conf
```

Passaggio 3: Commentare tutti i moduli inutilizzati nel file modules o semplicemente utilizzare:

```
dahdi_genconf modules
```

#### Configurazione manuale

Un'altra opzione è configurare le interfacce manualmente. Di seguito sono riportati alcuni esempi della configurazione per i canali DAHDI.

##### Esempio #1 – Due canali T1/ E1 utilizzando ISDN

Passaggi richiesti:

1. Installazione TE205P o TE210P
2. Configurazione del file `/etc/dahdi/system.conf`
3. Caricamento del driver DAHDI
4. Utility `dahdi_test`
5. Utility `dahdi_cfg`
6. Configurazione del file `chan_dahdi.conf`
7. Caricamento e test di Asterisk

Passaggio 1: Installazione TE205P. Prima di installare la TE205P, è importante comprendere le differenze tra le schede TE205P e TE210P. La scheda TE210P utilizza un bus a 64 bit alimentato a 3,3 volt che si trova quasi solo nelle schede madri dei server. Fai attenzione se specifichi questa scheda di interfaccia; assicurati che il tuo hardware supporti un bus a 64 bit, 3,3V. La scheda TE205P utilizza un PCI a 5V, che si trova spesso nei computer desktop. Abbiamo scelto la scheda di interfaccia TE205P con due span per questo esempio perché è più facile ridurla a una scheda a uno span o espanderla alla scheda a quattro span. Queste schede sono ora vendute con il marchio Sangoma (precedentemente Digium).

![Una scheda E1/T1 a doppio span Sangoma/Digium TE205P: le due porte RJ45 accettano i trunk digitali e un jumper integrato (il selettore E1/T1/J1) imposta lo standard di linea.](../images/10-legacy-fig10.png)

```
Step 2: /etc/dahdi/system.conf configuration file
```

La configurazione delle schede digitali TDM è un po' diversa dalla configurazione delle loro controparti analogiche. Per prima cosa, dovremo configurare gli span della scheda e poi i canali. Gli span sono numerati sequenzialmente a seconda dell'ordine di riconoscimento delle schede. In altre parole, se hai più di una scheda di interfaccia, è difficile sapere quale span appartiene a ciascuna. Usa dahdi_hardware per verificare quale hardware è installato su ogni span. Esempio #1 (2xT1 PRI)

```
span=1,1,0,esf,b8zs
span=2,0,0,esf,b8zs
bchan=1-23
dchan=24
bchan=25-47
dchan=48
defaultzone=us
loadzone=us
```

Esempio #2 (2xE1 PRI)

```
span=1,1,0,ccs,hdb3,crc4 # not always necessary, consult Telco.
span=2,0,0,ccs,hdb3,crc4
bchan=1-15, 17-31
dchan=16
bchan=33-47, 49-63
dchan=48
defaultzone=br
loadzone=br
```

Esempio #3 (4xBRI)

```
loadzone=de
defaultzone=de
span=1,1,0,ccs,ami
bchan=1,2
hardhdlc=3
span=2,0,0,ccs,ami
bchan=4,5
hardhdlc=6
span=3,0,0.ccs.ami
bchan=7,8
hardhdlc=9
span=4,0,0,ccs,ami
bchan=10,11
hardhdlc=12
```

Passaggio 3: Caricamento dei driver del kernel Verifica quale driver devi installare utilizzando dahdi_hardware.

```
dahdi_hardware
pci:0000:04:02.0     wcte2xxp    e159:0001 Sangoma Wildcard TE205P T1/E1 Board
```

Per caricare usa:

```
modprobe dahdi
modprobe wct2xxp
```

Passaggio 4: Utilizzando dahdi_test, controlla gli interrupt mancanti. Puoi verificare il numero di interrupt mancanti utilizzando l'utility dahdi_test compilata con le schede DAHDI. Un numero inferiore al 99,987% indica possibili problemi. Troverai dahdi_test in

```
/usr/sbin.
#./dahdi_test
Opened pseudo zap interface, measuring accuracy...
99.987793% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 99.987793% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000%
--- Results after 26 passes ---
Best: 100.000000 -- Worst: 99.987793 -- Average: 99.999061
```

Passaggio 5: Utilizzando l'utility dahdi_cfg. Questo è l'output corretto di dahdi_cfg per uno span E1 frazionario (15 porte) e due porte FXO.

```
#./dahdi_cfg -vvvv
Dahdi configuration
======================
SPAN 1: CCS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: Clear channel (Default) (Slaves: 01)
Channel 02: Clear channel (Default) (Slaves: 02)
Channel 03: Clear channel (Default) (Slaves: 03)
Channel 04: Clear channel (Default) (Slaves: 04)
Channel 05: Clear channel (Default) (Slaves: 05)
Channel 06: Clear channel (Default) (Slaves: 06)
Channel 07: Clear channel (Default) (Slaves: 07)
Channel 08: Clear channel (Default) (Slaves: 08)
Channel 09: Clear channel (Default) (Slaves: 09)
Channel 10: Clear channel (Default) (Slaves: 10)
Channel 11: Clear channel (Default) (Slaves: 11)
Channel 12: Clear channel (Default) (Slaves: 12)
Channel 13: Clear channel (Default) (Slaves: 13)
Channel 14: Clear channel (Default) (Slaves: 14)
Channel 15: Clear channel (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
16 channels configured.
```

Passaggio 6: Configurazione di DAHDI nel file /etc/asterisk/chan_dahdi.conf Esempio #1 (2xT1)

```
callerid="John Doe"<(555)555-1111>
switchtype=national
signalling =pri_cpe
context=from-pstn
group = 1
channel => 1-23
group =2
channel => 25-47
```

Esempio #2 (2xE1)

```
callerid="Flavio Eduardo" <4830258580>
switchtype=euroisdn
signalling = pri_cpe
group = 1
channel => 1-15;17-31
group =2
channel => 32-46;48-62
```

Esempio #3 (4xBRI)

```
signaling=bri_cpe
switchtype=euroisdn
group=1
context=from-pstn
channel=>1,2,4,5,7,8,10,11
```

Usa signaling=bri_cpe_ptmp per BRI punto-multipunto. Attualmente, la BRI punto-multipunto non è supportata in modalità NT.

#### Caricamento dei driver del kernel

Dopo aver configurato i driver, puoi semplicemente riavviare il server. Se hai installato DAHDI con make config, non avrai bisogno di fare nulla di extra. Il driver del kernel verrà caricato e configurato automaticamente. Tuttavia, a volte è utile caricare e scaricare i driver manualmente. Esempio:

```
modprobe wct11xp
dahdi_cfg -vvvvv
```

Il primo comando carica il driver e il secondo, dahdi_cfg, applica la configurazione al driver del kernel.

### Risoluzione dei problemi

A volte le cose non funzionano al primo colpo. Controlliamo alcune risorse per la risoluzione dei problemi di DAHDI. Passaggio 1: Controlla se la scheda viene riconosciuta dal sistema operativo. Le schede Sangoma/Digium sono solitamente riconosciute come modem ISDN.

```
lspci -v
00:00.0 Host bridge: Intel Corporation E7230/3000/3010 Memory Controller Hub
00:01.0 PCI bridge: Intel Corporation E7230/3000/3010 PCI Express Root Port
00:1c.0 PCI bridge: Intel Corporation 82801G (ICH7 Family) PCI Express Port 1 (rev 01)
00:1c.4 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 5 (rev
01)
00:1c.5 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 6 (rev
01)
00:1d.0 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #1 (rev
01)
00:1d.1 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #2 (rev
01)
00:1d.2 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #3 (rev
01)
00:1d.7 USB Controller: Intel Corporation 82801G (ICH7 Family) USB2 EHCI Controller (rev 01)
00:1e.0 PCI bridge: Intel Corporation 82801 PCI Bridge (rev e1)
00:1f.0 ISA bridge: Intel Corporation 82801GB/GR (ICH7 Family) LPC Interface Bridge (rev 01)
00:1f.1 IDE interface: Intel Corporation 82801G (ICH7 Family) IDE Controller (rev 01)
00:1f.2 IDE interface: Intel Corporation 82801GB/GR/GH (ICH7 Family) SATA IDE Controller (rev
01)
00:1f.3 SMBus: Intel Corporation 82801G (ICH7 Family) SMBus Controller (rev 01)
01:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
01:00.1 PIC: Intel Corporation 6700/6702PXH I/OxAPIC Interrupt Controller A (rev 09)
02:08.0 SCSI storage controller: LSI Logic / Symbios Logic SAS1068 PCI-X Fusion-MPT SAS (rev
01)
03:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
04:02.0 Network controller: Tiger Jet Network Inc. Tiger3XX Modem/ISDN interface
05:00.0 Ethernet controller: Broadcom Corporation NetXtreme BCM5721 Gig. Eth.PCI Express (rev
11)
07:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL-8139/8139C/8139C+ (rev 10)
07:05.0 VGA compatible controller: ATI Technologies Inc ES1000 (rev 02)
```

Passaggio 2: Controlla se il driver del kernel si sta caricando correttamente utilizzando:

```
modprobe wct11xp
dmesg
TE110P: Setting up global serial parameters for E1 FALC V1.2
TE110P: Successfully initialized serial bus for card
TE110P: Span configured for CAS/HDB3
Calling startup (flags is 4099)
Found a Wildcard: Sangoma Wildcard TE110P T1/E1
TE110P: Span configured for CCS/HDB3/CRC4
Calling startup (flags is 4099)
dahdi: Registered tone zone 0 (United States / North America)
wcte1xxp: Setting yellow alarm
```

Passaggio 3: Verifica lo stato degli allarmi relativi al livello fisico della connessione. Per verificare il livello fisico della connessione E1, puoi utilizzare il seguente comando CLI di Asterisk.

```
dahdi show status
```

Gli allarmi indicano problemi con la porta: Red Alarm: Impossibile mantenere la sincronizzazione con lo switch remoto. Questo è solitamente un problema fisico, come un codice di linea o un disallineamento del framing. Yellow alarm: Segnala che lo switch remoto è in allarme rosso. Ciò indica che lo switch remoto non sta ricevendo le tue trasmissioni. Blue Alarm: Riceve tutti 1 non incorniciati su tutti i timeslot; dahdi_tool attualmente non rileva un allarme blu. Loopback: La porta è in loopback locale o remoto.

```
vtsvoffice*CLI> dahdi show status
Description                              Alarms     IRQ        bpviol     CRC4
Sangoma Wildcard E100P E1/PRA Card 0      OK         0          0          0
Wildcard X100P Board 1                   OK         0          0          0
Wildcard X100P Board 2                   RED        0          0          0
```

Passaggio 4: Per rilevare problemi con DAHDI sul server Asterisk, controlla prima se i canali vengono riconosciuti utilizzando:

```
dahdi show channels
pabxip01*CLI> dahdi show channels
   Chan Extension  Context         Language   MOH Interpret
 pseudo            default                    default
      1            from-pstn                  default
      2            from-pstn                  default
      3            from-pstn                  default
      4            from-pstn                  default
      5            from-pstn                  default
      6            from-pstn                  default
      7            from-pstn                  default
      8            from-pstn                  default
      9            from-pstn                  default
     10            from-pstn                  default
     11            from-pstn                  default
     12            from-pstn                  default
     13            from-pstn                  default
     14            from-pstn                  default
     15            from-pstn                  default
     17            from-pstn                  default
     18            from-pstn                  default
     19            from-pstn                  default
     20            from-pstn                  default
     21            from-pstn                  default
     22            from-pstn                  default
     23            from-pstn                  default
     24            from-pstn                  default
     25            from-pstn                  default
     26            from-pstn                  default
     27            from-pstn                  default
     28            from-pstn                  default
     29            from-pstn                  default
     30 2171       from-pstn                  default
     31 2171       from-pstn                  default
```

Passaggio 5: Controlla lo stato del livello 3 ISDN, noto anche come q.931. Puoi controllare se il livello 3 ISDN è attivo utilizzando: `pri show spans` (per elencare tutti gli span) o `pri show span <n>` per uno span specifico:

```
vtsvoffice*CLI> pri show span 1
Primary D-channel: 16
Status: Provisioned, Up, Active
Switchtype: EuroISDN
Type: CPE
Window Length: 0/7
Sentrej: 0
SolicitFbit: 0
Retrans: 0
Busy: 0
Overlap Dial: 0
T200 Timer: 1000
T203 Timer: 10000
T305 Timer: 30000
T308 Timer: 4000
T313 Timer: 4000
N200 Counter: 3
```

Usa `pri show spans` (plurale) per elencare lo stato di tutti gli span PRI configurati contemporaneamente.

Controlla un canale specifico. dahdi show channel x:

```
vtsvoffice*CLI> dahdi show channel 1
Channel: 1
File Descriptor: 21
Span: 1
Extension:
Dialing: no
Context: entrada
Caller ID: 4832341689
Calling TON: 33
Caller ID name:
Destroy: 0
InAlarm: 0
Signalling Type: PRI Signalling
Radio: 0
Owner: <None>
Real: <None>
Callwait: <None>
Threeway: <None>
Confno: -1
Propagated Conference: -1
Real in conference: 0
DSP: no
Relax DTMF: no
Dialing/CallwaitCAS: 0/0
Default law: alaw
```

debug pri span x: Se dopo tutto hai ancora problemi, inizia a fare il debug dello span pri. Questo comando abilita un debug dettagliato delle chiamate ISDN. È un comando importante quando pensi che qualcosa non sia corretto. Puoi rilevare cifre composte in modo errato e altri problemi. Di seguito presentiamo l'esempio di un output di debug per una chiamata riuscita. Fai riferimento a questo esempio se devi confrontare una chiamata non riuscita con una senza problemi. Un consiglio è usare core set verbose=0 per ricevere solo i messaggi ISDN q.931.

```
-- Making new call for cr 32833
> Protocol Discriminator: Q.931 (8)  len=57
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: SETUP (5)
> [04 03 80 90 a3]
> Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
>                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
>                              Ext: 1  User information layer 1: A-Law (35)
> [18 03 a9 83 81]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 1 ]
> [28 0e 46 6c 61 76 69 6f 20 45 64 75 61 72 64 6f]
> Display (len=14) @h@>[ Flavio Eduardo ]
> [6c 0c 21 80 34 38 33 30 32 35 38 35 39 30]
> Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
>                           Presentation: Presentation permitted, user number not screened
(0) '4830258590' ]
> [70 09 a1 33 32 32 34 38 35 38 30]
> Called Number (len=11) [ Ext: 1  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '32248580' ]
> [a1]
> Sending Complete (len= 1)
< Protocol Discriminator: Q.931 (8)  len=10
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CALL PROCEEDING (2)
< [18 03 a9 83 81]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 1 ]
-- Processing IE 24 (cs0, Channel Identification)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: ALERTING (1)
< [1e 02 84 88]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Inband information or
appropriate pattern now available. (8) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=64
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: SETUP (5)
< [04 03 80 90 a3]
< Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
<                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
<                              Ext: 1  User information layer 1: A-Law (35)
< [18 03 a1 83 82]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Preferred Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 2 ]
< [1c 15 91 a1 12 02 01 bc 02 01 0f 30 0a 02 01 01 0a 01 00 a1 02 82 00]
< Facility (len=23, codeset=0) [ 0x91, 0xa1, 0x12, 0x02, 0x01, 0xbc, 0x02, 0x01, 0x0f, '0',
0x0a, 0x02, 0x01, 0x01, 0x0a, 0x01, 0x00, 0xa1, 0x02, 0x82, 0x00 ]
< [1e 02 82 83]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the local user (2)
<                               Ext: 1  Progress Description: Calling equipment is non-ISDN.
(3) ]
< [6c 0c 21 83 34 38 33 32 32 34 38 35 38 30]
< Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
<                           Presentation: Presentation allowed of network provided number (3)
'4832248580' ]
< [70 05 c1 38 35 38 30]
< Called Number (len= 7) [ Ext: 1  TON: Subscriber Number (4)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '8580' ]
< [a1]
< Sending Complete (len= 1)
-- Making new call for cr 5720
-- Processing Q.931 Call Setup
-- Processing IE 4 (cs0, Bearer Capability)
-- Processing IE 24 (cs0, Channel Identification)
-- Processing IE 28 (cs0, Facility)
Handle Q.932 ROSE Invoke component
-- Processing IE 30 (cs0, Progress Indicator)
-- Processing IE 108 (cs0, Calling Party Number)
-- Processing IE 112 (cs0, Called Party Number)
-- Processing IE 161 (cs0, Sending Complete)
> Protocol Discriminator: Q.931 (8)  len=10
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CALL PROCEEDING (2)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> Protocol Discriminator: Q.931 (8)  len=14
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CONNECT (7)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> [1e 02 81 82]
> Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Private network serving the local user (1)
>                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: CONNECT ACKNOWLEDGE (15)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: PROGRESS (3)
< [1e 02 84 82]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CONNECT (7)
> Protocol Discriminator: Q.931 (8)  len=5
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: CONNECT ACKNOWLEDGE (15)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Active, peerstate Connect Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: DISCONNECT (69)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: RELEASE (77)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Release Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: RELEASE COMPLETE (90)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: DISCONNECT (69)
< [08 02 82 90]
< Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Public network
serving the local user (2)
<                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
-- Processing IE 8 (cs0, Cause)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Disconnect Indication, peerstate Disconnect
Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: RELEASE (77)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: RELEASE COMPLETE (90)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
```

### Opzioni di configurazione in chan_dahdi.conf

Diverse opzioni sono disponibili nel file chan_dahdi.conf. Una descrizione di tutte le opzioni sarebbe noiosa e controproducente. Qui, dettaglieremo i principali gruppi di opzioni disponibili per fornire una migliore comprensione.

#### Opzioni generali (indipendenti dal canale)

context: Definisce il contesto in entrata.

```
context=default
```

channel: Definisce il canale o l'intervallo di canali. Ogni definizione di canale erediterà le opzioni definite prima della dichiarazione. I canali possono essere identificati individualmente o nella stessa riga con separazione tramite virgola. Gli intervalli possono essere definiti utilizzando “-”.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Consente ai canali di essere trattati come un gruppo. Se componi un numero di gruppo invece di un numero di canale, viene utilizzato il primo canale disponibile. Se i canali sono telefoni, quando chiami un gruppo, tutti i telefoni squilleranno contemporaneamente. Utilizzando le virgole, puoi specificare più di un gruppo per lo stesso canale.

```
group=1
group=3,5
```

language: Attiva l'internazionalizzazione e configura una lingua. Questa funzione configurerà i messaggi di sistema per una lingua specifica. L'inglese è l'unica lingua con prompt completi disponibili dall'installazione standard. musiconhold: Seleziona la classe di musica d'attesa.

#### Opzioni ISDN

switchtype: Dipende dal PBX o dallo switch utilizzato. In Europa e America Latina, EuroISDN è comune.

- 5ess: Lucent 5ESS
- euroisdn: EuroISDN
- national: National ISDN
- dms100: Nortel DMS100
- 4ess: AT&T 4ESS
- Qsig: Q.SIG

```
switchtype = EuroISDN
```

pridialplan: Richiesto per alcuni switch che necessitano di una specifica del piano di numerazione. Questa opzione viene ignorata da molti switch. Le opzioni valide sono private, national, international e unknown.

```
pridialplan = unknown
```

prilocaldialplan: Necessario per alcuni switch, solitamente unknown.

```
prilocaldialplan = unknown
```

overlapdial: La selezione a sovrapposizione (overlap dialing) viene utilizzata quando si passano cifre dopo che la connessione è stata stabilita. Puoi utilizzare la numerazione in modalità blocco (overlapdial=no) o in modalità cifra (overlapdial=yes). La modalità blocco è spesso utilizzata dagli operatori. signaling: Configura il tipo di segnalazione per i canali successivi. Questi parametri dovrebbero corrispondere a quelli nel file chan_dahdi.conf. Le scelte corrette si basano sul canale disponibile. Per ISDN potresti scegliere cinque opzioni:

- pri_cpe: Utilizzato quando il dispositivo è un CPE, a volte indicato come client, utente o slave. Questa è la forma di segnalazione più semplice e utilizzata. A volte, quando provi a connetterti a un PBX privato, anche il PBX è stato comunemente configurato come CPE. In questo caso, usa la segnalazione pri_net in Asterisk.
- pri_net: Utilizzato quando Asterisk è collegato a un PBX privato configurato come CPE. La segnalazione è spesso indicata come host, master o network.
- bri_cpe: Utilizzato quando Asterisk è collegato come CPE a un trunk ISDN BRI.
- bri_net: Utilizzato quando Asterisk è collegato a un telefono ISDN o a un PBX configurato come terminale (TE).
- bri_cpe_ptmp: Come bri_cpe, ma in un'architettura punto-multipunto.

#### Opzioni CallerID

Sono disponibili molte opzioni per il Caller ID. Alcune possono essere disabilitate, sebbene la maggior parte sia abilitata per impostazione predefinita. usecallerid: Abilita o disabilita la trasmissione del Caller ID per i canali successivi (Yes/No). Nota: Se il tuo sistema richiede due squilli prima di rispondere, prova a disabilitare questa funzione in modo che risponda immediatamente. hidecallerid: Nasconde il Caller ID (Yes/No). calleridcallwaiting: Abilita la ricezione del Caller ID durante un'indicazione di avviso di chiamata (Yes/No). callerid: Configura una stringa Caller ID per un canale specifico. Il chiamante può essere configurato con “asreceived” nelle interfacce trunk per inoltrare il Caller ID.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

Nota: La maggior parte delle TELCO richiede di configurare il proprio Caller ID corretto. Se non passi il Caller ID giusto, non dovresti essere in grado di chiamare verso l'esterno tramite la TELCO. D'altra parte, sarai in grado di ricevere chiamate anche senza configurare il Caller ID.

#### Opzioni di qualità audio

Queste opzioni regolano alcuni parametri di Asterisk che influenzano la qualità audio nei canali DAHDI.

- **echocancel**: Disabilita o abilita la cancellazione dell'eco. Dovresti mantenere questa funzione abilitata. Accetta "yes" o il numero di tap. (Spiegazione: Come funziona la cancellazione dell'eco? La maggior parte degli algoritmi di cancellazione dell'eco opera generando copie multiple di un segnale ricevuto, ognuna delle quali viene ritardata di un piccolo intervallo. Questo piccolo flusso è chiamato "tap". Il numero di tap determina il ritardo dell'eco che può essere cancellato. Queste copie vengono ritardate, regolate e sottratte dal segnale originale. Il trucco è regolare il segnale ritardato esattamente su ciò che è necessario per rimuovere l'eco.)
- **echocancelwhenbridged**: Abilita o disabilita il cancellatore di eco durante una chiamata TDM pura. Solitamente non è richiesto.
- **rxgain**: Regola il guadagno di ricezione audio per aumentare o diminuire il volume di ricezione (-100% a 100%).
- **txgain**: Regola il guadagno di trasmissione audio per aumentare o diminuire il volume di trasmissione (-100% a 100%).

Esempio:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Opzioni di fatturazione

Queste opzioni cambiano il modo in cui le informazioni sulle chiamate vengono registrate nel database dei call detail records (CDR). amaflags: Influisce sulla categorizzazione dei CDR. Accetta questi valori:

- billing
- documentation
- omit
- default

accountcode: Configura un codice account per un canale specifico. Può contenere qualsiasi valore alfanumerico, solitamente il dipartimento o il nome utente.

```
accountcode=finance
amaflags=billing
```

### Configurazione MFC/R2

MFC/R2 è utilizzato in diversi paesi in America Latina, Cina e Africa, così come in alcuni paesi europei. ISDN è superiore e preferibile se disponibile nella tua zona.

#### Comprendere il problema

La scheda utilizzata per segnalare MFC/R2 è la stessa utilizzata per segnalare ISDN. È possibile utilizzare MFC/R2 sui canali DAHDI utilizzando la libreria chiamata libopenR2 (www.libopenr2.com). Questa libreria non faceva parte delle versioni di Asterisk precedenti alla 1.6.2.

##### Comprendere il protocollo MFC/R2

Il protocollo MFC/R2 combina la segnalazione in-band e out-of-band. La segnalazione dell'indirizzo viene inoltrata in-band utilizzando una serie di toni, mentre le informazioni sul canale vengono trasmesse sul timeslot 16 come segnalazione out-of-band.

**Segnalazione di linea (ITU-T Q.421).** Nel timeslot 16, ogni canale vocale utilizza quattro bit ABCD per segnalare i suoi stati e il controllo di chiamata. I bit C e D sono raramente utilizzati. In alcuni paesi, possono essere utilizzati per la misurazione (misurazione a impulsi per la fatturazione). In una conversazione normale, abbiamo entrambi i lati che lavorano: il chiamante e il chiamato. La segnalazione dal lato chiamante è indicata come segnalazione in avanti (forward), mentre il lato chiamato utilizza la segnalazione all'indietro (backward). Designiamo Af e Bf per la segnalazione in avanti e Ab e Bb per la segnalazione all'indietro.

| Stato | ABCD in avanti | ABCD all'indietro |
| --- | --- | --- |
| Idle/Rilasciato | 1001 | 1001 |
| Sequestrato | 0001 | 1001 |
| Ack Sequestro | 0001 | 1101 |
| Risposto | 0001 | 0101 |
| ClearBack | 0001 | 1101 |
| ClearFwd (prima di clear-back) | 1001 | 0101 |
| ClearFwd (conferma disconnessione) | 1001 | 1001 |
| Bloccato | 1001 | 1101 |

MFC/R2 è stato definito dall'ITU. Sfortunatamente, diversi paesi hanno personalizzato lo standard in base alle proprie esigenze. Di conseguenza, sono emerse variazioni negli standard tra i paesi.

**Segnali inter-registro (ITU-T Q.441).** La segnalazione MFC/R2 utilizza una combinazione di due toni. Le tabelle seguenti mostrano lo standard ITU.

Gruppo di segnali I (in avanti):

| Descrizione | Segnale in avanti |
| --- | --- |
| Cifra 1 | I-1 |
| Cifra 2 | I-2 |
| Cifra 3 | I-3 |
| Cifra 4 | I-4 |
| Cifra 5 | I-5 |
| Cifra 6 | I-6 |
| Cifra 7 | I-7 |
| Cifra 8 | I-8 |
| Cifra 9 | I-9 |
| Cifra 0 | I-10 |
| Indicatore prefisso internazionale, richiesto soppressore di eco metà percorso | I-11 |
| Indicatore prefisso internazionale, nessun soppressore di eco richiesto | I-12 |
| Indicatore chiamata di test | I-13 |
| Indicatore prefisso internazionale, inserito soppressore di eco metà percorso | I-14 |
| Non utilizzato | I-15 |

Gruppo di segnali II (in avanti):

| Descrizione | Segnale in avanti |
| --- | --- |
| Abbonato senza priorità | II-1 |
| Abbonato con priorità | II-2 |
| Apparecchiatura di manutenzione | II-3 |
| Riservato | II-4 |
| Operatore | II-5 |
| Trasmissione dati | II-6 |
| Abbonato o operatore senza funzione di trasferimento in avanti | II-7 |
| Trasmissione dati | II-8 |
| Abbonato con priorità | II-9 |
| Operatore con funzione di trasferimento in avanti | II-10 |
| Riservato | II-11 |
| Riservato | II-12 |
| Riservato | II-13 |
| Riservato | II-14 |
| Riservato | II-15 |

Gruppo di segnali A (all'indietro):

| Descrizione | Segnale all'indietro |
| --- | --- |
| Invia prossima cifra (n+1) | A-1 |
| Invia penultima cifra (n-1) | A-2 |
| Indirizzo completo, passaggio alla ricezione dei segnali del Gruppo B | A-3 |
| Congestione nella rete nazionale | A-4 |
| Invia categoria del chiamante | A-5 |
| Indirizzo completo, addebito, impostazione condizioni vocali | A-6 |
| Invia terzultima cifra (n-2) | A-7 |
| Invia quartultima cifra (n-3) | A-8 |
| Riservato | A-9 |
| Riservato | A-10 |
| Invia indicatore prefisso internazionale | A-11 |
| Invia cifra di lingua o discriminazione | A-12 |
| Invia natura del circuito | A-13 |
| Richiesta informazioni sull'uso del soppressore di eco | A-14 |
| Congestione in uno scambio internazionale o alla sua uscita | A-15 |

Gruppo di segnali B (all'indietro):

| Descrizione | Segnale all'indietro |
| --- | --- |
| Riservato | B-1 |
| Invia tono di informazione speciale | B-2 |
| Linea dell'abbonato occupata | B-3 |
| Congestione (dopo passaggio gruppo A a B) | B-4 |
| Numero non assegnato | B-5 |
| Linea dell'abbonato libera, addebito | B-6 |
| Linea dell'abbonato libera, nessun addebito | B-7 |
| Linea dell'abbonato fuori servizio | B-8 |
| Riservato | B-9 |
| Riservato | B-10 |
| Riservato | B-11 |
| Riservato | B-12 |
| Riservato | B-13 |
| Riservato | B-14 |
| Riservato | B-15 |

#### Sequenza MFC/R2

La seguente sequenza illustra una chiamata originata da un interno di Asterisk verso un terminale nella PSTN. La PSTN interrompe la chiamata e termina la comunicazione.

![Un flusso di chiamata MFC/R2 completo tra Asterisk e la telco: la segnalazione di linea (Idle, Seized, Seize Ack, Answer, Clearback, Clear Forward) viene scambiata nel timeslot 16, le cifre composte e i segnali all'indietro "invia prossima cifra" (gruppi I/A/B) viaggiano in-band, e i toni udibili raggiungono l'abbonato.](../images/10-legacy-fig11.png)

### Come utilizzare il driver libopenr2

Il progetto avviato da Moises Silva è stato ispirato dal driver di canale Unicall scritto da Steve Underwood. La libreria OpenR2 è attualmente la soluzione software più stabile per Asterisk. Con questa soluzione, possiamo utilizzare qualsiasi scheda digitale compatibile con DAHDI. In precedenza, erano disponibili solo soluzioni proprietarie per MFC/R2; una delle migliori che ho utilizzato è quella resa disponibile da Khomp, www.khomp.com.br. In Asterisk 22, il supporto MFC/R2 tramite libopenR2 è integrato quando la libreria è presente al momento della compilazione — non è richiesta alcuna patch esterna. I passaggi seguenti mostrano l'installazione manuale storica per riferimento; sui sistemi moderni, installa `libopenr2-dev` dal gestore pacchetti della tua distribuzione prima di eseguire `./configure`, quindi abilita `chan_dahdi` in `make menuselect`.

I passaggi seguenti compilano openr2 e Asterisk dai loro attuali repository Git. Sono mantenuti come riferimento per i siti che compilano dal sorgente; su una distribuzione moderna di solito puoi saltarli interamente installando il pacchetto `libopenr2-dev` e una build di Asterisk 22 pacchettizzata, poiché `chan_dahdi` compila il supporto R2 direttamente contro libopenr2 senza patch esterna.

Passaggio 1: Installa gli strumenti di compilazione necessari.

```
apt-get install git
```

Passaggio 2: Clona la libreria openr2 e il sorgente di Asterisk. Non è necessario alcun albero patchato speciale su Asterisk 22 — un checkout standard compila il supporto R2 purché libopenr2 sia presente.

```
cd /usr/src
git clone https://github.com/moises-silva/openr2.git
git clone https://github.com/asterisk/asterisk.git
```

Passaggio 3: Compila e installa. Per favore, fai un BACKUP del tuo server prima di procedere.

```
cd /usr/src/openr2
./configure && make && make install && ldconfig
cd /usr/src/asterisk
./configure && make menuselect && make && make install
```

Nota: Non eseguire “make samples” per evitare di sovrascrivere i file di configurazione.

```
Step 4: Changing the file /etc/dahdi/system.conf:
vim /etc/dahdi/system.conf
```

Supponiamo che tu abbia una scheda con un'interfaccia E1.

```
span=1,1,0,cas,hdb3
cas=1-15:1101
cas=17-31:1101
dchan=16
loadzone=br
defaultzone=br
```

Passaggio 5: Esegui il comando dahdi_cfg per applicare le modifiche al driver:

```
dahdi_cfg -vvvvvvvv
Dahdi Version:SVN-branch-1.4-r4348
Echo Canceller: MG2
Configuration
======================
SPAN 1: CAS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: CAS / User (Default) (Slaves: 01)
Channel 02: CAS / User (Default) (Slaves: 02)
Channel 03: CAS / User (Default) (Slaves: 03)
Channel 04: CAS / User (Default) (Slaves: 04)
Channel 05: CAS / User (Default) (Slaves: 05)
Channel 06: CAS / User (Default) (Slaves: 06)
Channel 07: CAS / User (Default) (Slaves: 07)
Channel 08: CAS / User (Default) (Slaves: 08)
Channel 09: CAS / User (Default) (Slaves: 09)
Channel 10: CAS / User (Default) (Slaves: 10)
Channel 11: CAS / User (Default) (Slaves: 11)
Channel 12: CAS / User (Default) (Slaves: 12)
Channel 13: CAS / User (Default) (Slaves: 13)
Channel 14: CAS / User (Default) (Slaves: 14)
Channel 15: CAS / User (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
Channel 17: CAS / User (Default) (Slaves: 17)
Channel 18: CAS / User (Default) (Slaves: 18)
Channel 19: CAS / User (Default) (Slaves: 19)
Channel 20: CAS / User (Default) (Slaves: 20)
Channel 21: CAS / User (Default) (Slaves: 21)
Channel 22: CAS / User (Default) (Slaves: 22)
Channel 23: CAS / User (Default) (Slaves: 23)
Channel 24: CAS / User (Default) (Slaves: 24)
Channel 25: CAS / User (Default) (Slaves: 25)
Channel 26: CAS / User (Default) (Slaves: 26)
Channel 27: CAS / User (Default) (Slaves: 27)
Channel 28: CAS / User (Default) (Slaves: 28)
Channel 29: CAS / User (Default) (Slaves: 29)
Channel 30: CAS / User (Default) (Slaves: 30)
Channel 31: CAS / User (Default) (Slaves: 31)
31 channels to configure.
-----------------------------------------------------------------------
```

Passaggio 5: Modifica il file chan_dahdi.conf

```
vim /etc/asterisk/chan_dahdi.conf
[channels]
usecallerid=yes
callwaiting=yes
usecallingpres=yes
callwaitingcallerid=yes
threewaycalling=yes
transfer=yes
canpark=yes
cancallforward=yes
callreturn=yes
echocancel=yes
echotrainning=yes
echocancelwhenbridged=yes
signalling=mfcr2
mfcr2_variant=br
mfcr2_get_ani_first=no
mfcr2_max_ani=20
mfcr2_max_dnis=4
mfcr2_category=national_subscriber
mfcr2_logdir=span1
mfcr2_logging=all
group=1
callgroup=1
pickupgroup=1
callerid=asreceived
context=from-mfcr2
channel => 1-15,17-31
```

Passaggio 6: Modifica il dial plan nel file extensions.conf

```
vim /etc/asterisk/extensions.conf
[default]
exten => _XXXXXXXX,1,Set(CALLERID(num)=1145678990)
exten => _XXXXXXXX,n,Dial(DAHDI/g1/${EXTEN},60,tT)
```

Nota: Alcune TELCO non accettano chiamate senza Caller ID. Per favore, imposta il Caller ID su uno dei numeri DID assegnati dall'operatore. In alcuni paesi, questo passaggio non è richiesto. Passaggio 7: Testa la soluzione: Ora, con un interno nel contesto from-internal, chiama qualsiasi numero e osserva la console. Controlla se si stanno verificando errori. -- Executing Set("SIP/8564-081ca5d8", "CALLERID(num)=1145678990") in new stack -- Executing Dial("SIP/8564-081ca5d8", "DAHDI/g1/35678899|60|tT") in new stack

#### Debugging OpenR2

Per rilevare errori nelle chiamate, puoi attivare il debug. Per fare ciò, segui i passaggi seguenti.

1. Modifica il file `chan_dahdi.conf` e aggiungi le seguenti tre righe alla configurazione:

```
mfcr2_logdir=span1
mfcr2_logging=all
mfcr2_call_files=yes
```

2. Riavvia il server Asterisk
3. Testa la chiamata e controlla i file di chiamata in `/var/log/asterisk/mfcr2/span1`

Di seguito è riportata una traccia per una chiamata normale. Confrontala con ciò che ricevi nella tua chiamata.

```
[15:05:47:710] [Thread: 3078019984] [Chan 1] - Call started at Mon Jul  6 15:05:47 2009 on
chan 1
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Tx >> [SEIZE] 0x00
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x01
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Bits changed from 0x08 to 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - CAS Rx << [SEIZE ACK] 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 2
[15:05:47:951] [Thread: 3078019984] [Chan 1] - timer id 2 found, cancelling it now
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 3
[15:05:47:951] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 0
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 2
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 4
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - Sending ANI digit 4
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - Sending ANI digit 8
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - Sending ANI digit 3
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - Sending ANI digit 0
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - Sending more ANI unavailable
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Tx >> F [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Tx >> F [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:53:430] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Tx >> [CLEAR FORWARD] 0x08
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x09
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Bits changed from 0x0C to 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - CAS Rx << [IDLE] 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Call ended
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Cannot cancel timer 0
```

#### Configurazione MFC/R2

Le opzioni sono documentate all'interno del file chan_dahdi.conf. Alcune delle opzioni più importanti sono dettagliate qui. Parametri obbligatori: mfcr2_variant, mfcr2_max_ani e mfcr2_max_dnis. mfcr2_variant: Variante nazionale.

```
r2test -l
Variant Code        Country
AR                  Argentina
BR                  Brazil
CN                  China
CZ                  Czech Republic
CO                  Colombia
EC                  Ecuador
ITU                 International Telecommunication Union
MX                  Mexico
PH                  Philippines
VE                  Venezuela
```

mfcr2_max_ani: Quantità massima di cifre ANI da richiedere. mfcr2_max_dnis: Quantità massima di cifre DNIS da richiedere. mfcr2_get_ani_first: Se ottenere o meno l'ANI prima del DNIS (richiesto da alcune TELCO). mfcr2_category: Categoria del chiamante. Puoi impostare la variabile MFCR2_CATEGORY prima di avviare la chiamata. mfcr2_logdir: Directory in cui registrare i file di chiamata. (/var/log/asterisk/mfcr2/directory) mfcr2_call_files: Se registrare o meno le chiamate.

- mfcr2_logging: valori di logging
- cas – bit ABCD per tx e rx
- mf – toni multifrequenza
- stack – output dettagliato dello stack del canale e del contesto
- all – tutte le attività
- nothing – non registrare nulla

mfcr2_mfback_timeout: Questo valore merita di essere menzionato. A volte, se stai chiamando un cellulare o qualsiasi chiamata che richiede molto tempo per essere completata, questo parametro può andare in timeout, quindi viene spesso modificato per la messa a punto. Se alcune delle tue chiamate non vengono completate, questo è il parametro che dovresti cambiare per primo. mfcr2_metering_pulse_timeout: Gli impulsi vengono utilizzati da alcune varianti R2 per indicare i costi. mfcr2_allow_collect_calls: In Brasile, il tono II-8 viene utilizzato per indicare una chiamata a carico del destinatario; questo parametro ti consente di bloccare le chiamate a carico del destinatario. mfcr2_double_answer: Utilizzato anche per evitare chiamate a carico del destinatario quando è richiesta una doppia risposta. Con double_answer=yes blocchi effettivamente le chiamate a carico del destinatario. mfcr2_immediate_accept: Ti consente di saltare l'uso dei segnali di gruppo B/II e passare direttamente allo stato accettato. mfcr2_forced_release: Ti consente di velocizzare il rilascio della chiamata; funziona per la variante brasiliana.

#### ANI e DNIS

L'Automatic Number Identification (ANI) è il numero del chiamante. Il Dialed Number Identification Service (DNIS) è il numero chiamato o, in altre parole, il numero composto. Quando viene ricevuta una chiamata, solitamente le ultime quattro cifre vengono passate al PBX in un processo indicato come direct inward dial (DID). Il numero ANI è in realtà il Caller ID. L'ANI avrà l'interno del chiamante durante la composizione, mentre il DNIS conterrà la destinazione della chiamata. È importante che questi parametri siano configurati correttamente. Alcuni switch inviano solo le ultime quattro cifre, mentre altri inviano il numero completo.

### Formato del canale DAHDI

I canali DAHDI utilizzano il seguente formato nel dial plan:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Esempi:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## Il protocollo IAX2

In questo capitolo impareremo a conoscere il protocollo Inter-Asterisk eXchange (IAX), inclusi i suoi punti di forza e di debolezza. Verranno trattati anche dettagli come la modalità trunk e l'interconnessione di due server Asterisk. Tutti i riferimenti in questo documento corrispondono alla versione 2 di IAX.

Il protocollo IAX fornisce trasporto multimediale e segnalazione per voce e video. IAX è molto innovativo; risparmia larghezza di banda in modalità trunk ed è molto più semplice di SIP quando è necessario attraversare NAT. L'uso principale di IAX al giorno d'oggi è l'interconnessione di server Asterisk. IAX è stato creato principalmente per la voce, ma può anche ospitare video e altri flussi multimediali.

IAX è stato ispirato da altri protocolli VoIP, come SIP e MGCP. Invece di utilizzare due protocolli separati per la segnalazione e i media, IAX li ha unificati per creare un protocollo unico. IAX non utilizza RTP per il trasporto dei media; al contrario, incorpora i media nella stessa connessione UDP.

**Stato in Asterisk 22.** `chan_iax2` è ancora incluso e pienamente supportato in Asterisk 22 LTS, quindi tutto ciò che è contenuto in questa sezione rimane valido. IAX2 è, tuttavia, un protocollo legacy che vede relativamente pochi nuovi utilizzi: il settore è ampiamente convergente su SIP (tramite `chan_pjsip` in Asterisk 22) sia per il trunking dei provider che per l'interconnessione tra server. Il principale vantaggio rimanente di IAX2 è il suo design a porta singola: tutta la segnalazione e i media fluiscono su una singola porta UDP (4569 per impostazione predefinita), il che semplifica la configurazione di firewall e NAT rispetto a SIP e ai suoi flussi RTP separati. Per un nuovo trunk da Asterisk ad Asterisk dove il NAT non è un problema, un trunk PJSIP è l'approccio moderno raccomandato; IAX2 viene trattato qui perché rimane una scelta valida, specialmente dove è possibile aprire una sola porta UDP attraverso un firewall.

### Obiettivi

Alla fine di questo capitolo, dovresti essere in grado di:

- Identificare i punti di forza e di debolezza del protocollo IAX
- Descrivere gli scenari di utilizzo per il protocollo IAX
- Descrivere i vantaggi della modalità trunk di IAX
- Configurare iax.conf per i telefoni
- Configurare iax.conf per la connessione a un provider VoIP
- Configurare iax.conf per l'interconnessione tra server Asterisk
- Comprendere l'autenticazione IAX

### Design di IAX

Gli obiettivi principali per il design di IAX sono:

- Ridurre la larghezza di banda richiesta per il trasporto dei media e la segnalazione
- Fornire trasparenza NAT
- Essere in grado di trasmettere le informazioni del dialplan
- Supportare l'uso efficiente di paging e intercom

IAX è un protocollo di segnalazione e media peer-to-peer simile a SIP, ma senza l'uso di RTP. L'approccio di base consiste nel multiplexare i flussi multimediali su una singola connessione UDP tra due host. Il vantaggio maggiore di questo approccio è la sua semplicità nell'attraversamento di connessioni NAT, comunemente presenti nei modem xDSL. IAX utilizza una singola porta, UDP 4569 per impostazione predefinita, e quindi utilizza un numero di chiamata a 15 bit per multiplexare tutti i flussi. Il protocollo IAX utilizza processi di registrazione e autenticazione simili al protocollo SIP. Una descrizione del protocollo può essere trovata su http://www.ietf.org/internet-drafts/draft-guy-iax-05.txt

![Il protocollo IAX multiplexa molte chiamate tra due endpoint su una singola porta UDP (4569 per impostazione predefinita), utilizzando un numero di chiamata a 15 bit per mantenere separati i flussi, il che rende semplice l'attraversamento NAT.](../images/10-legacy-fig12.png)

### Utilizzo della larghezza di banda

La larghezza di banda utilizzata nelle reti VoIP è influenzata da diversi fattori; i codec e le intestazioni di protocollo sono i più importanti. Il protocollo IAX ha una caratteristica sorprendente chiamata modalità trunk, grazie alla quale multiplexa diverse chiamate utilizzando un'unica intestazione. Giocando con il calcolatore di larghezza di banda di Asterisk, vedrai come i trunk IAX possono farti risparmiare fino all'80% del traffico con chiamate multiple.

![Confronto tra l'overhead di IAX e SIP: due chiamate SIP/RTP necessitano di due pacchetti (40 byte di payload trasportati sotto 156 byte di overhead), mentre la modalità trunk IAX2 trasporta entrambe le chiamate in un singolo pacchetto (40 byte di payload sotto soli 66 byte di overhead) condividendo un'intestazione IP/UDP tra molti mini-frame.](../images/10-legacy-fig13.png)

### Denominazione dei canali

È importante comprendere le convenzioni di denominazione dei canali poiché utilizzerai questi nomi quando specifichi un canale nel dialplan. Il formato di un nome di canale IAX utilizzato per i canali in uscita è:

```
IAX/[<user>[:<secret>]@]<peer>[:<portno>][/<exten>[@<context>][/<options>]
```

- `<user>` — UserID sul peer remoto, o nome del client configurato in iax.conf
- `<secret>` — La password. In alternativa può essere il nome del file per una chiave RSA senza l'estensione finale (.key o .pub) e racchiuso tra parentesi quadre
- `<peer>` — Nome del server a cui connettersi
- `<portno>` — Numero di porta per la connessione
- `<exten>` — Extension nel server Asterisk remoto
- `<context>` — Context nel server Asterisk remoto
- `<options>` — L'unica opzione disponibile è 'a', che significa 'richiedi risposta automatica'

#### Esempio di canali in uscita:

I canali in uscita sono visibili nella console di Asterisk.

- `IAX2/8590:secret@myserver/8590@default` — Chiama l'extension 8590 su myserver. Utilizza 8590:secret come coppia nome/password
- `IAX2/iaxphone` — Chiama "iaxphone"
- `IAX2/judy:[judyrsa]@somewhere.com` — Chiama somewhere.com utilizzando judy come nome utente e una chiave RSA per l'autenticazione

#### Il formato di un canale IAX in entrata è:

I canali in entrata sono visibili nella console di Asterisk.

```
IAX2/[<username>@]<host>]-<callno>
```

- `<username>` — Nome utente se noto
- `<host>` — Host che si connette
- `<callno>` — Numero di chiamata locale

Esempio di canale in entrata:

- `IAX2[flavio@8.8.30.34]/10` — Numero di chiamata 10 dall'indirizzo IP 8.8.30.34 utilizzando flavio come utente.
- `IAX2[8.8.30.50]/11` — Numero di chiamata 11 dall'indirizzo IP 8.8.30.50.

### Utilizzo di IAX

Puoi utilizzare IAX in diversi modi. In questa sezione, ti mostreremo come configurare IAX per diversi scenari, tra cui:

- Connessione di un softphone tramite IAX
- Connessione di IAX a un provider VoIP tramite IAX
- Connessione di due server tramite IAX
- Connessione di due server tramite IAX in modalità trunk
- Debug di una connessione IAX
- Utilizzo di coppie di chiavi RSA per l'autenticazione

#### Connessione di un softphone tramite IAX

Asterisk supporta telefoni IP basati su IAX come l'ATCOM e il vecchio ATA di Digium (chiamato IAXy), così come softphone che implementano ancora il protocollo IAX2. Il processo per softphone, ATA e telefoni hardware è simile. Per configurare un dispositivo IAX, è necessario modificare il file iax.conf in /etc/asterisk

```
directory.
```

Utilizzeremo un softphone compatibile con IAX2 come esempio.

1. Crea un backup del file originale `iax.conf` utilizzando:

```
#cd /etc/asterisk
#mv iax.conf iax.conf.backup
```

2. Inizia a modificare un nuovo file `iax.conf`:

```
[general]
bindport=4569
bindaddr=8.8.1.4
bandwidth=high
```

- ; Parametro molto importante, cambia i codec disponibili

```
disallow=all
allow=ulaw
jitterbuffer=no
forcejitterbuffer=no
tos=lowdelay
autokill=yes
[guest]
type=user
context=guest
callerid="Guest IAX User"
; Trust Caller*ID Coming from iaxtel.com
;
[iaxtel]
type=user
context=default
auth=rsa
inkeys=iaxtel
;
; Trust Caller*ID Coming from iax.fwdnet.net
;
[iaxfwd]
type=user
context=default
auth=rsa
inkeys=freeworlddialup
;
; Trust callerid delivered over DUNDi/e164
;
;
;[dundi]
;type=user
;dbsecret=dundi/secret
;context=dundi-e164-local
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

Ho cercato di preservare le righe predefinite (non commentate) del file di esempio. Sono stati modificati i seguenti parametri:

```
bandwidth=high
```

Questa riga influenza la selezione del codec. L'utilizzo dell'impostazione high consente la selezione di un codec ad alta larghezza di banda e alta qualità come g.711 definito dalla parola chiave ulaw. Se mantieni il parametro predefinito, non sarai in grado di scegliere ulaw. In questo caso, Asterisk ti darà il messaggio “no codec available” per la configurazione sottostante.

```
disallow=all
allow=ulaw
```

Nei comandi descritti sopra, abbiamo disabilitato tutti i codec e abilitato solo ulaw. Nelle LAN, la maggior parte delle persone preferisce utilizzare ulaw perché non è intensivo per il processore e risparmia cicli CPU. Anche utilizzando più larghezza di banda, questo codec è preferibile perché nelle LAN di solito si dispone di una Ethernet a 100 megabit o addirittura Gigabit. Una chiamata vocale che utilizza ulaw consuma quasi 100 kilobit al secondo di larghezza di banda dalla tua rete, che è un uso molto leggero per le LAN ad alta velocità di oggi. Nelle reti WAN o Internet, di solito disabiliterai ulaw, scambiando alcuni cicli CPU disponibili con la compressione vocale per un migliore utilizzo della larghezza di banda. Anche i codec gsm, g729 e ilbc forniscono un buon fattore di compressione.

```
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

Nei comandi sopra, abbiamo definito un friend chiamato [2003]. Il context è quello predefinito (nei primi laboratori usiamo sempre il context predefinito per evitare confusione; questo context verrà spiegato completamente quando tratteremo il dialplan). La riga “host=dynamic” fornisce una registrazione dinamica dell'indirizzo IP del telefono.

3. Scarica e installa un softphone compatibile con IAX2. Puoi scegliere qualsiasi softphone che supporti ancora il protocollo IAX2 per il laboratorio.
4. Configura un account IAX nel client (solitamente *Aggiungi account* → IAX). Nota che il SipPulse Softphone è solo SIP e non può registrarsi tramite IAX2, quindi per i test IAX hai bisogno di un client che supporti ancora il protocollo.

5. Configura il file `extensions.conf` per testare il tuo dispositivo IAX.

```
[default]
exten=>2000,1,Dial(SIP/2000)
exten=>2001,1,Dial(SIP/2001)
exten=>2003,1,Dial(IAX2/2003)
```

Ora puoi effettuare chiamate tra i telefoni SIP creati nel Capitolo 3 e il telefono IAX creato nel laboratorio.

#### Connessione a un provider VoIP tramite IAX

Alcuni provider VoIP supportano IAX. Puoi trovare facilmente un provider IAX cercando “IAX providers”. Utilizzare un provider IAX ha molto senso poiché IAX può risparmiare molta larghezza di banda, attraversa facilmente il NAT e può autenticarsi utilizzando coppie di chiavi RSA.

![L'Asterisk di un cliente connesso a un provider VoIP tramite un trunk IAX su Internet: un singolo trunk trasporta tutte le chiamate da e verso il provider.](../images/10-legacy-fig14.png)

Il numero di provider VoIP commerciali compatibili con IAX è diminuito drasticamente nelle ultime versioni di Asterisk; la maggior parte dei provider ora offre esclusivamente trunk SIP/PJSIP. Prima di impegnarti con un provider IAX, conferma che mantengano attivamente la loro infrastruttura IAX. Per una nuova integrazione con un provider, un trunk PJSIP (Capitolo 3) è l'alternativa raccomandata.

#### Connessione a un provider tramite IAX

Passaggio 1: Apri un account presso il tuo provider preferito. Il tuo provider ti fornirà tre cose.

- Nome
- Secret
- Indirizzo IP o nome host
- Chiave pubblica RSA

Passaggio 2: Configura il file iax.conf per registrare il tuo Asterisk presso il tuo provider. Aggiungi le seguenti righe alla sezione [general] del file.

```
[general]
register=>name:secret@hostname/2003
```

Nelle istruzioni descritte sopra, ti sei registrato presso il tuo provider utilizzando il tuo account e la tua password. Nel momento in cui ricevi una chiamata, questa verrà inoltrata all'extension 2003.

```
[name]
```

- ; Il tuo nome utente o numero di account

```
type=peer
secret=secret
; Your password
host=hostname
```

Nelle istruzioni descritte sopra, abbiamo creato un peer corrispondente al provider per scopi di composizione.

```
[nameiax]
type=user
context=default
auth=rsa
inkeys=hostname
```

Questo è richiesto per l'autenticazione RSA. Utilizzare la chiave pubblica del tuo provider ti consente di essere sicuro che la chiamata ricevuta provenga effettivamente dal vero provider. Se qualcun altro tenta di utilizzare lo stesso percorso, non sarà in grado di autenticarlo perché non possiede la chiave privata corrispondente. Passaggio 4: Prova la connessione. Per testare la connessione, chiama un numero qualsiasi. Alcuni fornitori forniscono un test dell'eco. Per farlo, modifica il file extensions.conf.

```
[default]
exten=>*98,1,Dial(IAX2/name:secret@hostname/*98,20,r)
```

Vai alla CLI di Asterisk ed esegui un reload. Per verificare se Asterisk è registrato presso il provider, usa il comando successivo.

```
*CLI>reload
*CLI>iax2 show register
```

Ora componi semplicemente *98 sul softphone connesso al server Asterisk.

#### Connessione di due server Asterisk tramite un trunk IAX

È molto facile connettere un server a un altro. Non avrai bisogno di registrarli perché gli indirizzi IP sono già noti. Dovrai creare i peer e gli utenti nel file iax.conf. Tutte le extension nel sito HQ iniziano con 20 seguite da due cifre (es. 2000). Nella filiale (Branch), tutte le extension iniziano con 22 seguite da due cifre (es. 2200). Utilizzeremo il trunk. Avrai bisogno di una sorgente di timing DAHDI per abilitare questa funzione. Passaggio 1: Modifica il file iax.conf nel server Branch.

![Connessione di due server Asterisk con un trunk IAX: il server HQ (192.168.1.1, extension 20xx) e il server Branch (192.168.1.2, extension 22xx) si raggiungono tramite un singolo trunk IAX — non è necessaria alcuna registrazione perché entrambi gli indirizzi IP sono fissi e noti.](../images/10-legacy-fig15.png)

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;allow=gsm
[Branch]
type=user
context=default
secret=password
host=192.168.2.10
trunk=yes
notransfer=yes
[HQ]
type=peer
context=default
username=HQ
secret=password
host=192.168.2.10
callerID='HQ'
trunk=yes
notransfer=yes
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2000'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2001'
```

Passaggio 2: Configura il file extensions.conf nel server Branch

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_20XX,1,dial(IAX2/HQ/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

Passaggio 3: Configura il file iax.conf nel server HQ

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
[Branch]
type=peer
context=default
username=Branch
secret=password
host=192.168.2.9
callerid="Branch"
trunk=yes
notransfer=yes
[HQ]
type=user
secret=password
context=default
host=192.168.2.9
callerid="HQ"
trunk=yes
notransfer=yes
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2200"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2201"
host=dynamic
```

Passaggio 4: Configura il file extensions.conf nel server HQ.

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_22XX,1,Dial(IAX2/Branch/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Passaggio 5: Testa una chiamata dal telefono 2000 nel server HQ al telefono 2200 nel server Branch.

### Autenticazione IAX

Ora analizziamo il processo di autenticazione IAX dal punto di vista pratico per aiutarti a scegliere il metodo migliore per ogni requisito specifico.

#### Connessioni in entrata

![Il flusso decisionale dell'autenticazione IAX per una chiamata in entrata: Asterisk si ramifica a seconda che venga fornito un nome utente, se corrisponde a una sezione, se l'IP sorgente è consentito e se il secret (testo in chiaro, MD5 o RSA) corrisponde — accettando la chiamata con il context e le opzioni peer di quella sezione, o rifiutandola.](../images/10-legacy-fig16.png)

Quando Asterisk riceve una connessione in entrata, le informazioni iniziali possono includere un nome utente (dal campo "username=") oppure no. La connessione in entrata ha anche un indirizzo IP, che Asterisk utilizza anch'esso per l'autenticazione.

Se viene fornito un utente, Asterisk:

1. Cerca in iax.conf una voce con type=user (o type=friend con un nome di sezione corrispondente al nome utente). Se non la trova, Asterisk rifiuta la connessione.
2. Se la voce trovata ha configurazioni deny/allow, confronta l'indirizzo IP del chiamante per determinare se accettare o meno la chiamata a seconda delle clausole deny/allow.
3. Controlla la password (secret) utilizzando testo in chiaro, md5 o RSA.
4. Accetta la connessione e invia la chiamata al context specificato nella riga "context=" del file iax.conf.

Se non viene fornito un nome utente, Asterisk:

1. Cerca una voce contenente type=user (o type=friend) nel file iax.conf senza un secret specificato. Controlla anche le clausole deny/allow. Se viene trovata una voce, la connessione viene accettata e il nome della sezione viene utilizzato come nome dell'utente.
2. Cerca una voce contenente type=user (o type=friend) nel file iax.conf con un secret o una chiave RSA specificati. Controlla le clausole deny/allow. Se viene trovata una voce, tenta di autenticare il chiamante utilizzando il secret specificato; se corrisponde, accetta la connessione. Il nome della sezione è il nome dell'utente.

Supponiamo che il tuo file iax.conf abbia le seguenti voci:

```
[guest]
type=user
context=guest
[iaxtel]
type=user
context=incoming
auth=rsa
inkeys=iaxtel
[iax-gateway]
type=friend
allow=192.168.0.1
context=incoming
host=192.168.0.1
[iax-friend]
type=user
secret=this_is_secret
auth=md5
context=incoming
```

Se una chiamata ha un nome utente specificato, come:

- guest
- iaxtel
- iax-gateway
- iax-friend

Asterisk tenterà di autenticare la chiamata utilizzando solo la voce corrispondente nel file iax.conf. Se vengono specificati altri nomi, la chiamata verrebbe rifiutata. Se non viene specificato alcun utente, Asterisk tenterà di autenticare la connessione come guest. Tuttavia, se guest non esiste, proverà qualsiasi altra connessione con un secret corrispondente. In altre parole, se non hai una sezione guest nel tuo file iax.conf, un utente malintenzionato potrebbe tentare di indovinare qualsiasi secret corrispondente non specificando il nome utente. Si applicano anche le restrizioni deny/allow degli indirizzi IP. Un buon modo per evitare di indovinare il secret è utilizzare l'autenticazione RSA. Un altro metodo consiste nel limitare gli indirizzi IP autorizzati a chiamare.

#### Restrizioni degli indirizzi IP

L'accesso è controllato con le righe `permit` e `deny`:

```
permit = <ipaddr>/<netmask>
deny = <ipaddr>/<netmask>
```

Le regole vengono interpretate in sequenza e tutte vengono valutate (questo concetto è diverso dagli ACL solitamente presenti in router e firewall). L'ultima istruzione corrispondente sostituisce le precedenti.

Esempio n. 1:

```
permit=0.0.0.0/0.0.0.0
deny=192.168.0.0/255.255.255.0
```

Questo negherà qualsiasi pacchetto dalla rete 192.168.0.0/24.

Esempio n. 2:

```
deny=192.168.0.0/255.255.255.0
permit=0.0.0.0/0.0.0.0
```

Questo permetterà qualsiasi pacchetto, perché l'ultima istruzione sostituisce la prima.

#### Connessioni in uscita

Le connessioni in uscita acquisiscono le informazioni di autenticazione utilizzando i seguenti metodi:

- La descrizione del canale IAX2 passata dall'applicazione dial().
- Una voce con type=peer o type=friend nel file iax.conf.
- Una combinazione di entrambi i metodi.

#### Connessione di due server Asterisk tramite chiavi RSA

È possibile utilizzare IAX con un'autenticazione forte utilizzando chiavi RSA asimmetriche. Secondo il codice sorgente (res_krypto.c), Asterisk utilizza chiavi RSA con un algoritmo SHA-1 per i message digest invece del più debole MD5. Di seguito è riportata una guida passo-passo per configurare due server utilizzando chiavi RSA.

##### Configurazione del server per la filiale (Branch)

Passaggio 1: Genera le chiavi RSA nel server Branch

```
astgenkey -n
```

Quando richiesto, usa il nome chiave branch. Abbiamo utilizzato il parametro –n per evitare di inserire una passphrase ogni volta che Asterisk si reinizializza. Se vuoi migliorare la sicurezza, non usare il –n e avvia Asterisk con asterisk -i Passaggio 2: Copia le chiavi nella directory /var/lib/asterisk/keys

```
cp branch.* /var/lib/asterisk/keys
```

Passaggio 3: Copia la chiave pubblica nel server HQ

```
scp branch.pub root@hq_ip_address:/var/lib/asterisk/keys
```

Passaggio 4: Modifica il file iax.conf nel server Branch.

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;Create an entry for the HQ server
[hq]
type=user
context=default
host=192.168.2.10
trunk=yes
notransfer=yes
auth=rsa
inkeys=hq
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2200'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2201'
```

Passaggio 8: Configura il file extensions.conf nel server Branch

```
 [default]
exten=>_20XX,1,dial(IAX2/branch:[branch]@192.168.2.10/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

##### Configurazione del server per la sede centrale (HQ)

Passaggio 1: Genera le chiavi RSA nel server HQ

```
astgenkey -n
```

Quando richiesto usa il nome chiave hq. Passaggio 2: Copia le chiavi nella directory /var/lib/asterisk/keys

```
cp hq.* /var/lib/asterisk/keys
```

Passaggio 3: Copia la chiave pubblica nel server BRANCH

```
scp hq.pub root@branch_ip_address:/var/lib/asterisk/keys
```

Passaggio 4: Configura il file iax.conf nel server HQ

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
;Configure an entry for the branch server
[branch]
type=user
context=default
host=192.168.2.9
trunk=yes
notransfer=yes
auth=rsa
inkeys=branch
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2000"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2001"
host=dynamic
```

Passaggio 10: Configura il file extensions.conf nel server HQ.

```
[default]
exten=>_22XX,1,Dial(IAX2/hq:[hq]@192.168.2.9/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Passaggio 11: Testa una chiamata dal telefono 2000 nel server HQ al telefono 2200 nel server Branch.

### Configurazione del file iax.conf

Il file iax.conf ha diversi parametri; discutere ogni parametro uno per uno sarebbe noioso e controproducente. Tutti i parametri, insieme a una descrizione, possono essere trovati nel file di esempio. Nel wiki www.voip-info.org troverai informazioni dettagliate su ciascuno di essi. Qui mostreremo alcuni dei parametri più importanti per la configurazione della sezione general, dei peer e degli utenti.

#### Sezione [General]

Indirizzi del server:

- `bindport = <portnum>` — Configura la porta UDP IAX. Il valore predefinito è 4569.
- `bindaddr = <ipaddr>` — Usa 0.0.0.0 per associare Asterisk a tutte le interfacce, o specifica l'indirizzo IP di un'interfaccia specifica.

Selezione del codec:

- `bandwidth = [low|medium|high]` — High = tutti i codec; Medium = tutti i codec eccetto ulaw e alaw; Low = codec a bassa larghezza di banda.
- `allow/disallow = [alaw|ulaw|gsm|g.729| etc.]` — Ottimizzazione della selezione del codec.

### Jitter buffer

Il jitter è la variazione di ritardo tra i pacchetti. È il fattore più importante che influenza la qualità della voce. Un Jitter buffer viene utilizzato per compensare la variazione di ritardo. Sacrifica la latenza a favore di un jitter inferiore. Puoi fare un'analogia tra il jitter buffer e un serbatoio d'acqua. Entrambi possono ricevere pacchetti o acqua a intervalli irregolari, ma alla fine forniranno un flusso regolare.

![Il jitter buffer come un serbatoio d'acqua: i pacchetti arrivano irregolarmente dalla rete e riempiono il buffer, che poi li rilascia a un ritmo costante per produrre un flusso vocale fluido. La dimensione del buffer (in ms) scambia un po' di latenza per un jitter inferiore; la banda di eccesso del buffer consente ad Asterisk di aumentare o ridurre il buffer al variare delle condizioni di rete.](../images/10-legacy-fig17.png)

Un jitter piccolo (es. inferiore a 20 ms) è solitamente impercettibile. Tuttavia, un jitter superiore a questo livello è fastidioso. La latenza o il ritardo dovrebbero essere mantenuti al di sotto dei 150ms. Creare un jitter buffer sacrificherà un po' di ritardo per un jitter inferiore: un concetto noto come “delay-budget”. Puoi influenzare il jitter buffer utilizzando questi parametri:

- Jitterbuffer=<yes/no> – Abilita o disabilita
- Dropcount=<number> - Numero massimo di frame che dovrebbero essere ritardati negli ultimi due secondi. L'impostazione consigliata è 3 (1,5% di frame scartati)
- Maxjitterbuffer=<ms> - Solitamente inferiore a 100 ms
- Maxexcessbuffer=<ms> - Se il ritardo di rete migliora, il jitter buffer potrebbe essere sovradimensionato. Di conseguenza, Asterisk tenterà di ridurlo.
- Minexcessbuffer=<ms> - Una volta che il buffer in eccesso scende a questo valore, Asterisk inizia ad aumentare la dimensione del buffer.

### Tagging dei frame

Il parametro sottostante contrassegna il pacchetto IP nel campo del tipo di servizio. I router possono leggere questo tag, dando così priorità al traffico. Asterisk utilizza i codici DSCP per questo campo (RFC 2474). I valori consentiti sono CS0, CS1, CS2, CS3, CS4, CS5, CS6, CS7, AF11, AF12, AF13, AF21, AF22, AF23, AF31, AF32, AF33, AF41, AF42, AF43 e ef (ovvero, expedited forwarding).

```
tos=ef
```

### Crittografia IAX2

IAX supporta la crittografia delle chiamate utilizzando un cifrario a blocchi a 128 bit chiamato AES (Advanced Encryption Standard). È molto semplice attivare la crittografia tra i trunk IAX. Nel file iax.conf usa:

```
encryption=yes
```

Per forzare la crittografia:

```
forceencryption=yes
```

Per garantire la compatibilità con le versioni precedenti, potrebbe essere necessario disabilitare la rotazione delle chiavi utilizzando:

```
keyrotate=no
```

### Comandi di debug IAX2

Di seguito sono riportati alcuni dei comandi di console più importanti per la risoluzione dei problemi di Asterisk.

```
iax2 show netstats
vtsvoffice*CLI> iax2 show netstats
                        -------- LOCAL ---------------------  -------- REMOTE ---------------
-----
Channel           RTT  Jit  Del  Lost   %  Drop  OOO  Kpkts  Jit  Del  Lost   %  Drop  OOO
Kpkts
IAX2/8590-1        16   -1    0    -1  -1     0   -1      1   60  110     3   0     0    0
0
iax2 show channels
vtsvoffice*CLI> iax2 show channels
Channel       Peer             Username    ID (Lo/Rem)  Seq (Tx/Rx)  Lag      Jitter  JitBuf
Format
IAX2/8590-2   8.8.30.43        8590        00002/26968  00004/00003  00000ms  -0001ms  0000ms
unknow
iax2 show peers
vtsvoffice*CLI> iax2 show peers
Name/Username    Host                 Mask             Port          Status
8584             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8564             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8576             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8572             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8571             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8585             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8589             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8590             8.8.30.43       (D)  255.255.255.255  4569          OK (16 ms)
3232             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
9 iax2 peers [1 online, 8 offline, 0 unmonitored]
iax2 debug
```

Osservando questo output, identifica l'inizio e la fine della chiamata. Osserva le informazioni su ritardo e jitter ottenute utilizzando i pacchetti poke e pong. Questi pacchetti aiutano a creare l'output del comando “iax2 show netstats”.

```
vtsvoffice*CLI> iax2 debug
IAX2 Debugging Enabled
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: REGREQ
   Timestamp: 00003ms  SCall: 26975  DCall: 00000 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: REGAUTH
   Timestamp: 00009ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 137472844
   USERNAME        : 8590
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: REGREQ
   Timestamp: 00016ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
   MD5 RESULT      : f772b6512e77fa4a44c2f74ef709e873
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: REGACK
   Timestamp: 00025ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   USERNAME        : 8590
   DATE TIME       : 2006-04-17  16:03:00
   REFRESH         : 60
   APPARENT ADDRES : IPV4 8.8.30.43:4569
   CALLING NUMBER  : 4830258590
   CALLING NAME    : Flavio
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00025ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: POKE
   Timestamp: 00003ms  SCall: 00006  DCall: 00000 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: PONG
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Tx-Frame Retry[-01] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00006  DCall: 26976 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: AUTHREQ
   Timestamp: 00007ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 190271661
   USERNAME        : 8590
Rx-Frame Retry[Yes] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[-01] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: AUTHREP
   Timestamp: 00063ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   MD5 RESULT      : 57cc5c48affba14106c29439944413a1
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: ACCEPT
   Timestamp: 00054ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   FORMAT          : 1024
Tx-Frame Retry[000] -- OSeqno: 002 ISeqno: 002 Type: CONTROL Subclass: ANSWER
   Timestamp: 00057ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 003 ISeqno: 002 Type: VOICE   Subclass: 138
   Timestamp: 00090ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00054ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00057ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: IAX     Subclass: ACK
   Timestamp: 00090ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: VOICE   Subclass: 138
   Timestamp: 00210ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[-01] -- OSeqno: 004 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00210ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 003 ISeqno: 004 Type: IAX     Subclass: PING
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 004 ISeqno: 004 Type: IAX     Subclass: PONG
   Timestamp: 02083ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: ACK
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: HANGUP
   Timestamp: 08693ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   CAUSE           : Dumped Call
```

Per disattivare il debug, usa:

```
vtsvoffice*CLI>iax2 no debug
```

### Riepilogo

Questo capitolo ha esaminato i punti di forza e di debolezza del protocollo IAX. Ha dimostrato come funziona IAX in diversi scenari, come softphone e un trunk tra due server Asterisk. La modalità trunk ti consente di risparmiare larghezza di banda trasportando più di una chiamata in un singolo pacchetto. Infine, hai imparato i comandi della console che puoi utilizzare per controllare lo stato ed eseguire il debug del protocollo.

## Legacy SIP: chan_sip e sip.conf (rimosso in Asterisk 21+)

> **Legacy / storico:** Tutto ciò che è contenuto in questa sezione utilizza il vecchio driver `chan_sip` e il relativo file di configurazione `sip.conf`. `chan_sip` è stato deprecato per diverse versioni e **rimosso in Asterisk 21**, quindi **non esiste in Asterisk 22**. Nessuno degli esempi `sip.conf` riportati di seguito funzionerà su un sistema attuale: sono conservati qui solo per documentare come funzionavano le implementazioni legacy e per aiutarti a migrarle. Per il metodo moderno e supportato per eseguire queste operazioni, consulta la sezione *PJSIP: the SIP channel* del capitolo *SIP & PJSIP in depth*. La teoria del *protocollo* SIP (metodi, registrazione, proxy/redirect, SDP, tipi di NAT) è a livello di protocollo e si trova in quel capitolo; ciò che segue è puramente la **configurazione** `chan_sip` rimossa.

Sui sistemi legacy fino ad Asterisk 20, il SIP veniva configurato in `/etc/asterisk/sip.conf`, che era il secondo file più modificato (subito dopo `extensions.conf`). Le sezioni seguenti mostrano come `chan_sip` connetteva Asterisk a un provider SIP, come connettere due Asterisk tra loro utilizzando il SIP, il supporto ai domini, la presenza, le opzioni codec/DTMF/QoS, l'autenticazione e il NAT, seguiti da una guida alla migrazione di tutto ciò verso PJSIP.

### Connettere Asterisk a un provider SIP (sip.conf)

Asterisk viene spesso utilizzato per connettersi a un provider VoIP SIP. I provider VoIP solitamente offrono tariffe migliori per le chiamate telefoniche rispetto ai provider tradizionali. Un altro punto interessante e attraente dei provider VoIP è la possibilità di acquistare numeri DID in altre città, anche in paesi stranieri. Questi sono ottimi motivi per utilizzare il VoIP per le telecomunicazioni. In questa sezione, imparerai come il legacy `chan_sip` connetteva Asterisk a un provider VoIP. Sono necessari tre passaggi per connettere Asterisk a un provider SIP. I test possono essere condotti stabilendo un account con il tuo provider preferito. Passaggio 1: Registrazione presso un provider SIP in sip.conf Per connettersi a un provider SIP, avrai bisogno delle seguenti informazioni dal provider:

![Asterisk connesso a un provider di servizi VoIP tramite Internet o una WAN privata, con telefoni SIP locali registrati al server Asterisk](../images/07-sip-and-pjsip-fig07.png)

- username
- secret e remotesecret (usa secret per autenticare le richieste in entrata e remotesecret per le richieste in uscita)
- hostname
- domain
- codec consentiti

Questa configurazione consentirà al tuo provider di individuare l'indirizzo IP di Asterisk. Nella seguente istruzione, stiamo dicendo ad Asterisk di registrarsi presso un provider SIP definito dall'hostname e di informare il provider dell'indirizzo IP di Asterisk. L'istruzione indica che desideri ricevere chiamate all'extension 4100. Nella sezione [general] del file sip.conf, inserisci la seguente riga:

```
register=>name:secret@hostname/4100
```

Passaggio 2: Configurare il [peer] in sip.conf Crea una voce di tipo peer per il provider desiderato per semplificare la composizione su Asterisk.

```
[provider]
context=incoming
type=friend
dtmfmode=rfc2833
directmedia=no
username=username
remotesecret=secret
host=hostname
fromuser=username
fromdomain=domain
insecure=invite
disallow=all
allow=ulaw ; or any other codec available from your provider
```

Passaggio 3: Creare una rotta verso il provider nel dialplan Sceglieremo le cifre 010 come rotta di destinazione verso il provider. Per comporre #610000 all'interno del provider, componi semplicemente 010610000.

```
exten=>_010.,1,Set(CALLERID(num)=username)
exten=>_010.,n,Set(CALLERID(Name)="Flavio Gonçalves")
exten=>_010.,n,Dial(SIP/${EXTEN:3}@provider)
exten=>_010.,n,Hangup
```

#### Opzioni SIP specifiche per lo scenario del provider

La discussione seguente esamina i dettagli delle opzioni impostate nel file sip.conf per la connessione a un provider VoIP.

```
register=>username:password@hostname/4100
```

L'istruzione register nel file sip.conf viene utilizzata per registrarsi presso un provider. La transazione di registrazione viene autenticata con nome e secret. Puoi utilizzare una barra (“/”) per fornire un'extension per le chiamate in arrivo. Tecnicamente parlando, l'extension verrà inserita nel campo dell'intestazione “Contact” della richiesta SIP. Il comportamento di registrazione può essere controllato da determinati parametri:

```
registertimeout=20
registerattempts=10
```

Per verificare se la registrazione è avvenuta con successo, il comando console legacy era `sip show registry`. Su Asterisk 22 il comando equivalente è `pjsip show registrations` (registrazioni in uscita) e `pjsip show endpoints` per lo stato dell'endpoint.

Il parametro “username” viene utilizzato nel digest di autenticazione. Il digest viene calcolato utilizzando username, secret e realm:

```
username=username
```

Host definisce l'indirizzo o il nome del provider VoIP:

```
host=hostname
```

I parametri Fromuser e Fromdomain sono talvolta richiesti per l'autenticazione. Questi parametri vengono utilizzati nel campo dell'intestazione SIP From:

```
fromuser=username
fromdomain=hostname
```

Quando ti connetti a un provider VoIP, sono richieste le credenziali. Dopo l'INVITE iniziale, il provider ti invia un messaggio chiamato “407 Proxy Authentication Required”; tu fornisci le credenziali nel successivo messaggio INVITE. Per le chiamate in arrivo, il tuo server Asterisk richiederà le credenziali per il provider. Ovviamente, il provider non dispone di una credenziale valida per il tuo server Asterisk. Quando utilizzi insecure=invite, stai dicendo ad Asterisk di non inviare il “407 Proxy Authentication Required” al provider e di accettare le chiamate in arrivo. Puoi anche utilizzare insecure=port, invite per far corrispondere il peer in base all'indirizzo IP senza far corrispondere il numero di porta.

```
insecure=invite, port
```

### Connettere due server Asterisk tra loro utilizzando il SIP (sip.conf)

Puoi utilizzare il SIP per interconnettere due macchine Asterisk. È importante prestare attenzione al dialplan prima di procedere con questa configurazione. Gli utenti generalmente desiderano connettere altri PBX con il minimo sforzo. L'idea qui è di utilizzare un numero di extension solo per connettersi all'altro PBX. Passaggio 1: Modifica il file sip.conf nel server A:

```
[B]
type=user
secret=B
host=A
disallow=all
allow=ulaw
directmedia=no
[B-out]
type=peer
fromuser=A
username=A
remotesecret=A
host=B
disallow=all
allow=ulaw
directmedia=no
```

Passaggio 2: Modifica il file sip.conf nel server B:

```
[A]
type=user
host=B
secret=A
disallow=all
allow=ulaw
directmedia=no
[A-out]
```

![Connessione di due server Asterisk tramite SIP: il server A (extension 4400/4401) e il server B (extension 4500/4501) scambiano segnalazione SIP in modo che gli utenti su ciascun PBX possano chiamare l'altro](../images/07-sip-and-pjsip-fig08.png)

```
type=peer
host=A
fromuser=B
username=B
remotesecret=B
disallow=all
allow=ulaw
directmedia=no
```

Passaggio 3: Modifica il file extensions.conf nel server A:

```
[default]
exten=_44XX,1,dial(SIP/${EXTEN},20)
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/B-out/${EXTEN})
exten=_45XX,2,hangup()
```

Passaggio 4: Modifica il file extensions.conf nel server B:

```
[default]
exten=_44XX,1,dial(SIP/A-out/${EXTEN})
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/${EXTEN})
exten=_45XX,2,hangup()
```

### Supporto ai domini in Asterisk (sip.conf)

Il protocollo SIP segue l'architettura di Internet. La prima cosa da fare prima di configurare il SIP è impostare correttamente i server DNS. In un ambiente SIP, puoi chiamare un utente situato in qualsiasi proxy SIP, e altri utenti possono chiamare te utilizzando il tuo SIP Uniform Resource Identifier (URI). Per impostare un server DNS per il SIP, devi aggiungere record SRV al tuo server DNS.

```
; SIP server/proxy and its backup server/proxy
sip1.yourdomain.com
21600 IN A
200.180.4.169
sip2.yourdomain.com
21600 IN A
200.175.61.150
;
; DNS SRV records for SIP
_sip._udp.yourdomain.com  21600 IN SRV 10 0 5060 sip1.voip.school.
_sip._udp.yourdomain.com  21600 IN SRV 20 0 5060 sip2.voip.school.
```

Dopo aver configurato il DNS, puoi utilizzare l'URI, che punta a un utente SIP, un telefono SIP o un'extension telefonica. Un URI SIP ha un aspetto simile a un indirizzo email (es. sip:chuck@yourpartnerdomain.com). Utilizzando gli URI SIP, non è necessario alcun numero di telefono per effettuare una chiamata da un telefono SIP a un altro. Per chiamare un utente esterno, utilizza semplicemente un'istruzione come quella mostrata di seguito.

```
exten=4000,1,dial(SIP/chuck@yourpartnerdomain.com)
```

Alcuni parametri possono controllare il comportamento del dominio.

```
srvlookup=yes
```

Questo parametro abilita le ricerche DNS SRV sulle chiamate in uscita. Utilizzando questo parametro, è possibile effettuare chiamate utilizzando nomi SIP basati sul dominio.

```
allowguest=yes
```

Questo parametro consente di elaborare un INVITE esterno senza autenticazione. Elabora la chiamata all'interno del context definito nella sezione general o nell'istruzione domain. Attenzione: se definisci un context nella sezione general con accesso alla PSTN, un utente esterno può chiamare la PSTN tramite il tuo PBX. In questo caso, sosterrai eventuali addebiti. Consenti solo le tue extension nel context definito nella sezione general.

![Connessione ad altri server SIP tramite dominio: youdomain.com e yourpartnerdomain.com scambiano segnalazione SIP, in modo che utenti come lee e bruce possano chiamare chuck e norris utilizzando URI SIP](../images/07-sip-and-pjsip-fig09.png)

```
domain=acme.com,default
```

Il comando domain ti consente di gestire più di un dominio all'interno di Asterisk. Se una chiamata proviene da uno specifico dominio, viene indirizzata a uno specifico context.

```
;autodomain=yes
```

Questo parametro include l'IP locale e l'hostname nei domini consentiti.

```
;allowexternaldomains=no
```

Il valore predefinito è yes. Decommenta la riga per non consentire chiamate verso domini esterni.

### Configurazioni SIP avanzate (sip.conf)

Questa sezione spiega alcuni parametri avanzati del canale SIP legacy, come la presenza, la selezione dei codec, le opzioni DTMF e la marcatura QoS dei pacchetti. I **concetti** (BLF/presenza, negoziazione dei codec, modalità DTMF, marcatura DSCP) si applicano anche a PJSIP, ma i nomi dei parametri `sip.conf` mostrati qui **non** esistono in Asterisk 22. In PJSIP, la modalità DTMF è `dtmf_mode=` su un endpoint e i codec vengono impostati con `allow=`/`disallow=`.

#### Presenza SIP

La presenza SIP è parzialmente implementata in Asterisk. Asterisk supporta richieste come SUBSCRIBE e NOTIFY per gli utenti a seconda dello stato di un canale. Asterisk non supporta il metodo SIP PUBLISH. In altre parole, puoi sottoscriverti agli stati (occupato, libero e squillo) di un canale, ma non puoi pubblicare informazioni come “assente” o “non disturbare”. Lo scenario più comune per la presenza è il busy lamp field (BLF), in cui simuli il comportamento di un sistema KS con spie per ogni extension e trunk. Parametri SIP per la presenza:

- allowsubscribe=yes: Consente i metodi di sottoscrizione SIP
- subscribecontext=sip_subscribers: Context in cui cercare gli hint
- notifyring=yes: Invia NOTIFY SIP su squillo
- notifyhold=yes: Invia NOTIFY SIP su attesa
- counteronpeer (rinominato da limitonpeer per Asterisk 1.4.x): Applica il contatore solo sul lato peer
- callcounter=yes: Abilita i contatori di chiamata nel dispositivo.
- busylevel=1: Soglia per il numero di chiamate per considerare il dispositivo come occupato.

Ad esempio: Passaggio 1: Testare la presenza SIP con Asterisk non è difficile. Per prima cosa, configuriamo i file sip.conf e extensions.conf.

Nel file sip.conf

```
[general]
bindaddr=0.0.0.0
bindport=5060
disallow=all
allow=ulaw
allowsubscribe=yes
notifyringing=yes
notifyhold=yes
limitonpeer=yes
counteronpeer=yes
subscribecontext=default
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
[2001]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
In the file extensions.conf
[default]
exten=2000,hint,SIP/2000
exten=2001,hint,SIP/2001
exten=_20XX,1,dial(SIP/${EXTEN})
exten=_20XX,n,Hangup()
```

Passaggio 2: Ora configura il softphone per utilizzare la presenza. Ti mostreremo come configurare il softphone SipPulse.

- Sequenza: tasto destro->SIP Account Settings->Properties->Presence
- Cambia il modello di presenza da peer-to-peer a presence agent, il che farà sì che il softphone si sottoscriva ad Asterisk per gli eventi SIP.

Passaggio 3: Aggiungi il contatto ad altri softphone. In questo esempio, il softphone SipPulse è l'account 2000, quindi aggiungeremo un contatto per l'account 2001. Sequenza: Apri il pannello destro (pannello presenza nel softphone)->Clicca su Contacts->Add a contact. Inserisci il nome 2001. Visualizza come 2001 e non dimenticare di selezionare la casella Show this contact’s availability.

Passaggio 4: Ora chiama l'extension 2001 e controlla lo stato del telefono nel pannello destro del softphone. Usa il comando console `core show hints` per vedere lo stato della presenza cambiare nel server (nel legacy chan_sip, `sip show inuse` mostrava quante chiamate avevi su ogni linea). Su Asterisk 22, usa `pjsip show endpoints` per ispezionare lo stato dell'endpoint e del canale. Lo stato di presenza/BLF appare nei contatti del softphone o nel pannello BLF: il modo esatto in cui viene mostrato dipende dal client.

#### Configurazione dei codec

La configurazione dei codec è semplice e diretta. Puoi impostare le parole allow e disallow nella sezione [general] o nella sezione peer/user. La best practice è standardizzare il codec per evitare la transcodifica, che è intensiva per il processore. Si prega di utilizzare lo stesso codec per messaggi e prompt.

```
[general]
disallow=all
allow=g729
```

#### Opzioni DTMF

In alcune occasioni, passerai delle cifre a un'applicazione come la voicemail o un sistema di risposta vocale interattiva (IVR). È importante passare il DTMF correttamente. Il metodo più semplice per passare il DTMF è chiamato inband. Viene impostato nella sezione [general] o peer/user del file sip.conf. Quando imposti dtmfmode=inband, i toni DTMF vengono generati come suoni nel canale audio. Il problema principale di questo metodo è che, quando comprimi il canale audio utilizzando un codec come g729, i suoni vengono distorti e i toni DTMF non vengono riconosciuti correttamente. Se hai intenzione di utilizzare dtmfmode=inband, usa il codec g.711 (ulaw e alaw).

```
dtmfmode=inband
```

Un altro approccio consiste nell'utilizzare RFC2833, che ti consente di passare i toni DTMF come eventi denominati nei pacchetti RTP.

```
dtmfmode=rfc2833
```

Infine, puoi passare le cifre DTMF all'interno dei pacchetti SIP, invece che nei pacchetti RTP. Questo metodo è definito nelle RFC3265 (eventi di segnalazione) e RFC2976.

```
dtmfmode=info
```

Dopo il rilascio della versione 1.2, è ora possibile utilizzare:

```
dtmfmode=auto
```

Questo tenta di utilizzare RFC2833; se non è possibile, utilizza i toni in banda.

#### Configurazione della marcatura Quality of Service (QoS)

La QoS è un insieme di tecniche responsabili della qualità della voce. La QoS è implementata in modo tale da ridurre larghezza di banda, latenza e jitter. Le principali funzioni QoS sono la pianificazione dei pacchetti, la frammentazione e la compressione dell'intestazione. La QoS è implementata negli switch e nei router, non da Asterisk stesso. Tuttavia, Asterisk può aiutare router e switch marcando i pacchetti per una consegna espressa. La marcatura viene eseguita utilizzando i differentiated services code points (DSCP) definiti nelle RFC 2474 e RFC2475.

```
tos_sip=cs3
tos_audio=ef
tos_video=af41
```

A partire dalla versione 1.4, è possibile specificare codici diversi per segnalazione (SIP), audio (RTP) e video (RTP).

### Autenticazione SIP (sip.conf)

Quando il legacy `chan_sip` riceveva una chiamata SIP, seguiva le regole descritte nel diagramma seguente. Tre parametri giocavano un ruolo importante nell'autenticazione SIP. Su Asterisk 22, l'autenticazione viene configurata invece con oggetti PJSIP `auth` (`type=auth`, `auth_type=userpass`, `username=`, `password=`) referenziati da un endpoint, e il controllo dell'accesso IP viene eseguito con `permit=`/`deny=` sull'endpoint o tramite un `acl`.

![Flusso decisionale dell'autenticazione chan_sip legacy: Asterisk controlla l'intestazione From rispetto a sip.conf, tenta la sezione type=user/peer corrispondente e le credenziali MD5, e ricorre a insecure=invite o allowguest prima di consentire o negare la chiamata](../images/07-sip-and-pjsip-fig10.png)

```
allowguest=yes/no
```

Questo parametro controlla se un utente senza un peer corrispondente può autenticarsi senza nome e secret. Abbiamo discusso questo parametro nella sezione sul supporto ai domini.

```
insecure=invite,port
```

Quando utilizziamo insecure=invite, Asterisk non genera il messaggio “407 Proxy Authentication Required”. Senza questo messaggio, l'utente può effettuare una chiamata senza autenticazione. Questo viene spesso utilizzato per connettersi ai provider di servizi VoIP. Le chiamate provenienti dal provider di servizi VoIP solitamente non sono autenticate.

```
autocreatepeer=yes/no
```

Questo comando viene utilizzato quando Asterisk è connesso a un proxy SIP. Crea dinamicamente un peer per ogni chiamata. Quando questa opzione è abilitata, qualsiasi UAC può connettersi al server Asterisk. È importante limitare la connessione IP al proxy SIP. Il proxy SIP, a sua volta, si occupa del controllo degli accessi. La configurazione del peer si basa sulle opzioni generali e sul campo dell'intestazione “Contact” del pacchetto SIP. Attenzione: utilizzare con estrema cautela poiché apre completamente Asterisk.

```
secret=secret, remotesecret=secret
```

Questo parametro configura il secret per l'autenticazione; usa secret per le richieste in entrata e remotesecret per le richieste in uscita. Se non vuoi presentare i secret in file di testo, puoi utilizzare md5secret per includere un hash invece del secret. Per generare il secret MD5, puoi utilizzare:

```
echo -n "username:realm:secret" |md5sum
```

Quindi utilizza la seguente istruzione:

```
md5secret=0b0e5d467890....
```

Attenzione: non dimenticare di utilizzare il parametro –n; il ritorno a capo verrebbe utilizzato nel calcolo dell'md5.

```
deny=0.0.0.0/0.0.0.0
permit=192.168.1.0/255.255.255.0
```

Le istruzioni sopra negheranno tutti gli indirizzi IP e consentiranno l'UAC solo dalla rete locale (192.168.1.0/24).

#### Opzioni RTP

È possibile controllare alcuni parametri RTP.

```
rtptimeout=60
```

Questo termina le chiamate senza attività RTP per più di 60 secondi quando non sono in attesa.

```
rtpholdtimeout=120
```

Questo termina le chiamate senza attività RTP anche in attesa (dovrebbe essere maggiore di rtptimeout).

### NAT traversal SIP (sip.conf)

La *teoria* del NAT (i quattro tipi di NAT, il problema dell'intestazione Contact, i keep-alive e il forzare il media attraverso il server) è a livello di protocollo ed è trattata nel capitolo *SIP & PJSIP in depth*. I parametri `sip.conf` mostrati qui (`nat=`, `qualify=`, `directmedia=`, `externaddr=`, `localnet=`) sono **legacy chan_sip** e sono stati rimossi in Asterisk 21+. In PJSIP questi si mappano su impostazioni di trasporto/endpoint come `rewrite_contact=yes`, `force_rport=yes`, `rtp_symmetric=yes`, `direct_media=no`, `external_media_address`, `external_signaling_address` e `local_net=` sul trasporto, più `qualify_frequency=` sull'AOR.

Nel legacy chan_sip, il parametro `nat` aveva cinque opzioni:

- nat = no — Nessuna gestione NAT speciale oltre a RFC3581
- nat = force_rport — Finge che ci fosse un parametro rport anche se non c'era
- nat = comedia — Invia il media alla porta da cui Asterisk l'ha ricevuto, indipendentemente da dove l'SDP dice di inviarlo.
- nat = auto_force_rport — Imposta l'opzione force_rport se Asterisk rileva NAT (predefinito)
- nat = auto_comedia — Imposta l'opzione comedia se Asterisk rileva NAT

Quando inserisci l'istruzione “nat=force_rport” nel file sip.conf, stai dicendo ad Asterisk di ignorare l'indirizzo contenuto nel campo dell'intestazione “Contact” dell'intestazione SIP e di utilizzare l'indirizzo IP sorgente e la porta nell'intestazione IP del pacchetto, e anche di inviare il media all'indirizzo da cui è stato ricevuto, ignorando il contenuto dell'intestazione SDP.

```
nat=force_rport,comedia
```

È necessario mantenere aperta la mappatura NAT. Se il NAT scade, Asterisk non può inviare un INVITE all'UAC. L'UAC è in grado di inviare chiamate, ma non di riceverne. La seguente istruzione può essere utilizzata per mantenere aperto il NAT.

```
qualify=yes
```

Qualify invierà regolarmente un pacchetto SIP utilizzando il metodo OPTIONS, il che aiuterà a mantenere aperto il NAT. Qualify invia un OPTIONS ogni 60 secondi e ogni 10 secondi quando l'host non è raggiungibile. Puoi usare “sip show peers” per vedere la latenza per i peer. Se il NAT dell'utente è di tipo simmetrico, non è possibile inviare pacchetti direttamente da un UAC all'altro; in tal caso devi forzare l'RTP attraverso Asterisk utilizzando:

```
directmedia=no
```

#### Asterisk dietro NAT (sip.conf)

Tutti gli scenari precedenti presuppongono che il server Asterisk abbia un indirizzo Internet esterno (valido). A volte il server Asterisk viene implementato dietro un firewall con NAT. In questo caso, è necessario eseguire alcune configurazioni aggiuntive.

![Asterisk dietro NAT: un firewall mappa l'indirizzo pubblico 200.180.4.168 al server Asterisk interno (192.168.1.100), inoltrando il SIP su UDP 5060 e l'intervallo RTP UDP 10000–20000 definito in rtp.conf](../images/07-sip-and-pjsip-fig13.png)

1. Configura il firewall per reindirizzare staticamente la porta UDP 5060 al server Asterisk.
2. Configura il firewall per reindirizzare staticamente le porte UDP da 10000 a 20000.

Se vuoi limitare il numero di porte aperte, puoi modificare il file `rtp.conf` per cambiare l'intervallo di porte RTP. Un altro modo è utilizzare un firewall intelligente che supporti il protocollo SIP per aprire le porte RTP dinamicamente.

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

Passaggio 3: Configura Asterisk per includere l'indirizzo esterno nei campi dell'intestazione dei pacchetti SIP, incluso il Session Description Protocol (SDP). Puoi farlo aggiungendo le seguenti due istruzioni al file sip.conf:

```
externaddr=200.180.4.168
;External IP address
localnet=192.168.1.0/255.255.255.0
;Internal Network Address
nat=force_rport,comedia
```

Il primo parametro externaddr dice ad Asterisk di includere l'indirizzo IP esterno all'interno delle intestazioni SIP per le destinazioni esterne. Il secondo parametro localnet consente ad Asterisk di differenziare tra indirizzi esterni e interni. Facoltativamente, puoi utilizzare externhost se utilizzi un DNS dinamico con un indirizzo DHCP sul server.

### Stringhe di composizione SIP (chan_sip)

La tecnologia di dial-string `SIP/...` mostrata di seguito è il driver chan_sip rimosso. Su Asterisk 22 usa invece la tecnologia `PJSIP/...`: ad esempio `Dial(PJSIP/2000)` o `Dial(PJSIP/${EXTEN}@provider)`. Le forme e il significato sono altrimenti analoghi.

Puoi chiamare una destinazione SIP legacy utilizzando diverse stringhe di composizione:

```
SIP/peer
```

- ; È necessario avere un peer definito in sip.conf

```
SIP/flavio@voffice.com.br ; By the URI
SIP/[exten@]peer[:portno]
SIP/[user:password@domain/extension
```

Gli esempi includono:

```
exten=>s,1,Dial(SIP/ipphone)
exten=>s,1,Dial(SIP/info@voffice.com.br)
exten=>s,1,Dial(SIP/192.168.1.8:5060,20)
exten=>s,1,Dial(SIP/8500@sip.com:9876)
```

## Migrazione di un sistema legacy chan_sip a PJSIP

Poiché `chan_sip` è stato rimosso in Asterisk 21 e non è più presente in Asterisk 22, qualsiasi distribuzione `sip.conf` esistente deve essere migrata a PJSIP. Il più grande cambiamento concettuale è che un singolo `sip.conf` `[peer]` o `[friend]` viene suddiviso in diversi oggetti PJSIP, ognuno con un `type=`: un **endpoint** (impostazioni di chiamata/codec/media), uno o più oggetti **aor** (dove il dispositivo può essere raggiunto / registrazione), un oggetto **auth** (credenziali) e un **transport** condiviso (il socket in ascolto, indirizzi NAT). La seguente tabella associa i concetti più comuni.

| Concetto legacy sip.conf | Equivalente PJSIP (pjsip.conf) |
| --- | --- |
| Blocco `[peer]` / `[friend]` | `type=endpoint` + `type=aor` + `type=auth` (referenziati tramite `auth=` e `aors=`) |
| `type=friend` / `type=peer` / `type=user` | un singolo `type=endpoint` (PJSIP non ha distinzione tra friend/peer/user) |
| `host=dynamic` (registrazione dispositivo) | `type=aor` con `max_contacts=1`; il dispositivo esegue REGISTER per aggiornare il suo contatto |
| `host=<ip/hostname>` (statico) | `type=aor` con un `contact=sip:host:port` statico |
| `register=>user:secret@host/ext` (in uscita) | `type=registration` (`server_uri=`, `client_uri=`, `outbound_auth=`) |
| `secret=` / `username=` | `type=auth`, `auth_type=userpass`, `username=`, `password=` |
| `context=` | `context=` sull'endpoint |
| `disallow=all` / `allow=ulaw` | `disallow=all` / `allow=ulaw` sull'endpoint (stessa sintassi) |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` (PJSIP) — anche `inband`, `info`, `auto` |
| `directmedia=yes/no` | `direct_media=yes/no` sull'endpoint |
| `nat=force_rport,comedia` | `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes` (endpoint) |
| `qualify=yes` | `qualify_frequency=` (secondi) sull'**aor** |
| `externaddr=` | `external_media_address=` e `external_signaling_address=` sul **transport** |
| `localnet=` | `local_net=` sul **transport** |
| `insecure=invite` (provider, senza auth) | omettere `auth=`/`outbound_auth=` e usare `identify` (`type=identify`, `match=`) |
| `allowguest=yes` | endpoint `anonymous` + `allow_unauthenticated_options` (usare con cautela) |
| `tos_sip` / `tos_audio` | `tos_audio` / `tos_video` (e `cos_audio` / `cos_video`) sull'endpoint |

Un'extension che si registra e che appariva così nel `sip.conf` legacy:

```
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
disallow=all
allow=ulaw
secret=senha
```

diventa quanto segue in `pjsip.conf` su Asterisk 22:

```
[2000]
type=endpoint
context=default
disallow=all
allow=ulaw
dtmf_mode=rfc4733
direct_media=no
auth=2000
aors=2000

[2000]
type=auth
auth_type=userpass
username=2000
password=senha

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

### Lo script di conversione sip_to_pjsip.py

Asterisk include uno script di supporto, **`sip_to_pjsip.py`**, che legge un `sip.conf` esistente e produce un `pjsip.conf`. È possibile eseguirlo direttamente nella directory /etc/asterisk. L'utility si trova nell'albero dei sorgenti di Asterisk sotto `contrib/scripts/sip_to_pjsip/`, dove `${PATH_TO_ASTERISK_SOURCE}` è il percorso in cui si trovano i file sorgente di Asterisk (solitamente /usr/src/asterisk-22.x.y/):

```
${PATH_TO_ASTERISK_SOURCE}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Se lo si esegue con l'opzione `--help` si visualizzeranno le sue opzioni:

```
-h, --help                help
-p, --prefix PREFIX       prefix to use for the included config files
-q, --quiet               suppress warnings and informational messages
```

Accetta anche argomenti posizionali opzionali — `[input-file [output-file]]`, con valori predefiniti `sip.conf` e `pjsip.conf` nella directory corrente.

Considera il suo output come un **punto di partenza**: revisiona ogni oggetto generato, specialmente i transport, le impostazioni NAT e gli elenchi di codec, ed effettua test approfonditi prima di andare in produzione.

Migriamo il sip.conf nei nostri laboratori di accompagnamento presso la VoIP School Blackbelt (voip.school)

#### sip.conf

```
[general]
bindport=5060
bindaddr=0.0.0.0
context=dummy
disallow=all
allow=ulaw
alwaysauthreject=yes
allowguest=no
register=>1020:supersecret@sip.flagonc.com:5600/9999
[alice]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[bob]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[siptrunk]
type=peer
defaultuser=1020
secret=supersecret
port=5600 ; nor 5060, 5600
insecure=invite
host=sip.flagonc.com
fromuser=1020
fromdomain=sip.flagonc.com
context=from-siptrunk
```

#### pjsip.conf

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[alice]
qualify = yes
[bob]
qualify = yes
[siptrunk]
defaultuser = 1020
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
[reg_sip.flagonc.com]
type = registration
retry_interval = 20
max_retries = 10
contact_user = 9999
expiration = 120
transport = transport-udp
outbound_auth = auth_reg_sip.flagonc.com
client_uri = sip:1020@sip.flagonc.com:5600
server_uri = sip:sip.flagonc.com:5600
[auth_reg_sip.flagonc.com]
type = auth
password = supersecret
username = 1020
[alice]
type = aor
max_contacts = 1
[alice]
type = auth
username = alice
password = #supersecret#
[alice]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = alice
outbound_auth = alice
aors = alice
[bob]
type = aor
max_contacts = 1
[bob]
type = auth
username = bob
password = #supersecret#
[bob]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = bob
outbound_auth = bob
aors = bob
[siptrunk]
type = aor
contact = sip:1020@sip.flagonc.com:5600
[siptrunk]
type = identify
endpoint = siptrunk
match = sip.flagonc.com
[siptrunk]
type = auth
username = siptrunk
password = supersecret
[siptrunk]
type = endpoint
context = from-siptrunk
disallow = all
allow = ulaw
from_user = 1020
from_domain = sip.flagonc.com
auth = siptrunk
outbound_auth = siptrunk
aors = siptrunk
```

Sebbene la conversione sembri corretta, possiamo vedere che alcuni elementi come qualify=yes non possono essere mappati direttamente. Per risolvere, è necessario aggiungere alla sezione aor il comando qualify_frequency=time in secondi. Esempio di seguito.

```
[bob]
type = aor
max_contacts = 1
qualify_frequency=15
```

La configurazione completa di PJSIP è trattata nel capitolo *SIP & PJSIP in depth*, e la documentazione ufficiale su docs.asterisk.org offre una copertura completa del canale. Nei nostri laboratori di accompagnamento su voip.school, il laboratorio 5 ti permette di mettere in pratica ciò che hai appena imparato.

## Riepilogo

Questo capitolo ha raccolto le tecnologie di canale che precedono le odierne implementazioni puramente VoIP, ma che Asterisk 22 supporta ancora. Hai visto come le linee e i telefoni **analogici** si collegano tramite interfacce **FXO/FXS** su DAHDI, come vengono forniti i collegamenti **TDM digitali** (E1/T1 e ISDN PRI/BRI) e come **IAX2** (`chan_iax2`) serva ancora come trunk server-to-server efficiente e NAT-friendly, sebbene sia ormai decisamente legacy. Hai inoltre rivisitato il driver ritirato **`chan_sip`** e la sua sintassi `sip.conf` — che incontrerai nei sistemi più vecchi ma che non esiste più in Asterisk 22 — e hai lavorato alla migrazione di un tale sistema verso PJSIP con la tabella di mappatura dei concetti e lo script `sip_to_pjsip.py`. La regola generale è: ricorri a qualsiasi cosa in questo capitolo solo quando l'hardware reale o un sistema legacy esistente ti costringono; tutto ciò che è nuovo (green-field) è PJSIP su IP.

## Quiz

1. Riguardo alle due interfacce analogiche Foreign eXchange, indica le affermazioni corrette (seleziona tutte quelle applicabili):
   - A. Un'interfaccia FXO si collega alla centrale telefonica della PSTN e ne riceve il segnale di linea.
   - B. Un'interfaccia FXS fornisce segnale di linea e alimentazione per la suoneria a un telefono analogico standard, fax o modem.
   - C. Un'interfaccia FXS è il modo corretto per collegare Asterisk a una linea telefonica.
   - D. Un'interfaccia FXO può anche essere collegata a una porta di estensione di un PBX legacy.
2. La segnalazione di supervisione su una linea analogica include quale dei seguenti elementi (seleziona tutte quelle applicabili)?
   - A. On-hook
   - B. Off-hook
   - C. Ringing
   - D. DTMF
3. L'eco, i disturbi e il rumore su una scheda analogica DAHDI sono causati il più delle volte da:
   - A. Il modo in cui Asterisk è stato compilato
   - B. Conflitti di interrupt PCI
   - C. Un codec SIP errato
   - D. Un dialplan mancante
4. Per una fatturazione precisa sui canali analogici è necessario rilevare esattamente quando l'interlocutore risponde. Quale funzionalità devi attivare su Asterisk (e richiedere alla compagnia telefonica) per farlo?
   - A. Answer reversal
   - B. Billing reversal
   - C. Polarity reversal
   - D. Dial-tone generation
5. L'hardware DAHDI è indipendente da Asterisk: la scheda fisica viene configurata in `/etc/dahdi/system.conf`, mentre `chan_dahdi.conf` definisce i canali Asterisk, non l'hardware stesso.
   - A. Vero
   - B. Falso
6. Riguardo alla capacità e alla segnalazione dei trunk digitali, indica le affermazioni corrette (seleziona tutte quelle applicabili):
   - A. Un trunk E1 trasporta 30 canali vocali e un trunk T1 ne trasporta 24.
   - B. Un ISDN PRI utilizza 30B+D su un E1 e 23B+D su un T1.
   - C. ISDN è un esempio di segnalazione CCS, mentre MFC/R2 è un esempio di segnalazione CAS.
   - D. T1 è il trunk digitale più comunemente utilizzato in Europa e America Latina.
7. Quale utility rileva automaticamente le schede DAHDI e genera `/etc/dahdi/system.conf` e `dahdi-channels.conf`?
   - A. dahdi_generator
   - B. dahdi_genconf
   - C. dahdi_cfg
   - D. generate_dahdi
8. Durante la migrazione di un `sip.conf` `[friend]` legacy verso PJSIP, un singolo blocco deve essere suddiviso in diversi oggetti. Quale set di oggetti PJSIP `type=` sostituisce normalmente un `[friend]` in registrazione?
   - A. `type=endpoint`, `type=aor` e `type=auth`
   - B. `type=peer` e `type=user`
   - C. Solo `type=sip`
   - D. `type=channel` e `type=device`
9. Qual è il principale vantaggio pratico dell'utilizzo della modalità trunk IAX2 tra due server Asterisk?
   - A. Cifra ogni chiamata con TLS per impostazione predefinita
   - B. Trasporta diverse chiamate sotto un unico header, risparmiando larghezza di banda
   - C. Elimina la necessità di qualsiasi codec
   - D. Assegna una porta UDP separata per chiamata per una qualità migliore
10. Le chiavi RSA possono essere utilizzate per l'autenticazione IAX2. Quale chiave devi mantenere segreta e quale devi fornire all'altro server?
    - A. Mantieni segreta la chiave pubblica; condividi la chiave privata
    - B. Mantieni segreta la chiave privata; condividi la chiave pubblica
    - C. Mantieni segreta la chiave condivisa; condividi la chiave privata
    - D. Entrambe le chiavi devono essere condivise

**Risposte:** 1 — A, B, D · 2 — A, B, C · 3 — B · 4 — C · 5 — A · 6 — A, B, C · 7 — B · 8 — A · 9 — B · 10 — B
