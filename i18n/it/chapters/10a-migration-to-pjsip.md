# Migrazione da chan_sip a PJSIP: un ricettario

Se stai leggendo questo testo con un sistema Asterisk 13, 16 o 18 ancora in produzione, hai una scadenza. `chan_sip` — il driver di canale SIP originale configurato tramite `sip.conf` — è stato **deprecato in Asterisk 17, rimosso dalla build predefinita in Asterisk 19 ed eliminato completamente in Asterisk 21**. Non esiste in Asterisk 22 LTS. Non c'è alcun flag per riattivarlo, nessun `noload` per evitarlo, nessun pacchetto da installare. L'unico driver di canale SIP in Asterisk 22 è **PJSIP** (`res_pjsip` più `chan_pjsip`), configurato tramite `pjsip.conf`.

Quindi, un aggiornamento ad Asterisk 22 è, per la maggior parte dei siti, un *progetto di migrazione SIP* tanto quanto un aggiornamento di versione. La buona notizia è che il protocollo sulla linea non cambia — un telefono che si registrava e chiamava ieri si registrerà e chiamerà domani — e Asterisk fornisce uno strumento di conversione per svolgere l'80% del lavoro di traduzione al posto tuo. Questo capitolo è un ricettario pratico: la mappatura dei concetti, lo script di conversione, le traduzioni affiancate `sip.conf` → `pjsip.conf` per i casi che hai effettivamente, le modifiche al dialplan e alla CLI che accompagnano il passaggio, la migrazione realtime (database), oltre a una lista di controllo e alle insidie che colpiscono gli utenti.

Tutto ciò che è riportato qui è verificato rispetto al laboratorio Asterisk 22.10.0 del libro. Il materiale approfondito sull'eredità di `chan_sip` — e una conversione completa end-to-end di un `sip.conf` multi-dispositivo — si trova nel capitolo *Legacy channels*; questo capitolo ne è il compagno focalizzato, in stile ricettario.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Spiegare perché `chan_sip` non è più presente in Asterisk 22 e cosa lo sostituisce
- Mappare il modello peer/user/friend di `sip.conf` sul modello a oggetti PJSIP
  (endpoint + aor + auth + identify + transport + registration)
- Eseguire lo script di conversione `sip_to_pjsip.py` ed esaminarne criticamente l'output
- Tradurre manualmente i tipi di dispositivo comuni (telefono in registrazione, trunk in ingresso, registrazione in uscita) da `sip.conf` a `pjsip.conf`
- Migrare le impostazioni di NAT, media, DTMF, codec e autenticazione opzione per opzione
- Aggiornare il dialplan (`SIP/` → `PJSIP/`) e la CLI (`sip show` → `pjsip show`)
- Migrare una distribuzione realtime/ARA da `sippeers`/`sipregs` alle tabelle Sorcery `ps_*`
- Seguire una checklist di migrazione ed evitare le insidie classiche

## Perché migrare

`chan_sip` ha servito Asterisk per quasi due decenni, ma portava con sé un debito architettonico: un modulo monolitico, un singolo blocco di configurazione per dispositivo, un supporto multi-trasporto debole e uno stack SIP rimasto indietro rispetto alle RFC. **PJSIP** — costruito sullo stack maturo pjproject di Teluu e introdotto in Asterisk 12 — è stato il sostituto creato da zero. Con Asterisk 21, il progetto Asterisk ha completato il lavoro e rimosso `chan_sip` dall'albero dei sorgenti.

