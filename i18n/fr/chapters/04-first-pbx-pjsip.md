# Création de votre premier PBX avec PJSIP

Dans ce chapitre, vous apprendrez à effectuer une configuration de base d'un PBX Asterisk. L'objectif principal ici est de voir le PBX fonctionner pour la première fois, d'être capable de composer des numéros entre des extension, de composer un numéro pour écouter un message, et de composer vers un trunk analogique ou SIP unique. L'idée derrière ce chapitre est de s'assurer que votre Asterisk est opérationnel le plus rapidement possible. Après avoir terminé le travail de ce chapitre, vous disposerez des bases suffisantes pour préparer les chapitres suivants, où nous approfondirons les détails de configuration.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Comprendre et modifier les fichiers de configuration ;
- Installer des softphones basés sur SIP ;
- Installer et configurer un trunk SIP ;
- Installer et configurer une connexion analogique ;
- Appeler entre des extensions ;
- Appeler entre des téléphones et des destinations externes ; et
- Configurer un standard automatique (IVR).

## Compréhension des fichiers de configuration

Asterisk est contrôlé par des fichiers de configuration textuels situés dans /etc/asterisk. Le format de fichier est similaire aux fichiers « .ini » de Windows. Un point-virgule est utilisé comme caractère de commentaire, les signes « = » et « => » sont équivalents, et les espaces sont ignorés.

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asterisk interprète « = » et « => » de la même manière. Les différences de syntaxe sont utilisées pour distinguer les objets des variables. Utilisez « = » lorsque vous souhaitez déclarer une variable et « => » pour désigner un objet. La syntaxe est identique entre tous les fichiers, mais trois types de grammaire sont utilisés, comme discuté ci-dessous.

## Grammars

| Grammaire | Comment l'objet est créé | Fichier de conf. | Exemple |
|---------|---------------------------|------------|---------|
| Groupe simple | Tout sur la même ligne | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| Héritage d'options | Les options sont définies d'abord, l'objet hérite des options | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| Entité complexe | Chaque entité reçoit un context | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### Groupe simple

Le format de groupe simple utilisé dans `extensions.conf` et `voicemail.conf` est la grammaire la plus basique. Chaque objet est déclaré avec ses options sur la même ligne. Exemple :

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

Dans cet exemple, l'objet 1 est créé avec les options op1, op2 et op3, tandis que l'objet 2 est créé avec les options op1, op2 et op3.

### Grammaire d'héritage d'options d'objet

Ce format est utilisé par les fichiers chan_dahdi.conf et agents.conf, où de nombreuses options sont disponibles et où la plupart des interfaces et objets partagent les mêmes options. Typiquement, une ou plusieurs sections contiennent des déclarations d'objets et de canaux. Les options de l'objet sont déclarées au-dessus de l'objet et peuvent être modifiées pour un autre objet. Bien que ce concept soit difficile à comprendre, il est très facile à utiliser. Exemple :

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

Les deux premières lignes configurent la valeur des options op1 et op2 sur « bas » et « adv », respectivement. Lorsque l'objet 1 est instancié, il est créé en utilisant l'option 1 comme « bas » et l'option 2 comme « adv ». Après avoir défini l'objet 1, nous changeons l'option 1 en « int ». Ensuite, nous créons l'objet 2 avec l'option 1 comme « int » et l'option 2 comme « adv ».

### Objet d'entité complexe

Ce format est utilisé par pjsip.conf, iax.conf et d'autres fichiers de configuration dans lesquels existent de nombreuses entités avec beaucoup d'options. Typiquement, ce format ne partage pas un grand volume de configurations communes. Chaque entité reçoit un context. Parfois, des contexts réservés existent, comme [general] pour les configurations globales. Les options sont déclarées dans les déclarations de context. Exemple :

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

L'entité [entity1] a les valeurs « value1 » et « value2 » pour les options op1 et op2, respectivement. L'entité [entity2] a les valeurs « value3 » et « value4 » pour les options op1 et op2.

## Options pour construire un LAB pour Asterisk

Pour configurer un PBX, vous aurez besoin de matériel de base. Ce n'est ni difficile ni coûteux, mais il y a quelques options à prendre en considération. Tout ce dont vous aurez besoin, ce sont deux téléphones et une connexion au réseau public. Plusieurs options et combinaisons sont possibles lors de la création de votre lab, dont nous discuterons ci-dessous.

### Option 1 : LAB complet

Avec le LAB complet, il est possible de tester tous les scénarios disponibles et de comparer des solutions telles que les ATA, les IP-phones et les softphones. Vous pouvez également en apprendre davantage sur les trunks analogiques et SIP. Vous aurez besoin de :

- Un adaptateur téléphonique analogique (ATA) SIP
- Un IP phone
- Un serveur dédié pour Asterisk
- Une station de travail avec un softphone
- Une carte d'interface analogique avec au moins deux interfaces (1 FXO et 1 FXS)
- Un compte auprès d'un fournisseur VoIP

### Option 2 : LAB économique

Avec le LAB économique, nous simplifions un peu les choses. Nous utilisons l'ATA, qui est généralement moins coûteux que l'IP-phone, et une seule carte FXO, qui est vraiment peu coûteuse. Nous ne pourrons pas utiliser de téléphones analogiques connectés directement au serveur, mais cela n'arrive pas couramment en pratique. Vous aurez besoin de :

- Un adaptateur téléphonique analogique (ATA) SIP
- Un serveur dédié pour Asterisk
- Une station de travail pour le softphone
- Une carte d'interface analogique avec 1 FXO
- Un compte auprès d'un fournisseur VoIP

### Option 3 : LAB super économique

Le troisième LAB utilise un serveur virtualisé sur le propre ordinateur portable de l'étudiant. Le problème avec ce modèle réside dans les conflits générés par le port UDP. Parfois, le serveur Asterisk et le softphone tentent d'accéder au même port, empêchant Asterisk de lier le port d'adresse. Un autre problème est la qualité des appels ; les environnements virtuels ne sont pas indiqués pour les applications en temps réel telles qu'Asterisk. Utilisez un softphone gratuit pour le serveur et la station de travail, ainsi qu'une connexion trunk vers un fournisseur SIP. Vous aurez besoin de :

- Un ordinateur portable exécutant un softphone
- Une machine virtuelle (VirtualBox, VMware ou similaire) pour installer Asterisk
- Un compte auprès d'un fournisseur VoIP

## Séquence d'installation

Pour vous aider à comprendre la séquence d'installation, nous avons décrit les étapes nécessaires pour installer et configurer Asterisk.

