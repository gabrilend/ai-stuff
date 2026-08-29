# 009 — Roadmap

Six phases. They group functionality, not time — **lower numbers are more
foundational, not earlier**. It would be entirely normal for the last thing
finished in this project to belong to phase 1.

Every phase below is interface. **The mechanics are deliberately absent** and will
form later phases once they exist; see
[what this game is](001-what-this-game-is.md) on why the interface is being
worked out first.

## Phase 1 — The Canvas

One painting on screen, pannable and zoomable, and nothing else. No game in it at
all. It should be runnable as a pure viewer forever after, because a viewer with
no logic in it is the thing you reach for when you cannot tell whether a problem
is in the drawing or in the thinking.

Intended issues:

- the painting is one texture, mipmapped, not tiled
- the view is an offset and a scale, with a floor and a ceiling
- pan and zoom bindings *(blocked — see open question 2)*
- a converted-texture step, so nothing decodes a 25-megapixel PNG at a bad moment
- the window, the two panes, and the seam between them

Reads: [the map surface](002-the-map-surface.md).

## Phase 2 — The Cage

The fence network as a structure, and its appearance over the painting. This is
the phase that decides whether the hand-tracing in phase 3 is worth doing, so it
comes first even though nothing can be traced yet.

Intended issues:

- vertices, edges and blocks as three tables
- junctions and shape points, derived rather than stored
- adjacency is a shared edge, and the walk over it
- the block-identity buffer, and hit-testing as one pixel read
- the fence drawn one pixel wide in screen space
- each block fades on its own on-screen width
- the network validator, and what it refuses

Reads: [the fence network](003-the-fence-network.md).

## Phase 3 — The Tracing Tool

The second program. The instrument for the heroic effort of defining a city by
hand, and the only thing that ever writes a fence network.

Intended issues:

- a separate executable sharing the canvas code
- the click dispatch: new vertex, adopt vertex, adopt edge
- the pointer shows which of the three is about to happen
- snapping measured in screen pixels, and refusing imprecise work
- dragging a junction moves every fence into that corner
- naming a block, and giving it a default filter
- buildings as a positionless list
- a coverage report
- undo *(blocked — see open question 11)*

Reads: [the tracing tool](004-the-tracing-tool.md).

## Phase 4 — Filters and the Weave

Ways of looking at the city, drawn over it. The readings come first and are
checkable with nothing on screen; the hatching comes after.

Intended issues:

- a filter is a name, a colour, an angle, a mode, parameters, and a reading
- a reading of *nothing* is ignorance, and draws as bare painting
- the three modes and the render order
- the weave, resolved by line-index parity
- hatching anchored to painting coordinates, spaced in screen pixels
- the glow, breathing, additive
- the glow flips to aiming at high zoom *(blocked — see open question 10)*
- a block's default filter switches on when it is selected

Reads: [filters and the weave](005-filters-and-the-weave.md).

## Phase 5 — The Tome

The written half. Three regions, and the rule that colour never carries a fact
the words don't.

Intended issues:

- three regions: welded, welded, scrolling
- the chip row, and the focused filter's controls
- a chip carries name and angle, not only colour *(blocked — see open question 6)*
- the icon button pane, with dimming
- the move queue among the buttons, and go *(blocked — see open question 1)*
- the text pane, stylable, black ground and coloured words *(blocked — see open question 5)*
- space to search, and going to a place by name
- searching a building resolves to its block

Reads: [the tome](006-the-tome.md).

## Phase 6 — The Day

Time, and the small horizontal object that lets you sweep through it.

Intended issues:

- the hour as a global axis, above every filter
- the world advances on a move or on go, never on its own
- whereabouts as a function of the hour
- the time-curve, activity plotted, swept by dragging
- sweeping drives the hour and everything that reads it
- hovering and dragging must be distinguishable
- curves are readable only for people you know
- a few pinned, the rest on demand

Reads: [the day and the curve](007-the-day-and-the-curve.md).

## Deliberately absent

**The mechanics.** What a move is, what unites a neighbourhood, what any button
in the tome actually does. Not guessed at. See
[open questions](010-open-questions.md).

**Seasons.** The vision for them is that the map changes on its own every few
months to a seemingly random season — no cycle, no order, just a city that is
quietly arbitrary about it, which rhymes well with a game about rigid life.
Parked as a **2.0 goal**, contingent on an artist wanting to work with us.

One constraint is worth recording now, while it is understood, because it is the
kind of thing discovered far too late: fences are stored as painting pixel
coordinates, so **every seasonal variant must be the same camera at the same
resolution, pixel-aligned**. If a variant is framed even slightly differently,
every fence in the city slides off its street the moment the season turns. That
makes re-rendering one scene the safe production route and separately generated
images the dangerous one.

**Label collision, fog of war, and a tile pyramid.** All three are problems this
design does not have, and it is worth knowing they were considered and are
absent by construction rather than by oversight — no text on the map, ignorance
drawn as bare painting, and a board small enough for one texture.

## Related documents

- [Table of contents](table-of-contents.md)
- [Open questions](010-open-questions.md)
- [The shape of the code](008-the-shape-of-the-code.md)
