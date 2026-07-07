# Datapath — Territory & Majesty Formula (Phase 8)

> How data flows through the outer meta-layer of the game: the ring of
> neighboring provinces, the relationship you hold with each, and the resources
> that ring pours back into your kingdom. The [vision](../notes/vision) is the
> source of truth. This document maps the *flow* — who hands what to whom — and
> lists the structures and functions by the **role they play**, not by their
> eventual code names.
>
> Back to the [table of contents](table-of-contents.md). Sibling seams:
> [Phase 5 NCP characters](datapath-ncp-characters.md),
> [Phase 6 Dungeon Master](datapath-dungeon-master.md),
> [Phase 7 economy & settlement](datapath-economy-settlement.md).

---

## The vision lines this path serves

Phase 8 is the "Majesty formula" layer. The vision fixes it in these lines:

> this follows the majesty formula staple where overcoming trials and challenges
> and clearing and controlling neighboring provinces yields resources depending
> on your relationship to them. be peaceful, and they are on your side, and
> provide one thing or another. be unkind, and they are challenges to train up
> on. leave unclaimed, and monsters return, either to fight (for a specific type
> of resource) or to protect and leave to nature, to cultivate natural materials.
>
> if to many you are unkind, they may form a union. then you better prepare
> becaus e they'll end you.

"The Majesty formula" points at *Majesty: The Fantasy Kingdom Sim* — a game of
**indirect control**, where you never command a hero directly; you post a bounty
and hope someone takes it. That indirect spirit is the whole reason this path
leans on the autonomous NCPs from Phase 5 to actually go do the clearing. You do
not send an army into a province. You make it worth an adventurer's while, and
one of them wanders off to try.

---

## The flow in one breath

```
  a map of neighbouring provinces
        |  (each province holds ONE relationship state)
        v
  relationship state  --->  yield profile  --->  resource deltas
        ^                                              |
        |                                              v
  Phase 5 NCP expedition                        Phase 7 economy pools
  clears & controls a province                  (gold / gems / notes / logs)
        |
        |  the MANNER of the clear decides the new relationship
        v
  peaceful ally  |  unkind training-ground  |  left unclaimed
                                                     |
                                        monsters return in one of two modes
                                        (fight for a resource  |  cultivate nature)

  ... and a running tally of "how many did you treat unkindly?"
        |
        |  crosses a threshold
        v
  the provinces form a UNION  --->  an end-game army marches on your home domain
```

Read top-to-bottom that is: **map → relationship → yield → economy**, with two
loops folded in — the clear-and-control loop that *changes* relationships, and
the union threshold that *punishes* a certain pattern of them.

---

## Stage 1 — the map of neighbouring provinces

The taproot structure is a **territory map**: your home domain at the centre and
a ring (later, rings) of neighbouring provinces around it, joined by an
**adjacency** relation ("this province borders that one"). Adjacency is what the
word "neighbouring" means mechanically — a province is reachable, and it can
belong to a union, only through who it borders.

Each **province record** carries:
- an identity (id + a display name),
- its neighbours (the adjacency list),
- exactly one **relationship state** key (Stage 2),
- a handle to its **challenge** — the lair/trial the Phase 6 Dungeon Master grew
  inside it (this is why Phase 8 depends on Phase 6),
- a **yield accumulator** (what it has produced but not yet banked),
- a **kindness ledger** (how you have treated it over time), and
- a **reversion timer** used only while unclaimed (Stage 4).

See issue **801** for the map and the province record.

---

## Stage 2 — the relationship state (a dispatch table, not an if-ladder)

Every province is, at any instant, in exactly one of three relationships. These
are modelled as a **dispatch table keyed by state name** — never a chain of
if/else — because each state answers the same set of questions with a different
function, and because the legal transitions between them are themselves a table:

| state              | what it is to you                     | yields how           |
| ------------------ | ------------------------------------- | -------------------- |
| `allied` (peaceful)| "on your side… provide one thing or another" | passive trickle |
| `hostile`          | "challenges to train up on"           | only when cleared    |
| `unclaimed`        | "monsters return"                     | via a sub-mode (St.4)|

