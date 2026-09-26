# test_net_messages_c.lua

Generates `net-messages.h` and a C program holding the bytes of every
example message and every value Lua reads from them; compiles it (warnings
as errors) and runs it (issue 804). Every value must match exactly (floats
bit for bit); a cut-short message, too little room, and the wrong message
must be refused. Builds in `tmp/net/`.

- **Usage:** `luajit src/tests/test_net_messages_c.lua [DIR]`.
