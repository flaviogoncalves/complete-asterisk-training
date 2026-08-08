# Deployment, monitoring & scaling

Asterisk in einer Laborumgebung dazu zu bringen, einen Anruf entgegenzunehmen, ist eine Sache; es als Dienst zu betreiben, der Abstürze, Neustarts, Upgrades und Angreifer übersteht – und den man beobachten, sichern und erweitern kann – ist eine andere. Dieses Kapitel behandelt alles, was passiert, *nachdem* der dialplan funktioniert. Wir beginnen mit dem Supervisor, der Asterisk am Laufen hält (systemd), gehen über zur Paketierung in einem Container (unter Verwendung des eigenen Docker-Labs des Buches als praktisches Beispiel), behandeln dann Konfigurationsmanagement und Backups, Monitoring und Observability und schließlich die Muster, auf die man zurückgreift, wenn ein Server nicht ausreicht: Hochverfügbarkeit und Skalierung sowie die Realitäten des Hostings in der Cloud.

Alles Gezeigte wurde mit dem Asterisk 22-Labor des Buches in `lab/` verifiziert – demselben Container, auf dem Sie während des gesamten Buches aufgebaut haben.

## Ziele

Nach Abschluss dieses Kapitels sollten Sie in der Lage sein:

- Asterisk 22 zuverlässig unter systemd als Nicht-Root-Benutzer mit automatischem Neustart auszuführen
- Asterisk mit Docker zu containerisieren und die netzwerktechnischen Kompromisse zu verstehen
- `/etc/asterisk` in der Versionsverwaltung zu halten und den richtigen Status zu sichern
- Ein laufendes System über die CLI, CDR/CEL, AMI/ARI und Metriken zu überwachen
- Active/Standby-Hochverfügbarkeits- und horizontale Skalierungsmuster anzuwenden
- Asterisk sicher in der Cloud hinter NAT und einer Firewall zu hosten

## Ausführen von Asterisk unter systemd

Auf jeder aktuellen Linux-Distribution — Debian 12, Ubuntu 22.04/24.04, Rocky/AlmaLinux 9 — ist der Dienstmanager **systemd**. Das Installationskapitel zeigte, dass der `make config` Schritt (ausgeführt während `make install`) ein distributionsspezifisches Init-Skript installiert (`/etc/init.d/asterisk` auf Debian, ein `rc.d` Skript auf RedHat), welches systemd dann automatisch als Dienst kapselt; Asterisk liefert zudem eine native systemd-Unit unter `contrib/systemd/asterisk.service` mit, die Sie stattdessen für eine feinere Steuerung installieren können.
In jedem Fall ist systemd die unterstützte Methode für den produktiven Betrieb von Asterisk. Verweisen Sie auf *Installing Asterisk 22* für den Build-Prozess selbst; hier konzentrieren wir uns darauf, was der Dienst Ihnen bietet und wie man ihn bedient.

### Die Service-Unit und ihr Lebenszyklus

Sobald `make config` den Dienst installiert hat, folgt der Lebenszyklus dem üblichen systemd-Standard:

```
systemctl enable asterisk     # start automatically at boot
systemctl start asterisk      # start now
systemctl status asterisk     # is it running? recent log lines
systemctl restart asterisk    # full stop + start
systemctl stop asterisk       # stop
journalctl -u asterisk        # service logs via the journal
```

Einige betriebliche Hinweise:

- **`restart` vs. ein sanfter Reload.** `systemctl restart` beendet den Prozess und bricht jedes Gespräch ab. Für Konfigurationsänderungen möchten Sie das fast nie — verwenden Sie stattdessen das Asterisk CLI: `asterisk -rx 'core reload'` (oder einen modulspezifischen Reload wie `pjsip reload`). Reservieren Sie `systemctl restart` für Upgrades oder einen blockierten Prozess.
- **An den laufenden Daemon anhängen.** Wenn Asterisk als Dienst läuft, öffnen Sie dessen Konsole mit `asterisk -r` (oder `asterisk -rvvv` für ausführliche Ausgaben). Dies verbindet sich über den Kontroll-Socket mit dem bereits laufenden Daemon; es startet keine zweite Instanz.

### `Restart=` ersetzt safe_asterisk

Historisch gesehen wurde Asterisk über den **safe_asterisk** Wrapper gestartet, ein Shell-Skript, das Asterisk bei einem Absturz neu startete. Unter systemd gehört diese Aufgabe zur `Restart=` Direktive der Unit — systemd bemerkt das Beenden des Prozesses und startet ihn neu, wobei das Back-off durch `RestartSec=` und der Schutz vor Absturzschleifen durch `StartLimitIntervalSec=`/`StartLimitBurst=` gesteuert wird. Auf einem systemd-Host ist **safe_asterisk daher überflüssig** und im Allgemeinen unnötig. Falls Ihre mitgelieferte Unit dies noch nicht konfiguriert hat, ist ein Drop-in-Override der saubere Weg, um einen Neustart bei Fehlern hinzuzufügen, ohne die paketierte Datei zu bearbeiten:

```
# /etc/systemd/system/asterisk.service.d/override.conf
[Service]
Restart=always
RestartSec=2
```

Wenden Sie dies mit `systemctl daemon-reload && systemctl restart asterisk` an. Die Verwendung eines Drop-ins (anstatt die installierte Unit zu bearbeiten) stellt sicher, dass ein zukünftiges `make config` Ihre Änderungen nicht überschreibt.

