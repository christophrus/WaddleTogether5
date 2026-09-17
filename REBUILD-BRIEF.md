# WaddleTogether — Rebuild-Briefing

**Zweck dieses Dokuments:** Alles, was nötig ist, um dieses Spiel von Grund auf neu zu
bauen — *besser* als beim ersten Mal. Es ist keine Nacherzählung des bestehenden Codes,
sondern eine Weitergabe von Entscheidungen, Fallen und Erkenntnissen.

Der erste Durchlauf umfasst ~4.300 Zeilen GDScript (plus ~1.200 Zeilen Tests) über neun
Meilensteine. Vieles davon war Sackgassen-Arbeit. Dieses Dokument soll die Sackgassen
überspringbar machen.

**Lies zuerst Abschnitt 3 (harte Design-Regeln) und Abschnitt 8 (Bug-Katalog).** Der Rest
ist Kontext; diese beiden sind das, was den Unterschied macht.

---

## 1. Das Spiel in einem Absatz

Ein gemütliches 3D-Life-Sim in Godot 4. Der Spieler steuert eine **Entenmutter** in einem
friedlichen Park, baut ein Nest, legt Eier, zieht **Küken** groß und erlebt mit ihnen
kleine Abenteuer. Vorbild ist *A Waddleful Life*. **Keine Gegner, kein Zeitdruck, kein
Fail-State, kein Verlust.** Singleplayer. Zielgruppe: Cozy-Games, Tierliebhaber.

Die zentrale Fantasie ist nicht „Ressourcen verwalten", sondern **„diese Küken sind
meine, und sie werden zu jemandem."**

---

## 2. Technischer Rahmen

| Punkt | Wert |
|---|---|
| Engine | Godot 4.7.1 (4.5+ nötig) |
| Sprache | GDScript |
| Spieler-Texte | **Deutsch** |
| Code-Kommentare | **Englisch**, und sie erklären das **Warum**, nicht das Was |
| Plattform-Ziel | Steam (fern), Windows-Entwicklung |
| Startszene | Hauptmenü |

**Kommentarstil ist wichtig.** Der bestehende Code kommentiert konsequent Design-Absicht
und Fallstricke, nicht Syntax. Beispiel aus `learning_component.gd`:

> *„Proximity-based on purpose: the mother has to do the thing where the brood can watch.
> That quietly turns ordinary movement into teaching … without ever adding a fail state."*

Das ist der Ton. Ein Kommentar, der nur beschreibt, was die Zeile tut, ist verschwendet.

---

## 3. Harte Design-Regeln (nicht verhandelbar)

Diese vier Regeln haben im ersten Durchlauf mehrfach Entscheidungen umgeworfen. Sie
vorher zu kennen, spart die Umwege.

### 3.1 Kein Fortschrittsbalken für Beziehungen

> **Wortlaut des Auftraggebers:** „Kein UI-Balken. Der Fortschritt ist nur am Verhalten
> sichtbar — sonst wird aus einer Beziehung eine Tabelle."

Alles, was die *Beziehung* zu den Küken betrifft (Lernen, Bindung, Temperament, Zutrauen
der Parktiere), darf **nirgends** als Balken, Prozentzahl oder Statistik erscheinen. Weder
im HUD, noch in einem Menü, noch in einem Tooltip.

Jede Lernschwelle braucht stattdessen eine **sichtbare Verhaltensänderung** als einzige
Anzeige:
- Ein ungelehrtes Küken watschelt an Futter vorbei, als wäre es keins.
- Ein Küken, dem noch niemand das Wasser gezeigt hat, bleibt piepsend am Ufer stehen,
  während die Mutter schwimmt.
- Ein Nachbar-Tier lässt dich heute einen Schritt näher heran als gestern.

**Ausnahme:** Reine Objekt-Zähler sind erlaubt (getragenes Futter, Nistmaterial,
Brut-Fortschritt eines Eis). Das sind Gegenstände, keine Beziehungen.

### 3.2 Keine Strafe, kein Verlust

> „Ein draußen gebliebenes Küken wird nicht bestraft; du willst es trotzdem holen. Das ist
> der Unterschied zwischen Zwang und Fürsorge."

Nichts geht kaputt, nichts stirbt, nichts läuft ab. Bedürfnisse *nudgen* Verhalten und
erzeugen Geräusche — sie entziehen nie etwas. Wenn ein Design-Vorschlag eine Bestrafung
enthält, ist der Vorschlag falsch, nicht die Regel.

### 3.3 Abend ist eine Handlung, kein Knopfdruck

Sinngemäß: Rituale sollen *getan* werden, nicht passieren. Konkret hat das einen echten
Bug produziert (siehe 8.G.1): Küken schliefen automatisch ein, sobald es dunkel wurde —
egal wo. Damit wurde der Heimweg bedeutungslos. Die Regel: **Wenn etwas ein Ritual sein
soll, muss der Ort oder die Handlung Bedingung sein**, nicht bloß der Zeitpunkt.

### 3.4 Keine fremden Inhalte scrapen

Der Auftraggeber bat zweimal darum, Texturen aus dem Sketchfab-Webviewer zu scrapen (weil
sie im offiziellen Download fehlten). Das wurde abgelehnt und bleibt abgelehnt.

**Wichtige Nuance:** Das ist *kein* generelles Verbot externer Assets. Die beiden
Enten-Modelle liegen legitim vor. CC0-Packs (Quaternius, Kenney, Poly Pizza) sind
ausdrücklich in Betracht gezogen worden — siehe 9.3.

---

## 4. Die Kern-Spielschleife

Vom Auftraggeber wörtlich vorgegeben:

