# SIP trunking, DID & the PSTN

Un PBX qui ne peut appeler que lui-même n'est pas très utile. Tôt ou tard, chaque système doit atteindre le reste du monde — le PSTN, un fournisseur SIP ou un autre PBX. Le lien qui transporte ces appels est un **trunk**. À l'ère du TDM, un trunk était un circuit physique : un PRI T1/E1 ou un faisceau de lignes analogiques FXO. Aujourd'hui, il s'agit presque toujours d'un **SIP trunk** — une connexion logique vers un ITSP transportée sur le même réseau IP que tout le reste.

Ce chapitre montre comment connecter Asterisk 22 à un ITSP avec PJSIP, comment choisir entre un trunk basé sur l'enregistrement et un trunk basé sur l'IP, comment acheminer les numéros DID entrants vers la bonne destination, comment envoyer des appels sortants avec un caller-ID correct et un formatage E.164, et comment mettre en place une bascule (failover) et un routage au moindre coût à travers plusieurs trunks. Nous terminerons par la gestion du NAT pour les trunks et un laboratoire qui met en place un second Asterisk (et SIPp) en tant qu'ITSP fictif afin que vous puissiez passer de vrais appels via un trunk.

Tout ce qui est présenté ici est vérifié avec le laboratoire Asterisk 22.10.0 du livre ; le modèle d'objet trunk est le même que celui introduit dans *Building your first PBX with PJSIP* et *SIP & PJSIP in depth*.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Connecter Asterisk 22 à un ITSP avec PJSIP
- Choisir entre des trunks basés sur l'enregistrement et des trunks basés sur IP (statiques)
- Acheminer les DID entrants vers la bonne extension, le bon IVR ou la bonne file d'attente
- Acheminer les appels sortants avec le bon caller-ID et un formatage E.164
- Mettre en place un basculement de trunk et un routage au moindre coût avec `${DIALSTATUS}`
- Gérer le NAT pour les trunks au niveau du transport et de l'endpoint

## Qu'est-ce qu'un trunk SIP

Un trunk SIP est un chemin vocal logique entre votre PBX et un autre système SIP. En pratique, cet « autre système » est l'un des deux éléments suivants :

- **Un ITSP (Internet Telephony Service Provider).** Un opérateur commercial qui vous vend l'origination et la terminaison d'appels et, généralement, un bloc de numéros de téléphone (DIDs). Vous pointez Asterisk vers l'hôte de signalisation du fournisseur, et le fournisseur connecte vos appels au réseau PSTN plus large. C'est ainsi que la plupart des systèmes modernes accèdent au réseau téléphonique — aucun matériel de téléphonie n'est requis.
- **Une passerelle PSTN.** Un appareil (ou un autre Asterisk) qui possède des interfaces PSTN physiques — une carte PRI, des ports FXO analogiques ou une passerelle GSM/4G — et les présente à votre PBX en tant que SIP. La passerelle effectue la conversion TDM-vers-SIP ; du point de vue d'Asterisk, il s'agit simplement d'un autre trunk SIP.

Quoi qu'il en soit, dans PJSIP, un trunk est **juste un endpoint**. La même famille d'objets que vous avez utilisée pour un téléphone — `endpoint`, `auth`, `aor`, éventuellement `identify` et `registration` — permet de construire un trunk. Les différences résident dans les détails : un trunk s'authentifie en *sortant* (vous êtes le client, donc les identifiants vont dans `outbound_auth`, pas dans `auth`), il n'enregistre généralement pas d'agent utilisateur auprès de vous (vous vous enregistrez auprès de *lui*, ou il vous envoie du trafic depuis une IP connue), et il fait aboutir les appels entrants dans un context dédié tel que `from-pstn` au lieu de `from-internal`.

> **Comparaison avec l'ancien trunk TDM.** Un PRI vous donnait un nombre fixe de canaux B (23 sur un T1, 30 sur un E1) et signalait l'établissement de l'appel via un canal D dédié (voir le chapitre *Legacy channels*). Un trunk SIP n'a pas de nombre de canaux fixe — la capacité est déterminée par votre bande passante, la politique de votre fournisseur et toute limite de `max_contacts`/appels simultanés. L'identification de l'appelant (Caller-ID), le DID et la progression de l'appel qui transitaient auparavant par des éléments d'information ISDN transitent désormais par des en-têtes SIP et SDP.

