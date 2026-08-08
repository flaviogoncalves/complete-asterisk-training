# SIP-Trunking, DID & das PSTN

Eine PBX, die nur sich selbst anrufen kann, ist nicht sehr nützlich. Früher oder später muss jedes System den Rest der Welt erreichen — das öffentliche Telefonnetz (PSTN), einen SIP-Anbieter oder eine andere PBX. Die Verbindung, die diese Anrufe überträgt, ist ein **trunk**. In der TDM-Ära war ein trunk ein physischer Schaltkreis: ein T1/E1 PRI oder ein Bündel analoger FXO-Leitungen. Heute ist es fast immer ein **SIP trunk** — eine logische Verbindung zu einem Internet Telephony Service Provider (ITSP), die über dasselbe IP-Netzwerk wie alles andere übertragen wird.

Dieses Kapitel zeigt, wie man Asterisk 22 mit PJSIP an einen ITSP anbindet, wie man zwischen einem registrierungsbasierten und einem IP-basierten trunk wählt, wie man eingehende DID-Nummern an das richtige Ziel weiterleitet, wie man ausgehende Anrufe mit korrekter Caller-ID und E.164-Formatierung sendet und wie man Failover sowie Least-Cost-Routing über mehrere trunks hinweg aufbaut. Wir schließen mit der NAT-Behandlung für trunks ab und einem Labor, in dem ein zweiter Asterisk (und SIPp) als simulierter ITSP eingerichtet wird, damit Sie echte Anrufe über einen trunk tätigen können.

Alles hier ist für das Asterisk 22.10.0-Labor des Buches verifiziert; das trunk-Objektmuster ist dasselbe, das in *Building your first PBX with PJSIP* und *SIP & PJSIP in depth* eingeführt wurde.

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Asterisk 22 mit einem ITSP über PJSIP zu verbinden
- Zwischen registrierungsbasierten und IP-basierten (statischen) trunks zu wählen
- Eingehende DIDs an die richtige extension, IVR oder Warteschlange weiterzuleiten
- Ausgehende Anrufe mit korrekter Caller-ID und E.164-Formatierung zu routen
- Trunk-Failover und Least-Cost-Routing mit `${DIALSTATUS}` aufzubauen
- NAT für trunks auf der Transport- und der endpoint-Ebene zu handhaben

## Was ist ein SIP trunk

Ein SIP trunk ist ein logischer Sprachpfad zwischen Ihrer PBX und einem anderen SIP-System. In der Praxis ist dieses "andere System" eines von zwei Dingen:

- **Ein ITSP (Internet Telephony Service Provider).** Ein kommerzieller Anbieter, der Ihnen Anruf-Origination und -Termination sowie in der Regel einen Block von Telefonnummern (DIDs) verkauft. Sie verweisen Asterisk auf den Signalisierungs-Host des Anbieters, und der Anbieter verbindet Ihre Anrufe mit dem weiteren PSTN. Auf diese Weise erreichen die meisten modernen Systeme das Telefonnetz — es ist keine Telefonie-Hardware erforderlich.
- **Ein PSTN gateway.** Ein Gerät (oder ein anderes Asterisk), das über physische PSTN-Schnittstellen verfügt — eine PRI-Karte, analoge FXO-Ports oder ein GSM/4G gateway — und diese Ihrer PBX als SIP präsentiert. Das gateway übernimmt die TDM-zu-SIP-Konvertierung; aus Sicht von Asterisk ist es einfach ein weiterer SIP trunk.

So oder so, in PJSIP ist ein trunk **einfach ein endpoint**. Dieselbe Objektfamilie, die Sie für ein Telefon verwendet haben — `endpoint`, `auth`, `aor`, optional `identify` und `registration` — bildet einen trunk. Die Unterschiede liegen im Detail: Ein trunk authentifiziert sich *ausgehend* (Sie sind der Client, daher kommen die Anmeldedaten in `outbound_auth`, nicht in `auth`), er registriert normalerweise keinen User Agent bei Ihnen (Sie registrieren sich bei *ihm*, oder er sendet Ihnen Datenverkehr von einer bekannten IP), und er leitet eingehende Anrufe in einen dedizierten context wie `from-pstn` anstatt in `from-internal`.

> **Im Vergleich zum alten TDM trunk.** Ein PRI gab Ihnen eine feste Anzahl von B-Kanälen (23 bei einem T1, 30 bei einem E1) und signalisierte den Verbindungsaufbau über einen dedizierten D-Kanal (siehe das Kapitel *Legacy channels*). Ein SIP trunk hat keine feste Kanalanzahl — die Kapazität ist das, was Ihre Bandbreite, die Richtlinie Ihres Anbieters und etwaige `max_contacts`/concurrent-call-Limits zulassen. Caller-ID, DID und Anrufstatus, die früher über ISDN-Informationselemente übertragen wurden, nutzen heute SIP-Header und SDP.

Es gibt zwei Möglichkeiten, wie ein ITSP dem Austausch von Datenverkehr mit Ihnen zustimmt, und diese bestimmen, wie Sie den trunk aufbauen: **registrierungsbasiert** und **IP-basiert (statisch)**. Wir behandeln beide nacheinander.

## Registration-based trunks

