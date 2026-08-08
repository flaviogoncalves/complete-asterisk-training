# Asterisk Real-Time

Comme vous le savez, la configuration d'Asterisk s'effectue via l'utilisation de plusieurs fichiers texte dans le répertoire /etc/asterisk. Malgré la facilité d'utilisation des fichiers texte, il existe certains inconvénients connus :

- La nécessité de recharger Asterisk à chaque modification des fichiers
- Une augmentation de l'utilisation de la mémoire pour un grand volume d'utilisateurs
- La difficulté de coder une interface de provisionnement en utilisant des fichiers texte
- Aucune possibilité d'intégration avec des bases de données existantes

ARA, ou Asterisk Realtime, comme on l'appelle, a été créé par Anthony Minessale II, Mark Spencer et Constantine Filin et a été conçu pour permettre une intégration transparente avec des bases de données SQL. Une interface LDAP est également disponible. Ce système est aussi connu sous le nom d'Asterisk External Configuration et est configuré dans /etc/asterisk/extconfig.conf. Vous pouvez mapper des fichiers de configuration vers des tables dans une base de données (configuration statique) et utiliser des entrées en temps réel pour la création dynamique d'objets sans avoir besoin de recharger Asterisk.

## Objectifs

À la fin de ce chapitre, le lecteur devrait être capable de :

- Comprendre les avantages et les limites de Asterisk Real Time.
- Utiliser ODBC pour une utilisation avec ARA.
- Compiler et installer ARA en utilisant ODBC.
- Tester le système dans un environnement de laboratoire.

## Comment fonctionne Asterisk Real Time ?

Dans la nouvelle architecture Real Time, tout le code spécifique à la base de données a été déplacé vers les pilotes de canaux (channel drivers). Le canal appelle uniquement une routine générique qui effectue une recherche dans la base de données. Le résultat est un processus beaucoup plus simple et plus propre du point de vue du code source. La base de données est accessible via trois fonctions :

- STATIC : Utilisée pour configurer une configuration statique lors du chargement d'un module.
- REALTIME : Utilisée pour rechercher des objets lors d'un appel ou d'un autre événement.


- UPDATE : Utilisée pour mettre à jour des objets.

Sur Asterisk 22, les endpoints SIP sont gérés par la pile **PJSIP** (`res_pjsip`), qui est construite sur le modèle d'objet **Sorcery**. Avec l'assistant `realtime`, Sorcery charge chaque objet PJSIP depuis la base de données à la demande, et ces objets existent alors en tant qu'objets PJSIP configurés ordinaires — et non en tant que pairs realtime éphémères que l'ancien pilote SIP rejetait après chaque appel.