The state table entry holds: a label, whether it yields passively, whether it
presents a challenge, whether monsters can return, `on_enter`/`on_exit` hooks,
and — crucially — its **allowed transitions**. A second dispatch table keyed by
`(from_state, to_state)` validates and performs each move, so no code path can
smuggle a province from one state to another without going through the table.

See issue **802** for the state table and the transition table.

---

## Stage 3 — the yield profile (relationship decides the reward)

A **yield profile** is a function chosen *by relationship state* that, given a
province and elapsed time, returns a set of **resource deltas** (and, for
challenges, a training value for the NCP). Dispatch table keyed by state:

- `allied` → a steady passive trickle of "one thing or another" — a resource
  type tied to the province's nature. This is the reward for peace.
- `hostile` → **nothing passively**. A hostile province is a whetstone: it pays
  out only as an *event*, when an NCP expedition overcomes its trial, and its
  main product is training value + a trial log, not a steady stream.
- `unclaimed` → delegated down to the Stage-4 sub-mode.

See issue **803** for the yield-profile table.

---

## Stage 4 — unclaimed, and the two ways monsters return

Leave a province alone — never claimed, or abandoned after — and its reversion
timer runs. When it fills, **monsters return**, and the province rolls into one
of two sub-modes (a weighted roll on province traits, then a dispatch on the
result — see issue **804**, with sub-modes **804a** and **804b**):

- **fight** (804a): monsters garrison the province. It becomes a recurring
  combat target; clearing it yields "a specific type of resource" — a combat
  spoil — and then the monsters creep back and it can be fought again.
- **cultivate** (804b): monsters "protect and leave to nature." The province
  slowly accrues **natural materials** that can be harvested peacefully — a
  different, slower, renewable yield than the fight spoil.

Both sub-modes are unclaimed-state yield profiles; Stage 3 hands off to them.

---

## Stage 5 — the clear-and-control loop (indirect control via NCP expeditions)

This is the loop that *moves* provinces between relationships, and it is the
seam onto Phase 5. The player does **not** directly conquer. The player sets
incentives; an autonomous NCP chooses to mount an **expedition** at a province,
engages that province's Phase-6 challenge, and the **manner and outcome** of the
expedition decide the resulting transition (issue **805**):

| expedition result        | relationship it produces        |
| ------------------------ | ------------------------------- |
| succeed, peacefully       | `allied`                        |
| succeed, unkindly (conquer harshly) | `hostile` (subjugated whetstone) |
| fail                      | unchanged; monsters may entrench|

On a successful transition the loop calls Stage 2's transition table and unlocks
Stage 3's yield profile. Every unkind subjugation also ticks the **unkindness
tally** that Stage 6 watches.

---

## Stage 6 — territory feeds the economy; too much cruelty feeds a union

Two outputs leave this layer:

1. **Into the economy (issue 806).** A bridge/aggregator walks the map each
   economic tick, asks every province's active yield profile for its current
   delta, sums by resource type, and **deposits into the Phase 7 resource
   pools** (gold, gems, resource notes, trial logs). Territory *produces* yield
   events; the bridge *translates* them into economy deposits — the two concerns
   stay isolated so a bug in one can't corrupt the other.

2. **Into an end-game threat (issue 807).** A watcher tracks the unkindness
   tally. When it crosses a tuned threshold, the bordering unkind provinces
   **form a union** — a coalition antagonist that pools their strength and
   marches on your home domain. "then you better prepare becaus e they'll end
   you." This is the capstone: a threshold-triggered, map-driven boss.

---

## Structures, by role

- **Territory map** — the whole board: the home domain, every province, and the
  adjacency relation binding neighbours. Iterable; answers "who borders whom" and
  "which provinces sit on my frontier."
- **Province record** — one province's whole state (identity, neighbours,
  relationship key, challenge handle, yield accumulator, kindness ledger,
  reversion timer). *(801)*
- **Relationship-state table** — dispatch table keyed by state name; one entry
  per relationship, each answering the shared question set. *(802)*
- **Transition table** — dispatch table keyed by `(from, to)`; the only sanctioned
  way a province changes relationship. *(802)*
- **Yield-profile table** — dispatch table keyed by relationship state (and, for
  unclaimed, by sub-mode); each entry turns "a province + elapsed time" into
  resource deltas + training value. *(803, 804a, 804b)*
