# 020 — Open Questions

Every unresolved decision found while turning the vision into documents. This is
not a closing section and it is not decoration. **A phase whose questions have
not been worked through is a phase being built on a guess**, and the guesses are
labelled below as *working rulings* so that it is obvious which parts of the
documentation are the vision speaking and which parts are me filling a gap.

The questions are meant to be gone through one at a time. Answering one usually
kills two or three others — and occasionally creates one, which is what the
entries marked **NEW** are.

**Answered so far: A1, A2, A5, A6, A6b, A6b-i, A6c, A8, A8b, A9, A10, A11, A11b,
A11b-i, A11b-ii, A12, A13, A14, A15, A16, A16b, A17, A18, C1, C2, C2b, C4, D1,
D2, D3, D3b, D4, D5, D6, D7, D8, E1, E2, E2b, E2c** — forty, plus A7, which was
answered by deleting the rule it asked about. **Groups A and D are finished.**
Those entries are kept rather than deleted, rewritten to record the answer, what
it settles, and what was rejected. The road not taken is worth being able to find
again, especially where a system later turns out to be flat.

Each unanswered entry carries: what the vision says, the working ruling if there
is one, why the answer matters, and which documents change when it is answered.

---

# Group A — Rules the vision genuinely leaves open

These change how the game plays. They are the ones worth arguing about.

## A1. When a wave is wiped, which team draws? — **ANSWERED**

**Vision:** "whenever a wave is fully defeated, an upgrade goes into the pool for
a team."

**Answer: the team that killed the wave draws.** Team 1's chest fills up by
killing team 2's soldiers.

The rejected reading was that the team whose wave died is paid, which would have
made the upgrade economy a rubber band — losing a lane pays you — and a
completely different match.

What this settles, and it shapes everything downstream: **the chest is a snowball
by design.** A team winning a lane kills more waves there, draws more upgrades,
and wins it harder. Nothing in phases 1 through 5 brakes that. The siege-surge is
the only brake in the entire design, and it works by destroying the *arrangement*
rather than the upgrades — a rebuilt-under-fire arrangement is worse than one
built at leisure. If playtesting finds that surges do not visibly reset a
lopsided match, this rule is the first place to look.

**Changed:** [005](005-waves-and-when-one-is-finished.md), [009](009-the-shared-upgrade-pool.md), issues 208 and 403, phase-2 and phase-4 progress.

## A2. Who does a kill pay personal resource to? — **ANSWERED**

**Vision:** "There's also a resource gained when units are slain that is personal
to each player."

**Answer: every kill your team lands pays every player on your team, in full.**

It does not matter what did the killing — a wave unit, a tower guard, a guard
tower's arrow, somebody else's hero, or the last blow on a challenge monster all
pay identically. The killer's `owner` field is **not consulted for payment**. It
still decides who owns a hero for the spawn rules and the report, and nothing
else.

The rejected reading was that only bodies you paid for pay you, which would have
made every hero earn back its own price — attractive, and carrying a death
spiral: a player who lost their first hero badly might never afford a second and
would fall out of the match entirely.

What this settles: **"personal" means a private wallet, not a private income.**
Teammates earn identically, so the only thing separating two of them is what they
do with the same money — when to bank, which of the five heroes, which of the
three spawn destinations. That is a better axis to differentiate players on than
who was better at landing final blows, and a player who is inattentive at the
frontline is no longer thereby poorer.

**Changed:** [006](006-combat-and-damage.md), [011](011-commanders-and-personal-resource.md), [001](001-what-this-game-is.md), issues 205, 502 (rewritten and renamed), 509, 606, phase-2 and phase-5 progress.

**Still open underneath it:**

- **Is the catalogue figure per player, or a pot divided among them?** Treated as
  per player, which triples a team's real income compared with the other reading.
  That is a ruling, not part of the answer.
- **The hero economy is now a second snowball with no brake on it.** See C3.
## A3. How many players per team? — **ANSWERED**

**A variable, three per side for the prototype, and the map is derived from it.**
See F10: lanes equal players per team, and guard towers equal lanes times three.


**Vision:** "the allies can ping an upgrade to ask it to be unlocked, and if
**both** of them do so then it automatically unlocks."

**Working ruling:** three per team, six total. "Both of them" means exactly two
allies besides the locker.

**Why it matters:** at two per team the lock-and-objection rule does much less work,
and at one per team the whole negotiation system is dead weight. Also: should 1v1
and 2v2 be supported at all, or is this strictly a 3v3 game?

**Changes:** [016](016-players-teams-and-commands.md), [009](009-the-shared-upgrade-pool.md), issues 406, 407, 802.

## A4. "The guards in the base" — soldiers, or towers? — **ANSWERED**

**Vision:** "The guards in the base will move to attack any invaders no matter
which lane they came from, but the range on their arrows is such that they
probably will only be able to hit the units that came from a single lane — it's
just a radius around them."

**Answer: both halves are true, of different things, and the sentence is not
ambiguous once you notice it names two.** "Will move to attack" is a soldier.
"The range on their arrows" is a tower. The vision put them in one clause because
in the world they are one thing — the defence of a base — and in the record they
are two.

So: the base's guard **soldiers** are unleashed and answer any lane, because the
interior of a base is one open room. The base's **towers** shoot a plain radius
which in practice reaches the mouth of the one lane each sits at. **Bodies flow
across the base freely; arrows do not.**

This sat as a working ruling for a long time on the grounds that it was "not a
decision, both readings are implemented." That was a dodge. Both readings being
implemented *is* the answer, and the reason it is the right one is worth stating:
the two halves produce the behaviour the vision describes only when they are
both true. Towers alone and there are no bodies to meet a breach. Soldiers alone
and a base covers every lane at once, which makes splitting a push pointless and
takes away the one shove toward attacking two lanes at once.

The consequence to tell players: **pushing into a base means fighting every guard
in it, but only under the arrows of the one tower you walked past.** Splitting a
push across two lanes into the same base is therefore meaningfully better than
doubling up on one.

**Changes:** [007](007-guard-towers-and-their-guards.md), [008](008-the-base-and-the-library.md), issue 305.

## A5. What happens to upgrades slotted into a tower that falls? — **ANSWERED**

**Vision:** silent.

**Answer: nothing happens. They are untouched.**

An upgrade is slotted into a lane's stone **as a whole**, never into one specific
tower, so a felled tower has nothing in it to lose. The lane's other tower keeps
it. And when both of a lane's towers are rubble, the upgrade is still working —
through the three base towers, which have been inheriting every lane's stone the
whole time.

The rejected alternatives were returning them to the chest unplaced, and
destroying them with the tower. Destroying would compound a loss into a collapse,
which is the shape of a match that ends before it becomes interesting. Returning
would cost a decision at the worst possible moment.

**The consequence is larger than the rule looks, and it is now a deliberate part
of the design: a tower upgrade cannot be taken away from you by anything the
enemy does.** The only thing in the game that can dislodge one is a siege-surge.

That makes stone and soldiers asymmetric investments:

| | A lane upgrade | A stone upgrade |
| --- | --- | --- |
| Applies to | every wave unit spawned into that lane, forever | that lane's towers plus all three base towers, forever |
| Takes effect | on the next wave | immediately |
| Enemy can reduce its value by | killing your waves faster than you make them | **nothing** |
| Can be lost to | a siege-surge | a siege-surge |
| Pushes a frontline | yes | no — it only holds one |

Read that as a design instruction. **Stone must be worse at pushing than soldiers
are, by enough to be obvious**, or the unlosability makes it the default and
nobody ever puts an upgrade in a lane. Issue 804 should carry the ratio of stone
placements to lane placements as a headline number; if it drifts hard toward
stone, this rule is why.

It also makes a last stand viable: a team that invested in stone and then lost
all six lane towers still has three fully upgraded base towers. That is not a
comeback mechanic — a team that never invested gets nothing — but it means an
investment made while winning is still working while losing.

**Changed:** [007](007-guard-towers-and-their-guards.md) (which contradicted
this and has been corrected), [010](010-upgrades-slotted-into-stone.md), issues
306 and 408, phase-3 and phase-4 progress.
## A6. Does a surge empty the tower and library slots too? — **ANSWERED**

**Vision:** "all the upgrades get put back into the pool."

**Answer: nothing is emptied, and nothing is moved. During a surge the chest
cannot be touched at all — every body the stream spawns simply carries a random
third of it.** The full mechanism is in **A6b** below; this entry records what the
question was originally asking and why the answer is not what it expected.

The question assumed the surge takes your upgrades away, and asked which slots.
It does not take them away. It takes away your ability to *aim* them, which turns
out to be the thing worth taking.

Two earlier readings were both rejected along the way:

- **Emptying everything into the chest** punishes. A team with twelve upgrades and
  a team with three are both suddenly running on nothing, which flattens the match
  at the exact moment it should be at its most volatile.
- **Collecting everything into the library as an un-aimed pool** was an
  improvement but still needed a strength ratio between aimed and un-aimed, which
  is a dial nobody wanted to have to set.

Dealing the chest three ways needs no ratio and punishes nobody. See A6b.

When the surge **ends**, everything is dumped into the chest unplaced, and the
scramble to re-place it happens under the challenge.

## A6b. What does a surge actually do to the chest? — **ANSWERED**

Replaces the earlier "how much weaker is un-aimed than aimed," which assumed the
wrong mechanism.

**Answer: nobody can place, move, or withdraw anything during a surge. Every body
the stream spawns is stamped with a randomly selected third of the team's
upgrades.**

So the stream is a shuffled deck walking down a lane: this body carries a third
of the chest, the one behind it a different third, and neither is the combination
the team spent the match assembling.

**It does not make a team weaker.** A third of a large chest is still large. **It
makes them incoherent.** The three upgrades that worked together in the top lane
are all still on the field, just never on the same soldier twice running. What a
surge takes is not strength; it is the *arrangement*, which is the only thing in
this game a team actually built.

And it is self-balancing in a way a flat penalty is not: a team with twelve
upgrades has a great deal disturbed by scattering, and a team with three has
almost nothing. **The surge disrupts in proportion to how much there was to
disrupt** — the right shape for the design's only brake on a snowball.

Boons are the exception: no slot, never scattered, on every body in every phase.
They are the only thing that stays coherent through a surge.

When the surge ends, everything is dumped into the chest unplaced, and the
scramble to re-place it happens under the challenge with a monster walking.

**Changed:** [014](014-the-siege-surge.md), [009](009-the-shared-upgrade-pool.md), [005](005-waves-and-when-one-is-finished.md), [003](003-the-simulation-tick.md), [001](001-what-this-game-is.md), issues 602, 603.

## A6b-i. Exactly one third, or one-in-three each? — **ANSWERED**

**Answer: neither. The chest is dealt across the three bodies spawning that
instant, like a hand of cards.**

The question assumed each body draws independently. It does not. All three lanes
spawn on **one shared timer**, so at every spawn there are exactly three new
bodies — one per lane — and the whole chest is split between them:

1. Pick a **random starting lane** from the `surge` stream.
2. Walk the chest in random order, handing each upgrade to the next lane's body
   in rotation until every upgrade has been dealt.
3. Spawn the three with what they were dealt, plus every boon unconditionally.

Each body ends up with ⌊N/3⌋ or ⌈N/3⌉ upgrades. **Every upgrade you own is on the
field at every instant**, and no two of the three carry the same one.

The **random starting lane** is not decoration. When the chest does not divide by
three, one body gets one fewer — and starting at a random lane each time means
which lane comes up short **rotates**, rather than the top lane being permanently
a little poorer for the whole surge. A real fairness bug, avoided by one call
into a stream.

### Why this is better than either option offered

Independent draws would waste the chest: some upgrades would land on nobody in a
given instant, and a large chest would be represented on the field only on
average. Dealing guarantees **everything is always out there.**

And it produces the intended effect more exactly. A surge does not make a team
weaker — nothing is held back — **it makes them incoherent**, and it flattens the
lanes perfectly, since each receives a third of everything. A team that had
stacked one lane suddenly has three mediocre ones. The careful asymmetry they
spent the match building is replaced by an even smear, which is precisely what
the surge is for.

**Changed:** [014](014-the-siege-surge.md), issue 603 (rewritten and renamed), issue 601's phase table, [003](003-the-simulation-tick.md).

## A6c. "The towers aren't in play" — how far does that go? — **ANSWERED**

**Answer: towers shoot, at their baseline values, but cannot be destroyed and
spawn no guards. The guard production moves to the base and emerges as ordinary
stream bodies.**

| | Normally | During a siege-surge |
| --- | --- | --- |
| Shoots | yes, with its stone upgrades | **yes, at baseline** |
| Can be destroyed | yes | **no** |
| Spawns guards | yes, at its own node | **no** |
| Its guards | patrol the tower | **spawn from the base as stream bodies** |

**Invulnerability is what stops a surge being a siege window.** A team with the
stronger stream would otherwise use the phase to take stone cheaply while
everything was chaotic, and the surge would become a reward for already winning
rather than a disruption of it.

It also means no tower falls during a surge, so the three-upgrade tower reward
never fires — and with no discrete waves to finish off either, **the chest does
not grow at all during a siege-surge.** It is the one stretch of the match where
nothing is earned.

**Guard production moving to the base** is the detail worth telling players: your
patrols do not stand around during a surge, they walk out and join the flood. The
defence goes to meet the fight instead of waiting at home for it, and the ground
around your towers — normally the most dangerous on the map — is briefly empty.
Those bodies are stamped like every other stream body, with a share of the chest
dealt three ways rather than the stone upgrades they carry in any other phase.

**Changed:** [007](007-guard-towers-and-their-guards.md), [014](014-the-siege-surge.md), issues 602, 603.

## A7. During a surge, does slotting into stone count as "placing into a lane"? — **MOOT**

The rule this question was about **no longer exists.** The vision describes one —
"a player can't place an upgrade in the same lane twice in a row" — and it was
cut as arbitrary.

Nothing replaces it. The surge already deals every upgrade evenly across all
three lanes, which does the same job of stopping a player from owning one lane
and going blind to the others, without a rule anybody has to be told about.

This entry is kept only so that nobody re-derives the rule from the vision and
puts it back. See [the roadmap](019-roadmap.md), "what is deliberately not in any
phase."
## A8. Is the boon handed over, or chosen from several? — **ANSWERED**

**Answer: chosen, from three, by each player individually — and it arrives at a
different moment than anybody expected.**

**A boon is payment for slaying a challenge monster, not for surviving a surge.**
That relocation is the important half of this answer.

When both of a challenge's monsters are dead, the phase moves to **the calm** — a
new, short phase in which **nothing spawns**. Whatever is on the field fights it
out and thins, and in that window each player picks a boon from three offers, and
the team re-places the chest that was dumped out when the surge ended.

### Why the calm exists

Three people each picking from three options is a lot of choosing. Handing that
out at the moment a monster appears would be a menu opening while something
enormous starts walking — three lists to read, with a deadline, at the most
frightening point in the match. Paying it for the **kill**, in the quiet
afterwards, makes it a reward you get to enjoy.

That is worth protecting explicitly: **if the calm ever gets shortened for
pacing, the boon choice stops being a choice and becomes a thing you click
through.**

It also gives the match a shape it did not have. A surge no longer *ends in a
reward*; it ends in an empty board and a monster. The reward comes after, if you
earn it, with room to enjoy it — and then normal play resumes. Tension, then
release, twice.

### It happens twice, not three times

After the Pillar Orc and after the Field Dragon. **Never after the Eternal
Golem**, which is never slain — so there are six boons per team over a full
match, and the third challenge pays nothing at all. The endgame has no calm, no
boon, and no economy: whatever you have when the third surge ends is what you
finish with.

**Changed:** [015](015-boons-and-the-challenge.md) (rewritten), [014](014-the-siege-surge.md), issue 605 (rewritten and renamed), issue 601's phase table gains a row.

## A8b. How long is the calm, and does it really stop spawning? — **ANSWERED**

**Answer: thirty seconds to a minute, spawning stops, and every soldier still on
the field walks home.**

Not a drain, not a thinning — a **withdrawal.** Every body reverses, walks back to
its own base, and leaves the game. Nobody fights on the way. The map empties out.

Two reasons, and the second is the bigger.

**It makes the calm actually calm.** A quiet minute with a frontline still
grinding in it is not a quiet minute; it is a minute where you are supposed to be
choosing and are actually watching a lane collapse. Draining the map is what turns
the window into a reward rather than a distraction.

**It resets the frontlines to nothing.** After each of the first two challenges,
both teams start pushing again from their own bases with whatever stone is still
standing. A match therefore has **three fresh starts** rather than one long
accumulation — the territory resets, the stone does not, and the chest does not.
**What carries forward is what you built, not where you happened to be
standing.**

That is a large structural statement about what a match *is*, and it arrived from
a question about a menu.

Implementation consequence: push depth measures where a team's **living**
soldiers are, not a high-water mark, so a calm drops every lane's push depth back
to the base. The incremental maintenance from issue 102 is not enough — the calm
is the one moment in a match where the frontline moves backwards for everybody at
once, and it needs a full recompute at the end.

The duration is a balance value from the first commit, because it will be changed
several times and can only be found by watching people use it. **It is the only
phase in the game whose entire purpose is to be comfortable**, which makes it the
easiest one to ruin by trimming it for pacing.

**Changed:** [015](015-boons-and-the-challenge.md), [014](014-the-siege-surge.md), [002](002-the-map-and-its-milestones.md), issue 605.
## A8c. What if one team's monster dies long before the other's? — **ANSWERED**

**They wait, and they get nothing for it.** See F14: a team whose monster dies
sends its bodies home immediately, so there is no free push up the centre to be
had. Finishing first buys time, not tempo.


The challenge ends when *both* are dead, so the faster team waits. Their reward
for finishing first is a free push up the center while the enemy is still busy,
which may be enough — or may make the wait feel like a punishment for winning.
## A9. What exactly happens if a challenge monster is not stopped? — **ANSWERED**

**Vision:** "If they don't defeat it in time, well, game over."

**Answer: the team whose library the monster destroyed loses. That team only.**

There is no separate timer. The deadline is how long the monster takes to walk to
your library; if it arrives, it fells the library, and the ordinary win condition
does the rest. There is no special game-over path anywhere in the challenge code
— if one appears during implementation, something has gone wrong upstream.

Each monster is aimed at one base, so the two challenges run in parallel and are
scored independently. One team can fail while the other succeeds. This is not
co-op; it is two simultaneous solo tests running in the same corridor.

The rejected alternative was that *both* teams lose if either monster arrives,
which would have turned the challenge into a co-operative interlude between two
enemies. That is a genuinely striking idea and it is recorded here rather than
deleted: **if the challenge turns out flat in playtesting, this is the first
place to look.**

The walk-as-deadline also survives on its own merits. A timer is a number on a
panel; a monster walking down the center lane is a thing you can see. A player
who has never read a rules screen knows exactly how long is left, because the
time left is distance.

**Changed:** [015](015-boons-and-the-challenge.md), [008](008-the-base-and-the-library.md), issues 606 and 608, phase-6 progress.
## A10. When lanes funnel into the center, whose upgrades do those soldiers carry? — **ANSWERED**

**Answer: by spawning lane.** A soldier redirected into the center is stamped with
the upgrades of the lane it was *spawned for*, not the center's.

So placing into the top lane during a challenge still means something — you are
strengthening one of three groups converging on the middle, and a team that
invested heavily in one lane does not watch that investment evaporate for the
duration.

The rejected reading was *everything to everyone* — all of the team's upgrades on
every soldier in the central wave. Simpler and more legible, and it would have
made placement irrelevant for the duration.

The cost of the chosen answer is **legibility**: three soldiers walking side by
side in the same corridor can have wildly different strength, and there is no
obvious way to draw "this one is carrying the top lane's build." The viewer owes
this a marker of some kind — see issue 702.

It also preserves something the vision blesses explicitly. A team that stacked
everything into one lane does not watch that investment evaporate for the
duration of a challenge; it arrives in the middle, concentrated, on a third of
the bodies.

**Changed:** [015](015-boons-and-the-challenge.md), issue 607, phase-6 progress.

## A11. Does the chest deplete, or can the same upgrade be drawn forever? — **ANSWERED**

**Answer: with replacement. Duplicates stack. And both teams have access to
exactly the same choices.**

The catalogue is never depleted; a kind can be drawn any number of times; three
instances of the same kind can sit in three different lanes or stack in one.

The stated reason is the design thesis, and it is worth quoting the shape of it:
**what a team chooses determines who wins, because you are crafting a better
strategy than your foes.** Both sides are drawing from the same table with the
same weights. Nobody gets access to a card the other side cannot have. The only
thing that differs is what you do with what you got.

That is the same principle that made the map exactly symmetric and put the surge
on a visible clock: **remove every source of asymmetry except decisions.** If a
team is ahead, it is ahead because of placements, not because of luck of the
draw.

**Changed:** [009](009-the-shared-upgrade-pool.md), issue 403.

## A11b. Does "the same choices" mean the same *draws*? — **ANSWERED**

**Answer: yes — one deck for the whole match, both teams drawing from it in the
same order. Plus a way to buy your way off it.**

Team 1's fifth draw and team 2's fifth draw are the same kind. The deck is a
sequence generated once at match start from the catalogue's weights; each team
holds an **index** into it, not a stream of its own. A team that is killing more
reaches its fifth draw sooner, so **the leader is ahead on the same track**
rather than holding different cards.

That removes the last source of asymmetry in the design that is not a decision.
The map is exactly symmetric; the spawn intervals are identical; the surge is on
a clock both teams can see; and now the upgrades are the same upgrades in the
same order. **If a team is ahead, it is ahead because of placements.**

It also makes the enemy's chest legible with no interface for it at all. A team
four draws behind is holding **your own chest from two minutes ago.** You know
exactly what they have, because you had it. What you do not know is where they
put it — and that is the only thing worth not knowing.

### And the reroll

**A player may spend personal resource to send one of their team's upgrades to
the bottom of the deck and immediately draw the next card.**

This is **the only exchange between the two economies in the whole game**, and an
earlier draft of this documentation stated flatly that no such exchange existed.
It does now. It runs one way, and it is deliberately a bad deal:

- It does not buy an upgrade — the instance count is unchanged.
- It does not buy a *better* upgrade — you get whatever the deck says is next.
- What it buys is **deviation from the shared sequence.**

So the exchange rate is not chest-for-wallet. It is **certainty-for-heroes.** You
spend bodies you will never field in order to stop holding a card you do not
want, knowing the enemy holds that same card, may keep it, and may be right to.

Every reroll is a hero that never existed.

Mechanically the rerolled kind is appended to that team's own tail of the deck
and the team's index advances by one. **The other team's deck is untouched** —
so the two sequences agree until somebody pays to break them, and from then on
the divergence is exactly the record of who paid what.

Full mechanics in the new issue 411.

**Changed:** [009](009-the-shared-upgrade-pool.md) (rewritten drawing section), [011](011-commanders-and-personal-resource.md), [016](016-players-teams-and-commands.md), issues 106, 403, 503, and new issue 411.

## A11b-i. Can you see the next card before paying? — **ANSWERED**

**Answer: no. You pay into the dark.**

You know exactly what you are discarding and nothing about what you are getting.
A reroll is a **gamble** — the one place in a design that has systematically
removed luck where luck is deliberately put back.

The rejected alternative, showing the card, would have made the reroll a
calculation, which is what the rest of this design consistently prefers. It was
rejected because a visible next card turns *should I reroll this* into *should I
reroll this **now***, and a player would sit reading the deck waiting for it to
line up. **The deck is meant to be received, not farmed.**

Interface consequence: the panel shows what is being given up, clearly, and shows
**nothing at all** about what is coming. No card back, no hint, no rarity, no
count of what remains — anything that lets a player narrow the next card partially
reintroduces the farming behaviour at a fraction of the information.

It also makes A11b-ii harder rather than easier. A player paying into the dark is
buying a **distribution**, so the price has to be judged against the catalogue's
average rather than against any particular outcome.

**Changed:** [009](009-the-shared-upgrade-pool.md), issue 411.
## A11b-ii. What does a reroll cost? — **ANSWERED**

**Answer: a flat price, roughly that of the cheapest hero on a roster.**

One reroll equals one small body. That states the tradeoff in the most direct
terms available and needs no explaining at all — a player deciding whether to
reroll is deciding whether they would rather have had a soldier.

