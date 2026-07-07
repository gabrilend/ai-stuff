# Datapath — Economy & Settlement Management (Phase 7)

> How data flows through the player-side base economy: the store the returning
> adventurers feed and draw from. This document is the map; the
> [issue files](../issues/) (701–708) are the turn-by-turn directions.
>
> Sits inside [Phase 7 of the roadmap](roadmap.md#phase-7--economy--settlement-management),
> distills the economy slice of the
> [vision overview](vision-overview.md#phase-7--economy--settlement-management),
> and is indexed from the [table of contents](table-of-contents.md). When this
> doc and the [vision](../notes/vision) disagree, the vision wins.

---

## The one-paragraph flow

A New Character Person comes home from a lair carrying treasure. The economy
**deposits** that treasure into the shared **stockpile**. The player has, ahead
of time, configured **templates** — molds that say what a returning character of
a given kind *may request* and *may be handed*. At return-time the economy
**stamps an instance** from the matching template plus what this particular
character actually brought back, and hands that concrete request to the
**market**. The market **fulfills** what it can (magic items, rituals, market
goods) by spending the scarce resources and drawing on trade goods and on
**production** — the goods that the player's **workshops** have been generating
over time as **workers** (and the **service staff** who cover their chores) turn
raw inputs into finished goods. The re-equipped character then redeploys. Gold
is deliberately abundant ("so much gold that it's hard to consider what's most
valuable"); the interesting decisions run on the *scarce* resources — gems,
resource notes, and trial logs — which are what actually gate the good requests.

---

## The flow as a picture

```
   PHASE 5 (NCPs)                    PHASE 7 (this phase)                 PHASE 8
  ===============                   =====================               =========

  NCP returns from lair
    carries: brought-back  ───►  (706) RETURN-AND-REQUEST LOOP
    treasure + character-kind          |
                                       | 1. deposit brought-back treasure
                                       v
                                 (702) STOCKPILE / TREASURY  ◄──── province
                                       ^   ^        |               resources
                                       |   |        |               feed in via
   production goods ──────────────┐    |   |        |               the SAME
                                  |    |   |        |               deposit path
  (704) PRODUCTION                |    |   |        |               (Phase 8)
    workshops + workers  ─────────┘    |   |        |
    + service staff (704c)             |   |        |
    consume inputs, emit goods         |   |        |
       ▲                               |   |        |
       │ resource types define         |   |        |
       │ what is spendable/makeable     |   |        |
       │                               |   |        |
  (701) RESOURCE & TREASURE ───────────┘   |        |
        TYPE REGISTRY (dispatch)           |        |
                                           |        |
                                 2. look up template for this
                                    character-kind                       │
                                       |                                 │
                                       v                                 │
                                 (703) TEMPLATE MODEL ──────────────►    │
                                    "configure the mold, never the        stamp
                                     instantiation"                       an
                                       |                                  instance
                                       | 3. stamp request INSTANCE from
                                       |    template + brought-back treasure
                                       v
                                 (705) MARKET  ──► (705b) FULFILLMENT ENGINE
                                    trade goods come in       |
                                    (705a intake)             | 4. spend scarce
                                                              |    resources,
                                                              |    deliver
                                                              |    capability
                                                              v
                                 re-equip NCP from inventory template
                                       |
   NCP redeploys  ◄────────────────────┘  5. hand "ready" back to Phase 5

  (707) TEMPLATE-CONFIG UI  ── edits only 701/703/704/705 CONFIG, never the
        (data viewing/editing) running simulation's instances. It reads
                               projections; it does not compute them.
```

The picture separates two worlds that must never bleed into each other:

- **The simulation (data generation):** 701–706. It runs on its own, tick by
  tick and return by return, whether or not anyone is looking.
- **The configuration UI (data viewing / editing):** 707. It edits the *molds*
  (templates, worker counts, market stock policy) and *reads back* projected
  numbers by calling the simulation's own projection functions. It never reaches
  into a running instance, and it never re-derives a number the simulation
  already knows how to compute (that way the shown number can never drift from
  the true one).

---

## The two seams

### Seam to Phase 5 — returns and requests (the reason this phase exists)

Phase 5 owns the adventurers. Phase 7 owns the base they come home to. The
contract between them is small and lives in the
[return-and-request loop (706)](../issues/706-return-and-request-loop.md):

- **Inbound (Phase 5 → 7): a return event.** Carries the character's identity,
  its *character-kind* (which selects a template), its brought-back treasure
  (a bag of resource-type → amount), and its current loadout. Phase 5 does not
  need to know anything about markets, stockpiles, or workers — it just says
  "this one is home, here is what it carried."
- **Outbound (7 → Phase 5): a redeploy-ready hand-back.** Carries the same
  character with a refreshed loadout (what the market fulfilled, plus whatever
  the inventory template grants) and a note of any request that went
  *unfulfilled*, so Phase 5 can color the companion's dialogue ("the stockpile
  was out of mana crystals").

The templates the player configures are the vision's "NPC inventory lists that
can be configured as you see fit" and "when the character returns, they can
request new things, as you define." Phase 5 saves *character* patterns
(summarized); Phase 7 saves *request/inventory* templates. Same "edit the mold"
strategem, two different molds.

### Seam to Phase 8 — province resources feed in

Phase 8 (Territory & Majesty) will grant resources based on how the player
treats neighboring provinces. Those resources enter this economy through the
**same deposit entrypoint** the return loop uses — the
[stockpile (702)](../issues/702-stockpile-treasury-shared-store.md) exposes one
"deposit this bag of resources, and say where it came from" door, and both a
returning adventurer and a friendly province knock on it. This is why the
deposit path is factored out of the return loop and given to the stockpile
itself: so Phase 8 can reuse it without touching Phase 5's code. Phase 7 does
not build the province logic; it only guarantees the door is there and records
the provenance in the ledger.

---

## Structures, by the role they play

Names below are described by *what they hold*, not by an eventual code
identifier. The implementing issue is noted in brackets.

- **Resource-type record** [701] — one per treasure kind (gold, gem, resource
  note, trial log): its display name, whether it stacks/is fungible, how it is
  found in vaults, and what kinds of request it can pay for. Held in a
  **dispatch table keyed by resource-type id**, so "what does this resource do"
  is a table lookup, never an if/else ladder.
- **Stockpile / treasury** [702] — the shared store. Two shelves: a **balance
  table** (resource-type → amount) and a **goods store** (produced goods and
  trade goods → amount). Plus an **append-only ledger** recording every deposit
  and withdrawal with its provenance (which adventurer, which province, which
  workshop). Append-only on purpose: the economy's history should read like a
  bank statement you cannot secretly rewrite.
- **Request template** and **inventory template** [703] — the molds. A request
  template says what a returning character-kind *may ask for* and what each ask
  costs in scarce resources; an inventory template says what it is *handed for
  free from the stockpile* ("here, have a health potion. There's extra at the
  stockpile."). Held keyed by character-kind. **Never edited per-instance.**
- **Request instance** and **loadout instance** [703, stamped by 706] — the
  concrete, per-return objects derived from a template plus this character's
  brought-back treasure. Created at return-time, consumed by fulfillment,
  discarded. The UI never touches these.
- **Workshop record** and **worker-slot model** [704a] — one per placed
  building (a lumber shop, etc.): its building-type, its footprint/capacity, how
  many workers are currently assigned, and the derived **room-per-worker** that
  drives the throughput-vs-room tradeoff.
- **Building-type record** [704a] — a **dispatch table keyed by building-type**
  mapping each type to its input resources, output goods, base per-worker rate,
  and footprint.
- **Service-staff pool** [704c] — how many service staff are hired and the
  **coverage lookup** (how many workers one service-staff frees from chores),
  producing the production-speed multiplier.
- **Market record** and **stock policy** [705a] — one per player-placed market:
  its on-hand trade goods, the capabilities it can fulfill (magic items,
  rituals, market goods), and the *stock policy* (a mold: what it should keep in
  stock and at what resource-cost). The market is a placed instance; its policy
  is a template.
- **Request-type dispatch** [705b] — a **dispatch table keyed by request-type**
  (magic item / ritual / market good) mapping each to the handler that knows how
  to fulfill it.

---

## Functions, by the role they play

Described by job, not signature. Grouped by whether they *generate* data
(simulation) or *view/edit* it (UI) — the wall between those groups is the whole
point.

### Simulation side (data generation) — 701–706

- **Look up a resource-type's behavior** [701] — the dispatch entrypoint every
  other module uses instead of branching on resource kind.
- **Deposit a bag of resources (with provenance)** [702] — the one door both the
  return loop and Phase 8 provinces knock on. Adds to balances, writes the
  ledger.
- **Withdraw / check affordability** [702] — spend against balances; refuse
  explicitly (an error, not a silent zero) when the stockpile can't cover it, so
  the failure is loud and traceable.
- **Create / read / update / list a template** [703] — template CRUD, plus
  **save-a-template-as-a-new-template** (mirroring Phase 5's summarized-pattern
  save).
- **Stamp an instance from a template** [703, called by 706] — the mold → copy
  operation. The only sanctioned way an instance ever comes to exist.
- **Compute a workshop's throughput** [704a/704b] — from worker count and
  room-per-worker (the tradeoff curve) times the service-staff speed multiplier.
  This is the function the UI *calls* for its projections rather than
  reimplementing.
- **Advance production one tick** [704b] — for every workshop, consume inputs
  from the stockpile if available and emit goods at the computed rate. Written to
  be resolvable per-workshop independently (a coroutine per workshop, resolved by
  a pool) since workshops don't depend on one another within a tick.
- **Bring trade goods into the markets** [705a] — the periodic intake that keeps
  markets stocked per their policy.
- **Fulfill a request instance** [705b] — dispatch on request-type; check
  capability and affordability; spend, deliver, and log — or refuse with a reason.
- **Run one return** [706] — deposit, look up template, stamp instance, fulfill,
  re-equip, hand back to Phase 5; record the unfulfilled remainder.

### Viewing / editing side (data viewing) — 707

- **Show current balances and ledger** [707] — read-only over the stockpile.
- **Edit a template** [707] — the in-game UI over 703's template CRUD. Edits the
  mold only.
- **Edit worker allocation and preview throughput** [707] — set building and
  worker counts, and display the *projected* throughput by calling 704's
  compute-throughput function (never a re-derivation).
- **Hire service staff / edit market stock policy** [707] — edit the 704c and
  705a config, preview the effect via the simulation's own projection functions.

---

## The central principle: templates, never instantiations

This phase is the settlement half of the project-wide **"configure the template,
never the instantiation"** strategem (see
[strategems](../strategems/README)). The rule, stated plainly:

- The **player edits molds**: request templates, inventory templates, worker
  allocation, service-staff count, market stock policy.
- The **world stamps copies** at return-time and tick-time: request instances,
  loadout instances, produced-goods batches.
- **No path lets the UI edit a stamped copy.** If a copy is wrong, the mold was
  wrong — fix the mold, and the next stamp is right. This keeps the settlement's
  behavior coherent the same way Phase 5 keeps a companion's behavior coherent by
  saving *summarized* patterns rather than editing a live personality.

---

## Dispatch tables in this phase (a convention, not a suggestion)

Wherever behavior varies by a *kind*, this phase uses a table keyed by that kind
instead of an if/else or switch chain — it is cheaper to reach a function by
index than to walk a ladder of comparisons, and it keeps each kind's behavior in
one legible row:

- resource kind → resource-type behavior [701]
- building kind → inputs/outputs/rate/footprint [704a]
- request kind → fulfillment handler [705b]
- provenance kind (adventurer / province / workshop) → ledger annotation [702]

---

## Numbers live in a validator, not in this document

Per the project's documentation discipline, this datapath deliberately states no
hard constants — not the base per-worker rate, not the shape of the
room-per-worker bonus curve, not the fraction of a tick a worker loses to chores,
not how many workers one service-staff covers. Those are tuning knobs. They
belong in a tuning/config file read at load and surfaced by a **statistics /
validator utility** that can be run to report current figures on demand. When
those knobs are turned, the change and its reason go in `docs/balance-updates.md`
(append-only), not here. Reference the validator; never restate its output.

---

## Related documents

- [vision-overview.md](vision-overview.md) — the economy feature distillation.
- [roadmap.md](roadmap.md) — where Phase 7 sits in the dependency graph
  (needs Phase 5; feeds Phase 8).
- [datapath-ncp-characters.md](datapath-ncp-characters.md) *(planned, Phase 5)* —
  the other side of the return/request seam.
- [datapath-territory-majesty.md](datapath-territory-majesty.md) *(planned,
  Phase 8)* — the province resources that feed the deposit door.
- [table-of-contents.md](table-of-contents.md) — the master index.
