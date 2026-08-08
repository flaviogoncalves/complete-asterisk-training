# WebRTC avec Asterisk

WebRTC (Web Real-Time Communication) permet à un navigateur web d'émettre et de recevoir des appels sans plugin ni softphone externe — simplement avec JavaScript, un microphone et une connexion sécurisée vers Asterisk. Asterisk est capable d'agir en tant que serveur WebRTC depuis Asterisk 11, et depuis l'arrivée de la pile PJSIP (`res_pjsip`) dans Asterisk 12, il s'agit de la méthode recommandée pour le faire ; dans Asterisk 22, la configuration s'est stabilisée autour d'un petit nombre d'options bien comprises. Ce chapitre montre comment transformer un endpoint PJSIP en téléphone par navigateur, comment fonctionne le chemin média sécurisé, et quand vous devriez opter pour le support WebRTC intégré d'Asterisk plutôt que pour une passerelle dédiée.

Tout ce qui est présenté dans ce chapitre a été vérifié avec le laboratoire Asterisk 22 du livre ; la configuration montrée est la même que celle dans `lab/asterisk/etc`.

## Objectifs

À la fin de ce chapitre, vous devriez être capable de :

- Expliquer ce que WebRTC apporte à Asterisk et quand l'utiliser
- Décrire en quoi la sécurité des médias WebRTC (DTLS-SRTP) et ICE diffèrent du SIP standard
- Activer le serveur HTTP Asterisk et le point de terminaison WebSocket sécurisé (`wss`)
- Configurer un transport PJSIP `wss` et un endpoint WebRTC avec `webrtc=yes`
- Connecter un softphone dans un navigateur (SIP.js) et passer un appel
- Choisir entre le WebRTC natif d'Asterisk et une passerelle multimédia telle que Janus

## Pourquoi WebRTC avec Asterisk

Un endpoint WebRTC est, du point de vue d'Asterisk, simplement un autre endpoint PJSIP. Ce qui change, c'est la *manière* dont le navigateur l'atteint et dont les médias sont sécurisés. Les utilisations typiques incluent :

- **Click-to-call** sur un site web — un visiteur appelle une file d'attente ou une extension depuis une page web.
- **Agents basés sur le web** — un agent de centre de contact travaille entièrement dans le navigateur, sans softphone de bureau à installer ou à mettre à jour.
- **Appels intégrés** dans votre propre application web — par exemple, le softphone web SipPulse communiquant avec Asterisk.
- **Téléphones internes sans installation** — le personnel utilise un onglet de navigateur au lieu d'un téléphone matériel ou d'un client installé.

Le grand avantage est la portée : chaque navigateur moderne gère déjà WebRTC. Le coût est que WebRTC est strict — il *exige* des médias chiffrés et un transport sécurisé, il y a donc plus de choses à configurer qu'avec un téléphone SIP UDP classique.

## Différences entre WebRTC et le SIP classique

Un téléphone SIP standard communique via UDP/TCP et transporte généralement l'audio sous forme de RTP brut. Un client navigateur WebRTC se distingue par trois aspects importants, auxquels Asterisk doit s'adapter :

- **La signalisation transite par un WebSocket.** Au lieu du SIP sur le port UDP 5060, le navigateur ouvre un WebSocket sécurisé (`wss://`) vers le serveur HTTP intégré d'Asterisk. Les messages SIP circulent à l'intérieur de ce WebSocket.
- **Les médias sont toujours chiffrés avec DTLS-SRTP.** Les navigateurs refusent le RTP brut. Les deux parties effectuent une poignée de main DTLS (authentifiée par des empreintes de certificat échangées dans le SDP) et en dérivent des clés SRTP.
- **La connectivité est négociée avec ICE.** Plutôt que de supposer une adresse IP et un port accessibles, les deux parties collectent des adresses candidates (hôte, STUN-reflexive, TURN-relayed) et les testent jusqu'à ce qu'une connexion fonctionne. Le RTP et le RTCP sont généralement multiplexés sur un port unique (`rtcp_mux`).