Defining it against a catalogue entry rather than as a loose number also means it
tracks hero pricing automatically: retune the cheap hero and the reroll retunes
with it.

The rejected alternatives were a fraction of the ceiling, which now moves (A16b)
and would have made the price wander, and an escalating cost per reroll, which
would have made the fifth reroll a different decision from the first for reasons
a player has to be told about rather than shown.

See A16c for the one thing this creates: a flat price against a rising ceiling
means rerolling gets cheaper in real terms as a match runs.

**Changed:** [009](009-the-shared-upgrade-pool.md), issue 411.

## A11b-iii. Does this make the hero snowball worse? — **ANSWERED**

A team that is winning earns more, so it can both field more heroes **and** reroll
more. Resource has two sinks and a winning team can afford both. Recorded against
C3, which is already tracking the hero economy as the design's one unbraked
snowball.

## A12. Do objections expire? — **ANSWERED**

**Answer: yes, after a timeout.**

An objection left over from four minutes ago cannot combine with a fresh one to open a
lock nobody currently objects to.

Expiry is what keeps two objections a **decision** rather than an **accumulation**.
The two objections have to overlap in time, which means two people looked at the
same thing and disagreed with it at the same moment — which is what the two-key
rule is claiming to represent.

Without expiry, every lock on a long match eventually collects enough stray objections
to pop on its own, and the rule quietly degrades into a one-key rule that fires
late, for no reason anybody can point at, on an upgrade nobody was arguing about
any more. That is worse than having no rule, because it looks like a rule.

The timeout is a balance value: too short and two teammates who are not watching
each other can never coordinate an unlock at all; too long and it stops doing its
job.

**Changed:** [009](009-the-shared-upgrade-pool.md), issue 407.

## A13. Can a player lock every upgrade the team owns? — **ANSWERED**

**Answer: yes. Locking is unlimited and free.**

No cap, no cost, no decay. One player locking every instance the team owns is
legal, and their two teammates can undo it — slowly, one instance at a time,
through the two-objection rule.

The rejected alternatives were a cap of two or three per player, which would have
made a lock a scarce statement, and locks that decay on a timer, which would have
dissolved an inattentive player's claims without anyone having to fight them.
Both add a rule to explain in exchange for defending against a griefing case that
a team can already handle.

What it means for how the system reads: **a lock is not a permission, it is a
sentence.** "I am doing something here." Saying it about everything is a coherent
thing to say — *I have a plan for the whole board* — and it is answerable, at the
cost of your teammates having to disagree with you deliberately, one placement at
a time. That cost is the conversation, not an obstacle to it.

The interface should show a player how many things they currently have locked,
prominently, because the failure mode here is not malice but forgetting.

**Changed:** [009](009-the-shared-upgrade-pool.md), issue 406, phase-4 progress.
## A14. Do upgrades apply to hero units, or only wave units? — **ANSWERED**

**Vision:** calls them "unit upgrades" and describes them applying to waves.

**Answer: only wave units. Never heroes, and there is no per-kind exception.**

There is no hero bit in `applies_to`, and no way to write one. A hero walking
through a lane stacked with every upgrade the team owns fights at exactly its
catalogue values. The rule is enforced by the catalogue's structure — a two-bit
field, a validator that refuses anything outside {1, 2, 3}, and a mask-stamping
routine that returns zero for any flavour that is not a wave unit — rather than
by everybody remembering it.

**What it protects:** the two economies must not multiply. If a lane's upgrades
also pumped the heroes standing in it, a team could stack every upgrade into one
lane, buy every hero into that same lane, and get a compounding payoff for a
decision it only had to make once. The game would collapse into whichever lane
the team picked, and the other two would be a formality — the exact failure the
surge's even dealing of upgrades across all three lanes exists to prevent,
arriving through a different door.

**The price, accepted:** legibility. A hero fighting alongside enormously
upgraded wave units looks strangely unaffected by whatever is making them
enormous, and there is no obvious way to draw "this body is exempt."

**What it leaves:** the only interaction between a player's spending and their
team's chest is **indirect, through play.** A hero that turns a stalled enemy
queue into a wipe has just bought its team an upgrade draw. That is the only
exchange rate between the two economies, it runs one way, and it has to be
earned.

It also simplifies A10 — the question of whose upgrades a soldier funnelled into
the center carries during a challenge — down to wave units only.

**Changed:** [009](009-the-shared-upgrade-pool.md), [004](004-a-unit-and-what-it-carries.md), [012](012-hero-units.md), issue 401, phase-4 progress.
## A15. Are boons per team or per player? — **ANSWERED**

**Answer: one per player, three per team per challenge, and each is chosen from
three offered.** Answered together with A8; see there for the timing, which is
the more consequential half.

Six boons per team over a full match — three players × two survivable challenges,
since the Eternal Golem is never slain and pays nothing.

**A boon is also the one thing in the game that belongs to a person.** Everything
else in the chest is team property that any teammate can move. A boon is chosen
by you, permanent, unmovable, and applies to everything your team puts on the
field. In a design built almost entirely out of shared property and negotiation,
each player gets exactly **two moments of sole ownership per match**, and both
are paid for by killing something enormous.

Mechanically that means an upgrade instance gains an `owner` field for the first
time — set only on boons, 0 on everything else.

**Superseded on the offer question by F5.** This entry originally drew offers
**per player**, so that two teammates seeing the same boon was a happy accident.
One pair is now drawn per *event* and every player on both teams is offered that
same pair, for parity — see F5. Everything else here stands.

**Changed:** [015](015-boons-and-the-challenge.md), [014](014-the-siege-surge.md), issue 605 (rewritten and renamed), phase-6 progress.
## A16. Is there a limit on how many heroes one player can have alive? — **ANSWERED**

**Answer: no cap on heroes. A cap on the wallet.**

A player's resource balance has a ceiling, and income arriving at the ceiling is
**lost** — not stored, not carried, not converted. Spend it or waste it.

That is a better limiter than a hero cap, and the difference is the difference
between a rule and a pressure.

**A hero cap says no.** It refuses a purchase, at the moment a player has decided
to make it, for a reason that has nothing to do with the situation in front of
them. Arbitrary in exactly the way this game's rules try not to be.

**A ceiling says now.** It never refuses anything. It just means a player sitting
on a full wallet is **actively losing** every kill their team lands, and the only
way to stop losing is to act. Nobody is told what to do; they are told that doing
nothing costs something.

Three consequences:

- **Hoarding through a surge stops working.** The bank-two-surges-and-drop-six-
  heroes play is not forbidden; it is impossible, because you cannot save that
  much.
- **The fast layer becomes genuinely constant.** There is no phase where ignoring
  your wallet is correct, because ignoring it is spending it on nothing.
- **Rerolls become the overflow valve.** A player at the ceiling with nowhere good
  to put a hero has a second sink — pay to send an upgrade to the bottom of the
  deck. Resource that would have evaporated buys a chance at a better chest
  instead, which is a far more interesting thing to do with a full wallet than
  buying a hero you do not need.

A player at or near the ceiling must be told, loudly and continuously. **An
invisible overflow is a punishment nobody can see**, which is the worst kind.

**Changed:** [011](011-commanders-and-personal-resource.md), [012](012-hero-units.md), issue 503.

## A16b. What is the ceiling? — **ANSWERED**

**Answer: it is not one number. It starts tight and grows as the match goes on.**

Early on the ceiling is barely more than your most expensive hero: you are
spending almost constantly and overflowing the moment you hesitate. By the end it
is large enough that a deliberate spike is a real play — bank for a minute and put
four bodies on the ground at once.

That resolves the tension the question was built on. The two constraints — afford
your best hero with room to think, and make a surge un-bankable — were not both
satisfiable by a fixed number. They are satisfiable by **different numbers at
different times.**

**Working ruling on when it rises: at each calm**, alongside the boons. Two calms,
two raises. That ties the wallet's growth to the same events that grow everything
else, so a match escalates in one rhythm rather than three, and the ceiling steps
up **in front of the player** rather than creeping. The alternative — continuous
growth against the match clock — is smoother and much harder to notice happening.

Two things fall out that nobody chose and both look right:

**The endgame becomes a fill-the-tank moment.** The third challenge has no income
at all, so whatever a team banked before the third surge is the last resource it
will ever have — and by then the ceiling is at its highest. The Eternal Golem is
fought with a wallet that will never be topped up again.

**It matches the boons.** Both economies accumulate a floor as a match runs, so
the late game is simply bigger than the early game on both axes, and a mistake
late costs more than the same mistake early.

**Changed:** [011](011-commanders-and-personal-resource.md), issue 503.

## A16c. Does the rising ceiling make rerolling cheaper over time? — **ANSWERED**

The ceiling grows and a reroll's price is **flat** (A11b-ii), so rerolling gets
cheaper in real terms the longer a match runs, and late chests end up better
shaped than early ones.

That is probably right — with a shared deck, late rerolling is the main way two
teams holding the same cards end up holding different ones — but it is a curve
nobody chose deliberately, and issue 804 should be watching it.

## A17. Can heroes be bought during a challenge and the calm? — **ANSWERED**

**Answer: yes in every phase. During the calm the hero waits at your library.**

There is no phase in which purchasing is closed. During a siege-surge and during
a challenge, heroes arrive normally — they are a real answer to a monster, and
during a surge they are one of only two things a player can still do.

The calm is the exception only because the map is emptying: every soldier is
walking home, so a body spawned then would have nowhere to go and nothing to
fight. A hero bought during the calm **stands at the library until spawning
resumes**, and marches out with the first wave of the new phase.

That turns the calm into the one moment a player can deliberately build an
**opening push**: thirty seconds to a minute, a wallet that has been filling while
nobody could spend it, and a map about to be empty in both directions. What you
buy in the calm is what walks out first.

Implementation: heroes bought during the calm need a **waiting** state — the body
exists, stands at the library, and does not move or acquire until the phase
changes.

**Changed:** [012](012-hero-units.md), issue 503.
## A18. Do upgrades reach a tower's guards? — **ANSWERED**

Surfaced by A14's answer. Guards are `flavour = 3` — neither wave units nor
heroes — so nothing existing covered them.

**Answer: a guard is stamped at spawn with the stone upgrades of the lane its
tower stands on.** `tower_mask[lane]` for a lane tower; `base_tower_mask` for a
base tower, which is the union of all three lanes' stone plus the library.

Stamped at spawn, like a wave unit, because a guard is a short-lived body and the
mask is read on every swing. The *tower* reads live, because it stands for the
whole match. Those two rules sit next to each other and each needs a comment
saying why it is not the other one.

**Slotting an upgrade into a lane's stone therefore buys bodies as well as
arrows**, which compounds with A5 — an investment the enemy already cannot take
away now also puts stronger soldiers on the ground.

That pushes directly against A5's balance instruction, which was that stone must
be *worse at pushing a frontline* than soldiers are. The reconciliation is that
**guards are leashed.** A stone upgrade buys a better wall; it still cannot buy a
step forward, because a guard will not take one. That distinction is the only
thing keeping the two slots meaningfully different, and **if leashing is ever
loosened, this is the rule that breaks first.** It belongs in a comment above the
leash check.

Consequence for the numbers: guard count per tower is now a multiplier on every
stone upgrade, so B10 stopped being only a question about how hard a tower is to
walk past.

**Changed:** [007](007-guard-towers-and-their-guards.md), issue 303.

---

# Group B — Numbers nobody has picked yet

None of these belong in prose; they belong in catalogue tables with a validator.
And **none of them is answered by thinking** — they are found by running the
thing and looking at what happened, which is why every entry below is marked
*awaiting evidence* rather than open. They are not a backlog of decisions nobody
has made. They are a list of measurements nobody has taken.

What thinking *can* do, and what the rest of this section now does, is decide
**what each number is measured against.** A figure chosen against another figure
moves with it and stays coherent; nine figures chosen independently drift apart
the first time one of them is retuned, and then nobody can say why the game feels
wrong. The project already does this in three places — a library is one and a half
towers, a hero is two and a half wave units, a reroll is one cheap hero — and the
rest should follow the same discipline.

So each entry below names an **anchor**. The first run picks one absolute number
per cluster and derives the rest.

### The anchors

**The wave is the clock.** Everything about pacing is expressed in waves, because
a wave is the thing a player can see arriving. Ticks are the unit underneath and
seconds are never used.

**A wave unit is the unit of strength.** Everything that fights is priced in wave
units — a hero is 2.5 of them, a tower is some number of them, a monster is a
great many. One archetype's numbers are chosen and the rest are ratios.

- **B1. Wave interval and wave size.** *Awaiting evidence.* The interval is the
  anchor for all pacing and should be picked first, from watching a frontline
  form. Wave size follows from lane width: a wave should be **wider than the lane
  can fit abreast**, so that ranks queue and the frontline reads as a wave rather
  than a line. If it is not, the frontline queue from issue 206 does nothing
  visible.
- **B2. Surge length and stream rate.** *Awaiting evidence.* Anchored to B1 as a
  **ratio, not a figure**: the stream should put bodies down often enough that the
  lull between waves disappears entirely, since that is the whole feel of the
  phase. The current estimate is roughly twenty to thirty times the wave rate, one
  body at a time — see `docs/balance-updates.md`. Surge length is anchored to B6:
  long enough that a team's arrangement genuinely stops mattering, short enough
  that nobody is bored.
- **B3.** ~~The reassignment cooldown.~~ **Gone**, and what remains is *awaiting evidence* — replaced by the one-wave
  transit from D3. The wave *is* the cost. What remains is *awaiting evidence*:
  the calm's length, anchored to how long it actually takes three people to read
  two boons and re-place a chest, which is a stopwatch question and nothing else.
  The reroll price is already derived (A11b-ii, the cheapest hero).
- **B4. The command radius.** *Awaiting evidence.* Now one circle doing two jobs
  (F2), so it is anchored to **the distance a wave covers between spawns** — the
  radius should be small enough that reaching it is an act and large enough that
  standing in it is not accidental.
- **B5. Resource per kill, by flavour.** *Awaiting evidence.* Anchored to the
  hero roster: **a player's income across one wave-and-a-half of ordinary trading
  should buy the cheapest hero.** That single relation sets the pace of the whole
  second economy, and every other payout is a multiple of the wave-unit figure.
- **B6. Match length, and waves before the first surge.** *Awaiting evidence.*
  The top anchor. Everything about escalation — three surges, two calms, two
  ceiling raises — divides this number, so it is chosen first in wall-clock terms
  and then expressed in waves via B1.
- **B7. Catalogue size and weights.** *Awaiting evidence.* No longer capped by an
  integer's width (F3), so this is chosen on **legibility**: few enough that a
  player recognises what is on an enemy soldier at a glance, since reading the
  frontline is the only way to learn an opponent's arrangement.
- **B8. Boon count and strength.** *Awaiting evidence*, with one design
  constraint that is not a number and belongs here anyway: because every player
  on both teams is offered the same pair (F5), **an imbalanced pair is not a dull
  choice, it is a null event** — all six players correctly take the same one and
  nothing distinguishes anybody. The catalogue must be flat enough that the pick
  is about *fit* rather than about which is stronger. That is a harder bar than
  an ordinary upgrade catalogue has to clear.
- **B9. Challenge monster health.** *Awaiting evidence.* Anchored to what a team
  can field at that point in the match rather than to an absolute — which means
  it cannot be chosen before B5 and B6 are, and it is different for each of the
  three. The Golem has no health figure at all (F19 era: health is speed), so
  what it needs instead is a **regeneration curve**, anchored so that the
  equilibrium speed under a full team's sustained output is slow but not zero.
- **B10. Guard cap and replacement rate.** *Awaiting evidence.* The cap matters
  more than it did: guard count is a **multiplier on every stone upgrade** (F21),
  so this is not only a question about how hard a tower is to walk past.

## B11. Does the frontline actually move? — **AWAITING EVIDENCE**

Not a number, but it is answered by numbers, and it is the question the whole
project exists to answer. The vision's premise is that a subtracted lane-pusher
stalemates. **Nothing in these documents proves that upgrades, heroes and surges
are enough to unstick it.** The phase-2 demo is supposed to show the stalemate
and the phase-4 demo is supposed to show it broken; if phase 4's demo does not
visibly break it, the design is wrong and no amount of tuning fixes it.

Issue 804 — ten thousand matches overnight — exists to answer this.

### First evidence, from the prototype

Both halves of the premise now reproduce, on a machine, from one seed. This is
not the ten thousand matches and does not close the question; it is the first
measurement, and it points the right way.

**The stalemate is real.** A headless match with nobody placing anything runs for
twenty-two minutes and goes nowhere: both teams sit between milestones three and
four in every lane, hundreds of waves are spawned and wiped, and the frontlines
oscillate around the midpoint without either side taking a base. That is the
vision's problem statement, rendered — units walking toward one another, fighting
in the middle, barely moving the frontlines at all.

**Placement breaks it, and by a wide margin.** From the same seed, with one team
shovelling everything it draws into the centre lane, that lane reaches milestone
**8** — the enemy library — while the other team's depth in it collapses to
**0**. The other two lanes stay where the untouched match left them, which is the
control the comparison needed.

So the chest is not a marginal modifier. It is the difference between a match that
cannot end and a match that ends decisively, which is what the design claimed and
what nothing had yet shown.

Two cautions carried forward, both raised as their own questions rather than left
in this answer: the chest fills far faster than the evidence assumed (**G4**), and
a lane that is stacked without limit currently wins without any counterplay in the
prototype, because heroes, surges and challenges are not built yet.

---

# Group C — The shape of a match

## C1. What triggers a siege-surge? — **ANSWERED**

**Vision:** "every once in a while."

**Answer: a fixed match clock, with the countdown visible to both teams.**

The surges fall at known ticks and everybody can see how long they have. The
alternatives were a hidden clock and a trigger tied to the state of the game
(total kills, deepest push, towers felled), both of which would have made each
surge genuinely disruptive and both of which are closer to the literal reading of
"every once in a while."

The visible clock was chosen because it buys something the hidden versions
cannot: **a surge becomes an event a team plays toward.** The minutes before one
are their own phase of the match, with their own decisions, because everybody
knows what is coming. A hidden trigger produces one interesting moment; a visible
one produces an interesting approach to that moment, three times. It also fixes
the match's structure into an arc a player can narrate afterwards, which a random
interruption cannot.

**Changed:** [014](014-the-siege-surge.md), issue 601, phase-6 progress.

## C1b. Does a visible clock let a team dodge the chest-emptying? — **MOOT**

The question assumed a surge empties the chest. After F11 it does not empty
anything, and the deal reads every upgrade a team owns whether it is placed or
not — so holding upgrades back before a surge buys nothing at all. The original
reasoning is kept below because the pre-surge hold was a real behaviour to think
about, and it may come back if the deal ever stops reading unplaced instances.


Created by C1's answer, not settled by it.

If everybody can see the surge coming, the optimal play shortly beforehand is to
**stop placing upgrades and let them sit in the chest**, because anything placed
is about to be yanked back anyway. A team that does this walks into the surge
with a full chest and loses nothing to the emptying — which partly defuses the
mechanism the entire surge exists for.

Three ways out, and no obvious winner:

1. **Bless it.** The pre-surge hold becomes a legitimate skill, and the cost of
   holding is that your soldiers are unmodified for the last few minutes before
   the surge, which is a real price.
2. **Make holding hurt more.** Unplaced upgrades could be worth something to give
   up, or a lane with nothing in it could be more dangerous than it currently is.
3. **Narrow the window.** The clock is visible all match but the exact tick only
   firms up shortly before, so the hold cannot be timed precisely.

Option 1 is the cheapest and may simply be correct. It should be watched for in
issue 804 rather than pre-empted.
## C2. What ends a match that survives all three challenges? — **ANSWERED**

**Answer: the third challenge is always the Eternal Golem, it cannot be killed,
and it advances until a library falls.**

| | Ordinary monster | Eternal Golem |
| --- | --- | --- |
| Health | very large, finite | **infinite** |
| What damage does | removes health | **removes speed** |
| Recovers | no | **yes, rapidly** |
| Stops to fight | briefly | **never — fights on the move** |
| Ends when | it dies | **a library falls** |

Damage slows it; it recovers speed rapidly; keeping it slow therefore requires
**continuous** damage rather than a burst.

That single inversion is the whole endgame, and it needs no new systems — same
damage arithmetic, same soldiers, same upgrades, pointed at a number that heals.
**Every other fight in this game is an accumulation**: you chip a thing down and
the progress you made is progress you keep. The Golem is the one fight where
progress is not kept. You are not reducing something, you are holding something
back, and the moment you stop holding it is exactly as fast as it was before you
started.

The match is therefore bounded without a time limit, a scoring rule, or a
surrender. Once the third surge ends there is a hard guarantee the game finishes,
and every player can see the reason walking down the middle of the map.

**Two changes came with it**, both propagated:

- **Challenges use waves, not the surge's stream.** The lull between waves is
  what lets the Golem lurch forward before the next wave lands on it. A stream
  would pin it indefinitely. The endgame's pulse is slow, lurch, slow, lurch.
- **The center lane is topographically wider than the side lanes** —
  permanently, not just during a challenge — so a monster can fight a whole team
  at once rather than a single file waiting its turn to die. The permanent
  consequence is larger than the immediate one: **the center is where numbers
  matter most**, which is the only real difference between the three lanes and
  is one number in the map builder.

**Changed:** [015](015-boons-and-the-challenge.md), [002](002-the-map-and-its-milestones.md), [014](014-the-siege-surge.md), issues 601, 606 (rewritten and renamed), 607, 608, 206.

## C2b. One Golem, or two? — **ANSWERED**

**Answer: two. One per team, matching the first two challenges.**

Each team holds back its own; the two never interact; **the winner is whoever
held longest.** The endgame is two solo endurance tests running side by side in
the same corridor.

The rejected alternative was a single shared Golem as a tug of war, advancing
toward whichever team was doing less to stop it — the only mechanic in the whole
design where two teams would act on the same object at the same time. It is
recorded rather than deleted: **if the endgame plays flat, that is the first
place to look.**

**Also settled with it: the three challenges are a fixed, named sequence.**

| | Challenge | | |
| --- | --- | --- | --- |
| 1 | **The Pillar Orc** | killable | ends when both are dead |
| 2 | **The Field Dragon** | killable | ends when both are dead |
| 3 | **The Eternal Golem** | **cannot be killed** | **ends when a library falls** |

Not a random draw. A player who has played one match knows what is coming in the
next and can build toward it — the same reasoning that put the surge on a visible
clock. The escalation is the point: the first two can be beaten, and then the
third one cannot.

**Changed:** [015](015-boons-and-the-challenge.md), [001](001-what-this-game-is.md), issue 606.
## C3. Is the surge the only comeback mechanism? — **ANSWERED**

**Answer: yes, and that is the design. Nothing brakes the hero economy, nothing
is going to, and the snowball is the game showing you who played better.**

No floor, no catch-up term, no rubber band, no cheap hero priced against a losing
team's income. The three options this entry was holding open — bless it, price a
floor, brake it at the surge — resolve to the first.

The reasoning is not that the snowball is harmless. It is that **a competitive
game is supposed to illustrate strength**, and a mechanism that pulls a losing
team back toward a winning one is a mechanism that makes the first ten minutes
not matter. Every system in this design has been built so that a team that is
ahead is ahead *because of decisions* — the shared deck, the symmetric map, the
visible surge clock, one pair of boons offered to everybody. Having removed every
source of undeserved advantage, adding an undeserved rescue would be strange.

Two things make it survivable, and they are already in the design rather than
being added to answer this:

**Heroes do not persist.** A hero advantage is spent the moment the bodies die,
which is ninety seconds. A placement advantage compounds; a wallet advantage
converts into bodies that stop existing. The two snowballs are not the same shape
even though they have the same cause.

**The surge still brakes the half that compounds.** The chest — the thing that
actually accumulates — has its arrangement suspended three times a match. The
wallet does not, and does not need to, because it does not accumulate anything
that outlives a fight.

### The condition attached, which is a requirement and not a hope

Blessing the snowball is only correct **if there are early-game and late-game
strategies that pay off differently depending on what a team drew and where it
put it.** Without that, "no comeback mechanism" quietly becomes "whoever wins the
first two minutes wins," which is not strength being illustrated — it is a race
that ended before anybody noticed.

So this answer puts a **design requirement on the upgrade catalogue**, and it
belongs with B7 rather than being left as a hope:

