# Funzionalità avanzate del dialplan

Il Capitolo 3 ha discusso le basi di un dialplan. Per ragioni didattiche, non abbiamo spiegato tutte le funzionalità, ma solo alcune delle più importanti. Questo capitolo approfondirà il dialplan, descrivendo tecniche avanzate, nuove applicazioni e concetti.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Semplificare le tue voci di extension
- Gestire la sicurezza del dialplan e filtrare le extension
- Ricevere chiamate utilizzando un menu IVR
- Utilizzare le subroutine per evitare riscritture non necessarie
- Implementare un po' di sicurezza nel dialplan utilizzando "Include"
- Implementare il follow-me utilizzando AsteriskDB
- Implementare il comportamento fuori orario nel tuo PBX
- Utilizzare il comando switch per trasferire a un altro PBX
- Implementare il privacy manager
- Implementare la voicemail
- Implementare una directory aziendale

## Semplificare il dialplan

È possibile semplificare il dialplan utilizzando la parola chiave “same” per definire un'extension. Ciò dovrebbe ridurre il numero di errori di battitura nel dialplan. Controlla l'esempio qui sotto:

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Sicurezza del dialplan

È stata scoperta una vulnerabilità nel dialplan di Asterisk che consente a un utente di iniettare un nuovo canale e un numero di selezione nel proprio dialplan. Supponiamo che abbiate la seguente riga nel vostro server `exten=>_X.,1,Dial(PJSIP/${EXTEN})` e che un utente malintenzionato componga il numero `3000&DAHDI/1/011551123456789` nel softphone. Il protocollo SIP, per impostazione predefinita, accetta qualsiasi carattere alfanumerico, quindi l'extension composta attiverà effettivamente due chiamate: una per il canale PJSIP/3000 e l'altra per il canale DAHDI/011551123456789, che è un numero internazionale. Pertanto, qualsiasi utente con accesso a un'extension può effettivamente chiamare ovunque nel mondo. Il modo più semplice per evitare questo comportamento è filtrare i numeri prima di richiamare l'applicazione di chiamata. La funzione FILTER() è molto utile a questo scopo. Esempio:

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

L'applicazione di filtro vi consentirà di filtrare tutti i caratteri dal numero composto ad eccezione dei numeri da 0 a 9. Maggiori informazioni possono essere trovate nel file README-SERIOUSLY.bestpractices.txt disponibile in Asterisk.

## Ricezione di chiamate tramite un menu IVR.

Nell'ultima sezione, hai ricevuto tutte le chiamate utilizzando DID o inoltrandole all'operatore. Ora imparerai come implementare un menu IVR e come creare un servizio di risponditore automatico. Prima di entrare nello specifico, esaminiamo alcune nuove applicazioni. Abbiamo inserito l'output del comando `core show application` qui sotto semplicemente per facilitare la lettura. Puoi ottenere queste descrizioni autonomamente utilizzando `core show application <application_name>`.

### L'applicazione Background()

Questa applicazione riproduce l'elenco di file fornito mentre attende che venga composta un'extension dal canale chiamante. Per continuare ad attendere cifre dopo che questa applicazione ha terminato la riproduzione dei file, si dovrebbe utilizzare l'applicazione WaitExten. L'opzione langoverride specifica esplicitamente quale lingua tentare di utilizzare per i file audio richiesti. Qualsiasi context specificato sarà il context del dialplan che questa applicazione utilizzerà quando esce verso un'extension composta. Se uno dei file audio richiesti non esiste, l'elaborazione della chiamata verrà terminata. Opzioni:

- s - Fa sì che la riproduzione del messaggio venga saltata se il canale non è nello stato 'up' (ovvero, non ha ancora risposto). Se ciò accade, l'applicazione terminerà immediatamente.
- n - Non rispondere al canale prima di riprodurre i file.
- m - Interrompi solo se una cifra premuta corrisponde a un'extension di una sola cifra nel context di destinazione.

### L'applicazione Record()

Questa applicazione registra dal canale in un determinato nome file. Se il file esiste, verrà sovrascritto.

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' è il formato del tipo di file da registrare (wav, gsm, ecc.).
- 'silence' è il numero di secondi di silenzio consentiti prima di terminare.
- 'maxduration' è la durata massima della registrazione in secondi; se manca o è zero, non c'è un massimo.
- 'options' può contenere una delle seguenti lettere:
    - `a` — aggiunge a una registrazione esistente invece di sostituirla
    - `n` — non rispondere, ma registra comunque se la linea non ha ancora risposto
    - `q` — silenzioso (non riprodurre un segnale acustico)
    - `s` — salta la registrazione se la linea non ha ancora risposto
    - `t` — utilizza il tasto di terminazione alternativo `*` (DTMF) invece di quello predefinito `#`
    - `x` — ignora tutti i tasti di terminazione (DTMF) e continua a registrare fino alla chiusura della chiamata

Se il nome file contiene %d, questi caratteri verranno sostituiti con un numero incrementato di uno ogni volta che il file viene registrato. Usa core show file formats per vedere i formati disponibili sul tuo sistema. L'utente può premere # per terminare la registrazione e passare alla priorità successiva. Se l'utente chiude la chiamata durante una registrazione, tutti i dati andranno persi e l'applicazione terminerà.

### L'applicazione Playback()