1. **Nistmaterial sammeln**, bis das Nest fertig ist.
2. Dann **Eier legen und ausbrüten** — plus die Möglichkeit, später noch mehr zu legen.
3. **Küken schlüpfen** und müssen **im Nest** gefüttert werden.
4. Wenn die Küken groß genug sind, **folgen sie der Mutter**.
5. Die Mutter **bringt den Küken bei**, wie man Nahrung sammelt.
6. Küken wachsen und **unternehmen Abenteuer** zusammen mit der Mutter.

Drei geklärte Detailfragen:
- **Schritt 5 bedeutet echtes Lernen**, nicht ein Freischalten nach Wachstumsstufe. Küken
  lernen selbstständig zu fressen, indem sie zuschauen.
- **Nestgebundene Phase ist erwünscht**: frisch geschlüpfte Küken bleiben am Nest und
  folgen noch nicht.
- **Eier sind auf ein Maximum begrenzt** (Standard: 4 gleichzeitig; ein Platz wird frei,
  sobald ein Küken das Nest verlässt).

---

## 5. Mechaniken

### 5.1 Fundament (erste Meilensteine)

- **Entenmutter:** `CharacterBody3D`. Watscheln an Land, Schwimmen/Auftrieb im Wasser,
  Gründeln (Tauchen). Bewegung ist kamerarelativ. **Wichtig:** Der Körper rotiert nie
  selbst um Y — ein Kind-Node `Model` dreht sich in Laufrichtung, ein separater
  `CameraRig` hält die Kamera-Gierung. Das hält die Richtungsmathematik trivial.
- **Küken:** eigenständige `CharacterBody3D` mit Boids-artigem Folgeverhalten
  (Kohäsion + Separation von Geschwistern).
- **Bedürfnisse:** Hunger (0 = satt, 1 = hungrig) steigt langsam; Zuneigung. Weiche
  Werte, nie tödlich.
- **Wachstum:** datengetrieben über eine `.tres`-Resource (Stufen: Küken → Jungvogel →
  Flügge, je mit Skalierung, Farbe, Fütterungen-bis-Wachstum). Letzte Stufe löst den
  „ersten Flug" aus.
- **Pickups:** Futter und Nistmaterial, aufgesammelt durch Drüberlaufen. **Respawnen**
  nach ~45 s (±20 % Jitter), damit die Karte nicht leerläuft. Der Auftraggeber wollte
  reichlich davon: 20 Futter + 19 Nistmaterial über die Karte verteilt.
- **Nest:** Materialabgabe baut es in Stufen aus; fertig gebaut wechselt dieselbe
  Interaktion auf „Ei legen".
- **Zonen & Abenteuer:** fortschrittsbasierte Freischaltung (Nest-Ausbau → Wiese,
  Flügge-Werden → Waldrand); ein geskriptetes Abenteuer mit Start-/Ziel-Trigger.
- **Journal:** Erinnerungen als Tagebuchzeilen, ausgelöst über Signale.

### 5.2 Quak-Grammatik — eine Sprache aus Timing

Aus einem Knopf werden vier Rufe, unterschieden **nur durch Rhythmus**. (Echte
Stockenten kommunizieren tatsächlich so.)

| Geste | Ruf | Wirkung |
|---|---|---|
| Kurz tippen | **Sammeln** | Küken kommen — nur in Hörweite (~11 m) |
| Doppelt tippen | **Schau mal!** | Küken laufen in deine Blickrichtung; liegt dort Futter, lernen sie daraus |
| Halten | **Weitruf** | Trägt über die ganze Karte, holt Verirrte |
| Halten **am Nest** | **Schlaflied** | Brut legt sich hin, steht erst wieder auf, wenn du weggehst |

**Architektur-Entscheidung, die sich bewährt hat:** Die Gestenerkennung (Tippen vs.
Halten vs. Doppeltippen) gehört in den **Input-Layer** — das ist Eingabe-Arbeit. Die
Auflösung Weitruf→Schlaflied gehört in die **Ente**, weil sie ausschließlich vom Ort
abhängt. Diese Trennung sauber zu ziehen, hat den Code deutlich lesbarer gemacht.

Timing-Werte, die sich gut angefühlt haben: Halten ab 450 ms, Doppeltipp-Fenster 300 ms.
Ein einfacher Tipp löst erst nach Ablauf des Doppeltipp-Fensters aus — die 300 ms
Verzögerung sind in einem unhektischen Spiel unmerklich.

### 5.3 Lernen durch Nachahmung — das Herzstück

Jedes Küken führt **vier stille Werte**: `foraging`, `swimming`, `dabbling`, `courage`.

Sie wachsen **ausschließlich** dadurch, dass die Mutter etwas in Sichtweite tut. Ein
globales Signal trägt „hier ist gerade etwas Lehrreiches passiert" samt Ort und Menge;
jedes Küken entscheidet selbst, ob es nah genug war. Aufmerksamkeit fällt mit der
Entfernung ab (voll bei 0 m, ~35 % am Rand des Sichtradius von ~7 m), nie auf null.

An Schwellen schalten sich **Verhaltensweisen** frei:

| Wert | Schwelle 1 | Schwelle 2 |
|---|---|---|
| `foraging` | pickt selbst | bringt dir Futter |
| `swimming` | traut sich ins Wasser | — |
| `dabbling` | gründelt selbst | — |
| `courage` | streift umher, findet Fundstücke | holt verirrte Geschwister |

**Das Entscheidende:** Ein Küken ohne `foraging` läuft an Futter vorbei. Ein Küken ohne
`swimming` bleibt am Ufer stehen und piepst der schwimmenden Mutter hinterher. *Das* ist
die Anzeige — kein Balken (siehe 3.1).

