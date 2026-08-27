# Balance Updates

Append-only. Every knob turned and lever pulled, newest at the bottom, each with
the reason it was turned. Small tuning does not get an issue file; it gets a line
here.

Feature changes and design changes are **not** balance updates. If a rule
changed, that is an issue file. If a number changed, that is a line here.

Format:

    ## YYYY-MM-DD — what changed
    Old → new. Why. What was observed that prompted it.

---

## 2026-08-24 — nothing yet

No numbers have been chosen. The catalogue tables under `assets/` do not exist.
The candidates waiting to be picked are listed in Group B of
[open questions](020-open-questions.md), and the first entry in this ledger
should be the initial values with a note on where they came from.

## 2026-08-24 — the first spawn timings, as estimates

Nothing → the numbers below. These are the author's first estimates, written down
so that the timing tests have something to move away from rather than something
to invent. **None of them has been observed yet.** They are the shape of the
rhythm, not chosen values.

    normal wave interval      every 10-15 seconds
    normal wave size          5-6 bodies per lane
    surge stream interval     every 0.5 seconds
    surge stream size         one body per lane, all lanes on one shared timer

The ratio is what matters more than either number: a surge puts bodies on the
ground roughly twenty to thirty times as often as a wave does, one at a time
instead of six at a time. If the timing tests move one of these, they should move
the other and keep the ratio in view, because the surge's whole feel is that the
lull between waves disappears.

Related open questions: B1 (wave interval and size), B2 (surge length and stream
rate against the wave rate).

## 2026-08-26 — the first numbers that actually run

Estimates → catalogue tables. The four files under `assets/` now exist, so for the
first time these are values a program reads rather than a shape written down. They
were chosen to make a match *observable*, not to make it good: the point was to get
a frontline on screen so that everything in Group B has something to move away
from.

Where each cluster is anchored, following the discipline Group B asks for:

    the wave is the clock       -- one wave per lane per team, every 620 ticks
    a wave unit is the strength -- melee is 1x and everything else is a ratio
    the captain is 2.5x / 1.5x  -- health and damage, per the design
    the library is 1.5 towers   -- stored as a ratio, never as a figure
    a tick is 1/30 of a second  -- so a cooldown of 22 ticks is about 0.7s

What was observed, from the headless runner:

- **The stalemate is real and reproduces.** Twenty-two minutes, both teams between
  milestones three and four in every lane, neither base threatened. That is the
  vision's problem statement and it is now a thing that happens on a machine.
- **A melee body kills another in roughly six seconds** one-to-one, which is slow
  enough that a rank holds and fast enough that a wave resolves before the next one
  arrives. That number is what the wave interval was then chosen against.
- **The chest fills much faster than expected** — around a hundred and ninety draws
  per team over a full match, because nearly every wave in a stalemate is eventually
  wiped and nearly every wipe pays. Raised as **G4** rather than tuned here, because
  the match is only that long because the surge and the challenge are not built, and
  the number should be re-measured against a match shape that can actually end.
- **A stacked lane wins outright.** Everything one team drew, shovelled into the
  centre, reached the enemy library while the enemy's depth there collapsed to zero.
  Recorded against **B11**, which is the question the whole project exists to answer.

Two numbers that are not balance and are noted so nobody tunes them by accident:

    milestone 4 is at fraction 0.50   -- it must be the lane's bend; the builder
                                         places every other milestone relative to it
    command radius > tower range      -- getting inside has to be reachable ground
                                         rather than a spot under maximum fire

Related open questions: B1, B4, B5, B11, G4.

## 2026-08-26 — the camera's three constants

Nothing → the numbers below. Not simulation balance, but they are knobs with
reasons and they belong in the same ledger rather than in a comment nobody finds.

    wheel factor        1.18 per notch, multiplicative
    ease rate           14.0, as an exponential time constant
    zoom ceiling        9.0 screen pixels per pace

**Multiplicative, not additive**, because a notch should be the same *proportional*
change at every scale — an additive step crawls when zoomed in and jumps when zoomed
out, which is the same complaint from both ends.

**The ceiling is not a preference.** It is set by the requirement that a soldier's
upgrade badges be readable off the body, which is how an opponent learns your
arrangement at all. If the badges get smaller, this number goes up.

**The floor is not a number**, it is the whole-map framing, computed from the map's
own bounds — so changing the field size reframes the view with no second edit.

## 2026-08-26 — the second economy's first numbers

Nothing → the commander catalogue. Six colours, two commanders, six heroes, and
the die ladder that caps a wallet.

    colours              6, one per attribute score, each with its own display
                         shape as well as its own hue
    wallet ceiling       the die ladder -- 4, 6, 8, 10, 12 -- climbing a rung
                         every 2400 ticks and stopping at a d12
    bounty per kill      1 for a wave body, 3 for a captain, 5 for a hero,
                         40 for a challenge monster; **per player**, not a pot
    hero costs           two colours each, 5 or 6 points in total

Observed on the first run:

- **Players waste far more than they hold.** A hundred seconds in, each player had
  banked six might against a ceiling of six and thrown away fifty. That is the
  "spend it or waste it" pressure doing exactly what it is for, but the ratio says
  the early ceiling is very tight against the early income. Left alone for now,
  because the ladder climbs and because it is the kind of number that should be
  read off a long match rather than a short one.
- **A pair of commanders defines an economy.** With both in circulation every hero
  on both rosters is buyable; facing only one, half of them are not. That is the
  design working -- you farm what the enemy fields -- and it is also a trap, which
  is why the catalogue now says so out loud.

## 2026-08-26 — fear, and what it does instead of damage

Nothing → a frightened body swings at **0.62** of its damage for **180 ticks**.

Fear is the enemy's actual weapon and it is deliberately not a second way of doing
what swords already do. It is inflicted, on purpose, by something that meant to,
and it makes a crowd worse rather than better -- which is why the ability that
carries it fires on a crowd.

The number is a guess and wants a real fight to be read against. What it must not
become is large enough that a feared line simply stops working; the statue is
definitely slayable, you just have to have a stronger spirit.

## 2026-08-26 — the shape of a match, and monsters worth the name

Nothing → the phase timings, the stream rate, and three monsters.

    first normal stretch   5400 ticks (three minutes) before the first surge
    later normal stretches 4200 ticks
    surge                  1500 ticks
    calm                   900 ticks
    stream interval        15 ticks -- one body per lane, all lanes together

The stream rate against the wave rate is the ratio that matters, and it lands at
about forty to one: a wave leaves each lane every 620 ticks, and a surge puts a body
down in every lane every 15. The lull disappears entirely, which is the whole feel of
the phase.

**The monsters were tripled after the first measurement.** At 5200 and 8600 health
the Pillar Orc and the Field Dragon died in about thirteen seconds each, which is not
a challenge — it is an interruption. At 19000 and 31000:

    challenge 1   monster fell 30 seconds in
    challenge 2   monster fell 16 seconds in
    challenge 3   never; the match ended at 13 minutes

Thirty seconds is close to right, and the reason is worth writing down because it is
the number the tuning should be against rather than the health figure. **The deadline
is the walk**: from the midpoint of the centre lane to a library is about 720 paces,
and at 0.60 paces per tick that is forty seconds. A monster that dies at thirty has
got three quarters of the way, which is the tension the phase is for.

The second one dying faster than the first, despite being half again as tough, is the
boons compounding — both teams are stronger by then. That is the design and not a
defect, but it means the escalation has to outrun the compounding, and 31000 does not
by enough.

Related open questions: B2 (surge length and stream rate), B11.

## 2026-08-27 — the first numbers from playing it many times

No knobs turned. This is the first run of `./run-many-matches`, which is the thing
every question marked *awaiting evidence* has been waiting on, and what it produced is
a list of things to turn rather than a turn.

Twelve matches to a 30000-tick limit, both sides played by the measuring bot:

    team 1 won                     5 of 12
    team 2 won                     7 of 12
    drawn                          0
    never finished                 0
    a decided match lasts          9.6 minutes
    upgrades drawn per match       167
    of those, ever placed          89%
    heroes bought per match        531
    income thrown away per match   4788
    surges / challenges per match  1.7 / 1.7

**Every match finished.** None hit the tick limit and none was a draw, which is the
phase table doing its job — before it existed, two even sides ground until somebody
stopped watching.

**Heroes are far too cheap.** Five hundred and thirty-one purchases across six players
in under ten minutes is a hero every six seconds each. They are supposed to be a
decision — when to bank, when to spend, which of the five — and at this price there is
no decision, only a rate. Either costs go up sharply or income comes down, and the
next number says which.

**Income overwhelms everything.** Nearly five thousand points thrown away per match
*after* buying five hundred heroes. A full colour loses what arrives at it, so that
figure is pure overflow: the wallets are full essentially all the time. The die ladder
was meant to be pressure to spend; it is currently a wall that income sits against.

The two together point at the payout rather than at the prices. A body is worth 1 and
a captain 3, per player, and both teams kill a great many bodies — which was sized
before there was anything to spend it on.

**A match ends before the third challenge**, at 1.7 of them. The Golem almost never
arrives, which means the design's guarantee of termination is being provided by
somebody winning normally rather than by the thing built to provide it. Not wrong, but
worth knowing: the Golem is currently a safety net rather than an ending.

Related open questions: B5 through B9 all now have a first measurement, and **G4 is
answered below**.

## 2026-08-27 — the runner had to be made parallel before it was any use

One match is a single-threaded walk over flat arrays and will not go faster. A thousand
matches are a thousand independent walks and were being done one at a time, at thirty
seconds each — which puts ten thousand matches at three and a half days, and the entire
point of the thing is that you read the table in the morning.

It splits the seed range across one worker per core now. Sixteen matches in ninety-seven
seconds on fourteen cores, so ten thousand is a long night rather than a long weekend.

Each worker takes every Nth seed rather than a contiguous block, so a short run still
spreads across the range instead of giving one worker all the low seeds.
