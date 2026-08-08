# Deployment, monitoring & scaling

Far rispondere a una chiamata ad Asterisk in un laboratorio è una cosa; eseguirlo come un servizio che sopravvive a crash, riavvii, aggiornamenti e attacchi — e che è possibile osservare, sottoporre a backup e far crescere — è un'altra. Questo capitolo tratta tutto ciò che accade *dopo* che il dialplan funziona. Iniziamo con il supervisore che mantiene Asterisk attivo (systemd), passiamo al suo inserimento in un container (utilizzando il laboratorio Docker del libro come esempio pratico), quindi copriamo la gestione della configurazione e i backup, il monitoraggio e l'osservabilità, e infine i pattern a cui si ricorre quando un singolo server non è sufficiente: alta affidabilità e scaling, oltre alle realtà dell'hosting nel cloud.

Tutto ciò che viene mostrato è verificato rispetto al laboratorio Asterisk 22 del libro in `lab/` — lo stesso container su cui hai lavorato durante tutto il libro.

## Obiettivi

Al termine di questo capitolo, dovresti essere in grado di:

- Eseguire Asterisk 22 in modo affidabile tramite systemd, come utente non root, con riavvio automatico
- Containerizzare Asterisk con Docker e comprendere i compromessi relativi al networking
- Mantenere `/etc/asterisk` sotto controllo di versione ed eseguire il backup dello stato corretto
- Monitorare un sistema in esecuzione tramite CLI, CDR/CEL, AMI/ARI e metriche
- Applicare pattern di alta affidabilità active/standby e di scalabilità orizzontale
- Ospitare Asterisk nel cloud in sicurezza dietro NAT e firewall

## Esecuzione di Asterisk sotto systemd

Su ogni distribuzione Linux attuale — Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9 — il gestore dei servizi è **systemd**. Il capitolo sull'installazione ha mostrato che il passaggio `make config` (eseguito durante `make install`) installa uno script init di distribuzione (`/etc/init.d/asterisk` su Debian, uno script `rc.d` su RedHat), che systemd poi avvolge automaticamente come servizio; Asterisk fornisce anche una unit systemd nativa in `contrib/systemd/asterisk.service` che è possibile installare al suo posto per un controllo più preciso.
In ogni caso, systemd è il metodo supportato e consigliato per eseguire Asterisk in produzione. Si faccia riferimento a *Installing Asterisk 22* per la compilazione vera e propria; qui ci concentriamo su ciò che il servizio offre e su come gestirlo.

### La unit di servizio e il suo ciclo di vita

Una volta che `make config` ha installato il servizio, il ciclo di vita è quello ordinario di systemd:

```
systemctl enable asterisk     # start automatically at boot
systemctl start asterisk      # start now
systemctl status asterisk     # is it running? recent log lines
systemctl restart asterisk    # full stop + start
systemctl stop asterisk       # stop
journalctl -u asterisk        # service logs via the journal
```

Alcune note operative:

- **`restart` contro un ricaricamento (reload) graduale.** `systemctl restart` interrompe il processo e termina ogni chiamata in corso. Per le modifiche alla configurazione non si desidera quasi mai questo comportamento — utilizzare invece la CLI di Asterisk: `asterisk -rx 'core reload'` (o un ricaricamento specifico per modulo come `pjsip reload`). Riservare `systemctl restart` per gli aggiornamenti o per un processo bloccato.
- **Collegarsi al daemon in esecuzione.** Con Asterisk in esecuzione come servizio, aprire la sua console con `asterisk -r` (o `asterisk -rvvv` per un output dettagliato). Questo si connette al daemon già in esecuzione tramite il suo socket di controllo; non avvia una seconda copia.

### `Restart=` sostituisce safe_asterisk

Storicamente Asterisk veniva avviato tramite il wrapper **safe_asterisk**, uno script shell che riavviava Asterisk in caso di crash. Sotto systemd quel compito spetta alla direttiva `Restart=` della unit — systemd rileva l'uscita del processo e lo riavvia, con un back-off controllato da `RestartSec=` e una protezione dai cicli di crash tramite `StartLimitIntervalSec=`/`StartLimitBurst=`. Quindi, su un host systemd, **safe_asterisk è superato** e generalmente non necessario. Se la unit fornita non lo imposta già, un override drop-in è il modo pulito per aggiungere il riavvio in caso di errore senza modificare il file pacchettizzato:

```
# /etc/systemd/system/asterisk.service.d/override.conf
[Service]
Restart=always
RestartSec=2
```

Applicarlo con `systemctl daemon-reload && systemctl restart asterisk`. L'utilizzo di un drop-in (piuttosto che la modifica della unit installata) significa che un futuro `make config` non sovrascriverà la modifica.

### Esecuzione come utente non root

Asterisk non dovrebbe essere eseguito come root in produzione — un bug di esecuzione remota di codice in un processo eseguito come root rappresenta un compromesso totale dell'host, mentre lo stesso bug in un processo senza privilegi rimane contenuto. Ci sono due punti complementari in cui questo viene applicato:

- **La unit / asterisk.conf.** La unit pacchettizzata normalmente esegue Asterisk come utente e gruppo `asterisk`. È anche possibile (o in alternativa) impostare `runuser` e `rungroup` nella sezione `[options]` di `asterisk.conf`, che il daemon rispetta quando riduce i privilegi dopo il binding:

  ```
  [options]
  runuser = asterisk
  rungroup = asterisk
  ```

- **Proprietà dei file.** Le directory di runtime devono essere scrivibili da tale utente. Dopo aver creato l'account, assicurarsi della proprietà:

  ```
  chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk \
        /var/spool/asterisk /var/run/asterisk /etc/asterisk
  ```

Poiché SIP (5060) e RTP (10000+) sono tutte porte alte, Asterisk **non** ha bisogno di root per collegarsi ad esse — solo le porte privilegiate (tipo la 25) lo richiederebbero, ma Asterisk non le usa. L'esecuzione senza privilegi è quindi gratuita. (Il capitolo sulla sicurezza approfondisce il motivo per cui questo è importante; vedere *Asterisk Security*.)

## Containerizzare Asterisk

Un container impacchetta Asterisk e le sue dipendenze esatte in un'unica immagine immutabile, in modo che ciò che testi sia byte per byte ciò che distribuisci. Il compromesso riguarda i media in tempo reale: un server SIP è sensibile alla latenza e necessita di un intervallo ampio e prevedibile di porte UDP raggiungibili dall'esterno, e la rete dei container può essere d'intralcio. Il resto di questa sezione illustra il laboratorio del libro — `lab/Dockerfile` e `lab/docker-compose.yml` — come esempio concreto e funzionante, per poi spiegare l'unica trappola in cui tutti cadono: RTP e networking a ponte (bridged).

### L'immagine: compilare Asterisk dai sorgenti

Il `Dockerfile` del laboratorio compila Asterisk 22 dai sorgenti su Debian 12. Vale la pena leggere la sua struttura anche se non ne scriverai mai uno tu stesso:

```dockerfile
FROM debian:12-slim

ARG ASTERISK_VERSION=22.10.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates pkg-config \
        libedit-dev libxml2-dev libsqlite3-dev uuid-dev libssl-dev \
        libsrtp2-dev libcurl4-openssl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# ... download + tar xzf asterisk-${ASTERISK_VERSION}.tar.gz ...

RUN ./configure --with-jansson-bundled --with-pjproject-bundled \
    && make menuselect.makeopts \
    && menuselect/menuselect --enable res_srtp --enable res_http_websocket menuselect.makeopts \
    && make -j"$(nproc)" \
    && make install \
    && make install-logrotate \
    && ldconfig

EXPOSE 5060/udp 10000-10100/udp
CMD ["asterisk", "-f", "-vvv"]
```

Tre punti da sottolineare:

- **La versione è bloccata** (`ARG ASTERISK_VERSION=22.10.0`). La riproducibilità è l'intero scopo della containerizzazione: aggiornala deliberatamente, ricompila, ritesta.
- **`--with-pjproject-bundled` e `--with-jansson-bundled`** compilano lo stack SIP con una versione corrispondente a quella di Asterisk, così dipendi da meno pacchetti apt e non dovrai mai combattere con un PJSIP della distribuzione non allineato.
- **`CMD ["asterisk", "-f", "-vvv"]`** esegue Asterisk in *foreground* (`-f`, "do not fork"). Questa è la differenza chiave rispetto a un host systemd: il processo principale di un container non deve diventare un demone, altrimenti il container si chiuderebbe immediatamente. Quindi in un container **non** si usa affatto l'unità systemd — il runtime del container (Docker, più la policy `restart:`) diventa il supervisore che il `Restart=` dell'unità era su una VM.

### Bind-mount di `/etc/asterisk`

L'immagine deliberatamente **non** contiene alcuna configurazione. Invece, `docker-compose.yml` esegue il bind-mount della directory di configurazione dell'host:

```yaml
services:
  asterisk:
    build: .
    image: astbook/asterisk:22.10.0
    container_name: astlab-asterisk
    restart: unless-stopped
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

`./asterisk/etc:/etc/asterisk:ro` mappa la directory `lab/asterisk/etc` sotto controllo di versione su `/etc/asterisk` del container, in sola lettura (`:ro`). Il vantaggio è notevole: l'immagine rimane immutabile e riutilizzabile, mentre la configurazione risiede sull'host dove può essere modificata e, cosa fondamentale, mantenuta in git (sezione successiva). Per applicare una modifica alla configurazione, modifichi il file e ricarichi — `docker compose exec asterisk asterisk -rx 'core reload'` — senza ricompilare. `restart: unless-stopped` è l'equivalente a livello di compose del `Restart=` di systemd: Docker riavvia il container se Asterisk termina, ma non se lo hai arrestato deliberatamente.

### Networking host vs. bridged — il problema RTP

Questo è il singolo errore più comune con Asterisk containerizzato, quindi vale la pena comprenderlo con precisione. Per impostazione predefinita, Docker inserisce un container in una rete **bridged** e pubblichi le singole porte con `ports:`. La segnalazione funziona bene: 5060 è una singola porta. Il problema sono i media: RTP utilizza un *intervallo* di porte UDP (il `rtp.conf` del laboratorio imposta `rtpstart=10000` / `rtpend=10100`), e **ogni** porta che potrebbe trasportare audio deve essere pubblicata.

Il laboratorio fa esattamente questo:

```yaml
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

