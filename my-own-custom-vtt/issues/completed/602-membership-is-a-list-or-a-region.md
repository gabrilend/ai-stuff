# 602 -- Membership is a list or a region

**Phase:** 6, control is a dial
**Blocked by:** [601](601-a-scope-is-a-record.md)
**Blocks:** [605](605-the-tavern-commands-its-crockery.md)
**Documents:** [who controls what](../docs/008-who-controls-what.md)
**Open questions:** [6.1](../docs/016-open-questions.md) — the patrol crossing a
boundary.

## Current behaviour

Scopes exist as records. Nothing asks what is in one.

## Intended behaviour

One question, asked constantly: **is this thing inside this scope?**

`LIST` walks a slice of the membership pool. `REGION` resolves the thing's region
up the parent chain looking for the scope's — using `region_is_within`, which was
built in phase 1 and has been waiting for a caller.

Both are cheap. The list is short and the chain is two or three long.

### This is the load-bearing permission check

Every command runs it. Every outbound record runs it. It allocates nothing and
touches only the scopes, the pool, and the regions.

### The patrol problem, which this file creates

Region membership is evaluated from a thing's **current** region, so the moment a
goblin patrol crosses from the forest into the tavern, it belongs to the tavern's
commander.

That is mechanically what happens. **Whether anybody wants it is not settled.**
The forest's commander may have been walking that patrol for ten minutes with an
intention, and having it taken away at a doorway is a strange experience.

Alternatives, none argued out: the patrol keeps its origin scope until somebody
hands it over; a thing can be in a list scope *and* a region scope with the list
winning; the crossing is a request the receiving commander accepts.

**Do not decide this by implementing it.** Build the mechanical answer, make the
demo show the moment it happens, and leave [6.1](../docs/016-open-questions.md)
open until somebody has watched it and formed an opinion.

## Suggested implementation steps

1. Write `scope_contains(world, scope, thing)`, dispatching on membership.
2. Wire it into the outbound filter's gate 1 — which currently returns "admits
   nothing" and was written that way so this is a substitution.
3. Wire it into the command gauntlet's membership gate.
4. Write the companion `.info.md`.
5. Test both rules, nesting, a thing in neither, and a scope nobody holds.
6. Test the crossing: a body walking from one region to another changes which
   scope contains it, on the beat it crosses.
