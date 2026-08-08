# Colas de llamadas

Las colas de llamadas, también conocidas como ACD (Automatic Call Distribution), son cada vez más importantes para responder a las llamadas de los clientes de manera eficiente. Un distribuidor automático de llamadas puede ayudar a reducir costos, aumentar el servicio y mejorar las ventas, ya que los distribuidores de llamadas afectan la forma en que funciona su negocio, no por unos pocos días, sino por muchos años. En un entorno de call center, el factor número uno es la gente; ellos son el recurso más costoso. Se requiere tiempo, dinero y paciencia para contratar, capacitar y motivar a los agentes. Con un ACD, usted puede maximizar la productividad de los agentes dimensionando con precisión el número de agentes requeridos, controlando a los buenos y malos asistentes, y analizando el flujo de llamadas.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Comprender por qué y cómo utilizar colas de llamadas
- Comprender la teoría básica de las colas de llamadas
- Instalar y configurar el sistema de colas

## ¿Cómo funcionan las colas?

Las colas de llamadas no son exactamente una novedad. Cuando se tiene un alto flujo de llamadas entrantes, es difícil distribuirlas de manera adecuada. Usar una estrategia de grupo donde el teléfono suene simultáneamente en todos los agentes no parece funcionar, a menos que solo tenga unos pocos agentes. Sin embargo, una cola de llamadas solo entregará llamadas a un único agente disponible a la vez y pondrá al cliente en espera con música cuando no haya agentes disponibles. La cola funciona reteniendo la llamada mientras busca un agente desocupado para responderla. Uno de los mayores beneficios de la cola es evitar la pérdida de llamadas mientras se brinda la posibilidad de generar estadísticas.

![Una cola de llamadas: las llamadas entrantes 1-800 ingresan a la cola y una estrategia ACD (ringall, rrmemory, leastrecent, priority y otras) las distribuye a los agentes disponibles](../images/14-queues-fig01.png)

Por lo general, una cola de llamadas funciona así:

- Los agentes inician sesión en la cola.
- Las llamadas entrantes se ponen en cola.
- Se utiliza una estrategia de encolamiento para distribuir las llamadas y enviarlas a los agentes.
- Se reproduce música en espera mientras la persona que llama espera.
- Se pueden realizar anuncios a las personas que llaman, notificándoles el tiempo de espera.
- La llamada es respondida por el agente y se generan estadísticas.

La aplicación principal de las colas es el servicio al cliente. Al usar colas, evita perder llamadas cuando sus agentes están ocupados. Puede agregar nuevos agentes a la cola si descubre que la cantidad de personas en espera está creciendo. Otra ventaja de las colas es que ahora puede obtener estadísticas como la tasa de abandono de llamadas, la duración promedio de las llamadas y el objetivo de respuesta de llamadas. Estas estadísticas le ayudarán a determinar cuántos agentes utilizar para brindar un mejor servicio a su cliente.

### Arquitectura ACD

La arquitectura ACD está formada por colas y agentes. Un agente puede estar en dos colas al mismo tiempo. Una cola puede tener agentes, canales y grupos de agentes.

![Arquitectura ACD: cada cola (Servicio al Cliente, Ventas Internas) es alimentada por un número de teléfono y entrega llamadas a los agentes, quienes a su vez están vinculados a canales físicos](../images/14-queues-fig02.png)

## Queues

Las colas se definen en el archivo de configuración queues.conf. Los agentes son los encargados que inician sesión y son miembros de las colas. Los agentes se definen en el archivo agents.conf. El sistema de colas ha crecido significativamente a lo largo de muchas versiones, lo que hace que el archivo de configuración sea extenso. Explicaremos algunos de los parámetros principales. Un parámetro general que vale la pena destacar es `autofill`:

```
autofill=yes
```

El comportamiento antiguo de la cola era de tipo serial. La cola esperaba a que una llamada fuera despachada antes de enviar la siguiente llamada al siguiente agente. Si un agente tardaba 15 segundos en contestar una llamada, las otras llamadas en la cola debían esperar hasta que esa llamada fuera contestada. Para colas de alto volumen, este comportamiento era ineficiente. El nuevo comportamiento autofill=yes no espera hasta que se conteste una llamada, sino que trabaja en paralelo. Puede grabar las llamadas en la cola utilizando la opción mixmonitor. En este modo, las llamadas se graban y se mezclan al mismo tiempo.