![Disposition du laboratoire de référence : softphones SIP/IAX, un téléphone IP et des adaptateurs analogiques en tant qu'extensions (1), le serveur Asterisk avec des interfaces ETH0/FXO/FXS (3), et les trunks vers le PSTN via un fournisseur VoIP ou une liaison haut débit (2).](../images/04-first-pbx-fig01.png)

1. Configuration des extensions
   - a. Extensions SIP (ATA, softphone, téléphone IP)
   - b. Extensions IAX
   - c. Extensions FXS
2. Configuration des trunks
   - a. Configuration d'un trunk SIP
   - b. Configuration d'un trunk FXO
3. Construction d'un dialplan de base
   - a. Appel entre extensions
   - b. Appel vers des destinations externes
   - c. Réception d'un appel sur l'extension de l'opérateur
   - d. Réception d'un appel via un IVR

## Configuration des extensions

Les extensions sont des téléphones SIP, IAX ou analogiques connectés à un port FXS. Pour configurer une extension, vous devez modifier le fichier de configuration associé au canal (pjsip.conf, iax.conf, chan_dahdi.conf).

### Extensions SIP

Sur Asterisk 22, PJSIP (la pile `res_pjsip`, configurée dans `/etc/asterisk/pjsip.conf`) est le pilote de canal SIP. Il prend en charge plusieurs transports par endpoint, est activement maintenu et est le seul pilote SIP fourni avec la plateforme. (Le pilote original `chan_sip` a été supprimé dans Asterisk 21 — consultez le chapitre *Legacy channels* si vous devez migrer une ancienne configuration.)

L'idée ici est de configurer un PBX simple. (Les chapitres suivants fourniront une session SIP/PJSIP complète avec tous les détails.) PJSIP est configuré dans `/etc/asterisk/pjsip.conf` et contient tous les paramètres relatifs aux téléphones SIP et aux fournisseurs VoIP. Les clients SIP doivent être configurés avant de pouvoir passer et recevoir des appels.

#### Le transport

Dans PJSIP, la configuration de l'écouteur (adresse de liaison, port, protocole) réside dans un objet `transport`. Asterisk dispose d'une protection intégrée contre la devinette de noms d'utilisateur — il renvoie toujours un défi d'authentification identique pour les utilisateurs inconnus et connus, et les requêtes non identifiées répétées provenant d'une même IP sont limitées en débit via les options `[global]` `unidentified_request_count`/`unidentified_request_period`. Les principales options d'un transport sont :

- protocol : Le protocole de transport — `udp`, `tcp`, `tls`, `ws` ou `wss`.
- bind : L'adresse et le port sur lesquels l'écouteur se lie. Si vous définissez l'adresse sur `0.0.0.0`, il se lie à toutes les interfaces ; le port SIP par défaut est 5060 pour UDP/TCP.

Un transport UDP minimal :

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

La sélection des codec (`disallow`/`allow`) et le `context` par défaut sont configurés sur chaque `endpoint` (illustré ci-dessous), et non sur le transport. Les appels anonymes/invités sont gérés par un `endpoint` nommé `anonymous`. Les temporisateurs d'enregistrement sont contrôlés par AOR via `maximum_expiration`/`default_expiration`.

#### Clients SIP

Après avoir terminé la section transport, il est temps de configurer les clients SIP. Je tiens à rappeler une fois de plus au lecteur que nous aurons un chapitre entier sur SIP/PJSIP plus tard dans le livre. Pour l'instant, concentrons-nous sur les bases et laissons les détails pour plus tard.

Dans PJSIP, un client SIP est construit à partir d'un ensemble d'objets liés, reliés entre eux par une référence de nom :

- `endpoint` : Le comportement d'appel — les codec (`allow`/`disallow`), le dialplan `context`, et quels `auth` et `aors` il utilise.
- `auth` : Les identifiants. `username` est l'utilisateur d'authentification SIP et `password` est le secret utilisé pour authentifier l'appareil.
- `aor` : L'« adresse d'enregistrement » (AOR) — où l'endpoint peut être joint. Soit un `contact=` statique (pour un appareil à une IP fixe), soit `max_contacts=` pour permettre à l'appareil de s'enregistrer dynamiquement.

Attention : Utilisez des mots de passe forts, d'au moins 8 caractères, composés de caractères alphanumériques et numériques, et d'au moins un symbole. Des rapports de serveurs piratés sont apparus sur les listes de diffusion, et des outils de craquage de mots de passe par force brute pour SIP sont facilement disponibles pour les script kiddies. La fraude téléphonique coûte des milliers de dollars aux consommateurs et aux fournisseurs.

L'endpoint 6000 est un appareil à une IP fixe, donc son AOR porte un `contact` statique au lieu de permettre l'enregistrement. L'endpoint 6001 est un appareil qui s'enregistre, donc son AOR lui permet de s'enregistrer (`max_contacts=1`) :

```
[6000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6000-auth
aors=6000

[6000-auth]
type=auth
auth_type=digest
username=6000
password=#MySecret1#7

[6000]
type=aor
contact=sip:6000@10.1.30.50

[6001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6001-auth
aors=6001

[6001-auth]
type=auth
auth_type=digest
username=6001
password=Mys3cr3t#

[6001]
type=aor
max_contacts=1
```

PJSIP permet aux sections `endpoint`, `auth` et `aor` de partager le même nom de section (par exemple, les deux blocs `[6001]` ci-dessus, distingués par leur `type=`) ; de nombreux administrateurs les suffixent plutôt (`[6001]`, `[6001-auth]`, `[6001]` aor) pour la lisibilité. Pour un appareil qui s'enregistre, le contact est appris dynamiquement lorsque le téléphone s'enregistre, donc l'AOR n'a pas besoin de `contact` statique.

## Extensions IAX

`chan_iax2` est toujours fourni avec Asterisk 22 mais est désormais considéré comme hérité ; SIP/PJSIP est le protocole privilégié pour les nouveaux déploiements.

Vous pouvez également créer des extensions IAX. Ce protocole est natif à Asterisk, et nous lui consacrerons une section entière plus loin dans ce livre. Pour l'instant, créons quelques extensions en utilisant ce protocole. En tant que première section à configurer, la section [general] possède certains paramètres à définir. Les options principales sont :

- allow/disallow : Définit quels codec seront utilisés.
- bindaddr : Adresse sur laquelle le listener IAX2 se lie. Si vous la configurez sur 0.0.0.0 (par défaut), il se liera à toutes les interfaces.
- context : Définit le context par défaut pour tous les clients, sauf s'il est modifié dans la section client. Nous avons utilisé dummy pour des raisons de sécurité. Les utilisateurs non authentifiés accèdent à ce context lorsque l'option allowguest est définie sur yes.
- bindport : Port UDP IAX2 sur lequel écouter (par défaut 4569).
- delayreject : Lorsqu'il est défini sur yes, retarde l'envoi d'un rejet d'authentification pour une requête REGREQ ou AUTHREQ, ce qui améliore la sécurité contre les attaques par force brute sur les mots de passe.
- bandwidth : Lorsqu'il est défini sur high, il permet la sélection de codec à large bande passante, tels que le g711 dans leurs variantes ulaw et alaw.

Voici un exemple de la section [general] du fichier iax.conf.

```
[general]
bindport = 4569
bindaddr = 10.1.30.45 ;(use your IP)
context = dummy
delayreject=yes
bandwidth=high
disallow = all
allow = ulaw
```

### Clients IAX

Après avoir terminé les sections générales, il est temps de configurer les clients IAX.

- `[name]` : Le nom de la section est le nom du peer/user IAX ; une connexion IAX entrante lui est associée par son nom.
- `type` : La classe de connexion — `peer`, `user`, ou `friend` :
  - `peer` : Asterisk envoie des appels vers un peer.
  - `user` : Asterisk reçoit des appels d'un user.
  - `friend` : les deux directions à la fois.
  - `host` : Adresse IP ou nom d'hôte. La valeur la plus courante est `dynamic`, utilisée lorsque l'appareil s'enregistre auprès d'Asterisk.
  - `secret` : Mot de passe pour authentifier les peers et les users.

Avertissement : Utilisez des mots de passe robustes d'au moins 8 caractères, comprenant des caractères alphanumériques et numériques, ainsi qu'au moins un symbole. Des rapports de serveurs piratés sont apparus sur les listes de diffusion, et des outils de craquage de mots de passe par force brute pour les hash md5 IAX sont disponibles pour les script kiddies. La fraude aux appels coûte des milliers de dollars aux consommateurs et aux fournisseurs. Exemple :

```
[guest]
type=user
context=dummy
callerid="Guest IAX User"
[6003]
type=friend
context=from-internal
secret=#sup3rs3cr3t#
host=dynamic
[6004]
type=friend
context=from-internal
secret=#s3cr3ts3cr3t#
host=dynamic
```

## Configuration des périphériques SIP

Après avoir défini les téléphones dans le fichier de configuration Asterisk, il est temps de configurer le téléphone lui-même. Dans cet exemple, nous montrerons comment configurer un softphone gratuit — le SipPulse Softphone (téléchargez-le depuis https://www.sippulse.com/produtos/softphone). Consultez le manuel de votre appareil pour comprendre les paramètres de votre téléphone. Étape 1 : Configurez le téléphone pour utiliser l'extension 6000. Exécutez le programme d'installation. Après l'exécution, ouvrez les paramètres de compte/SIP et ajoutez un nouveau compte SIP. Remplissez les informations requises.

![L'écran de compte du SipPulse Softphone — saisissez le Server (votre IP Asterisk ou domaine), Username, Password et Display Name, puis choisissez le Transport (UDP, TCP ou TLS).](../images/softphone/sipphone-account.png){width=35%}

Display Name : 6000  User Name : 6000  Password : #MySecret1#7  Authorization User Name : 6000  Domain : ip_of_your_server. Confirmez que votre téléphone est enregistré en utilisant la commande de console `pjsip show endpoints` (ou `pjsip show endpoint 6000` pour plus de détails ; `pjsip show contacts` affiche les contacts AOR enregistrés). Répétez la configuration pour le téléphone 6001.

![Un SipPulse Softphone enregistré — le point vert et la ligne de compte (`1001@softphone.sippulse.com.br`) confirment l'enregistrement ; passez un appel depuis le pavé numérique ou les boutons d'appel/vidéo.](../images/softphone/sipphone-registered.png){width=35%}

## Configuration des périphériques IAX

IAX2 est un protocole hérité (voir le chapitre *Legacy channels*), et le Softphone SipPulse est uniquement SIP, il ne peut donc pas enregistrer un compte IAX. Si vous avez besoin de tester IAX2, utilisez un softphone qui le prend encore en charge. Créez un nouveau compte IAX,

3. Sélectionnez un nouveau compte IAX.
4. Insérez les options correspondantes pour le téléphone 6003 et éventuellement pour le 6004.
5. Enregistrez la configuration et vérifiez si le téléphone est enregistré en utilisant `iax2 show peers`.

Important : Utilisez un compte pour SIP et un autre pour IAX. Si vous souhaitez configurer le système pour faire sonner à la fois IAX et SIP en même temps, nous vous montrerons comment faire dans la section sur le dialplan.

### Configuration d'une interface PSTN

Pour vous connecter au PSTN, vous aurez besoin d'une interface de bureau d'échange étranger (FXO) et d'une ligne téléphonique. Vous pouvez également utiliser une extension PBX existante. Vous pouvez obtenir une carte d'interface de téléphonie avec une interface FXO auprès de plusieurs fabricants. Dans cet exemple, nous vous montrerons comment installer une carte d'interface DAHDI.

![Ports FXS et FXO : le port FXS pilote un téléphone analogique (fournit la tonalité et la sonnerie), tandis que le port FXO connecte Asterisk à la ligne Telco.]((../images/04-first-pbx-fig02.png))

### Lignes analogiques utilisant DAHDI

Vous pouvez acheter une carte analogique compatible avec DAHDI auprès de plusieurs fabricants. La X100P était l'une des premières cartes Digium et a déjà été abandonnée. Certains fabricants produisent encore des clones similaires. En plus du prix de la X100P, nous avons constaté plusieurs problèmes entre ces cartes et les nouvelles cartes mères, utilisez-la donc avec précaution. La X100P, à mon avis, n'est pas un bon choix pour un environnement de production. Toute carte compatible avec DAHDI devrait fonctionner. Grâce à l'équipe de développeurs DAHDI, nous disposons désormais d'un outil pour détecter et configurer les cartes d'interface presque automatiquement. Si vous venez d'installer les pilotes DAHDI, n'oubliez pas d'exécuter make config et de redémarrer la machine pour les charger automatiquement. Vous pouvez utiliser les commandes ci-dessous pour détecter et configurer votre carte. Étape 1 : Pour détecter votre matériel, utilisez :

```
dahdi_hardware
```

Étape 2 : Pour configurer, utilisez :

```
dahdi_genconf
```

La commande ci-dessus générera deux fichiers /etc/dahdi/system.conf et /etc/asterisk/dahdi-channels.conf. Les paramètres par défaut de dahdi_genconf sont généralement corrects, mais vous pouvez les modifier dans le fichier /etc/dahdi/genconf_parameters. Par défaut, il insérera les lignes (FXO) dans le context from-pstn et les téléphones (FXS) dans le context from-internal. Étape 3 : Après avoir exécuté dahdi_genconf, dans la dernière ligne du fichier /etc/asterisk/chan_dahdi.conf, insérez la ligne suivante :

```
#include dahdi-channels.conf
```

Étape 4 : Modifiez le fichier /etc/dahdi/modules et commentez tous les pilotes inutilisés. Redémarrez avant de continuer et vérifiez si les canaux sont reconnus en utilisant :

```
*CLI> dahdi show channels
```

### Connexion au PSTN via un fournisseur VoIP

Si votre budget est vraiment limité, vous pouvez configurer un trunk SIP pour vous connecter au PSTN. C'est certainement le moyen le plus abordable de se connecter au PSTN. Des milliers de fournisseurs VoIP existent dans le monde entier. Pour vous connecter à l'un d'eux, vous aurez besoin de certains paramètres. Paramètres fournis par le fournisseur SIP.

- username : login
- password : secret
- Domaine du fournisseur : domain
- Port UDP : 5060
- Codecs autorisés : g729, ilbc, alaw

Deux paramètres doivent être déterminés par vous.

- Extension pour recevoir les appels — dans ce cas : 9999
- context : from-sip

Dans PJSIP, un trunk SIP avec enregistrement est construit à partir de la même famille d'objets utilisée pour un endpoint, plus des objets explicites `registration` et `identify`. L'objet `registration` indique à Asterisk de s'enregistrer auprès du fournisseur, l'objet `identify` fait correspondre le trafic entrant de l'IP du fournisseur à l'endpoint (PJSIP authentifie les INVITE entrants par IP source), et `outbound_auth` fournit les identifiants pour les appels sortants et l'enregistrement :

```
[siptrunk]
type=endpoint
context=from-sip
disallow=all
allow=ilbc
allow=alaw
allow=g729
dtmf_mode=rfc4733
outbound_auth=siptrunk-auth
aors=siptrunk
from_user=login
from_domain=domain

[siptrunk-auth]
type=auth
auth_type=digest
username=login
password=secret

[siptrunk]
type=aor
contact=sip:domain:5060

[siptrunk]
type=identify
endpoint=siptrunk
match=domain

[siptrunk-reg]
type=registration
transport=transport-udp
outbound_auth=siptrunk-auth
server_uri=sip:domain:5060
client_uri=sip:login@domain:5060
contact_user=9999
retry_interval=60
```

Pour accéder à ce trunk, nous utiliserons le nom de canal `PJSIP/siptrunk`. Le paramètre `dtmf_mode=rfc4733` transporte le DTMF hors bande (RFC 4733 remplace l'ancienne RFC 2833 ; la charge utile est identique). L'option `identify`/`match` accepte des adresses IP, des CIDR ou des noms d'hôte, mais les noms d'hôte sont résolus une seule fois au moment du chargement de la configuration ; pour un fournisseur avec des IP changeantes, listez explicitement la ou les IP de signalisation. Confirmez l'enregistrement avec `pjsip show registrations`.

## Introduction au dialplan

Le dialplan est comme le cœur d'Asterisk. Il définit la manière dont Asterisk gère chaque appel vers le PBX. Il se compose d'extensions qui forment une liste d'instructions qu'Asterisk doit suivre. Les instructions sont déclenchées par des chiffres reçus depuis le canal ou l'application. Afin de configurer Asterisk avec succès, il est crucial de comprendre le dialplan. La majeure partie du dialplan est contenue dans le fichier extensions.conf situé dans le répertoire /etc/asterisk. Ce fichier utilise une grammaire de groupe simple et repose sur quatre concepts majeurs :

- Extensions
- Priorities
- Applications
- Contexts

Créons un dialplan de base. Dans les sections suivantes de ce livre, je consacrerai un chapitre exclusivement au dialplan. Si vous avez installé les fichiers d'exemple (make samples), le fichier extensions.conf existe déjà. Enregistrez-le sous un autre nom et commencez avec un fichier vide.

## La structure du fichier extensions.conf

Le fichier extensions.conf est divisé en sections. La première est la section [general] suivie de la section [globals]. Le début de chaque section commence par la définition de son nom (par exemple, [default]) et se termine lorsqu'une autre section est créée.

### La section [general]

La section general se situe en haut du fichier. Avant de commencer à configurer le dialplan, il est utile de connaître les options générales qui contrôlent certains comportements du dialplan. Ces options sont :

- static et write protect : Si `static=yes` et `writeprotect=no`, vous pouvez enregistrer le dialplan en cours d'exécution sur le disque avec la commande CLI :

```
*CLI> dialplan save
```

Avertissement : Si vous exécutez une commande `dialplan save` depuis la CLI, vous perdrez toutes les remarques et commentaires présents dans le fichier.

- autofallthrough : Si autofallthrough est activé, alors si une extension n'a plus d'instructions à exécuter, elle terminera l'appel avec BUSY, CONGESTION ou HANGUP selon la meilleure estimation d'Asterisk. C'est le comportement par défaut. Si autofallthrough n'est pas activé, alors si une extension n'a plus d'instructions à exécuter, Asterisk attendra qu'une nouvelle extension soit composée.
- clearglobalvars : Si clearglobalvars est activé, les variables globales seront effacées et réanalysées lors d'un dialplan reload ou d'un Asterisk reload. Si clearglobalvars n'est pas activé, alors les variables globales persisteront après les rechargements et — même si elles sont supprimées du fichier extensions.conf ou de l'un de ses fichiers inclus — elles resteront définies à leur valeur précédente.
- extenpatternmatchnew : Utilise un algorithme de correspondance de motifs plus rapide, ce qui aide sensiblement lorsque vous avez un grand nombre d'extensions. La valeur par défaut est no.
- userscontext : Il s'agit du context où les entrées provenant de users.conf sont enregistrées.

### La section [globals]

Dans la section [globals], vous définirez les variables globales et leurs valeurs initiales. Vous pouvez accéder à la variable dans le dialplan en utilisant ${GLOBAL(variable)}. Vous pouvez même accéder aux variables définies dans l'environnement linux/unix en utilisant ${ENV(variable)}. Les variables globales ne sont pas sensibles à la casse. Voici quelques exemples :

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

Dans l'exemple suivant, vous pouvez définir et tester une variable globale dans le dialplan.

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Un context est une partition nommée du dialplan. Après les sections [general] et [globals], le dialplan est un ensemble de contexts dans lequel chaque context possède plusieurs extensions, chaque extension possède plusieurs priorités, et chaque priorité appelle une application avec plusieurs arguments.

![Flux d'appel Asterisk : chaque appel arrive sur un canal (IAX, SIP, et autres) en tant que branche d'appel entrante ; le context du canal — défini globalement ou par canal dans le fichier de configuration du canal — décide quel context dans extensions.conf traite l'appel avant qu'il ne reparte sur la branche sortante.](images/call-flow.png){width=100%}(../images/04-first-pbx-fig03.png)

![Traitement des appels : le `context=` défini pour un canal (dans chan_dahdi.conf ou pjsip.conf) nomme le context correspondant dans extensions.conf où le dialplan gère l'appel.](images/call-processing.png){width=100%}(../images/04-first-pbx-fig04.png)

Vous pouvez construire un dialplan simple pour joindre d'autres téléphones et le PSTN. Cependant, Asterisk est bien plus puissant que cela. Notre objectif est de vous enseigner davantage de détails sur ce qui est possible dans le dialplan.

## Extensions

Contrairement au PBX traditionnel, où les extensions sont associées à des téléphones, des interfaces, des menus, etc., dans Asterisk, une extension est une liste de commandes à traiter lorsqu'un numéro ou un nom d'extension spécifique est déclenché. Les commandes sont traitées par ordre de priorité.

![Syntaxe des extensions : `exten => number(name),{priority|label}[(alias)],application`. Les extensions peuvent être numériques, alphanumériques, numériques avec identifiant d'appelant, un motif, ou une extension standard comme `s` ; les priorités peuvent être un nombre, `n` (suivant), `s` (identique), un décalage, ou un `hint`.](../images/04-first-pbx-fig05.png)

Une extension peut être littérale, standard ou spéciale. Une extension standard comprend uniquement des chiffres ou des noms et les caractères * et # ; 12#89* est une extension littérale valide. Les noms peuvent également être utilisés pour la correspondance d'extension. Les extensions sont sensibles à la casse. Cependant, vous ne pouvez pas créer deux extensions avec le même nom mais des casses différentes. Lorsqu'une extension est composée, la commande avec la première priorité est exécutée, suivie de la commande avec la priorité 2, et ainsi de suite. Cela se produit jusqu'à ce que l'appel soit déconnecté ou qu'une commande renvoie le numéro un, indiquant un échec. Ce qu'Asterisk fait lorsque la dernière priorité est exécutée est régulé par le paramètre autofallthrough. Voir la section [general] dans ce chapitre. Exemple :

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

Ci-dessus, vous trouverez la liste des instructions à traiter lorsque l'extension 123 est composée. La première priorité est de répondre au canal (nécessaire lorsque le canal est dans l'état de sonnerie : par exemple, les canaux FXO). La deuxième priorité est de lire un fichier audio appelé tt-weasels. La troisième priorité raccroche le canal. Une autre option consiste à gérer l'appel en fonction de l'identifiant de l'appelant. Vous pouvez utiliser le caractère / pour spécifier l'identifiant de l'appelant à traiter. Exemples :

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

Cet exemple déclenchera l'extension 123 et exécutera les options suivantes uniquement si l'identifiant de l'appelant est 100. Cela peut également être fait en utilisant le motif décrit ci-dessous :

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint : mappe une extension à un canal. Il est utilisé pour surveiller l'état du canal. Il est utilisé conjointement avec la présence. Le téléphone doit le prendre en charge.

#### Motifs

Vous pouvez utiliser des motifs et des littéraux dans le dialplan. Les motifs sont très utiles pour réduire la taille du dialplan. Tous les motifs commencent par le caractère « _ ». Les caractères suivants peuvent être utilisés pour définir un motif. La figure identifie les motifs disponibles pour une utilisation avec Asterisk.

![Caractères de correspondance de motifs : `_` démarre un motif, `.` correspond à un ou plusieurs caractères, `!` correspond à zéro ou plusieurs, `[123-7]` correspond à n'importe quel chiffre ou plage listé, `X` est 0-9, `Z` est 1-9, et `N` est 2-9 — avec des exemples mappant des plages d'extensions de bureau.](../images/04-first-pbx-fig06.png)

### Extensions spéciales

Asterisk utilise certains noms d'extensions comme extensions standard.

![Extensions spéciales d'Asterisk : `i` (invalide), `s` (démarrage), `h` (raccrocher), `t` (délai d'attente), `T` (délai d'attente absolu), `o` (opérateur), `a` (appuyé sur `*` dans la voicemail), `fax` (détection de fax), et `Talk` (utilisé avec BackgroundDetect).](../images/04-first-pbx-fig07.png)

Description :

- **s** : Start (Démarrage). Utilisé pour gérer un appel lorsqu'il n'y a pas de numéro composé. C'est utile pour les trunks FXO et le traitement au sein des menus.
- **t** : Timeout (Délai d'attente). Utilisé lorsque les appels restent inactifs après la lecture d'une invite. Il est également utilisé pour raccrocher une ligne inactive.
- **T** : AbsoluteTimeout (Délai d'attente absolu). Si vous établissez une limite d'appel en utilisant la fonction de dialplan `TIMEOUT(absolute)`, une fois que l'appel dépasse la limite définie, il sera envoyé vers l'extension T.
- **h** : Hangup (Raccrocher). Appelé après que l'utilisateur a déconnecté l'appel.
- **i** : Invalid (Invalide). Déclenché lorsque vous appelez une extension inexistante dans le context. L'utilisation de ces extensions peut affecter le contenu des enregistrements CDR — spécifiquement, le dst qui ne contient pas le numéro composé.
- **o** : Operator (Opérateur). Utilisé pour aller vers l'opérateur lorsque l'utilisateur appuie sur « 0 » pendant la voicemail.

L'utilisation de ces extensions peut modifier le contenu des enregistrements de facturation (CDR) — en particulier, le champ dst n'aura pas le numéro composé. Pour contourner ce problème, vous devez utiliser l'option g dans l'application dial() et envisager les fonctions resetcdr(w) et/ou nocdr().

## Variables

Dans le PBX Asterisk, les variables peuvent être globales, spécifiques à un canal ou spécifiques à l'environnement. Vous pouvez utiliser l'application NoOP() pour voir le contenu d'une variable dans la console. Elle peut utiliser une variable globale ou une variable spécifique à un canal comme arguments d'application. Une variable peut être référencée comme dans l'exemple suivant, où varname est le nom de la variable.

```
${varname}
```

Un nom de variable peut être une chaîne alphanumérique commençant par une lettre. Les noms de variables globales ne sont pas sensibles à la casse. Cependant, les variables système (définies par Asterisk ou définies par le canal) sont sensibles à la casse. Ainsi, la variable ${EXTEN} est différente de ${exten}.

### Variables globales

Les variables globales peuvent être configurées dans la section [global] du fichier extensions.conf ou en utilisant l'application :

```
set(Global(variable)=content)
```

### Variables spécifiques à un canal

Les variables spécifiques à un canal sont configurées en utilisant l'application set(). Chaque canal reçoit son propre espace de variables. Il n'y a aucun risque de collision entre les variables de différents canaux. Une variable spécifique à un canal est détruite lorsque le canal est raccroché. Certaines des variables les plus couramment utilisées sont :

- ${EXTEN} Extension composée
- ${CONTEXT} Contexte actuel
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} Identifiant de l'appelant actuel
- ${PRIORITY} Priorité actuelle

Les autres variables spécifiques à un canal sont toutes en majuscules. Vous pouvez voir le contenu de plusieurs variables en utilisant l'application dumpchan(). Voici un simple extrait des variables de dump-channel.

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Sortie de dumpchan :

```
Dumping Info For Channel: PJSIP/4400-00000001:
================================================================================
Info:
Name=               PJSIP/4400-00000001
Type=               PJSIP
UniqueID=           1161186526.1
LinkedID=           1161186526.0
CallerIDNum=        4400
CallerIDName=       laptop
ConnectedLineIDNum= (N/A)
ConnectedLineIDName=(N/A)
DNIDDigits=         9001
RDNIS=              (N/A)
Parkinglot=
Language=           en
State=              Ring (4)
Rings=              0
NativeFormat=       (ulaw)
WriteFormat=        ulaw
ReadFormat=         ulaw
RawWriteFormat=     ulaw
RawReadFormat=      ulaw
WriteTranscode=     No
ReadTranscode=      No
1stFileDescriptor=  16
Framesin=           0
Framesout=          0
TimetoHangup=       0
ElapsedTime=        0h0m0s
BridgeID=           (Not bridged)
Context=            default
Extension=          9001
Priority=           1
CallGroup=
PickupGroup=
Application=        DumpChan
Data=               (Empty)
Blocking_in=        (Not Blocking)
Variables:
```

La disposition des champs ci-dessus est la sortie d'Asterisk 22 `DumpChan` (un nom de canal `PJSIP/...` réel, les champs `CallerIDNum`/`ConnectedLineID` et les lignes `Raw*`/`Transcode`/`BridgeID` que les canaux PJSIP remplissent). Contrairement à l'ancien pilote, un canal PJSIP ne définit pas automatiquement les variables de canal `SIPCALLID`/`SIPUSERAGENT` ; les détails SIP équivalents sont lus à la demande avec les fonctions de dialplan `PJSIP_HEADER()` et `CHANNEL()` — par exemple `${CHANNEL(pjsip,call-id)}`, `${PJSIP_HEADER(read,User-Agent)}` et `${CHANNEL(rtp,dest)}` pour l'adresse RTP distante.

### Variables spécifiques à l'environnement

Les variables spécifiques à l'environnement peuvent être utilisées pour accéder aux variables définies dans le système d'exploitation. Vous pouvez définir des variables spécifiques à l'environnement en utilisant la fonction ENV(). Par exemple :

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### Variables spécifiques aux applications

Certaines applications utilisent des variables pour l'entrée et la sortie de données. Vous pouvez définir des variables avant d'appeler l'application ou récupérer la variable après l'exécution de l'application. Par exemple : l'application Dial renvoie les variables suivantes :

- ${DIALEDTIME} -> Il s'agit du temps écoulé entre la composition d'un canal et sa déconnexion.
- ${ANSWEREDTIME} -> Il s'agit de la durée réelle de l'appel.
- ${DIALSTATUS} Il s'agit du statut de l'appel : o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> Message d'erreur pour l'appel.

## Expressions

Les expressions peuvent être très utiles dans le dialplan. Elles sont utilisées pour manipuler des chaînes de caractères et effectuer des opérations mathématiques et logiques.

![Vue d'ensemble des expressions Asterisk — `$[expression1 operator expression2]` — regroupant les opérateurs mathématiques, logiques, de comparaison, d'expressions régulières et conditionnels disponibles dans le dialplan.](../images/04-first-pbx-fig08.png)

La syntaxe des expressions est définie comme suit :

```
$[expression1 operator expression2]
```

Supposons que nous ayons une variable appelée « I » et que nous souhaitions ajouter 100 à cette variable :

```
$[${I}+100]
```

Lorsqu'Asterisk rencontre une expression dans le dialplan, il remplace l'expression entière par la valeur résultante.

### Opérateurs

Les opérateurs suivants peuvent être utilisés pour construire des expressions. Il est important de respecter la priorité des opérateurs.

1. Parenthèses « () »
2. Opérateurs unaires « ! - »
3. Expression régulière « : =~ »
4. Opérateurs multiplicatifs « * / % »
5. Opérateurs additifs « + - »
6. Opérateurs de comparaison
7. Opérateurs logiques
8. Opérateurs conditionnels

#### Opérateurs mathématiques

- Addition (+)
- Soustraction (-)
- Multiplication (*)
- Division (/)
- Modulo (%)

#### Opérateurs logiques

- « ET » logique (&)
- « OU » logique (|)
- Complément unaire logique (!)

#### Opérateurs d'expression régulière

- Correspondance d'expression régulière (:)
- Correspondance exacte d'expression régulière (=~)

Une expression régulière est une chaîne de texte spéciale utilisée pour décrire un modèle de recherche. Vous pouvez considérer les expressions régulières comme des caractères génériques. Les expressions régulières sont utilisées pour faire correspondre une chaîne à un modèle afin de vérifier la correspondance. Si la correspondance réussit et que l'expression régulière contient au moins une correspondance, la première correspondance est renvoyée ; sinon, le résultat est le nombre de caractères ayant correspondu.

#### Opérateurs de comparaison

Le résultat d'une comparaison est 1 si la relation est vraie ou 0 si elle est fausse.

- = égal
- != différent
- < inférieur à
- > supérieur à
- <= inférieur ou égal à
- >= supérieur ou égal à

### LAB. Évaluez les expressions suivantes :

Placez ces expressions dans votre dialplan et utilisez l'application NoOP() pour évaluer les expressions. Composez le 9002 et examinez les résultats dans la console Asterisk. Utilisez verbose 15 pour afficher les résultats.

```
exten=9002,1,set(NAME="FLAVIO")                 ;Set NAME=FLAVIO
exten=9002,n,set(I=4)
exten=9002,n,set(URI="40001@voip.school")
exten=9002,n,NoOP(${NAME})
exten=9002,n,NoOP(${I})
exten=9002,n,NoOP($[${I}+${I}])
exten=9002,n,NoOP($[${I}=4])
exten=9002,n,NoOP($[${I}=4 & ${NAME}=FLAVIO])
exten=9002,n,NoOP($[${URI} =~ "4[0-9][0-9][0-9][0-9]@."])
exten=9002,n,NoOP($[${I}=4?"MATCH"::"DO NOT MATCH"])
exten=9002,n,hangup
```

## Fonctions

Certaines applications ont été remplacées par des fonctions, qui permettent le traitement de variables de manière plus avancée que les expressions seules. Vous pouvez consulter la liste complète des fonctions en exécutant la commande de console suivante :

```
*CLI> core show functions
```

Longueur de chaîne : ${LEN(string)} renvoie la longueur de la chaîne

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

Dans la première opération, le système affiche 5 comme résultat (le nombre de lettres dans le mot « fruit »). La seconde renvoie le nombre 4 (le nombre de lettres dans le mot « pear »). Sous-chaînes : Renvoie la sous-chaîne, en commençant à la position définie par le paramètre « offset », avec la longueur de chaîne définie dans le paramètre « length ». Si l'offset est négatif, il commence de droite à gauche, en débutant à la fin de la chaîne. Si la longueur est omise ou négative, il prend toute la chaîne à partir de l'offset.

```
${string:offset:length }
```

Exemple n°1 : Plusieurs sous-chaînes

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

Exemple n°2 : Extraire l'indicatif régional à partir des trois premiers chiffres.

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

Exemple n°3 : Prend tous les chiffres de la variable ${EXTEN}, à l'exception de l'indicatif régional.

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### Concaténation de chaînes

Pour concaténer deux chaînes, écrivez-les simplement l'une à côté de l'autre.

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Applications

Pour construire un dialplan, nous devons comprendre le concept d'applications. Vous utiliserez des applications pour gérer le channel dans le dialplan. Les applications sont implémentées dans plusieurs modules. Les applications disponibles dépendent des modules. Vous pouvez afficher toutes les applications Asterisk en utilisant la commande console :

```
*CLI> core show applications
```

Alternativement, vous pouvez afficher les détails d'une application spécifique en utilisant l'exemple suivant :

```
*CLI> core show application Dial
```

Pour construire un dialplan simple, vous devez connaître quelques applications. Nous discuterons d'exemples plus avancés plus loin dans le livre.

![La poignée d'applications nécessaires pour construire un dialplan simple : Answer (répondre à un canal), Dial (appeler un autre canal), Hangup (raccrocher un canal), Playback (lire un fichier audio) et Goto (sauter à une priorité, une extension ou un context).](../images/04-first-pbx-fig09.png)

Nous utiliserons ces applications (ci-dessus) pour créer un dialplan simple pour deux PBX de base.

### Answer()

[Synopsis] Répond à un canal en cours de sonnerie [Description] Answer([delay]) : Si l'appel n'a pas reçu de réponse, l'application y répondra. Sinon, elle n'a aucun effet sur l'appel. Si un délai est spécifié, Asterisk attendra le nombre de millisecondes spécifié dans ‘delay’ avant de répondre à l'appel.

### Dial()

La description suivante peut être obtenue en exécutant show application dial dans le dialplan. Pour faciliter la recherche, elle est reproduite ci-dessous. La syntaxe de l'application Dial est également indiquée ci-dessous :

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

Cette application passera des appels vers un ou plusieurs channels spécifiés. Dès qu'un des channels demandés répond, le channel à l'origine de l'appel recevra une réponse, s'il n'en a pas déjà reçu une. Ces deux channels seront alors actifs dans un appel ponté (bridged call). Tous les autres channels demandés seront alors raccrochés. À moins qu'un délai d'attente ne soit spécifié, l'application Dial attendra indéfiniment jusqu'à ce que l'un des channels appelés réponde, que l'utilisateur raccroche, ou que tous les channels appelés soient occupés ou indisponibles. L'exécution du dialplan se poursuivra si aucun des channels demandés ne peut être appelé ou si le délai d'attente expire. Cette application définit les variables de channel suivantes une fois terminée :

- DIALEDTIME - Il s'agit du temps écoulé entre la numérotation d'un channel et le moment où il est déconnecté.
- ANSWEREDTIME - Il s'agit de la durée réelle de l'appel.
- DIALSTATUS - Il s'agit du statut de l'appel : o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

Pour les modes Privacy et Screening, la variable DIALSTATUS sera définie sur DONTCALL si la partie appelée choisit d'envoyer la partie appelante vers le script 'Go Away'. La variable DIALSTATUS sera définie sur TORTURE si la partie appelée souhaite envoyer l'appelant vers le script 'torture'. Cette application signalera une terminaison normale si le channel d'origine raccroche ou si l'appel est ponté et que l'une des parties dans le pont met fin à l'appel. L'URL optionnelle sera envoyée à la partie appelée si le channel le prend en charge. Si la variable OUTBOUND_GROUP est définie, tous les channels pairs créés par cette application seront inclus dans ce groupe (comme dans

```
Set(GROUP()=...).
```

Le tableau suivant résume certaines des options les plus fréquemment utilisées pour l'application Dial. Pour la liste complète, utilisez la commande de console `core show application Dial`. Dans Asterisk 22, ces options sont séparées du canal et du délai d'attente par des virgules — par exemple `Dial(PJSIP/2000,20,tTm)`.

| Option | Description |
|--------|-------------|
| `A(x)` | Joue une annonce à la partie appelée, en utilisant `x` comme fichier. |
| `C` | Réinitialise le CDR pour cet appel. |
| `d` | Permet à l'utilisateur appelant de composer une extension à 1 chiffre en attendant que l'appel reçoive une réponse. Quitte vers cette extension si elle existe dans le context actuel, ou vers le context défini dans la variable `EXITCONTEXT`, s'il existe. |
| `D([called][:calling])` | Envoie les chaînes DTMF spécifiées après que la partie appelée a répondu, mais avant que l'appel ne soit ponté. La chaîne `called` est envoyée à la partie appelée et la chaîne `calling` à la partie appelante. Chaque paramètre peut être utilisé seul. |
| `f` | Force le caller ID du canal appelant à être défini sur l'extension associée au canal via un dialplan `hint`. Utile lorsque le PSTN n'autorise pas un caller ID arbitraire. |
| `g` | Poursuit l'exécution du dialplan à l'extension actuelle si le canal de destination raccroche. |
| `G(context^exten^pri)` | Si l'appel reçoit une réponse, transfère la partie appelante à la priorité spécifiée et la partie appelée à priorité+1. Une extension (ou une extension et un context) peut être spécifiée en option ; sinon, l'extension actuelle est utilisée. |
| `h` | Permet à la partie appelée de raccrocher en envoyant le chiffre DTMF `*`. |
| `H` | Permet à la partie appelante de raccrocher en envoyant le chiffre DTMF `*`. |
| `L(x[:y][:z])` | Limite l'appel à `x` ms, joue un avertissement lorsqu'il reste `y` ms, et répète l'avertissement toutes les `z` ms. Voir les variables `LIMIT_*` ci-dessous. |
| `m([class])` | Fournit de la musique d'attente (MusicOnHold) à la partie appelante jusqu'à ce que le canal demandé réponde. Une classe MusicOnHold spécifique peut être spécifiée. |
| `r` | Indique une tonalité de retour d'appel à la partie appelante et ne transmet aucun audio jusqu'à ce que le canal appelé réponde. |
| `S(x)` | Raccroche l'appel `x` secondes après que la partie appelée a répondu. |
| `t` | Permet à la partie appelée de transférer la partie appelante en envoyant la séquence DTMF définie dans `features.conf`. |
| `T` | Permet à la partie appelante de transférer la partie appelée en envoyant la séquence DTMF définie dans `features.conf`. |
| `w` | Permet à la partie appelée d'activer l'enregistrement à une touche en envoyant la séquence DTMF définie dans `features.conf`. |
| `W` | Permet à la partie appelante d'activer l'enregistrement à une touche en envoyant la séquence DTMF définie dans `features.conf`. |
| `k` | Permet à la partie appelée de parquer l'appel en envoyant la séquence DTMF définie pour le parcage d'appel dans `features.conf`. |
| `K` | Permet à la partie appelante de parquer l'appel en envoyant la séquence DTMF définie pour le parcage d'appel dans `features.conf`. |

L'option `L(x[:y][:z])` peut être ajustée avec les variables spéciales suivantes :

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no` (par défaut `yes`) : joue des sons pour l'appelant.
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no` : joue des sons pour la partie appelée.
- `LIMIT_TIMEOUT_FILE` — fichier à jouer lorsque le temps est écoulé.
- `LIMIT_CONNECT_FILE` — fichier à jouer lorsque l'appel commence.
- `LIMIT_WARNING_FILE` — fichier à jouer comme avertissement lorsque `y` est défini. Le comportement par défaut est d'annoncer le temps restant.

Exemple :

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

Dans l'exemple ci-dessus, l'application appellera le canal PJSIP correspondant. L'appelant et l'appelé pourraient tous deux transférer l'appel (Tt). Une musique d'attente sera entendue au lieu de la tonalité de retour d'appel. Si personne ne répond dans les 20 secondes, l'extension passera à la priorité suivante.

### Hangup()

Raccroche le canal appelant [Description] Hangup([causecode]) : Cette application raccroche le canal appelant. Si un code de cause est fourni, la cause de raccrochage du canal sera définie sur la valeur donnée.

### Goto()

Sauter à une priorité, une extension ou un context particulier [Description] Goto([[context|]extension|]priority) : Cette application amènera le canal appelant à poursuivre l'exécution du dialplan à la priorité spécifiée. Si aucune extension spécifique (ou extension et context) n'est spécifiée, cette application sautera à la priorité spécifiée de l'extension actuelle. Si la tentative de saut vers un autre emplacement dans le dialplan échoue, le canal continuera à la priorité suivante de l'extension actuelle.

## Construction d'un dialplan

Pour construire un dialplan simple, vous devez traiter tous les appels entrants et sortants en créant des contextes et des extensions. Dans cette section, nous vous montrerons comment construire les extensions les plus courantes.

### Appels entre extensions

Pour permettre les appels entre extensions, nous pourrions utiliser la variable de canal ${EXTEN}, qui fait référence à l'extension composée. Par exemple, si la plage d'extensions est comprise entre 4000 et 4999 et que toutes les extensions utilisent SIP, nous pourrions adopter la commande suivante :

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### Appels vers une destination externe

Pour appeler une destination externe, vous pouvez faire précéder le numéro composé d'une route. En Amérique du Nord, il est courant d'utiliser 9 suivi du numéro à appeler vers l'extérieur. Si vous utilisez un canal analogique ou numérique vers le PSTN, la commande devrait ressembler à ce qui suit : Si vous souhaitez utiliser le trunk SIP au lieu de DAHDI, utilisez le canal `PJSIP/...@siptrunk`.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

La ligne ci-dessus vous permettra de composer le 9 suivi du numéro souhaité. Dans l'exemple donné, vous utiliserez le premier canal DAHDI (DAHDI/1). Si vous avez plusieurs lignes et que celle-ci est occupée, l'appel ne sera pas abouti. Cependant, vous pourriez utiliser la ligne suivante pour choisir automatiquement le premier canal DAHDI disponible. En option, vous pouvez utiliser le trunk SIP au lieu de DAHDI. Dans la forme PJSIP `Dial(PJSIP/number@siptrunk,...)`, le numéro composé est la partie utilisateur et `siptrunk` est l'endpoint configuré ci-dessus.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

Le paramètre “g1” recherchera le premier canal disponible dans le groupe, permettant l'utilisation de tous les canaux. En utilisant la ligne ci-dessous, vous pourriez composer un numéro longue distance.

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### Composer le 9 pour obtenir une ligne PSTN

Si vous n'avez aucune restriction pour les appels externes, vous pouvez simplifier et utiliser ce qui suit :

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### Réception d'un appel sur l'extension de l'opérateur

Dans l'exemple suivant, l'extension de l'opérateur est 4000. La ligne PSTN est connectée à une interface FXO. Dans le fichier chan_dahdi.conf, le contexte spécifié est from-pstn. Tout appel provenant du PSTN sera routé vers le contexte from-pstn dans le dialplan. Cette ligne ne dispose pas de DID (Direct Inward Dialing) ; par conséquent, nous devrons recevoir l'appel via l'extension “s”. Si vous recevez l'appel depuis le trunk SIP, utilisez le contexte [from-sip].

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
[from-sip]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
```

### Réception d'un appel en utilisant le DID (Direct Inward Dialing)

Si vous avez une ligne numérique, vous recevrez l'extension composée. Lorsque c'est le cas, vous n'avez pas besoin de transférer l'appel à l'opérateur ; vous pouvez plutôt transférer l'appel directement vers la destination. Supposons que votre plage DID soit de 3028550 à 3028599 et que les quatre derniers chiffres soient transmis dans le DID. La configuration ressemblerait à l'exemple suivant :

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### Faire sonner plusieurs extensions simultanément

Vous pouvez configurer Asterisk pour appeler une extension et, si elle ne répond pas, appeler plusieurs autres extensions simultanément, comme indiqué dans l'exemple suivant :

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

Dans cet exemple, lorsque quelqu'un appelle l'opérateur, le canal DAHDI/1 est initialement tenté. Si personne ne répond après 15 secondes (timeout), les canaux DAHDI/1, DAHDI/2 et DAHDI/3 sonneront simultanément pendant 15 secondes supplémentaires.

### Routage par Caller ID

Dans cet exemple, vous pourriez appliquer des traitements différents en fonction du Caller ID, ce qui pourrait être utile pour les spammeurs d'appels. Par exemple :

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

Dans cet exemple, nous avons ajouté une règle spéciale qui, si le Caller ID est 4832518888, joue un message à partir du fichier précédemment enregistré “I-have-moved-to-china”. Les autres appels sont acceptés normalement.

### Utilisation de variables dans le dialplan

Asterisk peut utiliser des variables globales et de canal dans le dialplan comme arguments pour certaines applications. Regardez les exemples suivants :

```
[globals]
Flavio => DAHDI/1
Daniel => DAHDI/2&PJSIP/pingtel
Anna => DAHDI/3
Christian => DAHDI/4
[mainmenu]
exten => 1,1,Dial(${Daniel}&${Flavio})
exten => 2,1,Dial(${Anna}&${Christian})
exten => 3,1,Dial(${Anna}&${Flavio})
```

L'utilisation de variables facilite les changements futurs. Si vous modifiez la variable, toutes les références sont modifiées immédiatement.

### Enregistrement d'une annonce

Dans certaines des options discutées plus loin dans cette section, nous utiliserons des messages enregistrés. Voici un moyen simple de les enregistrer. Nous utiliserons l'application Record() pour enregistrer l'annonce en utilisant son propre téléphone.

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

Ces instructions vous permettent d'enregistrer n'importe quel message depuis un softphone. Exemple : composer recordmenu depuis le softphone. Les instructions appelleront l'enregistrement avec la variable ${EXTEN:6} sans les six premières lettres. En d'autres termes, l'instruction est équivalente à record(menu:gsm). Tout ce que vous avez à faire est de composer record + nom_du_fichier_a_enregistrer, appuyer sur # pour terminer l'enregistrement, et attendre d'entendre l'enregistrement.

### Réception des appels dans un standard automatique (digital receptionist)

Maintenant que nous avons quelques exemples simples, étendons nos connaissances sur les applications background() et goto(). La clé des systèmes interactifs dans Asterisk est l'application background(), qui vous permet d'exécuter un fichier audio qui, lorsque l'appelant appuie sur une touche, est interrompu afin d'envoyer l'appel vers l'extension composée. Syntaxe de l'application background() :

```
exten=>extension, priority, background(filename)
```

Une autre application très utile est goto(). Comme son nom l'indique, elle saute vers le contexte, l'extension et la priorité indiqués. Syntaxe de l'application goto() :

```
exten=>extension, priority,goto(context, extension, priority)
```

Formats valides pour la commande goto() :

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

Dans l'exemple suivant, nous allons créer un standard automatique. Il est très simple de modifier le fichier extensions.conf et de configurer les extensions suivantes :

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
include=aapstn
[from-sip]
include=aasip
[aapstn]
exten=>s,1,answer()
exten=>s,n,set(TIMEOUT(response)=10)
exten=>s,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>s,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
[aasip]
exten=>9999,1,answer()
exten=>9999,n,set(TIMEOUT(response)=10)
exten=>9999,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>9999,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
```

Les extensions SIP utilisent `PJSIP/` et les extensions IAX utilisent `IAX2/` — les deux pilotes sont fournis dans Asterisk 22, bien que `chan_iax2` soit désormais considéré comme hérité (legacy) et que SIP/PJSIP soit préféré.

Dans le fichier menu1.gsm, enregistrez le message “composez l'extension ou attendez l'opérateur”. Lorsque l'utilisateur compose le numéro 6000, il sera envoyé vers l'extension 6000. À ce stade, vous devriez avoir une compréhension claire de l'utilisation de plusieurs applications, notamment answer(), background(), goto(), hangup() et playback(). Si vous n'avez pas une compréhension claire, veuillez relire ce chapitre jusqu'à ce que vous vous sentiez à l'aise avec le contenu. Vous utiliserez très souvent l'application background. Une fois que vous aurez compris les bases des extensions, des priorités et des applications, il sera facile de créer un dialplan simple. Ces concepts seront explorés plus en profondeur plus loin dans le livre, et vous verrez que le dialplan deviendra plus puissant.

## Résumé

Dans ce chapitre, vous avez appris que les fichiers de configuration sont stockés dans le répertoire /etc/asterisk. Pour utiliser Asterisk, il est d'abord nécessaire de configurer les canaux (par exemple, pjsip, dahdi, iax). Trois grammaires différentes existent pour les fichiers de configuration : le groupe simple, l'héritage d'objets et l'entité complexe. Le dialplan est créé dans le fichier extensions.conf et constitue un ensemble de contextes et d'extensions. Dans le dialplan, chaque extension déclenche une application. Vous avez appris à utiliser les applications playback, background, dial, goto, hangup et answer.

## Quiz

1. Les fichiers de configuration des canaux sont (choisissez toutes les réponses qui s'appliquent) :
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. Dans Asterisk 22, le pair `chan_sip` unique (`[6001]`/`type=friend`/`host=dynamic`) est remplacé dans `pjsip.conf` par quel ensemble d'objets associés ?
   - A. Un `type=peer` et un `type=user`
   - B. Un `type=endpoint`, un `type=auth` et un `type=aor`
   - C. Un seul `type=friend`
   - D. Un `type=transport` et un `type=global`
3. Définir un context dans le fichier de configuration du canal est important car cela définit le context entrant pour les appels provenant de ce canal — un appel provenant du canal est traité dans le context correspondant dans `extensions.conf`.
   - A. Vrai
   - B. Faux
4. Les principales différences entre les applications `Playback()` et `Background()` sont (choisissez deux réponses) :
   - A. Playback joue une invite mais n'attend pas de chiffres.
   - B. Background joue une invite mais n'attend pas de chiffres.
   - C. Background joue un message et attend que des chiffres soient saisis.
   - D. Playback joue un message et attend que des chiffres soient saisis.
5. Lorsqu'un appel entre dans Asterisk via une carte d'interface téléphonique (FXO) sans DID, il est traité dans l'extension spéciale :
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. Les formats valides pour l'application `Goto()` sont (choisissez trois réponses) :
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. Le motif `_7[1-5]XX` correspond à (choisissez toutes les réponses qui s'appliquent) :
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. Dans `Dial(PJSIP/${EXTEN},20,tTm)`, que fait l'option `m` ?
   - A. Limite l'appel à une durée maximale.
   - B. Fournit de la musique d'attente à l'appelant au lieu de la tonalité de retour d'appel jusqu'à ce que le canal réponde.
   - C. Envoie des chiffres DTMF après que la partie appelée a répondu.
   - D. Force l'identification de l'appelant en utilisant un hint du dialplan.
9. Dans la grammaire d'héritage d'options utilisée par `chan_dahdi.conf`, vous :
   - A. Définissez l'objet sur une seule ligne.
   - B. Définissez les options d'abord et déclarez les objets en dessous des options définies.
   - C. Définissez un context séparé pour chaque objet.
10. Les priorités dans une extension doivent être numérotées consécutivement (1, 2, 3, …) et ne peuvent pas utiliser `n`.
    - A. Vrai
    - B. Faux

**Réponses :** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
