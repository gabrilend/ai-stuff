# The shot list — format

The shot list is the score of the film: everything the painter, animator and
editor need, and nothing they must guess. The writers' room writes it; a
person may write or edit it by hand, and that is the main way to iterate.

It is a Lua file read inside a sandbox that offers only the vocabulary below
(the same approach as the gif generator's scores). Reading it top to bottom
is watching the film in order.

## Example

```lua
film{ title = "daily report log MNL", size = {768, 432}, fps = 12,
      sound = "input/hum.ogg", seed = 4401 }

cast{ name = "officer", look = "tired imperial officer, grey uniform, " ..
      "short dark hair, mid-forties, fluorescent light", seed = 77 }

place{ name = "corridor", look = "endless curved grey corridor, " ..
       "white strip lights, no windows, severance office aesthetic" }

shot{ id = "s01", at = 0.0, lasts = 4.5, cut = "beat",
      sees = "officer walks alone down the corridor",
      cast = {"officer"}, place = "corridor",
      motion = push_in{ amount = 0.15 } }

shot{ id = "s02", at = 4.5, lasts = 3.0,
      sees = "a red sun seen through a viewport, too close",
      motion = drift{ strength = 0.25 } }

shot{ id = "s03", at = 7.5, lasts = 5.0, by = "gif",
      sees = "the vision: rings of light collapsing inward",
      score = "assets/scores/vision-collapse.lua" }

monologue{ id = "m01", at = 12.5, speaker = "officer",
           audio = "input/report.wav",
           says = "today I had the strangest sith vision",
           cutaways = { { at = 2.0, lasts = 3.0, sees = "a dark figure in a reactor" } } }
```

## Vocabulary

- `film{}` — once, first. Picture size, frames per second, the sound under
  the whole film, the base seed.
- `cast{}` — a recurring person. `voice` (string, optional) names the
  speech-engine voice their monologues are synthesised with. `look` is added to the prompt of every shot
  they appear in; their `seed` is used for their shots, which is the first
  of the tools for keeping a face the same (the others are control images
  and, if installed, ip-adapter).
- `place{}` — a recurring location, added to the prompt the same way.
- `shot{}` — one clip. `id` (string, unique), `at` and `lasts` (seconds,
  number), `sees` (string: the picture), optional `cast` (list of names),
  `place` (name), `motion` (one of the motions below), `by` (`"diffusion"`
  default, or `"gif"` with a `score` file for the gif generator), `cut`
  (`"beat"` to snap the start to the nearest beat-sheet onset).
- `monologue{}` — a speaking turn; see datapath-monologue.md.

## Motions (the closed set)

| motion | fields | what it does |
|---|---|---|
| `still{}` | — | the keyframe held |
| `push_in{amount}` | 0–1 | slow zoom toward the centre |
| `pull_out{amount}` | 0–1 | slow zoom away |
| `pan{dir, amount}` | left/right/up/down | the frame slides across a wider keyframe |
| `drift{strength}` | 0–1 | chained image-to-image repaints; the picture breathes |
| `dissolve{to}` | a second `sees` | two keyframes, crossfaded |

Anything outside the set is an error naming the unknown word and listing
the known ones. New motions are added by issue, not improvised.

## Why a Lua file

It is readable by a person, writable by a language model (which knows Lua),
and executable without a parser of our own. The sandbox means a written
shot list can call nothing but the vocabulary.