La bonne nouvelle : dans Asterisk 22, une option d'endpoint unique, `webrtc=yes`, active tout cela avec des paramètres par défaut judicieux. Nous verrons exactement ce qu'elle configure.

## Étape 1 — le serveur HTTP et le WebSocket

La signalisation WebRTC est assurée par le serveur HTTP intégré d'Asterisk (`res_http_websocket` expose le chemin `/ws` sur celui-ci). Les navigateurs nécessitent un WebSocket *sécurisé*, nous activons donc le TLS. Modifiez `http.conf` :

```
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088

; TLS / WSS for WebRTC. Browsers require a secure WebSocket (wss://).
tlsenable=yes
tlsbindaddr=0.0.0.0:8089
tlscertfile=/etc/asterisk/keys/asterisk.crt
tlsprivatekey=/etc/asterisk/keys/asterisk.key
```

Rechargez (`module reload res_http_websocket` ou redémarrez) et confirmez :

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

Le navigateur se connectera à `wss://your-asterisk:8089/ws`.

### À propos du certificat

Le certificat TLS ici sécurise le *WebSocket* (le canal de signalisation). Dans un environnement de laboratoire, un certificat auto-signé suffit — vous l'acceptez une fois dans le navigateur. En production, utilisez un certificat réel (par exemple Let's Encrypt) dont le nom correspond à l'hôte auquel le navigateur se connecte, sinon le navigateur refusera le WebSocket.

Pour le laboratoire, `lab/make-certs.sh` génère un certificat auto-signé avec `CN=localhost` (plus les SAN `localhost`/`127.0.0.1`) et l'écrit dans `asterisk/etc/keys/`. Pour un déploiement public, obtenez plutôt un certificat réel — par exemple avec Let's Encrypt :

```
certbot certonly --standalone -d voip.example.com
```

Ensuite, pointez `http.conf` vers les fichiers émis et rechargez `res_http_websocket` :

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

Assurez-vous que le nom du certificat correspond à l'hôte auquel le navigateur se connecte, et renouvelez-le (le minuteur de certbot le fait automatiquement) avant qu'il n'expire, sinon le WebSocket échouera.

Ce certificat n'est **pas** le même que le certificat DTLS utilisé pour chiffrer les médias — Asterisk génère celui-ci automatiquement, comme nous le verrons.

## Étape 2 — le transport WSS

PJSIP nécessite un transport de type `wss`. Ajoutez-le dans `pjsip.conf` :

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

Vérifiez qu'il est chargé :

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

Ne vous laissez pas induire en erreur par le `0.0.0.0:5060` affiché pour le transport `wss` — le WebSocket n'est **pas** servi sur le port 5060. La signalisation WebRTC est servie par le serveur HTTP que vous avez configuré à l'étape 1 (port 8089 pour `wss`). Le transport PJSIP `wss` est une fine couche au-dessus de `res_http_websocket`, donc l'adresse `bind` affichée pour celui-ci est cosmétique et peut être ignorée ; le port qui compte est `tlsbindaddr` dans `http.conf`.

## Étape 3 — l'endpoint WebRTC

Passons maintenant à l'endpoint lui-même. La clé est `webrtc=yes` :

```
[webrtc-1000]
type=endpoint
context=internal
disallow=all
allow=opus,ulaw
webrtc=yes
transport=transport-wss
aors=webrtc-1000
auth=webrtc-1000

[webrtc-1000]
type=auth
auth_type=digest
username=webrtc-1000
password=Lab-webrtc-secret

[webrtc-1000]
type=aor
max_contacts=1
```

`webrtc=yes` est une option de commodité. Elle équivaut à configurer manuellement toutes les options requises pour le WebRTC. Vous pouvez confirmer exactement ce qu'elle a activé :

