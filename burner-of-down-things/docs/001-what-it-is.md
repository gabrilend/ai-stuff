# 001 — What it is

It has no name, on purpose ([notes/vision](../notes/vision): *never name such a
thing*). The folder is called `burner-of-down-things`; that is where it lives,
not what it is called. In these documents it is **the machine**.

## The one-page version

A person hands the machine a piece of software, as source code. The machine
reads the source and writes it down as **issue files**: a blueprint, foundation
first, complete enough that someone who never saw the original could build it
again. Then it builds a **new design** from that blueprint alone — without
looking back at the original — and hands it over: the harness and etceteras,
working code and the things around it.

After that the person asks for changes whenever they like. A change is never
applied to the code directly. It becomes an edit to the blueprint, and the
design is rebuilt from the edit outward. Each change is **graded** by how deep
in the blueprint it reaches, so the person knows before it starts whether one
part will be rebuilt or most of them.

```
   the source ──read──► the survey ──describe──► the blueprint ──build──► the design
   (someone's          (what is                  (issue files,             (new code,
    source code,        there: files,             foundation first)         made from the
    never changed)      languages, links)              ▲                    blueprint alone)
                                                       │
                                     a change request ─┘  graded by depth,
                                     from the person      then rebuilt outward
```

> source-code, the language of creation, is created by language creating
> creations.

The loop in one line: source is read into language (the blueprint), and
language is written back into source (the design). An update goes once more
around the loop.

## Why it is shaped like this

The owner's projects are already built this way: every project can be rebuilt
from scratch by re-completing its completed issue files in order. The machine
applies that rule to software it did not write. The blueprint is the valuable
part; code is what the blueprint turns into when it is asked.

| Choice | Because |
|---|---|
| The blueprint is issue files in the house format | They are already the owner's way of describing software, and the house tool that checks issue trees (`validate-issues`) checks a blueprint for free |
| The design is built from the blueprint alone | A design that peeks at the original is a copy with extra steps. Keeping the builder away from the source is what makes the blueprint the real specification — anything it forgot shows up as a gap in the design, and the gap is fixed in the blueprint |
| Changes go into the blueprint, never the code | The blueprint stays true. A design patched by hand drifts from its blueprint, and the next rebuild throws the patch away |
| Work is done by **turns** of a model, started by the machine | The judgment (reading code, writing prose, writing code) is a model's. Everything around it — what to read, where the result may be written, what order to build in, whether it passes — is the machine's own deterministic code, which can be tested without spending anything |
| How a turn builds is taken from the owner's skill files | *"using whatever technology marvels the claude-code skill files tell it how to build."* The skills are the machine's craft; it does not invent its methods |

## The five parts

| Part | What it does | Document |
|---|---|---|
| The case and the ledger | One folder per piece of software handled; an append-only, chained record of every interaction | [003](003-datapath-the-case-and-the-ledger.md) |
| The survey | Reads the source without a model: files, languages, sizes, who-includes-whom | [004](004-datapath-the-survey.md) |
| The hands | Runs a model for one turn, confined to the folders that turn may touch, and checks afterwards that it stayed there | [005](005-datapath-the-hands.md) |
| The blueprint | The source described as issue files, and the graph of which issue builds on which | [006](006-datapath-the-blueprint.md) |
| The design | New code built from the blueprint, in waves that respect the graph, checked issue by issue | [007](007-datapath-the-design.md) |

Two more read and act on the others: [the update](008-datapath-the-update.md),
which grades and applies change requests, and
[the center](009-datapath-the-center.md), which is the machine's personality
— computed from the ledger and nothing else.

## The gyroscope

> constrained in it's direction, magnifying chosen perception, like a
> gyroscope that doesn't stand still.

| Gyroscope | Machine |
|---|---|
| The axis it holds | The blueprint. Every turn is aimed at one issue in it, and a turn cannot write outside the folders its issue allows |
| The spin that keeps the axis steady | Describe, build, check, repeated. A design that fails its check goes around again |
| Precession — the slow drift when something pushes on it | The center: each interaction recorded in the ledger tips what the machine attends to first, and nothing else can |

## What it refuses to promise

| It does not promise | Because |
|---|---|
| That updates are instant | A change that touches one leaf of the blueprint rebuilds one part; a change to the foundation rebuilds most of the design. The grade says which before anything runs ([008](008-datapath-the-update.md)) |
| That the design matches the original's code | It matches the blueprint. Where the two disagree about behaviour, the blueprint was incomplete, and the fix is a blueprint edit |
| To handle software with no source | *source-code, the language of creation* — without source there is nothing to read the language from |
| To build a mind | It builds software. Its own judgment is borrowed, one turn at a time, from whichever model harness the person chose ([005](005-datapath-the-hands.md)), the same rule kiln's surrogate follows |

## Ancestry

- **kiln** (`/home/ritz/programming/ai-playground/kiln`) — the surrogate of its
  umbilical phase: a model driven one turn at a time from a folder, told what
  it may touch, checked afterwards; and the harness table, so any model the
  person has can do the work.
- **rao-chat**, **wow-chat-2026** — examples of what a finished case looks
  like: projects that can be rebuilt from their own completed issues.
- **the owner's skills** — issue-lifecycle (how a blueprint is written and
  checked), project-init (how a design's folder is laid out),
  polyglot-source, canvas-and-paintbrush and upstream-patch-system (craft a
  build turn may be told to use).
