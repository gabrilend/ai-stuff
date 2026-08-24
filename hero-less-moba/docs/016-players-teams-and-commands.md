# 016 — Players, Teams, and Commands

**Datapath document.** Covers how many people are playing, and the single narrow
door through which everything a person does enters the simulation.

## Six players, two teams of three

The working assumption is **three players per team**. It comes from the vision's
description of the objection rule — "the allies can ping an upgrade to ask it to be
unlocked, and if both of them do so then it automatically unlocks." *Both* of
them means exactly two allies besides the locker, which means three per team.

Three also lines up with three lanes, which is a tidy coincidence and nothing
more. Nothing in the rules assumes one player per lane, and nothing forbids it.

Everything in the code is written against a team size constant, not the literal
number three, and the lock rule is written as "everyone but the locker has
objected" rather than "two people have objected," so that changing team size is
changing a number. Whether the game should support 1v1 and 2v2 at all is on the
[open questions](020-open-questions.md) page.

Player numbers 1, 2, 3 are team 1. Player numbers 4, 5, 6 are team 2. This is a
fixed mapping and not a lookup.

## The command queue

**Nothing a player does touches the world directly.** Clicking a sign-post does
not turn a sign-post. It appends a command record to a queue, and at the top of
the next tick the command pass applies every queued command in a fixed order —
by player number, then by arrival index within that player — and then clears the
queue.

Three things come from this and each of them is worth the indirection on its own:

1. **Reproducibility.** One machine given the same seed and the same command list
   produces the same match, tick for tick. That is the project's best regression
   test and it is what lets a whole match be described in a text file. It does
   *not* mean two machines agree — see the networking section below.
2. **Fairness.** Two players issuing conflicting commands on the same tick are
   resolved by player number, always, rather than by whose packet arrived first —
   which is to say, by whose connection is better.
3. **Testability.** A test is a seed and a list of commands. The whole of a match
   can be described in a text file and replayed at full speed with nothing drawn.

## The verbs

The complete list of things a player can do. If it is not here, it is not a thing
the game lets you do, and any feature proposal has to add a row.

| Command | Arguments | Refused when |
| --- | --- | --- |
| `place_upgrade` | instance, slot kind, lane | Locked by another; kind cannot enter that slot; already in transit; a surge is running |
| `withdraw_upgrade` | instance | Locked by another |
| `lock_upgrade` | instance | Already locked; instance is unplaced |
| `unlock_upgrade` | instance | Not locked by this player |
| `object_upgrade` | instance | Not locked; locked by this player; already objected by this player |
| `cancel_move` | instance | Not in transit; locked by another |
| `ping_map` | x, y | Rate-limited |
| `set_signpost` | sign-post, facing, branch | Sign-post is in enemy territory |
| `spawn_hero` | roster row, destination kind, destination id | Not enough resource; tower has enemies within the threshold radius; destination is not yours |
| `reroll_upgrade` | instance | Not enough resource; locked by another; a siege-surge is running |

Every refusal produces a **reason code**, and the viewer shows it. A command that
silently does nothing is the worst possible outcome — the player learns nothing
and concludes the game is broken. Refusals are loud.

There is no verb for moving a soldier, no verb for attacking, and no verb for
using an ability. Those are the simulation's business. A player places, locks,
objects, points, and buys.

## command record

| Field | Type | Meaning |
| --- | --- | --- |
| `tick` | integer | The tick this command is to be applied on. |
| `player` | integer | 1–6. |
| `verb` | integer | Row in the command dispatch table. |
| `a`, `b`, `c` | integer | Arguments, meaning determined by `verb`. |

Three integer arguments cover every verb in the table above. A command is sixteen
bytes and a whole match's worth of them fits comfortably in memory, which is what
lets a replay be the command list itself rather than a compressed approximation
of one.

The `verb` field indexes a dispatch table of handler functions rather than
selecting a branch in a conditional chain. Adding a verb is adding a row and a
function.

## Networking: peer-to-peer with a rotating authority

**Three channels, carrying three different kinds of thing, with different
guarantees.** *Settled; see [open questions](020-open-questions.md), E1 and E2.*

### 1. Choices — immediate, reliable, never rolled back

The moment a player places, locks, objects, points, or buys, their machine sends
that command to every other machine over TCP. It is applied on arrival.

