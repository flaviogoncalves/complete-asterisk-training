# Parte II — Canali e Connettività {.unnumbered}

La Parte II riguarda il modo in cui le chiamate entrano ed escono da Asterisk. Iniziamo progettando la rete VoIP attorno ad esso — codec, larghezza di banda e NAT — per poi studiare in profondità SIP e la sua moderna implementazione PJSIP, dato che PJSIP è l'unico canale SIP in Asterisk 22.

Da lì aggiungiamo le connessioni necessarie a una distribuzione reale: chiamate da browser con WebRTC, trunk e DID per raggiungere la PSTN e i propri provider, oltre ai canali legacy analogici, digitali (TDM) e IAX2 che si potrebbero ancora incontrare sul campo. Alla fine, sarai in grado di collegare Asterisk a telefoni, browser, carrier e apparecchiature più datate allo stesso modo.
