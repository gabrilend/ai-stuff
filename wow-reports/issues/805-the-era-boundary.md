# 805 - The era boundary

| | |
|---|---|
| Phase | 8 - emission to the server |
| Blocked by | 801 |
| Blocks | 803, 804 |

## Current behaviour

Nothing checks whether an emitted thing can exist on the target.

## Intended behaviour

The emulator being targeted implements one specific client era, and the client
is the half we do not control. An entity introduced after that era has no
identifier, no icon and no animation on the player's machine. Writing it into
the server's database does not add it to the game - it produces a server
describing something the client cannot render, which fails in ways that look
like anything except the actual cause.

So emission refuses, per entry, before emitting:

- The entity must exist in the target era. An identifier that first appears
  after it is refused.
- The field must exist in the target era's schema. A statistic invented later
  has no column to go in.
- The value must be meaningful in the target era. A coefficient that scales
  against a statistic which did not exist then is arithmetic without a referent.

Every refusal is recorded with its reason and shown in the view, never dropped.
A refusal is a finding: it is the archive telling you exactly which part of
fifteen years of tuning does not fit through the door, and that list is useful
in its own right.

## The thing this issue is really guarding

The purpose document draws the line: **numbers transplant, content does not.**
This issue is that line made mechanical, so the distinction does not depend on
whoever is running the emitter remembering it.

It is also worth being clear about what this project is therefore *for*. It is
not a way to run a modern patch on an old server, and it never will be. It is a
library of balance precedent - fifteen years of how a value of this shape was
tuned - to draw from when deciding what a number should be in a game that is
deliberately not the original. For that purpose the era boundary costs nothing,
because precedent does not need to be portable to be useful.

## Suggested implementation steps

1. Derive the target era's entity inventory from the server's own database
   rather than from a hand-written list, so it stays true as that project
   changes.
2. Check every change set entry against it at computation time, so refusals
   appear in the view rather than at apply time.
3. Count and group the refusals by reason. If most refusals share one reason,
   that is usually a missing mapping rather than a real boundary.
