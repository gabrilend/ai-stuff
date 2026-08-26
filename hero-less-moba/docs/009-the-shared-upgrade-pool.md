# 009 — The Shared Upgrade Pool

**Datapath document.** Covers the chest: what an upgrade is, how one is drawn,
where it can be put, and the lock-and-objection negotiation that keeps three players
from undoing each other's work.

This is the centre of the game. Everything else feeds it or is fed by it.

## An upgrade is an instance of a kind

Two records, and keeping them apart matters.

### upgrade kind — the catalogue, fixed at build time

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Row in the catalogue. |
| `name` | string | Shown to players. |
| `weight` | integer | Relative likelihood of being drawn. |
| `index` | integer | Which slot this kind occupies in a body's upgrade count vector. |
| `add` | double[] | Flat additions, one per modifiable stat. |
| `mul` | double[] | Multipliers, one per modifiable stat. |
| `behaviour` | integer | Index into a behaviour dispatch table, or **0** for a pure stat change. |

The modifiable stats are the soldier fields worth touching: damage, armour,
health, range, speed, attack cooldown. Behaviours are for anything that is not a
number — a splash on hit, a death rattle, a shield on the front rank. They are
dispatch-table entries so that adding one is adding a row, not editing the combat
loop.

### There is one kind of upgrade, and no field says who it is for

**Nothing in that record tags an audience**, and that is deliberate. *Settled;
see [open questions](020-open-questions.md), F28.* An upgrade modifies stats, and
**a body benefits to the extent that it has those stats and uses them.** No
routing, no categories, no refusals.

There are three things upgrades affect — **wave units, guards, and towers** — and
one catalogue works for all of them because they overlap almost completely:

| | Has feet | Has a blade | Throws bone | Has health |
| --- | --- | --- | --- | --- |
| **melee wave unit** | yes | yes | no | yes |
| **ranged wave unit** | yes | no | yes | yes |
| **guard** | yes | yes | no | yes |
| **tower** | **no — it is stone** | no | yes | yes |

A guard and a tower are **opposites with everything in common.** One has feet,
the other has stone. One has a blade, the other throws bone. Every property
either of them has, something else in the list has too — **every effect is shared
at least once**, which is precisely what makes one catalogue possible instead of
three.

So a health upgrade helps all four with no rule saying so. A movement upgrade
helps three and does nothing for a tower, because a tower's speed is zero and
always was. A ranged-damage upgrade helps the ranged bodies and the tower.

**An earlier draft carried two fields for this** — `applies_to`, saying which
slots a kind could enter, and `shape`, sorting kinds into melee, ranged, and
common. Both are gone. A tag is a second description of a thing that already
describes itself, and the two descriptions can disagree — which they would, the
first time somebody wrote an upgrade adding both movement speed and ranged damage
and had to pick a category for it.

**Nothing is refused on the grounds of what an upgrade is.** Any upgrade may be
placed in any slot. What it does there is however much of it applies.

### Upgrades never touch hero units

**A lane's upgrades apply to wave units and to nothing else.** A hero unit walking
through a lane stacked with every upgrade the team owns fights at exactly its
catalogue values. *Settled; see [open questions](020-open-questions.md), A14.*

There is no per-kind exception and no way to write one — heroes are excluded by
**flavour**, in the routine that stamps a body, not by anything in the catalogue.
That is the only audience rule left in the game, and it is a rule about the shape
of the game rather than a balance figure, which is why it lives in one place
rather than in a field somebody has to set correctly on every row.

The reason is that the two economies must not multiply. The chest is filled by
killing and spent on **placements**; personal resource is filled by killing and
spent on **bodies**. If a lane's upgrades also pumped the heroes standing in it,
a team could stack every upgrade into one lane, buy every hero into that same
lane, and get a compounding payoff for a decision it only had to make once. The
game would collapse into whichever lane the team picked, and the other two would
be a formality — which is the same collapse the surge's even dealing of upgrades
across all three lanes exists to prevent, arriving through a different door.

The price of the rule is legibility: a hero fighting alongside enormously
upgraded wave units looks strangely unaffected by whatever is making them
enormous, and there is no obvious way to draw "this body is exempt." That is
accepted. It is the smaller problem.