- The catalogue must contain kinds whose value **changes across a match** — some
  strong immediately and fading as bodies get bigger, some weak on a bare wave
  unit and enormous on a captain in a stacked lane.
- A team that is behind must have **a shape of chest that beats a team that is
  ahead**, available to it, reachable by placement rather than by being handed
  anything.
- If every upgrade is worth the same at minute two and minute twenty, this answer
  is wrong and a floor is needed after all.

That is the thing issue 804 measures. Not "does the leader win too often" — the
leader is supposed to win. **Does a team that fell behind and then out-placed its
opponent ever come back?** If the answer is never, the catalogue is flat, and the
catalogue is the fix.

### The two entries underneath it

**A11b-iii** asked whether the reroll makes it worse, since a winning team can
afford both sinks. It does, slightly, and it is blessed for the same reason —
rerolling is how a team *changes the shape of its chest*, which is precisely the
mechanism the condition above depends on. A losing team that spends its smaller
income on rerolls instead of bodies is doing the thing that can win it the game.

**A16c** asked about a flat reroll price against a rising ceiling, which makes
rerolling cheaper in real terms as a match runs. Also blessed, and for a sharper
reason than before: **late rerolling is the main way two teams holding the same
cards end up holding different ones**, and with a shared deck it is the only
source of chest divergence in the whole design. It getting cheaper late is the
curve that makes a long match interesting rather than a curve nobody chose.

**Changed:** [011](011-commanders-and-personal-resource.md), [006](006-combat-and-damage.md), [009](009-the-shared-upgrade-pool.md), issues 401, 804, and A11b-iii and A16c, which are answered with it.
## C4. How many commanders, and can two teammates pick the same one? — **ANSWERED**

**Answer: a handful — four or five to start — and no two players on a team may
pick the same one.**

A team fields three different rosters, so the three players' hero options never
overlap. Every hero on the field belongs to exactly one player's catalogue, and a
teammate cannot buy what you can.

The consequence worth designing toward rather than discovering: **a team's
composition is chosen in the lobby and cannot be corrected.** If nobody took a
commander with a good answer to stone, that team has no answer to stone for the
whole match. Commander selection stops being a preference and becomes the first
strategic decision of the game, made before anybody has seen anything.

The uniqueness check belongs in the **lobby**, in issue 802, not in the
simulation — the simulation should be perfectly happy to run three identical
commanders so that tests and bot runs can set up whatever they like.

**Changed:** issues 501, 802.

## C4b. How many is "a handful"? — **ANSWERED**

**Answer: as many as there are designs for. It is not a number and it was wrong
to ask for one.**

A commander is not a slot to be filled to a target count. It is a roster of
heroes that has to **reshuffle the jobs** rather than reskin them — something that
holds a frontline, something that kills a frontline, something that kills stone,
recombined so that a second commander answers those needs in a different order
and at different prices. A commander that cannot do that should not ship, and a
commander that can should, however many there already are.

So the constraint is **design effort, not a cap**, and the right question is not
"how many" but "what makes one worth adding." Issue 509 owns that, and it owns it
for every commander rather than for the first.

### The composition arithmetic stops being frightening

The worry recorded here was that with no duplicates per team, a small roster
gives a small number of team compositions — five commanders and three a side is
ten distinct teams, which is a week of exploration rather than a year.

That worry was real and it dissolves as the roster grows, quickly, because the
count is a combination rather than a product:

| Commanders | Distinct 3-player teams |
| --- | --- |
| 5 | 10 |
| 6 | 20 |
| 8 | 56 |
| 10 | 120 |
| 12 | 220 |

Doubling the roster does not double the compositions, it multiplies them by
twenty. **Two more commanders is the difference between ten teams and fifty-six**,
which is the strongest argument available for treating the roster as open-ended
rather than picking four and stopping.

The uniqueness rule that caused the worry is also what causes the payoff — without
it the count would be far larger and far duller, because most teams would be
somebody's favourite commander three times.

**Changed:** issues 501, 509, 802.
---

# Group D — What the player sees and touches

## D1. Which drawing library? — **ANSWERED**

**Answer: LÖVE.**

It is already LuaJIT, so there is **no FFI boundary between the viewer and the
simulation** — the snapshot is read directly, in the same language, with no
marshalling. It brings a window, input, audio, and a sprite batcher, and the
batcher is the one that matters: this game draws hundreds to thousands of
near-identical bodies every frame, and batching them is the viewer's only real
performance question.

The rejected alternative was an FFI binding to something lower-level: more
control over exactly how those bodies get drawn, in exchange for writing the
window, the loop, and the batcher before anything appears on screen at all. That
trade is worth making when the drawing is unusual. This is thousands of small
sprites on a fixed view.

Accepted with it: LÖVE's choices about how a frame works, and its distribution
story.

**This was the last decision in the project with a deadline.** Nothing else is
waiting on anybody.

And the terminal viewer from issue 109 **stays**. Not a stepping stone to be
discarded — it is faster to debug in, works over a connection where nothing
graphical does, pipes to a file and diffs, and it keeps the viewing layer honest
by being a second consumer of the same snapshots. **Two viewers means neither can
quietly become part of the simulation.**

**Changed:** [017](017-the-viewing-layer.md), issue 701, phase-7 progress.

## D2. Do players get any manual control over a hero? — **ANSWERED**

**Answer: no. None at all.** No hold-position, no focus-this, no manually
triggered ability, no targeting cursor.

Once a hero is bought and its spawn destination chosen, the only influence a
player has over it is the sign-post at a junction it has not reached yet — and
sign-posts can only be set in your own half of the map, so a hero past the
midpoint is entirely beyond reach.

This was the biggest single unknown about how the game *feels*, and it was
settled toward the strictest option. What it protects:

- **The one-brain rule.** "Heroes behave like regular units" is what keeps the
  soldier brain the only brain in the game, and in a lane-pusher with the heroes
  subtracted out, that brain is the whole product. Every piece of manual control
  is a behaviour the brain no longer has to be good at, and the end of that road
  is soldiers that are visibly stupider than the things you drive.
- **The chest.** A player's hands are busy placing, locking, and objecting. A hero
  demanding attention would compete directly with the system that replaced heroes.

**What it concentrates the design into: the ability condition table.** With
nothing able to intervene, a hero's entire personality is the predicates deciding
when its abilities fire. Two heroes with identical stats and different conditions
are two genuinely different purchases; two heroes with different stats and the
same condition are the same purchase at different prices. That makes issue 504
considerably more important than its position on the roadmap suggests, and its
condition table must not be three entries deep.

**Changed:** [012](012-hero-units.md), [006](006-combat-and-damage.md), issue 504, phase-5 progress.
## D3. Fog of war — can you see the enemy's chest? — **ANSWERED**

**Answer: you see their upgrades on their soldiers, and nothing else. And moving
an upgrade takes one full wave, which your own teammates can see.**

Three rules, and together they make an information design that nobody had to
design:

1. **Moving takes a wave.** An upgrade does not arrive when you place it. It is
   *marked to move* and takes one full wave to get there, applying at its old
   slot in the meantime. A placement lands two waves after the command.
2. **Allies see the mark.** For that whole wave, every teammate can see the
   instance is in transit and where it is going.
3. **Enemies see only bodies.** Look at the soldiers on the frontline and you can
   read what they were stamped with. You cannot see a chest, a slot, or a transit.

### The fog is made of walking

**An enemy reads your board two or three waves late**, and nothing was hidden to
achieve it. A change has to be marked, transit for a wave, spawn into the next
wave, and then walk far enough forward to be seen. By the time an opponent can
read your new arrangement, you have known it for the better part of a minute.

That delay falls out of rules that exist for entirely other reasons —
stamp-at-birth for performance, the transit wave to make placement a commitment,
and the plain length of a lane. There is no fog-of-war system in this game. There
is a walk.

It also lands exactly where it should, given the shared deck. An opponent already
knows roughly *what* you hold, because they are drawing the same cards in the same
order and can count. **What they do not know is your arrangement** — which is the
only thing in this design worth not knowing, since arrangement is the whole game.

### Marked-to-move is one of the five verbs

A **lock** says *I am doing something here.* An **objection** says *I would like
you to stop.* A **cursor** says *I am about to touch this.* A **ping** says *look
at this place.* And **marked-to-move** says *this is going there*, for a full
wave, to everyone on your team.

Two of the five are involuntary — the cursor and the mark — and those two are the
load-bearing ones. Together they mean **you can see a teammate reaching for
something before they touch it, and see what they did for a wave after.** Locks
and objections are for the cases that survive all that visibility and still need
settling. The canonical list is in
[the shared upgrade pool](009-the-shared-upgrade-pool.md).

**You cannot move an upgrade quietly.** Your teammates get a wave's notice, which
is exactly enough time to say something about it.

### And it replaces the reassignment cooldown

There is no second timer. The cost of moving an upgrade is that it takes a wave,
which is a cost a player can watch rather than a number that refuses them.

**Changed:** [009](009-the-shared-upgrade-pool.md), issue 404, and issue 702,
which now owes a way to draw a soldier's upgrades legibly at frontline distance.

## D3b. Can a move in transit be cancelled? — **ANSWERED**

**Answer: yes, freely, any time before it lands.** The instance stays where it
already was, and it costs nothing.

It is safe to be this generous because **a transit is not a resource.** Nothing
was spent, nothing consumed, and the upgrade has been applying at its old slot
the whole time. Refusing would punish a slip with a full wave of watching a
mistake crawl toward you, for no benefit to anybody.

The honest cost: **the marked-to-move message teammates were reading can
evaporate.** A teammate who saw the mark, decided it was fine, and moved on will
not be told it never happened. So the notice a transit gives is a *statement of
intent* rather than a promise — which is precisely what a lock is for when a
player wants the stronger thing.

New verb: `cancel_move`.

**Changed:** [009](009-the-shared-upgrade-pool.md), [016](016-players-teams-and-commands.md), issues 106, 404.

## D4. Can you see the enemy's sign-posts? — **ANSWERED**

**Answer: no. Sign-posts are hidden from the other team.**

They are physical objects standing in the world, which argues for visibility, and
that argument was rejected — because it is the same argument that would make the
enemy's chest visible, and this design answers it the same way everywhere. **You
learn where their heroes go by watching heroes arrive**, not by reading a sign.
The fog is made of walking, and what an opponent knows about you is what has
physically reached them.

The consequence is that routing is genuinely concealed until it pays off. A team
that has quietly pointed both junctions at the center has committed every future
hero purchase to the middle, and the other side finds out when heroes start
arriving there — several purchases late, with the commitment already a wave or
two deep.

Implementation note worth carrying: the snapshot contains **no direction field**
for the enemy's sign-posts — not a hidden field the viewer declines to draw, an
absent one. A viewer cannot leak what it was never sent, and this is the only
place in the snapshot where a field is withheld by team.

**Changed:** [013](013-signposts-and-lane-routing.md), issues 508 and 705.

## D5. Should sign-posts have locks, like upgrades do? — **ANSWERED**

**Answer: no.**

Any player on a team may set any of that team's two, at any time. Sign-posts are
cheap, instant, and reversible, and a negotiation layer over something undoable
in one click would be ceremony with no stakes underneath it.

What that leaves the viewer owing a player: **a clear, immediate signal when a
teammate changes one.** It will happen without warning and it silently redirects
every hero they have inbound — the only unnegotiated change any player can make
to another player's plans.

**Changed:** [013](013-signposts-and-lane-routing.md), issues 508 and 705.

## D6. Is there a general map ping? — **ANSWERED, and it took the word**

**Answer: yes — and the *upgrade* verb was renamed to make room for it.**

"Ping" now means what players expect it to mean: a marker you drop on the map to
point at a place. The lock-releasing verb is now **object**, and two objections
open a lock.

That is the right way round. Every team game has a map ping and players arrive
already knowing the word; the lock verb is unique to this game and had to be
learned regardless, so it may as well be learned under a name that says what it
does. "Two objections open a lock" explains itself; "two pings open a lock" never
did.

The rename ran through every document and issue: `ping_upgrade` became
`object_upgrade`, `ping_mask` became `objection_mask`, and two issue files were
renamed with it. The new verb is `ping_map`.

Note what this does **not** replace: every player's cursor is already synced and
visible to teammates, so pointing at a place by moving your mouse there already
worked. A ping is the deliberate, persistent version — it stays put for a moment
and demands attention, which a cursor cannot do because a cursor is always
somewhere.

**Changed:** every file mentioning the old verb; [001](001-what-this-game-is.md)'s vocabulary; [016](016-players-teams-and-commands.md); issues 106, 407 (renamed), 704 (renamed).
## D7. One screen for the whole map, or a camera that moves? — **ANSWERED**

**Answer: the whole map by default, always, with zoom to inspect.**

The default is the part that matters. The entire design rests on a player judging
three lanes by looking at them — that is what makes an upgrade "legible from
across the map," one of the three reasons the chest replaced heroes. A view that
starts anywhere else hands the chest panel a job the map was supposed to do.

Zoom exists because there is now real detail worth reading. A soldier carries a
visible record of what it was stamped with, and reading an enemy's build off their
frontline is the only way to learn their arrangement at all — see D3. At whole-map
scale a soldier is a few pixels; you need to be able to lean in.

### One rule for the camera

> **Zoom reveals detail. It never reveals events.**

Anything a player must react to — a tower falling, a surge starting, a monster
appearing, a teammate marking an upgrade to move, a lock breaking, their own
wallet overflowing — must be legible at the default view, with no zoom and no
camera move.

The failure this prevents is the one every game with a camera has: a player
looking at the wrong place at the wrong time, punished by information they were
never going to have. In a game where three people share one chest, that failure
lands on the whole team rather than on the person who looked away.

And **returning to the whole map is one instant, unmissable action.** If getting
back is ever a small navigation task, players stop zooming in at all, and the
detail the camera exists for goes unread.

**Changed:** [017](017-the-viewing-layer.md), issues 701 and 702.
## D8. What is the setting? — **ANSWERED**

**Answer: nobody remembers why.**

An ancient, automated war that nobody alive started. The bases still spawn
soldiers because the machinery that spawns soldiers still works. The towers still
shoot because that is what towers do. Nothing has required a decision to keep
happening for a very long time, and it has kept happening anyway.

**The libraries hold the records of why the war began, and nobody has read
them.** Destroying the enemy's library is how you win and also how the answer is
lost for good. A team that wins has not learned anything; it has burned the last
copy of the only question worth asking, at speed, with everything it had. That is
why the win condition is a library rather than a throne, and why it has so little
health — it is a room full of paper at the back of a machine that has been running
for centuries, and nobody thinks it is important.

The setting was not invented for the game. It was **excavated from the
subtraction**: take a lane-pusher, remove the heroes — the individuals, the named
people, the ones with reasons — and what remains is process without anybody in it.

Written up in full at [nobody remembers why](021-nobody-remembers-why.md).

## The Eternal Golem, and what it is made of — **ANSWERED, and preserved**

Recorded verbatim, because it is the most important sentence anybody has written
about this game:

> It doesn't die! It's eternal! It's deathless! It's the same golem in every
> game, watching you play and learning how you fight! Too bad it can't do much
> about it because it's made out of [redacted].

**It is the same Golem in every match.** Not a fresh instance of a monster type.
It watches, it learns, and it can do nothing with what it knows, because of what
it is made of.

In a world where nobody remembers why, **the Golem is the only thing that
remembers everything** — and it is built out of something that prevents it acting
on the memory. The perfect archive and the perfectly useless one, walking toward
the imperfect archive that everybody is dying over.

Mechanically it learns nothing and no part of the simulation consults a previous
match. Those two facts are allowed to sit next to each other; making it actually
adapt would require the game to remember matches, which is a large feature in
service of a line that works better unimplemented.

**What it is made of is not written down, and should stay not written down.**

## Does damaging the Eternal Golem pay anything? — **ANSWERED**

**No. There is no last-blow payout, because there is no last blow, and damage
pays no personal resource at all.**

Nor is there anything worth spending it on by then: every upgrade the team owns
is already applying to the wave units in the central lane, every soldier the
bases can make is already walking into the middle, and the entire effort of both
teams is spent on one thing — slowing that monster down.

So the third challenge is **the one stretch of a match with no economy in it.**
Nothing is earned and nothing new can be bought. Whatever a team banked before
the third surge is the last thing it will ever field, which turns the run-up to
that surge into a spend-it-all-now moment and the endgame into a matter of what
you already have.

**Changed:** [015](015-boons-and-the-challenge.md), [021](021-nobody-remembers-why.md), issue 606.

# Group E — Technical decisions not yet made

## E1. Networking model. — **ANSWERED**

**Answer: peer-to-peer, three channels, no permanent host.**

| Channel | Carries | Guarantee |
| --- | --- | --- |
| **Choices** | placements, locks, objections, sign-posts, purchases | sent immediately over TCP by whoever made the choice, applied on arrival, **never rolled back** |
| **Continuous state** | positions, health, projectiles | one peer publishes about once a second; **whose turn it is rotates**; everybody else accepts without argument |
| **Presence** | every player's cursor | continuous, tiny |

The choice channel's rule is the load-bearing one. A rollback is a lie the game
told you — you saw your upgrade land in the top lane, made three more decisions on
the strength of it, and then the game took it back. In a game whose entire subject
is placement decisions negotiated between three people, an untrustworthy placement
is fatal. **Positions may lie a little. Choices may not lie at all.**

The rotation matters for two reasons. A fixed host's view is always the true one
and their machine has no correction latency, which in a competitive match between
six people is a fixed advantage. And publishing means uploading to five peers, so
rotating turns *one player needing a good connection* into *all of them needing a
mediocre one*.

The cursor channel is not a nicety: it is **one of the five verbs a team has for
talking about the chest**, and one of the two that are involuntary. A hovering
cursor says *I am about to touch this* before anybody has committed to anything.
Expect teams to lock less because of it, since most of what a lock prevents is
two people reaching for the same thing without knowing it. The full list is in
[the shared upgrade pool](009-the-shared-upgrade-pool.md).

**Changed:** [016](016-players-teams-and-commands.md), [003](003-the-simulation-tick.md), issues 801 (rewritten and renamed), 107 (rewritten), 104, phase-2 and phase-8 progress.

**Created:** the trust question — see below.

## E2. Can the machines drift? — **ANSWERED**

**Answer: yes, and that is fine. Positions, health, and damage stay as doubles.**

E1's model does not require bit-identical agreement, so the fixed-point rewrite
that was the project's largest deadline is not needed and **phase 2 is
unblocked.**

What stays integer regardless is **time**. Every duration is a whole number of
ticks, because that is about two machines agreeing on *when* — which they must —
rather than on *where*, which they need not.

Two things this cost, both now written into the documents that claimed otherwise:

- **A replay is not just a seed and a command list.** That was true only under
  lockstep. The world is periodically overwritten from another machine, so a
  replay must record accepted snapshots too — which makes replays large rather
  than tiny. Issue 107 has been rewritten.
- **The determinism test no longer underwrites the network.** Same machine, same
  binary, same seed, same commands, same result still holds and is still the best
  regression test in the project. It proves nothing about two machines, and the
  comment beside it has to say so.

## E2b. Can the peer whose turn it is lie? — **ANSWERED**

**Answer: sanity-check on receipt, by causality rather than by tolerance.**

The check:

1. **Only look at values that differ from the local simulation.** The machines run
   the same code from the same seed, so most bodies agree and cost nothing to
   verify.
2. For each body that differs, find the units **in range of it, or otherwise
   within capability of affecting it**, on the checking machine's own view.
3. Ask whether the difference is **explicable** by those units. A health drop
   larger than every attacker in range could have dealt in the elapsed ticks is
   not a correction; it is a claim about something that could not have happened.
   A health gain larger than every **healer** in range could have produced is the
   same — see F39, which is where that turns out to be much harder than the
   damage case.
4. Reject what fails, keep the local value, log it.

**A causality check, not a tolerance** — and that distinction is the whole reason
it is worth building. A magnitude tolerance asks *is this change big?*, which is a
tuning question that always gets the edge cases wrong. This asks **could anything
have done this?**, which is a question the simulation already knows the answer to,
because knowing what is in range of what is the retarget pass's whole job. The
defence costs one function that reuses machinery that already exists.

It also lands close to the cheat. Publishing the enemy weaker requires attackers
in range you do not have. Publishing yourself healthier requires something in
range able to heal you — which **used to be nothing, and is now priests.**

**That is not a small amendment and F39 has the whole of it.** A per-body
question does not compose: one healer's single heal can serve as a valid
explanation for two different bodies at once, because nothing in a per-body check
tracks that its capacity is spent. The check becomes a bipartite matching over
healers and wounded bodies rather than a lookup — unless healing is made an
**area** effect, in which case the assignment disappears and this step goes back
to asking one question and getting a complete answer.

**What it does not catch:** a cheater who inflates damage *within* what an
in-range attacker could plausibly have dealt. It catches the impossible, not the
improbable — and that is the correct place to stop. Catching the improbable means
statistical thresholds and a stream of false accusations against players with bad
connections, in defence of a game that is peer-to-peer among people who chose to
play together.

**Changed:** issue 801, [016](016-players-teams-and-commands.md).

## E2c. What exactly is in the snapshot? — **ANSWERED**

**Answer: positions and health. Nothing else.**

Not deaths, not wave counters, not chest contents, not resource balances. The
reasoning is a chain:

> **Health determines deaths. Deaths determine wave wipes. Wave wipes determine
> draws. Draws determine the chest.**

So syncing health makes every derived layer agree **on its own**, without any of
it crossing the wire. Two machines that agree on every health value agree on who
died, therefore on which waves were finished off, therefore on what each team
drew, therefore on what is in the chest three people are looking at.

Three things it buys:

1. **The payload stays small** — two flat arrays of doubles per body,
   delta-encoded against the last accepted snapshot.
2. **The derived layer stays honest.** Nothing computes the chest except the rules
   that are supposed to. There is no second path by which a chest could change.
3. **There is much less to lie about.** A modified client can move bodies and
   adjust health. It cannot invent an upgrade, hand itself resource, or claim a
   wave it did not kill, because none of those are in the message.

That third point is the partial answer to E2b: **the smaller the snapshot, the
smaller the attack surface.** Positions-and-health is close to the minimum that
still keeps the derived layer converging.

One implementation consequence worth writing into the code: applying a snapshot
must **not** raise a death, a wipe, or a draw as a side effect. Health is
written; the ordinary resolve pass notices the zero on the next tick and
everything downstream follows through the normal path.

**Changed:** issue 801, [016](016-players-teams-and-commands.md).
## E3. How many soldiers on the map at once? — **ANSWERED**

**Answer: a hard configured maximum, preallocated at match start, and exceeding
it is an error rather than a reallocation.**

The question asked what the number *is*. The better answer is that nothing should
ever need to know, because the store is allocated once and never grows.

That follows the rule this project already uses everywhere else: **assign the
memory first, then hand out slices of it.** A store that can grow is a store that
can reallocate mid-tick, which invalidates every index a worker thread is holding
and turns the thread pool from an optimisation into a hazard. A fixed store makes
slicing a pair of integer bounds forever.

**Running out is a real failure and is treated as one.** Not a silent drop, not a
grow-and-continue — an error that names the phase, the tick, and the spawn that
could not be satisfied. A fallback here would be a match that quietly stops
spawning and a balance run that quietly lies.

The estimate that sizes it, so the first value is not a guess in the dark: the
worst case is a siege-surge, where both teams emit one body per lane on a short
timer. Bodies alive is roughly **spawn rate × how long a body lives**, plus the
standing guards, plus heroes. With the current estimates in
`docs/balance-updates.md` that lands in the **low hundreds**, not thousands — so
the cap is set well above it, and the validator reports the high-water mark of
every batch run so the headroom is a measured number rather than a hope.

**Changed:** [003](003-the-simulation-tick.md)'s world record, issues 103, 201, 209, 804.

## E4. FFI struct arrays or Lua tables for the soldier store? — **ANSWERED**

**Answer: FFI struct arrays for the soldier store and the snapshot. Lua tables
for everything else.**

The split is not a compromise, it is a line drawn at a real boundary: **FFI for
what is both large and hot; Lua tables for what is rare, long-lived, or
inspected.**

