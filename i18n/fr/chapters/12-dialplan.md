# Fonctionnalités avancées du dialplan

Le chapitre 3 a abordé les bases d'un dialplan. Pour des raisons didactiques, nous n'avons pas expliqué toutes les fonctionnalités, mais seulement certaines des plus importantes. Ce chapitre approfondira le dialplan en décrivant des techniques avancées, de nouvelles applications et des concepts.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Simplifier vos entrées d'extension
- Gérer la sécurité du dialplan et le filtrage des extensions
- Recevoir des appels à l'aide d'un menu IVR
- Utiliser des sous-routines pour éviter les réécritures inutiles
- Mettre en œuvre une certaine sécurité du dialplan en utilisant « Include »
- Mettre en œuvre le suivi d'appel (follow-me) en utilisant AsteriskDB
- Mettre en œuvre un comportement après les heures d'ouverture dans votre PBX
- Utiliser la commande switch pour transférer vers un autre PBX
- Mettre en œuvre le gestionnaire de confidentialité (privacy manager)
- Mettre en œuvre la voicemail
- Mettre en œuvre un annuaire d'entreprise

## Simplifier votre dialplan

Vous pouvez simplifier votre dialplan en utilisant le mot-clé « same » pour définir une extension. Cela devrait réduire le nombre de fautes de frappe dans le dialplan. Consultez l'exemple ci-dessous :

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Sécurité du dialplan

Une faille a été découverte dans le dialplan Asterisk qui permet à un utilisateur d'injecter un nouveau canal et un numéro à composer dans votre dialplan. Supposons que vous ayez la ligne suivante dans votre serveur `exten=>_X.,1,Dial(PJSIP/${EXTEN})` et qu'un utilisateur malveillant compose le numéro `3000&DAHDI/1/011551123456789` dans le softphone. Le protocole SIP, par défaut, accepte tous les caractères alphanumériques ; l'extension composée déclenchera donc en réalité deux appels : l'un pour le canal PJSIP/3000 et l'autre pour le canal DAHDI/011551123456789, qui est un numéro international. Ainsi, tout utilisateur ayant accès à une extension peut en réalité appeler n'importe où dans le monde. Le moyen le plus simple d'éviter ce comportement est de filtrer les numéros avant d'appeler l'application dial. La fonction FILTER() est très pratique pour cela. Exemple :

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

L'application de filtrage vous permettra de filtrer tous les caractères du numéro composé à l'exception des chiffres de 0 à 9. De plus amples informations sont disponibles dans le fichier README-SERIOUSLY.bestpractices.txt fourni avec Asterisk.

## Réception d'appels via un menu IVR.

Dans la section précédente, vous avez reçu tous les appels en utilisant un DID ou en les transférant vers l'opérateur. Vous allez maintenant apprendre à implémenter un menu IVR ainsi qu'à créer un service de standard automatique. Avant d'entrer dans les détails, examinons quelques nouvelles applications. Nous avons placé la sortie de la commande `core show application` ci-dessous simplement pour faciliter la lecture. Vous pouvez obtenir ces descriptions vous-même en utilisant `core show application <application_name>`.

### L'application Background()

Cette application joue la liste de fichiers donnée tout en attendant qu'une extension soit composée par le canal appelant. Pour continuer à attendre des chiffres après que cette application a fini de lire les fichiers, l'application WaitExten doit être utilisée. L'option langoverride spécifie explicitement quelle langue tenter d'utiliser pour les fichiers audio demandés. Tout context spécifié sera le contexte du dialplan que cette application utilise lors de la sortie vers une extension composée. Si l'un des fichiers audio demandés n'existe pas, le traitement de l'appel sera terminé. Options :

- s - Provoque l'omission de la lecture du message si le canal n'est pas dans l'état 'up' (c'est-à-dire qu'il n'a pas encore reçu de réponse). Si cela se produit, l'application reviendra immédiatement.
- n - Ne pas répondre au canal avant de lire les fichiers.
- m - Interrompre uniquement si un chiffre composé correspond à une extension à un chiffre dans le contexte de destination.

### L'application Record()

Cette application enregistre depuis le canal dans un nom de fichier donné. Si le fichier existe, il sera écrasé.

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' est le format du type de fichier à enregistrer (wav, gsm, etc.).
- 'silence' est le nombre de secondes de silence autorisées avant le retour.
- 'maxduration' est la durée d'enregistrement maximale en secondes ; si elle est manquante ou égale à zéro, il n'y a pas de maximum.
- 'options' peut contenir l'une des lettres suivantes :
    - `a` — ajoute à un enregistrement existant plutôt que de le remplacer
    - `n` — ne pas répondre, mais enregistrer quand même si la ligne n'a pas encore reçu de réponse
    - `q` — silencieux (ne pas jouer de tonalité de bip)
    - `s` — ignore l'enregistrement si la ligne n'a pas encore reçu de réponse
    - `t` — utilise la touche de terminaison alternative `*` (DTMF) au lieu de la valeur par défaut `#`
    - `x` — ignore toutes les touches de terminaison (DTMF) et continue l'enregistrement jusqu'au raccrochage

Si le nom de fichier contient %d, ces caractères seront remplacés par un nombre incrémenté de un à chaque fois que le fichier est enregistré. Utilisez core show file formats pour voir les formats disponibles sur votre système. L'utilisateur peut appuyer sur # pour terminer l'enregistrement et passer à la priorité suivante. Si l'utilisateur raccroche pendant un enregistrement, toutes les données seront perdues et l'application se terminera.

### L'application Playback()