È possibile verificare la situazione su qualsiasi sistema Asterisk 22:

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip` restituisce *0 modules loaded* — semplicemente non è presente. Non c'è nulla *verso cui* migrare se non PJSIP, quindi l'unica vera domanda è *come*, non *se*.

## La mappatura concettuale: non esiste un singolo "peer"

Il cambiamento mentale che mette in difficoltà chiunque provenga da `sip.conf` è questo: **PJSIP non ha alcun `[peer]`.** In `sip.conf` un blocco tra parentesi quadre — un `peer`, un `user` o un `friend` — descriveva *tutto* ciò che riguardava un dispositivo: le sue credenziali, dove raggiungerlo, i suoi codec, il suo comportamento NAT, il suo context nel dialplan. PJSIP suddivide deliberatamente quel singolo blocco in diversi oggetti più piccoli e con uno scopo specifico, ognuno contrassegnato da un `type=`, che *si richiamano a vicenda per nome*:

| Oggetto PJSIP (`type=`) | Responsabilità |
| --- | --- |
| `endpoint` | L'identità di gestione delle chiamate del dispositivo: codec, context, DTMF, media, NAT e riferimenti ai suoi `auth`/`aors`/`transport` |
| `aor` (Address of Record) | *Dove* raggiungere il dispositivo — contatti registrati o statici, `max_contacts`, qualify |
| `auth` | Credenziali (nome utente/password) per l'autenticazione in entrata e/o in uscita |
| `identify` | Corrispondenza di una richiesta in entrata con un endpoint tramite **IP sorgente** invece che tramite l'utente `From` |
| `transport` | Il/i socket in ascolto: protocollo, indirizzo/porta di bind, indirizzi NAT/esterni |
| `registration` | Un REGISTER **in uscita** da Asterisk verso un provider |

La distinzione tra `friend`/`peer`/`user` scompare completamente — in PJSIP tutto è un `endpoint`. Un singolo `sip.conf` friend diventa quindi, tipicamente, tre oggetti (`endpoint` + `auth` + `aor`) che condividono un nome e puntano l'uno all'altro:

```
                sip.conf                              pjsip.conf
            ┌──────────────┐              ┌──────────┐   ┌──────┐   ┌─────┐
            │   [2000]     │   becomes    │ endpoint │──▶│ auth │   │ aor │
            │ type=friend  │  ─────────▶  │  [2000]  │   │[2000]│   │[2000]│
            │ host=dynamic │              │  auth=───┼──▶└──────┘   └──────┘
            │ secret=...   │              │  aors=───┼───────────────▶ ▲
            └──────────────┘              └────┬─────┘
                                               │ transport=
                                               ▼
                                          ┌───────────┐
                                          │ transport │  (shared by all endpoints)
                                          └───────────┘
```

L'endpoint è il collante. Esso nomina un `transport` (o eredita quello predefinito), un oggetto `auth` e uno o più `aors`. Il modello a oggetti è trattato in modo approfondito in *SIP & PJSIP in depth*; qui ci serve solo come destinazione di ogni traduzione.

## Lo strumento di conversione `sip_to_pjsip.py`

Asterisk include uno script Python che legge un `sip.conf` esistente e scrive un
`pjsip.conf`. Non viene eseguito come comando CLI — risiede nell'**albero dei sorgenti di Asterisk**, non nei binari installati:

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Sull'Asterisk 22.10.0 del laboratorio il percorso completo è, ad esempio,
`/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`. La stessa directory contiene `sip_to_pjsql.py` (la variante realtime/SQL, trattata in seguito) e
i moduli di supporto `astconfigparser.py`, `astdicts.py` e `sqlconfigparser.py`.

### Esecuzione

Lo script accetta argomenti posizionali opzionali — `[input-file [output-file]]` —
che hanno come predefiniti `sip.conf` e `pjsip.conf` nella directory corrente:

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

Le sue uniche opzioni reali sono:

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

Legge l'input, stampa `Converting to PJSIP...` e scrive il file di output.
Internamente analizza ogni sezione `sip.conf` e, per ogni dispositivo, emette i corrispondenti
oggetti `endpoint`, `auth`, `aor`, `registration` e (dove può dedurli)
`transport`, applicando automaticamente le mappature delle opzioni descritte nella sezione successiva.

### Cosa fa — e i suoi limiti

Considera l'output come una **prima bozza, non come un file finito.** Lo script è onesto
riguardo alle proprie lacune: tutto ciò che non riesce a mappare correttamente viene scritto in un blocco chiaramente delimitato all'inizio del file di output:

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[softphone]
qualify = yes
...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
```

Nota in quel frammento reale che `qualify = yes` da un peer `sip.conf` è finito nel
blocco *non mappato* — poiché PJSIP qualifica sull'**aor** con
`qualify_frequency` (secondi), non come un booleano sul dispositivo, lo script lo lascia a te affinché tu possa impostarlo deliberatamente. Le limitazioni pratiche da pianificare sono:

- **I transport sono ipotizzati, non progettati.** Lo script emette un
  `transport-udp` di base da `bindport`/`bindaddr`, ma non può conoscere i tuoi certificati TLS,
  le tue esigenze TCP o il tuo layout multi-bind. Rivedi e riscrivi il transport.
