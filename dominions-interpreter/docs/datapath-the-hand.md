# Datapath — the hand

*Writing orders into the game's own file, and letting the game be the judge of
whether they are orders.*

## The path

    the ledger
        │
        ▼
    a working copy of the savegame      (never the live one)
        │
        ├─ start from the game's own .2h, and change bytes in it
        │
        ▼
    dom6_amd64 --verify <game>          the game judges the file
        │
        ├─ rejected ──► nothing is installed, the ledger is kept, say what happened
        │
        ▼
    dom6_amd64 --host <game>            the game resolves the turn
        │
        ▼
    a new .trn ──► read it, diff it, narrate what actually occurred

## Mutate, never compose

The hand does not build a `.2h` from nothing. It starts from the one the game
last wrote and changes the fields it understands.

An orders file is mostly the player's retained view of the world — province
records, event histories, things this program did not create and has no reason
to recreate. Composing all of that from scratch would mean understanding
everything in order to change one thing. Copying it forward and editing the
order fields means understanding only what is actually being changed, and the
cost of a gap in that understanding is a field left as it was rather than a
file full of plausible rubbish.

It also means the record offsets and raw bytes the reading kept are exactly
what is needed here, which is why it keeps them.

## `--verify` is the whole strategy

    dom6_amd64 --verify <game>    verify all 2h-files and exit (creates .chk files)

The game will tell you whether a file is a valid orders file. That single
documented flag is what converts this project's riskiest part from *"be right
about an undocumented binary format"* into *"be checkable against the program
that defines the format"*.

Two consequences follow, and both are structural:

**Nothing unverified is ever installed.** A written file that the game rejects
does not reach a savegame folder. The failure is reported in words, the ledger
survives, and the turn can still be typed in by hand.

**The format can be learned by experiment rather than by staring.** Change one
thing in the game, save orders, compare the two files: the bytes that differ
are the bytes that mean that thing. `--verify` confirms each attempt, `--host`
proves it. That is a slow, reliable method with a truth oracle at every step,
and it is the method — not a hope that the layout will become obvious.

The experiments have to be run **against a copy of a game nobody is playing**,
and they need a person to operate the game's interface. That is the one part of
this project that cannot be done by a program alone, and it is written down as
such rather than discovered later.

## The vocabulary grows one order at a time

The hand starts able to write nothing and grows an order type at a time, each
added only once an experiment has established where it lives and `--verify`
accepts it.

| Order | Status |
|---|---|
| everything | not yet established |

That table is the honest state of the project's hardest component and it is
kept here, updated as each order type is won. An empty table is not a
disappointment; it is the reason the ledger is designed to be useful without
this document's contents ever being filled in.

## Never the live savegame

The hand works under `work/`, on a copy. The rendered map data — tens of
megabytes per game, inert for the life of the game — is linked rather than
duplicated.

Installing a turn back into the live savegame directory is a **separate,
explicit act**, done after `--verify` has accepted the file, and it makes a
backup of what it replaces first. The game itself offers `--backup`, which tars
the save before hosting on Linux, and the hand uses it.

Corrupting an in-progress game to save a directory copy is not a trade worth
making. The games in the local collection go back years.

## Cheat detection

Dominions has cheat detection — there is a `--nocheatdet` flag to turn it off,
which is how we know. A hand-written orders file may need to satisfy it, and
whether it does is not yet known.

This is written down now because it is the kind of thing that is much more
alarming to discover during the first real turn than to have expected. If it
turns out that files this program writes are rejected, the ledger path still
works and the fix is a research problem, not a redesign.

## Hosting, and where this program hooks in

    dom6_amd64 --host <game>     generate new turn and exit

No graphical interface at any point. The whole loop — read, talk, write,
verify, host, read again — runs headless, which is what makes the accessibility
goal reachable rather than aspirational.

For games hosted elsewhere, `--preexec` and `--postexec` run a command around
each new turn, which is the hook by which this program can be told a turn has
arrived rather than polling for it.

## Related

- [The file format notes](dominions-file-formats.md) — what is established about the bytes
- [The ledger datapath](datapath-the-ledger.md) — what the hand consumes, and why it stands alone
- [The reading datapath](datapath-the-reading.md) — where offsets and raw bytes are kept
