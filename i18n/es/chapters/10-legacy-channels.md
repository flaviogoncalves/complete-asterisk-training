# Canales heredados: analógicos, TDM e IAX2

En un mundo puramente VoIP en 2026, los tipos de canales en este capítulo son cada vez más raros: la mayoría de las implementaciones nuevas son trunks SIP y endpoints PJSIP sobre Ethernet, sin hardware de telefonía en absoluto. No obstante, Asterisk 22 todavía admite la mayoría de ellos por completo. La conectividad analógica (FXO/FXS) y digital TDM (E1/T1/ISDN PRI/BRI) se proporciona a través de DAHDI, la pila de controladores desarrollada originalmente por Digium, que fue adquirida por Sangoma en 2018, después de que los controladores Zaptel anteriores fueran renombrados tras una disputa de marca registrada. La conectividad de servidor a servidor sobre IAX2 se proporciona mediante `chan_iax2`, que todavía se distribuye y admite, pero que ahora es firmemente un protocolo heredado.

Este capítulo también recopila el material de **SIP heredado**: el antiguo controlador `chan_sip` y su configuración `sip.conf` —eliminados en Asterisk 21 y desaparecidos en Asterisk 22— junto con una guía completa para migrar un sistema `sip.conf` existente a PJSIP. Si usted opera un entorno puramente SIP en PJSIP sin tarjetas de telefonía, sin trunks IAX2 y sin `sip.conf` heredado que convertir, puede omitir este capítulo con seguridad.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Conectar Asterisk a líneas y teléfonos analógicos con interfaces FXO/FXS a través de DAHDI;
- Reconocer la conectividad TDM digital (E1/T1, ISDN PRI/BRI) y cómo se configura;
- Configurar IAX2 (`chan_iax2`) para trunks de servidor a servidor y comprender por qué ahora es un estándar heredado;
- Identificar el driver retirado `chan_sip` y la sintaxis `sip.conf` que aún podría encontrar; y
- Migrar un sistema existente `chan_sip`/`sip.conf` a PJSIP.

## Canales analógicos (FXO/FXS)

A partir de Asterisk 22, DAHDI y las tarjetas de telefonía analógica siguen siendo totalmente compatibles, y DAHDI todavía se compila con los kernels actuales. Sin embargo, la mayoría de las implementaciones nuevas son puramente VoIP (troncales SIP, PJSIP), por lo que el hardware analógico/TDM es ahora una opción de nicho, que se encuentra principalmente en entornos heredados, conectividad PSTN rural o mercados regulados. Todo lo que se detalla a continuación sigue siendo aplicable a esos escenarios.

Existen varias formas de conectarse a la red telefónica pública conmutada (PSTN). La mejor manera depende de cómo la compañía telefónica haga disponible esta conexión en su área. La forma más sencilla es utilizar una línea analógica, similar a la línea que utiliza en casa. En esta sección, le mostraremos cómo configurar tarjetas analógicas de Sangoma™ (anteriormente Digium™) y Xorcom™.

### Objetivos

Al final de este capítulo, usted debería ser capaz de:

- Reconocer los principales términos y acrónimos de telefonía;
- Entender cuándo utilizar circuitos digitales y analógicos;
- Reconocer la diferencia entre FXS y FXO; y
- Configurar Asterisk para FXS y FXO.

### Conceptos básicos de telefonía

La mayoría de las implementaciones analógicas utilizan un par de líneas de cobre llamadas tip y ring. Cuando un bucle se cierra, el teléfono recibe el tono de marcado de la central telefónica (o de la PBX privada). La señalización más utilizada es loop-start; otros tipos de señalización menos comunes incluyen ground start, que se utiliza en varios países. Las tres categorías de señalización son:

- Señalización de supervisión
- Señalización de direccionamiento
- Señalización de información

#### Señalización de supervisión

Las principales señalizaciones de supervisión son on-hook, off-hook y ringing.

- **On-Hook** – Cuando un usuario coloca el teléfono en el gancho, la PBX interrumpe y no permite que pase la corriente eléctrica. En este estado, el circuito se denomina on-hook. En esta posición, solo el timbre está activo.
- **Off-Hook** – Antes de iniciar una llamada telefónica, el teléfono necesita pasar al estado off-hook. Retirar el auricular del gancho cierra el bucle e indica a la PBX que el usuario tiene la intención de realizar una llamada. Al recibir esta indicación, la PBX genera un tono de marcado, indicando al usuario que está lista para aceptar la dirección de destino (es decir, el número de teléfono).
- **Ringing** – Cuando un usuario llama a otro teléfono, genera un voltaje hacia el timbre que advierte al otro usuario sobre una llamada entrante. La señalización varía según el país, con diferentes tonos para diferentes países.

Puede personalizar los tonos de Asterisk según su país modificando el archivo indications.conf. Por ejemplo:

```
[br]
description=Brazil
ringcadance=1000,4000
dial=425
busy=425/250,0/250
ring=425/1000,0/4000
congestion=425/250,0/250,425/750,0/250
callwaiting=425/50,0/1000
```

#### Señalización de direccionamiento

Puede utilizar dos tipos de señalización para marcar. La primera y más común es dual tone multi-frequency (dtmf), mientras que la otra es la marcación por pulsos (utilizada en los antiguos teléfonos de disco). Los teléfonos tienen un teclado para marcar, y cada botón está asociado con dos frecuencias: una alta y una baja. En el caso de la señalización dtmf, la combinación de estos tonos indica qué dígito se está presionando. MFC/R2 utiliza un tono multifrecuencia diferente al dtmf.

#### Señalización de información

La señalización de información muestra el progreso de la llamada y diferentes eventos.

- Tono de marcado
- Tono de ocupado
- Tono de retorno de llamada
- Congestión
- Número inválido
- Tono de confirmación

### Interfaces PSTN

Como en el caso de las PBX antiguas, a menudo es necesario conectar la PBX Asterisk a la PSTN. Aquí le mostraremos cómo hacerlo. Por lo general, tiene tres opciones para las líneas telefónicas.

- Analógica: La forma más común para hogares y pequeñas empresas, generalmente entregada con un par metálico de líneas de cobre.
- Digital: Se utiliza cuando son necesarias muchas líneas. Una línea digital generalmente es entregada por un CSU/DSU o un multiplexor de fibra. El conector del usuario final suele ser un RJ45. En algunos países, las líneas E1 se entregan utilizando dos conectores BNC coaxiales; en este caso, necesitará un balun para conectar el jack RJ45 a la tarjeta de telefonía.
- SIP: Esta opción se ha desarrollado recientemente. La línea telefónica se entrega utilizando una conexión de datos con señalización SIP (VoIP). Esta es una buena opción para usar con Asterisk, ya que no necesitará comprar una tarjeta de telefonía. Las llamadas telefónicas se entregarán directamente al puerto Ethernet. Otra ventaja es que es posible que pueda liberar recursos de su CPU evitando la transcodificación de codec.

### Interfaces analógicas FXS, FXO y E&M

Hay varios tipos de interfaces analógicas disponibles. Es fundamental entender las diferencias entre estas interfaces para aprender cómo conectarse a la red telefónica, así como a otras PBX. Aquí, le mostraremos la interfaz E&M. Aunque actualmente no está disponible para Asterisk y ha sido descontinuada por varios proveedores, puede encontrar routers y PBX con este tipo de interfaz, por lo que es mejor saber con qué está tratando.

#### Interfaces Foreign eXchange (FX)

Las interfaces FX son analógicas. El término “Foreign eXchange” se aplica a las troncales de acceso a una oficina central (CO) de la PSTN. Foreign eXchange Office (FXO)

![Asterisk entre un teléfono analógico (FXS) y la línea de la compañía telefónica (FXO): el lado FXS proporciona tono de marcado y timbre al teléfono, mientras que el lado FXO obtiene el tono de marcado de la oficina central.](../images/10-legacy-fig01.png)

La interfaz FXO se utiliza para conectarse a una oficina central (CO) o a la extensión de otra PBX. Se comunica directamente con una línea telefónica proveniente de la PSTN. Otra opción es conectar la interfaz FXO a una PBX existente, permitiendo la comunicación entre Asterisk y la PBX heredada. Conectar Asterisk a un puerto de PBX y entregar una extensión remota mediante VoIP se conoce a menudo como una extensión fuera de las instalaciones (OPX). Una interfaz FXO recibe un tono de marcado. Foreign eXchange Station (FXS) La interfaz FXS alimenta un teléfono analógico, módem o fax. El FXS proporciona el tono de marcado y la energía para un teléfono.

#### Señalización de troncales

- Loop-Start
- Ground-Start
- Kewlstart

El uso de la señalización kewlstart en Asterisk es casi predeterminado. Kewlstart no es una señalización en sí misma, sino que añade inteligencia al circuito al monitorear lo que sucede en el otro lado. Kewlstart se basa en loop-start. La mayoría de los switches no admiten esta función, que se utiliza para obtener la notificación de colgado.

- Loopstart: Utilizado en la mayoría de las líneas analógicas, permite que el teléfono indique “on-hook” y “off-hook” y que el switch indique “ring” y “no-ring”. Esto es probablemente lo que la mayoría de la gente tiene en casa. El nombre proviene del hecho de que la línea siempre está abierta. Cuando cierra el bucle, el switch le proporciona un tono de marcado. Una llamada entrante se señala mediante un voltaje de timbre de 100V sobre el par abierto.

![Asterisk operando como una puerta de enlace VoIP: un puerto FXO se conecta a una extensión de PBX heredada mientras un Asterisk remoto entrega esa línea a un teléfono analógico sobre IP a través de un puerto FXS (una extensión fuera de las instalaciones, o OPX).](../images/10-legacy-fig02.png)

- Groundstart: Similar a Loopstart. Cuando desea realizar una llamada, un lado de la línea se cortocircuita. Cuando el switch identifica este estado, invierte el voltaje a través del par abierto y luego se cierra el bucle. En consecuencia, la línea primero se vuelve ocupada antes de ser ofrecida a quien llama.
- Kewlstart: Añade inteligencia a los circuitos, permitiendo el monitoreo del otro lado. Kewlstart incorpora muchas ventajas de loop-start.

### Configuración de canales de telefonía de Asterisk

Para configurar una tarjeta de interfaz de telefonía, son necesarios varios pasos. En este capítulo, mostraremos tres de los escenarios más comunes:

- Conexión analógica usando FXS
- Conexión analógica usando FXO
- Conexión de un Astribank™ con interfaces FXS y FXO

### Procedimiento de configuración (válido en ambos casos)

Antes de elegir el hardware para Asterisk, debe considerar el número de llamadas simultáneas, servicios y codecs que se van a instalar y habilitar. Asterisk es una aplicación que consume muchos recursos de CPU, razón por la cual recomendamos una máquina dedicada para Asterisk. El número de tarjetas de interfaz instaladas dentro de la computadora está limitado por el número de ranuras e interrupciones disponibles. Es preferible instalar una sola tarjeta con ocho interfaces de voz que dos tarjetas con cuatro. Otra opción es utilizar un banco de canales USB, como el Xorcom Astribank. Recientemente, algunos fabricantes (por ejemplo, CIANET) han comenzado a producir bancos de canales TDMoE, lo que facilita aún más la conexión de docenas de interfaces analógicas.

![Un Xorcom Astribank: un banco de canales USB para montaje en rack de 19 pulgadas que expone docenas de puertos FXS/FXO (aquí una unidad de 32 puertos) sin consumir ranuras PCI en el host.](../images/10-legacy-fig03.png)

#### Ejemplo 1: Instalación de un FXO y un FXS

En este ejemplo, utilizaremos una tarjeta de interfaz de telefonía Sangoma TDM400 (anteriormente vendida como Digium TDM400) con un módulo FXS y uno FXO. Los pasos requeridos se enumeran a continuación:

1. Instale la tarjeta analógica FXS, FXO o ambas.
2. Configure el archivo `/etc/dahdi/system.conf` (anteriormente `/etc/zaptel.conf`).
3. Genere los archivos de configuración usando `dahdi_genconf`.
4. Cargue el controlador para la interfaz DAHDI.
5. Ejecute `dahdi_test` para verificar las pérdidas de interrupción.
6. Ejecute `dahdi_cfg` para configurar el controlador.
7. Configure el canal DAHDI en el archivo `chan_dahdi.conf`, luego cargue Asterisk.

##### Paso 1: Instalar la placa TDM400

La tarjeta TDM404P contiene módulos FXS y FXO. Conecte los módulos FXS (S110M, verde) y FXO (X100M, rojo). Si está utilizando módulos FXS, conecte la tarjeta directamente a la fuente de alimentación utilizando un conector molex. Por favor, utilice protección electrostática antes de manipular las tarjetas de interfaz para evitar daños al hardware. Las tarjetas analógicas Sangoma (anteriormente Digium) también admiten un módulo de cancelación de eco de hardware VPMADT032.

##### Paso 2: Generar la configuración con dahdi_genconf

La buena noticia sobre la configuración es la nueva utilidad `dahdi_genconf`, que detecta automáticamente y genera la configuración para las interfaces DAHDI. La utilidad genera dos archivos:

- `/etc/dahdi/system.conf`
- `/etc/asterisk/dahdi-channels.conf`
- `/etc/asterisk/users.conf` (con la opción `users`)
- Todos estos archivos utilizan la opción `chan_dahdi full`

Antes de que pueda ejecutar `dahdi_genconf`, es importante configurar el archivo `genconf_parameters` (a menudo referido como `gen_parameters.conf`):

![Una tarjeta analógica Sangoma/Digium TDM404P: hasta cuatro módulos FXS o FXO se conectan a los puertos numerados, con una tarjeta hija opcional de cancelación de eco de hardware y un conector de alimentación dedicado de 12 V para módulos FXS.](../images/10-legacy-fig04.png)

```
#
# /etc/dahdi/genconf_parameters
#
# This file contains parameters that affect the
# dahdi_genconf configurator generator.
#
#base_exten          4000
#fxs_immediate       no
#fxs_default_start   ks
#lc_country          il
#context_lines       from-pstn
#context_phones      from-internal
#context_input       astbank-input
#context_output      astbank-output
#group_phones        0
#group_lines         5
#brint_overlap
#bri_sig_style       bri_ptmp
#
# The echo canceller to use. If you have a hardware echo canceller, just
# leave it be, as this one won't be used anyway.
#
# The default is mg2, but it may change in the future. E.g: a packager
# that bundles a better echo canceller may set it as the default, or
# dahdi_genconf will scan for the "best" echo canceller.
#
#echo_can            hpec
#echo_can            oslec
#echo_can            none   # to avoid echo cancellers altogether
# bri_hardhdlc: If this parameter is set to 'yes', in the entries for
# BRI cards 'hardhdlc' will be used instead of 'dchan' (an alias for
# 'fcshdlc').
#
#bri_hardhdlc        yes
# For MFC/R2 Support
#pri_connection_type R2
#r2_idle_bits        1101
# pri_types contains a list of settings:
# Currently the only setting is for TE or NT (the default is TE)
#
#pri_termtype
# SPAN/2              NT
# SPAN/4              NT
```

El archivo `genconf_parameters` le permite personalizar su configuración. Los parámetros más importantes para las líneas analógicas son:

```
base_exten          4000
fxs_immediate       no
fxs_default_start   ks
lc_country          br
context_lines       from-pstn
context_phones      from-internal
context_input       astbank-input
context_output      astbank-output
group_phones        0
group_lines         5
#echo_can           hpec
#echo_can           oslec
echo_can            MG2
```

Advertencia: Es necesario que configure al menos el algoritmo de cancelación de eco para los canales. El parámetro base_exten define el dialplan básico para las extensiones FXS. En este caso, el primer canal FXS recibirá el número de extensión 4000, el segundo 4001, y así sucesivamente. El contexto en el que se crean las líneas (context_phones) y las troncales (context_lines) es muy importante. Después de generar los archivos, debe incluir el archivo `/etc/asterisk/dahdi-channels.conf` en el archivo `/etc/asterisk/chan_dahdi.conf`:

```
#include dahdi-channels.conf
```

Nota: La señalización analógica es un poco confusa; siempre es la inversa de la tarjeta. Las tarjetas FXS se señalan con FXO, mientras que las tarjetas FXO se señalan con FXS. Asterisk habla con estos dispositivos como si estuviera en el lado opuesto.

##### Paso 3: Cargar los controladores del kernel

Ahora tiene que cargar el módulo chan_dahdi y el controlador del kernel de la tarjeta relacionada. Use dahdi_hardware para detectar su tarjeta y el nombre del controlador. Por ejemplo:

| Tarjeta | Controlador | Descripción |
| --- | --- | --- |
| TE410P | wct4xxp | 4xE1/T1 - 3.3V PCI |
| TE405P | wct4xxp | 4xE1/T1 - 5V PCI |
| TDM400P | wctdm | 4 FXS/FXO |
| T100P | wct1xxp | 1 T1 |
| E100P | wct1xxp | 1 E1 |
| X100P | wcfxo | 1 FXO |

Comandos para cargar los controladores:

```
modprobe dahdi
modprobe wctdm
```

##### Paso 4: Usar la utilidad dahdi_test

Una utilidad importante es dahdi_test, que se utiliza para verificar las pérdidas de interrupción en la tarjeta DAHDI. Los problemas de calidad de audio a menudo están relacionados con conflictos de interrupción. Para verificar que su tarjeta DAHDI no esté compartiendo una interrupción con otras tarjetas, use el siguiente comando:

```
#cat /proc/interrupts
```

Puede verificar el número de pérdidas de interrupción utilizando la utilidad dahdi_test compilada con las tarjetas DAHDI. Un número por debajo del 99.987% indica posibles problemas.

##### Paso 5: Usar la utilidad dahdi_cfg para configurar el controlador

DAHDI tiene un sistema inusual para cargar los controladores. Primero configure el /etc/dahdi/system.conf, y luego aplique esas configuraciones al controlador DAHDI usando dahdi_cfg. En este caso, dahdi_cfg se utiliza para configurar la señalización para las interfaces FX. Para ver los resultados, puede añadir “-vvvvv” al comando para obtener información detallada (verbose).

```
#
/sbin/dahdi_cfg -vv
Dahdi Configuration
======================
Channel map:
Channel 01: FXS Kewlstart (Default) (Slaves: 01)
Channel 02: FXO Kewlstart (Default) (Slaves: 02)
2 channels configured.
```

Si los canales se cargaron correctamente, verá una salida similar a la que se muestra arriba. Los usuarios a menudo configuran incorrectamente chan_dahdi.conf con señalización invertida entre canales. Si esto sucede, verá un mensaje como el que se muestra a continuación:

```
DAHDI_CHANCONFIG failed on channel 1: Invalid argument (22)
Did you forget that FXS interfaces are configured with FXO signalling
and that FXO interfaces use FXS signalling?
```

Después de configurar correctamente el hardware, puede proceder a la configuración de Asterisk.

##### Paso 6: Configurar el archivo /etc/asterisk/chan_dahdi.conf

Suena extraño, pero después de configurar el /etc/dahdi/system.conf, usted configuró la tarjeta en sí. DAHDI se puede utilizar para otros fines, como enrutamiento y SS7. Para usarlo con Asterisk, debe configurar los canales DAHDI de Asterisk. Cada canal en Asterisk tiene que ser definido; los canales SIP/PJSIP se definen en pjsip.conf (nota: chan_sip y sip.conf fueron eliminados en Asterisk 21), mientras que los canales TDM se definen en chan_dahdi.conf. Esto crea los canales TDM lógicos que se utilizarán en su dialplan.

```
signalling=fxs_ks;                  ; FXS signaling for the FXO interface
group=1;                            ; channel group
context=incoming;                   ; context
channel => 1;                       ; channel number
signalling=fxo_ks;                  ; FXO signaling for the FXS interface
group=2;                            ; channel group
context=extensions;                 ; context
channel => 2                        ; channel number
```

