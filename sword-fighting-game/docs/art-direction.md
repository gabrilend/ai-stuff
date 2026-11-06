# Art direction

## Claymation figures in brick armor

The look the vision asks for is Gumby-style claymation with Lego armor and
swords. Translated into what the renderer builds:

- **Bodies are clay.** Rounded, slightly lumpy shapes: a body is a stack of
  squashed spheres and tapered tubes, never a box. The surface is lit softly
  (a wide wrap-around light, no hard highlights) and carries a faint
  thumbprint pattern, a low-frequency wobble in brightness computed from the
  surface position, so it reads as something pressed by hand.
- **Armor and swords are bricks.** Hard, glossy, square-edged, with studs on
  top surfaces. Armor plates are boxes clipped onto the clay; a thicker armor
  rating means more and larger bricks. Swords are a flat blade box, a
  crossguard bar and a round pommel stud.
- **Faces are two dots and a line.** Every soldier has the same simple face,
  pressed into the clay. Team colour is on the bricks, not the clay.
- **No interface.** No health bars, no crosshair, no numbers in first person.
  A wounded soldier is dented and slumps; a fatigued one sags and breathes;
  awareness of the sides is warmth and chill at the screen edges.

## Pareidolia for cats

The vision asks to "intentionally give pareidolia to cats". The scenery
hides cat faces in ordinary things, for a cat watching the screen and for a
person who notices:

- clusters of field stones arranged as two eyes and a nose, with grass-tuft
  whiskers;
- shields whose rivets fall in a cat-face pattern;
- cloud shapes with two ears.

Each is placed by the scenery builder from the battle's seed, so the same
battle always has the same faces in the same places. They never carry
gameplay.

## Modding the look

Colours, sizes, and the clay/brick parameters are configuration knobs and
catalogue fields, not constants in the renderer, so a different art style is
a data change. A future step (phase 6) loads alternative mesh builders from a
mod folder.
