# dominions-interpreter — architecture

## What it is

A way to play a turn of Dominions 6 by talking to a computer about it.

You sit down, the machine tells you where your gods and generals are and what
happened to them since last time, you talk it over, and at the end of the
conversation a turn has been played — not simulated, not approximated, but
written into the game's own orders file and resolved by the game's own
executable. The interface is a conversation. The rules are Dominions'.

The vision asks for six things, and they are worth separating because they fail
differently:

1. read a Dominions 6 save file and use it as context
2. carry the previously generated messages forward as context too
3. run the models on three little machines over llama.cpp
4. talk, in character, with the people involved
5. **save the intended moves and resolve them with the actual game system**
6. tie previous events into the moment — *without* inventing connections

Number five is the one that makes this a program rather than a chat about a
screenshot. Number six is the one that makes it trustworthy. The rest is
plumbing, and good plumbing.

## The loop

    .trn + ftherlnd ──► the reading ──► the world, as a table
                                            │
                            the chronicle ──┤
                        (what was said and  │
                         what happened)     ▼
                                        the doors ──► conversation
                                     (three machines)      │
                                                           ▼
                                                      the ledger
                                              (intended moves, plain text)
                                                           │
                                                           ▼
                                                       the hand
                                            (write .2h, then --verify)
                                                           │
                                                           ▼
                                                   dom6 --host
                                                           │
                                                           └──► new .trn, loop

Six stages, each with one job, each able to be run and inspected alone. The
seams are files, not function calls, which is deliberate: a conversation is
expensive and unrepeatable, and every seam is a place work can be picked back
up after something goes wrong.

## The parts

### The reading

The savegame is three files. `ftherlnd` is the world as the host knows it —
every province, every nation, the truth. `<nation>.trn` is the world as *your*
nation knows it, which is smaller and is the one that matters, because a
narrator who can see through the fog will spoil the game in its first sentence.
`<nation>.2h` is what you hand back.

All three are the same format, disguised by a single exclusive-or, and their
interiors are arrays of fixed-stride records. What is established and what is
not is set out in [the file format notes](dominions-file-formats.md); how the
bytes become a world is [the reading datapath](datapath-the-reading.md).

**The reading never guesses.** A field it cannot place is absent from the world
table, not defaulted to zero. A narrator given a zero cannot tell it from a
real zero, and will say your treasury is empty when the truth is that nobody
has found the treasury field yet.

### The court

Dominions gives its commanders names. In the game read while writing this,
Pangaea's officers are called Peisandros, Cheiron, Lakedaimon, Sidon, Paeon,
Imbrios, Alastor, Elone, Paller, Pandion, Euaimon, Pleuron, Philia and
Uranokles. Those names come out of the save file, and so do their titles, their
magic, their wounds, and where they are standing.

The court is the cast list: the subset of the world that can be spoken *to*
rather than spoken *about*, with each member's dossier assembled from the world
table. Roleplay is not decoration here — it is how the interface works. "Ask
Cheiron what he can see from the mountain" is both a piece of theatre and a
query against the province adjacency table.

See [the court datapath](datapath-the-court.md).

### The chronicle

Append-only, one file per game, checksum-chained, plain text, readable while
being written. It holds three kinds of line: what the world was at the start of
a turn, what was said during the conversation, and what actually happened when
the turn resolved.

That third kind is the one that earns the whole structure. A system that
remembers only its own words will drift into a story it made up. Every
conversation is anchored by the *outcomes* of previous turns, which are facts
from the game, not from a model.

See [the chronicle datapath](datapath-the-chronicle.md).

### The doors

A **door** is an address that answers. Three mini computers running
`llama-server` are three doors; what is behind one is not this program's
business. The roster lives in `input/cluster`, one line per door, in the format
`gif-generator` and `backwards-reader` already use, because three programs on
one network should not disagree about how to name machines.

Three doors, three standing roles:

| Role | Answers | Refuses |
|---|---|---|
| **The herald** | narrates the world and voices the court | to state anything the world table does not contain |
| **The steward** | turns what was agreed into ledger entries | to invent an order it cannot map to a real one |
| **The remembrancer** | finds what in the chronicle bears on now | to connect things that only *resemble* each other |

The roles are assigned to doors, not baked into them. A door can hold more than
one role and a role can fall back to a busier door — but a role with no door is
a stopped program, not a degraded one. See
[the doors datapath](datapath-the-doors.md).

### The ledger

The intended moves, written as plain text a person can read, edit, and keep.

The ledger is the deliverable, not the `.2h`. If the writing step fails
forever, a ledger read aloud is still a playable turn — someone types it in.
That property is load-bearing for the accessibility goal, and it is the reason
the ledger is a file with its own format rather than an intermediate value.

