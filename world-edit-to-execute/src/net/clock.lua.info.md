# clock.lua

Milliseconds on the operating system's monotonic clock (issue 803), which
every thread reads alike and which never jumps when the wall clock is set.

- **`clock.now_ms() -> number`:** milliseconds since a fixed moment, with
  fractions. Messages carry whole milliseconds, so senders round.
- **`clock.sleep_ms(ms)`:** rests the thread through the operating system
  (`nanosleep`). `effil.sleep(1, "ms")` doesn't rest at all, and the
  server's thread spun a core flat out with it.
