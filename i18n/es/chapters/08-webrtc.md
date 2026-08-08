# WebRTC con Asterisk

WebRTC (Web Real-Time Communication) permite que un navegador web realice y reciba llamadas sin necesidad de complementos ni de un softphone externo; solo se requiere JavaScript, un micrófono y una conexión segura a Asterisk. Asterisk ha sido capaz de actuar como un servidor WebRTC desde Asterisk 11, y desde que la pila PJSIP (`res_pjsip`) llegó en Asterisk 12, ha sido la forma recomendada de hacerlo; en Asterisk 22, la configuración se ha consolidado en un puñado de opciones bien comprendidas. Este capítulo muestra cómo convertir un endpoint PJSIP en un teléfono de navegador, cómo funciona la ruta de medios segura y cuándo debería optar por el soporte WebRTC integrado de Asterisk frente a una pasarela dedicada.

Todo lo expuesto en este capítulo ha sido verificado con el laboratorio de Asterisk 22 del libro; la configuración mostrada es la misma que se encuentra en `lab/asterisk/etc`.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Explicar qué añade WebRTC a Asterisk y cuándo utilizarlo
- Describir cómo la seguridad de medios en WebRTC (DTLS-SRTP) e ICE difieren del SIP convencional
- Habilitar el servidor HTTP de Asterisk y el endpoint de WebSocket seguro (`wss`)
- Configurar un transporte PJSIP `wss` y un endpoint WebRTC con `webrtc=yes`
- Conectar un softphone de navegador (SIP.js) y realizar una llamada
- Decidir entre el WebRTC nativo de Asterisk y una pasarela de medios como Janus

## Por qué WebRTC con Asterisk

Un endpoint WebRTC es, desde el punto de vista de Asterisk, simplemente otro endpoint PJSIP. Lo que cambia es *cómo* el navegador llega a él y cómo se asegura el tráfico de medios. Los usos típicos incluyen:

- **Click-to-call** en un sitio web: un visitante llama a una cola o a una extension desde una página web.
- **Agentes basados en web**: un agente de contact-center trabaja completamente en el navegador, sin necesidad de instalar o actualizar un softphone de escritorio.
- **Llamadas integradas** en su propia aplicación web: por ejemplo, el softphone web SipPulse hablando con Asterisk.
- **Teléfonos internos sin instalación**: el personal utiliza una pestaña del navegador en lugar de un teléfono físico o un cliente instalado.

La gran ventaja es el alcance: todos los navegadores modernos ya hablan WebRTC. El costo es que WebRTC es estricto: *requiere* medios cifrados y un transporte seguro, por lo que hay más que configurar que en un teléfono SIP UDP convencional.

## Cómo difiere WebRTC del SIP convencional

Un teléfono SIP convencional señaliza a través de UDP/TCP y generalmente transporta audio como RTP sin cifrar. Un cliente de navegador WebRTC es diferente en tres aspectos importantes, y Asterisk debe adaptarse a cada uno de ellos:

- **La señalización viaja sobre un WebSocket.** En lugar de SIP sobre el puerto UDP 5060, el navegador abre un WebSocket seguro (`wss://`) hacia el servidor HTTP integrado de Asterisk. Los mensajes SIP viajan dentro de ese WebSocket.
- **Los medios siempre se cifran con DTLS-SRTP.** Los navegadores rechazan el RTP sin cifrar. Ambas partes realizan un handshake DTLS (autenticado mediante huellas digitales de certificados intercambiadas en el SDP) y derivan claves SRTP a partir de él.
- **La conectividad se negocia con ICE.** En lugar de asumir una IP y un puerto alcanzables, ambas partes recopilan direcciones candidatas (host, STUN-reflexive, TURN-relayed) y las prueban hasta que una funciona. RTP y RTCP generalmente se multiplexan en un solo puerto (`rtcp_mux`).

La buena noticia: en Asterisk 22, una única opción de endpoint, `webrtc=yes`, activa todo esto con valores predeterminados razonables. Veremos exactamente qué es lo que configura.

## Paso 1 — el servidor HTTP y el WebSocket

La señalización de WebRTC es servida por el servidor HTTP integrado de Asterisk (`res_http_websocket` expone la ruta `/ws` en él). Los navegadores requieren un WebSocket *seguro*, por lo que habilitamos TLS. Edite `http.conf`:

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

Recargue (`module reload res_http_websocket` o reinicie) y confirme:

```
*CLI> http show status
HTTP Server Status:
Server: Asterisk/22.10.0
Server Enabled and Bound to 0.0.0.0:8088

HTTPS Server Enabled and Bound to 0.0.0.0:8089

Enabled URI's:
/ws => Asterisk HTTP WebSocket
```

