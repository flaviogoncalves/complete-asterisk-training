# Enregistrements des détails d'appels (CDR) Asterisk

Asterisk, comme d'autres plateformes de téléphonie, permet la facturation des appels téléphoniques. Plusieurs programmes sur le marché peuvent importer les enregistrements générés par les PBX. Ces enregistrements sont utilisés pour vérifier le montant exact de la facture et les statistiques, entre autres choses.

## Objectifs

À la fin de ce chapitre, le lecteur devrait être capable de :

- Décrire où et dans quel format les enregistrements sont générés
- Générer des enregistrements en utilisant ODBC (Open Database Connectivity)
- Implémenter un schéma d'authentification intégré à la facturation

## Format des CDR Asterisk

Asterisk génère un enregistrement de détail d'appel (CDR) pour chaque appel. Ces enregistrements sont stockés, par défaut, dans un fichier texte au format CSV (valeurs séparées par des virgules) dans le répertoire /var/log/asterisk/cdr-csv. Le fichier est organisé selon les champs suivants :

| Champ | Description | Type |
|-------|-------------|------|
| Accountcode | Numéro de compte à utiliser | Chaîne |
| Src | Numéro de l'appelant (Caller ID) | Chaîne |
| Dst | Extension de destination | Chaîne |
| Dcontext | Context de destination | Chaîne |
| Clid | Caller ID avec texte | Chaîne |
| Channel | Canal utilisé | Chaîne |
| Dstchannel | Canal de destination | Chaîne |
| Lastapp | Dernière application | Chaîne |
| Lastdata | Données de la dernière application | Chaîne |
| Start | Début de l'appel | Date/Heure |
| Answer | Réponse à l'appel | Date/Heure |
| End | Fin de l'appel | Date/Heure |
| Duration | Durée, de la numérotation au raccrochage | Entier (secondes) |
| Billsec | Durée, de la réponse au raccrochage | Entier (secondes) |
| Disposition | Résultat de l'appel (ANSWERED, NO ANSWER, BUSY, FAILED, CONGESTION) | Chaîne |
| Amaflags | Indicateurs (DEFAULT, OMIT, BILLING, DOCUMENTATION) | Chaîne |
| Userfield | Champ défini par l'utilisateur | Chaîne |

Exemple d'un fichier CSV. Chaque ligne représente un enregistrement ; les champs apparaissent dans le même ordre que dans le tableau ci-dessus (`accountcode` en premier, `amaflags` en dernier) :

```text
# accountcode,src,dst,dcontext,clid,channel,dstchannel,lastapp,lastdata,
#   start,answer,end,duration,billsec,disposition,amaflags
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-5f30","PJSIP/8584-9153","Dial","PJSIP/8584,30,tT","2006-03-27 16:05:00","2006-03-27 16:05:00","2006-03-27 16:05:00","0","0","ANSWERED","DOCUMENTATION"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-96f5","PJSIP/8584-3312","Dial","PJSIP/8584,30,tT","2006-03-27 16:16:00","2006-03-27 16:16:00","2006-03-27 16:16:00","0","0","ANSWERED","BILLING"
"1234","4830258576","*72*1234*8584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-74ac","PJSIP/8584-297b","Dial","PJSIP/8584,30,tT","2006-03-27 16:22:00","2006-03-27 16:22:00","2006-03-27 16:22:00","0","0","ANSWERED","BILLING"
"1234","4830258576","2012348584","admin","""Joana D'Arc"" <4830258576>","PJSIP/8576-2c5d","PJSIP/8584-9870","Dial","PJSIP/8584,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
"1234","4830258584","2012348576","default","""Luis Sample"" <4830258584>","PJSIP/8584-03fd","PJSIP/8576-645c","Dial","PJSIP/8576,30,tT","2006-03-27 16:37:00","2006-03-27 16:37:00","2006-03-27 16:37:00","0","0","ANSWERED","BILLING"
```

## Codes de compte et comptabilité automatique des messages