- **NAT e indirizzi esterni richiedono un intervento umano.** `externaddr`/`localnet` potrebbero non
  essere convertiti correttamente; conferma manualmente `external_media_address`, `external_signaling_address`
  e `local_net` sul transport.
- **`qualify`, timer personalizzati e una manciata di opzioni finiscono nei "non mappati".**
  Leggi quel blocco dall'inizio alla fine e decidi per ciascuno di essi.
- **Le liste di codec, i context e la sicurezza richiedono una revisione.** Verifica `disallow`/`allow`,
  il dialplan `context` e assicurati che nessun dispositivo sia lasciato aperto involontariamente.

Il flusso di lavoro è quindi: esegui lo script su un file *di prova*, confrontalo e revisionalo, integra le parti corrette nel tuo `pjsip.conf` reale, quindi testa in modo esaustivo prima della messa in produzione.

## Traduzioni affiancate

Queste sono le ricette. `sip.conf` a sinistra, l'equivalente `pjsip.conf` verificato a destra (impilato qui per motivi di larghezza della pagina). Ogni nome di opzione e valore sulla destra è stato verificato rispetto al laboratorio Asterisk 22 con `config show help res_pjsip ...`.

### Un telefono che si registra (`host=dynamic`)

Il dispositivo più comune: un telefono da scrivania o un softphone che effettua l'accesso con un segreto e registra la propria posizione.

**Legacy `sip.conf`:**

```
[2000]
type=friend
host=dynamic
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmfmode=rfc2833
secret=Sup3rSecret
qualify=yes
```

**Asterisk 22 `pjsip.conf`:**

```
[2000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
auth=2000
aors=2000

[2000]
type=auth
auth_type=digest
username=2000
password=Sup3rSecret

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

Mosse chiave: `host=dynamic` diventa un `aor` con `max_contacts` (il dispositivo esegue il REGISTER per compilare il proprio contatto); `secret=` diventa `password=` all'interno di un `type=auth`; `qualify=yes` diventa `qualify_frequency=60` (secondi) sull'**aor**, non sull'endpoint. Imposta `max_contacts` su un valore superiore a 1 solo se desideri realmente lo stesso account su più dispositivi contemporaneamente.

### Un trunk in ingresso (`host=<ip>` / `type=peer`)

Un provider che ti invia chiamate da un indirizzo IP noto. Qui non c'è registrazione: autentichi il *traffico del carrier tramite il suo IP di origine* utilizzando `identify`.

**Legacy `sip.conf`:**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp-in]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw

[itsp-in]
type=aor
contact=sip:203.0.113.10:5060

[itsp-in]
type=identify
endpoint=itsp-in
match=203.0.113.10
```

La traduzione cruciale è **`insecure=invite` → `identify`**. In `chan_sip`, `insecure=invite` diceva ad Asterisk "non richiedere l'autenticazione per gli INVITE in ingresso da questo peer". PJSIP ottiene lo stesso effetto *facendo corrispondere l'IP di origine all'endpoint* con `type=identify`/`match=`, che è sia più esplicito che più sicuro. Il `host=` statico diventa un `contact=` permanente sull'`aor` in modo da poter anche chiamare *in uscita* verso il carrier. `match=` accetta un IP, un intervallo CIDR o un hostname (risolto al momento del caricamento della configurazione — ricarica se l'IP del provider cambia).

### Una registrazione in uscita (`register =>`)

Quando il provider vuole che *tu* effettui l'accesso presso di *loro*, `chan_sip` utilizzava una singola riga `register =>` in `[general]`. PJSIP la sostituisce con un oggetto `type=registration` dedicato più un `outbound_auth`.

**Legacy `sip.conf`:**

```
[general]
register => 1020:supersecret@sip.example.com:5600/9999

[itsp]
type=peer
host=sip.example.com
port=5600
defaultuser=1020
secret=supersecret
fromuser=1020
fromdomain=sip.example.com
context=from-pstn
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
outbound_auth=itsp-auth
aors=itsp-aor
from_user=1020
from_domain=sip.example.com

[itsp-auth]
type=auth
auth_type=digest
username=1020
password=supersecret

[itsp-aor]
type=aor
contact=sip:sip.example.com:5600

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:sip.example.com:5600
client_uri=sip:1020@sip.example.com:5600
contact_user=9999
retry_interval=60
```

