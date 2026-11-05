# 703 — Reach the endpoints from each voice

phase 7, bringing up the mini-computers

## Current behavior

Every endpoint is a llama.cpp server on kuvalu (401), reached so far only
from kuvalu itself.

## Intended behavior

Each mini-computer can reach every endpoint its role uses:

- kuvalu's llama.cpp servers, across the home network (allowed between the
  four machines);
- any outside provider in `endpoints`, on connections the voice opens, with
  its key file installed outside the repository;
- the model caller's own needs: `curl` and `dkjson`, or a replacement if the
  survey (701) finds no `curl`.

A check script runs `scripts/list-endpoints` (402) on each voice from
kuvalu and reports which endpoints each can reach.

Whether a mini-computer should also run its own llama.cpp server later is a
question for the owner. If so, it must be built for the i5-8500T (AVX2 and
FMA, **no** AVX-512, so a build tuned for kuvalu's processor would crash
there) and for the machine's C library.

## Suggested implementation steps

1. Install the client's needs on each voice.
2. Copy `endpoints` and any key files.
3. The check script.

## Related documents

- `docs/endpoints.md`
- `docs/network.md`

## Blocked by

401, 402, 701.

## Blocks

704.

## Note (2026-11-05, from issue 402)

- The voices keep no `endpoints` file: kuvalu names each voice's endpoint
  in the canvas it sends (`docs/endpoints.md`, "Where the file lives").
  Step 2 is then only the key files, at the path the canvas line names.
- `scripts/list-endpoints` runs on kuvalu, where `endpoints` is. The check
  script here instead asks, from each voice, every address the newest
  to-voices canvas names for that voice (the client's `--ping`, and a
  token count where a key is needed), and reports which it can reach.
