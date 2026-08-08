# Installation d'Asterisk 22

Dans le premier chapitre, nous avons appris comment Asterisk est utile dans l'environnement de la téléphonie. Dans ce chapitre, nous verrons comment télécharger et installer Asterisk. Avant de commencer, il est essentiel d'apprendre à le compiler et à l'installer. Le processus de compilation peut sembler étrange pour les utilisateurs traditionnels de Microsoft™ Windows™, mais il est assez courant dans l'environnement Linux™. On peut obtenir un code optimisé pour son matériel lors de la compilation d'Asterisk, ce que nous ferons ici. Asterisk fonctionne sur plusieurs systèmes d'exploitation, mais nous simplifierons les choses en n'en utilisant qu'un seul : Linux. Nous utilisons **Ubuntu 24.04 LTS** car ses dépendances sont faciles à installer et il s'agit d'une distribution serveur stable, bien prise en charge et à faible empreinte. Si vous préférez une autre distribution, ajustez les noms des paquets en conséquence.

Cette édition cible **Asterisk 22 LTS** (publiée le 2024-10-16 ; support complet jusqu'au 2028-10-16, correctifs de sécurité jusqu'au 2029-10-16). Asterisk 22 est la version actuelle avec support à long terme. Notez que Digium a été acquis par **Sangoma** en 2018, et qu'Asterisk est désormais sponsorisé par Sangoma — les références à « Digium » tout au long de ce chapitre font référence à la marque historique pour le matériel ancien.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Déterminer les prérequis matériels pour Asterisk ;
- Installer Linux avec les dépendances requises ;
- Télécharger une version stable via HTTPS ;
- Compiler Asterisk ; et
- Apprendre comment démarrer Asterisk au moment du démarrage du système.

## Matériel minimum requis

Asterisk n'a pas besoin de beaucoup de matériel pour fonctionner, cependant il existe quelques conseils pour choisir le meilleur matériel selon vos besoins. Vous devriez prendre en considération les facteurs principaux suivants lors du choix de votre matériel :

- Nombre total d'utilisateurs enregistrés. Définissez combien d'enregistrements par seconde vous devez prendre en charge.
- Nombre total d'appels simultanés. Définissez combien de conversations réseau vous devez traiter au niveau de la carte réseau et du pont sur le serveur Asterisk.
- Quels codecs vous devez prendre en charge. Les codecs à haute complexité nécessiteront beaucoup de puissance CPU/FPU sur votre serveur ; l'iLBC, par exemple, a été mesuré par son créateur (Global IP Sound) à environ 18 MIPS par canal pour des trames de 30 ms (et environ 15 MIPS pour des trames de 20 ms) sur un DSP TI C54x.
- Annulation d'écho. L'annulation d'écho peut consommer beaucoup de CPU/FPU ; dans certains cas, vous devriez choisir une annulation d'écho matérielle utilisant des DSP sur la carte d'interface de téléphonie.
- Disponibilité. Utilisez RAID1 ou 5 pour augmenter la disponibilité. N'oubliez pas qu'Asterisk est une application 24x7.

Le composant principal pour un serveur Asterisk est la carte réseau. Une bonne carte réseau de serveur est recommandée. Le CPU est important lorsque vous devez prendre en charge des codecs à haute complexité tels que g.729 et iLBC, ainsi que l'annulation d'écho. Vous pouvez choisir de décharger cela vers des DSP dédiés : Sangoma (anciennement Digium) fournit une carte DSP nommée TC400B capable de prendre en charge 120 appels G.729 simultanés.

La meilleure pratique consiste à choisir un ordinateur neuf, de classe serveur, provenant d'un fabricant reconnu. Pour savoir exactement combien d'appels simultanés ou combien d'utilisateurs enregistrés une machine spécifique peut prendre en charge, vous devriez tester ce matériel avec un outil de test de charge tel que SIPP (http://sipp.sourceforge.net). Certains fabricants de matériel tels que Xorcom (http://www.xorcom.com) publient leurs résultats sur leur site web.

