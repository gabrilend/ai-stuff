# 014 — The Siege-Surge

**Datapath document.** Covers the phase where the chest leaves your hands.

## The four phases, in one place

This is the project's **one** phase table. The challenge and the calm are written
up in [boons and the challenge](015-boons-and-the-challenge.md) and the data
version is built by issue 601, but neither of those restates the grid — a table
copied into three documents is a table that will disagree with itself, and this
one already did.

| | **Normal** | **Siege-surge** | **Challenge** | **The calm** |
| --- | --- | --- | --- | --- |
| How much of the match | the majority | three stretches | three stretches | after each slain monster |
| Spawn shape | **waves**, a batch per lane on a long interval | **a stream**, one body per lane on one shared timer | **waves**, normal interval | **nothing spawns; everyone walks home** |
| Spawn destination | its own lane | its own lane | **the center, every lane's worth** | — |
| What a body carries | its lane's placed upgrades | **a share of everything the team owns, dealt across the bodies spawning that instant** | its **spawning** lane's placed upgrades | — |
| Placing upgrades | free | **free — it changes nothing now, and everything next** | free | free |
| Towers | shoot with their slotted upgrades, can be felled, spawn guards | **shoot at bare catalogue values, cannot be felled, spawn nothing** | as normal | as normal |
| Boons | — | — | — | **each player picks one of two, after a slain monster** |
| Guards | patrol their tower | **spawn from the base as stream bodies** | patrol their tower | as normal |
| Chest grows on | wave wipes, tower kills | **nothing** | wave wipes, tower kills | — |
| Push depth | maintained | maintained | **ignored** | recomputed on leaving |

Read down the siege-surge column and the phase has one idea in it: **arrangement
stops mattering, without anything being taken away.** Waves become a stream, and
what a body carries stops being a decision and becomes a deal. Placement stays
open the entire time — it simply has no effect until the surge ends, which is
exactly when the challenge starts and a completely different kind of fight needs
a completely different board.

Two of those rows were open until recently and are worth reading twice, because
both were argued the other way first.

**Towers shoot at bare catalogue values during a surge.** *See
[open questions](020-open-questions.md), F19.* Nothing applies to them, and
nothing applies through them to their guards. The deal being described as
"assigned, not removed" seemed to argue that a tower ought to keep firing fully
upgraded — but that phrase is a promise about **the chest not being
confiscated**, not a promise that every slot keeps working. Towers are already
invulnerable for the duration; leaving them fully upgraded as well would make a
surge a free minute for whoever is behind, and it would leave half a team's board
untouched by the one thing in this design meant to disturb what a team built. **A
surge suspends arrangement — all of it.**

**Boons arrive twice a match, in the calm after a slain monster**, and each player
picks one of two. *See F6.* Not at the end of a surge, and therefore not three
times. See [boons and the challenge](015-boons-and-the-challenge.md).

Durations are balance values and live in `docs/balance-updates.md`, not here.

## The stream

Both bases emit **one body per lane, on one shared timer** — all three lanes fire
at the same instant, so a surge produces bodies in threes. Where normal play
sends a batch down each lane every several seconds, a surge sends a single body
down each lane every fraction of a second.

One timer for all three lanes, not three timers, and that is not a tidiness
decision. It is what makes the dealing below possible: at every spawn there are
exactly three new bodies, one per lane, and the whole chest can be split across
them.

The frontline stops being a place where two waves meet and becomes a place where
two **rates** meet. There is no lull to reposition in, no window where a lane is
briefly empty, and nothing to time anything against, because there is no spawn
clock any more.

Guards join the stream. A tower under surge conditions does not put a patrol on
the ground; its guard production is redirected to the base and emerges as
ordinary stream bodies. The defence walks out to meet the fight instead of
waiting at home for it.

## Everything the team owns, dealt across the bodies spawning that instant

**Nothing is taken, moved, emptied, or held back.** *Settled; see
[open questions](020-open-questions.md), F11.* Whatever a team has slotted into
the top lane stays slotted into the top lane for the whole surge. The chest is
not dumped out. Placements are not disturbed. **Upgrades are never moved except
by a player's own hand**, and a surge is the place that rule is worth stating,
because an earlier draft of this document had the surge confiscating the board
and handing it back afterwards. Watching your arrangement come apart without
touching it was frustrating in a way that nothing bought back.

What the surge does instead is **stop reading slots.** At every spawn:

1. Pick a **random one of the new bodies** to start with.
2. Take a **random upgrade from everything the team owns** — placed, slotted,
   unplaced, it makes no difference — and assign it to that body.
3. Move to the next body in rotation and repeat, until every upgrade the team
   owns has been assigned.
4. Send them on their way, stamped with what they were dealt.

Half a second later it happens again, from scratch, over the whole holding,
starting somewhere else.

The upgrades are **assigned, not removed.** An upgrade sitting unplaced in the
chest is on the field during a surge exactly as much as one slotted into a lane,
which is a real change from ordinary play, where an unplaced upgrade is doing
nothing for anybody.

