# Sicurezza di Asterisk

Sin dall'inizio, la questione della sicurezza per Asterisk è critica. SIP, Session Initiation Protocol, è il protocollo più attaccato su Internet secondo il CERT.BR. Chiunque gestisca un honeypot può confermarlo. Il problema delle frodi sulla condivisione dei ricavi su Internet (Internet Revenue Share Fraud) è molto serio e può portare a perdite superiori a centinaia di migliaia di dollari. Non si dovrebbe mai installare un server Asterisk connesso a Internet senza un'adeguata sicurezza. In questo capitolo, imparerai a identificare i principali tipi di attacchi che puoi ricevere e come prevenirli utilizzando una corretta politica di sicurezza. Ultimo, ma non meno importante, imparerai come implementare la politica di sicurezza suggerita.

Questo capitolo si rivolge ad **Asterisk 22 LTS**, dove PJSIP (`res_pjsip` / `chan_pjsip`) è l'unico canale SIP. (Il vecchio driver `chan_sip` è stato rimosso in Asterisk 21 — consulta il capitolo *Legacy Channels* se stai migrando un sistema più vecchio.) Una conseguenza rilevante per la sicurezza: le autenticazioni fallite vengono ora emesse attraverso il **security event framework** di Asterisk e il canale di log dedicato `security`, il che cambia il modo in cui viene configurato Fail2Ban (trattato più avanti in questo capitolo).

## Obiettivi

Al termine di questo capitolo sarai in grado di:

- Identificare le principali tipologie di attacchi effettuati frequentemente ai server Asterisk
- Definire una politica di sicurezza efficace
- Implementare la politica di sicurezza
- Installare e configurare IPTABLES per Asterisk
- Installare e configurare Fail2Ban per Asterisk
- Installare e configurare TLS e SRTP per la cifratura

## Principali attacchi alla telefonia IP

I principali attacchi alla telefonia IP possono essere classificati come DOS/DDOS, furto di servizio/frode telefonica (Toll Fraud) e intercettazione (Eavesdropping). Alcuni nomi possono creare confusione e diverse fonti a volte usano nomi differenti per lo stesso attacco. Furto di servizio, Toll Fraud, frode sulla condivisione dei ricavi Internet e frode telefonica sono nomi diversi per indicare hacker che utilizzano il tuo PBX per inviare traffico verso un numero a tariffazione maggiorata (Premium Rate Number) e ottenere rimborsi dal provider.

### DDoS/DOS

Denial of Service e Distributed Denial of Service sono attacchi popolari verso qualsiasi infrastruttura IT. Non è diverso con SIP e altri protocolli Voice over IP. Il Distributed denial of service è solitamente perpetrato da una botnet, mentre il DOS da un singolo computer. Nel febbraio 2011, la botnet Sality ha effettuato una scansione furtiva e coordinata dell'intero spazio di indirizzi IPv4 alla ricerca di server SIP vulnerabili; i ricercatori che osservavano il Network Telescope dell'UCSD l'hanno attribuita a circa tre milioni di IP sorgente distinti che sondavano la porta UDP 5060, molto probabilmente per tentare attacchi brute-force sugli account SIP per frodi telefoniche.[^sality]

[^sality]: A. Dainotti et al., "Analysis of a '/0' Stealth Scan from a Botnet," *IEEE/ACM Transactions on Networking*, 2015 (DOI 10.1109/TNET.2013.2297678).

![Una botnet peer-to-peer che dirige migliaia di tentativi di registrazione SIP verso un server](../images/19-security-fig01.png)

Il DOS viene solitamente applicato tramite tecniche come fuzzing e flooding. Il flooding può utilizzare SIP, IAX, RTP e altri protocolli. Possono interrompere completamente il servizio o degradare la qualità della voce. Sono molto difficili da mitigare se le porte sono aperte verso Internet. Di seguito sono riportati alcuni degli strumenti utilizzati dagli attaccanti

**Fuzzing:**

- **PROTOS Test Suite (c07-sip)** — dall'Università di Oulu OUSPG. Invia migliaia di pacchetti malformati per provocare un malfunzionamento, come un buffer overflow, che arresta il software.
- **Voiper** — genera più di 200.000 test coprendo tutti gli attributi SIP e verifica se il server è in grado di elaborare i messaggi in modo efficace. <http://voiper.sourceforge.net/>

**Flooding:**

- **INVITE Flooder** — inonda il server con richieste SIP INVITE. <http://www.hackingvoip.com/tools/inviteflood.tar.gz>
- **IAX Flooder** — inonda il server con traffico IAX2. <http://www.hackingvoip.com/tools/iaxflood.tar.gz>
- **RTP Flooder** — inonda le sessioni multimediali attive con pacchetti RTP per degradare la qualità della voce. <http://www.hackingvoip.com/tools/rtpflood.tar.gz>

### Tecniche di mitigazione per DoS/DDoS

Le mie raccomandazioni sono:

1. Non esporre il tuo server Asterisk su Internet, a meno che non sia necessario e con una protezione adeguata (SBC)
2. Nella rete interna, utilizza una Virtual LAN per la voce, soprattutto se ti trovi in un'università o un college dove il numero di utenti è elevato.
3. Utilizza VPN o TLS per l'accesso esterno.

