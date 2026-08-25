# 904 — Buying Bodies and Pointing Them

| | |
| --- | --- |
| Phase | 9 — An Opponent Worth Playing |
| Blocked by | 902, 503, 508 |
| Blocks | 906 |
| Reads | [hero units](../docs/012-hero-units.md) · [commanders and personal resource](../docs/011-commanders-and-personal-resource.md) |
| Open questions | none |

## Current behavior

The measuring bot from issue 803 places upgrades. Nothing buys a hero, and
nothing has ever touched a sign-post.

## Intended behavior

The fast layer, played by a bot. Three decisions, and they are the same three a
person makes.

**When to spend.** The wallet has a ceiling and income arriving at it is lost, so
the floor of competence is simply **never overflow** — a bot sitting at its
ceiling is throwing away every kill its team lands. That single rule gets a bot
most of the way to reasonable, which is worth knowing before anything cleverer is
attempted.

**Which hero.** From its commander's roster, against what the board reading says
is needed — something that holds a frontline, something that kills one, something
that kills stone. This is where a bot is allowed to be worse than a person and
where difficulty (issue 905) has room to live.

**Where to put it.** The three destinations are a real trade and a bot should
feel it: onto a wave is immediate and fragile, onto a tower is safe and slower,
onto the library is safest and slowest. The tower option is refused while enemies
stand inside that tower's **command radius**, so a bot has to check the same
circle a person looks at — and, since the radius is drawn for both teams, a bot
watching an *enemy* tower's radius knows when the enemy cannot reinforce it.

**Sign-posts** are the standing-orders half. A bot sets its three the way a person
should: rarely, and as a policy rather than a correction. It must respect the
one-turn rule — a body it routed into the centre cannot be routed again — so a
sign-post is a decision about *every future purchase*, not about the hero
currently walking.

### The endgame is different and a bot must know it

During the third challenge there are no more boons, no more ceiling raises, and
nothing to arrange. **Personal resource is the only live variable left**, and a
bot that keeps banking through the Golem has misread the whole phase. The rule is
blunt enough to hard-code: once the third surge ends, spend everything, always.

## Suggested implementation steps

1. Write the never-overflow rule first and measure it alone. It is the baseline
   every other spending behaviour has to beat, and it may beat most of them.
2. Write hero selection against the board readings, as a table from *what the
   board needs* to *roster rows that answer it* — a dispatch table, not a chain
   of conditions.
3. Write destination choice, including the command-radius check, and a test that
   a bot never issues a hero spawn that gets refused. A bot that spams refused
   commands is a bot that will look broken in the log for months.
4. Write sign-post policy as something that changes on **phase boundaries only**.
   A bot that re-points a sign every few seconds is producing noise, and its own
   heroes will end up scattered.
5. Hard-code the endgame spend-everything rule and comment it with why: there is
   nothing else left to buy.
6. Write a test that a bot's wallet never sits at the ceiling for more than a
   short window at any point in a match.

## Related documents and tools

- [Hero units](../docs/012-hero-units.md) — the three destinations and the radius
- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)
  — the ceiling, and why overflow is the pressure
- [Sign-posts and lane routing](../docs/013-signposts-and-lane-routing.md)
