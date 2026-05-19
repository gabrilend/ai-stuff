---
name: file locking (option A)
phase: 3
status: pending
blockedBy: [301]
---

# 302 — file locking (option A)

If one IIds has a file in the shared volume open for write, the other
IIds's attempt to open the same file for write gets a clear error.
The first opener wins; the second sees a "file in use" message.

## current behavior

The shared volume (issue 301) has no concurrent-access policy. If
both IIdses open the same file for write, the result is a race —
whichever finishes the last write commits, the other is silently
overwritten or corrupted.

## intended behavior

- The broker maintains an **in-memory lock table** keyed by host path.
- When an IIds opens a file for write, the broker records the lock:
  `{path, owning_instance, opened_at, mode}`.
- When the **other** IIds tries to open the same file for write, the
  broker rejects the open. The IIds sees a ProDOS / GS/OS error code
  equivalent to "file in use" — the standard error code is `$56`
  ("file is open"), which existing IIds software knows how to
  display.
- When the owning IIds closes the file, the lock is released.
- If the owning IIds crashes mid-write (issue 201's supervisor
  detects this), the broker releases the lock on restart, with a
  warning in the audit log.
- Read-only opens do **not** lock. Two readers can coexist freely.
- A reader and a writer can coexist: the reader sees a consistent
  snapshot taken at the moment of its open. (For phase 3, this is
  implemented as a copy-on-write: when the writer first writes, the
  broker materializes a snapshot for the reader. Cheap because IIds
  software files are small.)
- All lock decisions are logged to `tmp/broker-locks.log` with
  timestamps, paths, instances, and outcomes.

## suggested implementation steps

1. Add a `locks` table to the broker's state. Key: host file path.
   Value: `{instance, opened_at, mode}`.
2. Intercept the shared-volume open path in
   `src/broker/shared-volume.lua` (from issue 301). On `OpenFile`,
   check the lock table.
3. If a conflicting lock exists, return the IIds error code `$56`
   to the caller. GSplus will surface this to GS/OS as an
   ordinary file-system error.
4. On close, release the lock.
5. Wire the supervisor (issue 201) to broadcast "instance X
   crashed" events to the broker; the broker walks the lock table
   and releases locks held by instance X.
6. Add the audit log.
7. Test: open a doc on A, try to open it on B, see the error.
   Close on A, retry on B, succeeds.
8. Test the crash path: open a doc on A, kill instance A, restart it,
   open the doc on B, succeeds (lock was released).

## related documents

- `docs/001-architecture-overview.md` — operational constraints, file
  locking is option A
- `issues/301-shared-backing-filesystem.md` — the volume we're locking
- `issues/305-conflict-resolution.md` — what happens if both writers
  bypass locks (e.g., direct host-side edits)

## known design questions

- What about the host editing files directly (e.g., ssh in and edit a
  file in `~/.apple-IIds/shared/`)? The broker can't lock against
  host-side writes. Default: warn that direct host edits while the
  device is running are unsupported. Phase 5 settings UI can add a
  "force-refresh" command for after host edits.
- Granularity: file-level locking is the simplest. Per-record or
  per-byte locking is what GS/OS's File Manager *can* do natively,
  but for the shared volume, file-level is sufficient and predictable.
