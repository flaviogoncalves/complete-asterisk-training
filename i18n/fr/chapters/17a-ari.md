# L'interface REST d'Asterisk (ARI)

Le chapitre précédent a couvert AMI et AGI, les deux méthodes classiques pour greffer une logique externe sur Asterisk. Toutes deux sont antérieures au web moderne : AMI vous fournit un flux d'événements brut et orienté ligne via un socket TCP, et AGI confie un canal unique à un script pour la durée d'un appel. Aucune des deux n'a été conçue pour le type d'applications avec état, asynchrones et multi-canaux que les gens développent aujourd'hui — des IVR qui communiquent avec des services web, des tableaux de bord click-to-call, des contrôleurs de conférence ou des voicebots qui diffusent de l'audio vers un moteur de reconnaissance vocale.

ARI — l'interface REST d'Asterisk — a été introduite dans Asterisk 12 pour combler cette lacune, et dans Asterisk 22, c'est l'interface recommandée pour construire de nouvelles applications de téléphonie. L'idée derrière ARI est une séparation claire des préoccupations : **Asterisk devient un moteur multimédia** (il répond aux canaux, mixe les bridges, joue et enregistre de l'audio, envoie des DTMF), et **votre application fournit toute la logique de contrôle d'appel** via une combinaison d'une API REST (HTTP) et d'un flux d'événements WebSocket.

## Objectifs

À la fin de ce chapitre, le lecteur devrait être capable de :

- Expliquer ce qu'est ARI et en quoi il diffère de AMI et AGI
- Décider quand ARI est l'interface appropriée pour un projet
- Configurer `ari.conf` et `http.conf` pour activer ARI et créer un utilisateur
- Se connecter au flux d'événements WebSocket de ARI
- Décrire l'application de dialplan Stasis et les événements `StasisStart`/`StasisEnd`
- Décrire le modèle de ressources ARI : channels, bridges, playbacks, recordings, endpoints et device states
- Écrire une application Stasis minimale en Python qui répond à un channel, joue un son et raccroche
- Expliquer ce qu'est le channel `externalMedia` et pourquoi il est important pour les intégrations d'IA et de voicebot

## Qu'est-ce que ARI et quand l'utiliser

ARI repose sur deux transports fonctionnant de concert :

- **Une API REST (HTTP)** que votre application appelle pour *effectuer* des actions : créer un canal, y répondre, diffuser un son, créer un pont, lancer un enregistrement, raccrocher. Il s'agit de requêtes HTTP ordinaires (`GET`, `POST`, `DELETE`) vers `http://asterisk-host:8088/ari/...`.
- **Un flux d'événements WebSocket** via lequel Asterisk *informe* votre application de ce qui se passe : un canal a été créé, un chiffre DTMF est arrivé, une lecture est terminée, un canal a quitté votre application. Les événements sont transmis sous forme d'objets JSON.

Le modèle est asynchrone : vous effectuez une requête, et le *résultat* de cette requête revient généralement plus tard sous forme d'événement. Par exemple, vous envoyez une requête `POST` pour diffuser un son ; Asterisk répond immédiatement avec un objet `Playback`, et quelques secondes plus tard, vous recevez un événement `PlaybackFinished` lorsque l'audio est terminé.

Choisissez ARI plutôt que AMI ou AGI lorsque :

- Vous avez besoin d'un **contrôle précis des canaux et des ponts** : pour créer des conférences, des parcs d'appels, des files d'attente ou des flux d'appels personnalisés à partir de primitives, au lieu de dépendre des applications du dialplan.
- Votre application est **à état et persistante**, gérant plusieurs canaux simultanément et réagissant aux événements sur l'ensemble de ceux-ci.
- Vous souhaitez intégrer des **services web, des bus de messages ou des moteurs d'IA/reconnaissance vocale** et préférez JSON sur HTTP à un protocole ligne par ligne ou à un script stdin/stdout.
- Vous démarrez un **nouveau projet** et souhaitez utiliser l'interface activement recommandée par le projet Asterisk.

AMI reste l'outil approprié lorsque vous avez seulement besoin d'*observer* le système ou d'envoyer des commandes occasionnelles (numéroteurs, tableaux de bord, surveillance). AGI reste pratique pour un script IVR rapide et autonome. Mais pour tout ce qui nécessite d'orchestrer des appels, ARI est la réponse moderne.