Comme il s'agit de véritables objets, le NAT traversal, le qualify et le message waiting indication (MWI) fonctionnent tous normalement pour les endpoints realtime. (On peut également demander à Sorcery de mettre en cache les objets en mémoire via un assistant `memory_cache`, mais cela est optionnel et distinct du chargement realtime.) Lorsque vous modifiez un objet dans la base de données, le changement est pris en compte lors de la recherche suivante ; vous n'avez pas besoin de recharger après chaque modification. (Le modèle realtime retiré `chan_sip`, avec ses familles `sippeers`/`sipusers`, n'est traité que dans le chapitre *Legacy Channels*.)

## Configuration d'Asterisk Real Time

Pour ce laboratoire, nous supposerons que vous avez déjà installé ODBC à partir du chapitre sur les CDR. ARA est configuré dans le fichier texte extconfig.conf, où deux sections sont facilement identifiables. La première est la section des fichiers de configuration statiques, où vous pouvez remplacer les fichiers de configuration texte par des tables de base de données. La seconde section est le moteur de configuration realtime, où vous configurez des tables de base de données pour des objets dynamiques (peers/users). Il n'est pas rare d'utiliser des fichiers texte pour la configuration statique et la base de données pour les entrées dynamiques. Dans ce cas, la première section reste inchangée.

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Architecture d'Asterisk Real Time : les fichiers de configuration et les tables de base de données statiques sont chargés au démarrage d'Asterisk, tandis que les tables de base de données realtime fournissent une configuration dynamique lue à la demande lors d'un appel.]((../images/18-realtime-fig01.png))

```
;
[settings]
;
; Static configuration files:
;
; file.conf => driver,database[,table]
;
; maps a particular configuration file to the given
; database driver, database and table (or uses the
; name of the file as the table if not specified)
;
;uncomment to load queues.conf via the odbc engine.
;
;queues.conf => odbc,asterisk,ast_config
;
; The following files CANNOT be loaded from Realtime storage:
;       asterisk.conf
;       extconfig.conf (this file)
;       logger.conf
;
; Additionally, the following files cannot be loaded from
; Realtime storage unless the storage driver is loaded
; early using 'preload' statements in modules.conf:
;       manager.conf
;       cdr.conf
;       rtp.conf
;
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
;example => odbc,asterisk,alttable
;ps_endpoints => odbc,asterisk
;ps_aors => odbc,asterisk
;ps_auths => odbc,asterisk
;ps_contacts => odbc,asterisk
;voicemail => odbc,asterisk
;extensions => odbc,asterisk
;queues => odbc,asterisk
;queue_members => odbc,asterisk
```


### Section de configuration statique

La section de configuration statique est l'endroit où vous stockez l'équivalent des fichiers de configuration dans la base de données. Ces configurations sont lues lors du chargement d'Asterisk. Certains modules relisent la base de données lorsque vous effectuez un rechargement. Voici des exemples de configuration statique :

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

Le mappage de fichiers statiques est très utile pour les fichiers de configuration qui n'ont pas d'équivalent realtime par objet. Pour PJSIP, préférez les familles realtime par objet (`ps_endpoints`, `ps_aors`, etc.) décrites plus loin dans ce chapitre plutôt que de mapper l'intégralité de `pjsip.conf` en tant que fichier statique.

Trois exemples sont décrits ci-dessus. Dans le premier, vous liez queues.conf à une table queues dans la base de données asteriskdb. Dans le deuxième exemple, vous liez pjsip.conf à la table pjsip_conf dans la base de données asteriskdb définie dans la configuration odbc. Dans le dernier exemple, vous liez iax.conf à un annuaire LDAP. MyBaseDN est le DN de base à rechercher. Dans l'exemple précédent, l'application app_queue.so est chargée tandis que le pilote MySQL interroge la base de données et obtient les informations requises.

### Section de configuration Real Time

La configuration real-time (seconde partie du fichier extconfig.conf) est l'endroit où l'élément de configuration à charger est configuré, mis à jour et déchargé en temps réel. Avec le real time, il n'est pas nécessaire de recharger les configurations. La syntaxe real-time est la suivante :

```
<family name> => <driver>,<database name>[,table_name]
```

Exemple :

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

Ici, nous avons cinq lignes de configuration. Dans la première ligne, vous liez la famille PJSIP/Sorcery `ps_endpoints` à une table `ps_endpoints` dans la base de données asteriskdb. Dans la dernière, vous liez la famille voicemail à la table test dans la base de données asteriskdb. Chaque type d'objet PJSIP (endpoint, aor, auth, contact) possède sa propre famille et sa propre table ; l'ensemble complet est présenté dans la section « PJSIP Realtime (Sorcery) » ci-dessous. Les familles `voicemail`, `extensions`, `queues` et `queue_members` sont toujours valides dans Asterisk 22.

## PJSIP Realtime (Sorcery)

Sur Asterisk 22, les endpoints SIP sont gérés exclusivement par la pile **PJSIP** (`res_pjsip`), qui est construite sur la couche d'abstraction d'objets **Sorcery**. Plutôt qu'un simple "peer" SIP, PJSIP divise un compte SIP en plusieurs types d'objets, chacun étant stocké dans sa propre table realtime :

| Type d'objet Sorcery | Table realtime | Contenu |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | paramètres par compte (context, codecs, DTMF, etc.) |
| aor (address of record) | ps_aors | limites d'enregistrement et paramètres `qualify` |
| auth | ps_auths | identifiants `username` / `password` |
| contact | ps_contacts | l'emplacement enregistré dynamiquement |
| domain alias | ps_domain_aliases | domaines SIP alternatifs pour un endpoint |
| endpoint identifier by IP | ps_endpoint_id_ips | correspondance d'un endpoint par IP source |

Le mode realtime pour PJSIP est activé à deux endroits. Premièrement, mappez les types d'objets Sorcery vers realtime dans `extconfig.conf` :

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

Deuxièmement, indiquez à Sorcery d'utiliser l'assistant `realtime` pour ces types d'objets dans `sorcery.conf`. Le nom du mapping (ici `res_pjsip`) est le module dont vous déplacez les objets, et la valeur de droite pointe vers la famille que vous avez définie dans `extconfig.conf` :

```
[res_pjsip]
endpoint=realtime,ps_endpoints
aor=realtime,ps_aors
auth=realtime,ps_auths
domain_alias=realtime,ps_domain_aliases
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
```

Vous pouvez mélanger des objets statiques et realtime. Si vous omettez un type dans `sorcery.conf`, ce type d'objet continue d'être lu depuis `pjsip.conf`. Un modèle courant consiste à conserver les transports statiques et les paramètres globaux dans `pjsip.conf` tout en stockant les endpoints, aors, auths et contacts dans la base de données.

### Création du schéma realtime PJSIP avec Alembic

Asterisk fournit des migrations de base de données pour tous ses schémas realtime sous `contrib/ast-db-manage`. C'est la méthode prise en charge pour créer (et mettre à jour la version) des tables PJSIP — vous n'écrivez plus manuellement les définitions de table `ps_*`. L'ensemble de migration `config` contient les tables PJSIP/Sorcery.

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

Cela crée `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts` et les autres tables PJSIP avec les colonnes correctes pour la version d'Asterisk en cours d'exécution. (Alembic nécessite le package Python `alembic` ainsi qu'un pilote SQLAlchemy tel que `pymysql` pour MySQL/MariaDB ou `psycopg2` pour PostgreSQL.)

Un endpoint realtime minimal consiste alors en une ligne dans chacune des trois tables — par exemple pour l'endpoint `6010` :

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

Après l'insertion des lignes, il n'y a rien à recharger — le prochain REGISTER/INVITE récupère les objets depuis la base de données. Vous pouvez confirmer ce que le mode realtime a renvoyé avec :

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## Configuration de la base de données

Maintenant que nous avons configuré le fichier extconfig.conf, créons les tables. De manière générale, chaque colonne de base de données correspond à un nom d'option du fichier de configuration correspondant. Les tables PJSIP `ps_*` suivent cette règle : chaque colonne `ps_endpoints` porte le nom d'une option d'endpoint `pjsip.conf`, chaque colonne `ps_auths` celui d'une option d'authentification, et ainsi de suite. Par exemple, l'endpoint `pjsip.conf` ci-dessous,

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

est stocké sous forme d'une ligne répartie sur trois tables. La ligne `ps_endpoints` contient `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000` ; la ligne `ps_auths` contient `id=4000, auth_type=userpass, username=4000, password=supersecret` ; et la ligne `ps_aors` contient `id=4000, max_contacts=1`. Vous n'avez besoin de remplir que les colonnes que vous utilisez réellement — toute colonne laissée à NULL revient à la valeur par défaut de l'option. Si vous souhaitez, par exemple, le paramètre `callerid` sur un endpoint, remplissez la colonne `callerid` de `ps_endpoints` (le nom de la colonne est identique au nom de l'option `pjsip.conf`).

Une table de voicemail suit le même principe. Ses colonnes correspondent aux champs `voicemail.conf` :

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

Le `uniqueid` doit être unique pour chaque utilisateur de voicemail et peut être en auto-incrémentation. Il n'a pas besoin d'avoir de relation avec la mailbox ou le context.

### Construction d'un dialplan en utilisant Asterisk Real Time

Vous pouvez également utiliser le système temps réel pour créer le dialplan. ARA utilise l'instruction `switch` pour inclure les extensions temps réel dans le dialplan normal contenu dans le fichier extensions.conf. La table des extensions doit ressembler à celle ci-dessous :

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

La famille temps réel `extensions` est inchangée dans Asterisk 22 ; assurez-vous simplement que la colonne `appdata` appelle les canaux PJSIP, par exemple `PJSIP/4000`. Dans le dialplan, vous devez utiliser la commande `switch` pour utiliser le temps réel.

![Construction d'un dialplan avec Asterisk Real Time : extensions.conf utilise une instruction `switch => realtime` pour extraire les lignes d'extension (context, exten, priority, app, data) d'une table de base de données au lieu du fichier texte.](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

ou

```
[local]
switch => realtime/from-internal@extensions
```

## Lab : Installation et création des tables de base de données

Dans ce lab, nous allons préparer la base de données pour recevoir les paramètres Asterisk. Nous ne préparerons que les tables REALTIME. La configuration statique sera laissée aux fichiers de configuration texte (sympa, n'est-ce pas ?). La création des tables dans MySQL suit ci-dessous.

Étape 1 : Accédez à la base de données MySQL en tant que root.

```
mysql -u root -p
```

Étape 2 : Connectez-vous au serveur MySQL créé dans les labs CDR.

```
mysql -u astdb -p
```

Lorsque le mot de passe est demandé, tapez supersecret.

Étape 3 : Créez les tables nécessaires. Les fichiers de schéma statiques hérités sont toujours fournis sous `contrib/realtime/` (par exemple `/usr/src/asterisk-22.x/contrib/realtime/mysql`), mais sur Asterisk 22, la méthode recommandée et correcte en termes de version pour construire les tables realtime — en particulier les tables PJSIP `ps_*` — consiste à utiliser les migrations **Alembic** sous `contrib/ast-db-manage` (voir la section "Création du schéma realtime PJSIP avec Alembic" ci-dessus).

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

L'ensemble de migrations Alembic `config` construit les tables PJSIP `ps_*` (ainsi que `voicemail`, `extensions` et les autres schémas realtime) avec exactement les colonnes attendues par la version d'Asterisk en cours d'exécution, de sorte que le schéma corresponde toujours à la version installée.

Utilisez supersecret comme mot de passe.

Étape 4 : Vérifiez la création des tables.

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

Vous devriez voir les tables PJSIP `ps_*` (créées par la migration Alembic `config`), ainsi que les tables `voicemail`, `extensions` et les autres tables realtime :

```
mysql> show tables;
+----------------------------+
| Tables_in_astdb            |
+----------------------------+
| ps_aors                    |
| ps_auths                   |
| ps_contacts                |
| ps_domain_aliases          |
| ps_endpoint_id_ips         |
| ps_endpoints               |
| ps_registrations           |
| extensions                 |
| voicemail                  |
+----------------------------+
```

(Alembic crée plus de tables que celles-ci — la liste ci-dessus montre celles qui sont pertinentes pour ce lab.)

Étape 5 : La base de données est déjà configurée pour ODBC (depuis le lab CDR), donc aucune configuration ODBC supplémentaire n'est nécessaire ici.

Étape 6 : Inspectez et remplissez les tables depuis le client MySQL. Vous n'avez pas besoin d'un outil graphique tel que phpMyAdmin — chaque étape de ce chapitre consiste en du SQL simple, copiable et exécutable depuis la ligne de commande `mysql`. Connectez-vous à la base de données `astdb` (utilisez `supersecret` lorsque vous y êtes invité) :

```
mysql -u astdb -p astdb
```

Vous pouvez confirmer les colonnes d'une table à tout moment avec `DESCRIBE`, par exemple :

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

Ces tables ont été créées par la migration Alembic `config`, donc leurs colonnes correspondent déjà aux noms d'options `pjsip.conf` pour la version d'Asterisk en cours d'exécution — vous ne remplissez que les colonnes dont vous avez besoin.

## Lab : Configuration et test de ARA

Dans ce lab, nous allons modifier la configuration de extconfig.conf pour refléter notre configuration de base de données et nos tables.

Étape 1 : Configurer extconfig.conf et recharger Asterisk.

```
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
ps_endpoints => odbc,cdr
ps_aors => odbc,cdr
ps_auths => odbc,cdr
ps_contacts => odbc,cdr
voicemail => odbc,cdr,voicemail
extensions => odbc,cdr,extensions
```

Notez les familles `ps_endpoints`, `ps_aors`, `ps_auths` et `ps_contacts` ci-dessus ; associées aux mappages `sorcery.conf` correspondants (voir la section "PJSIP Realtime (Sorcery)"), elles permettent à PJSIP de lire ses comptes depuis la base de données. Les familles `voicemail` et `extensions` complètent cet exemple.

Étape 2 : Test d'extension Real Time. Créez un nouvel endpoint `6010` en insérant une ligne dans chacune des tables `ps_auths`, `ps_aors` et `ps_endpoints`, puis essayez d'enregistrer cet endpoint avec un softphone. Exécutez le SQL suivant dans le client `mysql` (`mysql -u astdb -p astdb`) :

```sql
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('6010-auth', 'userpass', '6010', 'supersecret');

INSERT INTO ps_aors (id, max_contacts)
VALUES ('6010', 1);

INSERT INTO ps_endpoints
  (id, transport, aors, auth, context, disallow, allow, dtmf_mode, direct_media)
VALUES
  ('6010', 'transport-udp', '6010', '6010-auth', 'from-internal',
   'all', 'ulaw', 'rfc4733', 'no');
```

Les trois lignes décrivent ensemble un compte SIP. Les paramètres de compte restants sont répartis entre les objets PJSIP : le context, les codec, le mode DTMF et la gestion des médias résident sur l'endpoint (les six dernières colonnes ci-dessus) ; l'enregistrement dynamique réside sur l'AOR. Il n'existe pas de flag "dynamic" séparé — un AOR accepte les REGISTER dynamiques tant que `max_contacts` est supérieur à zéro, et chaque emplacement enregistré est écrit dans `ps_contacts`.

Dans PJSIP, le mode DTMF hors bande RFC 2833 / RFC 4733 est nommé `rfc4733`, et `dtmf_mode=rfc4733` est la valeur par défaut — la colonne `dtmf_mode` ci-dessus est donc optionnelle et n'est affichée que pour plus de clarté.

Étape 3 : Essayez d'enregistrer le nouveau téléphone avec un softphone en utilisant le nom d'utilisateur `6010` et le mot de passe `supersecret`. Confirmez l'enregistrement sur la CLI Asterisk :

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

Étape 4 : Inclure les extensions dans la base de données.

```
mysql -u astdb -p
```

Entrez le mot de passe :

Utilisez supersecret lorsque cela vous est demandé, puis insérez la ligne d'extension depuis le client MySQL :

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

Étape 5 : Inclure Asterisk Real Time dans le dialplan. Dans le context `default` :

```
switch => realtime/test@extensions
```

Rechargez les extensions pour activer le changement.

```
asterisk-server*CLI> extensions reload
```

Étape 6 : Reconfigurez l'un des téléphones avec le nom d'utilisateur `bria`, si vous ne l'avez pas déjà fait.

Étape 7 : Composez le 6007 depuis un téléphone existant ; le téléphone `bria` devrait sonner.

## Résumé

Dans ce chapitre, vous avez appris qu'Asterisk Real Time permet de placer vos configurations dans une base de données. Asterisk est fourni avec des pilotes realtime natifs pour ODBC (qui permet d'accéder à toute base de données supportée par UnixODBC, y compris MySQL/MariaDB et SQLite) et PostgreSQL, ainsi qu'un pilote realtime LDAP pour les backends d'annuaire. MySQL/MariaDB est accessible via ODBC, comme nous l'avons fait dans ce chapitre (un module complémentaire `res_config_mysql` dédié existe également, mais il ne fait pas partie de la compilation principale, c'est pourquoi ODBC est la voie privilégiée). La configuration est divisée en configuration statique et en temps réel. La configuration statique remplace les fichiers de configuration, tandis que la configuration en temps réel crée des objets dynamiques qui ne sont chargés que lorsqu'un appel ou un événement connexe se produit. Nous avons conclu par un laboratoire pratique sur l'installation et la configuration d'ARA.

## Quiz

1. Asterisk Realtime fait partie de la distribution standard d'Asterisk.
   - A. Vrai
   - B. Faux
2. Les paramètres de connexion d'un serveur de base de données sont configurés dans le fichier :
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. Le fichier `extconfig.conf` configure les tables utilisées par Realtime. Il possède deux sections distinctes (cochez-en deux) :
   - A. Configuration statique
   - B. Configuration Realtime
   - C. Routes sortantes
   - D. Adresses IP et ports de base de données
4. Dans la configuration statique, une fois que les objets sont chargés depuis la base de données, ils sont conservés dans la mémoire d'Asterisk et ne sont actualisés qu'au démarrage ou lors d'un rechargement.
   - A. Vrai
   - B. Faux
5. PJSIP realtime (Sorcery) prend entièrement en charge `qualify` et MWI pour les endpoint realtime, car Sorcery les charge comme des objets PJSIP configurés ordinaires au lieu de les supprimer après chaque appel comme le faisaient les anciens peers SIP realtime.
   - A. Vrai
   - B. Faux
6. Dans PJSIP realtime, quelles tables contiennent les endpoint et leurs contacts enregistrés ?
   - A. `ps_endpoints` et `ps_contacts`
   - B. `ps_peers` et `ps_registry`
   - C. `ps_config` et `ps_data`
   - D. `extconfig` et `res_odbc`
7. Vous pouvez toujours utiliser des fichiers de configuration texte même après avoir activé ARA.
   - A. Vrai
   - B. Faux
8. phpMyAdmin est obligatoire lorsque vous utilisez Realtime.
   - A. Vrai
   - B. Faux
9. La base de données doit être créée avec chaque champ existant dans le fichier de configuration.
   - A. Vrai
   - B. Faux
10. Sur Asterisk 22, quelle est la méthode recommandée et correcte en termes de version pour créer les tables PJSIP realtime (`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`) ?
    - A. Écrire manuellement les instructions `CREATE TABLE` pour chaque table `ps_*`
    - B. Importer le `mysql_config.sql` hérité depuis `contrib/realtime/`
    - C. Exécuter les migrations Alembic `config` sous `contrib/ast-db-manage` (`alembic -c config.ini upgrade head`)
    - D. Les tables sont créées automatiquement lors du premier démarrage d'Asterisk

**Réponses :** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