Mappa i campi `register =>` uno a uno: le credenziali `1020:supersecret` diventano l'oggetto `auth` (referenziato come `outbound_auth`); `@sip.example.com:5600` diventa il `server_uri`; il suffisso `/9999` — la parte utente a cui il provider invia le chiamate in ingresso — diventa `contact_user=9999`. `defaultuser`/`fromuser` e `fromdomain` diventano `from_user` e `from_domain` sull'endpoint. Nota che `outbound_auth` appare *due volte*: la registrazione lo utilizza per il REGISTER, l'endpoint lo utilizza per rispondere alla sfida `407` sugli INVITE in uscita.

## Riferimento per la migrazione opzione per opzione

Quando si esegue la traduzione manualmente (o si controlla l'output dello script), questa tabella funge da riferimento. Ogni nome di opzione PJSIP e la relativa posizione (endpoint / aor / auth / transport) sono stati verificati nel laboratorio Asterisk 22.

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | Dove |
| --- | --- | --- |
| `[peer]` / `[user]` / `[friend]` | `type=endpoint` (+ `auth` + `aor`) | — |
| `host=dynamic` | `max_contacts=1` (device REGISTERs) | aor |
| `host=<ip/host>` | `contact=sip:<host>:<port>` | aor |
| `register => u:p@host/ext` | `type=registration` + `outbound_auth` | registration |
| `secret=` | `password=` | auth |
| `username=` / `defaultuser=` | `username=` | auth |
| `secret=` (auth method) | `auth_type=digest` | auth |
| `nat=force_rport,comedia` | `force_rport=yes` + `rewrite_contact=yes` + `rtp_symmetric=yes` | endpoint |
| `directmedia=yes/no` | `direct_media=yes/no` | endpoint |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` | endpoint |
| `disallow=` / `allow=` | `disallow=` / `allow=` (same syntax) | endpoint |
| `context=` | `context=` | endpoint |
| `qualify=yes` | `qualify_frequency=<seconds>` | aor |
| `insecure=invite` | omit auth; use `type=identify` + `match=` | identify |
| `fromuser=` / `fromdomain=` | `from_user=` / `from_domain=` | endpoint |
| `externaddr=` / `externip=` | `external_media_address=` + `external_signaling_address=` | transport |
| `localnet=` | `local_net=` | transport |

### Una nota su `secret` → `auth` e `auth_type`

Il parametro `secret=` di `chan_sip` diventa il campo `password=` di un oggetto `type=auth`. Il **metodo di autenticazione** viene impostato con `auth_type`. Utilizzare `auth_type=digest`. I valori più vecchi `userpass` e `md5` funzionano ancora, ma sono **deprecati e convertiti silenziosamente in `digest`** — verificato direttamente dal laboratorio:

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

Vedrete `auth_type=userpass` nelle configurazioni più vecchie e nell'output dello script di conversione (e nei capitoli precedenti di questo libro). È innocuo, ma scrivete `digest` in qualsiasi nuova configurazione.

### NAT, media e DTMF nel dettaglio

Questi tre aspetti sono la causa della maggior parte dei ticket post-migrazione del tipo "si registra ma non c'è audio". La scorciatoia `chan_sip` di `nat=force_rport,comedia` racchiudeva tre comportamenti in un'unica opzione; PJSIP li separa in modo da poter gestire ciascuno di essi:

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

Per i **media**, `directmedia` diventa `direct_media` (il trattino basso è l'unica modifica); mantenete `direct_media=no` ogni volta che la chiamata deve essere ancorata su Asterisk — attraverso NAT, o per registrare/transcodificare/trasferire. Per il **DTMF**, l'RFC è stato rinumerato: il parametro `dtmfmode=rfc2833` di `chan_sip` corrisponde al `dtmf_mode=rfc4733` di PJSIP (stesso meccanismo out-of-band telephone-event, numero RFC corrente). Il laboratorio conferma che i valori validi per `dtmf_mode` sono `rfc4733`, `inband`, `info`, `auto` e `auto_info`, con valore predefinito `rfc4733`.

Per i **codec**, non cambia nulla: `disallow=all` seguito da `allow=ulaw` (ecc.) utilizza la sintassi identica sull'endpoint PJSIP.

## Modifiche al dialplan e alla CLI

La migrazione non si ferma a `pjsip.conf`. Due elementi di uso quotidiano cambiano.

### Stringhe dei canali: `SIP/` → `PJSIP/`

Ogni `Dial()` e riferimento al canale nel `extensions.conf` che nominava la vecchia
tecnologia deve essere aggiornato:

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Le stringhe di composizione dei trunk seguono lo stesso schema: `Dial(SIP/${EXTEN}@itsp)` diventa
`Dial(PJSIP/${EXTEN}@itsp)`. PJSIP aggiunge inoltre la funzione `PJSIP_DIAL_CONTACTS()`
per far squillare contemporaneamente ogni contatto associato a un AOR, e le funzioni di dialplan `PJSIP_HEADER()` /
`PJSIP_MEDIA_OFFER()`; esegui un grep nel tuo dialplan per i riferimenti SIP `SIP/`,
`SIPPEER`, `SIPCHANINFO` e `CHANNEL(...)` e traducili ciascuno.

### CLI: `sip show ...` → `pjsip show ...`

L'intero albero dei comandi `sip ...` scompare insieme al driver. Le sostituzioni:

| Comando `chan_sip` | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (o `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (o `core reload`) |

I vecchi comandi non si comportano semplicemente in modo diverso: non esistono più. In
laboratorio, `sip show peers` restituisce *No such command*, mentre `pjsip show endpoints`,
`pjsip show aors`, `pjsip show auths`, `pjsip show contacts`,
`pjsip show registrations` e `pjsip show identifies` sono tutti presenti. Il comando di
risoluzione dei problemi più utile — il logger dei pacchetti SIP che stampava ogni messaggio
con `sip set debug` — è ora **`pjsip set logger on`** (con `pjsip set logger
host <ip>` per concentrarsi su un singolo peer).

## Migrazione Realtime (ARA)

Se utilizzavi `chan_sip` da un database (Asterisk Realtime Architecture), i tuoi
dispositivi risiedevano nella tabella `sippeers` e le registrazioni in `sipregs`. PJSIP utilizza un
livello di archiviazione completamente diverso — **Sorcery** — con una tabella *per ogni tipo di oggetto*. La mappatura è la seguente:

| Tabella realtime `chan_sip` | Tabella/e PJSIP / Sorcery |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (una riga ciascuna, suddivise) |
| `sipregs` | `ps_contacts` (registrazioni dinamiche) |
| — (`register=>` in uscita) | `ps_registrations` |
| — (corrispondenza IP) | `ps_endpoint_id_ips` (gli oggetti `identify`) |
| — (alias di dominio) | `ps_domain_aliases` |

La suddivisione concettuale è la stessa del caso dei file flat: una riga `sippeers` diventa
*tre* righe in tre tabelle (`ps_endpoints` + `ps_aors` + `ps_auths`) che
fanno riferimento l'una all'altra tramite il nome dell'endpoint.

Due elementi rendono questa operazione gestibile:

- **Lo schema viene generato automaticamente.** Asterisk fornisce migrazioni Alembic nella directory
  `contrib/ast-db-manage/` che creano ogni tabella `ps_*`. Esegui
  `alembic upgrade head` sul database `config` per costruire lo schema PJSIP
  attuale invece di scrivere il DDL a mano.
- **Esiste uno script di conversione SQL.** Accanto a `sip_to_pjsip.py` si trova
  **`sip_to_pjsql.py`** nella stessa directory `contrib/scripts/sip_to_pjsip/`;
  riutilizza la stessa logica di `convert()` ma genera un file `pjsip.sql` di
  istruzioni `INSERT` per le tabelle `ps_*` invece di un file di configurazione flat. Come per lo
  strumento per i file flat, revisiona l'output prima di caricarlo.

Infine, punta `sorcery.conf` al tuo database in modo che PJSIP legga endpoint, aor,
auth e contact dalle tabelle `ps_*` (tramite `res_config_odbc` /
`res_pjsip_realtime`), esattamente come `extconfig.conf` puntava un tempo `sippeers` al
database per `chan_sip`. Le meccaniche realtime sono trattate nel capitolo *Realtime*;
il punto specifico della migrazione è semplicemente *quali tabelle corrispondono a quali*.

## Lista di controllo per la migrazione

Un ordine di operazioni pragmatico per un passaggio in produzione:

1. **Inventario.** Elenca ogni dispositivo, trunk e `register =>` in `sip.conf` (o ogni riga `sippeers`/`sipregs`). Prendi nota delle impostazioni personalizzate di NAT, codec e DTMF.
2. **Esegui il convertitore su un file di prova.** `sip_to_pjsip.py sip.conf pjsip_generated.conf`. **Non** puntarlo al tuo `pjsip.conf` attivo.
3. **Leggi il blocco "Non mapped elements"** nella parte superiore dell'output e risolvi ogni riga — specialmente `qualify`, i timer e qualsiasi cosa relativa al NAT.
4. **Progetta manualmente i transport.** Un transport per ogni IP/porta; aggiungi TLS/TCP se necessario; imposta `external_*_address` e `local_net` per le macchine in cloud/NAT.
5. **Verifica l'autenticazione.** Conferma `auth_type=digest`, nomi utente e password su ogni oggetto `auth`.
6. **Verifica NAT/media/DTMF.** `force_rport`/`rewrite_contact`/`rtp_symmetric`, `direct_media`, `dtmf_mode=rfc4733` per ogni endpoint come richiesto.
7. **Aggiorna il dialplan.** `SIP/` → `PJSIP/` ovunque; controlla le funzioni `SIP*` e le variabili di canale.
8. **Aggiorna script e monitoraggio.** Qualsiasi strumento o consumer AMI che analizzava l'output di `sip show ...` deve passare a `pjsip show ...` / azioni AMI di PJSIP.
9. **Ricarica e verifica.** `module reload res_pjsip.so`, quindi `pjsip show endpoints`, `pjsip show registrations`, `pjsip show identifies`.
10. **Testa con il packet logger.** `pjsip set logger on`; effettua una registrazione, una chiamata in entrata e una chiamata in uscita e leggi lo scambio SIP dall'inizio alla fine.

## Insidie comuni

- **`alwaysauthreject` è ora integrato — non cercarlo.** `chan_sip` necessitava di
  `alwaysauthreject=yes` in modo da non rivelare quali extension esistessero rispondendo
  in modo diverso a nomi utente errati. PJSIP fa la cosa sicura per progettazione: non rivela mai se un endpoint esiste. Non c'è alcuna opzione `alwaysauthreject` da
  impostare. La protezione correlata — la limitazione dei mittenti non identificati — è la `unidentified_request_count` / `unidentified_request_period` globale, attiva per impostazione predefinita.

- **`insecure=invite` non è un'opzione PJSIP — usa `identify`.** Non esiste
  `insecure=` in `pjsip.conf`. Il modo per accettare INVITE non autenticati da un
  carrier noto è *identificare l'endpoint tramite IP sorgente* con `type=identify` /
  `match=`. Effettua il match in modo il più restrittivo possibile (IP host specifici, non ampi CIDR) e supportalo con un `type=acl` — un trunk con match IP senza autenticazione è un bersaglio per le frodi telefoniche.

- **Un trasporto per IP/porta.** Non è possibile associare due trasporti allo stesso
  IP:porta e non è possibile associare più trasporti TCP o TLS della stessa versione IP. Lo script di conversione potrebbe emettere un trasporto che collide con uno che
  già possiedi — consolida in un singolo livello di trasporto progettato deliberatamente.

- **`qualify=yes` non si traduce in un booleano.** Appartiene all'**aor** come
  `qualify_frequency=<seconds>`. Il convertitore inserisce `qualify=yes` nel
  blocco non mappato proprio perché non esiste un booleano equivalente sull'endpoint.

- **`secret=` non è un'opzione dell'endpoint.** Le credenziali risiedono solo in un oggetto `type=auth`
  a cui l'endpoint *fa riferimento* (`auth=` per le chiamate in entrata, `outbound_auth=` per
  quelle in uscita). Inserire una password sull'endpoint non ha alcun effetto.

