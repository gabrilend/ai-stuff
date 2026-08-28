# 016 — Players, Teams, and Commands

**Datapath document.** Covers how many people are playing, and the single narrow
door through which everything a person does enters the simulation.

## Team size is a variable, and the map is derived from it

**Three players per team is what the prototype targets. It is not a constant
anywhere.** *Settled; see [open questions](020-open-questions.md), F10.*

Three comes from the vision's description of the objection rule — "the allies can
ping an upgrade to ask it to be unlocked, and if both of them do so then it
automatically unlocks." *Both* of them means exactly two allies besides the
locker, which means three a side.

What is new, and what an earlier draft of this document got backwards, is that
**three lanes and three players is not a coincidence.** The map is generated from
the team size:

- **Lanes = players per team.** Three players, three lanes.
- **Guard towers per team = lanes × 3** — two standing on each lane, one at each
  lane's mouth inside the base. Two lanes gives six a side, three gives nine,
  four gives twelve.

So 2v2 and 4v4 are not variants to be supported later; they are what the map
builder emits when it is handed a different number. That is the whole of the
answer to E6, and it means the nine-milestone assumption is something the map
validator checks rather than something the rest of the code may rely on.

**This does not mean a player owns a lane.** Nothing assigns one, the shared
chest and the base guards' shared radius both exist to punish exactly that habit,
and a team is free to spend all three of its attentions on one lane. What follows
from the team size is the *shape of the field*, not who looks at what.

Player numbers run 1 to `players_per_team × 2`, the first half being team 1 and
the second half team 2. That is arithmetic on a variable, not a table — and the
lock rule is written as "everyone but the locker has objected" rather than "two
people have objected" for the same reason.

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
2. **A stable order, on one machine.** Two commands landing in the same tick are
   resolved by player number, always, rather than by which was appended first.
   Note what this does *not* claim: across six machines a command really is
   applied when its packet arrives, so two teammates on different connections
   can genuinely see a different order. That is what the freeze window below is
   for, and it is why the fairness argument lives in the networking section
   rather than here.
3. **Testability.** A test is a seed and a list of commands. The whole of a match
   can be described in a text file and replayed at full speed with nothing drawn.

## The verbs

The complete list of things a player can do. If it is not here, it is not a thing
the game lets you do, and any feature proposal has to add a row.

| Command | Arguments | Refused when |
| --- | --- | --- |
| `place_upgrade` | instance, slot kind, lane | Not yours and not communal; already in transit; destination is where it already is; inside the freeze window. **Never on the grounds of what the upgrade is** — see F28 |
| `withdraw_upgrade` | instance | Not yours and not communal; inside the freeze window |
| `choose_boon` | offer index | Not in a boon window; this player has already chosen |
| `contribute_upgrade` | instance | Not yours; already communal |
| `dismiss_upgrade` | instance | Not communal; already dismissed by this player |
| `offer_upgrade` | instance, player | Not yours; that player is not a teammate |
| `request_upgrade` | instance | Already have a request outstanding; rate-limited; the stone is already yours |
| `cancel_move` | instance | Not in transit; not yours and not communal |
| `ping_map` | x, y | Rate-limited |
| `set_signpost` | sign-post, branch | The sign-post is not this player's team's |
| `spawn_hero` | roster row, destination kind, destination id | Not enough resource; enemies inside that tower's command radius; destination is not yours |
| `reroll_upgrade` | instance | Not enough resource; not yours |

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
| `player` | integer | 1 to twice the team size. |
| `verb` | integer | Row in the command dispatch table. |
| `a`, `b`, `c` | integer | Arguments, meaning determined by `verb`. |

Three integer arguments cover every verb in the table above. A command is sixteen
bytes and a whole match's worth of them fits comfortably in memory, which is what
lets a replay be the command list itself rather than a compressed approximation
of one.

The `verb` field indexes a dispatch table of handler functions rather than
selecting a branch in a conditional chain. Adding a verb is adding a row and a
function.

## Networking: three flows, and only one of them crosses the front line

