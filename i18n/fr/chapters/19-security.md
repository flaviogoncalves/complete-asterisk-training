# Sécurité d'Asterisk

Depuis le début, la question de la sécurité pour Asterisk est critique. SIP, Session Initiation Protocol, est le protocole le plus attaqué sur Internet selon le CERT.BR. Toute personne exploitant un honeypot peut le confirmer. Le problème de la fraude au partage des revenus Internet (Internet Revenue Share Fraud) est très sérieux et peut entraîner des pertes supérieures à des centaines de milliers de dollars. Vous ne devriez jamais installer un serveur Asterisk connecté à Internet sans une sécurité appropriée. Dans ce chapitre, vous apprendrez à identifier les principaux types d'attaques que vous pouvez recevoir et comment les prévenir en utilisant une politique de sécurité adéquate. Enfin, et ce n'est pas le moins important, vous apprendrez à mettre en œuvre la politique de sécurité suggérée.

Ce chapitre cible **Asterisk 22 LTS**, où PJSIP (`res_pjsip` / `chan_pjsip`) est le seul canal SIP. (L'ancien pilote `chan_sip` a été supprimé dans Asterisk 21 — consultez le chapitre *Legacy Channels* si vous migrez un ancien système.) Une conséquence pertinente pour la sécurité : les échecs d'authentification sont désormais émis via le **security event framework** d'Asterisk et le canal de journalisation dédié `security`, ce qui modifie la manière dont Fail2Ban est configuré (abordé plus loin dans ce chapitre).

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Identifier les principaux types d'attaques fréquemment effectuées contre les serveurs Asterisk
- Définir une politique de sécurité efficace
- Mettre en œuvre la politique de sécurité
- Installer et configurer IPTABLES pour Asterisk
- Installer et configurer Fail2Ban pour Asterisk
- Installer et configurer TLS et SRTP pour le chiffrement

## Principales attaques contre la téléphonie IP

Les principales attaques contre la téléphonie IP peuvent être classées en DOS/DDOS, vol de service/fraude aux télécommunications (Toll Fraud) et écoute clandestine. Certains noms peuvent prêter à confusion et différentes sources utilisent parfois des termes différents pour désigner la même attaque. Vol de service, fraude aux télécommunications, fraude au partage de revenus Internet et fraude téléphonique sont autant de noms différents pour désigner des pirates utilisant votre PBX pour acheminer du trafic vers un numéro surtaxé et obtenir des ristournes de la part du fournisseur.

### DDoS/DOS

Le déni de service (Denial of Service) et le déni de service distribué (Distributed Denial of Service) sont des attaques populaires contre toute infrastructure informatique. Il n'en va pas autrement avec SIP et les autres protocoles de voix sur IP. Le déni de service distribué est généralement perpétré par un botnet, tandis qu'un DOS est le fait d'un seul ordinateur. En février 2011, le botnet Sality a effectué un scan furtif et coordonné de l'ensemble de l'espace d'adressage IPv4 à la recherche de serveurs SIP vulnérables — les chercheurs observant le télescope réseau de l'UCSD l'ont attribué à environ trois millions d'IP sources distinctes sondant le port UDP 5060, très probablement pour forcer des comptes SIP par brute-force à des fins de fraude aux télécommunications.[^sality]

[^sality]: A. Dainotti et al., "Analysis of a '/0' Stealth Scan from a Botnet," *IEEE/ACM Transactions on Networking*, 2015 (DOI 10.1109/TNET.2013.2297678).

![Un botnet pair-à-pair dirigeant des milliers de tentatives d'enregistrement SIP vers un serveur](../images/19-security-fig01.png)

Le DOS est généralement appliqué via des techniques telles que le fuzzing et le flooding. Le flooding peut utiliser SIP, IAX, RTP et d'autres protocoles. Ils peuvent arrêter complètement le service ou dégrader la qualité de la voix. Ils sont très difficiles à atténuer si les ports sont ouverts sur Internet. Voici quelques-uns des outils utilisés par les attaquants :

**Fuzzing :**

- **PROTOS Test Suite (c07-sip)** — de l'OUSPG de l'Université d'Oulu. Envoie des milliers de paquets malformés pour provoquer un dysfonctionnement tel qu'un dépassement de tampon (buffer overflow) qui arrête le logiciel.
- **Voiper** — génère plus de 200 000 tests couvrant tous les attributs SIP et vérifie si votre serveur peut traiter les messages efficacement. <http://voiper.sourceforge.net/>

**Flooding :**

- **INVITE Flooder** — inonde le serveur de requêtes SIP INVITE. <http://www.hackingvoip.com/tools/inviteflood.tar.gz>
- **IAX Flooder** — inonde le serveur de trafic IAX2. <http://www.hackingvoip.com/tools/iaxflood.tar.gz>
- **RTP Flooder** — inonde les sessions multimédias actives avec des paquets RTP pour dégrader la qualité de la voix. <http://www.hackingvoip.com/tools/rtpflood.tar.gz>

### Techniques d'atténuation pour DoS/DDoS

Mes recommandations sont les suivantes :

1. N'exposez pas votre serveur Asterisk sur Internet, sauf si nécessaire avec une protection appropriée (SBC).
2. Dans le réseau interne, utilisez un VLAN pour la voix, surtout si vous êtes dans une université ou une école où le nombre d'utilisateurs est élevé.
3. Utilisez un VPN ou TLS pour l'accès externe.

### Fraude au partage de revenus Internet

Cette fraude est un peu délicate à comprendre. La clé est de saisir le concept de numéro international surtaxé (IPRN).

![Les trois étapes de la fraude au partage de revenus Internet : acheter un numéro surtaxé, trouver un appareil VoIP vulnérable et appeler le numéro, puis collecter le paiement](../images/19-security-fig02.png)

Un IPRN est un numéro que vous pouvez obtenir gratuitement auprès de certaines sociétés de téléphonie Internet spécifiques. Recherchez des fournisseurs de numéros surtaxés Internet (Internet Premium Rate Number Providers) et vous en trouverez un grand nombre. Chez ce type d'opérateur, vous pouvez allouer, par exemple, un numéro sur un réseau satellite tel qu'Iridium, une destination coûtant des dizaines de dollars par minute à l'appelant. Le fournisseur IPRN vous reversera un pourcentage des revenus (10 à 20 % du revenu) pour chaque minute reçue.

![Une liste de prix d'un fournisseur IPRN montrant les taux de paiement par pays et les numéros de test](../images/19-security-fig03.png)

Après la phase d'allocation, le pirate tente de trouver un serveur Asterisk ouvert capable de composer l'IPRN alloué. Le PBX de la victime, contrôlé par le pirate, passera des centaines d'appels vers le numéro IPRN, générant un gain important pour le pirate et une facture téléphonique énorme pour la victime. Bien souvent, supérieure à des centaines de milliers de dollars en un seul week-end.

Principaux outils utilisés par les pirates pour attaquer un PBX :

1. **SIPVicious** : http://code.google.com/p/sipvicious/. Sipvicious est un ensemble d'outils de sécurité facile à utiliser. Son objectif principal est de reconnaître les PBX vulnérables et de craquer les mots de passe SIP en utilisant une attaque par force brute. L'outil le plus utilisé est svcrack. L'outil est capable de tester des milliers de mots de passe par seconde.
2. **Vulnérabilités des téléphones**. Un autre point fréquemment utilisé par les pirates comme vecteur d'attaque est le téléphone lui-même. De nombreuses personnes installant Asterisk ne changent pas le mot de passe par défaut de l'interface Web du téléphone. Une fois que ces téléphones sont ouverts sur Internet, les pirates peuvent essayer d'utiliser le mot de passe d'interface par défaut pour télécharger la configuration où ils peuvent souvent trouver le mot de passe SIP secret.

#### TFTPTheft :

Si vous utilisez le provisionnement automatique des téléphones via TFTP, vous êtes probablement exposé à ce type d'attaque. TFTP est une forme simple et non sécurisée de protocole de transfert de fichiers.

![Un attaquant téléchargeant des fichiers .cfg devinables depuis un serveur TFTP, récoltant des identifiants en texte clair depuis les fichiers de configuration](../images/19-security-fig04.png)

Le nom des fichiers de configuration est facilement devinable en utilisant l'adresse MAC suivie de .cfg (par exemple 001A2B3C4D5E.cfg). Un pirate avisé peut facilement créer un utilitaire pour essayer toutes les adresses MAC séquentiellement ou simplement télécharger un outil pour le faire. Le fichier de configuration est généralement non chiffré et contient le mot de passe SIP secret.

#### Atténuation pour les attaques par force brute et TFTPTheft

Pour atténuer ces attaques, vous pouvez appliquer les solutions ci-dessous. Force brute : La meilleure solution pour atténuer les attaques par force brute est d'empêcher les tentatives non autorisées séquentielles. Presque tous les installateurs Asterisk utilisent l'utilitaire fail2ban pour cela. Lorsque fail2ban détecte plusieurs tentatives avec un mauvais mot de passe ou nom d'utilisateur, il bannit l'IP de l'attaquant pour une certaine durée. La deuxième mesure contre la force brute consiste à utiliser des mots de passe forts, de plus de 12 caractères, avec au moins un caractère spécial. TFTPTheft : Pour empêcher le TFTPTheft, configurez le provisionnement pour utiliser HTTPS avec un nom et un mot de passe. Le fichier est transmis de manière chiffrée et un nom et un mot de passe empêchent les attaquants de tenter de télécharger des fichiers.

### Écoute clandestine

Nous ne voyons pas beaucoup ces types d'attaques car, dans la plupart des cas, elles ne sont tout simplement pas détectées. L'écoute clandestine est très difficile à détecter dans un environnement IP. Des utilitaires tels que UCsniff, disponibles gratuitement, sont capables d'écouter un appel VoIP sur la plupart des réseaux. La technique principale consiste à utiliser l'usurpation ARP (ARP spoofing) pour forcer le trafic à passer par l'ordinateur exécutant UCsniff et enregistrer les appels.

#### Atténuation pour l'écoute clandestine

Vous pouvez empêcher l'écoute clandestine en chiffrant votre trafic VoIP. L'autre moyen consiste à empêcher les attaques de type homme du milieu (MITM) sur votre réseau. L'inspection ARP est très efficace pour empêcher les MITM dans les réseaux de couche 2. Consultez le support technique de votre réseau pour comprendre comment l'implémenter. Plus loin dans ce livre, nous apprendrons comment installer le chiffrement basé sur TLS et SRTP. Vous pouvez également utiliser ARPWatch pour découvrir si quelqu'un abuse actuellement du protocole ARP pour attaquer votre réseau.

## Politique de sécurité pour Asterisk

La meilleure façon de mettre en œuvre la sécurité est de créer une politique de sécurité. Pour cette formation, je suggère une politique de sécurité adaptée à la plupart des installations Asterisk. Utilisez-la comme point de départ et adaptez-la selon vos besoins. La politique de sécurité suggérée est la suivante :

1. Aucun port UDP/TCP inutile ouvert
2. Aucun accès à une interface d'administration (SSH/HTTPS) ouvert sur Internet.
3. Pour accéder à SSH et/ou HTTP/HTTPS, il doit y avoir des exceptions explicites dans le pare-feu IPTABLES
4. Mots de passe robustes de 12 caractères avec au moins un caractère spécial
5. Bannir les adresses IP échouant plus de 10 fois lors de l'authentification en utilisant Fail2ban
6. Confirmation par mot de passe pour les appels internationaux
7. Limiter l'accès au port SIP à votre plage d'adresses IP connue

Si vous avez besoin d'un accès externe à votre PBX, il existe deux possibilités. Utilisez un SBC (Session Border Controller) pour protéger votre serveur contre les attaques DOS/DDOS ou utilisez un VPN chaque fois que vous souhaitez un accès externe. Si vous laissez le port 5060 ouvert sur Internet sans SBC ou VPN, vous vous exposez à une attaque DOS/DDOS. Le risque est le vôtre.

### Durcissement de l'ère PJSIP (Asterisk 22)

Au-delà du pare-feu et de Fail2Ban, la pile PJSIP d'Asterisk 22 fournit plusieurs contrôles au niveau de la configuration qui devraient faire partie de votre politique de sécurité. Ceux-ci complètent (et ne remplacent pas) les contrôles réseau ci-dessus :

- **Authentification par endpoint.** Chaque endpoint doit référencer une section `type=auth` dédiée avec un `password` unique et robuste (`auth_type=digest`). Ne réutilisez jamais d'identifiants entre les endpoints.
- **Gestion des appels anonymes intégrée.** PJSIP ne révèle pas si un nom d'utilisateur existe lorsque l'authentification échoue. Pour accepter les appels anonymes, vous devez explicitement créer un endpoint nommé `anonymous` et utiliser des sections `type=identify` (correspondant à l'IP source) pour mapper les pairs connus aux endpoints. Si vous ne souhaitez pas d'appels anonymes, ne créez simplement pas d'endpoint `anonymous`, et les requêtes non correspondantes seront défiées/rejetées.
- **ACLs.** Restreignez qui peut atteindre un endpoint avec des ACL nommées `/etc/asterisk/acl.conf`, référencées depuis l'endpoint avec `acl=` (ACL de signalisation/source) et `contact_acl=` (restreint l'adresse de contact/enregistrement). Vous pouvez également définir permit/deny directement sur l'endpoint.
- **`qualify`.** Définissez `qualify_frequency` (et `qualify_timeout`) sur l'AOR afin qu'Asterisk surveille activement la joignabilité des contacts enregistrés et supprime ceux qui sont inactifs.
- **Durcissement du transport PJSIP / Protection DoS.** Le `type=transport` n'expose pas de limite de clients par transport, donc la protection contre les inondations de connexions provient du pare-feu (les règles iptables/Fail2Ban dans ce chapitre) plutôt que d'une option PJSIP. Ce que le transport vous offre, c'est le réglage des keep-alive TCP (`tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`) pour éliminer les connexions mortes/semi-ouvertes, et les paramètres `local_net`/`external_*` pour une gestion correcte du NAT. Combinez-les avec les règles du pare-feu pour atténuer les attaques par inondation de connexions.
- **TLS + SRTP pour les médias.** Chiffrez la signalisation avec un transport TLS et les médias avec `media_encryption=sdes` (ou `dtls` pour WebRTC) sur l'endpoint — traité plus loin dans ce chapitre.
- **Contrôle d'accès AMI/ARI.** Restreignez l'Asterisk Manager Interface (`manager.conf`) et l'ARI (`ari.conf` / `http.conf`) au localhost ou à un réseau de gestion de confiance, utilisez des secrets uniques robustes, liez le serveur HTTP à une interface privée et ne les exposez jamais à Internet.

Tous les noms d'options ci-dessus sont confirmés pour Asterisk 22.10 : la section `type=transport` expose `tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`, `tos`, `cos`, `local_net` et la famille `external_*`, mais elle n'a **aucune** option `max_clients` — la protection contre les inondations de connexions provient du pare-feu, pas du transport. Les options d'endpoint `acl` et `contact_acl` prennent des noms de section depuis `acl.conf`, et la correspondance par IP source pour les pairs non authentifiés se fait avec des sections `type=identify` (`match=`).

### Suppression des ports inutiles

Au lieu de découvrir toutes les vulnérabilités associées à tous les protocoles Asterisk, simplifions le problème en supprimant les ports inutiles. Pour lister tous les ports ouverts par le serveur Asterisk, utilisez :

```
netstat -pantu |grep asterisk
```

Le résultat de la commande est affiché ci-dessous.

![Sortie de netstat montrant les nombreux ports liés par Asterisk, y compris 4569 (IAX) et 2727 (MGCP)](../images/19-security-fig05.png)

Si vous regardez le résultat, vous découvrirez que de nombreux ports sont ouverts. En avons-nous besoin ? Pas nécessairement, 2727 est le protocole MGCP (chan_mgcp), 4569 est l'IAX (chan_iax2). Si vous n'utilisez pas ces protocoles, vous pouvez simplement supprimer le module dans le fichier de configuration modules.conf.

Vous remarquerez peut-être qu'Asterisk lie un port UDP à numéro élevé. Cela provient du résolveur de `res_pjsip` effectuant des requêtes DNS sortantes (le port source est éphémère, comme toute recherche DNS client), et non d'un écouteur entrant — votre pare-feu n'a besoin d'autoriser que le trafic de retour **établi/associé** pour cela (la règle iptables `conntrack ESTABLISHED,RELATED` montrée ci-dessous couvre déjà cela). Vous n'avez **pas** besoin d'ouvrir une large plage UDP entrante à numéro élevé juste pour le DNS de PJSIP.

Pour supprimer les ports inutiles, désactivez les modules que vous n'utilisez pas. Modifiez le fichier modules.conf et ajoutez des lignes `noload` pour les canaux et protocoles que vous n'utilisez pas. **Ne faites pas** noload `res_pjsip`, `res_pjproject` ou `chan_pjsip` — ceux-ci sont requis pour SIP dans Asterisk 22 :

```
; res_pjsip / res_pjproject / chan_pjsip are REQUIRED in Asterisk 22 - keep them loaded
noload => chan_iax2.so
noload => chan_unistim.so
```

(Dans Asterisk 22, vous n'avez plus besoin de noload `chan_mgcp` ou `chan_skinny` — ces pilotes ont été *supprimés* dans Asterisk 21 et ne font pas partie d'une version standard 22.) Avec les instructions ci-dessus, j'ai supprimé tous les canaux inutiles en ne gardant que PJSIP. Vous pouvez choisir les modules de protocole que vous voulez, supprimez simplement ceux qui sont inutilisés. Le résultat est montré dans la capture d'écran ci-dessous — seul le port SIP (5060) lié par votre transport PJSIP est désormais exposé en entrée.

![Sortie de netstat après avoir désactivé les modules inutilisés : seul le port UDP 5060 reste lié par Asterisk](../images/19-security-fig06.png)

### Mise en œuvre de la politique de sécurité avec IPTABLES

IPTABLES ou netfilter est un pare-feu standard présent dans la plupart des distributions Linux. Dans ce laboratoire, nous configurerons iptables et fail2ban. L'objectif est de mettre en œuvre la politique de sécurité recommandée pour Asterisk et de bloquer tout trafic inutile. Suivez les étapes ci-dessous :

1. Bloquer tout trafic externe
2. Autoriser le trafic SSH depuis un réseau interne ou un hôte unique
3. Autoriser le trafic SIP en UDP et TCP sur les ports 5060
4. Autoriser le trafic RTP dans la plage de ports média UDP. Il n'y a pas de valeur par défaut intégrée unique — le `rtp.conf` d'Asterisk revient aux ports 5000–31000 lorsque rien n'est défini, mais le `rtp.conf.sample` fourni configure `rtpstart=10000` / `rtpend=20000`, donc nous utilisons cette plage d'exemple ici. Faites correspondre votre règle de pare-feu à ce que vous avez réellement défini dans `rtpstart`/`rtpend` dans `rtp.conf`.

Assurez-vous d'avoir un accès console au serveur, vous ne voulez pas vous bloquer hors du système. Soyez prudent.

1. Installez le paquet net-persistent.

   ```
   sudo apt-get install iptables-persistent
   ```

2. Autorisez tout le trafic depuis le loopback

   ```
   sudo iptables -I INPUT -i lo -j ACCEPT
   sudo iptables -I OUTPUT -o lo -j ACCEPT
   ```

3. Autorisez les connexions établies

   ```
   sudo iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   ```

4. Autorisez le trafic SSH/HTTPS depuis le réseau 192.168.0.0

   ```
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 443 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   ```

5. Insérez les règles Asterisk

   ```
   sudo iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5061 -j ACCEPT
   sudo iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
   ```

   Notez que le port 5061 (SIP sur TLS) est **TCP**, pas UDP. Les règles ci-dessus ouvrent 5060 en UDP et TCP et 5061 en TCP. Si vous n'utilisez que TLS, vous pouvez supprimer complètement les règles 5060 en clair. N'ouvrez que les ports auxquels vos transports PJSIP se lient réellement.

   `-I` signifie PREPEND (insérer au début)

6. La dernière règle doit être un drop (abandon)

   ```
   sudo iptables -A INPUT -j DROP
   ```

   `-A` signifie APPEND (ajouter à la fin). Note : Soyez prudent lors de la maintenance de nouvelles règles, vous devez ajouter les règles avant le DROP. Utilisez PREPEND pour les nouvelles règles `-I`

7. Enregistrez les règles et redémarrez iptables

   ```
   sudo iptables-save >/etc/iptables/rules.v4
   sudo /etc/init.d/netfilter-persistent restart
   ```

### Utilisation de Fail2Ban pour bloquer les tentatives d'authentification échouées multiples

Fail2Ban est presque un standard pour Asterisk. La plupart des utilisateurs l'implémentent pour améliorer la sécurité. Cet utilitaire scanne les journaux Asterisk à la recherche de tentatives échouées et bannit les adresses IP des attaquants. Ci-dessous, je fournis les instructions pour installer Fail2Ban.

Dans Asterisk 22, PJSIP signale les authentifications échouées et d'autres événements de sécurité via le **framework d'événements de sécurité** d'Asterisk, écrit dans le canal de journalisation dédié **`security`**. Pour faire fonctionner Fail2Ban, vous devez :

1. Activer le canal de sécurité dans `/etc/asterisk/logger.conf`. La syntaxe est `<filename> => <levels>`, donc pour envoyer le niveau de sécurité vers un fichier nommé `security`, écrivez :

```
[logfiles]
security => security
```

puis exécutez `logger reload` depuis la CLI. Cela produit `/var/log/asterisk/security` avec une ligne par événement de sécurité, sous la forme :

```
[2026-01-15 10:23:45] SECURITY[1234] res_security_log.c: SecurityEvent="InvalidPassword",...,RemoteAddress="IPV4/UDP/203.0.113.7/5060",...
```

Les événements qui intéressent Fail2Ban sont `InvalidPassword`, `ChallengeResponseFailed`, `InvalidAccountID` et `FailedACL`, chacun portant un champ `RemoteAddress="IPV4/UDP/<ip>/<port>"` qui identifie le contrevenant. (Notez que l'adresse est enveloppée comme `IPV4/UDP/.../...`, pas une IP nue — votre filtre doit extraire l'hôte de l'intérieur de cette chaîne.)

2. Pointez la prison `asterisk` vers ce fichier (`logpath = /var/log/asterisk/security`) et utilisez un filtre qui analyse ce format d'événement de sécurité.

Le Fail2Ban moderne fournit un filtre `asterisk` dont le `failregex` correspond déjà aux événements ci-dessus et extrait `<HOST>` du champ `RemoteAddress`, par exemple :

```
failregex = ^SecurityEvent="(?:FailedACL|InvalidAccountID|ChallengeResponseFailed|InvalidPassword)".*,RemoteAddress="IPV[46]/[^/"]+/<HOST>/\d+"
```

Les distributions PBX (FreePBX/Sangoma) fournissent des filtres équivalents. Préférez le filtre packagé plutôt que d'en écrire un manuellement, car les chaînes d'événements exactes dépendent de la version. Une mise en garde à connaître : un avis désormais corrigé (GHSA-5743-x3p5-3rg7) a montré qu'un trafic PJSIP contrefait pouvait injecter de fausses lignes de journal — gardez à jour à la fois Asterisk et votre filtre Fail2Ban.

Ci-dessous, je fournis les instructions pour installer Fail2Ban

1. Installez fail2ban sur Linux

   ```
   sudo apt-get install fail2ban
   ```

2. Activez fail2ban pour Asterisk et SSH

   ```
   sudo vi /etc/fail2ban/jails.d/defaults-debian.conf
   ```

   Ajoutez les lignes suivantes pour activer fail2ban pour ssh et asterisk

   ```
   [sshd]
   enabled = true
   [asterisk]
   enabled=true
   ```

3. Redémarrez fail2ban

   ```
   /etc/init.d/fail2ban restart
   ```

4. Vérifiez. Changez le secret de votre softphone et essayez de vous réenregistrer 10 fois. En utilisant `iptables -L`, vérifiez si l'adresse du softphone a été incluse comme adresse bloquée.
5. Supprimez l'adresse du bannissement (supposons que l'adresse soit 192.168.0.5)

   ```
   sudo fail2ban-client set asterisk unbanip 192.168.0.5
   ```

Note : Dans la commande, remplacez 192.168.0.5 par l'adresse IP de votre téléphone

### Mise en œuvre de TLS et SRTP

Je vais diviser cette section en deux. Dans la première partie, nous couvrirons TLS pour chiffrer la signalisation et dans la seconde partie, SRTP pour chiffrer les médias. L'objectif ici est de configurer Asterisk pour ces ressources.

#### TLS

TLS (Transport Layer Security) est le mécanisme de chiffrement défini pour protéger la signalisation SIP. Le tableau ci-dessous résume les attaques contre lesquelles TLS protège :

| Type d'attaque | Protégé ? | Notes |
|----------------|-----------|-------|
| Attaques de signalisation | Oui | TLS assure l'intégrité des messages |
| Homme du milieu | Oui | TLS vérifie le certificat du serveur |
| Écoute clandestine | Non | TLS chiffre la signalisation, pas les médias |

Pour le chiffrement des médias (voix/vidéo), utilisez SRTP.

#### Certificats numériques auto-signés

Il existe deux types de certificats que vous pouvez utiliser : auto-signés et commerciaux. Les certificats auto-signés sont signés par votre propre serveur tandis que les certificats commerciaux sont signés par une autorité externe. Pour la VoIP, vous pouvez être votre propre autorité de certification. Il n'y a pas besoin d'un certificat externe tel que GoDaddy ou Verisign, c'est une dépense inutile. Nous générerons nos propres certificats en utilisant ast_tls_cert.

#### Configuration de TLS avec des certificats auto-signés

Voici un guide étape par étape sur la façon d'implémenter TLS. Nous générons d'abord les certificats, puis nous configurons le transport TLS PJSIP (voir "Configuration de TLS avec chan_pjsip"), et enfin nous pointons le softphone vers celui-ci. Nous utiliserons le SipPulse Softphone, qui prend en charge TLS et SRTP nativement. (Tout softphone SIP compatible TLS/SRTP fonctionne de la même manière.)

**Étape 1.** Créez une clé RSA privée en utilisant le chiffrement 3DES avec une longueur de 4096 bits pour notre autorité de certification. La commande ci-dessous, présente dans /usr/src/asterisk-22.x.y/contrib/scripts, créera l'Autorité de Certification et le Certificat Asterisk. Comme d'habitude, adaptez les instructions si nécessaire, les versions changent, les répertoires changent. S'il vous plaît, soyez attentif à ce que vous faites. Utilisez votre domaine ou adresse IP dans l'option –C. La commande ast_tls_cert a trois options.

- -C nom d'hôte ou adresse IP (j'ai utilisé 192.168.0.74, l'adresse IP de ma VM)
- -O Nom de l'organisation
- -d Répertoire où stocker les clés

```
mkdir /etc/asterisk/keys
cd /usr/src/asterisk-22.0.0/contrib/scripts
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts# ./ast_tls_cert -C 192.168.0.74 -O "AsteriskGuide" -d /etc/asterisk/keys
No config file specified, creating '/etc/asterisk/keys/tmp.cfg'
You can use this config file to create additional certs without
re-entering the information for the fields in the certificate
Creating CA key /etc/asterisk/keys/ca.key
Generating RSA private key, 4096 bit long modulus
........................................................++
........................................................++
e is 65537 (0x010001)
Enter pass phrase for /etc/asterisk/keys/ca.key:
Verifying - Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating CA certificate /etc/asterisk/keys/ca.crt
Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating certificate /etc/asterisk/keys/asterisk.key
Generating RSA private key, 2048 bit long modulus
........................++++++
......................++++++
e is 65537 (0x010001)
Creating signing request /etc/asterisk/keys/asterisk.csr
Creating certificate /etc/asterisk/keys/asterisk.crt
Signature ok
subject=CN = 192.168.0.74, O = AsteriskGuide
Getting CA Private Key
Enter pass phrase for /etc/asterisk/keys/ca.key:
Combining key and crt into /etc/asterisk/keys/asterisk.pem
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts#
```

Je ne vais pas générer de certificat client car nous n'allons pas utiliser le certificat pour authentifier le client. Le client n'est pas tenu de présenter son propre certificat.

**Étape 2.** Configurez Asterisk pour prendre en charge notre client via TLS. Cela se fait dans `pjsip.conf` (un transport TLS plus les paramètres de l'endpoint) — la configuration complète est montrée dans la section suivante, "Configuration de TLS avec chan_pjsip". Nous ne nous authentifions pas en utilisant des certificats, nous chiffrons simplement le trafic.

**Étape 3.** Installez un softphone SIP compatible TLS (l'auteur utilise le SipPulse Softphone).

**Étape 4.** Copiez l'autorité de certification sur l'ordinateur exécutant le softphone. Après l'avoir installé, copiez le fichier `/etc/asterisk/keys/ca.crt` sur l'ordinateur exécutant le softphone (utilisez scp, ou WinSCP sur Windows) si vous utilisez un certificat auto-signé.

**Étape 5.** Créez le compte dans le softphone. Dans l'écran de compte, ajoutez le compte normalement comme n'importe quel autre compte sip. Utilisez le bon mot de passe, l'authentification est toujours basée sur le mot de passe.

**Étape 6.** Définissez TLS comme transport dans les paramètres du compte. Dans l'écran de compte du SipPulse Softphone (ci-dessous), choisissez **TLS** comme transport et utilisez le port 5061. Ajustez votre pare-feu pour ouvrir le port TCP 5061.

![L'écran de compte du SipPulse Softphone — entrez le Serveur (votre IP Asterisk ou domaine), le Nom d'utilisateur, le Mot de passe et le Nom d'affichage, puis choisissez le Transport (UDP, TCP ou TLS).](../images/softphone/sipphone-account.png){width=35%}

**Étape 7.** Faites confiance à l'autorité de certification. Si votre certificat TLS Asterisk est signé par une CA publique (par exemple Let's Encrypt — voir le chapitre *Déploiement*), un softphone moderne tel que le SipPulse Softphone lui fait confiance automatiquement via le magasin de certificats système, sans importation manuelle. Si vous utilisez un certificat auto-signé, importez sa CA (`/etc/asterisk/keys/ca.crt`) dans le client ou le magasin de confiance du système d'exploitation, ou acceptez-le lorsque vous y êtes invité.

**Étape 8.** Vous n'avez **pas** besoin d'un certificat client. Une idée fausse courante est que chaque téléphone a besoin de son propre certificat pour s'authentifier — ce n'est pas le cas. À ce stade, Asterisk *chiffre* seulement la session ; l'authentification est toujours le nom d'utilisateur et le mot de passe. Asterisk ne vérifie pas les certificats clients par défaut, il n'est donc pas nécessaire de distribuer un certificat par client.

**Étape 9.** Après avoir changé le certificat ou le transport, redémarrez complètement le softphone (quittez et relancez, ne fermez pas juste la fenêtre) afin qu'il se reconnecte via le nouveau transport.

### Configuration de TLS avec chan_pjsip

Apprenons maintenant à configurer PJSIP pour TLS. PJSIP est le seul canal SIP dans Asterisk 22, il n'y a donc rien à changer — assurez-vous simplement que `res_pjsip`, `res_pjproject` et `chan_pjsip` sont chargés. Étape 1 : Confirmez que PJSIP est activé dans /etc/asterisk/modules.conf.

```
; res_pjsip / res_pjproject / chan_pjsip must be loaded (do NOT noload them)
noload => chan_iax2.so
noload => chan_unistim.so
```

Étape 2 : Configurez PJSIP pour prendre en charge TLS. Ajoutez une section pour le transport TLS dans le fichier /etc/asterisk/pjsip.conf

```
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

Utilisez `method=tlsv1_2` (ou `tlsv1_3` si votre build OpenSSL/PJSIP le prend en charge) — TLS 1.0/1.1 sont obsolètes et non sécurisés et ne devraient pas être utilisés.

Étape 3 : Configurez l'endpoint pour blink. Modifiez `pjsip.conf` et modifiez la section pour blink. Laissez PJSIP choisir le transport automatiquement.

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
dtmf_mode=rfc4733
media_encryption=sdes
[blink]
type=aor
max_contacts=2
remove_existing=yes
[blink]
type=auth
auth_type=digest
username=blink
password=supersecret
```

Étape 4 : Vérification. Pour vérifier que l'enregistrement a eu lieu via TLS, utilisez la commande suivante dans la console Asterisk.

```text
asterisk*CLI> pjsip show aor blink

      Aor:  <Aor.............................................>  <MaxContact>
    Contact:  <Aor/ContactUri........................> <Hash....> <Status> <RTT(ms)..>
==========================================================================================

      Aor:  blink                                                2
    Contact:  blink/sip:03694827@192.168.0.67:56295;transp 620d91556d NonQual    nan
 ParameterName        : ParameterValue
 ====================================================================
 authenticate_qualify : false
 contact              : sip:03694827@192.168.0.67:56295;transport=tls
 default_expiration   : 3600
 max_contacts         : 2
 maximum_expiration   : 7200
 minimum_expiration   : 60
 qualify_frequency    : 0
 qualify_timeout      : 3.000000
 remove_existing      : true
 support_path         : false
```

### Passer des appels sécurisés en utilisant SRTP

Le protocole responsable du chiffrement des médias est le Secure Real Time Protocol (SRTP) défini dans la RFC3711. L'une des lacunes du protocole est l'absence d'un moyen standardisé d'échanger des clés. Asterisk utilise des clés d'échange SDES sur le protocole SDP protégé par le chiffrement de la signalisation fourni par TLS. Il existe également d'autres méthodes telles que MIKEY et ZRTP. ZRTP, développé par Philipp Zimmermann, est l'une des méthodes les plus sophistiquées pour l'échange de clés et le chiffrement des médias. Certains softphones et téléphones matériels autorisent ZRTP. Cependant, la méthode standard reste SDES et vous trouverez cette méthode dans presque tous les téléphones disponibles sur le marché. Ci-dessous un exemple de requête avec les clés de chiffrement définies dans le SDP dans les lignes a=crypto:1 et a=crypto:2.

```
INVITE sip:8000@192.168.1.237 SIP/2.0
Via:
SIP/2.0/tls
192.168.1.192:65525;rport;branch=z9hG4bKPj9fa224a14b17488ea15625ead833ea3a
Max-Forwards: 70
From:
"Flavio"
<sip:flavio@192.168.1.237>;tag=35afe6cc11274934867b24e43c805638
To: <sip:8000@192.168.1.237>
Contact: <sip:pyhkxnjz@192.168.1.192:65524;transport=tls>
Call-ID: 530a339c72af47f0a76e7ecb2a58ac43
CSeq: 5669 INVITE
Allow: SUBSCRIBE, NOTIFY, PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, MESSAGE
Supported: 100rel
User-Agent: Blink 0.2.5 (Windows)
Authorization: Digest username="flavio", realm="asterisk", nonce="72ff51ad",
uri="sip:8000@192.168.1.237",
response="ba8c10672751baa7007d82eb34e2340e",
algorithm=MD5
Content-Type: application/sdp
Content-Length: 544
v=0
o=- 3509174186 3509174186 IN IP4 192.168.1.192
s=Blink 0.2.5 (Windows)
c=IN IP4 192.168.1.192
t=0 0
m=audio 50004 RTP/SAVP 9 104 103 102 0 8 101
a=rtcp:50005
a=rtpmap:9 G722/8000
a=rtpmap:104 speex/32000
a=rtpmap:103 speex/16000
a=rtpmap:102 speex/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=crypto:1
AES_CM_128_HMAC_SHA1_80
inline:WrtZH82ztz93albRNT8o+oMcK9GvlAHRoaR1STvJ
a=crypto:2
AES_CM_128_HMAC_SHA1_32
inline:4Ma9jJOCEEGMPzzkmgyf6ttp1qhN16yumdXB7eRv
a=sendrecv
```

#### Configuration de SRTP sur Asterisk

Configurer SRTP sur Asterisk est très simple. Définissez `media_encryption=sdes` sur l'endpoint ; vous pouvez également l'exiger avec `media_encryption_optimistic=no` afin que les médias non chiffrés soient rejetés plutôt que silencieusement autorisés. Notez que SDES nécessite que la signalisation s'exécute sur TLS afin que les clés ne soient pas envoyées en clair.

**Étape 1.** Configuration d'Asterisk

Définissez ce qui suit sur la section `type=endpoint` dans `pjsip.conf` :

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
transport=transport-tls
media_encryption=sdes
media_encryption_optimistic=no
```

**Étape 2.** Configuration du softphone

Dans le softphone, activez SRTP pour les médias du compte (définissez l'option **SRTP (Media Encryption)** sur *Mandatory*) afin que la voix soit chiffrée.

![Les paramètres de compte du SipPulse Softphone (section inférieure) — définissez **Transport** sur TLS et **SRTP (Media Encryption)** sur *Mandatory* afin que la signalisation et les médias soient tous deux chiffrés.](../images/softphone/sipphone-config.png){width=35%}

## Activation de l'authentification à deux facteurs pour les appels internationaux

Parfois, la meilleure solution consiste à ne pas avoir de routes internationales. Cependant, si vous avez réellement besoin de composer des numéros internationaux, utilisez un mot de passe supplémentaire. Nous allons utiliser l'application Asterisk vmauthenticate pour demander le mot de passe de la voicemail avant d'autoriser un appel international. Ceci est configuré dans le dialplan dans le fichier extensions.conf. Voir l'exemple ci-dessous. Ainsi, un pirate informatique, même après avoir découvert le mot de passe d'un peer ou compromis un téléphone, a toujours besoin du mot de passe de la voicemail pour appeler cette destination.

```
exten=_9011.,1,Playback(pleasedialyourvmpassword)
exten=_9011.,2,VMAuthenticate(${CALLERID(num)}@default,s)
exten=_9011.,3,Dial(PJSIP/${EXTEN:1}@my_trunk,20,tT)
exten=_9011.,4,Hangup()
```

`VMAuthenticate` est toujours une application standard dans Asterisk 22. Le `Dial()` ci-dessus achemine l'appel via un trunk SIP/PJSIP (`PJSIP/<number>@<trunk>`), ce qui est la manière dont la plupart des installations modernes atteignent le PSTN — adaptez `my_trunk` au nom de votre propre trunk, et utilisez `DAHDI/g1/...` uniquement si vous disposez réellement d'une span DAHDI. La défense contre la fraude téléphonique dans le dialplan — un second facteur comme celui-ci, combiné à la restriction des contextes pouvant accéder à vos routes sortantes et internationales — demeure l'une des protections les plus importantes que vous puissiez déployer.

## Résumé

Dans ce chapitre, vous avez découvert les risques liés à la connexion d'un IP PBX à Internet. Ensuite, nous avons appris comment protéger notre PBX en mettant en œuvre une politique de sécurité. Dans cette politique de sécurité, nous avons implémenté iptables, fail2ban, TLS, SRTP et une authentification bidirectionnelle pour les appels internationaux. J'espère que vous avez apprécié ce chapitre.

## Quiz

1. Quelle est la contre-mesure la plus importante contre la fraude au partage des revenus Internet (Internet Revenue Share Fraud) ?
   - A. Implémenter SRTP
   - B. Maintenir Asterisk à jour
   - C. Implémenter TLS
   - D. Utiliser des mots de passe robustes
2. Le SIP fuzzing est défini comme :
   - A. Une attaque DoS utilisant des requêtes et des réponses malformées
   - B. Un vol de service où les mots de passe sont obtenus par force brute
   - C. L'écoute clandestine d'appels en cours
   - D. Une attaque DDoS avec une inondation de requêtes SIP
3. Le TFTPTheft se produit lorsque le serveur fournit des fichiers de configuration via TFTP. Vous pouvez l'éviter en utilisant :
   - A. FTP
   - B. HTTP
   - C. HTTPS avec nom d'utilisateur et mot de passe
   - D. SCP
4. Les attaques de type Man-in-the-middle utilisent une technique appelée :
   - A. TFTP theft
   - B. ARP spoofing
   - C. MAC poisoning
   - D. dsniff
5. Pour SRTP, Asterisk utilise le système suivant pour échanger les clés :
   - A. MIKEY
   - B. SDES
   - C. ZRTP
   - D. Pluto
6. L'utilitaire qui génère l'autorité de certification et les certificats, situé dans `/usr/src/asterisk-22.x.y/contrib/scripts`, est :
   - A. ast_tls_cert
   - B. gen_tls
   - C. gen_ast_tls
   - D. tls_generator
7. Stratégies valides pour empêcher l'écoute clandestine (cochez toutes les réponses qui s'appliquent) :
   - A. Implémenter des détecteurs d'écoute analogique
   - B. Utiliser l'utilitaire ARPwatch pour détecter l'ARP spoofing
   - C. Activer la détection d'ARP-spoofing dans les commutateurs
   - D. Utiliser SRTP
8. Asterisk prend en charge une authentification forte en vérifiant les certificats clients. (Le transport PJSIP TLS peut exiger et vérifier le certificat du client.)
   - A. Vrai
   - B. Faux
9. Sur Asterisk 22, quel paramètre d'endpoint PJSIP active le chiffrement des médias SRTP en utilisant des clés in-SDP (SDES) ?
   - A. `encryption=yes`
   - B. `media_encryption=sdes`
   - C. `srtp=mandatory`
   - D. `transport=tls`
10. Dans Asterisk 22, Fail2Ban doit lire les événements d'échec d'authentification PJSIP depuis le canal de journalisation dédié ________ (activé dans `logger.conf`).
   - A. `console`
   - B. `messages`
   - C. `security`
   - D. `verbose`

**Réponses :** 1 — D · 2 — A · 3 — C · 4 — B · 5 — B · 6 — A · 7 — B, C, D · 8 — A · 9 — B · 10 — C
