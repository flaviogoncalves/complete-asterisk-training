# Asterisk Sicherheit

Seit Beginn ist das Thema Sicherheit für Asterisk von entscheidender Bedeutung. SIP, das Session Initiation Protocol, ist laut CERT.BR das am häufigsten angegriffene Protokoll im Internet. Jeder, der einen Honeypot betreibt, kann dies bestätigen. Das Problem des Internet Revenue Share Fraud ist sehr ernst und kann zu Verlusten in Höhe von Hunderttausenden von Dollar führen. Sie sollten niemals einen Asterisk Server ohne angemessene Sicherheitsvorkehrungen mit dem Internet verbinden. In diesem Kapitel lernen Sie, wie Sie die wichtigsten Arten von Angriffen identifizieren, denen Sie ausgesetzt sein können, und wie Sie diese durch eine geeignete Sicherheitsrichtlinie verhindern. Zu guter Letzt erfahren Sie, wie Sie die vorgeschlagene Sicherheitsrichtlinie implementieren.

Dieses Kapitel konzentriert sich auf **Asterisk 22 LTS**, bei dem PJSIP (`res_pjsip` / `chan_pjsip`) der einzige SIP-Kanal ist. (Der alte `chan_sip` Treiber wurde in Asterisk 21 entfernt – siehe das Kapitel *Legacy Channels*, falls Sie ein älteres System migrieren.) Eine sicherheitsrelevante Konsequenz: Fehlgeschlagene Authentifizierungen werden nun über das Asterisk **security event framework** und den dedizierten `security` Logger-Kanal ausgegeben, was die Konfiguration von Fail2Ban verändert (wird später in diesem Kapitel behandelt).

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Die wichtigsten Arten von Angriffen zu identifizieren, die häufig auf Asterisk-Server verübt werden
- Eine effektive Sicherheitsrichtlinie zu definieren
- Die Sicherheitsrichtlinie zu implementieren
- IPTABLES für Asterisk zu installieren und zu konfigurieren
- Fail2Ban für Asterisk zu installieren und zu konfigurieren
- TLS und SRTP für die Verschlüsselung zu installieren und zu konfigurieren

## Hauptangriffe auf IP-Telefonie

Die Hauptangriffe auf IP-Telefonie lassen sich in DOS/DDOS, Dienstdiebstahl/Toll Fraud (Gebührenbetrug) und Abhören klassifizieren. Einige der Bezeichnungen können verwirrend sein, und verschiedene Quellen verwenden manchmal unterschiedliche Namen für denselben Angriff. Dienstdiebstahl, Toll Fraud, Internet Revenue Share Fraud und Telefonbetrug sind verschiedene Namen für Hacker, die Ihre PBX nutzen, um Datenverkehr zu einer Premium-Rate-Nummer zu leiten und Rückvergütungen vom Anbieter zu erhalten.

### DDoS/DOS

Denial of Service und Distributed Denial of Service sind beliebte Angriffe auf jede IT-Infrastruktur. Bei SIP und anderen Voice-over-IP-Protokollen ist das nicht anders. Ein Distributed Denial of Service wird normalerweise von einem Botnetz verübt, während ein DOS nur von einem einzelnen Computer ausgeht. Im Februar 2011 führte das Sality-Botnetz einen heimlichen, koordinierten Scan des gesamten IPv4-Adressraums durch, um nach anfälligen SIP-Servern zu suchen – Forscher, die das UCSD Network Telescope beobachteten, schrieben dies etwa drei Millionen verschiedenen Quell-IPs zu, die den UDP-Port 5060 sondierten, höchstwahrscheinlich um SIP-Konten für Toll Fraud per Brute-Force zu knacken.[^sality]

[^sality]: A. Dainotti et al., "Analysis of a '/0' Stealth Scan from a Botnet," *IEEE/ACM Transactions on Networking*, 2015 (DOI 10.1109/TNET.2013.2297678).

![Ein Peer-to-Peer-Botnetz, das Tausende von SIP-Registrierungsversuchen auf einen Server richtet](../images/19-security-fig01.png)

Das DOS wird normalerweise durch Techniken wie Fuzzing und Flooding angewendet. Flooding kann SIP, IAX, RTP und andere Protokolle verwenden. Sie können den Dienst vollständig stoppen oder die Sprachqualität verschlechtern. Sie sind sehr schwer abzuwehren, wenn die Ports zum Internet hin offen sind. Nachfolgend sind einige der von Angreifern verwendeten Werkzeuge aufgeführt:

**Fuzzing:**

- **PROTOS Test Suite (c07-sip)** — von der University of Oulu OUSPG. Sendet Tausende von fehlerhaften Paketen, um eine Fehlfunktion wie einen Pufferüberlauf zu provozieren, der die Software stoppt.
- **Voiper** — generiert mehr als 200.000 Tests, die alle SIP-Attribute abdecken, und überprüft, ob Ihr Server die Nachrichten effektiv verarbeiten kann. <http://voiper.sourceforge.net/>

**Flooding:**

- **INVITE Flooder** — überflutet den Server mit SIP INVITE-Anfragen. <http://www.hackingvoip.com/tools/inviteflood.tar.gz>
- **IAX Flooder** — überflutet den Server mit IAX2-Datenverkehr. <http://www.hackingvoip.com/tools/iaxflood.tar.gz>
- **RTP Flooder** — überflutet aktive Mediensitzungen mit RTP-Paketen, um die Sprachqualität zu verschlechtern. <http://www.hackingvoip.com/tools/rtpflood.tar.gz>

### Abwehrtechniken für DoS/DDoS

Meine Empfehlungen sind:

1. Setzen Sie Ihren Asterisk-Server nicht dem Internet aus, es sei denn, dies ist mit angemessenem Schutz (SBC) erforderlich.
2. Verwenden Sie im internen Netzwerk ein Virtual LAN für Sprache, insbesondere wenn Sie sich an einer Universität oder Hochschule befinden, wo die Anzahl der Benutzer hoch ist.
3. Verwenden Sie VPN oder TLS für den externen Zugriff.

### Internet Revenue Share Fraud

Dieser Betrug ist etwas schwierig zu verstehen. Der Schlüssel liegt im Verständnis des Konzepts einer International Premium Rate Number (IPRN).

