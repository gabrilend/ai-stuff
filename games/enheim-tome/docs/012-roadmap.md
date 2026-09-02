# 012 — Roadmap

Nine phases. They group functionality, not time — **lower numbers are more
foundational, not earlier**. It would be entirely normal for the last thing
finished in this project to belong to phase 1.

Phases 1 to 7 are interface and world. Phases 8 and 9 are the mechanics that move
them, worked out after the interface rather than before it; see
[what this game is](001-what-this-game-is.md) on why that order was chosen and
what it paid for.

## Phase 1 — The Canvas

One painting on screen, pannable and zoomable, and nothing else. No game in it at
all. It should stay runnable as a pure viewer forever after, because a viewer
with no logic in it is what you reach for when you cannot tell whether a problem
is in the drawing or in the thinking.

Intended issues:

- the painting is one texture, mipmapped, not tiled
- the view is an offset and a scale, with a floor and a ceiling
- pan and zoom bindings *(settled — the tracing mode uses the same panning)*
- a converted-texture step, so nothing decodes a 25-megapixel image at a bad moment
- the window, the two panes, and the seam between them

Reads: [the map surface](002-the-map-surface.md).

## Phase 2 — The Cage

The fence network as a structure and as an appearance. This decides whether the
partitioning in phase 3 is worth doing, so it comes first even though nothing can
be cut yet.

Intended issues:

- vertices, edges and places as tables; **faces derived, never stored**
- blocks are faces of a planar graph, found by the angular walk
- junctions and shape points, derived rather than stored
- adjacency is a shared edge, **true by construction**
- the identity buffer, and hit-testing as one pixel read
- the fence drawn one pixel wide in screen space
- the cage shows one level at a time, and swaps as you descend
- the validator, reduced to what the structure cannot guarantee

Reads: [the fence network](004-the-fence-network.md).

## Phase 3 — The Tracing Mode

**A mode inside the game**, so that a map is a thing players can make. The city
starts whole and gets cut up.

Intended issues:

- the tracing mode, and the discipline replacing the two-program guarantee
- cutting and severing, which are exact inverses
- the pointer shows what is about to happen
- snapping measured in screen pixels, and refusing imprecise work
- dragging a junction moves every fence into that corner
- naming a place, naming an intersection
- placing a building's rough zone
- assigning district and quadrant membership
- the coverage report, which measures fineness rather than coverage
- undo built from inverses, with a round-trip test per action
- autosave to the RAM tier
- a map is a bundle: picture, partition, names, and a notice

Reads: [the tracing mode](005-the-tracing-mode.md).

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
- the cage cross-fades between levels, with hysteresis so it cannot strobe

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

## Phase 8 — The Scaffold

The layer that makes the city move: gatherings, the two statuses, and the axes
minted when things are mixed.

Issues, written and numbered from 807 because 801 to 806 describe a replaced
design and are kept under their own names &mdash; see
[phase 8 progress](../issues/phase-8-progress.md):

- **807** an actor is a person or a place, carrying a character and a status
- **808** character is a sparse map of named axes, minted rather than declared
- **809** a place holds a natural character it never loses
- **810** open and closed, read off a line across the activity curve
- **811** the gathering: every actor present at one share of N+1, the room included
- **812** the closed give, the open adopt the blend
- **813** two closed actors with intent make an arc, and the arc lands somewhere
- **814** an arc carries a valence, and a valence changes who nearby is open
- **815** forcing a closed thing open, and the axis that comes out of it
- **816** an axis is a filter, so a minted axis needs a colour and an angle

Reads: [the scaffold](009-the-scaffold.md).

## Phase 9 — The Scene

The narrative half. Axis interactions become a scene record, and the record is
rendered into words by something that decides nothing.

Issues:

- **901** an interaction is one axis across the actors present, typed five ways
- **902** a scene record: hour, place, actors, interactions, spark, and what changed
- **903** what changed is computed before the narrator is asked
- **904** a scene exists only where something changed
- **905** history is append-only: axis changes, narrations, mintings
- **906** a fact is public or private, and the marking gates both a narration and a filter
- **907** the narrator is a viewer, and the city runs headless without it
- **908** the narrator thinks with everything and narrates with public plus known
- **909** the narration phase runs against a context that never held the private facts
- **910** naming a minted axis is the one place words touch the world
- **911** a narration lands in the tome's text pane and nowhere else
- **912** a missing narrator fails loudly and shows the record

Reads: [the scene](010-the-scene.md).

## The writing campaign that no longer exists

Kept as a heading because deleting it silently would hide the largest single
change this project has made to itself.

The previous plan required two thousand written block facts — one to two months at
thirty a day — followed by twenty to forty thousand house facts, priced in its own
document at **two to four years** at the same rate. It called that the only
version that ever ships.

**None of it is needed.** Nothing is authored. Character is computed from where
people are and what they are like, and the axes that describe a place are minted
at the moment of mixing rather than written in advance. What was a four-year
authoring schedule is now a function.

What remains authored is the tracing, which was always separate: the fence
network, the building zones, and the names. See
[the tracing mode](005-the-tracing-mode.md).

## Deliberately absent

**Some of the mechanics.** What a **move** is, and what any particular button in
the tome does. What an event is and how character travels are no longer absent —
see [the scaffold](009-the-scaffold.md). See also
[open questions](013-open-questions.md).

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
- [Open questions](013-open-questions.md)
- [The shape of the code](011-the-shape-of-the-code.md)