Note : Certaines applications Asterisk, telles que ConfBridge et la musique d'attente, ont besoin d'une source de temporisation interne. Sur les systèmes Linux modernes, celle-ci est fournie automatiquement par le module intégré `res_timing_timerfd` — aucun matériel de téléphonie n'est requis. (L'ancien minuteur logiciel `dahdi_dummy` n'existe plus ; sa fonctionnalité a été intégrée au module noyau principal `dahdi` dans DAHDI Linux 2.3.0.) Vous pouvez confirmer le minuteur actif avec la commande CLI `timing test`.

### Configuration matérielle

Le matériel pour Asterisk n'a pas besoin d'être sophistiqué. Vous n'avez pas besoin d'une carte vidéo coûteuse ou de nombreux périphériques. Quelques conseils sur la configuration matérielle :

- Désactivez les ports USB, série et parallèles inutilisés pour éviter la consommation d'interruptions inutiles.
- Une carte d'interface réseau robuste est essentielle.
- Soyez particulièrement vigilant si vous utilisez des cartes d'interface de téléphonie. Certaines cartes utilisent un bus PCI 3,3 volts, et il n'est pas facile de trouver des cartes mères pour celles-ci. De nos jours, le PCI express est plus facilement disponible.
- Accordez une attention particulière au disque dur ; un PBX est utilisé pour fonctionner en régime 24x7 alors que les ordinateurs de bureau fonctionnent en 8x5. N'utilisez pas de matériel de bureau pour un PBX, le disque dur tombe généralement en panne avant la première année. Ma recommandation est d'utiliser une machine serveur ou un appareil conçu pour exécuter des applications 24x7.

### Partage d'IRQ (cartes PCI héritées uniquement)

Cette préoccupation s'applique **uniquement** si vous installez des cartes de téléphonie physiques PCI/PCI-Express (matériel DAHDI). De telles cartes génèrent un grand nombre d'interruptions, et sur les anciens systèmes à processeur unique, partager une ligne IRQ avec un autre périphérique pourrait affamer le pilote et dégrader la qualité de la voix. Si vous utilisez des cartes de téléphonie, dédiez la machine à Asterisk, désactivez tous les périphériques intégrés inutilisés dans le BIOS et vérifiez les interruptions assignées avec `cat /proc/interrupts`. Les serveurs multi-cœurs modernes utilisant les interruptions MSI/MSI-X font du partage d'IRQ un problème inexistant en pratique, et un déploiement purement VoIP (sans cartes) n'a pas à s'en soucier du tout.

## Choisir une distribution Linux

Asterisk a été initialement développé pour fonctionner sous Linux. Cependant, il peut également fonctionner sous BSD Unix ou macOS. Si vous débutez avec Asterisk, essayez d'abord d'utiliser Linux car c'est beaucoup plus simple. Asterisk cible officiellement la famille RHEL (CentOS/RHEL/Fedora), Ubuntu et Debian. De bons choix pratiques aujourd'hui sont **Debian 12**, **Ubuntu 22.04 LTS / 24.04 LTS** et **Rocky Linux 9 / AlmaLinux 9** — CentOS Linux étant en fin de vie, préférez Rocky ou AlmaLinux sur les systèmes de la famille RHEL. Pour ce livre, j'utiliserai Ubuntu 24.04 LTS. Téléchargez la dernière image serveur de la version mineure 24.04 depuis le répertoire officiel des versions ci-dessous (le nom de fichier exact inclut la version mineure actuelle, par ex. `ubuntu-24.04.4-live-server-amd64.iso`) :

```
https://releases.ubuntu.com/24.04/
```

### Préparer Linux pour Asterisk

Avant de compiler Asterisk, vous avez besoin d'un système Linux fonctionnel avec les paquets de compilation installés. Installez **Ubuntu 24.04 LTS Server** dans une machine virtuelle ou sur une machine dédiée (utilisez l'image 64 bits ; tout dans ce livre est en 64 bits, bien qu'Asterisk lui-même prenne toujours en charge le x86 32 bits). Nous avons utilisé VirtualBox pour cette formation ; vous pouvez télécharger l'image depuis <https://releases.ubuntu.com/24.04>. L'installation de Linux en soi dépasse le cadre de ce livre — une connaissance de base de Linux est un prérequis. Une fois Linux installé, vous ajouterez les dépendances de compilation d'Asterisk (voir *Installer les dépendances* ci-dessous) puis vous compilerez Asterisk.