![Die drei Schritte des Internet Revenue Share Fraud: Kauf einer Premium-Rate-Nummer, Suche nach einem anfälligen VoIP-Gerät und Anruf der Nummer, dann Einfordern der Auszahlung](../images/19-security-fig02.png)

Eine IPRN ist eine Nummer, die Sie bei einigen speziellen Internet-Telefonanbietern kostenlos zuteilen können. Suchen Sie nach Internet Premium Rate Number Providers und Sie werden eine ganze Reihe davon finden. Bei dieser Art von Betreiber können Sie beispielsweise eine Nummer in einem Satellitennetzwerk wie Iridium zuteilen, ein Ziel, das den Anrufer Zehntel-Dollar pro Minute kostet. Der IPRN-Anbieter zahlt Ihnen einen Prozentsatz des Umsatzes (10 bis 20 % des Einkommens) für jede empfangene Minute zurück.

![Eine Preisliste eines IPRN-Anbieters, die Auszahlungsraten pro Land und Testnummern zeigt](../images/19-security-fig03.png)

Nach der Zuteilungsphase versucht der Hacker, einen offenen Asterisk-Server zu finden, der in der Lage ist, die zugeteilte IPRN zu wählen. Die vom Hacker kontrollierte PBX des Opfers tätigt Hunderte von Anrufen an die IPRN-Nummer, was eine große Rückzahlung für den Hacker und eine riesige Telefonrechnung für das Opfer generiert. Oftmals höher als Hunderttausende von Dollar an einem einzigen Wochenende.

Hauptwerkzeuge, die von Hackern verwendet werden, um eine PBX anzugreifen:

1. **SIPVicious**: http://code.google.com/p/sipvicious/. Sipvicious ist ein einfach zu bedienendes Sicherheits-Tool-Set. Sein Hauptziel ist es, anfällige PBXs zu erkennen und die SIP-Passwörter mittels Brute-Force-Angriff zu knacken. Das am häufigsten verwendete Werkzeug ist svcrack. Das Tool ist in der Lage, Tausende von Passwörtern pro Sekunde zu testen.
2. **Telefon-Schwachstellen**. Ein weiterer Punkt, der häufig von Hackern als Angriffsvektor genutzt wird, ist das Telefon selbst. Viele Leute, die Asterisk installieren, ändern das Standardpasswort in der Weboberfläche des Telefons nicht. Sobald diese Telefone im Internet offen sind, können Hacker versuchen, das Standard-Schnittstellenpasswort zu verwenden, um die Konfiguration herunterzuladen, wo sie oft das geheime SIP-Passwort finden können.

#### TFTPTheft:

Wenn Sie die automatische Bereitstellung (Auto-Provisioning) von Telefonen über TFTP verwenden, sind Sie wahrscheinlich anfällig für diese Art von Angriff. TFTP ist eine einfache und unsichere Form eines File Transfer Protocols.

![Ein Angreifer lädt erratbare .cfg-Dateien von einem TFTP-Server herunter und erntet Klartext-Anmeldedaten aus den Konfigurationsdateien](../images/19-security-fig04.png)

Die Namen der Konfigurationsdateien sind leicht erratbar, indem man die MAC-Adresse gefolgt von .cfg verwendet (z. B. 001A2B3C4D5E.cfg). Ein versierter Hacker kann leicht ein Dienstprogramm erstellen, um alle MAC-Adressen nacheinander auszuprobieren, oder einfach ein Tool herunterladen, um dies zu tun. Die Konfigurationsdatei ist normalerweise unverschlüsselt und enthält das geheime SIP-Passwort.

#### Abwehr von Brute-Force-Angriffen und TFTPTheft

Um diese Angriffe abzuwehren, können Sie die unten stehenden Lösungen anwenden. Brute-Force: Die beste Lösung zur Abwehr von Brute-Force-Angriffen ist die Verhinderung sequenzieller unbefugter Versuche. Fast jeder Asterisk-Installer verwendet dafür das Dienstprogramm fail2ban. Wenn fail2ban mehrere Versuche mit dem falschen Passwort oder Benutzernamen erkennt, sperrt es die IP des Angreifers für eine bestimmte Zeit. Die zweite Maßnahme gegen Brute-Force ist die Verwendung starker Passwörter mit mehr als 12 Zeichen und mindestens einem Sonderzeichen. TFTPTheft: Um TFTPTheft zu verhindern, konfigurieren Sie die Bereitstellung so, dass HTTPS mit Name und Passwort verwendet wird. Die Datei wird verschlüsselt übertragen, und ein Name sowie ein Passwort verhindern, dass Angreifer versuchen, Dateien herunterzuladen.

### Abhören

Wir sehen nicht viele dieser Arten von Angriffen, da sie in den meisten Fällen einfach nicht erkannt werden. Abhören ist in einer IP-Umgebung sehr schwer zu erkennen. Dienstprogramme wie das frei verfügbare UCsniff sind in der Lage, ein VoIP-Gespräch in den meisten Netzwerken abzuhören. Die Haupttechnik besteht darin, ARP-Spoofing zu verwenden, um den Datenverkehr über den Computer zu erzwingen, auf dem UCsniff läuft, und die Anrufe aufzuzeichnen.

#### Abwehr von Abhörmaßnahmen

Sie können das Abhören verhindern, indem Sie Ihren VoIP-Datenverkehr verschlüsseln. Der andere Weg besteht darin, Man-in-the-Middle-Angriffe (MITM) in Ihrem Netzwerk zu verhindern. ARP-Inspektion ist sehr effektiv, um MITM in Layer-2-Netzwerken zu verhindern. Fragen Sie Ihren Netzwerk-Support, um zu verstehen, wie man dies implementiert. Später in diesem Buch werden wir lernen, wie man eine Verschlüsselung auf Basis von TLS und SRTP installiert. Sie können auch ARPWatch verwenden, um festzustellen, ob jemand das ARP-Protokoll missbraucht, um Ihr Netzwerk anzugreifen.

## Sicherheitsrichtlinie für Asterisk

Der beste Weg, Sicherheit zu implementieren, ist die Erstellung einer Sicherheitsrichtlinie. Für dieses Training schlage ich eine Sicherheitsrichtlinie vor, die für die meisten Asterisk-Installationen geeignet ist. Nutzen Sie diese als Ausgangsbasis und passen Sie sie an Ihre Bedürfnisse an. Die vorgeschlagene Sicherheitsrichtlinie folgt hier:

1. Keine unnötigen UDP/TCP-Ports offen lassen.
2. Kein Zugriff auf administrative Schnittstellen (SSH/HTTPS) über das Internet.
3. Für den Zugriff auf SSH und/oder HTTP/HTTPS sollten explizite Ausnahmen in der IPTABLES-Firewall definiert werden.
4. Starke Passwörter mit 12 Zeichen und mindestens einem Sonderzeichen verwenden.
5. IP-Adressen, die mehr als 10 Mal bei der Authentifizierung scheitern, mit Fail2ban sperren.
6. Passwortbestätigung für internationale Anrufe.
7. Zugriff auf den SIP-Port auf Ihren bekannten IP-Adressbereich beschränken.

Wenn Sie einen externen Zugriff auf Ihre PBX benötigen, gibt es zwei Möglichkeiten. Verwenden Sie einen SBC (Session Border Controller), um Ihren Server vor DOS/DDOS zu schützen, oder nutzen Sie ein VPN, wann immer Sie externen Zugriff benötigen. Wenn Sie den Port 5060 ohne SBC oder VPN im Internet offen lassen, sind Sie anfällig für DOS/DDOS-Angriffe. Das Risiko liegt bei Ihnen.

### Härtung in der PJSIP-Ära (Asterisk 22)

Über die Firewall und Fail2Ban hinaus bietet der PJSIP-Stack von Asterisk 22 verschiedene Konfigurationsebenen, die Teil Ihrer Sicherheitsrichtlinie sein sollten. Diese ergänzen (ersetzen nicht) die oben genannten Netzwerkkontrollen:

- **Authentifizierung pro endpoint.** Jeder endpoint sollte auf einen dedizierten `type=auth` Abschnitt mit einem starken, eindeutigen `password` (`auth_type=digest`) verweisen. Verwenden Sie Anmeldedaten niemals für mehrere endpoints wieder.
- **Anonyme Anrufe sind integriert.** PJSIP verrät nicht, ob ein Benutzername existiert, wenn die Authentifizierung fehlschlägt. Um anonyme Anrufe überhaupt zu akzeptieren, müssen Sie explizit einen endpoint namens `anonymous` erstellen und `type=identify` Abschnitte (Abgleich über Quell-IP) verwenden, um bekannte Peers endpoints zuzuordnen. Wenn Sie keine anonymen Anrufe wünschen, erstellen Sie einfach keinen `anonymous` endpoint; nicht zugeordnete Anfragen werden dann abgelehnt oder erfordern eine Authentifizierung.
- **ACLs.** Schränken Sie ein, wer einen endpoint erreichen darf, indem Sie `/etc/asterisk/acl.conf` benannte ACLs verwenden, auf die vom endpoint aus mit `acl=` (Signalisierung/Quell-ACL) und `contact_acl=` (schränkt die Kontakt-/Registrierungsadresse ein) verwiesen wird. Sie können permit/deny auch direkt am endpoint festlegen.
- **`qualify`.** Setzen Sie `qualify_frequency` (und `qualify_timeout`) auf dem AOR, damit Asterisk die Erreichbarkeit registrierter Kontakte aktiv überwacht und inaktive Kontakte entfernt.
- **PJSIP-Transport-Härtung / DoS-Schutz.** Der `type=transport` bietet kein client-seitiges Limit pro Transport, daher erfolgt der Schutz vor Verbindungsfluten über die Firewall (die iptables/Fail2Ban-Regeln in diesem Kapitel) und nicht über eine PJSIP-Option. Was der Transport *tatsächlich* bietet, ist die Anpassung von TCP-Keep-Alive (`tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`), um tote oder halb offene Verbindungen zu bereinigen, sowie `local_net`/`external_*` Einstellungen für die korrekte NAT-Behandlung. Kombinieren Sie diese mit den Firewall-Regeln, um Angriffe durch Verbindungsfluten abzuwehren.
- **TLS + SRTP für Medien.** Verschlüsseln Sie die Signalisierung mit einem TLS-Transport und die Medien mit `media_encryption=sdes` (oder `dtls` für WebRTC) am endpoint — dies wird später in diesem Kapitel behandelt.
- **AMI/ARI-Zugriffskontrolle.** Beschränken Sie das Asterisk Manager Interface (`manager.conf`) und ARI (`ari.conf` / `http.conf`) auf localhost oder ein vertrauenswürdiges Verwaltungsnetzwerk, verwenden Sie starke, eindeutige Geheimnisse, binden Sie den HTTP-Server an eine private Schnittstelle und setzen Sie diese niemals dem Internet aus.

Alle oben genannten Optionsnamen wurden für Asterisk 22.10 bestätigt: Der `type=transport` Abschnitt bietet `tcp_keepalive_enable`, `tcp_keepalive_idle_time`, `tcp_keepalive_interval_time`, `tcp_keepalive_probe_count`, `tos`, `cos`, `local_net` und die `external_*` Familie, hat aber **keine** `max_clients` Option — Schutz vor Verbindungsfluten erfolgt über die Firewall, nicht über den Transport. Die `acl` und `contact_acl` endpoint-Optionen übernehmen Abschnittsnamen von `acl.conf`, und der Abgleich der Quell-IP für nicht authentifizierte Peers erfolgt über `type=identify` Abschnitte (`match=`).

### Entfernen unnötiger Ports

Anstatt alle Schwachstellen im Zusammenhang mit allen Asterisk-Protokollen zu entdecken, vereinfachen wir das Problem, indem wir unnötige Ports entfernen. Um alle vom Asterisk-Server geöffneten Ports aufzulisten, verwenden Sie:

```
netstat -pantu |grep asterisk
```

Die Ausgabe des Befehls ist unten dargestellt.

![netstat-Ausgabe, die die vielen von Asterisk gebundenen Ports zeigt, einschließlich 4569 (IAX) und 2727 (MGCP)](../images/19-security-fig05.png)

Wenn Sie sich die Ausgabe ansehen, werden Sie feststellen, dass viele Ports offen sind. Brauchen wir sie? Nicht unbedingt; 2727 ist das MGCP-Protokoll (chan_mgcp), 4569 ist IAX (chan_iax2). Wenn Sie diese Protokolle nicht verwenden, können Sie das Modul einfach in der Konfigurationsdatei modules.conf entfernen.

