# 076-the-lane-deck

What a lane can afford: a deck of tickets paid for in discards, a purse, and the meters that keep a kind from vanishing.

Read this file rather than the source. The source is for when one specific
function is misbehaving; this is for everything else.

## What it is for

**A wave is drawn, not specified** (issue 213, its first half). Each lane of each team
keeps a deck of tickets, one ticket naming one kind of soldier. Raising a wave takes
the top card — that kind walks out in a kit drawn at birth — then draws and discards
as many more cards as the body costs. Cost is the kit's weight, a point per
`weight_per_point`, rounded up, and never less than one.

**The purse is counted in tickets turned.** Every card off the top — drawn, discarded
or set aside — is a point out of it, and a wave draws until it is spent. It refills
each wave, saves up to a ceiling, and may end a wave in debt by the last body's
discards. So a lane that drew heavy infantry last is poorer next wave, and fields a
lighter one; one that has been cheap can suddenly afford something.

**Two of a kind, never three.** A third card of a kind is set aside, and so is a card
for a half — line or missile — that the commander's `melee_share` has already filled.
A kind missing for a while fills a meter by its tickets each wave; at twice its most
tickets one walks out without being drawn.

**The shuffle is a pile shuffle**, no random number in it: deal into 3, 4, 5, 4, 7
piles and stack them, the odd counts rotating from one shuffle to the next. After each
wave the discards are shuffled this way and put below the undrawn tickets; when the
deck runs out mid-wave the discards are shuffled and become it.

**Both teams' decks for a lane start alike** and draw kit from streams of the same name,
one stream object per team — so neither team's draws depend on the other's, and an
untouched match is still a mirror.

Not here yet: what upgrades do to a deck (a ticket for an entry, a point of income, an
entry traded for a better one), and placing each kind at its own bearing. That is 213b.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `begin(world)` | | — Builds every lane's deck, purse and meters for both teams. Called once at assembly. |
| `draw_wave(world, team, lane, commander)` | the commander whose turn it is | A list of `{archetype, kit, cost, entry}`, ordered by entry and heaviest first, and the lane's books settled for the wave. |
| `pile_shuffle(cards, settings, rotation)` | `settings` is `parameters.unit.deck` | The cards, shuffled. Pure. |
| `cost_of(world, row, mask)` | an archetype row with a kit, and its optional pieces | Its cost, in tickets. |

## Data structures it owns

`world.team[team].lane_deck[lane]`, one per lane per team:

| Field | Type | Meaning |
| --- | --- | --- |
| `draw` | integer[] | The deck, top first. Each card is an index into `parameters.unit.deck.entry`. |
| `discard` | integer[] | Cards turned this wave. Empty between waves. |
| `shuffles` | integer | How many shuffles so far, which picks the next rotation of the odd pile counts. |
| `tickets` | integer[entries] | How many tickets each entry holds. Its start, until 213b. |
| `meter` | integer[entries] | Grows by an entry's tickets each wave it is missing; zero once it walks out. |
| `fielded_total` | integer[entries] | How many of each have walked out of this lane, ever. |
| `purse` | integer | Tickets the lane may turn. May be negative: that is debt. |
| `kit_stream` | stream | Where kit is drawn from. Named for the lane, the same for both teams. |
| `last` | table | The last wave's books: `spent`, `set_aside`, `from_meter`, `fielded`, `purse_after`. |