Note what this leaves: the only way a player's spending and their team's chest
interact is **indirectly, through play.** A hero that turns a stalled enemy queue
into a wipe has just bought its team an upgrade draw. That is the only exchange
rate between the two economies, it runs one way, and it has to be earned.

### upgrade instance — a specific thing sitting in a specific place

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Index in the team's instance array. |
| `kind` | integer | Row in the catalogue above. |
| `team` | integer | 1 or 2. An instance never changes teams. |
| `slot_kind` | integer | **0** unplaced (in the chest), 1 lane, 2 lane towers, 3 library. |
| `slot_lane` | integer | 1–3 when `slot_kind` is 1 or 2; **0** otherwise. |
| `held_by` | integer | The player who owns this stone, or **0** if it has been contributed to the communal pool. |
| `dismissed_mask` | integer | Bit set of players who have marked this *not my problem*. When every player is set, it clears and the stone is visible to all of them again. Communal stones only. |
| `placed_tick` | integer | When it last arrived somewhere. Drives the UI's recency sort. |
| `is_boon` | integer | 1 if this is a boon. No slot, never dealt out by a surge. |
| `owner` | integer | Player number 1–6, **boons only**. **0** on everything else, which belongs to the team. |
| `moving_to_kind` | integer | Destination slot kind while in transit, or **0**. |
| `moving_to_lane` | integer | Destination lane while in transit, or **0**. |
| `arrives_wave` | integer | The wave id a transit lands with. **0** if not in transit. |

The important thing about this split: **there is no such thing as "the team's
Sharpened Blades upgrade."** A team can hold three instances of the same kind and
put them in three different lanes, or pile all three into one. **Duplicates
stack.** The catalogue is fixed; the instance array grows all match.

### Which is why a body carries counts, not a bit set

**What a soldier carries is an array of small integers — one slot per catalogue
kind, holding how many copies of that kind it has.** *Settled; see
[open questions](020-open-questions.md), F3.*

This is worth stating where the stacking rule is stated, because an earlier draft
had a body carry a **bit set**: one integer, one bit per kind. A bit set cannot
count. Two copies of a kind and one copy of that kind produce exactly the same
integer, so the stacking rule above had no way to take effect and nobody noticed
for the length of a whole design.

Two consequences fall out of the change and both are improvements.

**The catalogue is no longer capped at the width of an integer.** LuaJIT's bit
library is thirty-two wide, so a bit set silently limited the entire game to
thirty-two upgrade kinds — boons included — and that number was written down
nowhere. With a count vector the limit is memory, and the catalogue's size is
free to be chosen on its merits.

**Applying upgrades is a walk with a multiply in it.** The old arithmetic walked
set bits; the new one walks the vector and multiplies each modifier by its count.
Slightly more work per swing, and it is still a flat pass over a small fixed-size
array with no pointer chasing, which is the cheap kind.

One thing it does **not** settle, and it belongs with the catalogue rather than
here: **how a duplicate composes.** Two copies of a flat addition presumably add
twice. Two copies of a multiplier could multiply twice or add the excess once,
and those are very different curves at four copies. That is one rule for every
kind in the catalogue, not a per-kind field.

## Drawing: one deck, both teams, same order

**There is one deck for the whole match, and both teams draw from it in the same
order.** Team 1's fifth draw and team 2's fifth draw are the same kind. *Settled;
see [open questions](020-open-questions.md), A11 and A11b.*

The deck is a sequence of kinds, generated once at match start from the
catalogue's weights using the `deck` stream, long enough that no match reaches
the end of it. Each team holds an **index** into that sequence, not a stream of
its own.

A draw is: read the kind at your index, append an instance with `slot_kind = 0`,
advance your index by one, raise an event.

Draws happen on two events — a wave wiped (one) and a tower felled (three). Boons
come from somewhere else entirely; see
[boons and the challenge](015-boons-and-the-challenge.md).

### Why one shared sequence

**It removes the last source of asymmetry that is not a decision.**

The map is exactly symmetric. The spawn intervals are identical. The surge is on
a clock both teams can see. And now the upgrades are the same upgrades in the
same order. If a team is ahead, it is ahead because of **placements** — because
they crafted a better strategy out of the same material — and there is no run
where somebody simply drew better.

