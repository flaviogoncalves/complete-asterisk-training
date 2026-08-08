# La Asterisk REST Interface (ARI)

El capítulo anterior cubrió AMI y AGI, las dos formas clásicas de añadir lógica externa a Asterisk. Ambas son anteriores a la web moderna: AMI le proporciona un flujo de eventos sin procesar orientado a líneas a través de un socket TCP, y AGI entrega un solo canal a un script durante la duración de una llamada. Ninguna fue diseñada para el tipo de aplicaciones con estado, asíncronas y multicanal que la gente construye hoy en día: IVRs que se comunican con servicios web, paneles de control de click-to-call, controladores de conferencias o bots de voz que transmiten audio a un motor de voz.

ARI —la Asterisk REST Interface— se introdujo en Asterisk 12 para llenar ese vacío, y en Asterisk 22 es la interfaz recomendada para construir nuevas aplicaciones de telefonía. La idea detrás de ARI es una separación clara de responsabilidades: **Asterisk se convierte en un motor de medios** (responde canales, mezcla bridges, reproduce y graba audio, envía DTMF), y **su aplicación proporciona toda la lógica de control de llamadas** a través de una combinación de una API REST (HTTP) y un flujo de eventos WebSocket.

## Objetivos

Al finalizar este capítulo, el lector debería ser capaz de:

- Explicar qué es ARI y en qué se diferencia de AMI y AGI
- Decidir cuándo ARI es la interfaz adecuada para un proyecto
- Configurar `ari.conf` y `http.conf` para habilitar ARI y crear un usuario
- Conectarse al flujo de eventos WebSocket de ARI
- Describir la aplicación de dialplan Stasis y los eventos `StasisStart`/`StasisEnd`
- Describir el modelo de recursos de ARI: channels, bridges, playbacks, recordings, endpoints y device states
- Escribir una aplicación Stasis mínima en Python que conteste un channel, reproduzca un sonido y cuelgue
- Explicar qué es el channel `externalMedia` y por qué es importante para integraciones de IA y voicebots

## Qué es ARI y cuándo usarlo

ARI se basa en dos transportes que funcionan en conjunto:

- **Una API REST (HTTP)** que su aplicación invoca para *hacer* cosas: originar un canal, contestarlo, reproducir un sonido, crear un bridge, iniciar una grabación, colgar. Estas son solicitudes HTTP ordinarias (`GET`, `POST`, `DELETE`) contra `http://asterisk-host:8088/ari/...`.
- **Un flujo de eventos WebSocket** a través del cual Asterisk le *informa* a su aplicación qué está sucediendo: se creó un canal, llegó un dígito DTMF, finalizó una reproducción, un canal abandonó su aplicación. Los eventos se entregan como objetos JSON.

El patrón es asíncrono: usted realiza una solicitud y el *resultado* de esa solicitud generalmente regresa más tarde como un evento. Por ejemplo, usted `POST` una solicitud para reproducir un sonido; Asterisk responde inmediatamente con un objeto `Playback` y, algunos segundos después, usted recibe un evento `PlaybackFinished` cuando el audio ha terminado.

Elija ARI en lugar de AMI y AGI cuando:

- Necesite **control detallado de canales y bridges**: construir conferencias, estacionamiento, colas o flujos de llamadas personalizados a partir de primitivas en lugar de depender de aplicaciones del dialplan.
- Su aplicación sea **con estado y de larga duración**, manteniendo varios canales a la vez y reaccionando a eventos en todos ellos.
- Desee integrarse con **servicios web, buses de mensajes o motores de IA/voz** y prefiera JSON sobre HTTP en lugar de un protocolo de línea o un script de stdin/stdout.
- Esté comenzando un **nuevo proyecto** y desee la interfaz que el proyecto Asterisk recomienda activamente.

AMI sigue siendo la herramienta adecuada cuando solo necesita *observar* el sistema o ejecutar comandos ocasionales (marcadores, wallboards, monitoreo). AGI sigue siendo conveniente para un script de IVR rápido y autónomo. Pero para cualquier cosa que orqueste llamadas, ARI es la respuesta moderna.

> ARI no reemplaza al dialplan, lo complementa. Un canal se ejecuta en el dialplan como de costumbre hasta que llega a la aplicación `Stasis()`, momento en el cual el control se transfiere a su aplicación ARI. Cuando su aplicación termina, el canal puede ser enviado de regreso al dialplan o colgado.

## Habilitación de ARI: http.conf y ari.conf

