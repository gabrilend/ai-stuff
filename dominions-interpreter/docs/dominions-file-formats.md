# Dominions 6 file formats — what is known, and how

Nothing here comes from the publisher. Illwinter ships format notes with the
game (`dom6fileformats.pdf` in the Dominions folder) and they describe the
*map* format thoroughly and say nothing about savegames. Everything below was
established by reading the files in the local collection.

Two rules govern this document:

- **No count, size or offset is quoted as a literal anywhere else in the
  project.** The survey tool reads the real files and reports what is currently
  true; prose describes shape, tools report numbers.
- **A claim here is marked with how it was established.** "Confirmed across the
  collection" and "seen in one file" are different kinds of fact and mixing
  them is how a parser ends up confidently wrong.

The obfuscation and the world-state header were first worked out by the
**chronicler** project, which lives in the Dominions folder itself and
version-controls savegames. This project re-derived them independently against
the same collection and then went further into the record arrays, which
chronicler deliberately never needed to open.

---

## The obfuscation

**Every byte of a Dominions save or configuration file is exclusive-or-ed with
`0x4F`.** No key, no rotation, no compression, no per-file or per-version
variation. Undo it and the file is plain text mixed with plain binary.

*Established:* the same constant recovers readable game names, mod names, map
titles, province names and event text from every save in the collection, across
several game versions and with mods loaded or not.

Two consequences worth holding on to, because both bite:

**A zero byte reveals as `0x4F`.** Dominions stores strings null-terminated, so
after the exclusive-or the separator between every string is the constant
itself. String walking is therefore structural — split on the separator —
rather than a hunt for readable-looking runs.

**A raw zero byte reveals as the capital letter `O`.** Padding and the letter O
are the same byte. This is a genuine ambiguity, not a shortcut waiting to be
tidied up, and it has already caused one wrong measurement during this
project's own investigation: a naive scan for name-shaped text swallowed three
bytes of leading padding into every name and reported a record stride three
bytes short. Any tool that reads names must resolve the ambiguity explicitly
and must say which way it resolved.

Applies to: `dom6config`, `ftherlnd`, `<nation>.trn`, `<nation>.2h`.
Does not apply to: `.map` files (already plain text), `.tga`, `.d6m`.

---

## The header, shared by all three savegame files

Byte offsets from the start. Integers are little-endian and **not** obfuscated;
the disguise covers the text runs only.

| Offset | Width | Meaning |
|---|---|---|
| `0x00` | 3 | Format marker, constant across every observed file |
| `0x03` | 3 | The characters `DOM`, stored plainly — the signature |
| `0x0A` | 2 | Game version × 100. `636` is Dominions 6.36 |
| `0x0E` | 2 | Turn number, as the game displays it |

*Established:* read out of every started save in the collection at once. Every
version recovered is a real published Dominions version, older saves report
older versions, and every turn number lands in a plausible range with new games
low and long-running games high. A pretender-submission file reports turn zero,
which is correct — that game has not started.

The version field records the version that last **wrote** the file, not the one
that created the game.

---

## `ftherlnd` — the world as the host knows it

Present only once a game has started. A savegame folder without one is either
awaiting pretender submissions or an abandoned shell.

After the header comes a run of null-terminated strings, in this order:

1. the game name, matching the folder it sits in
2. for each enabled mod: its `.dm` filename, then **the folder that contains
   it**
3. for each map layer: a readable layer title, then the layer's `.map` file,
   then its `.d6m` file

The mod folder names being stored here is the most consequential small detail
in the format. Dominions finds a mod at `mods/<folder>/<file>.dm` and the save
records both halves; rename the folder and the save can no longer load. This
project only reads them, but it must read them, because **mods change what
units and spells exist** and a narrator that names a unit from unmodded data
will name the wrong unit.

*Established:* the layer titles recovered are the game's own
(`Pantokrator's Realm`, `The Realm Beneath`, `The Void`), each followed by map
files whose names match files on disk.

---

## `<nation>.trn` — the world as one nation knows it

Same header, same obfuscation, same opening string run — game name, mods, a
readable version string, then the map layers. After that the file is the
nation's own view: the provinces it can see, what it knows about them, its
commanders, its messages for the turn.

**This is the file the interpreter reads.** `ftherlnd` knows everything, which
is exactly what a narrator must not be handed. Reading the world from the turn
file is what keeps the fog of war intact for free rather than by discipline.

The nation is identified by the filename, not by anything found so far inside
the file.

---

## `<nation>.2h` — what the player hands back