### Archivo de configuración de colas

Las colas se configuran en el archivo queues.conf. En la figura, encontrará un ejemplo funcional de una cola.

![Un ejemplo funcional del archivo queues.conf, que muestra la sección general y una cola customerservice con estrategia, nivel de servicio, anuncios, grabación y miembros](../images/14-queues-fig03.png)

### Agentes

Puede configurar sus agentes en el archivo agents.conf. Los agentes pueden iniciar sesión desde cualquier extension para recibir llamadas. Puede llamar a un agente usando:

```
Dial(agent/<name>)
```

#### Inicio de sesión de agente

El flujo de inicio de sesión para el Agente 300 funciona así:

- El usuario marca una extension que ejecuta la aplicación `AgentLogin()`.
- `AgentLogin()` se ejecuta y el agente se asocia con el canal actual.
- Puede verificar el estado de los agentes usando el comando `agent show all`.

![Agentes: un usuario inicia sesión marcando una extension que ejecuta la aplicación agentlogin, la cual vincula al Agente 300 con el canal actual; puede verificar el estado del agente con `agent show all`](../images/14-queues-fig04.png)

Puede definir los agentes en el archivo agents.conf

```
; Agent configuration
[general]
persistentagents=yes
[agents]
autologoff=15
autologoffunavail=yes
ackcall=no
endcall=yes
wrapuptime=5000
musiconhold => default
;
;This section contains the agent definitions, in the form:
;
; agent => agentid,agentpassword,name
;
agent => 300,300
agent => 301,301
```

### Miembros

Los miembros son canales activos que responden a la cola. Los miembros pueden ser canales directos (PJSIP, DAHDI) o agentes que inician sesión antes de recibir llamadas.


### Estrategias

Las llamadas se distribuyen entre los miembros de acuerdo con una de estas estrategias:

- ringall: Hace sonar todos los canales disponibles hasta que alguien contesta.
- leastrecent: Distribuye al miembro menos reciente.
- fewestcalls: Distribuye al miembro con menos llamadas.
- random: Hace sonar una interfaz aleatoria.
- wrandom: Hace sonar una interfaz aleatoria, pero utiliza la penalización del miembro como peso al calcular su métrica.
- rrmemory: Utiliza round robin con memoria; recuerda dónde se quedó con la llamada en la última pasada.
- rrordered: Igual que rrmemory, excepto que se conserva el orden de los miembros de la cola del archivo de configuración.
- linear: Hace sonar a los miembros en el orden en que aparecen listados en queues.conf; para miembros dinámicos, en el orden en que fueron agregados.

La estrategia antigua `roundrobin` fue obsoleta desde Asterisk 1.4. Ya no es una estrategia documentada y no debería utilizarse: en Asterisk 22 el analizador todavía acepta la palabra `roundrobin`, pero solo como un alias de compatibilidad con versiones anteriores que apunta a `rrmemory`. Utilice `rrmemory` (o `rrordered`) explícitamente en su lugar. La lista anterior es el conjunto de estrategias documentadas para la opción `strategy` en el `queues.conf` de Asterisk 22.

## Agentes

Los agentes se implementan como canales proxy. Pueden utilizarse dentro de las colas. Otro uso para los canales de agente es la movilidad de extensiones. El usuario puede iniciar sesión usando cualquier teléfono y recibir sus llamadas. Esto permite que un usuario vaya a cualquier habitación para convertirla en una oficina. Puede marcar a un agente en el dialplan usando dial(agent/<name>). Los agentes se definen en el archivo agents.conf.

![Movilidad de agentes: el usuario levanta cualquier teléfono, marca una extensión de inicio de sesión e ingresa el número de agente y la contraseña; después de que agentlogin() tiene éxito, el agente (Agent 300) está listo para recibir llamadas, y puede verificar el estado con el comando de CLI `agent show all`](../images/14-queues-fig05.png)

### Grupos de agentes

Puede optar por utilizar grupos de agentes. Esta función no toma en consideración las estrategias de ACD. Probablemente preferirá listar a todos los agentes individualmente. Si desea transferir a un grupo de agentes, puede usar `queues.conf`:

```
member => agent/@1    ; any agent in group 1
member => agent/:1,1  ; any agent in group 1, wait for first available
```

### El archivo de configuración para agentes

Los agentes se definen en el archivo agents.conf. A continuación se muestra un ejemplo funcional del archivo.

![Un ejemplo funcional del archivo agents.conf: una sección general con persistentagents, una sección de agentes con los parámetros predeterminados (autologoff, ackcall, endcall, wrapuptime, musiconhold) y dos definiciones de agente (300 y 301)](../images/14-queues-fig06.png)

## Aplicaciones relacionadas con ACD

El sistema de colas de Asterisk pone a disposición varias aplicaciones para implementar las colas en el dialplan. A continuación, mostramos algunas de ellas.

### La aplicación queue()

Esta aplicación pone en cola las llamadas entrantes en una cola de llamadas específica según lo definido en queues.conf. La cadena de opciones puede contener cero o más opciones de una sola letra (que se muestran en la figura a continuación). Además de transferir la llamada, una llamada puede ser puesta en espera y luego ser atendida por otro usuario. La URL opcional se enviará a la parte llamada si el canal lo admite. El parámetro AGI opcional configurará un script AGI para que se ejecute en el canal de la parte que llama una vez que se conecte a un miembro de la cola. El timeout hará que la cola falle después de una cantidad específica de segundos, verificada entre cada ciclo de tiempo de espera y reintento. Esta aplicación establece la variable de estado QUEUE al finalizar:

![La aplicación queue(): su sintaxis `Queue(queuename,options,URL,announceoverride,timeout,AGI)` — Asterisk 22 separa los argumentos con comas (la forma antigua con barra vertical `|` ya no existe) — y las opciones de una sola letra disponibles (d, h, H, n, i, r, t, T, w, W)](../images/14-queues-fig07.png)

- TIMEOUT
- FULL
- JOINEMPTY
- LEAVEEMPTY
- JOINUNAVAIL
- LEAVEUNAVAIL

### La aplicación agentlogin()

Esta aplicación solicita al agente que inicie sesión en el sistema. Siempre devuelve -1. Mientras está conectado, el agente que recibe llamadas escuchará un pitido cuando entre una nueva llamada. El agente puede descartar la llamada presionando la tecla *.

![La aplicación agentlogin(): su sintaxis `AgentLogin([AgentNo][|options])` y la opción `s` para un inicio de sesión silencioso que no anuncia la confirmación de inicio de sesión](../images/14-queues-fig08.png)

### La aplicación addQueueMember()

Esta aplicación agrega dinámicamente un dispositivo (por ejemplo, PJSIP/3000) a una cola. Si el dispositivo ya existe, devolverá un error.

```
AddQueueMember(queuename[|interface][|penalty]):
```

#### La aplicación removeQueueMember()

Esta aplicación elimina dinámicamente un dispositivo de la cola. Si el dispositivo no pertenece a la cola, devolverá un error.

```
RemoveQueueMember(queuename[|interface])
```

### Aplicaciones de soporte y comandos CLI

Algunas aplicaciones y comandos de consola son capaces de ayudar en el trabajo con colas. A continuación se describe lo que hace cada aplicación:

![Aplicaciones de soporte (AddQueueMember, RemoveQueueMember) y comandos CLI (agent show all, queue show, queue show <name>) utilizados para gestionar colas en tiempo de ejecución](../images/14-queues-fig09.png)

## Tareas de configuración

La siguiente figura resume las tareas principales para crear un sistema de colas funcional.

![Las tareas de configuración de ACD: (1) crear la cola de llamadas (obligatorio), (2) definir los parámetros del agente (opcional), (3) crear agentes (opcional), (4) colocar la cola en el dialplan (obligatorio), (5) configurar la grabación del agente (opcional) y (6) verificar con agent show all y queue show (opcional)](../images/14-queues-fig10.png)

Paso 1: Crear la cola de llamadas en el archivo queues.conf:

```
[telemarketing]
music = default
;announce = queue-telemarketing
;context = qoutcon
timeout = 2
retry = 2
maxlen = 0
member => Agent/300
member => Agent/301
[auditing]
music = default
;announce = queue-auditing
;context = qoutcon
timeout = 15
retry = 5
maxlen = 0
member => Agent/600
member => Agent/601
```

