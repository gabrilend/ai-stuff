# 508 -- The phase five demo

**Phase:** 5, the bridge and the browser
**Blocked by:** every other issue in phase 5.
**Blocks:** nothing. The capstone.
**Documents:** [the roadmap](../../docs/015-roadmap.md)

## Current behaviour

`./run-phase-demo` offers phases 1 through 4, all of which print to a terminal.

## Intended behaviour

**A demo you can actually play.** Walk a character around a generated dungeon in a
browser, with real fog, at a real frame rate.

This is the first one that is not a report. Every earlier phase proved something
by printing numbers; this one proves the whole spine works by letting somebody
move.

### What it does

1. Starts a server with the fixture world and a body to drive.
2. Starts a bridge pointed at it.
3. Prints the URL, and waits.

The person opens `localhost:12345` and walks around. Walls block them. The fog
fills in behind them. The corridor is dark until they enter it.

### It must say how to stop

A demo that starts two processes and does not say how to stop them is a demo that
leaves two processes running. Print it, and handle the interrupt so both go down
together.

### And it should still report numbers

The earlier demos' habit is worth keeping, printed to the terminal while the
browser is open:

| Reported | Why |
| --- | --- |
| Beats per second, actual | Whether the heartbeat is keeping up. |
| Bytes per second to the browser | The wire cost of a real session. |
| Frames per second in the view | Whether interpolation is doing its job. |
| Time from key press to confirmed move | What prediction is hiding. |

That last one is the number that says whether the controls feel alive, and it is
worth measuring rather than judging.

### The honest caveat

Appearance in this phase comes from a table compiled into the renderer, not from a
ruleset. Phase 7 replaces that table with `describe`, and phase 9 replaces the
shapes with the sprite studio's output. **The interface is built now so that
replacement is a substitution rather than a rewrite** -- and the demo should say
so, rather than letting somebody think the placeholder shapes are the plan.

## Suggested implementation steps

1. Write it as a script that starts the server and the bridge and prints the URL.
2. Trap the interrupt and take both down.
3. Report the numbers to the terminal on an interval.
4. Confirm `./run-phase-demo 5` works from a clean checkout with nothing else
   running.
