# 025-the-words-the-machine-reads — info

Turns a scene into the two sentences a diffusion model is given: what the picture is, and what it must not be.

For a general: everything upstream decided facts -- this world, these subjects, this object along that line. A diffusion model does not read facts; it reads a sentence. This is the only file in the project that writes English, and keeping it the only one is why `024` is forbidden from building sentences even though it is where all the information is. Rewording the whole project's output should mean editing this file and nothing else, and testing the reasoning should never mean reading prose.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `025-the-words-the-machine-reads.lua` and
run the sweep again.*

## Invocation

```
luajit src/025-the-words-the-machine-reads.lua --chars 休語時川
```

## What it offers

| | |
|---|---|
| `M.token_estimate(text)` |  |
| `M.refusals()` |  |
| `M.positive(scene, settings)` | The scene, as the sentence describing it. |
| `M.prompts(record, store, settings)` | One record, all the way to the two sentences. Or nil and a reason. |

### `M.positive(scene, settings)`

The scene, as the sentence describing it.

Every clause carries a rank, and the sentence is shortened by dropping the lowest-ranked clause until it fits. The ranks are a claim about what a learning image cannot do without.

WHY RANKS AND NOT POSITIONS. The first attempt kept the head and the tail and trimmed the middle, on the reasoning that a text encoder weighs the beginning most and the photographic terms at the end are what stop the model drawing a cartoon. Both true. But when the middle ran out, the next thing to go was whatever sat second from the end of the head -- and for the character meaning *rest*, that was the person. The prompt came back as a tree in a wood, having silently deleted the entire reason this project claims to teach anything.

A colour palette is expendable. An etymology is not. Saying so explicitly is the only way the sentence shortens in the right direction.

  100  the first subject, weighted    92  the second subject    88  the world, in its particular version    80  the photographic tail    72  the third subject    60  the light    50  the objects along the strokes, heaviest first    40  the ground the sound-half became    30  the palette    20  the note that this is an abstract word

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `main(argv)` |  |

## Where it sits

Used by `027-test-the-meaning`, `030-make-one-kanji`, `044-run-the-pictures`.
