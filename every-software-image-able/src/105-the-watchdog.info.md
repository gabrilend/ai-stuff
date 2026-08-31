# 105-the-watchdog — info

Surviving a read that never comes back. One countdown per core, armed only around the operation that can hang, and disarmed the moment it returns.

Some addresses, when read, never answer. The processor is not faulted -- it is stopped inside the load instruction, waiting for data that will never arrive. Nothing inside the machine can notice, because the thing that would notice is the thing that stopped. The only way out is a piece of hardware that resets the machine when the machine stops telling it everything is fine.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `105-the-watchdog.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/105-the-watchdog.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.SLOTS` | how many countdowns exist |
| `M.new(options)` | described below |
| `M.attempt(watchdog, core, about, read)` | The whole discipline in one call: write the note, arm the countdown, attempt the read, disarm. |
| `M.what_was_it_doing(watchdog, read_note)` | What the next start does: read every core's last words and find out what the machine before it was doing. |
| `M.offer(catalogue, hands, watchdog)` |  |

### In more detail

**`M.SLOTS`**

One per core, assigned rather than allocated: a core takes its own slot by
its own number, so no two cores can be handed the same one and nothing has
to be locked to find out which is free. The number of cores is discovered
at startup and does not change while the machine runs.

**`M.new(options)`**

```
options:
  cores       how many countdowns to make
  patience    how long a read may take before the machine is reset,
              in whatever the timer counts
  arm         function(slot, patience)  -- starts the hardware countdown
  disarm      function(slot)            -- stops it
  note        function(text) -> where   -- writes the last words

The three functions are handed in for the same reason the memory rules
take their touch from outside: on the metal they are a timer device and a
disk, hosted they are pretend. What lives here is the shape.
```

**`M.attempt(watchdog, core, about, read)`**

The whole discipline in one call: write the note, arm the countdown,
attempt the read, disarm.

`about` says what is being touched and what is expected, and goes to
storage before anything happens. `read` is the thing that might not come
back.

Returns the value, or nil and what happened. A machine that comes back
from a reset never returns from here at all -- it returns from power-on,
which is why the note matters more than the return value.

**`M.what_was_it_doing(watchdog, read_note)`**

What the next start does: read every core's last words and find out what
the machine before it was doing.

Every slot rather than one, because the core that hung is not necessarily
the last one to have written. A machine with four cores leaves four
accounts, and the interesting one is whichever core did not come back.

## Why it must be a reset and not an interrupt

This is the constraint that shapes everything else here. A processor stalled on the bus is not fetching instructions, so an interrupt cannot be delivered to it -- there is nothing running to deliver it TO. The watchdog therefore takes the machine down and brings it back up. Recovery is a reboot, not a jump.

## Which is why the note comes first

and why that rule is load-bearing rather than tidy. The machine writes down what it is about to touch, before touching it. If the read hangs and the watchdog resets the machine, that note is the only thing that crosses the reboot. It is the machine's last words to its own next start.

## Armed only around the dangerous read

A watchdog running always costs every part of the machine a periodic obligation. Armed around one operation, the cost is paid exactly where the risk is, and a machine doing ordinary arithmetic owes nothing.

## One per core, not one per machine

A stalled core is one worker lost; the others keep running. A single machine-wide watchdog would reset all of them because one of them stopped, which turns one lost worker into a lost machine.

## Where it sits

**Checked by** `106-test-the-watchdog`, `151-test-the-documentation-site`.