Sie werden vielleicht bemerken, dass Asterisk einen UDP-Port mit hoher Nummer bindet. Dies kommt daher, dass der Resolver von `res_pjsip` ausgehende DNS-Abfragen durchführt (der Quellport ist flüchtig, wie bei jeder Client-DNS-Abfrage), nicht von einem eingehenden Listener — Ihre Firewall muss dafür nur **etablierten/zugehörigen** Rückverkehr zulassen (die iptables `conntrack ESTABLISHED,RELATED` Regel, die unten gezeigt wird, deckt dies bereits ab). Sie müssen **keinen** breiten eingehenden hohen UDP-Bereich nur für PJSIP-DNS öffnen.

Um unnötige Ports zu entfernen, deaktivieren Sie die Module, die Sie nicht verwenden. Bearbeiten Sie die Datei modules.conf und fügen Sie `noload` Zeilen für die Kanäle und Protokolle hinzu, die Sie nicht verwenden. **Führen Sie kein** noload für `res_pjsip`, `res_pjproject` oder `chan_pjsip` aus — diese werden für SIP in Asterisk 22 benötigt:

```
; res_pjsip / res_pjproject / chan_pjsip are REQUIRED in Asterisk 22 - keep them loaded
noload => chan_iax2.so
noload => chan_unistim.so
```

(In Asterisk 22 müssen Sie kein noload mehr für `chan_mgcp` oder `chan_skinny` ausführen — diese Treiber wurden in Asterisk 21 *entfernt* und sind nicht Teil eines Standard-Builds von 22.) Mit den obigen Anweisungen habe ich alle unnötigen Kanäle entfernt und nur PJSIP beibehalten. Sie können beliebige Protokollmodule auswählen, entfernen Sie einfach die ungenutzten. Das Ergebnis ist im Screenshot unten zu sehen — nur der SIP-Port (5060), der von Ihrem PJSIP-Transport gebunden wird, ist jetzt eingehend exponiert.

![netstat-Ausgabe nach dem Deaktivieren der ungenutzten Module: nur UDP-Port 5060 bleibt von Asterisk gebunden](../images/19-security-fig06.png)

### Implementierung der Sicherheitsrichtlinie mit IPTABLES

IPTABLES oder netfilter ist eine Standard-Firewall, die in den meisten Linux-Distributionen vorhanden ist. In diesem Labor werden wir iptables und fail2ban konfigurieren. Das Ziel ist es, die empfohlene Sicherheitsrichtlinie für Asterisk zu implementieren und allen unnötigen Datenverkehr zu blockieren. Befolgen Sie die unten stehenden Schritte:

1. Blockieren Sie allen externen Datenverkehr.
2. Erlauben Sie SSH-Datenverkehr aus einem internen Netzwerk oder von einem einzelnen Host.
3. Erlauben Sie SIP-Datenverkehr über UDP und TCP auf den Ports 5060.
4. Erlauben Sie RTP-Datenverkehr im UDP-Medienportbereich. Es gibt keinen einzelnen eingebauten Standard — Asterisks eigenes `rtp.conf` greift auf die Ports 5000–31000 zurück, wenn nichts eingestellt ist, aber die mitgelieferte `rtp.conf.sample` konfiguriert `rtpstart=10000` / `rtpend=20000`, daher verwenden wir diesen Beispielbereich hier. Passen Sie Ihre Firewall-Regel an das an, was Sie tatsächlich in `rtpstart`/`rtpend` in `rtp.conf` eingestellt haben.

Stellen Sie sicher, dass Sie Konsolenzugriff auf den Server haben; Sie möchten sich nicht selbst aus dem System aussperren. Seien Sie vorsichtig.

1. Installieren Sie das Paket net-persistent.

   ```
   sudo apt-get install iptables-persistent
   ```

2. Erlauben Sie allen Datenverkehr vom Loopback.

   ```
   sudo iptables -I INPUT -i lo -j ACCEPT
   sudo iptables -I OUTPUT -o lo -j ACCEPT
   ```

3. Erlauben Sie etablierte Verbindungen.

   ```
   sudo iptables -I INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
   ```

4. Erlauben Sie SSH/HTTPS-Datenverkehr aus dem Netzwerk 192.168.0.0.

   ```
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 22 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   sudo iptables -I INPUT -p tcp -s 192.168.0.0/16 --dport 443 -m conntrack --ctstate
   NEW,ESTABLISHED -j ACCEPT
   ```

5. Fügen Sie die Asterisk-Regeln ein.

   ```
   sudo iptables -I INPUT -p udp -m udp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5060 -j ACCEPT
   sudo iptables -I INPUT -p tcp -m tcp --dport 5061 -j ACCEPT
   sudo iptables -I INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
   ```

   Beachten Sie, dass Port 5061 (SIP über TLS) **TCP** ist, nicht UDP. Die obigen Regeln öffnen 5060 sowohl für UDP als auch für TCP und 5061 für TCP. Wenn Sie nur TLS betreiben, können Sie die einfachen 5060-Regeln vollständig weglassen. Öffnen Sie nur die Ports, an die Ihre PJSIP-Transporte tatsächlich gebunden sind.

   `-I` bedeutet PREPEND (voranstellen).

6. Die letzte Regel muss ein Drop sein.

   ```
   sudo iptables -A INPUT -j DROP
   ```

   `-A` bedeutet APPEND (anhängen). Hinweis: Seien Sie vorsichtig bei der Pflege neuer Regeln; Sie müssen Regeln vor dem DROP hinzufügen. Verwenden Sie PREPEND für neue Regeln `-I`.

7. Speichern Sie die Regeln und starten Sie iptables neu.

   ```
   sudo iptables-save >/etc/iptables/rules.v4
   sudo /etc/init.d/netfilter-persistent restart
   ```

### Verwendung von Fail2Ban zum Blockieren mehrfacher fehlgeschlagener Authentifizierungsversuche

Fail2Ban ist fast ein Standard für Asterisk. Die meisten Benutzer implementieren es, um die Sicherheit zu erhöhen. Dieses Dienstprogramm scannt die Asterisk-Protokolle nach fehlgeschlagenen Versuchen und sperrt die IP-Adressen der Angreifer. Nachfolgend finden Sie die Anweisungen zur Installation von Fail2Ban.