**A choice is authoritative from the person who made it, and no choice is ever
rolled back.** There is no scheduling window, no waiting for acknowledgement, and
no rollback-and-replay. If a player placed an upgrade, that upgrade is placed, on
every machine, as soon as the packet lands.

This is the most important property in the whole networking design and it is
worth being explicit about why. A rollback is a lie the game told you: you saw
your upgrade go into the top lane, you made three more decisions on the strength
of that, and then the game took it back. In a game whose entire subject is
placement decisions negotiated between three people, an untrustworthy placement
is fatal. Positions can lie a little. **Choices cannot lie at all.**

The cost is that two machines apply the same command a few ticks apart, so the
wave that spawned in between may be stamped differently on different machines.
That is a real divergence and it is corrected by channel 2.

### 2. Continuous state — a rotating authority, about once a second

Everything that is *not* a choice — where each body is, how much health it has,
what is in flight — drifts between machines, because it is floating-point
arithmetic being run independently on different processors.

**It is corrected on a cycle, by one peer at a time, and whose turn it is
rotates.** Each cycle, the machine whose turn it is publishes the last second or
so of continuous state; everybody else accepts it, without argument.

There is no permanent host. The rotation matters for two reasons:

- **Nobody's machine decides outcomes.** In a competitive game between six
  people, a fixed host is a fixed advantage — their view is always the true one
  and theirs is the machine with no correction latency. Rotating removes that.
- **The upload cost is shared.** Publishing a snapshot means sending it to five
  peers. Doing that once every six cycles rather than every cycle is the
  difference between one player needing a good connection and all of them
  needing a mediocre one.

Corrections should be small, because every machine is running the same code from
the same seed and only diverging by floating-point rounding and a few ticks of
command latency. They are not guaranteed small, and a body can visibly snap.

### 3. Presence — every player's cursor, continuously

Each player's mouse position is synced, so everyone can see what everyone else is
looking at.
This is a few bytes and it is not a nicety. **It is one of the five verbs a team
has for talking about the chest**, and one of the two that are involuntary — a
cursor hovering over an upgrade says *I am about to touch this*, before anybody
has to commit to anything. A team that can see each other's attention will lock
less, because most of what a lock prevents is two people reaching for the same
thing without knowing it. The full list is in
[the shared upgrade pool](009-the-shared-upgrade-pool.md).
prevents is two people reaching for the same thing without knowing it.

Whether enemy cursors are visible is a separate question and almost certainly no.

### Accepting a snapshot: does anything explain it?

A peer does not accept an incoming value blindly. **Only values that differ from
the local simulation are examined at all** — the machines are running the same
code from the same seed, so most bodies agree and cost nothing to verify. For
each one that differs, the receiving machine looks at the units in range of that
body on its own view and asks whether the difference is **explicable** by them: a
health drop larger than every attacker in range could have dealt in the elapsed
ticks is not a correction but a claim about something that could not have
happened. Values that fail are rejected, the local ones kept, and the rejection
logged.

This is a **causality check, not a tolerance**, and that is what makes it worth
having. A magnitude tolerance asks "is this change big?", which is a tuning
question that always gets the edge cases wrong. This asks "could anything have
done this?" — a question the simulation already knows the answer to, because
knowing what is in range of what is the retarget pass's whole job.

It catches the impossible, not the improbable, and that is the right place to
stop.

### What this model is not

It is **not lockstep**, and the earlier drafts of this project assumed it was.
Two consequences follow that are easy to miss:

- **Floating point is fine.** There is no requirement that two machines agree bit
  for bit, because disagreement is expected and corrected on a schedule. The
  fixed-point rewrite that was blocking phase 2 is not needed. See
  [the simulation tick](003-the-simulation-tick.md).
- **A replay is no longer just a seed and a command list.** That claim was true
  only under lockstep. Under a rotating authority the world is periodically
  overwritten from outside, so replaying commands against a seed reproduces *a*
  match rather than *the* match. See issue 107, which has been corrected.

Related: [the simulation tick](003-the-simulation-tick.md) ·
[the shared upgrade pool](009-the-shared-upgrade-pool.md) ·
[commanders and personal resource](011-commanders-and-personal-resource.md) ·
[the viewing layer](017-the-viewing-layer.md)
