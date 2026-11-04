# Datapath: the link, the heartbeat, and waiting

The current design. The issues that change it update this file.

## One visit of the courier

    near (courier, every `interval` seconds from input/courier)
      │
      ├─ 1. ssh: write now() into  distant:link/heartbeat
      ├─ 2. rsync: distant:outbox/*  → near:gate/waiting/      (requests in)
      ├─ 3. ssh: move carried ids    → distant:outbox/carried/
      ├─ 4. rsync: near:gate/answered/* → distant:answers/      (answers out)
      ├─ 5. git fetch distant distant-work → refs/distant/work  (commits in)
      ├─ 6. git push distant main         → distant's main      (main out)
      ├─ 7. twinned files: compare manifests, copy what differs (phase 4)
      └─ 8. ledger: one `connected` entry when the last visit failed and
               this one worked
    any step fails → the visit ends, the next one starts from step 1

Every step can be repeated safely: running a visit twice does the same as
running it once. A link that drops in the middle of a visit costs a repeat,
never a loss.

The **transport** is chosen in `input/link`: `ssh` (the real distant
computer) or `local` (a folder on kuvalu standing in for it, which is how
every test and demo runs without the Linode).

## The watchdog's view

    distant (watchdog, every `check` seconds)
      │ age = now − contents of link/heartbeat
      ├─ age ≤ limit → connected
      └─ age > limit → waiting
      │ on a change: write state to link/state, ledger entry
      ▼
    steward reads link/state before every action

The limit is set in `input/link` (`waiting-after = <seconds>`). The heartbeat
holds the time the courier wrote, and the age is measured against the
distant computer's own clock. The two clocks must agree to within a few
seconds, so both computers run time sync (phase 5 checks it).

## Waiting

When `link/state` says `waiting`, the steward:

- stops; it does not start a new piece of work on any **crystallized**
  place. A turn already in progress finishes its current file write and
  then stops;
- may work in the **loose area** (`<steward home>/loose/`), using CPU and
  memory that nothing else is using, at a lower priority (`nice 19`). It can
  run tests on copies, read, draft issue notes, and write to `desire/`-style
  notes;
- keeps writing requests to the outbox. They wait there.

When the state returns to `connected`, the steward writes one `note` request
listing what it made in the loose area, so the owner can ask for any of it
through the gate. Nothing moves out of the loose area on its own.

## Crystallized: the other side's parts

The owner's answer (notes/vision, third part): "if we pledge never to touch
their parts until they return or are no longer wanted... Forced cooperativity
by tying together two ankles."

So every place has an **owning side**, and crystallized means *the parts
that belong to whichever side is absent*. The pledge runs both ways:

| place | owned by | while the link is down |
| --- | --- | --- |
| the clone's `main` and its working tree | near (only the courier's push moves it) | distant must not touch it |
| `distant-work`, the outbox, `loose/`, the steward's ledger | distant | near must not touch them (it cannot reach them anyway) |
| a twinned file | the side its placement rule names (`docs/datapath-placement.md`) | the other side must not change its copy |
| a resident file | the side it lives on | the other side holds a stub and cannot fetch it |
| anything in `input/crystallized` | near, by the owner's say | distant must not touch it |

The pledge is kept by code, not just by the steward's prompt: the
watchdog's may-touch check answers no, and the steward's per-turn Claude
Code settings deny writes there (604). Kuvalu's side is kept the same way:
while the courier cannot reach the distant computer, no near program
changes a distant-owned twin.

"No longer wanted" is the only way out of the pledge. A side lets go of its
part by a `decision` request ("give up ownership of <place>?"), and that is
approved like any other request. Absence alone never transfers anything.

The vision also says to "harden a system by making it inoperable without
networked components". Resident placement already does this: a resident
file is unusable on the far side without the link, by design. Making more of
a system depend on both computers is a choice made per file in
`input/placement`, never a default.

## input/crystallized

One place per line: a path, absolute or relative to the monorepo root. `#`
starts a comment. A folder covers everything below it. These are places the
owner wants held as near's, even when no other rule says so.
