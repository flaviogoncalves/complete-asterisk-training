# Asterisk Call Detail Records

Asterisk, come altre piattaforme di telefonia, consente la fatturazione delle chiamate telefoniche. Esistono diversi programmi sul mercato in grado di importare i record generati dai PBX. Tali record vengono utilizzati, tra le altre cose, per verificare l'importo corretto della bolletta e per le statistiche.

## Obiettivi

Al termine di questo capitolo, il lettore dovrebbe essere in grado di:

- Descrivere dove e in quale formato vengono generati i record
- Generare record utilizzando ODBC (Open Database Connectivity)
- Implementare uno schema di autenticazione integrato con la fatturazione

## Formato CDR di Asterisk

Asterisk genera un record di dettaglio della chiamata (CDR) per ogni chiamata. Questi record vengono archiviati, per impostazione predefinita, in un file di testo in formato CSV (comma separated value) in /var/log/asterisk/cdr-csv. Il file è organizzato nei seguenti campi:

| Campo | Descrizione | Tipo |
|-------|-------------|------|
| Accountcode | Numero di account da utilizzare | Stringa |
| Src | Numero del Caller ID | Stringa |
| Dst | Extension di destinazione | Stringa |
| Dcontext | Context di destinazione | Stringa |
| Clid | Caller ID con testo | Stringa |
| Channel | Canale utilizzato | Stringa |
| Dstchannel | Canale di destinazione | Stringa |
| Lastapp | Ultima applicazione | Stringa |
| Lastdata | Dati dell'ultima applicazione | Stringa |
| Start | Inizio della chiamata | Data/Ora |
| Answer | Risposta alla chiamata | Data/Ora |
| End | Fine della chiamata | Data/Ora |
| Duration | Tempo, dalla composizione alla chiusura | Intero (secondi) |
| Billsec | Tempo, dalla risposta alla chiusura | Intero (secondi) |
| Disposition | Esito della chiamata (ANSWERED, NO ANSWER, BUSY, FAILED, CONGESTION) | Stringa |
| Amaflags | Flag (DEFAULT, OMIT, BILLING, DOCUMENTATION) | Stringa |
| Userfield | Campo definito dall'utente | Stringa |

Esempio di un file CSV. Ogni riga rappresenta un record; i campi appaiono nello stesso ordine della tabella precedente (`accountcode` per primo, `amaflags` per ultimo):

```text
# accountcode,src,dst,dcontext,clid,channel,dstchannel,lastapp,lastdata,
#   start,answer,end,duration,billsec,disposition,amaflags
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-5f30","PJSIP/8584-9153","Dial","PJSIP/8584,30,tT","2006-03-27 16:05:00","2006-03-27 16:05:00","2006-03-27 16:05:00","0","0","ANSWERED","DOCUMENTATION"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-96f5","PJSIP/8584-3312","Dial","PJSIP/8584,30,tT","2006-03-27 16:16:00","2006-03-27 16:16:00","2006-03-27 16:16:00","0","0","ANSWERED","BILLING"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-74ac","PJSIP/8584-297b","Dial","PJSIP/8584,30,tT","2006-03-27 16:22:00","2006-03-27 16:22:00","2006-03-27 16:22:00","0","0","ANSWERED","BILLING"
"1234","4830258576","2012348584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-2c5d","PJSIP/8584-9870","Dial","PJSIP/8584,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
"1234","4830258584","2012348576","default","""Luis Sample"" <4830258584>","PJSIP/8584-03fd","PJSIP/8576-645c","Dial","PJSIP/8576,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
```

## Codici account e contabilità automatizzata dei messaggi

È possibile specificare codici account e flag ama su ogni canale. Solitamente questa operazione viene eseguita nel file di configurazione del canale (ad esempio, chan_dahdi.conf, pjsip.conf). Il parametro amaflags definisce cosa fare con il record CDR. I possibili valori di amaflag sono:

- Default
- Omit
- Billing
- Documentation

