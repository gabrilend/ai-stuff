# 023 — Ways This Could Go Wrong

Not open questions and not balance values. **Failure modes** — shapes the game
could settle into that would make it worse, which nobody has decided to build and
which no single rule causes.

Each entry says the same four things: **what it looks like**, **why it would
happen**, **what already resists it**, and **what would show it**. The last is the
important one. A pitfall nobody can detect is a worry, and this project has
enough of those.

None of these is a bug. Every one of them is the game working exactly as written,
arriving somewhere nobody wanted.

---

## 1. One lane holds everything

**What it looks like.** A team puts every stone into the centre, buys every hero
into the centre, and pushes through by weight. The other two lanes are a
formality held by towers. A match becomes one fight, decided by who drew better
in the first five minutes.

**Why it would happen.** Concentration beats distribution whenever the payoff is
linear and the cost is not — and several things here lean that way. **The centre
lane is wider**, so more bodies fight at once and a numerical advantage converts
faster. **Challenges funnel everything into the centre** three times a match, so
the centre is where the deciding fights already are. And a stacked lane is simply
easier to think about than three balanced ones, which matters more than any
mechanic when people are busy.

**What already resists it**, and there is more than it first appears:

- **Heroes carry no lane upgrades.** *This is the rule that exists for this
  pitfall specifically* — A14's reasoning is exactly the failure above: *"a team
  could stack every upgrade into one lane, buy every hero into that same lane,
  and get a compounding payoff for a decision it only had to make once."*
  Removing it removes the main defence.
- **Stones belong to individual players.** Three separate holdings resist
  concentration by default; pooling them into one lane is a coordination three
  people have to actively perform, and contributing to the communal pool is the
  step that makes it possible.
- **The surge flattens it three times a match**, dealing everything a team owns
  across every lane at once.
- **A lane has finite towers.** Three per side. Fell them and the lane stops
  paying tower rewards, while six unclaimed towers stand in the lanes you
  ignored. **A won lane is a lane that has stopped earning.**
- **The base guards answer any lane but the base towers do not.** Splitting a push
  across two lanes into the same base is better than doubling one, which is a
  shove away from concentration at exactly the moment it matters most.
- **And it is matching pennies.** A stacked centre against a stacked centre
  cancels; a stacked centre against a stacked top wins one lane and loses one.
  Concentration is only dominant if it is *unilaterally* dominant, and it is not.

**What would show it.** Issue 804, and it needs a specific number rather than a
general watch: **the distribution of a team's stones across lanes, measured
against whether that team won.** If the winners are consistently more
concentrated than the losers, this pitfall is real. If there is no correlation,
it is not — and *"players are allowed to put all their upgrades in one lane, this
is fine"* stays true, as the vision says it should.

Watch two supporting figures beside it: **which lane** the concentration happens
in (if it is always the centre, the width is the cause), and **how early** it
starts (if teams commit in the first three minutes, the problem is that nothing
punishes an early wrong guess).

**What to try, if it is real**, in the order worth trying:

1. **Give the captain a rotating lane.** A captain pays three dice where an
   ordinary body pays one, so the lane carrying this wave's captain is worth
   three times the bounty. Rotate which lane that is, wave by wave. **Ignoring a
   lane then costs income directly** — you are not merely losing ground, you are
   declining to be paid — and it costs it in a way that moves, so no lane is
   permanently the rich one. One body, one rotation, no new rule to explain.
2. **Narrow the centre and widen the challenge.** The centre is wide because a
   monster must fight a whole team at once. That is a requirement of the
   *challenge*, not of normal play, and it could be met by the challenge widening
   the corridor while it runs rather than by the lane being permanently broad.
   Costs a rule that switches on, which this design has avoided — but it removes
   the strongest structural pull toward the middle.
3. **Diminishing returns per lane.** The simplest and the worst. It works, it is
   arbitrary, it contradicts the vision directly, and it makes a player's
   twentieth stone feel like a punishment for having played well. Last resort.

**And the thing not to do**, because it is the tempting one: **do not let heroes
inherit lane upgrades.** It looks like it would encourage spreading, since a hero
would want to walk where the stones are. It does the opposite — it makes stacking
one lane pay twice for the same decision, which is the exact compounding A14 was
written to prevent. The reason it looks appealing is a different problem that has
already been solved: healers needed to scale with their lane, and they do, because
**healers are wave units** (F40).

---

## 2. The board becomes something people agree in chat and then execute

**What it looks like.** Three players discuss the arrangement in text, reach a
plan, and then spend the match carrying it out. The placement layer stops being
where decisions happen and becomes data entry.

