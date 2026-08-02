# 201 — The shape of a tool call

## Current behavior

The engine produces text. Text does nothing.

## Intended behavior

The model can ask for an action and receive a result, through a form the engine
recognises in the token stream and answers. This is the boundary between thinking
and doing, and everything in phase 2 hangs off the shape chosen here.

## Suggested implementation steps

1. Choose how a call is recognised. Parsing structured text out of the stream is
   simple and forgiving of a model that phrases things slightly differently.
   Reserving tokens for it is exact and unambiguous and costs vocabulary. The
   choice decides how often the machine fails to act because it phrased a request
   in a way nothing matched.
2. Decide what happens on a malformed call. The rule in this project is that
   errors beat fallbacks: a call that does not parse should come back saying it
   did not parse, in a form the model can read and correct, rather than being
   guessed at.
3. Define how results return — including large results. A call that reads a
   million bytes of memory cannot put a million bytes into the thinking loop, so
   there has to be a way to hand back a summary and a handle rather than the
   whole thing.
4. Define how a call that does not return is survived. Some of these hands touch
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
