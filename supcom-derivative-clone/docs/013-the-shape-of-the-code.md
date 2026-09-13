# 013 — The Shape of the Code

Not a datapath document. This is the house style: where files live, how they are
named, and the handful of rules that are not negotiable.

## Language

**LuaJIT.** Not Lua 5.4 — no integer division operator, no bitwise operators as
syntax, no goto-based control flow that 5.1 would reject. Bit operations go
through LuaJIT's `bit` library. Where a hot array of numbers is needed, an FFI
struct array is preferred over a Lua table, because the whole simulation is
arithmetic over flat arrays and that is precisely what LuaJIT is good at.

The handheld build is C, box by box, from the same design; see
[the handheld](012-the-handheld.md). The tests and tools are LuaJIT everywhere.

## Files are numbered, and the numbers are a reading order

Every file's name begins with a three-digit index. The indices count up across
the **whole project**, not per directory, so that reading the project in index
order is reading a story from the beginning: the design documents first, then
the tool that turns them into pages, then the tests that specify the source,
then the source. A hidden file at the project root, `.file-index-counter`, holds
the highest index in use; a new file takes the next one and bumps the counter.

Companion documents share their file's index: `020-the-dunes.lua` sits beside
`020-the-dunes.info.md`.

Third-party code brought into `libs/` is numbered into the 900 band so that a
reader who does not care about it can skip a contiguous range.

Issue files are the exception: they are numbered by phase and position, not by
the counter, because their number is a statement about what they rest on.

## Nobody creates a file by hand

`./new-source-file` claims the index, stamps the licence, and writes the
companion stub. `./new-document` does the same for a document. `./new-issue`
writes an issue's frame and adds its row to the phase tracker. Each accepts a
list, so a whole phase of files is one command rather than a race for the
counter. `./fill-source-file` rewrites a body without disturbing the licence, and
`./complete-issue` moves a finished issue into `completed/`, rewriting its links
and marking the tracker, so the record of what was built is kept by a tool too.

The rule behind the tools is the monorepo's: **never create things manually;
create the tools that create things.** A file made by hand has a licence header
copied from somewhere, a companion somebody meant to write, and an index
somebody guessed.

## Every source file has a companion

For each `NNN-name.lua` there is an `NNN-name.info.md` listing:

- every function the file exports, its arguments and their types, and what it
  returns
- every data structure it owns, its fields, down to the primitives
- what the file is for, in prose, treating its internals as a black box

**Read the companion, not the source.** The source is for when a specific
function is misbehaving. The companion is for everything else. A companion that
has drifted from its source is a bug of the same severity as a wrong answer.

## A document that is not true is a bug

The documents are not a description of the software. They are half of it. This
project had sixteen of them, seventy-odd issue files, and a test suite before it
had a line of source, and reconstructing the software means reading them — so a
page that no longer matches what runs is not untidy, it is **wrong**, at the
same severity as a wrong answer from a function.

It is fixed the same way: immediately, by whoever noticed, without asking. An
issue is not closed while the pages around it still read false.
`./validate-documentation` is the compiler for the prose and catches the
commonest rots; a paragraph that quietly stopped being true is what the rule
above is for.

## Comments say why, not what

A comment that restates the line below it is noise. The comments this project
wants are:

- **Why this exists.** What went wrong without it, or what it was chosen over.
- **What each branch means.** Every conditional gets a comment naming what each
  path leads to. A branch and its comment are edited as one unit.
- **What the data looks like.** Anything learned about a format, a range, an
  invariant, or an edge case goes in as a comment at the place it matters. If a
  fact will be needed twice, it is written down once, in the code.

## Functions are folded

Every function opens with a vimfold marker on its own line, carrying the comment
symbol and the function's name without arguments, then the definition:

    -- {{{ local function can_see()
    local function can_see(field, x1, y1, h1, x2, y2, h2)
      ...
    end
    -- }}}

The closing marker sits on its own line below the function's last line. Shell
scripts fold the same way with `#`.

## Dispatch tables over branches

