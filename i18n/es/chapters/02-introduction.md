# Introducción a Asterisk PBX

La popularidad de las distribuciones listas para usar como FreePBX e Issabel ha crecido recientemente. En este libro, cubriremos el Asterisk clásico, que es la base para comprender estas distribuciones. Asterisk PBX es un software de código abierto capaz de transformar una PC común en una potente PBX multiprotocolo. En este capítulo, aprenderemos sobre las posibilidades de esta nueva tecnología y su arquitectura básica.

## Objetivos

Al finalizar este capítulo, usted debería ser capaz de:

- Explicar qué es Asterisk y qué hace;
- Describir el papel de Digium™ y su sucesor Sangoma;
- Reconocer la arquitectura básica de Asterisk y sus componentes;
- Señalar varios escenarios de uso; y
- Identificar fuentes de información y ayuda.

## Qué es Asterisk

Asterisk es un software de PBX de código abierto que convierte una computadora común en una PBX con todas las funciones para usuarios domésticos, empresas, proveedores de servicios VoIP y compañías telefónicas. Asterisk es también tanto una comunidad de código abierto como un proyecto patrocinado por Sangoma Technologies (que adquirió Digium en 2018). Usted es libre de usar y modificar Asterisk para satisfacer sus necesidades. Asterisk permite la conectividad en tiempo real entre redes PSTN y VoIP. Dado que Asterisk es mucho más que una PBX, no solo obtiene una actualización excepcional para su PBX existente, sino que también puede hacer cosas nuevas en telefonía, tales como:

- Conectar a empleados que trabajan desde casa a una PBX de oficina a través de Internet de banda ancha;
- Conectar varias oficinas en diferentes lugares a través de una red IP, red privada o incluso a través de Internet mismo;
- Dar a sus empleados un voicemail integrado con la web y el correo electrónico;
- Construir aplicaciones como IVRs que permitan conexiones a su sistema de pedidos u otras aplicaciones;
- Dar a los usuarios que viajan acceso a la PBX de la empresa desde cualquier lugar con una simple conexión de banda ancha o VPN; y
- mucho más....

Asterisk incluye varios recursos avanzados que anteriormente solo se encontraban en sistemas de gama alta, tales como:

- Música para clientes en espera en colas de llamadas, soportando transmisión de medios y archivos MP3;
- Colas de llamadas, mediante las cuales un equipo de agentes puede responder llamadas y monitorear colas;
- Integración con texto a voz y reconocimiento de voz;
- Registros detallados transferidos tanto a archivos de texto como a bases de datos SQL; y
- Conectividad PSTN a través de líneas digitales y analógicas.

## ¿Qué es AsteriskNOW (histórico) y FreePBX

Asterisk en su forma más pura, también conocido como “classic asterisk” (denominación del paquete de Debian) es considerado más una herramienta de desarrollo que un producto terminado por sí mismo. AsteriskNOW fue una iniciativa para transformar Asterisk en un soft-appliance. La distribución incluía CentOS como sistema operativo y FreePBX como interfaz gráfica. AsteriskNOW ha sido descontinuado desde entonces.

Hoy en día, la distribución estándar llave en mano de Asterisk es **FreePBX** (mantenida por Sangoma), la cual agrupa a Asterisk con una GUI de administración basada en web y un ecosistema de módulos. FreePBX tiene licencia bajo la GPL y puede descargarse libremente desde www.freepbx.org. Para implementaciones comerciales, Sangoma también ofrece **FreePBX Distro** (una imagen completa de Linux) y su producto comercial **PBXact**.

## Rol de Digium™ y Sangoma

Digium, una empresa ubicada en Huntsville, Alabama, fue la creadora y principal desarrolladora de Asterisk desde su fundación en 1999. Además de ser el patrocinador principal del desarrollo de Asterisk, Digium produjo tarjetas de interfaz de telefonía y otro hardware para PBXs Asterisk, y creó productos comerciales como Switchvox (dirigido al mercado de las PyMEs). En 2018, Digium fue adquirida por **Sangoma Technologies**, una empresa canadiense de comunicaciones unificadas. Desde la adquisición, Sangoma ha continuado patrocinando el desarrollo de Asterisk y sirve como su administrador principal, manteniendo el proyecto de código abierto en www.asterisk.org.

Históricamente, Digium ofreció Asterisk bajo tres tipos de acuerdos de licencia:

- Asterisk con Licencia Pública General (GPL). Esta es la versión más utilizada. Incluye todas las funciones y es gratuita para ser utilizada y modificada de acuerdo con los términos de la licencia GPL.
- Asterisk Business Edition era una versión comercial de Asterisk. Algunas empresas utilizaban la edición empresarial porque no querían o no podían utilizar la licencia GPL, generalmente porque no deseaban publicar su código fuente junto con Asterisk. **Nota:** Asterisk Business Edition ha sido descontinuada; hoy en día, Asterisk se distribuye únicamente bajo la GPL.
- Licenciamiento OEM de Asterisk. Después de que Digium dejó de vender Asterisk Business Edition al por menor, continuó licenciando esa edición comercial a clientes OEM, es decir, proveedores de equipos que deseaban construir productos propietarios sobre Asterisk sin publicar su propio código fuente bajo la GPL.

### El proyecto Zapata y su relación con Asterisk

El proyecto Zapata fue desarrollado por Jim Dixon, quien también fue responsable del revolucionario diseño de hardware utilizado con Asterisk. El hardware también es de código abierto; como tal, puede ser utilizado por cualquier empresa, y hoy en día varios fabricantes producen tarjetas compatibles con esta arquitectura.

El proyecto Zapata produjo una arquitectura llamada Zaptel, renombrada posteriormente como DAHDI (Digium/Asterisk Hardware Device Interface). Uno de los principales beneficios de esta arquitectura es la capacidad de utilizar la CPU de la PC para procesar el flujo de medios, la cancelación de eco y la transcodificación. Por el contrario, la mayoría de las tarjetas existentes utilizan procesadores de señales digitales (DSP) para realizar estas tareas. El uso de la CPU de la PC en lugar de DSPs dedicados reduce drásticamente el precio de la tarjeta. Por lo tanto, estas tarjetas son significativamente más económicas que las interfaces disponibles anteriormente de otros fabricantes. Por otro lado, estas tarjetas requieren mucha CPU; un mal uso de la CPU de la PC puede afectar significativamente la calidad de la voz. Recientemente, Digium lanzó una tarjeta coprocesadora que utiliza DSPs para codificar y decodificar G.729 y G.723, permitiendo una mejor escalabilidad para un gran número de canales.

## ¿Por qué Asterisk?

Recuerdo mi primer contacto con Asterisk. Por lo general, la primera reacción ante algo nuevo —especialmente algo que compite con lo que ya conoces— ¡es rechazarlo! Esto es exactamente lo que sucedió en 2003. Asterisk estaba compitiendo con una solución que yo le estaba vendiendo a un cliente (un Gateway VoIP de 4 E1), y era diez veces menos costoso que lo que yo estaba cobrando por la solución que ya conocía. Este precio desproporcionado me llevó a comenzar a estudiar Asterisk para identificar posibles fallas e inconvenientes. Por ejemplo, descubrí que la CPU de las PC de aquel entonces no soportaría 120 sesiones simultáneas de g.729; al final del día, gané la propuesta con mi solución de Gateway.

Sin embargo, este ejercicio me llevó al descubrimiento de que Asterisk podía resolver una variedad de problemas muy costosos para mi base de clientes. Teníamos problemas con cotizaciones caras para IVR, mensajería unificada, grabación de llamadas y marcadores; con un dimensionamiento adecuado, los problemas de CPU podían evitarse. De hecho, en solo tres años Asterisk se convirtió en el producto estrella de mi empresa (de hecho, decidí abrir otra compañía solo para el negocio de Asterisk). En mi opinión, Asterisk es una revolución en las telecomunicaciones que representa para la telefonía IP lo que Apache representa para los servicios web.

### Reducción extrema de costos

Si comparas una PBX tradicional con Asterisk en lo que respecta a interfaces digitales y teléfonos, Asterisk es ligeramente más barato que esas PBX. Sin embargo, Asterisk realmente vale la pena cuando añades funciones avanzadas como voicemail, ACD, IVR y CTI. Con estas funciones avanzadas, Asterisk se vuelve significativamente menos costoso que las PBX tradicionales. De hecho, comparar PBX Asterisk con PBX analógicas de gama baja es injusto porque Asterisk ofrece muchas funciones que no están disponibles en los sistemas analógicos de gama baja.

### Control e independencia del sistema de telefonía

Uno de los beneficios de Asterisk más citados por los clientes es la independencia que proporciona. Algunos de los fabricantes actuales ni siquiera le dan al cliente la contraseña del sistema o la documentación de configuración. Con el enfoque de "hágalo usted mismo" de Asterisk, el usuario obtiene total libertad; como beneficio adicional, el usuario tiene acceso a una interfaz estándar.

