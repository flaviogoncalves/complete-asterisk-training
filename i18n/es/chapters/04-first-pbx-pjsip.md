# Construyendo su primer PBX con PJSIP

En este capítulo, aprenderá cómo realizar una configuración básica de un PBX Asterisk. El objetivo principal aquí es ver el PBX funcionando por primera vez, ser capaz de marcar entre extensiones, marcar hacia un mensaje que se está reproduciendo y marcar hacia un solo trunk analógico o SIP. La idea detrás de este capítulo es asegurar que su Asterisk esté en funcionamiento lo antes posible. Después de completar el trabajo en este capítulo, tendrá los conocimientos suficientes para prepararse para los capítulos siguientes, donde profundizaremos más en los detalles de configuración.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Comprender y editar archivos de configuración;
- Instalar softphones basados en SIP;
- Instalar y configurar un trunk SIP;
- Instalar y configurar una conexión analógica;
- Llamar entre extensiones;
- Llamar entre teléfonos y destinos externos; y
- Configurar un IVR.

## Entendiendo los archivos de configuración

Asterisk es controlado por archivos de configuración de texto ubicados en /etc/asterisk. El formato del archivo es similar a los archivos “.ini” de Windows. Se utiliza un punto y coma como carácter de comentario, los signos “=” y “=>” son equivalentes, y los espacios son ignorados.

```
;
; The first line without a comment should be the session title.
;
[Session]
Key = value; Variable designation
[Session 2]
Key => value; Object declaration
```

Asterisk interpreta “=” y “=>” de la misma manera. Las diferencias en la sintaxis se utilizan para distinguir entre objetos y variables. Utilice “=” cuando desee declarar una variable y “=>” para designar un objeto. La sintaxis es la misma entre todos los archivos, pero se utilizan tres tipos de gramática, como se analiza a continuación.

## Grammars

| Grammar | Cómo se crea el objeto | Archivo de conf. | Ejemplo |
|---------|---------------------------|------------|---------|
| Simple Group | Todo en la misma línea | `extensions.conf` | `exten => 4000,1,Dial(PJSIP/4000)` |
| Option Inheritance | Las opciones se definen primero, el objeto hereda las opciones | `chan_dahdi.conf` | `[channels]; context=default; signalling=fxs_ks; group=1; channel => 1` |
| Complex Entity | Cada entidad recibe un context | `pjsip.conf`, `iax.conf` | `[cisco]; type=endpoint; auth=cisco-auth; aors=cisco; context=trusted` |

### Simple Group

El formato de simple group utilizado en `extensions.conf` y `voicemail.conf` es la gramática más básica. Cada objeto se declara con sus opciones en la misma línea. Ejemplo:

```
[Session]
Object 1 => op1,op2,op3
Object 2=> op1b,op2b,op3b
```

En este ejemplo, el objeto 1 se crea con las opciones op1, op2 y op3, mientras que el objeto 2 se crea con las opciones op1, op2 y op3.

### Object options inheritance grammar

Este formato es utilizado por los archivos chan_dahdi.conf y agents.conf, donde hay numerosas opciones disponibles y la mayoría de las interfaces y objetos comparten las mismas opciones. Típicamente, una o más secciones contienen declaraciones de objetos y canales. Las opciones para el objeto se declaran por encima del objeto y pueden cambiarse para otro objeto. Aunque este concepto es difícil de entender, es muy fácil de usar. Ejemplo:

```
[Session]
op1 = bas
op2 = adv
object=>1
op1 = int
object => 2
```

Las dos primeras líneas configuran el valor de las opciones op1 y op2 como “bas” y “adv”, respectivamente. Cuando se instancia el objeto 1, se crea utilizando la opción 1 como “bas” y la opción 2 como “adv”. Después de definir el objeto 1, cambiamos la opción 1 a “int”. A continuación, creamos el objeto 2 con la opción 1 como “int” y la opción 2 como “adv”.

### Complex entity object

Este formato es utilizado por pjsip.conf, iax.conf y otros archivos de configuración en los que existen numerosas entidades con muchas opciones. Típicamente, este formato no comparte un gran volumen de configuraciones comunes. Cada entidad recibe un context. A veces existen contexts reservados, como [general] para configuraciones globales. Las opciones se declaran en las declaraciones de context. Ejemplo:

```
[entity1]
op1=value1
op2=value2
[entity2]
op1=value3
op2=value4
```

La entidad [entity1] tiene los valores “value1” y “value2” para las opciones op1 y op2, respectivamente. La entidad [entity2] tiene los valores “value3” y “value4” para las opciones op1 y op2.

## Opciones para construir un LAB para Asterisk

Para configurar una PBX, necesitará algo de hardware básico. No es difícil ni costoso, pero hay algunas opciones que deben considerarse. Todo lo que necesitará son dos teléfonos y una conexión a la red pública. Existen algunas opciones y combinaciones posibles al crear su laboratorio, las cuales discutiremos a continuación.

### Opción 1: LAB completo

Con el LAB completo, es posible probar todos los escenarios disponibles y comparar soluciones como ATA, IP-phones y softphones. También puede aprender sobre troncales analógicas y SIP. Necesitará:

- Un adaptador de teléfono analógico (ATA) SIP
- Un IP phone
- Un servidor dedicado para Asterisk
- Una estación de trabajo con un softphone
- Una tarjeta de interfaz analógica con al menos dos interfaces (1 FXO y 1 FXS)
- Una cuenta con un proveedor VoIP

### Opción 2: LAB económico

Con el LAB económico, simplificamos un poco las cosas. Usamos el ATA, que generalmente es menos costoso que el IP phone, y una sola tarjeta FXO, que es realmente económica. No podremos usar teléfonos analógicos conectados directamente al servidor, pero esto no ocurre comúnmente en la práctica. Necesitará:

- Un adaptador de teléfono analógico (ATA) SIP
- Un servidor dedicado para Asterisk
- Una estación de trabajo para el softphone
- Una tarjeta de interfaz analógica con 1 FXO
- Una cuenta con un proveedor VoIP

### Opción 3: LAB súper económico

El tercer LAB utiliza un servidor virtualizado en la propia notebook del estudiante. El problema con este modelo son los conflictos generados por el puerto UDP. A veces, tanto el servidor Asterisk como el softphone intentan acceder al mismo puerto, evitando que Asterisk vincule el puerto de dirección. Otro problema es la calidad de las llamadas; los entornos virtuales no están indicados para aplicaciones de tiempo real como Asterisk. Utilice un softphone gratuito para el servidor y la estación de trabajo y una conexión de trunk a un proveedor SIP. Necesitará:

- Una laptop ejecutando un softphone
- Una máquina virtual (VirtualBox, VMware o similar) para instalar Asterisk
- Una cuenta con un proveedor VoIP

## Secuencia de instalación

Para ayudarle a comprender la secuencia de instalación, hemos descrito los pasos necesarios para instalar y configurar Asterisk.

![Diseño del laboratorio de referencia: softphones SIP/IAX, un teléfono IP y adaptadores analógicos como extensiones (1), el servidor Asterisk con interfaces ETH0/FXO/FXS (3), y los trunks hacia la PSTN a través de un proveedor VoIP o un enlace de banda ancha (2).](../images/04-first-pbx-fig01.png)

1. Configuración de extensiones
   - a. Extensiones SIP (ATA, softphone, teléfono IP)
   - b. Extensiones IAX
   - c. Extensiones FXS
2. Configuración de trunks
   - a. Configuración de un trunk SIP
   - b. Configuración de un trunk FXO
3. Construcción de un dialplan básico
   - a. Llamadas entre extensiones
   - b. Llamadas a destinos externos
   - c. Recepción de una llamada en la extensión de la operadora
   - d. Recepción de una llamada en un IVR

## Configuración de las extensiones

