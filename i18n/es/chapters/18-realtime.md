# Asterisk Real-Time

Como sabe, la configuración de Asterisk se logra mediante el uso de varios archivos de texto en el directorio /etc/asterisk. A pesar de la facilidad de usar archivos de texto, existen algunos inconvenientes conocidos:

- La necesidad de recargar Asterisk cada vez que se modifican los archivos
- Mayor uso de memoria para un gran volumen de usuarios
- Es difícil programar una interfaz de aprovisionamiento utilizando archivos de texto
- No hay posibilidad de integración con bases de datos existentes

ARA o Asterisk Realtime, como se le conoce, fue creado por Anthony Minessale II, Mark Spencer y Constantine Filin, y fue diseñado para permitir una integración transparente con bases de datos SQL. También hay disponible una interfaz LDAP. Este sistema también se conoce como Asterisk External Configuration y se configura en /etc/asterisk/extconfig.conf. Puede asignar archivos de configuración a tablas en una base de datos (configuración estática) y entradas en tiempo real para la creación dinámica de objetos sin la necesidad de recargar Asterisk.

## Objetivos

Al finalizar este capítulo, el lector debería ser capaz de:

- Comprender las ventajas y limitaciones de Asterisk Real Time.
- Utilizar ODBC para su uso con ARA.
- Compilar e instalar ARA utilizando ODBC.
- Probar el sistema en un entorno de laboratorio.

## ¿Cómo funciona Asterisk Real Time?

En la nueva arquitectura Real Time, todo el código específico de la base de datos se trasladó a los controladores de canal. El canal solo llama a una rutina genérica que busca en la base de datos. El resultado es un proceso mucho más simple y limpio desde el punto de vista del código fuente. Se accede a la base de datos mediante tres funciones:

- STATIC: Se utiliza para configurar una configuración estática cuando se carga un módulo.
- REALTIME: Se utiliza para buscar objetos durante una llamada u otro evento.


- UPDATE: Se utiliza para actualizar objetos.

En Asterisk 22, los endpoints SIP son manejados por la pila **PJSIP** (`res_pjsip`), la cual está construida sobre el modelo de objetos **Sorcery**. Con el asistente `realtime`, Sorcery carga cada objeto PJSIP desde la base de datos bajo demanda, y esos objetos existen entonces como objetos PJSIP configurados ordinarios, no como los peers realtime desechables que el antiguo controlador SIP descartaba después de cada llamada.

Debido a que son objetos reales, NAT traversal, qualify y message waiting indication (MWI) funcionan normalmente para los endpoints realtime. (Adicionalmente, se le puede indicar a Sorcery que almacene objetos en caché en la memoria mediante un asistente `memory_cache`, pero eso es opcional y está separado de la carga realtime). Cuando cambia un objeto en la base de datos, el cambio se detecta en la siguiente búsqueda; no necesita recargar después de cada edición. (El modelo realtime retirado `chan_sip`, con sus familias `sippeers`/`sipusers`, solo se cubre en el capítulo *Legacy Channels*).

## Configuración de Asterisk Real Time

Para este laboratorio, asumiremos que ya tiene instalado ODBC desde el capítulo de CDR. ARA se configura en el archivo de texto extconfig.conf, donde se pueden observar fácilmente dos secciones. La primera es la sección de archivos de configuración estáticos, donde puede sustituir los archivos de configuración de texto por tablas de base de datos. La segunda sección es el motor de configuración realtime, donde se configuran tablas de base de datos para objetos dinámicos (peers/users). No es inusual utilizar archivos de texto para la configuración estática y la base de datos para entradas dinámicas. En este caso, la primera sección se deja intacta.

```
extconfig.conf file format:
;
; Static and realtime external configuration
; engine configuration
;
; Please read doc/README.extconfig for basic table
; formatting information.
```

![Arquitectura de Asterisk Real Time: los archivos de configuración y las tablas de base de datos estáticas se cargan cuando Asterisk inicia, mientras que las tablas de base de datos realtime proporcionan una configuración dinámica que se lee bajo demanda durante una llamada.](images/ara_architecture.png){width=100%}(../images/18-realtime-fig01.png)

