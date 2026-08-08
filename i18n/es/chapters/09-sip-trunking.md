# SIP trunking, DID & the PSTN

Un PBX que solo puede llamarse a sí mismo no es muy útil. Tarde o temprano, todo sistema tiene que llegar al resto del mundo: la PSTN, un proveedor SIP u otro PBX. El enlace que transporta esas llamadas es un **trunk**. En la era TDM, un trunk era un circuito físico: un T1/E1 PRI o un conjunto de líneas analógicas FXO. Hoy en día, casi siempre es un **SIP trunk**: una conexión lógica a un Internet Telephony Service Provider (ITSP) que se transmite a través de la misma red IP que todo lo demás.

Este capítulo muestra cómo conectar Asterisk 22 a un ITSP con PJSIP, cómo elegir entre un trunk basado en registro y uno basado en IP, cómo enrutar números DID entrantes al destino correcto, cómo enviar llamadas salientes con el caller-ID correcto y formato E.164, y cómo construir failover y enrutamiento de menor costo a través de varios trunks. Terminamos con el manejo de NAT para trunks y un laboratorio que levanta un segundo Asterisk (y SIPp) como un ITSP simulado para que pueda realizar llamadas reales a través de un trunk.

Todo lo que se presenta aquí está verificado con el laboratorio de Asterisk 22.10.0 del libro; el patrón de objeto trunk es el mismo que se introdujo en *Building your first PBX with PJSIP* y *SIP & PJSIP in depth*.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Conectar Asterisk 22 a un ITSP con PJSIP
- Elegir entre trunks basados en registro y basados en IP (estáticos)
- Enrutar DID entrantes a la extension, IVR o cola correcta
- Enrutar llamadas salientes con el caller-ID correcto y formato E.164
- Construir failover de trunks y enrutamiento de menor costo con `${DIALSTATUS}`
- Manejar NAT para trunks en el transport y el endpoint

## Qué es un SIP trunk

Un SIP trunk es una ruta de voz lógica entre su PBX y otro sistema SIP. En la práctica, ese "otro sistema" es una de dos cosas:

- **Un ITSP (Internet Telephony Service Provider).** Un operador comercial que le vende originación y terminación de llamadas y, por lo general, un bloque de números telefónicos (DIDs). Usted apunta Asterisk al host de señalización del proveedor, y el proveedor conecta sus llamadas a la PSTN más amplia. Así es como la mayoría de los sistemas modernos llegan a la red telefónica; no se requiere hardware de telefonía.
- **Un gateway PSTN.** Un dispositivo (u otro Asterisk) que tiene interfaces físicas PSTN —una tarjeta PRI, puertos FXO analógicos o un gateway GSM/4G— y los presenta a su PBX como SIP. El gateway realiza la conversión de TDM a SIP; desde el punto de vista de Asterisk, es simplemente otro SIP trunk.

De cualquier manera, en PJSIP un trunk es **simplemente un endpoint**. La misma familia de objetos que utilizó para un teléfono — `endpoint`, `auth`, `aor`, opcionalmente `identify` y `registration` — construye un trunk. Las diferencias están en los detalles: un trunk se autentica de forma *saliente* (usted es el cliente, por lo que las credenciales van en `outbound_auth`, no en `auth`), por lo general no registra un user agent ante usted (usted se registra ante *él*, o este le envía tráfico desde una IP conocida), y aterriza las llamadas entrantes en un context dedicado como `from-pstn` en lugar de `from-internal`.

> **Comparado con el antiguo trunk TDM.** Una PRI le daba un número fijo de canales B (23 en una T1, 30 en una E1) y señalizaba el establecimiento de llamadas a través de un canal D dedicado (vea el capítulo *Legacy channels*). Un SIP trunk no tiene un conteo de canales fijo; la capacidad es lo que permitan su ancho de banda, la política de su proveedor y cualquier límite de `max_contacts`/concurrent-call. El Caller-ID, DID y el progreso de llamada que solían viajar en los elementos de información ISDN ahora viajan en los encabezados SIP y SDP.