It also makes the enemy's chest legible without any interface for it. A team that
is four draws behind is holding **your own chest from two minutes ago.** You know
exactly what they have, because you had it. What you do not know is where they
put it, and that is the only thing worth not knowing.

A team that is killing more reaches its fifth draw sooner. **The leader is ahead
on the same track**, not holding different cards — which is a race, and a race is
legible in a way a lottery is not.

The cost, and it is real: the roguelike texture of *this run went strangely*
disappears. Two evenly matched teams get identical resources with no variance to
break a stalemate. Whether that is a loss worth caring about is what issue 804 is
for.

### Rerolling

**A player may spend personal resource to send one of their team's upgrades to
the bottom of the deck and immediately draw the next card.**

This is the only exchange between the two economies in the entire game, and it
runs one way. It does not buy an upgrade — your instance count is unchanged. It
does not buy a *better* upgrade — you get whatever the deck says is next. What it
buys is **deviation from the shared sequence.**

Every reroll is a hero that never existed. A player who rerolls freely has a
well-shaped chest and nothing to put on the ground with it.

Mechanically: the rerolled instance's kind is appended to that team's own tail of
the deck, the instance is destroyed, the team's index advances by one, and a new
instance of the kind now at the index is appended. **The other team's deck is
untouched** — which means the two sequences agree until somebody pays to break
them, and from then on the divergence is exactly the record of who paid what.


**You do not see the next card before you pay.** *Settled; see
[open questions](020-open-questions.md), A11b-i.* You know exactly what you are
discarding and nothing about what you are getting, so a reroll is a **gamble**
rather than a calculation — the one place in a design that has systematically
removed luck where luck is put back on purpose.

The reason is that a visible next card would turn "should I reroll this" into
"should I reroll this *now*", and a player would sit reading the deck, waiting
for it to line up. The deck is meant to be received, not farmed.

**A reroll costs a flat price, roughly that of the cheapest hero on a roster.**
*Settled; see [open questions](020-open-questions.md), A11b-ii.* One reroll equals
one small body, which states the tradeoff in the most direct terms available and
needs no explaining at all. Defining it against a catalogue entry rather than as
a loose number also means it tracks hero pricing automatically.

One interaction to watch: the resource ceiling **grows** as a match goes on, and
a flat reroll cost does not. So rerolling gets cheaper in real terms the longer a
match runs, and late chests end up better shaped than early ones. That is
probably right — with a shared deck, late rerolling is the main way two teams
holding the same cards end up holding different ones — but it is a curve nobody
chose deliberately and issue 804 should be watching it.
Full mechanics in issue 411.

Draws are never automatically placed. An upgrade in the chest is doing nothing
for anybody, which is the pressure that makes a team look at the chest.

## During a siege-surge, arrangement stops mattering — but you can still arrange

Two rules, and they are easier to hold together than they look.

**Nothing is taken away, moved, or emptied.** *Settled; see
[open questions](020-open-questions.md), F11.* Whatever is slotted into the top
lane is still slotted into the top lane for the whole surge. The chest is not
dumped. Placements are not disturbed. **Upgrades in this game are never moved
except by a player's own hand**, and a surge is not an exception to that — it is
the reason the rule is worth stating.

**Instead, the surge reads everything the team owns as one flat list** and deals
it out to the bodies coming off the spawn points. Every half a second or so, one
body appears at each lane's start point; the deal picks a random one of them to
begin with, takes a random upgrade from the team's whole holding, assigns it to
that body, moves to the next body in rotation, and keeps going until every
upgrade the team owns has been assigned. Then it happens again at the next spawn,
from scratch, starting somewhere else.

The upgrades are **assigned, not removed.** A placed upgrade and an unplaced one
are equally on the field during a surge, because the deal does not look at slots
at all.

So the stream is not a column of identical soldiers. It is your entire chest
walking down three lanes at once, split three ways, in a different arrangement
every half second. It does not make you weaker — nothing is held back, and every
upgrade you own is on the field at every instant. **It makes you incoherent.**
The three upgrades that worked together in your top lane are all still out there,
just never on the same body twice running. What the surge suspends is not
strength; it is *arrangement*, which is the only thing in this game you actually
built.