> ARI ne remplace pas le dialplan, il le complète. Un canal s'exécute dans le dialplan comme d'habitude jusqu'à ce qu'il atteigne l'application `Stasis()`, moment auquel le contrôle est transféré à votre application ARI. Lorsque votre application a terminé, le canal peut être renvoyé dans le dialplan ou raccroché.

## Activation de l'ARI : http.conf et ari.conf

L'ARI repose sur le serveur HTTP intégré d'Asterisk, deux fichiers de configuration sont donc impliqués : `http.conf` active le serveur web, et `ari.conf` active l'ARI et définit ses utilisateurs.

### http.conf

Le serveur HTTP doit être activé et lié à une adresse et un port. Le port conventionnel de l'ARI est le **8088**.

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
```

Pour la production, vous devriez placer l'ARI derrière TLS. Asterisk peut servir HTTPS directement (`tlsenable=yes`, `tlsbindaddr`, `tlscertfile`, `tlsprivatekey`), ou vous pouvez terminer TLS dans un reverse proxy devant le port 8088. Via TLS, les URL deviennent `https://` et `wss://` au lieu de `http://` et `ws://`.

Vous pouvez confirmer que le serveur HTTP est actif depuis la CLI :

```
asterisk*CLI> http show status
HTTP Server Status:
Server Enabled and Bound to 0.0.0.0:8088
```

### ari.conf

`ari.conf` possède une section `[general]` et une section par utilisateur.

```ini
[general]
enabled=yes
pretty=yes              ; pretty-print JSON responses (handy while learning)

[asterisk]
type=user
read_only=no            ; set to yes for a user that may only issue GET requests
password=secret
password_format=plain   ; "plain" (default) or "crypt"
```

Quelques remarques sur ces options :

- `enabled` active ou désactive l'ARI globalement.
- `pretty` formate les réponses JSON pour qu'elles soient lisibles par un humain ; désactivez-le en production.
- Chaque utilisateur est une section nommée avec `type=user`.
- `read_only=yes` restreint cet utilisateur aux requêtes en lecture seule (GET).
- `password_format` peut être `plain` (le mot de passe est en clair) ou `crypt` (un mot de passe haché, généré avec `mkpasswd -m sha-512`).
- `permit`, `deny` et `acl` permettent des restrictions IP par utilisateur, en suivant les mêmes règles que `acl.conf`.

Après avoir modifié les fichiers, rechargez les modules concernés (`module reload res_ari.so` et `module reload http.so`) ou redémarrez Asterisk. Vous pouvez vérifier que l'ARI est en cours d'exécution avec :

```
asterisk*CLI> module show like res_ari
res_ari.so          Asterisk RESTful Interface          Running
res_ari_channels.so RESTful API module - Channel res... Running
res_ari_bridges.so  RESTful API module - Bridge reso... Running
...

asterisk*CLI> ari show apps
Application Name
=========================
```

`ari show apps` liste les applications Stasis actuellement enregistrées par les clients connectés. Elle est vide jusqu'à ce qu'un client se connecte, ce que nous ferons ensuite.

### L'URL des événements WebSocket

Un client s'abonne au flux d'événements en ouvrant un WebSocket vers le point de terminaison `/ari/events`, en nommant l'application Stasis qu'il implémente et en transmettant ses identifiants :

```
ws://asterisk-host:8088/ari/events?app=hello&api_key=asterisk:secret
```

Les paramètres de requête sont :

- `app` — le nom de votre application Stasis. C'est le même nom que vous utiliserez dans l'appel `Stasis()` du dialplan. Vous pouvez passer plusieurs noms séparés par des virgules.
- `api_key` — les identifiants, sous la forme `username:password`, correspondant à un utilisateur dans `ari.conf`.
- `subscribeAll` — booléen optionnel (par défaut `false`) ; lorsque `true`, l'application reçoit tous les événements, et pas seulement ceux concernant les ressources qu'elle possède.

Les mêmes identifiants `user:pass` sont utilisés comme authentification HTTP Basic sur les appels REST (ou ajoutés en tant que paramètre de requête `api_key` à cet endroit également).

## Stasis : confier un canal à votre application

Le pont entre le dialplan et ARI est l'application de dialplan **`Stasis()`** (le framework sous-jacent est également appelé Stasis). Lorsqu'un canal atteint `Stasis(appname[,args])`, Asterisk confie ce canal à l'application ARI enregistrée sous `appname` et cesse d'exécuter le dialplan pour celui-ci. Le contrôle appartient désormais à votre code.

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