- **La CLI e qualsiasi script di scraping si interrompono silenziosamente.** `sip show ...` restituisce "No
  such command", non un errore che il tuo monitoraggio rileverà necessariamente. Verifica ogni
  cron job, controllo Nagios e client AMI per i comandi `sip ` prima del passaggio definitivo.

## Riepilogo

La migrazione ad Asterisk 22 comporta l'abbandono di `chan_sip`, poiché il driver è stato rimosso in Asterisk 21 e PJSIP rimane l'unico canale SIP disponibile. Il fulcro del lavoro consiste nel riesprimere ogni `sip.conf` `peer`/`user`/`friend` — che raggruppava tutto in un unico blocco — come un insieme di oggetti PJSIP cooperanti: un `endpoint` più un `auth`, un `aor` e, a seconda del dispositivo, un `identify` (trunk in ingresso), un `registration` (login in uscita) e un `transport` condiviso. Lo script `sip_to_pjsip.py` in `contrib/scripts/sip_to_pjsip/` esegue la maggior parte della traduzione e segnala onestamente ciò che non riesce a mappare in un blocco "Non mapped elements", ma il suo output è solo una prima bozza: è necessario progettare manualmente il transport, il NAT e la sicurezza ed effettuare dei test prima della messa in produzione. Oltre alla configurazione, è necessario aggiornare il dialplan (`SIP/` → `PJSIP/`) e i propri script e procedure manuali (`sip show` → `pjsip show`, `sip set debug` → `pjsip set logger`). Le implementazioni realtime passano dalle tabelle `sippeers`/`sipregs` a quelle Sorcery `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts`, con l'ausilio di `sip_to_pjsql.py` e dello schema `contrib/ast-db-manage`. Attenzione alle insidie — `alwaysauthreject` è integrato, `insecure=invite` diventa `identify`, `qualify=yes` diventa `qualify_frequency` e si deve considerare un solo transport per IP/porta — e il passaggio sarà un'operazione meccanica piuttosto che misteriosa.