Existen dos formas en las que un ITSP aceptará intercambiar tráfico con usted, y estas determinan cómo construye el trunk: **basado en registro** y **basado en IP (estático)**. Cubrimos cada uno a continuación.

## Trunks basados en registro

Un trunk basado en registro es el modelo utilizado cuando el proveedor espera que *usted* inicie sesión en *ellos*. Su Asterisk envía periódicamente un SIP `REGISTER` al proveedor, autenticándose con un nombre de usuario y contraseña, exactamente de la misma manera que un teléfono se registra en su PBX. Esto es común cuando su IP pública es dinámica, cuando se encuentra detrás de NAT, o cuando el proveedor simplemente identifica a los clientes mediante credenciales SIP en lugar de por dirección IP.

En PJSIP, el inicio de sesión saliente reside en un objeto `registration` dedicado. Reemplaza la línea única `register =>` que el controlador eliminado `chan_sip` utilizaba en `sip.conf`. Aquí hay un trunk de registro completo hacia un proveedor ficticio, siguiendo el patrón verificado de los capítulos anteriores — observe `outbound_auth` (no `auth`), `server_uri`/`client_uri` (no `server`/`client`), `from_user`/`from_domain` en el endpoint, y `dtmf_mode=rfc4733`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-auth]
type=auth
auth_type=digest
username=4830001000
password=Lab-itsp-secret

[itsp-aor]
type=aor
contact=sip:itsp.example.com:5060

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:itsp.example.com:5060
client_uri=sip:4830001000@itsp.example.com:5060
contact_user=4830001000
retry_interval=60
```

Algunas cosas a tener en cuenta:

- **`auth_type=digest`, no `userpass`.** Ambos producen la misma autenticación digest, pero en Asterisk 22 `userpass` (y el antiguo `md5`) están **obsoletos y se convierten silenciosamente a `digest`**. Prefiera `digest` en configuraciones nuevas; todavía verá `userpass` en archivos antiguos y en los capítulos anteriores de este libro.
- **`outbound_auth` tanto en el endpoint como en el registro.** El registro lo utiliza para autenticar el `REGISTER`; el endpoint lo utiliza para responder al `407 Proxy Authentication Required` que el proveedor envía de vuelta a un `INVITE` saliente. Pueden compartir un objeto `auth`.
- **`from_user` / `from_domain`.** Muchos proveedores rechazan llamadas cuyo encabezado `From` no contiene su número de cuenta y su dominio. Estas dos opciones configuran exactamente eso.
- **`contact_user=4830001000`.** Esto se convierte en la parte de usuario del `Contact` que usted registra, para que el proveedor sepa a qué número entregar las llamadas entrantes. Es el equivalente moderno del sufijo `/9999` en la antigua línea `register =>`.
- **`retry_interval=60`.** Si el registro falla, reintente cada 60 segundos.

Después de una recarga, confirme el registro con `pjsip show registrations`. En el laboratorio — donde `itsp.example.com` en realidad no responde — la tabla se ve así:

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

El sufijo `(exp. Ns)` cuenta regresivamente los segundos hasta el próximo intento; una vez que llega a cero, muestra brevemente `(exp. Ns ago)` antes de que se dispare el reintento. Frente a un proveedor real, la columna `Status` muestra `Registered` con los segundos restantes hasta la próxima actualización. `Rejected` (o `Unregistered`) significa que el proveedor no aceptó el inicio de sesión — active `pjsip set logger on` y lea la respuesta `401`/`403`, casi siempre un nombre de usuario, contraseña o dominio `client_uri` incorrecto.

## Trunks basados en IP (estáticos)

El segundo modelo no requiere ningún tipo de registro. El proveedor conoce su dirección IP pública y envía las llamadas directamente a ella; usted, a su vez, envía las llamadas a la IP de señalización conocida del proveedor. La autenticación se realiza mediante la **dirección IP de origen**, no mediante credenciales SIP. Esto es típico para trunks entre dos servidores que usted controla, o para un trunk empresarial donde ambos lados tienen direcciones estáticas.

El objeto clave es `identify`. Le indica a Asterisk: "cualquier solicitud SIP que llegue desde *esta* IP pertenece a *ese* endpoint". Sin él, PJSIP intenta hacer coincidir una solicitud entrante con un endpoint mediante el usuario `From`, lo cual el tráfico de un operador no satisfará, por lo que la llamada sería rechazada o caería en el endpoint `anonymous`.

Un trunk estático elimina el objeto `registration` y añade `identify`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-aor]
type=aor
contact=sip:203.0.113.10:5060

[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
```