El navegador se conectará a `wss://your-asterisk:8089/ws`.

### Acerca del certificado

El certificado TLS aquí asegura el *WebSocket* (el canal de señalización). En un laboratorio, un certificado autofirmado es suficiente; usted lo acepta una vez en el navegador. En producción, utilice un certificado real (por ejemplo, Let's Encrypt) cuyo nombre coincida con el host al que se conecta el navegador; de lo contrario, el navegador rechazará el WebSocket.

Para el laboratorio, `lab/make-certs.sh` genera un certificado autofirmado con `CN=localhost` (más los SAN `localhost`/`127.0.0.1`) y lo escribe en `asterisk/etc/keys/`. Para un despliegue público, obtenga un certificado real en su lugar; por ejemplo, con Let's Encrypt:

```
certbot certonly --standalone -d voip.example.com
```

Luego apunte `http.conf` a los archivos emitidos y recargue `res_http_websocket`:

```
tlscertfile=/etc/letsencrypt/live/voip.example.com/fullchain.pem
tlsprivatekey=/etc/letsencrypt/live/voip.example.com/privkey.pem
```

Asegúrese de que el nombre del certificado coincida con el host al que se conecta el navegador y renuévelo (el temporizador de certbot hace esto automáticamente) antes de que caduque, o el WebSocket fallará.

Este certificado **no** es el mismo que el certificado DTLS utilizado para cifrar los medios; Asterisk genera ese automáticamente, como veremos.

## Paso 2 — el transporte WSS

PJSIP necesita un transporte de tipo `wss`. Agréguelo a `pjsip.conf`:

```
[transport-wss]
type=transport
protocol=wss
bind=0.0.0.0
```

Verifique que se haya cargado:

```
*CLI> pjsip show transports
Transport:  transport-udp             udp      0      0  0.0.0.0:5060
Transport:  transport-wss             wss      0      0  0.0.0.0:5060
```

No se deje engañar por el `0.0.0.0:5060` que se muestra para el transporte `wss`; el WebSocket **no** se sirve en el puerto 5060. La señalización de WebRTC es servida por el servidor HTTP que configuró en el Paso 1 (puerto 8089 para `wss`). El transporte PJSIP `wss` es una capa delgada sobre `res_http_websocket`, por lo que la dirección `bind` impresa para este es cosmética y puede ignorarse; el puerto que importa es `tlsbindaddr` en `http.conf`.

## Paso 3 — el endpoint WebRTC

Ahora el endpoint en sí. La clave es `webrtc=yes`:

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

`webrtc=yes` es un interruptor de conveniencia. Es equivalente a configurar manualmente todas las opciones requeridas por WebRTC. Puede confirmar exactamente qué activó:

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

Al leer esa salida:

- `media_encryption: dtls` y `dtls_auto_generate_cert: Yes` — el medio es DTLS-SRTP, y Asterisk autogenera el certificado DTLS, por lo que **no** necesita crear uno usted mismo. La huella digital (fingerprint) se anuncia en el SDP (`SHA-256`).
- `ice_support: true` — Asterisk recopila y negocia los candidatos ICE.
- `rtcp_mux: true` — RTP y RTCP comparten un mismo puerto, tal como esperan los navegadores.
- `use_avpf: true` — el perfil RTP AVPF (feedback), requerido por WebRTC.

Se recomienda `allow=opus` — Opus es el codec que los navegadores prefieren. Asterisk 22 incluye *passthrough* de Opus en el núcleo (el módulo `res_format_attr_opus`), lo cual es suficiente para retransmitir Opus entre dos ramas capaces de usar Opus sin necesidad de recodificar. La *transcodificación* de Opus a otro codec requiere el módulo separado `codec_opus`, que la guía oficial de WebRTC enumera como opcional pero altamente recomendado y que usted instala sobre la compilación base; consulte la discusión sobre codecs en *Designing a VoIP network*. Mantenga `ulaw` como respaldo para realizar puentes hacia ramas que no son WebRTC y que no pueden hablar Opus.

## Paso 4 — ICE, STUN y TURN

En una LAN plana, ICE con candidatos de host es suficiente y no se necesita nada más. A través de internet, generalmente se agrega un servidor STUN para que Asterisk y el navegador puedan descubrir sus direcciones públicas, y un servidor TURN para los casos en los que el flujo de medios directo es imposible (NAT simétrico, firewalls restrictivos). Apunte Asterisk hacia ellos en `rtp.conf`:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
; turnaddr=turn.example.com:3478
; turnusername=...
; turnpassword=...
```

El navegador se configura con sus propios servidores ICE en JavaScript (la lista `RTCPeerConnection` `iceServers`). Para una implementación puramente interna, puede omitir STUN/TURN por completo.

`turnaddr` toma un puerto opcional (predeterminado `3478`); `turnusername` y `turnpassword` se autentican en el relay. STUN solo ayuda a un peer a *descubrir* su dirección pública; cuando ambos extremos se encuentran detrás de un NAT simétrico o un firewall restrictivo, el flujo de medios directo es imposible y un relay TURN es lo único que permite que el audio fluya.

**Recomendación para producción:** un servidor STUN público (como el de Google) es adecuado para el descubrimiento de direcciones, pero **no** dependa de un TURN público para el tráfico real; TURN retransmite todos sus medios, por lo que debe tenerlo bajo su control. Ejecute su propio servidor [coturn](https://github.com/coturn/coturn). Un `/etc/turnserver.conf` mínimo con credenciales de largo plazo se ve así:

```
listening-port=3478
fingerprint
lt-cred-mech
user=asterisk:Strong-TURN-secret
realm=voip.example.com
external-ip=203.0.113.10
```

Luego, apunte Asterisk hacia él en `rtp.conf`:

```
[general]
icesupport=yes
stunaddr=stun.l.google.com:19302
turnaddr=turn.example.com:3478
turnusername=asterisk
turnpassword=Strong-TURN-secret
```

Proporcione al navegador el mismo servidor TURN en su lista `iceServers` para que ambos tramos puedan realizar el relay. Para entornos de producción con usuarios en redes móviles o detrás de firewalls corporativos, un coturn autohospedado es prácticamente obligatorio.

## Paso 5 — el cliente de navegador

Cualquier biblioteca SIP WebRTC funciona; dos de las más utilizadas son **SIP.js** y **JsSIP**. El laboratorio incluye un softphone SIP.js mínimo en `lab/webrtc/index.html`. La parte esencial es la URL de transporte y las credenciales:

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

Dos realidades del navegador que se deben recordar:

- **Contexto seguro.** `getUserMedia` (acceso al micrófono) solo funciona en páginas `https://` o `http://localhost`. Sirva la página a través de HTTPS en producción.
- **Acepte el certificado una vez.** Con un certificado de laboratorio autofirmado, visite primero `https://your-asterisk:8089/ws` en el mismo navegador y acepte la advertencia, o el WebSocket fallará silenciosamente.

El softphone web SipPulse es un cliente de referencia de grado de producción construido sobre estas mismas primitivas.

## Verificación de una llamada WebRTC

Con el navegador registrado, `pjsip show contacts` muestra el contacto dinámico y una llamada enciende el canal:

```
*CLI> pjsip show contacts
  Contact:  webrtc-1000/sip:webrtc-1000@... NonQual Avail
*CLI> core show channels
PJSIP/webrtc-1000-00000001  internal  600  Up  Echo
```

Si el audio es unidireccional o está ausente, casi siempre se trata de ICE o del certificado; consulte la resolución de problemas a continuación.

## Asterisk WebRTC frente a un media gateway

Asterisk puede terminar WebRTC directamente, pero no siempre es la herramienta adecuada:

- **Utilice el WebRTC nativo de Asterisk** cuando el navegador sea un *teléfono* en su PBX: un agente, una extension interna, o un click-to-call que aterriza en su dialplan. El navegador es simplemente otro endpoint y todo (queues, voicemail, IVR) funciona.
- **Utilice un gateway dedicado (por ejemplo, Janus)** cuando necesite escalar muchas sesiones de navegador independientemente del control de llamadas, realizar reenvío selectivo para conferencias/streaming de gran tamaño, o mantener el plano de medios separado de la PBX. Un gateway puentea WebRTC hacia SIP convencional, y Asterisk entonces ve una rama SIP ordinaria.

Muchos sistemas reales combinan ambos: Asterisk para el control de llamadas y un gateway para el escalado de medios del lado del navegador. (Esta es la arquitectura detrás del stack propio de SipPulse.)

## Solución de problemas

- **WebSocket no se conecta:** el navegador rechazó el certificado TLS. Abra
  `https://host:8089/ws` directamente y acéptelo, o instale un certificado de confianza.
- **Se registra pero no hay audio:** ICE falló — agregue STUN, y TURN si está a través de NAT. Verifique
  `pjsip set logger on` y observe los candidatos SDP.
- **Audio unidireccional:** generalmente es un problema de NAT/ICE en un extremo, o un codec sin coincidencia común —
  asegúrese de que `allow=opus,ulaw`.
- **La llamada se corta al contestar:** el handshake de DTLS falló; confirme que `dtls_auto_generate_cert`
  sea `Yes` y que el reloj del sistema sea correcto (los certificados son sensibles al tiempo).

## Laboratorio

1. Ejecute `./lab.sh up`, luego `bash lab/make-certs.sh` y reinicie Asterisk.
2. Sirva `lab/webrtc/index.html` (`python3 -m http.server` desde `lab/webrtc`) y ábralo; acepte el certificado en `https://localhost:8089/ws`.
3. Regístrese como `webrtc-1000` y llame a `600` (prueba de eco) — debería escucharse a sí mismo.
4. Desde el SipPulse Softphone registrado como `6001`, marque `1000` para llamar al navegador.
5. Inspeccione la negociación: `pjsip set logger on`, realice una llamada y encuentre la huella digital DTLS y los candidatos ICE en el SDP.

## Resumen

WebRTC convierte a un navegador en un endpoint de Asterisk de primera clase. La receta es pequeña pero estricta: habilite el servidor HTTP con TLS para que el navegador pueda abrir un WebSocket seguro, agregue un transporte PJSIP `wss` y configure `webrtc=yes` en el endpoint, lo cual activa DTLS-SRTP (con un certificado generado automáticamente), ICE, multiplexación RTP/RTCP y el perfil AVPF. Agregue STUN/TURN al atravesar NAT, sirva su página a través de HTTPS y apunte un cliente SIP.js (o JsSIP) a `wss://asterisk:8089/ws`. Para teléfonos basados en navegador en su PBX, el WebRTC nativo de Asterisk es el camino más sencillo; para medios a gran escala, combínelo con un gateway.

## Cuestionario

1. ¿Qué transporte utiliza un cliente de navegador WebRTC para llevar la señalización SIP a Asterisk?
   - A. UDP simple en el puerto 5060
   - B. Un WebSocket seguro (`wss://`) al servidor HTTP de Asterisk
   - C. TLS en el puerto 5061
   - D. Un socket TCP sin procesar en el puerto 8088

2. ¿Qué mecanismo se utiliza para cifrar los medios WebRTC entre el navegador y Asterisk?
   - A. SDES-SRTP (claves intercambiadas en el SDP)
   - B. DTLS-SRTP (claves derivadas de un handshake DTLS)
   - C. IPsec
   - D. RTP simple: WebRTC no cifra los medios

3. Verdadero o falso: cuando configura `webrtc=yes`, debe generar e instalar manualmente el certificado DTLS utilizado para cifrar los medios.

4. ¿En qué puerto expone el servidor HTTP de Asterisk del laboratorio el WebSocket **seguro** para WebRTC?
   - A. 5060
   - B. 5061
   - C. 8088
   - D. 8089

5. ¿Cuál de los siguientes activa `webrtc=yes` de forma predeterminada? (Elija todas las que correspondan).
   - A. `media_encryption: dtls`
   - B. `ice_support: true`
   - C. `rtcp_mux: true`
   - D. `use_avpf: true`
   - E. `transport: transport-udp`

6. Complete el espacio en blanco: WebRTC negocia la conectividad haciendo que ambos lados recopilen y prueben direcciones candidatas (host, STUN-reflexive, TURN-relayed) utilizando el marco de trabajo ________.

7. En `rtp.conf`, ¿qué dos configuraciones apuntan a Asterisk hacia un servidor externo para que pueda descubrir su dirección pública y retransmitir medios cuando las rutas directas fallan? (Elija todas las que correspondan).
   - A. `icesupport=yes`
   - B. `stunaddr=`
   - C. `turnaddr=`
   - D. `tlsbindaddr=`

8. La ruta URL que el `res_http_websocket` de Asterisk expone para la señalización WebRTC es ________.

9. Según el capítulo, ¿cuándo debería recurrir a una puerta de enlace de medios dedicada (como Janus) en lugar de WebRTC nativo de Asterisk?
   - A. Siempre que cualquier navegador necesite realizar una llamada
   - B. Cuando debe escalar muchas sesiones de medios de navegador independientemente del control de llamadas, realizar reenvío selectivo para conferencias grandes o mantener el plano de medios separado del PBX
   - C. Solo cuando el navegador no admite DTLS
   - D. Cuando desea que el voicemail y el IVR funcionen para el endpoint del navegador

10. Verdadero o falso: `getUserMedia` (acceso al micrófono) funciona en cualquier página `http://`, por lo que servir el softphone del navegador a través de HTTPS es opcional.

**Respuestas:** 1 — B · 2 — B · 3 — Falso (Asterisk genera automáticamente el certificado DTLS; `dtls_auto_generate_cert: Yes`) · 4 — D · 5 — A, B, C, D · 6 — ICE · 7 — B, C · 8 — `/ws` · 9 — B · 10 — Falso (se requiere contexto seguro: `getUserMedia` solo funciona en `https://` o `http://localhost`)
