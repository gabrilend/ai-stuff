# 042-domains

Land, air and sea: the one question a domain answers is where a unit may stand.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

There is no ship code, plane code or tank code. A domain is an integer in the
unit row, and it changes exactly two things:

- **Movement** asks one question, *may this unit stand here?* It is answered
  off the heightfield: land at or above the water line, sea below it, air
  anywhere.
- **Combat** reads the catalogue's `reaches`, a bit set over the same domains.
  The bits are named here.

The domains are a dispatch table, `STAND`, with one function per domain.
Adding a domain, such as issue 506's submerged carrier, means adding a row, not
a branch.

A plane flies at the ground beneath it plus its kind's flight height, so a
plane crossing a dune climbs with it. Over the water, the ground is the water
line and never the sea floor.

A shore cell is land with sea in one of its four neighbours. That is where a sea
factory stands (issue 307).

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `can_stand(field, domain, x, y)` | a field; a domain as a name or an integer; a position in cells | whether that domain may stand in the position's cell; refuses an unknown domain and a position off the field, by name |
| `ground_at(field, x, y)` | a field; a position | the height of the position's cell |
| `altitude_at(field, kind, x, y)` | a field; a kind's name or index; a position | the ground (or the water line, over the sea) plus the kind's flight height; zero for a kind that does not fly |
| `is_shore(field, x, y)` | a field; a position | whether the cell is land with sea beside it |
| `validate(world)` | a world | nothing; called by the units validator. Refuses, naming the row, a live unit standing where its domain may not, or off the field |
| `LAND`, `AIR`, `SEA` | | 1, 2, 3 |
| `DOMAINS`, `NAMES` | | name to integer, and integer to name |
| `REACH` | | the reach bits: land 1, air 2, sea 4 |
| `STAND` | | the dispatch table: `STAND[domain](height, water_line)` |

## Data structures it owns

None. It reads the field and the catalogue.
