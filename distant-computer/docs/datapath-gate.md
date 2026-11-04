# Datapath: one request through the gate

The current design. The issues that change it update this file.

## The path

    distant computer                       near computer (kuvalu)
    ────────────────                       ──────────────────────
    steward
      │ writes request (temp name, rename)
      ▼
    outbox/<id>
      │                    courier dials ──► copies outbox/<id>
      │                                        │
      │                                        ▼
      │                                      gate/waiting/<id>
      │                                        │ check (format, kind, paths)
      │                                        │   refused → ledger: failed
      │                                        ▼
      │                                      ledger: requested
      │                                        │
      │                                      owner runs `gate`
      │                                        │ reader for the kind shows it
      │                                        │ (a diff for commit and write)
      │                                        ▼
      │                                      approved ─────────► declined
      │                                        │                    │
      │                                        ▼                    │
      │                                      applier for the kind   │
      │                                        │ ledger: applied/failed
      │                                        ▼                    ▼
      │                                      gate/answered/<id>  ◄──┘
      │                    courier dials ◄── copies answered/<id>
      ▼
    answers/<id>
      │
    steward reads it on its next turn

## Step by step

1. **The steward writes a request** (`docs/request-format.md`) into the
   outbox, under a temporary name, then renames it, so the courier never
   copies half a file. It also writes `requested` into its own ledger.
2. **The courier carries it.** On each visit it lists the outbox, copies every
   id it has not seen into `gate/waiting/`, and moves the distant copy to
   `outbox/carried/`. Copying first and moving second means a dropped link
   can only cause the same request to be carried twice, and the gate ignores
   an id it already holds.
3. **The gate checks it.** It runs the format check and the kind's own
   check. A refused request goes to `gate/refused/` and the ledger as
   `failed`. Otherwise the ledger records `requested`.
4. **The owner answers.** `gate` with no arguments lists waiting requests,
   oldest first. `gate show <id>` runs the kind's reader. `gate approve <id>`
   and `gate decline <id> "note"` answer it. The answering command is a
   viewer: it reads the queue and writes answers, and the applying is done
   by the gate module.
5. **The applier runs** (approved only). Each kind's applier is one entry in
   a table from kind name to function. A failure writes `failed` with the
   error, and the request goes back to waiting, so a failed apply is never
   silently counted as done.
6. **The answer travels back** on the courier's next visit, into the
   distant computer's `answers/`.

## Where the folders are

    near:    tmp/shared-memory/gate/{waiting,answered,refused}/   (RAM)
             records/ledger                                       (disk, git)
    distant: <steward home>/outbox/, outbox/carried/, answers/    (disk)

The waiting queue lives in RAM. After a reboot of kuvalu it is rebuilt
because the distant computer still holds every request it has not had an
answer for, and the courier copies them in again. The ledger lives on disk,
because it is the record.
