# Uso de funciones de PBX

En los sistemas SIP, la mayoría de las funciones telefónicas se implementan en el endpoint. Existe una gran variedad de teléfonos SIP y fabricantes, y la interoperabilidad no está garantizada. El equipo de desarrollo de Asterisk ha realizado un trabajo increíble al implementar la mayoría de las funciones en el propio PBX, haciendo que Asterisk sea casi independiente del endpoint. Sin embargo, a veces encontrará que la misma función es realizada tanto por el teléfono como por el propio Asterisk. La integración del teléfono y el PBX es la próxima frontera en usabilidad y donde los sistemas propietarios se están enfocando en este momento. En este capítulo, aprenderá a utilizar la mayoría de estas funciones.

## Objetivos

Al finalizar este capítulo, usted será capaz de comprender y utilizar:

- Call Parking
- Call Pickup
- Call Transfer
- Call Conference (ConfBridge)
- Call Recording
- Music on hold

## Dónde se implementan las funciones

Ante todo, es importante entender cuándo se ejecutan las funciones de la PBX frente a cuándo el teléfono está realizando todo el trabajo. Por ejemplo, puede transferir una llamada usando el botón TRANSFER en el teléfono o marcando # (transferencia incondicional ejecutada por la propia PBX).

## Características implementadas por Asterisk

Estas características son implementadas en el PBX por el código de Asterisk:

- Music on hold
- Call parking
- Call pickup
- Call recording
- ConfBridge conference room
- Call transfer (blind and consultative)

## Funcionalidades usualmente implementadas por el dialplan

Estas funcionalidades necesitan ser programadas en el dialplan de Asterisk (extensions.conf):

- Desvío de llamadas si está ocupado
- Desvío de llamadas inmediato
- Desvío de llamadas si no hay respuesta
- Filtrado de llamadas (lista negra)
- No molestar
- Rellamada

## Funciones implementadas habitualmente por el teléfono

Estas funciones son implementadas por el firmware del teléfono:

![Donde se implementan habitualmente las funciones de la PBX: en el propio Asterisk, en el dialplan o en el teléfono](../images/13-pbx-features-fig01.png)

- Call on hold
- Blind transfer
- Consultative transfer
- Three-way conference
- Message waiting indicator

## El archivo de configuración de características

Algunas de las características presentadas en este capítulo se configuran en el archivo de configuración features.conf. Es posible cambiar el comportamiento de algunas características modificando este archivo. Hemos incluido el extracto relevante a continuación. En las siguientes secciones de este capítulo, describiremos cada característica. Extracto del archivo de ejemplo (Asterisk 22)

![La sección `[featuremap]` de features.conf, con los códigos de características DTMF predeterminados](../images/13-pbx-features-fig02.png)

Desde Asterisk 12, el estacionamiento de llamadas (call parking) se trasladó fuera de `features.conf` a su propio módulo, `res_parking`, con configuración en `res_parking.conf`. El bloque parking-lot a continuación (`parkext`, `parkpos`, `context`, `parkingtime`, y así sucesivamente) reside en `res_parking.conf`. La sección `[featuremap]` (los códigos de características DTMF, incluyendo `parkcall`) permanece en `features.conf`.

Las opciones de parking-lot residen en `res_parking.conf`. Un parking lot llamado `default` siempre existe, incluso si no está presente en el archivo de configuración. El extracto a continuación está tomado del `res_parking.conf.sample` de Asterisk 22:

```
; res_parking.conf
[default]                       ; Default Parking Lot
parkext => 700                  ; What extension to dial to park. (optional; if
                                ; specified, extensions will be created for parkext and
                                ; the whole range of parkpos)
parkpos => 701-720              ; What range of parking spaces to use - must be numeric.
                                ; Creates these spaces as extensions if parkext is set.
context => parkedcalls          ; Which context parked calls and the default park
                                ; extension are created in
;parkingtime => 45             ; Number of seconds a call can be parked before returning
;comebacktoorigin = yes        ; When a parked call times out, attempt to send it back to
                               ; the peer that parked it (default is yes)
;courtesytone = beep           ; Sound file to play when someone picks up a parked call
;parkedplay = caller           ; Who to play courtesytone to: parked, caller, both (default caller)
;parkedcalltransfers = caller  ; Enable DTMF transfers when picking up a parked call (default no)
;parkedcallreparking = caller  ; Enable DTMF parking when picking up a parked call (default no)
;parkedcallhangup = caller     ; Enable DTMF hangups when picking up a parked call (default no)
;findslot => next              ; 'next' uses the next space after the most recently used one;
                               ; 'first' (default) uses the lowest-numbered space available
;parkedmusicclass = default    ; MOH class to use for the parked channel
```

