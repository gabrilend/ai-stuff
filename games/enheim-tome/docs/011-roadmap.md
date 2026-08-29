# 011 — Roadmap

Eight phases. They group functionality, not time — **lower numbers are more
foundational, not earlier**. It would be entirely normal for the last thing
finished in this project to belong to phase 1.

Everything below is interface and world. **The mechanics are deliberately
absent** and will form later phases once they exist; see
[what this game is](001-what-this-game-is.md) on why the interface is being
worked out first.

## Phase 1 — The Canvas

One painting on screen, pannable and zoomable, and nothing else. No game in it at
all. It should stay runnable as a pure viewer forever after, because a viewer
with no logic in it is what you reach for when you cannot tell whether a problem
is in the drawing or in the thinking.

Intended issues:

- the painting is one texture, mipmapped, not tiled
- the view is an offset and a scale, with a floor and a ceiling
- pan and zoom bindings *(blocked — open question 1, and the tracing tool must agree)*
- a converted-texture step, so nothing decodes a 25-megapixel image at a bad moment
- the window, the two panes, and the seam between them

Reads: [the map surface](002-the-map-surface.md).

## Phase 2 — The Cage

The fence network as a structure and as an appearance. This decides whether the
hand-tracing in phase 3 is worth doing, so it comes first even though nothing can
be traced yet.

Intended issues:

- vertices, edges and blocks as tables; loops that close
- junctions and shape points, derived rather than stored
- adjacency is a shared edge, and the walk over it
- the identity buffer, and hit-testing as one pixel read
- the fence drawn one pixel wide in screen space
- each boundary fades on its own on-screen width
- the network validator, and what it refuses

Reads: [the fence network](004-the-fence-network.md).

## Phase 3 — The Tracing Tool

The second program, and the only thing that ever writes a fence network. The
instrument for defining a city by hand.

**This phase gates the largest cost in the project**, so it is finished properly
before the tracing campaign begins rather than alongside it — doubly so given the
board is currently a stand-in and every traced hour is provisional. See
[the notice](../inspiration-pictures/NOTICE.md).

Intended issues:

- a separate executable sharing the canvas code
- the click dispatch: new vertex, adopt vertex, adopt edge
- the pointer shows which of the three is about to happen
- snapping measured in screen pixels, and refusing imprecise work
- dragging a junction moves every fence into that corner
- naming a block, naming an intersection
- placing a building's rough zone
- assigning district and quadrant membership
- a coverage report
- undo *(blocked — open question 10, how deep undo goes)*

Reads: [the tracing tool](005-the-tracing-tool.md).

## Phase 4 — The Places

Everything above and below the block. Mostly bookkeeping, and almost none of it
geometry.

Intended issues:

- the containment chain as a list of the levels a place has, never a fixed depth
- groups: the city, and each megastructure, with no parent above them
- quadrants, four to a group, absent beyond the wall
- districts and quadrants outlined from membership, never traced
- buildings: rough zones, own facts, mostly open
- houses: no geometry, almost always restricted, listed inside a building
- the zoom picks which level a click selects
- the cage drawn at four weights

Reads: [the places of the city](003-the-places-of-the-city.md).

## Phase 5 — Filters and the Weave

Ways of looking at the city, drawn over it. The readings come first and are
checkable with nothing on screen; the hatching comes after.

Intended issues:

- a filter is a name, a colour, an angle, a mode, parameters, and a reading
- a reading takes **a person and a place**, and may answer nothing
- switching person repaints the map
- the three modes and the render order
- the weave, resolved by line-index parity
- hatching anchored to painting coordinates, spaced in screen pixels
- the glow, breathing, additive
- the glow flips to aiming at high zoom *(blocked — open question 3, the tunable that flips it)*
- a place's default filter switches on when it is selected

Reads: [filters and the weave](006-filters-and-the-weave.md).

## Phase 6 — The Tome

The written half. Three regions, and the rule that colour never carries a fact
the words don't.

Intended issues:

- three regions: welded, welded, scrolling
- the chip row, and the focused filter's controls
- a chip carries name and angle, not only colour *(blocked — open question 6, chip legibility)*
- the icon button pane, with dimming
- the move queue among the buttons, and go *(blocked — open question 4, whether queue order shows)*
- the text pane, stylable *(blocked — open question 5, what the colours mean)*
- descending block → building → house → person, and playing as them
- a block's intersections listed with their connections
- space to search, and going to a place by name
- the interior frame, in three placements

Reads: [the tome](007-the-tome.md).

## Phase 7 — The Day

Time, and the small horizontal object that lets you sweep through it.

Intended issues:

- the hour as a global axis, above every filter
- the world advances on a move or on go, never on its own
- whereabouts as a function of the hour
- the time-curve, activity plotted, swept by dragging
- sweeping drives the hour and everything that reads it
- hovering and dragging must be distinguishable
- curves readable only for people you know
- a few pinned, the rest on demand

Reads: [the day and the curve](008-the-day-and-the-curve.md).

## Phase 8 — Events, and What Is Known

The hidden layer, and the long writing campaign that fills it.

Intended issues:

- an event is a hook: local, ordinary, addressed by block, building, house
- an event reaches across an address boundary
- knowledge is the set of events a person holds
- a knowledge filter is a count of held events, and answers nothing where there are none
- one event per block, written before play
- houses fill in forever

Reads: [events and what people know](009-events-and-what-people-know.md).

## The writing campaign, and why it is not a phase

Two thousand block events is one to two months at thirty a day. Twenty to forty
thousand house events is **two to four years** at the same rate. So it is not
scheduled work; it is a thing that runs alongside everything else forever.

The game is playable once the block events exist. A house with no event has
nothing hidden in it, which looks exactly like a city you have not finished
learning.

## Deliberately absent

**The mechanics.** What a move is, what unites a neighbourhood, what holding an
event lets you do, what any button does. Not guessed at. See
[open questions](012-open-questions.md).

**A board that can ship.** The painting is somebody else's and cannot be
published. Almost nothing depends on *this* picture — only on there being one, in
perspective, of a city with streets — so what would be lost is the tracing, and
only the tracing.

**Interior generation.** Text describing a room becoming a room you can look at.
Parked deliberately: it is a second project, plausibly larger than this one, and
it consumes this one's output rather than being part of it. Its one settled
requirement is that a model be built and rendered from several angles rather than
several pictures being generated independently — because independently generated
views of one room do not agree, and renders of one model agree by construction.

**Seasons.** The map changing on its own every few months to a seemingly random
season, with no cycle and no order — a city quietly arbitrary about it, which
rhymes with a game about rigid life. A **2.0 goal**, contingent on an artist.

One constraint recorded now while it is understood: fences are painting-pixel
coordinates, so **every seasonal variant must be the same camera at the same
resolution, pixel-aligned**, or every fence slides off its street the moment the
season turns. Re-rendering one scene makes alignment free; separately generated
images make it very nearly impossible.

**Label collision, fog of war, and a tile pyramid.** All three are problems this
design does not have, absent by construction rather than by oversight — no text
on the map, ignorance drawn as bare painting, and a board small enough for one
texture.

## Related documents

- [Table of contents](table-of-contents.md)
- [Open questions](012-open-questions.md)
- [The shape of the code](010-the-shape-of-the-code.md)
