# Durchlauf 2 – Ergänzungen zum Bug-Katalog

Neue Fallen, die beim Neubau aufgetaucht sind. Gleiche Form wie in REBUILD-BRIEF.md
Abschnitt 8: **Symptom → Ursache → Lösung.**

### A.5 — Boden war unsichtbar, nur Himmelsfarbe
Selbst gebautes Terrain-Mesh per `SurfaceTool`, Dreiecke gegen den Uhrzeigersinn.
Godot zeichnet Vorderseiten **im Uhrzeigersinn**; von oben war das Terrain Rückseite
und wurde weggeschnitten. Eingebaute Meshes (Plane, Cylinder) waren fein, deshalb fiel
es nur beim Terrain auf.
→ Dreiecke im Uhrzeigersinn ausgeben. Normale trotzdem aus der CCW-Reihenfolge rechnen
und bei Bedarf umdrehen. Sichtprüfung per Screenshot, sonst bleibt es unbemerkt.

### A.6 — `Curve` klemmt still auf 0..1
`Curve.sample()` clamped auf `min_value`/`max_value`, Standard **0 bis 1**. Die
Sonnenwinkel-Kurve (−30°..60°) lieferte dadurch 0..1 Grad: Sonne den ganzen Tag am
Horizont, ewig lange Schatten, Steine sahen wie flache Scheiben aus. Die Energie-Kurve
kam nie über 1.0. Kein Fehler, keine Warnung.
→ `min_value`/`max_value` aus den Stützpunkten setzen, **bevor** Punkte hinzukommen.
Ein Test, der den Mittagswert prüft, hätte es sofort gezeigt.

### A.7 — `Gradient` bringt zwei Standardpunkte mit
`Gradient.new()` hat bereits Punkte bei 0 und 1. Nur `add_point` aufrufen ergibt vier
Stützstellen mit Standardfarben dazwischen.
→ Erst `offsets`/`colors` mit Anfang und Ende überschreiben, dann die Mitte einfügen.

### D.4 — Boden-Rauschen zerfiel in Kacheln
`fract(sin(dot(p, …)) * 43758.5453)` verliert bei Weltkoordinaten in Parkgröße die
Präzision und wird zu achsenparallelen Quadraten, unabhängig von der Anzahl Oktaven.
→ Integer-Hash (uint-Multiplikation/XOR-Shift) statt Sinus-Hash.

### D.5 — Blaues Wasser, nur der Kopf schaute heraus
Der Körper-Ursprung lag auf der Wasserlinie; das Modell hängt aber am Fußpunkt, also
war der Rumpf komplett unter Wasser.
→ Schwimmhöhe am Modell messen (`tools/inspect_model.tscn` liefert die AABB), nicht am
Kollisionskörper raten. Ente sitzt hoch, etwa ein Drittel unter Wasser.

### D.6 — Eine Bodenplatte als Horizont verdeckte den Teich
Eine große Ebene knapp unter Null als „Wiese bis zum Horizont" lag über der Teichmulde.
→ Vier Streifen außerhalb der Wände statt einer Platte unter allem.

### E.4 — `:=` bei untypisierten Werten ist ein Parse-Fehler
`var x := load(path).new()` oder `var y := array.filter(...)` scheitert („cannot infer
type"), und zwar erst zur Laufzeit beim Laden des Skripts. Die Szene lädt dann nicht.
→ Bei `load(...).new()`, `filter`, `map` explizit typisieren oder `=` verwenden.
`tools/check_scripts.tscn` findet das vor dem ersten Start.

### E.5 — `_ = wert` ist kein GDScript
Der „unbenutzt"-Trick aus anderen Sprachen ist ein Parse-Fehler.
→ Weglassen. Unbenutzte Parameter mit Unterstrich-Präfix benennen.

### F.5 — Ein Test, der nicht endet, hängt die Suite
Ein Testskript mit Parse-Fehler ließ `script.new()` scheitern; der Runner blieb ohne
`quit()` ewig laufen.
→ Wächter-Timer im Runner (120 s → FAIL, Exit 3) **und** `timeout` im Shell-Skript.
Beides, weil das eine das andere nicht abdeckt.

### F.6 — Live-Knoten überschreiben beim Speichern den Testzustand
Der Test setzte `GameState.neighbours["frog"]` direkt; beim Speichern schrieben die
Tier-Knoten ihre eigenen Werte darüber (das ist korrekt so).
→ Wahrheit dort setzen, wo sie lebt: am Knoten, nicht im Dictionary.

### G.7 — Der Anlauf zum Anfreunden blockierte sich selbst
Die „Tier bemerkt dich"-Zone war an die schrumpfende Komfortdistanz gekoppelt. Sobald
die Familie näher heran durfte, lag sie außerhalb der Zone und der Fortschritt stand.
→ Wahrnehmungsradius fest, nur die Fluchtdistanz schrumpft.

### G.8 — Küken blieben nach dem Wachsen am Nest stehen
Das Wachstum setzte `nest_bound = false` im Datensatz, der Zustandsautomat des Kükens
kannte den Wechsel nicht.
→ Der Automat folgt dem Datensatz, nicht umgekehrt: pro Frame prüfen, nicht nur in
`_ready()`. (Gleiches Muster wie 8.G.1: zwei Wege, dieselbe Bedingung.)

---

## Was diesmal von Anfang an da war

- Datei-Dispatcher für Tests (7.1) vor dem ersten Feature: 15 Tests, keine `if/elif`-Kette.
- Screenshot-Werkzeug (`tools/screenshot.tscn`) mit benannten Ansichten. Jede Optik-
  Änderung wurde angeschaut, bevor sie committed wurde. Vier der Fallen oben kamen nur
  dadurch ans Licht (A.5, A.6, D.4, D.5).
- Modell-Inspektor, um Clip-Namen und Größen zu *wissen* statt zu raten (8.C.2).
- Die drei Shader im ersten Weltaufbau, nicht als Politur (9.4).

## Offen geblieben

- Kamera fährt in Büsche hinein (keine Kollision, absichtlich, aber unschön). Möglich:
  Büsche in Kameranähe ausblenden.
- Trampelpfade, Löwenzahn im Wind, Regen, Glühwürmchen, Gefiederfarbe, Mausern (5.10).
- Balance nur im Zeitraffer. Beleuchtung über einen ganzen Tag nie am Stück angeschaut.
- Steam-Export weiterhin nicht versucht.
