# 012 — Open Questions

Every unresolved decision found while turning [the vision](../notes/vision) into
documents. This is not a closing section and it is not decoration. **A phase whose
questions have not been worked through is a phase being built on a guess**, and
the guesses below are labelled as *working rulings* so it is obvious which parts
of the documentation are the vision speaking and which are a gap being filled.

The questions are meant to be gone through one at a time.

**Thirty answered. Seventeen open.** The design is therefore *in progress*, not
finished.

---

# Answered

Kept rather than deleted, with what was rejected, because the road not taken is
worth being able to find again.

| # | Question | Answer | Rejected |
| --- | --- | --- | --- |
| A1 | Where does the map live, and everything else? | A permanent split — map one side, tome the other, neither ever covering the other. | Fullscreen map with floating slabs; a tome that opens over the map. |
| A2 | Painting pixels, or a reconstructed flat ground? | **Pixels only, and the game never claims a distance.** | Fitting a ground plane for honest distances; a per-district eyeballed scale. |
| A3 | What is the smallest clickable thing? | The **block** — later joined by the building below it. | Every building traced; a mix by district. |
| A4 | How is a block traced? | One loop at a time, with vertex and **whole-edge adoption**. | Tracing the street web and deriving faces; doing both. |
| A5 | When is the cage drawn? | Faded per place on its own on-screen width, hover and selection always solid. | Always on; only near the pointer; held on a key. |
| A6 | How does the tome hold its sections? | A welded top, a welded button pane, a scrolling text pane. | A fixed stack; an accordion. |
| A7 | Does the tracing tool share a window with the game? | **Separate program, shared canvas code.** | One program with a mode; separate plus in-game flagging. |
| A8 | How do filters carry a value? | Hatching, woven. The painting is never dimmed or tinted. | Dimming the painting so data glows; the cage thickening to carry it. |
| A9 | How many filters at once? | **Any number**, each with a colour, a turnable angle, and one of three modes. | One at a time; a fixed two. |
| A10 | What does the glow mean? | *This one* — selected, or named by a swept curve. Flips to aiming at high zoom. | Hover only; selection only with no aiming feedback. |
| A11 | Are there labels on the map? | **None. No text of any kind.** Space-then-type reaches a place by name. | Labels above a size threshold; hand-placed district names; tooltips. |
| A12 | Where does the search field appear? | The tome's welded top, taking over the filter controls while typing. | A band over the map's bottom; floating over its centre. |
| A13 | Do houses have positions? | **No.** A positionless list, now inside a building. | A point each, lit on hover; positions for landmarks only. |
| A14 | Does the clock run, and can it be scrubbed? | **The time is only ever now.** Sweeping consults your model; the world advances on a move or on go. | A clock running and scrubbable away from now, which would have needed an unmissable "this isn't real" state. |
| A15 | How many time-curves at once? | A few **pinned**, the rest on demand. | One at a time; a full stack of everyone known. |
| A16 | Where does the move queue live? | Among the **buttons that made it**, with go as one more button. | Its own welded strip; drawn on the map. |
| A17 | Are there seasons? | Deferred to **2.0**, contingent on an artist. | Building them now, by any of the three production routes. |
| A18 | Whose knowledge does a filter show? | **The person you are playing.** A reading is (person, place) → a number or nothing, and switching person repaints the map. | Knowledge belonging to the city or to the player across all characters; a split where physical facts are shared and social ones are not. |
| A19 | How do you reach a house? | Block on the map, then building, house and person as lists in the tome. | Traced building footprints; reachable only by search. |
| A20 | What decides which level a click selects? | **The zoom**, reusing the same on-screen-size rule that fades the cage. | A level control in the tome; one level per successive click. |
| A21 | What is above a quadrant? | **A group** — the city, or one megastructure — and groups have no parent. Four quadrants to a group; none at all beyond the wall. | A single root containing everything; a flat list of quadrants with nothing above them. |
| A22 | What must be written before the game is played? | **Every block's event.** Houses fill in forever. | Every house first, at two to four years; seeding houses from written patterns. |
| A23 | What is the third address level? | A **house** — an apartment inside a shared building, three to five rooms. | A room inside a house; only two indexed levels with the rest as prose. |
| A24 | What governs going in? | Buildings are **rarely closed**; houses **almost always restricted**. Someone lives there. | A rule per building; size deciding it; a rule per block that buildings inherit. |
| A25 | How do a building's own facts get written? | **Fill in forever**, like house events. | A few short fields for every building up front; only where an event points. |
| A26 | What extent does a building get? | A **rough hand-placed zone** over each roof. | A point each with nearest-wins; real traced footprints. |
| A27 | Where does an interior appear? | **All three placements valid**, with the tome's scrolling pane preferred. | Picking only one. |
| A28 | How does text become a room? | **Parked.** A separate project consuming this one's output. | Procedural now; a model that generates geometry from text now. |
| A29 | Which image is the board? | **The painting**, with a flat top-down view wanted eventually that must register with it exactly. | The flat map as the board; treating both as reference with the board drawn later. |
| A30 | Are the pictures ours? | **No.** Reference only — see [the notice](../inspiration-pictures/NOTICE.md). The board is a stand-in and cannot ship. | Treating them as project assets. |