Ein registration-based trunk ist das Modell, das verwendet wird, wenn der Provider erwartet, dass *Sie* sich bei *ihm* anmelden. Ihr Asterisk sendet periodisch ein SIP `REGISTER` an den Provider und authentifiziert sich mit Benutzername und Passwort, genau so, wie sich ein Telefon an Ihrer PBX registriert. Dies ist üblich, wenn Ihre öffentliche IP dynamisch ist, wenn Sie sich hinter NAT befinden oder wenn der Provider Kunden einfach anhand von SIP-Anmeldedaten anstatt anhand der IP-Adresse identifiziert.

In PJSIP befindet sich die ausgehende Anmeldung in einem dedizierten `registration` Objekt. Es ersetzt die einzelne `register =>` Zeile, die der entfernte `chan_sip` Treiber in `sip.conf` verwendete. Hier ist ein vollständiger registrierender trunk zu einem fiktiven Provider, der dem verifizierten Muster aus den früheren Kapiteln folgt — beachten Sie `outbound_auth` (nicht `auth`), `server_uri`/`client_uri` (nicht `server`/`client`), `from_user`/`from_domain` am endpoint und `dtmf_mode=rfc4733`:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-auth]
type=auth
auth_type=digest
username=4830001000
password=Lab-itsp-secret

[itsp-aor]
type=aor
contact=sip:itsp.example.com:5060

[itsp-reg]
type=registration
transport=transport-udp
outbound_auth=itsp-auth
server_uri=sip:itsp.example.com:5060
client_uri=sip:4830001000@itsp.example.com:5060
contact_user=4830001000
retry_interval=60
```

Ein paar Dinge, die zu beachten sind:

- **`auth_type=digest`, nicht `userpass`.** Beide erzeugen die gleiche Digest-Authentifizierung, aber in Asterisk 22 sind `userpass` (und das alte `md5`) **veraltet und werden stillschweigend in `digest` konvertiert**. Bevorzugen Sie `digest` in neuen Konfigurationen; Sie werden `userpass` weiterhin in älteren Dateien und in den früheren Kapiteln dieses Buches sehen.
- **`outbound_auth` sowohl am endpoint als auch bei der registration.** Die registration verwendet es, um die `REGISTER` zu authentifizieren; der endpoint verwendet es, um auf die `407 Proxy Authentication Required` zu antworten, die der Provider an einen ausgehenden `INVITE` zurücksendet. Sie können sich ein `auth` Objekt teilen.
- **`from_user` / `from_domain`.** Viele Provider lehnen Anrufe ab, deren `From` Header nicht Ihre Kontonummer und deren Domain enthält. Diese beiden Optionen legen genau das fest.
- **`contact_user=4830001000`.** Dies wird zum user-Teil des `Contact`, den Sie registrieren, damit der Provider weiß, an welche Nummer eingehende Anrufe zugestellt werden sollen. Es ist das moderne Äquivalent des `/9999` Suffixes in der alten `register =>` Zeile.
- **`retry_interval=60`.** Wenn die Registrierung fehlschlägt, versuchen Sie es alle 60 Sekunden erneut.

Bestätigen Sie nach einem reload die Registrierung mit `pjsip show registrations`. Im Labor — wo `itsp.example.com` nicht tatsächlich antwortet — sieht die Tabelle wie folgt aus:

```
*CLI> pjsip show registrations

 <Registration/ServerURI..............................>  <Auth....................>  <Status.......>
==========================================================================================

 itsp-reg/sip:itsp.example.com:5060                      itsp-auth                   Rejected          (exp. 56s)

Objects found: 1
```

Das `(exp. Ns)` Suffix zählt die Sekunden bis zum nächsten Versuch herunter; sobald es null erreicht, liest es kurz `(exp. Ns ago)`, bevor der erneute Versuch gestartet wird. Bei einem echten Provider zeigt die `Status` Spalte `Registered` mit den verbleibenden Sekunden bis zur nächsten Aktualisierung an. `Rejected` (oder `Unregistered`) bedeutet, dass der Provider die Anmeldung nicht akzeptiert hat — schalten Sie `pjsip set logger on` ein und lesen Sie die `401`/`403` Antwort, meistens ein falscher Benutzername, ein falsches Passwort oder eine falsche `client_uri` Domain.

## IP-basierte (statische) Trunks

Das zweite Modell benötigt keinerlei Registrierung. Der Provider kennt Ihre öffentliche IP-Adresse und sendet Anrufe direkt dorthin; Sie wiederum senden Anrufe an die bekannte Signalisierungs-IP des Providers. Die Authentifizierung erfolgt über die **Quell-IP-Adresse**, nicht über SIP-Anmeldedaten. Dies ist typisch für Trunks zwischen zwei Servern, die Sie kontrollieren, oder für einen Unternehmen-Trunk, bei dem beide Seiten statische Adressen haben.

Das entscheidende Objekt ist `identify`. Es sagt Asterisk: „Jede SIP-Anfrage, die von *dieser* IP eingeht, gehört zu *jenem* endpoint.“ Ohne dieses Objekt versucht PJSIP, eine eingehende Anfrage anhand des `From` Benutzers einem endpoint zuzuordnen, was bei Datenverkehr eines Carriers nicht funktioniert – daher würde der Anruf abgelehnt oder an den `anonymous` endpoint weitergeleitet werden.

Ein statischer Trunk lässt das `registration` Objekt weg und fügt `identify` hinzu:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com

[itsp-aor]
type=aor
contact=sip:203.0.113.10:5060

[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
```

