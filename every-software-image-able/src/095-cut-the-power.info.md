# 095-cut-the-power — info

Cutting the power at a chosen instant, over and over, to find out which instants a machine can be brought back from. Issue 704.

There is a window while a machine is moving into storage where it exists in two places, or in neither. On real hardware that window can only be tested by pulling a plug and hoping to hit the moment. An emulated machine can be stopped at exactly the instant you choose, as many times as you like, from the same starting point.

*Lifted from this file's own comments by `147`. To change this page,
change the comments in `095-cut-the-power.lua` and run the sweep again.*

## Invocation

```lua
local it = dofile(DIR .. "/src/095-cut-the-power.lua")
```

## What it offers

| | What it is |
|---|---|
| `M.OUTCOMES` | what a machine can be, after the power comes back |
| `M.new(options)` | described below |
| `M.at(sweep, from, instructions)` | One instant: restore to the start, run forward, cut the power, and see what comes back. |
| `M.sweep(sweep, options)` | The whole window, coarsely, then every edge narrowed. |
| `M.say_the_shape(result)` | The shape of the damage, rather than a pass or a fail. |

### In more detail

**`M.new(options)`**

```
options:
  snapshot   function() -> a token standing for the whole machine's state
  restore    function(token)
  run_for    function(instructions) -> runs that many and stops
  kill       function() -- cuts the power where it stands
  restart    function() -> "recovered" | "partial" | "gone"
```

**`M.sweep(sweep, options)`**

The whole window, coarsely, then every edge narrowed.

options: window (how many instructions the window is), samples (how many
         coarse points to take first)

## Bisect rather than scan

The window may be millions of instructions long and testing each one is pointless -- what is wanted is where the BOUNDARIES are. Find one instant that recovers and one that does not, then narrow between them: the same answer for a few dozen runs instead of millions.

## But watch for more than one band

Bisection assumes a single boundary. A window with two unrecoverable stretches will hide one of them, and the hidden one is exactly the sort of thing that only ever happens to somebody else's machine. So the sweep samples coarsely first, finds every band it can see, and bisects each edge -- and says how coarse the sampling was, so a reader knows what could still be hiding between the samples.

## Report the shape of the damage

not a pass or a fail. What matters is which instants come back, which come back confused, and which do not come back at all.

## Where it sits

**Belongs to** `704`.

**Checked by** `096-test-watching-and-power`.

