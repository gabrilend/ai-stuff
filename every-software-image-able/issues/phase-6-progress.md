# Phase 6 — Waking

**The capstone changed on 2026-08-21.** It was *write an allocator unaided* and it
is now *install yourself*: find a disk, do not destroy what is on it, write yourself
there in a form the firmware will start, confirm it starts, and keep running after
somebody pulls the card.

The allocator lost its subject when the seed began carrying one, under a rule that
says to carry anything trivial-and-required or unique-to-the-silicon and to tell the
machine it may rewrite it. Marking memory as in use is both, and there is not much
art in it.

The install is a better test for three reasons, and they are in `602`: it cannot be
half-done or faked, it exercises nearly everything at once, and it is the one step
that makes the seed a seed — the card comes out and the machine keeps existing.

Whether machines rewrite the allocator they were handed is still watched. It is no
longer the thing being proved.

**Goal.** A card goes into a computer, and the computer starts. Then, unaided, the
machine finds a disk, writes itself onto it in a form the firmware will start, and
comes back after a power cycle with the card out and what it learned still present.

This is the only phase that proves anything. The other five produce parts that can
be tested alone.

## Issues

| | | Status |
|---|---|---|
| `601` | First light | not started |
| `602` | The first thing it writes | not started |
| `603` | The demos, and the thing that runs them | **completed** — five demonstrations and the script that asks which to show |

## Where the risk is

Everywhere, and mostly in seams rather than in parts. Offsets the builder and the
engine disagree about. Firmware handing over in a state nobody tested against.
Memory the map calls usable that is not.

`602` is where the text written in phase 3 is judged, and the judging is
uncomfortable: the machine must be left alone. A helped machine proves nothing
about an unhelped one, so the first attempt at the install must be allowed to fail
without correction, and the failure fixed in `301` rather than at the keyboard.

**And the failure to be most careful about has a victim.** A machine that gets the
partition table wrong loses every partition on the disk at once. So the disk it is
left alone with should be one somebody is willing to lose, and it should have real
files on it, because a blank disk does not test the rule about assuming there is
data.

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
