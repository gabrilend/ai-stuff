# test_pings.lua

Checks minimap pings (issue 507f) from end to end without a window: the
`ping` and `pinged` messages round trip; the server sends a ping to the
pinger and their allies only (and to the pinger alone when the game says
nothing of allies), skips dropped players, lets pings through while paused,
and refuses pings sooner than `PING_EVERY_MS` or at a point that isn't a
finite number; the `PingMinimap` natives ping the local minimap, the
ForForce ones only for a force holding the local player, with Blizzard.j's
three styles (simple, flashy, attack) and its pure-red-to-254 rule; the VM
drops pings when their time is up and keeps no more than `PINGS_KEPT`; and
`ui/wc3/pings.lua` gives each ping's fade, ring and attack look over its
life.

- **Usage:** `luajit src/tests/test_pings.lua [DIR]`; without DIR it finds
  the project from its own path. Exits 1 on a failure.
