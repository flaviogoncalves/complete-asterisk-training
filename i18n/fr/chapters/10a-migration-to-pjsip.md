# Migration de chan_sip vers PJSIP : un guide pratique

Si vous lisez ceci avec un serveur Asterisk 13, 16 ou 18 toujours en production, vous avez une échéance. `chan_sip` — le pilote de canal SIP original configuré via `sip.conf` — a été **déprécié dans Asterisk 17, retiré de la compilation par défaut dans Asterisk 19, et entièrement supprimé dans Asterisk 21**. Il n'existe pas dans Asterisk 22 LTS. Il n'existe aucun indicateur pour le réactiver, aucune `noload` pour y échapper, aucun paquet à installer. Le seul pilote de canal SIP dans Asterisk 22 est **PJSIP** (`res_pjsip` plus `chan_pjsip`), configuré via `pjsip.conf`.

Ainsi, une mise à niveau vers Asterisk 22 est, pour la plupart des sites, un *projet de migration SIP* autant qu'une montée de version. La bonne nouvelle est que le protocole sur le réseau ne change pas — un téléphone qui s'enregistrait et appelait hier s'enregistrera et appellera demain — et Asterisk fournit un outil de conversion pour effectuer les 80 % initiaux de la traduction pour vous. Ce chapitre est un guide pratique : la correspondance des concepts, le script de conversion, les traductions côte à côte `sip.conf` → `pjsip.conf` pour les cas que vous rencontrez réellement, les changements dans le dialplan et la CLI qui accompagnent ce passage, la migration en realtime (base de données), ainsi qu'une liste de contrôle et les pièges courants.

Tout ce qui est présenté ici a été vérifié avec le laboratoire Asterisk 22.10.0 de ce livre. Le contenu détaillé sur l'héritage de `chan_sip` lui-même — ainsi qu'une conversion complète de bout en bout d'un `sip.conf` multi-périphérique — se trouve dans le chapitre *Legacy channels* ; ce chapitre en est le compagnon ciblé, sous forme de recettes.

## Objectifs

À la fin de ce chapitre, vous devriez être en mesure de :

- Expliquer pourquoi `chan_sip` a disparu dans Asterisk 22 et ce qui le remplace
- Faire correspondre le modèle peer/user/friend de `sip.conf` au modèle d'objet PJSIP
  (endpoint + aor + auth + identify + transport + registration)
- Exécuter le script de conversion `sip_to_pjsip.py` et examiner son résultat de manière critique
- Traduire manuellement les types de périphériques courants (téléphone avec enregistrement, trunk entrant, enregistrement sortant) de `sip.conf` vers `pjsip.conf`
- Migrer les paramètres NAT, média, DTMF, codec et authentification option par option
- Mettre à jour le dialplan (`SIP/` → `PJSIP/`) et le CLI (`sip show` → `pjsip show`)
- Migrer un déploiement realtime/ARA de `sippeers`/`sipregs` vers les tables Sorcery `ps_*`
- Suivre une liste de contrôle de migration et éviter les pièges classiques

## Pourquoi migrer

`chan_sip` a servi Asterisk pendant près de deux décennies, mais il comportait une dette architecturale : un module monolithique, un seul bloc de configuration par périphérique, une prise en charge limitée du multi-transport et une pile SIP qui avait pris du retard par rapport aux RFC. **PJSIP** — construit sur la pile mature pjproject de Teluu et introduit dans Asterisk 12 — a été le remplacement complet. Avec Asterisk 21, le projet Asterisk a terminé le travail et a supprimé `chan_sip` de l'arborescence.

