# Migración de chan_sip a PJSIP: un libro de recetas

Si está leyendo esto con un servidor Asterisk 13, 16 o 18 todavía en producción, tiene una fecha límite. `chan_sip` —el controlador de canal SIP original configurado a través de `sip.conf`— fue **declarado obsoleto en Asterisk 17, eliminado de la compilación predeterminada en Asterisk 19 y eliminado por completo en Asterisk 21**. No existe en Asterisk 22 LTS. No hay ninguna bandera para reactivarlo, ningún `noload` para evitarlo, ni paquete que instalar. El único controlador de canal SIP en Asterisk 22 es **PJSIP** (`res_pjsip` más `chan_pjsip`), configurado a través de `pjsip.conf`.

Por lo tanto, una actualización a Asterisk 22 es, para la mayoría de los sitios, tanto un *proyecto de migración SIP* como un salto de versión. La buena noticia es que el protocolo en la red no cambia —un teléfono que se registró y llamó ayer se registrará y llamará mañana— y Asterisk incluye una herramienta de conversión para hacer el 80% inicial de la traducción por usted. Este capítulo es un libro de recetas práctico: el mapeo de conceptos, el script de conversión, las traducciones lado a lado de `sip.conf` → `pjsip.conf` para los casos que usted realmente tiene, los cambios en el dialplan y la CLI que vienen con el cambio, la migración de realtime (base de datos), y una lista de verificación además de los obstáculos que afectan a las personas.

Todo lo que se presenta aquí está verificado con el laboratorio de Asterisk 22.10.0 del libro. El material de legado profundo sobre `chan_sip` en sí —y una conversión completa de extremo a extremo de un `sip.conf` multidispositivo— reside en el capítulo de *Canales heredados*; este capítulo es el compañero enfocado al estilo de recetas para ello.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Explicar por qué `chan_sip` ha desaparecido en Asterisk 22 y qué lo reemplaza
- Mapear el modelo peer/user/friend de `sip.conf` al modelo de objetos de PJSIP
  (endpoint + aor + auth + identify + transport + registration)
- Ejecutar el script de conversión `sip_to_pjsip.py` y revisar su salida de manera crítica
- Traducir manualmente los tipos de dispositivos comunes (teléfono con registro, trunk entrante, registro saliente) de `sip.conf` a `pjsip.conf`
- Migrar las configuraciones de NAT, media, DTMF, codec y autenticación opción por opción
- Actualizar el dialplan (`SIP/` → `PJSIP/`) y la CLI (`sip show` → `pjsip show`)
- Migrar un despliegue de realtime/ARA de `sippeers`/`sipregs` a las tablas de Sorcery
  `ps_*`
- Trabajar con una lista de verificación de migración y evitar los errores clásicos

## Por qué migrar en absoluto

`chan_sip` sirvió a Asterisk durante casi dos décadas, pero cargaba con deuda
arquitectónica: un módulo monolítico, un único bloque de configuración por dispositivo,
soporte débil para múltiples transportes y una pila SIP que se había quedado atrás
respecto a los RFC. **PJSIP** —construido sobre la madura pila pjproject de Teluu e
introducido en Asterisk 12— fue el reemplazo desde cero. Para Asterisk 21, el proyecto
Asterisk terminó el trabajo y eliminó `chan_sip` del árbol.

Puede confirmar la situación en cualquier sistema Asterisk 22:

```
*CLI> module show like chan_sip
Module                         Description              Use Count  Status      Support Level
0 modules loaded

*CLI> module show like chan_pjsip
Module                         Description              Use Count  Status      Support Level
chan_pjsip.so                  PJSIP Channel Driver     0          Running     core
1 modules loaded
```

`chan_sip` devuelve *0 modules loaded* — simplemente ya no está ahí. No hay nada a qué
migrar excepto PJSIP, por lo que la única pregunta real es *cómo*, no *si hacerlo*.

## El mapeo conceptual: no existe un "peer" único

