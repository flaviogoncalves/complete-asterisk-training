# Installazione di Asterisk 22

Nel primo capitolo, abbiamo imparato qualcosa su come Asterisk sia utile nell'ambiente della telefonia. In questo capitolo, tratteremo come scaricare e installare Asterisk. Prima di iniziare, è essenziale imparare come compilarlo e installarlo. Il processo di compilazione può sembrare strano per i tradizionali utenti Microsoft™ Windows™, ma è piuttosto comune nell'ambiente Linux™. Compilando Asterisk è possibile ottenere un codice ottimizzato per il proprio hardware, che è ciò che faremo qui. Asterisk funziona su diversi sistemi operativi, ma manterremo le cose semplici e ne useremo solo uno: Linux. Utilizziamo **Ubuntu 24.04 LTS** perché le sue dipendenze sono facili da installare ed è una distribuzione server stabile, ben supportata e con un ingombro ridotto. Se preferisci un'altra distribuzione, adatta i nomi dei pacchetti di conseguenza.

Questa edizione si rivolge ad **Asterisk 22 LTS** (rilasciata il 2024-10-16; supporto completo fino al 2028-10-16, correzioni di sicurezza fino al 2029-10-16). Asterisk 22 è l'attuale versione a supporto a lungo termine. Si noti che Digium è stata acquisita da **Sangoma** nel 2018 e Asterisk è ora sponsorizzato da Sangoma — i riferimenti a "Digium" in tutto questo capitolo si riferiscono al marchio storico per l'hardware legacy.

## Obiettivi

Al termine di questo capitolo dovresti essere in grado di:

- Determinare i requisiti hardware per Asterisk;
- Installare Linux con le dipendenze richieste;
- Scaricare una versione stabile tramite HTTPS;
- Compilare Asterisk; e
- Imparare come avviare Asterisk all'avvio del sistema.

## Requisiti hardware minimi

Asterisk non richiede molto hardware per funzionare, tuttavia ci sono alcuni suggerimenti per scegliere l'hardware migliore per le proprie esigenze. È necessario prendere in considerazione i seguenti fattori principali durante la scelta dell'hardware:

- Numero totale di utenti registrati. Definire quante registrazioni al secondo è necessario supportare
- Numero totale di chiamate simultanee. Definire quante conversazioni di rete è necessario elaborare nell'adattatore di rete e nel bridge sul server Asterisk
- Quali codec è necessario supportare. I codec ad alta complessità richiederanno molta potenza di CPU/FPU nel server; iLBC, ad esempio, è stato misurato dal suo creatore (Global IP Sound) a circa 18 MIPS per canale per frame da 30 ms (e circa 15 MIPS per frame da 20 ms) su un DSP TI C54x
- Cancellazione dell'eco. La cancellazione dell'eco può richiedere molta CPU/FPU; in alcuni casi è opportuno scegliere la cancellazione dell'eco hardware utilizzando DSP nella scheda di interfaccia telefonica
- Disponibilità. Utilizzare RAID1 o 5 per aumentare la disponibilità. Ricordare che Asterisk è un'applicazione 24x7.

Il componente principale per un server Asterisk è l'adattatore di rete. Si raccomanda un buon adattatore di rete per server. La CPU è importante quando è necessario supportare codec ad alta complessità come g.729 e iLBC e la cancellazione dell'eco. Si può scegliere di delegare questo compito a DSP dedicati: Sangoma (precedentemente Digium) fornisce una scheda DSP chiamata TC400B in grado di supportare 120 chiamate simultanee G.729.

