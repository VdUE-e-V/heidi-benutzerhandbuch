# Eigenen Server betreiben

Diese Anleitung beschreibt, wie du einen eigenen HEiDi-Backend-Server einrichtest: Zeitzone und Java, Apache als Reverse Proxy mit HTTPS, eine Firewall, die MariaDB-Datenbank und das Backend selbst als Dienst. Anschließend tragen deine Nutzerinnen und Nutzer die Adresse deines Servers in der App unter **Anderer Server** ein.

!!! warning "Für erfahrene Administratoren"
    Du brauchst Root-Zugang zu einem Linux-Server und Grundkenntnisse in Apache, Firewall und Datenbanken. Plane auch den laufenden Betrieb ein: Updates, Backups und Überwachung liegen bei dir.

## So ist der Server aufgebaut

```
App / Web-Version
        │  HTTPS, Port 443
        ▼
Apache (Reverse Proxy)
        │  HTTP, nur lokal
        ▼
HEiDi-Backend   127.0.0.1:8080
        │
        ▼
MariaDB         127.0.0.1:3306
```

- **Apache** nimmt alle Anfragen von außen über HTTPS an und leitet sie intern an das Backend weiter.
- Das **HEiDi-Backend** lauscht auf Port **8080** – nur lokal, wenn du es wie in Schritt 9 beschrieben einstellst. Von außen ist es nicht direkt erreichbar.
- **MariaDB** speichert Accounts, Pakete, Handbücher und Einsatzdaten.
- Von außen offen sind nur **22** (SSH), **80** (HTTP, für das Zertifikat und die Weiterleitung) und **443** (HTTPS).

## Voraussetzungen

