# 501 — Survey the fg-sora machines

phase 5, bringing up the fg-sora machines

## Current behavior

The minimal-llm project measured fg-sora-1 (192.168.1.11) and assumed the
other two match (`/home/ritz/programs/sora/minimal-llm/docs/005-cluster-topology.md`).
Unknown: which C library they use, whether the other two share the first's
user name and layout, what is installed (LuaJIT, a compiler, OpenSSL),
whether ports 10101, 20202 and 30303 are free and open. The owner says
nothing listens on them yet.

## Intended behavior

A survey script, run from kuvalu, that logs into each machine and writes one
report file per machine to `tmp/shared-memory/survey/`: hostname, C library
(from `ls -l /lib/ld-*`), processor and its instruction sets, memory, free
disk, which of the needed programs exist, and whether the guide port is free
and reachable from kuvalu.

It reads no credentials from the repository. It uses the owner's SSH setup,
and the owner adds keys if needed.

## Suggested implementation steps

1. The script, one read-only command per line, reporting what it could not
   find as an error, not a blank.
2. Run it and record the answers in `docs/architecture.md` (the machines
   table) and in the minimal-llm topology document, which shares the
   machines.

## Related documents

- `docs/architecture.md`, "The machines"

## Open questions

- C library, glibc or musl (`docs/open-questions.md`, 2). This survey
  answers it.
- How the owner wants credentials handled for logging in (they offered
  them; they stay out of the repository either way).

## Blocked by

None.

## Blocks

502, 503.