`match` akzeptiert eine IP-Adresse, einen CIDR-Bereich oder einen Hostnamen. **Hostnamen werden nur einmal beim Laden der Konfiguration aufgelöst**, wenn sich also die IP Ihres Providers ändert, müssen Sie neu laden. Für einen Carrier, der mehrere Media Gateways veröffentlicht, listen Sie jede Signalisierungs-IP auf – Sie können `match` wiederholen oder ein CIDR angeben:

```
[itsp-identify]
type=identify
endpoint=itsp
match=203.0.113.10
match=203.0.113.11
match=198.51.100.0/24
```

Überprüfen Sie mit `pjsip show identifies`, was Asterisk akzeptieren wird. Hier erfasst aus dem Labor (die `sipp-identify` Zeile ist der bereits bestehende SIPp-endpoint des Labors):

```
*CLI> pjsip show identifies

 Identify:  <Identify/Endpoint...........................................................>
      Match:  <criteria...........................>
==========================================================================================

 Identify:  itsp-identify/itsp
      Match: 172.30.0.50/32

 Identify:  sipp-identify/sipp
      Match: 172.30.0.0/24

Objects found: 2
```

### Die Sicherheitsimplikation

Ein IP-basierter Trunk ohne Authentifizierung ist eine Tür, und `identify`/`match` ist das einzige Schloss daran. Wenn Sie `match` einen zu breiten Bereich wählen – oder wenn ein Angreifer eine Quell-IP fälschen kann – landen Anrufe unauthentifiziert in Ihrem `from-pstn` context. Zwei Verteidigungsmaßnahmen, die zusammen verwendet werden sollten:

- **So eng wie möglich abgleichen.** Bevorzugen Sie spezifische Host-IPs gegenüber weiten CIDRs. Nur die echten Signalisierungs-IPs des Providers gehören in `match`.
- **Kombinieren Sie es mit einer ACL.** PJSIP kann Datenverkehr auf der SIP-Ebene verwerfen, bevor er jemals einen endpoint erreicht, indem ein `type=acl` Objekt (oder `acl.conf`) verwendet wird:

```
[itsp-acl]
type=acl
deny=0.0.0.0/0.0.0.0
permit=203.0.113.10
permit=203.0.113.11
```

Ein `type=acl` Abschnitt benötigt keine Referenz: `res_pjsip_acl` wendet jedes solche Objekt auf *allen* eingehenden SIP-Datenverkehr an, bevor dieser einen endpoint erreicht. (Die `acl` und `contact_acl` Optionen des Objekts ziehen benannte Regellisten aus `acl.conf`, anstatt `permit`/`deny` wie oben inline aufzulisten.) Das Prinzip ist dasselbe wie im SIP-Kapitel: Alles ablehnen, dann nur das erlauben, dem Sie vertrauen. Und was auch immer Ihr Trunk-context tut, **lassen Sie ihn niemals einen context erreichen, der Anrufe zurück zum PSTN tätigen kann**, ohne eine bewusste, authentifizierte Regel – das ist die klassische Lücke für Gebührenbetrug.

> **Welches Modell sollte ich verwenden?** Wenn der Provider Ihnen einen Benutzernamen und ein Passwort gibt, verwenden Sie einen **Registrierungs**-Trunk. Wenn er nach Ihrer IP-Adresse fragt und Ihnen seine gibt, verwenden Sie einen **Identify**-Trunk. Einige Provider unterstützen beides; viele echte Trunks kombinieren eine Registrierung (damit der Provider Sie finden kann) mit einem Identify (damit eingehende INVITEs von den Media Gateways des Providers auch dann zugeordnet werden, wenn sie von einer anderen IP als der des Registrars eintreffen).

## Inbound-Routing und DID-Verarbeitung

Sobald eingehende Anrufe eintreffen, landen sie im `context` des endpoint — hier
`from-pstn`. Eine **DID** (Direct Inward Dialing number) ist einfach die gewählte Nummer,
die der Provider Ihnen in der request URI übermittelt. Ihre Aufgabe im dialplan ist es, jede
DID einem Ziel zuzuordnen: einer einzelnen extension, einem IVR, einer queue oder einer ring group.

Die Nummer, die der Provider sendet, wird als `${EXTEN}` in `from-pstn` abgeglichen. Wie viel
davon Sie sehen, hängt vom Provider ab — manche senden die vollständige E.164-Nummer
(`+4830001000`), manche senden die nationale Nummer, manche senden nur die letzten paar
Ziffern. Untersuchen Sie einen echten eingehenden Anruf mit `pjsip set logger on` und betrachten Sie die
request URI, bevor Sie Muster schreiben.

### Eine DID zu einer extension

Der einfachste Fall — eine einzelne DID, die direkt an ein Telefon weitergeleitet wird:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID: ${EXTEN} from ${CALLERID(num)})
 same =>             n,Dial(PJSIP/6001,30,tT)
 same =>             n,Hangup()
```

### Eine DID zu einem IVR (automatische Telefonzentrale)

Eine Hauptnummer, die mit einem Menü antworten soll, anstatt ein Telefon klingeln zu lassen:

```
[from-pstn]
exten => 4830001000,1,Answer()
 same =>             n,Wait(1)
 same =>             n,Goto(ivr-main,s,1)