Four of these carry consequences worth spelling out.

**A2 and A3 together turn the city into a graph rather than a field.** Pixels-only
would normally leave you unable to say two things are near each other; choosing
blocks rescues it, because a hand-traced polygon already has the painting's
perspective baked into its shape. What is lost is the circle — no radius, ever.
What is gained is adjacency, where influence travels a block at a time along the
streets and a rampart genuinely stops it.

**A14 dissolved a problem rather than solving it.** A scrubbable clock would have
meant the screen could show a moment that isn't now, making every reading a
hypothetical that had to be marked or become quietly untrustworthy. "The time is
only ever now" removes the state entirely — and in doing so revealed the idea the
whole project rests on: the map was never a camera.

**A18 was free, and nobody planned it.** Character switching needed one extra
parameter on a function that already existed, because the map was always
somebody's model rather than the city itself. The most valuable thing in the
design cost a single argument.

**A22 is the only version that ships.** Two thousand block events is a couple of
months. Twenty to forty thousand house events is two to four years. Writing
everything first would mean nobody plays for years, including the author.

---

# Group A — Hands on the map

## 1. What are the pan and zoom bindings?

**Working ruling:** drag to pan, wheel to zoom about the pointer, clamped between
fitting the pane and native pixels.

**Why it matters:** space is taken by the search, and the tracing tool needs the
same gestures for a different job — a drag there might mean moving a vertex. The
two programs must not disagree about what a drag is.

**Changes:** [the map surface](002-the-map-surface.md), [the tracing tool](005-the-tracing-tool.md), phase 1.

## 2. What happens when you click undefined ground?

Most of the painting is unfenced for a long time and some forever — mountains,
fields, sea, the foreground ridge. It reads as zero in the identity buffer.

**Working ruling:** the click deselects, and nothing glows.

**Why it matters:** the alternative — bare ground doing nothing, so the current
selection survives — feels different in the hand, and decides whether the far
countryside is *outside the game* or merely *not yet traced*.

**Changes:** [the fence network](004-the-fence-network.md), phase 2.

## 3. What tunable flips the glow from selection to aiming?

**Working ruling:** count places entirely within the view; flip at one. The
player can switch the behaviour off.

**Why it matters:** "entirely within the view" is cheap but jumpy, changing on a
single pixel of pan. This needs feeling rather than reasoning, so it may wait for
something runnable.

**Changes:** [the map surface](002-the-map-surface.md), phase 5.

---

# Group B — The tome

## 4. Does queue order need to be visible, and how?

Queued moves show on the button that produced them, but a queue is a sequence and
fixed buttons have no order.

**Working ruling:** a count badge per button, order not shown.

**Why it matters:** if order matters to play, this is wrong and the queue needs
somewhere with a sequence in it. **This is a mechanics question wearing an
interface question's clothes** and should be answered from that side.

**Changes:** [the tome](007-the-tome.md), phase 6.

## 5. What do the text pane's colours signify?

Colours must be redundant with the words. What categories exist at all — people,
places, times, promises, warnings?

**Working ruling:** none. This wants the mechanics first.

**Why it matters:** it is the only styling decision that is not cosmetic, because
the categories are a claim about what kinds of thing exist in this game.

**Changes:** [the tome](007-the-tome.md), phase 6.

## 6. How does a filter chip stay legible at chip size?

A chip must carry name, hatch angle and colour — three redundant channels — small
enough that twelve fit in a row or two.

**Working ruling:** a small square showing the filter's own hatching at its own
angle in its own colour, with the name beside it, truncated.

**Changes:** [the tome](007-the-tome.md), [filters](006-filters-and-the-weave.md), phase 6.

## 7. Do the icon buttons carry words, and where?

**Working ruling:** icons only, with the name and effect appearing in the text
pane on hover.

**Why it matters:** an icon nobody can read is as exclusionary as a colour nobody
can distinguish, and a dimmed button must say *why*, which no icon does alone.

**Changes:** [the tome](007-the-tome.md), phase 6.