*Settled; see [open questions](020-open-questions.md), E1, E2, E2b, F7, F8.*

The single most important thing about this model, and the thing an earlier draft
had wrong: **the two teams do not simulate the same world.** Your machine does
not hold the enemy's chest, their slot assignments, their wallets, or which way
their sign-posts point. Those are not fields your viewer politely declines to
draw — they are not on your computer. That is the only version of hidden
information that survives somebody running a modified client.

| Flow | Who receives it | What it carries |
| --- | --- | --- |
| **The viewer's copy** | nobody — it never leaves the machine | everything the renderer needs, stamped once per tick |
| **Team traffic** | that team's machines only | placements, queued moves, locks, objections, sign-posts, purchases, boon picks |
| **Cross-team sync** | everybody | positions and health of bodies, projectiles, and structures |

### Team traffic — immediate, sanity-checked, never rolled back

The moment a player places, locks, objects, points, or buys, their machine sends
that command **to their teammates** over TCP. Each of them checks quickly that it
is a legal move, then applies it and updates their interface.

**A choice is authoritative from the person who made it, and no choice is ever
rolled back.** No scheduling window, no waiting for acknowledgement, no
rollback-and-replay. A rollback is a lie the game told you: you saw your upgrade
go into the top lane, you made three more decisions on the strength of that, and
then the game took it back. In a game whose entire subject is placement decisions
negotiated between three people, an untrustworthy placement is fatal. **Positions
may lie a little. Choices may not lie at all.**

The cost is that two teammates on different connections apply the same command a
few ticks apart, which is fine for everything except a destination that is about
to be read. So:

> **An upgrade's queued destination cannot be changed inside a window of the
> worst ping among that team's connected players, plus fifteen percent.**

Inside the window the destination is frozen and a change is refused, with a
reason. Outside it, everybody has already seen it. Fifteen percent is headroom
for a connection getting worse while you are looking at it rather than a tuned
figure, and the window is per team, because a team with three good connections
should not be slowed down by an opponent with a bad one.

### Cross-team sync — positions and health, and nothing else

Everything that is not a choice — where each body is and how much health it has —
drifts, because it is floating-point arithmetic run independently on different
processors. It is corrected on a cycle, by one peer at a time, with **whose turn
it is rotating**, and everybody else accepting without argument.

There is no permanent host. In a competitive match a fixed host's view is always
the true one and their machine is the one with no correction latency, which is a
fixed advantage; and publishing means uploading to everybody else, so rotating
turns *one player needing a good connection* into *all of them needing a mediocre
one*.

**Positions and health is close to the minimum that still works**, and it works
because of a chain: health determines deaths, deaths determine wave wipes, wave
wipes determine draws, draws determine the chest. Two machines that agree on
every health value agree on everything downstream without any of it crossing the
wire. It also means a modified client has very little to lie about — it can move
bodies and adjust health, and it cannot invent an upgrade, hand itself resource,
or claim a wave it did not kill, because none of those are in the message.

One implementation consequence worth writing into the code: applying an incoming
value must **not** raise a death, a wipe, or a draw as a side effect. Health is
written; the ordinary resolve pass notices the zero on the next tick and
everything downstream follows through the normal path.

#### What a position actually is, and what this section still owes

"Positions" is doing more work in the paragraphs above than it looks like, and
building the replay log — which records the same thing this sync records — walked
into it first.

**A body's x and y are derived, not stored.** A body walking a lane is held as how
far along the lane it is and how far across it; x and y are recomputed from those on
every move pass. Sending an x and a y and writing them onto the receiver's body
accomplishes precisely nothing: the next move pass overwrites them a fraction of a
second later, while every counter in the system reports the correction was applied.
What has to cross the wire is the authoritative set — lane coordinates, which
segment of the path, and which edge a body not on a lane is walking.

Two questions follow that this document cannot answer on its own, both written up in
[open questions](020-open-questions.md):

- **H1.** Which lane a body is in is a *decision*, taken once at a junction — not a
  number that drifts. Two machines that disagree about it have taken different turns
  rather than drifted apart, and this section's model has no answer for that.
