# link.lua

One direction of a connection between threads (an effil channel carrying
byte strings), which can be made to behave like a bad network (issue 803).

- **`link.sender(channel, disturbance) -> sender`:** `disturbance` (a table,
  every field optional): `delay_ms`, `jitter_ms` (a random extra, 0 up to
  this), `loss` (chance 0 to 1), `silent` (list of `{from_ms, to_ms}` from
  `start_ms`, when nothing arrives), `seed` (repeatable draws), `start_ms`.
- **`sender:send(bytes)`:** decides the message's fate and queues it with
  the moment it is due. Counts `sent` and `lost`.
- **`link.receiver(channel, disturbance) -> receiver`**; **`receiver:take(now_ms) ->
  list of bytes`:** every message due by then, earliest due first (jitter
  can make a later message due sooner). The receiver's own `delay_ms`,
  `jitter_ms` and `loss` (optional, changeable while running) are applied
  as messages come out of the queue; it counts `received` and `lost`.
- **`link.random_from(seed) -> function`:** a small repeatable random
  sequence, 0 up to 1.
