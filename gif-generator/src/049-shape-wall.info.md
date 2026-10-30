# 049-shape-wall — every mistake in a shape scene, at once

The 2D score's wall, for 3D scenes (issue 701c). A scene is walked from
the top: each word is looked up in the list for where it stands
(`048-shape-words.lua`), and each name it gives (a hue, a shape, a style,
a motion, an effect, a solid, a tag) in the vocabulary it names. A miss
does not stop the walk, so an author fixes one film's worth of mistakes
per attempt. Every miss says where it is and the nearest legal word:

    scene.instances[2] (hammer).motion: no word 'cycels' in a swing motion -- nearest legal: cycles
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
film and every test that loads a scene is behind the wall. The wall
checks words and names; whole-number and range rules are still
choreography's own, first error only.