### Ausführen als Nicht-Root-Benutzer

Asterisk sollte in der Produktion nicht als root ausgeführt werden — ein Fehler mit Remote-Code-Ausführung in einem Prozess, der als root läuft, bedeutet eine vollständige Kompromittierung des Hosts, während derselbe Fehler in einem unprivilegierten Prozess eingedämmt bleibt. Es gibt zwei komplementäre Stellen, an denen dies erzwungen wird:

- **Die Unit / asterisk.conf.** Die paketierte Unit führt Asterisk normalerweise als `asterisk` Benutzer und Gruppe aus. Sie können auch (oder stattdessen) `runuser` und `rungroup` im `[options]` Abschnitt von `asterisk.conf` setzen, was der Daemon berücksichtigt, wenn er nach dem Binden der Ports die Privilegien abgibt:

  ```
  [options]
  runuser = asterisk
  rungroup = asterisk
  ```

- **Dateiberechtigungen.** Die Laufzeitverzeichnisse müssen für diesen Benutzer beschreibbar sein. Stellen Sie nach dem Erstellen des Kontos die Eigentümerschaft sicher:

  ```
  chown -R asterisk:asterisk /var/lib/asterisk /var/log/asterisk \
        /var/spool/asterisk /var/run/asterisk /etc/asterisk
  ```

Da SIP (5060) und RTP (10000+) allesamt hohe Ports sind, benötigt Asterisk **keine** root-Rechte, um diese zu binden — nur privilegierte Ports im Stil von Port 25 wären nötig, welche Asterisk nicht verwendet. Der unprivilegierte Betrieb ist daher kostenlos. (Das Sicherheitskapitel erläutert, warum dies wichtig ist; siehe *Asterisk Security*.)

## Containerizing Asterisk

Ein Container verpackt Asterisk und seine exakten Abhängigkeiten in ein unveränderliches Image, sodass das, was Sie testen, Byte für Byte dem entspricht, was Sie ausliefern. Der Kompromiss betrifft Echtzeitmedien: Ein SIP-Server reagiert empfindlich auf Latenz und benötigt einen breiten, vorhersagbaren Bereich von UDP-Ports, die von außen erreichbar sind, was durch Container-Netzwerke erschwert werden kann. Der Rest dieses Abschnitts führt durch das eigene Labor des Buches — `lab/Dockerfile` und `lab/docker-compose.yml` — als konkretes, funktionierendes Beispiel und erklärt dann die eine Falle, in die jeder tappt: RTP und Bridged Networking.

### Das Image: Asterisk aus dem Quellcode bauen

Das `Dockerfile` des Labors baut Asterisk 22 aus dem Quellcode auf Debian 12. Die Struktur ist es wert, gelesen zu werden, selbst wenn Sie selbst nie eines schreiben:

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

Drei Dinge sind hervorzuheben:

- **Die Version ist fixiert** (`ARG ASTERISK_VERSION=22.10.0`). Reproduzierbarkeit ist der ganze Sinn des Containerisierens — ändern Sie sie bewusst, bauen Sie neu, testen Sie neu.
- **`--with-pjproject-bundled` und `--with-jansson-bundled`** bauen den SIP-Stack versionsgenau zu Asterisk, sodass Sie von weniger apt-Paketen abhängen und niemals gegen ein PJSIP der Distribution kämpfen müssen, das nicht kompatibel ist.
- **`CMD ["asterisk", "-f", "-vvv"]`** führt Asterisk im *Vordergrund* aus (`-f`, "do not fork"). Dies ist der entscheidende Unterschied zu einem systemd-Host: Der Hauptprozess eines Containers darf sich nicht daemonisieren, da der Container sonst sofort beendet würde. In einem Container verwenden Sie also **nicht** die systemd-Unit — die Container-Runtime (Docker, plus `restart:` Policy) wird zum Supervisor, der bei einer VM durch das `Restart=` der Unit ersetzt wurde.

### Bind-Mounting von `/etc/asterisk`

Das Image enthält absichtlich **keine** Konfiguration. Stattdessen bindet `docker-compose.yml` das Konfigurationsverzeichnis des Hosts ein:

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

`./asterisk/etc:/etc/asterisk:ro` bildet das versionskontrollierte `lab/asterisk/etc` Verzeichnis auf das `/etc/asterisk` des Containers ab, schreibgeschützt (`:ro`). Der Gewinn ist groß: Das Image bleibt unveränderlich und wiederverwendbar, während die Konfiguration auf dem Host verbleibt, wo sie bearbeitet und, was entscheidend ist, in git gespeichert werden kann (nächster Abschnitt). Um eine Konfigurationsänderung anzuwenden, bearbeiten Sie die Datei und laden sie neu — `docker compose exec asterisk asterisk -rx 'core reload'` — ohne einen neuen Build. `restart: unless-stopped` ist das Äquivalent auf Compose-Ebene zu systemd's `Restart=`: Docker startet den Container neu, wenn Asterisk beendet wird, aber nicht, wenn Sie ihn absichtlich gestoppt haben.

### Host- vs. Bridged-Networking — das RTP-Problem

