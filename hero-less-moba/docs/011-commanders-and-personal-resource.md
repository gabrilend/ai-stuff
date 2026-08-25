# 011 — Commanders and Personal Resource

**Datapath document.** Covers the one thing in this game that belongs to a single
player and cannot be touched by their teammates.

## What a commander is

Each player picks a commander before the match. A commander is **not a body on
the map.** There is no avatar to move, no commander health bar, and nothing to
kill. A commander is two things and only two things:

1. The **name of your resource** — gold, mana, blood, embers, favour.
2. The **roster of hero units** you are allowed to buy with it.

The resource name is flair. Two commanders that both call it "gold" are
mechanically identical in that respect: one number, earned the same way, spent
the same way. The vision says this outright and it is worth holding to, because
the temptation to make one commander's resource behave differently — decay over
time, cap out, convert — is exactly the temptation that turns a clean second
economy into six special cases.

The roster is where commanders actually differ. Everything about how a commander
plays is in what they can put on the ground.

### commander record — catalogue, fixed at build time

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | integer | Row in the commander catalogue. |
| `name` | string | Shown to players. |
| `resource_name` | string | Flair only. Never read by any rule. |
| `roster` | integer[] | Rows in the unit catalogue. At least three heroes, ideally five. |

### player record — live, per match

| Field | Type | Meaning |
| --- | --- | --- |
| `number` | integer | 1–6. Players 1–3 are team 1, 4–6 are team 2. |
| `team` | integer | 1 or 2. |
| `commander` | integer | Row in the commander catalogue. |
| `resource` | double | Current balance. Never negative, and never above `resource_max` — income arriving at the ceiling is lost. |
| `resource_max` | double | The current ceiling. Rises as the match goes on. |
| `resource_wasted` | double | Lifetime total lost to overflow. For the report, and for making the player uncomfortable. |
| `resource_earned` | double | Lifetime total, for the post-match report. |
| `hero_alive` | integer | How many of this player's heroes are currently on the map. |

## Earning

**Every kill your team lands pays every player on your team, in full.** *Settled;
see [open questions](020-open-questions.md), A2.*

It does not matter what did the killing. A wave unit, a tower guard, a guard
tower's arrow, somebody else's hero, a challenge monster being finished off — the
reap pass reads **the dead body's own team** and credits every player on the
other one. There is no last-hit tracking and nothing walks back to a killer —
see [combat and damage](006-combat-and-damage.md) and F13. The payout figure in
the catalogue is **per player**, not a pot to be divided, so a team's total income
scales with the team's size — three times what any one player sees, at three a
side. *That last detail is a ruling rather than something the answer settled; see
the open questions page.*

The payout per kill scales with what was killed. A wave unit is worth a small
amount, a hero unit a large one, a challenge monster an enormous one. The exact
figures live in the unit catalogue and are reported by the balance validator.

### What this makes the second economy

Because income is identical across a team, **the only thing that distinguishes
two teammates is what they do with the same money.** When to bank and when to
spend. Which of the five heroes. Which of the three spawn destinations. That is a
much better axis to differentiate players on than who was better at landing final
blows, and it means a player who is inattentive at the frontline is not thereby
poorer than their teammates — only slower to convert.

It also means the hero economy has no death spiral. A player who buys a hero, puts
it somewhere stupid, and watches it die in ten seconds has lost the purchase and
nothing else. They are earning at the same rate as everyone else and can try
again. The word "personal" in *personal resource* means a private wallet, not a
private income.

The cost of this, and it is real: **a team's income now tracks its map position.**
A team that is winning lanes is killing more, so it earns more, so it fields more
heroes, so it wins lanes harder. That is the same snowball the upgrade economy
has, running alongside it — and unlike the upgrade economy, nothing interrupts
this one. A siege-surge deals every upgrade out across the stream; it does not touch
anybody's wallet.
Whether that needs a floor is on the [open questions](020-open-questions.md) page
as a question this answer created.
## The cap, and why there is no cap on heroes

**There is no limit on how many of your heroes can be alive at once. There is a
limit on how much resource you can hold.** *Settled; see
[open questions](020-open-questions.md), A16.*

A player's balance has a ceiling. Income arriving at the ceiling is **lost** —
not stored, not carried, not converted. Spend it or waste it.

That is a much better limiter than a hero cap, and the difference is worth
stating because it is the difference between a rule and a pressure.

**A hero cap says no.** It refuses a purchase, at the moment a player has decided
to make it, for a reason that has nothing to do with the situation in front of
them. It is arbitrary in exactly the way the rules of this game try not to be.