- **Reversion timer** — per-province countdown that governs when monsters return
  to an unclaimed province. *(804)*
- **Expedition resolution record** — what an NCP expedition did at a province
  (target, manner, outcome), consumed by the clear-and-control loop. *(805)*
- **Unkindness tally** — the running count of provinces treated unkindly; the
  fuse the union watches. *(807)*
- **Union record** — a formed coalition: its member provinces, pooled strength,
  escalation clock, and assault target. *(807)*

## Functions, by role

- **build / seed the territory map**, register a province, bind two provinces as
  neighbours (adjacency is bidirectional). *(801)*
- **look up a province, iterate its neighbours, iterate the whole map, query the
  frontier** (provinces bordering your controlled set). *(801)*
- **describe a relationship state** (its table entry) and **attempt a
  transition** through the transition table, running `on_exit`/`on_enter`. *(802)*
- **evaluate a province's yield** by dispatching on its relationship state to the
  matching yield profile. *(803)*
- **run the reversion timer and, on fill, roll + dispatch the unclaimed
  sub-mode**; **produce the fight spoil** / **produce the cultivated material**.
  *(804 / 804a / 804b)*
- **resolve an NCP expedition into a transition** — read the manner+outcome, pick
  the resulting relationship, call the transition table, unlock the yield, tick
  the unkindness tally on cruelty. *(805)*
- **aggregate territory yields and deposit into the economy pools** each economic
  tick. *(806)*
- **watch the unkindness tally, form the union on threshold, escalate the union,
  and march it on the home domain.** *(807)*

## Files this path will add (and why)

Source files carry an ordering index drawn from the project's
`.file-index-counter` at build time (so they read in story order across the whole
codebase); the names below are by role, and each ships with a companion
`*.info.md` black-box summary.

- a **territory-map** module — the map, adjacency, the province record, frontier
  queries. Foundation for the rest. *(801)*
- a **relationship-states** module — the state dispatch table and the transition
  table. *(802)*
- a **yield-profiles** module — the per-relationship yield dispatch, including the
  two unclaimed sub-modes. *(803, 804, 804a, 804b)*
- a **clear-and-control** module — the expedition→transition resolver; the seam
  onto Phase 5 expeditions and Phase 6 challenges. *(805)*
- a **territory-economy bridge** module — the per-tick aggregator that deposits
  into Phase 7 pools. Kept separate so territory never writes to economy state
  directly. *(806)*
- a **union** module — the tally watcher, union formation, and the end-game
  assault. *(807)*

## Cross-phase seams (where this path touches its neighbours)

- **From Phase 5 (NCP characters):** expeditions arrive here as expedition
  resolution records. Indirect control lives on their side; we only read the
  result. See [datapath-ncp-characters.md](datapath-ncp-characters.md).
- **From Phase 6 (Dungeon Master):** each province's challenge is a lair the DM
  grew; overcoming it is what a hostile/unclaimed province's event yield is paid
  for. See [datapath-dungeon-master.md](datapath-dungeon-master.md).
- **Into Phase 7 (economy):** yields become deposits in the resource pools; trial
  logs and training value ride along. See
  [datapath-economy-settlement.md](datapath-economy-settlement.md).

## On counts and tuned numbers

Per project discipline this datapath hardcodes **no** numbers — not the union
threshold, not yield rates, not reversion durations. Those are tuned knobs; they
live in configuration and their history lives in
[balance-updates.md](balance-updates.md) (append-only). When a validator that
reports the live values exists, link it here rather than restating figures that
would rot.

---

## Related issues

Foundational first, capstone last:

- **801** — province model & the neighbouring-province map
- **802** — relationship states as a dispatch table (+ transitions)
- **803** — relationship-based yield profiles
- **804** — the unclaimed → monsters-return dynamic (reversion + sub-mode roll)
  - **804a** — unclaimed *fight* sub-mode (a specific combat spoil)
  - **804b** — unclaimed *cultivate* sub-mode (renewable natural materials)
- **805** — the clear-and-control loop (NCP expeditions drive transitions)
- **806** — territory → economy feedback bridge
- **807** — the union: a threshold-triggered end-game antagonist (capstone)