La best practice è scegliere un computer nuovo, di classe server, di un produttore noto. Per sapere esattamente quante chiamate simultanee o quanti utenti registrati una specifica macchina può supportare, è necessario testare questo hardware con uno strumento di stress test come SIPP (http://sipp.sourceforge.net). Alcuni produttori di hardware come Xorcom (http://www.xorcom.com) pubblicano i propri risultati sul sito web.

Nota: alcune applicazioni Asterisk, come ConfBridge e la musica d'attesa, necessitano di una sorgente di temporizzazione interna. Sui moderni sistemi Linux, questa viene fornita automaticamente dal modulo integrato `res_timing_timerfd` — non è richiesto alcun hardware telefonico. (Il vecchio timer software `dahdi_dummy` non esiste più; la sua funzionalità è stata integrata nel modulo kernel principale `dahdi` in DAHDI Linux 2.3.0.) È possibile confermare il timer attivo con il comando CLI `timing test`.

### Configurazione hardware

L'hardware di Asterisk non deve essere sofisticato. Non sono necessarie schede video costose o numerose periferiche. Alcuni suggerimenti sulla configurazione hardware:

- Disabilitare le porte USB, seriali e parallele inutilizzate per evitare il consumo di interrupt non necessari.
- Una robusta scheda di interfaccia di rete è essenziale.
- Prestare particolare attenzione se si utilizzano schede di interfaccia telefonica. Alcune schede utilizzano un bus PCI a 3,3 volt e non è facile trovare schede madri compatibili. Al giorno d'oggi, il PCI express è più facilmente reperibile.
- Prestare molta attenzione al disco rigido; i PBX lavorano solitamente in regime 24x7, mentre i desktop lavorano 8x5. Non utilizzare hardware desktop per un PBX, solitamente il disco rigido si guasta prima del primo anno. La mia raccomandazione è di utilizzare una macchina server o un'appliance progettata per eseguire applicazioni 24x7.

### Condivisione IRQ (solo per schede PCI legacy)

Questa preoccupazione si applica **solo** se si installano schede telefoniche fisiche PCI/PCI-Express (hardware DAHDI). Tali schede generano un gran numero di interrupt e, sui vecchi sistemi a CPU singola, la condivisione di una linea IRQ con un altro dispositivo potrebbe affamare il driver e degradare la qualità della voce. Se si utilizzano schede telefoniche, dedicare la macchina ad Asterisk, disabilitare qualsiasi dispositivo integrato inutilizzato nel BIOS e controllare gli interrupt assegnati con `cat /proc/interrupts`. I moderni server multi-core che utilizzano interrupt MSI/MSI-X rendono la condivisione IRQ un problema inesistente nella pratica, e una distribuzione puramente VoIP (senza schede) non deve preoccuparsene affatto.

## Scelta della distribuzione Linux

Asterisk è stato inizialmente sviluppato per essere eseguito su Linux. Tuttavia, può funzionare anche su BSD Unix o macOS. Se sei un principiante con Asterisk, prova prima a usare Linux poiché è molto più semplice. Asterisk punta ufficialmente alla famiglia RHEL (CentOS/RHEL/Fedora), Ubuntu e Debian. Buone scelte pratiche oggi sono **Debian 12**, **Ubuntu 22.04 LTS / 24.04 LTS** e **Rocky Linux 9 / AlmaLinux 9** — CentOS Linux è a fine vita, quindi preferisci Rocky o AlmaLinux sui sistemi della famiglia RHEL. Per questo libro userò Ubuntu 24.04 LTS. Scarica l'ultima immagine server point-release 24.04 dalla directory ufficiale delle release qui sotto (il nome file esatto include la point release corrente, ad esempio `ubuntu-24.04.4-live-server-amd64.iso`):

```
https://releases.ubuntu.com/24.04/
```

### Preparazione di Linux per Asterisk

Prima di compilare Asterisk, hai bisogno di un sistema Linux funzionante con i pacchetti di compilazione installati. Installa **Ubuntu 24.04 LTS Server** in una macchina virtuale o su un server dedicato (usa l'immagine a 64-bit; tutto in questo libro è a 64-bit, sebbene Asterisk stesso supporti ancora x86 a 32-bit). Abbiamo usato VirtualBox per questo corso; puoi scaricare l'immagine da <https://releases.ubuntu.com/24.04>. L'installazione di Linux in sé esula dallo scopo di questo libro — una conoscenza di base di Linux è un prerequisito. Con Linux installato, aggiungerai le dipendenze di compilazione di Asterisk (vedi *Installazione delle dipendenze* qui sotto) e poi compilerai Asterisk.

## Installazione di Linux per Asterisk

Installa Linux come di consueto, senza un desktop grafico. Durante l'installazione, abilita anche un mail transfer agent (utilizziamo **exim4**) — Asterisk ne avrà bisogno in seguito in questo libro per inviare le notifiche di voicemail-to-email. **Attenzione:** l'installazione di un sistema operativo cancella il disco di destinazione. Se effettui l'installazione su hardware fisico, esegui prima il backup dei tuoi dati; l'installazione all'interno di una macchina virtuale lascia intatto il tuo host. Avvia il programma di installazione dall'ISO di Ubuntu Server (o dall'unità ottica virtuale della VM) e rispondi alle richieste — la maggior parte di esse è intuitiva.

## Installazione delle dipendenze

Per installare Asterisk e DAHDI è necessario installare numerose dipendenze software. Il metodo consigliato per farlo in Asterisk 22 è utilizzare lo script fornito con l'albero dei sorgenti, che conosce i nomi corretti dei pacchetti per ogni distribuzione supportata. Dopo aver scaricato ed estratto i sorgenti di Asterisk (vedere "Compilazione di Asterisk" di seguito), eseguire:

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. Accedere come root (o utilizzare `sudo`).
2. Se si preferisce installare le dipendenze manualmente su un sistema Debian/Ubuntu, l'elenco dei pacchetti equivalente è:

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

Si noti che i sorgenti di Asterisk sono ora ospitati su Git, quindi `subversion` non è più necessario e le moderne distribuzioni Debian/Ubuntu forniscono `libncurses-dev` anziché la versione `libncurses5-dev`. È preferibile usare `./contrib/scripts/install_prereq install` rispetto a un elenco gestito manualmente, poiché lo script tiene sempre traccia dei nomi corretti dei pacchetti per la propria distribuzione.

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) è l'architettura di driver per schede analogiche e digitali. Prima di installare Asterisk è importante installare DAHDI se si prevede di utilizzare interfacce analogiche o digitali. DAHDI esiste ancora per le schede di telefonia analogica/digitale, ma è sempre più di nicchia: la maggior parte delle implementazioni moderne sono puramente VoIP e possono saltare completamente questa sezione. Installare DAHDI solo se si dispone di hardware di interfaccia telefonica fisica. Ottenere i file sorgente utilizzando:

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

Decomprimere i file utilizzando:

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### Compilazione dei driver DAHDI

Sarà necessario compilare i moduli DAHDI. I comandi ./configure e make menuselect sono stati introdotti diversi anni fa. Quest'ultimo consente di selezionare quali utilità e moduli compilare. I seguenti comandi eseguiranno questa operazione:

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

make install-config DAHDI è stato configurato. Se si dispone di hardware DAHDI, ora si consiglia di modificare /etc/dahdi/modules per caricare il supporto solo per l'hardware DAHDI installato in questo sistema. Per impostazione predefinita, il supporto per tutto l'hardware DAHDI viene caricato all'avvio di DAHDI. Penso che l'hardware DAHDI presente sul sistema sia: usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware Questa schermata (sopra) richiede di modificare il file /etc/dahdi/modules per caricare solo i driver necessari per la propria configurazione specifica e mostrare l'hardware rilevato. Modificare il file /etc/dahdi/modules e caricare solo l'hardware richiesto. Nel mio caso, stavo utilizzando una macchina di test con un Xorcom Astribank 6FXS e 2FXO. Il file è mostrato di seguito.

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

Riavviare il computer e verificare il corretto caricamento dei driver.

## Quale versione scegliere

Come regola generale, dovresti utilizzare la versione che dispone delle funzionalità richieste. Asterisk segue un modello di rilascio che alterna versioni LTS (long-term support) e versioni standard. Al momento di questa edizione, **Asterisk 22 è l'attuale versione LTS** (rilasciata nell'ottobre 2024; l'ultimo point release è 22.10.0), il che la rende la scelta migliore da adottare ora. Asterisk 20 è la precedente LTS, mentre la versione 16 (utilizzata nella prima edizione) è giunta a fine vita. Per i sistemi in produzione, scegli sempre una versione LTS.

## Compilazione di Asterisk

Se hai già compilato del software in precedenza, compilare Asterisk sarà un compito semplice. Esegui i seguenti comandi per compilare e installare Asterisk. Ricorda, puoi scegliere quali applicazioni e moduli compilare usando make menuselect. Passaggio 1: Scarica il codice sorgente

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

Passaggio 2: Installa i prerequisiti di compilazione (vedi "Installazione delle dipendenze" sopra)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

Passaggio 3: Configura la compilazione

```
./configure
```

Passaggio 4: Seleziona i moduli da compilare

```
make menuselect
```

Usa make menuselect per installare solo i moduli necessari. In Asterisk 22 il canale SIP è **chan_pjsip** (compilato per impostazione predefinita); il vecchio **chan_sip** è stato rimosso in Asterisk 21 e non esiste più. Il *pass-through* Opus funziona immediatamente (il modulo `res_format_attr_opus` incluso gestisce la negoziazione SDP), ma il modulo di transcodifica **codec_opus** rimane un binario esterno a codice chiuso di Sangoma/Digium — selezionandolo in menuselect lo si scarica dai server di Digium. Il binario è gratuito. Vedi "Selezione dei moduli con menuselect" di seguito per i dettagli.

Passaggio 5: Compila e installa Asterisk, quindi crea la configurazione predefinita e i file di esempio

```
make
make install
make samples
make config
ldconfig
```

`make install` installa i binari e i moduli, `make samples` scrive i file di configurazione di esempio in `/etc/asterisk`, `make config` installa lo script di avvio SysV init per la tua distribuzione rilevata (ad esempio `/etc/init.d/asterisk` su Debian/Ubuntu), e `ldconfig` aggiorna la cache delle librerie condivise. Un'unità systemd è inclusa anche nell'albero dei sorgenti in `contrib/systemd/asterisk.service`, ma `make config` non la installa automaticamente — copiala manualmente al suo posto se preferisci eseguire Asterisk sotto systemd (vedi sotto).

### Selezione dei moduli con menuselect

`make menuselect` apre un menu basato su testo dove puoi scegliere esattamente quali applicazioni, codec, canali e risorse compilare. Alcune note specifiche per Asterisk 22:

- **chan_pjsip** (sotto *Channel Drivers*) è il moderno canale SIP ed è abilitato per impostazione predefinita; è l'unico canale SIP in Asterisk 22.
- **codec_opus** (sotto *Codec Translators*) è un modulo **esterno** (la sua voce in menuselect recita "Download the Opus codec from Digium"); abilitandolo, `make` scarica il binario gratuito a codice chiuso da Sangoma/Digium. Il pass-through Opus di per sé non necessita di alcun modulo aggiuntivo. È disponibile anche il modulo **codec_g729** di Sangoma — il binario è scaricabile gratuitamente, ma la transcodifica G.729 legale richiede l'acquisto di una licenza per canale.
- Seleziona i formati audio e le lingue desiderate nei menu *Core Sound Packages*, *Music On Hold File Packages* e *Extras Sound Packages*; tutto ciò che selezioni lì viene scaricato e installato automaticamente durante `make install`.

Dopo aver effettuato le tue selezioni, scegli **Save & Exit** e prosegui con `make`.

## Avvio e arresto di Asterisk

Con questa configurazione minima, è possibile avviare Asterisk con successo. Per scopi di apprendimento e debug, è possibile avviare Asterisk in primo piano collegato alla console:

```
/usr/sbin/asterisk -vvvgc
```

Utilizzare il comando CLI `core stop now` per arrestare Asterisk:

```
*CLI> core stop now
```

### Avvio di Asterisk con systemd

Sulle moderne distribuzioni Linux (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9), il gestore dei servizi di sistema è **systemd**. Asterisk fornisce un'unità systemd in `contrib/systemd/asterisk.service` all'interno dell'albero dei sorgenti; copiarla in `/etc/systemd/system/asterisk.service` ed eseguire `systemctl daemon-reload`. Una volta installato, il metodo consigliato per eseguire Asterisk in produzione è tramite `systemctl`:

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

Una volta che Asterisk è in esecuzione come servizio, collegarsi alla sua CLI con `asterisk -r` (connessione) o `asterisk -rvvv` (connessione con output dettagliato).

Sui sistemi più datati, Asterisk veniva avviato tramite il vecchio script init SysV (`/etc/init.d/asterisk`) e il wrapper **safe_asterisk**, che riavviava Asterisk automaticamente in caso di crash. Con systemd, il riavvio automatico è gestito dalla direttiva `Restart=` del file di unità, quindi `safe_asterisk` non è generalmente più necessario. L'approccio legacy init/`safe_asterisk` funziona ancora, ma è deprecato sulle distribuzioni basate su systemd.

### Opzioni di runtime di Asterisk

Il processo di avvio di Asterisk è molto semplice. Se Asterisk viene eseguito senza alcun parametro, viene lanciato come daemon.

```
/sbin/asterisk
```

È possibile accedere alla console di Asterisk eseguendo il seguente comando. Si noti che è possibile eseguire più di un processo di console contemporaneamente.

```
/sbin/asterisk -r
```

### Opzioni di runtime disponibili per Asterisk

È possibile visualizzare le opzioni di runtime disponibili utilizzando `asterisk -h`

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## Directory di installazione

Asterisk viene installato in diverse directory, che possono essere modificate nel file asterisk.conf. A scopo didattico, cambierei il valore di verbose da 3 a 15, mentre per la produzione lo manterrei a 3. Le opzioni `maxcalls` e `maxload` sono buone opzioni per proteggere il sistema da sovraccarichi.

### asterisk.conf (estratto)

La sezione `[directories]` definisce dove Asterisk conserva la sua configurazione, i moduli, i dati, lo spool e i log:

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

La sezione `[options]` contiene le impostazioni di ottimizzazione a runtime. Le opzioni più utili da conoscere sono mostrate di seguito (decommentare per abilitarle); il file viene fornito con molte altre opzioni, ognuna documentata da un commento inline:

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## File di log e rotazione dei log

Asterisk PBX registra i propri messaggi in `/var/log/asterisk`. La registrazione è controllata da `logger.conf`. La parte fondamentale è la sezione `[logfiles]`, dove ogni riga definisce un canale di log e i livelli di messaggio che cattura (estratto):

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

Dopo aver apportato le modifiche, applica il cambiamento con `logger reload` e conferma i canali con `logger show channels`:

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

I file di log possono crescere rapidamente, quindi ruotali con il demone di sistema `logrotate` — aggiungi un file sotto `/etc/logrotate.d/`:

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

Maggiori informazioni su logrotate possono essere ottenute utilizzando:

```
#man logrotate
```

## Disinstallazione di Asterisk

Per disinstallare Asterisk, utilizzare:

```
make uninstall
```

Per disinstallare Asterisk e tutti i file di configurazione, utilizzare:

```
make uninstall-all
```

## Note sull'installazione di Asterisk

Questa sezione fornirà alcuni consigli sulle problematiche da affrontare prima di installare Asterisk.

### Sistemi in produzione

Se Asterisk viene installato in un ambiente di produzione, è necessario prestare attenzione alla progettazione del sistema. Un server deve essere ottimizzato in modo tale che i sistemi di telefonia abbiano la priorità rispetto ad altri processi di sistema. Asterisk non dovrebbe essere eseguito insieme a software che richiedono un uso intensivo del processore, come X-Windows. Se è necessario eseguire processi che richiedono un uso intensivo della CPU (ad esempio, un database di grandi dimensioni), utilizzare un server separato. In linea di massima, Asterisk è suscettibile alle variazioni delle prestazioni hardware. Pertanto, cercare di utilizzare Asterisk in un ambiente hardware che non richieda più del 40% di utilizzo della CPU.

### Suggerimenti di rete

Se si prevede di utilizzare telefoni IP, è importante prestare attenzione alla propria rete. I protocolli vocali sono molto validi e resistenti alla latenza e persino al jitter; tuttavia, se si utilizza una rete locale configurata male, la qualità della voce ne risentirà. È possibile garantire una buona qualità vocale solo utilizzando la quality of service (QoS) in switch e router. La voce in una rete locale tende a essere buona, ma anche in un ambiente LAN, se si dispone di hub da 10 Mbps con troppe collisioni, si finirà per avere una voce distorta o di scarsa qualità. Seguire queste raccomandazioni per garantire la migliore qualità vocale possibile:

- Utilizzare la QoS end-to-end se possibile o economicamente fattibile. Con la QoS end-to-end, la qualità della voce è perfetta. Non ci sono scuse!
- Evitare l'uso di hub 10/100 Mbps per la voce in un ambiente di produzione. Le collisioni possono imporre jitter sulla rete. Sono preferibili switch full duplex 10/100 Mbps poiché non si verificano collisioni.
- Utilizzare le VLAN per separare i broadcast non necessari dalla rete vocale. Non si vuole che un virus distrugga la rete vocale con broadcast ARP.
- Educare gli utenti sulle aspettative in una rete vocale. Senza QoS, non affermare che la voce sarà perfetta, poiché nella maggior parte dei casi non lo sarà. Molto spesso si otterrà una qualità della voce simile a quella di un telefono cellulare. Utilizzare telefoni di qualità, poiché i problemi con il firmware e la progettazione hardware sono comuni.

## Riepilogo

In questo capitolo, hai appreso i requisiti hardware minimi e come scaricare, installare e compilare Asterisk. Asterisk dovrebbe essere eseguito con un utente non root per motivi di sicurezza. Dovresti verificare il tuo ambiente di rete prima di avviare l'ambiente di produzione.

## Quiz

1. In Asterisk 22, quale driver di canale fornisce il supporto SIP e cosa è successo al vecchio `chan_sip`?
   - A. `chan_sip` è ancora il predefinito; `chan_pjsip` è opzionale.
   - B. `chan_pjsip` è il canale SIP predefinito; `chan_sip` è stato rimosso in Asterisk 21 e non esiste più.
   - C. Entrambi vengono compilati per impostazione predefinita e si sceglie tra loro durante l'esecuzione.
   - D. Il supporto SIP è stato rimosso completamente in favore di IAX2.
2. Le schede di interfaccia telefonica per Asterisk solitamente hanno Digital Signal Processor (DSP) integrati e quindi non richiedono molta CPU dal PC.
   - A. Vero
   - B. Falso
3. Se si desidera una qualità vocale perfetta, è necessario implementare una quality of service (QoS) end-to-end.
   - A. Vero
   - B. Falso
4. Si dovrebbe sempre scegliere l'ultima versione di Asterisk, poiché è la più stabile.
   - A. Vero
   - B. Falso
5. Qual è il metodo consigliato per installare le dipendenze di compilazione per Asterisk 22?
6. Se non si dispone di una scheda di interfaccia TDM, si avrà comunque una sorgente di temporizzazione interna per la sincronizzazione, fornita dal modulo `res_timing_timerfd` su Linux. Questa temporizzazione viene utilizzata da applicazioni come ________ e ________.
7. Durante l'installazione di Asterisk è meglio escludere ambienti desktop come GNOME o KDE, poiché le interfacce grafiche consumano cicli di CPU.
   - A. Vero
   - B. Falso
8. I file di configurazione di Asterisk si trovano nella directory ________.
9. Per installare i file di configurazione di esempio di Asterisk, digitare il comando: ________
10. Perché è importante eseguire Asterisk come utente non root?

**Risposte:** 1 — B · 2 — B · 3 — A · 4 — B · 5 — Eseguire `./contrib/scripts/install_prereq install` dall'albero dei sorgenti di Asterisk estratto · 6 — ConfBridge e Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — Sicurezza (limita i danni se Asterisk viene compromesso)