Cette application lit les noms de fichiers donnés (n'incluez pas l'extension). Des options peuvent également être incluses après un symbole pipe. L'option 'skip' provoque l'omission de la lecture du message si le canal n'est pas dans l'état 'up' (c'est-à-dire qu'il n'a pas encore reçu de réponse).

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

Si 'skip' est spécifié, l'application reviendra immédiatement si le canal n'est pas décroché. Sinon, à moins que 'noanswer' ne soit spécifié, le canal recevra une réponse avant que le son ne soit joué. Tous les canaux ne prennent pas en charge la lecture de messages alors qu'ils sont encore sur le crochet. Si 'j' est spécifié, l'application sautera à la priorité n+101 lorsque le fichier n'existe pas, s'il est présent. Cette application définit la variable de canal suivante une fois terminée :

- PLAYBACKSTATUS — le statut de la tentative de lecture sous forme de chaîne de texte, l'un des suivants :
    - `SUCCESS`
    - `FAILED`

### L'application Read()

Cette application lit un nombre prédéterminé de chiffres, un certain nombre de fois, depuis l'utilisateur vers la variable donnée.

- filename -- fichier à lire avant de lire les chiffres ou la tonalité avec l'option i
- maxdigits -- nombre maximum de chiffres acceptables. Arrête la lecture après que maxdigits ont été saisis (sans exiger que l'utilisateur appuie sur la touche #). La valeur par défaut est 0 - aucune limite - pour attendre que l'utilisateur appuie sur la touche #. Toute valeur inférieure à 0 signifie la même chose. La valeur maximale acceptée est 255.

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- les options sont `s`, `i`, `n` :
    - `s` — revenir immédiatement si la ligne n'est pas active
    - `i` — lire filename comme une tonalité d'indication depuis votre `indications.conf`
    - `n` — lire les chiffres même si la ligne n'est pas active
- attempts -- si supérieur à 1, le nombre de tentatives qui seront effectuées au cas où aucune donnée ne serait saisie
- timeout -- un nombre entier de secondes à attendre pour une réponse par chiffres. Si supérieur à 0, cette valeur remplacera le délai d'attente par défaut.

L'application read() doit se déconnecter si la fonction échoue ou génère une erreur.

### L'application Gotoif()

Cette application provoquera le saut du canal appelant vers l'emplacement spécifié dans le dialplan en fonction de l'évaluation de la condition donnée. Le canal continuera à labeliftrue si la condition est vraie, ou à 'labeliffalse' si la condition est fausse. Les étiquettes sont spécifiées avec la même syntaxe que celle utilisée dans l'application Goto. Si l'étiquette choisie par la condition est omise, aucun saut n'est effectué ; l'exécution se poursuit plutôt avec la priorité suivante dans le dialplan.

### Lab : Construction étape par étape d'un menu IVR

Créons un menu IVR avec les fonctionnalités suivantes. Lorsqu'il est composé, l'IVR lit un fichier audio avec le message « Bienvenue chez XYZ Corporation ; appuyez sur 1 pour les ventes, 2 pour le support technique, 3 pour la formation, ou attendez pour parler à un représentant. » Les chiffres dirigent l'appelant comme suit :

- `1` — transfert vers les ventes (PJSIP/4001)
- `2` — transfert vers le support technique (PJSIP/4002)
- `3` — transfert vers la formation (PJSIP/4003)
- Aucun chiffre pressé — transfert vers l'opérateur (PJSIP/4000)

**Étape 1 – Enregistrer les invites**

Créons une extension pour enregistrer les invites. Pour enregistrer une invite, composez depuis un softphone le `9003<filename>` (par exemple, `9003welcome`). Lorsque vous entendez le bip, commencez l'enregistrement ; appuyez sur `#` pour arrêter. Vous entendrez un bip et le système lira l'invite enregistrée.

**Étape 2 – Créer la logique du menu**

Lors de la composition de l'extension 9004, le traitement saute au menu dans l'extension `s`, priorité 1.

### Correspondance pendant la numérotation

Il s'agit d'un menu de configuration d'entreprise pour la réception d'appels. L'application `Background()` lit l'invite de bienvenue, puis attend des chiffres, en faisant correspondre ce que l'appelant compose avec les extensions définies dans le contexte actuel.

```
[incoming]
exten=>s,1,Background(welcome)
exten=>1,1,Dial(DAHDI/1)
exten=>2,1,Dial(DAHDI/2)
exten=>21,1,Dial(DAHDI/3)
exten=>22,1,Dial(DAHDI/4)
exten=>31,1,Dial(DAHDI/5)
exten=>32,1,Dial(DAHDI/6)
```

Lorsque vous composez le numéro de cette entreprise, le message de bienvenue est lu en premier. Après cela, Asterisk attend qu'un chiffre soit composé :

| Numéro composé | Action d'Asterisk |
|---------------|-----------------|
| 1 | Appelle immédiatement `Dial(DAHDI/1)` |
| 2 | Attend le délai d'expiration, puis appelle `Dial(DAHDI/2)` |
| 21 | Appelle immédiatement `Dial(DAHDI/3)` |
| 22 | Appelle immédiatement `Dial(DAHDI/4)` |
| 3 | Attend le délai d'expiration, puis se déconnecte |
| 31 | Appelle immédiatement `Dial(DAHDI/5)` |
| 32 | Appelle immédiatement `Dial(DAHDI/6)` |

Il est important d'éviter toute ambiguïté dans les menus. Tout le monde veut obtenir une réponse rapidement. Pour cette raison, vous ne devriez pas utiliser les numéros 2, 21 ou 22.

### Lab : Utilisation de l'application Read()

Veuillez essayer le laboratoire avec l'application read(). Read accepte les chiffres de l'utilisateur et les insère dans la variable spécifiée ; vous pouvez ensuite utiliser l'application gotoif pour rediriger l'appel.

## Inclusion de contextes

Un context peut inclure le contenu d'un autre context. Dans l'exemple ci-dessus, n'importe quel canal peut appeler n'importe quelle extension dans le context internal, mais seul le canal 4003 peut appeler des extensions internationales. Vous pouvez utiliser l'inclusion de contextes pour faciliter la création du dialplan. En utilisant l'inclusion de contextes, vous pouvez contrôler qui a accès à quelles extensions.

### Dépannage du message « number not found »

Il est très courant de recevoir le message « number not found ». La plupart des gens confondent le concept de contextes inclus car il n'est vraiment pas intuitif. En règle générale, allez d'abord dans le fichier de configuration du canal entrant, tel que `pjsip.conf`, `chan_dahdi.conf` et `iax.conf`, et déterminez le context actuel. Ensuite, allez dans le dialplan dans le fichier extensions.conf et vérifiez si le numéro composé peut être trouvé dans ce context. Si ce n'est pas le cas, il y a un problème avec votre dialplan. Les règles d'or des contextes sont : 1. Un canal ne peut appeler que des numéros situés dans le même context que le canal. 2. Le context où l'appel est traité est défini dans le fichier de configuration du canal entrant (`chan_dahdi.conf`, `iax.conf`, `pjsip.conf`).

## Utilisation de l'instruction switch

Vous pouvez envoyer le traitement du dialplan vers un autre serveur en utilisant la commande switch. Vous aurez besoin du nom et de la clé de l'autre serveur. Le context est le context de destination.

![10-dialplan-advanced-features figure 6](../images/10-dialplan-advanced-features-img06.png)

## Ordre de traitement du dialplan

Lorsqu'Asterisk reçoit un appel entrant, il recherche dans le context défini par le channel. Dans certains cas, si plusieurs modèles correspondent au numéro composé, Asterisk ne peut pas traiter l'appel exactement de la manière dont vous le souhaiteriez. Vous pouvez visualiser l'ordre de correspondance en utilisant la commande CLI dialplan show. Exemple : supposons que vous souhaitiez composer 912 pour acheminer vers un trunk analogique (DAHDI/1) et tous les autres numéros commençant par 9 vers un autre trunk analogique (DAHDI/2). Vous écririez quelque chose comme ceci :

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

Si deux modèles correspondent à une extension, vous pouvez contrôler quelle extension est traitée en premier en utilisant les contexts inclus. Un context inclus est traité après un modèle situé dans le même context.

## L'instruction #INCLUDE

Devrions-nous utiliser un seul gros fichier ou plusieurs fichiers ? Vous pouvez utiliser l'instruction #include <filename> pour inclure d'autres fichiers dans votre extensions.conf. Par exemple, nous pourrions créer un users.conf pour les utilisateurs locaux et un services.conf pour les services spéciaux. Faites attention à ne pas confondre #include <filename> avec le

```
include=>context statement.
```

## Sous-routines avec GOSUB

Dans les anciennes versions d'Asterisk, vous disposiez de la commande Macro. Cette commande a été dépréciée il y a longtemps au profit de GOSUB. Nous allons démontrer ici comment créer des sous-routines pour le traitement de la voicemail de manière simple et ordonnée. Format de la commande :

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

La commande GOSUB est disponible depuis Asterisk 1.6 et prend en charge le passage d'arguments (accessibles à l'intérieur de la sous-routine sous la forme `${ARG1}`, `${ARG2}`, et ainsi de suite). Grâce aux arguments, il est désormais possible de remplacer complètement les anciennes commandes Macro. Les macros (`app_macro`) ont été supprimées dans Asterisk 21 ; vous devez utiliser GOSUB pour les sous-routines.

### Création de la sous-routine

La définition est très similaire. Regardez la sous-routine ci-dessous définie pour la voicemail avec le nom stdexten (choisissez le nom que vous préférez). Après avoir appelé la commande Dial avec le premier argument (nom du canal), nous vérifions la variable ${DIALSTATUS} pour envoyer la logique d'appel à l'étape suivante.

```
[stdexten]
exten=>s,1,Dial(${ARG1},20,tT)
exten=>s,n,Goto(${DIALSTATUS})
exten=>s,n,hangup()
exten=>s,n(BUSY),voicemail(${ARG2},b)
exten=>s,n,hangup()
exten=>s,n(NOANSWER),voicemail(${ARG2},u)
exten=>s,n,hangup()
exten=>s,n(CANCEL),hangup
exten=>s,n(CHANUNAVAIL),hangup
exten=>s,n(CONGESTION),hangup
```

### Appel d'une sous-routine

Faites attention lors de l'appel de la sous-routine à utiliser des parenthèses avant les paramètres.

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Utilisation de la base de données Asterisk

Pour implémenter le renvoi d'appel et les listes noires, nous avons besoin d'un moyen de stocker et de restaurer des données. Heureusement, Asterisk fournit un mécanisme pour stocker et récupérer des données à partir d'une base de données intégrée appelée AstDB. Dans les versions modernes d'Asterisk (y compris Asterisk 22), AstDB est supportée par **SQLite3** (le fichier `/var/lib/asterisk/astdb.sqlite3`) ; Asterisk 1.8 et les versions antérieures utilisaient Berkeley DB v1. Cela est similaire à la base de données du registre Windows utilisant le concept hiérarchique de famille et de clés. Les données persistent entre les redémarrages d'Asterisk. L'API famille/clé est inchangée par rapport à l'ancien backend ; seul le format de stockage sur disque a changé.

### Fonctions, applications et commandes CLI

Il existe certaines fonctions, applications et commandes CLI qui fonctionnent avec AstDB :

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

Exemples :

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

Certaines applications peuvent être utilisées pour manipuler AstDB :

- DB_DELETE(<family/key>) — fonction qui renvoie et supprime une seule clé
- DBdeltree(<family>) — application qui supprime une famille/sous-arborescence entière

L'ancienne application `DBdel()` n'existe plus dans Asterisk 22. Supprimez une seule clé avec la fonction de dialplan `DB_DELETE()` — par exemple `Set(x=${DB_DELETE(family/key)})` ou, en tant qu'opération d'écriture, `Set(DB_DELETE(family/key)=)`. `DBdeltree()` (supprimer une famille/sous-arborescence entière) est toujours une application.

Il est également possible d'utiliser des commandes CLI pour définir et supprimer des clés :

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### Implémentation du renvoi d'appel, du DND et des listes noires

Dans cet exemple, vous apprendrez comment implémenter le renvoi d'appel immédiat et le renvoi d'appel sur occupation. Nous utiliserons *21* pour programmer le renvoi d'appel immédiat et *61* pour programmer le renvoi d'appel sur occupation. Pour annuler la programmation, utilisez #21# et #61# respectivement. Utilisez l'exemple ci-dessus pour remplir la base de données. Familles utilisées :

- CFIM – Call Forward Immediate (Renvoi d'appel immédiat)
- CFBS – Call Forward on Busy status (Renvoi d'appel sur occupation)
- DND – Do Not Disturb (Ne pas déranger)

Essayez de remplir la base de données en composant :

- *21* (Extension de destination pour le renvoi d'appel immédiat)
- *61* (Extension de destination pour le renvoi d'appel sur occupation)
- *41* (Extension à mettre en mode ne pas déranger)

Utilisez la commande CLI database show pour voir les familles, les clés et les valeurs ajoutées.

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### Renvoi d'appel, liste noire, DND

La sous-routine vérifie si la base de données contient les paires clé:valeur correspondant à CFIM, CFBS ou DND, puis les traite de manière appropriée. La sous-routine suivante appelle la routine de numérotation :

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## Utilisation d'une liste noire

L'ancienne application `LookupBlacklist()` a été **supprimée** d'Asterisk (elle a disparu en même temps que l'ancien mécanisme de « saut de priorité+101 »). Dans Asterisk 22, vous construisez une liste noire directement avec la fonction `DB_EXISTS()` (qui teste la présence d'une clé et, lorsqu'elle est trouvée, expose sa valeur dans `${DB_RESULT}`) ainsi que `GotoIf`. Stockez chaque numéro bloqué en tant que clé dans une famille `blacklist`, puis vérifiez l'identifiant de l'appelant (caller ID) au début de votre context entrant :

```
[incoming]
exten => s,1,GotoIf($[${DB_EXISTS(blacklist/${CALLERID(num)})}]?blocked,s,1)
exten => s,n,Dial(PJSIP/4000,20,tT)
exten => s,n,Hangup()
[blocked]
exten => s,1,Answer()
exten => s,2,Playback(blockedcall)
exten => s,3,Hangup()
```

`DB_EXISTS(blacklist/${CALLERID(num)})` renvoie `1` lorsque le numéro de l'appelant est présent dans la base de données (envoyant l'appel vers le context `blocked`) et `0` sinon, permettant ainsi à l'appel de poursuivre vers le `Dial()` normal.

Pour insérer un numéro dans la liste noire, nous pouvons utiliser la même ressource qu'auparavant, en utilisant *31* suivi des extensions à placer sur liste noire. Pour supprimer un numéro de la liste noire, vous devez utiliser #31# suivi du numéro à supprimer.

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

Vous pouvez également insérer les numéros dans la liste noire en utilisant la CLI de la console :

```
*CLI>database put blacklist <name/number> 1
```

Note : N'importe quelle valeur peut être associée à la clé. Le test `DB_EXISTS()` recherche la clé, et non la valeur. Pour effacer le numéro de la liste noire, vous pouvez utiliser :

```
*CLI>database del blacklist <name/number>
```

## Contextes basés sur le temps

Dans la figure suivante, nous avons un dialplan avec trois contextes. Le contexte [incoming] est celui où les appels sont généralement reçus. Nous avons inclus quatre lignes qui modifient le comportement en fonction de l'heure du système, comme illustré ci-dessous :

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

L'Asterisk moderne (y compris la version 22) sépare les champs time-include par des **virgules**, et non par des barres verticales. L'ancienne forme avec barre verticale (`include => context|times|weekdays|mdays|months`) est interprétée comme un nom de contexte littéral simple et échoue silencieusement à appliquer toute condition temporelle.

Pendant les heures de bureau habituelles, le traitement sera redirigé vers le mainmenu, où il appellera probablement un IVR pour gérer l'appel entrant. Si l'appel a lieu en dehors des heures d'ouverture, il appellera l'extension de sécurité définie dans la variable ${SECURITY}. Si l'extension de sécurité ne répond pas à l'appel, celui-ci sera envoyé vers la voicemail de l'opérateur.

![10-dialplan-advanced-features figure 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figure 12](../images/10-dialplan-advanced-features-img12.png)

## Messages basés sur le temps avec gotoiftime()

La syntaxe de GotoIfTime() est présentée ci-dessous.

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

Dans Asterisk 22, le séparateur de champ est une **virgule**, et non une barre verticale (la forme avec barre verticale a été dépréciée depuis Asterisk 1.6). Un champ optionnel `timezone` est pris en charge, et chaque étiquette de branchement utilise la forme habituelle `[[context,]extension,]priority`.

Cette application peut remplacer le context basé sur le temps et semble plus facile à comprendre et à lire. Vous pouvez spécifier le temps comme suit :

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=nombre de 1 à 31
- <hour>=nombre de 0 à 23
- <minute>=nombre de 0 à 59
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

Les noms des jours et des mois ne sont pas sensibles à la casse.

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

L'instruction précédente transfère le traitement vers l'extension s dans le context normalhours si l'appel a lieu entre 08:00 et 18:00 du lundi au vendredi.

## Utilisation de DISA pour obtenir une nouvelle tonalité

DISA, ou « direct inward system access », est un système qui permet aux utilisateurs de recevoir une seconde tonalité. Il permet aux utilisateurs de composer à nouveau un numéro vers une autre destination. Il est souvent utilisé par les techniciens lorsqu'ils doivent passer des appels longue distance pour du support technique le week-end ; au lieu d'appeler directement la destination depuis leur domicile, ils appellent le numéro DISA du bureau, reçoivent une tonalité, puis appellent la destination. Les frais d'interurbain sont alors facturés à l'entreprise plutôt qu'au téléphone du domicile.

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

Exemple :

```
exten => s,1,DISA(no-password,default)
```

En utilisant l'instruction précédente, l'utilisateur appelle le PBX et — sans nécessiter de mot de passe — reçoit une tonalité. Tout appel utilisant DISA sera traité en utilisant le context `default`. Les arguments de cette application incluent un mot de passe global ou un mot de passe individuel au sein d'un fichier. Si aucun context n'est spécifié, le context `disa` est supposé. Si vous utilisez un fichier de mots de passe, le chemin complet doit être spécifié. Un caller ID peut également être spécifié pour la numérotation externe DISA. Exemple :

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22 utilise des virgules comme séparateurs d'arguments (la forme avec barre verticale a été dépréciée dans 1.6). Le premier argument est soit un code d'accès unique, soit le chemin vers un fichier de codes d'accès, et le context par défaut lorsqu'aucun n'est fourni est `disa`.

## Limiter les appels simultanés

La fonction GROUP() vous permet de compter combien de canaux actifs vous avez dans un groupe en même temps. Exemple : Vous avez une succursale à Rio de Janeiro, où les téléphones suivent le modèle « _214X ». Cet emplacement est desservi par une ligne louée, avec 64K réservés pour la bande passante vocale. Dans ce cas, le nombre maximum d'appels autorisés est de 2 (G.729, environ 31.2K par appel). Pour limiter les appels vers Rio à deux :

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

La messagerie vocale est un système de réponse téléphonique informatisé qui enregistre les messages vocaux entrants, les sauvegardant sur disque ou les envoyant par e-mail. Elle dispose parfois d'un répertoire permettant de rechercher des boîtes vocales par nom. Par le passé, les systèmes de messagerie vocale étaient très coûteux. Aujourd'hui, avec la téléphonie IP, la messagerie vocale devient une fonctionnalité standard.

Pour configurer la messagerie vocale, vous devez suivre les étapes suivantes.

**Étape 1 : Modifiez `voicemail.conf` et définissez les paramètres généraux.**

- `format` — codec utilisé pour enregistrer le message (par exemple, wav49, wav, gsm)
- `serveremail` — expéditeur qui doit apparaître pour la notification par e-mail
- `maxmsg` — nombre maximum de messages dans la boîte vocale ; au-delà de ce seuil, les messages sont rejetés
- `maxsecs` — durée maximale d'un message vocal, en secondes
- `minsecs` — durée minimale d'un message, en secondes ; en dessous de ce seuil, aucun message n'est enregistré
- `maxsilence` — nombre de secondes de silence à considérer comme la fin du message

**Étape 2 : Modifiez `voicemail.conf` et créez les boîtes vocales des utilisateurs.**

### Voicemail.conf

Une boîte vocale est définie par une ligne par boîte, sous la forme :

```
mailboxID => pincode,fullname,email,pager-email,options
```

Les champs sont :

- **MailboxID** — généralement le numéro d'extension
- **Pincode** — mot de passe pour accéder au système de messagerie vocale
- **Full name** — utilisé par l'application de répertoire
- **E-mail** — adresse pour la notification de messagerie vocale
- **Pager e-mail** — adresse pour la notification via une passerelle SMS ou un téléavertisseur
- **Options** — options par boîte vocale (les mêmes options que dans `[general]`, mais appliquées à cette boîte spécifique)

La messagerie vocale possède plusieurs options qui contrôlent son comportement. Pour l'instant, nous nous en tiendrons aux options par défaut et nous nous concentrerons sur la définition de la boîte vocale. Après la section `[general]` dans le fichier, vous commencez à configurer les IDs de boîte vocale, chacun dans son propre context. Exemple :

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

Veuillez consulter les options avancées dans le fichier `voicemail.conf`.

**Étape 3 : Configurez le fichier `extensions.conf`.**

La sous-routine `stdexten` présentée précédemment (dans la section *Subroutines with GOSUB*) est exactement le gestionnaire d'appel/messagerie vocale dont vous avez besoin ici : elle appelle l'extension et utilise la valeur de la variable de canal `${DIALSTATUS}` pour rediriger le flux d'appel vers le message d'accueil approprié (`b` pour occupé, `u` pour indisponible). Appelez-la avec `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` depuis chaque extension dans `extensions.conf`.

## Utilisation de l'application VoiceMailMain()

L'application voicemailmain() est utilisée pour configurer la boîte vocale. Les utilisateurs peuvent appeler l'application, enregistrer leur message d'accueil et écouter leurs messages vocaux. Pour appeler l'application dans le dialplan, utilisez :

```
exten=>9000,1,VoiceMailMain()
```

Vous trouverez ci-dessous une liste des options disponibles pour cette application.

### Syntaxe de l'application Voicemail

Cette application permet à l'appelant de laisser un message pour une liste spécifiée de boîtes vocales. Lorsque plusieurs boîtes vocales sont spécifiées, le message d'accueil sera celui de la première boîte vocale indiquée. L'exécution du dialplan s'arrêtera si la boîte vocale spécifiée n'existe pas. La syntaxe est présentée ci-dessous :

```
 [Synopsis]
Leave a Voicemail message.
[Description]
This application allows the calling party to leave a message for the specified
list of mailboxes. When multiple mailboxes are specified, the greeting will
be taken from the first mailbox specified. Dialplan execution will stop if
the specified mailbox does not exist.
The Voicemail application will exit if any of the following DTMF digits are
received:
    0 - Jump to the 'o' extension in the current dialplan context.
    * - Jump to the 'a' extension in the current dialplan context.
This application will set the following channel variable upon completion:
${VMSTATUS}: This indicates the status of the execution of the VoiceMail
application.
    SUCCESS
    USEREXIT
    FAILED
[Syntax]
VoiceMail(mailbox[@context][&mailbox[@context][&...]][,options])
[Arguments]
options
```

![10-dialplan-advanced-features figure 13](../images/10-dialplan-advanced-features-img13.png)

```
    b: Play the 'busy' greeting to the calling party.
    d([c]): Accept digits for a new extension in context <c>, if played
    during the greeting. Context defaults to the current context.
    g(#): Use the specified amount of gain when recording the voicemail
    message. The units are whole-number decibels (dB). Only works on supported
    technologies, which is DAHDI only.
    s: Skip the playback of instructions for leaving a message to the
    calling party.
    u: Play the 'unavailable' greeting.
    U: Mark message as 'URGENT'.
    P: Mark message as 'PRIORITY'.
```

Dans tous les cas, le fichier beep.gsm sera lu avant que l'enregistrement ne commence. Les messages vocaux seront stockés dans le répertoire inbox.

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

Si un appelant appuie sur 0 (zéro) pendant l'annonce, il sera dirigé vers l'extension « o » (out) dans le context actuel de la boîte vocale. Cela peut être utilisé pour basculer vers l'opérateur. Si, pendant l'enregistrement, l'appelant appuie sur # ou si la limite de silence est atteinte, l'enregistrement s'arrête et l'appel passe à la priorité suivante. Assurez-vous de gérer l'appel après la lecture de la boîte vocale, comme illustré ci-dessous.

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### Marquer les messages vocaux comme urgents

Vous pouvez marquer certains messages comme « urgents ». Deux méthodes sont disponibles pour cela :

- Passer l'option « U » dans l'application voicemail()
- Spécifier review=yes dans le fichier voicemail.conf. Si vous utilisez cette option, l'utilisateur pourra marquer le message comme urgent après avoir enregistré ses instructions vocales.

## Envoi de la voicemail par e-mail

Dans certains cas (comme le mien), nous n'utilisons tout simplement pas l'application voicemailmain() pour consulter les messages. Il est plus simple et plus pratique d'envoyer tous les messages par e-mail avec l'audio en pièce jointe. En utilisant les paramètres ‘attach’ et ‘delete’, vous pouvez envoyer tous les messages par e-mail et les supprimer de la boîte vocale.

```
attach=yes
delete=yes
```

Pour envoyer la voicemail par e-mail, l'application voicemail utilise le message transfer agent (MTA), un composant de votre système d'exploitation. Debian utilise Exim comme MTA. L'application qui envoie l'e-mail est définie dans le paramètre ‘mailcmd’.

```
mailcmd =/usr/sbin/sendmail -t
```

Dans la distribution Debian de Linux, le MTA est Exim. Pour configurer Exim sous Debian, utilisez :

```
dpkg-reconfigure exim4-config
```

Vous pouvez choisir de faire envoyer un e-mail par votre MTA directement via SMTP ou via un smarthost (généralement le serveur de messagerie de votre entreprise). Vérifiez auprès de votre administrateur de messagerie la meilleure façon d'envoyer des e-mails depuis le serveur Asterisk vers votre serveur de messagerie.

## Personnalisation du message électronique

Vous pouvez contrôler la manière dont les messages sont envoyés en configurant les variables suivantes : Variables pour l'objet et le corps de l'e-mail :

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

Le corps et l'objet de l'e-mail sont construits à partir d'un modèle que vous définissez dans la section `[general]` de `voicemail.conf`. Vous pouvez modifier à la fois le corps et l'objet, mais la limite de taille du message est de 512 octets. Dans le modèle, `\n` insère un saut de ligne et `\t` insère une tabulation.

L'exemple `emailsubject` ci-dessous est simple. L'exemple `emailbody` est très proche de la valeur par défaut ; la valeur par défaut affiche uniquement le CIDNAME lorsqu'il n'est pas nul, sinon le CIDNUM, ou "an unknown caller" lorsque les deux sont nuls.

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Interface Web de voicemail

Il existe un script Perl dans la distribution source appelé `vmail.cgi`, situé dans `contrib/scripts/vmail.cgi` au sein de l'arborescence source d'Asterisk (il est toujours fourni avec Asterisk 22). La commande `make install` n'installe pas cette interface ; vous devez exécuter `make webvmail` depuis le répertoire source. Ce script nécessite que l'interpréteur de commandes Perl et un serveur web (tel qu'Apache) soient installés sur le serveur.

```
make webvmail
```

La cible `make webvmail` installe le script (setuid root) dans le répertoire CGI de votre serveur web (`HTTP_CGIDIR`) et copie les images de support depuis `images/*.gif` vers `HTTP_DOCSDIR/_asterisk` (par défaut `/var/www/html/_asterisk`). Si ces chemins ne correspondent pas à la configuration de votre serveur web, modifiez les variables `HTTP_CGIDIR` et `HTTP_DOCSDIR` dans le fichier `Makefile` de premier niveau avant d'exécuter la cible.

## Notification de messagerie vocale

Vous pouvez configurer la messagerie vocale pour envoyer un message de notification à votre téléphone lorsque vous avez de nouveaux messages. Dans Asterisk 22, l'indication d'attente de message (MWI) fonctionne avec les téléphones PJSIP et SIP ainsi qu'avec les téléphones DAHDI. Pour indiquer un message vocal non écouté, un voyant peut clignoter ou le téléphone peut émettre une tonalité spécifique. Vous devez configurer la boîte vocale dans le fichier de configuration du canal correspondant. Exemple : `pjsip.conf` (dans la section endpoint) :

```
mailboxes=8590
```

Dans PJSIP, l'indication de boîte vocale est définie avec l'option `mailboxes` à l'intérieur de la section endpoint de `pjsip.conf`, plutôt que l'ancien `mailbox=` de `sip.conf`. Les abonnements MWI sont gérés par le module `res_pjsip_mwi`.

![L'interface web Comedian Mail (`vmail.cgi`) : la connexion à la messagerie vocale web d'Asterisk — saisissez votre boîte vocale et votre mot de passe pour écouter, enregistrer, transférer ou supprimer des messages vocaux depuis un navigateur. Elle est toujours fournie avec Asterisk 22 et est installée avec `make webvmail`.](../images/10-dialplan-advanced-features-img14.png)

### Labo : Notification de message sur le téléphone

Ce labo a été testé en utilisant un softphone SIP.

1. Modifiez `pjsip.conf` et ajoutez `mailboxes=4401` dans la section endpoint pour le périphérique nommé 4401.
2. Modifiez le `extensions.conf` et créez une extension pour enregistrer un message vocal vers les extensions 4401.

```
exten=9008,1,voicemail(4401,b)
```

3. Allez sur la console et rechargez.
4. Dans le softphone SipPulse, ouvrez les paramètres du compte SIP et activez la vérification de la messagerie vocale (message-waiting) pour le compte.
5. Composez le 9008 et laissez un message.
6. Observez l'icône de message sur le téléphone.

## Utilisation de l'application directory

Cette application vous permet de trouver rapidement un utilisateur à appeler. La liste des noms et des extension correspondantes est récupérée à partir du fichier de configuration de la messagerie vocale voicemail.conf. La syntaxe de l'application peut être affichée en utilisant core show application directory :

```
-= Info about application 'Directory' =-
[Synopsis]
Provide directory of voicemail extensions.
[Description]
This application will present the calling channel with a directory of
extensions from which they can search by name. The list of names and
corresponding extensions is retrieved from the voicemail configuration file,
"voicemail.conf".
This application will immediately exit if one of the following DTMF digits
are received and the extension to jump to exists:
'0' - Jump to the 'o' extension, if it exists.
'*' - Jump to the 'a' extension, if it exists.
[Syntax]
Directory([vm-context][,dial-context[,options]])
[Arguments]
vm-context
    This is the context within voicemail.conf to use for the Directory.
    If not specified and 'searchcontexts=no' in "voicemail.conf", then
    'default' will be assumed.
dial-context
    This is the dialplan context to use when looking for an extension
    that the user has selected, or when jumping to the 'o' or 'a' extension.
options
    e: In addition to the name, also read the extension number to the
    caller before presenting dialing options.
    f(n): Allow the caller to enter the first name of a user in the
    directory instead of using the last name.  If specified, the optional
    number argument will be used for the number of characters the user should
    enter.
    l(n): Allow the caller to enter the last name of a user in the
    directory.  This is the default.  If specified, the optional number
    argument will be used for the number of characters the user should enter.
    b(n):  Allow the caller to enter either the first or the last name
    of a user in the directory.  If specified, the optional number argument
    will be used for the number of characters the user should enter.
    m: Instead of reading each name sequentially and asking for
    confirmation, create a menu of up to 8 names.
    p(n): Pause for n milliseconds after the digits are typed.  This
    is helpful for people with cellphones, who are not holding the receiver
    to their ear while entering DTMF.
    NOTE: Only one of the <f>, <l>, or <b> options may be specified.
    *If more than one is specified*, then Directory will act as  if <b> was
    specified.  The number of characters for the user to type defaults to
    '3'.
```

### Lab : Utilisation de l'application directory

1. Modifiez le fichier voicemail.conf pour ajouter deux extension dans le dialplan

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. Créez ces extension dans votre dialplan

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. Allez dans la console et rechargez
4. Composez le 9006 et enregistrez un nom pour chaque extension (4400, 4401)
5. Composez le 9007 et sélectionnez les trois lettres du nom de famille pour une extension (Eas=327). Si c'est la bonne option, appuyez sur « 1 » pour transférer vers le nom.

## Lab : Mise en pratique

Jusqu'à présent, vous avez appris plusieurs concepts de dialplan. Mettons toutes les applications, fonctions et concepts dans un exemple de dialplan afin que vous puissiez comprendre comment ils sont utilisés ensemble. Laissez-nous vous guider à travers la configuration complète du PBX pour le scénario ci-dessous.

- 4 trunks analogiques
- 16 extensions SIP
- 3 classes de service :
    - restrict (interne, local et 1-800)
    - ld (longue distance)
    - ldi (international)
- Message hors heures d'ouverture
- Standard automatique (auto attendant)

### Étape 1 – Configuration des canaux

**Trunks analogiques (`chan_dahdi.conf`).** Tout d'abord, nous allons configurer les trunks analogiques dans le fichier de configuration des canaux DAHDI `chan_dahdi.conf`. Dans ce cas, nous utiliserons une carte T400P Digium avec 4 interfaces FXO. Supposons que le pilote soit déjà chargé et que le fichier de configuration du pilote (/etc/dahdi/system.conf) soit correctement configuré.

![10-dialplan-advanced-features figure 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**Canaux SIP (`pjsip.conf`).** Nous avons choisi la numérotation du dialplan de 2000 à 2099. Deux codecs seront utilisés : G.729 et G.711 ulaw. Le premier sera utilisé pour les téléphones utilisant Asterisk via Internet ou WAN, tandis que le second sera utilisé pour les téléphones utilisant le réseau local. Dans `pjsip.conf`, nous arbitrerons quels appareils appartiendront à chaque classe de service (restrict, ld, ldi). Pour réduire la vulnérabilité aux attaques par force brute, nous utiliserons les adresses MAC des téléphones comme noms d'appareils. Je vous conseille vivement d'utiliser des mots de passe robustes pour éviter les attaques par force brute !

Nous définissons un transport et trois modèles réutilisables — une base d'endpoint avec les codecs partagés, une authentification digest et un AOR à contact unique — puis nous rattachons chaque appareil aux modèles et ne remplaçons que ce qui diffère (son context de classe de service et ses identifiants). `host=dynamic` devient un AOR auprès duquel le téléphone s'enregistre, et `directmedia` devient `direct_media` :

```ini
; pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[endpoint-base](!)
type=endpoint
disallow=all
allow=ulaw,gsm
direct_media=yes

[auth-digest](!)
type=auth
auth_type=digest

[aor-single](!)
type=aor
max_contacts=1

[00001A000002](endpoint-base)
context=restrict
auth=00001A000002
aors=00001A000002
mailboxes=20
[00001A000002](auth-digest)
username=00001A000002
password=#s2cr2t#
[00001A000002](aor-single)

[00001A000003](endpoint-base)
context=ld
dtmf_mode=rfc4733
auth=00001A000003
aors=00001A000003
mailboxes=20
[00001A000003](auth-digest)
username=00001A000003
password=#s3cr3t#
[00001A000003](aor-single)

[00001A000004](endpoint-base)
context=ldi
dtmf_mode=rfc4733
auth=00001A000004
aors=00001A000004
mailboxes=20
[00001A000004](auth-digest)
username=00001A000004
password=#s3cr3t#
[00001A000004](aor-single)
```

### Étape 2 – Configurer le dialplan

Commençons maintenant à configurer le extensions.conf. Définissez les extensions internes et la numérotation locale

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

Définissez les appels LD (longue distance)

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

Définissez les appels internationaux

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Étape 3 - Réception d'appels via un standard automatique

Pour recevoir des appels, utilisez deux contexts. Le premier est pour le fonctionnement aux heures normales, où l'appel sera reçu par un standard automatique. Le second est pour les heures creuses, où l'appelant recevra un message tel que « vous avez appelé la société XYZ, nos heures d'ouverture sont de 08h00 à 18h00 ; si vous connaissez le numéro de l'extension de destination, vous pouvez essayer de le composer maintenant ou raccrocher ». Menus : Heures normales, Heures creuses Dans les menus ci-dessous, le système jouera un message avertissant l'appelant que l'entreprise a été contactée en dehors des heures de travail habituelles, permettant à l'appelant de composer le numéro de l'extension de destination (quelqu'un peut travailler après les heures de travail habituelles).

```
[incoming]
include=>normalhours,08:00-18:00,mon-fri,*,*
include=>afterhours,18:00-23:59,*,*,*
include=>afterhours,00:00-07:59,*,*,*
include=>afterhours,*,sat-sun,*,*
[normalhours]
exten=>s,1,Goto(mainmenu,s,1)
[afterhours]
exten=>s,1,Background(afterhours)
exten=>s,2,hangup()
exten=>i,1,hangup()
exten=>t,1,hangup()
include=>restrict
```

Menus : Principal et Ventes Pendant les heures de travail normales, l'appel est pris en charge par un menu de standard automatique, recevant un message tel que « bienvenue à la société XYZ ; composez le 1 pour les ventes, le 2 pour le support technique, le 3 pour la formation, ou le numéro de l'extension souhaitée ».

```
[globals]
OPERATOR=PJSIP/2060
SALES=PJSIP/2035
TECHSUPPORT=PJSIP/2004
TRAINING=PJSIP/2036
[mainmenu]
exten=> s,1,Background(welcome)
exten=>1,1,Goto(sales,s,1)
exten=>2,1,Goto(techsupport,s,1)
exten=>3,1,Goto(training,s,1)
exten=>i,1,Playback(Invalid)
exten=>i,2,hangup()
exten=>t,1,Dial(${OPERATOR},20,Tt)
include=>restrict
[sales]
exten=>s,1,Dial(${SALES},20,Tt)
[techsupport]
exten=>s,1,Dial(${TECHSUPPORT},20,Tt)
[training]
exten=>s,1,Dial(${TRAINING},20,Tt)
```

Avec toutes ces instructions, la fonctionnalité de votre dialplan est maintenant prête. Dans la section suivante, nous démontrerons comment exploiter le PBX.

## Résumé

Dans ce chapitre, vous avez appris à recevoir des appels en utilisant un IVR ou un standard automatique. Vous avez étudié le concept d'inclusion de contextes et mis en œuvre quelques exemples. Des sous-routines ont été utilisées pour éviter la saisie répétitive, et la base de données Asterisk (AstDB, prise en charge par SQLite3 dans Asterisk 22) a été utilisée pour les fonctions nécessitant un stockage de données (par exemple, le transfert d'appel, le mode ne pas déranger, les listes noires). Enfin, vous avez appris à mettre en œuvre un comportement pour les heures de fermeture et avez implémenté un dialplan complet en utilisant ces concepts.

## Quiz

1. Une inclusion de context dépendante du temps utilise la forme `include => context,<times>,<weekdays>,<mdays>,<months>`. Que fait `include => normalhours,08:00-18:00,mon-fri,*,*` ?
   - A. Exécuter les extensions du lundi au vendredi, de 08:00 à 18:00
   - B. Exécuter les options tous les jours de tous les mois
   - C. Rien ; le format est invalide
2. Dans l'Asterisk moderne (y compris Asterisk 22), les champs d'un `include =>` basé sur le temps et de `GotoIfTime()` sont séparés par quel caractère ?
   - A. Le pipe `|`
   - B. La virgule `,`
   - C. Le point-virgule `;`
   - D. La barre oblique `/`
3. Pour appeler plusieurs canaux à la fois (en les faisant sonner simultanément), vous les séparez à l'intérieur de `Dial()` avec le caractère ___.
4. Un menu vocal qui joue une invite tout en attendant que l'appelant compose une extension est généralement créé avec l'application ___.
5. Vous pouvez inclure le contenu d'un autre fichier à l'intérieur de `extensions.conf` en utilisant l'instruction ___ (note : ceci est différent de l'instruction de context `include =>`).
6. Dans Asterisk 22, la base de données intégrée AstDB est supportée par :
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. Lorsque vous utilisez `Dial(type1/identifier1&type2/identifier2)`, Asterisk appelle chaque canal en séquence, en attendant 20 secondes entre eux.
   - A. Faux
   - B. Vrai
8. Avec l'application Background(), vous devez attendre que le message ait fini de jouer avant de pouvoir appuyer sur un chiffre DTMF pour choisir une option.
   - A. Faux
   - B. Vrai
9. Étant donné la syntaxe `Goto([[context,]extension,]priority)`, lesquelles des invocations suivantes de l'application Goto() sont valides ? (cochez toutes les réponses qui s'appliquent)
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Pour supprimer une seule clé d'AstDB dans le dialplan d'Asterisk 22, vous utilisez :
    - A. L'application `DBdel()`
    - B. La fonction `DB_DELETE()`
    - C. L'application `DBdeltree()`
    - D. L'application `LookupBlacklist()`

**Réponses :** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