Las extensiones son teléfonos SIP, IAX o analógicos conectados a un puerto FXS. Para configurar una extensión, debe editar el archivo de configuración relacionado con el canal (pjsip.conf, iax.conf, chan_dahdi.conf).

### Extensiones SIP

En Asterisk 22, PJSIP (la pila `res_pjsip`, configurada en `/etc/asterisk/pjsip.conf`) es el controlador de canal SIP. Es compatible con múltiples transportes por endpoint, cuenta con mantenimiento activo y es el único controlador SIP incluido con la plataforma. (El controlador original `chan_sip` fue eliminado en Asterisk 21; consulte el capítulo *Legacy channels* si necesita migrar una configuración antigua).

La idea aquí es configurar una PBX sencilla. (Los capítulos siguientes proporcionan una sesión SIP/PJSIP completa con todos los detalles). PJSIP se configura en `/etc/asterisk/pjsip.conf` y contiene todos los parámetros relacionados con los teléfonos SIP y los proveedores VoIP. Los clientes SIP deben configurarse antes de poder realizar y recibir llamadas.

#### El transporte

En PJSIP, la configuración del oyente (dirección de enlace, puerto, protocolo) reside en un objeto `transport`. Asterisk tiene protección integrada contra la adivinación de nombres de usuario: siempre devuelve un desafío de autenticación idéntico para usuarios conocidos y desconocidos, y las solicitudes no identificadas repetidas desde una misma IP están limitadas por tasa mediante las opciones `[global]` `unidentified_request_count`/`unidentified_request_period`. Las opciones principales de un transporte son:

- protocol: El protocolo de transporte: `udp`, `tcp`, `tls`, `ws` o `wss`.
- bind: Dirección y puerto a los que se vincula el oyente. Si establece la dirección en `0.0.0.0`, se vinculará a todas las interfaces; el puerto SIP predeterminado es 5060 para UDP/TCP.

Un transporte UDP mínimo:

```
[global]
type=global

[transport-udp]
type=transport
protocol=udp
bind=10.1.30.45:5060
```

La selección de codec (`disallow`/`allow`) y el `context` predeterminado se configuran en cada `endpoint` (que se muestra a continuación), no en el transporte. Las llamadas anónimas o de invitados son gestionadas por un `endpoint` llamado `anonymous`. Los temporizadores de registro se controlan por AOR mediante `maximum_expiration`/`default_expiration`.

#### Clientes SIP

Después de completar la sección de transporte, es momento de configurar los clientes SIP. Me gustaría recordar una vez más al lector que tendremos un capítulo completo de SIP/PJSIP más adelante en el libro. Por ahora, concentrémonos en lo básico y dejemos los detalles para después.

En PJSIP, un cliente SIP se construye a partir de un conjunto de objetos relacionados, vinculados entre sí por referencia de nombre:

- `endpoint`: El comportamiento de la llamada: codecs (`allow`/`disallow`), el dialplan `context` y qué `auth` y `aors` utiliza.
- `auth`: Las credenciales. `username` es el usuario de autenticación SIP y `password` es el secreto utilizado para autenticar el dispositivo.
- `aor`: La "dirección de registro" (address of record): dónde se puede contactar al endpoint. Ya sea un `contact=` estático (para un dispositivo con IP fija) o `max_contacts=` para permitir que el dispositivo se registre dinámicamente.

Advertencia: Utilice contraseñas seguras, de al menos 8 caracteres, que incluyan caracteres alfanuméricos y numéricos, y al menos un símbolo. Han aparecido informes de servidores hackeados en las listas de correo, y los programas de fuerza bruta para contraseñas SIP están fácilmente disponibles para usuarios inexpertos. El fraude de llamadas cuesta miles de dólares a consumidores y proveedores.

El endpoint 6000 es un dispositivo con IP fija, por lo que su AOR lleva un `contact` estático en lugar de permitir el registro. El endpoint 6001 es un dispositivo que se registra, por lo que su AOR le permite registrarse (`max_contacts=1`):

```
[6000]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6000-auth
aors=6000

[6000-auth]
type=auth
auth_type=digest
username=6000
password=#MySecret1#7

[6000]
type=aor
contact=sip:6000@10.1.30.50

[6001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=6001-auth
aors=6001

[6001-auth]
type=auth
auth_type=digest
username=6001
password=Mys3cr3t#

[6001]
type=aor
max_contacts=1
```

PJSIP permite que las secciones `endpoint`, `auth` y `aor` compartan el mismo nombre de sección (por ejemplo, los dos bloques `[6001]` anteriores, distinguidos por su `type=`); muchos administradores, en cambio, les añaden un sufijo (`[6001]`, `[6001-auth]`, `[6001]` aor) para facilitar la lectura. Para un dispositivo que se registra, el contacto se aprende dinámicamente cuando el teléfono se registra, por lo que el AOR no necesita un `contact` estático.

## Extensiones IAX

`chan_iax2` todavía se incluye en Asterisk 22, pero ahora es un protocolo heredado; SIP/PJSIP es el protocolo preferido para nuevas implementaciones.

También puede crear extensiones IAX. Este protocolo es nativo de Asterisk y tendremos una sección completa dedicada a él más adelante en este libro. Por ahora, creemos algunas extensiones utilizando el protocolo. Como la primera sección que se debe configurar, la sección [general] tiene ciertos parámetros que deben configurarse. Las opciones principales son:

- allow/disallow: Define qué codecs se van a utilizar.
- bindaddr: Dirección a la que se vincula el oyente IAX2. Si lo configura como 0.0.0.0 (predeterminado), se vinculará a todas las interfaces.
- context: Establece el context predeterminado para todos los clientes a menos que se cambie en la sección del cliente. Usamos dummy por razones de seguridad. Los usuarios no autenticados ingresan a este context cuando la opción allowguest se establece en yes.
- bindport: Puerto UDP de IAX2 en el que escuchar (predeterminado 4569).
- delayreject: Cuando se establece en yes, retrasa el envío de un rechazo de autenticación para un REGREQ o AUTHREQ, lo que mejora la seguridad contra ataques de fuerza bruta a contraseñas.
- bandwidth: Cuando se establece en high, permite la selección de codecs de gran ancho de banda, como g711 en sus variantes ulaw y alaw.

El siguiente es un ejemplo de la sección [general] del archivo iax.conf.

```
[general]
bindport = 4569
bindaddr = 10.1.30.45 ;(use your IP)
context = dummy
delayreject=yes
bandwidth=high
disallow = all
allow = ulaw
```

### Clientes IAX

Después de terminar las secciones generales, es hora de configurar los clientes IAX.

- `[name]`: El nombre de la sección es el nombre del peer/user IAX; una conexión IAX entrante se empareja con él por nombre.
- `type`: La clase de conexión — `peer`, `user` o `friend`:
  - `peer`: Asterisk envía llamadas a un peer.
  - `user`: Asterisk recibe llamadas de un user.
  - `friend`: ambas direcciones a la vez.
- `host`: Dirección IP o nombre de host. El valor más común es `dynamic`, utilizado cuando el dispositivo se registra en Asterisk.
- `secret`: Contraseña para autenticar peers y users.

Advertencia: Utilice contraseñas seguras con al menos 8 caracteres, caracteres alfanuméricos y numéricos, y al menos un símbolo. Han aparecido informes de servidores hackeados en las listas de correo, y existen herramientas de fuerza bruta para hashes md5 de IAX disponibles para script kiddies. El fraude de llamadas (toll fraud) cuesta miles de dólares a consumidores y proveedores. Ejemplo:

```
[guest]
type=user
context=dummy
callerid="Guest IAX User"
[6003]
type=friend
context=from-internal
secret=#sup3rs3cr3t#
host=dynamic
[6004]
type=friend
context=from-internal
secret=#s3cr3ts3cr3t#
host=dynamic
```

## Configuración de los dispositivos SIP

