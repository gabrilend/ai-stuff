# messages.lua

The gameplay messages between the server and its clients, and the one way
each becomes bytes and back (issue 803). Each message is described once as
data (its fields in order); one encoder and one decoder walk any
description.

- **`messages.encode(name, message) -> bytes`** (`string`): refuses, with an
  error naming the message and field, a missing field, a fraction or
  negative number in a whole-number field, or a number too big for it.
- **`messages.decode(bytes) -> name, message`**: refuses empty bytes, an
  unknown type, a message cut short, or bytes left over.
- **`messages.f32(value)`**: a number as it comes back through a 32-bit
  float field (for comparisons in tests).
- **`messages.names`**: every message name, in type order.
- **`messages.order_kind`**, **`messages.event_kind`**,
  **`messages.refusal`**: named numbers for the one-byte fields.

**Layout:** a type byte, then the fields in order, little-endian. Field
kinds: `u8`, `u16`, `u32`, `f32` (4 bytes), and a list (a `u16` count, then
records). A unit record is 43 bytes.

| Type | Name | Direction | Fields |
|---|---|---|---|
| 1 | order | client → server | order_id u32, given_tick u32, kind u8, target_x f32, target_y f32, target_unit u32 (0: a point), units list of {id u32} |
| 2 | heard | client → server | tick u32 (newest received) |
| 3 | order_answer | server → client | order_id u32, accepted u8, effect_tick u32, refusal u8 |
| 4 | unit_states | server → client | tick u32, units list of {id u32, x y z f32, vx vy vz f32, facing f32, anim u16, anim_phase f32, radius f32, team u8} |
| 5 | events | server → client | tick u32, events list of {kind u8, tick u32, unit u32, other u32} |
| 6 | waiting | server → client | tick u32, paused u8, silent list of {player u8, silent_ms u32, countdown_ms u32} |
| 7 | tolerance | client → server | ms u32 |
| 8 | tolerances | server → client | in_force_ms u32, players list of {player u8, ms u32} |
| 9 | drop_vote | client → server | player u8 |
| 10 | votes | server → client | needed u8, silent list of {player u8, votes u8} |
