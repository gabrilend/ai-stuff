# 502 — A Round Has Four Acts

| | |
| --- | --- |
| Phase | 5 — Command and the round |
| Blocked by | 305, 405, 406, 407, 501, 504 |
| Blocks | 503 |
| Files | `src/017-the-match.lua` |
| Reads | `docs/datapath-round-and-campaign.md` |

## Current behavior

Built in `src/017-the-match.lua`. With a person, the front-rank act puts
them in the line automatically when the lines touch; tab leaves and returns.
Each battle gets its own streams (match seed × 1000 + round). The match
summary for the receipt lives here too. Tested in
tests/035-command-and-growth.lua (a whole headless match runs every act).

## Intended behavior

A match record holds the campaign (504), the round number, each side's perk
list, the player's choices, the battle in progress (or false), and the
history of rounds.

Each round runs four acts, a dispatch table of act → handlers:

1. **command** — the push direction and the perk are chosen (503); the
   enemy commander chooses its own.
2. **approach** — the battle is set up in the region pushed into, every
   soldier replenished; the view is third person; the commander throws
   volleys and raises shields while the lines close.
3. **front rank** — when any two enemies first come within engage range, the
   view drops into first person behind the player's soldier (or the player
   may press tab at any time after the lines touch). If the player's soldier
   falls, the act returns to third person and the battle goes on.
4. **result** — when a contingent breaks, the winner is recorded, the
   campaign is updated (504), and after a pause the next round's command act
   begins, or the match ends.

Headless, the same acts run with no view; the "drop in" is a flag on the
battle that changes nothing in the simulation except whether the player's
soldier takes input from the script or its own mind.

## Suggested implementation steps

1. Write the acts and their transitions.
2. Test: a headless match runs every act in order and ends with a winner.