### Frode sulla condivisione dei ricavi Internet (Internet Revenue Share Fraud)

Questa frode è un po' complicata da comprendere. La chiave è capire il concetto di numero internazionale a tariffazione maggiorata (IPRN).

![Le tre fasi della frode sulla condivisione dei ricavi Internet: acquistare un numero a tariffazione maggiorata, trovare un dispositivo VoIP vulnerabile e chiamare il numero, quindi incassare il pagamento](../images/19-security-fig02.png)

Un IPRN è un numero che puoi assegnare gratuitamente presso alcune specifiche compagnie telefoniche internet. Cerca i provider di Internet Premium Rate Number e ne troverai un gran numero. Con questo tipo di operatore puoi assegnare, ad esempio, un numero in una rete satellitare come Iridium, una destinazione che costa decine di dollari al minuto per chi chiama. Il provider IPRN ti restituirà una percentuale dei ricavi (dal 10 al 20% del reddito) per ogni minuto ricevuto.

![Un listino prezzi di un provider IPRN che mostra le percentuali di pagamento per paese e i numeri di test](../images/19-security-fig03.png)

Dopo la fase di assegnazione, l'hacker cerca qualsiasi server Asterisk aperto in grado di comporre l'IPRN assegnato. Il PBX della vittima, controllato dall'hacker, effettuerà centinaia di chiamate verso il numero IPRN generando un grande ritorno economico per l'hacker e un'enorme bolletta telefonica per la vittima. Molte volte, superiore a centinaia di migliaia di dollari in un solo fine settimana.

Principali strumenti utilizzati dagli hacker per attaccare un PBX:

1. **SIPVicious**: http://code.google.com/p/sipvicious/. Sipvicious è un set di strumenti di sicurezza facile da usare. Il suo obiettivo principale è riconoscere i PBX vulnerabili e craccare le password SIP utilizzando un attacco brute force. Lo strumento più utilizzato è svcrack. Lo strumento è in grado di testare migliaia di password al secondo.
2. **Vulnerabilità dei telefoni**. Un altro punto frequentemente utilizzato dagli hacker come vettore di attacco è il telefono stesso. Molte persone che installano Asterisk non cambiano la password predefinita nell'interfaccia web del telefono. Una volta che questi telefoni sono aperti su Internet, gli hacker possono provare a utilizzare la password dell'interfaccia predefinita per scaricare la configurazione, dove spesso possono trovare la password SIP segreta.

#### TFTPTheft:

Se utilizzi il provisioning automatico dei telefoni tramite TFTP, probabilmente sei esposto a questo tipo di attacco. TFTP è una forma semplice e insicura di File Transfer Protocol.

![Un attaccante che scarica file .cfg facilmente intuibili da un server TFTP, raccogliendo credenziali in chiaro dai file di configurazione](../images/19-security-fig04.png)

Il nome dei file di configurazione è facilmente intuibile utilizzando l'indirizzo MAC seguito da .cfg (es. 001A2B3C4D5E.cfg). Un hacker esperto può facilmente creare un'utilità per provare tutti gli indirizzi MAC in sequenza o semplicemente scaricare uno strumento per farlo. Il file di configurazione solitamente non è crittografato e contiene al suo interno la password SIP segreta.

#### Mitigazione per attacchi brute force e TFTPTheft

Per mitigare questi attacchi puoi applicare le soluzioni seguenti. Brute force: la soluzione migliore per mitigare gli attacchi brute force è prevenire tentativi non autorizzati sequenziali. Quasi tutti gli installatori di Asterisk utilizzano l'utilità fail2ban per questo scopo. Quando fail2ban rileva tentativi multipli con password o nome utente errati, bandisce l'IP dell'attaccante per un certo periodo di tempo. La seconda misura contro il brute force è utilizzare password forti, di oltre 12 caratteri, con almeno un carattere speciale. TFTPTheft: per prevenire il TFTPTheft, configura il provisioning per utilizzare https con nome utente e password. Il file viene trasmesso crittografato e un nome utente e una password impediscono agli attaccanti di tentare il download di qualsiasi file.

### Intercettazione (Eavesdropping)

Non vediamo molti di questi tipi di attacco perché nella maggior parte dei casi semplicemente non vengono rilevati. L'intercettazione è molto difficile da rilevare in un ambiente IP. Utilità come UCsniff, disponibili gratuitamente, sono in grado di intercettare una chiamata VoIP nella maggior parte delle reti. La tecnica principale consiste nell'utilizzare l'ARP spoofing per forzare il traffico attraverso il computer che esegue UCsniff e registrare le chiamate.

#### Mitigazione per l'intercettazione

Puoi prevenire l'intercettazione crittografando il tuo traffico VoIP. L'altro modo è prevenire attacchi man-in-the-middle (MITM) sulla tua rete. L'ARP inspection è molto efficace per prevenire MITM nelle reti di livello 2. Verifica con il supporto tecnico di rete come implementarla. Più avanti in questo libro impareremo come installare la crittografia basata su TLS e SRTP. Puoi anche utilizzare ARPWatch per scoprire se qualcuno sta abusando del protocollo ARP per attaccare la tua rete.

## Politica di sicurezza per Asterisk

