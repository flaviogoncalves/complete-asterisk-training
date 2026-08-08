# Utilisation des fonctionnalités PBX

Dans les systèmes SIP, la plupart des fonctionnalités téléphoniques sont implémentées au niveau de l'endpoint. Il existe une grande variété de téléphones SIP et de fabricants, et l'interopérabilité n'est pas garantie. L'équipe de développement d'Asterisk a accompli un travail remarquable en implémentant la plupart des fonctionnalités directement dans le PBX, rendant Asterisk presque indépendant de l'endpoint. Cependant, il arrive parfois que la même fonction soit assurée à la fois par le téléphone et par Asterisk lui-même. L'intégration du téléphone et du PBX est la prochaine frontière en matière de convivialité, et c'est là que les systèmes propriétaires concentrent leurs efforts actuellement. Dans ce chapitre, vous apprendrez à utiliser la plupart de ces fonctionnalités.

## Objectifs

À la fin de ce chapitre, vous serez en mesure de comprendre et d'utiliser :

- Call Parking
- Call Pickup
- Call Transfer
- Call Conference (ConfBridge)
- Call Recording
- Music on hold

## Où les fonctionnalités sont implémentées

Avant tout, il est important de comprendre quand les fonctionnalités du PBX sont exécutées par rapport au moment où le téléphone effectue tout le travail. Par exemple, vous pouvez transférer un appel en utilisant le bouton TRANSFER sur le téléphone ou en composant # (transfert inconditionnel exécuté par le PBX lui-même).

## Fonctionnalités implémentées par Asterisk

Ces fonctionnalités sont implémentées dans le PBX par le code Asterisk :

- Music on hold
- Call parking
- Call pickup
- Call recording
- ConfBridge conference room
- Call transfer (blind and consultative)

## Fonctionnalités généralement implémentées par le dialplan

Ces fonctionnalités doivent être programmées dans le dialplan Asterisk (extensions.conf) :

- Renvoi d'appel sur occupation
- Renvoi d'appel immédiat
- Renvoi d'appel sur non-réponse
- Filtrage d'appels (liste noire)
- Ne pas déranger
- Rappel automatique

## Fonctionnalités généralement implémentées par le téléphone

Ces fonctionnalités sont implémentées par le micrologiciel du téléphone :

![Où les fonctionnalités du PBX sont généralement implémentées : dans Asterisk lui-même, dans le dialplan, ou dans le téléphone](../images/13-pbx-features-fig01.png)

- Mise en attente d'appel
- Transfert aveugle
- Transfert avec consultation
- Conférence à trois
- Indicateur de message en attente

## Le fichier de configuration des fonctionnalités

Certaines des fonctionnalités présentées dans ce chapitre sont configurées dans le fichier de configuration features.conf. Il est possible de modifier le comportement de certaines fonctionnalités en modifiant ce fichier. Nous avons inclus l'extrait pertinent ci-dessous. Dans les sections suivantes de ce chapitre, nous décrirons chaque fonctionnalité. Extrait du fichier exemple (Asterisk 22)

![La section `[featuremap]` de features.conf, avec les codes de fonctionnalité DTMF par défaut](../images/13-pbx-features-fig02.png)

Depuis Asterisk 12, le parcage d'appel a été retiré de `features.conf` pour être intégré dans son propre module, `res_parking`, avec une configuration dans `res_parking.conf`. Le bloc parking-lot ci-dessous (`parkext`, `parkpos`, `context`, `parkingtime`, et ainsi de suite) se trouve dans `res_parking.conf`. La section `[featuremap]` (les codes de fonctionnalité DTMF, incluant `parkcall`) demeure dans `features.conf`.

Les options de parking-lot se trouvent dans `res_parking.conf`. Un parking-lot nommé `default` existe toujours, même s'il n'est pas présent dans le fichier de configuration. L'extrait ci-dessous est tiré du fichier `res_parking.conf.sample` d'Asterisk 22 :

