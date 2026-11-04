# reading-walk-guide-room.lua — info

Gives a reading-walk guide a room of its own, with the person's consent, and
checks a room's ledgers. Issue 065e.

| | |
|---|---|
| `create <guide-name>` | shows every step (one sudo command each), asks for a typed `yes`, then makes the account `guide-<name>` (no login) and the room `/var/lib/reading-walk-guides/<name>/` owned by it, readable by all, writable by the guide only, with three empty ledgers |
| `create <guide-name> --dry-run` | shows the steps, does nothing |
| `check <room>` | every ledger rule (see `libs/guide-room.info.md`); exit 1 on any problem |
| `list <room>` | what the guide made public, with notes; how many files it kept |
| `--rooms=PATH` | where rooms live |

A guide name: lower-case letters, digits, dashes; starts with a letter; at
most 24 long. An existing account is refused, not reused.

Root can still read every room: privacy from the owner is by agreement.

Tests: `test-guide-room.sh`.