El cambio de mentalidad que confunde a todos los que vienen de `sip.conf` es este: **PJSIP no tiene `[peer]`.** En `sip.conf`, un bloque entre corchetes —un `peer`, un `user` o un `friend`— describía *todo* sobre un dispositivo: sus credenciales, dónde localizarlo, sus codec, su comportamiento ante NAT, su context de dialplan. PJSIP divide deliberadamente ese bloque único en varios objetos más pequeños de propósito único, cada uno etiquetado con un `type=`, que *se hacen referencia entre sí por nombre*:

| Objeto PJSIP (`type=`) | Responsabilidad |
| --- | --- |
| `endpoint` | La identidad de manejo de llamadas del dispositivo: codec, context, DTMF, media, NAT y referencias a sus `auth`/`aors`/`transport` |
| `aor` (Address of Record) | *Dónde* localizar al dispositivo: contactos registrados o estáticos, `max_contacts`, qualify |
| `auth` | Credenciales (nombre de usuario/contraseña) para autenticación entrante y/o saliente |
| `identify` | Hacer coincidir una solicitud entrante con un endpoint por **IP de origen** en lugar de por el usuario `From` |
| `transport` | El/los socket(s) de escucha: protocolo, dirección/puerto de enlace, direcciones NAT/externas |
| `registration` | Un REGISTER **saliente** desde Asterisk hacia un proveedor |

La distinción `friend`/`peer`/`user` desaparece por completo; en PJSIP todo es un `endpoint`. Por lo tanto, un solo friend `sip.conf` se convierte, típicamente, en tres objetos (`endpoint` + `auth` + `aor`) que comparten un nombre y se apuntan entre sí:

```
                sip.conf                              pjsip.conf
            ┌──────────────┐              ┌──────────┐   ┌──────┐   ┌─────┐
            │   [2000]     │   becomes    │ endpoint │──▶│ auth │   │ aor │
            │ type=friend  │  ─────────▶  │  [2000]  │   │[2000]│   │[2000]│
            │ host=dynamic │              │  auth=───┼──▶└──────┘   └──────┘
            │ secret=...   │              │  aors=───┼───────────────▶ ▲
            └──────────────┘              └────┬─────┘
                                               │ transport=
                                               ▼
                                          ┌───────────┐
                                          │ transport │  (shared by all endpoints)
                                          └───────────┘
```

El endpoint es el pegamento. Nombra un `transport` (o hereda el predeterminado), un objeto `auth` y uno o más `aors`. El modelo de objetos se cubre a fondo en *SIP & PJSIP in depth*; aquí solo lo necesitamos como el objetivo de cada traducción.

## La herramienta de conversión `sip_to_pjsip.py`

Asterisk incluye un script de Python que lee un `sip.conf` existente y escribe un
`pjsip.conf`. No se ejecuta como un comando de CLI; reside en el **árbol de fuentes de Asterisk**, no en los binarios instalados:

```
${ASTERISK_SRC}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

En el Asterisk 22.10.0 del laboratorio, la ruta completa es, por ejemplo,
`/usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py`. El mismo directorio contiene `sip_to_pjsql.py` (la variante realtime/SQL, que se tratará más adelante) y
los módulos auxiliares `astconfigparser.py`, `astdicts.py` y `sqlconfigparser.py`.

### Ejecución

El script acepta argumentos posicionales opcionales — `[input-file [output-file]]` —
que por defecto son `sip.conf` y `pjsip.conf` en el directorio actual:

```
cd /etc/asterisk
python /usr/src/asterisk-22.10.0/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py \
       sip.conf pjsip_generated.conf
```

Sus únicas opciones reales son:

```
-h, --help              show usage
-p, --prefix PREFIX     output prefix for include files (default: pjsip_)
-q, --quiet             don't print messages to stdout
```

Lee la entrada, imprime `Converting to PJSIP...` y escribe el archivo de salida.
Internamente recorre cada sección `sip.conf` y, por cada dispositivo, emite los objetos correspondientes
`endpoint`, `auth`, `aor`, `registration` y (donde puede inferirlos)
`transport`, aplicando automáticamente las asignaciones de opciones que se describen en la siguiente sección.

### Qué hace — y sus límites

Considere la salida como un **primer borrador, no como un archivo terminado.** El script es honesto
sobre sus propias deficiencias: todo lo que no puede asignar limpiamente se escribe en un bloque claramente delimitado en la parte superior del archivo de salida:

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[softphone]
qualify = yes
...
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
```

