# test_matchmaking_protocol.lua

Checks the matchmaking messages (issue 801a): MessagePack against the bytes
other programs write for each kind of value, and its refusals; each of the
sixteen messages coming back from its bytes as it was, giving the same
bytes again, and carrying its header and version; three messages on a
stream cut at every byte coming out whole and in order; and each kind of
bad message refused with a reason that names the message and field; and the
host's optional name in REGISTER_GAME (801b).

- **Usage:** `luajit src/tests/test_matchmaking_protocol.lua [DIR]`; exits 1
  on a failure.
