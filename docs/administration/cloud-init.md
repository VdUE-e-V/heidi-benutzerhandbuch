# Server mit cloud-init einrichten

Statt alle Schritte aus [Eigenen Server betreiben](eigener-server.md) von Hand auszuführen, kannst du einen neuen Cloud-Server mit einer **cloud-init-Konfiguration** automatisch einrichten lassen. Das funktioniert bei vielen Anbietern, zum Beispiel bei Hetzner Cloud. Nach rund zehn Minuten läuft das HEiDi-Backend – mit HTTPS, Firewall und abgesichertem SSH-Zugang.

**[:material-download: heidi-cloud-config.yaml herunterladen](heidi-cloud-config.yaml)**

## Was die Konfiguration einrichtet

| Bereich | Was passiert |
|---|---|
| **System** | Updates, Zeitzone Europe/Berlin |
| **SSH** | eigener Admin-Benutzer mit Schlüssel, kein Root-Login, keine Passwörter, **Port 2222**, fail2ban |
| **Firewall** | ufw: offen sind nur 2222 (SSH), 80 und 443 |
| **Software** | Java, Apache, Certbot, MariaDB |
| **Datenbank** | `heidi_db` und `heidi_user`, `max_allowed_packet` für große Dateien |
| **Backend** | Dienst-Benutzer `heidi`, Download von `ROOT.jar`, `environment.sh`, Dienst `heidi.service` – nur lokal auf `127.0.0.1:8080` |
| **Apache** | Reverse Proxy mit HTTPS-Zertifikat von Let’s Encrypt |
| **Zugangsdaten** | Passwörter für Datenbank und HEiDi-Administrator werden **auf dem Server zufällig erzeugt** |

## 1. Konfiguration anpassen

Öffne die Datei und ersetze alle Stellen in spitzen Klammern:

| Platzhalter | Beispiel | Hinweis |
|---|---|---|
| `<ADMIN_BENUTZER>` | `holu` | kommt **zweimal** vor: bei `users` und bei `AllowUsers` |
| `<PUBLIC_SSH_KEY>` | `ssh-ed25519 AAAA… du@laptop` | Inhalt deiner Datei `~/.ssh/id_ed25519.pub` |
| `<DOMAIN>` | `heidi.example.org` | ohne `https://` |
| `<LETSENCRYPT_EMAIL>` | `admin@example.org` | für Hinweise zum Zertifikat |

!!! warning "Domain vorher einrichten"
    Das HTTPS-Zertifikat kann nur ausgestellt werden, wenn die Domain beim Einrichten **schon auf die IP-Adresse des Servers zeigt**. Lege den DNS-Eintrag (A-Record) deshalb möglichst vor dem Erstellen an – bei Hetzner kannst du dafür vorab eine Primary IP reservieren. Klappt es nicht, lässt sich das Zertifikat später mit einem Befehl nachholen (siehe unten).

!!! info "Keine Passwörter in die Konfiguration"
    Die Konfiguration wird beim Anbieter gespeichert und ist vom Server aus abrufbar. Trag deshalb **keine Passwörter** ein. Die Passwörter für Datenbank und HEiDi-Administrator erzeugt der Server selbst. Die E-Mail-Einstellungen trägst du nach der Einrichtung von Hand nach.

## 2. Server erstellen

Am Beispiel von **Hetzner Cloud**:

1. In der Hetzner Console **Server hinzufügen** wählen.
2. Als Image **Ubuntu 24.04** wählen.
3. Einen Servertyp mit mindestens **4 GB Arbeitsspeicher** wählen – Java und MariaDB brauchen etwas Platz.
4. Unter **Cloud config** den Inhalt deiner angepassten `heidi-cloud-config.yaml` einfügen.
5. Server erstellen.

Die Einrichtung läuft im Hintergrund. Zum Schluss startet der Server einmal neu.

## 3. Verbinden und prüfen

Melde dich über Port **2222** mit deinem Admin-Benutzer an:

```bash
ssh -p 2222 holu@heidi.example.org
```

Prüfe, ob die Einrichtung durchgelaufen ist:

```bash
cloud-init status                  # sollte "status: done" melden
sudo cat /var/log/heidi-setup.log  # Ausgabe des Einrichtungsskripts
sudo systemctl status heidi        # sollte "active (running)" zeigen
sudo ss -ltnp | grep 8080          # Backend lauscht nur auf 127.0.0.1:8080
```

Bei Problemen hilft `sudo less /var/log/cloud-init-output.log`.

## 4. Zugangsdaten sichern

Die erzeugten Passwörter stehen in einer Datei, die nur root lesen kann:

```bash
sudo cat /root/heidi-zugangsdaten.txt
```

Übertrage sie in euren Passwort-Manager und **lösche die Datei danach**:

```bash
sudo rm /root/heidi-zugangsdaten.txt
```

Die Passwörter stehen weiterhin in `/etc/HEiDi/environment.sh`, die der Dienst zum Starten braucht.

## 5. E-Mail-Versand einrichten

Damit der Server E-Mails verschicken kann, z. B. zur Bestätigung neuer Accounts, trägst du die Zugangsdaten deines Postfachs nach. Öffne die Konfiguration und fülle die Zeilen `MAIL_…` aus – welche Werte typisch sind, steht in [Schritt 9 der Anleitung](eigener-server.md#9-backend-konfigurieren):

```bash
sudo nano /etc/HEiDi/environment.sh
sudo systemctl restart heidi
```

## Zertifikat nachholen

Hat die Domain beim Einrichten noch nicht auf den Server gezeigt, steht im Log `/var/log/heidi-setup.log` eine Warnung. Sobald der DNS-Eintrag stimmt, holst du das Zertifikat nach:

```bash
sudo certbot --apache -d heidi.example.org --redirect
```

## Unterschiede zur Anleitung von Hand

- **SSH auf Port 2222** statt 22, Root-Login abgeschaltet – wie im [Hetzner-Tutorial](https://community.hetzner.com/tutorials/basic-cloud-config/de/).
- `default-jre-headless` statt `default-jre`: dieselbe Java-Version, aber ohne Grafikbibliotheken, die ein Server nicht braucht.
- Die Apache-Konfiguration liegt in einer eigenen Datei `/etc/apache2/sites-available/heidi.conf`; Certbot erzeugt daraus `heidi-le-ssl.conf` für HTTPS.
- Der Dienst startet erst nach MariaDB (`After=… mariadb.service`).
- `SERVER_ADDRESS=127.0.0.1` ist schon gesetzt.

Wie du Einstellungen änderst, das Backend aktualisierst oder Logs ansiehst, steht unter [Im laufenden Betrieb](eigener-server.md#im-laufenden-betrieb).
