# 802 — The Lobby and Commander Selection

| | |
| --- | --- |
| Phase | 8 — Six Players |
| Blocked by | 501, 801 |
| Blocks | 805 |
| Reads | [commanders and personal resource](../docs/011-commanders-and-personal-resource.md), [players, teams, and commands](../docs/016-players-teams-and-commands.md) |
| Open questions | none |

## Current behavior

Player count, team assignment, and commanders are constants in a configuration
file.

## Intended behavior

The place a match is agreed on before it starts. Two teams, each player picking a
commander, everybody agreeing on a seed.

**Commander selection is a team conversation rather than a private preference**,
and that is new. Since the commanders take turns sending waves (F35b), a third of
what walks out of your base is somebody else's choice — their composition, their
bounty shape, their captain. A team that picks three swarm commanders is a team
that has decided something together, whether or not it noticed.

So the lobby owes players a view of **what the three of them add up to**: the
combined composition, the colours it will pay, and where the gaps are. Not a
recommendation — a mirror.

The lobby's real job is producing the **replay header**: match seed, rules
version, map parameters, player count, and each player's commander. That header
plus the command list is the entire match. Everything the lobby does is filling
in six fields.

Team assignment is arithmetic on the team size: the first half of the player
numbers are team 1, the second half team 2. Not a lookup and not a table, so that
command ordering by player number is also grouping by team — and so that the
lobby can seat a 2v2 or a 4v4 without a special case. See F10.

Commander selection is visible to your own team and — undecided — possibly to the
enemy. Since a commander is a roster rather than a body, knowing the enemy's
commanders tells you what may walk out of their base for the whole match, which
is a substantial piece of information.

The lobby is also where **team size** stops being a constant and becomes a
number. Everything in the simulation is written against a team-size constant
rather than the literal three, and the lock rule is phrased as "everyone but the
locker has objected" rather than "two people have objected," so that supporting 2v2
is a configuration change rather than a rewrite. This is where that pays off, or
where it turns out not to.

## Suggested implementation steps

1. Write the lobby state: players joined, teams, commanders chosen, ready flags.
2. Write the seed agreement — one machine proposes, all acknowledge, and it goes
   into the header before any simulation starts.
3. Write commander selection with the validator from issue 501 refusing an
   unfilled roster.
4. Write the rules-version stamp and refuse to start a match between machines
   whose versions differ, loudly and by name.
5. Write the handoff into the simulation, and confirm a match started from a
   lobby replays identically from its header.

## Related documents and tools

- [Commanders and personal resource](../docs/011-commanders-and-personal-resource.md)
- [Players, teams, and commands](../docs/016-players-teams-and-commands.md)

## Still open

How many players per team, and are smaller team sizes supported at all? And may
two teammates pick the same commander — which is either a legitimate specialist
composition or a boring one, depending on how distinct the rosters turn out.
