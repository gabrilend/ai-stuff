# Roadmap

Symbeline Rumble is built in nine phases. Each phase ends with a capstone
**demo** that lives in `issues/completed/demos/phase-N-demo/`, runnable
from a single bash script, on *both* the `nds` and `native` profiles.

Phases are clusters of functionality and major methodology, not arbitrary
timeboxes. Issues within a phase tend to share infrastructure; later
issues build on earlier ones. **Phases are not symmetrically sized.**
Phases 1, 4, 7, and 8 are heavy; phases 3, 5, 6, and 9 are tighter; phase
2 is aesthetic-shaped.

**Forward-stubbing** (strategem 006) is the bridge across phase
boundaries: a later phase's interface is sketched as a stub in the earlier
phase that consumes it, so work is unblocked even when the producer
doesn't yet exist. Phases note where this happens.

## Phase 1 — Foundation & Build System

**Methodology in focus:** the dual-target patch system, the trunk's
DS-shape, the fixed-point math layer.

By the end of Phase 1, the project can produce a `.nds` and a native ELF
from the same source, with patches applied and reverted around each
build. The trunk compiles a "hello rumble" scene with a single sprite, a
fixed-point sin-wave bob, and a button-press logged through the platform
input seam.

**Capstone demo:** boot the same hello-rumble on melonDS and on the native
window side-by-side; both show the same sprite, both respond to the same
logical inputs, both honor the same memory budget readouts printed to a
shared log file.

## Phase 2 — Display & Rendering Foundation

**Methodology in focus:** the platform render seam, the tilt-shift
divergence (D1), dual-screen layout vs. split-vertical-window layout, the
sharp-band aesthetic rule made enforceable in code.

By the end of Phase 2, both targets can render a static 3D scene in the
sharp band with tilt-shift framing (DS: layered backdrops; native: shader
post-process). The bottom screen / lower window half shows a tactical
inset of the same scene.

**Capstone demo:** a still-life of a small piece of terrain with a few
props and the chibi knight from phase 1, rendered on both targets, with a
side-by-side photograph and a stats readout. This is also the first
moment where `notes/sketches/parity-may-be-pessimism.md` becomes
checkable.

## Phase 3 — Map, Paths, and Paging

**Methodology in focus:** the 2×2 map data structure, the pre-authored
path graph, L/R paging with menu-on-second-press.

By the end of Phase 3, a unit can be placed at a spawn point and walks a
pre-defined path; L and R page between the left and right halves; a
second press opens an empty menu container.

**Forward-stub for phase 6:** the L/R menu opens but has no content. The
container exists; the vocabulary fills in phase 6. Game code can refer
to "the menu being open" before any menu actions are defined.

**Capstone demo:** a unit walking a path that crosses the L↔R seam; the
player pages with the shoulder; the unit continues its path on the new
half without resetting.

## Phase 4 — Units, Combat, & Death

**Methodology in focus:** the unit entity system, encounter detection,
fixed-point damage tick, death, deck-removal-on-death.

By the end of Phase 4, two opposing barracks spawn units; units path
toward each other; they encounter; they fight via deterministic
fixed-point damage application; one side wins; the deck removes dead
units. Three classes playable (Footman, Archer, Knight).

**Forward-stub for phase 8:** damage resolution calls
`apply_stat_modifiers(unit, &modifier_list)` where the modifier list is
currently empty. Equipment in phase 8 fills the list. Combat code does
not change in phase 8 — it just sees a non-empty list.

**Capstone demo:** a small skirmish on one half of the map, two
opposing barracks, three unit classes, deterministic outcome on both
rendering targets.

## Phase 5 — Economy & Structures

**Methodology in focus:** the section-mark gold bar, passive vs. active
gold, structure ownership and cap, the no-HUD discipline applied to
resources.

By the end of Phase 5, gemstone mines drip gold; treasure chests demand
physical retrieval (carrier visibly slowed, per
`notes/sketches/treasure-weight.md`); the gold cap responds to structure
ownership; the section-mark bar reads correctly under sustained activity.

**Capstone demo:** a player-controlled match where the only goal is to
accumulate gold. No combat. The bar fills, units retrieve chests, the
cap raises on captures, structures change hands.

