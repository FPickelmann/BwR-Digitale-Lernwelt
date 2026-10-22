# BwR Digitale Lernwelt

## Halloween Erweiterung

Bei einer bereits eingerichteten Lernwelt ausschließlich `database/04_halloween_update.sql` vollständig ausführen. Die ursprünglichen Einrichtungsskripte und Accountdateien nicht erneut ausführen. Das Update erhält Accounts, Passwörter, Freigaben und vorhandene Lernstände. Es enthält Transaktionstests mit temporären Testaccounts; deren Änderungen werden vor dem Commit verworfen. Als Ergebnis müssen 72 Prüfgruppen angezeigt werden.

Danach im Lehrerbereich „Anwendungen ansehen und testen“ öffnen. „Halloween-Waffelstand“ kann ohne Speicherung getestet und der Klasse zugeordnet werden. Die Zuordnung allein schaltet keine Schüleraccounts frei. Freigaben anschließend klassenweise oder individuell einstellen.

Jede Prüfgruppe zählt bei einer unrichtigen, vollständig ausgefüllten Eingabe einen Fehlversuch. Richtig ausgefüllte Felder werden einzeln markiert. Nach drei Fehlversuchen der Gruppe im aktuellen Durchlauf ist die Musterlösung serverseitig abrufbar. Ihre Nutzung wird je Aufgabe und Durchlauf einmal gezählt. Erneutes Öffnen im selben Durchlauf zählt nicht mehrfach. Eine Musterlösung schließt keine Aufgabe ab; erst die richtige eigene Eingabe zählt. Leere Felder zählen nicht als Fehlversuch. Bei Wiederholung werden aktuelle Fehlerzähler und Lösungsfreigaben zurückgesetzt, Gesamtfehler und historische Lösungsnutzung bleiben erhalten.

Die Anwendung umfasst 72 Prüfgruppen: Beträge und Buchungen zu vier Geschäftsfällen sowie Eintragungen und Schritte a–g zu acht Konten. Die fachlichen Daten entstehen aus `scripts/halloween_data.py`; `scripts/build_halloween_migration.py` baut das Update. `python -m unittest discover -s tests -p 'test_*.py'` prüft die Zahlen und Kontenabschlüsse. Die Oberfläche wurde separat mit einem simulierten Speicherdienst geprüft; dieser Test prüft keine echten Datenbankrechte.

Eigenständige Lernplattform mit Schüleraccounts, Lehrerbereich und später ergänzbaren Anwendungen. Statische Oberfläche auf GitHub Pages; Datenbank und Serverfunktionen im eigenen Supabase-Projekt.

## Einrichtung

1. Im Supabase-Projekt den SQL Editor öffnen, eine neue Abfrage anlegen und `database/01_schema.sql` ausführen. Das Skript ist für die erstmalige Einrichtung gedacht und bricht bei bereits vorhandenen Tabellen ab, ohne Teiländerungen zu übernehmen.
2. Die separat bereitgestellte vertrauliche Datei `02_accounts.sql` ausschließlich im Supabase SQL Editor ausführen. Sie enthält die 30 vereinbarten Schülerzugänge und den initialen Lehrerzugang. Diese Datei niemals in GitHub hochladen.
3. In GitHub unter Settings → Pages als Source **Deploy from a branch**, Branch **main**, Ordner **/(root)** auswählen und speichern.
4. Nach der Bereitstellung die Website aufrufen, zunächst als Lehrkraft anmelden und die Klasse 8b2026 öffnen.

Die Supabase-Verbindung ist in `config.js` bereits mit ausschließlich öffentlichen Verbindungsdaten eingetragen. Ein Secret Key oder service_role-Schlüssel wird im Browser nicht benötigt.

## Konten und Rechte