## Installation de Linux pour Asterisk

Installez Linux comme d'habitude, sans environnement de bureau graphique. Pendant l'installation, activez également un agent de transfert de courrier (nous utilisons **exim4**) — Asterisk en aura besoin plus tard dans ce livre pour envoyer les notifications de voicemail par e-mail. **Attention :** l'installation d'un système d'exploitation efface le disque cible. Si vous installez sur du matériel physique, sauvegardez vos données au préalable ; l'installation dans une machine virtuelle laisse votre hôte intact. Démarrez l'installateur à partir de l'ISO d'Ubuntu Server (ou du lecteur optique virtuel de la VM) et répondez aux invites — la plupart sont simples.

## Installation des dépendances

Pour installer Asterisk et DAHDI, vous devez installer de nombreuses dépendances logicielles. La méthode recommandée pour ce faire dans Asterisk 22 consiste à utiliser le script fourni avec l'arborescence des sources, qui connaît les noms de paquets corrects pour chaque distribution prise en charge. Après avoir téléchargé et extrait les sources d'Asterisk (voir « Compilation d'Asterisk » ci-dessous), exécutez :

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. Connectez-vous en tant que root (ou utilisez `sudo`).
2. Si vous préférez installer les dépendances manuellement sur un système Debian/Ubuntu, la liste de paquets équivalente est :

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

Notez que les sources d'Asterisk sont désormais hébergées sur Git, donc `subversion` n'est plus nécessaire, et les versions modernes de Debian/Ubuntu fournissent `libncurses-dev` plutôt que la version `libncurses5-dev`. Préférez `./contrib/scripts/install_prereq install` à une liste maintenue manuellement, car le script suit toujours les noms de paquets corrects pour votre distribution.

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) est l'architecture des pilotes pour les cartes analogiques et numériques. Avant d'installer Asterisk, il est important d'installer DAHDI si vous prévoyez d'utiliser des interfaces analogiques ou numériques. DAHDI existe toujours pour les cartes de téléphonie analogiques/numériques mais devient de plus en plus spécifique — la plupart des déploiements modernes sont purement VoIP et peuvent ignorer cette section entièrement. Installez DAHDI uniquement si vous possédez du matériel d'interface de téléphonie physique. Récupérez les fichiers sources en utilisant :

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

Décompressez les fichiers en utilisant :

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### Compilation des pilotes DAHDI

Vous devrez compiler les modules DAHDI. Les commandes ./configure et make menuselect ont été introduites il y a plusieurs années. Cette dernière vous permet de sélectionner les utilitaires et les modules à construire. Les commandes suivantes effectueront cette opération :

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

make install-config DAHDI a été configuré. Si vous possédez du matériel DAHDI, il est maintenant recommandé de modifier /etc/dahdi/modules afin de charger uniquement la prise en charge du matériel DAHDI installé sur ce système. Par défaut, la prise en charge de tout le matériel DAHDI est chargée au démarrage de DAHDI. Je pense que le matériel DAHDI présent sur votre système est : usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware Cet écran (ci-dessus) vous demande de modifier le fichier /etc/dahdi/modules pour charger uniquement les pilotes requis pour votre configuration spécifique et afficher le matériel détecté. Modifiez le fichier /etc/dahdi/modules et chargez uniquement le matériel requis. Dans mon cas, j'utilisais une machine de test avec un Xorcom Astribank 6FXS et 2FXO. Le fichier est présenté ci-dessous.

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

Réinitialisez votre ordinateur et vérifiez le chargement correct des pilotes.

## Quelle version choisir

En règle générale, vous devriez utiliser la version qui dispose des fonctionnalités requises. Asterisk suit un modèle de publication alternant entre des versions LTS (support à long terme) et des versions standard. Au moment de cette édition, **Asterisk 22 est la version LTS actuelle** (publiée en octobre 2024 ; la dernière version mineure est 22.10.0), ce qui en fait le meilleur choix à l'heure actuelle. Asterisk 20 est la précédente version LTS, et la version 16 (utilisée dans la première édition) est en fin de vie. Pour les systèmes en production, choisissez toujours une version LTS.