```

`ivr-main` ist der Kontext für die automatische Telefonzentrale, den Sie in den dialplan-Kapiteln
erstellt haben (`Background()` + `WaitExten()`). Das Routing der DID ist lediglich ein `Goto`.

### Eine DID zu einer queue

Eine Support-Leitung, die in einer Anruf-queue landen soll:

```
[from-pstn]
exten => 4830002000,1,Answer()
 same =>             n,Queue(support,t,,,300)
 same =>             n,Hangup()
```

### Viele DIDs auf einmal

Wenn Sie einen Nummernblock kaufen, hält ein Muster den dialplan klein. Angenommen, Ihr
DID-Bereich ist `4830003000`–`4830003099` und der Provider sendet die vollständige Nummer; ordnen
Sie die letzten zwei Ziffern jeder DID der extension `60xx` zu:

```
[from-pstn]
exten => _48300030XX,1,NoOp(DID ${EXTEN} -> extension 60${EXTEN:-2})
 same =>             n,Dial(PJSIP/60${EXTEN:-2},30,tT)
 same =>             n,Hangup()
```

`${EXTEN:-2}` nimmt die letzten zwei Ziffern (ein negativer Offset zählt von rechts),
sodass `4830003007` die `PJSIP/6007` klingeln lässt. Eine `did => extension`-Nachschlagetabelle, die mit
`GoSub` oder einer Asterisk-Datenbank (`AstDB`/`func_odbc`) erstellt wurde, lässt sich noch besser skalieren,
aber für eine Handvoll Nummern sind explizite Muster am übersichtlichsten.

> **Fangen Sie nicht zugeordnete DIDs ab.** Fügen Sie eine `i` (invalid) extension zu `from-pstn` hinzu, damit eine
> falsch geroutete eingehende Nummer eine Ansage abspielt oder den Operator klingeln lässt, anstatt
> stillschweigend abgebrochen zu werden:
>
> ```
> exten => i,1,Playback(ss-noservice)
>  same =>  n,Hangup()
> ```

## Outbound Routing, Caller-ID und E.164

Ausgehende Anrufe verlaufen in die entgegengesetzte Richtung: Ein internes Telefon wählt eine Nummer, Ihr dialplan gleicht diese ab, entfernt eventuelle Zugangspräfixe, setzt die vom Provider erwartete Caller-ID und übergibt den Anruf mit `Dial(PJSIP/<number>@itsp)` an das trunk endpoint.

### Senden des Anrufs an den trunk

Die Kanal-Syntax für einen trunk lautet `PJSIP/<number>@<endpoint>`: Der Teil vor dem `@` wird zum Benutzerteil der ausgehenden Request-URI, und der Teil nach dem `@` benennt das endpoint, dessen `aor` `contact` den Ziel-Host liefert. Eine klassische Regel für "Wähle 9 für eine externe Leitung":

```
[from-internal]
exten => _9NXXXXXXXXX,1,NoOp(Outbound to ${EXTEN:1} via itsp)
 same =>             n,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp,60,tT)
 same =>             n,Hangup()
```

`${EXTEN:1}` entfernt den führenden `9` Zugangscode, bevor die Nummer gesendet wird. Das Muster `_9NXXXXXXXXX` gleicht `9` plus eine 10-stellige Nummer ab, deren erste Ziffer 2–9 ist; passen Sie dies an Ihren dialplan an.

### Caller-ID bei ausgehenden Anrufen

Die meisten ITSPs ignorieren – oder lehnen aktiv – eine Caller-ID ab, die keine Nummer ist, die Sie besitzen. Setzen Sie die ausgehende Caller-ID-Nummer mit der `CALLERID(num)` Funktion vor `Dial()` auf eine Ihrer DIDs, wie oben gezeigt. Sie können auch den Namen festlegen:

```
 same => n,Set(CALLERID(num)=4830001000)
 same => n,Set(CALLERID(name)=ACME Corp)
```

Wenn der Provider Ihren Caller-ID-Namen dennoch entfernt oder überschreibt, entspricht dies seiner Richtlinie – viele Netzbetreiber beziehen den angezeigten Namen aus ihrer eigenen CNAM-Datenbank, basierend auf der Nummer, und nicht aus Ihrem `From` Header.

Zwei endpoint-Optionen interagieren damit:

- **`from_user`** setzt den Benutzerteil des `From` Headers auf SIP-Ebene, den einige Provider verwenden, um Ihr Konto unabhängig von `CALLERID(num)` zu identifizieren.
- **`trust_id_outbound`** (Standard `no`) steuert, ob Asterisk datenschutzrelevante Identitäts-Header (`P-Asserted-Identity`/`P-Preferred-Identity`) nach außen sendet. Lassen Sie dies deaktiviert, es sei denn, Ihr Provider dokumentiert, dass er PAI wünscht; in diesem Fall setzen Sie `trust_id_outbound=yes` und `send_pai=yes`.

### Normalisierung auf E.164

E.164 ist das internationale Nummernformat: ein führendes `+`, Ländercode, dann die nationale Nummer, ohne Leerzeichen oder Satzzeichen (zum Beispiel `+5548999990000` oder `+14155550100`). Netzbetreiber erwarten – oder verlangen – zunehmend E.164 auf dem trunk. Anstatt die Formatierung über den gesamten dialplan zu verteilen, normalisieren Sie diese einmalig im ausgehenden context.

Ein nordamerikanisches Beispiel, das eine 10-stellige lokale Nummer, eine 11-stellige `1`-präfixierte Nummer oder eine bereits im E.164-Format vorliegende Nummer akzeptiert und dem trunk immer `+1…` präsentiert:

```
[from-internal]
; 10-digit local: 4155550100  -> +14155550100
exten => _NXXNXXXXXX,1,Set(E164=+1${EXTEN})
 same =>            n,Goto(send-pstn,${E164},1)