```
;
[settings]
;
; Static configuration files:
;
; file.conf => driver,database[,table]
;
; maps a particular configuration file to the given
; database driver, database and table (or uses the
; name of the file as the table if not specified)
;
;uncomment to load queues.conf via the odbc engine.
;
;queues.conf => odbc,asterisk,ast_config
;
; The following files CANNOT be loaded from Realtime storage:
;       asterisk.conf
;       extconfig.conf (this file)
;       logger.conf
;
; Additionally, the following files cannot be loaded from
; Realtime storage unless the storage driver is loaded
; early using 'preload' statements in modules.conf:
;       manager.conf
;       cdr.conf
;       rtp.conf
;
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
;example => odbc,asterisk,alttable
;ps_endpoints => odbc,asterisk
;ps_aors => odbc,asterisk
;ps_auths => odbc,asterisk
;ps_contacts => odbc,asterisk
;voicemail => odbc,asterisk
;extensions => odbc,asterisk
;queues => odbc,asterisk
;queue_members => odbc,asterisk
```


### Sección de configuración estática

La sección de configuración estática es donde usted almacena el equivalente a los archivos de configuración en la base de datos. Estas configuraciones se leen durante la carga de Asterisk. Algunos módulos vuelven a leer la base de datos cuando usted realiza una recarga. Ejemplos de configuración estática son:

```
<conf filename> => <driver>,<databasename>[,table_name]
queues.conf => mysql,asteriskdb,queues_conf
pjsip.conf => odbc,asteriskdb,pjsip_conf
iax.conf => ldap,MyBaseDN,iax
```

El mapeo de archivos estáticos es más útil para archivos de configuración que no tienen un equivalente realtime por objeto. Para PJSIP, prefiera las familias realtime por objeto (`ps_endpoints`, `ps_aors`, y así sucesivamente) descritas más adelante en este capítulo en lugar de mapear todo el `pjsip.conf` como un archivo estático.

Se describen tres ejemplos arriba. En el primero, usted vincula queues.conf a una tabla queues en la base de datos asteriskdb. En el segundo ejemplo, usted vincula pjsip.conf a la tabla pjsip_conf en la base de datos asteriskdb definida en la configuración odbc. En el último ejemplo, usted vincula iax.conf a un directorio LDAP. MyBaseDN es el DN base que se debe buscar. En el ejemplo anterior, la aplicación app_queue.so se carga mientras el controlador MySQL consulta la base de datos y obtiene la información requerida.

### Sección de configuración Real Time

La configuración real-time (segunda parte del archivo extconfig.conf) es donde se configura, actualiza y descarga en tiempo real la pieza de configuración que se va a cargar. Con real time, no es necesario recargar las configuraciones. La sintaxis real-time es la siguiente:

```
<family name> => <driver>,<database name>[,table_name]
```

Ejemplo:

```
ps_endpoints => odbc,asterisk,ps_endpoints
ps_aors => odbc,asterisk,ps_aors
queues => odbc,asterisk,queue_table
queue_members => odbc,asterisk,queue_member_table
voicemail => odbc,asterisk,test
```

Aquí tenemos cinco líneas de configuración. En la primera línea, usted vincula la familia PJSIP/Sorcery `ps_endpoints` a una tabla `ps_endpoints` en la base de datos asteriskdb. En la última, usted vincula la familia voicemail a la tabla test en la base de datos asteriskdb. Cada tipo de objeto PJSIP (endpoint, aor, auth, contact) obtiene su propia familia y tabla; el conjunto completo se muestra en la sección "PJSIP Realtime (Sorcery)" a continuación. Las familias `voicemail`, `extensions`, `queues` y `queue_members` siguen siendo válidas en Asterisk 22.

## PJSIP Realtime (Sorcery)

En Asterisk 22, los endpoints SIP son manejados exclusivamente por la pila **PJSIP** (`res_pjsip`), la cual está construida sobre la capa de abstracción de objetos **Sorcery**. En lugar de un único "peer" SIP, PJSIP divide una cuenta SIP en varios tipos de objetos, cada uno almacenado en su propia tabla realtime:

| Sorcery object type | Realtime table | What it holds |
|---------------------|----------------|---------------|
| endpoint | ps_endpoints | configuraciones por cuenta (context, codecs, DTMF, etc.) |
| aor (address of record) | ps_aors | límites de registro y configuraciones de `qualify` |
| auth | ps_auths | credenciales de `username` / `password` |
| contact | ps_contacts | la ubicación registrada dinámicamente |
| domain alias | ps_domain_aliases | dominios SIP alternativos para un endpoint |
| endpoint identifier by IP | ps_endpoint_id_ips | coincidencia de un endpoint por IP de origen |

Realtime para PJSIP se habilita en dos lugares. Primero, asigne los tipos de objetos Sorcery a realtime en `extconfig.conf`:

```
[settings]
ps_endpoints => odbc,asterisk
ps_aors => odbc,asterisk
ps_auths => odbc,asterisk
ps_contacts => odbc,asterisk
ps_domain_aliases => odbc,asterisk
ps_endpoint_id_ips => odbc,asterisk
```

Segundo, indique a Sorcery que utilice el asistente `realtime` para esos tipos de objetos en `sorcery.conf`. El nombre de la asignación (aquí `res_pjsip`) es el módulo cuyos objetos está reubicando, y el valor a la derecha apunta a la familia que definió en `extconfig.conf`:

```
[res_pjsip]
endpoint=realtime,ps_endpoints
aor=realtime,ps_aors
auth=realtime,ps_auths
domain_alias=realtime,ps_domain_aliases
contact=realtime,ps_contacts

[res_pjsip_endpoint_identifier_ip]
identify=realtime,ps_endpoint_id_ips
```

Puede mezclar objetos estáticos y realtime. Si omite un tipo de `sorcery.conf`, ese tipo de objeto seguirá leyendo desde `pjsip.conf`. Un patrón común es mantener los transports estáticos y las configuraciones globales en `pjsip.conf` mientras se almacenan los endpoints, aors, auths y contacts en la base de datos.

### Creación del esquema realtime de PJSIP con Alembic

Asterisk incluye migraciones de base de datos para todos sus esquemas realtime bajo `contrib/ast-db-manage`. Esta es la forma admitida para crear (y actualizar la versión de) las tablas PJSIP; ya no se escriben a mano las definiciones de tabla de `ps_*`. El conjunto de migraciones `config` contiene las tablas PJSIP/Sorcery.

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# edit config.ini → set sqlalchemy.url, e.g.
#   sqlalchemy.url = mysql+pymysql://astdb:CHANGE_ME_DB_PASSWORD@127.0.0.1/astdb
alembic -c config.ini upgrade head
```

Esto crea `ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts` y las demás tablas PJSIP con las columnas correctas para la versión de Asterisk en ejecución. (Alembic requiere el paquete `alembic` de Python además de un controlador SQLAlchemy como `pymysql` para MySQL/MariaDB o `psycopg2` para PostgreSQL.)

Un endpoint realtime mínimo consiste entonces en una fila en cada una de las tres tablas; por ejemplo, el endpoint `6010`:

```
ps_auths:      id=6010-auth, auth_type=userpass, username=6010, password=supersecret
ps_aors:       id=6010, max_contacts=1
ps_endpoints:  id=6010, transport=transport-udp, aors=6010, auth=6010-auth,
               context=from-internal, disallow=all, allow=ulaw,
               direct_media=no