Not just orders. An orders file carries the player's whole retained view of the
world, which is why it runs to a hundred and sixty thousand bytes in a
mid-length game rather than a few hundred.

Observed, in order:

**Province records.** Each holds its name twice in succession, surrounded by
binary fields. Following the names is that province's event history as readable
prose with a dated heading — `Winter in the year 2 of the ascension wars:`,
then `Northia was conquered by Pangaea`, and so on back through the game.

This history is a gift for the narrative side of the project. It is the game's
own account of what has happened where, already written in the game's voice,
already attached to a place. It is not a summary this project has to generate,
and being a fact rather than a generation, it is safe to build connections on.

**Commander records, at the tail.** A fixed-stride array. The name is the only
text; everything else is binary. A record is a fixed part, then the name, then
its terminator.

*Established:* by measurement across every orders file in the collection, not
by eye. Run `./survey --deep` for the current figures — the count of files
measured, the stride found in each, and the distribution across all of them.
The claim the project relies on is the *shape* of that distribution: **one
stride dominates, and it is the same one in nearly every file.** If a future
run reports two, something has changed and the survey is where it shows.

Getting there took two corrections, both worth recording because both are the
kind of mistake that looks like a finding:

- The stride was first worked out by eye from four records and was three bytes
  wrong. Raw zero padding reveals as the capital letter `O`, and a scan for
  name-shaped text swallowed the padding into every name.
- Stripping the *leading* zeros from a name run fixed most files and split the
  collection into two apparent strides. The cause is a small binary field a few
  bytes before each name: when it holds `1` it reveals to the letter `N`, so
  the run starts at the binary byte and there is no leading zero left to strip.
  Taking the name to start after the **last** zero in the run — the same rule
  the string walk already used — collapsed the two strides into one.

The second correction is the useful one to remember. Two competing strides
looked exactly like a real format difference between game versions. It was a
bug in the reader.

The names recovered from the tail of a Pangaean save are that nation's
officers. Names beginning with a capital `O` come back clipped — *Odysseus*
reads as *dysseus* — which is the documented cost of resolving the padding
ambiguity towards padding.

*Not established:* which byte inside a commander record holds the order, the
target province, or the army setup. That is the open problem, and it is
addressed by experiment rather than by staring — see below.

---

## What the game will tell you about a file

Two documented options of the shipped Linux executable turn this from
reverse-engineering into a conversation with the game:

    dom6_amd64 --verify <game>     verify all .2h files, write .chk files, exit
    dom6_amd64 --host <game>       generate the new turn and exit

`--verify` is the oracle. A written orders file does not have to be *understood*
to be trusted — it has to be *accepted*, and the game itself says whether it is.
This is the single most important fact in this document, because it converts
the risky part of the project from "be right about an undocumented binary
format" into "be checkable against the program that defines it".

It also supplies the method for the open problem. Change one thing in the game,
save orders, and compare the two files: the bytes that differ are the bytes
that mean that thing. Repeated with a plan, that is a map of the order fields;
`--verify` confirms each step, and `--host` proves it.

Related flags worth knowing about:

| Flag | Why it matters here |
|---|---|
| `--statusdump` | player state in a parsable format, continuously |
| `--statfile` | a player info file after each turn |
| `--preexec` / `--postexec` | run a command around each new turn — where this program hooks in |
| `--nocheatdet` | cheat detection exists; a hand-written orders file may need to satisfy it |
| `--backup` | tar the save before hosting, on Linux |

---

## What a savegame folder contains

| Pattern | Changes | Rough size |
|---|---|---|
| `ftherlnd` | every turn | millions of bytes, growing |
| `<nation>.trn` | every turn | hundreds of thousands |
| `<nation>.2h` | whenever orders are saved | tens of thousands |
| `__*.map` | never after generation | tens of thousands |
| `__*.d6m` | never after generation | **tens of millions** |
| `*.tga` | never after generation | large |

The rendered map data dominates the folder and is inert for the life of the
game. This project never reads it and never copies it — a working copy of a
savegame links it rather than duplicating it.

---

## Where the numbers come from

Run the survey tool. It reads the real collection and reports what is true now:
how many savegames exist, which have started, what turn each is on, which
version wrote it, which mods it needs, and — for the record arrays — what
stride is actually observed rather than what this document remembers.

If a document and the tool disagree, the tool is right and the document is
stale. Fix the document.

## Reading list

- [Architecture](architecture.md)
- [The reading datapath](datapath-the-reading.md) — bytes to world table
- [The hand datapath](datapath-the-hand.md) — writing orders and having them judged
- [Table of contents](table-of-contents.md)
