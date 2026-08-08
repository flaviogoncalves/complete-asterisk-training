# Instalación de Asterisk 22

En el primer capítulo, aprendimos un poco sobre cómo Asterisk es útil en el entorno de telefonía. En este capítulo, cubriremos cómo descargar e instalar Asterisk. Antes de comenzar, es esencial aprender cómo compilarlo e instalarlo. El proceso de compilación puede parecer extraño para los usuarios tradicionales de Microsoft™ Windows™, pero es bastante común en el entorno Linux™. Uno puede obtener un código optimizado para su hardware al compilar Asterisk, que es lo que haremos aquí. Asterisk funciona en varios sistemas operativos, pero mantendremos las cosas sencillas y usaremos solo uno: Linux. Usamos **Ubuntu 24.04 LTS** porque sus dependencias son fáciles de instalar y es una distribución de servidor estable, bien soportada y con un bajo consumo de recursos. Si prefiere otra distribución, ajuste los nombres de los paquetes según corresponda.

Esta edición se enfoca en **Asterisk 22 LTS** (lanzada el 2024-10-16; soporte completo hasta el 2028-10-16, correcciones de seguridad hasta el 2029-10-16). Asterisk 22 es la versión actual de soporte a largo plazo. Tenga en cuenta que Digium fue adquirida por **Sangoma** en 2018, y Asterisk ahora es patrocinado por Sangoma; las referencias a "Digium" a lo largo de este capítulo se refieren a la marca heredada para hardware histórico.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Determinar los requisitos de hardware para Asterisk;
- Instalar Linux con las dependencias requeridas;
- Descargar una versión estable a través de HTTPS;
- Compilar Asterisk; y
- Aprender cómo iniciar Asterisk durante el arranque del sistema.

## Requisitos mínimos de hardware

Asterisk no necesita mucho hardware para ejecutarse; sin embargo, existen algunos consejos para elegir el mejor hardware según sus necesidades. Debe tomar en consideración los siguientes factores principales al elegir su hardware:

- Número total de usuarios registrados. Defina cuántos registros por segundo necesita soportar.
- Número total de llamadas simultáneas. Defina cuántas conversaciones de red necesita procesar en el adaptador de red y el puente en el servidor Asterisk.
- Qué codecs necesita soportar. Los codecs de alta complejidad requerirán mucha potencia de CPU/FPU en su servidor; iLBC, por ejemplo, fue medido por su creador (Global IP Sound) en aproximadamente 18 MIPS por canal para tramas de 30 ms (y alrededor de 15 MIPS para tramas de 20 ms) en un DSP TI C54x.
- Cancelación de eco. La cancelación de eco puede consumir mucha CPU/FPU; en algunos casos, debería elegir cancelación de eco por hardware utilizando DSPs en la tarjeta de interfaz de telefonía.
- Disponibilidad. Utilice RAID1 o 5 para aumentar la disponibilidad. Recuerde, Asterisk es una aplicación 24x7.

El componente principal para un servidor Asterisk es el adaptador de red. Se recomienda un buen adaptador de red para servidores. La CPU es importante cuando necesita soportar codecs de alta complejidad como g.729 e iLBC y cancelación de eco. Puede optar por delegar esto a DSPs dedicados: Sangoma (anteriormente Digium) proporciona una tarjeta DSP llamada TC400B capaz de soportar 120 llamadas simultáneas en G.729.