Vous pouvez spécifier des codes de compte et des indicateurs ama sur chaque canal. Habituellement, cela se fait dans le fichier de configuration du canal (par exemple, chan_dahdi.conf, pjsip.conf). Le paramètre amaflags définit ce qu'il faut faire avec l'enregistrement CDR. Les valeurs possibles pour amaflag sont :

- Default
- Omit
- Billing
- Documentation

De la même manière qu'un enregistrement peut être marqué pour la facturation ou la documentation, un code de compte peut être défini sur chaque enregistrement. Le code de compte est une chaîne de caractères libre (l'option `accountcode` endpoint accepte n'importe quelle chaîne, et l'enregistrement CDR le stocke dans un champ de 80 caractères) généralement utilisée pour affecter un enregistrement à un département ou à une unité commerciale. Exemple : section endpoint de pjsip.conf

```
[8576]
type=endpoint
accountcode=Support
```

L'indicateur AMA n'est pas une option `pjsip.conf` endpoint dans Asterisk 22 ; définissez-le par appel depuis le dialplan avec la fonction `CHANNEL` (par exemple `Set(CHANNEL(amaflags)=billing)`), ou avec `Set(CDR(amaflags)=billing)`.

## Modification du format CSV et/ou CDR

Vous pouvez modifier le format CSV en changeant le fichier cdr_custom.conf.

```
;
; Mappings for custom config file
;
[mappings]
Master.csv =>
"${CDR(clid)}","${CDR(src)}","${CDR(dst)}","${CDR(dcontext)}","${CDR(channel)}"
,"${CDR(dstchannel)}","${CDR(lastapp)}","${CDR(lastdata)}","${CDR(start)}","${C
DR(answer)}","${CDR(end)}","${CDR(duration)}","${CDR(billsec)}","${CDR(disposit
ion)}","${CDR(amaflags)}","${CDR(accountcode)}","${CDR(uniqueid)}","${CDR(userf
ield)}"
```

Vous pouvez modifier le format CDR dans le fichier cdr_custom.conf.

## Stockage des CDR

Le stockage des CDR peut être réalisé de plusieurs manières. La méthode la plus importante consiste à utiliser des fichiers texte CSV qui peuvent être facilement importés dans des tableurs. Pour les petites entreprises, cela suffit généralement. Certains logiciels de facturation acceptent, par défaut, les fichiers CSV. Cependant, stocker les CDR dans une base de données est bien meilleur et plus sûr. Asterisk prend en charge plusieurs types de bases de données. Il existe sur le marché des interfaces graphiques pour la facturation. Avec autant de pilotes, lequel choisir ?

### Pilotes de stockage disponibles

- cdr_csv – Fichiers texte avec valeurs séparées par des virgules
- cdr_custom – Fichiers texte personnalisables avec valeurs séparées par des virgules
- cdr_adaptive_odbc – Backend ODBC adaptatif (préféré pour le stockage en base de données)
- cdr_odbc – Bases de données prises en charge par unixODBC (hérité ; cdr_adaptive_odbc est préféré)
- cdr_pgsql – Bases de données Postgres
- cdr_tds (cdr_freetds) – Bases de données Sybase et MSSQL via FreeTDS
- cdr_manager – CDR vers l'interface Manager
- cdr_radius – Interface CDR radius
- cdr_sqlite3_custom – Module CDR personnalisé SQLite3

Le module `cdr_addon_mysql` (cdr_mysql) que les anciens guides recommandaient a été supprimé dans Asterisk 19, il n'y a donc pas de pilote CDR MySQL natif sur Asterisk 22. Pour écrire des CDR vers MySQL/MariaDB, utilisez `cdr_adaptive_odbc` avec un pilote ODBC MySQL — l'approche utilisée dans ce chapitre.

L'enregistrement des CDR est effectué par tous les modules actifs chargés dans le fichier /etc/asterisk/modules.conf. Si le paramètre autoload=yes est défini, tous les modules sont chargés. Pour vérifier quels cdr_drivers sont actuellement chargés dans le système, utilisez la commande ci-dessous :

