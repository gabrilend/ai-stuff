# backwards-reader — roadmap

Six phases. They are **clusters of functionality**, not a schedule. A phase
is a section of the software that holds together as one idea, and the
numbering runs foundational-first: later phases lean on earlier ones, and
the last issue in the project is a capstone rather than an afterthought.

It is normal for the final issue completed to belong to phase 1.

---

## Phase 1 — The Grain

*Text becoming a structure that knows its own seams.*

Everything mechanical and deterministic. No model, no network, no
cluster — this phase runs on a laptop with the wifi off, and it already
satisfies the first thing the vision asks for: a block of text, run in
reverse, one line at a time.

The unit is defined here, and so is the rung table, and getting those two
shapes right is most of the design. Byte offsets are the discipline: every
piece of text, at every depth, can point at exactly the bytes it came from.

| Issue | About |
|---|---|
| `101-the-input-gate` | reading `input/` first, because that is how a program learns how to start |
| `102-text-held-byte-exact` | loading text without altering a byte, and finding line seams |
| `103-the-unit-and-the-grain` | the one table shape every rung shares |
| `104-mechanical-seams` | splitting into sentences and clauses without a model |
| `105-the-ladder-of-rungs` | the dispatch table, the descent, and the floor that stops it |
| `106-mechanical-turning` | reversals that need nothing but the bytes |

## Phase 2 — The Record

*Somewhere for expensive, unrepeatable work to land safely.*

Early on purpose. A reading costs thousands of inferences and cannot be
reproduced exactly, so the place it gets written must exist before anything
expensive runs. Append-only, checksum-chained, plain text, tailable while
being written.

| Issue | About |
|---|---|
| `201-the-chain-link` | FNV-1a, and being honest that it is not a signature |
| `202-the-append-only-reading` | the three line kinds and the flush discipline |
| `203-verifying-and-loading-back` | one pass to check, one pass to rebuild the tree |

## Phase 3 — The Mirror

*Meaning turned inside out.*

The heart of the vision, and the first phase that needs a model. Built
against an injected transport so the whole thing is testable with fakes on
a machine with no GPU — the real llama.cpp adapter is deliberately the
smallest module in the phase, because it is the only part hardware can
break.

| Issue | About |
|---|---|
| `301-the-transport-contract` | request in, reply out, and a fake that satisfies it |
| `302-the-prompt-forge` | asking for an inversion in a way that gets one |
| `303-the-llama-door` | HTTP to `llama-server`, `/completion` and `/health` |
| `304-the-model-mirror` | rung 4, wired to a transport |
| `305-seams-refined-by-a-model` | positions only, never text, and why |

## Phase 4 — The Doors

*Three little machines, a GPU, and a workstation, all pulling.*

The cluster. Roster, health, and the price mechanism that routes work — a
door's price rises with its queue and falls as it proves itself fast, and
the cheapest door wins. This machine is a door too, which is what turns the
crossover point from a tuned constant into a live measurement.

| Issue | About |
|---|---|
| `401-the-roster` | `input/cluster`, parsed purely, refused politely |
| `402-the-pressure-market` | price from observed cost and queue depth |
| `403-the-coroutine-pool` | a shared stack of coroutines over yielding sockets |
| `404-health-and-the-refusal-to-limp` | why a dark door stops the reading |
| `405-the-crossover-measurement` | where "use more doors" stops paying, plotted |

## Phase 5 — The Angle

*The measuring instrument.*

Embeddings and cosine distance, so a machine can sort hundreds of pairs and
a person can read the good ones. Includes the calibration step, because a
band guessed once and hard-coded is a lie waiting for the model to change.

| Issue | About |
|---|---|
| `501-embeddings-from-a-door` | `/embedding`, normalized on arrival |
| `502-the-angle-between` | cosine distance, and what the number means |
| `503-calibrating-the-band` | measuring the band instead of declaring it |

## Phase 6 — The Reading Room

*Where a person actually meets the work.*

The viewing half, which shares nothing with the generating half but a file
format. Cheap, re-runnable, and able to attach to a reading still in
progress.

| Issue | About |
|---|---|
| `601-the-reading` | the orchestrator that runs a whole descent |
| `602-the-terminal-contrast-view` | pairs side by side, sorted by angle |
| `603-the-html-reading-room` | the same, with the ladder made visible |
| `604-the-documentation-pages` | generated HTML docs, everything linked to everything |
| `605-the-output-gate` | writing goodbye, which is how a program ends |
| `606-a-reading-of-its-own-record` | **capstone** — the program reads its own output, and the descent meets itself |

---

## The shape of the dependency

    Phase 1 ────────────────────────────► everything
       │
       ▼
    Phase 2 ──────────────► every later phase writes here
       │
       ▼
    Phase 3 ────► Phase 4 (the doors are what phase 3 talks to)
       │             │
       ▼             ▼
    Phase 5 ◄────────┘
       │
       ▼
    Phase 6

Phase 1 and 2 together are a complete, useful program: text in, mechanical
reversal at every scale, a verifiable record out. Nothing after that is
required for the vision's first ask to be satisfied — which is the point of
ordering it this way.

## Related

- `docs/architecture.md` — the shape all of this serves
- `docs/table-of-contents.md` — every document, indexed
