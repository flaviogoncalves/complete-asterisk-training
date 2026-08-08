```{=latex}
\frontmatter
```

## Copyright {.unnumbered}

*Asterisk Guide* — Zweite Ausgabe (Asterisk 22 LTS)

Copyright © 2006–2026 Flavio E. Gonçalves. Alle Rechte vorbehalten.

Kein Teil dieses Buches darf ohne die vorherige schriftliche Zustimmung des Autors in irgendeiner Form oder mit irgendwelchen Mitteln vervielfältigt, in einem Datenabrufsystem gespeichert oder übertragen werden, mit Ausnahme kurzer Auszüge, die in veröffentlichten Rezensionen verwendet werden.

**Ausgabe:** Zweite Ausgabe.

> **[author TODO]** Weisen Sie eine neue ISBN für die 2. Ausgabe zu (verwenden Sie nicht die 1st-ed 9781796396973 erneut) und legen Sie das Veröffentlichungsdatum vor dem Druck fest.

Viele der Bezeichnungen, die von Herstellern und Verkäufern zur Unterscheidung ihrer Produkte verwendet werden, werden als Marken beansprucht. Wo diese Bezeichnungen in diesem Buch erscheinen und der Autor sich eines Markenanspruchs bewusst war, wurden sie in Großbuchstaben oder mit Anfangsbuchstaben in Großschreibung gedruckt. Asterisk, Digium, IAX und DUNDi sind Marken von Sangoma Technologies (Digium wurde 2018 von Sangoma übernommen; Asterisk wird heute von Sangoma gesponsert).

Obwohl bei der Erstellung dieses Buches mit größter Sorgfalt vorgegangen wurde, übernimmt der Autor keine Verantwortung für Fehler oder Auslassungen oder für Schäden, die aus der Verwendung der hierin enthaltenen Informationen resultieren.

## Vorwort {.unnumbered}

Dieses Buch richtet sich an alle, die lernen möchten, wie man eine PBX (Private Branch Exchange) auf Basis von Asterisk 22 LTS installiert und konfiguriert. Asterisk ist eine Open-Source-Telefonieplattform, die eine Brücke zwischen VoIP und traditionellen TDM-Kanälen schlägt.

Dies ist die fünfte Generation eines Buches, das ursprünglich als *Asterisk Configuration Guide* begann. Das Material entstand aus der Arbeit, die ich 2006 zur Vorbereitung auf die Digium dCAP-Zertifizierung geleistet habe – die ich im ersten Anlauf bestand – und wurde seitdem mehr als tausend Schülern vermittelt.

Das Konzept der Open-Source-PBX ist revolutionär. Über Jahrzehnte hinweg wurde die Telefonie von einer Handvoll Unternehmen dominiert, die teure proprietäre Systeme verkauften. Asterisk gab diese Macht zurück in die Hände der Anwender: Funktionen, die einst wirtschaftlich unerreichbar waren – CTI (computer-telephony integration), IVR (interactive voice response), ACD (automatic call distribution), voicemail und vieles mehr – stehen heute jedem zur Verfügung, der über einen Linux-Rechner und die Bereitschaft zu lernen verfügt.

