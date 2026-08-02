# 201 — The shape of a tool call

## Current behavior

**Done, and tested** — `src/064` is the boundary, `src/065` checks it, 27 of
27 on 2026-08-02, including a live exchange on the real assembly engine.

The door and the catalogue are one object. The table the answering walks to
find a hand is the same table the machine reads to find out what its hands
are, and a hand offered later — including by something the machine built —
appears in it immediately. That answers `docs/002`'s open question about
whether a program can widen the door from inside: it can.

The call format is not chosen here. The recogniser is a swappable grammar
object and nothing above it assumes one, proven by running the same hands
under a second grammar and requiring the first grammar's calls to mean
nothing to it. The default is deliberately ordinary — `<call name argument>`
answered `<result name ...>` — in characters any vocabulary can say.

Every refusal is a sentence the machine can read and act on: unparsed, no
such hand, wrong argument count, a dangerous hand still closed, a hand that
could not do it, and a hand that came apart entirely. No hand moves in any
of those cases, and a hand that raises is caught rather than allowed to take
the thought down with it.

The loop (`061`) gained `converse`: thinking stops at a completed asking,
the hand moves, the answer joins the context as its own atom, and thinking
resumes. Two properties that came out of building it and are now tested:

- **A call in a request moves nothing.** Only the machine's own speech is
  scanned. Otherwise anything that talks to the machine reaches through it
  to its hands, which is a different machine than this one.
- **An exchange is bounded and says when the bound is reached**, because a
  machine stopped by a limit it cannot see looks like one that gave up.

Large answers go to the reader (`201a`) or are refused with both numbers
named — never truncated.

Still open, and belonging to the tickets that own the hands that can hang:
a call that never returns. Nothing here can hang; `205` is where that starts
being possible and where giving up on one is designed.

## Intended behavior

The model can ask for an action and receive a result, through a form the engine
recognises in the token stream and answers. This is the boundary between thinking
and doing, and everything in phase 2 hangs off the shape chosen here.

## Suggested implementation steps

1. **Do not choose the call format here.** How a call is written and recognised
   depends on the model, and the model is not chosen by this project (`101`) — it
   is a parameter of the build. Reserved tokens are ruled out for the same reason:
   an arbitrary model was not trained with tokens we invented. Beyond that, treat
   the specifics as arbitrary and settle them at implementation time against
   whichever model is in front of you.
2. Build the parser as a swappable part, and test it per model rather than once.
   It is one of the few places where changing the model can break the machine
   while everything else keeps working.
3. Decide what happens on a malformed call. The rule in this project is that
   errors beat fallbacks: a call that does not parse should come back saying it
   did not parse, in a form the model can read and correct, rather than being
   guessed at.
4. Define how results return. Small ones come back as text. Large ones go through
   `201a`, which searches them in a scratch context so that only the useful part
   ever reaches the machine's own.
5. Define how a call that does not return is survived. Some of these hands touch
   hardware, and hardware hangs (`docs/003a`). A call needs a way to be given up
   on, or the first bad probe ends the machine.
5. Keep the list of available calls readable **by the model**. It should be able
   to ask what its hands are rather than being told once at the start and having
   to remember. This is the same object the grown machine's operation table
   becomes — the door and the catalogue in one (`docs/002`).

## Blocks

Everything else in phase 2.

## Blocked by

`105`.

## Related documents

`docs/002-datapath-the-interpreter.md` — the door and the catalogue as one
object.
