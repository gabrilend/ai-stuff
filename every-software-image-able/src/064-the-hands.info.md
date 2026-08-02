# 064, 065 — the hands, and asking for something — info

The boundary between thinking and doing: the catalogue of what the machine
may ask for, the recogniser that finds an asking in the token stream, and
the answering. Issue `201`; everything else in phase 2 hangs off the shape
here.

## Running the checks

```
luajit src/065-test-the-hands.lua
```

## What `064` exports

| Name | Meaning |
|---|---|
| `GRAMMARS` | how a call is written, per model — swappable, `plain` by default |
| `new(options)` | a catalogue: grammar, answer budget, optional reader (`201a`) |
| `offer(catalogue, hand)` | adds a hand — name, takes, gives, does, optionally dangerous |
| `offer_the_catalogue(catalogue)` | the one hand every machine has: asking what its hands are |
| `catalogue_text(catalogue)` | what the machine reads when it asks |
| `find(catalogue, text)` | the first asking in a stretch of text, or nil |
| `answer(catalogue, call)` | carries one out; returns ok, text, and whether it was read |
| `answer_text(catalogue, call)` | the same, written the way the grammar writes answers |
| `open(catalogue, name, confirmation)` | opens a dangerous hand; confirming is read-only |

The loop (`061`) gains `hands` and `converse`: thinking stops at a completed
asking, the hand moves, the answer joins the context as its own atom, and
thinking resumes.

## The door and the catalogue are one object

The table the answering walks to find a hand is the same table the machine
reads to find out what its hands are (`docs/002`). There is no privilege
level here and no second list that could drift. A hand offered later — by
something the machine built — appears in the catalogue immediately, which is
this project's answer to that document's open question about whether a
program can widen the door from inside: it can.

## The call format is not chosen here

How a call is written depends on the model, and the model is a parameter of
the build (`101`). Reserved tokens are ruled out for the same reason: an
arbitrary model was not trained with tokens somebody invented. So the
recogniser is a swappable grammar object and nothing above it assumes one —
`065` proves that by running the same hands under a second grammar and
checking the first grammar's calls mean nothing to it.

`plain` is the default and deliberately ordinary: `<call name argument>`,
answered `<result name ... >`, in characters any vocabulary can say.

## Every refusal is a sentence

A call that does not parse, names no hand, miscounts its arguments, asks for
a dangerous hand, fails inside, or comes apart entirely — each comes back as
words the machine can read and act on, and no hand moves. Errors beat
fallbacks: a guessed call is a hand moving somewhere nobody asked it to.

A hand that raises is caught rather than allowed to take the thought down
with it.

## Two properties worth keeping

**A call in a request moves nothing.** Only the machine's own speech is
scanned. Otherwise anything that talks to the machine could reach through it
to its hands, which is a different machine than the one being built.

**An exchange is bounded, and says when the bound is reached.** A machine can
ask for the same thing forever; `converse` stops after `max_calls` and adds
an atom saying so, because a machine stopped by a limit it cannot see looks
like a machine that gave up.

## An answer too large to hold

Answers longer than the budget go to the reader (`201a`), which searches
them elsewhere so only the useful part crosses. With no reader they are
refused with both numbers named — never truncated, since a truncated answer
presented as whole is a lie the machine tells itself.

## Result on 2026-08-02

27 of 27, including a live exchange: a real thinking machine on the assembly
engine, stopped mid-thought at its own asking, its hand moved, the answer
landing as an atom before another token was drawn.