Dieses Buch wird Sie nicht von allein zu einem Guru machen – das kann kein Buch – aber am Ende werden Sie in der Lage sein, eine echte PBX mit erweiterten Funktionen aufzubauen und zu betreiben. Das Buch hat einen Begleiter – praktische Übungen und einen Online-Kurs – unter **VoIP School Blackbelt** (<https://voip.school>).

## Zielgruppe {.unnumbered}

Dieses Buch richtet sich an Leser, die neu bei Asterisk sind. Ich setze voraus, dass Sie mit Linux vertraut sind — der Shell, einem Texteditor und grundlegender Systemadministration. Sie können die Beispiele auf einem Linux-Desktop nachvollziehen, falls dies während des Lernens einfacher für Sie ist; eine virtuelle Maschine ist für die Übungen ebenfalls in Ordnung (erwarten Sie jedoch eine etwas schlechtere Sprachqualität). Für Produktivsysteme empfehle ich nicht, Asterisk in einer Desktop-Umgebung oder innerhalb einer schwach ausgestatteten VM zu betreiben. Etwas Vertrautheit mit IP-Netzwerken, Voice over IP (VoIP) und grundlegenden Telefoniekonzepten ist hilfreich.

## Was ist neu in der zweiten Auflage {.unnumbered}

Die zweite Auflage ist eine grundlegende Modernisierung für **Asterisk 22 LTS** (veröffentlicht 2024, unterstützt bis Oktober 2028). Die wichtigsten Änderungen:

- **PJSIP ist der einzige SIP-Kanal.** `chan_sip` wurde in Asterisk 21 entfernt und existiert in 22 nicht mehr. Jedes SIP-Beispiel verwendet nun PJSIP (`pjsip.conf`); das alte `sip.conf`-Material wird nur noch als Migrationsreferenz beibehalten.
- **Sangoma-Verwaltung.** Digium wurde 2018 von Sangoma übernommen; das Projekt wird nun von Sangoma entwickelt und gesponsert, was sich durchgehend im Text widerspiegelt.
- **Drei neue Kapitel.** *WebRTC with Asterisk* (Browser-Telefone über WSS/DTLS-SRTP), *SIP trunking, DID & the PSTN* sowie *Deployment, monitoring & scaling*.
- **Ein reproduzierbares Labor.** Jede Konfiguration und jeder Befehl im Buch wurde anhand eines Asterisk 22 Docker-Labors verifiziert, das Sie selbst ausführen können.
- **Modernisierte Funktionen.** ConfBridge ersetzt die alte MeetMe-Konferenzfunktion, ARI wird neben AMI/AGI eingeführt, PJSIP Realtime (Sorcery) wird behandelt, und die Kapitel zu Installation, Sicherheit und CDR wurden auf den neuesten Stand gebracht.
- **Eine neue Struktur.** Das Buch ist nun in vier Teile gegliedert — Foundations, Channels & Connectivity, Dialplan & Call Features sowie Integration & Operations.

## Über den Autor {.unnumbered}

Flavio E. Gonçalves wurde 1966 in Brasilien geboren. Er hegt ein starkes Interesse an Computern, seit er 1983 seinen ersten PC erhielt, und erwarb 1989 einen Ingenieursabschluss mit Schwerpunkt auf computergestütztem Design und Fertigung. Er ist CEO von SipPulse in Brasilien, einem Unternehmen, das sich auf SoftSwitch, SBC und mandantenfähige PBXs spezialisiert hat.

Im Laufe seiner Karriere hat er eine lange Liste von Zertifizierungen erworben – darunter Novell MCNE/MCNI, Microsoft MCSE/MCT, Cisco CCSP/CCNP/CCDP und Asterisk dCAP. Er begann über Open-Source-Software zu schreiben, weil er davon überzeugt ist, dass die strukturierte Art und Weise, wie Zertifizierungen einst ihr Material vermittelten, eine großartige Lernmethode ist. Er hat auf mehr als 25 Jahre Unterrichtserfahrung zurückgegriffen, um so zu schreiben, wie Menschen tatsächlich lernen, anstatt dies rein aus einem technischen Standpunkt heraus zu tun.

Flavio ist zweifacher Vater und lebt in Florianópolis, Brasilien – einem der schönsten Orte der Welt –, wo er seine Freizeit mit Surfen und Segeln verbringt.

## Feedback, Credits & Training {.unnumbered}

Ich bemühe mich sehr, Fehler zu finden und zu beseitigen, aber einige schlüpfen immer durch. Wenn Sie etwas Falsches finden, lassen Sie es mich bitte wissen, und ich werde mich darum kümmern.

Dieses Buch wird auch als Schulungsmaterial verwendet. Wenn Sie es in Ihrem eigenen Schulungszentrum verwenden oder den begleitenden Online-Kurs und die Labs absolvieren möchten, besuchen Sie **VoIP School Blackbelt** unter <https://voip.school> oder senden Sie eine E-Mail an <flavio@voip.school>.

**Credits.** Cover-Gestaltung: Karla Braga. Korrektoren: Luis F. Gonçalves, Guilherme Goes (dCAP) sowie professionelle Lektoren. Mein Dank gilt auch den vielen Studenten, deren Feedback über die Jahre hinweg dieses Material geprägt hat, sowie meiner Familie für ihre Unterstützung.

```{=latex}
\cleardoublepage
```