Il existe deux manières pour un ITSP d'accepter d'échanger du trafic avec vous, et elles déterminent la façon dont vous construisez le trunk : **basée sur l'enregistrement** et **basée sur l'IP (statique)**. Nous traitons chacune d'elles tour à tour.

## Trunks basés sur l'enregistrement

Un trunk basé sur l'enregistrement est le modèle utilisé lorsque le fournisseur attend que *vous* vous connectiez à *lui*. Votre Asterisk envoie périodiquement un SIP `REGISTER` au fournisseur, en s'authentifiant avec un nom d'utilisateur et un mot de passe, exactement de la même manière qu'un téléphone s'enregistre auprès de votre PBX. C'est une pratique courante lorsque votre IP publique est dynamique, lorsque vous êtes derrière un NAT, ou lorsque le fournisseur identifie simplement ses clients par des identifiants SIP plutôt que par adresse IP.

Dans PJSIP, la connexion sortante réside dans un objet `registration` dédié. Il remplace la ligne unique `register =>` que l'ancien pilote `chan_sip` utilisait dans `sip.conf`. Voici un trunk d'enregistrement complet vers un fournisseur fictif, suivant le modèle vérifié des chapitres précédents — notez `outbound_auth` (pas `auth`), `server_uri`/`client_uri` (pas `server`/`client`), `from_user`/`from_domain` sur l'endpoint, et `dtmf_mode=rfc4733` :

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-auth]
type=auth
auth_type=digest
username=4830001000
password=Lab-itsp-secret

[itsp-aor]
type=aor
contact=sip:itsp.example.com:5060

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:itsp.example.com:5060
client_uri=sip:4830001000@itsp.example.com:5060
contact_user=4830001000
retry_interval=60
```

Quelques points à noter :

- **`auth_type=digest`, pas `userpass`.** Les deux produisent la même authentification par condensat (digest), mais dans Asterisk 22, `userpass` (et l'ancien `md5`) sont **obsolètes et convertis silencieusement en `digest`**. Préférez `digest` dans les nouvelles configurations ; vous verrez toujours `userpass` dans les anciens fichiers et dans les chapitres précédents de ce livre.
- **`outbound_auth` à la fois sur l'endpoint et sur l'enregistrement.** L'enregistrement l'utilise pour authentifier le `REGISTER` ; l'endpoint l'utilise pour répondre au `407 Proxy Authentication Required` que le fournisseur renvoie vers un `INVITE` sortant. Ils peuvent partager un seul objet `auth`.
- **`from_user` / `from_domain`.** De nombreux fournisseurs rejettent les appels dont l'en-tête `From` ne contient pas votre numéro de compte et leur domaine. Ces deux options définissent exactement cela.
- **`contact_user=4830001000`.** Cela devient la partie utilisateur du `Contact` que vous enregistrez, afin que le fournisseur sache vers quel numéro acheminer les appels entrants. C'est l'équivalent moderne du suffixe `/9999` sur l'ancienne ligne `register =>`.
- **`retry_interval=60`.** Si l'enregistrement échoue, réessayez toutes les 60 secondes.

Après un rechargement, confirmez l'enregistrement avec `pjsip show registrations`. Dans le laboratoire — où `itsp.example.com` ne répond pas réellement — le tableau ressemble à ceci :

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

Le suffixe `(exp. Ns)` décompte les secondes jusqu'à la prochaine tentative ; une fois qu'il atteint zéro, il affiche brièvement `(exp. Ns ago)` avant que la nouvelle tentative ne soit déclenchée. Avec un fournisseur réel, la colonne `Status` affiche `Registered` avec les secondes restantes jusqu'au prochain rafraîchissement. `Rejected` (ou `Unregistered`) signifie que le fournisseur n'a pas accepté la connexion — activez `pjsip set logger on` et lisez la réponse `401`/`403`, presque toujours due à un nom d'utilisateur, un mot de passe ou un domaine `client_uri` incorrect.

## Trunks basés sur IP (statiques)

Le second modèle ne nécessite aucune inscription. Le fournisseur connaît votre adresse IP publique et y envoie les appels directement ; vous envoyez, à votre tour, les appels vers l'IP de signalisation connue du fournisseur. L'authentification se fait par **adresse IP source**, et non par des identifiants SIP. C'est le cas typique des trunks entre deux serveurs que vous contrôlez, ou pour un trunk d'entreprise où les deux parties disposent d'adresses statiques.

L'objet clé est `identify`. Il indique à Asterisk : "toute requête SIP arrivant de *cette* IP appartient à *cet* endpoint." Sans cela, PJSIP tente de faire correspondre une requête entrante à un endpoint via l'utilisateur `From`, ce que le trafic d'un opérateur ne satisfera pas — l'appel serait donc rejeté ou tomberait sur l'endpoint `anonymous`.

Un trunk statique supprime l'objet `registration` et ajoute `identify` :

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-aor]
type=aor
contact=sip:203.0.113.10:5060

[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
```