Vous pouvez confirmer la situation sur n'importe quel système Asterisk 22 :

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip` renvoie *0 modules loaded* — il n'est tout simplement plus là. Il n'y a rien vers quoi migrer à part PJSIP, donc la seule vraie question est *comment*, et non *si*.

## La correspondance conceptuelle : il n'existe pas de « peer » unique

Le changement de mentalité qui piège tous ceux venant de `sip.conf` est le suivant : **PJSIP n'a pas de `[peer]`.** Dans `sip.conf`, un bloc entre crochets — un `peer`, un `user` ou un `friend` — décrivait *tout* ce qui concernait un appareil : ses identifiants, comment le joindre, ses codecs, son comportement NAT, son context de dialplan. PJSIP fragmente délibérément ce bloc unique en plusieurs objets plus petits, à usage unique, chacun étiqueté avec un `type=`, qui *se référencent mutuellement par leur nom* :

| Objet PJSIP (`type=`) | Responsabilité |
| --- | --- |
| `endpoint` | L'identité de gestion des appels de l'appareil : codecs, context, DTMF, média, NAT et références à ses `auth`/`aors`/`transport` |
| `aor` (Address of Record) | *Où* joindre l'appareil — contacts enregistrés ou statiques, `max_contacts`, qualify |
| `auth` | Identifiants (nom d'utilisateur/mot de passe) pour l'authentification entrante et/ou sortante |
| `identify` | Faire correspondre une requête entrante à un endpoint par **IP source** au lieu de l'utilisateur `From` |
| `transport` | Le(s) socket(s) d'écoute : protocole, adresse/port de liaison, NAT/adresses externes |
| `registration` | Un REGISTER **sortant** d'Asterisk vers un fournisseur |

La distinction `friend`/`peer`/`user` disparaît complètement — dans PJSIP, tout est un `endpoint`. Un seul friend `sip.conf` devient donc, typiquement, trois objets (`endpoint` + `auth` + `aor`) qui partagent un nom et pointent les uns vers les autres :

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

L'endpoint est le lien. Il nomme un `transport` (ou hérite de celui par défaut), un objet `auth` et un ou plusieurs `aors`. Le modèle d'objet est couvert en profondeur dans *SIP & PJSIP in depth* ; ici, nous en avons seulement besoin comme cible de chaque traduction.

## L'outil de conversion `sip_to_pjsip.py`

Asterisk est fourni avec un script Python qui lit un `sip.conf` existant et écrit un
`pjsip.conf`. Il ne s'exécute pas en tant que commande CLI — il réside dans l'**arborescence des sources d'Asterisk**, et non dans les binaires installés :

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Sur l'Asterisk 22.10.0 du laboratoire, le chemin complet est, par exemple,
`/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`. Le même répertoire contient `sip_to_pjsql.py` (la variante realtime/SQL, traitée plus loin) et
les modules d'assistance `astconfigparser.py`, `astdicts.py` et `sqlconfigparser.py`.

### Exécution

Le script accepte des arguments positionnels optionnels — `[input-file [output-file]]` —
qui utilisent par défaut `sip.conf` et `pjsip.conf` dans le répertoire courant :

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

Ses seules véritables options sont :

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

Il lit l'entrée, affiche `Converting to PJSIP...` et écrit le fichier de sortie.
En interne, il parcourt chaque section `sip.conf` et, pour chaque appareil, génère les objets correspondants
`endpoint`, `auth`, `aor`, `registration` et (là où il peut les déduire)
`transport`, en appliquant automatiquement les mappages d'options décrits dans la section suivante.

### Ce qu'il fait — et ses limites

Considérez la sortie comme un **premier jet, et non comme un fichier final.** Le script est transparent
sur ses propres lacunes : tout ce qu'il ne peut pas mapper proprement est écrit dans un bloc clairement délimité en haut du fichier de sortie :

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

Remarquez dans ce fragment réel que `qualify = yes` provenant d'un pair `sip.conf` a atterri dans le bloc *non mappé* — parce que PJSIP qualifie sur l'**aor** avec
`qualify_frequency` (en secondes), et non via un booléen sur l'appareil, le script vous laisse le soin de le définir délibérément. Les limitations pratiques à prévoir sont :

- **Les transports sont devinés, pas conçus.** Le script émet un `transport-udp` de base
  à partir de `bindport`/`bindaddr`, mais il ne peut pas connaître vos certificats TLS,
  vos besoins en TCP ou votre configuration multi-bind. Examinez et réécrivez le transport.
- **NAT et les adresses externes nécessitent une intervention humaine.** `externaddr`/`localnet` peuvent ne pas
  être convertis proprement ; confirmez `external_media_address`, `external_signaling_address`
  et `local_net` sur le transport manuellement.
- **`qualify`, les minuteurs personnalisés et une poignée d'options atterrissent dans la section "non-mapped".**
  Lisez ce bloc du début à la fin et prenez une décision pour chacun d'eux.
- **Les listes de codec, les contextes et la sécurité nécessitent une révision.** Vérifiez `disallow`/`allow`,
  le dialplan `context` et assurez-vous qu'aucun appareil n'est laissé ouvert par inadvertance.

Le flux de travail est donc le suivant : exécutez le script vers un fichier *temporaire*, comparez et examinez
le résultat, intégrez les bonnes parties dans votre `pjsip.conf` réel, puis testez de manière exhaustive avant la mise en production.

## Traductions côte à côte

Voici les recettes. `sip.conf` à gauche, l'équivalent `pjsip.conf` vérifié à droite (empilés ici pour des raisons de largeur de page). Chaque nom d'option et chaque valeur sur la droite ont été vérifiés avec le laboratoire Asterisk 22 via `config show help res_pjsip ...`.

### Un téléphone avec enregistrement (`host=dynamic`)

Le périphérique le plus courant : un téléphone de bureau ou un softphone qui se connecte avec un secret et enregistre sa propre localisation.

**Héritage `sip.conf` :**

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

**Asterisk 22 `pjsip.conf` :**

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

Changements clés : `host=dynamic` devient un `aor` avec `max_contacts` (le périphérique envoie un REGISTER pour renseigner son contact) ; `secret=` devient `password=` à l'intérieur d'un `type=auth` ; `qualify=yes` devient `qualify_frequency=60` (en secondes) sur l'**aor**, et non sur l'endpoint. Ne réglez `max_contacts` au-dessus de 1 que si vous souhaitez réellement utiliser le même compte sur plusieurs périphériques simultanément.

### Un trunk entrant (`host=<ip>` / `type=peer`)

Un fournisseur qui vous envoie des appels depuis une adresse IP connue. Il n'y a pas d'enregistrement ici — vous authentifiez le *trafic de l'opérateur par son IP source* en utilisant `identify`.

**Héritage `sip.conf` :**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf` :**

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