```
*CLI> pjsip show endpoint webrtc-1000
 dtls_auto_generate_cert            : Yes
 dtls_fingerprint                   : SHA-256
 dtls_setup                         : actpass
 ice_support                        : true
 media_encryption                   : dtls
 rtcp_mux                           : true
 use_avpf                           : true
 webrtc                             : yes
```

En lisant cette sortie :

- `media_encryption: dtls` et `dtls_auto_generate_cert: Yes` — le média est en DTLS-SRTP, et Asterisk génère automatiquement le certificat DTLS, vous n'avez donc **pas** besoin d'en créer un vous-même. L'empreinte (fingerprint) est annoncée dans le SDP (`SHA-256`).
- `ice_support: true` — Asterisk collecte et négocie les candidats ICE.
- `rtcp_mux: true` — RTP et RTCP partagent un seul port, comme l'attendent les navigateurs.
- `use_avpf: true` — le profil RTP AVPF (feedback), requis par le WebRTC.

`allow=opus` est recommandé — Opus est le codec préféré des navigateurs. Asterisk 22 intègre le *passthrough* Opus dans son noyau (le module `res_format_attr_opus`), ce qui suffit pour relayer Opus entre deux segments compatibles Opus sans réencodage. Le *transcodage* d'Opus vers un autre codec nécessite le module séparé `codec_opus`, que le guide officiel WebRTC présente comme optionnel mais fortement recommandé, et que vous installez en complément de la version de base ; consultez la discussion sur les codecs dans *Designing a VoIP network*. Conservez `ulaw` comme solution de repli pour le pontage vers des segments non-WebRTC qui ne prennent pas en charge Opus.

## Étape 4 — ICE, STUN et TURN

Sur un réseau local (LAN) plat, ICE avec des candidats hôtes suffit et rien d'autre n'est nécessaire. Sur Internet, vous ajoutez généralement un serveur STUN afin qu'Asterisk et le navigateur puissent découvrir leurs adresses publiques, ainsi qu'un serveur TURN pour les cas où le média direct est impossible (NAT symétrique, pare-feu restrictifs). Indiquez-les à Asterisk dans `rtp.conf` :

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

Le navigateur est configuré avec ses propres serveurs ICE en JavaScript (la liste `RTCPeerConnection` `iceServers`). Pour un déploiement purement interne, vous pouvez ignorer complètement STUN/TURN.

`turnaddr` accepte un port optionnel (par défaut `3478`) ; `turnusername` et `turnpassword` s'authentifient auprès du relais. STUN aide seulement un pair à *découvrir* son adresse publique — lorsque les deux extrémités se trouvent derrière un NAT symétrique ou un pare-feu restrictif, le média direct est impossible et un relais TURN est la seule chose qui permet au flux audio de passer.

