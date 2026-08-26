# 068-server-main

The program a host runs. Holds the world, opens the door, and beats.

```
068-server [door-port]
```

Twenty beats a second — phase 2 measured that sight does not constrain that, so
it was chosen for how the controls feel rather than for what the machine can
manage.

## It is deliberately thin

Everything it calls has been built and tested on its own. This file is **the order
they go in**, and it is the only place in the project where the eight passes of
the tick are wired to real sockets:

1. `door_admit`, `door_connect_waiting`, `door_drain` — intake
2. decode and `session_command` — the gauntlet
3. `session_tick` — intent, motion, region, rules
4. `fog_fold` per viewer — sight, then memory
5. `outbound_build` per viewer, `door_flush` — outbound

## Permission is handed out, not asked for

A joining participant is given a body and **told which one it is**. They cannot
ask and they do not choose. `OP_HELLO` carries the answer.

## The signal handler sets a flag and nothing else

Doing real work in a signal handler is how a clean exit becomes a crash in the
middle of a socket write. The loop notices the flag and unwinds normally, which
is why a `kill` produces a proper goodbye with the beat count and the world hash.

## Falling behind

If more than a second late — the machine was busy, or the process was suspended
— it gives up on catching up rather than running a hundred beats back to back.
**A world that fast-forwards is worse than one that skipped.**

## Line-buffered output

`setvbuf` with `_IOLBF`, for the same reason as the bridge: redirected to a file,
a fully-buffered server looks exactly like a hung one.

## Measured

1,931 beats in 96.5 seconds — 20.0 a second, holding steady with a participant
connected and moving.
