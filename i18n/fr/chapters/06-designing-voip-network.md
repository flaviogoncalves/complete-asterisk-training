# Conception d'un réseau VoIP

La voix sur IP se développe rapidement sur le marché de la téléphonie. Le paradigme de convergence modifie notre façon de communiquer, réduisant les coûts et améliorant la manière dont nous échangeons des informations. La voix n'est que le début d'une ère de communication multimédia complète, incluant la voix, la vidéo et la présence. À l'avenir, nous ne transporterons plus les personnes vers le travail, mais le travail vers les personnes, car c'est plus propre, plus rapide et moins coûteux. La VoIP n'est qu'une partie de cette révolution. Notre défi dans ce chapitre est de concevoir un réseau VoIP. Pour ce faire, nous devrons comprendre des concepts tels que les protocoles de session et les codec, ainsi que la manière de dimensionner le nombre de circuits et la bande passante.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Comprendre les avantages de la VoIP
- Décrire comment Asterisk gère la VoIP
- Décrire les concepts des canaux SIP et IAX
- Choisir le protocole le plus adéquat pour un canal de données spécifique
- Choisir le codec le plus adéquat pour un canal de données spécifique
- Dimensionner le nombre de canaux requis
- Calculer la bande passante nécessaire

## Avantages de la VoIP

Pourquoi s'intéresser à la VoIP ? La VoIP offre des avantages tant aux entreprises qu'aux particuliers. La réduction des coûts en est certainement un, mais dans certains environnements, la VoIP simplifie l'intégration des systèmes informatiques. Plusieurs de ces avantages sont détaillés ici :

### Convergence

L'avantage principal de la VoIP est la combinaison des réseaux de données et de voix afin de réduire les coûts (convergence). Cependant, analyser uniquement le coût des minutes de communication peut ne pas suffire à justifier l'adoption de la VoIP. Le prix des minutes vendues par les opérateurs téléphoniques devient rapidement plus abordable et c'est un élément à prendre en considération avant d'adopter la VoIP.

### Coûts d'infrastructure

L'utilisation d'une infrastructure réseau unique réduit les coûts associés aux ajouts, aux suppressions et aux modifications. Comme l'IP est devenue omniprésente, elle a apporté la technologie liée à la VoIP sur plusieurs nouveaux appareils, tels que les téléphones portables, les PDA, les systèmes embarqués et les ordinateurs portables.

### Standards ouverts

Enfin, les standards ouverts sur lesquels la VoIP est construite offrent la liberté de choisir parmi différents fournisseurs. Ce seul avantage fait du client le roi plutôt qu'un subordonné des TELCOS et des fabricants de PBX.

### Intégration de la téléphonie informatique

La téléphonie est bien plus ancienne que l'informatique. Les PBX téléphoniques sont basés sur la commutation de circuits, et vous n'avez généralement pas plus qu'un ordinateur pour la supervision. Avec la VoIP, la téléphonie est créée dès le départ sur la base de standards informatiques. Cela rend l'utilisation d'applications de téléphonie informatique moins coûteuse et plus facile que dans l'ancien modèle. Vous pouvez rapidement créer une longue liste d'applications de téléphonie basées sur Asterisk. Vous pouvez développer des IVR, des ACD, du CTI, des dialers, des fenêtres contextuelles (screen popups) et d'autres applications en une fraction du temps requis pour les PBX traditionnels.

## Architecture VoIP d'Asterisk

L'architecture d'Asterisk est présentée ci-dessous. Asterisk traite tous les protocoles VoIP comme des canaux. Vous pouvez utiliser n'importe quel codec ou n'importe quel protocole. Le concept à retenir ici est qu'Asterisk établit un pont entre n'importe quel type de canal et n'importe quel autre. Ainsi, vous pouvez traduire des protocoles de signalisation tels que SIP et IAX les uns vers les autres, même avec des codecs différents. Par exemple, vous pouvez traduire un appel provenant d'un téléphone SIP sur le réseau local utilisant le codec G.711 vers un trunk SIP chez votre fournisseur VoIP utilisant le codec G.729. Dans les chapitres suivants, nous expliquerons les détails de l'architecture SIP et IAX. Le support de H.323 (via l'add-on chan_ooh323) est disponible mais de plus en plus rare ; SIP/PJSIP est le standard pour les déploiements modernes.