`match` accepte une adresse IP, une plage CIDR ou un nom d'hôte. **Les noms d'hôtes sont résolus une seule fois, au moment du chargement de la configuration**, donc si l'IP de votre fournisseur change, vous devez recharger. Pour un opérateur qui publie plusieurs passerelles média, listez chaque IP de signalisation — vous pouvez répéter `match` ou fournir un CIDR :

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

Vérifiez ce qu'Asterisk acceptera avec `pjsip show identifies`. Capturé depuis le laboratoire (la ligne `sipp-identify` est l'endpoint SIPp préexistant du laboratoire) :

```
*CLI> pjsip show identifies

 Identify:  <Identify/Endpoint...........................................................>
      Match:  <criteria...........................>
==========================================================================================

 Identify:  itsp-identify/itsp
      Match: 172.30.0.50/32

 Identify:  sipp-identify/sipp
      Match: 172.30.0.0/24

Objects found: 2
```

### L'implication en matière de sécurité

Un trunk basé sur IP sans authentification est une porte, et `identify`/`match` en est le seul verrou. Si vous `match` une plage trop large — ou si un attaquant peut usurper une IP source — les appels arrivent dans votre context `from-pstn` sans authentification. Deux défenses, utilisées conjointement :

- **Faites correspondre aussi étroitement que possible.** Préférez les IP d'hôtes spécifiques aux larges CIDR. Seules les véritables IP de signalisation du fournisseur doivent figurer dans `match`.
- **Associez-le à une ACL.** PJSIP peut rejeter le trafic au niveau de la couche SIP avant même qu'il n'atteigne un endpoint, en utilisant un objet `type=acl` (ou `acl.conf`) :

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