## Compilation d'Asterisk

Si vous avez déjà compilé des logiciels, la compilation d'Asterisk sera une tâche facile. Exécutez les commandes suivantes pour compiler et installer Asterisk. N'oubliez pas que vous pouvez choisir les applications et les modules à construire en utilisant make menuselect. Étape 1 : Télécharger le code source

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

Étape 2 : Installer les prérequis de compilation (voir « Installation des dépendances » ci-dessus)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

Étape 3 : Configurer la compilation

```
./configure
```

Étape 4 : Sélectionner les modules à construire

```
make menuselect
```

Utilisez make menuselect pour installer uniquement les modules nécessaires. Dans Asterisk 22, le canal SIP est **chan_pjsip** (construit par défaut) ; l'ancien **chan_sip** a été supprimé dans Asterisk 21 et n'existe plus. Le *pass-through* Opus fonctionne immédiatement (le module `res_format_attr_opus` intégré gère la négociation SDP), mais le module de transcodage **codec_opus** reste un binaire externe propriétaire provenant de Sangoma/Digium — le sélectionner dans menuselect le télécharge depuis les serveurs de Digium. Le binaire est gratuit. Voir « Sélection des modules avec menuselect » ci-dessous pour plus de détails.

Étape 5 : Construire et installer Asterisk, puis créer la configuration par défaut et les fichiers d'exemple

```
make
make install
make samples
make config
ldconfig
```

`make install` installe les binaires et les modules, `make samples` écrit les fichiers de configuration d'exemple dans `/etc/asterisk`, `make config` installe le script de démarrage SysV init pour votre distribution détectée (par exemple `/etc/init.d/asterisk` sur Debian/Ubuntu), et `ldconfig` rafraîchit le cache des bibliothèques partagées. Une unité systemd est également fournie dans l'arborescence source à `contrib/systemd/asterisk.service`, mais `make config` ne l'installe pas automatiquement — copiez-la vous-même à l'emplacement approprié si vous préférez exécuter Asterisk sous systemd (voir ci-dessous).

### Sélection des modules avec menuselect

`make menuselect` ouvre un menu textuel où vous choisissez exactement quelles applications, codecs, canaux et ressources construire. Quelques remarques spécifiques à Asterisk 22 :

- **chan_pjsip** (sous *Channel Drivers*) est le canal SIP moderne et est activé par défaut ; c'est le seul canal SIP dans Asterisk 22.
- **codec_opus** (sous *Codec Translators*) est un module **externe** (son entrée dans menuselect indique « Download the Opus codec from Digium ») ; l'activer pousse `make` à récupérer le binaire gratuit et propriétaire de Sangoma/Digium. Le pass-through Opus lui-même ne nécessite aucun module supplémentaire. Le module **codec_g729** de Sangoma est également disponible — le binaire est téléchargeable gratuitement, mais le transcodage légal G.729 nécessite l'achat d'une licence par canal.
- Sélectionnez les formats audio et les langues que vous souhaitez dans les menus *Core Sound Packages*, *Music On Hold File Packages* et *Extras Sound Packages* ; tout ce que vous cochez ici est téléchargé et installé automatiquement pendant `make install`.

Après avoir effectué vos sélections, choisissez **Save & Exit** et poursuivez avec `make`.

## Démarrage et arrêt d'Asterisk

Avec cette configuration minimale, il est possible de démarrer Asterisk avec succès. Pour l'apprentissage et le débogage, vous pouvez démarrer Asterisk au premier plan, attaché à la console :

```
/usr/sbin/asterisk -vvvgc
```

Utilisez la commande CLI `core stop now` pour arrêter Asterisk :

```
*CLI> core stop now
```

### Démarrage d'Asterisk avec systemd

Sur les distributions Linux modernes (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9), le gestionnaire de services système est **systemd**. Asterisk fournit une unité systemd dans `contrib/systemd/asterisk.service` au sein de l'arborescence source ; copiez-la vers `/etc/systemd/system/asterisk.service` et exécutez `systemctl daemon-reload`. Une fois installé, la méthode recommandée pour exécuter Asterisk en production est via `systemctl` :

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

