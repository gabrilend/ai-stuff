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

## The view

- **accordion** — the way the map squeezes outer rings together so far tiers
  still fit on screen. It has two dials:
  - **reach** — how many tiers outward the screen shows (zoom of the first
    kind: how much territory you overlook).
  - **squeeze** — how strongly outer tiers are compressed compared to inner
    ones (zoom of the second kind: the accordion's folds growing shorter).
- **depth dial** — the dial that tells a hero how many tiers outward to go
  adventuring.

## The console

- **command wheel** — the large round console in the middle of the screen,
  over the hub, as big as a game-show wheel. Its center turns like a lazy
  susan.
- **rim** — the outer band of the wheel, divided into sectors with writing on
  them.
- **pointer notch** — the fixed mark at the top of the wheel. Whatever rim
  sector sits under it is selected.
- **complication** — a small window cut into the wheel's face (like the date
  window on a watch) showing a lower-tier display behind it.
- **calendar complication** — the complication that shows the game calendar:
  a day-of-week or month name in an arc window, and a number one level below.
  A button flips it between day mode and month mode.
- **readout** — a number shown as bare metal surface seen through a glass
  lens. Readouts are never buttons, and never look like them.
- **button** — bright, colorful, round or half-round, and always pressable.
  Anything pressable is a button; anything not pressable is not colored like
  one.

## Commanding

- **stand** — one group of units that receives orders together. The smallest
  thing an order can be given to.
- **order** — one instruction to one stand. Always given in the same two
  steps: press an order button, then click on the map. One button, one click,
  one order, one stand.
- **courier** — the carrier of an order. It leaves the hub when the order is
  given and travels to the stand. The order only takes effect when the courier
  arrives.
- **transit** — the time an order spends travelling. Far fronts have long
  transit. New information can arrive while an order is still in transit, and
  a newer order can be sent after it.
- **factory** — a building that makes units. Its **waypoint path** (the route
  new units walk when they leave) is set once and then locked.
- **engineer** — the only unit that can dismantle a factory and rebuild it
  into something else, which is the only way to change a locked path.
- **hero** — a special unit that can be sent adventuring to a chosen depth.

## The team table

- **stand-in** — a commander seat. In hot-seat play one person can switch
  between stand-ins the way a strategy map switches between generals.
- **ballot** — one stand-in's vote on how a resource is split, or on what to
  buy next.
- **priority weight** — how much a stand-in cares about each ballot.
  Every stand-in has the same total weight to spread: "this part is crucial to
  my strategy, these I don't need a lot of."
- **vote cadence** — how often the table votes, set from the calendar
  complication.

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
- **held choice** — a choice saved for later instead of used now. If it needs
  an unlock that has not been bought yet, it waits; when the unlock is bought,
  the held choice strengthens it.
