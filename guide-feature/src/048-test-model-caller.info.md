# 048-test-model-caller — info

Tests for issue 401b, against two stand-in llama.cpp servers (047) on
127.0.0.1, every call over HTTP through curl as it will be to llama-server:
- the copies' upstream notes; the client loading nothing from another
  project;
- the stand-ins listening on the loopback address only (`/proc/net/tcp`);
- a role's endpoint, a chat reply (the conversation as sent, its usage, its
  seconds, a broken UTF-8 byte replaced), a token count, embeddings (each
  vector matched to its text by index, though the server lists them last
  first);
- a request past its timeout and a server error, each naming the endpoint;
- a call the endpoint is not for, refused before sending;
- the file read on every call: a `use.` line edited between two calls
  switches the role;
- refused: a `use.` line naming an endpoint that does not exist, no `use.`
  line, no timeout, a missing key file (402), a voice on an embedding endpoint, no file;
- a stopped server: not reachable, its calls errors naming it, and no
  fallback to the other chat endpoint;
- the client's command line; this project's own `endpoints` file;
- `scripts/refresh-vendored` against a throwaway upstream repository:
  up to date, `--check`, a plain copy replaced, a changed copy merged, a
  conflict left beside the copy.

    luajit src/048-test-model-caller.lua [--dir ROOT]