In Asterisk 22 meldet PJSIP fehlgeschlagene Authentifizierungen und andere Sicherheitsereignisse über das Asterisk **Security Event Framework**, das in den dedizierten **`security` Logger-Kanal** geschrieben wird. Damit Fail2Ban funktioniert, müssen Sie:

1. Den Sicherheitskanal in `/etc/asterisk/logger.conf` aktivieren. Die Syntax ist `<filename> => <levels>`; um die Sicherheitsstufe in eine Datei namens `security` zu senden, schreiben Sie:

```
[logfiles]
security => security
```

führen Sie dann `logger reload` über die CLI aus. Dies erzeugt `/var/log/asterisk/security` mit einer Zeile pro Sicherheitsereignis in der Form:

```
[2026-01-15 10:23:45] SECURITY[1234] res_security_log.c: SecurityEvent="InvalidPassword",...,RemoteAddress="IPV4/UDP/203.0.113.7/5060",...
```

Die Ereignisse, die für Fail2Ban relevant sind, sind `InvalidPassword`, `ChallengeResponseFailed`, `InvalidAccountID` und `FailedACL`, von denen jedes ein `RemoteAddress="IPV4/UDP/<ip>/<port>"` Feld enthält, das den Angreifer identifiziert. (Beachten Sie, dass die Adresse als `IPV4/UDP/.../...` verpackt ist, nicht als reine IP — Ihr Filter muss den Host aus dieser Zeichenfolge extrahieren.)

2. Den `asterisk` Jail auf diese Datei (`logpath = /var/log/asterisk/security`) richten und einen Filter verwenden, der dieses Sicherheitsereignisformat analysiert.

Moderne Fail2Ban-Versionen enthalten einen `asterisk` Filter, dessen `failregex` bereits mit den oben genannten Ereignissen übereinstimmt und `<HOST>` aus dem `RemoteAddress` Feld extrahiert, zum Beispiel:

```
failregex = ^SecurityEvent="(?:FailedACL|InvalidAccountID|ChallengeResponseFailed|InvalidPassword)".*,RemoteAddress="IPV[46]/[^/"]+/<HOST>/\d+"
```

PBX-Distributionen (FreePBX/Sangoma) liefern äquivalente Filter mit. Bevorzugen Sie den mitgelieferten Filter gegenüber dem manuellen Schreiben, da die genauen Ereigniszeichenfolgen versionsabhängig sind. Ein Hinweis, den Sie beachten sollten: Ein mittlerweile gepatchter Hinweis (GHSA-5743-x3p5-3rg7) zeigte, dass präparierter PJSIP-Datenverkehr gefälschte Protokollzeilen einschleusen konnte — halten Sie sowohl Asterisk als auch Ihren Fail2Ban-Filter auf dem neuesten Stand.

Nachfolgend finden Sie die Anweisungen zur Installation von Fail2Ban.

1. Installieren Sie fail2ban unter Linux.

   ```
   sudo apt-get install fail2ban
   ```

2. Aktivieren Sie fail2ban für Asterisk und SSH.

   ```
   sudo vi /etc/fail2ban/jails.d/defaults-debian.conf
   ```

   Fügen Sie die folgenden Zeilen hinzu, um fail2ban für ssh und asterisk zu aktivieren.

   ```
   [sshd]
   enabled = true
   [asterisk]
   enabled=true
   ```

3. Starten Sie fail2ban neu.

   ```
   /etc/init.d/fail2ban restart
   ```

4. Überprüfen Sie es. Ändern Sie das Passwort Ihres Softphones und versuchen Sie 10 Mal, sich neu zu registrieren. Überprüfen Sie mit `iptables -L`, ob die Adresse des Softphones als blockierte Adresse aufgenommen wurde.
5. Entfernen Sie die Adresse aus der Sperrliste (angenommen, die Adresse ist 192.168.0.5).

   ```
   sudo fail2ban-client set asterisk unbanip 192.168.0.5
   ```

Hinweis: Ersetzen Sie im Befehl 192.168.0.5 durch die IP-Adresse Ihres Telefons.

### Implementierung von TLS und SRTP

Ich werde diesen Abschnitt in zwei Teile unterteilen. Im ersten Teil behandeln wir TLS zur Verschlüsselung der Signalisierung und im zweiten Teil SRTP zur Verschlüsselung der Medien. Das Ziel hierbei ist es, Asterisk für diese Ressourcen zu konfigurieren.

#### TLS

TLS (Transport Layer Security) ist der Verschlüsselungsmechanismus, der zum Schutz der SIP-Signalisierung definiert wurde. Die folgende Tabelle fasst zusammen, gegen welche Angriffe TLS schützt:

| Angriffsart | Geschützt? | Hinweise |
|----------------|-----------|-------|
| Signalisierungsangriffe | Ja | TLS stellt die Integrität der Nachrichten sicher |
| Man-in-the-Middle | Ja | TLS prüft das Serverzertifikat |
| Abhören | Nein | TLS verschlüsselt die Signalisierung, nicht die Medien |

Für die Medienverschlüsselung (Sprache/Video) verwenden Sie SRTP.

#### Selbstsignierte digitale Zertifikate

Es gibt zwei Arten von Zertifikaten, die Sie verwenden können: selbstsignierte und kommerzielle. Selbstsignierte Zertifikate werden von Ihrem eigenen Server signiert, während kommerzielle Zertifikate von einer externen Behörde signiert werden. Für VoIP können Sie Ihre eigene Zertifizierungsstelle sein. Es besteht keine Notwendigkeit für ein externes Zertifikat wie von GoDaddy oder Verisign; dies ist eine unnötige Ausgabe. Wir werden unsere eigenen Zertifikate mit ast_tls_cert generieren.

#### Konfiguration von TLS mit selbstsignierten Zertifikaten

Nachfolgend finden Sie eine Schritt-für-Schritt-Anleitung zur Implementierung von TLS. Wir generieren zuerst die Zertifikate, konfigurieren dann den PJSIP-TLS-Transport (siehe "Konfiguration von TLS mit chan_pjsip") und verweisen schließlich das Softphone darauf. Wir verwenden das SipPulse Softphone, das TLS und SRTP nativ unterstützt. (Jedes TLS/SRTP-fähige SIP-Softphone funktioniert auf die gleiche Weise.)

