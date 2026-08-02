# 501 — The recipe and the board

## Current behavior

**Done, and tested** -- `src/088` holds both descriptions and the rules they
must satisfy, `input/example-recipe.lua` is one, `src/090` checks them, 34 of
34 on 2026-08-02 across this ticket and the two below it.

The two never name each other, and that is enforced rather than intended: a
recipe mentioning a machine is refused with the reason said plainly -- a
recipe that names a board has become a recipe FOR that board, and supporting
another means editing it rather than writing beside it. A board description
naming a part of the seed is refused the same way.

The six board descriptions already in the tree pass these rules unchanged.
They were written for the emulator harness before there was a builder to read
them, and an emulated machine is a board, so they are the same kind of thing.

**The where-it-looks field turned out to have two honest shapes.** Some boot
schemes carry the answer in themselves -- a BIOS always reads sector zero,
and repeating that in the description would be a second copy of a fact that
cannot vary. The schemes that DO vary must say, and that is the load-bearing
half. Making every description repeat it would have been the tidier rule and
the wrong one.

Adding a board requires touching nothing else, which is the whole portability
claim, and it is tested by inventing one during the test run and building for
it.

## Intended behavior

Two descriptions that do not name each other: a **recipe** saying what the seed
is, and a **board description** saying what it runs on. Supporting new hardware
becomes a new description file and no code.

## Suggested implementation steps

1. Write the recipe: the engines, the weights, the instruction, the patterns, the
   carried device descriptions, and any bundled drivers — with versions pinned.
   It never names a board.
2. Write the board description: architecture, how the firmware locates something
   to start **and where it looks for it**, which device the console is on and at
   what rate, which storage controllers to expect, what the board can boot from,
   how the medium is laid out, and where the description was transcribed from. It
   never names a part of the seed.
3. The "where it looks" field is load-bearing rather than incidental. Nothing
   shared can detect a processor and choose an engine (`402`), so the way each
   architecture ends up running its own code is that its firmware finds only its
   own payload in the place its convention names. That place is board knowledge,
   and the builder in `502` needs it to lay the medium out.
3. Record what each board description was transcribed from, for the same reason
   the device descriptions do (`302`) — a transcription whose source is not named
   cannot be re-checked when a board revision lands.
4. Provide a description per target board, and make adding one require touching
   nothing else. This is the whole portability claim and it is worth testing by
   adding one.
5. **Bake nothing secret and nothing machine-specific in.** An image is copied
   onto every card in a batch, and anything particular to one machine is
   particular to all of them. The seed is generic by construction; everything
   individual about a machine happens after it wakes.

## Blocks

`502`.

## Blocked by

`402`.

## Related documents

`docs/003-datapath-the-bootstrap.md` — the three ways an image could be made, and
where this one sits on that ladder.