```
; res_parking.conf
[default]                       ; Default Parking Lot
parkext => 700                  ; What extension to dial to park. (optional; if
                                ; specified, extensions will be created for parkext and
                                ; the whole range of parkpos)
parkpos => 701-720              ; What range of parking spaces to use - must be numeric.
                                ; Creates these spaces as extensions if parkext is set.
context => parkedcalls          ; Which context parked calls and the default park
                                ; extension are created in
;parkingtime => 45             ; Number of seconds a call can be parked before returning
;comebacktoorigin = yes        ; When a parked call times out, attempt to send it back to
                               ; the peer that parked it (default is yes)
;courtesytone = beep           ; Sound file to play when someone picks up a parked call
;parkedplay = caller           ; Who to play courtesytone to: parked, caller, both (default caller)
;parkedcalltransfers = caller  ; Enable DTMF transfers when picking up a parked call (default no)
;parkedcallreparking = caller  ; Enable DTMF parking when picking up a parked call (default no)
;parkedcallhangup = caller     ; Enable DTMF hangups when picking up a parked call (default no)
;findslot => next              ; 'next' uses the next space after the most recently used one;
                               ; 'first' (default) uses the lowest-numbered space available
;parkedmusicclass = default    ; MOH class to use for the parked channel
```

Les codes de fonctionnalité DTMF (incluant le `parkcall` en une étape) demeurent dans la section `[featuremap]` de `features.conf` :

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## Transfert d'appel

Le transfert d'appel peut être mis en œuvre par le téléphone, par un ATA ou par Asterisk lui-même. Reportez-vous au manuel de votre téléphone pour comprendre comment les appels sont transférés. Si votre téléphone ne prend pas en charge le transfert d'appel, vous pouvez utiliser Asterisk pour accomplir cette tâche. Le transfert d'appel est mis en œuvre de deux manières différentes.

La première méthode consiste à utiliser la fonctionnalité de transfert aveugle : composez # suivi du numéro vers lequel l'appel doit être transféré. Parfois, vous utiliserez la fonctionnalité de transfert de votre téléphone IP ou de votre softphone IP. Vous pouvez modifier le caractère de transfert en éditant le paramètre blindxfer dans le fichier features.conf.

Vous pouvez activer le transfert assisté dans Asterisk en supprimant le ; devant le paramètre atxfer dans le fichier features.conf. Pendant une conversation, vous devez appuyer sur *2. Asterisk dira "transfer" et vous donnera une tonalité. L'appelant est envoyé vers la musique d'attente. Après avoir parlé à la personne destinataire et raccroché le téléphone, le système relie l'appelant à la destination.

![Transfert d'appel : les étapes pour un transfert aveugle (appuyez sur # pendant l'appel) et un transfert assisté (appuyez sur *2)](../images/13-pbx-features-fig03.png)

### Liste des tâches de configuration

1. Pour un endpoint PJSIP, assurez-vous que l'option `direct_media` est définie sur `no` (afin que le flux média passe par Asterisk et que les codes de fonctionnalité soient détectés), ou utilisez une option `t`/`T` dans l'application `Dial()`

## Call parking

Cette fonctionnalité est utilisée pour mettre un appel en attente (parking). Cela est utile, par exemple, lorsque vous répondez à un appel téléphonique en dehors de votre bureau et que vous souhaitez transférer l'appel vers votre poste. Vous pouvez y parvenir en garant l'appel sur une extension. Une fois arrivé à votre bureau, composez simplement le numéro de l'extension de parking pour récupérer l'appel.