- Ein Server mit **Ubuntu oder Debian** (die Befehle unten sind dafür geschrieben)
- Eine **Domain**, die auf den Server zeigt, z. B. `heidi.example.org`
- **Apache 2.4.47 oder neuer** (wegen der WebSocket-Weiterleitung, siehe unten) – prüfen mit `apache2 -v`
- **MariaDB**
- **Java** und die richtige **Zeitzone** – siehe Schritt 1
- Die Backend-Datei [**`ROOT.jar`**](https://cloud.hilfeapp.org/s/Heidibackend) und das Setup-Skript [`setup-env.sh`](setup-env.sh)

In dieser Anleitung steht `heidi.example.org` für deine Domain. Ersetze sie überall durch deine eigene Adresse.

## 1. Grundeinrichtung: Zeitzone und Java

### Zeitzone einstellen

Stelle die Zeitzone des Servers auf deutsche Zeit. Sonst stehen in Protokollen und Zeitstempeln Uhrzeiten in UTC, also eine bzw. zwei Stunden versetzt:

```bash
sudo timedatectl set-timezone "Europe/Berlin"
timedatectl
```

Bei `Time zone` sollte jetzt `Europe/Berlin` stehen, und `System clock synchronized` sollte `yes` anzeigen.

### Java installieren

Das HEiDi-Backend ist eine Java-Anwendung. Installiere die Java-Laufzeitumgebung aus den Paketquellen deiner Distribution:

```bash
sudo apt update
sudo apt install default-jre
```

`default-jre` installiert die Java-Version, die deine Ubuntu- bzw. Debian-Version als Standard vorsieht. Prüfen kannst du die Installation mit:

```bash
java -version
```

## 2. Apache-Module aktivieren

```bash
sudo a2enmod proxy proxy_http headers ssl
```

| Modul | Wofür |
|---|---|
| `proxy`, `proxy_http` | Anfragen an das Backend weiterleiten |
| `headers` | Kopfzeilen der Anfragen setzen und entfernen |
| `ssl` | HTTPS |

## 3. HTTPS-Zertifikat einrichten

Für HTTPS brauchst du ein Zertifikat. Kostenlos geht das mit **Let’s Encrypt** und Certbot:

```bash
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d heidi.example.org
```

Certbot legt dabei die Datei `/etc/apache2/sites-available/000-default-le-ssl.conf` an, richtet auf Wunsch die Weiterleitung von HTTP auf HTTPS ein und erneuert das Zertifikat automatisch.

## 4. Apache als Reverse Proxy konfigurieren

Ergänze im `<VirtualHost *:443>`-Block der HTTPS-Konfiguration, z. B. in `000-default-le-ssl.conf`:

```apache
ServerName heidi.example.org

ProxyRequests Off
ProxyPreserveHost On
ProxyAddHeaders On

# Von außen mitgeschickte Weiterleitungs-Header verwerfen ...
RequestHeader unset Forwarded
RequestHeader unset X-Forwarded-For
RequestHeader unset X-Forwarded-Host
RequestHeader unset X-Forwarded-Server
RequestHeader unset X-Forwarded-Proto
RequestHeader unset X-Forwarded-Port
# ... und durch eigene, vertrauenswürdige Werte ersetzen
RequestHeader set X-Forwarded-Proto "https"
RequestHeader set X-Forwarded-Port "443"

ProxyPass        / http://127.0.0.1:8080/ upgrade=websocket
ProxyPassReverse / http://127.0.0.1:8080/
```

Was die Einstellungen bewirken:

`ProxyRequests Off`
:   Apache arbeitet nur als Reverse Proxy für deinen Server – nicht als offener Proxy für beliebige Adressen im Internet. **Unbedingt so lassen.**

`ProxyPreserveHost On`
:   Das Backend sieht die echte Domain (`heidi.example.org`) statt `127.0.0.1`.

`ProxyAddHeaders On` und `RequestHeader …`
:   Apache teilt dem Backend mit, dass die ursprüngliche Anfrage per HTTPS kam und von welcher IP-Adresse. Weil vorher alle von außen mitgeschickten `Forwarded`- und `X-Forwarded-*`-Header entfernt werden, kann niemand dem Backend eine falsche Herkunft vorgaukeln.

`ProxyPass … upgrade=websocket`
:   Leitet alle Anfragen an das Backend weiter, auch WebSocket-Verbindungen. Die Option `upgrade=websocket` gibt es erst ab **Apache 2.4.47**.

Konfiguration testen und Apache neu laden:

```bash
sudo apache2ctl configtest      # muss "Syntax OK" melden
sudo systemctl reload apache2
```

!!! tip "Große Uploads"
    Wenn Pakete oder Handbücher mit großen PDF-Dateien hochgeladen werden, achte auch auf die Limits in Apache: `LimitRequestBody` (ab Apache 2.4.53 standardmäßig 1 GB) und bei langsamen Verbindungen `ProxyTimeout`.

## 5. Firewall einrichten

Prüfe zuerst den aktuellen Stand und welche Dienste auf welchen Ports lauschen:

```bash
sudo ufw status verbose
sudo ufw show added
sudo ss -ltnp
```

In der Ausgabe von `ss -ltnp` sollte MariaDB (`3306`) **nur auf `127.0.0.1`** lauschen, nicht auf `0.0.0.0` oder `*`. Für das Backend (`8080`) stellst du das in [Schritt 9](#backend-nur-lokal-erreichbar-machen) ein.

Firewall-Regeln festlegen:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp     # SSH
sudo ufw allow 80/tcp     # HTTP (Zertifikat, Weiterleitung auf HTTPS)
sudo ufw allow 443/tcp    # HTTPS
```

!!! danger "Erst SSH freigeben, dann einschalten"
    Schalte die Firewall erst ein, **nachdem** Port 22 freigegeben ist. Sonst sperrst du dich aus, wenn du per SSH verbunden bist.

```bash
sudo ufw enable
sudo ufw status numbered
```

!!! warning "Docker umgeht ufw"
    Läuft das Backend in einem Docker-Container, veröffentliche den Port nur lokal, z. B. `-p 127.0.0.1:8080:8080`. Ein einfaches `-p 8080:8080` macht den Port im Internet erreichbar – **auch wenn ufw ihn blockiert**, weil Docker eigene Firewall-Regeln setzt.

!!! tip "SSH zusätzlich schützen"
    `sudo ufw limit 22/tcp` statt `allow` bremst wiederholte Anmeldeversuche. Noch sicherer: Anmeldung nur per SSH-Schlüssel und Passwort-Login abschalten.

## 6. MariaDB für große Dateien konfigurieren

Damit auch große Dateien (z. B. PDFs in Handbüchern) gespeichert werden können, muss MariaDB größere Datenpakete annehmen. Trage im Abschnitt `[mariadbd]` ein:

```ini
[mariadbd]
max_allowed_packet = 1G
```

Wo die Einstellung hingehört:

- auf Ubuntu und Debian am besten in `/etc/mysql/mariadb.conf.d/50-server.cnf`
- oder in `/etc/mysql/my.cnf` – Hauptsache im Abschnitt `[mysqld]` oder `[mariadbd]`

`1G` ist der Höchstwert, den MariaDB erlaubt. Ein kleinerer Wert spart Arbeitsspeicher, muss aber für die größte Datei reichen, die hochgeladen wird.

MariaDB neu starten und prüfen:

```bash
sudo systemctl restart mariadb
sudo mariadb -e "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

Der Wert wird in Byte angezeigt; `1073741824` entspricht 1 GB.

## 7. Dienst-Benutzer und Verzeichnisse anlegen

Das Backend läuft unter einem eigenen Systembenutzer `heidi` ohne Login und ohne Home-Verzeichnis. So hat es nur die Rechte, die es wirklich braucht.

Prüfe zuerst, ob es Benutzer oder Gruppe schon gibt:

```bash
getent passwd heidi
getent group heidi
```

Liefern **beide** Befehle keine Ausgabe, lege den Benutzer an:

```bash
sudo useradd --system --user-group --no-create-home \
  --home-dir /nonexistent --shell /usr/sbin/nologin heidi
```

Ergebnis prüfen:

```bash
id heidi
getent passwd heidi
```

Lege dann die beiden Verzeichnisse an – `/var/HEiDi` für das Backend und `/etc/HEiDi` für die Konfiguration:

```bash
sudo install -d -o root -g heidi -m 750 /var/HEiDi /etc/HEiDi
```

Beide gehören `root`; die Gruppe `heidi` darf lesen, aber nichts verändern.

## 8. Datenbank anlegen

Öffne die Datenbank-Konsole:

```bash
sudo mariadb
```

Lege Datenbank und Benutzer an und vergib die Rechte. Ersetze `PASSWORT` durch ein **langes, zufälliges Passwort**, das du sonst nirgends verwendest:

```sql
CREATE DATABASE heidi_db CHARACTER SET utf8mb4;

CREATE USER 'heidi_user'@'localhost' IDENTIFIED BY 'PASSWORT';
GRANT ALL PRIVILEGES ON heidi_db.* TO 'heidi_user'@'localhost';

SHOW GRANTS FOR 'heidi_user'@'localhost';
```

Mit `exit` verlässt du die Konsole.

Prüfe danach, ob sich der neue Benutzer so anmelden kann, wie es später das Backend tut – über TCP auf Port 3306:

```bash
mariadb --protocol=TCP --host=localhost --port=3306 --user=heidi_user --password heidi_db
```

Nach der Passworteingabe sollte die Konsole von `heidi_db` erscheinen. Zur Kontrolle:

```sql
SELECT CURRENT_USER();
```

Erwartet wird `heidi_user@localhost`.

## 9. Backend konfigurieren

Die Einstellungen des Backends – Port, Datenbankzugang, Administrator, E-Mail – liegen als Umgebungsvariablen in `/etc/HEiDi/environment.sh`. Diese Datei erzeugt das Setup-Skript **[`setup-env.sh`](setup-env.sh)**.

Lade das Skript auf den Server, zum Beispiel direkt aus diesem Benutzerhandbuch:

```bash
curl -O https://vdue-e-v.github.io/heidi-benutzerhandbuch/administration/setup-env.sh
```

Führe es **als root** aus und gib als Ziel die Konfigurationsdatei an:

```bash
sudo bash setup-env.sh /etc/HEiDi/environment.sh
```

Das Skript fragt die Einstellungen nacheinander ab. In eckigen Klammern steht jeweils der Vorschlag – mit ++enter++ übernimmst du ihn. Passwörter werden unsichtbar eingegeben und müssen zur Bestätigung wiederholt werden.

!!! warning "Datenbankname und -benutzer anpassen"
    Das Skript schlägt `heidi` als Datenbankname und Datenbank-Benutzer vor. In [Schritt 8](#8-datenbank-anlegen) hast du aber `heidi_db` und `heidi_user` angelegt. Tippe bei diesen beiden Fragen also **`heidi_db`** bzw. **`heidi_user`** ein, statt den Vorschlag zu übernehmen.

### Die Einstellungen im Einzelnen

**Server und Uploads**

| Frage | Vorschlag | Bedeutung |
|---|---|---|
| Server port | `8080` | Port des Backends. Muss zur Apache-Konfiguration (`ProxyPass … 127.0.0.1:8080`) passen. |
| Tomcat connection timeout | `300` | Wartezeit für Verbindungen |
| Tomcat keep-alive timeout | `300` | wie lange eine Verbindung offen gehalten wird |
| Compression enabled | `false` | Komprimierung der Antworten |
| Maximum file size | `100MB` | größte Datei, die hochgeladen werden kann, z. B. ein PDF im Handbuch |
| Maximum request size | `100MB` | größte Anfrage insgesamt |

**Datenbank**

| Frage | Vorschlag | Bedeutung |
|---|---|---|
| Database host | `localhost` | |
| Database port | `3306` | |
| Database name | `heidi` | **`heidi_db`** eintragen (siehe oben) |
| Database username | `heidi` | **`heidi_user`** eintragen (siehe oben) |
| Database password | – | das Passwort aus Schritt 8 |
| Hibernate schema management | `update` | Das Backend legt die Tabellen beim ersten Start an und passt sie bei Updates an. So lassen. |

**Logging**

Die vier Log-Level (`warn`, `ERROR`, `error`, `ERROR`) kannst du übernehmen. Bei der Fehlersuche lassen sie sich später erhöhen.

**Administrator und Speicher**

| Frage | Vorschlag | Bedeutung |
|---|---|---|
| Initial administrator username | `admin` | Benutzername des ersten Administrators |
| Initial administrator password | – | Passwort des ersten Administrators |
| Deprecated storage path | leer | veraltet – leer lassen |

!!! danger "Keine leeren Passwörter"
    Das Skript erlaubt leere Passwörter. Vergib für den **Administrator** und die **Datenbank** unbedingt lange, zufällige Passwörter – ein leeres Administrator-Passwort würde jedem Zugang zu deinem Server geben.

**E-Mail**

Zugangsdaten des Postfachs, über das der Server E-Mails verschickt, zum Beispiel für die Bestätigung neuer Accounts. Typische Werte für einen Mailserver mit STARTTLS:

| Frage | Beispiel |
|---|---|
| Email username | `heidi@example.org` |
| Email password | Passwort des Postfachs |
| Email server | `smtp.example.org` |
| Email transport protocol | `smtp` |
| SMTP port | `587` |
| SMTP authentication | `true` |
| SMTP STARTTLS enabled | `true` |
| SMTP STARTTLS required | `true` |

Die richtigen Werte bekommst du von deinem E-Mail-Anbieter.

### Datei schützen

Das Skript legt die Datei so an, dass nur `root` sie lesen kann. Damit der Dienst-Benutzer `heidi` sie lesen darf, änderst du Besitzer und Rechte:

```bash
sudo chown root:heidi /etc/HEiDi/environment.sh
sudo chmod 640 /etc/HEiDi/environment.sh
```

Jetzt kann nur `root` die Datei ändern, und nur `root` und `heidi` können sie lesen. Das ist wichtig, denn sie enthält alle Passwörter im Klartext.

### Backend nur lokal erreichbar machen

Das Backend nimmt standardmäßig Verbindungen auf **allen** Netzwerkschnittstellen an. Die Firewall aus [Schritt 5](#5-firewall-einrichten) blockiert Port 8080 zwar von außen. Sicherer ist es aber, wenn das Backend gar nicht erst nach außen lauscht. Ergänze dafür am Ende von `environment.sh`:

```bash
export SERVER_ADDRESS=127.0.0.1
```

Nach dem Start des Dienstes prüfst du mit `sudo ss -ltnp | grep 8080`, ob das Backend nur noch auf `127.0.0.1:8080` lauscht.

### Einstellungen später ändern

Das Skript überschreibt keine vorhandene Datei. Um Einstellungen zu ändern, bearbeite `/etc/HEiDi/environment.sh` direkt, zum Beispiel mit `sudo nano /etc/HEiDi/environment.sh`, und starte den Dienst danach neu:

```bash
sudo systemctl restart heidi
```

## 10. Backend installieren und als Dienst starten

Die aktuelle Version des Backends stellt der VdUE als Datei `ROOT.jar` in der [HEiDi-Cloud](https://cloud.hilfeapp.org/s/Heidibackend) bereit. Lade sie direkt auf den Server:

```bash
curl -L -o ROOT.jar https://cloud.hilfeapp.org/s/Heidibackend/download
ls -lh ROOT.jar        # rund 115 MB
```

Lege sie dann mit den richtigen Rechten ab:

```bash
sudo install -o root -g heidi -m 640 ROOT.jar /var/HEiDi/ROOT.jar
```

Lege die Dienst-Datei `/etc/systemd/system/heidi.service` an:

```ini
[Unit]
Description=HEiDi
After=network.target

[Service]
User=heidi
WorkingDirectory=/var/HEiDi
ExecStart=/bin/bash -c 'source /etc/HEiDi/environment.sh && exec /usr/bin/java -jar /var/HEiDi/ROOT.jar'
SuccessExitStatus=143
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Was die Einstellungen bewirken:

`User=heidi`
:   Das Backend läuft als Dienst-Benutzer, nicht als `root`.

`ExecStart=…`
:   Lädt zuerst die Umgebungsvariablen aus `environment.sh` und startet dann das Backend mit Java.

`SuccessExitStatus=143`
:   Java beendet sich beim normalen Stoppen mit dem Code 143. So wertet systemd das nicht als Fehler.

`Restart=on-failure`, `RestartSec=5`
:   Stürzt das Backend ab, startet systemd es nach 5 Sekunden neu.

Dienst aktivieren und starten:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now heidi
```

Dienst prüfen:

```bash
sudo systemctl status heidi       # sollte "active (running)" zeigen
sudo journalctl -u heidi -f       # laufende Log-Ausgabe, beenden mit Strg+C
sudo ss -ltnp | grep 8080         # Backend sollte auf 127.0.0.1:8080 lauschen
```

!!! tip "Start nach der Datenbank"
    Damit das Backend nach einem Neustart des Servers erst startet, wenn MariaDB bereit ist, kannst du im Abschnitt `[Unit]` ergänzen:

    ```ini
    After=network.target mariadb.service
    Wants=mariadb.service
    ```

### Backend aktualisieren

Eine neue Version installierst du, indem du die aktuelle Datei herunterlädst, sie ersetzt und den Dienst neu startest:

```bash
curl -L -o ROOT.jar https://cloud.hilfeapp.org/s/Heidibackend/download
sudo install -o root -g heidi -m 640 ROOT.jar /var/HEiDi/ROOT.jar
sudo systemctl restart heidi
sudo systemctl status heidi
```

Mach vorher ein Backup der Datenbank.

## 11. Server in der App verwenden

Wenn alles läuft, melden sich deine Nutzerinnen und Nutzer so an:

1. In der App auf **Registrieren** bzw. **Anmelden** tippen.
2. **Anderer Server** wählen.
3. Bei **Server-URL** die Adresse eintragen, z. B. `https://heidi.example.org`.

Zur Kontrolle: Unter <span class="klickweg">Einstellungen › Startprotokoll</span> zeigt die App, ob Anmeldung, Paketlisten und Rechtstexte vom Server geladen werden konnten.

## Noch zu ergänzen

- [ ] Benötigte Java-Mindestversion
- [ ] Versionsnummer und Prüfsumme für `ROOT.jar`, damit man erkennt, welche Version installiert ist
- [ ] Rechtstexte hinterlegen (Datenschutz, AGB, Impressum) – die App lädt sie vom Server
- [ ] CORS-Freigabe, damit die Web-Version auf den Server zugreifen darf
- [ ] Backups von Datenbank und hochgeladenen Dateien
- [ ] Updates und Überwachung