## 8. How do you change a place's default filter?

**Working ruling:** a button that sets the current filter as this place's default.

**Why it matters:** overruling a place's own lens is a small act of insight and
arguably worth the game noticing. Whether it does is design, not plumbing.

**Changes:** [filters](006-filters-and-the-weave.md), [the tome](007-the-tome.md), phase 5.

---

# Group C — The tracing effort

## 9. Where does the coverage readout live?

**Working ruling:** the tracing tool only.

**Why it matters:** if the game shows it, *how much of the city has been defined*
becomes something the player sees — which for a game about coming to know a city
might be a feature.

**Changes:** [the tracing tool](005-the-tracing-tool.md), phase 3.

## 10. Does the tracing tool need undo, and how deep?

**Working ruling:** yes, unlimited within a session; the alternative during hours
of tracing is retracing.

**Why it matters:** undo over a shared-vertex network is not a stack of
independent edits — dragging one junction touched every edge into that corner, and
undoing must restore all of them. That decides how the network is held in memory.

**Changes:** [the tracing tool](005-the-tracing-tool.md), [the fence network](004-the-fence-network.md), phase 3.

---

# Group D — The places

## 11. Which structures are megastructures?

Read off the painting and **unconfirmed**: the amphitheatre on the west bank, the
ringed colonnade on the east, the domed rotunda on the promontory, the smaller
western dome, and the great willow.

**Why it matters:** each one adds four quadrants and its own group, so this sets
the size of the top of the hierarchy. It also decides whether a tree can be a
group, which is a question about what a megastructure *is*.

**Changes:** [the places of the city](003-the-places-of-the-city.md), phase 4.

## 12. How many districts, and who decides their bounds?

Their outlines are derived from membership, so the only real question is how many
there are and which blocks go in which.

**Working ruling:** unknown; the flat view letters about twenty.

**Changes:** [the places of the city](003-the-places-of-the-city.md), phase 4.

## 13. Are the life paths chosen once, or moved between?

Family, trades, martial, learned — as many lives as there are districts.

**Why it matters:** in a game whose subject is a city that tells you which life to
choose, whether you may change your mind is close to the whole point.

**Changes:** [the places of the city](003-the-places-of-the-city.md), mechanics.

---

# Group E — The board

## 14. What ground plane makes the flat view register?

A flat top-down view is wanted eventually and must land on the painting exactly.
Two independently drawn pictures cannot register, so the flat view has to be
**derived** — which needs a fitted ground plane the project declined in A2.

**Working ruling:** none. The fences stay in painting pixels for now; the plane is
a cost that arrives with the flat view, not before.

**Why it matters:** it is the one place where the pixels-only decision has a
price, and knowing the price early is better than discovering it.

**Changes:** [the map surface](002-the-map-surface.md), a later phase.

## 15. Where do the shade filter's numbers live?

Shadow at a given hour needs the sun's path across this city's sky and the great
willow's height. Neither is measurable; both must be invented and held to.

**Working ruling:** a small table in `assets/`, since these are facts about *this
city* rather than about the program — and unlike the painting they are ours.

**Why it matters:** it sets a precedent for every filter that computes rather than
looks up. It also raises whether the painting's own light should be measured, since
a shade filter disagreeing with the painting's shadows would look wrong in a way
nobody could name.

**Changes:** [filters](006-filters-and-the-weave.md), phase 5.

---

# Group F — Mechanics, deliberately not guessed

## 16. What does holding an event let you do?

Knowledge is the set of events a person holds. What holding one *affords* — acting
on it, using it, trading it — is undecided.

**Changes:** [events](009-events-and-what-people-know.md), a later phase.

## 17. How does an event pass from one person to another?

The vision says people who know a fact "keep track of it and incorporate it going
forward". Whether telling somebody costs anything, whether it can be wrong, and
whether it can be lost, are all open.

**Why it matters:** it is the mechanism by which a city gets united, which is the
premise. Everything else in the design is the instrument that would show it.

**Changes:** [events](009-events-and-what-people-know.md), a later phase.

---

# Not questions — problems this design does not have

Worth recording so nobody solves them by accident:

- **Label collision.** There is no text on the map.
- **Fog of war.** Ignorance is a filter answering *nothing*, which is a person
  holding no events there. Nothing to build.
- **A tile pyramid.** The board is one texture.
- **Now versus then.** The time is only ever now.
- **Perspective correction.** Hand-traced fences carry the foreshortening for
  free, and the game never claims a distance.
- **A district-boundary editor.** Districts and quadrants are outlined from
  membership; there is nothing to draw.
