# clock.lua

Milliseconds on the operating system's monotonic clock (issue 803), which
every thread reads alike and which never jumps when the wall clock is set.

- **`clock.now_ms() -> number`:** milliseconds since a fixed moment, with
  fractions. Messages carry whole milliseconds, so senders round.