```
asterisk*CLI> module show like cdr_
Module                 Description                              Use Count  Status
Support Level
cdr_adaptive_odbc.so   Adaptive ODBC CDR backend                0          Running
core
cdr_csv.so             Comma Separated Values CDR Backend       0          Running
extended
cdr_custom.so          Customizable Comma Separated Values CDR  0          Running
core
cdr_manager.so         Asterisk Manager Interface CDR Backend   0          Running
core
cdr_odbc.so            ODBC CDR Backend                         0          Running
extended
cdr_sqlite3_custom.so  SQLite3 Custom CDR Module                0          Not Running
extended
6 modules loaded
```

Si vous voyez la capture d'écran ci-dessus, au moins cdr_adaptive_odbc, cdr_csv, cdr_custom, cdr_manager, cdr_odbc et cdr_sqlite3_custom sont en cours d'exécution. Ces dernières années, après quelques astricons, il est devenu clair pour moi que l'équipe Asterisk privilégiait ODBC. C'est le seul pilote prenant en charge le regroupement de connexions (connection pooling). Le regroupement de connexions est un avantage majeur en termes de performances car vous n'avez pas à ouvrir une nouvelle connexion pour chaque opération. Ce chapitre était précédemment rédigé en utilisant cdr_mysql. Je suis passé à cdr_adaptive_odbc pour cette édition, même en sachant qu'il est un peu plus complexe à configurer. Le choix de cdr_adaptive_odbc nous permet également de personnaliser le CDR. Vous pouvez simplement définir une nouvelle variable CDR dans le dialplan et ajouter la colonne correspondante à la base de données. Par exemple, pour enregistrer la gigue (jitter) audio :

```
Set(CDR(jitter)=${RTPAUDIOQOSJITTER})
```

### Stockage CSV

Comme nous l'avons dit précédemment, par défaut, Asterisk envoie tous les CDR vers un fichier texte CSV en utilisant le module cdr_csv.so. Si vous ne voyez pas les fichiers dans /var/log/asterisk/cdr-csv, vérifiez si le module est chargé en utilisant la commande CLI module show. S'il n'est pas chargé, vérifiez modules.conf. Dans ce chapitre, nous enverrons les CDR vers cdr_csv en guise de sauvegarde.

### Configuration du fichier modules.conf

Pour charger uniquement les modules appropriés, utilisez les lignes ci-dessous dans le fichier modules.conf

```
noload => cdr_custom.so
noload => cdr_odbc.so
noload => cdr_manager.so
noload => cdr_sqlite3_custom.so
```

Désormais, nous n'avons que cdr_csv et cdr_adaptive_odbc de chargés.

## Installation et configuration d'ODBC sur Ubuntu 22.04

Je regrette toujours de publier des instructions détaillées dans un livre. Elles changent parfois avant même que le livre ne soit publié. Les versions évoluent, les modules changent, alors essayez d'adapter les commandes présentées ici à votre propre situation. La plupart du temps, des changements mineurs suffisent pour reproduire l'installation. Soyez attentif aux étapes, même les utilisateurs Linux expérimentés trouveront difficile l'installation des pilotes ODBC.

Étape 1 - Installer les paquets requis :

```
apt-get install mysql-server unixodbc unixodbc-dev libltdl-dev libtool
```

Étape 2 - Créer une base de données et un utilisateur :

```
mysql -u root -p
```

(Utilisez le mot de passe défini lors de la création du serveur mysql) Tapez ces commandes dans la ligne de commande mysql

```
CREATE USER 'astdb'@'%' IDENTIFIED BY 'supersecret';
CREATE DATABASE cdr;
GRANT ALL PRIVILEGES ON cdr.* TO 'astdb'@'%';
FLUSH PRIVILEGES;
EXIT
```

Étape 3 - Créer la base de données

```
cd /usr/src/asterisk-22.*/contrib/scripts/realtime/mysql
mysql -u root -p astdb <mysql_cdr.sql
```

Étape 4 : Téléchargez le connecteur MySQL ODBC depuis Oracle. Vérifiez votre système d'exploitation en utilisant : `lsb_release -a`. Pour Ubuntu 22.04 (x86_64), visitez https://dev.mysql.com/downloads/connector/odbc/ et choisissez la version 8.x ou 9.x actuelle pour Ubuntu 22.04. Le nom de fichier exact et le numéro de version changent avec le temps, donc définissez `VER` (ci-dessous) avec le nom de la version Linux glibc actuelle.