Une section `type=acl` ne nécessite aucune référence : `res_pjsip_acl` applique chaque objet de ce type à *tout* le trafic SIP entrant avant qu'il n'atteigne un quelconque endpoint. (Les options `acl` et `contact_acl` sur l'objet extraient des listes de règles nommées depuis `acl.conf` au lieu de lister `permit`/`deny` en ligne comme ci-dessus.) Le principe est le même que celui du chapitre sur le SIP : refusez tout, puis autorisez uniquement ce en quoi vous avez confiance. Et quel que soit le rôle de votre context de trunk, **ne le laissez jamais atteindre un context capable de rappeler vers le PSTN** sans une règle délibérée et authentifiée — c'est la faille classique de la fraude téléphonique.

> **Quel modèle dois-je utiliser ?** Si le fournisseur vous donne un nom d'utilisateur et un mot de passe, utilisez un trunk avec **registration**. S'ils vous demandent votre adresse IP et vous donnent la leur, utilisez un trunk avec **identify**. Certains fournisseurs prennent en charge les deux ; de nombreux trunks réels combinent une registration (pour que le fournisseur puisse vous trouver) avec un identify (pour que les INVITE entrants provenant des passerelles média du fournisseur soient reconnus même lorsqu'ils arrivent depuis une IP différente de celle du registrar).

## Routage entrant et gestion des DID

Une fois que les appels entrants arrivent, ils atterrissent dans le `context` de l'endpoint — ici `from-pstn`. Un **DID** (Direct Inward Dialing number) est simplement le numéro composé que le fournisseur vous transmet dans l'URI de requête. Votre travail dans le dialplan consiste à mapper chaque DID vers une destination : une extension unique, un IVR, une file d'attente ou un groupe d'appel.

Le numéro envoyé par le fournisseur est mis en correspondance en tant que `${EXTEN}` dans `from-pstn`. La portion que vous voyez dépend du fournisseur — certains envoient le numéro E.164 complet (`+4830001000`), certains envoient le numéro national, d'autres n'envoient que les derniers chiffres. Inspectez un appel entrant réel avec `pjsip set logger on` et examinez l'URI de requête avant d'écrire des modèles.

### Un DID vers une extension

Le cas le plus simple — un seul DID routé directement vers un téléphone :

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### Un DID vers un IVR (standard automatique)

Un numéro principal qui doit répondre avec un menu au lieu de faire sonner un téléphone :

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` est le context de standard automatique que vous avez construit dans les chapitres sur le dialplan (`Background()` + `WaitExten()`). Router le DID est simplement un `Goto`.

### Un DID vers une file d'attente

Une ligne de support qui doit aboutir dans une file d'attente d'appels :

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### Plusieurs DID à la fois

Lorsque vous achetez un bloc de numéros, un modèle permet de garder le dialplan concis. Supposons que votre plage de DID soit `4830003000`–`4830003099` et que le fournisseur envoie le numéro complet ; mappez les deux derniers chiffres de chaque DID vers l'extension `60xx` :

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}` prend les deux derniers chiffres (le décalage négatif compte à partir de la droite), donc `4830003007` fait sonner `PJSIP/6007`. Une table de recherche `did => extension` construite avec `GoSub` ou une base de données Asterisk (`AstDB`/`func_odbc`) permet une meilleure mise à l'échelle, mais pour une poignée de numéros, des modèles explicites sont plus clairs.

> **Capturez le DID non reconnu.** Ajoutez une extension `i` (invalide) au `from-pstn` afin qu'un numéro entrant mal routé joue une annonce ou fasse sonner l'opérateur au lieu de couper l'appel silencieusement :
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## Routage sortant, identifiant de l'appelant et E.164

Les appels sortants suivent le chemin inverse : un téléphone interne compose un numéro, votre dialplan le fait correspondre, supprime tout préfixe d'accès, définit l'identifiant de l'appelant attendu par le fournisseur et transmet l'appel à l'endpoint trunk avec `Dial(PJSIP/<number>@itsp)`.

### Envoi de l'appel vers le trunk

La syntaxe de canal pour un trunk est `PJSIP/<number>@<endpoint>` : la partie avant le `@` devient la portion utilisateur de l'URI de requête sortante, et la partie après le `@` nomme l'endpoint dont le `aor` `contact` fournit l'hôte de destination. Une règle classique de « composer le 9 pour une ligne extérieure » :

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` supprime le code d'accès `9` initial avant que le numéro ne soit envoyé. Le motif `_9NXXXXXXXXX` correspond à `9` plus un numéro à 10 chiffres dont le premier chiffre est compris entre 2 et 9 ; ajustez-le selon votre dialplan.

### Identifiant de l'appelant sur les appels sortants

La plupart des ITSP ignorent — ou rejettent activement — un identifiant d'appelant qui n'est pas un numéro dont vous êtes propriétaire. Définissez le numéro d'identifiant de l'appelant sortant sur l'un de vos DID avec la fonction `CALLERID(num)` avant `Dial()`, comme indiqué ci-dessus. Vous pouvez également définir le nom :

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

Si le fournisseur supprime ou remplace toujours votre nom d'identifiant d'appelant, c'est sa politique — de nombreux opérateurs tirent le nom affiché de leur propre base de données CNAM indexée sur le numéro, et non de votre en-tête `From`.

Deux options d'endpoint interagissent avec cela :

- **`from_user`** définit la partie utilisateur de l'en-tête `From` au niveau SIP, que certains fournisseurs utilisent pour identifier votre compte indépendamment de `CALLERID(num)`.
- **`trust_id_outbound`** (par défaut `no`) contrôle si Asterisk enverra des en-têtes d'identité sensibles à la confidentialité (`P-Asserted-Identity`/`P-Preferred-Identity`) en sortie. Laissez-le désactivé à moins que votre fournisseur ne documente qu'il souhaite PAI, auquel cas définissez `trust_id_outbound=yes` et `send_pai=yes`.

### Normalisation vers E.164

E.164 est le format de numéro international : un `+` initial, le code pays, puis le numéro national, sans espaces ni ponctuation (par exemple `+5548999990000` ou `+14155550100`). Les opérateurs attendent — ou exigent — de plus en plus le format E.164 sur le trunk. Plutôt que de disperser le formatage dans tout le dialplan, normalisez-le une fois dans le context sortant.

Un exemple nord-américain qui accepte un numéro local à 10 chiffres, un numéro à 11 chiffres préfixé par `1`, ou un numéro déjà au format E.164, et présente toujours `+1…` au trunk :

```
[from-internal]
; 10-digit local: 4155550100  -> +14155550100
exten => _NXXNXXXXXX,1,Set(E164=+1${EXTEN})
 same =>            n,Goto(send-pstn,${E164},1)

; 11-digit with national prefix: 14155550100 -> +14155550100
exten => _1NXXNXXXXXX,1,Set(E164=+${EXTEN})
 same =>             n,Goto(send-pstn,${E164},1)

; already E.164: the user dialled + first
exten => _+X.,1,Goto(send-pstn,${EXTEN},1)

[send-pstn]
exten => _+X.,1,Set(CALLERID(num)=+14155550000)
 same =>     n,Dial(PJSIP/${EXTEN}@itsp,60,tT)
 same =>     n,Hangup()
```

Certains fournisseurs veulent le `+` ; d'autres veulent uniquement les chiffres. Si le vôtre rejette le `+`, supprimez-le lors de l'envoi avec `${EXTEN:1}` dans le `Dial`. L'idée est que toute la connaissance du format réside au même endroit, de sorte que changer de fournisseur — ou en ajouter un second — ne nécessite qu'une modification sur une seule ligne.

## Basculement et routage au moindre coût

Avec un seul trunk, une panne du fournisseur signifie l'impossibilité d'émettre des appels sortants. Avec deux ou plus, vous pouvez basculer automatiquement et même choisir la route la moins chère par destination — le *routage au moindre coût* (LCR).

### Basculement avec `${DIALSTATUS}`

`Dial()` définit la variable de canal `${DIALSTATUS}` lorsqu'il se termine. Les valeurs qui vous intéressent pour le basculement sont `CHANUNAVAIL` (le trunk n'a pas pu être atteint du tout) et `CONGESTION` (l'appel a été rejeté, par exemple parce que tous les circuits sont occupés). Essayez le trunk principal ; s'il n'a pas pu acheminer l'appel, passez au secours :

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

Notez le choix délibéré de **ne pas** basculer sur `BUSY` ou `NOANSWER` — ceux-ci signifient que la *partie appelée* a été atteinte et a refusé l'appel, donc réessayer sur un autre trunk ferait sonner à nouveau un téléphone qui a déjà dit non (et pourrait vous coûter un second appel). Ne redirigez que lorsque le *trunk lui-même* a échoué.

### Une sous-routine de routage réutilisable

Répéter cette logique pour chaque modèle de numérotation est source d'erreurs. Factorisez-la dans une routine `GoSub` qui prend le numéro de destination et essaie chaque trunk dans l'ordre :

```
[from-internal]
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Set(CALLERID(num)=4830001000)
 same =>   n,Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try2:end)
 same =>   n(try2),Dial(PJSIP/${NUM}@itsp_backup,60,tT)
 same =>   n(try2-chk),GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try3:end)
 same =>   n(try3),Dial(PJSIP/${NUM}@itsp_thirdparty,60,tT)
 same =>   n(end),Return()