; 11-digit with national prefix: 14155550100 -> +14155550100
exten => _1NXXNXXXXXX,1,Set(E164=+${EXTEN})
 same =>             n,Goto(send-pstn,${E164},1)

; already E.164: the user dialled + first
exten => _+X.,1,Goto(send-pstn,${EXTEN},1)

[send-pstn]
exten => _+X.,1,Set(CALLERID(num)=+14155550000)
 same =>     n,Dial(PJSIP/${EXTEN}@itsp,60,tT)
 same =>     n,Hangup()
```

Einige Provider wünschen das `+`; andere bevorzugen nur die Ziffern. Wenn Ihr Provider das `+` ablehnt, entfernen Sie es beim Ausgang mit `${EXTEN:1}` im `Dial`. Der Punkt ist, dass das gesamte Wissen über das Format an einem Ort gespeichert ist, sodass ein Wechsel des Providers – oder das Hinzufügen eines zweiten – nur eine einzeilige Änderung erfordert.

## Failover und Least-Cost Routing

Mit einem einzigen trunk bedeutet ein Ausfall des Anbieters, dass keine ausgehenden Anrufe mehr möglich sind. Mit zwei oder mehr können Sie automatisch ein Failover durchführen und sogar die günstigste Route pro Ziel auswählen — *Least-Cost Routing* (LCR).

### Failover mit `${DIALSTATUS}`

`Dial()` setzt die Kanalvariable `${DIALSTATUS}`, wenn es zurückkehrt. Die Werte, die für ein Failover relevant sind, sind `CHANUNAVAIL` (der trunk konnte überhaupt nicht erreicht werden) und `CONGESTION` (der Anruf wurde abgelehnt, z. B. alle Leitungen belegt). Versuchen Sie es mit dem primären trunk; wenn dieser den Anruf nicht weiterleiten konnte, weichen Sie auf den Backup-trunk aus:

```
[from-internal]
exten => _9NXXXXXXXXX,1,Set(CALLERID(num)=4830001000)
 same =>             n,Dial(PJSIP/${EXTEN:1}@itsp_primary,60,tT)
 same =>             n,NoOp(Primary returned ${DIALSTATUS})
 same =>             n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?backup:done)
 same =>             n(backup),Dial(PJSIP/${EXTEN:1}@itsp_backup,60,tT)
 same =>             n(done),Hangup()
```

Beachten Sie die bewusste Entscheidung, **kein** Failover bei `BUSY` oder `NOANSWER` durchzuführen — diese bedeuten, dass die *angerufene Partei* erreicht wurde und abgelehnt hat. Ein erneuter Versuch über einen anderen trunk würde also ein Telefon erneut klingeln lassen, das bereits abgelehnt hat (und könnte Sie einen zweiten Anruf kosten). Leiten Sie nur dann um, wenn der *trunk selbst* ausgefallen ist.

### Eine wiederverwendbare Routing-Subroutine

Diese Logik für jedes Wählmuster zu wiederholen, ist fehleranfällig. Fassen Sie sie in einer `GoSub`-Routine zusammen, die die Zielnummer entgegennimmt und jeden trunk der Reihe nach ausprobiert:

```
[from-internal]
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Set(CALLERID(num)=4830001000)
 same =>   n,Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try2:end)
 same =>   n(try2),Dial(PJSIP/${NUM}@itsp_backup,60,tT)
 same =>   n(try2-chk),GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?try3:end)
 same =>   n(try3),Dial(PJSIP/${NUM}@itsp_thirdparty,60,tT)
 same =>   n(end),Return()
```

Nun besteht jedes ausgehende Muster aus einem einzigen `GoSub`-Aufruf, und die trunk-Reihenfolge ist an genau einer Stelle definiert.

### Least-Cost Routing nach Ziel

Echtes LCR wählt den trunk basierend darauf aus, wohin der Anruf geht. Ein gängiges Schema besteht darin, das Zielpräfix abzugleichen und jede Anrufklasse an den Anbieter zu senden, der dafür am günstigsten ist — zum Beispiel internationale Anrufe an einen Wholesale-Carrier und lokale/nationale Anrufe an Ihren primären Anbieter:

```
[from-internal]
; international (011 + ...) -> wholesale trunk, then fall back to primary
exten => _9011.,1,GoSub(dialout-intl,s,1(${EXTEN:1}))
 same =>      n,Hangup()
; everything else -> domestic routing
exten => _9NXXXXXXXXX,1,GoSub(dialout,s,1(${EXTEN:1}))
 same =>             n,Hangup()