`match` acepta una dirección IP, un rango CIDR o un nombre de host. **Los nombres de host se resuelven una sola vez, al momento de cargar la configuración**, por lo que si la IP de su proveedor cambia, debe recargar. Para un operador que publica varias gateways de medios, enumere cada IP de señalización; puede repetir `match` o proporcionar un CIDR:

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

Verifique lo que Asterisk aceptará con `pjsip show identifies`. Capturado desde el laboratorio (la línea `sipp-identify` es el endpoint SIPp preexistente del laboratorio):

```
*CLI> pjsip show identifies

 Identify:  <Identify/Endpoint...........................................................>
      Match:  <criteria...........................>
==========================================================================================

 Identify:  itsp-identify/itsp
      Match: 172.30.0.50/32

 Identify:  sipp-identify/sipp
      Match: 172.30.0.0/24

Objects found: 2
```

### La implicación de seguridad

Un trunk basado en IP sin autenticación es una puerta, y `identify`/`match` es el único cerrojo en ella. Si usted `match` un rango demasiado amplio —o si un atacante puede suplantar una IP de origen— las llamadas aterrizan en su context `from-pstn` sin autenticación. Dos defensas, utilizadas en conjunto:

- **Haga coincidir de la manera más estricta posible.** Prefiera IPs de host específicas sobre CIDRs amplios. Solo las IPs de señalización reales del proveedor deben estar en `match`.
- **Combínelo con una ACL.** PJSIP puede descartar tráfico en la capa SIP antes de que llegue a un endpoint, utilizando un objeto `type=acl` (o `acl.conf`):

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

Una sección `type=acl` no necesita referencia: `res_pjsip_acl` aplica cada objeto de este tipo a *todo* el tráfico SIP entrante antes de que llegue a cualquier endpoint. (Las opciones `acl` y `contact_acl` en el objeto extraen listas de reglas con nombre desde `acl.conf` en lugar de listar `permit`/`deny` en línea como se mostró arriba). El principio es el mismo que en el capítulo de SIP: denegar todo, luego permitir solo lo que usted confía. Y sin importar lo que haga su context de trunk, **nunca permita que llegue a un context que pueda marcar hacia afuera a la PSTN** sin una regla deliberada y autenticada; ese es el clásico agujero de fraude telefónico.

> **¿Qué modelo debo usar?** Si el proveedor le proporciona un nombre de usuario y contraseña, use un trunk de **registro**. Si le piden su dirección IP y le dan la suya, use un trunk de **identificación**. Algunos proveedores admiten ambos; muchos trunks reales combinan un registro (para que el proveedor pueda encontrarlo) con una identificación (para que los INVITE entrantes de las gateways de medios del proveedor coincidan incluso cuando llegan desde una IP distinta a la del registrador).

## Enrutamiento de llamadas entrantes y manejo de DID

Una vez que las llamadas entrantes llegan, aterrizan en el `context` del endpoint — aquí
`from-pstn`. Un **DID** (número de marcación directa hacia adentro) es simplemente el número marcado
que el proveedor le entrega en el URI de solicitud. Su trabajo en el dialplan es asignar cada
DID a un destino: una extensión única, un IVR, una cola o un grupo de llamada.

