# Fortgeschrittene Funktionen des dialplan

Kapitel 3 behandelte die Grundlagen eines dialplan. Aus didaktischen Gründen haben wir nicht alle Funktionen erklärt, sondern nur einige der wichtigsten. Dieses Kapitel wird tiefer in den dialplan eintauchen und fortgeschrittene Techniken, neue Anwendungen und Konzepte beschreiben.

## Ziele

Am Ende dieses Kapitels sollten Sie in der Lage sein:

- Ihre extension-Einträge zu vereinfachen
- Die Sicherheit des dialplan zu adressieren und extensions zu filtern
- Anrufe mithilfe eines IVR-Menüs entgegenzunehmen
- Subroutinen zu verwenden, um unnötige Neuschreibungen zu vermeiden
- Dialplan-Sicherheit mithilfe von „Include“ zu implementieren
- Follow-me mithilfe der AsteriskDB zu implementieren
- Verhalten für außerhalb der Geschäftszeiten in Ihrer PBX zu implementieren
- Den switch-Befehl zu verwenden, um an eine andere PBX weiterzuleiten
- Den Privacy Manager zu implementieren
- Voicemail zu implementieren
- Ein Unternehmensverzeichnis zu implementieren

## Vereinfachung Ihres Dialplan

Sie können Ihren Dialplan vereinfachen, indem Sie das Schlüsselwort „same“ verwenden, um eine Extension zu definieren. Dies sollte die Anzahl der Tippfehler im Dialplan reduzieren. Sehen Sie sich das folgende Beispiel an:

```
exten => 4000,1,NoOp()
same  =>      n,Dial(PJSIP/005C2B313E22)
```

## Sicherheit im Dialplan

Es wurde eine Schwachstelle im Asterisk Dialplan entdeckt, die es einem Benutzer ermöglicht, einen neuen Kanal und eine Rufnummer in Ihren Dialplan einzuschleusen. Nehmen wir an, Sie haben die folgende Zeile auf Ihrem Server `exten=>_X.,1,Dial(PJSIP/${EXTEN})` und ein böswilliger Benutzer wählt die Nummer `3000&DAHDI/1/011551123456789` im softphone. Das SIP-Protokoll akzeptiert standardmäßig alle alphanumerischen Zeichen, sodass die gewählte extension tatsächlich zwei Anrufe auslöst: einen für den Kanal PJSIP/3000 und den anderen für den Kanal DAHDI/011551123456789, bei dem es sich um eine internationale Nummer handelt. Somit kann jeder Benutzer mit Zugriff auf eine extension tatsächlich überall auf der Welt anrufen. Der einfachste Weg, dieses Verhalten zu vermeiden, besteht darin, die Nummern zu filtern, bevor die dial-Anwendung aufgerufen wird. Die Funktion FILTER() ist hierfür sehr nützlich. Beispiel:

```
exten=>_X.,1,DIAL(PJSIP/${FILTER(0-9,${EXTEN})})
```

Die Anwendung filter ermöglicht es Ihnen, alle Zeichen aus der gewählten Nummer mit Ausnahme der Zahlen 0 bis 9 herauszufiltern. Weitere Informationen finden Sie in der Datei README-SERIOUSLY.bestpractices.txt, die von Asterisk bereitgestellt wird.

## Anrufe über ein IVR-Menü entgegennehmen.

Im letzten Abschnitt haben Sie alle Anrufe über DID oder durch Weiterleitung an den Operator entgegengenommen. Jetzt lernen Sie, wie man ein IVR-Menü implementiert und einen automatischen Vermittlungsdienst erstellt. Bevor wir uns den Details zuwenden, betrachten wir einige neue Anwendungen. Wir haben die Ausgabe des Befehls `core show application` unten eingefügt, um es den Lesern einfacher zu machen. Sie können diese Beschreibungen selbst über `core show application <application_name>` abrufen.

### Die Anwendung Background()

Diese Anwendung spielt die angegebene Liste von Dateien ab, während sie darauf wartet, dass der anrufende Kanal eine extension wählt. Um nach dem Abspielen der Dateien weiterhin auf Ziffern zu warten, sollte die Anwendung WaitExten verwendet werden. Die Option langoverride gibt explizit an, welche Sprache für die angeforderten Sounddateien verwendet werden soll. Jeder angegebene context ist der dialplan-context, den diese Anwendung beim Wechsel zu einer gewählten extension verwendet. Wenn eine der angeforderten Sounddateien nicht existiert, wird die Anrufverarbeitung beendet. Optionen:

- s - Bewirkt, dass das Abspielen der Nachricht übersprungen wird, wenn sich der Kanal nicht im Zustand 'up' befindet (d. h. er wurde noch nicht beantwortet). Wenn dies geschieht, kehrt die Anwendung sofort zurück.
- n - Den Kanal nicht beantworten, bevor die Dateien abgespielt werden.
- m - Nur unterbrechen, wenn eine gewählte Ziffer mit einer einstelligen extension im Ziel-context übereinstimmt.

### Die Anwendung Record()

Diese Anwendung nimmt vom Kanal in einen angegebenen Dateinamen auf. Wenn die Datei existiert, wird sie überschrieben.

![10-dialplan-advanced-features figure 1](../images/10-dialplan-advanced-features-img01.png)

- 'format' ist das Format des Dateityps, der aufgezeichnet werden soll (wav, gsm, etc.).
- 'silence' ist die Anzahl der Sekunden Stille, die erlaubt ist, bevor die Anwendung zurückkehrt.
- 'maxduration' ist die maximale Aufnahmedauer in Sekunden; wenn dieser Wert fehlt oder null ist, gibt es kein Maximum.
- 'options' kann einen der folgenden Buchstaben enthalten:
    - `a` — hängt die Aufnahme an eine bestehende Datei an, anstatt sie zu ersetzen
    - `n` — nicht beantworten, aber trotzdem aufzeichnen, falls die Leitung noch nicht beantwortet wurde
    - `q` — leise (keinen Piepton abspielen)
    - `s` — überspringt die Aufnahme, wenn die Leitung noch nicht beantwortet wurde
    - `t` — verwendet die alternative `*` Abbruchtaste (DTMF) anstelle der Standardtaste `#`
    - `x` — ignoriert alle Abbruchtasten (DTMF) und nimmt bis zum Auflegen auf

Wenn der Dateiname %d enthält, werden diese Zeichen jedes Mal, wenn die Datei aufgenommen wird, durch eine um eins erhöhte Zahl ersetzt. Verwenden Sie core show file formats, um die auf Ihrem System verfügbaren Formate anzuzeigen. Der Benutzer kann # drücken, um die Aufnahme zu beenden und mit der nächsten Priorität fortzufahren. Wenn der Benutzer während einer Aufnahme auflegt, gehen alle Daten verloren und die Anwendung wird beendet.

