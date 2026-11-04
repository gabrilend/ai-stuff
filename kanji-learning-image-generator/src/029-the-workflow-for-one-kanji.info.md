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
| `M.seed_for(record, style)` | The starting noise for a character, taken from the character itself. |
| `M.build_inside(record, made, settings)` | The inside route (`416`): the scene's things only where the strokes are, |
| `M.build_outside(record, made, settings)` | The outside route (`416`): the character painted, and the scene drawn around |
| `M.build(record, made, settings)` | The graph for one character, for the route `made.route` names. |
| `M.build_illusion(record, made, settings)` | The illusion route: the character hidden in the scene's light and dark, |
| `M.assumptions(settings)` | What this workflow takes on faith, said out loud. |

### `M.seed_for(record, style)`

The starting noise for a character, taken from the character itself.

Not from a clock. A given character regenerates identically, and two runs over the whole set differ only where the code changed -- without which, comparing six thousand pictures against six thousand pictures is impossible and every change looks like it changed everything.

Multiplied by a large odd number so that neighbouring characters, whose numbers differ by one, do not get neighbouring noise.

### `M.build_inside(record, made, settings)`

The inside route (`416`): the scene's things only where the strokes are,

and everything else background.

The stroke layer is never drawn. It is a mask, and two sentences are each held to one side of it -- the subjects inside, the word *background* and the empty world outside -- and combined into the one instruction the drawing follows. The character is there only because the things are where the strokes were.

### `M.build_outside(record, made, settings)`

The outside route (`416`): the character painted, and the scene drawn around

it -- "you can't generate images in here".

The inked canvas is encoded and every pixel off the strokes is marked to be drawn afresh; the strokes are held as they are. Then, after drawing, the ink is pasted back over the finished picture through the same mask, because the model's encoder and decoder smudge whatever passes through them and the character is the one thing here that must arrive exactly as painted.

### `M.build(record, made, settings)`

The graph for one character, for the route `made.route` names.

`made` names the files this character's pictures were written as, relative to the folder the picture program reads its inputs from.

A table of routes rather than a chain of tests: a route is a row, and the three never share a branch.

### `M.build_illusion(record, made, settings)`

The illusion route: the character hidden in the scene's light and dark,

through a control net. The original, and still the one for any kitchen that has a control net.

### `M.assumptions(settings)`

What this workflow takes on faith, said out loud.

There is no picture program on this machine. The model and the control net are names that have to match some other installation's model folder, and nothing here can look. Stating the assumption is the whole of what can be done about it, so it is done rather than skipped. {{{ M.shape_warning(width, height) Whether this picture is a shape the far end was never trained on.

Diffusion models learn on images of roughly one aspect and go strange well away from it -- repeated subjects, drifting composition. A five-character phrase is five times as wide as it is tall, and that is far outside what any of them have seen. Said out loud rather than prevented, because a long phrase is a legitimate thing to ask for and the result is worth looking at even if it comes out badly.

## Inside

Not reachable from outside the file. Listed because the page is also
what a person reads before opening the source.

| | |
|---|---|
| `size_of(made, wanted)` | The picture is as wide as the field is. A word of two characters is twice |
| `sampler_for(g, record, made, wanted, model, positive, negative, latent, denoise)` | The drawing itself, the same box for every route, so the routes differ only |
| `stroke_mask(g, made)` | The character's strokes as a mask the picture program can use: loaded as a |
| `save(g, record, made, last, last_socket)` |  |

## Where it sits

Used by `030-make-one-kanji`, `031-make-them-all`, `035-test-the-machine`, `044-run-the-pictures`.