Il modo migliore per implementare la sicurezza è creare una politica di sicurezza. Per questo corso suggerirò una politica di sicurezza adatta alla maggior parte delle installazioni Asterisk. Usala come punto di partenza di base e modificala in base alle tue esigenze. La politica di sicurezza suggerita è riportata di seguito:

1. Nessuna porta UDP/TCP non necessaria aperta
2. Nessun accesso ad alcuna interfaccia amministrativa (SSH/HTTPS) aperto su Internet.
3. Per accedere a SSH e/o HTTP/HTTPS dovrebbero esserci eccezioni esplicite nel firewall IPTABLES
4. Password complesse con 12 caratteri e almeno un carattere speciale
5. Bloccare gli indirizzi IP che falliscono più di 10 volte l'autenticazione utilizzando Fail2ban
6. Conferma della password per le chiamate internazionali
7. Limitare l'accesso alla porta SIP al tuo intervallo noto di indirizzi IP

Se hai bisogno di avere un accesso esterno al tuo PBX, ci sono due possibilità. Usa un SBC (Session Border Controller) per proteggere il tuo server da DOS/DDOS o usa una VPN ogni volta che desideri un accesso esterno. Se lasci la porta 5060 aperta su Internet senza un SBC o una VPN, sei esposto a un attacco DOS/DDOS. Il rischio è tuo.

### Hardening nell'era PJSIP (Asterisk 22)

Oltre al firewall e a Fail2Ban, lo stack PJSIP di Asterisk 22 fornisce diversi controlli a livello di configurazione che dovrebbero far parte della tua politica di sicurezza. Questi completano (non sostituiscono) i controlli di rete sopra indicati:

- **Autenticazione per-endpoint.** Ogni endpoint dovrebbe fare riferimento a una sezione dedicata `type=auth` con una `password` forte e univoca (`auth_type=digest`). Non riutilizzare mai le credenziali tra gli endpoint.
- **Gestione anonima integrata.** PJSIP non rivela se un nome utente esiste quando l'autenticazione fallisce. Per accettare chiamate anonime, devi creare esplicitamente un endpoint chiamato `anonymous` e utilizzare sezioni `type=identify` (corrispondenti all'IP di origine) per mappare i peer noti agli endpoint. Se non desideri chiamate anonime, non creare semplicemente un endpoint `anonymous` e le richieste non corrispondenti verranno sfidate/rifiutate.
- **ACL.** Limita chi può raggiungere un endpoint con ACL denominate `/etc/asterisk/acl.conf`, a cui si fa riferimento dall'endpoint con `acl=` (ACL di segnalazione/origine) e `contact_acl=` (limita l'indirizzo di contatto/registrazione). Puoi anche impostare permit/deny direttamente sull'endpoint.
- **`qualify`.** Imposta `qualify_frequency` (e `qualify_timeout`) sull'AOR in modo che Asterisk monitori attivamente la raggiungibilità dei contatti registrati ed elimini quelli non più attivi.
- **Hardening del trasporto PJSIP / Protezione DoS.** Il `type=transport` non espone un limite di client per trasporto, quindi la protezione contro il connection-flood deriva dal firewall (le regole iptables/Fail2Ban in questo capitolo) piuttosto che da un'opzione PJSIP. Ciò che il trasporto *offre* è la regolazione del TCP keep-alive (`tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`) per eliminare le connessioni morte/semi-aperte, e le impostazioni `local_net`/`external_*` per una corretta gestione del NAT. Combina queste con le regole del firewall per contrastare gli attacchi di connection-flood.
- **TLS + SRTP per i media.** Cripta la segnalazione con un trasporto TLS e i media con `media_encryption=sdes` (o `dtls` per WebRTC) sull'endpoint — trattato più avanti in questo capitolo.
- **Controllo accessi AMI/ARI.** Limita l'Asterisk Manager Interface (`manager.conf`) e l'ARI (`ari.conf` / `http.conf`) a localhost o a una rete di gestione fidata, usa segreti univoci forti, associa il server HTTP a un'interfaccia privata e non esporli mai a Internet.

Tutti i nomi delle opzioni sopra indicati sono confermati per Asterisk 22.10: la sezione `type=transport` espone `tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`, `tos`, `cos`, `local_net` e la famiglia `external_*`, ma **non** ha alcuna opzione `max_clients` — la protezione contro il connection-flood deriva dal firewall, non dal trasporto. Le opzioni dell'endpoint `acl` e `contact_acl` prendono i nomi delle sezioni da `acl.conf`, e la corrispondenza dell'IP di origine per i peer non autenticati viene eseguita con sezioni `type=identify` (`match=`).

### Rimozione delle porte non necessarie

Invece di scoprire tutte le vulnerabilità associate a tutti i protocolli Asterisk, semplifichiamo il problema rimuovendo le porte non necessarie. Per elencare tutte le porte aperte dal server Asterisk usa:

```
netstat -pantu |grep asterisk
```

L'output del comando è mostrato di seguito.

![output di netstat che mostra le numerose porte associate ad Asterisk, incluse 4569 (IAX) e 2727 (MGCP)](../images/19-security-fig05.png)

Se guardi l'output, scoprirai che molte porte sono aperte. Ne abbiamo bisogno? Non necessariamente, 2727 è il protocollo MGCP (chan_mgcp), 4569 è l'IAX (chan_iax2). Se non stai utilizzando questi protocolli, puoi semplicemente rimuovere il modulo nel file di configurazione modules.conf.

