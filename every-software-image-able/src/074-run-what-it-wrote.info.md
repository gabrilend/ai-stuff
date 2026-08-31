# 074-run-what-it-wrote — info

Placing code the machine wrote, calling it, and surviving it not returning. Issue 204's second half, and the half the phase's risk is in: code written by a model will sometimes loop forever, and without a way to regain control the first bad function ends the machine.

The machine hands over a page of assembly, this puts it somewhere real, runs it, and hands back what it returned. If it never returns, the count the assembler was inserting at the bottom of every loop crosses a line and the machine takes control back.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `074-run-what-it-wrote.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/074-run-what-it-wrote.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.ALLOWANCE` | how many times a loop may go round before somebody looks |
| `M.new(options)` | described below |
| `M.place(runner, name, bytes, text)` | Puts a program somewhere real and hands back where it went. |
| `M.call(runner, at, arguments)` | Runs it, watching the magnitude. |
| `M.watch(runner)` | What a machine asks between steps of something it is running: is this still worth waiting for. |
| `M.offer(catalogue, hands, runner, assembler)` | The hand itself: text in, a placed program out, and a second hand to call it. |

### In more detail

**`M.ALLOWANCE`**

A million. Not a tuned number -- an obviously-generous one, chosen so that
no correct program meets it by accident, since the whole failure this
replaced was a bound so tight that correct programs met it immediately.

It is spent per program and starts at zero for every run, so it is a
private count rather than a shared dial. Programs that legitimately need
more say so when they are run.

**`M.new(options)`**

```
options:
  memory       a memory (071), for placing and for the magnitude
  somewhere    an address in usable memory that is not ours, with room
  room         how many bytes are free there
  count_at     an address holding this program's loop count
  run          function(address, arguments) -> value; how this machine
               actually transfers control
  stop         function() -> nil; how it takes control back, or nil where
               nothing can. Absent means a runaway is fatal, which is
               said out loud rather than hoped about.
  allowance    how many turns of a loop are enough (default a million)
```

**`M.place(runner, name, bytes, text)`**

Puts a program somewhere real and hands back where it went.

The memory rules from 203 apply unchanged: this writes through them rather
than around them, so placing a program on top of the engine is refused by
the same check that refuses any other write there. A hand that could
bypass the one refusal would make the refusal decorative.

**`M.call(runner, at, arguments)`**

Runs it, watching the magnitude.

Returns the value, or nil and what happened. A program stopped for running
away is not an error in the machine -- it is the machine working -- so it
comes back as a sentence the model can read and a new attempt can be made
from.

**`M.watch(runner)`**

What a machine asks between steps of something it is running: is this
still worth waiting for. Exposed because the answer belongs to the runner
and the asking belongs to whatever transfers control.

**`M.offer(catalogue, hands, runner, assembler)`**

The hand itself: text in, a placed program out, and a second hand to call
it. Two hands rather than one, because placing and running are different
risks and a machine may want to look at what it built before running it.

## What is kept

The bytes and the text they came from, together, always. The pair is what makes a later reading of "why is this here" possible, and it is the first thing the machine builds that outlives the thought that made it (docs/006 on what a machine writes down).

## The escape, and its holes

Every loop this assembler built spends from an allowance, so a loop that will not end runs out of allowance and is stopped.

## Worth knowing

CORRECTED 2026-08-21, AND IT WAS A REAL DEFECT. The spending used to be done against the machine-wide status magnitude -- fifty as ordinary, stop at fifteen away -- which meant ANY LOOP OF FIFTEEN OR MORE ITERATIONS was declared a runaway. Copying a hundred bytes. Summing twenty numbers. Clearing a page, several hundred times over. The test suite missed it because its loops count down from five.

The cause was two instruments welded into one. The two digits on the lamps are POST codes -- breadcrumbs saying WHERE a program got to, in a vocabulary that program owns, last writer wins (079, docs/006). They are not a measurement and nothing accumulates in them. What stops a runaway is a plain count with a large allowance, and it is PER PROGRAM, because anything worth running is worth running on more than one thread and two threads looping at once would both push a number neither of them owns. What escapes it: code that did not come through our assembler, and a loop built out of something the assembler does not recognise as a back-edge. For those, an instruction budget stepped one at a time is the slow fallback -- it cannot be escaped, and it is worth having even if it is rarely reached. Whether it exists here is a property of the machine this is running on, and is answered rather than assumed: see `M.new`.

## Where it sits

**Belongs to** `204`.

**Checked by** `075-test-run-what-it-wrote`.

