# 018 — The Shape of the Code

Not a datapath document. This is the house style: where files live, how they are
named, and the handful of rules that are not negotiable.

## Language

**LuaJIT.** Not Lua 5.4 — no integer division operator, no bitwise operators as
syntax, no goto-based control flow that 5.1 would reject. Bit operations go
through LuaJIT's `bit` library. Where a hot array of numbers is needed, an FFI
struct array is preferred over a Lua table, because the whole simulation is
arithmetic over flat arrays and that is precisely what LuaJIT is good at.

## Files are numbered, and the numbers are a reading order

Every source file's name begins with a three-digit index. The indices count up
across the **whole project**, not per directory, so that reading the project in
index order is reading a story from the beginning. A hidden file at the project
root, `.file-index-counter`, holds the highest index in use; a new file takes the
next one and bumps the counter.

Companion documents share their file's index: `031-wave-spawner.lua` sits beside
`031-wave-spawner.info.md`.

External libraries dropped into `libs/` are renumbered into a high band so that a
reader who does not care about them can skip a contiguous range rather than
stepping over them one at a time.

## Every source file has a companion

For each `NNN-name.lua` there is an `NNN-name.info.md` listing:

- every function the file exports, its arguments and their types, and what it
  returns
- every data structure it owns, its fields, down to the primitives
- what the file is for, in prose, treating its internals as a black box

**Read the companion, not the source.** The source is for when a specific
function is misbehaving. The companion is for everything else. A companion that
has drifted from its source is a bug of the same severity as a wrong answer.

## Comments say why, not what

A comment that restates the line below it is noise. The comments this project
wants are:

- **Why this exists.** What went wrong without it, or what it was chosen over.
- **What each branch means.** Every conditional gets a comment naming what each
  path leads to. A branch and its comment are edited as one unit; changing the
  condition without changing the comment is leaving a lie in the file.
- **What the data looks like.** Anything learned about a format, a range, an
  invariant, or an edge case goes in as a comment at the place it matters. If a
  fact will be needed twice, it is written down once, in the code.

## Functions are folded

Every function opens with a vimfold marker on its own line, carrying the comment
symbol and the function's name without arguments, then the definition:

    -- {{{ local function pick_target()
    local function pick_target(world, soldier_id)
      ...
    end
    -- }}}

The closing marker sits on its own line below the function's last line.

## Dispatch tables over branches

Where a value selects behaviour — soldier state, command verb, upgrade behaviour,
ability, phase — the value indexes an array of functions. Not an if-chain, not a
switch. Adding a case is adding a row. The tick order itself is a dispatch table,
which makes the order of the simulation a piece of readable data instead of
something buried in a function body.

## Errors, not fallbacks

A fallback is a warning and a warning is an error. If a lookup fails, the program
stops and says what it was looking for and where. Silently substituting a default
turns one bug into a mystery discovered three systems downstream.

**Nil is not an option.** Fields that might be empty hold the integer zero, not
an absent value. Zero is a sentinel with a meaning; nil is a question about
whether some earlier code did its job, and that question belongs in a validator
at load time, not in a loop running a thousand times a tick. There are no nil
checks in the simulation, because there is nothing that could be nil.

## Directory layout

| Directory | Holds |
| --- | --- |
| `docs/` | The documents in this table of contents. `docs/HTML/` holds the generated browsable copy. |
| `notes/` | The vision, and anything not yet structured enough to be a document. |
| `src/` | The simulation and the viewer. Numbered files, each with a companion. |
| `libs/` | Third-party code, renumbered into a high band. |
| `assets/` | Sprites, sounds, catalogue data. |
| `issues/` | Issue files. `issues/completed/` for finished ones, `issues/completed/demos/` for phase demos. |
| `tmp/` | Symlink to `/tmp/hero-less-moba` — the executable tier, in RAM. |
| `tmp/shared-memory/` | Symlink to `/dev/shm/hero-less-moba` — logs, builds, and other non-executable artefacts, in RAM. |
| `input/` `output/` `desire/` `faith/` `strategems/` | Standing notes. The program reads `input/` first and writes goodbye to `output/` last. |

Nothing ephemeral is written into the repository. Logs go to `tmp/shared-memory/`,
and every script makes sure that directory exists before writing to it.

## Every source file carries the licence notice

This project is under the **GNU Affero General Public License, version 3 or
later**, and every source file it adds carries the standard notice near the top
in that file's comment syntax, ending with the SPDX line. The exact block is in
[COPYING.md](../COPYING.md).

**The file-creation tooling adds it, not a person.** The same rule that says never
create things manually applies here with particular force: a licence header is
the purest form of boilerplate, and hand-copied boilerplate is the kind that
silently rots — one file missing it, another carrying a version from two years
ago. The tool that stamps a new file with its index from the counter is the same
tool that should stamp it with its notice.

The AGPL rather than the GPL because this is a game people play against each
other over a network. Section 13 is the difference: a modified version that
people interact with remotely owes those people its source. Anyone running a
modified server owes its players the modifications.

## Scripts

Every script starts with a comment explaining what it is and how it works, at a
level a general could follow. Every script defines a hard-coded `${DIR}` at the
top pointing at the project root, accepts an override as its first argument, and
builds every other path relative to it — so that scripts run correctly from any
directory.

## Tests

There is a validator for the documents before there is a compiler for the code.
`./validate-documentation` checks that every link resolves, every issue is well
formed and present in its phase tracker, the roadmap agrees with the files, and
**no issue still cites an open question that has since been answered.** That last
check is the one that catches design rot: answering a question means editing the
document it changes, and it is easy to leave a dozen issue files claiming to wait
on something already settled.

Tests are cheap; make many. Every fixed bug gets a test that fails without the
fix. Two tests matter more than the rest and run on every build:

1. **Reproducibility.** Same machine, same binary, same seed, same commands, same
   result — tick for tick. It buys less than it would under lockstep, since the
   network reconciles rather than agreeing, but it is still the best regression
   test here: it fails the day someone adds a global random call or iterates a
   hash table whose order is not stable.
2. **Symmetry of the starting conditions.** The map is a mirror of itself, both
   teams begin with the same stone in the same places, and the same bodies leave
   both bases at the same tick. Any asymmetry *there* is a bug and this test finds
   it the day it is introduced.

   **Not tick-for-tick mirroring, which was the earlier claim and was wrong.** Two
   even sides diverge almost immediately and are supposed to: a tie broken one way
   in one lane is broken the other way in another, and by the second exchange the
   two halves of the field are different games. Trying to hold the mirror past the
   opening would mean a canonical ordering on every tie in the hottest loop in the
   simulation, bought to preserve a property that has no gameplay meaning after the
   first ten seconds.

   Set it up symmetrically. Do not try to keep it that way.

## Balance numbers do not live in prose

No document states a health value, a spawn interval, or a damage figure. Those
live in catalogue tables under `assets/` and are reported by the balance
validator. A document that quotes a number is a document that will be wrong.

Small tuning changes — turning knobs, pulling levers — are appended to
`docs/balance-updates.md` with the reason, and do not need an issue file.

Related: [the simulation tick](003-the-simulation-tick.md) ·
[the viewing layer](017-the-viewing-layer.md) ·
[the roadmap](019-roadmap.md)
