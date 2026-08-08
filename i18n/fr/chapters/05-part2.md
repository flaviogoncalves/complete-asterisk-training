# Partie II — Canaux et connectivité {.unnumbered}

La partie II traite de la manière dont les appels entrent et sortent d'Asterisk. Nous commençons par concevoir le réseau VoIP autour de celui-ci — codecs, bande passante et NAT — puis nous étudions en profondeur SIP et son implémentation moderne PJSIP, étant donné que PJSIP est le seul canal SIP dans Asterisk 22.

À partir de là, nous ajoutons les connexions nécessaires à un déploiement réel : les appels via navigateur avec WebRTC, les trunks et les DID pour atteindre le PSTN et vos fournisseurs, ainsi que les canaux analogiques, numériques (TDM) et IAX2 hérités que vous pourriez encore rencontrer sur le terrain. À la fin, vous serez capable de connecter Asterisk aussi bien à des téléphones, des navigateurs et des opérateurs qu'à des équipements plus anciens.