Observe en ese fragmento real que `qualify = yes` de un peer `sip.conf` terminó en el
bloque *no asignado* — debido a que PJSIP califica en el **aor** con
`qualify_frequency` (segundos), no como un booleano en el dispositivo, el script lo deja para que usted lo configure deliberadamente. Las limitaciones prácticas a tener en cuenta son:

- **Los transportes se adivinan, no se diseñan.** El script emite un
  `transport-udp` básico desde `bindport`/`bindaddr`, pero no puede conocer sus certificados TLS,
  sus necesidades de TCP o su diseño de enlaces múltiples. Revise y reescriba el transporte.
- **NAT y las direcciones externas requieren intervención humana.** `externaddr`/`localnet` pueden no
  sobrevivir limpiamente; confirme manualmente `external_media_address`, `external_signaling_address`
  y `local_net` en el transporte.
- **`qualify`, temporizadores personalizados y un puñado de opciones terminan en "no asignado".**
  Lea ese bloque de principio a fin y decida sobre cada uno.
- **Las listas de codec, los context y la seguridad necesitan revisión.** Verifique `disallow`/`allow`,
  el dialplan `context` y asegúrese de que ningún dispositivo quede abierto involuntariamente.

Por lo tanto, el flujo de trabajo es: ejecute el script hacia un archivo *temporal*, compárelo y revíselo, incorpore las partes correctas en su `pjsip.conf` real y luego realice pruebas exhaustivas antes de pasar a producción.

## Traducciones comparativas

Estas son las recetas. `sip.conf` a la izquierda, el equivalente verificado `pjsip.conf` a la derecha (apilado aquí por el ancho de la página). Cada nombre de opción y valor a la derecha ha sido verificado contra el laboratorio de Asterisk 22 con `config show help res_pjsip ...`.

### Un teléfono con registro (`host=dynamic`)

El dispositivo más común: un teléfono de escritorio o softphone que inicia sesión con un secreto y registra su propia ubicación.

**`sip.conf` heredado:**

```
[2000]
type=friend
host=dynamic
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmfmode=rfc2833
secret=Sup3rSecret
qualify=yes
```

**Asterisk 22 `pjsip.conf`:**

```
[2000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
auth=2000
aors=2000

[2000]
type=auth
auth_type=digest
username=2000
password=Sup3rSecret

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

Movimientos clave: `host=dynamic` se convierte en un `aor` con `max_contacts` (el dispositivo realiza un REGISTER para completar su contacto); `secret=` se convierte en `password=` dentro de un `type=auth`; `qualify=yes` se convierte en `qualify_frequency=60` (segundos) en el **aor**, no en el endpoint. Establezca `max_contacts` por encima de 1 solo si realmente desea la misma cuenta en varios dispositivos a la vez.

### Un trunk entrante (`host=<ip>` / `type=peer`)

Un proveedor que le envía llamadas desde una dirección IP conocida. Aquí no hay registro: usted autentica el *tráfico del carrier por su IP de origen* usando `identify`.

**`sip.conf` heredado:**

```
[itsp-in]
type=peer
host=203.0.113.10
context=from-pstn
disallow=all
allow=ulaw
insecure=invite
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp-in]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw

[itsp-in]
type=aor
contact=sip:203.0.113.10:5060