**Schritt 1.** Erstellen Sie einen privaten RSA-Schlüssel mit 3DES-Verschlüsselung und einer Länge von 4096 Bit für unsere Zertifizierungsstelle. Der unten stehende Befehl, der sich in /usr/src/asterisk-22.x.y/contrib/scripts befindet, erstellt die Zertifizierungsstelle und das Asterisk-Zertifikat. Passen Sie die Anweisungen wie üblich an, falls erforderlich; Versionen ändern sich, Verzeichnisse ändern sich. Bitte achten Sie darauf, was Sie tun. Verwenden Sie Ihre Domain oder IP-Adresse in der Option –C. Der Befehl ast_tls_cert hat drei Optionen.

- -C Host oder IP-Adresse (Ich habe 192.168.0.74 verwendet, die IP-Adresse meiner VM)
- -O Organisationsname
- -d Verzeichnis, in dem die Schlüssel gespeichert werden sollen

```
mkdir /etc/asterisk/keys
cd /usr/src/asterisk-22.0.0/contrib/scripts
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts# ./ast_tls_cert -C 192.168.0.74 -O "AsteriskGuide" -d /etc/asterisk/keys
No config file specified, creating '/etc/asterisk/keys/tmp.cfg'
You can use this config file to create additional certs without
re-entering the information for the fields in the certificate
Creating CA key /etc/asterisk/keys/ca.key
Generating RSA private key, 4096 bit long modulus
........................................................++
........................................................++
e is 65537 (0x010001)
Enter pass phrase for /etc/asterisk/keys/ca.key:
Verifying - Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating CA certificate /etc/asterisk/keys/ca.crt
Enter pass phrase for /etc/asterisk/keys/ca.key:
Creating certificate /etc/asterisk/keys/asterisk.key
Generating RSA private key, 2048 bit long modulus
........................++++++
......................++++++
e is 65537 (0x010001)
Creating signing request /etc/asterisk/keys/asterisk.csr
Creating certificate /etc/asterisk/keys/asterisk.crt
Signature ok
subject=CN = 192.168.0.74, O = AsteriskGuide
Getting CA Private Key
Enter pass phrase for /etc/asterisk/keys/ca.key:
Combining key and crt into /etc/asterisk/keys/asterisk.pem
root@asterisk:/usr/src/asterisk-22.0.0/contrib/scripts#
```

Ich werde kein Client-Zertifikat generieren, da wir das Zertifikat nicht zur Authentifizierung des Clients verwenden werden. Der Client muss sein eigenes Zertifikat nicht vorlegen.

**Schritt 2.** Konfigurieren Sie Asterisk, um unseren Client über TLS zu unterstützen. Dies erfolgt in `pjsip.conf` (ein TLS-Transport plus die endpoint-Einstellungen) — die vollständige Konfiguration wird im nächsten Abschnitt "Konfiguration von TLS mit chan_pjsip" gezeigt. Wir authentifizieren uns nicht mit Zertifikaten, sondern verschlüsseln nur den Datenverkehr.

**Schritt 3.** Installieren Sie ein TLS-fähiges SIP-Softphone (der Autor verwendet das SipPulse Softphone).

**Schritt 4.** Kopieren Sie die Zertifizierungsstelle auf den Computer, auf dem das Softphone läuft. Kopieren Sie nach der Installation die Datei `/etc/asterisk/keys/ca.crt` auf den Computer, auf dem das Softphone läuft (verwenden Sie scp oder WinSCP unter Windows), wenn Sie ein selbstsigniertes Zertifikat verwenden.

**Schritt 5.** Erstellen Sie das Konto im Softphone. Fügen Sie das Konto im Kontobildschirm normal wie jedes andere SIP-Konto hinzu. Verwenden Sie das richtige Passwort; die Authentifizierung basiert weiterhin auf dem Passwort.

**Schritt 6.** Stellen Sie TLS als Transport in den Kontoeinstellungen ein. Wählen Sie im Kontobildschirm des SipPulse Softphones (unten) **TLS** als Transport und verwenden Sie Port 5061. Passen Sie Ihre Firewall an, um den TCP-Port 5061 zu öffnen.

![Der Kontobildschirm des SipPulse Softphones — geben Sie den Server (Ihre Asterisk-IP oder Domain), Benutzername, Passwort und Anzeigename ein, dann wählen Sie den Transport (UDP, TCP oder TLS).](../images/softphone/sipphone-account.png){width=35%}