```
cd /usr/src
# Pick the current Linux (glibc) build for your platform from
# https://dev.mysql.com/downloads/connector/odbc/ and set VER to its name:
VER=mysql-connector-odbc-9.0.0-linux-glibc2.28-x86-64bit
wget https://dev.mysql.com/get/Downloads/Connector-ODBC/9.0/$VER.tar.gz
tar -xzvf $VER.tar.gz
```

Étape 5 : Installer le pilote ODBC

```
cd /usr/src/$VER
cp bin/* /usr/local/bin
cp lib/* /usr/local/lib
myodbc-installer -a -d -n "MySQL" -t "Driver=/usr/local/lib/libmyodbc9w.so"
```

Étape 6 - Configurer le connecteur ODBC, modifiez le fichier /etc/odbc.ini pour créer le DSN (Data Source Name)

```
[astconn]
Description = MySQL connector for astdb database
Driver = /usr/local/lib/libmyodbc9w.so
Database = astdb
Server = localhost
Port = 3306
```

Étape 7 : Tester l'accès au pilote en utilisant iSQL. iSQL est un utilitaire en ligne de commande pour se connecter à la base de données via unixodbc.

```
isql -v astconn astdb supersecret
>show tables
```

S'il vous plaît, ne poursuivez pas avec la configuration d'Asterisk si vous ne pouvez pas voir le résultat de la commande isql.

### Configuration d'ODBC dans Asterisk

Avant de pouvoir configurer cdr_adaptive_odbc, vous devez d'abord configurer le fichier de ressources ODBC.

Étape 1 - Connecter Asterisk à ODBC. Modifiez le fichier res_odbc.conf :

```
[cdr]
enabled => yes
dsn => astconn
username => astdb
password => supersecret
pre-connect => yes
```

Étape 2 – Redémarrer Asterisk et tester en utilisant

```
asterisk*CLI> odbc show
```

Le résultat est affiché ci-dessous.

```
asterisk*CLI> odbc show
ODBC DSN Settings
-----------------
Name:   cdr
DSN:    astconn
  Number of active connections: 1 (out of 20)
```

Étape 3 – Configurer le pilote ODBC adaptatif dans /etc/asterisk/cdr_adaptive_odbc.conf

```
[cdr]
connection=cdr
table=cdr
```

Ici `connection` pointe vers la section de connexion `[cdr]` définie dans `res_odbc.conf`, et `table` est la table de base de données où les CDR sont écrits.

Étape 4 – Recharger le module cdr_adaptive_odbc.so :

```
asterisk*CLI> reload cdr_adaptive_odbc
```

Étape 5 – Passez quelques appels et vérifiez la base de données pour de nouveaux enregistrements. Pour vérifier la base de données :

```
mysql -u root -p
>use astdb
>select * from cdr;
```

## Applications et fonctions

Plusieurs applications sont liées à la facturation.

### CDR(accountcode)

Définit un code de compte avant d'appeler une autre application dial() ; par exemple : Format :

```
Set(CDR(accountcode)=account)
```

Le code de compte peut être vérifié en utilisant la variable de canal ${CDR(accountcode)}

### CDR(amaflags)

Définit un indicateur à des fins de facturation. Les options sont default, omit, documentation et billing.

```
Set(CDR(amaflags)=amaflags)
```

### Set(CDR_PROP(disable)=1)

Désactive l'enregistrement des CDR pour le canal actuel, de sorte qu'aucun CDR ne soit écrit dans le fichier ou la base de données. Le rétablir à `0` réactive l'enregistrement.

```
Set(CDR_PROP(disable)=1)
```

L'application `NoCDR()` utilisée dans les éditions précédentes à cette fin a été supprimée dans Asterisk 21 ; sur Asterisk 22, vous désactivez le CDR d'un canal avec `Set(CDR_PROP(disable)=1)` à la place.