**Recommandation pour la production :** un serveur STUN public (tel que celui de Google) convient pour la découverte d'adresses, mais ne comptez **pas** sur un serveur TURN public pour le trafic réel — TURN relaie l'intégralité de vos médias, vous devez donc en garder le contrôle. Exécutez votre propre serveur [coturn](https://github.com/coturn/coturn). Un `/etc/turnserver.conf` minimal avec des identifiants à long terme ressemble à ceci :

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

Ensuite, indiquez-le à Asterisk dans `rtp.conf` :

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

Donnez au navigateur le même serveur TURN dans sa liste `iceServers` afin que les deux segments puissent relayer. Pour la production avec des utilisateurs sur des réseaux mobiles ou derrière des pare-feu d'entreprise, un coturn auto-hébergé est pratiquement obligatoire.

## Étape 5 — le client navigateur

N'importe quelle bibliothèque SIP WebRTC fonctionne ; deux des plus utilisées sont **SIP.js** et **JsSIP**. Le laboratoire inclut un softphone SIP.js minimal à `lab/webrtc/index.html`. La partie essentielle concerne l'URL de transport et les identifiants :

```javascript
const ua = new SIP.UserAgent({
  uri: SIP.UserAgent.makeURI('sip:webrtc-1000@your-asterisk'),
  transportOptions: { server: 'wss://your-asterisk:8089/ws' },
  authorizationUsername: 'webrtc-1000',
  authorizationPassword: 'Lab-webrtc-secret',
});
await ua.start();
await new SIP.Registerer(ua).register();
// place a call to the echo test
const inviter = new SIP.Inviter(ua, SIP.UserAgent.makeURI('sip:600@your-asterisk'));
await inviter.invite();
```

Deux réalités du navigateur à garder à l'esprit :

- **Contexte sécurisé.** `getUserMedia` (accès au microphone) ne fonctionne que sur des pages `https://` ou `http://localhost`. Servez la page via HTTPS en production.
- **Acceptez le certificat une fois.** Avec un certificat de laboratoire auto-signé, visitez d'abord `https://your-asterisk:8089/ws` dans le même navigateur et acceptez l'avertissement, sinon le WebSocket échouera silencieusement.

Le softphone web SipPulse est un client de référence de qualité production construit sur ces mêmes primitives.

## Vérification d'un appel WebRTC

Une fois le navigateur enregistré, `pjsip show contacts` affiche le contact dynamique, et un appel active le canal :

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

Si l'audio est unidirectionnel ou absent, il s'agit presque toujours d'un problème lié à ICE ou au certificat — consultez la section de dépannage ci-dessous.

## Asterisk WebRTC vs une passerelle média

Asterisk peut terminer le WebRTC directement, mais ce n'est pas toujours l'outil approprié :

- **Utilisez le WebRTC natif d'Asterisk** lorsque le navigateur est un *téléphone* sur votre PBX — un agent, une extension interne, ou un click-to-call qui aboutit dans votre dialplan. Le navigateur est simplement un autre endpoint et tout fonctionne (files d'attente, voicemail, IVR).
- **Utilisez une passerelle dédiée (par exemple Janus)** lorsque vous devez faire évoluer de nombreuses sessions de navigateur indépendamment du contrôle d'appel, effectuer un transfert sélectif pour de grandes conférences/du streaming, ou maintenir le plan média séparé du PBX. Une passerelle fait le pont entre le WebRTC et le SIP standard, et Asterisk voit alors une branche SIP ordinaire.

De nombreux systèmes réels combinent les deux : Asterisk pour le contrôle d'appel, et une passerelle pour la mise à l'échelle des médias côté navigateur. (C'est l'architecture derrière la propre pile de SipPulse.)

## Dépannage

- **WebSocket ne se connecte pas :** le navigateur a rejeté le certificat TLS. Ouvrez
  `https://host:8089/ws` directement et acceptez-le, ou installez un certificat approuvé.
- **L'enregistrement fonctionne mais il n'y a pas d'audio :** échec de ICE — ajoutez STUN, et TURN si vous traversez un NAT. Vérifiez
  `pjsip set logger on` et examinez les candidats SDP.
- **Audio unidirectionnel :** généralement dû à NAT/ICE d'un côté, ou à un codec sans correspondance commune —
  assurez-vous de `allow=opus,ulaw`.
- **L'appel est coupé au décrochage :** échec de la poignée de main DTLS ; confirmez que `dtls_auto_generate_cert`
  est `Yes` et que l'horloge système est correcte (les certificats sont sensibles au temps).

## Lab