Paso 2: Definir los parámetros del agente en el archivo agents.conf:

```
debian:/etc/asterisk# cat agents.conf
;
; Agent configuration
;
[agents]
; Define maxlogintries to allow agent to try max logins before
; failed.
; default to 3
maxlogintries=5
; Define autologoff times if appropriate.  This is how long
; the phone has to ring with no answer before the agent is
; automatically logged off (in seconds)
autologoff=15
; Define autologoffunavail to have agents automatically logged
; out when the extension that they are at returns a CHANUNAVAIL
; status when a call is attempted to be sent there.
; Default is "no".
;autologoffunavail=yes
; Define ackcall to require an acknowledgement by '#' when
; an agent logs in using agentcallbacklogin.  Default is "no".
;ackcall=no
; Define endcall to allow an agent to hangup a call by '*'.
; Default is "yes". Set this to "no" to ignore '*'.
;endcall=yes
; Define wrapuptime.  This is the minimum amount of time when
; after disconnecting before the caller can receive a new call
; note this is in milliseconds.
;wrapuptime=5000
; Define the default musiconhold for agents
; musiconhold => music_class
;musiconhold => default
;
; Define the default good bye sound file for agents
; default to vm-goodbye
;agentgoodbye => goodbye_file
; Define updatecdr. This is whether or not to change the source
; channel in the CDR record for this call to agent/agent_id so
; that we know which agent generates the call
;updatecdr=no
;
; Group memberships for agents (may change in mid-file)
;
;group=3
;group=1,2
;group=
```

Paso 3: Crear los agentes en el archivo agents.conf:

```
;agent => agentid,agentpassword,name
[agents]
agent => 300,300,Test Rep - 300
agent => 301,301,Test Rep . 301
agent => 600,600,Test Ver - 600
agent => 601,601,Test Ver . 601
```

Paso 4: Insertar la cola en el dialplan, en el archivo `extensions.conf`:

```
; Telemarketing queue.
exten=>_0800XXXXXXX,1,Answer
exten=>_0800XXXXXXX,2,Set(CHANNEL(musicclass)=default)
exten=>_0800XXXXXXX,3,Set(TIMEOUT(digit)=5)
exten=>_0800XXXXXXX,4,Set(TIMEOUT(response)=10)
exten=>_0800XXXXXXX,5,Background(welcome)
exten=>_0800XXXXXXX,6,Queue(telemarketing)
; Transfer to the queue auditing
exten => 8000,1,Queue(auditing)
exten => 8000,2,Playback(demo-echotest); No auditor available
exten => 8000,3,Goto(8000,1) ; Verify auditor again
; Agent login for the telemarketing and auditing queues
exten => 9000,1,Wait(1)
exten => 9000,2,AgentLogin()
```

### Configurar la grabación de colas

Las llamadas pueden grabarse utilizando la aplicación MixMonitor de Asterisk. (La aplicación independiente Monitor fue eliminada en Asterisk 22, y la opción `monitor-type` de queues.conf ahora solo acepta MixMonitor.) La grabación puede habilitarse desde dentro de la aplicación de cola, comenzando cuando la llamada es efectivamente contestada. Solo se graban las llamadas exitosas y no se realizan grabaciones mientras las personas escuchan MOH. Para habilitar la monitorización, simplemente especifique monitor-format. Esta función está deshabilitada de otro modo. Puede establecer el nombre del archivo para la grabación usando `Set(MONITOR_FILENAME=<filename>)`; de lo contrario, utilizará `MONITOR_FILENAME=${UNIQUEID}`.

En el archivo queues.conf:

```
monitor-format = wav
monitor-type = MixMonitor
monitor-join = yes
```

## Operación de colas

Los siguientes ejemplos explican cómo utilizar la cola.

1. Inicio de sesión del agente. Ejemplo: Un agente en la cola de telemarketing levanta el teléfono y marca #9000. El agente escucha un mensaje de inicio de sesión no válido y se le solicita su nombre y contraseña. La cola de auditoría sigue el mismo procedimiento.
2. Cola. Una vez en la cola, el agente escuchará MOH, si está definido. Cuando entra una llamada a la cola de telemarketing, el agente escuchará un pitido y será conectado a esa llamada.
3. Finalización de la llamada. Cuando el agente termina la llamada, él/ella puede:
   - Presionar ‘*’ para desconectarse y permanecer en la cola.
   - Desconectar el teléfono, desconectándose así de la cola.
   - Presionar #8000 para transferir la llamada para auditoría.