```

Désormais, chaque modèle sortant est un appel `GoSub`, et l'ordre des trunks est défini à un seul endroit.

### Routage au moindre coût par destination

Le véritable LCR choisit le trunk en fonction de la destination de l'appel. Une configuration courante consiste à faire correspondre le préfixe de destination et à envoyer chaque classe d'appel au fournisseur le moins cher pour celle-ci — par exemple, les appels internationaux vers un opérateur de gros et les appels locaux/nationaux vers votre trunk principal :

```
[from-internal]
; international (011 + ...) -> wholesale trunk, then fall back to primary
exten => _9011.,1,GoSub(dialout-intl,s,1(${EXTEN:1}))
 same =>      n,Hangup()
; everything else -> domestic routing
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout-intl]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Dial(PJSIP/${NUM}@itsp_wholesale,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?fb:end)
 same =>   n(fb),Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n(end),Return()
```

Pour plus de quelques préfixes, stockez la table de routage dans une base de données (`func_odbc`/`AstDB`) et recherchez le trunk par préfixe au lieu de coder les modèles en dur. Le dialplan reste léger et les tarifs résident dans une table que vous pouvez modifier sans recharger la logique.

## NAT et trunks

NAT est la cause la plus fréquente de problèmes avec les trunks — généralement de l'audio unidirectionnel, ou un trunk qui s'enregistre mais ne reçoit jamais d'appels entrants. La cause est la même que pour les téléphones (traitée dans *SIP & PJSIP in depth* et *Designing a VoIP network*) : Asterisk annonce sa propre idée de son adresse dans SIP et SDP, et derrière NAT, il s'agit d'une adresse privée RFC 1918 vers laquelle le fournisseur ne peut pas router le trafic.

Pour les trunks, la correction comporte deux volets : les paramètres sur le **transport** (votre adresse publique) et les paramètres sur l'**endpoint** (comment traiter les médias du fournisseur).

### Sur le transport — votre adresse publique

Lorsque le serveur Asterisk lui-même est derrière NAT (une machine dans le cloud ou sur site avec une IP privée et une IP publique 1:1), indiquez au transport son adresse publique et quels réseaux sont locaux. Ces options sont définies une fois, sur le `transport`, et s'appliquent à tout le trafic qui y transite :

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=172.30.0.0/24
local_net=10.0.0.0/8
external_media_address=203.0.113.50
external_signaling_address=203.0.113.50
```

