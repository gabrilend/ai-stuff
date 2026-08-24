# 014 — The Siege-Surge

**Datapath document.** Covers the phase where the chest leaves your hands.

## The four phases, in one place

Because the differences between them are the shape of the whole match:

| | **Normal** | **Siege-surge** | **Challenge** | **The calm** |
| --- | --- | --- | --- | --- |
| How much of the match | the majority | three short stretches | three stretches | **twice, 30–60s each** |
| Spawn shape | **waves**, a batch per lane on a long interval | **a stream**, one body per lane on one shared timer | **waves**, normal interval | **nothing spawns; everyone walks home** |
| Spawn destination | its own lane | its own lane | **the center, all three lanes' worth** | — |
| Who decides upgrades | the players, by placing | **nobody — the whole chest is dealt across the three bodies spawning that instant** | the players, by placing | the players, freely |
| Towers | shoot, can be felled, spawn guards | **shoot, cannot be felled, spawn nothing** | shoot, can be felled, spawn guards | as normal |
| Guards | patrol their tower | **spawn from the base as stream bodies** | patrol their tower | as normal |
| Chest grows on | wave wipes, tower kills | **nothing** | wave wipes, tower kills, the monster | — |
| Also | | | | **each player picks a boon** |

Read down the "siege-surge" column and the phase has one idea in it: **everything
that was a decision becomes a rate.** Waves become a stream, placement becomes a
random draw, towers become terrain, and patrols become more stream. For the
duration, the only things a player still decides are which hero to buy and where
to point a sign-post.

The calm happens **twice, not three times** — after the Pillar Orc and after the
Field Dragon. It never comes after the Eternal Golem, because the Golem is never
slain. See [boons and the challenge](015-boons-and-the-challenge.md).

## The stream

Both bases emit **one body per lane, on one shared timer** — all three lanes fire
at the same instant, so a surge produces bodies in threes. Where normal play
sends a batch down each lane every several seconds, a surge sends a single body
down each lane every fraction of a second.

One timer for all three lanes, not three timers, and that is not a tidiness
decision. It is what makes the dealing below possible: at every spawn there are
exactly three new bodies, one per lane, and the whole chest can be split across
them.

The frontline stops being a place where two waves meet and becomes a place where
two **rates** meet. There is no lull to reposition in, no window where a lane is
briefly empty, and nothing to time anything against, because there is no spawn
clock any more.

Guards join the stream. A tower under surge conditions does not put a patrol on
the ground; its guard production is redirected to the base and emerges as
ordinary stream bodies. The defence walks out to meet the fight instead of
waiting at home for it.

## The chest is dealt across the three, every time

**Upgrades cannot be placed, moved, or withdrawn while a surge is running.**

Instead, at every spawn the team's **entire chest is dealt out across the three
new bodies**, like a hand of cards:

1. Pick a **random starting lane** from the `surge` stream.
2. Walk the chest in random order, handing each upgrade to the next lane's body
   in rotation — starting lane, next, next, back to the first — until every
   upgrade has been dealt.
3. Spawn the three bodies with what they were dealt.

*Settled; see [open questions](020-open-questions.md), A6b.*

So each body gets ⌊N/3⌋ or ⌈N/3⌉ upgrades, **every upgrade you own is on the
field at every instant**, and no two of the three are carrying the same one.

The random starting lane matters for one specific reason: when the chest does not
divide by three, somebody gets one fewer. Starting the deal at a random lane each
time means **which lane comes up short rotates**, rather than the top lane being
permanently a little poorer than the others for the whole surge.

### What this actually does to a team

It does not make you weaker. Nothing is lost, nothing is held back, and your full
chest is walking down the map at all times. **It makes you incoherent.**

The three upgrades that worked together in the top lane are all still on the
field — on three different soldiers, in three different lanes, and never in the
same place again until the surge ends. What the surge takes from you is not
strength; it is the *arrangement*, which is the only thing in this game you
actually built.

It also flattens the lanes perfectly. Every lane receives a third of everything,
so during a surge **no lane is special** — the careful asymmetry a team spent the
match constructing is replaced by an even smear. A team that had stacked one lane
suddenly has three mediocre ones.

And it is self-balancing in a way a flat penalty is not. A team with twelve
upgrades has a great deal disturbed by being dealt out three ways; a team with
three has each of them on a body and almost nothing disturbed at all. **The surge
disrupts in proportion to how much there was to disrupt** — which is exactly the
right shape for the design's only brake on a snowball.

### Where the randomness comes from

A dedicated **`surge` random stream**, per team, separate from `deck`, `boon`,
`wander`, and `tie`. It supplies both the deal order and the starting lane, and
it advances several times a second while a surge runs — far more than any other
stream in the game. Sharing one would mean that changing the stream rate silently
changed every team's upgrade draws forever after. See
[the simulation tick](003-the-simulation-tick.md).

## The towers step back

While a surge runs:

- Towers **still shoot**, at their baseline catalogue values. Their stone upgrades
  are among the ones being scattered across the stream for the duration, so the
  stone fights the surge with nothing on it.
- Towers **cannot be destroyed.** No tower falls during a surge, and therefore no
  three-upgrade tower reward is paid.
- Towers **spawn no guards.** That production goes to the base instead, as
  described above.

Combined with there being no wave wipes to detect — the stream produces no
discrete groups to finish off — **the chest does not grow at all during a
siege-surge.** It is the one stretch of the match where nothing is earned.

Towers being invulnerable is what stops a surge from being a siege window. A team
with a stronger stream would otherwise use the phase to take stone cheaply while
everything was chaotic, and the surge would become a reward for already winning
rather than a disruption of it.

## What players actually do during a surge

Buy heroes, and point sign-posts. That is the whole list.

This is a deliberate hole in the game's main activity, and it is worth naming as
a design property rather than an absence: for two or three stretches a match, the
chest is out of your hands and the only thing you have is the fast layer. A
player who has been banking personal resource has a use for it; a player who has
been ignoring the second economy has nothing to do but watch.

## How it ends

On the tick a surge ends:

1. The stream stops and ordinary wave spawning resumes — redirected to the center,
   because a challenge starts on the same tick.
2. Towers become destructible again and resume spawning guards.
3. **Every upgrade is dumped into the chest, unplaced**, where it does nothing.
4. **The challenge begins** — a named monster per team, in the center lane.

**No boon is handed out here.** A boon is payment for *slaying* a challenge
monster, and it is chosen in the quiet minute afterwards. See
[boons and the challenge](015-boons-and-the-challenge.md).
So a surge does not end in a reward. It ends in a monster and an empty board, and
the scramble the vision describes — "the players have to quickly re-assign them to
re-create the strategies they were using" — happens **under** that monster, with
something enormous walking down the middle while three people rebuild the board.

The reward comes after, if you earn it, and there is a calm to enjoy it in.

Related: [waves](005-waves-and-when-one-is-finished.md) ·
[the shared upgrade pool](009-the-shared-upgrade-pool.md) ·
[boons and the challenge](015-boons-and-the-challenge.md) ·
[guard towers](007-guard-towers-and-their-guards.md)
