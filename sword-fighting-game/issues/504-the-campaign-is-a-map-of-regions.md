# 504 — The Campaign Is A Map Of Regions

| | |
| --- | --- |
| Phase | 5 — Command and the round |
| Blocked by | 102, 201 |
| Blocks | 502, 503 |
| Files | `src/016-the-campaign.lua` |
| Reads | `docs/datapath-round-and-campaign.md` |

## Current behavior

Built in `src/016-the-campaign.lua` as described; tested in
tests/035-command-and-growth.lua. In progress until the open question about
the rules on a loss is answered.

## Intended behavior

The campaign is a grid of regions (5 × 5 by default), each with a kind
from the regions catalogue (chosen from the `campaign` stream: meadow, swamp
park, prairie with fences, hills) and an owner (1, 2, or 0 for nobody). The
player's home is the middle of the bottom row, the enemy's the middle of the
top row; each side starts owning its home row.

There is a **front**: the region the next battle is pushed from. A push is a
compass direction from the front; legal if the neighbour in that direction is
on the map. The battle is fought in that neighbour, with the player
attacking.

- **Player wins:** the neighbour becomes the player's and the front moves
  there.
- **Player loses:** the enemy pushes back — the front region becomes the
  enemy's and the front moves one step toward the player's home along the
  enemy's chosen push.
- The match is won when the player wins a battle in the enemy's home; lost
  when the player loses a battle while the front is the player's home.

The enemy commander's choice of direction (for deployment, 305) is a pick
from the `campaign` stream weighted toward heading straight at the player's
home.

## Suggested implementation steps

1. Write the map, the push legality, and the result update.
2. Test: legal pushes never leave the map; a won battle in the enemy's home
   ends the match.

## Open questions

- On a loss, the front steps back toward home (built). Should the enemy
  also choose where battles are fought?
