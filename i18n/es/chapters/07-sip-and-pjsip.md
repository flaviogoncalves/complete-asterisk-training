# SIP & PJSIP en profundidad

SIP es el protocolo; PJSIP es la forma en que Asterisk 22 lo habla. **PJSIP** (`chan_pjsip`, configurado mediante `pjsip.conf`) es el único controlador de canal SIP en Asterisk 22 LTS. Este capítulo cubre los fundamentos del protocolo SIP (los cuales son a nivel de protocolo y permanecen 100% válidos) y el modelo de objetos y configuración de PJSIP que usted utiliza todos los días. El controlador heredado retirado y una guía de migración se cubren en el capítulo *Legacy channels*.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Explicar el rol de los agentes de usuario SIP, proxies, registradores y gateways;
- Seguir un flujo básico de llamada SIP (REGISTER, INVITE, respuestas provisionales y finales, ACK, BYE) y leer un mensaje SIP;
- Describir cómo SDP negocia la sesión de medios y cómo NAT afecta la señalización SIP y RTP;
- Mapear el modelo de objetos de PJSIP — `endpoint`, `auth`, `aor`, `transport`, `identify` y `registration` — y cómo los objetos se referencian entre sí;
- Configurar teléfonos SIP y trunks en `pjsip.conf`, incluyendo las opciones de traversal de NAT; y
- Verificar y solucionar problemas de endpoints con los comandos de CLI `pjsip show …`.

## Fundamentos del protocolo SIP

El Session Initiation Protocol (SIP) es un protocolo basado en texto similar a HTTP y SMTP que fue diseñado para inicializar, mantener y terminar sesiones de comunicación interactiva entre usuarios. Estas sesiones pueden incluir voz, video, chat, juegos interactivos y otros. SIP fue definido por el IETF y se ha convertido en el estándar de facto para las comunicaciones de voz. Es muy importante entender cómo funciona SIP. En Asterisk 22, la configuración de SIP reside en `pjsip.conf`, que es uno de los archivos editados con mayor frecuencia en un sistema basado en SIP (justo después de `extensions.conf`).

### Teoría de operación

SIP es un protocolo de señalización con los siguientes componentes: User Agent Client, User Agent Servers, SIP Proxies y SIP Gateways. La siguiente figura representa las relaciones entre estos componentes.

- UAC (user agent client) – El cliente o terminal que inicializa la señalización SIP.
- UAS (user agent server) – El servidor que responde a una señalización SIP proveniente de un UAC.
- UA (user agent) – El terminal SIP (teléfonos o gateways que contienen tanto UAC como UAS).
- Proxy Server – Recibe solicitudes de un UA y las transfiere a otros SIP Proxies si la estación en particular no está bajo su administración.
- Redirect Server – Recibe solicitudes y las envía de vuelta al UA, incluyendo datos de destino, en lugar de reenviarlas directamente al destino.
- Location Server – Recibe solicitudes de un UA y actualiza la base de datos de ubicación con esta información.

Por lo general, los servidores proxy, de redirección y de ubicación se alojan en el mismo hardware y utilizan la misma pieza de software, a la que llamamos SIP proxy. El SIP proxy es responsable del mantenimiento de la base de datos de ubicación, el establecimiento de la conexión y la terminación de la sesión.

![Los componentes principales de SIP: agentes de usuario (UAC/UAS/UA), el servidor de registro/proxy/redirección y un gateway hacia la PSTN, con el flujo de medios RTP directamente entre endpoints](../images/07-sip-and-pjsip-fig01.png)

#### Proceso de registro SIP

Antes de que un teléfono pueda recibir llamadas, debe registrarse en una base de datos de ubicación. En la base de datos de ubicación, la dirección IP se vinculará al nombre. En el siguiente ejemplo, la extension 8500 se vinculará a la dirección IP 200.180.1.1. No es necesario utilizar números de teléfono. En la arquitectura SIP, la extension registrada podría ser flavio@voip.school también.

![Registro SIP: el teléfono envía un REGISTER vinculando la extension 8500 a su dirección IP, el registrador almacena el contacto en la base de datos de ubicación y responde con 200 OK](../images/07-sip-and-pjsip-fig02.png)

#### Operación de proxy

Al operar como un SIP proxy, el servidor SIP permanece en medio de la señalización y es capaz de realizar enrutamiento avanzado y facturación. El flujo de medios, basado en el real time protocol (RTP), sigue yendo directamente entre los endpoints.

![Operación de proxy: el SIP proxy permanece en la ruta de señalización (INVITE/200 OK) y busca al destinatario en el servidor de ubicación, mientras que los medios RTP fluyen directamente entre los dos endpoints](../images/07-sip-and-pjsip-fig03.png)

#### Operación de redirección

Al redirigir, el servidor SIP simplemente envía un mensaje (por ejemplo, 302 moved temporarily) al agente de usuario y se mantiene fuera de la ruta de los nuevos mensajes. Es muy ligero en términos de uso de recursos, pero no tienes control alguno. La redirección se utiliza a veces en diseños de balanceo de carga.

