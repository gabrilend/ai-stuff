# 207 — Emit a status

## Retired 2026-08-21

**The status system was removed from the design and its code was deleted.** What
this ticket built — three numbers after every action, an aspect shown as a colour
and a shape, a per-program code, a magnitude with fifty as ordinary, a dispatch
table of meanings each machine builds for itself, and a display that falls back
from lamps to a screen to a wire — all of it is gone.

> I think we should remove the post-code system from the design entirely, it seems
> a little arbitrary and out of place. Like I like the vision of it, but... we want
> to make minimal software that just works, and this is introducing something that
> is complex for no reason.

**What replaced it** is in `docs/006`, which is a different document under the same
number now: the mind runs on its own thread, anything that might not stop runs on
another, the machine times them, and it deals with the ones that take too long.
Nothing is emitted, nothing is displayed, and nothing has to be looked up.

**Why it is worth reading anyway.** The mechanism this ticket built was load-bearing
in a way nobody intended: the two-digit magnitude was also being used to count loop
iterations, so a program was declared a runaway after fifteen turns of a loop —
copying a hundred bytes, summing twenty numbers. That defect is the strongest
argument for the removal, and it happened because one number was serving a picture.

**What was kept.** The three ways a machine can speak — lamps, a screen, a wire —
and the refusal to believe it spoke when nothing took the message. Those live in the
say-something work (`202`) and were never really about statuses.

**The ticket stays here** because tickets are never deleted, and because a reader
recreating this project from the completed directory needs to know that this step
existed, what it cost, and that it should not be built.

---


## Current behavior

**Built, tested at 24 of 24 on 2026-08-02, and deleted on 2026-08-21.** Two
programs, one that emitted and one that checked it; neither is in the project any
more. What follows describes what they did, and is kept for the reason at the top:
a reader recreating this project needs to know this step existed and that it should
not be built again.

Three numbers, shown as colour **and** shape, so the reading survives a
failed lamp, a dim room, or a person who does not distinguish the colours.
No two aspects share either encoding, which is checked rather than intended:
one encoding failing would otherwise make two aspects the same thing.

Lamps first, then the framebuffer from `202`, then the serial port — and
which one took it is reported. A machine with none of them is refused rather
than left believing it spoke, because a status shown nowhere looks exactly
like nothing having happened.

The reading lives at one address, shared, and it is **the same address the
assembler's loop emissions push on** (`073`). A runaway program and a
worried machine appear on one dial rather than two, which is what makes the
picture comparable across everything running at once. Settling returns the
magnitude to ordinary and keeps the crossings, since the thresholds crossed
on the way are the record of how close it came.

The meanings are left alone, and the machine is told so in words when it
asks: the codes mean whatever the emitting program needs, two machines
emitting seventeen mean unrelated things, and building the lookup that
answers *what is this one* is the first thing worth doing once anything is
emitting at all — and it is the grown machine's to build.

## Intended behavior

Programs and the machine itself can emit an aspect, a code and a magnitude, and
those can be shown on hardware that cannot spell.

## Suggested implementation steps

1. Provide the emission as a tool call and as something the code produced by
   `204` can reach. Both, because the machine emits during its own thinking and
   the things it builds emit during theirs.
2. Carry three numbers: the aspect, which says where this came from; the code,
   which means whatever the emitting program needs it to mean; and the magnitude,
   on an axis where fifty is ordinary and distance in either direction means a
   look is warranted, and nothing more than that.
3. Drive whatever display the board has. A handful of lamps or a seven-segment
   readout cannot spell, which is why the aspect is shown as colour **and**
   shape — the redundancy is so the reading survives a failed lamp, a dim room,
   or a person who does not distinguish the colours.
4. Keep the current reading in memory as a machine-wide value, so the picture is
   comparable across everything running rather than private to each program.
5. Where there are no lamps, draw the colourshape on the framebuffer from `202` —
   which most machines have and most will not have lamps. Fall back to the serial
   port after that, and say which is happening. A status shown nowhere is worse
   than no status, because it looks like nothing happened.
6. Leave the meanings alone. The seed provides the mechanism; the lookup that says
   what a given code means is something the grown machine builds for itself
   (`docs/006`), and baking a vocabulary in here would be deciding something that
   is not ours to decide.

## Blocks

The phase 2 demo.

## Blocked by

`201`, `202`.

## Related documents

The document that specified the three numbers and why fifty was the middle was
deleted with the rest of this. `docs/006` now holds what replaced it: programs that
might not stop run on their own threads and are timed, rather than reporting how
they are doing.