Dies ist der häufigste Fehler bei containerisiertem Asterisk, daher lohnt es sich, ihn genau zu verstehen. Standardmäßig platziert Docker einen Container in einem **bridged** Netzwerk und Sie veröffentlichen einzelne Ports mit `ports:`. Die Signalisierung funktioniert einwandfrei — 5060 ist ein einzelner Port. Das Problem sind die Medien: RTP verwendet einen *Bereich* von UDP-Ports (das `rtp.conf` des Labors setzt `rtpstart=10000` / `rtpend=10100`), und **jeder** Port, der Audio übertragen könnte, muss veröffentlicht werden.

Das Labor tut genau das:

```yaml
    ports:
      - "5060:5060/udp"
      - "10000-10100:10000-10100/udp"
```

Beachten Sie, dass der RTP-Veröffentlichungsbereich (`10000-10100`) exakt mit `rtp.conf` übereinstimmt. Wenn Sie dies falsch machen — zu wenige Ports veröffentlichen oder einen anderen Bereich als `rtp.conf` verwenden — werden Anrufe zwar verbunden, haben aber **einseitiges oder gar kein Audio**, da die RTP-Pakete auf einem Port landen, den Docker nicht weiterleitet. Zwei weitere Warnungen zum Bridged-Modus:

- **Das Veröffentlichen von tausenden Ports ist langsam und ressourcenintensiv.** Ein produktiver RTP-Bereich liegt typischerweise bei 10000–20000. Dass Docker ca. 10000 Userland-Proxy-Weiterleitungen erstellt, ist beim Start teuer und fügt einen zusätzlichen Hop im Medienpfad hinzu. Das Labor verwendet absichtlich einen kleinen Bereich von 100 Ports, da es immer nur ein oder zwei Testanrufe ausführt.
- **NAT im SDP.** Hinter der Bridge sieht Asterisk seine private Container-IP und bewirbt diese möglicherweise im SDP. Auf einem öffentlichen Host müssen Sie PJSIP seine externe Adresse mit `external_media_address` / `external_signaling_address` am Transport mitteilen (und `local_net` setzen), genau wie Sie es hinter jedem NAT tun würden — siehe *Cloud-Hosting* unten.

Die Alternative ist **Host-Networking** (`network_mode: host`), das die Bridge vollständig entfernt: Der Container teilt sich den Netzwerk-Stack des Hosts, sodass 5060 und der gesamte RTP-Bereich ohne Port-Veröffentlichung und ohne zusätzlichen Medien-Hop erreichbar sind. Dies ist der empfohlene Modus für einen echten Asterisk-Container — er umgeht das RTP-Bereichs-Problem vollständig. Der Preis dafür ist die Isolation: Der Container kann jeden Host-Port binden und Sie verlieren das pro-Service-Netzwerk von Compose. (Host-Networking ist ein Linux-Feature; auf Docker Desktop für macOS/Windows verhält es sich anders, was teilweise der Grund dafür ist, dass dieses Lehr-Labor explizit veröffentlichte Ports verwendet.)

### Persistente Volumes für Spool und Voicemail

Die beschreibbare Ebene eines Containers ist **flüchtig** — zerstören Sie den Container und alles, was er geschrieben hat, ist weg. Für Asterisk bedeutet das, dass Voicemail, Aufzeichnungen, der ausgehende Call-Spool und die lokale Datenbank bei jedem `docker compose up --build` verschwinden würden. Die Konfiguration überlebt, weil sie vom Host bind-gemountet wird; der *Zustand* benötigt die gleiche Behandlung. Innerhalb des Containers sind die relevanten Verzeichnisbäume:

```
/var/spool/asterisk        # voicemail, monitor recordings, outgoing/, etc.
/var/lib/asterisk          # astdb.sqlite3 (the internal database)
/var/log/asterisk          # full, messages, security, cdr-csv/, cel-custom/
```

(Der laufende Container des Labors zeigt genau diese — `/var/spool/asterisk` enthält `voicemail`, `monitor`, `outgoing`, `recording`; `/var/lib/asterisk` enthält `astdb.sqlite3`.) Um diese zu bewahren, mounten Sie benannte Volumes für die Verzeichnisse, die den Zustand enthalten, der Ihnen wichtig ist:

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

Das Lehr-Labor lässt diese absichtlich weg — es ist zustandslos und von Design her reproduzierbar, sodass jedes `up` ein sauberer Neuanfang ist — aber ein Produktions-Container **muss** sie haben, sonst verlieren Sie Voicemails beim ersten Redeploy.

## Konfigurationsmanagement und Backups

Der obige Bind-Mount deutet auf das richtige Modell hin: Behandeln Sie `/etc/asterisk` als **Code** und den Rest als **Daten**.

### Halten Sie `/etc/asterisk` in der Versionskontrolle

Das Konfigurationsverzeichnis ist eine flache Sammlung von Textdateien ohne Geheimnisse, die nicht als Vorlage dienen könnten — es ist ideal für git. Initialisieren Sie ein Repository in `/etc/asterisk` (oder halten Sie die Konfiguration, wie im Labor, zusammen mit dem Projekt und binden Sie es per Bind-Mount ein). Vorteile:

- Jede Änderung ist überprüfbar und rückgängig machbar (`git diff`, `git revert`).
- Sie haben einen Audit-Trail darüber, wer was wann geändert hat.
- In Kombination mit einem Container-Image beschreiben ein bekannter, guter Konfigurations-Commit sowie ein fixierter Image-Tag eine Bereitstellung vollständig.