Une fois qu'Asterisk fonctionne en tant que service, attachez-vous à son CLI avec `asterisk -r` (connexion) ou `asterisk -rvvv` (connexion avec sortie verbeuse).

Sur les systèmes plus anciens, Asterisk était démarré via le script d'initialisation SysV hérité (`/etc/init.d/asterisk`) et le wrapper **safe_asterisk**, qui redémarrait Asterisk automatiquement en cas de plantage. Avec systemd, le redémarrage automatique est géré par la directive `Restart=` du fichier d'unité, donc `safe_asterisk` n'est généralement plus nécessaire. L'approche héritée init/`safe_asterisk` fonctionne toujours mais est obsolète sur les distributions basées sur systemd.

### Options d'exécution d'Asterisk

Le processus de démarrage d'Asterisk est très simple. Si Asterisk est exécuté sans aucun paramètre, il est lancé en tant que daemon.

```
/sbin/asterisk
```

Vous pouvez accéder à la console Asterisk en exécutant la commande suivante. Veuillez noter que plusieurs processus de console peuvent être exécutés en même temps.

```
/sbin/asterisk -r
```

### Options d'exécution disponibles pour Asterisk

Vous pouvez afficher les options d'exécution disponibles en utilisant `asterisk -h`

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## Répertoires d'installation

Asterisk est installé dans plusieurs répertoires, qui peuvent être modifiés dans le fichier asterisk.conf. À des fins de formation, je changerais le niveau de verbosité de 3 à 15, mais pour la production, maintenez-le à 3. Les options `maxcalls` et `maxload` sont de bonnes options pour protéger votre système contre la surcharge.

### asterisk.conf (extrait)

La section `[directories]` définit où Asterisk conserve sa configuration, ses modules, ses données, sa file d'attente (spool) et ses journaux :

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

La section `[options]` contient les réglages d'exécution. Les options les plus utiles à connaître sont présentées ci-dessous (décommentez pour activer) ; le fichier est fourni avec beaucoup d'autres, chacune étant documentée par un commentaire en ligne :

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## Fichiers de log et rotation des logs

Le PBX Asterisk enregistre ses messages dans `/var/log/asterisk`. La journalisation est contrôlée par `logger.conf`. La partie clé est la section `[logfiles]`, où chaque ligne définit un canal de log et les niveaux de message qu'il capture (extrait) :

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

Après avoir effectué les modifications, appliquez le changement avec `logger reload` et confirmez les canaux avec `logger show channels` :

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

Les fichiers de log peuvent croître rapidement, il faut donc les faire pivoter avec le démon système `logrotate` — ajoutez un fichier sous `/etc/logrotate.d/` :

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

Plus d'informations sur logrotate peuvent être obtenues en utilisant :

```
#man logrotate
```

## Désinstallation d'Asterisk

Pour désinstaller Asterisk, utilisez :

```
make uninstall
```

Pour désinstaller Asterisk et tous les fichiers de configuration, utilisez :

```
make uninstall-all
```

## Notes sur l'installation d'Asterisk

Cette section fournira quelques conseils sur les problèmes à résoudre avant d'installer Asterisk.

### Systèmes de production

Si Asterisk est installé dans un environnement de production, vous devez prêter attention à la conception du système. Un serveur doit être optimisé de telle sorte que les systèmes de téléphonie aient la priorité sur les autres processus système. Asterisk ne devrait pas fonctionner avec des logiciels gourmands en processeur tels que X-Windows. Si vous devez exécuter des processus intensifs pour le CPU (par exemple, une base de données volumineuse), utilisez un serveur séparé. De manière générale, Asterisk est sensible aux variations de performance matérielle. Par conséquent, essayez d'utiliser Asterisk dans un environnement matériel qui ne nécessite pas plus de 40 % d'utilisation du CPU.

### Conseils réseau