ARI funciona sobre el servidor HTTP integrado de Asterisk, por lo que se requieren dos archivos de configuración: `http.conf` habilita el servidor web y `ari.conf` habilita ARI y define sus usuarios.

### http.conf

El servidor HTTP debe estar habilitado y vinculado a una dirección y un puerto. El puerto convencional para ARI es **8088**.

```ini
[general]
enabled=yes
bindaddr=0.0.0.0
bindport=8088
```

Para entornos de producción, debe colocar ARI detrás de TLS. Asterisk puede servir HTTPS directamente (`tlsenable=yes`, `tlsbindaddr`, `tlscertfile`, `tlsprivatekey`), o puede terminar TLS en un proxy inverso frente al puerto 8088. A través de TLS, las URLs se convierten en `https://` y `wss://` en lugar de `http://` y `ws://`.

Puede confirmar que el servidor HTTP está activo desde la CLI:

```
asterisk*CLI> http show status
HTTP Server Status:
Server Enabled and Bound to 0.0.0.0:8088
```

### ari.conf

`ari.conf` tiene una sección `[general]` y una sección por cada usuario.

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

Algunas notas sobre estas opciones:

- `enabled` activa o desactiva ARI de forma global.
- `pretty` formatea las respuestas JSON para que sean legibles por humanos; desactívelo en producción.
- Cada usuario es una sección con nombre mediante `type=user`.
- `read_only=yes` restringe a ese usuario a solicitudes de solo lectura (GET).
- `password_format` puede ser `plain` (la contraseña está en texto plano) o `crypt` (una contraseña cifrada, generada con `mkpasswd -m sha-512`).
- `permit`, `deny` y `acl` permiten restricciones de IP por usuario, siguiendo las mismas reglas que `acl.conf`.

Después de editar los archivos, recargue los módulos correspondientes (`module reload res_ari.so` y `module reload http.so`) o reinicie Asterisk. Puede verificar que ARI se está ejecutando con:

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

`ari show apps` enumera las aplicaciones Stasis registradas actualmente por los clientes conectados. Está vacío hasta que un cliente se conecta, que es exactamente lo que haremos a continuación.

### La URL de eventos de WebSocket

Un cliente se suscribe al flujo de eventos abriendo un WebSocket hacia el endpoint `/ari/events`, nombrando la aplicación Stasis que implementa y pasando sus credenciales:

```
ws://asterisk-host:8088/ari/events?app=hello&api_key=asterisk:secret
```

Los parámetros de consulta son:

- `app` — el nombre de su aplicación Stasis. Este es el mismo nombre que utilizará en la llamada `Stasis()` del dialplan. Puede pasar varios nombres separados por comas.
- `api_key` — las credenciales, en el formato `username:password`, que coinciden con un usuario en `ari.conf`.
- `subscribeAll` — booleano opcional (predeterminado `false`); cuando es `true`, la aplicación recibe todos los eventos, no solo aquellos de los recursos que posee.

Las mismas credenciales `user:pass` se utilizan como autenticación HTTP Basic en las llamadas REST (o también se añaden como un parámetro de consulta `api_key` allí).

## Stasis: entregando un canal a su aplicación

El puente entre el dialplan y ARI es la aplicación de dialplan **`Stasis()`** (el marco de trabajo subyacente también se llama Stasis). Cuando un canal llega a `Stasis(appname[,args])`, Asterisk entrega ese canal a la aplicación ARI registrada bajo `appname` y deja de ejecutar el dialplan para él. El control ahora pertenece a su código.

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

Cuando el canal entra en la aplicación, cada cliente conectado suscrito a `hello` recibe un evento **`StasisStart`** a través del WebSocket, que contiene el objeto de canal completo (su ID, nombre, caller ID, estado y cualquier argumento pasado a `Stasis()`). Esta es su señal para comenzar a controlar el canal.

Cuando el canal abandona la aplicación —porque su código lo devolvió al dialplan con `continueInDialplan`, o porque fue colgado— usted recibe un evento **`StasisEnd`**. Después de que `Stasis()` regresa al dialplan, este establece la variable de canal `STASISSTATUS` (`SUCCESS` o `FAILED`), para que el dialplan pueda ramificarse según el resultado.

## El modelo de recursos de ARI

ARI expone los componentes internos de Asterisk como un pequeño conjunto de recursos REST. Cada recurso reside bajo `/ari/<resource>` y se manipula con métodos HTTP estándar. Los más importantes son:

| Recurso | Lo que representa | Operaciones de ejemplo |
|----------|--------------------|--------------------|
| **channels** | Un segmento de llamada individual | originate, answer, play, record, hangup |
| **bridges** | Un punto de mezcla que une canales | create, add/remove channels, play to the bridge |
| **playbacks** | Una reproducción de medios en curso | get status, stop, pause/unpause |
| **recordings** | Grabaciones en vivo y almacenadas | start, stop, list stored, delete |
| **endpoints** | Peers configurados (PJSIP, etc.) | list, get state, send a message |
| **deviceStates** | Estados de dispositivo personalizados | list, get, set, delete |

Algunas llamadas REST concretas (las rutas se muestran con el prefijo `/ari` que aparece en la red):

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

El parámetro `media` en una solicitud `play` toma un URI de medios. La forma más común es un URI `sound:` que nombra un sonido integrado, por ejemplo `sound:hello-world` o `sound:tt-monkeys`. Cuando el audio termina, Asterisk emite un evento `PlaybackFinished` para ese ID de reproducción, que es como su aplicación sabe que puede continuar.

Los channels y los bridges son los dos bloques de construcción que usted combina para crear flujos de llamadas. Para conectar a dos personas que llaman, por ejemplo, usted origina o acepta dos channels, crea un bridge `mixing` con `POST /ari/bridges` y añade ambos channels a él con `POST /ari/bridges/{bridgeId}/addChannel`. Para construir una conferencia, simplemente siga añadiendo channels al mismo bridge.

## Un ejemplo práctico: una aplicación Stasis mínima

Construyamos la aplicación ARI más pequeña que sea útil. Cuando se marca cualquier extension, la llamada entra en nuestra aplicación Stasis, la cual la contesta, reproduce el clásico prompt `hello-world` y cuelga.

### El dialplan

En `extensions.conf`, envíe el channel a Stasis:

```
[from-internal]
exten => _X.,1,Stasis(hello)
 same => n,Hangup()
```

El nombre de la aplicación `hello` coincide con el `app=hello` que usamos al conectarnos.

### El cliente de Python

Este cliente utiliza dos bibliotecas bien conocidas: `requests` para las llamadas REST y `websocket-client` para el flujo de eventos. Instálelas con `pip install requests websocket-client`.

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

Ejecute el script y luego marque cualquier número desde un endpoint registrado. Debería escuchar "Hello, world", tras lo cual la llamada se libera. En la consola de Asterisk, `ari show apps` ahora mostrará `hello` mientras el cliente esté conectado.

Vale la pena seguir el flujo una vez:

1. El dialplan ejecuta `Stasis(hello)`; Asterisk entrega el channel a nuestra aplicación y envía un evento `StasisStart`.
2. Contestamos el channel y luego le pedimos a Asterisk que reproduzca `sound:hello-world`. Asterisk devuelve un objeto `Playback` cuyo `id` recordamos.
3. Cuando el audio termina, Asterisk envía `PlaybackFinished` con ese playback `id`; buscamos el channel y lo colgamos.
4. Colgar provoca que el channel abandone Stasis, produciendo un evento `StasisEnd`.

> **Una nota sobre las bibliotecas cliente.** Existe un wrapper de nivel superior llamado `ari-py` (el paquete `ari`), pero no tiene mantenimiento y fue escrito para una era más antigua de Python y herramientas Swagger. Para trabajos nuevos en Asterisk 22, prefiera el enfoque explícito de `requests` + WebSocket mostrado arriba, o una biblioteca de asyncio como `asyncari` si necesita concurrencia. El enfoque directo lo mantiene cerca de las llamadas REST y los eventos reales, que es exactamente lo que desea mientras aprende ARI.

## externalMedia: la puerta a la IA y los bots de voz

Los recursos anteriores le permiten reproducir y grabar *archivos*. Pero las aplicaciones de voz modernas (transcripción de voz a texto, bots de voz con IA, análisis en tiempo real) necesitan que el *flujo de audio en vivo* de una llamada se entregue a un proceso externo, y necesitan inyectar audio de vuelta.

ARI proporciona esto a través del **`externalMedia` channel**. Una solicitud `POST /ari/channels/externalMedia` crea un canal especial que, en lugar de hablar con un teléfono, transmite el medio RTP de la llamada hacia (y desde) un host externo. Usted conecta este canal con el canal de la persona que llama, y ahora su programa externo está en la ruta de audio: recibe el audio de quien llama como RTP y puede enviar audio sintetizado de vuelta.

La solicitud solo requiere:

- `app` — la aplicación Stasis que posee el nuevo canal.
- `format` — el formato de audio, por ejemplo `ulaw` o `slin16`.