Questa applicazione riproduce i nomi file forniti (non includere l'estensione). Le opzioni possono essere incluse dopo un simbolo pipe. L'opzione 'skip' fa sì che la riproduzione del messaggio venga saltata se il canale non è nello stato 'up' (ovvero, non ha ancora risposto).

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

Se viene specificato 'skip', l'applicazione terminerà immediatamente se il canale non è sganciato. Altrimenti, a meno che non sia specificato 'noanswer', il canale riceverà risposta prima che il suono venga riprodotto. Non tutti i canali supportano la riproduzione di messaggi mentre sono ancora agganciati. Se viene specificato 'j', l'applicazione salterà alla priorità n+101 quando il file non esiste, se presente. Questa applicazione imposta la seguente variabile di canale al termine:

- PLAYBACKSTATUS — lo stato del tentativo di riproduzione come stringa di testo, uno tra:
    - `SUCCESS`
    - `FAILED`

### L'applicazione Read()

Questa applicazione legge un numero predeterminato di cifre, per un certo numero di volte, dall'utente nella variabile fornita.

- filename -- file da riprodurre prima di leggere le cifre o il tono con l'opzione i
- maxdigits -- numero massimo di cifre accettabili. Interrompe la lettura dopo che sono state inserite maxdigits (senza richiedere all'utente di premere il tasto #). Il valore predefinito è 0 - nessun limite - per attendere che l'utente prema il tasto #. Qualsiasi valore inferiore a 0 significa lo stesso. Il valore massimo accettato è 255.

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- le opzioni sono `s`, `i`, `n`:
    - `s` — termina immediatamente se la linea non è attiva
    - `i` — riproduce filename come tono di indicazione dal tuo `indications.conf`
    - `n` — legge le cifre anche se la linea non è attiva
- attempts -- se maggiore di 1, il numero di tentativi che verranno effettuati nel caso in cui non vengano inseriti dati
- timeout -- Un numero intero di secondi da attendere per una risposta in cifre. Se maggiore di 0, tale valore sovrascriverà il timeout predefinito.

L'applicazione read() dovrebbe disconnettersi se la funzione fallisce o genera errori.

### L'applicazione Gotoif()

Questa applicazione farà sì che il canale chiamante salti alla posizione specificata nel dialplan in base alla valutazione della condizione fornita. Il canale continuerà a labeliftrue se la condizione è vera, o a 'labeliffalse' se la condizione è falsa. Le etichette sono specificate con la stessa sintassi utilizzata all'interno dell'applicazione Goto. Se l'etichetta scelta dalla condizione viene omessa, non viene eseguito alcun salto; piuttosto, l'esecuzione continua con la priorità successiva nel dialplan.

### Laboratorio: Costruire un menu IVR passo dopo passo

Creiamo un menu IVR con la seguente funzionalità. Quando viene chiamato, l'IVR riproduce un file audio con il messaggio “Benvenuti alla XYZ Corporation; premi 1 per le vendite, 2 per il supporto tecnico, 3 per la formazione, o attendi per parlare con un rappresentante.” Le cifre instradano il chiamante come segue:

- `1` — trasferimento alle vendite (PJSIP/4001)
- `2` — trasferimento al supporto tecnico (PJSIP/4002)
- `3` — trasferimento alla formazione (PJSIP/4003)
- Nessuna cifra premuta — trasferimento all'operatore (PJSIP/4000)

**Passaggio 1 – Registrare i messaggi**

Creiamo un'extension per registrare i messaggi. Per registrare un messaggio, componi da un softphone il numero `9003<filename>` (ad esempio, `9003welcome`). Quando senti il segnale acustico, inizia a registrare; premi `#` per interrompere. Sentirai un segnale acustico e il sistema riprodurrà il messaggio registrato.

**Passaggio 2 – Creare la logica del menu**

Quando si compone l'extension 9004, l'elaborazione salta al menu nell'extension `s`, priorità 1.

### Corrispondenza durante la composizione

Questo è un menu di configurazione aziendale per la ricezione di chiamate. L'applicazione `Background()` riproduce il messaggio di benvenuto e poi attende le cifre, confrontando ciò che il chiamante compone con le extension definite nel context corrente.

```
[incoming]
exten=>s,1,Background(welcome)
exten=>1,1,Dial(DAHDI/1)
exten=>2,1,Dial(DAHDI/2)
exten=>21,1,Dial(DAHDI/3)
exten=>22,1,Dial(DAHDI/4)
exten=>31,1,Dial(DAHDI/5)
exten=>32,1,Dial(DAHDI/6)
```

Quando chiami questa azienda, viene riprodotto prima il messaggio di benvenuto. Dopodiché, Asterisk attende che venga composta una cifra:

| Numero composto | Azione di Asterisk |
|---------------|-----------------|
| 1 | Chiama immediatamente `Dial(DAHDI/1)` |
| 2 | Attende il timeout, poi chiama `Dial(DAHDI/2)` |
| 21 | Chiama immediatamente `Dial(DAHDI/3)` |
| 22 | Chiama immediatamente `Dial(DAHDI/4)` |
| 3 | Attende il timeout, poi disconnette |
| 31 | Chiama immediatamente `Dial(DAHDI/5)` |
| 32 | Chiama immediatamente `Dial(DAHDI/6)` |

È importante evitare ambiguità nei menu. Tutti vogliono ricevere risposta rapidamente. Per questo motivo, non dovresti usare i numeri 2, 21 o 22.

### Laboratorio: Utilizzo dell'applicazione Read()

Prova il laboratorio con l'applicazione read(). Read accetta cifre dall'utente e le inserisce nella variabile specificata; puoi quindi utilizzare l'applicazione gotoif per reindirizzare la chiamata.

## Inclusione di context

Un context può includere i contenuti di un altro context. Nell'esempio precedente, qualsiasi canale può chiamare qualsiasi extension nel context internal, ma solo il canale 4003 può chiamare extension internazionali. È possibile utilizzare l'inclusione di context per semplificare la creazione del dialplan. Utilizzando l'inclusione di context, è possibile controllare chi ha accesso a quali extension.

### Risoluzione del problema del messaggio “number not found”

È molto comune ricevere il messaggio “number not found”. La maggior parte delle persone confonde il concetto di context inclusi perché non è affatto intuitivo. Come regola generale, per prima cosa andare al file di configurazione del canale in ingresso, come `pjsip.conf`, `chan_dahdi.conf` e `iax.conf`, e determinare il context corrente. Quindi, andare al dialplan nel file extensions.conf e verificare se il numero chiamato può essere trovato in quel context. In caso contrario, c'è qualcosa che non va nel dialplan. Le regole d'oro dei context sono: 1. Un canale può chiamare solo numeri all'interno dello stesso context del canale. 2. Il context in cui viene elaborata la chiamata è definito nel file di configurazione del canale in ingresso (`chan_dahdi.conf`, `iax.conf`, `pjsip.conf`).

## Utilizzo dell'istruzione switch

È possibile inviare l'elaborazione del dialplan a un altro server utilizzando il comando switch. Saranno necessari il nome e la chiave dell'altro server. Il context è il context di destinazione.

![10-dialplan-advanced-features figura 6](../images/10-dialplan-advanced-features-img06.png)

## Ordine di elaborazione del dialplan

Quando Asterisk riceve una chiamata in entrata, cerca nel context definito dal canale. In alcuni casi, se più di un pattern corrisponde al numero chiamato, Asterisk potrebbe non elaborare la chiamata esattamente nel modo in cui ci si aspetta. È possibile visualizzare l'ordine di corrispondenza utilizzando il comando CLI dialplan show. Esempio: supponiamo di voler comporre 912 per instradare verso un trunk analogico (DAHDI/1) e tutti gli altri numeri che iniziano con 9 verso un altro trunk analogico (DAHDI/2). Si scriverebbe qualcosa del genere:

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

Se due pattern corrispondono a una extension, è possibile controllare quale extension venga elaborata per prima utilizzando i context inclusi. Un context incluso viene elaborato dopo un pattern presente nello stesso context.

## L'istruzione #INCLUDE

Dovremmo usare un unico file di grandi dimensioni o diversi file? È possibile utilizzare l'istruzione #include <filename> per includere altri file nel proprio extensions.conf. Ad esempio, potremmo creare un users.conf per gli utenti locali e un services.conf per i servizi speciali. Fate attenzione a non confondere #include <filename> con il

```
include=>context statement.
```

## Subroutine con GOSUB

Nelle versioni precedenti di Asterisk era presente il comando Macro. Questo comando è stato deprecato molto tempo fa in favore di GOSUB. Dimostreremo qui come creare subroutine per l'elaborazione della voicemail in modo semplice e ordinato. Formato del comando:

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

Il comando GOSUB è disponibile da Asterisk 1.6 e supporta il passaggio di argomenti (disponibili all'interno della subroutine come `${ARG1}`, `${ARG2}` e così via). Con gli argomenti, è ora possibile sostituire completamente i vecchi comandi Macro. Le Macro (`app_macro`) sono state rimosse in Asterisk 21; è necessario utilizzare GOSUB per le subroutine.

### Creazione della subroutine

La definizione è molto simile. Osserva la subroutine qui sotto definita per la voicemail con il nome stdexten (scegli il nome che preferisci). Dopo aver chiamato il comando Dial con il primo argomento (nome del canale), controlliamo ${DIALSTATUS} per inviare la logica di chiamata al passaggio successivo.

```
[stdexten]
exten=>s,1,Dial(${ARG1},20,tT)
exten=>s,n,Goto(${DIALSTATUS})
exten=>s,n,hangup()
exten=>s,n(BUSY),voicemail(${ARG2},b)
exten=>s,n,hangup()
exten=>s,n(NOANSWER),voicemail(${ARG2},u)
exten=>s,n,hangup()
exten=>s,n(CANCEL),hangup
exten=>s,n(CHANUNAVAIL),hangup
exten=>s,n(CONGESTION),hangup
```

### Chiamata di una subroutine

Presta attenzione quando chiami la subroutine a utilizzare le parentesi prima dei parametri.

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Utilizzo di Asterisk DB

Per implementare l'inoltro di chiamata e le liste nere (black list), abbiamo bisogno di un modo per memorizzare e ripristinare i dati. Fortunatamente, Asterisk fornisce un meccanismo per archiviare e recuperare dati da un database integrato chiamato AstDB. Nelle versioni moderne di Asterisk (incluso Asterisk 22) AstDB è supportato da **SQLite3** (il file `/var/lib/asterisk/astdb.sqlite3`); Asterisk 1.8 e versioni precedenti utilizzavano Berkeley DB v1. È simile al database del registro di Windows, utilizzando il concetto gerarchico di family e keys. I dati persistono tra i riavvii di Asterisk. L'API family/key è invariata rispetto al backend precedente; è cambiato solo il formato di archiviazione su disco.

### Funzioni, applicazioni e comandi CLI

Esistono alcune funzioni, applicazioni e comandi CLI che interagiscono con AstDB:

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

Esempi:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

Alcune applicazioni possono essere utilizzate per manipolare AstDB:

- DB_DELETE(<family/key>) — funzione che restituisce ed elimina una singola chiave
- DBdeltree(<family>) — applicazione che elimina un'intera family/sottoalbero

La vecchia applicazione `DBdel()` non esiste più in Asterisk 22. Elimina una singola chiave con la funzione di dialplan `DB_DELETE()` — ad esempio `Set(x=${DB_DELETE(family/key)})` oppure, come operazione di scrittura, `Set(DB_DELETE(family/key)=)`. `DBdeltree()` (elimina un'intera family/sottoalbero) è ancora un'applicazione.

È possibile utilizzare anche i comandi CLI per impostare ed eliminare le chiavi:

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### Implementazione di Call Forward, DND e Blacklist

In questo esempio, imparerai come implementare l'inoltro di chiamata immediato (call forward immediate) e l'inoltro di chiamata su occupato (call forward on busy). Utilizzeremo *21* per programmare l'inoltro di chiamata immediato e *61* per programmare l'inoltro di chiamata su stato occupato. Per annullare la programmazione, usa rispettivamente #21# e #61#. Usa l'esempio precedente per popolare il database. Le family utilizzate sono:

- CFIM – Call Forward Immediate
- CFBS – Call Forward on Busy status
- DND – Do Not Disturb

Prova a popolare il database componendo:

- *21* (Estensione di destinazione per l'inoltro di chiamata immediato)
- *61* (Estensione di destinazione per l'inoltro di chiamata su stato occupato)
- *41* (Estensione da impostare su non disturbare)

Usa il comando CLI database show per vedere le family, le chiavi e i valori aggiunti.

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### Call Forward, Blacklist, DND

La subroutine verifica se il database contiene le coppie key:value corrispondenti a CFIM, CFBS o DND e le gestisce di conseguenza. La seguente subroutine richiama la routine di composizione:

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## Utilizzo di una blacklist

La vecchia applicazione `LookupBlacklist()` è stata **rimossa** da Asterisk (è scomparsa insieme al meccanismo legacy "priority+101 jump"). In Asterisk 22 si costruisce una blacklist direttamente con la funzione `DB_EXISTS()` (che verifica la presenza di una chiave e, quando trovata, ne espone il valore in `${DB_RESULT}`) più `GotoIf`. Memorizza ogni numero bloccato come chiave in una famiglia `blacklist`, quindi controlla il caller ID all'inizio del tuo context di ingresso:

```
[incoming]
exten => s,1,GotoIf($[${DB_EXISTS(blacklist/${CALLERID(num)})}]?blocked,s,1)
exten => s,n,Dial(PJSIP/4000,20,tT)
exten => s,n,Hangup()
[blocked]
exten => s,1,Answer()
exten => s,2,Playback(blockedcall)
exten => s,3,Hangup()
```

`DB_EXISTS(blacklist/${CALLERID(num)})` restituisce `1` quando il numero del chiamante è presente nel database (inviando la chiamata al context `blocked`) e `0` altrimenti, così la chiamata prosegue verso il normale `Dial()`.

Per inserire un numero nella blacklist, possiamo utilizzare la stessa risorsa di prima, usando *31* seguito dall'extension da inserire in blacklist. Per rimuovere un numero dalla blacklist, dovresti usare #31# seguito dal numero da rimuovere.

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

Puoi anche inserire i numeri nella blacklist utilizzando la CLI della console:

```
*CLI>database put blacklist <name/number> 1
```

Nota: Qualsiasi valore può essere associato alla chiave. Il test `DB_EXISTS()` cerca la chiave, non il valore. Per cancellare il numero dalla blacklist, puoi usare:

```
*CLI>database del blacklist <name/number>
```

## Contesti basati sul tempo

Nella figura seguente, abbiamo un dialplan con tre contesti. Il contesto [incoming] è dove le chiamate vengono solitamente ricevute. Abbiamo incluso quattro righe che modificano il comportamento in base all'orario di sistema, come esemplificato di seguito:

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

L'Asterisk moderno (incluso il 22) separa i campi time-include con **virgole**, non con barre verticali (pipe). La forma legacy con pipe (`include => context|times|weekdays|mdays|months`) viene analizzata come un nome di contesto letterale semplice e non riesce silenziosamente ad applicare alcuna condizione temporale.

Durante il normale orario di lavoro, l'elaborazione verrà reindirizzata al mainmenu, dove probabilmente verrà richiamato un IVR per gestire la chiamata in arrivo. Se la chiamata avviene fuori orario, verrà chiamata l'extension di sicurezza definita nella variabile ${SECURITY}. Se l'extension di sicurezza non risponde alla chiamata, questa verrà inviata alla voicemail dell'operatore.

![10-dialplan-advanced-features figura 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figura 12](../images/10-dialplan-advanced-features-img12.png)

## Messaggi basati sul tempo utilizzando gotoiftime()

La sintassi di GotoIfTime() è mostrata di seguito.

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

In Asterisk 22 il separatore di campo è la **virgola**, non la pipe (la forma con la pipe è stata deprecata in Asterisk 1.6). È supportato un campo opzionale `timezone` e ogni etichetta di diramazione utilizza la consueta forma `[[context,]extension,]priority`.

Questa applicazione può sostituire il context basato sul tempo e sembra più facile da comprendere e leggere. È possibile specificare l'orario come segue:

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=numero da 1 a 31
- <hour>=numero da 0 a 23
- <minute>=numero da 0 a 59
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

I nomi dei giorni e dei mesi non sono sensibili alle maiuscole/minuscole.

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

La precedente istruzione trasferisce l'elaborazione all'extension s nel context normalhours se la chiamata avviene tra le 08:00 e le 18:00 dal lunedì al venerdì.

## Utilizzo di DISA per ottenere un nuovo segnale di linea

DISA, o "direct inward system access", è un sistema che consente agli utenti di ricevere un secondo segnale di linea. Permette agli utenti di comporre nuovamente verso un'altra destinazione. Viene spesso utilizzato dai tecnici quando devono effettuare chiamate interurbane per il supporto tecnico durante i fine settimana; invece di chiamare direttamente verso la destinazione dalle proprie abitazioni, chiamano il numero DISA dell'ufficio, ricevono un segnale di linea e quindi chiamano la destinazione. I costi delle chiamate interurbane vengono addebitati all'azienda anziché al telefono di casa.

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

Esempio:

```
exten => s,1,DISA(no-password,default)
```

Utilizzando l'istruzione precedente, l'utente chiama il PBX e, senza richiedere alcuna password, riceve un segnale di linea. Qualsiasi chiamata che utilizza DISA verrà elaborata utilizzando il context `default`. Gli argomenti per questa applicazione includono una password globale o una password individuale all'interno di un file. Se non viene specificato alcun context, viene assunto il context `disa`. Se si utilizza un file di password, deve essere specificato il percorso completo. È possibile specificare un caller ID anche per la composizione esterna tramite DISA. Esempio:

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22 utilizza le virgole come separatori di argomenti (la forma con la barra verticale è stata deprecata nella versione 1.6). Il primo argomento è un singolo codice di accesso o il percorso verso un file di codici di accesso, e il context predefinito quando non ne viene fornito alcuno è `disa`.

## Limitare le chiamate simultanee

La funzione GROUP() consente di contare quanti canali attivi si hanno in un gruppo nello stesso momento. Esempio: si dispone di una filiale a Rio de Janeiro, dove i telefoni seguono il pattern “_214X”. Questa sede è servita da una linea dedicata, con 64K riservati alla larghezza di banda per la voce. In questo caso, il numero massimo di chiamate consentite è 2 (G.729, circa 31.2K per chiamata). Per limitare le chiamate verso Rio a due:

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

La voicemail è un sistema di segreteria telefonica computerizzato che registra i messaggi vocali in arrivo, salvandoli su disco o inviandoli tramite e-mail. A volte dispone di una rubrica dove è possibile cercare le caselle vocali per nome. In passato, i sistemi di voicemail erano molto costosi. Ora, con la telefonia IP, la voicemail sta diventando una funzionalità standard.

Per configurare la voicemail, è necessario seguire i passaggi seguenti.

**Passaggio 1: Modificare `voicemail.conf` e impostare i parametri generali.**

- `format` — codec utilizzato per registrare il messaggio (es. wav49, wav, gsm)
- `serveremail` — da chi dovrebbe apparire provenire la notifica e-mail
- `maxmsg` — numero massimo di messaggi nella casella vocale; superata questa soglia, i messaggi vengono scartati
- `maxsecs` — durata massima di un messaggio di voicemail, in secondi
- `minsecs` — durata minima di un messaggio, in secondi; al di sotto di questa soglia, non viene registrato alcun messaggio
- `maxsilence` — quanti secondi di silenzio considerare come fine del messaggio

**Passaggio 2: Modificare `voicemail.conf` e creare le caselle vocali degli utenti.**

### Voicemail.conf

Una casella vocale viene definita con una riga per casella, nel formato:

```
mailboxID => pincode,fullname,email,pager-email,options
```

I campi sono:

- **MailboxID** — solitamente il numero di extension
- **Pincode** — password per accedere al sistema di voicemail
- **Full name** — utilizzato dall'applicazione di rubrica
- **E-mail** — indirizzo per la notifica della voicemail
- **Pager e-mail** — indirizzo per la notifica tramite un gateway SMS o cercapersone
- **Options** — opzioni per singola casella (le stesse opzioni presenti in `[general]`, ma applicate a questa casella)

La voicemail dispone di diverse opzioni che ne controllano il comportamento. Per ora, ci limiteremo alle opzioni predefinite e ci concentreremo sulla definizione della casella vocale. Dopo la sezione `[general]` nel file, si inizia a configurare gli ID delle caselle vocali, ognuno nel proprio context. Esempio:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

Si prega di verificare le opzioni avanzate nel file `voicemail.conf`.

**Passaggio 3: Configurare il file `extensions.conf`.**

La subroutine `stdexten` mostrata in precedenza (sotto *Subroutines with GOSUB*) è esattamente il gestore di chiamata/voicemail necessario in questo caso: chiama l'extension e utilizza il valore della variabile di canale `${DIALSTATUS}` per reindirizzare il flusso della chiamata al messaggio di benvenuto corretto (`b` per occupato, `u` per non disponibile). Richiamarla con `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` da ogni extension in `extensions.conf`.

## Utilizzo dell'applicazione VoiceMailMain()

L'applicazione voicemailmain() viene utilizzata per configurare la casella vocale. Gli utenti possono chiamare l'applicazione, registrare il proprio messaggio di benvenuto e ascoltare i propri messaggi vocali. Per richiamare l'applicazione nel dialplan, utilizzare:

```
exten=>9000,1,VoiceMailMain()
```

Di seguito troverete un elenco delle opzioni disponibili per l'applicazione.

### Sintassi dell'applicazione Voicemail

Questa applicazione consente al chiamante di lasciare un messaggio per un elenco specificato di caselle vocali. Quando vengono specificate più caselle vocali, il messaggio di benvenuto verrà preso dalla prima casella specificata. L'esecuzione del dialplan si interromperà se la casella vocale specificata non esiste. La sintassi è mostrata di seguito:

```
 [Synopsis]
Leave a Voicemail message.
[Description]
This application allows the calling party to leave a message for the specified
list of mailboxes. When multiple mailboxes are specified, the greeting will
be taken from the first mailbox specified. Dialplan execution will stop if
the specified mailbox does not exist.
The Voicemail application will exit if any of the following DTMF digits are
received:
    0 - Jump to the 'o' extension in the current dialplan context.
    * - Jump to the 'a' extension in the current dialplan context.
This application will set the following channel variable upon completion:
${VMSTATUS}: This indicates the status of the execution of the VoiceMail
application.
    SUCCESS
    USEREXIT
    FAILED
[Syntax]
VoiceMail(mailbox[@context][&mailbox[@context][&...]][,options])
[Arguments]
options
```

![10-dialplan-advanced-features figura 13](../images/10-dialplan-advanced-features-img13.png)

```
    b: Play the 'busy' greeting to the calling party.
    d([c]): Accept digits for a new extension in context <c>, if played
    during the greeting. Context defaults to the current context.
    g(#): Use the specified amount of gain when recording the voicemail
    message. The units are whole-number decibels (dB). Only works on supported
    technologies, which is DAHDI only.
    s: Skip the playback of instructions for leaving a message to the
    calling party.
    u: Play the 'unavailable' greeting.
    U: Mark message as 'URGENT'.
    P: Mark message as 'PRIORITY'.
```

In tutti i casi, il file beep.gsm verrà riprodotto prima dell'inizio della registrazione. I messaggi vocali verranno archiviati nella directory inbox.

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

Se un chiamante preme 0 (zero) durante l'annuncio, la chiamata verrà trasferita all'extension 'o' (out) nel context corrente della voicemail. Questo può essere utilizzato per uscire verso l'operatore. Se durante la registrazione il chiamante preme # o il limite di silenzio scade, la registrazione viene interrotta e la chiamata passa alla priorità successiva. Assicuratevi di gestire la chiamata dopo la riproduzione della voicemail, come mostrato di seguito.

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### Contrassegnare i messaggi vocali come urgenti

È possibile contrassegnare alcuni messaggi come "urgenti". Sono disponibili due metodi per farlo:

- Passare l'opzione 'U' nell'applicazione voicemail()
- Specificare review=yes nel file voicemail.conf. Se si utilizza questa opzione, l'utente sarà in grado di contrassegnare il messaggio come urgente dopo aver registrato le istruzioni vocali.

## Invio della voicemail tramite e-mail

In alcuni casi (come il mio), semplicemente non utilizziamo l'applicazione voicemailmain() per leggere la posta elettronica. È più semplice e pratico inviare tutti i messaggi via e-mail con l'audio in allegato. Utilizzando i parametri ‘attach’ e ‘delete’, è possibile inviare tutti i messaggi via e-mail ed eliminarli dalla casella vocale.

```
attach=yes
delete=yes
```

Per inviare la voicemail via e-mail, l'applicazione voicemail utilizza il message transfer agent (MTA), un componente del proprio sistema operativo. Debian utilizza Exim come MTA. L'applicazione che invia l'e-mail è definita nel parametro ‘mailcmd’.

```
mailcmd =/usr/sbin/sendmail -t
```

Nella distribuzione Linux Debian, l'MTA è Exim. Per configurare Exim in Debian, utilizzare:

```
dpkg-reconfigure exim4-config
```

È possibile scegliere di far inviare l'e-mail al proprio MTA direttamente tramite SMTP o uno smarthost (solitamente il server di posta della propria azienda). Verificare con il proprio amministratore di posta elettronica il modo migliore per inviare e-mail dal server Asterisk al proprio server di posta.

## Personalizzazione del messaggio e-mail

È possibile controllare il modo in cui i messaggi vengono inviati impostando le seguenti variabili: Variabili per l'oggetto e il corpo dell'e-mail:

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

Il corpo e l'oggetto dell'e-mail vengono creati a partire da un modello che si imposta nella sezione `[general]` di `voicemail.conf`. È possibile modificare sia il corpo che l'oggetto, ma il limite di dimensione del messaggio è di 512 byte. Nel modello, `\n` inserisce una nuova riga e `\t` inserisce una tabulazione.

L'esempio `emailsubject` qui sotto è semplice. L'esempio `emailbody` è molto simile a quello predefinito; quello predefinito mostra solo il CIDNAME quando non è nullo, altrimenti il CIDNUM, oppure "an unknown caller" quando entrambi sono nulli.

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Interfaccia Web per la voicemail

Nella distribuzione dei sorgenti è presente uno script Perl chiamato `vmail.cgi`, situato in `contrib/scripts/vmail.cgi` all'interno dell'albero dei sorgenti di Asterisk (viene ancora fornito con Asterisk 22). Il comando `make install` non installa questa interfaccia; è necessario eseguire `make webvmail` dalla directory dei sorgenti. Questo script richiede che l'interprete di comandi Perl e un server web (come Apache) siano installati sul server.

```
make webvmail
```

L'obiettivo `make webvmail` installa lo script (setuid root) nella directory CGI del proprio server web (`HTTP_CGIDIR`) e copia le immagini di supporto da `images/*.gif` in `HTTP_DOCSDIR/_asterisk` (di default `/var/www/html/_asterisk`). Se tali percorsi non corrispondono alla struttura del proprio server web, modificare le variabili `HTTP_CGIDIR` e `HTTP_DOCSDIR` nel file `Makefile` di primo livello prima di eseguire l'obiettivo.

## Notifica della voicemail

È possibile configurare la voicemail per inviare un messaggio di notifica al proprio telefono quando si riceve un nuovo messaggio vocale. In Asterisk 22, la Message Waiting Indication (MWI) funziona con telefoni PJSIP e SIP, così come con i telefoni DAHDI. Per indicare una voicemail non ascoltata, una spia luminosa potrebbe lampeggiare oppure il telefono potrebbe riprodurre un segnale acustico. È necessario configurare la mailbox nel file di configurazione del canale corrispondente. Esempio: `pjsip.conf` (nella sezione endpoint):

```
mailboxes=8590
```

In PJSIP, l'hint della mailbox viene impostato con l'opzione `mailboxes` all'interno della sezione endpoint di `pjsip.conf`, anziché con il vecchio `mailbox=` di `sip.conf`. Le sottoscrizioni MWI sono gestite dal modulo `res_pjsip_mwi`.

![L'interfaccia web di Comedian Mail (`vmail.cgi`): il login alla Web-Voicemail di Asterisk — inserisci la tua mailbox e la password per riprodurre, salvare, inoltrare o eliminare i messaggi vocali da un browser. È ancora fornita con Asterisk 22 e viene installata con `make webvmail`.](../images/10-dialplan-advanced-features-img14.png)

### Laboratorio: Notifica dei messaggi sul telefono

Questo laboratorio è stato testato utilizzando un softphone SIP.

1. Modifica `pjsip.conf` e aggiungi `mailboxes=4401` nella sezione endpoint per il dispositivo denominato 4401.
2. Modifica il `extensions.conf` e crea un'extension per registrare una voicemail verso le extension 4401.

```
exten=9008,1,voicemail(4401,b)
```

3. Vai sulla console ed esegui il reload.
4. Nel softphone SipPulse, apri le impostazioni dell'account SIP e abilita il controllo della voicemail (message-waiting) per l'account.
5. Componi il 9008 e lascia un messaggio.
6. Osserva l'icona del messaggio sul telefono.

## Utilizzo dell'applicazione directory

Questa applicazione consente di trovare rapidamente un utente da chiamare. L'elenco dei nomi e delle relative extension viene recuperato dal file di configurazione di voicemail, voicemail.conf. La sintassi per l'applicazione può essere visualizzata utilizzando core show application directory:

```
-= Info about application 'Directory' =-
[Synopsis]
Provide directory of voicemail extensions.
[Description]
This application will present the calling channel with a directory of
extensions from which they can search by name. The list of names and
corresponding extensions is retrieved from the voicemail configuration file,
"voicemail.conf".
This application will immediately exit if one of the following DTMF digits
are received and the extension to jump to exists:
'0' - Jump to the 'o' extension, if it exists.
'*' - Jump to the 'a' extension, if it exists.
[Syntax]
Directory([vm-context][,dial-context[,options]])
[Arguments]
vm-context
    This is the context within voicemail.conf to use for the Directory.
    If not specified and 'searchcontexts=no' in "voicemail.conf", then
    'default' will be assumed.
dial-context
    This is the dialplan context to use when looking for an extension
    that the user has selected, or when jumping to the 'o' or 'a' extension.
options
    e: In addition to the name, also read the extension number to the
    caller before presenting dialing options.
    f(n): Allow the caller to enter the first name of a user in the
    directory instead of using the last name.  If specified, the optional
    number argument will be used for the number of characters the user should
    enter.
    l(n): Allow the caller to enter the last name of a user in the
    directory.  This is the default.  If specified, the optional number
    argument will be used for the number of characters the user should enter.
    b(n):  Allow the caller to enter either the first or the last name
    of a user in the directory.  If specified, the optional number argument
    will be used for the number of characters the user should enter.
    m: Instead of reading each name sequentially and asking for
    confirmation, create a menu of up to 8 names.
    p(n): Pause for n milliseconds after the digits are typed.  This
    is helpful for people with cellphones, who are not holding the receiver
    to their ear while entering DTMF.
    NOTE: Only one of the <f>, <l>, or <b> options may be specified.
    *If more than one is specified*, then Directory will act as  if <b> was
    specified.  The number of characters for the user to type defaults to
    '3'.
```

### Laboratorio: Utilizzo dell'applicazione directory

1. Modificare il file voicemail.conf per aggiungere due extension nel dialplan

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. Creare queste extension nel proprio dialplan

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. Andare sulla console ed eseguire il reload
4. Comporre 9006 e registrare un nome per ciascuna extension (4400, 4401)
5. Comporre 9007 e selezionare le tre lettere del cognome per una extension (Eas=327). Se questa è l'opzione corretta, premere ‘1’ per trasferire la chiamata al nome.

## Lab: Mettiamo tutto insieme

Finora, hai appreso diversi concetti relativi al dialplan. Mettiamo tutte le applicazioni, le funzioni e i concetti in un esempio di dialplan in modo che tu possa capire come vengono utilizzati insieme. Ti guideremo attraverso l'intera configurazione del PBX per lo scenario descritto di seguito.

- 4 trunk analogici
- 16 extension basate su SIP
- 3 classi di servizio:
    - restrict (interno, locale e 1-800)
    - ld (lunga distanza)
    - ldi (internazionale)
- Messaggio fuori orario
- Auto attendant

### Step 1 – Configurazione dei canali

**Trunk analogici (`chan_dahdi.conf`).** Per prima cosa, configureremo i trunk analogici nel file di configurazione dei canali DAHDI `chan_dahdi.conf`. In questo caso, utilizzeremo una scheda T400P Digium con 4 interfacce FXO. Supponiamo che il driver sia già caricato e che il file di configurazione del driver (/etc/dahdi/system.conf) sia configurato correttamente.

![10-dialplan-advanced-features figura 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**Canali SIP (`pjsip.conf`).** Abbiamo scelto la numerazione del dialplan da 2000 a 2099. Verranno utilizzati due codec: G.729 e G.711 ulaw. Il primo verrà utilizzato per i telefoni che utilizzano Asterisk su Internet o WAN, mentre il secondo verrà utilizzato per i telefoni che utilizzano la rete locale. In `pjsip.conf`, stabiliremo quali dispositivi apparterranno a ciascuna classe di servizio (restrict, ld, ldi). Per ridurre la vulnerabilità agli attacchi brute force, utilizzeremo gli indirizzi MAC dei telefoni come nomi dei dispositivi. Consiglio vivamente di utilizzare password complesse per evitare attacchi brute force!

Definiamo un transport e tre template riutilizzabili — una base endpoint con i codec condivisi, un'autenticazione digest e un singolo AOR di contatto — quindi colleghiamo ciascun dispositivo ai template e sovrascriviamo solo ciò che differisce (il suo context di classe di servizio e le credenziali). `host=dynamic` diventa un AOR a cui il telefono si registra, e `directmedia` diventa `direct_media`:

```ini
; pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[endpoint-base](!)
type=endpoint
disallow=all
allow=ulaw,gsm
direct_media=yes

[auth-digest](!)
type=auth
auth_type=digest

[aor-single](!)
type=aor
max_contacts=1

[00001A000002](endpoint-base)
context=restrict
auth=00001A000002
aors=00001A000002
mailboxes=20
[00001A000002](auth-digest)
username=00001A000002
password=#s2cr2t#
[00001A000002](aor-single)

[00001A000003](endpoint-base)
context=ld
dtmf_mode=rfc4733
auth=00001A000003
aors=00001A000003
mailboxes=20
[00001A000003](auth-digest)
username=00001A000003
password=#s3cr3t#
[00001A000003](aor-single)

[00001A000004](endpoint-base)
context=ldi
dtmf_mode=rfc4733
auth=00001A000004
aors=00001A000004
mailboxes=20
[00001A000004](auth-digest)
username=00001A000004
password=#s3cr3t#
[00001A000004](aor-single)
```

### Step 2 – Configurazione del dialplan

Ora iniziamo a configurare il file extensions.conf. Definiamo le extension interne e la selezione locale

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

Definiamo le chiamate LD (lunga distanza)

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

Definiamo le chiamate internazionali

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Step 3 - Ricezione di chiamate tramite un auto-attendant

Per ricevere chiamate, utilizza due context. Il primo è per il funzionamento durante l'orario normale, dove la chiamata verrà ricevuta da un auto-attendant. Il secondo è per l'orario di chiusura, dove il chiamante riceverà un messaggio come "hai chiamato l'azienda XYZ, il nostro orario normale è dalle 08:00 alle 18:00; se conosci il numero dell'extension di destinazione puoi provare a comporlo ora o riagganciare." Menu: Orario normale, Fuori orario Nei menu sottostanti, il sistema riprodurrà un messaggio avvisando il chiamante che l'azienda è stata raggiunta fuori dal normale orario di lavoro, consentendo al chiamante di comporre il numero dell'extension di destinazione (qualcuno potrebbe lavorare oltre il normale orario di lavoro).

```
[incoming]
include=>normalhours,08:00-18:00,mon-fri,*,*
include=>afterhours,18:00-23:59,*,*,*
include=>afterhours,00:00-07:59,*,*,*
include=>afterhours,*,sat-sun,*,*
[normalhours]
exten=>s,1,Goto(mainmenu,s,1)
[afterhours]
exten=>s,1,Background(afterhours)
exten=>s,2,hangup()
exten=>i,1,hangup()
exten=>t,1,hangup()
include=>restrict
```

Menu: Principale e Vendite Durante il normale orario di lavoro, la chiamata riceve risposta da un menu auto-attendant, ricevendo un messaggio come "benvenuti alla XYZ Company; componi 1 per le vendite, 2 per il supporto tecnico, 3 per la formazione, o il numero dell'extension desiderato".

```
[globals]
OPERATOR=PJSIP/2060
SALES=PJSIP/2035
TECHSUPPORT=PJSIP/2004
TRAINING=PJSIP/2036
[mainmenu]
exten=> s,1,Background(welcome)
exten=>1,1,Goto(sales,s,1)
exten=>2,1,Goto(techsupport,s,1)
exten=>3,1,Goto(training,s,1)
exten=>i,1,Playback(Invalid)
exten=>i,2,hangup()
exten=>t,1,Dial(${OPERATOR},20,Tt)
include=>restrict
[sales]
exten=>s,1,Dial(${SALES},20,Tt)
[techsupport]
exten=>s,1,Dial(${TECHSUPPORT},20,Tt)
[training]
exten=>s,1,Dial(${TRAINING},20,Tt)
```

Con tutte queste istruzioni, la funzionalità del tuo dialplan è ora pronta. Nella prossima sezione, dimostreremo come gestire il PBX.

## Riepilogo

In questo capitolo, hai imparato come ricevere chiamate utilizzando un IVR o un risponditore automatico. Hai studiato il concetto di inclusione di context e implementato alcuni esempi. Le subroutine sono state utilizzate per evitare di digitare ripetutamente, e il database di Asterisk (AstDB, supportato da SQLite3 in Asterisk 22) è stato utilizzato per le funzioni che richiedono l'archiviazione di dati (ad esempio, inoltro di chiamata, non disturbare, blacklist). Infine, hai imparato come implementare il comportamento fuori orario e hai implementato un dialplan completo utilizzando questi concetti.

## Quiz

1. Un include di contesto dipendente dal tempo utilizza la forma `include => context,<times>,<weekdays>,<mdays>,<months>`. Cosa fa `include => normalhours,08:00-18:00,mon-fri,*,*`?
   - A. Esegue le extension dal lunedì al venerdì, dalle 08:00 alle 18:00
   - B. Esegue le opzioni ogni giorno in tutti i mesi
   - C. Nulla; il formato non è valido
2. Nell'Asterisk moderno (incluso Asterisk 22), i campi di un `include =>` basato sul tempo e di `GotoIfTime()` sono separati da quale carattere?
   - A. Il pipe `|`
   - B. La virgola `,`
   - C. Il punto e virgola `;`
   - D. Lo slash `/`
3. Per chiamare diversi canali contemporaneamente (facendoli squillare simultaneamente), li si separa all'interno di `Dial()` con il carattere ___.
4. Un menu vocale che riproduce un messaggio mentre attende che il chiamante digiti un'extension viene solitamente creato con l'applicazione ___.
5. È possibile includere il contenuto di un altro file all'interno di `extensions.conf` utilizzando l'istruzione ___ (nota: questa è diversa dall'istruzione di contesto `include =>`).
6. In Asterisk 22, il database integrato AstDB è supportato da:
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. Quando si utilizza `Dial(type1/identifier1&type2/identifier2)`, Asterisk chiama ogni canale in sequenza, attendendo 20 secondi tra l'uno e l'altro.
   - A. Falso
   - B. Vero
8. Con l'applicazione Background(), è necessario attendere il termine della riproduzione del messaggio prima di poter premere una cifra DTMF per scegliere un'opzione.
   - A. Falso
   - B. Vero
9. Data la sintassi `Goto([[context,]extension,]priority)`, quali delle seguenti sono invocazioni valide dell'applicazione Goto()? (selezionare tutte le opzioni applicabili)
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Per eliminare una singola chiave da AstDB nel dialplan di Asterisk 22, si utilizza:
    - A. L'applicazione `DBdel()`
    - B. La funzione `DB_DELETE()`
    - C. L'applicazione `DBdeltree()`
    - D. L'applicazione `LookupBlacklist()`

**Risposte:** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
