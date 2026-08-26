# The map is geometry, not a picture

The most common way to build a virtual tabletop is: take a PNG of a dungeon, show
it to everyone, let them drag tokens across it. This project does not do that, and
this document is about what replaces it and what that makes possible.

A wall here is a line segment with two endpoints and a couple of flags. It is not
dark pixels. The consequence is that the program can *ask questions about the
space* -- can this creature see that one, does this corridor connect to that room,
where does the torchlight stop -- and a picture cannot be asked anything.

Everything else in the project that is interesting depends on this. Per-person fog
depends on computing sight, which depends on walls being segments. The security
argument in [what a viewer is allowed to know](009-what-a-viewer-is-allowed-to-know.md)
depends on the server knowing what each person can see, which depends on the same
thing. Generated content depends on the map being made of parts rather than being
one baked image.

## The wall record

| Field | Type | Meaning |
| --- | --- | --- |
| `ax`, `ay` | `int32_t` | One endpoint, fixed point, same scale as a thing's position. |
| `bx`, `by` | `int32_t` | The other endpoint. |
| `flags` | `uint16_t` | The bits below. |
| `door` | `uint32_t` | Index into the things array, if this segment is the leaf of a door. `0` if it is plain wall. |

### The flag bits

| Bit | Name | Meaning when set |
| --- | --- | --- |
| 0 | `BLOCKS_SIGHT` | Sight does not cross it. |
| 1 | `BLOCKS_MOVEMENT` | Bodies do not cross it. |
| 2 | `WALL_ONE_WAY` | Blocks only from one side. The side is the segment's left, taking `a`-to-`b` as forward. A window you can see out of but not into; a secret door that is a wall from the corridor. |

Sight-blocking and movement-blocking are separate bits because the interesting
cases are the ones where they disagree. A chasm blocks movement and not sight. A
thick curtain blocks sight and not movement. A portcullis blocks movement and lets
sight through. Collapsing them into one "solid" flag would delete all three.

**A door is a wall whose flags change.** When the door thing at index `door` is
opened, the ruleset clears the blocking bits on this segment. There is no separate
door system, no special case in the sight code, and no doubt about what a
half-open door does -- it is open or it is not, and the leaf swings for the
picture's sake while the segment's bits flip at one defined moment.

## Regions

A region is a named area with a boundary: the tavern, the forest, the third floor
of the tower. Regions are what make an abstract control scope addressable -- when
somebody is given command of "the tavern", what they are given is a region index,
and the scope covers every thing whose `region` field points at it.

| Field | Type | Meaning |
| --- | --- | --- |
| `first_vertex` | `uint32_t` | Index into a shared vertex pool where this region's boundary starts. |
| `vertex_count` | `uint32_t` | How many vertices it has. Boundaries are closed polygons; the last vertex joins the first. |
| `parent` | `uint32_t` | Index of the region that contains this one. `0` for a top-level region. The forest contains a clearing; the tavern contains a cellar. |
| `name_offset` | `uint32_t` | Offset into the string pool. Regions are the one place a human-readable name lives in the world, because a person has to be handed one. |

A thing's `region` field is maintained by the motion pass: when a body crosses a
boundary, its region changes, and the ruleset is told. That crossing is the hook
for everything that is "when they enter the tavern" -- and it costs a
point-in-polygon test only for bodies that actually moved.

Regions nest, and the parent chain is how a scope over "the forest" also covers
the clearing inside it, without listing the clearing.

## Lights

| Field | Type | Meaning |
| --- | --- | --- |
| `thing` | `uint32_t` | The thing that carries this light. Lights do not float free; a torch is a thing. |
| `radius` | `uint32_t` | How far the light reaches, fixed point. |
| `dim_radius` | `uint32_t` | Where bright light ends and dim begins. Many rulesets distinguish them; the server merely carries both numbers and lets the ruleset decide what they mean. |
| `arc` | `uint16_t` | How wide, for a lantern with a shutter. A full turn means it shines everywhere. |
| `colour` | `uint32_t` | Packed. The server does not interpret it. This is one of very few appearance fields in the world, and it is here because light *shape* affects what is visible, so the light has to be in the world rather than in the view. |

## The grid, and where it lives

The world is continuous. Positions are fixed-point, not squares. There is no grid
in any of the records above.

A grid is two other things wearing one name:

- **A drawing** -- lines over the floor so people can judge distance. That belongs
  to the view, and different people at the same table can have it on or off
  without disagreeing about the world.
- **A rule** -- movement snaps to squares, distance is counted in squares, a
  creature occupies exactly one. That belongs to the ruleset. A ruleset that wants
  squares constrains the positions it accepts; the server still stores fixed point,
  and the snapping is the ruleset's arithmetic.

Keeping the grid out of the world means a gridless system and a square-grid system
and a hex system are three rulesets over one server, rather than three servers.

## Everything here is generated

No wall is typed in by hand. Maps come out of a generator that emits segments,
regions, and lights, and the generator is the thing that is maintained -- see
[content is generated](013-content-is-generated.md). A hand-edited map is a map
nobody dares regenerate, and a map nobody dares regenerate is one that stops
matching the tool that made it.

## Read next

- [Sight and what it remembers](007-sight-and-what-it-remembers.md) -- the
  questions this geometry exists to answer.
- [Content is generated](013-content-is-generated.md) -- where walls come from.