El número que envía el proveedor se compara como `${EXTEN}` en `from-pstn`. Qué tanto de
él usted ve depende del proveedor — algunos envían el número E.164 completo
(`+4830001000`), algunos envían el número nacional, algunos envían solo los últimos
dígitos. Inspeccione una llamada entrante real con `pjsip set logger on` y observe el
URI de solicitud antes de escribir patrones.

### Un DID a una extensión

El caso más simple — un solo DID enrutado directamente a un teléfono:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### Un DID a un IVR (operadora automática)

Un número principal que debe responder con un menú en lugar de hacer sonar un teléfono:

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` es el context de operadora automática que construyó en los capítulos de dialplan
(`Background()` + `WaitExten()`). Enrutar el DID es solo un `Goto`.

### Un DID a una cola

Una línea de soporte que debe aterrizar en una cola de llamadas:

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### Muchos DIDs a la vez

Cuando usted compra un bloque de números, un patrón mantiene el dialplan pequeño. Suponga que su
rango de DID es `4830003000`–`4830003099` y el proveedor envía el número completo; asigne
los últimos dos dígitos de cada DID a la extensión `60xx`:

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}` toma los últimos dos dígitos (el desplazamiento negativo cuenta desde la derecha),
así que `4830003007` hace sonar `PJSIP/6007`. Una tabla de búsqueda `did => extension` construida con
`GoSub` o una base de datos de Asterisk (`AstDB`/`func_odbc`) escala aún más, pero para
un puñado de números los patrones explícitos son los más claros.

> **Capture el DID no coincidente.** Agregue una extensión `i` (inválida) a `from-pstn` para que un
> número entrante mal enrutado reproduzca un anuncio o llame a la operadora en lugar de
> desconectarse silenciosamente:
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## Enrutamiento de salida, caller-ID y E.164

Las llamadas salientes fluyen en la dirección opuesta: un teléfono interno marca un número, su dialplan lo hace coincidir, elimina cualquier prefijo de acceso, establece el caller-ID que el proveedor espera y entrega la llamada al endpoint del trunk con `Dial(PJSIP/<number>@itsp)`.

### Envío de la llamada al trunk

La sintaxis de canal para un trunk es `PJSIP/<number>@<endpoint>`: la parte antes del
`@` se convierte en la porción de usuario del URI de solicitud saliente, y la parte después del
`@` nombra al endpoint cuyo `aor` `contact` proporciona el host de destino. Una regla clásica de "marque 9 para una línea externa":

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` elimina el código de acceso `9` inicial antes de que se envíe el número. El patrón `_9NXXXXXXXXX` coincide con `9` más un número de 10 dígitos cuyo primer dígito es 2–9; ajústelo a su dialplan.

### Caller-ID en llamadas salientes

La mayoría de los ITSP ignoran —o rechazan activamente— un caller-ID que no sea un número de su propiedad. Establezca el número de caller-ID saliente a uno de sus DID con la función `CALLERID(num)` antes de `Dial()`, como se muestra arriba. También puede establecer el nombre:

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

Si el proveedor aún elimina o sobrescribe su nombre de caller-ID, esa es su política; muchos operadores obtienen el nombre mostrado de su propia base de datos CNAM indexada por el número, no de su encabezado `From`.

Dos opciones de endpoint interactúan con esto:

- **`from_user`** establece la parte de usuario del encabezado `From` a nivel SIP, que algunos proveedores utilizan para identificar su cuenta independientemente del `CALLERID(num)`.
- **`trust_id_outbound`** (predeterminado `no`) controla si Asterisk enviará encabezados de identidad sensibles a la privacidad (`P-Asserted-Identity`/`P-Preferred-Identity`) de forma saliente. Déjelo desactivado a menos que su proveedor documente que requiere PAI, en cuyo caso establezca `trust_id_outbound=yes` y `send_pai=yes`.

### Normalización a E.164

E.164 es el formato de número internacional: un `+` inicial, código de país, luego el número nacional, sin espacios ni puntuación (por ejemplo, `+5548999990000` o `+14155550100`). Los operadores esperan —o requieren— cada vez más E.164 en el trunk. En lugar de dispersar el formato por todo el dialplan, normalice una vez en el context de salida.

Un ejemplo norteamericano que acepta un número local de 10 dígitos, un número de 11 dígitos con prefijo `1`, o un número que ya está en formato E.164, y siempre presenta `+1…` al trunk:

```
[from-internal]
; 10-digit local: 4155550100  -> +14155550100
exten => _NXXNXXXXXX,1,Set(E164=+1${EXTEN})
 same =>            n,Goto(send-pstn,${E164},1)

