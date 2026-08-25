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

## A11b-iii. Does this make the hero snowball worse? — **NEW**

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

## A16c. Does the rising ceiling make rerolling cheaper over time? — **NEW**

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
## C3. Is the surge the only comeback mechanism?

Under the current rules, a losing team gets exactly two things: the surge
resetting the board, and the boon. **Everything else compounds toward the
winner**, and there are now two snowballs rather than one:

- **The chest.** A1 was answered as "the killing team draws," so winning a lane
  means drawing more upgrades and winning it harder. The surge brakes this one,
  by destroying the arrangement rather than the upgrades.
- **The wallet.** A2 was answered as "every kill your team lands pays every
  player on your team," so a team that is winning lanes is killing more and
  fielding more heroes. **Nothing brakes this one at all.** The surge empties the
  chest; it does not touch anybody's wallet.

That second snowball is new — it did not exist under the working ruling, where
only a player's own heroes earned. It may be fine: heroes die permanently, so a
hero advantage does not persist the way a placement does. It may also mean the
hero economy wants a floor, a catch-up term, or a cheap hero priced specifically
against what a losing team's income looks like. Issue 804 is where it gets
measured, and it should be one of the first things that run.
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

## C4b. How many is "a handful"? — **NEW**

Four or five to start, but issue 509's roster design has to hold across all of
them: a second commander should **reshuffle the jobs** rather than reskin them,
and doing that badly gives every commander the same five heroes with different
names.

There is also an interaction with no-duplicates that is easy to miss. With a
handful of commanders and three per team, the number of possible team
compositions is small, and **players will explore all of them quickly.** A
five-commander roster gives ten distinct team compositions. That is a week, not a
year.
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
   A health gain with nothing capable of healing in range is the same.
4. Reject what fails, keep the local value, log it.

**A causality check, not a tolerance** — and that distinction is the whole reason
it is worth building. A magnitude tolerance asks *is this change big?*, which is a
tuning question that always gets the edge cases wrong. This asks **could anything
have done this?**, which is a question the simulation already knows the answer to,
because knowing what is in range of what is the retarget pass's whole job. The
defence costs one function that reuses machinery that already exists.

It also lands exactly on the cheat. Publishing yourself healthier requires
something in range able to heal you, and nothing in this game heals. Publishing
the enemy weaker requires attackers in range you do not have.

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

## E7. How good does the bot need to be?

Issue 803's bot exists to generate balance data, and "good enough to produce
meaningful numbers" is a much smaller job than "good enough to be worth beating."

If the game ever ships single-player, the second is the requirement, and it
probably deserves its own phase rather than a corner of phase 8. Worth deciding
before the committed-strategy bot is written, because a bot built to be a
measuring instrument and a bot built to be an opponent are not the same program.

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

## F20. Which lane is the wide centre when there is no middle one? — **OPEN**

Created by F10, which made the lane count follow the team size.

A three-lane map has an obvious centre: the diagonal, the wide one, the one every
challenge funnels into, the one the connectors reach. A **four-lane** map has two
middle lanes and a **two-lane** map has none, and three separate systems ask for
a centre by name:

- **The challenge.** Every lane's production funnels into "the centre" and both
  monsters walk down it. With two candidates it is unclear which; with none it is
  unclear whether a challenge is possible at all.
- **The width rule.** The centre is topographically wider so that a monster can
  fight a whole team at once rather than a queue. That is the only real
  difference between the three lanes and it wants somewhere to live.
- **The connectors.** Each side lane's junction reaches the centre, which is what
  lets a hero change lanes at all. With no centre there is nothing to reach, and
  the sign-posts have nothing to point at except along.

Three shapes, none obviously right:

1. **An odd lane count only.** 3v3 and 5v5 work, 2v2 and 4v4 are not supported.
   Cheapest, and it makes the prototype's number a rule rather than a default.
2. **A dedicated centre that is not a lane.** The wide corridor exists on every
   map, nothing spawns into it during normal play, and challenges use it. Costs a
   piece of map that is idle most of the match.
3. **Nominate one.** On an even map the builder picks a lane to be the wide one,
   which makes the map asymmetric in a design that has removed every other
   asymmetry that is not a decision. Probably wrong for that reason alone.

Nothing is blocked by this: 3v3 is what gets built. It is written down so that
the map builder is not quietly designed around an assumption it will have to
break later.


## F21. What does a slot actually deliver, and to whom? — **ANSWERED**

**Answer: nothing is ever consumed, and the tower slot feeds two different kinds
of recipient with different halves of the same upgrade.**

