# 501 — The recipe and the board

## Current behavior

The parts of the seed exist as separate things nobody has described as a whole.

## Intended behavior

Two descriptions that do not name each other: a **recipe** saying what the seed
is, and a **board description** saying what it runs on. Supporting new hardware
becomes a new description file and no code.

## Suggested implementation steps

1. Write the recipe: the engines, the weights, the instruction, the patterns, the
   carried device descriptions, and any bundled drivers — with versions pinned.
   It never names a board.
2. Write the board description: architecture, how the firmware locates something
   to start, which device the console is on and at what rate, what the board can
   boot from, how the medium is laid out, and where the description was
   transcribed from. It never names a part of the seed.
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
