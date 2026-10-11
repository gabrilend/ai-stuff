# Issue 065e: The Guide's Room

**Status**: Open
**Parent**: 065-the-reading-walk.md
**Dependencies**: None
**Blocks**: 065f, 065g

## Current Behavior
No place for a guide's trail.

## Intended Behavior
A directory owned by a separate system user, readable but not writable by the
reader, holding the trail and the two dated ledgers (made public, kept to
itself) described in the parent. Created only after asking the user: that is
the consent step.

## Suggested Implementation Steps
1. Setup script that asks, then creates the user and the room.
2. Ledger format and a check that every entry matches a real file.