Schülerpasswörter haben vier Zeichen und unterscheiden keine Groß-/Kleinschreibung. Lehrerpasswörter sind länger und unterscheiden Groß-/Kleinschreibung.
Nach fünf Anmeldeversuchen pro Account innerhalb von 15 Minuten werden weitere Versuche bis zum Ende des Zeitfensters blockiert. Ein erfolgreicher Login setzt den Zähler zurück. Eine globale Begrenzung am Gateway ist bei größerem Betrieb zusätzlich sinnvoll.
Sitzungen gelten acht Stunden, werden serverseitig geprüft und nur im aktuellen Browser-Tab gehalten. Auf gemeinsam genutzten Geräten abmelden.

Die Daten liegen in einem nicht über die Data API freigegebenen privaten Schema mit aktiviertem RLS. Öffentlich aufrufbar ist ausschließlich die authentifizierende RPC-Funktion `bwr_api`. Anonyme direkte Tabellenrechte sind entzogen. Keine pauschalen Freigabepolicies hinzufügen.
Passwörter werden für die Anmeldung mit bcrypt gehasht. Da eine Passwortanzeige ausdrücklich gewünscht ist, wird zusätzlich eine verschlüsselte Kopie gespeichert; der Schlüssel bleibt in einer privaten Datenbanktabelle. Datenbankadministratoren können darauf zugreifen. Nicht für andere Dienste wiederverwenden.

## Freigaben und Statistiken

Zwei Zustände: freigeschaltet oder nicht sichtbar. Klassenfreigaben setzen den Zustand aller Schüleraccounts; danach sind individuelle Abweichungen möglich.
Neue Accounts übernehmen je Anwendung die strikte Mehrheit vorhandener Accounts. Bei Gleichstand oder leerer Klasse bleibt die Anwendung unsichtbar. Gelöschte Accountkürzel werden nicht erneut vergeben.
Eine entfernte Anwendungszuordnung blendet die Anwendung aus, erhält aber Lernstände. Der eigene Fortschritt zeigt nur freigeschaltete Anwendungen.
Der Lehrer kann alle Lernstände eines Accounts, eine Anwendung eines Accounts oder eine Anwendung der Klasse nach Bestätigung zurücksetzen. Dabei bleiben Passwörter und Freigaben erhalten. Accountlöschung entfernt auch Sitzungen und Statistiken.

Die Klassenübersicht berücksichtigt alle zugeordneten Schüleraccounts. Statusgruppen sind gegenseitig ausschließend: Ein Account mit mindestens einem abgeschlossenen Durchlauf gilt als vollständig bearbeitet, auch während einer Wiederholung. Wiederholungen zählen erst bei erneutem vollständigem Abschluss.

## Grenzen und Inbetriebnahme

Die Grundplattform enthält noch keine Lernanwendung. Erste Klasse: 8b2026. Weitere Klassen und Schüleraccounts lassen sich im Lehrerbereich anlegen. Der bestehende Lehrerzugang verwaltet diese Klassen ebenfalls.
Die Schülercodes sind Pseudonyme; das allein begründet keine Datenschutzkonformität. Schule und Datenschutzbeauftragte müssen den Einsatz, Hosting, Rechtsgrundlage, Informationspflichten, Auftragsverarbeitung und Löschfristen klären. Keine Namenszuordnung in dieses Repository hochladen.
Vor dem Schuleinsatz Rechte und Datenbankfunktionen im eigenen Projekt prüfen. Der lokale Test prüft Accountkürzel, Statistikberechnung und HTML-Escaping; ein erfolgreicher Datenbank-Livetest steht bis zum Ausführen der Einrichtung aus.

## Prüfung

`npm test` führt die lokalen Funktionstests aus. Manuelle Abnahme: Schüler sieht ausschließlich eigene Daten und Freigaben; Lehrkraft sieht nur eigene Klassen; falsche Logins werden begrenzt; Passwortanzeige funktioniert; Rücksetzen erhält Freigaben; Lehrertests erzeugen keine Lernstände.

Siehe `docs/ANWENDUNGEN.md` zum Ergänzen weiterer Anwendungen.