### Entorno de desarrollo fácil y rápido

Asterisk puede extenderse utilizando lenguajes de script como PHP y Perl con interfaces AMI y AGI. Asterisk es de código abierto y su código fuente puede ser modificado por el usuario. El código fuente está escrito principalmente en el lenguaje de programación ANSI C.

### Rico en funciones

Asterisk tiene varias funciones que no se encuentran o son opcionales en las PBX tradicionales (por ejemplo, voicemail, CTI, ACD, IVR, música en espera integrada y grabación). Los costos de estas funciones en algunas plataformas superan el precio de la plataforma misma.

### Contenido dinámico en el teléfono

Asterisk está programado utilizando el lenguaje C y otros lenguajes comunes en el entorno de desarrollo actual. La posibilidad de proporcionar contenido dinámico es prácticamente ilimitada.

### Dialplan flexible y potente

Otro avance de Asterisk es su potente dialplan. En las PBX tradicionales, incluso funciones simples como el enrutamiento de menor costo (LCR) no son factibles o son opcionales. Con Asterisk, elegir la mejor ruta es fácil y limpio.

### Código abierto ejecutándose sobre Linux

Una de las mejores características de Asterisk es su comunidad. Hay varios recursos disponibles, incluida la documentación oficial de Asterisk (docs.asterisk.org), la wiki VoIP-Info mantenida por la comunidad (www.voip-info.org <http://www.voip-info.org>), listas de distribución de correo electrónico y foros. A medida que Asterisk es adoptado cada vez más, los errores se encuentran y corrigen rápidamente. Con una gran base de usuarios y un equipo de desarrollo activo, Asterisk se encuentra entre las plataformas PBX más probadas del mundo, lo que ayuda a mantener la base de código estable y madura.

### Limitaciones de la arquitectura de Asterisk

Algunas limitaciones en Asterisk provienen del uso del diseño de telefonía Zapata. En este diseño, Asterisk utiliza la CPU de la PC para procesar canales de voz en lugar de procesadores de señales digitales (DSPs) dedicados, los cuales son comunes en otras plataformas. Aunque esto permite una enorme reducción de costos en la interfaz de hardware, el sistema se vuelve dependiente de la CPU de la PC. Mi recomendación es ejecutar Asterisk en una máquina dedicada y ser conservador con el dimensionamiento del hardware. También puedes usar Asterisk en una VLAN separada para evitar transmisiones excesivas que consuman la CPU (tormentas de broadcast causadas por bucles o virus). Algunas tarjetas de interfaz más nuevas de varios proveedores ahora incluyen DSPs para procesar la cancelación de eco, codecs y otras funciones, lo que hará que Asterisk sea aún mejor.

## Principales objeciones a Asterisk PBX

Es común escuchar objeciones sobre la adopción de Asterisk, las cuales abordaremos aquí.

### La cuota de mercado de Asterisk es demasiado pequeña

La cuota de mercado generalmente se mide por la cantidad de PBXs vendidos. Estas estadísticas se obtienen habitualmente de los distribuidores más grandes. Asterisk es software libre que puede descargarse e implementarse sin que se registre ninguna venta, por lo que se subestima sistemáticamente en esas cifras. Aun así, Asterisk impulsa una base instalada muy grande en todo el mundo —desde PBXs de oficina de un solo servidor hasta grandes implementaciones de operadores y contact-center— y sigue siendo el motor dominante detrás del ecosistema de PBX de código abierto (incluyendo distribuciones listas para usar como FreePBX).

### Si es gratuito, ¿cómo sobrevive el fabricante?

En realidad, no existe un fabricante de software de código abierto en el sentido tradicional. Digium desarrolló Asterisk desde 1999, manteniéndose a través de las ventas de tarjetas de interfaz de telefonía, productos PBX comerciales como Switchvox y software relacionado. En 2018, Sangoma Technologies adquirió Digium. Sangoma continúa financiando el desarrollo de Asterisk y genera ingresos a través de productos comerciales (módulos comerciales de FreePBX, PBXact, Switchvox), ventas de hardware y servicios profesionales.

### ¡Es difícil encontrar soporte técnico!

Sangoma proporciona soporte técnico comercial para Asterisk a través de su ecosistema de socios y directamente mediante sus ofertas de productos. Una red global de profesionales certificados proporciona soporte de primera línea y servicios profesionales. El soporte de la comunidad sigue siendo activo a través de los foros de Asterisk y las listas de correo en www.asterisk.org.

### ¿Asterisk soporta más de 200 extensiones?

Sí, absolutamente. Un solo servidor Asterisk bien dimensionado puede manejar una gran cantidad de extensiones, y Asterisk escala aún más distribuyendo usuarios a través de múltiples servidores con balanceo de carga y failover, permitiendo grandes implementaciones multisitio.

### Solo los “geeks” son capaces de instalar Asterisk

Con FreePBX (disponible como una distribución independiente de Sangoma), incluso los profesionales con conocimientos limitados sobre Linux son capaces de instalar y configurar una PBX de complejidad media. Con la ayuda de una GUI, es posible configurar una PBX completa en solo unas pocas horas.

### ¿Qué pasa si el servidor falla?

Una de las principales ventajas de Asterisk es su capacidad para ejecutarse en sistemas tolerantes a fallos. Es relativamente simple y económico tener dos servidores ejecutándose en paralelo. ¡Te reto a intentar esto con una PBX convencional!

### Nuestra empresa no utiliza software de código abierto

Tu empresa probablemente utiliza software de código abierto sin siquiera darse cuenta. Varios dispositivos utilizan Linux como su sistema operativo. Además, el soporte comercial y las implementaciones gestionadas están disponibles a través de Sangoma y su red de socios certificados.

### No se recomienda utilizar la CPU de la PC para procesar señalización y medios

Asterisk utiliza la CPU del servidor para procesar la señalización y los medios para los canales de voz en lugar de tener DSPs dedicados. Aunque esto permite una reducción de costos de hasta cinco veces, hace que el sistema dependa del rendimiento de la CPU principal. Con el dimensionamiento correcto, Asterisk es capaz de manejar grandes volúmenes. Si aún deseas liberar a la CPU principal de estas tareas, también puedes utilizar cancelación de eco por hardware e incluso tarjetas transcodificadoras, como la TC400B de Sangoma (anteriormente Digium) basada en DSPs.

## Arquitectura de Asterisk

Esta sección explicará cómo funciona la arquitectura de Asterisk. La figura a continuación muestra la arquitectura básica de Asterisk. A continuación, explicaremos conceptos relacionados con la arquitectura, incluyendo canales, codec y aplicaciones.

![La arquitectura de Asterisk](../images/01-introduction-fig01.png)

### Canales

Un canal es el equivalente a una línea telefónica, pero en formato digital. Por lo general, consiste en un sistema de señalización analógico o digital (TDM) o una combinación de codec y protocolo de señalización (por ejemplo, SIP-GSM, IAX-uLaw). Inicialmente, todas las conexiones de telefonía eran analógicas y susceptibles al eco y al ruido. Más tarde, la mayoría de los sistemas se convirtieron a sistemas digitales, con el sonido analógico convertido a un formato digital utilizando modulación por impulsos codificados (PCM) en la mayoría de los casos. Este formato permite la transmisión de voz a 64 kilobits/segundo sin compresión.

Canales que se conectan con la Public Switched Telephone Network (PSTN):

- `chan_dahdi`: tarjetas TDM analógicas (FXO/FXS) y digitales (E1/T1/PRI) de Sangoma (anteriormente Digium), Xorcom y otros. Construido por separado contra DAHDI — vea el capítulo *Legacy channels*.

Canales que se conectan con Voice over IP:

- `chan_pjsip`: SIP — el controlador de canal SIP principal y único en Asterisk 22 LTS. Cadena de marcado: `PJSIP/endpoint_name`. (**Nota:** el antiguo `chan_sip` fue eliminado en Asterisk 21 y no existe en Asterisk 22. Vea *Building your first PBX with PJSIP* para la configuración.)
- `chan_iax2`: el protocolo IAX2 — todavía se incluye en Asterisk 22 pero es legacy; SIP/PJSIP es preferido para nuevas implementaciones. Cadena de marcado: `IAX2/peer`.
- `chan_unistim`: teléfonos Nortel/Avaya UNISTIM. Todavía disponible (soporte extendido) pero raramente utilizado.

Los canales VoIP más antiguos ya no forman parte de una compilación estándar de Asterisk 22: `chan_h323` (H.323) sobrevive solo como el complemento de la comunidad `ooh323`, y `chan_mgcp` (MGCP) y `chan_skinny` (Cisco SCCP) fueron declarados obsoletos y eliminados del conjunto de canales moderno. Si necesita interoperar con esos protocolos, el enfoque habitual es utilizar una pasarela frente a Asterisk.

Canales misceláneos:

- **Local**: un pseudo-canal (integrado en el núcleo) que vuelve al dialplan en un context diferente — útil para enrutamiento recursivo y para distribuir una llamada a múltiples destinos. Cadena de marcado: `Local/extension@context`.

### Codec y traducción de codec

Por lo general, intentamos colocar tantas conexiones de voz como sea posible en una red de datos. Los codec habilitan nuevas funciones en la voz digital, incluida la compresión, que es una de las características más importantes ya que permite tasas de compresión superiores a 8 a 1. Muchos codec también definen características como la detección de actividad de voz (supresión de silencio), ocultación de pérdida de paquetes y generación de ruido de confort, aunque Asterisk por sí mismo no genera ruido de confort ni realiza supresión de silencio. Varios codec están disponibles para Asterisk y pueden traducirse de forma transparente de uno a otro. Internamente, Asterisk utiliza slinear como formato de flujo cuando necesita convertir de un codec a otro. Algunos codec en Asterisk solo son compatibles en modo pass-through; estos codec no se pueden traducir. Para verificar qué codec están instalados en su sistema, puede utilizar el comando de consola:

```
CLI>core show translation
```

Los siguientes codec son compatibles:

- G.711 ulaw (EE. UU.) - (64 Kbps).
- G.711 alaw (Europa) - (64 Kbps).
- G.722 (Alta definición) – (64 Kbps)
- G.723.1 - Solo modo pass-through
- G.726 - (16/24/32/40kbps)
- G.729 - Módulo de codec binario distribuido por Sangoma; la descarga es gratuita, pero el uso legal requiere la compra de una licencia por canal (8Kbps)
- GSM - (12-13 Kbps)
- iLBC - (15 Kbps)
- LPC10 - (2.4 Kbps)
- Speex - (2.15-44.2 Kbps)
- Opus - (6-510 Kbps)

### Protocolos

Enviar datos de un teléfono a otro debería ser fácil siempre que los datos encuentren un camino hacia el otro teléfono por sí mismos. Desafortunadamente, no sucede de esta manera, y es necesario un protocolo de señalización para establecer conexiones entre teléfonos, descubrir dispositivos finales e implementar la señalización de telefonía. SIP es el protocolo de señalización dominante en las implementaciones modernas y es el único canal SIP disponible en Asterisk 22 LTS (a través de chan_pjsip). IAX2 todavía está disponible pero se considera legacy. Asterisk admite los siguientes protocolos.

- SIP — a través de `chan_pjsip`
- IAX2 — legacy, todavía se incluye en Asterisk 22
- UNISTIM — teléfonos Nortel/Avaya (soporte extendido)
- H.323, MGCP y SCCP (Cisco Skinny) — protocolos legacy que ya no están en una compilación estándar de Asterisk 22 (H.323 solo a través del complemento de la comunidad `ooh323`)

### Aplicaciones

Para conectar llamadas de un teléfono a otro, se utiliza la aplicación dial(). La mayoría de las funciones de Asterisk (por ejemplo, voicemail y conferencias) se implementan como aplicaciones. Puede ver las aplicaciones de Asterisk disponibles utilizando el comando de consola core show applications.

```
CLI>core show applications
```

Puede agregar aplicaciones desde complementos de Asterisk, proveedores externos o incluso aquellas que usted mismo desarrolle.

## Descripción general de un sistema Asterisk

Asterisk es una PBX de código abierto que actúa como una PBX híbrida, integrando tecnologías como TDM y telefonía IP. Asterisk está listo para implementar funcionalidades como respuesta de voz interactiva (IVR) y distribución automática de llamadas (ACD); además, como se mencionó anteriormente, está abierto al desarrollo de nuevas aplicaciones. Esta figura muestra cómo Asterisk se conecta a la PSTN y a PBXs existentes utilizando interfaces analógicas y digitales, además de admitir teléfonos analógicos e IP. Puede actuar como un SoftSwitch, gateway de medios, voicemail, y conferencias de audio, y también cuenta con música en espera integrada.

![Descripción general de un sistema Asterisk](../images/01-introduction-fig02.png)

## Comparando el viejo y el nuevo mundo

En el viejo modelo de SoftSwitch, todos los componentes se vendían por separado, lo que significaba que tenías que comprar cada componente individualmente y luego integrarlo al entorno de PBX o SoftSwitch. Los costos y riesgos eran altos y la mayor parte del equipo era propietario.

![El viejo mundo: componentes comprados e integrados por separado](../images/01-introduction-fig03.png)

### Telefonía usando Asterisk

Todas las funciones están integradas en la plataforma Asterisk en la misma o en diferentes cajas según el dimensionamiento, y todas tienen licencia GPL. A veces es más fácil instalar Asterisk que licenciar algunas de las IP-PBX convencionales.

![Telefonía usando Asterisk: las funciones están integradas](../images/01-introduction-fig04.png)

## Construcción de un sistema de prueba

Al implementar una solución Asterisk, nuestro primer paso es generalmente construir un sistema de prueba. El objetivo es una **1×1 PBX** mínima —un teléfono que pueda llamar a otro— para que pueda probar endpoints, dialplan y funciones antes de tocar el entorno de producción. Hoy en día esto es totalmente por software: no necesita ningún hardware de telefonía.

![Un sistema de prueba simple de Asterisk](../images/01-introduction-fig05.png)

### La forma moderna: un laboratorio de software (recomendado)

El sistema de prueba más rápido es Asterisk 22 ejecutándose en un contenedor o máquina virtual, con **softphones** para los endpoints y, opcionalmente, un **SIP trunk** para llegar a la red pública:

- **Asterisk 22** en una pequeña caja Linux, VM o contenedor Docker. Este libro incluye un laboratorio Docker listo para usar (vea la guía de laboratorio) que inicia un Asterisk 22 completamente configurado con un solo comando — sin compilación, sin hardware.
- **Dos softphones** registrados como endpoints PJSIP, para que pueda realizar una llamada real entre ellos. A lo largo de este libro utilizamos el **SipPulse Softphone** (descarga gratuita: <https://www.sippulse.com/produtos/softphone>), disponible para escritorio y móvil.
- **Un SIP trunk** (opcional) de un proveedor VoIP, para cuando desee llegar a la PSTN. Sin tarjeta y sin línea analógica — solo credenciales.

Así es como se construye y verifica cada ejemplo en este libro, y usted puede reproducirlo en cualquier computadora portátil.

### La forma tradicional: tarjetas analógicas/digitales

Antes de VoIP, una PBX de prueba necesitaba interfaces físicas: un puerto **FXO** para conectarse a una línea telefónica existente y un puerto **FXS** para conectar un teléfono analógico, lo que en conjunto le daba una 1×1 PBX. Una sola tarjeta que llevara una interfaz FXO y una FXS era el kit de inicio clásico. Estas tarjetas basadas en DAHDI (de Sangoma, anteriormente Digium) todavía existen para sitios que deben terminar líneas analógicas o T1/E1, pero hoy en día son un nicho — la mayoría de las implementaciones son puramente VoIP. Si solo necesita conectar teléfonos o líneas analógicas, consulte el capítulo *Legacy Channels*; de lo contrario, puede omitir el hardware de telefonía por completo.

## Escenarios de Asterisk

Asterisk puede utilizarse en varios escenarios diferentes. Enumeraremos algunos de ellos y explicaremos las ventajas y posibles limitaciones de cada uno.

### IP PBX

El escenario más común es la instalación de una nueva PBX o el reemplazo de una existente. Si compara Asterisk con otras alternativas, encontrará que es más económico y rico en funciones que la mayoría de las PBX disponibles actualmente en el mercado. Varias empresas están cambiando sus especificaciones a Asterisk en lugar de otras marcas de PBX.

![Asterisk como una IP PBX](../images/01-introduction-fig06.png)

### Habilitación IP para PBX heredadas

La siguiente imagen ilustra una de las configuraciones más utilizadas. Las grandes empresas generalmente no quieren asumir riesgos significativos al invertir en nuevas tecnologías y, al mismo tiempo, desean preservar sus inversiones en equipos heredados. La habilitación IP de una PBX heredada puede ser muy costosa; por lo tanto, conectar una PBX Asterisk mediante líneas T1/E1 puede ser una buena alternativa para clientes conscientes de los costos. Otro beneficio es la posibilidad de conectarse a un proveedor de servicios VoIP con mejores tarifas de telefonía.

![Habilitación IP para una PBX heredada](../images/01-introduction-fig07.png)

### Omisión de cargos de larga distancia (Toll Bypass)

Una aplicación muy útil para VoIP es conectar sucursales a través de Internet o una WAN. El uso de una conexión de datos existente le permite omitir los cargos de larga distancia incurridos en las conexiones de telecomunicaciones entre la sede central y las sucursales.

![Omisión de cargos de larga distancia entre oficinas a través de una WAN](../images/01-introduction-fig08.png)

### Servidor de aplicaciones (IVR, conferencias, voicemail)

Asterisk puede utilizarse como servidor de aplicaciones para una PBX existente o conectarse directamente a la PSTN. Asterisk ofrece servicios como voicemail, recepción de fax, grabación de llamadas, IVR conectado a una base de datos y un servidor de audioconferencias. Si integra el voicemail y el fax en un servidor de correo electrónico existente, tendrá un sistema de mensajería unificada, que suele ser una solución costosa. El uso de Asterisk como servidor de aplicaciones proporciona una reducción de costos extrema en comparación con otras soluciones.

![Asterisk como servidor de aplicaciones](../images/01-introduction-fig09.png)

### Media Gateway

La mayoría de los proveedores de servicios de voz sobre IP utilizan un proxy SIP para alojar todo el registro, la ubicación y la autenticación de los usuarios SIP. Aún así, deben enviar llamadas a la PSTN directamente o enrutarlas a través de un proveedor de terminación de llamadas mayorista utilizando una conexión de voz sobre IP SIP o H.323. Asterisk puede actuar como un back-to-back user agent (B2BUA) o media gateway, reemplazando SoftSwitch o media gateways muy costosos. Compare el precio de un gateway de cuatro E1/T1 de los principales fabricantes del mercado con Asterisk. La solución Asterisk puede costar varias veces menos que otras soluciones y es capaz de traducir protocolos de señalización (H.323, SIP, IAX…) y codec (G.711, G.729…).

![Asterisk como media gateway](../images/01-introduction-fig10.png)

### Plataforma de Contact Center

Un contact center es una solución muy compleja que combina varias tecnologías, como la distribución automática de llamadas (ACD), el IVR y la supervisión de llamadas. Básicamente, existen tres tipos de contact centers: entrantes (inbound), salientes (outbound) y combinados (blended).

Los contact centers entrantes son muy sofisticados y generalmente requieren ACD, IVR, CTI, grabación, supervisión e informes. Asterisk tiene un ACD integrado para poner las llamadas en cola. El IVR se puede realizar utilizando Asterisk Gateway Interface (AGI) o mecanismos internos como la aplicación background(). La integración de telefonía informática (CTI) se logra utilizando Asterisk Manager Interface (AMI); la grabación y los informes están integrados en Asterisk.

Para un contact center saliente, un marcador predictivo o automático es uno de los componentes principales. Aunque hay varios marcadores disponibles para el Asterisk de código abierto, no es difícil construir el suyo propio para la plataforma si así lo desea. Un contact center combinado permite la operación simultánea de entrada y salida, ahorrando dinero al garantizar un mejor uso del tiempo del agente. Es posible utilizar Asterisk y su mecanismo ACD para implementar una solución combinada.

![Una plataforma de contact center Asterisk](../images/01-introduction-fig11.png)

## Cómo encontrar información y ayuda

Esta sección proporcionará algunas de las principales fuentes de información relacionadas con Asterisk.

- Sitio web oficial de Asterisk: <https://www.asterisk.org> Aquí puede encontrar información sobre:
- Documentación y Wiki -> <https://docs.asterisk.org>
- Foro de la comunidad -> <https://community.asterisk.org>
- Seguimiento de errores -> <https://github.com/asterisk/asterisk/issues>
- Wiki (legado, reemplazada en gran medida por docs.asterisk.org) -> <https://wiki.asterisk.org>

### Foro de la comunidad

El foro de la comunidad de Asterisk ha reemplazado en gran medida a las antiguas listas de correo y es el lugar para hacer preguntas. Intente reunir la mayor cantidad de información posible antes de publicar. Nadie le ayudará si no ha hecho su tarea; intente al menos una vez resolver el problema por su cuenta.

- <https://community.asterisk.org>

## Resumen

Asterisk es un software con licencia GPL que permite que una PC común actúe como una potente plataforma IP PBX. Mark Spencer, de Digium, creó Asterisk a finales de la década de 1990, y Digium se mantuvo vendiendo hardware y productos comerciales relacionados con Asterisk. Digium fue adquirida por Sangoma Technologies en 2018; Sangoma ahora patrocina el desarrollo de Asterisk. El diseño de la interfaz de hardware se originó en el proyecto Zapata desarrollado por Jim Dixon, el cual dio lugar a DAHDI.

La arquitectura de Asterisk tiene los siguientes componentes principales:

- CHANNELS: Analógicos, digitales o de voz sobre IP. En Asterisk 22 LTS, SIP es manejado exclusivamente por `chan_pjsip`.
- PROTOCOLS: Protocolos de comunicación, los cuales son responsables de la señalización de las llamadas, incluyendo SIP (vía PJSIP), H.323, MGCP e IAX2.
- CODECS: Traducen formatos digitales de voz permitiendo la compresión y la ocultación de pérdida de paquetes. Tenga en cuenta que Asterisk por sí mismo no realiza supresión de silencio (detección de actividad de voz) ni generación de ruido de confort; cuando los endpoints utilizan VAD, el ruido de confort debe desactivarse en el lado del cliente.
- APPLICATIONS: Responsables de la funcionalidad de la PBX de Asterisk. Conferencia, voicemail y fax son ejemplos de aplicaciones de Asterisk.

Asterisk puede utilizarse en diversos escenarios, desde una pequeña IP PBX hasta un sofisticado contact center. Puede encontrar ayuda fácilmente en www.asterisk.org y docs.asterisk.org.

## Cuestionario

1. ¿Qué empresa adquirió a Digium en 2018 y ahora funge como el administrador principal del proyecto de código abierto Asterisk?
   - A. Cisco Systems
   - B. Sangoma Technologies
   - C. Nortel Networks
   - D. Red Hat

2. En Asterisk 22 LTS, ¿qué controlador de canal proporciona conectividad SIP?
   - A. `chan_sip`
   - B. `chan_skinny`
   - C. `chan_pjsip`
   - D. `chan_h323`

3. Verdadero o Falso: El controlador de canal `chan_sip` fue eliminado en Asterisk 21 y no está presente en una compilación estándar de Asterisk 22.

4. ¿Cuáles de los siguientes canales/protocolos **ya no** forman parte de una compilación estándar de Asterisk 22? (Elija todas las que apliquen.)
   - A. MGCP (`chan_mgcp`)
   - B. SCCP / Cisco Skinny (`chan_skinny`)
   - C. IAX2 (`chan_iax2`)
   - D. H.323 (`chan_h323`, que sobrevive solo como el complemento comunitario `ooh323`)

5. La arquitectura de hardware del proyecto Zapata, originalmente llamada Zaptel, fue renombrada posteriormente como ____.
   - A. DAHDI
   - B. PJSIP
   - C. PRI
   - D. mISDN

6. Cuando Asterisk debe convertir audio de un codec a otro, ¿a través de qué formato de flujo interno realiza la traducción?
   - A. G.711 ulaw
   - B. GSM
   - C. slinear (signed linear)
   - D. Opus

7. Según el capítulo, ¿cuál es la situación de licenciamiento del módulo de codec G.729 distribuido por Sangoma?
   - A. Es GPL y completamente gratuito para cualquier uso.
   - B. La descarga es gratuita, pero el uso legal requiere la compra de una licencia por canal.
   - C. No se puede obtener en absoluto sin comprar Asterisk Business Edition.
   - D. Solo funciona en modo pass-through y no se puede instalar.

8. ¿Qué aplicación de Asterisk se utiliza para puentear una llamada de un teléfono a otro?
   - A. `Background()`
   - B. `Dial()`
   - C. `Queue()`
   - D. `Goto()`

9. ¿Qué es el canal `Local` en Asterisk?
   - A. Una interfaz FXS de hardware para teléfonos analógicos.
   - B. Un trunk SIP hacia un proveedor de servicios local.
   - C. Un pseudo-canal que redirige una llamada de vuelta al dialplan en un context diferente.
   - D. Un codec utilizado para llamadas on-net.

10. ¿En qué escenario de uso actúa Asterisk como un back-to-back user agent (B2BUA), traduciendo entre protocolos de señalización y codecs para reemplazar costosos SoftSwitch?
    - A. Habilitación IP de una PBX heredada
    - B. Toll bypass
    - C. Media Gateway
    - D. Plataforma de Contact Center

**Respuestas:** 1 — B · 2 — C · 3 — Verdadero · 4 — A, B, D · 5 — A · 6 — C · 7 — B · 8 — B · 9 — C · 10 — C
