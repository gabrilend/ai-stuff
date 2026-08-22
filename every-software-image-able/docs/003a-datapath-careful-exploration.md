# 003a — Datapath: Careful Exploration

The downward half of `003`. How the machine learns to operate hardware it has no
description for, without destroying it.

Descriptions can be found for essentially any computer built in the modern day.
The machine still needs the capability to act as though it has none, because a
description it has not confirmed is worse than no description — it will be
followed confidently into the wrong register.

## Why this is a constraint and not a preference

Writing the wrong value to the wrong register can destroy hardware permanently.
This is not a crash, not corruption, not a state a reboot clears. Four mechanisms
account for most of it:

- **Voltage and clock control.** Some devices expose the regulator that feeds
  them and the divider that clocks them. Raising either past what the silicon
  tolerates damages it in seconds, and the register that does it looks exactly
  like every other register.
- **Non-volatile configuration.** Many devices hold their identity and sometimes
  their firmware in storage that survives power loss. Writing into that region
  can leave a device that never announces itself again — the machine will not
  even find it next boot, so it cannot be repaired by trying harder.
- **Pin direction.** A pin configured as an output, driving one way while
  something outside drives the other way, is a short circuit through the driver
  transistor.
- **Thermal protection.** It can usually be switched off. A device run hard with
  it off does not report a problem; it stops existing.

Every other failure in this project is recoverable by writing more software.
These are not, which is why exploration gets its own discipline.

## The order of operations

**Read everything before writing anything.** Reads are where nearly all the
information is and where nearly none of the danger is. Build the complete picture
of what a device reports about itself before touching a single writable bit.

Two exceptions keep "reads are safe" from being exactly true. Some registers
clear themselves when read, so reading them is a change. And on some buses a read
from an address nothing answers on will hang until something resets the bus. Both
are survivable; neither is destructive.

**Find the reset first.** Before any exploratory write, establish whether the
device can be returned to a known state and confirm that it works. If it can,
every subsequent experiment is reversible and exploration becomes cheap. If it
cannot, every write is permanent and the pace should change accordingly.

**One at a time.** A probe is a single change followed by a single observation.
Changing two things and watching one outcome teaches nothing about which change
caused it, and if the outcome is a dead device it teaches nothing at all.

**Predict, then write, then check.** An exploratory write should be preceded by a
statement of what is expected to happen. A write with no prediction attached
produces a result nobody can interpret. This is the same rule the compiler
follows when it varies an approach (`004`) — the value of an experiment lives in
having said beforehand what would count as which answer.

## What may not be touched without a confirmed description

A denied list, refused by default regardless of how promising the register looks:

| Region | Why |
|---|---|
| Voltage, regulator, power state | Destroys the part |
| Clock dividers and multipliers | Destroys the part |
| Thermal limits and shutdown | Removes the protection that would have caught the others |
| Non-volatile configuration and firmware | Bricks the part, unrecoverably and invisibly |
| Pin direction and drive strength | Shorts the driver |

Getting into these requires tier two or three knowledge (`003`) that has been
**confirmed**, and confirmation is defined below.

## Confirming a description

A description is only usable once it has been shown to be about this exact part.
Confirmation is a read-only act, always. Confirming a description by writing to
the device is the failure this whole document exists to prevent.

```
the device's reported maker and part number match what the description claims
   → registers the description says are read-only are read
   → their values match what the description predicts
   → registers the description says are reserved read as the predicted pattern
   → the revision field, if there is one, is within the range the description covers
   → confidence rises; the denied list opens for this device only
```

Any mismatch means the description is for a relative rather than for this part,
and the denied list stays shut. Partial matches are the dangerous case: enough
agreement to feel confirmed, one silent disagreement in the register that matters.

**DescriptionMatch**

| Field | Type | Meaning |
|---|---|---|
| `device` | integer | which slot |
| `description` | string | which description was tested |
| `checks_run` | integer | how many read-only predictions were tested |
| `checks_passed` | integer | how many matched |
| `revision_covered` | boolean | whether the part's revision is inside the described range |
| `confirmed` | boolean | whether the denied list opened |

## Surviving the probe that kills the machine

Some experiments hang the bus, hang the processor, or take the machine down
entirely. The machine cannot report what happened, because it is not running.

So **the intent is written down before the attempt, not after**. A note saying "I
am about to write this value to this register on this device" goes to storage
first. If the machine comes back and the note is still there unresolved, the next
boot knows exactly which experiment did not survive, and does not repeat it.