Lorsque le canal entre dans l'application, chaque client connecté abonné à `hello` reçoit un événement **`StasisStart`** via le WebSocket, contenant l'objet canal complet (son ID, son nom, son caller ID, son état et tous les arguments transmis à `Stasis()`). C'est le signal pour commencer à contrôler le canal.

Lorsque le canal quitte l'application — parce que votre code l'a renvoyé vers le dialplan avec `continueInDialplan`, ou parce qu'il a été raccroché — vous recevez un événement **`StasisEnd`**. Une fois que `Stasis()` retourne au dialplan, il définit la variable de canal `STASISSTATUS` (`SUCCESS` ou `FAILED`), afin que le dialplan puisse effectuer une bifurcation selon le résultat.

## Le modèle de ressources ARI

ARI expose les composants internes d'Asterisk sous la forme d'un petit ensemble de ressources REST. Chaque ressource se trouve sous `/ari/<resource>` et est manipulée à l'aide des méthodes HTTP standard. Les plus importantes sont :

| Ressource | Ce qu'elle représente | Opérations d'exemple |
|----------|--------------------|--------------------|
| **channels** | Un segment d'appel unique | originate, answer, play, record, hangup |
| **bridges** | Un point de mixage qui relie les channels | create, add/remove channels, play to the bridge |
| **playbacks** | Une lecture multimédia en cours | get status, stop, pause/unpause |
| **recordings** | Enregistrements en direct et stockés | start, stop, list stored, delete |
| **endpoints** | Pairs configurés (PJSIP, etc.) | list, get state, send a message |
| **deviceStates** | États de périphérique personnalisés | list, get, set, delete |

Quelques appels REST concrets (chemins affichés avec le préfixe `/ari` qui apparaît sur le réseau) :

```
# Channels
POST   /ari/channels                          # originate a new channel
POST   /ari/channels/{channelId}/answer       # answer an incoming channel
POST   /ari/channels/{channelId}/play         # play media (body: media=sound:hello-world)
POST   /ari/channels/{channelId}/record       # record the channel
DELETE /ari/channels/{channelId}              # hang up the channel

# Bridges
POST   /ari/bridges                           # create a bridge (e.g. type=mixing)
POST   /ari/bridges/{bridgeId}/addChannel     # add a channel (param: channel=<id>)
POST   /ari/bridges/{bridgeId}/play           # play media to everyone in the bridge
DELETE /ari/bridges/{bridgeId}                # destroy the bridge

# Read-only resources
GET    /ari/endpoints
GET    /ari/deviceStates
GET    /ari/recordings/stored
GET    /ari/playbacks/{playbackId}
```

Le paramètre `media` sur une requête `play` prend un URI multimédia. La forme la plus courante est un URI `sound:` désignant un son intégré, par exemple `sound:hello-world` ou `sound:tt-monkeys`. Lorsque l'audio se termine, Asterisk émet un événement `PlaybackFinished` pour cet ID de lecture, ce qui permet à votre application de savoir qu'elle peut passer à l'étape suivante.

Les channels et les bridges sont les deux blocs de construction que vous combinez pour créer des flux d'appels. Pour connecter deux appelants, par exemple, vous créez ou acceptez deux channels, créez un bridge `mixing` avec `POST /ari/bridges`, et y ajoutez les deux channels avec `POST /ari/bridges/{bridgeId}/addChannel`. Pour créer une conférence, il vous suffit de continuer à ajouter des channels au même bridge.

## Un exemple pratique : une application Stasis minimale

Construisons la plus petite application ARI utile. Lorsqu'une extension est composée, l'appel entre dans notre application Stasis, qui y répond, joue le message classique `hello-world` et raccroche.

### Le dialplan

Dans `extensions.conf`, envoyez le canal vers Stasis :

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

Le nom de l'application `hello` correspond au `app=hello` que nous utilisons lors de la connexion.

### Le client Python

Ce client utilise deux bibliothèques bien connues : `requests` pour les appels REST et `websocket-client` pour le flux d'événements. Installez-les avec `pip install requests websocket-client`.

