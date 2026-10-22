# Anwendungen ergänzen

Die erste Lernanwendung ist der Halloween-Waffelstand.
Accounts und Lernstände bleiben beim Hinzufügen neuer Anwendungen erhalten.

1. Modul unter `applications/<kennung>/index.js` hinzufügen. Export: `mount(container, context)`.
2. Im SQL Editor einen Eintrag in `bwr_private.apps` und die fachlich geprüften Aufgaben in `bwr_private.tasks` anlegen. IDs bleiben nach der Veröffentlichung stabil.
3. Im Lehrerbereich unter Anwendungen die Anwendung der Klasse zuordnen und anschließend für die Klasse oder einzelne Accounts freischalten.

`context` enthält `test`, `tasks`, `start()`, `check(taskId, answer, requestId?)`, `solution(taskId)` und `repeat()`.
Bei Wiederholung einer fehlgeschlagenen Netzwerkanfrage dieselbe `requestId` verwenden. Das verhindert doppelte Fehlerzählung.
Lehrertests gehen durch dieselbe fachliche Prüfung, schreiben aber keinen Bearbeitungsstand.
Ein Schülerdurchlauf ist abgeschlossen, wenn alle Aufgaben im aktuellen Durchlauf richtig beantwortet sind. Das Anzeigen einer Lösung markiert eine Aufgabe nicht als gelöst.
Fehlversuche werden über alle Durchläufe addiert. Ein neuer Durchlauf löscht die aktuellen Antworten und die Liste gelöster Aufgaben, erhält aber die Statistik.

Die erste Prüfschnittstelle vergleicht nach Entfernen äußerer Leerzeichen ohne Unterscheidung der Großschreibung. Für Zahlenformate, Buchungssätze, alternative richtige Antworten und Folgefehler muss sie bei der jeweiligen Anwendung gezielt um fachliche Normalisierung erweitert werden. Die Halloween-Anwendung wird erst nach Prüfung des Arbeitsblatts ergänzt.

Mit Update 04 unterstützt die Schnittstelle strukturierte Feldgruppen. `context.progress` enthält den geladenen Arbeitsstand. `check` nimmt für diese Aufgaben ein Objekt mit Feldschlüsseln an. Geldbeträge werden numerisch geprüft; Kontonummern und bekannte Kürzel werden vereinheitlicht. Musterlösungen werden für Schüler erst nach drei Fehlversuchen der Prüfgruppe im aktuellen Durchlauf ausgeliefert. Lehrer können alle Musterlösungen im speicherfreien Testmodus öffnen. Antworten mit einem leeren Pflichtfeld lösen keine Fehlerzählung aus. Unterschiedliche, aber inhaltlich richtige freie Rechenausdrücke werden nicht automatisch ausgewertet; Schüler geben Ergebnisse in die getrennten Zahlenfelder ein.

Dateien eines Moduls werden erst beim Öffnen geladen. Schüler erhalten über die Datenbank nur freigegebene Aufgaben; die richtigen Antworten werden serverseitig geprüft.