La traduction cruciale est **`insecure=invite` → `identify`**. Dans `chan_sip`, `insecure=invite` indiquait à Asterisk de "ne pas contester les INVITE entrants provenant de ce pair pour l'authentification". PJSIP obtient le même effet en *faisant correspondre l'IP source à l'endpoint* avec `type=identify`/`match=`, ce qui est à la fois plus explicite et plus sécurisé. Le `host=` statique devient un `contact=` permanent sur l'`aor` afin que vous puissiez également appeler *vers l'extérieur* via l'opérateur. `match=` accepte une IP, une plage CIDR ou un nom d'hôte (résolu au moment du chargement de la configuration — rechargez si l'IP du fournisseur change).

### Un enregistrement sortant (`register =>`)

Lorsque le fournisseur souhaite que *vous* vous connectiez à *eux*, `chan_sip` utilisait une seule ligne `register =>` dans `[general]`. PJSIP la remplace par un objet `type=registration` dédié ainsi qu'un `outbound_auth`.

**Héritage `sip.conf` :**

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

**Asterisk 22 `pjsip.conf` :**

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

Faites correspondre les champs `register =>` un par un : les identifiants `1020:supersecret` deviennent l'objet `auth` (référencé en tant que `outbound_auth`) ; `@sip.example.com:5600` devient le `server_uri` ; le suffixe `/9999` — la partie utilisateur vers laquelle le fournisseur achemine les appels entrants — devient `contact_user=9999`. `defaultuser`/`fromuser` et `fromdomain` deviennent `from_user` et `from_domain` sur l'endpoint. Notez que `outbound_auth` apparaît *deux fois* : l'enregistrement l'utilise pour le REGISTER, l'endpoint l'utilise pour répondre au défi `407` sur les INVITE sortants.

## Référence de migration option par option

Lorsque vous effectuez une traduction manuelle (ou que vous auditez la sortie du script), ce tableau sert de référence. Chaque nom d'option PJSIP et son emplacement (endpoint / aor / auth / transport) ont été vérifiés avec un laboratoire Asterisk 22.

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | Emplacement |
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

### Une note sur `secret` → `auth` et `auth_type`

Le `secret=` de `chan_sip` devient le champ `password=` d'un objet `type=auth`. La **méthode d'authentification** est définie avec `auth_type`. Utilisez `auth_type=digest`. Les anciennes valeurs `userpass` et `md5` fonctionnent toujours mais sont **obsolètes et converties silencieusement en `digest`** — vérifié directement depuis le laboratoire :

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

Vous verrez `auth_type=userpass` dans les anciennes configurations et dans la sortie du script de conversion (ainsi que dans les chapitres précédents de ce livre). C'est sans danger, mais écrivez `digest` pour tout ce qui est nouveau.

### NAT, médias et DTMF en détail

Ces trois éléments sont à l'origine de la plupart des tickets post-migration du type « l'enregistrement fonctionne mais il n'y a pas d'audio ». Le raccourci `chan_sip` de `nat=force_rport,comedia` regroupait trois comportements en une seule option ; PJSIP les sépare afin que vous puissiez raisonner sur chacun d'eux :

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

Pour les **médias**, `directmedia` devient `direct_media` (le soulignement est le seul changement) ; gardez `direct_media=no` chaque fois que l'appel doit être ancré sur Asterisk — à travers un NAT, ou pour enregistrer/transcoder/transférer. Pour le **DTMF**, la RFC a été renumérotée : le `dtmfmode=rfc2833` de `chan_sip` est le `dtmf_mode=rfc4733` de PJSIP (même mécanisme out-of-band telephone-event, numéro de RFC actuel). Le laboratoire confirme que les valeurs valides pour `dtmf_mode` sont `rfc4733`, `inband`, `info`, `auto` et `auto_info`, avec `rfc4733` par défaut.

Pour les **codecs**, rien ne change : `disallow=all` suivi de `allow=ulaw` (etc.) utilise la syntaxe identique sur l'endpoint PJSIP.

## Modifications du dialplan et de la CLI

La migration ne s'arrête pas à `pjsip.conf`. Deux éléments utilisés quotidiennement changent.

### Chaînes de canaux : `SIP/` → `PJSIP/`

Chaque `Dial()` et référence de canal dans le `extensions.conf` qui nommait l'ancienne
technologie doit être mis à jour :

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Les chaînes de numérotation des trunk suivent le même modèle — `Dial(SIP/${EXTEN}@itsp)` devient
`Dial(PJSIP/${EXTEN}@itsp)`. PJSIP ajoute également la fonction `PJSIP_DIAL_CONTACTS()`
pour appeler simultanément tous les contacts liés à un AOR, ainsi que les fonctions de dialplan `PJSIP_HEADER()` /
`PJSIP_MEDIA_OFFER()` ; utilisez grep sur votre dialplan pour trouver les références SIP `SIP/`,
`SIPPEER`, `SIPCHANINFO` et `CHANNEL(...)` et traduisez chacune d'entre elles.

### CLI : `sip show ...` → `pjsip show ...`

L'intégralité de l'arborescence des commandes `sip ...` a disparu avec le pilote. Voici les remplacements :

| Commande `chan_sip` | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (ou `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (ou `core reload`) |

Les anciennes commandes ne se comportent pas simplement différemment — elles n'existent plus. En laboratoire, `sip show peers` renvoie *No such command*, tandis que `pjsip show endpoints`,
`pjsip show aors`, `pjsip show auths`, `pjsip show contacts`,
`pjsip show registrations` et `pjsip show identifies` sont toutes présentes. La commande de dépannage la plus
utile — l'enregistreur de paquets SIP qui affichait chaque message
avec `sip set debug` — est désormais **`pjsip set logger on`** (avec `pjsip set logger
host <ip>` pour se concentrer sur un pair spécifique).

## Migration vers Realtime (ARA)

Si vous utilisiez `chan_sip` à partir d'une base de données (Asterisk Realtime Architecture), vos périphériques résidaient dans la table `sippeers` et les enregistrements dans `sipregs`. PJSIP utilise une couche de stockage complètement différente — **Sorcery** — avec une table *par type d'objet*. Voici la correspondance :

| Table realtime `chan_sip` | Table(s) PJSIP / Sorcery |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (une ligne par table, séparées) |
| `sipregs` | `ps_contacts` (enregistrements dynamiques) |
| — (`register=>` sortant) | `ps_registrations` |
| — (correspondance IP) | `ps_endpoint_id_ips` (les objets `identify`) |
| — (alias de domaine) | `ps_domain_aliases` |

La séparation conceptuelle est la même que pour le cas des fichiers plats : une ligne `sippeers` devient *trois* lignes dans trois tables (`ps_endpoints` + `ps_aors` + `ps_auths`) qui se référencent mutuellement par le nom de l'endpoint.

Deux éléments rendent cette opération réalisable :

- **Le schéma est généré pour vous.** Asterisk fournit des migrations Alembic sous `contrib/ast-db-manage/` qui créent chaque table `ps_*`. Exécutez `alembic upgrade head` sur la base de données `config` pour construire le schéma PJSIP actuel plutôt que d'écrire le DDL à la main.
- **Il existe un script de conversion SQL.** Aux côtés de `sip_to_pjsip.py` se trouve **`sip_to_pjsql.py`** dans le même répertoire `contrib/scripts/sip_to_pjsip/` ; il réutilise la même logique `convert()` mais génère un fichier `pjsip.sql` contenant des instructions `INSERT` pour les tables `ps_*` au lieu d'un fichier de configuration plat. Comme pour l'outil de fichier plat, examinez la sortie avant de la charger.

Enfin, pointez `sorcery.conf` vers votre base de données afin que PJSIP lise les endpoints, aors, auths et contacts depuis les tables `ps_*` (via `res_config_odbc` / `res_pjsip_realtime`), exactement comme `extconfig.conf` pointait autrefois `sippeers` vers la base de données pour `chan_sip`. Les mécanismes de Realtime sont couverts dans le chapitre *Realtime* ; le point spécifique à la migration est simplement de savoir *quelle table correspond à quelle autre*.

## Liste de contrôle pour la migration

Un ordre d'opérations pragmatique pour une mise en production :

1. **Inventaire.** Listez chaque appareil, trunk et `register =>` dans `sip.conf` (ou chaque ligne `sippeers`/`sipregs`). Notez les paramètres personnalisés de NAT, codec et DTMF.
2. **Exécutez le convertisseur vers un fichier temporaire.** `sip_to_pjsip.py sip.conf pjsip_generated.conf`. Ne le pointez **pas** vers votre `pjsip.conf` en production.
3. **Lisez le bloc "Non mapped elements"** en haut de la sortie et résolvez chaque ligne — en particulier `qualify`, les minuteurs et tout ce qui concerne le NAT.
4. **Concevez le(s) transport(s) manuellement.** Un transport par IP/port ; ajoutez TLS/TCP si nécessaire ; configurez `external_*_address` et `local_net` pour les serveurs cloud/NAT.
5. **Vérifiez l'authentification.** Confirmez `auth_type=digest`, les noms d'utilisateur et les mots de passe sur chaque objet `auth`.
6. **Vérifiez NAT/media/DTMF.** `force_rport`/`rewrite_contact`/`rtp_symmetric`, `direct_media`, `dtmf_mode=rfc4733` par endpoint selon les besoins.
7. **Mettez à jour le dialplan.** `SIP/` → `PJSIP/` partout ; vérifiez les fonctions `SIP*` et les variables de canal.
8. **Mettez à jour les scripts et la surveillance.** Tout outil ou consommateur AMI qui analysait la sortie de `sip show ...` doit passer à `pjsip show ...` / actions AMI PJSIP.
9. **Rechargez et vérifiez.** `module reload res_pjsip.so`, puis `pjsip show endpoints`, `pjsip show registrations`, `pjsip show identifies`.
10. **Testez avec l'enregistreur de paquets.** `pjsip set logger on` ; effectuez un enregistrement, un appel entrant et un appel sortant, puis lisez l'échange SIP de bout en bout.

## Pièges courants

- **`alwaysauthreject` est désormais intégré — ne le cherchez pas.** `chan_sip` nécessitait
  `alwaysauthreject=yes` afin de ne pas divulguer l'existence d'extensions en répondant
  différemment aux noms d'utilisateurs invalides. PJSIP adopte une approche sécurisée par conception : il ne révèle jamais si un endpoint existe. Il n'y a aucune option `alwaysauthreject` à
  configurer. La protection associée — la limitation du débit des expéditeurs non identifiés — est gérée par les paramètres globaux
  `unidentified_request_count` / `unidentified_request_period`, activés par défaut.

- **`insecure=invite` n'est pas une option PJSIP — utilisez `identify`.** Il n'existe pas de
  `insecure=` dans `pjsip.conf`. La méthode pour accepter des INVITE non authentifiés provenant d'un opérateur connu consiste à *identifier l'endpoint par son IP source* avec `type=identify` /
  `match=`. Effectuez une correspondance aussi précise que possible (adresses IP d'hôtes spécifiques, et non de larges CIDR), et sécurisez-la avec un `type=acl` — un trunk correspondant à une IP sans authentification est une cible privilégiée pour la fraude téléphonique.

- **Un seul transport par IP/port.** Vous ne pouvez pas lier deux transports à la même combinaison IP:port, et vous ne pouvez pas lier plusieurs transports TCP ou TLS de la même version IP. Le script de conversion peut générer un transport qui entre en conflit avec un transport existant — consolidez le tout vers une couche de transport unique et délibérément conçue.

- **`qualify=yes` ne se traduit pas par un booléen.** Il appartient à l'objet **aor** sous le nom
  `qualify_frequency=<seconds>`. Le convertisseur place `qualify=yes` dans le
  bloc non mappé précisément parce qu'il n'existe aucun booléen équivalent sur l'endpoint.

- **`secret=` n'est pas une option d'endpoint.** Les identifiants résident uniquement dans un objet `type=auth`
  auquel l'endpoint fait *référence* (`auth=` pour les appels entrants, `outbound_auth=` pour les
  appels sortants). Placer un mot de passe sur l'endpoint ne sert à rien.

- **L'interface CLI et tous les scripts de récupération échouent silencieusement.** `sip show ...` renvoie "No such command", et non une erreur que votre système de surveillance détectera nécessairement. Auditez chaque tâche cron, vérification Nagios et client AMI pour les commandes `sip ` avant la mise en service.

## Résumé

Migrer vers Asterisk 22 signifie abandonner `chan_sip`, car le pilote a été supprimé dans Asterisk 21 et PJSIP est le seul canal SIP restant. Le cœur du travail consiste à réexprimer chaque `sip.conf` `peer`/`user`/`friend` — qui regroupait tout dans un seul bloc — sous la forme d'un ensemble d'objets PJSIP coopérants : un `endpoint` ainsi qu'un `auth`, un `aor` et, selon le périphérique, un `identify` (trunk entrant), un `registration` (identifiant sortant) et un `transport` partagé. Le script `sip_to_pjsip.py` situé dans `contrib/scripts/sip_to_pjsip/` effectue la majeure partie de la traduction et signale honnêtement ce qu'il ne peut pas mapper dans un bloc "Non mapped elements", mais sa sortie n'est qu'une première ébauche : concevez le transport, le NAT et la sécurité manuellement et testez avant la mise en production. Autour de la configuration, mettez à jour le dialplan (`SIP/` → `PJSIP/`) ainsi que vos doigts et vos scripts (`sip show` → `pjsip show`, `sip set debug` → `pjsip set logger`). Les déploiements realtime passent de `sippeers`/`sipregs` aux tables Sorcery `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts`, avec l'aide de `sip_to_pjsql.py` et du schéma `contrib/ast-db-manage`. Surveillez les pièges — `alwaysauthreject` est intégré, `insecure=invite` devient `identify`, `qualify=yes` devient `qualify_frequency`, et un seul transport par IP/port — et le basculement sera mécanique plutôt que mystérieux.

## Quiz

1. Pourquoi un déploiement Asterisk 22 doit-il utiliser PJSIP pour le SIP ?
   - A. `chan_sip` est plus lent mais toujours disponible
   - B. `chan_sip` a été supprimé dans Asterisk 21 et n'existe pas dans Asterisk 22
   - C. PJSIP est la valeur par défaut mais `chan_sip` peut être chargé avec `modules.conf`
   - D. `chan_sip` ne fonctionne qu'avec TLS dans Asterisk 22

2. Un seul bloc `sip.conf` `type=friend` devient le plus souvent quel ensemble d'objets PJSIP ?
   - A. Un seul `type=peer`
   - B. `type=endpoint` uniquement
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. Dans `sip.conf`, `host=dynamic` (l'appareil enregistre sa propre localisation) correspond à :
   - A. `type=identify` avec `match=dynamic`
   - B. un `type=aor` avec `max_contacts` (l'appareil envoie un REGISTER)
   - C. `direct_media=yes` sur l'endpoint
   - D. `type=registration`

4. Le script de conversion `sip_to_pjsip.py` est :
   - A. Une commande CLI : `asterisk -rx 'sip_to_pjsip'`
   - B. Un script Python dans l'arborescence source d'Asterisk sous `contrib/scripts/sip_to_pjsip/`
   - C. Un module compilé chargé au démarrage
   - D. Une partie de `res_pjsip.so`

5. Vrai ou Faux : La sortie de `sip_to_pjsip.py` est prête pour la production et doit être chargée sans révision.

6. Le raccourci `chan_sip` `nat=force_rport,comedia` se traduit sur un endpoint PJSIP par quelles trois options ?
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. Le `dtmfmode=rfc2833` de `sip.conf` devient quel paramètre PJSIP ?
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. Sur Asterisk 22, un objet `auth` doit utiliser quel `auth_type`, et quel est le statut de `userpass` ?
   - A. `auth_type=userpass` ; c'est la seule valeur valide
   - B. `auth_type=digest` ; `userpass` est obsolète et converti en `digest`
   - C. `auth_type=md5` ; `digest` est obsolète
   - D. `auth_type=plaintext` ; `digest` a été supprimé

9. Un pair fournisseur `chan_sip` avec `insecure=invite` (accepter les INVITE non authentifiés depuis une IP connue) est migré vers PJSIP en utilisant :
   - A. `insecure=invite` sur l'endpoint
   - B. `allowguest=yes` dans `[global]`
   - C. un objet `type=identify` avec `match=<provider IP>`
   - D. `auth_type=anonymous`

10. Dans une migration realtime, la table `chan_sip` `sippeers` est remplacée par quelles tables PJSIP/Sorcery ?
    - A. Une seule table `pjsip_peers`
    - B. `ps_endpoints`, `ps_aors` et `ps_auths`
    - C. `sipregs` et `voicemail`
    - D. `ps_contacts` uniquement

**Réponses :** 1 — B · 2 — C · 3 — B · 4 — B · 5 — Faux · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
