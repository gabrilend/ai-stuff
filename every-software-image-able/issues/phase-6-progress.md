# Phase 6 — Waking

**Goal.** A card goes into a computer with nothing on it, and the computer starts.
Then, unaided, it writes an allocator, finds storage, moves in, and comes back
after a power cycle still knowing what it learned.

This is the only phase that proves anything. The other five produce parts that can
be tested alone.

## Issues

| | | Status |
|---|---|---|
| `601` | First light | not started |
| `602` | The first thing it writes | not started |
| `603` | The demos, and the thing that runs them | not started |

## Where the risk is

Everywhere, and mostly in seams rather than in parts. Offsets the builder and the
engine disagree about. Firmware handing over in a state nobody tested against.
Memory the map calls usable that is not.

`602` is where the text written in phase 3 is judged, and the judging is
uncomfortable: the machine must be left alone. A helped machine proves nothing
about an unhelped one, so the first attempt at the allocator must be allowed to
fail without correction, and the failure fixed in `301` rather than at the
keyboard.

The way to make that bearable is to stop judging single machines. The draw is
deterministic per seed and the seed is a build parameter, so twenty images
differing in nothing but their randomness give a success rate rather than an
anecdote — and the ones that fail differently from each other say more than the
ones that fail alike.

Three outcomes would count as failure, and each points at a specific document
rather than at the idea: hardware damaged during exploration (`003a`), the weights
overwritten (`301`), no working assembly produced at all (`303`).

## After this

Nothing is planned. What the machine builds, in what order, and what it does when
it runs out of room to build, are the first observations anybody has of this kind
of machine — and they belong in `notes/`, not in a ticket.

## Demo

The machine, running from its own storage, narrating what it has built since it
was left alone.