| | Store | Why |
| --- | --- | --- |
| Soldiers | **FFI** | Thousands of them, touched every pass of every tick, sliced across the pool. This is the only thing in the game with that shape. |
| The upgrade count vector | **FFI**, alongside the soldier store | One small integer array per body, walked on every swing. It is part of the same hot record and should live in the same allocation. |
| Snapshots | **FFI** | Flat, written once a tick, delta-encoded, and shipped over a wire. |
| Structures, waves, upgrade instances, players, teams | **Lua tables** | Dozens, not thousands. Touched rarely. Read constantly by humans. |

[The shape of the code](018-the-shape-of-the-code.md) already leaned this way —
"where a hot array of numbers is needed, an FFI struct array is preferred" — and
this settles where the boundary sits rather than leaving it to taste.

The cost is accepted and worth naming, because it will be felt on a bad day:
**an FFI array is worse to debug.** No `pairs`, no printing a body by name, no
poking at it from a live prompt. The mitigation is not to avoid FFI; it is to
write the inspector early — one function that prints a soldier as a readable
record — and to treat it as part of the store rather than as a debugging
afterthought somebody adds under pressure.

**Changed:** [018](018-the-shape-of-the-code.md), issues 103, 107, 201.

## E5. Where do replays live, and how are they versioned? — **ANSWERED**

**Answer: two grades of replay, because there are two different things people
want back, and only one of them is heavy.**

| | Carries | Reproduces | Size |
| --- | --- | --- | --- |
| **Light** | seed, match parameters, command list | *a* match — the one those commands produce on one machine | tiny |
| **Full** | the above, plus the accepted position-and-health snapshots | *the* match six people actually played | large |

E2 established that a seed and a command list are not enough under a rotating
authority, because the world is periodically overwritten from another machine. It
did not follow that every replay must be heavy. **A light replay is still exactly
right for the thing replays are mostly for** — a batch run, a regression test, a
bug somebody wants to re-enter — because all of those happen on one machine,
where the simulation *is* deterministic and nothing overwrites anything.

The full grade exists for one purpose: watching back a networked game as it
actually happened, with the corrections in place. It is recorded only when the
match was networked, and the snapshot stream is delta-encoded against the last
accepted one.

**Where they live:** written to `tmp/shared-memory/` while a match runs, since
that is RAM and a match writes continuously; moved to a durable directory only
when kept. Nothing ephemeral goes in the repository.

**Versioning:** a **rules-version stamp in the header**, checked on load, and a
refusal — not a warning, not a best-effort — when it does not match the binary.
A replay run against rules it was not recorded under does not produce a slightly
wrong match; it produces a confidently wrong one, which is worse than no replay,
because somebody will believe it.

The stamp is a hash of the catalogue tables and the phase table, not a hand-typed
version number, so it changes when the rules change and cannot be forgotten.

**Changed:** [003](003-the-simulation-tick.md), [018](018-the-shape-of-the-code.md), issues 107, 801, 804.

## E6. Does the map builder need to make anything other than the standard map? — **ANSWERED**

**Yes, and it is not an option.** The lane count follows the team size, so a
two-lane and a four-lane map are ordinary output rather than variants. See F10.
The nine-milestone assumption becomes a thing the map validator checks rather
than a thing the rest of the code relies on.


Superseded by F10 — the builder scales with team size, so a two-lane and a
four-lane map are ordinary output rather than special cases. What remains here is
the consequence: **the milestone system must stop assuming nine**, and the count
becomes something the map validator reports rather than something the rest of the
code may rely on.

## E7. How good does the bot need to be? — **ANSWERED**

**Answer: good enough to be worth beating. This ships single-player, and that is
a phase rather than a corner of one.**

The entry was right that a bot built to be a measuring instrument and a bot built
to be an opponent are not the same program. The answer is that **the project
wants both**, and they stay separate:

| | Issue 803, phase 8 | Phase 9 |
| --- | --- | --- |
| Exists to | produce balance numbers | be played against |
| Good enough when | it plays consistently enough that ten thousand matches mean something | a person would rather play it than not |
| May be dull | yes | no |
| Must be fast | **yes** — it runs ten thousand times overnight | no |

Those requirements pull in opposite directions, which is exactly why one program
cannot serve both. A measuring bot wants to be cheap, deterministic, and boring.
An opponent wants to be varied, surprising, and occasionally wrong in the way a
person is wrong.

### The thing that makes this bot unusual

**Single-player in a 3v3 is not one bot. It is five, and two of them are on your
side.**

A person playing alone has two bot **teammates** sharing their chest. Those bots
have to place upgrades into lanes the human is also placing into, respect locks
the human sets, decide whether to object to them, and — since issue 806 — say
something. A teammate bot that trampled a human's arrangement every wave would be
worse than no teammate at all, and a teammate bot that never touched anything
would make the shared chest single-player.

**That is the hard problem in this phase, and it does not exist in the games this
one is subtracted from.** An opponent bot only has to play well. A teammate bot
has to play well *and* read what a person is trying to do from the only evidence
available — where they placed, what they locked, where their cursor is — and then
not get in the way of it. It is the negotiation layer, played from the other
side.

### It cannot cheat, and that falls out for free

Under F7 the enemy's chest, wallets, and sign-post directions are **not on your
machine**. A bot opponent running in the same process is subject to the same
thing: there is no privileged path to information a human would not have, because
the information is not there to read.

So **difficulty cannot come from information or from bonuses**, only from
decision quality. That is a harder bar and an honest one, and it is worth
enforcing structurally rather than by discipline — the bot should be handed the
same viewer frame a human's screen is drawn from, and nothing else.

**Changed:** [019](019-roadmap.md) gains a ninth phase, issue 803's scope is narrowed to the measuring instrument, and the opponent becomes phase 9.
---

# Group F — Answered in the review of 2026-08-24

A read-through of every document against every other one turned up a set of
disagreements between pages that were each individually well-formed, which is
why nothing here was caught by `./validate-documentation`. The answers below
came out of that session.

**Several of these reverse an earlier entry.** Where they do, the older entry is
left standing with its reasoning intact — the road not taken is worth being able
to find — and the entry here names what it supersedes. When the two disagree,
**Group F is the current design.**

Superseded by this group: **A6, A6b, A6b-i, A18** in part, **D3** in part,
**D4** in part, **E2c**, **B4**, and the boon arithmetic in **A8** and **A15**.

## F1. Are a tower's guards stamped with its upgrades, or do they read live? — **ANSWERED, then SUPERSEDED by F23**

**Answer: they read live. Nothing about a guard is stamped.**

A guard receives whatever is slotted into its own guard tower **the moment that
upgrade arrives**, and loses it the moment the upgrade physically leaves. It is
not a copy taken at birth; it is the tower's current holding, read through.

The queue still applies, and it is the same queue an upgrade uses everywhere
else: a player can queue an upgrade to move to a lane or to a different guard
tower, and **the guards keep their existing buffs until the next wave spawns and
the upgrade physically switches.** The wave spawn is the moment of the switch,
for stone and for guards alike, which means there is exactly one instant in the
match's rhythm where anything changes hands.

This supersedes **A18**, which said a guard was stamped at spawn like a wave
unit, and it corrects
[a unit and what it carries](004-a-unit-and-what-it-carries.md), which says a
guard's modifier set is permanently zero, and
[guard towers](007-guard-towers-and-their-guards.md), which says it is stamped.
All three were describing different rules.

What it costs: a guard's modifiers are now a lookup through its tower rather
than a number it carries, so the swing arithmetic for a guard is not the same
shape as the swing arithmetic for a wave unit. That is acceptable — guards are
few and towers are fixed — but it means "one soldier record, one combat routine"
now has one genuine branch in it, and the branch needs a comment saying why.

What it buys: the A5/A18 tension disappears. A5's balance instruction was that
stone must be worse at pushing a frontline than soldiers are. A18 pushed against
that by making a stone upgrade quietly buy bodies as well as arrows, and the
reconciliation was leashing. Live reading keeps the bodies but makes the
investment reversible — move the upgrade out and the guards are ordinary again
on the next wave — so stone is no longer the unlosable side of the trade.

**Changed:** [007](007-guard-towers-and-their-guards.md), [004](004-a-unit-and-what-it-carries.md) *(pending the soldier walkthrough)*, [010](010-upgrades-slotted-into-stone.md), issues 303, 401, 405.

## F2. What is a command radius? — **ANSWERED, and it is new**

A guard tower carries a **command radius**: a plain circle of ground around it,
and the only thing in the game that both teams can see the shape of.

It does two jobs.

**It gates the tower's own guard production.** A tower puts guards on the ground
up to a **cap**, and only while **no enemy stands inside its command radius**. A
tower under pressure does not reinforce itself; a tower with clear ground around
it fills back up. That inverts the usual behaviour and it is the point — guards
are what makes the ground around a tower dangerous, so the way to make a tower
approachable is to reach it, not to grind its patrol down and outlast the timer.

**The cap is a stat, and upgrades can raise it.** Slotting the right upgrade
into a lane's stone does not only make the towers shoot harder; it lets them
hold more bodies.

**It gates hero spawning.** A player may put a hero down at one of their own
guard towers only while the command radius is clear of enemies — the same test,
the same circle. This replaces the loose "threshold radius" that
[hero units](012-hero-units.md) referred to and **B4** was holding a number for;
there is one radius per tower and it does both jobs.

**Both teams can see it.** This is a deliberate exception to the rule that runs
through the rest of the design — sign-post directions are hidden, the enemy
chest is hidden, and what you know about an opponent is what has physically
reached you. The command radius is drawn for everybody, because it is the one
piece of information that both attacker and defender have to reason about at the
same moment: the attacker needs to know how far in they have to get to shut the
reinforcements off, and the defender needs to know how far out they have to push
to turn them back on. Hiding it would make the most tactical ground on the map
unreadable to the side standing on it.

**Changed:** [007](007-guard-towers-and-their-guards.md), [012](012-hero-units.md), [001](001-what-this-game-is.md)'s vocabulary, issues 303, 304, 506, and B4 and B10, which now hold numbers for one radius and one cap rather than two unrelated ones.

## F3. Can the same upgrade kind stack, and what stores it? — **ANSWERED**

**Answer: yes, duplicates stack, and the store is a count vector rather than a
bit set.**

**A11** already said duplicates stack and three instances of one kind can sit in
three lanes or pile into one. What nothing noticed is that the thing carrying
them — one integer, one bit per kind — cannot count. Two copies of a kind and one
copy of that kind produce the same integer, so as written the stacking rule had
no way to take effect.

So what a body carries is **an array of small integers, one per catalogue kind,
holding how many copies of that kind it has.** A lane's holding is the same
shape. The swing arithmetic changes from walking set bits to walking the vector
and multiplying each modifier by its count.

Three things follow.

**The catalogue is no longer capped at the width of an integer.** The `bit` field
in the upgrade catalogue exists only to pack kinds into a mask, and LuaJIT's bit
library is thirty-two wide, so the old design silently limited the whole game to
thirty-two upgrade kinds — including boons. Nobody had written that number down
anywhere. With a count vector the limit is memory, and **B7** is free to pick a
catalogue size on its merits.

**Stamping costs more.** A bit set is one integer copied; a count vector is an
array copied per body. It is still a flat copy of a small fixed-size array into
preallocated space, which is the cheap kind, but the "one integer" line in
several documents is no longer true.

**Something has to decide how a duplicate composes.** Two copies of a flat
addition presumably add twice. Two copies of a multiplier are the open half —
multiply twice, or add the excess once. That belongs with **B7** and the
catalogue, and it should be one rule for every kind rather than a per-kind field.

**Changed:** [009](009-the-shared-upgrade-pool.md), [006](006-combat-and-damage.md), [010](010-upgrades-slotted-into-stone.md), [004](004-a-unit-and-what-it-carries.md) *(pending the soldier walkthrough)*, issues 401, 402, 405.

## F4. Do boons reach hero units? — **ANSWERED**

**Answer: yes. A boon is on every body the team fields, heroes included.**

**A14** stands unchanged and is about something else: a **lane's** upgrades reach
wave units and nothing else, so that stacking a lane and buying heroes into it
cannot compound. A boon is not in a lane. It is not in any slot, it cannot be
moved, and it is not a thing a player aims — it is described best as **a buff on
the commander that radiates out to everything that team puts on the field.**

That is why it is allowed to touch heroes when a lane upgrade is not: there is no
placement decision for it to multiply with. Nobody can stack boons into one lane,
because a boon has no lane.

**Changed:** [015](015-boons-and-the-challenge.md), [009](009-the-shared-upgrade-pool.md), [012](012-hero-units.md), [004](004-a-unit-and-what-it-carries.md) *(pending the soldier walkthrough)*, issue 605.

## F5. How many boons, offered how many at a time? — **ANSWERED**

**Answer: two offered, one chosen, by each player independently.**

Not three offered, and not one boon handed to a team. Every player makes their
own pick, so a three-player team gains three boons at each boon event, and every
one of those three applies to everything the team fields.

### The two offers are the same two for everybody

**One pair is drawn per event, and all six players are offered that same pair.**
Not per player, not per team — per *match*. This supersedes the earlier ruling in
A15, which drew offers per player and treated two teammates seeing the same boon
as a happy accident.

It is the shared-deck argument again, arriving somewhere else: **remove every
source of asymmetry that is not a decision.** The map is symmetric, the spawn
intervals are identical, the surge is on a visible clock, both teams draw the
same upgrade kinds in the same order — and now both teams are offered the same
two boons at the same moment. Nobody is ever handed a better menu.

Three consequences, and the second is the one worth designing toward.

**A team can take three of the same boon.** Duplicates stack (F3), so three
players who all pick the left-hand option are running that boon at triple
strength. Nothing forbids it and it is a real strategy: concentrate, or spread
across both.

**It is a negotiation with no communication channel.** Three teammates are
looking at the same two cards and each has to guess what the others will take.
Spreading two-and-one is probably right and everybody piling onto the strong one
is a coordination failure — which makes this the only moment in the game where
the team's five verbs do not help at all, because there is nothing on the board to
lock, object to, or point at.

**The enemy's boons are legible without any interface.** They chose from the same
two you did, so after a calm you know their three boons are some split of a pair
you are holding yourself. What you do not know is the split. That is exactly the
shape of every other information rule here: you know *what*, never *how much of
which*.

The full arithmetic is in F6, which settles how many events there are.

**Changed:** [015](015-boons-and-the-challenge.md), issue 605.

## F6. When does a boon arrive, and how many times? — **ANSWERED**

**Answer: twice a match, in the calm after a slain monster.** The reading that
had them arriving at the end of each surge is rejected.

The whole of it, in one table, because the numbers are easy to state wrongly and
this document has already done so once:

| | Per event | Over a match |
| --- | --- | --- |
| Boon events | — | **two** — after the Pillar Orc, after the Field Dragon |
| Offered to each player | **two** | 2 + 2 |
| Chosen by each player | **one** | **1 + 1 — two boons per player** |
| Gained by a three-player team | **three** | **3 then 6 — six per team** |

**There is no third boon event.** The Eternal Golem is never slain, so nothing
pays for it, and the third surge is followed by a challenge that ends the match
rather than by a calm.

### Why payment rather than equipment

The vision has a boon arriving at the end of each siege-surge, as something that
"helps them overcome a challenge that appears" — equipment issued before the
fight. That is three events, and it was a live reading right up until this was
settled. It is rejected for two reasons.

**A boon issued before the fight is a menu opening while something enormous
starts walking.** Three players reading two lists each, with a deadline, at the
most frightening moment in the match. Paid for the kill, in the quiet afterwards,
it is a reward with room to enjoy it — and that is the entire reason the calm
exists as a phase at all.

**Equipment for a fight you have not had yet cannot be chosen well.** You would
be picking against a monster you have not met, which makes the choice a guess
rather than a read. Picking afterwards, with the next stretch of normal play in
front of you, is a decision about a board you can see.

So a boon is **payment for slaying a challenge monster**, and the shape of the
match is: surge, then monster, then reward. Tension, then release, twice.

### What it settles elsewhere

- **The wallet's ceiling rises twice**, at each calm, alongside the boons —
  confirming the working ruling in A16b rather than making it three.
- **A team finishes on six boons**, so the accumulating floor under a match is
  six permanent team-wide upgrades nobody can move, not nine.
- **Each player gets exactly two moments of sole ownership** in a design
  otherwise built entirely out of shared property, and both are paid for by
  killing something enormous.

**Changed:** [015](015-boons-and-the-challenge.md), [014](014-the-siege-surge.md)'s phase table, [011](011-commanders-and-personal-resource.md), issues 601, 605.

## F7. What actually crosses the wire, and to whom? — **ANSWERED**

**Answer: between teams, unit positions and health and nothing else. Everything
else is a small immediate message inside one team.**

This supersedes **E2c**, which said positions and health full stop, and it
resolves the collision where the word *snapshot* was naming two different
objects. There are three flows, not one:

| Flow | Who sees it | Carries |
| --- | --- | --- |
| **The viewer's snapshot** | never leaves the machine | everything the renderer needs — a local read-only copy per tick |
| **Team traffic** | that team's machines only | placements, queued moves, locks, objections, sign-posts, purchases, boon picks |
| **Cross-team sync** | everybody | positions and health of bodies, projectiles, and structures |

**The enemy's chest is not merely undrawn — it is not on your machine.** The
previous model had every peer simulating the whole world from a shared seed,
which meant both teams' chests, slots, and sign-post directions were sitting in
memory on every client and were secret only because the viewer declined to draw
them. They are now genuinely absent, which is the only version of hidden
information that survives a modified client.

**One constraint comes out of it.** Because a placement is authoritative from the
person who made it and is never rolled back, two teammates can still contradict
each other across a bad connection. So **an upgrade's queued destination cannot
be changed inside a window of the worst ping among that team's connected
players, plus fifteen percent.** Within that window the destination is frozen and
a change is refused with a reason. Outside it, everyone has already seen it.

**Changed:** [016](016-players-teams-and-commands.md), [017](017-the-viewing-layer.md), [003](003-the-simulation-tick.md), issues 107, 801, and E2c.

## F8. How is cheating caught, if the teams no longer share a world? — **ANSWERED**

**Answer: by auditing what the enemy could possibly have, against what they are
observed to have.**

**E2b** answered the physical half — a health change larger than anything in
range could have caused is a claim about something that could not have happened.
This is the economic half, and it is what the split in F7 makes necessary: your
machine no longer simulates the enemy's chest or wallet, so it has to **infer**
them and check the inference.

Both halves work the same way. Watch what arrives, ask whether it is explicable.

- **An upgrade shows up on an enemy frontline body that you have not seen come
  out of the shared deck.** The innocent explanation is that they paid to reroll
  and are further along the sequence than you are, and that explanation is
  checkable — it costs resource, and resource is bounded.
- **The enemy fields heroes costing more than they could feasibly have earned by
  that tick.** There is no innocent explanation for that one. Income is a
  function of kills, kills are visible, and the ceiling is known.

A single discrepancy is not an accusation; the checker's first job is to **try to
explain it**, and most of the time it can. What is not tolerated is
**accumulation.** One unexplained upgrade is a reroll you did not see. A dozen,
plus a hero roster nobody could afford, is not anything else.

This is the same principle as E2b's causality check and for the same reason: it
catches the impossible rather than the improbable, so it never produces a false
accusation against somebody with a bad connection.

**Changed:** [016](016-players-teams-and-commands.md), issue 801.

## F9. Is there an economy during the third challenge? — **ANSWERED**

**Answer: yes. Resource keeps flowing. What the Golem does not pay is a boon.**

[commanders and personal resource](011-commanders-and-personal-resource.md) and
[boons and the challenge](015-boons-and-the-challenge.md) both said the third
challenge had "no income at all" and was "the one stretch of a match with no
economy in it." That generalised a narrower fact — that the Golem itself pays
nothing for being damaged and nothing for being killed, because it cannot be
killed — into a claim the combat rules contradict. Waves still spawn, bodies
still die, and every death still pays.

So the endgame is not a stretch with the wallet switched off. It is a stretch
where **the wallet is the only thing still moving**: no more boons, no more
draws worth arranging, and personal resource buying the heroes that are the only
variable left in how long a team holds its Golem back.

**Changed:** [011](011-commanders-and-personal-resource.md), [015](015-boons-and-the-challenge.md), and the entry above titled "Does damaging the Eternal Golem pay anything?", which was right about the Golem and wrong about the phase.

## F10. How many players, and how much of the map follows from it? — **ANSWERED**

**Answer: it is a variable everywhere, three per side is what the prototype
targets, and the map is derived from it.**

The relationships, which nothing had written down:

- **Lanes = players per team.** Three players, three lanes.
- **Guard towers per team = lanes × 3** — two standing on each lane, one at each
  lane's mouth inside the base. Two lanes gives six a side, three gives nine,
  four gives twelve.

So a 2v2 and a 4v4 are not variants of the standard map; they are what the map
builder emits when it is handed a different team size. That **answers E6** in the
affirmative — the builder must scale — and it retires the fixed nine-milestone
assumption as a thing to check rather than a thing to rely on.

It also contradicts something
[players, teams, and commands](016-players-teams-and-commands.md) says outright:
that three lanes and three players is "a tidy coincidence and nothing more" and
"nothing in the rules assumes one player per lane." The map now assumes it
structurally. That does not mean a player owns a lane — the whole design pushes
against that — but the shape of the field is derived from the size of the team.

The fixed player-number mapping in that document — players 1 to 3 are team 1,
4 to 6 are team 2, "a fixed mapping and not a lookup" — has to go with it.

**This closes A3** as a design question. What remains is the prototype's scope:
3v3 is what gets built and played first.

**Changed:** [016](016-players-teams-and-commands.md), [002](002-the-map-and-its-milestones.md), [007](007-guard-towers-and-their-guards.md), [003](003-the-simulation-tick.md)'s world record, issues 101, 102, 802, and E6.

## F11. What exactly does a siege-surge do to a team's upgrades? — **ANSWERED**

**Answer: nothing. It reads them where they sit and deals them out to the bodies
coming off the spawn points.**

This supersedes **A6**, **A6b**, and **A6b-i** in their mechanism, though not in
what they were reaching for.

Every roughly half a second, **one body spawns at each lane's start point inside
the base** — three bodies in a three-lane match, mirrored on the other side. At
each of those spawns:

1. Pick a random one of the three new bodies to start with.
2. Take a **random upgrade from everything the team owns** and assign it to that
   body.
3. Move to the next body in rotation and repeat, until every upgrade the team
   owns has been assigned.
4. Send the three on their way, stamped.

Then half a second later it happens again, from scratch, over the team's whole
holding, starting at a fresh random body.

**The upgrades are assigned, not removed.** They are not taken out of anything.
Whatever is slotted into the top lane is still slotted into the top lane the
whole time the surge runs — the surge simply ignores where things sit and reads
the team's holding as one flat list.

That kills three things the older answers had built:

- **Nothing is dumped into the chest** when a surge starts, so nothing has to be
  remembered and restored when it ends, and the "scramble to re-place a chest
  that was emptied" is gone. Upgrades in this game are **never moved except by a
  player's own hand.** Watching your arrangement come apart without touching it
  was frustrating in a way that nothing bought back.
- **The chest is not the source.** The deal reads everything the team holds,
  placed or not, so an upgrade sitting unplaced is on the field during a surge
  exactly as much as a placed one is. There is no pre-surge hold to be clever
  about, which **retires C1b**.
- **The surge is not a freeze.** See F12.

What survives, and it is the part that mattered: for the length of the surge a
team's arrangement does not decide anything. Every upgrade is on the field at
every instant, spread across three bodies at a time, and never twice in the same
combination. **The surge does not take strength. It suspends arrangement.**

**Changed:** [014](014-the-siege-surge.md), [009](009-the-shared-upgrade-pool.md), [005](005-waves-and-when-one-is-finished.md), [001](001-what-this-game-is.md), issues 602, 603, and C1b.

## F12. Can players touch upgrades during a surge? — **ANSWERED**

**Answer: yes, freely. Place, move, withdraw, lock, object — all of it.**

The older rule refused every placement for the duration and left players with
nothing to do but buy heroes and point sign-posts, which
[the siege-surge](014-the-siege-surge.md) described as "a deliberate hole in the
game's main activity." It was a hole.

