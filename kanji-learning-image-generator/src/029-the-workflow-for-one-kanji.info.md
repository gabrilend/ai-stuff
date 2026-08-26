# 029-the-workflow-for-one-kanji — info

The actual pipeline: which boxes, wired how.

For a general: `028` knows how to describe a graph. This says what graph. It is the recipe -- load a model, turn the sentence into something the model understands, load the grey picture that hides the character, bias every step of the drawing towards it, draw, and lay the stroke-order arrows on top.

`docs/005` has the diagram and the reasoning. This is that, built.

*Lifted from this file's own comments by `034-the-companion-pages`. To
change this page, change the comments in `029-the-workflow-for-one-kanji.lua` and
run the sweep again.*

## What it offers

| | |
|---|---|
| `M.seed_for(record)` | The starting noise for a character, taken from the character itself. |
| `M.build(record, made, settings)` | The graph for one character. |
| `M.assumptions(settings)` | What this workflow takes on faith, said out loud. |

### `M.seed_for(record)`

The starting noise for a character, taken from the character itself.

Not from a clock. A given character regenerates identically, and two runs over the whole set differ only where the code changed -- without which, comparing six thousand pictures against six thousand pictures is impossible and every change looks like it changed everything.

Multiplied by a large odd number so that neighbouring characters, whose numbers differ by one, do not get neighbouring noise.

### `M.build(record, made, settings)`

The graph for one character.

`made` names the files this character's pictures were written as, relative to the folder the picture program reads its inputs from.

### `M.assumptions(settings)`

What this workflow takes on faith, said out loud.

There is no picture program on this machine. The model and the control net are names that have to match some other installation's model folder, and nothing here can look. Stating the assumption is the whole of what can be done about it, so it is done rather than skipped.

## Where it sits

Used by `030-make-one-kanji`, `031-make-them-all`, `035-test-the-machine`.
