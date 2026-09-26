# 206 — Sleeping and waking

## Current behavior

**Built and tested on the twin; the device half is unverified.** A
worker that finds the ring empty raises the parked count, looks at the
ring once more, and only then parks (`platform_wait_for_event`). A push
reads the parked count after publishing its task and wakes everyone only
if somebody is parked — each side writes then reads with a full barrier
between, so one of them always sees the other. The last core to park
sleeps only until the earliest timer (`platform_wait_until`), so a
scheduled value arrives on time with every core asleep. Timers are
`engine_timer` / `engine_timer_cancel`: a value delivered into a port at
a moment, optionally every period after, skipping (and counting) periods
nobody fired in time.

On the device, the wait is wait-for-event plus the generic timer's
periodic event stream (about 2.9 kHz), not the wait-for-interrupt the
text below describes — that needs the interrupt controller to route the
timer's interrupt, which nothing has set up. Recorded in
042-platform-device.c.

Tests: 051 (a 5 ms trickle parks cores between values and loses
nothing), 054 (a 1 kHz timer feeds a program; parking it stops every
run while the timer keeps firing).

## Intended behavior

**A worker with nothing to do parks the core. A worker that pushes a
task sends an event that wakes every parked core.**

The other project sleeps by asking the operating system, which costs a
trip into a kernel. There is no operating system here and no trip. This
chip has the mechanism in the instruction set, and it is better than
what we would have built.

| how a core waits | costs | wakes on |
|---|---|---|
| ask the ring again, forever | a whole core, continuously | nothing; it never stopped |
| **wait-for-event** | almost nothing; the core clock gates | an event sent by any core |
| **wait-for-interrupt** | less still; deeper state | a pending interrupt, *even with interrupts masked* |

**The event register is what makes this safe, and it is hardware doing
a job that is usually software's.**

Sending an event does not wake cores that happen to be waiting at that
instant. It sets a one-bit *event register* in every core. A core that
arrives at wait-for-event afterwards finds its bit already set,
consumes it, and does not wait at all.

```
  core 1                        core 3
  ──────                        ──────
  ring looks empty
                                push a task
                                send event  ──→ sets core 1's event bit
  wait-for-event
      │
      └─ bit already set → returns immediately, no wait

  the window between "looked" and "waited" cannot swallow a wake.
```

On a general-purpose system this window is the classic lost-wakeup bug,
and closing it requires the check and the sleep to happen inside one
hold of a lock. Here the hardware closes it, so the check needs no lock
at all.

**All four asleep is not completion.** This is the point where the
other project's engine declares the program finished. A handheld has no
such moment — every core asleep means the user has not pressed anything
yet, and something will arrive. Programs on this device end because
they were **asked** to (213), never because they ran out of things to
do.

So the last core to park does not declare anything. It asks a different
question: *is anything scheduled to arrive?*

```
  ring empty
      │
      ├── other cores still working ──→ wait-for-event, wake on their push
      │
      └── all four now idle
              │
              └── something scheduled?  (the 60 Hz frame, a timer)
                       │
                       ├── yes → wait-for-interrupt until the deadline
                       │          the core wakes on its own.
                       │          no handler runs. see below.
                       │
                       └── no  → wait-for-event. nothing will happen
                                  until something does.
```

**Waking on a deadline without an interrupt handler.** This is the
mechanism that lets the device be interrupt-free and still keep time. A
core in wait-for-interrupt wakes when an interrupt becomes *pending*,
whether or not interrupts are actually enabled. So the chip's timer is
armed for the next frame, interrupts stay masked, the core parks, and
at the deadline the timer's pending flag wakes it — the core simply
continues at the instruction after the wait. No handler is entered,
nothing is on the stack, and the engine never learns that hardware was
involved. The polled input map from phase 5 is what runs next.

**Wake everyone, not a chosen one.** Choosing which core to wake means
reasoning about which, and there is no information available that makes
one choice better than arbitrary. Waking all four lets whoever gets
there first take the task and the rest park again within a few hundred
cycles. Waking too many is much cheaper than failing to wake the one
that mattered.

**A worker that has just pushed does not park**, because the ring is
not empty — it just put something in it.

## Suggested implementation steps

1. Replace 205's temporary retry: on an empty ring, mark this core
   asleep in its context, then wait for an event.
2. Send an event at the end of every push in 204. Unconditional and
   cheap; the event register makes a redundant one harmless.
3. On waking, clear the asleep flag and re-check the ring before
   believing anything — a wake is a rumour, and several cores wake for
   one task.
4. The all-idle path: count sleeping cores, and when the count reaches
   the core total, take the deeper wait with the timer armed.
5. A trickle test — a slow drip of tasks over a wall-clock second —
   asserting that idle cores draw measurably less current, or failing
   that, that the counters show them parked rather than spinning.
6. A test that a task pushed in the exact window between an empty check
   and a park is still picked up, which is the property the event
   register is being trusted for.

## Open questions

- *How deep should idle go?* Wait-for-event gates the core clock;
  wait-for-interrupt goes further; actually powering a core down goes
  furthest and is a conversation with the power-management chip and the
  secure firmware. A frame is 16.6 milliseconds, which is an enormous
  amount of idle time to leave on the table, so the deepest state the
  wake latency allows is probably right. This wants measuring against
  battery life, which means it cannot be settled until there is
  something to measure.
- *Does the core that arms the timer own it?* If four cores can each
  arm the same timer for different deadlines, the earliest must win and
  somebody must own that decision. Probably one timer per core, since
  this chip gives each core its own.
- *What wakes the device from fully idle with no timer armed?* Today,
  nothing — which is correct for a device with no interrupts, and also
  means the power button has to be polled by something that never
  fully sleeps. That is a phase 5 problem and it should be written down
  there before it is discovered there.

### Proposed answers (UNVERIFIED)

1. *How deep should idle go?* Wait-for-event now; wait-for-interrupt once
   the interrupt controller routes the timer (a new issue). Powering
   cores down waits for battery measurements.
2. *Who owns the timer?* One table of up to 64 timers, fired by whichever
   core first notices one is due (a try-lock — losing means somebody is
   already doing it). On the device each core would arm its own timer
   for the earliest deadline.
3. *What wakes a fully idle device?* The 60 Hz input frame (phase 5) is
   a periodic timer, so a device with its input map running is never
   without a deadline. Written into 501.

## Blocked by

204, 205.

## Blocks

213 (parking uses this), 215.

## Related

- [204 — The task ring](204-the-task-ring.md), whose push sends the
  event
- [213 — Asked to stop, and parking](213-asked-to-stop-and-parking.md),
  which is what ending actually means here
- [501 — Polling-loop map structure](501-polling-loop-map-structure.md),
  the 60 Hz frame this wakes for
