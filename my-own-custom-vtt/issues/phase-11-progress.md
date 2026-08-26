# Phase 11 — The second view, and the documentation

**Goal:** the generate-then-view split, tested where it is hardest to fake.

**Status: complete.** All seven issues done. `./run-phase-demo 11` runs one
session watched from two terminals and a browser at once, then builds the
documentation site, then prints every question the project has not answered.

This is the last phase. The roadmap has eleven and there are eleven.

## The issues

| Issue | What it established |
| --- | --- |
| [1101 the paintbrush travels as numbers](completed/1101-the-paintbrush-travels-as-numbers.md) | An appearance fits the wire this project already had. |
| [1102 the browser draws what it is sent](completed/1102-the-browser-draws-what-it-is-sent.md) | A view renders the paintbrush; it does not own it. |
| [1103 a second view in a terminal](completed/1103-a-second-view-in-a-terminal.md) | The same protocol, and what it found. |
| [1104 the documentation is a linked site](completed/1104-the-documentation-is-a-linked-site.md) | 287 pages, every one a click from every other. |
| [1105 the site is built by a tool](completed/1105-the-site-is-built-by-a-tool.md) | Never by hand, and not committed. |
| [1106 what the tool found](completed/1106-what-the-tool-found.md) | 165 dead links, in two classes, both structural. |
| [1107 the phase eleven demo](completed/1107-the-phase-eleven-demo.md) | The capstone of the project. |

## What is built

| Source | What it is |
| --- | --- |
| `102-watch` | A second view, in a terminal, speaking the same protocol. |
| `103-build-documentation` | Markdown to a linked site, in Lua. |
| `104-mend-links` | Repoints the links that moving a file broke. |
| `105-demo-phase-11` | The in-process half of the capstone. |
| `./build-docs`, `./mend-links` | The two front doors to the above. |

Plus a layer opcode in `056-protocol`, the appearance written through the one
door in `059-outbound`, the assembly in `067-view.js`, and `--place` on the
server so there is something worth two people looking at.

## Three things this phase taught

**A second consumer finds what a first one hides.** The hello — who you are and
how big the world is — had never once arrived. It was written at join time into a
buffer that the outbound path clears at the top of every beat. The browser had
run for six phases without receiving one and nobody noticed, because the only
thing it carried that the browser needed was which body is yours, and the browser
degraded to "none" silently and correctly.

A terminal cannot draw a map without the extent. It found the bug in its first
run against a live server. **That is what a second consumer is for**, and it is
worth stating that no amount of testing the first view would have found it: the
browser was working exactly as well as it appeared to.

**A closed vocabulary is what made the appearance sendable.** Because the
paintbrush is four shapes, three slots and five motions — every move a small
integer — a sprite fits a protocol designed before sprites existed. The
alternatives were porting the generator into every view, or adding a byte-string
field to the one place that decides what a viewer may know. Both end with two
things that can disagree about what a goblin looks like, with no error anywhere.

The decision that bought this was made in phase 9 for a completely different
reason.

**A link dies at the moment of success.** Finishing an issue means moving it into
`completed/`, which silently invalidates every relative link inside it. A hundred
and sixty were dead. The files still read fine in an editor and nothing had ever
complained.

The general shape: *a structural breakage that happens at the moment of success
is the one nobody checks for.* It became a tool rather than an afternoon, because
the breakage recurs on every completion, forever.

## What this phase deliberately did not do

**It did not answer the open questions.** There are fifty-two, sixteen of them
already answered and marked so, and the rest are live. The demo prints every one
by number rather than letting the project report itself finished while holding
them.

**It did not read `input/`.** The server honours one of the seven decisions that
file names — which world — and takes the rest as command-line defaults or
compiled-in constants. Including participants, which means the door admits
whoever knocks. That is open question 16.1, and it is the same hole as 4.2 seen
from a different side.
