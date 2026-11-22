# Eigenen Server betreiben

Diese Anleitung beschreibt, wie du die **Laufzeitumgebung** für einen eigenen HEiDi-Backend-Server einrichtest: Java, Apache als Reverse Proxy mit HTTPS, eine Firewall und die MariaDB-Datenbank. Anschließend tragen deine Nutzerinnen und Nutzer die Adresse deines Servers in der App unter **Anderer Server** ein.

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
- Das **HEiDi-Backend** lauscht nur lokal auf Port **8080** und ist von außen nicht direkt erreichbar.
- **MariaDB** speichert Accounts, Pakete, Handbücher und Einsatzdaten.
- Von außen offen sind nur **22** (SSH), **80** (HTTP, für das Zertifikat und die Weiterleitung) und **443** (HTTPS).

## Voraussetzungen

- Ein Server mit **Ubuntu oder Debian** (die Befehle unten sind dafür geschrieben)
- Eine **Domain**, die auf den Server zeigt, z. B. `heidi.example.org`
- **Apache 2.4.47 oder neuer** (wegen der WebSocket-Weiterleitung, siehe unten) – prüfen mit `apache2 -v`
- **MariaDB**
- **Java** – siehe Schritt 1
- Das **HEiDi-Backend** selbst: [Installation des Backends – wird ergänzt]

In dieser Anleitung steht `heidi.example.org` für deine Domain. Ersetze sie überall durch deine eigene Adresse.

## 1. Java installieren

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

In der Ausgabe von `ss -ltnp` sollten das Backend (`8080`) und MariaDB (`3306`) **nur auf `127.0.0.1`** lauschen, nicht auf `0.0.0.0` oder `*`.

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
- oder in `/etc/mysql/my.cnf` – Hauptsache im Abschnitt `[mysqld]`

`1G` ist der Höchstwert, den MariaDB erlaubt. Ein kleinerer Wert spart Arbeitsspeicher, muss aber für die größte Datei reichen, die hochgeladen wird.

MariaDB neu starten und prüfen:

```bash
sudo systemctl restart mariadb
sudo mariadb -e "SHOW VARIABLES LIKE 'max_allowed_packet';"
```

Der Wert wird in Byte angezeigt; `1073741824` entspricht 1 GB.

## 7. Server in der App verwenden

Wenn alles läuft, melden sich deine Nutzerinnen und Nutzer so an:

1. In der App auf **Registrieren** bzw. **Anmelden** tippen.
2. **Anderer Server** wählen.
3. Bei **Server-URL** die Adresse eintragen, z. B. `https://heidi.example.org`.

Zur Kontrolle: Unter <span class="klickweg">Einstellungen › Startprotokoll</span> zeigt die App, ob Anmeldung, Paketlisten und Rechtstexte vom Server geladen werden konnten.

## Noch zu ergänzen

- [ ] Installation und Aktualisierung des HEiDi-Backends (Bezugsquelle, Start als Dienst, benötigte Java-Mindestversion)
- [ ] Datenbank und Datenbank-Benutzer für HEiDi anlegen
- [ ] Konfiguration des Backends (Datenbankzugang, Mailversand, Domain)
- [ ] Rechtstexte hinterlegen (Datenschutz, AGB, Impressum) – die App lädt sie vom Server
- [ ] CORS-Freigabe, damit die Web-Version auf den Server zugreifen darf
- [ ] Backups von Datenbank und hochgeladenen Dateien
- [ ] Updates und Überwachung