```python
#!/usr/bin/env python3
"""Minimal ARI Stasis app: answer, play hello-world, hang up."""
import json
import requests
from websocket import create_connection

ARI_HOST = "127.0.0.1"
ARI_PORT = 8088
ARI_USER = "asterisk"
ARI_PASS = "secret"
APP = "hello"

BASE = f"http://{ARI_HOST}:{ARI_PORT}/ari"
AUTH = (ARI_USER, ARI_PASS)

def answer(channel_id):
    requests.post(f"{BASE}/channels/{channel_id}/answer", auth=AUTH)

def play(channel_id, media):
    # Returns the Playback object; we could track its id to await PlaybackFinished.
    r = requests.post(
        f"{BASE}/channels/{channel_id}/play",
        params={"media": media},
        auth=AUTH,
    )
    return r.json()

def hangup(channel_id):
    requests.delete(f"{BASE}/channels/{channel_id}", auth=AUTH)

def main():
    ws_url = (
        f"ws://{ARI_HOST}:{ARI_PORT}/ari/events"
        f"?app={APP}&api_key={ARI_USER}:{ARI_PASS}"
    )
    ws = create_connection(ws_url)
    print(f"Connected to ARI, waiting for calls into Stasis app '{APP}'...")

    # Track which channel each playback belongs to, so we hang up when it ends.
    playback_owner = {}

    while True:
        event = json.loads(ws.recv())
        kind = event["type"]

        if kind == "StasisStart":
            channel_id = event["channel"]["id"]
            print(f"StasisStart on channel {channel_id}")
            answer(channel_id)
            pb = play(channel_id, "sound:hello-world")
            playback_owner[pb["id"]] = channel_id

        elif kind == "PlaybackFinished":
            pb_id = event["playback"]["id"]
            channel_id = playback_owner.pop(pb_id, None)
            if channel_id:
                print(f"Playback done, hanging up {channel_id}")
                hangup(channel_id)

        elif kind == "StasisEnd":
            print(f"StasisEnd on channel {event['channel']['id']}")

if __name__ == "__main__":
    main()
```

Exécutez le script, puis composez n'importe quel numéro depuis un endpoint enregistré. Vous devriez entendre "Hello, world", après quoi l'appel est libéré. Sur la console Asterisk, `ari show apps` affichera désormais `hello` tant que le client est connecté.

Le flux mérite d'être suivi une fois :

1. Le dialplan exécute `Stasis(hello)` ; Asterisk transmet le canal à notre application et envoie un événement `StasisStart`.
2. Nous répondons au canal, puis demandons à Asterisk de jouer `sound:hello-world`. Asterisk renvoie un objet `Playback` dont nous mémorisons le `id`.
3. Lorsque l'audio se termine, Asterisk envoie `PlaybackFinished` avec cet identifiant de lecture `id` ; nous recherchons le canal et le raccrochons.
4. Le raccrochage provoque la sortie du canal de Stasis, produisant un événement `StasisEnd`.

> **Une note sur les bibliothèques clientes.** Un wrapper de plus haut niveau appelé `ari-py` (le paquet `ari`) existe, mais il n'est plus maintenu et a été écrit pour une ère plus ancienne de Python et des outils Swagger. Pour tout nouveau travail sur Asterisk 22, préférez l'approche explicite `requests` + WebSocket présentée ci-dessus, ou une bibliothèque asyncio telle que `asyncari` si vous avez besoin de concurrence. L'approche brute vous permet de rester proche des appels REST et des événements réels, ce qui est exactement ce que vous voulez lors de l'apprentissage de l'ARI.

## externalMedia : la porte ouverte à l'IA et aux voicebots

Les ressources ci-dessus vous permettent de lire et d'enregistrer des *fichiers*. Mais les applications vocales modernes — transcription parole-texte, voicebots basés sur l'IA, analyse en temps réel — nécessitent que le *flux audio en direct* d'un appel soit transmis à un processus externe, et qu'il soit possible d'y réinjecter de l'audio.

ARI fournit cette fonctionnalité via le **`externalMedia` channel**. Une requête `POST /ari/channels/externalMedia` crée un canal spécial qui, au lieu de communiquer avec un téléphone, diffuse le flux média RTP de l'appel vers (et depuis) un hôte externe. Vous créez un pont entre ce canal et celui de l'appelant, et votre programme externe se retrouve alors sur le chemin audio : il reçoit l'audio de l'appelant sous forme de RTP et peut renvoyer de l'audio synthétisé.

La requête nécessite uniquement :

- `app` — l'application Stasis qui possède le nouveau canal.
- `format` — le format audio, par exemple `ulaw` ou `slin16`.