Después de definir los teléfonos en el archivo de configuración de Asterisk, es momento de configurar el teléfono en sí. En este ejemplo, mostraremos cómo configurar un softphone gratuito: el SipPulse Softphone (descárguelo desde https://www.sippulse.com/produtos/softphone). Consulte el manual de su dispositivo para comprender los parámetros de su teléfono. Paso 1: Configure el teléfono para usar la extension 6000. Ejecute el programa de instalación. Después de la ejecución, abra la configuración de cuenta/SIP y agregue una nueva cuenta SIP. Complete la información requerida.

![La pantalla de cuenta del SipPulse Softphone: ingrese el Server (su IP o dominio de Asterisk), Username, Password y Display Name, luego elija el Transport (UDP, TCP o TLS).](../images/softphone/sipphone-account.png){width=35%}

Display Name: 6000  User Name: 6000  Password: #MySecret1#7  Authorization User Name: 6000  Domain: ip_of_your_server. Confirme que su teléfono esté registrado usando el comando de consola `pjsip show endpoints` (o `pjsip show endpoint 6000` para más detalles; `pjsip show contacts` muestra los contactos AOR registrados). Repita la configuración para el teléfono 6001.

![Un SipPulse Softphone registrado: el punto verde y la línea de cuenta (`1001@softphone.sippulse.com.br`) confirman el registro; realice una llamada desde el teclado o los botones de llamada/video.](../images/softphone/sipphone-registered.png){width=35%}

## Configuración de los dispositivos IAX

IAX2 es un protocolo heredado (consulte el capítulo *Legacy channels*), y el Softphone SipPulse es solo SIP, por lo que no puede registrar una cuenta IAX. Si necesita probar IAX2, utilice un softphone que aún sea compatible con él. Cree una nueva cuenta IAX,

3. Seleccione una nueva cuenta IAX.
4. Inserte las opciones relacionadas para el teléfono 6003 y, opcionalmente, para el 6004.
5. Guarde la configuración y verifique si el teléfono está registrado usando `iax2 show peers`.

Importante: Utilice una cuenta para SIP y otra para IAX. Si desea configurar el sistema para que suenen tanto IAX como SIP al mismo tiempo, le mostraremos cómo hacerlo en la sección del dialplan.

### Configuración de una interfaz PSTN

Para conectarse a la PSTN, necesitará una interfaz de oficina de intercambio extranjero (FXO) y una línea telefónica. También puede utilizar una extension de una PBX existente. Puede obtener una tarjeta de interfaz de telefonía con una interfaz FXO de varios fabricantes. En este ejemplo, le mostraremos cómo instalar una tarjeta de interfaz DAHDI.

![Puertos FXS y FXO: el puerto FXS controla un teléfono analógico (suministra tono de marcado y timbre), mientras que el puerto FXO conecta Asterisk a la línea de la compañía telefónica.](FXS_FXO_ports.png)(../images/04-first-pbx-fig02.png)

### Líneas analógicas usando DAHDI

Puede comprar una tarjeta analógica compatible con DAHDI de varios fabricantes. La X100P fue una de las primeras tarjetas de Digium y ya ha sido descontinuada. Algunos fabricantes todavía producen clones similares. Además del precio de la X100P, hemos encontrado varios problemas entre estas tarjetas y las placas base nuevas, así que úsela con cuidado. La X100P, en mi opinión, no es una buena opción para un entorno de producción. Cualquier tarjeta compatible con DAHDI debería funcionar. Gracias al equipo de desarrolladores de DAHDI, ahora tenemos una herramienta para detectar y configurar las tarjetas de interfaz casi automáticamente. Si acaba de instalar los controladores DAHDI, no olvide ejecutar make config y reiniciar la máquina para cargarlos automáticamente. Puede usar los comandos a continuación para detectar y configurar su tarjeta. Paso 1: Para detectar su hardware, use:

```
dahdi_hardware
```

Paso 2: Para configurar use:

```
dahdi_genconf
```

El comando anterior generará dos archivos /etc/dahdi/system.conf y /etc/asterisk/dahdi-channels.conf. Los parámetros predeterminados para dahdi_genconf suelen ser correctos, pero puede cambiarlos en el archivo /etc/dahdi/genconf_parameters. De forma predeterminada, insertará las líneas (FXO) en el context from-pstn y los teléfonos (FXS) en el context from-internal. Paso 3: Después de ejecutar dahdi_genconf, en la última línea del archivo /etc/asterisk/chan_dahdi.conf inserte la siguiente línea:

```
#include dahdi-channels.conf
```

Paso 4: Edite el archivo /etc/dahdi/modules y comente todos los controladores no utilizados. Reinicie antes de continuar y verifique si los canales están siendo reconocidos usando:

```
*CLI> dahdi show channels
```

### Conexión a la PSTN mediante un proveedor VoIP

Si su presupuesto es realmente limitado, puede configurar un trunk SIP para conectarse a la PSTN. Es sin duda la forma más asequible de conectarse a la PSTN. Existen miles de proveedores de VoIP en todo el mundo. Para conectarse a uno de ellos, necesitará algunos parámetros. Parámetros proporcionados por el proveedor SIP.

- username: login
- password: secret
- Provider’s domain: domain
- UDP port: 5060
- Allowed codecs: g729, ilbc, alaw

Dos parámetros deben ser determinados por usted.

- Extension para recibir llamadas—en este caso: 9999
- context: from-sip

En PJSIP, un trunk SIP de registro se construye a partir de la misma familia de objetos utilizada para un endpoint, además de objetos explícitos `registration` y `identify`. El objeto `registration` le dice a Asterisk que se registre en el proveedor, el objeto `identify` hace coincidir el tráfico entrante desde la IP del proveedor con el endpoint (PJSIP autentica los INVITE entrantes por IP de origen), y `outbound_auth` suministra las credenciales para llamadas salientes y registro:

```
[siptrunk]
type=endpoint
context=from-sip
disallow=all
allow=ilbc
allow=alaw
allow=g729
dtmf_mode=rfc4733
outbound_auth=siptrunk-auth
aors=siptrunk
from_user=login
from_domain=domain

[siptrunk-auth]
type=auth
auth_type=digest
username=login
password=secret

[siptrunk]
type=aor
contact=sip:domain:5060

[siptrunk]
type=identify
endpoint=siptrunk
match=domain

[siptrunk-reg]
type=registration
transport=transport-udp
outbound_auth=siptrunk-auth
server_uri=sip:domain:5060
client_uri=sip:login@domain:5060
contact_user=9999
retry_interval=60
```

Para acceder a este trunk, utilizaremos el nombre de canal `PJSIP/siptrunk`. El ajuste `dtmf_mode=rfc4733` transporta DTMF fuera de banda (RFC 4733 reemplaza al antiguo RFC 2833; la carga útil es idéntica). La opción `identify`/`match` acepta direcciones IP, CIDR o nombres de host, pero los nombres de host se resuelven una vez en el momento de la carga de la configuración, por lo que para un proveedor con IPs cambiantes, enumere la(s) IP(s) de señalización explícitamente. Confirme el registro con `pjsip show registrations`.

## Introducción al dialplan

El dialplan es como el corazón de Asterisk. Define cómo Asterisk maneja cada llamada que llega a la PBX. Consiste en extensiones que crean una lista de instrucciones para que Asterisk las siga. Las instrucciones se ejecutan mediante dígitos recibidos desde el canal o la aplicación. Para configurar Asterisk con éxito, es crucial entender el dialplan. La mayor parte del dialplan está contenida en el archivo extensions.conf en el directorio /etc/asterisk. Este archivo utiliza una gramática de grupos sencilla y tiene cuatro conceptos principales:

- Extensions
- Priorities
- Applications
- Contexts

Vamos a crear un dialplan básico. En secciones posteriores de este libro, dedicaré un capítulo exclusivamente al dialplan. Si instaló los archivos de ejemplo (make samples), el archivo extensions.conf ya existe. Guárdelo con otro nombre y comience con un archivo en blanco.

## La estructura del archivo extensions.conf

El archivo extensions.conf está separado en secciones. La primera es la sección [general] seguida por la sección [globals]. El inicio de cada sección comienza con la definición de su nombre (es decir, [default]) y termina cuando se crea otra sección.

### La sección [general]

La sección general se encuentra en la parte superior del archivo. Antes de comenzar a configurar el dialplan, es útil conocer las opciones generales que controlan ciertos comportamientos del dialplan. Estas opciones son:

- static y write protect: Si `static=yes` y `writeprotect=no`, puede guardar el dialplan en ejecución de vuelta al disco con el comando de CLI:

```
*CLI> dialplan save
```

Advertencia: Si ejecuta un comando `dialplan save` desde la CLI, perderá todas las observaciones y comentarios en el archivo.

- autofallthrough: Si autofallthrough está configurado, entonces si una extension se queda sin tareas por realizar, terminará la llamada con BUSY, CONGESTION o HANGUP dependiendo de la mejor estimación de Asterisk. Este es el valor predeterminado. Si autofallthrough no está configurado, entonces si una extension se queda sin tareas por realizar, Asterisk esperará a que se marque una nueva extension.
- clearglobalvars: Si clearglobalvars está configurado, las variables globales se borrarán y se volverán a analizar ante un dialplan reload o Asterisk reload. Si clearglobalvars no está configurado, entonces las variables globales persistirán a través de las recargas y, incluso si se eliminan de extensions.conf o de uno de sus archivos incluidos, permanecerán configuradas con el valor anterior.
- extenpatternmatchnew: Utiliza un algoritmo de coincidencia de patrones más rápido, lo que ayuda notablemente cuando se tiene una gran cantidad de extensions. El valor predeterminado es no.
- userscontext: Este es el context donde se registran las entradas de users.conf.

### La sección [globals]

En la sección [globals] definirá las variables globales y sus valores iniciales. Puede acceder a la variable en el dialplan utilizando ${GLOBAL(variable)}. Incluso puede acceder a variables definidas en el entorno linux/unix utilizando ${ENV(variable)}. Las variables globales no distinguen entre mayúsculas y minúsculas. Algunos ejemplos podrían ser:

```
INCOMING=>DAHDI/8&DAHDI/9
RINGTIME=>3
```

En el siguiente ejemplo, puede configurar y probar una variable global en el dialplan.

```
exten=9000,1,set(GLOBAL(RINGTIME)=4)
exten=9000,n,Noop(${GLOBAL(RINGTIME)})
exten=9000,n,hangup()
```

## Contexts

Context es la partición nombrada del dialplan. Después de las secciones [general] y [globals], el dialplan es un conjunto de contexts en los cuales cada context tiene varias extensions, cada extension tiene varias priorities, y cada priority llama a una aplicación con varios argumentos.

![Flujo de llamadas de Asterisk: cada llamada llega a un canal (IAX, SIP, y otros) como un tramo de llamada entrante; el context del canal —configurado globalmente o por canal en el archivo de configuración del canal— decide qué context en extensions.conf procesa la llamada antes de que salga por el tramo saliente.](../images/04-first-pbx-fig03.png)

![Procesamiento de llamadas: el `context=` definido para un canal (en chan_dahdi.conf o pjsip.conf) nombra el context coincidente en extensions.conf donde el dialplan maneja la llamada.](../images/04-first-pbx-fig04.png)

Puede construir un dialplan simple para comunicarse con otros teléfonos y la PSTN. Sin embargo, Asterisk es mucho más potente que eso. Nuestro objetivo es enseñarle más detalles de lo que es posible en el dialplan.

## Extensions

A diferencia de los PBX tradicionales, donde las extensiones están asociadas a teléfonos, interfaces, menús, etc., en Asterisk una extension es una lista de comandos que se procesan cuando se activa un número o nombre de extension específico. Los comandos se procesan en orden de prioridad.

![Sintaxis de extension: `exten => number(name),{priority|label}[(alias)],application`. Las extensiones pueden ser numéricas, alfanuméricas, numéricas con caller ID, un patrón o una extension estándar como `s`; las prioridades pueden ser un número, `n` (siguiente), `s` (misma), un desplazamiento o un `hint`.](../images/04-first-pbx-fig05.png)

Una extension puede ser literal, estándar o especial. Una extension estándar incluye solo números o nombres y los caracteres * y #; 12#89* es una extension literal válida. Los nombres también pueden utilizarse para la coincidencia de extensiones. Las extensiones distinguen entre mayúsculas y minúsculas. Sin embargo, no se pueden crear dos extensiones con el mismo nombre pero diferente uso de mayúsculas. Cuando se marca una extension, se ejecuta el comando con la primera prioridad, seguido del comando con prioridad 2 y así sucesivamente. Esto ocurre hasta que la llamada se desconecta o algún comando devuelve el número uno, indicando un fallo. Lo que hace Asterisk cuando se ejecuta la última prioridad está regulado por el parámetro autofallthrough. Consulte la sección [general] en este capítulo. Ejemplo:

```
exten=>123,1,Answer
exten=>123,n,Playback(tt-weasels)
exten=>123,n,Hangup
```

Arriba encontrará la lista de instrucciones que se procesarán cuando se marque la extension 123. La primera prioridad es contestar el canal (necesario cuando el canal está en estado de llamada: es decir, canales FXO). La segunda prioridad es reproducir un archivo de audio llamado tt-weasels. La tercera prioridad cuelga el canal. Otra opción es manejar la llamada de acuerdo con el caller ID. Puede utilizar el carácter / para especificar el caller ID que se debe procesar. Ejemplos:

```
exten=>123/100,1,Answer()
exten=>123/100,n,Playback(tt-weasels)
exten=>123/100,n,Hangup()
```

Este ejemplo activará la extension 123 y ejecutará las siguientes opciones solo si el caller ID es 100. Esto también se puede hacer utilizando el patrón descrito a continuación:

```
exten=>1234/_256NXXXXXX,1,Answer()
```

hint: asigna una extension a un canal. Se utiliza para monitorear el estado del canal. Se utiliza junto con la presencia. El teléfono debe ser compatible con esto.

#### Patrones

Puede utilizar patrones y literales en el dialplan. Los patrones son muy útiles para reducir el tamaño del dialplan. Todos los patrones comienzan con el carácter “_”. Se pueden utilizar los siguientes caracteres para definir un patrón. La figura identifica los patrones disponibles para su uso con Asterisk.

![Caracteres de coincidencia de patrones: `_` inicia un patrón, `.` coincide con uno o más caracteres, `!` coincide con cero o más, `[123-7]` coincide con cualquier dígito o rango listado, `X` es 0-9, `Z` es 1-9 y `N` es 2-9 — con ejemplos que mapean rangos de extensiones de oficina.](../images/04-first-pbx-fig06.png)

### Extensiones especiales

Asterisk utiliza algunos nombres de extensiones como extensiones estándar.

![Extensiones especiales de Asterisk: `i` (inválida), `s` (inicio), `h` (colgar), `t` (tiempo de espera), `T` (tiempo de espera absoluto), `o` (operador), `a` (presionado `*` en voicemail), `fax` (detección de fax) y `Talk` (utilizado con BackgroundDetect).](../images/04-first-pbx-fig07.png)

Descripción:

- **s**: Inicio (Start). Se utiliza para manejar una llamada cuando no hay un número marcado. Es útil para trunks FXO y procesamiento dentro de menús.
- **t**: Tiempo de espera (Timeout). Se utiliza cuando las llamadas permanecen inactivas después de que se ha reproducido un mensaje. También se utiliza para colgar una línea inactiva.
- **T**: Tiempo de espera absoluto (AbsoluteTimeout). Si establece un límite de llamada utilizando la función de dialplan `TIMEOUT(absolute)`, una vez que la llamada exceda el límite definido, se enviará a la extension T.
- **h**: Colgar (Hangup). Se llama después de que el usuario desconecta la llamada.
- **i**: Inválida (Invalid). Se activa cuando llama a una extension inexistente en el context. El uso de estas extensiones puede afectar el contenido de los registros CDR; específicamente, el dst que no contiene el número marcado.
- **o**: Operador (Operator). Se utiliza para ir al operador cuando el usuario presiona "0" durante el voicemail.

El uso de estas extensiones puede cambiar el contenido de los registros de facturación (CDR); en particular, el campo dst no tendrá el número marcado. Para solucionar este problema, debe utilizar la opción g en la aplicación dial() y considerar las funciones resetcdr(w) y/o nocdr()

## Variables

En el PBX Asterisk, las variables pueden ser globales, específicas de un canal y específicas del entorno. Puede utilizar la aplicación NoOP() para ver el contenido de una variable en la consola. Puede usar una variable global o una variable específica de un canal como argumentos de las aplicaciones. Una variable puede ser referenciada como en el siguiente ejemplo, donde varname es el nombre de la variable.

```
${varname}
```

Un nombre de variable puede ser una cadena alfanumérica que comience con una letra. Los nombres de variables globales no distinguen entre mayúsculas y minúsculas. Sin embargo, las variables del sistema (las definidas por Asterisk son definidas por el canal) sí distinguen entre mayúsculas y minúsculas. Por lo tanto, la variable ${EXTEN} es diferente de ${exten}.

### Global variables

Las variables globales pueden configurarse en la sección [global] en el archivo extensions.conf o utilizando la aplicación:

```
set(Global(variable)=content)
```

### Channel-specific variables

Las variables específicas de un canal se configuran utilizando la aplicación set(). Cada canal recibe su propio espacio de variables. No hay posibilidad de colisiones entre variables de diferentes canales. Una variable específica de un canal se destruye cuando el canal cuelga. Algunas de las variables más utilizadas son:

- ${EXTEN} Extensión marcada
- ${CONTEXT} Contexto actual
- ${CALLERID(name)}
- ${CALLERID(num)}
- ${CALLERID(all)} Identificador de llamadas actual
- ${PRIORITY} Prioridad actual

Otras variables específicas de un canal están todas en mayúsculas. Puede ver el contenido de varias variables utilizando la aplicación dumpchan(). A continuación se muestra un extracto simple de las variables de dump-channel.

```
exten=9001,1,DumpChan()
exten=9001,n,Echo()
exten=9001,n,Hangup()
```

Salida de dumpchan:

```
Dumping Info For Channel: PJSIP/4400-00000001:
================================================================================
Info:
Name=               PJSIP/4400-00000001
Type=               PJSIP
UniqueID=           1161186526.1
LinkedID=           1161186526.0
CallerIDNum=        4400
CallerIDName=       laptop
ConnectedLineIDNum= (N/A)
ConnectedLineIDName=(N/A)
DNIDDigits=         9001
RDNIS=              (N/A)
Parkinglot=
Language=           en
State=              Ring (4)
Rings=              0
NativeFormat=       (ulaw)
WriteFormat=        ulaw
ReadFormat=         ulaw
RawWriteFormat=     ulaw
RawReadFormat=      ulaw
WriteTranscode=     No
ReadTranscode=      No
1stFileDescriptor=  16
Framesin=           0
Framesout=          0
TimetoHangup=       0
ElapsedTime=        0h0m0s
BridgeID=           (Not bridged)
Context=            default
Extension=          9001
Priority=           1
CallGroup=
PickupGroup=
Application=        DumpChan
Data=               (Empty)
Blocking_in=        (Not Blocking)
Variables:
```

El diseño de campo anterior es la salida de Asterisk 22 `DumpChan` (un nombre de canal `PJSIP/...` real, los campos `CallerIDNum`/`ConnectedLineID` y las filas `Raw*`/`Transcode`/`BridgeID` que los canales PJSIP completan). A diferencia del controlador antiguo, un canal PJSIP no establece automáticamente las variables de canal `SIPCALLID`/`SIPUSERAGENT`; los detalles SIP equivalentes se leen bajo demanda con las funciones de dialplan `PJSIP_HEADER()` y `CHANNEL()` — por ejemplo `${CHANNEL(pjsip,call-id)}`, `${PJSIP_HEADER(read,User-Agent)}` y `${CHANNEL(rtp,dest)}` para la dirección RTP remota.

### Environment-specific variables

Las variables específicas del entorno pueden utilizarse para acceder a variables definidas en el sistema operativo. Puede establecer variables específicas del entorno utilizando la función ENV(). Por ejemplo:

```
${ENV(LANG)}
Set(ENV(LANG)=en_US)
```

### Application-specific variables

Algunas aplicaciones utilizan variables para la entrada y salida de datos. Puede establecer variables antes de llamar a la aplicación o recuperar la variable después de la ejecución de la aplicación. Por ejemplo: La aplicación Dial devuelve las siguientes variables:

- ${DIALEDTIME} -> Este es el tiempo desde que se marca un canal hasta que se desconecta.
- ${ANSWEREDTIME} -> Esta es la cantidad de tiempo de la llamada real.
- ${DIALSTATUS} Este es el estado de la llamada: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE
- ${CAUSECODE} -> Mensaje de error para la llamada.

## Expresiones

Las expresiones pueden ser muy útiles en el dialplan. Se utilizan para manipular cadenas de texto y realizar operaciones matemáticas y lógicas.

![Descripción general de las expresiones de Asterisk — `$[expression1 operator expression2]` — agrupación de los operadores matemáticos, lógicos, de comparación, de expresiones regulares y condicionales disponibles en el dialplan.](../images/04-first-pbx-fig08.png)

La sintaxis de las expresiones se define de la siguiente manera:

```
$[expression1 operator expression2]
```

Supongamos que tenemos una variable llamada “I” y queremos sumarle 100 a dicha variable:

```
$[${I}+100]
```

Cuando Asterisk encuentra una expresión en el dialplan, reemplaza la expresión completa por el valor resultante.

### Operadores

Los siguientes operadores pueden utilizarse para construir expresiones. Es importante observar la precedencia de los operadores.

1. Paréntesis “()”
2. Operadores unarios “! -“
3. Expresión regular “: =~
4. Operadores multiplicativos “* / %”
5. Operadores aditivos “+ -“
6. Operadores de comparación
7. Operadores lógicos
8. Operadores condicionales

#### Operadores matemáticos

- Suma (+)
- Resta (-)
- Multiplicación (*)
- División (/)
- Módulo (%)

#### Operadores lógicos

- “AND” lógico (&)
- “OR” lógico (|)
- Complemento unario lógico (!)

#### Operadores de expresiones regulares

- Coincidencia de expresión regular (:)
- Coincidencia exacta de expresión regular (=~)

Una expresión regular es una cadena de texto especial utilizada para describir un patrón de búsqueda. Puede pensar en las expresiones regulares como comodines. Las expresiones regulares se utilizan para comparar una cadena con un patrón y verificar la coincidencia. Si la coincidencia tiene éxito y la expresión regular contiene al menos una coincidencia, se devuelve la primera coincidencia; de lo contrario, el resultado es el número de caracteres que coincidieron.

#### Operadores de comparación

El resultado de una comparación es 1 si la relación es verdadera o 0 si es falsa.

- = igual
- != no es igual
- < menor que
- > mayor que
- <= menor o igual que
- >= mayor o igual que

### LAB. Evalúe las siguientes expresiones:

Coloque estas expresiones en su dialplan y utilice la aplicación NoOP() para evaluar las expresiones. Marque 9002 y examine los resultados en la consola de Asterisk. Utilice verbose 15 para mostrar los resultados.

```
exten=9002,1,set(NAME="FLAVIO")                 ;Set NAME=FLAVIO
exten=9002,n,set(I=4)
exten=9002,n,set(URI="40001@voip.school")
exten=9002,n,NoOP(${NAME})
exten=9002,n,NoOP(${I})
exten=9002,n,NoOP($[${I}+${I}])
exten=9002,n,NoOP($[${I}=4])
exten=9002,n,NoOP($[${I}=4 & ${NAME}=FLAVIO])
exten=9002,n,NoOP($[${URI} =~ "4[0-9][0-9][0-9][0-9]@."])
exten=9002,n,NoOP($[${I}=4?"MATCH"::"DO NOT MATCH"])
exten=9002,n,hangup
```

## Funciones

Algunas aplicaciones han sido reemplazadas por funciones, las cuales permiten el procesamiento de variables de una manera más avanzada que las expresiones por sí solas. Puede ver la lista completa de funciones ejecutando el siguiente comando en la consola:

```
*CLI> core show functions
```

Longitud de cadena: ${LEN(string)} devuelve la longitud de la cadena

```
Example:
exten=>100,1,Set(Fruit=pear)
exten=>100,2,NoOp(${LEN(Fruit)})
exten=>100,3,NoOp(${LEN(${Fruit})})
```

En la primera operación, el sistema muestra 5 como resultado (el número de letras en la palabra “fruit”). La segunda devuelve el número 4 (el número de letras en la palabra “pear”). Subcadenas: Devuelve la subcadena, comenzando desde la posición definida por el parámetro “offset”, con la longitud de cadena definida en el parámetro “length”. Si el offset es negativo, comienza de derecha a izquierda, empezando al final de la cadena. Si se omite la longitud o es negativa, toma toda la cadena comenzando desde el offset.

```
${string:offset:length }
```

Ejemplo #1: Varias subcadenas

```
${123456789:1}-returns 23456789
${123456789:-4}-returns 6789
${123456789:0:3}-returns 123
${123456789:2:3}-returns 345
${123456789:-4:3}-returns 678
```

Ejemplo #2: Tomar el código de área de los primeros tres dígitos.

```
exten=>_NXX.,1,Set(areacode=${EXTEN:0:3})
```

Ejemplo #3: Toma todos los dígitos de la variable ${EXTEN}, excepto el código de área.

```
exten=>_516XXXXXXX,1,Dial(${EXTEN:3})
```

### Concatenación de cadenas

Para concatenar dos cadenas, simplemente escríbalas juntas.

```
${foo}${bar}
555${number}
${longdistanceprefix}555${number}
```

## Aplicaciones

Para construir un dialplan, necesitamos entender el concepto de aplicaciones. Usted utilizará aplicaciones para manejar el canal en el dialplan. Las aplicaciones se implementan en varios módulos. Las aplicaciones disponibles dependen de los módulos. Puede mostrar todas las aplicaciones de Asterisk usando el comando de consola:

```
*CLI> core show applications
```

Alternativamente, puede mostrar los detalles de una aplicación específica usando el siguiente ejemplo:

```
*CLI> core show application Dial
```

Para construir un dialplan simple, necesita conocer algunas aplicaciones. Discutiremos ejemplos más avanzados más adelante en el libro.

![El puñado de aplicaciones necesarias para construir un dialplan simple: Answer (contestar un canal), Dial (llamar a otro canal), Hangup (colgar un canal), Playback (reproducir un archivo de audio) y Goto (saltar a una prioridad, extension o context).](../images/04-first-pbx-fig09.png)

Usaremos estas aplicaciones (arriba) para crear un dialplan simple para dos PBX básicos.

### Answer()

[Sinopsis] Contesta un canal si está sonando [Descripción] Answer([delay]): Si la llamada no ha sido contestada, la aplicación la contestará. De lo contrario, no tiene efecto en la llamada. Si se especifica un retraso (delay), Asterisk esperará el número de milisegundos especificado en ‘delay’ antes de contestar la llamada.

### Dial()

La siguiente descripción se puede obtener emitiendo show application dial en el dialplan. Para facilitar la búsqueda, se reproduce a continuación. La sintaxis para la aplicación Dial también se muestra a continuación:

```
;dial to a single channel
Dial(Technology/resource,timeout,options,URL)
;dialing to multiple channels
Dial(Technology/resource[&Tech2/resource2...],timeout,options,URL)
```

Esta aplicación realizará llamadas a uno o más canales especificados. Tan pronto como uno de los canales solicitados conteste, el canal de origen será contestado, si es que aún no lo ha sido. Estos dos canales estarán entonces activos en una llamada puenteada. Todos los demás canales solicitados serán colgados. A menos que se especifique un tiempo de espera (timeout), la aplicación Dial esperará indefinidamente hasta que uno de los canales llamados conteste, el usuario cuelgue, o todos los canales llamados estén ocupados o no disponibles. La ejecución del dialplan continuará si no se puede llamar a ninguno de los canales solicitados o si el tiempo de espera expira. Esta aplicación establece las siguientes variables de canal al finalizar:

- DIALEDTIME - Este es el tiempo desde que se marca un canal hasta el momento en que se desconecta.
- ANSWEREDTIME - Esta es la cantidad de tiempo de una llamada real.
- DIALSTATUS - Este es el estado de la llamada: o CHANUNAVAIL o CONGESTION o NOANSWER o BUSY o ANSWER o CANCEL o DONTCALL o TORTURE

Para los modos de privacidad y filtrado (Privacy and Screening Modes), la variable DIALSTATUS se establecerá en DONTCALL si la parte llamada elige enviar a la parte que llama al script 'Go Away'. La variable DIALSTATUS se establecerá en TORTURE si la parte llamada desea enviar a la persona que llama al script 'torture'. Esta aplicación informará una terminación normal si el canal de origen cuelga o si la llamada está puenteada y cualquiera de las partes en el puente termina la llamada. La URL opcional se enviará a la parte llamada si el canal la admite. Si la variable OUTBOUND_GROUP está establecida, todos los canales pares creados por esta aplicación se incluirán en ese grupo (como en

```
Set(GROUP()=...).
```

La siguiente tabla resume algunas de las opciones utilizadas con más frecuencia para la aplicación Dial. Para obtener la lista completa, utilice el comando de consola `core show application Dial`. En Asterisk 22, estas opciones se separan del canal y del tiempo de espera mediante comas; por ejemplo, `Dial(PJSIP/2000,20,tTm)`.

| Opción | Descripción |
|--------|-------------|
| `A(x)` | Reproduce un anuncio a la parte llamada, usando `x` como archivo. |
| `C` | Restablece el CDR para esta llamada. |
| `d` | Permite al usuario que llama marcar una extension de 1 dígito mientras espera a que se conteste la llamada. Sale a esa extension si existe en el context actual, o al context definido en la variable `EXITCONTEXT`, si existe. |
| `D([called][:calling])` | Envía las cadenas DTMF especificadas después de que la parte llamada conteste, pero antes de que la llamada sea puenteada. La cadena `called` se envía a la parte llamada y la cadena `calling` a la parte que llama. Cualquiera de los parámetros puede usarse por separado. |
| `f` | Fuerza a que el identificador de llamadas (caller ID) del canal que llama se establezca en la extension asociada con el canal a través de un dialplan `hint`. Útil donde la PSTN no permite un identificador de llamadas arbitrario. |
| `g` | Procede con la ejecución del dialplan en la extension actual si el canal de destino cuelga. |
| `G(context^exten^pri)` | Si la llamada es contestada, transfiere a la parte que llama a la prioridad especificada y a la parte llamada a prioridad+1. Opcionalmente se puede especificar una extension (o extension y context); de lo contrario, se utiliza la extension actual. |
| `h` | Permite a la parte llamada colgar enviando el dígito DTMF `*`. |
| `H` | Permite a la parte que llama colgar enviando el dígito DTMF `*`. |
| `L(x[:y][:z])` | Limita la llamada a `x` ms, reproduce una advertencia cuando quedan `y` ms, y repite la advertencia cada `z` ms. Vea las variables `LIMIT_*` a continuación. |
| `m([class])` | Proporciona música en espera (MusicOnHold) a la parte que llama hasta que el canal solicitado conteste. Se puede especificar una clase de MusicOnHold específica. |
| `r` | Indica tono de llamada a la parte que llama y no pasa audio hasta que el canal llamado conteste. |
| `S(x)` | Cuelga la llamada `x` segundos después de que la parte llamada conteste. |
| `t` | Permite a la parte llamada transferir a la parte que llama enviando la secuencia DTMF definida en `features.conf`. |
| `T` | Permite a la parte que llama transferir a la parte llamada enviando la secuencia DTMF definida en `features.conf`. |
| `w` | Permite a la parte llamada habilitar la grabación de un toque enviando la secuencia DTMF definida en `features.conf`. |
| `W` | Permite a la parte que llama habilitar la grabación de un toque enviando la secuencia DTMF definida en `features.conf`. |
| `k` | Permite a la parte llamada estacionar la llamada enviando la secuencia DTMF definida para el estacionamiento de llamadas en `features.conf`. |
| `K` | Permite a la parte que llama estacionar la llamada enviando la secuencia DTMF definida para el estacionamiento de llamadas en `features.conf`. |

La opción `L(x[:y][:z])` se puede ajustar con las siguientes variables especiales:

- `LIMIT_PLAYAUDIO_CALLER` — `yes|no` (predeterminado `yes`): reproduce sonidos para quien llama.
- `LIMIT_PLAYAUDIO_CALLEE` — `yes|no`: reproduce sonidos para la parte llamada.
- `LIMIT_TIMEOUT_FILE` — archivo que se reproducirá cuando se agote el tiempo.
- `LIMIT_CONNECT_FILE` — archivo que se reproducirá cuando comience la llamada.
- `LIMIT_WARNING_FILE` — archivo que se reproducirá como advertencia cuando se define `y`. El valor predeterminado es decir el tiempo restante.

Ejemplo:

```
exten=_4XXX,1,Dial(PJSIP/${EXTEN},20,tTm)
```

En el ejemplo anterior, la aplicación llamará al canal PJSIP correspondiente. Tanto quien llama como quien es llamado podrían transferir la llamada (Tt). Se escuchará música en espera en lugar del tono de llamada. Si nadie contesta dentro de 20 segundos, la extension pasará a la siguiente prioridad.

### Hangup()

Cuelga el canal que llama [Descripción] Hangup([causecode]): Esta aplicación colgará el canal que llama. Si se proporciona un código de causa, la causa de desconexión del canal se establecerá en el valor dado.

### Goto()

Salta a una prioridad, extension o context en particular [Descripción] Goto([[context|]extension|]priority): Esta aplicación hará que el canal que llama continúe la ejecución del dialplan en la prioridad especificada. Si no se especifica una extension específica (o extension y context), esta aplicación saltará a la prioridad especificada de la extension actual. Si el intento de saltar a otra ubicación en el dialplan no tiene éxito, el canal continuará en la siguiente prioridad de la extension actual.

## Construcción de un dialplan

Para construir un dialplan sencillo, debe tratar todas las llamadas entrantes y salientes creando contexts y extensions. En esta sección, le mostraremos cómo construir las extensions más comunes.

### Llamadas entre extensions

Para habilitar las llamadas entre extensions, podríamos usar la variable de canal ${EXTEN}, que hace referencia a la extension marcada. Por ejemplo, si el rango de extensiones está entre 4000 y 4999 y todas las extensiones usan SIP, podríamos adoptar el siguiente comando:

```
[from-internal]
exten=_4XXX,1,Dial(PJSIP/${EXTEN})
```

### Llamadas a un destino externo

Para marcar a un destino externo, puede anteponer al número marcado una ruta. En Norteamérica, es común usar 9 seguido del número que se desea marcar externamente. Si está utilizando un canal analógico o digital hacia la PSTN, el comando debería verse de la siguiente manera: Si desea utilizar el trunk SIP en lugar de DAHDI, utilice el canal `PJSIP/...@siptrunk`.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/1/${EXTEN:1},20,tT)
or
exten=_9NXXXXXX,1,Dial(PJSIP/${EXTEN:1}@siptrunk,20,tT)
```

La línea anterior le permitirá marcar 9 y el número deseado. En el ejemplo dado, utilizará el primer canal DAHDI (DAHDI/1). Si tiene varias líneas y esta está ocupada, la llamada no se completará. Sin embargo, podría usar la siguiente línea para elegir automáticamente el primer canal DAHDI disponible. Opcionalmente, puede usar el trunk SIP en lugar de DAHDI. En la forma PJSIP `Dial(PJSIP/number@siptrunk,...)`, el número marcado es la parte del usuario y `siptrunk` es el endpoint configurado anteriormente.

```
[from-internal]
exten=_9NXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

El parámetro “g1” buscará el primer canal disponible en el grupo, permitiendo el uso de todos los canales. Usando la línea de abajo, podría marcar un número de larga distancia.

```
[from-internal]
exten=_91NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20,tT)
```

### Marcar 9 para obtener una línea PSTN

Si no tiene ninguna restricción para llamadas externas, podría simplificar y usar lo siguiente:

```
[from-internal]
exten=9,1,Dial(DAHDI/g1,20,tT)
```

### Recibir una llamada en la extension de la operadora

En el siguiente ejemplo, la extension de la operadora es 4000. La línea PSTN está conectada a una interfaz FXO. En el archivo chan_dahdi.conf, el context especificado es from-pstn. Cualquier llamada que provenga de la PSTN será enrutada al context from-pstn en el dialplan. Esta línea no tiene DID (direct inward dialing); por lo tanto, tendremos que recibir la llamada a través de la extension “s”. Si recibe desde el trunk SIP, use el context [from-sip].

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
[from-sip]
exten = s,1,Dial(${OPERATOR},40,tT)
exten = s,n,Hangup()
```

### Recibir una llamada usando DID (direct inward dialing)

Si tiene una línea digital, recibirá la extension marcada. Cuando este es el caso, no necesita reenviar la llamada a la operadora; más bien, puede reenviar la llamada directamente al destino. Suponga que su rango DID es de 3028550 a 3028599 y los últimos cuatro números se pasan en el DID. La configuración se vería como el siguiente ejemplo:

```
[from-pstn]
exten => _85[5-9]X,1,Answer()
exten => _85[5-9]X,n,Dial(PJSIP/${EXTEN},15,tT)
exten => _85[5-9]X,n,Hangup()
```

### Llamar a varias extensiones simultáneamente

Puede configurar Asterisk para llamar a una extension y, si no es contestada, llamar a varias otras extensiones simultáneamente, como se indica en el siguiente ejemplo:

```
exten => 0,1,Dial(DAHDI/1,15,tT)
exten => 0,n,Dial(DAHDI/1&DAHDI/2&DAHDI/3,15)
exten => 0,n,Hangup()
```

En este ejemplo, cuando alguien llama a la operadora, inicialmente se intenta el canal DAHDI/1. Si nadie contesta después de 15 segundos (timeout), los canales DAHDI/1, DAHDI/2 y DAHDI/3 sonarán simultáneamente por otros 15 segundos.

### Enrutamiento por Caller ID

En este ejemplo, podría dar diferentes tratamientos basados en el Caller ID, lo cual podría ser útil para spammers de llamadas. Por ejemplo:

```
exten => 8590/4832518888,1,Playback(I-have-moved-to-china)
exten => 8590,1,Dial(DAHDI/1,20)
```

En este ejemplo, hemos añadido una regla especial que, si el Caller ID es 4832518888, reproduce un mensaje del archivo previamente grabado “I-have-moved-to-china”. Otras llamadas son aceptadas como de costumbre.

### Uso de variables en el dialplan

Asterisk puede usar variables globales y de canal en el dialplan como argumentos para ciertas aplicaciones. Observe los siguientes ejemplos:

```
[globals]
Flavio => DAHDI/1
Daniel => DAHDI/2&PJSIP/pingtel
Anna => DAHDI/3
Christian => DAHDI/4
[mainmenu]
exten => 1,1,Dial(${Daniel}&${Flavio})
exten => 2,1,Dial(${Anna}&${Christian})
exten => 3,1,Dial(${Anna}&${Flavio})
```

El uso de variables facilita los cambios futuros. Si cambia la variable, todas las referencias se cambian inmediatamente.

### Grabación de un anuncio

En algunas de las opciones discutidas más adelante en esta sección, usaremos prompts grabados. Aquí le mostramos una forma sencilla de grabarlos. Usaremos la aplicación Record() para guardar el anuncio usando el propio teléfono.

```
[from-internal]
exten => _record.,1,Record(${EXTEN:6}:gsm)
exten => _record.,n,wait(1)
exten => _record.,n,Playback(${EXTEN:6})
exten => _record.,n,Hangup()
```

Estas instrucciones le permiten grabar cualquier mensaje desde un softphone. Ejemplo: marcando recordmenu desde el softphone. Las instrucciones llamarán a la grabación con la variable ${EXTEN:6} sin las primeras seis letras. En otras palabras, la instrucción es equivalente a record(menu:gsm). Todo lo que tiene que hacer es marcar record + nombre_del_archivo_a_grabar, presionar # para finalizar la grabación y esperar a escuchar la grabación.

### Recibir las llamadas en una recepcionista digital

Ahora que tenemos algunos ejemplos sencillos, expandamos nuestro aprendizaje sobre las aplicaciones background() y goto(). La clave para los sistemas interactivos en Asterisk es la aplicación background(), que le permite ejecutar un archivo de audio que, cuando la persona que llama presiona una tecla, se interrumpe para enviar la llamada a la extension marcada. Sintaxis de la aplicación background():

```
exten=>extension, priority, background(filename)
```

Otra aplicación muy útil es goto(). Como su nombre indica, salta al context, extension y prioridad indicados. Sintaxis de la aplicación goto():

```
exten=>extension, priority,goto(context, extension, priority)
```

Formatos válidos para el comando goto():

```
goto(context,extension,priority)
goto(extension,priority)
goto(priority)
```

En el siguiente ejemplo, crearemos una recepcionista digital. Es muy sencillo editar el archivo extensions.conf y configurar las siguientes extensiones:

```
[globals]
OPERATOR=PJSIP/6000
[from-pstn]
include=aapstn
[from-sip]
include=aasip
[aapstn]
exten=>s,1,answer()
exten=>s,n,set(TIMEOUT(response)=10)
exten=>s,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>s,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
[aasip]
exten=>9999,1,answer()
exten=>9999,n,set(TIMEOUT(response)=10)
exten=>9999,n,background(menu1)
exten=>s,n,WaitExten(30)
exten=>9999,n,Dial(${OPERATOR})
exten=>6000,1,Dial(PJSIP/6000)
exten=>6001,1,Dial(PJSIP/6001)
exten=>6003,1,Dial(IAX2/6003)
exten=>6004,1,Dial(IAX2/6004)
```

Las extensiones SIP usan `PJSIP/` y las extensiones IAX usan `IAX2/` — ambos controladores vienen en Asterisk 22, aunque `chan_iax2` ahora se considera heredado (legacy) y se prefiere SIP/PJSIP.

En el archivo menu1.gsm, grabe el mensaje “presione la extension o espere a la operadora”. Cuando el usuario marque el número 6000, será enviado a la extension 6000. En este punto, debería tener una comprensión clara del uso de varias aplicaciones, incluyendo answer(), background(), goto(), hangup() y playback(). Si no tiene una comprensión clara, por favor lea este capítulo de nuevo hasta que se sienta cómodo con el contenido. Usará la aplicación background muy a menudo. Una vez que entienda los conceptos básicos de extensions, prioridades y aplicaciones, será fácil crear un dialplan sencillo. Estos conceptos serán explorados con mayor profundidad más adelante en el libro, y verá que el dialplan se volverá más potente.

## Resumen

En este capítulo, usted ha aprendido que los archivos de configuración se almacenan en el directorio /etc/asterisk. Para utilizar Asterisk, primero es necesario configurar los canales (por ejemplo, pjsip, dahdi, iax). Existen tres gramáticas diferentes para los archivos de configuración: grupo simple, herencia de objetos y entidad compleja. El dialplan se crea en el archivo extensions.conf y es un conjunto de context y extension. En el dialplan, cada extension activa una aplicación. Usted ha aprendido a utilizar las aplicaciones playback, background, dial, goto, hangup y answer.

## Cuestionario

1. Los archivos de configuración de canal son (elija todas las que correspondan):
   - A. `/etc/asterisk/chan_dahdi.conf`
   - B. `/etc/asterisk/pjsip.conf`
   - C. `/etc/asterisk/iax.conf`
   - D. `/etc/asterisk/extensions.conf`
2. En Asterisk 22, el único peer `chan_sip` `[6001]` (`type=friend`/`host=dynamic`) es reemplazado en `pjsip.conf` por ¿qué conjunto de objetos relacionados?
   - A. Un `type=peer` y un `type=user`
   - B. Un `type=endpoint`, un `type=auth` y un `type=aor`
   - C. Un único `type=friend`
   - D. Un `type=transport` y un `type=global`
3. Definir un context en el archivo de configuración de canal es importante porque establece el context entrante para las llamadas desde ese canal; una llamada desde el canal es procesada en el context coincidente en `extensions.conf`.
   - A. Verdadero
   - B. Falso
4. Las principales diferencias entre las aplicaciones `Playback()` y `Background()` son (elija dos):
   - A. Playback reproduce un mensaje pero no espera dígitos.
   - B. Background reproduce un mensaje pero no espera dígitos.
   - C. Background reproduce un mensaje y espera a que se presionen dígitos.
   - D. Playback reproduce un mensaje y espera a que se presionen dígitos.
5. Cuando una llamada entra a Asterisk a través de una tarjeta de interfaz de telefonía (FXO) sin DID, es manejada en la extension especial:
   - A. `0`
   - B. `9`
   - C. `s`
   - D. `i`
6. Los formatos válidos para la aplicación `Goto()` son (elija tres):
   - A. `Goto(context,extension,priority)`
   - B. `Goto(priority,context,extension)`
   - C. `Goto(extension,priority)`
   - D. `Goto(priority)`
7. El patrón `_7[1-5]XX` coincide con (elija todas las que correspondan):
   - A. 7100
   - B. 7600
   - C. 7630
   - D. 7230
8. En `Dial(PJSIP/${EXTEN},20,tTm)`, ¿qué hace la opción `m`?
   - A. Limita la llamada a una duración máxima.
   - B. Proporciona música en espera al llamante en lugar del tono de llamada hasta que el canal conteste.
   - C. Envía dígitos DTMF después de que la parte llamada conteste.
   - D. Fuerza el ID del llamante usando una pista (hint) del dialplan.
9. En la gramática de herencia de opciones utilizada por `chan_dahdi.conf`, usted:
   - A. Define el objeto en una sola línea.
   - B. Define las opciones primero y declara los objetos debajo de las opciones definidas.
   - C. Define un context separado para cada objeto.
10. Las prioridades en una extension deben estar numeradas consecutivamente (1, 2, 3, …) y no pueden usar `n`.
    - A. Verdadero
    - B. Falso

**Respuestas:** 1 — A, B, C · 2 — B · 3 — A · 4 — A, C · 5 — C · 6 — A, C, D · 7 — A, D · 8 — B · 9 — B · 10 — B
