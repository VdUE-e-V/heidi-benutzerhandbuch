# Am Benutzerhandbuch mitarbeiten

Danke, dass du das HEiDi-Benutzerhandbuch verbessern möchtest! Jede Korrektur hilft – vom Tippfehler bis zum neuen Kapitel.

## So schlägst du eine Änderung vor

**Kleine Korrekturen direkt im Browser**

1. Öffne die Seite im veröffentlichten Handbuch und klicke oben rechts auf das Stift-Symbol („Diese Seite bearbeiten“).
2. Ändere den Text auf GitHub und beschreibe kurz, was du geändert hast.
3. GitHub legt automatisch einen Pull Request an. Das HEiDi-Team prüft ihn und übernimmt die Änderung.

**Größere Änderungen am eigenen Rechner**

```bash
git clone https://github.com/VdUE-e-V/heidi-benutzerhandbuch.git
cd heidi-benutzerhandbuch
pip install -r requirements.txt
mkdocs serve          # Vorschau unter http://127.0.0.1:8000
```

Lege für deine Änderung einen eigenen Branch an und öffne einen Pull Request gegen `main`.
Vor dem Zusammenführen prüft **Nico** jeden Pull Request. Die automatische Prüfung (`mkdocs build --strict`) muss grün sein: Sie meldet kaputte Links und fehlende Bilder.

Du hast einen Fehler in der **App** gefunden, nicht im Handbuch? Dann bitte nicht hier, sondern im Repository [heidi-issues](https://github.com/VdUE-e-V/heidi-issues) melden.

## Schreibregeln

### Ansprache und Ton

- Wir **duzen** – so wie die App selbst („Deine Hilfe-App für Einsatzdienste“).
- Kurze Sätze, aktive Formulierungen: „Tippe auf …“ statt „Es muss auf … getippt werden“.
- Eine Seite beantwortet eine Frage. Der erste Absatz sagt, worum es geht.
- Wir schreiben für Einsatzkräfte, nicht für Programmierer: keine Fachbegriffe aus der Softwareentwicklung.

### Bedienelemente

- Namen von Buttons, Reitern und Menüpunkten schreiben wir **fett und genau so, wie sie in der App heißen**, z. B. **neuen Einsatz anlegen** oder **Paket herunterladen**.
- Klickwege mit „›“: **Einstellungen › Pakete › Alle Pakete**.
- „Tippe“ für Smartphone und Tablet. Wo es um die Web-Version geht: „klicke“.

### Begriffe

| Begriff | Bedeutung | Nicht verwenden |
|---|---|---|
| **Benutzerhandbuch** | dieses Nachschlagewerk | „Handbuch“ allein, wenn dieses gemeint ist |
| **Handbuch** | Inhalte in der App (Artikel, PDFs, Algorithmen) | „Benutzerhandbuch“ |
| **Paket** | bringt die Funktionen der App mit: Einsatzformular, Stichwörter, Checklisten, Material, Kontakte | „Modul“, „Profil“ |
| **aktives Paket** | das eine Paket, mit dem du gerade arbeitest | |
| **Einsatzstichwort** | steuert, welche Inhalte im Einsatz angezeigt werden | „Tag“, „Kategorie“ |
| **HEiDi-Editor** | das Verwaltungsprogramm im Browser, mit dem Pakete und Handbücher erstellt werden | „Backend“, „Admin“ |
| **Server** | wo dein Account und die Pakete liegen, z. B. „HEiDi Standardserver“ | |

Neue Begriffe kommen ins [Glossar](docs/hilfe/glossar.md).

### Hinweisboxen

```markdown
!!! tip "Tipp"
    Ein hilfreicher Kniff.

!!! warning "Achtung"
    Etwas, das schiefgehen kann.

!!! info "Gut zu wissen"
    Hintergrundwissen.
```

### Screenshots

- Aufgenommen in **Smartphone-Größe (375 × 812 Pixel)**, z. B. mit den Entwicklertools des Browsers in der Web-Version.
- **Nur Testdaten** – keine echten Namen, Adressen oder Einsätze, keine echten Benutzernamen außer Test-Accounts.
- Ablage in `docs/assets/screenshots/`, Dateiname in Kleinbuchstaben mit Bindestrichen, z. B. `einsatz-anlegen.jpg`.
- Einbinden mit Alternativtext und der Klasse `screenshot`:

```markdown
![Formular zum Anlegen eines Einsatzes](../assets/screenshots/einsatz-anlegen.jpg){ .screenshot }
```

- Wenn sich die App ändert, den Screenshot unter **demselben Dateinamen** ersetzen. Dann stimmen alle Seiten, die ihn verwenden.

## Lizenz

Mit deinem Beitrag erklärst du dich einverstanden, dass er unter [CC BY-SA 4.0](LICENSE.md) veröffentlicht wird.