![Operación de redirección: el servidor de redirección responde al INVITE con un 302 Moved Temporarily que contiene el contacto, luego se aparta mientras el emisor vuelve a enviar INVITE/ACK directamente a la nueva ubicación](../images/07-sip-and-pjsip-fig04.png)

#### Cómo maneja Asterisk el SIP

Es importante entender que Asterisk no es un SIP proxy ni un SIP redirector. Asterisk puede desempeñar el papel de registrador y servidor de ubicación; sin embargo, solo conecta dos UACs a sí mismo. Por lo tanto, Asterisk se considera un back-to-back user agent (B2BUA). En otras palabras, conecta dos canales SIP, uniéndolos. Asterisk tiene un mecanismo de re-invite que puede hacer que los canales SIP hablen entre sí directamente en lugar de pasar por Asterisk. En un endpoint PJSIP, esto se controla mediante el parámetro `direct_media`. Al usar `direct_media=yes`, el flujo RTP va directamente de un endpoint a otro, liberando recursos del servidor.

#### Operación SIP con direct_media=yes

![Operación SIP con directmedia=yes: la señalización SIP fluye a través de Asterisk mientras que el audio RTP va directamente entre los dos teléfonos, liberando recursos del servidor](../images/07-sip-and-pjsip-fig05.png)

Sin embargo, si necesitas transferir o grabar la llamada usando Asterisk, puedes usar el parámetro `direct_media=no` para forzar el flujo RTP a través del servidor Asterisk.

#### Operación SIP con direct_media=no

![Operación SIP con directmedia=no: tanto la señalización SIP como el audio RTP están anclados a través de Asterisk, lo que le permite grabar, transcodificar o transferir la llamada](../images/07-sip-and-pjsip-fig06.png)

#### Mensajes SIP

Los mensajes SIP básicos son:

- INVITE – establecimiento de conexión
- ACK – acuse de recibo
- BYE – terminación de conexión
- CANCEL – terminación de conexión para una llamada no establecida
- REGISTER – registrar un UAC en un SIP proxy
- OPTIONS – se puede usar para verificar la disponibilidad
- REFER – transferir una llamada SIP a otra persona
- SUBSCRIBE – suscribirse a eventos de notificación
- NOTIFY – enviar información del canal
- INFO – enviar varios mensajes (por ejemplo, DTMF)
- MESSAGE – enviar mensajes instantáneos

Las respuestas SIP están en formato de texto y son fácilmente legibles (similares a los mensajes HTTP). Las respuestas más importantes son:

- 1XX – Mensajes de información (100–trying, 180–ringing, 183–progress)
- 2XX – Solicitud exitosa completada (200 – OK)
- 3XX – Redirección de llamada, la solicitud debe dirigirse a otro lugar (302 – moved temporarily, 305 – use proxy)
- 4XX – Error (403 – Forbidden)
- 5XX – Error de servidor (500 – Internal Server Error; 501 – Not implemented)
- 6XX – Fallo global (606 – Not acceptable)

Por ejemplo:

```
INVITE sip:2000@192.168.1.133 SIP/2.0
Via: SIP/2.0/UDP
192.168.1.116;rport;branch=z9hG4bKc0a8017400000063452fafbb00006967000000d2
From: "unknown"<sip:2001@192.168.1.133>;tag=1556140623845
To: <sip:2000@192.168.1.133>
Contact: <sip:2001@192.168.1.116>
Call-ID: 64B4C8EC-FCFC-49E9-98B1-90982EEEBED3@192.168.1.116
CSeq: 2 INVITE
Max-Forwards: 70
User-Agent: SJphone/1.61.312b (SJ Labs)
Content-Length: 335
Content-Type: application/sdp
Proxy-Authorization: Digest
username="2001",realm="asterisk",nonce="6c55905e",uri="sip:2000@192.168.1.133",
response="983c0099eea125d8cdfe93b0ec99f3ec",algorithm=MD5
```

#### Session description protocol (SDP)

SDP fue definido originalmente en el IETF RFC 2327, ahora obsoleto por el RFC 4566. Está destinado a describir sesiones multimedia con fines de anuncio de sesión, invitación de sesión y otras formas de iniciación de sesiones multimedia. SDP incluye:

- Protocolo de transporte (RTP/UDP/IP)
- Tipo de medio (texto, audio, video)
- Formato de medio o codec (video H.261, audio g.711, etc.)
- Información necesaria para recibir estos medios (direcciones, puertos, etc.)

El siguiente ejemplo es una transcripción de un SDP que describe una llamada entre dos teléfonos.

```
v=0
o=- 3369741883 3369741883 IN IP4 192.168.1.116
s=SJphone
c=IN IP4 192.168.1.116
t=0 0
a=setup:active
m=audio 49160 RTP/AVP 3 97 98 8 0 101
a=rtpmap:3 GSM/8000
a=rtpmap:97 iLBC/8000
a=rtpmap:98 iLBC/8000
a=fmtp:98 mode=20
a=rtpmap:8 PCMA/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-11,16
```

### NAT Traversal SIP