### ResetCDR()

Réinitialise l'enregistrement des données d'appel (Call Data Record) : l'heure `start` (et, si répondu, l'heure `answer`) est réglée sur l'heure actuelle et toutes les variables CDR sont effacées. Si l'option `v` est définie, les variables CDR sont préservées lors de la réinitialisation.

### Set(CDR(userfield)=Value)

Cette commande définit un champ utilisateur dans le CDR. Lors de l'utilisation de `cdr_adaptive_odbc`, le champ utilisateur est automatiquement stocké si une colonne `userfield` existe dans la table CDR — aucune recompilation de la source n'est nécessaire. Pour les fichiers texte CSV, vous devez modifier le code source (cdr_csv.c) et recompiler Asterisk si vous souhaitez utiliser des champs utilisateur.

Les éditions précédentes stockaient les CDR dans MySQL avec le module `cdr_addon_mysql` (`cdr_mysql.conf`). Ce module a été supprimé dans Asterisk 19, il n'est donc pas disponible sur Asterisk 22. Le chemin pris en charge est désormais `cdr_adaptive_odbc` avec un pilote ODBC MySQL, qui stocke le champ utilisateur — ainsi que toute autre colonne personnalisée — nativement grâce à son mappage de colonnes adaptatif.

### Ajout au champ utilisateur

Les éditions précédentes utilisaient l'application `AppendCDRUserField()` pour ajouter des données au champ utilisateur du CDR. Cette application a été supprimée d'Asterisk ; sur Asterisk 22, vous ajoutez des données au champ utilisateur en lisant et en redéfinissant celui-ci avec la fonction `CDR`, par exemple `Set(CDR(userfield)=${CDR(userfield)}extra)`.

![13-call-detail-records figure 1](../images/13-call-detail-records-img01.png)

## Authentification des utilisateurs

Certaines entreprises facturent les appels à leurs employés. Dans Asterisk, vous pouvez définir un mécanisme d'authentification qui vous permet de facturer l'utilisateur authentifié dans les CDR. Cette authentification peut être effectuée en utilisant un mot de passe transmis en tant que paramètre à l'application Authenticate — un fichier de mots de passe, indiqué par un / (barre oblique) avant le paramètre, ou une clé de base de données Asterisk (en utilisant l'option `d`). Format :

```
Authenticate(password[,options[,maxdigits[,prompt]]])
Authenticate(/passwdfile[,options])
```

Options :

- a – Définit le code de compte du canal sur le mot de passe saisi.
- d – Interprète le chemin donné comme une clé de base de données Asterisk plutôt que comme un fichier littéral.
- m – Interprète le chemin comme un fichier de lignes `accountcode:passwordhash`.
- r – Supprime la clé de base de données après une authentification réussie (valide uniquement avec `d`).

Si l'appelant échoue aux trois tentatives, le canal est raccroché ; l'exécution du dialplan ne se poursuit pas, gérez donc le chemin d'échec sur la ligne suivant `Authenticate()`. Exemple (appels internationaux) :

```
exten=_9011.,1,Authenticate(/password,d)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

L'ancienne option `j` (sauter à la priorité n+101 en cas d'échec) et la convention de priorité `+101` ont été supprimées d'Asterisk depuis longtemps ; un échec de `Authenticate()` raccroche simplement l'appel.

Pour insérer le mot de passe dans une clé de base de données depuis la console :

```
asterisk*CLI> database put senha 123456 1
```

## Utilisation des mots de passe de la voicemail

Cette application effectue la même opération que authenticate, mais utilise le fichier de configuration de la voicemail pour le mot de passe.

```
VMAuthenticate([mailbox][@context][,options])
```

Si une mailbox est spécifiée, seul le mot de passe de cette mailbox sera considéré comme valide. Si la mailbox n'est pas spécifiée, la variable de canal `${AUTH_MAILBOX}` sera définie avec la mailbox authentifiée. Si l'option `s` est définie, les invites initiales sont ignorées. Exemple (Appels internationaux) :

```
exten=_9011.,1,VMAuthenticate(${CALLERID(num)}@local,s)
 same=>n,Dial(DAHDI/g1/${EXTEN:1},20,tT)
 same=>n,Hangup()
