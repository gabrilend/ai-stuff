# 704 — the porch hears both spaces

Part of phase 7. Builds on 601 (the porch), 701c (the 3D vocabulary) and
701d (one canvas, two spaces). Related: 602 (three readings), 603 (the
spoken vision), the `canvas-and-paintbrush` skill.

## Founding words

Spoken by gabrilend, 2026-10-30, answering whether the studio skill and
`canvas-and-paintbrush` should become one:

> the canvas-and-paintbrush tool is slightly different than the gif
> generator, the canvas-and-paintbrush is for creating the tools of
> creation while the gif generator is one example of creating a tool that
> paints for us based on what we say. However the gif generator is missing
> something crucial which is the local LLM that takes what you say as a
> prompt or whatever and turns it into the proper words that the gif
> generator expects. It should still be written in pseudo-code style
> english, but you say "curve the ball around the circle" and it'd
> translate to "move ball at 90 degrees around circle" or whatever the
> gif-generator needs. The canvas-and-paintbrush is for creating a
> workflow where the user describes a visual need they have, and the
> paintbrushes can create many examples of that. It might be images or
> gifs or some other format we haven't built for yet.

So the two skills stay two (701f, open question 1, answered): one builds
paintbrushes, the other is how to hold this one. And the piece the
paintbrush is missing is the ear.

## Current Behavior

The ear half exists, for half the language. `src/032-porch.lua` (601)
turns prose into a score through a small local model that paints in
tool-calls, inside a grammar generated from the vocabulary tables, with
the wall's errors quoted back for a few retries. It is proven against a
scripted fake model; the live transport waits for the cluster.

But it only knows the 2D words. Its grammar has `canvas` and `stroke`
calls and nothing else, and its prompt is the score format and two
stroke scores. Since 701c and 701d, a score can also speak `camera{}`,
`world{}`, `shape{}` and `pane{}`, and the porch can say none of them.
"Curve the ball around the circle" has no ball to curve.

Nothing shows the person what the model understood, except the score
itself.

## Intended Behavior

