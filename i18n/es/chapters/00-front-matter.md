```{=latex}
\frontmatter
```

## Copyright {.unnumbered}

*Asterisk Guide* — Segunda edición (Asterisk 22 LTS)

Copyright © 2006–2026 Flavio E. Gonçalves. Todos los derechos reservados.

Ninguna parte de este libro puede ser reproducida, almacenada en un sistema de recuperación o transmitida de ninguna forma o por ningún medio sin el consentimiento previo por escrito del autor, excepto para breves extractos utilizados en reseñas publicadas.

**Edición:** Segunda edición.

> **[author TODO]** Asigne un nuevo ISBN para la segunda edición (no reutilice el ISBN de la primera edición 9781796396973) y establezca la fecha de publicación antes de la impresión.

Muchas de las designaciones utilizadas por los fabricantes y vendedores para distinguir sus productos son reclamadas como marcas comerciales. Cuando esas designaciones aparecen en este libro y el autor tenía conocimiento de una reclamación de marca comercial, se han impreso en mayúsculas o con iniciales en mayúsculas. Asterisk, Digium, IAX y DUNDi son marcas comerciales de Sangoma Technologies (Digium fue adquirida por Sangoma en 2018; Asterisk ahora es patrocinado por Sangoma).

Aunque se han tomado todas las precauciones en la preparación de este libro, el autor no asume ninguna responsabilidad por errores u omisiones, ni por los daños resultantes del uso de la información contenida en el mismo.

## Prefacio {.unnumbered}

Este libro es para cualquiera que desee aprender a instalar y configurar una PBX (Private Branch Exchange) basada en Asterisk 22 LTS. Asterisk es una plataforma de telefonía de código abierto que sirve de puente entre VoIP y los canales TDM tradicionales.

Esta es la quinta generación de un libro que comenzó como la *Asterisk Configuration Guide*. El material surgió del trabajo que realicé para prepararme para la certificación dCAP de Digium en 2006 —la cual aprobé en el primer intento— y desde entonces se ha enseñado a más de mil estudiantes.

El concepto de PBX de código abierto es revolucionario. Durante décadas, la telefonía estuvo dominada por un puñado de empresas que vendían costosos sistemas propietarios. Asterisk devolvió ese poder a manos de los usuarios: funciones que antes eran económicamente inalcanzables —CTI (computer-telephony integration), IVR (interactive voice response), ACD (automatic call distribution), voicemail y mucho más— ahora están disponibles para cualquiera que tenga una máquina con Linux y la disposición de aprender.

Este libro no lo convertirá en un gurú por sí solo —ningún libro puede hacerlo—, pero al finalizarlo usted será capaz de construir y operar una PBX real con funciones avanzadas. El libro tiene un complemento —laboratorios prácticos y un curso en línea— en **VoIP School Blackbelt** (<https://voip.school>).

## Audience {.unnumbered}

Este libro está dirigido a lectores que son nuevos en Asterisk. Asumo que se siente cómodo con Linux: la shell, un editor de texto y la administración básica del sistema. Puede seguir los ejemplos en un escritorio Linux si le resulta más fácil mientras aprende, y una máquina virtual es adecuada para los laboratorios (espere una calidad de voz ligeramente inferior). Para sistemas en producción, no recomiendo ejecutar Asterisk en un entorno de escritorio o dentro de una VM con pocos recursos. Tener cierta familiaridad con redes IP, Voice over IP (VoIP) y conceptos básicos de telefonía será de ayuda.

## Novedades en la segunda edición {.unnumbered}

La segunda edición es una modernización exhaustiva para **Asterisk 22 LTS** (lanzada en 2024, con soporte hasta octubre de 2028). Los cambios principales son:

- **PJSIP es el único canal SIP.** `chan_sip` fue eliminado en Asterisk 21 y no existe en 22. Cada ejemplo de SIP ahora utiliza PJSIP (`pjsip.conf`); el material heredado de `sip.conf` se conserva únicamente como referencia de migración.
- **Administración de Sangoma.** Digium fue adquirida por Sangoma en 2018; el proyecto ahora es desarrollado y patrocinado por Sangoma, y el texto refleja esto en todo momento.
- **Tres capítulos nuevos.** *WebRTC with Asterisk* (teléfonos de navegador sobre WSS/DTLS-SRTP), *SIP trunking, DID & the PSTN*, y *Deployment, monitoring & scaling*.
- **Un laboratorio reproducible.** Cada configuración y comando en el libro está verificado contra un laboratorio Docker de Asterisk 22 que usted mismo puede ejecutar.
- **Funciones modernizadas.** ConfBridge reemplaza a la antigua conferencia MeetMe, se introduce ARI junto con AMI/AGI, se cubre PJSIP Realtime (Sorcery), y los capítulos de instalación, seguridad y CDR han sido actualizados.
- **Una nueva estructura.** El libro ahora está organizado en cuatro partes: Fundamentos, Canales y Conectividad, Dialplan y Funciones de Llamada, e Integración y Operaciones.

## Sobre el autor {.unnumbered}

Flavio E. Gonçalves nació en 1966 en Brasil. Ha tenido un gran interés por las computadoras desde que obtuvo su primera PC en 1983, y obtuvo un título en ingeniería en 1989 con un enfoque en diseño y fabricación asistidos por computadora. Es el CEO de SipPulse en Brasil, una empresa dedicada a SoftSwitch, SBC y PBX multi-inquilino.

A lo largo de su carrera ha obtenido una larga lista de certificaciones: Novell MCNE/MCNI, Microsoft MCSE/MCT, Cisco CCSP/CCNP/CCDP y Asterisk dCAP, entre otras. Comenzó a escribir sobre software de código abierto porque cree que la forma estructurada en la que las certificaciones enseñaban su material es una excelente manera de aprender, y ha aprovechado más de 25 años de experiencia docente para escribir pensando en cómo aprenden realmente las personas, en lugar de hacerlo puramente desde un punto de vista técnico.

Flavio es padre de dos hijos y vive en Florianópolis, Brasil —uno de los lugares más hermosos del mundo—, donde pasa su tiempo libre practicando surf y navegación a vela.

## Comentarios, créditos y capacitación {.unnumbered}

Me esfuerzo mucho por encontrar y eliminar errores, pero algunos siempre se escapan. Si encuentra algo incorrecto, por favor hágamelo saber y tomaré medidas al respecto.

Este libro también se utiliza como material de capacitación. Si desea utilizarlo en su propio centro de capacitación, o tomar el curso en línea y los laboratorios complementarios, visite **VoIP School Blackbelt** en <https://voip.school> o envíe un correo electrónico a <flavio@voip.school>.

**Créditos.** Diseño de portada: Karla Braga. Revisores: Luis F. Gonçalves, Guilherme Goes (dCAP) y correctores de estilo profesionales. Mi agradecimiento también a los muchos estudiantes cuyos comentarios a lo largo de los años han dado forma a este material, y a mi familia por su apoyo.

```{=latex}
\cleardoublepage
```