Where a value selects behaviour — a system in the tick, a command verb, a
plane's mission, a unit's domain, a build target — the value indexes a table of
functions. Not an if-chain, not a switch. Adding a case is adding a row. The tick
order itself is a dispatch table, which makes the order of the simulation a
piece of readable data instead of something buried in a function body.

## Errors, not fallbacks

A fallback is a warning and a warning is an error. If a lookup fails, the
program stops and says what it was looking for and where. Silently substituting
a default turns one bug into a mystery discovered three systems downstream.

**Nil is not an option.** Fields that might be empty hold the integer zero, not
an absent value. Zero is a sentinel with a meaning; nil is a question about
whether some earlier code did its job, and that question belongs in a validator
at load time, not in a loop running a thousand times a tick. There are no nil
checks in the simulation, because there is nothing that could be nil.

The tests are built on the same rule. A test whose subject does not exist yet
does not skip; it fails, naming the file it looked for and the issue that
creates it. See [the tests come first](014-the-tests-come-first.md).

## Generate, then view

The simulation produces data; something else draws it. This is stated in
[the views](010-the-views.md) for the game and it applies to everything: the
dune tool produces a heightfield and the viewer shades it; the documentation is
Markdown and `./build-documentation` produces the pages; the tileset pipeline
produces images and the viewer loads them. Every time this split exists, a bug
has a side.

## Directory layout

| Directory | Holds |
| --- | --- |
| `docs/` | The documents in the table of contents. `docs/HTML/` holds the generated browsable copy. |
| `notes/` | The vision, and anything not yet structured enough to be a document. |
| `src/` | The simulation and the viewers. Numbered files, each with a companion. Empty until the tests say what goes in it. |
| `tests/` | The specification: one numbered program per cluster of mechanics, each naming the issues it covers. |
| `scripts/` | Tools that read the project rather than run it: the documentation generator. |
| `libs/` | Third-party code, numbered into the 900 band, installed from the manifest. |
| `assets/` | The catalogue tables and, later, the generated tileset. |
| `issues/` | Issue files. `issues/completed/` for finished ones, `issues/completed/demos/` for phase demos. |
| `tmp/` | Symlink to `/tmp/supcom-derivative-clone` — the executable tier, in RAM. |
| `tmp/shared-memory/` | Symlink to `/dev/shm/supcom-derivative-clone` — logs, builds, and other artefacts, in RAM. |
| `input/` `output/` `desire/` `faith/` `strategems/` | Standing notes. The program reads `input/` first and writes goodbye to `output/` last. |

Nothing ephemeral is written into the repository. Logs go to `tmp/shared-memory/`,
and every script makes sure that directory exists before writing to it.

## Every source file carries the licence notice

This project is under the **GNU Affero General Public License, version 3 or
later**, and every source file it adds carries the standard notice near the top,
ending with the SPDX line. The exact block is in [COPYING.md](../COPYING.md).
The file-creation tooling adds it, not a person.

The AGPL rather than the GPL because this is a game people play against each
other over a radio and a wire. Section 13 is the difference: a modified version
that people interact with remotely owes those people its source.

## Scripts

Every script starts with a comment explaining what it is and how it works, at a
level a general could follow. Every script defines a hard-coded `${DIR}` at the
top pointing at the project root, accepts an override as its first argument, and
builds every other path relative to it — so that scripts run correctly from any
directory. Scripts read `input/` first and write `output/goodbye` last.

Where a script chooses between behaviours by a name or a word — which build to
make, which job a symlinked name asks for — it uses a table, not a chain.

## Balance numbers do not live in prose

No document states a health value, a heal interval, or a cost. Those live in
catalogue tables under `assets/` and are reported by tools. A document that
quotes a number is a document that will be wrong. The vision's own starting
numbers are quoted as the vision's, once, and the catalogue is the authority.

Small tuning changes — turning knobs, pulling levers — are appended to
[the balance ledger](balance-updates.md) with the reason, and do not need an
issue file.

Related: [the tests come first](014-the-tests-come-first.md) ·
[the roadmap](015-roadmap.md)