Potresti notare che Asterisk associa una porta UDP con numero elevato. Questo deriva dal resolver di `res_pjsip` che effettua query DNS in uscita (la porta di origine è effimera, come qualsiasi ricerca DNS client), non da un listener in entrata — il tuo firewall deve solo consentire il traffico di ritorno **established/related** per essa (la regola iptables `conntrack ESTABLISHED,RELATED` mostrata di seguito copre già questo aspetto). **Non** è necessario aprire un ampio intervallo UDP in entrata solo per il DNS di PJSIP.

Per rimuovere le porte non necessarie, disabilita i moduli che non utilizzi. Modifica il file modules.conf e aggiungi le linee `noload` per i canali e i protocolli che non stai utilizzando. **Non** eseguire noload su `res_pjsip`, `res_pjproject` o `chan_pjsip` — sono necessari per SIP in Asterisk 22:

```
; res_pjsip / res_pjproject / chan_pjsip are REQUIRED in Asterisk 22 - keep them loaded
noload => chan_iax2.so
noload => chan_unistim.so
```

(In Asterisk 22 non è più necessario eseguire noload su `chan_mgcp` o `chan_skinny` — quei driver sono stati *rimossi* in Asterisk 21 e non fanno parte di una build standard 22.) Con le istruzioni sopra, ho rimosso tutti i canali non necessari mantenendo solo PJSIP. Puoi scegliere i moduli di protocollo che desideri, basta rimuovere quelli inutilizzati. Il risultato è mostrato nello screenshot qui sotto — solo la porta SIP (5060) associata al tuo trasporto PJSIP è ora esposta in entrata.

![output di netstat dopo aver disabilitato i moduli inutilizzati: solo la porta UDP 5060 rimane associata ad Asterisk](../images/19-security-fig06.png)

### Implementazione della politica di sicurezza con IPTABLES

IPTABLES o netfilter è un firewall standard presente nella maggior parte delle distribuzioni Linux. In questo laboratorio configureremo iptables e fail2ban. L'obiettivo è implementare la politica di sicurezza raccomandata per Asterisk e bloccare tutto il traffico non necessario. Segui i passaggi seguenti:

1. Blocca tutto il traffico esterno
2. Consenti il traffico SSH da una rete interna o da un singolo host
3. Consenti il traffico SIP in UDP e TCP sulle porte 5060
4. Consenti il traffico RTP nell'intervallo di porte media UDP. Non esiste un valore predefinito integrato unico — il `rtp.conf` di Asterisk ripiega sulle porte 5000–31000 quando non è impostato nulla, ma il file `rtp.conf.sample` fornito configura `rtpstart=10000` / `rtpend=20000`, quindi usiamo quell'intervallo di esempio qui. Fai corrispondere la tua regola firewall a qualsiasi `rtpstart`/`rtpend` tu abbia effettivamente impostato in `rtp.conf`.

Assicurati di avere accesso alla console del server, non vorrai bloccarti fuori dal sistema. Fai attenzione.

1. Installa il pacchetto net-persistent.

   ```
   sudo apt-get install iptables-persistent
   ```

2. Consenti tutto il traffico dal loopback

   ```
   sudo iptables -I INPUT -i lo -j ACCEPT
   sudo iptables -I OUTPUT -o lo -j ACCEPT
   ```

3. Consenti le connessioni stabilite

   ```
   sudo iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   ```

4. Consenti il traffico SSH/HTTPS dalla rete 192.168.0.0

   ```
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 443 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   ```