It is self-balancing in a way a flat penalty is not: a team with twelve upgrades
has a great deal disturbed by being dealt three ways, and a team with three has
almost nothing. **The surge disrupts in proportion to how much there was to
disrupt** — the right shape for the design's only brake on a snowball.

### And placement stays open the whole time

**Players may place, move, withdraw, lock, and object freely during a surge.**
*Settled; see [open questions](020-open-questions.md), F12.*

There is no reason to forbid it. Rearranging during a surge changes nothing about
the surge, because the deal ignores where things sit — so a refusal would be a
rule with no purpose that also left players with nothing to do for a minute at a
time.

What it does change is **what comes next.** A surge is followed immediately by a
challenge, and a challenge is one enormous body where a wave is many small ones.
The build that was right for grinding a frontline is usually wrong for a monster.
So the surge becomes the window in which a team retools for the thing walking out
of the middle, while the fighting carries on without waiting for them to finish
thinking.

The same freedom holds during the calm.

Boons sit outside all of this. They have no slot, they are not dealt, and they
are on every body the team fields in every phase — heroes included. See
[boons and the challenge](015-boons-and-the-challenge.md).

## Placing, and the wave it takes to move

A placement command names an instance and a destination slot. It is applied in
the command pass at the top of a tick, and it is refused — with a reason the
viewer can show — if any of these hold:

- The instance is locked by a different player.
- The instance is already in transit — cancel it first.
- The destination is where it already is.
- The instance is in the freeze window before a queued destination takes effect;
  see [players, teams, and commands](016-players-teams-and-commands.md).

A siege-surge is **not** on this list. Placement stays open in every phase; see
above.

### Moving takes one full wave

**An upgrade does not arrive the instant you place it. It is marked to move, and
it takes one full wave to get there.** *Settled; see
[open questions](020-open-questions.md), D3.*

While it is in transit it keeps applying at its **old** slot, and the wave that
spawns during that transit is stamped accordingly. The wave after that is the
first one born with it in its new home. So a placement lands **two waves after
the command**, with one wave of unchanged behaviour in between.

The transit replaces the reassignment cooldown entirely — there is no second
timer. The cost of moving an upgrade is that it takes a wave to move, which is a
cost a player can see rather than a number they get refused by.

Two things follow, and the second is the more interesting.

**Placement is a bet placed two waves ahead.** A team that can move every upgrade
every tick would simply keep all of them wherever the fighting currently is, and
the whole negotiation layer evaporates. The delay is what makes a placement a
commitment worth locking, objecting, and arguing about.

**Marked-to-move is a message.** Every teammate can see that an instance is in
transit and where it is going, for a full wave, before it lands — and unlike a
lock or an objection, it is **not opt-in.** You cannot move an upgrade quietly.
Your teammates get a wave's notice, which is exactly enough time to say something
about it.

### The eight verbs of the team's conversation

Three people each hold their own stones, and almost everything they say about
them they say by doing something. Everything they can say to each other is in
this table, and it is worth keeping the list short and the meanings distinct.

| | Says | Opt-in? | Costs |
| --- | --- | --- | --- |
| **Contribute** | *anyone can use this now.* | yes | the stone, permanently |
| **Offer** | *you specifically should have this.* | yes | the stone, to one person |
| **Dismiss** | *not my problem.* | yes | nothing; expires when everybody agrees |
| **Cursor** | *I am about to touch this.* | **no** — always on | nothing |
| **Marked-to-move** | *this is going there.* | **no** — automatic | a wave |
| **Ping** | *look at this place.* | yes | rate-limited |
| **Request** | *I would like that one.* | yes | rate-limited; one at a time; expires |
| **Chat** | *anything at all* | yes | rate-limited; team only |

**Two of the eight are involuntary, and those two are the load-bearing ones.** A
player's cursor is synced continuously and a placement announces itself for a
whole wave, which together mean **you can see a teammate reaching for something
before they touch it, and see what they did for a wave after.**

**Three of them move a stone and one asks about one**, which is new — under the
old shared chest nothing could be given, because everything was already
everybody's. Contributing and offering are the same act aimed differently: one
puts a stone where anybody might pick it up, the other puts it in one person's
hands.