Ein schöner Nebeneffekt: Damit wird gewöhnliches Herumlaufen zum Unterricht. Die Küken
beim Sammeln mitzunehmen ist eine andere Handlung als allein zu sammeln.

**Wichtig fürs Namensschema:** Das Signal sollte **nicht** `mother_did_x` heißen, sondern
neutral (z. B. `mother_demonstrated`). Grund: Im geplanten Generationen-Kreis (5.8) senden
später erwachsene Junghelfer **exakt dasselbe Signal**. Ein neutraler Name macht dieses
Feature zu einer Nulländerung am Lernsystem.

### 5.4 Küken-Persönlichkeiten

Sechs Temperamente: **die Neugierige, der Ängstliche, die Verfressene, der Verträumte,
die Mutige, der Anhängliche.** Pro Gelege verschieden verteilt (keine Dubletten, solange
der Vorrat reicht).

Jedes zeigt sich **dreifach**:
- **Auge:** leichter Farbstich und abweichende Größe.
- **Ohr:** eigene Stimmhöhe des Piepsens (eine `pitch_scale`-Variation auf derselben
  Audiodatei — der billigste Weg, sechs Küken nach sechs Küken klingen zu lassen).
- **Verhalten:** deutlich verschiedene Lerngeschwindigkeiten und Folgeabstände.

**Balance-Regel:** Jedes Temperament ist in etwas schnell und in etwas langsam. Keins ist
besser. Die Verfressene lernt Futtersuche doppelt so schnell, aber Mut langsamer; der
Ängstliche traut sich kaum ins Wasser, lernt aber aufmerksam am Futter.

**Namensgebung:** Küken schlüpfen **namenlos**. Beim **ersten Kuscheln** darf der Spieler
einen Namen eingeben (Eingabefeld mit Vorschlag, Steuerung währenddessen gesperrt). Das
ist der Moment, in dem ein Spielobjekt zu jemandem wird — er verdient eine eigene kleine
Szene.

### 5.5 Gründeln

Das eine Verb, das nur Enten haben. Im Wasser Tauchtaste halten → die Ente kippt nach
vorn, Schwanz senkrecht. Der Ton wird dumpf (eine schlichte Lautstärkeabsenkung reicht
völlig). Nach ein paar Sekunden kommt sie mit Futter oder einem Fundstück hoch.

Küken, die zugeschaut haben, machen es nach. **Vier Entenpopos in der Luft ist der beste
Screenshot des Spiels** — das ist ein ernst gemeintes Design-Ziel.

### 5.6 Wärme statt Hunger

Die Umkehrung des Survival-Meters. Nachts piepst ein Küken, das nicht in deiner Nähe ist
— immer etwas häufiger, je länger es allein bleibt (Intervall rampt z. B. von 6 s auf
2 s), und **sofort still**, sobald du kommst.

**Keine Zahl, keine Strafe, kein Verlust.** Das Geräusch ist der komplette Rückkanal.

Dazu gehört ein **Tag/Nacht-Zyklus**: Zeit als Float 0..1, ein voller Tag ~14 Minuten,
keine Uhr im UI. Die Tageszeit zeigt sich ausschließlich an Licht- und Himmelsfarbe
(Gradient-Keyframes für Sonnenwinkel, Lichtfarbe/-energie, Himmel- und Ambientfarben).
Die Tageszeit gehört in den Spielstand — ein nachts gespeichertes Spiel lädt auch nachts.

### 5.7 Fundstücke

Kronkorken, Murmeln, Knöpfe, blaue Glasscherben, glatte Kiesel. Mutige Küken finden sie
beim Umherstreifen und tragen sie stolz zum Nest, wo sie **dauerhaft liegen bleiben**
(im Spielstand). Die Mutter findet beim Gründeln gelegentlich auch welche.

Sie tun nichts und sind nichts wert — **das ist der Punkt.** Über viele Sitzungen wird der
Ring um das Nest zu einem Museum der eigenen Familiengeschichte. Das Nest hört auf, ein
Fortschrittsbalken zu sein, und wird ein Ort.

### 5.8 Scheue Nachbarn

Frosch, mürrischer Reiher, Schildkröte. Jeder hat eine **Komfortdistanz**, die schrumpft,
wenn sich die Familie ruhig in der Nähe aufhält (auch Gründeln zählt als ruhig), und
wieder wächst bei einem schnellen Anlauf oder einem Weitruf — nie über den Startwert
hinaus, ein Schreck kostet Fortschritt, macht es aber nie schlimmer als Tag eins.

Unterschreitet sie eine Schwelle, ist das Tier **für immer** angefreundet, flieht nie
wieder und bekommt ein kleines Signatur-Verhalten.

Jeder ist auf eine **andere Art** scheu — das ist wichtiger als die Zahlenwerte:
- **Frosch:** schreckhaft, hüpft in kurzen Sätzen weg.
- **Reiher:** würdevoll, stapft kontinuierlich davon statt zu hüpfen, braucht am längsten.
- **Schildkröte:** flieht **nie**, ist unbeeindruckbar — und dadurch die leichteste.
  Genau das ist die Pointe.

Die Belohnung fürs Anfreunden ist, **nah rankommen zu dürfen** — kein Bonus, kein
freigeschaltetes Feature.

### 5.9 Parkdekoration

Bäume (zwei Silhouetten: Rundkrone und Nadelbaum), Büsche, Schilf am Teichrand, Seerosen,
Steine, Parkbänke, ein Kiesweg und ein sichtbarer Bach.

