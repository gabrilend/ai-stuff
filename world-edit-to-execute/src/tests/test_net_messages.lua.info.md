# test_net_messages.lua

Checks every gameplay message (issue 803) comes back from its bytes exactly
as it was and re-encodes to the same bytes; the sizes of a unit record (38
bytes) and a heard beat (5); that floats come back as 32-bit floats; and
that each kind of bad input is refused with a reason.

- **Usage:** `luajit src/tests/test_net_messages.lua [DIR]`; exits 1 on a
  failure.