5. Inserisci le regole di Asterisk

   ```
   sudo iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5061 -j ACCEPT
   sudo iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
   ```

   Nota che la porta 5061 (SIP su TLS) è **TCP**, non UDP. Le regole sopra aprono la 5060 sia su UDP che su TCP e la 5061 su TCP. Se esegui solo TLS, puoi eliminare completamente le regole 5060 semplici. Apri solo le porte a cui i tuoi trasporti PJSIP si associano effettivamente.

   `-I` significa PREPEND (inserimento all'inizio)

6. L'ultima regola deve essere un drop

   ```
   sudo iptables -A INPUT -j DROP
   ```

   `-A` significa APPEND (aggiunta in fondo). Nota: Fai attenzione quando mantieni nuove regole, devi aggiungere le regole prima del DROP. Usa PREPEND per le nuove regole `-I`

7. Salva le regole e riavvia iptables

   ```
   sudo iptables-save >/etc/iptables/rules.v4
   sudo /etc/init.d/netfilter-persistent restart
   ```

### Utilizzo di Fail2Ban per bloccare tentativi multipli di autenticazione falliti

Fail2Ban è quasi uno standard per Asterisk. La maggior parte degli utenti lo implementa per migliorare la sicurezza. Questa utility scansiona i log di Asterisk alla ricerca di tentativi falliti e blocca gli indirizzi IP degli aggressori. Di seguito fornisco le istruzioni per installare Fail2Ban.

In Asterisk 22, PJSIP segnala le autenticazioni fallite e altri eventi di sicurezza attraverso il **framework degli eventi di sicurezza** di Asterisk, scritto nel canale di log dedicato **`security`**. Per far funzionare Fail2Ban devi:

1. Abilitare il canale di sicurezza in `/etc/asterisk/logger.conf`. La sintassi è `<filename> => <levels>`, quindi per inviare il livello di sicurezza a un file chiamato `security` scrivi:

```
[logfiles]
security => security
```

quindi esegui `logger reload` dalla CLI. Questo produce `/var/log/asterisk/security` con una riga per evento di sicurezza, nella forma:

```
[2026-01-15 10:23:45] SECURITY[1234] res_security_log.c: SecurityEvent="InvalidPassword",...,RemoteAddress="IPV4/UDP/203.0.113.7/5060",...
```

Gli eventi a cui Fail2Ban è interessato sono `InvalidPassword`, `ChallengeResponseFailed`, `InvalidAccountID` e `FailedACL`, ognuno dei quali trasporta un campo `RemoteAddress="IPV4/UDP/<ip>/<port>"` che identifica il trasgressore. (Nota che l'indirizzo è racchiuso come `IPV4/UDP/.../...`, non come un IP nudo — il tuo filtro deve estrarre l'host dall'interno di quella stringa.)

2. Punta la jail `asterisk` a quel file (`logpath = /var/log/asterisk/security`) e usa un filtro che analizzi questo formato di evento di sicurezza.

I moderni Fail2Ban includono un filtro `asterisk` il cui `failregex` corrisponde già agli eventi sopra indicati ed estrae `<HOST>` dal campo `RemoteAddress`, per esempio:

```
failregex = ^SecurityEvent="(?:FailedACL|InvalidAccountID|ChallengeResponseFailed|InvalidPassword)".*,RemoteAddress="IPV[46]/[^/"]+/<HOST>/\d+"
```

Le distribuzioni PBX (FreePBX/Sangoma) includono filtri equivalenti. Preferisci il filtro pacchettizzato rispetto alla scrittura manuale, poiché le stringhe esatte degli eventi dipendono dalla versione. Un avvertimento di cui essere consapevoli: un advisory ora corretto (GHSA-5743-x3p5-3rg7) ha mostrato che il traffico PJSIP manipolato poteva iniettare righe di log false — mantieni aggiornati sia Asterisk che il tuo filtro Fail2Ban.

Di seguito fornisco le istruzioni per installare Fail2Ban

1. Installa fail2ban su Linux

   ```
   sudo apt-get install fail2ban
   ```

2. Attiva fail2ban per Asterisk e SSH

   ```
   sudo vi /etc/fail2ban/jails.d/defaults-debian.conf
   ```

   Aggiungi le seguenti righe per attivare fail2ban per ssh e asterisk

   ```
   [sshd]
   enabled = true
   [asterisk]
   enabled=true
   ```

3. Riavvia fail2ban

   ```
   /etc/init.d/fail2ban restart
   ```

4. Verifica. Cambia il segreto dal tuo softphone e prova a registrarti nuovamente 10 volte. Usando `iptables -L`, controlla se l'indirizzo del softphone è stato incluso come indirizzo bloccato.
5. Rimuovi l'indirizzo dal ban (supponendo che l'indirizzo sia 192.168.0.5)

   ```
   sudo fail2ban-client set asterisk unbanip 192.168.0.5
   ```

Nota: Nel comando sostituisci 192.168.0.5 con l'indirizzo IP del tuo telefono

### Implementazione di TLS e SRTP

Dividerò questa sezione in due. Nella prima parte tratteremo TLS per crittografare la segnalazione e nella seconda parte SRTP per crittografare i media. L'obiettivo qui è configurare Asterisk per queste risorse.

#### TLS

TLS (Transport Layer Security) è il meccanismo di crittografia definito per proteggere la segnalazione SIP. La tabella seguente riassume contro quali attacchi protegge TLS:

| Tipo di attacco | Protetto? | Note |
|----------------|-----------|-------|
| Attacchi alla segnalazione | Sì | TLS assicura l'integrità dei messaggi |
| Man in the middle | Sì | TLS controlla il certificato del server |
| Eavesdropping | No | TLS crittografa la segnalazione, non i media |

Per la crittografia dei media (voce/video) usa SRTP.

#### Certificati digitali autofirmati

Esistono due tipi di certificati che puoi utilizzare: autofirmati e commerciali. I certificati autofirmati sono firmati dal tuo server, mentre i certificati commerciali sono firmati da un'autorità esterna. Per il VoIP, puoi essere la tua autorità di certificazione. Non c'è bisogno di un certificato esterno come GoDaddy e Verisign, questa è una spesa inutile. Genereremo i nostri certificati usando ast_tls_cert.

#### Configurazione di TLS con certificati autofirmati

Di seguito è riportata una guida passo dopo passo su come implementare TLS. Per prima cosa generiamo i certificati, poi configuriamo il trasporto TLS PJSIP (vedi "Configurazione di TLS con chan_pjsip") e infine puntiamo il softphone ad esso. Utilizzeremo il SipPulse Softphone, che supporta nativamente TLS e SRTP. (Qualsiasi softphone SIP compatibile con TLS/SRTP funziona allo stesso modo.)

**Passaggio 1.** Crea una chiave RSA privata utilizzando la crittografia 3DES con una lunghezza di 4096 bit per la nostra autorità di certificazione. Il comando seguente, presente in /usr/src/asterisk-22.x.y/contrib/scripts, creerà la Certification Authority e il Certificato Asterisk. Come al solito, adatta le istruzioni se necessario, le versioni cambiano, le directory cambiano. Per favore, presta attenzione a ciò che stai facendo. Usa il tuo dominio o indirizzo IP nell'opzione –C. Il comando ast_tls_cert ha tre opzioni.

- -C host o indirizzo IP (ho usato 192.168.0.74, l'indirizzo IP della mia VM)
- -O Nome dell'organizzazione
- -d Directory in cui archiviare le chiavi

```
mkdir /etc/asterisk/keys
cd /usr/src/asterisk-22.0.0/contrib/scripts
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts# ./ast_tls_cert -C 192.168.0.74 -O "AsteriskGuide" -d /etc/asterisk/keys
No config file specified, creating '/etc/asterisk/keys/tmp.cfg'
You can use this config file to create additional certs without
re-entering the information for the fields in the certificate
Creating CA key /etc/asterisk/keys/ca.key
Generating RSA private key, 4096 bit long modulus
........................................................++
........................................................++
e is 65537 (0x010001)
Enter pass phrase for /etc/asterisk/keys/ca.key:
Verifying - Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating CA certificate /etc/asterisk/keys/ca.crt
Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating certificate /etc/asterisk/keys/asterisk.key
Generating RSA private key, 2048 bit long modulus
........................++++++
......................++++++
e is 65537 (0x010001)
Creating signing request /etc/asterisk/keys/asterisk.csr
Creating certificate /etc/asterisk/keys/asterisk.crt
Signature ok
subject=CN = 192.168.0.74, O = AsteriskGuide
Getting CA Private Key
Enter pass phrase for /etc/asterisk/keys/ca.key:
Combining key and crt into /etc/asterisk/keys/asterisk.pem
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts#
```

Non genererò un certificato client perché non utilizzeremo il certificato per autenticare il client. Al client non è richiesto di presentare il proprio certificato.

**Passaggio 2.** Configura Asterisk per supportare il nostro client su TLS. Questo viene fatto in `pjsip.conf` (un trasporto TLS più le impostazioni dell'endpoint) — la configurazione completa è mostrata nella sezione successiva, "Configurazione di TLS con chan_pjsip". Non stiamo autenticando usando i certificati, stiamo solo crittografando il traffico.

**Passaggio 3.** Installa un softphone SIP compatibile con TLS (l'autore usa il SipPulse Softphone).

**Passaggio 4.** Copia l'autorità di certificazione sul computer che esegue il softphone. Dopo averla installata, copia il file `/etc/asterisk/keys/ca.crt` sul computer che esegue il softphone (usa scp, o WinSCP su Windows) se stai usando un certificato autofirmato.

**Passaggio 5.** Crea l'account nel softphone. Nella schermata dell'account aggiungi l'account normalmente come qualsiasi altro account sip. Usa la password corretta, l'autenticazione è ancora basata sulla password.

**Passaggio 6.** Imposta TLS come trasporto nelle impostazioni dell'account. Nella schermata dell'account del SipPulse Softphone (sotto), scegli **TLS** come trasporto e usa la porta 5061. Regola il tuo firewall per aprire la porta TCP 5061.

![La schermata dell'account del SipPulse Softphone — inserisci il Server (il tuo IP o dominio Asterisk), Nome utente, Password e Nome visualizzato, quindi scegli il Trasporto (UDP, TCP o TLS).](../images/softphone/sipphone-account.png){width=35%}

**Passaggio 7.** Considera attendibile l'autorità di certificazione. Se il tuo certificato TLS Asterisk è firmato da una CA pubblica (ad esempio Let's Encrypt — vedi il capitolo *Deployment*), un softphone moderno come il SipPulse Softphone lo considera attendibile automaticamente tramite l'archivio certificati di sistema, senza importazione manuale. Se usi un certificato autofirmato, importa la sua CA (`/etc/asterisk/keys/ca.crt`) nel client o nell'archivio di attendibilità del sistema operativo, o accettalo quando richiesto.

**Passaggio 8.** **Non** hai bisogno di un certificato client. Un malinteso comune è che ogni telefono abbia bisogno del proprio certificato per autenticarsi — non è così. A questo punto Asterisk *crittografa* solo la sessione; l'autenticazione è ancora nome utente e password. Asterisk non verifica i certificati client per impostazione predefinita, quindi non c'è bisogno di distribuire un certificato per ogni client.

**Passaggio 9.** Dopo aver modificato il certificato o il trasporto, riavvia completamente il softphone (chiudi e riapri, non limitarti a chiudere la finestra) in modo che si riconnetta tramite il nuovo trasporto.

### Configurazione di TLS con chan_pjsip

Ora impariamo come configurare PJSIP per TLS. PJSIP è l'unico canale SIP in Asterisk 22, quindi non c'è nulla da cambiare — assicurati solo che `res_pjsip`, `res_pjproject` e `chan_pjsip` siano caricati. Passaggio 1: Conferma che PJSIP sia abilitato in /etc/asterisk/modules.conf.

```
; res_pjsip / res_pjproject / chan_pjsip must be loaded (do NOT noload them)
noload => chan_iax2.so
noload => chan_unistim.so
```

Passaggio 2: Configura PJSIP per supportare TLS. Aggiungi una sezione per il trasporto TLS nel file /etc/asterisk/pjsip.conf

```
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

Usa `method=tlsv1_2` (o `tlsv1_3` se la tua build OpenSSL/PJSIP lo supporta) — TLS 1.0/1.1 sono obsoleti e insicuri e non dovrebbero essere usati.

Passaggio 3: Configura l'endpoint per blink. Modifica `pjsip.conf` e modifica la sezione per blink. Lascia che PJSIP scelga il trasporto automaticamente.

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
dtmf_mode=rfc4733
media_encryption=sdes
[blink]
type=aor
max_contacts=2
remove_existing=yes
[blink]
type=auth
auth_type=digest
username=blink
password=supersecret
```

Passaggio 4: Verifica. Per verificare che la registrazione sia avvenuta su TLS, usa il seguente comando nella console Asterisk.

```text
asterisk*CLI> pjsip show aor blink

      Aor:  <Aor.............................................>  <MaxContact>
    Contact:  <Aor/ContactUri........................> <Hash....> <Status> <RTT(ms)..>
==========================================================================================

      Aor:  blink                                                2
    Contact:  blink/sip:03694827@192.168.0.67:56295;transp 620d91556d NonQual    nan
 ParameterName        : ParameterValue
 ====================================================================
 authenticate_qualify : false
 contact              : sip:03694827@192.168.0.67:56295;transport=tls
 default_expiration   : 3600
 max_contacts         : 2
 maximum_expiration   : 7200
 minimum_expiration   : 60
 qualify_frequency    : 0
 qualify_timeout      : 3.000000
 remove_existing      : true
 support_path         : false
```

### Effettuare chiamate sicure utilizzando SRTP

Il protocollo responsabile della crittografia dei media è il Secure Real Time Protocol (SRTP) definito nella RFC3711. Uno dei limiti del protocollo è la mancanza di un modo standardizzato per scambiare chiavi. Asterisk utilizza chiavi di scambio SDES sul protocollo SDP protetto dalla crittografia della segnalazione fornita da TLS. Esistono anche altri metodi come MIKEY e ZRTP. ZRTP, sviluppato da Philipp Zimmermann, è uno dei metodi più sofisticati per lo scambio di chiavi e la crittografia dei media. Alcuni softphone e telefoni hardware consentono ZRTP. Tuttavia, il metodo standard è ancora SDES e troverai questo metodo in quasi tutti i telefoni disponibili sul mercato. Di seguito un esempio di una richiesta con le chiavi crittografiche definite nell'SDP nelle righe a=crypto:1 e a=crypto:2.

```
INVITE sip:8000@192.168.1.237 SIP/2.0
Via:
SIP/2.0/tls
192.168.1.192:65525;rport;branch=z9hG4bKPj9fa224a14b17488ea15625ead833ea3a
Max-Forwards: 70
From:
"Flavio"
<sip:flavio@192.168.1.237>;tag=35afe6cc11274934867b24e43c805638
To: <sip:8000@192.168.1.237>
Contact: <sip:pyhkxnjz@192.168.1.192:65524;transport=tls>
Call-ID: 530a339c72af47f0a76e7ecb2a58ac43
CSeq: 5669 INVITE
Allow: SUBSCRIBE, NOTIFY, PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, MESSAGE
Supported: 100rel
User-Agent: Blink 0.2.5 (Windows)
Authorization: Digest username="flavio", realm="asterisk", nonce="72ff51ad",
uri="sip:8000@192.168.1.237",
response="ba8c10672751baa7007d82eb34e2340e",
algorithm=MD5
Content-Type: application/sdp
Content-Length: 544
v=0
o=- 3509174186 3509174186 IN IP4 192.168.1.192
s=Blink 0.2.5 (Windows)
c=IN IP4 192.168.1.192
t=0 0
m=audio 50004 RTP/SAVP 9 104 103 102 0 8 101
a=rtcp:50005
a=rtpmap:9 G722/8000
a=rtpmap:104 speex/32000
a=rtpmap:103 speex/16000
a=rtpmap:102 speex/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=crypto:1
AES_CM_128_HMAC_SHA1_80
inline:WrtZH82ztz93albRNT8o+oMcK9GvlAHRoaR1STvJ
a=crypto:2
AES_CM_128_HMAC_SHA1_32
inline:4Ma9jJOCEEGMPzzkmgyf6ttp1qhN16yumdXB7eRv
a=sendrecv
```

#### Configurazione di SRTP su Asterisk

Configurare SRTP su Asterisk è molto semplice. Imposta `media_encryption=sdes` sull'endpoint; puoi anche richiederlo con `media_encryption_optimistic=no` in modo che i media non crittografati vengano rifiutati invece di essere silenziosamente consentiti. Nota che SDES richiede che la segnalazione venga eseguita su TLS in modo che le chiavi non vengano inviate in chiaro.

**Passaggio 1.** Configurazione di Asterisk

Imposta quanto segue nella sezione `type=endpoint` in `pjsip.conf`:

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
transport=transport-tls
media_encryption=sdes
media_encryption_optimistic=no
```

**Passaggio 2.** Configurazione del softphone

Nel softphone, abilita SRTP per i media dell'account (imposta l'opzione **SRTP (Media Encryption)** su *Mandatory*) in modo che la voce sia crittografata.

![Le impostazioni dell'account del SipPulse Softphone (sezione inferiore) — imposta **Transport** su TLS e **SRTP (Media Encryption)** su *Mandatory* in modo che sia la segnalazione che i media siano crittografati.](../images/softphone/sipphone-config.png){width=35%}

## Abilitazione dell'autenticazione a due fattori per le chiamate internazionali

A volte la soluzione migliore è non avere rotte internazionali. Tuttavia, se hai davvero bisogno di effettuare chiamate internazionali, utilizza una password aggiuntiva. Utilizzeremo l'applicazione Asterisk vmauthenticate per richiedere la password della voicemail prima di comporre un numero internazionale. Questo viene configurato nel dialplan all'interno di extensions.conf. Vedi l'esempio qui sotto. In questo modo, un hacker, anche dopo aver scoperto la password di un peer o aver compromesso un telefono, avrà comunque bisogno della password della voicemail per chiamare questa destinazione.

```
exten=_9011.,1,Playback(pleasedialyourvmpassword)
exten=_9011.,2,VMAuthenticate(${CALLERID(num)}@default,s)
exten=_9011.,3,Dial(PJSIP/${EXTEN:1}@my_trunk,20,tT)
exten=_9011.,4,Hangup()
```

`VMAuthenticate` è ancora un'applicazione standard in Asterisk 22. Il `Dial()` qui sopra instrada la chiamata su un trunk SIP/PJSIP (`PJSIP/<number>@<trunk>`), che è il modo in cui la maggior parte delle installazioni moderne raggiunge la PSTN — adatta `my_trunk` al nome del tuo trunk e usa `DAHDI/g1/...` solo se disponi effettivamente di uno span DAHDI. La difesa contro le frodi telefoniche nel dialplan — un secondo fattore come questo, combinato con la restrizione dei context che possono raggiungere le tue rotte in uscita e internazionali — rimane una delle protezioni più importanti che puoi implementare.

## Riepilogo

In questo capitolo abbiamo appreso i rischi legati alla connessione di un IP PBX a Internet. Successivamente, abbiamo imparato come proteggere il nostro PBX implementando una politica di sicurezza. In questa politica di sicurezza abbiamo implementato iptables, fail2ban, TLS, SRTP e l'autenticazione a due fattori per le chiamate internazionali. Spero che questo capitolo sia stato di vostro gradimento.

## Quiz

1. Qual è la contromisura più importante contro la frode di tipo Internet Revenue Share Fraud?
   - A. Implementare SRTP
   - B. Mantenere Asterisk aggiornato
   - C. Implementare TLS
   - D. Utilizzare password complesse
2. Il SIP fuzzing è definito come:
   - A. Un attacco DoS che utilizza richieste e risposte malformate
   - B. Furto di servizio in cui le password vengono forzate tramite brute-force
   - C. Intercettazione di chiamate in corso
   - D. Un DDoS con un flood di richieste SIP
3. Il TFTPTheft si verifica quando il server fornisce file di configurazione tramite TFTP. È possibile evitarlo utilizzando:
   - A. FTP
   - B. HTTP
   - C. HTTPS con nome utente e password
   - D. SCP
4. Gli attacchi man-in-the-middle utilizzano una tecnica chiamata:
   - A. TFTP theft
   - B. ARP spoofing
   - C. MAC poisoning
   - D. dsniff
5. Per SRTP, Asterisk utilizza il seguente sistema per lo scambio delle chiavi:
   - A. MIKEY
   - B. SDES
   - C. ZRTP
   - D. Pluto
6. L'utility che genera la certificate authority e i certificati, che si trova in `/usr/src/asterisk-22.x.y/contrib/scripts`, è:
   - A. ast_tls_cert
   - B. gen_tls
   - C. gen_ast_tls
   - D. tls_generator
7. Strategie valide per prevenire le intercettazioni (selezionare tutte le opzioni applicabili):
   - A. Implementare rilevatori di intercettazioni analogiche
   - B. Utilizzare l'utility ARPwatch per rilevare l'ARP spoofing
   - C. Abilitare il rilevamento dell'ARP-spoofing negli switch
   - D. Utilizzare SRTP
8. Asterisk supporta l'autenticazione forte verificando i certificati client. (Il trasporto PJSIP TLS può richiedere e verificare il certificato del client.)
   - A. Vero
   - B. Falso
9. Su Asterisk 22, quale impostazione dell'endpoint PJSIP attiva la cifratura dei media SRTP utilizzando chiavi in-SDP (SDES)?
   - A. `encryption=yes`
   - B. `media_encryption=sdes`
   - C. `srtp=mandatory`
   - D. `transport=tls`
10. In Asterisk 22, Fail2Ban deve leggere gli eventi di autenticazione PJSIP fallita dal canale logger dedicato ________ (abilitato in `logger.conf`).
   - A. `console`
   - B. `messages`
   - C. `security`
   - D. `verbose`

**Risposte:** 1 — D · 2 — A · 3 — C · 4 — B · 5 — B · 6 — A · 7 — B, C, D · 8 — A · 9 — B · 10 — C