It is also unnecessary now. Since the deal ignores where an upgrade sits (F11),
rearranging during a surge changes nothing about the surge — so there is no
reason to forbid it, and one good reason to encourage it: **what you are
arranging is the challenge.** A monster is one enormous body and a wave is many
small ones, and the build that was right for the second is usually wrong for the
first. The surge becomes the window in which a team retools for the thing walking
out of the middle next, while the fighting continues without waiting for them.

The same freedom holds during the calm.

**Changed:** [014](014-the-siege-surge.md), [009](009-the-shared-upgrade-pool.md), [016](016-players-teams-and-commands.md)'s refusal table, issues 404, 602, 603.

## F13. Whose side is a challenge monster on? — **ANSWERED**

**Answer: its own. Monsters are a third team, and each one is assigned to the
player-team it is a test for.**

A monster is hostile to everything and allied with nobody, so no configuration of
the map turns it into somebody's temporary ally. The assignment is bookkeeping,
not allegiance: **the team a monster is assigned to receives the boon when it
dies, no matter who landed the killing blow.** A team cannot steal another team's
challenge reward by reaching into the middle and finishing their monster off, and
nobody has to position a hero for a last hit.

That connects to a simplification worth stating on its own. **There is no
last-hit accounting in this game at all.** Resource is paid to a team, not to a
player, there is no experience, and no rule anywhere reads who struck last. The
`last_hit_by` field that
[combat and damage](006-combat-and-damage.md) and
[commanders and personal resource](011-commanders-and-personal-resource.md)
both describe can come out.

**Changed:** [015](015-boons-and-the-challenge.md), [006](006-combat-and-damage.md), [011](011-commanders-and-personal-resource.md), [004](004-a-unit-and-what-it-carries.md) *(pending the soldier walkthrough)*, issues 205, 502, 606.

## F14. What happens between a monster dying and normal play resuming? — **ANSWERED**

**Answer: three stages, and the middle one is a wait.**

1. **Your monster dies.** Your wave units and your heroes turn around and go
   home. The wave units simply disappear when they arrive. **The heroes refund
   what they cost**, so a hero that survived a challenge was rented rather than
   spent.
2. **You wait.** Until the other team has finished theirs, there is nothing for
   you to do but watch them fight. Finishing first buys time, not tempo.
3. **The calm.** Once both monsters are down and both sides' bodies are walking
   home, the quiet window opens: boons are chosen, upgrades are rearranged
   freely, and then normal play resumes.

The refund is the significant half and it changes what a hero is. Heroes still
die permanently and the resource still dies with them — that is unchanged during
ordinary play. But a hero bought *for a challenge* is only spent if it fails,
which is what makes throwing everything at a monster the correct move rather than
a gamble against your own next few minutes.

**This answers A8c**, which asked what happens when one team's monster dies long
before the other's, and it answers it in the least generous direction available:
the faster team gets no free push, because their bodies have already left.

**Changed:** [015](015-boons-and-the-challenge.md), [012](012-hero-units.md), [011](011-commanders-and-personal-resource.md), [014](014-the-siege-surge.md), issues 605, 606, 503, and A8c.

## F15. Where do sign-posts stand, and what do they do? — **ANSWERED IN PART**

**Answer: three of them, one per lane, standing on the anti-diagonal — and each
one is worth exactly one lane change.**

With team A's base at the bottom-left and team B's at the top-right, the three
sign-posts stand at the **top-left corner**, the **middle of the field**, and the
**bottom-right corner**. Those are the three points where the three lanes are
closest to each other, and the connectors between them run along that diagonal.

| Sign-post | Default | Alternative |
| --- | --- | --- |
| top-left | toward the enemy base | toward the centre |
| centre | toward the enemy base | toward the top-left, or toward the bottom-right |
| bottom-right | toward the enemy base | toward the centre |

A click toggles it. A unit arriving at a sign-post continues in the direction it
points — **and then goes straight on at every junction afterwards**, whatever the
next sign says. One diversion per body, and no more.

So the whole apparatus amounts to **the ability to swap a body into a neighbouring
lane, once, with a delay** — the delay being however long it takes to walk to the
corner. It is not a routing system and it cannot build a loop.

This replaces the earlier design of four sign-posts sitting at the near corners
of the two side lanes, two per team's own half, which had a structural problem
underneath it: the centre lane had no junction of its own, so anything that
walked into the middle could never walk out of it. Putting a sign-post in the
middle of the field fixes that by construction.

Three things are still open and are **F16**.

**Changed:** [013](013-signposts-and-lane-routing.md) (rewritten), [002](002-the-map-and-its-milestones.md), [012](012-hero-units.md), issues 101, 508, 705, and D4.

## F16. Who obeys a sign-post, who owns it, and who can see it — **ANSWERED**

Three questions, three answers, and together they say that a sign-post is a
private standing order rather than a piece of shared terrain.

### Heroes obey. Wave units do not.

**Only hero units read sign-posts.** Wave units ignore them completely and always
continue along their own lane, exactly as under the four-post design.

The reason is unchanged and it is load-bearing: if waves could be rerouted, a
team could feed two lanes into one and the lane structure of the map would be
decorative. **Waves are the map's skeleton; heroes are the thing that moves
across it.** The new posts are weaker than the old ones — they sit at the far
corners rather than outside your own base, and a body obeys at most one in its
life — but "weaker" was never the objection. Collapsing two lanes into one at the
midpoint is still collapsing two lanes into one.

Guards never reach a junction, being leashed. Challenge monsters ignore them.

### There are six, three per team.

**Each team has its own set of three.** Every junction carries two sign-posts —
yours and theirs, standing in the same place, pointing wherever each team last
set them. Six in total on a three-lane map.

So setting a sign-post is **only** an order to your own heroes. It is never an
act against the enemy, and nothing in this game lets one team touch an object the
other team is also using. The alternative — three shared posts, where turning one
redirects the enemy's heroes as well as your own — was the stranger idea and it
was rejected: it would be the only mechanic in the design where two teams act on
the same object, and it would make routing an attack rather than a plan.

Any player on a team may set any of that team's three, at any time, with **no
lock and no objection** — see D5. The three of them share one set of standing
orders, and every hero any of them buys obeys it.

### The enemy cannot see yours.

**Sign-posts are invisible to the other team**, which confirms D4 on new ground.
The old ruling drew the enemy's posts as objects with no direction shown, because
they stood as physical things in your own half. With one post per team per
junction, co-located, there is nothing to draw: **you see your three, and you do
not see theirs at all.**

That is cleaner than the old compromise and it lands the same way as everything
else in this design. **You learn where their heroes go by watching heroes
arrive**, not by reading a sign. A team that has quietly pointed all three of its
junctions at the centre has committed every future hero purchase to the middle,
and the other side finds out when heroes start turning up there — several
purchases late, with the commitment already a wave or two deep. The fog is made
of walking.

Implementation note, carried over from D4 and now stronger: the viewer's frame
contains **no entry at all** for the enemy's sign-posts — not a hidden field the
renderer declines to draw, an absent one. Under F7 the enemy's routing is not on
your machine in the first place, which is what makes the secrecy real rather than
polite.

### And the count follows the lanes

One post per lane per team, so **team size decides this too** (F10): a two-lane
match has four sign-posts, a three-lane match six, a four-lane match eight. The
map builder emits them with the junctions.

**Changed:** [013](013-signposts-and-lane-routing.md), [012](012-hero-units.md), [017](017-the-viewing-layer.md), [016](016-players-teams-and-commands.md), issues 101, 508, 705.

## F17. Is push depth meaningful during a challenge? — **ANSWERED**

**Answer: no. It is ignored for the duration.**

During a challenge every lane's production goes to the middle and the side lanes
empty, so the only bodies left standing in them are each team's own tower guards,
sitting at their own towers. Push depth measures the deepest milestone a team's
living soldiers have reached, so it would read each team's own stone back at them
and mean nothing.

Nothing consults it while a challenge runs. The rule that picks a lane for a hero
spawned on the library does not apply either, because there is only one lane
anything is walking down.

**Changed:** [002](002-the-map-and-its-milestones.md), [008](008-the-base-and-the-library.md), [015](015-boons-and-the-challenge.md), issues 102, 507, 607.


## F18. What does the one-wave transit actually look like? — **ANSWERED, unchanged**

**D3** is confirmed rather than superseded, and this entry exists because the
mechanism is easy to state wrongly.

A player queues an upgrade to move. Then:

- **The next wave to spawn is stamped at the upgrade's old slot.** It walks out
  carrying it.
- **The upgrade physically moves at that spawn.**
- **The wave after that is stamped at the new slot.**

So a placement lands two waves after the command, with one wave of unchanged
behaviour in between, and the moment of the switch is a wave spawn rather than a
tick on a timer. The same instant switches a lane's stone and therefore what its
guards are reading (**F1**).

During a challenge this is unchanged — waves spawn into the centre at the normal
interval, and the normal placement rules apply to all of it. **The chest is not
reshuffled during a challenge.** That only ever happened during a surge, and
after **F11** it does not happen there either.

**Changed:** nothing. Recorded because [the shared upgrade pool](009-the-shared-upgrade-pool.md) and issue 404 state it correctly and should not be edited toward something simpler.
## F19. Does a tower keep its own upgrades while a surge runs? — **ANSWERED**

**Answer: no. A tower keeps shooting, and it shoots at its bare catalogue
values.** No upgrades apply to it for the length of the surge.

The question came out of F11's phrasing. The deal *assigns* upgrades rather than
removing them, which seemed to argue that nothing had left the tower and it ought
to keep firing fully upgraded. That reasoning was too clever. "Assigned, not
removed" is a statement about **the chest not being confiscated** — nobody's
placements get shuffled and nothing has to be rebuilt afterwards. It is not a
promise that every slot keeps working while a surge runs.

So the rule is flat and needs no derivation: **during a surge, upgrades apply to
the bodies coming off the spawn points and to nothing else.** Not to towers, not
through towers to their guards.

That is also the version that keeps the phase honest. Towers are already
invulnerable for the duration; leaving them fully upgraded as well would make a
surge a free minute for whoever is behind, and it would leave the tower half of a
team's board completely untouched by the one thing in this design that is
supposed to disturb what a team built. **A surge suspends arrangement — all of
it**, not the soldier half only.

The guards inherit the same answer for free, since they read through their tower
(F1): during a surge a tower has nothing on it, so its guards carry nothing. And
towers spawn no guards during a surge anyway, so the only guards on the ground
are the ones that were already standing there when it began.

**Changed:** [the siege-surge](014-the-siege-surge.md) and its phase table, [guard towers](007-guard-towers-and-their-guards.md), issues 602 and 603.

## F20. Which lane is the wide centre when there is no middle one? — **ANSWERED**

**Answer: the map builder picks the innermost lane. When there are two innermost
lanes, each team is assigned one, mirrored.**

| Lanes | The wide one |
| --- | --- |
| 1 | that lane, shared |
| 2 | one each — team 1 funnels into one, team 2 into the other, mirrored |
| 3 | the middle lane, shared |
| 4 | the two interior lanes, one assigned to each team, mirrored |
| 5 | the middle lane, shared |

**Odd counts have a shared centre. Even counts give each team its own**, chosen
from the two interior lanes and assigned so that the map stays symmetric under a
half-turn — which is the only symmetry this design has ever needed, since the
bases sit at opposite corners.

That last part is the piece worth noticing. The obvious worry about an even map
was that nominating a lane would introduce an asymmetry into a design that has
removed every asymmetry that is not a decision. Assigning **one to each team,
opposite each other**, does not: rotate the field half a turn and it is the same
field. Both teams have a wide lane, both teams' challenges funnel into one, and
neither has an advantage — they simply have different ones.

The consequence for an even map is that **the two teams' challenges no longer
happen in the same corridor.** On a three-lane map both monsters walk the same
middle lane in opposite directions, past each other, never meeting. On a
four-lane map each team's monster walks its own. That is a different-feeling
endgame — two separate sieges rather than one shared corridor — and it is a
reason 3v3 is the shape the prototype is built and balanced against rather than
merely the default size.

**Changed:** [002](002-the-map-and-its-milestones.md), [015](015-boons-and-the-challenge.md), issue 101.
## F21. What does a slot deliver, and to whom? — **ANSWERED, then simplified by F28**

**Answer: nothing is ever consumed, and a slot delivers to everything standing in
it that can use what the upgrade does.**

### Nothing is consumed, in either slot

An upgrade placed at a lane is **affixed there**. It stays. It is stamped onto
every wave unit that lane spawns from then on, and stamping does not use it up —
the same upgrade stamps the next wave, and the one after, for as long as it sits
there. An upgrade slotted into a lane's towers is the same. **An upgrade is a
standing property of a slot, not a resource spent into bodies.**

### A slot has more than one kind of recipient

A lane spawns melee bodies and ranged bodies. A lane's towers cover both the
guards, who walk and swing, and the tower itself, which stands and shoots. So an
upgrade placed anywhere reaches a mixed audience, and how much of that audience
it actually helps depends on what the upgrade does.

**This entry originally answered that with a `shape` tag** — melee, ranged, or
common — sorting upgrades into categories and routing them accordingly. **F28
deleted the tag**, because the sorting was already implicit in the stats and did
not need naming twice. See F28 for the current rule, which is simpler and does
the same job.

What survives from this entry unchanged: the observation that killed the old
refusal rule. [Upgrades slotted into stone](010-upgrades-slotted-into-stone.md)
used to say "speed and health upgrades on an immobile building are meaningless"
and refuse them at the tower slot. That holds only if the slot feeds a building.
**It feeds a patrol as well**, so a movement-speed upgrade slotted into a lane's
towers makes its guards cover their ground faster and answer a breach sooner —
a real purchase, and one of the more interesting ones in the slot.

**Changed:** [009](009-the-shared-upgrade-pool.md), [010](010-upgrades-slotted-into-stone.md), [007](007-guard-towers-and-their-guards.md), issues 401, 408, 303.

## F28. How many kinds of upgrade are there? — **ANSWERED**

**Answer: one. There is no such thing as a melee upgrade or a tower upgrade.
There is an upgrade, and there are the things it happens to help.**

This deletes two fields from the catalogue — `applies_to` and `shape` — and the
entire refusal rule that hung off them.

### The rule

**An upgrade modifies stats. A body benefits to the extent that it has those
stats and uses them.** Nothing tags an upgrade with an audience, because the
audience is already implied by what the upgrade touches.

There are exactly three things upgrades affect: **wave units, guards, and
towers.** And the reason no tag is needed is that these three overlap almost
completely:

| | Has feet | Has a blade | Throws bone | Has health |
| --- | --- | --- | --- | --- |
| **melee wave unit** | yes | yes | no | yes |
| **ranged wave unit** | yes | no | yes | yes |
| **guard** | yes | yes | no | yes |
| **tower** | **no — it is stone** | no | yes | yes |

A guard and a tower are **opposites with everything in common**. One has feet,
the other has stone. One has a blade, the other throws bone. And every property
either of them has, the other has too, or something else in the list does —
**every effect is shared at least once**, which is what makes one catalogue
possible instead of three.

So a health upgrade helps all four, equally usefully, with no rule saying so. A
movement upgrade helps three and does nothing for the tower, because a tower's
speed is zero and always was. A ranged-damage upgrade helps the ranged bodies and
the tower. **None of that needs a field. It falls out of the numbers.**

### What it deletes

**`applies_to` is gone.** It was a two-bit set saying whether a kind could enter
the lane slot, the tower slot, or both, with a validator refusing anything
outside {1, 2, 3}.

**`shape` is gone**, four days after being added. It sorted upgrades into melee,
ranged, and common, and routed them accordingly.

**Every kind-based refusal is gone with them.** [Players, teams, and
commands](016-players-teams-and-commands.md)'s command table had *"kind cannot
enter that slot"* as a refusal reason for placement. **Nothing is refused on the
grounds of what an upgrade is.** Any upgrade may be placed in any slot, and what
it does there is however much of it applies.

### Why this is better than the tag

**A tag is a second description of a thing that already describes itself.** An
upgrade that adds movement speed is a melee-and-guard upgrade *because* it adds
movement speed — writing `shape = melee` next to it says the same fact again in a
form that can disagree with the first one. And it will disagree, the first time
somebody writes an upgrade that adds both speed and ranged damage and has to pick
a category for it.

**It also removes the last case where a placement could be flatly wrong.** With
tags, an upgrade in the wrong half of a lane did a fraction of its work and
nothing warned you. Without them, every placement does exactly as much as it can
do, and the interesting question goes back to being *where is this worth the
most* rather than *did I put it in a slot that accepts it*.

**And it makes the catalogue one table.** Not a lane catalogue and a stone
catalogue, not three shape-partitions. One list of things an upgrade can do to a
stat, drawn from one deck, placeable anywhere.

### What it costs

**Legibility.** A player looking at an upgrade cannot read off a tag which of
their bodies it helps; they have to know that towers do not walk. That is a real
cost and it is paid at the interface rather than in the rules — the viewer owes a
player a clear picture of *what this does and to whom*, and it now has to derive
that from the stats the same way the simulation does.

Which is the right place for it. A rule that exists to make an interface easier
is a rule the interface should have handled.

**Changed:** [009](009-the-shared-upgrade-pool.md)'s catalogue record, [010](010-upgrades-slotted-into-stone.md), [016](016-players-teams-and-commands.md)'s refusal table, [004](004-a-unit-and-what-it-carries.md), issues 401, 404, 408, and F21, F22, A14 — all of which described the tag.

## F22. Are there ranged wave units? — **ANSWERED**

**Answer: yes. A wave is made of three kinds of body — melee, ranged, and a
captain, which is one or the other.**

| | Health | Damage | Reach |
| --- | --- | --- | --- |
| **melee** | 1× | 1× | a small nonzero number |
| **ranged** | 1× | 1× | stands off |
| **captain** | **2.5×** | **1.5×** | melee *or* ranged, depending on the captain |

All three are `flavour = 1`. They are ordinary wave units with different rows in
the unit catalogue, they spawn with the wave, and **all three are stamped with
the lane's upgrades**.

This is what the question was asking and the answer costs more than a row in a
table. Four things follow.

### The lane slot needs the affinity split too

F21 gave the tower slot a three-way delivery — melee upgrades to the guards,
ranged to the tower, common to both — because that slot has two audiences. **The
lane slot now has two audiences as well**, so it works the same way: a melee
upgrade reaches the melee bodies and the melee captains, a ranged upgrade reaches
the ranged bodies and the ranged captains, and common upgrades reach everything.

So the catalogue's `shape` field is not a tower-slot detail. It is a property of
every upgrade in the game, and **placing a ranged upgrade into a lane is never
wasted but is never fully used either** — it lands on part of the wave.

### A lane has an internal composition, and it is a second axis

Before this, a lane was a quantity — how many upgrades sit in it. Now it also has
a **shape**: how much of what you placed there matches what walks out of it. Two
teams with identical chests and identical placements still differ if one of them
stacked melee upgrades into a lane and the other stacked ranged.

That is the second axis under the chest that the question was worried about, and
it is worth having. It also means a placement can be **wrong** rather than merely
suboptimal, which the design did not previously allow: an upgrade in the right
lane and the wrong half of it is doing a fraction of its work, and nothing refuses
it or warns.

### The frontline queue has to be rewritten around it

Issue 206 builds the queue on the assumption that bodies stop at the same
distance — front rank fights, ranks behind stack up and step forward as the front
rank dies. **Ranged bodies break that.** They stop further back, they do not want
the front rank, and a queue that treats them as ranks-in-waiting will push them
into melee range and delete the distinction.

What the queue has to become: the melee bodies form the rank, and the ranged
bodies **hold at their own reach behind it** rather than queuing for a place in
it. That is a real change to the phase-2 work and it belongs in issue 206 now
rather than being discovered in phase 4.

### The captain is the sharpest body in the game, and it is not a hero

Worth stating plainly because it is easy to miss and it changes what heroes are
for.

**A captain gets the lane's upgrades. A hero does not** (A14, and it is
load-bearing — the two economies must not multiply). A captain is 2.5× health and
1.5× damage *before* upgrades; a hero is roughly 2.5× combat weight with
abilities and **nothing else, ever.**

So in a lane carrying a dozen upgrades, **the captain walking out of it is
enormous and the hero standing next to it is not.** That is not a bug. It is the
chest economy visibly out-scaling the wallet economy in a lane somebody committed
to, which is the correct relationship — the chest is the slow accumulating layer
and it should win a long game. What a hero brings instead is **abilities and
timing**: it arrives when you choose, where you choose, and does something a
wave unit cannot do at all.

But it needs watching, and it is the thing issue 804 should measure first: if a
stacked lane's captain makes heroes feel pointless rather than different, the
hero roster is the problem and not the captain.

### What is still open

**Nobody has decided whether a wave's composition is fixed or chosen** — how many
melee, how many ranged, whether a captain is in every wave or only some, and
whether players can influence any of it. The design's instinct says fixed:
players place upgrades, they do not compose armies, and giving them a second
production decision competes with the chest for the same attention. Recorded as
**F27**.

**Changed:** [004](004-a-unit-and-what-it-carries.md), [005](005-waves-and-when-one-is-finished.md), [009](009-the-shared-upgrade-pool.md), [010](010-upgrades-slotted-into-stone.md), issues 201, 206, 207, 401, 405.

## F27. Is a wave's composition fixed, or chosen? — **ANSWERED**

**Answer: fixed, and fixed by whose commander is sending the wave.** No player
composes an army. A commander *is* a composition, chosen once in the lobby, and
what walks out is what that commander sends.

Combined with F35b's rotation — the commanders take turns, one wave each, around
and around — **a lane's composition varies over time and never over space**, and
nobody has a second production decision competing with placement for their
attention.

### What a commander is, now

Three things rather than two. It was a resource name and a hero roster; it is:

1. **A wave composition** — how many melee, how many ranged, and which captain.
   **One captain goes into every lane**, so a wave fields one apiece rather than
   one in total.
2. **A bounty shape**, which falls straight out of the first, since killing a
   body pays the colour it carries
3. **A hero roster**

And those are one decision rather than three, because the composition determines
the bounty and the roster has to answer what the composition cannot.

### The two written down so far

Preserved as given, because they are the first concrete commanders in the project
and the flavour is doing design work:

**The paladin commander.** More strong knights, priests in the back, and bowmen.
Heroes include **paladins** and **white dragons with lightning**.

**The savage noble**, an orc. Fields **barbarians** and **goblin bowmen** behind a
**hobgoblin captain**. Heroes include a **severage destroyer**, a **spiked
mammoth**, and **goblin archers** — many attacks, little damage, which a hero may
be and a wave unit may not.

Read those two against each other and the design is already visible. The paladin
fields fewer, tougher bodies with reach behind them; the orc fields a swarm whose
archers trade damage for volume. **They pay different colours at different
rates**, they want different things placed in front of them, and a team holding
both is farming two economies in alternation — which is exactly what the rotation
is for.

*"Goblin archers — many attacks, little damage"* is also the first statement in
the project that two ranged bodies can differ in **how** they shoot rather than
only in how hard, which is where attack cooldown starts earning its place in the
catalogue as something other than a number that goes down.

### And it opens one thing

**Priests in the back.** A priest implies healing, and healing is currently
assumed not to exist. Recorded as **F38**.

**Changed:** [005](005-waves-and-when-one-is-finished.md), [011](011-commanders-and-personal-resource.md), [004](004-a-unit-and-what-it-carries.md), issues 207, 501, 509, 802.

## F38. What does a priest do? — **ANSWERED IN PART**

**Answer so far: two things, and each scales off a different attribute die.**

| | Scales with |
| --- | --- |
| **Heal** | the priest's **strength** die |
| **Buff fortitude** | the priest's **constitution** die |

So a priest is not one effect with a number attached. It is a body whose two jobs
draw on two different colours of its own dice — which makes it the first unit in
the project whose **internal composition** matters, and the first place the
attribute system reaches down into a body's behaviour rather than only into what
a player can afford.

Two consequences fall out immediately.

**The attribute list is no longer abstract.** Vision 3 says *"there are as many
colors as there are attribute scores"*, which was a shape without contents.
Strength and constitution are now named, and they are named by what uses them
rather than by a table somebody wrote — which is the right direction of travel and
the way the rest should be filled in. B7 and F30 inherit that.

**And fortitude is a new stat**, distinct from armour and from health. What it
resists is not settled, and there is an obvious candidate: vision 3 makes **fear**
the enemy's actual weapon — paralysing, demoralising, subtly diminishing
decision-making — and puts sunlight paladins against it. Fortitude answering fear
would make the priest's two jobs *mend the body* and *hold the nerve*, which is a
much better pair than two numbers going up.