Network Address Translation (NAT) es una característica utilizada por la mayoría de las redes para ahorrar direcciones IP de Internet. Por lo general, una empresa recibe un pequeño bloque de direcciones IP, y los usuarios finales reciben una dirección IP dinámicamente cuando se conectan a Internet. NAT resuelve el problema de direccionamiento mapeando direcciones internas a direcciones externas. Almacena un mapeo de direcciones internas a externas en su memoria. Este mapeo es válido por un período de tiempo específico, después del cual se descarta. El mapeo utiliza pares IP:puerto para las direcciones internas y externas. Existen cuatro tipos de NAT:

- Full Cone
- Restricted Cone
- Port Restricted Cone
- Symmetric

La teoría de NAT a continuación —los cuatro tipos de NAT, el problema del encabezado Contact, los keep-alives y forzar los medios a través del servidor— es de nivel de protocolo y se aplica a cualquier implementación SIP. La forma en que configuras cada comportamiento en Asterisk 22 (PJSIP) se cubre más adelante en este capítulo bajo *Nat traversal on res_pjsip*.

#### Full Cone

El primer NAT, full cone, representa un mapeo estático de un par IP:puerto externo a un par IP:puerto interno. Cualquier computadora externa puede conectarse a él usando el par IP:puerto externo. Este es el caso en firewalls no stateful implementados con el uso de filtros.

![Full Cone NAT: el host interno (10.0.0.1:8000) está mapeado estáticamente al par externo 200.180.4.168:1234, por lo que cualquier computadora externa puede enviar paquetes a ese par y llegar al host interno](../images/07-sip-and-pjsip-fig11.png)

#### Restricted Cone

En el escenario de restricted cone, el par IP:puerto externo se abre solo cuando la computadora interna envía datos a una dirección externa. Sin embargo, el NAT restricted cone bloquea cualquier paquete entrante de una dirección diferente. En otras palabras, la computadora interna tiene que enviar datos a una computadora externa antes de que pueda enviar datos de vuelta.

#### Port Restricted Cone

El firewall port restricted cone es casi idéntico al restricted cone. La única diferencia es que, ahora, el paquete entrante tiene que provenir exactamente de la misma IP y puerto del paquete enviado.

#### Symmetric

El último tipo de NAT se llama symmetric. Es diferente de los tres primeros en que se realiza un mapeo específico para cada dirección externa. Solo se permite que direcciones externas específicas regresen mediante el mapeo NAT. No es posible predecir el par IP:puerto externo que utilizará el dispositivo NAT. Los otros tres tipos de NAT permiten el uso de un servidor externo para descubrir la dirección IP externa para la comunicación. Con NAT symmetric, incluso si puedes conectarte a un servidor externo, la dirección descubierta no se puede usar para ningún otro dispositivo excepto para este servidor.

![Symmetric NAT: se asigna un puerto de origen externo diferente para cada destino, por lo que el mapeo descubierto hacia un servidor no puede ser reutilizado por otro host, lo que rompe el traversal basado en STUN](../images/07-sip-and-pjsip-fig12.png)

#### Tabla de firewall NAT

La siguiente tabla resume los cuatro tipos de NAT.

| Tipo de NAT | Debe enviar datos primero | Puede determinar la IP:puerto externa para paquetes de retorno | Restringe paquetes entrantes a la IP:puerto de destino |
| --- | --- | --- | --- |
| Full Cone | No | Sí | No |
| Restricted Cone | Sí | Sí | Solo IP |
| Port Restricted Cone | Sí | Sí | Sí |
| Symmetric | Sí | No | Sí |

#### Señalización SIP y RTP sobre NAT

Algunos de los mayores problemas en el NAT traversal son que tienes que resolver dos problemas: señalización SIP y audio (RTP). La mayoría de los problemas de audio unidireccional están relacionados con NAT. Algo interesante sobre SIP es que, cuando un UAC envía un paquete, incrusta la dirección IP en el campo de encabezado SIP “Contact”. Por lo general, esta es una dirección interna (RFC1918); las respuestas a este paquete no pueden ser enrutadas a través de Internet de vuelta al UAC. Las soluciones conceptuales son siempre las mismas:

- **Ignorar la dirección Contact/Via y responder a donde realmente vino el paquete.** Este es el comportamiento definido en el RFC 3581 (`rport`). En PJSIP es `force_rport=yes`, y `rewrite_contact=yes` reescribe el contacto almacenado a la dirección de origen.
- **Enviar los medios de vuelta a la dirección desde la que realmente llegó el RTP** (RTP simétrico, históricamente llamado *comedia*). En PJSIP esto es `rtp_symmetric=yes`.
- **Mantener abierto el mapeo NAT.** Si el mapeo expira, Asterisk ya no puede enviar un INVITE al UAC — el teléfono puede realizar llamadas pero no recibirlas. Enviar un OPTIONS periódico (un *qualify*) mantiene el pinhole abierto. En PJSIP esto es `qualify_frequency=` en el AOR.