```

## Channel Event Logging (CEL)

Les enregistrements CDR fournissent une ligne de résumé par appel. Pour un suivi d'événements plus détaillé — tel que les transitions d'état de canal individuelles, les événements d'entrée/sortie de pont et les segments de transfert assisté — Asterisk 22 inclut **Channel Event Logging (CEL)**, configuré via `/etc/asterisk/cel.conf` et stocké par le biais de backends tels que `cel_odbc` ou `cel_custom`.

CEL complète le CDR plutôt que de le remplacer : le CDR demeure la norme pour les résumés de facturation, tandis que CEL fournit des données granulaires par événement, utiles pour la détection de fraude, le contrôle qualité et les rapports avancés.

Le modèle de configuration `cel.conf` reflète `cdr.conf` : vous activez les types d'événements souhaités dans la section `[general]` de `cel.conf`, puis vous configurez chaque backend de stockage dans son propre fichier — `cel_custom.conf` pour le CSV, `cel_odbc.conf` pour une base de données ODBC (la même connexion `res_odbc.conf` utilisée pour les CDR). Vous pouvez confirmer si CEL est actif avec `cel show status` sur la CLI.

## Résumé

Dans ce chapitre, nous avons appris à implémenter l'enregistrement des CDR dans des fichiers texte et dans une base de données MySQL. Nous avons également appris à définir les amaflags et les account codes. À la fin du chapitre, nous avons appris à utiliser un mécanisme d'authentification intégré avec les CDR et la facturation.

## Quiz

1. Par défaut, Asterisk enregistre les CDR dans le répertoire /var/log/asterisk/cdr-csv.
   - A. Faux
   - B. Vrai
2. Asterisk peut écrire les CDR vers (sélectionnez toutes les réponses qui s'appliquent) :
   - A. MySQL
   - B. Native Oracle
   - C. Microsoft SQL Server
   - D. Fichiers texte CSV
   - E. Bases de données supportées par unixODBC
3. Asterisk génère un CDR pour un seul type de stockage à la fois.
   - A. Faux
   - B. Vrai
4. Quels amaflags Asterisk sont disponibles ?
   - A. DEFAULT
   - B. OMIT
   - C. TAX
   - D. RATE
   - E. BILLING
   - F. DOCUMENTATION
5. Pour associer un département à un CDR, vous utilisez la commande ___, et le code de compte peut être lu avec la variable de canal ___.
6. La différence entre `Set(CDR_PROP(disable)=1)` et `ResetCDR()` est que la désactivation du CDR empêche l'écriture de tout enregistrement, tandis que `ResetCDR()` réinitialise (remet à zéro) l'enregistrement actuel. (L'application `NoCDR()` qui désactivait précédemment les CDR a été supprimée dans Asterisk 21.)
   - A. Faux
   - B. Vrai
7. Pour utiliser un champ défini par l'utilisateur avec le module `cdr_csv.so`, vous devez modifier le code source et recompiler Asterisk.
   - A. Faux
   - B. Vrai
8. Les trois méthodes d'authentification disponibles pour l'application Authenticate() sont :
   - A. Mot de passe
   - B. Fichier de mots de passe
   - C. Asterisk DB (dbput et dbget)
   - D. Voicemail
9. Les mots de passe de voicemail sont spécifiés dans une section séparée de `voicemail.conf` et ne sont pas les mêmes que ceux des utilisateurs de voicemail.
   - A. Faux
   - B. Vrai
10. Le Channel Event Logging (CEL) remplace le CDR dans Asterisk 22 — une fois le CEL activé, les résumés de facturation CDR ne sont plus produits.
    - A. Faux
    - B. Vrai

**Réponses :** 1 — B · 2 — A, B, C, D, E · 3 — A · 4 — A, B, E, F · 5 — `Set(CDR(accountcode)=...)`; `${CDR(accountcode)}` · 6 — B · 7 — A · 8 — A, B, C · 9 — B · 10 — A