; 11-digit with national prefix: 14155550100 -> +14155550100
exten => _1NXXNXXXXXX,1,Set(E164=+${EXTEN})
 same =>             n,Goto(send-pstn,${E164},1)

; already E.164: the user dialled + first
exten => _+X.,1,Goto(send-pstn,${EXTEN},1)

[send-pstn]
exten => _+X.,1,Set(CALLERID(num)=+14155550000)
 same =>     n,Dial(PJSIP/${EXTEN}@itsp,60,tT)
 same =>     n,Hangup()
```

Algunos proveedores quieren el `+`; otros quieren solo los dígitos. Si el suyo rechaza el `+`, elimínelo al salir con `${EXTEN:1}` en el `Dial`. El punto es que todo el conocimiento sobre el formato reside en un solo lugar, por lo que cambiar de proveedor —o agregar uno segundo— es un cambio de una sola línea.

## Failover y enrutamiento de menor costo

Con un solo trunk, una interrupción del proveedor significa que no hay llamadas salientes. Con dos o más, puede realizar una conmutación por error (failover) automáticamente e incluso elegir la ruta más económica por destino: *least-cost routing* (LCR).

### Failover con `${DIALSTATUS}`

`Dial()` establece la variable de canal `${DIALSTATUS}` cuando regresa. Los valores que le interesan para el failover son `CHANUNAVAIL` (el trunk no pudo ser alcanzado en absoluto) y `CONGESTION` (la llamada fue rechazada, por ejemplo, todos los circuitos ocupados). Intente con el trunk principal; si no pudo completar la llamada, pase al respaldo:

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

Note la elección deliberada de **no** realizar un failover en `BUSY` o `NOANSWER`; esos significan que la *parte llamada* fue alcanzada y declinó, por lo que reintentar en otro trunk volvería a llamar a un teléfono que ya dijo que no (y podría costarle una segunda llamada). Solo re-enrute cuando el *trunk mismo* haya fallado.

### Una subrutina de enrutamiento reutilizable

Repetir esa lógica para cada patrón de marcado es propenso a errores. Factorícelo en una rutina `GoSub` que tome el número de destino e intente cada trunk en orden:

```
[from-internal]
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Set(CALLERID(num)=4830001000)
 same =>   n,Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try2:end)
 same =>   n(try2),Dial(PJSIP/${NUM}@itsp_backup,60,tT)
 same =>   n(try2-chk),GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try3:end)
 same =>   n(try3),Dial(PJSIP/${NUM}@itsp_thirdparty,60,tT)
 same =>   n(end),Return()
```

Ahora, cada patrón de salida es una llamada `GoSub`, y el orden del trunk se define en un solo lugar.

### Enrutamiento de menor costo por destino

El LCR real elige el trunk según hacia dónde va la llamada. Una forma común es hacer coincidir el prefijo de destino y enviar cada clase de llamada al proveedor que sea más barato para ella; por ejemplo, llamadas internacionales a un operador mayorista y llamadas locales/nacionales a su principal:

```
[from-internal]
; international (011 + ...) -> wholesale trunk, then fall back to primary
exten => _9011.,1,GoSub(dialout-intl,s,1(${EXTEN:1}))
 same =>      n,Hangup()