**A resource ceiling says now.** It never refuses anything. It just means that a
player sitting on a full wallet is **actively losing** every kill their team
lands, and the only way to stop losing is to act. Nobody is told what to do; they
are told that doing nothing costs something.

Three consequences:

- **Hoarding through a surge stops working.** The bank-two-surges-and-drop-six-
  heroes play is not forbidden — it is simply impossible to save that much.
- **The fast layer becomes genuinely constant.** There is no phase where a player
  can correctly ignore their wallet, because ignoring it is spending it on
  nothing.
- **Rerolls become the overflow valve.** A player at the ceiling with nowhere
  good to put a hero has a second sink: pay to send an upgrade to the bottom of
  the deck. Resource that would have evaporated buys a chance at a better chest
  instead, which is a much more interesting thing to do with a full wallet than
  buying a hero you do not need.

A player at or near the ceiling must be told, loudly and continuously. **An
invisible overflow is a punishment nobody can see**, which is the worst kind, and
this is the one number in the interface that should be uncomfortable to look at.

### The ceiling rises as the match goes on

It is not one number. **It starts tight and grows**, so early play is relentless
and late play has room in it. *Settled; see
[open questions](020-open-questions.md), A16b.*

Early on the ceiling is barely more than your most expensive hero: you are
spending almost constantly and overflowing the moment you hesitate. By the end of
a match it is large enough that a deliberate spike is a real play — bank for a
minute and put four bodies on the ground at once.

**It rises at each calm**, alongside the boons — **two calms, two raises.**
*Settled; see [open questions](020-open-questions.md), A16b, and F6 for why there
are exactly two.* That ties the wallet's growth to the same events that grow
everything else, so a match escalates in one rhythm rather than three, and it
means the ceiling steps up in front of the player rather than creeping. The
alternative, continuous growth with the match clock, is smoother and much harder
to notice happening.

The two economies therefore step together and step twice: at each calm a player
picks a boon and their wallet gets deeper. By the third surge both are at their
maximum and neither will move again.

The interaction with the endgame is worth seeing early. **The third challenge is
the last thing the wallet is ever for.** *Settled; see
[open questions](020-open-questions.md), F9.* There are no more boons to be
chosen and no more calms to raise the ceiling, so the ceiling reached before the
third surge is the ceiling a team finishes on — at its highest, and permanent.

Income does **not** stop. Waves keep spawning into the centre, bodies keep dying,
and every death still pays every player on the opposing team. An earlier draft of
this document said the third challenge had "no income at all," which generalised
a narrower fact — the Golem itself pays nothing, for damage or for a kill it
cannot suffer — into a claim the combat rules contradict.

So the endgame is not a stretch with the wallet switched off. It is the stretch
where **the wallet is the only thing still moving.** No draws worth arranging, no
boons to come, and personal resource buying the heroes that are the only variable
left in how long a team holds its Golem back.

It also matches what the boons are already doing. Both economies accumulate a
floor as a match runs, so the late game is simply bigger than the early game on
both axes, and a mistake late costs more than the same mistake early.

## Spending

Resource buys exactly two things.

**Hero units**, which is the obvious one and the bulk of it.

**And rerolls.** A player may spend resource to take one of their team's upgrades,
send it to the bottom of the deck, and immediately draw the next card. *Settled;
see [open questions](020-open-questions.md), A11b.*

That second one deserves care, because an earlier draft of this document said
flatly that the two economies never touch and that no exchange rate exists
between them. **That is no longer true**, and the shape of the exchange is worth
being precise about:

- Resource **cannot buy an upgrade.** Rerolling does not add to the chest; your
  instance count is unchanged.
- Resource **cannot buy a better upgrade**, either. You get the next card, which
  is whatever the deck says it is.
- What resource buys is **deviation from a shared sequence.** Both teams draw the
  same kinds in the same order; paying is the only way to be somewhere else on
  that track than your opponent.

So the exchange rate is not chest-for-wallet. It is **certainty-for-heroes.** You
are spending bodies you will never field in order to stop holding a card you do
not want, and you are doing it knowing the enemy is holding that same card and
may keep it.

The tension is direct and it is the point: every reroll is a hero that never
existed. A player who rerolls freely has a well-shaped chest and nothing to put
on the ground with it.

Keeping the two economies otherwise separate is what stops the game collapsing
into one activity. A player who only manages the chest still has resource piling
up unused and heroes they are not fielding. A player who only buys heroes is
leaving upgrades sitting unplaced where their teammates can see them. Both are
visible failures, to teammates and to the player themselves, and both have an
obvious fix.

Related: [hero units](012-hero-units.md) ·
[combat and damage](006-combat-and-damage.md) ·
[players, teams, and commands](016-players-teams-and-commands.md)
