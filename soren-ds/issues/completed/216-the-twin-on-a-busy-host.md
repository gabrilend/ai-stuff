# 216 — The twin on a busy host

## Current behavior

Tests 049 (the task ring) and 075 (kinds, doors and launch boxes) fail
when the laptop is busy with other work. 049 runs four cores pushing and
popping one ring, and on a host with three or four other busy processes
it ran for minutes instead of a second, past the runner's limit. 075
reads counts that are short of what was sent ("weighted {1, 2, 5} split
40000 ... 4670 9130 23501"), or finds spread splitting 1000 / 1000.

Two causes, one in the twin and one in a test.

**The spin lock under a host that sets threads aside.** `spin_lock` is
a ticket lock: each waiter draws a number and the lock goes to the
numbers in order (204's choice, so a core that just let go cannot take
it again ahead of one that has waited). On the device that is right:
nothing takes a core away from the code it is running. On the twin a
core is a thread, and a busy host sets runnable threads aside for whole
time slices. When the thread holding the next number has been set aside,
the lock cannot move, and every waiter behind it spins away the CPU time
that thread needs to come back. Measured with 049 watching itself: about
130 ring operations a second, one per host time slice, where a quiet
host does a million in under a second. The engine was not wrong; it
was waiting, at full speed, for a thread that could not run.

**A spread check that hoped the feeder would win.** 075's spread check
fed 2000 values to a station sending each to whichever of a quick and a
slow destination had fewer waiting, and expected the quick one to get
more. That is true only if values arrive faster than the slow one can
handle them. On a busy host the feeder is often the thread set aside;
every value was handled before the next arrived, every look found both
destinations idle, ties went to the cursor, and the split came out even.

And every settle in 075 had a fixed limit (two to twenty seconds) whose
answer was never looked at, so a count read after a settle that gave up
was taken as the program's answer.

## Intended behavior

The suite passes on a host whose CPUs are all busy with something else,
checking exactly what it checked before.

- A spin-lock wait asks the platform how to wait
  (`platform_spin_wait(word, seen, turns)`), and a release with others
  queued tells it (`platform_spin_wake(word)`). The device hints the
  core, as it always did, and never sleeps. The twin spins while the
  queue keeps moving; once it has watched the queue stand still for a
  while, it sleeps in the kernel on the lock's now-serving word until it
  changes, and the release wakes the sleepers. A thread woken from sleep is run
  promptly, where one merely set aside waits its turn, so the next number
  gets a CPU when its turn comes. The lock is still a ticket lock, served
  in order, on both.
- 075's spread check holds the slow destination (its second input has no
  source while the values arrive) so it cannot keep up whatever the host
  does, feeds in batches of 100 with the program settled between them,
  then gives the slow destination its input and lets it work through
  what it was sent.
- 075 checks that every settle it relies on settled, with a limit of a
  minute, which costs nothing on a quiet host because a settle answers
  the moment the engine is idle.

## Open questions

- *Change the lock, or the twin's way of waiting?* The twin's way of
  waiting. The ticket lock's order is a decision about the device (204),
  and a twin that ran a different lock would stop testing the one the
  device runs.
- *Spin, yield, or sleep?* Tried in that order. Yielding the CPU after
  a short spin took 049 from timing out to two seconds on a moderately
  busy host, and still timed out with eight other busy processes: a
  yield gives the CPU to whatever else is runnable, which is rarely the
  thread holding the next number. Sleeping on the word does not depend
  on which thread the host picks.
- *Is the spread check weaker for holding the slow destination?* It is
  more certain, and it checks the same thing, but it no longer passes
  through the part of spread's look that counts runs already queued for
  a destination (issue 308): a held destination's backlog is in its
  port. That part only shows when a destination's runs pile up in the
  ring faster than the cores drain them, which a test can provoke but
  not promise.

### Proposed answers (UNVERIFIED)

As above. A waiter sleeps once it has spun 1024 turns since the queue
last moved (tens of microseconds here; a held lock is let go within a
fraction of one). Counting from the last move, not from the start of the
wait, matters: a waiter fourth in a moving queue is not stalled. A
threshold of 128 turns from the start of the wait made 049 ten to twenty
times slower on a quiet host, because waiters slept through handovers
that were about to happen; 4096 was slower under load than 1024 and no
faster when quiet. The kernel wait carries a one-millisecond limit as a
backstop; the wake is the mechanism.

## What happened

Measured on a four-CPU laptop that was already running other work, with
eight busy loops added: 049 went from timing out at 100 seconds to about
4 seconds, and 075 from timing out to under a second; the whole suite
passed three times in a row. With the host quiet, 049 takes what it took
before (0.7 to 1.2 seconds against 0.7 to 0.9). Making spread ignore its
look fails the reworked check (1000 / 1000), as it should.

## Related

- `issues/completed/204-the-task-ring.md` — why the lock serves in order.
- `src/engine/027-primitives.c`, `src/engine/025-platform.h`,
  `twin/026-platform-twin.c`, `src/device/042-platform-device.c`.
