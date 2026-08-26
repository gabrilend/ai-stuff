# Phase 4 — The Study Tool

**Goal.** The first three phases make a recipe for every character. This makes
pictures out of them, keeps every one ever made, records how good each is, and
lets a bad one be argued with — so the set improves by being used.

It exists because of `notes/041`, which arrived after the first three phases
were finished and reframed what the project is for. Read that first.

## Issues

| | | Status |
|---|---|---|
| `401` | The names the radicals bear | **completed** — two readings, and every piece carries a name as well as a phrase |
| `402` | A phrase is a picture too | **completed** — a word is one record, one picture, and one continuous stroke order |
| `403` | The paintbrush, and the wall around it | **completed** — a closed vocabulary, a wall that names every complaint at once, and a contract with one home |
| `404` | Running the pictures | **completed** — a kitchen inside the project, and pictures that are the characters |
| `405` | The pool that remembers | **completed** — two files per rendering, ratings appended, nothing deleted |
| `406` | Two ways of saying it is good | **completed** — a machine that squints, a gallery that cannot write, and the agreement between them |
| `407` | The quality dial | **completed** — the whole ladder, and the variety cost said before it is paid |
| `409` | The card is also the screen | **completed** — asked of the card what `307` asked of the processor |
| `408` | What a higher tier buys | **completed** — a stroke-order animation, and an encoder checked by decoding it |

`405` is the foundation the last three stand on. `404` is the one that cannot be
finished on this machine alone.

## Where the risk is

**`401` reverses a decision that was argued for carefully**, and the argument
was not wrong — it was answering a different question. The risk is that
reversing it quietly makes `docs/004` a document nobody trusts, so the old
reading is kept as a mode rather than deleted, and the reasoning behind it stays
where it was written.

**`404` is the first thing here that depends on another program existing.**
Everything up to it has been checkable on this machine; a workflow this project
calls correct has still never been opened by the thing it was written for. The
first real submission will find whatever this project has been wrong about since
phase three, all at once.

**`406` is where taste can drift without anything raising an error.** A machine
grader improved against a generator improved against that grader is a loop with
no anchor. The human floor and the agreement rate exist for that, and they only
work if somebody looks at them.

**And the whole phase assumes a person will actually rate things.** The pool,
the dial and the elaboration queue are all downstream of somebody clicking. If
nobody does, this is an apparatus that has made the project larger and no
better.

## Where the tests for this phase live

Not in a file of their own. `401` and `402` are tested in `027`, which is where
everything about turning a character into a scene is tested; `403` through `408`
are in `035`, which is where everything about turning a scene into a file
somebody can run is tested.

That is deliberate. A test file per *phase* would put the paintbrush's wall in a
different file from the scene grammar it overrides, and the animation in a
different file from the picture writer it is the other half of. The phases are
when things were built; the test files follow what they are about.

## What this phase turned up

**Three bugs left the data perfectly correct and made the program read it
wrong**, which is a shape this project had not hit before. A pattern anchored on
the newline before each entry eats it, so the next entry is never seen. `a and b
or c` falls through when b is nil, so a filter for *what a person judged*
quietly became *what anyone judged*. An inline event handler runs in a scope
where nothing the page declared is visible, so buttons could not see what they
were adding to.

**And two checks were wrong about the machine rather than about the code.** The
card was declared unusable because the arithmetic library's list of supported
architectures did not contain this card's exactly — while it sat there working,
because compiled CUDA code runs on any device of the same major version with an
equal or higher minor one. And a phrase list with a typo in it was treated as no
phrase list at all.

The pattern across all five: ask the thing, do not reason about it.
