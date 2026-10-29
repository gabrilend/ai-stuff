# Datapath: where a file lives

The current design. The issues that change it update this file.

## Deciding a placement

    a path in the monorepo
      │
      ├─ tracked by git?                              → tracked
      ├─ matches a rule in input/placement?           → that rule's placement
      ├─ larger than `twin-above` bytes?              → twinned
      └─ otherwise                                    → refused: no rule covers it
                                                         (written to the placement
                                                          report; never guessed)

## input/placement

    twin-above = 52428800            # bytes; larger untracked files are twinned
    twinned   roms/                  # a folder: everything below it
    resident-near  notes/private/    # lives only on kuvalu
    resident-distant  loose/         # lives only on the distant computer

Rules are read top to bottom and the first match wins. That order is written
in the file's own header comment, so whoever adds a line knows its position
matters.

## Twinned files

    each side: manifest = list of (path, size, sha256), built with one worker
               per CPU core (hashing is parallel work)
    courier:   compare the two manifests
               only near has it, or near's is newer → copy near → distant
               only distant has it                   → a `write`-like request
                                                       (kind `twin`, phase 4)
                                                       through the gate
               checksums differ on both              → a `decision` request

Copies from near to distant need no approval: the distant computer is the
steward's machine. Copies from distant to near always go through the gate.

## Resident files and stubs

On the side where a resident file is absent, a **stub** sits at its path:

    distant-computer stub
    lives-on: near
    size: 1288490188
    sha256: 9c1e...

Reading the file through `fetch <path>` asks the courier (near) or the outbox
(distant) for it, and the file lands in `tmp/shared-memory/fetched/`, not over
the stub. The stub stays, and the fetched copy is a cache in RAM.

When the link is down, `fetch` fails with an error that says which computer
holds the file and how long ago the link was last up. It does not return an
empty file and it does not wait forever. That is the vision's "we lose the
entire file — until we reconnect".
