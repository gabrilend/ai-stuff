<!-- Made by Claude (Opus 5.5), 2026-10-10, for issue 007 (from words to a model), as the datapath for describing objects in words; updated whenever an issue changes it. -->
# Datapath: from words to a model

A description in plain English, made of relationships and never of
measurements, becomes a 3D model measured in units where a part with no size
sentence is 1 wide.

```
description file (input/descriptions/NAME.txt)
  → sentences: split on full stops and line ends, each keeping its line
  → words: lower case; phrases joined into single words ("on top of" →
      on_top_of); a, an, the dropped (after the phrases that need them,
      like "a third", are joined)
  → declarations read first, so every part's name is known
      ("the drum is a cylinder" names the part "drum")
  → every sentence matched against the sentence shapes (docs/shape-words.md)
      → a statement: { line, type, subject, ... }
      → or a refusal: line, what was not understood, the nearest word or
        part name. All refusals are reported together; nothing is drawn.
  → the solver, three passes, each in dependency order (a part after
    every part it mentions):
      sizes        extents along / across / deep, from the kind's
                   proportions and the size sentences
      directions   which world axis each part's own axis runs along
      places       each part's centre; the first part named that no
                   sentence places sits at the origin
    every default used is listed (what was assumed, not said)
    conflicts (two sentences fixing one thing differently) and circles
    (A depends on B depends on A) are refusals naming both lines
  → the builder: each part's kind becomes triangles around its axis,
    turned and moved into place → a shape record (docs/datapath-cad-viewer.md)
  → output/described/NAME.gltf      the model (generator field says who made it)
    output/described/NAME.report.md every part's numbers, and the defaults
  → optionally the viewer, with pictures filed in development-history/
```

The words and their meanings live in one place: docs/shape-words.md (for
people) and src/012-the-shape-words.lua (for the program). A test keeps
the two equal.