![Architecture modulaire d'Asterisk : les applications et les canaux se connectent au cœur du commutateur PBX via des API, avec des modules de traduction de codec et de format de fichier chargés dynamiquement.](images/asterisk-architecture.png){width=100%}(../images/06-voip-network-fig01.png)

## Protocoles VoIP et pile réseau

La VoIP utilise un ensemble de protocoles différents fonctionnant de concert. Il est tentant de les aligner sur le modèle de référence OSI à sept couches, et de nombreux diagrammes anciens font exactement cela — en plaçant SIP et H.323 à la couche « session » et les codec à la couche « présentation ». Ce mappage a toujours été sujet à controverse. L'IETF, qui normalise SIP, n'utilise pas le modèle OSI ; il suit le modèle TCP/IP (DoD) à quatre couches, plus ancien, et la RFC 3261 définit **SIP comme un protocole de couche application**. Les médias suivent le même schéma : RTP et les codec résident dans la charge utile de l'application, transportés sur UDP au niveau de la couche transport. Le tableau ci-dessous mappe les principaux protocoles VoIP sur le modèle TCP/IP réellement utilisé par l'IETF, avec l'équivalent OSI approximatif indiqué uniquement pour référence.

| Couche TCP/IP (IETF) | Protocoles | Équivalent OSI approximatif |
|---|---|---|
| Application | SIP, H.323, MGCP, signalisation IAX2 ; RTP/RTCP ; codec (G.711, G.729, Opus…) | Application / Présentation / Session |
| Transport | UDP, TCP | Transport |
| Internet | IP (avec QoS telle que DiffServ) | Réseau |
| Liaison | Ethernet, PPP, Frame Relay… | Liaison de données / Physique |

Les mécanismes de QoS tels que DiffServ opèrent au niveau de la couche IP pour prioriser les paquets vocaux et améliorer la qualité des appels. Quelques spécificités de protocoles :

- **SIP** utilise UDP ou TCP sur le port 5060 (TLS sur 5061) pour transporter la signalisation. L'audio est transporté séparément par RTP sur une plage de ports UDP configurable (l'exemple `rtp.conf` fourni avec Asterisk utilise 10000 à 20000), encodé avec un codec tel que G.711.
- **H.323** transporte la signalisation d'appel sur TCP (signalisation d'appel H.225 sur le port 1720), tandis que le canal RAS H.225 utilise UDP sur le port 1719 ; RTP transporte l'audio.
- **IAX2** est inhabituel : il multiplexe à la fois la signalisation et les médias sur un seul port UDP (4569), ce qui simplifie le franchissement de NAT et de pare-feu.


## Comment choisir un protocole

Compte tenu du grand nombre de protocoles, comment choisir le meilleur pour votre réseau ? Dans cette section, nous mettrons en évidence les avantages et les inconvénients de chaque protocole.

### SIP - Session Initiated Protocol

SIP est un standard ouvert de l'Internet Engineering Task Force (IETF), largement défini dans la RFC 3261. La plupart des fournisseurs VoIP modernes utilisent SIP ; en effet, il devient le standard VoIP le plus populaire. La force de SIP réside dans le fait qu'il s'agit d'un standard basé sur l'IETF. SIP est léger comparé à l'ancien H.323. La principale faiblesse de SIP est la traversée de NAT, un défi pour la plupart des fournisseurs VoIP SIP. L'IETF n'a pas créé SIP avec la facturation à l'esprit, mais pour des communications ouvertes entre pairs. La facturation est généralement une préoccupation pour les fournisseurs VoIP.

### IAX – Inter Asterisk eXchange