**Schritt 7.** Vertrauen Sie der Zertifizierungsstelle. Wenn Ihr Asterisk-TLS-Zertifikat von einer öffentlichen CA signiert ist (zum Beispiel Let's Encrypt — siehe das Kapitel *Deployment*), vertraut ein modernes Softphone wie das SipPulse Softphone diesem automatisch über den Zertifikatsspeicher des Systems, ohne manuellen Import. Wenn Sie ein selbstsigniertes Zertifikat verwenden, importieren Sie dessen CA (`/etc/asterisk/keys/ca.crt`) in den Client oder den Vertrauensspeicher des Betriebssystems oder akzeptieren Sie es, wenn Sie dazu aufgefordert werden.

**Schritt 8.** Sie benötigen **kein** Client-Zertifikat. Ein häufiges Missverständnis ist, dass jedes Telefon ein eigenes Zertifikat zur Authentifizierung benötigt — das ist nicht der Fall. An diesem Punkt *verschlüsselt* Asterisk nur die Sitzung; die Authentifizierung erfolgt weiterhin über Benutzername und Passwort. Asterisk überprüft standardmäßig keine Client-Zertifikate, daher ist es nicht erforderlich, ein Zertifikat pro Client zu verteilen.

**Schritt 9.** Starten Sie nach dem Ändern des Zertifikats oder Transports das Softphone vollständig neu (beenden und neu starten, nicht nur das Fenster schließen), damit es sich über den neuen Transport wieder verbindet.

### Konfiguration von TLS mit chan_pjsip

Lernen wir nun, wie man PJSIP für TLS konfiguriert. PJSIP ist der einzige SIP-Kanal in Asterisk 22, also gibt es nichts umzustellen — stellen Sie nur sicher, dass `res_pjsip`, `res_pjproject` und `chan_pjsip` geladen sind. Schritt 1: Bestätigen Sie, dass PJSIP in /etc/asterisk/modules.conf aktiviert ist.

```
; res_pjsip / res_pjproject / chan_pjsip must be loaded (do NOT noload them)
noload => chan_iax2.so
noload => chan_unistim.so
```

Schritt 2: Konfigurieren Sie PJSIP zur Unterstützung von TLS. Fügen Sie einen Abschnitt für den TLS-Transport in der Datei /etc/asterisk/pjsip.conf hinzu.

```
[transport-tls]
type=transport
protocol=tls
bind=0.0.0.0:5061
cert_file=/etc/asterisk/keys/asterisk.crt
priv_key_file=/etc/asterisk/keys/asterisk.key
method=tlsv1_2
```

Verwenden Sie `method=tlsv1_2` (oder `tlsv1_3`, falls Ihr OpenSSL/PJSIP-Build dies unterstützt) — TLS 1.0/1.1 sind veraltet und unsicher und sollten nicht verwendet werden.

Schritt 3: Konfigurieren Sie den endpoint für blink. Bearbeiten Sie `pjsip.conf` und bearbeiten Sie den Abschnitt für blink. Lassen Sie PJSIP den Transport automatisch auswählen.

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
dtmf_mode=rfc4733
media_encryption=sdes
[blink]
type=aor
max_contacts=2
remove_existing=yes
[blink]
type=auth
auth_type=digest
username=blink
password=supersecret
```

Schritt 4: Überprüfung. Um zu überprüfen, ob die Registrierung über TLS erfolgte, verwenden Sie den folgenden Befehl in der Asterisk-Konsole.

```text
asterisk*CLI> pjsip show aor blink

      Aor:  <Aor.............................................>  <MaxContact>
    Contact:  <Aor/ContactUri........................> <Hash....> <Status> <RTT(ms)..>
==========================================================================================

      Aor:  blink                                                2
    Contact:  blink/sip:03694827@192.168.0.67:56295;transp 620d91556d NonQual    nan
 ParameterName        : ParameterValue
 ====================================================================
 authenticate_qualify : false
 contact              : sip:03694827@192.168.0.67:56295;transport=tls
 default_expiration   : 3600
 max_contacts         : 2
 maximum_expiration   : 7200
 minimum_expiration   : 60
 qualify_frequency    : 0
 qualify_timeout      : 3.000000
 remove_existing      : true
 support_path         : false
```

### Sichere Anrufe mit SRTP tätigen

Das Protokoll, das für die Medienverschlüsselung verantwortlich ist, ist das Secure Real Time Protocol (SRTP), das im RFC3711 definiert ist. Einer der Nachteile des Protokolls ist das Fehlen einer standardisierten Methode zum Austausch von Schlüsseln. Asterisk verwendet SDES zum Austausch von Schlüsseln über das SDP-Protokoll, geschützt durch die Signalisierungsverschlüsselung, die durch TLS bereitgestellt wird. Es gibt auch andere Methoden wie MIKEY und ZRTP. ZRTP, entwickelt von Philipp Zimmermann, ist eine der ausgefeiltesten Methoden für den Schlüsselaustausch und die Medienverschlüsselung. Einige Softphones und Hardware-Telefone unterstützen ZRTP. Der Standardweg ist jedoch immer noch SDES, und Sie werden diese Methode bei fast jedem auf dem Markt erhältlichen Telefon finden. Nachfolgend ein Beispiel für eine Anfrage mit den Krypto-Schlüsseln, die im SDP in den Zeilen a=crypto:1 und a=crypto:2 definiert sind.

```
INVITE sip:8000@192.168.1.237 SIP/2.0
Via:
SIP/2.0/tls
192.168.1.192:65525;rport;branch=z9hG4bKPj9fa224a14b17488ea15625ead833ea3a
Max-Forwards: 70
From:
"Flavio"
<sip:flavio@192.168.1.237>;tag=35afe6cc11274934867b24e43c805638
To: <sip:8000@192.168.1.237>
Contact: <sip:pyhkxnjz@192.168.1.192:65524;transport=tls>
Call-ID: 530a339c72af47f0a76e7ecb2a58ac43
CSeq: 5669 INVITE
Allow: SUBSCRIBE, NOTIFY, PRACK, INVITE, ACK, BYE, CANCEL, UPDATE, MESSAGE
Supported: 100rel
User-Agent: Blink 0.2.5 (Windows)
Authorization: Digest username="flavio", realm="asterisk", nonce="72ff51ad",
uri="sip:8000@192.168.1.237",
response="ba8c10672751baa7007d82eb34e2340e",
algorithm=MD5
Content-Type: application/sdp
Content-Length: 544
v=0
o=- 3509174186 3509174186 IN IP4 192.168.1.192
s=Blink 0.2.5 (Windows)
c=IN IP4 192.168.1.192
t=0 0
m=audio 50004 RTP/SAVP 9 104 103 102 0 8 101
a=rtcp:50005
a=rtpmap:9 G722/8000
a=rtpmap:104 speex/32000
a=rtpmap:103 speex/16000
a=rtpmap:102 speex/8000
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
a=rtpmap:101 telephone-event/8000
a=fmtp:101 0-15
a=crypto:1
AES_CM_128_HMAC_SHA1_80
inline:WrtZH82ztz93albRNT8o+oMcK9GvlAHRoaR1STvJ
a=crypto:2
AES_CM_128_HMAC_SHA1_32
inline:4Ma9jJOCEEGMPzzkmgyf6ttp1qhN16yumdXB7eRv
a=sendrecv
```

#### Konfiguration von SRTP auf Asterisk

Die Konfiguration von SRTP auf Asterisk ist sehr einfach. Setzen Sie `media_encryption=sdes` auf dem endpoint; Sie können es auch mit `media_encryption_optimistic=no` erzwingen, sodass unverschlüsselte Medien abgelehnt werden, anstatt sie stillschweigend zuzulassen. Beachten Sie, dass SDES erfordert, dass die Signalisierung über TLS läuft, damit die Schlüssel nicht im Klartext gesendet werden.

**Schritt 1.** Asterisk-Konfiguration

Setzen Sie Folgendes im `type=endpoint` Abschnitt in `pjsip.conf`:

```
[blink]
type=endpoint
aors=blink
auth=blink
context=from-internal
disallow=all
allow=ulaw
transport=transport-tls
media_encryption=sdes
media_encryption_optimistic=no
```

**Schritt 2.** Softphone-Konfiguration

Aktivieren Sie im Softphone SRTP für die Kontomedien (setzen Sie die Option **SRTP (Media Encryption)** auf *Mandatory*), damit die Sprache verschlüsselt wird.

![Die Kontoeinstellungen des SipPulse Softphones (unterer Bereich) — setzen Sie **Transport** auf TLS und **SRTP (Media Encryption)** auf *Mandatory*, damit Signalisierung und Medien beide verschlüsselt sind.](../images/softphone/sipphone-config.png){width=35%}

## Aktivierung der Zwei-Wege-Authentifizierung für internationale Anrufe

Manchmal ist es am besten, gar keine internationalen Routen zu haben. Wenn Sie jedoch wirklich international wählen müssen, verwenden Sie ein zusätzliches Passwort. Wir werden die Asterisk-Anwendung vmauthenticate verwenden, um das voicemail-Passwort abzufragen, bevor ein internationales Gespräch aufgebaut wird. Dies wird im dialplan in der extensions.conf konfiguriert. Siehe das Beispiel unten. Selbst wenn ein Hacker also ein peer-Passwort herausfindet oder ein Telefon kompromittiert, benötigt er immer noch das voicemail-Passwort, um dieses Ziel anzurufen.

```
exten=_9011.,1,Playback(pleasedialyourvmpassword)
exten=_9011.,2,VMAuthenticate(${CALLERID(num)}@default,s)
exten=_9011.,3,Dial(PJSIP/${EXTEN:1}@my_trunk,20,tT)
exten=_9011.,4,Hangup()
```

`VMAuthenticate` ist in Asterisk 22 weiterhin eine Standardanwendung. Das obige `Dial()` leitet den Anruf über einen SIP/PJSIP trunk (`PJSIP/<number>@<trunk>`), was der Weg ist, wie die meisten modernen Installationen das PSTN erreichen — passen Sie `my_trunk` an Ihren eigenen trunk-Namen an und verwenden Sie `DAHDI/g1/...` nur, wenn Sie tatsächlich eine DAHDI-Spanne besitzen. Die Abwehr von Gebührenbetrug im dialplan — ein zweiter Faktor wie dieser, kombiniert mit der Einschränkung, welche contexts Ihre ausgehenden und internationalen Routen erreichen können — bleibt eine der wichtigsten Schutzmaßnahmen, die Sie implementieren können.

## Zusammenfassung

In diesem Kapitel haben Sie die Risiken kennengelernt, die mit dem Anschluss einer IP PBX an das Internet verbunden sind. Anschließend haben wir gelernt, wie man unsere PBX durch die Implementierung einer Sicherheitsrichtlinie schützt. Im Rahmen dieser Sicherheitsrichtlinie haben wir iptables, fail2ban, TLS, SRTP sowie eine Zwei-Wege-Authentifizierung für internationale Anrufe implementiert. Ich hoffe, dieses Kapitel hat Ihnen gefallen.

## Quiz

1. Was ist die wichtigste Gegenmaßnahme gegen Internet Revenue Share Fraud?
   - A. Implementierung von SRTP
   - B. Asterisk auf dem neuesten Stand halten
   - C. Implementierung von TLS
   - D. Verwendung starker Passwörter
2. SIP Fuzzing ist definiert als:
   - A. Ein DoS-Angriff unter Verwendung fehlerhafter Anfragen und Antworten
   - B. Dienstdiebstahl, bei dem Passwörter durch Brute-Force ermittelt werden
   - C. Abhören laufender Anrufe
   - D. Ein DDoS mit einer Flut von SIP-Anfragen
3. TFTPTheft tritt auf, wenn der Server Konfigurationsdateien über TFTP bereitstellt. Sie können dies vermeiden durch:
   - A. FTP
   - B. HTTP
   - C. HTTPS mit Benutzername und Passwort
   - D. SCP
4. Man-in-the-Middle-Angriffe verwenden eine Technik namens:
   - A. TFTP Theft
   - B. ARP Spoofing
   - C. MAC Poisoning
   - D. dsniff
5. Für SRTP verwendet Asterisk das folgende System zum Austausch von Schlüsseln:
   - A. MIKEY
   - B. SDES
   - C. ZRTP
   - D. Pluto
6. Das Dienstprogramm, das die Zertifizierungsstelle und Zertifikate generiert und sich in `/usr/src/asterisk-22.x.y/contrib/scripts` befindet, ist:
   - A. ast_tls_cert
   - B. gen_tls
   - C. gen_ast_tls
   - D. tls_generator
7. Gültige Strategien zur Verhinderung von Abhörmaßnahmen (kreuzen Sie alle zutreffenden an):
   - A. Implementierung von Detektoren für analoges Abhören
   - B. Verwendung des Dienstprogramms ARPwatch zur Erkennung von ARP Spoofing
   - C. Aktivierung der ARP-Spoofing-Erkennung in den Switches
   - D. Verwendung von SRTP
8. Asterisk unterstützt eine starke Authentifizierung durch die Überprüfung von Client-Zertifikaten. (Der PJSIP TLS-Transport kann das Zertifikat des Clients anfordern und überprüfen.)
   - A. Wahr
   - B. Falsch
9. Welche PJSIP endpoint-Einstellung aktiviert auf Asterisk 22 die SRTP-Medienverschlüsselung unter Verwendung von in-SDP (SDES) Schlüsseln?
   - A. `encryption=yes`
   - B. `media_encryption=sdes`
   - C. `srtp=mandatory`
   - D. `transport=tls`
10. In Asterisk 22 muss Fail2Ban fehlgeschlagene PJSIP-Authentifizierungsereignisse aus dem dedizierten ________ Logger-Kanal lesen (aktiviert in `logger.conf`).
   - A. `console`
   - B. `messages`
   - C. `security`
   - D. `verbose`

**Antworten:** 1 — D · 2 — A · 3 — C · 4 — B · 5 — B · 6 — A · 7 — B, C, D · 8 — A · 9 — B · 10 — C