### Opciones de configuración

Hay varias opciones disponibles en el archivo chan_dahdi.conf. Una descripción de todas las opciones sería aburrida y contraproducente; en su lugar, nos centraremos en los principales grupos de opciones disponibles para una fácil comprensión.

#### Opciones generales (independientes del canal)

Estas opciones funcionan para cualquier canal: context: Define el contexto entrante.

```
context=default
```

channel: Define el canal o rango de canales. Cada definición de canal heredará las opciones definidas antes de la declaración. Los canales pueden identificarse individualmente o en la misma línea mediante separación por comas. Los rangos se pueden definir usando “-”.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Permite que los canales sean manejados como un grupo. Si marca un número de grupo en lugar de un número de canal, se utiliza el primer canal disponible. Si los canales son teléfonos, cuando llama a un grupo, todos los teléfonos sonarán simultáneamente. Con comas, puede especificar más de un grupo para el mismo canal.

```
group=1
group=3,5
```

language: Activa la internacionalización y configura un idioma. Esta función configurará los mensajes del sistema para un idioma específico. El inglés es el único idioma con avisos completos disponibles a través de la instalación estándar. musiconhold: Selecciona la clase de música en espera.

#### Opciones de Caller ID

Hay muchas opciones de callerid. Algunas pueden desactivarse, aunque la mayoría están habilitadas de forma predeterminada. usecallerid: Habilita o deshabilita la transmisión de callerid para los canales subsiguientes (Yes/No). Nota: Si su sistema recibe dos timbres antes de responder, intente deshabilitar esta función. Debería responder inmediatamente. hidecallerid: Define si se debe ocultar o no el callerid saliente (Yes/No). callerid: Configura una cadena de callerid para un canal específico. El caller puede configurarse con asreceived. Esto se utiliza principalmente en interfaces de troncales para indicar el callerid entrante.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

callwaitingcallerid: Admite callerid durante la llamada en espera. useincomingcalleridondahditransfer: Utiliza el callerid entrante en una transferencia.

#### Llamada en espera

Asterisk admite llamada en espera en canales FXS. El usuario recibirá un tono de espera si alguien intenta llamar a la extensión. Para habilitar la llamada en espera:

```
callwaiting=yes
```

Para admitir callerid en llamada en espera:

```
callwaitingcallerid=yes
```

#### Opciones de calidad de audio

Ajustar la cancelación de eco es mitad técnica, mitad arte. Estas opciones ajustan ciertos parámetros de Asterisk que afectan la calidad de audio en los canales DAHDI. Pueden ayudar a mejorar la calidad de audio en las interfaces analógicas.

#### La utilidad fxotune

El fxotune es una utilidad utilizada para ajustar con precisión ciertos parámetros para los módulos FXO. Este ajuste fino es necesario para corregir el desajuste de impedancia causado por el híbrido. La utilidad tiene tres modos de operación:

- Detección (-i): detecta y corrige los canales FXO existentes y guarda la configuración en

```
fxotune.conf
```

- Modo de volcado (-d): genera los archivos de forma de onda en fxotune_dump.vals
- Modo de inicio (-s): lee el archivo fxotune.conf y lo aplica a los módulos FXO

Es importante entender que tendrá que insertar la instrucción fxotune –s en la carga del sistema antes de iniciar Asterisk:

```
#modprobe dahdi
#modprobe wctdm
#fxotune -s
```

### Cancelación de eco

La mayoría de los algoritmos de cancelación de eco operan generando múltiples copias de la señal recibida, en las cuales cada una se retrasa por una cantidad específica de tiempo. El número de taps del filtro determina el tamaño del retardo de eco que necesita ser cancelado. Estas copias retrasadas se ajustan y se restan de la señal recibida. El truco es ajustar solo la señal retrasada para eliminar el eco sin utilizar demasiados ciclos de CPU. Desde la perspectiva de los usuarios, es importante elegir un algoritmo de cancelación de eco apropiado. El predeterminado es MG2; sin embargo, hay otras dos opciones disponibles: la High Performance Echo Cancellation (HPEC) de Sangoma (anteriormente Digium) y la cancelación de eco de código abierto (OSLEC) desarrollada por David Rowe.

