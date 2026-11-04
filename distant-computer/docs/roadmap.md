# Roadmap

Phases are groups of related functionality, not stages in time. Lower phases
hold what higher phases build on. Each phase ends with a demo in
`issues/completed/demos/phase-N-demo`, run from `./run-phase-demo`.

Everything up to phase 4 runs entirely on kuvalu, with the `local` transport
(a folder standing in for the distant computer). The Linode is first needed
in phase 5.

## Phase 1 — the record and the settings

What every program stands on: reading `input/`, writing the receipt, and the
append-only, checksum-chained ledger.

- settings reader and goodbye writer (`docs/settings-files.md`)
- the ledger: append, read, check the chain (`docs/ledger-format.md`)
- **demo:** writes a ledger of a few hundred entries using several workers,
  checks the chain, edits one byte of a copy and shows the checker pointing at
  that exact entry; prints entries-per-second and the receipt.

## Phase 2 — the gate

The near computer's waiting room for requests.

- request files: write, parse, check (`docs/request-format.md`)
- the queue and its folders; the readers and appliers, one per kind, in a
  table
- the `gate` command: list, show, approve, decline
- **demo:** a stand-in steward fills an outbox with one request of every
  kind, including some that must be refused; the demo approves and declines
  them through the same functions `gate` uses, and shows the queue counts,
  the ledger, and the files the appliers wrote.

## Phase 3 — the link

Carrying both ways, and knowing when the other side is gone.

- the transport: `local` and `ssh`, same functions
- the courier: one visit, steps 1–6 of `docs/datapath-link.md`
- the watchdog and `link/state`; `input/crystallized`
- git sync: `main` out, `distant-work` in, as `commit` requests
- **demo:** two folders on kuvalu, one as each computer. A run of visits,
  then the link is cut (the transport is told to fail), the watchdog turns to
  waiting, requests pile up, the link is restored, and they all arrive. The
  demo shows a timeline of state changes and counts.

## Phase 4 — placement

Where each file lives.

- `input/placement` rules and the placement report
- manifests built in parallel, and twinned-file sync
- resident files: stubs and `fetch`
- **demo:** a tree with tracked, twinned and resident files; sync, cut the
  link, show `fetch` failing with its message, restore, show it succeed;
  bytes moved and hashing rate.

## Phase 5 — the distant computer

Making the Linode into a distant computer, from a fresh install.

- the provisioner: given an address and a root login, create the steward's
  user, install LuaJIT, git, rsync and Claude Code, clone the monorepo, set
  up the link's key (near → distant only), firewall, time sync
- the health check: every assumption above, checked and reported
- **demo:** the health check's report against the real distant computer.

## Phase 6 — the steward

The session that works there.

- the turn prompt and the copied house instructions
- the loop: pick work, run a turn, file requests, record cost
- the budget
- waiting mode and the loose area
- **demo:** a day of the steward's turns, replayed from its ledger: issues
  touched, requests filed, approvals, cost against budget.

## Phase 7 — the voices

The vision's "threaded experts (personalities) that relate to the user at
whatever level of abstraction they please".

- persona files: name, abstraction level, what it is responsible for
- a conversation mailbox between each voice and the owner
- **demo:** the same piece of work described by three voices, at three levels.

## Phase 8 — the outward world

Goals, listings and hand-me-downs, all as `outward` requests
(`docs/datapath-outward.md`).

- funding goals and their progress, read from the ledger
- listing drafts
- hand-me-down notices
- **demo:** the goals board: each goal, its progress, and the requests that
  moved it.

## Phase 9 — seeing it

Viewers only. They read the ledger, the queue and the receipts, and change
nothing.

- a terminal dashboard of the gate and the link
- the HTML documentation site (`docs/HTML/`), with a feedback box per page
- **demo:** the dashboard and the site, opened in Firefox, with numbers from
  the real ledger.