`external_host` (le `host:port` de votre application média) est optionnel dans le schéma — il peut être vide pour une connexion de type serveur WebSocket — mais pour un voicebot RTP classique, vous devrez le fournir. Le paramètre `encapsulation` est défini par défaut sur `rtp` et `transport` sur `udp`, ce qui est exactement ce dont vous avez besoin pour un endpoint de streaming média.

```
POST /ari/channels/externalMedia
    app=hello
    external_host=127.0.0.1:9000
    format=slin16
```

Cette fonctionnalité unique est ce qui transforme Asterisk en une interface pour l'IA : le réseau téléphonique se termine sur Asterisk, ARI orchestre l'appel, et `externalMedia` achemine l'audio vers un moteur de reconnaissance vocale/IA et le renvoie. C'est le mécanisme sur lequel reposent les services d'IA et les voicebots.

## Résumé

ARI est l'interface moderne recommandée pour créer des applications de téléphonie sur Asterisk 22. Elle sépare clairement les tâches : Asterisk fait office de moteur média, et votre application — communiquant en JSON via HTTP et un WebSocket — fournit la logique de contrôle des appels. Vous l'activez via `http.conf` (le serveur web intégré sur le port 8088) et `ari.conf` (qui active ARI et définit les utilisateurs).

L'application de dialplan `Stasis()` transmet un canal à votre application, déclenchant `StasisStart` lorsqu'il y entre et `StasisEnd` lorsqu'il en sort. À partir de là, vous manipulez un petit ensemble de ressources REST — channels, bridges, playbacks, recordings, endpoints et device states — pour répondre, diffuser, enregistrer, ponter et raccrocher.

Nous avons construit une application Stasis minimale en Python qui répond à un appel, diffuse un message, puis raccroche, et nous avons vu comment le canal `externalMedia` diffuse du RTP en direct vers un programme externe — la base pour les intégrations d'IA et de voicebot.

## Quiz

1. Dans quelle version d'Asterisk ARI a-t-il été introduit ?
   - A. Asterisk 1.4
   - B. Asterisk 11
   - C. Asterisk 12
   - D. Asterisk 18
2. Dans le modèle ARI, Asterisk agit comme un moteur média tandis que votre application externe fournit la logique de contrôle d'appel.
   - A. Vrai
   - B. Faux
3. ARI utilise deux transports conjointement. Quelle paire est correcte ?
   - A. Une API REST/HTTP pour envoyer des commandes et un flux WebSocket pour recevoir des événements
   - B. Un protocole de ligne TCP et un script stdin/stdout
   - C. SNMP et SMTP
   - D. Deux sockets UDP séparés
4. Quels sont les deux fichiers de configuration qui doivent être configurés pour activer ARI ?
   - A. `manager.conf` et `agi.conf`
   - B. `http.conf` et `ari.conf`
   - C. `sip.conf` et `rtp.conf`
   - D. `modules.conf` et `cdr.conf`
5. Le port TCP conventionnel pour le serveur HTTP Asterisk (et donc ARI) est ____.
6. Quelle application de dialplan transfère un canal à une application ARI ?
   - A. `AGI()`
   - B. `Dial()`
   - C. `Stasis()`
   - D. `System()`
7. Lorsqu'un canal entre dans une application Stasis, quel événement est envoyé au client connecté ?
   - A. `ChannelDestroyed`
   - B. `StasisStart`
   - C. `Newchannel`
   - D. `Hangup`
8. Quelle requête ARI crée un point de mixage capable de joindre deux canaux ou plus ensemble ?
   - A. `POST /ari/channels`
   - B. `POST /ari/bridges`
   - C. `GET /ari/endpoints`
   - D. `DELETE /ari/recordings/stored`
9. Pour lire une invite intégrée sur un canal, quel événement indique à votre application que l'audio est terminé afin qu'elle puisse continuer ?
   - A. `PlaybackStarted`
   - B. `DTMFReceived`
   - C. `PlaybackFinished`
   - D. `ChannelTalkingFinished`
10. Le canal `externalMedia` est principalement utilisé pour :
    - A. Enregistrer un appel dans un fichier WAV local
    - B. Diffuser l'audio en direct de l'appel (RTP) vers et depuis une application externe, par exemple un moteur d'IA/reconnaissance vocale
    - C. Enregistrer un endpoint PJSIP
    - D. Recharger le dialplan

**Réponses :** 1 — C · 2 — A · 3 — A · 4 — B · 5 — `8088` · 6 — C · 7 — B · 8 — B · 9 — C · 10 — B