1. Exécutez `./lab.sh up`, puis `bash lab/make-certs.sh` et redémarrez Asterisk.
2. Servez `lab/webrtc/index.html` (`python3 -m http.server` depuis `lab/webrtc`) et ouvrez-le ; acceptez le certificat sur `https://localhost:8089/ws`.
3. Enregistrez-vous en tant que `webrtc-1000` et appelez `600` (test d'écho) — vous devriez vous entendre.
4. Depuis le softphone SipPulse enregistré en tant que `6001`, composez `1000` pour faire sonner le navigateur.
5. Inspectez la négociation : `pjsip set logger on`, passez un appel, et trouvez l'empreinte DTLS et les candidats ICE dans le SDP.

## Résumé

WebRTC transforme un navigateur en un endpoint Asterisk de premier ordre. La recette est courte mais stricte : activez le serveur HTTP avec TLS afin que le navigateur puisse ouvrir un WebSocket sécurisé, ajoutez un transport PJSIP `wss`, et configurez `webrtc=yes` sur l'endpoint — ce qui active DTLS-SRTP (avec un certificat auto-généré), ICE, le multiplexage RTP/RTCP et le profil AVPF. Ajoutez STUN/TURN lors du franchissement de NAT, servez votre page via HTTPS, et pointez un client SIP.js (ou JsSIP) vers `wss://asterisk:8089/ws`. Pour des téléphones par navigateur sur votre PBX, le WebRTC natif d'Asterisk est la voie la plus simple ; pour des médias à grande échelle, couplez-le avec une passerelle.

## Quiz

1. Quel transport un client navigateur WebRTC utilise-t-il pour acheminer la signalisation SIP vers Asterisk ?
   - A. UDP simple sur le port 5060
   - B. Un WebSocket sécurisé (`wss://`) vers le serveur HTTP d'Asterisk
   - C. TLS sur le port 5061
   - D. Un socket TCP brut sur le port 8088

2. Le média WebRTC entre le navigateur et Asterisk est chiffré en utilisant quel mécanisme ?
   - A. SDES-SRTP (clés échangées dans le SDP)
   - B. DTLS-SRTP (clés dérivées d'une poignée de main DTLS)
   - C. IPsec
   - D. RTP simple — WebRTC ne chiffre pas les médias

3. Vrai ou faux : lorsque vous configurez `webrtc=yes`, vous devez générer et installer manuellement le certificat DTLS utilisé pour chiffrer le média.

4. Sur quel port le serveur HTTP Asterisk du laboratoire expose-t-il le WebSocket **sécurisé** pour WebRTC ?
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. Laquelle des options suivantes est activée par défaut par `webrtc=yes` ? (Choisissez toutes les réponses qui s'appliquent.)
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. Complétez la phrase : WebRTC négocie la connectivité en demandant aux deux parties de collecter et de sonder des adresses candidates (hôte, STUN-reflexive, TURN-relayed) en utilisant le framework ________.

7. Dans `rtp.conf`, quels sont les deux paramètres qui indiquent à Asterisk un serveur externe afin qu'il puisse découvrir son adresse publique et relayer les médias lorsque les chemins directs échouent ? (Choisissez toutes les réponses qui s'appliquent.)
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. Le chemin d'URL que le `res_http_websocket` d'Asterisk expose pour la signalisation WebRTC est ________.

9. Selon le chapitre, quand devriez-vous opter pour une passerelle média dédiée (telle que Janus) plutôt que pour le WebRTC natif d'Asterisk ?
   - A. Chaque fois qu'un navigateur doit passer un appel
   - B. Lorsque vous devez mettre à l'échelle de nombreuses sessions média de navigateur indépendamment du contrôle d'appel, effectuer un transfert sélectif pour de grandes conférences, ou séparer le plan média du PBX
   - C. Uniquement lorsque le navigateur ne prend pas en charge DTLS
   - D. Lorsque vous souhaitez que la voicemail et l'IVR fonctionnent pour l'endpoint navigateur

10. Vrai ou faux : `getUserMedia` (accès au microphone) fonctionne sur n'importe quelle page `http://`, donc servir le softphone via le navigateur en HTTPS est optionnel.

**Réponses :** 1 — B · 2 — B · 3 — Faux (Asterisk génère automatiquement le certificat DTLS ; `dtls_auto_generate_cert: Yes`) · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — Faux (contexte sécurisé requis : `getUserMedia` ne fonctionne que sur `https://` ou `http://localhost`)