OSLEC (https://www.rowetel.com/?page_id=454) se ha fusionado en el kernel de Linux — reside en el área `drivers/staging/echo` del kernel — y DAHDI se compila contra él en lugar de enviar una descarga por separado. Para cambiar el algoritmo de cancelación de eco, establezca el parámetro `echo_can` en `/etc/dahdi/system.conf`. Por ejemplo:

```
echo_can=oslec
```

La cancelación de eco en Asterisk está controlada por tres parámetros en el archivo /etc/asterisk/chan-

```
dahdi.conf.
```

- **echocancel**: Deshabilita o habilita la cancelación de eco. Debe mantener esta función habilitada. Acepta "yes" o el número de taps. (Explicación: ¿Cómo funciona la cancelación de eco? La mayoría de los algoritmos de cancelación de eco operan generando múltiples copias de una señal recibida, con cada una siendo retrasada por un pequeño intervalo. Este pequeño flujo se llama "tap". El número de taps determina el retardo de eco que puede ser cancelado. Estas copias se retrasan, ajustan y restan de la señal original. El truco es ajustar la señal retrasada exactamente a lo que es necesario para eliminar el eco.)
- **echocancelwhenbridged**: Habilita o deshabilita el cancelador de eco durante una llamada TDM pura. Esto generalmente no es necesario.
- **rxgain**: Ajusta la ganancia de recepción de audio para aumentar o disminuir el volumen de recepción (-100% a 100%).
- **txgain**: Ajusta la ganancia de transmisión de audio para aumentar o disminuir el volumen de transmisión (-100% a 100%).

Por ejemplo:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Opciones de facturación

Estas opciones cambian cómo se registra la información de la llamada en la base de datos de registros de detalles de llamadas (CDR). amaflags: Configura las banderas AMA que afectan la categorización de CDR. Acepta los siguientes valores:

- billing
- documentation
- omit
- default

accountcode: Configura un código de cuenta para un canal específico. Puede contener cualquier valor alfanumérico, generalmente el departamento o el nombre de usuario.

```
accountcode=finance
amaflags=billing
```

### Opciones de progreso de llamada

Estos elementos se utilizan para adquirir información sobre el progreso de la llamada. En interfaces públicas, puede ser útil detectar el progreso de la llamada y determinar si fue contestada o si estaba ocupada. La detección de ocupado es altamente experimental y está regulada por parámetros específicos.

```
busydetect=yes
busycount=4
busypattern=500,500
callprogress=yes
progzone=br
```

Estos parámetros (arriba) especifican si la interfaz intentará detectar el tono de ocupado, cuántos tonos se utilizarán para una detección exitosa y cuál es el patrón de ocupado. La detección de ocupado es en gran medida experimental, y algunos parámetros adicionales pueden cambiarse en el Makefile. Para detectar la respuesta de una llamada, lo cual es esencial para una facturación precisa, es posible utilizar la inversión de polaridad para señalar el tiempo exacto de respuesta. Esto es importante si planea cobrar por la llamada o simplemente desea tener una facturación precisa para comparación. Por lo general, tiene que contactar a la compañía telefónica para solicitar este servicio.

```
answeronpolarityswitch=yes
```

En algunos países, es posible detectar el colgado de la llamada utilizando también la inversión de polaridad.

```
hanguponpolarityswitch=yes
```

#### Opciones para teléfonos

Estas opciones se utilizan para teléfonos conectados a las interfaces FXS. Todas las funcionalidades entregadas a los teléfonos analógicos conectados directamente a las interfaces DAHDI son controladas por Asterisk.

- **adsi** (Analog Display Services Interface): Este es un conjunto de estándares de telecomunicaciones utilizados por algunas compañías telefónicas para ofrecer servicios como la compra de boletos.
- **cancallforward**: Habilita o deshabilita el desvío de llamadas (*72 para habilitar y *73 para deshabilitar).
- **calleridcallwaiting**: Habilita el callerid recibido durante una indicación de llamada en espera (Yes/No).
- **immediate**: En modo inmediato, en lugar de proporcionar un tono de marcado, el canal salta inmediatamente a la extensión "s" en el contexto definido. Esto se utiliza para crear líneas directas (hotlines).
- **threewaycalling**: Habilita o deshabilita la conferencia tripartita.
- **mailbox**: Advierte al usuario sobre mensajes de correo de voz disponibles. Puede ser una señal audible o un indicador visual (si el teléfono admite esta función). El argumento es el número de buzón.
- **callgroup**: Agrupa teléfonos para marcar o para contestar.
- **pickupgroup**: Grupo de teléfonos para la captura de llamadas.

### Comandos CLI de DAHDI útiles

Una vez que Asterisk está ejecutándose con los canales DAHDI cargados, puede inspeccionar el estado del canal desde la CLI de Asterisk. Estos comandos siguen siendo actuales en Asterisk 22:

```
*CLI> dahdi show channels
*CLI> dahdi show channel 1
*CLI> module reload chan_dahdi.so
```

### Formato de canal DAHDI

Los canales DAHDI utilizan el siguiente formato en el dialplan:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Por ejemplo:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## Canales digitales (E1/T1/PRI / TDM)

A partir de Asterisk 22, DAHDI y libpri siguen siendo totalmente compatibles, pero los troncales digitales TDM (E1/T1/ISDN PRI) son reemplazados cada vez más por troncales SIP en nuevas implementaciones. Esta sección sigue siendo totalmente aplicable donde se requiera conectividad TDM; en entornos nuevos, el troncal SIP (Capítulo 3) generalmente ofrece la misma densidad de canales sin necesidad de hardware de telefonía.

Los canales digitales son extremadamente comunes, por lo que necesitará aprender a implementar estos canales si desea enfocarse en clientes grandes. Cuando el número de canales es alto (generalmente más de 8), es bastante común utilizar interfaces digitales como T1/E1/J1. T1 es muy común en EE. UU., mientras que E1 es común en Europa y J1 en Japón. Estos tipos de canales permiten una buena densidad de circuitos: 24 por canal T1 y 30 para canales E1.

En América Latina, China y África, es común utilizar un tipo de señalización asociada al canal (CAS) conocida como MFC/R2. Este capítulo examinará cómo implementar MFC/R2 utilizando la biblioteca OpenR2. En EE. UU. y Europa, la Red Digital de Servicios Integrados (ISDN) PRI es la señalización más común. El capítulo también discutirá la Interfaz de Acceso Básico (BRI) de ISDN, que es muy común en Europa en aplicaciones de gama media.

Todos los ejemplos del libro se concentran en canales DAHDI. Algunas tarjetas se implementan utilizando canales propietarios, así que consulte con su fabricante para obtener más detalles sobre cómo configurar su tarjeta específica.

### Objetivos

Al final de este capítulo usted será capaz de:

- Reconocer los términos principales utilizados en telefonía digital
- Diferenciar la señalización CAS y CCS
- Diferenciar la señalización R2 e ISDN
- Configurar interfaces con señalización ISDN
- Configurar interfaces con señalización R2

### Líneas digitales E1/T1

Las líneas digitales E1/T1 son una opción siempre que necesite implementar un gran número de canales. Un solo circuito E1 es capaz de manejar 30 llamadas simultáneas, y usted puede tener características como marcación directa entrante (DID), Caller ID (identificación de llamadas) y señalización avanzada. La línea E1/T1 puede llegar a su empresa de varias maneras utilizando par trenzado, fibra y microondas, dependiendo de su país. Las líneas digitales se entregan a su empresa utilizando UTP, fibra o microondas. Se utilizan módems y multiplexores (MUX) para entregar la línea física. La conexión a una línea T1 siempre se basa en un conector RJ45. Sin embargo, las líneas E1 también pueden ser aprovisionadas utilizando BNC. Es muy importante conocer de antemano el tipo de conector que va a recibir, principalmente en líneas E1. Por lo general, todo el equipo hasta el RJ45 es proporcionado por la TELCO.

![Cómo se aprovisionan los circuitos E1/T1: la compañía telefónica puede entregar el troncal sobre cobre UTP (módem HDSL para E1, o una conexión directa a la tarjeta para T1), sobre fibra óptica a través de un multiplexor óptico, o sobre un enlace de radio por microondas.](../images/10-legacy-fig05.png)

![¿UTP o BNC? La mayoría de las tarjetas digitales utilizan conectores RJ45 (UTP), pero algunas líneas E1 se entregan en coaxiales BNC duales, en cuyo caso se necesita un balun para adaptar el par coaxial al jack RJ45 de la tarjeta.](../images/10-legacy-fig06.png)

#### ¿Cómo se convierte la voz a bits?

La señal analógica se muestrea 8,000 veces por segundo para crear una versión digital de la voz analógica. Esta codificación se conoce como modulación por impulsos codificados (PCM). En EE. UU. y Japón, la señal se codifica utilizando ley (en Asterisk, referida como ulaw). En el resto del mundo, la codificación es alaw.

![Modulación por impulsos codificados (PCM): la señal de voz analógica de 4 kHz se muestrea 8,000 veces por segundo (Nyquist) y se codifica en un flujo digital de bits de 64 Kbps.](../images/10-legacy-fig07.png)

#### Multiplexación por división de tiempo

Las líneas analógicas tienen sentido cuando solo necesita unos pocos canales. Al utilizar la multiplexación por división de tiempo (TDM), es posible agrupar múltiples canales en una sola conexión de datos. Cuando desea un gran número de circuitos, la compañía telefónica generalmente le proporcionará un troncal digital, que es un circuito de datos en el cual la voz se transporta en formato digital utilizando PCM. Cada intervalo de tiempo (timeslot) utiliza 64 Kbps de ancho de banda para transportar un solo canal de voz.

![Multiplexación por división de tiempo en E1 y T1: una trama E1 transporta 32 intervalos de tiempo a 2048 Kbps (DS0 #0 para sincronización de trama, DS0 #16 para señalización), mientras que una trama T1 transporta 24 intervalos de tiempo a 1544 Kbps utilizando un bit para sincronización y un esquema de bits robados para señalización.](../images/10-legacy-fig08.png)

En EE. UU., el troncal digital más común es T1, que tiene 24 líneas disponibles; en Europa y América Latina, los troncales E1 tienen 30 líneas. Algunas empresas proporcionan un T1/E1 fraccional con menos canales. Señalización de bit robado: A veces, un troncal T1 utiliza un esquema de bit robado donde se toma prestado un bit para la señalización. En los troncales T1, el canal de datos/voz se transmite con 56 Kbps en cada intervalo de tiempo. Como puede observar, cuando utiliza el bit robado, el circuito T1 no pierde dos intervalos para sincronización y señalización.

#### Código de línea T1/E1

Los T1 y E1 son en realidad circuitos de datos y tienen una codificación de datos que determina la forma en que se interpretan los bits. Para los E1, el código de línea más común es HDB3 para la capa 1 y CCS para la capa 2. La forma más fácil de saber cómo está configurado su troncal digital es preguntar a la TELCO sobre esta información. Necesitará esta información para configurar el archivo /etc/dahdi/system.conf.

#### Señalización T1/E1

Es importante entender que las líneas T1/E1 pueden entregarse utilizando diferentes tipos de señalización, tales como:

- T1 con señalización de bit robado
- T1 con señalización ISDN
- E1 con MFC/R2 (CAS - Señalización Asociada al Canal)
- E1 con señalización ISDN

ISDN se utiliza a menudo en Europa y EE. UU. Es una red de voz digital, estandarizada por la Unión Internacional de Telecomunicaciones (ITU) en 1984. ISDN proporciona dos tipos de canales:

- Canales portadores (Bearer channels)
  - Voz
  - Datos
- Canales de datos
  - Señalización fuera de banda
  - Señalización LAPD
  - Q.931

Por lo general, una línea ISDN se proporciona utilizando dos medios físicos:

- Interfaz de acceso básico (BRI)
  - Conocida como 2B+D
  - Dos canales portadores (64K) y un canal de datos (16K)
  - Utiliza un par de cables de cobre con 148Kbps.
- Interfaz de acceso primario (PRI)
  - Entregada utilizando un troncal T1/E1
  - 23B+D para T1s
  - 30B+D para E1s

A veces, los circuitos E1 utilizan un esquema de señalización CAS llamado MFC/R2, que fue definido por la ITU como un estándar conocido como Q.421/Q441. Esto se encuentra frecuentemente en América Latina y Asia. Varias compañías de telefonía en estos países utilizan variantes personalizadas de MFC/R2. Por lo tanto, necesitará conocer la variación correcta del país para que funcione.

### ISDN BRI

Los canales que utilizan señalización ISDN BRI son muy populares en Europa. La mayoría de las tarjetas ISDN BRI para Asterisk soportan una interfaz S/T con capacidades NT y TE. La conexión TE (terminal) es la que se utiliza para conectarse a la TELCO o a otras PBX configuradas como terminación de red (NT). La NT se utiliza para conectar teléfonos y PBX configuradas como TE. ISDN BRI proporciona dos canales de datos/voz y un canal de señalización. Las tarjetas ISDN BRI están disponibles a través de varios proveedores de tarjetas de interfaz para Asterisk.

### Elección de una tarjeta de telefonía para su servidor Asterisk

Existen varios fabricantes de tarjetas digitales compatibles con Asterisk. La elección de una tarjeta depende de algunos de los siguientes factores:

#### Bus de datos

Existen varios tipos de bus en su PC. Es muy importante que tenga la tarjeta correcta para su servidor. La siguiente descripción general resume las tarjetas utilizadas con más frecuencia:

- PCI 5V de 32 bits que se encuentra en la mayoría de las computadoras, incluyendo computadoras de escritorio
  - Sangoma (anteriormente Digium) TE405, TE407, TE205, TE207, TE120, TE122, B410, TDM2400, TDM800, TDM410 y TC400
  - Sangoma A101, A102 y A104
- PCI 3.3V de 32/64 bits, básicamente encontrada en servidores
  - Sangoma (anteriormente Digium) TE410, TE412, TE210, TE212, TE120, TE122, B410, TDM2400, TDM800, TDM410 y TC400
- PCI Express encontrada en computadoras de escritorio y servidores
  - Sangoma (anteriormente Digium) TE420, TE220, TE121, AEX2400 y AEX800
  - Sangoma A101, A102 y A104

Estas familias de tarjetas se originaron en Digium, que Sangoma adquirió en 2018; ahora se venden y reciben soporte bajo la marca Sangoma. Muchos de los SKU más antiguos enumerados aquí han sido descontinuados, así que confirme la disponibilidad del modelo actual en www.sangoma.com antes de comprar.

- MiniPCI encontrada en sistemas embebidos
  - OpenVOX A100M(FXO), B100M(ISDN BRI), B200M(ISDN BRI) y B400M(ISDN BRI)
- USB 2.0 encontrada en la mayoría de las PCs modernas. Las soluciones basadas en USB permiten una gran densidad de canales analógicos y digitales. Este bus soporta 480 Mbps, y cada canal de voz ocupa 64 Kbps. Al utilizar hubs USB, es posible obtener densidades de hasta mil puertos analógicos en un solo puerto.
  - Xorcom Astribank (FXS, FXO, E1-ISDN, E1-R2)
- Ethernet. La mayor ventaja de Ethernet es permitir que la tarjeta sea conectada por más de un servidor. Las soluciones de alta disponibilidad son generalmente la aplicación principal para estos dispositivos. La fortaleza de esta solución es el uso de servidores sin ranuras PCI libres o servidores blade.
  - Redfone FoneBridge (hasta cuatro circuitos E1)

### Uso de cancelación de eco por hardware

La cancelación de eco por hardware reduce la carga en la CPU del host. Para tarjetas con más de una interfaz E1, la cancelación de eco por hardware puede ayudar a aliviar su procesador. Los nuevos canceladores de eco por software mejorados, como el OSLEC, están reduciendo la necesidad de un cancelador de eco por hardware. Para elegir entre canceladores de eco por hardware y software, debe considerar la cantidad de potencia de procesamiento disponible en su servidor y el número de circuitos E1. Un proceso de cancelación de eco puede utilizar hasta nueve MIPS (millones de instrucciones por segundo) por canal de voz con 128 taps de amplitud utilizando OSLEC (Referencia: Xorcom Ltd.). Si considera 1 ciclo de CPU por cada instrucción (lo cual no siempre es correcto según el procesador y la implementación del software en sí), estamos hablando de 1.080 Ghz para cuatro E1s.

#### Tipo de señalización

Seleccionar el tipo de señalización (por ejemplo, T1 CAS, T1 PRI, E1 CAS R2 o E1 CAS ISDN) no es una tarea fácil. Realmente depende de lo que tenga disponible en su área y a qué precio. La Señalización de Canal Común (CCS) es a menudo mejor que la señalización asociada al canal (CAS). Sin embargo, a menudo no está disponible. En EE. UU., generalmente puede elegir, ya que la mayoría de las TELCOS ofrecen T1 CAS para usuarios regulares y T1 PRI para usuarios avanzados (por ejemplo, centros de llamadas). En América Latina, E1 CAS R2 es predominante, pero ISDN PRI está disponible en algunas ciudades.

![La arquitectura de software DAHDI: Asterisk se comunica con el controlador de canal `chan_dahdi`, que a su vez carga las bibliotecas de protocolo libpri (ISDN), libopenr2 (MFC/R2) y libss7 (SS7); estas se asientan sobre la interfaz `/dev/dahdi`, el controlador del kernel DAHDI y el controlador del kernel de la interfaz específica de la tarjeta.](../images/10-legacy-fig09.png)

Implementar R2 es necesario para instalar una biblioteca conocida como OpenR2 (www.libopenr2.org), desarrollada por Moises Silva, y para parchear Asterisk antes de la instalación—un procedimiento simple que se muestra más adelante en este capítulo. La biblioteca ha pasado varias pruebas y está en producción en varios de nuestros clientes. ISDN es, en mi opinión, siempre la mejor opción, si está disponible. Algunos proveedores pueden tener acceso al sistema de señalización 7 (SS7), que es una señalización CCS disponible entre compañías telefónicas. Existen soluciones propietarias y de código abierto disponibles para SS7. La biblioteca libss7 se utiliza para soportar SS7 en Asterisk.

### Configuración de canales de telefonía en Asterisk

Configurar una tarjeta de interfaz de telefonía implica varios pasos necesarios. En este capítulo, mostraremos tres de los escenarios más comunes:

- Conexión digital utilizando ISDN PRI
- Conexión digital utilizando ISDN BRI
- Conexión digital utilizando MFC/R2

Hay dos formas de configurar los canales DAHDI. La primera es configurarlo manualmente con control total de todos los parámetros. La segunda forma es utilizar la utilidad dahdi_genconf para detectar y configurar las tarjetas.

#### Detección y configuración automática

Gracias al equipo de desarrollo de DAHDI, ahora tenemos detección y configuración automática de las tarjetas. Paso 1: Para generar la configuración automáticamente, utilice la utilidad dahdi_genconf, que detectará la tarjeta y generará los archivos /etc/dahdi/system.conf y dahdi-channels.conf.

```
dahdi_genconf
```

Paso 2: En la última línea del archivo chan_dahdi.conf, incluya el archivo dahdi-channels.conf

```
#include dahdi_channels.conf
```

Paso 3: Comente todos los módulos no utilizados en el archivo modules o simplemente utilice:

```
dahdi_genconf modules
```

#### Configuración manual

Otra opción es configurar las interfaces manualmente. A continuación se muestran algunos ejemplos de la configuración para canales DAHDI.

##### Ejemplo #1 – Dos canales T1/E1 utilizando ISDN

Pasos requeridos:

1. Instalación de TE205P o TE210P
2. Configuración del archivo `/etc/dahdi/system.conf`
3. Carga del controlador DAHDI
4. Utilidad `dahdi_test`
5. Utilidad `dahdi_cfg`
6. Configuración del archivo `chan_dahdi.conf`
7. Carga y prueba de Asterisk

Paso 1: Instalación de TE205P. Antes de instalar la TE205P, es importante entender las diferencias entre las tarjetas TE205P y TE210P. La tarjeta TE210P utiliza un bus de 64 bits alimentado por 3.3 voltios que se encuentra casi solo en las placas base de los servidores. Tenga cuidado si especifica esta tarjeta de interfaz; asegúrese de que su hardware soporte un bus de 64 bits y 3.3V. La tarjeta TE205P utiliza un PCI de 5V, que a menudo se encuentra en computadoras de escritorio. Hemos elegido la tarjeta de interfaz TE205P con dos spans para este ejemplo porque es más fácil reducirla a una tarjeta de un solo span o expandirla a una tarjeta de cuatro spans. Estas tarjetas ahora se venden bajo la marca Sangoma (anteriormente Digium).

![Una tarjeta E1/T1 de doble span Sangoma/Digium TE205P: los dos puertos RJ45 aceptan los troncales digitales, y un puente en la placa (el selector E1/T1/J1) establece el estándar de línea.](../images/10-legacy-fig10.png)

```
Step 2: /etc/dahdi/system.conf configuration file
```

La configuración de las tarjetas digitales TDM es un poco diferente de la configuración de sus contrapartes analógicas. Primero, necesitaremos configurar los spans de la placa y luego los canales. Los spans se numeran secuencialmente dependiendo del orden de reconocimiento de las tarjetas. En otras palabras, si tiene más de una tarjeta de interfaz, es difícil saber qué span pertenece a cada una. Utilice dahdi_hardware para verificar qué hardware está instalado en cada span. Ejemplo #1 (2xT1 PRI)

```
span=1,1,0,esf,b8zs
span=2,0,0,esf,b8zs
bchan=1-23
dchan=24
bchan=25-47
dchan=48
defaultzone=us
loadzone=us
```

Ejemplo #2 (2xE1 PRI)

```
span=1,1,0,ccs,hdb3,crc4 # not always necessary, consult Telco.
span=2,0,0,ccs,hdb3,crc4
bchan=1-15, 17-31
dchan=16
bchan=33-47, 49-63
dchan=48
defaultzone=br
loadzone=br
```

Ejemplo #3 (4xBRI)

```
loadzone=de
defaultzone=de
span=1,1,0,ccs,ami
bchan=1,2
hardhdlc=3
span=2,0,0,ccs,ami
bchan=4,5
hardhdlc=6
span=3,0,0.ccs.ami
bchan=7,8
hardhdlc=9
span=4,0,0,ccs,ami
bchan=10,11
hardhdlc=12
```

Paso 3: Carga de los controladores del kernel. Verifique qué controlador necesita instalar utilizando dahdi_hardware.

```
dahdi_hardware
pci:0000:04:02.0     wcte2xxp    e159:0001 Sangoma Wildcard TE205P T1/E1 Board
```

Para cargar, utilice:

```
modprobe dahdi
modprobe wct2xxp
```

Paso 4: Utilizando dahdi_test, verifique las interrupciones perdidas. Puede verificar el número de interrupciones perdidas utilizando la utilidad dahdi_test compilada con las tarjetas DAHDI. Un número por debajo del 99.987% indica posibles problemas. Encontrará dahdi_test en

```
/usr/sbin.
#./dahdi_test
Opened pseudo zap interface, measuring accuracy...
99.987793% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 100.000000% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000% 100.000000% 99.987793% 100.000000%
100.000000% 100.000000%
100.000000% 100.000000% 100.000000%
--- Results after 26 passes ---
Best: 100.000000 -- Worst: 99.987793 -- Average: 99.999061
```

Paso 5: Utilizando la utilidad dahdi_cfg. Esta es la salida correcta de dahdi_cfg para un span E1 fraccional (15 puertos) y dos puertos FXO.

```
#./dahdi_cfg -vvvv
Dahdi configuration
======================
SPAN 1: CCS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: Clear channel (Default) (Slaves: 01)
Channel 02: Clear channel (Default) (Slaves: 02)
Channel 03: Clear channel (Default) (Slaves: 03)
Channel 04: Clear channel (Default) (Slaves: 04)
Channel 05: Clear channel (Default) (Slaves: 05)
Channel 06: Clear channel (Default) (Slaves: 06)
Channel 07: Clear channel (Default) (Slaves: 07)
Channel 08: Clear channel (Default) (Slaves: 08)
Channel 09: Clear channel (Default) (Slaves: 09)
Channel 10: Clear channel (Default) (Slaves: 10)
Channel 11: Clear channel (Default) (Slaves: 11)
Channel 12: Clear channel (Default) (Slaves: 12)
Channel 13: Clear channel (Default) (Slaves: 13)
Channel 14: Clear channel (Default) (Slaves: 14)
Channel 15: Clear channel (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
16 channels configured.
```

Paso 6: Configuración de DAHDI en el archivo /etc/asterisk/chan_dahdi.conf. Ejemplo #1 (2xT1)

```
callerid="John Doe"<(555)555-1111>
switchtype=national
signalling =pri_cpe
context=from-pstn
group = 1
channel => 1-23
group =2
channel => 25-47
```

Ejemplo #2 (2xE1)

```
callerid="Flavio Eduardo" <4830258580>
switchtype=euroisdn
signalling = pri_cpe
group = 1
channel => 1-15;17-31
group =2
channel => 32-46;48-62
```

Ejemplo #3 (4xBRI)

```
signaling=bri_cpe
switchtype=euroisdn
group=1
context=from-pstn
channel=>1,2,4,5,7,8,10,11
```

Utilice signaling=bri_cpe_ptmp para BRI punto a multipunto. Actualmente, BRI punto a multipunto no es soportado en modo NT.

#### Carga de los controladores del kernel

Después de configurar los controladores, simplemente puede reiniciar el servidor. Si ha instalado DAHDI con make config, no necesitará hacer nada extra. El controlador del kernel se cargará y configurará automáticamente. Sin embargo, a veces es útil cargar y descargar los controladores manualmente. Ejemplo:

```
modprobe wct11xp
dahdi_cfg -vvvvv
```

El primer comando carga el controlador y el segundo, dahdi_cfg, aplica la configuración al controlador del kernel.

### Solución de problemas

A veces las cosas no funcionan a la primera. Revisemos algunos recursos para la solución de problemas de DAHDI. Paso 1: Verifique si la tarjeta está siendo reconocida por el sistema operativo. Las tarjetas Sangoma/Digium generalmente se reconocen como el módem ISDN.

```
lspci -v
00:00.0 Host bridge: Intel Corporation E7230/3000/3010 Memory Controller Hub
00:01.0 PCI bridge: Intel Corporation E7230/3000/3010 PCI Express Root Port
00:1c.0 PCI bridge: Intel Corporation 82801G (ICH7 Family) PCI Express Port 1 (rev 01)
00:1c.4 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 5 (rev
01)
00:1c.5 PCI bridge: Intel Corporation 82801GR/GH/GHM (ICH7 Family) PCI Express Port 6 (rev
01)
00:1d.0 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #1 (rev
01)
00:1d.1 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #2 (rev
01)
00:1d.2 USB Controller: Intel Corporation 82801G (ICH7 Family) USB UHCI Controller #3 (rev
01)
00:1d.7 USB Controller: Intel Corporation 82801G (ICH7 Family) USB2 EHCI Controller (rev 01)
00:1e.0 PCI bridge: Intel Corporation 82801 PCI Bridge (rev e1)
00:1f.0 ISA bridge: Intel Corporation 82801GB/GR (ICH7 Family) LPC Interface Bridge (rev 01)
00:1f.1 IDE interface: Intel Corporation 82801G (ICH7 Family) IDE Controller (rev 01)
00:1f.2 IDE interface: Intel Corporation 82801GB/GR/GH (ICH7 Family) SATA IDE Controller (rev
01)
00:1f.3 SMBus: Intel Corporation 82801G (ICH7 Family) SMBus Controller (rev 01)
01:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
01:00.1 PIC: Intel Corporation 6700/6702PXH I/OxAPIC Interrupt Controller A (rev 09)
02:08.0 SCSI storage controller: LSI Logic / Symbios Logic SAS1068 PCI-X Fusion-MPT SAS (rev
01)
03:00.0 PCI bridge: Intel Corporation 6702PXH PCI Express-to-PCI Bridge A (rev 09)
04:02.0 Network controller: Tiger Jet Network Inc. Tiger3XX Modem/ISDN interface
05:00.0 Ethernet controller: Broadcom Corporation NetXtreme BCM5721 Gig. Eth.PCI Express (rev
11)
07:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL-8139/8139C/8139C+ (rev 10)
07:05.0 VGA compatible controller: ATI Technologies Inc ES1000 (rev 02)
```

Paso 2: Verifique si el controlador del kernel se está cargando correctamente utilizando:

```
modprobe wct11xp
dmesg
TE110P: Setting up global serial parameters for E1 FALC V1.2
TE110P: Successfully initialized serial bus for card
TE110P: Span configured for CAS/HDB3
Calling startup (flags is 4099)
Found a Wildcard: Sangoma Wildcard TE110P T1/E1
TE110P: Span configured for CCS/HDB3/CRC4
Calling startup (flags is 4099)
dahdi: Registered tone zone 0 (United States / North America)
wcte1xxp: Setting yellow alarm
```

Paso 3: Verifique el estado de las alarmas relacionadas con la capa física de la conexión. Para verificar la capa física de la conexión E1, puede utilizar el siguiente comando de la CLI de Asterisk.

```
dahdi show status
```

Las alarmas indican problemas con el puerto: Alarma roja: No se puede mantener la sincronización con el switch remoto. Esto suele ser un problema físico, como un código de línea o un desajuste de trama. Alarma amarilla: Señala que el switch remoto está en alarma roja. Esto indica que el switch remoto no está recibiendo sus transmisiones. Alarma azul: Recibe todos los 1s sin trama en todos los intervalos de tiempo; dahdi_tool actualmente no detecta una alarma azul. Loopback: El puerto está en loopback local o remoto.

```
vtsvoffice*CLI> dahdi show status
Description                              Alarms     IRQ        bpviol     CRC4
Sangoma Wildcard E100P E1/PRA Card 0      OK         0          0          0
Wildcard X100P Board 1                   OK         0          0          0
Wildcard X100P Board 2                   RED        0          0          0
```

Paso 4: Para detectar problemas con DAHDI en el servidor Asterisk, primero verifique si los canales están siendo reconocidos utilizando:

```
dahdi show channels
pabxip01*CLI> dahdi show channels
   Chan Extension  Context         Language   MOH Interpret
 pseudo            default                    default
      1            from-pstn                  default
      2            from-pstn                  default
      3            from-pstn                  default
      4            from-pstn                  default
      5            from-pstn                  default
      6            from-pstn                  default
      7            from-pstn                  default
      8            from-pstn                  default
      9            from-pstn                  default
     10            from-pstn                  default
     11            from-pstn                  default
     12            from-pstn                  default
     13            from-pstn                  default
     14            from-pstn                  default
     15            from-pstn                  default
     17            from-pstn                  default
     18            from-pstn                  default
     19            from-pstn                  default
     20            from-pstn                  default
     21            from-pstn                  default
     22            from-pstn                  default
     23            from-pstn                  default
     24            from-pstn                  default
     25            from-pstn                  default
     26            from-pstn                  default
     27            from-pstn                  default
     28            from-pstn                  default
     29            from-pstn                  default
     30 2171       from-pstn                  default
     31 2171       from-pstn                  default
```

Paso 5: Verifique el estado de la capa 3 de ISDN, también conocida como q.931. Puede verificar si la capa 3 de ISDN está activa utilizando: `pri show spans` (para listar todos los spans) o `pri show span <n>` para un span específico:

```
vtsvoffice*CLI> pri show span 1
Primary D-channel: 16
Status: Provisioned, Up, Active
Switchtype: EuroISDN
Type: CPE
Window Length: 0/7
Sentrej: 0
SolicitFbit: 0
Retrans: 0
Busy: 0
Overlap Dial: 0
T200 Timer: 1000
T203 Timer: 10000
T305 Timer: 30000
T308 Timer: 4000
T313 Timer: 4000
N200 Counter: 3
```

Utilice `pri show spans` (plural) para listar el estado de todos los spans PRI configurados a la vez.

Verifique un canal específico. dahdi show channel x:

```
vtsvoffice*CLI> dahdi show channel 1
Channel: 1
File Descriptor: 21
Span: 1
Extension:
Dialing: no
Context: entrada
Caller ID: 4832341689
Calling TON: 33
Caller ID name:
Destroy: 0
InAlarm: 0
Signalling Type: PRI Signalling
Radio: 0
Owner: <None>
Real: <None>
Callwait: <None>
Threeway: <None>
Confno: -1
Propagated Conference: -1
Real in conference: 0
DSP: no
Relax DTMF: no
Dialing/CallwaitCAS: 0/0
Default law: alaw
```

debug pri span x: Si después de todo todavía tiene problemas, comience a depurar el span pri. Este comando habilita una depuración detallada de las llamadas ISDN. Es un comando importante cuando piensa que algo no es correcto. Puede detectar dígitos mal marcados y otros problemas. A continuación presentamos el ejemplo de una salida de depuración para una llamada exitosa. Consulte este ejemplo si necesita comparar una llamada fallida con una sin problemas. Un consejo es utilizar core set verbose=0 para recibir solo los mensajes q.931 de ISDN.

```
-- Making new call for cr 32833
> Protocol Discriminator: Q.931 (8)  len=57
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: SETUP (5)
> [04 03 80 90 a3]
> Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
>                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
>                              Ext: 1  User information layer 1: A-Law (35)
> [18 03 a9 83 81]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 1 ]
> [28 0e 46 6c 61 76 69 6f 20 45 64 75 61 72 64 6f]
> Display (len=14) @h@>[ Flavio Eduardo ]
> [6c 0c 21 80 34 38 33 30 32 35 38 35 39 30]
> Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
>                           Presentation: Presentation permitted, user number not screened
(0) '4830258590' ]
> [70 09 a1 33 32 32 34 38 35 38 30]
> Called Number (len=11) [ Ext: 1  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '32248580' ]
> [a1]
> Sending Complete (len= 1)
< Protocol Discriminator: Q.931 (8)  len=10
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CALL PROCEEDING (2)
< [18 03 a9 83 81]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 1 ]
-- Processing IE 24 (cs0, Channel Identification)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: ALERTING (1)
< [1e 02 84 88]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Inband information or
appropriate pattern now available. (8) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=64
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: SETUP (5)
< [04 03 80 90 a3]
< Bearer Capability (len= 5) [ Ext: 1  Q.931 Std: 0  Info transfer capability: Speech (0)
<                              Ext: 1  Trans mode/rate: 64kbps, circuit-mode (16)
<                              Ext: 1  User information layer 1: A-Law (35)
< [18 03 a1 83 82]
< Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Preferred Dchan: 0
<                        ChanSel: Reserved
<                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
<                       Ext: 1  Channel: 2 ]
< [1c 15 91 a1 12 02 01 bc 02 01 0f 30 0a 02 01 01 0a 01 00 a1 02 82 00]
< Facility (len=23, codeset=0) [ 0x91, 0xa1, 0x12, 0x02, 0x01, 0xbc, 0x02, 0x01, 0x0f, '0',
0x0a, 0x02, 0x01, 0x01, 0x0a, 0x01, 0x00, 0xa1, 0x02, 0x82, 0x00 ]
< [1e 02 82 83]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the local user (2)
<                               Ext: 1  Progress Description: Calling equipment is non-ISDN.
(3) ]
< [6c 0c 21 83 34 38 33 32 32 34 38 35 38 30]
< Calling Number (len=14) [ Ext: 0  TON: National Number (2)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1)
<                           Presentation: Presentation allowed of network provided number (3)
'4832248580' ]
< [70 05 c1 38 35 38 30]
< Called Number (len= 7) [ Ext: 1  TON: Subscriber Number (4)  NPI: ISDN/Telephony Numbering
Plan (E.164/E.163) (1) '8580' ]
< [a1]
< Sending Complete (len= 1)
-- Making new call for cr 5720
-- Processing Q.931 Call Setup
-- Processing IE 4 (cs0, Bearer Capability)
-- Processing IE 24 (cs0, Channel Identification)
-- Processing IE 28 (cs0, Facility)
Handle Q.932 ROSE Invoke component
-- Processing IE 30 (cs0, Progress Indicator)
-- Processing IE 108 (cs0, Calling Party Number)
-- Processing IE 112 (cs0, Called Party Number)
-- Processing IE 161 (cs0, Sending Complete)
> Protocol Discriminator: Q.931 (8)  len=10
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CALL PROCEEDING (2)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> Protocol Discriminator: Q.931 (8)  len=14
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: CONNECT (7)
> [18 03 a9 83 82]
> Channel ID (len= 5) [ Ext: 1  IntID: Implicit, PRI Spare: 0, Exclusive Dchan: 0
>                        ChanSel: Reserved
>                       Ext: 1  Coding: 0   Number Specified   Channel Type: 3
>                       Ext: 1  Channel: 2 ]
> [1e 02 81 82]
> Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Private network serving the local user (1)
>                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: CONNECT ACKNOWLEDGE (15)
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: PROGRESS (3)
< [1e 02 84 82]
< Progress Indicator (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location:
Public network serving the remote user (4)
<                               Ext: 1  Progress Description: Called equipment is non-ISDN.
(2) ]
-- Processing IE 30 (cs0, Progress Indicator)
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: CONNECT (7)
> Protocol Discriminator: Q.931 (8)  len=5
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: CONNECT ACKNOWLEDGE (15)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Active, peerstate Connect Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: DISCONNECT (69)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 65/0x41) (Terminator)
< Message type: RELEASE (77)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Release Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 65/0x41) (Originator)
> Message type: RELEASE COMPLETE (90)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
< Protocol Discriminator: Q.931 (8)  len=9
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: DISCONNECT (69)
< [08 02 82 90]
< Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Public network
serving the local user (2)
<                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
-- Processing IE 8 (cs0, Cause)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Disconnect Indication, peerstate Disconnect
Request
> Protocol Discriminator: Q.931 (8)  len=9
> Call Ref: len= 2 (reference 5720/0x1658) (Terminator)
> Message type: RELEASE (77)
> [08 02 81 90]
> Cause (len= 4) [ Ext: 1  Coding: CCITT (ITU) standard (0) 0: 0   Location: Private network
serving the local user (1)
>                  Ext: 1  Cause: Unknown (16), class = Normal Event (1) ]
< Protocol Discriminator: Q.931 (8)  len=5
< Call Ref: len= 2 (reference 5720/0x1658) (Originator)
< Message type: RELEASE COMPLETE (90)
NEW_HANGUP DEBUG: Calling q931_hangup, ourstate Null, peerstate Null
NEW_HANGUP DEBUG: Destroying the call, ourstate Null, peerstate Null
```

### Opciones de configuración en chan_dahdi.conf

Existen varias opciones disponibles en el archivo chan_dahdi.conf. Una descripción de todas las opciones sería aburrida y contraproducente. Aquí, detallaremos los principales grupos de opciones disponibles para proporcionar una mejor comprensión.

#### Opciones generales (independientes del canal)

context: Define el contexto entrante.

```
context=default
```

channel: Define el canal o rango de canales. Cada definición de canal heredará las opciones definidas antes de la declaración. Los canales pueden identificarse individualmente o en la misma línea con separación por comas. Los rangos pueden definirse utilizando “-”.

```
Channel=>1-15
Channel=>16
Channel=>17,18
```

group: Permite que los canales sean tratados como un grupo. Si marca un número de grupo en lugar de un número de canal, se utiliza el primer canal disponible. Si los canales son teléfonos, cuando llama a un grupo, todos los teléfonos sonarán simultáneamente. Utilizando comas, puede especificar más de un grupo para el mismo canal.

```
group=1
group=3,5
```

language: Activa la internacionalización y configura un idioma. Esta característica configurará los mensajes del sistema para un idioma específico. Inglés es el único idioma con avisos completos disponibles desde la instalación estándar. musiconhold: Selecciona la clase de música en espera.

#### Opciones ISDN

switchtype: Depende de la PBX o switch utilizado. En Europa y América Latina, EuroISDN es común.

- 5ess: Lucent 5ESS
- euroisdn: EuroISDN
- national: National ISDN
- dms100: Nortel DMS100
- 4ess: AT&T 4ESS
- Qsig: Q.SIG

```
switchtype = EuroISDN
```

pridialplan: Requerido para algunos switches que necesitan una especificación de plan de marcación. Esta opción es ignorada por muchos switches. Las opciones válidas son private, national, international y unknown.

```
pridialplan = unknown
```

prilocaldialplan: Necesario para algunos switches, generalmente unknown.

```
prilocaldialplan = unknown
```

overlapdial: La marcación superpuesta (overlap dialing) se utiliza cuando pasa dígitos después de que se establece la conexión. Puede utilizar numeración en modo bloque (overlapdial=no) o modo dígito (overlapdial=yes). El modo bloque es utilizado a menudo por los operadores. signaling: Configura el tipo de señalización para los canales subsiguientes. Estos parámetros deben corresponder a los del archivo chan_dahdi.conf. Las elecciones correctas se basan en el canal disponible. Para ISDN puede elegir cinco opciones:

- pri_cpe: Utilizado cuando el dispositivo es un CPE, a veces referido como cliente, usuario o esclavo. Esta es la forma de señalización más simple y utilizada. A veces, cuando intenta conectarse a una PBX privada, la PBX ha sido configurada comúnmente como CPE también. En este caso, utilice la señalización pri_net en Asterisk.
- pri_net: Utilizado cuando Asterisk está conectado a una PBX privada configurada como CPE. La señalización a menudo se refiere como host, maestro o red.
- bri_cpe: Utilizado cuando Asterisk está conectado como CPE a un troncal ISDN BRI.
- bri_net: Utilizado cuando Asterisk está conectado a un teléfono ISDN o PBX configurada como terminal (TE).
- bri_cpe_ptmp: Igual que bri_cpe, pero en una arquitectura punto a multipunto.

#### Opciones de CallerID

Hay muchas opciones de Caller ID disponibles. Algunas pueden desactivarse, aunque la mayoría están habilitadas por defecto. usecallerid: Habilita o deshabilita la transmisión de Caller ID para los canales subsiguientes (Yes/No). Nota: Si su sistema requiere dos timbres antes de contestar, intente desactivar esta característica para que conteste inmediatamente. hidecallerid: Oculta el Caller ID (Yes/No). calleridcallwaiting: Habilita la recepción de Caller ID durante una indicación de llamada en espera (Yes/No). callerid: Configura una cadena de Caller ID para un canal específico. El llamador puede configurarse con “asreceived” en interfaces de troncal para pasar el Caller ID hacia adelante.

```
callerid = "Flavio Eduardo Gonçalves" <48 30258500>
```

Nota: La mayoría de las TELCOS exigen que configure su Caller ID correcto. Si no pasa el Caller ID correcto, no debería poder marcar hacia afuera a través de la TELCO. Por otro lado, podrá recibir llamadas incluso sin configurar el Caller ID.

#### Opciones de calidad de audio

Estas opciones ajustan ciertos parámetros de Asterisk que afectan la calidad del audio en los canales DAHDI.

- **echocancel**: Deshabilita o habilita la cancelación de eco. Debe mantener esta característica habilitada. Acepta "yes" o el número de taps. (Explicación: ¿Cómo funciona la cancelación de eco? La mayoría de los algoritmos de cancelación de eco operan generando múltiples copias de una señal recibida, cada una retrasada por un pequeño intervalo. Este pequeño flujo se llama "tap". El número de taps determina el retraso de eco que puede ser cancelado. Estas copias se retrasan, ajustan y restan de la señal original. El truco es ajustar la señal retrasada exactamente a lo necesario para eliminar el eco.)
- **echocancelwhenbridged**: Habilita o deshabilita el cancelador de eco durante una llamada TDM pura. Esto generalmente no es necesario.
- **rxgain**: Ajusta la ganancia de recepción de audio para aumentar o disminuir el volumen de recepción (-100% a 100%).
- **txgain**: Ajusta la ganancia de transmisión de audio para aumentar o disminuir el volumen de transmisión (-100% a 100%).

Ejemplo:

```
echocancel=yes
echocancelwhenbridged=yes
txgain=-10%
rxgain=10%
```

#### Opciones de facturación

Estas opciones cambian la forma en que la información de la llamada se registra en la base de datos de registros detallados de llamadas (CDR). amaflags: Afecta la categorización del CDR. Acepta estos valores:

- billing
- documentation
- omit
- default

accountcode: Configura un código de cuenta para un canal específico. Puede contener cualquier valor alfanumérico, generalmente el departamento o nombre de usuario.

```
accountcode=finance
amaflags=billing
```

### Configuración de MFC/R2

MFC/R2 se utiliza en varios países de América Latina, China y África, así como en algunos países europeos. ISDN es superior y preferido si está disponible en su área.

#### Entendiendo el problema

La tarjeta utilizada para señalizar MFC/R2 es la misma utilizada para señalizar ISDN. Es posible utilizar MFC/R2 en canales DAHDI utilizando la biblioteca llamada libopenR2 (www.libopenr2.com). Esta biblioteca no formaba parte de las versiones de Asterisk anteriores a 1.6.2.

##### Entendiendo el protocolo MFC/R2

El protocolo MFC/R2 combina señalización en banda y fuera de banda. La señalización de dirección se reenvía en banda utilizando un conjunto de tonos, mientras que la información del canal se transmite sobre el intervalo de tiempo 16 como señalización fuera de banda.

**Señalización de línea (ITU-T Q.421).** En el intervalo de tiempo 16, cada canal de voz utiliza cuatro bits ABCD para señalar sus estados y control de llamada. Los bits C y D rara vez se utilizan. En algunos países, pueden utilizarse para medición (medición por pulsos para facturación). En una conversación normal, tenemos ambos lados trabajando: el lado llamante y el lado llamado. La señalización desde el lado llamante se refiere como señalización hacia adelante, mientras que el lado llamado utiliza señalización hacia atrás. Designaremos Af y Bf para la señalización hacia adelante y Ab y Bb para la señalización hacia atrás.

| Estado | ABCD adelante | ABCD atrás |
| --- | --- | --- |
| Inactivo/Liberado | 1001 | 1001 |
| Ocupado (Seized) | 0001 | 1001 |
| Acuse de ocupación | 0001 | 1101 |
| Contestado | 0001 | 0101 |
| ClearBack | 0001 | 1101 |
| ClearFwd (antes de clear-back) | 1001 | 0101 |
| ClearFwd (confirmación de desconexión) | 1001 | 1001 |
| Bloqueado | 1001 | 1101 |

MFC/R2 fue definido por la ITU. Desafortunadamente, varios países personalizaron el estándar para sus propias necesidades. Como resultado, surgieron variaciones en los estándares entre países.

**Señales inter-registro (ITU-T Q.441).** La señalización MFC/R2 utiliza una combinación de dos tonos. Las tablas a continuación muestran el estándar ITU.

Grupo de señales I (adelante):

| Descripción | Señal adelante |
| --- | --- |
| Dígito 1 | I-1 |
| Dígito 2 | I-2 |
| Dígito 3 | I-3 |
| Dígito 4 | I-4 |
| Dígito 5 | I-5 |
| Dígito 6 | I-6 |
| Dígito 7 | I-7 |
| Dígito 8 | I-8 |
| Dígito 9 | I-9 |
| Dígito 0 | I-10 |
| Indicador de código de país, se requiere supresor de eco de media vía saliente | I-11 |
| Indicador de código de país, no se requiere supresor de eco | I-12 |
| Indicador de llamada de prueba | I-13 |
| Indicador de código de país, supresor de eco de media vía saliente insertado | I-14 |
| No utilizado | I-15 |

Grupo de señales II (adelante):

| Descripción | Señal adelante |
| --- | --- |
| Suscriptor sin prioridad | II-1 |
| Suscriptor con prioridad | II-2 |
| Equipo de mantenimiento | II-3 |
| Reserva | II-4 |
| Operador | II-5 |
| Transmisión de datos | II-6 |
| Suscriptor u operador sin facilidad de transferencia hacia adelante | II-7 |
| Transmisión de datos | II-8 |
| Suscriptor con prioridad | II-9 |
| Operador con facilidad de transferencia hacia adelante | II-10 |
| Reserva | II-11 |
| Reserva | II-12 |
| Reserva | II-13 |
| Reserva | II-14 |
| Reserva | II-15 |

Grupo de señales A (atrás):

| Descripción | Señal atrás |
| --- | --- |
| Enviar siguiente dígito (n+1) | A-1 |
| Enviar penúltimo dígito (n-1) | A-2 |
| Dirección completa, cambio a recepción de señales Grupo B | A-3 |
| Congestión en la red nacional | A-4 |
| Enviar categoría de la parte llamante | A-5 |
| Dirección completa, cargo, establecer condiciones de voz | A-6 |
| Enviar antepenúltimo dígito (n-2) | A-7 |
| Enviar ante-antepenúltimo dígito (n-3) | A-8 |
| Reserva | A-9 |
| Reserva | A-10 |
| Enviar indicador de código de país | A-11 |
| Enviar dígito de idioma o discriminación | A-12 |
| Enviar naturaleza del circuito | A-13 |
| Solicitar información sobre el uso del supresor de eco | A-14 |
| Congestión en un intercambio internacional o en su salida | A-15 |

Grupo de señales B (atrás):

| Descripción | Señal atrás |
| --- | --- |
| Reserva | B-1 |
| Enviar tono de información especial | B-2 |
| Línea de suscriptor ocupada | B-3 |
| Congestión (después del cambio del grupo A al B) | B-4 |
| Número no asignado | B-5 |
| Línea de suscriptor libre, con cargo | B-6 |
| Línea de suscriptor libre, sin cargo | B-7 |
| Línea de suscriptor fuera de servicio | B-8 |
| Reserva | B-9 |
| Reserva | B-10 |
| Reserva | B-11 |
| Reserva | B-12 |
| Reserva | B-13 |
| Reserva | B-14 |
| Reserva | B-15 |

#### Secuencia MFC/R2

La siguiente secuencia ilustra una llamada que se origina desde una extensión de Asterisk a un terminal en la PSTN. La PSTN corta la llamada y finaliza la comunicación.

![Un flujo completo de llamada MFC/R2 entre Asterisk y la compañía telefónica: la señalización de línea (Inactivo, Ocupado, Acuse de ocupación, Contestado, Clearback, Clear Forward) se intercambia en el intervalo de tiempo 16, los dígitos marcados y las señales de "enviar siguiente dígito" hacia atrás (grupos I/A/B) viajan en banda, y los tonos audibles llegan al suscriptor.](../images/10-legacy-fig11.png)

### Cómo utilizar el controlador libopenr2

El proyecto iniciado por Moises Silva se inspiró en el controlador de canal Unicall escrito por Steve Underwood. La biblioteca OpenR2 es actualmente la solución de software más estable para Asterisk. Con esta solución, podemos utilizar cualquier tarjeta digital compatible con DAHDI. Anteriormente, solo estaban disponibles soluciones propietarias para MFC/R2; una de las mejores que he utilizado es la puesta a disposición por Khomp, www.khomp.com.br. En Asterisk 22, el soporte para MFC/R2 a través de libopenR2 está integrado cuando la biblioteca está presente en el momento de la compilación; no se requiere ningún parche externo. Los pasos a continuación muestran la instalación manual histórica como referencia; en sistemas modernos, instale `libopenr2-dev` desde el gestor de paquetes de su distribución antes de ejecutar `./configure`, luego habilite `chan_dahdi` en `make menuselect`.

Los pasos a continuación compilan openr2 y Asterisk desde sus repositorios Git actuales. Se mantienen como referencia para sitios que compilan desde el código fuente; en una distribución moderna, generalmente puede omitirlos por completo instalando el paquete `libopenr2-dev` y una compilación empaquetada de Asterisk 22, ya que `chan_dahdi` compila el soporte R2 directamente contra libopenr2 sin ningún parche externo.

Paso 1: Instale las herramientas de compilación que necesita.

```
apt-get install git
```

Paso 2: Clone la biblioteca openr2 y el código fuente de Asterisk. No se necesita ningún árbol parcheado especial en Asterisk 22; una descarga estándar compila el soporte R2 siempre que libopenr2 esté presente.

```
cd /usr/src
git clone https://github.com/moises-silva/openr2.git
git clone https://github.com/asterisk/asterisk.git
```

Paso 3: Compile e instale. Por favor, HAGA UNA COPIA DE SEGURIDAD de su servidor antes de continuar.

```
cd /usr/src/openr2
./configure && make && make install && ldconfig
cd /usr/src/asterisk
./configure && make menuselect && make && make install
```

Nota: No ejecute “make samples” para evitar sobrescribir sus archivos de configuración.

```
Step 4: Changing the file /etc/dahdi/system.conf:
vim /etc/dahdi/system.conf
```

Supongamos que tiene una tarjeta con una interfaz E1.

```
span=1,1,0,cas,hdb3
cas=1-15:1101
cas=17-31:1101
dchan=16
loadzone=br
defaultzone=br
```

Paso 5: Ejecute el comando dahdi_cfg para aplicar los cambios al controlador:

```
dahdi_cfg -vvvvvvvv
Dahdi Version:SVN-branch-1.4-r4348
Echo Canceller: MG2
Configuration
======================
SPAN 1: CAS/HDB3 Build-out: 0 db (CSU)/0-133 feet (DSX-1)
Channel map:
Channel 01: CAS / User (Default) (Slaves: 01)
Channel 02: CAS / User (Default) (Slaves: 02)
Channel 03: CAS / User (Default) (Slaves: 03)
Channel 04: CAS / User (Default) (Slaves: 04)
Channel 05: CAS / User (Default) (Slaves: 05)
Channel 06: CAS / User (Default) (Slaves: 06)
Channel 07: CAS / User (Default) (Slaves: 07)
Channel 08: CAS / User (Default) (Slaves: 08)
Channel 09: CAS / User (Default) (Slaves: 09)
Channel 10: CAS / User (Default) (Slaves: 10)
Channel 11: CAS / User (Default) (Slaves: 11)
Channel 12: CAS / User (Default) (Slaves: 12)
Channel 13: CAS / User (Default) (Slaves: 13)
Channel 14: CAS / User (Default) (Slaves: 14)
Channel 15: CAS / User (Default) (Slaves: 15)
Channel 16: D-channel (Default) (Slaves: 16)
Channel 17: CAS / User (Default) (Slaves: 17)
Channel 18: CAS / User (Default) (Slaves: 18)
Channel 19: CAS / User (Default) (Slaves: 19)
Channel 20: CAS / User (Default) (Slaves: 20)
Channel 21: CAS / User (Default) (Slaves: 21)
Channel 22: CAS / User (Default) (Slaves: 22)
Channel 23: CAS / User (Default) (Slaves: 23)
Channel 24: CAS / User (Default) (Slaves: 24)
Channel 25: CAS / User (Default) (Slaves: 25)
Channel 26: CAS / User (Default) (Slaves: 26)
Channel 27: CAS / User (Default) (Slaves: 27)
Channel 28: CAS / User (Default) (Slaves: 28)
Channel 29: CAS / User (Default) (Slaves: 29)
Channel 30: CAS / User (Default) (Slaves: 30)
Channel 31: CAS / User (Default) (Slaves: 31)
31 channels to configure.
-----------------------------------------------------------------------
```

Paso 5: Cambie el archivo chan_dahdi.conf

```
vim /etc/asterisk/chan_dahdi.conf
[channels]
usecallerid=yes
callwaiting=yes
usecallingpres=yes
callwaitingcallerid=yes
threewaycalling=yes
transfer=yes
canpark=yes
cancallforward=yes
callreturn=yes
echocancel=yes
echotrainning=yes
echocancelwhenbridged=yes
signalling=mfcr2
mfcr2_variant=br
mfcr2_get_ani_first=no
mfcr2_max_ani=20
mfcr2_max_dnis=4
mfcr2_category=national_subscriber
mfcr2_logdir=span1
mfcr2_logging=all
group=1
callgroup=1
pickupgroup=1
callerid=asreceived
context=from-mfcr2
channel => 1-15,17-31
```

Paso 6: Cambie el plan de marcación en el archivo extensions.conf

```
vim /etc/asterisk/extensions.conf
[default]
exten => _XXXXXXXX,1,Set(CALLERID(num)=1145678990)
exten => _XXXXXXXX,n,Dial(DAHDI/g1/${EXTEN},60,tT)
```

Nota: Algunas TELCOS no aceptan llamadas sin el Caller ID. Por favor, establezca el Caller ID a uno de los números DID asignados por el operador. En algunos países, este paso no es necesario. Paso 7: Pruebe la solución: Ahora, con una extensión en el contexto from-internal, llame a cualquier número y observe la consola. Verifique si está ocurriendo algún error. -- Executing Set("SIP/8564-081ca5d8", "CALLERID(num)=1145678990") in new stack -- Executing Dial("SIP/8564-081ca5d8", "DAHDI/g1/35678899|60|tT") in new stack

#### Depuración de OpenR2

Para detectar errores en las llamadas, puede activar la depuración. Para hacer esto, siga los pasos a continuación.

1. Edite el archivo `chan_dahdi.conf` y agregue las siguientes tres líneas a la configuración:

```
mfcr2_logdir=span1
mfcr2_logging=all
mfcr2_call_files=yes
```

2. Reinicie el servidor Asterisk
3. Pruebe la llamada y verifique los archivos de llamada en `/var/log/asterisk/mfcr2/span1`

A continuación se muestra un rastro para una llamada normal. Compárelo con lo que recibe en su llamada.

```
[15:05:47:710] [Thread: 3078019984] [Chan 1] - Call started at Mon Jul  6 15:05:47 2009 on
chan 1
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Tx >> [SEIZE] 0x00
[15:05:47:710] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x01
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Bits changed from 0x08 to 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - CAS Rx << [SEIZE ACK] 0x0C
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 2
[15:05:47:951] [Thread: 3078019984] [Chan 1] - timer id 2 found, cancelling it now
[15:05:47:951] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 3
[15:05:47:951] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:070] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 0
[15:05:48:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:48:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 2
[15:05:48:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:48:350] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:450] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:550] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:550] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:650] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:48:750] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:48:750] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:48:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 5
[15:05:48:950] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [ON]
[15:05:48:950] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:050] [Thread: 3078019984] [Chan 1] - MF Tx >> 5 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 8
[15:05:49:150] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:49:150] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:250] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Sending DNIS digit 4
[15:05:49:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:330] [Thread: 3078019984] [Chan 1] - Group A DNIS request handled
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:590] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:670] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:49:670] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:770] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:49:850] [Thread: 3078019984] [Chan 1] - Sending ANI digit 4
[15:05:49:850] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:49:930] [Thread: 3078019984] [Chan 1] - MF Tx >> 4 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:030] [Thread: 3078019984] [Chan 1] - Sending ANI digit 8
[15:05:50:030] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:130] [Thread: 3078019984] [Chan 1] - MF Tx >> 8 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:230] [Thread: 3078019984] [Chan 1] - Sending ANI digit 3
[15:05:50:230] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:330] [Thread: 3078019984] [Chan 1] - MF Tx >> 3 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:430] [Thread: 3078019984] [Chan 1] - Sending ANI digit 0
[15:05:50:430] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:530] [Thread: 3078019984] [Chan 1] - MF Tx >> 0 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:50:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:50:810] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:50:810] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:50:910] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:010] [Thread: 3078019984] [Chan 1] - Sending ANI digit 2
[15:05:51:010] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:110] [Thread: 3078019984] [Chan 1] - MF Tx >> 2 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:210] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:210] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:310] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:410] [Thread: 3078019984] [Chan 1] - Sending ANI digit 7
[15:05:51:410] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:510] [Thread: 3078019984] [Chan 1] - MF Tx >> 7 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:610] [Thread: 3078019984] [Chan 1] - Sending ANI digit 1
[15:05:51:610] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [ON]
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:710] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Rx << 5 [OFF]
[15:05:51:810] [Thread: 3078019984] [Chan 1] - Sending more ANI unavailable
[15:05:51:810] [Thread: 3078019984] [Chan 1] - MF Tx >> F [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [ON]
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:51:990] [Thread: 3078019984] [Chan 1] - MF Tx >> F [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Rx << 3 [OFF]
[15:05:52:090] [Thread: 3078019984] [Chan 1] - Sending category National Subscriber
[15:05:52:090] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [ON]
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:05:53:350] [Thread: 3078019984] [Chan 1] - MF Tx >> 1 [OFF]
[15:05:53:430] [Thread: 3078019984] [Chan 1] - MF Rx << 1 [OFF]
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - Cannot cancel timer 0
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Tx >> [CLEAR FORWARD] 0x08
[15:06:03:322] [Thread: 3078019984] [Chan 1] - CAS Raw Tx >> 0x09
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Bits changed from 0x0C to 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - CAS Rx << [IDLE] 0x08
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Call ended
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Attempting to cancel timer timer 0
[15:06:03:569] [Thread: 3085228944] [Chan 1] - Cannot cancel timer 0
```

#### Configuración de MFC/R2

Las opciones están documentadas dentro del archivo chan_dahdi.conf. Algunos de los parámetros más importantes se detallan aquí. Parámetros obligatorios: mfcr2_variant, mfcr2_max_ani y mfcr2_max_dnis. mfcr2_variant: Variante del país.

```
r2test -l
Variant Code        Country
AR                  Argentina
BR                  Brazil
CN                  China
CZ                  Czech Republic
CO                  Colombia
EC                  Ecuador
ITU                 International Telecommunication Union
MX                  Mexico
PH                  Philippines
VE                  Venezuela
```

mfcr2_max_ani: Cantidad máxima de dígitos ANI a solicitar. mfcr2_max_dnis: Cantidad máxima de dígitos DNIS a solicitar. mfcr2_get_ani_first: Si obtener o no el ANI antes del DNIS (requerido por algunas TELCOS). mfcr2_category: Categoría del llamador. Puede establecer la variable MFCR2_CATEGORY antes de iniciar la llamada. mfcr2_logdir: Directorio para registrar los archivos de llamada. (/var/log/asterisk/mfcr2/directory). mfcr2_call_files: Si registrar o no las llamadas.

- mfcr2_logging: valores de registro
- cas – bits ABCD para tx y rx
- mf – tonos multifrecuencia
- stack – salida detallada de la pila de canal y contexto
- all – todas las actividades
- nothing – no registrar nada

mfcr2_mfback_timeout: Este valor merece ser mencionado. A veces, si está llamando a un teléfono celular o cualquier llamada que tarda mucho tiempo en completarse, este parámetro puede agotarse (time out), por lo que a menudo se cambia para un ajuste fino. Si algunas de sus llamadas no se están completando, este es el parámetro que debería cambiar primero. mfcr2_metering_pulse_timeout: Los pulsos son utilizados por algunas variantes R2 para indicar costos. mfcr2_allow_collect_calls: En Brasil, el tono II-8 se utiliza para indicar una llamada por cobrar; este parámetro le permite bloquear llamadas por cobrar. mfcr2_double_answer: También utilizado para evitar llamadas por cobrar cuando se requiere una doble respuesta. Con double_answer=yes usted bloquea efectivamente las llamadas por cobrar. mfcr2_immediate_accept: Le permite omitir el uso de señales de grupo B/II e ir directamente al estado aceptado. mfcr2_forced_release: Le permite acelerar la liberación de la llamada; funciona para la variante brasileña.

#### ANI y DNIS

La Identificación Automática de Número (ANI) es el número del llamador. El Servicio de Identificación de Número Marcado (DNIS) es el número llamado o, en otras palabras, el número marcado. Cuando se recibe una llamada, generalmente los últimos cuatro números se pasan a la PBX en un proceso referido como marcación directa entrante (DID). El número ANI es en realidad el Caller ID. El ANI tendrá la extensión del llamador al marcar, mientras que el DNIS contendrá el destino de la llamada. Es importante que estos parámetros se configuren correctamente. Algunos switches envían solo los últimos cuatro dígitos mientras que otros envían el número completo.

### Formato de canal DAHDI

Los canales DAHDI utilizan el siguiente formato en el plan de marcación:

```
DAHDI/[g]<identifier>[c][r<cadence>]
<identifier> - Physical channel numeric identifier
[g] - Group identifier
[c] - Answer confirmation. A number is not considered until the callee presses "#"
[r] - customized ringing
[cadence] - Integer from 1 to 4
```

Ejemplos:

```
DAHDI/2     - channel 2
DAHDI/g1    - First available channel in group 1
```

## El protocolo IAX2

En este capítulo, aprenderemos sobre el protocolo Inter-Asterisk eXchange (IAX), incluyendo sus fortalezas y debilidades. También se cubrirán detalles como el modo trunk y la interconexión de dos servidores Asterisk. Todas las referencias en este documento corresponden a la versión 2 de IAX.

El protocolo IAX proporciona transporte de medios y señalización para voz y video. IAX es muy innovador; ahorra ancho de banda en modo trunk y es mucho más simple que SIP cuando se necesita atravesar NAT. El uso principal de IAX hoy en día es interconectar servidores Asterisk. IAX fue creado principalmente para voz, pero también puede acomodar video y otros flujos multimedia.

IAX se inspiró en otros protocolos VoIP, como SIP y MGCP. En lugar de utilizar dos protocolos separados para señalización y medios, IAX los unificó para crear un protocolo único. IAX no utiliza RTP para el transporte de medios; en su lugar, incrusta los medios en la misma conexión UDP.

**Estado en Asterisk 22.** `chan_iax2` todavía se incluye y es totalmente compatible en Asterisk 22 LTS, por lo que todo lo expuesto en esta sección sigue siendo válido. Sin embargo, IAX2 es un protocolo heredado que ve relativamente pocos despliegues nuevos: la industria ha convergido mayoritariamente en SIP (vía `chan_pjsip` en Asterisk 22) tanto para trunking de proveedores como para interconexión de servidores. La principal ventaja restante de IAX2 es su diseño de puerto único: toda la señalización y los medios fluyen sobre un solo puerto UDP (4569 por defecto), lo que simplifica la configuración del firewall y NAT en comparación con SIP y sus flujos RTP separados. Para un nuevo trunk de Asterisk a Asterisk donde NAT no es una preocupación, un trunk PJSIP es el enfoque moderno recomendado; IAX2 se cubre aquí porque sigue siendo una opción válida, especialmente donde solo se puede abrir un puerto UDP a través de un firewall.

### Objetivos

Al final de este capítulo, usted debería ser capaz de:

- Identificar las fortalezas y debilidades del protocolo IAX
- Describir escenarios de uso para el protocolo IAX
- Describir las ventajas del modo trunk de IAX
- Configurar iax.conf para teléfonos
- Configurar iax.conf para la conexión con un proveedor VoIP
- Configurar iax.conf para la interconexión de Asterisk
- Comprender la autenticación IAX

### Diseño de IAX

Los objetivos principales para el diseño de IAX son:

- Reducir el ancho de banda requerido para el transporte de medios y la señalización
- Proporcionar transparencia NAT
- Ser capaz de transmitir la información del dialplan
- Soportar el uso eficiente de paginación e intercomunicación

IAX es un protocolo de señalización y medios peer-to-peer similar a SIP sin utilizar RTP. El enfoque básico es multiplexar los flujos multimedia sobre una única conexión UDP entre dos hosts. El mayor beneficio de este enfoque es su simplicidad al atravesar conexiones sobre NAT, que se encuentran regularmente en módems xDSL. IAX utiliza un solo puerto, UDP 4569 por defecto, y luego utiliza un número de llamada con 15 bits para multiplexar todos los flujos. El protocolo IAX utiliza procesos de registro y autenticación similares al protocolo SIP. Una descripción del protocolo se puede encontrar en http://www.ietf.org/internet-drafts/draft-guy-iax-05.txt

![El protocolo IAX multiplexa muchas llamadas entre dos endpoints sobre un solo puerto UDP (4569 por defecto), usando un número de llamada de 15 bits para mantener los flujos separados, lo que hace que el cruce de NAT sea simple.](../images/10-legacy-fig12.png)

### Uso de ancho de banda

El ancho de banda utilizado en las redes VoIP se ve afectado por varios factores; los codecs y las cabeceras de protocolo son los más importantes. El protocolo IAX tiene una característica sorprendente llamada modo trunk, mediante la cual multiplexa varias llamadas utilizando una sola cabecera. Al jugar con la calculadora de ancho de banda de Asterisk, verá cómo los trunks IAX pueden ahorrarle hasta un 80% del tráfico con llamadas múltiples.

![Comparación del overhead de IAX y SIP: dos llamadas SIP/RTP necesitan dos paquetes (40 bytes de carga útil transportados bajo 156 bytes de overhead), mientras que el modo trunk de IAX2 transporta ambas llamadas en un solo paquete (40 bytes de carga útil bajo solo 66 bytes de overhead) al compartir una cabecera IP/UDP a través de muchos mini-frames.](../images/10-legacy-fig13.png)

### Nomenclatura de canales

Es importante entender las convenciones de nomenclatura de canales, ya que utilizará estos nombres al especificar un canal en el dialplan. El formato de un nombre de canal IAX utilizado para canales salientes es:

```
IAX/[<user>[:<secret>]@]<peer>[:<portno>][/<exten>[@<context>][/<options>]
```

- `<user>` — UserID en el peer remoto, o nombre del cliente configurado en iax.conf
- `<secret>` — La contraseña. Alternativamente, puede ser el nombre de archivo para una clave RSA sin la extensión final (.key o .pub) y encerrado entre corchetes
- `<peer>` — Nombre del servidor al cual conectarse
- `<portno>` — Número de puerto para la conexión
- `<exten>` — Extension en el servidor Asterisk remoto
- `<context>` — Context en el servidor Asterisk remoto
- `<options>` — La única opción disponible es 'a', que significa 'request autoanswer'

#### Ejemplo de canales salientes:

Los canales salientes se ven en la consola de Asterisk.

- `IAX2/8590:secret@myserver/8590@default` — Llamar a la extension 8590 en myserver. Utiliza 8590:secret como el par nombre/contraseña
- `IAX2/iaxphone` — Llamar a "iaxphone"
- `IAX2/judy:[judyrsa]@somewhere.com` — Llamar a somewhere.com usando judy como nombre de usuario y una clave RSA para autenticación

#### El formato de un canal IAX entrante es:

Los canales entrantes se ven en la consola de Asterisk.

```
IAX2/[<username>@]<host>]-<callno>
```

- `<username>` — Nombre de usuario si se conoce
- `<host>` — Host que se conecta
- `<callno>` — Número de llamada local

Ejemplo de canal entrante:

- `IAX2[flavio@8.8.30.34]/10` — Número de llamada 10 desde la dirección IP 8.8.30.34 usando flavio como usuario.
- `IAX2[8.8.30.50]/11` — Número de llamada 11 desde la dirección IP 8.8.30.50.

### Uso de IAX

Puede utilizar IAX de varias maneras. En esta sección, le mostraremos cómo configurar IAX para varios escenarios, incluyendo:

- Conectar un softphone usando IAX
- Conectar IAX a un proveedor VoIP usando IAX
- Conectar dos servidores usando IAX
- Conectar dos servidores usando IAX en modo trunk
- Depurar una conexión IAX
- Usar pares de claves RSA para autenticación

#### Conectar un softphone usando IAX

Asterisk soporta teléfonos IP basados en IAX como el ATCOM y el antiguo ATA de Digium (llamado IAXy), así como softphones que todavía implementan el protocolo IAX2. El proceso para softphones, ATAs y teléfonos físicos es similar. Para configurar un dispositivo IAX, necesita editar el archivo iax.conf en /etc/asterisk

```
directory.
```

Usaremos un softphone compatible con IAX2 como ejemplo.

1. Haga una copia de seguridad del archivo original `iax.conf` usando:

```
#cd /etc/asterisk
#mv iax.conf iax.conf.backup
```

2. Comience a editar un nuevo archivo `iax.conf`:

```
[general]
bindport=4569
bindaddr=8.8.1.4
bandwidth=high
```

- ; Parámetro muy importante, cambia los codecs disponibles

```
disallow=all
allow=ulaw
jitterbuffer=no
forcejitterbuffer=no
tos=lowdelay
autokill=yes
[guest]
type=user
context=guest
callerid="Guest IAX User"
; Trust Caller*ID Coming from iaxtel.com
;
[iaxtel]
type=user
context=default
auth=rsa
inkeys=iaxtel
;
; Trust Caller*ID Coming from iax.fwdnet.net
;
[iaxfwd]
type=user
context=default
auth=rsa
inkeys=freeworlddialup
;
; Trust callerid delivered over DUNDi/e164
;
;
;[dundi]
;type=user
;dbsecret=dundi/secret
;context=dundi-e164-local
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

He intentado preservar las líneas predeterminadas (no comentadas) del archivo de muestra. Se modificaron los siguientes parámetros:

```
bandwidth=high
```

Esta línea afecta la selección de codec. Usar el ajuste high permite la selección de un codec de alto ancho de banda y alta calidad como g.711 definido por la palabra clave ulaw. Si mantiene el parámetro predeterminado, no podrá elegir ulaw. En este caso, Asterisk le dará el mensaje “no codec available” para la configuración a continuación.

```
disallow=all
allow=ulaw
```

En los comandos descritos anteriormente, deshabilitamos todos los codecs y habilitamos solo ulaw. En redes LAN, la mayoría de la gente prefiere usar ulaw porque no consume muchos recursos del procesador y ahorra ciclos de CPU. Incluso usando más ancho de banda, este codec es preferible porque en las LAN generalmente tiene una Ethernet de 100 megabits o incluso un Gigabit. Una llamada de voz usando ulaw utiliza casi 100 kilobits por segundo de ancho de banda de su red, lo cual es un uso muy ligero para las LAN de alta velocidad de hoy en día. En redes WAN o Internet, generalmente deshabilitará ulaw, intercambiando algunos ciclos de CPU disponibles por compresión de voz para un mejor uso del ancho de banda. Los codecs gsm, g729 e ilbc también proporcionan un buen factor de compresión.

```
[2003]
type=friend
context=default
secret=senha
host=dynamic
```

En los comandos anteriores, hemos definido un friend llamado [2003]. El context es el default (en los primeros laboratorios siempre usamos el context default para evitar confusiones; este context se explicará completamente cuando cubramos el dialplan). La línea “host=dynamic” proporciona un registro dinámico de la dirección IP del teléfono.

3. Descargue e instale un softphone compatible con IAX2. Puede elegir cualquier softphone que todavía soporte el protocolo IAX2 para el laboratorio.
4. Configure una cuenta IAX en el cliente (típicamente *Add account* → IAX). Tenga en cuenta que el SipPulse Softphone es solo SIP y no puede registrarse sobre IAX2, por lo que para las pruebas de IAX necesita un cliente que todavía soporte el protocolo.

5. Configure el archivo `extensions.conf` para probar su dispositivo IAX.

```
[default]
exten=>2000,1,Dial(SIP/2000)
exten=>2001,1,Dial(SIP/2001)
exten=>2003,1,Dial(IAX2/2003)
```

Ahora puede marcar entre los teléfonos SIP creados en el Capítulo 3 y el teléfono IAX creado en el laboratorio.

#### Conectar a un proveedor VoIP usando IAX

Algunos proveedores VoIP soportan IAX. Puede encontrar fácilmente un proveedor IAX buscando “IAX providers”. Usar un proveedor IAX tiene mucho sentido ya que IAX puede ahorrar mucho ancho de banda, atraviesa fácilmente NAT y puede autenticarse usando pares de claves RSA.

![El Asterisk de un cliente conectado a un proveedor VoIP sobre un trunk IAX a través de Internet: un solo trunk transporta todas las llamadas hacia y desde el proveedor.](../images/10-legacy-fig14.png)

El número de proveedores VoIP comerciales capaces de IAX ha disminuido drásticamente en las últimas versiones de Asterisk; la mayoría de los proveedores ahora ofrecen trunks SIP/PJSIP exclusivamente. Antes de comprometerse con un proveedor IAX, confirme que mantienen activamente su infraestructura IAX. Para una nueva integración con un proveedor, un trunk PJSIP (Capítulo 3) es la alternativa recomendada.

#### Conectar a un proveedor usando IAX

Paso 1: Abra una cuenta en su proveedor favorito. Su proveedor le proporcionará tres cosas.

- Nombre
- Secret
- Dirección IP o nombre de host
- Clave pública RSA

Paso 2: Configure el archivo iax.conf para registrar su Asterisk con su proveedor. Agregue las siguientes líneas a la sección [general] del archivo.

```
[general]
register=>name:secret@hostname/2003
```

En las instrucciones descritas anteriormente, se registró con su proveedor usando su cuenta y contraseña. En el momento en que reciba una llamada, esta será reenviada a la extension 2003.

```
[name]
```

- ; Su nombre de cuenta o número

```
type=peer
secret=secret
; Your password
host=hostname
```

En las instrucciones descritas anteriormente, hemos creado un peer correspondiente al proveedor para fines de marcado.

```
[nameiax]
type=user
context=default
auth=rsa
inkeys=hostname
```

Esto es necesario para la autenticación RSA. Usar la clave pública de su proveedor le permite estar seguro de que la llamada que se recibe es realmente del proveedor verdadero. Si alguien más intenta usar la misma ruta, no podrá autenticarla porque no tienen la clave privada correspondiente. Paso 4: Pruebe la conexión. Para probar la conexión, llame a cualquier número. Algunos proveedores proporcionan una prueba de eco. Para lograr esto, por favor edite el archivo extensions.conf.

```
[default]
exten=>*98,1,Dial(IAX2/name:secret@hostname/*98,20,r)
```

Vaya a la CLI de Asterisk y ejecute un reload. Para verificar si Asterisk está registrado con el proveedor, use el siguiente comando.

```
*CLI>reload
*CLI>iax2 show register
```

Ahora simplemente marque *98 en el softphone conectado al servidor Asterisk.

#### Conectar dos servidores Asterisk a través de un trunk IAX

Es muy fácil conectar un servidor a otro. No necesitará registrarlos porque las direcciones IP ya son conocidas. Tendrá que crear los peers y users en el archivo iax.conf. Todas las extensiones en el sitio HQ comienzan con 20 seguidas de dos dígitos (ej. 2000). En la sucursal (Branch), todas las extensiones comienzan con 22 seguidas de dos dígitos (ej. 2200). Usaremos el trunk. Necesitará una fuente de tiempo DAHDI para habilitar esta característica. Paso 1: Edite el archivo iax.conf en el servidor de la sucursal.

![Conectando dos servidores Asterisk con un trunk IAX: el servidor HQ (192.168.1.1, extensiones 20xx) y el servidor de la sucursal (192.168.1.2, extensiones 22xx) se alcanzan entre sí sobre un solo trunk IAX — no se necesita registro porque ambas direcciones IP son fijas y conocidas.](../images/10-legacy-fig15.png)

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;allow=gsm
[Branch]
type=user
context=default
secret=password
host=192.168.2.10
trunk=yes
notransfer=yes
[HQ]
type=peer
context=default
username=HQ
secret=password
host=192.168.2.10
callerID='HQ'
trunk=yes
notransfer=yes
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2000'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2001'
```

Paso 2: Configure el archivo extensions.conf en el servidor de la sucursal

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_20XX,1,dial(IAX2/HQ/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

Paso 3: Configure el archivo iax.conf en el servidor HQ

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
[Branch]
type=peer
context=default
username=Branch
secret=password
host=192.168.2.9
callerid="Branch"
trunk=yes
notransfer=yes
[HQ]
type=user
secret=password
context=default
host=192.168.2.9
callerid="HQ"
trunk=yes
notransfer=yes
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2200"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2201"
host=dynamic
```

Paso 4: Configure el archivo extensions.conf en el servidor HQ.

```
[general]
static=yes
writeprotect=no
autofallthrough=yes
clearglobalvars=no
priorityjumping=no
[default]
exten=>_22XX,1,Dial(IAX2/Branch/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Paso 5: Pruebe una llamada desde el teléfono 2000 en el servidor HQ al teléfono 2200 en el servidor de la sucursal.

### Autenticación IAX

Ahora analicemos el proceso de autenticación IAX desde el punto de vista práctico para ayudarle a elegir el mejor método para cada requisito específico.

#### Conexiones entrantes

![El flujo de decisión de autenticación IAX para una llamada entrante: Asterisk se ramifica dependiendo de si se proporciona un nombre de usuario, si coincide con una sección, si la IP de origen está permitida y si el secret (texto plano, MD5 o RSA) coincide — aceptando la llamada con el context y las opciones de peer de esa sección, o denegándola.](../images/10-legacy-fig16.png)

Cuando Asterisk recibe una conexión entrante, la información inicial puede incluir un nombre de usuario (del campo "username=") o no. La conexión entrante también tiene una dirección IP, que Asterisk utiliza para la autenticación también.

Si se proporciona un usuario, Asterisk:

1. Busca en iax.conf una entrada con type=user (o type=friend con un nombre de sección que coincida con el nombre de usuario). Si no la encuentra, Asterisk rechaza la conexión.
2. Si la entrada encontrada tiene configuraciones de deny/allow, compara la dirección IP del llamante para determinar si aceptar la llamada o no dependiendo de las cláusulas deny/allow.
3. Verifica la contraseña (secret) usando texto plano, md5 o RSA.
4. Acepta la conexión y envía la llamada al context especificado en la línea "context=" del archivo iax.conf.

Si no se proporciona un nombre de usuario, Asterisk:

1. Busca una entrada que contenga type=user (o type=friend) en el archivo iax.conf sin un secret especificado. También verifica las cláusulas deny/allow. Si se encuentra una entrada, la conexión se acepta y el nombre de la sección se utiliza como el nombre del usuario.
2. Busca una entrada que contenga type=user (o type=friend) en el archivo iax.conf con un secret o clave RSA especificada. Verifica las cláusulas deny/allow. Si se encuentra una entrada, intenta autenticar al llamante usando el secret especificado; si coincide, acepta la conexión. El nombre de la sección es el nombre del usuario.

Supongamos que su archivo iax.conf tiene las siguientes entradas:

```
[guest]
type=user
context=guest
[iaxtel]
type=user
context=incoming
auth=rsa
inkeys=iaxtel
[iax-gateway]
type=friend
allow=192.168.0.1
context=incoming
host=192.168.0.1
[iax-friend]
type=user
secret=this_is_secret
auth=md5
context=incoming
```

Si una llamada tiene un nombre de usuario especificado, como:

- guest
- iaxtel
- iax-gateway
- iax-friend

Asterisk intentará autenticar la llamada usando solo la entrada correspondiente en el archivo iax.conf. Si se especifican otros nombres, la llamada sería rechazada. Si no se especifica ningún usuario, Asterisk intentará autenticar la conexión como guest. Sin embargo, si guest no existe, intentará cualquier otra conexión con un secret coincidente. En otras palabras, si no tiene una sección guest en su archivo iax.conf, un usuario malintencionado podría intentar adivinar cualquier secret coincidente no especificando el nombre de usuario. Las restricciones de deny/allow de direcciones IP también se aplican. Una buena manera de evitar la adivinanza de secretos es usar autenticación RSA. Otro método es restringir las direcciones IP permitidas para llamar.

#### Restricciones de dirección IP

El acceso se controla con las líneas `permit` y `deny`:

```
permit = <ipaddr>/<netmask>
deny = <ipaddr>/<netmask>
```

Las reglas se interpretan en secuencia, y todas ellas se evalúan (este concepto es diferente de las ACLs que se encuentran usualmente en routers y firewalls). La última instrucción coincidente reemplaza a las anteriores.

Ejemplo #1:

```
permit=0.0.0.0/0.0.0.0
deny=192.168.0.0/255.255.255.0
```

Esto denegará cualquier paquete de la red 192.168.0.0/24.

Ejemplo #2:

```
deny=192.168.0.0/255.255.255.0
permit=0.0.0.0/0.0.0.0
```

Esto permitirá cualquier paquete, porque la última instrucción reemplaza a la primera.

#### Conexiones salientes

Las conexiones salientes adquieren información de autenticación utilizando los siguientes métodos:

- La descripción del canal IAX2 pasada por la aplicación dial().
- Una entrada con type=peer o type=friend en el archivo iax.conf.
- Una combinación de ambos métodos.

#### Conectar dos servidores Asterisk usando claves RSA

Es posible usar IAX con autenticación fuerte usando claves RSA asimétricas. Según el código fuente (res_krypto.c), Asterisk usa claves RSA con un algoritmo SHA-1 para resúmenes de mensajes en lugar del MD5 más débil. A continuación, se presenta una guía paso a paso para configurar dos servidores usando claves RSA.

##### Configurar el servidor para la sucursal

Paso 1: Genere las claves RSA en el servidor de la sucursal

```
astgenkey -n
```

Cuando se le pregunte, use el nombre de clave branch. Hemos usado el parámetro –n para evitar pasar una frase de contraseña cada vez que Asterisk se reinicializa. Si desea mejorar la seguridad, no use el –n e inicie Asterisk con asterisk -i Paso 2: Copie las claves al directorio /var/lib/asterisk/keys

```
cp branch.* /var/lib/asterisk/keys
```

Paso 3: Copie la clave pública al servidor HQ

```
scp branch.pub root@hq_ip_address:/var/lib/asterisk/keys
```

Paso 4: Edite el archivo iax.conf en el servidor de la sucursal.

```
[general]
bindport=4569                   ; bindport and bindaddr may be specified
bindaddr=0.0.0.0                ; more than once to bind to multiple
disallow=all
allow=ulaw
;Create an entry for the HQ server
[hq]
type=user
context=default
host=192.168.2.10
trunk=yes
notransfer=yes
auth=rsa
inkeys=hq
[2200]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2200'
[2201]
type=friend
auth=md5
context=default
secret=password
host=dynamic
callerid='2201'
```

Paso 8: Configure el archivo extensions.conf en el servidor de la sucursal

```
 [default]
exten=>_20XX,1,dial(IAX2/branch:[branch]@192.168.2.10/${EXTEN},20)
exten=>_20XX,2,hangup
exten=>_22XX,1,dial(IAX2/${EXTEN},20)
exten=>_22XX,2,hangup
```

##### Configurar el servidor para la sede central

Paso 1: Genere las claves RSA en el servidor HQ

```
astgenkey -n
```

Cuando se le pregunte, use el nombre de clave hq. Paso 2: Copie las claves al directorio /var/lib/asterisk/keys

```
cp hq.* /var/lib/asterisk/keys
```

Paso 3: Copie la clave pública al servidor BRANCH

```
scp hq.pub root@branch_ip_address:/var/lib/asterisk/keys
```

Paso 4: Configure el archivo iax.conf en el servidor HQ

```
[general]
bindaddr=0.0.0.0
bindport=4569
disallow=all
allow=ulaw
allow=gsm
;Configure an entry for the branch server
[branch]
type=user
context=default
host=192.168.2.9
trunk=yes
notransfer=yes
auth=rsa
inkeys=branch
[2000]
type=friend
auth=md5
context=default
secret=password
callerid="2000"
host=dynamic
[2001]
type=friend
auth=md5
context=default
secret=password
callerid="2001"
host=dynamic
```

Paso 10: Configure el archivo extensions.conf en el servidor HQ.

```
[default]
exten=>_22XX,1,Dial(IAX2/hq:[hq]@192.168.2.9/${EXTEN})
exten=>_22XX,2,hangup
exten=>_20XX,1,Dial(IAX2/${EXTEN})
exten=>_20XX,2,hangup
```

Paso 11: Pruebe una llamada desde el teléfono 2000 en el servidor HQ al teléfono 2200 en el servidor de la sucursal.

### Configuración del archivo iax.conf

El archivo iax.conf tiene varios parámetros; discutir cada parámetro uno por uno sería aburrido y contraproducente. Todos los parámetros, junto con una descripción, se pueden encontrar en el archivo de muestra. En la wiki www.voip-info.org encontrará información detallada sobre cada uno. Aquí mostraremos algunos de los parámetros más importantes para la configuración de la sección general, peers y users.

#### Sección [General]

Direcciones del servidor:

- `bindport = <portnum>` — Configura el puerto UDP IAX. El predeterminado es 4569.
- `bindaddr = <ipaddr>` — Use 0.0.0.0 para enlazar Asterisk a todas las interfaces, o especifique la dirección IP de una interfaz específica.

Selección de codec:

- `bandwidth = [low|medium|high]` — High = todos los codecs; Medium = todos los codecs excepto ulaw y alaw; Low = codecs de bajo ancho de banda.
- `allow/disallow = [alaw|ulaw|gsm|g.729| etc.]` — Ajuste fino de la selección de codec.

### Jitter buffer

El jitter es la variación de retardo entre paquetes. Es el factor más importante que afecta la calidad de la voz. Se utiliza un Jitter buffer para compensar la variación de retardo. Sacrifica latencia a favor de un menor jitter. Puede hacer una analogía entre el jitter buffer y un tanque de agua. Ambos pueden recibir paquetes o agua a intervalos irregulares, pero finalmente entregarán un flujo regular.

![El jitter buffer como un tanque de agua: los paquetes llegan irregularmente desde la red y llenan el buffer, que luego los libera a una tasa constante para producir un flujo de voz suave. El tamaño del buffer (en ms) intercambia un poco de latencia por un menor jitter; la banda de exceso de buffer permite a Asterisk aumentar o disminuir el buffer a medida que cambian las condiciones de la red.](../images/10-legacy-fig17.png)

Un jitter pequeño (es decir, por debajo de 20 ms) suele ser imperceptible. Sin embargo, un jitter por encima de este nivel es molesto. La latencia o retardo debe mantenerse por debajo de 150ms. Crear un jitter buffer sacrificará algo de retardo por un menor jitter, un concepto conocido como “delay-budget”. Puede afectar el jitter buffer usando estos parámetros:

- Jitterbuffer=<yes/no> – Habilita o deshabilita
- Dropcount=<number> - Cantidad máxima de frames que deben retrasarse en los últimos dos segundos. El ajuste recomendado es 3 (1.5% de frames descartados)
- Maxjitterbuffer=<ms> - Generalmente por debajo de 100 ms
- Maxexcessbuffer=<ms> - Si el retardo de la red mejora, el jitter buffer podría estar sobredimensionado. En consecuencia, Asterisk intentará reducirlo.
- Minexcessbuffer=<ms> - Una vez que el exceso de buffer cae a este valor, Asterisk comienza a aumentar el tamaño del buffer.

### Etiquetado de frames (Frame tagging)

El parámetro a continuación marca el paquete IP en el campo de tipo de servicio. Los routers pueden leer esta etiqueta, priorizando así el tráfico. Asterisk utiliza códigos DSCP para este campo (RFC 2474). Los valores permitidos son CS0, CS1, CS2, CS3, CS4, CS5, CS6, CS7, AF11, AF12, AF13, AF21, AF22, AF23, AF31, AF32, AF33, AF41, AF42, AF43 y ef (es decir, reenvío acelerado).

```
tos=ef
```

### Cifrado IAX2

IAX soporta el cifrado de llamadas usando una clave simétrica, un cifrado de bloque de 128 bits llamado AES (Advanced Encryption Standard). Es muy simple activar el cifrado entre trunks IAX. En el archivo iax.conf use:

```
encryption=yes
```

Para forzar el cifrado:

```
forceencryption=yes
```

Para garantizar la compatibilidad con versiones anteriores, es posible que deba deshabilitar la rotación de claves usando:

```
keyrotate=no
```

### Comandos de depuración IAX2

A continuación se presentan algunos de los comandos de consola de solución de problemas más importantes para Asterisk.

```
iax2 show netstats
vtsvoffice*CLI> iax2 show netstats
                        -------- LOCAL ---------------------  -------- REMOTE ---------------
-----
Channel           RTT  Jit  Del  Lost   %  Drop  OOO  Kpkts  Jit  Del  Lost   %  Drop  OOO
Kpkts
IAX2/8590-1        16   -1    0    -1  -1     0   -1      1   60  110     3   0     0    0
0
iax2 show channels
vtsvoffice*CLI> iax2 show channels
Channel       Peer             Username    ID (Lo/Rem)  Seq (Tx/Rx)  Lag      Jitter  JitBuf
Format
IAX2/8590-2   8.8.30.43        8590        00002/26968  00004/00003  00000ms  -0001ms  0000ms
unknow
iax2 show peers
vtsvoffice*CLI> iax2 show peers
Name/Username    Host                 Mask             Port          Status
8584             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8564             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8576             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8572             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8571             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8585             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8589             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
8590             8.8.30.43       (D)  255.255.255.255  4569          OK (16 ms)
3232             (Unspecified)   (D)  255.255.255.255  0             UNKNOWN
9 iax2 peers [1 online, 8 offline, 0 unmonitored]
iax2 debug
```

Al observar esta salida, identifique el inicio y el final de la llamada. Observe la información de retardo y jitter obtenida usando paquetes poke y pong. Estos paquetes ayudan a crear la salida del comando “iax2 show netstats”.

```
vtsvoffice*CLI> iax2 debug
IAX2 Debugging Enabled
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: REGREQ
   Timestamp: 00003ms  SCall: 26975  DCall: 00000 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: REGAUTH
   Timestamp: 00009ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 137472844
   USERNAME        : 8590
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: REGREQ
   Timestamp: 00016ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
   USERNAME        : 8590
   REFRESH         : 60
   MD5 RESULT      : f772b6512e77fa4a44c2f74ef709e873
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: REGACK
   Timestamp: 00025ms  SCall: 00003  DCall: 26975 [8.8.30.43:4569]
   USERNAME        : 8590
   DATE TIME       : 2006-04-17  16:03:00
   REFRESH         : 60
   APPARENT ADDRES : IPV4 8.8.30.43:4569
   CALLING NUMBER  : 4830258590
   CALLING NAME    : Flavio
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00025ms  SCall: 26975  DCall: 00003 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: POKE
   Timestamp: 00003ms  SCall: 00006  DCall: 00000 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: PONG
   Timestamp: 00003ms  SCall: 26976  DCall: 00006 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Tx-Frame Retry[-01] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00006  DCall: 26976 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[000] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: AUTHREQ
   Timestamp: 00007ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   AUTHMETHODS     : 2
   CHALLENGE       : 190271661
   USERNAME        : 8590
Rx-Frame Retry[Yes] -- OSeqno: 000 ISeqno: 000 Type: IAX     Subclass: NEW
   Timestamp: 00003ms  SCall: 26977  DCall: 00000 [8.8.30.43:4569]
   VERSION         : 2
   CALLING NUMBER  : 8590
   CALLING NAME    : 4830258590
   FORMAT          : 2
   CAPABILITY      : 1550
   USERNAME        : 8590
   CALLED NUMBER   : 8580
   DNID            : 8580
Tx-Frame Retry[-01] -- OSeqno: 000 ISeqno: 001 Type: IAX     Subclass: ACK
   Timestamp: 00003ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 001 ISeqno: 001 Type: IAX     Subclass: AUTHREP
   Timestamp: 00063ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   MD5 RESULT      : 57cc5c48affba14106c29439944413a1
Tx-Frame Retry[000] -- OSeqno: 001 ISeqno: 002 Type: IAX     Subclass: ACCEPT
   Timestamp: 00054ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   FORMAT          : 1024
Tx-Frame Retry[000] -- OSeqno: 002 ISeqno: 002 Type: CONTROL Subclass: ANSWER
   Timestamp: 00057ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 003 ISeqno: 002 Type: VOICE   Subclass: 138
   Timestamp: 00090ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 002 Type: IAX     Subclass: ACK
   Timestamp: 00054ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00057ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: IAX     Subclass: ACK
   Timestamp: 00090ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 002 ISeqno: 004 Type: VOICE   Subclass: 138
   Timestamp: 00210ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[-01] -- OSeqno: 004 ISeqno: 003 Type: IAX     Subclass: ACK
   Timestamp: 00210ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 003 ISeqno: 004 Type: IAX     Subclass: PING
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Tx-Frame Retry[000] -- OSeqno: 004 ISeqno: 004 Type: IAX     Subclass: PONG
   Timestamp: 02083ms  SCall: 00004  DCall: 26977 [8.8.30.43:4569]
   RR_JITTER       : 0
   RR_LOSS         : 0
   RR_PKTS         : 1
   RR_DELAY        : 40
   RR_DROPPED      : 0
   RR_OUTOFORDER   : 0
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: ACK
   Timestamp: 02083ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
Rx-Frame Retry[ No] -- OSeqno: 004 ISeqno: 005 Type: IAX     Subclass: HANGUP
   Timestamp: 08693ms  SCall: 26977  DCall: 00004 [8.8.30.43:4569]
   CAUSE           : Dumped Call
```

Para desactivar la depuración, use:

```
vtsvoffice*CLI>iax2 no debug
```

### Resumen

Este capítulo ha revisado las fortalezas y debilidades del protocolo IAX. Ha demostrado cómo funciona IAX en varios escenarios, como softphones y un trunk entre dos servidores Asterisk. El modo trunk le permite ahorrar ancho de banda al transportar más de una llamada en un solo paquete. Finalmente, aprendió comandos de consola que puede usar para verificar el estado y depurar el protocolo.

## Legacy SIP: chan_sip y sip.conf (eliminado en Asterisk 21+)

> **Legado / histórico:** Todo en esta sección utiliza el antiguo controlador `chan_sip`
> y su archivo de configuración `sip.conf`. `chan_sip` fue marcado como obsoleto durante
> varias versiones y **eliminado en Asterisk 21**, por lo que **no existe en
> Asterisk 22**. Ninguno de los ejemplos de `sip.conf` a continuación funcionará en un
> sistema actual; se mantienen aquí solo para documentar cómo funcionaban las
> implementaciones heredadas y para ayudarle a migrarlas. Para conocer la forma
> moderna y compatible de hacer esto, consulte la sección *PJSIP: the SIP channel*
> del capítulo *SIP & PJSIP in depth*. La teoría del *protocolo* SIP (métodos,
> registro, proxy/redirect, SDP, tipos de NAT) es a nivel de protocolo y se
> encuentra en ese capítulo; lo que sigue es puramente la **configuración**
> eliminada de `chan_sip`.

En los sistemas heredados hasta Asterisk 20, SIP se configuraba en `/etc/asterisk/sip.conf`, que solía ser el segundo archivo más modificado (justo después de `extensions.conf`). Las secciones a continuación muestran cómo `chan_sip` conectaba Asterisk a un proveedor SIP, cómo conectar dos Asterisk entre sí usando SIP, soporte de dominio, presencia, opciones de codec/DTMF/QoS, autenticación y NAT, seguido de una guía para migrar todo esto a PJSIP.

### Conexión de Asterisk a un proveedor SIP (sip.conf)

Asterisk se utiliza a menudo para conectarse a un proveedor de VoIP SIP. Los proveedores de VoIP suelen tener mejores tarifas para llamadas telefónicas que los proveedores tradicionales. Otro punto interesante y atractivo de los proveedores de VoIP es la posibilidad de comprar números DID en otras ciudades, incluso en países extranjeros. Estas son buenas razones para utilizar VoIP para las telecomunicaciones. En esta sección, aprenderá cómo el `chan_sip` heredado conectaba Asterisk a un proveedor de VoIP. Se requieren tres pasos para conectar Asterisk a un proveedor SIP. Las pruebas se pueden realizar estableciendo una cuenta con su proveedor favorito. Paso 1: Registro con un proveedor SIP en sip.conf Para conectarse a un proveedor SIP, necesitará la siguiente información del proveedor:

![Asterisk conectado a un proveedor de servicios VoIP a través de Internet o una WAN privada, con teléfonos SIP locales registrados en el servidor Asterisk](../images/07-sip-and-pjsip-fig07.png)

- nombre de usuario
- secret y remotesecret (Use secret para autenticar solicitudes entrantes y remotesecret para solicitudes salientes)
- nombre de host
- dominio
- codecs permitidos

Esta configuración permitirá a su proveedor localizar la dirección IP de Asterisk. En la siguiente declaración, le decimos a Asterisk que se registre en un proveedor SIP definido por el nombre de host e informamos al proveedor de la dirección IP de Asterisk. La declaración indica que desea recibir llamadas en la extension 4100. En la sección [general] del archivo sip.conf, ingrese la siguiente línea:

```
register=>name:secret@hostname/4100
```

Paso 2: Configure el [peer] en sip.conf Cree una entrada de tipo peer para el proveedor deseado para simplificar el marcado de Asterisk.

```
[provider]
context=incoming
type=friend
dtmfmode=rfc2833
directmedia=no
username=username
remotesecret=secret
host=hostname
fromuser=username
fromdomain=domain
insecure=invite
disallow=all
allow=ulaw ; or any other codec available from your provider
```

Paso 3: Cree una ruta hacia el proveedor en el dialplan Elegiremos los dígitos 010 como la ruta de destino hacia el proveedor. Para marcar #610000 dentro del proveedor, simplemente marque 010610000.

```
exten=>_010.,1,Set(CALLERID(num)=username)
exten=>_010.,n,Set(CALLERID(Name)="Flavio Gonçalves")
exten=>_010.,n,Dial(SIP/${EXTEN:3}@provider)
exten=>_010.,n,Hangup
```

#### Opciones SIP específicas para el escenario del proveedor

La siguiente discusión examina los detalles de las opciones establecidas en el archivo sip.conf para la conexión a un proveedor de VoIP.

```
register=>username:password@hostname/4100
```

La instrucción register en el archivo sip.conf se utiliza para registrarse con un proveedor. La transacción de registro se autentica con el nombre y el secret. Puede usar una barra diagonal (“/”) para proporcionar una extension para las llamadas entrantes. Técnicamente hablando, la extension se colocará en el campo de encabezado “Contact” de la solicitud SIP. El comportamiento de registro puede ser controlado por ciertos parámetros:

```
registertimeout=20
registerattempts=10
```

Para verificar si el registro fue exitoso, el comando de consola heredado era `sip show registry`. En Asterisk 22, el comando equivalente es `pjsip show registrations` (registros salientes) y `pjsip show endpoints` para el estado del endpoint.

El parámetro “username” se utiliza en el resumen de autenticación (digest). El resumen se calcula utilizando el nombre de usuario, el secret y el realm:

```
username=username
```

Host define la dirección o el nombre del proveedor de VoIP:

```
host=hostname
```

Los parámetros Fromuser y Fromdomain a veces son necesarios para la autenticación. Estos parámetros se utilizan en el campo de encabezado SIP From:

```
fromuser=username
fromdomain=hostname
```

Cuando se conecta a un proveedor de VoIP, se requieren credenciales. Después de la invitación inicial, el proveedor le envía un mensaje llamado “407 Proxy Authentication Required”; usted proporciona las credenciales en el mensaje INVITE posterior. Para las llamadas entrantes, su servidor Asterisk solicitará credenciales para el proveedor. Obviamente, el proveedor no tiene una credencial válida para su servidor Asterisk. Cuando usa insecure=invite, le está diciendo a Asterisk que no envíe el “407 Proxy Authentication Required” al proveedor y que acepte las llamadas entrantes. También puede usar insecure=port, invite para hacer coincidir el peer según la dirección IP sin hacer coincidir el número de puerto.

```
insecure=invite, port
```

### Conexión de dos servidores Asterisk mediante SIP (sip.conf)

Puede usar SIP para interconectar dos cajas Asterisk. Es importante prestar atención al dialplan antes de continuar con esta configuración. Los usuarios generalmente quieren conectar otras PBX con el mínimo esfuerzo. La idea aquí es usar un número de extension solo para conectarse a la otra PBX. Paso 1: Edite el archivo sip.conf en el servidor A:

```
[B]
type=user
secret=B
host=A
disallow=all
allow=ulaw
directmedia=no
[B-out]
type=peer
fromuser=A
username=A
remotesecret=A
host=B
disallow=all
allow=ulaw
directmedia=no
```

Paso 2: Edite el archivo sip.conf en el servidor B:

```
[A]
type=user
host=B
secret=A
disallow=all
allow=ulaw
directmedia=no
[A-out]
```

![Conexión de dos servidores Asterisk usando SIP: el servidor A (extensiones 4400/4401) y el servidor B (extensiones 4500/4501) intercambian señalización SIP para que los usuarios en cada PBX puedan marcar al otro](../images/07-sip-and-pjsip-fig08.png)

```
type=peer
host=A
fromuser=B
username=B
remotesecret=B
disallow=all
allow=ulaw
directmedia=no
```

Paso 3: Edite el archivo extensions.conf en el servidor A:

```
[default]
exten=_44XX,1,dial(SIP/${EXTEN},20)
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/B-out/${EXTEN})
exten=_45XX,2,hangup()
```

Paso 4: Edite el archivo extensions.conf en el servidor B:

```
[default]
exten=_44XX,1,dial(SIP/A-out/${EXTEN})
exten=_44XX,2,hangup()
exten=_45XX,1,dial(SIP/${EXTEN})
exten=_45XX,2,hangup()
```

### Soporte de dominio de Asterisk (sip.conf)

El protocolo SIP sigue la arquitectura de Internet. Lo primero que debe hacer antes de configurar SIP es configurar correctamente los servidores DNS. En un entorno SIP, puede llamar a un usuario ubicado en cualquier proxy SIP, y otros usuarios también pueden llamarlo a usted usando su Identificador de Recursos Uniforme (URI) SIP. Para configurar un servidor DNS para SIP, debe agregar registros SRV a su servidor DNS.

```
; SIP server/proxy and its backup server/proxy
sip1.yourdomain.com
21600 IN A
200.180.4.169
sip2.yourdomain.com
21600 IN A
200.175.61.150
;
; DNS SRV records for SIP
_sip._udp.yourdomain.com  21600 IN SRV 10 0 5060 sip1.voip.school.
_sip._udp.yourdomain.com  21600 IN SRV 20 0 5060 sip2.voip.school.
```

Después de configurar el DNS, puede usar el URI, que apunta a un usuario SIP, un teléfono SIP o una extension telefónica. Un URI SIP se parece a una dirección de correo electrónico (por ejemplo, sip:chuck@yourpartnerdomain.com). Usando URIs SIP, no se necesita un número de teléfono para realizar una llamada de un teléfono SIP a otro. Para marcar a un usuario externo, simplemente use una declaración como la que se muestra a continuación.

```
exten=4000,1,dial(SIP/chuck@yourpartnerdomain.com)
```

Ciertos parámetros pueden controlar el comportamiento del dominio.

```
srvlookup=yes
```

Este parámetro habilita las búsquedas DNS SRV en llamadas salientes. Usando este parámetro, es posible realizar llamadas usando nombres SIP basados en el dominio.

```
allowguest=yes
```

Este parámetro permite que una invitación externa sea procesada sin autenticación. Procesa la llamada dentro del context definido en la sección general o en la declaración de dominio. Advertencia: Si define un context en la sección general con acceso a la PSTN, un usuario externo puede marcar a la PSTN a través de su PBX. En este caso, usted incurrirá en cualquier cargo. Permita solo sus propias extensiones en el context definido en la sección general.

![Conexión a otros servidores SIP por dominio: youdomain.com y yourpartnerdomain.com intercambian señalización SIP, para que usuarios como lee y bruce puedan llamar a chuck y norris usando URIs SIP](../images/07-sip-and-pjsip-fig09.png)

```
domain=acme.com,default
```

El comando domain le permite manejar más de un dominio dentro de Asterisk. Si una llamada proviene de un dominio específico, se dirige a un context específico.

```
;autodomain=yes
```

Este parámetro incluye la IP local y el nombre de host en los dominios permitidos.

```
;allowexternaldomains=no
```

El valor predeterminado es yes. Elimine el comentario de la línea para no permitir llamadas a dominios externos.

### Configuraciones avanzadas de SIP (sip.conf)

Esta sección explica algunos parámetros avanzados del canal SIP heredado, como la presencia, la selección de codec, las opciones de DTMF y el marcado de QoS de paquetes. Los **conceptos** (BLF/presencia, negociación de codec, modos DTMF, marcado DSCP) se trasladan a PJSIP, pero los nombres de los parámetros `sip.conf` que se muestran aquí **no** existen en Asterisk 22. En PJSIP, el modo DTMF es `dtmf_mode=` en un endpoint, y los codecs se configuran con `allow=`/`disallow=`.

#### Presencia SIP

La presencia SIP está parcialmente implementada en Asterisk. Asterisk admite solicitudes como SUBSCRIBE y NOTIFY a usuarios dependiendo del estado de un canal. Asterisk no admite el método SIP PUBLISH. En otras palabras, puede suscribirse a los estados (ocupado, inactivo y sonando) de un canal, pero no puede publicar información como “ausente” o “no molestar”. El escenario más común para la presencia es el campo de lámpara ocupada (BLF), en el que se simula el comportamiento de un sistema KS con lámparas para cada extension y trunk. Parámetros SIP para presencia:

- allowsubscribe=yes: Permitir métodos de suscripción SIP
- subscribecontext=sip_subscribers: Context donde buscar sugerencias (hints)
- notifyring=yes: Enviar SIP NOTIFY al sonar
- notifyhold=yes: Enviar SIP NOTIFY al poner en espera
- counteronpeer (renombrado de limitonpeer para Asterisk 1.4.x): Aplicar el contador solo en el lado del peer
- callcounter=yes: Habilitar contadores de llamadas en el dispositivo.
- busylevel=1: Umbral para el número de llamadas para considerar el dispositivo como ocupado.

Por ejemplo: Paso 1: Probar la presencia SIP con Asterisk no es tan difícil. Primero, configuremos los archivos sip.conf y extensions.conf.

En el archivo sip.conf

```
[general]
bindaddr=0.0.0.0
bindport=5060
disallow=all
allow=ulaw
allowsubscribe=yes
notifyringing=yes
notifyhold=yes
limitonpeer=yes
counteronpeer=yes
subscribecontext=default
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
[2001]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
secret=senha
callcounter=yes
busylevel=1
In the file extensions.conf
[default]
exten=2000,hint,SIP/2000
exten=2001,hint,SIP/2001
exten=_20XX,1,dial(SIP/${EXTEN})
exten=_20XX,n,Hangup()
```

Paso 2: Ahora configure el softphone para usar presencia. Le mostraremos cómo configurar el SipPulse Softphone.

- Secuencia: clic derecho->SIP Account Settings->Properties->Presence
- Cambie el modelo de presencia de peer-to-peer a presence agent, lo que hará que el softphone se suscriba a Asterisk para eventos SIP.

Paso 3: Agregue el contacto a otros softphones. En este ejemplo, el SipPulse Softphone es la cuenta 2000, por lo que agregaremos un contacto para la cuenta 2001. Secuencia: Abra el panel derecho (panel de presencia en el softphone)->Haga clic en Contacts->Add a contact. Ingrese el nombre 2001. Muestre como 2001 y no olvide marcar la casilla Show this contact’s availability.

Paso 4: Ahora llame a la extension 2001 y verifique el estado del teléfono en el panel derecho del softphone. Use el comando de consola `core show hints` para ver el estado de presencia cambiando en el servidor (en el chan_sip heredado, `sip show inuse` mostraba cuántas llamadas tenía en cada línea). En Asterisk 22, use `pjsip show endpoints` para inspeccionar el estado del endpoint y del canal. El estado de presencia/BLF aparece en los contactos del softphone o en el panel BLF; la forma exacta en que se muestra depende del cliente.

#### Configuración de codec

La configuración de codec es simple y directa. Puede establecer las palabras allow y disallow en la sección [general] o en la sección peer/user. La mejor práctica es estandarizar el codec para evitar la transcodificación, que consume muchos recursos del procesador. Utilice el mismo codec para mensajes y avisos.

```
[general]
disallow=all
allow=g729
```

#### Opciones de DTMF

En ciertas ocasiones, pasará dígitos a una aplicación como voicemail o un sistema de respuesta de voz interactiva (IVR). Es importante pasar el DTMF correctamente. El método más simple para pasar DTMF se llama inband. Se establece en la sección [general] o peer/user del archivo sip.conf. Cuando establece dtmfmode=inband, los tonos DTMF se generan como sonidos en el canal de audio. El problema principal con este método es que, cuando comprime el canal de audio usando un codec como g729, los sonidos se distorsionan y los tonos DTMF no se reconocen correctamente. Si planea usar dtmfmode=inband, use el codec g.711 (ulaw y alaw).

```
dtmfmode=inband
```

Otro enfoque es usar RFC2833, que le permite pasar tonos DTMF como eventos con nombre en los paquetes RTP.

```
dtmfmode=rfc2833
```

Finalmente, puede pasar dígitos DTMF dentro de paquetes SIP, en lugar de paquetes RTP. Este método está definido en RFC3265 (eventos de señalización) y RFC2976.

```
dtmfmode=info
```

Tras el lanzamiento de la versión 1.2, ahora es posible usar:

```
dtmfmode=auto
```

Esto intenta usar RFC2833; si no es posible, usa tonos en banda.

#### Configuración de marcado de calidad de servicio (QoS)

QoS es un conjunto de técnicas responsables de la calidad de la voz. QoS se implementa de tal manera que reduce el ancho de banda, la latencia y el jitter. Las funciones principales de QoS son la programación de paquetes, la fragmentación y la compresión de encabezados. QoS se implementa en switches y routers, no por el propio Asterisk. Sin embargo, Asterisk puede ayudar a los routers y switches marcando los paquetes para una entrega rápida. El marcado se realiza utilizando puntos de código de servicios diferenciados (DSCP) definidos en RFC 2474 y RFC 2475.

```
tos_sip=cs3
tos_audio=ef
tos_video=af41
```

A partir de la versión 1.4, puede especificar diferentes códigos para señalización (SIP), audio (RTP) y video (RTP).

### Autenticación SIP (sip.conf)

Cuando el `chan_sip` heredado recibía una llamada SIP, seguía las reglas descritas en el siguiente diagrama. Tres parámetros desempeñaban un papel importante en la autenticación SIP. En Asterisk 22, la autenticación se configura en su lugar con objetos PJSIP `auth` (`type=auth`, `auth_type=userpass`, `username=`, `password=`) referenciados por un endpoint, y el control de acceso IP se realiza con `permit=`/`deny=` en el endpoint o mediante un `acl`.

![Flujo de decisión de autenticación de chan_sip heredado: Asterisk verifica el encabezado From contra sip.conf, prueba la sección type=user/peer coincidente y las credenciales MD5, y recurre a insecure=invite o allowguest antes de permitir o denegar la llamada](../images/07-sip-and-pjsip-fig10.png)

```
allowguest=yes/no
```

Este parámetro controla si un usuario sin un peer correspondiente puede autenticarse sin un nombre y un secret. Discutimos este parámetro en la sección de soporte de dominio.

```
insecure=invite,port
```

Cuando usamos insecure=invite, Asterisk no genera el mensaje “407 Proxy Authentication Required”. Sin este mensaje, el usuario puede realizar una llamada sin autenticación. Esto se usa a menudo para conectarse a proveedores de servicios VoIP. Las llamadas que provienen del proveedor de servicios VoIP generalmente no están autenticadas.

```
autocreatepeer=yes/no
```

Este comando se usa cuando Asterisk está conectado a un proxy SIP. Crea dinámicamente un peer para cada llamada. Cuando esta opción está habilitada, cualquier UAC puede conectarse al servidor Asterisk. Es importante limitar la conexión IP al proxy SIP. El proxy SIP, a su vez, se encarga del control de acceso. La configuración del peer se basa en las opciones generales, así como en el campo de encabezado “Contact” del paquete SIP. Advertencia: Use esto con extrema precaución ya que abre completamente Asterisk.

```
secret=secret, remotesecret=secret
```

Este parámetro configura el secret para la autenticación; use secret para solicitudes entrantes y remotesecret para solicitudes salientes. Si no desea presentar los secrets en archivos de texto, puede usar md5secret para incluir un hash en lugar del secret. Para generar el secret MD5, puede usar:

```
echo -n "username:realm:secret" |md5sum
```

Luego use la siguiente declaración:

```
md5secret=0b0e5d467890....
```

Advertencia: No olvide usar el parámetro –n; el retorno de carro se usará en el cálculo del md5.

```
deny=0.0.0.0/0.0.0.0
permit=192.168.1.0/255.255.255.0
```

Las declaraciones anteriores denegarán todas las direcciones IP y permitirán UAC solo desde la red local (192.168.1.0/24).

#### Opciones RTP

Es posible controlar algunos parámetros RTP.

```
rtptimeout=60
```

Esto termina las llamadas sin actividad RTP durante más de 60 segundos cuando no están en espera.

```
rtpholdtimeout=120
```

Esto termina las llamadas sin actividad RTP incluso en espera (debe ser mayor que rtptimeout).

### Recorrido NAT SIP (sip.conf)

La *teoría* de NAT (los cuatro tipos de NAT, el problema del encabezado Contact, los keep-alives y forzar el tráfico multimedia a través del servidor) es a nivel de protocolo y se cubre en el capítulo *SIP & PJSIP in depth*. Los parámetros `sip.conf` que se muestran aquí (`nat=`, `qualify=`, `directmedia=`, `externaddr=`, `localnet=`) son de **chan_sip heredado** y se eliminaron en Asterisk 21+. En PJSIP, estos se asignan a configuraciones de transporte/endpoint como `rewrite_contact=yes`, `force_rport=yes`, `rtp_symmetric=yes`, `direct_media=no`, `external_media_address`, `external_signaling_address` y `local_net=` en el transporte, además de `qualify_frequency=` en el AOR.

En el chan_sip heredado, el parámetro `nat` tenía cinco opciones:

- nat = no — No realizar ningún manejo especial de NAT más que RFC3581
- nat = force_rport — Fingir que había un parámetro rport incluso si no lo había
- nat = comedia — Enviar el tráfico multimedia al puerto desde el que Asterisk lo recibió, independientemente de dónde diga el SDP que se envíe.
- nat = auto_force_rport — Establecer la opción force_rport si Asterisk detecta NAT (predeterminado)
- nat = auto_comedia — Establecer la opción comedia si Asterisk detecta NAT

Cuando coloca la declaración “nat=force_rport” en el archivo sip.conf, le está diciendo a Asterisk que ignore la dirección contenida en el campo de encabezado “Contact” del encabezado SIP y use la dirección IP de origen y el puerto en el encabezado IP del paquete, y también que envíe el tráfico multimedia de regreso a la dirección desde donde se recibió, ignorando el contenido del encabezado SDP.

```
nat=force_rport,comedia
```

Es necesario mantener abierta la asignación NAT. Si NAT expira, Asterisk no puede enviar una invitación al UAC. El UAC puede enviar llamadas, pero no recibir ninguna. La siguiente declaración se puede usar para mantener NAT abierta.

```
qualify=yes
```

Qualify enviará un paquete SIP usando el método OPTIONS regularmente, lo que ayudará a mantener NAT abierta. Qualify envía un OPTIONS cada 60 segundos y cada 10 segundos cuando el host no está accesible. Puede usar “sip show peers” para ver la latencia de los peers. Si el NAT del usuario es de tipo simétrico, no es posible enviar paquetes de un UAC a otro directamente; en ese caso, debe forzar el RTP a través de Asterisk usando:

```
directmedia=no
```

#### Asterisk detrás de NAT (sip.conf)

Todos los escenarios anteriores asumen que el servidor Asterisk tiene una dirección de Internet externa (válida). A veces, el servidor Asterisk se implementa detrás de un firewall con NAT. En este caso, es necesario realizar algunas configuraciones adicionales.

![Asterisk detrás de NAT: un firewall asigna la dirección pública 200.180.4.168 al servidor Asterisk interno (192.168.1.100), reenviando SIP en UDP 5060 y el rango RTP UDP 10000–20000 definido en rtp.conf](../images/07-sip-and-pjsip-fig13.png)

1. Configure el firewall para redirigir el puerto UDP 5060 estáticamente al servidor Asterisk.
2. Configure el firewall para redirigir los puertos UDP de 10000 a 20000 estáticamente.

Si desea restringir la cantidad de puertos abiertos, puede editar el archivo `rtp.conf` para cambiar el rango de puertos RTP. Otra forma es usar un firewall inteligente que admita el protocolo SIP para abrir los puertos RTP dinámicamente.

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

Paso 3: Configure Asterisk para incluir la dirección externa en los campos de encabezado de los paquetes SIP, incluido el Protocolo de Descripción de Sesión (SDP). Puede lograr esto agregando las siguientes dos declaraciones al archivo sip.conf:

```
externaddr=200.180.4.168
;External IP address
localnet=192.168.1.0/255.255.255.0
;Internal Network Address
nat=force_rport,comedia
```

El primer parámetro externaddr le dice a Asterisk que incluya la dirección IP externa dentro de los encabezados SIP para destinos externos. El segundo parámetro localnet permite a Asterisk diferenciar entre direcciones externas e internas. Opcionalmente, puede usar externhost si usa un DNS dinámico con una dirección DHCP en el servidor.

### Cadenas de marcado SIP (chan_sip)

La tecnología de cadena de marcado `SIP/...` que se muestra a continuación es el controlador chan_sip eliminado. En Asterisk 22, use la tecnología `PJSIP/...` en su lugar; por ejemplo, `Dial(PJSIP/2000)` o `Dial(PJSIP/${EXTEN}@provider)`. Las formas y el significado son, por lo demás, análogos.

Puede llamar a un destino SIP heredado usando diferentes cadenas de marcado:

```
SIP/peer
```

- ; Necesita tener un peer definido en sip.conf

```
SIP/flavio@voffice.com.br ; By the URI
SIP/[exten@]peer[:portno]
SIP/[user:password@domain/extension
```

Los ejemplos incluyen:

```
exten=>s,1,Dial(SIP/ipphone)
exten=>s,1,Dial(SIP/info@voffice.com.br)
exten=>s,1,Dial(SIP/192.168.1.8:5060,20)
exten=>s,1,Dial(SIP/8500@sip.com:9876)
```

## Migración de un sistema legacy chan_sip a PJSIP

Debido a que `chan_sip` fue eliminado en Asterisk 21 y ya no existe en Asterisk 22, cualquier despliegue existente de `sip.conf` debe migrarse a PJSIP. El cambio conceptual más importante es que un solo `sip.conf` `[peer]` o `[friend]` se divide en varios objetos PJSIP, cada uno con un `type=`: un **endpoint** (configuración de llamadas/codec/medios), uno o más objetos **aor** (donde se puede localizar el dispositivo / registro), un objeto **auth** (credenciales) y un **transport** compartido (el socket de escucha, direcciones NAT). La siguiente tabla relaciona los conceptos más comunes.

| Concepto legacy sip.conf | Equivalente en PJSIP (pjsip.conf) |
| --- | --- |
| Bloque `[peer]` / `[friend]` | `type=endpoint` + `type=aor` + `type=auth` (referenciado mediante `auth=` y `aors=`) |
| `type=friend` / `type=peer` / `type=user` | un solo `type=endpoint` (PJSIP no tiene distinción entre friend/peer/user) |
| `host=dynamic` (registro de dispositivo) | `type=aor` con `max_contacts=1`; el dispositivo realiza un REGISTER para actualizar su contacto |
| `host=<ip/hostname>` (estático) | `type=aor` con un `contact=sip:host:port` estático |
| `register=>user:secret@host/ext` (saliente) | `type=registration` (`server_uri=`, `client_uri=`, `outbound_auth=`) |
| `secret=` / `username=` | `type=auth`, `auth_type=userpass`, `username=`, `password=` |
| `context=` | `context=` en el endpoint |
| `disallow=all` / `allow=ulaw` | `disallow=all` / `allow=ulaw` en el endpoint (misma sintaxis) |
| `dtmfmode=rfc2833` | `dtmf_mode=rfc4733` (PJSIP) — también `inband`, `info`, `auto` |
| `directmedia=yes/no` | `direct_media=yes/no` en el endpoint |
| `nat=force_rport,comedia` | `force_rport=yes`, `rewrite_contact=yes`, `rtp_symmetric=yes` (endpoint) |
| `qualify=yes` | `qualify_frequency=` (segundos) en el **aor** |
| `externaddr=` | `external_media_address=` y `external_signaling_address=` en el **transport** |
| `localnet=` | `local_net=` en el **transport** |
| `insecure=invite` (proveedor, sin autenticación) | omitir `auth=`/`outbound_auth=` y usar `identify` (`type=identify`, `match=`) |
| `allowguest=yes` | endpoint `anonymous` + `allow_unauthenticated_options` (usar con precaución) |
| `tos_sip` / `tos_audio` | `tos_audio` / `tos_video` (y `cos_audio` / `cos_video`) en el endpoint |

Una extension que se registra y que lucía así en el `sip.conf` legacy:

```
[2000]
type=friend
host=dynamic
context=default
dtmfmode=rfc2833
disallow=all
allow=ulaw
secret=senha
```

se convierte en lo siguiente en `pjsip.conf` en Asterisk 22:

```
[2000]
type=endpoint
context=default
disallow=all
allow=ulaw
dtmf_mode=rfc4733
direct_media=no
auth=2000
aors=2000

[2000]
type=auth
auth_type=userpass
username=2000
password=senha

[2000]
type=aor
max_contacts=1
qualify_frequency=60
```

### El script de conversión sip_to_pjsip.py

Asterisk incluye un script de ayuda, **`sip_to_pjsip.py`**, que lee un `sip.conf` existente y genera un `pjsip.conf`. Puede ejecutarlo directamente en el directorio /etc/asterisk. La utilidad se encuentra en el árbol de fuentes de Asterisk bajo `contrib/scripts/sip_to_pjsip/`, donde `${PATH_TO_ASTERISK_SOURCE}` es la ruta donde se encuentran los archivos fuente de Asterisk (usualmente /usr/src/asterisk-22.x.y/):

```
${PATH_TO_ASTERISK_SOURCE}/contrib/scripts/sip_to_pjsip/sip_to_pjsip.py
```

Si lo ejecuta con la opción `--help`, verá sus opciones:

```
-h, --help                help
-p, --prefix PREFIX       prefix to use for the included config files
-q, --quiet               suppress warnings and informational messages
```

También acepta argumentos posicionales opcionales — `[input-file [output-file]]`, que por defecto son `sip.conf` y `pjsip.conf` en el directorio actual.

Trate su salida como un **punto de partida**: revise cada objeto generado, especialmente los transports, la configuración NAT y las listas de codec, y realice pruebas exhaustivas antes de pasar a producción.

Migremos el archivo sip.conf en nuestros laboratorios complementarios en VoIP School Blackbelt (voip.school)

#### sip.conf

```
[general]
bindport=5060
bindaddr=0.0.0.0
context=dummy
disallow=all
allow=ulaw
alwaysauthreject=yes
allowguest=no
register=>1020:supersecret@sip.flagonc.com:5600/9999
[alice]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[bob]
type=friend
secret=#supersecret#
host=dynamic
qualify=yes
directmedia=no
context=from-internal
[siptrunk]
type=peer
defaultuser=1020
secret=supersecret
port=5600 ; nor 5060, 5600
insecure=invite
host=sip.flagonc.com
fromuser=1020
fromdomain=sip.flagonc.com
context=from-siptrunk
```

#### pjsip.conf

```
;--
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
[general]
bindport = 5060
[alice]
qualify = yes
[bob]
qualify = yes
[siptrunk]
defaultuser = 1020
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Non mapped elements end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
--;
[transport-udp]
type = transport
protocol = udp
bind = 0.0.0.0:5060
[reg_sip.flagonc.com]
type = registration
retry_interval = 20
max_retries = 10
contact_user = 9999
expiration = 120
transport = transport-udp
outbound_auth = auth_reg_sip.flagonc.com
client_uri = sip:1020@sip.flagonc.com:5600
server_uri = sip:sip.flagonc.com:5600
[auth_reg_sip.flagonc.com]
type = auth
password = supersecret
username = 1020
[alice]
type = aor
max_contacts = 1
[alice]
type = auth
username = alice
password = #supersecret#
[alice]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = alice
outbound_auth = alice
aors = alice
[bob]
type = aor
max_contacts = 1
[bob]
type = auth
username = bob
password = #supersecret#
[bob]
type = endpoint
context = from-internal
disallow = all
allow = ulaw
direct_media = no
auth = bob
outbound_auth = bob
aors = bob
[siptrunk]
type = aor
contact = sip:1020@sip.flagonc.com:5600
[siptrunk]
type = identify
endpoint = siptrunk
match = sip.flagonc.com
[siptrunk]
type = auth
username = siptrunk
password = supersecret
[siptrunk]
type = endpoint
context = from-siptrunk
disallow = all
allow = ulaw
from_user = 1020
from_domain = sip.flagonc.com
auth = siptrunk
outbound_auth = siptrunk
aors = siptrunk
```

Aunque la conversión parece correcta, podemos ver que algunos elementos como qualify=yes no pueden mapearse directamente. Para corregirlo, debe agregar a la sección aor el comando qualify_frequency=time en segundos. Ejemplo a continuación.

```
[bob]
type = aor
max_contacts = 1
qualify_frequency=15
```

La configuración completa de PJSIP se trata en el capítulo *SIP & PJSIP in depth*, y la documentación oficial en docs.asterisk.org tiene una cobertura completa del canal. En nuestros laboratorios complementarios en voip.school, el laboratorio 5 le permite practicar lo que acaba de aprender.

## Resumen

Este capítulo reunió las tecnologías de canal que son anteriores a las implementaciones puramente VoIP de hoy en día, pero que Asterisk 22 todavía admite. Vio cómo las líneas y teléfonos **analógicos** se conectan a través de interfaces **FXO/FXS** en DAHDI, cómo se aprovisionan los enlaces **TDM digitales** (E1/T1 e ISDN PRI/BRI), y cómo **IAX2** (`chan_iax2`) todavía sirve como un trunk eficiente y amigable con NAT de servidor a servidor, a pesar de que ahora es firmemente un legado. También revisó el controlador retirado **`chan_sip`** y su sintaxis `sip.conf` —que encontrará en sistemas más antiguos pero que ya no existe en Asterisk 22— y trabajó en la migración de dicho sistema a PJSIP con la tabla de mapeo de conceptos y el script `sip_to_pjsip.py`. La regla general: recurra a cualquier cosa en este capítulo solo cuando el hardware real o un sistema heredado existente lo obliguen; todo proyecto nuevo (green-field) debe ser PJSIP sobre IP.

## Cuestionario

1. Con respecto a las dos interfaces analógicas Foreign eXchange, marque las afirmaciones correctas (elija todas las que correspondan):
   - A. Una interfaz FXO se conecta a la central de la PSTN y obtiene el tono de marcado de ella.
   - B. Una interfaz FXS proporciona tono de marcado y energía de llamada a un teléfono analógico estándar, fax o módem.
   - C. Una interfaz FXS es la forma correcta de conectar Asterisk a una línea telefónica.
   - D. Una interfaz FXO también puede conectarse a un puerto de extensión de una PBX heredada.
2. La señalización de supervisión en una línea analógica incluye cuál de las siguientes (elija todas las que correspondan):
   - A. On-hook
   - B. Off-hook
   - C. Ringing
   - D. DTMF
3. El eco, los chasquidos y el ruido en una tarjeta analógica DAHDI son causados la mayoría de las veces por:
   - A. La forma en que se compiló Asterisk
   - B. Conflictos de interrupciones PCI
   - C. Un codec SIP incorrecto
   - D. Un dialplan faltante
4. Para una facturación precisa en canales analógicos, debe detectar exactamente cuándo responde el extremo remoto. ¿Qué función activa en Asterisk (y solicita a la compañía telefónica) para hacer esto?
   - A. Answer reversal
   - B. Billing reversal
   - C. Polarity reversal
   - D. Dial-tone generation
5. El hardware DAHDI es independiente de Asterisk: la tarjeta física se configura en `/etc/dahdi/system.conf`, mientras que `chan_dahdi.conf` define los canales de Asterisk, no el hardware en sí.
   - A. Verdadero
   - B. Falso
6. Con respecto a la capacidad y señalización de troncales digitales, marque las afirmaciones correctas (elija todas las que correspondan):
   - A. Una troncal E1 transporta 30 canales de voz y una troncal T1 transporta 24.
   - B. Una ISDN PRI utiliza 30B+D en una E1 y 23B+D en una T1.
   - C. ISDN es un ejemplo de señalización CCS, mientras que MFC/R2 es un ejemplo de señalización CAS.
   - D. T1 es la troncal digital más utilizada en Europa y América Latina.
7. ¿Qué utilidad detecta automáticamente las tarjetas DAHDI y genera `/etc/dahdi/system.conf` y `dahdi-channels.conf`?
   - A. dahdi_generator
   - B. dahdi_genconf
   - C. dahdi_cfg
   - D. generate_dahdi
8. Al migrar una `sip.conf` `[friend]` heredada a PJSIP, un solo bloque debe dividirse en varios objetos. ¿Qué conjunto de objetos `type=` de PJSIP reemplaza normalmente a un `[friend]` de registro?
   - A. `type=endpoint`, `type=aor` y `type=auth`
   - B. `type=peer` y `type=user`
   - C. Solo `type=sip`
   - D. `type=channel` y `type=device`
9. ¿Cuál es la principal ventaja práctica de utilizar el modo troncal IAX2 entre dos servidores Asterisk?
   - A. Cifra cada llamada con TLS de forma predeterminada
   - B. Transporta varias llamadas bajo un solo encabezado, ahorrando ancho de banda
   - C. Elimina la necesidad de cualquier codec
   - D. Asigna un puerto UDP separado por llamada para una mejor calidad
10. Las claves RSA pueden utilizarse para la autenticación IAX2. ¿Qué clave debe mantener en secreto y cuál debe entregar al otro servidor?
    - A. Mantenga la clave pública en secreto; comparta la clave privada
    - B. Mantenga la clave privada en secreto; comparta la clave pública
    - C. Mantenga la clave compartida en secreto; comparta la clave privada
    - D. Ambas claves deben ser compartidas

**Respuestas:** 1 — A, B, D · 2 — A, B, C · 3 — B · 4 — C · 5 — A · 6 — A, B, C · 7 — B · 8 — A · 9 — B · 10 — B