**Still open:** what fortitude resists, and therefore whether fear is built.

**Changed:** [004](004-a-unit-and-what-it-carries.md), [011](011-commanders-and-personal-resource.md), issues 401, 501, 509.

## F39. Who healed whom? — **ANSWERED**

**Answer: nobody solves the assignment. Healers stand where the assignment is
easy, and the five healer archetypes each dodge the problem in a different way.**

The full behaviour is in
[standing off and falling back](022-standing-off-and-falling-back.md). What
belongs here is why the answer is a good one, since the question was posed as a
puzzle about whether a per-body sanity check could be fooled.

### The problem, restated

Two healers, three wounded. One reachable by the first only, one by both, one by
the second only. All three claim a heal; **each claim passes an independent check
and the set is impossible.** It is a bipartite matching, Hall's condition is the
test, and the body standing in the overlap of two healers is the one that goes
unhealed — because the two with no alternative claim their healers first.

### The answer: position so that Hall's condition holds

**A healer keeps itself in range of enough wounded bodies that the healers who
could contest them cannot claim them all.** In practice, within reach of at least
three valid wounded, while out of enemy melee and ranged range.

**That is Hall's condition turned into a movement goal**, and it is the part of
this worth admiring. The hard version of the problem is *given these positions,
find an assignment* — a flow problem, global, expensive, and needing the checker
and the simulation to agree on a tie-break. The easy version is *move until your
own neighbourhood is bigger than the demand on it*, which every healer can do
alone, locally, with no knowledge of what any other healer decided.

It does not guarantee a perfect matching. It makes one overwhelmingly likely,
which is the correct bar for a game.

**And the claim rule handles the rest:** a healer skips anybody already being
healed, and when there are genuinely not enough wounded to go round it relaxes to
*fewest healers on them, lowest health first*. Somebody gets doubled up. Nobody
stands idle.

### And the archetypes answer it five ways

The matching problem appears and disappears down the roster, and **the difference
is the design rather than a leak in it**:

- **Priest** — one target, contested. Has the problem fully, and is the reason the
  positional rule exists.
- **Druid** — one target, but as a regeneration that ticks. Contention is spread
  over *time* rather than over bodies.
- **Paladin** — an area aura. **No selection, therefore no assignment, therefore
  no problem.** The way out that deletes the question rather than answering it.
- **Curse-doctor** — heals allies near a cursed *enemy*. Inverts the whole thing:
  the targeting decision is about the other side, and the healing follows from
  where the fighting is.
- **Rain shaman** — a chain, resolving one bounce at a time, so the assignment is
  sequential and self-resolving by construction.

So there was never one answer to find. **Five units answer it five ways, and that
is what makes them five units instead of five numbers.**

### What the sanity check has to do

Include healers among the things that could explain a health change, as
attackers already are — and for the **paladin, druid, curse-doctor and shaman it
stays a per-body lookup**, because none of those requires knowing who else
claimed what.

**The priest is the only one that needs care**, and the positional rule is what
keeps even that tractable: a priest standing correctly has slack in its
neighbourhood, so a claim against it is explicable without solving anything. The
test in issue 801 should be built against the priest specifically.

**Changed:** [022](022-standing-off-and-falling-back.md) (new), [016](016-players-teams-and-commands.md), [004](004-a-unit-and-what-it-carries.md), issues 203, 204, 510, 801.
## F23. Stamped or read live? — **ANSWERED, and it reverses F1**

**Answer: everything is stamped. Nothing is ever read through a reference. When
the source changes, the affected bodies are cleared and re-stamped by an explicit
sweep.**

F1 said guards read their tower live. That is withdrawn. The reasoning there —
that a guard belongs to something standing still, so reading through costs one
indirection — was true and beside the point. What it bought was the ability to
change your mind; what it cost was a reference in the swing path, and this design
has spent a great deal of effort making sure the swing path touches nothing but
the body's own slot.

So the rule is one rule for every flavour:

> **Clear, then re-stamp.** A body's upgrade counts are a copy it owns. When the
> thing it was copied from changes, every affected body has its vector **cleared
> and rebuilt from the current truth** — not patched, not adjusted, rebuilt.

Three moments trigger a sweep, and only three:

| When | Which bodies |
| --- | --- |
| An upgrade arrives at or leaves a **lane's towers** — at a wave spawn, not the instant it is queued | every guard in that lane |
| A **boon is chosen** | every living body that team owns; during a calm that is the heroes waiting at the library and nothing else |
| A body **spawns** | that body, from its lane or its tower, plus its team's boons |

**Wave units are never swept**, which is not an exception to the rule but the
point of it: a wave unit keeps what it was born with, an upgrade leaving a lane
does not weaken the soldiers already walking in it, and that delay is what makes
a placement a bet worth arguing about.

**Guards are swept and wave units are not.** Both call sites want a comment,
because each looks like a bug from the other one. The difference is that a wave
unit walks away from its lane and dies somewhere else, while a guard stands at
the thing it copied from for its entire life — so a guard whose tower has changed
and whose vector has not is a visible lie, and a wave unit whose lane has changed
is a design feature.

### Why rebuild rather than adjust

An incremental adjustment has to know what changed, apply the delta, and be
correct about the order things happened in. A rebuild reads the current state and
writes it. The first is faster and drifts; the second is slower and cannot.
Sweeps happen at wave spawns and at boon picks — a handful of times a minute at
most, over the bodies in one lane — so the slower one is free.

The general shape, which belongs in `strategems/`: **copy at the boundary, and
when the boundary moves, recopy everything downstream of it rather than trying to
remember what the difference was.**

**Changed:** [004](004-a-unit-and-what-it-carries.md), [007](007-guard-towers-and-their-guards.md), [009](009-the-shared-upgrade-pool.md), [010](010-upgrades-slotted-into-stone.md), [006](006-combat-and-damage.md), F1, issues 303, 405, 605.

## F24. What does a hero do while it waits? — **ANSWERED**

**Answer: a sixth brain state, and it is the only place in the game with room for
personality.**

A17 established that a hero bought during the calm exists, stands at the library,
and marches out when spawning resumes. That needs a state, and the state is a new
one — the brain is six states, not five, and issue 203's title is now slightly
wrong.

The deliberate asymmetry, which is worth a comment: **walking home at the start of
a calm is not a state.** It reuses leashing, with the leash set to the team's own
library. Leaving the map is something the brain already knows how to do. Standing
still with intent is not.

**What a waiting hero should do: meander, idle, and turn to look at the other
bodies standing near it.** None of it may touch the world, none of it is
mechanical, and none of it may be skipped for being decoration. This is the only
moment in the entire match when a body a player paid for is visible, alive, and
has nothing at stake — every other second of a hero's life it is walking toward
something or dying to it. If a player is ever going to feel anything about a body
rather than about the decision that bought it, it is here, in the thirty seconds
before it walks out.

**Changed:** [004](004-a-unit-and-what-it-carries.md), [012](012-hero-units.md), issues 203, 503, 605.

## F25. What does the Golem do to what it walks into? — **ANSWERED, flavour provisional**

**The mechanic is settled. The flavour is a placeholder and is recorded as one.**

It kills melee and ranged bodies differently. Anything that closed to swinging
distance is **grabbed and crushed**. Anything standing off is answered **at
range**. The point of the split is that there is no distance at which a team
farms it safely — close is lethal and back is not safe either — which is what
makes sustaining the damage check hard, because the bodies doing the damage keep
dying. With F22 confirming that a wave contains both melee and ranged bodies,
this is not a hypothetical: every wave sent at the Golem is losing bodies at both
ranges, in different ways.

Mechanically both are entries in the **ability dispatch table**, firing on a
condition, writing into the same pending-damage buffer as an ordinary swing.
Nothing about the Golem is a second damage system.

What the ranged answer *is*, in the author's own words and preserved verbatim
because this project keeps those:

> throws things at ranged units or uses laser beams or something idk

**"Lazer beams or something idk" is the standing answer.** It is a placeholder
and it is allowed to stay one — the Golem's arithmetic does not care what the
projectile looks like, and nothing downstream is blocked. But it is the last
thing anybody sees before a match ends, so it is worth coming back to once there
is a screen to look at rather than settling it now on paper.

**Changed:** [015](015-boons-and-the-challenge.md), issue 606.
## F26. What does a chat channel do to the argument for locks? — **AWAITING EVIDENCE**

Created by the decision to build one (issue 806), and worth watching rather than
pre-empting.

[The shared upgrade pool](009-the-shared-upgrade-pool.md) introduces the lock and
objection system with the line **"three people share one chest and mostly cannot
talk about it in words."** That was true and is now a design decision that was
reversed. The immediate cause was the boon pick — the one moment where nothing
being decided is on the board yet, so all five verbs are useless and a team has
to coordinate blind.

The question is what the lock system is *for* once words exist.

The answer that looks right, and it should be written down and then tested
against people: **chat is persuasion, a lock is enforcement.** A message asks; a
lock refuses. A lock persists without anyone remembering it, works on a teammate
who was not reading, and cannot be argued with in the moment. None of that is
true of a sentence.

If that holds, a team that talks well locks less, and the lock becomes what it
was always described as — *"I am doing something here"* said to somebody who did
not ask — rather than the only channel that existed.

What would falsify it: locks going unused entirely, or the two-objection rule
never firing because disputes get settled in text before anybody objects. Either
would mean the negotiation layer was carrying communication rather than
enforcement, and that a chunk of phase 4 exists to route around a missing feature.

The opposite failure is also possible and is worth naming: **chat becoming the
whole game**, with the board reduced to executing what was agreed in text. That
would be a different game from the one described here, where a placement is a
statement and a lock is an argument.

Issue 804's numbers cannot see any of this. It is a question about six people in
a room, and it gets answered the first time six people are in one.

## F29. Whose upgrades are they? — **ANSWERED, and it changes the centre of the game**

**Answer: each player's own. A team does not share a chest. Both teams draw the
same stones in the same order, and within a team every player gets a different
one.**

This supersedes the shared-chest model that A11 and A11b built and that
[the shared upgrade pool](009-the-shared-upgrade-pool.md) is named after.

### How a draw works now

A draw event deals **one stone to every player on the team**, and deals the *same
hand* to both teams. Worked through with the example as it was given:

| Draw | Team A gets | Team B gets |
| --- | --- | --- |
| first | stone 1 | stone 1 |
| second | stone 7 | stone 7 |
| third | stone 9 | stone 9 |

So on a three-player team, one draw event puts stones 1, 7 and 9 on the board for
each side — one per player. **Both teams hold exactly the same stones. No two
players on a team hold the same stone.**

That keeps the parity argument from A11b completely intact — *if a team is ahead,
it is ahead because of placements* — while removing the thing that argument cost:
under a shared chest, three teammates were three hands reaching into one box, and
now they are three people each holding something.

### What a player may do with theirs

**Place them, move them, and give them away.** A stone belongs to the player who
drew it, and it stays theirs unless they **offer it to an ally**, at which point
it becomes the ally's to place and to give away in turn.

Nobody can take one. Nobody can move somebody else's placement.

### Which means the lock system may have nothing left to do

This is the consequence worth stating loudly rather than discovering during
phase 4, and it is recorded as **F31**.

Locks, objections, and the two-key rule exist for exactly one situation: a
teammate moving something you placed. **That situation cannot arise any more.**
If a stone is yours until you give it away, there is nothing to lock it against,
and `locked_by`, `objection_mask`, `lock_upgrade`, `unlock_upgrade` and
`object_upgrade` are all answers to a question nobody is asking.

[What this game is](001-what-this-game-is.md) states the shared pool as one of
the three reasons the chest replaced heroes — *"It is negotiated. Your teammates
can move what you placed."* That sentence is now false, and the premise document
is the first thing that has to change.

**But the negotiation is not gone. It has changed direction.** Under a shared
chest the conversation was defensive — *stop touching mine.* Under individual
stores it is a request — *can I have that one, I have a use for it.* An offer is
a strictly nicer verb than a lock, it costs the giver something real, and it
cannot be done by accident. It is also the only one of the six verbs that
**transfers** anything.

Whether that is a better game is F31's problem. What is settled here is the
ownership.

**Changed:** [009](009-the-shared-upgrade-pool.md) (extensively), [001](001-what-this-game-is.md)'s premise and vocabulary, [016](016-players-teams-and-commands.md)'s verb table gains `offer_upgrade`, [017](017-the-viewing-layer.md), issues 402, 403, 404, 406, 407, 411, 703, 704, 903.

## F30. Is resource one number or many? — **ANSWERED**

From [vision 3](../notes/vision-3), plus two mechanics that arrived after it and
gave it a shape. Still open because it rewrites the second economy, but no longer
a sketch.

**The core:** there are as many kinds of resource as there are attribute scores,
each with its own colour *and its own display shape* — a bar, a flowy circle
script, pips one to six, a playing card of a randomly generated suit. Killing a
wave unit carrying a colour pays that colour; a captain pays three. A commander's
roster decides the shape of its bounty — *"3 blue die for every 1 green die and
every 5 red die"*. Buying a hero rolls a die per attribute, and picking high
costs more of that colour than picking low.

### Moss balls: a +1 that travels with the stone

**Some stones carry a moss ball among their other effects.** It is not a separate
object and it is not placed separately — it is an attribute a stone has, the way
a stone has a damage bonus, and a stone that has one usually has other bonuses
too.

**It follows the stone.** Wherever the stone is, the moss ball's **+1** applies
to whatever is standing in that same slot:

| The stone sits in | The +1 reaches |
| --- | --- |
| **a lane** | the die roll of wave units in that lane |
| **a lane's towers** | that roll for the tower *and* its guards |

Move the stone and the +1 moves with it. It buffs **only things present in the
same area the stone is present in** — which is the same rule every other effect a
stone carries already follows, so it needs no new machinery at all.

**The +1 is applied at will**, so a player with a mossy stone has a small free
decision on top of the placement: which attribute's die does this point at.

**Expect no more than four to six in any one lane or tower.** That bound is what
keeps the roll a roll. A die plus a large flat bonus stops being random and
becomes a number, and an attribute that has quietly become a number is an
attribute that has stopped being interesting — so the cap is a design constraint
rather than a tuning preference, and the balance work should treat it as one.

An earlier draft of this entry had moss balls as objects belonging to a **tower**
rather than to a stone — accumulating among its bricks, staying where they were
put. That was a misreading and it invented a whole new axis the design did not
ask for. **Nothing here belongs to a place.** Stones belong to players, effects
belong to stones, and where a stone sits decides who its effects reach. The moss
ball is no exception, and the design is smaller for it.

### Bounty stones: investing in a teammate

**Some stones are playable on another player**, and what they do is raise the
**bounty** that player's kills pay — **+1 for a melee or ranged body, +3 for a
captain**, on a particular colour.

The owning player redistributes them freely, so a team can **concentrate its
income**: three people can decide that one of them should be the one accumulating
red, and make it so.

This is the first cooperative act in the design that is not about placement.
Every other way a team helps each other is *here is a thing, put it somewhere* —
this is *I am making you earn faster*, which is an investment rather than a gift,
and it pays out over the rest of the match rather than immediately.

It also pairs with the note that closes vision 3: **every hero has at least one
use for every attribute**, so no colour is ever dead for anybody. Investing red
in a teammate is never wasted on them; it just makes some of their options
cheaper than others.

### What it all collides with

- **"Mechanically it is one number"** — the first vision's own words about
  personal resource, and A2's answer, and all of
  [commanders and personal resource](011-commanders-and-personal-resource.md).
- **The ceiling is per colour, and it is five.** *Settled.* A16 gave the wallet
  one ceiling and made overflow the pressure; there are now as many ceilings as
  there are colours, each filling and overflowing on its own — **and each one
  tops out at five points, which is exactly one d12.**

  So the cap is not a separate number somebody has to pick. **It is the top of
  the die ladder**, and the whole wallet is describable in one line: as many
  colours as there are attribute scores, five points each, spendable in any
  partition up to a d12. Three colours means a maximum wallet of fifteen points,
  which is small enough to draw and small enough to hold in your head.

  That also makes the ladder do double duty. It was a spending rule — how points
  become dice — and it is now the **shape of the wallet itself**, so a player who
  understands one understands the other. Nothing else has to be explained.

  The interaction with A16b is worth naming: **the ceiling rises across a match**,
  which now means it climbs *the ladder* — a colour that starts capped at two
  points can hold a d6 and no more, and by the endgame holds a d12. So a raise is
  not an abstract number going up, it is **a bigger die becoming possible**, and
  a player can see exactly what a calm bought them.

  That is the answer that makes the rest of the system mean anything.
  **Overflowing in blue while starving in red is a situation**, where overflowing
  full stop is only a scolding — and it is a situation with three answers already
  in the design: spend the blue on something you would not otherwise have bought,
  get a teammate to invest a bounty stone in your red, or go and kill different
  things. A single ceiling would have collapsed all of that into *spend
  something, anything*.

  It also gives the interface a harder job, and one worth doing well: a player
  has to see several wallets filling at different rates and notice which one is
  about to waste. That is the one number A16 said should be uncomfortable to look
  at, multiplied — so it needs shape and position, not just colour, which is what
  the display-type rule above is for.
- **A2, "every kill pays every player in full."** Still workable — every kill pays
  every player the colour of what died — but it has to be said that way.
- **The reroll price**, anchored by A11b-ii to the cheapest hero. A hero no longer
  has *a* price.
- **B5** becomes much larger: payouts per colour per flavour.
- **C4's commander uniqueness** gains a second job. It was about roster variety;
  now a commander's bounty shape is part of what it is, so no-duplicates also
  guarantees a team's income is mixed rather than concentrated by accident.

**Not blocked and blocking nothing**, because none of it is built. It wants
settling before issue 501 writes the commander catalogue, since a bounty shape is
now part of what a commander *is*.

## F31. Does the lock system still have a job? — **ANSWERED**

**Answer: no. Locks and objections are optional and are not being built. What
replaces them is the opposite verb — you do not claim a stone, you disclaim
one.**

### Contributing

A player may **contribute** any of their stones to a **communal pool**. Once
there:

- **Anyone on the team may place it, and re-place it, freely.**
- **It appears to each of them as their own.** There is no owner badge, no "this
  is Sam's stone" — a contributed stone is simply one of the stones you have.

That second rule is the whole design and it is worth being exact about why. The
point is not to obscure who gave what. It is that **a shared thing you have to
remember is shared is not shared** — it comes with a small permanent tax of
attention and etiquette, and that tax is what made the lock system necessary in
the first place. Contributing a stone means letting go of it completely. In the
words it arrived in: *they forget they ever didn't own it, and they just use it
as they please.*

### Dismissing

The failure mode of a communal pool is not theft, it is **neglect** — three
people each assuming somebody else is handling it. So:

**A player may mark a communal stone "not my problem", and it disappears from
their view.** Not from the pool; from *their* pool. Somebody else's problem now.

**And when every player has dismissed it, it comes back to all of them.** The
dismissals clear and the stone is visible to the whole team again, and the cycle
can start over.

That single rule is what makes the system safe. A stone cannot fall through the
floor, because the floor closes: the moment nobody is looking at it, everybody
is. It converts *I assumed you had it* — which is silent and permanent — into a
thing that resurfaces on its own.

### Why this is better than a lock

**A lock is a claim and this is a disclaim**, and disclaiming is the honest one.
Locking says *I am doing something here*, which is a statement about intent that
a teammate has to take on trust and cannot verify. Dismissing says *I am not
doing anything here*, which is a statement about attention and is simply true
when made.

**It also has no failure state.** A lock could be forgotten and hold a placement
hostage for a whole match; the interface owed a player a running count of what
they had locked precisely because forgetting was the expected failure. A
dismissal cannot be forgotten, because forgetting it is what makes it expire.

**And it needs no negotiation to undo.** The two-objection rule existed to open a
lock against its holder's wishes — a whole mechanism for one situation. Nothing
here is against anybody.

So: `lock_upgrade`, `unlock_upgrade`, `object_upgrade`, `locked_by`,
`objection_mask` and the objection timeout are all withdrawn. The verbs that
replace them are **`contribute_upgrade`** and **`dismiss_upgrade`**.

**Changed:** [009](009-the-shared-upgrade-pool.md) (the whole locking section), [001](001-what-this-game-is.md)'s vocabulary, [016](016-players-teams-and-commands.md)'s verb table, [017](017-the-viewing-layer.md), issues 406 and 407 (which build the withdrawn system), 703, 704, 903.

## F31b. What happens to issues 406 and 407? — **ANSWERED**

**Answer: they move to `issues/will-not-implement/`, kept and never edited
again.** The git history carries the move, which is what makes deleting them
unnecessary.

Both were blueprints for the lock system. Their numbers are **spent** and will
not be reused, and each carries a short note at the top naming what replaced it —
**412, contributing a stone** and **413, staking a die to share** — with its body
left exactly as written.

That is a third option neither of the two on offer here. Rewriting them in place
would have destroyed a record; leaving them cancelled in `issues/` would have made
the active list lie about what is still to be built. A separate directory does
neither, and it gives the project a place to put the next one.

**The general rule it establishes:** an issue is never deleted and never
rewritten into something else. If the design stops wanting it, it moves, keeps
its number, and gains one line saying where the story went instead.

## F31c. Is there a verb for asking? — **ANSWERED**

**Answer: yes. Build it, because refusing to build it does not prevent it.**

*"People will just use voice chat if we don't allow it in the game."*

That is the whole argument and it is a good one. Leaving asking out of the
vocabulary does not remove asking from the game; it moves it somewhere the design
cannot see, shape, or bound. A verb the game defines can be rate-limited, made
polite by construction, made ignorable without awkwardness, and made to cost
something if it should. A sentence over voice can be none of those.

**What it must not become is the point.** The stated worry is exact: *"players
are supposed to share their units and build each other up, instead of
micromanaging each other's resources."* A request verb that turns into a nagging
channel — pointing at every stone a teammate holds, one after another — would be
the failure, and it is the likely one, because asking is free and giving is not.

So the shape to build toward: **giving must be easier than asking.**

- **Contributing and offering cost a click and a stone.** Requesting should cost
  at least as much attention and probably more — rate-limited, one outstanding
  request at a time, expiring on its own.
- **A request is addressed to a stone, not to a person.** *I would like that one*
  rather than *give me something*, which keeps it concrete and keeps it from
  becoming a general demand for attention.
- **Ignoring one is free and silent.** No notification that you declined, no
  record, nothing a teammate can point at afterwards. A request that can be held
  against you is a demand.

Which leaves the team with three verbs that move a stone and one that asks about
one — and the asking is the only one of the four that changes nothing by itself.

**Changed:** [009](009-the-shared-upgrade-pool.md)'s verb table gains an eighth row, [016](016-players-teams-and-commands.md), issue 412.

## F32. "Stone" means two things and one of them has to go — **ANSWERED**

**Answer: a stone is an upgrade. The guard-tower meaning is withdrawn.**

This is a collision I introduced and it is worth recording as a caution rather
than quietly fixing, because of *how* it happened.

**What went wrong.** The audit found the word "stone" used a couple of hundred
times across the documents to mean *guard towers, spoken of as a material* —
never defined anywhere, not present in the vision, and load-bearing in one good
sentence: *an upgrade goes either on bodies that walk forward and die, or on
stone that stays put and does not.* The fix seemed obvious: define it, since it
was doing real work and only lacked an entry.

That was the mistake. **The word was not the project's to spend.** Two visions
later it turns out a stone is what a player holds — a rune with a colour, listed
under a tower, tapped to pick it up — and the vocabulary table had already given
the name to something else.

**So the guard-tower meaning goes.** Where a document needs to talk about towers
as a material, it says *towers*, or names the thing directly. The one sentence
that needed the metaphor can have it without the word: an upgrade goes either on
bodies that walk forward and die, or on the towers that stay put and do not.

### What still has to be renamed

Not done yet, and listed so it is not forgotten:

- **[Upgrades slotted into stone](010-upgrades-slotted-into-stone.md)** — the
  document's own title, and its filename.
- **Issue 408, "slotting upgrades into stone"** — same, and the roadmap and phase
  tracker rows that name it.
- Prose uses throughout 007, 009, 010, and the phase-3 and phase-4 trackers.

