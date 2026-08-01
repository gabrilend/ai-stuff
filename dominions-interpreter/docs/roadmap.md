# dominions-interpreter — roadmap

Seven phases. They are **clusters of functionality**, not a schedule. A phase
is a section of the software that holds together as one idea, and the numbering
runs foundational-first: later phases lean on earlier ones, and the last issue
is a capstone rather than an afterthought.

It is normal for the final issue completed to belong to phase 1.

The ordering has one deliberate property worth stating up front. **The two
phases that need a model are fifth and sixth, and the phase that needs the
undocumented binary format is seventh.** Everything mechanical, everything
certain, and everything testable on a laptop with the wifi off comes first —
so that the parts most likely to go wrong arrive last, standing on something
that already works.

---

## Phase 1 — The Reading

*A savegame becomes a table describing a world.*

No model, no network, no game executable. This phase runs against the local
collection of savegames, which is large, spans several game versions, and
includes games with six mods loaded — a parser that agrees with all of it is
worth trusting.

| Issue | About |
|---|---|
| `101-the-input-gate` | reading `input/` first, because that is how a program learns how to start |
| `102-seeing-through-the-disguise` | the exclusive-or, the separator, and the letter O problem |
| `103-the-header-without-the-file` | signature, version, turn — from the first sixteen bytes |
| `104-the-string-run` | game name, mod dependencies, map layers |
| `105-the-record-arrays` | fixed-stride records, measured rather than assumed |
| `106-the-world-table` | one plain table, with `unplaced` for what is not understood |
| `107-the-survey` | what the collection actually contains, reported rather than remembered |
| `108-the-narrator` | logging into the RAM tier, in sentences |

At the end of this phase you can point the program at any savegame in the
collection and get a readable account of what is in it. That is already useful
to somebody who cannot read the game's interface.

## Phase 2 — The Chronicle

*Somewhere for expensive, unrepeatable work to land safely.*

Early on purpose. A conversation costs many inferences across three machines
and cannot be reproduced, so the place it lands must exist and be trustworthy
before anything expensive runs.

| Issue | About |
|---|---|
| `201-the-chain-link` | FNV-1a, and being honest that it is not a signature |
| `202-three-kinds-of-line` | `world`, `said`, `happened`, and why they never merge |
| `203-the-difference-between-turns` | what changed, computed rather than summarised |
| `204-verify-and-load` | one pass to check, one pass to rebuild |

## Phase 3 — The Court

*The part of the world that can be spoken to.*

Still mechanical. The cast list, the dossiers assembled from province history,
and the scene selection — all of it decided by lookups before any model is
asked to write a word.

| Issue | About |
|---|---|
| `301-the-cast-list` | names resolved to records, ambiguity settled up front |
| `302-dossiers-from-province-history` | the game's own dated prose, attached to whoever is standing in it |
| `303-choosing-what-to-open-on` | ranked mechanically, so drama cannot outrank a siege |

## Phase 4 — The Ledger

*The intended moves, as a file, useful with or without the rest.*

The format, the provenance requirement, and the validation — all testable by
hand-writing ledgers and checking them against a world table. Nothing here
needs a model or the game.

| Issue | About |
|---|---|
| `401-the-entry-format` | four fields that describe a move and one that justifies it |
| `402-validation-against-the-world` | five lookups, none of which ask a model |
| `403-the-read-back` | the review surface, built to be listened to |

## Phase 5 — The Doors

*Three little machines, reached over HTTP.*

The first phase that needs hardware, and deliberately the smallest. The roster,
the transport contract, the price mechanism, and one small llama.cpp adapter.

| Issue | About |
|---|---|
| `501-the-roster` | `input/cluster`, parsed purely, refused politely |
| `502-the-transport-contract` | request in, reply out, and a fake that satisfies it |
| `503-the-llama-door` | HTTP to `llama-server`, and nothing else |
| `504-the-pressure-market` | price from observed cost and queue depth |
| `505-losing-a-door-mid-conversation` | pause, say so, offer to continue — never lose a session |

## Phase 6 — The Conversation

*Where a person actually plays.*

The three roles, the session loop, and the terminal surface. Every part of it
testable against a fake transport, which means the whole conversation engine
can be developed and debugged with the cluster switched off.

| Issue | About |
|---|---|
| `601-the-herald` | prose from the world table, and voiced dialogue from dossiers |
| `602-the-remembrancer` | cited candidate links, and the freedom to find none |
| `603-the-steward` | agreement to ledger entries, and refusing what cannot be mapped |
| `604-the-session` | the loop, and what it writes as it goes |
| `605-the-listening-surface` | linear, re-readable, addressable by name |

## Phase 7 — The Hand

*Orders written into the game's own file, and judged by the game.*

Last because it is the only part that cannot be made certain in advance, and
because everything before it is useful without it.

| Issue | About |
|---|---|
| `701-the-working-copy` | a savegame copied safely, with the map data linked not duplicated |
| `702-the-difference-experiment` | the method: change one thing, save, diff, confirm |
| `703-the-order-vocabulary` | one order type at a time, each won by experiment |
| `704-writing-and-being-judged` | mutate the game's own file, then `--verify` |
| `705-hosting-headless` | `--host`, and reading the result back |
| `706-installing-a-turn` | the separate, explicit act, with a backup first |
| `707-a-turn-played-by-talking` | **capstone** — read, talk, write, verify, host, narrate the outcome |

---

## The shape of the dependency

    Phase 1 ──────────────────────────────────► everything
       │
       ▼
    Phase 2 ─────────────► every later phase writes here
       │
       ├──► Phase 3 ──┐
       │              ├──► Phase 6 ──► Phase 7
       ├──► Phase 4 ──┘        ▲
       │                       │
       └──► Phase 5 ───────────┘

Phases 1 and 2 together are already a program: point it at a savegame, get a
readable account of the world and a durable record of it. Phases 3 and 4 add
the two things a conversation needs to have on either side of it. Only then
does anything need a model, and only after that does anything need to write a
byte the game will read.

## What is uncertain, ranked

Written down here rather than discovered later.

1. **Where the order fields live in a `.2h`.** Not established. Addressed by
   experiment with `--verify` as the oracle. Needs a person to operate the
   game's interface; this is the one part a program cannot do alone.
2. **Whether cheat detection accepts a hand-written orders file.** Unknown.
   There is a flag to disable it, which is how we know it exists.
3. **How much of a turn file is understood.** Currently a small fraction. The
   survey reports the number rather than this document guessing at it.
4. **Whether mod-loaded games can be narrated safely.** Mods change what units
   and spells exist, and this project does not read mod files yet. Until it
   does, the narrator may only name things it read as text out of the save.

## Related

- [Architecture](architecture.md) — the shape all of this serves
- [The file format notes](dominions-file-formats.md) — what is known about the bytes
- [Table of contents](table-of-contents.md) — every document, indexed