Nota che l'intervallo di pubblicazione RTP (`10000-10100`) corrisponde esattamente a `rtp.conf`. Se sbagli — pubblichi troppe poche porte o un intervallo diverso da `rtp.conf` — le chiamate si connettono ma hanno **audio unidirezionale o assente**, perché i pacchetti RTP finiscono su una porta che Docker non sta inoltrando. Due ulteriori avvertenze con la modalità bridged:

- **Pubblicare migliaia di porte è lento e pesante.** Un intervallo RTP di produzione è tipicamente 10000–20000. Docker che crea circa 10000 inoltri proxy userland è costoso all'avvio e aggiunge un salto nel percorso dei media. Il laboratorio mantiene un intervallo deliberatamente piccolo di 100 porte perché esegue solo una o due chiamate di test.
- **NAT nell'SDP.** Dietro il bridge, Asterisk vede il suo IP privato del container e potrebbe annunciarlo nell'SDP. Su un host pubblico devi comunicare a PJSIP il suo indirizzo esterno con `external_media_address` / `external_signaling_address` sul transport (e impostare `local_net`), esattamente come faresti dietro qualsiasi NAT — vedi *Cloud hosting* qui sotto.

L'alternativa è il **networking host** (`network_mode: host`), che rimuove completamente il bridge: il container condivide lo stack di rete dell'host, quindi la 5060 e l'intero intervallo RTP sono raggiungibili senza pubblicazione di porte e senza salti extra per i media. Questa è la modalità consigliata per un vero container Asterisk: aggira completamente il problema dell'intervallo RTP. Il suo costo è l'isolamento: il container può collegarsi a qualsiasi porta dell'host e perdi la rete per-servizio di compose. (Il networking host è una funzionalità di Linux; su Docker Desktop per macOS/Windows si comporta diversamente, motivo per cui questo laboratorio didattico utilizza porte pubblicate esplicite.)

### Volumi persistenti per spool e voicemail

Il layer scrivibile di un container è **effimero**: distruggi il container e tutto ciò che ha scritto scompare. Per Asterisk ciò significa che voicemail, registrazioni, spool delle chiamate in uscita e database locale svanirebbero a ogni `docker compose up --build`. La configurazione sopravvive perché è in bind-mount dall'host; lo *stato* necessita dello stesso trattamento. All'interno del container, gli alberi rilevanti sono:

```
/var/spool/asterisk        # voicemail, monitor recordings, outgoing/, etc.
/var/lib/asterisk          # astdb.sqlite3 (the internal database)
/var/log/asterisk          # full, messages, security, cdr-csv/, cel-custom/
```

(Il container in esecuzione del laboratorio mostra esattamente questi — `/var/spool/asterisk` contiene `voicemail`, `monitor`, `outgoing`, `recording`; `/var/lib/asterisk` contiene `astdb.sqlite3`.) Per preservarli, monta volumi nominati per le directory che contengono lo stato che ti interessa:

```yaml
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro     # config (bind, in git)
      - ast-spool:/var/spool/asterisk        # voicemail + recordings (persist)
      - ast-lib:/var/lib/asterisk            # astdb (persist)
      - ast-log:/var/log/asterisk            # logs (persist)

volumes:
  ast-spool:
  ast-lib:
  ast-log:
```

Il laboratorio didattico li omette di proposito — è stateless e riproducibile per progettazione, quindi ogni `up` è un nuovo inizio — ma un container di produzione **deve** averli, altrimenti perderai la voicemail al primo redeploy.

## Gestione della configurazione e backup

Il bind-mount di cui sopra suggerisce il modello corretto: trattare `/etc/asterisk` come **codice** e
il resto come **dati**.

### Mantenere `/etc/asterisk` nel controllo di versione

La directory di configurazione è un insieme piatto di file di testo senza segreti che non possano essere
modellati tramite template — è ideale per git. Inizializzare un repository in `/etc/asterisk` (o, come
fatto nel laboratorio, mantenere la configurazione insieme al progetto ed eseguire il bind-mount). I vantaggi sono:

- Ogni modifica è revisionabile e reversibile (`git diff`, `git revert`).
- Si dispone di una traccia di controllo su chi ha modificato cosa e quando.
- Combinato con un'immagine container, un commit di configurazione noto come funzionante più un tag di immagine bloccato
  descrivono completamente una distribuzione.

Un paio di avvertenze specifiche per la configurazione di Asterisk:

- **Segreti.** `pjsip.conf` (e `manager.conf`, `ari.conf`) contengono password. Non
  eseguire il commit di segreti reali in un repository condiviso in testo in chiaro — utilizzare dei template (un file per
  ambiente, o un gestore di segreti / sostituzione di variabili d'ambiente al momento del deploy) e mantenere
  solo segnaposto in git. Le password in stile `Lab-6001-secret` banali del laboratorio vanno bene
  *solo* perché risiedono su una subnet Docker privata.
- **Templating per ambiente.** I valori realtime che differiscono tra dev, staging
  e produzione (indirizzi di bind, IP esterni, credenziali trunk, URL del database) sono
  esattamente le righe da trasformare in template, mantenendo la maggior parte della configurazione identica tra gli
  ambienti.

### Cosa sottoporre a backup

La configurazione in git copre il dialplan e gli endpoint, ma un PBX attivo accumula
*stato* che non si trova in alcun file di configurazione. Un backup completo è:

| Cosa | Dove | Perché |
|------|-------|-----|
| Configurazione | `/etc/asterisk/` | dialplan, endpoints (anche in git) |
| Voicemail & registrazioni | `/var/spool/asterisk/` | dati utente — insostituibili |
| Database interno | `/var/lib/asterisk/astdb.sqlite3` | chiavi `DB()`, stato del dispositivo |
| CDR / CEL | `/var/log/asterisk/cdr-csv/` o archivio SQL | fatturazione & cronologia |
| Database esterni | il tuo MySQL/PostgreSQL | realtime, CDR, voicemail |

L'**astdb** merita una nota: è il piccolo archivio chiave/valore integrato di Asterisk (un
file SQLite in `/var/lib/asterisk/astdb.sqlite3`) utilizzato dalle funzioni del dialplan `DB()`,
stati dei dispositivi, impostazioni di follow-me e simili. È possibile esportarlo per l'ispezione o il backup
dalla CLI:

```
asterisk -rx 'database show'
```

Se il tuo CDR/CEL o la voicemail o la configurazione PJSIP risiedono in un database esterno (vedi
*Asterisk Real-Time* e *Asterisk Call Detail Records*), quel database è ora la
fonte di verità per quei dati e deve essere incluso nella tua normale rotazione di backup del database —
eseguire il backup di `/etc/asterisk` da solo non è sufficiente.

## Monitoraggio e osservabilità

Non puoi gestire ciò che non puoi vedere. Asterisk espone il suo stato su quattro livelli, da una rapida occhiata umana a una pipeline di metriche: la **CLI**, i record **CDR/CEL**, gli eventi **AMI/ARI** e gli **esportatori di metriche**.

### Controlli di integrità CLI

Il controllo più rapido per verificare "se tutto funziona" è la CLI. I comandi seguenti vengono eseguiti dal vivo sul laboratorio. Prima i canali:

```
*CLI> core show channels
Channel              Location             State   Application(Data)
0 active channels
0 active calls
0 calls processed
```

`0 active calls` su un sistema inattivo è normale; su uno carico, questa è la tua concorrenza in tempo reale. `core show uptime` conferma che il processo non si è riavviato a tua insaputa:

```
*CLI> core show uptime
System uptime: 1 hour, 40 minutes, 19 seconds
Last reload: 12 minutes, 32 seconds
```

Per l'integrità SIP, `pjsip show endpoints` mostra ogni endpoint e se i suoi contatti registrati sono raggiungibili. Dal laboratorio:

```
*CLI> pjsip show endpoints
 Endpoint:  6001                                                 Unavailable   0 of inf
     InAuth:  6001/6001
        Aor:  6001                                               1
 Endpoint:  6002                                                 Unavailable   0 of inf
     InAuth:  6002/6002
        Aor:  6002                                               1
 Endpoint:  sipp                                                 Unavailable   0 of inf
        Aor:  sipp                                               1
   Identify:  sipp-identify/sipp
        Match: 172.30.0.0/24
 Endpoint:  webrtc-1000                                          Unavailable   0 of inf
     InAuth:  webrtc-1000/webrtc-1000
        Aor:  webrtc-1000                                        1
Objects found: 4
```

`Unavailable` qui significa semplicemente che nessun telefono è attualmente registrato su quegli endpoint (il laboratorio non ha client attivi) — una volta che un softphone si registra e `qualify` lo conferma, lo stato mostra il contatto come raggiungibile. Comandi complementari: `pjsip show contacts` (registrazioni correnti e tempo di round-trip), `pjsip show transports` e `pjsip show aor <name>` per un singolo AOR. Questi sono gli strumenti quotidiani per rispondere alla domanda "perché l'extension X non è raggiungibile?".

