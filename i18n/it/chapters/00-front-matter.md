```{=latex}
\frontmatter
```

## Copyright {.unnumbered}

*Asterisk Guide* — Seconda Edizione (Asterisk 22 LTS)

Copyright © 2006–2026 Flavio E. Gonçalves. Tutti i diritti riservati.

Nessuna parte di questo libro può essere riprodotta, archiviata in un sistema di recupero dati o trasmessa in qualsiasi forma o con qualsiasi mezzo senza il previo consenso scritto dell'autore, ad eccezione di brevi estratti utilizzati in recensioni pubblicate.

**Edizione:** Seconda Edizione.

> **[author TODO]** Assegnare un nuovo ISBN per la seconda edizione (non riutilizzare quello della prima edizione 9781796396973) e impostare la data di pubblicazione prima della stampa.

Molte delle denominazioni utilizzate dai produttori e dai venditori per distinguere i propri prodotti sono rivendicate come marchi. Laddove tali denominazioni appaiono in questo libro e l'autore era a conoscenza di una rivendicazione di marchio, esse sono state stampate in maiuscolo o con l'iniziale maiuscola. Asterisk, Digium, IAX e DUNDi sono marchi di Sangoma Technologies (Digium è stata acquisita da Sangoma nel 2018; Asterisk è ora sponsorizzato da Sangoma).

Sebbene sia stata presa ogni precauzione nella preparazione di questo libro, l'autore non si assume alcuna responsabilità per errori od omissioni, o per danni derivanti dall'uso delle informazioni qui contenute.

## Prefazione {.unnumbered}

Questo libro è rivolto a chiunque desideri imparare a installare e configurare un PBX (Private Branch Exchange) basato su Asterisk 22 LTS. Asterisk è una piattaforma di telefonia open source che funge da ponte tra VoIP e i canali TDM tradizionali.

Questa è la quinta generazione di un libro nato originariamente come *Asterisk Configuration Guide*. Il materiale è frutto del lavoro svolto per prepararmi alla certificazione Digium dCAP nel 2006 — che ho superato al primo tentativo — ed è stato insegnato a più di mille studenti da allora.

Il concetto di PBX open source è rivoluzionario. Per decenni, la telefonia è stata dominata da una manciata di aziende che vendevano costosi sistemi proprietari. Asterisk ha restituito quel potere nelle mani degli utenti: funzionalità un tempo economicamente irraggiungibili — CTI (computer-telephony integration), IVR (interactive voice response), ACD (automatic call distribution), voicemail e molto altro — sono ora disponibili per chiunque disponga di una macchina Linux e della volontà di imparare.

Questo libro non vi trasformerà in un guru da solo — nessun libro può farlo — ma alla fine sarete in grado di costruire e gestire un PBX reale con funzionalità avanzate. Il libro è accompagnato da risorse aggiuntive — laboratori pratici e un corso online — presso **VoIP School Blackbelt** (<https://voip.school>).

## Destinatari {.unnumbered}

Questo libro è pensato per i lettori che si avvicinano per la prima volta ad Asterisk. Do per scontato che abbiate familiarità con Linux: la shell, un editor di testo e l'amministrazione di base del sistema. Potete seguire le lezioni su un desktop Linux se vi risulta più semplice durante l'apprendimento, e una macchina virtuale va bene per i laboratori (aspettatevi una qualità vocale leggermente inferiore). Per i sistemi in produzione, non consiglio di eseguire Asterisk in un ambiente desktop o all'interno di una VM con poche risorse. Una certa familiarità con le reti IP, il Voice over IP (VoIP) e i concetti base della telefonia sarà d'aiuto.

## Novità della seconda edizione {.unnumbered}

La seconda edizione è un'accurata modernizzazione per **Asterisk 22 LTS** (rilasciato nel 2024,
supportato fino a ottobre 2028). Le principali novità:

- **PJSIP è l'unico canale SIP.** `chan_sip` è stato rimosso in Asterisk 21 e non
  esiste nella versione 22. Ogni esempio SIP ora utilizza PJSIP (`pjsip.conf`); il materiale
  legacy `sip.conf` è mantenuto solo come riferimento per la migrazione.
- **Gestione da parte di Sangoma.** Digium è stata acquisita da Sangoma nel 2018; il progetto è ora
  sviluppato e sponsorizzato da Sangoma, e il testo lo riflette in ogni sua parte.
- **Tre nuovi capitoli.** *WebRTC with Asterisk* (telefoni basati su browser tramite WSS/DTLS-SRTP),
  *SIP trunking, DID & the PSTN* e *Deployment, monitoring & scaling*.
- **Un laboratorio riproducibile.** Ogni configurazione e comando nel libro è verificato
  rispetto a un laboratorio Docker con Asterisk 22 che puoi eseguire autonomamente.
- **Funzionalità modernizzate.** ConfBridge sostituisce la vecchia conferenza MeetMe, ARI viene
  introdotto insieme ad AMI/AGI, viene trattato PJSIP Realtime (Sorcery) e i capitoli su installazione,
  sicurezza e CDR sono stati aggiornati.
- **Una nuova struttura.** Il libro è ora organizzato in quattro parti: Fondamenta,
  Canali e connettività, Dialplan e funzionalità di chiamata, e Integrazione e operazioni.

## Informazioni sull'autore {.unnumbered}

Flavio E. Gonçalves è nato nel 1966 in Brasile. Nutre un forte interesse per i computer da quando ha ottenuto il suo primo PC nel 1983 e ha conseguito una laurea in ingegneria nel 1989 con specializzazione in progettazione e produzione assistita da computer. È il CEO di SipPulse in Brasile, un'azienda dedicata a SoftSwitch, SBC e PBX multitenant.

Nel corso della sua carriera ha ottenuto una lunga lista di certificazioni: Novell MCNE/MCNI, Microsoft MCSE/MCT, Cisco CCSP/CCNP/CCDP e Asterisk dCAP, tra le altre. Ha iniziato a scrivere di software open source perché crede che il metodo strutturato con cui le certificazioni insegnavano il materiale sia un ottimo modo per imparare, e ha attinto a oltre 25 anni di esperienza nell'insegnamento per scrivere in modo adatto a come le persone imparano realmente, piuttosto che basandosi puramente su un punto di vista tecnico.

Flavio è padre di due figli e vive a Florianópolis, in Brasile — uno dei posti più belli al mondo — dove trascorre il suo tempo libero facendo surf e andando a vela.

## Feedback, crediti e formazione {.unnumbered}

Cerco sempre di trovare ed eliminare gli errori, ma alcuni riescono sempre a sfuggire. Se trovi qualcosa di sbagliato, per favore fammelo sapere e provvederò a correggerlo.

Questo libro viene utilizzato anche come materiale didattico. Se desideri utilizzarlo nel tuo centro di formazione, o seguire il corso online e i laboratori associati, visita **VoIP School Blackbelt** su <https://voip.school> o invia un'email a <flavio@voip.school>.

**Crediti.** Copertina: Karla Braga. Revisori: Luis F. Gonçalves, Guilherme Goes (dCAP) e correttori di bozze professionisti. I miei ringraziamenti vanno anche ai numerosi studenti il cui feedback nel corso degli anni ha dato forma a questo materiale, e alla mia famiglia per il loro supporto.

```{=latex}
\cleardoublepage
```