La mejor práctica es elegir una computadora nueva, de clase servidor, de un fabricante reconocido. Para saber exactamente cuántas llamadas simultáneas o cuántos usuarios registrados puede soportar una máquina específica, debe probar este hardware con una herramienta de prueba de estrés como SIPP (http://sipp.sourceforge.net). Algunos fabricantes de hardware como Xorcom (http://www.xorcom.com) publican sus resultados en su sitio web.

Nota: Algunas aplicaciones de Asterisk, como ConfBridge y música en espera, necesitan una fuente de temporización interna. En Linux moderno, esto es proporcionado automáticamente por el módulo integrado `res_timing_timerfd`; no se requiere hardware de telefonía. (El antiguo temporizador de software `dahdi_dummy` ya no existe; su funcionalidad fue integrada en el módulo principal del kernel `dahdi` en DAHDI Linux 2.3.0.) Puede confirmar el temporizador activo con el comando de CLI `timing test`.

### Configuración de hardware

El hardware de Asterisk no necesita ser sofisticado. No necesita una tarjeta de video costosa ni numerosos periféricos. Algunos consejos sobre la configuración de hardware:

- Deshabilite los puertos USB, seriales y paralelos no utilizados para evitar el consumo de interrupciones innecesarias.
- Una tarjeta de interfaz de red robusta es esencial.
- Tenga especial cuidado si está utilizando tarjetas de interfaz de telefonía. Algunas tarjetas utilizan un bus PCI de 3.3 voltios, y no es fácil encontrar placas base para ellas. En estos días, PCI express es más fácil de encontrar.
- Preste mucha atención al disco duro; una PBX suele trabajar en un régimen 24x7, mientras que las computadoras de escritorio trabajan 8x5. No utilice hardware de escritorio para una PBX, generalmente el disco duro falla antes del primer año. Mi recomendación es utilizar una máquina servidor o un dispositivo diseñado para ejecutar aplicaciones 24x7.

### Compartición de IRQ (solo tarjetas PCI heredadas)

Esta preocupación se aplica **solo** si instala tarjetas de telefonía físicas PCI/PCI-Express (hardware DAHDI). Dichas tarjetas generan un gran número de interrupciones y, en sistemas antiguos de una sola CPU, compartir una línea IRQ con otro dispositivo podría agotar al controlador y degradar la calidad de la voz. Si utiliza tarjetas de telefonía, dedique la máquina a Asterisk, deshabilite cualquier dispositivo integrado no utilizado en el BIOS y verifique las interrupciones asignadas con `cat /proc/interrupts`. Los servidores modernos multinúcleo que utilizan interrupciones MSI/MSI-X hacen que compartir IRQ no sea un problema en la práctica, y un despliegue puramente VoIP (sin tarjetas) no necesita preocuparse por esto en absoluto.

## Elección de una distribución de Linux

Asterisk fue desarrollado inicialmente para ejecutarse en Linux. Sin embargo, también puede ejecutarse en BSD Unix o macOS. Si es nuevo en Asterisk, intente usar Linux primero, ya que es mucho más fácil. Asterisk apunta oficialmente a la familia RHEL (CentOS/RHEL/Fedora), Ubuntu y Debian. Buenas opciones prácticas hoy en día son **Debian 12**, **Ubuntu 22.04 LTS / 24.04 LTS** y **Rocky Linux 9 / AlmaLinux 9** — CentOS Linux ha llegado al final de su vida útil, así que prefiera Rocky o AlmaLinux en sistemas de la familia RHEL. Para este libro usaré Ubuntu 24.04 LTS. Descargue la imagen de servidor de la versión puntual más reciente de 24.04 desde el directorio oficial de lanzamientos a continuación (el nombre de archivo exacto incluye la versión puntual actual, por ejemplo, `ubuntu-24.04.4-live-server-amd64.iso`):

```
https://releases.ubuntu.com/24.04/
```

### Preparación de Linux para Asterisk

Antes de compilar Asterisk, necesita un sistema Linux funcional con los paquetes de compilación instalados. Instale **Ubuntu 24.04 LTS Server** en una máquina virtual o en un equipo dedicado (use la imagen de 64 bits; todo en este libro es de 64 bits, aunque Asterisk en sí todavía admite x86 de 32 bits). Utilizamos VirtualBox para este entrenamiento; puede descargar la imagen desde <https://releases.ubuntu.com/24.04>. La instalación de Linux en sí está fuera del alcance de este libro; el conocimiento básico de Linux es un prerrequisito. Con Linux instalado, agregará las dependencias de compilación de Asterisk (vea *Instalación de dependencias* a continuación) y luego compilará Asterisk.

## Instalación de Linux para Asterisk

Instale Linux como de costumbre, sin un escritorio gráfico. Durante la instalación, habilite también un agente de transferencia de correo (usamos **exim4**); Asterisk lo necesitará para enviar notificaciones de voicemail-to-email más adelante en este libro. **Precaución:** instalar un sistema operativo borra el disco de destino. Si realiza la instalación en hardware físico, haga primero una copia de seguridad de sus datos; instalar en una máquina virtual deja su host intacto. Inicie el instalador desde la ISO de Ubuntu Server (o la unidad óptica virtual de la VM) y responda a las indicaciones; la mayoría son sencillas.

## Instalación de dependencias

Para instalar Asterisk y DAHDI debe instalar muchas dependencias de software. La forma recomendada de hacer esto en Asterisk 22 es utilizar el script que se incluye con el árbol de fuentes, el cual conoce los nombres de paquete correctos para cada distribución soportada. Después de descargar y extraer el código fuente de Asterisk (vea "Compilando Asterisk" a continuación), ejecute:

```
cd /usr/src/asterisk-22.x.y
./contrib/scripts/install_prereq install
```

1. Inicie sesión como root (o utilice `sudo`).
2. Si prefiere instalar las dependencias manualmente en un sistema Debian/Ubuntu, la lista de paquetes equivalente es:

```
apt-get install build-essential git wget openssl libssl-dev libxml2-dev \
  libsqlite3-dev uuid-dev libjansson-dev libedit-dev libncurses-dev \
  libcurl4-openssl-dev pkg-config autoconf-archive
```

Tenga en cuenta que el código fuente de Asterisk ahora se aloja en Git, por lo que `subversion` ya no es necesario, y las versiones modernas de Debian/Ubuntu incluyen `libncurses-dev` en lugar de la versión `libncurses5-dev`. Prefiera `./contrib/scripts/install_prereq install` sobre una lista mantenida manualmente, ya que el script siempre rastrea los nombres de paquete correctos para su distribución.

### DAHDI

DAHDI (Digium/Sangoma Asterisk Hardware Device Interface) es la arquitectura de controladores para tarjetas analógicas y digitales. Antes de instalar Asterisk es importante instalar DAHDI si planea utilizar interfaces analógicas o digitales. DAHDI todavía existe para tarjetas de telefonía analógica/digital, pero es cada vez más específico; la mayoría de las implementaciones modernas son puramente VoIP y pueden omitir esta sección por completo. Instale DAHDI solo si tiene hardware de interfaz de telefonía física. Obtenga los archivos fuente utilizando:

```
wget https://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-current.tar.gz
```

Descomprima los archivos utilizando:

```
tar -xzvf dahdi-linux-complete-current.tar.gz
```

### Compilación de controladores DAHDI

Necesitará compilar los módulos de DAHDI. Los comandos ./configure y make menuselect fueron introducidos hace varios años. Este último le permite seleccionar qué utilidades y módulos construir. Los siguientes comandos realizarán esto:

```
cd dahdi-linux-complete-X.Y.Z+X.Y.Z/linux   # adapt to the version downloaded
make
make install
cd ../tools
autoreconf -i
./configure
make
make install
```

make install-config DAHDI ha sido configurado. Si tiene algún hardware DAHDI, ahora se recomienda editar /etc/dahdi/modules para cargar soporte solo para el hardware DAHDI instalado en este sistema. De forma predeterminada, el soporte para todo el hardware DAHDI se carga al iniciar DAHDI. Creo que el hardware DAHDI que tiene en su sistema es: usb:004/002 xpp_usb- e4e4:1150 Astribank-multi no-firmware Esta pantalla (arriba) le pide que cambie el archivo /etc/dahdi/modules para cargar solo los controladores requeridos para su configuración específica y mostrar el hardware detectado. Edite el archivo /etc/dahdi/modules y cargue solo el hardware requerido. En mi caso, estaba utilizando una máquina de prueba con un Xorcom Astribank 6FXS y 2FXO. El archivo se muestra a continuación.

```
# Contains the list of modules to be loaded / unloaded by /etc/init.d/dahdi.
#
# NOTE:  Please add/edit /etc/modprobe.d/dahdi or /etc/modprobe.conf if you
#        would like to add any module parameters.
#
# Format of this file: list of modules, each in its own line.
# Anything after a '#' is ignore, likewise trailing and leading
# whitespaces and empty lines.
# Digium TE205P/TE207P/TE210P/TE212P: PCI dual-port T1/E1/J1
# Digium TE405P/TE407P/TE410P/TE412P: PCI quad-port T1/E1/J1
# Digium TE220: PCI-Express dual-port T1/E1/J1
# Digium TE420: PCI-Express quad-port T1/E1/J1
#wct4xxp
# Digium TE120P: PCI single-port T1/E1/J1
# Digium TE121: PCI-Express single-port T1/E1/J1
# Digium TE122: PCI single-port T1/E1/J1
#wcte12xp
# Digium T100P: PCI single-port T1
# Digium E100P: PCI single-port E1
#wct1xxp
# Digium TE110P: PCI single-port T1/E1/J1
#wcte11xp
# Digium TDM2400P/AEX2400: up to 24 analog ports
# Digium TDM800P/AEX800: up to 8 analog ports
# Digium TDM410P/AEX410: up to 4 analog ports
#wctdm24xxp
# X100P - Single port FXO interface
# X101P - Single port FXO interface
#wcfxo
# Digium TDM400P: up to 4 analog ports
#wctdm
# Xorcom Astribank Devices
xpp_usb
```

Reinicie su computadora y verifique la carga correcta de los controladores.

## ¿Qué versión elegir?

Como regla general, debe utilizar la versión que cuente con las funciones requeridas. Asterisk sigue un modelo de lanzamiento que alterna entre versiones LTS (soporte a largo plazo) y versiones estándar. Al momento de esta edición, **Asterisk 22 es la versión LTS actual** (lanzada en octubre de 2024; la versión de punto más reciente es 22.10.0), lo que la convierte en la mejor opción para elegir ahora. Asterisk 20 es la versión LTS anterior, y la versión 16 (utilizada en la primera edición) ha llegado al final de su vida útil. Para sistemas en producción, elija siempre una versión LTS.

## Compilando Asterisk

Si usted ha compilado software anteriormente, compilar Asterisk será una tarea sencilla. Ejecute los siguientes comandos para compilar e instalar Asterisk. Recuerde, puede elegir qué aplicaciones y módulos construir utilizando make menuselect. Paso 1: Descargar el código fuente

```
cd /usr/src
wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -xzvf asterisk-22-current.tar.gz
```

Paso 2: Instalar los prerrequisitos de compilación (vea "Instalando dependencias" arriba)

```
cd asterisk-22.x.y (adapt to the version downloaded)
./contrib/scripts/install_prereq install
```

Paso 3: Configurar la compilación

```
./configure
```

Paso 4: Seleccionar los módulos a construir

```
make menuselect
```

Utilice make menuselect para instalar solo los módulos necesarios. En Asterisk 22 el canal SIP es **chan_pjsip** (construido por defecto); el antiguo **chan_sip** fue eliminado en Asterisk 21 y ya no existe. El *pass-through* de Opus funciona de inmediato (el módulo `res_format_attr_opus` incluido en el árbol maneja la negociación SDP), pero el módulo de transcodificación **codec_opus** sigue siendo un binario externo de código cerrado de Sangoma/Digium; seleccionarlo en menuselect lo descarga desde los servidores de Digium. El binario es gratuito. Vea "Seleccionando módulos con menuselect" a continuación para más detalles.

Paso 5: Construir e instalar Asterisk, luego crear la configuración por defecto y los archivos de ejemplo

```
make
make install
make samples
make config
ldconfig
```

`make install` instala los binarios y módulos, `make samples` escribe los archivos de configuración de ejemplo en `/etc/asterisk`, `make config` instala el script de inicio SysV para su distribución detectada (por ejemplo, `/etc/init.d/asterisk` en Debian/Ubuntu), y `ldconfig` refresca la caché de bibliotecas compartidas. Una unidad de systemd también se incluye en el árbol de fuentes en `contrib/systemd/asterisk.service`, pero `make config` no la instala automáticamente; cópiela usted mismo en su lugar si prefiere ejecutar Asterisk bajo systemd (vea abajo).

### Seleccionando módulos con menuselect

`make menuselect` abre un menú basado en texto donde usted elige exactamente qué aplicaciones, codecs, canales y recursos construir. Algunas notas específicas para Asterisk 22:

- **chan_pjsip** (bajo *Channel Drivers*) es el canal SIP moderno y está habilitado por defecto; es el único canal SIP en Asterisk 22.
- **codec_opus** (bajo *Codec Translators*) es un módulo **externo** (su entrada en menuselect dice "Download the Opus codec from Digium"); habilitarlo hace que `make` obtenga el binario gratuito de código cerrado de Sangoma/Digium. El *pass-through* de Opus por sí mismo no necesita ningún módulo adicional. El módulo **codec_g729** de Sangoma también está disponible; el binario es gratuito para descargar, pero la transcodificación legal de G.729 requiere una licencia comprada por canal.
- Seleccione los formatos de sonido y los idiomas que desee en los menús *Core Sound Packages*, *Music On Hold File Packages* y *Extras Sound Packages*; todo lo que marque allí se descarga e instala automáticamente durante `make install`.

Después de realizar sus selecciones, elija **Save & Exit** y continúe con `make`.

## Cómo iniciar y detener Asterisk

Con esta configuración mínima, es posible iniciar Asterisk correctamente. Para fines de aprendizaje y depuración, puede iniciar Asterisk en primer plano conectado a la consola:

```
/usr/sbin/asterisk -vvvgc
```

Utilice el comando de CLI `core stop now` para apagar Asterisk:

```
*CLI> core stop now
```

### Cómo iniciar Asterisk con systemd

En las distribuciones de Linux modernas (Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9), el administrador de servicios del sistema es **systemd**. Asterisk incluye una unidad de systemd en `contrib/systemd/asterisk.service` dentro del árbol de fuentes; cópiela a `/etc/systemd/system/asterisk.service` y ejecute `systemctl daemon-reload`. Una vez instalado, la forma recomendada de ejecutar Asterisk en producción es a través de `systemctl`:

```
systemctl start asterisk      # start the service
systemctl stop asterisk       # stop the service
systemctl restart asterisk    # restart the service
systemctl status asterisk     # show current status
systemctl enable asterisk     # start automatically at boot
```

Una vez que Asterisk se esté ejecutando como un servicio, conéctese a su CLI con `asterisk -r` (conectar) o `asterisk -rvvv` (conectar con salida detallada).

En sistemas más antiguos, Asterisk se iniciaba mediante el script de inicio heredado SysV (`/etc/init.d/asterisk`) y el contenedor **safe_asterisk**, el cual reiniciaba Asterisk automáticamente si este fallaba. Con systemd, el reinicio automático se gestiona mediante la directiva `Restart=` del archivo de unidad, por lo que `safe_asterisk` generalmente ya no es necesario. El enfoque heredado de init/`safe_asterisk` todavía funciona, pero está obsoleto en distribuciones basadas en systemd.

### Opciones de tiempo de ejecución de Asterisk

El proceso de inicio de Asterisk es muy sencillo. Si Asterisk se ejecuta sin ningún parámetro, se lanza como un demonio.

```
/sbin/asterisk
```

Puede acceder a la consola de Asterisk ejecutando el siguiente comando. Tenga en cuenta que se puede ejecutar más de un proceso de consola al mismo tiempo.

```
/sbin/asterisk -r
```

### Opciones de tiempo de ejecución disponibles para Asterisk

Puede mostrar las opciones de tiempo de ejecución disponibles utilizando `asterisk -h`

```text
sipast:/usr/src/asterisk-22.x.y# asterisk -h
Asterisk 22.10.0, Copyright (C) 1999 - 2025, Sangoma Technologies Corporation and others.
Usage: asterisk [OPTIONS]
Valid Options:
   -V              Display version number and exit
   -C <configfile> Use an alternate configuration file
   -G <group>      Run as a group other than the caller
   -U <user>       Run as a user other than the caller
   -c              Provide console CLI
   -d              Increase debugging (multiple d's = more debugging)
   -f              Do not fork
   -F              Always fork
   -g              Dump core in case of a crash
   -h              This help screen
   -i              Initialize crypto keys at startup
   -L <load>       Limit the maximum load average before rejecting new calls
   -M <value>      Limit the maximum number of calls to the specified value
   -m              Mute debugging and console output on the console
   -n              Disable console colorization. Can be used only at startup.
   -p              Run as pseudo-realtime thread
   -q              Quiet mode (suppress output)
   -r              Connect to Asterisk on this machine
   -R              Same as -r, except attempt to reconnect if disconnected
   -s <socket>     Connect to Asterisk via socket <socket> (only valid with -r)
   -t              Record soundfiles in /var/tmp and move them where they
                   belong after they are done
   -T              Display the time in [Mmm dd hh:mm:ss] format for each line
                   of output to the CLI. Cannot be used with remote console mode.
   -v              Increase verbosity (multiple v's = more verbose)
   -x <cmd>        Execute command <cmd> (implies -r)
   -X              Enable use of #exec in asterisk.conf
   -W              Adjust terminal colors to compensate for a light background
```

## Directorios de instalación

Asterisk se instala en varios directorios, los cuales pueden modificarse en el archivo asterisk.conf. Para propósitos de entrenamiento, yo cambiaría el verbose de 3 a 15; para producción, manténgalo en 3. Las opciones `maxcalls` y `maxload` son buenas opciones para proteger su sistema de una sobrecarga.

### asterisk.conf (extracto)

La sección `[directories]` define dónde guarda Asterisk su configuración, módulos, datos, spool y registros (logs):

```
[directories](!) ; remove the (!) to enable this
astetcdir => /etc/asterisk
astmoddir => /usr/lib/asterisk/modules
astvarlibdir => /var/lib/asterisk
astdbdir => /var/lib/asterisk
astkeydir => /var/lib/asterisk
astdatadir => /var/lib/asterisk
astagidir => /var/lib/asterisk/agi-bin
astspooldir => /var/spool/asterisk
astrundir => /var/run/asterisk
astlogdir => /var/log/asterisk
astsbindir => /usr/sbin
```

La sección `[options]` contiene el ajuste de tiempo de ejecución. Las opciones más útiles que debe conocer se muestran a continuación (quite el comentario para habilitarlas); el archivo viene con muchas más, cada una documentada mediante un comentario en línea:

```
[options]
;verbose = 3      ; Console verbosity (raise to 15 for training, keep 3 in production)
;debug = 3        ; Debug level
;maxcalls = 10    ; Maximum number of simultaneous calls allowed
;maxload = 0.9    ; Stop accepting new calls when load average exceeds this
;maxfiles = 1000  ; Maximum number of open files
;runuser = asterisk   ; The user to run as
;rungroup = asterisk  ; The group to run as
```

## Archivos de registro y rotación de registros

Asterisk PBX registra sus mensajes en `/var/log/asterisk`. El registro es controlado por `logger.conf`. La parte clave es la sección `[logfiles]`, donde cada línea define un canal de registro y los niveles de mensaje que captura (extracto):

```ini
; logger.conf (excerpt)
[general]
;dateformat = %F %T.%3q          ; ISO 8601 timestamps, with milliseconds

[logfiles]
; <logger_name> => [formatter]<levels>
console  => notice,warning,error
messages => notice,warning,error
full     => notice,warning,error,verbose,dtmf,fax
security => security              ; PJSIP/auth security events (used by Fail2Ban)
```

Después de editar, aplique el cambio con `logger reload` y confirme los canales con `logger show channels`:

```text
*CLI> logger show channels
Channel                       Type   Formatter  Status   Configuration
/var/log/asterisk/security    File   default    Enabled  - SECURITY
/var/log/asterisk/full        File   default    Enabled  - NOTICE WARNING ERROR VERBOSE DTMF FAX
/var/log/asterisk/messages    File   default    Enabled  - NOTICE WARNING ERROR
```

Los archivos de registro pueden crecer rápidamente, así que rótelos con el demonio del sistema `logrotate` — agregue un archivo bajo `/etc/logrotate.d/`:

```text
/var/log/asterisk/messages /var/log/asterisk/*log {
   missingok
   rotate 5
   weekly
   create 0640 asterisk asterisk
   postrotate
       /usr/sbin/asterisk -rx 'logger reload'
   endscript
}
```

Se puede obtener más información sobre logrotate utilizando:

```
#man logrotate
```

## Desinstalación de Asterisk

Para desinstalar Asterisk, utilice:

```
make uninstall
```

Para desinstalar Asterisk y todos los archivos de configuración, utilice:

```
make uninstall-all
```

## Notas de instalación de Asterisk

Esta sección proporcionará algunos consejos sobre problemas a considerar antes de instalar Asterisk.

### Sistemas de producción

Si Asterisk se instala en un entorno de producción, debe prestar atención al diseño del sistema. Un servidor debe optimizarse de tal manera que los sistemas de telefonía tengan prioridad sobre otros procesos del sistema. Asterisk no debe ejecutarse junto con software que consuma muchos recursos del procesador, como X-Windows. Si necesita ejecutar procesos que consuman mucha CPU (por ejemplo, una base de datos enorme), utilice un servidor independiente. En términos generales, Asterisk es susceptible a las variaciones en el rendimiento del hardware. Por lo tanto, intente utilizar Asterisk en un entorno de hardware que no requiera más del 40% de utilización de la CPU.

### Consejos de red

Si planea utilizar teléfonos IP, es importante que preste atención a su red. Los protocolos de voz son muy buenos y resistentes a la latencia e incluso al jitter; sin embargo, si utiliza una red de área local mal configurada, la calidad de la voz se verá afectada. Solo es posible garantizar una buena calidad de voz utilizando calidad de servicio (QoS) en switches y routers. La voz en una red de área local tiende a ser buena, pero incluso en un entorno LAN, si tiene hubs de 10 Mbps con demasiadas colisiones, terminará teniendo una voz distorsionada o de mala calidad. Siga estas recomendaciones para garantizar la mejor calidad de voz posible:

- Utilice QoS de extremo a extremo si es posible o económicamente viable. Con QoS de extremo a extremo, la calidad de la voz es perfecta. ¡No hay excusas!
- Evite el uso de hubs de 10/100 Mbps para voz en un entorno de producción. Las colisiones pueden imponer jitter en la red. Se prefieren los 10/100 Mbps full duplex porque no ocurren colisiones.
- Utilice VLANs para separar las transmisiones innecesarias de la red de voz. No querrá que un virus destruya su red de voz con transmisiones ARP.
- Eduque a los usuarios sobre las expectativas en una red de voz. Sin QoS, no afirme que la voz será perfecta, ya que en la mayoría de los casos no lo será. La mayoría de las veces se logrará una calidad de voz similar a la de un teléfono móvil. Utilice teléfonos de calidad, ya que los problemas con el firmware y el diseño del hardware son comunes.

## Resumen

En este capítulo, usted ha aprendido sobre los requisitos mínimos de hardware, así como también cómo descargar, instalar y compilar Asterisk. Asterisk debe ejecutarse con un usuario que no sea root por razones de seguridad. Usted debe verificar su entorno de red antes de iniciar el entorno de producción.

## Cuestionario

1. En Asterisk 22, ¿qué controlador de canal proporciona soporte SIP y qué sucedió con el antiguo `chan_sip`?
   - A. `chan_sip` sigue siendo el predeterminado; `chan_pjsip` es opcional.
   - B. `chan_pjsip` es el canal SIP predeterminado; `chan_sip` fue eliminado en Asterisk 21 y ya no existe.
   - C. Ambos se compilan de forma predeterminada y usted elige entre ellos durante la ejecución.
   - D. El soporte SIP fue eliminado por completo en favor de IAX2.
2. Las tarjetas de interfaz de telefonía para Asterisk generalmente tienen procesadores de señales digitales (DSPs) integrados, por lo que no requieren mucha CPU de la PC.
   - A. Verdadero
   - B. Falso
3. Si desea una calidad de voz perfecta, necesita implementar calidad de servicio (QoS) de extremo a extremo.
   - A. Verdadero
   - B. Falso
4. Siempre debe elegir la versión más reciente de Asterisk, ya que es la más estable.
   - A. Verdadero
   - B. Falso
5. ¿Cuál es la forma recomendada de instalar las dependencias de compilación para Asterisk 22?
6. Si no tiene una tarjeta de interfaz TDM, aún tendrá una fuente de temporización interna para la sincronización, proporcionada por el módulo `res_timing_timerfd` en Linux. Esta temporización es utilizada por aplicaciones como ________ y ________.
7. Al instalar Asterisk, es mejor dejar fuera los entornos de escritorio como GNOME o KDE, porque las interfaces gráficas consumen ciclos de CPU.
   - A. Verdadero
   - B. Falso
8. Los archivos de configuración de Asterisk se encuentran en el directorio ________.
9. Para instalar los archivos de configuración de ejemplo de Asterisk, escriba el comando: ________
10. ¿Por qué es importante ejecutar Asterisk como un usuario que no sea root?

**Respuestas:** 1 — B · 2 — B · 3 — A · 4 — B · 5 — Ejecute `./contrib/scripts/install_prereq install` desde el árbol de fuentes de Asterisk extraído · 6 — ConfBridge y Music on Hold · 7 — A · 8 — `/etc/asterisk` · 9 — `make samples` · 10 — Seguridad (limita el daño si Asterisk es comprometido)
