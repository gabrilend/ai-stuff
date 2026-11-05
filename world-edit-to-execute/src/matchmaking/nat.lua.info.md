# nat.lua

NAT detection and UDP hole punching (issue 801d). Two players behind
home routers can't reach each other until each router has seen a datagram
go out to the other; this module gets both routers to that point at once.
Everything works on an *endpoint* (`send(data, ip, port)`, `receive()`
giving data, ip, port or nil, `local_address()`); `nat.udp(ip, port)`
makes one from a LuaSocket UDP socket, and `src/tests/natsim.lua` makes
simulated ones behind simulated routers. Pass `clock` (seconds) to drive
time by hand.

**The reflector** (run beside the matchmaking server:
`matchmaking-serve.lua --nat-port P [--nat-alt-ip IP]`)

- **`nat.reflector({ main, alt_port, alt_ip? })`**: answers a BIND with the
  address and port it came from, from the endpoint it was asked at, or
  from the other port or other address when the BIND's flags ask.
  `:poll()` answers all that waits; `:handle(which, data, ip, port)` one.
- **`nat.reflector_udp(ip, port, alt_ip)`**: the same on real sockets,
  ports P and P+1 (port 0: any two free ports).

**Detecting** (`nat.detector(endpoint, { server_ip, server_port })`,
`:step()` until it gives the kind; or blocking,
`nat.detect_type({ stun_server = "ip:port", endpoint? })` giving the kind
and the outside ip and port). The questions, in order:

1. where am I? No answer in `detect_wait` (1 s): **blocked**. The answer is
   my own address: **open**.
2. (only if the reflector has a second address) answer from your other
   address. Answered: **full_cone**.
3. answer from your other port. Answered: restricted, else port-restricted.
4. where am I, asked at your other port? Another outside port: **symmetric**;
   otherwise **restricted_cone** or **port_restricted** from 3.

3 comes before 4 on purpose: after a datagram to the other port, a
port-restricted router lets that port's answers in. Without a second
address a full cone reads as restricted_cone; both punch alike.
Questions repeat every `detect_retry` (0.2 s), so loss is survived; the
whole detection takes well under five seconds.

**Punching** (`nat.create_punch({ endpoint, remote_ip, remote_port, token })`)

- `:step()` sends a PROBE every `probe_interval` (0.1 s) and answers the
  other side's with an ACK. **established** on an ACK to one of its own,
  **failed** after `punch_timeout` (5 s). Once open, a KEEPALIVE when it
  has sent nothing for `keepalive` (15 s); **lost** after `lost_after` (3)
  keepalives of silence, and open again when heard.
- A probe from another port of the remote's address moves the remote
  there (a symmetric router gave the remote a new port).
- Only datagrams with the punch's `token` count, so punches can share an
  endpoint. `:handle(data, ip, port)` takes one datagram; `:poll()` reads
  the endpoint itself and keeps the game's datagrams from the remote for
  `:receive()`; `:send(data)` sends the game's.

**A lobby's session** (`nat.session(lobby, { endpoint, mapped_ip?, mapped_port? })`)

Ties punches to a lobby of `client.lua`. A player's `:start()` sends its
outside endpoint to the host through NAT_PUNCH; the host answers each with
its own and both punch. Without `mapped_ip` the server fills in the address
it sees. The token is `nat.token(game_id, player_id)` of the player.
`:step()` reads the endpoint, hands each datagram to its punch and fires
**established**, **failed**, **lost** (player_id, punch) and **data**
(player_id, datagram). `:punch_for(player_id)`, `:close()`.

**Packets** ("WN", a kind byte, a 32-bit token, then the body; big-endian):

| Kind | Byte | Body |
|------|------|------|
| BIND | 1 | flags (1: answer from the other port, 2: from the other address) |
| BOUND | 2 | ip (4), port (2), the reflector's other port (2), its other address (4, 0.0.0.0 if none) |
| PROBE | 3 | seq (4) |
| ACK | 4 | seq (4) |
| KEEPALIVE | 5 | none |

These are not STUN (RFC 5389) packets: the reflector is ours, so no
outside service is used. They are separate from the matchmaking server's
MessagePack messages because they ride UDP; if question Q-1 brings in 803's
message layer, only `nat.encode` and `nat.decode` change.

**Which kinds punch through** (the simulation in
`test_matchmaking_nat.lua`, both sides starting at once):

| | open | full cone | restricted | port-restricted | symmetric |
|---|---|---|---|---|---|
| **open** | yes | yes | yes | yes | yes |
| **full cone** | yes | yes | yes | yes | yes |
| **restricted** | yes | yes | yes | yes | yes |
| **port-restricted** | yes | yes | yes | yes | no |
| **symmetric** | yes | yes | yes | no | no |

With a fifth of all datagrams lost: full cone with any kind, every punch
opened; restricted with restricted and port-restricted with
port-restricted, over 90% and 70% (all opened in the test runs). A "no"
fails within five seconds; there is no relay and no port prediction
(open questions for the owner, issue 801d). What to tell the player then:
"Couldn't reach the host directly. One of you may need to forward a port
on the router."

IPv4 only.