### CDR e CEL

Ogni chiamata lascia un **Call Detail Record** (CDR); il **Channel Event Logging** (CEL) aggiunge eventi più dettagliati per ogni canale. Conferma che il CDR sia attivo e quale backend lo memorizzi:

```
*CLI> cdr show status

Call Detail Record (CDR) settings
----------------------------------
  Logging:                    Enabled
  Mode:                       Simple
  Log calls by default:       Yes
  Log unanswered calls:       No
...
* Registered Backends
  -------------------
    (none)
```

Il laboratorio mostra `(none)` tra i backend registrati perché la configurazione minima del laboratorio non carica alcun modulo di archiviazione CDR — quindi i record vengono calcolati ma non scritti da nessuna parte. In produzione carichi un backend (CSV, o `cdr_odbc`/`cdr_adaptive_odbc` in MySQL/PostgreSQL) e quello diventa la tua fonte per la fatturazione e lo storico. Il CEL è **disabilitato per impostazione predefinita** (`cel show status`` reports `CEL Logging: Disabled` in the lab) and you enable it in `cel.conf` solo quando hai bisogno di dettagli a livello di evento. Entrambi sono trattati in profondità in *Asterisk Call Detail Records*; per il monitoraggio, il punto è che CDR/CEL sono il tuo registro *storico*, mentre la CLI è la tua vista *dal vivo*.

### Eventi AMI e ARI

Per il monitoraggio programmatico in tempo reale, preferisci un feed di eventi push piuttosto che interrogare la CLI:

- **AMI (Asterisk Manager Interface)** è il protocollo TCP di eventi/comandi di lunga data (`manager.conf`). Ti iscrivi e ricevi `Newchannel`, `Hangup`, `DialBegin`, `BridgeEnter`, `PeerStatus` ed eventi simili man mano che le chiamate avvengono — la spina dorsale di wallboard e strumenti di contabilità delle chiamate. Nel laboratorio, AMI è disabilitato per impostazione predefinita (`manager show settings` riporta `Manager (AMI): No`); lo abiliti e lo proteggi in `manager.conf`.
- **ARI (Asterisk REST Interface)** è la moderna interfaccia HTTP + WebSocket (`ari.conf`, servita dal server HTTP integrato). Fornisce un flusso di eventi JSON e un controllo granulare delle chiamate — la scelta giusta per le nuove integrazioni.

Entrambi sono dettagliati in *Extending Asterisk with AMI and AGI* e *The Asterisk REST Interface (ARI)*. L'avvertenza rilevante per la distribuzione: **AMI e ARI sono potenti e non devono mai essere esposti a internet.** Collega il server HTTP a localhost o a una rete di gestione, usa segreti forti e univoci e proteggi le porte con un firewall — vedi *Asterisk Security*.

### Metriche: Prometheus e Grafana

Per dashboard e avvisi, Asterisk 22 include un esportatore Prometheus, **`res_prometheus.so`** (un modulo con livello di supporto *extended*), che espone le metriche su un endpoint HTTP che un server Prometheus interroga. Oltre alle metriche di processo principali, include provider collegabili che coprono canali, chiamate, endpoint, bridge e registrazioni in uscita PJSIP:

```
# core process
asterisk_core_uptime_seconds
asterisk_core_last_reload_seconds
asterisk_core_scrape_time_ms
asterisk_core_properties
# channels
asterisk_channels_count
asterisk_channels_state
asterisk_channels_duration_seconds
# calls
asterisk_calls_count
asterisk_calls_sum
# endpoints
asterisk_endpoints_count
asterisk_endpoints_state
asterisk_endpoints_channels_count
# bridges
asterisk_bridges_count
asterisk_bridges_channels_count
# PJSIP outbound registrations
asterisk_pjsip_outbound_registration_status
```

Puoi confermare che il modulo sia presente nella build del laboratorio:

```
*CLI> module show like prometheus
Module                         Description                     Use Count  Status      Support Level
res_prometheus.so              Asterisk Prometheus Module      0          Not Running  extended
```

Mostra `Not Running` perché il laboratorio non lo configura né lo carica; abilitandolo (`prometheus.conf` più il server HTTP) trasformi Asterisk in un target per Prometheus. Punta Prometheus all'endpoint di scraping e Grafana a Prometheus, e otterrai dashboard di serie temporali (chiamate simultanee, registrazioni, trend ASR/ACD) e avvisi (ad esempio "chiamate attive scese a zero" o "picchi di fallimenti nelle registrazioni"). Per i team che utilizzano già Prometheus/Grafana, questo è il modo naturale per integrare Asterisk nell'osservabilità esistente, invece di analizzare l'output della CLI.

### Codici di risposta SIP da monitorare

Qualunque sia la pipeline, alcuni risultati SIP segnalano problemi e vale la pena impostare degli avvisi: fallimenti persistenti di sfida `401`/`407` o `403 Forbidden` suggeriscono un attacco brute-force o una tempesta di credenziali configurate male (incrocia con Fail2Ban in *Asterisk Security*); `503 Service Unavailable` indica un server o un trunk sovraccarico o congestionato; e un picco in `408 Request Timeout`/`480 Temporarily Unavailable` solitamente significa che gli endpoint sono diventati irraggiungibili (timeout NAT, fallimenti di qualify).

## Alta affidabilità e scalabilità

Un singolo server Asterisk rappresenta un punto di guasto singolo e ha un limite massimo di chiamate finito. I due problemi — *rimanere operativi* e *crescere nelle dimensioni* — hanno risposte differenti.

### Active/standby con IP flottante

Il classico e collaudato modello di HA per Asterisk è **active/standby** (non active/active — lo stato delle chiamate in Asterisk è difficile da condividere in tempo reale). Due server identici, uno attivo e uno in standby, condividono un **IP flottante (virtuale)** gestito da un cluster manager come **keepalived** (VRRP) o **Pacemaker/Corosync**. I telefoni e i trunk si registrano all'IP flottante, non a uno dei due host reali. Se il nodo attivo fallisce il controllo di integrità, l'IP flottante si sposta sullo standby, che prende il controllo.

L'avvertenza onesta: un failover IP **interrompe le chiamate in corso** — Asterisk non replica lo stato dei canali attivi tra i nodi, quindi chiunque si trovi a metà chiamata deve ricomporre il numero. Le registrazioni si ristabiliscono entro un ciclo di qualify/registration. Ciò che il failover garantisce è che il *servizio* si ripristini in pochi secondi senza intervento manuale, il che per la maggior parte dei PBX è esattamente l'obiettivo. Per rendere lo standby effettivamente in grado di subentrare, entrambi i nodi necessitano della stessa configurazione (il tuo `/etc/asterisk` gestito con git, distribuito in modo identico) e dello stesso *stato* — che è il punto successivo.

### Esternalizzare lo stato con PJSIP Realtime

L'active/standby funziona solo se lo standby è a conoscenza degli stessi endpoint e registrazioni del nodo attivo. Il modo per ottenerlo è **smettere di mantenere lo stato in file piatti su una singola macchina** e spostarlo su un database condiviso letto da entrambi i nodi. **PJSIP Realtime** (Sorcery supportato da un database) fa esattamente questo: endpoint, AOR, auth — e, cosa importante, le **registrazioni** (la tabella `ps_contacts`) — risiedono in MySQL/PostgreSQL invece che in `pjsip.conf` e nella memoria locale. Entrambi i nodi Asterisk puntano allo stesso database, quindi un telefono registrato tramite un nodo è visibile all'altro. Questo è trattato in *Asterisk Real-Time* (la sezione PJSIP Realtime / Sorcery); qui il punto fondamentale della distribuzione è che **esternalizzare lo stato è il prerequisito sia per l'HA che per lo scaling orizzontale** — senza di esso, ogni nodo è un'isola.

Applica la stessa logica al resto del tuo stato: CDR/CEL in un archivio SQL condiviso, voicemail su storage condiviso/replicato (o `ODBC_STORAGE`), e le chiavi astdb da cui dipendi in un database. Una volta che lo stato è esterno, i nodi Asterisk diventano più simili a front-end intercambiabili.

### Proxy SIP in front-end (OpenSIPS)

Per scalare *oltre* la capacità di un singolo server, si inserisce un **proxy SIP/bilanciatore di carico** davanti a un pool di media server Asterisk. **OpenSIPS** è un proxy SIP appositamente progettato ad altissimo throughput (gestisce centinaia di migliaia di registrazioni e instrada la segnalazione senza toccare i media). Il proxy presenta un unico indirizzo SIP al mondo, mantiene il servizio di registrazione/localizzazione e distribuisce le chiamate tra i back-end Asterisk. Questa separazione — un livello di proxy leggero che gestisce registrazione e routing, e un livello Asterisk scalabile orizzontalmente che gestisce l'elaborazione effettiva delle chiamate (IVR, code, conferenze, transcodifica) — è il modo in cui le grandi distribuzioni crescono oltre una singola macchina. (La piattaforma SipPulse stessa utilizza OpenSIPS davanti ai suoi media/application server esattamente per questo motivo.)

### Scalabilità dei media

Il proxy distribuisce la *segnalazione* a basso costo; **i media sono la risorsa costosa**. Il relay RTP, e specialmente la transcodifica tra codec (es. Opus ↔ G.711) o l'esecuzione di grandi conferenze, è limitato dalla CPU ed è ciò che effettivamente limita un server. Strategie:

- **Evitare la transcodifica** ove possibile — negoziare un codec comune end-to-end in modo che Asterisk esegua il bridge in modo nativo (pass-through) invece di transcodificare. Questa è la vittoria più grande in termini di capacità media.
- **Scalare i media orizzontalmente** aggiungendo nodi Asterisk dietro il proxy; ognuno trasporta una quota delle chiamate simultanee.
- **Scaricare i media del browser** su un gateway WebRTC dedicato (es. Janus) in modo che il PBX non debba anche terminare e inoltrare ogni flusso DTLS-SRTP del browser — vedi *WebRTC with Asterisk*, che discute esattamente questa separazione Asterisk-più-gateway.

Dimensiona la capacità in base alle **chiamate simultanee e al carico di transcodifica**, non in base agli utenti registrati — 10.000 telefoni registrati che sono per lo più inattivi sono molto meno costosi di 200 conferenze transcodificate simultanee.

## Cloud hosting

Eseguire Asterisk su una VM cloud (AWS, GCP, Azure, una VPS) è una pratica comune e funziona bene, ma la rete cloud è **sottoposta a NAT e firewall per impostazione predefinita**, il che crea conflitti con SIP. Di seguito sono riportate le problematiche specifiche per questo tipo di implementazione.

### NAT e SDP

Una VM cloud ha quasi sempre un IP **privato** sulla propria interfaccia di rete e un IP **pubblico** separato che il provider mappa tramite NAT. Se Asterisk annuncia l'IP privato nell'SDP, i telefoni remoti inviano l'RTP in un buco nero: il classico sintomo di audio unidirezionale o assente. Comunica a PJSIP la sua identità pubblica sul transport:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=203.0.113.10      ; the VM's PUBLIC IP
external_signaling_address=203.0.113.10
local_net=10.0.0.0/8                     ; your private/VPC range(s)
```

`external_*` fa sì che Asterisk riscriva l'indirizzo che annuncia ai peer pubblici, mentre
`local_net` gli indica quali peer sono locali (e *non* dovrebbero essere riscritti). Questa è la
stessa gestione del NAT discussa sopra per il networking a ponte di Docker: una VM cloud è, a tutti gli effetti, dietro NAT.

### Firewall e intervallo RTP

Di solito su una VM cloud si applicano due firewall: il gruppo di sicurezza / ACL di rete del **provider** e gli iptables dell'**host**. Entrambi devono aprire le stesse porte e la policy è quella descritta nel capitolo sulla Sicurezza. Il set di regole recuperato dalla prima edizione
(`docs/legacy-labs/configs/Lab7/rules.v4`) ne cattura la struttura: accetta SIP e l'intervallo RTP, accetta le connessioni established/related, scarta il resto:

```
-A INPUT -p udp -m udp --dport 5060 -j ACCEPT
-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -j DROP
```

Due correzioni apportate dal capitolo sulla Sicurezza che sono rilevanti qui: apri la **5061 su TCP** (non UDP) se utilizzi SIP/TLS, e ricorda che l'intervallo UDP RTP nel tuo firewall deve corrispondere esattamente a
`rtpstart`/`rtpend` in `rtp.conf`: lo stesso intervallo che pubblichi su un container.
Non duplicare qui la configurazione di iptables/Fail2Ban; **segui le sezioni sul firewall, Fail2Ban e TLS/SRTP di *Asterisk Security*** (Fail2Ban monitora il canale di log `security` che il laboratorio abilita già in `logger.conf`) e applica tale policy *sia* nel firewall dell'host che nel gruppo di sicurezza cloud.

### Latenza, regione e SBC

- **Scegli una regione vicina ai tuoi utenti.** La voce è sensibile alla latenza: una latenza unidirezionale bocca-orecchio superiore a circa 150 ms è percepibile. Ospita la VM nella regione più vicina alla maggior parte dei tuoi telefoni e trunk; il traffico media intercontinentale è udibilmente peggiore.
- **Metti un SBC davanti per qualsiasi implementazione esposta su internet.** Un **Session Border Controller** termina SIP/RTP al margine, nasconde la tua topologia, normalizza il NAT e assorbe il traffico DoS e di scansione prima che raggiunga Asterisk. La raccomandazione principale del capitolo sulla Sicurezza — *non esporre Asterisk direttamente su internet* — vale doppiamente nel cloud, dove l'IP pubblico della tua VM viene scansionato pochi minuti dopo l'avvio. Un SBC (o almeno un proxy SIP protetto come OpenSIPS più Fail2Ban) è lo standard per il margine di rete.

## Riepilogo

Il deployment è la fase in cui un dialplan funzionante diventa un servizio affidabile. Su una VM, esegui Asterisk tramite **systemd** come utente **non-root**, lasciando che il `Restart=` dell'unità lo mantenga attivo (safe_asterisk è stato sostituito) e utilizzando `core reload` anziché `systemctl restart` per le modifiche alla configurazione. La **containerizzazione** con Docker — come avviene nel laboratorio del libro — ti fornisce un'immagine immutabile e bloccata con la configurazione **bind-mounted** da una `/etc/asterisk` gestita con git; l'insidia è rappresentata dai media, quindi utilizza **host networking** oppure pubblica un intervallo di porte RTP che **corrisponda esattamente a `rtp.conf`**, e monta **persistent volumes** per spool/voicemail/astdb in modo che lo stato sopravviva a un redeploy. Tratta la configurazione come codice ed **esegui il backup dello stato** che la configurazione non cattura: voicemail, registrazioni, `astdb.sqlite3` e CDR/CEL. **Osserva** il sistema su quattro livelli: la CLI (`core show channels`, `pjsip show endpoints`) per la vista in tempo reale, **CDR/CEL** per lo storico, **AMI/ARI** per gli eventi programmatici e l'esportatore **`res_prometheus`** verso Grafana per dashboard e avvisi, mantenendo AMI/ARI fuori dalla rete pubblica. Per **rimanere operativo**, esegui una configurazione active/standby con un **floating IP** (accettando che il failover interrompa le chiamate attive); per **crescere**, esternalizza lo stato con **PJSIP Realtime**, metti davanti un pool di media server con **OpenSIPS** e minimizza la transcodifica, poiché **sono i media — non le registrazioni — a limitare le capacità di un server**. Infine, nel **cloud**, tratta la VM come se fosse dietro NAT (`external_media_address`, `local_net`), apri il firewall come indicato nel capitolo sulla Sicurezza sia nell'host che nel gruppo di sicurezza del provider, scegli una regione a bassa latenza e non esporre mai Asterisk direttamente: posiziona un **SBC** al margine della rete.

## Quiz

1. Su un host systemd, cosa sostituisce il compito del vecchio wrapper `safe_asterisk` nel riavviare un Asterisk andato in crash?
   - A. Un job cron
   - B. La direttiva `Restart=` del file unit
   - C. `systemctl enable`
   - D. Il astdb
2. Per applicare una modifica alla configurazione di un Asterisk in esecuzione **senza interrompere le chiamate**, dovresti:
   - A. `systemctl restart asterisk`
   - B. Riavviare il server
   - C. `asterisk -rx 'core reload'`
   - D. Ricostruire l'immagine del container
3. Un Asterisk containerizzato (con rete bridged) connette le chiamate ma **non ha audio**. La causa più probabile è:
   - A. Il dialplan è errato
   - B. L'intervallo di porte UDP RTP pubblicate non corrisponde a `rtpstart`/`rtpend` in `rtp.conf`
   - C. Il CDR è disabilitato
   - D. La CLI non è raggiungibile
4. Quali directory devono essere montate come **volumi persistenti** affinché un redeploy del container non perda lo stato? (seleziona tutte le opzioni applicabili)
   - A. `/var/spool/asterisk` (voicemail, registrazioni)
   - B. `/var/lib/asterisk` (astdb)
   - C. `/etc/asterisk` (già bind-mounted dall'host)
   - D. `/usr/sbin`
5. Quale comando CLI fornisce il conteggio in tempo reale delle chiamate attive?
   - A. `cdr show status`
   - B. `core show channels`
   - C. `pjsip show transports`
   - D. `module show like prometheus`
6. In Asterisk 22, il metodo supportato per esporre le metriche di chiamate/canali a uno stack Prometheus/Grafana è:
   - A. Analizzare il file di log `full`
   - B. Il modulo `res_prometheus.so`
   - C. Script AGI
   - D. Non ne esiste nessuno
7. Qual è il prerequisito sia per il failover HA che per lo scaling orizzontale su più nodi Asterisk?
   - A. Eseguire come root
   - B. Esternalizzare lo stato (es. registrazioni PJSIP Realtime in un database condiviso)
   - C. Disabilitare il CDR
   - D. Utilizzare il networking bridged
8. Quale risorsa limita più direttamente il numero di chiamate simultanee che un server Asterisk può gestire?
   - A. Il numero di utenti registrati
   - B. L'elaborazione dei media, specialmente la transcodifica
   - C. La dimensione di `/etc/asterisk`
   - D. Il backend CDR
9. Su una VM cloud, quali impostazioni di trasporto `pjsip.conf` fanno sì che Asterisk annunci il proprio indirizzo pubblico affinché l'audio remoto funzioni? (seleziona tutte le opzioni applicabili)
   - A. `external_media_address`
   - B. `external_signaling_address`
   - C. `local_net`
   - D. `qualify_frequency`
10. Per un deployment cloud esposto su internet, la regola fondamentale del capitolo sulla sicurezza è:
    - A. Utilizzare sempre due NIC
    - B. Non esporre mai Asterisk direttamente su internet; posizionare un SBC (o un proxy rafforzato + Fail2Ban) al perimetro
    - C. Utilizzare solo UDP
    - D. Disabilitare TLS

**Risposte:** 1 — B · 2 — C · 3 — B · 4 — A, B · 5 — B · 6 — B · 7 — B · 8 — B · 9 — A, B, C · 10 — B
