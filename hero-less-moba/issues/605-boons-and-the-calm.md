# 605 — Boons, and the Calm They Are Chosen In

| | |
| --- | --- |
| Phase | 6 — The Surge and the Challenge |
| Blocked by | 105, 401, 402, 601, 606 |
| Blocks | 607 |
| Reads | [boons and the challenge](../docs/015-boons-and-the-challenge.md) |
| Open questions | B8 — how many boons, and how much stronger than an ordinary upgrade |

## Current behavior

Each player is offered two boons in the calm after a slain monster, and a boon
reaches everything that team fields, heroes included — it is not in a lane and has no
slot, which is exactly why it is allowed where a lane upgrade is not.

**An unchosen offer stays open indefinitely.** Nothing is ever taken for anybody.

The six on offer are drawn at random from a flat list, which is a curation problem
rather than a mechanism one.

## Intended behavior

**A boon is payment for slaying a challenge monster, not for surviving a surge.**

When both of a challenge's monsters are dead, the phase moves to **the calm** — a
phase in which nothing spawns and **every soldier still on the field turns
around and walks back to its own base**, where it leaves the game. Nobody fights
on the way. It lasts thirty seconds to a minute. In that window:

- **Each player chooses a boon from two offered.** One pick per player, made
  independently, so a three-player team gains three at once.
- **The same two are offered to every player on both teams.** One pair drawn per
  event, per match — not per player and not per team. Nobody is ever handed a
  better menu, which is the shared-deck principle arriving somewhere new.
- **The board can be rearranged**, as it can in every phase. Nothing was dumped
  when the surge ended and nothing needs rebuilding; this is simply an unhurried
  minute in which to do it.

Then spawning resumes.

**It happens twice, not three times** — after the Pillar Orc and after the Field
Dragon, never after the Eternal Golem, which is never slain.

| | Per event | Over a match |
| --- | --- | --- |
| Boon events | — | two |
| Offered to each player | two | 2 + 2 |
| Chosen by each player | one | **two per player** |
| Gained by a three-player team | three | **3, then 6 — six per team** |

**A boon reaches every body the team fields, heroes included.** A lane's upgrades
never touch heroes; a boon is not in a lane and has no slot, so there is no
placement decision for it to multiply with. It is best implemented as what it is
described as — a modifier on the commander that is folded into everything that
team spawns.

**The wallet's ceiling rises here too**, once per calm, so both economies step
together and step exactly twice.

### What a boon is

An instance with `is_boon = 1`, **no slot**, and an `owner` — the only instance
kind that has one.

It is **not a lane upgrade with the lanes filled in.** It has no slot at all, so
it is not summed into any lane's counts; it lives in a **team-level boon count
vector** that is folded into every body that team fields, of every flavour,
heroes included. The surge's dealing pass skips it entirely.

So a boon applies to everything, everywhere, in every phase, cannot be moved,
survives every surge unscattered, and **belongs to the player who chose it** —
which is a fact about authorship and the post-match report, not about who it
helps. It helps the whole team.

Why the calm exists, why a boon paid for the kill is different from one handed
out when the monster appears, and why the frontline reset it causes is a
structural statement about what a match is, are all in
[boons and the challenge](../docs/015-boons-and-the-challenge.md).

**One line from there is worth repeating here as a build instruction:** if the
calm is ever shortened for pacing, the boon choice stops being a choice and
becomes a thing you click through.

## Suggested implementation steps

1. Add the calm as a phase-table row in issue 601: nothing spawns, all slots
   legal, a fixed duration in ticks that is a balance value **from the first
   commit**, because it will be changed several times and can only be found by
   watching people use it.
2. Write the **walking home** behaviour by reusing the leashing state from issue
   304 — reverse `facing`, leash to the team's own library, refuse to acquire,
   leave the game on arrival. Do not write a sixth brain state.
3. **Recompute push depths at the end of the calm.** It is the one moment in a
   match where the frontline moves backwards for everybody at once, and the
   incremental maintenance from issue 102 cannot follow it.
4. Write the boon catalogue as a data table under `assets/` with its own
   validator, sharing the upgrade kind record's shape.
5. On entering the calm, draw **one pair of offers** from the `boon` stream and
   put that same pair into every player's frame, on both teams. One draw per
   event, not one per player — a test should assert that all six players were
   offered an identical pair, because this is the parity rule and it will be
   quietly broken by anybody who assumes a per-player draw is more natural.
6. Write `choose_boon`. A player who does not choose before the calm ends gets
   the **first of the two**. **Never nothing** — a player who looked away should
   not be permanently behind their teammates. Note that the default being the
   same for everybody means an inattentive team converges on a triple stack of
   one boon, which is a legal outcome rather than a bug.
7. Build the team's boon count vector by summing every `is_boon` instance, and
   fold it into every body at spawn regardless of flavour — and for guards, which
   read their tower live, fold it in at read time. Confirm the surge's dealing
   pass skips boons. Test across both surges, and test that a hero carries them
   while carrying no lane upgrades at all, since that pair of rules is the one
   most likely to be collapsed into a single wrong one.
8. Keep a permanent list of each player's boons on screen. A boon nobody can look
   up is an unexplained change in how strong their soldiers are.

## Related documents and tools

- [Boons and the challenge](../docs/015-boons-and-the-challenge.md)
- [The shared upgrade pool](../docs/009-the-shared-upgrade-pool.md)

## Still open

**How long is the calm?** Long enough to read three options and re-place a chest,
short enough that a match does not sag. **The only phase in the game whose entire
purpose is to be comfortable**, which makes it the easiest one to ruin by
trimming.

**Are the two offers balanced against each other?** A player picks the stronger
of two, so unlike a handed-out boon there is no averaging — and because everybody
is offered the same pair, an imbalanced pair is not merely a dull choice, it is a
pair where all six players correctly make the same pick and the event does
nothing at all. The catalogue has to be flat enough that the choice is about
**fit** rather than about which one is better, which is a harder bar than usual
and is really a question for B8.
