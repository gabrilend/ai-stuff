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

    twin-above = 52428800                 # bytes; larger untracked files are twinned, owned by near
    twinned-near      roms/               # whole on both; near owns it
    twinned-distant   renders/            # whole on both; distant owns it
    resident-near     notes/private/      # lives only on kuvalu
    resident-distant  loose/              # lives only on the distant computer

Every rule names the **owning side**, because ownership decides what is
crystallized while the link is down (`docs/datapath-link.md`, "Crystallized:
the other side's parts"). The side that does not own a twin may read its
copy, but must never change it.

Rules are read top to bottom and the first match wins. That order is written
in the file's own header comment, so whoever adds a line knows its position
matters.

## Twinned files

    each side: manifest = list of (path, size, sha256), built with one worker
               per CPU core (hashing is parallel work)
    courier:   compare the two manifests
               near-owned, differs or missing on distant → copy near → distant
               distant-owned, differs or missing on near → a `twin` request
                                                           (phase 4) through the gate
               changed on the side that does not own it  → an error naming the
                                                           file: the pledge was broken

Copies from near to distant need no approval: the distant computer is the
steward's machine. Copies from distant to near always go through the gate.
A copy changed by the side that does not own it is never merged or
overwritten quietly. It is reported, because it means a program broke the
pledge, and that program is the bug to find.

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
