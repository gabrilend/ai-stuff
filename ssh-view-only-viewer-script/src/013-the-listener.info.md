# 013-the-listener.lua

Waits for packets and hands each one, unexamined, to a callback. Knows
nothing about what makes a packet good.

## listener.carriers

A table of ways a packet may arrive — a dispatch table, so adding a
carrier is adding a row.

| name | what it does |
|---|---|
| `udp` | binds a UDP port and reads datagrams |
| `stdin` | one packet per line from standard input |

UDP rather than TCP because a knock is one message with no conversation
after it. A wrong packet gets no reply, so from outside a listening
machine and a silent one look the same.

`stdin` exists so "did the machine do the right thing with this packet"
can be asked without a network being part of the question.

## listener.listen(carrier_name, options, on_packet, should_continue)

| | type | meaning |
|---|---|---|
| in `carrier_name` | string | key into `carriers` |
| in `options` | table | `port`, `address`, `tick_seconds` |
| in `on_packet` | function | called `(data, from_host)` |
| in `should_continue` | function or nil | return false to stop |

**Raises on an unknown carrier**, naming the ones it knows. It does not
fall back — a doorman that quietly read standard input when asked for a
network port would appear to run and never hear anybody.

`tick_seconds` is the UDP read timeout, and it is what lets the loop come
up for air to sweep expired grants. Without it a machine nobody knocks at
would never remove anything.

## Notes

- `READ_SIZE` is 1024, deliberately larger than the 256 the arrangement
  accepts, so an oversized packet is seen and refused with a reason
  rather than cut down to a length that might accidentally parse.