**Why it would happen.** Talking is faster than acting, and a plan agreed in
words is easier to hold than one negotiated through the board.

**What already resists it.** Chat is deliberately the weakest verb — rate
limited, ignorable, and silent when ignored. The two involuntary verbs (a synced
cursor, a placement that announces itself for a whole wave) mean a great deal is
communicated without anybody choosing to. And a placement takes a wave to land,
so a plan agreed now describes a board two waves from now.

**What would show it.** Nothing measures this. It needs six people in a room, and
the tell is whether locking — sorry, **contributing and dismissing** — get used at
all, or whether everything is settled before anybody touches a stone. Tracked as
F26.

---

## 3. Captains make heroes feel pointless

**What it looks like.** A captain is 2.5× health and 1.5× damage *and* carries its
lane's stones. A hero is roughly 2.5× combat weight and carries nothing. In a
lane holding a dozen stones the captain is enormous and the hero beside it is
not, so buying a hero feels like buying a worse version of something that arrives
free.

**Why it would happen.** It is the chest economy out-scaling the wallet economy,
which is **correct** — the chest is the slow accumulating layer and should win a
long game. The pitfall is not the scaling; it is the scaling being *legible as a
comparison*, because the two bodies stand next to each other in the same lane.

**What already resists it.** A hero brings **abilities and timing** — it arrives
where and when you choose and does something a wave unit cannot do at all. That
is a different axis from strength, and heroes are the only bodies on it.

**What would show it.** Hero purchase rate late in a match compared with early.
If players stop buying heroes once lanes are well stocked, the roster is the
problem rather than the captain — and issue 804 should report the two curves
together.

---

## 4. A flat catalogue turns "no comeback mechanic" into "no comeback"

**What it looks like.** Whichever team wins the first few minutes wins the match,
because nothing they could have drawn later would have changed the shape of it.

**Why it would happen.** C3 blessed the snowball on an explicit condition: **the
catalogue must contain kinds whose value changes across a match**, some strong
immediately and fading, some weak on a bare body and enormous on a stacked one.
Without that, a stone drawn at minute twenty is worth what one drawn at minute two
was worth, and a team that fell behind can never out-place its way back.

**What already resists it.** Nothing yet. The catalogue is unwritten and this is
a requirement on it, recorded with B7.

**What would show it.** Not *does the leader win too often* — the leader is
supposed to win. **Does a team that fell behind and then out-placed its opponent
ever come back?** If never, the catalogue is flat. Issue 804.

---

## 5. Asking becomes nagging

**What it looks like.** A player spends the match pointing at teammates' stones
and requesting them, one after another. The request verb becomes a channel for
managing other people's pockets, which is the thing it was built to prevent.

**Why it would happen.** Asking is free and giving is not.

**What already resists it.** One outstanding request at a time, rate limited,
expiring on its own, addressed to a specific stone rather than to a person — and
**ignoring one is free and silent**, with no notification and no record. A request
that can be held against you is a demand.

**What would show it.** Requests issued per player per match, against requests
granted. A high ratio of asked-to-given is the tell.

---

## 6. The bot teammate teaches people not to touch the board

**What it looks like.** A person playing alone places a stone, a bot re-places it
a few seconds later, and the person stops bothering. Single-player becomes
watching.

**Why it would happen.** Nothing in the simulation stops a bot from moving a
communal stone, because nothing stops a *person* either — that is the whole point
of the communal pool. The restraint has to live inside the bot, where it fails
silently.

**What already resists it.** The rule is written down (issue 903) and asserted in
a test. That is thinner protection than a rule the simulation enforces, and the
issue says so.

**What would show it.** A person playing a match and being asked afterwards
whether they felt like it was their board. There is no instrument for this one.

---

## 7. Fear is not fun

**What it looks like.** Fear *"subtly diminishing decision-making"* is a status
effect on a **player** rather than on a body — the only thing in this design that
reaches through the screen. Done badly it is a game that makes your interface
worse while you are losing, which is a punishment for being behind, arriving
exactly when a player is least able to enjoy it.

**Why it would happen.** It is a genuinely novel idea, and novel ideas about
player-facing degradation have a poor record.

**What already resists it.** Nothing built yet. Fortitude answers fear, which
means there is a counter-play — that is the thing to protect. **Fear a player can
do nothing about is the failure; fear they can answer is the mechanic.**

**What would show it.** Whether anybody enjoys the third challenge.

---

Related: [open questions](020-open-questions.md) for decisions rather than
failure modes · [the roadmap](019-roadmap.md), whose "deliberately not in any
phase" list is the sibling of this page — things ruled out rather than watched
for.
