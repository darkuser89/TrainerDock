# Epic-Startprobe (nur Entwicklung)

Kein Produktcode. Standardmäßig liest `controller.py` nur die benannten sicheren
Installationsmetadaten und eine private Datei mit **eigenen** Trainerwerten.
Ohne `--run` werden weder Dateien angelegt noch Prozesse gestartet.

Die vorbereitete echte Transaktion benötigt vorab den ausdrücklichen Nutzerauftrag:

1. Originale `.item`-Identität, Installationswurzel, relativen Startpfad und SHA-256
   des Originalexecutables gegen die konkrete Spezifikation prüfen. Bereits laufendes
   Originalspiel ablehnen. Kein Ersatzstart und kein Epic-Neustart.
2. Einen zufällig benannten eigenen nativen Broker und seine private Konfiguration
   **neben** der Spiele-App anlegen; keine Datei im App-Bundle verändern.
3. Originalbytes vorab in einem kleinen privaten, fsync-gesicherten Journal außerhalb
   des Repositories aufbewahren. Im Manifest ausschließlich den Zeichenkettenwert
   `LaunchExecutable` ersetzen; alle anderen Bytes und `LaunchCommand` erhalten.
4. Genau einen offiziellen Epic-Deep-Link öffnen. Epic erzeugt und übergibt seine
   Startargumente. Der Broker protokolliert, liest oder speichert deren Inhalte nicht;
   er reicht denselben `argv` direkt an das exakte Originalprogramm weiter. Erst vor
   `execv` setzt er die eigene MHT-/DYLD-Umgebung. Keine Kontodaten oder Token lesen.
5. Beim ersten Broker-Ack sofort die exakten Originalbytes zurücknehmen, ebenso bei
   Fehler oder Timeout (Standard 45 Sekunden). Nur zurücknehmen, wenn das Manifest
   noch unserer Mutation entspricht; neuere fremde Änderungen erhalten und das
   Journal für die Prüfung behalten. SIGINT/SIGTERM lösen dieselbe Rücknahme aus.
6. Broker und Sidecar erst entfernen, wenn keine Prozessidentität mehr den Broker
   ausführt. Bei Crash bleibt das Journal für `--recover` erhalten. Ein gestartetes
   Spiel wird vom Controller niemals geschlossen.

Der Dateisystemvergleich ist keine exklusive Sperre des fremden Epic-Clients.
Konkurrierende Epic-Dateiänderungen werden vor Schreiben/Rücknahme geprüft;
ein Konflikt beendet die Probe und behält die Wiederherstellungsdaten.

`original-exec-confirmed` bestätigt nur die native Prozessidentität nach `execv`,
**nicht** erfolgreiche Epic-Anmeldung, Hauptmenü oder Cheatwirkungen. Der echte
Vampire-Survivors-Test zeigte: Ein bereits laufender Epic-Client überschreibt die
Umleitung aus seinem Cache und startet ohne Helfer. Nach regulärem Beenden des
Clients wurden Originalstart, Trainerverbindung und lokaler Lauf bestätigt.
Vor einer Probe deshalb den Epic-Client regulär beenden; der Produktdienst lehnt
einen laufenden Client ausdrücklich ab. Keine stillen Wiederholungen ergänzen.

## Synthetisch bauen und prüfen

```sh
mkdir -p /private/tmp/trainerdock-epic-launch-test-build
xcrun clang -arch arm64 -mmacosx-version-min=27.0 -fobjc-arc \
  -Wall -Wextra -Werror -framework AppKit -framework Foundation \
  Tests/EpicLaunch/Broker.m Core/MHTEpicLaunch.m \
  -o /private/tmp/trainerdock-epic-launch-test-build/Broker
EPIC_TEST_BROKER=/private/tmp/trainerdock-epic-launch-test-build/Broker \
  python3 -B Tests/EpicLaunch/test_controller.py
```

Fixtures und temporäre synthetische Programme entstehen ausschließlich unter
`/private/tmp` und werden nach dem Test entfernt. Kein installiertes Spiel,
Epic-Client, Originalmanifest oder Spielstand wird für diese Tests benutzt.

## Private Eingaben vorbereiten

`Spec.json` enthält genau `manifest`, `appName`, `namespace`, `install`,
`launchExecutable` und `targetSHA256` aus der geprüften Installation. `Launch.json`
(Modus 0600) enthält genau `target` und `environment`; darin ausschließlich eigene
`MHT_*`-Werte, `DYLD_INSERT_LIBRARIES` und optional `DYLD_LIBRARY_PATH`.
Keine Startargumente, Authentisierungswerte oder Konto-Dateien hineinkopieren.

```sh
# Nur lesender Plan; Werte sind zuvor konkret vorzubereiten:
python3 -B Tests/EpicLaunch/controller.py --spec /private/tmp/Spec.json \
  --config /private/tmp/Launch.json \
  --broker /private/tmp/trainerdock-epic-launch-test-build/Broker

# Ausschließlich nach ausdrücklicher Freigabe dieselben Argumente um --run ergänzen.
# Nach einem Prozessabbruch ausschließlich rücknehmen, ohne Start:
python3 -B Tests/EpicLaunch/controller.py --recover /private/tmp/trainerdock-epic-launch-test/UID/transaction.json
```