- **Plain speech in, the studio's words out.** A person says what they
  see ("curve the ball around the circle", "a gold cube spins slowly
  while a spark chases it"), and the porch writes a score that speaks
  both spaces, the same score a person would have written.
- **The grammar covers both vocabularies, generated, never typed.** The
  3D tool-calls (`shape`, `camera`, `world`, `pane`) come from the same
  word lists the 3D wall checks (`src/048-shape-words.lua`): each
  context's words, their kinds, and the runtime's names (hues, meshes,
  motion kinds, effects). A word added to a list is a word the model may
  say. Strokes gain `pane`, and `tip` may name a shape.
- **The prompt is the truth people read.** The score format (with its
  second-space section), `docs/shape-format.md`, and reference scores
  including a mixed one.
- **What the model heard is said back in plain words.** Each tool-call
  is read back as one pseudo-code English line, written by the porch
  from the call itself, not by the model. For example: *"a violet
  icosahedron circles at radius 2.4, once a loop"*, *"0.5 to 3.5 s: a
  teal comet flies from the gold cube to the violet icosahedron"*. The
  person checks the lines, not the Lua. When a line is wrong, they say
  so in plain words and the porch tries again. The same lines head the
  score as comments.
- **Many examples of one need.** The `canvas-and-paintbrush` shape is a
  person describing a visual need and the brushes making many examples
  of it. Here, that is 602's three readings, now in both spaces: three
  scores from one sentence, filmed small, side by side, each with its
  read-back lines, and the person picks.
- **The wall still argues.** A 3D mistake comes back as the 3D wall
  says it (`shape #1 (ball).motion: no word 'cycels' ... nearest legal:
  cycles`), quoted verbatim, as the 2D mistakes already are.

## Suggested Implementation Steps

1. Generate the 3D tool-calls' grammar from `048-shape-words.lua`: one
   rule per context, a `kind` that picks its motion's words, the
   runtime's names as alternations. Add `pane` to the stroke call and
   let a tip name a shape. Snapshot-test it against the word lists, as
   601's grammar is.
2. Collect the new calls into a raw score (`camera`, `world`, `shapes`,
   `panes`) so `score.write` writes it and `compile.score` judges it
   whole.
3. The read-back: one plain line per call, from a table of sayings per
   call kind and motion kind. Every word list entry has a meaning line
   already, so this can lean on them.
4. Widen the prompt: the shape format, and `tests/two-spaces/mixed.lua`
   or the phase 7 demo's score as the mixed example.
5. Tests against fake models: a canned run of 3D and mixed tool-calls
   collects into a score that compiles and films; a 3D misspelling is
   corrected in two attempts with the 3D wall's words quoted back; the
   read-back of a known score is the expected lines.
6. Then 602 (three readings) and 603 (the spoken vision) cover both
   spaces with no further change, since they take whatever the porch
   writes.

## Open Questions

1. **Is the read-back the "pseudo-code style English" she means, or is
   there a language between speech and score?** Her example turns
   "curve the ball around the circle" into "move ball at 90 degrees
   around circle". Two readings:
   - The score is already that language, and the read-back lines are
     how a person sees it without reading Lua. Nothing new to learn;
     the porch keeps one target.
   - A new middle language of English-like commands ("move ball at 90
     degrees around circle"), which the model writes and a second,
     ordinary translator turns into a score. A person could write it by
     hand, too. It's a third vocabulary to keep closed and in step.
   Built for now: the first, because it adds no language and the
   read-back can become the middle language later if she wants to type
   in it.
2. **Which model, and where?** The porch is written against llama.cpp
   behind one orchestrator door (`input/cluster`). Is that still the
   plan, or does another machine take the ear?
   Nothing here needs the answer until the live transport is wired.

## What Happened

Built 2026-10-30 on top of 701g. `src/033-porch-test.lua` is 35 of 35
(18 before), and `./test-shape-films` still passes whole.

- **The grammar (step 1).** `porch.grammar()` now also has `shape`,
  `camera`, `world` and `pane` calls, generated when it is asked for
  from `048-shape-words.lua`: one rule per context, each motion kind's
  own words after its `"kind"`, and the runtime's hues, meshes, effects
  and solids as choices. `world` takes the scene words a score doesn't
  say elsewhere (`compile.SAID_ELSEWHERE`), and `pane` takes
  `compile.PANE_WORDS`. A stroke may name its `pane`, a tip may name a
  shape's tag, and the canvas takes `frames` and `background`. It is 147
  rules. A word list naming a kind the porch can't say stops the grammar
  with a sentence, rather than leaving the word unsayable.
- **A reader for it.** No model runs here, so `src/058-gbnf.lua` reads
  GBNF and matches text against it. The tests prove the grammar names no
  rule it never defines, says every kind of shape motion, allows a
  mixed reading, and refuses a misspelled hue or motion word. It found a
  real fault on its first run: a choice like `glow | solid | wire`
  written straight after its key let a bare `"solid"` through and kept
  `"style":"solid"` out. Every choice is now held in parentheses.
- **Collecting (step 2).** Shape and pane calls are kept in the order
  spoken, camera and world once each, and each call's prose rides above
  it in the written score. A second camera or world call is refused
  with a sentence saying why, so it is neither dropped nor merged.
- **The read-back (step 3).** `src/059-say-back.lua` says each thing in
  a score as one plain line, written from the calls and not by the
  model: "ball: a violet icosahedron, glowing, circles at radius 2, once
  a loop", "0 to 1 s: a jade point following ball". Each shape and
  camera motion kind has its own saying; a word no saying speaks of is
  still named, as `(also: bob)`. The lines head the written score as
  comments, and `porch.translate` returns them as a third value.
- **The prompt (step 4).** It adds `docs/shape-format.md` and
  `tests/two-spaces/mixed.lua`, and says what each new call is for.
- **Tests (step 5).** A fake model first misspells `cycles` in a shape's
  orbit. The 3D wall's line comes back word for word ("shape #1
  (ball).motion: no word 'cycels' in an orbit motion -- nearest legal:
  cycles"), and the second reading passes. The written score reads
  back, passes the wall again and films a whole loop. The read-back of
  `mixed.lua` is checked line by line.

Not built here:

- The person answering a wrong line in plain words and the porch trying
  again with that answer. `translate` takes a correction only as wall
  errors today; a person's words would go in the same slot, and belong
  with 602's three readings, where the person is already choosing.
- 602 and 603 in both spaces (step 6): they take whatever the porch
  writes, but neither is built yet.
- The live transport, which waits on open question 2.

`033-porch-test.lua` stays outside `./test-shape-films`, as before,
since it needs dkjson from the shared shelf.