### Nothing is consumed, in either slot

An upgrade placed at a lane is **affixed there**. It stays. It is stamped onto
every wave unit that lane spawns from then on, and stamping does not use it up —
the same upgrade stamps the next wave, and the one after, for as long as it sits
there. An upgrade slotted into a lane's towers is the same: it applies
continuously, to everything that reads through those towers, and moving it away
is the only thing that ever stops it.

This was never in doubt, but it was also never written in one place, and the
surge's deal made it worth saying out loud: **an upgrade is a standing property of
a slot, not a resource that gets spent into bodies.**

### The tower slot has two audiences, and they are shaped differently

A lane's towers are two things at once:

- **The guard units, which are melee.** They walk, they close, they swing.
- **The guard tower itself, which is ranged.** It stands still and shoots.

So an upgrade slotted there does not simply "apply to the towers." It applies
according to what it *is*:

| The upgrade is | The guards get it | The tower gets it |
| --- | --- | --- |
| a **melee** upgrade | **yes** | no |
| a **ranged** upgrade | no | **yes** |
| **common** — health, armour, and the like | **yes** | **yes** |

That is why the phrasing is "and *possibly* the tower itself." A melee damage
upgrade in a lane's towers is not wasted and is not refused; it buys a harder
patrol and does nothing for the arrows.

### What this breaks, and it needs correcting

[upgrades slotted into stone](010-upgrades-slotted-into-stone.md) currently says
**"Speed and health upgrades on an immobile building are meaningless"**, and uses
that to justify refusing them at the tower slot. That reasoning is dead. The slot
feeds bodies that walk, so a movement-speed upgrade slotted into a lane's towers
makes its guards patrol faster and answer a breach sooner, which is a real
purchase.

The refusal test has to change with it: **a placement into the tower slot is
refused only when the upgrade helps neither the guards nor the tower.** Which,
given that guards are ordinary soldiers, is a much smaller set than the old rule
assumed — possibly empty.

### What it opens

**Does the same affinity split apply at the lane slot?** Wave units have a
`range` and melee is described as "a small nonzero number, not a special case,"
which leaves room for ranged wave units to exist as a different archetype. If
they do, a ranged upgrade affixed to a lane full of melee soldiers is doing
nothing, and the lane slot needs the same three-way table. If every wave unit is
melee, the question does not arise. Recorded as **F22**.

**Changed:** [009](009-the-shared-upgrade-pool.md)'s catalogue record, [010](010-upgrades-slotted-into-stone.md) (the "meaningless on a building" argument, which is wrong), [007](007-guard-towers-and-their-guards.md), issues 401, 408, 303.

## F22. Are there ranged wave units, and does the lane slot need an affinity? — **OPEN**

Created by F21.

The tower slot now delivers melee upgrades to guards and ranged upgrades to the
tower, because those two recipients are shaped differently. The lane slot
delivers to wave units, and nothing has yet said whether wave units are all one
shape.

- **If every wave unit is melee**, the lane slot needs no affinity test at all,
  and "melee versus ranged" is a rule about the tower slot only.
- **If a lane can spawn ranged wave units** — an archer archetype alongside a
  swordsman — then a lane's upgrades need the same three-way table, and placing a
  ranged upgrade into a lane of melee bodies becomes a real mistake a player can
  make.

The second is the more interesting game and the more expensive one. It gives a
lane an internal composition to think about, which is a second axis under the
chest; it also means the frontline queue has to handle bodies that stop at
different distances, and issue 206's ranks-behind-the-front logic assumes they do
not.

Nothing is blocked. The catalogue is not written yet and the affinity field can
be added to it whichever way this goes.

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

## F25. What does the Golem do to what it walks into? — **OPEN**

The shape is settled and the specifics are not.

**Settled:** it kills melee and ranged bodies differently. Anything that closed to
swinging distance is **grabbed and crushed**. Anything standing off is answered
**at range** — something thrown, or something worse. The point of the split is
that there is no distance at which a team farms it safely: close is lethal and
back is not safe either, which is what makes sustaining the damage check hard,
because the bodies doing the damage keep dying.

**Not settled:** what the ranged answer actually is. Thrown debris, a beam, a
shockwave along the lane. This is one of the few places in the design where the
answer is aesthetic before it is mechanical, and it is the last thing anybody
sees before a match ends, so it is worth more than a shrug.

Whatever it is, it wants to obey the existing rules: an entry in the ability
dispatch table, firing on a condition, writing into the same pending-damage
buffer as an ordinary swing.

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

That is the whole list. **This stops being a design and starts being a program at
issue 101.**
