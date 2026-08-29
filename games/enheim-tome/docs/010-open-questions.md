# 010 — Open Questions

Every unresolved decision found while turning [the vision](../notes/vision) into
documents. This is not a closing section and it is not decoration. **A phase whose
questions have not been worked through is a phase being built on a guess**, and
the guesses below are labelled as *working rulings* so it is obvious which parts
of the documentation are the vision speaking and which parts are a gap being
filled.

The questions are meant to be gone through one at a time.

**Twelve open.** The interface design is therefore *in progress*, not finished.

---

# Answered

Kept rather than deleted, with what was rejected, because the road not taken is
worth being able to find again.

| # | Question | Answer | Rejected |
| --- | --- | --- | --- |
| A1 | Where does the map live, and where does everything else? | A permanent split — map on one side, tome on the other, neither ever covering the other. | Map fullscreen with floating slabs; map with the tome opening over it. |
| A2 | Painting pixels, or a reconstructed flat ground? | **Pixels only, and the game never claims a distance.** | Fitting a ground plane so distances become honest; a per-district eyeballed scale. |
| A3 | What is the smallest clickable thing? | The **block**. Buildings live inside it as a list. | Every building traced; a mix of both by district. |
| A4 | How is a block traced? | One loop at a time, with vertex and **whole-edge adoption**. | Tracing the street web and deriving faces; doing both. |
| A5 | When is the cage drawn? | Faded per block on its own on-screen width, with hover and selection always solid. | Always on; only near the pointer; held on a key. |
| A6 | How does the tome hold its sections? | A welded top, then a welded button pane, then a scrolling text pane. | A fixed stack; an accordion. |
| A7 | Does the tracing tool share a window with the game? | **Separate program, shared canvas code.** | One program with a mode; separate plus in-game flagging. |
| A8 | How do overlays carry a value? | Hatching, woven. The painting is never dimmed and never tinted. | Dimming the painting so data glows; the cage thickening to carry the value. |
| A9 | How many filters at once? | **Any number**, each with a colour, a turnable angle, and one of three stacking modes. | One at a time; a fixed two. |
| A10 | What does the glow mean? | *This one* — the selected block, or the block a swept curve names. Flips to aiming at high zoom. | Hover only; selection only, with no aiming feedback. |
| A11 | Are there labels on the map? | **None. No text of any kind.** Space-then-type goes to a place by name. | Labels above a size threshold; hand-placed district names; hover tooltips. |
| A12 | Where does the search field appear? | The tome's welded top, taking over the filter controls while you type. | A band across the map's bottom; floating over the map's centre. |
| A13 | Do buildings have positions? | **No.** A positionless list inside a block. | A point each, lit on hover; positions for landmarks only. |
| A14 | Does the clock run, and can it be scrubbed? | **The time is only ever now.** Sweeping consults your model; the world advances on a move or on go. | A clock that runs and can be scrubbed away from now — which would have needed an unmissable "this isn't real" state. |
| A15 | How many time-curves at once? | A few **pinned**, the rest on demand. | One at a time; a full stack of everyone known. |
| A16 | Where does the move queue live? | Among the **buttons that made it**, with go as one more button. | Its own welded strip; drawn on the map. |
| A17 | Are there seasons? | Deferred to **2.0**, contingent on an artist. | Building them now, in any of the three production routes. |

Two of these deserve their consequences spelled out, because they carry the
design.

**A2 and A3 together turn the city into a graph rather than a field.** Pixels-only
would normally leave you unable to say two things are near each other; choosing
blocks rescues it, because a hand-traced polygon already has the painting's
perspective baked into its shape. What is lost is the circle — no radius, ever.
What is gained is adjacency, where influence travels a block at a time along the
streets and a rampart genuinely stops it. For a game about uniting a city that is
the better model.

**A14 dissolved a problem rather than solving it.** A scrubbable clock would have
meant the screen could show a moment that isn't now, making every reading on it a
hypothetical that had to be marked as such or become quietly untrustworthy.
"The time is only ever now" removes the state entirely, and in doing so revealed
the idea the whole project rests on: the map was never a camera, it is your model
of the city.

---

# Group A — Hands on the map

## 1. What are the pan and zoom bindings?

**Working ruling:** drag to pan, wheel to zoom about the pointer, with the zoom
clamped between fitting the pane and native pixels.

**Why it matters:** space is already taken by the search, and the tracing tool
needs the same gestures for a different job — dragging there might mean moving a
vertex rather than moving the map. The two programs should not disagree about
what a drag is.

**Changes:** [the map surface](002-the-map-surface.md), [the tracing tool](004-the-tracing-tool.md), phase 1.

## 2. What happens when you click untraced ground?

Most of the painting will be unfenced for a long time and some of it forever —
the mountains, the fields, the sea, the foreground ridge. It reads as identity
zero in the block-identity buffer.

**Working ruling:** the click deselects, and nothing glows.

**Why it matters:** the alternative — clicks on bare ground doing nothing at all,
so the current selection survives — is defensible and feels different in the
hand. It also decides whether the far countryside is *outside the game* or merely
*not yet traced*, which is a statement about how big the city is allowed to get.

**Changes:** [the fence network](003-the-fence-network.md), phase 2.

## 3. What is the tunable that flips the glow from selection to aiming?

At high zoom, when the selected block is the only one fully on screen, marking it
is pointless and the glow becomes an aiming aid instead.

**Working ruling:** count blocks entirely within the view; flip when that count
reaches one. The player can switch the behaviour off.