; everything else -> domestic routing
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout-intl]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Dial(PJSIP/${NUM}@itsp_wholesale,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?fb:end)
 same =>   n(fb),Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n(end),Return()
```

Para más de unos pocos prefijos, almacene la tabla de rutas en una base de datos (`func_odbc`/`AstDB`) y busque el trunk por prefijo en lugar de codificar patrones. El dialplan se mantiene pequeño y las tarifas residen en una tabla que puede editar sin recargar la lógica.

## NAT y trunks

NAT es la causa más común de problemas en los trunks; típicamente audio unidireccional o un trunk que se registra pero nunca recibe llamadas entrantes. La causa es la misma que para los teléfonos (cubierto en *SIP & PJSIP in depth* y *Designing a VoIP network*): Asterisk anuncia su propia idea de su dirección en SIP y SDP, y detrás de NAT esa es una dirección privada RFC 1918 a la que el proveedor no puede enrutar de vuelta.

Para los trunks, la solución tiene dos partes: configuraciones en el **transport** (su dirección pública) y configuraciones en el **endpoint** (cómo tratar los medios del proveedor).

### En el transport: su dirección pública

Cuando el servidor Asterisk está detrás de NAT (una caja en la nube o local con una IP privada y una IP pública 1:1), dígale al transport su dirección pública y qué redes son locales. Estas opciones se configuran una vez, en el `transport`, y se aplican a todo el tráfico sobre él:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=172.30.0.0/24
local_net=10.0.0.0/8
external_media_address=203.0.113.50
external_signaling_address=203.0.113.50
```

- **`external_signaling_address`** — la IP pública que Asterisk escribe en los encabezados SIP (`Via`, `Contact`) para destinos fuera de `local_net`.
- **`external_media_address`** — la IP pública que Asterisk escribe en la línea `c=` del SDP para que el RTP regrese al lugar correcto. Por lo general, es idéntica a la dirección de señalización.
- **`local_net`** — redes que Asterisk trata como internas, por lo que *no* reescribe las direcciones para los pares de la LAN. Enumere cada subred interna.

### En el endpoint: los medios del proveedor

