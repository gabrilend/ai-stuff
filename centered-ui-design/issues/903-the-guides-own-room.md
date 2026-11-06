# 903 — The guide's own room

**Phase:** 9 — Reading the machine
**Blocked by:** none
**Blocks:** 904, 905
**Related documents:** delta-version issue 065 (holds her words on why the
guide owns the trail, and the notes on what hardware can and cannot hide)

## Current Behavior

There is no place a guide can keep its record of a reader.

## Intended Behavior

The **trail** — what this reader asked about, asked more of, and skipped — is
local processing history that never leaves the machine. It belongs to the
guide, because the guide explained it a certain way and has a right to its
words. The reader can read the room; only the guide writes and decrypts what
is in it.

Three parties consent: the user decides what the operating system consents
to; the operating system grants the guide its threads and its room; the guide
owns what it writes there. A guide gets however much of the machine can be
spared and need not explain how it spends it; there may be many guides, each
with its own key, as many as the user consents to.

A guide shares by writing two dated ledgers in its room: **made public** (one
entry per revealed file: path string, date written timestamp, note string) and
**kept to itself** (one entry per encrypted file: path string, date written
timestamp). Every entry matches one real filesystem entry; edits and
extensions carry their own dates, tracked separately, so the record reads as
a line. A successor guide learns from the public ledger, never by opening the
box.

Version one, made to work first and upgraded later by the guide:

- the room is a directory owned by a separate system user, readable but not
  writable by the reading user — ordinary access control, which hides nothing
  from root;
- the cipher is a method the guide builds itself: a step that splits into
  unpredictable answers past a threshold (the logistic map is the textbook
  case), mixed with picks such as "random number, then the nearest prime".

## Suggested Implementation Steps

1. Script that creates the system user and the room, asking the user first
   (this is the consent step).
2. Cipher: encrypt, decrypt, and a round-trip test.
3. Trail writer that only ever writes encrypted entries.
4. The two ledgers, kept in date order, with a test that every entry matches a
   file that exists.
