# 406 -- Commands run a gauntlet

**Phase:** 4, people connect
**Blocked by:** [403](403-the-wire-format.md),
[405](405-refusals-are-sentences.md)
**Blocks:** [408](408-the-phase-four-demo.md)
**Documents:** [commands enter through one door](../../docs/010-commands-enter-through-one-door.md)

## Current behaviour

`command_apply()` checks the verb and the subject index. Everything else is
missing because scopes and viewers did not exist.

## Intended behaviour

Every command runs the same checks in the same order, cheapest and most
fundamental first, so that a malformed or malicious message is discarded before
anything expensive touches it.

| # | Gate | What it costs |
| --- | --- | --- |
| 1 | **Well-formed?** Opcode in range, flag chain within its limit, instruction complete. | A comparison. Closes the socket -- these are not user errors. |
| 2 | **Is the scope yours?** The scope's viewer must be the participant this socket belongs to. | **One integer comparison, and it is the load-bearing permission check in the entire system.** |
| 3 | **Is the reference in range?** Every reference slot, against its array's count. | A comparison each. |
| 4 | **Is the subject inside that scope?** List membership, or the region parent walk. | A few reads. |
| 5 | **Does the verb suit the style?** `DRIVE` from an `ORDERED` scope is refused. | A comparison. |
| 6 | **Does the ruleset permit it?** | Whatever a ruleset costs. |

Gates 2, 4, and 5 need scopes and are **stubbed permissively in this phase** with
the checks written in place. Gate 6 needs a ruleset and is an empty function.

Writing them now, in order, with the later ones stubbed, is the point: inserting
a gate into a gauntlet that already works is how a gate ends up in the wrong
place, and the order is the whole design.

### Only the decoder closes sockets

Gate 1 closes. Gates 2 through 6 refuse in words. That split should be obvious
from the code's shape rather than remembered -- a sender who is not speaking the
language and a participant who asked for something they cannot have are different
situations and deserve different treatment.

### The one integer comparison

Gate 2 is worth its own note in the source. Almost every other protection in this
project is geometric or structural; this one is `scope->viewer == this_viewer`.
Everything about who may touch what reduces to it, and it is cheap enough that
nobody will ever be tempted to skip it -- which is exactly the property a
load-bearing check should have.

## Suggested implementation steps

1. Restructure `command_apply` into the numbered gates, each its own function, in
   this order.
2. Stub 2, 4, 5, and 6 permissively, each with a comment naming what it will check
   and which phase brings it.
3. Record and refuse as [405](405-refusals-are-sentences.md) describes.
4. Write the companion `.info.md`, listing the gates in order -- that list is the
   specification of what a legal command is.
5. Test each gate by provoking it, and assert the *reason*, not merely that it
   failed.