Si el NAT del usuario es del tipo symmetric, no es posible enviar paquetes de un UAC a otro directamente; en ese caso, tienes que forzar el RTP a través de Asterisk con `direct_media=no`. Estas configuraciones son apropiadas para la mayoría de los casos. Es posible optimizar el tráfico usando técnicas avanzadas como Simple Traversal of UDP over NAT (STUN), que es útil con full cone, restricted cone y port restricted cone, y Application Layer Gateway (ALG). Desafortunadamente, la mayoría de los firewalls hoy en día —incluso los routers DSL/cable domésticos— son symmetric, lo que hace que STUN sea inutilizable. ALG podría resolver el problema, pero no es compatible, no está implementado o tiene errores en la mayoría de los casos.

#### Asterisk detrás de NAT

A veces, el servidor Asterisk mismo se implementa detrás de un firewall con NAT — una situación muy común cuando despliegas en la nube. En este caso, es necesario realizar una configuración adicional para que Asterisk anuncie su dirección **pública** en los encabezados SIP y SDP en lugar de la privada.

Conceptualmente hay tres pasos:

- Reenviar el puerto de señalización SIP (UDP 5060 por defecto) desde el firewall al servidor Asterisk.
- Reenviar el rango de puertos de medios RTP (UDP 10000–20000 por defecto, configurado en `rtp.conf`) desde el firewall al servidor Asterisk.
- Decirle a Asterisk su dirección externa y qué red es local, para que sepa cuándo sustituir la dirección pública en los encabezados.

En PJSIP, estos dos últimos elementos se mapean a `external_media_address` / `external_signaling_address` y `local_net=` en el **transport**, y el rango de puertos RTP todavía se configura en `rtp.conf`:

```
; RTP Configuration
;
[general]
;
; RTP start and RTP end configure start and end addresses
;
rtpstart=10000
rtpend=20000
```

La configuración PJSIP completa y funcional para un servidor Asterisk detrás de NAT se proporciona más adelante en este capítulo bajo *Asterisk Server behind NAT*.

### Limitaciones de SIP

Asterisk utiliza el flujo RTP entrante para sincronizar el flujo saliente. Si el flujo entrante se interrumpe (supresión de silencio), la música en espera se cortará. En otras palabras, no debes usar supresión de silencio en teléfonos o proveedores con Asterisk.

## PJSIP: el canal SIP

PJSIP es el canal SIP en Asterisk. Se introdujo por primera vez en Asterisk 12 y, tras años de desarrollo, se convirtió en el canal SIP predeterminado y recomendado; en Asterisk 22 (la versión LTS actual) es el único controlador de canal SIP. PJSIP se basa en el proyecto de Teluu llamado pjproject. La pila pjproject es utilizada por muchos softphones e implementaciones comerciales de SIP. Es una pila SIP versátil y madura.

### Por qué usar PJSIP

PJSIP fue un rediseño desde cero de cómo Asterisk habla SIP, y vale la pena entender las características que lo convirtieron en el estándar.

#### Características

El canal admite muchas características, algunas de las cuales merecen mención aquí:

- Registros múltiples: Puede usar más de un teléfono conectado a la misma Address of Record. En otras palabras, puede conectar dos teléfonos al mismo endpoint.
- Interfaz de programación de aplicaciones (API) amigable. La API es modular y fácil de extender, construida a partir de muchos módulos pequeños que cooperan entre sí en lugar de un gran bloque de código.
- Transportes múltiples: Puede escuchar en múltiples direcciones, puertos y transportes al usar PJSIP. No está limitado a una única dirección de enlace para todos sus dispositivos. PJSIP es muy flexible.

#### Una nota sobre la configuración

La configuración de PJSIP es más detallada: requiere un poco más de esfuerzo y más líneas de configuración, ya que cada dispositivo se describe mediante varios objetos relacionados en lugar de un bloque de peer único. Esa estructura adicional es lo que le da a PJSIP su flexibilidad, y el asistente de configuración (cubierto más adelante) mantiene el aprovisionamiento diario breve.

### Módulos de PJSIP

El canal PJSIP está implementado por muchos módulos descritos a continuación:

#### res_pjsip

Esta es la capa base de PJSIP y el módulo principal. Es responsable de algunos de los servicios principales.

#### res_pjsip_session

Este módulo es responsable de las sesiones de medios, el procesamiento del protocolo de descripción de sesión y algunos complementos.

#### res_pjsip_messaging

Procesa mensajes SIP y analiza encabezados SIP.

#### res_pjsip_registrar

Responsable de manejar los registros SIP.

#### res_pjsip_pubsub

Responsable de procesar subscribe, notify y publish. Estos mensajes son responsables de manejar la presencia SIP y BLF (Busy Lamp Field).

### Configuración de PJSIP

PJSIP tiene muchas secciones diferentes. El formato de la sección es:

```
[Section Name]
Option = Value
Option = Value
```

#### Sección de endpoint

El objeto de configuración más importante es el endpoint. La configuración del endpoint tiene una funcionalidad central y debe asociarse con una sección de AOR y una de Transport. Ejemplo:

```
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
```

Si observa el ejemplo anterior, el endpoint es una especie de pegamento que une todas las secciones. Especifica un transporte, la address of record y la autenticación para un teléfono. También define la parte más importante, el punto de entrada del context en el dialplan.

#### Address of Record (AOR)

Este objeto le dice a Asterisk dónde contactar al endpoint. Almacena las direcciones de contacto. También permite la configuración de buzones de voz. Ejemplo:

```
[softphone]
type=aor
max_contacts=2
```

#### Autenticación

Esta sección es responsable de la autenticación entrante y saliente. La documentación se encuentra en el archivo de ejemplo pjsip.conf. Ejemplo:

```
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
```

#### Transporte

La sección de transporte le permite definir direcciones IPV4 e IPV6 y el protocolo de transporte, TCP, UDP, TLS, Websockets, etc. También puede configurar direcciones Natted en esta sección. Puede crear múltiples transportes, pero no pueden compartir la misma IP y puerto, y no puede vincular múltiples transportes TCP o TLS de la misma versión de IP. Ejemplo:

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
```

#### Registro

Este objeto se utiliza para configurar un registro saliente. Ejemplo:

```
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
```

#### Identify

Este objeto controla qué solicitud SIP pertenece a cada endpoint. Si no tiene una sección de identify, el sistema hará coincidir el contenido del encabezado “From” con el nombre del endpoint. Usando esta sección, puede asignar direcciones IP específicas a endpoints específicos, identificados por nombre de usuario o IP. Ejemplo:

```
[siptrunk]
type=identify
endpoint=siptrunk
match=52.37.87.85
```

#### ACL

El objeto ACL le permite configurar redes específicas con acceso al endpoint. Ahora las ACL se definen en una sección específica o en el archivo acl.conf. Ejemplo:

```
[acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=209.16.236.0
permit=209.16.236.1
```

### Relación entre entidades

La relación entre los objetos de configuración proporciona una gran flexibilidad para la configuración. Sin embargo, parece un poco complejo para cualquiera que esté empezando.

![Relaciones entre los objetos de configuración de PJSIP: el endpoint se vincula al transporte, auth y AOR (que contiene los contactos); el registro se vincula al transporte y auth; identify apunta al endpoint, mientras que ACL y domain alias son independientes](../images/07-sip-and-pjsip-fig14.png)

El gráfico anterior significa:

#### Relaciones:

| Objetos | Cardinalidad |
| --- | --- |
| ENDPOINT / AOR | muchos a muchos |
| ENDPOINT / AUTH | cero a muchos, a cero a uno |
| ENDPOINT / IDENTIFY | cero a uno |
| ENDPOINT / TRANSPORT | cero a muchos, a al menos uno |
| REGISTRATION / AUTH | cero a muchos, a cero a uno |
| REGISTRATION / TRANSPORT | cero a muchos, a al menos uno |
| AOR / CONTACT | muchos a muchos |

ACL y DOMAIN_ALIAS no tienen una relación de configuración directa con los otros objetos.

### Configuración de un softphone

Para configurar un softphone debe definir muchas secciones diferentes. A continuación, un ejemplo de cómo configurar un softphone. Para el lado del cliente puede usar el SipPulse Softphone (https://www.sippulse.com/produtos/softphone), que puede descargar y registrar contra el endpoint a continuación.

```
[transport-udp-main]
type=transport
protocol=udp
bind=0.0.0.0:5060
[softphone]
type=endpoint
transport=transport-udp-main
context=from-internal
disallow=all
allow=ulaw
aors=softphone
auth=softphone
[softphone]
type=auth
auth_type=digest
username=softphone
password=#supersecret#
[softphone]
type=aor
max_contacts=2
```

La configuración anterior establece un transporte para UDP en el puerto 5060, luego define un endpoint, su autenticación por nombre de usuario y contraseña, y luego la Address of Record con un máximo de dos contactos.

### Configuración de un trunk SIP

Para configurar un trunk SIP necesita tener la dirección IP o el host del trunk SIP, el nombre y la contraseña. Debe crear una nueva sección de registro para este propósito.

```
[siptrunk]
type=endpoint
transport=transport-udp-main
context=from-siptrunk
direct_media=no
disallow=all
allow=ulaw
outbound_auth=siptrunk
aors=siptrunk
[siptrunk]
type=aor
contact=sip:sip.flagonc.com:5600
[siptrunk]
type=auth
auth_type=digest
username=1020
password=supersecret
[siptrunk]
type=registration
outbound_auth=siptrunk
server_uri=sip:1020@sip.flagonc.com:5600
client_uri=sip:1020@sip.flagonc.com
contact_user=9999
[siptrunk]
type=identify
endpoint=siptrunk
match=sip.flagonc.com
```

### Recorrido de NAT en res_pjsip

Network Address Translation se creó hace mucho tiempo como una forma de lidiar con la escasez de direcciones IP versión 4. Muchas personas también usan NAT como una característica de seguridad que oculta las direcciones internas de una red de la Internet pública. A veces tendrá que manejar el recorrido de NAT. En algunos casos, el servidor puede estar detrás de NAT, como cuando está implementando el servidor en la nube. Muchas veces, si está implementando en la nube, sus usuarios también estarán detrás de un router NAT. Para organizar las cosas, dividiremos esto en dos partes. La primera es el servidor Asterisk detrás de NAT, como en una implementación en la nube. En la segunda sección, cubriremos cómo admitir clientes detrás de NAT usando res_pjsip.

#### Servidor Asterisk detrás de NAT

Cuando el servidor Asterisk está detrás de NAT, debe informar las direcciones locales externas e internas en la sección de transporte. Tendremos las siguientes directivas.

##### direct_media

¿El flujo de medios va directamente de par a par o a través del servidor? Para NAT debería fluir a través del servidor. Para NAT seleccione no. Ejemplo:

```
direct_media=no
```

##### external_media_address

Dirección de medios para manejar RTP externo. Por lo general, es la misma que la external_signaling_address. Use la dirección IP pública de su servidor para medios y señalización. Ejemplo:

```
external_media_address=54.232.1.20
```

##### external_signaling_address

Dirección SIP externa donde recibir mensajes. Ejemplo:

```
external_signaling_address=54.232.1.20
```

##### local_net

La red que considera su red local. Ejemplo:

```
local_net=172.16.30.0/24
local_net=127.0.0.1/32
```

#### Ejemplo completo de transporte para un servidor Asterisk detrás de NAT

Para usar un servidor Asterisk detrás de NAT debe realizar dos pasos. Primero, definir un transporte detrás de NAT. Dos, asociar este transporte al endpoint.

##### Creación del transporte detrás de NAT

Para crear el transporte detrás de NAT en el archivo pjsip.conf, cree una sección como la siguiente.

```
[tnat]
type=transport
protocol=udp
bind=0.0.0.0
local_net=172.16.30.0/24
local_net=127.0.0.1/32
external_media_address=54.232.1.20
external_signaling_address=54.232.1.20
```

Asocie el transporte a un endpoint

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
auth=6000
aors=6000
```

Para trunks SIP también debe asociar el transporte a la sección de registro como se muestra a continuación.

```
[siptrunk_reg]
type=registration
transport=tnat
server_uri=sip:sip.flagonc.com:5600
outbound_auth=siptrunk_auth
client_uri=sip:23456789@flagonc.com
contact_user=9999
```

#### Uso de Asterisk con clientes detrás de NAT

Para usar teléfonos detrás de NAT debe configurar algunos parámetros adicionales por endpoint.

##### direct_media

¿El flujo de medios va directamente de par a par o a través del servidor? Para NAT debería fluir a través del servidor. Ejemplo:

```
direct_media=no
```

##### rtp_symmetric

Esto es lo que llamamos comedia. En lugar de confiar en la dirección definida en este encabezado SDP como es habitual en SIP, use la dirección desde donde recibe el primer paquete rtp y envíe de vuelta desde la misma dirección. Ejemplo:

```
rtp_symmetric=yes
```

##### force_rport

Este es el comportamiento definido en el RFC3581. En lugar de usar la dirección en el encabezado VIA, envíe las respuestas de vuelta desde donde provienen las solicitudes. Ejemplo:

```
force_rport=yes
```

##### qualify_frequency

Este ajuste debe aplicarse al AOR (no al endpoint). También está el último paso, configurar la opción qualify. Siempre debe tener algunos paquetes haciendo ping al destino para mantener abierta la asignación de NAT. Esto se establece en la sección AOR. Ejemplo:

- qualify_frequency=15

Ejemplo completo de un endpoint donde el servidor y el cliente están detrás de NAT

```
[6000]
type=endpoint
transport=tnat
context=from-internal
direct_media=no
force_rport=yes
rtp_symmetric=yes
auth=6000
aors=6000
[6000]
type=aor
qualify_frequency=15
```

### Nomenclatura de canales

Como es habitual, uno de los aspectos importantes de un canal es su nomenclatura y PJSIP tiene algunos detalles interesantes. Usted marca un endpoint PJSIP con la tecnología `PJSIP/`:

```
exten=>6000,1,Dial(PJSIP/6000,20,tT)
```

Una característica útil es la posibilidad de marcar todos los contactos registrados en un AOR a la vez. La función PJSIP_DIAL_CONTACTS se traducirá a la lista de contactos para marcar.

```
exten=>6000,1,Dial(${PJSIP_DIAL_CONTACTS(6000)},20,tT)
```

Marcar un trunk es ligeramente diferente. Suponga que el trunk no se registrará en su plataforma o no tiene una dirección IP asociada con su AOR address of record. Puede especificar la dirección del trunk directamente en la línea. Usando una marcación internacional como ejemplo.

```
exten=>9011.,1,Dial(PJSIP/siptrunk/sip:${EXTEN:1}@sip.flagonc.com)
```

Si prefiere especificar la dirección del trunk en la sección AOR, también puede usar.

```
exten=>9011.,1,Dial(PJSIP/${EXTEN:1}@siptrunk)
```

### Asistente de configuración de PJSIP

PJSIP es potente pero detallado de configurar: muchas secciones diferentes y plantillas que pueden resultar confusas al principio. La buena noticia es el asistente de configuración de PJSIP. Al definir cada canal en unas pocas líneas, le permite crear plantillas y simplificar la configuración de nuevos dispositivos. Use el archivo pjsip_wizard.conf para configurar. Todavía debe definir las secciones de transporte y globales en el archivo pjsip.conf. Personalmente, prefiero usar el asistente solo para teléfonos; para trunks SIP, por lo general, el número no es grande y puede configurar directamente en pjsip. La mayor ventaja del asistente es la posibilidad de usar plantillas y crear teléfonos rápidamente.

```
[phone_default](!)
type = wizard
accepts_auth = yes
accepts_registrations = yes
transport = tnat
endpoint/allow = ulaw
endpoint/context = from-internal
endpoint/direct_media=no
endpoint/force_rport=yes
endpoint/rtp_symmetric=yes
aor/qualify_frequency=15
[alice](phone_default)
inbound_auth/username = alice
inbound_auth/password = supersecret
[bob](phone_default)
inbound_auth/username = bob
inbound_auth/password = supersecret
```

### Carga y descarga de PJSIP

PJSIP es el único canal SIP en Asterisk 22, y sus módulos se cargan de forma predeterminada. En casos raros, es posible que aún desee controlar la carga de módulos desde el archivo modules.conf; por ejemplo, para deshabilitar PJSIP en un servidor que solo usa IAX2 o DAHDI.

#### Para deshabilitar PJSIP

Edite el archivo modules.conf y agregue las siguientes líneas.

```
noload => res_pjsip.so
noload => res_pjsip_pubsub.so
noload => res_pjsip_session.so
noload => chan_pjsip.so
noload => res_pjsip_exten_state.so
```

### Comandos de consola

Ahora que configuró sus endpoints PJSIP, es hora de ver cómo verificar su configuración. Hay muchos comandos de consola para ayudarlo con esta tarea. Después de editar pjsip.conf, recargue la configuración con:

```
module reload res_pjsip.so
```

Un simple `reload` (o `core reload`) recarga todos los módulos, incluido PJSIP. (Tenga en cuenta que no existe un comando `pjsip reload` puro; `pjsip reload` solo existe en la forma `pjsip reload qualify aor|endpoint`). Puede listar todos los comandos de consola de PJSIP disponibles con `help pjsip`.

#### pjsip show endpoints

Este comando muestra los endpoints disponibles. En la imagen a continuación, tenemos una captura de pantalla. Puede ver la dirección del endpoint del softphone y ver que está disponible.

![Salida de `pjsip show endpoints` listando los endpoints blink, siptrunk y softphone con su AOR, auth, transporte y disponibilidad: el contacto del softphone está registrado (Avail)](../images/07-sip-and-pjsip-fig15.png)

#### pjsip show endpoint <endpoint>

Con el comando anterior, puede ver cada parámetro del endpoint. La lista a continuación se cortó a menos de la mitad de los parámetros actuales.

![Salida de `pjsip show endpoint softphone` mostrando la lista completa de parámetros para un solo endpoint, desde 100rel y allow=(ulaw) hasta callerid y connected_line_method](../images/07-sip-and-pjsip-fig16.png)

#### pjsip show aors

Este comando lista los objetos Address of Record configurados y sus contactos, para que pueda confirmar a dónde enviará Asterisk las llamadas para cada endpoint.

#### pjsip show registrations

El comando a continuación muestra los registros realizados por nuestro propio servidor.

![Salida de `pjsip show registrations`: el registro saliente siptrunk/sip:1020@sip.flagonc.com:5600 se muestra con estado Registered](../images/07-sip-and-pjsip-fig17.png)

#### pjsip list

El comando list es un poco más amigable y muestra menos datos, pero mejor estructurados. Listando endpoints:

![Salida de `pjsip list endpoints`: un listado compacto de una línea por endpoint (blink, siptrunk, softphone) con su estado y conteo de canales](../images/07-sip-and-pjsip-fig18.png)

Listando contactos:

![Salida de `pjsip list contacts` mostrando los URI de contacto de siptrunk y softphone con su hash y estado de qualify](../images/07-sip-and-pjsip-fig19.png)

#### pjsip set logger on

El comando de solución de problemas más útil es el registrador de paquetes SIP. Imprime cada solicitud y respuesta SIP en la consola a medida que se envía o recibe, lo cual es invaluable al diagnosticar problemas de registro y configuración de llamadas.

```
pjsip set logger on
pjsip set logger off
```

También puede restringir el registro a un solo host con `pjsip set logger host <ip>`.

#### pjsip set history on

Una gran adición a PJSIP es el concepto de historial. Puede capturar y analizar solicitudes y respuestas SIP en tiempo real de una manera sencilla. Para iniciar el historial, use el comando a continuación.

![Ejecutar `pjsip set history on` devuelve "PJSIP History enabled"](../images/07-sip-and-pjsip-fig20.png)

Ahora puede mostrar el historial:

![Salida de `pjsip show history`: una tabla numerada de mensajes SIP capturados (REGISTER, 401 Unauthorized, REGISTER, 200 OK) con marcas de tiempo, dirección y destino](../images/07-sip-and-pjsip-fig21.png)

Luego, para ver una solicitud o respuesta específica, muestre el elemento del historial:

![Salida de `pjsip show history entry`: el texto completo de un solo mensaje SIP capturado (aquí la respuesta `404 Not Found` de Asterisk 22 a una sonda OPTIONS), mostrando los encabezados Via (con `rport`/`received`), Call-ID, From, To y CSeq, las capacidades `Allow`/`Supported` y el encabezado `Server: Asterisk PBX 22.10.0`](../images/07-sip-and-pjsip-fig22.png)

Muy fácil, ¿verdad? También puede borrar el historial cuando lo desee usando `pjsip set history clear`.

> **¿Migrando un sistema existente chan_sip/sip.conf?** El controlador heredado `chan_sip`
> y una **guía completa de migración de sip.conf a pjsip.conf** (incluida la
> tabla de mapeo de conceptos y el script de conversión `sip_to_pjsip.py`) se cubren
> en el capítulo *Legacy channels*.

## Resumen

SIP es el protocolo de señalización de la IETF que establece, modifica y finaliza sesiones de medios. Sus agentes de usuario, proxies, registradores y gateways intercambian mensajes basados en texto — REGISTER, INVITE, las respuestas provisionales y finales, ACK y BYE — mientras que SDP negocia los codec y RTP transporta los medios. Esa teoría del protocolo es atemporal y se aplica a cualquier implementación de SIP.

En Asterisk 22 usted utiliza SIP a través de **PJSIP** (`chan_pjsip`), configurado en `pjsip.conf`. En lugar de un peer monolítico, un dispositivo se modela como un conjunto de objetos pequeños con referencias cruzadas: `endpoint` (comportamiento de llamada y codec), `auth` (credenciales), `aor` (dónde es alcanzable) y `transport` (el listener), además de `identify` (coincidencia de un trunk por IP) y `registration` (registro saliente) para proveedores de servicios. Usted vio cómo estos objetos encajan entre sí, cómo configurar tanto teléfonos como trunks, cómo las opciones de NAT-traversal (`force_rport`, `rewrite_contact`, `rtp_symmetric`, `direct_media` y los `external_*`/`local_net` del transporte) resuelven despliegues del mundo real, y cómo inspeccionar todo esto con `pjsip show endpoints`, `aors`, `contacts` y `registrations`.

## Cuestionario

1. En la arquitectura SIP, ¿qué componente recibe una solicitud y la responde con una respuesta de redirección (como `302 Moved Temporarily`) que contiene la nueva ubicación, para luego mantenerse fuera de la ruta de los mensajes de seguimiento?
   - A. Proxy server
   - B. Redirect server
   - C. Location server
   - D. Registrar

2. ¿Qué papel desempeña Asterisk cuando gestiona una llamada SIP entre dos teléfonos?
   - A. Un SIP proxy que permanece solo en la ruta de señalización
   - B. Un SIP redirect server
   - C. Un back-to-back user agent (B2BUA) que puentea dos canales SIP
   - D. Un SIP load balancer sin estado

3. ¿Qué método SIP utiliza un teléfono para informar al registrar su dirección IP actual y así poder recibir llamadas posteriormente?
   - A. INVITE
   - B. OPTIONS
   - C. SUBSCRIBE
   - D. REGISTER

4. Verdadero o Falso: En Asterisk 22, `chan_sip` y `sip.conf` siguen estando disponibles como alternativa heredada junto a PJSIP.

5. ¿Con qué objetos de configuración debe estar asociado un endpoint para que Asterisk sepa qué socket de escucha utilizar y a dónde enviar las llamadas para ese dispositivo? (Elija todas las que correspondan.)
   - A. `type=transport`
   - B. `type=aor`
   - C. `type=identify`
   - D. `type=registration`

6. En un objeto PJSIP `aor`, ¿qué configuración mantiene abierta la asignación NAT mediante la calificación periódica del contacto y cuál es su unidad?
   - A. `qualify=yes` (booleano)
   - B. `qualify_frequency` (segundos)
   - C. `rtp_timeout` (milisegundos)
   - D. `nat=force_rport`

7. Complete el espacio en blanco: Para hacer que Asterisk haga coincidir una solicitud SIP entrante con un endpoint específico mediante la dirección IP de origen (en lugar de mediante el encabezado `From`), debe crear una sección con `type=________`.

8. ¿Qué objeto PJSIP se utiliza para configurar un registro **saliente** desde Asterisk hacia un proveedor de trunk SIP?
   - A. `type=aor`
   - B. `type=identify`
   - C. `type=registration`
   - D. `type=auth`

9. En la CLI de Asterisk 22, ¿qué comando habilita el registrador de paquetes SIP que imprime cada solicitud y respuesta SIP en la consola?
   - A. `sip set debug on`
   - B. `pjsip set logger on`
   - C. `pjsip debug on`
   - D. `sip show registry`

10. En un endpoint PJSIP que sirve a un teléfono detrás de un NAT simétrico, ¿qué par de configuraciones hace que Asterisk responda a la dirección de origen de la solicitud (RFC 3581) y envíe los medios de vuelta a donde realmente llega el RTP?
    - A. `direct_media=yes` y `srvlookup=yes`
    - B. `force_rport=yes` y `rtp_symmetric=yes`
    - C. `allowguest=yes` y `insecure=invite`
    - D. `qualify=yes` y `nat=no`

**Respuestas:** 1 — B · 2 — C · 3 — D · 4 — Falso · 5 — A, B · 6 — B · 7 — identify · 8 — C · 9 — B · 10 — B
