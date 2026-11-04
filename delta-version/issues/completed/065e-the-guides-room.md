# Issue 065e: The Guide's Room

**Status**: Completed 2026-10-10
**Parent**: 065-the-reading-walk.md
**Dependencies**: None
**Blocks**: 065f, 065g

## Current Behavior
`scripts/reading-walk-guide-room.lua create <name>` makes a guide's room after
a typed "yes"; `check` and `list` read a room's ledgers through
`scripts/libs/guide-room.lua`. Tests: `scripts/test-guide-room.sh`. No room
has been made on this machine yet (it needs sudo, run by the person).

## Intended Behavior
**Consent first.** Every step is shown — one sudo command each, with why —
before anything runs, and nothing runs without a typed "yes". The person
decides what the machine agrees to.

**The room.** A system account `guide-<name>` that nobody can log into, and a
folder `/var/lib/reading-walk-guides/<name>/` owned by it, mode 0755: everyone
may look, only the guide may write. One account and room per guide, as many as
the person allows. Root can still read everything; the room's privacy from
the owner is by agreement (hardware confidential computing would be needed
for more, and is not used).

**The ledgers.** Three tab-separated files the guide appends to:
- made public — written, path, note: what it shares and what it is;
- kept to itself — written, path: what it keeps, known to exist;
- changes — when, path, edit or extension: later changes, dated apart so the
  record reads as a line.
Every entry names a real file in the room; entries are in time order; a
change follows a listing. A check reports every broken rule at once.

## Suggested Implementation Steps
1. Ledger library: append with a time stamp, read, check; paths refused if
   absolute, climbing out, or holding tabs.
2. Room maker: plan, consent, steps; dry run.
3. Tests on a RAM room with a stand-in clock: one well-kept room, one broken
   ledger per rule, dry run, refusal without consent, bad names.

## Decided against
- A room inside the reader's home or the project: the reader would own it.
- Running the steps as one script under sudo: one command per step names the
  step that failed and leaves the person seeing exactly what ran.