**Requesting is the odd one out and the one to be careful with.** It changes
nothing by itself, and it was built for a reason worth remembering: **refusing to
build it does not prevent it.** Players will ask over voice, where the design
cannot rate-limit it, cannot make it ignorable without awkwardness, and cannot
stop it becoming a running commentary on what a teammate is holding.

So it exists, and it is deliberately the weakest verb here. **Giving must stay
easier than asking** — a request names one specific stone, only one can be
outstanding, it expires on its own, and **ignoring one is free and silent.** No
notification that you declined, no record, nothing anybody can bring up later. A
request that can be held against you is a demand, and this game is supposed to be
about building each other up rather than managing each other's pockets.

**One of them is a refusal to act**, and it is the only verb in the game that
works by *subtraction*. Dismissing removes a thing from your attention rather
than adding anything to anybody's, and it is the replacement for the whole
lock-and-objection system — see above for why a disclaim is a better instrument
than a claim.

A ping is the only one of the eight that is not about the stones at all.

**Chat is the newest and the one that changes the others.** An earlier draft of
this document opened this section with *"three people share one chest and mostly
cannot talk about it in words,"* and built a lock system partly on that. Words
exist now — see issue 806 — and they arrived because of a specific hole: **when a
boon is chosen, nothing being decided is on the board yet**, so every other verb
is useless and a team has to coordinate blind.

The distinction that survives the lock system's removal: **chat persuades, the
other six do.** A message asks for something; contributing, offering and
dismissing actually move the board, and they do it in a way a teammate who was
not reading still sees. A team that talks well will hand things around more
deliberately — which is the two working together rather than one replacing the
other.

Whether that survives six people in a room is
[open questions](020-open-questions.md), F26.

### A move can be called back, freely, until it lands

**Cancelling a transit costs nothing and can be done any time before it
arrives.** *Settled; see [open questions](020-open-questions.md), D3b.* The
instance simply stays where it already was.

This is the kind answer to a misclick, and the reason it is safe is that a
transit is not a resource — nothing was spent, nothing was consumed, and the
upgrade has been applying at its old slot the entire time. Refusing a cancel
would be punishing a player for a slip with a full wave of watching their mistake
crawl toward them, for no benefit to anybody.

It does cost something, and the cost is honest: **the marked-to-move message your
teammates were reading can evaporate.** A teammate who saw the mark, decided it
was fine, and moved on will not be told it never happened. So the notice a
transit gives is a *statement of intent*, not a promise — which is exactly what
a lock is for when you want the stronger thing.

**There is no cap on how many upgrades a lane can hold.** The vision says so
outright: "players are allowed to put all their upgrades in one lane. This is
fine." Stacking everything in one lane is a real strategy with a real cost — the
other two lanes are then running on nothing, and the base guards will be meeting
whatever walks out of them.

## What the enemy can see

**They can see your upgrades on your soldiers, and nothing else.**

Because the deck is shared, an opponent already knows roughly *what* you hold —
count their own draws and they are looking at their own chest from a few minutes
ago. What they do not know is your **arrangement**, and the only way to learn it
is to look at the bodies you send at them.

A soldier carries a visible record of what it was stamped with. Read the
frontline and you can read the lane's build.

**So your board is visible, two or three waves late.** A change has to be marked,
transit for a wave, spawn into the next wave, and then walk far enough forward to
be seen. By the time an opponent can read your new arrangement, you have known it
for the better part of a minute.

That delay is the whole information design, and it falls out of rules that exist
for other reasons — stamp-at-birth, the transit wave, and the length of a lane.
Nothing had to be hidden deliberately. **The fog is made of walking.**

## Contributing, and dismissing

**A stone belongs to the player who drew it.** Nobody can take it, nobody can
move what you placed with it, and there is no lock, because there is nothing to
lock it against. *Settled; see [open questions](020-open-questions.md), F29 and
F31.*

Two verbs let a team be a team anyway, and they point in opposite directions.

### Contribute — letting go of one completely

A player may **contribute** any of their stones to a **communal pool**. Once
there, any teammate may place it, move it, and place it again, as often as they
like.

**And it appears to each of them as simply one of the stones they have.** No
owner shown, no *this one is Sam's*, no asking. The point is not to hide who gave
what — it is that **a shared thing you have to remember is shared is not
shared.** Remembering costs a small permanent tax of attention and etiquette, and
that tax is what made a lock system necessary in the first place. Contributing
means letting go completely: *they forget they ever didn't own it, and they just
use it as they please.*

