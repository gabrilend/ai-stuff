# 054-test-endpoint-tools — info

Tests for issue 402, against three stand-in llama.cpp servers (047) on
127.0.0.1: a chat server, a chat server that asks for a key
(`--key-file`), and an embedding server. The key file is in a home folder
inside the throwaway, outside its project.

- the `use.` line rewritten: only that line, its comment kept, a role that
  starts another's name left alone, a missing line added;
- `scripts/use-endpoint`: a switch (said, written, read on the next call),
  the same choice again (nothing written), and back; refused with nothing
  written: an endpoint not in the file, the wrong kind for a voice or the
  embedder, no timeout, not answering, a bad role name, a rewritten file
  that does not read back;
- keys: missing, not taken by the provider (401), inside the project, two
  keys, empty; no refusal shows the key; no header for an endpoint with no
  key; while a request is in flight the key is on no command line and its
  header file is mode 600, and afterwards it is gone; the server's log
  never holds it;
- `from_canvas`: each voice's own line, the outside provider's key read on
  this machine, a voice with no line, a key file the voice does not have;
- `scripts/list-endpoints`: every endpoint, its kind, address, roles,
  whether it answers and why not, a key file that cannot be read, a
  broken file.

    luajit src/054-test-endpoint-tools.lua [--dir ROOT]
