# Características avanzadas del dialplan

El Capítulo 3 discutió los conceptos básicos de un dialplan. Por razones didácticas, no explicamos todas las características, sino solo algunas de las más importantes. Este capítulo profundizará más en el dialplan, describiendo técnicas avanzadas, nuevas aplicaciones y conceptos.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Simplificar sus entradas de extensiones
- Abordar la seguridad del dialplan y el filtrado de extensiones
- Recibir llamadas utilizando un menú IVR
- Utilizar subrutinas para evitar reescrituras innecesarias
- Implementar algo de seguridad en el dialplan utilizando “Include”
- Implementar la función de sígueme (follow-me) utilizando AsteriskDB
- Implementar el comportamiento fuera de horario en su PBX
- Utilizar el comando switch para transferir a otra PBX
- Implementar el gestor de privacidad (privacy manager)
- Implementar voicemail
- Implementar un directorio corporativo

## Simplificando su dialplan

Puede simplificar su dialplan utilizando la palabra clave “same” para definir una extension. Esto debería reducir la cantidad de errores tipográficos en el dialplan. Revise el siguiente ejemplo:

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Seguridad del dialplan

Se descubrió una vulnerabilidad en el dialplan de Asterisk que permite a un usuario inyectar un nuevo canal y un número de marcado en su dialplan. Supongamos que usted tiene la siguiente línea en su servidor `exten=>_X.,1,Dial(PJSIP/${EXTEN})` y algún usuario malintencionado marcó el número `3000&DAHDI/1/011551123456789` en el softphone. El protocolo SIP, por defecto, acepta cualquier carácter alfanumérico, por lo que la extension marcada activará en realidad dos llamadas: una para el canal PJSIP/3000 y la otra para el canal DAHDI/011551123456789, el cual es un número internacional. Por lo tanto, cualquier usuario con acceso a una extension puede marcar a cualquier parte del mundo. La forma más sencilla de evitar este comportamiento es filtrar los números antes de llamar a la aplicación dial. La función FILTER() es muy útil para esto. Ejemplo:

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

La aplicación de filtro le permitirá filtrar todos los caracteres del número marcado excepto los números del 0 al 9. Puede encontrar más información en el archivo README-SERIOUSLY.bestpractices.txt disponible en Asterisk.

## Recepción de llamadas mediante un menú IVR.

En la sección anterior, recibió todas las llamadas utilizando DID o mediante el desvío a la operadora. Ahora aprenderá a implementar un menú IVR, así como a crear un servicio de operadora automática. Antes de entrar en detalles, examinemos algunas aplicaciones nuevas. Ponemos el resultado del comando `core show application` a continuación simplemente para facilitar la lectura a los usuarios. Puede obtener estas descripciones usted mismo utilizando `core show application <application_name>`.

### La aplicación Background()

Esta aplicación reproducirá la lista de archivos proporcionada mientras espera a que el canal que llama marque una extension. Para continuar esperando dígitos después de que esta aplicación haya terminado de reproducir los archivos, se debe utilizar la aplicación WaitExten. La opción langoverride especifica explícitamente qué idioma intentar usar para los archivos de sonido solicitados. Cualquier context que se especifique será el contexto del dialplan que esta aplicación utilizará al salir hacia una extension marcada. Si uno de los archivos de sonido solicitados no existe, se terminará el procesamiento de la llamada. Opciones:

- s - Hace que se omita la reproducción del mensaje si el canal no está en estado 'up' (es decir, aún no ha sido contestado). Si esto sucede, la aplicación regresará inmediatamente.
- n - No contesta el canal antes de reproducir los archivos.
- m - Solo interrumpe si un dígito presionado coincide con una extension de un solo dígito en el context de destino.

### La aplicación Record()

Esta aplicación graba desde el canal en un nombre de archivo determinado. Si el archivo existe, será sobrescrito.

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' es el formato del tipo de archivo a grabar (wav, gsm, etc).
- 'silence' es el número de segundos de silencio permitidos antes de regresar.
- 'maxduration' es la duración máxima de grabación en segundos; si falta o es cero, no hay máximo.
- 'options' puede contener cualquiera de las siguientes letras:
    - `a` — añade a una grabación existente en lugar de reemplazarla
    - `n` — no contesta, pero graba de todos modos si la línea aún no ha sido contestada
    - `q` — silencioso (no reproduce un tono de pitido)
    - `s` — omite la grabación si la línea aún no ha sido contestada
    - `t` — utiliza la tecla de terminación alternativa `*` (DTMF) en lugar de la predeterminada `#`
    - `x` — ignora todas las teclas de terminación (DTMF) y continúa grabando hasta colgar

Si el nombre de archivo contiene %d, estos caracteres serán reemplazados por un número que se incrementa en uno cada vez que se graba el archivo. Utilice core show file formats para ver los formatos disponibles en su sistema. El usuario puede presionar # para terminar la grabación y continuar con la siguiente prioridad. Si el usuario cuelga durante una grabación, todos los datos se perderán y la aplicación terminará.

### La aplicación Playback()

Esta aplicación reproduce los nombres de archivo proporcionados (no incluya la extensión). Las opciones también pueden incluirse después de un símbolo de barra vertical (pipe). La opción 'skip' hace que la reproducción del mensaje se omita si el canal no está en estado 'up' (es decir, no ha sido contestado aún).

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

Si se especifica 'skip', la aplicación regresará inmediatamente si el canal no está descolgado. De lo contrario, a menos que se especifique 'noanswer', el canal será contestado antes de que se reproduzca el sonido. No todos los canales admiten la reproducción de mensajes mientras aún están descolgados. Si se especifica 'j', la aplicación saltará a la prioridad n+101 cuando el archivo no exista, si está presente. Esta aplicación establece la siguiente variable de canal al finalizar:

- PLAYBACKSTATUS — el estado del intento de reproducción como una cadena de texto, uno de:
    - `SUCCESS`
    - `FAILED`

### La aplicación Read()

Esta aplicación lee un número predeterminado de dígitos de cadena, un cierto número de veces, desde el usuario hacia la variable dada.

- filename -- archivo a reproducir antes de leer dígitos o tono con la opción i
- maxdigits -- número máximo aceptable de dígitos. Deja de leer después de que se hayan ingresado maxdigits (sin requerir que el usuario presione la tecla #). El valor predeterminado es 0 - sin límite - para esperar a que el usuario presione la tecla #. Cualquier valor por debajo de 0 significa lo mismo. El valor máximo aceptado es 255.

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- las opciones son `s`, `i`, `n`:
    - `s` — regresa inmediatamente si la línea no está activa
    - `i` — reproduce filename como un tono de indicación desde su `indications.conf`
    - `n` — lee dígitos incluso si la línea no está activa
- attempts -- si es mayor que 1, el número de intentos que se realizarán en caso de que no se ingresen datos
- timeout -- Un número entero de segundos a esperar por una respuesta de dígito. Si es mayor que 0, ese valor anulará el tiempo de espera predeterminado.

La aplicación read() debe desconectarse si la función falla o genera un error.

### La aplicación Gotoif()

Esta aplicación hará que el canal que llama salte a la ubicación especificada en el dialplan basándose en la evaluación de la condición dada. El canal continuará en labeliftrue si la condición es verdadera, o en 'labeliffalse' si la condición es falsa. Las etiquetas se especifican con la misma sintaxis que la utilizada dentro de la aplicación Goto. Si se omite la etiqueta elegida por la condición, no se realiza ningún salto; más bien, la ejecución continúa con la siguiente prioridad en el dialplan.

### Laboratorio: Construcción de un menú IVR paso a paso

Creemos un menú IVR con la siguiente funcionalidad. Cuando se marca, el IVR reproduce un archivo de audio con el mensaje “Bienvenido a XYZ Corporation; presione 1 para ventas, 2 para soporte técnico, 3 para capacitación, o espere para hablar con un representante.” Los dígitos dirigen a quien llama de la siguiente manera:

- `1` — transferir a ventas (PJSIP/4001)
- `2` — transferir a soporte técnico (PJSIP/4002)
- `3` — transferir a capacitación (PJSIP/4003)
- Ningún dígito presionado — transferir a la operadora (PJSIP/4000)

**Paso 1 – Grabar los avisos**

Creemos una extension para grabar los avisos. Para grabar un aviso, marque desde un softphone a `9003<filename>` (por ejemplo, `9003welcome`). Cuando escuche el pitido, comience a grabar; presione `#` para detener. Escuchará un pitido y el sistema reproducirá el aviso grabado.

**Paso 2 – Crear la lógica del menú**

Al marcar la extension 9004, el procesamiento salta al menú en la extension `s`, prioridad 1.

### Coincidencia mientras marca

Esta es una configuración de menú de empresa para recibir llamadas. La aplicación `Background()` reproduce el aviso de bienvenida y luego espera dígitos, haciendo coincidir lo que marca quien llama con las extensiones definidas en el context actual.

```
[incoming]
exten=>s,1,Background(welcome)
exten=>1,1,Dial(DAHDI/1)
exten=>2,1,Dial(DAHDI/2)
exten=>21,1,Dial(DAHDI/3)
exten=>22,1,Dial(DAHDI/4)
exten=>31,1,Dial(DAHDI/5)
exten=>32,1,Dial(DAHDI/6)
```

Cuando marca a esta empresa, primero se reproduce el mensaje de bienvenida. Después de eso, Asterisk espera a que se marque un dígito:

| Número marcado | Acción de Asterisk |
|---------------|-----------------|
| 1 | Llama inmediatamente a `Dial(DAHDI/1)` |
| 2 | Espera el tiempo de espera, luego llama a `Dial(DAHDI/2)` |
| 21 | Llama inmediatamente a `Dial(DAHDI/3)` |
| 22 | Llama inmediatamente a `Dial(DAHDI/4)` |
| 3 | Espera el tiempo de espera, luego se desconecta |
| 31 | Llama inmediatamente a `Dial(DAHDI/5)` |
| 32 | Llama inmediatamente a `Dial(DAHDI/6)` |

Es importante evitar ambigüedades en los menús. Todo el mundo quiere ser atendido rápidamente. Por esta razón, no debe usar los números 2, 21 o 22.

### Laboratorio: Uso de la aplicación Read()

Por favor, pruebe el laboratorio con la aplicación read(). Read acepta dígitos del usuario y los inserta en la variable especificada; luego puede usar la aplicación gotoif para redirigir la llamada.

## Inclusión de context

Un context puede incluir el contenido de otro context. En el ejemplo anterior, cualquier canal puede marcar cualquier extension en el context internal, pero solo el canal 4003 puede marcar extensions internacionales. Puede utilizar la inclusión de context para facilitar la creación del dialplan. Al usar la inclusión de context, puede controlar quién tiene acceso a qué extensions.

### Solución de problemas del mensaje “number not found”

Es muy común recibir el mensaje “number not found”. La mayoría de las personas confunden el concepto de los contexts incluidos porque realmente no es intuitivo. Como regla general, primero vaya al archivo de configuración del canal entrante, como `pjsip.conf`, `chan_dahdi.conf` y `iax.conf`, y determine el context actual. Luego, vaya al dialplan en el archivo extensions.conf y verifique si el número marcado se puede encontrar en ese context. Si no es así, algo anda mal con su dialplan. Las reglas de oro de los contexts son: 1. Un canal solo puede marcar números dentro del mismo context que el canal. 2. El context donde se procesa la llamada se define en el archivo de configuración del canal entrante (`chan_dahdi.conf`, `iax.conf`, `pjsip.conf`).

## Uso de la sentencia switch

Puede enviar el procesamiento del dialplan a otro servidor utilizando el comando switch. Necesitará el nombre y la clave del otro servidor. El context es el context de destino.

![10-dialplan-advanced-features figura 6](../images/10-dialplan-advanced-features-img06.png)

## Orden de procesamiento del dialplan

Cuando Asterisk recibe una llamada entrante, busca en el context definido por el canal. En algunos casos, si más de un patrón coincide con el número marcado, Asterisk no puede procesar la llamada de la manera exacta en que usted piensa que debería hacerlo. Puede ver el orden de coincidencia usando el comando de CLI dialplan show. Ejemplo: Digamos que desea marcar 912 para enrutar a un trunk analógico (DAHDI/1) y todos los demás números que comienzan con 9 a otro trunk analógico (DAHDI/2). Usted escribiría algo como:

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

Si dos patrones coinciden con una extension, puede controlar qué extension se procesa primero utilizando los contexts incluidos. Un context incluido se procesa después que un patrón en el mismo context.

## La sentencia #INCLUDE

¿Deberíamos usar un archivo grande o varios archivos? Puede utilizar la sentencia #include <filename> para incluir otros archivos en su extensions.conf. Por ejemplo, podríamos crear un users.conf para los usuarios locales y un services.conf para servicios especiales. Tenga cuidado de no confundir #include <filename> con el

```
include=>context statement.
```

## Subrutinas con GOSUB

En versiones anteriores de Asterisk existía el comando Macro. Este comando fue declarado obsoleto hace mucho tiempo en favor de GOSUB. Demostraremos aquí cómo crear subrutinas para el procesamiento de voicemail de una manera fácil y ordenada. Formato del comando:

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

El comando GOSUB ha estado disponible desde Asterisk 1.6 y permite pasar argumentos (disponibles dentro de la subrutina como `${ARG1}`, `${ARG2}`, y así sucesivamente). Con argumentos, ahora es posible reemplazar completamente los antiguos comandos Macro. Las Macros (`app_macro`) fueron eliminadas en Asterisk 21; debe utilizar GOSUB para las subrutinas.

### Creación de la subrutina

La definición es muy similar. Observe la subrutina a continuación definida para voicemail con el nombre stdexten (elija el nombre que prefiera). Después de llamar al comando Dial con el primer argumento (nombre del canal), verificamos el ${DIALSTATUS} para enviar la lógica de la llamada al siguiente paso.

```
[stdexten]
exten=>s,1,Dial(${ARG1},20,tT)
exten=>s,n,Goto(${DIALSTATUS})
exten=>s,n,hangup()
exten=>s,n(BUSY),voicemail(${ARG2},b)
exten=>s,n,hangup()
exten=>s,n(NOANSWER),voicemail(${ARG2},u)
exten=>s,n,hangup()
exten=>s,n(CANCEL),hangup
exten=>s,n(CHANUNAVAIL),hangup
exten=>s,n(CONGESTION),hangup
```

### Llamada a una subrutina

Preste atención al llamar a la subrutina para usar paréntesis antes de los parámetros.

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Uso de Asterisk DB

Para implementar el desvío de llamadas y las listas negras, necesitamos alguna forma de almacenar y restaurar datos. Afortunadamente, Asterisk proporciona un mecanismo para almacenar y recuperar datos de una base de datos integrada llamada AstDB. En el Asterisk moderno (incluyendo Asterisk 22), AstDB está respaldado por **SQLite3** (el archivo `/var/lib/asterisk/astdb.sqlite3`); Asterisk 1.8 y versiones anteriores utilizaban Berkeley DB v1. Esto es similar a la base de datos del registro de Windows, utilizando el concepto jerárquico de familia y claves. Los datos persisten entre reinicios de Asterisk. La API de familia/clave no ha cambiado respecto al backend anterior; solo cambió el formato de almacenamiento en disco.

### Funciones, aplicaciones y comandos de la CLI

Existen algunas funciones, aplicaciones y comandos de la CLI que funcionan con AstDB:

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

Ejemplos:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

Algunas aplicaciones pueden utilizarse para manipular AstDB:

- DB_DELETE(<family/key>) — función que devuelve y elimina una sola clave
- DBdeltree(<family>) — aplicación que elimina una familia/subárbol completo

La antigua aplicación `DBdel()` ya no existe en Asterisk 22. Elimine una sola clave con la función de dialplan `DB_DELETE()` — por ejemplo, `Set(x=${DB_DELETE(family/key)})` o, como una operación de escritura, `Set(DB_DELETE(family/key)=)`. `DBdeltree()` (eliminar una familia/subárbol completo) sigue siendo una aplicación.

Es posible utilizar comandos de la CLI para establecer y eliminar claves también:

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### Implementación de desvío de llamadas, DND y listas negras

En este ejemplo, aprenderá cómo implementar el desvío de llamadas inmediato y el desvío de llamadas por ocupado. Usaremos *21* para programar el desvío de llamadas inmediato y *61* para programar el desvío de llamadas por estado ocupado. Para cancelar la programación, utilice #21# y #61#, respectivamente. Utilice el ejemplo anterior para poblar la base de datos. Familias utilizadas:

- CFIM – Call Forward Immediate (Desvío inmediato)
- CFBS – Call Forward on Busy status (Desvío por ocupado)
- DND – Do Not Disturb (No molestar)

Intente poblar la base de datos marcando:

- *21* (Extensión de destino para el desvío de llamadas inmediato)
- *61* (Extensión de destino para el desvío de llamadas por estado ocupado)
- *41* (Extensión para activar el modo no molestar)

Utilice el comando de la CLI database show para ver las familias, claves y valores añadidos.

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### Desvío de llamadas, lista negra, DND

La subrutina verifica si la base de datos contiene los pares clave:valor correspondientes a CFIM, CFBS o DND, y luego los maneja de manera apropiada. La siguiente subrutina llama a la rutina de marcado:

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## Uso de una lista negra

La antigua aplicación `LookupBlacklist()` fue **eliminada** de Asterisk (desapareció junto con el mecanismo heredado "priority+101 jump"). En Asterisk 22, usted construye una lista negra directamente con la función `DB_EXISTS()` (que tanto comprueba una clave como, cuando la encuentra, expone su valor en `${DB_RESULT}`) además de `GotoIf`. Almacene cada número bloqueado como una clave en una familia `blacklist`, luego verifique el caller ID al inicio de su context de entrada:

```
[incoming]
exten => s,1,GotoIf($[${DB_EXISTS(blacklist/${CALLERID(num)})}]?blocked,s,1)
exten => s,n,Dial(PJSIP/4000,20,tT)
exten => s,n,Hangup()
[blocked]
exten => s,1,Answer()
exten => s,2,Playback(blockedcall)
exten => s,3,Hangup()
```

`DB_EXISTS(blacklist/${CALLERID(num)})` devuelve `1` cuando el número de la persona que llama está presente en la base de datos (enviando la llamada al context `blocked`) y `0` en caso contrario, por lo que la llamada continúa hacia el `Dial()` normal.

Para insertar un número en la lista negra, podemos usar el mismo recurso que antes, utilizando *31* seguido de las extensiones que se incluirán en la lista negra. Para eliminar un número de la lista negra, debe usar #31# seguido del número que desea eliminar.

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

También puede insertar los números en la lista negra usando la CLI de la consola:

```
*CLI>database put blacklist <name/number> 1
```

Nota: Cualquier valor puede asociarse con la clave. La prueba `DB_EXISTS()` busca la clave, no el valor. Para borrar el número de la lista negra, puede usar:

```
*CLI>database del blacklist <name/number>
```

## Contextos basados en tiempo

En la siguiente figura, tenemos un dialplan con tres contextos. El contexto [incoming] es donde usualmente se reciben las llamadas. Hemos incluido cuatro líneas que cambian el comportamiento dependiendo de la hora del sistema, como se ejemplifica a continuación:

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

El Asterisk moderno (incluyendo la versión 22) separa los campos de time-include con **comas**, no con barras verticales (pipes). La forma heredada con barras verticales (`include => context|times|weekdays|mdays|months`) se analiza como un nombre de contexto literal simple y falla silenciosamente al aplicar cualquier condición de tiempo.

Durante el horario laboral regular, el procesamiento será redirigido al mainmenu, donde probablemente llamará a un IVR para gestionar la llamada entrante. Si la llamada ocurre fuera del horario laboral, llamará a la extension de seguridad definida en la variable ${SECURITY}. Si la extension de seguridad no responde la llamada, esta será enviada al voicemail del operador.

![10-dialplan-advanced-features figura 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features figura 12](../images/10-dialplan-advanced-features-img12.png)

## Mensajes basados en tiempo usando gotoiftime()

La sintaxis de GotoIfTime() se muestra a continuación.

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

En Asterisk 22, el separador de campos es una **coma**, no una barra vertical (la forma con barra vertical fue declarada obsoleta en Asterisk 1.6). Se admite un campo opcional `timezone` y cada etiqueta de rama utiliza la forma habitual `[[context,]extension,]priority`.

Esta aplicación puede reemplazar el context basado en tiempo y parece más fácil de entender y leer. Puede especificar el tiempo de la siguiente manera:

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=número del 1 al 31
- <hour>=número del 0 al 23
- <minute>=número del 0 al 59
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

Los nombres de los días y meses no distinguen entre mayúsculas y minúsculas.

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

La instrucción anterior transfiere el procesamiento a la extension s en el context normalhours si la llamada ocurre entre las 08:00AM y las 06:00PM de lunes a viernes.

## Uso de DISA para obtener un nuevo tono de marcado

DISA, o "direct inward system access", es un sistema que permite a los usuarios recibir un segundo tono de marcado. Permite a los usuarios marcar de nuevo hacia otro destino. A menudo es utilizado por técnicos al realizar llamadas de larga distancia para soporte técnico durante los fines de semana; en lugar de marcar desde sus hogares directamente al destino, llaman al número DISA de la oficina, reciben un tono de marcado y luego llaman al destino. Los cargos de larga distancia se generan en la empresa en lugar de en el teléfono del hogar.

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

Ejemplo:

```
exten => s,1,DISA(no-password,default)
```

Utilizando la instrucción anterior, el usuario marca al PBX y, sin requerir ninguna contraseña, recibe un tono de marcado. Cualquier llamada que utilice DISA será procesada usando el context `default`. Los argumentos para esta aplicación incluyen una contraseña global o una contraseña individual dentro de un archivo. Si no se especifica un context, se asume el context `disa`. Si utiliza un archivo de contraseñas, se debe especificar la ruta completa. También se puede especificar un caller ID para la marcación externa de DISA. Ejemplo:

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22 utiliza comas como separadores de argumentos (la forma con barra vertical fue obsoleta desde 1.6). El primer argumento es ya sea un código de acceso único o la ruta a un archivo de códigos de acceso, y el context predeterminado cuando no se proporciona ninguno es `disa`.

## Limitar llamadas simultáneas

La función GROUP() le permite contar cuántos canales activos tiene en un grupo al mismo tiempo. Ejemplo: Usted tiene una sucursal en Río de Janeiro, donde los teléfonos siguen el patrón “_214X”. Esta ubicación es atendida por una línea dedicada, con 64K reservados para el ancho de banda de voz. En este caso, el número máximo de llamadas permitidas es 2 (G.729, aproximadamente 31.2K por llamada). Para limitar las llamadas a Río a dos:

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

Voicemail es un sistema de contestador telefónico computarizado que graba mensajes de voz entrantes, guardándolos en el disco o enviándolos por e-mail. A veces cuenta con un directorio donde se pueden buscar buzones de voicemail por nombre. En el pasado, los sistemas de voicemail eran muy costosos. Ahora, con la telefonía IP, el voicemail se está convirtiendo en una característica estándar.

Para configurar el voicemail, debe seguir los siguientes pasos.

**Paso 1: Edite `voicemail.conf` y establezca los parámetros generales.**

- `format` — codec utilizado para grabar el mensaje (por ejemplo, wav49, wav, gsm)
- `serveremail` — de quién debe parecer que proviene la notificación por e-mail
- `maxmsg` — número máximo de mensajes en el buzón; después de este umbral, los mensajes se descartan
- `maxsecs` — duración máxima de un mensaje de voicemail, en segundos
- `minsecs` — duración mínima de un mensaje, en segundos; por debajo de este umbral, no se graba ningún mensaje
- `maxsilence` — cuántos segundos de silencio se tratarán como el final del mensaje

**Paso 2: Edite `voicemail.conf` y cree los buzones de los usuarios.**

### Voicemail.conf

Un buzón se define con una línea por buzón, en el formato:

```
mailboxID => pincode,fullname,email,pager-email,options
```

Los campos son:

- **MailboxID** — usualmente el número de extensión
- **Pincode** — contraseña para acceder al sistema de voicemail
- **Full name** — utilizado por la aplicación de directorio
- **E-mail** — dirección para la notificación de voicemail
- **Pager e-mail** — dirección para la notificación a través de una pasarela SMS o buscapersonas
- **Options** — opciones por buzón (las mismas opciones que en `[general]`, pero aplicadas a este buzón)

Voicemail tiene varias opciones que controlan su comportamiento. Por ahora, nos limitaremos a las opciones predeterminadas y nos concentraremos en la definición del buzón. Después de la sección `[general]` en el archivo, comienza a configurar los IDs de los buzones, cada uno en su propio context. Ejemplo:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

Por favor, consulte las opciones avanzadas en el archivo `voicemail.conf`.

**Paso 3: Configure el archivo `extensions.conf`.**

La subrutina `stdexten` mostrada anteriormente (bajo *Subroutines with GOSUB*) es exactamente el manejador de llamadas/voicemail que necesita aquí: marca la extensión y utiliza el valor de la variable de canal `${DIALSTATUS}` para redirigir el flujo de la llamada al saludo de voicemail adecuado (`b` para ocupado, `u` para no disponible). Llámela con `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` desde cada extensión en `extensions.conf`.

## Uso de la aplicación VoiceMailMain()

La aplicación voicemailmain() se utiliza para configurar el buzón de voicemail. Los usuarios pueden marcar la aplicación, grabar su saludo y escuchar su voicemail. Para llamar a la aplicación en el dialplan, utilice:

```
exten=>9000,1,VoiceMailMain()
```

A continuación, encontrará una lista de las opciones disponibles para la aplicación.

### Sintaxis de la aplicación Voicemail

Esta aplicación permite que la parte que llama deje un mensaje para una lista específica de buzones. Cuando se especifican varios buzones, el saludo se tomará del primer buzón especificado. La ejecución del dialplan se detendrá si el buzón especificado no existe. La sintaxis se muestra a continuación:

```
 [Synopsis]
Leave a Voicemail message.
[Description]
This application allows the calling party to leave a message for the specified
list of mailboxes. When multiple mailboxes are specified, the greeting will
be taken from the first mailbox specified. Dialplan execution will stop if
the specified mailbox does not exist.
The Voicemail application will exit if any of the following DTMF digits are
received:
    0 - Jump to the 'o' extension in the current dialplan context.
    * - Jump to the 'a' extension in the current dialplan context.
This application will set the following channel variable upon completion:
${VMSTATUS}: This indicates the status of the execution of the VoiceMail
application.
    SUCCESS
    USEREXIT
    FAILED
[Syntax]
VoiceMail(mailbox[@context][&mailbox[@context][&...]][,options])
[Arguments]
options
```

![10-dialplan-advanced-features figura 13](../images/10-dialplan-advanced-features-img13.png)

```
    b: Play the 'busy' greeting to the calling party.
    d([c]): Accept digits for a new extension in context <c>, if played
    during the greeting. Context defaults to the current context.
    g(#): Use the specified amount of gain when recording the voicemail
    message. The units are whole-number decibels (dB). Only works on supported
    technologies, which is DAHDI only.
    s: Skip the playback of instructions for leaving a message to the
    calling party.
    u: Play the 'unavailable' greeting.
    U: Mark message as 'URGENT'.
    P: Mark message as 'PRIORITY'.
```

En todos los casos, el archivo beep.gsm se reproducirá antes de que comience la grabación. Los mensajes de voicemail se almacenarán en el directorio inbox.

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

Si quien llama presiona 0 (cero) durante el anuncio, la llamada se moverá a la extension 'o' (out) en el context actual del voicemail. Esto puede utilizarse para salir hacia la operadora. Si durante la grabación quien llama presiona # o se agota el límite de silencio, la grabación se detiene y la llamada pasa a la siguiente prioridad. Asegúrese de manejar la llamada después de que se reproduzca el voicemail, como se muestra a continuación.

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### Etiquetado de mensajes de voicemail como urgentes

Puede etiquetar algunos mensajes como "urgentes". Existen dos métodos disponibles para esto:

- Pase la opción 'U' en la aplicación voicemail()
- Especifique review=yes en el archivo voicemail.conf. Si utiliza esta opción, el usuario podrá etiquetar el mensaje como urgente después de grabar las instrucciones de voz.

## Envío de voicemail al correo electrónico

En algunos casos (como el mío), simplemente no utilizamos la aplicación voicemailmain() para leer el correo electrónico. Es más sencillo y práctico enviar todos los mensajes al correo electrónico con el audio adjunto. Utilizando los parámetros ‘attach’ y ‘delete’, puede enviar todos los mensajes al correo electrónico y borrarlos del buzón.

```
attach=yes
delete=yes
```

Para enviar voicemail al correo electrónico, la aplicación voicemail utiliza el agente de transferencia de mensajes (MTA), un componente de su sistema operativo. Debian utiliza Exim como MTA. La aplicación que envía el correo electrónico se define en el parámetro ‘mailcmd’.

```
mailcmd =/usr/sbin/sendmail -t
```

En la distribución Debian de Linux, el MTA es Exim. Para configurar Exim en Debian, utilice:

```
dpkg-reconfigure exim4-config
```

Puede elegir que su MTA envíe un correo electrónico directamente a través de SMTP o un smarthost (generalmente el servidor de correo de su empresa). Verifique con su administrador de correo electrónico la mejor manera de enviar correos electrónicos desde el servidor Asterisk a su servidor de correo.

## Personalización del mensaje de correo electrónico

Puede controlar cómo se envían los mensajes configurando las siguientes variables: Variables para el asunto y el cuerpo del correo electrónico:

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

El cuerpo y el asunto del correo electrónico se construyen a partir de una plantilla que usted configura en la sección `[general]` de `voicemail.conf`. Puede modificar tanto el cuerpo como el asunto, pero el límite de tamaño del mensaje es de 512 bytes. En la plantilla, `\n` inserta una nueva línea y `\t` inserta una tabulación.

El ejemplo `emailsubject` a continuación es sencillo. El ejemplo `emailbody` es muy similar al predeterminado; el predeterminado muestra solo el CIDNAME cuando no es nulo, de lo contrario el CIDNUM, o "an unknown caller" cuando ambos son nulos.

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Interfaz web de voicemail

Existe un script de Perl en la distribución de código fuente llamado `vmail.cgi`, ubicado en `contrib/scripts/vmail.cgi` dentro del árbol de código fuente de Asterisk (todavía se incluye con Asterisk 22). El comando `make install` no instala esta interfaz; debe ejecutar `make webvmail` desde el directorio de código fuente. Este script requiere que el intérprete de comandos Perl y un servidor web (como Apache) estén instalados en el servidor.

```
make webvmail
```

El objetivo `make webvmail` instala el script (setuid root) en el directorio CGI de su servidor web (`HTTP_CGIDIR`) y copia las imágenes de soporte desde `images/*.gif` hacia `HTTP_DOCSDIR/_asterisk` (por defecto `/var/www/html/_asterisk`). Si esas rutas no coinciden con la estructura de su servidor web, edite las variables `HTTP_CGIDIR` y `HTTP_DOCSDIR` en el archivo `Makefile` de nivel superior antes de ejecutar el objetivo.

## Notificación de voicemail

Puede configurar el voicemail para enviar un mensaje de notificación a su teléfono cuando tenga un nuevo voicemail. En Asterisk 22, la indicación de mensaje en espera (MWI) funciona con teléfonos PJSIP y SIP, así como con teléfonos DAHDI. Para indicar un voicemail no escuchado, una luz indicadora puede parpadear o el teléfono puede reproducir un tono de aviso. Debe configurar el buzón en el archivo de configuración del canal correspondiente. Ejemplo: `pjsip.conf` (en la sección endpoint):

```
mailboxes=8590
```

En PJSIP, la sugerencia (hint) del buzón se establece con la opción `mailboxes` dentro de la sección endpoint de `pjsip.conf`, en lugar del antiguo `mailbox=` de `sip.conf`. Las suscripciones MWI son manejadas por el módulo `res_pjsip_mwi`.

![La interfaz web de Comedian Mail (`vmail.cgi`): el inicio de sesión de Asterisk Web-Voicemail — ingrese su buzón y contraseña para reproducir, guardar, reenviar o eliminar voicemail desde un navegador. Todavía se incluye con Asterisk 22 y se instala con `make webvmail`.](../images/10-dialplan-advanced-features-img14.png)

### Laboratorio: Notificación de mensajes en el teléfono

Este laboratorio fue probado utilizando un softphone SIP.

1. Edite `pjsip.conf` y agregue `mailboxes=4401` en la sección endpoint para el dispositivo llamado 4401.
2. Edite el `extensions.conf` y cree una extension para grabar un voicemail en las extensiones 4401.

```
exten=9008,1,voicemail(4401,b)
```

3. Vaya a la consola y recargue.
4. En el softphone SipPulse, abra la configuración de la cuenta SIP y habilite la verificación de voicemail (message-waiting) para la cuenta.
5. Marque 9008 y deje un mensaje.
6. Observe el icono de mensaje en el teléfono.

## Uso de la aplicación directory

Esta aplicación le permite encontrar rápidamente un usuario para llamar. La lista de nombres y las extensiones correspondientes se obtienen del archivo de configuración de voicemail, voicemail.conf. La sintaxis de la aplicación se puede mostrar usando core show application directory:

```
-= Info about application 'Directory' =-
[Synopsis]
Provide directory of voicemail extensions.
[Description]
This application will present the calling channel with a directory of
extensions from which they can search by name. The list of names and
corresponding extensions is retrieved from the voicemail configuration file,
"voicemail.conf".
This application will immediately exit if one of the following DTMF digits
are received and the extension to jump to exists:
'0' - Jump to the 'o' extension, if it exists.
'*' - Jump to the 'a' extension, if it exists.
[Syntax]
Directory([vm-context][,dial-context[,options]])
[Arguments]
vm-context
    This is the context within voicemail.conf to use for the Directory.
    If not specified and 'searchcontexts=no' in "voicemail.conf", then
    'default' will be assumed.
dial-context
    This is the dialplan context to use when looking for an extension
    that the user has selected, or when jumping to the 'o' or 'a' extension.
options
    e: In addition to the name, also read the extension number to the
    caller before presenting dialing options.
    f(n): Allow the caller to enter the first name of a user in the
    directory instead of using the last name.  If specified, the optional
    number argument will be used for the number of characters the user should
    enter.
    l(n): Allow the caller to enter the last name of a user in the
    directory.  This is the default.  If specified, the optional number
    argument will be used for the number of characters the user should enter.
    b(n):  Allow the caller to enter either the first or the last name
    of a user in the directory.  If specified, the optional number argument
    will be used for the number of characters the user should enter.
    m: Instead of reading each name sequentially and asking for
    confirmation, create a menu of up to 8 names.
    p(n): Pause for n milliseconds after the digits are typed.  This
    is helpful for people with cellphones, who are not holding the receiver
    to their ear while entering DTMF.
    NOTE: Only one of the <f>, <l>, or <b> options may be specified.
    *If more than one is specified*, then Directory will act as  if <b> was
    specified.  The number of characters for the user to type defaults to
    '3'.
```

### Laboratorio: Uso de la aplicación directory

1. Edite el archivo voicemail.conf para agregar dos extensiones en el dialplan

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. Cree estas extensiones en su dialplan

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. Vaya a la consola y recargue
4. Marque 9006 y grabe un nombre para cada extensión (4400, 4401)
5. Marque 9007 y seleccione las tres letras del apellido para una extensión (Eas=327). Si esta es la opción correcta, presione ‘1’ para transferir a la extensión.

## Lab: Poniéndolo todo junto

Hasta ahora, has aprendido varios conceptos del dialplan. Pongamos todas las aplicaciones, funciones y conceptos en un ejemplo de dialplan para que puedas entender cómo se utilizan en conjunto. Vamos a guiarte a través de toda la configuración de la PBX para el escenario que se describe a continuación.

- 4 trunks analógicos
- 16 extensiones basadas en SIP
- 3 clases de servicio:
    - restrict (interno, local y 1-800)
    - ld (larga distancia)
    - ldi (internacional)
- Mensaje de fuera de horario
- Auto attendant

### Paso 1 – Configuración de canales

**Trunks analógicos (`chan_dahdi.conf`).** Primero, configuraremos los trunks analógicos en el archivo de configuración de canales DAHDI `chan_dahdi.conf`. En este caso, usaremos una tarjeta T400P Digium con 4 interfaces FXO. Supongamos que el controlador ya está cargado y que el archivo de configuración del controlador (/etc/dahdi/system.conf) está configurado correctamente.

![10-dialplan-advanced-features figura 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**Canales SIP (`pjsip.conf`).** Hemos elegido la numeración del dialplan de 2000 a 2099. Se utilizarán dos codecs: G.729 y G.711 ulaw. El primero se utilizará para teléfonos que usen Asterisk a través de Internet o WAN, mientras que el segundo se utilizará para teléfonos que usen la red local. En `pjsip.conf`, arbitraremos qué dispositivos pertenecerán a cada clase de servicio (restrict, ld, ldi). Para reducir la vulnerabilidad a ataques de fuerza bruta, usaremos las direcciones MAC de los teléfonos como nombres de dispositivo. ¡Recomiendo encarecidamente que utilices contraseñas seguras para evitar ataques de fuerza bruta!

Definimos un transporte y tres plantillas reutilizables — una base de endpoint con los codecs compartidos, una autenticación digest y un AOR de contacto único — luego adjuntamos cada dispositivo a las plantillas y sobrescribimos solo lo que difiere (su context de clase de servicio y credenciales). `host=dynamic` se convierte en un AOR contra el cual se registra el teléfono, y `directmedia` se convierte en `direct_media`:

```ini
; pjsip.conf
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[endpoint-base](!)
type=endpoint
disallow=all
allow=ulaw,gsm
direct_media=yes

[auth-digest](!)
type=auth
auth_type=digest

[aor-single](!)
type=aor
max_contacts=1

[00001A000002](endpoint-base)
context=restrict
auth=00001A000002
aors=00001A000002
mailboxes=20
[00001A000002](auth-digest)
username=00001A000002
password=#s2cr2t#
[00001A000002](aor-single)

[00001A000003](endpoint-base)
context=ld
dtmf_mode=rfc4733
auth=00001A000003
aors=00001A000003
mailboxes=20
[00001A000003](auth-digest)
username=00001A000003
password=#s3cr3t#
[00001A000003](aor-single)

[00001A000004](endpoint-base)
context=ldi
dtmf_mode=rfc4733
auth=00001A000004
aors=00001A000004
mailboxes=20
[00001A000004](auth-digest)
username=00001A000004
password=#s3cr3t#
[00001A000004](aor-single)
```

### Paso 2 – Configurar el dialplan

Ahora comencemos a configurar el extensions.conf. Define las extensiones internas y el marcado local

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

Define LD (larga distancia)

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

Define llamadas internacionales

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Paso 3 - Recibir llamadas usando un auto-attendant

Para recibir llamadas, utiliza dos contexts. El primero es para la operación en horario normal, donde la llamada será recibida por un auto-attendant. El segundo es para fuera de horario, donde la persona que llama recibirá un mensaje como “ha llamado a la empresa XYZ, nuestro horario normal es de 08:00 AM a 06:00 PM; si conoce el número de extensión de destino puede intentar marcarlo ahora o colgar”. Menús: Horario normal, Fuera de horario En los menús a continuación, el sistema reproducirá un mensaje advirtiendo a la persona que llama que se comunicó con la empresa fuera del horario laboral regular, permitiendo que la persona marque el número de extensión de destino (alguien podría estar trabajando después del horario laboral regular).

```
[incoming]
include=>normalhours,08:00-18:00,mon-fri,*,*
include=>afterhours,18:00-23:59,*,*,*
include=>afterhours,00:00-07:59,*,*,*
include=>afterhours,*,sat-sun,*,*
[normalhours]
exten=>s,1,Goto(mainmenu,s,1)
[afterhours]
exten=>s,1,Background(afterhours)
exten=>s,2,hangup()
exten=>i,1,hangup()
exten=>t,1,hangup()
include=>restrict
```

Menús: Principal y Ventas Durante el horario laboral normal, la llamada es contestada por un menú de auto-attendant, recibiendo un mensaje como “bienvenido a XYZ Company; marque 1 para ventas, 2 para soporte técnico, 3 para capacitación, o el número de extensión deseado”.

```
[globals]
OPERATOR=PJSIP/2060
SALES=PJSIP/2035
TECHSUPPORT=PJSIP/2004
TRAINING=PJSIP/2036
[mainmenu]
exten=> s,1,Background(welcome)
exten=>1,1,Goto(sales,s,1)
exten=>2,1,Goto(techsupport,s,1)
exten=>3,1,Goto(training,s,1)
exten=>i,1,Playback(Invalid)
exten=>i,2,hangup()
exten=>t,1,Dial(${OPERATOR},20,Tt)
include=>restrict
[sales]
exten=>s,1,Dial(${SALES},20,Tt)
[techsupport]
exten=>s,1,Dial(${TECHSUPPORT},20,Tt)
[training]
exten=>s,1,Dial(${TRAINING},20,Tt)
```

Con todas estas sentencias, la funcionalidad de tu dialplan ya está lista. En la siguiente sección, demostraremos cómo operar la PBX.

## Resumen

En este capítulo, usted ha aprendido cómo recibir llamadas utilizando un IVR o un contestador automático. Ha estudiado el concepto de inclusión de context y ha implementado algunos ejemplos. Se utilizaron subrutinas para evitar la escritura repetitiva, y la base de datos de Asterisk (AstDB, respaldada por SQLite3 en Asterisk 22) se utilizó para funciones que requieren almacenamiento de datos (por ejemplo, desvío de llamadas, no molestar, listas negras). Finalmente, ha aprendido cómo implementar el comportamiento fuera de horario y ha implementado un dialplan completo utilizando estos conceptos.

## Quiz

1. Un include de context dependiente del tiempo utiliza la forma `include => context,<times>,<weekdays>,<mdays>,<months>`. ¿Qué hace `include => normalhours,08:00-18:00,mon-fri,*,*`?
   - A. Ejecutar las extensiones de lunes a viernes, de 08:00 a 18:00
   - B. Ejecutar las opciones todos los días en todos los meses
   - C. Nada; el formato es inválido
2. En Asterisk moderno (incluyendo Asterisk 22), los campos de un `include =>` basado en tiempo y de `GotoIfTime()` están separados por ¿qué carácter?
   - A. La barra vertical `|`
   - B. La coma `,`
   - C. El punto y coma `;`
   - D. La barra diagonal `/`
3. Para marcar varios canales a la vez (haciéndolos sonar simultáneamente), los separa dentro de `Dial()` con el carácter ___.
4. Un menú de voz que reproduce un mensaje mientras espera a que la persona que llama marque una extension se crea usualmente con la aplicación ___.
5. Puede incluir el contenido de otro archivo dentro de `extensions.conf` usando la sentencia ___ (nota: esto es diferente a la sentencia de context `include =>`).
6. En Asterisk 22, la base de datos integrada AstDB está respaldada por:
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. Cuando utiliza `Dial(type1/identifier1&type2/identifier2)`, Asterisk marca cada canal en secuencia, esperando 20 segundos entre ellos.
   - A. Falso
   - B. Verdadero
8. Con la aplicación Background(), debe esperar hasta que el mensaje termine de reproducirse antes de poder presionar un dígito DTMF para elegir una opción.
   - A. Falso
   - B. Verdadero
9. Dada la sintaxis `Goto([[context,]extension,]priority)`, ¿cuáles de las siguientes son invocaciones válidas de la aplicación Goto()? (marque todas las que apliquen)
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Para eliminar una sola clave de AstDB en el dialplan de Asterisk 22, utiliza:
    - A. La aplicación `DBdel()`
    - B. La función `DB_DELETE()`
    - C. La aplicación `DBdeltree()`
    - D. La aplicación `LookupBlacklist()`

**Respuestas:** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