Los códigos de características DTMF (incluyendo `parkcall` de un solo paso) permanecen en la sección `[featuremap]` de `features.conf`:

```
; features.conf
[featuremap]
;blindxfer => #1                ; Blind transfer  (default is #) -- Make sure to set the T and/or t option in the Dial() or Queue() app call!
;disconnect => *0               ; Disconnect  (default is *) -- Make sure to set the H and/or h option in the Dial() or Queue() app call!
;atxfer => *2                   ; Attended transfer  -- Make sure to set the T and/or t option in the Dial() or Queue()  app call!
;parkcall => #72                ; Park call (one step parking)  -- Make sure to set the K and/or k option in the Dial() app call!
;automixmon => *3               ; One Touch Record a.k.a. Touch MixMonitor -- Make sure to set the X and/or x option in the Dial() or Queue() app call!
```

## Transferencia de llamadas

La transferencia de llamadas puede ser implementada por el teléfono, por un ATA o por el mismo Asterisk. Consulte el manual de su teléfono para entender cómo se transfieren las llamadas. Si su teléfono no admite la transferencia de llamadas, puede utilizar Asterisk para realizar esta tarea. La transferencia de llamadas se implementa de dos maneras diferentes.

La primera forma es utilizar la función de transferencia ciega: marque # seguido del número al que se desea transferir. A veces utilizará la función de transferencia de su teléfono IP o softphone IP. Puede cambiar el carácter de transferencia editando el parámetro blindxfer en el archivo features.conf.

Puede habilitar la transferencia asistida en Asterisk eliminando el ; antes del parámetro atxfer en el archivo features.conf. Durante una conversación, debe presionar *2. Asterisk dirá "transfer" y le dará un tono de marcado. La persona que llama es enviada a música en espera. Después de hablar con la persona de destino y colgar el teléfono, el sistema conecta a la persona que llama con el destino.