**Platzierung:** deterministisch (fester RNG-Seed, damit der Park über Sitzungen gleich
aussieht und Tests darauf prüfen können) und per Rejection-Sampling, das sich automatisch
von allem fernhält, was fürs Spiel zählt. Die Sperrzonen werden **zur Laufzeit aus Gruppen
gelesen** (Nest, Spawn, Tore, Trigger, Pickups, Tierreviere), nicht als Liste gepflegt —
eine gepflegte Liste driftet garantiert auseinander.

**Kollision:** Nur Bäume und Bänke sind solide. Büsche, Steine und Schilf ausdrücklich
**nicht** — sonst wird „zum Teich laufen" zum Slalom.

### 5.10 Noch nicht gebaut — aber Teil der Vision

Diese Ideen stammen vom Auftraggeber und gehören zum Zielbild:

- **Der Generationen-Kreis** *(das eigentliche Finale)* — eines Morgens liegen Eier im
  Nest. Die alte Brut verschwindet nicht: Sie wird zu **Junghelfern**, die Nachzügler
  einsammeln und den Kleinen beibringen, was du ihnen beigebracht hast. Technisch elegant,
  weil Helfer einfach dasselbe Lehr-Signal senden wie die Mutter. *„Der Erfolg besteht
  darin, überflüssig zu werden."*
- **Trampelpfade** — wo ihr oft lauft, legt sich das Gras flach. Die Welt merkt sich
  Gewohnheiten.
- **Löwenzahn-Jagd im Wind.**
- **Regen als Inhalt statt Hindernis** — Pfützen, Würmer, Unterstellen unter einem Blatt.
- **Sternbilder aus freigelassenen Glühwürmchen.**
- **Gefiederfarbe nach Ernährung.**
- **Mausern** — Flaumfedern werden zu Nistmaterial, Kreis geschlossen.

---

## 6. Architektur — was sich bewährt hat

### 6.1 Autoload-Singletons

Reihenfolge ist relevant (spätere dürfen frühere benutzen):

| Autoload | Aufgabe |
|---|---|
| `EventBus` | **Nur Signal-Deklarationen**, keine Logik. Der Kopplungs-Knotenpunkt. |
| `GameState` | Serialisierbarer Weltzustand. Entitäten referenzieren über **IDs**, nicht Node-Pfade. |
| `InputRouter` | Roheingabe → Absicht, pro `player_id`. |
| `SaveManager` | JSON nach `user://`, Autosave bei Meilenstein-Signalen. |
| `AudioManager` | SFX/Musik nach Namen; **fehlende Dateien werden still ignoriert**. |
| `Settings` | Vollbild u. ä. |
| `Journal` | Hört auf Signale, schreibt Tagebuchzeilen. Kein System kennt es. |
| `Progression` | Übersetzt Meilensteine in freigeschaltete Zonen. Regeln an einem Ort. |
| `Daytime` | Tag/Nacht-Uhr + Weltbeleuchtung. |

### 6.2 Muster, die sich getragen haben

**Signal-Hub statt harter Referenzen.** Systeme emittieren und lauschen am `EventBus`.
Das macht Tests trivial (Signal spionieren statt Objekte verdrahten) und hält Features
unabhängig.

**Komponenten statt Vererbung.** `NeedsComponent`, `GrowthComponent`, `FlockFollowComponent`,
`LearningComponent` sind eigenständige Kind-Nodes. Ein Küken setzt sich aus ihnen zusammen.

**Entenähnliche Interaktion (duck typing).** Interagierbare Objekte sind einfach Nodes in
der Gruppe `interactable` mit `get_interaction_prompt(duck)` und `interact(duck)`. Keine
Basisklasse, keine Registry. Die Ente scannt in Reichweite und zeigt den nächstbesten
Prompt. Das hat über neun Meilensteine ohne eine einzige Änderung getragen.

**Gruppen als Laufzeit-Verzeichnis.** Statt Positionen und Referenzen zu pflegen, werden
sie aus Gruppen gelesen (`duck`, `duckling`, `pickup`, `nest_site`, `neighbour`,
`zone_gate`, `adventure_zone`). Besonders wertvoll für die Dekoration (5.9).

**Ein Knoten pro System in der Weltszene.** Wildlife und Dekoration hängen je an **einem
einzigen leeren Node** in `park.tscn` und bauen alles Weitere im Code. Vorteil: Die
Weltszene bleibt beim Feature-Bau unangetastet, Diffs bleiben lesbar, und parallele
Arbeit kollidiert nicht.

**Kollisions-Layer-Konvention (bewährt, einfach):**
- Layer 1 = alles Feste (Boden, Bäume, Bänke, Barrieren). `collision_layer=1, mask=0`.
- Ente Layer 2, Küken Layer 8, beide `mask=1`.
- Neue feste Objekte brauchen dadurch **keine** neue Layer-Konfiguration.

**Koop-Vorsorge ohne Koop-Code.** Eingaben laufen über `InputRouter` mit `player_id`,
Entitäten identifizieren sich über IDs, Kommunikation über Signale. Netzwerkcode existiert
nicht, wäre aber nachrüstbar.

### 6.3 Modell-Pipeline (gut gelöst, übernehmenswert)

Figuren laufen mit **Graybox-Primitiven**, bis eine Modelldatei an einem festen Pfad
auftaucht — dann wird sie automatisch montiert und die Primitive versteckt. Kein
Code-Wechsel, kein Bruch, wenn die Datei fehlt.