Contributing is one-way. A stone in the pool does not come back to you, because
"whose is it really" is exactly the question the pool exists to delete.

### Dismiss — saying *not my problem*, and the floor that closes

The failure mode of a communal pool is not theft. It is **neglect** — three
people each quietly assuming somebody else has it in hand.

So a player may mark a communal stone **not my problem**, and it vanishes from
their view. Not from the pool; from *theirs*.

> **When every player has dismissed the same stone, it comes back to all of
> them.** The dismissals clear and it is everybody's again.

That single rule is what makes the pool safe, and it is worth reading twice. **A
stone cannot fall through the floor, because the floor closes.** The moment
nobody is looking at it, everybody is. It turns *I assumed you had it* — which is
silent, and permanent, and only discovered when a lane collapses — into something
that resurfaces on its own.

### Why a disclaim beats a claim

**A lock says *I am doing something here***, which is a statement about intent
that a teammate must take on trust and cannot check.

**A dismissal says *I am not doing anything here***, which is a statement about
attention and is simply true at the moment it is made.

Three things follow, and each was a real problem with the old design:

- **It cannot be forgotten.** A lock left on for a whole match held a placement
  hostage, which is why the interface owed a player a running count of what they
  had locked. A dismissal that everybody forgets is a dismissal that expires.
- **Nothing is ever done *to* anybody.** The two-objection rule existed to open a
  lock against its holder's wishes — a whole mechanism, with a timeout to tune,
  for one situation. There is no such situation here.
- **It scales to any team size** with no rule change at all. "Everybody has
  dismissed it" means the same thing at two players as at four, where "two
  objections" never did.

### And the third verb: offer

**A player may offer one of their own stones to a specific teammate**, and it
becomes theirs — to place, to contribute, or to offer on.

It is the only verb in the game that **transfers** anything, and it is the one to
reach for when the communal pool is too vague: contributing puts a stone where
anybody might use it, offering puts it in one person's hands because you think
they specifically should have it.

Offering costs the giver something real and visible, cannot be done by accident,
and cannot be done *to* somebody. It is a strictly kinder verb than a lock ever
was.

## The team's view of its own chest

| Field | Type | Meaning |
| --- | --- | --- |
| `instance` | array of upgrade instances | Everything this team has ever drawn. |
| `lane_count` | integer[lanes][kinds] | Cached count vector per lane — how many copies of each kind sit there. Rebuilt whenever a placement changes; read at spawn. |
| `tower_count` | integer[lanes][kinds] | The same, for upgrades slotted into each lane's towers. |
| `library_count` | integer[kinds] | Upgrades slotted into the library. |
| `base_tower_count` | integer[kinds] | The sum of every `tower_count` row and `library_count`. What the base towers fire with, and what their guards read — see [upgrades slotted into stone](010-upgrades-slotted-into-stone.md). |
| `all_count` | integer[kinds] | Every upgrade the team owns, placed or not. What a siege-surge deals from, and nothing else reads it. |
| `deck_index` | integer | How far this team has drawn into the shared deck. The gap between the two teams' indices is the whole of the economy's asymmetry. |
| `unplaced_count` | integer | How many instances are sitting in the chest doing nothing. Shown large, on purpose. |

These are caches, and the word matters: they are **sums over the instance array**,
rebuilt on placement, which is rare, and read on spawn, which is constant. The
alternative — walking every instance at every spawn — is the same answer computed
hundreds of times more often. A validator should check them against the instance
array at load and after every phase change, because a stale cache here is an
upgrade that silently stops working.

Note that `base_tower_count` sums rather than unions. Under a bit set the base
towers merged three lanes' stone and lost the duplicates; with counts, a team
that slotted the same kind into two different lanes' towers gets both copies in
the base. That is a real change in what the base is worth and it follows directly
from stacking.

Related: [waves](005-waves-and-when-one-is-finished.md) ·
[upgrades slotted into stone](010-upgrades-slotted-into-stone.md) ·
[the siege-surge](014-the-siege-surge.md) ·
[players, teams, and commands](016-players-teams-and-commands.md)