**Why it matters:** "entirely within the view" is cheap but jumpy — it changes on
a single pixel of pan. A zoom threshold would be smoother and less correct. This
needs to be felt rather than reasoned about, so it may have to wait for something
runnable.

**Changes:** [the map surface](002-the-map-surface.md), phase 4.

---

# Group B — The tome

## 4. Does queue order need to be visible, and how?

Queued moves show on the button that produced them. But a queue is a sequence and
buttons in fixed positions have no order, so the pane can show that one button
has two moves pending and another has one, but not which happens first.

**Working ruling:** a small count badge per button, with order not shown.

**Why it matters:** if order matters to play at all, this is wrong and the queue
needs somewhere with a sequence in it. If order does not matter — if a queue is a
set of intentions resolved by the world rather than a program — then the badge is
right and simple. **This is really a mechanics question wearing an interface
question's clothes**, and it should be answered from that side.

**Changes:** [the tome](006-the-tome.md), phase 5.

## 5. Do the icon buttons carry words, and where?

**Working ruling:** icons only in the pane, with the name and what it does
appearing in the text pane below on hover.

**Why it matters:** [the rule about colour](001-what-this-game-is.md) has a
sibling problem here — an icon nobody can read is as exclusionary as a colour
nobody can distinguish, and a dimmed button in particular must say *why* it is
dimmed, which no icon can do alone.

**Changes:** [the tome](006-the-tome.md), phase 5.

## 6. What do the text pane's colours signify?

The colours must be redundant with the words — never carrying a fact the text
does not also state. That leaves the question of what categories exist at all:
people, places, times, promises, warnings?

**Working ruling:** none. This wants the mechanics first.

**Why it matters:** it is the only styling decision that is not purely cosmetic,
because the categories are a claim about what kinds of thing exist in this game.

**Changes:** [the tome](006-the-tome.md), phase 5.

## 7. How does a filter chip stay legible at chip size?

A chip must carry name, hatch angle and colour — three redundant channels — in
something small enough that twelve of them fit in one or two rows.

**Working ruling:** a small square showing the filter's actual hatching at its
actual angle in its actual colour, with the name beside it, truncated.

**Why it matters:** if a chip cannot carry all three, either the colour rule
bends here or the chip row stops being compact, and both are worse than finding a
form that works.

**Changes:** [the tome](006-the-tome.md), [filters and the weave](005-filters-and-the-weave.md), phase 5.

## 8. How do you change a block's default filter?

Every block names the filter that switches on when it is selected, overridable
"in the interface for that spot."

**Working ruling:** a button in the pane that sets the current filter as this
block's default.

**Why it matters:** overruling a place's own lens is a small act of insight and
arguably worth recording rather than just doing. Whether the game notices you did
it is a design question, not a plumbing one.

**Changes:** [filters and the weave](005-filters-and-the-weave.md), [the tome](006-the-tome.md), phase 4.

---

# Group C — The tracing effort

## 9. Where does the coverage readout live?

Blocks traced, blocks named, fraction of the painting fenced.

**Working ruling:** in the tracing tool only.

**Why it matters:** if the game shows it too, then *how much of the city has been
defined* becomes something the player sees — which for a game about coming to
know a city might be a feature rather than a leak, and might not.

**Changes:** [the tracing tool](004-the-tracing-tool.md), phase 3.

## 10. Does the tracing tool need undo, and how deep?

**Working ruling:** yes, unlimited within a session, because the alternative
during hours of tracing is retracing.

**Why it matters:** undo over a shared-vertex network is not a stack of
independent edits — dragging one junction touched every edge into that corner, and
undoing it must restore all of them. That is real work and it decides how the
network is stored in memory.

**Changes:** [the tracing tool](004-the-tracing-tool.md), [the fence network](003-the-fence-network.md), phase 3.

---

# Group D — Filters that need invented facts

## 11. Where do the shade filter's numbers live?

Shadow at a given hour needs the sun's path across this city's sky and the great
tree's height. Neither is measurable from the painting; both must be invented and
then held to consistently.

**Working ruling:** a small table in `assets/`, since these are facts about *this
city* rather than about the program — and unlike the painting they are ours,
which is exactly why they belong there and it does not.

**Why it matters:** it sets a precedent for every filter that computes rather than
looks up. It also raises whether the light in the painting should be measured —
the shadows there fall consistently enough to derive a sun direction, and a
shade filter that disagreed with the painting's own shadows would look wrong in a
way nobody could name.

**Changes:** [filters and the weave](005-filters-and-the-weave.md), phase 4.

---

# Group E — Deferred

## 12. How would seasonal paintings be produced? — **2.0**

The map changing on its own every few months to a seemingly random season, with
no cycle and no order.

**Blocked on an artist.** Recorded now because the constraint is understood now:
fences are painting-pixel coordinates, so **every variant must be the same camera
at the same resolution, pixel-aligned**, or every fence in the city slides off its
street the moment the season turns. Re-rendering one scene makes alignment free;
separately generated images make it very nearly impossible.

A third route needs no artist at all — deriving seasons from the one painting
with a snow pass and a colour shift — at the cost of a golden tree that can never
go bare.

**Changes:** [the map surface](002-the-map-surface.md), [roadmap](009-roadmap.md).

---

# Not questions — problems this design does not have

Worth recording so nobody solves them by accident:

- **Label collision.** There is no text on the map.
- **Fog of war.** Ignorance is a filter answering *nothing*, and draws as bare
  painting. There is no system to build.
- **A tile pyramid.** The board is one texture.
- **Now versus then.** The time is only ever now.
- **Perspective correction.** Hand-traced fences carry the foreshortening for
  free, and the game never claims a distance.