Ein `ModelAnimator` mappt Clips **nach Schlüsselwort** auf logische Zustände
(`idle`/`walk`/`swim`/`dive`/…), weil Modelle unterschiedliche Clipnamen mitbringen
(`Duck_walk` vs. `walk`). Bewegungs-Clips werden auf Loop gestellt, Einmal-Clips nicht.

---

## 7. Test-Infrastruktur — das Wichtigste am Projekt

Das Spiel ist ohne Eingabe kaum manuell zu prüfen (langsame Zyklen, lange Brutzeiten,
Nachtphasen). Automatisierte Tests waren das, was Tempo überhaupt ermöglicht hat.

### 7.1 Aufbau — so, und nicht anders

**Ein Test = eine Datei** unter `game/tests/<name>_test.gd`, ausgewählt über **eine
einzige** Umgebungsvariable (`WADDLE_TEST=<name>`), die die passende Datei lädt.

Jede Testdatei: `extends Node`, eine Funktion `run(main: Node)`, druckt **genau eine**
Zeile `[NAME] RESULT: …` und beendet mit passendem Exit-Code. Pro Prüfung eine Zeile mit
den tatsächlichen Werten — ein Fehlschlag muss sagen, **was** kaputt ist, nicht nur dass
etwas kaputt ist.

**Ein Skript fährt alles** und gibt eine Zusammenfassungstabelle plus Exit-Code aus.

> ⚠️ **Das war im ersten Durchlauf der größte Architekturfehler.** Tests wurden anfangs
> als `if/elif`-Kette in das Haupt-Szenenskript geschrieben, plus eine zweite Kette im
> Hauptmenü (damit Tests die Szene automatisch starten). Das Hauptskript wuchs auf
> **1.127 Zeilen**, fast nur Testcode, und jeder neue Test bedeutete zwei Dateien
> anzufassen. **Baue den Datei-Dispatcher ab Tag eins.**

### 7.2 Notwendige Test-Hilfsmittel

- **Zeitraffer-Hebel:** Brutzeit, Tageslänge und Piepsintervalle müssen zur Laufzeit
  überschreibbar sein, sonst dauert ein Test 14 Minuten.
- **Bootstrap-Helfer:** „Nest bauen, N Eier legen, ausbrüten" als eine Funktion. Fast
  jeder Test braucht das.
- **Spione statt Ausgabegeräte:** Ein simpler Zähler (z. B. `_peep_count`) macht Audio
  headless prüfbar.
- **Spielstand-Hygiene:** Jeder Test, der speichern kann, muss die echte Spielstand-Datei
  **byteweise sichern und wiederherstellen**. Sonst zerstören Tests echte Spieldaten.

### 7.3 Sichtprüfung — und warum sie nicht optional ist

**`--headless` rendert nichts.** Logik lässt sich headless prüfen, Aussehen nicht.

Im ersten Durchlauf hieß das: Screenshot-Code ins Projekt schreiben, GUI-Binary starten,
PNG aus dem User-Verzeichnis kopieren. Umständlich genug, dass es zu selten gemacht wurde
— mit direkten Folgen (siehe 8.D.3, 8.G.2).

**Die Lösung, die das umgedreht hat:** Ein MCP-Server, der sich an den *laufenden*
Godot-Editor hängt ([hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)). Damit sind
möglich: Screenshot vom laufenden Spiel, Node-Eigenschaften zur Laufzeit auslesen,
Editor-Log samt Stacktraces lesen, Code im laufenden Spiel auswerten.

> **Empfehlung: Das gehört an den Anfang eines Neubaus, nicht ans Ende.** Mindestens vier
> Bugs wären damit in Minuten statt Stunden gefunden worden. Zwei Hinweise: Die Telemetrie
> des Addons ist standardmäßig an (abschaltbar), und das Plugin trägt sich selbst ein
> Autoload ein, das vor einem echten Export wieder raus muss.

**Und der eigentliche Lerneffekt:** Das Werkzeug wurde zunächst nur zur **Abnahme**
benutzt („sieht ok aus, committen") statt zur **Iteration** (bauen → schauen → nachbessern
→ wieder schauen). Genau daran ist der erste Optik-Durchlauf gescheitert.

---

## 8. Bug-Katalog — die Fallen

Der wertvollste Teil dieses Dokuments. Jeder Eintrag: **Symptom → Ursache → Lösung.**

### A. Godot-Fallen

**A.1 — Kamera schaute in den Himmel**
`Transform3D(float×12)` liest die neun Basis-Zahlen **zeilenweise**. Handgeschriebene
Rotationsmatrizen sind dadurch leicht invertiert.
→ **Nie Matrizen von Hand schreiben. `rotation_degrees` im Code setzen.**

**A.2 — `render_mode billboard` existiert nicht für eigene Shader**
Das ist eine `StandardMaterial3D`-Eigenschaft, kein Shader-Schlüsselwort.
→ Billboarding manuell in `vertex()`: `MODELVIEW_MATRIX` aus den Kamera-Basisvektoren
(`INV_VIEW_MATRIX`) und der eigenen Translation neu zusammensetzen.

**A.3 — Primitiv-Meshes sind auf ihrem Ursprung zentriert**
Sphere/Cylinder/Capsule/Box spannen `-h/2 … +h/2`, **nicht** `0 … h`. Ein Gradient-Shader,
der `VERTEX.y / höhe` rechnet, ist dadurch falsch.
→ Symmetrisch remappen: `(VERTEX.y + halbe_höhe) / (2 * halbe_höhe)`.

**A.4 — `.uid`-Dateien gehören ins Repo**
Godot 4 legt zu jedem Skript/Shader eine `.uid` an. Wird sie vergessen, ist der
Arbeitsbaum dauerhaft „dirty".
→ Nach dem Anlegen neuer Dateien einmal importieren lassen, dann **alles** committen.