```
about to try something that might not return
   → write the intent: device, register, value, what is expected
   → arm the board's reset timer, briefly                  (added 2026-08-21)
   → perform the write
   → disarm the timer
   → observe
   → write the outcome, which retires the intent
```

**The two middle steps are new and they cost nothing.** The firmware arms a reset
timer before the machine's first instruction and the machine turns it off, because
thinking must never be on a clock. That call may be made again — so a machine can arm
it for a few seconds around a probe and turn it off afterwards.

It matters because this ticket's gravestone was designed for probes that *destroy*
hardware, and there is a second failure with the same shape: a probe that **hangs**.
A read from an address nothing answers on stops the processor inside the instruction,
where no amount of timing helps because the machine's own code is not running to do
the timing (`003`). With the reset timer armed, the board comes back and finds a note
with no outcome beside it. Without it, the board sits stopped until somebody walks
over to it.

Nobody had noticed the two failures were the same shape. The mechanism needed no
change to cover both.

A note with no outcome beside it is a gravestone. It is the only way this machine
learns from the experiments that killed it.

This is where a permanent, append-only note earns its place in the design — not
imported from anywhere, but required by the fact that the writer can die
mid-sentence. Everything about how far back that store reaches and what else goes
into it is question 10 in `008`.

## When the description is not enough, ask a person

**Added 2026-08-21, and it changes what this document is for.** Confirming a
description is the machine's own route into the denied list and it stays. What was
missing is what happens when there is no description to confirm, or the
confirmation fails, and the machine still cannot get on with anything else.

It asks somebody. Not for permission in the sense of a gate — there is no gate
anywhere in this design — but because a person can pick up a screwdriver, read a
datasheet, or simply say *no, don't*. The machine explains three things: what it is
worried about, why it wants the change, and how it would be done. That is the same
instrument the machine already uses to justify every other choice it makes
(`004`), pointed at a person instead of at a chart.

**It cannot do this for a long time.** Asking requires a way of reaching somebody,
and a channel is software the machine has to build. Until then, and this is the
whole of what the seed can offer:

```
stuck: needs a dangerous write, cannot work around it, cannot defer it,
       and has nothing else worth doing
   → if there is a way to reach a person, ask, explaining concern, reason, method
   → if not, write a note that says HELP I'M STUCK, and go do something else
   → if there is any output at all but no conversation, blink S.O.S. on it
   → or demolish what was being built and start again, aiming to miss the pitfall
```

That last one costs work already done and is sometimes the cheapest way forward.
It is also the only move in this design that spends capability on purpose, which
is the exact opposite of what rung four does (`005`), and it is worth noticing
that both are correct.

## Who writes the carried descriptions

Nothing said. Tier two of the knowledge table in `003` is *a description carried on
the image, in our own format*, and the only thing written about it is that it costs
drive space and must be written before shipping.

**They are generated at build time and validated by a person.** A model on the
development machine reads the part's documentation and produces a description in
our format — including, and this is the part that matters, the **read-only
predictions** the machine will later use to confirm it: which registers are
read-only and what they should read as, which are reserved and what pattern they
hold, which revisions the description covers. The engineer checks it before the
image is built.

Which gives the confirmation ceremony a symmetry it did not have. **The engineer
confirms a description against documentation at build time; the machine confirms
the same description against the silicon at boot.** The same act, twice, and the
person is present for the half that only documentation can answer.

It also puts a bound on what documentation is needed to build a seed at all. Two
things: **which registers on this exact part destroy it**, and **the operating
sequence for any device with no governing standard.** Everything else the machine
finds out by asking the hardware.

## Time

There is no deadline. The machine should spend as much time as it needs building
out functionality. Being slow costs nothing that matters; being wrong costs a
part that cannot be replaced by any amount of software.

This is the one place in the project where the answer to "should we try
something clever" is no.

## Open questions

- **How does the machine know a device died?** Absence of response is also what a
  busy device looks like, and what an unpowered one looks like. Distinguishing
  "destroyed" from "not answering yet" is not obviously possible from inside.
- **Does a gravestone ever get retried?** A note whose experiment killed the
  machine might have been killed by something else entirely — an unrelated fault
  at the same moment. Never retrying means one coincidence closes a door forever;
  retrying means the coincidence theory is tested with the same hardware that
  died last time.
- **Who confirms the confirmer?** A carried description that is itself wrong
  passes every read-only check it predicted, because it predicted them. Tier two
  knowledge has no external check.
- **Can exploration be practised safely anywhere?** A machine with a second,
  expendable copy of a device could learn on that one. Nothing in the design
  provides for it, and it may be the only honest way to explore the denied list.
