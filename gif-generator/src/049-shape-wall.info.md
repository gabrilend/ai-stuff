# 049-shape-wall — every mistake in a shape scene, at once

The 2D score's wall, for 3D scenes (issue 701c). A scene is walked from
the top: each word is looked up in the list for where it stands
(`048-shape-words.lua`), each name it gives (a hue, a shape, a style, a
motion, an effect, a solid, a tag) in the vocabulary it names, each value
against its word's rules (whole cycles, 0 to 1, exactly four points,
...), each needed word is asked for, and the rules that tie words
together (`CROSS`: a rolling shape needs a route, only a superball
morphs, ...) are applied. A miss does not stop the walk, so an author
fixes one film's worth of mistakes per attempt. Every miss says where it
is, and a misspelling the nearest legal word:

    scene.instances[2] (hammer).motion: no word 'cycels' in a swing motion -- nearest legal: cycles
    scene.instances[1] (bloom).spin.turns: must be a whole number, or the loop has a seam
    scene.beams[1].from: nothing is tagged 'bloon' -- nearest tag: bloom

## Usable surface

- **vocabulary(hues, meshes, choreography) → vocab** — the names a scene
  may give, from the colour table handed to `choreography.load`, the
  cabinet's `names()` and `choreography.vocabulary()`. Errors if the word
  lists and the code name different motions or shapes.
- **check(scene, vocab) → { line, ... }** — every problem, in the order
  met; empty when the scene speaks only legal words.
- **require(scene, vocab)** — errors with every problem in one message,
  "N problems, all at once".

`choreography.load` calls `require` before it reads anything, so every
film and every test that loads a scene is behind the wall, and load
itself only builds. A needed word that a misspelling was already pointed
at is not asked for a second time.
