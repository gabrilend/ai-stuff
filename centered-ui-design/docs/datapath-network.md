<!-- written by Claude (Opus 5.5) during project initialisation, 2026-10-10.
     Planned design of networked play (phase 8). Kept short until phase 8
     work begins; update it then. -->

# Datapath: commands across machines

Because the simulation is deterministic (same seed + same commands = same
game), machines do not send the world to each other. They send only
commands.

```
 seat's view ─▶ command ─▶ stamped with the tick it takes effect (now + delay)
            ─▶ sent to every other machine over ENet (built into LÖVE)
 each machine: a tick may run only when every seat's commands for it are in
            ─▶ simulation runs that tick identically everywhere
            ─▶ every few seconds, machines swap a checksum of the world;
               a mismatch stops the game with an error naming the tick
```

The game's own order transit already hides network delay well: an order was
always going to take time to reach the front.