La otra mitad maneja a un proveedor que a su vez se encuentra detrás de NAT, o simplemente envía medios desde una dirección distinta a la que figura en su SDP. Configure esto por cada endpoint de trunk:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com
```

- **`direct_media=no`** — mantiene los medios fluyendo a través de Asterisk en lugar de permitir que los dos tramos hablen directamente. Es esencial a través de NAT y, de todos modos, es necesario si desea grabar, transcodificar o monitorear la llamada.
- **`rtp_symmetric=yes`** — el comportamiento clásico *comedia*: envía el RTP de vuelta a la dirección desde la que realmente provino el medio, no a la dirección que reclama el SDP.
- **`force_rport=yes`** — responde al SIP desde la IP/puerto de origen de la solicitud (RFC 3581), en lugar de confiar en el encabezado `Via`.
- **`rewrite_contact=yes`** — en mensajes SIP entrantes desde este endpoint, reescribe el encabezado `Contact` (o un encabezado `Record-Route` apropiado) a la dirección IP y puerto de origen desde donde realmente provino el paquete. Según la propia documentación de la opción, esto "ayuda a los servidores a comunicarse con endpoints que están detrás de NATs" y "ayuda a reutilizar conexiones de transporte confiables como TCP y TLS".

> **Recomendación: teléfonos vs trunks.** `rewrite_contact` es casi siempre la opción correcta para los teléfonos, porque su contacto anunciado es típicamente una dirección privada RFC 1918 que no es enrutable de vuelta hacia ellos. En un trunk basado en IP estática, el contacto del proveedor suele ser ya una dirección pública correcta, por lo que reescribirlo a menudo es innecesario; algunos operadores prefieren dejarlo desactivado allí y habilitarlo solo para trunks de registro y teléfonos detrás de NAT. El efecto documentado de la opción es puramente la reescritura de `Contact`/`Record-Route` entrante mencionada arriba; por lo tanto, la práctica segura es probar con su operador específico antes de activarlo en un trunk estático.

Puede confirmar la configuración efectiva en cualquier endpoint con `pjsip show endpoint <name>`: `direct_media`, `rtp_symmetric`, `force_rport`, `rewrite_contact` y el resto se imprimen en el volcado de parámetros.

## Lab — un ITSP simulado con un segundo Asterisk y SIPp

No necesita un trunk de pago para practicar. El laboratorio del libro ya ejecuta un contenedor de Asterisk 22.10.0 y un contenedor de SIPp en una red privada `172.30.0.0/24`; trataremos al contenedor de SIPp como el "operador" que realiza llamadas entrantes y añadiremos un endpoint de trunk que dirige esas llamadas a un context `from-pstn`.

![Un trunk SIP entre el PBX Asterisk y el ITSP: el PBX se registra como una cuenta, las llamadas salientes marcan `PJSIP/<num>@trunk` y las llamadas entrantes aterrizan en el context `from-pstn`.](../images/09-sip-trunking-fig01.png)

### 1. Añadir el endpoint del trunk

Añada un trunk basado en IP a `lab/asterisk/etc/pjsip.conf` que coincida con el host de SIPp del laboratorio y dirija las llamadas entrantes a `from-pstn`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor

[itsp-aor]
type=aor
contact=sip:172.30.0.50:5060

[itsp-identify]
type=identify
endpoint=itsp
match=172.30.0.50
```

### 2. Enrutar el DID entrante

En `lab/asterisk/etc/extensions.conf`, añada un context `from-pstn` que responda al DID que marcará el operador simulado y lo reproduzca, luego añada una regla de salida:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID ${EXTEN} from ${CALLERID(num)})
 same =>             n,Answer()
 same =>             n,Playback(demo-congrats)
 same =>             n,Hangup()
exten => i,1,Playback(ss-noservice)
 same =>  n,Hangup()

[from-internal]
; outbound across the trunk
exten => _9X.,1,Set(CALLERID(num)=4830001000)
 same =>     n,Dial(PJSIP/${EXTEN:1}@itsp,30,tT)
 same =>     n,Hangup()
