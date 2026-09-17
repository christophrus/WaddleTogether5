# Modelle einbinden (Drop-in)

Die Spielfiguren laufen aktuell mit **Graybox-Primitiven**. Ein echtes Modell wird
automatisch geladen und ersetzt die Primitive — ohne Code-Änderung.

## So geht's

1. Lege dein Modell hier ab, exakt so benannt:
   - Entenmutter: `assets/models/duck_mother.glb`
   - Küken: `assets/models/duckling.glb`
   (`.glb`/`.gltf` werden von Godot automatisch importiert. Alternativ eine `.tscn` und
   im Inspector von `duck_mother.tscn` / `duckling.tscn` unter **Visual → Visual Scene** zuweisen.)
2. Projekt in Godot öffnen, damit importiert wird.
3. Falls Größe/Ausrichtung nicht passen: im Inspector der jeweiligen Szene
   **Visual → Visual Scale** und **Visual Yaw Offset Deg** anpassen
   (das Modell sollte nach **+Z** blicken; die Figur watschelt in Laufrichtung).

Das Modell wird unter dem `Model`-Node montiert und erbt damit automatisch Drehung und
Watschel-Wippen. Fehlt die Datei, bleibt die Graybox als Fallback — nichts bricht.

**Farben:** Viele Low-Poly-Modelle (z. B. von Quaternius) speichern ihre Farbe als
**Vertex-Farben** statt als Textur. Godot zeigt die per Default nicht an. Dafür gibt es das
Flag **Visual → Use Vertex Colors** (im Inspector der Figur) — ist für die aktuellen Modelle
aktiv. Alternativ eine feste Farbe über **Visual Tint**. Tools: `tools/inspect_mesh.gd`
(Materialien/Clips) und `tools/extract_glb_textures.py` (eingebettete Bilder prüfen/auslesen).

## Kostenlose Quellen (CC0 / frei nutzbar)

- **Quaternius** — quaternius.com — CC0, animierte Low-Poly-Tierpacks (u. a. Vögel/Enten).
  Ideal, weil komplett gemeinfrei (keine Namensnennung nötig).
- **Poly Pizza** — poly.pizza — viele Low-Poly-Modelle; nach „duck" suchen. Lizenz je Modell
  prüfen (oft CC0 oder CC-BY = Namensnennung nötig).
- **Kenney** — kenney.nl — CC0 Asset-Packs („Animated Characters", „Nature Kit").
- **Sketchfab** — sketchfab.com — auf „Downloadable" + Lizenz CC0/CC-BY filtern.

Bei **CC-BY** die geforderte Namensnennung in einer `CREDITS.md` ergänzen.

## Animationen (optional, später)

Bringt das Modell einen `AnimationPlayer` mit Clips wie `idle`/`walk`/`swim` mit, können
wir die Zustandsmaschine der Figur damit verdrahten. Sag Bescheid, welche Clips dein Modell
hat, dann baue ich die Anbindung ein.