[itsp-in]
type=identify
endpoint=itsp-in
match=203.0.113.10
```

La traducción crucial es **`insecure=invite` → `identify`**. En `chan_sip`, `insecure=invite` le decía a Asterisk "no desafíes los INVITE entrantes de este peer para autenticación". PJSIP logra el mismo efecto *haciendo coincidir la IP de origen con el endpoint* mediante `type=identify`/`match=`, lo cual es más explícito y más seguro. El `host=` estático se convierte en un `contact=` permanente en el `aor` para que también pueda realizar llamadas *salientes* al carrier. `match=` acepta una IP, un rango CIDR o un nombre de host (resuelto al momento de cargar la configuración; recargue si la IP del proveedor cambia).

### Un registro saliente (`register =>`)

Cuando el proveedor quiere que *usted* inicie sesión en *ellos*, `chan_sip` usaba una sola línea `register =>` en `[general]`. PJSIP la reemplaza con un objeto `type=registration` dedicado más un `outbound_auth`.

**`sip.conf` heredado:**

```
[general]
register => 1020:supersecret@sip.example.com:5600/9999

[itsp]
type=peer
host=sip.example.com
port=5600
defaultuser=1020
secret=supersecret
fromuser=1020
fromdomain=sip.example.com
context=from-pstn
```

**Asterisk 22 `pjsip.conf`:**

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
outbound_auth=itsp-auth
aors=itsp-aor
from_user=1020
from_domain=sip.example.com

[itsp-auth]
type=auth
auth_type=digest
username=1020
password=supersecret

[itsp-aor]
type=aor
contact=sip:sip.example.com:5600

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:sip.example.com:5600
client_uri=sip:1020@sip.example.com:5600
contact_user=9999
retry_interval=60
```

Mapee los campos `register =>` uno a uno: las credenciales `1020:supersecret` se convierten en el objeto `auth` (referenciado como `outbound_auth`); `@sip.example.com:5600` se convierte en el `server_uri`; el sufijo `/9999` —la parte del usuario a la que el proveedor entrega las llamadas entrantes— se convierte en `contact_user=9999`. `defaultuser`/`fromuser` y `fromdomain` se convierten en `from_user` y `from_domain` en el endpoint. Tenga en cuenta que `outbound_auth` aparece *dos veces*: el registro lo usa para el REGISTER, el endpoint lo usa para responder al desafío `407` en los INVITE salientes.

## Referencia de migración opción por opción

Cuando realice la traducción manualmente (o audite la salida del script), esta tabla es su referencia. Cada nombre de opción de PJSIP y su ubicación (endpoint / aor / auth / transport) ha sido verificada en el laboratorio de Asterisk 22.

| Legacy `sip.conf` | Asterisk 22 `pjsip.conf` | Ubicación |
| --- | --- | --- |
| `[peer]` / `[user]` / `[friend]` | `type=endpoint` (+ `auth` + `aor`) | — |
| `host=dynamic` | `max_contacts=1` (device REGISTERs) | aor |
| `host=<ip/host>` | `contact=sip:<host>:<port>` | aor |
| `register => u:p@host/ext` | `type=registration` + `outbound_auth` | registration |
| `secret=` | `password=` | auth |
| `username=` / `defaultuser=` | `username=` | auth |
| `secret=` (auth method) | `auth_type=digest` | auth |
| `nat=force_rport,comedia` | `force_rport=yes` + `rewrite_contact=yes` + `rtp_symmetric=yes` | endpoint |
| `directmedia=yes/no` | `direct_media=yes/no` | endpoint |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` | endpoint |
| `disallow=` / `allow=` | `disallow=` / `allow=` (same syntax) | endpoint |
| `context=` | `context=` | endpoint |
| `qualify=yes` | `qualify_frequency=<seconds>` | aor |
| `insecure=invite` | omit auth; use `type=identify` + `match=` | identify |
| `fromuser=` / `fromdomain=` | `from_user=` / `from_domain=` | endpoint |
| `externaddr=` / `externip=` | `external_media_address=` + `external_signaling_address=` | transport |
| `localnet=` | `local_net=` | transport |

### Una nota sobre `secret` → `auth` y `auth_type`

El `secret=` de `chan_sip` se convierte en el campo `password=` de un objeto `type=auth`. El **método de autenticación** se establece con `auth_type`. Utilice `auth_type=digest`. Los valores antiguos `userpass` y `md5` siguen funcionando, pero están **obsoletos y se convierten silenciosamente a `digest`** — verificado directamente desde el laboratorio:

```
*CLI> config show help res_pjsip auth auth_type
...
 The older 'md5' and 'userpass' values are deprecated and converted to 'digest'.
    userpass - Deprecated.  Use 'digest'.
    md5 - Deprecated.  Use 'digest'.
    digest - If selected, the 'password' ... parameters must be provided.
