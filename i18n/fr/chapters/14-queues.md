# Files d'attente d'appels

Les files d'attente d'appels, également connues sous le nom d'ACD (Automatic Call Distribution), deviennent de plus en plus importantes pour répondre efficacement aux appels des clients. Un distributeur automatique d'appels peut aider à réduire les coûts, à améliorer le service et à augmenter les ventes, car les distributeurs d'appels influencent le fonctionnement de votre entreprise — non pas pour quelques jours, mais pour de nombreuses années. Dans un environnement de centre d'appels, le facteur numéro un est le personnel ; il s'agit de la ressource la plus coûteuse. Il faut du temps, de l'argent et de la patience pour embaucher, former et motiver les agents. Avec un ACD, vous pouvez maximiser la productivité des agents en dimensionnant précisément le nombre d'agents requis, en contrôlant les bons et les mauvais employés, et en analysant le flux d'appels.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Comprendre pourquoi et comment utiliser les files d'attente d'appels
- Comprendre la théorie fondamentale des files d'attente d'appels
- Installer et configurer le système de file d'attente

## Comment fonctionnent les files d'attente ?

Les files d'attente d'appels ne sont pas exactement une nouveauté. Lorsque vous avez un flux important d'appels entrants, il est difficile de distribuer les appels de manière appropriée. L'utilisation d'une stratégie de groupe où le téléphone sonne simultanément sur tous les agents ne semble pas fonctionner, à moins que vous n'ayez que quelques agents. Cependant, une file d'attente d'appels ne distribuera les appels qu'à un seul agent disponible à la fois et mettra le client en attente avec de la musique lorsqu'aucun agent n'est disponible. La file d'attente fonctionne en retenant l'appel tout en trouvant un agent inoccupé pour répondre à l'appel. L'un des plus grands avantages de la file d'attente est d'éviter de perdre des appels tout en offrant la possibilité de générer des statistiques.

