# 201 — The shape of a tool call

## Current behavior

The engine produces text. Text does nothing.

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