[dialout-intl]
exten => s,1,Set(NUM=${ARG1})
 same =>   n,Dial(PJSIP/${NUM}@itsp_wholesale,60,tT)
 same =>   n,GotoIf($["${DIALSTATUS}" = "CHANUNAVAIL" | "${DIALSTATUS}" = "CONGESTION"]?fb:end)
 same =>   n(fb),Dial(PJSIP/${NUM}@itsp_primary,60,tT)
 same =>   n(end),Return()
```

Für mehr als nur ein paar Präfixe sollten Sie die Routing-Tabelle in einer Datenbank (`func_odbc`/`AstDB`) speichern und den trunk anhand des Präfixes nachschlagen, anstatt Muster fest zu kodieren. Der dialplan bleibt klein und die Tarife befinden sich in einer Tabelle, die Sie bearbeiten können, ohne die Logik neu zu laden.

## NAT und trunks

NAT ist die häufigste Ursache für Probleme mit trunks — typischerweise einseitiges Audio oder ein trunk, der sich zwar registriert, aber niemals eingehende Anrufe empfängt. Die Ursache ist dieselbe wie bei Telefonen (behandelt in *SIP & PJSIP in depth* und *Designing a VoIP network*): Asterisk gibt in SIP und SDP seine eigene Vorstellung seiner Adresse an, und hinter NAT ist dies eine private RFC 1918-Adresse, zu der der Provider keine Route zurück hat.

Für trunks besteht die Lösung aus zwei Teilen — Einstellungen am **transport** (Ihre öffentliche Adresse) und Einstellungen am **endpoint** (wie die Medien des Providers behandelt werden).

### Am transport — Ihre öffentliche Adresse

Wenn sich der Asterisk-Server selbst hinter NAT befindet (ein Cloud- oder On-Premise-System mit einer privaten IP und einer 1:1 öffentlichen IP), teilen Sie dem transport seine öffentliche Adresse mit und welche Netzwerke lokal sind. Diese Optionen werden einmalig am `transport` eingestellt und gelten für den gesamten darüber laufenden Datenverkehr:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
local_net=172.30.0.0/24
local_net=10.0.0.0/8
external_media_address=203.0.113.50
external_signaling_address=203.0.113.50
```

- **`external_signaling_address`** — die öffentliche IP, die Asterisk in SIP-Header (`Via`, `Contact`) für Ziele außerhalb von `local_net` schreibt.
- **`external_media_address`** — die öffentliche IP, die Asterisk in die SDP `c=`-Zeile schreibt, damit RTP an den richtigen Ort zurückkehrt. Normalerweise identisch mit der Signalisierungsadresse.
- **`local_net`** — Netzwerke, die Asterisk als intern behandelt, damit es Adressen für LAN-peers *nicht* umschreibt. Listen Sie jedes interne Subnetz auf.

### Am endpoint — die Medien des Providers

Die andere Hälfte kümmert sich um einen Provider, der selbst hinter NAT sitzt oder Medien einfach von einer anderen Adresse sendet als derjenigen, die in seinem SDP steht. Stellen Sie dies pro trunk-endpoint ein:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
direct_media=no
rtp_symmetric=yes
force_rport=yes
rewrite_contact=yes
outbound_auth=itsp-auth
aors=itsp-aor
from_user=4830001000
from_domain=itsp.example.com
```

- **`direct_media=no`** — sorgt dafür, dass Medien durch Asterisk fließen, anstatt die beiden Seiten direkt miteinander kommunizieren zu lassen. Dies ist über NAT hinweg unerlässlich und ohnehin erforderlich, wenn Sie den Anruf aufzeichnen, transkodieren oder überwachen möchten.
- **`rtp_symmetric=yes`** — das klassische *comedia*-Verhalten: Senden Sie RTP an die Adresse zurück, von der die Medien tatsächlich kamen, nicht an die Adresse, die das SDP behauptet.
- **`force_rport=yes`** — antworten Sie auf SIP von der Quell-IP/Port der Anfrage (RFC 3581), anstatt dem `Via`-Header zu vertrauen.
- **`rewrite_contact=yes`** — schreiben Sie bei eingehenden SIP-Nachrichten von diesem endpoint den `Contact`-Header (oder einen entsprechenden `Record-Route`-Header) auf die Quell-IP-Adresse und den Port um, von denen das Paket tatsächlich stammte. Laut der Dokumentation der Option "hilft dies Servern bei der Kommunikation mit endpoints, die sich hinter NATs befinden" und "hilft bei der Wiederverwendung zuverlässiger Transportverbindungen wie TCP und TLS."

> **Empfehlung — Telefone vs. trunks.** `rewrite_contact` ist für Telefone fast immer die richtige Wahl, da ihr angekündigter Kontakt normalerweise eine private RFC 1918-Adresse ist, die nicht zu ihnen zurückführbar ist. Bei einem auf statischen IPs basierenden trunk ist der Kontakt des Providers normalerweise bereits eine korrekte öffentliche Adresse, daher ist ein Umschreiben oft unnötig; einige Betreiber ziehen es vor, dies dort deaktiviert zu lassen und es nur für Registrierungs-trunks und NAT-Telefone zu aktivieren. Der dokumentierte Effekt der Option ist lediglich das oben genannte eingehende `Contact`/`Record-Route`-Umschreiben — daher ist es die sicherste Praxis, dies mit Ihrem spezifischen Anbieter zu testen, bevor Sie es bei einem statischen trunk aktivieren.

Sie können die effektiven Einstellungen für jeden endpoint mit `pjsip show endpoint <name>` bestätigen — `direct_media`, `rtp_symmetric`, `force_rport`, `rewrite_contact` und der Rest werden alle im Parameter-Dump ausgegeben.

## Lab — ein simulierter ITSP mit einem zweiten Asterisk und SIPp

Sie benötigen keinen kostenpflichtigen trunk, um zu üben. Das Lab des Buches betreibt bereits einen Asterisk 22.10.0-Container und einen SIPp-Container in einem privaten `172.30.0.0/24` Netzwerk; wir werden den SIPp-Container als den „Carrier“ behandeln, der eingehende Anrufe tätigt, und einen trunk endpoint hinzufügen, der diese Anrufe in einem `from-pstn` context landen lässt.

![Ein SIP trunk zwischen der Asterisk PBX und dem ITSP: Die PBX registriert sich als ein Konto, ausgehende Anrufe wählen `PJSIP/<num>@trunk` und eingehende Anrufe landen im `from-pstn` context.](images/sip-trunk-lab.png){width=100%}(../images/09-sip-trunking-fig01.png)

### 1. Den trunk endpoint hinzufügen

Fügen Sie einen IP-basierten trunk zu `lab/asterisk/etc/pjsip.conf` hinzu, der dem SIPp-Host des Labs entspricht und eingehende Anrufe in `from-pstn` landen lässt:

```
[itsp]
type=endpoint
context=from-pstn
disallow=all
allow=ulaw
allow=alaw
dtmf_mode=rfc4733
aors=itsp-aor

