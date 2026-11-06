# run-net-tests.sh

Runs the tests of issues 803, 804, 405f, 801a and 801b: messages (Lua and
the generated C unpacker), the server, the server on its own thread, the
crowd, the matchmaking messages, and the matchmaking server (its rules, then
as a daemon in a network of its own, which needs `unshare -rn`). Exits 1 if any fails. **Usage:**
`run-net-tests.sh [DIR]`.