```

Recargue ambos archivos (`core reload`) y verifique que el trunk se haya cargado:

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. Realizar una llamada entrante a través del trunk

Apunte un escenario de SIPp al PBX con el DID como usuario de destino. El laboratorio ya incluye `lab/sipp/uac_9000.xml`, que envía un INVITE a la extension `9000`; cópielo a `uac_did.xml` y cambie el request-URI/usuario `To` de `9000` a `4830001000`, luego ejecútelo desde el contenedor de SIPp:

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

Observe cómo la llamada llega a `from-pstn` en la consola de Asterisk (`pjsip set logger on` muestra el INVITE entrante; `core show channels` muestra el channel `PJSIP/itsp-…` reproduciendo `demo-congrats`). Debido a que la IP de origen de SIPp coincide con el `identify`, la llamada se acepta sin autenticación, exactamente como se comporta un trunk de operador estático.

### 4. Inspeccionar el trunk

Capture la configuración completa del trunk para sus notas:

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (Desafío) convertirlo en un trunk de registro

Configure el *segundo* contenedor de Asterisk como un registrador real: asígnele un `endpoint`+`auth`+`aor` para la cuenta `4830001000`, luego en el PBX intercambie el bloque `identify` por el bloque `registration` del inicio de este capítulo (apuntando `server_uri` a la IP del segundo contenedor). Confirme con `pjsip show registrations` que el estado indique `Registered`, luego realice una llamada en cada dirección.

## Resumen

Un trunk SIP conecta su PBX con el mundo exterior, y en PJSIP es simplemente un
endpoint construido a partir de la misma familia de `endpoint` + `auth` + `aor` que usted ya conoce,
además de un `identify` o un `registration`. Utilice un **trunk de registro**
(`type=registration` con `outbound_auth`) cuando el proveedor le proporcione un nombre de usuario
y contraseña; utilice un **trunk basado en IP** (`type=identify` con `match`) cuando
la autenticación se realiza mediante la IP de origen — y asegure este último con un `match`
estricto y un `acl`, ya que un trunk sin autenticación es un objetivo para el fraude telefónico. En las llamadas entrantes,
el DID del proveedor llega como `${EXTEN}` en su context `from-pstn`, donde usted
lo enruta a una extension, un IVR o una cola — los patrones y `${EXTEN:-N}` mantienen
los bloques de DID compactos. En las llamadas salientes, configure `CALLERID(num)` con un número que usted posea, normalice
a E.164 en un solo lugar y entregue la llamada a `PJSIP/<number>@trunk`. Construya
resiliencia probando múltiples trunks y ramificando según `${DIALSTATUS}`
(`CHANUNAVAIL`/`CONGESTION` significan re-enrutar; `BUSY`/`NOANSWER` no lo hacen), y coloque
el enrutamiento de menor costo en una tabla `GoSub`. Finalmente, el NAT para trunks es bidireccional:
`external_media_address`/`external_signaling_address`/`local_net` en el
**transport** para su dirección pública, y `direct_media=no`, `rtp_symmetric`,
`force_rport` y `rewrite_contact` en el **endpoint** para los medios del proveedor.

## Cuestionario

1. En PJSIP, las credenciales utilizadas para autenticar una llamada *saliente* o un registro ante un proveedor se referencian con:
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. Usted debería utilizar un trunk `type=registration` cuando:
   - A. El proveedor lo identifica a usted por su dirección IP de origen.
   - B. El proveedor le proporciona un nombre de usuario y una contraseña y espera que usted inicie sesión.
   - C. Usted nunca quiere que Asterisk envíe un `REGISTER`.
   - D. El trunk se encuentra entre dos servidores con IP estática que usted controla.
3. La opción `match` del objeto `identify` acepta (elija todas las que apliquen):
   - A. Una dirección IP
   - B. Un rango CIDR
   - C. Un nombre de host (resuelto al momento de cargar la configuración)
   - D. Solo un nombre de usuario SIP
4. En Asterisk 22, `auth_type=userpass` es:
   - A. El único valor válido
   - B. Obsoleto y convertido a `digest`
   - C. Eliminado y causa un error de carga
   - D. Requerido para el registro saliente
5. Un número DID entrante llega al dialplan como:
   - A. `${CALLERID(num)}`
   - B. `${EXTEN}` en el `context` del endpoint del trunk
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. Para enviar los últimos dos dígitos del DID marcado `4830003007` a una extension, usted usaría:
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. Después de `Dial()` a un trunk, usted debería realizar una conmutación por error (failover) a un trunk de respaldo en el cual `${DIALSTATUS}` valores (elija dos):
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. Para establecer el número de caller-ID presentado al proveedor antes de realizar una llamada saliente, utilice:
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. Las opciones que le indican a Asterisk su dirección *pública* cuando el servidor se encuentra detrás de NAT se configuran en:
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. `rtp_symmetric=yes` en un endpoint de trunk hace que Asterisk:
    - A. Cifre RTP con SRTP
    - B. Envíe RTP de vuelta a la dirección desde la cual llegó realmente el medio, ignorando el SDP
    - C. Deshabilite RTP por completo
    - D. Fuerce el medio directo entre endpoints

**Respuestas:** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
