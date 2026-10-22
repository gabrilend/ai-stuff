# 402 — Relay to remote models

phase 4, the thinkers

## Current behavior

Only `local-llama` exists (401). A voice's model must run on its own
machine.

## Intended behavior

The owner asked: "can we add functionality to have the three mini-computers
connect to remote locations to do their LLM processing? Acting as relay
nodes."

Two more entries in the backend table, same shape as 401:

- `remote-llama`: a llama.cpp server on another machine, by address and
  port. The first target is a server on kuvalu using its GTX 1080 Ti, which
  keeps everything on the home network.
- `remote-api`: a hosted model service over HTTPS. The first one built is
  whichever service the owner chooses (`docs/open-questions.md`, 3).

The voice stays the fg-sora. Only "turn this conversation into a reply"
travels. The page, the context gathering, the fit check, the frame counter
and rmail stay where they are.

Addresses, keys and passwords are read from a file named in `input/thinker`
that lives outside the repository. A missing key is an error at start, not
at the first turn.

A failing remote backend is an error for that turn, counted, and the voice
tries again next turn. There is no quiet switch to another backend
(`docs/open-questions.md`, 4).

The current frame format does not say which backend wrote a frame. The
thinker's log and goodbye receipt record it for each turn.

## Suggested implementation steps

1. `remote-llama`: the same calls as `local-llama` with a different address.
   It mostly reuses 401.
2. `remote-api`: once the owner names the service, its request and reply
   shape, its token counting and its context length.
3. HTTPS from LuaJIT: check the shared libs for a TLS binding (rmail
   already links OpenSSL).
4. Tests: each backend answering; each failing; a missing key at start.

## Related documents

- `docs/datapath-thinker.md`, "Inference backends"

## Open questions

- Which remote places, and may project files leave the house?
  (`docs/open-questions.md`, 3)
- Ever switch backends on failure? (`docs/open-questions.md`, 4)
- Should the page show which backend wrote each voice's frame? That would
  add a header to the frame format and a field to the page protocol.

## Blocked by

401.

## Blocks

407, 503.