Ein paar Vorsichtsmaßnahmen speziell für die Asterisk-Konfiguration:

- **Geheimnisse.** `pjsip.conf` (und `manager.conf`, `ari.conf`) enthalten Passwörter. Committen Sie keine echten Geheimnisse im Klartext in ein geteiltes Repository — verwenden Sie Vorlagen (eine Datei pro Umgebung oder einen Secrets-Manager / Umgebungsvariablen-Substitution zum Zeitpunkt der Bereitstellung) und behalten Sie nur Platzhalter in git. Die trivialen `Lab-6001-secret`-Passwörter des Labors sind *nur* deshalb in Ordnung, weil sie sich in einem privaten Docker-Subnetz befinden.
- **Umgebungsspezifische Vorlagen.** Die realtime-Werte, die sich zwischen Entwicklung, Staging und Produktion unterscheiden (Bind-Adressen, externe IPs, trunk-Zugangsdaten, Datenbank-URLs), sind genau die Zeilen, die Sie als Vorlage definieren, während der Großteil der Konfiguration über alle Umgebungen hinweg identisch bleibt.

### Was gesichert werden muss

Die Konfiguration in git deckt den dialplan und die endpoints ab, aber eine aktive PBX sammelt *Zustände*, die sich in keiner Konfigurationsdatei befinden. Ein vollständiges Backup umfasst:

| Was | Wo | Warum |
|------|-------|-----|
| Konfiguration | `/etc/asterisk/` | dialplan, endpoints (auch in git) |
| voicemail & Aufzeichnungen | `/var/spool/asterisk/` | Benutzerdaten — unersetzlich |
| Interne Datenbank | `/var/lib/asterisk/astdb.sqlite3` | `DB()` keys, Gerätestatus |
| CDR / CEL | `/var/log/asterisk/cdr-csv/` oder SQL-Speicher | Abrechnung & Historie |
| Externe Datenbanken | Ihre MySQL/PostgreSQL | realtime, CDR, voicemail |

Die **astdb** verdient eine Anmerkung: Es ist der kleine, in Asterisk integrierte Key/Value-Speicher (eine SQLite-Datei unter `/var/lib/asterisk/astdb.sqlite3`), der von `DB()` dialplan-Funktionen, Gerätestatus, Follow-Me-Einstellungen und Ähnlichem verwendet wird. Sie können sie zur Überprüfung oder für Backups über die CLI exportieren:

```
asterisk -rx 'database show'
```

Wenn Ihre CDR/CEL-, voicemail- oder PJSIP-Konfiguration in einer externen Datenbank liegt (siehe *Asterisk Real-Time* und *Asterisk Call Detail Records*), ist diese Datenbank nun die Quelle der Wahrheit für diese Daten und muss in Ihren normalen Datenbank-Backup-Zyklus aufgenommen werden — das Sichern von `/etc/asterisk` allein reicht nicht aus.

## Monitoring und Observability

Sie können nicht betreiben, was Sie nicht sehen können. Asterisk legt seinen Status auf vier Ebenen offen, von einem schnellen menschlichen Blick bis hin zu einer Metrik-Pipeline: das **CLI**, die **CDR/CEL**-Datensätze, **AMI/ARI**-Ereignisse und **Metrik-Exporter**.

### CLI-Gesundheitsprüfungen

Die schnellste Prüfung auf „Ist es gesund?“ ist das CLI. Die unten stehenden Befehle werden live im Labor ausgeführt. Zuerst die Channels:

```
*CLI> core show channels
Channel              Location             State   Application(Data)
0 active channels
0 active calls
0 calls processed
```

`0 active calls` auf einem ruhigen System ist normal; auf einem ausgelasteten System ist dies Ihre Echtzeit-Auslastung. `core show uptime` bestätigt, dass der Prozess nicht unter Ihnen neu gestartet wurde:

```
*CLI> core show uptime
System uptime: 1 hour, 40 minutes, 19 seconds
Last reload: 12 minutes, 32 seconds
```

Für den SIP-Status zeigt `pjsip show endpoints` jeden endpoint und ob seine registrierten Kontakte erreichbar sind. Aus dem Labor:

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

`Unavailable` bedeutet hier einfach, dass derzeit kein Telefon an diesen endpoints registriert ist (das Labor hat keine Live-Clients) — sobald sich ein softphone registriert und `qualify` dies bestätigt, zeigt der Status den Kontakt als erreichbar an. Begleitende Befehle: `pjsip show contacts` (aktuelle Registrierungen und Round-Trip-Zeit), `pjsip show transports` und `pjsip show aor <name>` für einen AOR. Dies sind die täglichen Werkzeuge für die Frage: „Warum ist extension X nicht erreichbar?“

### CDR und CEL

Jeder Anruf hinterlässt einen **Call Detail Record** (CDR); **Channel Event Logging** (CEL) fügt detailliertere Ereignisse pro Channel hinzu. Bestätigen Sie, dass CDR aktiv ist und welches Backend es speichert:

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

