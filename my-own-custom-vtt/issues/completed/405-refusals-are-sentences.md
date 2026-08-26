# 405 -- Refusals are sentences

**Phase:** 4, people connect
**Blocked by:** [403](403-the-wire-format.md)
**Blocks:** [406](406-commands-run-a-gauntlet.md)
**Documents:** [commands enter through one door](../../docs/010-commands-enter-through-one-door.md)

## Current behaviour

`refusal_sentence()` in `051-commandlog.c` returns text for four reasons. Nothing
sends it anywhere, because there is nobody to send it to.

## Intended behaviour

Every refused command comes back to the participant as **text a person can read**:
what was refused, and what would have been required.

Never a silent drop. Never a numeric code. Never a command that appears to work
and quietly does not.

### This is not politeness

**Nobody reads a rules screen.** The refusal is where a person finds out that
their character cannot see round that corner, that this goblin belongs to the
forest and not to them, that the door is barred.

If the refusal is silence, the only way to learn the rules is to be told them by
somebody who already knows -- and the program has failed at the one moment it was
in a position to teach.

### What a refusal carries

| Field | Why |
| --- | --- |
| Which command | So a client can tie it to what somebody pressed. |
| The sentence | The whole point. |
| What would have been required | Where it is knowable. "That is thirty feet away and you can reach ten" teaches; "out of range" does not. |

### Where refusals are not sent

**Gate 1 of the decoder** -- an unknown opcode, a flag chain past its limit -- does
not refuse in words. It closes the socket. There is nobody honest on the other end
to explain anything to, and composing a sentence for a sender who is not speaking
the language is work done for an attacker.

Everything past decoding refuses in words.

### The refused-command log is evidence

Every refusal is already recorded with its reason. A session's refusals are the
most direct evidence available about where an interface confuses people -- and
worth reporting in the phase demo, because a list of what everybody *tried* is
more useful than a list of what worked.

## Suggested implementation steps

1. Add the refusal message to the wire format.
2. Extend the refusal table as the gauntlet grows, so every gate has a sentence
   from the day it exists rather than a number that gets one later.
3. Carry the "what would have been required" field where it is knowable, and
   leave it empty rather than filling it with something vague where it is not.
4. Make the demo show refusals, including one deliberately provoked.
5. Write the companion `.info.md`.
6. Test that every refusal reason in the table has a non-empty sentence. A reason
   with no sentence is a silent drop wearing a number.
