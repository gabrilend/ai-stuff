# 201 — A messenger in Lua

## Current behavior

Nothing exists.

## Intended behavior

**The host: a LuaJIT program Firefox starts and talks to over native
messaging.** The framing, message types and the host's life are in
`docs/006-datapath-the-bridge.md`.

It reads standard input as a stream of messages — four bytes of length in the
machine's byte order, then that many bytes of UTF-8 JSON — and writes answers
the same way to standard output. Nothing else may ever be written to standard
output: one stray `print` corrupts the stream and Firefox closes the pipe
without saying why. Logging goes to `tmp/shared-memory/host.log`.

**Messages are dispatched by a table keyed on the message's `type`.** An
unknown type is answered with an `error` message and logged; it does not stop
the host. A malformed frame (length larger than what arrives, JSON that does
not parse) is logged and ends the host, because the stream can no longer be
trusted to be in step.

**The host's life:** read `input/` first (the settings file from `105`), serve
until standard input closes, write `goodbye` into `output/`, exit.

**Pictures are bigger than one message may be** (1 MB, host to Firefox). The
first thing to establish, with a throwaway test, is whether the extension's
background script can read a file the host wrote into the shared-memory folder.
If it can, pictures travel as paths; if not, as base64 split into numbered
pieces. Whichever is chosen is written into `docs/006`.

## Suggested implementation steps

1. `src/` — the framing module: read one message, write one message. JSON via
   `dkjson` from the monorepo's `libs/lua/`.
2. `src/` — the host's main loop and its dispatch table, with one handler to
   start: `hover`, which runs phase 1 (`102`, `104`, `105`) and answers with
   the quantity record or `no_quantity`.
3. The native messaging manifest, and an install script that writes it into
   `~/.mozilla/native-messaging-hosts/` with the host's absolute path filled
   in from `${DIR}`.
4. Tests without Firefox: a Lua test that starts the host as a child process,
   feeds it framed messages built from the saved fixtures, and checks the
   framed answers. Includes a deliberately broken frame.
5. The picture-transport experiment, its result written into `docs/006`.

## Related

`docs/006-datapath-the-bridge.md` · needs `102`, `104`, `105` · blocks `202`,
`203`, `204`, `205`
