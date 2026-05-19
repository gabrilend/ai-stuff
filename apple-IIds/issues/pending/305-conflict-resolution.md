---
name: conflict resolution policy
phase: 3
status: pending
blockedBy: [301, 302, 303, 304]
---

# 305 — conflict resolution policy

Where the shared filesystem, shared clipboard, and IPC channel produce
concurrent state changes, the broker applies a coherent set of rules
and writes an audit log so the user (or a developer) can understand
what happened.

## current behavior

The pieces have local rules — file locking is first-writer-wins (302),
scrap is timestamp-based (303), IPC is best-effort (304) — but no
unified policy or visibility into the decisions.

## intended behavior

- A single broker module `src/broker/conflict-policy.lua` owns all
  cross-instance conflict decisions.
- **For file writes:** locking (issue 302) prevents most conflicts.
  In the rare case where conflicts arise (e.g., host-side edits or
  lock-table inconsistency on crash recovery), the policy is
  **last-writer-wins** with the loser's content preserved as a
  `.conflict-N` sidecar in the same directory. The user can then
  manually reconcile.
- **For scrap:** timestamp-based last-writer-wins as per issue 303.
  No history retention.
- **For IPC:** the channel is best-effort with at-most-once delivery
  semantics. If an instance crashes while a message is in flight,
  the message is dropped and an event is logged. Programs that need
  guarantees layer their own protocol on top.
- An **audit log** at `tmp/broker-conflicts.log` records every
  conflict decision: timestamp, type, what was preserved, what was
  superseded. Settings UI (phase 5) can surface a "recent conflicts"
  view.

## suggested implementation steps

1. Create `src/broker/conflict-policy.lua` with three functions:
   `resolve_file_conflict(host_path, winner_inst, loser_data)`,
   `resolve_scrap_conflict(...)`, `log_ipc_drop(...)`.
2. Refactor issues 302, 303, 304 to call into this module rather
   than handling conflicts locally.
3. Implement the `.conflict-N` sidecar mechanism for file conflicts.
   Naming: `MyDoc.conflict-2026-05-20T14-32-15.txt` (timestamp suffix
   keeps multiple conflicts straight).
4. Implement the audit log writer (append-only, JSONL format for
   easy parsing).
5. Test each conflict path with a contrived scenario:
   - kill the broker mid-write, restart, edit a file from both
     instances → expect `.conflict-N` to appear
   - rapid alternating scrap copies → expect timestamp ordering to
     decide
   - kill an instance while AppleTalk packets are in flight → expect
     log entries, no crash

## related documents

- `docs/001-architecture-overview.md` — operational constraints
- `issues/301-shared-backing-filesystem.md`,
  `issues/302-file-locking.md`,
  `issues/303-shared-clipboard.md`,
  `issues/304-appletalk-ipc-channel.md` — the systems whose
  conflicts this module mediates

## notes

- The `.conflict-N` sidecar approach is borrowed from Dropbox,
  Syncthing, and similar sync tools. The user mental model "if two
  copies disagree, both are kept, you decide" is familiar and safe.
- For phase 3, the conflict module is intentionally simple: rules,
  not heuristics. Smarter conflict handling (e.g., text-document
  three-way merge) is out of scope.