### B. Physik & Bewegung

**B.1 — Ente blieb beim Verlassen des Wassers hängen** *(kostete mehrere Anläufe)*
Frontal gegen die Kante: fest. Diagonal in eine Ecke: ging. Klassisches
**Kapsel-gegen-Stufe**-Problem — die gerundete Unterseite erzeugt eine kombinierte
Kollisionsnormale, die **gleichzeitig** Vorwärts- und Aufwärtsbewegung blockiert. Bloßes
Anheben genügt nicht, die Kapsel bleibt an der Stufe gepresst.
→ Vor `move_and_slide()` per `test_move()` prüfen: Ist der Weg horizontal blockiert, wäre
er aber nach einem kleinen Anheben frei? Dann vorher anheben.

> **B.1b — und derselbe Fix fehlte dann bei den Küken.** Sie steuern ihren eigenen
> `CharacterBody3D` und hatten exakt denselben Bug. **Wenn zwei Entitäten dieselbe
> Bewegungsart teilen, teile auch den Fix** — oder prüfe beide.

**B.2 — Ente tauchte unendlich tief**
Tauchen war als konstante Abwärtsgeschwindigkeit umgesetzt.
→ Als **Zieltiefe** modellieren, nicht als Geschwindigkeit. Der Auftrieb federt dann
sauber ein und pendelt sich ein. Echte Enten gründeln ohnehin nur mit dem Vorderteil.

### C. Animation & Eingabe

**C.1 — Tauchanimation setzte ständig zurück**
Die Tauchtaste flackerte zwischen gedrückt/losgelassen (vermutlich Ghosting oder
Hintergrundsoftware), was die Animation jedes Mal neu startete.
→ **Entprellen im Input-Layer** mit großzügigem Fenster (500 ms hat gehalten; 150 ms
reichten nicht). In einem unhektischen Spiel ist die Verzögerung unmerklich.

**C.2 — Tauchanimation lief durch statt in der Gründel-Pose zu bleiben**
Erster Versuch: Frame per `seek()` einfrieren — das tötete **alle** Bewegung, auch das
Paddeln der Beine.
→ Durch Frame-für-Frame-Scrubbing herausgefunden: Der Clip ist ein **nahtloser Vollzyklus**,
bei dem die Ente den Großteil der Zeit kopfüber ist. Lösung: den ganzen Clip nativ loopen
lassen (`Animation.LOOP_LINEAR`). Nahtlos, und alles bleibt in Bewegung.
→ **Verallgemeinerung: Erst den Clip verstehen, dann eingreifen.** Ein Scrubbing-Werkzeug
zu bauen war schneller als weiter zu raten.

**C.3 — Laufanimation war hakelig**
Der prozedurale Watschel-Hüpfer aus der Graybox-Zeit lief **zusätzlich** zur echten
Laufanimation — zwei unsynchronisierte Schwingungen auf demselben Node.
→ Prozedurale Bewegung überspringen, sobald ein echter Animator montiert ist.

### D. Material & Rendering

**D.1 — Modelle waren grau statt bunt**
Viele Low-Poly-Modelle speichern Farbe in **Vertex-Farben**, nicht in Texturen. Godot
zeigt die per Default nicht an. *(Genau hier entstand die Scraping-Anfrage — die Textur
fehlte nicht, sie existierte nie.)*
→ `vertex_color_use_as_albedo = true` **und** `vertex_color_is_srgb = true` (ohne das
zweite Flag bleicht alles aus). Dazu `metallic = 0`, `roughness = 1`, sonst spiegelt der
blaue Himmel auf hellen Flächen und die Küken wirken blaustichig.

**D.2 — Fortschrittsbalken füllte sich nie** *(ein Bug, der bis zum Spieler durchkam)*
Das pro Instanz duplizierte Material wurde per `set_surface_override_material()` gesetzt —
aber die Szene wies das Material über `material_override` zu, **und das hat Vorrang**. Der
Renderer zeigte weiter das geteilte Original, dessen Wert nie aktualisiert wurde.
→ Duplikat auf **dieselbe** Property zurückschreiben.
→ **Lehre:** Der Test prüfte vorher nur, dass Werte gesetzt wurden. Ein Test muss den
Parameter **an dem Material auslesen, das wirklich gerendert wird.**

**D.3 — Der ganze Park sah aus wie „Grauwürfel mit Farbe drauf"**
Reine `StandardMaterial3D`-Vollfarbe auf jeder Form. Keine Licht-/Schattenvariation, keine
Bewegung.
→ Drei kleine eigene Shader haben das gedreht — billig, ohne ein einziges externes Asset:
  1. **Laub:** vertikaler Farbverlauf (unten dunkler, oben heller — eine
     Ambient-Occlusion-Annäherung ohne Textur) plus leichtes Windwiegen, das per `t²` nur
     den oberen Teil bewegt, damit Stamm und Halm verwurzelt wirken. Die Phase an die
     Weltposition koppeln, sonst wackeln alle Pflanzen im Gleichtakt.
  2. **Boden:** zweifarbiges Wertrauschen aus der Weltposition. Der Boden ist die größte
     Fläche im Bild — eine einheitliche Farbe dort trug mehr zum Graybox-Eindruck bei als
     jede einzelne Requisite.
  3. **Wasser:** sanftes Vertex-Kräuseln plus Fresnel-Aufhellung am Rand, damit der Teich
     nach Wasser aussieht statt nach getöntem Glas über einem Loch im Rasen.
