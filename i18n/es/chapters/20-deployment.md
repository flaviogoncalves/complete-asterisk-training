# Despliegue, monitoreo y escalabilidad

Hacer que Asterisk responda una llamada en un laboratorio es una cosa; ejecutarlo como un servicio que sobreviva a fallos, reinicios, actualizaciones y atacantes —y que además puedas observar, respaldar y hacer crecer— es otra muy distinta. Este capítulo trata sobre todo lo que sucede *después* de que el dialplan funciona. Comenzamos con el supervisor que mantiene a Asterisk activo (systemd), pasamos a empaquetarlo en un contenedor (usando el laboratorio Docker del propio libro como ejemplo práctico), luego cubrimos la gestión de configuración y respaldos, monitoreo y observabilidad, y finalmente los patrones a los que recurres cuando un solo servidor no es suficiente: alta disponibilidad y escalabilidad, además de las realidades del alojamiento en la nube.

Todo lo mostrado está verificado contra el laboratorio de Asterisk 22 del libro en `lab/` — el mismo contenedor sobre el que has estado trabajando a lo largo del libro.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Ejecutar Asterisk 22 de manera confiable bajo systemd, como un usuario sin privilegios de root, con reinicio automático
- Contenerizar Asterisk con Docker y comprender las compensaciones de red
- Mantener `/etc/asterisk` en control de versiones y respaldar el estado correcto
- Monitorear un sistema en ejecución a través de la CLI, CDR/CEL, AMI/ARI y métricas
- Aplicar patrones de alta disponibilidad activo/en espera y escalado horizontal
- Alojar Asterisk en la nube de forma segura detrás de NAT y un firewall

## Ejecución de Asterisk bajo systemd

En todas las distribuciones de Linux actuales —Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9— el administrador de servicios es **systemd**. El capítulo de instalación mostró que el paso `make config` (ejecutado durante `make install`) instala un script de inicio de la distribución (`/etc/init.d/asterisk` en Debian, un script `rc.d` en RedHat), el cual systemd envuelve automáticamente como un servicio; Asterisk también incluye una unidad nativa de systemd en `contrib/systemd/asterisk.service` que puede instalar en su lugar para un control más preciso.
De cualquier manera, systemd es la forma soportada y recomendada para ejecutar Asterisk en producción. Consulte *Installing Asterisk 22* para la compilación en sí; aquí nos enfocamos en lo que el servicio le ofrece y cómo operarlo.

### La unidad de servicio y su ciclo de vida

Una vez que `make config` ha instalado el servicio, el ciclo de vida es el habitual de systemd:

```
systemctl enable asterisk     # start automatically at boot
systemctl start asterisk      # start now
systemctl status asterisk     # is it running? recent log lines
systemctl restart asterisk    # full stop + start
systemctl stop asterisk       # stop
journalctl -u asterisk        # service logs via the journal
```

Algunas notas operativas:

- **`restart` frente a una recarga elegante.** `systemctl restart` termina el proceso y desconecta todas las llamadas. Para cambios de configuración, casi nunca querrá hacer eso; utilice la CLI de Asterisk en su lugar: `asterisk -rx 'core reload'` (o una recarga específica de un módulo como `pjsip reload`). Reserve `systemctl restart` para actualizaciones o un proceso bloqueado.
- **Conectarse al daemon en ejecución.** Con Asterisk ejecutándose como un servicio, abra su consola con `asterisk -r` (o `asterisk -rvvv` para una salida detallada). Esto se conecta al daemon que ya está en ejecución a través de su socket de control; no inicia una segunda copia.

### `Restart=` reemplaza a safe_asterisk

Históricamente, Asterisk se iniciaba a través del contenedor **safe_asterisk**, un script de shell que reiniciaba Asterisk si este fallaba. Bajo systemd, esa tarea pertenece a la directiva `Restart=` de la unidad; systemd detecta la salida del proceso y lo reinicia, con un tiempo de espera controlado por `RestartSec=` y protección contra bucles de fallos mediante `StartLimitIntervalSec=`/`StartLimitBurst=`. Por lo tanto, en un host con systemd, **safe_asterisk queda obsoleto** y generalmente es innecesario. Si su unidad instalada no lo configura, un archivo de anulación (drop-in) es la forma limpia de añadir el reinicio tras fallos sin editar el archivo empaquetado:

```
# /etc/systemd/system/asterisk.service.d/override.conf
[Service]
Restart=always
RestartSec=2
```

Aplíquelo con `systemctl daemon-reload && systemctl restart asterisk`. Usar un archivo de anulación (en lugar de editar la unidad instalada) significa que una futura `make config` no sobrescribirá su cambio.

### Ejecución como usuario no root

Asterisk no debe ejecutarse como root en producción; un error de código remoto en un proceso que se ejecuta como root supone un compromiso total del host, mientras que el mismo error en un proceso sin privilegios queda contenido. Existen dos lugares complementarios donde esto se aplica:

- **La unidad / asterisk.conf.** La unidad empaquetada normalmente ejecuta Asterisk como el usuario y grupo `asterisk`. También puede (o en su lugar) configurar `runuser` y `rungroup` en la sección `[options]` de `asterisk.conf`, lo cual el daemon respeta cuando reduce sus privilegios después de realizar el binding:

  ```
  [options]
  runuser = asterisk
  rungroup = asterisk
  ```

- **Propiedad de archivos.** Los directorios de tiempo de ejecución deben ser escribibles por ese usuario. Después de crear la cuenta, asegúrese de la propiedad:

  ```
  chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk \
        /var/spool/asterisk /var/run/asterisk /etc/asterisk
  ```

Debido a que SIP (5060) y RTP (10000+) son puertos altos, Asterisk **no** necesita privilegios de root para enlazarlos; solo los puertos privilegiados tipo puerto 25 lo requerirían, los cuales Asterisk no utiliza. Por lo tanto, la ejecución sin privilegios es gratuita. (El capítulo de Seguridad amplía por qué esto es importante; consulte *Asterisk Security*.)

## Containerización de Asterisk

Un contenedor empaqueta Asterisk y sus dependencias exactas en una imagen inmutable, de modo que lo que usted prueba es, byte por byte, lo que usted despliega. El compromiso es el contenido multimedia en tiempo real: un servidor SIP es sensible a la latencia y necesita un rango amplio y predecible de puertos UDP accesibles desde el exterior, y la red de contenedores puede ser un obstáculo. El resto de esta sección recorre el laboratorio del propio libro — `lab/Dockerfile` y `lab/docker-compose.yml` — como un ejemplo concreto y funcional, y luego explica la trampa en la que todos caen: RTP y la red en puente (bridged networking).

### La imagen: compilando Asterisk desde el código fuente

El `Dockerfile` del laboratorio compila Asterisk 22 desde el código fuente en Debian 12. Vale la pena leer su estructura incluso si nunca escribe una usted mismo:

```dockerfile
FROM debian:12-slim

ARG ASTERISK_VERSION=22.10.0
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential wget ca-certificates pkg-config \
        libedit-dev libxml2-dev libsqlite3-dev uuid-dev libssl-dev \
        libsrtp2-dev libcurl4-openssl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# ... download + tar xzf asterisk-${ASTERISK_VERSION}.tar.gz ...

RUN ./configure --with-jansson-bundled --with-pjproject-bundled \
    && make menuselect.makeopts \
    && menuselect/menuselect --enable res_srtp --enable res_http_websocket menuselect.makeopts \
    && make -j"$(nproc)" \
    && make install \
    && make install-logrotate \
    && ldconfig

EXPOSE 5060/udp 10000-10100/udp
CMD ["asterisk", "-f", "-vvv"]
```

Tres cosas a destacar:

- **La versión está fijada** (`ARG ASTERISK_VERSION=22.10.0`). La reproducibilidad es el objetivo principal de la containerización: actualícela deliberadamente, recompile y vuelva a probar.
- **`--with-pjproject-bundled` y `--with-jansson-bundled`** compilan la pila SIP con una versión que coincide con Asterisk, por lo que usted depende de menos paquetes apt y nunca tendrá conflictos con un PJSIP de la distribución que no esté sincronizado.
- **`CMD ["asterisk", "-f", "-vvv"]`** ejecuta Asterisk en *primer plano* (`-f`, "do not fork"). Esta es la diferencia clave con respecto a un host con systemd: el proceso principal de un contenedor no debe convertirse en un demonio (daemonize), o el contenedor se cerraría inmediatamente. Por lo tanto, en un contenedor **no** se utiliza la unidad de systemd en absoluto; el tiempo de ejecución del contenedor (Docker, además de la política `restart:`) se convierte en el supervisor que el `Restart=` de la unidad era en una VM.

### Montaje de enlace (Bind-mounting) de `/etc/asterisk`

La imagen deliberadamente **no** contiene configuración. En su lugar, `docker-compose.yml` realiza un montaje de enlace del directorio de configuración del host:

```yaml
services:
  asterisk:
    build: .
    image: astbook/asterisk:22.10.0
    container_name: astlab-asterisk
    restart: unless-stopped
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

`./asterisk/etc:/etc/asterisk:ro` asigna el directorio `lab/asterisk/etc` bajo control de versiones en el `/etc/asterisk` del contenedor, en modo de solo lectura (`:ro`). La recompensa es grande: la imagen permanece inmutable y reutilizable, mientras que la configuración reside en el host donde puede editarse y, fundamentalmente, mantenerse en git (siguiente sección). Para aplicar un cambio de configuración, usted edita el archivo y recarga — `docker compose exec asterisk asterisk -rx 'core reload'` — sin necesidad de recompilar. `restart: unless-stopped` es el equivalente a nivel de compose del `Restart=` de systemd: Docker reinicia el contenedor si Asterisk se cierra, pero no si usted lo detuvo deliberadamente.

### Red de host vs. red en puente: el problema de RTP

Este es el fallo más común en Asterisk containerizado, por lo que vale la pena entenderlo con precisión. De forma predeterminada, Docker coloca un contenedor en una red **en puente** (bridged) y usted publica puertos individuales con `ports:`. La señalización funciona bien: 5060 es un solo puerto. El problema es el contenido multimedia: RTP utiliza un *rango* de puertos UDP (el `rtp.conf` del laboratorio establece `rtpstart=10000` / `rtpend=10100`), y **cada** puerto que pueda transportar audio debe ser publicado.

El laboratorio hace exactamente eso:

```yaml
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

Tenga en cuenta que el rango de publicación de RTP (`10000-10100`) coincide exactamente con `rtp.conf`. Si se equivoca —publica muy pocos puertos o un rango diferente al de `rtp.conf`— las llamadas se conectarán pero tendrán **audio unidireccional o nulo**, porque los paquetes RTP llegan a un puerto que Docker no está redirigiendo. Dos advertencias adicionales con el modo puente:

- **Publicar miles de puertos es lento y pesado.** Un rango RTP de producción suele ser 10000–20000. Que Docker cree ~10000 redirecciones de proxy en espacio de usuario es costoso al inicio y añade un salto en la ruta de los medios. El laboratorio mantiene un rango deliberadamente pequeño de 100 puertos porque solo ejecuta una o dos llamadas de prueba.
- **NAT en el SDP.** Detrás del puente, Asterisk ve su IP privada de contenedor y puede anunciarla en el SDP. En un host público, usted debe indicar a PJSIP su dirección externa con `external_media_address` / `external_signaling_address` en el transporte (y configurar `local_net`), exactamente como lo haría detrás de cualquier NAT — vea *Cloud hosting* más abajo.

La alternativa es la **red de host** (`network_mode: host`), que elimina el puente por completo: el contenedor comparte la pila de red del host, por lo que el 5060 y todo el rango RTP son accesibles sin publicar puertos y sin saltos multimedia adicionales. Este es el modo recomendado para un contenedor de Asterisk real; evita por completo el problema del rango RTP. Su costo es el aislamiento: el contenedor puede enlazar cualquier puerto del host y usted pierde la red por servicio de compose. (La red de host es una característica de Linux; en Docker Desktop para macOS/Windows se comporta de manera diferente, lo cual es parte de la razón por la que este laboratorio de enseñanza utiliza puertos publicados explícitos).

### Volúmenes persistentes para spool y voicemail

La capa grabable de un contenedor es **efímera**: destruya el contenedor y todo lo que escribió desaparecerá. Para Asterisk, eso significa que el voicemail, las grabaciones, el spool de llamadas salientes y la base de datos local desaparecerían en cada `docker compose up --build`. La configuración sobrevive porque se monta mediante un enlace desde el host; el *estado* necesita el mismo tratamiento. Dentro del contenedor, los árboles relevantes son:

```
/var/spool/asterisk        # voicemail, monitor recordings, outgoing/, etc.
/var/lib/asterisk          # astdb.sqlite3 (the internal database)
/var/log/asterisk          # full, messages, security, cdr-csv/, cel-custom/
```

(El contenedor en ejecución del laboratorio muestra exactamente estos: `/var/spool/asterisk` contiene `voicemail`, `monitor`, `outgoing`, `recording`; `/var/lib/asterisk` contiene `astdb.sqlite3`). Para preservarlos, monte volúmenes con nombre para los directorios que contienen el estado que le interesa:

```yaml
    volumes:
      - ./asterisk/etc:/etc/asterisk:ro     # config (bind, in git)
      - ast-spool:/var/spool/asterisk        # voicemail + recordings (persist)
      - ast-lib:/var/lib/asterisk            # astdb (persist)
      - ast-log:/var/log/asterisk            # logs (persist)

volumes:
  ast-spool:
  ast-lib:
  ast-log:
```

El laboratorio de enseñanza omite esto a propósito —es sin estado y reproducible por diseño, por lo que cada `up` es un lienzo en blanco— pero un contenedor de producción **debe** tenerlos, o perderá el voicemail en el primer redespliegue.

## Gestión de configuración y respaldos

El bind-mount anterior sugiere el modelo correcto: trate a `/etc/asterisk` como **código** y
el resto como **datos**.

### Mantenga `/etc/asterisk` en control de versiones

El directorio de configuración es un conjunto plano de archivos de texto sin secretos que no puedan ser
plantillados; es ideal para git. Inicialice un repositorio en `/etc/asterisk` (o, como hace
el laboratorio, mantenga la configuración junto al proyecto y móntela mediante bind-mount). Beneficios:

- Cada cambio es revisable y reversible (`git diff`, `git revert`).
- Usted tiene un registro de auditoría de quién cambió qué y cuándo.
- Combinado con una imagen de contenedor, un commit de configuración conocido como bueno más una etiqueta de imagen fijada
  describe completamente un despliegue.

Un par de precauciones específicas para la configuración de Asterisk:

- **Secretos.** `pjsip.conf` (y `manager.conf`, `ari.conf`) contienen contraseñas. No
  envíe secretos reales a un repositorio compartido en texto plano; utilice plantillas (un archivo por
  entorno, o un gestor de secretos / sustitución de variables de entorno en tiempo de despliegue) y mantenga
  solo marcadores de posición en git. Las contraseñas triviales de estilo `Lab-6001-secret` del laboratorio están bien
  *solo* porque residen en una subred privada de Docker.
- **Plantillas por entorno.** Los valores realtime que difieren entre desarrollo, staging
  y producción (direcciones de enlace, IPs externas, credenciales de trunk, URLs de bases de datos) son
  exactamente las líneas que debe convertir en plantillas, manteniendo la mayor parte de la configuración idéntica entre
  entornos.

### Qué respaldar

La configuración en git cubre el dialplan y los endpoints, pero una PBX en vivo acumula
*estado* que no está en ningún archivo de configuración. Un respaldo completo es:

| Qué | Dónde | Por qué |
|------|-------|-----|
| Configuración | `/etc/asterisk/` | dialplan, endpoints (también en git) |
| Voicemail y grabaciones | `/var/spool/asterisk/` | datos de usuario — irreemplazables |
| Base de datos interna | `/var/lib/asterisk/astdb.sqlite3` | claves `DB()`, estado del dispositivo |
| CDR / CEL | `/var/log/asterisk/cdr-csv/` o almacén SQL | facturación e historial |
| Bases de datos externas | su MySQL/PostgreSQL | realtime, CDR, voicemail |

La **astdb** merece una mención: es el pequeño almacén de clave/valor integrado de Asterisk (un
archivo SQLite en `/var/lib/asterisk/astdb.sqlite3`) utilizado por las funciones de dialplan `DB()`,
estados de dispositivo, configuraciones de follow-me y similares. Puede volcarla para inspección o respaldo
desde la CLI:

```
asterisk -rx 'database show'
```

Si su configuración de CDR/CEL, voicemail o PJSIP reside en una base de datos externa (vea
*Asterisk Real-Time* y *Asterisk Call Detail Records*), esa base de datos es ahora la
fuente de verdad para esos datos y debe estar en su rotación normal de respaldos de base de datos;
respaldar solo `/etc/asterisk` no es suficiente.

## Monitoreo y observabilidad

No se puede operar lo que no se puede ver. Asterisk expone su estado en cuatro niveles, desde un vistazo rápido para el usuario hasta una canalización de métricas: la **CLI**, los registros **CDR/CEL**, los eventos **AMI/ARI** y los **exportadores de métricas**.

### Verificaciones de salud de la CLI

La verificación más rápida de "¿está saludable?" es la CLI. Los comandos a continuación se ejecutan en vivo contra el laboratorio. Primero, los canales:

```
*CLI> core show channels
Channel              Location             State   Application(Data)
0 active channels
0 active calls
0 calls processed
```

`0 active calls` en un sistema sin carga es normal; en uno ocupado, esta es su concurrencia en tiempo real. `core show uptime` confirma que el proceso no se ha estado reiniciando bajo su supervisión:

```
*CLI> core show uptime
System uptime: 1 hour, 40 minutes, 19 seconds
Last reload: 12 minutes, 32 seconds
```

Para la salud de SIP, `pjsip show endpoints` muestra cada endpoint y si sus contactos registrados son alcanzables. Desde el laboratorio:

```
*CLI> pjsip show endpoints
 Endpoint:  6001                                                 Unavailable   0 of inf
     InAuth:  6001/6001
        Aor:  6001                                               1
 Endpoint:  6002                                                 Unavailable   0 of inf
     InAuth:  6002/6002
        Aor:  6002                                               1
 Endpoint:  sipp                                                 Unavailable   0 of inf
        Aor:  sipp                                               1
   Identify:  sipp-identify/sipp
        Match: 172.30.0.0/24
 Endpoint:  webrtc-1000                                          Unavailable   0 of inf
     InAuth:  webrtc-1000/webrtc-1000
        Aor:  webrtc-1000                                        1
Objects found: 4
```

`Unavailable` aquí simplemente significa que ningún teléfono está registrado actualmente en esos endpoints (el laboratorio no tiene clientes activos); una vez que un softphone se registra y `qualify` lo confirma, el estado muestra el contacto como alcanzable. Comandos complementarios: `pjsip show contacts` (registros actuales y tiempo de ida y vuelta), `pjsip show transports` y `pjsip show aor <name>` para un AOR. Estas son las herramientas cotidianas para responder "¿por qué no se puede alcanzar la extension X?".