```

Verá `auth_type=userpass` en configuraciones antiguas y en la salida del script de conversión (y en capítulos anteriores de este libro). Es inofensivo, pero escriba `digest` en cualquier implementación nueva.

### NAT, media y DTMF en detalle

Estos tres puntos son donde se originan la mayoría de los tickets post-migración del tipo "se registra pero no tiene audio". La abreviatura `nat=force_rport,comedia` de `chan_sip` agrupaba tres comportamientos en una sola opción; PJSIP los separa para que pueda analizar cada uno:

```
; sip.conf:  nat=force_rport,comedia
; pjsip.conf (on the endpoint):
force_rport=yes        ; reply to the source IP/port of the request (RFC 3581)
rewrite_contact=yes    ; rewrite the stored Contact to the real source address
rtp_symmetric=yes      ; send RTP back where it actually came from (comedia)
```

Para **media**, `directmedia` se convierte en `direct_media` (el guion bajo es todo el cambio); mantenga `direct_media=no` siempre que la llamada deba estar anclada en Asterisk — a través de NAT, o para grabar/transcodificar/transferir. Para **DTMF**, el RFC fue renumerado: el `dtmfmode=rfc2833` de `chan_sip` es el `dtmf_mode=rfc4733` de PJSIP (el mismo mecanismo out-of-band telephone-event, número de RFC actual). El laboratorio confirma que los valores válidos de `dtmf_mode` son `rfc4733`, `inband`, `info`, `auto` y `auto_info`, con un valor predeterminado de `rfc4733`.

Para los **codecs**, nada cambia: `disallow=all` seguido de `allow=ulaw` (etc.) utiliza la sintaxis idéntica en el endpoint de PJSIP.

## Cambios en el dialplan y la CLI

La migración no se detiene en `pjsip.conf`. Dos elementos de uso diario cambian.

### Cadenas de canal: `SIP/` → `PJSIP/`

Cada `Dial()` y referencia de canal en el `extensions.conf` que nombrara la tecnología antigua debe actualizarse:

```
; Before (chan_sip)
exten => 2000,1,Dial(SIP/2000,30,tT)