Analogamente al modo in cui un record può essere contrassegnato per la fatturazione (billing) o la documentazione, è possibile impostare un codice account su ogni record. Il codice account è una stringa a formato libero (l'opzione `accountcode` endpoint accetta qualsiasi String, e il record CDR lo memorizza in un campo da 80 caratteri) solitamente utilizzata per assegnare un record a un dipartimento o a un'unità aziendale. Esempio: sezione endpoint di pjsip.conf

```
[8576]
type=endpoint
accountcode=Support
```

Il flag AMA non è un'opzione `pjsip.conf` endpoint in Asterisk 22; impostalo per chiamata dal dialplan con la funzione `CHANNEL` (ad esempio `Set(CHANNEL(amaflags)=billing)`), oppure con `Set(CDR(amaflags)=billing)`.

## Modifica del formato CSV e/o CDR

È possibile modificare il formato CSV cambiando il file cdr_custom.conf.

```
;
; Mappings for custom config file
;
[mappings]
Master.csv =>
"${CDR(clid)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}"
,"${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${C
DR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposit
ion)}","${CDR(amaflags)}","${CDR(accountcode)}","${CDR(uniqueid)}","${CDR(userf
ield)}"
```

È possibile modificare il formato CDR nel file cdr_custom.conf.

## Archiviazione dei CDR

L'archiviazione dei CDR può essere realizzata in diversi modi. Il metodo più importante è quello dei file di testo CSV, che possono essere facilmente importati nei fogli di calcolo. Per le piccole imprese, di solito questo è sufficiente. Alcuni software di fatturazione accettano, per impostazione predefinita, file CSV. Tuttavia, archiviare i CDR in un database è molto meglio e più sicuro. Asterisk supporta diversi tipi di database. Esistono sul mercato alcune interfacce grafiche per la fatturazione. Con così tanti driver, quale scegliere?

### Driver di archiviazione disponibili

- cdr_csv – File di testo con valori separati da virgola
- cdr_custom – File di testo personalizzabili con valori separati da virgola
- cdr_adaptive_odbc – Backend ODBC adattivo (preferito per l'archiviazione su database)
- cdr_odbc – Database supportati da unixODBC (legacy; preferito cdr_adaptive_odbc)
- cdr_pgsql – Database Postgres
- cdr_tds (cdr_freetds) – Database Sybase e MSSQL tramite FreeTDS
- cdr_manager – CDR verso la Manager Interface
- cdr_radius – Interfaccia CDR radius
- cdr_sqlite3_custom – Modulo CDR personalizzato per SQLite3

Il modulo `cdr_addon_mysql` (cdr_mysql) che le guide più datate raccomandavano è stato rimosso in Asterisk 19, quindi non esiste un driver CDR MySQL nativo su Asterisk 22. Per scrivere i CDR su MySQL/MariaDB, utilizzare `cdr_adaptive_odbc` insieme a un driver ODBC per MySQL: l'approccio utilizzato in questo capitolo.

La registrazione dei CDR viene eseguita su tutti i moduli attivi caricati nel file /etc/asterisk/modules.conf. Se il parametro autoload=yes è impostato, tutti i moduli vengono caricati. Per verificare quali cdr_drivers sono attualmente caricati nel sistema, utilizzare il comando seguente:

```
asterisk*CLI> module show like cdr_
Module                 Description                              Use Count  Status
Support Level
cdr_adaptive_odbc.so   Adaptive ODBC CDR backend                0          Running
core
cdr_csv.so             Comma Separated Values CDR Backend       0          Running
extended
cdr_custom.so          Customizable Comma Separated Values CDR  0          Running
core
cdr_manager.so         Asterisk Manager Interface CDR Backend   0          Running
core
cdr_odbc.so            ODBC CDR Backend                         0          Running
extended
cdr_sqlite3_custom.so  SQLite3 Custom CDR Module                0          Not Running
extended
6 modules loaded
```

Se si visualizza lo screenshot sopra, almeno cdr_adaptive_odbc, cdr_csv, cdr_custom, cdr_manager, cdr_odbc e cdr_sqlite3_custom sono in esecuzione. Negli ultimi anni, dopo alcuni astricon, mi è apparso chiaro che il team di Asterisk stesse privilegiando ODBC. È l'unico driver che supporta il connection pooling. Il connection pooling rappresenta un grande vantaggio in termini di prestazioni, poiché non è necessario aprire una nuova connessione per ogni operazione. Questo capitolo era stato scritto in precedenza utilizzando cdr_mysql. Per questa edizione sono passato a cdr_adaptive_odbc, pur sapendo che è un po' più complesso da configurare. La scelta di cdr_adaptive_odbc ci consente inoltre di personalizzare il CDR. È possibile impostare semplicemente una nuova variabile CDR nel dialplan e aggiungere la colonna corrispondente al database. Ad esempio, per registrare il jitter audio:

```
Set(CDR(jitter)=${RTPAUDIOQOSJITTER})
```

### Archiviazione CSV

Come abbiamo detto in precedenza, per impostazione predefinita, Asterisk invia tutti i CDR a un file di testo CSV utilizzando il modulo cdr_csv.so. Se non è possibile visualizzare i file in /var/log/asterisk/cdr-csv, verificare se il modulo viene caricato utilizzando il comando CLI module show. Se non è caricato, controllare modules.conf. In questo capitolo invieremo i CDR a cdr_csv come backup.

### Configurazione del file modules.conf

Per caricare solo i moduli appropriati, utilizzare le righe seguenti nel file modules.conf

```
noload => cdr_custom.so
noload => cdr_odbc.so
noload => cdr_manager.so
noload => cdr_sqlite3_custom.so
```

Ora abbiamo caricato solo cdr_csv e cdr_adaptive_odbc.

## Installazione e configurazione di ODBC su Ubuntu 22.04

Mi pento sempre di pubblicare istruzioni dettagliate nel libro. A volte cambiano prima ancora che il libro venga pubblicato. Le versioni cambiano, i moduli cambiano, quindi cerca di adattare i comandi qui presenti alla tua situazione specifica. Il più delle volte, piccole modifiche sono sufficienti per riprodurre l'installazione. Presta attenzione ai passaggi: anche gli utenti Linux esperti troveranno difficile installare i driver ODBC.

Passaggio 1 - Installare i pacchetti richiesti:

```
apt-get install mysql-server unixodbc unixodbc-dev libltdl-dev libtool
```

Passaggio 2 - Creare un database e un utente:

```
mysql -u root -p
```

(Usa la password definita quando hai creato il server mysql) Digita questi comandi nella riga di comando di mysql

```
CREATE USER 'astdb'@'%' IDENTIFIED BY 'supersecret';
CREATE DATABASE cdr;
GRANT ALL PRIVILEGES ON cdr.* TO 'astdb'@'%';
FLUSH PRIVILEGES;
EXIT
```

Passaggio 3 - Creare il database

```
cd /usr/src/asterisk-22.*/contrib/scripts/realtime/mysql
mysql -u root -p astdb <mysql_cdr.sql
```

Passaggio 4: Scaricare il connettore ODBC di MySQL da Oracle. Controlla il tuo sistema operativo usando: `lsb_release -a`. Per Ubuntu 22.04 (x86_64), visita https://dev.mysql.com/downloads/connector/odbc/ e scegli l'attuale release 8.x o 9.x per Ubuntu 22.04. Il nome esatto del file e il numero di versione cambiano nel tempo, quindi imposta `VER` (sotto) su come viene chiamata l'attuale build glibc per Linux.

```
cd /usr/src
# Pick the current Linux (glibc) build for your platform from
# https://dev.mysql.com/downloads/connector/odbc/ and set VER to its name:
VER=mysql-connector-odbc-9.0.0-linux-glibc2.28-x86-64bit
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/9.0/$VER.tar.gz
tar -xzvf $VER.tar.gz
```

Passaggio 5: Installare il driver ODBC

```
cd /usr/src/$VER
cp bin/* /usr/local/bin
cp lib/* /usr/local/lib
myodbc-installer -a -d -n "MySQL" -t "Driver=/usr/local/lib/libmyodbc9w.so"
```

Passaggio 6 - Configurare il connettore ODBC modificando il file /etc/odbc.ini per creare il DSN (Data Source Name)

```
[astconn]
Description = MySQL connector for astdb database
Driver = /usr/local/lib/libmyodbc9w.so
Database = astdb
Server = localhost
Port = 3306
```

Passaggio 7: Testare l'accesso al driver usando iSQL. iSQL è un'utilità da riga di comando per connettersi al database tramite unixodbc.

```
isql -v astconn astdb supersecret
>show tables
```

Per favore, non procedere con la configurazione di Asterisk se non riesci a vedere il risultato del comando isql.

### Configurazione di ODBC in Asterisk

Prima di poter configurare cdr_adaptive_odbc, dovresti prima configurare il file delle risorse ODBC.

Passaggio 1 - Connettere Asterisk a ODBC. Modifica il file res_odbc.conf:

```
[cdr]
enabled => yes
dsn => astconn
username => astdb
password => supersecret
pre-connect => yes
```

Passaggio 2 – Riavviare Asterisk ed eseguire il test usando

```
asterisk*CLI> odbc show
```

L'output è mostrato di seguito.

```
asterisk*CLI> odbc show
ODBC DSN Settings
-----------------
Name:   cdr
DSN:    astconn
  Number of active connections: 1 (out of 20)
```

Passaggio 3 – Configurare il driver ODBC adattivo in /etc/asterisk/cdr_adaptive_odbc.conf

```
[cdr]
connection=cdr
table=cdr
```

Qui `connection` punta alla sezione di connessione `[cdr]` definita in `res_odbc.conf`, e `table` è la tabella del database dove vengono scritti i CDR.

Passaggio 4 – Ricaricare il modulo cdr_adaptive_odbc.so:

```
asterisk*CLI> reload cdr_adaptive_odbc
```

Passaggio 5 – Effettuare alcune chiamate e controllare il database per nuovi record. Per controllare il database:

```
mysql -u root -p
>use astdb
>select * from cdr;
```

## Applicazioni e funzioni

Diverse applicazioni sono correlate alla fatturazione.

### CDR(accountcode)

Imposta un codice account prima di chiamare un'altra applicazione dial(); per esempio: Formato:

```
Set(CDR(accountcode)=account)
```

Il codice account può essere verificato utilizzando la variabile di canale ${CDR(accountcode)}

### CDR(amaflags)

Imposta un flag per scopi di fatturazione. Le opzioni sono default, omit, documentation e billing.

```
Set(CDR(amaflags)=amaflags)
```

### Set(CDR_PROP(disable)=1)

Disabilita la registrazione dei CDR per il canale corrente, in modo che nessun CDR venga scritto nel file o nel database. Impostarlo nuovamente su `0` riabilita la registrazione.

```
Set(CDR_PROP(disable)=1)
```

L'applicazione `NoCDR()` che le edizioni precedenti utilizzavano per questo scopo è stata rimossa in Asterisk 21; su Asterisk 22 si disabilita il CDR di un canale utilizzando invece `Set(CDR_PROP(disable)=1)`.

### ResetCDR()

Reimposta il Call Data Record: l'ora di `start` (e, se ha risposto, l'ora di `answer`) viene impostata all'ora corrente e tutte le variabili CDR vengono cancellate. Se l'opzione `v` è impostata, le variabili CDR vengono preservate durante il ripristino.

### Set(CDR(userfield)=Value)

Questo comando imposta un campo utente nel CDR. Quando si utilizza `cdr_adaptive_odbc`, il campo utente viene memorizzato automaticamente se esiste una colonna `userfield` nella tabella CDR — non è necessaria alcuna ricompilazione del sorgente. Per i file di testo CSV, è necessario modificare il codice sorgente (cdr_csv.c) e ricompilare Asterisk se si desidera utilizzare i campi utente.

Le edizioni precedenti memorizzavano i CDR in MySQL con il modulo `cdr_addon_mysql` (`cdr_mysql.conf`). Quel modulo è stato rimosso in Asterisk 19, quindi non è disponibile su Asterisk 22. Il percorso supportato ora è `cdr_adaptive_odbc` con un driver ODBC MySQL, che memorizza il campo utente — e qualsiasi altra colonna personalizzata — nativamente tramite la sua mappatura adattiva delle colonne.

### Accodamento al campo utente

Le edizioni precedenti utilizzavano l'applicazione `AppendCDRUserField()` per aggiungere dati al campo utente del CDR. Quell'applicazione è stata rimossa da Asterisk; su Asterisk 22 si aggiungono dati al campo utente leggendolo e reimpostandolo con la funzione `CDR`, per esempio `Set(CDR(userfield)=${CDR(userfield)}extra)`.

![13-call-detail-records figura 1](../images/13-call-detail-records-img01.png)

## Autenticazione utente

Alcune aziende addebitano le chiamate ai propri dipendenti. In Asterisk è possibile impostare uno schema di autenticazione che consente di addebitare l'utente autenticato nel CDR. Questa autenticazione può essere effettuata utilizzando una password passata come parametro all'applicazione Authenticate: un file di password, indicato da una / (barra) prima del parametro, o una chiave del database Asterisk (utilizzando l'opzione `d`). Formato:

```
Authenticate(password[,options[,maxdigits[,prompt]]])
Authenticate(/passwdfile[,options])
```

Opzioni:

- a – Imposta l'account code del canale sulla password inserita.
- d – Interpreta il percorso fornito come una chiave del database Asterisk anziché come un file letterale.
- m – Interpreta il percorso come un file di righe `accountcode:passwordhash`.
- r – Rimuove la chiave del database dopo un'autenticazione riuscita (valido solo con `d`).

Se il chiamante fallisce tutti e tre i tentativi, il canale viene terminato; l'esecuzione del dialplan non prosegue, quindi gestisci il percorso di errore nella riga successiva a `Authenticate()`. Esempio (Chiamate internazionali):

```
exten=_9011.,1,Authenticate(/password,d)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

La vecchia opzione `j` (salto alla priorità n+101 in caso di errore) e la convenzione di priorità `+101` sono state rimosse da Asterisk molto tempo fa; un fallimento di `Authenticate()` comporta semplicemente la terminazione della chiamata.

Per inserire la password in una chiave del database dalla console:

```
asterisk*CLI> database put senha 123456 1
```

## Utilizzo delle password dalla voicemail

Questa applicazione esegue la stessa funzione di authenticate, ma utilizza il file di configurazione della voicemail per la password.

```
VMAuthenticate([mailbox][@context][,options])
```

Se viene specificata una mailbox, solo la password di quella mailbox sarà considerata valida. Se la mailbox non viene specificata, la variabile di canale `${AUTH_MAILBOX}` verrà impostata con la mailbox autenticata. Se l'opzione `s` è impostata, i prompt iniziali vengono saltati. Esempio (Chiamate Internazionali):

```
exten=_9011.,1,VMAuthenticate(${CALLERID(num)}@local,s)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

## Channel Event Logging (CEL)

I record CDR forniscono una riga di riepilogo per ogni chiamata. Per un tracciamento degli eventi più dettagliato — come le transizioni di stato dei singoli canali, gli eventi di ingresso/uscita dai bridge e le fasi di trasferimento assistito — Asterisk 22 include **Channel Event Logging (CEL)**, configurato tramite `/etc/asterisk/cel.conf` e archiviato attraverso backend come `cel_odbc` o `cel_custom`.

CEL integra CDR anziché sostituirlo: CDR rimane lo standard per i riepiloghi di fatturazione, mentre CEL fornisce dati granulari per singolo evento, utili per il rilevamento delle frodi, il monitoraggio della qualità e la reportistica avanzata.

Il pattern di configurazione `cel.conf` rispecchia `cdr.conf`: si abilitano i tipi di evento desiderati nella sezione `[general]` di `cel.conf`, quindi si configura ogni backend di archiviazione nel proprio file — `cel_custom.conf` per CSV, `cel_odbc.conf` per un database ODBC (la stessa connessione `res_odbc.conf` utilizzata per i CDR). È possibile verificare se CEL è attivo con `cel show status` sulla CLI.

## Riepilogo

In questo capitolo abbiamo imparato come implementare la registrazione dei CDR in file di testo e in un database MySQL. Abbiamo inoltre imparato come impostare gli amaflags e gli account code. Alla fine del capitolo, abbiamo imparato come utilizzare uno schema di autenticazione integrato con i CDR e la fatturazione.

## Quiz

1. Per impostazione predefinita, Asterisk registra i CDR nella directory /var/log/asterisk/cdr-csv.
   - A. Falso
   - B. Vero
2. Asterisk può scrivere i CDR su (seleziona tutte le opzioni applicabili):
   - A. MySQL
   - B. Native Oracle
   - C. Microsoft SQL Server
   - D. File di testo CSV
   - E. Database supportati da unixODBC
3. Asterisk genera un CDR per un solo tipo di archiviazione alla volta.
   - A. Falso
   - B. Vero
4. Quali amaflags di Asterisk sono disponibili?
   - A. DEFAULT
   - B. OMIT
   - C. TAX
   - D. RATE
   - E. BILLING
   - F. DOCUMENTATION
5. Per associare un dipartimento a un CDR si utilizza il comando ___, e l'account code può essere letto con la variabile di canale ___.
6. La differenza tra `Set(CDR_PROP(disable)=1)` e `ResetCDR()` è che disabilitare il CDR impedisce la scrittura di qualsiasi record, mentre `ResetCDR()` azzera (imposta a zero) il record corrente. (L'applicazione `NoCDR()` che in precedenza disabilitava i CDR è stata rimossa in Asterisk 21.)
   - A. Falso
   - B. Vero
7. Per utilizzare un campo definito dall'utente con il modulo `cdr_csv.so`, è necessario modificare il codice sorgente e ricompilare Asterisk.
   - A. Falso
   - B. Vero
8. I tre metodi di autenticazione disponibili per l'applicazione Authenticate() sono:
   - A. Password
   - B. Password file
   - C. Asterisk DB (dbput e dbget)
   - D. Voicemail
9. Le password della voicemail sono specificate in una sezione separata di `voicemail.conf` e non sono le stesse degli utenti della voicemail.
   - A. Falso
   - B. Vero
10. Il Channel Event Logging (CEL) sostituisce il CDR in Asterisk 22: una volta abilitato il CEL, i riepiloghi di fatturazione CDR non vengono più prodotti.
    - A. Falso
    - B. Vero

**Risposte:** 1 — B · 2 — A, B, C, D, E · 3 — A · 4 — A, B, E, F · 5 — `Set(CDR(accountcode)=...)`; `${CDR(accountcode)}` · 6 — B · 7 — A · 8 — A, B, C · 9 — B · 10 — A