`external_host` (el `host:port` de su aplicación de medios) es opcional en el esquema — puede estar vacío para una conexión de estilo servidor WebSocket — pero para un bot de voz RTP clásico usted lo proporcionará. El parámetro `encapsulation` tiene como valor predeterminado `rtp` y `transport` a `udp`, que es exactamente lo que usted desea para un endpoint de medios en streaming.

```
POST /ari/channels/externalMedia
    app=hello
    external_host=127.0.0.1:9000
    format=slin16
```

Esta característica única es lo que convierte a Asterisk en una interfaz para la IA: la red telefónica termina en Asterisk, ARI orquesta la llamada y `externalMedia` canaliza el audio hacia un motor de voz/IA y de regreso. Este es el mecanismo sobre el cual se construyen los servicios de IA y los bots de voz.

## Resumen

ARI es la interfaz moderna y recomendada para crear aplicaciones de telefonía en Asterisk 22. Divide el trabajo de forma clara: Asterisk es el motor de medios y su aplicación —que utiliza JSON sobre HTTP y un WebSocket— proporciona la lógica de control de llamadas. Se habilita a través de `http.conf` (el servidor web integrado en el puerto 8088) y `ari.conf` (que activa ARI y define a los usuarios).

La aplicación de dialplan `Stasis()` entrega un canal a su aplicación, generando `StasisStart` cuando entra y `StasisEnd` cuando sale. A partir de ahí, usted manipula un pequeño conjunto de recursos REST —channels, bridges, playbacks, recordings, endpoints y device states— para contestar, reproducir, grabar, puentear y colgar.

Construimos una aplicación mínima en Python Stasis que contesta una llamada, reproduce un mensaje y cuelga, y vimos cómo el canal `externalMedia` transmite RTP en vivo a un programa externo, lo cual constituye la base para integraciones de IA y voicebots.

## Cuestionario

1. ¿En qué versión de Asterisk se introdujo ARI?
   - A. Asterisk 1.4
   - B. Asterisk 11
   - C. Asterisk 12
   - D. Asterisk 18
2. En el modelo ARI, Asterisk actúa como un motor de medios mientras su aplicación externa proporciona la lógica de control de llamadas.
   - A. Verdadero
   - B. Falso
3. ARI utiliza dos transportes en conjunto. ¿Qué par es el correcto?
   - A. Una API REST/HTTP para emitir comandos y un flujo WebSocket para recibir eventos
   - B. Un protocolo de línea TCP y un script de stdin/stdout
   - C. SNMP y SMTP
   - D. Dos sockets UDP separados
4. ¿Qué dos archivos de configuración deben configurarse para habilitar ARI?
   - A. `manager.conf` y `agi.conf`
   - B. `http.conf` y `ari.conf`
   - C. `sip.conf` y `rtp.conf`
   - D. `modules.conf` y `cdr.conf`
5. El puerto TCP convencional para el servidor HTTP de Asterisk (y por lo tanto para ARI) es ____.
6. ¿Qué aplicación del dialplan transfiere un canal a una aplicación ARI?
   - A. `AGI()`
   - B. `Dial()`
   - C. `Stasis()`
   - D. `System()`
7. Cuando un canal entra en una aplicación Stasis, ¿qué evento se envía al cliente conectado?
   - A. `ChannelDestroyed`
   - B. `StasisStart`
   - C. `Newchannel`
   - D. `Hangup`
8. ¿Qué solicitud de ARI crea un punto de mezcla que puede unir dos o más canales?
   - A. `POST /ari/channels`
   - B. `POST /ari/bridges`
   - C. `GET /ari/endpoints`
   - D. `DELETE /ari/recordings/stored`
9. Para reproducir un aviso integrado en un canal, ¿qué evento le indica a su aplicación que el audio ha terminado para que pueda continuar?
   - A. `PlaybackStarted`
   - B. `DTMFReceived`
   - C. `PlaybackFinished`
   - D. `ChannelTalkingFinished`
10. El canal `externalMedia` se utiliza principalmente para:
    - A. Grabar una llamada en un archivo WAV local
    - B. Transmitir el audio en vivo de la llamada (RTP) hacia y desde una aplicación externa, por ejemplo, un motor de IA/voz
    - C. Registrar un endpoint PJSIP
    - D. Recargar el dialplan

**Respuestas:** 1 — C · 2 — A · 3 — A · 4 — B · 5 — `8088` · 6 — C · 7 — B · 8 — B · 9 — C · 10 — B
