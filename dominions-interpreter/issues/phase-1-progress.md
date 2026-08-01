# Phase 1 — The Reading — progress

*A savegame becomes a table describing a world.*

The goal of this phase is that the program can be pointed at any savegame in
the collection and produce a readable account of what is in it, with nothing
guessed and everything it could not place said out loud.

Run `./survey /path/to/.dominions6` for the current state of the collection and
`./tests-run` for the current state of the checks. Neither number is written
into this file, because both would be wrong within a month.

---

## Where the phase stands

| Issue | State |
|---|---|
| `101-the-input-gate` | complete |
| `102-seeing-through-the-disguise` | complete |
| `103-the-header-without-the-file` | complete |
| `104-the-string-run` | complete |
| `105-the-record-arrays` | complete |
| `106-the-world-table` | **not started** |
| `107-the-survey` | complete |
| `108-the-narrator` | complete |

The phase is not finished. The world table is the piece everything downstream
is handed, and until it exists the parts below it are a set of readers rather
than a reading.

## What the phase can do now

Point `./survey` at a Dominions folder and it reports, per savegame: what turn
it is on, which version last wrote it, which nations have been played in it,
and which mods it declares. With `--deep` it opens the orders files, measures
the record arrays inside them, and reports the stride distribution and how much
of each file has been accounted for.

The last of those is the honest measure of where the format work stands, and it
is small. It should be.

## What the collection taught the code

Three defects were found by running against real savegames rather than
fixtures, and all three would have survived a hand-written test.

**A savegame called `H2`.** A three-character minimum string length dropped its
name entirely, so the first string found became the first mod's filename, and
the game-name check reported a disagreement that was the reader's fault rather
than the file's. The floor is now two.

**Two competing record strides.** Measured across the collection, orders files
split into two apparent strides three bytes apart. It looked exactly like a
format difference between game versions. It was a bug: a binary field holding
`1` reveals to the letter `N`, so name runs began at the binary byte and no
leading zero was left to strip. Taking the name to start after the *last* zero
in the run collapsed the two into one and found more records per file besides.

**An assertion written backwards.** The test claiming a raw zero reveals to the
letter `O` asserted that it does not. The test suite caught it on its first
run, which is the argument for writing the assertion out even when the fact
feels too obvious to state.

## What is left before the phase closes

**The world table.** Issue 106. It needs province records parsed, which means
parsing the event history that follows each province name — the game's own
dated prose, which is the most valuable text in the file for everything
downstream and is not yet read.

**A survey test.** Number `009` is reserved for it and the file is not written.
The survey is currently proved only by running it, which is not the same thing.

**The mods question.** Savegames declare which mod folders they need and the
survey reports them, but nothing checks whether those folders exist. The
function to do it is written and unused.

## Open questions raised by this phase

These are carried forward, not closed. Each needs answering with a person
before the phase can be called finished.

1. **Should more than one game be playable in one session?** The design assumes
   one, which keeps the chronicle unambiguous.
2. **The header version and the readable version string disagree** in observed
   files — the header says one thing, the text says another. Which is
   authoritative is unknown, and both are currently reported.
3. **Bytes `0x06` to `0x09` of the header are consistent and unexplained.**
   Possibly a build identifier, possibly a checksum. Not needed yet.
4. **Are the names at the tail of every orders file commanders?** Confirmed for
   a save whose officers were recognisable. In another game the tail names
   include words like *Whitewood* and *Butterfly*, which could as easily be
   provinces. This needs settling before anything calls the array a cast list.
5. **Are provinces in an orders file the ones the nation can currently see, or
   every one it has ever seen?** The distinction matters for a narrator
   describing what is visible now.
6. **Do record strides differ between game versions?** Eighteen versions are
   represented in the collection and one stride dominates, which is evidence
   but not proof — the older saves are also the smaller ones.

## Related

- [Roadmap](../docs/roadmap.md)
- [The file format notes](../docs/dominions-file-formats.md)
- [The reading datapath](../docs/datapath-the-reading.md)