Renaming a document and an issue file touches the roadmap, the tracker, the table
of contents, and every link — so it is a job to do deliberately in one pass with
the validator watching, rather than incidentally.

### The general caution

**A term that is used everywhere and defined nowhere is not necessarily free.**
It may be undefined because nobody has needed it yet, or because it is already
spoken for by something that has not been written down. The check that would have
caught this costs one question: *does the author use this word for something
else?* — and the place to look is the vision, which is the only document nobody
else wrote.

**Changed:** [001](001-what-this-game-is.md)'s vocabulary. The renames above are outstanding.

## F33. Should this become a PvP zone in Everland Ghostsong? — **DIRECTION SET**

**Yes, as a target rather than a port, and the host keeps its own engine.**

The proposal is to build this inside the AzerothCore project at
`~/games/azeroth-core/wow-chat-2026/` — *Everland Ghostsong*, whose stated
premise is that **the game exists for socialising** and that combat and
progression are the backdrop for conversation.

### What made it obviously worth doing

**The socialising premise is this project's premise.** Everland's philosophy is
that the world is a backdrop for conversation; this project's thesis is that a
shared pool people argue over beats avatars people drive. Those are the same bet
made twice, and a PvP zone built on negotiation belongs there more than an
ordinary battleground would.

**Playerbots already exist there**, described as companions that join your party,
follow commands, and have their own behaviours. That is most of phase 9 already
standing, including the hard half — the *teammate* bot.

**The world is already empty.** Everland removed every NPC and creature so the
world is quiet until a player arrives, which is exactly the canvas a lane-pusher
needs: a space where nothing exists except what the match spawns.

### The engine stays the host's

**The host handles the engine's jobs — networking, graphics, scheduling, bodies
on screen — and this project supplies the rules.** That resolves what looked like
the fatal objection and it is worth being precise about what it actually costs,
because something real is given up.

**These do not survive, and they were never design features:**

- the fixed tick, and durations counted in ticks
- the named random streams
- same-seed-same-result
- the replay

**Every one of those is a property of the reference implementation, not of the
game.** That distinction was already half-discovered by E2, which found that the
networking model does not rely on lockstep and that the determinism test "proves
nothing about two machines." It is now fully general: **determinism is a thing
this project builds for itself so that it can test and measure. It is not
something the game needs in order to be the game.**

Which means the port loses the *instruments* and keeps the *design*. Balance
numbers still come from the LuaJIT implementation running ten thousand matches
overnight; the host runs the game people play.

### What transfers, precisely

Everything written down as a rule, and it is nearly all of it: the shared deck
dealt one stone per player, contribute-and-dismiss, the offer, the command
radius, the surge that reads instead of confiscating, the boon pair offered to
everybody, the milestone comparison, the one-turn sign-post, the Golem whose
health is its speed.

None of that needs a clock anybody owns.

**Changed:** nothing yet. This becomes real at phase 7 or later, and the decision to take now is only F34's — whether the source is authored with language markers from the start.

## F34. Should the source be polyglot? — **DIRECTION SET**

Write the source in several languages at once, keeping the inactive ones in
structured comments, with a small activator switching which is live. One of the
languages is "ported to azerothcore" (F33).

**Written up as a reusable skill** at `~/.claude/skills/polyglot-source/`, since
the idea is not specific to this project.

### The rule that makes it affordable

**Delete what you are no longer sure of. Git is the other implementations.**

That inverts the obvious instinct and it removes the objection that would
otherwise sink the whole idea — that every change becomes N changes and the
inactive versions rot silently.

They are allowed to rot. A block nobody can vouch for is **deleted**, not kept
and not marked stale, because a wrong implementation sitting in a file is worse
than an absent one — somebody will activate it.

**Recovery is mechanical**, and it is the reason this works:

1. `git log` the file, find the last commit where that language was current.
2. Diff **the rest of the machine** from there to now — not the deleted block.
   What did the canonical language do since, what did the records become, which
   rules changed.
3. Re-derive the block from the design as it now stands, treating the old one as
   a sketch of how that language thinks rather than as a text to patch.

Bringing an old block forward line by line is how you get something that compiles
and is wrong in the way the system used to be.

**So "how out of date is this version" becomes a commit range** rather than a
feeling, which is strictly better than a stale block that looks maintained
because it sits next to a maintained one. And the cost of a change goes back to
being one change: fix the canonical language, delete what you cannot vouch for,
carry on. The bill for a target arrives when somebody wants that target, as a
readable diff of everything that happened since.

### For this project specifically

**LuaJIT stays canonical.** The house style says so and nothing here argues with
it. A polyglot tree has one language that gets fixed first, or it drifts into
several half-programs.

**The second implementation is the review.** Writing the soldier brain again in a
language with different primitives finds every place the first version leaned on
something incidental. This project has spent real effort on documents catching
each other's contradictions; a second implementation catches a different class.

**And under F33 the gaps are the deliverable.** A unit with no AzerothCore version
and a note saying *the host runs scripts on its own worker and does not hand out
slices* is a recorded fact about the target at the line where it matters. Those
notes, collected, are the map of where this design depends on owning its clock.

### The one decision to take before phase 1

**Whether source files are authored with language markers from the start**, and
what a unit is — per function is finest and noisiest, per file is coarsest and
easiest to keep honest. Retrofitting markers onto a finished tree is mechanical
but large, and the unit boundary wants choosing once and never again.

## F35. The economy tripled — is that all right? — **ANSWERED**

**Answer: yes, blessed. And the problem it was really about was legibility, not
arithmetic, so the fix is a merge rather than a rate change.**

A draw deals one stone to every player, so a three-player team gets three stones
per wave wipe and nine per felled tower — three times the old rate, scaling with
team size. That stands. Balance absorbs it: individually weaker stones, a longer
deck, or wipes that come less often. It also makes contributing and offering
matter early in a match rather than only late, which is the right direction.

### Stones of a kind merge where they sit

**Two stones of the same kind in the same slot become one stone**, showing its
count. In a lane or in a lane's towers — **never in a chest**, private or
communal, where a player is still choosing what to do with each of them.

**A double right-click breaks a merged stone back into its constituents**, for a
player who wants to send them different places.

That is a presentation rule doing a design job, and worth stating as one:
**the problem with a three-times-faster economy is not that it is too strong, it
is that it looks like too much.** A lane holding twelve separate stones is
unreadable; a lane holding four stones, one of them showing ×5, is a board a
person can take in at a glance. The merge costs nothing mechanically — counts
already stack, since a body carries a count vector — and buys back the whole
legibility loss.

### Two other levers, kept and not spent

Both are recorded because they may be wanted when the numbers arrive, and one of
them was considered and disliked on the spot.

**Rarer draw events.** Keep one-stone-per-player but stop paying it on every wave
wipe. Preserves the per-match total at the cost of making a wipe feel unrewarding.

**Per-player lanes** — each player spawning wave units into one lane according to
their commander, earning bounty only in the lane they fought in, with the towers
carrying their unit types too. **Rejected on sight, and the reason is worth
keeping:** *"I don't like this design, I think it would limit the player's
viewpoint and make them tunnel vision."* Every-player-touches-every-lane is a
design pillar, and this would have quietly repealed it in exchange for a tidier
economy.

**Changed:** [009](009-the-shared-upgrade-pool.md), [017](017-the-viewing-layer.md), issues 402, 403, 703.

## F35b. How do three commanders' wave compositions share one map? — **ANSWERED**

Created by rejecting per-player lanes, and it is the better answer.

**The commanders take turns.** Wave one is commander A's composition, wave two is
commander B's, wave three is commander C's, then A again. Every wave still goes
into every lane.

Two things fall out and both are good.

**The whole map is covered by every commander in rotation**, so nobody is
confined to a corner of it and the tunnel-vision problem never arises. Bounty
shape varies over *time* rather than over *space* — which means every player is
farming the same colours as their teammates at any given moment, and the mix
comes from the rotation rather than from where you happened to be looking.

**Everyone is invested in how each commander is built**, including the two they
did not pick. A teammate's roster is not their business alone; it is a third of
what walks out of your base. That makes commander selection in the lobby a team
conversation rather than three private preferences, and it gives C4's
no-duplicates rule a second job it did not have.

### Which gives heroes a spawn queue

Since waves now belong to commanders in rotation, a hero can be **queued to spawn
with a future wave** — up to **N−1 waves ahead**, where N is the team size, but
**never fewer than one**.

**Not the current wave.** That is the constraint the rule is built around: by the
time you are looking at a wave it has already left, so buying a hero onto it is
buying into something you can no longer influence.

| Team size | Queue depth |
| --- | --- |
| 1 | **1** — the special case; N−1 would be zero and there would be no way to buy a hero onto a wave at all |
| 2 | 1 — the next wave only |
| 3 | 2 — the next wave or the one after |
| 4 | 3 |

So the rule is **max(1, N−1)**, and the exception exists only at a team size of
one, where the formula would otherwise close the door entirely.

At every size above one the horizon is exactly *up to but not including your own
commander's next turn*, which makes the depth a consequence of the rotation
rather than a number somebody picked. At a size of one there is no rotation to
speak of — every wave is yours — so the horizon is simply the next one.

This changes the first of the three hero destinations in
[hero units](012-hero-units.md) — *onto a wave*, which was immediate — into
something scheduled, and it should be read as a strictly better version of it: a
purchase with a delivery date is a commitment, and this design has consistently
found that commitments are what make decisions worth arguing about.

**Changed:** [005](005-waves-and-when-one-is-finished.md), [011](011-commanders-and-personal-resource.md), [012](012-hero-units.md), issues 207, 501, 505, 802.

## F36. During a surge, whose stones are dealt? — **ANSWERED**

**Answer: everybody's. All of them, private hands included, pooled for the
duration and applied at random.**

*"During a siege-surge we collect all the stones and use them for united purpose —
spawning units all over the map of all three kinds. It's intended to be chaotic
but fair, and to this end all of the stones are applied randomly while the
commanders at home are deciding how to distribute them for the challenge
monster."*

Three things in that worth pulling out.

**Ownership stops mattering for the duration, and only for the duration.** A
surge is the one stretch of a match where the question *whose is this* has no
answer, because everything is being dealt at once to bodies coming out of every
lane. Nothing is transferred and nothing changes hands — the stones are read, not
moved, exactly as F11 established. When the surge ends, everything is still
exactly where and whose it was.

**Hoarding stops working, without a rule against it.** A stone held privately and
unplaced is on the field during a surge precisely as much as a placed one, so
there is no pre-surge hold to be clever about. That closes C1b's worry for the
second time and from a different direction: the first fix was that the deal
ignores slots, and this one is that it ignores owners too.

**"Chaotic but fair" is the design instruction**, and the two halves are doing
different jobs. Chaotic: random application, all three body kinds, every lane at
once, no arrangement surviving. Fair: *everything* a team has is out there, so
nobody is holding anything back and nobody is being deprived of anything.

### And what the players are actually doing meanwhile

**Deciding how to distribute them for the challenge monster — and each monster
has different requirements.**

That is new and it makes the surge's retooling window concrete rather than
general. It is not *rebuild your board for the next stretch of play*; it is
**build the board that beats the specific thing walking out of the middle next**,
which is known in advance because the three challenges are a fixed named
sequence.

So the Pillar Orc, the Field Dragon and the Eternal Golem want three different
arrangements, and a team that knows which is coming is spending the surge
answering a question with a right answer. What those requirements are belongs
with B9 and the monster catalogue.

**Changed:** [014](014-the-siege-surge.md), [009](009-the-shared-upgrade-pool.md), [015](015-boons-and-the-challenge.md), issues 603, 606.


## F37. What does a staked die cost? — **ANSWERED, and it defines the whole wallet**

**Answer: one point. It drops you down one notch, and a reroll needs one from
every player.** No roll, no gamble, no variable price. All three readings this
entry was holding open were overthinking it.

The answer arrived with the thing it depends on, so the wallet gets written down
here.

### Resource is points, and points are spent as dice

A colour is held as a number of **points**. Points are turned into **dice** when
spent, on a fixed ladder:

| Points | Die |
| --- | --- |
| 1 | d4 |
| 2 | d6 |
| 3 | d8 |
| 4 | d10 |
| 5 | d12 |

**d12 is the largest die there is.** A player with more than five points in a
colour holds more dice, not a bigger one.

**And you partition your points however you like at the moment of spending.**
Three red points is *any* of:

- **3d4** — three small dice
- **1d4 + 1d6** — one small and one medium
- **1d8** — one large

Those are the same three points wearing different shapes, and the worked example
is the part that matters: **if a hero costs 2d4, a player with three red points
can pay it and keep one point over** — spending two of their points as two small
dice and holding the third. Nothing is wasted by having chosen a shape, because
the shape is chosen at the counter.

That is the mechanic underneath *"depending on if you pick high or low, it costs
more or less"* from vision 3: an expensive hero wants big dice, which means
committing several points into one of them; a cheap one wants small dice and
leaves change.

### So a stake is one point

**Staking a die to share drops your colour down exactly one notch.** Three red
becomes two red — you had 3d4 or 1d4+1d6 or 1d8 available, and now you have 2d4
or 1d6. Nothing is rolled, nothing is at risk, the point is simply gone.

**The reroll fires when the team has staked one each** — three on a three-player
team. So a collective reroll costs every player one point, in whichever colour
each of them chose to pay from, which makes it cheap for a rich team and real for
a poor one with no rule saying so.

And it keeps what made the mechanism good: **one person dismissing costs
nothing** until the others agree. Declining to care about a stone is free right up
until the whole team declines together.

### What this settles beyond itself

**A hero's price stops being a number.** It is a *hand* — 2d4, or 1d8, or 1d6+1d4
— so two heroes costing the same total points are genuinely different purchases,
because one wants its points concentrated and the other wants them spread. That
is what F30's *"a hero purchase becomes a shape rather than a price"* was
reaching for, now with the shape written down.

**And the per-colour ceiling has an obvious candidate**, though not a settled one:
five points is one d12 and the top of the ladder. Whether a colour caps there, or
whether a player may hold more points as several dice, belongs with A16 and the
numbers.

**Changed:** [011](011-commanders-and-personal-resource.md), [009](009-the-shared-upgrade-pool.md), issues 411, 413, 503, and F30, which this fills in.

## F40. Are the healers wave units or heroes? — **ANSWERED**

**Answer: wave units. So are captains. The commander decides which.**

Healing is not a purchase. It arrives with the wave, in the ordinary way, and
dies in the ordinary way — which means a lane that is being sustained is being
sustained by bodies the enemy can kill, and killing them is how you stop it.

### What a commander actually determines

Everything about what walks out, and **none of it is a stat block**:

| | Set by the commander |
| --- | --- |
| **The captain** | which one — its signature body |
| **The composition** | what proportion of the wave is melee and what is ranged |
| **The bounty dice** | which colours its bodies carry, and therefore what killing them pays |

**And the melee and ranged bodies themselves are always the same stats**, for
every commander, buffed by whatever is placed in their lane. A knight and a
barbarian are one body wearing two costumes, and so are a bowman and a goblin
archer.

That is a much larger simplification than it looks and it is the right one. It
means a commander is **a mixture and a captain**, not a private unit catalogue —
so adding a commander is choosing proportions, colours, and one signature body,
rather than balancing three new stat blocks against everything that exists.

**And the goblin archers moved rather than being flattened.** *"Many attacks,
little damage"* was originally read as the first statement in the project that
two ranged bodies could differ in **how** they shoot. That cannot be true of a
wave unit any more — but it can be true of a **hero**, and that is where the
goblin archers went: onto the **savage noble's roster**, alongside the severage
destroyer and the spiked mammoth.

Which is the better home for them anyway. A hero is where a body is allowed to be
strange, and *many small fast attacks* is a genuinely different thing to buy from
anything else on a roster — it is the answer to armour, since a flat subtraction
per hit punishes exactly that profile, and something has to be.

So attack cooldown as a differentiator is off the table **for wave units** and
very much on it for heroes and captains.

### The captain is the signature

**Each commander has a different captain**, and it is where the commander's
character lives. The paladin commander's captain is a **priest**. The savage
noble's is a **hobgoblin captain**.

So a captain is not always a healer — but several of the healers are captains,
which is what makes healing a property of *who you brought* rather than a role
somebody fills. A team of three commanders fields three different captains, in
rotation, and therefore three different kinds of support, none of which anybody
chose to buy.

**Which resolves the trap this entry was worried about.** Wave units carry their
lane's upgrades and heroes carry none — so if healers had been heroes, a heal
would never scale while everything around it did. As wave units, **a healer gets
stronger exactly as the lane it walks in does**, which is the same rule as
everything else and needs no exception.

### And some of the named units are still heroes

Paladins, white dragons with lightning, severage destroyers, spiked mammoths.
Those are bought, they carry abilities, and they carry no lane upgrades. The
druid's moon spike sits with them.

**Changed:** [004](004-a-unit-and-what-it-carries.md), [005](005-waves-and-when-one-is-finished.md), [011](011-commanders-and-personal-resource.md), [022](022-standing-off-and-falling-back.md), issues 501, 509, 510, and F27, which described commander composition before this narrowed it.
---

## How this list is meant to be used

Work down Group A first, one at a time, out loud. Each answer gets written into
the document it changes, the working ruling paragraph gets deleted, and the entry
here is rewritten as **Answered** with the reasoning kept — not removed, because
the road not taken is worth being able to find again.

Occasionally an answer is **to delete something.** A7 is one: the vision's
no-repeat-lane rule was cut as arbitrary, the issue file for it removed, and every
mention pruned. Its entry survives only so that nobody re-derives the rule from
the vision and puts it back.

Occasionally an answer **takes a word.** D6 is one: "ping" went to the map, where
players already expect it, and the lock-releasing verb was renamed to **object**
across every document and issue.

**Run `./validate-documentation` after answering anything.** It fails if an issue
still cites a question that has been answered, which is the most common way this
page and the issue files drift apart.

## What is still open

**Nothing blocks building anything.** Forty-one of sixty-five are answered, and
what is left divides cleanly:

**Group B — the numbers.** B1 through B10 are wave sizes, intervals, radii,
payouts, catalogue weights, and monster health. **None of them is answered by
thinking.** They are found by running the thing, and the first entry in
`balance-updates.md` should be whatever they are initially set to, with a note on
where the values came from.

**B11 is not a number.** *Does the frontline actually move?* The vision's premise
is that a lane-pusher with the heroes subtracted out stalemates, and nothing in
twenty-three documents proves the shared chest, the two economies, and the surges
are enough to unstick it. It is the largest question in the project and issue 804
is the only thing that can answer it.

**Four rules nobody has needed to settle yet.** A3, how many players per team —
three is assumed everywhere, written against a constant. A4, whether "the guards
in the base" meant soldiers or towers; both readings are implemented, which is
defensible and is not a decision. A8c, what happens when one team's challenge
monster dies long before the other's. C1b, whether a visible surge clock lets a
team dodge the chest-dealing by holding upgrades in the chest.

**Two curves nobody chose.** A16c, a flat reroll price against a rising ceiling,
so rerolling gets cheaper in real terms as a match runs. A11b-iii and C3, the
hero economy as the design's one unbraked snowball — a winning team earns more,
fields more heroes, and can reroll more, and nothing interrupts it the way a
surge interrupts the chest. Both show up in issue 804's numbers rather than in an
argument.

**One scope question.** C4b, how many commanders — a handful with no duplicates
per team produces a small number of possible compositions, and players will
exhaust them quickly.

**Five technical questions with no deadline.** E3 body counts, E4 storage layout,
E5 replay storage, E6 whether the map builder ever emits a non-standard map, and
E7 how good the bot has to be — which is really the question of whether this
ships single-player, and probably deserves its own phase if it does.

That is the whole list as it stood before anything was built. **This stops being
a design and starts being a program at issue 101** — and building it turned up its
own set of disagreements, which are Group G below.

---

# Group G — Found while building it

Writing the program is itself a review, and a harsher one than reading the
documents against each other. A document can describe two things that cannot both
be true and stay perfectly readable; a program has to pick one, and the picking is
where the disagreement surfaces.

Everything below came out of building the prototype — the map builder, the
simulation, the camera, and the viewer. None of it is a complaint about the
design. Each entry is a place where the documents are either **not consistent**,
**not yet implemented**, or **quietly disagreed with by the code that had to
choose**, and every one of them wants an answer from a person rather than from
whoever next reads the file.

## G1. Does the centre lane's junction have three neighbours or four? — **ANSWERED**

[The map](002-the-map-and-its-milestones.md)'s node record says a junction has
three neighbours, and adds "the centre lane's midpoint is a junction too, so it
has three."

It has four, and the geometry the same document describes is what makes it four.
A short connector joins **each** side lane's junction to the middle. The centre
lane's midpoint therefore carries two lane neighbours plus two connectors, while
each side junction carries two lane neighbours plus one connector and does have
three.

The builder emits four and the validator accepts it, because four is what the
described shape produces. Three readings are available:

1. **The sentence is simply wrong** and the centre junction has four. Nothing in
   the design depends on the number; it is a fact about the graph, not a rule.
2. **The two connectors should land on different nodes** — one just before the
   midpoint and one just after — which restores three neighbours everywhere and
   makes crossing the middle a two-step journey rather than a single point every
   route passes through.
3. **There should be one connector, not two**, joining the two side junctions and
   crossing the centre without touching it — which would mean a body can go from
   the top lane to the bottom without ever entering the middle, and that is a
   different game.

The first is a one-line documentation fix. The second and third are design
changes.

**Answer: four is correct, and the document was wrong.**

The number is a fact about the graph rather than a rule anybody plays by, and
nothing in the design rests on it. Both connectors landing on the same node is
also the better shape: it makes the middle a single place every cross-map route
passes through, rather than two crossings that happen to be near each other.

**Changed:** [002](002-the-map-and-its-milestones.md)'s node record, and the
paragraph about connectors now says outright that both of them land on the
midpoint and why that leaves it with four neighbours.

## G2. Exact mirror symmetry does not hold, and it is asked for by name — **ANSWERED**

[The shape of the code](018-the-shape-of-the-code.md) names two tests that run on
every build. Reproducibility is implemented and passes. **Symmetry is not, and
would not pass.**

A match with no player commands should leave the two teams in exact mirror states
at every tick. It does not. Two causes, and only one of them is fixed:

- **The tie stream was shared between the teams**, so each team's luck depended on
  how often the other team happened to have a tie to break. That is fixed — it is
  now one stream per team, for the same reason `draw` always was.
- **The spatial grid is walked in row-major order.** A body at (a, b) and its
  mirror image at (b, a) see their equally-good candidates in *different orders*,
  because reflecting the map swaps the axes and the walk does not. Tie-breaking
  picks the nth candidate uniformly, but the nth candidate is a different body on
  each side.

After the first fix the asymmetry is systematic rather than random — both teams
drift in a consistent direction rather than diverging noisily — which is what a
scan-order cause looks like.

Making it exact means giving the tie-break a **canonical ordering** that does not
depend on how the grid was walked: sort the tied candidates by something
reflection-invariant before choosing. That costs a sort in the hottest loop in the
game, on every tie, forever.

So the question is not "how do we fix it" but **is exact mirror symmetry worth
that price**, or is the test better written as a tolerance — the two teams' push
depths within one milestone of each other over a long unattended match — which
would catch every real asymmetry and cost nothing.

**Answer: neither. The simulation is set up symmetrically and then allowed to
diverge.**

> The simulation should be set-up in a symmetrical fashion, but it will very
> quickly diverge, so there's no reason to try and maintain it beyond the starting
> conditions.

That reframes what the test is for. Symmetry is a property of the **opening**, not
of the match: the map mirrors, both teams start with the same stone in the same
places, and the same bodies leave both bases on the same tick. Past that, two even
sides are supposed to come apart — a tie broken one way in one lane is broken the
other way in another, and by the second exchange the two halves are different games.

Holding the mirror any longer would cost a canonical ordering on every tie in the
hottest loop in the simulation, bought to preserve something with no gameplay
meaning after the first ten seconds. The per-team tie streams stay, because they fix
a real coupling — each team's luck depending on how often the *other* team had a tie
— which is worth fixing regardless of symmetry.

**Changed:** [018](018-the-shape-of-the-code.md)'s two standing tests, and the
invariants, which now assert the opening rather than every tick.

## G3. Lane width does nothing — **ANSWERED, and it is not the question it looked like**