![Call parking : composez 700 pour garer un appel dans le premier emplacement libre (701–720) ; Asterisk annonce l'emplacement, que vous composez depuis n'importe quel téléphone pour récupérer l'appel](../images/13-pbx-features-fig04.png)

Par défaut, l'extension 700 est utilisée pour garer un appel. Au milieu d'une conversation, appuyez sur # pour transférer l'appel vers l'extension 700. Asterisk annoncera alors votre extension de parking, telle que 701 ou 702. Raccrochez le téléphone et l'appelant sera mis en attente. Allez à votre téléphone de bureau et composez l'extension de parking annoncée pour récupérer l'appel. Si l'appelant reste en attente trop longtemps, la fonctionnalité de timeout se déclenchera et l'extension initialement appelée sonnera à nouveau.

### Liste des tâches de configuration

Suivez les étapes ci-dessous pour activer le call parking. Étape 1 : Rendez le parking lot accessible depuis votre dialplan (requis). Le `context` du parking lot par défaut est `parkedcalls` (défini dans `res_parking.conf`). Incluez ce context dans le context depuis lequel vos téléphones appellent, dans `extensions.conf` :

```
include => parkedcalls
```

Étape 2 : Testez la fonctionnalité de call parking en composant #700. Notes :

- L'extension de parking ne sera pas affichée dans la commande CLI dialplan show.
- Il est nécessaire de recharger le module de parking après avoir modifié le fichier de configuration du parking : `module reload res_parking.so`. Pour les modifications dans features.conf, `module reload features.so`.
- Pour garer un appel, vous devez transférer vers #700. Vérifiez les options `t` et `T` dans l'application `Dial()`.

## Call pickup

Call pickup vous permet de récupérer un appel provenant d'un collègue appartenant au même groupe d'appel. Cela permet d'éviter, par exemple, de devoir se lever pour répondre à un appel qui sonne sur le poste d'une autre personne dans votre bureau, mais qui n'est pas présente. En composant *8, vous pouvez récupérer un appel au sein de votre groupe d'appel. Ce numéro peut être modifié dans le fichier `features.conf`.

![Call pickup : les membres ne peuvent récupérer que les appels au sein de leur propre groupe ; l'opérateur (pickupgroup=1,2,3) peut récupérer les appels de chaque groupe](../images/13-pbx-features-fig05.png)

### Liste des tâches de configuration

Suivez les étapes ci-dessous pour configurer la fonctionnalité Call pickup. Étape 1 : Configurez un groupe d'appel pour vos extensions. Cela s'effectue dans le fichier de configuration du canal (pjsip.conf, iax.conf, chan_dahdi.conf). Pour les endpoints PJSIP, définissez `call_group` et `pickup_group` dans la section endpoint de `pjsip.conf` (pjsip.conf utilise des noms d'options en snake_case). Cette tâche est obligatoire.

Pour PJSIP (pjsip.conf) :
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


Étape 2 : Modifiez le numéro de la fonctionnalité call-pickup (optionnel). Celui-ci est défini dans la section `[general]` de `features.conf`, et non dans `pjsip.conf` :

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## Conférence (appel en conférence)

Il existe différentes manières de mettre en œuvre une conférence sur Asterisk. La première option consiste simplement à utiliser la capacité de conférence à trois du téléphone. En utilisant cette fonctionnalité dans le téléphone, vous n'avez besoin d'aucun support dans le serveur lui-même. Cependant, lorsque vous souhaitez une conférence avec plus de 3 personnes, vous devez utiliser une salle de conférence. L'application de conférence moderne d'Asterisk est ConfBridge (`app_confbridge`).

ConfBridge prend en charge les conférences vocales HD et la visioconférence. Il existe certaines limitations pour la visioconférence, comme l'absence de transcodage — tous les participants doivent utiliser le même codec et le même profil. La visioconférence utilise un mode « suivre le locuteur », affichant l'image de la dernière personne à avoir parlé. Vous pouvez facilement configurer de nouveaux menus DTMF dans ConfBridge.

ConfBridge remplace l'ancienne application MeetMe, qui a été dépréciée dans Asterisk 19. MeetMe est toujours présent dans l'arborescence source d'Asterisk 22, mais il dépend de DAHDI et n'est pas compilé par défaut ; ainsi, sur une installation PJSIP typique, il est tout simplement indisponible — ConfBridge est l'application de conférence prise en charge. Contrairement à MeetMe, ConfBridge ne nécessite **pas** de DAHDI ou de source de synchronisation matérielle : il s'appuie sur l'interface de synchronisation intégrée d'Asterisk (`res_timing_timerfd` sur Linux, ou `res_timing_pthread`), donc aucun module `dahdi_dummy` n'est nécessaire. Si vous migrez depuis un ancien système qui utilisait `MeetMe()` et `meetme.conf`, remplacez-les par `ConfBridge()` et `confbridge.conf` comme décrit ci-dessous.

### ConfBridge

Pour démarrer une salle de conférence, la syntaxe est indiquée ci-dessous.

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

Pour obtenir une description complète de la commande, vous pouvez utiliser core show application confbridge.

![Sortie de `core show application confbridge`, montrant le synopsis, la syntaxe et les arguments bridge_profile, user_profile et menu](../images/13-pbx-features-fig06.png)

![Plusieurs endpoints PJSIP rejoignent une conférence ConfBridge nommée (101) ; un participant est l'administrateur. Le mixage et la synchronisation sont gérés par `app_confbridge` avec `bridge_softmix` et le minuteur intégré `res_timing_*` — aucun DAHDI requis.](../images/13-pbx-features-fig09.png)

Comme vous pouvez le voir ci-dessus, il y a trois arguments importants, chacun correspondant à un type de section dans `confbridge.conf`. **bridge_profile** (une section `type=bridge`) : ici, vous sélectionnez le nombre maximum de participants (`max_members`), l'enregistrement (`record_conference`), `video_mode` et de nombreux autres paramètres à l'échelle du pont.

Il n'est pas logique de reproduire l'exemple complet ici, alors permettez-moi de vous donner un exemple simple sur la façon de configurer un bridge_profile dans le fichier confbridge.conf.

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile** (une section `type=user`) : ici, vous définissez des options spécifiques par utilisateur, telles que si l'utilisateur est un administrateur (`admin=yes`), s'il commence en mode muet (`startmuted=yes`), la musique d'attente et de nombreuses autres options par utilisateur. Exemple :

```
[admin_user]
type=user
admin=yes
```

**menu** (une section `type=menu`) : ici, vous définissez le mappage du clavier (DTMF) pour la conférence — par exemple, quelle touche active/désactive le mode muet, ajuste le volume ou quitte la conférence. Consultez le fichier `confbridge.conf.sample` pour voir toutes les actions disponibles. Exemple :

```
[my_menu]
type=menu
*=playback_and_continue
1=toggle_mute
2=decrease_listening_volume
3=increase_listening_volume
4=decrease_talking_volume
5=increase_talking_volume
6=leave_conference
```

#### Fonctions Confbridge

Les options du pont de conférence peuvent être transmises dynamiquement dans le dialplan en utilisant la fonction CONFBRIDGE(). Voir les exemples ci-dessous :

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### Commandes d'administration ConfBridge et migration depuis MeetMe

Si vous venez de MeetMe, les fonctions d'administration que vous utilisiez via `MeetMeAdmin()` et l'option `a` (admin) sont désormais exprimées via le **profil utilisateur administrateur** (`admin=yes`) ainsi que les actions du **menu**. Un administrateur qui rejoint avec un profil administrateur et un menu contenant des actions d'administration peut verrouiller la salle, expulser des utilisateurs et mettre des participants en sourdine en direct depuis le clavier. Les actions de menu pertinentes dans `confbridge.conf` sont :

- `admin_kick_last` -- expulser le dernier utilisateur ayant rejoint
- `admin_toggle_mute_participants` -- mettre en sourdine/rétablir le son de tous les participants non administrateurs
- `toggle_mute` -- mettre en sourdine/rétablir votre propre son
- `participant_count` -- annoncer le nombre de participants
- `leave_conference` -- quitter le pont et continuer dans le dialplan

Celles-ci remplacent les indicateurs d'option MeetMe `MeetMe()` (`a`, `A`, `m`, `M`, `l`, `x`, …) et les commandes `MeetMeAdmin()` (`k`, `K`, `L`, `M`, `N`, …). Sur une installation PJSIP moderne, vous ne chargerez pas du tout `app_meetme` ; toute la configuration de la conférence réside dans `confbridge.conf`, et les modifications sont appliquées avec `module reload app_confbridge.so` (la logique ConfBridge réside dans `app_confbridge` ; il n'y a pas de module `res_confbridge`).

### Exemple ConfBridge

Pour créer une salle de conférence accessible à l'extension 500, dans `extensions.conf` :

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

Le premier appelant à composer le 500 crée la conférence `101` ; les appelants suivants la rejoignent. Les profils et menus référencés ici (`default_bridge`, `default_user`, `sample_user_menu`) sont définis dans `confbridge.conf`. Pour exiger un code PIN, définissez `pin=` dans le profil utilisateur ; pour faire d'un participant un administrateur de conférence, donnez-lui un profil utilisateur avec `admin=yes`.

## Enregistrement d'appels

Il existe plusieurs façons d'enregistrer un appel dans Asterisk. Vous pouvez utiliser l'application `MixMonitor()` pour enregistrer facilement des appels. (L'ancienne application `Monitor`, qui enregistrait deux fichiers séparés, a été supprimée ; utilisez `MixMonitor` à la place.)

### Utilisation de l'application MixMonitor

L'application `MixMonitor` enregistre l'audio du canal actuel dans le fichier spécifié. Si le nom du fichier est un chemin absolu, elle utilise ce chemin. Sinon, elle crée le fichier dans le répertoire de surveillance configuré dans asterisk.conf.

![L'application MixMonitor() : enregistre et mixe l'audio d'un canal dans un fichier, avec des options pour ajouter, pont uniquement et réglage du volume](../images/13-pbx-features-fig09.png)

### MixMonitor()

Enregistre un appel et mixe l'audio pendant l'enregistrement. Syntaxe : `MixMonitor(filename.extension[,options[,command]])`. Enregistre l'audio du canal actuel dans le fichier spécifié. Options valides :

- a - Ajoute au fichier au lieu de l'écraser.
- b - Sauvegarde l'audio dans le fichier uniquement lorsque le canal est ponté.
- Note : n'inclut pas les conférences.
- v(<x>) - Ajuste le volume audible par un facteur de <x> (allant de -4 à 4)
- V(<x>) - Ajuste le volume parlé par un facteur de <x> (allant de -4 à 4)
- W(<x>) - Ajuste les volumes audible et parlé par un facteur de <x> (allant de -4 à 4)
- <command> sera exécutée lorsque l'enregistrement sera terminé. Toutes les chaînes correspondant à ^{X} seront déséchappées en ${X} et toutes les variables seront évaluées à ce moment-là. La variable MIXMONITOR_FILENAME contiendra le nom du fichier utilisé pour l'enregistrement.

Une ressource intéressante est la fonctionnalité d'enregistrement à une touche `automixmon`, qui permet à une partie de composer un code DTMF (l'exemple `features.conf` suggère `*3` ; il n'y a pas de valeur par défaut intégrée, vous devez donc le définir) pendant un appel pour démarrer immédiatement (et désactiver) l'enregistrement. Elle est basée sur MixMonitor, elle écrit donc un seul fichier mixé. Exemple :

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

Les options `X` et `x` activent la fonctionnalité MixMonitor à une touche pour l'appelant et l'appelé respectivement. Comme MixMonitor enregistre un seul fichier mixé, il n'est pas nécessaire de combiner des fichiers IN/OUT séparés par la suite (l'ancienne approche `automon`/`Monitor`, qui produisait deux fichiers pour `soxmix`, a été supprimée avec l'application `Monitor`).

Si vous ne souhaitez pas utiliser Set() avant l'application Dial(), vous pouvez définir ceci dans la section globals :

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### Musique d'attente (Music on hold)

La musique d'attente (MOH) a changé plusieurs fois entre les versions 1.0, 1.2 et 1.4. Dans la dernière version, la MOH utilise par défaut "FILE-BASED". En d'autres termes, Asterisk fournira les fichiers MOH dans des formats tels que g729, alaw, ulaw et gsm. Ainsi, il n'est pas nécessaire de transcoder la musique avant de l'envoyer au canal. Cela économise du temps processeur, ce qui est une modification bienvenue pour ceux qui travaillent avec des systèmes en production.

Dans les anciennes versions, la MOH était généralement fournie par MP3 (elle peut toujours être configurée de cette façon). Fournir la MOH en utilisant le MP3 oblige Asterisk à transcoder, consommant une précieuse puissance CPU dans le processus.

Le nouveau fichier de configuration est présenté ci-dessous. Notez que la classe par défaut utilise désormais le mode de format de fichier natif mode=files. Tous les autres modes sont commentés. Chaque section est une classe. La seule classe non commentée à ce stade est default. Si vous souhaitez avoir des classes différentes pour des fichiers différents, vous devrez créer de nouvelles sections (classes).

![L'exemple de configuration musiconhold.conf, listant les modes MOH valides (quietmp3, mp3, custom, files, …)](../images/13-pbx-features-fig10.png)

```
; Music on Hold -- Sample Configuration
;[samplemp3]
;mode=quietmp3
;directory=/var/lib/asterisk/mohmp3
;
; valid mode options:
; quietmp3      -- default
; mp3           -- loud
; mp3nb         -- unbuffered
; quietmp3nb    -- quiet unbuffered
; custom        -- run a custom application (See examples below)
; files         -- read files from a directory in any Asterisk supported
;                  media format. (See examples below)
;[manual]
;mode=custom
; Note that with mode=custom, a directory is not required, such as when reading
; from a stream.
;directory=/var/lib/asterisk/mohmp3
;application=/usr/bin/mpg123 -q -r 8000 -f 8192 -b 2048 --mono -s
;[ulawstream]
;mode=custom
;application=/usr/bin/streamplayer 192.168.100.52 888
;format=ulaw
; mpg123 on Solaris does not always exit properly; madplay may be a better
; choice
;[solaris]
;mode=custom
;directory=/var/lib/asterisk/mohmp3
;application=/site/sw/bin/madplay -Q -o raw:- --mono -R 8000 -a -12
;
;
; File-based (native) music on hold
;
; This plays files directly from the specified directory, no external
; processes are required. Files are played in normal sorting order
; (same as a sorted directory listing), and no volume or other
; sound adjustments are available. If the file is available in
; the same format as the channel's codec, then it will be played
; without transcoding (same as Playback would do in the dialplan).
; Files can be present in as many formats as you wish, and the
; 'best' format will be chosen at playback time.
;
; NOTE:
; If you are not using "autoload" in modules.conf, then you
; must ensure that the format modules for any formats you wish
; to use are loaded _before_ res_musiconhold. If you do not do
; this, res_musiconhold will skip the files it is not able to
; understand when it loads.
;
[default]
mode=files
directory=/var/lib/asterisk/moh
;
;[native-random]
;mode=files
;directory=/var/lib/asterisk/moh
;random=yes     ; Play the files in a random order
```

### Tâches de configuration MOH

Maintenant, pour utiliser la musique d'attente, définissez la classe MOH dans les fichiers de configuration des canaux (chan_dahdi.conf, pjsip.conf, iax.conf, etc.). Pour les endpoints PJSIP, définissez `moh_suggest` dans la section endpoint de `pjsip.conf` (l'ancien nom d'option `musicclass` s'applique à chan_dahdi et aux autres pilotes de canaux, pas à PJSIP). Les morceaux freeplay installés sont maintenant au format wav. Au moment de l'installation, vous pouvez sélectionner (en utilisant make menuselect) les formats de fichiers MOH disponibles. Si vous souhaitez ajouter de nouveaux fichiers MOH, vous devrez les fournir dans les formats requis. Par exemple :

Dans `/etc/asterisk/chan_dahdi.conf`, ajoutez la ligne `musiconhold` :

```
[channels]
musiconhold=default
```

Ensuite, modifiez `/etc/asterisk/musiconhold.conf` pour définir cette classe :

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

Dans le dialplan, vous pouvez démarrer la musique d'attente sur un canal avec `StartMusicOnHold` (et l'arrêter avec `StopMusicOnHold`) :

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

Pour jouer de la musique d'attente pendant une durée fixe comme test rapide, utilisez l'application `MusicOnHold` avec une durée (en secondes) :

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## Application Maps

Les Application Maps vous permettent d'ajouter de nouvelles fonctionnalités en utilisant la section `[applicationmap]` du fichier features.conf. Supposons que vous ayez besoin d'identifier le type de client auquel vous répondez dans un centre d'appels. Vous pourriez créer une application map pour chaque type de client, ce qui permettrait de compter le nombre de clients répondus par type.

## Résumé

Dans ce chapitre, vous avez appris où résident les fonctionnalités PBX d'Asterisk — certaines dans le noyau, d'autres dans le dialplan, et certaines sur le téléphone — et comment les codes de fonction DTMF sont mappés dans la section `[featuremap]` de `features.conf`. Vous avez configuré le **transfert d'appel** (aveugle et supervisé) et le **parcage d'appel** (`res_parking.conf`, avec les options de Dial `k`/`K` et le lot `parkedcalls`), la **prise d'appel** par groupe, et la **conférence** avec **ConfBridge** (profils de bridge/user/menu `confbridge.conf`), qui remplace l'ancien MeetMe. Vous avez mis en place l'**enregistrement à une touche** avec MixMonitor (`automixmon`, les options de Dial `X`/`x`, et `DYNAMIC_FEATURES`), configuré la **musique d'attente**, et vu comment les **application maps** vous permettent de lier votre propre logique de dialplan à une séquence DTMF. Avec ces briques de base, vous pouvez fournir les fonctionnalités quotidiennes que les utilisateurs attendent d'un PBX d'entreprise.

## Quiz

1. Quelles affirmations sont vraies concernant la mise en attente d'appel (call parking) ?
   - A. Par défaut, l'extension 800 est utilisée pour la mise en attente d'appel.
   - B. Lorsque vous êtes loin de votre bureau et que vous recevez un appel, vous pouvez le mettre en attente ; le système annonce l'emplacement de mise en attente, et vous composez ce numéro depuis n'importe quel téléphone pour récupérer l'appel.
   - C. Par défaut, l'extension 700 met un appel en attente, et les appels sont placés dans les emplacements 701–720.
   - D. Vous composez 700 pour récupérer un appel mis en attente.
2. Pour utiliser la fonctionnalité de prise d'appel (call-pickup), toutes les extensions doivent être dans le même ___. Pour les canaux DAHDI, cela est configuré dans le fichier ___.
3. Lors du transfert d'un appel, vous pouvez choisir entre un transfert ___, où la destination n'est pas consultée au préalable, et un transfert ___, où vous parlez à la destination avant de finaliser l'opération.
4. Pour effectuer un transfert assisté (consultatif), vous utilisez la séquence ___ ; pour un transfert aveugle, vous utilisez ___.
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. Pour héberger des conférences téléphoniques dans Asterisk 22, vous utilisez l'application ___.
6. Dans ConfBridge, un participant obtient des privilèges d'administrateur (expulser, mettre les autres en sourdine, verrouiller la salle) en définissant ___ dans son profil utilisateur (`confbridge.conf`) :
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. Le meilleur format pour la musique d'attente (music on hold) est le MP3, car il utilise très peu de puissance de traitement sur le serveur Asterisk.
   - A. Vrai
   - B. Faux
8. Pour prendre un appel provenant d'un groupe d'appel spécifique, vous devez être dans le groupe ___ correspondant.
9. Vous pouvez enregistrer un appel avec l'application MixMonitor() ou la fonctionnalité d'enregistrement à une touche (`automixmon`). Dans l'exemple `features.conf`, `automixmon` est associé à la séquence DTMF ___.
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. Dans ConfBridge, quelle option de profil utilisateur `confbridge.conf` permet à un participant de rejoindre la conférence en sourdine (il peut entendre la conférence mais ne peut pas être entendu tant qu'il n'a pas désactivé la sourdine) ?
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**Réponses :** 1 — B, C · 2 — pickup group ; `chan_dahdi.conf` · 3 — blind ; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
