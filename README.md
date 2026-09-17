# WaddleTogether

Ein gemütliches 3D-Life-Sim in Godot 4: Du bist eine Entenmutter in einem friedlichen
Park. Nest bauen, Eier legen, Küken großziehen – und ihnen beibringen, wie man Ente ist.
Keine Gegner, kein Zeitdruck, kein Verlust.

Die Design-Entscheidungen, Regeln und Fallen stehen in [REBUILD-BRIEF.md](REBUILD-BRIEF.md).
Dieses Repository ist der zweite Durchlauf, der die dort beschriebenen Umwege überspringt.

## Spielen

Projekt in Godot 4.5+ öffnen (entwickelt mit 4.7.1) und starten. Startszene ist das Hauptmenü.

| Taste | Aktion |
|---|---|
| WASD | Watscheln / Schwimmen |
| Q / E, Pfeil links/rechts | Kamera drehen |
| Leertaste | Interagieren (Nest bauen, Ei legen, füttern, kuscheln, Fundstück ablegen) |
| F kurz tippen | **Sammeln** – Küken in Hörweite kommen |
| F doppelt tippen | **Schau mal!** – Küken laufen in deine Blickrichtung |
| F halten | **Weitruf** (überall) bzw. **Schlaflied** (am Nest) |
| Shift halten (im Wasser) | Gründeln |
| J | Tagebuch |
| Esc | Pause |

Die Beziehung zu den Küken hat absichtlich keine Anzeige. Was sie gelernt haben, siehst
du nur daran, was sie tun.

## Struktur

```
game/
  autoload/     EventBus, GameState, InputRouter, SaveManager, AudioManager,
                Settings, Journal, Progression, Daytime
  main/         game.tscn – Park + HUD
  ui/           Hauptmenü, HUD (Zähler, Prompt, Namensgebung, Tagebuch, Pause)
  world/        park.gd (Terrain, Teich, Licht), Pickups, Tore, Abenteuer,
                Dekoration, Generationen, Shader
  entities/     Entenmutter, Küken (+ Komponenten), Nest, Modell-Pipeline, Nachbarn
  data/         Wachstumsstufen (.tres), Temperamente (.tres)
  tests/        Ein Test = eine Datei, siehe unten
assets/         Modelle und Audio (Drop-in, siehe assets/models/MODELS.md)
tools/          Testrunner, Skript-Check, Modell-Inspektor, Screenshot-Werkzeug
```

## Tests

Jeder Test ist eine Datei `game/tests/<name>_test.gd`, ausgewählt über `WADDLE_TEST=<name>`.
Der Runner startet die echte Spielszene darunter und ruft `run(main)` auf.

```bash
tools/run_tests.sh            # alle, mit Zusammenfassung und Exit-Code
tools/run_tests.sh learning   # einzelne
```

PowerShell: `tools\run_tests.ps1`. Logs liegen unter `tools/test_out/`.

Parse-Fehler vorab finden (nach dem Anlegen neuer Skripte):

```bash
godot --headless --path . res://tools/check_scripts.tscn
```

## Sichtprüfung

`--headless` rendert nichts. Für Screenshots die GUI-Binary benutzen:

```bash
WADDLE_VIEW=pond WADDLE_BROOD=3 WADDLE_SHOT=out.png godot --path . res://tools/screenshot.tscn
```

Ansichten: `spawn`, `nest`, `brood`, `pond`, `ground`, `top`, `meadow`, `forest`, `night`.
`WADDLE_TIME=0..1` setzt die Tageszeit, `WADDLE_BROOD=n` schlüpft n Küken vorab.

## Modelle

`assets/models/duck_mother.glb` und `duckling.glb` werden automatisch montiert; fehlen
sie, laufen Graybox-Primitive. `tools/inspect_model.tscn` listet Größe, Materialien und
Animationsclips. Keine Inhalte aus fremden Webviewern scrapen (Regel 3.4 im Brief).