## Quiz

1. Perché una distribuzione Asterisk 22 deve utilizzare PJSIP per il protocollo SIP?
   - A. `chan_sip` è più lento ma ancora disponibile
   - B. `chan_sip` è stato rimosso in Asterisk 21 e non esiste in Asterisk 22
   - C. PJSIP è il valore predefinito ma `chan_sip` può essere caricato con `modules.conf`
   - D. `chan_sip` funziona solo con TLS in Asterisk 22

2. Un singolo blocco `sip.conf` `type=friend` diventa solitamente quale insieme di oggetti PJSIP?
   - A. Un singolo `type=peer`
   - B. Solo `type=endpoint`
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. In `sip.conf`, `host=dynamic` (il dispositivo registra la propria posizione) corrisponde a:
   - A. `type=identify` con `match=dynamic`
   - B. un `type=aor` con `max_contacts` (il dispositivo esegue REGISTER)
   - C. `direct_media=yes` sull'endpoint
   - D. `type=registration`

4. Lo script di conversione `sip_to_pjsip.py` è:
   - A. Un comando CLI: `asterisk -rx 'sip_to_pjsip'`
   - B. Uno script Python nell'albero dei sorgenti di Asterisk sotto `contrib/scripts/sip_to_pjsip/`
   - C. Un modulo compilato caricato all'avvio
   - D. Parte di `res_pjsip.so`

