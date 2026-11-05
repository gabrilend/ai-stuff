# natsim.lua

A pretend network for testing `nat.lua` (issue 801d): public machines, and
routers of each usual kind (`full_cone`, `restricted_cone`,
`port_restricted`, `symmetric`, `blocked`) with machines behind them.
Endpoints made by `machine:udp(port)` look like `nat.udp`'s; datagrams
arrive at once, through each router's mapping (one outside port per inside
endpoint, or per destination for a symmetric router) and filter (anyone,
the hosts sent to, or the host and port sent to). A mapping not used
outbound for `mapping_timeout` (30 s) lapses and the next gets a new
port. `loss` drops that share of the datagrams crossing the public side,
from a seeded generator, so runs repeat exactly. Counts in `net.sent`,
`net.delivered`, `net.dropped`.