![Une file d'attente d'appels : les appels entrants 1-800 entrent dans la file d'attente et une stratégie ACD (ringall, rrmemory, leastrecent, priority, et autres) les distribue aux agents disponibles](../images/14-queues-fig01.png)

Habituellement, une file d'attente d'appels fonctionne comme ceci :

- Les agents se connectent à la file d'attente.
- Les appels entrants sont mis en file d'attente.
- Une stratégie de mise en file d'attente pour distribuer les appels est utilisée pour envoyer les appels aux agents.
- De la musique d'attente est jouée pendant que l'appelant attend.
- Des annonces peuvent être faites aux appelants, les informant du temps d'attente.
- L'appel est pris par l'agent et des statistiques sont générées.

L'application principale des files d'attente est le service client. En utilisant des files d'attente, vous évitez de perdre des appels lorsque vos agents sont occupés. Vous pouvez ajouter de nouveaux agents à la file d'attente si vous constatez que le nombre d'appelants dans la file d'attente augmente. Un autre avantage des files d'attente est que vous pouvez désormais obtenir des statistiques telles que le taux d'abandon d'appels, la durée moyenne des appels et l'objectif de réponse aux appels. Ces statistiques vous aideront à déterminer combien d'agents utiliser pour fournir un meilleur service à vos clients.

### Architecture ACD

L'architecture ACD est formée par des files d'attente et des agents. Un agent peut être dans deux files d'attente en même temps. Une file d'attente peut avoir des agents, des channels et des groupes d'agents.

![Architecture ACD : chaque file d'attente (Service Client, Ventes Internes) est alimentée par un numéro de téléphone et distribue les appels aux agents, qui sont à leur tour liés à des channels physiques](../images/14-queues-fig02.png)

## Queues

Les queues sont définies dans le fichier de configuration queues.conf. Les agents sont des opérateurs qui se connectent et sont membres des queues. Les agents sont définis dans le fichier agents.conf. Le système de queues s'est considérablement développé au fil de nombreuses versions, rendant le fichier de configuration étendu. Nous expliquerons certains des paramètres majeurs. Un paramètre général qui mérite d'être souligné est `autofill` :

```
autofill=yes
```

L'ancien comportement de la queue était de type serial. La queue attendait qu'un appel soit distribué avant d'envoyer l'appel suivant à l'agent suivant. Si un agent met 15 secondes à répondre à un appel, les autres appels dans la queue devaient attendre que cet appel soit répondu. Pour les queues à haut volume, ce comportement était inefficace. Le nouveau comportement autofill=yes n'attend pas qu'un appel soit répondu, mais fonctionne plutôt en parallèle. Vous pouvez enregistrer les appels dans la queue en utilisant l'option mixmonitor. Dans ce mode, les appels sont enregistrés et mixés en même temps.

### Fichier de configuration des queues

Les queues sont configurées dans le fichier queues.conf. Dans la figure, vous trouverez un exemple fonctionnel d'une queue.

![Un exemple fonctionnel du fichier queues.conf, montrant la section générale et une queue customerservice avec la stratégie, le niveau de service, les annonces, l'enregistrement et les membres](../images/14-queues-fig03.png)

### Agents

Vous pouvez configurer vos agents dans le fichier agents.conf. Les agents peuvent se connecter depuis n'importe quelle extension pour recevoir des appels. Vous pouvez appeler un agent en utilisant :

```
Dial(agent/<name>)
```

#### Connexion de l'agent

Le flux de connexion pour l'Agent 300 fonctionne comme ceci :

- L'utilisateur compose une extension qui exécute l'application `AgentLogin()`.
- `AgentLogin()` est exécuté et l'agent est associé au canal actuel.
- Vous pouvez vérifier le statut des agents en utilisant la commande `agent show all`.

![Agents : un utilisateur se connecte en composant une extension qui exécute l'application agentlogin, qui lie l'Agent 300 au canal actuel ; vous pouvez vérifier le statut de l'agent avec `agent show all`](../images/14-queues-fig04.png)

Vous pouvez définir les agents dans le fichier agents.conf

```
; Agent configuration
[general]
persistentagents=yes
[agents]
autologoff=15
autologoffunavail=yes
ackcall=no
endcall=yes
wrapuptime=5000
musiconhold => default
;
;This section contains the agent definitions, in the form:
;
; agent => agentid,agentpassword,name
;
agent => 300,300
agent => 301,301
```

### Membres

Les membres sont des canaux actifs répondant à la queue. Les membres peuvent être des canaux directs (PJSIP, DAHDI) ou des agents qui se connectent avant de recevoir des appels.


### Stratégies

Les appels sont distribués parmi les membres selon l'une de ces stratégies :

- ringall : Fait sonner tous les canaux disponibles jusqu'à ce que quelqu'un réponde.
- leastrecent : Distribue au membre le moins récemment sollicité.
- fewestcalls : Distribue au membre ayant le moins d'appels.
- random : Fait sonner une interface aléatoire.
- wrandom : Fait sonner une interface aléatoire, mais utilise la pénalité du membre comme poids lors du calcul de sa métrique.
- rrmemory : Utilise le round robin avec mémoire ; il se souvient où il s'est arrêté avec l'appel lors du dernier passage.
- rrordered : Identique à rrmemory, sauf que l'ordre des membres de la queue dans le fichier de configuration est préservé.
- linear : Fait sonner les membres dans l'ordre où ils sont listés dans queues.conf ; pour les membres dynamiques, dans l'ordre où ils ont été ajoutés.

L'ancienne stratégie `roundrobin` a été dépréciée depuis Asterisk 1.4. Ce n'est plus une stratégie documentée et elle ne devrait pas être utilisée : dans Asterisk 22, l'analyseur accepte toujours le mot `roundrobin`, mais uniquement comme un alias de rétrocompatibilité qui pointe vers `rrmemory`. Utilisez plutôt `rrmemory` (ou `rrordered`) explicitement. La liste ci-dessus est l'ensemble des stratégies documentées pour l'option `strategy` dans le `queues.conf` d'Asterisk 22.

## Agents

Les agents sont implémentés en tant que canaux proxy. Ils peuvent être utilisés au sein des files d'attente. Une autre utilisation des canaux d'agent est la mobilité des extensions. L'utilisateur peut se connecter en utilisant n'importe quel téléphone et recevoir ses appels. Cela permet à un utilisateur de se rendre dans n'importe quelle pièce pour en faire un bureau. Vous pouvez appeler un agent dans le dialplan en utilisant dial(agent/<name>). Vous définissez les agents dans le fichier agents.conf.

![Mobilité des agents : l'utilisateur décroche n'importe quel téléphone, compose une extension de connexion, et saisit le numéro d'agent ainsi que le mot de passe ; une fois que agentlogin() a réussi, l'agent (Agent 300) est prêt à prendre des appels, et vous pouvez vérifier le statut avec la commande CLI `agent show all`](../images/14-queues-fig05.png)

### Groupes d'agents

Vous pouvez choisir d'utiliser des groupes d'agents. Cette fonction ne prend pas en considération les stratégies ACD. Vous préférerez probablement lister tous les agents individuellement. Si vous souhaitez transférer vers un groupe d'agents, vous pouvez utiliser `queues.conf` :

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### Le fichier de configuration pour les agents

Les agents sont définis dans le fichier agents.conf. Vous trouverez ci-dessous un exemple fonctionnel du fichier.

![Un exemple fonctionnel du fichier agents.conf : une section générale avec persistentagents, une section agents avec les paramètres par défaut (autologoff, ackcall, endcall, wrapuptime, musiconhold), et deux définitions d'agent (300 et 301)](../images/14-queues-fig06.png)

## Applications liées à l'ACD

Le système de file d'attente d'Asterisk met à disposition plusieurs applications pour implémenter les files d'attente dans le dialplan. Ci-dessous, nous en présentons quelques-unes.

### L'application queue()

Cette application place les appels entrants dans une file d'attente particulière telle que définie dans queues.conf. La chaîne d'options peut contenir zéro ou plusieurs options d'une seule lettre (présentées dans la figure ci-dessous). En plus du transfert d'appel, un appel peut être mis en attente (parked) puis récupéré par un autre utilisateur. L'URL optionnelle sera envoyée à la partie appelée si le canal le prend en charge. Le paramètre AGI optionnel configurera un script AGI à exécuter sur le canal de la partie appelante une fois qu'elle sera connectée à un membre de la file d'attente. Le timeout provoquera l'échec de la file d'attente après un nombre spécifié de secondes, vérifié entre chaque cycle de timeout et de nouvelle tentative. Cette application définit la variable d'état QUEUE à la fin :

![L'application queue() : sa syntaxe `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — Asterisk 22 sépare les arguments par des virgules (l'ancienne forme avec pipe `|` a disparu) — et les options d'une seule lettre disponibles (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### L'application agentlogin()

Cette application demande à l'agent de se connecter au système. Elle renvoie toujours -1. Une fois connecté, l'agent recevant des appels entendra un bip lorsqu'un nouvel appel arrivera. L'agent peut rejeter l'appel en appuyant sur la touche *.

![L'application agentlogin() : sa syntaxe `AgentLogin([AgentNo][|options])` et l'option `s` pour une connexion silencieuse qui n'annonce pas la confirmation de connexion](../images/14-queues-fig08.png)

### L'application addQueueMember()

Cette application ajoute dynamiquement un périphérique (par exemple, PJSIP/3000) à une file d'attente. Si le périphérique existe déjà, elle renverra une erreur.

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### L'application removeQueueMember()

Cette application supprime dynamiquement un périphérique de la file d'attente. Si le périphérique n'appartient pas à la file d'attente, elle renverra une erreur.

```
RemoveQueueMember(queuename[|interface])
```

### Applications de support et commandes CLI

Certaines applications et commandes de console sont capables d'aider au travail avec les files d'attente. Ce qui suit décrit ce que fait chaque application :

![Applications de support (AddQueueMember, RemoveQueueMember) et commandes CLI (agent show all, queue show, queue show <name>) utilisées pour gérer les files d'attente à l'exécution](../images/14-queues-fig09.png)

## Tâches de configuration

La figure ci-dessous résume les tâches principales pour créer un système de file d'attente fonctionnel.

![Les tâches de configuration ACD : (1) créer la file d'attente (obligatoire), (2) définir les paramètres des agents (optionnel), (3) créer les agents (optionnel), (4) intégrer la file d'attente dans le dialplan (obligatoire), (5) configurer l'enregistrement des agents (optionnel), et (6) vérifier avec agent show all et queue show (optionnel)](../images/14-queues-fig10.png)

Étape 1 : Créer la file d'attente dans le fichier queues.conf :

```
[telemarketing]
music = default
;announce = queue-telemarketing
;context = qoutcon
timeout = 2
retry = 2
maxlen = 0
member => Agent/300
member => Agent/301
[auditing]
music = default
;announce = queue-auditing
;context = qoutcon
timeout = 15
retry = 5
maxlen = 0
member => Agent/600
member => Agent/601
```

Étape 2 : Définir les paramètres des agents dans le fichier agents.conf :

```
debian:/etc/asterisk# cat agents.conf
;
; Agent configuration
;
[agents]
; Define maxlogintries to allow agent to try max logins before
; failed.
; default to 3
maxlogintries=5
; Define autologoff times if appropriate.  This is how long
; the phone has to ring with no answer before the agent is
; automatically logged off (in seconds)
autologoff=15
; Define autologoffunavail to have agents automatically logged
; out when the extension that they are at returns a CHANUNAVAIL
; status when a call is attempted to be sent there.
; Default is "no".
;autologoffunavail=yes
; Define ackcall to require an acknowledgement by '#' when
; an agent logs in using agentcallbacklogin.  Default is "no".
;ackcall=no
; Define endcall to allow an agent to hangup a call by '*'.
; Default is "yes". Set this to "no" to ignore '*'.
;endcall=yes
; Define wrapuptime.  This is the minimum amount of time when
; after disconnecting before the caller can receive a new call
; note this is in milliseconds.
;wrapuptime=5000
; Define the default musiconhold for agents
; musiconhold => music_class
;musiconhold => default
;
; Define the default good bye sound file for agents
; default to vm-goodbye
;agentgoodbye => goodbye_file
; Define updatecdr. This is whether or not to change the source
; channel in the CDR record for this call to agent/agent_id so
; that we know which agent generates the call
;updatecdr=no
;
; Group memberships for agents (may change in mid-file)
;
;group=3
;group=1,2
;group=
```

Étape 3 : Créer les agents dans le fichier agents.conf :

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

Étape 4 : Insérer la file d'attente dans le dialplan, dans le fichier `extensions.conf` :

```
; Telemarketing queue.
exten=>_0800XXXXXXX,1,Answer
exten=>_0800XXXXXXX,2,Set(CHANNEL(musicclass)=default)
exten=>_0800XXXXXXX,3,Set(TIMEOUT(digit)=5)
exten=>_0800XXXXXXX,4,Set(TIMEOUT(response)=10)
exten=>_0800XXXXXXX,5,Background(welcome)
exten=>_0800XXXXXXX,6,Queue(telemarketing)
; Transfer to the queue auditing
exten => 8000,1,Queue(auditing)
exten => 8000,2,Playback(demo-echotest); No auditor available
exten => 8000,3,Goto(8000,1) ; Verify auditor again
; Agent login for the telemarketing and auditing queues
exten => 9000,1,Wait(1)
exten => 9000,2,AgentLogin()
```

### Configurer l'enregistrement de la file d'attente

Les appels peuvent être enregistrés en utilisant l'application MixMonitor d'Asterisk. (L'application autonome Monitor a été supprimée dans Asterisk 22, et l'option `monitor-type` de queues.conf n'accepte désormais que MixMonitor.) L'enregistrement peut être activé depuis l'application de file d'attente, commençant au moment où l'appel est réellement pris. Seuls les appels aboutis sont enregistrés, et aucun enregistrement n'est effectué pendant que les appelants écoutent la MOH. Pour activer la surveillance, spécifiez simplement monitor-format. Cette fonctionnalité est sinon désactivée. Vous pouvez définir le nom de fichier pour l'enregistrement en utilisant `Set(MONITOR_FILENAME=<filename>)` ; sinon, il utilisera `MONITOR_FILENAME=${UNIQUEID}`.

Dans le fichier queues.conf :

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## Opération de file d'attente

Les exemples suivants expliquent comment utiliser la file d'attente.

1. Connexion de l'agent. Exemple : Un agent dans la file d'attente de télémarketing décroche le téléphone et compose le #9000. L'agent entend un message de connexion invalide et doit saisir son nom et son mot de passe. La file d'attente d'audit suit la même procédure.
2. File d'attente. Une fois dans la file d'attente, l'agent entendra de la MOH, si elle est définie. Lorsqu'un appel arrive dans la file d'attente de télémarketing, l'agent entendra un bip et sera connecté à cet appel.
3. Fin d'appel. Lorsque l'agent termine l'appel, il/elle peut :
   - Appuyer sur ‘*’ pour se déconnecter et rester dans la file d'attente.
   - Raccrocher le téléphone, se déconnectant ainsi de la file d'attente.
   - Appuyer sur #8000 pour transférer l'appel pour audit.

## Ressources avancées

Le système de file d'attente d'Asterisk dispose de fonctionnalités avancées permettant de prioriser certains clients et agents, ainsi que d'activer un menu utilisateur.

### Menu utilisateur

Vous pouvez définir un menu pour un utilisateur en attente dans la file d'attente en utilisant des extensions à un chiffre. Pour activer cette option, définissez un context dans la configuration de file d'attente queues.conf.

### Pénalité

Les agents peuvent être configurés avec une pénalité. Une file d'attente enverra les appels en priorité aux utilisateurs ayant les valeurs de pénalité les plus faibles. Par exemple, puisque nous savons que nos clients adorent Susan et sa voix douce, nous pouvons choisir de lui assigner une priorité 0. À l'inverse, l'agent nommé Uber, qui a moins d'expérience, est moins sollicité pour le service client ; par conséquent, nous assignons une priorité 10 à cet agent. Dans le fichier queues.conf :

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### Priorité

Les files d'attente fonctionnent en mode FIFO (premier entré, premier sorti). Si vous souhaitez donner la priorité à des clients spéciaux (platine, or), vous pouvez configurer des priorités différenciées. Pour les clients platine ou or :

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

Clients bleus :

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## L'application agentcallbacklogin() est supprimée

L'application `agentcallbacklogin()` a été dépréciée par Digium dans Asterisk 1.4 (juillet 2006) et n'est plus disponible dans Asterisk 22. L'approche recommandée consiste à utiliser `AddQueueMember()` avec une interface PJSIP pour ajouter dynamiquement des membres de type callback à une file d'attente. Le document `queues-with-callback-members.txt` était inclus dans les anciens répertoires Asterisk `/doc` pour guider la migration.

L'ancien pilote de canal `chan_agent` a également été supprimé ; ses fonctionnalités ont été réécrites sous forme du module `app_agent_pool`, qui est celui qui fournit `AgentLogin()`, `AgentRequest()` et la fonction de dialplan `AGENT()` dans Asterisk 22 (ceux-ci sont toujours présents — `app_agent_pool.so` est fourni avec une version standard 22). Pour les centres d'appels modernes, cependant, le modèle standard consiste à ignorer complètement les canaux d'agent et à ajouter le périphérique PJSIP de l'agent directement à la file d'attente avec `AddQueueMember()`/`RemoveQueueMember()` (de manière statique dans `queues.conf`, ou dynamiquement depuis le dialplan ou AMI). C'est plus simple, s'intègre proprement avec l'état du périphérique PJSIP, et c'est l'approche utilisée tout au long de ce chapitre.

## Statistiques de file d'attente

Tous les événements des files d'attente sont consignés dans /var/log/asterisk/queue_log. Le format du journal de file d'attente est publié dans le document queuelog.txt situé dans le répertoire /doc de la documentation d'Asterisk. Vous trouverez ci-dessous certains des événements consignés les plus importants.

- ABANDON(position|origposition|waittime)
- AGENTDUMP
- AGENTLOGIN(channel)
- AGENTLOGOFF(channel|logintime)
- ATTENDEDTRANSFER(destexten|destcontext|holdtime|calltime|origposition)
- BLINDTRANSFER(extension|context|holdtime|calltime|origposition)
- COMPLETEAGENT(holdtime|calltime|origposition)
- COMPLETECALLER(holdtime|calltime|origposition)
- CONFIGRELOAD
- CONNECT(holdtime|bridgedchanneluniqueid)
- ENTERQUEUE(url|callerid)
- EXITEMPTY(position|origposition|waittime)
- EXITWITHKEY(key|position)
- EXITWITHTIMEOUT(position|origposition|waittime)
- QUEUESTART
- RINGNOANSWER(ringtime)
- SYSCOMPAT

Vous pouvez créer votre propre utilitaire pour traiter ces événements ou utiliser un progiciel de statistiques prêt à l'emploi :

- **QueueMetrics** (<https://www.queuemetrics.com/>) – un progiciel commercial, activement maintenu, qui analyse `queue_log` et demeure l'un des outils de reporting les plus complets pour les centres d'appels Asterisk.
- **Développement personnalisé** – étant donné que le format `queue_log` ci-dessus est stable et bien documenté, il est simple de l'analyser avec un petit script (Python, etc.) et d'alimenter une base de données ou un tableau de bord avec ces événements.

Pour une approche davantage axée sur les événements que la lecture en continu de `queue_log`, l'**Asterisk REST Interface (ARI)** et les actions **AMI** `QueueSummary`/`QueueStatus` vous permettent de créer des tableaux de bord de files d'attente en direct et des intégrations personnalisées basées sur l'état en temps réel des files d'attente, plutôt que sur l'analyse a posteriori des journaux. ARI est l'interface d'intégration moderne et prise en charge pour ce type de travail dans Asterisk 22.

## Résumé

Dans ce chapitre, vous avez appris à utiliser un ACD, son architecture et comment le configurer. Certaines fonctionnalités avancées telles que les priorités et les pénalités ont également été présentées.

## Quiz

1. Laquelle des stratégies de distribution de file d'attente suivantes est valide dans `queues.conf` (choisissez toutes les réponses qui s'appliquent) ?
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. Vous pouvez enregistrer une conversation entre un agent et un client depuis la file d'attente en définissant l'option ___ dans le fichier `queues.conf`.
3. Quelle `strategy` fait sonner les membres dans l'ordre exact où ils sont listés dans `queues.conf` ?
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. Lorsque l'agent termine un appel dans l'exemple de télémarketing, quelles actions peut-il effectuer (choisissez toutes les réponses qui s'appliquent) ?
   - A. Appuyer sur `*` pour se déconnecter et rester dans la file d'attente
   - B. Raccrocher le téléphone et se déconnecter de la file d'attente
   - C. Appuyer sur `#8000` pour transférer l'appel à des fins d'audit
   - D. Appuyer sur `#` pour se déconnecter immédiatement de toutes les files d'attente
5. Quelles sont les deux tâches *requises* pour obtenir une file d'attente fonctionnelle (choisissez toutes les réponses qui s'appliquent) ?
   - A. Créer la file d'attente
   - B. Créer les agents
   - C. Configurer les paramètres des agents
   - D. Configurer l'enregistrement
   - E. Placer la file d'attente dans le dialplan
6. Dans une file d'attente, vous pouvez proposer un menu à un seul chiffre que l'appelant peut composer pendant l'attente. Ceci est activé en définissant un(e) ___ dans la section `queues.conf` de la file d'attente :
   - A. agent
   - B. menu
   - C. context
   - D. application
7. Les applications de support `AddQueueMember()` et `RemoveQueueMember()` sont utilisées dans le ___ pour ajouter ou supprimer des membres au moment de l'exécution :
   - A. dialplan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. Depuis la suppression de chan_sip dans Asterisk 21, un membre de file d'attente statique doit référencer un canal tel que ___ plutôt que `SIP/1001`.
9. Le paramètre `wrapuptime` est le temps minimum après qu'un agent a déconnecté un appel avant que la file d'attente n'envoie un nouvel appel à cet agent.
   - A. Vrai
   - B. Faux
10. Un appelant peut obtenir une position plus élevée dans la même file d'attente en définissant la variable de canal `QUEUE_PRIO` avant d'appeler `Queue()`.
    - A. Vrai
    - B. Faux

**Réponses :** 1 — A, C, D, E, F (roundrobin n'est pas une stratégie documentée ; dans Asterisk 22, elle ne survit qu'en tant qu'alias obsolète pour rrmemory) · 2 — `monitor-format` (l'enregistrement depuis la file d'attente est activé en spécifiant `monitor-format` ; dans Asterisk 22, `monitor-type` ne prend en charge que MixMonitor) · 3 — C (linear) · 4 — A, B, C (`*` déconnecte et maintient ; `#` n'est pas une touche de déconnexion globale) · 5 — A, E · 6 — C (l'option `context`) · 7 — A (le dialplan) · 8 — `PJSIP/1001` (n'importe quelle interface `PJSIP/`) · 9 — Vrai · 10 — Vrai