IAX est un protocole ouvert développé à l'origine par Digium (maintenant Sangoma). IAX est un protocole tout-en-un car il transporte la signalisation et les médias via le même port UDP (4569). Mark Spencer a développé IAX en tant que protocole binaire pour une bande passante réduite. La force principale d'IAX est son utilisation réduite de la bande passante (il n'utilise pas RTP) ; il est également très facile pour la traversée de NAT et de pare-feu puisqu'il n'utilise qu'un seul port UDP (4569).

Si un fabricant de PBX traditionnel avait créé IAX, il aurait probablement commercialisé le protocole comme « la meilleure invention depuis la crème glacée » ; dans certaines situations, IAX en mode trunk peut réduire l'utilisation de la bande passante vocale d'un tiers. IAX2 (version 2) est toujours fourni dans Asterisk 22 via le module `chan_iax2` et reste utile pour les trunks Asterisk-à-Asterisk, bien qu'il soit considéré comme un héritage ; SIP/PJSIP est préféré pour les nouveaux déploiements. IAX2 est spécifié dans [RFC 5456](https://www.rfc-editor.org/rfc/rfc5456) (Informationnel).

### MGCP – Media Gateway Control Protocol

MGCP est un protocole utilisé conjointement avec H.323, SIP et IAX. Son plus grand avantage est l'évolutivité. Il est configuré dans l'agent d'appel plutôt que dans les passerelles. Cela simplifie le processus de configuration et permet une gestion centralisée. Cependant, l'implémentation dans Asterisk n'est pas complète, et il semble que peu de gens l'utilisent.

### H.323

H.323 est largement utilisé dans la VoIP. C'est l'un des premiers protocoles VoIP et il est essentiel pour connecter les infrastructures VoIP plus anciennes basées sur des passerelles. H.323 est toujours le standard sur le marché des passerelles, bien que le marché migre lentement vers SIP. Les forces de H.323 incluent sa large adoption sur le marché et sa maturité. Les faiblesses de H.323 sont liées à la complexité de l'implémentation et aux coûts associés aux organismes de normalisation.

### Tableau de comparaison des protocoles

Le tableau suivant résume les différences entre les protocoles de session.

| Protocole | Organisme de normalisation | Module Asterisk 22 / statut | Utilisé pour |
|----------|---------------|-----------------------------|----------|
| SIP | Standard IETF | `chan_pjsip` (cœur ; le seul pilote SIP — `chan_sip` a été supprimé dans Asterisk 21) | Téléphones SIP ; connexion aux fournisseurs de services SIP |
| IAX2 | RFC 5456 (Informationnel) | `chan_iax2` (cœur ; toujours fourni, considéré comme un héritage) | Trunks Asterisk-à-Asterisk ; téléphones IAX2 ; fournisseurs de services IAX |
| H.323 | Standard ITU | `chan_ooh323` (extension communautaire externe, pas dans la version de base) | Téléphones et passerelles H.323 (peut utiliser un gatekeeper externe, ne peut pas en être un) |
| MGCP | IETF/ITU | `chan_mgcp` supprimé dans Asterisk 21 — plus disponible | (téléphones MGCP hérités) |
| SCCP (Skinny) | Propriétaire Cisco | `chan_skinny` supprimé dans Asterisk 21 — plus disponible | (téléphones Cisco hérités) |

## Un endpoint par appareil

Dans Asterisk 22, la pile PJSIP modélise chaque téléphone, trunk ou passerelle comme un seul objet **endpoint** dans `pjsip.conf`. Un endpoint passe et reçoit des appels ; ses identifiants résident dans un objet `auth`, son adresse enregistrée dans un `aor`, et son chemin réseau dans un `transport`. Vous configurez un endpoint par appareil et y attachez les éléments nécessaires — il n'y a pas de rôle distinct "user" ou "peer" à prendre en compte. (Le modèle d'objet complet est traité dans *SIP & PJSIP in depth*.)

## Codecs et traduction de codecs

Vous utiliserez un codec pour convertir la voix d'une onde analogique en un signal numérique. Les codecs diffèrent les uns des autres par des aspects tels que la qualité sonore, le taux de compression, la bande passante et les besoins en ressources informatiques. Les services, les téléphones et les passerelles prennent généralement en charge plusieurs de ces aspects. Le codec G.729 est très populaire. Il ne fait pas partie de la version standard de Asterisk 22 ; il est fourni sous forme de module complémentaire externe (`codec_g729`) que vous téléchargez depuis Digium (désormais Sangoma). La source `menuselect` de Asterisk le répertorie avec `support_level=external` et note clairement : "Téléchargez le codec g729a depuis Digium. Une licence doit être achetée pour ce codec." En d'autres termes, l'utilisation légale du G.729 nécessite l'achat d'une licence par canal. (Une alternative open-source, `bcg729`, existe également.)

