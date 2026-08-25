# 905 — Difficulty Without Cheating

| | |
| --- | --- |
| Phase | 9 — An Opponent Worth Playing |
| Blocked by | 902, 903, 904 |
| Blocks | 906 |
| Reads | [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

A bot plays one way, at one strength.

## Intended behavior

**Difficulty comes from decision quality and reaction time. It never comes from
information, and it never comes from bonuses.**

This is not a principle the project is choosing to be nice about — it is the only
option available. Under the networking model the enemy's chest, wallets, and
sign-post directions are **not on the machine**, so a bot has nothing privileged
to read even if somebody wanted it to. And a bot with bonus income or bonus
damage would be measuring something other than the game, which makes every
balance number gathered against it a lie.

So the dials, in the order they should be reached for:

| Dial | What it changes | Why it is honest |
| --- | --- | --- |
| **Reaction delay** | how many ticks pass between a bot seeing a frame and acting on it | a person also takes time to notice |
| **Attention** | how many of the board readings it consults before deciding | a person also misses things |
| **Horizon** | whether it plays toward the next surge or only the next wave | a person also fails to plan |
| **Mistake rate** | how often it takes the second-best option | a person is also wrong sometimes |

**The lowest difficulty should be a bot that is bad in recognisable ways** — slow
to notice a lane collapsing, placing upgrades into a lane where they half-fit,
banking through a surge and overflowing. Those are the mistakes a new player
makes, which makes an easy bot a teaching instrument rather than a handicapped
one.

**The highest difficulty is a bot with no delay and full attention, and that is
the ceiling.** There is nothing above it, because there is nothing else to give
it. If that is not hard enough, the answer is a better bot rather than a bigger
number — and that is the correct place for the ceiling to be.

### The dial that must not exist

**Never make the bot's soldiers stronger.** It is the obvious lever and it is
poison here specifically: the entire premise of this game is that strength comes
from placement decisions over a shared pool, and a bot handed a multiplier is a
bot that has been given the one thing no player can be given. A person who loses
to it learns nothing, because the thing that beat them is not in the game.

## Suggested implementation steps

1. Make every dial a **number in a table**, not a branch. A difficulty is a row.
2. Build reaction delay into issue 901's interface from the start rather than
   bolting it on — it is the single most effective dial and the easiest to get
   wrong late.
3. Implement mistake rate as *taking the second-ranked option*, not as taking a
   random one. A bot that occasionally does something senseless reads as broken;
   a bot that occasionally does something defensible but worse reads as a person.
4. Draw the mistake rate from a **named random stream**, so that a difficulty
   setting is reproducible and a bot match can be replayed.
5. Write a test that no difficulty row touches any catalogue value, ever. It is
   the one guardrail worth enforcing mechanically, because the temptation arrives
   late and under pressure.
6. Run the batch runner from issue 804 across difficulty rows and check the win
   rate moves monotonically. If it does not, a dial is doing something other than
   what it says.

## Related documents and tools

- Issue 901 — the fence a bot reads through, and where delay lives
- Issue 804 — the batch runner that measures whether the dials work
