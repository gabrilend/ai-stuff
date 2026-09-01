# 012 — Open Questions

Every unresolved decision found while turning [the vision](../notes/vision) into
documents. This is not a closing section and it is not decoration. **A phase whose
questions have not been worked through is a phase being built on a guess**, and
the guesses below are labelled as *working rulings* so it is obvious which parts
of the documentation are the vision speaking and which are a gap being filled.

The questions are meant to be gone through one at a time.

**Forty-three answered. Eleven open.** The design is therefore *in progress*, not
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
| A4 | How is a block traced? | **Superseded by A38.** It is not traced — the city is subdivided and blocks are faces of the street graph. | The original answer, one loop at a time with whole-edge adoption. |
| A5 | When is the cage drawn? | Faded per place on its own on-screen width, hover and selection always solid. | Always on; only near the pointer; held on a key. |
| A6 | How does the tome hold its sections? | A welded top, a welded button pane, a scrolling text pane. | A fixed stack; an accordion. |
| A7 | Does the editor share a window with the game? | **Reversed by A39.** It is a mode inside the game, so that maps are mods players can make. | The original answer, a separate program. |
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
| A31 | What are the pan and zoom bindings? | **Middle drag pans, wheel zooms.** Left click selects and explains; right click modifies. Deliberately inverted from convention. | Left-drag panning; a modifier held to pan; conventional left-to-press buttons. |
| A32 | Do the icon buttons carry words, and where? | **Left-clicking one explains it**, including why a dimmed one cannot be used. Falls out of the two-hand scheme rather than needing its own mechanism. | Hover text; permanent labels beside icons. |
| A33 | Does zoom stop at native pixels? | **No — past native is allowed in both programs and looks like honest blur.** | Stopping at native; stopping in the game but not the tool. |
| A34 | What fills the tome pane before the tome exists? | **Nothing.** An empty panel until phase 6, so the proportions are real from the start. | Debug readouts; giving the map the whole window until phase 6. |
| A35 | What happens on ground with no identity? | **The click is ignored and the selection stays.** Input not on the map cannot affect the selection of things in the map. | Deselecting; selecting the countryside as a thing. |
| A36 | Where does the fence line run across a street? | **Down the centre**, each block owning its half. So there is **no street object** — a lane is where two blocks meet. | Along a kerb, which breaks the shared edge; making streets places of their own. |
| A37 | How brightly is a shared edge drawn? | **One pixel means one colour for all lines.** Nothing varies, so nothing arbitrates. Only *which* level is drawn varies. | Larger place wins; smaller wins; fade on the edge's own length; stroking twice. |
| A38 | How is the city defined? | **By subdivision.** It starts whole and gets cut up; coverage is always complete and blocks are faces of the graph. | Tracing each block's closed loop; a mix of both. |
| A39 | Where does the editor live? | **A mode inside the game**, deliberately entered — so a map is a mod players can make. | A separate developer program (the previous answer). |
| A40 | How precisely must the fence follow a street's centre? | **Anywhere in the road.** What matters is that buildings sit clearly on one side, and at the zooms where the cage is looked at a wobble is invisible. | A two-click midpoint helper; straight runs between corners. |
| A41 | How is undo built? | **From inverses**, with a mandatory round-trip test per action so a wrong inverse fails the build rather than somebody's work. | Keeping copies of what changed; no undo at all. |
| A42 | Does the game show how much of the city is defined? | **No — the tracing mode only.** Coverage is always complete, so any figure would be an artefact of authoring rather than a fact about the world. | Showing it in the game as something the character could know. |
| A43 | What is a map, as a distributable thing? | **A bundle** — picture, partition, names and a notice, together. | A partition referencing a picture it does not carry; deciding later. |

Five of these carry consequences worth spelling out.

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

