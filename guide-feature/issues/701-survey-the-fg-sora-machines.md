# 701 — Survey the mini-computers

phase 7, bringing up the mini-computers

## Current behavior

The minimal-llm project measured fg-sora-1 (192.168.1.11) and assumed the
other two match
(`/home/ritz/programs/sora/minimal-llm/docs/005-cluster-topology.md`).
Unknown: which C library they use, whether the other two share the first's
user name and layout, which tools are installed (LuaJIT, `curl`, `git`,
OpenSSL, a compiler), free memory for a RAM clone, and whether the rmail
ports are free. The owner says nothing listens on them yet.

## Intended behavior

A survey script, run from kuvalu, that logs into each machine and writes one
report per machine to `tmp/shared-memory/survey/`: hostname, C library (from
`ls -l /lib/ld-*`), processor and its instruction sets, memory and free
memory, free disk, which needed programs exist, whether its rmail port is
free, and whether it can reach kuvalu's llama.cpp ports and SSH (the router
rules, `docs/network.md`).

It reads no credentials from the repository and uses the owner's SSH setup.
Anything it cannot find is reported as an error, not a blank.

## Suggested implementation steps

1. The script, one read-only command per line.
2. Run it and record the answers in `docs/architecture.md` and in the
   minimal-llm topology document, which shares these machines.

## Related documents

- `docs/architecture.md`, "The machines"
- `docs/network.md`

## Open questions

- C library and tools (`docs/open-questions.md`, 1). The survey answers it.
- How the owner wants login credentials handled. They offered them; either
  way they stay out of the repository.

## Blocked by

None.

## Blocks

702, 703.