## Phase 6 — Player Controls, Menus, & Spells

**Methodology in focus:** the touchscreen model, the L/R menu vocabulary
(filling the phase-3 stub), spell casting, deck cycling, the no-HUD
discipline applied to feedback.

By the end of Phase 6, the player drives a full single-player skirmish
end-to-end: shoulder paging, touchscreen orders, deck cycling, at least
two spells (one self-targeted, one unit-targeted). The Anbernic
top-screen-touch divergence (D6) is implemented; baseline DS has an
explicit alternate-targeting path.

**Capstone demo:** the player completes a full unscaffolded skirmish.
No debug overlays, no developer chrome, no on-map text other than the
section-mark bar and incidental speech bubbles.

## Phase 7 — Local Multiplayer

**Methodology in focus:** two-target peer-to-peer multiplayer over a
lockstep simulation. The DS-proprietary bridge process on native. New
divergence grid rows (D9–D12). The largest single phase by complexity.

**Architecture:** lockstep sync with ~3-tick input delay over a unified
application-layer wire protocol. Transports differ by pairing:

- **DS↔DS** uses libnds's proprietary local-wireless API directly.
- **native↔native** uses our own peer-to-peer protocol over standard
  802.11 (WiFi Direct or ad-hoc). No router.
- **DS↔native** uses a melonDS-derived **bridge process** on the native
  side that speaks DS-proprietary protocol over real radio. This
  requires a USB AR9271 wifi adapter on most RG-XXXX hardware because
  stock Realtek chips don't support raw 802.11b injection. The adapter
  is documented as a setup item.

Determinism: fixed-point gameplay (per `008-fixed-point-math.md`) makes
the simulation byte-identical between peers. State checksums exchanged
every N ticks; mismatch is a hard logged error.

**Capstone demo:** three pairings, three skirmish matches: DS↔DS,
native↔native, DS↔native via bridge. The capstone proves the bridge
architecture by playing the same game across all three.

## Phase 8 — Meta-Progression

**Methodology in focus:** save data on both targets, the post-match
upgrade loop, equipment editing, level allocation, behavior-pattern
editing, permadeath as a per-campaign option.

By the end of Phase 8, matches (single-player AND multiplayer from
phase 7) feed into a persistent profile. The phase-4 stat-modifier stub
is **filled**: equipment produces modifiers that combat code consumes
unchanged. The post-match screen presents level-up choices; loadouts
are editable; permadeath is selectable per campaign.

**Capstone demo:** a three-match arc — at least one multiplayer match
in the mix — with persistent character development across all three.
One permadeath event in the final match makes the loss visible.

## Phase 9 — Content & First Playable

**Methodology in focus:** first playable campaign arc; full audio mixer
and assets; polished art; balance-updates discipline (`docs/balance-
updates.md`, append-only); the speech-bubble notification surface fully
implemented.

By the end of Phase 9, the game has a first playable campaign of 3–5
missions, full audio, polished art, balanced numbers. The capstone
*is* the campaign, played end-to-end on both targets.

**Phase 9 stretch — DS Download Play.** Build a stripped-down NDS
binary of Symbeline Rumble (one map, no progression). Teach the bridge
process to act as a WMB (Wireless Multiboot) host. A friend brings
their DS with no cart; the user's Anbernic seeds the demo binary over
real radio; the friend plays a match against the user. This is the
single capability that justifies the bridge architecture's cost beyond
plain cross-target play.

## Cross-phase responsibilities

These are not phases; they are continuous obligations that every phase
contributes to:

- **Divergence grid** (`005-divergence-grid.md`) gains rows as features
  diverge and loses rows as targets converge.
- **`info.md` files** sit next to every source file, documenting external
  surface and intent.
- **Tests** are cheap; they accompany each feature. A bug found is a test
  written.
- **Demos** are deliverables, not scaffolding. They run on both targets,
  every phase.
- **LLM transcripts** are saved into `llm-transcripts/` and referenced
  from issues when the implementation history becomes useful.
- **Forward-stubs** (strategem 006) bridge phases by reserving an
  interface in an earlier phase that a later phase fills. The bridge is
  named in both phases' issues.
