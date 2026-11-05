# netns.lua

Runs a socket test in a network of its own (issue 801b): the test calls
**`netns.enter(arg[0], args)`** first; outside, that runs the test again
under `unshare -rn` (a fresh network holding only a loopback) and exits
with its status; inside (`WETE_NETNS=1`), it switches the loopback on
through an ioctl in LuaJIT's FFI, so no `ip` command is needed, and
returns. If `unshare -rn` can't make a network, the test fails saying so
rather than touching the machine's own network.