### Die Anwendung Playback()

Diese Anwendung spielt angegebene Dateinamen ab (ohne Dateiendung). Optionen können ebenfalls nach einem Pipe-Symbol eingefügt werden. Die Option 'skip' bewirkt, dass das Abspielen der Nachricht übersprungen wird, wenn sich der Kanal nicht im Zustand 'up' befindet (d. h. noch nicht beantwortet wurde).

![10-dialplan-advanced-features figure 2](../images/10-dialplan-advanced-features-img02.png)

![10-dialplan-advanced-features figure 3](../images/10-dialplan-advanced-features-img03.png)

Wenn 'skip' angegeben ist, kehrt die Anwendung sofort zurück, falls der Kanal nicht abgenommen wurde. Andernfalls wird der Kanal beantwortet, bevor der Ton abgespielt wird, es sei denn, 'noanswer' ist angegeben. Nicht alle Kanäle unterstützen das Abspielen von Nachrichten, während der Hörer noch aufgelegt ist. Wenn 'j' angegeben ist, springt die Anwendung zur Priorität n+101, falls die Datei nicht existiert und die Priorität vorhanden ist. Diese Anwendung setzt nach Abschluss die folgende Kanalvariable:

- PLAYBACKSTATUS — der Status des Wiedergabeversuchs als Textzeichenfolge, einer der folgenden:
    - `SUCCESS`
    - `FAILED`

### Die Anwendung Read()

Diese Anwendung liest eine vorbestimmte Anzahl von Ziffernfolgen, eine bestimmte Anzahl von Malen, vom Benutzer in die angegebene Variable ein.

