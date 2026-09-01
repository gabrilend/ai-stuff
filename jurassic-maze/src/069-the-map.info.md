# 069-the-map

Reads a hand-authored map of plates and stairs, and flattens it to a height field.

Read this page rather than the source. The source is for when one named function
is misbehaving; this is for everything else.

## What it is for

A map here is data a person typed, not something a generator produced, and that
changes what the file is for. A generator's output can be trusted to be
self-consistent, because the same code made all of it. A hand-authored file has
typos in it, and a typo that loads quietly is a map nobody can debug. So most of
this module is refusals.

The language has two words in it, because that is all the reference picture is
made of: flat tops, and the stairs between them. There is not one wall in that
picture.

## Exports

| Function | Arguments | Returns |
| --- | --- | --- |
| `load(map)` | a map table | a height field and a report |
| `describe(field)` | | what was loaded, as lines of text |
| `to_store(Stone, field, layers)` | | the same world as a stone store |
| `DIRECTIONS` | | the four names a staircase may head in |

## What a map contains

**A plate** is an axis-aligned rectangle of flat ground.

| Field | Type | Meaning |
| --- | --- | --- |
| `x`, `y` | integers | the corner nearest the origin, in cells |
| `w`, `d` | integers, at least 1, default 1 | extent along x and along y |
| `z` | integer | the plane of its top surface |

**A staircase** carries one elevation down to another.

| Field | Type | Meaning |
| --- | --- | --- |
| `x`, `y` | integers | the top tread |
| `dir` | `"+x"`, `"-x"`, `"+y"`, `"-y"` | which way it descends |
| `w` | integer, default 1 | how wide the flight is, across its direction |
| `from`, `to` | integers | elevation at the top, and the shelf it lands on |

There are `from - to` treads, one per layer, and tread `n` sits at `from - n`.
One layer per tread is what makes a flight a ramp a ball accelerates down rather
than a row of ledges it stalls on.

## The field that comes out

| Field | Type | Meaning |
| --- | --- | --- |
| `width`, `depth` | integers | the footprint in cells |
| `height[i]` | integer | the top surface plane at `x + y * width` |
| `lowest`, `highest` | integers | the elevation range |
| `uncovered` | integer | cells no plate reached, left at the map's `base` |
| `claimed[n]` | integer | how many cells plate `n` still shows in the finished surface |

## Two rules that make the format authorable

**Where plates overlap, the higher wins, and the order they were written in does
not matter.** A plaza with a block standing in it is two rectangles — the plaza,
then the block — rather than the plaza split into four pieces around a hole. The
order independence is the part that matters: somebody adding a plate must not
have to work out where in the list it belongs.

**A staircase overwrites, high or low.** Not "the higher wins" — a flight cuts
through the rim of the shelf it leaves, a rim is by definition taller than the
flight passing through it, and taking the higher of the two would fill the cut
back in and leave a staircase drawn on a shelf that goes nowhere.

## `claimed` is counted afterwards, and that is the whole point of it

A plate that shows nothing in the finished surface was buried by something
higher, and that is nearly always a typo. Counting while building would be
order-dependent — a plate written first wins every cell it touches and then
loses them again — so it would report a healthy number for a plate that is
completely invisible. Counting against the finished field asks the only useful
question: is any of this plate still there?

## `to_store` is scaffolding, and the one-layer trap in it

The stone store is a grid of 32-bit columns with a bit per layer, built to
express tunnels and overhangs that a hand-authored height field cannot have and
does not want. The reason to build one anyway is that the renderer, the sightline
survey and the validator all speak store, and a map nobody can look at is a map
nobody can check.

**A map's elevation is the plane of the top surface; a store's height is the
index of the topmost solid layer, and a layer L occupies L to L + 1.** They
differ by one. A shelf you stand on at 22 is layer 21 in the store. Everything
downstream of the map works in planes, because a ball resting on that shelf has
its centre at 22 plus its radius; everything downstream of the store works in
layers.

Every cell of a map is walkable, because every surface in one is the top of
something. That is why the maze validator cannot be run against a map: its first
check insists the rim of the world is wall.