![Transferencia de llamadas: los pasos para una transferencia ciega (presione # durante la llamada) y una transferencia asistida (presione *2)](../images/13-pbx-features-fig03.png)

### Lista de tareas de configuración

1. Para un endpoint PJSIP, asegúrese de que la opción `direct_media` esté configurada en `no` (para que el media fluya a través de Asterisk y se detecten los códigos de función), o utilice una opción `t`/`T` en la aplicación `Dial()`

## Call parking

Esta función se utiliza para estacionar una llamada. Esto ayuda, por ejemplo, cuando usted está contestando una llamada telefónica fuera de su oficina y desea transferir la llamada de regreso a su escritorio. Puede lograr esto estacionando la llamada en una extension. Una vez que llegue a su escritorio, simplemente marque el número de la extension de estacionamiento para recuperar la llamada.

![Call parking: marque 700 para estacionar una llamada en el primer espacio libre (701–720); Asterisk anuncia el espacio, el cual usted marca desde cualquier teléfono para recuperar la llamada](../images/13-pbx-features-fig04.png)

De forma predeterminada, la extension 700 se utiliza para estacionar una llamada. En medio de una conversación, presione # para transferir la llamada a la extension 700. Ahora Asterisk anunciará su extension de estacionamiento, como 701 o 702. Cuelgue el teléfono y la persona que llama quedará en espera. Diríjase al teléfono de su escritorio y marque la extension de estacionamiento anunciada para recuperar la llamada. Si la persona que llama permanece estacionada durante mucho tiempo, la función de tiempo de espera (timeout) se activará y la extension marcada originalmente volverá a sonar.

### Lista de tareas de configuración

Siga los pasos a continuación para habilitar el call parking. Paso 1: Haga que el estacionamiento sea accesible desde su dialplan (requerido). El `context` del estacionamiento predeterminado es `parkedcalls` (configurado en `res_parking.conf`). Incluya ese context en el context desde el cual marcan sus teléfonos, en `extensions.conf`:

```
include => parkedcalls
```

Paso 2: Pruebe la función de call parking marcando #700. Notas:

- La extension de estacionamiento no se mostrará en el comando CLI dialplan show.
- Es necesario recargar el módulo de estacionamiento después de cambiar el archivo de configuración de estacionamiento: `module reload res_parking.so`. Para cambios en features.conf, `module reload features.so`.
- Para estacionar una llamada, necesita transferir a #700. Verifique las opciones `t` y `T` en la aplicación `Dial()`.

## Call pickup

Call pickup permite capturar una llamada de un colega que se encuentre en el mismo grupo de llamada. Esto ayuda a evitar, por ejemplo, tener que levantarse para contestar una llamada que está sonando para otra persona en su oficina, pero que no está presente. Al marcar *8, usted puede capturar una llamada dentro de su grupo de llamada. Este número puede ser modificado en el archivo `features.conf`.

![Call pickup: los miembros solo pueden capturar llamadas dentro de su propio grupo; el operador (pickupgroup=1,2,3) puede capturar llamadas de todos los grupos](../images/13-pbx-features-fig05.png)

### Lista de tareas de configuración

Siga los pasos a continuación para configurar la función de call pickup. Paso 1: Configure un grupo de llamada para sus extensiones. Esto se realiza en el archivo de configuración del canal (pjsip.conf, iax.conf, chan_dahdi.conf). Para endpoints PJSIP, establezca `call_group` y `pickup_group` en la sección endpoint de `pjsip.conf` (pjsip.conf utiliza nombres de opciones en snake_case). Esta tarea es obligatoria.

Para PJSIP (pjsip.conf):
```
[4x00]
type=endpoint
call_group=1
pickup_group=1,2
```


Paso 2: Cambie el número de la función call-pickup (opcional). Esto se establece en la sección `[general]` de `features.conf`, no en `pjsip.conf`:

```
; features.conf
[general]
pickupexten = *8   ; Configures the call pickup extension (default is *8)
```

## Conferencia (llamada de conferencia)

Existen diferentes formas de implementar una conferencia en Asterisk. La primera opción es simplemente utilizar la capacidad de conferencia tripartita del teléfono. Al usar esta función en el teléfono, no requiere ningún soporte en el servidor mismo. Sin embargo, cuando desea una conferencia con más de 3 personas, debe ejecutar una sala de conferencias. La aplicación de conferencia moderna de Asterisk es ConfBridge (`app_confbridge`).

ConfBridge admite conferencias de voz en HD y videoconferencias. Existen algunas limitaciones para las videoconferencias, como la ausencia de transcodificación: todos los participantes deben utilizar el mismo codec y perfil. La videoconferencia utiliza un modo de seguimiento del hablante (follow-the-talker), mostrando la imagen de la última persona en hablar. Puede configurar fácilmente nuevos menús DTMF en ConfBridge.

ConfBridge reemplaza a la antigua aplicación MeetMe, la cual fue declarada obsoleta en Asterisk 19. MeetMe todavía se incluye en el árbol de fuentes de Asterisk 22, pero depende de DAHDI y no se compila de forma predeterminada, por lo que en una instalación típica de PJSIP simplemente no está disponible; ConfBridge es la aplicación de conferencia soportada. A diferencia de MeetMe, ConfBridge **no** requiere DAHDI ni una fuente de temporización de hardware: se basa en la interfaz de temporización integrada de Asterisk (`res_timing_timerfd` en Linux, o `res_timing_pthread`), por lo que no se necesita ningún módulo `dahdi_dummy`. Si está migrando desde un sistema antiguo que utilizaba `MeetMe()` y `meetme.conf`, reemplácelos con `ConfBridge()` y `confbridge.conf` como se describe a continuación.

### ConfBridge

Para iniciar una sala de conferencias, la sintaxis se enumera a continuación.

```
ConfBridge(conference,bridge_profile,user_profile,menu)
```

Para obtener una descripción completa del comando, puede utilizar core show application confbridge.

![Salida de `core show application confbridge`, que muestra la sinopsis, la sintaxis y los argumentos bridge_profile, user_profile y menu](../images/13-pbx-features-fig06.png)

![Varios endpoints PJSIP se unen a una conferencia ConfBridge nombrada (101); un participante es el administrador. La mezcla y la temporización son manejadas por `app_confbridge` junto con `bridge_softmix` y el temporizador integrado `res_timing_*`; no se requiere DAHDI.](../images/13-pbx-features-fig09.png)

Como puede ver arriba, hay tres argumentos importantes, cada uno asignado a un tipo de sección en `confbridge.conf`. **bridge_profile** (una sección `type=bridge`): aquí selecciona el número máximo de participantes (`max_members`), la grabación (`record_conference`), `video_mode` y muchos otros parámetros de toda la conferencia.

No tiene sentido reproducir el ejemplo completo aquí, así que permítame darle un ejemplo simple sobre cómo configurar un bridge_profile en el archivo confbridge.conf.

```
[default_bridge]
type=bridge
max_members=10
record_conference=yes
```

**user_profile** (una sección `type=user`): aquí define opciones que son específicas por usuario, tales como si el usuario es un administrador (`admin=yes`), si comienzan en silencio (`startmuted=yes`), música en espera y muchas otras opciones por usuario. Ejemplo:

```
[admin_user]
type=user
admin=yes
```

**menu** (una sección `type=menu`): aquí define el mapeo del teclado (DTMF) para la conferencia; por ejemplo, qué tecla alterna el silencio, ajusta el volumen o abandona la conferencia. Consulte el archivo `confbridge.conf.sample` para ver todas las acciones disponibles. Ejemplo:

```
[my_menu]
type=menu
*=playback_and_continue
1=toggle_mute
2=decrease_listening_volume
3=increase_listening_volume
4=decrease_talking_volume
5=increase_talking_volume
6=leave_conference
```

#### Funciones de Confbridge

Las opciones del puente de conferencia se pueden pasar dinámicamente en el dialplan utilizando la función CONFBRIDGE(). Vea los ejemplos a continuación:

```
exten => 1,1,Answer()
exten => 1,n,Set(CONFBRIDGE(user,template)=default_user)
exten => 1,n,Set(CONFBRIDGE(user,admin)=yes)
exten => 1,n,Set(CONFBRIDGE(user,marked)=yes)
exten => 1,n,ConfBridge(sales)
```

### Comandos de administración de ConfBridge y migración desde MeetMe

Si proviene de MeetMe, las funciones de administración que utilizaba a través de `MeetMeAdmin()` y la opción (admin) `a` ahora se expresan a través del **perfil de usuario administrador** (`admin=yes`) más las acciones del **menú**. Un administrador que se une con un perfil de administrador y un menú que contiene acciones de administración puede bloquear la sala, expulsar usuarios y silenciar participantes en vivo desde el teclado. Las acciones de menú relevantes en `confbridge.conf` son:

- `admin_kick_last` -- expulsar al último usuario que se unió
- `admin_toggle_mute_participants` -- silenciar/activar el sonido de todos los participantes que no son administradores
- `toggle_mute` -- silenciar/activar su propio sonido
- `participant_count` -- anunciar el número de participantes
- `leave_conference` -- abandonar el puente y continuar en el dialplan

Estos reemplazan las banderas de opción de MeetMe `MeetMe()` (`a`, `A`, `m`, `M`, `l`, `x`, …) y los comandos `MeetMeAdmin()` (`k`, `K`, `L`, `M`, `N`, …). En una instalación moderna de PJSIP no cargará `app_meetme` en absoluto; toda la configuración de la conferencia reside en `confbridge.conf` y los cambios se aplican con `module reload app_confbridge.so` (la lógica de ConfBridge reside en `app_confbridge`; no existe un módulo `res_confbridge`).

### Ejemplo de ConfBridge

Para crear una sala de conferencias accesible en la extension 500, en `extensions.conf`:

```
exten => 500,1,Answer()
 same => n,ConfBridge(101,default_bridge,default_user,sample_user_menu)
```

La primera persona en marcar 500 crea la conferencia `101`; las llamadas subsiguientes se unen a ella. Los perfiles y menús referenciados aquí (`default_bridge`, `default_user`, `sample_user_menu`) están definidos en `confbridge.conf`. Para requerir un PIN, establezca `pin=` en el perfil de usuario; para hacer que un participante sea administrador de la conferencia, asígnele un perfil de usuario con `admin=yes`.

## Grabación de llamadas

Existen varias formas de grabar una llamada en Asterisk. Puede utilizar la aplicación `MixMonitor()` para grabar llamadas fácilmente. (La aplicación más antigua `Monitor`, que grababa dos archivos separados, fue eliminada; utilice `MixMonitor` en su lugar).

### Uso de la aplicación MixMonitor

La aplicación `MixMonitor` graba el audio del canal actual en el archivo especificado. Si el nombre del archivo es una ruta absoluta, utiliza dicha ruta. De lo contrario, crea el archivo en el directorio de monitoreo configurado en asterisk.conf.

![La aplicación MixMonitor(): graba y mezcla el audio de un canal en un archivo, con opciones para añadir, solo puenteado y ajuste de volumen](../images/13-pbx-features-fig09.png)

### MixMonitor()

Grabe una llamada y mezcle el audio durante la grabación. Sintaxis: `MixMonitor(filename.extension[,options[,command]])`. Graba el audio del canal actual en el archivo especificado. Opciones válidas:

- a - Añade al archivo en lugar de sobrescribirlo.
- b - Solo guarda audio en el archivo mientras el canal está puenteado.
- Nota: no incluye conferencias.
- v(<x>) - Ajusta el volumen audible por un factor de <x> (en un rango de -4 a 4)
- V(<x>) - Ajusta el volumen hablado por un factor de <x> (en un rango de -4 a 4)
- W(<x>) - Ajusta tanto el volumen audible como el hablado por un factor de <x> (en un rango de -4 a 4)
- <command> se ejecutará cuando la grabación termine. Cualquier cadena que coincida con ^{X} será decodificada a ${X} y todas las variables serán evaluadas en ese momento. La variable MIXMONITOR_FILENAME contendrá el nombre del archivo utilizado para la grabación.

Un recurso interesante es la función de grabación con un solo toque `automixmon`, que permite a una parte marcar un código DTMF (la muestra `features.conf` sugiere `*3`; no hay un valor predeterminado integrado, por lo que debe configurarlo) durante una llamada para iniciar (y detener) la grabación inmediatamente. Está construida sobre MixMonitor, por lo que escribe un único archivo mezclado. Ejemplo:

```
exten => _4XXX,1,Set(DYNAMIC_FEATURES=automixmon)
 same => n,Dial(PJSIP/${EXTEN},20,jtTXx) ; X and x enable one-touch MixMonitor recording
```

Las opciones `X` y `x` habilitan la función de MixMonitor de un solo toque para quien llama y quien recibe la llamada, respectivamente. Debido a que MixMonitor graba un único archivo mezclado, no hay necesidad de combinar archivos IN/OUT separados posteriormente (el antiguo enfoque `automon`/`Monitor`, que producía dos archivos para `soxmix`, fue eliminado junto con la aplicación `Monitor`).

Si no desea utilizar Set() antes de la aplicación Dial(), puede configurarlo en la sección globals:

```
[globals]
DYNAMIC_FEATURES=automixmon
```

### Música en espera (Music on hold)

La música en espera (MOH) ha cambiado varias veces entre las versiones 1.0, 1.2 y 1.4. En la versión más reciente, la MOH utiliza "FILE-BASED" por defecto. En otras palabras, Asterisk proporcionará los archivos de MOH en formatos como g729, alaw, ulaw y gsm. Por lo tanto, no es necesario transcodificar la música antes de enviarla al canal. Esto ahorra tiempo de procesador, lo cual es una modificación bienvenida para aquellos que trabajan con sistemas en producción.

En versiones anteriores, la MOH generalmente se proporcionaba mediante MP3 (todavía puede configurarse de esa manera). Proporcionar MOH usando MP3 obliga a Asterisk a transcodificar, gastando valiosa potencia de CPU en el proceso.

El nuevo archivo de configuración se muestra a continuación. Tenga en cuenta que la clase predeterminada ahora utiliza el modo de formato de archivo nativo mode=files. Todos los demás modos están comentados. Cada sección es una clase. La única clase sin comentar en este punto es default. Si desea tener diferentes clases para diferentes archivos, necesitará crear nuevas secciones (clases).

![La configuración de ejemplo de musiconhold.conf, listando los modos de MOH válidos (quietmp3, mp3, custom, files, …)](../images/13-pbx-features-fig10.png)

```
; Music on Hold -- Sample Configuration
;[samplemp3]
;mode=quietmp3
;directory=/var/lib/asterisk/mohmp3
;
; valid mode options:
; quietmp3      -- default
; mp3           -- loud
; mp3nb         -- unbuffered
; quietmp3nb    -- quiet unbuffered
; custom        -- run a custom application (See examples below)
; files         -- read files from a directory in any Asterisk supported
;                  media format. (See examples below)
;[manual]
;mode=custom
; Note that with mode=custom, a directory is not required, such as when reading
; from a stream.
;directory=/var/lib/asterisk/mohmp3
;application=/usr/bin/mpg123 -q -r 8000 -f 8192 -b 2048 --mono -s
;[ulawstream]
;mode=custom
;application=/usr/bin/streamplayer 192.168.100.52 888
;format=ulaw
; mpg123 on Solaris does not always exit properly; madplay may be a better
; choice
;[solaris]
;mode=custom
;directory=/var/lib/asterisk/mohmp3
;application=/site/sw/bin/madplay -Q -o raw:- --mono -R 8000 -a -12
;
;
; File-based (native) music on hold
;
; This plays files directly from the specified directory, no external
; processes are required. Files are played in normal sorting order
; (same as a sorted directory listing), and no volume or other
; sound adjustments are available. If the file is available in
; the same format as the channel's codec, then it will be played
; without transcoding (same as Playback would do in the dialplan).
; Files can be present in as many formats as you wish, and the
; 'best' format will be chosen at playback time.
;
; NOTE:
; If you are not using "autoload" in modules.conf, then you
; must ensure that the format modules for any formats you wish
; to use are loaded _before_ res_musiconhold. If you do not do
; this, res_musiconhold will skip the files it is not able to
; understand when it loads.
;
[default]
mode=files
directory=/var/lib/asterisk/moh
;
;[native-random]
;mode=files
;directory=/var/lib/asterisk/moh
;random=yes     ; Play the files in a random order
```

### Tareas de configuración de MOH

Ahora, para utilizar música en espera, establezca la clase de MOH en los archivos de configuración del canal (chan_dahdi.conf, pjsip.conf, iax.conf, etcétera). Para endpoints PJSIP, establezca `moh_suggest` en la sección del endpoint de `pjsip.conf` (el nombre de la opción heredada `musicclass` se aplica a chan_dahdi y otros controladores de canal, no a PJSIP). Las melodías freeplay instaladas están ahora en formato wav. En el momento de la instalación, puede seleccionar (usando make menuselect) los formatos de archivo de MOH disponibles. Si desea añadir nuevos archivos de MOH, tendrá que suministrarlos en los formatos requeridos. Por ejemplo:

En `/etc/asterisk/chan_dahdi.conf`, añada la línea `musiconhold`:

```
[channels]
musiconhold=default
```

Luego edite `/etc/asterisk/musiconhold.conf` para definir esa clase:

```
[default]
mode=files
directory=/var/lib/asterisk/moh
```

En el dialplan, puede iniciar la música en espera en un canal con `StartMusicOnHold` (y detenerla con `StopMusicOnHold`):

```
exten => 100,1,StartMusicOnHold(default)
 same => n,Dial(PJSIP/2)
```

Para reproducir música en espera durante un tiempo fijo como prueba rápida, utilice la aplicación `MusicOnHold` con una duración (en segundos):

```
[local]
exten => 6601,1,MusicOnHold(default,30)
```

## Mapas de aplicaciones

Los mapas de aplicaciones le permiten agregar nuevas funciones mediante el uso de la sección `[applicationmap]` del archivo features.conf. Suponga que necesita identificar el tipo de cliente al que está atendiendo en un call center. Podría crear un mapa de aplicaciones para cada tipo de cliente, lo cual podría contar la cantidad de clientes atendidos por tipo.

## Resumen

En este capítulo aprendió dónde residen las funciones de PBX de Asterisk —algunas en el núcleo, otras en el dialplan y otras en el teléfono— y cómo se asignan los códigos de funciones DTMF en la sección `[featuremap]` de `features.conf`. Configuró **call transfer** (ciega y asistida) y **call parking** (`res_parking.conf`, con las opciones de Dial `k`/`K` y el lote `parkedcalls`), **call pickup** por grupo y **conferencing** con **ConfBridge** (perfiles de bridge/user/menu `confbridge.conf`), que reemplaza al antiguo MeetMe. Configuró **one-touch recording** con MixMonitor (`automixmon`, las opciones de Dial `X`/`x` y `DYNAMIC_FEATURES`), configuró **music on hold** y vio cómo los **application maps** le permiten vincular su propia lógica de dialplan a una secuencia DTMF. Con estos componentes básicos puede ofrecer las funciones cotidianas que los usuarios esperan de una PBX empresarial.

## Cuestionario

1. ¿Qué afirmaciones son ciertas sobre el estacionamiento de llamadas (call parking)?
   - A. De forma predeterminada, la extension 800 se utiliza para el estacionamiento de llamadas.
   - B. Cuando usted no está en su escritorio y recibe una llamada, puede estacionarla; el sistema anuncia la ranura de estacionamiento y usted marca esa ranura desde cualquier teléfono para recuperar la llamada.
   - C. De forma predeterminada, la extension 700 estaciona una llamada, y las llamadas se estacionan en las ranuras 701–720.
   - D. Usted marca 700 para recuperar una llamada estacionada.
2. Para utilizar la función de captura de llamadas (call-pickup), todas las extensiones deben estar en el mismo ___. Para los canales DAHDI, esto se configura en el archivo ___.
3. Al transferir una llamada, puede elegir entre una transferencia ___, donde no se consulta primero al destino, y una transferencia ___, donde usted habla con el destino antes de completarla.
4. Para realizar una transferencia asistida (de consulta), usted utiliza la secuencia ___; para una transferencia ciega (blind), usted utiliza ___.
   - A. #1, *2
   - B. *2, #1
   - C. #2, #1
   - D. #1, #2
5. Para alojar conferencias telefónicas en Asterisk 22, usted utiliza la aplicación ___.
6. En ConfBridge, a un participante se le otorgan privilegios de administrador (expulsar, silenciar a otros, bloquear la sala) configurando ___ en su perfil de usuario (`confbridge.conf`):
   - A. admin=yes
   - B. marked=yes
   - C. moderator=yes
   - D. type=admin
7. El mejor formato para la música en espera (music on hold) es MP3, porque utiliza muy poca potencia de procesamiento en el servidor Asterisk.
   - A. Verdadero
   - B. Falso
8. Para capturar una llamada de un grupo de llamadas específico, usted debe estar en el grupo de ___ correspondiente.
9. Puede grabar una llamada con la aplicación MixMonitor() o con la función de grabación de un solo toque (one-touch recording) (`automixmon`). En el ejemplo de `features.conf`, `automixmon` está asignado a la secuencia DTMF ___.
   - A. *1
   - B. *2
   - C. *3
   - D. #1
10. En ConfBridge, ¿qué opción de perfil de usuario de `confbridge.conf` hace que un participante se una silenciado (pueden escuchar la conferencia pero no pueden ser escuchados hasta que se les quite el silencio)?
    - A. startmuted=yes
    - B. listen=only
    - C. muteall=yes
    - D. quiet=yes

**Respuestas:** 1 — B, C · 2 — pickup group; `chan_dahdi.conf` · 3 — blind; attended · 4 — B · 5 — ConfBridge() · 6 — A · 7 — B · 8 — pickup · 9 — C · 10 — A