; After (chan_pjsip)
exten => 2000,1,Dial(PJSIP/2000,30,tT)
```

Las cadenas de marcado de los trunk siguen el mismo patrón: `Dial(SIP/${EXTEN}@itsp)` se convierte en `Dial(PJSIP/${EXTEN}@itsp)`. PJSIP también añade la función `PJSIP_DIAL_CONTACTS()` para llamar a todos los contactos vinculados a un AOR simultáneamente, además de las funciones de dialplan `PJSIP_HEADER()` / `PJSIP_MEDIA_OFFER()`; busque en su dialplan referencias a `SIP/`, `SIPPEER`, `SIPCHANINFO` y `CHANNEL(...)` SIP y traduzca cada una.

### CLI: `sip show ...` → `pjsip show ...`

Todo el árbol de comandos `sip ...` desaparece junto con el controlador. Los reemplazos son:

| Comando `chan_sip` | Asterisk 22 (`chan_pjsip`) |
| --- | --- |
| `sip show peers` | `pjsip show endpoints` |
| `sip show peer <name>` | `pjsip show endpoint <name>` |
| `sip show registry` | `pjsip show registrations` |
| `sip show channels` | `core show channels` (o `pjsip show channels`) |
| `sip set debug on` | `pjsip set logger on` |
| `sip reload` | `module reload res_pjsip.so` (o `core reload`) |

Los comandos antiguos no solo se comportan de manera diferente, sino que ya no existen. En el laboratorio, `sip show peers` devuelve *No such command*, mientras que `pjsip show endpoints`, `pjsip show aors`, `pjsip show auths`, `pjsip show contacts`, `pjsip show registrations` y `pjsip show identifies` están todos presentes. El comando de resolución de problemas más útil —el registrador de paquetes SIP que imprimía cada mensaje con `sip set debug`— es ahora **`pjsip set logger on`** (con `pjsip set logger host <ip>` para enfocarse en un peer específico).

## Migración a Realtime (ARA)

Si ejecutaba `chan_sip` desde una base de datos (Asterisk Realtime Architecture), sus
dispositivos residían en la tabla `sippeers` y los registros en `sipregs`. PJSIP utiliza una
capa de almacenamiento completamente diferente — **Sorcery** — con una tabla *por tipo
de objeto*. El mapeo es el siguiente:

| Tabla realtime de `chan_sip` | Tabla(s) de PJSIP / Sorcery |
| --- | --- |
| `sippeers` | `ps_endpoints`, `ps_aors`, `ps_auths` (una fila cada una, divididas) |
| `sipregs` | `ps_contacts` (registros dinámicos) |
| — (`register=>` saliente) | `ps_registrations` |
| — (coincidencia de IP) | `ps_endpoint_id_ips` (los objetos `identify`) |
| — (alias de dominio) | `ps_domain_aliases` |

La división conceptual es la misma que en el caso de archivos planos: una fila de `sippeers` se convierte
en *tres* filas en tres tablas (`ps_endpoints` + `ps_aors` + `ps_auths`) que
se referencian entre sí mediante el nombre del endpoint.

Dos cosas hacen que esto sea manejable:

- **El esquema se genera para usted.** Asterisk incluye migraciones de Alembic en
  `contrib/ast-db-manage/` que crean cada tabla de `ps_*`. Ejecute
  `alembic upgrade head` contra la base de datos `config` para construir el esquema
  PJSIP actual en lugar de escribir DDL a mano.
- **Existe un script de conversión SQL.** Junto a `sip_to_pjsip.py` se encuentra
  **`sip_to_pjsql.py`** en el mismo directorio `contrib/scripts/sip_to_pjsip/`;
  reutiliza la misma lógica de `convert()` pero emite un archivo `pjsip.sql` con sentencias
  `INSERT` para las tablas de `ps_*` en lugar de un archivo de configuración plano. Al igual que con la
  herramienta para archivos planos, revise la salida antes de cargarla.

Finalmente, apunte `sorcery.conf` a su base de datos para que PJSIP lea endpoints, aors,
auths y contacts desde las tablas `ps_*` (vía `res_config_odbc` /
`res_pjsip_realtime`), exactamente como `extconfig.conf` apuntaba anteriormente `sippeers` a la
base de datos para `chan_sip`. Los mecanismos de realtime se cubren en el capítulo de *Realtime*;
el punto específico de la migración es simplemente *qué tablas se mapean con cuáles*.

## Lista de verificación de migración

Un orden de operaciones pragmático para una transición a producción:

1. **Inventario.** Liste cada dispositivo, trunk y `register =>` en `sip.conf` (o cada fila de `sippeers`/`sipregs`). Tome nota de las configuraciones personalizadas de NAT, codec y DTMF.
2. **Ejecute el convertidor hacia un archivo temporal.**
   `sip_to_pjsip.py sip.conf pjsip_generated.conf`. **No** lo apunte a su `pjsip.conf` en vivo.
3. **Lea el bloque "Non mapped elements"** en la parte superior de la salida y resuelva cada línea, especialmente `qualify`, temporizadores y cualquier cosa relacionada con NAT.
4. **Diseñe el/los transport(s) manualmente.** Un transport por IP/puerto; añada TLS/TCP según sea necesario; configure `external_*_address` y `local_net` para cajas en la nube/NAT.
5. **Verifique la autenticación.** Confirme `auth_type=digest`, nombres de usuario y contraseñas en cada objeto `auth`.
6. **Verifique NAT/media/DTMF.** `force_rport`/`rewrite_contact`/`rtp_symmetric`, `direct_media`, `dtmf_mode=rfc4733` por endpoint según sea necesario.
7. **Actualice el dialplan.** `SIP/` → `PJSIP/` en todas partes; revise las funciones de `SIP*` y las variables de canal.
8. **Actualice scripts y monitoreo.** Cualquier herramienta o consumidor de AMI que analizara la salida de `sip show ...` debe migrar a `pjsip show ...` / acciones de PJSIP AMI.
9. **Recargue y verifique.** `module reload res_pjsip.so`, luego `pjsip show endpoints`, `pjsip show registrations`, `pjsip show identifies`.
10. **Pruebe con el registrador de paquetes.** `pjsip set logger on`; realice un registro, una llamada entrante y una llamada saliente, y lea el intercambio SIP de principio a fin.

## Errores comunes

- **`alwaysauthreject` ya viene integrado — no lo busque.** `chan_sip` necesitaba
  `alwaysauthreject=yes` para no revelar qué extensiones existían respondiendo
  de manera diferente a nombres de usuario incorrectos. PJSIP hace lo correcto por diseño: nunca revela si un endpoint existe. No hay ninguna opción `alwaysauthreject` que configurar. La protección relacionada —limitar la tasa de remitentes no identificados— es el parámetro global
  `unidentified_request_count` / `unidentified_request_period`, que viene activado por defecto.

- **`insecure=invite` no es una opción de PJSIP — utilice `identify`.** No existe
  `insecure=` en `pjsip.conf`. La forma de aceptar INVITEs sin autenticar de un
  proveedor conocido es *identificar el endpoint por IP de origen* con `type=identify` /
  `match=`. Realice la coincidencia de la manera más estricta posible (IPs de host específicas, no CIDRs amplios) y respalde esto con un `type=acl` — un trunk con coincidencia de IP sin autenticación es un objetivo para el fraude telefónico.

- **Un transporte por IP/puerto.** No puede enlazar dos transportes a la misma
  IP:puerto, y no puede enlazar múltiples transportes TCP o TLS de la misma versión de IP. El script de conversión puede emitir un transporte que colisione con uno que
  usted ya tenga — consolide todo en una capa de transporte diseñada deliberadamente.

- **`qualify=yes` no se traduce a un booleano.** Pertenece al **aor** como
  `qualify_frequency=<seconds>`. El convertidor coloca `qualify=yes` en el
  bloque no mapeado precisamente porque no existe un booleano equivalente en el
  endpoint.

- **`secret=` no es una opción de endpoint.** Las credenciales residen únicamente en un objeto `type=auth`
  al que el endpoint *hace referencia* (`auth=` para llamadas entrantes, `outbound_auth=` para
  salientes). Poner una contraseña en el endpoint no hace nada.

- **La CLI y cualquier script de extracción fallan silenciosamente.** `sip show ...` devuelve "No
  such command", no un error que su monitoreo necesariamente detectará. Audite cada
  trabajo de cron, chequeo de Nagios y cliente AMI en busca de comandos `sip ` antes de la migración.

## Resumen

Migrar a Asterisk 22 significa migrar fuera de `chan_sip`, debido a que el controlador fue eliminado en Asterisk 21 y PJSIP es el único canal SIP que permanece. El núcleo del trabajo consiste en volver a expresar cada `sip.conf` `peer`/`user`/`friend` —que agrupaba todo en un solo bloque— como un conjunto de objetos PJSIP que cooperan: un `endpoint` más un `auth`, un `aor` y, dependiendo del dispositivo, un `identify` (trunk de entrada), un `registration` (inicio de sesión de salida) y un `transport` compartido. El script `sip_to_pjsip.py` en `contrib/scripts/sip_to_pjsip/` realiza la mayor parte de la traducción y señala honestamente lo que no puede asignar en un bloque de "Elementos no asignados", pero su salida es un primer borrador: diseñe el transport, NAT y la seguridad manualmente y realice pruebas antes de pasar a producción. Alrededor de la configuración, actualice el dialplan (`SIP/` → `PJSIP/`) y sus dedos y scripts (`sip show` → `pjsip show`, `sip set debug` → `pjsip set logger`). Las implementaciones realtime se mueven de `sippeers`/`sipregs` a las tablas Sorcery `ps_endpoints`/`ps_aors`/`ps_auths`/`ps_contacts`, con `sip_to_pjsql.py` y el esquema `contrib/ast-db-manage` para ayudar. Esté atento a las dificultades — `alwaysauthreject` está integrado, `insecure=invite` se convierte en `identify`, `qualify=yes` se convierte en `qualify_frequency`, y un transport por IP/puerto — y el cambio será mecánico en lugar de misterioso.

## Cuestionario

1. ¿Por qué una implementación de Asterisk 22 debe usar PJSIP para SIP?
   - A. `chan_sip` es más lento pero aún está disponible
   - B. `chan_sip` fue eliminado en Asterisk 21 y no existe en Asterisk 22
   - C. PJSIP es el valor predeterminado pero `chan_sip` puede cargarse con `modules.conf`
   - D. `chan_sip` solo funciona con TLS en Asterisk 22

2. ¿En qué conjunto de objetos PJSIP se convierte más comúnmente un solo bloque `sip.conf` `type=friend`?
   - A. Un solo `type=peer`
   - B. Solo `type=endpoint`
   - C. `type=endpoint` + `type=auth` + `type=aor`
   - D. `type=transport` + `type=registration`

3. En `sip.conf`, `host=dynamic` (el dispositivo registra su propia ubicación) se asigna a:
   - A. `type=identify` con `match=dynamic`
   - B. un `type=aor` con `max_contacts` (el dispositivo envía REGISTER)
   - C. `direct_media=yes` en el endpoint
   - D. `type=registration`

4. El script de conversión `sip_to_pjsip.py` es:
   - A. Un comando de CLI: `asterisk -rx 'sip_to_pjsip'`
   - B. Un script de Python en el árbol de fuentes de Asterisk bajo
     `contrib/scripts/sip_to_pjsip/`
   - C. Un módulo compilado que se carga al arrancar
   - D. Parte de `res_pjsip.so`

5. Verdadero o Falso: La salida de `sip_to_pjsip.py` está lista para producción y debe cargarse sin revisión.

6. ¿A qué tres opciones se traduce la abreviatura `chan_sip` `nat=force_rport,comedia` en un endpoint PJSIP?
   - A. `nat=yes`, `qualify=yes`, `directmedia=no`
   - B. `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes`
   - C. `external_media_address`, `external_signaling_address`, `local_net`
   - D. `insecure=invite`, `identify`, `match`

7. ¿En qué configuración de PJSIP se convierte el `dtmfmode=rfc2833` de `sip.conf`?
   - A. `dtmf_mode=rfc2833`
   - B. `dtmf_mode=inband`
   - C. `dtmf_mode=rfc4733`
   - D. `dtmf_mode=info`

8. En Asterisk 22, ¿qué `auth_type` debe usar un objeto `auth` y cuál es el estado de `userpass`?
   - A. `auth_type=userpass`; es el único valor válido
   - B. `auth_type=digest`; `userpass` está obsoleto y se convierte a `digest`
   - C. `auth_type=md5`; `digest` está obsoleto
   - D. `auth_type=plaintext`; `digest` fue eliminado

9. Un peer de proveedor `chan_sip` con `insecure=invite` (aceptar INVITEs no autenticados desde una IP conocida) se migra a PJSIP usando:
   - A. `insecure=invite` en el endpoint
   - B. `allowguest=yes` en `[global]`
   - C. un objeto `type=identify` con `match=<provider IP>`
   - D. `auth_type=anonymous`

10. En una migración realtime, ¿por qué tablas de PJSIP/Sorcery se reemplaza la tabla `chan_sip` `sippeers`?
    - A. Una sola tabla `pjsip_peers`
    - B. `ps_endpoints`, `ps_aors` y `ps_auths`
    - C. `sipregs` y `voicemail`
    - D. Solo `ps_contacts`

**Respuestas:** 1 — B · 2 — C · 3 — B · 4 — B · 5 — Falso · 6 — B · 7 — C · 8 — B · 9 — C · 10 — B