[itsp-aor]
type=aor
contact=sip:172.30.0.50:5060

[itsp-identify]
type=identify
endpoint=itsp
match=172.30.0.50
```

### 2. Die eingehende DID routen

Fügen Sie in `lab/asterisk/etc/extensions.conf` einen `from-pstn` context hinzu, der die DID beantwortet, die der simulierte Carrier wählen wird, und diese wiedergibt; fügen Sie dann eine ausgehende Regel hinzu:

```
[from-pstn]
exten => 4830001000,1,NoOp(Inbound DID ${EXTEN} from ${CALLERID(num)})
 same =>             n,Answer()
 same =>             n,Playback(demo-congrats)
 same =>             n,Hangup()
exten => i,1,Playback(ss-noservice)
 same =>  n,Hangup()

[from-internal]
; outbound across the trunk
exten => _9X.,1,Set(CALLERID(num)=4830001000)
 same =>     n,Dial(PJSIP/${EXTEN:1}@itsp,30,tT)
 same =>     n,Hangup()
```

Laden Sie beide Dateien neu (`core reload`) und überprüfen Sie, ob der trunk geladen wurde:

```
*CLI> pjsip show endpoint itsp
 Endpoint:  itsp                                                 Not in use    0 of inf
        Aor:  itsp-aor                                           0
      Contact:  itsp-aor/sip:172.30.0.50:5060              ...        NonQual         nan
   Identify:  itsp-identify/itsp
        Match: 172.30.0.50/32
```

### 3. Einen eingehenden Anruf über den trunk tätigen

Richten Sie ein SIPp-Szenario auf die PBX mit der DID als Zielbenutzer. Das Lab liefert bereits `lab/sipp/uac_9000.xml` mit, welches die extension `9000` per INVITE anspricht; kopieren Sie es nach `uac_did.xml` und ändern Sie den request-URI/`To` Benutzer von `9000` auf `4830001000`, führen Sie es dann vom SIPp-Container aus:

```
docker compose -f lab/docker-compose.yml exec -T sipp \
  sipp -sf /sipp/uac_did.xml 172.30.0.10:5060 -m 1 -nostdin