Si vous prévoyez d'utiliser des téléphones IP, il est important que vous prêtiez attention à votre réseau. Les protocoles vocaux sont très performants et résistants à la latence et même à la gigue ; cependant, si vous utilisez un réseau local mal configuré, la qualité de la voix en pâtira. Il n'est possible de garantir une bonne qualité vocale qu'en utilisant la qualité de service (QoS) dans les commutateurs et les routeurs. La voix sur un réseau local a tendance à être bonne, mais même dans un environnement LAN, si vous avez des hubs de 10 Mbps avec trop de collisions, vous finirez par avoir une voix déformée ou de mauvaise qualité. Suivez ces recommandations pour garantir la meilleure qualité vocale possible :

- Utilisez une QoS de bout en bout si possible ou économiquement réalisable. Avec une QoS de bout en bout, la qualité de la voix est parfaite. Aucune excuse !
- Évitez d'utiliser des hubs 10/100 Mbps pour la voix dans un environnement de production. Les collisions peuvent imposer de la gigue sur le réseau. Les connexions full duplex 10/100 Mbps sont préférables car aucune collision ne se produit.
- Utilisez des VLAN pour séparer les diffusions inutiles du réseau vocal. Vous ne voulez pas qu'un virus détruise votre réseau vocal avec des diffusions ARP.
- Informez les utilisateurs sur les attentes concernant un réseau vocal. Sans QoS, ne prétendez pas que la voix sera parfaite, car dans la plupart des cas, elle ne le sera pas. Une qualité de voix similaire à celle d'un téléphone mobile sera le plus souvent atteinte. Utilisez des téléphones de qualité, car les problèmes liés au firmware et à la conception matérielle sont courants.

## Résumé

Dans ce chapitre, vous avez découvert la configuration matérielle minimale requise ainsi que la manière de télécharger, d'installer et de compiler Asterisk. Pour des raisons de sécurité, Asterisk doit être exécuté avec un utilisateur non privilégié (non-root). Vous devez vérifier votre environnement réseau avant de démarrer l'environnement de production.

## Quiz

1. Dans Asterisk 22, quel pilote de canal fournit le support SIP, et qu'est-il arrivé à l'ancien `chan_sip` ?
   - A. `chan_sip` est toujours la valeur par défaut ; `chan_pjsip` est optionnel.
   - B. `chan_pjsip` est le canal SIP par défaut ; `chan_sip` a été supprimé dans Asterisk 21 et n'existe plus.
   - C. Les deux sont compilés par défaut et vous choisissez entre eux lors de l'exécution.
   - D. Le support SIP a été entièrement supprimé au profit de IAX2.
2. Les cartes d'interface de téléphonie pour Asterisk possèdent généralement des Digital Signal Processors (DSPs) intégrés et n'ont donc pas besoin de beaucoup de CPU de la part du PC.
   - A. Vrai
   - B. Faux
3. Si vous voulez une qualité vocale parfaite, vous devez mettre en œuvre une qualité de service (QoS) de bout en bout.
   - A. Vrai
   - B. Faux
4. Vous devriez toujours choisir la dernière version d'Asterisk, car c'est la plus stable.
   - A. Vrai
   - B. Faux
5. Quelle est la méthode recommandée pour installer les dépendances de compilation pour Asterisk 22 ?
6. Si vous n'avez pas de carte d'interface TDM, vous disposerez toujours d'une source de synchronisation interne, fournie par le module `res_timing_timerfd` sous Linux. Cette synchronisation est utilisée par des applications telles que ________ et ________.
7. Lors de l'installation d'Asterisk, il est préférable de ne pas installer d'environnements de bureau tels que GNOME ou KDE, car les interfaces graphiques consomment des cycles CPU.
   - A. Vrai
   - B. Faux
8. Les fichiers de configuration d'Asterisk sont situés dans le répertoire ________.
9. Pour installer les fichiers de configuration d'exemple d'Asterisk, tapez la commande : ________
10. Pourquoi est-il important d'exécuter Asterisk en tant qu'utilisateur non-root ?

**Réponses :** 1 — B · 2 — B · 3 — A · 4 — B · 5 — Exécutez `./contrib/scripts/install_prereq install` depuis l'arborescence source d'Asterisk extraite · 6 — ConfBridge et Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — Sécurité (limite les dégâts si Asterisk est compromis)