→ Außerdem: **HSV- statt RGB-Jitter** für Farbvarianz. Unabhängiges Kanalrauschen
verschiebt den Farbton unvorhersehbar und wirkt schmutzig; Farbton + Helligkeit variieren
bei konstanter Sättigung wirkt natürlich.
→ Und: **chunkigere Proportionen.** Kürzere, dickere Bäume mit volleren, stärker
überlappenden Kronen lesen sich „storybook"; botanisch korrekte Proportionen wirken karg.

### E. GDScript-Fallen

**E.1 — Lambdas fangen lokale Variablen per Wert**
Ein `int`-Zähler, der in einer Signal-Lambda hochgezählt wird, bleibt draußen bei 0 — still,
ohne Fehler.
→ In ein einelementiges Array packen (`var count := [0]`), das ist eine Referenz.

**E.2 — Doppelter Variablenname im selben Scope**
Ein Parse-Fehler, der erst zur Laufzeit auffällt und die Szene komplett nicht laden lässt.
→ Nach dem Anlegen neuer Skripte immer einmal importieren lassen.

**E.3 — `monitoring` lässt sich im eigenen Signal-Callback nicht setzen**
Godot blockiert das („Function blocked during in/out signal"), der Aufruf **verpufft
still**. Ein aufgesammeltes Item blieb dadurch unsichtbar weiter aktiv.
→ `set_deferred("monitoring", false)`. Zusätzlich ein **eigenes Bool-Flag** als
maßgebliche Quelle führen, das sofort wirkt.

### F. Test-Fallen

**F.1 — Autosave überschrieb den Spielstand, den ein anderer Test brauchte**
Fast jeder Test baut ein Nest, das löst Autosave aus. Der Lade-Test bekam dadurch fremde
Daten.
→ Reihenfolge im Testrunner festschreiben **und kommentieren, warum**.

**F.2 — Wiederholtes Füttern in einer Schleife fütterte nur einmal**
Nach der ersten Fütterung fiel der Hunger unter die Schwelle, die Interaktion war ab da
ein No-Op. Der Test „fütterte" zehnmal und wunderte sich.
→ Zustand zwischen den Schritten explizit zurücksetzen.

**F.3 — Ein Test schlug fehl, weil der *Test* falsch war, nicht der Code** *(zweimal)*
Einmal wurde Zustand aus einem früheren Testabschnitt übernommen, einmal ein Szenario per
Teleport erzeugt, das im echten Spiel gar nicht entstehen kann.
→ **Bevor man den Code „repariert": prüfen, ob die Situation real erreichbar ist.** Beide
Male war der Produktionscode korrekt.

**F.4 — Ein Test verließ sich auf einen Bug**
Der Respawn-Test funktionierte nur, weil `monitoring` (E.3) still fehlschlug. Nach dem Fix
sammelte die danebenstehende Ente das Objekt sofort wieder ein.
→ Beim Beheben eines latenten Bugs prüfen, welche Tests sich darauf verließen.

### G. Design-Fallen

**G.1 — Küken erstarrten nachts überall, statt heimzukehren**
„Warm" (= nah bei der Mutter) genügte allein zum Einschlafen — unabhängig vom Ort. Da
Küken tagsüber ohnehin fast immer dicht bei der Mutter laufen, löste das bei Einbruch der
Nacht **sofort** aus, mitten im Feld. Der Heimweg wurde dadurch bedeutungslos.
→ Einschlafen verlangt **warm UND tatsächlich am Nest**. Der bewusste Schlaflied-Ruf hatte
diese Ortsbedingung längst; die passive Variante hatte sie nie bekommen.
→ **Verallgemeinerung: Wenn es zwei Wege zu demselben Ergebnis gibt, müssen beide
dieselben Bedingungen erfüllen.** Solche Inkonsistenzen sind eine ergiebige Bug-Quelle.

**G.2 — Der Reiher sah aus wie ein Duschkopf**
Der Hals war nach `-Z` geneigt, Kopf und Schnabel standen aber auf fest verdrahteten
`+Z`-Koordinaten — auf der Gegenseite. Sie hingen nicht am Halsende, sondern schwebten
dahinter. Aus Spielerperspektive blieb eine senkrechte Säule mit einer Kugel obendrauf.
→ Bei aus Code zusammengesetzten Figuren: **alle Teile auf derselben Achsenseite**
platzieren. Und: Kleine dunkle Augenpunkte machen aus einer Kugel einen Kopf — der
billigste Lesbarkeits-Trick überhaupt.

**G.3 — Schlaflied hatte kein Ende**
Eingeschläferte Küken wären bis zum nächsten Ruf festgenagelt gewesen.
→ Sie stehen auf, sobald die Mutter weggeht — wortlos und ohne Timer, den der Spieler
lernen muss.

**G.4 — Handplatzierte Objekte umgingen die Sperrzonen**
Zwei Parkbänke wurden von Hand gesetzt und landeten zu nah an Nest und Spawn, weil nur der
automatische Streuvorgang gegen die Sperrzonen prüfte.
→ Auch handplatzierte Objekte durch dieselbe Prüfung schicken (Wunschort als Anker, bei
Konflikt in der Nähe einen freien Platz suchen). Robuster als 40 Koordinaten von Hand
nachzurechnen.

**G.5 — Ein Baum stand mitten im Bach**
Der Bach ist reine Dekoration ohne eigenen Szenenknoten — stand also in keiner Gruppe und
wurde vom gruppenbasierten Sperrzonen-Scan (6.2) nicht erfasst.
→ Rein dekorative Flächen brauchen eine **explizite** Sperrzone. Wo ein Muster eine
Ausnahme hat, ist die Ausnahme der Bug.

**G.6 — Nebendatei überlebte „Neues Spiel"**
Angefreundete Tiere wurden vorübergehend in eine eigene JSON-Datei geschrieben (weil die
Spielstand-Dateien gerade gesperrt waren). Die lag außerhalb des Spielstands, wurde also
beim Zurücksetzen nicht gelöscht — eine neue Familie hätte die zahmen Tiere der alten
vorgefunden.
→ **Aller Fortschritt gehört in den einen Spielstand.** Wenn ein Umweg nötig ist, muss er
sofort danach aufgelöst werden.

---

## 9. Was ich beim Neubau anders machen würde

### 9.1 Test-Dispatcher ab Tag eins
Siehe 7.1. Der größte einzelne Architekturfehler des ersten Durchlaufs.

### 9.2 Optik-Werkzeuge vor Optik-Arbeit
Den MCP-Editor-Anschluss (7.3) **zuerst** einrichten und dann **iterativ** benutzen. Der
Ablauf „bauen → anschauen → nachbessern → wieder anschauen" ist das, was die Dekoration im
zweiten Anlauf gerettet hat. Beim ersten Anlauf wurde nur einmal gebaut und abgenommen.

### 9.3 Asset-Frage bewusst entscheiden
Die Umgebung wurde aus Primitiven gebaut, **weil nichts anderes da war** — nicht, weil es
so gefordert war. Die drei Shader (8.D.3) holen daraus erstaunlich viel heraus, aber ein
CC0-Naturpack (Quaternius, Kenney) würde den Park in einem Bruchteil der Zeit besser
aussehen lassen. **Das sollte am Anfang entschieden werden**, nicht implizit durch
Untätigkeit. Eine Bedingung bleibt: kein Scrapen fremder Webinhalte (3.4).

### 9.4 Shader früh, nicht als Politur
Laub-Gradient, Boden-Rauschen und Wasser-Fresnel sind zusammen keine 100 Zeilen und setzen
den gesamten Ton. Sie gehören in den ersten Weltaufbau, nicht in einen Nachzügler-Durchgang.

### 9.5 Die vier Design-Regeln als Prüfliste behandeln
Die Regeln aus Abschnitt 3 sind mehrfach *nach* der Implementierung verletzt worden (G.1,
und beinahe mehrere Balken-Anzeigen). Bei jedem neuen Feature explizit durchgehen.

### 9.6 Parallele Arbeit ist möglich — mit strikter Dateizuständigkeit
Drei Features wurden gleichzeitig von getrennten Agenten gebaut. Was es funktionieren ließ:
- **Exklusive Dateizuständigkeit** je Agent, plus ausdrückliche Liste eingefrorener Dateien.
- **Signale vorab deklarieren**, damit niemand den gemeinsamen Signal-Hub anfassen muss.
- **Leere Platzhalter-Knoten** in der Weltszene vorbereiten, damit Features rein im Code
  entstehen können.
- **Kein Feature gilt als fertig, bevor die gesamte Suite grün ist.**
- Wer ohne eine gesperrte Datei nicht weiterkommt, **meldet das, statt sie anzufassen.**

Das hat funktioniert; genau dieser letzte Punkt hat allerdings den Umweg aus G.6 erzeugt,
der hinterher aufgeräumt werden musste. Einplanen: Nach paralleler Arbeit braucht es eine
Integrationsrunde.

---

## 10. Startreihenfolge für den Neubau

Vorschlag, der die Erkenntnisse oben berücksichtigt:

1. **Projektgerüst + Test-Dispatcher + Testrunner-Skript.** Vor dem ersten Feature.
2. **Editor-Anschluss für Sichtprüfung** einrichten.
3. **Welt mit Shadern:** Boden, Teich, Beleuchtung — gleich mit den drei Shadern.
4. **Entenmutter:** Bewegung, Kamera, Wasser (inkl. Stufen-Hilfe aus B.1 **von Anfang an**).
5. **Nest → Eier → Küken → Füttern**, also die Kernschleife aus Abschnitt 4.
6. **Wachstum + nestgebundene Phase + Folgeverhalten.**
7. **Lernen durch Nachahmung** (5.3) — das Herzstück, mit neutralem Signalnamen.
8. **Persönlichkeiten + Namensgebung** (5.4).
9. **Quak-Grammatik** (5.2), **Gründeln** (5.5).
10. **Tag/Nacht + Wärme** (5.6), **Fundstücke** (5.7), **Nachbarn** (5.8).
11. **Dekoration** (5.9) — iterativ mit Screenshots.
12. **Generationen-Kreis** (5.10) — das Finale, das im ersten Durchlauf nie kam.

Schritte 4–6 bilden das erste spielbare Spiel. Schritt 7 ist der Punkt, an dem es
**dieses** Spiel wird und nicht irgendein Sammel-Spiel.

---

## 11. Offene Punkte

- **Audio:** Es existieren nur prozedural erzeugte Platzhalter-Klänge. Die Aufruf-Hooks
  sind vollständig verdrahtet, echte Klänge fehlen.
- **Balance ungeprüft im echten Spielfluss:** Lernschwellen, Anfreunde-Tempo der Nachbarn
  und Wachstumsquoten sind geschätzt und nur im Zeitraffer getestet.
- **Beleuchtungsverlauf über einen ganzen Tag** wurde nie mit menschlichen Augen über
  einen vollständigen Zyklus begutachtet.
- **Steam-Export:** nie versucht. Export-Presets sind bewusst nicht eingecheckt
  (Keystore-Risiko).