Three documents say a lane's width feeds exactly two things: how wide the renderer
draws it, and **how many bodies the frontline queue lets stand abreast.** The
renderer draws it. The queue does not read it.

What is implemented is a queue by personal space: a melee body stops short behind
a friendly body ahead of it in the same lane, and ranged bodies keep a smaller
bubble and hold behind the rank. That produces ranks, and the ranks read correctly
on screen. But it is **single file**, so the centre lane's whole design property —
that it is where numbers matter most, because more bodies get into contact at
once — does not currently exist. The centre is wider only in the drawing.

This also blocks **B1**, which instructs that a wave should be *wider than the
lane can fit abreast* so that ranks queue visibly. That instruction cannot be
followed while the answer to "how many fit abreast" is always one.

The shape of the fix looked clear enough — a lane holds a small number of
parallel files, and a body picks the nearest free one.

**That was the wrong question, and the answer replaces it rather than settling
it.** Recorded as it was given:

> draw a line toward the enemy, then arrange your formation for the advance. a
> basic one is lines of melee in front of lines of ranged, with cavalry behind so
> they can flank toward the flank of theirs that's weak. Draw a line through the
> enemy like the way the healers do to orient themselves, and then make your rank
> lines parallel to that. The lanes are mostly suggestions, the world is actually
> just a dense mixture of plains, forests, mountains, etc... But for our purposes
> just say it's flat everywhere. The lanes should determine the path that you take
> toward the enemy, but not how you should be arranged when you engage. You should
> make a line parallel to the line through the enemy group, and arrange your guys
> oriented to that line. Once fighting begins it's less important to retain
> cohesion, but the approach is how you engage.

**So a lane never constrains a formation at all.** The lane is the *path*; the
enemy is the *arrangement*. A host draws the line through the mass of the enemy
formation — the same line a ranged body already uses to decide which way to orbit,
which is why this needs no new mechanism — and forms its ranks parallel to it:
melee in front, ranged behind at their own reach, cavalry behind that to flank
whichever of the enemy's flanks is weak.

A rank is therefore **as wide as theirs**, not as wide as the corridor. A host
with more bodies than the enemy's line is wide puts the surplus in the ranks
behind, which is where a numerical advantage belongs.

Two things fall out and both are worth stating.

**The world is flat, deliberately and consciously.** *"the world is actually just
a dense mixture of plains, forests, mountains, etc... But for our purposes just
say it's flat everywhere."* That is a simplification being accepted with its eyes
open rather than an absence of terrain, and it should stay visible as a choice.

**The centre lane's whole mechanical purpose evaporates**, which is a real cost
and is raised as **G8** rather than buried in this answer.

**Changed:** issue 206, which is now a formation issue rather than a queue issue,
and keeps the paragraph above verbatim.

## G4. Is one draw per wave wipe far too generous? — **ANSWERED, and it was the wrong question**

Measured rather than argued, so it belongs in Group B's spirit even though it was
found here.

Nearly every wave in a stalemated match is eventually wiped, because a wave that
meets an even wave grinds until one side is gone. So nearly every wave pays. In a
twenty-two minute headless match each team drew **around a hundred and ninety
upgrades**, all of which sat unplaced because nothing was placing them.

Three readings, and they are not exclusive:

1. **It is correct and the number is only shocking because nobody is placing.** A
   real team spends them as they arrive, and a hundred and ninety placements over
   twenty-two minutes across three players is roughly one every twenty seconds
   each — busy, not absurd.
2. **The wipe is too easy to earn.** A wave that dies to towers counts, and a wave
   both sides grind to nothing pays whoever survived by one body.
3. **The match is too long**, and it is long because the surge and the challenge —
   the two things that end matches — are not built.

The third is most likely and is why this is awaiting evidence rather than open:
the number should be re-measured once a match can actually end, not tuned now
against a match shape that will not exist.

### The evidence, and it reverses the question

Twelve matches, both sides played, every one of them finishing: **167 upgrades drawn
per match and 89% of them placed.**

So the draw rate is not too generous. The chest is not filling faster than a team can
empty it — a team that is *playing* empties nearly all of it. The hundred and ninety
unplaced stones that prompted this question were the product of a match with **nobody
in the chair**, which is not a finding about the economy at all.

That is worth keeping as a lesson rather than just an answer. The measurement was taken
from an unattended match because that was the only kind of match that existed, and it
described the absence of a player rather than the design. **A number taken from a game
nobody is playing is a number about nobody playing.**

What the same run *did* turn up is a real imbalance, and it is on the other side of the
economy: five hundred heroes bought per match and five thousand points of income
thrown away on top of that. See `balance-updates.md`. The wallet, not the chest.

## G5. Should the side lanes be so much longer than the centre? — **ANSWERED**

The described shape produces side lanes about **1.7 times** the centre lane's
length, because a side lane runs out to a corner and back while the centre cuts
the diagonal. Nothing in any document says whether that is intended.

The consequence is real and visible: first contact happens in the centre a long
time before it happens anywhere else, and every side lane's first wave meets the
enemy's much later. That is authentic to the genre this one is subtracted from,
and it gives the centre a second distinguishing property beyond width — it is
where the match starts.

But it interacts with **G3** and with the centre being the wide lane. If the
centre is where numbers matter most *and* where contact happens first *and* the
route both connectors lead to, it may simply be the whole game with two side
shows attached.

The alternative is bending the side lanes inward so all three are closer in
length, which costs the clean "out to the corner" shape and the neat fact that
milestone 4 is exactly the bend.

**Answer: intended, and now written down.**

It gives the centre a distinction beyond being wide: **it is where the match starts.**
First contact of every match happens there, the side lanes develop later, and a team
learns what it is facing in the middle first. The three lanes are therefore not
interchangeable in time as well as in shape, which is worth having in a game whose
whole read is a comparison between three of them.

**Changed:** [002](002-the-map-and-its-milestones.md).

## G6. Are upgrades applied per swing or folded in at birth? — **ANSWERED**

[Combat and damage](006-combat-and-damage.md) describes step 4 of a swing as
walking the attacker's count vector and applying each nonzero entry.

The prototype **folds the modifiers into the body's own fields at stamp time**
instead, and keeps the count vector on the body only so the renderer can draw the
badges an opponent reads an arrangement off.

The two produce identical numbers. Folding does the multiplication once per body
rather than once per blow, and it is safe precisely because of a rule the design
already committed to: a wave unit's vector never changes after birth, and a
guard's only changes when its tower does — which is exactly when it is re-stamped.

So this is a documentation question and not a behaviour one: **which should the
document describe?** The written version is easier to reason about; the built
version is what runs. Leaving them different is the thing that must not happen,
because a reader who trusts the page will look for a loop that is not there.

**Answer: the document describes what runs, which is folding at birth.**

And this should not have been a question. A page that no longer matches the software
is a bug of the same severity as a wrong answer from a function, and it is fixed the
same way — immediately, by whoever noticed, without asking. There is nothing here to
rule on. That rule is now written into
[the shape of the code](018-the-shape-of-the-code.md) so that the next one is not
asked either.

**Changed:** [006](006-combat-and-damage.md).

## G8. What is the wide centre lane for, now that width does not cap a rank? — **ANSWERED**

Created by **G3**'s answer, not settled by it.

The centre lane is wider than the side lanes, permanently, as topography. Every
document that mentions it gives the same reason: more bodies get into contact at
once there, so **the centre is where numbers matter most** — stacking a side lane
is a bet on quality and stacking the centre is a bet on quantity. That was the
only real difference between the three lanes, and it was one number in the map
builder's table.

G3 removes the mechanism it rested on. If a rank is as wide as the enemy's line
rather than as wide as the corridor, then a fight in a side lane and a fight in
the middle are the same fight, and the width is a drawing.

Four ways out, and they are not equally good:

1. **Let it go.** The centre already has three other things: it is the shortest
   lane so contact happens there first, it is where both connectors land so it is
   the only route between the flanks, and it is where the challenge monsters walk.
   That may be enough to make it distinct without a width rule.
2. **Width caps the formation after all**, as a soft maximum — the enemy sets the
   rank's width, but the corridor sets a ceiling on it. Keeps the property and
   costs the clean statement that the lane never constrains arrangement.
3. **Give the middle something else.** It is the ground the jungle used to occupy
   and the place a body can leave; there may be a better property there than width.
4. **Make the terrain real**, which G3's answer explicitly defers — *"a dense
   mixture of plains, forests, mountains"* — and let the middle be open ground while
   the flanks are not. That is the largest of the four by a wide margin.

### A partial answer arrived from building it

**The lane's width now sets how wide a wave marches.** Not how many bodies may
fight at once — nothing sets that — but how many walk abreast down the road, which
is a different question with an obvious answer: a road's width is how many people
fit across it.

That gives the centre back most of what it wanted, by a different route. A wave
marching up the middle arrives with more of itself abreast, so more of it is in
contact the moment contact happens, and a numerical advantage tells sooner. The
difference from the old rule is that it is decided on the way there rather than at
the moment of contact — which suits a design where waves are formed before they
leave the base.

### And then the challenge answered it properly

> during the challenge monster fight, the three waves that are concentrated into the
> central lane should spawn abreast from one another. So, if the width of a wave is
> about 10, then at -12 and +12 from the central wave's center there should be the
> center of the left and right lane - + and - twelve because 5 for the "radius" of
> the circle that is the formation, 5 for the other formation, and 2 for a bit of
> gap between them.

**The centre lane is wide because three formations have to stand abreast in it.**
Which is what every document always said the reason was — "all three lanes' worth of
soldiers funnel into the center during a challenge, and a monster has to be able to
fight a whole team at once" — now with arithmetic behind it instead of an intention.

The width is therefore **derived**, not chosen: the centre formation's radius, plus a
side lane's on either side of it, plus the gaps. At the current file spacing that is
136 paces of formation, and the centre lane is 140.

One thing had to be added to make it work, and it is worth recording because the
problem was not obvious. **A rank stops widening at a fixed number of files.**
Without a cap the sizing is circular in a way that widening cannot fix: the centre is
wide so three formations fit, but a wider lane makes the centre's *own* formation
wider, which pushes the other two further out, which needs a wider lane. Every
attempt to make the corridor contain them made them bigger.

So a road wider than the cap is simply **room** — which is the right relationship
anyway. A road twice as wide does not make an army twice as broad; it makes it
comfortable.

Option 4 — real terrain — remains untouched and is explicitly deferred by G3's
answer.

**Changed:** [002](002-the-map-and-its-milestones.md), the map shape parameters, and
issue 206.

## G9. What happens to a boon nobody chose? — **ANSWERED**

The only fallback in the prototype, and it is announced rather than silent: a boon
still unchosen when the calm runs out is **taken for the player**, first of the two
offered, with an event saying so.

It exists because the alternative is worse. An unmade choice would sit in the offer
table forever and quietly deny that team a modifier the other team has — a team
punished, permanently, for one player looking away for thirty seconds.

But taking it for them breaks a rule this project otherwise keeps absolutely:
**nothing decides for a player.** Every refusal is named and handed back, no spawn is
ever redirected, and no upgrade is ever moved except by somebody's own hand. This is
the one place that is not true.

Three ways out:

1. **Keep it, and make the automatic pick visible and undoable** — the boon is taken,
   the player is told, and they may swap it for the other one until the next surge.
   Cheapest, and it turns a decision made for you into a default you can reject.
2. **Hold the calm open** until everybody has picked. Honest, and it hands one
   inattentive player a lever over five other people's match, which is a worse
   failure than the one it fixes.
3. **Let it lapse.** No boon, and the team is down one. Consistent with the rest of
   the design — you were offered, you did not take it — and brutal in a game where
   the offer arrives during the one phase with nothing else happening.

The bot takes the first offered too, and that is a different decision for a different
reason: whichever it preferred would become an invisible constant in every number a
balance run produced.

## G7. Issue 101 describes four junctions — **ANSWERED**

The issue that builds the path graph says the side lanes "bend once near each
base — four bends in total, and those bends are the junctions," and that the
centre lane "has no junctions."

[The map](002-the-map-and-its-milestones.md) says the opposite, at length, and
explains why: three junctions, one per lane, on the field's other diagonal, and
giving the centre a junction of its own is what makes the middle a place a body
can leave. The builder follows the document.

The issue is simply stale — it predates the change and nobody went back.

**Answer: the issue was wrong and has been corrected**, along with the note that its
bends are now rounded rather than sharp.

Listing it here as a question was itself the mistake. Issue files are the blueprint
this project is meant to be rebuildable from, which is exactly why a blueprint that
contradicts the building gets fixed rather than catalogued. **An issue is not closed
while the pages around it still read false.**

**Changed:** issue 101.

## H1. "Positions and health" — but a position here is not an x and a y — **NEEDS A DECISION**

Found while building the replay log, which records the same thing the network's
accepted sync records and therefore ran into the same wall first.

[Players, teams, and commands](016-players-teams-and-commands.md) says the
cross-team sync carries "positions and health of bodies, projectiles, and
structures," and reasons carefully about why that is close to the minimum that
still works. What it does not say is **which numbers a position is**, and in this
simulation that turns out not to be a detail.

A body walking a lane is stored as *how far along the lane* and *how far across
it*. Its x and y are derived from those on every move pass, by asking the lane's
path where that point is. Writing an x and a y onto a body accomplishes exactly
nothing: the next move pass recomputes them a fraction of a second later and the
correction is gone, while every counter in the system reports that it was applied.

That is not a hypothetical. It is what the first version of the replay's
correction did, and the only reason it was caught is that a test measured whether
the correction had any effect rather than whether the code had run.

So the sync's payload has to be the authoritative set:

| Field | What it is |
| --- | --- |
| `lane` | which of the three, or 0 for a body that is not in one |
| `lane_along` | distance from the lane's start, in world units |
| `lane_across` | offset from the lane's centre line, signed |
| `path_index` | which segment of the lane's path it is standing on |
| `node_from`, `node_to` | the edge a body **not** on a lane is walking |
| `progress` | how far into that edge, from 0 to 1 |
| `health` | as before |

**The question is whether `lane` belongs in that list, and the answer is probably
no.** Which lane a body is walking is not continuous state that drifts — it is a
*decision*, taken once at a junction, and the document is emphatic that decisions
are broadcast immediately and never rolled back. Two machines that disagree about
which lane a body is in have not drifted apart; they have taken different turns.
Writing the sender's lane number onto the receiver's body does not reconcile that.
It produces a body standing in a lane it never entered, holding a path index into
a path it is not on — which crashes the walk, which is how this was found.

**Answering this needs a decision about what the sync is for.** Two readings:

1. **The sync repairs arithmetic and nothing else.** A structural disagreement is
   left standing and counted, and the count is the honest measure of how far apart
   two machines have got. This is what the replay does today, because it is the
   only one of the two that is certainly correct.
2. **The sync repairs everything the authority can see.** Lane membership is sent,
   and receiving a lane change means rebuilding the body's path state from scratch
   rather than assigning a number to it. More faithful and considerably more code,
   and it makes the receiver's simulation subordinate rather than corrected.

## H2. A machine that killed the wrong body can never be corrected — **ANSWERED**

The same experiment, and the more serious of the two.

The sync carries health, and [players, teams, and commands](016-players-teams-and-commands.md)
already says the right thing about applying it: writing a health value must not
raise a death directly — the ordinary resolve pass notices the zero on the next
tick and everything downstream follows the normal path. That handles one
direction. A body that is alive here and dead there receives zero health and dies
properly.

**The other direction has no mechanism at all.** A body that died here and is
alive there cannot be brought back. Its slot was freed and recycled, its
generation counter has moved on, and everything that referred to it has been told
it is gone. The accepted sync arrives describing a body this machine no longer
has, and there is nothing to write the numbers onto.

This matters more than it sounds, because deaths are the hinge the whole design
hangs from: health determines deaths, deaths determine wave wipes, wave wipes
determine draws, draws determine the chest. A machine that killed one soldier the
authority did not is a machine that may be one wipe out for the rest of the match,
and no amount of position correction closes that.

How far apart it can get is measurable, and the number is unpleasant. Take a
recorded match, perturb every living body by a tenth of a world unit — well below
anything a player could see — and play it back:

- **left alone**, the two runs end up around 580 world units apart at worst, with
  about ten thousand body-observations across the match that could not be
  reconciled at all
- **corrected at every keyframe**, around 200 units and six thousand

Correcting plainly helps, and just as plainly does not converge. The residue is
almost entirely bodies that exist in one run and not the other. Run the same
measurement yourself with the divergence check in the invariants suite, which
prints both numbers.

Three ways out, in the order they look promising:

1. **Sync existence as well as health.** The authority's message says which slots
   hold living bodies; a receiver missing one respawns it from the description and
   a receiver holding an extra one removes it. This is the honest fix and it makes
   the message meaningfully larger.
2. **Make deaths a choice rather than an outcome.** Deaths are broadcast the way
   commands are — immediately, never rolled back — and the local resolve pass only
   proposes them. Keeps the sync small; makes every death a network round trip in
   a game with thousands of them.
3. **Accept it and bound it.** Measure the divergence continuously with the hash
   the replay already computes, and when two machines are further apart than some
   threshold, resynchronise the whole world rather than a keyframe. Cheapest, and
   it turns a permanent slow error into a periodic visible hitch.

**Answer: a death decays before it is final.** None of the three above, and a fourth
that is better than all of them.

A body that reaches zero health leaves the field immediately — it stops fighting,
stops being a target, stops holding a place in the queue, stops counting toward push
depth — and then **holds its slot, and every one of its numbers, for two seconds**
before anything about the death is made final. Nobody is paid, no wave counter moves,
no guard is replaced, no challenge ends. Two seconds is two reconciliation cycles,
which is long enough for every machine to have had its say, and undoing the death is
then a matter of clearing one number.

Why this beats the three that were offered: it does not enlarge the message
(option 1), it does not turn thousands of deaths into network events (option 2), and
it converges rather than accepting a permanent drift (option 3). What it costs is
that **every consequence of a death lands two seconds late** — uniformly, for all of
them, so it is a delay rather than a distortion.

The alternative of paying immediately and undoing it if the death is reverted was
rejected, and the reason is worth keeping: a payment can be unmade only if it has not
been spent, and a chest draw that has already been placed cannot be unmade at all.
**A consequence that has been acted on is not revertible**, so the only honest place
for the boundary is before the consequence rather than after it.

It is also simply the better thing to look at. A body that fades rather than blinking
out is the least artificial version of the moment, and the fade is real data rather
than an animation the renderer invented.

**Built:** issue 210. **Changed:** the world record, the reap pass, the snapshot, the
renderer, and [the simulation tick](003-the-simulation-tick.md).

H1 is still open, and it is the smaller one.

## H3. A pool of coroutines is not parallel — **ANSWERED**

[The thread pool slices the tick](../issues/209-the-thread-pool-slices-the-tick.md)
asks for "a pool of coroutines over shared memory," and
[the shape of the code](018-the-shape-of-the-code.md) repeats it. The sentiment is
right and the mechanism does not do what the sentiment wants.

**Coroutines in Lua all run on one operating-system thread.** They hand control to
each other; they never hold it at the same time. A pool of them over a tick that is
thousands of soldiers doing arithmetic is a more complicated way to take exactly as
long, and on a machine with sixteen idle cores it will use one of them.

Coroutines are the right tool when the work is waiting — a file, a socket, a reply
from another machine. None of the tick is waiting. All of it is arithmetic.

Real parallelism in this environment means separate Lua states, which cannot share a
table, so the world would have to stop being tables of numbers and become memory
allocated through the FFI, addressed by pointer, with the flat-array layout it
already has. That layout is the half of the job already done and done for exactly
this reason — the argument for a struct of arrays was always that slicing one is a
pair of integer bounds. What is not done is that every file which reads a body reads
it out of a Lua table today.

Now measurable, which changes the question: `./run-prototype headless` prints a
census of how crowded the field gets. It is **hundreds of bodies, not thousands**,
and very uneven — an ordinary phase is a fraction of a challenge. A pool has to earn
its place at the ordinary figure, because that is where a match spends most of its
time.

Three ways, in the order they look promising:

1. **Do the slicing, execute it serially, and be honest about it.** Cutting each
   pass into independent slices is most of the work and most of the value: it forces
   the question of what each pass is allowed to touch, and answering it is how the
   attack pass turned out to be safe only because damage is buffered. A pool whose
   size is a number and whose speed is the same at every size is a scaffold with a
   truthful label. Swapping the executor later is contained.
2. **Move the world into FFI memory and use real threads.** The design this project
   has been describing all along, and a change that touches every file that reads a
   body. Worth doing if the body count ever justifies it; the census says it does
   not yet.
3. **Close the issue with the measurement as the reason.** A pool that costs more
   than it saves is a pool that should not exist, and the issue itself says so in
   its fifth step.

**Answer: the prototype is single-threaded, and it says so.** The coroutine pool is
the shape of the idea rather than a working parallelism, and every document that
implied otherwise has been corrected — that sentence was in three places and was not
true in any of them.

When it needs to scale, **the parts that matter move to a C core**, which is where
real parallelism lives anyway: separate execution over memory addressed by pointer,
which is what the flat-array layout was always for. That is a later expansion and not
a rewrite of the prototype.

Nothing is being built for issue 209 now. The census makes the case for waiting: the
field holds hundreds of bodies and a match already runs at many times real time on
one core.

**Changed:** issue 209, [the simulation tick](003-the-simulation-tick.md), and the
phase-2 progress file.

## H4. Do milestones stay nine, or become thirty-three? — **NEEDS A DECISION**

Raised by the request in [issue 211](../issues/211-waypoints-and-the-zones-they-sit-in.md)
to make the measure of how far along a lane a wave is "about four times more
discrete."

A lane currently has **nine milestones**, at fixed fractions of its length, and they
do two jobs at once: they are where the towers stand, and they are the unit push
depth is counted in. Push depth is the number the whole game runs on.

Four times finer means thirty-two intervals instead of eight. Two ways to get there.

1. **Milestones stay; zones are added underneath.** Each milestone interval is
   divided into four, so every milestone is still exactly on a zone boundary, no
   tower moves, and nothing that says "milestone" changes meaning. Push depth moves
   from counting milestones to counting zones. Two concepts where there was one, and
   somebody will eventually ask which of them a given number is in.
2. **Milestones themselves become thirty-three**, with the towers at every fourth
   one. One concept, no ambiguity, and exactly the same geometry — but every piece of
   code that says "milestone" now means something four times finer: the structure
   sites, the sign-posts, the chest's slot addressing, the renderer's marks along
   each lane, the terminal viewer, the bot. Each of those is a small change and
   there are a lot of them, and any one missed is an off-by-four in a number nobody
   prints.

The safer of the two is the first, and safety is worth something here specifically
because push depth is read in so many places that a silent factor of four would be
found by a player rather than by a test.

## H5. Does a waypoint steer the formation, or replace the lane? — **NEEDS A DECISION**

The other half of [issue 211](../issues/211-waypoints-and-the-zones-they-sit-in.md).

A wave is to approach a **waypoint** — a point at a random position inside the next
zone — rather than simply advancing a number, so that its approach angle varies a
little and two waves walking the same lane do not lay their feet in the same places.
"It's hard to tell exactly which direction is optimal while on the ground, so you
just sorta go toward that direction."

The question is what "approach" means against the way movement is built.

A formation is held in **lane coordinates**: how far along the lane, and how far
across it. World position is derived from those against the lane's own curve. That
is not an implementation detail, it is the reason a rank survives a corner — every
body in a rank shares one distance-along, so the road carries the line round the
bend as a line. Hold a formation in world coordinates instead and it either tears
apart on a turn or scythes through the inside of it.

1. **The waypoint steers within the lane.** The wave still advances along the lane at
   its pace; the waypoint sets *how far across* the formation is heading, and the
   formation eases toward it. The approach angle varies, the wander is real, and the
   lane still carries the shape round every corner for free. The waypoint's
   along-position then does little except decide when to pick the next one.
2. **The waypoint is a destination in the world.** The wave genuinely navigates to a
   point, and its progress along the lane becomes a consequence of walking there.
   Faithful to the description, and it means lane coordinates stop being what a
   formation is held in — which is the load-bearing property the formation work has
   been built on and measured against from the beginning.

The first delivers the visible effect asked for and costs nothing. The second is a
rewrite of the movement model, and would need the corner behaviour re-solved from
scratch by some other means.