Das Labor zeigt `(none)` unter den registrierten Backends, da die minimale Laborkonfiguration kein CDR-Speichermodul lädt — Datensätze werden also berechnet, aber nirgendwo geschrieben. In der Produktion laden Sie ein Backend (CSV oder `cdr_odbc`/`cdr_adaptive_odbc` in MySQL/PostgreSQL), das dann zu Ihrer Abrechnungs- und Historienquelle wird. CEL ist **standardmäßig deaktiviert** (`cel show status` zeigt ` reports `CEL Logging: Disabled` in the lab) and you enable it in `cel.conf` nur, wenn Sie Details auf Ereignisebene benötigen. Beide werden ausführlich in *Asterisk Call Detail Records* behandelt; für das Monitoring ist wichtig, dass CDR/CEL Ihre *historische* Aufzeichnung sind, während das CLI Ihre *Live*-Ansicht darstellt.

### AMI- und ARI-Ereignisse

Für programmgesteuertes Echtzeit-Monitoring möchten Sie einen Push-Feed von Ereignissen, anstatt das CLI abzufragen:

- **AMI (Asterisk Manager Interface)** ist das langjährig bewährte TCP-Ereignis-/Befehlsprotokoll (`manager.conf`). Abonnieren Sie es und Sie erhalten `Newchannel`, `Hangup`, `DialBegin`, `BridgeEnter`, `PeerStatus` und ähnliche Ereignisse, während Anrufe stattfinden — das Rückgrat von Wallboards und Anruf-Abrechnungstools. Im Labor ist AMI standardmäßig deaktiviert (`manager show settings` meldet `Manager (AMI): No`); Sie aktivieren und sichern es in `manager.conf`.
- **ARI (Asterisk REST Interface)** ist die moderne HTTP + WebSocket-Schnittstelle (`ari.conf`, bereitgestellt durch den integrierten HTTP-Server). Sie bietet einen JSON-Ereignisstrom und eine fein abgestimmte Anrufsteuerung — die richtige Wahl für neue Integrationen.

Beide werden in *Extending Asterisk with AMI and AGI* und *The Asterisk REST Interface (ARI)* detailliert beschrieben. Die für den Einsatz relevante Warnung: **AMI und ARI sind mächtig und dürfen niemals dem Internet ausgesetzt werden.** Binden Sie den HTTP-Server an localhost oder ein Management-Netzwerk, verwenden Sie starke, eindeutige Geheimnisse und sichern Sie die Ports per Firewall — siehe *Asterisk Security*.

### Metriken: Prometheus und Grafana

Für Dashboards und Alarmierung liefert Asterisk 22 einen Prometheus-Exporter, **`res_prometheus.so`** (ein Modul mit *extended* Support-Level), das Metriken auf einem HTTP-endpoint bereitstellt, die von einem Prometheus-Server abgefragt werden. Neben grundlegenden Prozessmetriken liefert es erweiterbare Provider für Channels, Anrufe, endpoints, Bridges und PJSIP-ausgehende Registrierungen:

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

Sie können bestätigen, dass das Modul im Labor-Build vorhanden ist:

```
*CLI> module show like prometheus
Module                         Description                     Use Count  Status      Support Level
res_prometheus.so              Asterisk Prometheus Module      0          Not Running  extended
```

Es zeigt `Not Running`, da das Labor es nicht konfiguriert oder lädt; die Aktivierung (`prometheus.conf` plus der HTTP-Server) macht Asterisk zu einem Prometheus-Ziel. Richten Sie Prometheus auf den Scrape-endpoint und Grafana auf Prometheus aus, und Sie erhalten Zeitreihen-Dashboards (gleichzeitige Anrufe, Registrierungen, ASR/ACD-Trends) und Alarmierung (z. B. „aktive Anrufe auf null gefallen“ oder „Spitzen bei Registrierungsfehlern“). Für Teams, die bereits Prometheus/Grafana betreiben, ist dies der natürliche Weg, Asterisk in die bestehende Observability zu integrieren, anstatt CLI-Ausgaben zu parsen.

### SIP-Antwortcodes, die man beobachten sollte

Unabhängig von der Pipeline signalisieren einige SIP-Ergebnisse Probleme und sind es wert, alarmiert zu werden: Anhaltende `401`/`407` Challenge-Fehler oder `403 Forbidden` deuten auf einen Brute-Force-Angriff oder eine Welle falsch konfigurierter Anmeldedaten hin (vergleichen Sie dazu Fail2Ban in *Asterisk Security*); `503 Service Unavailable` deutet auf einen überlasteten Server oder trunk hin; und ein Anstieg bei `408 Request Timeout`/`480 Temporarily Unavailable` bedeutet normalerweise, dass endpoints nicht mehr erreichbar sind (NAT-Timeout, Qualify-Fehler).

## Hochverfügbarkeit und Skalierung

Ein einzelner Asterisk-Server stellt einen Single Point of Failure dar und hat eine begrenzte Kapazität für Anrufe. Die beiden Probleme – *Betriebsbereitschaft* und *Skalierbarkeit* – erfordern unterschiedliche Lösungsansätze.

### Aktiv/Standby mit einer Floating IP

Das klassische, bewährte HA-Muster für Asterisk ist **Aktiv/Standby** (nicht Aktiv/Aktiv – der Anrufstatus in Asterisk lässt sich nur schwer live synchronisieren). Zwei identische Server, einer aktiv und einer im Standby, teilen sich eine **Floating (virtuelle) IP**, die von einem Cluster-Manager wie **keepalived** (VRRP) oder **Pacemaker/Corosync** verwaltet wird. Telefone und trunks registrieren sich an der Floating IP, nicht an einem der physischen Hosts. Wenn der aktive Knoten seine Integritätsprüfung nicht besteht, wandert die Floating IP zum Standby-Knoten, der daraufhin die Aufgaben übernimmt.

Der ehrliche Vorbehalt: Ein IP-Failover **bricht laufende Anrufe ab** – Asterisk repliziert den Live-Kanalstatus nicht zwischen den Knoten, daher muss jeder, der sich mitten in einem Gespräch befindet, erneut wählen. Registrierungen werden innerhalb eines qualify/registration-Zyklus wiederhergestellt. Was man durch das Failover gewinnt, ist, dass der *Dienst* innerhalb von Sekunden ohne manuelles Eingreifen wiederhergestellt wird, was für die meisten PBXs genau das Ziel ist. Damit der Standby-Knoten die Aufgaben tatsächlich übernehmen kann, benötigen beide Knoten die gleiche Konfiguration (Ihre per git verwaltete `/etc/asterisk`, identisch bereitgestellt) und den gleichen *Status* – was der nächste Punkt ist.

### Status externalisieren mit PJSIP Realtime

Aktiv/Standby funktioniert nur, wenn der Standby-Knoten die gleichen endpoints und Registrierungen kennt wie der aktive Knoten. Der Weg, dies zu erreichen, besteht darin, **den Status nicht mehr in flachen Dateien auf einer Box zu speichern**, sondern ihn in eine gemeinsam genutzte Datenbank zu verschieben, die beide Knoten lesen. **PJSIP Realtime** (Sorcery, unterstützt durch eine Datenbank) tut genau dies: endpoints, AORs, auths – und, was wichtig ist, **Registrierungen** (die Tabelle `ps_contacts`) – liegen in MySQL/PostgreSQL anstatt in `pjsip.conf` und dem lokalen Arbeitsspeicher. Beide Asterisk-Knoten greifen auf dieselbe Datenbank zu, sodass ein Telefon, das über einen Knoten registriert wurde, für den anderen sichtbar ist. Dies wird in *Asterisk Real-Time* (dem Abschnitt zu PJSIP Realtime / Sorcery) behandelt; hier ist der entscheidende Punkt für die Bereitstellung, dass **die Externalisierung des Status die Voraussetzung für HA sowie für horizontale Skalierung ist** – ohne sie ist jeder Knoten eine isolierte Insel.

Wenden Sie dieselbe Logik auf den Rest Ihres Status an: CDR/CEL in einen gemeinsamen SQL-Speicher, voicemail auf gemeinsam genutztem/repliziertem Speicher (oder `ODBC_STORAGE`) und die astdb-Schlüssel, von denen Sie abhängen, in eine Datenbank. Sobald der Status externalisiert ist, werden die Asterisk-Knoten eher zu austauschbaren Front-Ends.

### SIP-Proxys davor (OpenSIPS)

Um *über* die Kapazität eines einzelnen Servers hinaus zu skalieren, setzen Sie einen **SIP-Proxy/Load Balancer** vor einen Pool von Asterisk-Medienservern. **OpenSIPS** ist ein zweckgebundener SIP-Proxy mit sehr hohem Durchsatz (er verarbeitet Hunderttausende von Registrierungen und leitet Signalisierung weiter, ohne die Medien zu berühren). Der Proxy präsentiert der Außenwelt eine einzige SIP-Adresse, verwaltet den Registrierungs-/Standortdienst und verteilt Anrufe auf die Asterisk-Back-Ends. Diese Trennung – eine leichtgewichtige Proxy-Ebene für Registrierung und Routing, eine horizontal skalierbare Asterisk-Ebene für die eigentliche Anrufverarbeitung (IVR, Warteschlangen, Konferenzen, Transcoding) – ist die Art und Weise, wie große Installationen über eine einzelne Box hinauswachsen. (Die SipPulse-Plattform selbst verwendet aus genau diesem Grund OpenSIPS vor ihren Medien-/Anwendungsservern.)

### Medienskalierung

Der Proxy verteilt *Signalisierung* kostengünstig; **Medien sind die teure Ressource**. RTP-Relaying und insbesondere das Transcoding zwischen codecs (z. B. Opus ↔ G.711) oder das Durchführen großer Konferenzen sind CPU-intensiv und begrenzen die Kapazität eines Servers. Strategien:

- **Vermeiden Sie Transcoding**, wo immer möglich – verhandeln Sie einen gemeinsamen codec von Ende zu Ende, damit Asterisk nativ brückt (pass-through), anstatt zu transcodieren. Dies ist der größte Gewinn für die Medienkapazität.
- **Skalieren Sie Medien horizontal**, indem Sie Asterisk-Knoten hinter dem Proxy hinzufügen; jeder trägt einen Teil der gleichzeitigen Anrufe.
- **Lagern Sie Browser-Medien aus** an ein dediziertes WebRTC-Gateway (z. B. Janus), damit die PBX nicht auch noch den DTLS-SRTP-Stream jedes Browsers terminieren und weiterleiten muss – siehe *WebRTC with Asterisk*, wo genau diese Aufteilung zwischen Asterisk und Gateway diskutiert wird.

Bemessen Sie die Kapazität nach **gleichzeitigen Anrufen und Transcoding-Last**, nicht nach registrierten Benutzern – 10.000 registrierte Telefone, die größtenteils im Leerlauf sind, sind weitaus kostengünstiger als 200 gleichzeitige transcodierte Konferenzen.

## Cloud-Hosting

Das Betreiben von Asterisk auf einer Cloud-VM (AWS, GCP, Azure, einem VPS) ist üblich und funktioniert gut, aber das Cloud-Netzwerk ist **standardmäßig hinter NAT und Firewalls**, was zu Problemen mit SIP führt. Im Folgenden werden die einsatzspezifischen Bedenken erläutert.

### NAT und das SDP

Eine Cloud-VM hat fast immer eine **private** IP auf ihrer NIC und eine separate **öffentliche** IP, die der Anbieter per NAT darauf abbildet. Wenn Asterisk die private IP im SDP ankündigt, senden entfernte Telefone RTP in ein schwarzes Loch — das klassische Symptom für einseitige Kommunikation oder fehlendes Audio. Teilen Sie PJSIP seine öffentliche Identität auf dem Transport mit:

```
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060
external_media_address=203.0.113.10      ; the VM's PUBLIC IP
external_signaling_address=203.0.113.10
local_net=10.0.0.0/8                     ; your private/VPC range(s)
```

`external_*` veranlasst Asterisk dazu, die Adresse, die es öffentlichen Peers ankündigt, umzuschreiben, während `local_net` angibt, welche Peers lokal sind (und *nicht* umgeschrieben werden sollten). Dies ist dieselbe NAT-Handhabung, die oben für gebridgte Docker-Netzwerke besprochen wurde — eine Cloud-VM befindet sich faktisch hinter NAT.

### Firewall und der RTP-Bereich

Auf einer Cloud-VM kommen normalerweise zwei Firewalls zum Einsatz: die Sicherheitsgruppe / Network ACL des **Anbieters** und die iptables des **Hosts**. Beide müssen dieselben Ports öffnen, und die Richtlinie entspricht der aus dem Sicherheitskapitel. Das übernommene Regelsatz-Beispiel der 1. Auflage (`docs/legacy-labs/configs/Lab7/rules.v4`) erfasst die Struktur — akzeptiere SIP und den RTP-Bereich, akzeptiere etablierte/zugehörige Verbindungen, verwerfe den Rest:

```
-A INPUT -p udp -m udp --dport 5060 -j ACCEPT
-A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -j DROP
```

Zwei Korrekturen aus dem Sicherheitskapitel sind hier von Bedeutung: Öffnen Sie **5061 auf TCP** (nicht UDP), wenn Sie SIP/TLS betreiben, und denken Sie daran, dass der RTP-UDP-Bereich in Ihrer Firewall exakt mit `rtpstart`/`rtpend` in `rtp.conf` übereinstimmen muss — derselbe Bereich, den Sie auf einem Container veröffentlichen. Duplizieren Sie hier nicht den iptables/Fail2Ban-Aufbau; **folgen Sie den Abschnitten zu Firewall, Fail2Ban und TLS/SRTP in *Asterisk Security*** (Fail2Ban überwacht den `security` Logger-Kanal, den das Labor bereits in `logger.conf` aktiviert) und wenden Sie diese Richtlinie sowohl in der Host-Firewall als auch in der Cloud-Sicherheitsgruppe an.

### Latenz, Region und der SBC

- **Wählen Sie eine Region in der Nähe Ihrer Benutzer.** Sprache ist latenzempfindlich — eine Latenz von Mund zu Ohr von über ~150 ms ist spürbar. Hosten Sie die VM in der Region, die dem Großteil Ihrer Telefone und trunks am nächsten liegt; Medienübertragungen über Kontinente hinweg sind hörbar schlechter.
- **Platzieren Sie bei jedem internetseitigen Einsatz einen SBC davor.** Ein **Session Border Controller** terminiert SIP/RTP am Rand, verbirgt Ihre Topologie, normalisiert NAT und absorbiert DoS- und Scan-Datenverkehr, bevor dieser Asterisk erreicht. Die Kernempfehlung des Sicherheitskapitels — *setzen Sie Asterisk nicht ungeschützt dem Internet aus* — gilt doppelt in der Cloud, wo die öffentliche IP Ihrer VM innerhalb von Minuten nach dem Start gescannt wird. Ein SBC (oder zumindest ein gehärteter SIP-Proxy wie OpenSIPS plus Fail2Ban) ist der Standard am Netzwerkrand.

## Zusammenfassung

Deployment ist der Prozess, bei dem aus einem funktionierenden dialplan ein zuverlässiger Dienst wird. Lassen Sie Asterisk auf einer VM unter **systemd** als **non-root** Benutzer laufen und nutzen Sie die `Restart=` der Unit, um den Dienst am Laufen zu halten (safe_asterisk ist überholt). Verwenden Sie für Konfigurationsänderungen `core reload` anstelle von `systemctl restart`. Das **Containerizing** mit Docker – wie im Labor dieses Buches praktiziert – liefert Ihnen ein unveränderliches, fixiertes Image, bei dem die Konfiguration über ein git-verwaltetes `/etc/asterisk` **bind-mounted** wird. Der Haken dabei ist die Medienübertragung: Nutzen Sie daher entweder **host networking** oder veröffentlichen Sie einen RTP-Portbereich, der **exakt `rtp.conf` entspricht**, und binden Sie **persistent volumes** für spool/voicemail/astdb ein, damit der Status bei einer erneuten Bereitstellung erhalten bleibt. Behandeln Sie Konfiguration wie Code und **sichern Sie den Status**, den die Konfiguration nicht erfasst: voicemail, Aufzeichnungen, `astdb.sqlite3` sowie CDR/CEL. **Überwachen** Sie das System auf vier Ebenen – das CLI (`core show channels`, `pjsip show endpoints`) für die Live-Ansicht, **CDR/CEL** für die Historie, **AMI/ARI** für programmatische Ereignisse und den **`res_prometheus`** Exporter für Grafana zur Erstellung von Dashboards und Alarmen – während Sie AMI/ARI vom öffentlichen Internet fernhalten. Um **verfügbar zu bleiben**, betreiben Sie ein Aktiv/Standby-Setup mit einer **floating IP** (wobei in Kauf genommen wird, dass bei einem Failover aktive Anrufe getrennt werden). Um zu **skalieren**, lagern Sie den Status mit **PJSIP Realtime** aus, schalten Sie einen Pool von Medienservern mit **OpenSIPS** vor und minimieren Sie Transcoding, da **Medien – nicht Registrierungen – die Kapazitätsgrenze eines Servers bestimmen**. Behandeln Sie die VM in der **cloud** schließlich so, als befände sie sich hinter NAT (`external_media_address`, `local_net`), öffnen Sie die Firewall gemäß dem Sicherheitskapitel sowohl auf dem Host als auch in der Sicherheitsgruppe des Anbieters, wählen Sie eine Region mit geringer Latenz und setzen Sie niemals ein ungeschütztes Asterisk direkt ein – platzieren Sie ein **SBC** am Netzwerkrand.

## Quiz

1. Was ersetzt auf einem systemd-Host die Aufgabe des alten `safe_asterisk`-Wrappers, ein abgestürztes Asterisk neu zu starten?
   - A. Ein cron-Job
   - B. Die `Restart=`-Direktive der Unit-Datei
   - C. `systemctl enable`
   - D. Die astdb
2. Um eine Konfigurationsänderung auf ein laufendes Asterisk anzuwenden, **ohne Anrufe zu unterbrechen**, sollten Sie:
   - A. `systemctl restart asterisk`
   - B. Den Server neu starten
   - C. `asterisk -rx 'core reload'`
   - D. Das Container-Image neu erstellen
3. Ein containerisiertes (bridged-network) Asterisk verbindet Anrufe, hat aber **kein Audio**. Die wahrscheinlichste Ursache ist:
   - A. Der dialplan ist fehlerhaft
   - B. Der veröffentlichte RTP UDP-Portbereich stimmt nicht mit `rtpstart`/`rtpend` in `rtp.conf` überein
   - C. CDR ist deaktiviert
   - D. Das CLI ist nicht erreichbar
4. Welche Verzeichnisse müssen als **persistente Volumes** eingebunden werden, damit bei einer erneuten Bereitstellung des Containers kein Status verloren geht? (alle zutreffenden auswählen)
   - A. `/var/spool/asterisk` (voicemail, Aufzeichnungen)
   - B. `/var/lib/asterisk` (astdb)
   - C. `/etc/asterisk` (bereits vom Host aus eingebunden)
   - D. `/usr/sbin`
5. Welcher CLI-Befehl liefert die aktuelle Anzahl der aktiven Anrufe?
   - A. `cdr show status`
   - B. `core show channels`
   - C. `pjsip show transports`
   - D. `module show like prometheus`
6. Was ist in Asterisk 22 der unterstützte Weg, um Anruf-/Kanal-Metriken für einen Prometheus/Grafana-Stack bereitzustellen?
   - A. Parsen der `full`-Logdatei
   - B. Das `res_prometheus.so`-Modul
   - C. AGI-Skripte
   - D. Es gibt keinen
7. Was ist die Voraussetzung sowohl für HA-Failover als auch für horizontale Skalierung über mehrere Asterisk-Knoten hinweg?
   - A. Ausführung als root
   - B. Externalisierung des Status (z. B. PJSIP Realtime-Registrierungen in einer gemeinsam genutzten Datenbank)
   - C. Deaktivierung von CDR
   - D. Verwendung von bridged networking
8. Welche Ressource begrenzt am direktesten, wie viele gleichzeitige Anrufe ein Asterisk-Server verarbeiten kann?
   - A. Die Anzahl der registrierten Benutzer
   - B. Medienverarbeitung, insbesondere Transcoding
   - C. Die Größe von `/etc/asterisk`
   - D. Das CDR-Backend
9. Welche `pjsip.conf`-Transporteinstellungen sorgen auf einer Cloud-VM dafür, dass Asterisk seine öffentliche Adresse bekannt gibt, damit Remote-Audio funktioniert? (alle zutreffenden auswählen)
   - A. `external_media_address`
   - B. `external_signaling_address`
   - C. `local_net`
   - D. `qualify_frequency`
10. Für eine internetseitige Cloud-Bereitstellung lautet die Grundregel des Sicherheitskapitels:
    - A. Betreiben Sie immer zwei Netzwerkkarten
    - B. Setzen Sie Asterisk niemals direkt dem Internet aus; platzieren Sie einen SBC (oder einen gehärteten Proxy + Fail2Ban) am Rand
    - C. Verwenden Sie nur UDP
    - D. Deaktivieren Sie TLS

**Antworten:** 1 — B · 2 — C · 3 — B · 4 — A, B · 5 — B · 6 — B · 7 — B · 8 — B · 9 — A, B, C · 10 — B
