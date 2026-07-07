# 807 — The union: a threshold-triggered end-game antagonist (capstone)

> Phase 8 capstone. "if to many you are unkind, they may form a union. then you
> better prepare becaus e they'll end you." A running tally of cruelty; once it
> crosses a line, the wronged provinces coalesce and march on your home domain.
> Datapath:
> [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md) (Stage 6).

## Stats / meta
- **Phase:** 8 — Territory & Majesty Formula — **capstone**.
- **Depends on:** 801 (adjacency — who can coalesce with whom), 802 (which
  provinces are `hostile`), 805 (the unkind-subjugation events that feed the
  tally).
- **Blocks:** the Phase-8 demo (below) leans on this to show the full loop.
- **Kind:** threshold watcher + a composite antagonist entity.

## Current Behavior
None of this exists yet. Unkind subjugations happen (805) and could in principle
be counted, but nothing counts them, nothing notices a pattern of cruelty, and
there is no consequence for treating the whole ring badly. A player could subdue
every neighbour by force with no reckoning.

## Intended Behavior
The vision's warning, verbatim:

> if to many you are unkind, they may form a union. then you better prepare
> becaus e they'll end you.

An **unkindness tally** tracks how many provinces you currently hold in cruelty
(hostile subjugations, and abandoned-then-hostile land). A **watcher** compares
it to a tuned **threshold**. When the tally crosses that line, the bordering
unkind provinces **form a union** — a coalition antagonist:

- **membership** — the connected set of unkind provinces (found by walking 801's
  adjacency, so only provinces that actually border each other can join one
  union; distant cruelties may form *separate* unions).
- **pooled strength** — the sum of its member provinces' strengths, so a large
  union is genuinely dangerous.
- **an escalation clock** — a runway ("then you better prepare"): the union does
  not strike instantly; it musters, giving the player a window to make peace
  (turn members `allied` via 805, shrinking or dissolving the union) or fortify.
- **an assault** — when the clock fills, the union marches on the **home domain**.
  Resolving the assault is a win-or-lose-the-run condition — "they'll end you."

Making peace with enough members drops the tally back below the threshold and can
**dissolve** the union before it strikes — the door out stays open until the last
moment, matching "they *may* form a union."

Threshold, escalation duration, and strength weights are tuned knobs, in config +
tracked in [balance-updates.md](../docs/balance-updates.md) — nothing hardcoded
here, so a "too easy / too punishing" union is a knob-turn, not a rewrite.

## Suggested Implementation Steps
1. Write a **union** module owning the **unkindness tally** object. Expose an
   increment/decrement interface that 802's hooks and 805 notify (injected, so
   those modules do not hard-depend on this one).
2. Write the **watcher**: on tally change, compare to the config threshold; if
   crossed and no union yet covers those provinces, **form a union**.
3. Implement **form-union**: walk 801's adjacency from an unkind seed province to
   gather its connected unkind neighbours into a **union record** (members, pooled
   strength, escalation clock, assault target = home domain).
4. Advance the **escalation clock** each tick; comment the fork clearly — while
   the clock runs the player may still sue for peace (dissolve path) or prepare
   (fight path); when it fills, launch the assault.
5. Implement **peace shrinks / dissolves** the union: when a member turns
   `allied`, remove it, recompute strength; if membership or tally drops below
   threshold, dissolve. Model union lifecycle states (`mustering`, `assaulting`,
   `dissolved`) as a small dispatch table, not flags.
6. Implement the **assault** resolution as the run's lose condition, wired to
   whatever "home domain defence" surface exists; keep the hook thin so the
   defence mechanics can grow separately.
7. Write the companion `*.info.md`. Test: the tally rises/falls correctly; the
   union forms only at/over threshold; only *adjacent* unkind provinces join;
   making peace dissolves a mustering union; a full clock launches the assault.

## Phase demo (part of the deliverable)
When 801–807 land, build/refresh the **Phase 8 demo** in
`issues/completed/demos/` (and add its number to the root demo launcher). It
should *show the statistics*, not narrate: a province ring with live relationship
states, per-relationship yields flowing into the economy pools (recombining the
Phase 7 tools), an NCP expedition (Phase 5) flipping a relationship, and the
unkindness tally climbing until a union musters and marches — the full Majesty
loop on one screen. A graphical window is preferred over text.

## Related Documents / Tools
- Datapath: [datapath-territory-majesty.md](../docs/datapath-territory-majesty.md)
- Tally fed by 805; membership walks 801's adjacency; peace path uses 802/805.
- Roadmap places this as the Bucket D capstone:
  [roadmap.md](../docs/roadmap.md).