![Modulation par impulsions codées (PCM) : un signal analogique de 4000 Hz est échantillonné 8000 fois par seconde (théorème de Nyquist) et codé en un flux binaire numérique de 64 Kbps.](../images/06-voip-network-fig04.png)

Asterisk 22 prend en charge les codecs suivants (entre autres) :

- GSM : 13 Kbps
- iLBC : 13.3 Kbps
- ITU G.711 (ulaw/alaw) : 64 Kbps — qualité PSTN standard ; ulaw courant en Amérique du Nord, alaw courant en Europe et en Amérique latine
- ITU G.722 : 64 Kbps — large bande (voix HD), bonne qualité avec la même bande passante que le G.711
- ITU G.723.1 : 5.3/6.3 Kbps
- ITU G.726 : 16/24/32/40 Kbps
- ITU G.729 : 8 Kbps — module binaire externe `codec_g729` téléchargé depuis Digium/Sangoma (`support_level=external` ; une licence doit être achetée pour l'utiliser)
- Speex : 2.15 à 44.2 Kbps
- LPC10 : 2.4 Kbps
- **Opus** : 6–510 Kbps, variable — codec moderne large bande/bande complète ; excellente qualité et résilience à la perte de paquets ; fourni sous forme de module binaire externe `codec_opus` téléchargé depuis Digium/Sangoma (`support_level=external` ; aucun achat de licence noté, contrairement au G.729) ; recommandé pour WebRTC et les endpoints SIP modernes. (Des alternatives de compilation open-source existent sur GitHub.)

De plus, Asterisk permet la traduction entre les codecs. Dans certains cas, cela n'est pas possible, comme pour le g723, qui n'est pris en charge qu'en mode pass-thru. La traduction d'un codec à un autre consomme beaucoup de ressources CPU. Par conséquent, évitez cela autant que possible.

## Comment choisir un codec

Le choix du codec dépend de plusieurs options, telles que :

- La qualité sonore
- Les coûts de licence
- La consommation de ressources CPU
- Les besoins en bande passante
- La dissimulation de perte de paquets
- La disponibilité pour Asterisk et les terminaux téléphoniques

Le tableau suivant compare les codecs les plus populaires. La qualité de ces codecs est considérée comme « toll » (qualité téléphonique) — en d'autres termes, similaire à celle du PSTN.

| Codec | G.711 | G.722 | Opus | G.729A | iLBC | GSM |
|---|---|---|---|---|---|---|
| Bande audio | Étroite | Large (HD) | Étroite–complète | Étroite | Étroite | Étroite |
| Bande passante (Kbps) | 64 | 64 | 6–510 | 8 | 13.33 | 13 |
| Coût/canal | Gratuit | Gratuit | Gratuit | Licence¹ | Gratuit | Gratuit |
| Effacement de trame² | Aucun | Faible | Excellent | ~3% | ~5% | ~3% |
| Coût CPU | Très faible | Faible | Mod.–élevé | Élevé | Élevé | Faible |

Les modules d'Asterisk 22 sont : G.711 `codec_ulaw` / `codec_alaw` (cœur), G.722 `codec_g722` (cœur), Opus `codec_opus` (externe), G.729 `codec_g729` (externe), iLBC `codec_ilbc` (cœur) et GSM `codec_gsm` (cœur). Opus est qualifié de « Étroite–complète » car il s'adapte de la bande étroite jusqu'à la bande complète ; sa bande passante (6–510 Kbps) est variable, et sa résistance à l'effacement de trame provient de ses fonctions intégrées de FEC/PLC.

La référence du PSTN est le **G.711** — c'est la référence pour la qualité « toll » et il est transcodé gratuitement au sein d'Asterisk. Le **G.722** offre une voix large bande (HD) au même débit de 64 Kbps et constitue un bon choix pour le LAN/interne. **Opus** est le standard moderne par défaut pour WebRTC et les endpoints SIP compatibles : il adapte son débit binaire, dispose d'une correction d'erreur directe intégrée et résiste bien à la perte de paquets ; il est fourni sous forme de binaire externe `codec_opus` (téléchargement gratuit). Le **G.729** reste utile sur les trunks WAN à faible bande passante, mais son utilisation légale nécessite soit le module sous licence de Sangoma `codec_g729` (téléchargement gratuit, licence par canal requise pour l'utilisation), soit l'implémentation open-source **bcg729** comme alternative.

¹ Le binaire `codec_g729` de Sangoma est gratuit au téléchargement mais nécessite l'achat d'une licence par canal pour une utilisation légale. L'implémentation open-source `bcg729` est une alternative sans licence.

² La résistance à l'effacement de trame fait référence à la façon dont la qualité perçue (MOS) se maintient en cas de perte de paquets. Le point de bascule exact varie selon la paquetisation et les conditions réseau ; utilisez cette colonne pour une comparaison relative, et non comme un chiffre précis.

**Recommandations de codecs pour Asterisk 22 :**

- **G.711 (ulaw/alaw) :** À utiliser pour les trunks PSTN et une interopérabilité maximale ; coût de transcodage nul au sein d'Asterisk.
- **G.729 :** Utile pour les trunks WAN à faible bande passante ; le module `codec_g729` de Sangoma est gratuit au téléchargement mais nécessite l'achat d'une licence par canal pour l'utilisation.
- **G.722 :** Bon choix pour la voix large bande (HD) sur les extensions LAN/internes ; même bande passante que le G.711 avec une meilleure qualité.
- **Opus :** Recommandé pour les endpoints modernes, les clients WebRTC et tout déploiement où l'endpoint le prend en charge. Débit binaire adaptatif, excellente résilience à la perte de paquets, disponible gratuitement via le module binaire `codec_opus` de Sangoma.

## Surcharge causée par les en-têtes de protocole

Malgré le fait que les codec utilisent peu de bande passante, nous devons prendre en compte la surcharge causée par les en-têtes de protocole tels qu'Ethernet, IP, UDP et RTP. Par conséquent, la bande passante réellement consommée dépend des en-têtes utilisés. Sur un réseau Ethernet, les besoins sont plus élevés que sur un réseau PPP, car l'en-tête PPP est plus court que celui d'Ethernet. Un seul paquet vocal G.729, par exemple, ne transporte que 20 octets de charge utile mais est encapsulé dans environ 58 octets d'en-têtes Ethernet, IP, UDP et RTP — ce sont donc les en-têtes, et non le codec, qui dominent la consommation de bande passante (voir la figure ci-dessous).

![Un seul paquet vocal G.729 sur Ethernet : 20 octets de charge utile encapsulés dans 58 octets d'en-têtes Ethernet, IP, UDP et RTP — une conversation G.729 consomme 31,2 Kbps.]((../images/06-voip-network-fig05.png))

- Ethernet (Ethernet+IP+UDP+RTP+G.711) = 95,2 Kbps
- PPP (PPP+IP+UDP+RTP+G.711) = 82,4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.711) = 82,8 Kbps

Codec G.729 (8 Kbps)

- Ethernet (Ethernet+IP+UDP+RTP+G.729) = 31,2 Kbps
- PPP (PPP+IP+UDP+RTP+G.729) = 26,4 Kbps
- Frame-Relay (FR+IP+UDP+RTP+G.729) = 26,8 Kbps

Vous pouvez facilement calculer d'autres besoins en bande passante en utilisant un calculateur de bande passante VoIP en ligne tel que <https://www.voip.school/bandcalc/bandcalc.php>.


## Ingénierie du trafic

Un problème majeur dans la conception des réseaux VoIP est le dimensionnement du nombre de lignes et de la bande passante requise vers une destination spécifique, comme un bureau distant ou un fournisseur de services. Il est également important de dimensionner le nombre d'appels simultanés d'Asterisk (paramètre principal pour le dimensionnement d'Asterisk).

### Simplifications

La simplification principale et la plus utilisée consiste à estimer le nombre d'appels par type d'utilisateur. Par exemple :

- PBX d'entreprise (un appel simultané pour cinq extensions)
- Utilisateurs résidentiels (un appel simultané pour seize utilisateurs)

Exemple n°1 Le siège social de l'entreprise dispose de 120 extensions et de deux succursales — la première avec 30 extensions et la seconde avec 15 extensions. Notre objectif est de dimensionner le nombre de trunks E1 au siège social et la bande passante requise pour le réseau Frame-Relay.

![Topologie réseau exemple (même ville) : le siège social avec 120 extensions se connecte au PSTN via des lignes T1, et à la succursale n°1 (30 extensions) et à la succursale n°2 (15 extensions) via un cloud Frame-Relay.]((../images/06-voip-network-fig06.png))

1a Nombre de lignes T1

- Nombre total d'extensions utilisant des lignes T1 : 120+30+15=165 lignes
- Utilisation d'un trunk pour chaque tranche de cinq extensions pour un usage professionnel
- Nombre total de lignes = 33 ou environ 2xT1 lignes

1b Besoins en bande passante Nous choisissons le codec g.729 en raison des besoins en bande passante, de la qualité sonore et d'une consommation CPU moyenne.

Avec un trunk pour chaque tranche de cinq extensions :

- Bande passante requise pour la succursale n°1 (Frame-relay) : 26.8*6=160.8 Kbps
- Bande passante requise pour la succursale n°2 (Frame-relay) : 26.8*3= 80.4 Kbps

### Méthode Erlang B

Lorsque vous disposez de données historiques, vous pouvez dimensionner le trunk de manière plus scientifique plutôt que par simplification. Nous utiliserons les travaux d'Agner Karup Erlang (Copenhagen Telephone Company, 1909), qui a développé une formule pour calculer le nombre de lignes dans un groupe de trunks entre deux villes.

Un **Erlang** est une unité de mesure du trafic courante en télécommunications ; elle décrit le volume de trafic pendant une heure. Par exemple, supposons que 20 appels se produisent en une heure, avec une moyenne de 5 minutes de conversation chacun :

- Minutes de trafic dans l'heure : 20 × 5 = 100 minutes
- Heures de trafic au sein d'une heure : 100 / 60 = **1.66 Erlangs**

Vous pouvez lire ces mesures à partir d'un journal d'appels et les utiliser pour concevoir votre réseau et calculer le nombre de lignes requises. Une fois le nombre de lignes connu, vous pouvez calculer les besoins en bande passante.

**Erlang B** est la méthode la plus couramment utilisée pour calculer le nombre de lignes dans un groupe de trunks. Elle suppose que les appels arrivent de manière aléatoire (distribution de Poisson) et que les appels bloqués sont immédiatement rejetés. Elle nécessite de connaître le **Busy Hour Traffic (BHT)**, que vous pouvez obtenir à partir d'un journal d'appels ou estimer par simplification : BHT = 17 % des minutes d'appel d'une journée.

![Résultats du calculateur Erlang B : 5 Erlangs avec 1 % de blocage nécessitent 11 lignes (siège social vers succursale n°1), et 2.83 Erlangs avec 1 % de blocage nécessitent 8 lignes (siège social vers succursale n°2).]((../images/06-voip-network-fig07.png))

Une autre variable importante est le Grade of Service (GoS), qui définit la probabilité de blocage des appels par manque de lignes. Vous pouvez arbitrer ce paramètre, qui est généralement de 0.05 (5 % d'appels perdus) ou 0.01 (1 % d'appels perdus). Exemple n°1 : En utilisant le même exemple du siège social et des deux succursales présenté plus tôt dans cette section, nous vous fournirons quelques données sur les modèles de trafic. À partir du journal d'appels, nous avons découvert ces données : Données du journal d'appels (Minutes d'appel et BHT) :

- Siège social vers succursale n°1 = 2 000 minutes, BHT = 300 minutes
- Siège social vers succursale n°2 = 1 000 minutes, BHT = 170 minutes
- Succursale n°1 vers succursale n°2 = 0, BHT=0

Arbitrons GoS=0.01

- Siège social vers succursale n°1 - BHT=300 minutes/60 = 5 Erlangs
- Siège social vers succursale n°2 – BHT=170 minutes/60 = 2.83 Erlangs

En utilisant un calculateur Erlang tel que <https://www.erlang.com>

- Pour le siège social vers la succursale n°1, 11 lignes sont requises.
- Pour le siège social vers la succursale n°2, 8 lignes sont requises

1.b Bande passante requise Nous utilisons un WAN où la perte de paquets est rare. Nous choisirons le codec g729 en raison de sa bonne qualité sonore et de sa compression de données (8 Kbps).

Codec sélectionné : g729 Couche liaison de données : Frame-Relay

- Bande passante vocale estimée pour la succursale n°1 : 26.8x11 = 294.8 Kbps
- Bande passante vocale estimée pour la succursale n°2 : 26.8x8 = 214.40 Kbps

## Réduction de la bande passante requise pour la VoIP

Trois méthodes peuvent être utilisées pour réduire la bande passante requise pour les appels VoIP :

- Compression d'en-tête RTP
- IAX Trunked
- Charge utile VoIP

### Compression d'en-tête RTP

Dans les réseaux Frame-Relay et PPP, vous pouvez utiliser la compression d'en-tête RTP. La compression d'en-tête RTP a été définie dans la RFC 2508. Il s'agit d'une norme IETF disponible dans plusieurs routeurs. Cependant, soyez prudent, car certains routeurs nécessitent un ensemble de fonctionnalités différent pour que cette ressource soit disponible. L'impact de l'utilisation de la compression d'en-tête RTP est fabuleux car il réduit la bande passante requise dans notre exemple de 26.8 Kbps par conversation vocale à 11.2 Kbps, soit une réduction de 58.2 % !

### Mode trunk IAX2

Si vous connectez deux serveurs Asterisk, vous pouvez utiliser le protocole IAX2 en mode trunk. Cette technologie révolutionnaire ne nécessite aucun routeur spécial et peut être appliquée à tout type de liaison de données.

![Mode trunk IAX2 sur Ethernet : un seul appel g.729 nécessite sa pile d'en-têtes complète (31.2 Kbps), mais un second appel partage ces en-têtes et n'ajoute qu'une petite miniframe IAX2, avec une moyenne d'environ 9.6 Kbps de bande passante supplémentaire par appel additionnel.](IAX2_trunk_mode.png)(../images/06-voip-network-fig08.png)

Le mode trunk IAX2 réutilise les mêmes en-têtes à partir du deuxième appel. En utilisant g729 sur une liaison PPP, le premier appel consommera 30 Kbps de bande passante, tandis que le second appel utilisera le même en-tête que le premier et réduira la bande passante nécessaire pour l'appel supplémentaire à 9.6 Kbps. Nous pouvons calculer la bande passante requise en mode trunk comme suit : Branche n°1 (11 appels) Bande passante = 31.2 + (11-1)* 9.6 Kbps = 127.2 Kbps Branche n°2 (8 appels) Bande passante = 31.2 + (8-1)* 9.6 Kbps = 98.4 Kbps Le premier appel utilise 31.2 Kbps, le suivant 9.6, et ainsi de suite.

### Augmentation de la charge utile vocale

Cette méthode est très courante lors de l'utilisation de passerelles VoIP sur Internet. En utilisant une charge utile plus importante, vous sacrifiez la latence au profit d'une bande passante réduite. Vous pouvez modifier la paquetisation RTP en ajoutant la taille de trame au codec dans l'instruction allow.

![Augmentation de la charge utile vocale : le regroupement de 60 octets de charge utile g.729 dans un paquet (au lieu de 20) amortit les 58 octets d'en-têtes sur plus de données vocales, réduisant la bande passante à environ 16.05 Kbps par appel au prix d'une latence accrue.](Increasing_payload.png)(../images/06-voip-network-fig09.png)

Exemple :

```
allow=ulaw:30
```

Le nombre après le deux-points est l'intervalle de paquetisation en millisecondes — la quantité de voix transportée dans chaque paquet RTP. Une valeur plus grande amortit la surcharge fixe de l'en-tête sur plus d'audio (moins de bande passante) au prix d'une latence accrue. Chaque codec a sa propre taille de trame minimale, maximale et par défaut ; G.711 (`ulaw`/`alaw`), par exemple, est réglé par défaut sur 20 ms.

## Résumé

Dans ce chapitre, vous avez appris qu'Asterisk traite la VoIP en utilisant des canaux. Il prend en charge SIP (via `chan_pjsip` dans Asterisk 22) et IAX2 ; H.323 n'est disponible que via le module complémentaire communautaire `ooh323`, et les anciens canaux MGCP et SCCP (Skinny) ne font plus partie d'une version standard d'Asterisk 22. Vous avez comparé et appris comment choisir un protocole de signalisation et un codec pour les canaux VoIP. IAX2 est plus efficace en termes de bande passante et peut traverser facilement le NAT. SIP/PJSIP est le protocole le plus pris en charge par les fournisseurs tiers de téléphones et de passerelles, et constitue le seul pilote de canal SIP dans Asterisk 22. Le protocole H.323 est le plus ancien et devrait être utilisé pour se connecter à des infrastructures VoIP héritées. Dans la section Ingénierie du trafic, nous avons appris à concevoir et à dimensionner un réseau VoIP.

## Quiz

1. Quels sont les avantages de la VoIP décrits dans ce chapitre (cochez toutes les réponses qui s'appliquent) ?
   - A. Convergence des réseaux de données et de voix pour réduire les coûts
   - B. Coût d'infrastructure réduit pour les ajouts, suppressions et modifications
   - C. Standards ouverts qui vous libèrent d'un fournisseur unique
   - D. Intégration téléphonie-informatique plus facile et moins coûteuse
   - E. Garantie de tarifs de communication à la minute inférieurs à ceux de n'importe quelle compagnie téléphonique
2. La convergence est l'intégration de la voix, des données et de la vidéo dans un réseau unique ; son principal avantage est la réduction des coûts liés à la mise en œuvre et à la maintenance de réseaux séparés.
   - A. Faux
   - B. Vrai
3. Asterisk traite chaque protocole VoIP comme un canal et peut ponter n'importe quel type de canal vers n'importe quel autre, en effectuant le transcodage entre les codec si nécessaire.
   - A. Faux
   - B. Vrai
4. Dans Asterisk 22, SIP est géré par quel pilote de canal ?
   - A. chan_sip
   - B. chan_pjsip
   - C. chan_skinny
   - D. chan_mgcp
5. Dans le modèle TCP/IP (IETF) sur lequel SIP est réellement défini dans la RFC 3261, les protocoles de signalisation SIP, H.323 et IAX2 fonctionnent au niveau de la couche ___.
   - A. Présentation
   - B. Application
   - C. Physique
   - D. Session
   - E. Liaison de données
6. SIP est le protocole le plus adopté pour les téléphones IP et est un standard ouvert largement défini par l'IETF dans la RFC 3261.
   - A. Faux
   - B. Vrai
7. IAX2 transporte à la fois la signalisation et les médias sur un seul port UDP, ce qui le rend efficace et facile à traverser le NAT. Quel port UDP IAX2 utilise-t-il ?
   - A. 5060
   - B. 1720
   - C. 4569
   - D. 5061
8. IAX a été développé à l'origine par Digium (maintenant Sangoma). Malgré une adoption limitée par les fabricants de téléphones, IAX est excellent lorsque vous avez besoin de (cochez toutes les réponses qui s'appliquent) :
   - A. Réduire l'utilisation de la bande passante (il n'utilise pas RTP)
   - B. Un format de média vidéo
   - C. Une traversée facile du NAT et des pare-feu
   - D. Un mode trunk pour combiner de nombreux appels Asterisk-à-Asterisk et amortir la surcharge des en-têtes
9. Dans Asterisk 22, un appareil est configuré comme un objet PJSIP `endpoint` unique qui passe et reçoit des appels — il n'y a pas de rôle "user" ou "peer" séparé.
   - A. Faux
   - B. Vrai
10. Concernant les codec dans Asterisk 22, cochez toutes les affirmations vraies :
    - A. G.711 est équivalent au PCM et utilise 64 Kbps de bande passante.
    - B. Le module codec_g729 de Sangoma est gratuit au téléchargement, mais son utilisation légale nécessite l'achat d'une licence par canal.
    - C. GSM est populaire car il utilise environ 13 Kbps et ne nécessite aucune licence.
    - D. G.711 u-law est courant en Amérique du Nord, tandis que a-law est courant en Europe et en Amérique latine.
    - E. G.729 est léger et utilise très peu de ressources CPU pour encoder et décoder par rapport au G.711.

**Réponses :** 1 — A, B, C, D · 2 — B · 3 — B · 4 — B · 5 — B (Application — SIP est un protocole de couche application dans le modèle TCP/IP utilisé par l'IETF) · 6 — B · 7 — C · 8 — A, C, D · 9 — B · 10 — A, B, C, D