**A31 and A32 turned rudeness into an answer.** The two hands — left asks, right
acts — were chosen as a deliberate refusal of the muscle memory a person arrives
with. They then solved a problem the design already had and had not solved: the
colour rule demands a dimmed control say more than "no", and an icon alone
cannot. The enquiry hand works on controls the action hand refuses, so a greyed
button explains itself. A stance taken for its own sake paid for something else.

**A22 is the only version that ships.** Two thousand block events is a couple of
months. Twenty to forty thousand house events is two to four years. Writing
everything first would mean nobody plays for years, including the author.

---

# Group A — Hands on the map

## 1. What are the pan and zoom bindings? — **ANSWERED, see A31**

**Middle drag pans, wheel zooms about the pointer. Left click selects and
explains; right click modifies.**

Play and the tracing mode agree because panning is the middle button in both —
the editing gestures are the left and right buttons with modifiers. The conflict
this question was raised about does not arise.

The inversion of left and right is deliberate rudeness, taken as a stance rather
than arrived at: the interface asks to be learned rather than guessed. It also
answered question 7 as a side effect.

Zoom is clamped below at the pane fit and **not clamped above** — see A33.

## 2. What happens when you click undefined ground? — **ANSWERED, see A35 and A38**

**There is no undefined ground.** The city is subdivided rather than filled in, so
coverage is always complete and every pixel of the painting belongs to some
place, however coarsely that part is still divided.

The question was asked of a design that has since been replaced, and the
replacement removed its subject rather than answering it.

What survives is the case of pixels that are genuinely **not the map**: the
letterbox above and below the painting at the fit zoom. There, the click is
ignored and the selection stays, under one sentence — *input that is not on the
map cannot affect the selection of things in the map.*

A consequence either way: there is no deselecting by clicking away. Selecting
something else is how you stop looking at a thing, and the tome always has
something in it.

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

## 7. Do the icon buttons carry words, and where? — **ANSWERED, see A32**

**Left-clicking a button explains it**, including why a dimmed one cannot be used
here.

This was not designed for; it fell out of the two-hand scheme in A31. The colour
rule demands that a dimmed control say more than "no", and an icon alone cannot.
Because the enquiry hand works on controls the action hand refuses, a greyed
button is never a dead end.

It follows that **nothing may be pressable by the hand that asks about it.**
Anything acting on left click has broken the scheme, and the scheme is what makes
every dimmed thing legible.

## 8. How do you change a place's default filter?

**Working ruling:** a button that sets the current filter as this place's default.

**Why it matters:** overruling a place's own lens is a small act of insight and
arguably worth the game noticing. Whether it does is design, not plumbing.

**Changes:** [filters](006-filters-and-the-weave.md), [the tome](007-the-tome.md), phase 5.

---

# Group C — The tracing effort

## 9. Where does the coverage readout live? — **ANSWERED, see A42**

**The tracing mode only.**

The question was reframed by a larger answer: **coverage is always one hundred
percent.** The city is subdivided rather than filled in, so there is no such thing
as undefined ground and nothing for a player to be told about how complete the
map is.

What the report measures instead is how *finely* the city is divided and how well
it is named — facts about the authoring rather than about the world, and
therefore not the player's business.

## 10. Does the editor need undo, and how deep? — **ANSWERED, see A41**

**Yes, unlimited within a session, built from inverses.**

Two of the four hard cases stopped existing when the model became subdivision:
**cutting and severing are exact inverses of each other**, so the two commonest
actions come with their reversals already written. Dragging a vertex was always
easy.

What is still hard is merging two vertices, which rewrites an unknown number of
edge paths and whose inverse must record them explicitly rather than derive them.

Inverses are smaller and faster than keeping copies, and carry one failure mode
copies do not: a wrong inverse only shows up **after** somebody presses undo. So
the answer comes with a condition rather than alone:

> **Every action has a test that performs it, undoes it, and asserts the network
> is byte-identical to before.**

That turns *hope every inverse is right* into *the build fails if one is not*.

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