## Recursos avanzados

El sistema de colas de Asterisk cuenta con algunas funciones avanzadas para priorizar a ciertos clientes y agentes, así como para habilitar un menú de usuario.

### Menú de usuario

Puede definir un menú para un usuario mientras espera en la cola utilizando extensiones de un solo dígito. Para habilitar esta opción, defina un context en la configuración de colas queues.conf.

### Penalización

Los agentes pueden configurarse con una penalización. Una cola enviará las llamadas primero a los usuarios con valores de penalización más bajos. Por ejemplo, dado que sabemos que a nuestros clientes les encanta Susan y su voz suave, podemos optar por asignarle una prioridad 0. Alternativamente, el agente llamado Uber, quien tiene menos experiencia, es menos preferido para el servicio al cliente; por lo tanto, le asignamos una prioridad 10 a este agente. En el archivo queues.conf:

```
[customerservice]
member=300,0,Susan the excellent agent
member=300,10,Uber the new guy
```

### Prioridad

Las colas operan en modo FIFO (primero en entrar, primero en salir). Si desea dar prioridad a clientes especiales (platino, oro), puede configurar prioridades diferenciadas. Para clientes platino u oro:

```
exten=>111,1,Playback(welcome)
exten=>111,2,Set(QUEUE_PRIO=10)
exten=>111,3,Queue(customerservice)
```

Clientes azules:

```
exten=>112,1,Playback(welcome)
exten=>112,2,Set(QUEUE_PRIO=5)
exten=>112,3,Queue(customerservice)
```

## La aplicación agentcallbacklogin() ha sido eliminada

La aplicación `agentcallbacklogin()` fue declarada obsoleta por Digium en Asterisk 1.4 (julio de 2006) y ya no está disponible en Asterisk 22. El enfoque recomendado es utilizar `AddQueueMember()` con una interfaz PJSIP para agregar dinámicamente miembros de tipo callback a una cola. El documento `queues-with-callback-members.txt` se incluía en directorios antiguos de Asterisk `/doc` como guía de migración.

El antiguo controlador de canal `chan_agent` fue eliminado de igual manera; su funcionalidad fue reescrita como el módulo `app_agent_pool`, que es el que proporciona `AgentLogin()`, `AgentRequest()` y la función de dialplan `AGENT()` en Asterisk 22 (estos todavía están presentes; `app_agent_pool.so` se incluye en una compilación estándar de 22). Para los centros de llamadas modernos, sin embargo, el patrón estándar es omitir los canales de agente por completo y agregar el dispositivo PJSIP del agente directamente a la cola con `AddQueueMember()`/`RemoveQueueMember()` (de forma estática en `queues.conf`, o de forma dinámica desde el dialplan o AMI). Esto es más sencillo, se integra limpiamente con el estado del dispositivo PJSIP y es el enfoque utilizado a lo largo de este capítulo.

## Estadísticas de colas

Todos los eventos de las colas se registran en /var/log/asterisk/queue_log. El formato del registro de colas se publica en el documento queuelog.txt en el directorio /doc de la documentación de Asterisk. A continuación, se presentan algunos de los eventos registrados más importantes.

- ABANDON(position|origposition|waittime)
- AGENTDUMP
- AGENTLOGIN(channel)
- AGENTLOGOFF(channel|logintime)
- ATTENDEDTRANSFER(destexten|destcontext|holdtime|calltime|origposition)
- BLINDTRANSFER(extension|context|holdtime|calltime|origposition)
- COMPLETEAGENT(holdtime|calltime|origposition)
- COMPLETECALLER(holdtime|calltime|origposition)
- CONFIGRELOAD
- CONNECT(holdtime|bridgedchanneluniqueid)
- ENTERQUEUE(url|callerid)
- EXITEMPTY(position|origposition|waittime)
- EXITWITHKEY(key|position)
- EXITWITHTIMEOUT(position|origposition|waittime)
- QUEUESTART
- RINGNOANSWER(ringtime)
- SYSCOMPAT