- **H2 — answered, and built.** A machine that killed a body the authority did not
  could never be corrected: the slot was freed and recycled, and there was nothing
  left to write the numbers onto. Since deaths are the hinge everything downstream
  hangs from — deaths to wipes to draws to the chest — that was the more serious of
  the two.

  **A death is now a two-second process.** A body at zero health leaves the field
  immediately and then holds its slot, and every one of its numbers, for two
  correction cycles before anything about the death is made final — nobody paid, no
  wave counter moved, no guard replaced, no challenge ended. Undoing it is clearing
  one number. This section's message therefore has a body to write onto for as long
  as any peer could still disagree, which is the whole requirement.

  The cost lands here rather than on the wire: **every consequence of a death is two
  seconds late**, uniformly. See issue 210. How far two runs drift apart, with and
  without correction, is printed by the divergence check in the invariants suite.

### Presence — every player's cursor, continuously

Each player's mouse position is synced to their **teammates**. This is a few
bytes and it is not a nicety: it is one of the eight verbs a team has for talking
about the chest, and one of the two that are involuntary. A cursor hovering over
an upgrade says *I am about to touch this*, before anybody has committed to
anything. Expect teams to lock less because of it, since most of what a lock
prevents is two people reaching for the same thing without knowing it. The full
list is in [the shared upgrade pool](009-the-shared-upgrade-pool.md).

Enemy cursors are not sent.

### Checking what arrives: could anything have done this?

A peer does not accept an incoming value blindly, and the test is the same on
both sides of the front line: **watch what arrives, and ask whether it is
explicable.**

**Within a team, and for the shared bodies**, this is a causality check.
*Settled; see E2b.* Only values that differ from the local simulation are looked
at, since the machines agree about most bodies for free. For each one that
differs, the receiving machine finds the units in range of that body on its own
view and asks whether the difference is explicable by them. A health drop larger
than every attacker in range could have dealt in the elapsed ticks is not a
correction; it is a claim about something that could not have happened. What
fails is rejected, the local value kept, the rejection logged.

**Health gains used to be free to reject** — this document said *"nothing in this
game heals"* and treated any rise as impossible. **Priests heal**, so that
absolute is gone, and healers have to be counted among the things that could
explain a change exactly as attackers already are.

Which is harder than it sounds, and F39 has the whole of it: **a per-body
question does not compose.** One healer's single heal can look like a valid
explanation for two different bodies at once, because nothing in a per-body check
tracks that its capacity can only be spent once. That turns the check from a
lookup into a bipartite matching, unless healing is made an **area** effect —
which removes the assignment entirely and puts the check back to one question
with one complete answer. See F39.

**Across teams, it is an accounting check.** *Settled; see F8.* Because your
machine no longer simulates the enemy's chest or their wallets, it has to
**infer** them from what walks into you, and then check the inference:

- **An upgrade appears on an enemy frontline body that you have not seen come out
  of the shared deck.** There is an innocent explanation — they paid to reroll and
  are further along the sequence than you are — and it is checkable, because a
  reroll costs resource and resource is bounded by kills you can see.
- **The enemy fields heroes costing more than they could feasibly have earned by
  this tick.** There is no innocent explanation for that one.

A single discrepancy is not an accusation, and the checker's first job is to
**try to explain it** — most of the time it can. What is not tolerated is
**accumulation.** One unexplained upgrade is a reroll you did not watch for. A
dozen of them, plus a roster nobody could afford, is not anything else.

Both halves catch **the impossible rather than the improbable**, which is the
right place to stop. Catching the improbable means statistical thresholds and a
stream of false accusations against people with bad connections, in defence of a
game played peer-to-peer among six people who chose to play together.

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
  match rather than *the* match. See issue 107.

Related: [the simulation tick](003-the-simulation-tick.md) ·
[the shared upgrade pool](009-the-shared-upgrade-pool.md) ·
[commanders and personal resource](011-commanders-and-personal-resource.md) ·
[the viewing layer](017-the-viewing-layer.md)