So each body gets ⌊N/L⌋ or ⌈N/L⌉ upgrades for N upgrades across L lanes,
**every upgrade the team owns is on the field at every instant**, and no two of
the bodies spawning together carry the same copy.

The **random starting body** matters for one specific reason: when the holding
does not divide evenly, somebody gets one fewer. Starting the deal somewhere new
each time means **which lane comes up short rotates**, rather than the top lane
being permanently a little poorer for the whole surge. A real fairness bug,
avoided by one call into a stream.

### What this actually does to a team

It does not make you weaker. Nothing is lost, nothing is held back, and your full
chest is walking down the map at all times. **It makes you incoherent.**

The three upgrades that worked together in the top lane are all still on the
field — on three different soldiers, in three different lanes, and never in the
same place again until the surge ends. What the surge takes from you is not
strength; it is the *arrangement*, which is the only thing in this game you
actually built.

It also flattens the lanes perfectly. Every lane receives a third of everything,
so during a surge **no lane is special** — the careful asymmetry a team spent the
match constructing is replaced by an even smear. A team that had stacked one lane
suddenly has three mediocre ones.

And it is self-balancing in a way a flat penalty is not. A team with twelve
upgrades has a great deal disturbed by being dealt out three ways; a team with
three has each of them on a body and almost nothing disturbed at all. **The surge
disrupts in proportion to how much there was to disrupt** — which is exactly the
right shape for the design's only brake on a snowball.

### Where the randomness comes from

A dedicated **`surge` random stream**, per team, separate from `deck`, `boon`,
`wander`, and `tie`. It supplies both the deal order and the starting lane, and
it advances several times a second while a surge runs — far more than any other
stream in the game. Sharing one would mean that changing the stream rate silently
changed every team's upgrade draws forever after. See
[the simulation tick](003-the-simulation-tick.md).

## The towers step back

While a surge runs:

- Towers **cannot be destroyed.** No tower falls during a surge, and therefore no
  three-upgrade tower reward is paid.
- Towers **spawn no guards.** That production goes to the base instead and comes
  out as ordinary stream bodies, as described above.
- Towers **still shoot, at their bare catalogue values.** *Settled; see
  [open questions](020-open-questions.md), F19.* No upgrade applies to a tower
  for the length of a surge, and since a tower's guards read through it, none
  applies to them either. The stone fights the surge with nothing on it.

Combined with there being no wave wipes to detect — the stream produces no
discrete groups to finish off — **the chest does not grow at all during a
siege-surge.** It is the one stretch of the match where no upgrade is earned.

Towers being invulnerable is what stops a surge from being a siege window. A team
with a stronger stream would otherwise use the phase to take stone cheaply while
everything was chaotic, and the surge would become a reward for already winning
rather than a disruption of it.

## What players actually do during a surge

Everything they normally do, and one thing more.

They place, move, withdraw, lock, and object exactly as they always can — *see
[open questions](020-open-questions.md), F12* — and none of it changes what the
stream is carrying, because the deal does not look at slots. They buy heroes.
They point sign-posts.

What makes the phase different is **what all that arranging is now for.** A surge
is followed immediately by a challenge, and a challenge is one enormous body
where a wave is a great many small ones. Range, splash, and rate of fire are
worth different amounts against those two things, and a board built for grinding
a frontline is usually the wrong board for a monster.

So a surge is the window in which a team **retools for what is walking out of the
middle next**, while the fighting carries on without waiting for them to finish
deciding. The phase used to be a hole in the game's main activity — buy heroes,
point sign-posts, that was the list — and it is now the one stretch where the
main activity is entirely about the future.

## How it ends

On the tick a surge ends:

1. The stream stops and ordinary wave spawning resumes — redirected to the center,
   because a challenge starts on the same tick.
2. Towers become destructible again and resume spawning guards, subject to their
   command radius being clear.
3. **The board goes back to meaning something.** Nothing moves and nothing is
   dumped; the slots simply start being read again, so whatever the team arranged
   during the surge is what the first wave into the center carries.
4. **The challenge begins** — a named monster per team, in the center lane.

**No boon is handed out here.** *Settled; see
[open questions](020-open-questions.md), F6.* A boon is payment for *slaying* a
challenge monster, and it is chosen in the quiet afterwards. The vision has one
arriving at this moment instead, as equipment for the fight ahead; that reading
was rejected, because a menu opening as something enormous starts walking is not
a reward, and because equipment picked against a monster you have not met is a
guess. See [boons and the challenge](015-boons-and-the-challenge.md).

So a surge does not end in a reward. What it ends in is **a monster, and a board
you have spent
the last minute rebuilding for it.** The scramble the vision describes — "the
players have to quickly re-assign them to re-create the strategies they were
using" — has already happened, during the surge, while the stream was running.
That is the trade this design makes: the panic is moved earlier, into a phase
where nothing you do can go wrong, and what is left when the monster appears is a
board you chose.

Related: [waves](005-waves-and-when-one-is-finished.md) ·
[the shared upgrade pool](009-the-shared-upgrade-pool.md) ·
[boons and the challenge](015-boons-and-the-challenge.md) ·
[guard towers](007-guard-towers-and-their-guards.md)