Every entry names the commander, the order, and **the sentence in the
conversation it came from**. An order nobody can trace back to something that
was actually said is a bug, and the format makes it visible.

See [the ledger datapath](datapath-the-ledger.md).

### The hand

Writes the ledger into a `.2h`, then asks the game whether it is a valid one.

    dom6_amd64 --verify        checks every .2h and writes .chk files
    dom6_amd64 --host          generates the new turn and exits

Both are documented command-line options of the shipped Linux binary. They are
the two facts that make this project tractable: **we do not have to be right
about the file format, we have to be checkable.** The hand writes, the game
judges, and a file the game will not accept never reaches a savegame folder.

The hand also never writes into the real savegame directory. It works on a copy
under `work/`, and installing a turn back into the live game is a separate,
explicit act. Corrupting an in-progress game to save a directory copy is not a
trade worth making.

See [the hand datapath](datapath-the-hand.md).

## The rule about connections

> *not everything is related to everything else, so it's better to make
> accurate assumptions than fearless deductions*

This is the sharpest sentence in the vision and it is a design constraint, not
a mood. A narrative engine's characteristic failure is that it will always
find a thread, because finding threads is what it is for. Ask it why your
mage died and it will tie the death to a prophecy from turn four whether or
not the two have anything to do with each other, and it will do this
fluently, which is what makes it dangerous.

So the remembrancer's answer set includes **"nothing in the chronicle bears on
this"**, and that answer is a success. Three mechanisms hold the line:

1. **A connection must name its evidence.** Every claimed link cites the
   chronicle line it came from. A link with no citation is dropped before it
   reaches the narrator, not argued with.
2. **Resemblance is not connection.** Nearness in embedding space nominates a
   candidate; it never confirms one. Confirmation requires a shared concrete
   referent — the same province, commander, item, or spell — which is a lookup
   against the world table, not a judgement.
3. **The prose is marked.** Narration that rests on a cited link reads
   differently from narration that is only scene-setting, and the record keeps
   the two apart so a wrong connection can be found later.

Stated in general, away from this project:
`strategems/a-connection-must-name-its-evidence.md`.

## Who this is for

The vision names players who are vision impaired, or who cannot get past the
interface. That is not a nice-to-have bolted on at the end; it is the
**acceptance test**, and it decides several things that would otherwise be
matters of taste:

- The primary surface is a terminal conversation, which screen readers already
  handle well. No curses layout, no spatial UI, no information carried only by
  colour or position.
- Every piece of state is reachable by asking for it in words. If the only way
  to learn something is to look at a map, that is a missing feature.
- The game's own map is not required at any point in the loop. Reading,
  talking, writing, verifying and hosting all happen without the GUI ever
  opening.
- Output is linear and re-readable. You can ask for the last thing again.

A sighted player who simply dislikes the interface gets the same program, which
is the usual way of it.

## Language and dependencies

LuaJIT 2.1. Three dependencies, all already on the shelf at
`/home/ritz/programming/ai-stuff/libs/lua/`:

| What | Why |
|---|---|
| `dkjson.lua` | llama.cpp speaks JSON |
| `luasocket` | HTTP to the doors |
| `effil-jit` | real threads, if a measurement ever asks for them |

No model runtime is vendored, and no Dominions code is. The game is reached the
way any other program reaches it: by writing files it reads and running its
executable with documented flags.

## Testability

Everything that talks to a model takes its **transport as an argument** — a
plain function from request to reply. Tests hand in a fake. The whole program
above the socket is therefore testable on a machine with no cluster, which is
the machine it was written on.

Everything that talks to *Dominions* is tested against the real local
collection of savegames, which is large and varied and includes games from
several versions and with several mods loaded. A parser that agrees with a
hundred real files is a parser worth trusting; one that agrees with a fixture
somebody wrote by hand is not.

The one thing that cannot be tested without the game is the hand, and the game
supplies the test itself: `--verify`.

## Source order

Source files are numbered so the project reads front to back as one story,
counting up across directories rather than within them. Each module is followed
by the test that proves it, and each has an `.info.md` beside it describing what
it offers without requiring anyone to read the code.

## Related documents

- [The file format notes](dominions-file-formats.md) — what is known about the bytes, and what is not
- [The reading datapath](datapath-the-reading.md) — savegame to world table
- [The court datapath](datapath-the-court.md) — who can be spoken to
- [The chronicle datapath](datapath-the-chronicle.md) — the append-only memory
- [The doors datapath](datapath-the-doors.md) — the cluster and its three roles
- [The ledger datapath](datapath-the-ledger.md) — intended moves as plain text
- [The hand datapath](datapath-the-hand.md) — writing orders and having them judged
- [Roadmap](roadmap.md) — the phases
- [Table of contents](table-of-contents.md) — every document, indexed
- `notes/vision` — the original ask, unedited
