# 061-the-stones

An upgrade stops being a number and becomes a specific thing sitting in a specific
place, belonging to somebody.

## What it is for

The chest counted. A team held three Whetstones and that was the whole of what could
be said about them. Counting is enough to stamp a body and not nearly enough for the
thing this game is actually about, which is three people sharing one drawer and
having to get along.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — |
| `draw(world, team, count)` | | — Takes stones off the deck and hands them out. |
| `rebuild_counts(world, team)` | | — Rebuilds the per-slot count cache from the instances. |
| `place(world, player, stone, slot_kind, slot_lane)` | | A verdict. Marks a move; it lands in two waves. |
| `cancel(world, player, stone)` | | A verdict. Free, any time before it lands. |
| `land_transits(world, turn)` | | — Moves everything whose wave has come. |
| `contribute(world, player, stone)` | | A verdict. One-way. |
| `offer(world, player, stone, to)` | | A verdict. The only verb that transfers. |
| `dismiss(world, player, stone)` | | A verdict. *Not my problem.* |
| `request(world, player, stone)` | | A verdict. Changes nothing by itself. |
| `ping` / `move_cursor` | | — Things people say. |
| `reroll(world, player, stone)` | | A verdict. Trades a stone for the next card. |
| `may_touch(stone, player)` | | Theirs, or communal. |
| `visible_to(world, stone, player)` | | Whether it is in that player's own view. |

## The instance

| Field | Meaning |
| --- | --- |
| `id`, `kind`, `team` | Which stone, of what, on whose side. A stone never changes teams. |
| `slot_kind`, `slot_lane` | 0 chest, 1 lane, 2 lane towers, 3 library. |
| `held_by` | The player who owns it, or **0** for communal. |
| `dismissed_mask` | Bit set of players who have set it aside. Clears when all of them have. |
| `moving_to_kind`, `moving_to_lane`, `arrives_turn` | Where it is going and when. |
| `placed_tick`, `is_boon`, `owner` | For the interface and for boons. |

**The instances are the truth; the per-slot counts are a cache**, rebuilt whole
rather than adjusted — same principle as every other sweep here. Everything that
stamps a body reads the cache, because a stamp is a walk over one small array per
kind and turning it into a walk over every stone a team owns would put the chest in
the hot path of every spawn.

## A stone belongs to whoever drew it

Nobody can take it, nobody can move what you placed with it, and **there is no lock,
because there is nothing to lock it against.**

That is the design's second answer to the same problem and it is shaped by the
first's failure. The original had a shared chest with locks: claim a stone so a
teammate cannot move it, plus a two-objection rule to break a lock somebody left on.
It needed a timeout to tune, an interface that reminded you what you were holding
hostage, and a mechanism whose whole purpose was doing something to somebody against
their wishes.

**A lock says *I am doing something here*** — a claim about intent a teammate must
take on trust and cannot check. Ownership says nothing at all, because there is
nothing to say.

Draws go round-robin among a team's players. A wave wipe pays the team, but a stone
has to belong to a person, and keeping everybody holding something is the
precondition for there being a conversation: a player with an empty hand has nothing
to contribute, nothing to offer, and nothing anybody would ask them for.

## Moving takes a wave, and announces itself

A placement lands **two waves after the command**, applying at its old slot the whole
time, with one wave of unchanged behaviour in between.

That delay is the entire negotiation layer. A team that could move every stone every
tick would keep all of them wherever the fighting currently is, and there would be
nothing to argue about.

It is also a **message, and not an opt-in one.** Every teammate sees that a stone is
in transit and where it is going, for a full wave, before it lands. You cannot move
an upgrade quietly.

Cancelling is free and available until it lands. Nothing was spent and the stone has
been applying at its old slot the whole time, so refusing would punish a misclick
with a wave of watching a mistake crawl toward you. The honest cost is that **the
message your teammates were reading can evaporate** — so a transit is a statement of
intent, not a promise.

## Contribute, and the floor that closes

**Contribute** puts a stone in a communal pool where anybody may use it, forever, and
it appears to each of them as simply one of the stones they have — no owner shown, no
*this one is Sam's*. The point is not to hide who gave what; it is that **a shared
thing you have to remember is shared is not shared.** Remembering costs a small
permanent tax of attention and etiquette, and that tax is what made locks necessary.

One-way. A stone in the pool does not come back, because *whose is it really* is
exactly the question the pool exists to delete.

**Dismiss** is the safety on it. The failure of a communal pool is not theft, it is
**neglect** — three people each quietly assuming somebody else has it in hand. So a
player may mark a communal stone *not my problem* and it vanishes from **their** view,
not from the pool.

> When every player has dismissed the same stone, it comes back to all of them.

A stone cannot fall through the floor, because the floor closes. The moment nobody is
looking at it, everybody is — which turns *I assumed you had it* into something that
resurfaces on its own.

**Why a disclaim beats a claim**: a lock is a statement about intent that must be
taken on trust; a dismissal is a statement about attention and is simply true when
made. It cannot be forgotten (one everybody forgets expires), nothing is ever done
*to* anybody, and it scales to any team size with no rule change — "everybody has
dismissed it" means the same at two players as at four, where "two objections" never
did.

## Giving must stay easier than asking

**Offer** is the only verb that transfers anything, costs the giver something real
and visible, cannot be done by accident, and cannot be done *to* somebody.

**Request** changes nothing at all and is deliberately the weakest thing here. It
exists because **refusing to build it does not prevent it** — players will ask over
voice, where the design cannot rate-limit it, cannot make it ignorable without
awkwardness, and cannot stop it becoming a running commentary on what a teammate is
holding. So: one at a time, naming one stone, and **ignoring one is free and silent.**
No notification that you declined, no record, nothing anybody can bring up later. A
request that can be held against you is a demand, and this game is supposed to be
about building each other up rather than managing each other's pockets.