5. Vero o Falso: L'output di `sip_to_pjsip.py` è pronto per la produzione e dovrebbe essere caricato senza revisione.

6. La scorciatoia `chan_sip` `nat=force_rport,comedia` si traduce su un endpoint PJSIP in quali tre opzioni?
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. Il `dtmfmode=rfc2833` di `sip.conf` diventa quale impostazione PJSIP?
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. Su Asterisk 22, un oggetto `auth` dovrebbe utilizzare quale `auth_type` e qual è lo stato di `userpass`?
   - A. `auth_type=userpass`; è l'unico valore valido
   - B. `auth_type=digest`; `userpass` è deprecato e convertito in `digest`
   - C. `auth_type=md5`; `digest` è deprecato
   - D. `auth_type=plaintext`; `digest` è stato rimosso

9. Un peer provider `chan_sip` con `insecure=invite` (accetta INVITE non autenticati da un IP noto) viene migrato a PJSIP utilizzando:
   - A. `insecure=invite` sull'endpoint
   - B. `allowguest=yes` in `[global]`
   - C. un oggetto `type=identify` con `match=<provider IP>`
   - D. `auth_type=anonymous`

10. In una migrazione realtime, la tabella `chan_sip` `sippeers` viene sostituita da quali tabelle PJSIP/Sorcery?
    - A. Una singola tabella `pjsip_peers`
    - B. `ps_endpoints`, `ps_aors` e `ps_auths`
    - C. `sipregs` e `voicemail`
    - D. Solo `ps_contacts`

**Risposte:** 1 — B · 2 — C · 3 — B · 4 — B · 5 — Falso · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