- **`external_signaling_address`** — l'IP publique qu'Asterisk écrit dans les en-têtes SIP (`Via`, `Contact`) pour les destinations situées en dehors de `local_net`.
- **`external_media_address`** — l'IP publique qu'Asterisk écrit dans la ligne `c=` du SDP afin que le RTP revienne au bon endroit. Généralement identique à l'adresse de signalisation.
- **`local_net`** — les réseaux qu'Asterisk traite comme internes, afin qu'il ne réécrive *pas* les adresses pour les pairs sur le LAN. Listez chaque sous-réseau interne.

### Sur l'endpoint — les médias du fournisseur

L'autre moitié gère un fournisseur qui se trouve lui-même derrière NAT, ou qui envoie simplement des médias depuis une adresse différente de celle indiquée dans son SDP. Définissez ces paramètres par endpoint de trunk :

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com
```

- **`direct_media=no`** — maintenir le flux média à travers Asterisk plutôt que de laisser les deux segments communiquer directement. Essentiel à travers NAT, et requis de toute façon si vous souhaitez enregistrer, transcoder ou surveiller l'appel.
- **`rtp_symmetric=yes`** — le comportement classique *comedia* : renvoyer le RTP vers l'adresse d'où provient réellement le média, et non vers l'adresse revendiquée par le SDP.
- **`force_rport=yes`** — répondre au SIP depuis l'IP/port source de la requête (RFC 3581), au lieu de faire confiance à l'en-tête `Via`.
- **`rewrite_contact=yes`** — sur les messages SIP entrants provenant de cet endpoint, réécrire l'en-tête `Contact` (ou un en-tête `Record-Route` approprié) vers l'adresse IP et le port source d'où provient réellement le paquet. Selon la documentation de l'option elle-même, cela "aide les serveurs à communiquer avec des endpoints situés derrière des NAT" et "aide à réutiliser des connexions de transport fiables telles que TCP et TLS."

> **Recommandation — téléphones vs trunks.** `rewrite_contact` est presque toujours le bon choix pour les téléphones, car leur contact annoncé est généralement une adresse privée RFC 1918 qui n'est pas routable vers eux. Sur un trunk basé sur une IP statique, le contact du fournisseur est généralement déjà une adresse publique correcte, donc sa réécriture est souvent inutile ; certains opérateurs préfèrent la désactiver dans ce cas et ne l'activer que pour les trunks avec enregistrement et les téléphones derrière NAT. L'effet documenté de l'option est purement la réécriture `Contact`/`Record-Route` entrante mentionnée ci-dessus — la pratique prudente consiste donc à tester avec votre opérateur spécifique avant de l'activer sur un trunk statique.

Vous pouvez confirmer les paramètres effectifs sur n'importe quel endpoint avec `pjsip show endpoint <name>` — `direct_media`, `rtp_symmetric`, `force_rport`, `rewrite_contact`, et le reste sont tous imprimés dans le vidage des paramètres.

## Lab — un ITSP simulé avec un second Asterisk et SIPp

Vous n'avez pas besoin d'un trunk payant pour vous entraîner. Le labo du livre exécute déjà un conteneur Asterisk 22.10.0 et un conteneur SIPp sur un réseau privé `172.30.0.0/24` ; nous traiterons le conteneur SIPp comme le « transporteur » effectuant des appels entrants, et nous ajouterons un endpoint de trunk qui fait aboutir ces appels dans un context `from-pstn`.

![Un trunk SIP entre le PBX Asterisk et l'ITSP : le PBX s'enregistre comme un compte, les appels sortants composent `PJSIP/<num>@trunk`, et les appels entrants aboutissent dans le context `from-pstn`.](images/sip-trunk-lab.png){width=100%}(../images/09-sip-trunking-fig01.png)

### 1. Ajouter l'endpoint de trunk

Ajoutez un trunk basé sur IP à `lab/asterisk/etc/pjsip.conf` qui correspond à l'hôte SIPp du labo et fait aboutir les appels entrants dans `from-pstn` :

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor

[itsp-aor]
type=aor
contact=sip:172.30.0.50:5060

[itsp-identify]
type=identify
endpoint=itsp
match=172.30.0.50
```