```

Después de insertar las filas no hay nada que recargar; el siguiente REGISTER/INVITE extrae los objetos de la base de datos. Puede confirmar lo que devolvió realtime con:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

## Configuración de la base de datos

Ahora que hemos configurado el archivo extconfig.conf, vamos a crear las tablas. En términos generales, cada columna de la base de datos coincide con un nombre de opción del archivo de configuración correspondiente. Las tablas de PJSIP `ps_*` siguen esta regla: cada columna `ps_endpoints` lleva el nombre de una opción de endpoint de `pjsip.conf`, cada columna `ps_auths` el de una opción de auth, y así sucesivamente. Por ejemplo, el endpoint `pjsip.conf` a continuación,

```
[4000](endpoint)
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=4000
aors=4000
```

se almacena como una fila a través de tres tablas. La fila `ps_endpoints` contiene `id=4000, context=from-internal, disallow=all, allow=ulaw, auth=4000, aors=4000`; la fila `ps_auths` contiene `id=4000, auth_type=userpass, username=4000, password=supersecret`; y la fila `ps_aors` contiene `id=4000, max_contacts=1`. Solo necesita completar las columnas que realmente utiliza; cualquier columna que deje como NULL recurrirá al valor predeterminado de la opción. Si desea, por ejemplo, el parámetro `callerid` en un endpoint, complete la columna `callerid` de `ps_endpoints` (el nombre de la columna es el mismo que el nombre de la opción `pjsip.conf`).

Una tabla de voicemail sigue la misma idea. Sus columnas se asignan a los campos de `voicemail.conf`:

| uniqueid | mailbox | context | password | email | fullname |
|----------|---------|---------|----------|-------|----------|
| 1 | 4000 | default | 4000 | john@doe.com | John Doe |

El `uniqueid` debe ser único para cada usuario de voicemail y puede ser autoincremental. No necesita tener ninguna relación con el mailbox o el context.

### Construcción de un dialplan usando Asterisk Real Time

También puede utilizar el sistema en tiempo real para crear el dialplan. ARA utiliza la sentencia `switch` para incluir las extensiones en tiempo real dentro del dialplan normal contenido en el archivo extensions.conf. La tabla de extensiones debería verse como la siguiente:

| context | exten | priority | app | appdata |
|---------|-------|----------|-----|---------|
| from-internal | 4000 | 1 | Dial | PJSIP/4000 |

La familia en tiempo real `extensions` no ha cambiado en Asterisk 22; solo asegúrese de que la columna `appdata` marque canales PJSIP, por ejemplo `PJSIP/4000`. En el dialplan, debe usar el comando `switch` para utilizar el tiempo real.

![Construcción de un dialplan con Asterisk Real Time: extensions.conf utiliza una sentencia `switch => realtime` para extraer filas de extensión (context, exten, priority, app, data) de una tabla de base de datos en lugar de hacerlo desde el archivo de texto.](../images/18-realtime-fig02.png)


```
[local]
switch => realtime
```

o

```
[local]
switch => realtime/from-internal@extensions
```

## Lab: Instalación y creación de las tablas de la base de datos

En este laboratorio, prepararemos la base de datos para recibir parámetros de Asterisk. Prepararemos solo las tablas REALTIME. La configuración estática se dejará en los archivos de texto de configuración (genial, ¿verdad?). A continuación, se muestra la creación de tablas en MySQL.

Paso 1: Ingrese a la base de datos MySQL como root.

```
mysql -u root -p
```

Paso 2: Inicie sesión en el servidor MySQL creado en los laboratorios de CDR.

```
mysql -u astdb -p
```

Cuando se le solicite la contraseña, escriba supersecret.

Paso 3: Cree las tablas necesarias. Los archivos de esquema estático heredados todavía se incluyen en `contrib/realtime/` (por ejemplo, `/usr/src/asterisk-22.x/contrib/realtime/mysql`), pero en Asterisk 22 la forma recomendada y correcta según la versión para construir las tablas realtime —especialmente las tablas PJSIP `ps_*`— es mediante las migraciones de **Alembic** en `contrib/ast-db-manage` (vea la sección "Creating the PJSIP realtime schema with Alembic" más arriba).

```
cd /usr/src/asterisk-22.x/contrib/ast-db-manage
cp config.ini.sample config.ini
# set sqlalchemy.url for your astdb database, then:
alembic -c config.ini upgrade head
```

El conjunto de migraciones de Alembic `config` construye las tablas PJSIP `ps_*` (junto con `voicemail`, `extensions` y los otros esquemas realtime) exactamente con las columnas que la versión de Asterisk en ejecución espera, por lo que el esquema siempre coincide con la compilación.

Use supersecret como contraseña.

Paso 4: Verifique la creación de las tablas.

```
mysql -u astdb -p astdb
mysql>use astdb;
mysql>show tables;
```

Debería ver las tablas PJSIP `ps_*` (creadas por la migración de Alembic `config`), junto con las tablas `voicemail`, `extensions` y otras tablas realtime:

```
mysql> show tables;
+----------------------------+
| Tables_in_astdb            |
+----------------------------+
| ps_aors                    |
| ps_auths                   |
| ps_contacts                |
| ps_domain_aliases          |
| ps_endpoint_id_ips         |
| ps_endpoints               |
| ps_registrations           |
| extensions                 |
| voicemail                  |
+----------------------------+
```

(Alembic crea más tablas que estas; la lista anterior muestra las relevantes para este laboratorio).

Paso 5: La base de datos ya está configurada para ODBC (desde el laboratorio de CDR), por lo que no se necesita ninguna configuración adicional de ODBC aquí.

Paso 6: Inspeccione y rellene las tablas desde el cliente MySQL. No necesita una herramienta gráfica como phpMyAdmin; cada paso en este capítulo es SQL simple, que se puede copiar y pegar, ejecutado desde la línea de comandos `mysql`. Conéctese a la base de datos `astdb` (use `supersecret` cuando se le solicite):

```
mysql -u astdb -p astdb
```

Puede confirmar las columnas de una tabla en cualquier momento con `DESCRIBE`, por ejemplo:

```
mysql> DESCRIBE ps_endpoints;
mysql> DESCRIBE ps_auths;
mysql> DESCRIBE ps_aors;
```

Estas tablas fueron creadas por la migración de Alembic `config`, por lo que sus columnas ya coinciden con los nombres de las opciones `pjsip.conf` para la versión de Asterisk en ejecución; solo debe completar las columnas que necesite.

## Lab: Configuración y prueba de ARA

En este laboratorio cambiaremos la configuración de extconfig.conf para reflejar nuestra configuración de base de datos y tablas.

Paso 1: Configure extconfig.conf y recargue Asterisk.

```
; Realtime configuration engine
;
; maps a particular family of realtime
; configuration to a given database driver,
; database and table (or uses the name of
; the family if the table is not specified
;
ps_endpoints => odbc,cdr
ps_aors => odbc,cdr
ps_auths => odbc,cdr
ps_contacts => odbc,cdr
voicemail => odbc,cdr,voicemail
extensions => odbc,cdr,extensions
```

Observe las familias `ps_endpoints`, `ps_aors`, `ps_auths` y `ps_contacts` anteriores; junto con los mapeos `sorcery.conf` correspondientes (consulte la sección "PJSIP Realtime (Sorcery)"), hacen que PJSIP lea sus cuentas desde la base de datos. Las familias `voicemail` y `extensions` completan el ejemplo.

Paso 2: Prueba de extensión Real Time. Cree un nuevo endpoint `6010` insertando una fila en cada una de las tablas `ps_auths`, `ps_aors` y `ps_endpoints`, luego intente registrar este endpoint con un softphone. Ejecute el siguiente SQL en el cliente `mysql` (`mysql -u astdb -p astdb`):

```sql
INSERT INTO ps_auths (id, auth_type, username, password)
VALUES ('6010-auth', 'userpass', '6010', 'supersecret');

INSERT INTO ps_aors (id, max_contacts)
VALUES ('6010', 1);

INSERT INTO ps_endpoints
  (id, transport, aors, auth, context, disallow, allow, dtmf_mode, direct_media)
VALUES
  ('6010', 'transport-udp', '6010', '6010-auth', 'from-internal',
   'all', 'ulaw', 'rfc4733', 'no');
```

Las tres filas juntas describen una cuenta SIP. El resto de los ajustes de la cuenta se distribuyen entre los objetos PJSIP: context, codecs, modo DTMF y manejo de medios residen en el endpoint (las últimas seis columnas anteriores); el registro dinámico reside en el AOR. No existe un indicador "dynamic" separado; un AOR acepta REGISTERs dinámicos siempre que `max_contacts` sea mayor que cero, y cada ubicación registrada se escribe en `ps_contacts`.

En PJSIP, el modo DTMF fuera de banda RFC 2833 / RFC 4733 se denomina `rfc4733`, y `dtmf_mode=rfc4733` es el valor predeterminado, por lo que la columna `dtmf_mode` anterior es opcional y se muestra solo para mayor claridad.

Paso 3: Intente registrar el nuevo teléfono con un softphone usando el nombre de usuario `6010` y la contraseña `supersecret`. Confirme el registro en la CLI de Asterisk:

```
asterisk-server*CLI> pjsip show endpoint 6010
asterisk-server*CLI> pjsip show contacts
```

Paso 4: Incluya las extensiones en la base de datos.

```
mysql -u astdb -p
```

Ingrese la contraseña:

Use supersecret cuando se le solicite, luego inserte la fila de la extensión desde el cliente MySQL:

```sql
USE astdb;
INSERT INTO extensions (id, context, exten, priority, app, appdata)
VALUES ('1', 'test', '6007', '1', 'Dial', 'PJSIP/bria');
```

Paso 5: Incluya Asterisk Real Time en el dialplan. En el context `default`:

```
switch => realtime/test@extensions
```

Recargue las extensiones para activar el cambio.

```
asterisk-server*CLI> extensions reload
```

Paso 6: Reconfigure uno de los teléfonos con el nombre de usuario `bria`, si aún no lo ha hecho.

Paso 7: Marque 6007 desde un teléfono existente; el teléfono `bria` debería sonar.

## Resumen

En este capítulo, usted ha aprendido que Asterisk Real Time le permite colocar sus configuraciones en una base de datos. Asterisk incluye controladores nativos de realtime para ODBC (que alcanza cualquier base de datos compatible con UnixODBC, incluyendo MySQL/MariaDB y SQLite) y PostgreSQL, además de un controlador realtime LDAP para backends de directorio. Se accede a MySQL/MariaDB a través de ODBC, como hicimos en este capítulo (también existe un complemento `res_config_mysql` dedicado, pero reside fuera de la compilación principal, por lo que ODBC es el camino común). La configuración se divide en estática y en tiempo real. La configuración estática reemplaza a los archivos de configuración, mientras que la configuración en tiempo real crea objetos dinámicos que se cargan solo cuando ocurre una llamada u otro evento relacionado. Concluimos con un laboratorio práctico sobre cómo instalar y configurar ARA.

## Cuestionario

1. Asterisk Realtime es parte de la distribución estándar de Asterisk.
   - A. Verdadero
   - B. Falso
2. Los parámetros de conexión de un servidor de base de datos se configuran en el archivo:
   - A. extensions.conf
   - B. pjsip.conf
   - C. res_odbc.conf
   - D. extconfig.conf
3. El archivo `extconfig.conf` configura las tablas utilizadas por Realtime. Tiene dos secciones distintas (marque dos):
   - A. Configuración estática
   - B. Configuración de Realtime
   - C. Rutas de salida
   - D. Direcciones IP y puertos de base de datos
4. En la configuración estática, una vez que los objetos se cargan desde la base de datos, se mantienen en la memoria de Asterisk y solo se actualizan al iniciar o recargar.
   - A. Verdadero
   - B. Falso
5. PJSIP realtime (Sorcery) es totalmente compatible con `qualify` y MWI para endpoints de realtime, porque Sorcery los carga como objetos PJSIP configurados ordinarios en lugar de descartarlos después de cada llamada como lo hacían los antiguos peers de SIP realtime.
   - A. Verdadero
   - B. Falso
6. En PJSIP realtime, ¿qué tablas contienen los endpoints y sus contactos registrados?
   - A. `ps_endpoints` y `ps_contacts`
   - B. `ps_peers` y `ps_registry`
   - C. `ps_config` y `ps_data`
   - D. `extconfig` y `res_odbc`
7. Todavía puede utilizar archivos de configuración de texto incluso después de habilitar ARA.
   - A. Verdadero
   - B. Falso
8. phpMyAdmin es obligatorio cuando utiliza Realtime.
   - A. Verdadero
   - B. Falso
9. La base de datos debe crearse con cada campo que exista en el archivo de configuración.
   - A. Verdadero
   - B. Falso
10. En Asterisk 22, ¿cuál es la forma recomendada y correcta según la versión para crear las tablas de PJSIP realtime (`ps_endpoints`, `ps_aors`, `ps_auths`, `ps_contacts`)?
    - A. Escribir manualmente las sentencias `CREATE TABLE` para cada tabla `ps_*`
    - B. Importar el `mysql_config.sql` heredado desde `contrib/realtime/`
    - C. Ejecutar las migraciones de Alembic `config` bajo `contrib/ast-db-manage` (`alembic -c config.ini upgrade head`)
    - D. Las tablas se crean automáticamente la primera vez que inicia Asterisk

**Respuestas:** 1 — A · 2 — C · 3 — A, B · 4 — A · 5 — A · 6 — A · 7 — A · 8 — B · 9 — B · 10 — C
