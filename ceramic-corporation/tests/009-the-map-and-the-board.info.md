# 009-the-map-and-the-board

Covers issues 102 and 103.

- The bakery is valid with one warning, and its boxes' states are the ones
  document 002 reads off it by hand.
- **One smallest broken file per rule code**, L1 to L9, M1 to M15 and S1 to S4,
  each refused *with that code* — refused for the wrong reason is a failure.
- W2 and W3 are warnings and not refusals; the reader names every problem.
- The bakery's board equals the table in document 004.
- A stack of ten pull requests: the bottom frees one and reaches nine, ranks
  first, and after it is merged the next one leads with eight.
- A two-box loop ends and neither box is in its own reach.
- An outside party is a source, shown with its speakers.
- A box waiting on two sources is freed by neither alone.

Run under LuaJIT and Lua 5.4 by `./run-tests`.