- filename -- Datei, die vor dem Lesen von Ziffern oder einem Ton mit der Option i abgespielt werden soll
- maxdigits -- maximal zulässige Anzahl von Ziffern. Stoppt das Lesen, nachdem maxdigits eingegeben wurden (ohne dass der Benutzer die Taste # drücken muss). Standard ist 0 - kein Limit - um darauf zu warten, dass der Benutzer die Taste # drückt. Jeder Wert unter 0 bedeutet dasselbe. Der maximal akzeptierte Wert ist 255.

![10-dialplan-advanced-features figure 4](../images/10-dialplan-advanced-features-img04.png)

![10-dialplan-advanced-features figure 5](../images/10-dialplan-advanced-features-img05.png)

- option -- Optionen sind `s`, `i`, `n`:
    - `s` — sofort zurückkehren, wenn die Leitung nicht 'up' ist
    - `i` — filename als Hinweiston von Ihrem `indications.conf` abspielen
    - `n` — Ziffern lesen, auch wenn die Leitung nicht 'up' ist
- attempts -- wenn größer als 1, die Anzahl der Versuche, die unternommen werden, falls keine Daten eingegeben werden
- timeout -- Eine Ganzzahl in Sekunden, um auf eine Zifferneingabe zu warten. Wenn größer als 0, überschreibt dieser Wert das Standard-Timeout.

Die Anwendung read() sollte die Verbindung trennen, wenn die Funktion fehlschlägt oder einen Fehler verursacht.

### Die Anwendung Gotoif()

Diese Anwendung bewirkt, dass der anrufende Kanal basierend auf der Auswertung der angegebenen Bedingung an die angegebene Stelle im dialplan springt. Der Kanal fährt bei labeliftrue fort, wenn die Bedingung wahr ist, oder bei 'labeliffalse', wenn die Bedingung falsch ist. Die Labels werden mit derselben Syntax angegeben wie innerhalb der Anwendung Goto. Wenn das durch die Bedingung gewählte Label weggelassen wird, wird kein Sprung durchgeführt; stattdessen wird die Ausführung mit der nächsten Priorität im dialplan fortgesetzt.

### Labor: Schritt-für-Schritt-Erstellung eines IVR-Menüs

Lassen Sie uns ein IVR-Menü mit der folgenden Funktionalität erstellen. Wenn es angewählt wird, spielt das IVR eine Audiodatei mit der Nachricht „Willkommen bei der XYZ Corporation; drücken Sie 1 für den Vertrieb, 2 für den technischen Support, 3 für Schulungen oder warten Sie, um mit einem Mitarbeiter zu sprechen.“ Die Ziffern leiten den Anrufer wie folgt weiter:

- `1` — Weiterleitung an den Vertrieb (PJSIP/4001)
- `2` — Weiterleitung an den technischen Support (PJSIP/4002)
- `3` — Weiterleitung an Schulungen (PJSIP/4003)
- Keine Ziffer gedrückt — Weiterleitung an den Operator (PJSIP/4000)

**Schritt 1 – Aufnehmen der Ansagen**

Lassen Sie uns eine extension erstellen, um die Ansagen aufzunehmen. Um eine Ansage aufzunehmen, wählen Sie von einem softphone aus `9003<filename>` (zum Beispiel `9003welcome`). Wenn Sie den Piepton hören, beginnen Sie mit der Aufnahme; drücken Sie `#`, um zu stoppen. Sie hören einen Piepton und das System spielt die aufgenommene Ansage ab.

**Schritt 2 – Erstellen der Menülogik**

Beim Wählen der extension 9004 springt die Verarbeitung zum Menü in der extension `s`, Priorität 1.

### Übereinstimmung während des Wählens

Dies ist ein Firmen-Einrichtungsmenü für die Entgegennahme von Anrufen. Die Anwendung `Background()` spielt die Begrüßungsansage ab und wartet dann auf Ziffern, wobei sie das, was der Anrufer wählt, mit den im aktuellen context definierten extensions abgleicht.

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

Wenn Sie diese Firma anrufen, wird zuerst die Begrüßungsnachricht abgespielt. Danach wartet Asterisk darauf, dass eine Ziffer gewählt wird:

| Gewählte Nummer | Asterisk-Aktion |
|---------------|-----------------|
| 1 | Ruft sofort `Dial(DAHDI/1)` an |
| 2 | Wartet auf das Timeout, ruft dann `Dial(DAHDI/2)` an |
| 21 | Ruft sofort `Dial(DAHDI/3)` an |
| 22 | Ruft sofort `Dial(DAHDI/4)` an |
| 3 | Wartet auf das Timeout, trennt dann die Verbindung |
| 31 | Ruft sofort `Dial(DAHDI/5)` an |
| 32 | Ruft sofort `Dial(DAHDI/6)` an |

Es ist wichtig, Mehrdeutigkeiten in den Menüs zu vermeiden. Jeder möchte schnell bedient werden. Aus diesem Grund sollten Sie die Nummern 2, 21 oder 22 nicht verwenden.

### Labor: Verwendung der Anwendung Read()

Bitte versuchen Sie das Labor mit der Anwendung read(). Read akzeptiert Ziffern vom Benutzer und fügt sie in die angegebene Variable ein; Sie können dann die Anwendung gotoif verwenden, um den Anruf umzuleiten.

## Context-Inklusion

Ein context kann die Inhalte eines anderen context einbinden. Im obigen Beispiel kann jeder Kanal jede extension im internal context anrufen, aber nur der Kanal 4003 kann internationale extensions anrufen. Sie können die context-Inklusion verwenden, um die Erstellung des dialplan zu vereinfachen. Durch die Verwendung der context-Inklusion können Sie steuern, wer Zugriff auf welche extensions hat.

### Fehlerbehebung bei der Meldung „number not found“

Es kommt sehr häufig vor, dass die Meldung „number not found“ erscheint. Die meisten Leute verwechseln das Konzept der inkludierten contexts, da es nicht wirklich intuitiv ist. Als Faustregel gilt: Gehen Sie zuerst zur Konfigurationsdatei des eingehenden Kanals, wie z. B. `pjsip.conf`, `chan_dahdi.conf` und `iax.conf`, und bestimmen Sie den aktuellen context. Gehen Sie dann zum dialplan in der Datei extensions.conf und prüfen Sie, ob die gewählte Nummer in diesem context gefunden werden kann. Wenn nicht, stimmt etwas mit Ihrem dialplan nicht. Die goldenen Regeln für contexts lauten: 1. Ein Kanal kann nur Nummern innerhalb desselben context wie der Kanal selbst anrufen. 2. Der context, in dem der Anruf verarbeitet wird, ist in der Konfigurationsdatei des eingehenden Kanals definiert (`chan_dahdi.conf`, `iax.conf`, `pjsip.conf`).

## Verwendung der switch-Anweisung

Sie können die dialplan-Verarbeitung mithilfe des switch-Befehls an einen anderen Server senden. Sie benötigen dazu den Namen und den Schlüssel des anderen Servers. Der context ist der Ziel-context.

![10-dialplan-advanced-features Abbildung 6](../images/10-dialplan-advanced-features-img06.png)

## Verarbeitungsreihenfolge im dialplan

Wenn Asterisk einen eingehenden Anruf empfängt, sucht es in dem für den Kanal definierten context. In einigen Fällen, wenn mehr als ein Muster auf die gewählte Nummer passt, kann Asterisk den Anruf möglicherweise nicht genau so verarbeiten, wie Sie es erwarten. Sie können die Übereinstimmungsreihenfolge mit dem CLI-Befehl `dialplan show` einsehen. Beispiel: Nehmen wir an, Sie möchten 912 wählen, um über einen analogen trunk (DAHDI/1) zu routen, und alle anderen Nummern, die mit 9 beginnen, über einen anderen analogen trunk (DAHDI/2). Sie würden etwa Folgendes schreiben:

```
[example]
exten=>_912.,1,Dial(DAHDI/1/${EXTEN})
exten=>_9.,1,Dial(DAHDI/2/${EXTEN})
```

Wenn zwei Muster auf eine extension passen, können Sie steuern, welche extension zuerst verarbeitet wird, indem Sie included contexts verwenden. Ein included context wird später verarbeitet als ein Muster im selben context.

## Die #INCLUDE-Anweisung

Sollten wir eine große Datei oder mehrere Dateien verwenden? Sie können die #include <filename>-Anweisung verwenden, um andere Dateien in Ihre extensions.conf einzubinden. Wir könnten zum Beispiel eine users.conf für lokale Benutzer und eine services.conf für spezielle Dienste erstellen. Achten Sie darauf, #include <filename> nicht mit der

```
include=>context statement.
```

## Subroutines mit GOSUB

In älteren Versionen von Asterisk gab es den Befehl Macro. Dieser Befehl wurde vor langer Zeit zugunsten von GOSUB als veraltet markiert. Wir zeigen hier, wie man Subroutines für die voicemail-Verarbeitung auf einfache und geordnete Weise erstellt. Befehlsformat:

```
gosub([[context,]exten,]priority[(arg1[,...][,argN])])
```

Der Befehl GOSUB ist seit Asterisk 1.6 verfügbar und unterstützt die Übergabe von Argumenten (verfügbar innerhalb der Subroutine als `${ARG1}`, `${ARG2}` und so weiter). Mit Argumenten ist es nun möglich, die alten Macro-Befehle vollständig zu ersetzen. Macros (`app_macro`) wurden in Asterisk 21 entfernt; Sie müssen GOSUB für Subroutines verwenden.

### Erstellen der Subroutine

Die Definition ist sehr ähnlich. Betrachten Sie die untenstehende Subroutine, die für voicemail mit dem Namen stdexten definiert ist (wählen Sie den Namen, der Ihnen gefällt). Nachdem wir den Befehl Dial mit dem ersten Argument (Name des Kanals) aufgerufen haben, prüfen wir den ${DIALSTATUS}, um die Anruflogik an den nächsten Schritt weiterzuleiten.

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

### Aufrufen einer Subroutine

Achten Sie beim Aufruf der Subroutine darauf, Klammern vor den Parametern zu verwenden.

```
exten=>6000,1,Gosub(stdexten,s,1(PJSIP/6000,${EXTEN}))
exten=>6001,1,Gosub(stdexten,s,1(PJSIP/6001,${EXTEN}))
exten=>6002,1,Gosub(stdexten,s,1(PJSIP/6002,${EXTEN}))
exten=>6003,1,Gosub(stdexten,s,1(PJSIP/6003,${EXTEN}))
```

## Verwendung der Asterisk DB

Um Anrufweiterleitungen und Blacklists zu implementieren, benötigen wir eine Möglichkeit, Daten zu speichern und wiederherzustellen. Glücklicherweise bietet Asterisk einen Mechanismus zum Speichern und Abrufen von Daten aus einer integrierten Datenbank namens AstDB. Im modernen Asterisk (einschließlich Asterisk 22) wird AstDB durch **SQLite3** (die Datei `/var/lib/asterisk/astdb.sqlite3`) unterstützt; Asterisk 1.8 und früher verwendeten Berkeley DB v1. Dies ähnelt der Windows-Registrierungsdatenbank, die das hierarchische Konzept von Family und Keys verwendet. Die Daten bleiben über Asterisk-Neustarts hinweg erhalten. Die Family/Key-API ist gegenüber dem älteren Backend unverändert; nur das Speicherformat auf der Festplatte hat sich geändert.

### Funktionen, Anwendungen und CLI-Befehle

Es gibt einige Funktionen, Anwendungen und CLI-Befehle, die mit AstDB arbeiten:

- variable=${DB(<family/key>)}
- DB(<family/key>)=value
- DB_EXISTS(<family/key>)

Beispiele:

```
exten=_*21*XXXX,1,Set(DB(CFIM/${CALLERID(num)})=${EXTEN:4})
exten=s,1,Set(temp=${DB(CFIM/${EXTEN})})
```

Einige Anwendungen können verwendet werden, um AstDB zu manipulieren:

- DB_DELETE(<family/key>) — Funktion, die einen einzelnen Key zurückgibt und löscht
- DBdeltree(<family>) — Anwendung, die eine ganze Family/einen ganzen Subtree löscht

Die alte Anwendung `DBdel()` existiert in Asterisk 22 nicht mehr. Löschen Sie einen einzelnen Key mit der dialplan-Funktion `DB_DELETE()` — z. B. `Set(x=${DB_DELETE(family/key)})` oder, als Schreiboperation, `Set(DB_DELETE(family/key)=)`. `DBdeltree()` (Löschen einer ganzen Family/eines ganzen Subtrees) ist weiterhin eine Anwendung.

Es ist auch möglich, CLI-Befehle zum Setzen und Löschen von Keys zu verwenden:

- database del
- database put
- database show <family[/key]>
- database showkey
- database deltree
- database get

![10-dialplan-advanced-features figure 7](../images/10-dialplan-advanced-features-img07.png)

![10-dialplan-advanced-features figure 8](../images/10-dialplan-advanced-features-img08.png)

### Implementierung von Anrufweiterleitung, DND und Blacklists

In diesem Beispiel lernen Sie, wie Sie eine sofortige Anrufweiterleitung und eine Anrufweiterleitung bei Besetzt implementieren. Wir verwenden *21*, um die sofortige Anrufweiterleitung zu programmieren, und *61*, um die Anrufweiterleitung bei Besetzt zu programmieren. Um die Programmierung abzubrechen, verwenden Sie #21# bzw. #61#. Verwenden Sie das obige Beispiel, um die Datenbank zu füllen. Verwendete Families:

- CFIM – Call Forward Immediate (Sofortige Anrufweiterleitung)
- CFBS – Call Forward on Busy status (Anrufweiterleitung bei Besetzt)
- DND – Do Not Disturb (Nicht stören)

Versuchen Sie, die Datenbank durch Wählen der folgenden Nummern zu füllen:

- *21* (Ziel-extension für sofortige Anrufweiterleitung)
- *61* (Ziel-extension für Anrufweiterleitung bei Besetzt)
- *41* (Extension, um den Nicht-stören-Modus zu aktivieren)

Verwenden Sie den CLI-Befehl database show, um die hinzugefügten Families, Keys und Werte anzuzeigen.

![10-dialplan-advanced-features figure 9](../images/10-dialplan-advanced-features-img09.png)

![10-dialplan-advanced-features figure 10](../images/10-dialplan-advanced-features-img10.png)

### Anrufweiterleitung, Blacklist, DND

Die Subroutine überprüft, ob die Datenbank die Key:Value-Paare enthält, die CFIM, CFBS oder DND entsprechen, und behandelt diese dann entsprechend. Die folgende Subroutine ruft die Wählroutine auf:

```
exten=_4XXX,1,gosub(stdexten,s,1(${EXTEN}))
```

## Verwendung einer Blacklist

Die alte `LookupBlacklist()` Anwendung wurde aus Asterisk **entfernt** (sie verschwand zusammen mit dem veralteten „priority+101 jump“-Mechanismus). In Asterisk 22 erstellen Sie eine Blacklist direkt mit der `DB_EXISTS()` Funktion (die sowohl auf einen Schlüssel prüft als auch bei einem Treffer dessen Wert in `${DB_RESULT}` bereitstellt) sowie `GotoIf`. Speichern Sie jede blockierte Nummer als Schlüssel in einer `blacklist` Familie und prüfen Sie dann die Caller ID am Anfang Ihres eingehenden context:

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

`DB_EXISTS(blacklist/${CALLERID(num)})` gibt `1` zurück, wenn die Nummer des Anrufers in der Datenbank vorhanden ist (und leitet den Anruf an den `blocked` context weiter), und `0` andernfalls, sodass der Anruf wie gewohnt zum `Dial()` fortfährt.

Um eine Nummer in die Blacklist einzufügen, können wir dieselbe Ressource wie zuvor verwenden, indem wir *31* gefolgt von der zu sperrenden extension eingeben. Um eine Nummer aus der Blacklist zu entfernen, sollten Sie #31# gefolgt von der zu entfernenden Nummer verwenden.

```
[apps]
exten=>_*31*X.,1,Set(DB(blacklist/${EXTEN:4})=1)
exten=>_*31*X.,2,Hangup()
exten=>_#31#X.,1,Set(x=${DB_DELETE(blacklist/${EXTEN:4})})
exten=>_#31#X.,2,Hangup()
```

Sie können die Nummern auch über die Konsole CLI in die Blacklist einfügen:

```
*CLI>database put blacklist <name/number> 1
```

Hinweis: Jedem Schlüssel kann ein beliebiger Wert zugeordnet werden. Der `DB_EXISTS()` Test sucht nach dem Schlüssel, nicht nach dem Wert. Um die Nummer aus der Blacklist zu löschen, können Sie Folgendes verwenden:

```
*CLI>database del blacklist <name/number>
```

## Zeitbasierte Kontexte

In der folgenden Abbildung sehen wir einen dialplan mit drei Kontexten. Der [incoming] Kontext ist der Ort, an dem Anrufe üblicherweise empfangen werden. Wir haben vier Zeilen eingefügt, die das Verhalten in Abhängigkeit von der Systemzeit ändern, wie im Folgenden dargestellt:

```
include => context,<times>,<weekdays>,<mdays>,<months>
```

Modernes Asterisk (einschließlich 22) trennt die time-include-Felder mit **Kommas**, nicht mit Pipes. Die veraltete Pipe-Form (`include => context|times|weekdays|mdays|months`) wird als einfacher, wörtlicher Kontextname interpretiert und schlägt stillschweigend fehl, ohne eine Zeitbedingung anzuwenden.

Während der regulären Arbeitszeiten wird die Verarbeitung an das mainmenu weitergeleitet, wo wahrscheinlich ein IVR aufgerufen wird, um den eingehenden Anruf zu bearbeiten. Wenn der Anruf außerhalb der Geschäftszeiten erfolgt, wird die in der Variablen ${SECURITY} definierte security extension angerufen. Wenn die security extension den Anruf nicht entgegennimmt, wird er an die voicemail des Operators weitergeleitet.

![10-dialplan-advanced-features Abbildung 11](../images/10-dialplan-advanced-features-img11.png)

![10-dialplan-advanced-features Abbildung 12](../images/10-dialplan-advanced-features-img12.png)

## Zeitbasierte Nachrichten mit gotoiftime()

Die Syntax von GotoIfTime() ist unten dargestellt.

```
GotoIfTime(times,weekdays,mdays,months[,timezone]?[labeliftrue][:labeliffalse])
```

In Asterisk 22 ist das Feldtrennzeichen ein **Komma**, kein Pipe-Symbol (die Pipe-Form wurde in Asterisk 1.6 als veraltet markiert). Ein optionales Feld `timezone` wird unterstützt, und jede Sprungmarke verwendet die übliche Form `[[context,]extension,]priority`.

Diese Anwendung kann den zeitbasierten context ersetzen und scheint einfacher zu verstehen und zu lesen zu sein. Sie können die Zeit wie folgt angeben:

- <timerange>=<hour>':'<minute>'-'<hour>':'<minute> |"*"
- <daysofweek>=<dayname>|<dayname>'-'<dayname>|"*"
- <dayname>="sun"|"mon"|"tue"|"wed"|"thu"|"fri"|"sat"
- <daysofmonth>=<daynum>|<daynum>'-'<daynum> |"*"
- <daynum>=Zahl von 1 bis 31
- <hour>=Zahl von 0 bis 23
- <minute>=Zahl von 0 bis 59
- <months>=<monthname>|<monthname>'-'<monthname>|"*"
- <monthname>="jan"|"feb"|"mar"|"apr"|"may"|"jun"|"jul"|"aug"|"sep"|"oct"|"nov"|"dec"

Die Namen für Tage und Monate unterscheiden nicht zwischen Groß- und Kleinschreibung.

```
exten=>s,1,GotoIfTime(8:00-18:00,mon-fri,*,*?normalhours,s,1)
```

Die vorherige Anweisung überträgt die Verarbeitung an die extension s im context normalhours, wenn der Anruf zwischen 08:00 Uhr und 18:00 Uhr von Montag bis Freitag erfolgt.

## Verwendung von DISA für ein neues Wählton-Signal

DISA, oder „direct inward system access“, ist ein System, das es Benutzern ermöglicht, ein zweites Wählton-Signal zu erhalten. Es erlaubt Benutzern, erneut eine andere Zielrufnummer zu wählen. Es wird häufig von Technikern verwendet, wenn sie an Wochenenden Ferngespräche für den technischen Support führen; anstatt direkt von zu Hause aus das Ziel anzurufen, rufen sie die DISA-Nummer des Büros an, erhalten ein Wählton-Signal und wählen dann das Ziel. Die Gebühren für das Ferngespräch fallen dann bei der Firma an und nicht beim privaten Telefonanschluss.

```
DISA(passcode|filename[,context[,cid[,mailbox[@context][,options]]]])
```

Beispiel:

```
exten => s,1,DISA(no-password,default)
```

Unter Verwendung der vorherigen Anweisung ruft der Benutzer die PBX an und erhält – ohne dass ein Passwort erforderlich ist – ein Wählton-Signal. Jeder Anruf, der DISA verwendet, wird über den `default` context verarbeitet. Die Argumente für diese Anwendung umfassen ein globales Passwort oder ein individuelles Passwort innerhalb einer Datei. Wenn kein context angegeben ist, wird der `disa` context angenommen. Wenn Sie eine Passwortdatei verwenden, muss der vollständige Pfad angegeben werden. Eine Caller ID kann ebenfalls für die externe DISA-Wahl festgelegt werden. Beispiel:

```
exten => s,1,DISA(numeric-passcode,default,"Flavio" <4830258590>)
```

Asterisk 22 verwendet Kommas als Argumenttrenner (die Pipe-Form wurde in 1.6 als veraltet markiert). Das erste Argument ist entweder ein einzelner Passcode oder der Pfad zu einer Passcode-Datei, und der Standard-context, wenn keiner angegeben ist, ist `disa`.

## Begrenzung gleichzeitiger Anrufe

Die Funktion GROUP() ermöglicht es Ihnen, die Anzahl der aktiven Kanäle in einer Gruppe zur gleichen Zeit zu zählen. Beispiel: Sie haben eine Niederlassung in Rio de Janeiro, wo Telefone dem Muster „_214X“ folgen. Dieser Standort wird über eine Standleitung versorgt, bei der 64K für die Sprachbandbreite reserviert sind. In diesem Fall beträgt die maximal zulässige Anzahl an Anrufen 2 (G.729, etwa 31.2K pro Anruf). Um die Anrufe nach Rio auf zwei zu begrenzen:

```
exten=>_214X,1,set(GROUP()=Rio)
exten=>_214X,n,Gotoif($[${GROUP_COUNT()} > 1]?outoflimit)
exten=>_214X,n,Dial(PJSIP/${EXTEN})
exten=>_214X,n,hangup
exten=>_214X,n(outoflimit),playback(callsexceedcapacity)
exten=>_214X,n,hangup
```

## Voicemail

Voicemail ist ein computergestütztes Telefonbeantwortungssystem, das eingehende Sprachnachrichten aufzeichnet, auf der Festplatte speichert oder per E-Mail versendet. Manchmal verfügt es über ein Verzeichnis, in dem Sie Voicemail-Boxen nach Namen suchen können. Früher waren Voicemail-Systeme sehr teuer. Heute, mit IP-Telefonie, wird Voicemail zu einem Standard-Feature.

Um Voicemail zu konfigurieren, sollten Sie die folgenden Schritte durchlaufen.

**Schritt 1: Bearbeiten Sie `voicemail.conf` und legen Sie die allgemeinen Parameter fest.**

- `format` — der für die Aufnahme der Nachricht verwendete codec (z. B. wav49, wav, gsm)
- `serveremail` — Absenderadresse, von der die E-Mail-Benachrichtigung zu stammen scheint
- `maxmsg` — maximale Anzahl an Nachrichten in der Mailbox; nach Erreichen dieses Schwellenwerts werden Nachrichten verworfen
- `maxsecs` — maximale Länge einer Voicemail-Nachricht in Sekunden
- `minsecs` — minimale Länge einer Nachricht in Sekunden; unterhalb dieses Schwellenwerts wird keine Nachricht aufgezeichnet
- `maxsilence` — Anzahl der Sekunden Stille, die als Ende der Nachricht gewertet werden

**Schritt 2: Bearbeiten Sie `voicemail.conf` und erstellen Sie die Mailboxen der Benutzer.**

### Voicemail.conf

Eine Mailbox wird mit einer Zeile pro Mailbox definiert, in der Form:

```
mailboxID => pincode,fullname,email,pager-email,options
```

Die Felder sind:

- **MailboxID** — üblicherweise die extension Nummer
- **Pincode** — Passwort für den Zugriff auf das Voicemail-System
- **Full name** — wird von der Verzeichnisanwendung verwendet
- **E-mail** — Adresse für die Voicemail-Benachrichtigung
- **Pager e-mail** — Adresse für die Benachrichtigung über ein SMS-Gateway oder einen Pager
- **Options** — Optionen pro Mailbox (dieselben Optionen wie in `[general]`, jedoch auf diese Mailbox angewendet)

Voicemail verfügt über verschiedene Optionen, die sein Verhalten steuern. Vorerst bleiben wir bei den Standardoptionen und konzentrieren uns auf die Definition der Mailbox. Nach dem Abschnitt `[general]` in der Datei beginnen Sie mit der Konfiguration der Mailbox-IDs, jede in ihrem eigenen context. Beispiel:

```
[general]
[default]
1234=>1234,SomeUser,email@address.com,pager@address.com,saycid=yes|dialout=fromvm|callback=fromvm|review=yes|operator=yes
```

Bitte prüfen Sie die erweiterten Optionen in der Datei `voicemail.conf`.

**Schritt 3: Konfigurieren Sie die Datei `extensions.conf`.**

Die zuvor gezeigte Subroutine `stdexten` (unter *Subroutines with GOSUB*) ist genau der Anruf-/Voicemail-Handler, den Sie hier benötigen: Er wählt die extension und verwendet den Wert der Kanalvariablen `${DIALSTATUS}`, um den Anruffluss zur entsprechenden Voicemail-Begrüßung umzuleiten (`b` für besetzt, `u` für nicht erreichbar). Rufen Sie diese mit `Gosub(stdexten,s,1(PJSIP/<device>,<mailbox>))` von jeder extension in `extensions.conf` auf.

## Verwendung der VoiceMailMain() Anwendung

Die Anwendung voicemailmain() wird verwendet, um die voicemail Mailbox zu konfigurieren. Benutzer können die Anwendung anrufen, ihre Begrüßung aufnehmen und ihre voicemail abhören. Um die Anwendung im dialplan aufzurufen, verwenden Sie:

```
exten=>9000,1,VoiceMailMain()
```

Nachfolgend finden Sie eine Liste der für die Anwendung verfügbaren Optionen.

### Syntax der Voicemail-Anwendung

Diese Anwendung ermöglicht es dem Anrufer, eine Nachricht für eine angegebene Liste von Mailboxen zu hinterlassen. Wenn mehrere Mailboxen angegeben sind, wird die Begrüßung von der ersten angegebenen Mailbox übernommen. Die Ausführung des dialplan wird gestoppt, wenn die angegebene Mailbox nicht existiert. Die Syntax ist unten dargestellt:

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

![10-dialplan-advanced-features Abbildung 13](../images/10-dialplan-advanced-features-img13.png)

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

In allen Fällen wird die Datei beep.gsm abgespielt, bevor die Aufnahme beginnt. voicemail-Nachrichten werden im Verzeichnis inbox gespeichert.

```
/var/spool/asterisk/voicemail/context/boxnumber/INBOX/
```

Wenn ein Anrufer während der Ansage die 0 (Null) drückt, wird er zur 'o' (out) extension im aktuellen voicemail context weitergeleitet. Dies kann verwendet werden, um zum Operator zu gelangen. Wenn der Anrufer während der Aufnahme # drückt oder das Stille-Limit abläuft, wird die Aufnahme gestoppt und der Anruf geht zur nächsten Priorität über. Stellen Sie sicher, dass Sie den Anruf behandeln, nachdem die voicemail abgespielt wurde, wie unten gezeigt.

```
exten=>somewhere,5,Playback(Goodbye)
exten=>somewhere,6,Hangup
```

### Markieren von voicemail-Nachrichten als dringend

Sie können einige Nachrichten als „dringend“ markieren. Hierfür stehen zwei Methoden zur Verfügung:

- Übergeben Sie die Option 'U' in der Anwendung voicemail()
- Geben Sie review=yes in der Datei voicemail.conf an. Wenn Sie diese Option verwenden, kann der Benutzer die Nachricht nach der Aufnahme der Sprachanweisungen als dringend markieren.

## Voicemail per E-Mail versenden

In manchen Fällen (wie bei mir) verwenden wir die Anwendung voicemailmain() einfach nicht, um E-Mails abzurufen. Es ist einfacher und praktischer, alle Nachrichten mit angehängter Audiodatei per E-Mail zu versenden. Mithilfe der Parameter ‘attach’ und ‘delete’ können Sie alle Nachrichten per E-Mail versenden und sie anschließend aus der Mailbox löschen.

```
attach=yes
delete=yes
```

Um Voicemail per E-Mail zu versenden, nutzt die voicemail-Anwendung den Message Transfer Agent (MTA), eine Komponente Ihres Betriebssystems. Debian verwendet Exim als MTA. Die Anwendung, die die E-Mail versendet, wird im Parameter ‘mailcmd’ definiert.

```
mailcmd =/usr/sbin/sendmail -t
```

In der Linux-Distribution Debian ist Exim der Standard-MTA. Um Exim unter Debian zu konfigurieren, verwenden Sie:

```
dpkg-reconfigure exim4-config
```

Sie können wählen, ob Ihr MTA eine E-Mail direkt über SMTP oder über einen Smarthost (normalerweise der Mailserver Ihres Unternehmens) versenden soll. Klären Sie mit Ihrem E-Mail-Administrator den besten Weg, um E-Mails vom Asterisk-Server an Ihren E-Mail-Server zu senden.

## Anpassen der E-Mail-Nachricht

Sie können steuern, wie Nachrichten versendet werden, indem Sie die folgenden Variablen einrichten: Variablen für E-Mail-Betreff und E-Mail-Text:

- VM_NAME
- VM_DUR
- VM_MSGNUM
- VM_MAILBOX
- VM_CIDNUM
- VM_CIDNAME
- VM_CALLERID
- VM_DATE

Der E-Mail-Text und der Betreff werden aus einer Vorlage erstellt, die Sie im Abschnitt `[general]` von `voicemail.conf` festlegen. Sie können sowohl den Text als auch den Betreff ändern, aber die Größenbeschränkung der Nachricht beträgt 512 Bytes. In der Vorlage fügt `\n` einen Zeilenumbruch und `\t` einen Tabulator ein.

Das folgende Beispiel `emailsubject` ist unkompliziert. Das Beispiel `emailbody` kommt dem Standard sehr nahe; der Standard zeigt nur den CIDNAME an, wenn dieser nicht null ist, andernfalls den CIDNUM oder "an unknown caller", wenn beide null sind.

```
emailsubject=[PBX]: New message ${VM_MSGNUM} in mailbox ${VM_MAILBOX}

emailbody=Dear ${VM_NAME}:\n\n\tjust wanted to let you know you were just left a ${VM_DUR} long message (number ${VM_MSGNUM})\nin mailbox ${VM_MAILBOX} from ${VM_CALLERID}, on ${VM_DATE}, so you might\nwant to check it when you get a chance. Thanks!\n\n\t\t\t\t--Asterisk\n
```

## Voicemail Web-Interface

Es gibt ein Perl-Skript in der Quelldistribution namens `vmail.cgi`, das sich unter `contrib/scripts/vmail.cgi` im Asterisk-Quellbaum befindet (es wird immer noch mit Asterisk 22 ausgeliefert). Der Befehl `make install` installiert dieses Interface nicht; Sie müssen `make webvmail` aus dem Quellverzeichnis ausführen. Dieses Skript erfordert, dass der Perl-Befehlsinterpreter und ein Webserver (wie Apache) auf dem Server installiert sind.

```
make webvmail
```

Das Ziel `make webvmail` installiert das Skript (setuid root) in das CGI-Verzeichnis Ihres Webservers (`HTTP_CGIDIR`) und kopiert die unterstützenden Bilder von `images/*.gif` nach `HTTP_DOCSDIR/_asterisk` (standardmäßig `/var/www/html/_asterisk`). Falls diese Pfade nicht mit dem Layout Ihres Webservers übereinstimmen, bearbeiten Sie die Variablen `HTTP_CGIDIR` und `HTTP_DOCSDIR` in der obersten `Makefile`, bevor Sie das Ziel ausführen.

## Voicemail-Benachrichtigung

Sie können voicemail so konfigurieren, dass eine Benachrichtigung an Ihr Telefon gesendet wird, wenn Sie eine neue voicemail haben. In Asterisk 22 funktioniert die Message Waiting Indication (MWI) sowohl mit PJSIP- und SIP-Telefonen als auch mit DAHDI-Telefonen. Um eine ungehörte voicemail anzuzeigen, kann eine Anzeigeleuchte blinken oder das Telefon kann einen Signalton abspielen. Sie müssen die mailbox in der entsprechenden Kanal-Konfigurationsdatei konfigurieren. Beispiel: `pjsip.conf` (im endpoint-Abschnitt):

```
mailboxes=8590
```

In PJSIP wird der mailbox-Hinweis mit der Option `mailboxes` innerhalb des endpoint-Abschnitts von `pjsip.conf` festgelegt, anstatt mit dem alten `mailbox=` von `sip.conf`. MWI-Abonnements werden vom Modul `res_pjsip_mwi` verarbeitet.

![Das Comedian Mail Web-Interface (`vmail.cgi`): der Asterisk Web-Voicemail-Login — geben Sie Ihre mailbox und Ihr Passwort ein, um voicemail über einen Browser abzuspielen, zu speichern, weiterzuleiten oder zu löschen. Es wird weiterhin mit Asterisk 22 ausgeliefert und mit `make webvmail` installiert.](images/comedian_mail.png){width=50%}(../images/10-dialplan-advanced-features-img14.png)

### Labor: Nachrichtenbenachrichtigung im Telefon

Dieses Labor wurde mit einem SIP-softphone getestet.

1. Bearbeiten Sie `pjsip.conf` und fügen Sie `mailboxes=4401` im endpoint-Abschnitt für das Gerät mit dem Namen 4401 hinzu.
2. Bearbeiten Sie die `extensions.conf` und erstellen Sie eine extension, um eine voicemail für 4401-extensions aufzunehmen.

```
exten=9008,1,voicemail(4401,b)
```

3. Gehen Sie zur Konsole und führen Sie einen reload durch.
4. Öffnen Sie im SipPulse softphone die SIP-Kontoeinstellungen und aktivieren Sie die voicemail-Prüfung (message-waiting) für das Konto.
5. Wählen Sie 9008 und hinterlassen Sie eine Nachricht.
6. Beobachten Sie das Nachrichtensymbol auf dem Telefon.

## Verwendung der directory-Anwendung

Diese Anwendung ermöglicht es Ihnen, schnell einen Benutzer zu finden, den Sie anrufen möchten. Die Liste der Namen und die zugehörigen extension werden aus der voicemail-Konfigurationsdatei voicemail.conf abgerufen. Die Syntax für die Anwendung kann mit core show application directory angezeigt werden:

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

### Übung: Verwendung der directory-Anwendung

1. Bearbeiten Sie die Datei voicemail.conf, um zwei extension im dialplan hinzuzufügen

```
[default]
; Define maximum number of messages per folder for a particular context.
;maxmsg=50
4400=>4400,Clint Eastwood,ceastwood@voip.school
4401=>4401,John Wayne,jwayne@voip.school
```

2. Erstellen Sie diese extension in Ihrem dialplan

```
exten=9006,1,VoiceMailMain()
exten=9006,n,Hangup()
exten=9007,1,Directory(default,default)
exten=9007,n,Hangup()
```

3. Wechseln Sie zur Konsole und führen Sie einen reload durch
4. Wählen Sie 9006 und nehmen Sie einen Namen für jede extension auf (4400, 4401)
5. Wählen Sie 9007 und geben Sie die drei Buchstaben des Nachnamens für eine extension ein (Eas=327). Wenn dies die richtige Option ist, drücken Sie ‚1‘, um zu dem Namen weiterzuleiten.

## Lab: Alles zusammenfügen

Bisher haben Sie verschiedene Konzepte für den dialplan kennengelernt. Lassen Sie uns alle Anwendungen, Funktionen und Konzepte in einem Beispiel für einen dialplan zusammenfassen, damit Sie verstehen, wie sie gemeinsam genutzt werden. Wir führen Sie durch die gesamte PBX-Konfiguration für das folgende Szenario.

- 4 analoge trunks
- 16 SIP-basierte extensions
- 3 Serviceklassen:
    - restrict (intern, lokal und 1-800)
    - ld (Fernverbindungen)
    - ldi (international)
- Nachricht für außerhalb der Geschäftszeiten
- Auto-Attendant

### Schritt 1 – Konfiguration der Kanäle

**Analoge trunks (`chan_dahdi.conf`).** Zuerst konfigurieren wir die analogen trunks in der DAHDI-Kanalkonfigurationsdatei `chan_dahdi.conf`. In diesem Fall verwenden wir eine T400P Digium-Karte mit 4 FXO-Schnittstellen. Wir gehen davon aus, dass der Treiber bereits geladen ist und die Treiberkonfigurationsdatei (/etc/dahdi/system.conf) korrekt konfiguriert wurde.

![10-dialplan-advanced-features Abbildung 16](../images/10-dialplan-advanced-features-img16.png)

```
signalling=fxs_ks
language=en
context=incoming
group=1
channel => 1-4
```

**SIP-Kanäle (`pjsip.conf`).** Wir haben die Nummerierung für den dialplan von 2000 bis 2099 gewählt. Es werden zwei codec verwendet: G.729 und G.711 ulaw. Der erste wird für Telefone verwendet, die Asterisk über das Internet oder WAN nutzen, während der zweite für Telefone im lokalen Netzwerk zum Einsatz kommt. In `pjsip.conf` legen wir fest, welche Geräte zu welcher Serviceklasse (restrict, ld, ldi) gehören. Um die Anfälligkeit für Brute-Force-Angriffe zu verringern, verwenden wir die MAC-Adressen der Telefone als Gerätenamen. Ich rate Ihnen dringend, sichere Passwörter zu verwenden, um Brute-Force-Angriffe zu vermeiden!

Wir definieren einen Transport und drei wiederverwendbare Vorlagen — eine endpoint-Basis mit den gemeinsamen codec, eine Digest-Authentifizierung und einen AOR mit einem einzelnen Kontakt — und verknüpfen dann jedes Gerät mit den Vorlagen, wobei wir nur die abweichenden Parameter (den context der Serviceklasse und die Anmeldedaten) überschreiben. `host=dynamic` wird zu einem AOR, bei dem sich das Telefon registriert, und `directmedia` wird zu `direct_media`:

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

### Schritt 2 – Konfiguration des dialplan

Beginnen wir nun mit der Konfiguration der extensions.conf. Definieren Sie interne extensions und lokales Wählen

```
[restrict]
exten=>_2000,1,Dial(PJSIP/00001A000002,20,t)
exten=>_2030,1,Dial(PJSIP/00001A000003,20,t)
exten=>_2040,1,Dial(PJSIP/00001A000004,20,t)
exten=>_9XXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20) ; local calls
exten=>_91800.,1,Dial(DAHDI/g1/${EXTEN:1},20); 1-800
```

Definieren Sie LD (Fernverbindungen)

```
[ld]
Include=>restrict
exten=>_9NXXNXXXXXX,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

Definieren Sie internationale Anrufe

```
[ldi]
include=>ld
exten=>_901X.,1,Dial(DAHDI/g1/${EXTEN:1},20)
```

### Schritt 3 – Anrufe mit einem Auto-Attendant entgegennehmen

Um Anrufe entgegenzunehmen, verwenden Sie zwei context. Der erste ist für den Betrieb während der normalen Geschäftszeiten, bei dem der Anruf von einem Auto-Attendant entgegengenommen wird. Der zweite ist für die Zeit außerhalb der Geschäftszeiten, in der der Anrufer eine Nachricht erhält wie: „Sie haben die Firma XYZ angerufen, unsere normalen Geschäftszeiten sind von 08:00 bis 18:00 Uhr; wenn Sie die Ziel-extension kennen, können Sie diese jetzt wählen oder auflegen.“ Menüs: Normale Geschäftszeiten, Außerhalb der Geschäftszeiten In den folgenden Menüs spielt das System eine Nachricht ab, die den Anrufer darauf hinweist, dass die Firma außerhalb der regulären Arbeitszeiten erreicht wurde, und ermöglicht es dem Anrufer, die Ziel-extension zu wählen (jemand könnte nach den regulären Arbeitszeiten arbeiten).

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

Menüs: Hauptmenü und Vertrieb Während der normalen Arbeitszeiten wird der Anruf von einem Auto-Attendant-Menü beantwortet, das eine Nachricht abspielt wie: „Willkommen bei der Firma XYZ; wählen Sie 1 für Vertrieb, 2 für technischen Support, 3 für Schulungen oder die gewünschte extension“.

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

Mit all diesen Anweisungen ist die Funktionalität Ihres dialplan nun bereit. Im nächsten Abschnitt zeigen wir Ihnen, wie Sie die PBX bedienen.

## Zusammenfassung

In diesem Kapitel haben Sie gelernt, wie man Anrufe mithilfe eines IVR oder einer automatischen Telefonzentrale entgegennimmt. Sie haben das Konzept der context-Einbindung studiert und einige Beispiele implementiert. Subroutinen wurden verwendet, um wiederholte Eingaben zu vermeiden, und die Asterisk-Datenbank (AstDB, unterstützt durch SQLite3 in Asterisk 22) wurde für Funktionen eingesetzt, die eine Datenspeicherung erfordern (z. B. Anrufweiterleitung, Nicht-stören-Funktion, Blacklists). Abschließend haben Sie gelernt, wie man ein Verhalten für die Zeit außerhalb der Geschäftszeiten implementiert, und einen vollständigen dialplan unter Verwendung dieser Konzepte erstellt.

## Quiz

1. Ein zeitabhängiges context include verwendet die Form `include => context,<times>,<weekdays>,<mdays>,<months>`. Was bewirkt `include => normalhours,08:00-18:00,mon-fri,*,*`?
   - A. Führt die extensions von Montag bis Freitag, 08:00 bis 18:00 Uhr aus
   - B. Führt die Optionen jeden Tag in allen Monaten aus
   - C. Nichts; das Format ist ungültig
2. In modernem Asterisk (einschließlich Asterisk 22) werden die Felder eines zeitbasierten `include =>` und von `GotoIfTime()` durch welches Zeichen getrennt?
   - A. Den senkrechten Strich `|`
   - B. Das Komma `,`
   - C. Das Semikolon `;`
   - D. Den Schrägstrich `/`
3. Um mehrere Kanäle gleichzeitig anzurufen (sie simultan klingeln zu lassen), trennen Sie diese innerhalb von `Dial()` mit dem Zeichen ___.
4. Ein Sprachmenü, das eine Ansage abspielt, während auf die Eingabe einer extension durch den Anrufer gewartet wird, wird üblicherweise mit der Anwendung ___ erstellt.
5. Sie können den Inhalt einer anderen Datei innerhalb von `extensions.conf` mit der Anweisung ___ einbinden (Hinweis: Dies unterscheidet sich von der context-Anweisung `include =>`).
6. In Asterisk 22 wird die integrierte AstDB-Datenbank unterstützt durch:
   - A. Berkeley DB v1
   - B. MySQL
   - C. SQLite3
   - D. PostgreSQL
7. Wenn Sie `Dial(type1/identifier1&type2/identifier2)` verwenden, wählt Asterisk jeden Kanal nacheinander und wartet jeweils 20 Sekunden zwischen ihnen.
   - A. Falsch
   - B. Wahr
8. Bei der Anwendung Background() müssen Sie warten, bis die Nachricht vollständig abgespielt wurde, bevor Sie eine DTMF-Ziffer drücken können, um eine Option auszuwählen.
   - A. Falsch
   - B. Wahr
9. Gegeben die Syntax `Goto([[context,]extension,]priority)`, welche der folgenden sind gültige Aufrufe der Anwendung Goto()? (markieren Sie alle zutreffenden)
   - A. Goto(context,extension)
   - B. Goto(context,extension,priority)
   - C. Goto(extension,priority)
   - D. Goto(priority)
10. Um einen einzelnen Schlüssel aus der AstDB im Asterisk 22 dialplan zu löschen, verwenden Sie:
    - A. Die Anwendung `DBdel()`
    - B. Die Funktion `DB_DELETE()`
    - C. Die Anwendung `DBdeltree()`
    - D. Die Anwendung `LookupBlacklist()`

**Antworten:** 1 — A · 2 — B · 3 — `&` · 4 — Background() · 5 — #include · 6 — C · 7 — A · 8 — A · 9 — B, C, D · 10 — B