Puede crear su propia utilidad para procesar estos eventos o utilizar un paquete de estadísticas listo para usar:

- **QueueMetrics** (<https://www.queuemetrics.com/>) – un paquete comercial con mantenimiento activo que analiza `queue_log` y sigue siendo una de las herramientas de informes más completas para centros de llamadas Asterisk.
- **Desarrollo propio** – debido a que el formato `queue_log` anterior es estable y está bien documentado, es sencillo analizarlo con un script pequeño (Python, etc.) y enviar los eventos a una base de datos o tablero de control.

Para un enfoque más orientado a eventos que el simple seguimiento de `queue_log`, la **Asterisk REST Interface (ARI)** y las acciones de **AMI** `QueueSummary`/`QueueStatus` le permiten crear tableros de control de colas en vivo e integraciones personalizadas basadas en el estado de la cola en tiempo real, en lugar de analizar registros después de los hechos. ARI es la superficie de integración moderna y compatible para este tipo de trabajo en Asterisk 22.

## Resumen

En este capítulo usted ha aprendido cómo utilizar un ACD, su arquitectura y cómo configurarlo. También se presentaron algunas funciones avanzadas como prioridades y penalizaciones.

## Cuestionario

1. ¿Cuáles de las siguientes son estrategias de distribución de cola válidas en `queues.conf` (elija todas las que correspondan)?
   - A. ringall
   - B. roundrobin
   - C. leastrecent
   - D. fewestcalls
   - E. rrmemory
   - F. linear
2. Puede grabar una conversación entre un agente y un cliente desde dentro de la cola configurando la opción ___ en el archivo `queues.conf`.
3. ¿Qué `strategy` hace sonar a los miembros en el orden exacto en que aparecen listados en `queues.conf`?
   - A. random
   - B. wrandom
   - C. linear
   - D. fewestcalls
4. Cuando el agente termina una llamada en el ejemplo de telemarketing, ¿qué acciones puede realizar (elija todas las que correspondan)?
   - A. Presionar `*` para desconectarse y permanecer en la cola
   - B. Colgar el teléfono y desconectarse de la cola
   - C. Presionar `#8000` para transferir la llamada para auditoría
   - D. Presionar `#` para cerrar sesión en todas las colas inmediatamente
5. ¿Qué dos tareas son *necesarias* para obtener una cola funcional (elija todas las que correspondan)?
   - A. Crear la cola
   - B. Crear los agentes
   - C. Configurar los parámetros del agente
   - D. Configurar la grabación
   - E. Poner la cola en el dialplan
6. En una cola de llamadas puede ofrecer un menú de un solo dígito que la persona que llama puede marcar mientras espera. Esto se habilita definiendo un(a) ___ en la sección `queues.conf` de la cola:
   - A. agent
   - B. menu
   - C. context
   - D. application
7. Las aplicaciones de soporte `AddQueueMember()` y `RemoveQueueMember()` se utilizan en el ___ para agregar o eliminar miembros en tiempo de ejecución:
   - A. dialplan
   - B. command-line interface
   - C. queues.conf
   - D. agents.conf
8. Dado que chan_sip fue eliminado en Asterisk 21, un miembro de cola estático debe hacer referencia a un canal como ___ en lugar de `SIP/1001`.
9. El parámetro `wrapuptime` es el tiempo mínimo después de que un agente desconecta una llamada antes de que la cola le envíe una nueva llamada a ese agente.
   - A. True
   - B. False
10. Se le puede dar a una persona que llama una posición más alta en la misma cola configurando la variable de canal `QUEUE_PRIO` antes de llamar a `Queue()`.
    - A. True
    - B. False

**Respuestas:** 1 — A, C, D, E, F (roundrobin no es una estrategia documentada; en Asterisk 22 sobrevive solo como un alias obsoleto para rrmemory) · 2 — `monitor-format` (la grabación desde la cola se habilita especificando `monitor-format`; en Asterisk 22 `monitor-type` solo admite MixMonitor) · 3 — C (linear) · 4 — A, B, C (`*` desconecta y permanece; `#` no es una tecla para cerrar sesión en todo) · 5 — A, E · 6 — C (la opción `context`) · 7 — A (el dialplan) · 8 — `PJSIP/1001` (cualquier interfaz `PJSIP/`) · 9 — True · 10 — True
