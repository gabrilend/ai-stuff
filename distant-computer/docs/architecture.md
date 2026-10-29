# Architecture

How the pieces of distant-computer fit together. Every other document in
`docs/` zooms in on one part of this one. Words in **bold** are the project's
core terms, defined in `docs/core-terms.md`.

## The two computers

    kuvalu (the near computer)                 the Linode (the distant computer)
    ───────────────────────────                ─────────────────────────────────
    the owner sits here                        the steward lives here
    the monorepo at /mnt/mtwo/.../ai-stuff     a clone of the same monorepo
    the gate: every request waits here         the outbox: requests are written here
    the courier: dials out, carries both ways  the watchdog: connected or waiting?
    the ledger: every request and answer       the steward's own copy of the ledger

The **near computer** is kuvalu, the machine the owner works at. The
**distant computer** is a Linode the owner creates. It holds a clone of the
monorepo (`/home/ritz/programming/ai-stuff/`, which is a link to
`/mnt/mtwo/programming/ai-stuff/`) and runs the **steward**: a Claude Code
session running headless, with no terminal attached, that works through the
issue files of the projects there.

## One direction of dialing

Only the near computer ever opens a connection. The **courier** on kuvalu
dials the distant computer over SSH on a timer. It does three things each
time it connects:

1. **Carry requests in.** It copies new files from the distant computer's
   **outbox** into the near computer's **gate**.
2. **Carry answers out.** It copies the owner's answers back, and pushes the
   monorepo's `main` branch to the distant clone.
3. **Leave a heartbeat.** It writes the current time into a file on the
   distant computer. That file's age is how the distant computer knows whether
   the near computer is still there.

So the distant computer holds no key, password or address that reaches
kuvalu. It cannot write to the near computer at all. That makes the gate
structural, not a policy. The only way a change gets from the distant
computer onto kuvalu is to be written as a **request**, carried by the
courier, and **approved** by the owner. Kuvalu also never has to open a port
to the internet.

## The gate

The gate is a folder of waiting requests on kuvalu, plus one command for
answering them. Every request has a **kind**, and each kind has its own
reader (to show it) and applier (to carry it out):

| kind | what it asks for | applied as |
| --- | --- | --- |
| `commit` | merge one commit from the distant branch | a cherry-pick onto `main`, through the house own-lines commit tools |
| `write` | put these bytes at this path on kuvalu | a write to a temporary name, then a rename into place |
| `sudo` | run this command as root on kuvalu | `sudo` in a terminal the owner is watching; never in the background |
| `outward` | act in the world: list for sale, give away, spend, sign, email | never applied by a program. The owner does it, or someone the owner hires does it. The gate records that it was done |
| `decision` | a question only the owner can answer | the answer text is carried back to the steward |

The owner answers each request **approved** or **declined**. Both answers
are written to the **ledger**, and so is the request. `docs/datapath-gate.md`
follows one request from start to finish.

## What the steward may do without asking

On the distant computer, almost anything. It is the steward's machine:
root access, its own tools, its own way of writing code if it prefers. It
should prefer the house style (`~/.claude/CLAUDE.md`, copied over). The lines
it does not cross on its own are:

- anything that lands on kuvalu (that is the gate's job);
- anything **outward**: money, contracts, sales, gifts, messages to people;
- anything **crystallized**, while it is **waiting** (below);
- its **budget**: the API spending ceiling the owner sets in `input/budget`.
  The steward's own thinking costs money, so the budget is the first
  outward line, and the one it meets every hour.

## Connected and waiting

The **watchdog** on the distant computer reads the age of the heartbeat
file. While the heartbeat is fresh, the distant computer is **connected**.
When it is older than the limit in `input/link`, the distant computer is
**waiting**. While waiting:

- the steward stops writing to every **crystallized** place, meaning
  everything owned by the near computer: the clone's `main`, near-owned
  twinned files, and every place listed in `input/crystallized`. The pledge
  runs both ways, so kuvalu does not touch the distant computer's parts
  either;
- it may use resources nothing else is using (CPU, memory, and the
  **loose area**, a scratch folder that belongs to no project). It can run
  tests, read, draft, and think in writing there;
- requests it would have made pile up in the outbox. Nothing is lost,
  because the outbox is on its own disk;
- on reconnect, everything in the loose area is either offered through the
  gate or left in the loose area. It is never merged silently.

`docs/datapath-link.md` covers this in detail.

## Where files live

Every file in the monorepo has one **placement**, read from rules in
`input/placement`:

| placement | lives | when the link is down |
| --- | --- | --- |
| **tracked** | in git, so on both computers | readable on both |
| **twinned** | a large file kept whole on both computers, matched by checksum | readable on both |
| **resident** | on one computer only; the other side has a short stub naming where it lives, and fetches it on request | the far copy is unreachable until reconnect, and reading it is an error, not an empty file |

Large files are twinned, as the vision asks. A resident file's loss during a
disconnection is temporary by design: "we lose the entire file — until we
reconnect, of course." `docs/datapath-placement.md` has the rules.

## Programs, in reading order

Every program reads its settings from `input/<program>` first and writes
`output/goodbye` last (`docs/settings-files.md`). Data-making programs and
data-viewing programs are kept apart: the gate's queue and ledger are data;
the answering command, the dashboard, and the HTML pages are viewers of it.

| program | runs on | phase |
| --- | --- | --- |
| settings reader, goodbye writer | both | 1 |
| the ledger | both | 1 |
| the gate (queue, readers, appliers, `gate` command) | near | 2 |
| the courier | near | 3 |
| the watchdog | distant | 3 |
| placement (rules, twins, stubs, fetch) | both | 4 |
| the provisioner and health check | near, aimed at distant | 5 |
| the steward loop | distant | 6 |
| the voices (personas) | distant, talking to near | 7 |
| goals, listings, hand-me-downs | distant drafts, near decides | 8 |
| the viewers (dashboard, HTML site) | near | 9 |

## Lines this design will not move

- Nothing outward happens without one approval from a person, per action.
  The owner wants the steward to have total autonomy, and inside its machine
  it does. But a program cannot be a party to a contract or hold money. An
  action taken in the owner's name, with no one watching, cannot be undone
  by reverting a commit. "Hire someone who does that for us" is a **funding
  goal** the steward can work toward (`docs/datapath-outward.md`). Until that
  person exists, the owner is the one who presses yes.
- The distant computer never holds credentials for kuvalu.