### CDR y CEL

Cada llamada deja un **Call Detail Record** (CDR); el **Channel Event Logging** (CEL) añade eventos más detallados por canal. Confirme que CDR esté activo y qué backend lo almacena:

```
*CLI> cdr show status

Call Detail Record (CDR) settings
----------------------------------
  Logging:                    Enabled
  Mode:                       Simple
  Log calls by default:       Yes
  Log unanswered calls:       No
...
* Registered Backends
  -------------------
    (none)
```

El laboratorio muestra `(none)` bajo los backends registrados porque la configuración mínima del laboratorio no carga ningún módulo de almacenamiento de CDR; por lo tanto, los registros se calculan pero no se escriben en ninguna parte. En producción, usted carga un backend (CSV, o `cdr_odbc`/`cdr_adaptive_odbc` hacia MySQL/PostgreSQL) y eso se convierte en su fuente de facturación e historial. CEL está **deshabilitado por defecto** (`cel show status` muestra ` reports `CEL Logging: Disabled` in the lab) and you enable it in `cel.conf` solo cuando necesite detalles a nivel de evento. Ambos se cubren a fondo en *Asterisk Call Detail Records*; para el monitoreo, el punto es que CDR/CEL son su registro *histórico*, mientras que la CLI es su vista *en vivo*.

### Eventos AMI y ARI

Para un monitoreo programático en tiempo real, usted desea una fuente de eventos (push) en lugar de consultar la CLI:

- **AMI (Asterisk Manager Interface)** es el protocolo de eventos/comandos TCP de larga trayectoria (`manager.conf`). Suscríbase y recibirá `Newchannel`, `Hangup`, `DialBegin`, `BridgeEnter`, `PeerStatus` y eventos similares a medida que ocurren las llamadas; es la columna vertebral de los paneles de control y herramientas de contabilidad de llamadas. En el laboratorio, AMI está deshabilitado por defecto (`manager show settings` reporta `Manager (AMI): No`); usted lo habilita y asegura en `manager.conf`.
- **ARI (Asterisk REST Interface)** es la moderna interfaz HTTP + WebSocket (`ari.conf`, servida por el servidor HTTP incorporado). Proporciona un flujo de eventos JSON y un control de llamadas detallado; es la opción correcta para nuevas integraciones.

Ambos se detallan en *Extending Asterisk with AMI and AGI* y *The Asterisk REST Interface (ARI)*. La advertencia relevante para la implementación: **AMI y ARI son potentes y nunca deben exponerse a internet.** Vincule el servidor HTTP a localhost o a una red de gestión, utilice secretos únicos y fuertes, y proteja los puertos con un firewall; consulte *Asterisk Security*.

### Métricas: Prometheus y Grafana

Para paneles de control y alertas, Asterisk 22 incluye un exportador de Prometheus, **`res_prometheus.so`** (un módulo con nivel de soporte *extended*), que expone métricas en un endpoint HTTP que un servidor Prometheus consulta (scrape). Junto con las métricas principales del proceso, incluye proveedores conectables que cubren canales, llamadas, endpoints, bridges y registros salientes de PJSIP:

```
# core process
asterisk_core_uptime_seconds
asterisk_core_last_reload_seconds
asterisk_core_scrape_time_ms
asterisk_core_properties
# channels
asterisk_channels_count
asterisk_channels_state
asterisk_channels_duration_seconds
# calls
asterisk_calls_count
asterisk_calls_sum
# endpoints
asterisk_endpoints_count
asterisk_endpoints_state
asterisk_endpoints_channels_count
# bridges
asterisk_bridges_count
asterisk_bridges_channels_count
# PJSIP outbound registrations
asterisk_pjsip_outbound_registration_status
```

Puede confirmar que el módulo está presente en la compilación del laboratorio:

```
*CLI> module show like prometheus
Module                         Description                     Use Count  Status      Support Level
res_prometheus.so              Asterisk Prometheus Module      0          Not Running  extended
```

Muestra `Not Running` porque el laboratorio no lo configura ni lo carga; habilitarlo (`prometheus.conf` más el servidor HTTP) convierte a Asterisk en un objetivo de Prometheus. Apunte Prometheus al endpoint de consulta y Grafana a Prometheus, y obtendrá paneles de series temporales (llamadas concurrentes, registros, tendencias de ASR/ACD) y alertas (por ejemplo, "las llamadas activas cayeron a cero" o "los fallos de registro están aumentando"). Para los equipos que ya ejecutan Prometheus/Grafana, esta es la forma natural de integrar Asterisk en la observabilidad existente, en lugar de analizar la salida de la CLI.

### Códigos de respuesta SIP que vale la pena vigilar

Independientemente de la canalización, algunos resultados SIP señalan problemas y vale la pena generar alertas: los fallos de desafío persistentes `401`/`407` o `403 Forbidden` sugieren una tormenta de fuerza bruta o credenciales mal configuradas (consulte Fail2Ban en *Asterisk Security*); `503 Service Unavailable` apunta a un servidor o trunk sobrecargado o congestionado; y un pico en `408 Request Timeout`/`480 Temporarily Unavailable` generalmente significa que los endpoints se han vuelto inalcanzables (tiempo de espera de NAT, fallos de qualify).

## Alta disponibilidad y escalabilidad

Un servidor Asterisk es un punto único de falla y tiene un límite finito de llamadas. Los dos problemas —*mantenerse activo* y *crecer*— tienen respuestas diferentes.

### Activo/pasivo con una IP flotante

El patrón de HA clásico y bien probado para Asterisk es **activo/pasivo** (no activo/activo; el estado de las llamadas en Asterisk es difícil de compartir en tiempo real). Dos servidores idénticos, uno activo y otro pasivo, comparten una **IP flotante (virtual)** gestionada por un administrador de clúster como **keepalived** (VRRP) o **Pacemaker/Corosync**. Los teléfonos y trunks se registran en la IP flotante, no en ninguno de los hosts reales. Si el nodo activo falla en su verificación de estado, la IP flotante se mueve al nodo pasivo, el cual toma el control.

La advertencia honesta: una conmutación por error (failover) de IP **interrumpe las llamadas en curso**; Asterisk no replica el estado de los canales en vivo entre nodos, por lo que cualquier persona en medio de una llamada debe volver a marcar. Los registros se restablecen dentro de un ciclo de qualify/registration. Lo que la conmutación por error le brinda es que el *servicio* se recupera en segundos sin intervención manual, lo cual para la mayoría de las PBX es exactamente el objetivo. Para que el nodo pasivo sea realmente capaz de tomar el control, ambos nodos necesitan la misma configuración (su `/etc/asterisk` gestionado con git, desplegado de forma idéntica) y el mismo *estado*, que es el siguiente punto.

### Externalizar el estado con PJSIP Realtime

El modo activo/pasivo solo funciona si el nodo pasivo conoce los mismos endpoint y registros que el nodo activo. La forma de lograrlo es **dejar de mantener el estado en archivos planos en una sola caja** y moverlo a una base de datos compartida que ambos nodos lean. **PJSIP Realtime** (Sorcery respaldado por una base de datos) hace exactamente esto: los endpoint, AORs, auths —y, lo que es más importante, los **registros** (la tabla `ps_contacts`)— residen en MySQL/PostgreSQL en lugar de en `pjsip.conf` y la memoria local. Ambos nodos de Asterisk apuntan a la misma base de datos, por lo que un teléfono registrado a través de un nodo es visible para el otro. Esto se trata en *Asterisk Real-Time* (la sección de PJSIP Realtime / Sorcery); aquí el punto del despliegue es que **externalizar el estado es el requisito previo tanto para la HA como para la escalabilidad horizontal**; sin esto, cada nodo es una isla.

Aplique la misma lógica al resto de su estado: CDR/CEL en un almacén SQL compartido, voicemail en almacenamiento compartido/replicado (o `ODBC_STORAGE`), y las claves de astdb de las que dependa en una base de datos. Una vez que el estado es externo, los nodos de Asterisk se vuelven más parecidos a front-ends intercambiables.

### Proxies SIP al frente (OpenSIPS)

Para escalar *más allá* de la capacidad de un solo servidor, usted coloca un **proxy SIP/balanceador de carga** frente a un grupo de servidores de medios Asterisk. **OpenSIPS** es un proxy SIP diseñado específicamente para un rendimiento muy alto (manejan cientos de miles de registros y enrutan la señalización sin tocar los medios). El proxy presenta una única dirección SIP al mundo, mantiene el servicio de registro/ubicación y distribuye las llamadas entre los back-ends de Asterisk. Esta separación —una capa de proxy ligera que realiza el registro y el enrutamiento, y una capa de Asterisk escalable horizontalmente que realiza el procesamiento de llamadas real (IVR, colas, conferencias, transcodificación)— es cómo las grandes implementaciones crecen más allá de una sola caja. (La plataforma SipPulse misma utiliza OpenSIPS frente a sus servidores de medios/aplicaciones exactamente por esta razón).

### Escalabilidad de medios

El proxy distribuye la *señalización* de forma económica; **los medios son el recurso costoso**. El retransmisión de RTP, y especialmente la transcodificación entre codecs (por ejemplo, Opus ↔ G.711) o la ejecución de grandes conferencias, depende de la CPU y es lo que realmente limita a un servidor. Estrategias:

- **Evite la transcodificación** siempre que sea posible: negocie un codec común de extremo a extremo para que Asterisk realice puentes de forma nativa (pass-through) en lugar de transcodificar. Esta es la mayor ganancia en capacidad de medios.
- **Escale los medios horizontalmente** añadiendo nodos de Asterisk detrás del proxy; cada uno lleva una parte de las llamadas concurrentes.
- **Descargue los medios del navegador** a una puerta de enlace WebRTC dedicada (por ejemplo, Janus) para que la PBX no esté también terminando y retransmitiendo cada flujo DTLS-SRTP del navegador; consulte *WebRTC with Asterisk*, que analiza exactamente esta división entre Asterisk y la puerta de enlace.

Dimensione la capacidad según las **llamadas concurrentes y la carga de transcodificación**, no según los usuarios registrados: 10,000 teléfonos registrados que están mayormente inactivos son mucho más económicos que 200 conferencias transcodificadas simultáneas.

## Cloud hosting

Ejecutar Asterisk en una VM en la nube (AWS, GCP, Azure, un VPS) es común y funciona bien, pero la red en la nube está **bajo NAT y con firewall de forma predeterminada**, lo cual entra en conflicto con SIP. A continuación se presentan las preocupaciones específicas de la implementación.

### NAT y el SDP

Una VM en la nube casi siempre tiene una IP **privada** en su NIC y una IP **pública** separada que el proveedor le asigna mediante NAT. Si Asterisk anuncia la IP privada en el SDP, los teléfonos remotos envían el RTP a un agujero negro: el síntoma clásico de audio unidireccional o sin audio. Indique a PJSIP su identidad pública en el transporte:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=203.0.113.10      ; the VM's PUBLIC IP
external_signaling_address=203.0.113.10
local_net=10.0.0.0/8                     ; your private/VPC range(s)
```

`external_*` hace que Asterisk reescriba la dirección que anuncia a los pares públicos, mientras que
`local_net` le indica qué pares son locales (y *no* deben ser reescritos). Este es el mismo manejo de NAT discutido anteriormente para redes Docker puenteadas: una VM en la nube está, en efecto, detrás de NAT.

### Firewall y el rango RTP

Por lo general, se aplican dos firewalls en una VM en la nube: el grupo de seguridad / ACL de red del **proveedor** y el iptables del **host**. Ambos deben abrir los mismos puertos, y la política es la del capítulo de Seguridad. El conjunto de reglas rescatado de la primera edición
(`docs/legacy-labs/configs/Lab7/rules.v4`) captura la forma: aceptar SIP y el rango RTP, aceptar conexiones establecidas/relacionadas, descartar el resto:

```
-A INPUT -p udp -m udp --dport 5060 -j ACCEPT
-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -j DROP
```

Dos correcciones que el capítulo de Seguridad realiza y que son importantes aquí: abra el **5061 en TCP** (no UDP) si ejecuta SIP/TLS, y recuerde que el rango UDP de RTP en su firewall debe coincidir exactamente con `rtpstart`/`rtpend` en `rtp.conf`: el mismo rango que publica en un contenedor.
No duplique la compilación de iptables/Fail2Ban aquí; **siga las secciones de firewall, Fail2Ban y TLS/SRTP de *Asterisk Security*** (Fail2Ban observa el canal de registro `security` que el laboratorio ya habilita en `logger.conf`) y aplique esa política tanto en el firewall del host como en el grupo de seguridad de la nube.

### Latencia, región y el SBC

- **Elija una región cercana a sus usuarios.** La voz es sensible a la latencia: una latencia de boca a oído de un solo sentido superior a ~150 ms es notable. Aloje la VM en la región más cercana a la mayoría de sus teléfonos y trunks; el tráfico de medios entre continentes suena notablemente peor.
- **Coloque un SBC al frente para cualquier implementación orientada a internet.** Un **Session Border Controller** termina SIP/RTP en el borde, oculta su topología, normaliza NAT y absorbe el tráfico de DoS y escaneo antes de que llegue a Asterisk. La recomendación principal del capítulo de Seguridad — *no exponga Asterisk directamente a internet* — se aplica doblemente en la nube, donde la IP pública de su VM es escaneada a los pocos minutos de estar activa. Un SBC (o al menos un proxy SIP reforzado como OpenSIPS más Fail2Ban) es el estándar para el borde.

## Resumen

El despliegue es el proceso mediante el cual un dialplan funcional se convierte en un servicio confiable. En una VM, ejecute Asterisk bajo **systemd** como un usuario **non-root**, permitiendo que el `Restart=` de la unidad lo mantenga activo (safe_asterisk ha sido reemplazado) y utilizando `core reload` en lugar de `systemctl restart` para los cambios de configuración. La **containerización** con Docker —como se hace en el laboratorio de este libro— le proporciona una imagen inmutable y fijada con la configuración **bind-mounted** desde un `/etc/asterisk` bajo control de versiones con git; el inconveniente es el manejo de medios, por lo que debe utilizar **host networking** o publicar un rango de puertos RTP que **coincida exactamente con `rtp.conf`**, y montar **persistent volumes** para spool/voicemail/astdb de modo que el estado sobreviva a un redespliegue. Trate la configuración como código y **realice copias de seguridad del estado** que la configuración no captura: voicemail, grabaciones, `astdb.sqlite3` y CDR/CEL. **Observe** el sistema en cuatro niveles: la CLI (`core show channels`, `pjsip show endpoints`) para una vista en tiempo real, **CDR/CEL** para el historial, **AMI/ARI** para eventos programáticos y el exportador **`res_prometheus`** hacia Grafana para paneles y alertas, manteniendo siempre AMI/ARI fuera de la internet pública. Para **mantenerse activo**, ejecute un esquema activo/pasivo con una **floating IP** (aceptando que la conmutación por error interrumpirá las llamadas activas); para **crecer**, externalice el estado con **PJSIP Realtime**, coloque un grupo de servidores de medios detrás de **OpenSIPS** y minimice la transcodificación, ya que **los medios —no los registros— son lo que limita la capacidad de un servidor**. Finalmente, en la **cloud**, trate la VM como si estuviera detrás de NAT (`external_media_address`, `local_net`), abra el firewall según lo indicado en el capítulo de Seguridad tanto en el host como en el grupo de seguridad del proveedor, elija una región de baja latencia y nunca exponga Asterisk directamente: coloque un **SBC** en el borde.

## Cuestionario

1. En un host systemd, ¿qué reemplaza la función del antiguo wrapper `safe_asterisk` para reiniciar un Asterisk que ha fallado?
   - A. Un trabajo de cron
   - B. La directiva `Restart=` del archivo de unidad
   - C. `systemctl enable`
   - D. El astdb
2. Para aplicar un cambio de configuración a un Asterisk en ejecución **sin interrumpir las llamadas**, usted debe:
   - A. `systemctl restart asterisk`
   - B. Reiniciar el servidor
   - C. `asterisk -rx 'core reload'`
   - D. Reconstruir la imagen del contenedor
3. Un Asterisk en contenedor (red bridge) conecta llamadas pero **no tiene audio**. La causa más probable es:
   - A. El dialplan es incorrecto
   - B. El rango de puertos UDP RTP publicados no coincide con `rtpstart`/`rtpend` en `rtp.conf`
   - C. El CDR está deshabilitado
   - D. La CLI no es accesible
4. ¿Qué directorios deben montarse como **volúmenes persistentes** para que un redespliegue del contenedor no pierda el estado? (marque todas las que apliquen)
   - A. `/var/spool/asterisk` (voicemail, grabaciones)
   - B. `/var/lib/asterisk` (astdb)
   - C. `/etc/asterisk` (ya montado desde el host)
   - D. `/usr/sbin`
5. ¿Qué comando de CLI proporciona el conteo en tiempo real de las llamadas activas?
   - A. `cdr show status`
   - B. `core show channels`
   - C. `pjsip show transports`
   - D. `module show like prometheus`
6. En Asterisk 22, la forma admitida para exponer métricas de llamadas/canales a una pila Prometheus/Grafana es:
   - A. Analizar el archivo de registro `full`
   - B. El módulo `res_prometheus.so`
   - C. Scripts AGI
   - D. No existe ninguna
7. ¿Cuál es el prerrequisito tanto para la conmutación por error (failover) de HA como para el escalado horizontal a través de múltiples nodos Asterisk?
   - A. Ejecutar como root
   - B. Externalizar el estado (por ejemplo, registros de PJSIP Realtime en una base de datos compartida)
   - C. Deshabilitar el CDR
   - D. Usar redes bridge
8. ¿Qué recurso limita más directamente cuántas llamadas simultáneas puede manejar un servidor Asterisk?
   - A. El número de usuarios registrados
   - B. El procesamiento de medios, especialmente la transcodificación
   - C. El tamaño de `/etc/asterisk`
   - D. El backend de CDR
9. En una VM en la nube, ¿qué configuraciones de transporte `pjsip.conf` hacen que Asterisk anuncie su dirección pública para que el audio remoto funcione? (marque todas las que apliquen)
   - A. `external_media_address`
   - B. `external_signaling_address`
   - C. `local_net`
   - D. `qualify_frequency`
10. Para un despliegue en la nube expuesto a internet, la regla fundamental del capítulo de Seguridad es:
    - A. Usar siempre dos NICs
    - B. Nunca exponer Asterisk directamente a internet; coloque un SBC (o un proxy reforzado + Fail2Ban) en el borde
    - C. Usar solo UDP
    - D. Deshabilitar TLS

**Respuestas:** 1 — B · 2 — C · 3 — B · 4 — A, B · 5 — B · 6 — B · 7 — B · 8 — B · 9 — A, B, C · 10 — B