```

Beobachten Sie, wie der Anruf auf der Asterisk-Konsole auf `from-pstn` trifft (`pjsip set logger on` zeigt das eingehende INVITE; `core show channels` zeigt den `PJSIP/itsp-…` channel, der `demo-congrats` wiedergibt). Da die Quell-IP von SIPp mit dem `identify` übereinstimmt, wird der Anruf ohne Authentifizierung akzeptiert — genau so, wie sich ein statischer Carrier-trunk verhält.

### 4. Den trunk untersuchen

Erfassen Sie die vollständige Konfiguration des trunks für Ihre Notizen:

```
pjsip show endpoint itsp
pjsip show aors
pjsip show identifies
```

### 5. (Zusatzaufgabe) Einen Registrierungs-trunk erstellen

Starten Sie den *zweiten* Asterisk-Container als echten Registrar: Geben Sie ihm ein `endpoint`+`auth`+`aor` für das Konto `4830001000`, tauschen Sie dann auf der PBX den `identify` Block gegen den `registration` Block vom Anfang dieses Kapitels aus (wobei `server_uri` auf die IP des zweiten Containers zeigt). Bestätigen Sie mit `pjsip show registrations`, dass der Status `Registered` lautet, und tätigen Sie dann einen Anruf in jede Richtung.

## Zusammenfassung

Ein SIP trunk verbindet Ihre PBX mit der Außenwelt, und in PJSIP ist er lediglich ein endpoint, der aus derselben `endpoint` + `auth` + `aor` Familie aufgebaut ist, die Sie bereits kennen, ergänzt um ein `identify` oder ein `registration`. Verwenden Sie einen **registration trunk** (`type=registration` mit `outbound_auth`), wenn der Anbieter Ihnen einen Benutzernamen und ein Passwort zur Verfügung stellt; verwenden Sie einen **IP-based trunk** (`type=identify` mit `match`), wenn die Authentifizierung über die Quell-IP erfolgt — und sichern Sie Letzteren mit einem eng gefassten `match` und einem `acl` ab, da ein nicht authentifizierter trunk ein Ziel für Gebührenbetrug (toll fraud) darstellt. Eingehend trifft die DID des Anbieters als `${EXTEN}` in Ihrem `from-pstn` context ein, wo Sie sie an eine extension, ein IVR oder eine Warteschlange weiterleiten — Muster und `${EXTEN:-N}` halten DID-Blöcke kompakt. Setzen Sie ausgehend `CALLERID(num)` auf eine Nummer, die Ihnen gehört, normalisieren Sie an einer zentralen Stelle auf E.164 und übergeben Sie den Anruf an `PJSIP/<number>@trunk`. Sorgen Sie für Ausfallsicherheit, indem Sie mehrere trunks ausprobieren und basierend auf `${DIALSTATUS}` verzweigen (`CHANUNAVAIL`/`CONGESTION` bedeuten Umleitung; `BUSY`/`NOANSWER` tun dies nicht), und legen Sie Least-Cost-Routing in einer `GoSub` Tabelle ab. Schließlich ist NAT für trunks zweiseitig: `external_media_address`/`external_signaling_address`/`local_net` auf dem **transport** für Ihre öffentliche Adresse, sowie `direct_media=no`, `rtp_symmetric`, `force_rport` und `rewrite_contact` auf dem **endpoint** für die Medien des Anbieters.

## Quiz

1. In PJSIP werden die Anmeldedaten, die zur Authentifizierung eines *ausgehenden* Anrufs oder einer Registrierung bei einem Provider verwendet werden, referenziert mit:
   - A. `auth=`
   - B. `outbound_auth=`
   - C. `secret=`
   - D. `remotesecret=`
2. Sie sollten einen `type=registration` trunk verwenden, wenn:
   - A. Der Provider Sie anhand Ihrer Quell-IP-Adresse identifiziert.
   - B. Der Provider Ihnen einen Benutzernamen und ein Passwort gibt und erwartet, dass Sie sich anmelden.
   - C. Sie niemals möchten, dass Asterisk ein `REGISTER` sendet.
   - D. Der trunk zwischen zwei Servern mit statischer IP besteht, die Sie kontrollieren.
3. Die `match` Option des `identify` Objekts akzeptiert (wählen Sie alle zutreffenden aus):
   - A. Eine IP-Adresse
   - B. Einen CIDR-Bereich
   - C. Einen Hostnamen (der zum Zeitpunkt des Konfigurationsladens aufgelöst wird)
   - D. Nur einen SIP-Benutzernamen
4. Auf Asterisk 22 ist `auth_type=userpass`:
   - A. Der einzige gültige Wert
   - B. Veraltet und konvertiert zu `digest`
   - C. Entfernt und verursacht einen Ladefehler
   - D. Erforderlich für ausgehende Registrierungen
5. Eine eingehende DID-Nummer kommt im dialplan an als:
   - A. `${CALLERID(num)}`
   - B. `${EXTEN}` im `context` des trunk endpoints
   - C. `${DIALSTATUS}`
   - D. `${CONTEXT}`
6. Um die letzten zwei Ziffern der gewählten DID `4830003007` an eine extension zu senden, würden Sie Folgendes verwenden:
   - A. `${EXTEN:2}`
   - B. `${EXTEN:0:2}`
   - C. `${EXTEN:-2}`
   - D. `${EXTEN:8}`
7. Nach `Dial()` zu einem trunk sollten Sie auf einen Backup-trunk ausweichen, bei dem welche `${DIALSTATUS}` Werte gelten (wählen Sie zwei)?
   - A. `CHANUNAVAIL`
   - B. `BUSY`
   - C. `CONGESTION`
   - D. `NOANSWER`
8. Um die caller-ID-Nummer festzulegen, die dem Provider vor dem Rauswählen präsentiert wird, verwenden Sie:
   - A. `Set(CALLERID(num)=4830001000)`
   - B. `Set(from_user=4830001000)`
   - C. `Set(DIALSTATUS=4830001000)`
   - D. `Set(CONNECTEDLINE(num)=4830001000)`
9. Die Optionen, die Asterisk seine *öffentliche* Adresse mitteilen, wenn sich der Server hinter NAT befindet, werden eingestellt auf dem:
   - A. `endpoint`
   - B. `aor`
   - C. `transport` (`external_media_address` / `external_signaling_address`)
   - D. `registration`
10. `rtp_symmetric=yes` auf einem trunk endpoint veranlasst Asterisk dazu:
    - A. RTP mit SRTP zu verschlüsseln
    - B. RTP an die Adresse zurückzusenden, von der die Medien tatsächlich ankamen, wobei das SDP ignoriert wird
    - C. RTP vollständig zu deaktivieren
    - D. Direct Media zwischen endpoints zu erzwingen

**Antworten:** 1 — B · 2 — B · 3 — A, B, C · 4 — B · 5 — B · 6 — C · 7 — A, C · 8 — A · 9 — C · 10 — B
