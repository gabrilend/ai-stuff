<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10,
     from notes/vision, so every other document and every conversation can
     share one vocabulary. Update it whenever a term is added or changes. -->

# Core terms

The agreed words for this project. Every other document, every issue, every
comment in source uses these words for these things. When a new thing appears,
it gets a word here first.

## The shape of the world

- **hub** — your base. It sits at the exact center of your screen, always.
  The map is drawn around it, outward. The command wheel sits on top of it.
- **team** — the players who share one hub. A team of 4 means it took four
  people to run a realm this large.
- **quadrant** — the slice of the circle one team member is responsible for.
  With 4 players each quadrant is a quarter turn (90 degrees); with 3 it is a
  third; with 1 it is the whole circle. (The word is kept even when there are
  not four slices.)
- **direction** — a compass bearing out from the hub. Each direction has one
  **foe**: the opposing player who lives out that way.
- **tier** — a ring around the hub. Tier 1 is the nearest ring of foes, tier 2
  the next ring out, and so on. Moving "center to outer" means beating tier 1
  in a direction to reach tier 2 in that same direction.
- **front** — the place in one direction where your forces meet that
  direction's foe at the current tier.
- **flank** — movement sideways around the circle (changing angle, keeping
  distance), as opposed to outward (changing distance). A **flanking force**
  is a group sent side to side, usually to help a neighbouring quadrant.
- **tier-time** — the map is not to scale. Every tier band takes roughly the
  same time to cross, no matter how wide it would be in real distance. That is
  why far-off forces appear to move faster: they are crossing bigger bands in
  the same time.
- **underworld** — the inside face of the sphere the map lies on. The surface
  is one realm; the underworld is the other, where (in the w7 prehistory)
  the monsters were pushed and now hold their own realm.

## The view

- **sphere projection** — the map is a grid on a sphere, hub at one pole,
  tiers as bands of latitude. The screen shows it flattened into a circle
  around the dashboard, inner tiers wide, outer tiers folded toward the edge
  like an accordion closing.
- **merged stand** — units far away or crowded together drawn as one marker
  carrying two numbers: **average level** and **count**.
- **balance color** — the merged marker's color, showing how its strength
  compares to the threat it is contesting.
- **differential triangles** — small triangles beside a marker carrying the
  same information as the balance color by shape (up = ahead, down = behind,
  more triangles = larger difference), for colorblind players.

## The dashboard

- **console** — the large shape in the middle of the screen, over the hub:
  an **arch**, one hump of an M.
- **band** — the arch's curved strip, foot to foot: gold-edged glass that is
  the map's display (the map is seen through it). Never clicked.
- **dashboard** (or dashboard surface) — the metal beneath the band and above
  the base, where the buttons and dials are.
- **section** — one ally's arch. With allies the console is a row of arches
  sharing feet (an M with a hump each); each player sees their own section
  whole and the neighbours' feet. More allies make the M longer, never a
  section smaller.
- **arch units** — positions on the dashboard written as distance across
  from the arch's center and up from its base, as shares of the arch's
  height.
- **button** — bright, colorful, round or half-round, and always pressable.
  The only clickable things on the dashboard. Every button is an order verb
  (plus the calendar's day/month switch).
- **dial** — the generic information component: a disc no thicker than
  paper, inscribed with words or numbers, turning beneath a seamless glass
  window cut into the dashboard. Only the part under the window is ever seen.
  The game turns dials; the player never does.
- **nested dial** — a dial seen through a window in another dial's surface,
  one level lower (the calendar's day number below its weekday).
- **calendar** — the game's clock, shown on dials: month, weekday, and one
  level lower, the day number. Its pace (day or month) is switched with a
  button. Votes, among other things, happen on its boundaries.
- **readout** — a dial showing a number. Never painted, never clickable.

## Commanding

- **figure** — how a unit is drawn: six spheroids (body, head, two arms, two
  legs) placed by the **body plan**. Its limbs **bend**: points are pushed by
  an amount growing with the square of their distance from the shoulder or
  hip, so limbs deform rather than swing rigidly.
- **walking phase** — a number each unit carries, turned by the move box in
  proportion to how fast the unit goes over the ground; the bend formula
  reads it. The shape is never rebuilt, only the formula's input changes.
- **cuboid** — a small rounded cube (the unit sphere pushed toward a cube by
  one formula), glazed like ceramic, in one of four colors, lying about for
  units to carry.
- **section** — a color-coded patch on the ground, one per color, one in the
  middle of each quadrant: where cuboids of that color are carried and
  stacked.
- **hauling** — what a seat's unit with no order does: fetch the nearest
  free cuboid, carry it to its color's section, set it down.
- **chair** — the player's seat at the round table. Scrolling turns it about
  the hub: the world turns and the row of arches slides, so the player can
  look along to an ally's quadrant.
- **stand** — one group of units that receives orders together. The smallest
  thing an order can be given to.
- **order** — one instruction to one stand. Always given in the same two
  steps: click the stand on the map (who), then click an order button on the
  dashboard (what). Then map, then dashboard again. There are no menus and
  no shortcut commands: to build, you tell an engineer; to attack, you tell
  a stand.
- **courier** — the carrier of an order. It leaves the hub when the order is
  given and travels to the stand. The order only takes effect when the courier
  arrives.
- **transit** — the time an order spends travelling. Far fronts have long
  transit. New information can arrive while an order is still in transit, and
  a newer order can be sent after it.
- **factory** — a building that makes units. Its **waypoint path** (the route
  new units walk when they leave) is set once and then locked.
- **engineer** — the unit that builds, and the only unit that can dismantle a
  factory and rebuild it into something else, which is the only way to change
  a locked path.
- **hero** — a special unit that can be told to adventure a number of tiers
  deep.

## The team table

- **stand-in** — a commander seat. In hot-seat play one person can switch
  between stand-ins the way a strategy map switches between generals.
- **ballot** — one stand-in's vote on how a resource is split, or on what to
  buy next.
- **priority weight** — how much a stand-in cares about each ballot.
  Every stand-in has the same total weight to spread: "this part is crucial to
  my strategy, these I don't need a lot of."
- **vote cadence** — how often the table votes: on the calendar's boundaries,
  day or month as its pace button is set.

## Growing

- **resources** — **metal** (bodies, buildings), **glass** (shields, lenses,
  sensing), **aether** (the magical resource that unlocks things).
- **level-up** — what happens to both sides of a front when it is decided:
  each gains resources and is offered choices.
- **choice** — one thing that can be taken at a level-up: a unit type, an
  upgrade, a building. Every choice is built from the same value budget, so
  choices are roughly equal in value.
- **offer** — the set of choices one side sees at one level-up. Every side
  gets the same number of choices, of the same total value (Mechabellum
  parity).
- **roll table** — the generated list choices are drawn from. Rolling it is two
  steps: each **entry** has its own chance of coming up at all, and when it
  comes up, a second set of percentages picks which of its **values** you get.
- **price** — the resource cost of a choice.
- **unlock** — an aether-bought prerequisite some choices require.
- **enhancement** — a held choice that strengthens a particular power (unit
  kind, building, ability) once it is slotted into it, after City of Heroes
  by way of Symbeline. If the power is not owned yet, the enhancement waits
  in the tray; when the power is acquired, it slots in.
- **inspiration** — a one-time boost doled out to a stand (after the same
  source).
- **held choice** — a choice saved for later instead of taken now; it waits
  in the **tray**.
- **tray** — where held choices wait.