### 2. Router le DID entrant

Dans `lab/asterisk/etc/extensions.conf`, ajoutez un context `from-pstn` qui répond au DID que le transporteur simulé composera et le joue, puis ajoutez une règle sortante :

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID ${EXTEN} from ${CALLERID(num)})
 same =>             n,Answer()
 same =>             n,Playback(demo-congrats)
 same =>             n,Hangup()
exten => i,1,Playback(ss-noservice)
 same =>  n,Hangup()

[from-internal]
; outbound across the trunk
exten => _9X.,1,Set(CALLERID(num)=4830001000)
 same =>     n,Dial(PJSIP/${EXTEN:1}@itsp,30,tT)
 same =>     n,Hangup()
```

Rechargez les deux fichiers (`core reload`) et vérifiez que le trunk est chargé :

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. Passer un appel entrant via le trunk

Pointez un scénario SIPp vers le PBX avec le DID comme utilisateur cible. Le labo fournit déjà `lab/sipp/uac_9000.xml`, qui envoie un INVITE vers l'extension `9000` ; copiez-le vers `uac_did.xml` et modifiez le request-URI/`To` utilisateur de `9000` vers `4830001000`, puis exécutez-le depuis le conteneur SIPp :

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

Observez l'appel atteindre `from-pstn` sur la console Asterisk (`pjsip set logger on` montre l'INVITE entrant ; `core show channels` montre le channel `PJSIP/itsp-…` jouant `demo-congrats`). Comme l'IP source SIPp correspond au `identify`, l'appel est accepté sans authentification — exactement comme se comporte un trunk transporteur statique.

### 4. Inspecter le trunk

Capturez la configuration complète du trunk pour vos notes :

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (Défi) en faire un trunk avec enregistrement

Mettez en place le *second* conteneur Asterisk comme un registrar réel : donnez-lui un `endpoint`+`auth`+`aor` pour le compte `4830001000`, puis sur le PBX, remplacez le bloc `identify` par le bloc `registration` du début de ce chapitre (en pointant `server_uri` vers l'IP du second conteneur). Confirmez avec `pjsip show registrations` que le statut indique `Registered`, puis passez un appel dans chaque direction.

## Résumé

Un trunk SIP connecte votre PBX au monde extérieur, et dans PJSIP, il s'agit simplement d'un endpoint construit à partir de la même famille `endpoint` + `auth` + `aor` que vous connaissez déjà, complétée par un `identify` ou un `registration`. Utilisez un **trunk avec enregistrement** (`type=registration` avec `outbound_auth`) lorsque le fournisseur vous fournit un nom d'utilisateur et un mot de passe ; utilisez un **trunk basé sur IP** (`type=identify` avec `match`) lorsque l'authentification se fait par IP source — et sécurisez ce dernier avec un `match` restreint et un `acl`, car un trunk sans authentification est une cible privilégiée pour la fraude téléphonique. En entrée, le DID du fournisseur arrive en tant que `${EXTEN}` dans votre context `from-pstn`, où vous le dirigez vers une extension, un IVR ou une file d'attente — les modèles et `${EXTEN:-N}` permettent de garder les blocs de DID compacts. En sortie, définissez `CALLERID(num)` sur un numéro dont vous êtes propriétaire, normalisez vers E.164 à un endroit unique, et transmettez l'appel à `PJSIP/<number>@trunk`. Renforcez la résilience en essayant plusieurs trunks et en utilisant des branchements sur `${DIALSTATUS}` (`CHANUNAVAIL`/`CONGESTION` signifient réacheminement ; `BUSY`/`NOANSWER` ne le font pas), et placez le routage au moindre coût dans une table `GoSub`. Enfin, le NAT pour les trunks est bidirectionnel : `external_media_address`/`external_signaling_address`/`local_net` sur le **transport** pour votre adresse publique, et `direct_media=no`, `rtp_symmetric`, `force_rport` et `rewrite_contact` sur l'**endpoint** pour les médias du fournisseur.

## Quiz

1. Dans PJSIP, les identifiants utilisés pour authentifier un appel *sortant* ou un enregistrement auprès d'un fournisseur sont référencés par :
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. Vous devriez utiliser un trunk `type=registration` lorsque :
   - A. Le fournisseur vous identifie par votre adresse IP source.
   - B. Le fournisseur vous donne un nom d'utilisateur et un mot de passe et attend que vous vous connectiez.
   - C. Vous ne voulez jamais qu'Asterisk envoie un `REGISTER`.
   - D. Le trunk se situe entre deux serveurs à IP statique que vous contrôlez.
3. L'option `match` de l'objet `identify` accepte (choisissez toutes les réponses qui s'appliquent) :
   - A. Une adresse IP
   - B. Une plage CIDR
   - C. Un nom d'hôte (résolu au moment du chargement de la configuration)
   - D. Un nom d'utilisateur SIP uniquement
4. Sur Asterisk 22, `auth_type=userpass` est :
   - A. La seule valeur valide
   - B. Obsolète et convertie en `digest`
   - C. Supprimée et provoque une erreur de chargement
   - D. Requise pour l'enregistrement sortant
5. Un numéro DID entrant arrive dans le dialplan en tant que :
   - A. `${CALLERID(num)}`
   - B. `${EXTEN}` dans le `context` de l'endpoint du trunk
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. Pour envoyer les deux derniers chiffres du DID composé `4830003007` vers une extension, vous utiliseriez :
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. Après `Dial()` vers un trunk, vous devriez basculer vers un trunk de secours sur lequel `${DIALSTATUS}` sont des valeurs (choisissez deux réponses) :
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. Pour définir le numéro d'identification de l'appelant (caller-ID) présenté au fournisseur avant de composer un numéro sortant, utilisez :
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. Les options qui indiquent à Asterisk son adresse *publique* lorsque le serveur est derrière un NAT sont définies sur le :
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. `rtp_symmetric=yes` sur un endpoint de type trunk amène Asterisk à :
    - A. Chiffrer le RTP avec SRTP
    - B. Renvoyer le RTP vers l'adresse d'où le média est réellement arrivé, en ignorant le SDP
    - C. Désactiver complètement le RTP
    - D. Forcer le média direct entre les endpoints

**Réponses :** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
